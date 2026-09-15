# Crash Detection — Node.js Backend

Express.js backend that validates Firebase JWT tokens from the Flutter app.

## Setup

### 1. Install Node.js
Download from [nodejs.org](https://nodejs.org) → **LTS version**.

### 2. Install dependencies
```bash
cd K:\Crash_Detection\backend
npm install
```

### 3. Get Firebase service account key
1. [Firebase Console](https://console.firebase.google.com) → ⚙️ Project Settings
2. **Service Accounts** tab → **Generate new private key**
3. Save the downloaded JSON as **`serviceAccountKey.json`** in this folder
   (it is already `.gitignore`d — never commit it)

### 4. Create `.env` file
```bash
copy .env.example .env
```
Edit `.env` and set your values (the defaults work for local dev).

### 5. Run
```bash
# Development (auto-restart on file changes)
npm run dev

# Production
npm start
```
Server starts at **http://localhost:8080**

---

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health` | None | Health check |
| `POST` | `/api/auth/firebase` | Bearer token | Verify Firebase JWT, upsert user |
| `POST` | `/api/auth/logout` | Bearer token | Revoke all tokens server-side |
| `GET` | `/api/user/profile` | Bearer token | Get authenticated user profile |
| `DELETE` | `/api/user/account` | Bearer token | Delete Firebase account |

---

## Flutter Integration

In `lib/core/constants/app_constants.dart`, set:

```dart
// Android Emulator → points to your PC's localhost
static const String backendBaseUrl = 'http://10.0.2.2:8080';

// Physical device on same Wi-Fi → use your PC's local IP
// static const String backendBaseUrl = 'http://192.168.x.x:8080';
```

Find your local IP: run `ipconfig` → IPv4 Address under Wi-Fi adapter.

---

## Project Structure
```
backend/
├── src/
│   ├── index.js                  ← Express app + server
│   ├── config/
│   │   └── firebase.js           ← Firebase Admin SDK init
│   ├── middleware/
│   │   └── firebaseAuth.js       ← JWT verification middleware
│   └── routes/
│       ├── auth.js               ← /api/auth/*
│       └── user.js               ← /api/user/*
├── serviceAccountKey.json        ← ⚠️ Add this (download from Firebase)
├── .env                          ← ⚠️ Add this (copy from .env.example)
├── .env.example
├── .gitignore
└── package.json
```
