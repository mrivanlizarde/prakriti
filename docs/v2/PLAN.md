# Prakriti for Mac v2: the build plan

Written Sat 10 Oct 2026 for unattended builder agents, an independent verifier per milestone, and Ivan.
Status: **Proposed, reviewed** (see section 10, "Review", for every change the review made and why). It
turns Ivan's request (`docs/v2/REQUEST.md`, items 1 to 12, plus the podcast-ready output and "post ready")
and the five research and design tracks into fourteen milestones, M0 to M13, built as **31 parts** (M0,
M1, M2a, M2b and so on). A part is one builder session, gets its own verifier and its own ship gate, and
leaves the live app working. A milestone is done when its last part ships.

**Read first, in this order:** `docs/v2/REQUEST.md`, this file, then only the track documents a milestone
names: `research-edit-engine.md` (cited as **EE**), `research-people.md` (**PE**), `design-spec.md`
(**DS**), `help/` (**H** plus the file number), `icons/README.md` (**IC**). Then `START_HERE.md` (its 34
load-bearing warnings, cited as "warning N", and the Mac app's 65, cited as **W** plus the number) and the last entry of `docs/BUILD-LOG.md`.

**Markers.** *Measured* means run on Ivan's M5 Pro (64 GB, macOS 27.2) on Sat 10 Oct 2026. **[unverified]**
means not confirmed against a source or a run; the milestone that depends on it checks it first.
**[proposal]** means a choice made here that Ivan can change without cost. Weekdays were computed with
`date(1)`. This file uses no em or en dashes, so any line can be lifted into the app or the help.

---

## 1. The plan on one page

| Part | What Ivan has when it ships | Depends on |
|---|---|---|
| **M0** Baseline | v1 plus the podcast-ready episode, committed and verified; a test suite that never reads a class | the podcast-ready run finishing |
| **M1** The new icons | The cut-disc icon in the Dock and Finder; six menu bar shapes, the working one animated | M0 |
| **M2a** Help window | Help in the app (search, Help menu search, Show Me links), articles that only describe what is built | M0 |
| **M2b** Welcome window | The five welcome panels on first launch, each row shown only once its feature exists | M2a |
| **M3a** Main window and Settings | Library sidebar, grid and list, the inspector (Outputs, Checks, Info), the Settings window; opening a recording still shows v1's recording page | M2a |
| **M3b** The Viewer | The Viewer playing Original, Podcast and Podcast-ready, the transcript under it, Cut and Keep, Timeline-lite; v1's recording page retired | M3a |
| **M4a** Progress and Activity | Percent, stage, time left and the log line everywhere; the Activity window (Command-9) | M3b |
| **M4b** Capture check | Every track of every new recording measured, with a plain finding and a capture tip; Hybrid MOV accepted | M4a |
| **M5a** The new privacy lock | The v2 lock, failing closed, and the cloud adapter's own check, on v1's existing Claude client; the hardware check | M3a |
| **M5b** Anthropic and OpenAI | Both providers in Settings, Models, keys in the Keychain, model lists from each provider | M5a |
| **M6a** Faces in a recording | Every face found and tracked; the people line on each recording; nothing stored about strangers | M4b, M5b |
| **M6b** Voices and names | Who speaks when (microphone tracks, else the diarizer); faces linked to voices; Who Is Teaching and Name for This Recording; the lock fed by the people check | M6a |
| **M6c** Choices applied to audio | Include, Blur Face, Remove per person and per output, applied to the podcast; the audio output check; names said aloud | M6b |
| **M6d** Hiding in pictures | Faces hidden by Core Image; safe card thumbnails; the Viewer's People overlay | M6c |
| **M7a** People, named | The People gallery with every named person (Name Only included), the consent sheet, the sealed vault, Forget | M6d |
| **M7b** Recognition | Named people with a release found in new recordings, Review, Merge, retention, the calibration harness | M7a |
| **M8a** The edit plan | The rough cut as an `EditPlan` (pauses, fillers, retakes), shown on Timeline-lite; no video yet | M6d |
| **M8b** The rendered MP4 | The MP4, captions file, description and Ready checklist, made only for recordings where everyone is Included | M8a |
| **M8c** Video in the Viewer | The Video rendition through the same compositor; Restore and Remove spans | M8b |
| **M8d** People in the video | Hidden faces and removed speech in the MP4, the picture and audio output checks, video allowed for every recording | M8c |
| **M9a** House style and zooms | Clear, Calm, Energetic, Story; Pace; punch-ins and push-ins; the House Style pane | M8d |
| **M9b** Text and graphics | The typeface, the overlay engine, lower thirds, term cards | M9a |
| **M9c** Beats and direction | The beat annotation, the direction field and chips, selection under a length, the plan before rendering | M9b |
| **M9d** Hook, chapters, versions | Key-phrase text, the hook, chapters, versions, the Direction tab | M9c |
| **M10a** Timelines | FCPXML 1.14 and 1.10, graphics clips, Read Me, Open in Final Cut Pro or DaVinci Resolve, written only when everyone is Included | M9d |
| **M10b** Privacy-safe timeline media | Cleaned media when anyone is hidden, checked like the MP4; timelines for every recording; the round trips | M10a |
| **M11a** Shorts | Vertical shorts with calm captions, the Shorts rendition and the 9:16 guide | M9d |
| **M11b** Thumbnails, Approve, Ready | Three safe thumbnails, upload checklists, the Approve sheet that refuses a failing file, the Ready group | M11a |
| **M12a** Supporting moments, found | The index on this Mac and Find Supporting Moments | M9d |
| **M12b** Supporting moments, added | Adding one by hand, with its date label and join | M12a |
| **M13** Finish line | Every help article and welcome panel true to the build, every check run again, the handover for Ivan | all |

M10, M11 and M12 depend only on M9d and can be built in any order; the order above is the recommended one
(the timeline is what Ivan asked for by name). Each part is sized to one builder session. Where a part
would expose a feature before its privacy protection exists, the part refuses that case **in code** and
says why on screen (M5a before M5b, M8b, M10a); the refusal is lifted only by the part that builds the
protection (M8d, M10b), so no order of shipping can leak a student.

---

## 2. Rules for every milestone

### 2.1 Builder, verifier, ship

1. **The builder** works on a branch `v2-mN`, in development mode only (`--development`, `~/Prakriti/Dev`,
   its own store and log; W1, W10). It writes code, tests, the help articles its feature changes, and a
   dated `docs/BUILD-LOG.md` entry headed "v2 milestone N" in the shape v1 used (what was built, every check
   with its measured result, decisions with reasons, what does not work, what needs Ivan). Docs change in
   the same commit as the code. `git status` is read before every commit and files are staged by name,
   never `git add -A` (warning 2).
2. **The verifier** is a separate agent that did not write the code. It clones the repository at the
   milestone's commit into its own scratch folder, runs every acceptance check in the milestone by itself,
   opens and looks at every PNG the checks produce, launches the real app, and writes
   `screens/mac/v2-mN-verify/verdict.txt`: each check, PASS or FAIL, the measured value, and the file it
   looked at. Reading code is not verification, and a passing test is not either (START_HERE, rules).
3. **Ship gate.** Only after the verdict is PASS on every check marked *ship gate*: the builder merges to
   `main`, runs `make migrate-check` whenever a SwiftData model changed (W33), then `make install` (W21),
   then watches the live log for two heartbeat lines ("Checked 2 folders.") to prove the live watcher
   survived. A FAIL goes back to the builder; nothing is installed on a FAIL. Checks marked *Ivan* never
   block the install; they are listed for him in the BUILD-LOG entry.
4. **Regression set, every milestone (ship gate):** `make test` (every unit and snapshot test),
   `make accept` (as changed in M0), `make accept-edits`. The longer v1 acceptances (`accept-outputs`,
   `accept-models`, about 15 min; `accept-podcast`, about 40 min) run in any milestone that touches their
   code paths, and all of them run in M13.
5. **Real recordings: the 13 Sep and 6 Sep talks only** (Gabriel's talks:
   `Studio Recordings /2026-09-13/2026-09-13 18-25-44.mp4`, 15:48, and
   `Studio Recordings /2026-09-06/2026-09-06 18-06-33.mp4` with its `-vertical` twin, 55:39). Read-only,
   size and date checked unchanged afterwards (W17). **Never a class, never the archive, never the
   SerenityAI download.** Anything a test needs that these two cannot show (a second person, a second
   voice, silence, a second microphone track) is a fixture built from them by `make fixtures` (section 4),
   written only to `~/Prakriti/Dev/Fixtures`.
6. **Never touch Ivan's live data in a check.** No check opens the live store except `make migrate-check`
   (which reads a copy), no check writes into `~/Prakriti/Outputs` or `~/Prakriti/Approved`, and the files
   of episode 1 (`~/Prakriti/Outputs/2026-09-06 18-06-33/`) are never remade: episode 1 ships Fri 23 Oct.
7. **New outputs start off** for every folder and are never made for recordings that already exist, the
   pattern of W56 and W63. Upgrading the app must never start work by itself (no backfill). Existing
   recordings show a button ("Check People", "Make Video") instead.
8. **Parts.** Each milestone below lists its parts and which acceptance checks each part must pass.
   Rules 1 to 3 apply per part: one branch `v2-m6a` and so on, one verifier, one verdict in
   `screens/mac/v2-m6a-verify/`, one ship gate, one BUILD-LOG entry headed "v2 part 6a". The regression
   set (rule 4) is part of every part. A check split across parts says which half each part runs.
   Where a check below writes `MILESTONE=v2-m8`, use the running part's id (`v2-m8a`, `v2-m8b`, ...), so
   each part's pictures and verdict land in their own folder.
9. **Looking at frames of Gabriel, before D1 is answered.** Every fixture is cut from Gabriel's talks, so
   until D1 is answered a check that says "looked at" on a frame showing a face is done by measurement
   only (the numbers the check names) and the PNG is listed for Ivan in the BUILD-LOG entry. That never
   turns a ship gate into a FAIL or a SKIPPED; it moves only the look. Frames with no face (the Help,
   the welcome, Settings, sample data) are looked at as written.
10. **Every check reads something a program can read.** A verifier runs alone, so nothing is judged from
    the menu bar (it cannot be captured without Screen Recording, IC) or from a moving picture. The
    development build gains three debug switches, compiled only into Debug builds and never read by
    the installed app: `--debug-playback-log` (the Viewer's player writes `currentTime` and `rate` to
    the development log once a second), `--debug-status-log` (every change of the menu bar status line
    is written to the development log), `--debug-help-search=<words>` (runs the Help menu search
    handler, prints the article ids it returns, and quits). Checks below that need them say so.
11. **Every video, audio, image and timeline file is made in a staging folder** inside the job folder and
    moved into the output folder only after its output checks pass (W29's staging, extended). A file
    that fails is deleted with the job, so nothing that failed a privacy check ever sits in `Outputs`
    where it could be uploaded by hand.

**Before the build starts (Ivan, about five minutes).** Three answers stop builders from stalling halfway:
yes to swift-markdown 0.9.0 (M2a) and to FluidAudio pinned at the version Hark's `Package.resolved`
records (M6b), and D1 (section 8). A part that reaches a missing yes stops before its first commit and
says which yes it needs; it never fetches first.

### 2.2 Standing rules the builders inherit

- Every v1 warning in START_HERE (W1 to W65) still holds unless a milestone below names one it replaces.
- A compiler warning fails the build (W4), and the macOS 27 SDK deprecates APIs the research used in
  scratch programs: new code uses `try reader.start()` and `reader.outputProvider(for:)`, never
  `startReading()` or `copyNextSampleBuffer()` (PE 1.7; v1 itself calls neither, grep on Sat 10 Oct), and
  `AVVideoComposition.Configuration`, never `AVMutableVideoComposition` (EE 4.2). Two traps from the same
  measurements: `outputProvider(for:)` adds the output itself, so calling `reader.add(output)` first
  crashes ("cannot add an output that has already been added", PE 1.7, measured); and frames go into the
  writer through `AVAssetWriterInput.PixelBufferReceiver` (macOS 26 and later, EE 4.2 item 6), not the
  older append calls. Whether `outputProvider(for:)` accepts an `AVAssetReaderVideoCompositionOutput`
  is **[unverified]**: M8b checks it against the SDK on its first day and records the answer.
- **Privacy by construction, not by care.** Three rules each enforced by a type or a test, not by a
  reviewer remembering:
  1. Every cloud request body is a `CloudPayload`, a type whose only initializer is
     `PrivacyLock.release(_:)`, which runs the lock and the name tokens (M5a). The provider clients take
     nothing else, so no code path can send text that has not passed the lock.
  2. `RulesTests` fails if any file under `People/`, `Render/` or `Export/` names `URLSession`,
     `URLRequest` or a provider client. Face and voice work cannot reach the network. (`Merge/` reaches
     LM Studio's embeddings only through `Writing/`'s local client, which refuses any host but
     `localhost`; a test plants a remote URL and expects the refusal.)
  3. Every rendered or exported file passes one `OutputGate` (rule 2.1.11) that runs the picture and
     audio output checks the file's kind needs; a writer cannot move a file into `Outputs` any other way
     (the move function is private to the gate).
- Every font from `AppFont`, 17 pt body, nothing under 12 pt, no tooltips (W5). No em dashes, no
  "Processing", no "we" in any string (W6); the copy test extends to `Resources/Help` and the welcome text.
- Never skeuomorphic: no film strips, drawn scrubbers, waveforms as decoration, grain or textures. The
  system player is the only scrubber (W43).
- Notices never carry a file name, a title or a person's name (W23).
- No raw recording or removed audio ever leaves the Mac (warning 18). Face and voice work never goes to a
  cloud model, in any configuration (PE 5.5).
- Every stored SwiftData property has a default; enums stored as raw strings; the first change that is
  not an addition brings a `VersionedSchema` (W11).
- Every media file a milestone makes has its last 5 seconds decoded before it is called made (START_HERE,
  rules: verify media by decoding its tail).
- **Swift packages and model downloads are fetched only after Ivan's yes** (listed under "Needs Ivan").
  Each package is pinned to an exact version; each version and its date go in BUILD-LOG.

### 2.3 Where new code goes

| Folder under `mac/Prakriti/` | Holds | First milestone |
|---|---|---|
| `Help/` | Article model, Markdown rendering, search index, Help menu search handler, Quick Help | M2 |
| `Resources/Help/` | The help articles, user text only | M2 |
| `Views/Welcome/` | The welcome window | M2 |
| `Views/Library/`, `Views/Viewer/`, `Views/Inspector/`, `Views/Settings/`, `Views/Activity/` | The new window regions | M3, M4 |
| `Progress/` | Stage progress, measured stage times, time left | M4 |
| `Engine/CaptureCheck.swift` | Every stream and track measured | M4 |
| `Writing/` (existing) | Providers, keys, the hardware check, the privacy lock | M5 |
| `People/` | Faces, tracks, voices, links, decisions, the people file, hiding, the output check, then the gallery and the print vault | M6, M7 |
| `Edit/` | Words, envelope, rough cut, `EditPlan`, beats, direction, selection, styles, visual plan | M8, M9 |
| `Render/` | Composition builder, compositor, overlays, video audio, writer, shorts, thumbnails, Ready checklists | M8, M9, M11 |
| `Export/` | FCPXML writer and lint, timeline media, graphics clips, Read Me | M10 |
| `Merge/` | Embedding index, suggestions | M12 |

Tests go in `mac/PrakritiTests/` as one file per area (`HelpTests`, `LibraryTests`, `ProgressTests`,
`ProviderTests`, `PeopleTests`, `GalleryTests`, `RoughCutTests`, `RenderTests`, `StyleTests`,
`FCPXMLTests`, `ShortsTests`, `MergeTests`) plus one acceptance file per milestone that reads real
recordings, run only by its `make` target, as v1 does.

---

## 3. Every item in REQUEST.md, mapped to milestones

| REQUEST item | What it asks | Where it is built | Where it is verified |
|---|---|---|---|
| 1 | Plan for clean inputs, not the messy first recordings | Capture check and capture tips (M4); multi-track audio as the main path for who speaks (M6); 4K-aware zoom limits (M9); vertical twin or 4K crop for shorts (M11). Poor input gets a check, a warning and a tip, never a silent publish | M4 capture check on 13 Sep (single dual-mono track flagged with its tip); M6 two-track fixture |
| 2a | A startup screen with usage tips, including how to capture the best video | Welcome window, five panels, panel 2 on capture (M2b), copy finalized (M13) | M2b, M13 |
| 2b | Documentation for the help section | Help window, search, Help menu search, Show Me links, the eleven articles from `help/` (M2a); each later part updates its articles; final pass (M13) | M2a `make accept-help`; every milestone's copy test; M13 |
| 3a | Flag faces; say when it is Gabriel or Serenity, or other people | People pass, people line on each recording, filter, notice (M6a, M6b); automatic recognition of named people with a release (M7b). **Honest gap:** until a release is signed (D2), Prakriti finds and counts every face and voice by itself, but it is Ivan who says "this is Gabriel" (Who Is Teaching, one pick per recording). Recognizing Gabriel without being told is biometric, so it waits for his release by design | M6a, M6b on 13 Sep and the two-person fixture; M7b with Ivan's own clip |
| 3b | Choose who is included in the output videos and audio | Include, Blur Face, Remove per person and per output (M6), applied to audio (M6), video (M8), timelines (M10), shorts and thumbnails (M11) | M6, M8, M10, M11, each with an output check that re-finds faces and voices |
| 4 | Edited output plus FCP or DaVinci XML; remove pauses, umms, bad takes; captions; text animation; transitions; zooms; MKBHD as the template; 100% ready; least friction | Rough cut and render (M8); house style, text, zooms, transitions, direction (M9); FCPXML 1.14 and 1.10 (M10); shorts, thumbnails, Ready checklists, Approve (M11) | M8 to M11 |
| 5 | Room for an OpenAI or Anthropic API on a less powerful Mac | Both providers, keys in the Keychain, the hardware check and its suggestion, the privacy lock (M5) | M5 |
| 6 | Progress on each recording while it works | Stage, percent, time left, log line on the card, inspector, Viewer, toolbar, menu bar, Activity window (M4); render and people stages report real progress (M6, M8) | M4, and every later milestone's progress trace |
| 7 | Prompt or adjust the editorialization ("more energetic", "faster cuts", "focus on motivating") | Presets, direction field, chips, the plan before rendering, versions (M9) | M9 on 13 Sep |
| 8 | A gallery of recognized faces, like Photos | People gallery with every named person from the first day, Name Only included, so a returning subject has a page of recordings before any release (M7a); recognition, Review, Merge (M7b) | M7a, M7b |
| 9 | Merge sections from different videos, by hand, not as a rule | Find Supporting Moments, add by hand, date label (M12) | M12, 6 Sep into 13 Sep |
| 10 | Preview inside the app; build a viewer | The Viewer with Original and Podcast (M3), Video through the same compositor that renders the file (M8), Shorts (M11), People and Captions overlays and the 9:16 guide (M6, M8, M11) | M3, M8, M11 |
| 11 | Another UI pass: how would Apple build it (iPhoto, FCP, Apple creative apps) | The DS main window, Settings window, Activity window, Viewer, inspector (M3, M4); People in the sidebar (M7) | M3, M4, real-window captures every milestone |
| 12 | A better icon for the Dock and the menu bar | "Recomposed" from IC (M1) | M1 |
| Earlier the same day | Podcast-ready audio | Being finished by another run; landed and verified in M0; its section moves into the inspector (M3); people choices apply to it (M6) | M0, M3, M6 |
| Earlier the same day | "Videos to also be post ready" | Ready checklist for YouTube (M8), shorts and upload checklists (M11) | M8, M11 |
| Decision: students are the privacy subject | Unnamed people default to Remove (face blurred, speech cut) | M6 | M6 |
| Decision: biometric data policy | Prints only for named people with a release; none on disk for anyone else | M6 (nothing stored), M7 (gallery) | M6 check 7, M7 checks |
| Decision: MKBHD grammar, not brand | House style numbers from EE 2.3; no logo, colors, fonts, stings | M9 | M9 |
| Decision: 100% ready | Measured platform checklists; Approve refused while a chosen file fails | M8, M11 | M8, M11 |
| Decision: two deliverables per video | MP4 (M8) and timelines (M10), plus the privacy-safe media the timelines point at (M10) | M8, M10 | M10 |
| Decision: real-frame thumbnails for Gabriel and Serenity | Safe-frame rule | M6 (cards), M11 (YouTube thumbnails) | M6, M11 |
| Decision: privacy lock relaxed | Lock = a class, or anyone heard who has not allowed cloud reading, or people not checked yet, or other people present | M5 (rule, failing closed), M6 (fed by the people pass) | M5, M6 |

---

## 4. Shared fixtures (`make fixtures`)

Built by `mac/scripts/make-fixtures.sh` from the two talks with ffmpeg and macOS `say`, into
`~/Prakriti/Dev/Fixtures/`. Each is regenerated byte for byte from its recipe, and its recipe is in the
script with the reason. None contains a student, a class or anything from the archive.

| Fixture | Recipe | Used for |
|---|---|---|
| `13sep-90s.mp4` | `-c copy` of 13 Sep, 5:00 to 6:30 (v1 already cuts 90 s clips this way) | Fast runs |
| `silent-60s.mp4` | 13 Sep picture, 65 s, audio replaced by digital silence | The silence rule; replaces the 14 Sep class in `make accept` (M0) |
| `two-people-mixed.mp4` | `13sep-90s` with the 6 Sep picture laid in the lower right corner at 30% size from 0:20 to 0:60, and a 20 s passage of `say -v Samantha` reading a fixed paragraph mixed into the single track at 0:30 | A second face and a second voice on one mixed track (the diarizer path). The corner face is Gabriel too, but with nobody enrolled it is "Unnamed 1", which is all the hiding and output checks need |
| `two-people-tracks.mov` | The same picture; track 1 the mix, track 2 the 13 Sep voice alone, track 3 the `say` voice alone (the OBS layout in H03) | The clean-input path: who speaks from microphone tracks |
| `ivan-clip.mov` (only after Ivan records it) | Ivan's own 2-minute clip, his face and voice, recorded by him on this Mac | Enrolling a named person with a release, recognition, Forget (M7). Optional; M7 ships without it |
| `ivan-plus-13sep.mov` | `13sep-90s` with `ivan-clip` laid in a corner and his voice on track 3 | Named and unnamed in one frame (M7) |
| `ums-and-retake.wav` | 30 s of `say` text with planted "um", "uh", a stutter, a spoken "let me start over" restart, and a parallel-phrasing pair | Rough-cut unit tests where the right answer is known (M8) |
| `synthetic-transcript.json` | A made-up talk in Parakeet's JSON shape, about 4,000 words, naming no real person | Cloud provider tests (M5) until D1 is answered |

---

## 5. Defaults this plan takes (no answer needed; change any of them freely)

Each is a recommendation from a track that sits inside Ivan's brief. They are written into the build as
defaults, and the BUILD-LOG of the milestone that builds each one says so.

| Default | Source | Note |
|---|---|---|
| The three choices are **Include**, **Blur Face** (heard, face blurred) and **Remove** (speech cut, face blurred wherever it still shows). Unnamed people default to Remove | DS 3.5.2, with PE 3.1's meanings | Same as REQUEST's default. H07 used "Blur" for face and voice together; it is rewritten in M6 |
| "Ready for your yes" becomes **"Waiting for your yes"**; "Ready" means approved and passing every check | DS C1 | Display text only; the stored raw value `readyForYourYes` stays, so no migration |
| Dark-mode text accent `#7D8BFF`; `#4459E8` stays for fills | DS C7, measured 3.05 to 1 | |
| The privacy-lock line names the real reason, never Serenity | DS C4 | |
| Gallery has one face-less "Unnamed people" tile; unnamed faces appear only in their own recording, cropped live, never saved | DS C2, PE 2.3 | |
| The people file keeps a face picture only for a named person who may appear (Gabriel, Serenity, anyone Ivan marks so). Every other track keeps times and boxes; its picture is cropped live from the video when the People tab is open | DS C2, REQUEST (real frames allowed for Gabriel and Serenity) | PE 2.1 step 8 said "one thumbnail per track", which would store a picture of every student. Changed in review |
| Named people appear in the gallery from the day they are named, Name Only included: a key photo from a real frame for people who may appear, a monogram for anyone else, their recordings, minutes on screen and speaking (from per-recording naming), and the line "Recognition off. Named by you in each recording." | REQUEST item 8, DS 3.9 | Not biometric: no print, only Ivan's own naming. Gives Ivan the returning-subject page before any release. Added in review |
| Clips from another day carry their date on screen, on by default | DS C6 | Serenity's accuracy condition |
| Approve is refused while a chosen deliverable fails a check | DS C8 | |
| Outputs, Models and Settings move to a Settings window; Activity to its own window | DS C5 | |
| Classes stay unapprovable, as in v1 (W35). Talks and conversations become approvable once every person has a choice, the output check passes, and any mixed-track recording with a second voice has had its flagged moments listened to | H06 asked; v1 rule kept for classes | Lifting it for classes is for Ivan and Serenity later, not a build default |
| Unnamed people: no prints on disk at all; strangers grouped by continuous tracks; "up to N other people at once" | PE 2.1, 5.1 | Stricter than REQUEST's "deleted after the job" |
| Recognition needs a written release (date, where kept, face and voice switches); **Name Only** for everyone else. Being named for a recording (no prints) is enough to be Included, and Gabriel and Serenity may be Included (REQUEST) | PE 5.3, REQUEST | Recognition and appearing are separate consents |
| Prints deleted 12 months after a person last appears, with a line in Needs You 30 days before | PE 5.4 | |
| Timelines point at privacy-safe media whenever anyone is blurred or removed (about 20 to 22 GB an hour); an APFS clone otherwise | EE 5.5, PE 3.3 | Not optional: without it the timeline undoes the privacy choices |
| Video master -14 LUFS, true peak -1 dBTP or lower, AAC-LC 48 kHz stereo 384 kbps, H.264 High 16 Mbps at 1080p (45 to 60 at 4K) | EE 6.1 | The podcast stays at -16 |
| Captions: a sidecar `.srt` on long-form, burned in calmly on shorts; a House Style switch burns them on long-form too | EE 2.3 | MKBHD burns none (0 of 148 frames). Say so if you want them burned by default |
| Style names: **Clear** (the house style), **Calm**, **Energetic**, **Story**; **Teaching** switch; **Pace**; **Length**; **Focus** chips | EE 2.5 | Ends the clash between DS and H08 |
| Pushed-in zooms and dissolves stay out of shipped timelines until a round trip passes in both apps | EE 5.8, the vault's 2026-07-30 lesson | Markers take their place |
| Typeface for burned text: an SIL OFL family with full IAST coverage, chosen in M9 by rendering "Prāṇāyāma, Īśvara praṇidhāna, Kṛṣṇamācārya" in three candidates (Noto Sans, Source Sans 3, Inter) and looking. Never SF Pro in a video | EE 2.7, E10 | Contact sheet in BUILD-LOG; Ivan can overrule |
| No music and no sound effects by default; a bed only from a folder Ivan fills | EE 2.4 | |
| MKBHD is not named in the help or the app; the style is described in plain words | H08 builder notes | Ivan can overrule |
| OBS: Hybrid MOV and Hybrid MP4 both accepted (OBS 32 records Hybrid MOV on a Mac by default) | H03 | Warning 15 and SCOPE SET-04 are updated in M4 |
| On a Mac that cannot run the local writing model, a class or a recording with other people waits for writing and says why; nothing is sent | H09 gap | Ivan's Mac has 64 GB, so this affects other users only |
| No Dock badge in v2 | IC notes the old reason is stale | A later choice |
| Embeddings for merging always run on this Mac (`text-embedding-nomic-embed-text-v1.5` in LM Studio, listed by its server, measured) | DS 3.8 | Text, not biometrics |
| Names said aloud are checked: person names in the transcript (Apple's `NLTagger`) that are not named people become Check moments, and Approve waits until each is marked Keep or Mute | Serenity's standing condition (zero student names in anything public) | Not in REQUEST; added because a student named by the teacher would otherwise reach the video, the captions and the podcast |

**Found while planning, and fixed in the plan:**

1. v1's `make accept` reads the silent **14 Sep class** (W17, START_HERE "Build, run, test"). The task rule is
   never a class, so M0 replaces it with `silent-60s.mp4`.
2. REQUEST relaxes the lock to "classes or other people", but START_HERE W29 and SCOPE PRV-10 keep
   Serenity's teaching away from any Claude session until Q-S13 is Granted. The lock in M5 therefore has a
   per-person switch, "Cloud models may read their words", off for everyone by default: a recording where
   Serenity speaks stays local until her yes. This keeps both rules.
3. REQUEST's cloud option meets warning 19 (every cloud call after redaction, checked on the data). M5's
   adapter refuses unless the people check ran and found no one without cloud consent, and replaces every
   person name found by `NLTagger` (other than named people with cloud consent) with a token before sending.
4. Two welcome texts exist (DS 4.2 and `help/welcome-panels.md`). M2 uses DS 4.2's window and panel
   structure (it carries the setup panel with the notification ask), fixes its panel 2 line to "In OBS,
   record Hybrid MOV or Hybrid MP4, never MKV", and keeps the help track's capture wording where shorter.
5. The help articles describe v1's sidebar (Today, Recordings, Outputs, Models screens) and v2 names
   that DS changed. Each milestone rewrites the lines its renames touch; M13 checks every UI name in every
   article against the build.
6. PE 1.7 says v1 uses the macOS 27 deprecated `AVAssetReader` calls; a grep of `mac/Prakriti` on Sat 10
   Oct finds none. The rule stands for new code (2.2).

---

## 6. The milestones

Each milestone: **Goal**, **Scope** (in, and out), **Files**, **Acceptance** (numbered checks a verifier
runs alone; *ship gate* unless marked *Ivan*), **Needs Ivan**.

### M0. Baseline: land podcast-ready, retire the class from the checks

**Goal.** Start v2 from a committed, verified v1 that includes the podcast-ready episode, with a test
suite that never reads a class.

**Scope.** In: wait for the podcast-ready run to commit (`PodcastReady.swift`, `PodcastReadyRun.swift`,
`ID3.swift`, `Artwork.swift`, `PodcastReadyViews.swift`, its tests, its BUILD-LOG entry); do not edit
those files while it is running. Then: add `mac/scripts/make-fixtures.sh` and `make fixtures`; change
`PipelineAcceptanceTests` to use `silent-60s.mp4` instead of the 14 Sep class, and the W17 text to "the 13
Sep and 6 Sep talks only"; add `make regress` (test, accept, accept-edits). Out: any v2 feature.

**Files.** `mac/Makefile`, `mac/scripts/make-fixtures.sh` (new), `mac/PrakritiTests/PipelineAcceptanceTests.swift`,
`START_HERE.md` (W17 and the `make accept` paragraph), `docs/BUILD-LOG.md`.

**Acceptance.**
1. `cd ~/Code/prakriti/mac && make test`: every test passes, 0 compiler warnings in the build log.
2. `make accept-podcast MILESTONE=v2-m0` (about 40 min, LM Studio running): its checklist reads PASS for
   loudness (-16 within 1 LU), true peak (at or under -1 dBTP), the tail decode and every tag frame read
   back, on both talks, as its own BUILD-LOG entry states.
3. `make fixtures` twice: every fixture's SHA-256 is the same both times; `ffprobe` shows the stream
   layout the table in section 4 gives (two-people-tracks: 3 audio streams).
4. `make accept MILESTONE=v2-m0`: 13 Sep within -17 to -15 LUFS, true peak at or under -1.0; `silent-60s`
   is Needs a decision with no output folder; and `grep -c "2026-09-14" acceptance.txt` prints 0.
5. `make accept-edits` passes as in v1.
6. The two originals' size and modification date are unchanged after the run.
7. *Ship gate:* `make migrate-check` then `make install`; the live log shows "Checked 2 folders." twice
   after the install.

**Needs Ivan.** Nothing.

**Parts.** One part; it is already one session.

### M1. The new icons

**Goal.** The "Recomposed" mark in the Dock, Finder and menu bar (REQUEST 12).

**Scope.** Exactly IC "Putting it in the app", steps 1 to 6: copy `source/Prakriti.icon` to
`mac/Prakriti/Resources/AppIcon.icon`; remove `AppIcon.appiconset` and `mac/scripts/make_icon.swift`; copy
the seven menu bar image sets into `Assets.xcassets`; `xcodegen generate`; `StatusSummary.Icon.menuBarAsset`;
`MenuBarIcon` draws the asset and keeps its accessibility label; a `WorkingTicker` on the app model swaps
the two working frames every 0.7 s only while work runs and never under Reduce Motion (a `TimelineView` in
a `MenuBarExtra` label draws once, measured in IC). Out: a Dock badge; the website favicon.

**Files.** `mac/Prakriti/Resources/AppIcon.icon/` (new), `Resources/Assets.xcassets/` (seven image sets
added, the app icon set removed), `mac/scripts/make_icon.swift` (removed), `App/StatusSummary.swift`,
`Views/MenuBar.swift`, `App/AppModel.swift` (the ticker), `mac/project.yml` if needed,
`PrakritiTests/RulesTests.swift`, START_HERE ("App icon" row), BUILD-LOG.

**Acceptance.**
1. `make build`: 0 warnings; the built app's `Contents/Resources/Assets.car` lists `AppIcon`
   (`assetutil --info`), and Info.plist has `CFBundleIconName` = `AppIcon`.
2. `make test`: the new test passes (six distinct `menuBarAsset` names, each loads from the bundle as an
   18 by 18 pt template image), and "each menu bar state has its own shape" still passes.
3. A unit test drives `WorkingTicker` on an injected clock: it flips at 0.7 s intervals while working,
   has no timer scheduled while idle (the test reads the ticker's timer, which is `nil`), and never
   starts with Reduce Motion on.
4. `swift scripts/capture-window.swift` or an `NSWorkspace.icon(forFile:)` render of the built app at 512
   and 32 px, saved to `screens/mac/v2-m1/`, looked at beside `docs/v2/icons/previews/sheet-app-icon.png`:
   the cut disc, not the plain dot.
5. *Ivan:* after install, the Dock shows the cut disc (if not, `cd ~ && killall Dock`); the menu bar mark
   alternates while a 90 s clip in `~/Prakriti/Drop` is made, and shows the outline under Pause All; once
   in Dark appearance, once with Icon and widget style set to Tinted. The menu bar cannot be captured
   without Screen Recording permission, so this is his look.

**Needs Ivan.** The look in check 5.

**Parts.** One part.

### M2. Help window and welcome

**Goal.** Help inside the app and a first-launch welcome (REQUEST 2), built so that no article or panel
ever describes something the build does not do.

**Scope.**
- **Articles.** `git mv` the eleven articles `docs/v2/help/00-index.md` to `10-troubleshooting.md`, named
  one by one, never a `*.md` glob (the glob would also carry `welcome-panels.md` into the app as an
  article), to `mac/Prakriti/Resources/Help/`. `welcome-panels.md` moves to `docs/v2/help-notes/` as
  the copy source for M2b. Move every "Builder notes" section into
  `docs/v2/help-notes/<same name>.md` so the app bundle holds user text only; write a new
  `docs/v2/help/README.md` pointing at both. Extend the front matter with `section`, `order` and
  `requires` (DS 5.3).
- **Capabilities.** A `Capabilities` set in the app (`help`, `viewer`, `progress`, `cloudProviders`,
  `people`, `gallery`, `video`, `style`, `timelines`, `shorts`, `merge`), each switched on in code by the
  milestone that builds it. An article whose `requires` is off is hidden; inside an article, a block
  between `:::requires video` and `:::` is hidden when that capability is off. swift-markdown does not
  know the `:::` fence (its own directives are `@Name { }`), so `HelpLibrary` removes or unwraps these
  blocks in a text pass **before** parsing, with its own tests (nested blocks refused, an unclosed
  block fails the build's help test). M2a rewrites each article so that, with only `help` on, every
  visible sentence is true of today's app (v1 plus podcast-ready).
- **Help window** (`Window` id `help`, Command-?): `NavigationSplitView` of sections and articles, the
  article at most 680 pt wide, rendered from swift-markdown blocks into SwiftUI with `AppFont` (DS 5.2,
  5.4). Search as you type over title, keywords, summary and text. Links: `NN-name.md` and
  `prakriti-help://<id>` open an article; `prakriti://show/<place>` renders as a **Show Me** button that
  opens that place. The `prakriti://` scheme is handled inside the Help view only and is **not**
  registered with Launch Services, so no other app or web page can drive Prakriti through it.
- **Help menu search:** `NSApp.registerUserInterfaceItemSearchHandler(_:)` with an
  `NSUserInterfaceItemSearching` handler that returns article ids and opens the Help window (DS 5.5).
  Help menu items: Prakriti Help, Welcome to Prakriti, Show Log in Finder (H10).
- **Welcome window** (`Window` id `welcome`, 720 by 600, `.defaultLaunchBehavior(.presented)` gated on a
  stored `welcomeSeenVersion`, `.restorationBehavior(.disabled)`): DS 4.1 and 4.2, five panels, "1 of 5"
  in words, Back and Continue, closing counts as seen. Each row carries a `requires` capability and is
  hidden until its feature exists, so panel 1 at M2 lists only finding recordings, the podcast and "nothing
  is posted without you". Panel 5's notification button reads the current authorization first: not
  determined, it asks macOS; denied, it reads "Open Notification Settings" and opens System Settings,
  because v1 found notifications off for Prakriti and a second request shows nothing. Never shown under
  `--sample-data` unless `--show=welcome`; never blocks the watcher.
- Quick Help and TipKit wait for M3 (they point at controls that M3 creates).

**Files.** `Help/HelpArticle.swift`, `Help/HelpLibrary.swift`, `Help/HelpRenderer.swift`,
`Help/HelpSearch.swift`, `Help/HelpMenuSearch.swift`, `Help/Capabilities.swift`,
`Views/Help/HelpWindow.swift`, `Views/Welcome/WelcomeWindow.swift`, `Views/Welcome/WelcomeContent.swift`,
`App/PrakritiApp.swift` (scenes, Help menu), `Resources/Help/*.md`, `docs/v2/help-notes/` (new),
`mac/project.yml` (swift-markdown package), `PrakritiTests/HelpTests.swift`, `SnapshotTests`, BUILD-LOG.

**Acceptance.**
1. `make test`, including `HelpTests`: every article parses; ids unique; every `related` id and every
   link resolves (to an article or a known place); no file under `Resources/Help` contains
   "builder-notes", an em or en dash, "we" as a word, "Processing" or "tap"; every SF Symbol named in an
   article or the welcome exists (`NSImage(systemSymbolName:)`).
2. A capability test: with only `help` on, the visible text of every article and panel contains none of
   the words "Viewer", "Blur Face", "Final Cut Pro", "DaVinci", "Shorts", "OpenAI", "People" as a feature
   name (a list kept in the test and extended by each milestone); with all capabilities on, every article
   is visible.
3. `make accept-help MILESTONE=v2-m2a` opens the real app with `--sample-data --show=help`, captures the
   real window for three articles in light and dark into `screens/mac/v2-m2a/real/`, and runs
   `--debug-help-search=OBS`, `=notifications` and `=privacy` (rule 2.1.10): each prints the expected
   article id first. Every PNG looked at: 17 pt body, nothing clipped. (M2b adds the five panels to the
   same target: `--show=welcome`, each panel captured light and dark, no scroll needed on any.)
4. A Show Me link in the snapshot of "Sources and watching" opens the Sources place (asserted in a UI-model
   test, not by pixels).
5. First launch is made, not assumed: the check deletes the development preferences' `welcomeSeenVersion`
   (`defaults delete` on the development domain, never the live one), then launches the built app twice
   in `--development`: the welcome window appears on the first launch only (log line "Welcome shown"),
   and the watcher's first look happens within 5 s of launch both times.
6. Regression set (2.1.4).

**Parts.**
- **M2a, Help window:** articles, capabilities, the `:::` pass, the Help window, rendering, search, Help
  menu search, Help menu items. Checks 1, 2 (articles), 3 (articles), 4, 6.
- **M2b, Welcome window:** the welcome window and its five panels, gated rows, the notification button.
  Checks 1 (welcome strings), 2 (panels), 3 (panels), 5, 6. Ivan looks once (Needs Ivan): Apple's own
  first-run windows (Final Cut Pro, Pixelmator Pro, iWork) are one panel of feature rows, so if five
  panels feel long to him, the fallback is one panel plus "Capture the Best Video" opening in Help.

**Needs Ivan.** Yes to adding swift-markdown (pinned 0.9.0, released 21 Sep 2026 per DS 5.4), before
M2a starts. After M2b installs, the welcome appears once at his next launch; he can read it and say what
to change.

### M3. The new main window

**Goal.** Ivan's "take another pass, how would Apple build it" (REQUEST 11) and the Viewer (REQUEST 10),
with every v1 function still reachable.

**Scope.**
- **Main window** per DS 2.1 to 2.5: 1440 by 900 default, 1100 by 720 minimum; Library sidebar (Needs You,
  In Progress, Ready, All Recordings; Sources with Add Folder); People section hidden until M6. Smart
  groups are SwiftData predicates over raw strings (W11). Sidebar counts as plain 15 pt text, never a
  `.badge` (W5), no `foregroundStyle` on sidebar icons (W8).
- **Browser:** grid (`LazyVGrid`, adaptive 240 to 360 pt cards) and list (`Table`), Command-1 and
  Command-2; cards with status capsule (symbol and words), length capsule, title, date; thumbnails are the
  neutral tile with date and kind (DS 3.1.2 rule 3) until M6 can make safe frames. Search over titles,
  notes and what was said, with Title and Said tokens; a "Said" result opens the Viewer at that sentence.
  Context menu per DS 3.1.1 (Remove from Library never touches the original).
- **Viewer** (open: double-click, Return, Command-Down; back: Escape, Command-Up): `AVPlayerView` on a black
  canvas, renditions **Original**, **Podcast** (episode) and **Podcast-ready** in the toolbar picker
  (Video and Shorts appear in M8 and M11, disabled with the reason until then). Under it the transcript as
  paragraphs, click a word to play from it, **Follow Playback** on by default (fixes v1's gap), select
  words to Cut or Keep (v1's cuts, on the original's clock, W41), and a Timeline-lite that shows v1's trim
  and cuts as outlined spans with the `scissors` symbol (DS 3.4.3; no film strip, no waveform, no handle).
  Space plays or pauses; J, K, L shuttle **[unverified in `AVPlayerView`; behaviour only, nothing drawn]**.
- **Inspector** (`.inspector`, Command-Option-I), tabs shown as built: **Outputs** (status block, the
  deliverables list with Play and Show in Finder, Make Again, Approve, the podcast-ready section and the
  writing section moved from v1's page), **Checks** (v1's report numbers, the accuracy checklist with
  checkboxes, the privacy-lock line), **Info** (title, What This Is, notes, Episode starts at and ends at,
  original path, output folder). People and Direction tabs appear in M6 and M9. Approve keeps every v1
  refusal (W35 to W38).
- **Settings window** (`Settings` scene, Command-comma): General, Outputs (v1's Outputs screen as it is),
  Models (v1's Models screen until M5), Privacy (the lock sentence), Advanced (paths). Sources settings show
  in the inspector when a source is selected (DS 3.5.6).
- Status words: "Waiting for your yes" (C1) in the app and in notices; dark text accent (C7); lock line
  per C4 (still v1's rule underneath until M5).
- Quick Help panel at the top of the inspector (Help menu, Show Quick Help), fed by a `.quickHelp(_:article:)`
  modifier, replacing tooltips (DS 5.5). TipKit tip 3 ("Click a word to play from it") only if the snapshot
  proves `TipView` draws at 12 pt or more; otherwise Prakriti's own inline row (DS 5.5 note).
- State restoration (group, selection, open recording, rendition, playhead, inspector tab).
- Help: articles 04, 05 and 06 rewritten for the new window; `viewer` capability on.
- Out: the Activity window and progress (M4); anything about people, video or direction.

**Files.** `Views/MainView.swift` (rewritten), `Views/Library/` (`LibraryView`, `BrowserGrid`, `BrowserList`,
`RecordingCard`, `SmartGroup`), `Views/Viewer/` (`ViewerView`, `RenditionPicker`, `TranscriptView`,
`TimelineLite`), `Views/Inspector/` (`InspectorView`, `OutputsTab`, `ChecksTab`, `InfoTab`, `SourceInspector`),
`Views/Settings/` (`SettingsScene` and five panes), `Views/QuickHelp.swift`, `Views/Components.swift`
(the grey cards retired), `App/PrakritiApp.swift`, `App/AppModel.swift` (selection, routes, restoration),
`Model/Vocabulary.swift` (display words), `App/Notices.swift` (wording), the retired screens
(`TodayView`, `RecordingsView`, `RecordingPage`, `SourcesView`, `OutputsView`, `ModelsView`, `SettingsView`,
`ActivityView`) moved into the new places or deleted, `SnapshotTests`, `SnapshotRenderer`,
`scripts/capture-window.swift` (new `--show=` values), `RulesTests`, `NotificationTests`, Help articles,
BUILD-LOG, START_HERE ("Prakriti for Mac" paragraph and the file table).

**Acceptance.**
1. `make test`: all v1 tests (113 at the finish line, plus podcast-ready's and M1 to M2's) still pass, with
   the snapshot list extended; `RulesTests` still fails on a planted 11 pt font and a planted `.help`.
2. `make snapshots MILESTONE=v2-m3`: every group (empty and filled), grid and list, Viewer with each
   rendition, each inspector tab, each Settings pane, light and dark. Every PNG looked at.
3. `make look MILESTONE=v2-m3` (real window, sample data) plus
   `open -n build/Build/Products/Debug/Prakriti.app --args --development --debug-playback-log --show=viewer --open=<13 Sep dev path>`:
   playback is proved from the development log, not the picture (rule 2.1.10): two `currentTime` lines
   3 s apart differ by 2.5 to 3.5 s with `rate` 1. The real window capture is then looked at for the
   system player on the Podcast rendition, the sidebar's selected row icon (W7, W8) and the glass
   toolbar.
4. A UI-model test plays from a clicked word: the player's time lands within 0.25 s of that word's start
   on the original's clock, and with Follow Playback on, the highlighted sentence changes as time passes.
5. `make accept-edits MILESTONE=v2-m3`: trim 10 s and cut 5:00 to 5:30 through the new inspector's model
   paths, Make Again, Approve: the approved MP3 is 38.82 s shorter (v1's number) and 0 of the 73 five-word
   runs inside the cut are heard again.
6. Notices: `NotificationTests` updated to "Waiting for Your Yes" and still checks no name or title.
7. Contrast test: every text color token measures 4.5 to 1 or more on its background in both appearances.
8. Regression set; `make migrate-check` (the new selection state is not stored in SwiftData, or is an
   addition with defaults).

**Parts.**
- **M3a, Main window and Settings:** the window, sidebar, browser grid and list, search (a "Said" result
  opens the recording at that sentence in v1's page until M3b), the inspector's Outputs, Checks and Info
  tabs, the Settings window, status words, contrast, notices. **Opening a recording (double-click,
  Return, Command-Down) shows v1's `RecordingPage` in the detail area**, unchanged, so trim, cuts,
  Make Again and Approve keep working for episode 1 while the Viewer is built. Nothing of v1's page is
  deleted in M3a. Checks 1, 2 (groups, grid, list, inspector, Settings), 3 (window, sidebar, toolbar;
  no playback), 5 (through v1's page, as v1 runs it), 6, 7, 8.
- **M3b, The Viewer:** the Viewer and its renditions, the transcript, Follow Playback, Cut and Keep,
  Timeline-lite, Quick Help, state restoration; only then are `RecordingPage` and the other retired
  screens moved or deleted. Checks 1, 2 (Viewer), 3 (playback), 4, 5 (through the Viewer and inspector),
  8.

**Needs Ivan.** *Ivan:* ten minutes with the new window after M3a installs, and again after M3b, with his
yes or changes. This is the milestone his taste matters most for, and it is the cheapest point to change
direction.

### M4. Progress, Activity and the capture check

**Goal.** "Give me a progress on the recordings as it's working" (REQUEST 6), and the clean-input check
(REQUEST 1).

**Scope.**
- **`JobProgress`** observable per running job: stage id and plain name (verbs, never "Processing"), step
  N of M, fraction within the stage, overall fraction weighted by each stage's **measured** average on this
  Mac, time left only once the running stage has a measured rate ("Working out the time left" before
  that, always "About", rounded), the latest log line, and what it waits on after 60 s with no progress
  ("Waiting for LM Studio to load the model"). Updates at most twice a second (DS 3.6.1).
- **Fraction sources:** ffmpeg passes run with `-progress pipe:1` (`out_time_us` against the input length);
  Parakeet by elapsed time against the measured rate, capped at 95% until it exits **[parakeet-mlx progress
  output unverified]**; LM Studio by streamed tokens against the measured average of that task; later
  stages (people, render) report frames done against frames total.
- **`StageTiming`** (SwiftData, an addition): seconds per media minute per stage, seeded at first launch from
  v1's own `RunStep` history in the store, then a running average of the last 10 runs.
- **Shown in:** the card (Working capsule with a determinate ring and percent), the list row, the
  inspector status block (Pause, Stop), the Viewer banner, the toolbar Activity button (queue percent), the
  menu bar status line ("Making Sun 13 Sep: Writing the transcript, 64%, about 6 min left. 2 waiting.").
- **Activity window** (`Window` id `activity`, Command-9, the toolbar button, the menu bar): Now, Finished,
  Log (DS 3.6.3); per-row Pause and Stop; the stage list with each done stage's time and each coming
  stage's usual time; Make Next on a waiting row. The Log tab replaces v1's Activity screen with the same
  sentences and the heartbeat line.
- **Menu bar menu** per DS 3.14 (Show Activity, Prakriti Help added).
- **Capture check** (`Engine/CaptureCheck.swift`), first step of every recording, tests included: every
  stream by `ffprobe` (size, frame rate, codec, color tags, chapters), every audio track by `ebur128` on its
  own map (`-map 0:a:N`), silence per track, and **dual mono** (one microphone copied to two channels:
  left minus right under -60 dB). Each finding has a plain line, a capture tip and a Help link, in the
  Checks tab's Capture section. A file under 60 s still makes nothing and gets no output folder (W16); its
  capture check is shown from the store.
- Hybrid MOV accepted everywhere Hybrid MP4 is; warning 15 and SCOPE SET-04's line updated.
- `progress` capability on; H04 and H10 updated.

**Files.** `Progress/JobProgress.swift`, `Progress/StageTimings.swift`, `Engine/Subprocess.swift` (progress
pipe), `App/PipelineRunner.swift`, `Engine/Pipeline.swift` (stage reporting), `Engine/CaptureCheck.swift`,
`Model/Models.swift` (`StageTiming`, capture result JSON on `Recording`), `Views/Activity/ActivityWindow.swift`,
`Views/MenuBar.swift`, `App/StatusSummary.swift`, toolbar and inspector views, `ProgressTests`,
`CaptureCheckTests`, `make accept-progress`, Help 04 and 10, START_HERE warning 15, BUILD-LOG.

**Acceptance.**
1. `make test` including `ProgressTests`: weighted overall fraction never decreases; time left is absent
   until a stage has a rate; a 61 s stall produces the waiting line; at most two updates a second.
2. `make accept-progress MILESTONE=v2-m4` makes the 13 Sep talk twice in development and writes
   `progress-trace.txt` (time, stage, percent, time left). Pass when: percent rises monotonically from
   0 to 100; on the second run, the time left shown at the 50% mark is within 25% of the real remaining
   time; the menu bar status line, read from the development log with `--debug-status-log` (rule
   2.1.10; the menu bar itself cannot be captured), matches the trace at three moments.
3. Capture check on 13 Sep: 1920 by 1080, 29.97 fps, H.264, BT.709, one audio track, stereo, flagged
   **dual mono** with the tip "Give each speaker a microphone on its own track" (the known state of the
   studio files, warning 6 and H02). On `two-people-tracks.mov`: three tracks, each with its own loudness, none
   dual mono. On `silent-60s.mp4`: track silent. On the 30 s clip: filed as a test, no output folder, the
   capture check present in the store.
4. Snapshots of the Activity window (Now with a working row, Finished, Log, empty) and the Checks tab
   Capture section, light and dark, looked at; one real-window capture of Activity during a run.
5. Regression set; `make migrate-check`.

**Parts.**
- **M4a, Progress and Activity:** `JobProgress`, fraction sources, `StageTiming`, every place progress
  shows, the Activity window, the menu bar menu, H04. Checks 1, 2, 4 (Activity), 5.
- **M4b, Capture check:** `CaptureCheck`, the Checks tab's Capture section, Hybrid MOV, warning 15 and
  SET-04, H10. Checks 3, 4 (Capture section), 5.

**Needs Ivan.** Nothing. *Ivan:* turning on notifications, if still off (v1 open item), so the progress
reaches him away from the window.

### M5. Models: Anthropic, OpenAI and the hardware check

**Goal.** "Space for an OpenAI or Anthropic API in case a user does not have a computer powerful enough"
(REQUEST 5), honestly: a cloud key takes the language work only (DS C3).

**Scope.**
- **Providers** (`Writing/ModelClients.swift`, `Writing/Providers.swift`): LM Studio, Apple on-device and
  Ollama as in v1; **Anthropic** (renamed from v1's "Claude API", same Keychain service
  `studio.therowan.prakriti.app.claude-api`) and **OpenAI** (new service
  `studio.therowan.prakriti.app.openai-api`). Keys only in the login Keychain, never in a file, preference,
  store or log (W52); after saving, only "Saved in your Keychain" and Remove Key.
- **Anthropic over HTTPS** (Swift has no official SDK, so raw HTTP is the documented route): `POST
  https://api.anthropic.com/v1/messages` with `x-api-key` and `anthropic-version: 2023-06-01`, always
  `"stream": true`, `max_tokens` 64,000, a 9-minute timeout (START_HERE engine warnings). **No `thinking`
  field** (on current models a disabled or budgeted thinking setting is a 400, and warning 34 forbids one); depth
  is `output_config.effort`, set explicitly per task (planning and writing `high`, tags `low`). Server
  fallback on a refusal: `"fallbacks": "default"` with the `anthropic-beta: server-side-fallback-2026-07-01`
  header. `stop_reason` of `refusal` or `max_tokens`, or empty text, is a failure, never a result. The
  model pop-up is filled from `GET /v1/models`; the default selection is `claude-opus-5-5` (Anthropic's
  current default), with the measured cost of each call shown after it runs so Ivan can choose
  `claude-sonnet-5-5` (his recorded cost lever). Source: the claude-api reference, cached 6 Oct 2026,
  re-read in review: on Opus 5.5 an explicit `thinking` setting of disabled or a budget is a 400 at
  every effort, and effort defaults to `medium`, so it is always set. **The pop-up lists only models
  this request shape works on.** Older models listed by `/v1/models` reject `output_config.effort` or
  the fallback beta (the reference names Haiku 4.5 and Sonnet 4.5 for effort), so the pop-up keeps a
  model only when the Models API's `capabilities` object says it supports effort **[field name read on
  the build day]**, and the `fallbacks` field and header are sent only for the models the reference
  lists for them (Opus 5.5, Opus 5, Sonnet 5.5, Fable 5.1).
- **OpenAI:** `POST https://api.openai.com/v1/responses`, streamed; the model pop-up filled from
  `GET /v1/models`; no model id is hard-coded **[the current OpenAI model ids and the Responses streaming
  event names are unverified here: the builder reads developers.openai.com on the day and records the
  version it built against]**. JSON validated in Swift exactly as v1's LM Studio answers are (W48).
- **Tasks:** v1's Writing, Tagging, Summarizing, plus **Planning the edit** and **Choosing moments**
  (used from M9 and M12; listed, greyed with "Not built yet" until then, W32).
- **Hardware check** (`Writing/HardwareCheck.swift`): chip from `sysctl machdep.cpu.brand_string`
  (measured: "Apple M5 Pro"), memory from `ProcessInfo.physicalMemory` (measured: 68,719,476,736 bytes),
  Apple Intelligence availability from `SystemLanguageModel.default.availability`. Verdict: 64 GB or more,
  "This Mac can run the writing model" (Qwen3.8-27B holds about 33 to 36 GB, peaks of 51 to 54 GB measured,
  LOCAL-MODEL.md); under 64 GB, "Writing a long recording needs a cloud key, or it waits" with Anthropic or
  OpenAI suggested for talks. A suggestion only: nothing switches to a cloud provider by itself. Shown in
  Settings, Models and on welcome panel 5.
- **The privacy lock** (`Writing/PrivacyLock.swift`, replacing `Writer.route`'s v1 rule): local only when
  the recording is a class; or its people check has not run; or anyone heard has not been allowed cloud
  reading (a per-person switch, off by default, stored with the person); or anyone unnamed appears or
  speaks. Until M6 every recording is "people not checked", so cloud tasks run only on fixtures. A locked
  task set to a cloud provider runs on LM Studio or Apple on-device instead, and the step, the Checks tab
  and `show-notes.md` say why. If no local model can run it, the step waits with the reason.
- **The cloud adapter's own check (warning 19):** before any request it asserts, on the data, that the text has
  no span of a person without cloud consent and that every name `NLTagger` finds (`.nameType`,
  `personalName`) other than consenting named people has been replaced by a token, restored in the answer.
  A failed assertion refuses the call and logs why, never the text. The check lives in
  `PrivacyLock.release(_:)`, the only way to make the `CloudPayload` a provider client accepts (2.2), and
  a name Ivan marked Mute under names said aloud (M6c) is always tokenized even if `NLTagger` misses it
  that time. Cloud writing for real recordings stays off by default until check 3's measured recall is
  90% or more and D1 is answered (risk R18).
- `cloudProviders` capability on; H09 rewritten for Settings, Models.

**Files.** `Writing/ModelClients.swift`, `Writing/Providers.swift` (new), `Writing/AnthropicClient.swift`,
`Writing/OpenAIClient.swift`, `Writing/Keychain.swift`, `Writing/HardwareCheck.swift`,
`Writing/PrivacyLock.swift`, `Writing/NameTokens.swift`, `Writing/Writer.swift`, `Model/Vocabulary.swift`
(providers, tasks), `Views/Settings/ModelsPane.swift`, `ProviderTests`, `make accept-providers`, Help 09,
START_HERE W50 and W52, BUILD-LOG.

**Acceptance.**
1. `make test` with `ProviderTests`, using a `URLProtocol` stub: the Anthropic body has `stream: true`, no
   `thinking` key, `output_config.effort` set, the fallback header; the OpenAI body targets `/v1/responses`
   with streaming; a streamed `refusal` and a `max_tokens` stop are failures; keys are read from the test
   Keychain services and never appear in the log file (grep).
2. Lock tests, counting cloud requests: a class, 0; people not checked, 0; a person without cloud consent
   speaking, 0; an unnamed person present, 0; `synthetic-transcript.json` marked checked with one consenting
   speaker, 1. The adapter refuses a planted untokenized name.
3. `NLTagger` recall on the 13 Sep transcript, measured and written to BUILD-LOG (how many person names it
   finds, which are false); the verifier reads only counts and the names of Gabriel and Serenity, never a
   student's. **[recall unverified until measured]**
4. Hardware check with injected profiles (16, 32, 48, 64, 128 GB, with and without Apple Intelligence): the
   verdict text for each; on this Mac, "Apple M5 Pro, 64 GB. This Mac can run the writing model."
5. `make accept-models MILESTONE=v2-m5`: v1's acceptance still passes with the new lock (the 13 Sep talk is
   "people not checked", so LM Studio writes it and the cloud client is asked 0 times).
6. *Only with keys present and Ivan's yes on cost (cents):* `make accept-providers` tests each key against
   `/v1/models` (free) and writes titles for `synthetic-transcript.json` once per provider; the answer
   passes `WritingCheck`. Without keys this check is reported SKIPPED, not failed.
7. Snapshots of the Models pane (keys absent, saved, rejected), light and dark, looked at.

**Parts. The lock ships before the new providers**, so there is never a build in which OpenAI or the
modernized Anthropic client can run under v1's older rule (which let a talk with students heard go to
the cloud if it did not mention Serenity).
- **M5a, The new privacy lock:** `PrivacyLock`, `CloudPayload`, `NameTokens`, the per-person cloud
  switch, the hardware check, all applied to v1's existing Claude API client unchanged. Checks 2, 3, 4,
  5, and check 1's Keychain and log parts.
- **M5b, Anthropic and OpenAI:** the Anthropic client brought to the current request shape, the OpenAI
  client, the filtered model pop-ups, the Models pane, H09. Checks 1, 6, 7, and 2 again (the lock now
  in front of both providers).

**Needs Ivan.** An Anthropic key and an OpenAI key if he wants them tested (Settings, Models, paste, Save
in Keychain), and his yes to a few cents of test calls. D1 before any real talk goes to a cloud model.

### M6. People in a recording

**Goal.** "Flag faces; let me know when it's Gabriel or Serenity, or other people; let me choose who is
included in the output videos and audio" (REQUEST 3), with nothing biometric kept about anyone unnamed.

**Scope.**
- **The people pass** (`People/`), a pipeline step after the transcript and before writing (its answer
  feeds the lock), per PE 2.1: Vision `DetectFaceRectanglesRequest` revision 4 at 2 frames a second, with
  landmarks and capture quality; tracks by box overlap (IoU 0.3 or more; broken at a cut or 1.5 s unseen);
  frames decoded with `AVAssetReader` through `outputProvider(for:)`, analyzed at 1080p even from 4K.
  Vision warmed on one frame before progress is timed (PE 1.7).
- **Voices.** With isolated microphone tracks (capture check found them): who speaks when from each track
  being active, 6 dB above the others [proposal from PE 2.5]; a one-time "Track 2 is Gabriel's microphone"
  mapping per source. With one mixed track: FluidAudio's offline diarizer, with
  `OfflineDiarizerConfig.Export.embeddingsPath` left `nil` and every embedding and centroid dropped when the
  job ends (PE 2.5). Any mixed-track recording with two or more voices puts its voice boundaries in the
  listen queue before Approve (warning 14).
- **Linking** faces to voices by mouth opening against voice activity (PE 2.6), landmarks at 10 fps only on
  stretches with two or more faces.
- **Naming without prints:** an Info tab "Who is teaching" picker (people named in Settings, Privacy, by
  name only) names the single matching track and voice of a talk; the People tab's **Name for This
  Recording** names any other track. Names are not biometric; nothing about a face is stored for it.
- **The people file** (`~/Library/Application Support/Prakriti/People/Recordings/<recording id>.json`):
  tracks as times and boxes, voice segments as times, links, decisions, and a face picture **only for a
  named person who may appear** (section 5; changed in review from PE 2.1's "one thumbnail per track",
  which would have stored a picture of every student). Any other track's picture is cropped live from
  the video while the People tab is open and never written. **No landmarks and no embeddings** for
  anyone, ever, in this milestone. Frames saved for analysis live in
  `Application Support/Prakriti/Jobs/<uuid>/`, deleted when the job ends, and every launch deletes any job
  folder left by a crash before anything else (PE 5.4).
- **Decisions** per person and per output (DS 3.5.2): Include, Blur Face, Remove (Remove Voice for a voice
  with no face); defaults Include for a named person who may appear (Gabriel, Serenity, REQUEST) and
  Remove for everyone else; Customize per Output; Set All Unnamed To; the consequence line ("Removing
  Unnamed 2's speech takes out 4 min 12 s"); undoable; a change marks the outputs "Not in the episode yet"
  (W36's rule).
- **Applying them now:** Remove cuts the person's speech from the podcast episode and the podcast-ready
  episode, widened to the nearest pause, with v1's 15 ms fades (W42), and the transcript files follow
  (W39). Blur Face changes nothing in audio. With every person Included and nothing removed, the mastering
  chain is unchanged string for string, so the bit-for-bit v0 check on 13 Sep still holds (W30).
- **Hiding in pictures** (`People/FaceHide.swift`): a Core Image function that hides given tracks in a
  frame (padded 1.6 times, soft ellipse, a heavy blur of at least a quarter of the face's width then
  pixelation, held 0.5 s before and after each sighting, a body's head region when the face is lost;
  PE 3.2). **Boxes between the 2 fps detections come from Vision's `TrackObjectRequest` at the full frame
  rate, re-seeded from each detection** (PE 1.1 and 3.2, 3.3 ms per face per frame measured); a box only
  held or interpolated between samples 0.5 s apart can lose a face that moves. Overlaps follow PE 3.5:
  where a hidden region covers part of an Included face, hiding wins. Used now for thumbnails and the
  Viewer's People overlay; used by the renderer from M8d.
- **Safe thumbnails** for cards (DS 3.1.2): the sharpest frame where every face is Included, else the best
  frame with every other face hidden, else the neutral tile; stored in
  `Application Support/Prakriti/Thumbnails/`, never written before the people pass.
- **Where it shows:** the People tab (summary sentence, one row per person with a live crop held in memory
  only, decisions, Play Their Moments); the people line on cards and rows ("Gabriel. Up to 2 other people
  at once. 1 other voice."); the filter "Other people appear"; Needs You lists them first; one fixed notice
  (W23) whose words say only what that build does: "Other people appear in this recording." from M6a,
  then "Other people appear in this recording. Their voices are left out until you decide." from M6c,
  then "...Their faces are blurred and their voices left out until you decide." from M8d, when a video
  can show a face; the Viewer's **People** overlay on Original (boxes and labels; Ivan sees faces in his own
  app, DS Q3).
- **Names said aloud** (section 5): person names `NLTagger` finds that are not named people become Check
  moments ("A name is said at 12:40"), each Keep or Mute; Mute dips the word in every audio output and
  replaces it in captions with "[name]". Approve waits until each is decided.
- **Audio output check** (PE 3.6 item 2, within the job): after the podcast is made, the voice segments of
  the finished file are matched against the job's in-memory voices; any speech that is not an Included
  person stops Approve with its time.
- **Overlapping speech** (PE 3.5): where an Included and a Removed voice speak at once, the overlap is cut
  (fail closed), widened to the Included person's word boundaries, and listed for listening; "Keep
  Gabriel's microphone here" is Ivan's choice per stretch, never automatic.
- The lock (M5) now reads the people result. **The people check counts as run only when both the face
  step and the voice step finished for that recording** (M6b); a recording with faces checked and voices
  not yet checked is still "people not checked" and stays local. `people` capability on; H07 rewritten to these words; H02's
  class section kept.

**Files.** `People/FaceScan.swift`, `People/Tracks.swift`, `People/VoiceActivity.swift`,
`People/Diarizer.swift`, `People/SpeakerLink.swift`, `People/PeopleFile.swift`,
`People/PeopleDecisions.swift`, `People/FaceHide.swift`, `People/Thumbnails.swift`,
`People/NamesSaidAloud.swift`, `People/AudioOutputCheck.swift`, `Engine/Pipeline.swift` (the step),
`Engine/Mastering` (Remove spans as cuts), `Engine/EpisodeEdits.swift`, `Model/Models.swift` (a `Person`
model for named people: name, may appear, cloud consent; per-recording people summary fields),
`Views/Inspector/PeopleTab.swift`, `Views/Viewer/PeopleOverlay.swift`, card and list views,
`App/Notices.swift`, `mac/project.yml` (FluidAudio package), `PeopleTests`, `make accept-people`, Help 02,
06, 07, BUILD-LOG, START_HERE (new warnings for the people file, the job folder and the embeddings path).

**Acceptance.**
1. `make test` with `PeopleTests`: tracking joins and breaks as specified on synthetic boxes; decisions
   default correctly; the coordinate conversion between Vision (origin bottom left) and Media Intelligence
   (top left) round-trips; Remove widens to pauses; `embeddingsPath` is `nil` in every diarizer config
   built (a test reads it).
2. `make accept-people MILESTONE=v2-m6a` (and m6b, m6c as each part runs its half) on the **13 Sep talk**: one face track group covering at least 95%
   of sampled frames, one voice; with "Who is teaching" set to Gabriel, the People tab reads "Gabriel speaks
   for N percent." and no other people; the podcast's decoded audio equals the M0 baseline bit for bit
   (nothing removed). If the pass finds a second face or voice, the verifier writes down its times and
   counts and this half becomes *Ivan* (is someone else really there?), not a FAIL: the talk's real
   content is not something the build controls.
3. On **`two-people-mixed.mp4`**: two face tracks (main and corner), two voices; the corner person is
   Unnamed 1 with Remove; the remade podcast, transcribed again with Parakeet, contains 0 of the five-word
   runs of the `say` paragraph and at least 98% of the 13 Sep words that were not removed, in order.
4. On **`two-people-tracks.mov`**: who speaks comes from tracks 2 and 3 (log line says so); the result
   matches check 3.
5. Thumbnail of `two-people-mixed`: Vision finds exactly one unhidden face, inside the main track's box;
   inside the corner region the image variance falls by at least 80% against the source frame. Picture
   looked at.
6. Hiding test: five frames rendered with the corner track hidden; Vision finds no face inside any hidden
   region, including 0.5 s before the corner face first appears.
7. **Nothing stored for strangers:** after every run, `Application Support/Prakriti/People/Faces`,
   `Voices` and `FaceIndex` do not exist; `Jobs/` is empty; the people file contains no array of 128 or
   more numbers and no image data or image path for any track that is not a named person who may appear
   (a test parses it); no file under `Application Support/Prakriti` other than the safe card thumbnail
   is an image (`file` on every file); a crash simulated mid-pass (kill -9) leaves a job folder that the next
   launch deletes before its first look.
8. Speed on the **6 Sep talk** (55:39): the people pass takes under 5 minutes, timed (PE 6.7).
9. The privacy lock: with a cloud provider chosen for writing, `two-people-mixed` writes locally (0 cloud
   requests); the 13 Sep talk with Gabriel's cloud switch off writes locally; on, it is allowed (counted,
   no request sent in the test).
10. Names said aloud on 13 Sep: the count of Check moments is written to BUILD-LOG as a number only.
11. The notice for `two-people-mixed` is the fixed sentence, with no name or title (`NotificationTests`).
12. Snapshots: People tab for both fixtures, the cards with people lines, the Viewer's People overlay; real
    window capture of the overlay. Every PNG looked at (D1).
13. Regression set; `make accept-outputs` (the bit-for-bit check); `make migrate-check`.

**Parts.**
- **M6a, Faces:** the people step in the pipeline, `FaceScan`, `Tracks`, the people file (faces only),
  the job folder and its launch cleanup, the People tab read-only, the people line, the filter, the
  notice's first wording. Decisions are not shown yet and v1's outputs and Approve are unchanged, so
  nothing gets worse for any recording. Checks 1 (tracking, coordinates), 2 (faces; bit for bit), 7,
  8 (faces), 11, 12 (People tab, cards), 13.
- **M6b, Voices and names:** microphone tracks, the diarizer, linking, Who Is Teaching, Name for This
  Recording, the `Person` model, the lock fed by a complete people check. Checks 1 (`embeddingsPath`), 2
  (voice, "Gabriel speaks for"), 4 (who speaks from tracks), 8 (whole pass), 9, 13.
- **M6c, Choices applied to audio:** decisions and their defaults, Remove in the podcast and
  podcast-ready episodes, overlapping speech, the audio output check, names said aloud, the notice's
  second wording, H07. Checks 1 (decisions, widening), 3, 4 (result matches 3), 10, 11, 13.
- **M6d, Hiding in pictures:** `FaceHide` with the full-rate tracker, safe card thumbnails, the Viewer's
  People overlay. Checks 5, 6, 7 (thumbnails are the only images), 12 (overlay), 13.

**Needs Ivan.** Yes to adding FluidAudio, before M6b: pinned to the exact version Hark's `Package.resolved`
records (PE 2.5 says Hark pins 0.15.5; the current release is 0.17.7 of 8 Oct 2026), and the
`embeddingsPath` test proves the field exists in that version. Its diarization models are already in
`~/Library/Application Support/FluidAudio/Models/speaker-diarization` (measured); yes also to any model
download the pinned version needs. D1.

### M7. The People gallery

**Goal.** "A gallery of faces recognized in videos ... the way Apple Photos does this" (REQUEST 8), holding
only people with a written release.

**Scope** (PE 2.2 to 2.4, 4, 5; DS 3.9):
- **Recognition** with `MediaIntelligence.FaceGroupAnalyzer` (working directory
  `Application Support/Prakriti/People/FaceIndex/`): crops of consenting people inserted and grouped;
  new recordings identified with `identifyFaces(in:)`, which stores nothing (measured, PE 1.2). Asset ids
  are UUIDs, never file names, because the framework logs them. Votes per track (PE 2.2): named without
  asking at 3 or more identified frames, 60% or more the same person, none matched to anyone else, and the
  voice agreeing when the track speaks; "Is this Gabriel?" otherwise; unnamed when nothing matches.
- **The vault:** crops (up to about 50 per person) and voice prints sealed with AES-GCM under a per-person
  256-bit key in the login Keychain (service `studio.therowan.prakriti.app.people`, account = person id);
  the whole `People/` folder excluded from Time Machine (`isExcludedFromBackup`). Apple's index is
  treated as rebuildable from the sealed crops.
- **Consent sheet** (Name This Person): name, role, Learn Face, Learn Voice, "Written release signed on"
  (a date), "Where the signed release is kept", the notice version; **Learn [Name]** or **Name Only**
  (PE 5.6 words). Recognition consent and "may appear" are separate lines on the person.
- **Gallery** (sidebar People, then pinned named people): 120 pt round key photos, Favorites first, sort by
  name or custom order; **every named person, Name Only included** (section 5): a key photo from a real
  frame for a person who may appear, a monogram for anyone else, and "Recognition off. Named by you in
  each recording." until a release exists; the one face-less "Unnamed people" tile; a person page (status line, recordings,
  minutes on screen, minutes speaking, Review Possible Matches, Change Key Photo, Rename, Merge 2 People,
  Hide from People, **Forget Face and Voice**).
- **Forget:** destroy the key, delete crops and voices, delete their assets from the index, purge and
  rebuild it from everyone else's crops (the analyzer reads image files, so the rebuild opens each sealed
  crop into the job folder under a UUID name and the job's cleanup deletes them, PE 1.2), then prove it (sealed files fail to open, an old crop identifies
  as nil). **Retention:** prints deleted 12 months after last appearance, with a Needs You line 30 days
  before.
- **Calibration harness** `make calibrate-people` (PE 6.1), for when releases exist: label tracks in
  Review, report recognized, mistaken and stranger-taken-for-named rates.
- `gallery` capability on; H07's gallery sections.

**Files.** `People/Gallery.swift`, `People/PrintVault.swift`, `People/Recognition.swift`,
`People/Retention.swift`, `Model/Models.swift` (`Person` gains consent fields, key photo, favorites),
`Views/People/GalleryView.swift`, `Views/People/PersonPage.swift`, `Views/People/NameThisPersonSheet.swift`,
`Views/People/ReviewSheet.swift`, sidebar, `GalleryTests`, `make accept-gallery`, `make calibrate-people`,
Help 07, BUILD-LOG, START_HERE (new warnings: the vault, Forget, backup exclusion).

**Acceptance.**
1. `make test` with `GalleryTests`: seal and open round trip; a destroyed key makes every sealed file fail;
   votes give named, ask and unnamed on synthetic identify results; Merge refuses when either person lacks
   a release; Name Only stores no file under `People/Faces` or `Voices`.
2. **With no release recorded** (always run): `make accept-gallery` on `two-people-mixed`: the gallery is
   empty; Name This Person defaults to Name Only; afterwards `People/Faces`, `People/Voices` and
   `People/FaceIndex` hold no files. `tmutil isexcluded "$HOME/Library/Application Support/Prakriti/People"`
   reports excluded.
3. **With `ivan-clip.mov` and Ivan's release** (run only when both exist; otherwise SKIPPED and listed for
   Ivan): enroll Ivan from his clip (development store only); on `ivan-plus-13sep.mov`, Ivan is named
   without asking and Included, the 13 Sep face is Unnamed 1 with Remove; the hash list of every file in
   `People/` is identical before and after the identify pass (nothing stored about the stranger);
   Forget Ivan, then the three proofs of Forget pass and the index was rebuilt (its files' dates changed).
4. Snapshots: gallery empty, gallery with one person (Ivan's key photo, only if check 3 ran), person page,
   consent sheet, Review sheet, light and dark, looked at.
5. Regression set; `make migrate-check`.

**Parts.**
- **M7a, People, named:** the gallery with Name Only people, the person page (recordings, minutes on
  screen and speaking, Rename, Change Key Photo, Hide from People), the consent sheet, the print vault
  (seal, open, Keychain key, backup exclusion), Forget for the vault, retention. Checks 1 (seal, destroyed
  key, Name Only stores nothing), 2, 4 (empty, Name Only person, page, sheet), 5.
- **M7b, Recognition:** `FaceGroupAnalyzer`, votes, Review Possible Matches, Merge 2 People, the index
  rebuild in Forget, `make calibrate-people`. Checks 1 (votes, Merge refuses), 3, 4 (Review, Ivan's key photo), 5.

**Needs Ivan.** D2 (releases). Optional, to exercise recognition now: a 2-minute clip of himself recorded
on this Mac (`ivan-clip.mov` in `~/Prakriti/Dev/Fixtures/`) and his own release recorded in the
development copy. Recognition of Gabriel and Serenity waits for their releases; until then they are named
per recording, which already gives Ivan his "let me know".

### M8. The edited video: rough cut

**Goal.** A rendered, ready-to-post MP4 with pauses, fillers and bad takes removed and people applied,
previewed in the Viewer exactly as it will be posted (REQUEST 4, 10, "post ready").

**Scope.**
- **`EditPlan`** (`Edit/EditPlan.swift`), schema `prakriti.editplan/1` exactly as EE 3.4: spans tied to word
  ids, removed items with kind and confidence, Check moments, visual items (empty in M8), chapters,
  people applied; validated in Swift before anything renders (EE 3.4 rules 1 to 6). Stored per recording
  and version as `edit-plan.json` in the output folder. Every later output (MP4, preview, timelines,
  captions, chapters, the podcast's cut list) is written from it.
- **Rough cut** (EE 1.2 to 1.7), all code, no model: words in spoken order through v1's
  `EpisodeTranscript.sentences(json:)` (W45); the audio envelope (10 ms RMS, floor, hysteresis); word ends
  clamped to the envelope (326 of 502 pauses hide inside Parakeet's word spans, measured, EE 0); pauses
  shortened, never removed, with protected silences; fillers (um, uh, er, erm, ah, stutters) removed only
  where the cut is clean; restarts by spoken marker and by the abandoned-sentence rule with the
  parallel-phrasing guard (two thirds of restart-looking pairs are deliberate, EE 1.6); passage retakes by
  embeddings confirmed by the model, else a Check moment "Possible retake at 12:40: kept both"; feasibility
  and frame snap (cuts on frame boundaries in a low-energy region).
- **People** applied on top, never overridable by the plan (EE 3.4 rule 5): Remove cuts their speech time
  from picture and sound; Blur Face and Remove hide their face in every frame.
- **Render** (`Render/`), EE 4.2: `AVMutableComposition` built with async `insertTimeRange`; a custom
  `AVVideoCompositing` compositor over Core Image on Metal, reading `sourceReadOnlyPixelBuffer(byTrackID:)`;
  instructions from the plan; `AVVideoComposition.Configuration` (never the deprecated mutable types).
  The **same compositor** drives the Viewer's Video rendition through `AVPlayerItem.videoComposition`, so
  the preview is the output. Writing: `AVAssetReaderVideoCompositionOutput` into `AVAssetWriter` through
  `AVAssetWriterInput.PixelBufferReceiver` (2.2), H.264 High, CABAC, 16 Mbps at 1080p, key frame every 15
  frames, BT.709, `shouldOptimizeForNetworkUse`. Render speed is an estimate (4 to 8 times real time,
  EE 4.2, **[estimate]**) until check 5 measures it.
- **Video audio** (`Render/VideoAudio.swift`): ffmpeg joins the plan's spans with 10 ms handles and 20 ms
  equal-power crossfades (EE 1.7; total length stays the sum of spans), then v1's speech chain re-targeted
  to -14 LUFS and true peak -1 dBTP, as a float WAV encoded by the writer as AAC-LC 48 kHz stereo 384 kbps.
- **Deliverables** in `<Outputs>/<recording>/Video/`: the MP4 named by date until it has a title,
  the `.srt` (at most 42 characters a line, two lines, 20 characters a second, EE 2.7) on the edited clock,
  `Description.txt` (title, description and chapters from the writing step when it ran, MISSING
  otherwise, never invented, W62), and `Ready checklist.txt` measured from the file (EE 6.4): container,
  codec, profile, size, frame rate, bitrate within 10%, BT.709 tags, index at the front, no video edit list,
  loudness and true peak, tail decoded, captions parse, chapters follow YouTube's rules, people applied.
- **Output check for pictures** (PE 3.6 item 1): faces found again in the MP4 at 5 fps; every face must be
  an Included person's track or inside a hidden region; any other face stops the output: "A face Prakriti
  cannot account for at 12:41. Hide it or include the person, then Make Again."
- **Output check for sound** (PE 3.6 item 2, the same as M6c's on the podcast): the MP4's audio is matched
  against the job's in-memory voices; speech that is not an Included person stops the output with its
  time. Both checks run inside `OutputGate` (2.2), so a failing MP4 never reaches `Video/`.
- **Viewer:** the **Video** rendition; the Timeline-lite now shows the plan (kept filled, removed outlined
  with its reason symbol: pause, filler, retake, another person, trimmed); select a span to Restore or
  Remove; Delete and Command-Z; "Not in the video yet" until Make Again; struck-through removed words in the
  transcript; Captions overlay toggle.
- **Output kind:** `editedVideo` becomes available (W32), off for every folder (2.1.7), with a "Make Video"
  button on existing recordings. Make Again on a version keeps the last good files until the new ones are
  done (W29's staging).
- `video` capability on; Help 05, 06 and 10 updated.

**Files.** `Edit/Words.swift`, `Edit/Envelope.swift`, `Edit/RoughCut.swift`, `Edit/Restarts.swift`,
`Edit/EditPlan.swift`, `Edit/PlanValidation.swift`, `Render/CompositionBuilder.swift`,
`Render/Compositor.swift`, `Render/Instructions.swift`, `Render/VideoWriter.swift`, `Render/VideoAudio.swift`,
`Render/Captions.swift`, `Render/ReadyChecklist.swift`, `People/PictureOutputCheck.swift`,
`Engine/Pipeline.swift` (steps "Planning the edit", "Making the video", "Checking the video"),
`Views/Viewer/*`, `Model/Vocabulary.swift`, `RoughCutTests`, `RenderTests`, `make accept-video`, Help,
BUILD-LOG, START_HERE (warnings: one plan drives every output; the compositor is the preview).

**Acceptance.**
1. `make test` with `RoughCutTests` on `ums-and-retake.wav`: every planted "um" and "uh" removed, the
   stutter's first copy removed, everything before "let me start over" removed, the parallel pair kept;
   `RenderTests` render frames at chosen times from a fixture plan and compare with expected images.
2. `make accept-video MILESTONE=v2-m8` on the **13 Sep talk**, the Clear defaults, writes
   `acceptance-video.txt`. Pass when (EE 1.8): every cut point sits 20 dB or more under speech level for
   20 ms or more, or inside a crossfade; no sample jump at a join exceeds the largest in the 50 ms around
   it; Parakeet run on the output finds at least 98% of kept non-filler words in order; at least 90% of
   removed "um" and "uh" are absent; no pause longer than the preset's trigger except protected ones, and
   the median sentence pause within 50 ms of target; the output length equals the sum of kept spans within
   one frame; video and audio cut on the same frame.
3. The MP4 measured: `ffprobe` H.264 High, 1920 by 1080, 30000/1001, BT.709 tags, AAC 48 kHz stereo 384
   kbps, video bitrate within 10% of 16 Mbps; the `moov` box before `mdat`; no `elst` on the video track;
   `ebur128` -14 within 1 LU and true peak at or under -1 dBTP; the last 5 s decode with no error.
   `Ready checklist.txt` reads PASS on every line except MISSING title fields when writing was off.
4. **Preview equals output:** six frames at known plan times, decoded from the MP4, and the same times
   taken by `AVAssetImageGenerator` from the composition with the exact `videoComposition` object the
   Viewer's player item uses (so the preview path is what is measured, not a second renderer), match at
   38 dB PSNR or better **[threshold proposed; the encoder adds differences]**.
5. The same run on the **6 Sep talk** (55:39) passes checks 2 and 3; render time recorded (EE open question
   E7) and fed to `StageTiming`.
6. On **`two-people-mixed.mp4`** with the corner person on Remove: the picture output check passes; with
   hiding switched off for that track in a test build, the output is stopped with the time of the first
   unaccounted face; re-transcribed, 0 `say` runs remain.
7. Snapshots and one real-window capture of the Viewer on the Video rendition with the Timeline-lite,
   looked at; playback proved from `--debug-playback-log` (two `currentTime` lines 3 s apart differ by
   2.5 to 3.5 s, rule 2.1.10).
8. Regression set; `make migrate-check`.
9. *Ivan:* the listening check of EE 1.8: three random 30 s windows of the 13 Sep video, "did anything
   sound cut?"; and E3, a 3-minute count of "um" in the 6 Sep talk against `transcript.json`, if he wants
   the filler recall measured. A "yes" becomes a fixture for the builder.

**Parts.**
- **M8a, The edit plan:** `Words`, `Envelope`, `RoughCut`, `Restarts`, `EditPlan`, `PlanValidation`, the
  "Planning the edit" step writing `edit-plan.json`, the Timeline-lite showing the plan on Original. No
  file a person could post is made. Checks 1 (`RoughCutTests`), 2 measured on the plan against the
  original's audio (cut points, pauses, kept length; the Parakeet halves wait for M8b), 8.
- **M8b, The rendered MP4:** composition, compositor (no hiding yet), writer, video audio, captions,
  `Description.txt`, the Ready checklist, `OutputGate`, the `editedVideo` output kind. **By construction,
  Make Video refuses any recording whose people check has not run or found anyone not Included**, with
  the line "Video for recordings with other people arrives in the next update"; the 13 Sep talk (Gabriel
  only) is made. Checks 1 (`RenderTests`), 2, 3, 5, 8.
- **M8c, Video in the Viewer:** the Video rendition through the same compositor, Restore and Remove,
  Delete and Command-Z, struck-through words, the Captions overlay. Checks 4, 7, 8.
- **M8d, People in the video:** hiding in the compositor (M6d's `FaceHide`), Remove as cut time, the
  picture and sound output checks, the notice's third wording; the refusal from M8b is removed in this
  part only. Checks 6, 8, and 3 again on `two-people-mixed`.

**Needs Ivan.** The listening check (not blocking). D3 matters from here: 1080p recordings limit zooms in
M9 and shorts in M11.

### M9. House style and direction

**Goal.** The MKBHD grammar in Prakriti's own look, and "a way to prompt or adjust the editorialization"
(REQUEST 4 and 7).

**Scope.**
- **Styles** (`Edit/Style.swift`): Clear, Calm, Energetic, Story with the numbers in EE 2.3 and 2.4, plus
  Teaching (demonstrations whole and wide), Pace (0.8, 1.0, 1.25), Length, Focus. House Style pane in
  Settings: Punch-ins (Off, Subtle, Punchy), Text (Off, Subtle, Bold), Transitions (Cuts only,
  Restrained), Captions burned on long-form (off), title font, date labels.
- **Beats** (`Edit/Beats.swift`): the model annotates each recording once (EE 3.3: beats, scores 0 to 3 for
  eight focus tags, kind, standsAlone, dependsOn, keyLine, hookCandidate, terms), on the "Planning the edit"
  task's provider under the lock; validated in Swift (word ids exist, key lines word for word); cached by
  transcript hash. Requests to LM Studio use temperature 0 with a fixed seed, recorded in the beats
  file, so a check run twice on the same transcript reads the same beats **[whether LM Studio honours the
  seed for this model is checked on the day; if not, the cache is what keeps runs comparable]**.
- **Direction** (`Edit/Direction.swift`): the field and preset capsules; a rules table for common phrases
  (faster, calmer, energetic, punchy, fewer or more cuts, zooms, text, captions, "under N minutes"), the
  model only for the rest, its output limited to the fields of EE 3.2; never who appears, consent or
  publishing ("People are chosen under People"). Shown back as removable chips before rendering.
- **Selection** (`Edit/Selection.swift`): the small knapsack of EE 3.3 under the length target, keeping the
  thesis and closing beats and dependencies, order kept.
- **Visual plan** (`Edit/VisualPlan.swift`): punch-ins centred on the face track with the eye line on the
  upper third, never past the frame edge, alternating scales, capped by
  `min(style scale, 1.15 x sourceHeight / outputHeight)` so a 1080p source never goes past 1.15 (EE 2.6);
  slow push-ins at most 1.05; back to wide at each new beat; demonstrations at 1.00 in Teaching; key-phrase
  text (2 to 6 words, the speaker's exact words, on the empty side, never over a face); lower third once per
  Included named teacher; term cards spelled from the Yoga Marga word list; the hook cold open (model picks
  three candidates, code checks each word for word); chapters (first at 0:00, at least three, each 10 s or
  more); the held moment; speech ending 5 s before the last frame.
- **Overlays** (`Render/Overlays.swift`): each text item designed as a SwiftUI view, rendered once with
  `ImageRenderer`, cached, moved and faded by the compositor with EE 2.7's timings; the chosen OFL typeface
  bundled with its licence file.
- **The plan before rendering:** the progress block shows the plan in plain lines ("Cuts pauses longer
  than 0.4 s. Punch-ins about every 8 s. Keeps the story at 12:40. Ends at 11:48.") with Make and Stop.
- **Versions:** each Make Again is a version (direction, chips, made time, length, files); Play and Use This
  Version; Approve names one version.
- Direction tab in the inspector (DS 3.5.3), the Timeline-lite marks lane (punch-in, text, transition,
  chapter symbols), Quick Help for spans. `style` capability on; H08 rewritten to these names.

**Files.** `Edit/Style.swift`, `Edit/Beats.swift`, `Edit/Direction.swift`, `Edit/DirectionRules.swift`,
`Edit/Selection.swift`, `Edit/VisualPlan.swift`, `Edit/Hook.swift`, `Edit/Chapters.swift`,
`Render/Overlays.swift`, `Render/Compositor.swift` (zoom and overlay), `Resources/Fonts/` (OFL family and
licence), `Model/Models.swift` (`EditVersion`), `Views/Inspector/DirectionTab.swift`,
`Views/Settings/HouseStylePane.swift`, `Writing/Writer.swift` (the planning prompt, with W51's rule on
private matters), `StyleTests`, `make accept-style`, Help 08, BUILD-LOG.

**Acceptance.**
1. `make test` with `StyleTests`: every rules-table phrase maps to its fields; the model's interpretation is
   rejected when it names a field outside the vocabulary; "show the students" changes nothing and returns
   the People sentence; the knapsack honours dependencies and the length target on synthetic beats.
2. Typeface: the IAST test string rendered in three candidates to `screens/mac/v2-m9/typeface.png`, looked
   at; the chosen face's `CTFont` has a glyph for every character of the string.
3. `make accept-style MILESTONE=v2-m9` on the **13 Sep talk** (beats by Qwen3.8-27B in LM Studio, timed):
   - Clear: visual changes a minute 6 to 8 measured from the plan, 10 or more in the first 30 s; every
     punch-in scale at most 1.15 (1080p source); every on-screen text equals the transcript's words for its
     range (normalized for case and spacing).
   - "More energetic. Faster, more frequent cuts.": chips include Style Energetic and Pace faster; visual
     changes a minute 12 to 15; median shot 3 to 4 s.
   - "Focus on the parts that are motivating or enlightening. Under 10 minutes.": length at most 10:00 and
     at least 8:30; the mean motivating plus enlightening score of kept beats is higher than of dropped beats.
   - A pace-only change after the first annotation makes 0 model requests (LM Studio request count) and
     shows its plan in under 10 s.
4. Frames rendered at every text moment and at three punch-ins: every text box inside the frame's title-safe
   area and not intersecting any face box (measured with Vision); the eye line within the upper third
   plus or minus 5% in punch-ins. The PNGs looked at.
5. The M8 checks 2 and 3 pass on the Energetic version (rough-cut quality and the platform checklist).
6. Two versions exist; Play switches the Viewer between them; Approve's model names version 2.
7. Snapshots of the Direction tab (empty, chips, plan shown, versions) and House Style pane, looked at.
8. Regression set; `make accept-models` (the writing prompts changed); `make migrate-check`.

**Parts.**
- **M9a, House style and zooms:** `Style` (Clear, Calm, Energetic, Story, Teaching, Pace, Length as
  numbers), punch-ins and push-ins in the compositor, back to wide after three tight spans (at beats
  once M9c exists), speech ending 5 s before the last frame, the House Style pane. No model. Checks 3
  (Clear: punch-in scales; visual changes counted from cuts and punch changes only), 4 (eye line), 5 (on
  Clear), 8.
- **M9b, Text and graphics:** the typeface contact sheet and choice, the bundled OFL family, the overlay
  engine (`ImageRenderer`, cache, EE 2.7 timings), lower thirds for Included named teachers, the 2 s
  title card, the date label renderer M12b will use. Checks 2, 4 (lower thirds, title card), 8.
- **M9c, Beats and direction:** `Beats`, `Direction` and its rules table, the model for the rest,
  `Selection`, the plan before rendering. Checks 1, 3 (Energetic, Focus and length, pace-only), 8 with
  `make accept-models`.
- **M9d, Hook, chapters, versions:** key-phrase text, term cards, the hook cold open, chapters, the held
  moment, versions, the Direction tab, the marks lane. Checks 3 (Clear in full: every visual change and
  every text), 4 (every text moment), 5 (Energetic), 6, 7, 8.

**Needs Ivan.** *Ivan:* watch the Clear and Energetic versions of 13 Sep and say what is off; that answer
tunes the numbers, and the typeface contact sheet is his to overrule.

### M10. Timelines for Final Cut Pro and DaVinci Resolve

**Goal.** "An XML for FCP or DaVinci" of the same edit, finishable by hand, that cannot undo the privacy
choices (REQUEST 4).

**Scope.**
- **FCPXML writer** (`Export/FCPXMLWriter.swift`) from the `EditPlan`, one generator writing version 1.14
  (Final Cut Pro 12.4) and 1.10 (DaVinci Resolve 20.2.1, as installed; **that 20.2.1 imports 1.10 is
  [unverified]**: a vendor note says 1.10 works from Resolve 18 on, EE 5.2, and check 5 or Ivan's round
  trip settles it), EE 5.7's eight rules: whole-frame
  rational times, one asset per source with `start="0s"`, anchored items in the parent's time, transitions
  with handles, captions in an `ITT.en` role without overlaps, plain `.fcpxml` files. Whether Resolve
  keeps FCPXML caption lanes, markers and chapter markers is **[unverified]** (EE 5.2); the `.srt` beside
  the Resolve file and the Read Me cover the case where it does not.
- **Graphics** (`Export/GraphicsClips.swift`): every title, lower third, key phrase, term card and date label
  as a ProRes 4444 clip with transparency in `Graphics/`, on a lane, enabled; an editable `title` twin above
  it, `enabled="0"` (EE 5.4).
- **Media** (`Export/TimelineMedia.swift`): when everyone is Included, `Media/` holds APFS clones (`cp -c`)
  of each source; when anyone is Blur Face or Remove, it holds a **privacy-safe copy** made by the same
  compositor: faces burned in, removed speech replaced by the recording's own room tone on **every** audio
  track, a removed person's own microphone track left out entirely (their voice is on it even when others
  speak, PE 3.3 and 3.4), only the used ranges plus 2 s handles, HEVC 10-bit about 50 Mbps at 1080p (EE
  5.5, PE 3.3; **sizes are rule of thumb until measured**). The cleaned media passes the same picture and
  sound output checks as the MP4 inside `OutputGate` (PE 3.6 item 3) before any timeline that points at
  it is written. Neither timeline ever references the original or the Studio Recordings folder.
- **Gated items:** push-ins and dissolves written as markers ("Push-in here", "Dissolve here") until the
  round trip (checks 6 and 7) passes; then a stored flag `timelineAnimationsVerified` turns them on.
- Captions also as `.srt` beside the Resolve file; `Read Me.txt` (five lines: how to open each, what is
  switched off).
- Outputs tab rows for both timelines, **Open in Final Cut Pro** and **Open in DaVinci Resolve** shown only
  when `NSWorkspace.urlForApplication(withBundleIdentifier:)` finds `com.apple.FinalCutApp` or
  `com.blackmagic-design.DaVinciResolve` (both measured on this Mac, DS 3.5.1); File menu Export items.
- `timelines` capability on; H05 and H10 timeline sections.

**Files.** `Export/FCPXMLWriter.swift`, `Export/FCPXMLLint.swift`, `Export/GraphicsClips.swift`,
`Export/TimelineMedia.swift`, `Export/ReadMe.swift`, `Render/Compositor.swift` (cleaned-media mode),
`Views/Inspector/OutputsTab.swift`, menus, `FCPXMLTests`, `make accept-timeline`,
`scripts/resolve-import.py` (verifier only), Help, BUILD-LOG, START_HERE (warning: timelines never point at
originals when anyone is hidden).

**Acceptance.**
1. `make test` with `FCPXMLTests`: the DTDs are copied out of
   `/Applications/Final Cut Pro Creator Studio.app/Contents/Frameworks/Interchange.framework/Versions/A/Resources/`
   (`FCPXMLv1_14.dtd`, `FCPXMLv1_10.dtd`, both present, measured) into `build/dtd/` (xmllint cannot read
   them in place, EE 5.8), and `xmllint --noout --dtdvalid` passes for both versions of three fixture plans;
   the test is skipped with a message when Final Cut Pro is absent. Semantic lint: every time a whole number
   of frames, no spine overlap, durations sum to the sequence, every `ref` resolves, every `src` exists,
   transitions have handles, captions do not overlap.
2. `make accept-timeline MILESTONE=v2-m10a` on the **13 Sep** Clear version: both files valid; every
   `media-rep src` is under the version's `Media/`; `Media/` files are clones, proved per file and not by
   free space (another agent may be writing to the same disk): a small Swift helper reads
   `ATTR_CMNEXT_CLONEID` or `ATTR_CMNEXT_PRIVATESIZE` with `getattrlist` and finds each `Media/` file
   shares its blocks with its source **[attribute names from the SDK headers, checked on the day; `df`
   falling by under 100 MB is the fallback, run with nothing else writing]**.
3. On **`two-people-mixed`** with the corner person on Remove: `grep -c "Studio Recordings"` over both files
   prints 0; Vision on the cleaned media finds no face inside the hidden track's regions; Parakeet run on the
   cleaned media at the removed ranges finds 0 `say` runs; the cleaned media's length equals the used
   ranges plus 2 s handles.
4. `Graphics/` clips: `ffprobe` shows ProRes 4444 with an alpha channel; one frame of each looked at.
5. **DaVinci Resolve 20.2.1 import** by script: `scripts/resolve-import.py` creates a scratch project
   ("Prakriti scratch v2-m10", never an existing one), calls `MediaPool.ImportTimelineFromFile` (documented
   in Resolve's own scripting README on this Mac, which accepts FCPXML), and prints the clip count and
   duration, which must equal the plan's. **[unverified on this Mac, and likely to fail on the free
   edition]**: Resolve connects an outside script only when Preferences, System, General, "External
   scripting using" is set to Local, and third-party guides say the free edition refuses outside
   scripts whatever that setting says, allowing only scripts started from Workspace, Scripts inside
   Resolve ([Blackmagic forum](https://forum.blackmagicdesign.com/viewtopic.php?p=670352),
   [davinci-resolve-mcp](https://github.com/tooflex/davinci-resolve-mcp)); Resolve 21.1 moved Python
   scripting to Studio (Puget Systems, CineD). The script tries once and, if it cannot connect,
   writes SKIPPED with the reason and the check becomes *Ivan*: he runs the same script from Workspace,
   Scripts (steps in BUILD-LOG, about 3 minutes). Not a ship gate. The scripting keys do not include
   "Use sizing information", so punch-in scales are checked by eye in check 7.
6. **Final Cut Pro 12.4 round trip** (*not a ship gate*: it needs a person or a screen-driving session,
   and it only unlocks animations), by a verifier able to drive the screen, else *Ivan*: open a scratch
   library `~/Prakriti/Dev/Scratch.fcpbundle` (never his real library), File, Import, XML; then export XML
   again and compare clip count, offsets, scales and marker count with the file; share five frames at known
   times and compare with the MP4's frames. Written up in BUILD-LOG with the frames.
7. *Ivan or the screen-driving verifier:* the same five frames in Resolve; then in both apps switch off
   every effect and drag a clip edge outward on `two-people-mixed`: no hidden face appears and no removed
   speech is heard (PE 6.5). Only after checks 6 and 7 pass for push-ins and dissolves does the builder flip
   `timelineAnimationsVerified`, in a follow-up commit with the evidence.
8. Regression set.

**Parts.**
- **M10a, Timelines:** the FCPXML writer and lint, graphics clips, Read Me, the `.srt`, clones in
  `Media/`, the Outputs rows, Open In, File menu items. **By construction, a timeline is written only
  when everyone in the version is Included**; otherwise the row reads "A timeline for a recording with
  hidden people arrives in the next update" and nothing is written. Checks 1, 2, 4, 5, 8.
- **M10b, Privacy-safe timeline media:** cleaned media, its output checks, the refusal removed, the
  round trips and the `timelineAnimationsVerified` flag. Checks 3, 6, 7, 8.

**Needs Ivan.** Please do not update DaVinci Resolve during the v2 build: the timeline is written for
20.2.1's FCPXML, and the free 21.1 dropped scripting. Check 5 from Workspace, Scripts if the outside
script cannot connect, and the two round trips if no verifier can drive the screen (about 15 minutes
in all, steps written in BUILD-LOG).

### M11. Shorts, thumbnails, Approve and Ready

**Goal.** "100% ready for distribution": every file a platform asks for, measured against its published
rules, and Approve that refuses a file that would fail (REQUEST 4, "post ready").

**Scope.**
- **Shorts** (`Render/Shorts.swift`): up to the Direction tab's count (default 3, 30 to 60 s, never over
  180 s), chosen from beats that stand alone with a strong hook; picture from, in order, the vertical twin
  when its audio cross-correlates with the main recording within one frame (EE E6), a 4K source's crop
  (1215 by 2160 scaled down), or a 1080p crop with a capture warning that it is upscaled; a face-following
  crop with a dead zone (moves only when the face leaves the middle third); burned calm captions (one line,
  2 to 5 words, the spoken word full white, the rest 70%) inside the strict safe area of EE 6.3; -14 LUFS;
  1080 by 1920 H.264 about 10 Mbps. **The vertical twin is a second camera, so its faces are not the main
  recording's faces:** when a short uses the twin, the face step of the people pass (M6a) runs on the
  twin as its own source, its tracks are matched to the main recording's people by time and voice, and
  any twin track not matched to an Included person is hidden (unknown means hidden). Every short then
  passes the picture and sound output checks in `OutputGate`, like the MP4.
- **Thumbnails** (`Render/Thumbnails.swift`): three candidates from Media Intelligence's
  `KeyFrameAnalysisRequest` **[documented, PE 1.2; never run or timed on this Mac: the part measures it
  on its first day, and if it is unusable the candidates come from Vision's face capture quality and
  sharpness on the beats' key lines instead]** and the beats' key lines, under the safe-frame rule (every visible face an
  Included person); 1280 by 720 JPEG under 2 MB plus a full-size master (3840 by 2160 only from a 4K
  source).
- **Upload checklists** (`Render/ReadyChecklist.swift`): YouTube long-form (from M8), YouTube Shorts,
  Instagram Reels and TikTok **[Reels and TikTok specs are third-party, EE 6.2; their lines say so]**; each
  field in the platform's upload order with Copy and Show in Finder (DS 3.11).
- **Approve sheet** (DS 3.11): deliverables with checkboxes, a failing one unticked and disabled with its
  reason (C8); the version; one line per people decision; moments from other recordings; where each model
  step ran; "Nothing is uploaded or posted." Approve copies the chosen files by APFS clone into
  `~/Prakriti/Approved/<name>/` with `APPROVAL.md` extended (version, people decisions, names said aloud and
  their choice, every file's size and SHA-256). All of v1's refusals and the approval voiding stay
  (W35 to W38). Classes stay refused (section 5).
- **Ready** group: approved, and every chosen deliverable passes; "Approved, a check failed" in Needs You.
- Viewer: **Shorts** rendition ("Short 1 of 3") and the **9:16 guide** overlay on Original and Video.
- `shorts` capability on; H05 and H06.

**Files.** `Render/Shorts.swift`, `Render/VerticalCrop.swift`, `Render/BurnedCaptions.swift`,
`Render/Thumbnails.swift`, `Render/ReadyChecklist.swift`, `App/Approval.swift`,
`Views/Inspector/ApproveSheet.swift`, `Views/Inspector/UploadChecklist.swift`, `Views/Viewer/VerticalGuide.swift`,
`Model/Vocabulary.swift` (Ready, approved-with-a-failing-check), `ShortsTests`, `make accept-shorts`, Help,
BUILD-LOG.

**Acceptance.**
1. `make test` with `ShortsTests`: the safe rectangle check rejects a planted caption box outside it; the
   dead-zone crop does not move for a face inside the middle third; Approve refuses a deliverable whose
   checklist has a FAIL and copies nothing.
2. `make accept-shorts MILESTONE=v2-m11` on the **6 Sep talk** (with its vertical twin): the twin's audio
   offset measured and written down; three shorts, each `ffprobe` 1080 by 1920, 29.97, at most 180 s,
   -14 within 1 LU, true peak at or under -1, tail decoded; Vision text recognition on frames every 2 s
   reads caption words that match the transcript; the face centre inside the middle third in at least 90%
   of sampled frames; frames with the safe area drawn on them looked at.
3. On the **13 Sep talk** (no twin, 1080p): shorts made from a crop, with the capture warning in Checks.
4. Thumbnails of 13 Sep: three, 1280 by 720, each under 2 MB; Vision finds only the Included face. On
   `two-people-mixed`: the corner face hidden in every candidate.
5. Approve on 13 Sep in development (the development copy's own Approved folder under `~/Prakriti/Dev`,
   never `~/Prakriti/Approved`, rule 2.1.6): the sheet lists deliverables, version, people, "None" for moments;
   `APPROVAL.md` hashes match the copied files; a planted 190 s short is unticked and named in the sheet;
   the recording appears in Ready only when everything chosen passes.
6. No network request is made by Approve (a `URLProtocol` counter in the test reads 0).
7. Snapshots: Approve sheet (passing, one failing), Ready group, upload checklist, Viewer with Shorts and the
   9:16 guide; looked at.
8. Regression set; `make migrate-check`.

2b. On the **6 Sep** shorts made from the twin: Vision on frames every 0.5 s finds no face outside an
   Included person's matched track or a hidden region (the twin's own people step ran; log line says so).

**Parts.**
- **M11a, Shorts:** `Shorts`, `VerticalCrop`, the twin's own face step, `BurnedCaptions`, the Shorts
  rendition, the 9:16 guide. Checks 1 (safe rectangle, dead zone), 2, 2b, 3, 7 (Viewer), 8.
- **M11b, Thumbnails, Approve, Ready:** thumbnails, the upload checklists, the Approve sheet, the Ready
  group. Checks 1 (Approve refuses), 4, 5, 6, 7 (sheet, Ready, checklist), 8.

**Needs Ivan.** Nothing to build it. Before any real upload (his, by hand): the private YouTube test upload
of SCOPE SET-13 settles EE E8 (does YouTube accept the AAC priming edit list).

### M12. Moments from another recording

**Goal.** "Merge sections from different videos ... added to the video at hand but not always and not as
a rule" (REQUEST 9).

**Scope** (DS 3.8, EE 3.5):
- **Index** (`Merge/EmbeddingIndex.swift`): sentence windows of each recording's transcript embedded with
  `text-embedding-nomic-embed-text-v1.5` through LM Studio's `/v1/embeddings` **[the endpoint's request shape
  is checked against LM Studio on the day; the model id is measured]**, kept in its own SQLite file under
  Application Support, built only from spans where every face and voice is an Included named person
  (a moment from a recording with a student in frame is never offered).
- **Suggestions** (`Merge/Suggestions.swift`): from the Direction tab (this recording's main points) or from
  selected words; candidates from recordings of the same named teacher above a similarity threshold, then
  one sentence from the "Choosing moments" task's model, under the lock, saying whether it supports the
  point without contradicting it; at most three; 5 to 45 s, on sentence boundaries; exact words, date,
  where it would go.
- **Adding** is by hand only: an `insert` span with `addedBy: "ivan"`; the date label on screen by default
  (C6) for the first 3 s; loudness of each source matched before joining; colour matched to the main
  recording **[proposal, measured on two real days]**; the style's join (hard cut, or a 12-frame dissolve,
  rendered in the MP4 and gated in timelines as in M10).
- **Re-checked at every render.** People choices in the source recording can change after a moment is
  added. Plan validation re-reads the source's current people file at every Make Again and refuses an
  insert span in which anyone is no longer Included, with the line "A moment from Sun 6 Sep now includes
  someone who is hidden. Remove it or change their choice." The index drops such spans the same way.
- Empty state with the real count searched ("Prakriti searched 2 recordings of Gabriel").
- `merge` capability on; H08's moments section.

**Files.** `Merge/EmbeddingIndex.swift`, `Merge/Suggestions.swift`, `Edit/EditPlan.swift` (insert spans),
`Render/Compositor.swift` (date label, join), `Render/VideoAudio.swift` (per-source loudness),
`Views/Inspector/SupportingMomentsSheet.swift`, `MergeTests`, `make accept-merge`, Help 08, BUILD-LOG.

**Acceptance.**
1. `make test` with `MergeTests`: a span with an unnamed person is never indexed; suggestions are refused
   for a recording whose teacher differs; an added span carries `addedBy: "ivan"` and nothing is ever added
   without that call.
2. `make accept-merge MILESTONE=v2-m12`: index the 13 Sep and 6 Sep talks (both "Who is teaching:
   Gabriel"); Find Supporting Moments on 13 Sep returns one to three moments from 6 Sep, each with words
   found word for word in the 6 Sep transcript; add the first; Make Again.
3. In the new 13 Sep video: Parakeet run again hears the added words at the planned time within 0.5 s; the
   date label "6 Sep 2026" is visible in a frame 1 s into the moment (Vision text recognition and a look);
   each joined source measures within 1 LU of the target; the plan validates and the Ready checklist passes.
4. The suggestion model's requests are counted under the lock (local while Gabriel's cloud switch is off).
5. Snapshots of the sheet (suggestions, empty) and the Timeline-lite with the teal span; looked at.
6. Regression set.
7. After the moment is added, the 6 Sep corner of a planted test plan is set to an unnamed person on
   Remove in the 6 Sep people file: Make Again on 13 Sep is refused with the line above, and nothing new
   reaches `Video/`.

**Parts.**
- **M12a, Supporting moments, found:** the index, suggestions, the sheet, the empty state. Checks 1
  (indexing, teacher), 2 (up to the suggestions), 4, 5 (sheet), 6.
- **M12b, Supporting moments, added:** insert spans, the date label, per-source loudness, the join,
  the re-check at render. Checks 1 (`addedBy`), 2 (add, Make Again), 3, 5 (Timeline-lite), 6, 7.

**Needs Ivan.** Nothing.

### M13. Finish line

**Goal.** Everything true, everything checked, the handover written.

**Scope.** Every capability on. A pass over all eleven articles and the five welcome panels: every UI name
matches the build (a test lists every bold or quoted UI name in the articles and finds it in the app's
strings); the welcome panels in their final copy; up to four TipKit tips (DS 5.5) if M3 proved their size;
the "What's New" panel for v2. START_HERE ("Prakriti for Mac", the file table, new warnings), README,
CHANGELOG and a BUILD-LOG "v2 finish line" in v1's shape: what works with measured evidence, what does not,
what needs Ivan, the best picture of every screen, three things to try first.

**Acceptance.**
1. `make test`; `make accept`, `accept-outputs`, `accept-edits`, `accept-models`, `accept-podcast`,
   `accept-progress`, `accept-people`, `accept-gallery`, `accept-video`, `accept-style`, `accept-timeline`,
   `accept-shorts`, `accept-merge`, `accept-help`: all pass on one commit.
2. `make look MILESTONE=v2-finish` and the full snapshot set, light and dark: every screen looked at.
3. The live app after `make install`: heartbeat lines continue in the live log. The end-to-end drop runs
   in development, never by changing Ivan's live settings (rule 2.1.6): the installed app is opened a
   second time with `open -n ... --args --development`, Video is turned on for the development drop
   folder, and `make drop MODE=development MILESTONE=v2-finish` drops a 90 s clip that is found, made,
   and reaches "Waiting for your yes" with a playable Video rendition (proved with
   `--debug-playback-log` on a Debug build of the same commit), then removed as `make drop` describes.
   *Ivan:* the same with `MODE=live` once, if he wants to see it in his own library.
4. Em dash check over `mac/Prakriti`, `Resources/Help`, README and PLAN: prints nothing.

**Parts.** One part. Its acceptance run takes several hours (every `make accept-*`), so the builder starts
it in the background and reads the results; it is one session of attention, not of wall-clock time.

**Needs Ivan.** The "For Ivan" checklist in the finish-line entry.

---

## 7. Risks

| # | Risk | What the plan does about it |
|---|---|---|
| R1 | **Timeline imports look right in validation and wrong in the app** (the vault's 2026-07-30 lesson: in-XML compositing and animation fail silently) | Rendered graphics on lanes, static transforms only, animations gated behind a recorded round trip (M10 checks 5 to 7) |
| R2 | **The editable timeline leaks a hidden student** (one drag of a clip edge, or switching off a blur) | Privacy-safe media whenever anyone is hidden; timelines never reference originals; checked by grep, by Vision and by re-transcription (M10 check 3) |
| R3 | **A student is taken for a teacher.** Recognition and voice matching fail one way dangerously | Every threshold leans to hiding; named without asking needs two agreeing signals; unsure means unnamed (M6, M7); the output check re-finds every face and voice in the finished file (M6, M8) |
| R4 | **Today's studio files are one microphone copied to two channels** (warnings 6 and 14), so who speaks is a guess on them | Clean input is the design: the capture check flags dual mono with a tip (M4); mixed-track recordings with two voices need Ivan's listen before Approve (M6) |
| R5 | **The local model is slow and large.** Beat annotation of a 15-minute talk is estimated at 8 to 12 minutes, longer for an hour; Qwen holds 33 to 36 GB while Vision and the renderer also want memory | Annotate once and choose in code (M9); never run the writing model and a render at the same time (the runner serializes heavy steps); the model loaded only for its step (W46) |
| R6 | **Disk.** Cleaned media is about 20 to 22 GB an hour; 4K sources several times today's 2.8 GB an hour | Clones when nothing is hidden; Approve clones instead of copying; v1's 100 GB floor for archive work stays (warning 24); 753 GiB free on Sat 10 Oct (measured); D3 decides 4K storage |
| R7 | **A milestone breaks the live engine** Ivan relies on for episode 1 (Fri 23 Oct) | Install only after a PASS (2.1.3), new outputs off and no backfill (2.1.7), episode 1's folder never remade (2.1.6), `make migrate-check` before every install with model changes |
| R8 | **Snapshots lie** (Liquid Glass and `AVPlayerView` cannot be drawn into bitmaps) | The real window is the judge in every milestone with a visual change (W7, W43) |
| R9 | **API drift.** Model ids, Anthropic betas and OpenAI's Responses events change | Model lists fetched from each provider at runtime; the request shapes pinned by tests and re-read on the build day (M5) |
| R10 | **DaVinci Resolve versions.** 20.2.1 lacks FCP 12's FCPXML; free 21.1 lacks scripting | Write 1.10 for Resolve; ask Ivan not to update during the build (M10) |
| R11 | **Media Intelligence grouping is unmeasured** (accuracy and speed need stored prints, which need releases) | M7 ships with recognition exercised only on Ivan's own clip; `make calibrate-people` runs once releases exist; SFace (Apache 2.0) is the fallback named in PE 1.4 |
| R12 | **The look depends on B-roll and 4K** (43% of MKBHD's frames are B-roll; 1080p limits punch-ins to about 15%) | Zoom caps follow the source (M9); the capture tips and the welcome ask for 4K and a second angle; poor inputs warn, never fail silently |
| R13 | **Student names said aloud** reach the video, captions and podcast | Names said aloud become Check moments that block Approve until decided (M6) |
| R14 | **Scope.** Fourteen milestones in 31 one-session parts | Order delivers what Ivan asked for by name early (icons, help, window, progress, people, video); every part ships alone; M7 runs beside M8, and M10 to M12 are independent |
| R15 | **Licences.** SF Pro in burned text, music, imitation of MKBHD's brand | OFL typeface; no music unless Ivan's folder; house style numbers, never his assets (M9) |
| R16 | **Copy drifts from the build** (help that describes a feature that is not there) | Capabilities hide unbuilt text (M2); a test of UI names (M13) |
| R17 | **A crash leaves frames of faces on disk** | Job folders deleted at the end of every job and at every launch before anything else (M6 check 7) |
| R18 | **A student's name reaches a cloud model** because `NLTagger` missed it in a talk where only Gabriel appears | Cloud writing for real recordings stays off until M5 check 3 measures recall of 90% or more and D1 is answered; names Ivan Mutes are always tokenized; the lock keeps every recording with other people local regardless |
| R19 | **A part ships a feature before its protection** (video, timelines or cloud providers before hiding, cleaned media or the lock) | Refusals in code that only the protecting part removes (M5a before M5b, M8b, M10a); `OutputGate` and `CloudPayload` make the unsafe path impossible to write, not just untested (2.2) |
| R20 | **A second camera brings its own faces** (the vertical twin; later, a second angle for the MKBHD look) | Every video source gets its own face step; unmatched tracks are hidden; every rendered file is re-checked (M11a) |

---

## 8. Decisions only Ivan can make

Three, each with a recommended answer. Everything else is a default in section 5.

**D1. What Gabriel's yes covers, for building and checking.** The verifiers are Claude sessions. Checking
the video, the people pass and thumbnails means looking at frames of Gabriel's 13 Sep and 6 Sep talks; v1's
verifiers already read his transcripts. Separately, the cloud providers can only be tested on a real talk
if his talk's text may go to Anthropic or OpenAI with names replaced (SCOPE PRV-10 counts his written yes
of Fri 9 Oct, if it came). **Recommended:** confirm that his written yes exists and covers both; then the
verifiers may look at frames of those two talks, and his cloud switch is turned on. Until you answer,
verifiers check those frames by measurement only (face counts, pixel differences) and list the pictures
for you, and cloud tests use the synthetic transcript. Serenity's switch stays off until her Q-S13.

**D2. Biometric releases.** The gallery may learn a face or a voice only with a written release (date and
where it is kept). **Recommended:** a one-page release (the notice text PE 5.6 drafts, reviewed by the lawyer
research/08 budgets), signed by you now so M7 can be tested on your own clip, and by Gabriel and Serenity
when you see them (Serenity's 30 minutes on Tue 27 Oct), kept as PDFs in a folder of yours that is not the
shared studio folder. Until they sign, they are named per recording, which already tells you when it is
Gabriel or Serenity.

**D3. Where 4K recordings live.** 4K at the OBS settings in H03 is likely 13 to 36 GB an hour
**[unverified until the five-minute test]**, and every file syncs through the shared iCloud folder to
everyone in it. **Recommended:** at the studio visit, record the five-minute test (H03, "Storage") and
multiply by the session length. If an hour is under about 25 GB, keep the iCloud share with Keep
Downloaded on the engine Mac and a larger iCloud plan if needed; if over, record to a dedicated SSD on the
studio Mac and have Prakriti read from it. Until 4K exists, everything works at 1080p with gentler zooms and
softer shorts, which the checks say plainly.

---

## 9. Sources

Project documents: `docs/v2/REQUEST.md`; `docs/v2/research-edit-engine.md`; `docs/v2/research-people.md`;
`docs/v2/design-spec.md`; `docs/v2/help/` (00 to 10 and `welcome-panels.md`); `docs/v2/icons/README.md`;
`START_HERE.md` (rules, the 34 standing warnings and the Mac app's 65); `docs/BUILD-LOG.md` (milestones 1 to
6 and "Finish line"); `docs/LOCAL-MODEL.md`; `docs/SCOPE.md` (PRV-10, SET-04, SET-05, SET-13); `PLAN.md`;
`mac/project.yml`, `mac/Makefile`, `mac/scripts/install.sh`, `mac/Prakriti/` (read Sat 10 Oct).

Measured on this Mac, Sat 10 Oct 2026: `sysctl machdep.cpu.brand_string` "Apple M5 Pro" and `hw.memsize`
68,719,476,736; `/usr/bin/xmllint`, `/opt/homebrew/bin/ffmpeg` and `ffprobe` present; Final Cut Pro
Creator Studio, Compressor Creator Studio and DaVinci Resolve installed; FCPXML DTDs 1.10 to 1.14 in Final
Cut Pro's Interchange framework; Resolve's scripting README (last updated 18 Aug 2025) documents
`ImportTimelineFromFile` for FCPXML and command-line invocation; LM Studio at `localhost:1235` lists
`qwen/qwen3.8-27b` and `text-embedding-nomic-embed-text-v1.5`; FluidAudio's diarization models present in
`~/Library/Application Support/FluidAudio/Models/speaker-diarization`; Hark depends on FluidAudio from
0.12.4; 753 GiB free on the data volume; the two talks and the 6 Sep vertical twin present in the studio
folder; v1 sources contain no `startReading` or `copyNextSampleBuffer` call; weekdays from `date(1)`.

Web, read Sat 10 Oct 2026:
- Anthropic API reference (claude-api skill, models table cached 6 Oct 2026): current model ids, effort as
  the only depth control on Claude Opus 5.5, `fallbacks: "default"` with `server-side-fallback-2026-07-01`,
  streaming for long requests.
- DaVinci Resolve 21.1 moves Python scripting to Studio:
  [Puget Systems, 10 Sep 2026](https://www.pugetsystems.com/blog/2026/09/10/how-davinci-resolve-free-v21-1-scripting-changes-affect-puget-bench/),
  [CineD](https://www.cined.com/es/davinci-resolve-21-1-released-ai-assistant-integration-via-mcp-individual-hdr-trims-and-python-scripting-moves-to-studio/),
  [Blackmagic, About DaVinci Resolve 21](https://www.blackmagicdesign.com/support/content/readme/59dd4eef1f4941c29fb8dc48b33f5c87).
- OpenAI: the models list endpoint
  ([reference](https://developers.openai.com/api/reference/cli/resources/models/methods/list/index.md)) and
  the [developer changelog](https://developers.openai.com/docs/changelog); third-party listings disagree on
  the newest model ids ([BenchLM](https://benchlm.ai/providers/openai),
  [endoflife.date](https://endoflife.date/openai-api-models)), hence ids are read at runtime.
- Every other source (Apple HIG and API pages, FCPXML reference, YouTube specs, OBS, FluidAudio, Media
  Intelligence, BIPA) is cited where it was checked, in the track documents above, and is not repeated here.
- Read in review, Sat 10 Oct 2026: DaVinci Resolve's "External scripting using" preference and the free
  edition's refusal of outside scripts, third-party reports only
  ([Blackmagic forum](https://forum.blackmagicdesign.com/viewtopic.php?p=670352),
  [davinci-resolve-mcp](https://github.com/tooflex/davinci-resolve-mcp)); the claude-api reference (cached
  6 Oct 2026) for the Anthropic request shape in M5.

---

## 10. Review

Sat 10 Oct 2026, one pass by a reviewer who did not write the plan, against `REQUEST.md`, the three
research and design tracks, `START_HERE.md` and the v1 sources. Every change below is already made in the
text above.

### 10.1 What changed, and why

**Milestones too big for one builder session (split).**
1. Fourteen milestones became **31 parts**, each one builder session with its own verifier, verdict and
   ship gate (rule 2.1.8; table in section 1; a **Parts** block in every milestone naming which checks
   each part runs). The old sizes said L is about three sessions and XL about four, but rule 2.1.1 gave
   each milestone one builder and one verifier, so a large milestone would either overrun a session or
   ship half-built. The size column is gone because every part is now one session.

**Ordering that would have left the live app broken or unsafe.**
2. **M3 split so v1's recording page stays until the Viewer replaces it.** As written, M3 deleted
   `RecordingPage` (trim, cuts, Make Again, Approve) in the same milestone that built the Viewer; a
   half-finished M3 would have left Ivan with no way to edit or approve while episode 1 ships Fri 23 Oct.
   M3a keeps v1's page as the detail view; M3b retires it only once the Viewer passes `accept-edits`.
3. **M5: the lock ships before the providers.** v1's lock let a talk with students heard go to the cloud
   if it did not mention Serenity. Shipping OpenAI or the new Anthropic client under that rule, even for one
   part, would have widened that hole. M5a moves v1's existing client behind the v2 lock first.
4. **M8 and M10 refuse unsafe cases in code until their protection exists.** Make Video (M8b) and
   timelines (M10a) work only when everyone is Included; the refusal is removed only by M8d (hiding in the
   MP4) and M10b (cleaned media). Any shipping order is therefore safe.
5. **The privacy lock cannot open on half a people check.** A recording counts as checked only when both
   the face step (M6a) and the voice step (M6b) ran; before, faces alone could have read as "no other
   people" on a recording where a student is heard but not seen.
6. **The notice says only what the build does.** The single fixed sentence promised blurred faces and
   removed voices from M6 on, before either existed; it now changes in M6c and M8d.
7. **Help files moved by name, not by `*.md`.** The glob would have shipped `welcome-panels.md` into the app
   as a help article. There are eleven articles (00 to 10), not twelve; three places corrected.

**Privacy rules that were promises, now enforced by construction.**
8. **No stored picture of a student.** M6's people file kept "one thumbnail per track" (from PE 2.1),
   which is a stored face picture of every student, the exact thing DS C2 forbids. Now only named people who
   may appear keep a picture; every other crop is made live. M6 check 7 fails on any other image file.
9. **`CloudPayload`, `OutputGate`, and a network-free `People/`, `Render/` and `Export/`** (section 2.2). The
   cloud adapter's check, the output checks and "face work never leaves the Mac" were described as things
   code should do; they are now types and a rules test, so the unsafe path cannot be written by accident.
10. **Staging for every made file** (rule 2.1.11). A video that failed the face check would otherwise sit in
    `Outputs`, one drag from YouTube.
11. **The MP4's sound is checked, not only its pictures.** M8 had a picture output check only; PE 3.6 asks
    for both. Added to M8 and to the cleaned media in M10.
12. **Faces followed at full frame rate.** Hiding held a box for 0.5 s around 2 fps detections; PE 3.2
    specifies Vision's `TrackObjectRequest` between detections, because a moving face can leave a held box.
13. **Overlapping speech cut, fail closed** (PE 3.5), which M6 did not mention.
14. **The removed person's own microphone track is left out of the cleaned media** (PE 3.3, 3.4); M10 only
    replaced their speech with room tone, but their microphone carries their voice all the way through.
15. **The vertical twin gets its own face step** (M11a, R20). Shorts cut from the 6 Sep vertical camera would
    have used the main camera's face boxes, which do not line up with a second camera, so a student in the
    vertical frame would have been shown.
16. **Moments from another recording are re-checked at every render** (M12b): a choice changed later in the
    source recording would otherwise not reach a video that already borrowed from it.
17. **Cloud writing for real talks waits for measured name recall** (R18): a talk with only Gabriel on
    camera can still name a student aloud, and `NLTagger`'s recall was never measured. Muted names are
    always tokenized.

**Acceptance checks a verifier could not run unattended.**
18. **Debug switches** (rule 2.1.10) replace three checks that read a moving picture or the menu bar:
    playback (M3 check 3, M8 check 7) from `currentTime` in the log, the menu bar status line (M4 check 2)
    from the log, Help menu search (M2 check 3) from a printed list.
19. **First launch is made, not assumed** (M2 check 5): the check deletes the development welcome flag
    first, never the live one.
20. **Clones proved per file** (M10 check 2), not by free disk space, which another agent writing to the
    same disk would make meaningless.
21. **Resolve and Final Cut round trips are not ship gates** (M10 checks 5 to 7). Research and the web say
    the free Resolve likely refuses an outside script whatever its preference says; the check now tries
    once, reports SKIPPED with the reason, and falls to Ivan running it from Workspace, Scripts.
22. **The 13 Sep "one person only" assertion** (M6 check 2) becomes *Ivan* if a real second person is found,
    instead of failing the build for the talk's content. **Before D1**, every "looked at" on a frame with a
    face is measured and listed for Ivan rather than looked at (rule 2.1.9), matching D1's own text.
23. **M13's end-to-end drop runs in development**, not by switching on Video in Ivan's live settings, which
    rule 2.1.6 forbids.
24. **Approve in M11 check 5 writes to the development Approved folder**, said explicitly.
25. **Model runs made repeatable** (M9): temperature 0 and a recorded seed for beats, flagged unverified for
    LM Studio, with the transcript-hash cache as the fallback.
26. The `WorkingTicker` test (M1 check 3) now measures something ("no timer while idle") instead of "the app
    does not wake".

**Claims the research did not support (marked or corrected).**
27. Resolve 20.2.1 importing FCPXML 1.10 is **[unverified]** in EE 5.2, as are Resolve's handling of caption
    lanes and markers; the plan stated the first as fact. Marked, with the `.srt` and Read Me as the cover.
28. `KeyFrameAnalysisRequest` is documented but never run here (PE 1.2); marked, with a Vision fallback.
29. Cleaned media sizes and render speed are rule of thumb (EE 4.2, 5.5); marked.
30. `outputProvider(for:)` with `AVAssetReaderVideoCompositionOutput` is unverified; marked. Added PE 1.7's
    measured crash (`reader.add` before `outputProvider`) and EE 4.2's `PixelBufferReceiver`, which the
    plan's deprecation rule left out and which would trip the zero-warning build (W4).
31. FluidAudio's pin: the plan said "from 0.12.4"; PE 2.5 says Hark pins 0.15.5 and the current release is
    0.17.7. The pin is now Hark's resolved version, with a test that the `embeddingsPath` field exists.
32. The Anthropic request shape was re-read against the claude-api reference (cached 6 Oct 2026) and holds
    (no `thinking` field on Opus 5.5, effort set explicitly because it defaults to `medium`, the
    `server-side-fallback-2026-07-01` header with `fallbacks: "default"`). Added: the model pop-up keeps
    only models that accept effort, and fallbacks go only to the models that support them, so choosing an
    older model from `/v1/models` cannot produce a 400.
33. swift-markdown does not parse the plan's `:::requires` fences; `HelpLibrary` handles them in a text pass
    before parsing (M2a).

**Requests not covered, or covered thinner than they read.**
34. **REQUEST 8, the gallery for returning subjects,** would have been empty until a signed release. Named
    people now appear from the day they are named, Name Only included, with their recordings and minutes
    and "Recognition off" (section 5, M7a). No print is involved.
35. **REQUEST 3a, "let me know when it's Gabriel or Serenity",** is stated honestly in the map: until a
    release, Prakriti counts everyone by itself, but Ivan names the teacher. Recognizing Gabriel unprompted
    is biometric and waits for his release by design.
36. Everything else in REQUEST maps to a part (section 3). No item was missing outright.

**Ivan's time.**
37. **Three yeses up front** (after rule 2.1.11): swift-markdown, FluidAudio and D1, so a builder never stalls
    mid-plan waiting for an answer.

### 10.2 Looked at and left alone

- **UI against "how Apple would build it".** Nothing skeuomorphic was found: no film strips, scrubbers,
  waveforms or textures; the system player is the only scrubber; Timeline-lite is outlined spans and SF
  Symbols. The sidebar, inspector, Settings window, Photos-style People and the Help window follow DS
  section 1. One choice is less Apple than the rest: a five-panel welcome, where Final Cut Pro, Pixelmator
  Pro and iWork show one panel of feature rows. It stays (DS 4.1 measured those apps and kept five panels
  because capture tips need room), with a named fallback for Ivan's look in M2b.
- The decisions in section 5 and D1 to D3 are unchanged except the two rows added (pictures in the people
  file, Name Only in the gallery).

### 10.3 The final list of parts

M0 Baseline. M1 The new icons. M2a Help window. M2b Welcome window. M3a Main window and Settings.
M3b The Viewer. M4a Progress and Activity. M4b Capture check. M5a The new privacy lock. M5b Anthropic
and OpenAI. M6a Faces in a recording. M6b Voices and names. M6c Choices applied to audio. M6d Hiding in
pictures. M7a People, named. M7b Recognition. M8a The edit plan. M8b The rendered MP4. M8c Video in the
Viewer. M8d People in the video. M9a House style and zooms. M9b Text and graphics. M9c Beats and
direction. M9d Hook, chapters, versions. M10a Timelines. M10b Privacy-safe timeline media. M11a Shorts.
M11b Thumbnails, Approve, Ready. M12a Supporting moments, found. M12b Supporting moments, added.
M13 Finish line.

---

## 11. Answers before the build (Sonny, Sat 10 Oct 2026; Ivan said "start the v2 build when the plan's ready")

- **swift-markdown: yes.** Apple's own package; render Help articles with it. Pin an exact version.
- **FluidAudio: yes,** at exactly the version Hark already resolves (read Hark's Package.resolved).
- **D1: the safe default applies.** No written yes from Gabriel was found in his thread as of Sat 10 Oct. So
  verifiers check frames of his 13 Sep and 6 Sep talks by measurement only (face counts, pixel differences)
  and list the pictures for Ivan; cloud providers are tested on the synthetic transcript only. Serenity's
  cloud switch stays off.
- **D2: the default applies.** No releases yet: people are named per recording; the gallery stores no face
  or voice prints; M7b's live recognition check is recorded as blocked-needs-ivan, not failed.
- **D3: the default applies.** Everything works at 1080p with the gentler zoom limits; the checks say so.
- **Order:** the podcast-ready output (separate run) must be committed and installed before M0 starts.
- **Ivan, Mon 12 Oct: switch writing to the Claude API.** Local Qwen was too slow (58 min per package). He is
  creating an Anthropic key (workspace-scoped) and will paste it into Prakriti himself; it lives in the
  Keychain only. Default writing provider becomes Anthropic, model claude-sonnet-5-5 (Opus 5.5 optional for the
  accuracy pass); LM Studio stays as the fallback and as the forced provider under the privacy lock (classes,
  or other people heard or seen). Gabriel's own talks may go to the cloud by Ivan's decision. Never read,
  log or test with Ivan's real key; tests use a stub.
- **Ivan, Mon 12 Oct: designed YouTube thumbnails, previewed on every tile.** (1) Each recording tile in the
  browser grid shows the chosen YouTube thumbnail once one exists (a real video frame until then; never the
  placeholder ring when a frame can be read). (2) Thumbnails are designed, not screenshots: the best real
  frame of the teacher (Vision aesthetics and face-capture quality; eyes open, expressive, sharp), subject cut
  out and placed (Vision foreground mask), a 2 to 4 word headline (not the title) in large type, high
  contrast, one focal point, readable at 168 px wide, following the thumbnail research in
  research-edit-engine.md and MKBHD's thumbnail conventions (clean, one subject, minimal words, strong
  color separation; never his brand). (3) Yoga Marga's own brand from brand-yoga-marga.md: Alegreya /
  Alegreya Sans, saffron #DC6B09, earth #975131, gold #F3CF8A, black and white. Three options per video,
  each a different composition, with a one-line reason; the chosen one shown on the tile. Faces of anyone not
  Included are never in a thumbnail (privacy rule). Built in M11b; the tile preview may land earlier (M3/M8)
  using a plain frame. Thumbnail headlines come from the writing model (Claude Sonnet by default).
- **Ivan, Mon 12 Oct: releases exist.** "All the participants have signed an agreement that includes that their
  likeness can be used for commercial purposes." So: (1) people found in a recording default to Include, not
  Leave Out; Include / Hide Face / Leave Out stays as an editing choice, not a privacy gate; (2) classes and
  recordings with other people may be approved, rendered, exported and sent to the cloud writer; (3) D1 and D2
  are answered: verifiers may look at frames, and the gallery may learn named people's faces and voices
  (recognition, M7b). Keep: per-person consent flag (now "signed release on file"), Forget, encryption at rest,
  and nothing published without Ivan's tap. Do not reintroduce student-specific blocks.
- **Answers to the builders' "For Ivan" items (Sonny, Tue 13 Oct, from Ivan's own decisions of 12 Oct):**
  (1) **M5a install decision: YES.** Releases are signed by all participants, so every person counts as released
  and the lock must NOT force LM Studio for talks, classes, recordings with other people, or recordings that name
  Serenity or anyone else aloud. Cloud writing (Claude API, Ivan's key) is the default for everything; the lock
  only blocks when a recording has a person marked "no release" or Leave Out by Ivan. Fix the lock this way in the
  next part, then **make install** (M5a to the latest passing part ship together) and confirm the live app writes
  with Anthropic. (2) Everyone starts as Include: confirmed. (3) Names said aloud (lineage teachers etc.) are not
  people decisions: never ask about them at Approve. (4) The hiding pictures go to Ivan for a look; not a gate.

## Part LOCK (inserted Wed 14 Oct, between M8b and M8c)

Goal: the privacy lock follows Ivan's decision of Mon 12 Oct (all participants signed releases). Change the lock so
the Claude API (Anthropic, claude-sonnet-5-5) writes every recording, including classes, recordings with other people,
and recordings that name anyone aloud; the lock blocks the cloud only for a person Ivan marked "no release" or Leave
Out. Names said aloud are never asked about at Approve. Update the lock's tests to assert the new behavior, the
notice text, Help 07 and 09, START_HERE and BUILD-LOG. Then `make install`, so everything built from M5a to M8b
reaches the live app at last.
Acceptance: unit tests show a class and a recording with an unnamed person both route to Anthropic, and a person
marked Leave Out blocks it; the full suite passes; the live app is installed (a new pid), its Settings show Anthropic as
the writer, and a fresh Activity sweep is logged; one real write on the 13 Sep talk goes through Anthropic and its
cost is recorded (a few cents).
- **Wed 14 Oct, Sonny: video audio at 320 kbps AAC is accepted** (the Mac's AAC encoder tops out at 320; YouTube's
  384 is a recommendation, and 320 AAC is transparent for speech). Read M8b's 384 as 320 everywhere.

## Part TXGAP (inserted Wed 14 Oct, after LOCK)

The M8b run found two 17-second stretches of Gabriel speaking on the 6 Sep talk with no transcript (Parakeet dropped
them). Fix at the cause: transcribe in overlapping chunks (or re-run any gap of speech longer than 3 s with no words,
found by comparing the sound envelope to word times), merge without duplicates, and make the coverage check fail on
any such gap, not only at the tail. Acceptance: both 17 s stretches on the 6 Sep talk now have words; a coverage test
plants a silent-text gap and catches it; the 13 Sep transcript is unchanged except for any newly found words; full
suite passes; make install.
- **Wed 14 Oct, Sonny (Ivan asked whether the test material could be smaller): routine checks use 5-minute
  excerpts** cut with ffmpeg -c copy from the 13 Sep talk (from 2:00) and the 6 Sep talk (from 20:00), kept in
  ~/Prakriti/Dev/Excerpts/. Full-length runs on both talks happen only on the LAST part of each milestone group
  (M8d, M9d, M10b, M11b, M12b) and at M13. Any check whose bar is a full-length count (joins, coverage, words)
  is scaled to the excerpt and says so.
