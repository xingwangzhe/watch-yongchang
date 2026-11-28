#!/usr/bin/env bash
set -euo pipefail

adb_cmd() { timeout 60 adb "$@"; }

# KTR R2 uses a 3:2 display. Half-resolution keeps the same dp size at half the render cost.
adb_cmd shell wm size 960x640
adb_cmd shell wm density 210

echo "Installing Android APK"
adb_cmd install --no-streaming game/build/android/watch-yongchang.apk
adb_cmd logcat -c

echo "Launching Android game"
adb_cmd shell monkey -p fun.xingwangzhe.watchyongchang 1
sleep 20

echo "Sending touch movement and attack input"
adb_cmd shell input tap 85 480
adb_cmd shell input swipe 85 480 140 480 700
adb_cmd shell input tap 860 480
sleep 3

mkdir -p ci-artifacts/android/emulator
timeout 30 adb exec-out screencap -p > ci-artifacts/android/emulator/screen.png
test -s ci-artifacts/android/emulator/screen.png
adb_cmd logcat -d -t 3000 > ci-artifacts/android/emulator/logcat.txt
adb_cmd shell pidof fun.xingwangzhe.watchyongchang

if grep -E "FATAL EXCEPTION|Fatal signal|SCRIPT ERROR" ci-artifacts/android/emulator/logcat.txt; then
  echo "Android emulator reported a fatal runtime error" >&2
  exit 1
fi
