#!/usr/bin/env bash
ADB="/home/arun/android-sdk/platform-tools/adb"
APK="/home/arun/personal-ai-stock/app-arm64-v8a-release.apk"

echo "Checking phone connection status..."
for i in {1..120}; do
  LINE=$($ADB devices | grep -v "List of" | grep -w "device" | head -n1)
  if [ -n "$LINE" ]; then
    DEV_ID=$(echo "$LINE" | awk '{print $1}')
    echo "Device detected ($DEV_ID)! Installing upgraded APK: $APK"
    $ADB -s "$DEV_ID" install -r "$APK"
    RES=$?
    if [ $RES -eq 0 ]; then
      echo "=== INSTALLATION SUCCESSFUL ==="
      echo "Setting up ADB reverse port 8000 for local communication..."
      $ADB -s "$DEV_ID" reverse tcp:8000 tcp:8000
      echo "Launching app on device..."
      $ADB -s "$DEV_ID" shell monkey -p com.personal.aistock -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
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
