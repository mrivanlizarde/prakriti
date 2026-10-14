# Builder notes: 05-outputs.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/05-outputs.md` ("Outputs").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3b (Mon 12 Oct 2026)

- v1's recording page was retired with the Viewer: every line that sent Ivan to "the recording's page"
  now names the viewer or the inspector's tab that holds the same thing.

## Status after v2 part M3a (Sun 11 Oct 2026)

- The Outputs screen is Settings, Outputs; its Show Me is `settings/outputs`. A folder's outputs are chosen in the
  inspector with the folder selected. Ready to upload shows on the recording's page and in the inspector's
  Outputs tab (the same `PodcastReadySection`).

## Status after v2 part M2a (Sun 11 Oct 2026)

- Tables are lists. The podcast-ready section now describes what was built on 10 and 11 Oct: `Episode
  text.txt` and `.md` (not "Title, show notes and captions.txt"), the file named after show and episode,
  MISSING until Ivan sets show, host and artwork, a class never made ready, the Ready to upload section and
  Update Podcast-Ready Files.
- Gated: edited video (`video`), shorts (`shorts`), thumbnails (`thumbnails`), timelines (`timelines`).
- "See also" lists were removed from every article: the window draws Related links from `related`.

## Notes from the help track (Sat 10 Oct 2026)

### State of each output on 10 Oct 2026

- Built in v1: Podcast episode, Transcript, Titles/show notes/chapters, Checks and report.
- Podcast-ready episode: being built by another run now. Names here are from its code
  (`PodcastPackage.folderName` "Podcast-ready", `textName` "Title, show notes and captions.txt",
  `checklistName` "Upload checklist.txt"; `.srt` and `.vtt` beside the MP3). Re-read after it lands.
- Edited video, Shorts, Thumbnails, Timeline: v2, not built. Everything said about them is the v2
  intent from REQUEST.md; confirm each line against the build.

### Assumptions to confirm

- The Ready to post checklist exists and gates Approve (REQUEST.md: "100% ready for distribution"
  means every output passes the platform's published specs). The listed checks are YouTube's own
  recommendations, below.
- The delivery size (1080p or 4K) of the edited video is left to the video track. Note: punch-ins
  up to 2x from a 4K source stay sharp at 1080p delivery but are upscaled at 4K delivery.
- Captions: a separate `.srt` for long videos (YouTube's recommended simple format), words on screen
  for shorts. If the video track also burns captions into the long video, add one line.
- Thumbnails: REQUEST.md allows real frames for Gabriel and Serenity. "Only show people who have
  agreed" generalizes that rule; confirm.
- **Timeline media (privacy trap).** If the FCPXML points at the original recording, opening it in
  Final Cut Pro shows every face Prakriti blurred and every voice it removed. This article assumes
  the timeline points at privacy-processed media in Outputs. Raise with the timeline track.
- Shorts length "up to 3 minutes" is YouTube's limit; Reels and TikTok limits not checked
  `[unverified]`.

### Sources (checked 10 Oct 2026)

- Apple Podcasts loudness (-16 LKFS within 1 dB, true peak -1 dBFS): podcasters.apple.com/support/893, as
  cited in `PodcastReady.swift`.
- YouTube recommended upload settings (MP4, moov at front, no edit lists; H.264 High profile, closed
  GOP of half the frame rate, 4:2:0; AAC-LC or Opus at 48 kHz, stereo 384 kbps, mono 128 kbps;
  BT.709; 1080p30 8 Mbps, 4K30 35 to 45 Mbps; upload at the recorded frame rate):
  https://support.google.com/youtube/answer/1722171
- YouTube Shorts: square or vertical up to three minutes, uploads on or after 15 Oct 2024:
  https://support.google.com/youtube/answer/15424877
- YouTube thumbnails: 3840 x 2160 for videos (2160 x 3840 for Shorts), minimum width 640, 50 MB on
  desktop, 2 MB on mobile, JPG or PNG, 16:9: https://support.google.com/youtube/answer/72431
- YouTube caption formats (SRT recommended for basic timing; WebVTT for positioning):
  https://support.google.com/youtube/answer/2734698
- Final Cut Pro: File > Import > XML, or double-click, or drag to the app icon:
  https://support.apple.com/guide/final-cut-pro/verdbd66ae/mac . FCPXML 1.14 arrived with Final Cut
  Pro 12.0 (28 Jan 2026): https://support.apple.com/102825
- DaVinci Resolve: File > Import > Timeline; Relink Clips for Selected Timeline (third-party guides):
  https://help.epidemicsound.com/hc/en-us/articles/31033671901458-How-to-Import-Your-Audio-Timeline-XML-FCPXML-and-Relink-Files .
  Resolve 21 (beta 4) added "importing and exporting Final Cut Pro 12 FCPXML files":
  https://www.motionmedia.com/mm-blog/davinci-resolve-21-beta-4-fcpxml-ai-updates . Exact menu
  wording in Resolve 21 `[unverified]`; which FCPXML version Resolve 21 accepts `[unverified]`.

## Built in v2 part TXGAP (Wed 14 Oct 2026)

- "Transcript" gains the paragraph on listening again: measured on the 6 Sep talk, the whole-file run wrote no words for 17 s at
  24:22, 17 s at 39:24 and 5 s at 43:04; each stretch heard again on its own gave 72, 59 and 22 words (153 in all), written once
  each. The rule is 3 s or more with no words and 1 s or more of speech by the sound's envelope (`TranscriptGaps`).
- "Checks and report" names the two new report entries (stretches listened to again, and stretches still without words).

## Notes from part M8c (Wed 14 Oct 2026)

- The `requires video` bullet in "The outputs" was removed: the `renderedVideo` bullet already describes the file, and two
  "Edited video" bullets would show once `video` is on. A `requires video` paragraph under the M8b section says how to watch it.
- The long `requires video` section (zooms, on-screen text, transitions, blurring each person) is now `requires style`: none of it
  is built in M8c. M9 (and M8d for blurring) must reconcile it with the `renderedVideo` section before switching `style` on, or
  two "Edited video" sections will show.
