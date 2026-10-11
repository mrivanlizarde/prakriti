#!/bin/bash
# make fixtures: the shared test files of Prakriti for Mac v2 (docs/v2/PLAN.md, section 4).
#
#   cd ~/Code/prakriti/mac && make fixtures
#   cd ~/Code/prakriti/mac && ./scripts/make-fixtures.sh --if-missing   (what make accept runs first)
#
# Every fixture is made from the 13 Sep and 6 Sep talks (Gabriel's, read only) and macOS `say`, into
# ~/Prakriti/Dev/Fixtures and nowhere else. Never a class, never the archive, never the SerenityAI
# download: anything a test needs that the two talks cannot show (a second face, a second voice,
# silence, a second microphone track) is built here instead, so no check ever has to read a class.
#
# The same recipe gives the same bytes every time on this Mac (checked by running it twice and
# comparing SHA-256; `SHA256SUMS` in the folder records the last run, and a rerun says SAME or
# CHANGED for each file). That holds for this ffmpeg build and this macOS voice; another ffmpeg or a
# voice update can change the bytes, which is why the versions are written to RECIPES.txt.
# Reproducible because: no clock or random input; container metadata stripped (-map_metadata -1)
# and written bit-exact (-fflags +bitexact, no "encoder" tag, no creation time); x264 is
# deterministic unless told otherwise; `say` measured byte-identical across runs (11 Oct 2026).
#
# Everything is made in a hidden staging folder, checked (streams, length, the last 5 s decoded),
# and only then moved into place, so a failed run never leaves half a fixture where a test reads it.
# The two talks' size and modification date are checked unchanged at the end.
#
# --if-missing: build only when a fixture is missing (a fresh Mac or a fresh clone), else exit.
set -euo pipefail
cd "$(dirname "$0")/.."

FFMPEG=/opt/homebrew/bin/ffmpeg
FFPROBE=/opt/homebrew/bin/ffprobe
SAY=/usr/bin/say
PYTHON=/usr/bin/python3
STUDIO="$HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings "   # the trailing space is in the name
TALK13="$STUDIO/2026-09-13/2026-09-13 18-25-44.mp4"   # 15:48, Gabriel alone
TALK06="$STUDIO/2026-09-06/2026-09-06 18-06-33.mp4"   # 55:39, Gabriel alone (episode 1)
OUT="$HOME/Prakriti/Dev/Fixtures"
RECIPES="scripts/fixtures"
STAGE="$OUT/.making"

FIXTURES=(13sep-90s.mp4 silent-60s.mp4 two-people-mixed.mp4 two-people-tracks.mov ums-and-retake.wav
          ums-and-retake.txt second-voice.txt synthetic-transcript.json)

if [ "${1:-}" = "--if-missing" ]; then
  missing=0
  for name in "${FIXTURES[@]}"; do [ -f "$OUT/$name" ] || missing=1; done
  if [ $missing = 0 ]; then echo "Fixtures present in $OUT (make fixtures rebuilds them)."; exit 0; fi
  echo "A fixture is missing from $OUT: building them all."
fi

for tool in "$FFMPEG" "$FFPROBE" "$SAY" "$PYTHON"; do
  [ -x "$tool" ] || { echo "FAIL: $tool is not there"; exit 1; }
done
for talk in "$TALK13" "$TALK06"; do
  [ -f "$talk" ] || { echo "FAIL: missing $talk"; exit 1; }
done
fingerprint() { stat -f "%z@%m" "$1"; }
BEFORE13=$(fingerprint "$TALK13"); BEFORE06=$(fingerprint "$TALK06")

mkdir -p "$OUT"
rm -rf "$STAGE"
mkdir -p "$STAGE"
trap 'rm -rf "$STAGE"' EXIT

# Every output is written bit-exact with no metadata carried from the talks.
EXACT=(-map_metadata -1 -map_chapters -1 -fflags +bitexact)
ff() { "$FFMPEG" -hide_banner -nostdin -nostats -v error -y "$@"; }

# The second voice, used twice below. Samantha, as the plan names; brought from the 16.5 LUFS `say`
# writes to about the talk's own loudness (13 Sep measures -26.7 LUFS), so neither voice buries the
# other; 18.7 s of speech padded to exactly 20 s.
SAY_GAIN="-10dB"
VOICE_LEN=20
VOICE_AT=30
step() { printf '%-28s' "$1"; }

step "second voice (say)"
"$SAY" -v Samantha -o "$STAGE/.second-voice.aiff" -f "$RECIPES/second-voice.txt"
cp "$RECIPES/second-voice.txt" "$STAGE/second-voice.txt"
echo "done"

# 1. 13sep-90s.mp4: the 13 Sep talk from 5:00 for 90 s, the streams copied as they are (v1's clip
#    cut, `make drop`), metadata stripped. Fast runs.
step "13sep-90s.mp4"
ff -ss 300 -t 90 -i "$TALK13" -map 0:v:0 -map 0:a:0 -c copy "${EXACT[@]}" "$STAGE/13sep-90s.mp4"
echo "done"
CLIP_LEN=$("$FFPROBE" -v error -select_streams a:0 -show_entries stream=duration -of csv=p=0 "$STAGE/13sep-90s.mp4")

# 2. silent-60s.mp4: the 13 Sep picture from 5:00 for 65 s, its sound replaced by digital silence
#    (AAC, stereo, 48 kHz, as the studio files are). 65 s because under 60 s is a test clip and never
#    reaches the sound check. Replaces the silent 14 Sep class in `make accept` (PLAN M0).
step "silent-60s.mp4"
ff -ss 300 -t 65 -i "$TALK13" -f lavfi -t 65 -i "anullsrc=r=48000:cl=stereo" \
   -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 160k -ar 48000 -ac 2 -t 65 "${EXACT[@]}" "$STAGE/silent-60s.mp4"
echo "done"

# 3. two-people-mixed.mp4: 13sep-90s with the 6 Sep picture (from 3:00) laid in the lower right
#    corner at 30% size (576 by 324, 48 px in from the edges) from 0:20 to 0:60, and the second voice
#    mixed into the single track from 0:30 to 0:50, in both channels as the studio's one microphone
#    is. A second face and a second voice on one mixed track: the diarizer path. The corner face is
#    Gabriel too; with nobody enrolled it is "Unnamed 1", which is all the hiding checks need.
#    Why 3:00: Vision finds his face in every 2 s sample from 3:00 to 3:42 of the 6 Sep talk; from
#    10:12 on it finds none for half a minute, so a 10:00 start gave a corner with no face in it
#    (measured 11 Oct, face counts only).
#    H.264 High, CRF 18, keyframe every 2 s, BT.709 tags as the talks carry; AAC 160 kbps as OBS wrote,
#    coded mid and side with intensity stereo and noise substitution off, so the two channels stay
#    identical, as the studio's are (with ffmpeg's defaults they differed by up to -14.5 dB, measured).
step "two-people-mixed.mp4"
ff -i "$STAGE/13sep-90s.mp4" -ss 180 -t 40 -i "$TALK06" -i "$STAGE/.second-voice.aiff" \
   -filter_complex "\
[1:v]scale=576:324:flags=bicubic,setpts=PTS-STARTPTS+20/TB[corner];\
[0:v][corner]overlay=x=W-w-48:y=H-h-48:enable='between(t,20,60)':eof_action=pass,format=yuv420p[v];\
[2:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=mono,pan=stereo|c0=c0|c1=c0,volume=$SAY_GAIN,apad=whole_dur=$VOICE_LEN,atrim=0:$VOICE_LEN,adelay=${VOICE_AT}s:all=1[second];\
[0:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[talk];\
[talk][second]amix=inputs=2:duration=first:normalize=0[a]" \
   -map "[v]" -map "[a]" -c:v libx264 -preset medium -crf 18 -profile:v high -pix_fmt yuv420p -g 60 \
   -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
   -c:a aac -b:a 160k -ar 48000 -aac_ms 1 -aac_is 0 -aac_pns 0 "${EXACT[@]}" -flags:v +bitexact -flags:a +bitexact \
   "$STAGE/two-people-mixed.mp4"
echo "done"

# 4. two-people-tracks.mov: the same picture (copied) with three tracks, the OBS layout of help
#    article 03: track 1 everything mixed, track 2 the 13 Sep voice alone, track 3 the second voice
#    alone (silent outside 0:30 to 0:50). Each track is one microphone, so each is mono: none is
#    "dual mono" (one microphone copied to two channels, the studio files' problem). The clean-input
#    path: who speaks is read from tracks 2 and 3. AAC 192 kbps mono, 48 kHz.
step "two-people-tracks.mov"
ff -i "$STAGE/two-people-mixed.mp4" -i "$STAGE/13sep-90s.mp4" -i "$STAGE/.second-voice.aiff" \
   -filter_complex "\
[1:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,pan=mono|c0=0.5*c0+0.5*c1,asplit=2[talk1][talk2];\
[2:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=mono,volume=$SAY_GAIN,apad=whole_dur=$VOICE_LEN,atrim=0:$VOICE_LEN,adelay=${VOICE_AT}s:all=1,apad=whole_dur=$CLIP_LEN,atrim=0:$CLIP_LEN,asplit=2[second1][second3];\
[talk1][second1]amix=inputs=2:duration=first:normalize=0[mix]" \
   -map 0:v:0 -map "[mix]" -map "[talk2]" -map "[second3]" -c:v copy \
   -c:a aac -b:a 192k -ar 48000 -ac 1 "${EXACT[@]}" -flags:a +bitexact -f mov "$STAGE/two-people-tracks.mov"
echo "done"

# 5. ums-and-retake.wav: 30 s of `say` (Samantha, 150 words a minute) reading ums-and-retake.txt,
#    which plants, in order: a false start and "let me start over", the restart, an "Um" and an
#    "uh", a stutter ("So so"), and a parallel pair ("When the breath is slow, the mind is slow.
#    When the breath is steady, the mind is steady."). Half a second of silence first, padded to
#    exactly 30 s. 48 kHz mono 16-bit. The rough cut's unit tests know the right answer (PLAN M8).
#    Parakeet hears every planted word (11 Oct); it heard an earlier stutter, "The the", as "that
#    the", so the stutter is "So so", which it writes as said.
step "ums-and-retake.wav"
"$SAY" -v Samantha -r 150 -o "$STAGE/.ums.aiff" -f "$RECIPES/ums-and-retake.txt"
ff -i "$STAGE/.ums.aiff" -af "aresample=48000,adelay=500:all=1,apad=whole_dur=30,atrim=0:30" \
   -ac 1 -c:a pcm_s16le "${EXACT[@]}" -flags:a +bitexact "$STAGE/ums-and-retake.wav"
cp "$RECIPES/ums-and-retake.txt" "$STAGE/ums-and-retake.txt"
echo "done"

# 6. synthetic-transcript.json: a made-up talk (synthetic-talk.txt, about 4,000 words, naming no real
#    person) in Parakeet's JSON shape. Cloud provider tests use it until Gabriel's written yes (D1).
step "synthetic-transcript.json"
"$PYTHON" -I "$RECIPES/synthetic-transcript.py" "$RECIPES/synthetic-talk.txt" "$STAGE/synthetic-transcript.json"

# 7. ivan-plus-13sep.mov, only once Ivan has recorded ivan-clip.mov (his own face and voice, on this
#    Mac, into ~/Prakriti/Dev/Fixtures): 13sep-90s with his clip (its first 80 s) laid in the lower
#    left corner at 324 px high from 0:10, track 1 the mix, track 2 the 13 Sep voice, track 3 his
#    voice. Named and unnamed in one frame (PLAN M7). Never made without his clip.
IVAN="$OUT/ivan-clip.mov"
if [ -f "$IVAN" ]; then
  step "ivan-plus-13sep.mov"
  ff -i "$STAGE/13sep-90s.mp4" -t 80 -i "$IVAN" \
     -filter_complex "\
[1:v]scale=-2:324:flags=bicubic,setpts=PTS-STARTPTS+10/TB[corner];\
[0:v][corner]overlay=x=48:y=H-h-48:enable='between(t,10,90)':eof_action=pass,format=yuv420p[v];\
[0:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,pan=mono|c0=0.5*c0+0.5*c1,asplit=2[talk1][talk2];\
[1:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=mono,adelay=10s:all=1,apad=whole_dur=$CLIP_LEN,atrim=0:$CLIP_LEN,asplit=2[ivan1][ivan3];\
[talk1][ivan1]amix=inputs=2:duration=first:normalize=0[mix]" \
     -map "[v]" -map "[mix]" -map "[talk2]" -map "[ivan3]" -c:v libx264 -preset medium -crf 18 -profile:v high \
     -pix_fmt yuv420p -g 60 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
     -c:a aac -b:a 192k -ar 48000 -ac 1 "${EXACT[@]}" -flags:v +bitexact -flags:a +bitexact -f mov "$STAGE/ivan-plus-13sep.mov"
  echo "done"
  FIXTURES+=(ivan-plus-13sep.mov)
else
  echo "ivan-plus-13sep.mov         not made: ivan-clip.mov is not in $OUT (Ivan records it; optional, PLAN M7)"
fi
rm -f "$STAGE"/.*.aiff

# Check each one before it is moved into place: the streams the plan's table gives, the length, and
# the last 5 seconds decoded with no error.
fail() { echo "FAIL: $*"; exit 1; }
layout() {   # codec_type:codec_name:channels per stream, in order
  "$FFPROBE" -v error -show_entries stream=codec_type,codec_name,channels -of csv=p=0 "$1" \
    | awk -F, '{ if ($2=="video") print $2":"$1; else print $2":"$1":"$3 }' | paste -sd' ' -
}
length() { "$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$1"; }
size() { "$FFPROBE" -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1"; }
tail_decodes() { [ -z "$("$FFMPEG" -hide_banner -nostdin -v error -sseof -5 -i "$1" -f null - 2>&1)" ]; }
within() { awk -v x="$1" -v lo="$2" -v hi="$3" 'BEGIN { exit !(x >= lo && x <= hi) }'; }
expect() {   # file, layout, shortest, longest
  local file="$STAGE/$1" got
  got=$(layout "$file")
  [ "$got" = "$2" ] || fail "$1 streams are '$got', expected '$2'"
  within "$(length "$file")" "$3" "$4" || fail "$1 is $(length "$file") s long, expected $3 to $4"
  tail_decodes "$file" || fail "$1: the last 5 s do not decode"
}
expect 13sep-90s.mp4 "video:h264 audio:aac:2" 89.5 90.5
expect silent-60s.mp4 "video:h264 audio:aac:2" 64.5 65.5
expect two-people-mixed.mp4 "video:h264 audio:aac:2" 89.5 90.5
expect two-people-tracks.mov "video:h264 audio:aac:1 audio:aac:1 audio:aac:1" 89.5 90.5
expect ums-and-retake.wav "audio:pcm_s16le:1" 29.99 30.01
[ ! -f "$STAGE/ivan-plus-13sep.mov" ] || expect ivan-plus-13sep.mov "video:h264 audio:aac:1 audio:aac:1 audio:aac:1" 89.5 90.5
for name in 13sep-90s.mp4 silent-60s.mp4 two-people-mixed.mp4 two-people-tracks.mov; do
  [ "$(size "$STAGE/$name")" = "1920x1080" ] || fail "$name is $(size "$STAGE/$name"), expected 1920x1080"
done
LOUDEST=$("$FFMPEG" -hide_banner -nostdin -nostats -i "$STAGE/silent-60s.mp4" -map 0:a:0 -af volumedetect -f null - 2>&1 \
  | awk '/max_volume/ { print $5 }')
within "$LOUDEST" -999 -60 || fail "silent-60s.mp4's loudest point is $LOUDEST dB, expected at or under -60"
"$PYTHON" -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
words = sum(1 for s in d["sentences"] for t in s["tokens"] if t["text"].startswith(" "))
starts = [t["start"] for s in d["sentences"] for t in s["tokens"]]
assert 3800 <= words <= 4200, words
assert starts == sorted(starts)
assert d["text"] == " ".join(s["text"].strip() for s in d["sentences"])
' "$STAGE/synthetic-transcript.json" || fail "synthetic-transcript.json is not the expected shape"

# The talks were only read.
[ "$(fingerprint "$TALK13")" = "$BEFORE13" ] || fail "the 13 Sep talk's size or date changed"
[ "$(fingerprint "$TALK06")" = "$BEFORE06" ] || fail "the 6 Sep talk's size or date changed"

# Into place, then the record of this run.
for name in "${FIXTURES[@]}"; do mv -f "$STAGE/$name" "$OUT/$name"; done
OLD_SUMS=""
[ -f "$OUT/SHA256SUMS" ] && OLD_SUMS=$(cat "$OUT/SHA256SUMS")
(cd "$OUT" && shasum -a 256 "${FIXTURES[@]}") > "$OUT/.SHA256SUMS.new"
mv -f "$OUT/.SHA256SUMS.new" "$OUT/SHA256SUMS"
{
  echo "Prakriti for Mac v2 fixtures, made by mac/scripts/make-fixtures.sh (recipes in mac/scripts/fixtures)."
  echo "$("$FFMPEG" -hide_banner -version | head -1)"
  echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), say voice Samantha"
  echo "Sources, read only: the 13 Sep talk (13sep-90s, silent-60s, two-people-*) and the 6 Sep talk (the corner picture)."
} > "$OUT/RECIPES.txt"

echo
echo "Fixtures in $OUT:"
while read -r sum name; do
  previous=$(awk -v n="$name" '$2 == n { print $1 }' <<< "$OLD_SUMS")
  if [ -z "$previous" ]; then verdict="new"; elif [ "$previous" = "$sum" ]; then verdict="SAME as the last run"; else verdict="CHANGED since the last run"; fi
  printf '  %-26s %s  %s\n' "$name" "$sum" "$verdict"
done < "$OUT/SHA256SUMS"
echo "  silent-60s.mp4 loudest point: $LOUDEST dB"
echo "The 13 Sep and 6 Sep talks: size and modification date unchanged."
