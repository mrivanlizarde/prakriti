---
id: sources-and-watching
title: Sources and watching
summary: How Prakriti watches folders, when a recording counts as finished, and how to follow its progress or pause it.
keywords: [sources, folders, watch, drop folder, add folder, add file, automatic, ask me first, iCloud, keep downloaded, test, vertical, pause all, resume all, progress, menu bar, activity, check now]
related: [03-set-up-obs-for-prakriti, 05-outputs, 10-troubleshooting]
---

# Sources and watching

A source is a folder Prakriti watches for new recordings. When a recording arrives, Prakriti checks it
and, if you choose, makes its outputs with nobody touching anything.

## Add a folder to watch

1. Click Sources in the sidebar.
2. Click Add Folder, choose the folder, then click Open. You can also drag the folder onto "Drop a
   recording here".
3. Under "When a recording arrives", choose one:
   - **Make outputs automatically:** Prakriti checks each new recording and makes its outputs.
   - **Ask me first:** Prakriti checks it, then waits for you to choose Make Outputs on its page.
4. Turn on the outputs this folder should make. See [Outputs](05-outputs.md).

If macOS asks whether Prakriti may read the folder, click Allow. If a folder shows a warning, click
Open Privacy Settings and turn Prakriti on.

## Add a single recording

- Put the file in the Drop folder, in the Prakriti folder in your home folder. Prakriti makes it like
  any other recording.
- Or click Sources, then click Add File and choose the file.

## What counts as a recording

- **Video and audio files:** MOV, MP4, M4V, MKV, M4A, WAV, MP3 and AAC.
- **A finished file, not one still being written.** OBS creates the file when recording starts, and
  iCloud downloads a file in pieces. Prakriti waits until the file has stopped growing for a minute
  before it starts.
- **Under 60 seconds is a test.** Prakriti files it as a test, sends no notice, and shows its capture
  check on the recording's page. See [Capture the best video](02-capture-the-best-video.md).
- **A vertical twin is part of the same session.** A file whose name ends in `-vertical` is paired
  with the recording of the same name, not made twice.

## What Prakriti never does to a source

- It never writes into a folder it watches, and never changes or deletes a recording in it. Everything
  it makes goes to the Outputs folder, in the Prakriti folder in your home folder.
- It does not watch its own Outputs or Approved folders.

## How watching works

Prakriti notices a new file as soon as macOS reports it, and also looks through every folder every 5
minutes in case something was missed. It keeps watching when the window is closed. Click Check Now on
the Sources screen to look right away.

Each look is written in Activity as a short line, such as "Checked 2 folders. Nothing new." If no new
line appears for more than 5 minutes, Prakriti may have stopped. See
[If something isn't working](10-troubleshooting.md).

### Folders in iCloud Drive

With Optimize Mac Storage on, macOS can remove a recording's data from your Mac and keep only a
placeholder. Prakriti waits for the download, which can take a while for a large file. To keep a
shared recordings folder on your Mac, Control-click it in the Finder and choose Keep Downloaded.

## Follow the progress

- **Today** shows every recording being worked on, the step it is on, a progress bar and the time
  left.
- **The recording's page** shows each step in order, with how long each one took.
- **The menu bar** shows the current step and how far along it is.
- **Notifications** tell you when a recording is found, when it is ready for your yes, and when
  something needs a decision.

## Pause and resume

Click Pause All in the toolbar, in the menu bar menu, or in Settings. A recording already being made
finishes. Nothing new is looked for or started until you click Resume All.

## Stop watching a folder

On the Sources screen, click Stop Watching under the folder. Nothing in the folder is deleted, and
recordings already found stay in Recordings.

## See also

- [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md)
- [Outputs](05-outputs.md)
- [If something isn't working](10-troubleshooting.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

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
