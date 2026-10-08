# Prakriti — the decision spine (v1, 2026-10-08)

Written by Sonny after reading all nine research files. Every writer, designer and critic builds
from this file. Where this file and a research file disagree, this file wins; where this file is
silent, the research files are the evidence. Anything marked **OPEN** is not ours to decide: it
belongs to Ivan, Gabriel or Serenity and must be shown to them as a question with a recommended
answer, never silently decided.

## Facts that changed the plan (from research, all cited there)

1. **The archive is 958 videos, ~1,175 hours** (Nov 2023 to May 2026) on the Yoga Mārga School
   channel (`yogamarga.school`), mostly unlisted. It includes guest teachers, student practicums,
   114 untitled test uploads, ~33 duplicates and a private playlist of 1:1 coaching calls. Most of
   it is Serenity teaching. A Google Takeout of the channel is ~69% on Ivan's Mac
   (`~/Downloads/SerenityAI`, ~253 GB) and the link likely expires 2026-10-08.
2. **The studio folder is 6 real sessions, ~5.4 hours**, not 12 recordings: horizontal + vertical
   twins and 8 to 153 second tests. **2026-09-14 (62 min class) has a completely silent audio
   track** and nobody noticed for 24 days. Nothing usable recorded since 09-23. No Serenity studio
   recording yet.
3. **Every studio file is one mixed mic** (dual-mono). Existing diarization put a student's
   personal story under the teacher's label. **Diarization cannot carry the privacy promise.** The
   teacher also says students' first names. Upstream fix: OBS multitrack (mix, one track per
   teacher mic, one track for Zoom/computer audio).
4. **Students were told recordings are for the private community** (09-13). Publishing class
   recordings is a new purpose that needs new consent.
5. **YouTube**: uploads now have their own quota bucket (100/day); quota is not the constraint.
   Whether unaudited API projects are forced private is contradicted in Google's own docs. Test &
   Compare (3 thumbnails) has **no API**: Studio desktop only. Channel Managers cannot authorize
   API apps; **the channel owner must do a one-time Google consent**. Archive talks are *already
   on YouTube*: publishing one can be a metadata + visibility change, not a new upload.
6. **RedCircle and Spotify have no upload API.** The only fully hands-off podcast path is a feed
   Prakriti hosts itself (or Transistor, which has an API and private feeds).
7. **ElevenLabs Professional Voice Cloning clones only the account holder's own voice**, verified
   by them. Prakriti prepares clean, consented datasets; Gabriel and Serenity each train their own.
8. **Apple Podcasts requires AI disclosure** in the audio and metadata if an ElevenLabs voice is
   used. A real recorded intro avoids this entirely.
9. **Browser folder watching is impossible for this team** (Safari has no File System Access API;
   Chrome's observer needs an open tab), Workers cap requests at 100 MB and can't run ffmpeg or
   Apple's models. Measured on the M5 Pro: Apple SpeechAnalyzer ~97 to 206x real time, SoundAnalysis
   ~720x, Vision frame scoring ~41x. The whole archive transcribes in hours, free.
10. **Optimize Mac Storage is ON**: watched iCloud files can become placeholders at any time.
    OBS writes the file when recording *starts*; a new file is not a finished recording.
11. **R2 is not enabled** on Ivan's Cloudflare account. Ivan has a **paid Apple Developer
    membership but no Developer ID certificate** (needed before the engine runs on a second Mac).
12. **Gabriel paused new Yoga Marga enrollment in January 2026**; archive pieces will advertise
    closed offers. Talks contain spoken promises ("below this video...") and earnings claims.
13. GoHighLevel's Social Planner (already paid for) can post to YouTube and has an approval flow.
14. Serenity is active: she gave her email on 09-24, handed over channel and Skool access on
    10-01, and said *"We can meet after you have everything and Sunny has assessed it."*

## The decisions

**D1. Architecture: hybrid, one engine and one shared room.**
- **Prakriti Engine**: a small native macOS app (Swift, SwiftUI) on one Mac. A background watcher
  registered as a login item (SMAppService) that keeps running even if the menu bar icon is hidden;
  an optional menu bar menu for status. It watches folders (FSEvents with saved event IDs, iCloud
  download handling, readiness checks), does all heavy media work locally (Apple SpeechAnalyzer,
  FluidAudio speaker labels with teacher enrollment, SoundAnalysis, ShazamKit, Vision, AVFoundation,
  ffmpeg), sends native notifications on its Mac, and uploads finished lightweight outputs
  (audio, proxies, thumbnails, transcripts) to the cloud. Masters never leave the engine Mac / RAID.
- **Prakriti (the web app)** at `prakriti.therowan.studio`: Cloudflare Workers + D1 + R2, the
  Up Next template (invite-only Google sign-in + passkeys, sessions, encryption, strict headers).
  Where all three people review, approve, browse the library, set rules, and get Web Push
  notifications on their own Mac (Safari "Add to Dock") and iPhone (Home Screen). Nobody but the
  engine Mac installs anything.
- Claude (Anthropic API) does the editorial thinking (selection, cut decisions, titles, chapters,
  descriptions, scoring reasons, accuracy checklists). Apple's on-device model is too small (8K
  context) for a transcript.

**D2. Where the engine runs: OPEN (Ivan + Gabriel).** v1 runs on Ivan's MacBook Pro (works now,
pauses when the lid is closed, and the UI says so honestly). Recommendation: an always-on Mac
mini at the studio beside the RAID before the 72-hour promise is made. Code is identical.

**D3. The autonomy line.** Everything up to "ready for your yes" runs on its own with no input:
detect, wait until the file is complete, check, transcribe, label, score, cut, master, package,
notify. **Publishing waits for one human tap per piece**, by design: the standing rule, YouTube's
developer policy (express consent before upload) and Serenity's accuracy condition all require it.
The tap is made as small as possible: notification, one review screen, Approve. A per-content-type
"publish unless vetoed within 24 h" dial is a **later, explicit decision for Ivan**, only after a
run of clean approvals, and **never** for anything with voices other than consenting teachers.

**D4. Notifications.** Ivan's three moments are kept, the way Apple's guidelines allow: **one
notification per recording, updated in place** (same identifier), so three moments never become
three stacked banners. Detected: quiet alert ("New recording found"). Started: passive.
Ready for your yes: with sound. Plus two exceptions that get their own notification in the same
thread: Needs a decision, Couldn't finish (after automatic retries fail). Archive batch work sends
**one daily summary**, never per item. Files under 60 seconds are filed as tests, silently. A
silent or broken recording is a "Needs a decision" the same day (the 09-14 lesson). Ivan's engine
Mac gets native notifications; everyone gets Web Push with per-person preferences (default for
Gabriel and Serenity: Ready for your yes, Needs a decision, Live, weekly note; they can opt into
all). Copy: title case with the date, full sentences, no app name, no "we", no em dashes, no
student names or quotes, no Publish button inside a notification.

**D5. Privacy by construction (Serenity's conditions, built in, not bolted on).**
- An unknown voice is treated as a student. Anything uncertain is cut, never guessed.
- Only consenting teachers are ever enrolled as known speakers; no student voiceprint is stored.
- A name scrubber mutes student names in audio and removes them from text and on-screen.
- Classes and anything with other voices are never published publicly without Serenity's rule
  and a per-piece privacy receipt she can approve in under a minute (voices, names, removals,
  disclosures on one screen).
- A consent registry per person, per channel, per use (podcast, YouTube, AI voice, knowledge base).
- Music check before anything is published (SoundAnalysis finds music, ShazamKit identifies it).
- Disclosure labels whenever a synthetic voice is used. A kill switch that pauses every outward
  action at once. Unpublish in one step. An audit log of every action.
- Upstream fix recommended to Gabriel: OBS multitrack recording, teacher on headphones.

**D6. Accuracy (Serenity's second condition).** Each piece carries a short accuracy checklist
(5 to 10 checkable claims) and a stale-truth check for archive pieces (old prices, closed offers,
"enroll now", earnings claims), plus a "Recorded in <month year>" label. A Yoga Marga lexicon
(Yoga Mārga, pranayama, Sanskrit terms, names) corrects transcripts.

**D7. The unit is a session, not a file.** Horizontal + vertical twins pair into one session (the
vertical twin gives native 9:16 shorts). Sub-60 s files are tests. Each session is routed to a
venture (Yoga Marga School, Yogi Sales Support, VeraSales, personal) because the studio is shared.

**D8. Quality score = plain verdicts, not numbers.** Per dimension (Audio, Video, Message):
Ready to post / Worth a look / Source only, each with factual reasons ("Silent for 62 minutes",
"Loud enough, two coughs at 12:04"). Never 73/100.

**D9. Podcast.** Podcast audio is the first lane. Mastered to -16 LUFS / -1 dBTP with compression
(the studio measures -21 to -36 LUFS; normalization alone is not enough). **Hosting: OPEN
(Gabriel).** Recommendation: Prakriti hosts the feed itself (R2, on a domain Yoga Marga owns), so
approve-to-live is truly one tap and full classes can go to a private students-only feed; the
existing RedCircle show can redirect to it. Alternative: Transistor (API, private feeds). RedCircle
stays manual. **Intro/outro: recommend a real recorded intro** by Gabriel or Serenity in the studio
(no AI disclosure needed, no consent question); ElevenLabs only if they choose it, with disclosure.

**D10. YouTube.** The channel owner connects the channel once (Google consent). Prakriti uploads
private, a person approves, Prakriti schedules or sets public. For archive talks already on
YouTube, publishing is a new title, description, chapters, thumbnail and visibility on the existing
video (fastest path to the 25-by-6-Nov target); re-upload only when the edit materially improves
it. Three thumbnails are prepared; Prakriti sets the first choice; Test & Compare is a 30-second
manual Studio step, offered as a checklist, only where the channel is eligible. Auto-dubbing stays
off until consent covers it.

**D11. Archive.** Re-run the Takeout from the channel owner's account (Takeout is an owner action)
onto the RAID or an external drive (Ivan's Mac has ~805 GB free, the archive at original quality is
1 to 2.7 TB). Then: dedupe by audio fingerprint, skip tests, classify (talk / class / coaching call /
guest / practicum), quarantine private 1:1 coaching calls (never processed for publishing), music
scan, transcribe, triage with Claude Haiku, score, shortlist. Talks by Gabriel or Serenity with no
other voices are the first candidates.

**D12. Later lanes, switched on one at a time, each gated.** Edited video + thumbnails + chapters +
captions (studio sessions) → shorts from the vertical twin → the Library (per-teacher knowledge
base, "ask the archive" that answers only with the teacher's own words and a timecode, consented
teachers only) → voice datasets (clean single-speaker audio prepared for each teacher to train on
their own ElevenLabs account; Serenity's locked until she says yes) → Spanish (captions, YouTube
auto-dub only with consent) → the business loop (a call to action per content type, tracked links,
GoHighLevel). Every lane has an owner action and an exit check before the next switches on.

**D13. Autonomy you can trust.** Heartbeat from the engine (the web app shows "Watching on <Mac>,
last seen 2 min ago" and alerts when it goes quiet), a nightly sweeper for anything stuck or
missing, a dated log line for every run including "found nothing", a cost meter with a monthly cap,
automatic retries for transient failures only, and coverage checks after every filter stage (the
VAD lesson: compare duration out to duration in).

**D14. Sign-in.** Invite-only. Google sign-in plus passkeys (Up Next's mechanics), "Last used"
remembered. No sign-up, no pricing on the page. **v1 (today) has no app behind the sign-in yet**:
the card is real in design but states plainly that sign-in opens with the first lane and invites
come from Ivan. Never a form that pretends to work.

**D15. The page is the product's front door.** `prakriti.therowan.studio/` is the features page and
the sign-in page in one, for Gabriel and Serenity first. `/roadmap` is the plain-language roadmap
for them (what is being built, in what order, what is needed from whom). Both noindex, robots
disallow, no money, nothing about students or internal debates beyond product principles.

**D16. Money.** Prakriti is its own project to be scoped and priced (proposed on the 10-07 roadmap,
which Gabriel has). Run costs are small and are stated in PLAN.md (Claude cents per recording,
R2 dollars per month, optional Auphonic/Transistor/Mac mini). **Ivan's fee is never on the public
site.** PLAN.md carries a gate: Prakriti is priced before the second lane switches on.

## Phases and anchor dates (writers refine; all dates 2026)

- **Phase 0, Ground (8 to 16 Oct):** features page live (today); owner actions (Takeout re-run,
  OBS multitrack + sound check, R2 enabled, Developer ID cert, channel owner consent, Serenity's
  privacy + consent answers, engine Mac and podcast host decided). Engine skeleton: watcher,
  readiness, sound check, notifications.
- **Phase 1, First light (to 23 Oct):** studio sessions flow end to end into the podcast lane:
  detect → check → transcribe → label → master → package → Ready for your yes → approve → live on
  the feed. Web app sign-in, Today screen, recording page, approve. First episode live.
- **Phase 2, The archive (to 6 Nov):** archive ingest, triage, scoring, shortlist; approved
  archive talks published (feed + YouTube metadata/visibility). **25 live by Friday 6 Nov.**
- **Phase 3, The studio package (Nov):** edited video, three thumbnails, chapters, captions,
  shorts from vertical. The 72-hour promise starts when the engine Mac is always-on.
- **Phase 4, The Library and voices (Dec onward):** knowledge bases, ask the archive, voice
  datasets with consent, Spanish.
- **Phase 5, Later:** autonomy dial, GoHighLevel and calls to action, analytics loop, Instagram.

## Design direction for the public pages

- Readers: Gabriel and Serenity. Job: understand what Prakriti is and how it works in one visit,
  and know where to sign in. Second job: trust (Serenity's conditions visible as product design).
- **Copy voice**: describe, never sell. No hype, no em dashes, no "we" overload, plain words, short
  sentences. Never promise what the process will break (e.g. never "fully automatic publishing").
- **Never skeuomorphic**: no drawn film strips, scrub bars, waveforms-as-decoration, grain,
  textures, drawn hardware or fake Mac window chrome. Abstract, typographic, precise.
- Avoid the stock AI looks (cream + serif + terracotta, near-black + acid green, purple gradients,
  Inter/Space Grotesk, emoji, everything centered, rounded cards everywhere).
- Type: UI text uses the system stack (SF on Apple devices) at 17px body, nothing under 12px;
  a display face from Google Fonts may carry the wordmark and headlines (never serve SF font files).
- Light and dark from the system setting, no toggle. Works at 390px with no sideways scroll.
- Show the real thing: a package preview beside the sign-in card (speaker-tagged transcript
  excerpt, plain verdicts, three thumbnail options, the episode as it would appear). Transcript
  words may come from **Gabriel's own studio talks only** (09-06 or 09-13, no students), two
  neutral sentences at most, no earnings claims. **No photographs or video frames of people in v1**;
  thumbnail options are typographic title cards.
- Security: Worker sets CSP (self + Google Fonts only), HSTS, frame-ancestors none, nosniff,
  Referrer-Policy, Permissions-Policy, `X-Robots-Tag: noindex`; robots.txt disallows everything,
  AI crawlers included. Static files in `web/public/` only.
