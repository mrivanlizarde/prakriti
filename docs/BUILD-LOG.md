# Build log: Prakriti for Mac

One dated entry per milestone of `docs/NEXT-PROMPT.md`, oldest first: what was built, every check
with its measured result, the decisions taken and why, and anything Ivan must do. A new session
resumes from the last entry. Weekdays computed with `date(1)`.

**Where it stands:** milestones 1 and 2 of 6 done (Sat 10 Oct). Next: milestone 3, the watcher and
notifications, then the switch-over from engine v0.

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
