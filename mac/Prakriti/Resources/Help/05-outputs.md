---
id: outputs
title: Outputs
summary: What Prakriti makes from each recording, what is in each file, and where the files go.
section: outputs
order: 1
keywords: [outputs, podcast episode, podcast-ready, MP3, loudness, LUFS, transcript, captions, SRT, VTT, report, show notes, chapters, titles, episode text, upload checklist, artwork, show name, word list, intro, outro, mono, stereo]
related: [sources-and-watching, reviewing-and-approving, models-and-api-keys]
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

- **Podcast episode:** a quick MP3 to listen to.
- **Podcast-ready episode:** the finished MP3 for a podcast host, with everything the host asks for.
- **Transcript:** the words, with times, in the formats you choose.
- **Checks and report:** length, sound, loudness and how much the transcript covers, in one short
  report.
- **Titles, show notes and chapters:** drafts written by the model you choose.
:::requires video
- **Edited video:** a finished video file ready to post, with its captions and text.
:::
:::requires shorts
- **Shorts:** vertical clips of the strongest moments.
:::
:::requires thumbnails
- **Thumbnails:** three still images to choose from.
:::
:::requires timelines
- **Timeline:** the same edit, to open and finish in Final Cut Pro or DaVinci Resolve.
:::

The podcast episode, the transcript and the report are on for every new folder. The podcast-ready
episode and the titles, show notes and chapters start off, because they take longer: turn them on for a
folder, or for one recording.

### Podcast episode

`episode.mp3`, leveled to podcast loudness (-16 LUFS unless you change it). It is the draft to listen to
while you review.

### Podcast-ready episode

A folder named Podcast-ready, with:

- The finished MP3, mastered with its own chain to Apple's -16 LUFS with peaks at or under -1 dBTP, with
  its title, show, host, artwork and chapters written into the file. It is named after the show and the
  episode once both are set, and by its date until then.
- Captions timed to the finished MP3 (`.srt` and `.vtt`).
- `Episode text.txt` (and the same as `Episode text.md`): the episode title and three alternatives, a
  one-line summary, the show notes with the chapters, keywords, and a caption and a pull quote each for
  Instagram, LinkedIn, and X and Threads.
- `Upload checklist.txt`, which measures the file against Apple Podcasts' published requirements, line
  by line, as PASS, MISSING or FAIL, with what to do about each.

The show's name, host, artwork, numbering and a call to action are set once, in Settings, Outputs.
Prakriti never makes them up: until you set them, the checklist says MISSING. A recording marked as a
class is never made ready to upload.

In the inspector's Outputs, the Ready to upload section shows the checklist
and has a Copy button for the
title, the summary, the show notes and each caption, and Update Podcast-Ready Files writes a new title
or show name into the files without making the sound again.

### Transcript

The words as spoken, with times, in the formats you choose: plain text (`.txt`), subtitles (`.srt`), web
subtitles (`.vtt`) and formatted text (`.md`). Prakriti spells Yoga Marga's words using its word list,
shown in Settings, Outputs. When something is cut from the episode, the transcript follows: the cut
words are gone and the times match the episode.

### Checks and report

`REPORT.md`: how long the recording is, how its sound measured, the episode's loudness, how much of the
recording the transcript covers, and any word the word list fixed. It says plainly that speakers are
not checked yet.

### Titles, show notes and chapters

Three title options, show notes, chapters at real moments in the recording, tags, a short summary and
an accuracy checklist, in `show-notes.md`. Every quote in the checklist is found word for word in the
transcript, and every chapter starts at one of the transcript's own lines. The claims still need a
person to check them. See [Models and API keys](09-models-and-api-keys.md).

:::requires video
### Edited video

A video file ready to upload, made by Prakriti itself. The edit:

- Takes out long pauses, filler words such as "um" and "uh", false starts and repeated takes.
- Zooms in and out to hide cuts and to give weight to a key moment.
- Puts key ideas on screen as clean text, in the speaker's own words.
- Uses few, simple transitions.
- Masters the sound so voices are clear and even.
- Includes or blurs each person as you chose. See [Privacy and students](07-people-and-privacy.md).

Beside the video you get:

- Captions as a separate file (`.srt`) to upload with it.
- A text file with the title, description, chapters and tags.
- A **Ready to post** checklist. It measures the video against YouTube's published upload
  recommendations: an MP4 file that starts playing before it finishes downloading, H.264 video, AAC
  sound at 48 kHz, standard color (Rec. 709), the frame rate it was recorded at, and enough bitrate for
  its size. Every line must pass before you approve.
:::

:::requires shorts
### Shorts

Vertical clips, 1080 by 1920, each a complete moment of up to 3 minutes. YouTube treats a square or
vertical video of up to 3 minutes as a Short. The words appear on screen, because many people watch
shorts with the sound off.
:::

:::requires thumbnails
### Thumbnails

Three still images in the 16:9 shape, at 3840 by 2160, as YouTube recommends. They are made from real
frames of the recording, and only show people who have agreed to appear. Choose one when you approve.
:::

:::requires timelines
### Timeline for Final Cut Pro or DaVinci Resolve

The same edit as the finished video, as a file you can open and change by hand: every cut, zoom,
caption, title and transition stays editable.

- **Final Cut Pro:** choose File > Import > XML, select the `.fcpxml` file, then click Import. Or
  double-click the file in the Finder.
- **DaVinci Resolve:** open a project, then choose File > Import > Timeline and select the file. If a
  clip shows as offline, Control-click the timeline in the Media Pool and choose Relink Clips for
  Selected Timeline.

The timeline uses media from the recording's folder in Outputs, with blurs and removals already
applied. Keep that folder together. If you move it, Final Cut Pro or Resolve asks you to find the media
again.
:::

## Choose which outputs are made

- **For a folder:** select it under Sources in the sidebar, set it to Make outputs automatically in the
  inspector, then turn its outputs on or off. [Show Me](prakriti://show/sources)
- **For files you add by hand:** in Settings, Outputs (Command-comma), turn on the standard choices.
  [Show Me](prakriti://show/settings/outputs)
- **For one recording:** select it, then in the inspector's Outputs, under Outputs for this recording,
  change a switch. The recording then has its own choices. Click Make Again to make it with them.

How each output is made, such as the loudness target, the silence trim, an intro and outro, mono or
stereo, and the transcript's formats, is set in Settings, Outputs, for every folder at once.

## While it works

While a recording is being made, In Progress and the inspector show the step it is on. Files made
before are kept until the new ones are ready.
