# Build log: Prakriti for Mac

One dated entry per milestone of `docs/NEXT-PROMPT.md`, oldest first: what was built, every check
with its measured result, the decisions taken and why, and anything Ivan must do. A new session
resumes from the last entry. Weekdays computed with `date(1)`.

**Where it stands:** v1 reached its finish line on Sat 10 Oct: all six milestones passed on real
recordings, and "Finish line" says what works, what does not, what Ivan must click, where the pictures
of every screen are, and the three things to try first. **The same evening the podcast-ready episode
was added** (the section "Podcast-ready episode"): the file to upload to a podcast host, with its
tags, chapters, captions, a title, show notes and captions text and an upload checklist, on a new
mastering chain that raises the whole episode by one amount (episode 1's loudness range 5.2 LU in
v0's file, 4.7 in the new one; whether the riding Ivan heard is gone is for his ears). Passed on the
6 Sep and 13 Sep talks. **On Sun 11 Oct it gained its episode text and the recording page's Ready to
upload section** (the section "Episode text and Ready to upload"): title and alternatives, one-line
summary, show notes with chapters and a call to action, keywords, a caption and verbatim pull quote
per platform, Ivan's copy rules enforced in Swift, a Copy button for each, and a class never made
ready. Passed on the 13 Sep talk with Qwen3.8-27B. **Both were re-checked by independent verifiers
and passed; the handoff is the last section, "Podcast-ready episode: the handoff"**: what works, the
one claim corrected, what is MISSING by design and how to set it, where episode 1's file is, and what
episode 1 still needs before it is uploaded.
Prakriti for Mac, installed in `~/Applications` (the build of `c91058b` since 03:02 Sun 11 Oct), is
the only thing watching the studio folder and `~/Prakriti/Drop`. Titles, show notes and chapters, and
the podcast-ready episode, can be made but are off for every folder until Ivan turns them on.

---

## Milestone 1: skeleton. Sat 10 Oct 2026

### What was built

- `mac/project.yml` and the generated `mac/Prakriti.xcodeproj`: an app target (`Prakriti`,
  bundle id `studio.therowan.prakriti.app`, macOS 27.0, Swift 6 language mode) and a unit-test
  target (`PrakritiTests`) hosted in the app. `mac/Makefile` wraps every command; `make check`
  runs `mac/scripts/check-launch.sh`.
- **The main window** (`Window`, 1180 by 760, minimum 900 by 600): a sidebar with Today (with a
  count of what needs Ivan), Recordings, Sources, Outputs, Models, Activity and Settings, and a
  Pause All button in the toolbar.
  - **Today:** the date, a headline ("3 recordings need you"), the status line, then "Needs you"
    (Ready for your yes, Needs a decision, Couldn't finish) and "Working now" with the named step
    and a step count.
  - **Recordings:** every recording, newest first, each opening its page (status and reason,
    privacy lock line for a class, steps with timings, results, the original file).
  - **Sources:** each folder with its path, "Make outputs automatically" or "Ask me first", the
    four built outputs as switches, Stop Watching (with a confirmation that says nothing is
    deleted), and Add by hand: a drop zone, Add File, Add Folder. These work and are saved.
  - **Outputs:** the four built outputs with their settings (loudness target, trim silence, intro
    and outro, mono or stereo; transcript formats and the Yoga Marga word list; checks and report;
    titles, show notes and chapters with the writing model named), and five marked "Not built yet"
    with one line each.
  - **Models:** a provider per task (writing, tagging, summarizing), the privacy lock in plain
    words, and LM Studio (`http://localhost:1235/v1`, `qwen/qwen3.8-27b`), Apple on-device, Ollama
    and the Claude API described.
  - **Activity:** every line, grouped by day, newest first.
  - **Settings:** Pause All, Show Prakriti in the menu bar, the folders, one switch per notice with
    its sound described, the model choices, and where the files are.
- **The menu bar menu** (a menu, not a popover): the status line, Open Prakriti, Pause All or
  Resume All, Settings (Command-Comma), Quit Prakriti. The icon is an abstract ring whose shape
  changes with the state (idle, not watching, working, waiting for you, problem, paused).
- **The app keeps running with its window closed:** the app delegate returns false from
  `applicationShouldTerminateAfterLastWindowClosed`, and automatic and sudden termination are off.
- **The data layer** (`mac/Prakriti/Model`): SwiftData models `Source`, `Recording`,
  `OutputSetting`, `Run` (with its ordered `RunStep`s) and `LogEntry`; the status vocabulary of
  SCOPE 9.2; output resolution (recording, then folder, then default); the privacy lock routing (a
  class, or anything with Serenity in it, never reaches the Claude API); seeding on first launch.
- **The log file:** one line per event in `~/Library/Logs/Prakriti/Development/<date>.log`, in
  local time like engine v0's `log.txt`, also mirrored to the unified log.
- **The app icon:** the front door's mark (ultramarine dot on stone), drawn by
  `mac/scripts/make_icon.swift`. Accent color: the front door's ultramarine.

### Checks run, with results

| Check | Result |
|---|---|
| Clean build, `xcodebuild clean build` | `BUILD SUCCEEDED`. **0 compiler warnings** (warnings fail the build). One line of tool output, `appintentsmetadataprocessor ... warning: Metadata extraction skipped`, is Xcode's App Intents step reporting it has nothing to do, not a compiler warning |
| Signature, `codesign -dv` and `codesign --verify --deep --strict` | Authority `Apple Development: ilizarde@mac.com (K55TBYNKUC)`, TeamIdentifier `LD587PB2H8`, flags `runtime` (hardened). Verify passes. Entitlements: `app-sandbox` false (and Xcode's own `get-task-allow` in Debug) |
| Info.plist of the built app | `studio.therowan.prakriti.app`, `LSMinimumSystemVersion` 27.0, `NSSupportsAutomaticTermination` false |
| Unit tests, `make test` | **22 tests, 0 failures**: ModelTests 11, RulesTests 10, SnapshotTests 1 |
| Launch with `open`, self-check closes the window at 2 s | Log: "Self-check: closed 1 window(s)", then "still running 3 s after closing the window. Open windows: 0" |
| Still running a minute later | `pgrep` found it; `ps` showed elapsed **01:23** with no window open |
| `make check` (the scripted version) | PASS: running 15 s after launch; PASS: the log says it kept running |
| Relaunch keeps the store and does not re-seed | Second launch logged no "First start". Store: 1 source (Test drop folder, `~/Prakriti/Dev/Drop`, automatic) and 18 output settings (9 defaults and 9 for that folder) |
| Engine v0 untouched | LaunchAgent `studio.therowan.prakriti` state running; `~/Prakriti/log.txt` kept writing "sweep (timer): nothing new" every 5 minutes through the session. The app created nothing inside `~/Prakriti/Drop` or the studio folder (a test checks every folder it creates) |
| Snapshots, `make snapshots MILESTONE=m1` | **32 PNGs** in `screens/mac/m1/` at 2360 by 1520 px (the 1180 by 760 window at 2x): 7 sidebar screens, the recording page for the 13 Sep talk and for the silent 14 Sep class, and Today empty, each in light and dark (20), plus 12 "-end" pictures of the pages taller than the window. **Every one was opened and looked at** |
| Em dashes | `grep` over `mac/` sources: 0. `RulesTests` fails on any |
| Type floor | `RulesTests` fails on any font outside `AppFont` (17 pt body, 15 secondary, 13 labels, 21 and 28 headings), any built-in text style, any sidebar badge or small control. System controls (pop-up menus, buttons, segmented controls, the window title) draw at the system's 13 pt, above the 12 pt floor |

### What the look-through caught and fixed

Rendering is not the check; looking is. The first renders showed:

- **The sidebar came out blank** (white, even in dark mode). Liquid Glass cannot be drawn into a
  bitmap. Fixed in the test, not the app: the snapshot composes the real `Sidebar` view over the
  system window background (START_HERE, "Load-bearing warnings for the Mac app", 7).
- The selected sidebar row drew as a black bar, and the sidebar icons as faint grey: both
  materials and vibrancy, which a bitmap cannot reproduce. The test swaps the selection material
  for the system's selected-row color. The icons are now tinted with the accent color, which is
  also macOS's default for sidebar icons. **Superseded, and the cause of a real bug:** that tint
  made the selected row's icon vanish in the real window. See "Milestone 1, fixes after the
  independent check" below.
- **Real problems in the app, fixed:** long paths wrapped across two right-aligned lines (now one
  line, home shown as `~`, middle truncated, full path on hover); every output's name appeared
  twice, as a section header and as its switch; two outputs repeated their description in a
  second note; the loudness value sat stranded mid-row away from its stepper and showed "-16.0";
  the Channels control floated mid-row; Today's empty state repeated the headline; a 61:42
  recording read "1 hr 1 min" (now rounded, "1 hr 2 min"); the Models intro left "it." alone on a
  line.

Known snapshot limits, not app bugs: switches and the selected segment draw grey because the test
window is never frontmost (the knob's side shows the state: right is on); the glass material
itself is not in the PNGs, and in the "-end" pictures the text scrolled under the toolbar shows
through it, because the toolbar's blur is glass too. Look at the real window with `make run`.

### Decisions, each with its reason

1. **xcodegen, not a hand-rolled package.** Installed with Homebrew (2.46.0). `project.yml` is the
   source of truth and the generated project is committed too, so a fresh clone opens in Xcode
   without xcodegen.
2. **SwiftData, not a small file store.** The Activity log alone grows by about 290 lines a day
   (a check every 5 minutes), relationships (folder, recording, runs, settings) are real, and
   `@Query` keeps every screen live. It is SQLite under `~/Library/Application Support/Prakriti/`,
   where SCOPE 7.19 puts the engine's state, never under `~/Documents`. Every stored property has
   a default, and enums are stored as raw strings, so additions migrate on their own.
3. **Development mode with its own store, logs and folders** (`~/Prakriti/Dev/...`,
   `.../Development/`). One constant, `AppMode.current`, flips it at the milestone 3 switch-over.
4. **Bundle id `studio.therowan.prakriti.app`,** as the build prompt set. START_HERE's earlier
   proposal (`studio.therowan.prakriti`) is the label engine v0's LaunchAgent already uses. The
   login-item identity for the watcher is decided in milestone 3, against SCOPE 7.2.
5. **Manual signing** with the "Apple Development" identity and team LD587PB2H8. No provisioning
   profile is needed because the app asks for no restricted entitlement. Signing did not block.
6. **Deployment target macOS 27.0:** the SDK in Xcode 27 is 27.0, and the Mac runs 27.2.
7. **Swift 6 language mode, without main-actor-by-default isolation,** so the milestone 2
   pipeline can run its SwiftData work on a background actor.
8. **Settings live in the sidebar,** as asked; Command-Comma opens the main window there rather
   than a second Settings window.
9. **A folder added by hand starts as "Ask me first."** Reason: adding a folder (or 958 archive
   files) must never start work by itself (SCOPE: importing never starts paid work). The drop
   folder starts as automatic.
10. **Titles, show notes and chapters start off.** The writing model holds about 33 GB of memory
    while it runs (docs/LOCAL-MODEL.md); Ivan turns it on per folder or per recording.
11. **Fixtures use real numbers.** The 13 Sep talk (-16.8 LUFS, peak -1.6 dBFS, 2,948 words,
    reaching 15:47 of 15:48), the 14 Sep class (loudest point -91 dB, 1:01:42) and the 6 Sep talk
    (55:39) are engine v0's measurements and `ffprobe` durations. The three short clips are named
    like the test clips milestones 2 and 3 will cut from the 13 Sep talk. No class was processed;
    the 14 Sep class was only measured for its length.

### What does not work yet

No watcher, no pipeline, no notifications, no model calls: those are milestones 2, 3 and 6.
Add File and the drop zone save a recording as Found, and it waits there until the pipeline
exists. Pause All is saved and logged, with nothing yet to pause. The recording page has no
player, transcript, trim, cuts, Make Again or Approve (milestone 5). The Models screen does not
yet check that LM Studio answers, and a Claude API key cannot be added (milestone 6). The menu
bar menu is a system menu, so it is checked by its code and its status-line tests, not by a
picture.

### For Ivan

Nothing is needed from you for milestone 1. To see the real window, with its glass sidebar:

```bash
cd ~/Code/prakriti/mac && make run
```

Clicks coming in milestone 3, each logged here when it is reached: allowing Prakriti's
notifications, allowing it to read the Documents folder (the Studio Recordings folder lives there),
and approving the login item that keeps the watcher running.

### Notes for milestone 2

- Engine v0's three runs of the 13 Sep talk measured -16.6, -17.2 and -16.8 LUFS, so its output
  lands about 0.8 LU under the -16 target (the second pass aims at -15.4 before the limiter). The
  Swift port measures its own output and reports it; the milestone asks for "about -16".
- The rules to port unchanged are in `engine/prakriti.mjs`: readiness, the sound check, under 60
  seconds is a test, the coverage check, and the two mastering bugs in its comments.

---

## Milestone 1, fixes after the independent check. Sat 10 Oct 2026

The independent verifier captured the real running window (`screencapture -l` works on this Mac
without Screen Recording permission) and found one blocking problem the snapshots had hidden, plus
five smaller ones. Each is fixed at its cause, and each fix was checked by a run, a measurement or
a picture that was looked at.

### What was wrong, and what changed

1. **Blocking: the selected sidebar row lost its icon in the real window, light and dark.**
   `MainView.swift` painted every sidebar icon with `.foregroundStyle(.tint)`, the accent color,
   and macOS paints the selected row in that same accent color, so the "Today" sun disappeared.
   The tint had been added to make the snapshot's grey icons look right: an app change made for a
   capture artifact, which START_HERE warning 7 warns against.
   - **App:** the explicit tint is gone. The sidebar colors its own icons: accent at rest, white on
     the selected row. Measured in the real window: the selected row's icon is now 449 to 891
     pixels of near-white on the accent fill, on every screen, light and dark (it was 0 and 1).
   - **Snapshots draw the selection as the real window does.** The sidebar's list takes the focus
     in a window that reports itself frontmost, the selected row is drawn emphasized (white icon
     and label), and the highlight is filled with `controlAccentColor`, which is exactly what the
     real window paints (measured: (35, 55, 198) in light, (68, 92, 236) in dark; the darker
     `selectedContentBackgroundColor` the test used before is not what the window shows). Labels
     and symbols that macOS colors only when it composites the screen (vibrancy) are drawn on top
     with their blend mode, the symbols in the accent color, so the sidebar now matches the real one.
   - **Snapshots check it.** `SnapshotTests` fails if the selected row's icon or label does not
     stand out from the selection (fewer than 150 differing pixels in the icon slot or the label
     slot). **Proved on the bug itself:** with the tint put back, all 32 renders failed, 0 to 5
     pixels standing out; with it removed, all pass.
   - **The milestone check now captures the real window.** `make look` (and the end of
     `make check`) runs `mac/scripts/capture-window.swift`: it opens the real app on the sample
     data (`--sample-data`, in memory, nothing saved, Ivan's store never opened) at each of the
     seven screens in light and in dark, captures the window with `screencapture -l`, and checks
     the selected row's icon and label by their pixels. **Proved on the bug:** the verifier's two
     captures fail it (icon 0 and 1 pixels), and a build with the tint put back failed 10 of 14
     (every screen where the selection is in the accent color; on Recordings and Activity the page
     takes the focus and macOS draws the selection grey, where an accent icon shows).
2. **Recordings drew in a different order from one look to the next** when recordings share a
   session date (four fixtures share 13 Sep, 6:25:44 pm). Both lists now sort with
   `Recording.newestFirst`: the session date, then when it was found, then the path. A test sorts
   four starting orders and gets one list; the light and dark Recordings pictures now match.
3. **The development guard covered only the first-launch setup.** Add Folder, Add File and the drop
   zone accepted the Studio Recordings folder, `~/Prakriti/Drop` or a class file. Now, in
   development, `AppPaths.refusal(for:isFolder:)` refuses anything inside the Studio Recordings
   folder, inside `~/Prakriti` other than `~/Prakriti/Dev`, or inside the SerenityAI archive
   (`~/Downloads/SerenityAI`, private calls), and any folder that holds one of them (watching
   `~/Documents` would take in the studio folder). Paths are compared with symlinks resolved and
   case ignored. A refusal leaves one Activity line and shows an alert with the reason in plain
   words. Live mode refuses nothing here; the switch-over decides. Three tests cover it (nine
   refused folders, a refused class file, archive and v0 drop files, and live mode), and the real
   app shows the alert when asked to add the studio folder (captured, light and dark).
4. **Tooltips drew at 11 pt** (measured: `NSFont.toolTipsFont(ofSize: 0)` is 11.0), under the
   12 pt floor. There were three, not two: Pause All, Add File, and the full path on every path
   row. All are gone. Pause All and Add File now show their names beside their symbols in the
   toolbar; a long path takes a second line under its label, so it can be read in full. A rules
   test fails on any `.help(` or `toolTip`. The alert's message, by contrast, measured 13 pt.
5. **Light snapshots drew the title bar's sidebar button as an empty white circle.** Cause, found
   in the layer tree: the glyph is an image layer with a `vibrantColorMatrix` filter, which a
   bitmap capture skips, and its raw color in light is near-white. The test now draws that glyph
   in the label color. Looked at: dark glyph on white in light, white in dark, as in the real window.
6. **Outputs copy.** "Not built yet" is said once, as the section header, not again on each of the
   five rows. The writing model's name comes from the settings (`qwen/qwen3.8-27b` reads
   "Qwen3.8-27B", by `Format.modelName`, tested) instead of being typed into the view.

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test` | **28 tests, 0 failures**: ModelTests 15, RulesTests 12, SnapshotTests 1 |
| Snapshots, `make snapshots MILESTONE=m1-fix` | 32 PNGs in `screens/mac/m1-fix/`, every one looked at (as contact sheets, then close-ups of the sidebar beside the real window's) |
| Real window, `make look MILESTONE=m1-fix` | **16 of 16 PASS**: 14 screens (selected-row icon 449 to 891 px, label 1,225 to 2,035 px; accent fill (36, 52, 196) light, (68, 92, 236) dark) and the refusal alert in light and dark. Pictures in `screens/mac/m1-fix/real/`, every one looked at |
| Negative control, snapshots | Tint put back: **32 of 32 renders failed** the selected-row check (0 to 5 px). Pictures in `screens/mac/m1-negative/` |
| Negative control, real window | Tint put back: **10 of 14 FAIL** (icon 0 to 4 px), the 4 grey-selection screens pass, as they should. The verifier's two captures also fail (0 and 1 px) |
| `make check` | PASS: still running 15 s after its window closed; PASS: log line; then the real-window capture, all PASS |
| Em dashes in `mac/` (app, tests, scripts, Makefile) | 0 |
| Engine v0 | LaunchAgent `studio.therowan.prakriti` running; `~/Prakriti/log.txt` kept writing "sweep (timer): nothing new"; `~/Prakriti/Drop` empty and untouched. No class or archive file was opened: the refusal tests only build paths |

### Decisions, each with its reason

1. **Fix the app, then make both pictures honest, rather than pick one.** The snapshots stay
   because they reach pages a launch cannot (a recording's page, the scrolled ends, the empty
   state); the real-window capture is the ground truth for what only macOS draws.
2. **Sample-data launch flags are one word each** (`--show=sources`, `--appearance=dark`,
   `--add-folder=/path`). A value given as a separate word reads to macOS as a file to open, and
   an app launched to open a file does not open its window: that cost several runs of "the window
   did not appear". Appearance is set with `.preferredColorScheme`, because setting `NSApp.appearance`
   before launch finished also stopped the window from opening.
3. **The archive is refused in development too,** although the verifier named only the studio
   folder and the drop folder. Reason: the build's do-nots forbid processing the archive, and from
   milestone 2 a hand-added file can be run.
4. **Alerts are allowed, tooltips are not.** Measured: an alert's message draws at 13 pt; a
   tooltip at 11.

### Known snapshot limits (not app bugs)

Switches, selected segments and the window buttons draw grey because a test window is never truly
frontmost (the knob's side shows the state: right is on). In light, sidebar labels come out dark
grey where the real window's are black. The sidebar rows sit about 13 points lower than in the real window. The
snapshot always shows the sidebar focused; on Recordings and Activity the real window gives the
page the focus and draws the selection grey. `make look` shows the real thing.

### For Ivan

Nothing to click. `make look` and `make check` take the screen's focus for about a minute while
they open the app sixteen times; leave the Mac alone while they run.

---

## Milestone 2: the pipeline in Swift. Sat 10 Oct 2026

### What was built

- **`mac/Prakriti/Engine/`, engine v0's `processFile` ported rule for rule.** It knows nothing about
  the store or the window: it takes a file and a folder to write into, reports each step as it
  goes, and returns what it measured.
  - `Subprocess.swift`: every tool by absolute path (`ToolPaths`: ffmpeg, ffprobe, Parakeet,
    brctl), `/opt/homebrew/bin` first on each child's PATH, both pipes read to their end on
    background threads, a time limit per tool (ten minutes plus the recording's length), and the
    tool stopped if the work is cancelled.
  - `Readiness.swift`: v0's `waitUntilReady`. The iCloud placeholder flag (`SF_DATALESS`, read with
    `lstat`, the flag v0 reads through `stat -f %Sf`), `brctl download` and up to an hour's wait;
    the size must hold still (60 s, `stableWait`, configurable so tests can shorten it); ffprobe
    must give a duration; the last 5 seconds must decode.
  - `Measurements.swift`: reading volumedetect, loudnorm's JSON, the ebur128 summary, ffprobe's
    JSON and the transcript's last cue, each tested on output captured on this Mac.
  - `Pipeline.swift`: the steps in order, each timed: Checked the file is complete; under 60 s is
    a test (filed, nothing made); Sound check (loudest point at or under -60 dB, or no audio
    track, is Needs a decision and nothing is made); Audio for the transcript (mono 16 kHz WAV);
    Transcript (Parakeet, `.txt/.srt/.vtt/.json`); Coverage check (last cue within 120 s of the
    end); Episode audio (two-pass loudnorm, mono and 48 kHz inside the chain before
    `alimiter ... level=disabled`, MP3 128k mono); Loudness check (ebur128 integrated loudness and
    true peak of the MP3, its last 5 s decoded, its length within 1 s of the recording); Report.
    `Mastering` holds the chain and its two bug comments.
  - `Report.swift`: v0's REPORT.md, with a table of the steps and their timings added, and one
    line on how loudnorm raised the loudness (see the finding below).
- **`mac/Prakriti/App/PipelineRunner.swift`:** one recording at a time, as v0 does. It writes each
  step onto the recording's run as it happens (so Today, the status line and the page show the
  named step live), then the measurements and the status: Ready for your yes, Skipped (test),
  Needs a decision (no usable sound) or Couldn't finish (the reason in one plain sentence). Every
  run leaves Activity lines and log lines (numbers and file names only). Pause All holds the line;
  a recording already running finishes. Quitting stops the running tool; on the next launch a
  recording left Working is marked Couldn't finish with Try Again. The outputs and the loudness
  target are read from the recording's settings, then its folder's, then the defaults (milestone 4
  checks this end to end).
- **In the app:** File > Process File… (Command-Shift-P) and a Process File… button on Recordings;
  Add File (File menu, and Sources) still only adds. A recording's page has Make Outputs (when
  Found) or Try Again (when Couldn't finish), says when it is waiting its turn, lists the steps
  with timings (steps that never ran in one "Not run" row), and shows Results: the sound in the
  original, the episode's loudness and peak, the transcript's words and reach, the files with Show
  in Finder, and Open Report. The status line names work in progress even before the watcher
  exists ("Working on Sun 13 Sep: making the episode audio").
- **Data:** `Recording` gains `loudestDB`, `averageDB`, `inputLUFS` and `coverageOK` (additions,
  so the store migrates on its own).
- **Launch flags for driving the real app without clicks:** `--process-file=<path>`,
  `--show=<screen>`, `--open=latest` (one word each, like the capture flags).
- **Tests and scripts:** `PipelineTests` (15, in `make test`), `PipelineAcceptanceTests` (`make
  accept`), `SnapshotRenderer` (the drawing code split out of `SnapshotTests` so both can use it),
  `scripts/process-in-app.sh`, and `capture-window.swift --window`.
- **Test clips,** cut with `ffmpeg -c copy` from the 13 Sep talk: `~/Prakriti/Dev/Drop/2026-09-13
  clip 30s.mp4` (30.08 s) and `~/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4` (90.12 s).

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test` | **44 tests, 0 failures, 1 skipped by design** (the acceptance test, which needs `make accept`): ModelTests 15, RulesTests 12, PipelineTests 15, SnapshotTests 1 |
| `make accept MILESTONE=m2`, the 13 Sep talk | **Ready for your yes. Episode -16.8 LUFS, true peak -1.6 dBFS** (ebur128); measured again with loudnorm's own meter: -16.82 LUFS, -1.59 dBTP. Transcript 2,948 words, **last cue 15:47 of 15:48 (gap 0 s)**. REPORT.md, episode.mp3, transcript.txt/.srt/.vtt/.json made; speech.wav removed. 41.1 s, of which: readiness 5.2 s (test wait 5 s), sound 0.6 s, speech audio 0.5 s, Parakeet 10.9 s, coverage 0.0 s, mastering 22.1 s, loudness check 1.8 s |
| The 14 Sep class (silent) | **Needs a decision, nothing made** (no output folder exists). Loudest point -91 dB, average -91 dB, length 1:01:42. Readiness 5.2 s, sound check 1.0 s |
| The 30 s clip | **Skipped, kind Test, nothing made.** 30.08 s |
| The 6 Sep talk (episode 1) | Ready for your yes. -16.7 LUFS, true peak -1.2 dBFS (again: -16.72, -1.22). 9,952 words, 55:38 of 55:39. 128.7 s: Parakeet 35.3 s, mastering 78.2 s |
| **Same as engine v0** | The decoded audio of both episodes is **bit for bit identical** to v0's (`ffmpeg -f md5`: 13 Sep `69658a8c...`, 6 Sep `a202cdac...` on both), and both `.srt` and `.vtt` files are byte-identical to v0's |
| Originals untouched | Size and modification date of all four inputs unchanged after the run (checked by the test) |
| Real app, `scripts/process-in-app.sh` on the 90 s clip | Opened with `--process-file=`, no clicks: Ready for your yes **69 s after launch**, of which readiness 63.9 s (the real 60 s wait), Parakeet 1.5 s; -16.5 LUFS, peak -1.8 dBFS, 241 words, 1:29 of 1:30. Still running afterwards. Both captures looked at |
| `make check MILESTONE=m2` | Tests pass; PASS still running 15 s after its window closed; real-window captures **16 of 16 PASS** (selected-row icon 449 to 891 px, the refusal alert in light and dark) |
| Snapshots | `screens/mac/m2/`: 20 pictures of what the pipeline really processed (Recordings, Today, Activity, the four recording pages, light and dark, with the scrolled ends), 32 sample-data pictures, `real/` 18 real-window captures. **Every one looked at**, as contact sheets and full size |
| Em dashes | 0 in `mac/` (app, tests, scripts, Makefile); `RulesTests` passes. REPORT.md checked by a test too |
| Engine v0 | LaunchAgent `studio.therowan.prakriti` running throughout; `~/Prakriti/log.txt` kept writing "sweep (timer): nothing new"; `~/Prakriti/Drop` empty and `~/Prakriti/Outputs` untouched |

The numbers above are from the second `make accept` run on the final code; the first run, before the
look-through changes, measured the same audio, words and coverage. Full text:
`screens/mac/m2/acceptance.txt` (gitignored).

### Found while porting: loudnorm has never stayed linear on these talks

The port reports what loudnorm's second pass says it did. On every studio talk it says
**`dynamic`**, not `linear`, although v0 asks for `linear=true`. The reason is arithmetic: the 13 Sep
talk measures -26.67 LUFS with a true peak of -0.38 dBTP on the mono mix, so raising it evenly to
-15.4 means +11.3 dB and peaks near +11 dBTP, far past the -1.5 ceiling. loudnorm then falls back,
silently, to riding the level moment to moment. SCOPE 7.11 predicted exactly this (finding E23) and
says a dynamic result is "worth a look". Engine v0 has done the same on every episode it made,
including episode 1 (the 6 Sep talk, bit-identical here), without saying so. It is also why the
result lands about 0.8 LU under the -16 target.

Not changed in this milestone, on purpose: the build asked for a faithful port, the 13 Sep talk
passes (-16.8 is inside -17 to -15, by 0.2 LU), and episode 1 is already made by v0 with this chain.
REPORT.md and the Episode audio step now say it in plain words ("leveled moment to moment, not
evenly, so it is worth a listen"). The fix belongs in milestone 4, where loudness is a setting:
SCOPE 7.11's order (mono, a gentle compressor, then loudnorm with an explicit LRA, then a true-peak
limiter), or an even gain to the target followed by the limiter, checked by `normalization_type`
reading `linear` and by ear on the 13 Sep talk.

### What the look-through caught and fixed

- **Seven "Skipped" rows** on a test clip's page, six on the silent class's: the steps that never
  ran are now one "Not run" row that names them.
- **The Report step's detail was a file name** ("REPORT.md."): now "Written to REPORT.md, beside the
  episode."
- **The leveling mode was invisible in the app:** it is now in the Episode audio step's detail.
- **A test of mine was wrong, not the app:** the whole-chain test on a generated tone expected the
  coverage check to fail, but a 65 s file can never be more than 120 s short. Parakeet writes an
  empty transcript for a tone (checked by hand), so the test now uses 150 s and passes.

### Decisions, each with its reason

1. **A faithful port first,** proved by identical decoded audio and transcripts, before any change to
   what comes out. Reason: two mastering bugs were found only by measuring; the port must not
   bring new ones in quietly. Three additions only report or check, and change no audio:
   `print_format=json` on the second pass (to read `normalization_type`), `framelog=verbose` on
   the ebur128 check (hides 100 ms lines; the summary is identical), and the MP3 length check
   (within 1 s of the recording; SCOPE 7.4 "duration out equals duration in").
2. **No transcript files after Parakeet is Couldn't finish.** v0 carried on and reported 0 words.
   An empty transcript (no speech) still counts as a transcript, and the coverage check then says
   it stops early.
3. **A coverage miss stays Ready for your yes, with the reason first,** as in v0, and its Activity
   line is marked for attention. Reason: the gap may be silence; Ivan listens before trusting it.
4. **One at a time; Pause All holds the line, the running one finishes.** Reason: v0's behavior, and
   stopping mid-run would leave half-made files.
5. **Every tool has a time limit (ten minutes plus the recording's length).** Reason: one at a time
   means a hung tool would hold every later recording; SCOPE 7.2 asks for a timeout on every job.
6. **By-hand runs try once,** with Try Again on the page. v0 retries three times in its sweep; the
   watcher (milestone 3) brings automatic retries back.
7. **Process File adds and starts; Add File only adds.** Process File took the Recordings toolbar
   button, because a file added from there is a file Ivan wants made. Add File stays in the File
   menu and on Sources; its recordings wait as Found with Make Outputs on their page.
8. **The acceptance test is the only code that reads the Studio Recordings folder in development,**
   and only the three files the build prompt named, read-only, with a check that each is unchanged.
   The app itself still refuses that folder in development. Reason: student privacy; v0 owns it.
9. **The acceptance test clears its own output folders first,** only inside `~/Prakriti/Dev/Outputs`.
   Reason: an old folder would hide a new "nothing made" mistake.
10. **The acceptance test writes its run lines to the development log,** with its store in memory.
    Reason: the log lines are part of what is being checked.
11. **Notifications wait for milestone 3.** The pipeline reports the same moments v0 notifies on
    (found, started, ready, needs a decision, couldn't finish), so the notification builder can hook
    in without changing it.
12. **Outputs keep v0's layout,** `Outputs/<file name without extension>/`, so the switch-over does
    not move anything Ivan already knows where to find.

### What does not work yet

No watcher, no notifications, no automatic retries (milestone 3). Readiness is v0's, not yet SCOPE
7.3's fuller rule (5 minutes of stability with no file events, the MP4 index check, reading through
`NSFileCoordinator` from a `clonefile` copy). Trim silence, intro and outro, stereo, the `.md`
transcript and the Yoga Marga word list are settings that do nothing yet (milestone 4). No player,
transcript view, trim, cuts, Make Again or Approve (milestone 5); no models (milestone 6). "Needs a
decision" has no decision buttons yet. Speakers are not checked, and the report says so.

### For Ivan

Nothing to click for this milestone. Two things worth your ears and eyes:

1. **Listen to episode 1 before Fri 23 Oct for the level riding up and down,** especially quiet
   passages that come up and louder ones that sit down. Engine v0's chain leveled it moment to
   moment rather than evenly (above). If it sounds natural, nothing needs to change for episode 1;
   if it pumps, milestone 4's fix can remake it.
2. The 13 Sep talk passes the loudness check by 0.2 LU (-16.8 against a floor of -17). It is the
   same file v0 made, so this is not new, but it is the margin a slightly quieter talk could miss.

To see it yourself:

```bash
cd ~/Code/prakriti/mac && make run
```

Then File > Process File… and choose `~/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4` (about 70
seconds, most of it the 60-second check that the file has finished copying).

### Notes for milestone 3

- The watcher feeds `model.runner.enqueue(recording, trigger: .fileEvent)`; the queue, the status
  line and the recording page already handle waiting, working and every outcome.
- The development store holds one processed recording, the 90 s clip in `~/Prakriti/Dev/Clips`. The
  30 s clip in `~/Prakriti/Dev/Drop` is **not** in it (the acceptance test's store is in memory), so
  a first sweep of the drop folder will find it and file it as a test. Cut a fresh 90 s clip with a
  new name for the "dropped and notified" check.
- Reading the Studio Recordings folder from the real app will need Ivan's click on the Documents
  permission prompt at the switch-over (tests ran under xcodebuild, which already has access).

---

## Milestone 3: the watcher, notifications, and the switch-over from engine v0. Sat 10 Oct 2026

### What was built

- **The watcher** (`mac/Prakriti/App/Watcher.swift`, `Engine/EventStream.swift`, `Engine/FolderScan.swift`).
  - FSEvents, file by file, over every source, with the newest event id saved after each batch
    (with the disk's id) and passed back on launch, so changes made while Prakriti was closed are
    replayed. Dropped or merged events, or a watched folder moving, trigger a full look.
  - A full look through every folder at launch, on wake, every 5 minutes, after Check Now, after
    Resume All and when a folder is added or removed. Events settle 5 s first (v0's wait), so a
    burst of changes makes one look.
  - The folder listing is engine v0's `candidates()`, rule for rule: hidden names skipped, three
    folder levels deep, v0's media types, **never a `-vertical.` rendition** (v0 never listed them,
    so its state.json does not know them), symbolic links skipped.
  - Each folder is listed on its own background thread with a 20 s limit, so a folder parked on a
    macOS permission prompt is reported ("Waiting for macOS to allow Prakriti into this folder")
    while the other folders go on.
  - **The first look at a folder lists what is already there and leaves it alone** (v0's "first
    start" rule), so adding a folder of old recordings never starts work on all of them.
  - Per source: "Make outputs automatically" makes everything chosen; **"Ask me first" checks only**
    (complete, long enough, has sound), then waits for Make Outputs. A silent recording there is
    still a Needs a decision the same day.
  - **Automatic retries:** three tries, at the regular looks, before Couldn't finish and one notice.
    A run stopped by a quit starts again by itself and counts as a try, so a file that stops
    Prakriti every time cannot loop. Ivan's own Make Outputs and Try Again run once.
  - **The heartbeat:** every regular look leaves a line in Activity and a Run, including "Checked 2
    folders. Nothing new." A look set off by a file event that finds nothing leaves no line,
    because OBS writing a recording sends events every few seconds.
  - **Pause All** now stops looking as well as starting ("Paused, so no folder was checked"), and
    Resume All looks at once.
  - Sleep and wake are logged; waking starts a full look. Each run holds a no-idle-sleep activity
    for its own length only.
- **Notifications** (`App/Notices.swift`): one per recording, updated in place. New Recording Found
  (active, no sound, after the file is complete and at least 60 s, v0's order), Started (passive,
  after the sound check passes, with "about N minutes" from measured speed), Ready for Your Yes
  (sound) share `rec-<file>-status`; Needs a Decision (`-decision`) and Couldn't Finish
  (`-problem`) are their own, in the same thread. Hidden previews use the status words. The
  builder is plain data and tested; the notifier asks for alert and sound once, never provisional,
  never badge; a click opens that recording's page. Every notice is written to the log with what
  macOS did with it. Settings shows the permission in plain words and re-reads it when Prakriti
  comes to the front and at every heartbeat.
- **Open at login:** `SMAppService.mainApp`, registered only by the copy in `~/Applications` (or
  `/Applications`). Opened at login, Prakriti closes its window and keeps watching. Settings shows
  the state, with a button to Login Items when it needs Ivan.
- **One watcher per mode:** a `flock` lock in the mode's Application Support folder. A second copy
  in the same mode logs why and quits; a development copy runs beside the live one.
- **A plain `kill` is Quit** (SIGTERM handled), so the install script and the checks stop Prakriti
  cleanly.
- **The switch-over:** `AppMode.switchedOver` is true; `--development` opens a test copy with its
  own store, preferences, log, lock and `~/Prakriti/Dev` folders. On its first live launch the app
  seeded Studio Recordings and `~/Prakriti/Drop` (both automatic), read engine v0's
  `~/Prakriti/state.json` into the store **before its first look** (`App/EngineV0Import.swift`;
  paths only, plus the numbers in v0's REPORT.md tables), and started watching.
- **Refusals in every mode:** the SerenityAI archive (private calls) and Prakriti's own Outputs and
  Approved folders as sources (watching them would find its own episodes).
- **Screens:** Sources has a Watching row with Check Now, and each folder says what its last look
  found or why it cannot be read, with Open Privacy Settings when macOS is the reason. Settings
  has Open at login and the notification permission. The status line and the menu bar icon put a
  folder that cannot be read ahead of work in progress.
- **Scripts:** `make install` (`scripts/install.sh`), `make drop MODE=development|live`
  (`scripts/drop-in-app.sh`, the acceptance in the real app), and `--forget=<path>` to take a test
  recording back out of the list. The development checks (`check-launch.sh`, `process-in-app.sh`,
  the refusal capture) now open a `-n --development` copy.

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test` | **66 tests, 0 failures, 1 skipped by design** (`make accept` only): ModelTests 15, RulesTests 12, PipelineTests 15, NotificationTests 6, WatcherTests 16, SnapshotTests 1 |
| Notification builder, all five events | 19 variants (each event, ask-first, coverage gap, no audio track, one, two and three tries, no length, no folder) pass the copy rules: title "Event: Sun 13 Sep" with a computed weekday and title case; full sentences of 3+ words ending in a period; no em or en dash, "!", app name, "we", "processing" or emoji. Exact words pinned for the 13 Sep talk and the 14 Sep class. A file named "Maria asks about her divorce.m4a" titled "Maria's question" reaches no notice. Found, Started and Ready share one identifier; decision and problem their own; one thread. Sounds: Found and Started silent, Started passive, the other three with sound |
| Watcher, end to end on generated files | A 70 s tone dropped in is found, made and Ready with notices Found, Started, Ready on one identifier and no clicks (3.8 s); Ask me first checks, makes nothing, one Found notice; an 8 s clip is filed silently; 65 s of silence is Found then Needs a Decision; a broken file gets tries 1 and 2 with no notice, then Couldn't finish and one notice ("It stopped three times while checking the file is complete..."); an interrupted automatic run restarts and counts; a first look lists and starts nothing; the heartbeat logs "Checked 1 folder. Nothing new." with a Run; pause stops looking and resume catches up; a missing folder is reported, not fatal |
| FSEvents, real | A file written into a watched folder arrives as an event; after the stream stops, a file written meanwhile is **replayed** from the saved id, with HistoryDone |
| The switch-over, on engine v0's real state.json shape | Seeds both folders automatic; imports 11 (7 skipped, 2 Ready, the watcher test skipped because its files are gone, the silent class Needs a decision); the 13 Sep talk keeps -16.8 LUFS, -1.6 dBFS, 2,948 words, 15:47; the first look over the studio tree (with both vertical renditions and the .txt files) finds **nothing new**, starts nothing, posts nothing; read once only |
| **Negative controls** | Copy rule broken on purpose ("we", "!"): 3 failures. The vertical rule removed: the scan test fails, and the switch-over test fails with **13 recordings instead of 11** (both vertical renditions would have been made). Both restored |
| **Dev acceptance, real app, before the switch-over** (`make drop MODE=development`) | A fresh 90 s clip (90.12 s, `ffmpeg -c copy` from the 13 Sep talk) moved into `~/Prakriti/Dev/Drop` at 14:50:49: **found 14:50:56 (7 s), Ready for your yes 78 s after the move**, no clicks. Readiness 65.3 s (the real 60 s wait), Parakeet 1.5 s; -16.5 LUFS, peak -1.8 dBFS, 241 words, 1:29 of 1:30. Three notices handed to macOS on one identifier |
| Event replay, real app | Relaunch replayed from event 340827176 (nothing missed); after the live cleanup, the relaunch **caught the one change made while closed** |
| **Engine v0 retired** | v0 idle (last line 14:56:40 "sweep (timer): nothing new"). `launchctl bootout gui/501/studio.therowan.prakriti` exit 0 at 14:56:59; `launchctl print` now says `Could not find service "studio.therowan.prakriti"`; no `prakriti.mjs` process; plist moved to `~/Prakriti/retired/studio.therowan.prakriti.plist`; `~/Prakriti/log.txt` and `state.json` unchanged since |
| First live launch, 14:57:06 | "Took over from the old engine: 11 files it had already seen were added as they were (7 existing, 3 ready, 1 silent)". Login item: **on (registered now)**. Studio Recordings: **listed 10 recordings, no permission prompt needed**. "Checked 2 folders. Nothing new." |
| **Live acceptance, after the switch-over** (`make drop MODE=live`) | A fresh 90 s clip moved into `~/Prakriti/Drop` at 14:57:43: **found 14:57:50 (7 s), Ready 78 s after the move**, no clicks; same numbers as above. Then the clip and its outputs were removed and the recording forgotten (`--forget`); `~/Prakriti/Drop` empty, `~/Prakriti/Outputs` back to v0's two folders |
| **Nothing v0 saw was made again** | In the live store, all 11 recordings from v0 have **0 runs** and no automatic intent; v0's 12 output files are identical in size and date before and after |
| Live heartbeat | Launched 14:59:51; the regular look logged "Checked 2 folders. Nothing new." at **15:05:10** (5 min 19 s: macOS coalesces timers for a background app; the interval is a floor, not a promise) |
| Only the app watches | `pgrep`: one `~/Applications/Prakriti.app` process, no node engine. A second live copy opened with `open -n` logged "Another copy of Prakriti is already running in live mode, so this one closes" and quit; the first kept running |
| `make check MILESTONE=m3` | Tests pass; PASS still running 15 s after its window closed; real-window captures **16 of 16 PASS** (selected-row icon 449 to 891 px; the development refusal alert, now worded for the live owner, in light and dark) |
| Snapshots | `screens/mac/m3/`: 42 PNGs (every screen light and dark with scrolled ends, plus Sources, Today and Settings in the "waiting for macOS" state). `real/`: the development app on Activity and Sources, the live app on Today, Activity and Sources, and the 16 `make look` captures. **Every one looked at** |
| Em dashes | 0 in `mac/` (app, tests, scripts, Makefile) |

### What the look-through and the runs caught and fixed

- **A folder that cannot be read was hidden behind "Working on..."** on Today and the menu bar. It
  now wins: it needs Ivan, and work in progress has its own section.
- **The window-capture launches wrote into Ivan's live log** after the switch-over (14 lines between
  15:02 and 15:03 on Sat 10 Oct, left in place). Sample-data launches now always log to the
  development log, checked: a capture adds 0 lines to the live log.
- **A refused notification was logged as "waiting"**: notices now say why they were not shown, and
  a refusal is one Activity line Ivan can see.
- **Notices claimed one-word sentences** ("Found.") when a recording had no folder; caught by the
  copy-rule test, reworded.

### Decisions, each with its reason

1. **`SMAppService.mainApp`, as the build prompt set, not SCOPE 7.2's nested agent.** Reason: one
   app, one identity, no second target this week. Cost, raised below as a trap: a crash is not
   restarted until the next login (v0's LaunchAgent had KeepAlive).
2. **The live copy lives in `~/Applications` (`make install`).** Reason: a login item records where
   the app is, every build rewrites the build folder, and a build replaced the running development
   copy's files during this milestone. Folder and notification permissions follow the signature,
   which both copies share.
3. **`AppMode.switchedOver` plus `--development`,** with separate store, preferences, log, lock and
   folders. Reason: later milestones need a test copy that cannot pause the live watcher or move
   its saved event id (preferences were shared until now).
4. **The first look at any folder is a baseline;** seeded folders count as looked at, and v0's
   state.json is the memory of what was there before. Reason: v0's rule, and adding a folder must
   never start work on everything in it.
5. **New Recording Found arrives when the file is complete and at least 60 s long** (v0's order),
   not on first sight. Reason: before that, Prakriti cannot know it is not a test, and tests are
   silent. SCOPE's queued variant ("two recordings are ahead of it") is not built.
6. **Titles use the build prompt's event names** ("New Recording Found", "Started", "Needs a
   Decision") rather than SCOPE 8.3's per-case titles ("Recording From", "No Sound"), so the
   notice and its switch in Settings use the same words.
7. **A notice never carries a file name, a title or a tool's error text.** Reason: a dropped file
   can be named after a student, and notices show on lock screens and mirrored devices (PR-22).
8. **Notification permission is asked at launch,** not after a folder choice with an explainer
   (SCOPE 7.2). Reason: there is no setup flow yet; the explainer arrives with one.
9. **One watcher per mode by `flock`.** Reason: two watchers on one folder make and notify everything
   twice; a lock dies with its process, so a crash never leaves Prakriti locked out.
10. **The import reads only paths and v0's report tables, and runs before the watcher starts;** if
    it cannot be read, nothing is watched. Reason: without v0's memory the first look would take
    the classes of 16, 20 and 23 Sep as new.
11. **The studio folder and the drop folder are both "Make outputs automatically",** as v0 ran them.
12. **Readiness is still v0's** (60 s steady, opens, tail decodes). SCOPE 7.3's fuller rule waits.

### What does not work yet, or was not seen working

- **No notice has reached Notification Center yet:** macOS reports notifications as turned off for
  Prakriti (see For Ivan). The builder, the identifiers and macOS accepting each request are
  proved; a banner on screen and a click opening the page are not.
- Opening at login is registered (`on`) but has not been through a real login; the next login
  should leave "Finished launching at login" in the log.
- Sleep and wake are built but not tested by closing the lid. FSEvents on the studio folder itself
  was not exercised by a new studio file (nothing may be written there); the 5-minute look covers
  it either way, and FSEvents is proved on the drop folder.
- A recording still being recorded in the studio folder holds the one-at-a-time line until it stops
  growing, as in v0.
- No crash restart (decision 1).

### For Ivan

1. **Turn notifications on for Prakriti** (blocked, needs Ivan). macOS reports them as turned off;
   whether someone pressed Don't Allow or macOS recorded it when a test copy quit with the prompt
   open is not knowable from the logs. System Settings, Notifications, Prakriti: Allow
   notifications, Banners, Play sound. Or Prakriti, Settings, Notifications, Open Notification
   Settings. Until then every notice is written to `~/Library/Logs/Prakriti/<date>.log` only, and
   **a silent class would show up in Today and Activity but not as a banner.**
2. Nothing to do for the Documents folder: the app read the studio folder with no prompt.
3. Nothing to do for the login item: it is on. macOS may have shown a "Background Items Added"
   notice; that one is informational.
4. To go back to engine v0 for any reason: quit Prakriti first (two watchers would double
   everything), then
   `mv ~/Prakriti/retired/studio.therowan.prakriti.plist ~/Library/LaunchAgents/ && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/studio.therowan.prakriti.plist`.

### Notes for milestone 4

- **After any code change, `make install`,** or the live copy keeps running the old code while the
  tests pass on the new.
- Test in development: `open -n mac/build/Build/Products/Debug/Prakriti.app --args --development`.
- The live store holds v0's 11 recordings: 2 Ready (13 Sep, 6 Sep), 1 Needs a decision (14 Sep).

---

## Milestone 4: outputs and settings. Sat 10 Oct 2026

### What was built

- **Every working output's settings now change what is made** (`mac/Prakriti/Engine/Pipeline.swift`):
  - **Podcast episode:** the loudness target (both loudnorm passes and the limiter follow it), the
    **silence trim** (new step "Silence at the start and end": `silencedetect` at -50 dB for at least
    1 s on the mono mix, half a second kept before the first sound and after the last; `SilenceTrim`),
    an **intro and outro** (each checked, measured, brought to the talk's own loudness, then joined to
    the talk in one filter graph before the whole episode is leveled; `Mastering.Program`), and
    **mono or stereo** (the layout set inside the chain, before the limiter, as v0's bug 2 demands;
    128 kbps either way, decision 6). The loudness check now expects intro + kept talk + outro, within 1 s.
  - **Transcript:** the chosen formats only (.txt, .srt, .vtt, and a new **.md**: paragraphs, each
    with its time, `TranscriptFiles.markdown`); `transcript.json` is always kept while the transcript
    is on, as Parakeet heard it. **The Yoga Marga word list** (`Engine/Lexicon.swift`, new step "Word
    list") fixes known mis-hearings of the school's name ("yoga market", "Yoga Margot", "Yokamarga",
    "Yakamarga", "Yogamarga", "Yoga Marka", "yoga marker", "Yoga Margo", and lowercase "yoga marga"),
    "Pradayama", "Sampia", and three lineage names Parakeet got wrong in the 13 Sep talk
    (Krishnamacharya, Pattabhi Jois, Iyengar). Whole words only; the .srt and .vtt keep every number
    and timing line byte for byte; every fix is listed with its time in REPORT.md.
  - **Checks and report:** REPORT.md gains the episode's length, the trim, the intro and outro, the
    formats made, the word list's fixes as a table, and how far the episode's clock is shifted from
    the transcript's.
  - **Titles, show notes and chapters:** shown, with its switch off and greyed, as needing the
    writing model ("Not made yet: it needs the writing model, which Prakriti does not use yet."),
    whatever is stored (`OutputKind.isAvailable`). Wired in milestone 6.
  - The five not-built outputs keep their one line each under "Not built yet".
- **A make happens in a staging folder** (`.making <name>` beside the recording's folder) and moves
  in only when it has finished (`Pipeline.place`). A file made again replaces the old one; a file an
  earlier make left that this one did not make (a transcript turned off) is removed; any other file in
  the folder is left alone. A stopped make leaves the last good files untouched.
- **Which outputs, and how** (`OutputResolver`): a recording's own switch, else its folder's (Sources),
  else the Outputs screen's (files added by hand) decides **whether**; the recording's own settings,
  else the Outputs screen's, decide **how**. See "Found on the way" below for why.
- **Screens:**
  - **Outputs:** the episode's settings (loudness, trim, intro, outro, channels, each with one plain
    line), the transcript's formats and word list switch, the word list itself (each word, what it is,
    how it has been misheard), checks and report, titles (waiting for the model), not built yet, and
    one closing line on what the switches here mean.
  - **A recording's page:** a new "Outputs for this recording" section: the four switches (the
    folder's choices until one is changed, then its own), a one-line summary of the episode and
    transcript settings, "Change Settings for This Recording" or "Use the Folder's Choices", and
    **Make Again…** (with a confirmation that says the files are replaced only once the new ones are
    ready and the original is not changed). With its own choices, its episode and transcript settings
    appear below, for the outputs it makes. Results gain the episode's length and trim, the word
    list's fixes, and what was made. A silent recording or a test clip shows no output choices.
  - **Sources:** each folder's switches, with titles shown as waiting for the model.
- **Data:** `Recording` gains `episodeDuration`, `silenceTrimmedStart`, `silenceTrimmedEnd`,
  `wordListFixes` and `madeFiles` (additions with defaults). A finished make writes all of them; a
  stopped one changes none, because the last good files are still there.
- **Scripts and checks:** `make accept-outputs` (`OutputsAcceptanceTests`), `make migrate-check`
  (`StoreMigrationTests` on a `sqlite3 .backup` copy of the live store), `--open=<path>` to open one
  recording's page in the real app, and snapshots of every screenful of a long page (`-p2`, `-p3`),
  not just its top and end.

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test` | **78 tests, 0 failures, 3 skipped by design** (the two acceptances and the migration check): ModelTests 16, RulesTests 12, PipelineTests 15, NotificationTests 6, WatcherTests 16, **OutputsTests 9**, SnapshotTests 1 |
| **Acceptance 1: the transcript off, made again, leaves no transcript** (`make accept-outputs`, the 13 Sep talk) | After the transcript was turned off on the recording's page: **no `transcript.*` file in the folder**; the folder holds `REPORT.md` and `episode.mp3` only; Parakeet did not run (no Transcript step); REPORT.md has no Transcript row; Activity: "Made again: the earlier files were replaced, and transcript.json, transcript.md, transcript.srt, transcript.txt, transcript.vtt removed because they were not chosen this time." |
| **Acceptance 2: -16 to -19 LUFS, made again** | **Target -16: -16.8 LUFS, true peak -1.7 dBFS (ebur128); -16.82 LUFS, -1.68 dBTP (loudnorm print mode).** Changed on the Outputs screen to -19 and made again: **-19.1 LUFS, true peak -1.7 dBFS (ebur128); -19.10 LUFS, -1.71 dBTP (loudnorm).** Both meters within 0.1 LU of -19. Run twice (15:45, and 16:04 on the final code), same numbers to the hundredth |
| **Acceptance 3: the word list fixes a planted mis-hearing** | `OutputsTests.testTheWordListFixesPlantedMishearingsAndNoTiming`: an .srt planted with "yoga market", "Yoga Margot", "Yokamarga", "Pradayama", "Yoga Marka", "Krishna Macharya", "Patabi Joyce", "Ayengar", "samkhya": all 9 fixed, "Yoga Mārga School" and "yoga markets" left alone, every number and timing line byte for byte the same, a second pass fixes nothing. **Through the real tools:** `testTheWordListFixesWhatParakeetMishears` has the Mac's own voice (`say`) speak the mis-hearings; Parakeet wrote "Yoga Market School", "Pradayama", "Yoga Margot"; the .txt and .md read "Yoga Marga School", "Pranayama", "Yoga Marga"; `transcript.json` still says "Yoga Market" |
| The word list on the real 13 Sep talk | **15 fixes**: Iyengar 2 (from "Ayengar", "Ayangar"), Krishnamacharya 5, Pattabhi Jois 1, Yoga Marga 6 ("Yoga Marka" at 2:53 and five lowercase), Samkhya 1. All 15 read in `acceptance-outputs.txt`; none wrong |
| The trim on the real 13 Sep talk | 1.68 s under -50 dB at the start: **1.18 s trimmed**, nothing at the end (the talk runs to its last second); episode 15:47 of 15:48 |
| **The settings change nothing when off** | Trim off, -16, mono, no intro or outro on the recording's page: the episode's decoded audio md5 is **69658a8cb8a954b92798c5e9f3ea5833, identical to engine v0's** episode in `~/Prakriti/Outputs` (read only) |
| Trim, intro, outro, stereo, measured | `testTrimIntroOutroAndStereoChangeTheEpisode`, generated audio: 4 s silence + 70 s tone + 5 s silence, 3 s intro, 2 s outro 24 dB quieter, stereo, -19: trimmed 3.5 s and 4.5 s (within 0.1 s); **episode length within 0.5 s of 76 s = 3 + 71 + 2**; 2 channels; -19 within 1 LU; peak at or under -1; the intro and outro play within 3 dB of the talk's momentary loudness |
| A stopped remake | A remake whose intro has gone: Couldn't finish with "The intro chosen on the Outputs screen (gone.wav) is not there any more...", **the previous episode byte for byte untouched**, no staging folder left |
| A note Ivan keeps in the folder | Survives a remake (tested) |
| Through the app | `testARecordingWithTheTranscriptTurnedOffIsMadeWithoutOne`: the Outputs screen's -19 reaches a recording; its own transcript switch off; made at -19 with no transcript; `madeFiles` = REPORT.md, episode.mp3 |
| **The real app** (`scripts/process-in-app.sh`, development copy, the 90 s clip, no clicks) | Ready for your yes, made in 1 min 8 s (of which the 60 s readiness wait took 63.3 s): Word list "1 fix: Yoga Marga (1)", "No silence to trim at either end", -16.5 LUFS, peak -1.8 dBFS, `transcript.md` written, the old files replaced, no staging folder left. Its page captured in the real window (`real/m4-real-clip-90s-page.png`), looked at |
| `make check MILESTONE=m4` | Tests pass; PASS still running 15 s after its window closed; real-window captures **16 of 16 PASS** (the Outputs screen in light and dark looked at: switches in the accent color, the new lines) |
| **Live store migration, on a copy** (`make migrate-check`) | Opened with the new models: 11 recordings (2 ready: 13 Sep -16.8 LUFS, 6 Sep -16.7 LUFS), 2 folders, 27 output settings, 29 Activity lines; the new fields empty |
| **Installed live** (`make install`, 16:13:37) | Quit cleanly, replaced, opened: "Mode: live. Store: ~/Library/Application Support/Prakriti/Prakriti.store" (no fallback), login item on, replayed 0 events, "Checked 2 folders. Nothing new." The live store read afterwards: 11 recordings, 2 ready, 27 output settings. engine v0's outputs in `~/Prakriti/Outputs` unchanged (dates 8 and 9 Oct) |
| Snapshots | `screens/mac/m4/`: 54 sample-data pictures (every screen light and dark, every screenful of the long pages, the recording page with the folder's choices and with its own) and 18 from the acceptance (the 13 Sep page after runs 1 and 3, the Outputs screen at -19, light and dark, every screenful). `real/`: 19 real-window captures. **Every one looked at**, as contact sheets and full size |
| Em dashes, en dashes, tooltips | 0 in `mac/` |

The full text of the acceptance is `screens/mac/m4/acceptance-outputs.txt` (gitignored).

### Found on the way: the Outputs screen never reached a watched folder

Every folder got its own copy of every output setting on the day it was added, and the pipeline read
the folder's copy before the Outputs screen's. Sources shows only on and off switches, so the folder's
copy of the loudness, the trim or the intro could never be seen or changed, and **a loudness changed on
the Outputs screen would have shown -19 while every studio episode went on being made at -16.** It
would have looked like the setting did not work. Fixed at the cause: a folder decides only which
outputs it makes, and the settings come from the Outputs screen or the recording's own (START_HERE,
Mac warning 28). A test sets the folder's copy to -23 and the screen to -19, and the recording gets -19.

### What the look-through caught and fixed

- **The middle of long pages was never pictured.** A recording's page now runs three screens; the
  snapshot took the top and the end, and the Results and the new Outputs section sat between them,
  unseen. The renderer now saves every screenful (`-p2`, `-p3`).
- **Settings looked live for an output turned off.** With the transcript off on the 13 Sep page, its
  transcript settings still showed below. They now show only for outputs the recording makes.
- **Greying out was wrong on the Outputs screen.** Its episode settings were greyed when its own
  switch was off, but every folder that makes episodes uses them. They are never greyed now.
- **A silent class offered output choices** it can never use. Hidden for silent recordings and tests.
- **"Fixes the known mis-hearings below"** on a recording's page, where the list is not below: now
  "listed on the Outputs screen".
- "Its capitals are fixed too" read oddly under a name: now "Wrong capitals are fixed too."
- A test expectation of mine was wrong, not the app: "%.3f" of 1.1815 is "1.181" in binary floating
  point. The test now uses 1.18.

### Decisions, each with its reason

1. **Folders choose whether; the Outputs screen (or the recording) chooses how.** Reason: the trap
   above; and Sources shows switches only, so a folder's hidden copy of the loudness was unreachable.
2. **A recording's own choices are a full copy, made the moment one is changed, and its page says
   "Changes on Sources and Outputs do not reach it", with "Use the Folder's Choices" to go back.**
   Reason: half-inherited settings would be impossible to read on screen.
3. **Staging, then replace only Prakriti's own file names.** Reason: a stopped remake must not cost
   the last good episode, the transcript-off acceptance must leave nothing behind, and Ivan's own files
   in the folder must survive.
4. **Make Again on a finished recording asks once.** Reason: it replaces files (HIG: confirm the
   destructive). Milestone 5 adds trim and cuts to the same button.
5. **The mastering chain is not changed in this milestone, including its leveling.** Milestone 2 found
   loudnorm falls back to riding the level ("dynamic") on every studio talk and said the fix belonged
   here. Not done, on purpose: changing how episodes sound needs Ivan's ears, episode 1 (made by v0)
   ships Fri 23 Oct, and the build asked for settings that change what is made, which they now do
   with the chain otherwise untouched (proved bit for bit). It is raised for Ivan below.
6. **Stereo is 128 kbps too.** Reason: the studio records one microphone into both channels, and
   LAME's joint stereo spends almost nothing on a side channel that is silent, so 128 kbps stereo
   sounds the same as the mono episode; 192 would only make the file bigger.
7. **The intro and outro are brought to the talk's loudness, then joined end to end with no
   crossfade.** Reason: SCOPE 7.11 asks each piece at the same loudness; a crossfade (SCOPE proposes
   250 ms) could lay music over the first word, and an intro is normally made with its own fade.
8. **Silence trim: -50 dB, at least 1 s, half a second kept.** Reason: measured on both real talks
   (1.7 s and 3.4 s of near-silence at the start, none at the end); conservative so no word is clipped.
   It is on by default, as the Outputs screen already showed it.
9. **Transcript times stay on the original recording's clock.** Reason: the coverage check, the
   player (milestone 5) and any caption work start from the original; REPORT.md states the shift
   ("everything is 1.2 s earlier").
10. **The word list fixes known variants only; it names three lineage teachers beyond the brief.**
    Reason: they were plainly misheard in the 13 Sep talk ("Krishna Macharya" five times) and their
    spellings are settled; phonetic matching of other words (SCOPE's second stage) needs word
    confidences and is not built. "Yoga Marga school" keeps its small "s": "Yoga Mārga School" is the
    channel's name, and whether Gabriel meant the channel is not for a word list to decide.
11. **`transcript.json` is always kept while the transcript is on, whatever formats are chosen.**
    Reason: it is the words as heard (SCOPE 7.7 keeps originals), and the recording page (milestone 5)
    and the writing model (milestone 6) read its timings. At least one readable format stays chosen.
12. **Titles, show notes and chapters cannot be turned on until milestone 6.** Reason: a switch that
    does nothing is the problem this milestone fixed.
13. **Installed live after the checks** (`make install`), after `make migrate-check` passed on a copy.
    Reason: START_HERE warning 21, the live watcher otherwise runs the old code. From now, a new studio
    recording is made with the trim, the word list and the .md transcript.

### What does not work yet, or was not seen working

- **The leveling is still moment to moment (dynamic), not even,** on every studio talk (decision 5).
- An intro or outro has been proved on generated tones only; no real intro file exists yet.
- Make Again cannot yet trim, cut or edit the title and notes (milestone 5); there is no player.
- The word list cannot be edited in the app; corrections Ivan makes are not offered back (ACC-06).
- Titles, show notes and chapters: milestone 6.
- Notifications are still turned off in System Settings (milestone 3, For Ivan 1), so the new
  Ready notice for a remade recording reaches the log only.

### For Ivan

1. **Turn notifications on for Prakriti** (still blocked on your click, from milestone 3): System
   Settings, Notifications, Prakriti: Allow notifications, Banners, Play sound.
2. **The uncomfortable one: episodes are leveled moment to moment, not evenly.** It has been true
   since engine v0, it is true of episode 1, and this milestone did not change it (decision 5). Listen
   to episode 1 (`~/Prakriti/Outputs/2026-09-06 18-06-33/episode.mp3`) for quiet passages swelling
   and loud ones sitting down. If it sounds natural, nothing changes. If it pumps, say so and the
   next milestone makes a compressor-first version (SCOPE 7.11) for you to compare by ear before
   anything is switched.
3. **Episode 1 is safe as it is.** It is v0's file and nothing remakes it unless you press Make Again.
   If you do, it is made with today's choices (silence trimmed, word list on); to get v0's audio
   exactly, give it its own choices with the trim off first. Gabriel's recorded intro (README: it
   opens episode 1) can now be chosen as that recording's intro.
4. **Glance at the word list** (Outputs screen) for spellings Gabriel would write differently,
   especially the three lineage names (Krishnamacharya, Pattabhi Jois, Iyengar).

To see it:

```bash
cd ~/Code/prakriti/mac && open ~/Applications/Prakriti.app
```

### Notes for milestone 5

- Make Again exists on a finished recording's page (`RecordingOutputsSection`, `AppModel.makeOutputs`);
  trim, cuts, title and notes belong beside it. `Recording.trimStart`, `trimEnd` and `cuts` exist and
  are unused; the episode's program (`Mastering.Program`) is where cut ranges join the trim.
- Transcript times are on the original's clock; `transcript.json` has word timings as heard, and the
  corrected words are in the .srt.
- `make accept-outputs` and `make migrate-check` are the patterns for milestone 5's acceptance and
  for any model change before `make install`.


---

## Milestone 5: the recording page. Sat 10 Oct 2026

### What was built

- **A recording's page, top to bottom** (`mac/Prakriti/Views/RecordingsView.swift`, `RecordingPage.swift`):
  - **Status, with Approve at the top** (SCOPE 9.1 #5: the named action at the top of the pane). Under
    the status: why it cannot be approved yet in one sentence, or "Speakers not checked" with the
    reason; **Approve…** (a confirmation names the files and the folder and says nothing is uploaded);
    **Make Again…** beside it while the trim or cuts are not in the episode; the approved folder with
    Show in Finder once approved.
  - **Listen:** AVKit's own `AVPlayerView` (inline controls, clipped to its pill: no drawn scrubber or
    waveform), playing **Episode** (the MP3 as made) or **Original** (the recording's sound only, as an
    audio-only composition of its first sound track, so no video area). Switching keeps the moment.
  - **Transcript:** one line per Parakeet sentence, read from `transcript.json` with the word list
    applied, each with its time. **Click a line and the player plays from it**: in the episode, from
    where that moment is after the trim and cuts (`EpisodeClock`). Shift-click selects several, then
    **Cut Selected Lines**; Control-click a line for Play From Here and Cut This Line. Lines a cut
    takes are struck through and say "Cut from the episode" or "Partly cut from the episode"; the line
    playing is shown in bold.
  - **Trim and cuts:** "Episode starts at" and "Episode ends at" (typed as 4:12 or 1:02:30, applied on
    Return or when the field is left, or **Use Player Time**), each cut with Remove, "Cut a section,
    from and to" with Add Cut, what the episode keeps ("15:08 of 15:48 (40 s taken out)"), a line when
    the changes are not in the episode yet, Clear Trim and Cuts, Make Again.
  - **About this recording:** the title, the notes, and **What this is**: Talk, one teacher speaking;
    Class; Conversation; Not set. A class is privacy locked, as before.
  - Then the steps, results, outputs for this recording, and the file, as in milestone 4.
- **The edits in the pipeline** (`Engine/EpisodeEdits.swift`, `Pipeline.swift`): `PipelineOptions.edits`
  (start, end, cuts, seconds on the original's clock) become the parts of the recording the episode
  keeps, after the silence trim (`EpisodeEdits.segments`). New step **"Your trim and cuts"** (refuses
  edits that leave nothing, with the reason). The mastering pass with edits is one filter graph: the
  recording split into its parts, each cut, started at zero and faded 15 ms in and out, joined, then
  the layout and 48 kHz, then (with an intro or outro) joined to them, then loudnorm and the limiter
  (`Mastering.part`); without edits the chain is milestone 4's, string for string. The length check
  expects intro + the kept parts + outro.
- **The transcript files follow the episode** (new step "Transcript matched to the episode",
  `EpisodeTranscript`): whenever anything is taken out or added, the chosen .srt, .vtt and .md (and the
  .txt when words were dropped) are rebuilt from `transcript.json`'s word times, the words inside a cut
  or trim left out, every time on the episode's clock, the word list applied. `transcript.json` keeps
  every word as heard. REPORT.md gains "Your edits" and says the files follow the episode and how many
  words were left out.
- **Approve** (`App/Approval.swift`, `App/RecordingActions.swift`): `ApprovalCheck` decides (busy, not
  made, the speakers rule, edits not made, files missing, already approved), and `AppModel.approve`
  checks it again whoever calls it. It copies the finished files except `transcript.json` through a
  hidden `.approving <name>` folder into `~/Prakriti/Approved/<name>/` (development:
  `~/Prakriti/Dev/Approved`), with **`APPROVAL.md`**: the title and notes as written, the edits, and
  every file's size and SHA-256. Status Approved, one Activity line. Any later change (title, notes,
  what it is, trim, cuts, Make Again) takes the approval back to Ready for your yes; the approved copy
  stays until the next approval replaces it (only Prakriti's own file names).
- **Data:** `Recording` gains `madeTrimStart`, `madeTrimEnd`, `madeCuts` (what the episode was made
  with), `episodeParts`, `episodeIntro` (the episode's map), `madeAt`, `approvedFiles` (additions with
  defaults; `trimStart`, `trimEnd`, `cuts`, `approvedFolder`, `approvedAt` existed since milestone 1).
- **Tests and tools:** `RecordingPageTests` (11, in `make test`), `EditsAcceptanceTests`
  (`make accept-edits`), `StoreMigrationTests` checks the new fields, `make snapshots ONLY=recording`,
  and capture flags `--open=ready` and `--sample-edits` for the real window on the sample page. The
  snapshot renderer now scrolls only the page, not a list inside it.

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test MILESTONE=m5` | **90 tests, 0 failures, 4 skipped by design** (the three acceptances and the migration check): ModelTests 16, RulesTests 12, PipelineTests 15, NotificationTests 6, WatcherTests 16, OutputsTests 9, **RecordingPageTests 11**, SnapshotTests 1 |
| **Acceptance: trim the first 10 s, cut one 30 s section, Make Again, Approve** (`make accept-edits`, the 13 Sep talk) | Made with the standard choices: episode **946.550 s** (ffprobe; 1.18 s of silence already trimmed). Marked as a talk; "0:10" typed as the start, 5:00 to 5:30 cut; Approve refused ("Make Again first"); made again: "The episode keeps 15:08 of 15:48", -16.8 LUFS, peak -1.6 dBFS. Approved: **ffprobe measures the approved `episode.mp3` at 907.732 s: 38.82 s shorter than the first episode** (expected 38.82: 10 s trimmed less the 1.18 s the silence trim had already taken, plus the 30 s cut) **and 40.05 s shorter than the 947.78 s recording**. Measured again by hand from the shell: 907.732000 and 947.780167 |
| **The approved files exist** | `~/Prakriti/Dev/Approved/2026-09-13 18-25-44/`: APPROVAL.md, REPORT.md, episode.mp3, transcript.md, .srt, .txt, .vtt; **no transcript.json**; the approved MP3's SHA-256 (`320122f6...`) is the made one's and is in APPROVAL.md. `~/Prakriti/Approved` (live) is empty on purpose: see decision 1 |
| **The cut is really gone** | The approved transcript has none of the cut's sentences, and every sentence of the minute after it. **Parakeet run again on the approved MP3 heard 0 of the 73 five-word runs said inside 5:00 to 5:30 (and nowhere else in the talk), and 189 of 201 from the minute after the cut.** "Transcript matched to the episode: 103 words in the parts taken out are left out." The approved .srt starts at 0:00.080 with the sentence that starts at 0:10.08 in the recording |
| **A recording marked "class" cannot be approved** | `RecordingPageTests.testAClassCannotBeApproved`: Approve refused with "Speakers not checked", nothing copied, an Activity line and an alert; a conversation, "Not set" and a test refused too. On the real 13 Sep talk (the acceptance): marked as a class after approval, the approval is taken back, Approve refused, the earlier approved copy byte for byte unchanged |
| Approving a talk | `testApprovingATalkCopiesTheFinishedFilesAndAReceipt`: Approved/<name> beside Outputs/<name>, every made file but transcript.json, the receipt's SHA-256 matches, no staging folder left, a title change takes the approval back, a trim not made blocks it, approving again keeps Ivan's own file in the folder |
| The edits through the real tools | `testATrimAndACutMakeTheEpisodeShorterAndTheTranscriptForgetsTheCut`: the Mac's voice says three sentences, the middle one "A student named Maria asks about her divorce."; trimmed 1 s and that sentence cut: episode length within 0.3 s of expected (ffprobe agrees), "divorce" in none of .txt, .srt, .md, still in transcript.json; the last line's time moved up by the trim and the cut |
| A line plays the episode from its moment | `testALinePlaysTheEpisodeFromWhereItsMomentIs`: the page's own player, after a cut, seeks the episode to the line's mapped time (within 0.1 s) and reads it back on the original's clock; switched to Original, the same moment as recorded; the cut line reads "Cut" |
| Make Again uses the page's edits | `testMakeAgainUsesThePageEditsAndRemembersThem`: 10 s trimmed and 20 s cut from a 90 s tone: 30 s shorter, `episodeParts` [10 to 40, 60 to 90], not pending afterwards |
| The chain | `testACutIsOneGraphWithFadesAndTheLimiterAfterIt`: the exact graph, `level=disabled` kept, 48 kHz before the limiter; no edits gives milestone 4's arguments |
| **Regression: milestone 4's acceptance** (`make accept-outputs`) | -16.8 LUFS, -19.1 after the change to -19, no transcript file left with it off, and with the trim off the decoded audio md5 **69658a8c... identical to engine v0's** |
| **Regression: milestone 2's acceptance** (`make accept`) | 13 Sep: -16.8 LUFS, peak -1.7, reaches 15:47 of 15:48; 14 Sep class: Needs a decision, nothing made (loudest -91 dB); 30 s clip: a test; 6 Sep: -16.7 LUFS, peak -1.4. Its .srt check now allows for the transcript following the episode |
| Snapshots | `screens/mac/m5/`: 90 sample-data pictures (every screen light and dark; the recording page ready, with edits not made, marked as a class, approved, with its own choices, and silent, each screenful) and 60 from the acceptance (the real 13 Sep page made, with edits pending, made again, approved, as a class, light and dark, each screenful). **Every one looked at**, as contact sheets and full size |
| **Real window** | `real/m5-real-page-{light,dark}{,-edits}.png` (the sample page: the system player, Approve enabled for a talk, disabled with Make Again beside it while edits wait, cut lines struck); `real/m5-real-dev-clip-90s-page.png` (the development store, migrated, on the 90 s clip: Speakers not checked); `real/m5-real-live-13sep-page.png` (**the installed live app on the 13 Sep talk engine v0 made**: its episode in the player, its transcript, Speakers not checked). All looked at |
| `make look MILESTONE=m5` and the launch check | 16 of 16 PASS; still running 3 s after its window closed |
| **Live store migration, on a copy** (`make migrate-check`) | 11 recordings (2 ready), 2 folders, 27 output settings, 47 Activity lines; every new field empty, nothing pending, v0's 13 Sep read as one part, Speakers not checked |
| **Installed live** (`make install`, 17:26:50) | Quit cleanly, replaced, opened: "Mode: live. Store: ...Prakriti.store" (no fallback), login item on, "Checked 2 folders. Nothing new." |
| Em and en dashes, tooltips | 0 in `mac/`; RulesTests pass |

The full text of the acceptance is `screens/mac/m5/acceptance-edits.txt` (gitignored).

### What the look-through and the runs caught and fixed

- **A line wholly inside a cut read "Partly cut".** Measured on the Mac's voice: Parakeet stretches a
  sentence's last word across the pause after it and puts the full stop after the pause, so by a
  word's middle, words said inside the cut seemed to land outside it, and a lone "." could have been
  kept in the episode's transcript. A word's place is now `min(middle, start + 0.15 s)` and punctuation
  goes with the word before it (`EpisodeTranscript.position`, `isWord`); a planted case and the voice
  test cover both.
- **The system player sat on a black band** in the real window (AVKit's video area). It is clipped to
  the player's own pill; the page shows the system control and nothing drawn by Prakriti.
- **Time and title fields drew without borders** in the grouped form ("From to To" read as words);
  they are bordered fields now, the title written from the left.
- **The snapshot renderer scrolled the transcript list with the page**, so the pictures showed the
  page's middle with the list at 2:00 and made ten pictures a page. Only the page scrolls now.
- **The approved state said the same thing three times;** it is one line now, and the Approve caption
  is hidden once approved.
- **Make Again was a screen and a half below "Make Again first";** it now sits beside Approve too.
- **The original is looked at off the main thread** (it lives in `~/Documents`; START_HERE warning 24).
- **Test-side, not app:** the acceptance's refusal alert dimmed every later picture (now dismissed as
  Ivan would); two of my own test expectations had wrong arithmetic (five words, not six; 17 s, not 16).

### Decisions, each with its reason

1. **The acceptance approves in development, into `~/Prakriti/Dev/Approved`, not the live
   `~/Prakriti/Approved`.** Reason: the live folder is where Ivan's real yeses go, the place he will
   upload from; a 13 Sep episode there with an arbitrary test cut and his name on the receipt would be
   a trap. The live path is pinned by `RulesTests` (`~/Prakriti/Approved`), the code path is the same,
   and the installed live app showed the page on the real 13 Sep talk. Nothing was approved live.
2. **Only "Talk, one teacher speaking" can be approved until speaker checks exist;** Class,
   Conversation and Not set show "Speakers not checked". Every recording arrives Not set, so approving
   takes one more choice. Reason: unknown means student (SCOPE PR-3); Prakriti cannot tell voices
   apart, so Ivan's word that only the teacher speaks is the only check there is, and the receipt says
   so. Serenity being in a recording does not block a yes (she is a teacher); the privacy lock for
   models is unchanged.
3. **Approve is refused while the trim or cuts on the page are not in the episode.** Reason: a yes must
   cover the file that exists, not the one on screen.
4. **Approve never copies `transcript.json`.** Reason: it keeps the words of every cut, and the approved
   folder is what goes out.
5. **The transcript files follow the episode whenever anything is taken out or added, replacing
   milestone 4's decision 9.** Reason: cuts exist to take things out, often someone's words; captions
   must line up with what is heard (after milestone 4's silence trim they sat 1.2 s late). The page,
   the coverage check and the word list's report times still use the original's clock through
   `transcript.json`. With nothing taken out or added, the files are as before.
6. **Edits are typed and stored in seconds on the original's clock;** each make stores the episode's
   map. Reason: the transcript and the Original player speak that clock, and a line must play the
   episode from where its moment is now.
7. **The silence trim still runs under Ivan's trim;** the later start and the earlier end win.
   Reason: a trim at 0:10 makes the silence trim moot at the start, but an untrimmed end still loses
   its silence, as before.
8. **Fades of 15 ms on every kept part when there are edits; none without.** Reason: a cut mid-word
   clicks; without edits the chain stays milestone 4's (and v0's), proved bit for bit.
9. **Parts shorter than a quarter second between cuts are cut too.** Reason: a blip of half a syllable,
   and "uncertain means cut".
10. **Approve's name is the file's name** (`Approved/2026-09-13 18-25-44`), beside its folder in
    Outputs; the title goes in the receipt. Reason: a title can change, and a stable pair is easy to
    find. Approving again replaces only Prakriti's own file names.
11. **Any change takes an approval back** (title, notes, what it is, trim, cuts, Make Again). Reason:
    SCOPE 9.1 #6, a yes is void once anything it covered changes.
12. **The player is AVKit's own view, clipped to its pill.** Reason: Ivan's never-skeuomorphic rule
    allows the system's media controls only; bitmap snapshots cannot draw it, so the real window is the
    judge (START_HERE warning 43).
13. **A line's time is about when its first word starts,** and clicking plays from there. Reason:
    Parakeet's sentences begin where the one before ended, so the pause would play first.

### What does not work yet, or was not seen working

- **No person has clicked through the page.** Every action was driven through the same model calls the
  buttons make (the acceptance and the tests), and the real window was captured in four states, but a
  click on a line, the player's sound, typing in a field and the confirmation dialogs were not done by
  hand (that would need Accessibility or Screen Recording permission for the tools).
- **Speakers are not checked;** "Talk" is Ivan's word. Conversations cannot be approved at all yet.
- Intros and outros with cuts are covered by the graph test only, not by a run with a real intro.
- The line playing is shown in bold, but the list does not scroll to follow the player.
- Notifications are still turned off for Prakriti in System Settings (milestone 3), so the Ready notice
  after a Make Again reaches the log only.
- Approving does not write anything to the web app or any feed; publishing is not part of v1.

### For Ivan

1. **Turn notifications on for Prakriti** (still blocked on your click, since milestone 3): System
   Settings, Notifications, Prakriti: Allow notifications, Banners, Play sound.
2. **To approve anything, first say what it is.** Every recording arrives "Not set", which counts as
   possibly having students in it, so Approve stays off. On a talk where only Gabriel or Serenity
   speaks, choose "Talk, one teacher speaking" under About this recording, listen, then Approve. A
   class can never be approved in v1.
3. **Episode 1 (Sun 6 Sep) is untouched.** Nothing remakes or approves it unless you do. If you
   approve it as it is, Approve copies engine v0's files (they have no .md transcript) into
   `~/Prakriti/Approved/2026-09-06 18-06-33`. If you trim or cut it, Make Again first: from then its
   transcript follows the episode.
4. Still open from milestone 4: listen to episode 1 for the level riding up and down (moment-to-moment
   leveling); say if it pumps.

To see it:

```bash
cd ~/Code/prakriti/mac && open ~/Applications/Prakriti.app
```

Then Recordings, Sun 13 Sep.

### Notes for milestone 6

- The writing model reads `transcript.json` (every word, original clock) or the episode's transcript
  files (cut words gone, episode clock). **Chapters must be on the episode's clock and must not quote
  a cut:** feed it the episode's cues (`EpisodeTranscript.cues` with `Recording.episodeClock`), never
  the as-heard words, or a chapter title could name a student whose question was cut.
- The privacy lock reads `Recording.kind`, which Ivan can now set on the page; a class must force a
  local model.
- The receipt (`APPROVAL.md`) is where written titles and show notes belong once they exist; any
  change to them takes the approval back, as the title does now.

## Milestone 5 fixes: the transcript reads as it was said. Sat 10 Oct 2026

The independent verifier found one regression and two smaller faults in milestone 5. Each is fixed
at its cause and re-measured on the real recordings below.

### What was wrong, and why

1. **The transcript files that follow the episode carried misplaced punctuation and words**
   (medium; it touched Episode 1's deliverable). Since milestone 5 (decision 5), every make that
   takes anything out, including the default silence trim with no edits of Ivan's, rebuilds the
   .srt, .vtt and .md (and the .txt when words drop) from `transcript.json`. Each cue was Parakeet's
   tokens joined in the order listed. **That order is not the order they were said:** Parakeet writes
   a sentence's text in the order it heard the words, then sorts the sentence's tokens by start time
   (parakeet_mlx `alignment.py`, `AlignedSentence.__post_init__`, read on this Mac). Where its
   listening chunks meet, every 105 s (224.84, 329.6, 644.84, 854.84, 959.84 s ...), a few tokens
   carry a wrong, too-early time, most often a sentence's last full stop, so the sort moves them.
   Measured over transcript.json: **13 Sep 5 of 137 sentences, 6 Sep 21 of 555.** The 6 Sep .srt
   had 8 captions starting with "." or "?" (". But the problem was that again, we spent $100 for the
   venue"), plus "when we you, know, really", "the You can always have access to Fathom" and
   "room. I don't want to share a with someone"; engine v0's had none, because it shipped Parakeet's
   own sentence text.
2. **The approved REPORT.md disagreed with the approved folder** (low): its Transcript row listed
   `transcript.json`, which Approve never copies, and its word list table listed "yoga marga" at
   5:20, inside the 5:00 to 5:30 cut. The report is written once in Outputs and copied as it is.
3. **START_HERE's map said "Milestones 1 to 3 landed"** (low, stale truth) after 4 and 5 had.

### What was changed

- **`EpisodeTranscript.sentences(json:)` reads each sentence in the order it was said**
  (`mac/Prakriti/Engine/EpisodeEdits.swift`). `spelling` finds the order of the tokens that spells
  the sentence's own text byte for byte (a search that tries first the token next in time, so a
  sentence's repeated " and" or "," keep their own times; it gives up after 20,000 steps and leaves
  the sentence as it was). `retimed` keeps the tokens whose times already run in order (the most of
  them, a word counting double, the later times winning a tie, since a misplaced time is the
  too-early one) and gives each other token a time between its neighbours. The sentence's start and
  end come from them, so the page's line for "Or what if you just exponentially increase that,
  right?" starts at its first word (963.32 s), not at the misplaced question mark (959.84 s). Every reader of transcript.json goes
  through this: the episode's files, the page's lines and their cut state, and the acceptance checks.
- **A sentence kept whole is written as Parakeet's own sentence text;** only a sentence a trim or
  cut goes through is built from its words, and that part never opens with a comma or full stop
  (`isClosingPunctuation`). So even tokens that cannot spell their text could not reach a file
  misordered unless a cut splits that very sentence.
- **A word is kept or dropped whole** (`words`): the token that starts with a space and the pieces
  and punctuation after it (" Jer", "se", "y", "."), placed by `position` as before. Before, each
  piece was placed alone, so a cut could keep half a word.
- **The word list's fixes follow the episode too.** `cues` returns the fixes it made, each at its time
  in the original; when the transcript follows the episode, the report lists those and counts the
  rest: "1 more fix fell in the parts taken out of the episode, so it is in no file and not listed."
  The step line says "(with 1 word list fix)".
- **REPORT.md says only what is true in both folders** (`Engine/Report.swift`): the Transcript row lists
  the readable formats ("`transcript.txt`, `.srt`, `.vtt`, `.md`; 2948 words heard"), and a new row,
  "Words as heard", says `transcript.json` is kept in the Outputs folder only and Approve never
  copies it.
- START_HERE: the `mac/` row (milestones 1 to 5), warnings 37, 39 and 40 amended, warning 45 added
  (read transcript.json only through `sentences(json:)`, with the reason and the numbers).

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings |
| `make test MILESTONE=m5-fix` | **92 tests, 0 failures, 4 skipped by design** (RecordingPageTests run again, 13 of 13, after the fixture's second sentence was swapped for an Episode 1 one, so the repo carries no personal fact about anyone but the speaker) (the three acceptances and the migration check). New: `testParakeetsMisplacedTokensAreReadInTheOrderTheyWereSaid` (six sentences of Parakeet's real tokens copied verbatim from the 13 Sep and 6 Sep transcript.json: each spells its text, its times run in order, each misplaced token lands between its neighbours, e.g. the "." of "for the venue" at 335.08 s, not 329.6 s; with the silence trim every cue is the sentence word for word; cuts through three of them give "And as you guys remember," / "doing a lot." / "we spent $100 for the venue." / "just exponentially increase that, right?"; tokens that cannot spell their text fall back to Parakeet's text), `testTheReportNamesOnlyWhatTheFilesHold`, and the cut-fix assertions added to `testTheEpisodeTranscriptLosesTheWordsOfACut` |
| The same rule modelled in Python (a scratch check, not shipped), both talks' transcript.json | All 26 misordered sentences: every one spelled, every one's times in order, none given up; the Swift run agrees (the acceptance rows below) |
| **`make accept MILESTONE=m5-fix`** (13 Sep, 14 Sep class, 30 s clip, 6 Sep) | 13 Sep: -16.8 LUFS, peak -1.7 dBFS, reaches 15:47 of 15:48; **.srt and .vtt: 137 captions for 137 sentences, 0 start with punctuation, 0 differ from Parakeet's sentence.** 14 Sep: Needs a decision, nothing made (loudest -91 dB). 30 s clip: a test, nothing made. 6 Sep (Episode 1): -16.7 LUFS, peak -1.4 dBFS, reaches 55:38 of 55:39; **.srt and .vtt: 555 captions for 555 sentences, 0 start with punctuation, 0 differ.** These caption checks are now part of `make accept` |
| **The verifier's reproduction** | `grep -cE '^[,.;:!?] '` on `~/Prakriti/Dev/Outputs/2026-09-06 18-06-33/transcript.srt`: **0** (was 8); .vtt 0; 13 Sep .srt and .vtt 0. **The 555 caption texts of the new 6 Sep .srt are identical to engine v0's** (`~/Prakriti/Outputs`), compared one by one; captions now read "...we spent $100 for the venue.", "Or what if you just exponentially increase that, right?", "when we, you know, really" |
| **`make accept-edits MILESTONE=m5-fix`** (13 Sep: 0:10 trim, 5:00 to 5:30 cut, Make Again, Approve) | Approved episode **907.732 s by ffprobe, 38.82 s shorter than the first (expected 38.82), 40.05 s shorter than the 947.780 s recording**; SHA-256 `320122f6...`, the made one's. **131 sentences kept whole: 131 read word for word in the approved .txt and 131 are one caption each in the approved .srt; 0 captions start with punctuation.** The approved .txt reads "at that point. And as you guys remember, we were doing a lot.", "You can always have access to the Fathom" and "we realize is that in our platform"; the verifier's three bad strings: 0 each. Parakeet run again on the approved MP3: 0 of 73 five-word runs from the cut heard, 189 of 201 from the minute after. Class refusal unchanged |
| **The approved REPORT.md** | Transcript row: "`transcript.txt`, `.srt`, `.vtt`, `.md`; 2948 words heard; reaches 15:47 of 15:48; Yoga Marga word list: 14 fixes"; no `transcript.json` among the files; "Words as heard" row present; **14 fixes listed, none inside the trim or the cut** (5:20 gone), "1 more fix fell in the parts taken out" |
| Regression: `make accept-outputs MILESTONE=m5-fix` | -16.8 LUFS, -19.1 after the change to -19, no transcript file left with it off, and with the trim off the decoded audio md5 **69658a8c... identical to engine v0's** |
| Pictures | `screens/mac/m5-fix/` (gitignored): every sample screen light and dark from `make test`, and the real 13 Sep and 6 Sep pages from the acceptances. Looked at: the 6 Sep page (light), the 13 Sep page made again (dark) and approved (light) with its cut lines struck through and the kept lines unchanged. No view code changed |
| **Installed live** (`make install`, 18:22:12, and again at 18:28:05 with the final commit's build) | Quit cleanly, replaced, opened: "Mode: live. Store: ...Prakriti.store", login item on, "Checked 2 folders. Nothing new.", still running (pid 1771). The live build with the fault (17:26 to 18:22) made nothing: `~/Prakriti/Outputs` holds only engine v0's two folders from 8 and 9 Oct |
| Em and en dashes | 0 in `mac/` |

### Decisions, each with its reason

1. **Restore Parakeet's order rather than only patch the symptoms** (the verifier's suggested
   direction was to use the sentence text when whole and drop stray leading punctuation). Both
   guards are in, but the order is fixed where transcript.json is read. Reason: misplaced tokens also
   carry wrong times, and those times decide which words a cut takes, where a line starts on the page
   and whether it reads "Partly cut"; "the You can always" had a word timed 5 s early.
2. **A misplaced token gets a time between its neighbours, never its own.** Reason: its own time is
   the chunk boundary's, seconds off; between its neighbours is right to a fraction of a second in
   every case measured.
3. **The report keeps the full word count ("2948 words heard") and counts, never names, a fix inside
   a cut.** Reason: the count is a number about the recording; a term from a cut is cut content.
4. **Installed the fix live** (milestone 5 had installed the faulty build). Reason: the live app
   would have written misordered captions for the next recording with silence to trim.

### For Ivan

Nothing new to do. Episode 1's files in `~/Prakriti/Outputs` are still engine v0's and were never
affected; if you Make Again on it, its captions now match v0's word for word.

---

## Milestone 6: the models. Sat 10 Oct 2026

### What was built

- **`mac/Prakriti/Writing/`, the models behind one interface** (`LanguageModelClient`: prepare, a
  budget check, one request, release, a test):
  - **LM Studio** (`LMStudioClient`, the default for every task): Qwen3.8-27B through the local
    OpenAI-compatible server at the Models screen's address (`http://localhost:1235/v1`). Before the
    first request Prakriti makes sure the model is loaded at **65,536 tokens** through LM Studio's REST
    API (`/api/v1/models`, `/load` with `context_length`, `/unload`): not loaded, it loads it; loaded
    smaller, it unloads and reloads it; and when the writing step ends it unloads only what it loaded.
    Every request carries docs/LOCAL-MODEL.md's settings: one system and one user message,
    `max_tokens` 16,384, `reasoning_effort` "medium", temperature 0.7, top_p 0.8, top_k 20,
    presence_penalty 1.5, no `response_format`. A reply cut off by its length, or empty, is a failure.
  - **Apple on-device** (`AppleOnDeviceClient`, Foundation Models): availability in plain words, its
    real context (`contextSize`, 8,192 on macOS 27.2) and Apple's own `tokenCount`; tags and summaries
    by guided generation (`@Generable`). A transcript that does not fit is read in parts for tags and
    summaries (tags merged by how often they come up, part summaries summarized) and **refused for
    writing**, with the reason.
  - **Ollama** (`OllamaClient`, optional): its own chat API with `num_ctx` set per request.
  - **Claude API** (`ClaudeClient`, optional): raw HTTP to the Messages API (no Swift SDK exists),
    `claude-opus-5-5` by default, adaptive thinking, effort "medium", Anthropic's refusal fallback on.
    The key is read from the **Keychain** (`KeyStore`, `Keychain.swift`) only when a task is set to it.
- **The writer** (`Writer.swift`): for the writing task, titles, show notes, chapters and an accuracy
  checklist, from the transcript as the episode plays it (one line per sentence, its time in
  brackets, the words of any cut gone); then tags and a summary as their own tasks, each with its own
  provider. **`WritingCheck`** passes nothing on trust: chapter starts must be the transcript's own line
  times, quotes must be found word for word in `transcript.txt`, both left out and counted otherwise;
  dashes become commas; a chapter under 2 minutes, or one too many for the length (SCOPE PKG-05: at
  least three, at most six an hour), joins the one before; non-JSON, under three titles, too few
  chapters or no quote found is tried again, up to three tries of the same single-turn request.
- **The privacy lock** (`Privacy`, `Writer.route`): a class, or a transcript that says "Serenity"
  (whole word, any case), turns any Claude API choice into LM Studio for every task. The pipeline sets
  `Recording.hasSerenity` from the transcript (never unset), and the step line, the recording page and
  `show-notes.md` say what the lock did.
- **In the pipeline:** a step "Titles, show notes and chapters" after the transcript and the episode,
  before the report, planned only when the output is on and the transcript is made. It writes
  `show-notes.md` (the draft Ivan reads: titles, notes, chapters, tags, summary, the checklist for
  review, what the checks changed, and a placeholder for the call to action and the removal address,
  which SCOPE leaves open) and `titles-notes-chapters.json` (the checked package with the model's own
  answer). A model that is closed or answers badly costs only this step: the make is still Ready, with
  the reason. REPORT.md gains a row. Approve copies `show-notes.md`, never the JSON.
- **Write Again** (`PipelineRunner.write`, trigger `writeAgain`): writes them again from the transcript
  already made, takes its turn in line, replaces only the two written files, keeps the last ones if it
  fails, and takes an approval back.
- **Screens:** the **Models** screen (tasks, the privacy lock, LM Studio's address and model, Apple's
  status, Ollama's address and model, the Claude API key with Save in Keychain and Remove Key, and a
  test button per provider with what it found); on a recording's page, **Titles, show notes and
  chapters**: who wrote them and when, the lock line, three title options each with Use This Title,
  the show notes with Use as Notes, the chapters, the checklist with each quote and its time, tags,
  summary, what the checks left out, and Write Titles and Notes or Write Again. Outputs and Sources now
  let the switch be turned on, with plain lines on what it takes.
- **Data:** `Recording.writtenJSON` (the package without the raw answer) and `writingProblem`
  (additions; `make migrate-check` passes). Settings: Ollama's address and model, the Claude model.
- **Tests and checks:** `WritingTests` (19, in `make test`), `ModelsAcceptanceTests`
  (`make accept-models`), and the migration check now asserts no folder has titles on after an upgrade.

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test MILESTONE=m6` (also inside `make check`; last run on the final code) | **113 tests, 0 failures, 5 skipped by design** (the four acceptances and the migration check): ModelTests 16, RulesTests 12, PipelineTests 15, NotificationTests 6, WatcherTests 16, OutputsTests 9, RecordingPageTests 13, **WritingTests 20**, SnapshotTests 1 |
| **Acceptance: Qwen3.8-27B writes for the 13 Sep talk** (`make accept-models MILESTONE=m6`, run three times; the third on the final code, 20:03) | Ready for your yes. **Valid JSON** (the model's own answer parsed as it came, nothing around it), **3 title options** ("What's Happening at Yoga Marga School", "Yoga Marga's New Direction and Schedule", "Sales, Coaching, and Yin Yoga at Yoga Marga"), show notes (113 words), **3 chapters, each start found among the 137 cue starts of the episode's `transcript.srt` to the millisecond** (0:00 = cue 1, 4:11 = cue 37, 12:24 = cue 91), the first at the first line. **Checklist: 8 claims, every quote found word for word in `transcript.txt` as is** (character offsets 644, 714, 790, 978, 1845, 7702, 13225, 14517), 0 left out, 0 chapters left out. Runs one and two: 3 titles, 3 chapters, 8 and 7 quotes, all found. Full text: `screens/mac/m6/acceptance-models.txt` (gitignored) |
| **Runtime** | Writing request **585 s, 847 s and 630 s** (the second with the unit tests running beside it): about 5,200 to 5,300 tokens read, 5,319, 7,710 and 5,774 written of which 4,580, 7,117 and 5,073 thinking; one try each. The whole step with Apple's tags (3.4 to 3.7 s) and summary (4.3 to 4.8 s): **10 min 3 s, 14 min 25 s and 10 min 48 s**; the whole make 10 min 45 s, 15 min 7 s and 11 min 29 s |
| **LM Studio loaded at 65,536 by Prakriti** | The model was unloaded before each run; the log (third run): 20:04:23 the step starts, **20:04:32 "Loaded Qwen3.8-27B in LM Studio at 65,536 tokens in 8 s"**, 20:15:01 the answer, 20:15:11 "Unloaded Qwen3.8-27B in LM Studio, which Prakriti had loaded"; `GET /api/v1/models` afterwards: not loaded |
| **Privacy lock, on the real talk** | Writing set to the Claude API on purpose. The 13 Sep transcript names Serenity: `hasSerenity` went from false to true, the step says "Privacy lock: Serenity is in this recording, so LM Studio did the writing chosen for the Claude API", and **the Claude client was asked 0 times** (it could only count and refuse) |
| **Privacy lock, unit tests** | A class with every task on the Claude API: LM Studio asked 3 times, Claude 0, lock reason "this is a class", all three tasks named; a talk whose text says Serenity: Claude 0; a talk without her: Claude used (nothing else forbids it); a class with Apple chosen: Apple kept. Write Again on a class through the runner: Claude 0, files written, the lock in the step and in Activity, Ivan's own file in the folder untouched |
| **Apple on-device, a short input** | The talk's first 8 lines (218 words, about 1,372 of its 8,192 tokens): **3 tags in 0.7 s** ("Yoga Marga, Ashtanga, guru"). Also in `make test` on made-up text, and the Models screen's test: 3 tags in 0.8 s. A long text with a small limit is read in parts, each part fitting, then summarized; writing is refused with "reads at most N tokens at once" and nothing sent |
| LOCAL-MODEL.md settings, pinned | `WritingTests`: the request body (roles, 16,384, medium, 0.7/0.8/20/1.5, no response_format); "length" and empty content are retryable failures; leading blank lines trimmed; through a stub server, a model loaded at 8,192 is unloaded, loaded at 65,536, asked, and only Prakriti's instance unloaded; a closed server is asked once and said plainly |
| The checks, unit tests | Planted answer: a title with an em dash (comma now), "9:99" and "2:40" left out as not line times, "[4:22]" accepted, a 16 s last chapter joined; quotes found with curly quotes, ellipses and a typographic apostrophe; "fifty years" (said: forty) and a two-word quote left out. Non-JSON, two titles, empty notes, one chapter, no quote found: each a retryable failure |
| Keychain | Save, read, replace and remove on a test item; tests never touch Ivan's item; with no key the Claude API's test sends nothing ("No key added. Nothing is sent to Anthropic.") |
| **Models screen, each provider tested for real** | LM Studio: "Answered in 14 s. Loaded Qwen3.8-27B in LM Studio at 65,536 tokens in 8 s. Unloaded again after the test." Apple on-device: "Wrote 3 tags in 0.8 s: breath, exhale, pause." Ollama: "Ollama answers. Installed: qwen3:4b. Name one above to use it." Claude API: "No key added. Nothing is sent to Anthropic." |
| Regression: `make accept-outputs` and `make accept-edits` (MILESTONE=m6-regress) | -16.8 and -19.1 LUFS as before; with the trim off the decoded audio md5 `69658a8c...` is **identical to engine v0's**; the cut episode 907.732 s, 38.82 s shorter as expected; a class still refused |
| `make check MILESTONE=m6` | Tests pass; PASS still running 15 s after its window closed; real-window captures **16 of 16 PASS** |
| `make migrate-check` | The live store copy opens: 11 recordings, 2 folders, 27 output settings; the new fields empty; **titles on in 0 folders**, so nothing starts writing on its own after the upgrade |
| **Installed live** (`make install`, 20:01:33, and again at 20:20:33 with the final code) | Quit cleanly, replaced, opened: "Mode: live. Store: ...Prakriti.store" (no fallback), login item on, "Checked 2 folders. Nothing new.", still running afterwards (pid 16709); signed Apple Development, team LD587PB2H8, `codesign --verify --deep --strict` passes. LM Studio left unloaded, as it was at the start of the session |
| Pictures | `screens/mac/m6/`: every screen light and dark from `make test` (including the Models screen and the recording page with what Qwen wrote, and a class not written yet with the lock line), the acceptance's page after the real writing and the Models screen after the real tests (`m6-13sep-written-*`, `m6-models-*`), and `real/` (16 real-window captures). **Looked at:** the Models screen light and dark, every screenful; the recording page's writing section light and dark; Outputs; Sources; the class page |
| Em and en dashes, tooltips | 0 in `mac/`, START_HERE, CHANGELOG, LOCAL-MODEL.md; RulesTests pass |

### What the look-through and the runs caught and fixed

- **The first real show notes, and Apple's summary, repeated a private family matter the talk
  mentions.** Nothing in the checks could catch it: it was true and in the transcript. The writing,
  tagging and summary prompts now leave out illness, deaths, grief, family matters, money troubles and
  relationships (anyone's), while the checklist may keep the speaker's own income or health claims,
  which must be checked. The second run had none. START_HERE warning 51; a prompt is not a guarantee.
- **"Privacy lock: serenity is in this recording":** the reason was lowercased to sit mid-sentence. The
  reasons are now written to sit mid-sentence ("this is a class", "Serenity is in this recording") and
  capitalized only to start one; a test pins her capital. The same lowercasing would have printed
  "lM Studio" and "qwen3.8" in a failure line; those sentences no longer lowercase anything.
- **Chapter titles of five words** ("Life Update and India Trip") despite "at most 4": the prompt now
  says "2 to 4 words (count them)", with an example; the second run's were 3 to 4 words. A longer
  title is still kept and noted, never cut.
- **The Models screen said "On this Mac" twice and Apple's 8,192 tokens three times:** the row is
  "Status" and the test line says only what the test did.
- **"Loaded ... at 65,536 tokens" was logged after a ten-minute answer**, timed as if it had just
  happened: the model is now loaded before the first request and the line written then (third run:
  logged 9 s into the step).
- Test-side: an em dash inside a regular expression in my own code tripped RulesTests (now written as
  `\u{2014}`); a fixture quote tripped the banned-words rule for app strings, so the fixture uses
  another of the real claims.

### Decisions, each with its reason

1. **Off for every folder, including the live studio folder** (`isOnByDefault` false; migrate-check
   asserts it). Reason: 10 to 15 minutes and 33 GB per recording should be Ivan's choice.
2. **Prakriti loads and unloads the model itself, through LM Studio's REST API.** Reason: a request to
   an unloaded model loads it at LM Studio's default 8,192; and leaving 33 GB loaded all day for a few
   minutes of writing per recording is a cost Ivan did not choose. A model Ivan loaded is left loaded.
3. **No `response_format`.** Reason: both runs returned clean JSON without it, LOCAL-MODEL.md calls
   schema enforcement on this model unproven, and Swift checks the JSON either way.
4. **Chapter and quote checks drop, never fix,** except two stated fixes: the first chapter is moved to
   the first line, and a chapter too short joins the one before. Reason: a time or a quote the
   transcript does not have is the model's invention; a moved first chapter and a joined short one
   change no claim.
5. **Quotes are matched with whitespace and typographic quotes evened out, nothing else.** Reason:
   `transcript.txt` is one long line and models write curly apostrophes; case, spelling and punctuation
   are what "word for word" means.
   A quote is found in `transcript.txt` or in the lines the model read. Reason: on a recording engine
   v0 made (the live 13 Sep and 6 Sep talks), the `.txt` has no word list fixes while the lines do, so
   a true quote naming Krishnamacharya would otherwise be dropped (found reading the code after the
   acceptance; covered by `WritingTests`, not by a real run).
6. **A writing failure does not fail the make.** Reason: the episode and transcript took their own
   work and are good; Write Again is one click.
7. **The written files go with the make that wrote them;** a make without writing removes the old ones.
   Reason: an old draft beside a new transcript (after a cut) could quote words that are gone.
8. **Approve copies `show-notes.md`, not the JSON.** Reason: the JSON keeps the model's own answer,
   including quotes that failed the check.
9. **"Serenity" anywhere in the transcript locks the recording, even as a common word.** Reason: a false
   alarm only keeps text on this Mac; a miss would send her teaching out.
10. **Tags and summary are their own tasks with their own providers,** not folded into the writing
    request. Reason: the Models screen offers a provider per task, and a switch that does nothing is
    the problem milestone 4 fixed. On Apple on-device they take 3 to 5 s.
11. **The Claude API defaults to `claude-opus-5-5`** with adaptive thinking and medium effort, raw
    HTTP. Reason: the current Opus per Anthropic's own guidance; there is no Swift SDK. Never tested
    with a key: none was added, and adding one is Ivan's.
12. **The Started notice adds about 5 minutes plus 0.3 s per second of recording when writing is on.**
    Reason: one measurement (603 s for the 15:48 talk); a guess stated as one.

### What does not work yet, or was not seen working

- **The Claude API has never answered:** no key exists, so only "no key, nothing sent" was tested.
- **Ollama has never written anything:** it answers and lists `qwen3:4b`, but no model is named.
- **The writing has run on one recording** (the 13 Sep talk, twice). The 55-minute 6 Sep talk would
  take longer (an estimate, not a measurement) and has not been written. A recording of about two hours
  reaches the 65,536-token limit by the size estimate; beyond it the writing is refused with the
  reason, never cut off (chunked writing is not built).
- Apple on-device's tags are weak ("yoga of communication"); LM Studio is the default for tagging.
- No person has clicked Use This Title, Use as Notes, Write Again, a test button or Save in Keychain in
  the real window; each was driven through the same model calls the buttons make.
- Notifications are still turned off for Prakriti in System Settings (since milestone 3).

### For Ivan

1. **Turn notifications on for Prakriti** (still blocked on your click, since milestone 3).
2. **To try the writing:** open Recordings, Sun 13 Sep, and press **Write Titles and Notes** (LM Studio
   must be open with its server on; Prakriti loads the model itself and takes about 10 minutes). Or
   turn on Titles, show notes and chapters for one folder on Sources.
3. **Read the draft before trusting it.** The checks prove the times and quotes are real, not that the
   claims are right or that nothing private slipped in. The first run put a private family matter in
   the show notes; the prompt now forbids it, but a prompt is not a guarantee.
4. **A Claude API key, if you want one,** goes on Models, Claude API, Save in Keychain. Classes and
   anything with Serenity in it never reach it either way.
5. LM Studio's default port is 1234; yours is 1235, which is what Prakriti uses.

To see it:

```bash
cd ~/Code/prakriti/mac && open ~/Applications/Prakriti.app
```

Then Models, or Recordings, Sun 13 Sep.

---

## Finish line, Sat 10 Oct 2026

**Prakriti for Mac v1 passes its finish line.** All six milestones passed their checks on real
recordings (the 13 Sep talk, the 6 Sep talk, the silent 14 Sep class, clips cut from the 13 Sep talk).
Since 14:57 it is the live engine: installed at `~/Applications/Prakriti.app`, opening at login,
watching the Studio Recordings folder and `~/Prakriti/Drop`, writing to `~/Prakriti/Outputs`. Engine
v0 is retired. Nothing has been published, uploaded or sent, and `~/Prakriti/Approved` is empty: no
yes has been given on Ivan's behalf.

### How it was checked

Each milestone was built, then re-checked by an independent verifier working from a fresh clone and
the real app. The verdicts relayed to this session: **milestone 1 passed** (16 checks, one blocked:
the menu bar menu cannot be pictured without Screen Recording permission) and **milestone 2 passed**
(reproduced from a fresh clone: the 13 Sep episode -16.8 LUFS, true peak -1.6 dBFS, decoded audio
bit for bit the same as engine v0's). The milestone 5 verifier found the caption-order regression,
fixed and re-measured in "Milestone 5 fixes" above. The milestone 6 verifier ran the real writing
again (20:28 to 20:39; notes in `screens/mac/m6-verify/verifier-independent-check.txt`). The
milestone 3 and 4 verifiers' pictures and acceptance text are in `screens/mac/m3-verify/` and
`screens/mac/m4-verify/`; their verdict text was not relayed to this session, so this section relies
on the measurements in those milestones' own entries.

Re-checked for this section, 20:44 to 20:50, on the final commit (`11f7781`):

| Check | Result |
|---|---|
| `make test MILESTONE=finish` | **113 tests, 0 failures, 5 skipped by design** (the four acceptances and the migration check), 248 s. 128 pictures of every screen, light and dark, in `screens/mac/finish/`; Today empty and the 13 Sep steps looked at |
| The live app | Running (pid 16709, opened 20:20:33 by `make install`). Its log shows the 5-minute look every time: "Checked 2 folders. Nothing new." at 20:25:33, 20:30:53, 20:36:13, 20:41:24, 20:46:44 |
| Engine v0 | `launchctl print gui/501/studio.therowan.prakriti`: "Could not find service". Its plist is in `~/Prakriti/retired/`. `~/Prakriti/Outputs` holds only v0's two folders (8 and 9 Oct); `~/Prakriti/Drop` and `~/Prakriti/Approved` are empty |
| The installed app's signature | `studio.therowan.prakriti.app`, team LD587PB2H8, `codesign --verify --deep --strict` passes |
| LM Studio | `qwen/qwen3.8-27b` present, **no instance loaded**: Prakriti unloaded what it loaded |
| The 13 Sep episode, measured again (made 20:28 in development) | ebur128: **-16.8 LUFS, true peak -1.7 dBFS**, loudness range 4.2 LU. ffprobe: 946.55 s, mono, 48 kHz, 128 kbps. Last 5 s decode clean. 137 captions, 0 starting with punctuation, the last ending at 15:46.4 on the episode's clock (15:47 of 15:48 on the recording's). `show-notes.md`: 0 em or en dashes |
| The approved test episode (development) | ffprobe: **907.732 s** against the recording's 947.780 s: the 10 s trim and the 30 s cut are gone |
| Housekeeping | Two `tail -f` processes left on the development log by earlier build sessions (started 13:50 and 19:15, orphaned) were stopped. Nothing else was touched |

### What works, with the measured evidence

| What | Measured |
|---|---|
| **The app** | Signed with Ivan's Apple Development certificate, no sandbox, hardened runtime. Keeps running with its window closed (verifier: alive 2 min 30 s with no window). One watcher per mode: a second live copy logs why and quits |
| **Finding recordings, with no clicks** (milestone 3) | Live, after the switch-over: a 90 s clip moved into `~/Prakriti/Drop` was **found in 7 s and Ready for your yes 78 s later**, most of it the 60 s wait that proves the file finished copying. Changes made while Prakriti was closed are caught on the next launch. The switch-over imported v0's memory, so **nothing v0 had seen was made again** (11 recordings, 0 runs) |
| **The pipeline** (milestone 2) | The 13 Sep talk: **-16.8 LUFS, true peak -1.6 dBFS, transcript reaching 15:47 of 15:48, 2,948 words**, in about 41 s. The 6 Sep talk (episode 1): -16.7 LUFS, 55:38 of 55:39. Both episodes decode **bit for bit the same as engine v0's**. The silent 14 Sep class: **Needs a decision, nothing made** (loudest point -91 dB). A 30 s clip: filed as a test, nothing made, no notice |
| **Outputs and settings** (milestone 4) | Loudness target -16 made -16.8 LUFS; changed to -19 and made again: **-19.1 LUFS on two meters**. Transcript turned off: no transcript file left. Everything off: bit for bit v0's episode. Silence trim, intro, outro and stereo measured on generated audio. The Yoga Marga word list made 15 fixes on the 13 Sep talk, none wrong |
| **The recording page** (milestone 5) | Trim the first 10 s, cut 5:00 to 5:30, Make Again, Approve: the approved episode is **38.82 s shorter, exactly as expected**; Parakeet run again on it heard **0 of the 73 five-word runs said inside the cut**. Captions: 137 of 137 (13 Sep) and 555 of 555 (6 Sep) read exactly as Parakeet wrote each sentence. A recording marked as a class is refused at Approve. The system player plays the episode or the original; a transcript line plays from its moment |
| **The models** (milestone 6) | Qwen3.8-27B in LM Studio, four runs on the 13 Sep talk (three by the builder, one by the verifier): **valid JSON every time, 3 titles, 3 chapters each starting on a real transcript line, and 8, 7, 8 and 6 quotes found word for word** (the verifier's run dropped one quote that was not word for word, as the check is meant to). Prakriti loads the model at 65,536 tokens itself (8 s) and unloads it after. The writing takes about 10 to 14 minutes. **Privacy lock:** with the writing set to the Claude API, the 13 Sep talk (it names Serenity) went to LM Studio and **the Claude API was asked 0 times**. Apple on-device wrote 3 tags for a short input in 0.7 s |
| **Design rules** | Body text 17 pt, nothing under 12 pt, no tooltips (they draw at 11 pt), no em or en dashes anywhere in the app: each enforced by `RulesTests`, inside the 113 |

### What does not work, or was not reached

- **No notice has ever reached the screen.** macOS has notifications turned off for Prakriti (the live
  log says so at every launch, last at 20:20:33). The notice builder, its wording and its identifiers
  are proved by tests, and macOS accepts each request; a banner on screen and a click opening the
  recording were never seen. Until Ivan turns them on, **a silent class shows in Today and Activity
  but not as a banner.**
- **The menu bar menu was never pictured** (it needs Screen Recording permission). The log says
  "Menu bar item: shown".
- **No person has clicked through the app.** Every button was driven through the same code it calls,
  and the real window was captured in each state, but a hand click on a line, the player's sound,
  typing in a field and the confirmation dialogs were not done by a person.
- **Episodes are leveled moment to moment, not evenly,** on every studio talk, since engine v0 and
  including episode 1. Not changed on purpose: it needs Ivan's ears before anything about how
  episodes sound changes, and episode 1 ships Fri 23 Oct.
- **Speakers are not checked.** Only a recording Ivan marks "Talk, one teacher speaking" can be
  approved. Classes and conversations cannot be approved in v1.
- **The accuracy check proves the quotes, not the claims.** In the verifier's run, the claim "The
  teacher was living on 300 dollars a month in 2018" sits on the quote "living on his buddy's couch
  for 300 bucks a month" (a couch for 300 a month, not a whole budget), and two other claims add
  words their quotes do not say ("Pacific time", "within six months"). Every claim needs a person.
- **Nothing restarts Prakriti if it crashes** until the next login (engine v0's LaunchAgent restarted
  itself). The only sign is Activity going quiet: no "Checked 2 folders" line for more than 5 minutes.
- **The writing is proved on one recording** (the 13 Sep talk, four runs). The 55-minute 6 Sep talk
  has not been written; about two hours is the limit, and longer is refused, never cut off. The
  Claude API has never answered (no key exists); Ollama has never written; Apple's tags are weak.
- **Not tested for real:** closing the lid (sleep and wake), a real login (opening at login is
  registered "on"), a real intro or outro file. Readiness is v0's rule (60 s steady), not SCOPE
  7.3's fuller one.
- **Not built, as the spec said:** edited video, three thumbnails, shorts, knowledge base, voice
  dataset (each shown as "Not built yet" with one line), and any publishing.
- Small: the transcript does not scroll to follow the player; the word list cannot be edited in the
  app.

### For Ivan: what needs you

- [ ] **Turn on notifications** (since milestone 3): System Settings, Notifications, Prakriti: Allow
  notifications, Banners, Play sound.
- [ ] **Look at the menu bar once:** a ring icon; its menu has the status line, Open Prakriti, Pause
  All, Settings and Quit Prakriti.
- [ ] **Listen to episode 1 before Fri 23 Oct** (`~/Prakriti/Outputs/2026-09-06 18-06-33/episode.mp3`)
  for quiet passages swelling and loud ones sitting down. Say if it pumps.
- [ ] **At your next login, nothing to do;** afterwards the log should say "Finished launching at
  login". If Prakriti is not in the menu bar after a restart, open it once.
- [ ] Glance at the word list's spellings (Outputs screen), especially Krishnamacharya, Pattabhi Jois
  and Iyengar.
- [ ] Optional: a Claude API key (Models, Claude API, Save in Keychain). Nothing in v1 needs it.
- Before approving anything: under About this recording, set What this is to "Talk, one teacher
  speaking". Approve copies to `~/Prakriti/Approved`, your real yes folder.

### The best picture of every screen

All under `~/Code/prakriti/screens/mac/` (gitignored, on this Mac only). "Real" means the real
running window; the others are drawn by the tests. Every one listed was looked at.

| Screen | Picture |
|---|---|
| Today | `m6/real/01-today-light.png` |
| Today, the live app on Ivan's real recordings | `m3/real/m3-live-today.png` |
| Today, nothing waiting | `finish/09-today-empty-dark.png` |
| Recordings | `m6/real/02-recordings-dark.png` |
| Sources | `m6/real/03-sources-light.png` |
| Outputs | `m6/real/04-outputs-light.png` |
| Models | `m6/real/05-models-dark.png` |
| Activity | `m6/real/06-activity-light.png` |
| Settings | `m6/real/07-settings-dark.png` |
| A recording's page, the live 13 Sep talk, with the system player | `m5/real/m5-real-live-13sep-page.png` |
| A recording's page with a trim and cut not made yet | `m5/real/m5-real-page-light-edits.png` |
| Titles, show notes and chapters written by Qwen3.8-27B, with the privacy lock line | `m6/m6-13sep-written-light-p3.png` |
| The silent class: Needs a decision, privacy locked | `m6/08-recording-silent-dark.png` |
| The steps and their timings on the 13 Sep talk | `finish/08-recording-class-not-written-light-p4.png` |
| A folder refused (a test copy asked to watch the studio folder) | `m6/real/08-refusal-light.png` |
| The menu bar menu | None: blocked on Screen Recording permission |

The full set from the final code, every screen light and dark and every screenful of the long pages,
is `finish/` (128 pictures).

### Try these three first

1. **Turn on notifications, then drop a recording in.** Copy any talk at least a minute long into
   `~/Prakriti/Drop` (never a class). Within about a minute and a half you should see "New Recording
   Found", then "Ready for Your Yes". Open it from the notice. This is the one thing no one has seen
   on screen yet.
2. **Open Sun 13 Sep and use the page with your own hands.** Recordings, Sun 13 Sep: press play,
   click a line of the transcript and hear it jump there, type 0:10 in "Episode starts at", press
   Make Again, and listen to the start. Use the 13 Sep talk, not episode 1 (Sun 6 Sep), so episode
   1's files stay exactly as they are.
3. **Have it write the titles and show notes, then check its claims.** Open LM Studio with its server
   on, press Write Titles and Notes on the 13 Sep page, and wait about 10 minutes. Then read the
   accuracy checklist against the episode: the quotes are guaranteed to be real, the claims are not.

To open it:

```bash
cd ~ && open ~/Applications/Prakriti.app
```

---

## Podcast-ready episode. Sat 10 Oct 2026

Ivan asked for podcast-ready edited audio as an output, as close as possible to a file that can be
uploaded to a podcast host as it is, with a text file of the episode's name, show notes and social
captions. Built as a new output, "Podcast-ready episode", separate from "Podcast episode" (which stays
engine v0's chain: the quick draft to listen to).

### The diagnosis first: why episode 1's MP3 rides its volume

Measured 10 Oct on the originals and engine v0's MP3s in `~/Prakriti/Outputs` (read only), and again
by `make accept-podcast` (its report, `screens/mac/podcast/acceptance-podcast-*.txt`):

| | 6 Sep talk (episode 1) | 13 Sep talk |
|---|---|---|
| The talk as recorded (mono mix) | -23.80 LUFS, true peak +0.04 dBTP, loudness range 6.6 LU | -26.67 LUFS, true peak -0.38 dBTP, range 6.2 LU |
| Peak over loudness | 23.8 dB | 26.3 dB |
| What a linear raise to -15.4 with the peak at -1.5 allows | 13.9 dB | 13.9 dB |
| loudnorm's second pass, engine v0's chain run again | **`normalization_type` dynamic** | **dynamic** |
| engine v0's MP3 | -16.7 LUFS, true peak -1.2 dBTP, **range 5.2 LU** | -16.8 LUFS, -1.6 dBTP, **range 4.2 LU** |
| The gain it applied over speech (short-term loudness, MP3 less original, 5th to 95th percentile) | 5.3 to 9.3 dB (a 4.0 dB spread; min 0.7, max 13.8) | 8.0 to 12.3 dB (4.3 dB spread) |
| Seconds where that gain moved more than 2 dB within one second | **104 s** (largest 10.2 dB) | 58 s (largest 7.7 dB) |
| Quiet passages against loud ones | +9.8 dB on the quietest speech, +5.9 on the loudest | +13.2 and +8.5 |
| The room tone in pauses (original momentary under -50 LUFS) | +9.7 dB median, **+13.6 at the 95th percentile**, against +7.4 on speech | +12.8 and **+17.1**, against +10.3 |

**The cause:** the talks' peaks sit about 24 to 26 dB over their loudness; raising them evenly to the
target would push the peaks 10 to 12 dB past the ceiling, so loudnorm's second pass silently gives up
"linear" and rides the level from a 3-second window, lifting quiet passages and the room tone between
sentences, then pulling the level down when speech returns. Milestone 2 found the mode; these are the
numbers of what it did. Engine v0's MP3 lines up with the original frame for frame (the alignment was
checked: any shift but 0 widens the spread), so the gain curve is the chain's, not a timing artifact.

### What was built

- **The output** (`OutputKind.podcastReady`, "Podcast-ready episode"), off for every folder; an older
  store gets its settings switched off at launch (`PrakritiStore.addMissingOutputKinds`). Settings on
  the Outputs screen (and a recording's own): show name, host or author, show artwork (checked against
  Apple's rules as soon as it is chosen), explicit, mono or stereo, bitrate (64, 96, 128 mono; 128, 192
  stereo), light noise reduction, and "the intro or outro has an AI-made voice". Episode and season
  numbers are the recording's own, on its page. It uses the podcast episode's silence trim, intro and
  outro, and the recording's trim and cuts.
- **The chain** (`PodcastMastering`, run by `Pipeline.masterPodcastReady`): the talk (trimmed and cut,
  at 48 kHz) through a 70 Hz high-pass, optional afftdn, a gain to -20 LUFS, a 1.5:1 compressor above
  -22 dB (20 ms attack, 500 ms release), the layout at 44.1 kHz, rendered once to a float WAV; the intro
  and outro brought to the processed talk's loudness and joined; the gain before a -3.0 dBFS limiter
  found by measuring until loudnorm's own correction is under 0.2 LU; loudnorm's second pass in linear
  mode to -16 LUFS plus a 0.4 LU encoder allowance; the layout and rate again; a last limiter at -2.7;
  LAME CBR. The MP3 is measured to the hundredth (loudnorm's meter): a true peak over -1.1 dBTP or a
  loudness off by more than 0.5 makes it once more with the limits lowered by the excess.
- **The package** (`Pipeline.packagePodcastReady`), in `<Outputs>/<recording>/Podcast-ready/`:
  - `<Show name> - <Episode title>.mp3` (ASCII only, as Apple asks; the date until a title is chosen),
    its **ID3v2.4 tag written by Prakriti** (`ID3.swift`): TIT2 title, TPE1 host, TALB show, TDRC year,
    COMM the summary, TCON Podcast, TRCK the episode number, APIC the artwork when it passes, and the
    chapters as a CTOC listing CHAP frames, each with its title, the first at 0:00.
  - `<same name>.srt` and `.vtt`, timed to the finished file (`EpisodeTranscript.cues` on the episode's
    clock: the intro, the trim and the cuts all moved in).
  - `Title, show notes and captions.txt`: the episode title (or the writer's three options), the show
    and episode details, the show notes (Ivan's own, or the writer's draft, said to be a draft), the
    chapters, three social captions and hashtags from the tags, the summary, what is not chosen yet.
  - `Upload checklist.txt`: 23 lines, each PASS, MISSING or FAIL with the measured value and what to
    do, measured on the tagged file and read back (see "Checks" below).
- **Social captions** (`WritingCheck.captions`): asked for in the same single writing request (no
  second load of the 33 GB model), three of them, at most 120 and 150 to 280 characters, describe never
  sell; any words a caption puts in quotation marks must be found word for word in the transcript or
  the caption is left out and counted; dashes, exclamation marks, hashtags and links are taken out.
  Shown on the recording page under the show notes and in `show-notes.md`.
- **Update Podcast-Ready Files** (`PipelineRunner.packageAgain`, trigger `packageAgain`): re-tags,
  renames and rewrites the text and checklist around the audio already made, without mastering again, for a new
  title, notes, show name, host, artwork or episode number; the page says when the files are out of
  date. Write Again updates them too. The audio is never made again by it (tested byte for byte); it
  measures the file again, so it takes about 10 s on a 16-minute talk and 35 s on episode 1.
- **Approve** copies the `Podcast-ready` folder, every file in it listed in `APPROVAL.md` with its
  SHA-256 (tested).
- **The recording page** gains a "Podcast-ready episode" section: the file and Show in Finder, the
  sound and the file in one line each, the checklist's summary with every line that does not pass and
  what to do, Open Checklist, the episode and season, and Update Podcast-Ready Files.
- **REPORT.md** gains a "Podcast-ready episode" row; Activity and the step lines carry the numbers.
- **Make:** `make accept-podcast` (`PodcastReadyAcceptanceTests`), and `make migrate-check` now runs
  the store upgrade on its copy.

### How each setting was chosen, measured 10 Oct

| Setting | Measured | Chosen |
|---|---|---|
| High-pass | The voice's energy by band (speech windows, both talks): 90 to 120 Hz -13.6 and -15.2 dB of the whole, 70 to 90 Hz -27 to -30, under 70 Hz -39 to -48 (pops and room). An 80 Hz two-pole filter takes about 1.5 dB off the voice's lowest notes | **70 Hz**, two poles |
| Noise reduction | The room tone sits 38 dB under the speech on 13 Sep and 51 dB on 6 Sep. afftdn at nr 6 and 12 lowered the pauses by 1.5 dB and left the speech at -26.7 LUFS | **Off** by default; an option for a noisier room |
| Compressor | Six settings on both talks, against v0's 4.2 and 5.2 LU and its 58 and 104 s of gain jumps. 2:1 to 3:1, or a 50 ms attack and 1 s release, made 62 to 123 s of jumps. None at all left 4.8 LU on 13 Sep (above v0's) | **1.5:1 above -22 dB, 20 ms, 500 ms**: 3.7 and 4.7 LU |
| Limits | alimiter limits samples: the encoded true peak lands 1.2 to 1.8 dB over its limit. When the last limiter took 0.7 dB the true peak rose (-0.9, -1.0). At -2.8 the 6 Sep talk trimmed by 10 s reached -0.98 dBTP | **-3.0 then -2.7 dBFS**, and a remake once over -1.1 |
| Encoder allowance | The master -16.0 LUFS, the MP3 of it -16.4 at 96 and 128 kbps, -16.2 at 192 | **+0.4 LU** |
| Bitrate | Null test against the master (13 Sep): coding noise 18.9 dB under the speech at 64 kbps, 24.1 at 96, 25.6 at 128; 29, 43 and 58 MB an hour; 64 kbps pushed the true peak to -0.3 dBTP. Apple recommends 96 to 128 kbps for mono MP3 | **96 kbps mono**, 44.1 kHz |

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| `make test MILESTONE=podcast` (final code) | **125 tests, 0 failures, 7 skipped by design** (the five acceptance methods, two of them new, and the migration check), 301 s. New: **PodcastReadyTests 10** |
| The chain, string for string | `testTheChainIsTheMeasuredOne`: the talk chain, the gain stage, loudnorm linear with `level=disabled` limiters, the layout and 44.1 kHz before the last limiter (v0's bug 2), stereo never under 128 kbps |
| **A chapters test file with 3 chapters** | `testATagWithThreeChaptersIsReadBack`, on a generated 200 s MP3: the CTOC (top level, ordered, ch0 ch1 ch2) and **three CHAP frames read back** by Prakriti's reader (starts 0, 60,000, 130,000 ms; ends 60,000, 130,000, 200,000; titles as written) **and by ffprobe** (3 chapters at 0.000000, 60.000000, 130.000000 with their titles); TIT2, TPE1, TALB, TDRC 2026, TCON Podcast, TRCK 3, a real **COMM** frame, APIC front cover; the audio decodes to the same number of samples before and after (gapless kept); broken chapters (out of order, only two) are caught |
| **Artwork validation, generated test images (not shipped)** | `testArtworkIsCheckedAgainstApplesRules`, nine images drawn in a temporary folder and deleted: a 1400 px RGB JPEG and a 3000 px PNG **pass**; 1000 px (too small), 1400 by 1500 (not square), 3200 px (too large), a PNG with alpha, a grey JPEG, a 3000 px noisy JPEG over 512 KB, and a text file named .jpg each **fail with their own reason** |
| **The captions follow a 10 s trim**, on the Mac's own voice | `testThePodcastReadyEpisodeAndItsCaptionsFollowATrim`: a known line moves by exactly 10 s less the silence trim (to the millisecond), the trimmed line is gone from the captions, the length shorter by the same; the package named, tagged, measured (-16 within 1, -1 or under, linear), its checklist MISSING show name and artwork; Approve copies the folder with every file's SHA-256 in the receipt |
| Update Podcast-Ready Files | `testUpdatingTheFilesRetagsWithoutMakingTheAudioAgain`, through the app: a show name, host, title and episode number set, the files updated: renamed `Test Show - The Long Exhale.mp3`, the old name gone, **the audio byte for byte the same**, TALB, TPE1, TIT2, TRCK read back, the checklist's show name and title now PASS |
| An older store | `testAnOlderStoreGetsTheNewOutputSwitchedOff`: the default and one per live folder added, all off, once only |
| **6 Sep talk (episode 1), `make accept-podcast`** (final code, 22:37 to 23:16) | |
| Diagnosis, measured again | the talk -23.80 LUFS, +0.04 dBTP, range 6.60 LU; peak over loudness 23.84 dB, 13.90 allowed; **engine v0's second pass: `dynamic`**; v0's MP3 -16.7 LUFS, -1.2 dBTP, **range 5.2 LU**; its gain over speech 5.3 to 9.3 dB, **more than 2 dB within a second for 104 s** (largest 10.2), pauses 9.7 to 13.6 dB |
| The new MP3 | **-16.02 LUFS integrated, true peak -1.20 dBTP** (loudnorm's meter); **-16.0 LUFS, -1.2 dBTP by ebur128**; **loudness range 4.7 LU against v0's 5.2**; **loudnorm `linear`**; its gain over speech 6.5 to 10.3 dB, more than 2 dB within a second for 92 s (largest 8.3), pauses 13.1 to 16.3 dB; 55:36, 40.0 MB, mono 96 kbps 44.1 kHz |
| Its tail and tags | the last 5 s decode with no error; **ffprobe: date=2026, genre=Podcast, title=Sun 6 Sep 2026, comment present, no album** (no show name invented); ID3 frames read back: TIT2 TDRC TCON COMM CTOC and 5 CHAP; **5 chapters read back by Prakriti and by ffprobe**, the first at 0:00, the last ending at 55:36 |
| The 10 s trim | caption 101 ("And when we did um that first retreat...") at 777.183 s, then 770.040 s: **7.143 s earlier, expected 10 s less the 2.86 s silence trim = 7.143**; the file 3336.192 s, then 3329.049 s |
| The checklist | **0 FAIL, 6 MISSING, 17 PASS: Show name MISSING, Artwork MISSING**, Episode title MISSING (three drafts offered), Host MISSING, Show notes MISSING (a draft, not chosen), Speakers MISSING; **Loudness PASS -16.02, True peak PASS -1.20**, Leveling PASS, Chapters PASS (5), Transcript PASS (555 captions, the last ending at 55:36 of 55:36), Social captions PASS (3) |
| Writing, the first time on this talk | about 19,940 tokens to read; the request **1,115 s** (17,454 read, 9,040 written of which 8,009 thinking), one try: 3 titles, 5 chapters, 7 quotes found word for word, 3 social captions; tags 151 s and summary 181 s also on LM Studio; the step 24 min 16 s |
| Times | podcast-ready audio 124 s (the episode's first pass reused) to 159 s; the files 34 s (the two-decimal meter over 55 minutes); the whole make with writing 29 min 6 s |
| **13 Sep talk, `make accept-podcast`** (final code, 23:16 to 23:48) | |
| Diagnosis | the talk -26.67 LUFS, -0.38 dBTP, range 6.20 LU; peak over loudness 26.29 dB; **v0's second pass `dynamic`**; v0's MP3 -16.8 LUFS, -1.6 dBTP, **range 4.2 LU**; its gain over speech 8.0 to 12.3 dB, more than 2 dB within a second for 58 s, pauses 12.8 to 17.1 dB |
| The new MP3 | **-16.03 LUFS, true peak -1.78 dBTP** (loudnorm); -16.0, -1.8 (ebur128); **range 3.7 LU against v0's 4.2**; **`linear`**; gain over speech 8.9 to 13.7 dB, more than 2 dB within a second for 66 s (largest 7.2), pauses 16.2 to 19.3 dB; tail decodes; ffprobe date 2026, genre Podcast, no album; **3 chapters read back by both readers** |
| The 10 s trim | caption 41 at 281.298 s, then 272.480 s: **8.818 s earlier, expected 10 s less 1.18 s = 8.818**; 946.550 s, then 937.732 s |
| The checklist | **0 FAIL, 6 MISSING, 17 PASS**, the same lines as 6 Sep; Loudness PASS -16.03, True peak PASS -1.78 |
| Writing | the request 1,409 s (11,330 thinking tokens), one try: 3 titles, 3 chapters, 7 quotes, 3 social captions (an earlier run: 1,046 s, 8,092 thinking); the step 27 min 41 s with tags and summary on LM Studio |
| Both talks | the originals' size and date unchanged; LM Studio left with nothing loaded; writes only in `~/Prakriti/Dev/Outputs` |
| A first run of the same acceptance, on the code before the fix | passed on 13 Sep, and **found the 6 Sep trimmed file at -0.98 dBTP**, which led to the fix (above); stopped before its writing, model not left loaded |
| `make migrate-check` | the live store copy opens: 11 recordings (2 ready), 2 folders, 27 output settings, 134 Activity lines; every new field empty; **the new output added to the copy, switched on in 0 folders** |
| `make look MILESTONE=podcast` | **16 of 16 PASS** (selected row icon 437 to 845 px, the refusal alert light and dark). Outputs in the real window, light and dark, looked at: the new section, its switch off, the show name field |
| Snapshots | `screens/mac/podcast/`: every screen light and dark, and the acceptance's pages (`podcast-2026-09-06-*`, `podcast-2026-09-13-*`). **Looked at:** Outputs (both screenfuls with the new settings) light; the recording page's writing section with the captions and its podcast-ready section, light and dark; Sources with the new switch |
| **Installed live** (`make install`, 23:55:55) | quit cleanly, replaced, opened: "Mode: live. Store: ...Prakriti.store" (no fallback); "New output available: Podcast-ready episode. It is off for every folder until you turn it on."; "Checked 2 folders. Nothing new."; `codesign --verify --deep --strict` passes. `~/Prakriti/Outputs` still holds engine v0's files of 8 and 9 Oct; `~/Prakriti/Approved` and `~/Prakriti/Drop` empty |
| Em and en dashes | 0 in `mac/`, the docs, and every generated checklist, text file and show-notes.md |

### What the runs and the look-through caught and fixed

- **A true peak over Apple's line passed the checklist.** The 6 Sep talk trimmed by 10 s measured
  "-1.0 dBTP" by ebur128 (one decimal) and -0.98 by loudnorm (two). The finished file is now measured
  with loudnorm's meter, kept only at -1.1 or under, and the limits start 0.2 dB lower. The run in
  progress was stopped (its model was not left loaded) and both talks were made again on the fix.
- **ffmpeg's tags were not what the task asks for**: the comment went into a TXXX frame, not COMM, and
  the CHAP frames had no titles (ffprobe showed "ch0"). Prakriti now writes the tag itself and reads it
  back; ffprobe reads the chapter titles.
- **The last limiter raised the peak it was meant to hold** when it had to take 0.7 dB; the gain is now
  staged so it barely acts.
- **The encoder takes 0.4 LU**: the MP3 measured -16.4 from a -16.0 master; the master aims 0.4 higher.
- **The riding measure itself was off by 20 ms** on a trimmed file (the shift rounded to a 100 ms
  frame): the pauses' 95th percentile read 22.9 dB where reading the original between frames gives
  19.0 (the same file; the untrimmed prototype gave 18.2). The acceptance reads between frames now.
- File names are ASCII only ("Mārga" becomes "Marga"), as Apple asks for file names and addresses
  (research 06 §3.3). A hashtag from "Five A's" read "#FiveAS"; apostrophes now join their word.
- Checklist wording: "the intro, talk and outro" on an episode with neither; the tags listed out of order.
- The date in new code comments said 11 Oct; it is Sat 10 Oct (`date(1)`).

### Decisions, each with its reason

1. **A separate output, not a change to "Podcast episode".** Reason: episode.mp3 is engine v0's chain,
   proved bit for bit, and episode 1 was approved in that form; the podcast-ready file can be compared
   with it by ear before anything is switched.
2. **96 kbps mono, not SCOPE PKG-01's 128.** Reason: the build asked for a choice from measurement; 96 is
   the knee of the null test, inside Apple's recommendation, and 40 MB for episode 1 instead of 53. 128
   is one click on the Outputs screen if Ivan prefers it.
3. **Chapters in the ID3 tag**, as the task asks; SCOPE PKG-01 proposed chapters in the feed only. Both
   can be done; the feed is not built.
4. **No expander** (SCOPE PIP-18 lists one). Reason: an expander that misjudges a quiet word "breathes";
   the measured cost of not having one is a room tone about 3.4 dB louder in pauses than engine v0's,
   on the median (13 Sep: 16.2 dB of gain against 12.8; 6 Sep: 13.1 against 9.7), and steadier (the
   spread from median to 95th percentile 3.1 and 3.2 dB against 4.3 and 3.9). Worth Ivan's ears on 13
   Sep, the noisier room (the room sits about 33 dB under the speech there, about 46 dB on 6 Sep, in the prototype runs).
5. **Host goes in the artist frame, the show in the album frame**, as the task asks (SCOPE PKG-01 put
   the show's name in the artist). Hosts read the show from their own form either way.
6. **Show notes and title count as PASS only once Ivan has chosen them** (Use This Title, Use as Notes,
   or his own words). Reason: PASS means ready to upload, and a model's draft is not.
7. **Speakers are always MISSING.** Reason: Prakriti cannot tell voices apart; a person must listen. It
   names the 13 Sep example below.
8. **The captions keep Parakeet's sentence cues** (one per sentence); SCOPE PKG-02 proposes cues of at
   most two lines of 42 characters and voice spans for Apple. Not built: the voice spans need speaker
   checks, which do not exist.
9. **MP3, as the task asks**, although Apple's page now says it prefers AAC for RSS feeds. The checklist
   says so; every host takes MP3.

### What does not work yet, or was not seen working

- **No person has listened to a podcast-ready file.** The numbers say the riding is gone; Ivan's ears
  have not. (Corrected Sun 11 Oct: the independent check found the numbers do not say this. See
  "Podcast-ready episode: the handoff".)
- **The writing now takes longer** on the 13 Sep talk: 1,046 and 1,409 s for the request, against 585
  to 847 s in milestone 6; 8,092 and 11,330 thinking tokens against 4,580 to 7,117. The captions are the
  likely cause; two runs cannot say how much is them and how much is variance. Tags and summary on LM
  Studio (the Models screen's default) add 4 to 5 minutes; on Apple on-device they take seconds.
- Speakers are not checked; names said in a talk reach the captions (the 13 Sep captions name a person
  in their first 8 seconds). The Speakers line says to listen for names.
- Captions are one cue per sentence (no 42-character lines, no voice spans).
- Nothing is uploaded, and no feed exists: episode and season numbers, explicit and the show details go
  into the host's form by hand, from the text file.

### For Ivan

1. **Listen to episode 1's podcast-ready file against engine v0's**, at a quiet passage and at the
   start of a sentence after a pause: `~/Prakriti/Dev/Outputs/2026-09-06 18-06-33/Podcast-ready/2026-09-06.mp3`
   (made by the acceptance, development folder) and `~/Prakriti/Outputs/2026-09-06 18-06-33/episode.mp3`
   (v0's, the one you said rides). The numbers say the riding is gone; your ears decide. (Corrected Sun
   11 Oct: they do not; see "Podcast-ready episode: the handoff".) Listen for
   the room between sentences too: it is steadier but about 3 dB louder (decision 4).
2. **Set the show on the Outputs screen**, Podcast-ready episode: the show's name (Gabriel's to choose,
   SCOPE Q-G26), the host or author, and the artwork (square JPEG or PNG, 1400 to 3000 px, RGB, under
   512 KB; the line under it says at once whether it passes). Until then the checklist says MISSING,
   on purpose: Prakriti never makes them up.
3. **To make episode 1's podcast-ready file in the live app:** open Recordings, Sun 6 Sep; under
   Outputs for this recording turn on Podcast-ready episode (and Titles, show notes and chapters for
   the notes and captions); mark it "Talk, one teacher speaking"; Make Again. With writing on it takes
   about 30 minutes for episode 1 (24 for the writing). Then Use This Title, Use as Notes, set the episode number, and Update
   Podcast-Ready Files (about half a minute). Episode 1's own `episode.mp3` is replaced by Make Again
   with today's chain for the quick episode (silence trimmed): if you want v0's file kept exactly,
   copy it aside first.
4. **Read the drafts before using them.** Episode 1's titles, show notes and captions are the model's;
   the quotes are checked, the claims are not. The 13 Sep captions name Serenity as leading the
   coaching track; her consent rules for anything public that names her still apply.
5. Optional: 128 kbps instead of 96 (Outputs screen) if you hear the difference; the file grows by a
   third.

### For the videos ("post ready", the question you asked)

Short answer: five of the podcast-ready pieces carry straight over to the videos, three are new for
video, and two do not apply. The videos themselves (SCOPE PKG-07 edited video, PKG-08 shorts) are Phase
3, after Fri 6 Nov by the cut line, so this is the recommendation for that build, not built here.

Carry over, the same code paths:
1. **The sound chain** (high-pass, gentle compressor, one even raise, peaks limited, measured to the
   hundredth). One change: YouTube and the short-video apps play loud uploads quieter but do not turn
   quiet ones up, and the commonly measured reference is about -14 LUFS, so a -16 master plays about 2
   dB under its neighbours there. Recommendation: the video's sound at -14 LUFS, true peak -1, from the
   same chain; the podcast stays at -16. (SCOPE PKG-07 says "the same -16 master"; this is the one place
   to revisit it.)
2. **Captions timed to the finished cut**: the .srt for YouTube (PKG-09, uploaded rather than YouTube's
   automatic ones), and the same word timings for the calm burned-in captions on shorts (PIP-24), since
   most short video is watched with the sound off.
3. **Chapters, checked the same way**: YouTube takes chapters as timestamps in the description and
   asks for the first at 0:00 and at least three, the rule the ID3 chapters already pass.
4. **The text file, per platform**: the YouTube title (100 characters at most), description with the
   chapters, tags; and for each short its own caption and hashtags, drafted in the same writing request.
5. **The upload checklist, per platform**, with the same privacy lines (not a class, speakers not
   checked, no names said) plus the video ones below.

New for video:
6. **A thumbnail check** like the artwork check: 1280 by 720, 16:9, JPEG or PNG, under 2 MB (PKG-06).
7. **What is on screen**: the privacy gate is bigger for picture than for sound. A cut removes a
   student's voice, not their face in the frame; the screen check (PRV-14) has to exist before any
   video is post-ready.
8. **The video file itself**: 1920 by 1080 H.264 with AAC at 48 kHz for YouTube; 1080 by 1920 and under
   3 minutes for shorts; plays to its end, picture and sound the same length, the length the cut list
   says.

Does not apply: the ID3 tag and embedded artwork (video platforms read their own forms), and the
explicit flag (YouTube asks "made for kids" and age limits instead).

The uncomfortable one: shorts are planned from OBS's vertical recording (PIP-23, SET-05), and the
vertical output has been off since 6 Sep. Episode 1 has its vertical twin
(`2026-09-06 18-06-33-vertical.mp4`); 13 Sep and later do not. Turning it back on at the studio visit
is what makes "post-ready" shorts possible without cropping a wide frame.

---

## Episode text and Ready to upload. Sun 11 Oct 2026

The second half of Ivan's podcast-ready request: the text file with the episode's name, show notes and
social captions for that specific episode, and a page he can upload from. Built on the podcast-ready
episode above (Sat 10 Oct); the audio chain is unchanged.

### What was built

- **`Episode text.txt` and `Episode text.md`** in `<Outputs>/<recording>/Podcast-ready/`, replacing
  `Title, show notes and captions.txt`. In order: the **episode title** (Ivan's, else the writer's first
  pick, said to be a pick) and **three alternatives**; a **one-line summary** under 160 characters
  (also the MP3's comment); the **show notes**, 2 to 4 short paragraphs, then **Chapters** at their
  times in the finished MP3 (the ones written into its tag, the first at 0:00), then Ivan's **call to
  action** if he set one, otherwise none; **keywords**; **social captions** for Instagram (up to five
  hashtags), LinkedIn and X and Threads (under 280 characters, with its count), each with a
  **one-sentence pull quote** and its time in the file; the details for the host's form; and what the
  checks changed or left out. The `.md` is the same words as Markdown (hashtags escaped so they are not
  headings, pull quotes as quotes).
- **The writer** (`Writer.swift`) asks for all of it in the same single request as the titles, notes,
  chapters and checklist: 4 titles (the pick first), `one_line`, `show_notes` as a list of paragraphs,
  `keywords`, and `social` with a caption, `pull_quote` and `pull_quote_at` per platform. New checks in
  `WritingCheck`, every one a drop or a stated fix, never an invention:
  - a pull quote is kept only when it is found **word for word inside one line** of the transcript (one
    sentence as Parakeet wrote it), is 4 to 40 words, keeps the copy rules and repeats no other
    platform's; its time is that line's;
  - a caption is cleaned as before (dashes, exclamation marks, inline hashtags and links out), left out
    if it quotes words the transcript does not have or breaks the copy rules, and kept **under** its
    platform's limit (X 280, LinkedIn 3,000, Instagram 2,200) by cutting back to whole sentences, or
    left out;
  - **a hashtag is kept only when its letters are a run of whole words the teacher says**
    (`WritingCheck.hashtag(_:in:)`), capitalized as those words ("Ashtanga yoga" gives #AshtangaYoga);
  - the one-line summary over 159 characters keeps its first sentence if that fits, else none.
- **Ivan's copy rules in Swift** (`Writing/CopyRules.swift`): no prices or sums of money, no money or
  earnings words, no enrollment or sign-ups, no offers ("a free week", "% off"), read sentence by
  sentence with NaturalLanguage. Applied to titles, the one-line summary, show notes, keywords, captions,
  pull quotes, hashtags, chapter titles, tags and the summary, both when the model answers and again when
  the files are written (so a package written before 11 Oct is screened too). Ivan's own title, notes
  and call to action are never screened. The accuracy checklist is exempt on purpose: the speaker's own
  income claims belong there, for a person to check.
- **`PodcastPackage.copy`** works out the words once (`EpisodeCopy`); the two text files and the page's
  Copy buttons all read it.
- **Outputs screen, Podcast-ready episode:** the switch, then the show's settings in the brief's order:
  show name, show artwork (checked against Apple's rules as soon as it is chosen), host or author,
  **numbering** (not numbered, episode numbers, or seasons and episode numbers) and **call to action**
  (multi-line, "None" until typed; a dash in it becomes a comma in the files); then explicit and the
  sound settings. Numbered, an episode without its number is MISSING on the checklist.
- **The show's settings belong to the show** (`OutputResolver.podcastReady`): name, host, artwork,
  numbering and call to action always come from the Outputs screen; explicit, layout, bitrate, noise
  reduction and the AI voice line can be a recording's own. A recording's own podcast-ready settings no
  longer show the show's rows, only a line saying where they are.
- **The recording page's "Ready to upload" section** (was "Podcast-ready episode"): "Ready to upload" or
  "Not ready to upload yet" with the FAIL, MISSING and PASS counts, Show in Finder; every file with what
  it is for and its size; a **Copy** button (saying "Copied" for two seconds) for the title, the one-line
  summary, the show notes (with the chapters and call to action, exactly as the file has them), each
  caption (Instagram's with its hashtags) and each pull quote; the **whole checklist**, what is left
  first, each line with **PASS, MISSING or FAIL as a word**, its detail and what to do; the episode and
  season numbers, with the highest number used so far; Update Podcast-Ready Files.
- **A class is never made ready.** `Pipeline` skips both podcast-ready steps for a recording marked a
  class, with the reason on each step and on the page; `canUpdatePodcastReady` and `repackage` refuse
  it; the Ready to upload section shows "Not made ready to upload" and why, for every class, and says so
  when files from before it was marked a class are still in its folder (Make Again removes them).
- **Checklist:** "Episode and season numbers" follows the numbering; "Show notes" says whether a call
  to action closes them; "Social captions" passes only with all three platforms and their pull quotes;
  a new "Copy rules" line says what was screened.
- **Data:** `OutputSetting.numberingRaw` and `callToAction` (additions with defaults);
  `WrittenPackage.oneLine`, `keywords`, `social`, `leftOutPullQuotes` (optional, so older packages read);
  `PodcastReadyRecord.files` (optional).
- **Also:** the Started notice's writing estimate is now 1,500 s plus 0.1 s per second of recording
  (was 300 plus 0.3: it said about 10 minutes for the 13 Sep talk, which now takes about 30).
- **Tests and checks:** `EpisodeTextTests` (10, in `make test`), `EpisodeTextAcceptanceTests`
  (`make accept-episode-text`), and `make migrate-check` now asserts the new settings arrive unset.

### Checks run, with results

| Check | Result |
|---|---|
| Build | `BUILD SUCCEEDED`, 0 compiler warnings (warnings fail the build) |
| Full test suite (final code, run while the second acceptance used LM Studio) | **136 tests, 0 failures, 8 skipped by design** (the seven acceptance methods and the migration check), 400 s. New: **EpisodeTextTests 10** |
| **Acceptance on the 13 Sep talk with Qwen3.8-27B in LM Studio** (`make accept-episode-text MILESTONE=episode-text`), run twice: on the code before the last fixes (01:48 to 02:21) and on the final code (02:27 to 03:02) | Second run **passed**. Made with everything on in 33 min 32 s; writing set to the Claude API on purpose: **privacy lock held, Claude API client asked 0 times**, written by Qwen3.8-27B in LM Studio. The request: **1,632 s, one try**, 5,800 tokens read, 13,983 written of which 13,036 thinking (first run: 1,457 s, 11,218 thinking). The whole writing step with tags and summary on LM Studio: 1,923 s (first run 1,798 s) |
| `Episode text.txt` sections | **12 of 12** found (title, Alternatives, one-line summary, show notes, Chapters, keywords, social captions, Instagram, LinkedIn, X and Threads, pull quotes, the host's form); `.md` has the same as headings. Title "Yoga Marga's New Direction and Yin Yoga" (the writer's pick) **plus 3 alternatives**; one-line summary **141 characters**; show notes **3 paragraphs, 147 words**; **9 keywords**; call to action none set |
| **Every pull quote word for word** (checked in the test against `transcript.txt` and the `.srt`, and again from the shell with `grep -F` on `transcript.txt`) | Instagram "Yoga is a practice that is more than just asana, pranayama, breathing, stretching." at 8:47: offset 8,816, inside cue 66; LinkedIn "And if at any point it is becoming a disservice to ourselves, then it impacts our ability to show up for others." at 2:37: offset 2,638, cue 20; X and Threads "Yoga Marga, we're not going anywhere, we're still here." at 12:09: offset 12,243, cue 88. `grep -cF`: **1, 1, 1**. Both runs chose the same three |
| **Chapter times in the finished audio** (ffprobe on `2026-09-13.mp3`, 946.550 s) | 0:00 "The Lineage of Yoga" = 0.000 s; 2:52 "A New Direction" = 172.218 s; 12:24 "Weekly Yin Yoga" = 744.258 s: **the same three, in the same order, all inside the file** |
| **No em dashes** (`grep` for em and en dashes) | **0** in `Episode text.txt`, `Episode text.md` and `Upload checklist.txt` |
| **No prices, earnings or enrollment in the captions** (`grep` of the captions section) | **0 "$", 0 "enroll"**, 0 of price, pricing, income, earn, money, dollar, bucks, tuition, free week, sign up; the whole file: 0 "$", 0 "enroll"; `CopyRules` on every sentence of the file: nothing |
| **X and Threads under 280** | **153 characters** (first run 162). Instagram 168 characters with **4 hashtags** (#YogaMarga #AshtangaYoga #YinYoga #Krishnamacharya), all whole words of `transcript.txt`; LinkedIn 331 |
| Call to action, through Update Podcast-Ready Files | A test line set on the Outputs screen: the files went out of date, were updated, and **the show notes ended with it**; cleared and updated again: gone, the rest of the file unchanged |
| The class refusal on the real recording | Marked a class after the run: Update Podcast-Ready Files refused (`canUpdatePodcastReady` false); the page shows "Not made ready to upload" with the reason and the note about files from before |
| Checklist | 0 FAIL, **6 MISSING** (show name, episode title, host, artwork, show notes, speakers: all Ivan's), 18 PASS, including Social captions and Copy rules |
| LM Studio after each run | **nothing loaded** |
| `make migrate-check` | the live store copy opens: 11 recordings, 2 folders, 30 output settings, 172 Activity lines; **numbering "none" and no call to action on all 30**; podcast-ready on in 0 folders |
| **Installed live** (`make install`, 03:02:54) | quit cleanly, replaced, signed (`codesign --verify --deep --strict` passes), reopened: pid 2200, "Mode: live. Store: ...Prakriti.store", "Checked 2 folders. Nothing new." at 03:02:54 and again at 03:07:54 (the 5-minute look, still pid 2200), both also in the live store's Activity lines (read only with sqlite3). `~/Prakriti/Outputs` still holds only engine v0's two folders; `Approved` and `Drop` empty |
| Pictures, looked at | `screens/mac/episode-text/`: the real 13 Sep page from the acceptance, light and dark (`episode-text-13sep-ready-*`: the Ready to upload section with the real files, Copy rows, pull quotes and checklist) and marked as a class (`episode-text-13sep-class-*`); from `make test`: the fixture page (`08-recording-ready-*`, now the real Qwen text), the class refusal (`08-recording-class-not-ready-*`, with the recording's own settings showing only where the show's are), and the Outputs screen with the new settings (`04-outputs-numbered-*`, light and dark) |

### What the runs and the look-through caught and fixed

- **A show name or call to action typed on the Outputs screen never reached a recording that had its
  own choices.** The first acceptance run set its test call to action on the Outputs screen after the
  recording had been given its own outputs, and the show notes did not change. A recording's own
  setting held a frozen copy of the show's name, host, artwork and call to action, and it won. This is
  the exact flow the entry above gives Ivan for episode 1 (turn the output on for the recording, then
  set the show). Fixed with `OutputResolver.podcastReady`; tested; the second run passed.
- **The model's hashtags included "#Yogalinage"** (misspelled) and "#Ashtangayoga" (run together). Now
  a hashtag must be whole words of the transcript, capitalized as those words.
- **The page's file sizes and the checklist disagreed** (10.8 MB against 11.4 MB, binary against decimal
  megabytes). Both decimal now.
- The P1 fixture's captions said "available to enrolled students" and its notes "pause enrollment" and
  "a free week": the screen took them out on the page, which is how the rule was first seen working;
  the fixture now holds the real Qwen output of 11 Oct.
- The banned-words rule for app strings tripped on the teacher's own "we're" in a fixture quote; the
  quote keeps his words, escaped.

### Decisions, each with its reason

1. **One request, not a second one for the episode text.** Reason: a second request holds the 33 GB
   model for another 10 to 20 minutes; the same request grew from 17 to 23 minutes (10 Oct, with three
   plain captions) to 24 and 27 minutes (11 Oct).
2. **Ask for 4 titles and call the first the pick; the title stays MISSING until Ivan chooses.**
   Reason: the brief asks for the chosen title plus three alternatives, and P1's rule is that a draft is
   not ready to upload.
3. **Drop, never fix, except to cut a caption back to whole sentences or the one-line summary to its
   first sentence.** Reason: as for quotes and chapters, a fixed claim is an invented one.
4. **The copy rules are narrow word lists, not a model.** Reason: they must be predictable and
   testable; "sales" as a subject, "pay attention" and "the practice offers" are ordinary here. A false
   alarm costs one caption; a miss costs trust.
5. **The call to action is the only place money or enrollment may appear, and the model never sees
   it.** Reason: "never mention prices or enrollment unless the call to action setting says so" is met
   by the setting itself saying so, in Ivan's words; letting the model echo it would let it embellish.
6. **Only a class is refused.** A conversation or a recording not marked keeps its FAIL or MISSING line.
   Reason: the brief names classes; the others already cannot pass the checklist or be approved.
7. **Explicit stays the episode's own;** name, host, artwork, numbering and call to action are the
   show's. Reason: Apple asks explicit per episode; the rest describe the show.
8. **Pull quotes are timed in the file**, not the original. Reason: a quote card or clip is cut from the
   finished episode.

### What does not work yet, or was not seen working

- **No person has pressed a Copy button.** The pasteboard is tested on a private pasteboard (never
  Ivan's clipboard); the real window was not driven by hand.
- **The claims in the drafts are not checked, only the quotes.** The second run's notes say yin yoga is
  "a deep body reset for practitioners who have been spending long hours in conversation and
  stillness", which reads as the model's colour. Read every draft before using it.
- **The drafts name Serenity** (leading the coaching track), as P1 found; her consent for anything
  public still rules.
- The last chapter in the tag ends 48 ms after the file does (946.598 against 946.550 s, the encoder's
  length against the planned one, P1's code). Apple and ffprobe read it; noted, not changed.
- Writing now takes about 30 minutes on the 15:48 talk. The 6 Sep talk was not run with the episode
  text (P1's run of it took 24 minutes before this change).

### For Ivan

1. **Set the show once, on the Outputs screen, Podcast-ready episode:** the show's name (Gabriel's to
   choose), host or author, artwork, numbering, and, if you want one, a call to action in your words.
   They now reach every episode, including ones you turned on by hand.
2. **On a recording's page, under Ready to upload:** read the drafts, press Use This Title and Use as
   Notes (above) for the ones you keep, then Update Podcast-Ready Files, then Copy each piece into the
   host's form and the three apps. Nothing is posted by Prakriti.
3. **Read every caption and pull quote before posting.** The quotes are proved to be the teacher's
   words; whether a sentence should be shared is your call, and nothing here checks who is named.

### For the videos ("post ready")

What this session adds to the earlier answer (the end of "Podcast-ready episode", above): the episode
text carries over to video as one text per platform from the same single request (a YouTube title of at
most 100 characters and a description with the same chapters; a caption and hashtags for each short),
with the same copy rules, the same hashtag rule, and pull quotes that double as each short's opening
line, since each comes with its time in the finished cut. The Ready to upload section becomes one per
video, with the same Copy buttons and a checklist per platform. The class refusal becomes the stronger
rule video needs: refused until the screen check (PRV-14) can say no student is in the picture.

---

## Podcast-ready episode: the handoff. Sun 11 Oct 2026

Both halves of Ivan's request ("Podcast-ready episode", Sat 10 Oct, and "Episode text and Ready to
upload", Sun 11 Oct, above) were checked again by independent verifiers, each from a fresh clone of
the pushed commit, and parts of it once more by this session. **Both passed, with one exception: the
claim that the new chain fixes episode 1's volume riding is not supported by the measurements**, so
it is corrected below and in CHANGELOG and START_HERE. No code changed in this handoff. The code is
`c91058b`, pushed; the live app is that code (installed 03:02:53, pid 2200, `codesign --verify --deep
--strict` passes; the only file in `mac/` changed after the install is a test).

### What works, with the measured evidence

| What | Measured |
|---|---|
| Build and tests, fresh clone of `c91058b` | `BUILD SUCCEEDED`, 0 compiler warnings. `make test`: **136 tests, 0 failures, 8 skipped by design** (the seven acceptance methods and the migration check), 391 s. On `eba220e` before it: 125, 0 failures, 7 skipped; PodcastReadyTests 10 of 10 |
| **Episode 1 (6 Sep), old against new, measured again by this session with ebur128** | engine v0's `episode.mp3` (live Outputs, read only): **-16.7 LUFS, loudness range 5.2 LU**, peak -1.2 dBFS. The podcast-ready MP3 (development): **-16.0 LUFS, loudness range 4.7 LU**, peak -1.2. loudnorm's meter on the new file (verifier): -16.02 LUFS, true peak -1.20 dBTP, its second pass **linear** (v0's chain: **dynamic**) |
| 13 Sep, old against new (verifier) | v0 -16.8 LUFS, range 4.2 LU. New **-16.03 LUFS, true peak -1.78 dBTP, range 3.7 LU**, linear |
| The file | 44.1 kHz, mono, 96 kbps MP3. Episode 1: 55:36, 40.0 MB. The last 5 s decode on both talks |
| The tag, read by the verifier's own parser and by ffprobe | ID3v2.4: title, year 2026, genre Podcast, a real comment frame, a table of contents and its chapters (6 on episode 1, 3 on 13 Sep), the first at 0:00, every later one starting exactly on a caption. **No show name and no host written: nothing invented.** A 3-chapter test file (one non-ASCII title) read back the same by three readers, its audio decoding to the same samples before and after tagging |
| Artwork check | The verifier's 14 generated images, deleted after: a 1400 px RGB JPEG, a 3000 px PNG and a PNG named .jpg pass; 1399 px, 3001 px, not square, alpha, grey, CMYK, 10 MB, 11.5 MB, HEIC, a text file named .jpg and a missing file each fail with their own reason |
| Captions follow the edit | A 10 s trim moved episode 1's caption 101 by 7.143 s (10 s less the 2.857 s of silence trimmed); the verifier found those words in the trimmed audio 10 ms from the caption by cross-correlation. 13 Sep: 8.818 s, also 10 ms. A scratch test with an intro, an outro and a 4 s cut: later captions moved exactly 4.000 s, earlier ones stayed, the audio 37 ms from its caption, -16.06 LUFS, linear (not committed) |
| The episode text, 13 Sep, Qwen3.8-27B (P2 verifier's own run) | Passed in 3,674 s: four titles (the pick and 3 alternatives), the one-line summary, show notes with the chapters, keywords, a caption each for Instagram, LinkedIn and X and Threads, 3 pull quotes found word for word. **Privacy lock held:** the talk mentions Serenity, so LM Studio wrote it although the writing was set to the Claude API. The model was loaded at 65,536 tokens and unloaded after |
| Checklist | Both talks: **0 FAIL, 6 MISSING** (show name, episode title, host, artwork, show notes, speakers), 17 PASS on 6 Sep (made 10 Oct, before the episode text) and 18 on 13 Sep. Every line carries its measured value and what to do |
| No em or en dashes | 0 in `mac/`, the docs, and every generated checklist, text file and caption file |
| Nothing leaked or sent | The live `~/Prakriti/Outputs`, `Approved` and `Drop`: every file's SHA-256 the same before and after the verifier's runs. No network or upload code added. No class processed. `web/` and engine v0 untouched |

### Corrected: the numbers do not say the riding is gone

The 10 Oct entry, its CHANGELOG entry, START_HERE and the commit `eba220e` said the new chain fixes
or ends episode 1's volume riding. The P1 verifier measured it with their own script, and the numbers
(the builder's own included) do not show that:

| | 6 Sep, v0 | 6 Sep, new | 13 Sep, v0 | 13 Sep, new |
|---|---|---|---|---|
| Seconds where the gain moved more than 2 dB within one second | 104 | 92 | 58 | **66** |
| Spread of the gain over speech | 4.0 dB | 3.8 dB | 4.3 dB | **4.8 dB** |
| Gain movement not explained by how loudly he speaks (standard deviation) | 1.02 dB | 0.85 dB | 0.88 dB | 0.83 dB |
| Pauses lifted more than the voice | 2.2 dB | **5.0 dB** | 2.5 dB | **5.0 dB** |
| Loudness range | 5.2 LU | 4.7 LU | 4.2 LU | 3.7 LU |

What is true: the new file is raised by one amount for the whole episode (loudnorm stays linear, where
v0's gave up and rode the level), and its loudness range is 0.5 LU lower on both talks, which is what
the spec asked for. What is not shown: that the second-to-second rise and fall Ivan heard is gone. On
episode 1 it moves a little less; on 13 Sep a little more; the compressor now does some of the moving
that loudnorm did. And the room sound between sentences sits about 2.5 to 3 dB louder against his
voice than in v0's files (decision 4 of 10 Oct: no expander). Only listening decides. The lines above
that said otherwise now point here; the commit title cannot be changed.

### MISSING by design, and how Ivan sets each

| Checklist line | Why Prakriti leaves it | Where Ivan sets it |
|---|---|---|
| Show name | Gabriel's to choose (Q-G26, due the day before the studio visit). Prakriti never makes one up | Outputs screen, Podcast-ready episode, **Show name**. Then **Update Podcast-Ready Files** on the recording's page: the file becomes `<Show> - <Title>.mp3` and the tag carries the name |
| Artwork | Prakriti never makes artwork | Outputs screen, **Show artwork**, Choose: square JPEG or PNG, 1400 to 3000 px, RGB, under 512 KB. The line under it says at once whether it passes |
| Host or author | Not known | Outputs screen, **Host or author** |
| Episode title | The writer drafts four; a draft is not ready | The recording's page: **Use This Title**, or type one |
| Show notes | The same | The recording's page: **Use as Notes**, or write them. An optional call to action, in Ivan's words, is on the Outputs screen |
| Speakers | Prakriti cannot tell voices apart | Only by listening. **This line is always MISSING** (`PodcastReady.swift`, the checklist), so the page and the checklist can never say "Ready to upload": with everything else set, the best they show is "Not ready to upload yet: 0 FAIL, 1 MISSING". That one is Ivan's to clear by ear |

With Numbering set to episode numbers on the Outputs screen, each episode's number (typed on its page)
becomes one more line until it is set.

### Episode 1's podcast-ready file: where it is, and how Ivan makes it

- **Live: not made.** `~/Prakriti/Outputs/2026-09-06 18-06-33/` holds only engine v0's files (listed at
  about 04:20, Sun 11 Oct). That is by design: the tests write only to development, and the output is off for
  every folder.
- **To listen to now (development):** `~/Prakriti/Dev/Outputs/2026-09-06 18-06-33/Podcast-ready/2026-09-06.mp3`,
  made 00:55 Sun 11 Oct by the P1 verifier's acceptance run. Its text file is still the 10 Oct
  `Title, show notes and captions.txt`, from before the episode text existed.
- **To make it in the live app:** Recordings, Sun 6 Sep; under About this recording mark it "Talk, one
  teacher speaking"; under Outputs for this recording switch on Podcast-ready episode (and Titles, show
  notes and chapters for the text, with LM Studio open and its server on); **Make Again**. The folder
  appears at `~/Prakriti/Outputs/2026-09-06 18-06-33/Podcast-ready/`. Make Again also replaces v0's
  `episode.mp3` with today's quick chain, so copy v0's file aside first:

  ```bash
  cd ~/Prakriti && cp "Outputs/2026-09-06 18-06-33/episode.mp3" "retired/2026-09-06 episode, engine v0.mp3"
  ```

- **How long:** the podcast-ready audio takes 2 to 3 minutes (124 to 159 s on 10 Oct). The writing has **not** been run on episode 1 since the
  episode text was added. On 13 Sep (a third of its length) the P2 verifier's run took 58 min 17 s,
  because the first try answered with nothing after 29 minutes (14,823 thinking tokens, no text) and
  the second passed. Plan on an hour or more and keep the Mac awake.

### Not the upload file yet: what episode 1 still needs

The checklist checks the file, not what is said in it. PLAN.md (the week of Mon 19 Oct) still needs,
before episode 1 is uploaded:

1. Gabriel's answer on the two income claims and the spoken offer, by Fri 16 Oct (Q-G8). With no
   answer all are cut, which removes the opening line.
2. One story about a student cut under the student rule, unless Serenity answers otherwise first.
3. Serenity hears the passages that name her, at her first meeting (episode 1 is approved in two
   versions).
4. Gabriel's recorded intro opens the episode (Q-G9, at the studio visit); it goes on the Outputs
   screen as the intro.
5. The show name and artwork above.

So the file to upload is made **after** those cuts are on the recording's page and the intro is set:
one Make Again with all of it, then Update Podcast-Ready Files for words only. A podcast-ready file
made before then is for listening, not for upload.

### For Ivan: what needs you

- [ ] **Listen, old against new**, before Fri 23 Oct: `~/Prakriti/Outputs/2026-09-06 18-06-33/episode.mp3`
  (v0's) and the development file above. At a quiet passage, at the start of a sentence after a
  pause, and in the pauses themselves (the room sound). Say which is better, or whether either pumps.
  If the room between sentences bothers you, the measured next step is a gentle expander on the
  pauses (decision 4 of 10 Oct), tried on 13 Sep first.
- [ ] **Get the show name and artwork from Gabriel** (Q-G26) and type them once on the Outputs screen,
  with the host's name.
- [ ] **Copy v0's episode aside** (the command above) before the first Make Again on episode 1.
- [ ] **Read every draft before using it.** The quotes are proved to be the teacher's words; the claims
  are not checked. The 13 Sep drafts name Serenity.
- Nothing else is needed for the app to keep running.

### The best pictures

All under `~/Code/prakriti/screens/mac/` (on this Mac only). The first three were looked at in this
session; the others by the builder or a verifier.

| What | Picture |
|---|---|
| Outputs screen, Podcast-ready episode: show artwork, host, numbering, call to action, sound settings (show name at the top edge) | `episode-text/04-outputs-numbered-light-p2.png` |
| Ready to upload on the real 13 Sep page: the status, the files with sizes, the measured sound | `episode-text/episode-text-13sep-ready-light-p6.png` |
| Ready to upload, the Copy rows: title, one-line summary, show notes with chapters, Instagram caption, a pull quote | `episode-text/episode-text-13sep-ready-light-p7.png` |
| The same, dark | `episode-text/episode-text-13sep-ready-dark-p6.png`, `-p7.png` |
| A class: "Not made ready to upload", and why | `episode-text/episode-text-13sep-class-dark-p7.png` (looked at in this session) |
| Episode 1's page from the 10 Oct acceptance | `podcast/podcast-2026-09-06-dark.png` and its pages |
| Outputs in the real window | `podcast/real/04-outputs-dark.png` |
| The acceptance reports | `podcast/acceptance-podcast-2026-09-06.txt`, `podcast/acceptance-podcast-2026-09-13.txt`, `episode-text/acceptance-episode-text.txt` |

### Notes for the next build

1. **The writing's thinking is creeping toward its cap.** `max_tokens` is 16,384 (LOCAL-MODEL.md);
   milestone 6 spent 4,580 to 7,117 thinking tokens, the episode text 11,218 to 13,036, and the P2
   verifier's empty first try 14,823. Episode 1 is three times longer and has not been written with
   the episode text. Measure it once in development before Ivan relies on it; if a try runs out, raise
   the budget or split the request.
2. **Speakers can never pass.** Give Ivan a way to record "I listened: one teacher, no names said"
   on the page (with the date), or the page never says Ready to upload.
3. **A "content cleared" line** tied to each episode's conditions in PLAN.md (income claims, the student
   story, Serenity's passages), so "ready" means cleared as well as well-made.
4. The verifier's intro, outro and cut test passed in a scratch clone and is not committed; commit an
   equivalent.
5. If Ivan hears riding or the room in the pauses: an expander for the pauses, measured against v0 on
   13 Sep first.
