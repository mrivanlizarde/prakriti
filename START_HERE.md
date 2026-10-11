# START HERE: Prakriti

**What this is.** Prakriti is the content engine Ivan Lizarde is building for Gabriel Galindo and
Serenity, who run Yoga Marga, a yoga teacher-training school. It watches for raw recordings (new
studio sessions saved by OBS into a shared iCloud folder, and the 958-video archive on the school's
YouTube channel) and, with nobody touching it, checks them, transcribes them, keeps the consenting
teachers' voices, cuts any voice that is not clearly theirs, mutes the student names it finds,
describes the result in plain-word verdicts, and assembles a publishable package: a mastered podcast
episode first, then later edited video, three thumbnails, chapters, captions, shorts, a per-teacher
library and clean voice datasets. Then it stops: Ivan listens at the moments it is least sure about,
one named person says yes, and only then does it publish and confirm the piece is live. It is two parts: a
small native Mac app (the **engine**) that does the heavy work where the files live, and a private
web app at `prakriti.therowan.studio` (Cloudflare Worker, D1, R2) where the three of them review,
approve and get notified. The name is the yoga-philosophy word for the raw matter every form is made
from. On Thu 8 Oct 2026 it is named, researched, scoped, planned and through all three rounds of
self-feedback; the Worker (`web/src/index.js`) and the front door (`web/public`) are written and not
deployed (they go live through the pre-deploy sequence in PLAN.md row 21); nothing else is built yet.
**Since then:** the front door and roadmap went live the evening of Thu 8 Oct (see Deploy), and on
Sat 10 Oct Prakriti for Mac, the native engine, was built, took over from engine v0 and reached its
v1 finish line (see "Prakriti for Mac" and the end of `docs/BUILD-LOG.md`).

**Current state, matching PLAN.md:**

- The first episode, Gabriel's Sun 6 Sep talk, approved in two versions, is planned for Fri 23 Oct on
  a new Yoga Marga show at its own address, in a new Yoga Marga Cloudflare account.
- **Ivan publishes every episode through Fri 6 Nov,** by hand for episode 1 and then with his release
  script; Prakriti's own release slots switch on after Fri 6 Nov.
- Sign-in opens by Mon 26 Oct, with the invitations sent that morning. Notices come by email until
  after Fri 6 Nov.
- The proposed target is 25 archive talks as podcast episodes by Fri 6 Nov, which Ivan confirms with
  Gabriel on Fri 9 Oct. **YouTube for the archive is after Fri 6 Nov,** at most two a day.
- What is built by Fri 6 Nov, and what waits, is fixed by **the cut line** in PLAN.md, written Fri 9
  Oct.

**Read in this order, then stop.**

1. This file.
2. `PLAN.md`: the current state, this week, the phases, the gates, the open questions.
3. `docs/SCOPE.md`: what every feature is and why. Read §0.2 (the uncomfortable things) first.
4. `research/DECISIONS.md`: the decision spine. **It wins** wherever anything else disagrees.
5. `docs/FEEDBACK.md`: the record of the feedback rounds. Every critic's finding, the decision on
   it and its reason, and the spine corrections still waiting for Ivan. Read it before changing
   anything a round already settled.
6. Only the research files your task touches. SCOPE cites them by section ("07 §1.3").

---

## The people, and the two conditions that shape everything

- **Ivan**: builder and operator. Brand strategist, non-engineer, high taste. Plain language,
  a recommendation not a menu, terminal commands always with the `cd`.
- **Gabriel**: co-founder, product-minded; wants Yoga Marga visible without it becoming his job.
- **Serenity**: co-founder and teacher; most of the archive is her teaching. Her two standing
  conditions (Thu 24 Sep) are the spec: **student privacy** (students' voices and names out of
  public content) and **accuracy** (anything public must be right, including the year). She has
  not given written consent to any AI version of herself, so nothing speaks as her. She meets Ivan
  twice: in the week of Mon 12 Oct, and for 30 minutes on Tue 27 Oct.
- **Sonny** (the assistant writing this) **is Claude.** Until Serenity says yes to Q-S13, no Claude
  session, Sonny included, reads her teaching or any class (warning 29).
- **Students** are protected, never users. They were told recordings are for the private
  community; publishing them is a new purpose that needs new consent.

---

## Where everything is

### In this repository (`~/Code/prakriti`)

If something listed here does not exist yet, that work has not landed. Check `CHANGELOG.md`.

| Path | What it is | Notes |
|---|---|---|
| `START_HERE.md`, `README.md`, `PLAN.md`, `CHANGELOG.md` | The four project documents | README and PLAN may be read by Gabriel or Serenity: no em dashes, plain words |
| `research/BRIEF.md` | The brief every research agent worked from | |
| `research/DECISIONS.md` | Decisions D1 to D16 and the facts that changed the plan | The spine |
| `research/01` to `09` | The nine research tracks: conversations, Apple platform, Apple HIG, UI patterns, landscape, APIs, infrastructure, privacy and rights, new ideas | Evidence, cited everywhere. **Keep out of git** (warning 16): they name students and one student's family detail. Not yet in `.gitignore`; adding them is the first step of PLAN.md row 21 |
| `research/*transcript*` | Raw call transcripts | **Gitignored.** They hold people's words, including students' and private matters |
| `docs/SCOPE.md` | The full scope: 244 features, architecture, notifications, data, privacy, publishing, AI, failure modes, risks, open questions, verification plan | Internal: carries money and facts about students. Gabriel and Serenity read `/roadmap` instead |
| `docs/FEEDBACK.md` | The record of the self-feedback rounds: six critics, every finding, every decision and its reason | Internal |
| `web/wrangler.jsonc` | Worker deploy config | Account pinned; only `public/` served; custom domain is the only door |
| `web/src/` | The Worker (`index.js`): headers, CSP, routing, and later the app. Written Thu 8 Oct, not deployed | The Worker runs first for every path |
| `web/public/` | **The only folder served to the internet**: `index.html` (the front door), `roadmap.html`, `404.html`, `robots.txt`, `assets/`. Written Thu 8 Oct, not deployed | Anything placed here is public |
| `scripts/shoot.mjs` | Renders pages to PNGs in headless Chrome and reports console errors, failed loads and sideways overflow | The verification step for anything visual. Caps a full-page capture at 16,000px (warning 26) |
| `screens/` | Where screenshots land | Gitignored |
| `mac/` | **Prakriti for Mac**, the native app (SwiftUI, SwiftData). Milestones 1 to 6 landed Sat 10 Oct: window and menu bar, the pipeline in Swift, the watcher and notifications, outputs and settings, the recording page (trim, cuts, Make Again, Approve), and the writing models (titles, show notes and chapters by Qwen3.8-27B in LM Studio, checked against the transcript, with the privacy lock). **Since Sat 10 Oct it is the live engine**, installed in `~/Applications`, opening at login | Read "Prakriti for Mac" below, then `docs/BUILD-LOG.md` |
| `docs/BUILD-LOG.md` | One dated entry per milestone of the Mac app: what was built, every check with its measured result, decisions, and what Ivan must do | A new session resumes from its last entry |

Later, from the Up Next template: `migrations/`, `test/`, `scripts/smoke.mjs` (production refusals
tested as refusals), `scripts/backup.mjs`.

### Facts for the build

| Fact | Value | Status |
|---|---|---|
| Apple team ID | **LD587PB2H8** (07 l.509-511). K55TBYNKUC is the identifier of Ivan's Apple Development certificate; `research/02` l.751 calls it the team and is wrong | Measured |
| Bundle IDs | Prakriti for Mac is `studio.therowan.prakriti.app` (set by the v1 build prompt, signed since Sat 10 Oct), and it is also the login item (`SMAppService.mainApp`, registered by the copy in `~/Applications`, milestone 3). `studio.therowan.prakriti` was engine v0's LaunchAgent label, retired Sat 10 Oct | In use |
| D1 database | `prakriti`, in Ivan's account, with migrations in `web/migrations/` beside `web/wrangler.jsonc` (Up Next keeps `migrations/` beside its config) | **Proposed, for Ivan to confirm** |
| R2 access from `wrangler` | After R2 is enabled (Q-I2), run `cd ~/Code/prakriti/web && npx wrangler login` again, then check with `cd ~/Code/prakriti/web && npx wrangler r2 bucket list`. Reason: the current OAuth login shows no R2 scope (07 l.394) | To do, by Fri 16 Oct |
| The archive drive (Q-I17) | When the encrypted drive is first unlocked, tick "Remember this password in my keychain". Reason: without it the drive stays locked after a reboot, and the Phase 0 reboot check (nothing touched, every folder read) fails | To do, when the drive arrives |
| Time zone | Times are Pacific, America/Los_Angeles; US daylight time ends Sun 1 Nov 2026, inside the one-a-day release window | Measured with `date(1)` |

### Outside this repository

| Where | What | Rule |
|---|---|---|
| `~/Documents/Design Work/Galindo x Lizarde/Studio Recordings /` (note the **trailing space**) | The watched studio folder; OBS saves here; one dated subfolder per day | **Read-only to Prakriti.** It syncs to everyone in the share |
| `~/Downloads/SerenityAI/` | A partial Google Takeout of the channel, about 253 GB of an expected 388 GB, about 694 of 958 videos complete | Contains private 1:1 coaching calls. Quarantine: list them, never copy them out in the salvage, never process them. Deleting this copy is Serenity's call (Q-S23) |
| The archive drive (not attached yet) | An encrypted external SSD of about 2 TB, recommended for the salvage output and the re-run (Q-I17, Mon 12 Oct) | Without it, the re-run is extracted part by part, never into a watched folder (warnings 23, 24) |
| `~/Code/up-next` | Ivan's live app at `upnext.therowan.studio`; the template for sign-in, sessions, encryption, headers, evidence check, `shoot.mjs`, `smoke.mjs`, backups | Copy patterns, not Kristin's brand colors |
| `~/Code/transcribe-app` (Hark) | Apple SpeechAnalyzer plus FluidAudio; the engine's transcription core | Hark is ad-hoc signed; do not copy that |
| `~/.claude/skills/transcribe-audio/` | The hard-won transcription procedure, engines and coverage checks | Reuse its engines and checks |
| `~/Code/coffee-cup` | A working sign, notarize, staple, `spctl` pipeline | Waits on Ivan's Developer ID certificate |
| `~/Documents/Claude/Projects/Gabriel Galindo/closer-app` | VeraSales: the LLM call layer (streaming, thinking headroom), Workflows, Resend adapter, D1 backups | Same stack, Gabriel's account. Do not copy its `models.js` as is: it sends `{type:'disabled'}` thinking for Sonnet 5.5 (warning 34). Do copy the `retries` guard in `workflow.js` |
| Yoga Marga's new Cloudflare account (not created yet) | The podcast-only address as its own zone, the feed bucket and the feed Worker | Created at Ivan's studio visit, with Gabriel's yes to the address cost; Gabriel owner, Serenity and Ivan members. **Not** Gabriel's existing account, which runs VeraSales production (07 l.355). Its `account_id` is pinned in the feed Worker's own wrangler config |
| `~/Documents/Claude/Projects/The Rowan Studio/site/` | Design tokens and display face for the front door | Copy the tokens, **never** its asset root |
| The Sonny vault (`~/Documents/Claude/Projects/Sonny/Sonny/`) | The naming decision in `40 Decisions/` (dated 2026-10-08), the Yoga Marga project note, people notes, debriefs | Durable decisions go there as well as here |

---

## Engine v0: retired Sat 10 Oct (it ran Thu 8 to Sat 10 Oct)

The first slice of the engine, built the evening of 8 Oct so Prakriti could be used before the Swift
engine existed: `engine/prakriti.mjs` (Node, no dependencies), run by a LaunchAgent at login. It
watched the Studio Recordings folder and `~/Prakriti/Drop` and made episode 1 (the Sun 6 Sep talk)
and the 13 Sep talk into `~/Prakriti/Outputs/`. **Prakriti for Mac took over on Sat 10 Oct at
14:57** (milestone 3): the LaunchAgent was booted out and its plist moved to
`~/Prakriti/retired/studio.therowan.prakriti.plist`; v0's `~/Prakriti/state.json` and `log.txt`
stay where they are as history, and the app read state.json once so nothing v0 saw is made again.

The code stays in `engine/` because its comments hold the rules the app ported (readiness, the sound
check, the coverage check, and the two mastering bugs: the limiter must keep `level=disabled`, and
mono + sample rate stay **inside** the filter chain before it; either mistake put the peak over 0
dBFS on 8 Oct).

To go back to v0, **quit Prakriti first** (two watchers would make and notify everything twice):

```bash
cd ~ && mv ~/Prakriti/retired/studio.therowan.prakriti.plist ~/Library/LaunchAgents/ && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/studio.therowan.prakriti.plist
```

## Run the site locally and verify it

Reading the HTML is not verification. Render it and look at the pixels.

The screenshot script needs Node 22 and Google Chrome in `/Applications`. By default it reads the
static files straight from `web/public`, so no server is needed. Pass the file names that exist in
`web/public` (the front door is `index.html`; the roadmap page is the file served at `/roadmap`).

```bash
cd ~/Code/prakriti && node scripts/shoot.mjs --full --width 1440 /index.html /roadmap.html
cd ~/Code/prakriti && node scripts/shoot.mjs --full --width 1440 --dark /index.html /roadmap.html
cd ~/Code/prakriti && node scripts/shoot.mjs --full --width 768 /index.html /roadmap.html
cd ~/Code/prakriti && node scripts/shoot.mjs --full --width 390 /index.html /roadmap.html
cd ~/Code/prakriti && node scripts/shoot.mjs --full --width 390 --dark /index.html /roadmap.html
```

Then **open every PNG in `screens/` and look at it.** Each run also prints, per page, any console
error, failed load, or sideways overflow. "No horizontal overflow" at 390 px is required.

To check the Worker itself (headers, routing, the 404s), run it locally and point the script at it:

```bash
cd ~/Code/prakriti/web && npx wrangler dev
cd ~/Code/prakriti && node scripts/shoot.mjs --base http://127.0.0.1:8787 --full / /roadmap
```

Then, with `wrangler dev` still running, check the headers and the 404s locally. This is required
before the first deploy (warning 17). Expect `Content-Security-Policy`, `X-Content-Type-Options`,
`Referrer-Policy`, `Permissions-Policy` and `X-Robots-Tag`, and **no** `Strict-Transport-Security`
over plain http (warning 11):

```bash
cd ~/Code/prakriti && curl -sI http://127.0.0.1:8787/ | grep -iE '^(content-security-policy|strict-transport-security|x-content-type-options|referrer-policy|permissions-policy|x-robots-tag):'
```

Each of these must print `404`, and `/` and `/roadmap` must print `200`:

```bash
cd ~/Code/prakriti && for p in /.git/config /wrangler.jsonc /src/index.js /PLAN.md /no-such-page / /roadmap; do printf '%s ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:8787$p"; done
```

Use `127.0.0.1`, not `localhost` (reason in the warnings below).

Before anything goes live, check for em dashes. This must print nothing:

```bash
cd ~/Code/prakriti && grep -rn $'\xe2\x80\x94' web/public PLAN.md README.md
```

---

## Deploy

Deploying is outward-facing. **It waits for Ivan's yes, every time.** Approval once is not approval
forever.

**Before the first deploy:** follow PLAN.md row 21, in order: (1) the `.gitignore` edit, done by
Ivan's pre-deploy sequence, adding `research/0*.md`, `*.mp4`, `*.mov`, `*.mkv`, `*.wav`, `*.m4a` and
`*.mp3`, because the nine research files name students (warning 16); (2) Ivan's yes on the
screenshots; (3) `git status`, read in full, then, with Ivan's yes, a `git grep -i` for the known names
over the staged tree, then the first commit, staging files by name, never `git add -A` (warning 2);
(4) a private remote; (5) the `wrangler dev` checks (warning 17); (6) deploy; (7) the live checks;
(8) flip the roadmap status row "Front page and roadmap" to "Done, live since <date computed with
`date(1)`>". If any step misses, the Fri 9 Oct messages go without links; they never wait for it. A
project that ships before it has a remote tends never to get one (Sono Lino went live uncommitted). Done
Thu 8 Oct: private remote `mrivanlizarde/prakriti`, deployed and checked live the same evening.

**Every deploy:**

1. `cd ~/Code/prakriti && git status` and read it. Stage named files only.
2. Render and look (above). Run the em dash check (above).
3. Get Ivan's yes.
4. Deploy:

   ```bash
   cd ~/Code/prakriti/web && npx wrangler deploy
   ```

   The account is pinned in `wrangler.jsonc` (`563eb5c6ada343f86eddc6d77364bbbd`, Ivan's). Compare
   the "Uploaded N files" count wrangler prints with the files you actually changed. The first
   deploy creates the DNS record and certificate for `prakriti.therowan.studio` itself.

5. Check the live site. Headers first; expect a strict `Content-Security-Policy` (self and Google
   Fonts only, with `frame-ancestors 'none'`), `Strict-Transport-Security`,
   `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy` and
   `X-Robots-Tag: noindex`:

   ```bash
   cd ~/Code/prakriti && curl -sI https://prakriti.therowan.studio/ | grep -iE '^(content-security-policy|strict-transport-security|x-content-type-options|referrer-policy|permissions-policy|x-robots-tag):'
   ```

   Robots must disallow everything, AI crawlers included:

   ```bash
   cd ~/Code/prakriti && curl -s https://prakriti.therowan.studio/robots.txt
   ```

   Internal files must be unreachable, and junk paths must be real 404s, not the homepage. Each line
   must print `404`:

   ```bash
   cd ~/Code/prakriti && for p in /.git/config /wrangler.jsonc /src/index.js /PLAN.md /no-such-page; do printf '%s ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' "https://prakriti.therowan.studio$p"; done
   ```

   And the two real pages must print `200`:

   ```bash
   cd ~/Code/prakriti && for p in / /roadmap; do printf '%s ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' "https://prakriti.therowan.studio$p"; done
   ```

   Plain http must answer with a `301` to https (warning 25):

   ```bash
   cd ~/Code/prakriti && curl -sI http://prakriti.therowan.studio/ | head -3
   ```

6. Render the live pages too (`--base https://prakriti.therowan.studio`) and look. Check each page's
   height first: `scripts/shoot.mjs` caps a full-page capture at 16,000px (warning 26).
7. On the first deploy, flip the roadmap status row to "Done, live since <date>", the date computed
   with `date(1)`.
8. Write the deploy into the session's `CHANGELOG.md` entry.

Once there is an app behind the sign-in, `scripts/smoke.mjs` (adapted from Up Next) replaces most of
step 5: every gate driven with the thing it must refuse.

---

## Rules of engagement

- **Recall before you build.** PLAN.md for where things stand, SCOPE.md for what and why,
  DECISIONS.md for what is settled. Never re-ask Ivan something that is already written down.
- **DECISIONS.md wins** over the research files. SCOPE §0.3 lists every place they disagreed and
  what was done.
- **OPEN items belong to their owner.** Put them to that person as a question with a recommended
  answer. Never decide one quietly in code.
- **Nothing outward without a human yes:** deploying, publishing, sending, posting, inviting. Inside
  the product, publishing waits for one approval per piece, tied to a publication manifest (every
  file hash, every text field exactly as sent, the destination IDs); any change voids it.
- **Verify by looking, not by reading.** Render pages. Decode the tail of every media file. Read a
  publish back from the platform; Prakriti's own status row is not proof.
- **Docs change in the same commit as the code.** One `CHANGELOG.md` entry per session, and the
  *why* is the part worth writing.
- **Commits explain why**, and name the decision (D9) or risk (R-01) they come from.
- **One lane at a time.** Podcast audio first. Each lane has an exit check before the next one
  switches on.
- **Plain words on every page Gabriel or Serenity read.** Describe, never sell. Never promise what
  the process will break (for example, never "fully automatic publishing"). Never skeuomorphic: no
  drawn film strips, scrub bars, waveforms as decoration, grain or textures.
- **Interface type:** operating screens use the system font (SF on Apple devices) at 17 px body,
  nothing under 12 px. The front door may carry a display face from Google Fonts. Never serve SF
  font files.
- **Never invent a fact, number, name or contact detail.** If it is not in a source, write
  "unknown" or mark it OPEN.

---

## Load-bearing warnings

Each one states its reason, because a warning without a reason gets argued away.

1. **Serve assets only from `web/public/`.** Cloudflare serves everything under the assets
   directory to the open internet. `therowan.studio` used the repo root and served `.git` (the whole
   private repo, reconstructable) and later `CLAUDE.md`. After every deploy, `/.git/config` must
   return 404.

2. **Never `git add -A`.** Read `git status` first and stage files by name. This folder receives
   files from outside the session (research transcripts, screenshots, and soon media), and a blind
   `git add -A` once sent patient photographs to GitHub on another project.

3. **Research transcripts stay gitignored** (`research/*transcript*` in `.gitignore`). They hold
   people's own words, including students and private family matters. Never rename one so it escapes
   the pattern, and never force-add it. Media file types are **not yet** in `.gitignore` (SET-11);
   they are added in the first step of PLAN.md row 21, before any recording or audio file can land in
   the repo.

4. **No em dashes on any page Gabriel or Serenity read**: everything in `web/public`, PLAN.md,
   README.md, and every title, show note and description Prakriti generates. An em dash reads as
   machine-written, and it is Ivan's standing rule. Run the grep above before every deploy.

5. **Publishing always waits for a human yes.** It is the standing rule; YouTube's developer policy
   requires express consent before each upload or change; Serenity's accuracy condition requires a
   person to look; and a published podcast episode cannot be recalled once apps have downloaded it.
   No Approve or Publish button ever goes inside a notification.

6. **An unknown voice is a student.** Anything not confidently a consenting teacher is cut.
   Speaker separation already failed the dangerous way: on Sun 20 Sep a student's personal story was
   labeled as the teacher. Every studio file so far is one microphone duplicated into two channels,
   so labels alone cannot carry the privacy promise (see warning 14).

7. **Never store a student's voiceprint.** Only consenting teachers are enrolled, with their written
   yes. Embeddings of unknown voices live in memory for one job only, are never written to disk, and
   are never compared across recordings. Voiceprints are biometric data under Illinois and Colorado
   law, and live lawsuits target exactly "recognize the same person later" (08 §3.4).

8. **Compute every weekday with `date(1)`**, for example
   `date -j -f %Y-%m-%d 2026-10-23 +%A`. Never recall one. Five wrong weekday labels once shipped in a
   care file and a sent recap, and people plan their days around the weekday.

9. **Keep `account_id` pinned in `wrangler.jsonc`.** Wrangler on this Mac is logged in to six
   Cloudflare accounts, including Gabriel's. Without the pin a deploy can land in someone else's.

10. **Keep `not_found_handling: "none"`, `workers_dev: false` and `preview_urls: false`.** Single-page
    handling answers junk URLs with the homepage and a 200 (a soft 404 that gets indexed); a
    workers.dev or preview URL would be a second, unguarded door.

11. **Send HSTS only over https.** From a plain-http local server it teaches the browser to refuse
    `localhost` for every later preview (this happened on another project). Use `127.0.0.1` locally.

12. **Never write into the shared studio folder.** It syncs to every participant and spends Ivan's
    iCloud space. The 10-07 transcripts with students' personal details are already there and are
    being moved out (SET-10).

13. **Never process the private coaching calls** in the archive or the partial download. They are
    quarantined: excluded at inventory before any audio step (the Private Meetings playlist,
    anything marked private, anything titled as a meeting room), never copied in the salvage, never
    transcribed, never sent to any model. A call found later stops there and its transcript is
    deleted. Not Prakriti's to decide (PR-24).

14. **Never promise speaker separation as a guarantee.** On Sun 20 Sep a student's story was
    labeled as the teacher, and nothing noticed. On one microphone, software can mistake a student
    for a teacher without knowing it. The promise is the check: speaker verification in short
    windows, the post-render check on every exact MP3, and Ivan listening at the queued moments of
    every archive piece before it reaches its approver, logged with who and when. Copy that says "never guesses" or "always muted" is a promise the
    process will break.

15. **OBS records Hybrid MP4, never MKV.** Apple's frameworks (AVFoundation, SpeechAnalyzer,
    SoundAnalysis, Vision) cannot open Matroska, so an MKV recording would stall the whole pipeline.
    And a fragmented MP4 passes a naive "is there a `moov` box" check while it is still recording,
    so the readiness rule must be format-aware, with "finished" defined only from the committed
    fixtures (warning 20; SCOPE §7.3).

16. **Research files 01 to 09 and the call transcript stay out of git.** They name students and one
    student's family detail (07-infra l.26, 96, 101; 06-apis l.90; 01-conversations l.431, 436),
    and people's data has reached GitHub before (PR-19). The transcript is already ignored; the nine
    research files are not yet. **The `.gitignore` edit is the first step of PLAN.md row 21**
    (`research/0*.md` and the media types), because nine research files name students; then grep
    `BRIEF.md` and `DECISIONS.md` for student names, and run `git grep -i` for known names over the
    staged tree before the first commit.

17. **Before the first deploy, run the `wrangler dev` render and the curl checks of headers and
    404s against `127.0.0.1:8787`** (commands above). The `file://` render only draws the static
    files; it never exercises the Worker's CSP, headers or routing, so a broken header or a soft 404
    would first appear on the live site.

18. **No raw recording is ever uploaded to the cloud.** Not by the engine, not by a web page, not
    "temporarily". Other recordings, such as a phone recording, go into the shared Studio Recordings
    folder (Finder on a Mac, the Files app on an iPhone), which the engine already watches. Reason:
    raw recordings carry students' voices, and the front door promises they stay on the Mac (PR-12);
    the promise holds only if no upload path exists. The same goes for removed audio: "Prakriti never
    uploads a raw recording or any removed audio."

19. **Every cloud call runs after stage 15 (redaction).** Never send transcript text to Claude before
    names are tokenized and Other voice is removed, and make the cloud adapter check the data
    (`public_safe`, no Other-voice spans, no untokenized roster hits), not the order. Reason: stage 11
    (the lexicon) once ran before stages 14 and 15 and would have sent students' words and names to a
    vendor (round 2, finding E2). The lexicon is local now (SCOPE §7.4, §7.7).

20. **"Finished" for a Hybrid MP4 comes only from the committed fixtures,** never from "stopped
    growing". Reason: a partial Hybrid file opens and plays, so a truncated recording would reach
    "Ready for your yes". An unfinalized Hybrid file that stopped growing is a Needs a decision and
    never continues on its own (SCOPE §7.3; round 2, finding E3).

21. **The feed has one publisher:** Ivan's Worker (his release script until Fri 6 Nov), writing the
    episodes with `If-None-Match: *` and `feed.xml` with `If-Match` on its stored ETag into the bucket
    in Yoga Marga's new Cloudflare account, through a bucket-scoped token. Never bind or query D1
    across accounts. Reason: a Worker cannot, and the feed would come to depend on Ivan's account; the feed
    Worker in Yoga Marga's account reads only its own bucket (SCOPE §12.1; round 2, finding E4).

22. **Prakriti's YouTube code never contains a delete call** and writes only to video IDs listed in an
    approved publication manifest. Reason: the account holder's one-time grant allows deleting all 958
    videos, and the code is the only thing standing between that grant and the archive (PR-26; round
    2, finding S8).

23. **The Takeout re-run is never extracted into a watched folder.** Use the streaming extractor and
    its exclusion list; private items stay in the zip or go to a separate encrypted quarantine folder;
    no audio step runs before inventory classifies a file. Reason: a channel Takeout includes the
    private coaching calls (warning 13; round 2, finding S7).

24. **Keep a 100 GB free-space floor for archive work.** Below it, archive work pauses; studio work
    never does. Reason: the partial download, the salvage, the re-run zips and their extraction
    together nearly fill Ivan's Mac (about 811 GiB free on Thu 8 Oct), and a full disk stops the
    studio recordings too (SCOPE §7.1; round 2, findings E9, C5).

25. **The smoke checks include `curl -sI http://prakriti.therowan.studio/`, expecting a `301`** to
    https. Reason: round 2 found no http-to-https redirect (finding E15, measured on two live hosts),
    and Ivan's web security baseline requires HTTPS.

26. **`scripts/shoot.mjs` caps a full-page capture at 16,000px, so check the page's height first.**
    Reason: the roadmap was 17,020px tall at 1440 and 25,741px at 390, and the bottom of those PNGs
    was silently cut; anything below the cap needs separate viewport captures.

27. **Episode 1 is approved as two versions,** A with the passage that names Serenity and B without
    it, in one written yes from Gabriel ("A if Serenity says yes, otherwise B"). Reason: a passage cut
    after his yes would void it, and the cut file would skip its checks (round 3, findings G2, E2).
    Both versions get the post-render check and Ivan's listen.

28. **Nothing above the cut line slips without Ivan rebooking sessions or resetting the number.**
    Reason: the public dates, and the 25 Gabriel agrees to, rest on that line (PLAN.md, "The cut
    line"; round 3, findings E1, C3). If a session is lost, say so the same day and book another.

29. **No Claude session, Sonny included, reads Serenity's teaching or any class until Q-S13 is
    Granted.** No transcript, title or description of hers or of a class is opened in a session;
    Sonny sees only counts and categories printed by a script on the Mac, and the name seed list is
    built the same way. Reason: Sonny is Claude, so a session reading her transcripts is a cloud call
    on her teaching, which Q-S13 is hers to allow (round 3, finding S2).

30. **Timeouts count awake time,** and timers restart on wake. Reason: a sleeping laptop would
    otherwise park healthy jobs as Couldn't finish every time the lid closes (round 3, finding E8).

31. **A takedown voids approvals** (the "Taken down" state). Reason: otherwise the piece returns to
    Approved with valid approvals, and the next release slot republishes it (round 3, finding E5). The
    release script reads `takedowns.json` first and never removes a GUID it did not add.

32. **R2 multipart has no conditional put and no per-part checksum, so integrity is hashed in the
    Worker:** `head(key)` before `createMultipartUpload`, a random key suffix plus `v<n>`,
    `crypto.DigestStream` per part against the engine's declared SHA-256, and one whole-file pass after
    `complete()`. Reason: round 2's design relied on R2 features that are not there (round 3, finding
    E6).

33. **Never an approve link in an email.** Every email carries one "Open the Review Page" link per
    piece and nothing else that acts. Reason: mail scanners open links, and an approve link would
    approve unseen work (round 3, finding H3).

34. **No thinking setting on any Claude model; effort is the only control** (Haiku `low`, Sonnet
    `medium`, Opus `high`), and every Claude Workflow step carries `retries: {limit: 0, delay: '1
    second'}`. Reason: VeraSales' `models.js` sends `{type:'disabled'}` for Sonnet 5.5, which the
    round 3 critic read as a 400, and Workflows retry paid steps by default; a §19 live call per model
    verifies it before use (SCOPE §13.3; round 3, finding E10).

---

## Prakriti for Mac (`mac/`)

The native app that becomes Ivan's control room for Prakriti, built in six milestones from
`docs/NEXT-PROMPT.md`. **Milestone 1 (skeleton), Sat 10 Oct:** a signed SwiftUI app with a main
window (sidebar: Today, Recordings, Sources, Outputs, Models, Activity, Settings), a menu bar menu,
a SwiftData store, and tests that draw every screen to PNG. **Milestone 2 (the pipeline), Sat 10
Oct:** engine v0's `processFile` ported rule for rule into `mac/Prakriti/Engine`, run one recording
at a time by `PipelineRunner`; on the 13 Sep and 6 Sep talks its episode audio decodes bit for bit
the same as v0's. **Milestone 3 (the watcher and the switch-over), Sat 10 Oct:** FSEvents with saved
event ids plus a look through every folder every 5 minutes, per folder "Make outputs automatically"
or "Ask me first", three automatic tries, a heartbeat line in Activity for every look, Pause All,
one notice per recording updated in place, opening at login. **Then engine v0 was retired:** the app
read v0's state.json, took over the Studio Recordings folder and `~/Prakriti/Drop`, writes to
`~/Prakriti/Outputs`, and is the only thing watching. **Milestone 4 (outputs and settings), Sat 10
Oct:** every output's settings now change what is made: the loudness target, the silence trim, an
intro and outro, mono or stereo, the transcript's formats (.txt, .srt, .vtt, .md) and the Yoga Marga
word list; each folder chooses which outputs it makes, and each recording can have its own choices
and be made again. Titles, show notes and chapters wait for the writing model (milestone 6).
**Milestone 5 (the recording page), Sat 10 Oct:** each recording's page has Approve at the top, the
system audio player (AVKit's own, episode or original), the transcript as lines that play from their
moment and can be cut, where the episode starts and ends, sections to cut (from the lines or typed),
its title, notes and what it is, and Make Again with all of it. **Approve copies the finished files
to `~/Prakriti/Approved/<name>/` with a receipt; nothing is uploaded.** Only a recording marked as a
talk with one teacher speaking can be approved: a class, a conversation or one nobody has marked
shows "Speakers not checked" (speaker checks do not exist yet). Once anything is taken out of an
episode, its transcript files follow it: the cut words are gone and the times match the audio.
**Milestone 6 (the models), Sat 10 Oct:** titles, show notes, chapters and an accuracy checklist,
written by the model chosen for each task on the Models screen (LM Studio by default, with Qwen3.8-27B
loaded by Prakriti at 65,536 tokens; Apple on-device; Ollama; the Claude API with its key in the
Keychain), then checked in Swift: every chapter starts at a time that is one of the transcript's own
lines, and every quote is found word for word in `transcript.txt`, or it is left out and counted.
Tags and a short summary are their own tasks. **The privacy lock:** a recording marked as a class, or
whose transcript says "Serenity", is only read by models on this Mac; a task set to the Claude API is
done by LM Studio instead, and the page, the step and `show-notes.md` say so. The output is a draft in
`show-notes.md` (Approve copies it) and `titles-notes-chapters.json` (Outputs only). It is off for
every folder until Ivan turns it on, because the model holds about 33 GB and takes minutes.
**Finish line, Sat 10 Oct:** v1 passed on real recordings. What works, what does not, what Ivan must
click and the three things to try first are the last section of `docs/BUILD-LOG.md`, "Finish line".
Progress, checks and decisions per milestone are in `docs/BUILD-LOG.md`.

**Two copies, two jobs.** The live Prakriti is the copy in `~/Applications` (`make install` puts it
there); it watches the real folders and opens at login. Everything run from the build folder for
testing opens with `--development`: its own store, preferences, log, lock and `~/Prakriti/Dev`
folders, beside the live one.

### Day to day (for Ivan)

- **Open it.** It opens by itself when you log in and keeps watching with its window closed. To see
  the window, click the ring in the menu bar and choose Open Prakriti, or:

  ```bash
  cd ~ && open ~/Applications/Prakriti.app
  ```

- **Where things go.** Finished files: `~/Prakriti/Outputs/<recording name>/` (`episode.mp3`, the
  transcripts, `REPORT.md`, and `show-notes.md` when writing is on). Your yeses:
  `~/Prakriti/Approved/<recording name>/`, only when you press Approve. To have any file made, put it
  in `~/Prakriti/Drop`. Prakriti only reads the Studio Recordings folder and never writes into it.
  Every look and every step: `~/Library/Logs/Prakriti/<date>.log`, and the Activity screen.
- **Pause it.** Pause All (the window's toolbar, the menu bar, or Settings). A recording already
  running finishes; nothing new is found or started until Resume All.
- **Stop it.** Menu bar ring, Quit Prakriti (or Command-Q with the window in front). It stays stopped
  until you open it again or log in again. To stop it opening at login: System Settings, General,
  Login Items, switch Prakriti off. **If it crashes, nothing restarts it until the next login** (engine
  v0 restarted itself): Activity going quiet, no "Checked 2 folders" line for more than 5 minutes, is
  the sign.
- **Engine v0 is retired** (Sat 10 Oct, 14:57). Prakriti for Mac is the only thing watching. Never
  run both: two watchers make and notify everything twice. Going back: "Engine v0: retired" above.
- **What still needs you:** the checklist in `docs/BUILD-LOG.md`, "Finish line" (turning on
  notifications first).

### Build, run, test

Needs Xcode 27 and, only to change the project, `brew install xcodegen`. Every command runs from
`mac/`:

```bash
cd ~/Code/prakriti/mac && make build
```
```bash
cd ~/Code/prakriti/mac && make test
```
```bash
cd ~/Code/prakriti/mac && make snapshots MILESTONE=m1
```
```bash
cd ~/Code/prakriti/mac && make check
```
```bash
cd ~/Code/prakriti/mac && make run
```
```bash
cd ~/Code/prakriti/mac && make look MILESTONE=m1
```
```bash
cd ~/Code/prakriti/mac && make accept MILESTONE=m2
```
```bash
cd ~/Code/prakriti/mac && ./scripts/process-in-app.sh "$HOME/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4" ../screens/mac/m2/real
```
```bash
cd ~/Code/prakriti/mac && make accept-outputs MILESTONE=m4
```
```bash
cd ~/Code/prakriti/mac && make accept-edits MILESTONE=m5
```
```bash
cd ~/Code/prakriti/mac && make snapshots MILESTONE=m5 ONLY=recording
```
```bash
cd ~/Code/prakriti/mac && make accept-models MILESTONE=m6
```
```bash
cd ~/Code/prakriti/mac && make migrate-check
```
```bash
cd ~/Code/prakriti/mac && make install
```
```bash
cd ~/Code/prakriti/mac && make drop MODE=development MILESTONE=m3
```
```bash
cd ~/Code/prakriti/mac && make drop MODE=live MILESTONE=m3
```
```bash
tail -20 ~/Library/Logs/Prakriti/$(date +%Y-%m-%d).log
```

`make test` runs every unit test (data, rules, copy and type checks, and the snapshot render).
`make snapshots` writes every screen, light and dark, at the window's real size (1180 by 760) to
`screens/mac/<milestone>/` (gitignored), plus an `-end` picture for any page taller than the
window, and fails if the selected sidebar row's icon or label cannot be seen. `make look` opens
the **real** app on sample data (in memory, nothing saved) at each sidebar screen in light and
dark, captures the real window with `screencapture -l` into `screens/mac/<milestone>/real/`,
checks the selected sidebar row by its pixels, and checks that adding the Studio Recordings folder
is refused with an alert. It takes the screen's focus for about a minute: leave the Mac alone.
`make check` builds, tests, launches the app, lets it close its own window, proves it is still
running 15 seconds later, then runs `make look`'s capture. `make accept` is milestone 2's check on
**real recordings** through the app's own pipeline and runner (about 4 to 5 minutes): the 13 Sep talk
must come out between -17 and -15 LUFS with its true peak at or under -1.0 dBFS, a transcript
reaching within 120 s of the end and a REPORT.md; the silent 14 Sep class must be Needs a decision
with nothing made; the 30 s clip in `~/Prakriti/Dev/Drop` must be filed as a test; the 6 Sep talk
runs too. It writes to `~/Prakriti/Dev/Outputs`, draws Recordings, Today, Activity and each
recording's page from what was really measured into `screens/mac/<milestone>/`, and writes the
numbers to `acceptance.txt` there. `scripts/process-in-app.sh` checks the **real app**: it opens
Prakriti with Process File on one file (launch flag `--process-file=`), waits for the result in the
log, and captures the real window on Recordings and on that recording's page. `make install`
builds, quits the installed copy cleanly, replaces `~/Applications/Prakriti.app` whole and opens
it: **run it after every code change**, or the live watcher keeps running the old code. `make drop`
is milestone 3's check in the real app: it cuts a fresh 90 s clip from the 13 Sep talk into
`~/Prakriti/Dev/Clips`, moves it into the drop folder (development: `~/Prakriti/Dev/Drop` with a
`--development` copy; live: `~/Prakriti/Drop` with the installed copy), touches nothing else, and
passes when the log shows it found, made and Ready for your yes, with each notice and what macOS
did with it. After a live run, take the clip back out: quit, delete the clip and its folder in
`~/Prakriti/Outputs`, and open the app with `--forget=<the clip's path>`. `make accept-outputs` is
milestone 4's check on the **real 13 Sep talk** (about 3.5 minutes): made with the standard choices
(-16 LUFS), made again after the Outputs screen's loudness is changed to -19 (must measure within 1 LU
of -19 on two meters), made again with the transcript turned off on the recording's page (no
`transcript.*` file may be left), then made with the trim off at -16 (its decoded audio must equal
engine v0's episode bit for bit). It writes `acceptance-outputs.txt` and pictures of each state to
`screens/mac/<milestone>/`. `make migrate-check` copies the live store with `sqlite3 .backup` (the live
store is only read) and opens the copy with this build's models: **run it before `make install`
whenever a model changes.** `make accept-edits` is milestone 5's check on the **real 13 Sep talk**
(about 3 minutes): made with the standard choices, marked as a talk, the first 10 s trimmed and 5:00
to 5:30 cut on its page, made again, approved into `~/Prakriti/Dev/Approved`, the approved MP3
measured with ffprobe against the first episode (about 40 s shorter), the cut words checked gone from
the approved transcript and by transcribing the approved episode again, then marked as a class and
refused; it writes `acceptance-edits.txt` and pictures of each state. `make snapshots ONLY=recording`
draws only the recording pages, for a quick look. `make accept-models` is milestone 6's check on the
**real 13 Sep talk** with the **real models** (about 11 to 15 minutes, nearly all of it Qwen3.8-27B
thinking; it needs LM Studio's server running at the Models screen's address with the model
downloaded): writing is set to the Claude API on purpose, so the privacy lock must hand it to LM Studio
(the talk names Serenity; the Claude client in the test only counts and refuses, and must be asked 0
times); tags and summary go to Apple on-device; the model is unloaded first so Prakriti's own load at
65,536 tokens is exercised, and must be unloaded again after. It checks every chapter start against
the cue starts of `transcript.srt` and every quote against `transcript.txt`, has Apple on-device tag a
short input, tests each provider for real, and writes `acceptance-models.txt`, the model's own answer
(`model-answer.txt`) and pictures of the page and the Models screen. The real window on the sample recording page:
`open -n build/Build/Products/Debug/Prakriti.app --args --sample-data --show=recordings --open=ready
--appearance=light` (add `--sample-edits` for a trim and cut not made yet), then
`swift scripts/capture-window.swift --window build/Build/Products/Debug/Prakriti.app out.png`.
`--open=<path>` opens one recording's page in the real app. **Then open
every PNG and look at it,** including the `-p2`, `-p3` pictures of the screens between a long page's
top and its end. Reading the code is not verification, and neither is a passing test.

### Where things live

| What | Where |
|---|---|
| Project definition (source of truth) | `mac/project.yml`; `make generate` rebuilds `Prakriti.xcodeproj`, and both are committed |
| App code | `mac/Prakriti/App` (launch, paths, settings, log, `PipelineRunner`, `Watcher`, `Notices`, `LoginItem` with the instance lock, `EngineV0Import`), `Engine` (the pipeline: `Subprocess`, `Readiness`, `Measurements`, `Pipeline` with `Mastering`, `Report`; the watcher's `FolderScan` and `EventStream`), `Model` (vocabulary, SwiftData models, store), `Views`, `Fixtures` |
| Tests | `mac/PrakritiTests`: `ModelTests`, `RulesTests`, `NotificationTests` (the five notices and the copy rules), `WatcherTests` (the watcher end to end on generated files, FSEvents replay, the switch-over on v0's state.json), `PipelineTests` (rules on generated files, runs in `make test`), `PipelineAcceptanceTests` (real recordings, `make accept` only), `OutputsTests` (milestone 4: the word list on planted mis-hearings and through Parakeet with the Mac's own voice, the trim, intro, outro and stereo measured, a remake with the transcript off, a stopped remake), `OutputsAcceptanceTests` (the 13 Sep talk, `make accept-outputs` only), `RecordingPageTests` (milestone 5: edits, the episode's clock, typed times, the cut's words gone through Parakeet with the Mac's voice, six sentences of Parakeet's real misplaced tokens, what the report names, the page's player, Approve and its refusals), `EditsAcceptanceTests` (the 13 Sep talk trimmed, cut, made again and approved, `make accept-edits` only), `StoreMigrationTests` (`make migrate-check` only), `SnapshotTests`, and `SnapshotRenderer` (the drawing both snapshot kinds share) |
| Real-window capture | `mac/scripts/capture-window.swift` (run by `make look` and `make check`); also `--analyze <png>` to check any capture, and `--window <app> <png>` to capture the running app as it is |
| Real-app pipeline check | `mac/scripts/process-in-app.sh <file> <folder>` |
| The writing models (milestone 6) | `mac/Prakriti/Writing/`: `ModelClients.swift` (the request and reply, LM Studio with its load at 65,536 tokens, Ollama, the Claude API), `AppleOnDevice.swift` (Foundation Models, guided generation for tags and summaries), `Keychain.swift` (the Claude API key), `Writer.swift` (prompts, the privacy lock, tries, `WritingCheck`, `WrittenPackage` and `show-notes.md`); `App/ModelActions.swift` (test buttons, the key, Write Again, Use This Title); `Views/ModelsView.swift`, `Views/WritingSection.swift`; the pipeline step `.writing` and `PipelineRunner.write` (Write Again); tests `WritingTests` (in `make test`) and `ModelsAcceptanceTests` (`make accept-models`) |
| Written files | Beside the episode: `show-notes.md` (titles, notes, chapters, tags, summary, the checklist for review, what the checks changed, and placeholders for what is not chosen yet) and `titles-notes-chapters.json` (the checked package plus the model's own answer; never approved). On the recording: `writtenJSON` (the package without the raw answer) and `writingProblem` |
| The Claude API key | The login Keychain, generic password, service `studio.therowan.prakriti.app.claude-api`, account `api-key`. Tests use `studio.therowan.prakriti.app.tests.claude-api` |
| The recording page (milestone 5) | `mac/Prakriti/Views/RecordingPage.swift` (player, transcript lines, trim and cuts, title and notes, Approve), `App/RecordingActions.swift` (what its buttons do), `App/Approval.swift` (who may be approved, the copy and its receipt), `Engine/EpisodeEdits.swift` (the edits, the episode's clock, typed times, the transcript that follows the episode); tests `RecordingPageTests` (in `make test`) and `EditsAcceptanceTests` (`make accept-edits`) |
| Approved files, live | `~/Prakriti/Approved/<file name without extension>/`: `episode.mp3`, the transcript's chosen formats (following the episode), `REPORT.md`, and `APPROVAL.md` (title, notes, edits, every file's size and SHA-256). Never `transcript.json`. Development: `~/Prakriti/Dev/Approved/` |
| Outputs, development mode | `~/Prakriti/Dev/Outputs/<file name without extension>/`: `episode.mp3`, `transcript.txt/.srt/.vtt/.md` (the chosen formats, with the word list applied), `transcript.json` (Parakeet's words as heard, with their times; never changed), `REPORT.md` (engine v0's layout). A make in progress lives in the hidden `.making <name>` folder beside it |
| The Yoga Marga word list | `mac/Prakriti/Engine/Lexicon.swift` (each word as written, how it has been misheard, and what it is); shown on the Outputs screen |
| Output settings | Which outputs: each folder's switches (Sources), else the Outputs screen's (files added by hand). How: the Outputs screen. A recording's own choices (its page) override both: `OutputResolver` in `Model/Store.swift` |
| Test clips | `~/Prakriti/Dev/Drop/2026-09-13 clip 30s.mp4` (a test) and `~/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4` (a full run), cut with `ffmpeg -c copy` from the 13 Sep talk |
| The built app | `mac/build/Build/Products/Debug/Prakriti.app` (gitignored) |
| The live app | `~/Applications/Prakriti.app` (from `make install`), the login item |
| Store, live | `~/Library/Application Support/Prakriti/Prakriti.store`; the watcher lock beside it (`watcher.lock`) |
| Log, live | `~/Library/Logs/Prakriti/<date>.log`: every look, every step, every notice and what macOS did with it |
| Outputs and drop folder, live | `~/Prakriti/Outputs/<file name without extension>/`, `~/Prakriti/Drop` |
| Engine v0, retired | `engine/prakriti.mjs`; its plist in `~/Prakriti/retired/`; its `~/Prakriti/state.json` and `log.txt` kept as history |
| Store, development mode | `~/Library/Application Support/Prakriti/Development/Prakriti.store` |
| Log, development mode | `~/Library/Logs/Prakriti/Development/<date>.log`, one line per event |
| Working folders, development mode | `~/Prakriti/Dev/Drop`, `~/Prakriti/Dev/Outputs`, `~/Prakriti/Dev/Approved` |
| App icon | Drawn by `mac/scripts/make_icon.swift` from the front door's mark (an ultramarine dot on stone) |

### Load-bearing warnings for the Mac app

1. **`AppMode.switchedOver` is true since Sat 10 Oct: the app is live, and every test copy opens
   with `--development`.** A development copy uses only `~/Prakriti/Dev` and its own store,
   preferences, log and lock, and refuses, with an alert and an Activity line, any folder or file
   inside the Studio Recordings folder or inside `~/Prakriti` other than `~/Prakriti/Dev`, and any
   folder that holds one of them (`AppPaths.refusal`; tests in `ModelTests`; the real app is checked
   by `make look`). Every mode refuses the SerenityAI archive and watching Prakriti's own Outputs
   and Approved folders. Reason: the live copy owns the studio folder and `~/Prakriti/Drop`; a test
   copy watching them would make and notify every recording twice, and the folder holds classes.
2. **Automatic termination stays off** (`NSSupportsAutomaticTermination` false in Info.plist, and
   `disableAutomaticTermination` at launch). Reason: macOS quits a windowless app on its own, and
   the watcher must keep working with the window closed. `make check` proves it on every run.
3. **Signed with the Apple Development certificate, team LD587PB2H8, hardened runtime, no
   sandbox,** set in `project.yml`. Reason: macOS ties folder permission to the signature, and an
   ad-hoc build loses it silently (SCOPE 7.17). No sandbox because the app runs ffmpeg and Parakeet
   and reads Ivan's folders.
4. **A compiler warning fails the build** (`SWIFT_TREAT_WARNINGS_AS_ERRORS`). Reason: "builds
   clean" is a milestone gate, and an ignored warning becomes noise nobody reads. The one
   `appintentsmetadataprocessor ... warning` line in xcodebuild's output is the tool talking, not
   the compiler, and does not fail anything.
5. **Every font comes from `AppFont`** (17 pt body, nothing under 12 pt), and a test fails on any
   other font, any sidebar badge, any small control and any tooltip (`.help`). Reason: macOS text
   styles are 10 to 13 pt and tooltips draw at 11 (measured), and Ivan's floor is 12 with a 17 pt
   body. Name a control in its label instead; an alert's message (13 pt) is fine.
6. **No em dashes, no "Processing", no "we"** in any app string; a test reads the sources and fails
   on them. Reason: Ivan's standing rule, and SCOPE 8.3's copy rules.
7. **The snapshots compose the sidebar, and the real window is the judge.** Liquid Glass cannot be
   drawn into a bitmap (it comes out solid white), so the test draws the window, paints the sidebar
   column with the system window background, draws the same `Sidebar` view on top (focused and
   emphasized, its selection in the accent color, as the frontmost real window draws it), and
   redraws the title bar buttons. Layers macOS colors only on screen (vibrancy) are redrawn by
   hand. Switches and selected segments still draw grey (a test window is never truly frontmost;
   the knob's side shows the state: right is on). Reason: **never change the app to make a
   snapshot look right.** On 10 Oct the sidebar icons were tinted because the snapshot drew them
   grey, and that tint made the selected row's icon vanish in the real window while every snapshot
   looked fine. When a snapshot and the app disagree, run `make look` and believe the real window.
8. **No `foregroundStyle` on sidebar icons.** The sidebar colors its own icons, accent at rest and
   white on the selected row. Reason: an explicit `.tint` paints the selected row's icon in the
   selection's own color, so it disappears (10 Oct). `SnapshotTests` and `make look` both fail if
   it comes back; both were proved against the bug.
9. **Capture launch flags are one word each:** `--sample-data --show=<screen> --appearance=<light|dark>
   --add-folder=<path>`. Reason: a value given as its own word reads to macOS as a file to open,
   and then the app does not open its window. Setting `NSApp.appearance` before launch finishes
   does the same, so the capture uses `.preferredColorScheme`.
10. **Tests and captures never touch Ivan's data.** Under tests `AppModel.launch()` uses an
    in-memory store, throwaway preferences and no log file; under `--sample-data` it uses an
    in-memory store of the sample recordings and throwaway preferences, and writes only to the
    development log. Reason: a test or a
    capture must never write into the real store or `~/Prakriti`.
11. **SwiftData: every stored property has a default, and enums are stored as raw strings.**
    Reason: additions then migrate on their own, and predicates over raw strings are the reliable
    part of SwiftData. The first change that is not an addition brings a `VersionedSchema`.
12. **The mastering chain is engine v0's, checked string for string** (`Mastering`,
    `PipelineTests.testMasteringChainIsEngineV0s`; with the milestone 4 settings off, see 30). The limiter keeps `level=disabled`, and mono and
    the 48 kHz sample rate stay inside the filter chain before it. Reason: either mistake put the
    peak over 0 dBFS in v0's testing on 8 Oct (+2.2 dBFS, then over 0 again). The only addition is
    `print_format=json` on the second pass, so the report can say whether loudnorm stayed linear.
13. **Every tool is called by absolute path, and every child gets `/opt/homebrew/bin` first on its
    PATH** (`ToolPaths`, `Subprocess`). Reason: a login item starts with a bare PATH (the agency
    backup failed 66 nights on it), and Parakeet reads audio by calling `ffmpeg` by name.
14. **Every tool has a time limit (ten minutes plus the recording's length) and is stopped when
    Prakriti quits;** a recording left Working is marked Couldn't finish on the next launch with Try
    Again. Reason: one recording runs at a time, so a hung tool would otherwise hold every later
    recording forever, silently.
15. **The size must hold still 60 s in the app.** Only tests shorten it (`PipelineRunner.stableWait`).
    Reason: OBS creates the file when recording starts and writes it for the whole session; a
    shorter wait in the app would process a recording that is still being made.
16. **A test clip or a silent recording makes nothing:** no output folder at all. The tests check
    the folder does not exist, and `make accept` clears its own output folders first so an old run
    cannot hide a new mistake. Reason: v0's rule, and a silent file once went unnoticed for 24 days.
17. **The acceptance test is the only code that reads the Studio Recordings folder in development,**
    and only the three files it names (13 Sep talk, silent 14 Sep class, 6 Sep talk), read-only; it
    checks each original's size and date are unchanged afterwards. Everywhere else development mode
    refuses that folder (warning 1). Reason: the folder holds the classes, which may not be processed
    (student privacy), and the live Prakriti owns it.
18. **Never list a `-vertical.` rendition, and keep the folder listing engine v0's**
    (`FolderScan`: hidden names, three levels, v0's media types, no symbolic links). Reason: v0
    never listed the vertical files, so its state.json does not know them; with the rule removed
    on purpose, the switch-over test took in 13 recordings instead of 11, and the app would have
    made the two vertical renditions of 6 Sep on its first look.
19. **engine v0's state.json is read before the watcher's first look, once, and a failed read
    stops the watcher.** Reason: it is the only record of what v0 saw; without it the first look
    takes every studio file as new, including the classes of 16, 20 and 23 Sep, which may not be
    processed (student privacy).
20. **The first look at a folder lists what is there and starts nothing** (`Source.baselinedAt`);
    seeded folders count as looked at. Reason: v0's first-start rule, and a folder of 958 archive
    files added by hand must never start 958 runs.
21. **The live copy is `~/Applications/Prakriti.app`; run `make install` after every code change.**
    Reason: the login item records where the app lives, and a build rewrites the build folder in
    place (it replaced a running copy's files on 10 Oct). Without `make install` the live watcher
    keeps running old code while every test passes on the new.
22. **One watcher per mode (`InstanceLock`, `flock` on `watcher.lock`); test copies open with
    `open -n ... --args --development`.** Reason: a second live copy would find, make and notify
    everything twice. A lock dies with its process, so a crash never locks Prakriti out. Proved: a
    second live copy logged why and quit.
23. **A notice never carries a file name, a recording's title or a tool's error text** (only the
    date, lengths, the folder's name and fixed sentences; `NotificationTests` checks every variant).
    Reason: a dropped file can be named after a student, and notices show on lock screens and
    mirrored devices (SCOPE 8.1, PR-22).
24. **Folders are listed off the main thread, one thread each, with a time limit, and nothing on the
    main thread touches a path inside `~/Documents`** (the import compares paths only). Reason: the
    first read of a protected folder waits until someone answers macOS's prompt; on the main thread
    that freezes the app, and in one shared look it would stop the drop folder too.
25. **SIGTERM is Quit** (the app handles it). Reason: the install script and every check stop
    Prakriti with `pkill`; without the handler that kills it mid-run and skips the clean stop.
26. **Window captures and sample data log to the development log in every mode.** Reason: after the
    switch-over the captures ran in live mode and wrote 14 lines into Ivan's live log (10 Oct).
27. **Automatic work gets three tries at the regular looks; an interrupted automatic run restarts by
    itself and counts as a try.** Reason: v0's rule, a passing failure says nothing (SCOPE 8.7), and
    a file that stops Prakriti every time must end as Couldn't finish, not loop.
28. **A folder decides only WHETHER an output is made; HOW it is made comes from the Outputs screen,
    or from a recording's own settings** (`OutputResolver.choice` and `.details`). Reason: every folder
    holds a copy of every setting from the day it was added, and until 10 Oct that copy won, so a
    loudness changed on the Outputs screen silently never reached the studio folder's recordings.
    For the same reason the settings on the Outputs screen are never greyed out by its switches.
29. **A make happens in a hidden staging folder (`.making <name>`) and replaces the recording's files
    only when it has finished; only Prakriti's own file names (`Pipeline.madeNames`) are ever replaced
    or removed.** Reason: a remake that stops halfway must leave the last good episode as it was (a
    test stops one on purpose), a remake with the transcript off must leave no transcript behind
    (milestone 4's acceptance), and a note Ivan keeps in the folder must survive a remake (tested).
30. **With the trim, intro and outro off, the mastering chain is engine v0's, string for string, and
    `make accept-outputs` checks the 13 Sep episode's decoded audio equals v0's bit for bit.** Reason:
    episode 1 was made by v0; the settings must change nothing when they are off. The intro and outro
    are each brought to the talk's own loudness before the whole episode is leveled, inside one
    filter graph, with the layout and 48 kHz set before the limiter (v0's bug 2).
31. **`transcript.json` is Parakeet's words as heard and is never touched by the word list; the word
    list matches whole words only, and every fix is listed with its time in REPORT.md.** Reason:
    SCOPE 7.7 keeps the originals, and a wrong fix ("the yoga market" meant literally) must be
    findable. The list fixes only known variants; phonetic matching is not built.
32. **A switch for an output that cannot be made shows off and greyed, whatever is stored**
    (`OutputKind.isAvailable`, the four built outputs since milestone 6). Reason: the screen must never
    claim something is made that is not. Until milestone 6 this held titles, show notes and chapters
    off; they are now made, from the transcript only (warning 56 for why they start off).
33. **Run `make migrate-check` before `make install` whenever a model changes.** Reason: a store that
    fails to open falls back to a temporary one, and the live watcher would run with no memory of what
    it has made (it would make nothing new, but every recording and its numbers would vanish from the
    window). Every stored property keeps a default, so additions migrate on their own; the check
    proves it on a copy.
34. **Silence is trimmed only under -50 dB for at least a second, keeping half a second before the
    first sound and after the last.** Reason: measured 10 Oct, the studio talks open with 1.7 to 3.4 s
    of near-silence and run to their last second; a looser rule would clip words. Transcript times
    stay on the original recording's clock, and REPORT.md says how far the episode is shifted.

35. **Who may be approved is decided in `ApprovalCheck`, not by the button, and `AppModel.approve`
    checks it again whoever calls it.** Only a recording marked "Talk, one teacher speaking" can be
    approved; a class, a conversation or one marked "Not set" shows "Speakers not checked" and is
    refused (a test approves a class and a conversation and checks nothing was copied). Reason:
    speaker checks do not exist yet, an unknown voice counts as a student (SCOPE PR-2, PR-3), and every
    recording arrives "Not set".
36. **Approve waits while the trim or cuts on the page are not in the episode** (`Recording.editsPending`,
    comparing the page's edits with `madeTrimStart`, `madeTrimEnd`, `madeCuts` from the last finished
    make). Reason: a yes must cover exactly the file that was made, never an episode that still holds a
    section Ivan cut on screen.
37. **Approve never copies `transcript.json`,** and copies through a hidden `.approving <name>` folder,
    replacing only Prakriti's own names (`Approval.knownNames`). Reason: transcript.json keeps every
    word as heard, including the words of a cut; and a file Ivan keeps in the approved folder must
    survive approving again (tested). **`REPORT.md` is copied as it is, so it must be true in both
    folders:** its Transcript row lists only the readable formats, a "Words as heard" row says
    transcript.json is kept in Outputs only, and once the transcript follows the episode its word list
    table lists only the fixes in the files (a fix inside a cut is counted, never named). Reason: the
    verifier found the approved report listing transcript.json and a 5:20 fix from inside the 5:00 to
    5:30 cut (10 Oct); cut content must not reach the approved folder, not even a term.
38. **Any change to an approved recording takes the approval back** (`changedAfterApproval`: title,
    notes, what it is, trim, cuts, Make Again); the approved copy stays as it was until he approves
    again. Reason: SCOPE 9.1 #6, a yes is void once anything it covered changes.
39. **Once anything is taken out of an episode or added to it, the transcript files follow the
    episode** (step "Transcript matched to the episode", `EpisodeTranscript`): built from
    `transcript.json`'s word times, the words inside a cut or trim dropped, every time on the episode's
    clock. `transcript.json` keeps everything on the original's clock, and the page reads it. Reason:
    a cut is how a student's question or a name comes out of an episode, so the transcript that ships
    with it must lose those words too, and captions must line up with the audio. This replaces
    milestone 4's decision 9 (times on the original's clock), which left the captions 1.2 s late after
    the silence trim. With nothing removed or added (trim off, no intro), the files are Parakeet's own
    (with the word list applied), as before. A sentence kept whole is written as Parakeet's own
    sentence text; only a sentence a trim or cut goes through is built from its words (warning 45).
40. **A word's place is `min(middle, start + 0.15 s)`, a word is kept or dropped whole, and
    punctuation goes with the word before it** (`EpisodeTranscript.position`, `words`, `isWord`). A word
    is the token that starts with a space and the pieces and punctuation after it (" Jer", "se", "y",
    "."). Reason: measured 10 Oct, Parakeet stretches the last word before a pause across the pause
    and puts a sentence's full stop after it; by the middle, a line wholly inside a cut read "Partly
    cut", and a lone "." could have been kept after a cut. Part of a sentence never opens with a comma
    or full stop (`isClosingPunctuation`).
41. **Edits are seconds on the original recording's clock, and each make stores the episode's map**
    (`episodeParts`, `episodeIntro`, read as `Recording.episodeClock`). Reason: the transcript lines,
    "Use Player Time" and the Original player all speak the original's clock, and a line must play the
    episode from where its moment is now. A recording made before milestone 5 is read as one part (all
    of it, or what the silence trim kept).
42. **With edits, every kept part fades in and out over 15 ms and the parts are joined in one filter
    graph before the layout, the 48 kHz rate and the limiter; without edits the chain is milestone 4's
    string for string** (`Mastering.part`, `RecordingPageTests`). Reason: a cut through a word clicks
    without a fade, and v0's bug 2 (resampling after the limiter) must not come back through the join.
43. **The player is AVKit's own `AVPlayerView`, clipped to its pill; never a drawn scrubber or
    waveform.** Bitmap snapshots cannot draw it (it shows as a black or grey pill); the real window,
    `--open=ready`, is the judge. Reason: Ivan's never-skeuomorphic rule allows only the system's own
    media controls.
44. **The original is looked at off the main thread** before the player opens it. Reason: it lives in
    the studio folder inside `~/Documents` (warning 24); a first read there can wait on a macOS prompt.
45. **Parakeet's token list is not in the order the words were said: read `transcript.json` only
    through `EpisodeTranscript.sentences(json:)`, never by joining its tokens as listed.** Parakeet
    writes each sentence's text in the order it heard the words, then sorts the sentence's tokens by
    start time (parakeet_mlx `alignment.py`, `AlignedSentence`). Where its listening chunks meet
    (every 105 s) a few tokens carry a wrong, too-early time, most often a sentence's last full stop,
    so the sort moves them: 13 Sep 5 of 137 sentences, 6 Sep 21 of 555. Joined as listed they read
    ". But the problem was that again, we spent $100 for the venue" and "the You can always have
    access to Fathom". `sentences(json:)` puts the tokens back in the order the text spells
    (`spelling`) and times each misplaced one between its neighbours (`retimed`). Reason: milestone 5
    shipped those joins in every file that follows the episode, including after the default silence
    trim with no edits (8 captions of the 6 Sep .srt began with "." or "?"; engine v0's had none).
    `make accept` and `make accept-edits` now check every caption against Parakeet's sentence text.
46. **LM Studio is loaded by Prakriti at 65,536 tokens through its REST API (`POST /api/v1/models/load`
    with `context_length`), before the first request; a copy loaded smaller is unloaded and loaded
    again; and Prakriti unloads only what it loaded, when the writing step ends.** Reason: LM Studio's
    default is 8,192 tokens, and a chat request to a model that is not loaded makes LM Studio load it
    on demand at that default, which would cut a transcript off (docs/LOCAL-MODEL.md rule 1). The model
    holds about 33 GB, so it is not left loaded for nothing. The `lms` CLI cannot reach the server on
    port 1235; Prakriti uses HTTP only. Measured 10 Oct: the load takes 8 to 9 s.
47. **Every LM Studio request is one system and one user message, `max_tokens` at least 16,384,
    `reasoning_effort` "medium", temperature 0.7, top_p 0.8, top_k 20, presence_penalty 1.5, and no
    `response_format`; `finish_reason` "length" or empty content is a failure, tried again up to three
    times, never a result** (`LMStudioClient.body`, `.reply`; pinned by `WritingTests`). Reason:
    docs/LOCAL-MODEL.md rules 2 to 5. At the template's own effort the model spent about 48k tokens
    thinking; at medium it spent 4,580 and 7,117 on the 13 Sep talk.
48. **Nothing the model writes is trusted until `WritingCheck` passes it:** chapter starts must be one
    of the transcript's own line times (the brackets it was shown), quotes must be found word for word
    in `transcript.txt` or in the lines the model read (they differ only where engine v0's `.txt` lacks
    the word list's fixes; only whitespace and typographic quotes are evened out; case, spelling and
    punctuation count), and both are left out and counted otherwise; em and en dashes become commas;
    a chapter under 2 minutes, or one too many, joins the one before; JSON that is not JSON, fewer than
    three titles, too few chapters or no quote found is tried again. Reason: SCOPE 13's evidence check
    and LOCAL-MODEL.md rule 4; a model invents times and quotes.
49. **The writer reads the episode's cues (`EpisodeTranscript.cues` on the episode's clock, the words
    of every cut gone), never `transcript.json` as heard.** Reason: a chapter title or a quote must not
    name a student whose question was cut, and the times must match the audio (milestone 5's note).
50. **The privacy lock lives in `Writer.write` (`route`), the only way any task reaches a model:** a
    class, or a transcript that says "Serenity" (`Privacy.mentionsSerenity`, whole word, any case;
    `Recording.hasSerenity` is then set and never unset), turns a Claude API choice into LM Studio for
    every task, and the step line, the page and `show-notes.md` say so. Reason: SCOPE PRV-10, until
    Serenity's yes no Claude session reads her teaching or any class. Proved: the acceptance set writing
    to the Claude API on the 13 Sep talk and the Claude client was asked 0 times.
51. **The prompts keep private matters out:** titles, show notes, chapters, tags and summaries leave out
    illness, deaths, grief, family matters, money troubles and relationships, anyone's, the speaker's
    included; the checklist may hold the speaker's own income, health or result claims, because those
    must be checked. Reason: on 10 Oct the first run's show notes (Qwen) and summary (Apple) both
    repeated a private family matter the 13 Sep talk mentions; the second run, with this rule, had
    none. A prompt is not a guarantee: Ivan reads every draft.
52. **The Claude API key lives only in the Keychain (`KeyStore.claude`), is read only when a task is set
    to the Claude API, and is never written to a file, a preference, the store or a log.** Tests use
    `KeyStore.testing`. Reason: the build's rule, and a key in a file ends up in git.
53. **Approve copies `show-notes.md`, never `titles-notes-chapters.json`.** Reason: the JSON keeps the
    model's own answer, quotes that failed the check included; REPORT.md says the JSON stays in Outputs.
54. **A writing failure costs only its step:** the make is still Ready for your yes, with the reason in
    its status and the step; the written files of an earlier make are removed with the rest of that
    make's files (they described another transcript); Write Again tries once more and, if it fails,
    leaves the last written files as they were. Reason: LM Studio closed for a minute must not cost a
    40-second episode, and an old draft must never sit beside a new transcript it does not match.
55. **Apple on-device reads `SystemLanguageModel.default.contextSize` tokens (8,192 on macOS 27.2),
    counted with Apple's `tokenCount`:** a long transcript is read in parts for tags and summaries and
    refused for writing, with the reason. Catch macOS 27's `LanguageModelError`, not the deprecated
    `GenerationError` (a deprecation warning fails the build). Reason: the build asked to chunk or refuse
    beyond the limit, never to truncate.
56. **Titles, show notes and chapters start off for every folder, including the live studio folder**
    (`OutputKind.isOnByDefault`; `make migrate-check` asserts no folder has them on after an upgrade).
    Reason: the model holds about 33 GB and takes 10 to 15 minutes on a 16-minute talk; a new studio
    recording must not start that on its own.

## The engine's standing warnings (from SCOPE, for the parts still to come)

These came from the scope before `mac/` existed. Each applies from the milestone that builds the
part it names:

- **Sign every build with a stable certificate from the first one** (Ivan's Apple Development
  certificate on his Mac; Developer ID, notarized and stapled, anywhere else). macOS ties folder
  permission to the code signature; an ad-hoc build gets a new identity on every rebuild and
  silently loses the permission while System Settings still shows it ticked.
- **Call every tool by absolute path; keep secrets in the Keychain, never in a plist.** A launch
  agent does not get Homebrew's PATH: the nightly backup on this Mac failed 66 nights in a row with
  `npx ENOENT`, silently.
- **A new file is not a finished recording.** OBS creates the file when recording starts, iCloud
  delivers in pieces, and files can become placeholders at any time. Process only after the
  readiness rule passes (ENG-05, SCOPE §7.3): downloaded, size stable for 5 minutes with no FSEvents
  for the file, the format-aware index check ("finished" for Hybrid MP4 only from the committed
  fixtures; warning 20), duration agrees, last 5 seconds decode. Read through `NSFileCoordinator` and
  work from a `clonefile` copy.
- **The engine is one nested app identity** (SCOPE §7.2): not sandboxed, hardened runtime, one
  `LSUIElement` app in `Contents/Library/LoginItems/` launched by `SMAppService.agent` from a written
  plist with `KeepAlive` set to `{ SuccessfulExit = false }`, owning the watcher, the pipeline,
  notifications and the menu bar, and raising every permission prompt itself at setup. Reason:
  notification permission and folder access belong to one signed identity; split them and one half
  silently loses its permission. And a plain `KeepAlive` would make Quit do nothing. **Milestone 3
  used `SMAppService.mainApp` instead** (the build prompt's choice: one app, one identity): it opens
  at login, but **nothing restarts it after a crash** until the next login. The nested agent with
  `KeepAlive = { SuccessfulExit = false }` is still the way to close that gap.
- **The engine talks to the Worker only through the contract in SCOPE §6.4.** Its token works only on
  `/engine/*`, and it can never publish: the Worker opens every upload session and the engine only
  receives the session address. Claude's results come back through `/engine/editorial`, and every
  request carries `X-Prakriti-Protocol`.
- **Every job has a timeout and a crash-loop guard, counted in awake time** (SCOPE §7.2; warning 30).
  Reason: D13 promises autonomy you can trust, and a corrupt file must park as Couldn't finish, not
  loop.
- **Notification permission is alert and sound only,** never provisional and never badge, because the
  engine has no Dock icon. A click opens the review address carried in `userInfo` with `NSWorkspace`
  (SCOPE §8.5); check it by clicking one notice on the engine Mac.
- **Events go through a local outbox** in the same SQLite transaction as the change they report, with
  a sequence per (engine, token epoch) (SCOPE §6.4). Reason: one lost event once froze the sequence for
  good (round 3, finding E7).
- **No voice-activity gate and no denoiser before transcription.** A gate once dropped 80% of a
  tape with no warning. Yin classes are 31 to 41% intentional silence.
- **Every filter reports what it kept against what it was given** (the coverage check), and every
  produced media file has its tail decoded.
- **Masters never leave the Mac or the RAID.** Only redacted, teacher-only outputs go to the cloud.
- **Importing never starts paid work.** Adding 958 archive items must not fire 958 paid AI runs.
- **AI calls always stream, with a 9-minute timeout and 40,000 tokens of thinking headroom.** Never
  `stream: false`: it caused two silent 10-minute hangs, and the silence is the symptom. Opus 5.5
  always thinks; when VeraSales switched to it, 12 of 26 runs came back truncated.

How to prove each engine part works (the silent Mon 14 Sep class, the 09-20 call, the 10-file
hand-checked sample for calibration, the Hybrid MP4 fixtures, a deliberately corrupt file) is in
SCOPE §19.
