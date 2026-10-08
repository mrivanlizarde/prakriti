# 09 · Features nobody has thought of yet

Research track 09 for Prakriti. Written 2026-10-08 by a Sonny research agent. Read-only research;
this file is the only thing written.

**What this file is.** A long list (69 ideas, plus a "never" list) of features and behaviours that
were not discussed on the 2026-09-24 or 2026-10-07 calls, each sized and phased, then ranked. The
ten that should change the scope are marked **[TOP 10]** and argued in section 3.

**How it was grounded.** Read `BRIEF.md`, `2026-10-07-call-gabriel-transcript.txt`, the vault notes
`20 Projects/Yoga Marga.md`, `20 Projects/Gabriel Galindo — Content Engine.md`,
`20 Projects/Call Debriefs/2026-09-24 — Gabriel Galindo and Serenity.md`,
`10 People/Serenity Todesco.md`, `10 People/Gabriel Galindo.md`,
`30 Ventures/Gabriel Galindo — Closer.md` (skimmed), the 10-07 roadmap page
(`Gabriel Galindo/Roadmap/galindo-lizarde-roadmap.html`), the old `content-engine/PLAN.md`, the
coaching material (`The Work Book/The Work Book — Web App Concept.md`,
`The Coaching Studio/coaching-studio-v1-spec-foundation.md`, memory file
`complaint-is-a-latent-vision.md`). Then **probed the actual studio folder** with `ffprobe` and
`grep` (read-only) so the ideas answer what is really in it, not what the calls assumed. External
claims were checked on the web on 2026-10-08 and cited inline.

**Legend.**
- Effort: **S** = about 1 to 2 days of build; **M** = about 3 to 10 days; **L** = more than two
  weeks. These are Sonny estimates for the Cloudflare + local-helper stack, not quotes.
- Phase: **now** = belongs in the first version; **soon** = the first month after first publish;
  **later** = after the archive lane is running and Serenity's answers are in; **never** = argued
  against.
- `[unverified]` = could not confirm from a primary source. `[inferred]` = Sonny's reading of
  evidence, not stated by anyone. `[estimate]` = arithmetic on measured numbers.
- Student names heard in the recordings are deliberately **not** reproduced anywhere in this file.

---

## 1. What the raw material actually looks like (measured today)

These facts came from probing `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /`
on 2026-10-08. Several of the ideas below exist only because of them.

| Finding | Evidence | Why it matters |
|---|---|---|
| **12 `.mp4` files are 6 real sessions.** Two sessions were recorded twice, as a horizontal file and a `-vertical.mp4` twin (1080x1920). Four files are tests: 153 s, 11.5 s, 8.6 s, 10.4 s. | `ffprobe` on every file; e.g. `2026-09-06/2026-09-06 18-06-33-vertical.mp4` is 3339 s at 1080x1920, its twin `2026-09-06 18-06-33.mp4` is 3339 s at 1920x1080 | A watcher that treats each file as a recording will notify, transcribe and package the same class twice, and announce four tests as "new raw material". |
| **Real material in four weeks: about 5.4 hours** (19,564 s across 09-06, 09-13, 09-14, 09-16, 09-20, 09-23). | Sum of `ffprobe` durations `[estimate]` | Sets the steady-state load: roughly 1.5 hours a week of new studio content. |
| **Storage: about 17.9 GB for September**, about 2.8 GB per hour of horizontal 1080p (about 6.2 Mbps), and the vertical twin doubles it. | `stat` sizes summed: 17,922 MB `[estimate]` | At this pace, roughly 200 to 500 GB a year in Ivan's iCloud shared folder `[estimate]`. Storage lifecycle is a real feature, not housekeeping. |
| **The vertical canvas already exists.** OBS is recording a native 9:16 output alongside 16:9 (the `-vertical` naming suggests a vertical-canvas plugin `[inferred]`). | `2026-09-06/*-vertical.mp4` files | Shorts do not need AI auto-reframing for studio sessions that have a vertical twin. |
| **One stereo audio track per file.** Every recording has exactly one audio stream (48 kHz, 2 ch). | `ffprobe -select_streams a` on all 12 files | Every voice in the room and on Zoom is mixed together, so "keep only Serenity's voice" depends entirely on a model. |
| **Existing transcripts put the whole class under one speaker.** The yin classes on 09-16 and 09-23 show only `Speaker 1` (09-23 shows a brief `Speaker 2`), even though online students are heard. | `grep '^Speaker'` on `2026-09-16 20-03-49.txt`, `2026-09-23 19-59-52.txt` | Diarization on this audio is not reliable enough to be the privacy guarantee on its own. |
| **The teacher says students' first names aloud** in the opening greetings of both yin classes. | Opening lines of `2026-09-16 20-03-49.txt` and `2026-09-23 19-59-52.txt` (names not reproduced here) | Removing every non-teacher voice still publishes students' names. Serenity's privacy condition is not met by voice isolation alone. |
| **Students attend online, through Zoom.** "Those of you watching online"; "I'm not getting your audio". | `2026-09-23 19-59-52.txt`, `2026-09-16 20-03-49.txt` | Their voices most likely enter OBS as computer audio, a separate source from the room mic `[inferred]`, which means they can be put on their own track (idea A7). |
| **Studio classes are taught without music, by stated policy.** "We'll always teach these classes without music." | `2026-09-23 19-59-52.txt` | Copyright music risk is mainly an archive problem, not a studio one. |
| **Sessions open with mic checks.** "Okay, audio test", "check, check". | `2026-09-16 20-03-49.txt`, `2026-09-06 17-43-25.txt`, `2026-09-17 06-02-43.txt` | Auto-trim of the warm-up is needed on real sessions too. |
| **One 62-minute session has no transcript.** `2026-09-14 20-00-09.mp4` (Monday) has no `.txt` beside it. | Directory listing | The pipeline already has a silent gap. Nothing told anyone. |
| **The studio is used for non-Yoga-Marga work.** Two short "press one button" tests name third-party products or people. | `2026-09-26 10-29-54.txt`, `2026-10-02 15-10-06.txt` | The watcher needs to know what is Yoga Marga and what is not before it notifies or publishes. |
| **The brand name is mis-transcribed at least six ways.** "yoga market" (8x), "Yoga Margot", "Yokamarga", "Yogamarga", "Yoga Marka", "yoga marker"; also "Pradayama" (pranayama) and "Sampia" (Samkhya). | `grep` across the studio `.txt` files and the 10-07 transcript | Every downstream output (search, captions, show notes, knowledge base) inherits these errors unless vocabulary is fixed at the transcription step. |
| **Talks contain spoken promises.** "Somewhere below this video, you're going to see the option to enroll in a free week." | `2026-09-13 18-25-44.txt` | If the description lacks that link, the published piece breaks a promise the speaker made on camera. |
| **New Yoga Marga enrollment was paused in January 2026.** "I decided to consciously stop enrolling new students for Yoga Marga." | `2026-09-13 18-25-44.txt` | Archive recordings will advertise offers, prices and cohorts that no longer exist. The current call to action is not obviously "join the YTT". |
| **Talks contain earnings claims.** "how we were able to generate up to $32,000 in 30 days" | `2026-09-06 18-06-33.txt` | Business-coaching income claims are under FTC scrutiny (section 2, B6). |
| **Members already say there is too much content.** "there's so much content there... sometimes it can be a little [overwhelming]" | `2026-09-13 18-25-44.txt` | The archive's value to members is curation and search, not volume. |

---

## 2. The coaching frame: each complaint is a latent vision, with a number

The Work Book and The Coaching Studio both run on the same move: flip the complaint into the vision
it hides, then make it specific (`memory/complaint-is-a-latent-vision.md`;
`The Coaching Studio/coaching-studio-v1-spec-foundation.md` line 98, "the million-dollar exercise").
Applied to everyone Prakriti serves, the flips point at features nobody has asked for yet. Numbers
marked "proposed" are Sonny's, for the team to change.

| Who | The complaint, in their words | The vision underneath | The number that makes it real | Features it points at |
|---|---|---|---|---|
| **Gabriel** | *"For whatever reason, we're incapable of hitting post and share."* (10-07 transcript) | Yoga Marga has a visible public body of work. | Already proposed: 25 archive pieces by Fri 6 Nov 2026; 72 h studio-to-live (roadmap page). Add: **human time per piece under 2 minutes** (proposed). | E1, E2, E9, G10 |
| **Gabriel** | *"If I look up Serenity or Gab or if I look up Yoga Marga, I don't get a full sense of... who these people are."* (10-07 transcript) | A stranger who searches them finds them, and understands them. | Proposed: by 31 Dec 2026, a YouTube and Apple Podcasts search for "Yoga Marga" and for "Serenity Todesco" each returns at least 5 of their own pieces on the first screen. | E13, D1, D2, C1 |
| **Gabriel** | *"What I don't want is to create a 20 hour, 40 hour work week for myself."* (`Yoga Marga.md`) | The content runs without becoming his job. | Proposed: Gabriel's total weekly time in Prakriti under 30 minutes. | E1, E3, A3, G9 |
| **Serenity** | Student privacy: classes are interactive and she names students (`2026-09-24` debrief). | Nothing a student said leaves the room. | **Zero** student voices and **zero** student names in public output, shown on a per-piece receipt. | A7, B1, B2, B9, B10 |
| **Serenity** | *"If it's going to be published to the public, though, I want to make sure that I get the year right."* (`2026-09-24` debrief) | Everything public is something she would sign. | Proposed: every checkable claim reviewed before publish, at **under 5 minutes of her time per piece**. | B3, B4, C1, F3 |
| **Ivan** | *"At the end of this all, I'm not sure what we're aiming at."* (10-07 transcript); the vault's repeated "scope grows without a compensation conversation" | One engine with a defined finish line and a visible cost. | Proposed: run cost per published piece visible on the home screen; Prakriti scoped and priced before the second lane switches on. | G2, G1, G7, G10 |
| **Students and members** | "So much content... it can be a little [overwhelming]." (`2026-09-13 18-25-44.txt`) | They can find the one teaching they need. | Proposed: any question about a topic Serenity has taught returns her own words, with a timecode, in under 10 seconds. | D9, D10, D6 |

The coaching read on Gabriel's own draft: his 10-07 plan ("drop a video, walk away, get a zip") serves
the *production* half of his complaint. The complaint is about *publishing*. The zip is where the
current process already dies. That is why the posting habit (E1, E2, E9) ranks above most new
outputs in this file.

---

## 3. The top 10 that should change the scope

Each of these either changes the architecture, removes work, or adds something that the first
version is unsafe or pointless without. The full entries are in section 4.

### T1. Privacy by microphone, not by model (A7)
**Change:** set OBS to record multiple audio tracks: teacher's mic, co-teacher's mic, and the
Zoom/computer audio (where online students are heard) each on its own track. The public mix is built
only from the teachers' tracks. Diarization becomes the backup, not the guarantee.
**Why it changes scope:** today every file has one mixed stereo track and the existing transcripts
cannot tell students from teacher (section 1). OBS supports this in Advanced output mode, ticking
several "Audio Track" boxes and assigning each source to a track
([OBS forum guide](https://obsproject.com/forum/threads/high-quality-recording-with-multiple-audio-tracks-in-advanced-output-mode.150001/);
[GamingOnLinux walkthrough](https://www.gamingonlinux.com/2017/02/how-to-record-videos-on-linux-using-obs-studio-with-separate-audio-tracks-for-gameplay-and-microphone/page=1/)).
It also gives the voice-model lane clean single-speaker audio for free, which was a separate
deliverable on the 10-07 call. It is a studio settings change (S), not a build. It only helps
**future** recordings; the 900-video archive still needs model-based separation.
**Risk:** a user report of sources blending onto the same tracks
([OBS forum](https://obsproject.com/forum/threads/issue-with-multiple-audio-tracks-from-2-audio-sources.54106));
verify with a test recording, not by reading settings.

### T2. Serenity's privacy receipt, with a name scrubber (B1 + B2)
**Change:** every piece carries a short receipt: voices audible, names spoken, sensitive
disclosures, what was removed. She approves the receipt, not the transcript. Spoken first names in
the teacher's own speech are detected (against a roster and a name model) and cut or toned.
**Why it changes scope:** the teacher says students' names in the greetings of both studio yin
classes (section 1). The current plan (diarize, keep her voice) publishes those names. And Serenity
"is not a heavy technical user" (`10 People/Serenity Todesco.md`), so the review surface has to be
small.

### T3. Serenity's accuracy receipt, plus a stale-truth detector (B3 + B4)
**Change:** extract checkable claims (years, numbers, names, Sanskrit, citations, offers, prices) into
a 5 to 10 item checklist per piece. Archive pieces also get flagged for statements that were true when
recorded and are not now (prices, retreats, "enroll now", the YTT that paused intake in January
2026). Corrections are saved and reused.
**Why it changes scope:** the 09-24 answer to her accuracy condition was "regenerate a clean script
from the corpus" (debrief). That is right for new studio content and heavy for the archive. A
checklist lets archive pieces publish as-recorded with a short, specific review, which is what the
25-by-6-Nov target needs.

### T4. A session is the unit, not a file (A1 + A2 + A3)
**Change:** the watcher groups a horizontal file and its `-vertical` twin as one session, transcribes
once, sends the vertical file to the Shorts lane, files sub-60-second mic checks as Tests (no
notification), and routes each session to a venture: Yoga Marga School, Yogi Sales Support,
VeraSales, personal, or test.
**Why it changes scope:** 12 files are 6 real sessions (section 1). Without this, the first week of
notifications is mostly noise, which is the fastest way to teach three people to ignore them.

### T5. A Yoga Marga lexicon at the transcription step (C1)
**Change:** a maintained glossary (brand name with its diacritic, Sanskrit terms, teachers and
lineage, offer names, recurring places) fed into Whisper's `--initial_prompt` and a post-correction
pass. Local `whisper --help` confirms the `--initial_prompt` flag on this Mac, and the
`transcribe-audio` skill already passes a vocabulary prompt (`~/.claude/skills/transcribe-audio/SKILL.md`
line 48; "Half of what looks like ASR error is vocabulary", line 69).
**Why it changes scope:** the brand is spelled wrong six ways in four weeks (section 1). Search,
captions, chapters, show notes and both knowledge bases all inherit it. It is the cheapest
quality lever in the whole system.

### T6. Triage the archive before transcribing it (C2 + C3 + C4 + B11)
**Change:** do not deep-transcribe 900 recordings first. (a) Pull YouTube's existing automatic
captions for the channel's own videos (`captions.download`, 200 quota units, needs edit permission
on the video) for a fast topic and quality pass
([captions.download](https://developers.google.com/youtube/v3/docs/captions/download);
`trackKind` includes `ASR`, [captions resource](https://developers.google.com/youtube/v3/docs/captions?hl=ja)).
ASR-track download for owners is inferred from the permission rule, `[unverified]` until tested.
(b) Pull originals through Google Takeout (original upload quality) rather than Studio downloads,
which are 720p or 360p
([Make Tech Easier](https://maketecheasier.com/download-your-own-youtube-videos/);
[PhoneArena on Takeout originals](https://www.phonearena.com/news/Google-Takeout-lets-you-retrieve-your-original-YouTube-videos_id35024)).
(c) Fingerprint audio to collapse duplicates
([pyacoustid / Chromaprint](https://pypi.org/project/pyacoustid)).
(d) Scan for copyrighted music (B11). Then deep-transcribe only the shortlist.
**Why it changes scope:** the brief records that no archive transcripts exist on this Mac. The
25-by-6-Nov target depends on choosing the 25 quickly; the full archive can be transcribed after.

### T7. The posting habit: one-tap approve and a release queue (E1 + E2, with E9 named)
**Change:** approval is a single screen reached from a notification, with "approve all ready" for a
batch. Approved pieces enter a queue that releases on a fixed rhythm, and the home screen shows
**runway** (days of approved content queued). The opt-out mode (publish at a set time unless vetoed)
is written down as a later decision, because the standing rule is "nothing outward-facing without a
human yes" (`BRIEF.md`).
**Why it changes scope:** this is the only part of the system that addresses Gabriel's actual
sentence. A zip of finished outputs is where the current process already stalls.

### T8. Every piece carries the right ask, and keeps its spoken promises (E5 + E6 + E7)
**Change:** each piece gets a call to action chosen by content type (a business-of-yoga talk points to
Yogi Sales Support; a yin class to the free week or the community; Serenity's philosophy to YMCT or
coaching), with a unique tracked link per piece. A spoken-promise check finds things like "below this
video you'll see the option to enroll in a free week" and blocks publishing until the description
fulfils it. Leads created through those links are attributed back to the piece in GoHighLevel.
**Why it changes scope:** the 10-07 package has no call to action at all, Gabriel's talks already
make spoken promises (section 1), and Yoga Marga's business runs on GoHighLevel (`Yoga Marga.md`,
"Content → webinar → Skool community → one-to-one calls"). Without this, Prakriti publishes content
that cannot be connected to a single enrollment.

### T9. Autonomy you can trust (A9 + A10 + G1 + G2 + G3)
**Change:** a heartbeat from the watcher to the cloud with an alert when it goes quiet; a nightly
sweeper that finds sessions missing any artifact; a per-run evidence log; a cost meter with a monthly
cap; and a kill switch that halts every outward action at once.
**Why it changes scope:** "watch folders and work autonomously" means nobody is looking. A
dead-man's switch alerts on the absence of a ping, which catches a machine that is off, a crashed
job, or a misconfigured scheduler, none of which produce an error
([Healthchecks docs mirror](https://healthchecks.sre.cfainstitute.org/docs/)). Ivan's Mac travels
(`BRIEF.md`), and the 09-14 session already has no transcript with no alert (section 1).

### T10. Let GoHighLevel do the posting and the approving (E3)
**Change:** route multi-platform posting (YouTube videos and Shorts, Instagram, TikTok, Facebook,
LinkedIn) through GoHighLevel's Social Planner rather than building each platform integration.
Its API creates posts per platform, YouTube posts take `type` `video` or `short`, a privacy level
(`private`, `public`, `unlisted`) and a schedule date
([HighLevel API, create post](https://marketplace.gohighlevel.com/docs/2021-04-15/ghl/social-planner/create-post)).
Its post approval flow emails an approver, who can approve, reject or edit; reseller documentation
describes an external approval link that works without a login
([approval flow guide](https://mastermind.helpscoutdocs.com/article/254-post-approval-in-the-social-planner);
[external link, reseller doc](https://blog.tekmatix.com/b/post-approval-flow-in-social-planner), `[unverified]`
for their plan).
**Why it changes scope:** Yoga Marga already pays for GoHighLevel and Ivan spent August learning it
(`Yoga Marga.md`). Prakriti then builds YouTube upload directly only if GoHighLevel's YouTube posting
falls short (the API page is inconsistent on the privacy field name, so test it). Gabriel's "someone
has to post" becomes "GoHighLevel posts, after one approval".

**First runners-up** (high value, smaller scope change): D9 Ask the archive (quote, do not generate),
A6 the "that was good" marker, E13 the findability check, D12 the gap-driven recording brief, F3 the
taste log.

---

## 4. The full list

### A. Intake and the watcher

**A1. A session is the unit, not a file.** [TOP 10, T4]
- *What:* group a horizontal recording and its `-vertical` twin (same timestamp prefix) into one
  session. Transcribe once, from the horizontal file. Feed the vertical file straight to the Shorts
  lane; crop timecodes from the horizontal transcript apply to it unchanged.
- *Why for Yoga Marga:* two of the six real sessions already have twins, and the twins were
  transcribed separately with small differences (section 1). The vertical canvas also removes the
  need for AI reframing on studio Shorts, which tools like Opus Clip sell as a feature.
- *Effort / phase:* S / now.

**A2. Test and noise triage.**
- *What:* anything under about 60 seconds, or whose transcript is dominated by "audio test",
  "check, check", "one, two, three", is filed as a Test: kept, not processed, not announced.
- *Why:* four of twelve files are tests of 8.6 to 153 seconds (section 1). The macOS notification
  "new raw material detected" should mean something.
- *Effort / phase:* S / now.

**A3. Venture router.**
- *What:* classify every session as Yoga Marga School (Serenity's teaching, classes), Yogi Sales
  Support (Gabriel's business-of-yoga talks), VeraSales, personal, or test. Each venture has its own
  outputs, calls to action, channels and approver.
- *Why:* the studio is shared. The September folder holds Gabriel's retreat-sales talk
  (`2026-09-06 18-06-33.txt`), a Yoga Marga life update (`2026-09-13`), yin classes, and tests for
  third-party products (`2026-09-26`, `2026-10-02`). Gabriel told Ivan on 10-07 that VeraSales
  content is coming too. Publishing a VeraSales demo to the Yoga Marga podcast is the failure this
  prevents.
- *Effort / phase:* M / now (classification), outputs per venture later.

**A4. Recording-stop handshake.**
- *What:* learn that a recording is finished from OBS itself rather than by watching file sizes.
  obs-websocket's `RecordStateChanged` event carries `outputActive`, `outputState`, and an
  `outputPath` with the saved file name once recording has stopped
  ([Streamer.bot docs for the event](https://wiki.streamer.bot/en/Broadcasters/OBS/Events/Output-Events/RecordStateChanged)).
  Fall back to a file-stability check when OBS is not reachable. Also confirm the file is fully
  downloaded locally before reading it, since it lives in an iCloud shared folder and may be a
  cloud-only placeholder on the processing Mac `[unverified mechanism; other tracks cover the Apple
  API]`.
- *Why:* files are 2.5 to 3.3 GB written over about an hour (section 1). Processing a half-written
  or not-yet-downloaded file produces a confident, wrong package.
- *Effort / phase:* S / now.

**A5. Live recording guard.**
- *What:* in the first 60 to 90 seconds of a recording, watch input levels (obs-websocket offers
  `InputVolumeMeters` events, high-frequency and opt-in,
  [obsws-python event docs](https://tessl.io/registry/tessl/pypi-obsws-python/files/docs/event-subscriptions.md))
  and send a notification if the main mic is silent, clipping, or if only computer audio is present.
- *Why:* the 09-16 class opens with "I'm not getting your audio" (`2026-09-16 20-03-49.txt`). Catching a
  dead mic during the class is worth more than any quality score after it. This is the
  Unreasonable Hospitality version of "quality score".
- *Effort / phase:* M / soon. Needs a process on the studio machine with OBS websocket access.

**A6. The "that was good" marker.** [runner-up]
- *What:* a hotkey, Stream Deck button, or phone shortcut that drops a named chapter marker into the
  recording while teaching. OBS supports chapter markers in Hybrid MP4 via the "Add chapter marker"
  hotkey, the websocket `CreateRecordChapter` request, or the frontend API
  ([OBS Knowledge Base, Hybrid MP4](https://obsproject.com/kb/hybrid-mp4)). Prakriti treats markers as
  the highest-priority clip seeds, above any AI score.
- *Why:* Gabriel described wanting "those key moments"; the teacher knows when a moment landed better
  than any model. Caveats: chapters are written at finalisation and are lost if OBS crashes (same
  KB page), and one macOS user reported chapters not appearing in players
  ([OBS forum thread](https://obsproject.com/forum/threads/streamup-chapter-marker-manager.176239/)), so
  test on the studio Mac. Requires switching the recording format to Hybrid MP4.
- *Effort / phase:* S (settings) plus S to read markers / soon.

**A7. Multitrack audio in the studio.** [TOP 10, T1]
- *What:* teacher mic, co-teacher mic, and Zoom or computer audio on separate tracks; the public mix
  uses only teacher tracks; the voice-model lane takes each teacher's own track.
- *Why:* section 3, T1.
- *Effort / phase:* S (studio settings, a test recording) plus M (pipeline reads tracks) / now.

**A8. "Who is in it" without asking.**
- *What:* infer participants from (a) the calendar event that overlaps the recording start (Serenity
  Mondays at 1pm per the 09-24 debrief; Wednesday evening yin and Sunday talks per the folder's
  dates and weekdays) and (b) voice enrollment: a few minutes of each teacher's clean audio becomes a
  reference so speakers are labelled automatically. Ask only when confidence is low.
- *Why:* the 10-07 design says "we tell it who's in it". That is the one manual step left in an
  "autonomous" pipeline, and it falls on people who do not hit post.
- *Effort / phase:* M / soon.

**A9. Missing-artifact sweeper.** [TOP 10, T9]
- *What:* nightly, list every session and check each expected artifact exists (transcript, score,
  audio, package). Anything missing becomes a visible task with a reason and an automatic retry.
- *Why:* `2026-09-14 20-00-09.mp4`, 62 minutes, has no transcript and nobody noticed (section 1).
- *Effort / phase:* S / now.

**A10. Watcher heartbeat and "away" mode.** [TOP 10, T9]
- *What:* the local watcher pings the Cloudflare Worker every few minutes; a scheduled check alerts
  (email via Resend, and the panel) if no ping arrives inside a grace period on a day a recording is
  expected. "Away" mode: when Ivan's Mac is travelling, sessions queue (or a studio-side helper takes
  over) and the panel says so plainly.
- *Why:* a dead-man's switch catches failures that never raise an error
  ([Healthchecks docs mirror](https://healthchecks.sre.cfainstitute.org/docs/)); Ivan's Mac is not
  always on (`BRIEF.md`).
- *Effort / phase:* S / now.

### B. Privacy, consent and accuracy (Serenity's conditions as features)

**B1. Name scrubber.** [TOP 10, T2]
- *What:* detect personal names spoken in the teacher's own speech (a roster of current and past
  students from GoHighLevel or the YTT lists, plus a name-recognition pass on the transcript), then cut
  the greeting segment or replace the name with a soft tone. The default for classes: trim the
  opening greetings entirely.
- *Why:* see section 1. Keeping only the teacher's voice still publishes students' names.
- *Effort / phase:* M / now (before any class audio publishes).

**B2. Privacy receipt per piece.** [TOP 10, T2]
- *What:* a one-screen receipt: voices heard (by track or speaker), names spoken and what happened to
  each, personal disclosures flagged (B7), and the removed segments with timecodes. Serenity approves
  the receipt in under a minute; any open item blocks publishing.
- *Why:* Serenity is "not a heavy technical user" and needed step-by-step help with macOS Passwords
  (`10 People/Serenity Todesco.md`). The receipt is the smallest surface that lets her own the
  condition she set.
- *Effort / phase:* S / now.

**B3. Accuracy checklist, not a transcript review.** [TOP 10, T3]
- *What:* extract checkable claims (years, ages, numbers, names, Sanskrit terms, attributions,
  references to texts) into a short checklist with the timecode and the line. Serenity ticks, fixes,
  or cuts. Every correction is saved to the lexicon (C1) and the claims memory, so the same mistake
  is caught automatically next time.
- *Why:* her exact words were about "the year" (09-24 debrief). A checklist is specific, fast, and
  learns.
- *Effort / phase:* M / now.

**B4. Stale-truth detector for the archive.** [TOP 10, T3]
- *What:* flag statements in older recordings that are time-sensitive: prices ("we started about
  4,500", `2026-09-06 18-06-33.txt`), offers, dates, cohort starts, "enroll now", retreats, and
  anything about programs that have changed. Options per flag: cut, keep with a spoken or written
  "recorded in 2023" label (D3), or keep.
- *Why:* Gabriel paused new Yoga Marga enrollment in January 2026 (`2026-09-13 18-25-44.txt`). An
  archive episode telling listeners to join something that is closed breaks trust and breaks the
  funnel at the same time. This is the "stale truth" trap from Sonny's own protocol, applied to
  content.
- *Effort / phase:* M / now (archive lane).

**B5. Audio-only suitability check and practice disclaimer.**
- *What:* score how visual a class is (cues like "you guys can't see", "I'll be demoing", "like this",
  "look at your right foot") and route highly visual classes to video-only. For practice episodes
  that do go audio-only, add a short spoken safety line in the intro (listen to your body, consult a
  professional) `[unverified: wording should come from Serenity or counsel]`.
- *Why:* Gabriel's idea of audio-only yin classes (10-07 transcript) is good for verbally cued
  classes and poor for demonstrated ones; the 09-23 class says "I'll be demoing for today's class"
  (`2026-09-23 19-59-52.txt`). A listener following a pose by ear is a liability question for a
  teacher-training school.
- *Effort / phase:* S / now (the podcast lane is first).

**B6. Earnings and health claims flag.**
- *What:* flag income claims ("$32,000 in 30 days", `2026-09-06 18-06-33.txt`) and health or cure
  claims for a deliberate yes before publishing, with an optional standard disclaimer.
- *Why:* in January 2025 the FTC proposed extending the Business Opportunity Rule to "business coaching
  opportunities" and a new Earnings Claim Rule requiring substantiation
  ([Kelley Drye summary](https://www.kelleydrye.com/viewpoints/blogs/ad-law-access/ftc-puts-pedal-to-the-metal-to-release-proposed-rule-on-mlm-earnings-claims-changes-to-business-opportunity-rule-but-republican-commissioners-pump-the-brakes-in-potential-foreshadowing)).
  Final status is `[unverified]`; deceptive earnings claims were already unlawful under the 2012
  rule (same source). Yogi Sales Support is literally a business-coaching offer
  (`Yoga Marga.md`).
- *Effort / phase:* S / soon (when Yogi Sales Support content publishes).

**B7. Sensitive-disclosure flag.**
- *What:* flag personal disclosures about family, health, money, or third parties by name, inside the
  privacy receipt (B2).
- *Why:* talks are informal and personal (a household detail is shared at the start of
  `2026-09-20 18-07-58.txt`, not reproduced here). Serenity's privacy condition was about students;
  the same instinct applies to the teachers' own families.
- *Effort / phase:* S / now (part of B2).

**B8. Voice and likeness consent ledger.**
- *What:* a dated, revocable consent record per person and per use (voice clone, dubbed voice,
  avatar, intro/outro reads). Any job that would synthesize a person's voice or likeness checks the
  ledger first and refuses without a yes.
- *Why:* Serenity "has not consented to an AI version of herself" (`BRIEF.md`). ElevenLabs'
  Professional Voice Clone requires the voice owner to read a CAPTCHA aloud before training
  ([ElevenLabs PVC quickstart](https://elevenlabs.io/docs/cookbooks/voices/professional-voice-cloning)),
  but Instant Voice Cloning only requires the uploader to confirm they have the rights
  ([ElevenLabs voice guide](https://elevenlabs.io/voice-guide)), and YouTube's auto-dubbing generates
  AI voices in other languages (D8). The vendor gates are inconsistent, so the gate has to be
  Prakriti's.
- *Effort / phase:* S / now.

**B9. Student consent registry.**
- *What:* an opt-in ("may your voice and first name appear in public recordings?") collected through a
  GoHighLevel form at enrollment or once for existing students; Prakriti treats opted-in students as
  allowed speakers. Future enrollment agreements carry the clause.
- *Why:* it turns "remove every student" into "include those who said yes", which is what makes
  testimonials (D15) and interactive class moments publishable at all.
- *Effort / phase:* M / later (needs Serenity's answer on how far privacy goes, and wording she
  trusts).

**B10. Right-to-removal finder.**
- *What:* given a person (name, or a voice sample), list every published piece where they are heard or
  named, with links, so takedown is one action.
- *Why:* if a student ever asks, the answer has to be minutes, not a weekend of listening. It also
  makes the privacy promise credible in the features page.
- *Effort / phase:* M / soon (needs A8 voice enrollment).

**B11. Copyright music scan for the archive.**
- *What:* before anything from the archive publishes, detect music and identify known tracks. Apple's
  ShazamKit is available on macOS 12 and later and matches audio signatures against the Shazam
  catalog or a custom catalog
  ([ShazamKit](https://developer.apple.com/documentation/shazamkit.md)); SoundAnalysis ships a
  built-in classifier for 300-plus sound types including musical instruments
  ([WWDC21 session 10036](https://developer-mdn.apple.com/videos/play/wwdc2021/10036)), useful for "is
  there music at all".
- *Why:* Content ID matches audio regardless of whether you hold a licence, and the rights holder
  picks block, monetize or track
  ([Foxi Music guide](https://www.foximusic.com/blog/need-background-music-that-wont-trigger-content-id/)).
  Studio classes are taught without music (section 1); the Zoom-era archive is unknown `[unverified]`.
- *Effort / phase:* M / now (archive lane only).

### C. Transcription and archive ingest

**C1. Yoga Marga lexicon.** [TOP 10, T5]
- *What:* a living glossary: "Yoga Mārga" and "Yoga Marga School", Sanskrit terms with correct
  spelling and optional diacritics (pranayama, Samkhya, the sutras), teachers and lineage names,
  offer names (YTT, YMCT, Yogi Sales Support), recurring places. Used as the transcription prompt,
  in a correction pass, in captions, and shown in show notes as a mini glossary for listeners.
- *Why:* section 3, T5.
- *Effort / phase:* S / now.

**C2. Triage from YouTube's own captions.** [TOP 10, T6]
- *What:* list and download existing caption tracks for the channel's own videos, score topic,
  speaker mix and quality from them, pick the shortlist, and only then run the full local
  transcription.
- *Why:* section 3, T6. Quota: `captions.list` is 50 units and `captions.download` is 200, both from
  the shared 10,000-unit daily pool ([quota table](https://developers.google.com/youtube/v3/determine_quota_cost)),
  so about 250 units per video and about 40 videos a day if nothing else runs `[estimate]`; the full
  900 take about three weeks of quota, or less with a quota increase. Start with the most likely
  candidates so the shortlist exists in the first few days.
- *Effort / phase:* M / now.

**C3. Bulk originals through Google Takeout.**
- *What:* request a Takeout export of the channel's videos (original upload quality) rather than
  pulling each from Studio, which provides 720p or 360p
  ([Make Tech Easier](https://maketecheasier.com/download-your-own-youtube-videos/)).
- *Why:* the roadmap's ask is "add me as a manager on the YouTube channel so I can pull the archive
  down" (roadmap page). Takeout is an owner action, so it may need Gabriel or whoever owns the Google
  account, not a manager. Takeout menus may have changed since the sources were written `[unverified]`.
- *Effort / phase:* S / now.

**C4. Archive dedupe.**
- *What:* audio-fingerprint every archive file (Chromaprint / `fpcalc`, available via Homebrew,
  [pyacoustid](https://pypi.org/project/pyacoustid)) and cluster near-identical recordings: the same
  class uploaded twice, a trimmed re-upload, the Zoom and Fathom copies of the same session.
- *Why:* 900 is Gabriel's number (`BRIEF.md`); with re-uploads and multiple capture tools in use
  (Zoom, Fathom per `2026-09-13 18-25-44.txt`, OBS), the unique count is likely lower `[inferred]`.
  Every duplicate removed is transcription time and review time saved.
- *Effort / phase:* S to M / now.

**C5. Known-sources inventory.**
- *What:* a page listing every place Yoga Marga recordings live, with counts and whether Prakriti has
  ingested them: unlisted YouTube, the studio folder, Fathom, Zoom cloud, the member platform, and
  the hard drives held in Colombia by a former contractor.
- *Why:* the 09-24 debrief records "one or two hard drives in Colombia right now that have recordings
  of our calls and our calls with clients" held by someone Gabriel fired. A "complete archive"
  claim is false while that sits outside it. The inventory makes the gap visible without Ivan having
  to raise it again.
- *Effort / phase:* S / soon.

### D. Outputs nobody listed

**D1. Captions and transcripts everywhere.**
- *What:* upload a caption file to every YouTube video (`captions.insert`, 400 units,
  [Captions: insert](https://developers.google.cn/youtube/v3/docs/captions/insert?hl=en)), and publish a
  timed VTT transcript with speaker labels to the podcast feed. Apple Podcasts shows transcripts you
  provide only after opting in to "Display transcripts I provide", prefers VTT over SRT, needs timing
  (plain text is not delivered), shows "Provided by" the show, and supports the Podcasting 2.0
  `podcast:transcript` tag
  ([Apple support](https://podcasters.apple.com/support/5316-transcripts-on-apple-podcasts);
  [Waveroom guide](https://www.waveroom.com/blog/how-to-add-your-own-transcript-to-apple-podcasts/)).
- *Why:* accessibility for deaf and hard-of-hearing students, searchable text for discovery, and the
  lexicon (C1) makes them right. The existing `.txt` transcripts have no timestamps (`BRIEF.md`), so
  timed transcripts are new work, not a reformat.
- *Effort / phase:* S / now.

**D2. Chapters everywhere.**
- *What:* chapters in YouTube descriptions (first at 0:00, at least three, each at least 10 seconds,
  per third-party guides; [Storyblocks](https://www.storyblocks.com/resources/tutorials/how-to-add-chapters-to-youtube-video))
  and podcast chapters. Apple Podcasts added chapter support, including `podcast:chapters`, with
  iOS 26.2, and auto-generates chapters when none are provided
  ([Podnews FAQ](https://podnews.net/article/apple-chapters-faq)).
- *Why:* a 55 to 70 minute class or talk becomes navigable, and chapter titles are searchable.
  Teacher markers (A6) can seed them.
- *Effort / phase:* S / now.

**D3. Honest provenance labels.**
- *What:* every archive piece is labelled in title or intro: "From the archive, recorded live in
  2023" versus "Studio session". The ElevenLabs intro states it in one line.
- *Why:* Gabriel's whole case for the archive is authenticity ("there's not going to be anything more
  authentic than just Serenity in the middle of her... highest version of herself", 10-07
  transcript). Saying when it was recorded is also the gentlest accuracy hedge for Serenity, and it
  pairs with B4.
- *Effort / phase:* S / now.

**D4. Quote cards.**
- *What:* three pull quotes per piece, set as typographic cards in Yoga Marga's brand (flat, no
  textures, no drawn objects, per Ivan's never-skeuomorphic rule), sized for Instagram, Skool posts
  and the newsletter. Castmagic generates "quote cards" from transcripts as a standard output
  ([Vantaige review](https://vantaige.io/ai-tool/castmagic)).
- *Why:* the cheapest public artifact per recording, and the one most likely to be posted from a
  phone.
- *Effort / phase:* S to M / soon.

**D5. Newsletter and blog post per piece.**
- *What:* a short email for GoHighLevel and a longer post for the website, each with the episode
  embedded and the piece's call to action. Castmagic and Riverside both sell this
  ([Castmagic features](https://www.castmagic.io/features);
  [Riverside AI tools overview](https://support.riverside.com/hc/en-us/articles/13315511579037-AI-Producer-Tools-Overview)).
- *Why:* Gabriel: "there's no web presence" (10-07 transcript), and the website redesign is already
  wanted (`Yoga Marga.md`). Search engines index text, not audio.
- *Effort / phase:* M / soon.

**D6. Themed playlists and podcast seasons.**
- *What:* auto-group pieces by theme (yin, philosophy and the sutras, pranayama, business of yoga,
  community updates) into YouTube playlists and podcast seasons; regenerate as pieces are added.
- *Why:* answers the members' "too much content" complaint (section 1) for the public too, and
  playlists keep a listener inside Yoga Marga's own material.
- *Effort / phase:* S / soon.

**D7. A daily one-minute teaching.**
- *What:* a short daily series (60 to 90 seconds, audio and vertical) cut from strong archive
  moments, with its own feed or playlist.
- *Why:* Gabriel's own frame is Marcus Aurelius, private musings that became public wisdom (10-07
  transcript). A daily rhythm is also the opposite of "incapable of hitting post": it builds the
  habit in public. Volume comes from the archive, not new recording.
- *Effort / phase:* M / later (after the 25).

**D8. Spanish.**
- *What:* three tiers. (1) Spanish captions and show notes: cheap, now-ish. (2) YouTube's built-in
  auto-dubbing, reported in February 2026 as available to all users in 27 languages including Spanish
  with "Expressive Speech" ([Storyboard18](https://www.storyboard18.com/digital/youtube-expands-auto-dubbing-to-27-languages-adds-more-natural-and-expressive-voices-88923.htm);
  eligibility `[unverified]` for this channel). (3) A Spanish podcast feed through ElevenLabs Dubbing,
  which supports Spanish (`es`) ([ElevenLabs dubbing quickstart](https://elevenlabs.io/docs/cookbooks/dubbing)).
- *Why:* Gabriel speaks Spanish ("Papas", "hermano", `10 People/Gabriel Galindo.md`), and YouTube reports
  creators with multi-language audio got more than 25% of watch time from non-primary languages
  ([Storyboard18](https://storyboard18.com/how-it-works/youtube-rolls-out-multi-language-audio-feature-bringing-video-dubbing-to-all-creators-80746.htm)).
  Tiers 2 and 3 synthesize the teacher's voice in another language, so both pass through B8.
- *Effort / phase:* S (tier 1) to L (tier 3) / later.

**D9. Ask the archive: quote, do not generate.** [runner-up]
- *What:* a search box over every transcript that returns the teacher's **actual words** with the
  timecode and a link that plays from that moment, grouped by recording. No synthesized answer in
  her voice. Cloudflare AI Search (formerly AutoRAG) indexes an R2 bucket automatically into
  Vectorize and has a search-only endpoint that returns retrieved content without generation
  ([How AutoRAG works](https://developers.cloudflare.com/autorag/concepts/how-autorag-works)).
  Internal first; members later (D10).
- *Why:* it delivers the per-person knowledge base's value now, without waiting for Serenity's
  consent to an AI version of herself, and it is accuracy-safe because nothing is paraphrased.
  Castmagic's "Magic Chat" is the competitor shape, which generates answers
  ([Castmagic features](https://www.castmagic.io/features)); the quote-only mode is the version that
  fits Serenity's conditions.
- *Effort / phase:* M / soon.

**D10. Member library in the community.**
- *What:* curated paths through the archive ("start here", by theme, by YTT module) for members,
  with unlisted embeds and the D9 search. Skool has no official public API as of mid-2026; the
  supported automation is Zapier (invite member, unlock a course), reported to need the Pro plan
  ([RevenueGeeks](https://revenuegeeks.com/software/skool/api);
  [Zapier Skool integrations](https://zapier.com/apps/skool/integrations/webhook)).
- *Why:* the old content-engine plan already called archive search "the actual product" for a paid
  community (`content-engine/PLAN.md`), and members say there is too much to navigate (section 1).
- *Effort / phase:* M / later.

**D11. Course coverage map against the YTT syllabi.**
- *What:* once Serenity sends the three syllabi, map every archive segment to syllabus modules; show
  which modules have strong material, weak material, or none.
- *Why:* the self-paced YTT (workstream 4 on 09-24) is built from this corpus. The map tells them
  what they already have and what is missing before anyone records.
- *Effort / phase:* L / later (blocked on the syllabi).

**D12. Gap-driven recording brief.** [runner-up]
- *What:* Prakriti proposes what to record next: topics with audience demand (F1, D16), weak or
  missing coverage (D11), or a powerful archive moment in poor quality. It drafts a teleprompter
  script in the teacher's own phrasing from the archive, with the accuracy checklist (B3) applied
  before recording.
- *Why:* the studio has a teleprompter "that matches our voice" (10-07 transcript), and the 09-24
  answer to Serenity's accuracy condition was exactly this: a fresh, fact-checked script from the
  corpus. It closes the loop from output back to input, which none of the 10-07 outputs do.
- *Effort / phase:* M / soon.

**D13. Continuing-education courses for teachers.**
- *What:* package archive material into structured continuing-education courses for registered yoga
  teachers.
- *Why:* Gabriel introduces Yoga Marga School as providing "continuing education for yoga teachers
  and spiritual practitioners" (`2026-09-06 18-06-33.txt`). Yoga Alliance requires RYTs to complete
  75 CE hours every three years, 30 of them training, and states all 30 may be distance learning, per
  an official page last updated July 2023
  ([Yoga Alliance via search result](https://www.yogaalliance.org/Credentialing/ContinuingEducation),
  `[unverified current]`); courses must come from a registered YACEP, an E-RYT, or a qualified
  professional (same source). Whether Yoga Marga qualifies is an open question.
- *Effort / phase:* L / later.

**D14. Teaching-lineage map and credits.**
- *What:* track teachers, texts and traditions cited in the recordings ("the teachings from Dr. David
  Wolf", `2026-09-13 18-25-44.txt`; the sutras; Samkhya) and credit them in show notes; build a
  lineage page over time.
- *Why:* respect for lineage is part of accuracy in a teacher-training school, and attribution is a
  check Serenity would want (B3).
- *Effort / phase:* M / later.

**D15. Testimonials, with a consent request.**
- *What:* find moments where a student describes a change, then generate a consent request to that
  student (GoHighLevel form) before the moment can be used.
- *Why:* testimonials sell YTT and Yogi Sales Support; Serenity's privacy rule forbids using them
  silently. The consent request is the only version that serves both.
- *Effort / phase:* M / later (after B9).

**D16. Question and objection mining.**
- *What:* collect questions students ask in classes and viewers ask in YouTube comments into a FAQ that
  feeds topics (D12) and, for Gabriel's side, the objection library for Yogi Sales Support.
- *Why:* ties the content engine to the sales offer Gabriel is building (`Yoga Marga.md`), and to the
  VeraSales training-dashboard direction (`30 Ventures/Gabriel Galindo — Closer.md`).
- *Effort / phase:* M / later.

**D17. Seasonal calendar.**
- *What:* a content calendar that pulls matching archive pieces forward for dates: International Day
  of Yoga on 21 June (UN resolution A/RES/69/131,
  [Wikisource copy](https://en.wikisource.org/wiki/United_Nations_Resolution_No._69-131_(International_Day_of_Yoga))),
  solstices and equinoxes, new-year intentions, and Yoga Marga's own cohort and retreat dates.
- *Why:* cheap relevance; the queue (E2) can hold themed pieces ahead of time.
- *Effort / phase:* S / later.

### E. Distribution and the "hit post" habit

**E1. One-tap approve.** [TOP 10, T7]
- *What:* every "ready" notification opens a single approve screen: the piece, its receipts (B2, B3),
  title, thumbnail, call to action, and one button. "Approve all ready" for batches. On macOS a
  native helper can put Approve and Review buttons on the notification itself
  (`UNNotificationAction`, macOS 10.14 and later,
  [Apple docs](https://developer.apple.com/documentation/usernotifications/unnotificationaction.md)).
  On iPhone, web push for a Home Screen web app reliably opens a URL on tap; action buttons in Safari
  web push are not confirmed ([WebKit, Declarative Web Push](https://webkit.org/?p=16535);
  [Apple forum thread](https://developer.apple.com/forums/thread/726793), `[unverified]`), so design
  for tap-then-approve: two taps.
- *Why:* Gabriel's sentence. Every extra screen between "ready" and "live" is where it dies.
- *Effort / phase:* M / now.

**E2. Release queue with a cadence and a runway.** [TOP 10, T7]
- *What:* approved pieces wait in a queue that releases on a set rhythm (for example Tuesday, Thursday,
  Sunday), so approving ten on a Sunday does not dump ten at once. The home screen shows runway ("12
  days of content queued") and the next three releases.
- *Why:* consistency matters more than bursts for a channel being found for the first time, and runway
  turns "we should post" into a number the team can see falling.
- *Effort / phase:* S / now.

**E3. GoHighLevel as the posting and approval layer.** [TOP 10, T10]
- *What / why:* section 3, T10.
- *Effort / phase:* M / soon.

**E4. Podcast once, YouTube automatically.**
- *What:* submit the podcast's RSS feed in YouTube Studio; YouTube turns each audio episode into a
  static-image video on the channel, back-catalog episodes arrive as private, and new episodes upload
  automatically ([YouTube Help](https://support.google.com/youtube/answer/13973017?hl=en);
  [Android Central](https://www.androidcentral.com/apps-software/youtube-audio-only-podcast-upload-rss-feed)).
  Available in select countries including the US.
- *Why:* the podcast lane is first (`BRIEF.md`); this puts every episode on YouTube and YouTube Music
  with no upload code at all. Trade-off: a static image, not an edited video, so use it for the audio
  lane and keep edited video for the best pieces.
- *Effort / phase:* S / soon.

**E5. Spoken-promise check.** [TOP 10, T8]
- *What:* detect promises and calls to action spoken in the recording ("below this video you'll see
  the option to enroll in a free week", `2026-09-13 18-25-44.txt`; "I'll make sure the calls get
  uploaded", same file) and require the package to fulfil each: the link in the description, the
  follow-up task created with an owner.
- *Why:* Ivan's own rule that a request carries its own mechanism, and his "close the loop" lesson
  (`memory/close-the-loop-not-just-the-transaction.md`). A published video that points "below" at
  nothing is a broken promise in public.
- *Effort / phase:* S to M / now.

**E6. Call-to-action router with tracked links.** [TOP 10, T8]
- *What:* a small table of calls to action per venture and content type, chosen automatically and
  shown on the approve screen; each piece gets its own tracked link (UTM or a GoHighLevel trigger
  link).
- *Why:* see T8. The answer to "what is the ask now that enrollment paused" is an open question
  (section 7), and the router is where that answer lives.
- *Effort / phase:* S to M / now.

**E7. Content-to-lead ledger.** [TOP 10, T8]
- *What:* leads arriving through a piece's link are created or tagged in GoHighLevel (inbound webhook
  trigger, a premium trigger with metered executions per third-party guides,
  [Growthable](https://growthable.io/gohighlevel-tutorials/workflows/how-to-use-the-inbound-webhook-workflow-premium-trigger-in-gohighlevel/);
  or the Contacts API) and attributed back; the panel shows leads, calls booked and enrollments per
  piece.
- *Why:* the only proof the engine is worth its cost to the business, and the input for F1.
- *Effort / phase:* M / soon.

**E8. Thumbnail test handoff.**
- *What:* Prakriti prepares the three thumbnails, then gives a one-screen checklist to run YouTube's
  "Test & compare" and records the winner back.
- *Why:* the 10-07 package promised three thumbnails "for YouTube A/B tests" (`BRIEF.md`). Test &
  compare is a desktop YouTube Studio feature, up to three thumbnails, judged on watch-time share,
  not available for Shorts, Made for Kids, mature or private videos
  ([YouTube Help](https://support.google.com/youtube/answer/13861714)); no Data API access was found.
  Unlisted eligibility `[unverified]`. So the A/B step is a human step per video, or it does not
  happen.
- *Effort / phase:* S / soon.

**E9. Publish-unless-vetoed mode (a decision, not a build).**
- *What:* once trust is earned (for example 20 consecutive approvals without edits), pieces in a
  given lane publish at their scheduled time unless someone vetoes in the 24 hours before.
- *Why:* the honest cure for "incapable of hitting post" is removing the need to hit it. It conflicts
  with the standing rule "nothing outward-facing without a human yes" (`BRIEF.md`), so it can only
  be switched on by Ivan's explicit decision, per lane, with the kill switch (G3) in place. Write it
  down now so the roadmap has somewhere for it to go.
- *Effort / phase:* S / later, by decision.

**E10. Impact note to the teacher.**
- *What:* when a piece goes live, the teacher gets a short note with the link; 48 hours later, a
  second line with how many people listened or watched and any comment worth reading.
- *Why:* Unreasonable Hospitality for the creators themselves. People who cannot hit post are often
  people who never see that it mattered. Seeing that it did is the reinforcement the habit needs.
- *Effort / phase:* S / soon.

**E11. Past-student re-engagement.**
- *What:* when a class is published, students who attended it and opted in (B9) get a note: "the
  class you took is now an episode".
- *Why:* Gabriel: people "love" this material and keep "coming back years and years later" (10-07
  transcript). The archive is also a reactivation list.
- *Effort / phase:* M / later.

**E12. Comment reply drafts.**
- *What:* drafts of replies to YouTube and podcast comments in the teacher's voice, queued for one-tap
  send. Never automatic.
- *Why:* responsiveness grows a young channel; the drafts remove the blank-page cost.
- *Effort / phase:* M / later.

**E13. Findability check.** [runner-up]
- *What:* weekly, record what a stranger sees when searching "Yoga Marga", "Yoga Marga School",
  "Serenity Todesco" and "Gabriel Galindo yoga" on YouTube and Apple Podcasts: how many results are
  theirs, on the first screen. Show the trend in the digest (G10).
- *Why:* this is the number inside Gabriel's complaint (section 2). It measures the vision, not the
  activity.
- *Effort / phase:* S to M / soon.

### F. The learning loop

**F1. Performance feedback into the score.**
- *What:* pull per-video retention from the YouTube Analytics API (`audienceWatchRatio` and
  `relativeRetentionPerformance` by `elapsedVideoTimeRatio`, up to 100 points, two to three days of
  lag, `yt-analytics.readonly` scope;
  [Zernio docs](https://docs.zernio.com/analytics/get-youtube-video-retention);
  [analytix reference](https://analytix.readthedocs.io/en/v2.1.0/refs/yt-analytics-reports.html)) and
  podcast downloads (from the host, or open analytics through the OP3 prefix,
  [op3.dev](https://op3.dev/)). Compare predicted score to actual performance; recalibrate monthly.
- *Why:* the 10-07 quality score is a guess until it is checked against what people actually watch.
  Opus Clip's own virality score is described by reviewers as "a rough guide, not gospel"
  ([Opus Clip help](https://help.opus.pro/docs/article/virality-score);
  [review](https://marcandrews.com/?p=6263)).
- *Effort / phase:* M / later (needs a few weeks of data).

**F2. The audience picks the clips.**
- *What:* segments viewers rewatch or where retention holds unusually well become Shorts and
  daily-teaching (D7) candidates automatically.
- *Why:* the best signal for "key moments" is the audience's own behaviour; it complements teacher
  markers (A6).
- *Effort / phase:* M / later.

**F3. Taste log.** [runner-up]
- *What:* every rejection or edit asks for one tap of a reason ("too salesy", "wrong year", "not my
  best", "privacy", "off-brand"), stored and fed back into prompts and scoring per person.
- *Why:* the engine is supposed to work without further input; it can only do that if the input it
  does get teaches it. VeraSales already stores per-account voice documents in a Prompt Library
  (`30 Ventures/Gabriel Galindo — Closer.md`, 09-24 entry), so the pattern exists.
- *Effort / phase:* S to M / soon.

### G. Operations (the COO lens)

**G1. Evidence log per run.** [TOP 10, T9]
- *What:* a receipt per run: input file hash, models and versions, prompts, durations, costs, outputs,
  who approved what and when, and where it was published.
- *Why:* "verify by rendering and looking, not by reading code" (`BRIEF.md`) needs something to look
  at; disputes ("I never approved that") need a record; re-runs (G4) need to know what produced what.
- *Effort / phase:* S / now.

**G2. Cost meter with a monthly cap.** [TOP 10, T9]
- *What:* per piece and per month: Anthropic, ElevenLabs, storage, any paid transcription. A cap that
  pauses non-urgent work and alerts.
- *Why:* ElevenLabs bills isolation at 1,000 characters per minute of audio, files up to 1 hour
  ([Voice Isolator docs](https://elevenlabs.io/docs/capabilities/voice-isolator)); run across an archive
  this adds up fast `[estimate pending plan]`. The roadmap page lists Prakriti as "its own project to
  scope", and a factual cost line is the neutral way to have the money conversation the vault keeps
  flagging (`Yoga Marga.md`, "Fourth unscoped, unpriced ask").
- *Effort / phase:* S / now.

**G3. Kill switch.** [TOP 10, T9]
- *What:* one control that stops every outward action (publish, post, email, upload) immediately,
  per lane or globally; also tripped automatically by a failed privacy check, a cost spike, or a
  burst of errors.
- *Why:* autonomy is only acceptable if stopping it is easier than starting it.
- *Effort / phase:* S / now.

**G4. Re-run on model upgrade.**
- *What:* every stage is versioned; when a better transcription or language model ships, re-run
  selected stages over the archive and show a diff (for example: 40 names newly caught, 12 chapter
  titles improved). Published assets are never overwritten in place; changed outputs get new names
  (Ivan's "never overwrite an immutable asset" rule, `MEMORY.md`).
- *Why:* a 900-recording archive processed once with this year's models will be under-served by next
  year's; and a model switch "changes every request" (`MEMORY.md`, Opus 5.5 entry), so re-runs must be
  deliberate.
- *Effort / phase:* M / later.

**G5. Storage lifecycle.**
- *What:* raw masters move out of the iCloud shared folder after processing (to the RAID tower or to
  R2 Infrequent Access), with lightweight proxies and the audio mezzanine kept hot. Never delete
  masters. R2 is about $0.015 per GB-month standard and $0.01 Infrequent Access (30-day minimum),
  with no egress charge, per third-party summaries
  ([Filebase](https://filebase.com/blog/cloudflare-r2-pricing-costs-savings-and-alternatives-in-2026/),
  `[unverified against Cloudflare's page]`). At 500 GB, about $5 to $7.50 a month `[estimate]`.
- *Why:* about 17.9 GB in September from the studio alone (section 1), in a folder owned by Ivan's
  iCloud account, and the RAID build is not dated (`Yoga Marga.md`).
- *Effort / phase:* M / soon.

**G6. A lane for low scores and failures.**
- *What:* nothing is deleted. Low-scoring recordings still feed the knowledge base (D9) and the member
  library (D10). Failures carry a reason code, retry automatically once, then surface as a named task.
  The score decides where a recording goes, not whether it lives.
- *Why:* Gabriel's point that even "shitty quality... the message is solid" (10-07 transcript). A
  recording that should not be public can still teach a member.
- *Effort / phase:* S / now.

**G7. Ownership and exit export.**
- *What:* one action exports everything (sessions, packages, transcripts, knowledge bases, the
  lexicon, receipts) to storage Yoga Marga controls, in open formats.
- *Why:* Prakriti will run on Ivan's Cloudflare account, iCloud and API keys (`BRIEF.md`) for content
  that is Gabriel and Serenity's. The roadmap page already drafts "what we own together"; the export
  is that sentence in software, and it is the honest answer to "what happens if this ends".
- *Effort / phase:* S / soon.

**G8. Ready for more than one account.**
- *What:* scope all data to an account from day one, as in Up Next and VeraSales (`BRIEF.md`).
- *Why:* Ivan on 10-07: "We all have access to this thing, just the 3 of us. And then maybe later we
  can make a product." Retrofitting tenancy later is the expensive version; VeraSales had to add its
  tenant boundary after launch (`30 Ventures/Gabriel Galindo — Closer.md`, 09-16 entry).
- *Effort / phase:* S / now.

**G9. Role-specific views, and Serenity's email.**
- *What:* Serenity's home shows only "needs your eyes" (privacy and accuracy receipts) and what went
  live. Gabriel's shows "ready to post", runway, and leads. Ivan's shows health, cost and failures.
  Sign-in collects each person's email.
- *Why:* Serenity's time and comfort with tools are the scarce resource. And the vault has logged for
  two months that nobody has her email address
  (`10 People/Serenity Todesco.md`, "Still no way to reach her"); her first sign-in fixes that.
- *Effort / phase:* S / now.

**G10. Monday digest.**
- *What:* one email (Resend) on Monday morning: what went live, what is waiting and on whom by name,
  runway, findability (E13), leads (E7), cost (G2), anything broken.
- *Why:* Ivan's "one recap at end of day" preference and his requests-carry-their-own-mechanism rule
  (`MEMORY.md`). Three busy people will read one email; they will not open a dashboard.
- *Effort / phase:* S / now.

---

## 5. Ranked list (all 69)

Ranked by value to the 25-by-6-Nov target and Serenity's two conditions, then by how much it
reduces human time, then by effort.

| Rank | ID | Idea | Effort | Phase | Flag |
|---:|---|---|:-:|:-:|---|
| 1 | A7 | Multitrack audio in the studio | S+M | now | TOP 10 |
| 2 | B2 | Privacy receipt per piece | S | now | TOP 10 |
| 3 | B1 | Name scrubber | M | now | TOP 10 |
| 4 | E1 | One-tap approve | M | now | TOP 10 |
| 5 | A1 | A session is the unit, not a file | S | now | TOP 10 |
| 6 | C1 | Yoga Marga lexicon | S | now | TOP 10 |
| 7 | B3 | Accuracy checklist | M | now | TOP 10 |
| 8 | G3 | Kill switch | S | now | TOP 10 |
| 9 | A10 | Watcher heartbeat and away mode | S | now | TOP 10 |
| 10 | E2 | Release queue, cadence, runway | S | now | TOP 10 |
| 11 | C2 | Triage from YouTube's own captions | M | now | TOP 10 |
| 12 | B4 | Stale-truth detector | M | now | TOP 10 |
| 13 | E6 | Call-to-action router | S-M | now | TOP 10 |
| 14 | E5 | Spoken-promise check | S-M | now | TOP 10 |
| 15 | A4 | Recording-stop handshake | S | now | |
| 16 | A2 | Test and noise triage | S | now | TOP 10 |
| 17 | A3 | Venture router | M | now | TOP 10 |
| 18 | G1 | Evidence log per run | S | now | TOP 10 |
| 19 | G2 | Cost meter with cap | S | now | TOP 10 |
| 20 | G10 | Monday digest | S | now | |
| 21 | B8 | Voice and likeness consent ledger | S | now | |
| 22 | A9 | Missing-artifact sweeper | S | now | TOP 10 |
| 23 | D1 | Captions and transcripts everywhere | S | now | |
| 24 | D2 | Chapters everywhere | S | now | |
| 25 | D3 | Honest provenance labels | S | now | |
| 26 | B5 | Audio-only suitability and disclaimer | S | now | |
| 27 | C3 | Takeout originals | S | now | TOP 10 |
| 28 | C4 | Archive dedupe | S-M | now | TOP 10 |
| 29 | B11 | Copyright music scan (archive) | M | now | TOP 10 |
| 30 | G6 | Lane for low scores and failures | S | now | |
| 31 | G9 | Role-specific views, Serenity's email | S | now | |
| 32 | G8 | Ready for more than one account | S | now | |
| 33 | E3 | GoHighLevel posts and approves | M | soon | TOP 10 |
| 34 | E7 | Content-to-lead ledger | M | soon | TOP 10 |
| 35 | A6 | "That was good" marker | S | soon | runner-up |
| 36 | D9 | Ask the archive, quote only | M | soon | runner-up |
| 37 | E13 | Findability check | S-M | soon | runner-up |
| 38 | D12 | Gap-driven recording brief | M | soon | runner-up |
| 39 | F3 | Taste log | S-M | soon | runner-up |
| 40 | E10 | Impact note to the teacher | S | soon | |
| 41 | A8 | Who is in it, without asking | M | soon | |
| 42 | A5 | Live recording guard | M | soon | |
| 43 | B7 | Sensitive-disclosure flag | S | now (inside B2) | |
| 44 | B6 | Earnings and health claims flag | S | soon | |
| 45 | E4 | Podcast RSS to YouTube | S | soon | |
| 46 | E8 | Thumbnail test handoff | S | soon | |
| 47 | G5 | Storage lifecycle | M | soon | |
| 48 | G7 | Ownership and exit export | S | soon | |
| 49 | C5 | Known-sources inventory | S | soon | |
| 50 | D4 | Quote cards | S-M | soon | |
| 51 | D6 | Themed playlists and seasons | S | soon | |
| 52 | D5 | Newsletter and blog post | M | soon | |
| 53 | B10 | Right-to-removal finder | M | soon | |
| 54 | D7 | Daily one-minute teaching | M | later | |
| 55 | F1 | Performance feedback into score | M | later | |
| 56 | F2 | The audience picks the clips | M | later | |
| 57 | G4 | Re-run on model upgrade | M | later | |
| 58 | D10 | Member library in the community | M | later | |
| 59 | D11 | Course coverage map | L | later | |
| 60 | D8 | Spanish (three tiers) | S-L | later | |
| 61 | B9 | Student consent registry | M | later | |
| 62 | D16 | Question and objection mining | M | later | |
| 63 | D14 | Lineage map and credits | M | later | |
| 64 | D15 | Testimonials with consent | M | later | |
| 65 | E11 | Past-student re-engagement | M | later | |
| 66 | D13 | Continuing-education courses | L | later | |
| 67 | D17 | Seasonal calendar | S | later | |
| 68 | E12 | Comment reply drafts | M | later | |
| 69 | E9 | Publish-unless-vetoed (decision) | S | later, by decision | |

Note on the TOP 10 flags: the ten scope changes in section 3 are bundles (T1 to T10), so more than
ten rows carry the flag. Each bundle should land in the scope as one line item.

---

## 6. Never (and why)

| Idea | Why not |
|---|---|
| **Auto-publish anything with an unconsented student voice or name** | Serenity's first condition; the 09-24 debrief calls it "the engagement's first real breach of trust" if it happens. |
| **Answers generated in Serenity's voice for students** (an "Ask Serenity" chatbot) before she consents | She has not consented to an AI version of herself (`BRIEF.md`). D9's quote-only search delivers most of the value without crossing that line. |
| **Waveform audiograms, film-strip or scrub-bar visuals** | Ivan's never-skeuomorphic rule (`BRIEF.md`). Quote cards (D4) are the flat alternative. |
| **Automatic comment replies** | Outward-facing without a human yes; a wrong-tone reply in a teacher's name is worse than silence. E12 drafts only. |
| **A virality score as the north star** | Reviewers call Opus Clip's score "a rough guide, not gospel" ([review](https://marcandrews.com/?p=6263)); Yoga Marga's goal is findability and enrollments (E13, E7), not virality. |
| **Deleting masters after processing** | Re-runs (G4) and future models need the originals; lifecycle them to cold storage (G5) instead. |
| **Building Instagram, TikTok and Facebook posting integrations in-house** | GoHighLevel's Social Planner already does it and is already paid for (E3). Build YouTube direct only if GoHighLevel falls short. |

---

## 7. Facts that contradict current assumptions

1. **YouTube's upload quota is no longer the bottleneck.** Google's quota page, last updated
   2026-10-08, says `videos.insert` and `search.list` "have their own quota buckets" with "a default
   daily limit of 100 per day", each call costing 1
   ([Google](https://developers.google.com/youtube/v3/determine_quota_cost)). The vault's "~6 uploads/day"
   constraint (`20 Projects/Gabriel Galindo — Content Engine.md`; `content-engine/PLAN.md`) is stale.
   The bottleneck for 25 by 6 Nov is approvals, which strengthens T7.
2. **"12 recordings" is 6 real sessions, about 5.4 hours** (section 1). The brief's count is files.
3. **One studio session already has no transcript** (`2026-09-14 20-00-09.mp4`).
4. **Diarization cannot carry the privacy promise on this audio**: one mixed track per file, and the
   existing transcripts label whole classes as one speaker.
5. **Keeping only the teacher's voice still publishes student names**, because the teacher greets
   students by name.
6. **The studio yin classes are taught without music**, by stated policy; music risk is an archive
   problem.
7. **New Yoga Marga enrollment paused in January 2026** (`2026-09-13 18-25-44.txt`), so the archive
   will advertise things that no longer exist, and the right call to action is an open question.
8. **The three thumbnails cannot be A/B tested by API**: Test & compare is desktop Studio only, not
   for Shorts.
9. **Vendor consent gates are uneven**: ElevenLabs PVC needs the owner to read a CAPTCHA, Instant
   Voice Cloning only a checkbox; YouTube auto-dubbing synthesizes voices in other languages.
10. **Posting and approval may already be paid for**: GoHighLevel's Social Planner posts to YouTube
    (video or short, unlisted or public, scheduled) and has an approval flow.
11. **RedCircle has no confirmed public upload API**: only third-party connector pages, some
    describing a different product ([Pipedream listing](https://pipedream.com/apps/redcircle-api)). Its
    manual form does accept a transcript URL ([RedCircle support](https://support.redcircle.com/uploading-an-episode)).
    Plan for a manual upload step, or a self-hosted feed, until confirmed.
12. **Skool has no official public API** (Zapier only, reportedly Pro plan), so "publish into Skool"
    is a link or a Zapier step, not an integration.

---

## 8. Open questions (with the person who owns each)

1. **Gabriel:** now that new Yoga Marga enrollment is paused, what is the one ask for each content
   type? The free week, Yogi Sales Support, YMCT, Serenity's coaching? (Drives E6, E7.)
2. **Gabriel, studio:** which microphones and sources does OBS have; can Zoom audio go on its own
   track; can recording switch to Hybrid MP4 for markers? Who makes the change, and when is the test
   recording? (A6, A7.)
3. **Serenity:** for names spoken in class, cut the greeting, tone the name, or allow first names with
   consent? (B1, B9.)
4. **Serenity:** would a 5 to 10 item accuracy checklist per piece meet her condition, or does she want
   a different review mode? (B3.)
5. **Gabriel:** did the Zoom-era classes in the archive play background music? (B11.)
6. **Gabriel:** which Google account owns the channel, and is it in the YouTube Partner Program?
   (C3 Takeout, D8 auto-dubbing eligibility.)
7. **Gabriel:** does GoHighLevel's plan include Social Planner with YouTube connected, approvals, and
   premium triggers? (E3, E7.)
8. **Gabriel or Serenity:** does Yoga Marga hold YACEP status, or does a teacher hold E-RYT? (D13.)
9. **Gabriel or Serenity:** do YTT enrollment agreements already include a recording or consent
   clause? (B9.)
10. **Ivan:** is publish-unless-vetoed (E9) ever acceptable, and at what trust threshold?
11. **Ivan:** where does the watcher run when his Mac travels: is there a studio Mac that can host a
    helper? (A5, A10.)
12. **Ivan and Gabriel:** who owns the content, the knowledge bases and the voice data if the
    engagement ends? (G7.)

---

## 9. Sources

**Local files (read-only):**
- `/Users/ivanlizarde/Code/prakriti/research/BRIEF.md`
- `/Users/ivanlizarde/Code/prakriti/research/2026-10-07-call-gabriel-transcript.txt`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/20 Projects/Yoga Marga.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/20 Projects/Gabriel Galindo — Content Engine.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/20 Projects/Call Debriefs/2026-09-24 — Gabriel Galindo and Serenity.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/10 People/Serenity Todesco.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/10 People/Gabriel Galindo.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/30 Ventures/Gabriel Galindo — Closer.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Sonny/Sonny/40 Decisions/2026-10-08 — The content engine is called Prakriti.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/Gabriel Galindo/Roadmap/galindo-lizarde-roadmap.html`
- `/Users/ivanlizarde/Documents/Claude/Projects/Gabriel Galindo/content-engine/PLAN.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/The Work Book/The Work Book — Web App Concept.md`
- `/Users/ivanlizarde/Documents/Claude/Projects/The Coaching Studio/coaching-studio-v1-spec-foundation.md`
- `~/.claude/projects/-Users-ivanlizarde-Documents-Claude-Projects/memory/complaint-is-a-latent-vision.md`, `unreasonable-hospitality.md`, `close-the-loop-not-just-the-transaction.md`
- `~/.claude/skills/transcribe-audio/SKILL.md`
- `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /` (all 12 `.mp4` probed with `ffprobe`; all `.txt` grepped)

**Web (checked 2026-10-08):**
- OBS Hybrid MP4 chapter markers: https://obsproject.com/kb/hybrid-mp4
- OBS chapter plugin thread (macOS report): https://obsproject.com/forum/threads/streamup-chapter-marker-manager.176239/
- OBS multitrack recording: https://obsproject.com/forum/threads/high-quality-recording-with-multiple-audio-tracks-in-advanced-output-mode.150001/ ; https://www.gamingonlinux.com/2017/02/how-to-record-videos-on-linux-using-obs-studio-with-separate-audio-tracks-for-gameplay-and-microphone/page=1/ ; https://obsproject.com/forum/threads/issue-with-multiple-audio-tracks-from-2-audio-sources.54106
- obs-websocket RecordStateChanged: https://wiki.streamer.bot/en/Broadcasters/OBS/Events/Output-Events/RecordStateChanged ; InputVolumeMeters: https://tessl.io/registry/tessl/pypi-obsws-python/files/docs/event-subscriptions.md
- YouTube quota (videos.insert bucket, captions costs): https://developers.google.com/youtube/v3/determine_quota_cost
- YouTube captions.insert / download / resource: https://developers.google.cn/youtube/v3/docs/captions/insert?hl=en ; https://developers.google.com/youtube/v3/docs/captions/download ; https://developers.google.com/youtube/v3/docs/captions?hl=ja
- YouTube Test & compare: https://support.google.com/youtube/answer/13861714
- YouTube chapters rules (third party): https://www.storyblocks.com/resources/tutorials/how-to-add-chapters-to-youtube-video
- YouTube RSS podcast ingestion: https://support.google.com/youtube/answer/13973017?hl=en ; https://www.androidcentral.com/apps-software/youtube-audio-only-podcast-upload-rss-feed
- YouTube auto-dubbing and multi-language audio: https://www.storyboard18.com/digital/youtube-expands-auto-dubbing-to-27-languages-adds-more-natural-and-expressive-voices-88923.htm ; https://storyboard18.com/how-it-works/youtube-rolls-out-multi-language-audio-feature-bringing-video-dubbing-to-all-creators-80746.htm
- YouTube Analytics retention: https://docs.zernio.com/analytics/get-youtube-video-retention ; https://analytix.readthedocs.io/en/v2.1.0/refs/yt-analytics-reports.html
- Google Takeout / Studio download quality: https://maketecheasier.com/download-your-own-youtube-videos/ ; https://www.phonearena.com/news/Google-Takeout-lets-you-retrieve-your-original-YouTube-videos_id35024
- Apple Podcasts transcripts: https://podcasters.apple.com/support/5316-transcripts-on-apple-podcasts ; https://www.waveroom.com/blog/how-to-add-your-own-transcript-to-apple-podcasts/
- Apple Podcasts chapters: https://podnews.net/article/apple-chapters-faq
- ShazamKit: https://developer.apple.com/documentation/shazamkit.md
- SoundAnalysis built-in classifier: https://developer-mdn.apple.com/videos/play/wwdc2021/10036
- UNNotificationAction: https://developer.apple.com/documentation/usernotifications/unnotificationaction.md
- Declarative Web Push / iOS actions: https://webkit.org/?p=16535 ; https://developer.apple.com/forums/thread/726793
- ElevenLabs PVC verification: https://elevenlabs.io/docs/cookbooks/voices/professional-voice-cloning ; IVC: https://elevenlabs.io/voice-guide
- ElevenLabs Voice Isolator: https://elevenlabs.io/docs/capabilities/voice-isolator ; Dubbing: https://elevenlabs.io/docs/cookbooks/dubbing
- GoHighLevel create post API: https://marketplace.gohighlevel.com/docs/2021-04-15/ghl/social-planner/create-post
- GoHighLevel post approval: https://mastermind.helpscoutdocs.com/article/254-post-approval-in-the-social-planner ; https://blog.tekmatix.com/b/post-approval-flow-in-social-planner
- GoHighLevel inbound webhook trigger: https://growthable.io/gohighlevel-tutorials/workflows/how-to-use-the-inbound-webhook-workflow-premium-trigger-in-gohighlevel/
- Skool API status: https://revenuegeeks.com/software/skool/api ; https://zapier.com/apps/skool/integrations/webhook
- RedCircle: https://pipedream.com/apps/redcircle-api ; https://support.redcircle.com/uploading-an-episode
- Cloudflare AI Search (AutoRAG): https://developers.cloudflare.com/autorag/concepts/how-autorag-works
- Cloudflare R2 pricing (third party): https://filebase.com/blog/cloudflare-r2-pricing-costs-savings-and-alternatives-in-2026/
- Healthchecks (dead-man's switch): https://healthchecks.sre.cfainstitute.org/docs/
- Chromaprint / pyacoustid: https://pypi.org/project/pyacoustid
- OP3 podcast analytics: https://op3.dev/
- Yoga Alliance CE: https://www.yogaalliance.org/Credentialing/ContinuingEducation (content via search summary; the live page redirected and did not show CE detail)
- International Day of Yoga: https://en.wikisource.org/wiki/United_Nations_Resolution_No._69-131_(International_Day_of_Yoga)
- FTC earnings claims proposal: https://www.kelleydrye.com/viewpoints/blogs/ad-law-access/ftc-puts-pedal-to-the-metal-to-release-proposed-rule-on-mlm-earnings-claims-changes-to-business-opportunity-rule-but-republican-commissioners-pump-the-brakes-in-potential-foreshadowing
- Content ID and music licensing (vendor guide): https://www.foximusic.com/blog/need-background-music-that-wont-trigger-content-id/
- Competitors: Castmagic https://www.castmagic.io/features , https://vantaige.io/ai-tool/castmagic ; Opus Clip https://help.opus.pro/docs/article/virality-score , https://marcandrews.com/?p=6263 ; Riverside https://support.riverside.com/hc/en-us/articles/13315511579037-AI-Producer-Tools-Overview
