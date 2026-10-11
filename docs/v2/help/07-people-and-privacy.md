---
id: people-and-privacy
title: People and privacy
summary: How Prakriti finds faces and voices, how you choose who appears in each output, and what it stores.
keywords: [people, faces, voices, privacy, students, blur, remove, include, gallery, name a person, agreed, consent, unnamed, face print, voice print, biometric, forget, children, Zoom]
related: [02-capture-the-best-video, 06-reviewing-and-approving, 09-models-and-api-keys]
---

# People and privacy

Teachers choose to appear in what is published. Students usually have not. Prakriti finds every face
and voice in a recording so you decide, person by person, who appears in what goes out.

## What Prakriti looks for

In every recording, Prakriti looks for faces in the picture and voices in the sound, on this Mac.

- **People you have named** in People, who have agreed to be recognized, are shown by name.
- **Everyone else** is shown as Unnamed. Prakriti can tell them apart within one recording, but never
  remembers them from one recording to the next.

## See who is in a recording

In Recordings, each recording shows who was found: the names of the people you have named, and how
many other people appear or speak, such as "Gabriel, Serenity and 3 other people". Choose View > Show
Recordings With Other People to see only those.

On a recording's page, People in This Recording lists each person with a picture of their face, when
they appear, and when they speak.

## Choose who appears in each output

For each person, in each output, choose one:

| Choice | In video | In sound |
|---|---|---|
| **Include** | Seen as recorded | Heard as recorded |
| **Blur** | Face blurred wherever it appears | Their speech is taken out |
| **Remove** | The moments they appear in are cut | The moments they speak in are cut |

- People you have named and who have agreed start as **Include**.
- Everyone else starts as **Blur**: face blurred and speech taken out. Change it only when that person
  has agreed to appear.
- For sound-only outputs, such as the podcast episode, Blur and Remove both take out the person's
  speech.
- Thumbnails only ever show people who have agreed.
- The timeline for Final Cut Pro or DaVinci Resolve uses the video with your choices already applied,
  so the people you blurred or removed are not in it either.

**Tip:** Set a choice once for every output from the person's row, then change single outputs as
needed.

## People: your gallery of recurring faces

Click People in the sidebar to see everyone you have named, with their face, their voice, and every
recording they appear in. As with People in Photos, Prakriti uses what it learns from one recording to
recognize the same person in the next.

### Name a person

Only name someone who has agreed to have their face and voice recognized by Prakriti.

1. On a recording's page, under People in This Recording, click an Unnamed person.
2. Click Name This Person and type their name.
3. Select "This person has agreed to be recognized", then click Save.

From then on Prakriti keeps a reference of their face and voice and recognizes them in every
recording, including the ones you have already made. Their face appears in People.

### Correct a mistake

If Prakriti names the wrong person, click the name on the recording's page and choose Not This Person.
If it misses someone you have named, click the Unnamed person and choose their name. When Prakriti is
not sure who someone is, it treats them as Unnamed, so a doubtful face is blurred, never shown.

### Forget a person

Select the person in People, then choose Forget This Person. Prakriti deletes the reference of their
face and voice. Outputs already made are not changed. In recordings made after that, the person is
Unnamed.

## What Prakriti stores

| Who | What is kept | Where | For how long |
|---|---|---|---|
| People you named who agreed | A reference of their face and of their voice, used to recognize them | On this Mac only | Until you choose Forget This Person |
| Everyone else | Nothing kept. What Prakriti learns about their face and voice is used only while it makes that one recording | Only while that recording is being made, then deleted | Never compared across recordings |

The original recording, and the transcript Prakriti makes from it, still contain everyone as they were
recorded. They stay on this Mac, in your folders, and are never uploaded. Face and voice references
are never sent to any model or service outside your Mac.

## Classes and the models outside your Mac

A class, or any recording where someone other than the people you named appears or speaks, is only
read by models on this Mac. Even if you have added an OpenAI or Anthropic key, that recording's text
is not sent to them. See [Models and API keys](09-models-and-api-keys.md).

## Good practice with students

- Tell students at the start of every class that it is recorded, what for, and where to sit to stay
  out of frame.
- Repeat students' questions in your own words, so the answer still makes sense without their voice.
- Never change a student to Include unless they have agreed, preferably in writing.
- If a child appears in a recording, keep that recording private.

See [Capture the best video](02-capture-the-best-video.md) for setting up a class.

## See also

- [Review and approve](06-reviewing-and-approving.md)
- [Models and API keys](09-models-and-api-keys.md)
- [Outputs](05-outputs.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

### Decisions this article follows (REQUEST.md)

- Students are the privacy subject; Gabriel and Serenity may appear. Every other face or voice is
  flagged. Per person in each output: Include / Blur (faces) / Remove (their segments). Default for
  unnamed people: Blur faces and Remove their speech.
- Face and voice prints stored only for people Ivan names and marks "has agreed". Unnamed people's
  prints live only for the job, then are deleted; the gallery shows them as "Unnamed, this recording
  only".
- Privacy lock relaxed: classes and recordings where other people appear or speak still stay local.

### Ambiguities resolved here, to confirm

- **What "Blur" does to sound.** REQUEST.md lists Blur as a face choice and gives the unnamed default
  as "Blur faces and Remove their speech". This article makes Blur mean exactly that default (face
  blurred, speech taken out), so the default is one choice, and Remove cut whole moments. If the
  build separates face and voice choices, rewrite the table as two columns of choices.
- **Recognizing people in past recordings** after naming them ("including the ones you have already
  made") assumes v2 re-scans stored recordings using the new reference. Under the biometric rule it may
  only use the new person's reference, never stored prints of others. If the build does not re-scan,
  cut that clause.
- **"Choose View > Show Recordings With Other People"**: a filter Ivan asked for implicitly ("let me
  know when it includes other people"). Rename to match the build.
- **Children:** from research/08 P10 (minors excluded without a parent's release), not in REQUEST.md.

### Why the storage table matters

Stored face or voice prints of students are what the BIPA and Colorado biometric suits target
(research/08 §3.4: the Otter.ai ruling of 13 Aug 2026 let claims proceed on a tool that recognizes
"the same person in later conversations"). research/08 P9 also says per-job embeddings should never
be written to disk; this article says "used only while it makes that one recording" which is true
under either design. A written biometric notice and release for the teachers (research/08 F4) is
still owed; the "has agreed" checkbox records consent, it does not create it.

### Honesty points

- The transcript (`transcript.json`, Parakeet's words as heard, never changed) keeps students'
  words on this Mac. The help says so rather than implying Prakriti erases them.
- "Never uploaded" holds for v1 and v2 (Prakriti never uploads). If the web app's R2 sync from SCOPE
  ships, revisit this line.
