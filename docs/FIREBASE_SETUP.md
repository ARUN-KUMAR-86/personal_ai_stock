# Firebase Cloud Messaging (FCM) Setup for Android

This guide explains how to enable background push notifications on your Android phone.

---

## 1. Firebase Project Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project (e.g., `personal-ai-stock`).
2. Add an **Android Application**:
   - **Android package name**: `com.personal.aistock` (matches `mobile/android/app/src/main/AndroidManifest.xml`)
   - App nickname: `AI Stock Intel`
3. Download the generated `google-services.json` file.
4. Place `google-services.json` in:
   ```bash
   personal-ai-stock/mobile/android/app/google-services.json
   ```

---

## 2. Service Account Private Key (Backend Dispatcher)

To allow the FastAPI backend to send push notifications:
1. In Firebase Console, navigate to **Project Settings** > **Service accounts**.
2. Click **Generate new private key**.
3. Save the JSON file securely on your Linux machine (e.g., `personal-ai-stock/backend/serviceAccountKey.json`).
4. Update `personal-ai-stock/backend/.env`:
   ```bash
   FCM_SERVICE_ACCOUNT_PATH="/home/arun/personal-ai-stock/backend/serviceAccountKey.json"
   ```

---

## 3. Testing Notification Dispatch

You can test notification dispatch without waiting for a market scan:
```bash
cd /home/arun/personal-ai-stock
./backend/venv/bin/python scripts/test_notification.py
```
Or from the Flutter app:
- Open the **Alerts** screen and tap the phone icon in the top right (`Send Test Push Alert`).
