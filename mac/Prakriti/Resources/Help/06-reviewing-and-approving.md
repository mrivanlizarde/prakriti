---
id: reviewing-and-approving
title: Review and approve
summary: Play the recording and its episodes in the viewer, read the transcript, trim and cut, check what is said, and approve the finished files.
section: reviewing
order: 1
keywords: [review, approve, approve sheet, deliverables, upload checklist, upload, youtube, shorts, reels, tiktok, approved a check failed, listen, play, viewer, video, edited video, watch video, captions, take out again, undo, delete, podcast-ready, follow playback, remove from the edit, keep in the edit, restore, find, episode, original, transcript, cut, trim, make again, accuracy checklist, waiting for your yes, needs a decision, needs you, ready, inspector, approved folder, receipt, talk, class, what this is, remove from library]
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
- **Ready** holds what you have approved, while everything you approved still passes its checks.
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
:::requires thumbnails
- **Approved, a check failed:** you approved it, and something it covered no longer passes, such as a
  file in the Approved folder changed or gone. It moves to Needs You, the inspector says what, and you can
  approve it again.
:::

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
:::
:::requires video
- **Video:** the edited video, once it is made. A recording with a video opens on it.
:::
:::requires shorts
- **Shorts:** the shorts, once they are made. The menu beside the control chooses which one plays, such
  as Short 1 of 3. Each plays as its own file, with its words on screen.

**Vertical Guide,** at the top right of the picture on the Original and the Video, shades everything
outside the 9:16 window the shorts are cut from. The window follows the speaker the way the shorts do.
View > Vertical Guide does the same.
:::

:::unless video
Two more choices in that control do not play here yet; choosing one says why.
:::

:::requires video
The last choice in that control does not play here yet; choosing it says why. Video says why too until the
video is made.
:::

:::requires viewer
The player is the Mac's own. Press Space to play or pause. L plays forward, and faster each time you press it again; J
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

:::requires editPlan
On the Original, once the recording has an edit plan, the strip shows the plan instead: what it keeps,
filled in, and what it takes out, outlined with its reason: a pause shortened, a filler word or a word
said twice, a false start, someone you chose to Leave Out, or your trim or a cut. Click a piece to play
from it; the top of the inspector says what it is and why. Under the strip, Prakriti says how much the
plan keeps. See "Edit plan" in [Outputs](05-outputs.md).
:::

:::requires video
## Watch the edited video

Choose **Video** in the toolbar. The viewer draws the video the same way the file was made, from the
same edit plan, with the video's own sound, so what you watch is what you would upload. Clicking a word
in the transcript plays the video from that word; a word the video takes out plays from where the video
carries on after it.

- **The strip** shows the plan the video was made from: what it keeps, filled in, and what it takes
  out, outlined with its reason.
- **The transcript** strikes through every word the video takes out.
- **Captions,** at the top right of the picture, shows the video's captions file over the picture, as
  it will be uploaded with the video. View > Captions does the same.

To change the edit, click a piece of the strip. The top of the inspector says what it is, with one
button:

- **Restore,** on a piece taken out: a pause, a filler word, a word said twice or a false start comes
  back as recorded; your own cut or trim gives its time back.
- **Remove,** on a piece kept: it comes out of the video and the podcast episode, like a cut. Delete
  does the same, and Delete also takes out words selected in the transcript.
- Once changed, the button turns to **Take Out Again** or **Keep**, so a second click undoes the first.
  Edit > Undo (Command-Z) undoes any of them too.
- Time taken out for someone you chose to Leave Out has no Restore here: change their choice in the
  People tab.

A change is not in the video until you make it again: the line under the toolbar says "Not in the
video yet", with Make Again. Approve waits until what you restored is in the video.

If the edit was planned again after the video was made (Plan Again), Video says so and plays once you
make it again, so the viewer never shows an edit that is not in the file.
:::
:::requires style
Under the strip, a row of small symbols shows what the edit adds, where it is in the recording: a
magnifying glass for a punch-in or a slow push-in, Aa for text on screen, a quotation mark
for the opening line (it plays first in the video), and a bookmark for each chapter. With Quick Help on,
pointing at one says what it is.

To watch an earlier version of the video, click Play beside it under Versions in the inspector's
Direction tab. See [Editorial direction](08-editorial-direction.md).
:::

:::unless voices
## Say what it is

Under What this is, choose **Talk, one teacher speaking**, **Class** or **Conversation**. Prakriti does
not yet tell one voice from another, so only a talk with one teacher speaking can be approved. Before
you approve, listen for any other voice, and for any name said aloud.
:::

:::requires voices
## Say what it is, and who is teaching

Under What this is, choose **Talk, one teacher speaking**, **Class** or **Conversation**.
:::
:::requires thumbnails
A talk can always be approved; a class or a conversation once Prakriti has checked who appears and speaks
in it.
:::
:::requires voices
Under **Who is teaching**, choose the teacher, so the People tab can say how much of the recording is theirs.

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
transcript and captions too; Hide Face keeps their voice in the podcast and hides their face in the recording's picture.
To see who is where, choose Original and click People at the top right of the picture. Names Said Aloud lists each name
Prakriti found, kept as said; choose Mute for any you want gone, and it is silenced and written as [name]. Then click Make Again. See
[Privacy and students](07-people-and-privacy.md).
:::

:::requires renderedVideo
In the edited video, Hide Face hides that person's face in every frame and Leave Out cuts their speech from the
picture and the sound. Choose Video in the toolbar to watch it as it will be posted: the faces are hidden there too.
:::

:::requires people
## Check who appears

In the inspector's People tab, In This Recording lists every face and voice Prakriti found, with what
happens to them in each output: Include, Hide Face or Leave Out. Everyone starts on Include. Check each one
before you approve, and watch the moments where someone you hid or left out appears. See
[Privacy and students](07-people-and-privacy.md).
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

- The recording is marked Talk, one teacher speaking, or Prakriti has checked who appears and speaks in it.
- Every trim, cut and choice in the People tab is in the episode: click Make Again after changing them.
- Prakriti's second listen to the episode found no one you left out.
- If you left someone out and the voices were told apart on one mixed track, you listened to the changes of voice.
:::
:::requires people
- Every file you approve passes its own checks, including the check that no one you hid or left out can be
  seen or heard in it.
:::

:::unless thumbnails
Then click Approve, in the toolbar while the recording is open or in the inspector's Outputs, and confirm. Prakriti copies
the finished files to the Approved folder, in a folder
named after the recording, with `APPROVAL.md`: a receipt with the title, the notes, the edits, and
each file's size and fingerprint. Nothing is uploaded or posted.
:::
:::requires thumbnails
Then click Approve, in the toolbar while the recording is open, in the inspector's Outputs, or choose
Recording > Approve (Command-Shift-Return). The Approve sheet lists everything that can be approved: the
episode, the edited video, the thumbnails, each short, the transcript and the report, each with a box.
Everything that passes its checks is ticked. Anything that fails is unticked and cannot be ticked, with the
check that fails named, such as "Short 2 is 190 s; the limit is 180 s." Untick anything you do not want.
The sheet also shows the video's version, a line for each person and what happens to them, and where
each step that used a model ran.

Click Approve. Prakriti copies what is ticked to the Approved folder, in a folder named after the
recording, without taking extra space on this Mac, with `APPROVAL.md`: a receipt with the title, the notes,
the edits, the version, what was approved and what was not and why, each person's choice, the names said
aloud (a name you muted is only counted, never written), and each file's size and fingerprint. Nothing is
uploaded or posted.

A class or a conversation can be approved once Prakriti has checked who appears and speaks in it.
:::
:::requires style
When the recording has an edited video, Approve covers the version in use: the question says which
("Version 2, made Thu 15 Oct 2026 at 9:41 pm. Clear, the house style."), and so does the receipt. To approve another version, click Use
This Version beside it in the Direction tab first.
:::

If you change anything after approving, such as the title, the notes, a trim or a cut, the approval is
taken back and the inspector says "Approved before this change". Approve it again once it is right. The
approved files stay as they were until you do.

## After you approve

The recording moves to Ready. Upload the files yourself.

:::requires thumbnails
In the inspector's Outputs, the Upload Checklist shows what YouTube, YouTube Shorts, Instagram Reels and
TikTok each ask for, in the order their upload form asks: Copy beside each piece of text, Show in Finder
beside each file, and PASS, MISSING or FAIL for each. A few answers are yours to give in the platform
itself, such as whether a video is made for kids. The rules for Reels and TikTok come from guides
written by others, not from Instagram or TikTok, and the lines say so.
:::

For the podcast-ready episode, the Ready to upload section, in the inspector's Outputs, has the upload checklist and a
Copy button for each piece of text the podcast host asks for. See [Outputs](05-outputs.md).

:::requires renderedVideo
When the recording has an edited video, Approve copies its Video folder too: the video, its captions,
`Description.txt` and `Ready checklist.txt`. Before you upload it, read its Ready checklist, under
Edited video in the inspector's Outputs or in the file: upload only when every line passes, or when the
lines left are the ones you are about to fill in on YouTube.
:::

## Remove a recording from the library

Control-click it and choose Remove from Library, then confirm. Prakriti forgets it and moves its files
in Outputs to the Trash. The original recording and anything in the Approved folder are not touched,
and its folder does not bring it back as new. To bring it back, choose File > Add File and choose it.
