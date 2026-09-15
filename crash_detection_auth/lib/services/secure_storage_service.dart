import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';

/// Manages encrypted, on-device storage of the Firebase ID token and basic
/// user profile data.
///
/// On Android, uses [EncryptedSharedPreferences] backed by the Android
/// Keystore. On iOS, data is stored in the Keychain.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  // ── Token ─────────────────────────────────────────────────────────────────

  /// Saves [token] to secure storage.
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.keyIdToken, value: token);
    _log.d('Token saved to secure storage.');
  }

  /// Returns the stored ID token, or [null] if nothing is saved yet.
  Future<String?> getToken() async {
    final token = await _storage.read(key: AppConstants.keyIdToken);
    _log.d(token != null
        ? 'Token read from secure storage (length=${token.length}).'
        : 'No token in secure storage.');
    return token;
  }

  /// Deletes the stored token (e.g., on sign-out or after token refresh).
  Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.keyIdToken);
    _log.d('Token deleted from secure storage.');
  }

  // ── User Profile ─────────────────────────────────────────────────────────

  /// Saves basic user profile data to secure storage.
  Future<void> saveUserData({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyUid, value: uid),
      if (email != null)
        _storage.write(key: AppConstants.keyEmail, value: email),
      if (displayName != null)
        _storage.write(key: AppConstants.keyDisplayName, value: displayName),
      if (photoUrl != null)
        _storage.write(key: AppConstants.keyPhotoUrl, value: photoUrl),
    ]);
    _log.d('User data saved for uid=$uid');
  }

  /// Reads all stored user profile data.
  /// Returns a [Map] with keys matching [AppConstants] key constants.
  Future<Map<String, String?>> getUserData() async {
    final results = await Future.wait([
      _storage.read(key: AppConstants.keyUid),
      _storage.read(key: AppConstants.keyEmail),
      _storage.read(key: AppConstants.keyDisplayName),
      _storage.read(key: AppConstants.keyPhotoUrl),
    ]);

    return {
      AppConstants.keyUid: results[0],
      AppConstants.keyEmail: results[1],
      AppConstants.keyDisplayName: results[2],
      AppConstants.keyPhotoUrl: results[3],
    };
  }

  // ── Housekeeping ─────────────────────────────────────────────────────────

  /// Deletes ALL stored data. Call on logout.
  Future<void> clearAll() async {
    await _storage.deleteAll();
    _log.i('All secure storage cleared.');
  }

  /// Returns true if a token is currently stored.
  Future<bool> hasToken() async {
    final token = await _storage.read(key: AppConstants.keyIdToken);
    return token != null && token.isNotEmpty;
  }
}
