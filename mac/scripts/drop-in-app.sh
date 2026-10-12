#!/bin/bash
# Milestone 3's check in the REAL app: a fresh 90 s clip, cut with `ffmpeg -c copy` from the 13 Sep
# talk, is moved into a watched drop folder, and nothing else is done. Passes when the app's log
# shows it found, started, made and Waiting for your yes (v1: Ready for your yes), with the notices it sent (or why macOS did
# not show them). No clicks.
#   cd ~/Code/prakriti/mac && ./scripts/drop-in-app.sh development ../screens/mac/m3/real
#   cd ~/Code/prakriti/mac && ./scripts/drop-in-app.sh live ../screens/mac/m3/real
# development: starts a test copy (-n --development) on ~/Prakriti/Dev/Drop if none is running.
# live: the installed copy (~/Applications/Prakriti.app) must already be running; uses ~/Prakriti/Drop.
# The clip is cut into ~/Prakriti/Dev/Clips first and then moved in, as a finished file arrives.
set -euo pipefail
MODE="${1:?development or live}"
OUT="${2:-../screens/mac/latest/real}"
TALK="$HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-13/2026-09-13 18-25-44.mp4"
STAGE="$HOME/Prakriti/Dev/Clips"
STAMP="$(date +%H%M%S)"
NAME="2026-09-13 watcher test $MODE $STAMP.mp4"
mkdir -p "$OUT" "$STAGE"

if [ "$MODE" = development ]; then
  APP="build/Build/Products/Debug/Prakriti.app"
  DROP="$HOME/Prakriti/Dev/Drop"
  LOG="$HOME/Library/Logs/Prakriti/Development/$(date +%Y-%m-%d).log"
  BIN="$APP/Contents/MacOS/Prakriti"
  if ! pgrep -f "$BIN" > /dev/null; then
    BEFORE=$( [ -f "$LOG" ] && wc -l < "$LOG" || echo 0 )
    open -n "$APP" --args --development --show=activity
    for _ in $(seq 1 60); do tail -n +$((BEFORE + 1)) "$LOG" 2>/dev/null | grep -q "Checked .* folder" && break; sleep 1; done
  fi
else
  APP="$HOME/Applications/Prakriti.app"
  DROP="$HOME/Prakriti/Drop"
  LOG="$HOME/Library/Logs/Prakriti/$(date +%Y-%m-%d).log"
  BIN="$APP/Contents/MacOS/Prakriti"
  pgrep -f "$BIN" > /dev/null || { echo "FAIL: the installed Prakriti is not running (make install)"; exit 1; }
fi
pgrep -f "$BIN" > /dev/null || { echo "FAIL: Prakriti is not running"; exit 1; }

/opt/homebrew/bin/ffmpeg -hide_banner -v error -y -ss 300 -t 90 -i "$TALK" -c copy "$STAGE/$NAME"
DUR=$(/opt/homebrew/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 "$STAGE/$NAME")
BEFORE=$( [ -f "$LOG" ] && wc -l < "$LOG" || echo 0 )
mv "$STAGE/$NAME" "$DROP/$NAME"
START=$(date +%s)
echo "Moved $NAME ($DUR s) into $DROP at $(date +%H:%M:%S). Waiting for the app, no clicks."

seen() { tail -n +$((BEFORE + 1)) "$LOG" 2>/dev/null | grep -F "$1" | head -1; }
DONE=""
for _ in $(seq 1 300); do
  NEW=$(tail -n +$((BEFORE + 1)) "$LOG" 2>/dev/null || true)
  if grep -qE "\($NAME\) is (waiting|ready) for your yes|Filed $NAME as a test|\($NAME\) has no usable sound|Couldn't finish $NAME" <<< "$NEW"; then DONE=yes; break; fi
  pgrep -f "$BIN" > /dev/null || { echo "FAIL: Prakriti quit while working"; exit 1; }
  sleep 2
done
END=$(date +%s)
NEW=$(tail -n +$((BEFORE + 1)) "$LOG")
echo "--- log since the move ---"
echo "$NEW"
echo "---"
[ -n "$DONE" ] || { echo "FAIL: no result in the log within 10 minutes"; exit 1; }
FOUND=$(grep -m1 -F "Found $NAME in" <<< "$NEW" | cut -c12-19 || true)
echo "Found at:      ${FOUND:-not logged}"
echo "Result after:  $((END - START)) s from the move"
grep -qE "\($NAME\) is (waiting|ready) for your yes" <<< "$NEW" && echo "PASS: found, made and ready with no clicks" || { echo "FAIL: not ready"; exit 1; }
grep -E "Notice (shown|NOT shown|handed|\(log only\))" <<< "$NEW" | sed 's/^/notice: /' || echo "notice: none logged"
echo "Still running: $(pgrep -f "$BIN" > /dev/null && echo yes || echo no)"
echo "NAME=$NAME"
