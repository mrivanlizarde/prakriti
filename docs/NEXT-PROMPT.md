MY ANSWERS (Sat 10 Oct): (1) The app is for me alone in v1. (2) Local models run in LM Studio (installed). The writing model is Qwen3.8-27B, MLX 8-bit (lmstudio-community/Qwen3.8-27B-MLX-8bit, 29.5 GB, Apache 2.0), which I am downloading myself; load it at a 65,536-token context through LM Studio's local server (start it with `~/.lmstudio/bin/lms server start` if it is off). READ docs/LOCAL-MODEL.md before writing any model code: its six settings (context at load, capped thinking, single-turn roles, JSON validated in Swift, sampling, memory) are load-bearing. Runner-up to compare later: Gemma 4 31B. Ollama is optional, not required. (3) Prakriti is not priced; there is no money gate.

Build Prakriti for Mac v1: a native macOS app that is my control room for Prakriti. Work through the milestones below without me, verify each one yourself, commit after each, and stop only when v1 passes its finish line or you hit a step only I can do.

READ FIRST
~/Code/prakriti/START_HERE.md, PLAN.md, docs/SCOPE.md (§7 engine, §8 notifications, §11 privacy), research/DECISIONS.md, research/02-apple-platform.md, research/03-apple-hig.md, and engine/prakriti.mjs (the working v0 engine: its readiness rules, sound check, coverage check and the two mastering bugs in its comments are load-bearing).

WHO IT IS FOR
Me (Ivan) on my MacBook Pro (M5 Pro, 64 GB, macOS 27.2, Xcode 27). Gabriel and Serenity do not use this app in v1; their review comes later through a private link. Episode 1 (the Sun 6 Sep talk) ships Fri 23 Oct and this build must not get in its way: keep engine v0 running until the app's watcher passes milestone 3, then switch over and retire the LaunchAgent.

WHAT V1 IS
A SwiftUI app (main window plus an optional menu bar menu; the watcher runs as a login item that keeps working when the window is closed or the menu bar icon is hidden).
1. Sources: add or remove watched folders (system Open panel), a drop zone, and "Add file". Per source: which outputs to make automatically, or "Ask me first".
2. Outputs, each a toggle with its own settings, chosen per source and per recording:
   - Working in v1: Podcast episode (MP3; loudness target; trim silence at start and end; intro and outro files; mono/stereo), Transcript (.txt, .srt, .vtt, .md; lexicon of Yoga Marga terms applied), Checks and report (duration, sound, loudness, coverage, speakers-not-checked warning), Titles, show notes and chapters (written by the chosen model).
   - Shown but marked "Not built yet" with one line each: edited video, three thumbnails, shorts, knowledge base, voice dataset.
3. Each recording: status, a step list with timings, the system audio player (no drawn scrubbers or waveforms; the system player's own controls are fine), the transcript (click a line to jump there), trim start and end, mark sections to cut, edit title and notes, "Make again" with changed settings, and "Approve" which copies the finished files to ~/Prakriti/Approved/<name>. Nothing is ever uploaded or published.
4. Models, chosen per task (writing, tagging, summarizing): LM Studio first (Qwen3.8-27B, via its local OpenAI-compatible server), Apple on-device (Foundation Models; only for inputs under its context limit, chunk or refuse beyond it), Ollama (optional), and Claude API (optional; key kept in the Keychain, never in a file). A privacy lock: any recording marked as a class or containing Serenity forces a local model, and the UI says so.
5. Notifications: one per recording, updated in place: New Recording Found (no sound), Started (quiet), Ready for Your Yes (sound), plus Needs a Decision and Couldn't Finish. Copy rules from SCOPE §8.
6. Activity log (every run, including "nothing new") and Settings (folders, model providers, notification choices, a Pause All switch).

HOW TO BUILD IT
- Swift and SwiftUI, macOS 27 target, no App Sandbox (it runs ffmpeg and reads my folders), signed with the Apple Development certificate already in my keychain. Project in ~/Code/prakriti/mac/.
- Reuse what works: call ffmpeg and Parakeet (~/Code/transcribe-3/.venv/bin/parakeet-mlx) as subprocesses with absolute paths, exactly as engine v0 does, before trying Apple SpeechAnalyzer as a second option.
- Keep every rule from v0 and SCOPE: a new file is not a finished recording; sound check first; under 60 s is a test; coverage check after transcription; outputs never written into the shared iCloud folder; unknown voices are treated as students; classes cannot be approved until speaker checks exist.
- Design: Apple's HIG, system font, 17 pt body, nothing under 12 pt, light and dark, never skeuomorphic, no em dashes in any UI text.

MILESTONES (each ends with: build passes, tests pass, the app is launched and screenshotted and you have LOOKED at the screenshot, docs and CHANGELOG updated, one commit with named files, a dated entry in docs/BUILD-LOG.md)
1. Skeleton: app builds and launches; main window with Sources, Recordings, Settings; screenshot.
2. Pipeline in Swift: process one file end to end (port v0); test on the 13 Sep talk (expect about -16 LUFS, peak under -1 dBFS, transcript reaching the end) and on the silent 14 Sep class (expect Needs a Decision, nothing made).
3. Watcher and notifications: a 90-second clip dropped into the drop folder is found, processed and notified with no clicks from you. Then retire engine v0's LaunchAgent and say so in the log.
4. Outputs and settings: toggling outputs changes what gets made; changing the loudness target and remaking a recording produces a different measured result.
5. Recording page: trim, cut, re-make and Approve work on the 13 Sep talk; the approved files are in ~/Prakriti/Approved and the cut sections are really gone (measure duration).
6. Models: titles, show notes and chapters for the 13 Sep talk written by Qwen3.8-27B through LM Studio (valid JSON, every quoted claim found word for word in the transcript), and by Apple on-device for a short input; the privacy lock forces local on a recording marked "class". If the model is not downloaded yet, build everything else and leave this check for last.

FINISH LINE
All six milestones pass their checks on real recordings, and docs/BUILD-LOG.md ends with: what works, what does not, screenshots of every screen, and the three things I should try first.

STOP AND ASK ME ONLY FOR
macOS permission prompts I must click, model downloads over 5 GB, anything that would upload, publish, send or delete outside ~/Prakriti, and signing changes. Everything else: decide, note the decision in BUILD-LOG, keep going. If usage runs out, the next session resumes from BUILD-LOG.

DO NOT
Publish or upload anything; send any message; touch the website or Cloudflare; process the archive Takeout or any class for output; change PLAN.md's dates; store keys in files.
