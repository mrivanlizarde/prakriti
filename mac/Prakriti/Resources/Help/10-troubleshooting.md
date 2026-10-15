---
id: troubleshooting
title: If something isn't working
summary: What to check when a recording is not found, has no sound, sends no notice, or a model does not answer, and where the log is.
section: troubleshooting
order: 1
keywords: [troubleshooting, problem, edit plan, Plan the Edit, soft picture, punch-in, Teaching, video does not play, watch video, not found, silent, no sound, capture check, audio tracks, both channels, Check Capture, notifications, stopped, quit, flicker, bands, sync, LM Studio, API key, Claude API, Anthropic, OpenAI, model list, cut, disk space, encoding overloaded, log, show log]
related: [capture-the-best-video, set-up-obs-for-prakriti, sources-and-watching, models-and-api-keys]
---

# If something isn't working

## Finding and making

### If a new recording doesn't appear

- Make sure Prakriti is open: its mark, a disc cut across the middle, is in the menu bar. While it works
  on a recording, the two halves light in turn. If the mark is not there, open Prakriti from the
  Applications folder.
- Check that Pause All is not on. If it is, click Resume All.
- Look at the folder under Sources in the sidebar. If it shows a warning sign, select it, click Open
  Privacy Settings in the inspector, and turn Prakriti on. [Show Me](prakriti://show/sources)
- A recording still being written is not ready yet. Prakriti starts a minute after the file stops
  growing. A file in iCloud Drive must download first.
- A recording under 60 seconds is filed as a test, and nothing is made from it.
- Select the folder under Sources and click Check Now in the inspector.

### If Prakriti seems to have stopped

Choose Window > Activity. [Show Me](prakriti://show/activity) Prakriti writes a line such as
"Checked 2 folders. Nothing new." every 5 minutes. If there is no new line for longer than that, quit
Prakriti from the menu bar and open it again. If it keeps happening, send the day's log (see "Find the
log" below).

:::requires progress
The lines are under Log in the Activity window, where the search field finds one. Under Now, a step
that has not moved for a minute says what it is waiting on, such as "Waiting for Parakeet to finish the
transcript." If it stays that way, click Stop, then Make Outputs to try again.
:::

### If you don't get notifications

Choose Prakriti > Settings (Command-comma), click General, then Open Notification Settings. System
Settings opens at Prakriti's own page: turn on Allow notifications.
[Show Me](prakriti://show/settings/general) Choose Banners, and turn on sound for its notifications. Also
check that a Focus is not hiding them. Settings, General says whether macOS allows Prakriti's notices.

:::requires welcome
The last panel of the welcome window does the same: choose Help > Welcome to Prakriti, click Continue to
the last panel, then click Turn On Notifications, or Open Notification Settings if they are off.
:::

:::requires editPlan
### If the edit plan is not made

Under Edit plan in the inspector's Outputs, Prakriti says why in one sentence.

- **Plan the Edit is dimmed:** the recording has no transcript yet, or it is being made. Wait for it to
  finish, or turn on Transcript for it and click Make Again.
- **The original is not on this Mac:** the plan reads the original's sound. Download it in the Finder,
  then click Plan the Edit again.
- **The plan did not pass its own check:** Prakriti checks every plan before saving it, and saves none
  that fails. Click Make Again so the transcript is made again, then Plan Again. If it keeps happening,
  send the day's log (see "Find the log" below).
- **It says your newest trim, cuts or choices are not in the plan yet:** click Plan Again.
:::

:::requires direction
### If the plan does not follow your direction

Look under Direction, **Read as**: each thing Prakriti understood is listed there. If something is
missing, write it with the common phrases (for example "under 10 minutes", "faster", "focus on the
motivating parts"), or check that a model is chosen for Planning the edit in Settings, Models. If the
plan says it could not read the parts of the talk, that model did not answer: open LM Studio, or check
the key in Settings, Models, then click Plan Again.

### If the video is longer than the length you asked for

The talk's main point and its close are always kept, with any part they depend on. When those alone run
longer than the length, the plan says so in its lines. Choose a longer length, or take out a part by
name, for example "take out the story about the car".
:::

:::requires renderedVideo
### If the video is not made

Under Edited video in the inspector's Outputs, Prakriti says why in one sentence.

- **Make Video is dimmed:** the recording has no transcript yet, or it is being made. Wait for it to
  finish, or turn on Transcript for it and click Make Again.
- **It says who appears and speaks in it has not been checked:** click Check People in the People tab,
  then Make Video.
- **It says a face Prakriti cannot account for at a time:** after the video was made, Prakriti found a face
  in it that is not someone you included. Play the Original at that time with People on. If it is someone
  you want hidden, choose Hide Face for them; if it is someone you are happy to show, choose Include. Then
  click Make Again. If no box is drawn on that face, click Check People first.
- **It says someone it heard sounds like a person you left out:** listen to the Original at that time,
  check the choice for that voice in the People tab, then click Make Again.
- **It says the edit plan could not be made:** see "If the edit plan is not made" above.
- **The video was not kept:** Prakriti measures every video before it moves it into the recording's
  folder, and deletes one that does not play to its end or is not the length the plan keeps. Click Make
  Again. If it keeps happening, send the day's log (see "Find the log" below).
- **A line of the Ready checklist says FAIL:** the line says what to do. Most need only Make Again.
:::

:::requires video
### If the video does not play in the viewer

Choosing Video says why in one sentence.

- **The edited video is not made for this recording:** select it and click Make Video under Edited video
  in the inspector's Outputs.
- **The edit was planned again after this video was made:** Plan Again changed the plan, so the video
  in the folder no longer matches it. Click Make Again.
- **It says where the video hides faces is not in the recording's folder:** the file that holds the hidden
  places was moved or deleted. Click Make Again.
- **The original is not on this Mac:** the viewer draws the video from the original recording. Download
  it in the Finder, then choose Video again.
- **It says your newest changes are not in the video yet:** you restored or removed a piece, or changed
  the trim, cuts or who is in it. Click Make Again to see them in the video.
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

The capture check, at the top of the inspector's Checks, lists every audio track in the file. One track
means OBS is set to record one track, or every source is on track 1 only. See "Sources and tracks" in
[Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md). A player plays only the first track, so a file
can sound right and still be missing the others.

### If the capture check says one microphone is in both channels

The left and right of that track carry the same sound: one microphone copied to both. It plays fine,
but one voice cannot be told from another in it. Give each speaker a microphone on its own track, as in
"Sources and tracks" in [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md).

### If the capture check says a track is silent

A microphone recorded nothing on that track. In OBS, check the microphone is not muted and moves on its
meter, and that it is set to that track in Advanced Audio Properties. If the silent track is track 1,
the recording has no usable sound and nothing is made from it.

### If an older recording has no capture check

Recordings found before the capture check existed are not checked by themselves. Select one, click
Checks in the inspector, then click Check Capture. It only reads the file.
:::

### If the transcript stops before the end

The notice and the inspector say how much is missing. Listen to the end of the recording. If speech
continues there, click Make Again. If it stops again, the sound at that point may be very quiet or
damaged.

### If the transcript is missing words in the middle

When there is still speech with no words after Prakriti has listened to it a second time, the notice
says so, and Missing words in the inspector's Checks lists where each stretch starts and how long it
is. The same list is in `REPORT.md`. Listen at those times. If you hear speech, click Make Again. If
the words are still missing, the speech there may be very quiet, far from the microphone or under
other sound.

### If a cut took out something you need

Open the recording and click the cut in the strip under the player, then click Restore at the top of the inspector. Or, in the inspector's Info, click Restore beside the cut. Then click Make Again.

## Picture and sound

:::requires houseStyle
### If the video looks soft after a punch-in

A punch-in enlarges the recorded picture. On a 1080p recording Prakriti never goes past 1.15, but the
picture is still a little softer there. Record in 4K. See
[Capture the best video](02-capture-the-best-video.md). Until then, in Settings, House Style, choose
Punch-ins Subtle or Off, then click Plan the Edit or Make Again.

### If a punch-in cuts off a raised arm or a pose

In Settings, House Style, turn on Teaching: the picture then changes only at cuts and never pushes in
slowly, and stays whole wherever no face is seen. Then click Make Again.
:::

:::requires textOnScreen
### If the title or the teacher's name is not on the video

The title shows only when the recording has a title in the inspector's Info, and the name only for a
teacher you named who is included in the video. Check both, and that Title at the start and Teacher's
name are on in Settings, House Style. If they are and the text is still missing, there was no moment
clear of every face: in a frame crowded with people Prakriti leaves the text out rather than cover
someone. Then click Plan the Edit or Make Again.
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

In the inspector's People, click the person and choose Not This Person,
or choose the right name. Then click Make Again. Faces seen from the side, far away or in poor light
are harder to recognize. Prakriti treats anyone it is not sure about as Unnamed, so their face is
blurred.
:::

## Models

### If LM Studio doesn't answer

- Open LM Studio and make sure its local server is running.
- In Settings, Models, check the address matches the one LM Studio shows, then click Test LM Studio.
  [Show Me](prakriti://show/settings/models)
- Make sure the model is downloaded in LM Studio. Prakriti loads it itself.
- Close large apps. The model needs about 33 GB of memory while it works.

Writing takes about 10 to 15 minutes for a 15-minute talk. That is normal. If writing stops, the episode
is still made, and the inspector's Outputs say why the writing stopped.

### If an Anthropic or OpenAI key doesn't work

- Click Test Anthropic or Test OpenAI in Settings, Models and read the message.
  [Show Me](prakriti://show/settings/models)
- If it says the company did not accept the key, make a new key on the company's site, paste it and
  click Save in Keychain.
- Check that the account on the company's site has credit or a payment method.
- If the Model pop-up is empty, click Read the List Again.

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
