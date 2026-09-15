/// Application-wide constants.
/// Replace [backendBaseUrl] with your actual Spring Boot server URL.
class AppConstants {
  AppConstants._();

  // ── Backend ──────────────────────────────────────────────────────────────
  /// Base URL for the Node.js REST API.
  static const String backendBaseUrl = 'http://192.168.137.1:8080';

  /// Endpoint the backend exposes to accept a Firebase JWT.
  static const String firebaseAuthEndpoint = '/api/auth/firebase';

  /// Endpoint for user profile CRUD operations.
  static const String profileEndpoint = '/api/user/profile';

  /// Alias used by BackendApiService for profile fetch.
  static const String userProfileEndpoint = '/api/user/profile';

  /// Endpoint for streaming sensor data batches.
  static const String sensorDataEndpoint = '/api/sensor/data';

  // ── Secure Storage Keys ────────────────────────────────────────────────
  static const String keyIdToken = 'firebase_id_token';
  static const String keyUid = 'user_uid';
  static const String keyEmail = 'user_email';
  static const String keyDisplayName = 'user_display_name';
  static const String keyPhotoUrl = 'user_photo_url';

  // ── Timeouts ──────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Token Refresh ─────────────────────────────────────────────────────
  /// Proactively refresh the token this many minutes before expiry.
  static const int tokenRefreshBufferMinutes = 5;

  // ── Phone OTP ─────────────────────────────────────────────────────────
  static const int otpResendCooldownSeconds = 60;
  static const int otpLength = 6;

  // ── Sensor ────────────────────────────────────────────────────────────────
  /// Target sampling interval for accelerometer + gyroscope (10Hz).
  static const Duration sensorSamplingInterval = Duration(milliseconds: 100);

  /// Number of readings per batch before sending to backend.
  static const int sensorBatchSize = 30; // 3 seconds at 10Hz

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const String appName = 'Crash Detection';
}
