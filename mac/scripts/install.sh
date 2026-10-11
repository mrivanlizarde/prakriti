#!/bin/bash
# Installs the built Prakriti into ~/Applications and opens it there: the live watcher, the copy
# that opens at login. Reason: a login item records where the app lives, and the build folder is
# rewritten by every build, so the live copy must live somewhere a build never touches.
#   cd ~/Code/prakriti/mac && make install
# A running live copy is asked to quit first (SIGTERM, which Prakriti treats as Quit: the running
# tool is stopped, and a recording it was making starts again by itself at the next launch).
set -euo pipefail
BUILT="${1:-build/Build/Products/Debug/Prakriti.app}"
DEST="$HOME/Applications/Prakriti.app"
BIN="$DEST/Contents/MacOS/Prakriti"

[ -d "$BUILT" ] || { echo "FAIL: no build at $BUILT (run make build)"; exit 1; }
codesign --verify --deep --strict "$BUILT" || { echo "FAIL: the build is not validly signed"; exit 1; }

if pgrep -f "$BIN" > /dev/null; then
  echo "Asking the installed Prakriti to quit."
  pkill -TERM -f "$BIN" || true
  for _ in $(seq 1 60); do pgrep -f "$BIN" > /dev/null || break; sleep 0.5; done
  if pgrep -f "$BIN" > /dev/null; then echo "FAIL: it did not quit within 30 s; nothing was replaced"; exit 1; fi
fi

mkdir -p "$HOME/Applications"
# Replace the whole bundle, never file by file, so no mixed old and new pieces remain.
rm -rf "$DEST.new"
ditto "$BUILT" "$DEST.new"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"
# The bundle folder keeps the build folder's date (ditto copies it), and macOS keeps an app's icon
# cached against that date: after v2 part M1 changed the icon, Finder's icon for the installed copy was
# still v1's dot until the date changed (measured 11 Oct). A new date makes Finder read the icon again
# (the Dock was not measured). The signature covers the contents, not the folder's date.
touch "$DEST"
codesign --verify --deep --strict "$DEST" && echo "Installed and signed: $DEST"
open "$DEST"
for _ in $(seq 1 30); do pgrep -f "$BIN" > /dev/null && break; sleep 0.5; done
pgrep -f "$BIN" > /dev/null && echo "Running: $(pgrep -f "$BIN")" || { echo "FAIL: it did not start"; exit 1; }
