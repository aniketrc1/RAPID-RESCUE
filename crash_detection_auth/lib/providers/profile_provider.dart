import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/user_profile.dart';
import '../services/profile_api_service.dart';

enum ProfileState { initial, loading, loaded, notFound, error }

/// Manages user profile state across the app.
class ProfileProvider extends ChangeNotifier {
  final ProfileApiService _profileApiService;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 1));

  ProfileProvider({required ProfileApiService profileApiService})
      : _profileApiService = profileApiService;

  // ── State ──────────────────────────────────────────────────────────────────
  ProfileState _state = ProfileState.initial;
  UserProfile? _profile;
  String? _errorMessage;

  ProfileState get state => _state;
  UserProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ProfileState.loading;
  bool get hasProfile => _profile != null;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Loads the user's profile from the backend.
  Future<void> loadProfile() async {
    _setState(ProfileState.loading);
    _errorMessage = null;
    try {
      final profile = await _profileApiService.getProfile();
      if (profile == null) {
        _profile = null;
        _setState(ProfileState.notFound);
      } else {
        _profile = profile;
        _setState(ProfileState.loaded);
      }
    } on DioException catch (e) {
      _log.e('loadProfile failed', error: e);
      _errorMessage = _extractError(e, 'Failed to load profile.');
      _setState(ProfileState.error);
    } catch (e) {
      _log.e('loadProfile unexpected error', error: e);
      _errorMessage = 'Unexpected error loading profile.';
      _setState(ProfileState.error);
    }
  }

  /// Saves the profile (create or update).
  /// Returns true on success.
  Future<bool> saveProfile(UserProfile profile) async {
    _setState(ProfileState.loading);
    _errorMessage = null;
    try {
      final saved = await _profileApiService.saveProfile(
        profile,
        isNew: _profile == null,
      );
      _profile = saved;
      _setState(ProfileState.loaded);
      return true;
    } on DioException catch (e) {
      _log.e(
        'saveProfile failed — status: ${e.response?.statusCode}',
        error: e,
      );
      _errorMessage = _extractError(e, 'Failed to save profile.');
      _setState(ProfileState.error);
      return false;
    } catch (e) {
      _log.e('saveProfile unexpected error', error: e);
      _errorMessage = 'Unexpected error saving profile.';
      _setState(ProfileState.error);
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setState(ProfileState s) {
    _state = s;
    notifyListeners();
  }

  String _extractError(DioException e, String fallback) {
    try {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      String? serverMsg;
      if (data is Map && data['message'] != null) {
        serverMsg = data['message'] as String;
      } else if (data is Map && data['errors'] is List) {
        serverMsg = (data['errors'] as List).join('\n');
      }
      if (serverMsg != null && serverMsg.isNotEmpty) {
        return status != null ? '[$status] $serverMsg' : serverMsg;
      }
      // No response body — likely a network error.
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Cannot reach server. Check your network or ensure the backend is running.';
      }
    } catch (_) {}
    return fallback;
  }
}
