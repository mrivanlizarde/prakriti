# 07 · Existing assets, infrastructure and reuse

Research track 07 for Prakriti. Written 2026-10-08 by a Sonny research agent, read-only except
this file. Every claim carries a source: a file path, a command that was run on this Mac on
2026-10-08, or a URL. Anything not verified is marked `[unverified]`; anything worked out from
indirect evidence is marked `[inferred]`. No file in the studio folder was moved, modified,
downloaded or evicted; probes were read-only (`ffprobe`, `ffmpeg ... -f null -`, `ls -lO`, `du`,
`brctl status`, `brctl quota`, `mdls`, `xattr`). Sample frames were written to the session
scratchpad only.

---

## 0. The twelve findings that change the scope

1. **Speaker isolation is NOT trivial on the current recordings.** Every studio file has exactly
   **one** audio track, stereo AAC, and the left and right channels are bit-identical (L minus R
   measures digital silence, -91 dB). It is one mixed mic, duplicated. There is no per-person
   track to pull. (§1.3)
2. **One class recording has no sound at all.** `2026-09-14 20-00-09.mp4` (61 min 42 s, 2.86 GB,
   Gabriel teaching on the floor, video fine) has a completely silent audio track: -91 dB mean
   and max, one silence spanning 0 to 3702.2 s. It is also the only recording with no `.txt`
   beside it. Nobody noticed for 24 days. The quality score and an early "is there sound?"
   alarm are not nice-to-haves; they would have saved a class. (§1.3)
3. **The existing diarization collapses classes into one speaker.** The `.txt` transcripts written
   2026-10-07 (format matches Hark's auto-save `[inferred]`) label almost everything "Speaker 1".
   In the 09-20 class a student talks for minutes about a parent moving in from Phoenix and a new
   apartment, and it is attributed to the same "Speaker 1" as the teacher. Diarization is exactly
   what Ivan offered Serenity as the answer to student privacy (vault debrief, 2026-09-24). On
   this audio it does not yet work. (§1.4)
4. **The fix is upstream and free: configure OBS to record separate tracks.** OBS can write up to
   six audio tracks per recording (mix on track 1, isolated mic(s) and Zoom/desktop audio on
   others) in Advanced output mode. Doing this on the studio Mac turns speaker isolation from a
   model problem into a file read for every recording made after the change. (§1.5)
5. **Recordings are quiet.** Integrated loudness -24 to -36 LUFS against a podcast norm near
   -16; one class peaks at -0.1 dBFS while averaging -35.6 LUFS. Loudness normalisation is a
   required stage, and it will raise the noise floor. (§1.3)
6. **Yin classes are 31 to 41 percent silence** in holds of 10 to 140 s. Any coverage check,
   silence trim or VAD stage must know this, or it will either flag every yin class as broken or
   cut the class out of itself. (§1.3)
7. **R2 is not enabled on Ivan's Cloudflare account.** `wrangler r2 bucket list` against account
   `563eb5c6...` returns `Please enable R2 through the Cloudflare Dashboard. [code: 10042]`. The
   brief assumes R2 exists. It is a dashboard step for Ivan (billing). (§3.4)
8. **A browser cannot push a studio file through a Worker.** Worker request bodies cap at 100 MB
   on Free/Pro plans; a one-hour studio file is 2.6 to 3.3 GB. "Drag and drop a video on a web
   page" must upload straight to R2 (multipart, presigned) or, better, never upload the master at
   all and let a Mac-side worker read the folder. (§3.5)
9. **Ivan has a paid Apple Developer Program membership, but no Developer ID certificate yet.**
   Xcode's team record says `isFreeProvisioningTeam = 0`, `teamType = Individual`, team "Ivan
   Lizarde"; the only signing identity is "Apple Development". A notarised Mac helper app needs
   one Developer ID Application certificate created in Xcode first (the same step already pending
   for Coffee Cup). (§5)
10. **The vault's YouTube quota number is stale.** The content-engine docs say "~6 uploads/day".
    Google's quota page (last updated 2026-09-14) now gives `videos.insert` its own bucket of 100
    calls a day at 1 unit each. The real gate is different: uploads from an **unaudited** API
    project are forced to **private**. (§3.6)
11. **The nightly backup pattern the security baseline points to has never run under launchd.**
    `~/Backups/rowan-agency/backup.log` holds 66 copies of `spawnSync npx ENOENT`; the only backup
    on disk is dated 2026-08-02. launchd agents do not get Homebrew's PATH. Any Prakriti LaunchAgent
    (the folder watcher) will fail the same way unless it uses absolute paths. (§8)
12. **"Sonny must be cheap and self-starting" rules out heavy always-on local daemons**, and Ivan's
    MacBook travels and sleeps. Watching a folder autonomously needs a machine that is awake when
    the studio records. Candidates: the studio Mac (details unknown), the planned 8-bay RAID host,
    or a dedicated always-on Mac. This is a placement decision, not a code one. (§7, §8)

---

## 1. The studio recordings, measured

### 1.1 Folder, sync and sharing state

| Fact | Value | Source |
|---|---|---|
| Path | `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /` (trailing space) | `ls` |
| iCloud Desktop & Documents sync | **ON** (`Desktop & Documents: current=YES`); `~/Library/Mobile Documents/com~apple~CloudDocs/Documents` is a symlink to `~/Documents` | `brctl status`, `ls -la ~/Library/Mobile\ Documents/com~apple~CloudDocs/` |
| Shared item | The **parent** `Galindo x Lizarde` is the shared folder (`kMDItemIsShared = 1`, role `NSURLUbiquitousSharedItemRoleOwner`, so Ivan owns it). Participants not readable from metadata `[unverified]` | `mdls`, `xattr` on the parent |
| Downloaded locally? | **Yes, all 12 .mp4.** No `dataless` flag in `ls -lO` (flags column `-`), allocated blocks equal file size (`du -k` vs `stat -f %z`), and every file's last 5 s decodes clean (`ffmpeg -sseof -5 -i <f> -f null -`) | commands run 2026-10-08 |
| Quarantine xattr | Every .mp4 carries `com.apple.quarantine` and `com.apple.macl` | `ls -la@` |
| Total size | **17.93 GB** for 12 files, 2026-09-06 to 2026-10-02 | `stat` sum |
| iCloud quota left | 1,620,774,245,184 bytes (~1.62 TB) in Ivan's personal account | `brctl quota` |
| Mac disk free | 808 GiB of 1.8 TiB | `df -h ~` |
| Dated subfolders | 9 (`2026-09-06` … `2026-10-02`); OBS file names are `YYYY-MM-DD HH-MM-SS.mp4` | `ls` |

### 1.2 Every file

All files: container MP4 (`major_brand=isom`, muxer tag `encoder=Lavf62.12.102`), video H.264 High,
`yuv420p`, BT.709 limited range, progressive, **29.97 fps (30000/1001)**, ~6.0 Mbps video;
audio AAC-LC 48 kHz **stereo, 1 audio track**. Command:
`ffprobe -v error -show_entries format=...:stream=... -of compact` on each file.

| File | Duration | Resolution | Total bitrate | Audio kbps | Audio tracks | Size | Tail decodes | Content (from .txt head) |
|---|---|---|---|---|---|---|---|---|
| `2026-09-06/2026-09-06 17-43-25.mp4` | 2:33 | 1920×1080 | 6.15 Mbps | 160 | 1 (stereo, dual-mono) | 0.12 GB | yes | Gabriel audio test, "braiding my hair" |
| `2026-09-06/2026-09-06 17-43-25-vertical.mp4` | 2:33 | **1080×1920** | 6.12 Mbps | 127 | 1 | 0.12 GB | yes | same take, vertical canvas |
| `2026-09-06/2026-09-06 18-06-33.mp4` | 55:39 | 1920×1080 | 6.18 Mbps | 160 | 1 | 2.58 GB | yes | Yoga Marga School talk, retreats, "$32,000 in 30 days" |
| `2026-09-06/2026-09-06 18-06-33-vertical.mp4` | 55:39 | **1080×1920** | 6.14 Mbps | 127 | 1 | 2.56 GB | yes | same talk, vertical canvas |
| `2026-09-13/2026-09-13 18-25-44.mp4` | 15:48 | 1920×1080 | 6.17 Mbps | 160 | 1 | 0.73 GB | yes | "life update" talk, addressed to Brenda |
| `2026-09-14/2026-09-14 20-00-09.mp4` | 61:42 | 1920×1080 | 6.18 Mbps | 160 | 1 | 2.86 GB | yes | **class, audio track entirely silent; no .txt** |
| `2026-09-16/2026-09-16 20-03-49.mp4` | 66:16 | 1920×1080 | 6.18 Mbps | 160 | 1 | 3.07 GB | yes | yin class, hybrid with Zoom ("not getting your audio") |
| `2026-09-17/2026-09-17 06-02-43.mp4` | 0:12 | 1920×1080 | 5.91 Mbps | 160 | 1 | 0.01 GB | yes | audio test |
| `2026-09-20/2026-09-20 18-07-58.mp4` | 55:04 | 1920×1080 | 6.18 Mbps | 160 | 1 | 2.55 GB | yes | class opening with a student check-in |
| `2026-09-23/2026-09-23 19-59-52.mp4` | 71:35 | 1920×1080 | 6.18 Mbps | 160 | 1 | 3.32 GB | yes | yin class, students Valor and Brenda named, "Serenity is actually joining us" |
| `2026-09-26/2026-09-26 10-29-54.mp4` | 0:09 | 1920×1080 | 5.82 Mbps | 160 | 1 | 0.01 GB | yes | "press one button" live test |
| `2026-10-02/2026-10-02 15-10-06.mp4` | 0:10 | 1920×1080 | 5.88 Mbps | 160 | 1 | 0.01 GB | yes | "press one button", StudioBinder test |

Storage rate: **2.78 GB per recorded hour** for the horizontal canvas, ~5.5 GB/hour when the
vertical canvas records too (computed from size/duration above).

### 1.3 What the numbers say

**One mic, duplicated.** For six long files, a 60 s window at 10:00 measured with
`pan=mono|c0=c0-c1,volumedetect` returns -91.0 dB mean and max (digital silence), while each
channel alone is -28 to -42 dB mean. L and R are identical. The vertical file differs from its
horizontal twin only by AAC encoding noise (L-R -66.9 dB mean). Source: commands run 2026-10-08.
So there is no isolated voice in any existing recording; isolation would have to be done by a
diarization or source-separation model.

**The silent class.** `ffmpeg -i "2026-09-14/2026-09-14 20-00-09.mp4" -vn -af "pan=mono|c0=c0,volumedetect,silencedetect=noise=-60dB:d=30"`
returns `mean_volume -91.0 dB`, `max_volume -91.0 dB`, `silence_start 0`,
`silence_end 3702.206667`. A frame at 20:00 shows Gabriel in a supine stretch in the studio,
lit by string lights (scratchpad `frames/0914.jpg`). The video is fine; the mic was not captured.
The silence is digital zero, not a quiet room, so this is a routing or mute failure in OBS
`[inferred]`.

**Loudness** (`ebur128=peak=true`, whole file, left channel):

| File | Integrated | Loudness range | True peak |
|---|---|---|---|
| 09-06 talk | -26.8 LUFS | 6.6 LU | -3.0 dBFS |
| 09-13 talk | -29.6 LUFS | 6.2 LU | -3.4 dBFS |
| 09-16 yin class | **-35.6 LUFS** | 16.2 LU | **-0.1 dBFS** |
| 09-20 class | -24.2 LUFS | 20.6 LU | -2.9 dBFS |
| 09-23 yin class | -31.4 LUFS | 16.3 LU | -1.4 dBFS |

The talks are tight (6 LU range) and merely quiet; the classes swing widely, and 09-16 nearly
clips while averaging very low. A podcast master will need loudness normalisation and probably
compression; target values belong to the audio research track.

**Silence in classes** (`silencedetect=noise=-50dB:d=10`): 09-16 has 44 silences of 10 s or more,
1,240 s total (31%), longest 140 s; 09-23 has 38, 1,774 s total (41%), longest 137 s; the 09-20
class has 2 (27 s); the 09-06 talk has none. At -60 dB/30 s the 09-23 class shows a regular
rhythm of ~45 s silences (holds). Gabriel himself floated an audio-only yin class as content
(call transcript, `2026-10-07-call-gabriel-transcript.txt`), where the silence *is* the class.

**Brightness** (keyframes only, `signalstats` YAVG, 0-255 in limited range): 09-06 talk mean 115.6;
09-14 class 93.2; 09-20 class 97.4; 09-23 class 90.1 (min 70.8). Evening classes are darker than
the daytime talk. Keyframe spacing ~1.9 s (1,760 keyframes in 3,339 s), which makes keyframe-only
scans cheap.

**Dual canvas.** `-vertical.mp4` files are a separate 1080×1920 output of the same session with
their own audio encode (127 kbps vs 160). Frame at 20:00 of the vertical file is a tight
centre crop of Gabriel (`frames/0906v.jpg`). This is consistent with an OBS vertical-canvas
plugin such as Aitum Vertical `[unverified]`. Prakriti must pair `X.mp4` and `X-vertical.mp4` as
one session with two renditions, not process them twice (the 2026-10-07 run did transcribe both:
two near-identical `.txt` files, 10,023 and 10,028 words).

**Muxer tag.** `encoder=Lavf62.12.102` means an FFmpeg-based muxer wrote the file (OBS's
ffmpeg-mux path or a remux), not OBS's own Hybrid MP4 writer `[inferred, unverified]`. A plain MP4
writes its index at the end, so a recording in progress, or a crash mid-recording, leaves a file
that cannot be read. OBS's KB: Hybrid MP4 (OBS 30.2+) "remains recoverable even if writing the
file is aborted" (https://obsproject.com/kb/hybrid-mp4). The studio Mac's OBS version and
container settings are unknown `[unverified]`.

### 1.4 The existing `.txt` transcripts

- Written 2026-10-07 between 12:51:00 and 13:04:32, one beside each .mp4 except 09-14
  (`ls -la -T`). Format `Speaker N: <one long block>`, no timestamps, file name = media name with
  `.txt` extension. That matches Hark's auto-save (`dest = job.url.deletingPathExtension().appendingPathExtension(...)`,
  `~/Code/transcribe-app/Sources/Hark/AppModel.swift:237`; `"\(s): \(block.text)"`,
  `Sources/TranscribeCore/SpeakerTranscript.swift:156`) `[inferred]`. No session note records the
  run (`grep` of `00 Sonny/Sessions/`).
- **Throughput** `[inferred from mtimes]`: the 55.7-minute talk finished 2 min 23 s after the
  previous file, so roughly 20 to 25× real time for transcription plus diarization on the M5 Pro.
  About 5.4 h of audio completed in under 14 minutes of wall clock.
- **Diarization result:** 18 `Speaker 1` labels and 9 `Speaker 2` across all files; only 09-23
  has turns at all (15). The 09-20 class opens with a student's personal update (a parent moving
  in, a new apartment, unpaid teaching) under the same `Speaker 1` as the teacher, and the whole
  file is one block. The 09-16 hybrid class is one block.
- **Brand-name errors:** in the 09-06 talk "Yoga Marga" is transcribed correctly 2 times and as
  "Yoga Margot", "Yoga Market" or "Yoga Margo" 4 to 5 times (`grep -o -i`). A vocabulary hint is
  needed (names: Yoga Marga, Gabriel/Gab, Serenity, students' names, Sanskrit pose and
  philosophy terms).
- **Word-rate coverage proxy** (no timestamps to check coverage directly): talk 180 wpm, 09-13 185
  wpm, 09-20 155 wpm, yin classes 75 to 82 wpm (consistent with 31 to 41% silence). Nothing looks
  truncated, but this is a proxy, not the coverage check the skill demands.
- **Privacy:** these transcripts, including students' personal details, now sit inside the shared
  iCloud folder and sync to every participant of `Galindo x Lizarde` `[inferred from sharing
  metadata]`. Prakriti should not write outputs into the input share by default.

### 1.5 What Prakriti must do because of this

- **"New raw material" means a settled file**, not a file event. Settled = not `dataless`,
  size stable across two checks some minutes apart, `ffprobe` reads a duration, and the last
  seconds decode. A plain MP4 is unreadable until OBS closes it, and an iCloud download arrives
  in pieces.
- **Run a sound check first, before anything expensive:** whole-file `volumedetect` on audio
  decodes at ~1,700× real time (observed `speed=1.7e+03x`), so a one-hour file is checked in about
  two seconds. Digital silence, clipping, and loudness are the first three lines of the audio
  quality score.
- **Recommend an OBS change on the studio Mac** (one-time, Gabriel or Ivan at the studio):
  Advanced output mode; track 1 = full mix (keep it, it is what plays); track 2 = Gabriel's mic;
  track 3 = Serenity's mic (when she is in the room); track 4 = Zoom/desktop audio (remote
  students). Tick the tracks in Recording settings. Prefer MKV or Hybrid MP4 so a crash does not
  lose the recording. OBS's KB: "Give each source its own recording track" via Advanced Audio
  Properties; "all standard video players will only play back one audio track at a time"
  (https://obsproject.com/kb/multiple-audio-track-recording-guide). Third-party guides state the
  maximum is six tracks and that multitrack needs Advanced mode
  (https://tsgdoc.socsci.ru.nl/index.php/OBS_Studio/Recording_Multiple_Audio_Sources) `[verify on
  the studio Mac's OBS version]`. Verify the result with `ffprobe` (expect several `codec_type=audio`
  streams), not by watching the OBS meter, which "does not prove that source is stored on a file
  track" (same guides).
- **Room mic vs lavalier:** with two people in one room, each person's mic still picks up the
  other. Separate tracks make isolation far easier but not perfect; a per-track gate or the
  diarizer still runs, just on an easy problem `[inferred]`.

---

## 2. Transcription assets

### 2.1 Hark (`~/Code/transcribe-app`)

- **What:** SwiftPM macOS app + CLI. Apple `SpeechAnalyzer`/`SpeechTranscriber` (macOS 26+,
  on-device, word time ranges and confidence) for words; **FluidAudio** (Apache 2.0, Pyannote on
  CoreML/ANE) for speakers; `TranscriptBuilder` merges by **chunk midpoint**. Outputs txt, srt,
  vtt, markdown, json. Sources: `START_HERE.md`, `README.md`, `PLAN.md`,
  `Sources/TranscribeCore/{Transcriber,SpeakerDiarizer,AudioSource,SpeakerTranscript}.swift`
  (1,605 lines total across all targets).
- **Versions:** `Package.swift` pins FluidAudio `from: "0.12.4"`; `Package.resolved` has
  **0.15.5**. The resolved FluidAudio checkout contains ASR (Parakeet, Cohere, Paraformer,
  SenseVoice), several diarizers (offline Pyannote, Sortformer, LS-EEND), VAD, TTS, and
  **known-speaker enrolment** (`enrollSpeaker` in `Diarizer/Sortformer/SortformerDiarizer.swift:225`,
  `Diarizer/LS-EEND/LSEENDDiarizer.swift:289`; `initializeKnownSpeakers` in
  `Diarizer/Core/DiarizerManager.swift:74`). Hark uses none of the enrolment API: it calls
  `OfflineDiarizerManager(config: .default)` and gets anonymous `Speaker N`. Enrolling Gabriel's
  and Serenity's voices is the obvious next step for "tell it who is in it".
- **Speed:** 2.3 s warm for a 29.5 s two-speaker test (~13×) (`CHANGELOG.md`, 2026-07-21); ~20-25×
  on the studio files `[inferred, §1.4]`.
- **Notifications:** posted via `/usr/bin/osascript display notification`, "Hark is unsandboxed,
  so this is reliable and needs no notification-permission dance" (`Sources/Hark/AppModel.swift:199-205`).
- **Launch path lesson:** "Never decode media from inside an Automator Run Shell Script" (AVFoundation
  decode fails with `_GenericObjCError` inside Automator's inherited sandbox); hand files to the
  app with `open -g -a` (`START_HERE.md`, `install-quick-action.sh`).
- **Build lessons:** pin deployment target to macOS 26 (toolchain defaults to a macOS 28 target
  that runs locally and fails elsewhere); repo lives in `~/Code` because iCloud corrupts builds;
  jobs run one at a time because both engines are heavy (`START_HERE.md`, `CHANGELOG.md`).
- **Distribution:** ad-hoc signed (`codesign --force --deep --sign -`, `make-app.sh`), bundle id
  `com.ivanlizarde.hark`, `LSMinimumSystemVersion 26.0`. Public on GitHub under MIT since
  2026-10-01 (`git remote -v`, `CHANGELOG.md`). Prebuilt `Hark.zip` (arm64, macOS 26+) texted to
  Gabriel 2026-10-01; not notarised, so "Open Anyway" is needed; his source build failed
  (`Sonny/Sonny/20 Projects/Gabriel Galindo — Claude setup.md`).
- **Known gaps** (`PLAN.md`): UI never visually reviewed; no audio player synced to transcript;
  sandbox entitlements unsolved; confidence highlighting not surfaced (but `minConfidence` is
  carried on every block, e.g. 0.604, 0.866).

### 2.2 `~/Code/transcribe-3` (the VN Post War tapes job, 2026-09-01)

- Not an app: scripts. `fw.py` (faster-whisper large-v3, int8, CPU, `vad_filter=False`, beam 5,
  word timestamps, `initial_prompt`), `run_local.sh`, `cloud.sh` (OpenAI
  `gpt-4o-transcribe-diarize`, key from Keychain account `openai_api_key`), `diarize_pyannote.py`
  (pyannote 3.1 + word-midpoint assignment), `reconcile.py` (Whisper vs Parakeet per segment),
  `.venv` with `parakeet-mlx` on Python 3.14 (`.venv/pyvenv.cfg`). Sources: `START_HERE.md`,
  `README.md`, `CHANGELOG.md`, the scripts.
- **Measured speed:** `local-run.log`: 32.8 min tape in 4,933 s and 40.8 min tape in 5,738 s
  (about 0.4× real time while pyannote ran alongside). The vault says ~1.1× alone on the 8 GB M2
  (`60 Reference/Transcribing old audio locally.md`). Not measured on the M5 Pro `[unverified]`.
- **Failure lessons:** WhisperX's VAD gate kept 70 s of a 328 s tape with no warning; pyannote
  split single sentences across speakers and merged a three-way exchange on band-limited audio;
  `TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1` needed under torch 2.6+; Whisper with `language=en` silently
  translates Spanish; the Python 3.9 environment is Xcode's and can vanish with an update.
- Also holds `out/Call with Gabriel Galindo/` (2026-09-13): cleaned.wav, Whisper and Parakeet
  outputs and a reconcile for an Ivan-Gabriel call.

### 2.3 The `transcribe-audio` skill (`~/.claude/skills/transcribe-audio/`)

- `SKILL.md` + `scripts/{fw.py, reconcile.py, run_local.sh, second_engine.sh}` (`fw.py` identical
  to transcribe-3's, `diff` clean). Procedure: preflight, local pass VAD off, **coverage check
  before reading a word**, research the names, second engine (Parakeet), reconcile, hand pass,
  deliver `.txt` beside the audio with a fixed header, verify.
- The coverage check in `run_local.sh` compares the last segment's end to the file duration and
  flags a gap over 15 s. It checks the **tail only**; a hole in the middle, or a yin class's
  legitimate silences, are not modelled. Prakriti needs a coverage check that compares speech
  regions found by an energy detector against regions transcribed.
- The skill is quality-first and hand-reconciled. Prakriti is throughput-first and autonomous.
  Reuse its engines, flags and checks; do not reuse its "Sonny does a hand pass" step for every
  file (it "takes roughly the audio's running time again").

### 2.4 Engines available on this Mac today

Preflight run 2026-10-08: `/usr/bin/python3 -c "import faster_whisper"` prints 1.2.1; Hugging Face
cache holds `faster-whisper-large-v3` (2.9 G), `parakeet-tdt-0.6b-v3` MLX (2.3 G),
`pyannote/speaker-diarization-3.1`, `segmentation-3.0`, `wespeaker-voxceleb-resnet34-LM`,
`speechbrain/spkrec-ecapa-voxceleb`; FluidAudio models in
`~/Library/Application Support/FluidAudio/Models/speaker-diarization`; `/opt/homebrew/bin/whisper`
(openai-whisper); `~/Applications/Hark.app` installed.

| Engine | Where | Speed here | Speakers | Best for | Known failure |
|---|---|---|---|---|---|
| Apple SpeechAnalyzer (via Hark) | `~/Code/transcribe-app` | ~20-25× `[inferred]` | via FluidAudio | Fast first pass, word timings, confidence | Brand names ("Yoga Margot"); macOS 26+ only |
| FluidAudio diarizer | same | included above | anonymous, enrolment available but unused | Speaker turns, known-voice labels | Collapsed the studio classes to one speaker |
| faster-whisper large-v3 | `/usr/bin/python3`, `fw.py` | 0.4-1.1× (M2/contended) | none | Accuracy with a vocabulary prompt | VAD gate data loss; translates other languages |
| Parakeet TDT 0.6B v3 (MLX) | `~/Code/transcribe-3/.venv` | unmeasured, GPU | none | Literal second opinion | n/a recorded |
| pyannote 3.1 | Python | 47 min CPU per 33 min audio | yes | Clean wideband audio only | Split sentences on poor audio |
| OpenAI gpt-4o-transcribe-diarize | cloud, key in Keychain | n/a | yes | Clean audio, speaker labels | Account had no credits (2026-09-01) |

### 2.5 Machine

Apple M5 Pro, 18 cores (6 Super, 12 Performance), 64 GB, MacBook Pro Mac17,8, macOS 27.2
(26B5101f) (`sysctl`, `system_profiler`, `sw_vers`). Node v22.22.0; ffmpeg/ffprobe 9.0.1 with
`h264_videotoolbox`, `hevc_videotoolbox`, `prores_videotoolbox`, `aac_at`, `libmp3lame`,
`libopus`, `libx264`, `libx265`, and the analysis filters `loudnorm`, `ebur128`, `silencedetect`,
`arnndn`, `afftdn`, `blackdetect`, `freezedetect`, `blurdetect`, `scdet`, `signalstats`,
`thumbnail`, `cropdetect`, `showspectrumpic` (no `whisper` filter in this build). `yt-dlp` at
`/opt/homebrew/bin/yt-dlp`. Apps: DaVinci Resolve, Descript, Final Cut Pro Creator Studio,
Compressor Creator Studio, Obsidian (`ls /Applications`). OBS is **not** on this Mac; the studio
Mac records.

---

## 3. Web stack assets

### 3.1 Up Next (`~/Code/up-next`), live at `upnext.therowan.studio`

Cloudflare Worker + D1, plain JavaScript, no framework, no build step; deps `@anthropic-ai/sdk`
^0.131.0, `@simplewebauthn/server` ^14.0.3, `jose` ^6.2.12, `wrangler` ^4.147.0 (`package.json`).
7,884 lines (`wc -l`). `curl https://upnext.therowan.studio/login` returns 200 with the app's
`Permissions-Policy` header, so it is deployed. Note: the decision was Cloudflare Access in front
(`docs/DEPLOY.md` step 0), but `/login` answers directly with no Access redirect `[observed
2026-10-08; whether Access was deliberately deferred is unverified]`.

| Module | Path | What it gives Prakriti |
|---|---|---|
| The gate | `src/index.js` | Worker runs first for every path; a `PUBLIC_FILES` set for the sign-in page; everything else needs a full session. The features-as-login page slots into `PUBLIC_FILES`. |
| Security headers | `src/http.js` | Strict CSP (`default-src 'none'`, no inline script, no third party), HSTS only when not local, nosniff, no-referrer, DENY framing, COOP/CORP, Permissions-Policy. |
| Cookies, JSON helpers, CSRF | `src/http.js` | `__Host-` cookies, `assertSameOriginJson` (Origin + Sec-Fetch-Site + JSON only). |
| Google sign-in | `src/auth/google.js` (169 lines) | OIDC + PKCE, `redirect_uri = ${origin}/auth/google/callback`, optional `GOOGLE_HOSTED_DOMAIN` (`hd`) check, invite-only, Google `sub` bound on first sign-in. |
| Passkeys | `src/auth/passkey.js` (201), `public/assets/webauthn.js` (88) | Touch ID second factor, step-up for sensitive actions, recovery codes. |
| Sessions | `src/auth/session.js` (100) | 256-bit token in cookie, SHA-256 in DB; partial (10 min) vs full; 7-day absolute, 72 h idle; revoke on logout. |
| Rate limits + audit | `src/auth/guard.js` (41) | Table-backed fixed-window limiter (survives isolate churn), audit log with IP hash, cron sweep. |
| Encryption | `src/crypto.js` (190) | `MASTER_KEY` → KEK wraps a per-account DEK; AES-256-GCM bound to `table.column:rowId` as AAD; HMAC blind indexes. |
| Account-scoped store | `src/db.js` (490) | `Store.forAccount(env, id)`; no method takes another account id; all crypto inside. |
| LLM extraction with evidence check | `src/engine/extract.js` (243) | JSON-schema output, `verifyEvidence` (every item must quote the source verbatim), fenced untrusted content, `stop_reason` handling, spend estimate, monthly budget. Model `claude-opus-5-5`, effort `low`, `max_tokens 16000`, `timeout 120_000`, `maxRetries 2`, server-side fallback beta. |
| Ingest loop | `src/engine/ingest.js` (203) | Cron-driven per-account processing. |
| Operator routes | `src/index.js` `/ops/*`, `src/setup.js`, `scripts/{invite,setkey,setuplink}.mjs` | Invite a user, drop a key write-only, a private setup link for someone else to enter keys. |
| Screenshots | `scripts/shoot.mjs` (94) | Headless Chrome over CDP, `--dark`, `--width 390`, `--click`; signs in through `/dev/login`. Hardcodes cookie name `__Host-upnext` and Chrome at `/Applications/Google Chrome.app` (present). |
| Production smoke | `scripts/smoke.mjs` (52) | Refusals tested as refusals against the live URL: CSP, HSTS, framing, redirects, forged session, cross-site POST, dev login absent, operator routes closed. |
| Backups | `scripts/backup.mjs` (44) | 30 nightly encrypted exports to Ivan's machine, refuses to rotate on a small or plaintext-looking export. |
| Tests | `test/{core,security,server}.test.js`, `test/d1shim.js` | 50 tests; `d1shim.js` runs server code against the real migrations on `node:sqlite`. "Check the summary says `skipped 0`" (live tests skip when the dev server is down). |
| Design tokens | `public/assets/base.css` (114) | SF Pro, 17 px body, 1.47 line height, -0.022em, labels 12 px; light and dark via `prefers-color-scheme` plus `data-theme`; buttons, inputs. Decoded Strategies palette (ink, navy, coral) is Kristin's brand, not Prakriti's. |
| Sign-in page | `public/login.html`, `public/assets/login.{css,js}` | Card UI, Google button, passkey step, recovery codes. `noindex, nofollow`. |
| PWA | `public/manifest.webmanifest` | Lets Safari "Add to Dock" make it a Dock app. Up Next's PLAN recommends "Add to Dock now, web push next" for reaching the user (`PLAN.md`). |
| Deploy config | `wrangler.jsonc` | `account_id` pinned (`563eb5c6ada343f86eddc6d77364bbbd`) because wrangler is logged in to six accounts; `assets.directory ./public`, `run_worker_first: true`, `not_found_handling: none`; `routes: [{pattern: "upnext.therowan.studio", custom_domain: true}]`; `workers_dev: false`; `preview_urls: false`; observability on; secrets only via `wrangler secret put`. |
| Docs | `START_HERE.md`, `SECURITY.md`, `docs/DEPLOY.md`, `docs/BUILD-LOG.md` | Threat model written as "who could want in, and what stops them", with the test that proves each control. |

### 3.2 VeraSales (`~/Documents/Claude/Projects/Gabriel Galindo/closer-app`)

Same stack, older and bigger (8,125 lines in `src/`). Production Worker lives in **Gabriel's**
Cloudflare account; the `verasales.ai` zone is in Ivan's, bridged by an edge proxy Worker
(`wrangler.toml`, `edge/wrangler.toml`). Still inside iCloud-synced `~/Documents`, against the
"repos live outside iCloud" rule.

| Module | Path | Reuse value |
|---|---|---|
| Long jobs in a Workflow | `src/workflow.js` (162) | `GenerateWorkflow` with `step.do`, no auto-retry (`retries: {limit: 0, delay ...}`; "`delay` is REQUIRED whenever `retries` is present"), attempt log. The reason: `waitUntil` silently killed every run at 0:30. |
| LLM call layer | `src/llm.js` (1,155) | Streaming with `AbortSignal.timeout(9 min)`; retry only transient statuses (408/409/429/5xx/529) and stream errors; `THINKING_HEADROOM = 40000` added to `max_tokens` because Opus 5.5 always thinks; `readableTail` live preview; refuses platform-key fallback. |
| Model registry | `src/models.js` (110) | Per-model thinking rules and prices: Opus 5.5 $4/$20 always thinks (any `thinking` config is a 400); Sonnet 5.5 $2/$10 optional; Fable 5.1 $10/$50. `thinkingFor`, `costOf`. |
| Secrets at rest | `src/secrets.js` (95) | `enc:v1:` envelope, AES-256-GCM under `KEY_ENCRYPTION_KEY`, fail closed on write, lazy migration. |
| Email | `src/mail.js` (112) | Resend adapter; one request per recipient (Resend rejects a whole request if any recipient is not allowed before domain verification); degrades to "stored, not notified" with no key. |
| Backups | `src/backup.js` (187) | Nightly D1 → private R2, paged streaming, 30 days. "Never add a public r2.dev domain or a custom domain". |
| Auth | `src/auth.js` (61) | Email + password, PBKDF2 100k. Up Next's Google + passkey is the better pattern for Prakriti. |
| CI | `.github/workflows/deploy.yml` | Tests gate deploy; migrations additive-only; secrets pushed from GitHub secrets; `--var BUILD_ID`. |
| Guard tests | `tests/worker-refs.test.mjs`, `tests/ui-smoke.test.mjs` | "Every function the worker CALLS must still be defined"; UI smoke that actually calls render functions, because `node --check` passed three production breakages. |
| Crons | `wrangler.toml` `[triggers]` | "scheduled() routes crons EXHAUSTIVELY; adding one here without a branch there used to mean it silently ran the Fathom poller instead." |

### 3.3 Side by side

| Concern | Up Next | VeraSales | Take for Prakriti |
|---|---|---|---|
| Sign-in | Google + passkey, invite-only | Email + password | Up Next |
| Session | hash-stored, partial/full, idle + absolute | HttpOnly cookie | Up Next |
| Data at rest | per-account DEK, AAD-bound | key column only | Up Next (transcripts of students are sensitive) |
| Store | `Store.forAccount` | tenant tests | Up Next (one account: Yoga Marga; three users) |
| Headers/CSP | strict, tested | partial | Up Next |
| Long jobs | cron + inline | **Workflows** | VeraSales `workflow.js` for anything over 30 s server-side |
| LLM calls | SDK, timeout, evidence check | streaming, headroom, retries, registry | both: Up Next's evidence check + VeraSales' streaming/headroom/registry |
| Email | none | Resend adapter | VeraSales `mail.js` |
| Backups | local encrypted export | D1 → R2 | both, once R2 is enabled |
| Screens | `shoot.mjs` | n/a | Up Next |
| Prod smoke | `smoke.mjs` | n/a | Up Next |
| Deploy | wrangler, account pinned, custom domain | GitHub Action, other account | Up Next's `wrangler.jsonc` shape |

### 3.4 Cloudflare account state (measured 2026-10-08)

- `npx wrangler whoami` (wrangler 4.147.0, OAuth, ilizarde@gmail.com): six accounts: Damaso Lara,
  **Gabriel Galindo** (`ca893bd7...`), **Ivan Lizarde** (`563eb5c6ada343f86eddc6d77364bbbd`),
  Jacob (Amalgamation Pictures), Johan Martinez-Khalilian, Reynaldo Leal. Token scopes include
  workers write, d1 write, queues, pipelines, secrets_store, containers, ai, browser, zone read;
  no R2 scope appears in the list `[whether OAuth can manage R2 once enabled is unverified]`.
- `wrangler d1 list` (Ivan's account): `up-next`, `rowan-agency`, `oxcart`.
- `wrangler r2 bucket list` (Ivan's account): **error 10042, R2 not enabled**.
- DNS: `therowan.studio` NS `howard.ns.cloudflare.com`, `aron.ns.cloudflare.com`;
  `upnext.therowan.studio` resolves to Cloudflare; **`prakriti.therowan.studio` has no record**
  (free to claim with a `custom_domain` route, which creates DNS and certificate itself, per
  `closer-app/edge/wrangler.toml` comment).
- `therowan.studio/.git/config` and `/CLAUDE.md` both 404 (the earlier exposure is closed).

### 3.5 Platform limits that shape the design

- **Worker request body: 100 MB on Free and Pro, 200 MB Business, up to 5 GB Enterprise**
  (https://developers.cloudflare.com/workers/platform/limits/). A one-hour studio file is
  2.6-3.3 GB, so a web drop must go browser → R2 directly (multipart, presigned) or not happen.
- `waitUntil()` "can extend execution for up to 30 seconds after the response is sent" (same page);
  paid CPU up to 5 min per request; 128 MB memory per isolate; cron CPU 30 s (under hourly) or
  15 min. **No media processing (ffmpeg, ASR) can run in a Worker.** It runs on a Mac (or a
  Container, which the token can create, `[unverified for this use]`).
- R2: max object 5 TiB; single PUT 5 GiB; multipart up to 10,000 parts
  (https://developers.cloudflare.com/r2/platform/limits/). Pricing: Standard $0.015/GB-month,
  Infrequent Access $0.01; Class A $4.50/M, Class B $0.36/M; free tier 10 GB-month, 1M A, 10M B;
  **egress free** (https://developers.cloudflare.com/r2/pricing/).
- Storage math `[estimate]`: at a planned ~4 studio hours a week (Sunday talk, Monday and Wednesday
  yin, Serenity Mondays, per the 2026-09-24 debrief) × 2.78 GB/h ≈ 11 GB/week ≈ 48 GB/month ≈
  580 GB/year of masters; ≈ $8.70/month on R2 Standard by year end if masters were kept there.
  Outputs (MP3/M4A, thumbnails, Markdown) are small by comparison.

### 3.6 Publishing APIs (infrastructure constraints only)

- YouTube Data API: "Projects get 100 `search.list` calls and 100 `videos.insert` calls per day …
  plus 10,000 units per day combined for all other endpoints"; "A video upload costs 1 unit"; page
  last updated 2026-09-14 (https://developers.google.com/youtube/v3/getting-started,
  https://developers.google.com/youtube/v3/determine_quota_cost). `thumbnails.set` 50 units,
  `videos.update` 50, `captions.insert` 400.
- "All videos uploaded via the videos.insert endpoint from unverified API projects created after
  28 July 2020 will be restricted to private viewing mode"; "each API project must undergo an
  audit"; max file 256 GB (https://developers.google.com/youtube/v3/docs/videos/insert).
- YouTube scopes are **sensitive** (Google gives deleting a YouTube video as an example), so a
  published OAuth app needs sensitive-scope verification
  (https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification);
  an app left in **Testing** loses grants after 7 days (memory `gmail-access-internal-app.md`, checked
  against Google's help 2026-10-02), which would break autonomous publishing weekly.
- The roadmap page asks Gabriel to "Add me as a manager on the YouTube channel so I can pull the
  archive down" (`Gabriel Galindo/Roadmap/galindo-lizarde-roadmap.html`). How the archive is
  pulled (Studio download, Takeout, yt-dlp with manager cookies) belongs to another track
  `[unverified]`.
- Resend: domains verified so far in the vault are johankhalilian.com and (pending) verasales.ai;
  whether therowan.studio is verified in Resend is `[unverified]` (`20 Projects/Manzanita Kitchen
  — the page.md`, `30 Ventures/Gabriel Galindo — Closer.md`).
- ElevenLabs: no key in Keychain (`security find-generic-password -a elevenlabs_api_key` absent);
  the vault mentions ElevenLabs only as a future option (`00 Sonny/Roadmap.md:55`,
  `00 Sonny/Voice — the design.md:112`). Whose account and plan is `[unverified]`.
- Anthropic: no `anthropic_api_key` Keychain item; Up Next takes the customer's own key, VeraSales
  refuses any platform fallback. Whose key pays for Prakriti is an open question.
- OpenAI: key present in Keychain (account `openai_api_key`); credits were zero on 2026-09-01.

---

## 4. Vault reference notes

**`60 Reference/The web project security baseline.md`** (established 2026-08-02, standing rule):
HTTPS + HSTS (via `_headers` for assets the Worker does not run first for); passwords hashed and
provisioned; honeypot + per-IP table-backed meter on every public form (therowan.agency got bot
rows within hours); sessions expire and revoke server-side, tokens stored as hashes; SameSite +
JSON-only mutations; expiring or hashed magic links; no dead credentials; no secrets in logs;
billing alerts on at project birth; nightly vendor-independent backups with rotation gated on a
healthy write. Structural rules that outrank it: **gate whole origins, not path lists**
(`run_worker_first`); **refusals are tested as refusals**; **a 200 is not proof** (read rows
back); **never RENAME a referenced table** in a migration. Memory `secrets-go-in-apple-passwords.md`
overrides its "1Password" wording: secrets go in Apple Passwords.

**`60 Reference/LLM call traps learned on Closer.md`** (updated 2026-08-05): never `stream: false`
(two silent 10-minute hangs; "the silence is the symptom"); always set `thinking` and `effort`
explicitly; long work never in `waitUntil` (Workflow + explicit status machine
`new | processing | processed | failed`, double-spend guard, 10-minute stale window); **import
must not imply process** (bulk import firing one paid run each); re-baseline cost on real
artifacts (62 min ≈ 75,655 chars ≈ 19k tokens; 2.99 chars/token measured, a guessed 3.7 ran 19%
low); reconcile telemetry against the vendor's bill (Closer's log caught 24-55% of real spend for
two weeks); caching only pays on tokens sent repeatedly and close together (Closer wrote 23,553
cache tokens and read zero; 52% of the bill was output). Plus memory
`a-model-switch-changes-every-request.md` (Opus 5.5 always thinks; 12 of 26 runs truncated after
the switch).

**`60 Reference/Transcribing old audio locally.md`**: the shipped pipeline (ffmpeg mono 16 kHz,
60 Hz high-pass, loudnorm, **no denoiser**; Whisper large-v3 int8 VAD off; Parakeet second
engine; reconcile; research; hand pass); what failed (VAD gate, diarization on similar older male
voices on 3.5 kHz audio, denoising); cost (79 min of audio, ~4 h wall clock on an 8 GB M2).

**`60 Reference/The interface type scale.md`**: tools use SF Pro; page title 34 px Display 600;
section heading 21-24; big number 40; **body 17 px Text, line-height 1.47, tracking -0.022em**;
secondary 15; labels 12 px weight 600 +0.02em; mono only for counts and timestamps; **nothing
below 12 px anywhere**; tracking positive on display, negative on text. **Does not apply to brand
work** (The Rowan Studio carries its own type). Test: "is the reader operating something, or
being spoken to?" For Prakriti: the features/login page is being spoken to (may carry Rowan's
brand type); everything behind sign-in is operated (SF Pro scale).

**`00 Sonny/Capabilities.md`** (updated 2026-09-21): skills (`transcribe-audio`, `ui-cleanup`,
`sonny-reason`, etc.); Oxcart (Worker panel, `watcher.mjs` debounced file watch, launchd agents);
`telegram-media-export`; scheduled tasks `sonny-daily-audit` 07:06 and `sonny-morning-brief` 06:47
→ Telegram (`@ivan_sonny_bot`, hard-wired to one chat id); a warning that `~/.claude/skills/` is
not backed up. Prakriti is not listed yet.

**Stale project docs** (see §11): `Gabriel Galindo/content-engine/{START_HERE,PLAN}.md` (July,
"PLANNING ONLY… Do not start building", "Thumbnails: prompts not images", "~6 uploads/day",
"$0.20/call"); `20 Projects/Gabriel Galindo — Content Engine.md` body below the 10-07 callout.

---

## 5. Apple Developer Program status

- `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier` → `isFreeProvisioningTeam = 0;
  teamName = "Ivan Lizarde"; teamType = Individual;`. A free Personal Team reports 1, so this is a
  **paid individual membership** as of the last Xcode sign-in. Renewal date `[unverified]`.
- `security find-identity -v -p codesigning` → **one** identity: "Apple Development:
  ilizarde@mac.com (K55TBYNKUC)"; certificate subject `OU=LD587PB2H8, O=Ivan Lizarde`
  (team ID LD587PB2H8), valid 2026-06-13 to 2027-06-13.
- **No "Developer ID Application" certificate.** `20 Projects/Coffee Cup.md` (next-action:
  "Create the Developer ID Application certificate in Xcode and store notary credentials
  (`xcrun notarytool store-credentials coffee-cup-notary`), then `make release`") and
  `~/Code/coffee-cup/{Makefile,START_HERE.md}` already hold a working sign → DMG → notarize →
  staple → `spctl` pipeline waiting on that certificate. `~/Code/memory-palace/HANDOFF.md:30` lists
  the same step as pending.
- Consequence: a Prakriti Mac helper can ship **notarised** to Gabriel's M2 and the studio Mac
  after one 20-minute step in Xcode by Ivan (his Apple ID; Sonny cannot enter it). Until then it
  is ad-hoc signed and needs "Open Anyway", as Hark did. Coffee Cup's START_HERE also warns that
  notarising builds made on a macOS beta "occasionally fails on Apple's side" (this Mac runs
  macOS 27.2 build 26B5101f).

---

## 6. The Rowan Studio's design language

Source: `~/Documents/Claude/Projects/The Rowan Studio/site/css/style.css` header and tokens (v5,
"The Atelier"); `site/fonts/`; `site/wrangler.jsonc`; `site/worker/index.js`; `site/robots.txt`.

- "Paper and ink, one blue. Fraunces carries h1 and h2, the wordmark, the signature and the closing
  address. Everything else is the sans. Blue appears only on links, the signature and that address."
- Tokens: `--paper #FAF7F0`, `--ink #1B1916`, `--whisper #716B5C`, `--faded #C9C2B2`,
  `--hair #DDD5C4`, `--blue #0000EE`, `--plate #F1ECE1`; dark: paper `#161513`, ink `#E8E4DB`,
  whisper `#8A857A`, faded `#4A463F`, hair `#2E2C28`, blue `#7B7BFF`, plate `#1E1C19`.
- Type: Fraunces (self-hosted variable woff2, roman and italic, `fonts/fraunces.woff2` 67 KB,
  `fraunces-italic.woff2` 82 KB) for display; `system-ui, -apple-system` for text; body 16 px,
  1.55, -0.005em; labels 11 px uppercase 0.2em in `--whisper` (brand voice, below the tool floor,
  so not for Prakriti's operating screens).
- Layout: `--wrap 1200px`, `--gutter clamp(20px, 5vw, 64px)`; sticky translucent header with hairline;
  quiet reveal motion (`opacity`/`translateY 16px`, 0.8 s) disabled under `prefers-reduced-motion`;
  focus ring 2 px blue.
- Hosting precedent: Worker + Static Assets (not Pages); asset root is `"."` guarded only by
  `.assetsignore`, which leaked CLAUDE.md for ~3 minutes on 2026-10-03 (memory
  `cloudflare-assets-root-is-public.md`). robots.txt blocks AI crawlers. **Do not copy the asset
  root; copy the tokens.**
- `site/CLAUDE.md` is stale (says New York serif, Cloudflare Pages + Formspree, v4); the CSS is
  the truth.
- Recommendation `[inferred]`: Prakriti's public features/login page borrows Rowan's paper, ink,
  hairlines and Fraunces headings (it is a Rowan Studio product on a Rowan subdomain), while the
  signed-in app uses the SF Pro tool scale with Rowan's paper/ink/blue as its palette, not Up
  Next's coral and navy.

---

## 7. Lessons from working memory that apply to Prakriti

From `~/.claude/projects/-Users-ivanlizarde-Documents-Claude-Projects/memory/` (87 files read by
description, the relevant ones in full). One line each.

- `verify-media-by-decoding-its-tail`: a truncated MP4 opens and thumbnails; decode the last seconds of every ingested and every produced file.
- `verify-filter-stages-by-coverage`: every filter (VAD, silence trim, dedupe, "skip short files") must report output coverage against input.
- `transcription-use-the-skill`: transcription runs on the existing skill's engines and checks; do not rebuild them.
- `a-model-switch-changes-every-request`: Opus 5.5 always thinks; budget headroom, check timeouts, read the failure log 24 h after any model change.
- `model-choice-is-the-cost-lever`: price the model ladder from logged usage before any cost engineering; caching is rarely the lever.
- `code-repos-live-outside-icloud`: Prakriti's repo stays at `~/Code/prakriti` (it is; symlinked into the Gabriel folder); never put working media, venvs or caches under `~/Documents`.
- `cloudflare-assets-root-is-public`: site in `public/`, `not_found_handling: "none"`, then `curl /.git/config` must 404; gitignored is not assetsignored.
- `never-overwrite-an-immutable-asset`: a changed output under `/assets/*` gets a new filename; `?v=` is not a cache key on Workers assets.
- `git-init-before-first-deploy`: git init, private remote and first push before the first deploy; read `git status` before staging in any folder that receives outside files.
- `web-security-baseline`: load the vault baseline at the start; gate the whole origin; test refusals.
- `no-hsts-from-local-dev`: send HSTS only over https; use `127.0.0.1` if a pane is poisoned.
- `hidden-preview-pane-freezes-animations`: UI state never waits on an animation; probes use timers and computed style.
- `verify-a-loop-plays-not-that-it-loaded`: any preview player is verified by `paused === false` and `currentTime` advancing twice.
- `render-the-glyph-not-the-table`: render the features page's real strings in the chosen font before shipping.
- `interface-type-scale`: SF Pro 17 px for the operated app; brand type only on the spoken-to page.
- `never-skeuomorphic`: no drawn waveforms-as-tape, film strips, scrub bars, grain or textures; behaviour can be physical, expression stays abstract.
- `never-em-dashes-write-in-ivans-voice`: no em dashes anywhere Gabriel or Serenity read, including generated show notes and titles.
- `agency-copy-voice`: the features page describes, never sells, and never promises what the process will break.
- `secrets-go-in-apple-passwords`: `MASTER_KEY` and any OAuth secret go in Apple Passwords, piped via clipboard.
- `film-stills-have-a-procedure`: 29.97 fps timecode drifts from clock time and `ffmpeg -ss` lands a frame late; thumbnails pulled from transcript timestamps must convert to absolute frames.
- `the-record-is-not-the-thing`: "published" is verified on YouTube/RedCircle, not by Prakriti's own status row.
- `check-a-number-against-its-sibling`: compare each quality score and duration to its sibling (horizontal vs vertical, last week's class) before reporting.
- `close-the-loop-not-just-the-transaction`: after a recording is processed, build what Gabriel and Serenity see next (the package, the notification, the one-tap approve).
- `requests-carry-their-own-mechanism`: any ask to Gabriel/Serenity (OBS settings, consent) ships with a link, a date and a fallback.
- `sonny-must-be-cheap-and-self-starting`: no heavy always-on daemon on Ivan's laptop and no reliance on Ivan remembering; the watcher needs a home that is awake.
- `ivan-pivots-before-finishing`: podcast audio first was agreed; hold the line on one output at a time.
- `build-then-flag-the-assumption` and `deliver-drafts-he-can-finish`: ship the whole package with the open assumption on top, in a form Ivan can edit.
- `long-form-documents-want-to-be-a-page`: the roadmap and the features page are pages with interaction and a scroll indicator, light and dark, phone width.
- `browser-pane-return-does-not-submit`: in-pane form tests click the button; Cloudflare's integrity check 403s Python's default user agent.
- `finalization-layer-zip-and-style-library`: at ship, cut an archive zip and file the reusable pattern.
- `never-invent-a-contact-detail`: Serenity's email is unknown; leave the invite blank until it is in a source.
- `calibrate-claims-to-what-ivan-knows` and `say-the-uncomfortable-thing`: the silent 09-14 class and the diarization collapse are said plainly, up front.
- `name-the-money-question-in-the-moment`: Prakriti is a new build inside a $500/month retainer that both sides said to revisit (call transcript); say it when scope is set.
- `one-recap-at-end-of-day`: Prakriti's notifications to people other than Ivan should batch, not drip `[inferred application]`.

---

## 8. Other infrastructure found on this Mac

- **launchd precedent.** `~/Library/LaunchAgents/com.oxcart.watcher.plist` runs
  `/opt/homebrew/bin/node .../Oxcart/watcher.mjs` with `RunAtLoad`, `KeepAlive`,
  `ThrottleInterval 30`, logs in `/tmp`. It is live (`launchctl list` shows a PID; log lines
  `push ok` every 15 s). `watcher.mjs` uses `fs.watch` per folder, a 2.5 s debounce and a 15 s floor,
  ignores non-`.md` churn, and says plainly "Nothing here is live while the Mac is asleep." Same
  shape fits a Prakriti watcher. Because this node binary already reads `~/Documents` under launchd,
  the Files and Folders permission for Documents is evidently granted to it `[inferred]`; a new
  Swift helper would need its own grant.
- **Do not copy:** that plist carries a live bearer token in plaintext `EnvironmentVariables`
  (value not reproduced here). Prakriti's agent should read secrets from Keychain.
- **The backup agent is broken.** `com.rowan.backup.plist` runs `backup.mjs`, which calls `npx` by
  name; under launchd `npx` is not on PATH: 66 × `spawnSync npx ENOENT` in
  `~/Backups/rowan-agency/backup.log`, one backup on disk (2026-08-02), `launchctl list` last exit 1.
  `studio.dvlpmnt.oxcart.calendar` also shows last exit 1 (cause not checked). No trap note exists
  for the backup failure (`grep` of `50 Traps/`). Lesson for Prakriti: absolute paths for
  `ffmpeg`, `ffprobe`, `node`, or an explicit `PATH` in the plist, and a dated success line per run
  so a dead job is visible.
- **Always-on hardware.** A Mac mini in Johan's office runs Sam (OpenClaw), administered by Ivan
  (`60 Reference/Sam — Johan's agent.md`). Ivan's 8-bay RAID tower is empty and was offered as the
  shared archive drive; the vault disagrees on where it lives (`20 Projects/Yoga Marga.md`: "built
  at Gabriel's"; `Call Debriefs/2026-09-24`: "live at Johan's house on 2-gigabit fibre"). Studio
  Mac model and macOS `[unverified]`. Gabriel's own Mac is an M2, macOS version unknown
  (`20 Projects/Gabriel Galindo — Claude setup.md`).
- **Reach channels already built:** Sonny's Telegram bot (Ivan only), Oxcart panel (Ivan only),
  osascript notifications (Hark), Resend (VeraSales, Jo's site).
- **No archive on disk:** the only Gabriel transcripts on this Mac are two call transcripts in
  `Gabriel Galindo/Transcripts/`; the ~900 archive recordings have no local copy or transcript
  (`ls`, `mdfind`).

---

## 9. Reuse plan: what to copy from where

| Prakriti piece | Copy from | How | Notes |
|---|---|---|---|
| Worker skeleton, gate, routing | `~/Code/up-next/src/index.js` | adapt | Keep `run_worker_first: true` and the `PUBLIC_FILES` set; the features page is `/` or `/login` in that set. |
| Security headers, cookies, CSRF | `up-next/src/http.js` | copy | Add `img-src` for R2-served thumbnails only if served from same origin via the Worker. |
| Google sign-in + passkeys + sessions + recovery | `up-next/src/auth/*`, `public/assets/webauthn.js`, `login.js` | copy | No `GOOGLE_HOSTED_DOMAIN` (mixed accounts). Plan Serenity's passkey enrolment as a guided call (she "needed talking through macOS Passwords step by step", `10 People/Serenity Todesco.md`). |
| Rate limits, audit, sweep | `up-next/src/auth/guard.js` | copy | |
| Encryption + account store | `up-next/src/crypto.js`, `src/db.js` | adapt | One account (Yoga Marga), three users; encrypt transcripts and student-bearing text. |
| Operator invite / setup link | `up-next/scripts/invite.mjs`, `setuplink.mjs`, `src/setup.js` | adapt | For loading the ElevenLabs/YouTube/RedCircle credentials without email. |
| LLM call layer | `closer-app/src/llm.js` (`completeWithRetry`, streaming, `outputBudget`), `src/models.js` | adapt | Plus Up Next's `verifyEvidence` so every chapter title, pull quote and show-note claim must quote the transcript. |
| Long-running server jobs | `closer-app/src/workflow.js` | adapt | Only for server-side steps (LLM passes, publishing). Media work happens on the Mac. |
| Email | `closer-app/src/mail.js` | copy | One request per recipient. |
| Design tokens | Rowan `site/css/style.css` (palette, Fraunces) + `up-next/public/assets/base.css` (SF Pro scale, components) | merge | Rowan colours on Up Next's structure. |
| Screenshots | `up-next/scripts/shoot.mjs` | adapt | Rename cookie, allow unauthenticated shots of the public page. |
| Prod smoke | `up-next/scripts/smoke.mjs` | adapt | Add: `/.git/config` 404, upload endpoint refuses without session, R2 bucket not publicly listable. |
| Tests | `up-next/test/d1shim.js`, `closer-app/tests/{worker-refs,ui-smoke}.test.mjs` | copy | |
| Deploy config | `up-next/wrangler.jsonc` | adapt | `name: prakriti`, `account_id 563eb5c6...`, `routes [{pattern: "prakriti.therowan.studio", custom_domain: true}]`, `workers_dev false`, `preview_urls false`, `assets ./public`, `not_found_handling none`, D1 `prakriti`, R2 binding once enabled. |
| Backups | `up-next/scripts/backup.mjs` | adapt | Fix the launchd PATH lesson from `rowan-backups`. |
| Transcription | Hark `TranscribeCore` (SpeechAnalyzer + FluidAudio) | reuse as a library | Add FluidAudio known-speaker enrolment, a vocabulary hint, timestamps in every output. Second engine (Whisper/Parakeet via `transcribe-audio/scripts`) only for flagged files. |
| Audio preprocessing and checks | `transcribe-audio/scripts/run_local.sh` (ffmpeg chain, coverage), commands in §1 of this file | adapt | Add whole-file silence, clipping, loudness, and speech-region coverage. |
| Folder watcher | `Oxcart/watcher.mjs` + `com.oxcart.watcher.plist` shape | adapt | Watch `.mp4/.mkv/.mov`, not `.md`; settled-file test; absolute binary paths; Keychain for secrets. Or a Swift helper using FSEvents (Apple API track). |
| Notifications | Hark `AppModel.notify` (osascript) | start here | A signed app with `UNUserNotificationCenter` is the durable version (Apple API track). |
| Signing and notarisation | `~/Code/coffee-cup/Makefile`, `START_HERE.md` | copy | After Ivan creates the Developer ID certificate. |
| Project docs | `up-next/{START_HERE,SECURITY}.md`, `docs/DEPLOY.md` | pattern | The four-doc rule from `CLAUDE.md`. |

---

## 10. Load-bearing warnings, each with its reason

1. **Never treat a file-created event as "new raw material".** A plain MP4 has no index until OBS
   closes it, and iCloud delivers files in pieces; an early read either fails or, worse, processes a
   partial file that decodes fine up to where it stops (`verify-media-by-decoding-its-tail`).
2. **Never trust a track count you did not probe.** Every current file has one dual-mono track; a
   pipeline that assumes per-speaker tracks will silently publish the whole room. Probe
   `codec_type=audio` streams on every file and fall back to diarization when there is one.
3. **Never let a diarization label decide what is public on its own.** It merged a student's
   personal story into the teacher's voice on 2026-09-20. Serenity's privacy condition is the
   spec (`20 Projects/Yoga Marga.md`), and Gabriel's "audio only, including the yoga classes"
   instinct collides with it directly.
4. **Never run media work in a Worker or in `waitUntil`.** 100 MB bodies, 128 MB memory, 30 s
   `waitUntil` (Cloudflare limits page); VeraSales lost every run at 0:30 before Workflows.
5. **Never write outputs into the shared input folder by default.** It syncs to every participant
   and spends Ivan's iCloud quota; the 10-07 transcripts with students' details are already there.
6. **Never call a binary by name from a LaunchAgent.** 66 silent nights of `npx ENOENT` in the
   backup log.
7. **Never put secrets in a LaunchAgent plist or under `~/Documents`.** Plists are plain text;
   `~/Documents` uploads to Apple (`code-repos-live-outside-icloud`).
8. **Never publish without a human yes, and never assume an API upload is public.** Standing
   safety rule (BRIEF.md), and YouTube forces unaudited-project uploads to private.
9. **Never let ingestion imply paid processing.** A 900-file archive import must not fire 900 paid
   LLM runs (LLM call traps).
10. **Never ship an LLM call without streaming, explicit effort, thinking headroom and a timeout**
    (LLM call traps; Opus 5.5 always thinks and any `thinking` config is a 400, `closer-app/src/models.js`).
11. **Never deploy without `account_id` pinned.** Wrangler is logged in to six accounts, including
    Gabriel's (`up-next/wrangler.jsonc` comment; `wrangler whoami`).
12. **Never put the site at the asset root.** `public/` only; check `/.git/config` 404 after deploy.
13. **Never VAD-gate or silence-trim a yin class blindly.** 31-41% of it is intentional silence.
14. **Never denoise before ASR** (`Transcribing old audio locally`). Denoising for the podcast
    master is a separate, later stage.

---

## 11. Stale truth found

| Doc | Says | Reality |
|---|---|---|
| `BRIEF.md` "Cloudflare (Workers, D1, R2)" | R2 available | R2 not enabled on Ivan's account (error 10042) |
| `BRIEF.md` "OBS can record separate mic tracks" (task framing) | possible isolation | true of OBS, false of every file recorded so far |
| `Gabriel Galindo/content-engine/START_HERE.md`, `PLAN.md` (July) | "PLANNING ONLY… Do not start building"; Fathom as source; "~6 uploads/day"; "$0.20/call, 300 h ≈ $60" | Superseded by the 10-07 call and Prakriti; quota now 100 `videos.insert`/day; Opus 5.5 costs several times Sonnet 5 |
| `20 Projects/Gabriel Galindo — Content Engine.md` (body) | "Why it's parked", Fathom key questions | Callout at top supersedes; body is history |
| `The Rowan Studio/site/CLAUDE.md` | New York serif, Pages, Formspree, v4 | v5 CSS: Fraunces, Workers Static Assets |
| `transcribe-audio` SKILL.md "on an 8 GB M2" | machine sizing | Ivan now works on an M5 Pro 64 GB; "run engines sequentially on 8 GB" still applies to Gabriel's M2 |
| `up-next/docs/DEPLOY.md` "Cloudflare Access in front" | Access enforced | `/login` answers 200 with no Access redirect `[observed]` |
| Security baseline "nightly backups… `rowan-backups/backup.mjs` is the pattern" | working backups | That agent has failed every night since August |

---

## 12. Open questions (for Ivan unless noted)

1. Which machine is the always-on worker: the studio Mac, a Mac at the RAID's home, or another?
   (Its chip and macOS decide whether Hark's engines run there: Apple Silicon and macOS 26+.)
2. Where does the RAID actually live, Gabriel's or Johan's house? The vault says both.
3. OBS on the studio Mac: version, output mode, container, and will Gabriel let us switch to
   multitrack (mix + per-mic + Zoom)? Who is in the room for each recording type?
4. Who are the participants of the `Galindo x Lizarde` iCloud share?
5. Enable R2 on Ivan's Cloudflare account (dashboard, billing), or keep masters on the RAID and
   put only outputs in the cloud?
6. Whose keys pay: Anthropic, ElevenLabs, YouTube API project, RedCircle? (VeraSales refuses
   platform fallback by design.)
7. Is therowan.studio verified in Resend, if Prakriti emails anyone?
8. Serenity's email address (open trap; `contact@yogamarga…` suggested in July, domain not on file).
9. Create the Developer ID Application certificate (unblocks Coffee Cup too)?
10. Should the 09-14 silent class be raised with Gabriel now, so the next class gets a sound check?
11. Cloudflare Access in front of prakriti.therowan.studio, given that the public page *is* the
    features page? (Access would hide it; the Up Next precedent decided Access but did not apply it.)

---

## 13. Sources

Local (read 2026-10-08):
- `~/Code/prakriti/research/BRIEF.md`, `~/Code/prakriti/research/2026-10-07-call-gabriel-transcript.txt`
- `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /` (12 .mp4, 11 .txt), probed with ffprobe/ffmpeg 9.0.1
- `~/Code/transcribe-app/{START_HERE,README,PLAN,CHANGELOG}.md`, `Package.swift`, `Package.resolved`, `make-app.sh`, `install-quick-action.sh`, `Sources/**`, `.build/checkouts/FluidAudio/Sources/FluidAudio/**`
- `~/Code/transcribe-3/{START_HERE,README,CHANGELOG,research}.md`, `fw.py`, `run_local.sh`, `cloud.sh`, `post_run.sh`, `diarize_pyannote.py`, `reconcile.py`, `local-run.log`, `.venv/pyvenv.cfg`
- `~/.claude/skills/transcribe-audio/SKILL.md`, `scripts/*`
- `~/Code/up-next/{START_HERE,SECURITY,PLAN,CHANGELOG}.md`, `docs/DEPLOY.md`, `wrangler.jsonc`, `package.json`, `src/{index,http,crypto,db}.js`, `src/auth/{session,guard,google}.js`, `src/engine/extract.js`, `scripts/{shoot,smoke}.mjs`, `public/login.html`, `public/assets/{base,login}.css`, `test/d1shim.js`
- `~/Documents/Claude/Projects/Gabriel Galindo/closer-app/{wrangler.toml,package.json,README.md}`, `src/{llm,models,workflow,mail,auth,secrets,backup}.js`, `edge/wrangler.toml`, `.github/workflows/deploy.yml`, `tests/{worker-refs,ui-smoke}.test.mjs`
- `~/Documents/Claude/Projects/Gabriel Galindo/content-engine/{START_HERE,PLAN}.md`, `Roadmap/galindo-lizarde-roadmap.html`, `Transcripts/`
- Vault (`~/Documents/Claude/Projects/Sonny/Sonny/`): `60 Reference/The web project security baseline.md`, `LLM call traps learned on Closer.md`, `Transcribing old audio locally.md`, `The interface type scale.md`, `Sam — Johan's agent.md`; `00 Sonny/Capabilities.md`, `Roadmap.md`, `Voice — the design.md`; `20 Projects/{Gabriel Galindo — Content Engine, Yoga Marga, Coffee Cup, Gabriel Galindo — Claude setup, Kristin Spiotto — Systems Build}.md`; `20 Projects/Call Debriefs/2026-09-24 — Gabriel Galindo and Serenity.md`; `10 People/Serenity Todesco.md`, `Gabriel Galindo.md`; `40 Decisions/2026-10-08 — The content engine is called Prakriti.md`; `50 Traps/{iCloud conflict duplicates break builds, Two months of contacting Serenity directly, and nobody got her email address}.md`
- `~/Documents/Claude/Projects/The Rowan Studio/site/{css/style.css, wrangler.jsonc, .assetsignore, CLAUDE.md, worker/index.js, robots.txt}`
- `~/Documents/Claude/Projects/Oxcart/watcher.mjs`, `~/Library/LaunchAgents/{com.oxcart.watcher,com.rowan.backup}.plist`, `~/Code/rowan-backups/backup.mjs`, `~/Backups/rowan-agency/backup.log`
- `~/Code/coffee-cup/{Makefile,START_HERE.md,PLAN.md}`, `~/Code/memory-palace/HANDOFF.md`
- Memory: `~/.claude/projects/-Users-ivanlizarde-Documents-Claude-Projects/memory/*.md`
- Commands: `brctl status`, `brctl quota`, `mdls`, `xattr`, `sysctl`, `system_profiler SPHardwareDataType`, `sw_vers`, `df -h`, `security find-identity`, `security find-certificate`, `defaults read com.apple.dt.Xcode`, `security find-generic-password -a <name>` (existence only), `npx wrangler whoami`, `wrangler d1 list`, `wrangler r2 bucket list`, `dig`, `curl -I`, `launchctl list`

Web (fetched 2026-10-08):
- Cloudflare Workers limits: https://developers.cloudflare.com/workers/platform/limits/
- Cloudflare R2 limits: https://developers.cloudflare.com/r2/platform/limits/
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/
- OBS multiple audio track guide: https://obsproject.com/kb/multiple-audio-track-recording-guide
- OBS Hybrid MP4: https://obsproject.com/kb/hybrid-mp4
- OBS multitrack (Radboud wiki): https://tsgdoc.socsci.ru.nl/index.php/OBS_Studio/Recording_Multiple_Audio_Sources
- YouTube quota: https://developers.google.com/youtube/v3/getting-started and https://developers.google.com/youtube/v3/determine_quota_cost
- YouTube videos.insert: https://developers.google.com/youtube/v3/docs/videos/insert
- Google sensitive scope verification: https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification
