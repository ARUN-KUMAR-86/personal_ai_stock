#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ADB="${ADB:-/home/arun/android-sdk/platform-tools/adb}"
PKG="com.personal.aistock"

APK=""
for cand in \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" \
  "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-release.apk"; do
  if [ -f "$cand" ]; then
    APK="$cand"
    break
  fi
done

if [ -z "$APK" ]; then
  echo "Error: Release APK not found in mobile/build/app/outputs/flutter-apk/. Please run: cd mobile && flutter build apk --release"
  exit 1
fi

echo "Checking phone connection status for Zed Main Production App..."
for i in {1..60}; do
  LINE=$($ADB devices | grep -v "List of" | grep -w "device" | head -n1)
  if [ -n "$LINE" ]; then
    DEV_ID=$(echo "$LINE" | awk '{print $1}')
    echo "Device detected ($DEV_ID)! Installing Main Production APK: $APK"
    $ADB -s "$DEV_ID" install -r "$APK"
    RES=$?
    if [ $RES -eq 0 ]; then
      echo "=== MAIN PRODUCTION INSTALLATION SUCCESSFUL ==="
      $ADB -s "$DEV_ID" reverse --remove-all 2>/dev/null || true
      echo "Launching Zed on device..."
      $ADB -s "$DEV_ID" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
      echo "Zed is running independently on your phone via 24/7 cloud backend!"
      exit 0
    else
      echo "Install failed with code $RES, retrying..."
    fi
  fi
  sleep 1
done

echo "Waiting loop ended. No device detected."
$ADB devices
exit 1
