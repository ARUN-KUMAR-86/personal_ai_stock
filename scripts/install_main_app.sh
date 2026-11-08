#!/usr/bin/env bash
ADB="/home/arun/android-sdk/platform-tools/adb"
APK="/home/arun/personal-ai-stock/app-main-arm64-v8a-release.apk"
PKG="com.personal.aistock"

echo "Checking phone connection status for Main Production App..."
for i in {1..120}; do
  LINE=$($ADB devices | grep -v "List of" | grep -w "device" | head -n1)
  if [ -n "$LINE" ]; then
    DEV_ID=$(echo "$LINE" | awk '{print $1}')
    echo "Device detected ($DEV_ID)! Installing Main Production APK: $APK"
    $ADB -s "$DEV_ID" install -r "$APK"
    RES=$?
    if [ $RES -eq 0 ]; then
      echo "=== MAIN PRODUCTION INSTALLATION SUCCESSFUL ==="
      echo "Setting up ADB reverse port 8000 for local communication..."
      $ADB -s "$DEV_ID" reverse tcp:8000 tcp:8000
      echo "Launching Main app on device..."
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
