# Builder notes: 03-set-up-obs-for-prakriti.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/03-set-up-obs-for-prakriti.md` ("Set up OBS for Prakriti").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Tables are lists. Recording Format says **Hybrid MP4** until the capture check lands (`captureCheck`, M4b,
  which accepts Hybrid MOV and updates START_HERE warning 15); the MOV text is kept in a block.
- Gated: tracks 2 to 5 used for the finished sound (`people`), the vertical canvas for shorts (`shorts`),
  the capture check on the test file (`captureCheck`). Visible: a `-vertical` file is left alone (W18).
- The ffprobe example's path is `~/Movies/test.mp4` (OBS's default folder), not the Drop folder, because a
  file under 60 s in the Drop folder makes nothing yet.

## Notes from the help track (Sat 10 Oct 2026)

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
