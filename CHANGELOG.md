# Changelog

Newest first. One entry per working session. The diff records what changed; this file records
why. Weekdays computed with `date(1)`.

---

## 2026-10-13, Tue: v2 part M6d fix, the overlay in the snapshots, and no job folder left behind

- **The Viewer's snapshots now draw the picture and what sits over it.** Why: the verifier looked at
  `20-viewer-people` and found a picture with no box, label or People toggle, though the build report said it showed
  both boxes. Measured: the picture area of every Viewer snapshot was fully transparent (19,475 of 19,475 samples), so
  it looked black in a dark viewer. Once SwiftUI hosts the player, the canvas under it and the overlay over it are loose
  layers that a bitmap capture skips; the renderer now draws them in order. A report that says a picture shows something
  must come from looking at that picture; `SnapshotTests` now measures it too.
- **Both kinds of box are seen, in a snapshot and in the real window.** Why: the dashed Hide Face box had never been
  looked at anywhere, because the window capture seeded no hidden face. One fixture (`Fixtures.showPeopleOverlay`) now
  feeds both.
- **A card picture's job folder is made only when the picture is staged.** Why: `make accept` ended while a card
  picture was still being chosen in the background, and the job folder made at the start of that work was left empty,
  failing all 4 people acceptance tests on the next run. The milestone 2 acceptance also waits for its card pictures now.
  The face step keeps its folder for the whole scan, because the crash check depends on killing it mid-scan.

## 2026-10-13, Tue: v2 part M6d, hiding in pictures

- **A recording's card shows a real frame once its faces are known, and never a face Ivan chose to hide.** Why: REQUEST
  items 3b and 11 (choose who is included; browse by picture like Photos), and Ivan's 12 Oct rule that faces of anyone
  not Included are never in a thumbnail. The frame is chosen after the people pass: first one where everyone seen is
  included (a named person first, the sharpest by Vision's capture quality), else one with every other face hidden, else
  none (the plain tile). Every candidate is checked by Vision before it is kept: a face inside a hidden region, or one the
  people pass never saw, refuses it. Fail closed, because a face the pass missed is a face nobody decided about.
- **`FaceHide` and `FaceFollower`, the hiding the video will use (M8d).** Padded 1.6 times, a soft ellipse, a blur of 30%
  of the face's width, then pixelated 5 blocks across the face; held 0.5 s before and after each sighting; followed at
  the full frame rate by Vision's tracker between the two-a-second sightings. Why: research-people.md 3.2 and plan review
  item 12, a held box loses a moving face. Measured on a moving test square: the followed box overlapped the square 0.84
  to 0.91, the held box alone 0.14 to 0.60.
- **A change of choice or name deletes the card picture at once, then chooses again in the background, one at a time
  per recording.** Why: a picture made under older choices must never stay on screen, and an older make finishing late
  must never overwrite a newer one.
- **Set All Unnamed To now covers the faces seen for under a second.** Why: otherwise their faces would stay in pictures
  after Ivan hid everyone not named.
- **The Viewer's People overlay** (on the Original, toggle at the top right or View > People): a box and a name per
  face, dashed with the choice in words for anyone hidden. Why: design spec 3.4.1 and Q3; Ivan sees who is where in his
  own app. Found by looking at the real window: accent text on clear glass over a bright picture could not be read, so
  the toggle is white on darkened glass and on or off shows in the symbol's fill.
- **New Help capability `hiding`, separate from `people`.** Why: the `people` blocks describe hiding in every output,
  the video and timelines, which are not built; Help says only what the app does.

---

## 2026-10-13, Tue: v2 part M6c, fixes after the verifier

- **A Leave Out cut no longer ends inside the next word someone included says.** Why: the verifier found check 4 failing
  (97.7% of Gabriel's words kept on two-people-tracks, every word counted, under the plan's 98%) and traced it to a cut
  ending at 48.77 s, inside "business", in every run. The builder had put it down to Parakeet's run-to-run noise and
  changed the test to leave out fillers and numbers. The cause was real: the cut grew to "0.03 s before the next word"
  on Parakeet's word times, which come in 80 ms steps and put this word's start 0.16 s late.
- **Each edge of a cut now settles on the sound itself:** the start of the quiet between the left-out voice's own end and
  the end the words give (the end), the end of the quiet on the other side (the start), read from the track the
  episode is made from. Toward the next word the words alone now stop 0.24 s short of Parakeet's start for it. Why: the
  verifier's suggested direction, and measured: the quietest point itself is not enough, because before a voiced "b"
  it is the stop's own closure; ends at 48.505 to 48.535 s keep "business", ends at 48.54 to 48.55 s lose its "b". The
  earlier "isness" was this fault too, not a tail of "teaching".
- **The acceptance test counts every word again, as the plan says;** the share without fillers and numbers is written
  down as a reading only, with the words not heard and their times so a loss can be traced. Why: a gate loosened to
  pass hid a real fault.
- **The migration check now fails if a recording arrives with choices, names said aloud or choices applied.** Why: the
  verifier measured it by hand and found no test would catch a regression.
- Help 07 says the cut stops a little before the next word someone included says.

---

## 2026-10-13, Tue: v2 part M6c, choices applied to audio

- **Every face and voice in the People tab now has a choice: Include, Hide Face or Leave Out (a voice with no face:
  Include or Leave Out), with Set All Unnamed To, the line saying what it takes out, Play Their Moments, and Undo.** Why:
  REQUEST item 3, "let me choose who should be included in the output videos and audio".
- **Everyone starts as Include, not Leave Out.** Why: Ivan's note of Mon 12 Oct (PLAN section 11): the participants
  signed releases, so the three choices are editing choices, not a privacy gate. The plan's section 5 default (Remove for
  anyone unnamed) predates that note. The notice's second wording follows: "Other people appear in this recording.
  Everyone is in the episode until you choose otherwise." The plan's own wording would have been false.
- **Leave Out cuts every stretch that person speaks from the podcast episode and the podcast-ready episode, taking every
  word it touches whole and the short gap after it, with v1's 15 ms fades; the transcript files follow.** Why:
  research-people.md 3.4 (cut time, not a track: a voice bleeds into every microphone). Taking a short gap whole was
  measured: with half the gap, an 80 ms tail of the teacher's "teaching" stayed and Parakeet heard "isness".
- **Where a left-out voice and an included one speak at once, the stretch is cut and listed for listening.** Why:
  research-people.md 3.5, fail closed. "Keep Gabriel's microphone here" is not built (it needs the podcast to take its
  sound from another track for a stretch); listed for a later part.
- **Someone left out with no voices found stops the make.** Why: fail closed; a make that could not find them must not
  produce a file that may still hold them.
- **After a make that leaves someone out, Prakriti listens to what it made again (the diarizer, in memory) and compares
  each voice with the original's voices; anyone who sounds like a person left out stops Approve with the time.** Why:
  research-people.md 3.6 item 2. Measured: it passes the real cuts and catches the second voice when it is planted back.
  Embeddings live only for the length of that check (PLAN D2: no print stored).
- **Names said aloud: Apple's tagger finds person names in the transcript, other than people named in Settings; each is
  Keep or Mute, Mute silences it in both podcast episodes and writes [name] in every transcript file, caption and what the
  writer reads; Approve waits until each is decided.** Why: PLAN section 5 and risk R13, Serenity's standing condition.
- **Approve also waits for the choices to be in the episode, for the audio check to pass, and, with someone left out of a
  mixed track, for the changes of voice to be listened to.** Why: Mac warning 36's rule (a yes covers exactly what was
  made) and warning 14 (a mixed track is a guess).
- **With nobody left out and nothing muted, nothing changes.** Why: Mac warning 30, the bit-for-bit check against engine v0.
- **New capability `choices` (separate from `people`, which is hiding faces in pictures, M6d); Help 02, 06, 07 and 09 and
  the welcome rewritten to it.** Why: Help describes only what is built; Hide Face is offered but changes no picture yet.

## 2026-10-13, Tue: v2 part M6b, voices and names

- **Every make now listens for who speaks when, right after the faces: from the microphone tracks when the recording has
  them, else told apart on the one mixed track by FluidAudio's diarizer (0.15.5, Hark's pin).** Why: REQUEST item 3, and
  PLAN review item 5: faces alone could read as "nobody else" where a student is heard but not seen. Microphone tracks are
  the clean-input path (REQUEST item 1); the diarizer is the fallback for every studio file so far.
- **A microphone track speaks when it is within 6 dB of the loudest track, not "6 dB above the others".** Why: read
  literally, two people speaking at once would both vanish; within 6 dB still leaves a voice's bleed into a neighbour's
  microphone out, and keeps overlapping speech, which the cut of overlapping speech needs (research-people.md 3.5).
- **The diarizer keeps overlapping speech.** Why: measured, with FluidAudio's defaults a voice speaking only over the
  teacher vanished into the teacher; with overlap kept it was found to the tenth of a second. That voice is a student.
- **No voice print is written or kept, and nothing is downloaded.** Why: the biometric decision; `embeddingsPath` nil is
  tested, only times leave the diarizer, offline mode is on, and the model folder Hark shares is only read.
- **Voices are linked to faces by the only face on screen and by mouth movement on crowded stretches; doubt leaves a voice
  with no face.** Why: research-people.md 2.6; a wrong link would carry a name to the wrong person.
- **People You Name in Settings, Who is teaching in Info, Name for This Recording and Track N in This Folder in People.**
  Why: until releases are on file (D2) Prakriti cannot recognize anyone, so Ivan names; a name is not biometric.
- **The privacy lock reads the people check: complete only with both steps, every unnamed face, voice and glimpse counts
  as someone else.** Why: Mac warning 90, fail closed. The 13 Sep talk stays local even with Gabriel named and agreed (other
  faces after 12:39; it says "Serenity"); a made-up one-voice recording opens once its voice is named and agreed.
- **Check People replaces Look for Faces.** Why: an older recording needs both steps for the check to count.
- **New capability `voices`; Help 03, 06 and 07 rewritten to it.** Why: Help describes only what is built.

## 2026-10-12, Mon: v2 part M6a, faces in a recording

- **Every make now looks for faces: two frames a second, Vision's revision 4 face finder, boxes and times only, into a
  people file per recording.** Why: REQUEST item 3 ("let me know when it includes other people"); boxes and times are
  what hiding a face needs later (M6d), and they are not a print of anyone's face, so nothing biometric is kept about
  a stranger (the biometric decision, research-people.md 5.1).
- **"Other people appear" rests on how many faces are in one frame, never on telling people apart.** Why: without a
  face print nobody can be told from anybody, and the plan's own tracking (overlap 0.3) split one moving speaker into
  111 tracks on the 6 Sep talk. Two faces in one frame needs no guess about identity, and errs toward saying "other
  people" (the safe direction, research-people.md 1.6).
- **Tracks also join when two boxes are near and the same size, not only when they overlap by 0.3.** Why: measured,
  a speaker's head moves up to 0.115 of the picture in half a second (overlap 0.26); without it the fixture's main
  face split at 58 s and 70 s.
- **The People tab (read only), the people line on cards and in the list, the Other People Appear filter, and one
  fixed notice, "Other people appear in this recording."** Why: the plan's M6a parts; the notice says only what this
  build does, never a name or title (Mac warning 23).
- **Faces on the People tab are cropped from the original while the tab is open and held in memory only.** Why: a
  stored crop of every face would be a collection of students' faces (plan section 5, review item 8).
- **A job folder for every face step, deleted when it ends, and every launch deletes any a crash left, before
  anything else.** Why: research-people.md 5.4; proved with a SIGKILL mid-scan.
- **Faces never open the privacy lock.** Why: a student can be heard without being seen; the check counts as run
  only once the voice step (M6b) exists (review item 5).
- **New capability `faces` for Help, separate from `people`.** Why: Help and the welcome may describe only what is
  built, and `people` also covers voices and choices that do not exist yet.
- **Not installed.** Why: installing ships M5a and M5b with it, which Ivan has not said yes to (BUILD-LOG "v2 part
  M6a", For Ivan).

## 2026-10-12, Mon: v2 part M5b, Anthropic and OpenAI

- **OpenAI joins Anthropic as a cloud provider, each with its own key in the Keychain, a model pop-up filled from the
  company's own list, and a test button.** Why: REQUEST item 5 ("space for an OpenAI or Anthropic API in case a user
  does not have a computer powerful enough"); a pop-up from the live list means no model id goes stale in the code.
- **Anthropic is spoken to in the current request shape: streamed, no thinking field, effort set per task, and the
  server's own fallback on a refusal for the models that support it.** Why: v1's body sent `thinking: adaptive` and a
  non-streamed call; on current models an explicit thinking setting can be a 400, effort defaults to `medium` on Opus
  5.5 so it must be set, and a silent non-streamed call hung for 10 minutes twice. Refusals and cut-off answers are
  failures, never results.
- **Only models that accept this request shape are offered.** Why: `/v1/models` also lists older Claude models that
  reject `output_config.effort`; choosing one would have made every call a 400.
- **Both providers sit behind the M5a lock, proved again in HTTP requests: a class, people not checked, someone who
  has not agreed, or anyone unnamed sends 0 requests to either provider; a checked talk with one consenting speaker
  sends 1.** Why: the plan ships the lock before any new provider, so OpenAI never ran under v1's weaker rule.
- **Anthropic's default model is Claude Sonnet 5.5, and each Anthropic call's cost is measured and shown.** Why:
  Ivan's 12 Oct note (PLAN section 11) and his recorded cost lever (Sonnet about $0.13 a call, Opus about $0.83).
- **Settings, Models lists Planning the edit and Choosing moments, greyed as "Not built yet"; welcome panel 5 gains
  "Choose where models write." with this Mac's verdict.** Why: the design spec's Models pane and panel 5; greyed, not
  hidden, as Mac warning 32 asks for things that cannot run yet.
- **Not installed, for the same reason as M5a** (see BUILD-LOG "v2 part M5b", For Ivan).

## 2026-10-12, Mon: v2 part M5a, the new privacy lock

- **A cloud model now reads only a talk whose people check has run and found everyone heard named and agreed to
  cloud models, nobody unnamed, and no mention of Serenity.** Why: v1's rule let a talk with a student heard reach
  the Claude API as long as nobody said "Serenity"; the plan ships this lock before OpenAI or the new Anthropic
  client (M5b), so neither ever runs under the older rule. The people check is part M6, so today every real
  recording is written on this Mac. **This undoes, for now, Ivan's 12 Oct switch of talks to the Claude API**, so
  the part is committed and not installed until he decides: see BUILD-LOG "v2 part M5a", For Ivan.
- **Every cloud request is a `CloudPayload`, and only `PrivacyLock.release` can make one; cloud clients take nothing
  else.** Why: PLAN 2.2 rule 1 and warning 19: the check has to be on the data and impossible to skip, not a
  reviewer remembering. A test fails if any other file builds a payload.
- **Names are replaced by `[[NAME-n]]` before a request leaves the Mac, put back in the answer, and the text is read
  again before it is allowed out.** Why: warning 19. Measured on the 13 Sep talk, Apple's tagger caught 20 of 21
  name mentions (95%); it missed "Serenity" in the prompt's own sentence about the school's teachers, so her name,
  muted names and named people who have not agreed are always replaced, whatever the tagger finds.
- **A per-person switch, "Cloud models may read their words" (`Person.mayReadInCloud`), off for everyone.** Why:
  the plan's answer to Serenity's condition (SCOPE PRV-10) that still lets a consenting teacher's talk use a key.
- **Settings, Models shows This Mac: the chip, the memory and whether it can run the writing model.** Why: REQUEST
  item 5; the threshold (64 GB) is the measured peak in LOCAL-MODEL.md, and it only suggests, never switches.

## 2026-10-12, Mon: v2 part M4b, the capture check

- **Every new recording is checked for how it was recorded, as its first step once the file is complete: the
  file type, picture size, frame rate, codec, color tags and chapter markers, and every audio track on its own
  (loudness, true peak, silence, and whether left and right are one microphone copied to both).** Why: REQUEST
  item 1, "plan for clean inputs": a poor input gets a check, a warning and a capture tip, never silence. Every
  studio file so far is one track with one microphone in both channels (13 Sep: left minus right -91 dB), the
  reason one voice cannot be told from another (warnings 6 and 14).
- **The findings sit at the top of the inspector's Checks, what to change first, each with a tip and a link to
  the Help article that explains it.** Why: design spec 3.5.4; the plan asks for a plain line, a capture tip and
  a Help link per finding.
- **The check never stops a make or changes a status.** Why: it would hold back every studio recording made so
  far; the sound check stays the only rule that refuses one (Mac warning 108).
- **A test under 60 s keeps its capture check.** Why: the 10-second OBS test is exactly when Ivan needs to see
  the tracks (Help 02 and 03).
- **Older recordings get a Check Capture button instead of being checked by themselves.** Why: PLAN rule 2.1.7,
  an upgrade never starts work on recordings that already exist.
- **Hybrid MOV is accepted everywhere Hybrid MP4 is, and Help, the welcome, warning 15 and SCOPE SET-04 say so.**
  Why: OBS 32 records Hybrid MOV on a Mac by default; a fragmented MOV is now tested through the watcher,
  readiness, the capture check and AVFoundation.

## 2026-10-12, Mon: v2 part M4a, fixes after the verifier

- **Pressing Command-Option-I twice quickly now leaves the inspector shown.** Why: the verifier saw the second
  press fail in 2 of 5 `make look` runs. The key was never lost. It reached the menu every time, and then the
  end of the first hide's animation told the model "hidden" and overwrote it. The window's report now goes
  through `AppModel.inspectorReported`, which sets aside a report that contradicts what was asked under a second
  earlier (Mac warning 107). The earlier reason (the toolbar ring drawn as shapes) was wrong and is corrected
  in warning 106.
- **The keys check now reads the inspector itself, 1.5 s after the second press, with an unhurried hide and show
  as the control.** Why: the old check read only the View menu's words at once, so it passed on a moment that
  the late report then undid; with the unfixed code the new check fails 4 of 4 runs.
- **A running first step reads "Checking the file is complete", not "Checked".** Why: the verifier's picture
  showed the past tense at 0:28 so far. The stored step name stays, because stored steps are matched by it.
- **A snapshot of two recordings in line shows Make Next on the second, and Help says the button is there.**
  Why: no picture showed the button, and Help mentioned only the Control-click.
- **Not installed until every check passed.** Why: PLAN rule 2.1.3; the builder installed before verification.

## 2026-10-12, Mon: v2 part M4a, progress and the Activity window

- **Every recording being made shows its stage, percent and time left: a ring and percent on its card, a bar in
  the list, the stage, "Step 5 of 9", the latest line, Pause and Stop in the inspector and the Viewer's banner,
  the line's percent on the toolbar's Activity button, and "Making Sun 13 Sep: Writing the transcript, 64%,
  about 6 min left." in the menu bar.** Why: REQUEST item 6, "give me a progress on the recordings as it's
  working"; v1 showed the step's name and nothing about how far along or how long.
- **The percent is weighted by how long each stage takes on this Mac and never goes back; a time left is shown
  only once the running stage has a measured rate, else "Working out the time left".** Why: design spec 3.6.1's
  honesty rules. Measured on the 13 Sep talk made twice: the second run's time left was within 3.9% of what
  really remained wherever more than 5 s remained. A stage whose ffmpeg passes are not known ahead moves the bar
  but gives no rate, because measured, the podcast-ready mastering's pace said 8.5 s left when 30 s remained.
- **Stage times are learned:** each finished stage's seconds per minute of recording, the last 10 runs, in a new
  `StageTiming` model (an addition), seeded once from the steps already in the store. Why: the plan's
  `StageTiming`; a fixed guess would be wrong on another Mac and after any change to the pipeline.
- **ffmpeg reports its own progress (`-progress pipe:1`), Parakeet and writing are timed against their measured
  average and held at 95% until they end, and a stage that has not moved for a minute says what it waits on.**
  Why: the plan's fraction sources. Parakeet 0.5.2 was checked: piped, it prints nothing until it ends, so its
  progress cannot be read. Writing keeps `stream: false` (the request is pinned, LOCAL-MODEL.md), so it is timed
  rather than counted in tokens.
- **Pause and Stop per recording, Make Next in the line.** Pause suspends the running tool and moves its time
  limit on by the pause; Stop ends the make (the last make's files stay, Mac warning 29) and nothing restarts it.
  Why: design spec 3.6.3; Pause All could only stop new work from starting.
- **The Activity window is rebuilt: a sentence and Pause All, then Now (the make with every stage, how long each
  took, the usual time of each to come; the line waiting), Finished (by day, with the result, Show and Show in
  Finder) and Log (v1's lines with a search field).** Why: design spec 3.6.3, Final Cut Pro's Background Tasks in
  Prakriti's words. The menu bar menu gains Show Activity, "N recordings need you" and Prakriti Help (design spec
  3.14).
- **`--debug-status-log` and `make accept-progress`.** Why: PLAN rule 2.1.10; the menu bar cannot be captured, so
  the status line is proved from the log, and the acceptance compares it with the trace.

## 2026-10-12, Mon: v2 part M3b, fixes after the verifier

- **Space, J, K, L and Escape in the Viewer no longer depend on SwiftUI's focus.** Why: the verifier found Space
  ignored in 2 of 5 real launches, each one a Viewer put back from the last session; the focus set in `onAppear`
  was not taken. Measured before the fix: 4 of 5 launches failed. A key monitor reads them from the app's own
  events now (START_HERE warning 99); measured after: 20 of 20 launches played.
- **Play at the very end starts again from the beginning, and a pause saves its moment at once.** Why: the
  restored moment walked to the end of the 90 s clip and the next Space did nothing; and a pause at 23.696 s
  came back at 22.800 s because the moment was saved once a second.
- **No word Ivan reads sends him to "the recording's page" or "the Outputs screen" any more.** Why: both were
  retired (M3b and M3a), yet the welcome's step 2, three Help lines and eleven lines of the podcast-ready
  checklist and episode text still named them. Each now names the place the control really is (the Viewer, the
  inspector's Info or Outputs tab, or Settings, Outputs), and `RulesTests` fails if either name comes back.

## 2026-10-12, Mon: v2 part M3b, the Viewer

- **Opening a recording shows the Viewer: the system player on a black canvas, Original, Podcast or
  Podcast-ready chosen in the toolbar, with Timeline-lite and the transcript under it.** Why: REQUEST item 10,
  "preview the videos within the app", and v1's page only played sound in a pill; the plan's M3 Viewer.
- **The transcript is words, not lines: click a word to play from it; select words to Remove from the Edit or
  Keep in the Edit; Follow Playback marks the sentence playing and keeps it in view.** Why: v1's transcript did
  not follow the player (design spec 3.4.4), and cutting by whole lines took more than Ivan chose. A selection
  becomes a cut held clear of its neighbours, because Parakeet stretches a word over the pause after it.
- **v1's recording page is deleted.** Why: the plan retires it only once the Viewer passes `accept-edits`, which
  now runs through the Viewer and the inspector. Its every function moved: the trim, Use Player Time, the cuts
  with Restore and a typed cut to Info; the per-recording outputs to Outputs; steps and numbers were already in
  Checks. Every "page" in the app's words and in Help now names the Viewer or the inspector.
- **Quick Help (Help menu) replaces tooltips at the top of the inspector, and the first-time tip is Prakriti's
  own row.** Why: tooltips draw at 11 pt; TipKit's `TipView` was not proved to draw at 12 pt or more.
- **The window comes back as it was left** (group, selection, open recording, rendition, moment, tab), kept in
  the mode's preferences, not the store. Why: design spec 2.5; no migration for where the window was.
- **`--debug-playback-log`, and playback proved from the log in `make look`.** Why: PLAN rule 2.1.10; a moving
  picture cannot be judged by a verifier, and the menu of a real player cannot be read.
- **The player never takes the keyboard focus.** Why: measured in the real window, Escape stayed in the Viewer
  while `AVPlayerView` held the focus.
- **No capture or snapshot shows a talk's picture; the Original plays a test pattern there.** Why: D1 stands
  in this run's instructions (frames of Gabriel's talks are measured, not looked at).

## 2026-10-12, Mon: v2 part M3a, second fix (the build was not warning-free)

- **`make build` now fails on any compiler warning by reading its own output.** Why: the commit that kept
  layout out of the live preferences (1aafbc0) added a Swift concurrency warning, `SWIFT_TREAT_WARNINGS_AS_ERRORS`
  did not turn it into an error, the build said it succeeded, the report said 0 warnings, and that build was
  installed live. The compiler setting cannot be trusted alone, so the log is the judge.
- **The window observer behind that warning is a selector on a main-actor object.** Why: the closure form is
  Sendable, so it could not touch the window without either the warning or a data-race error.
- **`make install` unregisters every other copy LaunchServices knows, running or not.** Why: the first fix only
  caught copies that were running, and a quit scratch build was still registered, ready to be picked by
  bundle identifier.
- **Not installed by this fix.** Why: PLAN 2.1.3 installs only after an independent PASS, and 1aafbc0 was
  installed before one; this fix waits for the verdict.

## 2026-10-12, Mon: v2 part M3a, fixed after verification

- **The privacy lock fails closed: only a recording marked as a talk, without Serenity, can reach the Claude
  API.** Why: v1's rule locked only a class or Serenity, so a recording whose kind was never set went to the
  cloud when chosen, and the live settings chose the Claude API while the 16, 20 and 23 Sep classes sat
  unmarked in the store. M5a replaces the rule and must stay at least this strict.
- **`make migrate-check` checks the migration, not Ivan's data.** Why: it asserted nothing was approved or
  removed, which failed the ship gate for every later part the evening Ivan approved two talks.
- **Captures and development copies no longer save window layout into the live preferences, and `make look`
  puts back anything that slips through.** Why: every copy shares the bundle identifier, and `make look` had
  changed the live split view and Settings window sizes.
- **`make install` quits and unregisters any other copy running live.** Why: from 20:13 on 11 Oct the live
  watcher was a verifier's Debug clone under `/private/tmp`, picked by LaunchServices, with no login item.

## 2026-10-11, Sun: v2 part M3a, the main window and Settings

- **The main window is a library now, built the way Photos and Final Cut Pro are: a sidebar of groups and
  folders, a browser of recordings, and an inspector for whatever is selected.** Needs You, In Progress,
  Ready and All Recordings replace Today and Recordings; each watched folder is a row under Sources with its
  settings in the inspector; recordings show as a grid of cards or a list (Command-1, Command-2), sorted and
  filtered, and a search finds them by title, notes or what was said, opening the recording at the matching
  sentence. Why: Ivan asked for "another pass, how would Apple build it" (REQUEST item 11), and v1's long
  scrolling pages put controls far from what they affect.
- **Opening a recording still shows v1's recording page, unchanged.** Why: the Viewer is part M3b's, and
  episode 1 ships Fri 23 Oct; trim, cuts, Make Again and Approve must keep working on the page Ivan knows
  until the Viewer has passed the same checks (PLAN 10.1, item 2).
- **Outputs, Models and v1's settings moved into a Settings window (Command-comma); Activity into its own
  window (Window > Activity).** Why: the sidebar is for content, preferences live in Settings in every
  Apple app (design spec C5); Activity's progress features come with part M4a.
- **"Ready for your yes" reads "Waiting for your yes", in the app, the notices and Activity.** Why: "Ready"
  now names the group of approved recordings, and one word must mean one thing (design spec C1). The stored
  value did not change, so nothing migrated.
- **Secondary text, sidebar headings and red problem text are drawn in colors measured at 4.5 to 1 or more,
  and text in the accent uses #7D8BFF in dark.** Why: measured on macOS 27.2, the system's secondary grey is
  3.95 to 1 on the white window, the sidebar's heading grey 2.23, and the dark accent 3.05 (design spec C7):
  under the minimum for 15 and 17 pt text. A test measures every text color on every background, light, dark
  and Increase Contrast.
- **The privacy lock's line names the real reason and no person:** "This recording names a teacher who has
  not agreed to cloud models, so only models on this Mac read it." Why: design spec C4; the rule underneath is
  still v1's until part M5a.
- **Remove from Library forgets a recording, sends its Outputs folder to the Trash, and leaves its path on
  its folder so the watcher never finds it as new again.** The original and the Approved folder are never
  touched. Why: the design spec asks for it (3.1.1), and without the path list the next look, five minutes
  later, would have taken the recording in again and, in a Make outputs automatically folder, made it again.
- **The accuracy checklist has a box per claim, in the inspector's Checks.** Why: the plan asks for it, and a
  claim Ivan has checked should stay checked; the ticks change no file and no approval.
- **The window opens at 1440 by 900 (it was 1180 by 760), never smaller than 1100 by 720.** Why: 17 pt type
  with a sidebar, a browser and an inspector needs the room (design spec 2.2). Ivan's own saved window size is
  kept.
- **Found while building, and fixed:** an empty state's wrapped message, asked for its smallest size in a
  narrow column, asked for up to 2,195 pt of height, which would push the window past the screen (now a
  240 pt minimum width, and a snapshot check that the content fits); Escape while typing in a field on the
  recording's page closed the page (now the field keeps it); setting a whole window's text hierarchy to fix
  the grey turned every bordered button and tile dark (taken back for a measured style).

## 2026-10-11, Sun: v2 part M2b, the welcome window

- **A welcome window of five panels opens once by itself, and again from Help, Welcome to Prakriti:**
  what Prakriti does, how to record for the best results, how outputs work, privacy, and three things to
  set now (a folder to watch, notifications, where Help is). "1 of 5" in words, Back and Continue, Return,
  Command-Left and Escape; every panel fits 720 by 600 pt at 17 pt without scrolling. Why: Ivan asked
  for a startup screen with usage tips, including how to capture the best video (REQUEST item 2).
- **Each row names the parts it describes, as Help's blocks do, so the welcome shows only what is
  built.** Today panel 1 lists finding recordings, the podcast and "nothing is posted without you";
  panel 3 has three steps, not five; the privacy panel describes v1's real protections. A sentence that a
  later part replaces is written twice (today's, and v2's), and a test walks every stage of the 31-part
  build to prove exactly one shows. Why: a welcome that promises a viewer, faces or an edited video
  before they exist is the copy drifting from the build (PLAN R16), and it is the first thing anyone reads.
- **It counts as seen when it is shown, at a launch made by hand.** At a launch macOS makes at login it
  is neither shown nor counted, and the first-launch check deletes only the development copy's preference.
  Why: Prakriti closes every window it opens at login, so a welcome counted then would never have been
  read; and a check must never touch the live app's preferences.
- **macOS is not asked about notifications at the launch that shows the welcome; the last panel asks,
  after saying why.** Its button reads macOS's answer first: never asked, it asks; turned off, it reads
  Open Notification Settings and opens System Settings at Prakriti's own page (measured: the page's
  address takes the app's id); on, it says On. Settings' own button now opens the same page. Why: v1 found
  notifications off for Prakriti, and once macOS has a no a second request shows nothing; the HIG asks for
  the reason before the system's question.
- **Choose Folder on the last panel uses a panel that does not stop the app,** and says on the row what
  happened (added and set to Ask me first, already watched, or refused and why). Why: nothing in the
  welcome may hold up the watcher, and an alert would land on the main window behind it.
- **A capture that adds a folder never lets the watcher look through the folders.** Why: the sample data
  names the real studio folder, so a look in a window capture would have taken its files in (found while
  building the capture of the last panel, before it ran).

## 2026-10-11, Sun: v2 part M2a, Help in the app

- **Prakriti Help is a window in the app (Help, Prakriti Help, Command-?):** the articles by section in a
  sidebar, each drawn at 17 pt with the app's own type scale, Back and Forward, search as you type, Related
  links, and Show Me buttons that open the screen an article describes. Why: Ivan asked for documentation
  in the help section (REQUEST item 2); a Help Book would open in another app, could not open a place in
  Prakriti, and its index has been unreliable for years (design spec 5.6).
- **The Help menu's own search field lists the articles,** beside the menu commands macOS finds, and
  Show Log in Finder sits under Help. Why: that is where a Mac user types a question, and the log should
  never need a typed path.
- **Help describes only what is built.** Each article and each block inside one names the capability it
  describes (`:::requires video`, or `:::unless video` for what is true until then); only `help` is on,
  so the viewer, faces, the edited video, timelines, shorts, OpenAI and the rest are hidden until the part
  that builds each switches it on. A test lists the feature names every part introduces and fails if one
  shows early. Why: the help drafts were written for v2 and described features that do not exist yet; a
  help page that promises a feature is the copy drifting from the build (PLAN R16).
- **Every article was rewritten to describe today's app** (v1 with the podcast-ready episode): the
  recording page's Listen, trim and cuts, Approve's real rules, the podcast-ready folder as built on 10 and
  11 Oct, the v1 privacy lock as it is. "Welcome to Prakriti" became "What Prakriti does" and "People and
  privacy" became "Privacy and students" until the features those names point at exist. Why: Ivan reads
  Help to act on it, so every visible sentence has to be true today.
- **The articles live in the app (`mac/Prakriti/Resources/Help/`), moved one by one; the builder notes
  moved to `docs/v2/help-notes/`.** Why: the bundle should hold user text only, and a `*.md` glob would
  have shipped the welcome panels' copy as an article.
- **swift-markdown 0.9.0 (Apple's package), pinned exactly, with Ivan's yes,** parses the articles into
  blocks the window draws itself; tables, images and HTML are refused by the test. **Smart punctuation is
  off.** Why: the first snapshots showed it curling quotes the rest of the app writes straight, and it
  would turn `--` into the dashes Ivan's rule forbids.
- **No URL scheme is registered.** Show Me links are buttons inside Help, and an article's links only open
  other articles. Why: a registered `prakriti://` scheme would let any web page drive the app.
- **A debug switch, `--debug-help-search`, prints what the Help menu's search returns and quits,** so an
  unattended check can read it. It is compiled only into Debug builds and refused by the installed copy.
  Why: `make install` installs a Debug build, so `#if DEBUG` alone would have put it in the live app.

## 2026-10-11, Sun: v2 part M1, the new icons

- **The Dock and Finder show "Recomposed": the ultramarine dot cut across its middle, the halves set
  apart** (`docs/v2/icons/README.md`), as an Icon Composer document with default, dark, clear and tinted
  looks, in place of v1's plain dot. Why: Ivan asked for a better icon (REQUEST item 12), a dot on a
  light square reads as a record button, and a cut and re-set mark says what the app does without
  drawing film or a waveform.
- **v1's `make_icon.swift` and its icon set are deleted, not kept beside the new icon.** Why: two
  sources for one icon is how a stale one comes back; the master is now `docs/v2/icons/source/Prakriti.icon`
  (START_HERE warning 73).
- **The menu bar shows the same cut disc as a template glyph, one shape per state,** in place of the
  SF Symbols ring. Why: the Dock and the menu bar should read as one app, and a state is a shape, never
  a color, because macOS already dims the whole menu bar on a display that is not active.
- **While work runs, the two halves light in turn every 0.7 s, turned by a `WorkingTicker` on the
  model; the timer exists only while the menu bar shows working, and never with Reduce Motion.** Why: a
  menu bar label is drawn once, so it cannot animate itself (measured by the icon track), and a timer
  left running would wake Prakriti all day for nothing (START_HERE warning 72).
- **Checked in the real menu bar, not only in tests:** `capture-window.swift --menu-bar` reads the
  system's menu bar window with no click. While a 90 s clip was made in a development copy, its mark
  went from the waiting glyph to 92 alternations one every 0.70 s, and back to waiting when the clip was
  ready; under Pause All it showed the outline. `--app-icon` draws the icon as Finder gets it and
  measures the cut. Why: the plan left the menu bar to Ivan's eye because capturing it needs Screen
  Recording permission; this session had that permission, so the animation is measured as well.
- **Tests that fail on the bug:** every glyph an 18 by 18 pt template and the seven drawings different,
  and the ticker driven on a clock the test moves by hand (flips on the 0.7 s, no timer while idle,
  never with Reduce Motion). Each was proved by breaking the code it guards.
- **`make install` now gives the installed app a new date.** Why: after the first install Finder's
  icon for the live copy was still v1's dot while the bundle held the cut disc; `ditto` had kept the
  build folder's 10 Oct date, and macOS keeps an app's icon cached against it. With a new date
  Finder's icon is read again (measured both ways; the Dock hides itself here and was not measured).
- **Stale truth fixed:** START_HERE gave "the engine has no Dock icon" as the reason notices never use
  a badge. Prakriti for Mac has had a Dock icon since v1; v2 still shows no badge by choice, and a badge
  is now Ivan's decision. The help article on troubleshooting described the menu bar "ring"; it now
  describes the mark.

## 2026-10-11, Sun: v2 part M0, the baseline (no class in any check)

- **`make fixtures` (`mac/scripts/make-fixtures.sh`, recipes in `mac/scripts/fixtures/`) builds the
  shared test files every v2 part uses**, into `~/Prakriti/Dev/Fixtures`, from the 13 Sep and 6 Sep
  talks and macOS `say` only: a 90 s clip, 65 s of picture with digital silence, a second face and a
  second voice on one mixed track, the same with each voice on its own microphone track, 30 s of
  planted fillers and a restart, and a made-up 4,023-word talk in Parakeet's JSON shape. Why: v2's
  checks need silence, a second person and a second microphone, which the two talks do not have, and
  the only studio files that do are classes, which no check may read (student privacy).
- **Every fixture comes out byte for byte the same on a second run,** and the script says SAME or
  CHANGED against the last one. Why: an independent verifier rebuilds them on its own clone, and a
  check is only repeatable if its input is.
- **Three recipe choices were changed by measuring, not by looking:** the corner picture starts at
  3:00 of the 6 Sep talk, not 10:00, because Vision found no face there from 10:12 on; the mixed track
  is coded so its two channels stay identical, as the studio's one microphone is (ffmpeg's default let
  them drift by up to -14.5 dB); the stutter is "So so", because Parakeet heard "The the" as "that the".
  Why: a fixture that does not show what its name says would pass a check for the wrong reason.
- **`make accept` uses `silent-60s.mp4` where it read the silent 14 Sep class,** builds the fixtures
  first if any is missing, and fails if a 2026-09-14 path comes back. START_HERE warning 17 now reads
  "the 13 Sep and 6 Sep talks only". Why: the v2 plan's rule is never a class, and v1's own acceptance
  was the one place that still read one.
- **`make regress`** runs the regression set every v2 part must pass (`make test`, `make accept`, `make
  accept-edits`). Why: one command a verifier cannot run half of.
- **`make accept-podcast` looked for headings the episode text renamed on 11 Oct** ("SHOW AND EPISODE",
  "CHAPTERS") and failed on the 6 Sep talk with every measurement passing; nobody had run it since. The
  test now reads the episode text's headings, and the whole acceptance passed on both talks. Why: the
  v2 plan's regression set leans on these acceptances, and one that fails for a stale reason teaches
  people to ignore it.
- **The episode 1 file Ivan is asked to listen to now has a copy at `~/Prakriti/Dev/Listen/`.** Why:
  every acceptance run clears the development output folder the handoff pointed at, and v2's parts will
  run them many times before Fri 23 Oct.
- **Raised, not changed:** on the 13 Sep talk the writing model ran out of thinking one try in three
  today (one cut off at its 16,384-token limit, one empty), each failed try costing about half an hour.
  Why it is written down: the budget is v1's, the first part to touch the writing (M5a) should fix it.
- No app code changed; the live app was reinstalled from this code only after every M0 check passed
  (see `docs/BUILD-LOG.md`, "v2 part M0").

## 2026-10-11, Sun: the podcast-ready handoff, and one claim taken back

- **`docs/BUILD-LOG.md` ends with "Podcast-ready episode: the handoff":** what the independent
  verifiers measured on both halves (the audio of 10 Oct and the episode text of 11 Oct), what is
  MISSING by design and where Ivan sets each, where episode 1's file is and how he makes it in the live
  app, what episode 1 still needs before it is uploaded, and the best pictures. Why: both halves passed
  their independent checks, and Ivan needs one place that says what to do next.
- **"It fixes the volume riding" is taken back** (the 10 Oct entry below, START_HERE, the top of
  BUILD-LOG). The independent check measured the gain second by second: on episode 1, 92 s of jumps
  over 2 dB within a second against v0's 104; on 13 Sep, 66 against 58; and the pauses lifted about 5
  dB more than the voice against about 2 dB in v0's files. What the new chain does do: one even raise
  for the whole episode (loudnorm linear, v0's dynamic) and a loudness range 0.5 LU lower (episode 1:
  5.2 to 4.7 LU). Why: a claim the numbers do not carry would tell Ivan he need not listen, and episode
  1 ships Fri 23 Oct.
- **START_HERE's Day to day now explains the upload folder:** where it is, what each file is for, the
  five steps from setting the show to uploading by hand, and that the Speakers line always stays MISSING
  until Ivan has listened. Why: the folder is the deliverable, and the page alone never says "Ready to
  upload" (Speakers cannot pass), which would read as a fault without the explanation.
- **Raised for the next build, not changed:** the writing's thinking now reaches 11,000 to 14,800
  tokens against a 16,384 cap and has not been run on episode 1 with the episode text; Speakers needs a
  way to pass on Ivan's word; the checklist does not know an episode's content conditions (income
  claims, the student story, Serenity's passages). Why: each could stop episode 1 the week it ships.

## 2026-10-11, Sun: the episode text, and Ready to upload

- **`Episode text.txt` (and the same as `Episode text.md`) in the Podcast-ready folder replaces
  `Title, show notes and captions.txt`.** It holds the episode title (Ivan's, else the writer's first
  pick) and three alternatives, a one-line summary under 160 characters, the show notes in 2 to 4 short
  paragraphs followed by the chapters at their times in the finished MP3 and Ivan's call to action, the
  keywords, and a caption each for Instagram (up to five hashtags), LinkedIn and X and Threads (under 280
  characters), each with a one-sentence pull quote. Why: Ivan asked for the episode's name, show notes and
  captions for that specific episode beside the file, as close as possible to uploadable; one caption
  per platform is what gets pasted, and a pull quote is the line people share.
- **Written in the same single request as the titles and notes**, by the chosen model (on this Mac
  under the privacy lock). Why: a second request would hold the 33 GB model for another 10 to 20 minutes.
  The request now takes 24 to 27 minutes on the 13 Sep talk (most of it thinking), so the Started
  notice's estimate was raised from about 10 to about 27 minutes.
- **Ivan's copy rules are read by Swift, not only asked for (`CopyRules`).** No prices, money,
  earnings, enrollment, sign-ups or offers in a title, the one-line summary, the show notes, a keyword,
  a caption, a pull quote, the tags or the summary: a flagged caption, quote, title or keyword is left
  out, a flagged sentence is taken out, and each is said. Why: the 13 Sep drafts of 10 and 11 Oct said
  "available to enrolled students", "pause new student enrollment", "a free week" and "pricing", while
  enrollment may be closed and the talk names a teacher's own income. A prompt is not a guarantee.
- **Every pull quote is found word for word inside one line of the transcript, or left out; every
  hashtag is whole words the teacher says.** Why: Ivan's brief asks for a verbatim one-sentence quote,
  and the model's first hashtags included a misspelling ("#Yogalinage").
- **The recording page's podcast-ready section is now "Ready to upload":** whether it is ready, every
  file with its size and Show in Finder, a Copy button for the title, the one-line summary, the show
  notes and each caption and pull quote, and the whole checklist with PASS, MISSING and FAIL as words.
  Why: what Ivan does next is paste these into a host's form and three apps; the file and the buttons
  read the same function, so what is copied is what the file says.
- **A class is never made ready to upload.** The pipeline skips both podcast-ready steps for a class,
  Update Podcast-Ready Files refuses it, and the page says why. Why: students may be heard in a class
  and voices are not checked; a folder named for upload must never hold one.
- **Numbering and a call to action on the Outputs screen.** Numbered, an episode without its number is
  MISSING; the call to action closes the show notes in Ivan's words, and is the only place money or
  enrollment may appear. Why: Ivan's brief, and the show decides both once, not each episode.
- **The show's name, host, artwork, numbering and call to action now always come from the Outputs
  screen,** even for a recording with its own choices. Why: the acceptance found that a recording given
  its own choices kept a frozen copy of them, so a show name typed later on the Outputs screen never
  reached it; that is the exact flow BUILD-LOG gave Ivan for episode 1.
- Checks and measured results: `docs/BUILD-LOG.md`, "Episode text and Ready to upload".

## 2026-10-10, Sat: the podcast-ready episode

- **A new output, "Podcast-ready episode": the file Ivan can upload to a podcast host as it is.** In
  `<Outputs>/<recording>/Podcast-ready/`: the MP3 named for the show and the episode, its captions
  (.srt and .vtt) timed to it, `Title, show notes and captions.txt` and `Upload checklist.txt`. The
  quick "Podcast episode" stays as the draft to listen to. Why: Ivan asked for edited audio as close
  as possible to uploadable, with the episode name, show notes and social captions beside it.
- **It fixes the volume riding Ivan heard on episode 1.** (Taken back Sun 11 Oct, see the entry above:
  the chain raises the episode evenly, but the measurements do not show the riding gone.) Diagnosed with numbers first: engine v0's
  loudnorm pass falls back to "dynamic" on every studio talk, because the talk's peaks sit about 24
  dB over its loudness; on episode 1 the gain it applied moved over a 4 dB spread, jumped more than 2
  dB within a second for 104 s, and lifted the room tone in pauses unevenly. The new chain levels
  with a gentle compressor, then raises the whole episode by one amount (loudnorm reports linear),
  then limits the peaks. Why: the riding was the one thing about episode 1's sound already flagged
  for Ivan's ears since milestone 2.
- **Every setting was chosen from a measurement, and each reason sits beside its number in the
  code:** 70 Hz high-pass (the voice's lowest notes sit at 90 to 120 Hz), 1.5:1 compression (stronger
  settings jumped more than v0 did), noise reduction off (the room sits 38 to 51 dB under the voice
  and afftdn lowered it only 1.5 dB), 44.1 kHz mono 96 kbps (a null test: 5 dB less coding noise than
  64 kbps, which also broke the peak rule; 128 adds a third to the file for 1.5 dB). Why: "reading
  code is not verification" applies to sound too.
- **Prakriti writes the MP3's ID3v2.4 tag itself, and reads it back.** Why: ffmpeg wrote the comment
  as the wrong frame and left the chapter titles out (measured), and a checklist must describe the
  file, not the intent.
- **The writing model now also drafts three social captions** in the same single request, checked like
  the quotes: words in quotation marks must be the teacher's own, word for word. Why: Ivan asked for
  captions for sharing each episode; a second request would hold the 33 GB model for minutes more.
- **Show name, host and artwork are never invented.** They are MISSING in the checklist until Ivan
  sets them on the Outputs screen; the file is named by its date until it has a title. **Update
  Podcast-Ready Files** on the recording's page re-tags and renames around the audio already made
  (about 10 s for a 16-minute talk, 35 s for episode 1). Why: the build's do-nots, and a title chosen
  after the make should not cost a remaster.
- **The finished file's true peak is measured to the hundredth.** Why: the first acceptance run found
  episode 1, trimmed by 10 s, at -0.98 dBTP by loudnorm's meter while ebur128's one-decimal summary said
  "-1.0", so the checklist would have passed a file over Apple's line. Now a file over -1.1 is made
  again with the limits lowered, and the limits start 0.2 dB lower.
- **Approve copies the Podcast-ready folder**, with every file in it in the receipt. Why: the approved
  folder is where Ivan uploads from.
- Off for every folder until Ivan turns it on. Checks and measured results: `docs/BUILD-LOG.md`,
  "Podcast-ready episode".

## 2026-10-10, Sat: Prakriti for Mac v1, finish line

- **`docs/BUILD-LOG.md` ends with the finish line:** what works with its measured evidence, what does
  not, Ivan's checklist, the best picture of every screen, and the three things to try first. Why:
  the build prompt's finish line asks for exactly that, and a v1 nobody can pick up cold is not done.
- **Re-checked on the final commit before writing it:** 113 tests, 0 failures; the live app's
  5-minute look still logging; engine v0 still retired; the 13 Sep episode measured again at -16.8
  LUFS, true peak -1.7 dBFS. Why: the section quotes numbers, and each had to survive a fresh
  measurement.
- **START_HERE gains "Day to day (for Ivan)"** (open, where files go, pause, stop, and that nothing
  restarts Prakriti after a crash), and its opening paragraph no longer says nothing is built. Why: the
  section was written for whoever builds the app, not for the person who uses it, and the opening
  described Thu 8 Oct.

## 2026-10-10, Sat: Prakriti for Mac, milestone 6 (the models)

- **Prakriti now writes titles, show notes, chapters and an accuracy checklist for a recording,**
  with Qwen3.8-27B in LM Studio by default, and Apple on-device, Ollama or the Claude API chosen per
  task on the Models screen, each with a test button. Why: titles and notes were Growati's job and are
  Prakriti's to replace (SCOPE PKG-04), and Ivan asked for local models first.
- **Nothing the model writes is kept on trust.** Every chapter must start at one of the transcript's
  own line times and every checklist quote must be found word for word in `transcript.txt`; anything
  else is left out and counted, and a bad answer is tried again. Why: a model invents times and quotes,
  and Serenity's condition is that a person can check every claim (SCOPE 13).
- **The privacy lock is real now:** a class, or a recording whose transcript says "Serenity", is only
  read by models on this Mac; a task set to the Claude API is done by LM Studio instead, and the page
  and the show notes say so. Why: SCOPE PRV-10, until Serenity says yes no Claude session reads her
  teaching or any class. The 13 Sep talk names her, and the acceptance proved the Claude API was asked
  0 times.
- **Prakriti loads Qwen3.8-27B itself at 65,536 tokens and unloads it after.** Why: LM Studio's default
  8,192 would cut a transcript off (LOCAL-MODEL.md), and the model holds 33 GB.
- **The prompts keep private matters out of titles and notes.** Why: the first real run's show notes
  repeated a private family matter the talk mentions; with the rule, the second run's did not.
- **Off for every folder until Ivan turns it on,** including the live studio folder. Why: 10 to 15
  minutes and 33 GB per recording should be a choice.
- Checks and measured results: `docs/BUILD-LOG.md`, "Milestone 6".

## 2026-10-10, Sat: Prakriti for Mac, milestone 5 fixes (the transcript reads as it was said)

- **The transcript files that follow the episode now read exactly as Parakeet wrote each sentence.**
  Since milestone 5 they were rebuilt by joining Parakeet's word pieces in the order Parakeet lists
  them, and that order is not the order they were said: Parakeet sorts them by time, and a few carry
  a wrong time where its listening chunks meet. About 4% of sentences came out as ". But the problem
  was that again, we spent $100 for the venue" or "the You can always have access to Fathom", and
  because the default silence trim counts as taking something out, Episode 1's captions had 8 of
  those with no edits at all. Why it matters: Episode 1 ships Fri 23 Oct with these captions. The
  pieces are now put back in the order of the sentence's own text, and a sentence kept whole is
  written as Parakeet's text.
- **The approved REPORT.md no longer lists `transcript.json`** (Approve never copies it; the report
  now says it stays in Outputs) **and no longer names a word list fix from inside a cut.** Why: the
  approved folder is what goes out, and cut content must not reach it, not even a term.
- START_HERE's map said milestones 1 to 3; it now says 1 to 5.
- Checks and measured results: `docs/BUILD-LOG.md`, "Milestone 5 fixes".

## 2026-10-10, Sat: Prakriti for Mac, milestone 5 (the recording page)

- **Each recording now has a page Ivan can review and approve from.** Approve at the top; the
  system's own audio player (the episode as made, or the original's sound); the transcript as lines
  that play from their moment; where the episode starts and ends; sections to cut, from selected
  lines or typed times; the title, notes and what the recording is; Make Again with all of it. Why:
  until now a finished episode could only be opened in Finder, and nothing could be taken out of it.
- **Trim and cut work, measured on the 13 Sep talk.** The first 10 s trimmed and 5:00 to 5:30 cut,
  made again and approved: ffprobe measures the approved MP3 38.82 s shorter than the first episode
  (which had already lost 1.18 s of silence) and 40.05 s shorter than the recording. The cut words
  are gone from the approved transcript, and transcribing the approved episode again heard none of
  them.
- **Approve copies, it never publishes.** The finished files go to `~/Prakriti/Approved/<name>/` with
  a receipt holding the title, the notes and every file's SHA-256; `transcript.json` (every word as
  heard, cut words included) stays behind. **A class cannot be approved,** nor a conversation, nor a
  recording nobody has marked as a talk: the page says "Speakers not checked". Why: speaker checks
  do not exist yet, and an unknown voice counts as a student.
- **The transcript files now follow the episode** once anything is taken out of it: the words in a
  cut are dropped and the times match the audio. Why: a cut is how a student's question comes out,
  and the words must go with it; it also fixes captions that sat 1.2 s late after the silence trim.
- Every check, measurement and decision is in `docs/BUILD-LOG.md`.

## 2026-10-10, Sat: Prakriti for Mac, milestone 4 (outputs and settings)

- **Every output's settings now change what is made, proved on the 13 Sep talk.** Loudness target
  -16 measured -16.8 LUFS; changed to -19 on the Outputs screen and made again, it measured -19.1
  LUFS on two meters. Turned the transcript off on the recording's page and made it again: no
  transcript file was left. Why it mattered: until now trim, intro, outro, stereo, the .md transcript
  and the word list were switches that did nothing.
- **Fixed a trap found on the way: the Outputs screen never reached a watched folder.** Each folder
  kept its own frozen copy of every setting from the day it was added, and that copy won, so the
  loudness on the Outputs screen showed one number while the studio folder's episodes were made at
  another. Now a folder chooses only which outputs it makes; how they are made comes from the
  Outputs screen, or from a recording's own choices.
- **The Yoga Marga word list fixes known mis-hearings on this Mac,** and keeps Parakeet's words as
  heard in `transcript.json`. On the 13 Sep talk it made 15 fixes ("Yoga Marka", "Krishna Macharya",
  "Patabi Joyce", "Ayengar" and lowercase "yoga marga"), each listed with its time in REPORT.md so a
  wrong fix can be found. Why: Sanskrit and the school's own name are what speech recognition gets
  wrong, and a transcript that misspells the brand cannot go out.
- **Making again is safe.** A make happens in a hidden staging folder and replaces the old files only
  when it has finished; a remake that stops leaves the last good episode untouched, and only
  Prakriti's own files are ever replaced. With the new settings off, the 13 Sep episode is still
  engine v0's, bit for bit.
- **Silence is trimmed at the start and end by default** (1.2 s on the 13 Sep talk), conservatively,
  so no word is clipped. Titles, show notes and chapters are shown as waiting for the writing model.
- Every check, measurement and decision is in `docs/BUILD-LOG.md`.

## 2026-10-10, Sat: Prakriti for Mac, milestone 3 (the watcher, notifications) and the switch-over

- **Prakriti for Mac is now the live engine, and engine v0 is retired.** The app watches the Studio
  Recordings folder and `~/Prakriti/Drop` with FSEvents (replayed from the last saved event after a
  quit) and a look through every folder every 5 minutes, makes what each folder is set to make, or
  checks and waits when it is set to "Ask me first", gives automatic work three tries, logs a line
  for every look including "nothing new", and opens at login from `~/Applications`. Why now: the
  build said to switch only once the app's own watcher passed, and it did, in both places: a 90 s
  clip moved into the drop folder was found in 7 s and Ready for your yes 78 s later with no clicks,
  before the switch-over in `~/Prakriti/Dev/Drop` and after it in `~/Prakriti/Drop`.
- **Nothing engine v0 saw is made again.** The app read v0's `state.json` into its store before its
  first look (11 files: 7 already there on 8 Oct, the 13 Sep and 6 Sep episodes, the silent 14 Sep
  class), and its first look over the studio folder found nothing new. Why it matters: without it,
  the classes of 16, 20 and 23 Sep would have been taken as new, and they may not be processed.
  The vertical renditions v0 never listed are never listed here either; a test with that rule
  removed made 13 recordings instead of 11.
- **One notice per recording, updated in place,** written to SCOPE 8's copy rules and tested on every
  variant: title case with the date, full sentences, no app name, no "we", no em dashes, and never a
  file name, a title or a tool's error text, because a dropped file can be named after a student and
  notices show on lock screens.
- **Not working yet, and Ivan's to fix:** macOS reports notifications as turned off for Prakriti, so
  every notice goes to the log only. Turn them on in System Settings, Notifications, Prakriti.
  Until then a silent class shows in Today and Activity but not as a banner.
- **The uncomfortable part:** v0 was restarted by launchd if it crashed; the app, as a login item, is
  not, until the next login. Every check, measurement and decision is in `docs/BUILD-LOG.md`.

## 2026-10-10, Sat: Prakriti for Mac, milestone 2 (the pipeline in Swift)

- **The app can make an episode now.** Engine v0's pipeline is ported into `mac/Prakriti/Engine`
  rule for rule (readiness, under 60 s is a test, sound check first, Parakeet with the coverage
  check, two-pass mastering with v0's two bug fixes, the MP3 measured and its tail decoded,
  REPORT.md) and run one at a time from File > Process File… or a recording's Make Outputs button.
  Why a port first: the watcher (milestone 3) needs a pipeline it can trust before engine v0 is
  retired, and the proof is that both talks' episode audio decodes **bit for bit identical** to
  v0's, with identical transcripts.
- **Acceptance on real recordings, `make accept`:** the 13 Sep talk at -16.8 LUFS, peak -1.6 dBFS,
  transcript to 15:47 of 15:48, REPORT.md; the silent 14 Sep class refused as Needs a decision with
  nothing made; a 30 s clip filed as a test; the 6 Sep talk at -16.7 LUFS. The real app processed a
  90 s clip with no clicks in 69 s.
- **Found while porting, and raised rather than fixed:** loudnorm has never stayed linear on these
  talks; it silently levels them moment to moment (SCOPE finding E23), including episode 1. The
  report now says so in plain words, Ivan should listen to episode 1 for it before Fri 23 Oct, and
  the fix belongs in milestone 4 with the loudness settings. Why not now: the milestone asked for a
  faithful port, and a mastering change a week before episode 1 deserves its own check by ear.
- Every check, measurement and decision is in `docs/BUILD-LOG.md`.

## 2026-10-10, Sat: Prakriti for Mac, milestone 1 fixes after the independent check

- **The selected sidebar row lost its icon in the real window,** light and dark. The icons had been
  tinted with the accent color to make a snapshot look right, and macOS paints the selection in
  that same color. The tint is gone. Why it matters beyond one icon: the snapshot was changed to
  draw a grey selection that hid the bug, so the fix is in three places. The app no longer colors
  sidebar icons; the snapshots now draw the selection as the real window does and fail when its
  icon or label cannot be seen; and `make look` (also the end of `make check`) captures the real
  window on every screen, light and dark, and checks the row by its pixels. Both checks were proved
  by putting the bug back: 32 of 32 snapshots and 10 of 14 real captures failed.
- **Development now refuses engine v0's folders, the classes and the archive however they arrive**
  (Add Folder, Add File, the drop zone), with an alert in plain words. Why: the guard covered only
  the first launch, and from milestone 2 a hand-added class could be run, against the build's rule
  on student privacy.
- **Recordings keep one order** when several share a session date (date, then found, then path).
  Why: the same list drew differently from one look to the next.
- **No tooltips.** Measured at 11 pt, under Ivan's 12 pt floor. Pause All and Add File show their
  names; long paths take a second line. A test fails on any tooltip.
- **Smaller:** the title bar's sidebar button draws its glyph in light snapshots (a vibrancy filter
  the bitmap skipped); "Not built yet" is said once on Outputs; the writing model's name comes from
  Settings, not from text typed into the view.
- Every check, measurement and decision is in `docs/BUILD-LOG.md`.

## 2026-10-10, Sat: Prakriti for Mac, milestone 1 (skeleton)

- **The Mac app exists, signed, and does nothing dangerous yet.** `mac/` holds a SwiftUI app
  (`studio.therowan.prakriti.app`, macOS 27, no sandbox, Apple Development certificate, hardened
  runtime) with the main window Ivan asked for (Today, Recordings, Sources, Outputs, Models,
  Activity, Settings), a menu bar menu, and a SwiftData store for sources, recordings, output
  settings, runs and log lines. Why a skeleton first: every later milestone (pipeline, watcher,
  notifications, models) lands into these screens and this store, so their shape and their rules
  (17 pt body, no em dashes, the status words of SCOPE 9.2, the privacy lock) are fixed once, with
  tests, before any real work flows through them.
- **It runs in development mode on purpose.** It only knows `~/Prakriti/Dev` and its own store,
  and its status line says "Not watching yet. The old engine still handles new recordings."
  Why: engine v0 is making episode 1 for Fri 23 Oct; nothing may compete with it until the
  milestone 3 switch-over.
- **It keeps running with its window closed,** proven by a self-check launch (`make check`).
  Why: macOS quits windowless apps on its own unless they opt out, and the watcher will live here.
- **Every screen is drawn to PNG by a test, in light and dark, and was looked at.** Liquid Glass
  draws as solid white in a bitmap, so the test composes the real sidebar view over the system
  background (START_HERE, warning 7 for the Mac app). The look-through caught real problems
  before they shipped: paths wrapping across two lines, a duplicated heading on every output,
  a stepper value stranded mid-row, an empty state repeating its headline, and "1 hr 1 min"
  for a 61:42 recording (now "1 hr 2 min").
- Decisions, every check with its result, and what Ivan needs to do are in `docs/BUILD-LOG.md`.

## 2026-10-08, Thu: feedback round 3

- **Engine v0, 8 Oct evening.** Ivan had 10% of his usage left and asked for whatever gets Prakriti into use. Built `engine/prakriti.mjs` + a LaunchAgent: watch, readiness, sound check, Parakeet transcript with coverage check, mastered MP3, REPORT.md, three notifications. Tested on the silent 09-14 class (refused in 1 s after the stability wait) and the 09-13 talk (16 min in 36 s). Two mastering bugs found only by measuring the output: the limiter's default auto-level pushed peaks to +2.2 dBFS, and resampling after the limiter put them back over 0. Both fixed and commented in the code. Publishing stays manual; speaker labels and name muting are not in v0, and the report says so.

- **Live, 8 Oct evening.** Deployed to prakriti.therowan.studio. Cloudflare Web Analytics (automatic setup on the therowan.studio zone) was injecting a beacon script that the CSP blocked on every page; HTML now carries `Cache-Control: no-transform` so the edge leaves pages alone, rather than loosening the CSP. Verified live: 200 on / and /roadmap, 404 on /.git/config, /wrangler.jsonc and junk paths, headers present, http redirects to https, no console errors.

### Why this round happened

Round 2 asked whether the plan would run; round 3 asked whether it would run in the hours actually
booked, and whether the pages promise only what the process can keep. Six critics found about 100
features sitting in about 24 hours of sessions, with every safeguard of the autonomous engine landing
after the 25 it protects; the pages promising 25 against about 5 qualifying talks; Gabriel's yes to
episode 1 voiding itself if Serenity's passage were cut; Sonny, who is Claude, about to draft
Serenity's assessment from her transcripts; and the podcast's "Yoga Marga account" turning out to be
the account that runs VeraSales production. Each would have broken in front of Gabriel or Serenity
within two weeks, so it was cheaper to fix on paper today, before the Fri 9 Oct messages.

### Feedback rounds

- **Six lenses:** Gabriel, Serenity, brand and copy, HIG and accessibility, engineer, and COO
  completeness.
- **108 findings.** 0 rejected outright. 82 accepted as written and 26 with a modification.
- **Seven parts of fixes were rejected,** each with its reason in `docs/FEEDBACK.md`: a session-run
  command-line engine (E1; Ivan's 10-08 request is autonomous watching with Mac notifications); a
  day-one share link (G10; no such page exists, and a show page is new scope); holding the 18 if the
  show is not yet listed (G10; no privacy gain, and the 25 is counted on the feed); a separate list
  screen of archive pieces (H2; capacity, and the session email lists every piece); thumbnails asked
  by Fri 16 Oct (G14; podcast approvals carry none, so it moves to Fri 6 Nov); Prakriti's own
  automatic release slots from Fri 30 Oct (C14 b, E1; Ivan's release script runs until Fri 6 Nov);
  and moving the private calls without Serenity's yes (C18; it becomes Q-S23's suggestion).
- **The top changes, and why:**
  - **The cut line.** Sonny sizes the work on Fri 9 Oct, before the two messages, and writes down
    what is built by Fri 6 Nov and what waits. The quiet-engine email, the daily sweep, backups and
    one-step takedown move above it, because they protect the 25; every YouTube API task, Web Push and
    Prakriti's own release slots go below it. If the set above does not fit, Ivan books more sessions
    or resets the number that day.
  - **The 25 are proposed podcast episodes,** counted on the feed and confirmed with Gabriel on Fri 9
    Oct with two counts. The fallback is "10 by Fri 6 Nov, and 25 once Serenity's talks are cleared",
    because "or class stretches" contradicted the privacy promise.
  - **YouTube after Fri 6 Nov.** Archive talks go to YouTube from Mon 9 Nov, at most two a day,
    because the build could not carry the YouTube work in time and no Zoom-era frame had been
    checked; the Mon 26 Oct shortlist reports how many qualify. The account holder's sitting and the
    YouTube tests move to the week of Mon 26 Oct, through the production project.
  - **Episode 1 in two versions.** A with the passage that names Serenity, B without; Gabriel approves
    both in one written yes; her reply, or her silence by the end of Thu 22 Oct, picks. Her answer can
    no longer void his yes.
  - **Ivan as the listener.** Ivan listens at the queued moments of every archive piece before it
    reaches its approver, logged with who and when, and his time is measured on the Sun 6 Sep talk
    before it is budgeted. Gabriel's 2 minutes become "Proposed", his goal only if he says yes,
    because he never said it (09 l.71 proposed it).
  - **The students-present question.** "Teacher-only" is defined once; until Serenity answers Q-S30,
    nothing from a session where students were present goes public, whether they spoke or only
    listened.
  - **Two meetings for Serenity.** The week of Mon 12 Oct, with three questions needed by Fri 16 Oct
    (the name list, students who only listened, and Claude including Sonny), and 30 minutes on Tue 27
    Oct for the rest, due Fri 30 Oct. Until she says yes to Q-S13, no Claude session reads her
    teaching or any class.
  - **The new Cloudflare account.** The podcast's home is a new account on a Yoga Marga address, with
    Gabriel as owner, created at the studio visit with his yes to the address cost, not his existing
    account.
  - **Money off the page.** The terms, the price, who pays for the lawyer and the certificate live in
    PLAN.md only; the lawyer question on the page carries no payment.
- **The full record** of every finding, the fourteen conflicts between critics, and the seven round 3
  spine corrections pending for Ivan: `docs/FEEDBACK.md`, Round 3. DECISIONS.md was not edited.

### What the docs implementer changed

- **PLAN.md:** the cut line (a new section, written Fri 9 Oct, with row 23 moved ahead of row 4 and
  one ordered Fri 9 Oct checklist); the 25 as proposed podcast episodes with two counts and the new
  release plan; episode 1 rewritten around two versions; Ivan's listen in Gates and "Time it takes",
  with the critics' 6 to 7 minutes a piece recorded as their estimate, OPEN until measured;
  "teacher-only" defined once; Serenity's two meetings; the new Cloudflare account in Q-G2, row 19 and
  the feed home (ready Tue 20 Oct); Gabriel's seven things and "yes to the suggestions"; consent
  before the screen exists; the takedown runbook Gabriel can run; the account holder's sitting and
  the YouTube tests moved to the week of Mon 26 Oct, and archive YouTube after Fri 6 Nov; Q-G28, Q-G29, Q-S28, Q-S29 and Q-S30;
  the round 3 spine corrections. Why: the critics found the plan honest but not sized, and three of
  its dated promises would have broken themselves.
- **docs/SCOPE.md:** the Phase column reconciled to the cut line; privacy (Ivan's listen in PRV-05,
  the student rule and the privacy promise rewritten word for word, teacher-only defined in §5.16,
  Serenity's receipt for any piece with an Other voice, "my partner" counted as naming her, Q-S16 and
  Q-S23 defaults, LIB-10, LIB-12 and BIZ-06 gated, PRV-07, PRV-14, ACC-04, ACC-05 and ACC-07 Decided);
  the review page ("Not Yet...", Keep / Cut / Add a Note), one email per approval session with no
  approve link, Approved never alerting, the engine notice opened through `userInfo`; the engine and
  cloud (awake-time timeouts, an event outbox, integrity hashed in the Worker because R2 multipart has
  no conditional put, a "Taken down" state, Hybrid MP4 fixtures on the synced copy, the model
  registry, release slots across Sun 1 Nov, `review_links`, `delegations` and `listens` tables); and
  §11.9 and §18 regenerated from PLAN.md's question table. Why: E2 to E7 and S1 to S3 would each have
  surfaced in the first build week or the first archive approval.
- **README.md:** the student rule and the privacy promise word for word; who uploads; the proposed
  25 as podcast episodes; YouTube after Fri 6 Nov; Gabriel's seven things; Serenity's two meetings
  and the channel confirmation as hers only; the repeated Never-list sentences cut. Why: it is read by
  Gabriel and Serenity and stated proposed numbers as facts.
- **START_HERE.md:** current-state lines that match PLAN; a "Facts for the build" table (team
  LD587PB2H8, proposed bundle IDs and D1 name, the `wrangler login` re-auth, the keychain step for
  the archive drive); the `.gitignore` edit as the first step of row 21; warnings 27 to 34, each with
  its reason.
- **Site changes** (`web/public`, `web/src`) are recorded by the site implementer in
  `docs/FEEDBACK.md`, Round 3, "What changed".

### Not done, as of writing this entry

- Nothing deployed, committed or sent. `.gitignore` and `research/DECISIONS.md` are unchanged: the
  `.gitignore` edit is the first step of PLAN.md row 21, and DECISIONS v2 is Ivan's by Mon 12 Oct.
- The sizing, the cut line, the count and the two messages are Fri 9 Oct work; the money statements'
  times in the Sun 6 Sep talk are re-found from its transcript for the private message, not written
  into any document.

---

## 2026-10-08, Thu: feedback round 2

### Why this round happened

Round 1 made the plan honest; round 2 asked whether it would run. Six critics read the revised
pages and found that the 25 rested on a small, uncounted pool, that every fallback handed uploading
back to Gabriel, that episode 1 quietly waited on Serenity a day before she could sign in, and that
the engine had six blockers, one of which would have sent students' words to Claude before they
were removed. Each would have surfaced in week one, in front of Gabriel and Serenity, so it was
cheaper to fix it on paper today.

### Feedback rounds

- **Six lenses:** Gabriel, Serenity, brand and copy, HIG and accessibility, engineer, and COO
  completeness.
- **127 findings.** 0 rejected outright. 24 accepted with a modification.
- **Seven parts of fixes were rejected,** each with its reason in `docs/FEEDBACK.md`: Transistor as a
  no-answer default (money never defaults); a Mon 19 Oct episode 1 (the show's home and Serenity's
  look cannot be ready); Ivan alone choosing the always-on Mac (D2 says Ivan and Gabriel); quoting
  Google's consent wording before it is seen; "Keep as Video Only" ("Keep as B-Roll" is Gabriel's own
  word); Fri 16 Oct for the lawyer (Fri 23 Oct instead); and Serenity's privacy set on Fri 23 Oct (Fri
  30 Oct instead, after her assessment).
- **The top changes, and why:**
  - **A new show at its own address, and Ivan does every upload.** A new Yoga Marga show that Gabriel
    names, on a web address bought only for the podcast and held in Yoga Marga's own Cloudflare
    account, so `yogamarga.school` and its email are never touched. Gabriel never uploads, posts to
    the podcast or submits, because his goal is to get out of their own way. With no answer, the
    first episode waits for the show's home rather than going somewhere temporary.
  - **The trailer is dropped.** It had no way to approve it and would have gone out before anyone
    could stop it; Gabriel's recorded intro opens episode 1 instead.
  - **Episode 1 by private link.** Made on the Mac by Wed 21 Oct (by hand with ffmpeg as a fallback);
    Serenity's private link Wed 21 Oct, with the passage naming her cut if she has not replied by the
    end of Thu 22 Oct; Gabriel's written yes to the exact files Thu 22 Oct; Ivan uploads Fri 23 Oct.
  - **Sign-in by Mon 26 Oct.** Sign-in, the review screen, Pause All Publishing, the activity log,
    the cost ledger and the email notice move out of the Phase 1 week to Mon 26 Oct, before archive
    approvals; Web Push after Fri 6 Nov. Phase 1 had 16 rows for about 12 booked hours.
  - **Serenity's privacy set moves to Fri 30 Oct,** after the assessment she asked for, with each
    question's most private setting until she answers, so none of them holds up Gabriel's 25.
  - **The 25 is counted and, if needed, reset on Fri 9 Oct.** A first metadata screen (PLAN.md row
    5) found the pool of Gabriel-only talks small, so the count goes in the Fri 9 Oct message with
    three numbers, and the suggested fallback is his own "10".
  - **Engine blockers E2 to E6:** every cloud call after redaction (the lexicon stage is local);
    "finished" for Hybrid MP4 only from studio-visit fixtures; one feed publisher writing into Yoga
    Marga's bucket (a Worker cannot read D1 across accounts); an editorial endpoint for Claude's
    results; and a launch plist where Quit stays quit.
- **The full record** of every finding, the conflicts between critics, and the round 2 spine
  corrections pending for Ivan: `docs/FEEDBACK.md`, Round 2. DECISIONS.md was not edited.

### What the docs implementer changed

- **PLAN.md:** the 25 counted in three numbers on Fri 9 Oct with the reset that day; the podcast's
  home (Q-G2 with Q-G3 merged in, new Q-G26); Phase 1 rewritten as the shortest safe path with no
  trailer; the app pieces moved to "Before approvals open (by Mon 26 Oct)"; old order 2 after Fri 6
  Nov; dates moved and new questions (Q-G27, Q-S24 to Q-S27, Q-I20 to Q-I22); new rows for the
  pre-deploy sequence, DECISIONS v2, build sessions and the weekly call; the privacy-proof gate
  split by teacher; American spelling. Why: the critics found the plan was honest but would not run
  as written.
- **docs/SCOPE.md:** the engine (§6.4 rows, §7.2 plist and timeouts, §7.3 fixtures, §7.4 stage 11
  local and stage 15 checked against stages 9 and 14, §7.8 hand-label screen, §7.13 multipart through
  the Worker), the single feed publisher (§12.1), the YouTube connection and the no-delete rule
  (§12.3, PR-26), privacy (name check before any flip, Serenity as a required viewer, own-life
  passages, segment inheritance, consents only from the teacher's own account), notifications and
  sign-in (§8, §9), data tables (§10.1), and §11.9 and §18 regenerated from PLAN. Why: E2 to E6 would
  have failed in the first build week, and S1 would have published a student's name.
- **README.md:** status and asks per round 2; the private-calls and "never uploads" wording; American
  spelling; the "catalog" sentence cut. Why: it promised a trailer and a sign-in week that no longer
  exist.
- **START_HERE.md:** warnings 19 to 26 with reasons, the http-to-https 301 smoke check, the
  pre-deploy sequence, and current-state lines that match PLAN.
- **Site changes** (`web/public`, `web/src`) are recorded by the site implementer in
  `docs/FEEDBACK.md`, Round 2, "What changed", Site.

### Not done, as of writing this entry

- Nothing deployed, committed or sent. `.gitignore` and `research/DECISIONS.md` are unchanged.
- Round 3 has not run.

---

## 2026-10-08, Thu: feedback round 1

### Why this round happened

Ivan asked for three rounds of self-feedback on the scope and the pages, each reasoned and then
implemented. Round 1 put everything written earlier today in front of six critics before anyone
outside the session sees it, because the front door and the Fri 9 Oct messages are the first things
Gabriel and Serenity will read, and a promise that breaks in week one costs more than a day of
revision.

### Feedback rounds

- **Six lenses:** Gabriel, Serenity, brand and copy, HIG and accessibility, engineer, and COO
  completeness.
- **141 findings.** 0 rejected outright. 46 accepted with a modification.
- **Five parts of fixes were rejected,** each with its reason in `docs/FEEDBACK.md`: dates inside the
  sign-in buttons (G21); quoting the income claim on the page (G8, S3); using the class note before
  a lawyer reads it (S21); single digits of asks across all phases (G2); harvesting student names by
  OCR (E8).
- **The top changes, and why:**
  - **The privacy promise is now the check, not perfection.** The front page repeated a voice
    separation promise that already failed on Sun 20 Sep. Speaker verification moves to short
    windows, every exact MP3 gets a post-render check, the receipt gains a "Listen here" row, and a
    person listens before anything goes out.
  - **The 25 no longer rests on Serenity.** It is Gabriel's goal, counted from teacher-only talks;
    her pieces count only if and when she says yes. Her privacy answers move to Fri 23 Oct after a
    meeting in the week of Mon 12 Oct, with the most private setting until then, and the voice
    question has no date.
  - **The first episode is the Sun 6 Sep talk,** not a new talk that may never be recorded, because
    input stopped on Wed 23 Sep. A trailer from Gabriel's intro may come first, Mon 19 Oct.
  - **Gabriel's asks shrink.** Setup moves to one Ivan studio visit; operational questions carry "no
    answer: the suggestion stands"; one message to each person on Fri 9 Oct.
  - **One rule each, everywhere,** for who approves, students, AI voices and faces, and publish
    unless stopped. A new question names the channel's owner (Q-GS7).
  - **The engine became buildable:** a one-page API contract and a written process model before any
    engine code, readiness aware of Hybrid MP4, a yes tied to a publication manifest, no raw upload
    to the cloud ever, and an always-on host plan that survives FileVault restarts.
  - **The feed belongs to Yoga Marga:** its domain and bucket in a Cloudflare account Yoga Marga
    owns, with RedCircle by hand until that is settled. RedCircle forwarding is unverified until
    Ivan checks its help pages.
  - **Facts corrected:** the Takeout is about 388 GB, not 1 to 2.7 TB, so it fits on Ivan's Mac and
    the salvage starts now; none of the archive is transcribed yet.
- **The full record** of every finding, the conflicts between critics, and the spine corrections
  pending for Ivan: `docs/FEEDBACK.md`. DECISIONS.md was not edited.

### What the docs implementer changed

- **PLAN.md** rewritten throughout: current state, the goal rows, a new "next few days" list (one
  message each on Fri 9 Oct, the metadata count, RedCircle check, scripts, the studio visit, brand
  verification), gates (publication manifest, the approvals rule, the student and AI rules, a
  privacy proof split by content type, the money gate with lanes defined once, the FileVault host
  items), Phases 0 to 5, a new "Time it takes" section, the open questions re-sorted with every
  weekday recomputed, "Spine corrections pending" and "Since the 7 Oct page". Why: the critics found
  the same fact stated differently across documents, and Gabriel was carrying about 50 asks.
- **docs/SCOPE.md** revised to match: the engine API contract (§6.4), the process model, readiness,
  coverage, identity, window verification, roster seeding, mastering, uploads and the always-on host
  (§7); data tables (§10); the feed and YouTube (§12); navigation, the review screen, states,
  keyboard and VoiceOver (§9); notifications (§8); the receipt, the rules and the questions (§4, §5,
  §11, §18). Why: the engineer's blockers (E1 to E6) would have failed in the first build week.
- **README.md** for Gabriel and Serenity: the Never list, the student and AI rules and the privacy
  promise in their shared wording; current dates and asks; no "lane". Why: it promised a perfection
  the process cannot keep.
- **START_HERE.md:** five new load-bearing warnings with reasons, a pointer to `docs/FEEDBACK.md`,
  and current-state lines that match the code on disk.

### Not done, as of writing this entry

- Nothing deployed, committed or sent. `.gitignore` is unchanged: keeping research 01 to 09 out of
  git and adding media types are recorded in PLAN.md (row 3) for the first commit.
- Rounds 2 and 3 have not run.

---

## 2026-10-08, Thu: named, researched, scoped and planned

### Why this session happened

On Wed 7 Oct Ivan described a package to Gabriel (podcast audio, an edited video, three
thumbnails, a quality score, a speaker-tagged transcript feeding each teacher's knowledge base,
clean voice audio) and Gabriel called it brilliant. His goal, in his words: "get out of our own
way". The complaint underneath is about publishing, not production: a zip of outputs is where the
current process already dies. So the vision is a visible public body of work that no longer depends
on anyone's willpower, with numbers attached: 25 archive pieces live by Fri 6 Nov, studio
recordings ready within 72 hours, under 2 minutes of human time per piece.

On Thu 8 Oct Ivan asked for an insanely clear roadmap before any code: every feature anyone had
named plus ones nobody had, built for the web at `prakriti.therowan.studio`, a features page that is
also the sign-in page, folder watching with no further input, macOS notifications at three moments,
and a pass through Apple's platform, Apple's design guidelines, real product UI and the competitive
landscape.

### Named

**Prakriti**, the yoga-philosophy word for primordial matter, replacing the roadmap's working name
"The Processor", which read as a computer chip. Ivan's image was the *Voyager* replicator minus its
flaw: it does not rebuild from a catalog of finished products, it recomposes raw material into
something new. Prakriti says that almost word for word, and it comes from Yoga Marga's own
tradition, so Gabriel and Serenity read it instantly. One name covers the whole engine (a split
into two names was declined). "Fabricator" tied and is held for a later project. Caveat carried
forward: the word is opaque outside the school; revisit if Prakriti is ever sold as a product.
Recorded in the vault's `40 Decisions/` note dated 2026-10-08.

### Researched: nine tracks, read-only

Each track wrote one file in `research/`, with sources for every claim.

| Track | The question it answered |
|---|---|
| 01 Conversations | What has everyone actually asked for, promised and decided since July? |
| 02 Apple platform | What can a Mac do for this, measured on Ivan's M5 Pro? |
| 03 Apple HIG | What do Apple's guidelines say about the front door, the menu bar and notifications? |
| 04 UI patterns | How do the best products handle sign-in, queues, review, libraries and notifications? |
| 05 Landscape | What exists already, what is missing for Yoga Marga, and what to buy versus build? |
| 06 APIs | What do YouTube, the podcast hosts, ElevenLabs, Auphonic and Claude really allow and cost? |
| 07 Infrastructure | What does Ivan already run that can be reused, and what is broken? |
| 08 Privacy and rights | What do consent, biometrics, music, minors and disclosure rules require? |
| 09 Ideas | What would help that nobody has thought of yet? |

Sonny then wrote `research/DECISIONS.md`, the decision spine (D1 to D16). Where research and
DECISIONS disagree, DECISIONS wins.

### The facts that changed the plan

Each of these was measured or sourced, and each one moved something.

- **The archive is 958 videos, about 1,175 hours**, mostly unlisted, and mostly Serenity teaching.
  It includes guest teachers, student practicums, 114 untitled test uploads, about 33 duplicates and
  a private playlist of 1:1 coaching calls. So the archive needs sorting and a quarantine before
  anything else, and the 25-by-Fri-6-Nov number depends on Serenity.
- **The studio folder is 6 real sessions, about 5.4 hours**, not 12 recordings: twins and short
  tests. So the unit became the session, not the file (D7), and tests file themselves silently.
- **The Mon 14 Sep class has a completely silent audio track**, and nobody noticed for 24 days. So
  the sound check runs first, and a silent file is a same-day decision.
- **Every studio file is one microphone duplicated into two channels**, and speaker labels put a
  student's personal story under the teacher's name. So speaker separation cannot carry the privacy
  promise alone: the software fails closed (an unknown voice is a student), and the real fix is
  upstream, one track per microphone in OBS.
- **Students were told the recordings are for the private community.** So publishing classes is a
  new purpose that needs new consent, and classes are gated on Serenity's rule.
- **RedCircle and Spotify have no upload API.** So the only truly hands-off podcast is a feed
  Prakriti hosts itself (recommended) or a host with an API.
- **ElevenLabs lets a person clone only their own voice.** So Prakriti prepares clean, consented
  datasets and never clones anyone.
- **Apple Podcasts requires AI disclosure** whenever an AI voice is used. So a real recorded intro
  is recommended.
- **A browser cannot watch a folder** for this team, and a Cloudflare Worker cannot take a file over
  100 MB or run ffmpeg. **Apple's on-device speech engine ran at 97 to 206 times real time** on the
  M5 Pro. So the heavy work belongs on a Mac, and it is free.
- **Optimize Mac Storage is on, and OBS writes the file when recording starts.** So a new file is
  not a finished recording; the engine needs a readiness rule.
- **R2 is not enabled, and there is no Developer ID certificate.** Two owner actions, now on the
  plan with dates.
- **New enrollment has been paused since January**, and talks contain spoken promises and an
  earnings figure. So archive pieces need a stale-truth check and an accuracy checklist.
- **The partial Takeout of the channel is about 69% downloaded and its link likely expired today.**
  So the owner re-runs it, and the complete files are salvaged now.

### The decision: hybrid, one engine and one shared room (D1)

A small native Mac app (the engine) watches the folder and does every heavy step where the files
live; a web app at `prakriti.therowan.studio` (Cloudflare Worker, D1, R2, built on the Up Next
template) is where the three of them review, approve and get notified, on their Macs and iPhones,
with nothing to install. Claude does the editorial thinking.

Why the alternatives lost:

- **Pure web** cannot watch a folder, and cannot move or process multi-gigabyte recordings.
- **Pure native** on three Macs still needs a server for one shared queue and phone notifications,
  and triples the signing and update work for a team with no engineer.
- **Cloud processing** would send students' voices to vendors, and costs about $200 to $2,000 for
  the archive, work the Mac does for free (SCOPE §6.5, numbered §6.4 before round 1).

The engine starts on Ivan's MacBook Pro. Because a laptop travels and sleeps, **the 72-hour
promise starts only when the engine runs on an always-on Mac** (D2), and the web app says plainly
when the engine is asleep.

### The features page is the sign-in page (D14, D15)

Ivan asked for it, most products work this way, and Gabriel and Serenity need to understand what
Prakriti is in one visit before they ever sign in. Two choices keep it honest:

- **The sign-in card states plainly** that sign-in opens with the first lane and invitations come
  from Ivan. There is no app behind it yet, and a form that pretends to work would be the first
  broken promise.
- **The package preview shows the real thing without exposing anyone**: two neutral sentences of
  Gabriel's own words from his studio talks, plain verdicts, three typographic title cards, no
  photographs of people. Serenity's conditions appear on the page as product design, not as fine
  print.

Both pages are unlisted in search, carry strict security headers, and are served only from
`web/public`.

### Scoped and planned

- **`docs/SCOPE.md`**: 244 features in 15 areas and 31 rejected or retired items, each with a
  reason. Every ledger item from track 01 and every idea from track 09 is mapped to a row. Where
  research disagreed, SCOPE §0.3 records 15 reconciliations, for example local transcription over a
  paid cloud service (students' voices stay on the Mac), a self-hosted feed over a paid host, no
  Approve button inside any notification (approving unseen work defeats review), and Sonnet writing
  while Opus judges (model choice is the cost lever).
- **`PLAN.md`**: phases 0 to 5 with dated milestones, an owner for every task, the owner actions
  that block each phase, an exit check someone can look at, what is explicitly not in each phase,
  and the open questions, each with a recommended answer and a date.
- **Gates added**, each because something would otherwise go wrong quietly:
  - **Consent:** nothing with students goes public until Serenity sets her rule; no voice reference
    or voice dataset for anyone without their written yes. Students were promised privacy, and
    voiceprints are biometric data.
  - **Money:** Prakriti is priced before the second lane switches on. Scope has grown on this
    engagement before without a price, and Gabriel raised the question himself on Wed 7 Oct.
  - **Engine host:** the 72-hour clock starts only on an always-on Mac, because that promise is
    already on the record with Gabriel and a laptop cannot keep it.
- **`START_HERE.md`** for whoever picks this up cold, and **`README.md`** for Gabriel and Serenity.

### Not done, as of writing this entry

- No engine code and no app code behind the sign-in. Later in this session the Worker
  (`web/src/index.js`) and the front door (`web/public`: `index.html`, `roadmap.html`, `404.html`,
  `robots.txt`, `assets/`) were written; neither is deployed.
- Nothing deployed. The repository has no commits and no remote; the first commit and a private
  remote come before the first deploy.
- Nothing sent to Gabriel or Serenity. The questions, the note to Gabriel and the first archive
  assessment are on `PLAN.md`'s "This week" list for Ivan to send.

If any of these change later today, they are recorded here, in this entry.
