#!/usr/bin/env bash
# Auto-Install script for Zed Android Mobile Application
# Installs the standalone release APK directly to your connected Android phone.
# Once installed, the app works 100% independently via Wi-Fi or mobile data.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ADB="${ADB:-/home/arun/android-sdk/platform-tools/adb}"

# Look for freshly built APK in flutter-apk output folder
APK=""
for cand in \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-release.apk" \
  "$ROOT_DIR/app-arm64-v8a-release.apk"; do
  if [ -f "$cand" ]; then
    APK="$cand"
    break
  fi
done

if [ -z "$APK" ]; then
  echo "Error: Release APK not found. Please build it first: cd mobile && flutter build apk --release"
  exit 1
fi

echo "Checking phone connection status via ADB..."
for i in {1..60}; do
  LINE=$($ADB devices | grep -v "List of" | grep -w "device" | head -n1)
  if [ -n "$LINE" ]; then
    DEV_ID=$(echo "$LINE" | awk '{print $1}')
    echo "Device detected ($DEV_ID)! Installing Zed Release APK: $APK"
    $ADB -s "$DEV_ID" install -r "$APK"
    RES=$?
    if [ $RES -eq 0 ]; then
      echo "=== INSTALLATION SUCCESSFUL ==="
      # Remove any legacy reverse port forwards so the app uses its independent cloud connection
      $ADB -s "$DEV_ID" reverse --remove-all 2>/dev/null || true
      echo "Launching Zed application on device..."
      $ADB -s "$DEV_ID" shell monkey -p com.personal.aistock -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
      echo ""
      echo "====================================================================="
      echo "  ZED IS INSTALLED & RUNNING INDEPENDENTLY ON YOUR PHONE!"
      echo "  - Connects to: https://personal-ai-stock-backend.onrender.com"
      echo "  - Works on your phone's Wi-Fi or Mobile Data (4G/5G)."
      echo "  - You can safely DISCONNECT the USB cable."
      echo "  - Your laptop does NOT need to stay switched ON."
      echo "====================================================================="
      exit 0
    else
      echo "Install failed with code $RES, retrying..."
    fi
  fi
  sleep 1
done

echo "No device detected after 60s. Please ensure USB debugging is enabled."
$ADB devices
exit 1
