---
id: outputs
title: Outputs
summary: What Prakriti makes from each recording, what is in each file, and where the files go.
section: outputs
order: 1
keywords: [outputs, edit plan, rough cut, edited video, MP4, YouTube, Make Video, ready checklist, description, pauses, filler words, podcast episode, podcast-ready, MP3, loudness, LUFS, transcript, captions, SRT, VTT, report, show notes, chapters, titles, episode text, upload checklist, artwork, show name, word list, intro, outro, mono, stereo]
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
:::requires renderedVideo
- **Edited video:** an MP4 cut from the edit plan, with its captions, a description to paste and a
  checklist against YouTube's rules.
:::
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
:::requires renderedVideo
The edited video starts off too, for every folder: it takes a few more minutes for each recording.
:::

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

:::requires editPlan
### Edit plan

The rough cut of a recording, worked out on this Mac from its transcript and its sound in a few seconds.
Select a recording, then in the inspector's Outputs, under Edit plan, click **Plan the Edit**. The plan:

- Shortens long pauses, and never takes a pause out entirely. Inside a sentence, a pause longer than
  0.4 s becomes 0.18 s. After a comma or a full stop, a pause longer than 0.6 s becomes 0.35 s. After a
  breathing or practice cue, such as "inhale", "notice" or "close your eyes", or after a question, a
  pause is kept up to 4 s. A pause is only ever quiet time: where the transcript has no words but there
  is sound, such as speech the transcription missed, the sound is kept and only the quiet around it is
  shortened.
- Takes out filler words (um, uh, er, erm, ah), the first of a word said twice ("so so"), and a false
  start ended with "let me start over", "take two" or "scratch that".
- Cuts only where the sound is quiet, never inside a word, and keeps what it cannot cut cleanly. Where it
  is not sure, such as two sentences in a row that start alike, it keeps both and lists the moment under
  Edit plan, with Play.
- Takes out your trim, your cuts and anyone you chose to Leave Out.

The plan is saved as `edit-plan.json` in the recording's folder, and the strip under the Original in the
viewer shows it. Once a recording has a plan, Make Again plans it again with your newest changes; Plan
Again does that alone, without making anything else.
:::
:::unless renderedVideo
Nothing else is made from the plan yet.
:::

:::requires renderedVideo
### Edited video

An MP4 made by Prakriti itself from the edit plan, on this Mac. To make one for a recording already made,
select it, then in the inspector's Outputs, under Edited video, click **Make Video**. To make one for
every new recording in a folder, turn on Edited video for that folder. A 15-minute talk takes a few
minutes.

- The cuts are the edit plan's: shortened pauses, filler words, words said twice and false starts
  taken out, and your trim and cuts. The picture and the sound are cut on the same frame.
- Each cut in the sound is a 20 ms crossfade, so no cut clicks, and the video is exactly as long as
  what the plan keeps.
- The sound is leveled to -14 LUFS with its peaks at -1 dBTP or under, the level YouTube turns
  louder videos down to (measured by others; YouTube publishes no figure).
- The picture is H.264 at 16 Mbps for 1080p, in the size and frame rate it was recorded.

For now, Prakriti makes a video only of a recording where everyone seen and heard is included, and
only once its people check has run. If anyone is set to Hide Face or Leave Out, Make Video says so and
makes nothing: video that hides or leaves out a person arrives in the next update. Watching the video
inside Prakriti arrives in the next update too.

The files are in a folder named Video, inside the recording's folder:

- The video, named after the recording's title, or its date until it has one.
- Its captions as a separate `.srt` file to upload with it: at most 42 characters a line and two lines,
  never more than a second behind the voice. Where the talk is faster than 20 characters a second, the
  captions keep every word and the checklist says how many are that fast.
- `Description.txt`: the title, the description and the chapters to paste into YouTube. They come from
  the title and notes you gave the recording in Info, else from the titles, show notes and chapters when
  they were written. Anything neither has is marked MISSING with what to do; Prakriti never makes one up.
- `Ready checklist.txt`: every line measured from the files, PASS, MISSING or FAIL, against YouTube's
  published upload settings. It checks the container, the codecs, the size, the frame rate, the bitrate,
  the color tags, the key frames, that the file starts playing before it finishes downloading, the
  loudness, that the video plays to its end, the captions, the title, description and chapters, and who
  is in it. The same lines are in the inspector, those that do not pass first.

The sound is AAC at 320 kbps, the most the Mac's own encoder makes. YouTube suggests 384 kbps; it
converts the sound again when you upload, so the difference does not reach a viewer.
:::

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
