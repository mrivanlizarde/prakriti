# Research: the edit engine and the editable timeline

Prakriti for Mac v2. Written Sat 10 Oct 2026 by a research run for the edit-engine track. It answers
REQUEST.md item 4 ("an XML for FCP or DaVinci ... removes pauses, umms, bad takes, adds captions, text
animation, transitions, zooms, MKBHD as the template, 100% ready for distribution") and item 7 (prompt
the editorialization). Everything here was checked against the web on this date, against the apps and
SDK installed on this Mac, or against Prakriti's own recordings; anything that was not is marked
**[unverified]**. Nothing in `mac/` was changed.

Words used here: a **span** is a stretch of a recording that the edit keeps; a **cut** is the join
between two spans; a **punch-in** is a cut where the next span is shown a little closer, so the jump
reads as a second camera; a **push-in** is a slow zoom during a span.

---

## The answer on one page

1. **One plan drives every output.** The engine turns transcript + audio + direction into one
   `EditPlan` (spans tied to transcript word IDs, plus zooms, text, captions, chapters). The MP4, the
   in-app preview, the Final Cut Pro and DaVinci Resolve timelines, the captions and the chapters
   are all written from that one plan, so they cannot disagree. The podcast's cut list (v1's
   `EpisodeEdits`) becomes one projection of it.
2. **Mechanical cleanup is code, not the model.** Pauses, filler words, stutters and restarts are
   found by code from Parakeet's words checked against the audio. The model only makes editorial
   choices (what to keep for length and focus, the hook, emphasis, chapters).
3. **Do not trust Parakeet's word end times for pauses.** Measured on the 6 Sep talk: 326 of 502
   audible pauses of 0.3 s or more sit *inside* a word's time span (Parakeet stretches the word
   before a pause). Pause cutting must read the audio. This is a property of the transcriber, not of
   messy capture, so it applies to clean inputs too.
4. **Restart detection needs a guard for teaching rhythm.** Of 13 places in the 6 Sep talk where two
   sentences in a row start with the same three words, about a third are restarts and two thirds are
   deliberate parallel phrasing ("Some people can't afford to get a massage. Some people can't
   afford to..."). Cutting those would damage the teaching. Rule: keep the last *complete* take, and
   when unsure, keep both and leave a "Check" marker.
5. **House style:** hard cuts, alternating punch-ins of about 12% on jump cuts, rare slow push-ins,
   sparse key-phrase text in the speaker's own words, no burned captions on long-form (sidecar
   `.srt`), calm burned captions on shorts, no music by default, -14 LUFS. Three alternatives:
   Calm teacher, Energetic, Documentary. Tables in section 2.
6. **Direction from a prompt:** the model annotates each recording once (beats with scores such as
   motivating or enlightening); a prompt then becomes bounded parameter changes plus re-weighting,
   solved in code in seconds. The model is only asked again for a focus it has not scored. This
   keeps the local Qwen model usable for iteration (about 10 minutes per model call, measured in v1).
7. **Render with AVFoundation and a custom compositor drawing with Core Image.** The same compositor
   plays live in the in-app viewer and renders the MP4, so preview equals output. ffmpeg stays for
   audio (v1's proven mastering) and for checks. The installed ffmpeg 9.0.1 has no `drawtext` and no
   `libass`, so it cannot draw text anyway.
8. **Editable timeline: FCPXML, written twice.** Version 1.14 for Final Cut Pro 12.4 and the same
   content at version 1.10 for DaVinci Resolve 20.2.1 (both installed here). Both validate against
   Apple's own DTDs from the FCP bundle (done on this Mac for the example in 5.6). Captions ride along
   as `.srt` for Resolve. Titles and animated text ship as rendered clips with transparency, so they
   look identical in both apps, with editable title versions included but switched off.
9. **Two traps to design around now.** (a) The vault's 2026-07-30 lesson: "In-XML compositing and
   animation silently fail on import." So keyframed push-ins and dissolves go into the timeline only
   after a round-trip test passes on this Mac. (b) **The editable timeline can leak what the MP4
   hides.** If it points at the raw recording, anyone who opens it can drag a clip edge and reveal a
   removed student, or see an unblurred face. When anyone is blurred or removed, the timeline must
   point at a cleaned copy of the media.

### What this changes or contradicts in REQUEST.md and SCOPE.md

| Where | What it said | What the research says |
|---|---|---|
| REQUEST, "Two deliverables per finished video" | A rendered MP4 and an editable timeline | Add a third piece when anyone is blurred or removed: the cleaned media the timeline points at (5.5). Without it the timeline undoes the privacy choices. Disk cost: about 20 to 22 GB per hour of source (5.5) |
| REQUEST, "MKBHD as the template" + item 4 "adds captions" | Captions in the edit | His long-form videos burn in no captions: 0 of 148 sampled frames ([PandaStudio](https://www.writepanda.ai/blog/mkbhd-editing-style-measured/)). Recommend sidecar captions on long-form, burned calm captions on shorts (matches SCOPE PIP-24). A switch can burn them on long-form too |
| REQUEST, "MKBHD as the template" | His grammar | About 43% of his frames are B-roll and he prefers J-cuts between real angles. Prakriti has no B-roll source; punch-ins and graphics stand in. A second camera angle at capture is the honest way to get his look (section 7) |
| REQUEST, "a DaVinci Resolve-compatible export" | One export | Resolve 20.2.1 is installed; Final Cut Pro 12's FCPXML (1.14) import arrived in Resolve 21.0 beta 4 ([Motion Media](https://www.motionmedia.com/mm-blog/davinci-resolve-21-beta-4-fcpxml-ai-updates)). So the Resolve file is FCPXML 1.10, plus an `.srt`. Updating Resolve to 21.1 (free) would let it take the 1.14 file, but the 1.10 file is the safe default |
| SCOPE PKG-07 | "the same -16 LUFS master", AAC 160 kbps, H.264 at 8 Mbps | Video master at **-14 LUFS** (YouTube turns louder audio down to about -14 and does not turn quieter audio up, per third-party measurement; a -16 master plays 2 dB quieter than neighbours). AAC at **384 kbps** stereo (YouTube's own recommendation). Video at **16 Mbps** for 1080p30 (YouTube's floor is 8; headroom for its re-encode). 1080p stays the default |
| design-spec.md and help/08 | Preset names differ between the two docs (Energetic, Calm, Faster Cuts... vs Clear, Energetic, Calm, Teaching, Highlights) | The engine has four style presets plus modifiers; a single user-facing list is proposed in 2.5. The help page's "Teaching" protections (keep demonstrations whole and wide) are adopted as a modifier |
| Font choice (not yet decided) | n/a | Do not burn SF Pro into videos: its download license limits it to user-interface mock-ups **[unverified for the copy built into macOS]**. Use an open-licence (SIL OFL) family with full IAST coverage for Sanskrit, and render the test string and look |

---

## 0. What was measured on this Mac (the ground under this document)

| What | Result | How |
|---|---|---|
| Studio recordings today | 1920x1080, 29.97 fps (`30000/1001`), H.264 High at about 6.0 Mbps, BT.709 tagged, AAC-LC stereo 48 kHz at 160 kbps, no timecode track (13 Sep talk, 947.78 s) | `ffprobe` on `Studio Recordings /2026-09-13/2026-09-13 18-25-44.mp4` |
| Parakeet model | `parakeet-tdt-0.6b-v3` through `parakeet-mlx`; token times come in 0.08 s steps | `~/.cache/huggingface/hub`, `transcript.json` |
| Does Parakeet write fillers? | Yes, some: 43 "um" and 70 "uh" in the 55-minute 6 Sep talk (about 1.1 per 100 words). Whether it writes *all* of them is **[unverified]**: needs a 3-minute hand count | Counted in `Outputs/2026-09-06 18-06-33/transcript.json` |
| Pauses hidden in words | Word gaps of 0.3 s or more by Parakeet's times: 280. Audible pauses of 0.3 s or more (`silencedetect` at -40 dB): 502. Of those 502, **326 have their middle inside a word's span**; median hidden pause 0.61 s, longest 6.32 s | Episode audio is on the same clock as the transcript (no trim) |
| Restart-looking pairs | 13 pairs of consecutive sentences share their first three words; about 4 or 5 are restarts or rephrasings, 8 or 9 are parallel phrasing or a sentence building on the last | Same transcript |
| Other disfluencies | "you know" 28, sentence-opening "Like" 20, ", like," 6, immediate word repeats ("the the") 20 | Same transcript |
| ffmpeg | 9.0.1 (Homebrew): has `zoompan`, `xfade`, `acrossfade`, `afade`, `loudnorm`, `ebur128`, `silencedetect`, VideoToolbox H.264/HEVC/ProRes encoders. **No `drawtext`, no `subtitles`/`ass`** (built without freetype and libass) | `ffmpeg -buildconf`, `-filters` |
| Final Cut Pro | Final Cut Pro Creator Studio 12.4 ships DTDs for FCPXML 1.0 to **1.14** in `Contents/Frameworks/Interchange.framework/Versions/A/Resources/` | `find`, `defaults read` |
| FCPXML 1.10 vs 1.14 | Every element this engine needs (`asset-clip`, `spine`, `title`, `caption`, `transition`, `adjust-transform`, `keyframe`, `chapter-marker`, `marker`, `adjust-volume`) is identical; 1.14 only adds things (live drawing, voice isolation, colour conform, stereo 3D, smart-collection rules) | `diff FCPXMLv1_10.dtd FCPXMLv1_14.dtd` |
| Built-in effects | `Basic Title.moti`, `Basic Lower Third.moti` present; the default transition is `FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265` (order 0 in `TransitionOrder.plist`, Cross Dissolve) | FCP bundle |
| DaVinci Resolve | 20.2.1 installed, with its July 2025 Reference Manual (the source for 5.2) | `Info.plist`, `pdftotext` |
| macOS SDK | Xcode 27.0, MacOSX27.0.sdk; Prakriti's deployment target is macOS 27.0 | `xcodebuild -version`, project |
| Example timeline | The FCPXML in 5.6 validates against both the 1.14 and the 1.10 DTD | `xmllint --dtdvalid` |

---

## 1. The automatic rough cut

### 1.1 How the existing tools do it

None of them publishes accuracy numbers. Their real quality bar is "skip what can't be cut cleanly"
plus "a person reviews before export".

| Tool | How it decides | What it lets you tune | Quality bar it states | Timeline out |
|---|---|---|---|---|
| **Descript** | Transcript-based. Flags "um", "uh" and similar (English only) and lets you delete, ignore, or replace with a gap, one by one or all at once. **"Avoid harsh cuts"** skips any filler "that can't be removed without clipping into nearby words" after an audio check. "Shorten word gaps": gaps longer than a threshold are shortened to a target, example target 200 ms ([filler words](https://help.descript.com/script-editing/filler-words.md), [word gaps](https://help.descript.com/script-editing/shorten-word-gaps.md)) | Gap threshold and target; per-instance review | Skip unclean cuts | Yes (XML to NLEs) |
| **Gling** | Transcribes, flags silences and "bad takes", user reviews in a text editor before export ([Gling](https://gling.ai/silence-remover)); how a take is chosen is not documented. Third-party reviewers describe it as silences, bad takes and disfluencies ([Unite.AI](https://www.unite.ai/gling-ai-review)) | Review per cut | Human review | XML to Final Cut Pro, Resolve, Premiere |
| **TimeBolt** | Audio threshold: anything quieter than "Filter Below Sound Level" is silence; padding keeps breath room ([TimeBolt docs](https://timebolt.notion.site/Silence-Detection-67e267311a104d7dbb391073c5960d8e)) | Threshold dB, minimum duration, padding | "Defaults are best for most recordings" | XML |
| **FireCut** (Premiere) | Silence by dB threshold and minimum gap (tutorial example 0.4 s), filler words, "remove repetition", zoom cuts at key moments; its own guide does punch-ins by hand at about 110% to 115% ([FireCut](https://firecut.ai/blog/how-firecut-streamlines-your-premiere-pro-timeline/)) | Threshold, min silence, zoom | Vendor claim: 30% to 50% less editing time | Inside Premiere |
| **AutoCut** (Premiere, Resolve) | Silences by threshold; "AutoCut Repeat" transcribes and finds repeated takes, user reviews before deleting; AutoZoom adds zooms from the audio with zoom %, min and max duration and anchor point ([AutoCut features](https://autocut.com/help-center/autocut-overview/autocut-features), [AutoCut Angles](https://www.autocut.com/en/autocutangles/), [CineD, in Japanese](https://www.cined.com/jp/autocut-plugin-now-integrates-ai-directly-into-premiere-pro-to-automatically-handle-time-consuming-tasks/)) | All of the above | CineD: "a first-pass automated cut, not a creative one"; accuracy depends on the audio | Inside the NLE |
| **Recut** | On-device audio threshold detection, $99 one-time ([BlitzCut comparison](https://blitzcutai.com/blog/best-mac-video-editor-silence-removal-2026)) | Threshold, padding **[unverified]** | n/a | XML **[unverified]** |

Common starting values from guides written about these tools: threshold -35 to -40 dB with 0.3 to
0.5 s of padding for natural dialogue ([Cutsio](https://cutsio.com/blog/final-cut-pro-remove-silence-best-settings-for-natural-cuts)).
Research on fillers: Adobe's PodcastFillers work found an ASR-based pipeline (VAD, then ASR, then a
classifier) beats keyword spotting ([Interspeech 2022](https://arxiv.org/abs/2203.15135)); its data
licence forbids commercial use, so it is a method reference only. A verbatim transcriber that keeps
fillers with sharp word times exists (CrisperWhisper, [arXiv 2408.16589](https://arxiv.org/abs/2408.16589)),
but its fast build is non-commercial; Parakeet stays.

**What Prakriti does differently:** it decides from the transcript *and* the audio, it never cuts
what it cannot cut cleanly (Descript's rule), it treats repetition as possibly deliberate, and every
uncertain decision becomes a "Check" moment for Ivan (SCOPE's "listen at the moments it is least sure
about") and a to-do marker in the timeline.

### 1.2 The pipeline, in order

1. **Words.** Read `transcript.json`; put tokens back in spoken order with v1's `EpisodeTranscript.said`
   (Parakeet's order bug, already solved); group tokens into words; give each word a stable ID
   (`w0`, `w1`...) and record the transcript's SHA-256 so a later plan can detect a changed transcript.
2. **Audio envelope.** From the dialogue track at 48 kHz: RMS in 10 ms frames (dBFS), a noise floor
   (10th percentile of the quietest second-long windows), and speech activity with hysteresis: on at
   floor + 12 dB, off at floor + 8 dB **[proposal; tune by listening]**. Clean inputs (REQUEST
   decision 1) make an energy gate reliable; a neural VAD is not needed for v2.
3. **Refine word boundaries (1.3).**
4. **Pauses (1.4), fillers (1.5), restarts and retakes (1.6)** become candidate removals, each with
   a confidence.
5. **Feasibility check** for every candidate cut (1.7): if it cannot be made cleanly, it is dropped
   and, if it mattered, marked "Check".
6. **Editorial pass** (section 3) chooses what to keep for length and focus.
7. **Visual plan** (section 2): punch-ins, push-ins, text, captions.
8. **Frame snap.** Every cut lands on a video frame boundary (33.37 ms at 29.97 fps) chosen inside
   the low-energy region, so the MP4 and the FCPXML (which must be frame-aligned, see 5.7) are the
   same edit. A filler whose surrounding quiet is shorter than two frames is not cut.

### 1.3 Fixing Parakeet's word boundaries

Parakeet's word times are good for *where a word starts*, poor for *where it ends* before a pause (v1
already found "caught." running 3 s into the silence; this research measured it across a whole talk,
section 0). Rule: a word's end is clamped to the first point where speech activity has been off for
150 ms inside the word's span; its start is moved later to the first active frame if Parakeet placed
it in silence. Then:

- **Lead-in** before the first syllable of a kept span: 80 ms (catches the consonant attack).
- **Tail** after the last syllable: from where the envelope falls to floor + 6 dB, plus 60 to 100 ms
  (the natural decay and room). Presets change these (2.4).
- A sharper option for later: forced alignment of the transcript to the audio **[not needed for v2]**.

### 1.4 Pauses: keep the breath, lose the dead air

Natural speech has short pauses inside sentences and longer ones between them. The engine never
removes a pause entirely; it **shortens** pauses longer than a trigger to a target, and builds the
shortened pause from the pause's own start and end (real room tone, and the inhale that usually sits
just before the next phrase), joined with a crossfade (1.7).

| Pause | House target | Shortened when longer than |
|---|---|---|
| Inside a sentence (no punctuation at the boundary) | 0.18 s | 0.40 s |
| Between sentences | 0.35 s | 0.60 s |
| Between paragraphs or topics (model's beat boundaries) | 0.55 s | 0.90 s |

**Protected silences.** This is a yoga school: some silences are the content. A pause is kept up to a
preset limit (House 4 s, Calm 8 s) when it follows a breath or practice cue ("inhale", "exhale",
"breathe", "close your eyes", "notice", "pause", "feel", "let that land", a question to the viewer) or
when the model marks the beat as practice. Gabriel's own standard (SCOPE PKG-07, 10 Sep): "sharper,
removing some of the dead space and 'ums'", so the default is firm but not breathless.

### 1.5 Filler words

| Class | Words | House rule |
|---|---|---|
| Always fillers | um, uh, er, erm, ah (standing alone) | Remove when the cut is clean (1.7) |
| Stutters | an immediate repeat of a word or start of a word ("the the", "I I", "w- we") | Remove the first occurrence when the two are within 0.3 s |
| Discourse markers | "like", "you know", "I mean", "kind of", "sort of", "basically", "actually", "right?" as a tag, sentence-opening "So" or "Okay so" | Keep in House and Calm; remove in Energetic only when classified as a discourse marker with high confidence |

**The "like" problem.** "Like" is a verb ("I like this pose"), a comparison ("feels like a stretch"),
an approximation ("like five minutes"), a quote marker ("she was like...") or a filler ("it's, like,
the breath"). Only the last may go. Candidate rules: it is flanked by pauses or commas, or opens a
sentence followed by a pause, or repeats ("like, like"); it is never a candidate when followed
directly by a noun phrase or a number without a pause. Candidates go to the model with three words of
context each side and the answer "filler" or "meaning" plus a confidence; anything below high
confidence is kept. Measured scale: 20 sentence-opening "Like" and 6 ", like," in 55 minutes, so this
is a small, cheap model call. "You know" (28) follows the same path.

### 1.6 Bad takes and restarts: keep the last complete take

Four detectors, from most to least certain:

1. **Spoken markers.** "Let me start over", "let me say that again", "let me try that again", "one
   more time", "take two", "from the top", "scratch that", "cut that", "sorry, let me". Everything
   from the start of the abandoned sentence (or passage) to the marker's end is removed. This is
   near-certain, which is why section 7 asks teachers to say "take two" when they stumble.
2. **Sentence restarts.** Sentence A, then within 20 s sentence B whose first three or more words
   match A's (fuzzy match 0.8 or better), **and** A looks abandoned: no closing punctuation, or it
   ends in a filler or a cut-off word, or it is under 60% of B's length, or it contains a self-repair
   ("I mean", "sorry", "no wait"). Remove A, keep B.
3. **The parallel-phrasing guard.** If A is a complete sentence and B's remainder after the shared
   opening is different content (similarity under 0.5), it is parallelism, kept: "Some people can't
   afford to get a massage. Some people can't afford to join a yoga studio" and "I love it. I love it
   because it's giving me so much". Measured: two thirds of the restart-looking pairs in the 6 Sep
   talk are this kind.
4. **Passage retakes.** A passage of 2 to 6 sentences whose meaning closely matches a later passage
   within 3 minutes (embedding similarity of 0.90 or more with `nomic-embed-text-v1.5`, already in LM
   Studio) is a candidate retake: keep the later one if it is complete, confirm with the model.

Anything between "certain" and "parallel" is **kept** and listed as a Check moment ("Possible retake
at 12:40: kept both"). Ivan's one click resolves it; the decision is remembered for that recording.

### 1.7 Audio at every cut

- **Where:** the cut point is the lowest-energy 10 ms frame inside the allowed region, then snapped
  to the nearest frame boundary that stays inside it.
- **How:** an equal-power crossfade of 20 ms centred on the cut (minimum 5 ms when the quiet region
  is tight). The crossfade uses 10 ms of "handle" from each side, taken from the removed material
  next to the cut, so **total length stays exactly the sum of the kept spans** and picture stays in
  sync. (ffmpeg's `acrossfade` shortens the output by the overlap unless the spans carry these
  handles; the plan must include them.)
- **Why not v1's fades:** v1 fades each kept part out and in over 15 ms (`EpisodeEdits.fade`). That
  dips the room tone for 30 ms at every cut; with hundreds of cuts in a talk, a crossfade keeps the
  background continuous. v1's 15 ms dip stays valid for the podcast's few hand cuts.
- **Room tone:** never insert digital silence. Shortened pauses reuse their own sound. If a gap ever
  needs filling, loop the quietest 1 s of the recording's own room with crossfades. Section 7 asks
  for 5 s of quiet at the start of each recording for exactly this.
- **Breaths:** kept by default (they are part of a natural pause). Energetic removes an inhale only
  when it is 150 ms or more before speech onset, so the next word's attack is untouched.
- **Laughter, applause, a bell:** never cut through. Apple's SoundAnalysis built-in classifier can
  label laughter and breathing **[unverified label list on macOS 27]**.

### 1.8 Quality bars: how we know the rough cut is good

Automatic, on every make:

| Check | Pass when |
|---|---|
| No cut inside a word | Every cut point sits where the envelope is at least 20 dB under the recording's speech level for at least 20 ms, or inside a crossfade |
| No clicks | Every audio join has a crossfade; no sample jump at a join exceeds the largest jump in the surrounding 50 ms |
| Every kept word survives | Parakeet run again on the output finds at least 98% of kept non-filler words, in order (v1's five-word-run check, reused) |
| Removed fillers are gone | At least 90% of removed "um"/"uh" are absent from the re-transcript |
| Pause shape | No pause longer than the preset's trigger except protected silences; median sentence pause within 50 ms of target |
| Length is right | Output duration equals the sum of kept spans within one frame |
| Sync | Video and audio cut at the same frame (J and L cuts only where the plan says) |

By ear, once per preset change: Ivan listens to three random 30 s windows and answers "did anything
sound cut?". Any yes becomes a fixture.

---

## 2. The house style: MKBHD's grammar, Prakriti's own look

### 2.1 What his editing actually does

| Element | What the evidence says | Source |
|---|---|---|
| Pace | 7.4 cuts a minute on average (6.4 to 8.9), median shot 5.5 to 6.5 s, 90th percentile 16 s. Densest at the start: 10 to 14 cuts in the first 30 s, about 3.7 per 30 s in the body, 2 to 5 in the last 30 s. Three videos, ffmpeg scene detection, so indicative | [PandaStudio, measured](https://www.writepanda.ai/blog/mkbhd-editing-style-measured/) |
| What is on screen | 48% talking head, 43% B-roll, 0 to 9% full-frame graphics, no split screens | same |
| Hook | Thesis spoken about 2.4 s in; a short brand sting only after a spoken tease | same |
| One deliberate pause | Each video has one static hold of 32 to 55 s, a reasoning or verdict monologue, at 72% to 92% of the runtime | same |
| Text | No burned-in speech captions (0 of 148 frames). One spec card about 20 s in, at most 4 bullets. Small source tags on borrowed clips. Full-frame charts for numbers | same |
| Ending | No end-screen animation or outro; speech ends 4 to 6 s before the last frame | same |
| Cuts | He prefers J-cuts (the next shot's sound starts before its picture) to plain jump cuts, while saying jump cuts can work | His Skillshare class, as summarized by [PandaStudio's search notes](https://www.writepanda.ai/blog/mkbhd-editing-style-measured/) and a course review **[class itself not readable: 403]** |
| Tools and team | The team cuts in Final Cut Pro; editor Mariah Zenk explains her cutting in the team's 2024 "how we make videos" video | [fcp.cafe](https://fcp.cafe/news/20241014), video at [youtube.com/watch?v=3dQ6yKSttEc&t=1095s](https://www.youtube.com/watch?v=3dQ6yKSttEc&t=1095s) **[video not transcribed here]** |
| His graphics package | A paid MotionVFX pack of his transitions and graphics, black and red | [Mac4Ever, 2022](https://www.mac4ever.com/mac/170509-mkbhd-a-cree-un-plug-in-final-cut-pro-premiere-resolve-avec-tous-ses-effets-video-en-promo) |
| Punch-in amounts | Not published by his team. Tools that imitate the look use about 110% to 115% | [FireCut](https://firecut.ai/blog/how-firecut-streamlines-your-premiere-pro-timeline/) **[unverified for him]** |
| Sound design, music, colour | Described only qualitatively ("thoughtful pacing, strategic music placement, purposeful sound design") | [DevX](https://www.devx.com/daily-news/four-editing-principles-that-transformed-my-creative-process/) **[no measurements]** |

### 2.2 What Prakriti takes, and what it never takes

**Takes (the grammar):** tight pacing that is densest in the opening; jump cuts disguised as a second
angle; restraint (hard cuts, almost no transitions); text only where it carries information; one
held, uncut moment for the core idea; a quiet ending that leaves room for YouTube's end screen; clean,
loud-enough, consistent sound; source labels on anything from elsewhere (Prakriti's date label on
merged moments, design-spec C6).

**Never takes (the brand):** his logo, his red and black, his fonts, his sting, intro or outro, the
MotionVFX pack, his thumbnails' look, his catchphrases. The house style takes the school's own colours
and an open-licence typeface (2.7).

**The B-roll gap.** His grammar leans on B-roll; Prakriti has none. Stand-ins, in order of preference:
a real second camera angle (section 7); the vertical twin's tighter framing **[if in sync, unverified]**;
punch-ins; key-phrase text; term cards; and, later, a folder of the school's own B-roll that the model
can place by keyword. No stock, no AI-made footage of real people (SCOPE's AI rule).

### 2.3 House preset: the numbers

| Parameter | House | Why |
|---|---|---|
| Visual changes a minute (cut, punch change, text in) | 6 to 8; 10 or more in the first 30 s | His 7.4, front-loaded |
| Median shot | about 6 s | His 5.5 to 6.5 s |
| Punch-in on a jump cut | Alternate 1.00 and 1.12; never two spans in a row at the same scale | Two scales read as two cameras; same scale reads as a mistake |
| Punch-in move | Instant (a cut, not a zoom) | A punch-in that animates draws attention to itself |
| Slow push-in | 1.00 to 1.05 over 4 s, ease in and out, at most one per 90 s, on a model-marked key line | Adds life without a cut |
| Snap zoom | Never | Not his grammar; kept for Energetic |
| Back to wide | At every new beat (topic) and after 3 tight spans in a row | Resets the eye |
| Hook | Cold open of 5 to 15 s: the strongest self-contained line (model picks three, code checks them word for word), then a 2 s title, then the talk from its real start | His tease then sting |
| Lower third | Once per teacher, at the first on-camera moment after the hook | |
| Key-phrase text | At most one per 60 to 90 s, 2 to 6 words, the speaker's exact words | help/08: "text on screen always uses the speaker's own words" |
| Term card | When a Sanskrit term is defined: the term (spelled from the Yoga Marga word list) and, only if spoken, the speaker's definition | His spec card, adapted |
| The held moment | One uncut span of 30 to 60 s for the core teaching, placed where the model marks the thesis | His "deliberate pause" |
| Captions on long-form | Off as pixels; full `.srt` alongside | His 0 of 148 frames; YouTube viewers can switch them on |
| Transitions | Hard cuts. A 12-frame cross dissolve only where a moment from another recording joins, with its date label | Restraint, plus honesty about time |
| Music | None | help/08 promise "nothing added under them" |
| Sound effects | None | Same |
| Ending | Speech ends 5 s before the last frame, picture holds wide | Room for YouTube's end screen, which uses the last 5 to 20 s ([YouTube](https://support.google.com/youtube/answer/6388789?hl=en)) |
| Loudness | -14 LUFS integrated, true peak -1 dBTP or lower | Section 6 |

### 2.4 The three alternatives, side by side

| Parameter | House | Calm teacher | Energetic | Documentary |
|---|---|---|---|---|
| For | Most talks | Meditation, breath work, slow classes, philosophy | Short motivational talks, promos | Longer stories, retreats, an arc across sessions |
| Pause inside a sentence: target / trigger | 0.18 / 0.40 s | 0.30 / 0.70 s | 0.10 / 0.25 s | 0.22 / 0.50 s |
| Pause between sentences: target / trigger | 0.35 / 0.60 s | 0.60 / 1.00 s | 0.20 / 0.35 s | 0.45 / 0.80 s |
| Protected silences kept up to | 4 s | 8 s | 2 s | 4 s |
| Lead-in / tail | 80 / 150 ms | 120 / 220 ms | 60 / 100 ms | 100 / 180 ms |
| Fillers removed | um, uh, stutters | um, uh only, only where very clean | all classes incl. confident discourse markers, breaths before cuts | um, uh, stutters |
| Visual changes a minute | 6 to 8 | 3 to 4 | 12 to 15 | 4 to 6 |
| Median shot | about 6 s | 10 to 15 s | 3 to 4 s | 7 to 9 s |
| Punch-ins | 1.00 / 1.12 alternating | 1.00 / 1.06, only on cuts that would visibly jump | 1.00 / 1.15 / 1.25 rotating | 1.00 / 1.10 |
| Slow push-ins | 1.05 over 4 s, 1 per 90 s | 1.04 over 6 s, 1 per 2 to 3 min | none | 1.06 over 6 s, 1 per 60 s |
| Snap zoom | never | never | 1.00 to 1.30 in 6 frames on a punchline, at most 1 per 45 s | never |
| Hook | 5 to 15 s cold open | none: opens on the welcome | 3 to 8 s cold open | 10 to 20 s cold open, then a title card |
| Key-phrase text | 1 per 60 to 90 s | 1 per 2 to 3 min | 1 per 20 to 40 s | 1 per 60 s, plus chapter title cards |
| Captions burned in (long-form) | no | no | yes, calm style | no |
| Transitions | hard cuts; dissolve only at a merge | hard cuts; 15-frame dissolve at a merge | hard cuts only; a merge gets a hard cut plus its label | 12-frame dissolves at chapter changes and merges |
| Music | none | none | optional bed, only from Ivan's licensed folder, 18 dB under speech | optional bed, 20 dB under speech |
| Sound effects | none | none | a soft whoosh on snap zooms, -30 dBFS or lower | none |
| Demonstrations | kept whole | kept whole and wide | may be trimmed | kept whole |

Music is never added from anywhere but a folder Ivan fills himself: YouTube blocks any Short over one
minute with an active copyright claim ([YouTube](https://support.google.com/youtube/answer/15424877?hl=en)).

### 2.5 One list of names for the app (proposal)

The engine needs four style presets and a few modifiers; the UI should say them one way. Proposed
mapping, to be settled with the design track:

| Engine | design-spec.md (3.5.3) | help/08 | Proposed single name |
|---|---|---|---|
| House | (default) | Clear | **Clear** |
| Calm teacher | Calm | Calm | **Calm** |
| Energetic | Energetic | Energetic | **Energetic** |
| Documentary | Story First | (none) | **Story** |
| Modifier: keep demonstrations whole and wide, pose names on screen | Teaching Only | Teaching | **Teaching** (a switch, works with any style) |
| Modifier: length target | Length pop-up | Highlights | **Length** (Highlights = "About 3 minutes") |
| Modifier: focus | Motivating, Enlightening | free text | **Focus** chips (section 3) |
| Pace | Relaxed, Balanced, Brisk | (none) | Pace scales the pause and cut numbers of the chosen style by 0.8, 1.0, 1.25 |
| House Style: Punch-ins Off / Subtle / Punchy | Settings | | Off; Subtle = Calm's numbers; Punchy = Energetic's |
| House Style: Text Off / Subtle / Bold | Settings | | Off; Subtle = House frequency; Bold = Energetic frequency |
| House Style: Transitions Cuts only / Restrained | Settings | | Cuts only = no dissolves even at merges; Restrained = the table above |

### 2.6 Zooms in detail

- **Centre on the face.** The punch-in centre comes from the teacher's face track (Vision, from the
  people track): the eye line sits on the upper third of the zoomed frame; the zoomed frame is clamped
  so it never shows past the source edge. For a span, the centre is fixed (a punch-in is a still
  camera). For a push-in, the centre eases from the span's start framing to its end framing.
- **Resolution budget.** Never scale a 1080p source more than about 1.15 for a 1080p output (beyond
  that the picture softens visibly; **[a taste threshold, confirm by eye]**). From a 4K source to a
  1080p output, scales up to 2.0 are free; the presets cap at 1.5 for taste. So the engine computes
  `maxScale = min(preset scale, 1.15 x sourceHeight / outputHeight)` and the Calm or House numbers
  shrink automatically on 1080p sources. Today's recordings are 1080p (section 0); this is why
  section 7 asks for 4K.
- **Ease curves** (Prakriti's own): push-in uses cubic Bezier (0.42, 0, 0.58, 1), an even ease in and
  out; snap zoom uses (0.16, 1, 0.3, 1), fast then settling, over 6 frames (200 ms); text in uses
  (0.2, 0.8, 0.2, 1) over 300 ms. In FCPXML these become `interp="ease"` or `interp="easeOut"`
  keyframes, which are close but not identical (5.4).
- **Vertical:** shorts come from the vertical twin when it exists (SCOPE PKG-08). Cropping 9:16 out of
  a 1080p 16:9 frame leaves a 608 x 1080 window, upscaled 1.78 times: visibly soft. From 4K it is a
  1215 x 2160 window, downscaled: sharp. A crop that follows the face uses a dead zone (it moves only
  when the face leaves the middle third) and a smooth follow, so the frame does not drift with every
  nod (the vault's face-lock method, "Photo-to-Video Slideshow Method").

### 2.7 Type and motion

- **Typeface:** an open-licence (SIL OFL) sans with full IAST coverage (ā ī ū ṛ ṝ ḷ ṅ ñ ṭ ḍ ṇ ś ṣ ṃ
  ḥ), or the school's own brand face if its licence covers video. Before choosing, render
  "Prāṇāyāma, Īśvara praṇidhāna, Kṛṣṇamācārya" in it and look (Sonny's rule: render the glyph, not the
  table). Do not burn SF Pro or New York into videos **[licence for the system copies unverified]**.
- **Key-phrase text:** 2 to 6 words, one line, placed in the empty side of the frame (the side the
  teacher is not on), never over the face. Words appear one after another, 70 ms apart, each rising
  16 px and fading in over 300 ms; holds 1.5 to 3 s; fades out over 200 ms. No bounce, no pop, no
  emoji (SCOPE PIP-24's "calm" applies to all text).
- **Lower third:** name in semibold, role in regular at 70% opacity; slides 24 px and fades in over
  300 ms, holds 4 s, fades out over 250 ms. No bar or box shapes drawn as objects (never skeuomorphic).
- **Date label on a merged moment:** "6 Sep 2026", small, top corner, for the first 3 s of the moment
  (design-spec C6).
- **Burned captions on shorts:** one line, 2 to 5 words a page, changing at phrase boundaries; the
  word being said is full white, the rest 70%; cap height about 64 px on a 1080 x 1920 frame; soft
  shadow, no box; inside the safe area (6.3).
- **Sidecar captions (`.srt`):** at most 42 characters a line, two lines, 20 characters a second, at
  least 5/6 s and at most 7 s on screen ([Netflix general requirements](https://backlothelp.netflix.com/hc/en-us/articles/215758617),
  [Netflix template](https://backlothelp.netflix.com/hc/en-us/articles/219375728); the 20 cps English
  figure is from a third-party summary **[unverified on Netflix's English page]**). v1 already writes
  cues from word times; the plan's clock maps them to the edited video.

### 2.8 Sound, colour, framing

- **Sound:** the video master is v1's speech chain re-targeted to -14 LUFS and true peak -1 dBTP. No
  music or effects by default. Ducking, when a style allows a bed: 18 to 20 dB under speech, 300 ms
  attack, 600 ms release **[proposal]**.
- **Colour:** keep BT.709 tags end to end (the sources are tagged BT.709). One gentle "enhance" per
  recording, computed once from a handful of frames (Core Image's auto-adjustment filters, as
  iPhoto's Enhance did) and applied evenly, never per frame (per-frame correction flickers).
  Moments merged from another day get a match to the main recording's exposure and white balance
  **[proposal, measure on two real days]**.
- **Framing:** a punch-in never cuts off the top of the head when the teacher raises their arms in a
  demonstration: in Teaching mode, demonstrations stay at 1.00.

---

## 3. Editorial direction from a prompt

### 3.1 The architecture: annotate once, choose in code

The local model is slow at writing (about 9 tokens a second; one v1 call took 10 to 14 minutes,
LOCAL-MODEL.md). Asking it to re-edit a whole talk for every "a bit faster" would make Direction feel
broken. So the work splits:

1. **Annotate once per recording (model, cached).** The model reads the cleaned transcript with
   sentence IDs and returns **beats** (topic-sized passages) with scores. Run again only if the
   transcript changes or a new focus appears.
2. **Interpret the direction (rules first, model only if needed, seconds).** Free text becomes a small,
   bounded set of parameter changes plus focus weights (3.2).
3. **Select (code, instant).** Keep beats to maximize the weighted score under the length target,
   respecting dependencies and order (3.3).
4. **Plan visuals (code, instant)** from the style's numbers and the beats' marks.
5. **Show the plan, then render** (help/08's "Removes 4 minutes 10 seconds, adds 22 zooms and 6 lines
   of text, ends at 11:48").

Only step 1, and a focus never scored before, uses the model. Everything else runs in seconds, so
"Make Again" is fast for pace, zoom and text changes.

### 3.2 From words to parameters

**The bounded vocabulary.** The model may only set these; anything else is ignored and said so.

| Field | Values | Example phrases |
|---|---|---|
| `style` | clear, calm, energetic, story | "more energetic", "calmer", "like a documentary" |
| `pace` | -2 to +2 steps (each step scales pauses by 0.85 or 1.15 and cut density the other way) | "faster", "slower", "let it breathe", "tighter" |
| `cutDensity` | -2 to +2 | "more frequent cuts", "fewer cuts" |
| `punchIns` | off, subtle, punchy | "no zooms", "more zooms" |
| `text` | off, subtle, bold | "fewer words on screen", "more text" |
| `captionsBurned` | on, off | "add captions on screen" |
| `targetSeconds` | number or null | "under 12 minutes", "about 3 minutes" |
| `focus` | list of tags with weights (motivating, enlightening, practical, story, humor, philosophy, technique, personal) plus free-text topics | "focus on motivating or enlightening moments", "keep the story about the first retreat" |
| `avoid` | list of tags or topics | "take out the story about the car" |
| `keepWhole` | list of topics or beat IDs | "keep the breathing practice whole" |
| `hook` | on, off | "start with the strongest line", "no teaser" |

**Rules first.** A keyword table handles the common phrases with no model at all (instant, offline,
predictable): faster, slower, calmer, energetic, punchy, fewer/more cuts, zooms, text, captions,
"under N minutes". **The model second**, only for what the rules cannot read, with a JSON schema and
the same Swift validation as v1 (LOCAL-MODEL rule 4); its output can only contain the fields above.

**Never in the vocabulary:** who appears, blur or remove choices, consent, publishing. Those live in
People and Approve. If a prompt asks ("show the students"), the plan says "People are chosen under
People" and changes nothing.

**Shown back as chips before anything renders,** each removable: "Pace: faster (pauses up to 0.25 s)",
"Punch-ins: every 6 to 8 s", "Focus: motivating, enlightening", "Length: about 12 min". This is the HIG
rule design-spec cites: acknowledge, keep the person in control.

### 3.3 The beat annotation and the selection

Per beat, the model returns (validated in Swift; IDs, scores and text below are illustrative, not
from a real run):

```json
{
  "beat": "b07",
  "sentences": ["s041", "s052"],
  "summary": "Pricing by value, not by hours",
  "scores": { "motivating": 2, "enlightening": 3, "practical": 2, "story": 0, "humor": 0,
              "philosophy": 1, "technique": 0, "personal": 1 },
  "kind": "teaching",
  "standsAlone": true,
  "dependsOn": ["b06"],
  "practice": false,
  "keyLine": { "from": "w2210", "to": "w2224", "text": "people confuse cost with value" },
  "hookCandidate": true,
  "terms": ["dakshina"],
  "housekeeping": false
}
```

Scores are 0 to 3. `kind` is one of: welcome, housekeeping, teaching, story, practice, question,
closing. Code adds what the audio knows: speaking rate and loudness range per beat (a proxy for
energy).

**Selection** is a small knapsack over beats (a 55-minute talk has dozens, not thousands): maximize
the sum of `score x weight` under `targetSeconds`, where weights come from `focus` and `avoid`;
always keep the thesis beat and the closing; if a beat is kept, keep the beats it depends on; keep
order (only the hook and merged moments may move). With no length target, the default keeps every
beat except housekeeping and warm-up (SCOPE PKG-07: "warm-up trimmed") and anything scored 0
everywhere.

### 3.4 The edit decision list (the plan's saved form)

Written by code (never by the model directly), stored per recording and per version
(`edit-plan.json`), and the single source for every output. The IDs, times and words below are
illustrative, not from a real plan.

```json
{
  "schema": "prakriti.editplan/1",
  "recording": "2026-09-13 18-25-44",
  "version": 3,
  "transcriptSHA256": "9f2c...",
  "frameDuration": "1001/30000",
  "style": "clear",
  "modifiers": { "teaching": false, "pace": 0, "targetSeconds": null },
  "direction": {
    "prompt": "More energetic. Focus on the motivating parts.",
    "interpreted": { "style": "energetic", "focus": { "motivating": 1.5 } },
    "chips": ["Style: Energetic", "Focus: motivating"]
  },
  "spans": [
    { "id": "k1", "source": "2026-09-13 18-25-44", "from": "w120", "to": "w188",
      "in": 40.120, "out": 52.733, "role": "hook", "text": "(the exact words of w120 to w188)" },
    { "id": "k2", "source": "2026-09-13 18-25-44", "from": "w0", "to": "w119",
      "in": 3.040, "out": 39.873, "role": "main" },
    { "id": "k9", "source": "2026-09-06 18-06-33", "from": "w5512", "to": "w5560",
      "in": 1501.480, "out": 1507.512, "role": "insert", "addedBy": "ivan",
      "reason": "Makes the same point about pricing, said more directly." }
  ],
  "removed": [
    { "kind": "filler", "words": ["w131"], "confidence": 0.97 },
    { "kind": "restart", "words": ["w402", "w415"], "confidence": 0.91, "keptTake": ["w416", "w431"] },
    { "kind": "pause", "from": 61.220, "to": 62.010, "keptSeconds": 0.35 }
  ],
  "checks": [
    { "at": "w702", "kind": "possibleRetake", "kept": "both", "say": "Possible retake at 12:40: kept both." }
  ],
  "visual": [
    { "span": "k2", "kind": "punchIn", "scale": 1.12, "center": [0.48, 0.36] },
    { "span": "k4", "kind": "pushIn", "from": 1.0, "to": 1.05, "seconds": 4.0 },
    { "span": "k5", "kind": "keyPhrase", "from": "w2210", "to": "w2214" },
    { "span": "k2", "kind": "lowerThird", "person": "gabriel", "at": "w3" },
    { "span": "k9", "kind": "dateLabel", "text": "6 Sep 2026" }
  ],
  "chapters": [ { "title": "Cost and value", "at": "w120" } ],
  "people": { "applied": "people-decisions v12" }
}
```

**Validation in Swift before anything renders** (the v1 quote check, generalized):

1. Every word ID exists in that source's transcript, and the transcript hash matches.
2. Every `text` field equals the transcript's words for that range (normalized for case and spacing),
   or the plan is refused.
3. Spans do not overlap within a source; times agree with word IDs within 0.25 s after refinement.
4. Key-phrase text and hook lines are word for word (help/08's promise).
5. **People decisions are applied after the plan and cannot be overridden by it:** any span holding
   speech of someone set to Remove is cut by code; Blur regions come from face tracks. The model never
   sees a person's name for this purpose and has no field to change it.
6. Every chapter is at least 10 s long, the first starts at 0:00, there are at least three (6.2).

### 3.5 Moments from another recording

- **Finding:** every recording's beats are embedded with `nomic-embed-text-v1.5` (text, not
  biometrics, and only for people in the gallery who agreed, per design-spec and help/08). A
  candidate is a beat from another recording of the same person with similarity above a threshold;
  the model then judges, in one sentence, whether it supports the point without contradicting it.
- **Adding:** never automatic. Added moments become `role: "insert"` spans with `addedBy: "ivan"`.
- **Joining:** loudness of each source is matched before joining (each source is measured on its own);
  picture gets the date label, the colour match (2.8) and the style's transition.

### 3.6 Time and cost

| Step | Local (Qwen3.8-27B, measured pace) | Cloud (when the privacy lock allows) |
|---|---|---|
| Annotate a 15-minute talk (about 5k tokens in, 2k to 3k out plus thinking) | 8 to 12 min **[estimate from v1's 10 to 14 min writing call]** | 1 to 2 min; about $0.13 a call on Sonnet (Sonny's measured average per call, not for this prompt) |
| A direction change that only touches pace, zooms, text | seconds, no model | same |
| A new focus never scored | 3 to 6 min **[estimate]** | under 1 min |
| "Like"/"you know" classification | under 1 min (tiny prompt) | seconds |

The privacy lock decides which column applies (classes or other people present: local only, REQUEST).

---

## 4. Rendering the final MP4 on this Mac

### 4.1 The options

| | AVFoundation + custom compositor (Core Image on Metal) | AVFoundation + Core Animation tool | ffmpeg filter graph | Core Image alone (reader, filter, writer) |
|---|---|---|---|---|
| Punch-ins and push-ins | Any curve, per frame | Animate the video layer with CA timing | `zoompan` jitters (integer pixel steps, open bug since 2015, [ticket 4298](https://ffmpeg.org/pipermail/ffmpeg-trac/2025-March/072904.html)); fix is upscale first, slow | Any curve |
| Text and captions | Pre-rendered images (SwiftUI `ImageRenderer` or Core Text) animated in the compositor | CATextLayer with CA animations | Needs `drawtext` / `libass`: **missing from the installed build** | Same as compositor |
| Face blur | Per-frame masks from face tracks | Awkward | Possible with masks, hard | Yes |
| Live preview in the app | **Yes: the same compositor runs in `AVPlayerItem.videoComposition`** | **No**: the SDK header says the Core Animation tool "works for offline rendering only" (`AVPlayerItem.h`, SDK 27) | No (render first) | No |
| Hardware decode and encode | Yes (VideoToolbox through AVFoundation) | Yes | Yes (`h264_videotoolbox`) | Yes |
| Testable frame by frame | Yes: call the render function for time t in a unit test | Hard | Only by rendering | Yes |
| Maintainable by an AI builder | Plain Swift types, compiler-checked | CA timing quirks (`AVCoreAnimationBeginTimeAtZero`, `isRemovedOnCompletion = false`) and a known freeze report ([Apple forums](https://developer.apple.com/forums/thread/726146)) | Long filter strings, errors at run time | Plain Swift, but you rebuild AVFoundation's scheduling |

### 4.2 Recommendation: AVFoundation with a custom compositor

**Why:** one renderer for the viewer and the file (Ivan's item 10, preview, shows exactly what will be
posted); any easing and any overlay; per-frame face blur; hardware codecs; and it is ordinary Swift
that can be unit-tested frame by frame. ffmpeg keeps the audio (v1's mastering chain, already
verified bit for bit) and the checks (`ebur128`, `ffprobe`, decoding the tail).

**The pieces, with the macOS 27 SDK names** (checked in `MacOSX27.0.sdk`; deployment target is 27.0,
so the new APIs are all available):

1. **Timeline:** `AVMutableComposition` (not deprecated) with `insertTimeRange(_:of:at:)` in its async
   form (the synchronous one is deprecated since macOS 15). Track A holds all jump cuts; track B is used
   only where a dissolve overlaps two spans.
2. **Video composition:** `AVVideoComposition(configuration:)` with
   `AVVideoComposition.Configuration(customVideoCompositorClass:frameDuration:instructions:renderSize:...)`.
   `AVMutableVideoComposition`, `AVMutableVideoCompositionInstruction` and
   `AVMutableVideoCompositionLayerInstruction` are **deprecated in Swift since macOS 26** ("Use
   AVVideoComposition.Configuration instead"). Built-in layer-instruction ramps
   (`AVVideoCompositionLayerInstruction.TransformRamp`) are linear only, which is one more reason for
   the custom compositor.
3. **Instructions:** a Prakriti type conforming to `AVVideoCompositionInstructionProtocol` that
   carries, for its time range, the source track(s), the scale and centre function, the overlays and
   the blur regions, all read from the `EditPlan`.
4. **Compositor:** a class conforming to `AVVideoCompositing`. Per request: read
   `sourceReadOnlyPixelBuffer(byTrackID:)` (macOS 26+; the older `sourceFrameByTrackID` is deprecated
   in 27), make a `CIImage`, crop and scale for the zoom, blur faces, composite cached text images,
   render with one `CIContext` (Metal) into `renderContext.makeMutablePixelBuffer()`, and call
   `finish(withComposedPixelBuffer:)`.
5. **Text:** each title, lower third or caption page is designed as a SwiftUI view, rendered once to an
   image with `ImageRenderer`, cached, then moved and faded by the compositor. Word-by-word reveals use
   one image per word.
6. **Writing the file:** `AVAssetReader` with `AVAssetReaderVideoCompositionOutput` (frames from the
   composition) and the ffmpeg-mastered audio as PCM, into `AVAssetWriter` (frames through
   `AVAssetWriterInput.PixelBufferReceiver`, macOS 26+). `AVAssetExportSession` cannot set a bitrate
   (presets only), so it is not used for the final file; it is fine for the 540p review proxy
   (SCOPE PKG-07).
7. **Audio:** ffmpeg builds the dialogue from the plan's spans with handles and 20 ms equal-power
   crossfades (1.7), masters to -14 LUFS, and hands a WAV to the writer, which encodes AAC-LC 48 kHz
   stereo at 384 kbps.

**Encoder settings (YouTube long-form, 1080p29.97):** H.264 High profile, CABAC
(`AVVideoH264EntropyModeKey`), average bitrate 16 Mbps, key frame every 15 frames (half the frame rate,
YouTube's "closed GOP, GOP of half the frame rate"), frame reordering on (B-frames; the exact count
of 2 is not settable through AVFoundation **[unverified]**), BT.709 colour properties, progressive,
same frame rate as the source, `shouldOptimizeForNetworkUse = true` (index at the front). For a 4K
source delivered in 4K: 45 to 60 Mbps.

**Speed to expect:** v1's research measured `h264_videotoolbox` at 8 Mbps encoding 120 s of 1080p30 in
13.1 s (about 9x real time) and ProRes 422 at 39x (research/02, 2.3). The M5 Pro has one video encode
engine and one ProRes engine ([Apple specs](https://apple.com/macbook-pro/specs)). With Core Image work
per frame, plan for 4x to 8x real time at 1080p (a 15-minute talk in 2 to 4 minutes) **[estimate;
measure on the 13 Sep talk in the first build]**.

---

## 5. The editable timeline

### 5.1 Where FCPXML is today

- Final Cut Pro 12.0 (28 Jan 2026) "Updates FCPXML to version 1.14"; 12.2, 12.3 and 12.4 (29 Sep 2026)
  did not change it ([Apple release notes](https://support.apple.com/102825), [fcp.cafe](https://fcp.cafe/releasenotes)).
  1.13 came with Final Cut Pro 11.0, 1.12 with 10.8, 1.10 (with the `.fcpxmld` bundle) with 10.6.
- Apple's public DTD page still shows 1.10 ([Apple DTD](https://developer.apple.com/documentation/professional-video-applications/document-type-definition));
  the 1.14 DTD is inside Final Cut Pro (section 0). The story elements Prakriti needs are unchanged
  from 1.10 to 1.14.
- Time values are rational seconds; they should be multiples of the frame duration or Final Cut Pro
  "inserts a gap ... A warning message appears" ([Timing Attributes](https://developer.apple.com/documentation/professional-video-applications/timing-attributes)).
  An anchored item's `offset` is in its parent's time ("base element's time for an anchor"), same page.
- Caption roles must be written `roleName?captionFormat=ITT.en` (or `CEA608`); the role name cannot
  contain "." or "?" ([Roles Attribute](https://developer.apple.com/documentation/professional-video-applications/roles-attribute)).
- Keyframes: `adjust-transform` with `param name="scale"` or `"position"` holding a
  `keyframeAnimation`; position is in percent of the frame height
  ([Animation](https://developer.apple.com/documentation/professional-video-applications/animation)).

### 5.2 What DaVinci Resolve takes from FCPXML

From the DaVinci Resolve 20 Reference Manual installed with Resolve 20.2.1 (July 2025), chapter 55
"Preparing Timelines for Import and Comparison" and chapter 58 "Conforming XML Files":

| Element | Resolve 20, from "FCP X XML" | Manual's words |
|---|---|---|
| Cuts, multiple tracks, linked audio | Yes | Effects table |
| Video transitions | Yes; Cross Dissolve and nine wipes and irises map by name | "supports the import of ten different transitions when importing XML project files from Final Cut Pro X" |
| **Audio transitions** | **No** | Effects table: "Audio Transitions ... No" |
| Audio fade handles | Yes | "When you import a Final Cut Pro X project, the fade handles for each clip automatically import as well." |
| Position, scale, rotation, opacity, **keyframed** | Yes, with the "Use sizing information" option | "If these settings have been keyframed, the animation will appear in DaVinci Resolve." |
| Ken Burns | Becomes Dynamic Zoom | "About 'Ken Burns Effect' and Dynamic Zoom" |
| **Titles** | **As plain "Basic" text generators; some formatting; no Motion animation** | "All imported text effects appear in the DaVinci Resolve Timeline as Basic text generators. Some, but not all, formatting parameters are imported" |
| Compound clips, sync clips, multicam | As compound clips | "About Nested Sequences and Compound Clips" |
| Colour board | A subset, as primary grades | "Use color information: For Final Cut Pro X XML files only" |
| Alpha channels | ProRes 4444, DNxHR 444, Animation, TIFF, EXR | "About Supported Alpha Channels" |
| **Captions (`caption` elements)** | **[unverified]**: the manual's subtitle import lists .srt, .srtx, .vtt, .xml and .ttml files, not FCPXML caption lanes | Chapter 52 |
| Markers, chapter markers | **[unverified]** | not stated |
| FCPXML version accepted by 20.2.1 | **[unverified]**: 1.10 works from Resolve 18 on ([vendor note](https://toolsonair.atlassian.net/wiki/spaces/TST/pages/3497623553/JIM+DaVinci+Resolve+v.5.5)); FCP 12 FCPXML import/export arrived in 21.0 beta 4 ([Motion Media](https://www.motionmedia.com/mm-blog/davinci-resolve-21-beta-4-fcpxml-ai-updates)). Resolve 21.1 is current (Sep 2026, [RedShark](https://www.redsharknews.com/davinci-resolve-21.1-new-features-release)) | |

Resolve also has a built-in way to check an imported timeline against a reference movie ("Verifying
Imported Timelines Using Offline References", chapter 55). Prakriti's own MP4 is that reference.

### 5.3 The export set

One folder per finished version, beside the MP4 (names are what Ivan sees; no em dashes):

```
Sun 13 Sep, Version 3/
  Sun 13 Sep.mp4                        the finished video, ready to post
  Sun 13 Sep.srt                        captions for YouTube (and for Resolve)
  Description.txt                       title, description, chapters, ready to paste
  Thumbnail A.jpg, B.jpg, C.jpg         (SCOPE PKG-06)
  Edit for Final Cut Pro.fcpxml         FCPXML 1.14
  Edit for DaVinci Resolve.fcpxml       the same edit, FCPXML 1.10
  Graphics/                             titles, lower thirds, key phrases, term cards and date
                                        labels as ProRes 4444 clips with transparency
  Media/                                what both timelines point at (5.5)
  Read Me.txt                           five lines: how to open each, what is switched off
```

`Media/` holds an APFS clone of each source (`cp -c`: no extra disk until something changes) when
nobody is blurred or removed, or the cleaned copy when someone is. Pointing at the copy in
`~/Prakriti/Outputs` also avoids iCloud evicting the original from the shared Studio Recordings folder
and leaving the timeline offline.

### 5.4 Element by element: what each app will show

| In the plan | Written as | Final Cut Pro 12.4 | Resolve 20.2.1 | If it does not survive |
|---|---|---|---|---|
| Kept spans (cuts) | `asset-clip` in the `spine`, frame-aligned | Exact | Exact | n/a |
| Audio crossfade at a cut | 1-frame `fadeIn` / `fadeOut` on `adjust-volume` (not an audio transition) | Fade handles | Fade handles import | MP4 is sample-accurate; timeline is frame-accurate (cuts within 1 frame) |
| Punch-in (static scale) | `adjust-transform scale="1.12 1.12" position="x y"` | Exact **[round-trip test]** | Imports with "Use sizing information" | Re-apply by hand; Read Me says how |
| Push-in (animated) | `keyframeAnimation` on `scale`, `interp="ease"` | **Gated** (vault lesson) | Manual says keyframes import | Off until 5.8's test passes; a marker says "push-in here" instead |
| Cross dissolve at a merge | `transition` with the Cross Dissolve FxPlug, 12 frames, centred on the cut | **Gated** | Imports (video) | Off until 5.8's test passes; marker instead |
| Titles, lower thirds, key phrases, term cards, date labels | The rendered clip from `Graphics/` on a lane above (enabled) **and** an editable `title` on a lane above that, `enabled="0"` | Identical look; editable copy one click away | Identical look; editable copy is a plain text generator | n/a: the rendered clip is the safety net |
| Captions | `caption` elements, role `Captions?captionFormat=ITT.en` | Native captions, exportable | **[unverified]** | Import `Sun 13 Sep.srt` as a subtitle track (File, Import, Subtitle) |
| Burned captions (shorts, Energetic) | Rendered clips, like titles | Identical | Identical | n/a |
| Chapters | `chapter-marker` | Native chapters (they export into the MP4) | **[unverified]** | `Description.txt` has them |
| "Check" moments | `marker` with `completed="0"` (a to-do) | To-do markers | Markers **[unverified]** | Listed in Read Me |
| Face blur | Baked into `Media/` | Blurred | Blurred | n/a: never left to the editor |
| Removed person's speech | Not in `Media/` at all | Absent | Absent | n/a |
| Colour enhance | Baked into `Media/` only when cleaning is needed; otherwise not written | Not shown | Not shown | Small; Read Me says so **[proposal]** |

### 5.5 The privacy trap, and the cleaned media

An NLE timeline is a list of pointers into whole source files. Every removed second is still in the
file, one drag of a clip edge away, and a blur that lives only in Prakriti's renderer does not exist
in Final Cut Pro or Resolve. So when a recording's People decisions include any Blur or Remove:

- Prakriti writes a **cleaned copy** of each source into `Media/`: faces blurred per frame from the
  face tracks (the same compositor code as the MP4), removed people's speech replaced by room tone and
  their on-camera spans replaced by a held frame or black **[the people track decides which]**.
- Both timelines point at the cleaned copy. The raw file is never referenced.
- Codec: HEVC 10-bit at about 50 Mbps for 1080p (about 22 GB an hour), or ProRes 422 Proxy (about
  45 Mbps at 1080p30) if editing speed matters **[sizes are rule-of-thumb; measure]**.
- When nobody is blurred or removed (Gabriel and Serenity only), `Media/` is a zero-cost APFS clone.

This adds work the REQUEST did not list, and it is not optional: without it, the editable timeline
quietly undoes the student-privacy promise.

### 5.6 A minimal valid FCPXML

Validated on this Mac against Final Cut Pro 12.4's own DTDs (1.14 as written; 1.10 with only the
version number changed). It shows: frame-aligned rational times at 29.97 fps, a wide span with 1-frame
audio fades, a rendered lower third with its editable twin switched off, a caption with a correct ITT
role, a chapter marker, a punch-in with a to-do marker, a keyframed push-in, a 12-frame cross dissolve
into a moment from another recording, and its date label. **DTD-valid is not the same as "imports
well"**: section 5.8 is the real test, and the push-in and dissolve stay switched off in shipped files
until it passes.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.14">
  <resources>
    <format id="r1" name="FFVideoFormat1080p2997" frameDuration="1001/30000s" width="1920" height="1080" colorSpace="1-1-1 (Rec. 709)"/>
    <asset id="r2" name="2026-09-13 18-25-44" start="0s" duration="28433405/30000s" hasVideo="1" format="r1" hasAudio="1" audioSources="1" audioChannels="2" audioRate="48000">
      <media-rep kind="original-media" src="file:///Users/ivanlizarde/Prakriti/Outputs/2026-09-13%2018-25-44/Edit/Media/2026-09-13%2018-25-44.mp4"/>
    </asset>
    <asset id="r5" name="2026-09-06 18-06-33" start="0s" duration="100171071/30000s" hasVideo="1" format="r1" hasAudio="1" audioSources="1" audioChannels="2" audioRate="48000">
      <media-rep kind="original-media" src="file:///Users/ivanlizarde/Prakriti/Outputs/2026-09-13%2018-25-44/Edit/Media/2026-09-06%2018-06-33.mp4"/>
    </asset>
    <asset id="r7" name="Lower third, Gabriel" start="0s" duration="120120/30000s" hasVideo="1" format="r1">
      <media-rep kind="original-media" src="file:///Users/ivanlizarde/Prakriti/Outputs/2026-09-13%2018-25-44/Edit/Graphics/Lower%20third%2C%20Gabriel.mov"/>
    </asset>
    <effect id="r3" name="Basic Title" uid=".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti"/>
    <effect id="r4" name="Cross Dissolve" uid="FxPlug:4731E73A-8DAC-4113-9A30-AE85B1761265"/>
    <effect id="r6" name="Basic Lower Third" uid=".../Titles.localized/Lower Thirds.localized/Basic Lower Third.localized/Basic Lower Third.moti"/>
  </resources>
  <library>
    <event name="Prakriti">
      <project name="Sun 13 Sep, House style">
        <sequence format="r1" duration="780780/30000s" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
          <spine>
            <asset-clip ref="r2" name="Span 1, wide" offset="0s" start="300300/30000s" duration="150150/30000s" tcFormat="NDF" audioRole="dialogue">
              <adjust-volume>
                <param name="amount">
                  <fadeIn type="easeIn" duration="1001/30000s"/>
                  <fadeOut type="easeOut" duration="1001/30000s"/>
                </param>
              </adjust-volume>
              <asset-clip ref="r7" lane="1" name="Lower third, Gabriel (picture)" offset="315315/30000s" start="0s" duration="120120/30000s" videoRole="titles"/>
              <title ref="r6" lane="2" name="Lower third, Gabriel (editable)" offset="315315/30000s" start="0s" duration="120120/30000s" enabled="0">
                <text>
                  <text-style ref="ts1">Gabriel Galindo</text-style>
                </text>
                <text-style-def id="ts1">
                  <text-style font="Inter" fontSize="54" fontFace="Semi Bold" fontColor="1 1 1 1" alignment="left"/>
                </text-style-def>
              </title>
              <caption lane="3" name="Welcome, everyone." offset="300300/30000s" start="0s" duration="60060/30000s" role="Captions?captionFormat=ITT.en">
                <text placement="bottom">
                  <text-style ref="ts2">Welcome, everyone.</text-style>
                </text>
                <text-style-def id="ts2">
                  <text-style font=".AppleSystemUIFont" fontSize="13" fontFace="Regular" fontColor="1 1 1 1" backgroundColor="0 0 0 1"/>
                </text-style-def>
              </caption>
              <chapter-marker start="300300/30000s" duration="1001/30000s" value="Welcome" posterOffset="0s"/>
            </asset-clip>
            <asset-clip ref="r2" name="Span 2, punch in" offset="150150/30000s" start="600600/30000s" duration="210210/30000s" tcFormat="NDF" audioRole="dialogue">
              <adjust-transform scale="1.12 1.12" position="0 -2.5"/>
              <marker start="600600/30000s" duration="1001/30000s" value="Check: a possible retake was removed just before this" completed="0"/>
            </asset-clip>
            <asset-clip ref="r2" name="Span 3, slow push in" offset="360360/30000s" start="900900/30000s" duration="240240/30000s" tcFormat="NDF" audioRole="dialogue">
              <adjust-transform>
                <param name="scale">
                  <keyframeAnimation>
                    <keyframe time="900900/30000s" value="1 1" interp="ease"/>
                    <keyframe time="1021020/30000s" value="1.05 1.05" interp="ease"/>
                  </keyframeAnimation>
                </param>
              </adjust-transform>
            </asset-clip>
            <transition name="Cross Dissolve" offset="594594/30000s" duration="12012/30000s">
              <filter-video ref="r4" name="Cross Dissolve"/>
            </transition>
            <asset-clip ref="r5" name="Insert from Sun 6 Sep" offset="600600/30000s" start="45045000/30000s" duration="180180/30000s" tcFormat="NDF" audioRole="dialogue">
              <title ref="r3" lane="1" name="Date label, 6 Sep 2026" offset="45045000/30000s" start="0s" duration="90090/30000s">
                <text>
                  <text-style ref="ts3">6 Sep 2026</text-style>
                </text>
                <text-style-def id="ts3">
                  <text-style font="Inter" fontSize="36" fontFace="Medium" fontColor="1 1 1 0.85" alignment="left"/>
                </text-style-def>
              </title>
            </asset-clip>
          </spine>
        </sequence>
      </project>
    </event>
  </library>
</fcpxml>
```

Frame arithmetic for checking it: one frame is `1001/30000s`. Spans are 150, 210, 240 and 180 frames
(780 in all, the sequence duration). The dissolve is 12 frames centred on frame 600, so its offset is
frame 594 and it borrows 6 frames of media past each side of the cut. Anchored items' offsets are in
the parent clip's source time (the lower third starts at the clip's `start` plus 15 frames).

### 5.7 Rules for writing FCPXML (each with its reason)

1. **Every time is a whole number of frames,** written `N*1001/30000s` for 29.97 (`N*100/3000s` for 30,
   `N*1001/24000s` for 23.976). Reason: otherwise Final Cut Pro inserts gaps with a warning.
2. **One `asset` per source file, `start="0s"`** (the recordings have no timecode track), duration
   in whole frames, `media-rep src` an absolute `file://` URL with spaces and commas percent-encoded.
   Reason: the vault's working shape (version 1.9 slideshows) and Apple's sample both use it.
3. **Anchored items and keyframes use the parent clip's own time** (its `start` plus the moment).
   Reason: Apple's timing page; getting this wrong puts titles at the wrong place silently.
4. **Transitions need media on both sides.** Half the transition's length must exist in the source
   before the incoming span and after the outgoing one. Reason: without handles Final Cut Pro shortens
   or refuses the transition.
5. **Captions in a role must not overlap** and must sit within their parent clip's range
   **[from experience; confirm in 5.8]**.
6. **No in-XML compositing beyond placing clips and static transforms** until 5.8 passes. Reason: the
   vault's 2026-07-30 lesson ("In-XML compositing and animation silently fail on import. Deliver clean
   cuts that always open").
7. **Write both versions from one generator;** only the `version` attribute differs. Reason: the
   elements used are identical in 1.10 and 1.14 (section 0), so one code path serves both apps.
8. **Plain `.fcpxml` files, not `.fcpxmld` bundles.** Reason: Final Cut Pro opens both (design-spec,
   measured); Resolve's support for the bundle is **[unverified]**.

### 5.8 How to verify (render it and look, not read it)

1. **Unit test, every build:** generate the FCPXML for fixtures and run
   `xmllint --noout --dtdvalid <copy of FCPXMLv1_14.dtd> file.fcpxml` (and 1.10). Copy the DTD out of
   the app first: `xmllint` failed to read it from the path inside the app bundle (spaces). Skip the
   test, with a message, if Final Cut Pro is not installed.
2. **Semantic lint in Swift:** frame alignment, no spine overlaps, durations sum to the sequence,
   every `ref` resolves, every `src` file exists, transitions have handles, captions do not overlap.
3. **Round trip in Final Cut Pro, once per generator change, in a scratch library** (never Ivan's real
   library): File, Import, XML; then export XML again and compare clip counts, offsets, scales and
   marker counts; then share 5 frames at known times and compare them with the same frames of
   Prakriti's MP4. Pass means same frames (within a small difference for scaling filters).
4. **Round trip in Resolve 20.2.1:** File, Import Timeline, with "Use sizing information" on; then use
   Resolve's offline reference comparison against Prakriti's MP4 (chapter 55). Check: cuts, punch-ins,
   transitions, fades, which titles came through, whether captions and markers came through.
5. **Gate:** push-ins and dissolves are written into shipped timelines only after steps 3 and 4 pass
   for them; until then each becomes a marker ("Push-in here", "Dissolve here").
6. Record the result in `docs/BUILD-LOG.md` with the frames, as v1 did for every milestone.

### 5.9 Alternatives considered

| Format | What it carries | Why not the primary |
|---|---|---|
| **OpenTimelineIO** (`.otio`, `.otioz`) | Cuts, transitions, markers; Resolve imports it (manual chapter 61) | No standard for transforms or titles, so zooms and text would be lost; Final Cut Pro does not read it natively. Revisit if a third NLE matters |
| **CMX3600 EDL + SRT** | One video track of cuts and dissolves, plus captions | No transforms, no titles, frame and timecode pitfalls. Offer only if someone asks for "an EDL" |
| **Final Cut Pro 7 XML (xmeml)** | What Premiere reads | Not needed for FCP or Resolve |
| **Resolve scripting** to build a native timeline | Everything Resolve can do | Resolve 21.1 moved "advanced scripting" to Studio ([RedShark](https://www.redsharknews.com/davinci-resolve-21.1-new-features-release)); depends on the paid app and on Resolve running |
| **A custom Motion title template** installed into `~/Movies/Motion Templates.localized` | Editable animated titles in Final Cut Pro | Resolve would flatten it; worth it later for the Final Cut Pro file only |

---

## 6. "100% ready": the distribution specs

### 6.1 YouTube long-form

| Item | Spec | Source |
|---|---|---|
| Container | MP4, no edit lists, index at the front ("Fast Start") | [YouTube upload settings](https://support.google.com/youtube/answer/1722171?hl=en) |
| Video | H.264, progressive, High profile, 2 consecutive B-frames, closed GOP of half the frame rate, CABAC, variable bitrate, 4:2:0, BT.709, same frame rate as recorded | same |
| Bitrate (SDR, 24 to 30 fps) | 1080p: 8 Mbps; 4K: 35 to 45 Mbps (at 48 to 60 fps: 12 and 53 to 68). "No bitrate limit is required" | same |
| Prakriti's choice | 1080p29.97 at 16 Mbps (4K at 45 to 60) | headroom for YouTube's re-encode |
| Audio | AAC-LC (or Opus), 48 kHz; stereo 384 kbps, mono 128 kbps | same |
| Loudness | -14 LUFS integrated, true peak -1 dBTP or lower. YouTube publishes no target; third-party measurement shows it turns louder uploads down to about -14 and does not raise quieter ones | [Production Advice](https://productionadvice.co.uk/stats-for-nerds/), [Youlean](https://youlean.co/?p=30813) **[not an official spec]** |
| Captions | `.srt` in plain UTF-8, basic only (no styling); `.vtt` also accepted | [YouTube caption formats](https://support.google.com/youtube/answer/2734698?hl=en) |
| Chapters in the description | First at 00:00, at least three, ascending, each at least 10 s; manual chapters override automatic ones | [YouTube chapters](https://support.google.com/youtube/answer/9884579?hl=en) |
| Thumbnail | Recommended 3840 x 2160 (16:9), minimum width 640; JPG or PNG; 2 MB limit on mobile, 50 MB on desktop. SCOPE PKG-06 keeps 1280 x 720 JPEG under 2 MB plus a 4K master: valid on both | [YouTube thumbnails](https://support.google.com/youtube/answer/72431?hl=en) |
| End screen | Last 5 to 20 s, video at least 25 s, up to 4 elements; not for made-for-kids | [YouTube end screens](https://support.google.com/youtube/answer/6388789?hl=en) |

**On "no edit lists":** AAC encoders add a priming delay that MP4 writers usually describe with an
edit list on the *audio* track. YouTube's warning is about edit lists that cut video. The check: no
`elst` box on the video track; an audio priming entry is reported but allowed **[YouTube's tolerance
unverified; test with one private upload in the YouTube API test week, SCOPE SET-13]**.

### 6.2 Shorts, Reels, TikTok

| | YouTube Shorts | Instagram Reels | TikTok |
|---|---|---|---|
| Frame | 9:16 (or square), 1080 x 1920 | 1080 x 1920 | 1080 x 1920 |
| Length | Up to 3 minutes; vertical or square up to 3 minutes is classed as a Short (uploads after 15 Oct 2024) ([YouTube](https://support.google.com/youtube/answer/15424877?hl=en)) | Sources conflict: 3 minutes is the common figure, longer uploads reported **[unverified; Meta's page not readable]** | 10 minutes for most accounts, 60 on some **[third-party only]** |
| Copyright | Any Short over 1 minute with an active claim is blocked | n/a | n/a |
| Codec | H.264 + AAC, 30 fps (same as long-form encoder at 1080 x 1920, about 10 Mbps) | same | same, at least 2 Mbps |
| Thumbnail | 2160 x 3840 recommended; set only in Studio (SCOPE PKG-08) | in-app | in-app |

SCOPE PKG-08's 15 to 60 s length fits all three. Captions are burned in for all three (PIP-24).

### 6.3 Safe areas for burned text (1080 x 1920)

Platforms publish no binding numbers; third-party guides differ by up to about 30 px
([PostPlanify](https://postplanify.com/blog/social-media-safe-zones-2026-complete-guide),
[VidPros](https://vidpros.com/vertical-video-safe-zone/)). Prakriti uses the strictest union:

- Keep clear: top 250 px, bottom 350 px, right 120 px (TikTok's buttons), left 60 px.
- So text lives in x 60 to 960, y 250 to 1570; captions sit with their baseline at about y 1250 to
  1400, centred on x 510 (the safe area's centre, a little left of the frame's).
- Faces: keep the eyes between y 500 and 800 so captions never cross them.
- The check is computed from the layout (every text box inside the safe rectangle), then a frame is
  rendered with the safe area drawn on it and looked at once per style change.

### 6.4 The automatic "ready" checklist (extends v1's podcast checklist)

Each line measured from the file, never trusted from the settings: container and codec (`ffprobe`);
size, frame rate and profile; bitrate within 10% of target; BT.709 tags; index at the front; no video
edit list; loudness -14 ±1 LUFS and true peak ≤ -1 dBTP (`ebur128`); **the last 5 s decode cleanly**
(Sonny's rule: verify media by decoding its tail); captions parse, at most 42 characters a line, two
lines, 20 cps; chapters follow YouTube's rules; thumbnail size and weight; for shorts, every text box
inside the safe area and length under 3 minutes; and for every output, People decisions applied (no
Remove person's words in the re-transcript, which v1's re-transcription already makes possible).

---

## 7. What the capture tips must say, for this engine to shine

For the startup screen and help/02 (another track writes them; these are the facts the engine relies
on, written so they can be lifted as they are, with no em dashes):

- **Record in 4K, even if you post in 1080p.** Zooms up to twice as close stay sharp, and vertical
  clips cut from the wide picture stay sharp. Today's recordings are 1080p, which limits zooms to
  about 15%.
- **Record at high quality.** 6 Mbps (today's setting) is fine for watching, not for zooming in. In
  OBS, choose a high-quality recording preset or a quality-based setting **[help/03 owns the exact
  OBS values]**.
- **Keep the vertical recording on** for talks (SCOPE SET-05), so shorts have their own picture.
- **A second camera, if you can.** A wider or side angle makes cuts feel like a real production.
- **One microphone per speaker, on its own track.**
- **Leave room around the head.** Eyes on the upper third, some space on the side the speaker is not
  facing (that is where text goes).
- **Hold still and quiet for five seconds after you press record.** Prakriti uses that silence to
  learn the room.
- **If you stumble, pause, say "take two", and start the sentence again.** Prakriti keeps the last
  complete take.
- **Keep the light and white balance fixed** (no auto exposure), so recordings from different days
  match when moments are combined.
- **Constant frame rate**, the same every time (29.97 today).

---

## 8. Open questions and the verification plan

| # | Question | How to settle it | Blocks |
|---|---|---|---|
| E1 | Does Resolve 20.2.1 import FCPXML 1.10 captions, chapter markers and to-do markers? | 5.8 step 4 with the 5.6 example | Read Me wording only (SRT covers captions) |
| E2 | Do static punch-ins, keyframed push-ins and dissolves from our FCPXML import correctly in FCP 12.4 and Resolve? | 5.8 steps 3 and 4 | Turning on push-ins and dissolves in timelines |
| E3 | Does Parakeet write every "um" and "uh"? | Hand-count 3 minutes of the 6 Sep talk against `transcript.json` | Filler recall target (1.8) |
| E4 | Are the pause numbers right by ear? | Ivan's three-window listening test per preset | Preset defaults |
| E5 | Final typeface and IAST rendering | Render the test string in the candidate, look | Any text on screen |
| E6 | Is the vertical twin in sync with the main recording? | Cross-correlate the two audio tracks on one session | Using the twin for B-roll stand-ins |
| E7 | Render speed with the custom compositor | Time the 13 Sep talk, 1080p | Progress estimates |
| E8 | Does YouTube accept the AAC priming edit list without complaint? | One private test upload (SET-13 week) | The "no edit lists" check's strictness |
| E9 | One preset vocabulary across design-spec and help | Decide with the design track (2.5) | UI strings |
| E10 | The SF Pro licence for burned-in video text | Read the macOS licence's font clause, or avoid the question with an OFL font (recommended) | Typeface choice |

---

## Sources

Apple
- Final Cut Pro release notes: https://support.apple.com/102825
- FCPXML Reference: https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference.md
- Creating FCPXML Documents: https://developer.apple.com/documentation/professional-video-applications/creating-fcpxml-documents.md
- Document Type Definition (1.10 on the web): https://developer.apple.com/documentation/professional-video-applications/document-type-definition.md
- Story Elements: https://developer.apple.com/documentation/professional-video-applications/story-elements.md
- Timing Attributes: https://developer.apple.com/documentation/professional-video-applications/timing-attributes.md
- Roles Attribute: https://developer.apple.com/documentation/professional-video-applications/roles-attribute.md
- Animation: https://developer.apple.com/documentation/professional-video-applications/animation.md
- caption: https://developer.apple.com/documentation/professional-video-applications/caption.md
- AVVideoCompositionCoreAnimationTool: https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool.md
- Core Animation tool freeze report: https://developer.apple.com/forums/thread/726146
- MacBook Pro (M5 Pro) specs: https://apple.com/macbook-pro/specs
- On this Mac: MacOSX27.0.sdk AVFoundation headers and Swift interface; Final Cut Pro Creator Studio 12.4 bundle (FCPXML DTDs 1.0 to 1.14, templates, `TransitionOrder.plist`)

Blackmagic Design
- DaVinci Resolve 20 Reference Manual (July 2025), installed at `/Applications/DaVinci Resolve/DaVinci Resolve Manual.pdf`: chapters 52, 55, 58, 61
- Resolve 21 beta 4, FCP 12 FCPXML: https://www.motionmedia.com/mm-blog/davinci-resolve-21-beta-4-fcpxml-ai-updates
- Resolve 21.1: https://www.redsharknews.com/davinci-resolve-21.1-new-features-release
- Resolve 21.0 release: https://petapixel.com/2026/06/03/davinci-resolve-21-officially-released-with-new-photo-editing-ai-tools/
- FCPXML 1.10 needs Resolve 18+: https://toolsonair.atlassian.net/wiki/spaces/TST/pages/3497623553/JIM+DaVinci+Resolve+v.5.5
- fcp.cafe release notes: https://fcp.cafe/releasenotes

YouTube and platforms
- Upload encoding settings: https://support.google.com/youtube/answer/1722171?hl=en
- Chapters: https://support.google.com/youtube/answer/9884579?hl=en
- Thumbnails: https://support.google.com/youtube/answer/72431?hl=en
- Three-minute Shorts: https://support.google.com/youtube/answer/15424877?hl=en
- End screens: https://support.google.com/youtube/answer/6388789?hl=en
- Caption file formats: https://support.google.com/youtube/answer/2734698?hl=en
- Loudness, third-party: https://productionadvice.co.uk/stats-for-nerds/ and https://youlean.co/?p=30813
- Safe zones, third-party: https://postplanify.com/blog/social-media-safe-zones-2026-complete-guide and https://vidpros.com/vertical-video-safe-zone/
- Reels specs, third-party: https://www.socialcal.app/blog/instagram-video-length-limits-2026
- TikTok specs, third-party: https://www.heyorca.com/blog/tiktok-media-specs-best-practices-2026
- Netflix timed text: https://backlothelp.netflix.com/hc/en-us/articles/215758617 and https://backlothelp.netflix.com/hc/en-us/articles/219375728

Editing tools and research
- Descript filler words: https://help.descript.com/script-editing/filler-words.md
- Descript shorten word gaps: https://help.descript.com/script-editing/shorten-word-gaps.md
- Gling: https://gling.ai/silence-remover and https://www.unite.ai/gling-ai-review
- TimeBolt silence detection: https://timebolt.notion.site/Silence-Detection-67e267311a104d7dbb391073c5960d8e
- FireCut: https://firecut.ai/blog/how-firecut-streamlines-your-premiere-pro-timeline/
- AutoCut: https://autocut.com/help-center/autocut-overview/autocut-features, https://www.autocut.com/en/autocutangles/ and https://www.cined.com/jp/autocut-plugin-now-integrates-ai-directly-into-premiere-pro-to-automatically-handle-time-consuming-tasks/
- Recut comparison: https://blitzcutai.com/blog/best-mac-video-editor-silence-removal-2026
- Silence settings guide: https://cutsio.com/blog/final-cut-pro-remove-silence-best-settings-for-natural-cuts
- PodcastFillers (Adobe, Interspeech 2022): https://arxiv.org/abs/2203.15135
- CrisperWhisper: https://arxiv.org/abs/2408.16589
- ffmpeg zoompan jitter: https://ffmpeg.org/pipermail/ffmpeg-trac/2025-March/072904.html

MKBHD
- Measured editing study: https://www.writepanda.ai/blog/mkbhd-editing-style-measured/
- Team cuts in Final Cut Pro: https://fcp.cafe/news/20241014 (video: https://www.youtube.com/watch?v=3dQ6yKSttEc&t=1095s)
- MotionVFX pack: https://www.mac4ever.com/mac/170509-mkbhd-a-cree-un-plug-in-final-cut-pro-premiere-resolve-avec-tous-ses-effets-video-en-promo
- Team and channel: https://www.tubefilter.com/2021/07/27/marques-brownlee-second-channel-the-studio/
- Editing principles, qualitative: https://www.devx.com/daily-news/four-editing-principles-that-transformed-my-creative-process/

Prakriti and the vault
- `docs/v2/REQUEST.md`, `docs/v2/design-spec.md`, `docs/v2/help/08-editorial-direction.md`, `docs/SCOPE.md` (PKG-06, PKG-07, PKG-08, PIP-22 to PIP-24, SET-05, SET-13), `docs/LOCAL-MODEL.md`, `docs/BUILD-LOG.md`, `research/02-apple-platform.md`
- `mac/Prakriti/Engine/EpisodeEdits.swift` (Parakeet order repair, 15 ms fades), `Engine/Pipeline.swift`
- Vault: `60 Reference/Photo-to-Video Slideshow Method.md` (the FCPXML import lesson), `60 Reference/Pulling stills from a Final Cut timeline at exact timecodes.md`
