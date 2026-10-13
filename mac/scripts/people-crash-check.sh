#!/bin/bash
# v2 part M6a, docs/v2/PLAN.md M6 check 7's last half: a face step killed with SIGKILL while it works leaves its job
# folder, and the next launch deletes it before its first look through the folders.
#
#   cd ~/Code/prakriti/mac && ./scripts/people-crash-check.sh build/Build/Products/Debug/Prakriti.app ../screens/mac/v2-m6a
#
# Development only: the debug switch --debug-face-scan (Debug builds, never the installed copy, Mac warning 77) runs
# the face step on the two-people-mixed fixture, with its job folder in the DEVELOPMENT Application Support folder.
# The live copy, its store and its folders are never touched.
set -u
APP="${1:?the built app}"
OUT="${2:?a folder for the result}"
mkdir -p "$OUT"
RESULT="$OUT/crash-check.txt"
EXE="$APP/Contents/MacOS/Prakriti"
SUPPORT="$HOME/Library/Application Support/Prakriti/Development"
JOBS="$SUPPORT/Jobs"
FIXTURE="$HOME/Prakriti/Dev/Fixtures/two-people-mixed.mp4"
LOG="$HOME/Library/Logs/Prakriti/Development/$(date +%Y-%m-%d).log"
say() { echo "$1" | tee -a "$RESULT"; }
: > "$RESULT"
say "v2 part M6a crash check, $(date)"
[ -x "$EXE" ] || { say "FAIL: no built app at $APP"; exit 1; }
[ -f "$FIXTURE" ] || { say "FAIL: no fixture at $FIXTURE (make fixtures)"; exit 1; }
if pgrep -f "Prakriti.app/Contents/MacOS/Prakriti --development" >/dev/null; then
    say "FAIL: a development copy is already running; quit it first (the check needs the development lock)."
    exit 1
fi
mkdir -p "$JOBS"
before=$(ls "$JOBS" | wc -l | tr -d ' ')
say "Job folders before: $before"

# 1. The face step, killed while it works.
"$EXE" --development --debug-face-scan="$FIXTURE" >/dev/null 2>&1 &
PID=$!
job=""
for _ in $(seq 1 400); do
    job=$(ls "$JOBS" 2>/dev/null | head -1)
    [ -n "$job" ] && break
    sleep 0.05
done
[ -n "$job" ] || { say "FAIL: the face step never made a job folder"; kill -9 $PID 2>/dev/null; exit 1; }
sleep 1.5
if ! kill -0 $PID 2>/dev/null; then
    say "FAIL: the face step finished before it could be killed (it has to be killed while it works)"
    exit 1
fi
kill -9 $PID
wait $PID 2>/dev/null
say "Killed the face step with SIGKILL 1.5 s after its job folder appeared: pid $PID"
if [ -d "$JOBS/$job" ]; then say "Left by the crash: Jobs/$job (PASS: the crash leaves it)"; else say "FAIL: the job folder vanished without a launch"; exit 1; fi

# 2. The next launch deletes it before its first look.
mark=$(wc -l < "$LOG" | tr -d ' ')
"$EXE" --development >/dev/null 2>&1 &
APPPID=$!
looked=""
for _ in $(seq 1 120); do
    looked=$(tail -n +"$((mark + 1))" "$LOG" | grep -n "Checked " | head -1)
    [ -n "$looked" ] && break
    sleep 0.5
done
kill -TERM $APPPID 2>/dev/null
for _ in $(seq 1 40); do kill -0 $APPPID 2>/dev/null || break; sleep 0.25; done
new=$(tail -n +"$((mark + 1))" "$LOG")
deleted=$(echo "$new" | grep -n "a crash left in" | head -1)
say "Log lines of that launch, in order:"
echo "$new" | grep -E "opened\. Mode|a crash left in|Checked " | head -5 | sed 's/^/  /' | tee -a "$RESULT"
remaining=$(ls "$JOBS" | wc -l | tr -d ' ')
say "Job folders after the launch: $remaining"
if [ -z "$deleted" ]; then say "FAIL: the launch did not say it deleted a job folder"; exit 1; fi
if [ -z "$looked" ]; then say "FAIL: the launch never looked through the folders within 60 s"; exit 1; fi
d=${deleted%%:*}; l=${looked%%:*}
if [ "$d" -lt "$l" ] && [ "$remaining" -eq 0 ] && [ ! -d "$JOBS/$job" ]; then
    say "PASS: the job folder was deleted at launch (log line $d) before the first look (log line $l), and Jobs is empty."
else
    say "FAIL: deleted at line $d, first look at line $l, $remaining job folder(s) left"
    exit 1
fi
