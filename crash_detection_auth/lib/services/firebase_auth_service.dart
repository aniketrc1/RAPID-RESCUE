import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/auth_exceptions.dart';

/// Handles all Firebase Authentication operations.
///
/// Responsibilities:
///  - Google Sign-In OAuth flow
///  - Phone / SMS OTP flow
///  - Retrieving and proactively refreshing Firebase ID tokens (JWT)
///  - Exposing [authStateChanges] stream for automatic login persistence
///  - Sign-out (Firebase + Google)
class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
            );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 1));

  // ── Auth State Stream ─────────────────────────────────────────────────────

  /// Emits the current [User] whenever sign-in state changes.
  /// Listen to this stream in [AuthProvider] for automatic login persistence.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in Firebase user, or [null] if not authenticated.
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ────────────────────────────────────────────────────────

  /// Initiates the Google Sign-In OAuth flow and signs the credential into
  /// Firebase Auth.
  ///
  /// Returns the signed-in [UserCredential].
  /// Throws [GoogleSignInCancelledException] if the user dismisses the picker.
  /// Throws [GoogleSignInFailedException] for any other failure.
  Future<UserCredential> signInWithGoogle() async {
    try {
      _log.i('Starting Google Sign-In...');

      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();

      if (googleAccount == null) {
        // User cancelled the picker.
        throw const GoogleSignInCancelledException();
      }

      final GoogleSignInAuthentication googleAuth =
          await googleAccount.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      _log.i('Google Sign-In successful: ${userCredential.user?.email}');
      return userCredential;
    } on GoogleSignInCancelledException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      _log.e('GoogleSignIn FirebaseAuthException: ${e.code}', error: e);
      throw GoogleSignInFailedException(
        message: _mapFirebaseAuthError(e),
        originalError: e,
      );
    } catch (e) {
      _log.e('GoogleSignIn unexpected error', error: e);
      throw GoogleSignInFailedException(
        message: 'Google sign-in failed. Please try again.',
        originalError: e,
      );
    }
  }

  // ── Phone / OTP ───────────────────────────────────────────────────────────

  /// Sends an SMS OTP to [phoneNumber] (E.164 format, e.g. "+919876543210").
  ///
  /// Calls [onCodeSent] with the [verificationId] on success.
  /// Calls [onError] with a typed [AppAuthException] on failure.
  ///
  /// The optional [onAutoVerified] callback is invoked on Android if Firebase
  /// automatically intercepts the SMS and signs in without user input.
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(AppAuthException error) onError,
    void Function(UserCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    _log.i('Sending OTP to $phoneNumber');

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),

      // Android auto-retrieval (silent verification)
      verificationCompleted: (PhoneAuthCredential credential) async {
        _log.i('Phone auto-verified, signing in silently...');
        try {
          final uc = await _auth.signInWithCredential(credential);
          onAutoVerified?.call(uc);
        } on FirebaseAuthException catch (e) {
          onError(PhoneAuthException(
              message: _mapFirebaseAuthError(e), originalError: e));
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        _log.e('Phone verification failed: ${e.code}', error: e);
        onError(PhoneAuthException(
            message: _mapFirebaseAuthError(e), originalError: e));
      },

      codeSent: (String verificationId, int? resendingToken) {
        _log.i('OTP sent. verificationId: $verificationId');
        onCodeSent(verificationId, resendingToken);
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _log.w('OTP auto-retrieval timeout for verificationId: $verificationId');
      },
    );
  }

  /// Verifies [smsCode] against [verificationId] and signs the user into
  /// Firebase.
  ///
  /// Returns [UserCredential] on success.
  /// Throws [InvalidOtpException] if the code is wrong/expired.
  /// Throws [PhoneAuthException] for other Firebase errors.
  Future<UserCredential> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    _log.i('Verifying SMS OTP...');
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential uc = await _auth.signInWithCredential(credential);
      _log.i('Phone sign-in successful: ${uc.user?.phoneNumber}');
      return uc;
    } on FirebaseAuthException catch (e) {
      _log.e('OTP verification failed: ${e.code}', error: e);
      if (e.code == 'invalid-verification-code' ||
          e.code == 'invalid-verification-id') {
        throw const InvalidOtpException();
      }
      throw PhoneAuthException(
          message: _mapFirebaseAuthError(e), originalError: e);
    }
  }

  // ── JWT Token ─────────────────────────────────────────────────────────────

  /// Returns the Firebase ID token (JWT) for the currently signed-in user.
  ///
  /// If [forceRefresh] is true Firebase will always call its servers to get a
  /// fresh token, which is what the Dio interceptor does on 401 responses.
  ///
  /// Throws [TokenRetrievalException] if there is no signed-in user or the
  /// network call fails.
  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const TokenRetrievalException(
          message: 'No authenticated user. Please sign in first.');
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw const TokenRetrievalException(
            message: 'Firebase returned an empty token.');
      }
      _log.d('Token retrieved (forceRefresh=$forceRefresh, length=${token.length})');
      return token;
    } on TokenRetrievalException {
      rethrow;
    } catch (e) {
      throw TokenRetrievalException(
          message: 'Failed to retrieve Firebase ID token.',
          originalError: e);
    }
  }

  /// Returns the [IdTokenResult] which includes claims and the expiration time.
  Future<IdTokenResult> getIdTokenResult({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const TokenRetrievalException(
          message: 'No authenticated user.');
    }
    return user.getIdTokenResult(forceRefresh);
  }

  /// Sets up a listener on [authStateChanges] that proactively refreshes the
  /// token [AppConstants.tokenRefreshBufferMinutes] before it expires.
  ///
  /// Returns the [StreamSubscription] so the caller can cancel it on dispose.
  StreamSubscription<User?> setupTokenAutoRefresh({
    required void Function(String newToken) onTokenRefreshed,
    required void Function(AppAuthException error) onError,
  }) {
    Timer? _refreshTimer;

    return _auth.idTokenChanges().listen((user) async {
      _refreshTimer?.cancel();

      if (user == null) return;

      try {
        final result = await user.getIdTokenResult();
        final expiry = result.expirationTime;
        if (expiry == null) return;

        final now = DateTime.now();
        final refreshAt = expiry.subtract(
          Duration(minutes: AppConstants.tokenRefreshBufferMinutes),
        );
        final delay = refreshAt.difference(now);

        if (delay.isNegative) {
          // Token already expired or about to expire – refresh immediately.
          final fresh = await user.getIdToken(true);
          if (fresh != null) onTokenRefreshed(fresh);
          return;
        }

        _log.i(
            'Token refresh scheduled in ${delay.inMinutes} min '
            '(expires: ${expiry.toIso8601String()})');

        _refreshTimer = Timer(delay, () async {
          try {
            final fresh = await user.getIdToken(true);
            if (fresh != null) {
              _log.i('Proactive token refresh succeeded.');
              onTokenRefreshed(fresh);
            }
          } catch (e) {
            onError(
              TokenRefreshException(
                  message: 'Auto token refresh failed.', originalError: e),
            );
          }
        });
      } catch (e) {
        _log.e('Error setting up token auto-refresh', error: e);
      }
    });
  }

  // ── Sign-Out ──────────────────────────────────────────────────────────────

  /// Signs the user out of both Firebase and Google.
  Future<void> signOut() async {
    _log.i('Signing out...');
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    _log.i('Sign-out complete.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Maps [FirebaseAuthException] codes to human-readable strings.
  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'The sign-in credential is invalid or has expired.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Console.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found for this credential.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-phone-number':
        return 'The phone number is invalid. Use E.164 format (e.g. +91...).';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Try again later.';
      case 'session-expired':
        return 'OTP session expired. Please request a new code.';
      default:
        return e.message ?? 'Authentication error (${e.code}).';
    }
  }
}
