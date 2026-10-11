---
id: set-up-obs-for-prakriti
title: Set up OBS for Prakriti
summary: The OBS Studio settings that give Prakriti a crash-safe file, a sharp picture, and every microphone on its own track.
keywords: [OBS, settings, Hybrid MOV, Hybrid MP4, canvas, 4K, 1080p, frame rate, encoder, Apple VT, HEVC, CRF, quality, keyframe interval, audio tracks, multitrack, Zoom, macOS Audio Capture, chapter marker, vertical, file name]
related: [02-capture-the-best-video, 04-sources-and-watching, 10-troubleshooting]
---

# Set up OBS for Prakriti

OBS Studio records the studio sessions that Prakriti turns into finished work. These settings take
about 15 minutes to set once. They are for OBS Studio 32 or later on a Mac with Apple silicon.

**Important:** Change one thing at a time on a day you are not teaching, and finish with the
10-second test at the end of this page.

## 1. Video

Choose OBS > Settings, then click Video.

| Setting | Value |
|---|---|
| Base (Canvas) Resolution | 3840x2160 |
| Output (Scaled) Resolution | 3840x2160 |
| Common FPS Values | 30 |

If the camera or the Mac cannot keep up with 4K, use 1920x1080 for both. See "If OBS says Encoding
overloaded" in [If something isn't working](10-troubleshooting.md).

## 2. Output

Click Output, then set Output Mode to **Advanced**. Only Advanced mode records separate audio tracks.

Click the **Recording** tab:

| Setting | Value | Why |
|---|---|---|
| Type | Standard | |
| Recording Path | The folder Prakriti watches | Prakriti finds each new recording there. |
| Recording Format | Hybrid MOV (.mov) | Survives a crash or power cut, and it is the default for new installs on a Mac since OBS 32. Hybrid MP4 (.mp4) also works. Never plain MP4: a crash makes it unreadable. |
| Video Encoder | Apple VT HEVC Hardware Encoder | Uses the Mac's video chip, so OBS stays light, and makes files about half the size of H.264 at the same quality. |
| Audio Encoder | AAC | Opens everywhere. |
| Audio Track | 1, 2, 3 and 4 (and 5 if you use a room microphone) | One track per microphone, plus Zoom. Set up in step 4. |

Under the encoder's settings:

| Setting | Value | Why |
|---|---|---|
| Rate Control | CRF | Keeps the quality steady and lets the file size follow the picture. |
| Quality | 65 to 70 | On Apple's encoders **a higher number means better quality.** This is the opposite of other encoders, where a lower CRF is better. |
| Keyframe Interval | 2 s | Lets editors and Prakriti jump to any moment quickly. Never 0. |
| Use B-Frames | On | Smaller files at the same quality. |

Click the **Audio** tab and set Audio Bitrate to **320** for every track you selected.

## 3. Audio and advanced settings

Click Audio and set Sample Rate to **48 kHz**. That is the rate video uses everywhere.

Click Advanced and leave these as they are:

- Color Format: NV12
- Color Space: Rec. 709
- Color Range: Limited
- Filename Formatting: keep the pattern the studio already uses (`%CCYY-%MM-%DD %hh-%mm-%ss`).
  Prakriti reads the date of each recording from its name.

Click OK.

## 4. Sources and tracks

In the Sources list, add one source for each thing you want to record:

| Thing | OBS source |
|---|---|
| Camera through a capture card | Capture Card Device |
| iPhone or webcam | Video Capture Device |
| Each microphone | Audio Input Capture, one per microphone |
| Zoom or other computer sound | macOS Audio Capture, set to the Zoom app |

Each sound should come from one source only, or it is recorded twice.

Then choose Edit > Advanced Audio Properties and set each source's Tracks:

| Source | Tracks | Mono |
|---|---|---|
| First teacher's microphone | 1 and 2 | On |
| Second teacher's microphone | 1 and 3 | On |
| Zoom (macOS Audio Capture) | 1 and 4 | Off |
| Room microphone (optional) | 5 only | On |

Track 1 is everything mixed together: it is what plays in QuickTime Player or any other player. Tracks
2 to 5 each hold one source alone. Prakriti builds the finished sound from those, so it can keep each
teacher's voice clean and leave out a voice you choose to remove. The room microphone stays out of
track 1 so students' voices are never mixed into the teachers' sound.

Turning on Mono for a microphone puts the voice in both ears instead of one.

**Note:** Leave noise suppression, noise gate and compressor filters off on the microphones. Prakriti
needs the untouched sound.

## 5. A key for chapter markers

Click Settings > Hotkeys and find **Add Chapter Marker (Hybrid MP4/MOV only)**. Give it a key, or a
button on a remote or a Stream Deck. Press it during a session to mark a strong moment, or right after
a mistake. The marker is saved in the file when you stop recording.

## 6. Vertical video for shorts

With a 4K canvas you do not need a separate vertical canvas. Prakriti cuts each vertical short from the
middle of the 4K picture at the full 1080 by 1920 size that Shorts and Reels use.

With a 1080p canvas, a short cut from the middle would be blurry. Keep a vertical canvas plugin on
(such as Aitum Vertical) at 1080x1920. Prakriti recognizes its file, ending in `-vertical`, as the
same session and does not make it twice.

## 7. Check it with a 10-second test

1. Click Start Recording, speak for 10 seconds into each microphone in turn, and play a few seconds of
   Zoom audio if you use it.
2. Click Stop Recording.
3. Look at the bottom of the OBS window. There should be no "Encoding overloaded!" message and no
   dropped frames.
4. Put the test file in the Drop folder. Prakriti's capture check on the recording's page should show
   3840 by 2160 at 30 frames per second, and one track for each source with sound on it.

To check the file yourself in Terminal, replace the path at the end with your test file's:

```bash
cd ~ && ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,r_frame_rate,channels -of compact "$HOME/Prakriti/Drop/test.mov"
```

Each `codec_type=audio` line is one track. You should see five lines (track 1 and the four on their
own), or six with a room microphone.

## Storage

A 4K recording at these settings is several times larger than today's 1080p files. Before the first
full session, record five minutes, note the file size, and multiply by the length of a session. Make
sure the folder that receives recordings, and every Mac that syncs it, has room.

## See also

- [Capture the best video](02-capture-the-best-video.md)
- [Sources and watching](04-sources-and-watching.md)
- [If something isn't working](10-troubleshooting.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

### What this changes in SCOPE and REQUEST.md (raise with Ivan)

- **SCOPE SET-04 says "Hybrid MP4, never MKV."** Since OBS 32.0 the default recording format for new
  installs is Hybrid MP4, **"Hybrid MOV on macOS."** Both are crash-safe and both carry chapter
  markers; MOV also takes PCM audio with better compatibility and ProRes. Prakriti already accepts
  `.mov` (`FolderScan.mediaExtensions`). Recommendation: accept either; tell Ivan to keep OBS's Mac
  default. The readiness rule for a Hybrid file (SCOPE §7.3 fixtures) must be captured for MOV too.
- **SCOPE SET-05 says "vertical canvas back on."** With a 4K canvas it is redundant: a 9:16 crop of
  a 3840x2160 frame is 1215x2160, which scales down to 1080x1920 cleanly. The existing vertical file
  is itself only a center crop of the same camera (research/07 §1.3), so a 4K crop loses nothing and
  can follow the teacher. It also removes a plugin with reported OBS 32 bugs and halves what syncs.
  Keep the vertical canvas only at 1080p.
- **Storage trap.** Today's files are 1080p at 6.18 Mbps (about 2.8 GB an hour, research/07). A 4K
  HEVC file at Quality 65 to 70 will likely be 30 to 80 Mbps, roughly 13 to 36 GB an hour
  `[unverified: measure with the five-minute test]`. The studio folder is an iCloud share that syncs
  to everyone in it with Optimize Mac Storage on. 4K multiplies that load several times. Decide before
  the studio visit: a bigger iCloud plan, or a local recording drive on the studio Mac with Prakriti
  reading from it.
- **Track layout** matches SCOPE SET-03 (mix, Gabriel, Serenity, Zoom), plus an optional room track
  kept out of the mix. Generic wording here because the help may be read by other users.

### Assumptions about v2

- The capture check on a test file (see 02's builder notes).
- Prakriti v2 reads every audio track and builds outputs from tracks 2 to 5, never from track 1 when
  isolated tracks exist. v1 measures one track only.
- Prakriti reads OBS chapter markers.
- Prakriti crops vertical shorts from a 4K horizontal source.

### Verification notes

- OBS labels in this article were checked against OBS's own en-US locale files on GitHub (master,
  10 Oct 2026): "Base (Canvas) Resolution", "Output (Scaled) Resolution", "Common FPS Values",
  "Output Mode", "Advanced", "Recording Format", "Hybrid MOV (.mov)", "Hybrid MP4 (.mp4)",
  "Video Encoder", "Audio Encoder", "Audio Track", "Audio Bitrate", "Sample Rate", "Color Format",
  "NV12 (8-bit, 4:2:0, 2 planes)", "Color Space", "Rec. 709", "Color Range", "Limited",
  "Filename Formatting", "Advanced Audio Properties", "Tracks", "Mono",
  "Add Chapter Marker (Hybrid MP4/MOV only)", "Encoding overloaded! ...", "Capture Card Device",
  "Video Capture Device", "Audio Input Capture", "macOS Audio Capture", "Start Recording".
  The menu path "OBS > Settings" on macOS and "Settings > Hotkeys" `[unverified on OBS 32.2 UI]`.
- Apple VT encoder (OBS `plugins/mac-videotoolbox/encoder.c`, master): Rate Control list includes
  CRF; "Quality" is a 0 to 100 slider passed to `kVTCompressionPropertyKey_Quality` as 0.0 to 1.0
  (default 60); CRF requires Apple Silicon; "Keyframe Interval (0=auto)" defaults to 2 s. An OBS
  maintainer on issue #11830 (still open): "What is normally known as "CRF" is just "Quality" and
  higher numbers are expected to give better quality."
- Quality 65 to 70 is a starting point, not measured on the studio Mac `[unverified]`. Measure the
  five-minute test's bitrate with ffprobe and look at a frame.
- Whether Hybrid MOV carries 5 or 6 AAC tracks without problems in Final Cut Pro and Resolve is not
  documented by OBS `[unverified: check with the test file]`.
- OBS version state on 10 Oct 2026: 32.2.2 is the latest stable (14 Aug 2026); 33.0.0 RC1 was
  published 9 Oct 2026. Nothing in 33.0's notes changes these settings except "Improved file
  splitting for Hybrid MP4/MOV". OBS 32.2 no longer runs on macOS 12.
- The studio Mac's model is unknown (SCOPE Q-G22). On an Intel Mac, CRF is not offered; use ABR at
  about 40,000 kbps for 4K or 15,000 for 1080p `[unverified values]`.

### Sources (checked 10 Oct 2026)

- Hybrid MP4 and MOV, versions, codecs, crash recovery, chapter markers: https://obsproject.com/kb/hybrid-mp4
- OBS 32.0: "default settings for new installs now use our crash resistant Hybrid MP4 video container (Hybrid MOV on macOS)": https://obsproject.com/welcome
- OBS releases (32.2.2 latest stable; 33.0.0 RC1 9 Oct): https://github.com/obsproject/obs-studio/releases
- Multitrack recording: https://obsproject.com/kb/multiple-audio-track-recording-guide
- Simple vs Advanced output: https://obsproject.com/kb/standard-recording-output-guide
- Apple VT CRF behavior: https://github.com/obsproject/obs-studio/issues/11830
- macOS Audio Capture (OBS 30+, macOS 13+, one app's audio): https://obsproject.com/kb/macos-desktop-audio-capture-guide
- Aitum Vertical canvas settings: https://aitum.notion.site/General-Settings-060fefd594e648babca9820bc19af01b ; OBS 32 reports: https://obsproject.com/forum/threads/aitum-vertical.166504/page-12
- 48 kHz and 320 kbps AAC for local recording (community guidance): https://obs-versions.com/blog/obs-audio-settings-guide
- YouTube Shorts and Reels size 1080x1920 (9:16): https://support.google.com/youtube/answer/15424877
