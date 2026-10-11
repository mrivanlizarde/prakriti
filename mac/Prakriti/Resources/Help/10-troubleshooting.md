---
id: troubleshooting
title: If something isn't working
summary: What to check when a recording is not found, has no sound, sends no notice, or a model does not answer, and where the log is.
section: troubleshooting
order: 1
keywords: [troubleshooting, problem, not found, silent, no sound, notifications, stopped, quit, flicker, bands, sync, LM Studio, API key, Claude API, cut, disk space, encoding overloaded, log, show log]
related: [capture-the-best-video, set-up-obs-for-prakriti, sources-and-watching, models-and-api-keys]
---

# If something isn't working

## Finding and making

### If a new recording doesn't appear

- Make sure Prakriti is open: its mark, a disc cut across the middle, is in the menu bar. While it works
  on a recording, the two halves light in turn. If the mark is not there, open Prakriti from the
  Applications folder.
- Check that Pause All is not on. If it is, click Resume All.
- Click Sources and look at the folder. If it shows a warning, click Open Privacy Settings and turn
  Prakriti on. [Show Me](prakriti://show/sources)
- A recording still being written is not ready yet. Prakriti starts a minute after the file stops
  growing. A file in iCloud Drive must download first.
- A recording under 60 seconds is filed as a test, and nothing is made from it.
- Click Check Now on the Sources screen.

### If Prakriti seems to have stopped

Click Activity in the sidebar. [Show Me](prakriti://show/activity) Prakriti writes a line such as
"Checked 2 folders. Nothing new." every 5 minutes. If there is no new line for longer than that, quit
Prakriti from the menu bar and open it again. If it keeps happening, send the day's log (see "Find the
log" below).

### If you don't get notifications

Click Settings in the sidebar, then Open Notification Settings. System Settings opens at Prakriti's own
page: turn on Allow notifications. [Show Me](prakriti://show/settings) Choose Banners, and turn on sound
for its notifications. Also check that a Focus is not hiding them. The Settings screen says whether macOS
allows Prakriti's notices.

:::requires welcome
The last panel of the welcome window does the same: choose Help > Welcome to Prakriti, click Continue to
the last panel, then click Turn On Notifications, or Open Notification Settings if they are off.
:::

### If a recording says it is silent or has no sound

Prakriti checks the sound first. If the loudest moment is close to silence, or the file has no sound
track, it marks the recording Needs a decision and makes nothing from it. The original is untouched.

- In OBS, check that each microphone source is not muted and shows movement on its meter.
- Check that the microphone is chosen as the source's device and that OBS is allowed to use the
  microphone: Apple menu > System Settings > Privacy & Security > Microphone.
- Record a 10-second test and play it back before the next session.

:::requires captureCheck
### If only one audio track is found

OBS is set to record one track, or every source is on track 1 only. See "Sources and tracks" in
[Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md). A player plays only the first track, so a file
can sound right and still be missing the others.
:::

### If the transcript stops before the end

The notice and the page say how much is missing. Listen to the end of the recording. If speech
continues there, click Make Again. If it stops again, the sound at that point may be very quiet or
damaged.

### If a cut took out something you need

On the recording's page, under Trim and cuts, click Remove beside the cut, then click Make Again.

## Picture and sound

:::requires style
### If the video looks soft after a zoom

The recording was made in 1080p, so a zoom enlarges the picture. Record in 4K. See
[Capture the best video](02-capture-the-best-video.md). Until then, choose the Calm preset or write
"Fewer zooms" under Direction.
:::

### If the picture flickers or shows moving bands

The camera's shutter speed does not match the lights. Set the shutter to 1/60. If the bands stay, try
1/120, or change the light.

### If the voice and lips don't match

In OBS, choose Edit > Advanced Audio Properties and adjust the microphone's Sync Offset, a few tens of
milliseconds at a time, until they match in a test recording.

### If OBS says "Encoding overloaded!"

The Mac cannot record at these settings. In OBS, make sure Video Encoder is a hardware encoder (Apple
VT). If the message stays, set both resolutions to 1920x1080. See
[Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md).

:::requires people
## People

### If someone is named wrongly, or not recognized

On the recording's page, under People in This Recording, click the person and choose Not This Person,
or choose the right name. Then click Make Again. Faces seen from the side, far away or in poor light
are harder to recognize. Prakriti treats anyone it is not sure about as Unnamed, so their face is
blurred.
:::

## Models

### If LM Studio doesn't answer

- Open LM Studio and make sure its local server is running.
- On the Models screen, check the address matches the one LM Studio shows, then click Test LM Studio.
  [Show Me](prakriti://show/models)
- Make sure the model is downloaded in LM Studio. Prakriti loads it itself.
- Close large apps. The model needs about 33 GB of memory while it works.

Writing takes about 10 to 15 minutes for a 15-minute talk. That is normal. If writing stops, the episode
is still made, and the recording's page says why the writing stopped.

### If the Claude API key doesn't work

- Click Test Claude API on the Models screen and read the message.
- Check that the account on Anthropic's site has credit or a payment method.
- Make a new key on Anthropic's site, then paste it and click Save in Keychain.

:::requires timelines
## Final Cut Pro and DaVinci Resolve

### If the media shows as missing or offline

The timeline uses media in the recording's folder in Outputs. If the folder was moved or renamed, put it
back, or point the app to it:

- **Final Cut Pro:** select the missing clips, choose File > Relink Files, and choose the folder.
- **DaVinci Resolve:** Control-click the timeline in the Media Pool, choose Relink Clips for Selected
  Timeline, and choose the folder.

If the folder is in iCloud Drive, make sure its files are downloaded.

### If DaVinci Resolve says the file is not valid

Update DaVinci Resolve to the latest version, then import again. Use the file Prakriti made for Resolve,
not the one for Final Cut Pro, if both are in the folder.
:::

## Space

### If your Mac runs low on space

Recordings, and 4K recordings most of all, are large. Move older approved recordings to an external
drive, and remove outputs you no longer need from the Outputs folder. Prakriti never deletes originals.

## Find the log

Prakriti writes everything it does to a log, one file per day. Choose Help > Show Log in Finder, or open
the folder in Terminal:

```bash
cd ~/Library/Logs/Prakriti && open .
```
