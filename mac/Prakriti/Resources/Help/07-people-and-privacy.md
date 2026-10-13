---
id: people-and-privacy
title: Privacy and students
summary: What stays on this Mac, which recordings only models on this Mac may read, and how to protect students in a class.
section: people
order: 1
keywords: [privacy, students, class, privacy lock, Serenity, local, cloud, Anthropic, OpenAI, Claude API, transcript, approve, cut, notifications, names, children, consent]
related: [capture-the-best-video, reviewing-and-approving, models-and-api-keys]
---

# Privacy and students

Teachers choose to appear in what is published. Students usually have not. Prakriti keeps every
recording on this Mac, and holds back anything a person has not checked.

## What stays on this Mac

- **The original recording** is only read, never changed, and never uploaded.
- **The transcript** is made on this Mac. The copy with every word as it was heard stays in the
  recording's folder in Outputs and is never copied to the Approved folder. The transcript files that
  are approved follow the episode, so the words of a cut are gone from them too.
- **Notices** never show a file name or a recording's title, only facts such as its date, because they
  appear on the lock screen and on other devices.
- **Nothing is uploaded or posted.** You upload approved files yourself.

## Which recordings only models on this Mac read

A cloud model, Anthropic or OpenAI, reads only a talk in which everyone heard is named and has agreed to
cloud models, and nobody else appears or speaks. Everything else is only read by models on this Mac, even
if a task is set to Anthropic or OpenAI: a class, a conversation, a test, a recording whose kind is still Not
set, and any recording where other people appear or speak.

:::unless faces
Prakriti does not check who appears and speaks yet, so for now every recording is only read on this Mac.
:::

:::requires faces
Prakriti looks for faces now, but not yet for voices, so it cannot tell that nobody else speaks. For now every
recording is only read on this Mac.
:::

LM Studio does that task instead, and the inspector's Checks tab says why. Names are replaced before anything
is sent. See [Models and API keys](09-models-and-api-keys.md).

:::requires faces
## Faces in a recording

While it makes a recording's outputs, Prakriti looks for faces in the picture, two frames a second, on this
Mac. It keeps only when and where each face was seen: never a picture of anyone's face, and nothing that could
recognize them in another recording.

- **In the browser,** each recording shows a line such as "One person at a time." or "Other people appear, up
  to 2 at once." To see only the recordings with other people, click Sort in the toolbar and choose Other
  People Appear.
- **In the inspector's People tab,** a sentence says what was found, then one row for each face, Unnamed 1,
  Unnamed 2 and so on, with how long it is on screen. The face in each row is taken from the recording while
  the tab is open, and is never saved.
- **A notice** says "Other people appear in this recording." the first time two or more faces are seen at once.
  Like every notice, it never names the recording or anyone in it.
- **A recording found before Prakriti looked for faces** shows Look for Faces in its People tab.

Prakriti does not know who anyone is, and nothing it finds changes what is made: the outputs are the same as
before. A row is a face seen in one place in the picture, so one person who walks around can show as two rows;
"up to 2 at once" is the number to go by.
:::

:::unless people
## Classes and other voices

Prakriti does not yet tell one voice from another. So:

- Only a recording marked **Talk, one teacher speaking** can be approved. A class or a conversation
  shows "Speakers not checked" and cannot be approved.
- A class is never made ready to upload as a podcast episode.
- Before you approve a talk, listen for any voice other than the teacher's, and for any name said
  aloud. To take one out, select its words in the Viewer's transcript and choose Remove from the Edit,
  or type its times under Cut a section in the inspector's Info tab: the episode and the transcript both lose it.
  See [Review and approve](06-reviewing-and-approving.md).
:::

:::requires people
## What Prakriti looks for

In every recording, Prakriti looks for faces in the picture and voices in the sound, on this Mac.

- **People you have named** in People, who have agreed to be recognized, are shown by name.
- **Everyone else** is shown as Unnamed. Prakriti can tell them apart within one recording, but never
  remembers them from one recording to the next.

## See who is in a recording

In the browser, each recording shows who was found: the names of the people you have named, and how many
other people appear or speak, such as "Gabriel, Serenity and 3 other people". Choose View > Show
Recordings With Other People to see only those.

In the inspector's People tab, People in This Recording lists each person with a picture of their face, when
they appear, and when they speak.

## Choose who appears in each output

For each person, in each output, choose one:

- **Include:** seen and heard as recorded.
- **Blur Face:** heard as recorded, with their face blurred wherever it appears.
- **Remove:** their speech is cut, and their face is blurred wherever it still shows.

Where each person starts:

- People you have named and who have agreed start as **Include**.
- Everyone else starts as **Remove**. Change it only when that person has agreed to appear.
- Thumbnails only ever show people who have agreed.
- The timeline for Final Cut Pro or DaVinci Resolve uses the video with your choices already applied,
  so the people you blurred or removed are not in it either.

**Tip:** Set a choice once for every output from the person's row, then change single outputs as needed.
:::

:::requires gallery
## People: your gallery of recurring faces

Click People in the sidebar to see everyone you have named, with their face, their voice, and every
recording they appear in. As with People in Photos, Prakriti uses what it learns from one recording to
recognize the same person in the next.

### Name a person

Only name someone who has agreed to have their face and voice recognized by Prakriti.

1. In the inspector's People tab, under People in This Recording, click an Unnamed person.
2. Click Name This Person and type their name.
3. Select "This person has agreed to be recognized", then click Save.

From then on Prakriti keeps a reference of their face and voice and recognizes them in every recording.
Their face appears in People.

### Correct a mistake

If Prakriti names the wrong person, click the name in the inspector's People tab and choose Not This Person.
If it misses someone you have named, click the Unnamed person and choose their name. When Prakriti is
not sure who someone is, it treats them as Unnamed, so a doubtful face is blurred, never shown.

### Forget a person

Select the person in People, then choose Forget This Person. Prakriti deletes the reference of their face
and voice. Outputs already made are not changed. In recordings made after that, the person is Unnamed.

## What Prakriti stores

- **People you named who agreed:** a reference of their face and of their voice, used to recognize them,
  on this Mac only, until you choose Forget This Person.
- **Everyone else:** nothing is kept. What Prakriti learns about their face and voice is used only while
  it makes that one recording, then deleted, and never compared across recordings.

Face and voice references are never sent to any model or service outside your Mac.
:::

## Good practice with students

- Tell students at the start of every class that it is recorded, what for, and where to sit to stay out
  of frame.
- Repeat students' questions in your own words, so the answer still makes sense without their voice.
- Never publish a student's voice or face unless they have agreed, preferably in writing.
- If a child appears in a recording, keep that recording private.

See [Capture the best video](02-capture-the-best-video.md) for setting up a class.
