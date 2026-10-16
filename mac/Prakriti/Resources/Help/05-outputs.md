---
id: outputs
title: Outputs
summary: What Prakriti makes from each recording, what is in each file, and where the files go.
section: outputs
order: 1
keywords: [outputs, thumbnails, thumbnail, headline, make thumbnails, use this one, timelines, Final Cut Pro, DaVinci Resolve, FCPXML, Make Timelines, export timeline, edit plan, rough cut, edited video, MP4, YouTube, Make Video, Watch Video, punch-in, push-in, zoom, House Style, end screen, ready checklist, description, pauses, filler words, podcast episode, podcast-ready, MP3, loudness, LUFS, transcript, captions, SRT, VTT, report, show notes, chapters, titles, episode text, upload checklist, artwork, show name, word list, intro, outro, mono, stereo]
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
:::requires shorts
- **Shorts:** vertical clips of the strongest moments.
:::
:::requires thumbnails
- **Thumbnails:** three designed YouTube thumbnails to choose from.
:::
:::requires timelines
- **Timelines:** the same edit, to open and finish in Final Cut Pro or DaVinci Resolve.
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

Parakeet, the transcription tool, can miss a stretch of speech now and then. So after it has listened
to the whole recording, Prakriti compares the sound with the words: wherever there are 3 seconds or more
with no words but someone is speaking, it listens to that stretch again on its own and adds the words it
hears, each once, in its place.

### Checks and report

`REPORT.md`: how long the recording is, how its sound measured, the episode's loudness, how much of the
recording the transcript covers (any stretch listened to again, and any stretch of speech still without
words), and any word the word list fixed. It says plainly that speakers are
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
:::requires direction
To steer one recording's plan (a style, a pace, a length, what to focus on), use the inspector's
Direction tab. The plan then shows in plain lines before anything is made. See
[Editorial direction](08-editorial-direction.md).
:::
:::requires style
A plan for a video also reads the parts of the talk (with the model chosen for Planning the edit), for
its opening line, key phrases, terms, held moment and chapters. Those chapters go in the video's
`Description.txt`, so the Ready checklist's Chapters line passes even with Titles, show notes and
chapters off.
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

Prakriti makes a video once the recording's people check has run, and applies your choices in the
People tab to it:

- **Hide Face:** their face is hidden in every frame under a heavy blur, followed from frame to frame,
  and held half a second before and after each time it is seen. Their voice stays.
- **Leave Out:** every stretch they speak is cut from the picture and the sound together, and their face
  is hidden wherever it still shows.

Before the video is kept, Prakriti looks for faces in it again, five frames a second, and listens to it
again. If it finds a face that is not someone you included, or hears someone you left out, it keeps no
video and says when, such as "A face Prakriti cannot account for at 12:41. Hide it or include the
person, then Make Again." The People line of the Ready checklist says what it found.

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
To watch it, open the recording and choose **Video** in the toolbar, or click **Watch Video** under
Edited video. The viewer draws each frame the same way the file was made, from the same edit plan, and
plays the video's own sound, so what you watch is what you would upload. See
[Review and approve](06-reviewing-and-approving.md).
:::

:::requires houseStyle
### Punch-ins and the ending

The video is edited in the style chosen in Settings, House Style.
[Show Me](prakriti://show/settings/houseStyle)

- **Punch-ins.** About every other change of picture, at a cut or between two sentences, the picture
  moves a little closer on the teacher's face; at the next change it goes back to the whole picture, so
  a cut reads as a second camera. With Clear it moves to 1.12 times the picture, with the eyes a third of the way down.
  On a 1080p recording no punch-in goes past 1.15, so the picture stays sharp. Where no face is seen, or
  the face moves through the shot, the whole picture stays.
- **Slow push-ins.** Now and then a long shot of the whole picture moves in slowly, with Clear to 1.05
  over 4 seconds, at most once every 90 seconds.
- **About 7 changes of picture a minute** with Clear, and 10 in the first 30 seconds.
- **Room at the end.** The speaking ends 5 seconds before the last frame, so YouTube's end screen covers
  no words. The last frame is held, without sound.

Each style has its own numbers, for the pauses too (those under Edit plan are Clear's): Calm changes
less and only gently, Energetic more often and closer, Story in between. Pace makes any style quicker or slower, and Teaching keeps demonstrations whole and
wide. A change in House Style is used the next time the edit is planned: click Plan the Edit or Make
Again. Videos already made stay as they are.
:::

:::requires textOnScreen
### The title and names on screen

Text on the edited video is switched on or off in Settings, House Style, under Text on Screen.
[Show Me](prakriti://show/settings/houseStyle)

- **The title.** For 2 seconds as the talk begins, the recording's title as you set it in the inspector's Info.
  It sits on the side of the frame away from the teacher, as large as fits in three lines. A recording
  with no title shows none: nothing is written for you.
- **The teacher's name.** Once, the first time the teacher is seen after the title, their name with
  "Teacher" under it, near the bottom of the frame on the side away from their face, for about 4
  seconds. Only for a teacher you named (Who Is Teaching, or a person whose role is Teacher) who is
  included in the video.
- **Key phrases and terms.** The speaker's own words, and the Sanskrit terms the talk explains, from the
  parts of the talk, switched on or off under Key phrases and Terms. See
  [Editorial direction](08-editorial-direction.md). When the video opens on the talk's strongest line, the
  title comes right after it.

Text never covers a face: Prakriti checks every face it found, through each punch-in, for the whole
time the text shows, and waits for a clear moment or leaves the text out. All text stays inside the
middle 90% of the frame, so no screen crops it. The type is Alegreya Sans, Yoga Marga's own, white with
a soft shadow and no box behind it. It comes in over a third of a second and goes out over a quarter.

To change a title on screen, change the title in Info, then click Plan the Edit or Make Again.
:::


:::requires shorts
### Shorts

Vertical clips, 1080 by 1920, of the strongest moments, cut from the same edit plan as the video, so
pauses, filler words and anyone you left out stay out. Three of up to 60 seconds each unless you choose
otherwise in the Direction tab (0 to 5 shorts, up to 30, 45 or 60 seconds). Each is whole sentences
from one part of the talk, starting on its strongest line. YouTube treats a vertical video of up to 3
minutes as a Short, and Prakriti never makes one longer.

The words are on screen, because many people watch shorts with the sound off: one line of two to five
words at a time, the word being said in full white and the rest a little dimmer, inside the part of the
frame no app covers with its buttons. The sound is at -14 LUFS, like the video.

The picture comes from the vertical recording when OBS made one and its sound lines up with the main
recording, from a crop of a 4K picture, or from a crop of a 1080p picture, which is softer, and Checks
says so. A crop follows the speaker's face and moves only when the face leaves the middle of the frame.
Faces you hid are hidden in every short, and each short is checked for faces and voices before it is
kept, like the video. They are in the Shorts folder, each with its captions file. In the inspector,
Outputs lists them with Play and Show in Finder, and Make Shorts makes them for a recording made
without them.
:::

:::requires thumbnails
### Thumbnails

Three designed thumbnails for YouTube, each a different look, in the recording's Thumbnails folder:
`Thumbnail A.jpg` to `Thumbnail C.jpg`, 1280 by 720 and under 2 MB as YouTube asks, and a full-size copy of
each (1920 by 1080 from a 1080p recording, 3840 by 2160 from a 4K one).

Each starts from a real frame of the teacher: Prakriti looks at frames from what the edit keeps, the
strongest lines of the talk first, and picks the sharpest, best lit ones with the eyes open. The teacher is
cut out of the frame and placed in Yoga Marga's colours, with a headline of two to four words written by
the model chosen for Writing in Settings, Models (never the title, never a person's name). The words are
large enough to read when YouTube shows the thumbnail small, and dark or light enough against what is behind
them. Each option says in one line why it looks the way it does.

- **A, Saffron:** the teacher on the right of the school's saffron, the words on the left.
- **B, Night and gold:** the teacher on the left of near-black, the words in gold.
- **C, The room:** the room as it was, darkened behind the words.

Faces of anyone you set to Hide Face or Leave Out are hidden before anything is drawn, and every finished
thumbnail is looked at again: if a face in it is not someone you included, that option is not kept.

In the inspector, Outputs, under Thumbnails, click Use This One under the one you want; the recording's
picture in the library shows it. Make Thumbnails makes them for a recording made without them. If you
change who is hidden afterwards, the library shows the recording's own picture again until you make them
again.
:::

:::requires timelines
### Timelines for Final Cut Pro and DaVinci Resolve

The same edit as the edited video, as files you can open and finish by hand: every cut, punch-in, caption, chapter
and title. Prakriti writes them with the video when Timelines is on for the recording, or at once with Make
Timelines, in the inspector's Outputs, under Timelines. They are in the recording's Timeline folder in Outputs:

- **Edit for Final Cut Pro.fcpxml:** click Open in Final Cut Pro, double-click the file, or choose File > Import >
  XML in Final Cut Pro and select it.
- **Edit for DaVinci Resolve.fcpxml:** in DaVinci Resolve, choose File > Import > Timeline and select it, with Use
  sizing information turned on, so the punch-ins come in. If the captions do not come in, choose File > Import >
  Subtitle and select the .srt file beside it.
- **Graphics:** the title, the teacher's name, key phrases and terms as clips that look exactly as in the video. Each
  has an editable copy on the lane above it, switched off.
- **Media:** when everyone is included, a copy of the recording that takes no extra space on this Mac until one of
  them changes. When anyone is set to Hide Face or Leave Out, or a name is muted, a privacy-safe copy instead (see
  below).
- **Read Me.txt:** how to open each file, in five lines.

Slow push-ins are markers named "Push-in here", not moves, until they have been checked in both apps. File > Export
Final Cut Pro Timeline (Command-E) and File > Export DaVinci Resolve Timeline show the file in the Finder, and write it
first if needed.

**Important:** A timeline never points at the recording itself while anyone is hidden or left out. For such a
recording, Prakriti first makes a privacy-safe copy of the parts the edit uses, with 2 seconds to spare on each side:
hidden faces are burned into the picture, removed speech is replaced by the room's own sound on every sound track, and
the microphone track of anyone you left out is not in it at all. It looks for faces and listens again before the
timelines are kept, so a clip edge dragged out or an effect switched off cannot bring anyone back. This copy takes a
few minutes to make and about 22 GB for an hour of edit; the row shows how far it has come.

Keep the Timeline folder together. If you move it, Final Cut Pro or Resolve asks you to find the media again.
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
