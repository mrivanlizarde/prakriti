# People, faces and voices: research for Prakriti for Mac v2

Written Sat 10 Oct 2026 for the v2 build, from Ivan's request and the decisions in `REQUEST.md`.
Track: who is on screen, who is speaking, the People gallery, Include or hide per person, and how
face and voice prints are kept. Everything marked **measured** was run on Ivan's M5 Pro (64 GB,
macOS 27.2, Xcode 27 SDK 27.0) on Sat 10 Oct between 21:49 and 22:05, while another build session
was using the Mac (load average 3.6 to 8.4), so real numbers will be the same or a little faster.
Everything marked **[unverified]** was not confirmed against a source or a run.

**How the measurements were made, and what was kept.** Small Swift programs in the session's
scratch folder (not in this repository) read the development test clips of the 13 Sep talk in
`~/Prakriti/Dev/Clips` (1920 by 1080, 29.97 fps, H.264), ran Apple's face requests in memory and
printed only counts and timings. No face print was written to disk, no frame was looked at, and
the only frames written to disk (120 JPEGs for Apple's face analyzer) were in the scratch folder.
Every sampled frame of that clip held exactly one face, the speaker's.

---

## The short version

1. **Apple shipped a public face-grouping engine in macOS 27: `FaceGroupAnalyzer` in the new
   Media Intelligence framework.** It is the Photos People idea as an API: it finds faces in
   images, stores them in a folder you choose, groups them into "entities" (one per person), and
   can **identify faces in new images against that gallery without storing anything**. Measured:
   30 ms per 1080p frame, and the store's files did not change after identifying 120 frames.
   Build recognition on it. Do not build recognition on Vision's `GenerateImageFeaturePrintRequest`:
   Apple's own header says that print comes from the image classifier, not a face model.
2. **Vision does everything around recognition, fast.** Face boxes (revision 4, new and default in
   macOS 27: better precision and recall, tighter boxes), 98 landmark points, face capture quality,
   person masks and frame-to-frame tracking. Measured per hour of 1080p at 2 frames a second, one
   face: **about 2.6 minutes** for detection, landmarks, quality and decoding. The whole people
   pass (faces and voices) should take **3 to 4 minutes per hour** on this Mac. It always runs on
   the Mac, even when a user turns on the OpenAI or Anthropic option for the writing.
3. **Only consenting, named people go into the gallery.** Unnamed people are found, tracked and
   blurred, but never put into the gallery and never matched across recordings. Within one
   recording they are grouped by **continuous tracks**, not by face prints, so nothing biometric
   about a student is ever written to disk. Naming someone later (a guest who agreed) adds them to
   the gallery from that moment, and only then.
4. **"Who is speaking" comes from the microphones first.** With clean inputs (one microphone per
   person on its own OBS track, which REQUEST.md assumes), who speaks when is a measured fact, and
   FluidAudio's voice match only confirms the microphone is still on the right person. With one
   mixed track, FluidAudio's offline diarizer (10.6% error on the AMI meeting set, 323 times real
   time on an M5 Pro, its own benchmark) plus a voice match against the gallery does the job, and
   anything unsure counts as someone else.
5. **Face and voice are linked by lip movement.** The face whose mouth moves when a voice is
   active is that voice's face. Vision's 98 landmarks give mouth opening per frame; correlate it
   with each voice's activity. Two signals that agree (face match and voice match) let Prakriti
   say "Gabriel" without asking; one signal alone means it asks.
6. **Three choices per person, not two axes:** **Include** (seen and heard), **Hide Face** (heard,
   face hidden), **Leave Out** (face hidden and their speech cut). Leave Out is the default for
   everyone unnamed. A blurred face with the voice kept is not anonymous (YouTube's own privacy test
   counts a voice), so Hide Face is for people who agreed to be heard but not seen.
7. **Privacy has to be in the pixels and the sound, not in a timeline effect.** A blur in an FCPXML
   is an effect anyone can switch off, over the original footage that still holds the student's
   face and voice. The editable timeline must point at a **privacy-safe copy of the media** (faces
   burned in, removed speech gone). Final Cut's own Censor effect and shape masks can be keyframed
   in FCPXML, but only as a visible marker of what was hidden, never as the hiding.
8. **Prove it on the output, the way milestone 5 proved cuts.** After rendering, detect every face
   in the finished video again and identify every voice again; any face or voice that is not an
   Included person and not inside a hidden region stops the output with the time it happened.
9. **The People gallery copies Photos' words and moves:** People screen of round key photos,
   Favorites first, a person page with "Review More" ("Is this Gabriel?" Yes or Not), Make Key
   Photo, Merge, Rename, Hide from People, and one thing Photos does not need: **Forget Face and
   Voice**, which deletes the prints. Each person shows recordings, minutes on screen and minutes
   speaking.
10. **Prints are encrypted per person and can be destroyed per person.** Voice prints and the
    face crops the gallery is built from live in Prakriti's own folder, each person's under their
    own key in the Keychain; Apple's face store is treated as a rebuildable index, purged and
    rebuilt when someone is forgotten. The folder is excluded from Time Machine.

### What this changes in REQUEST.md

| Decision in REQUEST.md | What the research says | Proposed change |
|---|---|---|
| Face prints "for people Ivan names and marks has agreed" | BIPA asks for a **written release** from the person, and recognition is a different use from appearing in a video (research/08 P6) | "Has agreed" records the date of a written release and where it is kept, with separate switches for face and voice. Add **Name Only** (a label, no recognition) for anyone without a release |
| Unnamed people's prints "live only for the job that found them and are then deleted" | research/08 P9 is stricter: never written to disk, never compared across recordings. Apple's grouping needs a store on disk; tracks do not | Unnamed people are grouped by track, with no prints on disk at all. The count shown is honest: "up to 3 other people at once" |
| Per person: Include / Blur (faces) / Remove (their segments) | A blurred face with the voice kept still identifies; "Remove" for a silent person on screen cannot cut them out | Include / Hide Face / Leave Out, defined in section 3.1. Same default for unnamed people (face hidden, speech cut) |
| Editable timeline (FCPXML, Resolve) "so a person can open the same edit" | A blur effect in the XML can be switched off, and the original media under it still holds the faces and voices | Keep the decision, add a rule: the timeline references privacy-safe media whenever anyone in it is hidden or left out |
| Cloud option for a Mac that is not powerful enough | The people pass is cheap (3 to 4 min per hour here) and is biometric processing | The people pass is never sent to a cloud model, and no frame goes to one before it is blurred |
| "Let me know when it's Gabriel or Serenity, or other people" | Warning 23: a notice never carries a name or title | The recording's row and page say the names; a notice says only the fixed sentence "Other people are in a new recording" |

---

## 1. What Apple gives us on macOS 27

### 1.1 Finding, measuring and following faces: Vision

All checked in the macOS 27.0 SDK's `Vision.swiftinterface` on this Mac, and against Apple's
documentation where it exists.

| Request | What it gives | Use in Prakriti | Measured (ms per frame, 1080p) |
|---|---|---|---|
| `DetectFaceRectanglesRequest`, revision 4 | Face boxes with roll, yaw, pitch. Revision 4 is new in macOS 27 and the default: "better precision and recall, and bounding boxes tend to be tighter" ([doc](https://developer.apple.com/documentation/vision/detectfacerectanglesrequest/revision-swift.enum/revision4)) | Every face, every sampled frame | **5.7** (revision 3: 4.6). The first calls after launch were slower (23.9 average over a 90 s clip) while the model loaded |
| `DetectFaceLandmarksRequest`, revision 4 | 98 landmark points, including inner and outer lips and pupils ([doc](https://developer.apple.com/documentation/vision/detectfacelandmarksrequest/revision-swift.enum/revision4)) | Mouth opening for "who is speaking", eyes open for key photos | **5.5** |
| `DetectFaceCaptureQualityRequest` | 0 to 1: "better lit, sharper, and more centrally positioned" ([doc](https://developer.apple.com/documentation/vision/detectfacecapturequalityrequest)) | Choosing which frames to identify and which to use as key photos | **4.2**. On the talk: median 0.47, lowest 5% under 0.27, best 0.69 |
| `TrackObjectRequest` | Follows a box from frame to frame ([doc](https://developer.apple.com/documentation/vision/trackobjectrequest)); Apple's sample re-seeds trackers from fresh detections, "for instance... every ten frames" ([sample](https://developer.apple.com/documentation/vision/tracking-multiple-objects-or-rectangles-in-video)) | Moving the blur between the 2 fps detections, at full frame rate | **3.3** per face per frame |
| `GeneratePersonInstanceMaskRequest` | A mask per person ([doc](https://developer.apple.com/documentation/vision/generatepersoninstancemaskrequest)) | Hiding a whole body when a face is turned away; checking every body has an accounted face | **92.8** (expensive: use on samples, not every frame) |
| `DetectHumanRectanglesRequest` | Body boxes | Cheap check that every person has a face assigned or hidden | **6.3** |
| `GenerateImageFeaturePrintRequest` | A 768-number image print (measured) | Rejecting near-duplicate frames for thumbnails, as in Apple's thumbnail sample. **Not identity** (1.3) | **2.9** per face crop |

Decoding every frame of the 10-minute clip with `AVAssetReader` took 3.7 s in total.

### 1.2 Recognizing people: Media Intelligence, new in macOS 27

`MediaIntelligence.framework` is in the macOS 27.0 SDK and documented: "Analyze video content and
group faces in images using on-device machine learning" ([framework](https://developer.apple.com/documentation/mediaintelligence)).
Its `FaceGroupAnalyzer` ([doc](https://developer.apple.com/documentation/mediaintelligence/facegroupanalyzer),
[article](https://developer.apple.com/documentation/mediaintelligence/detecting-and-grouping-faces-in-images)):

- `init(workingDirectory:)`: the analyzer "stores all face data and cluster assignments" in a
  folder the app chooses; the framework alone manages its contents. Measured: it creates two
  SQLite stores (`MIDataStore.sqlite`, `VUIndex.sqlite`).
- `insertOrUpdateAssets(_:)`: finds faces in image files and **persists** their face data.
- `update(subprogress:)`: groups stored faces into entities, one per person. After it, every face
  has an `entityID`.
- `identifyFaces(in:)`: "Detects and identifies faces without modifying the analyzer's data...
  without storing any face data. Each returned face has an entityID if the framework matched it
  to a known entity, or nil" ([doc](https://developer.apple.com/documentation/mediaintelligence/facegroupanalyzer/identifyfaces(in:))).
- `deleteAssets(_:)`, `deleteAllAssets()`, and `purge(workingDirectory:)`, which "permanently
  delete[s] all face data, group assignments, and metadata".

**Measured:** `identifyFaces` on 120 frames of the 10-minute clip (one every 5 s, saved as JPEG):
**30.1 ms per frame** including reading the JPEG, 120 faces found, none matched (the gallery was
empty, as expected). The working directory held the same six files at the same sizes before and
after: nothing was stored. `purge` left the folder empty.

What it does not give, and what Prakriti must do itself:

- **Images only.** An asset is an image file URL. Prakriti saves the frames it wants identified
  as image files in the job's own folder and deletes them when the job ends.
- **No confidence score.** A face is matched or not. Prakriti makes its own confidence by voting
  across a track (2.2).
- **No names, no merge, no "this is not X".** Prakriti keeps its own table: which of its own
  assets are which person. Entities are Apple's; people are Prakriti's.
- **Its store cannot be encrypted by the app** (the framework owns the files). So the gallery's
  Apple store is treated as a rebuildable index (5.2).
- **Coordinates:** `Face.bounds` is normalized with the origin at the **top left**
  ([doc](https://developer.apple.com/documentation/mediaintelligence/facegroupanalyzer/face/bounds));
  Vision's boxes have it at the **bottom left**. Convert in one place.
- **It logs asset identifiers.** Measured: the framework printed every asset ID and face ID to the
  program's output. Asset IDs must be opaque (a UUID), never a file name, because a file can be
  named after a student (warning 23's reason).
- Accuracy and speed of `update` (the grouping) were **not measured**: that needs faces of
  consenting people stored on disk, which waits for their releases (section 6, check 1).

The same framework's `VideoAnalyzer` has `HighlightAnalysisRequest` ("the most engaging segments
of a video", with an engagement level per segment) and `KeyFrameAnalysisRequest` (the frame that
best represents the video), both on device ([article](https://developer.apple.com/documentation/mediaintelligence/finding-the-best-moments-in-a-video)).
Not this track, but **the editing and thumbnail tracks should know it exists.**

### 1.3 What is not there

- **No face identity in Vision.** The macOS 27 Vision interface has no face print, face
  recognition or person identification request. `GenerateImageFeaturePrintRequest`'s header says
  its revisions are "the feature print produced by the `VNClassifyImageRequest` classifier", a
  whole-image scene print. On the same face in the same shot, consecutive samples measured a
  distance of 0.10 typically, 0.23 at the 95th percentile and up to 0.54: it moves with pose and
  light, and nothing says it separates two people. Use it for duplicate frames, not for people.
- **Photos' People is not reachable.** The macOS 27 Photos framework headers have no person, face
  or people API (checked). Prakriti cannot read Ivan's Photos library's people, and should not.
- **Vision's private face library** (`libfaceCore.dylib`, which exports an "extract faceprint"
  option) has no header and is private API. Never use it.
- **No speaker diarization from Apple** in Speech, SoundAnalysis or AVFAudio in the macOS 27.0 SDK
  (checked again: zero matches), as research/02 §7.2 found.

### 1.4 If Apple's grouping is not good enough

Only if the calibration in section 6 fails:

- **SFace** (OpenCV Zoo): a MobileFaceNet face-recognition model, "All files in this directory are
  licensed under Apache 2.0" ([model](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface)).
  OpenCV's own code uses a cosine similarity of 0.363 (or a distance of 1.128) as "same person"
  ([sface.py](https://github.com/opencv/opencv_zoo/blob/main/models/face_recognition_sface/sface.py)).
  It would need converting to Core ML. Its training data's terms are **[unverified]**.
- **Not InsightFace's models.** Its code is MIT, but its pretrained models are "for non-commercial
  research purposes only" ([README](https://github.com/deepinsight/insightface)). Prakriti may be
  offered to other users (the cloud option implies it), so that rules them out.

### 1.5 Speed for one hour of 1080p (M5 Pro)

| Step | Rate | Per hour | Measured or estimated |
|---|---|---|---|
| Decode all frames | 3.7 s per 10 min | 22 s | Measured |
| Detect faces, 2 frames a second (revision 4) | 5.7 ms a frame | 41 s | Measured |
| Landmarks and capture quality on those frames | 9.7 ms a frame | 70 s | Measured |
| Identify with `FaceGroupAnalyzer`: best 5 frames per track plus one every 10 s | 30 ms a frame | 11 s for one person present all hour | Rate measured, plan estimated |
| Follow hidden faces at full frame rate | 3.3 ms per face per frame | 6 min per hour **of a hidden face on screen** | Measured rate |
| Person masks on samples (only when bodies need hiding) | 93 ms a frame | 11 min at 2 fps | Measured rate |
| Hiding the faces while rendering (Core Image, GPU) | 0.73 ms against 0.47 ms a frame without | about 30 s | Measured |
| Voices: FluidAudio offline diarizer | 323 times real time (FluidAudio's AMI benchmark on an M5 Pro) | about 11 s | [FluidAudio Benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md) |

So a clean studio hour with one or two people: **3 to 4 minutes** for the whole people pass, plus
the render (encoding dominates; research/02 measured HEVC at about 8.7 times real time). macOS 27
runs only on Apple silicon ([PetaPixel](https://petapixel.com/2025/06/10/macos-26-tahoe-is-the-end-of-the-road-for-intel-macs/)),
so every Mac that can run Prakriti has the Neural Engine these requests use; an M1 will be slower
by an amount **not measured**. A 4K source can be analyzed from a 1080p decode (set the reader's
output size) and rendered at full size.

### 1.6 Accuracy: what goes wrong, and the rule for each

- **Profile views.** Revision 4 still found the face at 68 degrees of yaw on the talk, but
  recognition from a side view is weak. Identify only on frames with yaw within 40 degrees and
  capture quality of at least 0.35 (starting values, set by calibration); let the track carry the
  name through the turned-away frames.
- **Lighting and focus.** Capture quality falls with both. The studio talk measured a median of
  0.47; a frame under 0.25 is never used to identify anyone and never as a key photo.
- **Glasses, hats, masks, a new haircut.** Photos counters these with upper-body matching and
  synthetic masks in training ([Apple ML research](https://machinelearning.apple.com/research/recognizing-people-photos));
  `FaceGroupAnalyzer`'s handling is **[unverified]**. Expect the same person to split into two
  entities now and then (sunglasses one day). Merge in the person page handles it.
- **Small faces** (a back row, a Zoom tile): a face can be found long before it can be
  recognized. Anything too small to identify is unknown, so it is hidden. Detection, not
  recognition, decides what gets hidden.
- **Error rates differ between groups of people.** NIST's study of 189 algorithms found false
  match rates varying by demographic group, often by a factor of 10 or more
  ([NIST IR 8280](https://nvlpubs.nist.gov/nistpubs/ir/2019/NIST.IR.8280.pdf), not re-read this
  session). Apple reports work to narrow the gap in Photos (same research page). Rule: a face
  alone never makes someone Included unless the gallery match is strong and repeated (2.2).
- **The dangerous mistake is one way round.** Taking a student for Gabriel shows the student.
  Taking Gabriel for a stranger only hides Gabriel until Ivan says "Yes". Every threshold leans
  toward hiding.

### 1.7 Traps found while measuring (for the builder)

- `AVAssetReader.startReading()` and `copyNextSampleBuffer()` are **deprecated in macOS 27**, and a
  deprecation warning fails Prakriti's build (Mac warning 4). Use `try reader.start()` and
  `reader.outputProvider(for:)` with `await provider.next()` (macOS 26). **`outputProvider(for:)`
  adds the output itself:** calling `reader.add(output)` first crashes with "cannot add an output
  that has already been added" (measured).
- The synchronous `AVVideoComposition(asset:applyingCIFiltersWithHandler:)` is deprecated since
  macOS 15. Use the macOS 26 `AVVideoComposition(applyingFiltersTo:applier:) async throws`, whose
  applier gets `AVCIImageFilteringParameters` (`sourceImage`, `compositionTime`, `renderSize`)
  (SDK, `AVFoundation.swiftinterface`).
- Revision 4's tighter boxes leave hair, ears and the jaw outside the box. Pad hidden regions
  (1.6 times the box, an ellipse with a soft edge) rather than blurring the box.
- Vision's first calls after launch load models and run several times slower. Warm up on one
  frame before timing or showing a progress estimate.

---

## 2. Grouping people: inside a recording and across recordings

### 2.1 The people pass, step by step

It runs after transcription and before writing, because its answer ("other people appear or
speak") is what turns the writing's privacy lock on (REQUEST.md: classes, or recordings where
other people appear or speak, stay on local models).

1. **Detect** every face at 2 frames a second (revision 4), with landmarks and capture quality.
2. **Track.** Link detections into tracks: the same face in consecutive samples when the boxes
   overlap (intersection over union of at least 0.3), broken at a scene cut or after 1.5 s unseen.
   A track is one person for as long as the camera keeps seeing them.
3. **Pick frames to identify:** per track, the 5 best by capture quality within the yaw limit,
   plus one every 10 s for long tracks.
4. **Identify** those frames with the gallery's `FaceGroupAnalyzer.identifyFaces` (nothing stored).
5. **Vote** per track (2.2): named person, "ask", or unnamed.
6. **Voices** (2.5): microphone tracks or diarization, then a voice match against the gallery.
7. **Link** faces and voices by mouth movement (2.6).
8. **Decide** per person with the defaults (3.1) and write the recording's people file: tracks
   (times and boxes only), voice segments, links, decisions, one thumbnail per track.
9. **Forget** everything else: the frames saved for identifying, and every voice embedding of
   anyone not in the gallery, which never left memory.

### 2.2 Confidence without a score: votes

`identifyFaces` answers per frame. A track's answer comes from its frames:

- **Named, without asking:** at least 3 identified frames, at least 60% of them the same person,
  and no frame matched to anyone else. If the track also speaks, the voice must match the same
  person (2.5); a voice that says someone else turns it into "ask".
- **Ask ("Is this Gabriel?"):** some frames match but not enough, or face and voice disagree.
- **Unnamed:** no frame matches anyone.

These numbers are starting points, to be set by the calibration in section 6 so that a stranger is
taken for a named person in fewer than 1 in 1,000 tracks. Until Ivan answers an "ask", that track
is treated as unnamed (hidden, speech left out).

### 2.3 The gallery across recordings: consenting people only

- **Who is in it:** only people Ivan has named and marked with a written release (section 5).
  Today that would be Gabriel, Serenity and Ivan.
- **What it holds:** small face crops (one face per image) chosen from recordings Ivan has
  confirmed, up to about 50 per person, spread across days, light and angles; each crop's origin
  (recording, track, time) is kept so it can be removed later. Apple's analyzer holds these crops'
  face data and groups them; Prakriti's table maps crops to people.
- **How a person is matched:** a face matched to an entity belongs to the person whose confirmed
  crops make up that entity. An entity holding crops of two people is a conflict that Prakriti
  shows and Ivan settles; with three or four people in the gallery it should be rare.
- **How it grows:** each "Yes" in Review adds that track's best new-looking crops (those least
  like the ones already kept), then `update()` regroups. This is how Photos stays incremental: a
  conservative first grouping, then wider merging as evidence builds
  ([Apple ML research](https://machinelearning.apple.com/research/recognizing-people-photos)).

### 2.4 Merge, split, rename, and naming someone later

- **Merge** (Photos: select two, Control-click, "Merge 2 People"): both people's crops and voice
  prints become one person's. Allowed only if both have a release on file, or the merged person
  takes the stricter of the two consents.
- **This is not Gabriel** (Photos: "This is Not [name]"): the track becomes unnamed in that
  recording, and any gallery crops that came from it are deleted from the gallery. Nothing about
  the person it really is gets stored.
- **Rename:** only the label changes.
- **Naming an unnamed person later** (a guest who agreed): Ivan opens the recording's People row,
  chooses Name This Person, and fills in the release (section 5). Only then does Prakriti cut the
  crops from that recording's stored track boxes and add them to the gallery. Other unnamed tracks
  in that recording are then identified against the new entry, which is how a guest's several
  tracks become one person without ever grouping unnamed faces on disk.

### 2.5 Voices: who is speaking

**With clean inputs (the plan):** one microphone per person, each on its own OBS track. Then:

- A one-time setup per studio layout: "Track 2 is Gabriel's microphone, Track 3 is Serenity's".
- Who speaks when is a track being active: its level well above the others (6 dB is a starting
  value), so a voice picked up by a neighbour's microphone is not counted as that neighbour.
- Every recording, a voice match of each track against its person's stored voice print catches a
  swapped microphone. A track whose voice does not match is an unnamed voice.

**With one mixed track (fallback):** FluidAudio, which Hark already uses (Hark pins 0.15.5;
current release v0.17.7 of 8 Oct 2026, [releases](https://github.com/FluidInference/FluidAudio/releases)):

- The **offline pipeline** (pyannote Community-1 segmentation, WeSpeaker embeddings, VBx
  grouping) is the README's "use this for most use cases" choice, and the most accurate in its own
  benchmarks: 10.6% diarization error on 16 AMI meetings at 323 times real time on an M5 Pro
  ([Benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md)).
  Its result includes each speaker's average embedding (`speakerDatabase`, 256 numbers).
- Prakriti then compares each speaker's average, and each segment of 2 s or more, with the stored
  voice prints of consenting people. FluidAudio's own `SpeakerManager` defaults to a cosine
  distance of 0.65 for "same speaker" (`Clustering/SpeakerManager.swift`, checked in Hark's copy);
  Prakriti's limit comes from calibration and leans strict.
- Speaker pre-enrollment is built into FluidAudio's streaming diarizers (Sortformer, LS-EEND:
  `enrollSpeaker(withAudio:named:)`; streaming pyannote: `initializeKnownSpeakers`), which the
  README calls reliable for streaming pyannote. For whole files, matching after the offline pass
  is simpler and keeps the better accuracy **[design choice, not measured]**.
- **Two settings that must never change:** `OfflineDiarizerConfig.Export.embeddingsPath` stays
  `nil` (when set, FluidAudio writes every embedding to disk), and the result's `speakerDatabase`
  and centroids are dropped when the job ends. Reason: those are voice prints of students.
- On the mixed studio track, diarization once labelled a student's story as the teacher
  (research/08 §0 item 2). That is why a mixed track with other voices present asks Ivan to
  listen before Approve, as v1 does with the moments it is least sure about.

### 2.6 Linking a face to a voice

Apple has no active-speaker detection. Two ways, the first is enough for clean inputs:

1. **Mouth movement against voice activity (build this).** On stretches where two or more faces
   are on screen and someone is speaking, run landmarks at 10 frames a second (5.5 ms a frame, so
   about 3 minutes per hour of such stretches), measure the inner-lip opening divided by face
   height, and correlate its movement with each voice's activity. The face that moves with a
   voice is that voice's face. With one face on screen, the link is the obvious one, but only if
   that voice is speaking while the mouth moves.
2. **A trained model (only if 1 fails):** Light-ASD, MIT licensed, 94.06% mAP on
   AVA-ActiveSpeaker ([repo](https://github.com/Junhua-Liao/Light-ASD)); it would need converting
   to Core ML, and its weights' terms are **[unverified]**.

The link gives each person both numbers Ivan asked for: minutes on screen (their face tracks) and
minutes speaking (their voice segments), and it lets two weak signals become one strong one.

---

## 3. Include, Hide Face, Leave Out

### 3.1 The three choices

| Choice | Face | Their speech | For |
|---|---|---|---|
| **Include** | Shown | Kept | Gabriel, Serenity, anyone with a release who agreed to appear |
| **Hide Face** | Hidden wherever it appears | Kept | Someone who agreed to be heard but not seen |
| **Leave Out** | Hidden wherever it appears | Cut, in sound and picture | Everyone unnamed (the default), anyone who has not agreed |

Every output can override a person's choice for that output only, as REQUEST.md asks ("let me
choose who should be included in the output videos and audio"). Audio-only outputs (the podcast)
use the speech column only. A person with no release cannot be set to Include; the control says
why in one line.

Other things that identify a person and are not this track, but must be in the same check: names
said aloud (name muting, research/08 P4), names on screen such as Zoom tiles (Vision text
recognition), and distinctive clothing or tattoos when a face is hidden (person masks).

### 3.2 Hiding a face in the rendered video

- **Where:** in the render, through `AVVideoComposition(applyingFiltersTo:applier:)` (macOS 26).
  For each frame, look up the hidden tracks' boxes at that time and composite.
- **Boxes at full frame rate:** the 2 fps detections are joined by a tracker at full frame rate,
  re-seeded from each detection (Apple's sample does this every few frames). Pad to 1.6 times the
  box as a soft-edged ellipse, and **keep hiding for 0.5 s after the last sighting and before the
  first**, so a face turning into view is never visible for a frame.
- **How strong:** blurred and pixelated faces can sometimes be recognized again by software
  ([McPherson, Shokri, Shmatikov, 2016](https://arxiv.org/abs/1609.00408)). Use a heavy blur (a
  radius of at least a quarter of the face's width) followed by pixelation of no more than 8
  blocks across the face, or an opaque soft fill. Measured cost with a 40 px blur and 24 px
  pixelation on 1080p: **0.26 ms a frame** on the GPU.
- **When a face is lost:** if a hidden person's body (human rectangle or person mask) is in frame
  but their face is not found, hide the head region of the body box. Unknown means hidden.
- **Reframing is the gentler tool:** the editing track's punch-in zooms (the MKBHD grammar) can
  crop an unnamed person at the frame's edge out entirely. Prefer a crop that removes them to a
  blur that shows something is hidden; the output check (3.6) decides whether either worked.

### 3.3 The editable timeline: privacy lives in the media

What FCPXML can carry (FCPXML 1.14 DTD, bundled in Final Cut Pro 12.4 on this Mac at
`Final Cut Pro Creator Studio.app/.../Interchange.framework/.../FCPXMLv1_14.dtd`; Apple's online
DTD is 1.10, [DTD](https://developer.apple.com/documentation/professional-video-applications/document-type-definition)):

- `filter-video-mask` holding `mask-shape` elements and a `filter-video`; every `param` can hold a
  `keyframeAnimation` of `keyframe time= value=` points. So a shape mask over a blur, moved by
  keyframes from Vision's boxes, is expressible.
- `object-tracker` and `tracking-shape` exist, and Apple's own example is "Add a blurry circle to a
  person's face to help preserve anonymity" ([object-tracker](https://developer.apple.com/documentation/professional-video-applications/object-tracker),
  [tracking-shape](https://developer.apple.com/documentation/professional-video-applications/tracking-shape)).
  But the tracking data sits in a file referenced by `dataLocator`, in Final Cut's own format:
  Prakriti cannot write it **[inferred]**.
- Final Cut's built-in **Stylize > Censor** effect (`Censor.moef` in FCP 12.4) publishes Method,
  Amount, Center and Radius, which can be keyframed. The exact parameter keys for the XML must be
  read from a project exported by Final Cut **[unverified]**.
- DaVinci Resolve 20.2.1 is installed here. Whether its FCPXML import keeps Final Cut effects and
  masks was not found in any Blackmagic source; forum reports say effects often do not carry over
  **[unverified]**.

**The rule:** whenever anyone in an edit is set to Hide Face or Leave Out, the FCPXML and the
Resolve export reference a **privacy-safe copy** of the source: faces burned in, removed people's
speech and microphone tracks gone, and only the time ranges the edit uses plus 2 s handles.
Reason: an effect can be switched off by anyone who opens the project, and a timeline's media keeps
everything outside each clip's in and out points, so a student's question cut from the edit is one
drag away. Optional on top: a disabled Censor layer or markers named "Hidden: unnamed person" so an
editor sees where hiding happened. When everyone in the edit is Included, the timeline may point at
the original. The container and codec of the privacy-safe copy belong to the editing track
(research/02 measured ProRes 422 at 39 times real time; it is large).

### 3.4 Cutting a person's speech

- **Leave Out cuts time, in sound and picture,** for every stretch the person speaks, widened to
  the nearest pause so no syllable is left, with the 15 ms fades milestone 5 already uses.
- With separate microphones, muting only their track is not enough: their voice is also in the
  other microphones at a lower level. Cutting the time is the default.
- The cut leaves the teacher answering a question nobody hears. The editing track can offer a short
  on-screen line that states the question in neutral words without identifying the asker **[idea,
  for the editing track]**.
- Report what was left out: "Left out 3 min 12 s spoken by other people", with each stretch
  playable, because a voice wrongly taken for a stranger would silently remove the teacher's words.

### 3.5 When two people overlap

- **Speaking at the same time,** one Included and one Left Out: cut the overlap (fail closed),
  widened to the Included person's word boundaries, and list it for listening. Keeping only the
  Included person's microphone through the overlap is a choice Ivan can make per stretch after
  listening ("Keep Gabriel's microphone here"), never automatic: the other voice bleeds into it.
- **Faces overlapping on screen,** one Included and one hidden: hide the union; where the hidden
  region covers part of the Included face, hiding wins.
- **A hidden person's body in front of an Included person:** a person mask on the samples, hidden
  as a region, the same rule.

### 3.6 Proving it on the output

The same idea as milestone 5's acceptance (Parakeet run again on the approved episode heard 0 of
the 73 five-word runs inside the cut):

1. **Faces:** detect faces in the finished MP4 at 5 frames a second (revision 4, about 1.7 minutes
   per hour) and identify them against the gallery. Every face must be an Included person, or
   inside a hidden region of the plan. Any other face stops the output: "A face Prakriti cannot
   account for at 12:41."
2. **Voices:** run the voice match on the finished audio. Every stretch of speech must match an
   Included person; anything else is listed for listening and blocks Approve until heard.
3. **Media handed to an editor:** the same two checks on the privacy-safe copy.

---

## 4. The People gallery, modeled on Photos

### 4.1 What Photos does (current Photos for Mac guide)

From Apple's "Find and name photos of people and pets" ([guide](https://support.apple.com/guide/photos/phtad9d981ab/mac)):
Collections > **People & Pets**; **Name this Person**; **Rename**; "**This is Not [name]**" on a
face; **Review More Photos** with **Yes** or **Not** per suggestion, then Done; **Make Key Photo**;
**Favorite** and Unfavorite; **Sort by Name** or **Sort by Custom Order**; select several, then
**Merge [number] People**; **Hide this Person**, "Hide from People & Pets Album". Underneath,
Photos groups conservatively first, then merges across moments, and declares faces that match no
one "unknown" ([Apple ML research](https://machinelearning.apple.com/research/recognizing-people-photos)).

### 4.2 Prakriti's version

| Photos | Prakriti | Difference, and why |
|---|---|---|
| People & Pets | **People** in the sidebar | Grid of round key photos. Favorites first and larger |
| Unnamed faces across the library | **Unnamed, this recording only**: a section listing recordings that have unnamed people | Never grouped across recordings (REQUEST.md; BIPA). Each opens that recording's People row |
| Name this Person | **Name This Person...** opens the consent sheet (5.6) | A name with recognition needs a release; **Name Only** is the alternative |
| Review More Photos (Yes / Not) | **Review** on a person page: "Is this Gabriel?" over a face from a track, with a 5 s clip of its voice when it speaks. **Yes** / **Not Gabriel** | Ordered by how unsure Prakriti is, and by recordings waiting for approval first |
| This is Not [name] | **Not Gabriel** on any face in a recording | The track turns unnamed; any gallery crops from it are deleted |
| Make Key Photo | **Make Key Photo** | Default key photo: highest capture quality, yaw within 15 degrees, eyes open (landmarks). Real frames are allowed for Gabriel and Serenity (REQUEST.md) |
| Merge [number] People | **Merge 2 People** | Allowed only when both have a release |
| Favorite | **Favorite** | Same |
| Hide this Person | **Hide from People** | Only declutters the grid; recognition continues. Stopping recognition is Forget |
| (none) | **Forget Face and Voice** | Deletes the person's prints (5.4). Their name stays on recordings already checked |
| Sort by Name or Custom Order | Same two | Same |

**A person's page:** key photo and name; one line of status ("Recognized on this Mac since 12 Oct.
Written release dated 12 Oct."); three numbers: **recordings**, **minutes on screen**, **minutes
speaking**; the list of recordings with, for each, a plain bar of when they were on screen and when
they spoke (flat bars, no film strip; Ivan's never-skeuomorphic rule); Review; and at the bottom,
Forget Face and Voice.

**A recording's People row** (on the recording page, above the outputs): one round photo per
person and per unnamed track, the name or "Unnamed 1", their minutes on screen and speaking, and
the three-way choice (Include, Hide Face, Leave Out) as a segmented control. Clicking a photo plays
the recording from that person's first appearance in the in-app viewer.

**"Let me know when it's Gabriel or Serenity, or other people":** the Recordings list and the
recording page say it in words: "Gabriel. Serenity. Up to 2 other people at once. 1 other voice."
Today lists recordings with other people first. A notice says only the fixed sentence "Other people
are in a new recording" (Mac warning 23: no names or titles in notices, which show on lock screens).

"Up to N at once" is the honest count: the most unnamed faces in any one frame. Because unnamed
tracks are not grouped by face prints, Prakriti does not claim a total.

---

## 5. Biometric privacy: carrying out the policy

The policy is REQUEST.md's, with research/08 P6 and P9: prints only for named people with a
release; nothing persistent for anyone else; consent per use and revocable. The legal reasons are in
research/08 §3.4 (BIPA: a voiceprint or "scan of... face geometry" is a biometric identifier, and
photographs are not, [740 ILCS 14/10](https://lig.ilga.gov/legislation/ilcs/documents/074000140K10.htm)).
One later ruling supports the design for unnamed people: in *Zellmer v. Meta* (9th Cir., June
2024) face signatures of non-users, compared against consenting users and deleted at once, were
held not to be biometric identifiers ([Hunton](https://www.hunton.com/privacy-and-cybersecurity-law-blog/ninth-circuit-holds-face-signatures-used-for-photo-tag-suggestions-are-not-biometric-information));
it does not bind Illinois courts and is criticized ([Eric Goldman](https://blog.ericgoldman.org/archives/2024/06/facebook-defeats-bipa-face-scanning-lawsuit-zellmer-v-meta.htm)).
Prakriti's design goes further than that case: an unnamed face is compared and dropped in memory,
by Apple's own no-storage call.

### 5.1 What is kept, for whom, and where

| What | Named, with a release | Unnamed or Name Only | Where |
|---|---|---|---|
| Face crops the gallery is built from | Yes, encrypted, up to about 50 | Never | `~/Library/Application Support/Prakriti/People/Faces/` |
| Apple's face store (`FaceGroupAnalyzer` working directory) | Yes (derived from the crops) | Never | `~/Library/Application Support/Prakriti/People/FaceIndex/` |
| Voice prints (256-number embeddings) | Yes, encrypted, a few per person | Never; in memory for the job only | `~/Library/Application Support/Prakriti/People/Voices/` |
| Face tracks: times and boxes | Yes | Yes (needed to hide them) | The recording's people file in Application Support. **No landmarks** for unnamed people: landmark points are face geometry |
| One thumbnail per track | Yes | Yes (a photograph, so Ivan can decide) | Same; deleted with the recording |
| Frames saved for identifying | Deleted when the job ends | Deleted when the job ends | The job's own folder |
| Names, consent record | Yes | Name Only keeps the name | The SwiftData store (not biometric) |

Never in: `~/Documents` or anything iCloud syncs, Outputs, Approved, REPORT.md, logs, notices,
FCPXML metadata, the web app, or any cloud request (REQUEST.md item 5's cloud option included).

### 5.2 Encryption at rest

- **FileVault is on** on this Mac (`fdesetup status`, checked). That protects the disk when the
  Mac is off; the rest protects the data while it is on and in backups.
- **Per-person keys.** Each named person's crops and voice prints are sealed with AES-GCM (CryptoKit)
  under that person's own 256-bit key. Destroying the key makes every copy unreadable, including
  any copy that slipped into a backup.
- **Keys in the Keychain,** never in a file or preference (as the Claude key, Mac warning 52). The
  better home is the data-protection keychain with "after first unlock, this device only", so
  overnight runs with the screen locked still work and the key never syncs or restores to another
  Mac ([kSecUseDataProtectionKeychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain),
  [this device only](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)).
  On macOS that keychain needs entitlements "authorized by a provisioning profile"
  ([TN3137](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains)), which
  Prakriti's signing does not have yet. Until it does, use the login keychain the app already uses.
  Not "when unlocked": a locked screen would stop the overnight watcher's people pass.
- **Out of Time Machine:** set "excluded from backup" on the whole `People` folder. Ivan's Mac backs
  up to a local Time Machine disk (checked); without this, every forgotten print would live on in
  old backups. Losing the gallery with the Mac costs a few minutes of Review, not the recordings.
- **Apple's store is an index, not the record.** It cannot be encrypted by Prakriti, so it holds only
  what the encrypted crops can rebuild, and it is rebuilt from them whenever anyone is forgotten.
- **Known limit:** local APFS snapshots can hold deleted files for up to a day **[unverified for
  macOS 27]**. Key destruction covers the crops and voices; Apple's index is covered by the rebuild.

### 5.3 Consent, per named person

Stored for each person in the gallery:

| Field | Why |
|---|---|
| Name, role (teacher, guest, operator) | Who it is |
| Face recognition: yes or no; voice recognition: yes or no | Separate uses (research/08 P6) |
| Release date, and where the signed release is kept (a file or a place) | BIPA asks for a written release, and Ivan must be able to show it |
| Which version of the notice they saw | The notice text will change after the lawyer's review |
| Who recorded it, and when | Accountability |
| Last appeared | Retention (5.4) |

Recognition consent is **not** consent to appear in published videos: that is the publication
consent research/08 handles. The People page shows both lines, separately.

### 5.4 Deleting, and keeping no longer than needed

- **Forget Face and Voice:** destroy the person's key, delete their crops and voice prints, delete
  their assets from Apple's index, then purge and rebuild the index from everyone else's crops.
  Their name stays on past recordings (a name is not biometric). Then check: opening their sealed
  files must fail, and identifying one of their old crops must return no match.
- **Retention:** a person's prints are deleted automatically 12 months after their last appearance
  in a new recording, with a line on Today 30 days before. BIPA's outside limit is 3 years after
  the last interaction (research/08 §3.4); 12 months is a proposal for Ivan.
- **Every job cleans up after itself, and every launch checks:** a crash mid-job must not leave
  saved frames behind. On launch, before anything else, Prakriti deletes any job folder left over.
- **Deleting a recording from Prakriti** deletes its people file and thumbnails.
- **A published retention schedule** is a BIPA duty (section 15(a)); it belongs on the school's
  privacy page, written with the lawyer research/08 budgets for **[for Ivan]**.

### 5.5 Never leaves the Mac

The people pass, the gallery and the output check run on the Mac in every configuration. With the
OpenAI or Anthropic option on, no frame is sent before hiding is applied, no unhidden student frame
is ever sent, no face crop or voice clip is sent for "who is this", and a recording where other
people appear or speak keeps its writing on local models (REQUEST.md's lock).

### 5.6 Words on screen

Ivan's copy rules: no em dashes, no "we", no "Processing", names in labels instead of tooltips.
Proposed text (the lawyer reviews the release itself, not these labels):

- People page, empty: "No one is recognized yet. When a recording is checked, name the people in
  it and Prakriti learns them for the next time."
- Unnamed section title: "Unnamed, this recording only"
- Under it: "Prakriti does not learn people you have not named. It hides their faces and leaves
  out their voices unless you choose otherwise."
- Consent sheet title: "Recognize Gabriel in new recordings?"
- Consent sheet body: "Prakriti can learn Gabriel's face and voice so it finds him in new
  recordings by itself. It keeps them only on this Mac, locked, and deletes them if he changes
  his mind or has not appeared for 12 months."
- Switches: "Learn his face" and "Learn his voice"
- Fields: "Written release signed on" (a date) and "Where the signed release is kept"
- Buttons: "Learn Gabriel" and "Name Only"
- Without a release: "Name Only keeps the name on this recording. Prakriti will not look for
  Gabriel in other recordings."
- Forget, button: "Forget Face and Voice"
- Forget, confirmation: "Delete what Prakriti learned about Gabriel's face and voice? His name
  stays on recordings already checked. This cannot be undone."
- Review: "Is this Gabriel?" with "Yes" and "Not Gabriel"
- Include control, no release: "Gabriel can be shown once his release is recorded."
- Recording line: "Gabriel. Serenity. Up to 2 other people at once. 1 other voice."
- Output check failure: "A face Prakriti cannot account for at 12:41. Hide it or include the
  person, then Make Again."
- Left out speech: "Left out 3 min 12 s spoken by other people. Listen to each part."

---

## 6. How to verify (each a check the builder runs, and Ivan can watch)

1. **Calibration, once releases are signed.** From recordings where Gabriel, Serenity and Ivan
   appear, label 200 tracks by hand (in the app's Review). Measure: how often a named person is
   recognized without asking, how often a person is taken for another, and how often a face from a
   recording of none of them (a public clip with permission, or synthetic faces) is taken for one of
   them. Set the vote and voice limits so the last is under 1 in 1,000 tracks. This is also the
   first measurement of `FaceGroupAnalyzer.update`'s grouping and speed, which this session did not
   run (it stores prints, and no one has a release yet).
2. **Nothing stored for strangers.** Identify a recording that holds no gallery person; afterwards,
   the gallery's files must be unchanged in size and date, the job folder gone, and FluidAudio's
   export path unset. (Measured once for `identifyFaces` today.)
3. **The output check catches a miss.** Plant a face the plan does not hide (turn hiding off for one
   track in a test) and render: the output must be stopped at that time.
4. **Hiding holds through motion.** A test clip with a person walking across the frame and turning:
   play the rendered file and look at every frame where they enter and turn (render one and look at
   it, the 19 Jul lesson).
5. **The editable timeline is safe.** Open the exported FCPXML in Final Cut and the Resolve export in
   Resolve, switch off every effect, and look: no hidden face appears, and extending a clip's edges
   finds no removed speech.
6. **Forget works.** Forget a test person; their sealed files fail to open, their old crop is not
   identified, Apple's index was rebuilt, and Time Machine's exclusion is on the folder.
7. **Speed.** Time the people pass on a full hour; it should be under 5 minutes on this Mac.

---

## 7. Open questions for Ivan

1. **Releases:** Gabriel, Serenity and you each sign a short biometric release before the gallery
   holds anyone (research/08 F4 already proposed it, with one lawyer's review). Who keeps the signed
   copies, and where?
2. **Retention:** delete a person's prints 12 months after they last appear. Shorter or longer?
3. **The three words:** Include, Hide Face, Leave Out. Keep, or rename?
4. **Counting unnamed people:** "up to 2 other people at once" instead of a total, because Prakriti
   will not group strangers by their faces. Is that enough for your "let me know"?
5. **The archive's Zoom recordings** (gallery tiles, name labels): REQUEST.md says design for clean
   inputs. Proposal: the same rules apply (every face not in the gallery is hidden, names on tiles
   are found by text recognition), with no special features for Zoom layouts.

---

## Sources

Apple (all fetched or checked Sat 10 Oct 2026):
- Vision: [face rectangles revision 4](https://developer.apple.com/documentation/vision/detectfacerectanglesrequest/revision-swift.enum/revision4),
  [landmarks revision 4](https://developer.apple.com/documentation/vision/detectfacelandmarksrequest/revision-swift.enum/revision4),
  [face capture quality](https://developer.apple.com/documentation/vision/detectfacecapturequalityrequest),
  [TrackObjectRequest](https://developer.apple.com/documentation/vision/trackobjectrequest),
  [tracking sample](https://developer.apple.com/documentation/vision/tracking-multiple-objects-or-rectangles-in-video),
  [GenerateImageFeaturePrintRequest](https://developer.apple.com/documentation/vision/generateimagefeatureprintrequest),
  [person instance mask](https://developer.apple.com/documentation/vision/generatepersoninstancemaskrequest),
  [Vision updates](https://developer.apple.com/documentation/updates/vision) (lists nothing for
  2026; revision 4 is documented on its own page). The macOS 27.0 SDK on this Mac: `Vision.swiftinterface`,
  `VNGenerateImageFeaturePrintRequest.h`, `Photos.framework/Headers`, `libfaceCore.tbd`.
- Media Intelligence: [framework](https://developer.apple.com/documentation/mediaintelligence),
  [FaceGroupAnalyzer](https://developer.apple.com/documentation/mediaintelligence/facegroupanalyzer),
  [identifyFaces(in:)](https://developer.apple.com/documentation/mediaintelligence/facegroupanalyzer/identifyfaces(in:)),
  [Detecting and grouping faces in images](https://developer.apple.com/documentation/mediaintelligence/detecting-and-grouping-faces-in-images),
  [Face.bounds](https://developer.apple.com/documentation/mediaintelligence/facegroupanalyzer/face/bounds),
  [Finding the best moments in a video](https://developer.apple.com/documentation/mediaintelligence/finding-the-best-moments-in-a-video),
  and `MediaIntelligence.swiftinterface` in the SDK.
- AVFoundation in the SDK (`AVFoundation.swiftinterface`, `AVVideoComposition.h`): `outputProvider(for:)`,
  `AVVideoComposition(applyingFiltersTo:applier:)`, and the macOS 27 deprecations.
- [Recognizing People in Photos Through Private On-Device Machine Learning](https://machinelearning.apple.com/research/recognizing-people-photos)
- [Photos for Mac: find and name photos of people and pets](https://support.apple.com/guide/photos/phtad9d981ab/mac)
- FCPXML: [reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference),
  [object-tracker](https://developer.apple.com/documentation/professional-video-applications/object-tracker),
  [tracking-shape](https://developer.apple.com/documentation/professional-video-applications/tracking-shape),
  [DTD 1.10](https://developer.apple.com/documentation/professional-video-applications/document-type-definition);
  DTD 1.14 and `Censor.moef` inside Final Cut Pro 12.4 on this Mac.
- Keychain: [kSecUseDataProtectionKeychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain),
  [kSecAttrAccessibleWhenUnlockedThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly),
  [TN3137: On Mac keychain APIs and implementations](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains)

Voices and models:
- [FluidAudio README](https://github.com/FluidInference/FluidAudio), [releases](https://github.com/FluidInference/FluidAudio/releases),
  [Benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md);
  Hark's copy of FluidAudio 0.15.5 in `~/Code/transcribe-app/.build/checkouts/FluidAudio`
- [SFace, OpenCV Zoo](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface),
  [sface.py thresholds](https://github.com/opencv/opencv_zoo/blob/main/models/face_recognition_sface/sface.py)
- [InsightFace license terms](https://github.com/deepinsight/insightface)
- [Light-ASD](https://github.com/Junhua-Liao/Light-ASD)
- [Defeating Image Obfuscation with Deep Learning](https://arxiv.org/abs/1609.00408)
- [NIST IR 8280, demographic effects](https://nvlpubs.nist.gov/nistpubs/ir/2019/NIST.IR.8280.pdf) (not re-read this session)

Law (secondary sources; research/08 holds the full analysis):
- [740 ILCS 14/10, BIPA definitions](https://lig.ilga.gov/legislation/ilcs/documents/074000140K10.htm)
- *Zellmer v. Meta*: [Hunton](https://www.hunton.com/privacy-and-cybersecurity-law-blog/ninth-circuit-holds-face-signatures-used-for-photo-tag-suggestions-are-not-biometric-information),
  [Eric Goldman](https://blog.ericgoldman.org/archives/2024/06/facebook-defeats-bipa-face-scanning-lawsuit-zellmer-v-meta.htm)
- macOS 27 is Apple silicon only: [PetaPixel](https://petapixel.com/2025/06/10/macos-26-tahoe-is-the-end-of-the-road-for-intel-macs/)

In this repository: `REQUEST.md`, `research/02-apple-platform.md` §2.3, §7.2, §8;
`research/08-privacy-rights.md` §0, §3.4, P2 to P12; `START_HERE.md` Mac warnings 4, 23, 50, 52.
