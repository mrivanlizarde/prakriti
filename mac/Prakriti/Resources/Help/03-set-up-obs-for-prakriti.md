---
id: set-up-obs-for-prakriti
title: Set up OBS for Prakriti
summary: The OBS Studio settings that give Prakriti a crash-safe file, a sharp picture, and every microphone on its own track.
section: recording
order: 2
keywords: [OBS, settings, Hybrid MP4, canvas, 4K, 1080p, frame rate, encoder, Apple VT, HEVC, CRF, quality, keyframe interval, audio tracks, multitrack, Zoom, macOS Audio Capture, vertical, file name, ffprobe]
related: [capture-the-best-video, sources-and-watching, troubleshooting]
---

# Set up OBS for Prakriti

OBS Studio records the studio sessions that Prakriti turns into finished work. These settings take
about 15 minutes to set once. They are for OBS Studio 32 or later on a Mac with Apple silicon.

**Important:** Change one thing at a time on a day you are not teaching, and finish with the 10-second
test at the end of this page.

## 1. Video

Choose OBS > Settings, then click Video.

- **Base (Canvas) Resolution:** 3840x2160
- **Output (Scaled) Resolution:** 3840x2160
- **Common FPS Values:** 30

If the camera or the Mac cannot keep up with 4K, use 1920x1080 for both. See "If OBS says Encoding
overloaded" in [If something isn't working](10-troubleshooting.md).

## 2. Output

Click Output, then set Output Mode to **Advanced**. Only Advanced mode records separate audio tracks.

Click the **Recording** tab and set:

- **Type:** Standard.
- **Recording Path:** the folder Prakriti watches. Prakriti finds each new recording there.
:::unless captureCheck
- **Recording Format:** Hybrid MP4 (.mp4). It survives a crash or a power cut. Never plain MP4, which a
  crash makes unreadable, and never MKV, which the Mac's own video tools cannot open.
:::
:::requires captureCheck
- **Recording Format:** Hybrid MOV (.mov). It survives a crash or power cut, and it is the default for
  new installs on a Mac since OBS 32. Hybrid MP4 (.mp4) also works. Never plain MP4: a crash makes it
  unreadable.
:::
- **Video Encoder:** Apple VT HEVC Hardware Encoder. It uses the Mac's video chip, so OBS stays light,
  and makes files about half the size of H.264 at the same quality.
- **Audio Encoder:** AAC. It opens everywhere.
- **Audio Track:** 1, 2, 3 and 4 (and 5 if you use a room microphone): one track per microphone, plus
  Zoom. They are set up in step 4.

Under the encoder's settings:

- **Rate Control:** CRF. It keeps the quality steady and lets the file size follow the picture.
- **Quality:** 65 to 70. On Apple's encoders **a higher number means better quality**, the opposite of
  other encoders, where a lower CRF is better.
- **Keyframe Interval:** 2 s. It lets editing tools jump to any moment quickly. Never 0.
- **Use B-Frames:** on. Smaller files at the same quality.

Click the **Audio** tab and set Audio Bitrate to **320** for every track you selected.

## 3. Audio and advanced settings

Click Audio and set Sample Rate to **48 kHz**. That is the rate video uses everywhere.

Click Advanced and leave these as they are:

- Color Format: NV12
- Color Space: Rec. 709
- Color Range: Limited
- Filename Formatting: keep the pattern the studio already uses (`%CCYY-%MM-%DD %hh-%mm-%ss`). Prakriti
  reads the date of each recording from its name.

Click OK.

## 4. Sources and tracks

In the Sources list, add one source for each thing you want to record:

- **A camera through a capture card:** Capture Card Device.
- **An iPhone or a webcam:** Video Capture Device.
- **Each microphone:** Audio Input Capture, one per microphone.
- **Zoom or other computer sound:** macOS Audio Capture, set to the Zoom app.

Each sound should come from one source only, or it is recorded twice.

Then choose Edit > Advanced Audio Properties and set each source's Tracks:

- **First teacher's microphone:** tracks 1 and 2, Mono on.
- **Second teacher's microphone:** tracks 1 and 3, Mono on.
- **Zoom (macOS Audio Capture):** tracks 1 and 4, Mono off.
- **Room microphone (optional):** track 5 only, Mono on.

Track 1 is everything mixed together: it is what plays in QuickTime Player or any other player. Tracks
2 to 5 each hold one source alone, so each voice is kept on its own in the original. The room
microphone stays out of track 1, so students' voices are never mixed into the teachers' sound.

:::requires people
Prakriti builds the finished sound from tracks 2 to 5, so it can keep each teacher's voice clean and
leave out a voice you choose to remove.
:::

Turning on Mono for a microphone puts the voice in both ears instead of one.

**Note:** Leave noise suppression, noise gate and compressor filters off on the microphones. Prakriti
needs the untouched sound.

## 5. A key for chapter markers

Click Settings > Hotkeys and find **Add Chapter Marker (Hybrid MP4/MOV only)**. Give it a key, or a
button on a remote or a Stream Deck. Press it during a session to mark a strong moment, or right after
a mistake. The marker is saved in the file when you stop recording.

## 6. A vertical copy

If OBS also records a vertical copy of the session (a file whose name ends in `-vertical`), Prakriti
leaves that file alone, so the same session is never made twice.

:::requires shorts
With a 4K canvas you do not need a separate vertical canvas. Prakriti cuts each vertical short from
the middle of the 4K picture at the full 1080 by 1920 size that Shorts and Reels use.

With a 1080p canvas, a short cut from the middle would be blurry. Keep a vertical canvas plugin on
(such as Aitum Vertical) at 1080x1920. Prakriti recognizes its file, ending in `-vertical`, as the same
session.
:::

## 7. Check it with a 10-second test

1. Click Start Recording, speak for 10 seconds into each microphone in turn, and play a few seconds of
   Zoom audio if you use it.
2. Click Stop Recording.
3. Look at the bottom of the OBS window. There should be no "Encoding overloaded!" message and no
   dropped frames.
:::requires captureCheck
4. Put the test file in the Drop folder. Prakriti's capture check on the recording's page should show
   3840 by 2160 at 30 frames per second, and one track for each source with sound on it.
:::

To check the file in Terminal, replace the path at the end with your test file's:

```bash
cd ~ && ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,r_frame_rate,channels -of compact "$HOME/Movies/test.mp4"
```

Each `codec_type=audio` line is one track. You should see five lines (track 1 and the four on their
own), or six with a room microphone. The `codec_type=video` line shows the picture's width, height and
frame rate.

## Storage

A 4K recording at these settings is several times larger than a 1080p file. Before the first full
session, record five minutes, note the file size, and multiply by the length of a session. Make sure
the folder that receives recordings, and every Mac that syncs it, has room.
