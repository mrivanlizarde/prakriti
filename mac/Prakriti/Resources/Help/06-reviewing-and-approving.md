---
id: reviewing-and-approving
title: Review and approve
summary: Play the recording and its episodes in the viewer, read the transcript, trim and cut, check what is said, and approve the finished files.
section: reviewing
order: 1
keywords: [review, approve, listen, play, viewer, podcast-ready, follow playback, remove from the edit, keep in the edit, restore, find, episode, original, transcript, cut, trim, make again, accuracy checklist, waiting for your yes, needs a decision, needs you, ready, inspector, approved folder, receipt, talk, class, what this is, remove from library]
related: [outputs, people-and-privacy, models-and-api-keys]
---

# Review and approve

Prakriti stops when a recording's outputs are made. Nothing is ready to go out until a person has
listened to it, checked it and clicked Approve.

## Find and open a recording

When a recording is ready, you get a notice such as "Waiting for Your Yes: Sun 13 Sep". Click it to open
the recording. Or click **Needs You** in the sidebar: it holds every recording waiting for your yes,
needing a decision or that could not finish. [Show Me](prakriti://show/group/needs-you)

- **In Progress** holds what is being made, waiting its turn, or found and not made yet.
- **Ready** holds what you have approved.
- **All Recordings** holds everything, by the month it was recorded. Each folder under Sources holds
  its own.

Choose View > as Grid (Command-1) or View > as List (Command-2). The Sort menu in the toolbar sorts by
date recorded, date found, length or title, and shows only the kinds you choose. Type in the search field
to find a recording by its title, its notes or what was said in it: a sentence that matches shows under
the recording, with its time, and clicking it opens the recording there.

Click a recording to select it: the inspector, on the right, shows it (View > Show Inspector,
Command-Option-I). Double-click it, or press Return, to open it in the viewer. Click Back, or press
Escape, to return.

Its status is shown in symbol and words:

- **Working:** outputs are being made. The inspector shows the step it is on.
- **Waiting for your yes:** everything is made and waiting for you.
- **Needs a decision:** something stopped Prakriti, such as a silent recording. The inspector says what,
  and what you can do.
- **Couldn't finish:** a step stopped. The inspector says which, and Try Again starts it again.
- **Approved:** you approved it, and its files are in the Approved folder.

:::unless viewer
## Listen to it

Under Listen, choose **Episode** to hear the episode as made, or **Original** to hear the recording as
it was recorded. The player is the Mac's own.

- Click a line of the transcript to play from that moment.
- Control-click a line for Play From Here and Cut This Line.
:::

:::requires viewer
## Watch and listen in the viewer

The viewer takes the place of the library while a recording is open. Choose what plays in the toolbar:

- **Original:** the recording as it was recorded, picture and sound.
- **Podcast:** the episode as made.
- **Podcast-ready:** the podcast-ready episode, once it is made.

Two more choices in that control are not made by Prakriti yet; choosing one says so. The player is
the Mac's own. Press Space to play or pause. L plays forward, and faster each time you press it again; J
plays backward where the file allows it; K stops. They are in the Playback menu too.

Under the player:

- **The strip** shows what the episode keeps, filled in, and what the trim and cuts take out, outlined
  with scissors. A thin line marks the moment playing. Click a piece to play from it. A piece that is
  taken out also shows at the top of the inspector, with Restore.
- **The transcript,** in paragraphs under their times. Click a word to play from it. With View > Follow
  Playback on, the sentence playing is marked and kept in view. Words taken out are struck through.
  Edit > Find in Transcript (Command-F) finds a word.

The first time, a tip under the strip says how to use the transcript; click Got It to hide it. To see
what any control does, choose Help > Show Quick Help: the top of the inspector says what the control
under the pointer does, with a link to more in Help.
:::

:::unless voices
## Say what it is

Under What this is, choose **Talk, one teacher speaking**, **Class** or **Conversation**. Prakriti does
not yet tell one voice from another, so only a talk with one teacher speaking can be approved. Before
you approve, listen for any other voice, and for any name said aloud.
:::

:::requires voices
## Say what it is, and who is teaching

Under What this is, choose **Talk, one teacher speaking**, **Class** or **Conversation**. Only a talk with
one teacher speaking can be approved. Under **Who is teaching**, choose the teacher, so the People tab can say
how much of the recording is theirs.

:::

:::unless choices
Prakriti lists every voice it hears in the People tab, but nothing it finds is left out of the episode yet.
Before you approve, listen to every other voice listed there, and for any name said aloud. When the voices were
told apart on one mixed track, the People tab lists each change of voice: listen to those too.
:::

:::requires choices
## Choose who is in the episode

In the People tab, every face and voice Prakriti found has a choice: Include, Hide Face or Leave Out. Everyone starts
as Include. Leave Out cuts every stretch that person speaks from the podcast episodes, their words from the
transcript and captions too; Hide Face changes nothing in the podcast. Under Names Said Aloud, choose Keep or Mute for
each name Prakriti found; a muted name is silenced and written as [name]. Then click Make Again. See
[Privacy and students](07-people-and-privacy.md).
:::

:::requires people
## Check who appears

Under People in This Recording, every face and voice Prakriti found is listed, with what happens to
them in each output: Include, Blur Face or Remove. Check each one before you approve. Watch the moments
where someone you blurred or removed appears. See [Privacy and students](07-people-and-privacy.md).

Prakriti marks the moments where the transcript or a person's name may be wrong. Listen to them.
:::

## Check what is said

Read the accuracy checklist in the inspector's Checks, when the titles and notes are written. Each quote
was found word for word in the transcript. Each claim still needs a person: check it against the
recording, including any year, name or number, then tick its box. The ticks are your own record; they
change no file.

## Change the episode

- **Trim the start or end.** In the inspector's Info, type a time in Episode starts at or Episode ends
  at, such as 4:12 or 1:02:30, or play to the moment in the viewer and click Use Player Time.
- **Take words out.** Select words in the transcript (drag across them, or Shift-click), then click
  Remove from the Edit under the transcript, or Control-click and choose it, or choose Edit > Remove from
  the Edit. Or, in the inspector's Info, type two times under Cut a section and click Add Cut.
- **Bring words back.** Select them and choose Keep in the Edit. To bring a whole cut back, click
  Restore beside it in the inspector's Info, or click it in the strip and click Restore. Clear Trim and
  Cuts takes them all away.
:::requires style
- **Steer the whole edit with words.** See [Editorial direction](08-editorial-direction.md).
:::
- **Make it again.** Click Make Again. Your changes are used, the files made before are kept until the
  new ones are ready, and the original recording is not changed.

Times are always from the start of the original recording, as the transcript shows them. Until you
make it again, the viewer says the changes are not in the episode yet.

## Approve

:::unless choices
Before you can approve:

- The recording is marked Talk, one teacher speaking.
- Every trim and cut is in the episode: click Make Again after changing them.
:::
:::requires choices
Before you can approve:

- The recording is marked Talk, one teacher speaking.
- Every trim, cut and choice in the People tab is in the episode: click Make Again after changing them.
- Every name said aloud is kept or muted.
- Prakriti's second listen to the episode found no one you left out.
- If you left someone out and the voices were told apart on one mixed track, you listened to the changes of voice.
:::
:::requires people
Before you can approve:

- Every output you chose is made, and made after your last change.
- Every person in the recording has a choice in every output.
- Every line of each output's checklist passes.
:::

Then click Approve, in the toolbar while the recording is open or in the inspector's Outputs, and confirm. Prakriti copies
the finished files to the Approved folder, in a folder
named after the recording, with `APPROVAL.md`: a receipt with the title, the notes, the edits, and
each file's size and fingerprint. Nothing is uploaded or posted.

If you change anything after approving, such as the title, the notes, a trim or a cut, the approval is
taken back and the inspector says "Approved before this change". Approve it again once it is right. The
approved files stay as they were until you do.

## After you approve

The recording moves to Ready. Upload the files yourself. For the podcast-ready episode, the Ready to
upload section, in the inspector's Outputs, has the upload checklist and a
Copy button for each piece of text the podcast host asks for. See [Outputs](05-outputs.md).

## Remove a recording from the library

Control-click it and choose Remove from Library, then confirm. Prakriti forgets it and moves its files
in Outputs to the Trash. The original recording and anything in the Approved folder are not touched,
and its folder does not bring it back as new. To bring it back, choose File > Add File and choose it.
