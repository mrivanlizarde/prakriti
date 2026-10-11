---
id: outputs
title: Outputs
summary: What Prakriti makes from each recording, what is in each file, and where the files go.
keywords: [outputs, podcast episode, podcast-ready, MP3, transcript, captions, SRT, VTT, edited video, YouTube, shorts, vertical, thumbnails, timeline, FCPXML, Final Cut Pro, DaVinci Resolve, report, show notes, chapters, upload checklist, ready to post]
related: [04-sources-and-watching, 06-reviewing-and-approving, 07-people-and-privacy, 08-editorial-direction]
---

# Outputs

An output is something Prakriti makes from a recording. Each folder you watch makes the outputs you
turn on for it, and any recording can have its own choices.

## Where the files go

- **Made files:** the Outputs folder, in the Prakriti folder in your home folder, with one folder per
  recording, named after the recording.
- **Approved files:** when you click Approve, Prakriti copies the finished files to the Approved folder
  beside it. See [Review and approve](06-reviewing-and-approving.md).

The original recording is never changed. Nothing is uploaded or posted.

## The outputs

| Output | What you get |
|---|---|
| Podcast episode | A quick MP3 to listen to |
| Podcast-ready episode | The finished MP3 for a podcast host, with everything the host asks for |
| Transcript | The words, with times, in the formats you choose |
| Titles, show notes and chapters | Drafts written by the model you choose |
| Edited video | A finished video file ready to post, with its captions and text |
| Shorts | Vertical clips of the strongest moments |
| Thumbnails | Three still images to choose from |
| Timeline | The same edit, to open and finish in Final Cut Pro or DaVinci Resolve |
| Checks and report | Length, sound, loudness and coverage, in one short report |

### Podcast episode

`episode.mp3`, leveled to podcast loudness. It is the draft to listen to while you review.

### Podcast-ready episode

A folder named Podcast-ready with:

- The finished MP3, with its title, artwork, chapters and other details written into the file.
- Captions timed to the episode (`.srt` and `.vtt`).
- `Title, show notes and captions.txt`, ready to paste into the podcast host.
- `Upload checklist.txt`, which measures the file against Apple Podcasts' published requirements:
  loudness of -16 LUFS within 1 dB, and true peak no higher than -1 dBFS.

### Transcript

The words as spoken, with times, in the formats you choose: plain text (`.txt`), subtitles (`.srt`),
web subtitles (`.vtt`) and formatted text (`.md`). Prakriti spells Yoga Marga's words using its word
list. When something is cut from the episode or video, the transcript follows: the cut words are gone
and the times match.

### Titles, show notes and chapters

Three title options, show notes, chapters at real moments in the recording, and an accuracy checklist.
Every quote in the checklist is found word for word in the transcript. The claims still need a person
to check them. See [Models and API keys](09-models-and-api-keys.md).

### Edited video

A video file ready to upload, made by Prakriti itself. The edit:

- Takes out long pauses, filler words such as "um" and "uh", false starts and repeated takes.
- Zooms in and out to hide cuts and to give weight to a key moment.
- Puts key ideas on screen as clean text, in the speaker's own words.
- Uses few, simple transitions.
- Masters the sound so voices are clear and even.
- Includes or blurs each person as you chose. See [People and privacy](07-people-and-privacy.md).

You steer the edit with presets and a few words. See [Editorial direction](08-editorial-direction.md).

Beside the video you get:

- Captions as a separate file (`.srt`) to upload with it.
- A text file with the title, description, chapters and tags.
- A **Ready to post** checklist. It measures the video against YouTube's published upload
  recommendations: an MP4 file that starts playing before it finishes downloading, H.264 video, AAC
  sound at 48 kHz, standard color (Rec. 709), the frame rate it was recorded at, and enough bitrate
  for its size. Every line must pass before you approve.

### Shorts

Vertical clips, 1080 by 1920, each a complete moment of up to 3 minutes. YouTube treats a square or
vertical video of up to 3 minutes as a Short. The words appear on screen, because many people watch
shorts with the sound off.

### Thumbnails

Three still images in the 16:9 shape, at 3840 by 2160, as YouTube recommends. They are made from real
frames of the recording, and only show people who have agreed to appear. Choose one when you approve.

### Timeline for Final Cut Pro or DaVinci Resolve

The same edit as the finished video, as a file you can open and change by hand: every cut, zoom,
caption, title and transition stays editable.

- **Final Cut Pro:** choose File > Import > XML, select the `.fcpxml` file, then click Import. Or
  double-click the file in the Finder.
- **DaVinci Resolve:** open a project, then choose File > Import > Timeline and select the file. If a
  clip shows as offline, Control-click the timeline in the Media Pool and choose Relink Clips for
  Selected Timeline.

The timeline uses media from the recording's folder in Outputs, with blurs and removals already
applied. Keep that folder together. If you move it, Final Cut Pro or Resolve asks you to find the
media again.

### Checks and report

`REPORT.md`: how long the recording is, how its sound measured, its loudness, and how much of it the
transcript covers.

## Choose which outputs are made

- **For a folder:** click Sources, then turn outputs on or off under the folder.
- **For files you add by hand:** click Outputs and set the standard choices.
- **For one recording:** on its page, click Change Settings for This Recording, make your choices,
  then click Make Again.

How each output is made, such as the loudness target or the transcript's formats, is set on the
Outputs screen.

## Follow the progress

While a recording is being made, each output shows its own step and how long is left, on Today and on
the recording's page. Files made before are kept until the new ones are ready.

## See also

- [Review and approve](06-reviewing-and-approving.md)
- [People and privacy](07-people-and-privacy.md)
- [Editorial direction](08-editorial-direction.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

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
