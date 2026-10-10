#!/bin/bash
# Launches the built app, lets it close its own window two seconds in, and proves it is still
# running fifteen seconds later. Reason: Prakriti must keep working with its window closed, and
# macOS quits windowless apps on its own unless they opt out (automatic termination).
#   cd ~/Code/prakriti/mac && ./scripts/check-launch.sh
set -euo pipefail
APP="${1:-build/Build/Products/Debug/Prakriti.app}"
LOGDIR="${PRAKRITI_LOG_DIR:-$HOME/Library/Logs/Prakriti/Development}"
LOG="$LOGDIR/$(date +%Y-%m-%d).log"
BIN="$APP/Contents/MacOS/Prakriti"

pkill -f "$BIN" 2>/dev/null || true
sleep 1
BEFORE=$( [ -f "$LOG" ] && wc -l < "$LOG" || echo 0 )
open "$APP" --args --check-keeps-running
sleep 15

if pgrep -f "$BIN" > /dev/null; then
  echo "PASS: still running 15 s after launch (its window closed at 2 s)"
else
  echo "FAIL: the app is not running"; exit 1
fi
NEW=$(tail -n +$((BEFORE + 1)) "$LOG")
if grep -q "Self-check: still running" <<< "$NEW"; then
  echo "PASS: the log says it kept running with no window"
else
  echo "FAIL: no self-check line in $LOG"; exit 1
fi
echo "--- log ---"
echo "$NEW"
pkill -f "$BIN" || true
