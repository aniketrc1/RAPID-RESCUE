import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../core/errors/auth_exceptions.dart';
import '../services/backend_api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/secure_storage_service.dart';

// ── Auth State Enum ───────────────────────────────────────────────────────────

enum AuthState {
  /// App has just launched – determining sign-in state.
  initial,

  /// User is signed in and token has been sent to backend.
  authenticated,

  /// User is not signed in.
  unauthenticated,
}

// ── Auth Provider ─────────────────────────────────────────────────────────────

/// Central state holder for authentication.
///
/// - Listens to [FirebaseAuth.authStateChanges] for automatic login persistence.
/// - Coordinates token storage via [SecureStorageService].
/// - Sends JWT to Spring Boot backend via [BackendApiService] after every
///   successful sign-in.
/// - Exposes reactive [authState], [currentUser], [errorMessage], [isLoading].
class AppAuthProvider extends ChangeNotifier {
  AppAuthProvider({
    required FirebaseAuthService authService,
    required SecureStorageService storageService,
    required BackendApiService backendApiService,
  })  : _authService = authService,
        _storageService = storageService,
        _backendApiService = backendApiService {
    _init();
  }

  final FirebaseAuthService _authService;
  final SecureStorageService _storageService;
  final BackendApiService _backendApiService;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 1));

  // ── Public State ──────────────────────────────────────────────────────────

  AuthState _authState = AuthState.initial;
  AuthState get authState => _authState;

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The last successfully retrieved ID token. Updated on every refresh.
  String? _idToken;
  String? get idToken => _idToken;

  // ── Internal ──────────────────────────────────────────────────────────────

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<User?>? _tokenRefreshSubscription;

  // ── Initialisation ────────────────────────────────────────────────────────

  void _init() {
    _authSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _log.i('Auth state: unauthenticated');
      _tokenRefreshSubscription?.cancel();
      _currentUser = null;
      _idToken = null;
      _setAuthState(AuthState.unauthenticated);
      return;
    }

    _log.i('Auth state: authenticated (uid=${user.uid})');
    _currentUser = user;

    // Fetch and store token.
    try {
      final token = await _authService.getIdToken();
      _idToken = token;
      await _storageService.saveToken(token);
      await _storageService.saveUserData(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );

      // Send token to Spring Boot backend.
      await _sendTokenToBackend(token);
    } catch (e) {
      _log.e('Error after auth state change', error: e);
    }

    // Setup proactive token refresh.
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _authService.setupTokenAutoRefresh(
      onTokenRefreshed: (newToken) async {
        _idToken = newToken;
        await _storageService.saveToken(newToken);
        _log.i('Auto-refreshed token saved.');
        notifyListeners();
      },
      onError: (e) => _log.e('Auto-refresh error: ${e.message}'),
    );

    _setAuthState(AuthState.authenticated);
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final response = await _backendApiService.sendAuthToken(token);
      _log.i('Backend response: $response');
    } on AppAuthException catch (e) {
      // Non-fatal: local auth is still valid even if backend call fails.
      _log.w('Failed to send token to backend: ${e.message}');
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithGoogle();
      // _onAuthStateChanged fires automatically.
    } on GoogleSignInCancelledException {
      // silently ignore cancellation
    } on AppAuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Phone Sign-In ─────────────────────────────────────────────────────────

  /// Step 1 – Request OTP for [phoneNumber].
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    void Function(UserCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithPhoneNumber(
        phoneNumber: phoneNumber,
        resendToken: resendToken,
        onCodeSent: (id, token) {
          _setLoading(false);
          onCodeSent(id, token);
        },
        onError: (e) {
          _setLoading(false);
          _setError(e.message);
        },
        onAutoVerified: (uc) {
          _setLoading(false);
          onAutoVerified?.call(uc);
        },
      );
    } catch (e) {
      _setLoading(false);
      _setError('Failed to send OTP. Check the phone number and try again.');
    }
  }

  /// Step 2 – Verify OTP.
  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.verifySmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      // _onAuthStateChanged fires automatically.
    } on InvalidOtpException catch (e) {
      _setError(e.message);
    } on AppAuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('OTP verification failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign-Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signOut();
      await _storageService.clearAll();
      // _onAuthStateChanged will set state to unauthenticated.
    } catch (e) {
      _setError('Sign-out failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Token Utilities ───────────────────────────────────────────────────────

  /// Force-refresh and return the latest ID token.
  Future<String?> refreshToken() async {
    try {
      final token = await _authService.getIdToken(forceRefresh: true);
      _idToken = token;
      await _storageService.saveToken(token);
      notifyListeners();
      return token;
    } on AppAuthException catch (e) {
      _setError(e.message);
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setAuthState(AuthState state) {
    _authState = state;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() => _clearError();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
