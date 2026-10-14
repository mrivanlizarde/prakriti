---
id: people-and-privacy
title: Privacy and students
summary: What stays on this Mac, which recordings only models on this Mac may read, and how to protect students in a class.
section: people
order: 1
keywords: [recognition, recognize, review possible matches, merge, privacy, students, class, privacy lock, Serenity, local, cloud, Anthropic, OpenAI, Claude API, transcript, approve, cut, notifications, names, children, consent, voices, teacher, microphone, include, leave out, hide face, mute, names said aloud, people, gallery, release, forget, key photo, name only]
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

:::unless voices
Prakriti does not check who appears and speaks yet, so for now every recording is only read on this Mac.
:::

:::requires voices
Prakriti checks who appears and who speaks in every recording it makes, and every face and voice you have not
named counts as someone else. So a recording is only read on this Mac until you name the teacher, and stays that
way while anyone else appears or speaks in it. A teacher's words go to a cloud model only once you have turned on
"Cloud models may read their words" for them in Settings, Privacy.
:::

LM Studio does that task instead, and the inspector's Checks tab says why. Names are replaced before anything
is sent. See [Models and API keys](09-models-and-api-keys.md).

:::requires faces
## Faces in a recording

While it makes a recording's outputs, Prakriti looks for faces in the picture, two frames a second, on this
Mac. It keeps only when and where each face was seen: never a picture of anyone's face. Only a person whose recorded
release covers their face is recognized in another recording (see Recognition, below).

- **In the browser,** each recording shows a line such as "One person at a time." or "Other people appear, up
  to 2 at once." To see only the recordings with other people, click Sort in the toolbar and choose Other
  People Appear.
- **In the inspector's People tab,** a sentence says what was found, then one row for each face, Unnamed 1,
  Unnamed 2 and so on, with how long it is on screen. The face in each row is taken from the recording while
  the tab is open, and is never saved.
- **A notice** says "Other people appear in this recording. Everyone is in the episode until you choose otherwise."
  the first time two or more faces are seen at once. Like every notice, it never names the recording or anyone in it.

Finding someone changes nothing that is made. Only your choices do (see Choose who is in the episode, below). A row is
a face seen in one place in the picture, so one person who walks around can show as two rows; "up to 2 at once" is
the number to go by.
:::

:::requires voices
## Voices, and naming who is who

Right after the faces, Prakriti listens for who speaks when, on this Mac.

- **With each microphone on its own track** (see [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md)),
  who speaks is read from tracks 2 and up: a microphone track is someone speaking when it is clearly louder than
  the sound of the same voice reaching the other microphones.
- **With one mixed track,** voices are told apart by how they sound. That is a best guess, so the People tab lists
  each change from one voice to another as a moment worth listening to.
- **Each voice is linked to a face** when it speaks while that face is the only one on screen, or while that
  face's mouth moves with it. When Prakriti is not sure, the voice is shown on its own, with no face.

Prakriti does not know who anyone is. You tell it, one recording at a time:

1. In Settings, Privacy, under People You Name, add the names of the teachers who appear in your recordings.
2. In the inspector's Info tab, choose the teacher under **Who is teaching**. The voice that speaks the most, and
   its face, take that name, and the People tab says, for example, "Gabriel speaks for 92 percent."
3. Anyone else: in the People tab, click **Name for This Recording** under their face or voice. A name given to a
   face also reaches the voice linked to it.
4. For a microphone that always belongs to the same person, click **Track 2 in This Folder** under that voice, and
   choose them: every recording from that folder heard on that track takes the name.

Only times are kept: when each face is seen and when each voice speaks. Never a picture of a face and never a print
of a voice, except what Prakriti learns of a person whose recorded release covers their face (see Recognition). A name
is kept as a name.

A recording found before Prakriti checked who appears and speaks shows **Check People** in its People tab.
:::

:::requires choices
## Choose who is in the episode

Everyone found in a recording starts as **Include**: the participants have signed releases, so nobody is taken out
until you choose. Under each face and voice in the People tab, choose one:

- **Include:** heard as recorded.
- **Hide Face:** heard as recorded, so the podcast does not change. Their face is hidden in the recording's
  picture in the browser.
- **Leave Out:** every stretch they speak is cut from the podcast episode and the podcast-ready episode, with the
  pause around it, so no syllable is left. The cut stops a little before the next word someone included says, so that
  word stays whole. Their words leave the transcript and the captions too.

A voice with no face can be Include or Leave Out. A choice for a named person, such as Gabriel, covers every row with
their name. Under the list, **Set All Unnamed To** sets everyone you have not named at once.

The line under each choice says what it does, for example "Leaving out Voice 2 takes 22 s out of the podcast."
**Play Their Moments** plays from where that person first speaks; click Play the Next Moment for each one after it. Every choice can be undone
with Edit > Undo.

Your choices are used the next time the recording is made: until you click Make Again, the People tab and the Viewer
say they are not in the episode yet, and Approve waits.

**When two people speak at once,** and one of them is left out, the whole stretch is cut, so the person you included
loses those words too. The People tab lists each of those stretches, under In the Episode, to listen to.

**After the episode is made,** Prakriti listens to it again on this Mac. If anyone it hears sounds like a person you
left out, the People tab says when, such as "Speech at 0:31 in episode.mp3 sounds like Voice 2, whom you chose to leave
out.", and Approve waits until it is made again. When the voices were told apart on one mixed track and you left
someone out, listen to the changes of voice listed there, then select I listened to the changes of voice.

:::

:::requires hiding
## Pictures of a recording

Once Prakriti has looked for faces, a recording's card in the browser shows a frame from it instead of its date. The
frame is chosen so that everyone in it is someone you included. When no such frame can be found, the face of everyone
you chose Hide Face or Leave Out for is hidden in the frame, under a heavy blur and large blocks. Before a frame is kept, Prakriti looks for
faces in it again, and any face that is not someone you included means the frame is not used. If no frame passes, the
card keeps its date.

When you change a choice or a name, the card's picture is removed at once and chosen again. The card picture is the
only picture Prakriti keeps. It is kept on this Mac, never in a folder Prakriti watches.

## See who is where

Open a recording, choose Original in the toolbar, and click **People** at the top right of the picture (or choose
View > People). Each face gets a box with its name, or Unnamed. A face you chose to hide has a dashed box, and its label
says the choice, such as "Unnamed 2, Hide Face". The Original always plays as recorded: the boxes show who is where, they
hide nothing.
:::

:::requires choices
## Names said aloud

Prakriti looks for people's names in the transcript, other than the people you named in Settings, Privacy. Each name
is listed in the People tab under Names Said Aloud, with the times it is said and Play. For each one, choose:

- **Keep:** left as it is.
- **Mute:** silenced in the podcast episode and the podcast-ready episode, and written as [name] in the transcript,
  the captions and what the writing model reads.

Approve waits until every name is kept or muted. Prakriti can miss a name, so listen too.

## Classes

- Only a recording marked **Talk, one teacher speaking** can be approved. A class or a conversation shows "Speakers
  not checked" and cannot be approved.
- A class is never made ready to upload as a podcast episode.
:::

:::unless choices
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
- **Hide Face:** heard as recorded, with their face blurred wherever it appears.
- **Leave Out:** their speech is cut, and their face is blurred wherever it still shows.

Everyone starts as **Include**, because the participants have signed releases.

- Thumbnails only ever show people you included.
- The timeline for Final Cut Pro or DaVinci Resolve uses the video with your choices already applied,
  so the people you blurred or removed are not in it either.

**Tip:** Set a choice once for every output from the person's row, then change single outputs as needed.
:::

:::requires gallery
## People: everyone you name

Click **People** in the sidebar to see everyone you have named, each as a round picture with their name and how many
recordings they are in. It is built like People in Photos. Each person is there because you named them, in a recording
or in Settings, Privacy, and Prakriti finds a person in new recordings by itself only once you have recorded a written
release that covers their face (see Recognition, below).

- **The picture** is a frame of their face from one of their recordings, taken from the recording each time People
  shows it and never saved. For someone who should not be shown, turn off Can Appear in What Is Published: People
  shows their initials instead.
- **Favorites** come first. Sort **By Name** or in **Custom Order**: in Custom Order, drag a person onto another to put
  them in that place.
- **Unnamed people** is one tile with no face. It lists the recordings with someone you have not named. Prakriti does
  not remember people who are not named; each recording shows its own, in the inspector's People tab.

### Name a person

1. In the inspector's People tab, open the menu under a face or a voice and choose **Name This Person**.
2. Type their name. If they are already in People, click their name under it: the face or voice joins that person.
3. Choose their role, and whether they can appear in what is published.
4. Click **Name Only**. Prakriti keeps the name, and nothing about their face or voice.

### Record a written release

If the person has signed a written release, record it with their name: in Name This Person, or with **Record Release**
on their page, turn on A written release is signed, then fill in the date it was signed, where the signed release is
kept, and whether it covers their face, their voice or both. When it covers their face, the button says **Learn** and
their name: click it, and Prakriti learns their face from the recordings where they are named (see Recognition). A
release that covers only their voice is kept with the name: voices are not learned yet.

### A person's page

Click a person to see their page: their picture, whether a release is on file and whether Prakriti recognizes them,
whether they can appear in what is published, and three figures, how many recordings they are in, their minutes on
screen and their minutes speaking, counted from where they are named. Their recordings are listed under it, as in the
browser.

- **Rename** changes only the name, everywhere it is shown.
- **Change Key Photo** shows each face named for them; click the one to use, or Automatic for the face on screen the
  longest.
- **More** has Favorite, Pin to Sidebar (a pinned person is listed under People in the sidebar), Can Appear in What Is
  Published, **Hide from People**, which only takes them off the grid and the sidebar, and Merge With.

### Forget Face and Voice

For a person with a release on file, More has **Forget Face and Voice**. It destroys the key that locks what Prakriti
learned of their face, checks that nothing of theirs can be opened, deletes it, and builds Prakriti's face index again
from everyone else. Then it checks that one of their old pictures no longer matches anyone. Their name stays on
recordings already checked, and Prakriti stops recognizing them. Removing a name in Settings, Privacy does the same first.

Anything Prakriti keeps of a person's face or voice is deleted 12 months after they last appeared in a recording. Needs
You says so 30 days before.

## What Prakriti stores

- **People you name:** the name, their role, whether they can appear, and the release you recorded, on this Mac only.
- **Faces of people with a release that covers their face:** up to 50 small pictures of their face, cut from the
  recordings where they are named, each locked with a key of their own that only this Mac's keychain holds, and the face
  index Prakriti builds from them. Nothing else of anyone's face, and no print of anyone's voice.
- **Everyone else:** nothing. A face on a person's picture or on the People tab is taken from the recording while it is
  shown and never saved. Pictures Prakriti looks at to recognize people are deleted as soon as it is done.
- **The People folder** in Prakriti's Application Support folder is left out of Time Machine backups, so nothing in it
  outlives a Forget in an old backup.
:::

:::requires recognition
## Recognition

Prakriti recognizes the people whose recorded release covers their face, in each recording it makes or checks after
that. It learns each of them from up to 50 pictures of their face, cut from the recordings where you named them.

After the faces and voices of a recording are found, Prakriti looks at a few frames of every face row and compares them
with the people it has learned, on this Mac. A face is named by Prakriti only when at least 3 frames are looked at,
most of them match the same person, none matches anyone else, and any voice linked to the face is not named as someone
else. Otherwise:

- **Not sure:** the row says "Is this Gabriel?" with **Yes** and **Not Gabriel**, and until you answer, the face counts
  as not named.
- **No match:** the face stays Unnamed.

Your own names always come first: a face you named, or the teacher you chose, is never renamed by Prakriti.

- **If Prakriti names the wrong person,** click **Not** and the name under the face in the inspector's People tab. The
  face goes back to not named, and any picture Prakriti learned from it is deleted.
- **Review Possible Matches** on a person's page shows every face Prakriti was unsure about, one at a time, recordings
  waiting for your yes first. **Yes** names the face and teaches Prakriti a little more of that person's face; **Not**
  and the name says it is someone else.
- **Merge 2 People:** when one person was named twice, Command-click both in People, then Control-click one and choose
  Merge 2 People, or choose More, Merge With on a person's page. Choose which name to keep. Both need a recorded
  release. Every recording that names either takes the kept name, and where the two had different choices the stricter
  one is kept.

Voices are not learned in this version: a voice is named by you, by Who is teaching, or by a folder's microphone track.
:::

## Good practice with students

- Tell students at the start of every class that it is recorded, what for, and where to sit to stay out
  of frame.
- Repeat students' questions in your own words, so the answer still makes sense without their voice.
- Never publish a student's voice or face unless they have agreed, preferably in writing.
- If a child appears in a recording, keep that recording private.

See [Capture the best video](02-capture-the-best-video.md) for setting up a class.
