---
id: sources-and-watching
title: Sources and watching
summary: How Prakriti watches folders, when a recording counts as finished, and how to follow its work or pause it.
section: recording
order: 3
keywords: [sources, folders, watch, drop folder, add folder, add file, process file, automatic, ask me first, make outputs, iCloud, keep downloaded, test, vertical, pause all, resume all, menu bar, activity, check now, stop watching]
related: [set-up-obs-for-prakriti, outputs, troubleshooting]
---

# Sources and watching

A source is a folder Prakriti watches for new recordings. When a recording arrives, Prakriti checks it
and, if you choose, makes its outputs with nobody touching anything.

## Add a folder to watch

1. Click Sources in the sidebar. [Show Me](prakriti://show/sources)
2. Click Add Folder, choose the folder, then click Watch This Folder. You can also drag the folder onto
   "Drop a recording here".
3. A new folder starts as **Ask me first**: what is already in it is listed and left alone. Under
   "When a recording arrives", choose one:
   - **Make outputs automatically:** Prakriti checks each new recording and makes its outputs.
   - **Ask me first:** Prakriti checks it, then waits for you to click Make Outputs on its page.
4. With Make outputs automatically chosen, the folder's outputs appear under it. Turn on the ones this
   folder should make. See [Outputs](05-outputs.md).

If macOS asks whether Prakriti may read the folder, click Allow. If a folder shows a warning, click Open
Privacy Settings and turn Prakriti on.

## Add a single recording

- Put the file in the Drop folder, in the Prakriti folder in your home folder. Prakriti finds it like
  any new recording.
- Or click Add File on the Sources screen, or choose File > Add File, and choose the file. It waits on
  its page until you click Make Outputs.
- To start one at once, choose File > Process File.

## What counts as a recording

- **Video and audio files:** MOV, MP4, M4V, MKV, M4A, WAV, MP3 and AAC.
- **A finished file, not one still being written.** OBS creates the file when recording starts, and
  iCloud downloads a file in pieces. Prakriti waits until the file has stopped growing for a minute
  before it starts.
- **Under 60 seconds is a test.** Prakriti files it as a test, makes nothing and sends no notice.
:::requires captureCheck
  Its page shows the capture check. See [Capture the best video](02-capture-the-best-video.md).
:::
- **A vertical copy is left alone.** In a watched folder, a file whose name ends in `-vertical` is
  never made on its own.

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
placeholder. Prakriti asks iCloud for the file and waits for the download, up to an hour, which can take
a while for a large file. To keep a shared recordings folder on your Mac, Control-click it in the Finder
and choose Keep Downloaded.

## Follow the work

:::unless progress
- **Today** shows every recording being worked on, the step it is on, and how many steps are done.
- **The recording's page** shows each step in order, with how long each one took.
- **The menu bar** shows Prakriti's mark. While it works, the two halves of the mark light in turn, and
  its menu says which recording it is working on and the step.
- **Notifications** tell you when a recording is found, when it is ready for your yes, when something
  needs a decision, and when a recording could not finish.
:::
:::requires progress
- **Today** shows every recording being worked on, the step it is on, a progress bar and the time left.
- **The recording's page** shows each step in order, with how long each one took.
- **The menu bar** shows the current step and how far along it is.
- **Notifications** tell you when a recording is found, when it is ready for your yes, and when
  something needs a decision.
:::

## Pause and resume

Click Pause All in the toolbar, in the menu bar menu, or in Settings. A recording already being made
finishes. Nothing new is looked for or started until you click Resume All.

## Stop watching a folder

On the Sources screen, click Stop Watching under the folder, then confirm. Nothing in the folder is
deleted, and recordings already found stay in Recordings.
