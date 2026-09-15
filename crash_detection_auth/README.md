# Crash Detection – Flutter Firebase Auth Module

A **production-ready** Flutter authentication module integrating Firebase Authentication with a Spring Boot backend.

## Features

| Feature | Status |
|---------|--------|
| Google Sign-In (OAuth 2.0) | ✅ |
| Phone OTP Authentication | ✅ |
| Automatic Login Persistence | ✅ |
| Firebase JWT Token Retrieval | ✅ |
| Encrypted Token Storage (Keystore/Keychain) | ✅ |
| Automatic Token Refresh (proactive + 401 retry) | ✅ |
| JWT forwarded to Spring Boot backend | ✅ |
| Logout (Firebase + Google + secure storage) | ✅ |

---

## Architecture

```
Flutter App
    │
    ├── SplashScreen ─────────── AuthProvider (ChangeNotifier)
    ├── LoginScreen  ─────────────────┤
    ├── PhoneOtpScreen                │
    └── HomeScreen                    │
                                      │
                              FirebaseAuthService
                                 ├── Google Sign-In
                                 ├── Phone OTP
                                 ├── getIdToken()
                                 └── setupTokenAutoRefresh()
                                      │
                              SecureStorageService
                              (flutter_secure_storage)
                                      │
                              BackendApiService (Dio)
                              ├── AuthInterceptor
                              │   ├── Inject Bearer token
                              │   └── 401 → refresh → retry
                              └── POST /api/auth/firebase
```

---

## Project Structure

```
crash_detection_auth/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── firebase_options.dart              # FlutterFire CLI output
│   ├── core/
│   │   ├── constants/app_constants.dart   # Backend URL, storage keys
│   │   └── errors/auth_exceptions.dart   # Typed exception hierarchy
│   ├── services/
│   │   ├── firebase_auth_service.dart    # All Firebase Auth operations
│   │   ├── secure_storage_service.dart   # Encrypted token storage
│   │   └── backend_api_service.dart      # Dio + AuthInterceptor
│   ├── providers/
│   │   └── auth_provider.dart            # ChangeNotifier state
│   └── screens/
│       ├── splash_screen.dart            # Auto-login persistence
│       ├── login_screen.dart             # Google + Phone buttons
│       ├── phone_otp_screen.dart         # OTP two-step flow
│       └── home_screen.dart              # JWT info + logout
├── android/
│   ├── build.gradle                      # Google Services classpath
│   └── app/
│       ├── build.gradle                  # minSdk 21, GMS plugin
│       ├── google-services.json          # ⚠️ Replace with real file
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── kotlin/.../MainActivity.kt
├── FIREBASE_SETUP.md                     # Step-by-step setup guide
└── pubspec.yaml                          # All dependencies
```

---

## Quick Start

### Prerequisites

- Flutter SDK ≥ 3.3.0
- Android SDK with min API 21
- A Firebase project (see [FIREBASE_SETUP.md](./FIREBASE_SETUP.md))

### Steps

```bash
# 1. Clone / open the project
cd crash_detection_auth

# 2. Install FlutterFire CLI (one-time)
dart pub global activate flutterfire_cli

# 3. Connect to your Firebase project
flutterfire configure

# 4. Set your Spring Boot URL in:
#    lib/core/constants/app_constants.dart → backendBaseUrl

# 5. Get dependencies
flutter pub get

# 6. Run
flutter run
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_auth` | Core Firebase Authentication |
| `google_sign_in` | Google OAuth flow |
| `flutter_secure_storage` | Encrypted token storage |
| `dio` | HTTP client with interceptors |
| `provider` | Reactive state management |
| `pinput` | OTP input widget |
| `country_code_picker` | Country dial code picker |

---

## Token Flow

```
1. User signs in (Google / Phone OTP)
2. Firebase returns an ID token (JWT, valid 1 hour)
3. Token is saved to flutter_secure_storage
4. Token is POST-ed to Spring Boot: POST /api/auth/firebase
5. On expiry, Dio AuthInterceptor catches 401:
     → calls Firebase.getIdToken(forceRefresh: true)
     → saves new token
     → retries the original request
6. Additionally, a background Timer refreshes the token
   5 minutes before expiry (proactive refresh)
```

---

## Environment: Backend URL

Edit `lib/core/constants/app_constants.dart`:

```dart
static const String backendBaseUrl = 'https://your-backend.com';
```

See [FIREBASE_SETUP.md](./FIREBASE_SETUP.md) for full backend configuration.
