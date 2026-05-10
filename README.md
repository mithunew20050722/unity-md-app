# UNITY-MD Flutter App — Setup Guide

## 📁 File Structure

```
unity_md_app/
├── lib/
│   ├── main.dart                    # Entry point
│   ├── screens/
│   │   ├── splash_screen.dart       # Auto session check
│   │   ├── login_screen.dart        # Google Sign-In
│   │   ├── setup_screen.dart        # Phone + Pair code
│   │   └── home_screen.dart         # Bot dashboard
│   └── services/
│       ├── api_service.dart         # Railway API calls
│       └── auth_service.dart        # Firebase auth + session
├── android/app/src/main/
│   ├── AndroidManifest.xml
│   └── java/com/unityteam/unity_md/
│       ├── BootReceiver.java        # Auto-start on boot
│       └── BotService.java          # Background keep-alive

# Server side (UNITY_FAST project):
dashboard/
├── routes/appApi.js                 # New mobile app API
└── server.js                        # (modified — app route registered)
```

---

## 🔧 Step 1 — Firebase Setup

1. [Firebase Console](https://console.firebase.google.com) → New project → **unity-md-app**
2. Android app add කරන්න:
   - Package name: `com.unityteam.unity_md`
   - `google-services.json` download කරලා `android/app/` ඇතුළේ දාන්න
3. Authentication → Sign-in method → **Google** enable
4. Project Settings → General → **Web API Key** copy

---

## 🔧 Step 2 — Environment Variables (Railway)

Railway project → Variables ල add:

```
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

---

## 🔧 Step 3 — Android build.gradle

`android/app/build.gradle` ල:

```gradle
android {
    namespace "com.unityteam.unity_md"
    compileSdk 34

    defaultConfig {
        applicationId "com.unityteam.unity_md"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-auth'
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
}

apply plugin: 'com.google.gms.google-services'
```

`android/build.gradle` ල:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

---

## 🔧 Step 4 — Flutter Dependencies Install

```bash
cd unity_md_app
flutter pub get
```

---

## 🔧 Step 5 — Build APK

```bash
# Debug APK (testing)
flutter build apk --debug

# Release APK
flutter build apk --release --split-per-abi
```

APK location: `build/app/outputs/flutter-apk/`

---

## 📱 App Flow

```
Phone boot / App open
        ↓
   SplashScreen
        ↓
  Firebase user? ──No──→ LoginScreen (Google)
        ↓ Yes                    ↓
  SavedSession?          SetupScreen
        ↓ Yes            (phone + pair code)
  Reconnect API                  ↓
        ↓              Session saved to Railway
  Connected? ──Yes──→  HomeScreen
        ↓ No (needs re-pair)
  SetupScreen (re-pair)
```

---

## 🌐 API Endpoints (Server Side)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/app/ping` | Health check |
| POST | `/api/app/register` | Phone register + pair code |
| GET | `/api/app/status/:uid` | Session status |
| POST | `/api/app/reconnect` | Reconnect session |
| POST | `/api/app/disconnect` | Stop bot |
| GET | `/api/app/bot/info/:uid` | Bot stats |

All endpoints (except ping) require:
```
Authorization: Bearer <firebase_id_token>
```

---

## ✅ Server Deployment

Updated files:
- `dashboard/routes/appApi.js` — **NEW** (copy to server)
- `dashboard/server.js` — **MODIFIED** (copy to server)

Railway deploy:
```bash
git add dashboard/routes/appApi.js dashboard/server.js
git commit -m "Add mobile app API endpoints"
git push
```
