---
id: welcome
title: Welcome to Prakriti
summary: What Prakriti does, in five steps, and what it never does.
keywords: [welcome, overview, getting started, how it works, steps, what it does, approve, publish]
related: [02-capture-the-best-video, 03-set-up-obs-for-prakriti, 04-sources-and-watching, 06-reviewing-and-approving]
---

# Welcome to Prakriti

Prakriti turns raw recordings of talks and classes into finished work: a podcast episode, an edited
video ready to post, captions, a transcript, thumbnails, and a timeline you can open in Final Cut Pro
or DaVinci Resolve. It runs on your Mac, keeps watching with its window closed, and stops before
anything goes out, so a person always makes the last call.

## How it works, in five steps

1. **Record.** OBS, or any app that records, saves the session into a folder Prakriti watches. You
   can also drop any recording into the Drop folder.
2. **Prakriti finds it and checks it.** It waits until the recording has finished saving, then checks
   the sound, the picture and every audio track. A silent or broken recording is flagged the same day,
   and nothing is made from it.
3. **Prakriti makes the outputs you chose.** It writes the transcript, finds the people who appear and
   speak, edits the video, masters the sound and drafts the titles and notes. Today and the recording's
   page show each step as it happens and how long is left.
4. **You review.** Watch the edit in the viewer, choose who appears in each output, steer the edit with
   a few words, and make it again until it is right.
5. **You approve.** Prakriti copies the finished files to your Approved folder with a receipt. You
   upload them. Prakriti never posts or uploads anything on its own.

## What Prakriti never does

- It never changes or deletes an original recording, and never writes into a folder it watches.
- It never uploads, posts or sends anything.
- It never keeps the face or voice of someone you have not named and marked as having agreed.
- It never sends a class, or any recording where other people appear or speak, to a model outside your
  Mac.

## Start here

1. [Capture the best video](02-capture-the-best-video.md): the light, sound and room choices that
   matter most.
2. [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md): the settings, once.
3. Turn on notifications so you know when a recording is ready: choose Apple menu > System Settings,
   click Notifications, click Prakriti, then turn on Allow notifications.
4. Record a 10-second test and put it in the Drop folder.

**Tip:** To see the welcome screens again, choose Help > Welcome to Prakriti.

## See also

- [Sources and watching](04-sources-and-watching.md)
- [Outputs](05-outputs.md)
- [Review and approve](06-reviewing-and-approving.md)
- [People and privacy](07-people-and-privacy.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

- **Assumes these v2 names and places:** the viewer on the recording's page; "Help > Welcome to
  Prakriti" reopens the welcome panels (Apple HIG: a skipped tutorial must be easy to find later, for
  example in a help area); Today and the recording page show per-step progress with time left
  (Ivan's item 6). Rename here if the build uses different words.
- **"It never sends a class, or any recording where other people appear or speak, to a model outside
  your Mac"** is REQUEST.md's relaxed privacy lock (mentions of Serenity no longer force local).
  v1's lock still includes "transcript says Serenity" (`Writer.swift`); this line is true of v1 too.
- **Notifications:** v1's finish line found macOS had notifications off for Prakriti and no banner was
  ever seen. The welcome panels ask for permission (see welcome-panels.md), and this page repeats the
  manual path. The System Settings path is from BUILD-LOG ("System Settings, Notifications, Prakriti:
  Allow notifications") `[unverified on macOS 27 wording]`.
- Five steps mirror SCOPE's life of a recording; the "flagged the same day" line is the 14 Sep silent
  class lesson (`Pipeline.swift`: loudest point at or below -60 dB, Needs a decision, nothing made).
