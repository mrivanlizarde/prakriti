---
id: reviewing-and-approving
title: Review and approve
summary: Watch the edit in the viewer, check who appears and what is said, change the edit, and approve the finished files.
keywords: [review, approve, viewer, preview, play, watch, transcript, cut, trim, make again, accuracy checklist, ready for your yes, approved folder, receipt]
related: [05-outputs, 07-people-and-privacy, 08-editorial-direction]
---

# Review and approve

Prakriti stops when a recording's outputs are made. Nothing is ready to go out until a person has
watched it, checked it and clicked Approve.

## Open a recording

When a recording is ready, you get a notice such as "Ready for Your Yes: Sun 13 Sep". Click it, or
click Today or Recordings in the sidebar and double-click the recording.

At the top of the page you see its status:

- **Working:** outputs are being made. Each step shows its progress and the time left.
- **Ready for your yes:** everything is made and waiting for you.
- **Needs a decision:** something stopped Prakriti, such as a silent recording. The page says what, and
  what you can do.
- **Approved:** you approved it, and its files are in the Approved folder.

## Watch it in the viewer

The viewer at the top of the page plays any output in the app: the edited video, a short, the podcast
episode or the original recording. Choose which one from the menu above the player.

- Press Space to play or pause.
- Click a line of the transcript to play from that moment.
- Turn captions on or off from the player's controls.
- Under the player, the strip shows each cut, zoom and title. Click one to jump to it.

**Tip:** In the list of made files, select a file and press Space to preview it with Quick Look.

## Check who appears

Under People in This Recording, every face and voice Prakriti found is listed, with what happens to
them in each output: Include, Blur or Remove. Check each one before you approve. Watch the moments
where someone you blurred or removed appears. See [People and privacy](07-people-and-privacy.md).

## Check what is said

- **Listen where Prakriti is least sure.** The page marks moments where the transcript or a person's
  name may be wrong.
- **Read the accuracy checklist** under the titles and notes. Each quote was found word for word in
  the transcript. Each claim still needs a person: check it against the recording, including any year,
  name or number.

## Change the edit

- **Trim the start or end.** Type a time in Episode starts at or Episode ends at, or play to the moment
  and click Use Player Time.
- **Cut a section.** Select lines in the transcript and click Cut Selected Lines, or type the times
  under Cut a section and click Add Cut. To bring a cut back, click Remove beside it.
- **Steer the whole edit with words.** See [Editorial direction](08-editorial-direction.md).
- **Make it again.** Click Make Again. Your changes are used, the files made before are kept until the
  new ones are ready, and the original recording is not changed.

## Approve

Before you can approve:

- Every output you chose is made, and made after your last change.
- Every person in the recording has a choice in every output.
- Every line of each output's checklist passes.

Then click Approve, and confirm. Prakriti copies the finished files to the Approved folder, in a folder
named after the recording, with `APPROVAL.md`: a receipt with the title, the notes, the edits, the
people choices, and each file's size and fingerprint. Nothing is uploaded or posted.

If you change anything and make it again after approving, approve it again. The earlier approved files
stay where they are, marked as approved before the change.

## After you approve

Upload the files yourself, using the Ready to post or Upload checklist beside each one. The checklist
lists the title, description, captions and thumbnail to use.

## See also

- [Outputs](05-outputs.md)
- [People and privacy](07-people-and-privacy.md)
- [Editorial direction](08-editorial-direction.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

- From v1 (`RecordingPage.swift`, `Vocabulary.swift`, `Approval.swift`): statuses, "Episode starts
  at", "Episode ends at", "Use Player Time", "Cut Selected Lines", "Add Cut", "Remove", "Make
  Again…", "Approve…", `APPROVAL.md` with every file's size and SHA-256 ("fingerprint" in user text),
  "Approved before this change".
- **Assumes for v2, confirm each:** the viewer plays video outputs and lets you choose the output
  (Ivan's item 10; v1 has AVKit's audio player with "Episode" and "Original"); a strip of cuts,
  zooms and titles under the player; captions toggle; Quick Look on made files; a "People in This
  Recording" section; "moments where Prakriti is least sure" marked on the page (SCOPE's review
  model: Ivan listens at the low-confidence moments).
- **Approve rules change in v2.** v1 only approves "Talk, one teacher speaking" because speakers are
  not checked. With per-person choices in v2, this article assumes a class can be approved once every
  person has a choice and the checklists pass. That is a real policy change: confirm with Ivan
  before the build lifts v1's rule. Serenity's consent questions (Q-S13 and others in SCOPE) may still
  block classes from public outputs regardless of the app.
- Keyboard: AVKit's player handles Space; J, K and L (Final Cut Pro's shuttle keys) and arrow-key
  frame stepping are recommended for the viewer but not promised here `[unverified in AVPlayerView]`.
- v1 says "a changed copy voids approvals" (SCOPE). "Approve it again" matches that.
