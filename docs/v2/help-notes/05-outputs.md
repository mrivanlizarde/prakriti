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

## Notes from part M8d (Wed 14 Oct 2026)

- "Edited video" loses "video that hides or leaves out a person arrives in the next update": Make Video is refused only before
  the people check. The new paragraph says what Hide Face and Leave Out do to the video and that the made file is looked at
  again (faces, five frames a second) and listened to again before it is kept, with the gate's own sentence.
- The `requires style` section still mentions blurring each person: M9 must drop that line when it switches `style` on, since the
  `renderedVideo` paragraph now describes it.

## Notes from part M9a (Wed 14 Oct 2026)

- New block `:::requires houseStyle`, "Punch-ins and the ending", after the Edited video block: every number in it is
  `Style.base(.clear)` and `Style.maxScale` (1.12, 1.15 on 1080p, 1.05 over 4 s once in 90 s, about 7 changes a minute and 10 in
  the first 30 s, 5 s at the end), measured on the 13 Sep talk by `make accept-style`. Keywords added: punch-in, push-in, zoom,
  House Style, end screen. The `style` block's "Edited video" section (key ideas as text, transitions) stays hidden: text is M9b
  and transitions M9c/M9d; reconcile it with the `renderedVideo` and `houseStyle` blocks before `style` is switched on.

## Notes from part M9b (Thu 15 Oct 2026)

- New block `:::requires textOnScreen`, "The title and names on screen", before the hidden `style` block: the title for 2 s
  (Ivan's own title in Info, never written for him), the teacher's name once with "Teacher" for about 4 s (4.55 s: 0.3 in, 4 s,
  0.25 out), never over a face, inside the middle 90% (title safe), Alegreya Sans. Every number is `OverlayKind.motion` and
  `OverlayLayout`, measured on the test pattern by `TextTests` and on the 13 Sep excerpt by `make accept-text`. Help 10 gains
  "If the title or the teacher's name is not on the video". Key phrases and term cards stay in the hidden `style` block (M9d).

## Status after v2 part M9c (Thu 15 Oct 2026)

- New block `:::requires direction` after the Edit plan section: one paragraph pointing to Direction above Edit plan and to
  article 08. The "Edited video" block (`style`) stays hidden: key ideas as text on screen and transitions are M9d.

## Status after v2 part M9d (Thu 15 Oct 2026)

- The old hidden `style` block "Edited video" (zooms, key ideas as text, "few, simple transitions", "includes or blurs each
  person", a text file with tags) was removed when `style` was switched on: the `renderedVideo`, `houseStyle` and `textOnScreen`
  blocks describe the video as built, transitions are not built (hard cuts only), and tags are not written for the video.
- The Direction pointer now names the Direction tab. A new `style` paragraph says a video's plan reads the parts of the talk and
  that their chapters go in `Description.txt` (the Ready checklist's Chapters line passes with writing off).
- "The title and names on screen": the title shows as the talk begins, after the opening line; key phrases and terms point to 08.

## Built in v2 part M10a (Thu 15 Oct 2026)

- "Timelines for Final Cut Pro and DaVinci Resolve" now describes what is built: the Timeline folder (two `.fcpxml` files, the
  video's `.srt`, `Read Me.txt`, `Graphics/`, `Media/`), Make Timelines and the Timelines output, Open in Final Cut Pro, File >
  Import > Timeline in Resolve with Use sizing information, File > Export Final Cut Pro Timeline (Command-E), push-ins as markers,
  and the refusal for anyone hidden or a muted name. The old text promised "every cut, zoom, caption, title and transition stays
  editable"; zooms that move and transitions are not written until M10b's round trips, so it was cut. "with blurs and removals
  already applied" was cut too: M10a writes no timeline when anyone is hidden.
- 10 (troubleshooting): "Update DaVinci Resolve to the latest version" was replaced: the file is written for Resolve 20 and the
  plan asks Ivan not to update Resolve during the build. Added: no timeline, and missing punch-ins or captions in Resolve.
- 07: "In the timelines", under `timelines`. The older line under `people` (cleaned media) stays hidden for M10b.
- Unverified until Ivan's round trips (PLAN M10 checks 5 to 7): that Resolve 20.2.1 imports the 1.10 file with its captions,
  markers and the texts' lanes; that Final Cut Pro shows the punch-ins exactly as the MP4.

## Built in v2 part M10b (Thu 15 Oct 2026)

- 05: the refusal is gone. "Media" now says clone when everyone is included, privacy-safe copy otherwise; the Important note
  describes the copy as built (the parts used with 2 s to spare, faces burned in, removed speech replaced by the room's own
  sound on every track, a left-out person's own microphone track not in it, looked at and listened to again before it is kept,
  about 22 GB an hour of edit, measured 49.2 Mbps on two-people-mixed). Push-ins stay markers: the round trips are Ivan's.
- 07: "In the timelines" rewritten to the privacy-safe copy and its checks; the bullet under `choices` ("uses the video with
  your choices already applied") now names the privacy-safe copy, which is what is built.
- 10: "If there is no timeline" names the two new reasons (choices newer than the video, the copy failing its own check) and
  the disk room the copy needs.

## Built in v2 part M11a (Fri 16 Oct 2026)

- 05: "Shorts" describes what is built: cut from the edit plan, 3 of up to 60 s unless the Direction tab says otherwise (0 to 5;
  30, 45 or 60 s), whole sentences of one part starting on its strongest line, never over 3 minutes; calm captions of 2 to 5
  words inside the area no app covers; -14 LUFS; the picture from the vertical recording, a 4K crop or a softer 1080p crop
  (Checks says so), a crop following the speaker; hidden faces hidden and every short checked before it is kept.
- 02: "Stay near the middle" no longer says a short is cut from the center: a crop follows the speaker.
- 03: the vertical canvas paragraph says the `-vertical` file becomes the shorts' picture once its sound lines up, with its own
  face step; a 4K short follows the speaker.
- 06: the Shorts rendition with "Short 1 of 3", and Vertical Guide (also in View).
- 08: the Direction tab's Shorts (how many, how long).
- Not built here (M11b): thumbnails, upload checklists for Shorts, Reels and TikTok, the Approve sheet, Ready.
