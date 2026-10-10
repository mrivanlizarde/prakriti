#!/bin/bash
# Milestone 2's check of the REAL app: opens Prakriti with Process File on one file (the same code
# path as File > Process File), waits for the pipeline to finish by reading the development log,
# then captures the real window on Recordings and on that recording's page. No clicks: the app is
# driven by one-word launch flags (--process-file=, --show=, --open=latest).
#   cd ~/Code/prakriti/mac && ./scripts/process-in-app.sh "$HOME/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4" ../screens/mac/m2/real
# It uses the development store, so the recording stays in the app afterwards. Development mode
# refuses anything inside the Studio Recordings folder: use a clip under ~/Prakriti/Dev.
set -euo pipefail
FILE="$1"
OUT="${2:-../screens/mac/latest/real}"
APP="${APP:-build/Build/Products/Debug/Prakriti.app}"
BIN="$APP/Contents/MacOS/Prakriti"
LOG="$HOME/Library/Logs/Prakriti/Development/$(date +%Y-%m-%d).log"
NAME="$(basename "$FILE")"
mkdir -p "$OUT"

pkill -f "$BIN" 2>/dev/null || true
sleep 1
BEFORE=$( [ -f "$LOG" ] && wc -l < "$LOG" || echo 0 )
START=$(date +%s)
open "$APP" --args "--process-file=$FILE" --show=recordings
echo "Opened Prakriti with Process File on $NAME. Waiting for the pipeline (the size must hold still 60 s first)."

DONE=""
for _ in $(seq 1 240); do
  NEW=$(tail -n +$((BEFORE + 1)) "$LOG" 2>/dev/null || true)
  if grep -qE "($NAME).*(ready for your yes)|Filed $NAME as a test|($NAME).*(no usable sound)|Couldn't finish $NAME" <<< "$NEW"; then DONE=yes; break; fi
  pgrep -f "$BIN" > /dev/null || { echo "FAIL: Prakriti quit while working"; exit 1; }
  sleep 2
done
[ -n "$DONE" ] || { echo "FAIL: no result in the log within 8 minutes"; exit 1; }
echo "Finished in $(( $(date +%s) - START )) s from launch. Still running: $(pgrep -f "$BIN" > /dev/null && echo yes || echo no)"
sleep 2
swift scripts/capture-window.swift --window "$APP" "$OUT/m2-real-recordings.png"
pkill -f "$BIN" || true
sleep 2
open "$APP" --args --show=recordings --open=latest
sleep 4
swift scripts/capture-window.swift --window "$APP" "$OUT/m2-real-recording-page.png"
pkill -f "$BIN" || true
echo "--- log ---"
tail -n +$((BEFORE + 1)) "$LOG"
