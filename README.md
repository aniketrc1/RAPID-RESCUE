# 🚨 Crash Detection System

A full-stack motorcycle/vehicle crash detection system using IMU sensors, GPS, Firebase, and ML.

---

## Architecture

```
Crash_Detection/
├── crash_detection_auth/   ← Flutter mobile app
├── backend/                ← Node.js Express API
├── ml_model/               ← Python ML pipeline + Flask inference API
└── dataset/                ← Raw motorcycle fall CSVs (not tracked in git)
```

---

## Modules

### 1. Flutter App (`crash_detection_auth/`)
- **Auth:** Google Sign-In + Phone OTP via Firebase Auth
- **Profile:** User profile + emergency contacts (stored in Firestore)
- **Sensor Monitor:** Live accelerometer, gyroscope, GPS at 10Hz
- **Background Service:** Continuous sensor collection → batch POST to backend
- **Crash Detection:** Real-time gForce, rotation, speedDrop computation

#### Setup
```bash
cd crash_detection_auth
flutter pub get
flutter run
```

> **Required:** Place your `google-services.json` (Android) from Firebase Console at:
> `crash_detection_auth/android/app/google-services.json`
>
> Run `flutterfire configure` to generate `lib/firebase_options.dart`

---

### 2. Node.js Backend (`backend/`)
JWT-protected REST API using Firebase Admin SDK + Firestore.

#### Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/firebase` | Verify Firebase JWT, upsert user |
| POST | `/api/auth/logout` | Revoke refresh tokens |
| GET | `/api/user/profile` | Get user profile |
| POST | `/api/user/profile` | Create user profile |
| PUT | `/api/user/profile` | Update user profile |
| DELETE | `/api/user/account` | Delete account |
| POST | `/api/sensor/data` | Receive sensor batch → ML analysis |

#### Setup
```bash
cd backend
npm install

# Copy and fill in environment variables
cp .env.example .env
```

`.env` variables:
```
PORT=3000
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
CORS_ORIGIN=*
```

> **Required:** Download `serviceAccountKey.json` from Firebase Console → Project Settings → Service Accounts → Generate new private key. Place it in `backend/`.

```bash
npm run dev
```

---

### 3. ML Crash Detection Model (`ml_model/`)
Trained on 4 real motorcycle fall scenarios. **XGBoost** model with **AUC: 0.93**, **F1: 0.77**.

#### Pipeline
```bash
cd ml_model
pip install -r requirements.txt

python 1_preprocess.py   # Load + label CSV data
python 2_features.py     # Sliding window feature extraction
python 3_train.py        # Train Random Forest + XGBoost
python 4_evaluate.py     # Confusion matrix + ROC curve
```

> **Required:** Place the dataset CSV files in `dataset/` (not tracked by git — share via team drive).
>
> CSV format: tab-separated, columns: `time | Ax | Ay | Az | Rx | Ry | Rz`

#### Flask Inference API
```bash
cd ml_model/api
pip install -r requirements.txt
python app.py
# Listening on http://localhost:5000
```

```bash
# Test
curl -X GET http://localhost:5000/health
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{"readings": [{"ax":2.1,"ay":15.3,"az":3.2,"rx":45,"ry":80,"rz":20,"gForce":1.8,"rotation":92}]}'
```

Response:
```json
{
  "crashDetected": true,
  "confidence": 0.87,
  "severity": "moderate",
  "model": "RandomForest/XGBoost",
  "windowSize": 1
}
```

---

## Firestore Schema

```
users/{uid}                    ← User profile
sensorReadings/{uid}/readings  ← 10Hz sensor batches
```

---

## Environment Setup Checklist (for each team member)

- [ ] Clone repo
- [ ] Get `google-services.json` from Firebase Console → place in `crash_detection_auth/android/app/`
- [ ] Run `flutterfire configure` in `crash_detection_auth/` to generate `lib/firebase_options.dart`
- [ ] Get `serviceAccountKey.json` from Firebase Console → place in `backend/`
- [ ] Copy `backend/.env.example` → `backend/.env` and fill values
- [ ] Place dataset CSVs in `dataset/` (get from team drive)
- [ ] Run ML pipeline scripts to regenerate model (see above)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| Auth | Firebase Auth (Google + Phone OTP) |
| Database | Firebase Firestore |
| Backend | Node.js + Express |
| Sensors | `sensors_plus`, `geolocator`, `flutter_background_service` |
| ML | Python, XGBoost, scikit-learn, Flask |
| HTTP | Dio (Flutter), Axios (Node.js) |

---

## Security Notes

- Firebase JWT is verified on every backend request
- Tokens stored in Android Keystore / iOS Keychain via `flutter_secure_storage`
- 401 responses trigger automatic token refresh + retry
- **Never commit** `google-services.json`, `serviceAccountKey.json`, or `.env`
# RAPID-RESCUE
