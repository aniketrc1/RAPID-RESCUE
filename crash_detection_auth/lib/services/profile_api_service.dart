import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import 'backend_api_service.dart';

/// Handles all profile-related API calls to the Node.js backend.
/// Uses the [BackendApiService] Dio instance which auto-injects the JWT.
class ProfileApiService {
  final Dio _dio;

  ProfileApiService({required BackendApiService backendApiService})
      : _dio = backendApiService.dio;

  /// GET /api/user/profile
  /// Returns null if profile doesn't exist yet (404).
  Future<UserProfile?> getProfile() async {
    try {
      final response = await _dio.get(AppConstants.profileEndpoint);
      final data = response.data['profile'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST /api/user/profile — creates a new profile.
  Future<UserProfile> createProfile(UserProfile profile) async {
    final response = await _dio.post(
      AppConstants.profileEndpoint,
      data: profile.toJson(),
    );
    return UserProfile.fromJson(
        response.data['profile'] as Map<String, dynamic>);
  }

  /// PUT /api/user/profile — updates (upserts) an existing profile.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final response = await _dio.put(
      AppConstants.profileEndpoint,
      data: profile.toJson(),
    );
    return UserProfile.fromJson(
        response.data['profile'] as Map<String, dynamic>);
  }

  /// Saves the profile — creates if new, updates if exists.
  Future<UserProfile> saveProfile(UserProfile profile,
      {required bool isNew}) async {
    return isNew ? createProfile(profile) : updateProfile(profile);
  }
}
