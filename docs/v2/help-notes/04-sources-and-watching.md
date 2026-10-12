# Builder notes: 04-sources-and-watching.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/04-sources-and-watching.md` ("Sources and watching").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3a (Sun 11 Oct 2026)

- Sources are rows of the sidebar; a folder's settings (mode, outputs, Check Now, Open Privacy Settings, Stop
  Watching) are in the inspector when it is selected. Add Folder is the sidebar's last Sources row and File >
  Add Folder. v1's drop area is gone: a file or folder dragged onto the window is added. Activity is Window >
  Activity (its own window; M4a builds it out). The first Show Me is still `sources` (it now selects the first
  folder), which `HelpTests.testShowMeInSourcesAndWatchingOpensSources` checks.
- "Follow the work" (until `progress`) names In Progress and the inspector's Checks. The `:::requires progress`
  block had its names updated (In Progress, waiting for your yes); M4a still rewrites it.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Show Me (Sources) in step 1: the link check 4 of M2a tests (`HelpTests.testShowMeInSourcesAndWatchingOpensSources`).
- Corrected to v1: a new folder starts as Ask me first (`addSource`); outputs appear under a folder only
  with Make outputs automatically; Add File waits for Make Outputs; File > Process File starts at once;
  iCloud: Prakriti asks iCloud for the file (`brctl download`) and waits up to an hour.
- Gated: progress with time left (`progress`; until then: Today's steps, the menu bar mark and menu,
  the five notices), the capture check (`captureCheck`).

## Notes from the help track (Sat 10 Oct 2026)

- Labels taken from v1's code (`SourcesView.swift`, `MenuBar.swift`): "Add File…", "Add Folder…",
  "Drop a recording here", "When a recording arrives", "Make outputs automatically", "Ask me first",
  "Open Privacy Settings…", "Check Now", "Stop Watching…", "Pause All", "Resume All". The help drops
  the trailing ellipsis in running text, as Apple's guides do.
- File types from `FolderScan.mediaExtensions`: mp4, mov, mkv, m4a, wav, mp3, aac, m4v.
- The one-minute wait is v1's readiness rule (60 s steady), not SCOPE §7.3's fuller one. If v2 adds
  the Hybrid MOV/MP4 fragment check, this line still reads true.
- **Assumes for v2:** the capture check on test files; Today shows a progress bar and time left per
  recording; the menu bar shows the current step and progress (Ivan's item 6). v1 Today shows
  "Step N of M" only.
- "Keep Downloaded" is the Finder command for iCloud Drive items on recent macOS
  `[unverified on macOS 27 wording]`.
- Deliberately not named in user help: the Studio Recordings folder's trailing space, the SerenityAI
  archive refusal, development mode.
