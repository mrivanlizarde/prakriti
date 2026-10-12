---
id: sources-and-watching
title: Sources and watching
summary: How Prakriti watches folders, when a recording counts as finished, and how to follow its work or pause it.
section: recording
order: 3
keywords: [sources, folders, watch, drop folder, add folder, add file, process file, automatic, ask me first, make outputs, iCloud, keep downloaded, test, vertical, pause all, resume all, menu bar, activity, check now, stop watching, progress, percent, time left, pause, stop, make next]
related: [set-up-obs-for-prakriti, outputs, troubleshooting]
---

# Sources and watching

A source is a folder Prakriti watches for new recordings. When a recording arrives, Prakriti checks it
and, if you choose, makes its outputs with nobody touching anything.

## Add a folder to watch

1. In the sidebar, under Sources, click Add Folder, or choose File > Add Folder.
   [Show Me](prakriti://show/sources)
2. Choose the folder, then click Watch This Folder. You can also drag the folder onto the window.
3. A new folder starts as **Ask me first**: what is already in it is listed and left alone. Select the
   folder under Sources: its settings show in the inspector, on the right. Under "When a recording
   arrives", choose one:
   - **Make outputs automatically:** Prakriti checks each new recording and makes its outputs.
   - **Ask me first:** Prakriti checks it, then waits for you to choose Make Outputs.
4. With Make outputs automatically chosen, the folder's outputs appear under it in the inspector. Turn
   on the ones this folder should make. See [Outputs](05-outputs.md).

If macOS asks whether Prakriti may read the folder, click Allow. A folder Prakriti cannot read shows a
warning sign in the sidebar: select it, click Open Privacy Settings in the inspector, and turn Prakriti
on.

## Add a single recording

- Put the file in the Drop folder, in the Prakriti folder in your home folder. Prakriti finds it like
  any new recording.
- Or drag the file onto the window, or choose File > Add File, and choose the file. It waits in In
  Progress, marked Found, until you choose Make Outputs: in the inspector, or Control-click it.
- To start one at once, choose File > Process File.

## What counts as a recording

- **Video and audio files:** MOV, MP4, M4V, MKV, M4A, WAV, MP3 and AAC.
- **A finished file, not one still being written.** OBS creates the file when recording starts, and
  iCloud downloads a file in pieces. Prakriti waits until the file has stopped growing for a minute
  before it starts.
- **Under 60 seconds is a test.** Prakriti files it as a test, makes nothing and sends no notice.
:::requires captureCheck
  The inspector's Checks show the capture check. See [Capture the best video](02-capture-the-best-video.md).
:::
- **A vertical copy is left alone.** In a watched folder, a file whose name ends in `-vertical` is
  never made on its own.

## What Prakriti never does to a source

- It never writes into a folder it watches, and never changes or deletes a recording in it. Everything
  it makes goes to the Outputs folder, in the Prakriti folder in your home folder.
- It does not watch its own Outputs or Approved folders.

## How watching works

Prakriti notices a new file as soon as macOS reports it, and also looks through every folder every 5
minutes in case something was missed. It keeps watching when the window is closed. To look right away,
select a folder under Sources and click Check Now in the inspector.

Each look is written in Activity (Window > Activity) as a short line, such as "Checked 2 folders.
Nothing new." If no new
line appears for more than 5 minutes, Prakriti may have stopped. See
[If something isn't working](10-troubleshooting.md).

### Folders in iCloud Drive

With Optimize Mac Storage on, macOS can remove a recording's data from your Mac and keep only a
placeholder. Prakriti asks iCloud for the file and waits for the download, up to an hour, which can take
a while for a large file. To keep a shared recordings folder on your Mac, Control-click it in the Finder
and choose Keep Downloaded.

## Follow the work

:::unless progress
- **In Progress**, in the sidebar, lists every recording being made, waiting its turn or found. Select
  one: the inspector shows the step it is on.
- **The inspector's Checks** show each step of the last make, with how long each one took.
- **The menu bar** shows Prakriti's mark. While it works, the two halves of the mark light in turn, and
  its menu says which recording it is working on and the step.
- **Notifications** tell you when a recording is found, when it is waiting for your yes, when
  something needs a decision, and when a recording could not finish.
:::
:::requires progress
- **On the recording:** while it is made, its card shows a ring and the percent, and in the list (View >
  as List) a bar with the percent and the time left, such as "64%, about 6 min left". The percent counts
  each step by how long it usually takes on this Mac, so a quick check is worth less than making the
  audio. The time left appears once Prakriti has timed that step, and says "Working out the time left"
  until then.
- **The inspector:** select the recording. Outputs shows the step it is on ("Step 5 of 9"), a bar, the
  percent, the time left and the latest line it wrote, with Pause and Stop. If a step has not moved for a
  minute, it says what it is waiting on.
- **The Activity window:** choose Window > Activity (Command-9), click the Activity button in the
  toolbar, or choose Show Activity in the menu bar menu. [Show Me](prakriti://show/activity)
  - **Now** shows the recording being made, with every step: how long each finished one took, the
    running one's time so far, and the usual time of each still to come. Recordings waiting their turn
    are listed under it, in order. Control-click one and choose Make Next to make it next.
  - **Finished** lists each recording that ended, by day, with what came of it, Show and Show in Finder.
  - **Log** has every check and every step, newest first, with a search field.
- **The menu bar** shows the recording, its step, the percent and the time left, such as "Making Sun 13
  Sep: Writing the transcript, 64%, about 6 min left."
- **Notifications** tell you when a recording is found, when it is waiting for your yes, and when
  something needs a decision.
:::

## Pause and resume

Click Pause All in the toolbar, in the menu bar menu, or in Settings, General. A recording already being made
finishes. Nothing new is looked for or started until you click Resume All.

:::requires progress
To pause one recording, click Pause beside it in the Activity window or in the inspector. The recording
being made holds where it is until you click Resume; one waiting its turn keeps its place in line. Writing
titles and show notes cannot be paused once it has started.

To stop one, click Stop. A recording being made stops at once: nothing new is kept, the files from its
last make stay as they were, and it is not started again on its own. One waiting its turn leaves the
line. Choose Make Outputs to start either again.
:::

## Stop watching a folder

Select the folder under Sources, click Stop Watching in the inspector, then confirm. Nothing in the
folder is deleted, and recordings already found stay in All Recordings.
