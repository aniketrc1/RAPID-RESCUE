import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/auth_exceptions.dart';
import 'firebase_auth_service.dart';
import 'secure_storage_service.dart';

/// HTTP client for communicating with the Spring Boot backend.
///
/// Features:
/// - Automatically attaches `Authorization: Bearer <token>` on every request.
/// - On HTTP 401, proactively refreshes the Firebase ID token using
///   [FirebaseAuthService.getIdToken] and retries the original request once.
/// - Typed error responses wrapped in [BackendAuthException] / [NetworkException].
class BackendApiService {
  BackendApiService({
    required FirebaseAuthService authService,
    required SecureStorageService storageService,
    Dio? dio,
  })  : _authService = authService,
        _storageService = storageService,
        _dio = dio ?? _buildDio() {
    _dio.interceptors.add(
      AuthInterceptor(
        authService: _authService,
        storageService: _storageService,
        dio: _dio,
      ),
    );
  }

  final FirebaseAuthService _authService;
  final SecureStorageService _storageService;
  final Dio _dio;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 1));

  /// Exposes the configured Dio instance for use by other services.
  /// The [AuthInterceptor] is already attached — JWT is auto-injected.
  Dio get dio => _dio;

  // ── Auth Endpoints ────────────────────────────────────────────────────────

  /// Sends the Firebase ID [token] to the Spring Boot backend.
  ///
  /// The backend should validate the token with Firebase Admin SDK and return
  /// its own session token / user profile.
  ///
  /// Returns the decoded JSON response body as [Map<String, dynamic>].
  Future<Map<String, dynamic>> sendAuthToken(String token) async {
    _log.i('Sending Firebase JWT to backend (${AppConstants.firebaseAuthEndpoint})');
    try {
      final response = await _dio.post(
        AppConstants.firebaseAuthEndpoint,
        data: {'idToken': token},
      );
      _log.i('Backend accepted token. Status: ${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches the authenticated user's profile from the backend.
  Future<Map<String, dynamic>> getUserProfile() async {
    _log.i('Fetching user profile (${AppConstants.userProfileEndpoint})');
    try {
      final response = await _dio.get(AppConstants.userProfileEndpoint);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConstants.backendBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        contentType: 'application/json',
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  AppAuthException _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.unknown) {
      return const NetworkException();
    }
    final status = e.response?.statusCode;
    final msg = (e.response?.data as Map?)?['message']?.toString() ??
        e.message ??
        'Unknown backend error';
    return BackendAuthException(message: msg, statusCode: status, originalError: e);
  }
}

// ── Auth Interceptor ──────────────────────────────────────────────────────────

/// Dio interceptor that:
/// 1. Reads the stored token from [SecureStorageService] and injects
///    `Authorization: Bearer <token>` into every outgoing request.
/// 2. On HTTP 401, force-refreshes the Firebase token, saves the new one,
///    and retries the original request exactly once.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.authService,
    required this.storageService,
    required this.dio,
  });

  final FirebaseAuthService authService;
  final SecureStorageService storageService;
  final Dio dio;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static const String _retryHeader = 'X-Retry';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    // Only retry 401s once (guard against infinite loop via custom header).
    if (response?.statusCode == 401 &&
        err.requestOptions.headers[_retryHeader] == null) {
      _log.w('401 received – refreshing Firebase token and retrying...');
      try {
        final freshToken = await authService.getIdToken(forceRefresh: true);
        await storageService.saveToken(freshToken);

        // Clone the original request with the new token.
        final retryOptions = err.requestOptions
          ..headers['Authorization'] = 'Bearer $freshToken'
          ..headers[_retryHeader] = 'true';

        final retryResponse = await dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } on AppAuthException catch (e) {
        _log.e('Token refresh failed during 401 retry: ${e.message}');
        return handler.next(err);
      } catch (e) {
        _log.e('Unexpected error during 401 retry', error: e);
        return handler.next(err);
      }
    }
    return handler.next(err);
  }
}
