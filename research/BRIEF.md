# Prakriti — research brief (shared by every research and design agent)

Written 2026-10-08 by Sonny. Read this first, then `2026-10-07-call-gabriel-transcript.txt` in
this folder for the latest direction.

## What Prakriti is

The content engine Ivan Lizarde is scoping for **Gabriel Galindo** and **Serenity Todesco**, who
run **Yoga Marga** (a yoga teacher-training school; Yoga Marga School). Named 2026-10-08:
*prakriti* is the yoga-philosophy word for primordial matter, the raw material every form is
composed from. Ivan's brief: like the *Star Trek: Voyager* replicator, but it does not rebuild
from a catalogue of finished products; it takes raw elemental material and **recomposes it into
something new**.

Raw material in:
- **The archive**: about 900 recordings (Gabriel's number) of past classes, talks and sessions,
  sitting on **unlisted YouTube**. No transcripts of them exist on Ivan's Mac despite the call
  assuming so.
- **The studio**: new OBS recordings (1080p) that save automatically into an iCloud shared folder
  owned by Ivan: `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /`
  (note the trailing space in the folder name). 12 recordings in dated subfolders since
  2026-09-06, each an `.mp4` with a `.txt` transcript (no timestamps). Content types seen:
  talking-head Yoga Marga School talks (~55 min), live yin classes with named students speaking,
  a 1:1 conversation, short tests.

Out, per recording (the package Ivan described on the 10-07 call, Gabriel called it "brilliant"):
podcast audio (with ElevenLabs intro / outro / short mid-roll), an edited video, three thumbnail
options (for YouTube A/B tests), a quality score (audio, video, message), a transcript tagged by
speaker as Markdown that feeds a per-person knowledge base (Gabriel's, Serenity's), and
speaker-isolated clean audio for training voice models (ElevenLabs). Plus long-form + shorts from
new studio recordings, and publishing to YouTube and a podcast host (RedCircle account exists).
Gabriel's addition: someone has to upload, and someone has to post.

Gabriel's goal in his words: *"get out of our own way, because for whatever reason we're
incapable of hitting post and share."* The current roadmap proposes a target of **25 archive
pieces live by Friday 6 Nov 2026, and every new studio recording live within 72 hours.**

Agreed sequencing: build the whole engine once, switch outputs on one at a time, **podcast audio
first** (fastest path to published). Classes (students speak) wait for Serenity's privacy answer.
Voice/avatar models wait for Serenity's explicit consent for hers.

## What Ivan asked for on 2026-10-08 (verbatim intent)

- An insanely clear and thorough roadmap before any coding.
- Include every feature Gabriel and Ivan have talked about; scope additional features nobody has
  thought of yet.
- Built for the web, hosted at **prakriti.therowan.studio**.
- A **features page that is also the login page**, like most SaaS products, so Gabriel and
  Serenity clearly understand what the product is and how it works.
- It must **watch folders and work autonomously** with no further input.
- **macOS notifications** when new raw material is detected, when processing starts, and when it
  completes.
- Survey the full library of Apple APIs; a local app is fine if it is better suited. Think about
  every resource available.
- A pass through Apple's Human Interface Guidelines. UI research on Mobbin. Research similar
  products: what's missing for us, what exists and how we could implement it.
- Three rounds of self-feedback, reasoned and implemented.

## People and constraints

- **Ivan**: brand strategist, non-engineer, high taste. Plain language, no jargon, give a
  recommendation not a menu. Copy voice: describe, never sell; never promise what the process will
  break. Never skeuomorphic (no drawn film strips, scrub bars, grain, textures). Interfaces for
  operating use SF Pro at 17px body, nothing under 12px; brand pages may carry their own type.
  Never em dashes in anything Gabriel or Serenity read.
- **Gabriel**: Ivan's partner on VeraSales (50/50), Yoga Marga co-founder, warm, product-minded,
  defers on architecture. Has an M2 Mac.
- **Serenity**: Yoga Marga co-founder and teacher. Her standing conditions (24 Sep call): privacy
  of students (their voices/names out of public content) and accuracy. Owes answers on how far the
  privacy rule goes and three YTT syllabi. Has not consented to an AI version of herself.
- Hardware: Ivan's M5 Pro MacBook Pro, 64 GB, macOS 27.2 (travels, so it is not always on). A RAID
  storage build at the studio was discussed. Studio Mac details unknown.
- Infra Ivan already runs: Cloudflare (Workers, D1, R2) in his own account, zone `therowan.studio`
  is there, with `upnext.therowan.studio` as a precedent subdomain app (`~/Code/up-next`: Google
  sign-in + passkeys, account-scoped store, encryption, screenshot and smoke scripts). VeraSales
  (`Gabriel Galindo/closer-app`) is the same stack. Resend for email. Anthropic API. ElevenLabs.
  ffmpeg and openai-whisper are installed; Ivan's own transcription app Hark is at
  `~/Code/transcribe-app`, and the `transcribe-audio` skill at `~/.claude/skills/transcribe-audio/`
  holds the hard-won transcription pipeline.
- Standing safety rules: nothing outward-facing (sending, publishing, posting) without a human yes
  until explicitly changed; never handle passwords; never invent facts or contact details; verify
  by rendering and looking, not by reading code; never `git add -A`.

## Rules for research agents

- **Read-only** outside your own output file. Do not send, post, publish, or change anything in any
  account. Reading iMessages/mail on this Mac is fine; never send.
- Cite sources (URL or file path) for every factual claim. Mark anything you could not verify as
  `[unverified]`. Today is 2026-10-08; your training data may be stale, so check current docs.
- Write your full findings to your assigned file in `~/Code/prakriti/research/`. Be thorough and
  specific; downstream agents will build the scope from your file alone.
