#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ADB="${ADB:-/home/arun/android-sdk/platform-tools/adb}"
PKG="com.personal.aistock.dev"

APK=""
for cand in \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-dev-release.apk" \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-dev-arm64-v8a-release.apk" \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-release.apk"; do
  if [ -f "$cand" ]; then
    APK="$cand"
    break
  fi
done

if [ -z "$APK" ]; then
  echo "Error: Dev APK not found. Please build it first."
  exit 1
fi

echo "Checking phone connection status for Dev App..."
for i in {1..60}; do
  LINE=$($ADB devices | grep -v "List of" | grep -w "device" | head -n1)
  if [ -n "$LINE" ]; then
    DEV_ID=$(echo "$LINE" | awk '{print $1}')
    echo "Device detected ($DEV_ID)! Installing Zed Dev APK: $APK"
    $ADB -s "$DEV_ID" install -r "$APK"
    RES=$?
    if [ $RES -eq 0 ]; then
      echo "=== ZED DEV INSTALLATION SUCCESSFUL ==="
      echo "Forwarding ADB reverse port 8000 for local USB debugging..."
      $ADB -s "$DEV_ID" reverse tcp:8000 tcp:8000 2>/dev/null || true
      echo "Launching Zed Dev app on device..."
      $ADB -s "$DEV_ID" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
      exit 0
    else
      echo "Install failed with code $RES, retrying..."
    fi
  fi
  sleep 1
done

echo "Waiting loop ended. Current status:"
$ADB devices
exit 1
