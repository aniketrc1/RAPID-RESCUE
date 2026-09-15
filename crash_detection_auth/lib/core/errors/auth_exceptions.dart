/// Typed exception hierarchy for the authentication module.
/// All exceptions carry a [message] field for user-friendly display and
/// an optional [originalError] for debug logging.
sealed class AppAuthException implements Exception {
  const AppAuthException({required this.message, this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() => 'AppAuthException: $message';
}

// ── Google Sign-In ──────────────────────────────────────────────────────────

/// Thrown when the user cancels the Google sign-in dialog.
final class GoogleSignInCancelledException extends AppAuthException {
  const GoogleSignInCancelledException()
      : super(message: 'Google sign-in was cancelled.');
}

/// Thrown when the Google sign-in flow fails for any other reason.
final class GoogleSignInFailedException extends AppAuthException {
  const GoogleSignInFailedException({required super.message, super.originalError});
}

// ── Phone / OTP ─────────────────────────────────────────────────────────────

/// Thrown when Firebase rejects a phone number (invalid format, quota, etc.).
final class PhoneAuthException extends AppAuthException {
  const PhoneAuthException({required super.message, super.originalError});
}

/// Thrown when the OTP entered by the user is wrong or expired.
final class InvalidOtpException extends AppAuthException {
  const InvalidOtpException({String message = 'Invalid or expired OTP. Please try again.'})
      : super(message: message);
}

// ── Token ────────────────────────────────────────────────────────────────────

/// Thrown when retrieving / refreshing the Firebase ID token fails.
final class TokenRetrievalException extends AppAuthException {
  const TokenRetrievalException({required super.message, super.originalError});
}

/// Thrown when proactive token refresh fails unexpected errors.
final class TokenRefreshException extends AppAuthException {
  const TokenRefreshException({required super.message, super.originalError});
}

// ── Backend ──────────────────────────────────────────────────────────────────

/// Thrown when the Spring Boot backend rejects the token or returns an error.
final class BackendAuthException extends AppAuthException {
  const BackendAuthException({required super.message, this.statusCode, super.originalError});

  final int? statusCode;
}

/// Thrown when there is a network / connectivity error reaching the backend.
final class NetworkException extends AppAuthException {
  const NetworkException({String message = 'No internet connection or server unreachable.'})
      : super(message: message);
}
