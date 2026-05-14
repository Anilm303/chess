# Real Device and APK Production Guide

This guide explains the remaining setup needed for a Flutter + Python chat/game app to work the same on:
- Chrome
- Android emulator
- USB-connected Android phones
- Installed APKs
- Release builds

## What is already fixed in code
- Android cleartext traffic is enabled for local development.
- Runtime permissions are requested from Flutter using `permission_handler`.
- Backend URL resolution now prefers stable candidates and clears stale cached URLs.
- Firebase initialization is guarded so missing config does not crash startup.
- Socket connections already use reconnect options.
- Release builds disable minify and resource shrinking.

## 1. Localhost and LAN IP
Android phones cannot reliably use `localhost` for your PC backend.

Use one of these during development:
- Android emulator: `http://10.0.2.2:8000/api`
- USB-connected phone with adb reverse: `http://127.0.0.1:8000/api`
- Real phone on Wi-Fi: `http://192.168.x.x:8000/api`

Recommended development backend command:
```bash
cd chess_backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 2. Android permissions
The app already declares the common permissions needed for network, camera, microphone, and media access.

If you add new media features, keep these permissions in `android/app/src/main/AndroidManifest.xml`:
- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `CAMERA`
- `RECORD_AUDIO`
- `READ_EXTERNAL_STORAGE` for Android 12 and lower
- `WRITE_EXTERNAL_STORAGE` for legacy devices
- `READ_MEDIA_IMAGES` for Android 13+
- `READ_MEDIA_VIDEO` for Android 13+
- `READ_MEDIA_AUDIO` for Android 13+

Runtime permissions are requested from `lib/services/device_bootstrap.dart` and call flow permissions are requested in `lib/services/call_service.dart`.

## 3. Firebase Android setup
For Firebase Auth, Firestore, Storage, and FCM on Android, you still need a real Firebase project.

Required steps:
1. Create or open your Firebase project.
2. Add an Android app with package name `com.example.chess_app` or update the package name to match your final app id.
3. Download `google-services.json`.
4. Put it in `android/app/google-services.json`.
5. Add SHA-1 and SHA-256 fingerprints in Firebase Console.
6. Enable the auth providers you need.
7. Enable Firestore and Storage rules for production.

Important:
- Without the real `google-services.json`, Firebase Auth/Firestore/Storage will not be fully functional on Android.
- The Flutter code now initializes Firebase safely and will not crash if Firebase is missing, but that also means Firebase features will be skipped until the project config is added.

## 4. HTTP and HTTPS
Cleartext HTTP is enabled for local development, which is why `http://192.168.x.x:8000` can work.

For production:
- Move the backend to HTTPS.
- Use a real domain or managed platform URL.
- Update `API_BASE_URL` to `https://your-domain.com/api`.
- Use `wss://your-domain.com` for Socket.IO/WebSocket.

Why HTTP can fail on Android 9+:
- Android blocks cleartext traffic by default for apps targeting newer SDKs unless explicitly allowed.
- Production apps should use HTTPS instead of allowing cleartext.

## 5. Socket.IO and WebSocket
For real devices:
- Always use the same backend base URL as API traffic.
- Keep reconnect logic enabled.
- Ensure the backend is reachable from the device network.
- Use `adb reverse tcp:8000 tcp:8000` only for USB debugging.

If the device disconnects often:
- Check Wi-Fi stability.
- Verify the backend process is not sleeping or restarting.
- Check Android battery optimization for the APK.

## 6. Image, video, and file uploads
For message and story uploads:
- Keep camera and media permissions enabled.
- On Android 13+, use the new media permissions.
- Ensure your backend accepts multipart uploads.
- For larger videos, prefer multipart upload instead of raw JSON.

## 7. Voice and video calls
For WebRTC calls:
- Camera permission is required for video calls.
- Microphone permission is required for audio and video calls.
- Speaker routing and local stream initialization already happen in the call service.
- Test both the front and rear camera paths.

## 8. Release APK settings
The app release build is currently configured to:
- Keep minify disabled.
- Keep resource shrinking disabled.

This is useful while stabilizing production behavior.

Recommended commands:
```bash
flutter clean
flutter pub get
flutter build apk --debug
flutter build apk --release
```

## 9. Debugging on real devices
Useful commands:
```bash
flutter logs
adb logcat
flutter run -d <device_id>
```

What to look for:
- `SocketException` for backend connectivity
- Firebase initialization errors
- Permission denied errors
- Multipart upload failures
- WebRTC camera/mic permission failures

## 10. Production deployment
Backend options:
- Render
- Railway
- VPS
- Any HTTPS-capable cloud host

Recommended production layout:
- API: `https://api.your-domain.com/api`
- WebSocket: `wss://api.your-domain.com`

Environment variables:
- `API_BASE_URL=https://api.your-domain.com/api`
- `WS_BASE_URL=wss://api.your-domain.com`
- `DATABASE_URL=...`
- `FIREBASE_*` values if you use server-side Firebase integration

## 11. Current architecture summary
Flutter services:
- `lib/services/api_service.dart`
- `lib/services/ludo_socket_service.dart`
- `lib/services/message_service.dart`
- `lib/services/call_service.dart`
- `lib/services/device_bootstrap.dart`

Python backend:
- `chess_backend/main.py`
- `chess_backend/app/api_routes.py`
- `chess_backend/app/websocket_handler.py`
- `chess_backend/app/room_manager.py`
- `chess_backend/app/game_engine.py`
- `chess_backend/app/db_connection.py`

## 12. Practical checklist
Before testing on a phone:
- Start backend on `0.0.0.0:8000`.
- Confirm `http://10.0.2.2:8000/health` works on emulator.
- Confirm your real phone can reach the LAN IP.
- Add `google-services.json`.
- Add Firebase SHA-1 and SHA-256.
- Grant camera/mic/media permissions.
- Build and install a fresh APK.

## 13. Important note
The codebase is now prepared for production-style device handling, but Firebase Android Auth/Storage/Firestore still require your real Firebase project configuration files. That part cannot be fully completed from code alone.
