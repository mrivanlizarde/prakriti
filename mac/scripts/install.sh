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

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Any OTHER copy running in live mode (not --development, not --sample-data) is asked to quit too, and
# LaunchServices is told to forget its bundle. Reason (12 Oct): from 20:13 on 11 Oct the live watcher was
# a Debug build in a verifier's clone under /private/tmp, which LaunchServices had picked by bundle
# identifier. It ran on the live store and folders with no login item, from a folder that gets cleaned
# out, and a fresh install would have handed over to it and quit (one live copy at a time).
STRAYS=()
while read -r pid cmd; do
  [ -n "$pid" ] || continue
  case "$cmd" in "$BIN"*|*--development*|*--sample-data*) continue ;; esac
  STRAYS+=("$pid")
  bundle="${cmd%%/Contents/MacOS/Prakriti*}"
  echo "Another live copy is running (pid $pid) from $bundle. Asking it to quit, and unregistering it."
  kill -TERM "$pid" || true
  [ -d "$bundle" ] && "$LSREGISTER" -u "$bundle" || true
done < <(ps -axo pid=,command= | grep "Prakriti.app/Contents/MacOS/Prakriti" | grep -v grep | sed 's/^ *//')
for pid in "${STRAYS[@]+"${STRAYS[@]}"}"; do
  for _ in $(seq 1 60); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
  if kill -0 "$pid" 2>/dev/null; then echo "FAIL: the other live copy (pid $pid) did not quit within 30 s; nothing was replaced"; exit 1; fi
done

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
# Registered again by path, so a launch by bundle identifier (a notice, the login item) finds this copy.
"$LSREGISTER" -f "$DEST" || true
open "$DEST"
for _ in $(seq 1 30); do pgrep -f "$BIN" > /dev/null && break; sleep 0.5; done
pgrep -f "$BIN" > /dev/null && echo "Running: $(pgrep -f "$BIN")" || { echo "FAIL: it did not start"; exit 1; }
