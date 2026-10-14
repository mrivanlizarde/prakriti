# Builder notes: 07-people-and-privacy.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/07-people-and-privacy.md` ("Privacy and students").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M7a (Tue 13 Oct 2026)

- The `gallery` block was rewritten to what M7a builds: People in the sidebar, Name This Person (Name Only by default),
  Record Release (kept with the name, nothing learned), the person page, Forget Face and Voice, retention, and what is
  stored. The old text (recognizing named people, Not This Person, "From then on Prakriti keeps a reference") moved to a
  new `recognition` block, hidden until part M7b builds it.
- Button names match the build: **Name This Person…**, **Name Only**, **Record Release**, **Rename…**, **Change Key
  Photo…**, **More**, **Hide from People**, **Forget Face and Voice…**. The plan's "Learn [Name]" button is not used,
  because nothing is learned in M7a; M7b renames it if it wants.

## Status after v2 part M3a (Sun 11 Oct 2026)

- Only a hidden `people` block changed: "In Recordings" became "In the browser" (v1's Recordings screen is gone).

## Status after v2 part M2a (Sun 11 Oct 2026)

- Title is **"Privacy and students"** until faces and voices exist (`people`, M6), because there is no People
  feature yet; the id `people-and-privacy` stays. M6 renames it.
- Visible: what stays on this Mac, the v1 privacy lock, classes and other voices (`:::unless people`), good
  practice. Gated: faces and voices and the three choices (`people`), the gallery, naming, forgetting and
  what is stored (`gallery`).
- The hidden choices already use section 5's defaults: **Include**, **Blur Face**, **Remove**, unnamed people
  starting as Remove. The old Blur meaning (face and speech) is gone. Tables are lists.

## Notes from the help track (Sat 10 Oct 2026)

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

## Built in v2 part M5a (Mon 12 Oct 2026)

- The privacy lock is `PrivacyLock` (mac/Prakriti/Writing/PrivacyLock.swift). A cloud model reads only a talk whose
  people check ran, with no one unnamed and everyone heard named and agreed (`Person.mayReadInCloud`, off by
  default), and whose transcript does not name Serenity. The people check is part M6, so every real recording is
  locked today ("Who appears and speaks in it has not been checked, so only models on this Mac read it.").
- Every cloud request goes through `PrivacyLock.release`: names Apple's tagger finds are replaced by [[NAME-n]] and
  put back in the answer; muted names, named people who have not agreed and Serenity are always replaced (the tagger
  missed "Serenity" in the writing prompt when measured); the text is read again and refused if a name is left.
- Settings, Models has "This Mac": the chip, memory and verdict ("Apple M5 Pro, 64 GB. This Mac can run the writing
  model."), and Apple Intelligence's state. The welcome panel 5 line is part M5b's.
- Not built: OpenAI, Anthropic's current request shape, model lists from each provider (M5b); the people check (M6).

## Built in v2 part M6a (Mon 12 Oct 2026)

- New capability `faces` (Help/Capabilities.swift), separate from `people`: the article's "Faces in a recording"
  section and the lock paragraph's second sentence are `:::requires faces` blocks. `people` (voices, Include, Blur
  Face, Remove) is still off, so "What Prakriti looks for" and the choices stay hidden.
- What the article says is built: the face step in every make, boxes and times kept, the people line ("One person at
  a time." / "Other people appear, up to 2 at once."), Sort > Other People Appear, the People tab with Unnamed rows and
  live crops never saved, the one notice, Look for Faces for older recordings.
- `HelpTests.unbuiltNames`: "People" and "Unnamed" (case sensitive), "Other People Appear" and "Look for Faces" now
  belong to `faces`; "Blur Face" and the print words stay with `people`.
- Not built: voices, names, Who Is Teaching (M6b); choices and removing speech (M6c); hiding faces (M6d).
