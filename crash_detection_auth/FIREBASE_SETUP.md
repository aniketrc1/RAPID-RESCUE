# Firebase Setup Guide

This guide walks you through connecting the Crash Detection Flutter app to a real Firebase project.

---

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add project** → enter a project name (e.g. `crash-detection`) → Continue
3. (Optional) Enable Google Analytics → Continue
4. Click **Create project**

---

## 2. Enable Authentication Providers

In the Firebase Console:

1. Go to **Build → Authentication → Sign-in method**
2. Enable **Google**:
   - Toggle **Enable**
   - Set a support email
   - Click **Save**
3. Enable **Phone**:
   - Toggle **Enable**
   - For testing, add your phone number to **Phone numbers for testing** (avoids real SMS)
   - Click **Save**

---

## 3. Add Android App to Firebase

1. In Firebase Console → Project Overview → **Add app → Android**
2. Enter package name: **`com.crashdetection.crash_detection`**
3. (Optional) Enter app nickname
4. Click **Register app**
5. **Download `google-services.json`**
6. **Replace** the placeholder file at:
   ```
   android/app/google-services.json
   ```
   with the downloaded file.
7. Skip steps 4 & 5 shown in the Console (already configured in Gradle files)

### Generate & Add SHA-1 (required for Google Sign-In)

```bash
# Debug key (development)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Copy the SHA-1 fingerprint
```

In Firebase Console → Project settings → Your apps → **Android app** → **Add fingerprint** → paste the SHA-1.

---

## 4. Add iOS App to Firebase (optional)

1. Firebase Console → **Add app → iOS**
2. Enter bundle ID: **`com.crashdetection.crashDetection`**
3. Download **`GoogleService-Info.plist`**
4. In Xcode: drag `GoogleService-Info.plist` into `Runner/Runner/` (check **Copy items if needed**)
5. In `ios/Runner/Info.plist`, add your reversed client ID for Google Sign-In:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Copy REVERSED_CLIENT_ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

---

## 5. Install FlutterFire CLI & Generate firebase_options.dart

```bash
# Install the CLI
dart pub global activate flutterfire_cli

# From the project root — this regenerates lib/firebase_options.dart
flutterfire configure
```

Follow the prompts to select your project and platforms. This **overwrites** the placeholder `lib/firebase_options.dart`.

---

## 6. Update Backend URL

In `lib/core/constants/app_constants.dart`, replace:

```dart
static const String backendBaseUrl = 'https://your-backend.com';
```

with your actual Spring Boot server URL.

---

## 7. Spring Boot Backend Setup

Your Spring Boot backend needs to validate the Firebase JWT token. Add the Firebase Admin SDK:

### Maven

```xml
<dependency>
  <groupId>com.google.firebase</groupId>
  <artifactId>firebase-admin</artifactId>
  <version>9.3.0</version>
</dependency>
```

### Minimal Spring Security Filter

```java
@Component
public class FirebaseTokenFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain)
            throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String idToken = authHeader.substring(7);
            try {
                FirebaseToken decoded = FirebaseAuth.getInstance().verifyIdToken(idToken);
                // Set security context with decoded.getUid(), decoded.getEmail() etc.
                UsernamePasswordAuthenticationToken auth =
                    new UsernamePasswordAuthenticationToken(
                        decoded.getUid(), null, Collections.emptyList());
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (FirebaseAuthException e) {
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                return;
            }
        }
        chain.doFilter(request, response);
    }
}
```

### Endpoint to receive the token (POST /api/auth/firebase)

```java
@RestController
@RequestMapping("/api/auth")
public class AuthController {
    @PostMapping("/firebase")
    public ResponseEntity<?> authenticateWithFirebase(@RequestBody Map<String, String> body) {
        // Token has already been validated by the filter above
        String uid = SecurityContextHolder.getContext().getAuthentication().getName();
        // Return your own session token or user profile
        return ResponseEntity.ok(Map.of("uid", uid, "status", "authenticated"));
    }
}
```

---

## 8. Run the App

```bash
cd crash_detection_auth
flutter pub get
flutter run
```

---

## Testing Phone OTP Without Real SMS

In Firebase Console → **Authentication → Sign-in method → Phone → Phone numbers for testing**:

Add entries like:
- Phone: `+91 9999999999` → OTP: `123456`

These bypass real SMS and are free.

---

## Common Issues

| Problem | Fix |
|---------|-----|
| `PlatformException: sign_in_failed` | Ensure SHA-1 is added in Firebase Console |
| `FirebaseException: operation-not-allowed` | Enable the auth provider in Firebase Console |
| `MissingPluginException` | Run `flutter pub get` and restart the app |
| `google-services.json not found` | Place it at `android/app/google-services.json` |
| `401 from Spring Boot` | Check Firebase Admin SDK initialization in backend |
