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
v1 finish line (see "Prakriti for Mac" and the end of `docs/BUILD-LOG.md`). That night it gained the
podcast-ready episode, and on Sun 11 Oct its episode text (title and alternatives, one-line summary,
show notes with chapters, keywords, a caption and pull quote per platform) and the recording page's
Ready to upload section with a Copy button for each.

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
| `mac/` | **Prakriti for Mac**, the native app (SwiftUI, SwiftData). The podcast-ready episode followed v1 on Sat 10 Oct. Milestones 1 to 6 landed Sat 10 Oct: window and menu bar, the pipeline in Swift, the watcher and notifications, outputs and settings, the recording page (trim, cuts, Make Again, Approve), and the writing models (titles, show notes and chapters by Qwen3.8-27B in LM Studio, checked against the transcript, with the privacy lock). **Since Sat 10 Oct it is the live engine**, installed in `~/Applications`, opening at login | Read "Prakriti for Mac" below, then `docs/BUILD-LOG.md` |
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

15. **OBS records Hybrid MOV or Hybrid MP4, never MKV.** OBS 32 records Hybrid MOV on a Mac by default,
    and since v2 part M4b (Mon 12 Oct) Prakriti accepts it everywhere it accepts Hybrid MP4 (the watcher, the
    readiness check, the capture check and the Viewer, tested on a fragmented MOV in `CaptureCheckTests`); the
    capture check names an MKV file with the tip to switch. Apple's frameworks (AVFoundation, SpeechAnalyzer,
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
Tags and a short summary are their own tasks. **The privacy lock (v2 part M5a, `PrivacyLock`, Mon 12
Oct):** a cloud model reads only a talk whose people check ran, with nobody unnamed seen or heard and
everyone heard named and agreed to cloud models (`Person.mayReadInCloud`, off by default), and whose
transcript does not say "Serenity". The people check is part M6, so **today every real recording is
locked** ("Who appears and speaks in it has not been checked"); a task set to the Claude API is done by
LM Studio instead, and the page, the step and `show-notes.md` say so. Every cloud request is a
`CloudPayload` made only by `PrivacyLock.release`: names replaced by `[[NAME-n]]` tokens and put back in the
answer, then the text read again and refused if a name is left. Settings, Models shows the hardware
check ("Apple M5 Pro, 64 GB. This Mac can run the writing model."). The output is a draft in
`show-notes.md` (Approve copies it) and `titles-notes-chapters.json` (Outputs only). It is off for
every folder until Ivan turns it on, because the model holds about 33 GB and takes minutes.
**Finish line, Sat 10 Oct:** v1 passed on real recordings. What works, what does not, what Ivan must
click and the three things to try first are the last section of `docs/BUILD-LOG.md`, "Finish line".
Progress, checks and decisions per milestone are in `docs/BUILD-LOG.md`.
**Podcast-ready episode, Sat 10 Oct (after v1):** a new output, separate from the quick "Podcast
episode" draft, that makes the file Ivan can upload to a podcast host as it is. Its own mastering
chain (a 70 Hz high-pass, a gentle 1.5:1 compressor, the whole episode raised evenly to -16 LUFS,
peaks limited to -1 dBTP or under, 44.1 kHz, mono 96 kbps) keeps loudnorm linear where engine v0's
fell back to riding the level, and lowers episode 1's loudness range from 5.2 to 4.7 LU. **It does not
measurably end the second-to-second riding** (the independent check, Sun 11 Oct: 92 s of 2 dB jumps
against v0's 104 on episode 1, 66 against 58 on 13 Sep, and the pauses about 2.5 to 3 dB louder
against the voice); Ivan's ears decide, see "Podcast-ready episode: the handoff". Prakriti writes the ID3v2.4 tag itself (title, author, show, year, comment, genre
Podcast, episode number, artwork, chapters); captions (.srt, .vtt) are timed to the finished file;
`Episode text.txt` (and the same as `Episode text.md`) holds the words that go with it (below);
`Upload checklist.txt` measures the file against Apple's published rules, line by line, PASS,
MISSING or FAIL. All in `<Outputs>/<recording>/Podcast-ready/`; Approve copies the
folder. Show name, host and artwork are MISSING until Ivan sets them on the Outputs screen: Prakriti
never invents them. Off for every folder until turned on. See `docs/BUILD-LOG.md`, "Podcast-ready
episode".
**Episode text and Ready to upload, Sun 11 Oct:** `Episode text.txt` and `.md` in the Podcast-ready
folder: the episode title (Ivan's, else the writer's first pick) and three alternatives, a one-line
summary under 160 characters, show notes in 2 to 4 short paragraphs followed by the chapters at their
times in the finished MP3 and Ivan's call to action (Outputs screen; none unless he types one),
keywords, and a caption each for Instagram (up to five hashtags), LinkedIn and X and Threads (under 280
characters), each with a one-sentence pull quote found word for word inside one line of the transcript
or left out. Written in the same single request as the titles and notes, by the chosen model (on this
Mac under the privacy lock), then read by Swift: Ivan's copy rules are enforced by `CopyRules` (no
prices, money, earnings, enrollment or offers; a caption, pull quote, title or keyword that names one
is left out, a sentence of drafted notes is taken out, and each is said). The recording page's **Ready
to upload** section lists the files, the whole checklist with PASS, MISSING or FAIL as words, and a
Copy button for the title, one-line summary, show notes and each caption and pull quote, with Show in
Finder. **A class is never made ready:** the pipeline refuses both podcast-ready steps for it, Update
Podcast-Ready Files refuses it, and the page says why. Numbering (not numbered, episode numbers, or
seasons and episode numbers) is on the Outputs screen. See `docs/BUILD-LOG.md`, "Episode text and Ready
to upload".
**v2 begins, part M0 (baseline), Sun 11 Oct:** the v2 build (`docs/v2/PLAN.md`, 31 parts) starts from
v1 with the podcast-ready episode, checked again, and a test suite that never reads a class. `make
fixtures` builds the shared test files every v2 check uses, from the two talks and `say`; `make accept`
uses `silent-60s.mp4` where it read the silent 14 Sep class; `make regress` runs the regression set. No
app code changed. See `docs/BUILD-LOG.md`, "v2 part M0".
**v2 part M1 (the new icons), Sun 11 Oct:** the Dock and Finder show "Recomposed", the brand's
ultramarine dot cut across its middle with the halves set apart (`docs/v2/icons/README.md`), from an
Icon Composer document with default, dark, clear and tinted looks. The menu bar shows the same cut disc
as a black-and-clear template glyph, one shape per state: the mark when idle, the halves lit in turn
every 0.7 s while working (held still with Reduce Motion on), a dot when something waits, an
exclamation mark for a problem, an outline when paused, a dashed outline when not watching. v1's
drawn dot (`make_icon.swift`) and its icon set are gone. See `docs/BUILD-LOG.md`, "v2 part M1".
**v2 part M2a (Help), Sun 11 Oct:** Prakriti Help is in the app: Help, Prakriti Help (Command-?) opens a
window of the eleven articles by section, each drawn at 17 pt from its Markdown (Apple's swift-markdown
0.9.0, pinned), with Back and Forward, search as you type, Related links, and **Show Me** buttons that open
the screen an article describes. The Help menu's own search field lists the articles too, and Help, Show
Log in Finder shows today's log. **Help shows only what is built:** every block of an article that
describes a later part's feature (`:::requires video` and so on) is hidden until that part switches its
capability on, and a test fails if a feature name of an unbuilt part is visible. The articles moved from
`docs/v2/help/` to `mac/Prakriti/Resources/Help/`, their builder notes to `docs/v2/help-notes/`, and each
was rewritten to describe v1 with the podcast-ready episode as it is today. See `docs/BUILD-LOG.md`, "v2
part M2a".
**v2 part M2b (the welcome window), Sun 11 Oct:** five panels open once by itself, in front of the main
window, at the first launch made by hand, and again from Help, Welcome to Prakriti: what Prakriti does, how
to record for the best results, how outputs work, privacy, and Get Started (choose a folder to watch,
notifications, where Help is). Like Help, every row names the parts it describes and shows only once they
are built, so today's welcome describes v1 with the podcast-ready episode; a later part's sentence is
written beside today's and replaces it in the commit that builds it. macOS is not asked about
notifications at that launch: the last panel asks after saying why, or, when notifications are off, opens
System Settings at Prakriti's own page. See `docs/BUILD-LOG.md`, "v2 part M2b".
**v2 part M3a (the main window and Settings), Sun 11 Oct:** the window is now built the way Photos and Final
Cut Pro are (`docs/v2/design-spec.md` 2 and 3). The sidebar is a Library of four groups, **Needs You** (waiting
for your yes, needs a decision, couldn't finish), **In Progress**, **Ready** (approved) and **All Recordings**,
each a SwiftData predicate over the stored status, with counts as plain text; under **Sources**, each watched
folder and Add Folder. The middle is a browser of recordings as a **grid** of cards (a neutral tile with the
day and the kind, the status in symbol and words, the length, the title and when it was recorded) or a
**list** (Command-1 and Command-2), in sections (Needs You by status, oldest first; months elsewhere), with a
Sort and Filter menu, and a **search** over titles, notes and what was said (a matching sentence opens the
recording there). On the right, the **inspector** (Command-Option-I) follows the selection: a recording's
**Outputs** (status, Make Outputs or Try Again, Approve and Make Again with v1's refusals, the files with Play
and Show in Finder, the writing and podcast-ready sections), **Checks** (what was measured, the accuracy
checklist with a box per claim, the privacy lock in words that name no one, the steps of the last make) and
**Info** (title, what it is, notes, where the episode starts and ends, the file); a folder's settings (v1's
Sources screen, for one folder). v1's Outputs and Models screens and its settings moved into a **Settings window**
(Command-comma: General, Outputs, Models, Privacy, Advanced); Activity is its own window (Window > Activity).
A card's menu adds **Remove from Library**: Prakriti forgets it and its Outputs folder goes to the Trash; the
original and Approved are untouched, and its folder never brings it back as new. "Ready for your yes" now
reads **"Waiting for your yes"** everywhere, notices included, so "Ready" means approved. Secondary text and
the dark accent were measured under 4.5 to 1 and replaced. See `docs/BUILD-LOG.md`, "v2 part M3a".
**v2 part M3b, the Viewer, Mon 12 Oct:** opening a recording (double-click, Return, Command-Down) replaces the
browser with the **Viewer**: the system player (AVKit's own, the only scrubber) on a canvas black in both
appearances, playing **Original** (picture and sound), **Podcast** or **Podcast-ready**, chosen in the toolbar
(Video and Shorts are in the control and say they are not made yet); Space plays or pauses, J, K and L
shuttle. Under it, **Timeline-lite** (what stays filled in the accent, what the trim and cuts take out outlined
with scissors, a line at the moment playing; click a piece to play from it and see it above the inspector's
tabs with Restore) and the **transcript** in paragraphs of words: click a word to play from it, **Follow
Playback** marks the sentence playing and keeps it in view, select words and **Remove from the Edit** or **Keep
in the Edit**, Find (Command-F). The trim, Use Player Time, the cuts with Restore and a typed cut are in the
inspector's Info; the per-recording output choices moved to Outputs. **Quick Help** (Help menu) explains the
control under the pointer at the top of the inspector. The window is put back at the next launch (group,
selection, open recording, rendition, moment, tab). **v1's recording page is retired** (`RecordingPage.swift`
and `RecordingsView.swift` deleted). See `docs/BUILD-LOG.md`, "v2 part M3b".
**v2 part M4a, progress and the Activity window, Mon 12 Oct:** a recording being made shows how far along it is,
everywhere: a ring and the percent on its card ("Working 64%"), a bar with "64%, about 6 min left" in the list, the
stage, "Step 5 of 9", a bar, the percent, the time left and the latest line in the inspector's Outputs with
**Pause** and **Stop**, the same on one line in the Viewer's banner, the whole line's percent on the toolbar's
**Activity** button, and "Making Sun 13 Sep: Writing the transcript, 64%, about 6 min left. 2 waiting." in the menu
bar. The percent is weighted by how long each stage takes **on this Mac** (each stage's last 10 runs, `StageTiming`,
seeded from the store's own step history) and never goes back; ffmpeg reports its own progress (`-progress
pipe:1`); Parakeet and writing are timed and held at 95% until they end; the time left appears only once the
running stage has a measured rate ("Working out the time left" until then); a stage still for a minute says what
it waits on. **Pause** suspends the running tool (its time limit moves on by the pause) or holds a waiting
recording in its place; **Stop** ends the make (the last make's files stay) or takes it out of the line; nothing
restarts it on its own; **Make Next** moves one to the front. **Window > Activity (Command-9)**: a sentence and Pause
All, then **Now** (the make with every stage and its time, the line waiting), **Finished** (by day, with the result,
Show and Show in Finder) and **Log** (v1's lines, with a search field). The menu bar menu has Show Activity, "N
recordings need you" and Prakriti Help. See `docs/BUILD-LOG.md`, "v2 part M4a".

**v2 part M6a, faces in a recording, Mon 12 Oct (built, not installed: see BUILD-LOG "v2 part M6a"):** every make
looks for faces after the transcript (step "Faces"): every frame decoded with AVAssetReader, two a second given to
Vision's face finder (revision 4) with the capture quality, joined into tracks (overlap 0.3, or near and the same size;
broken by a change of picture or 1.5 s unseen), and the tracks into rows by place. It keeps **boxes and times only**, in
`<Application Support>/People/Recordings/<recording id>.json`, through a job folder deleted when the step ends. A
recording shows "One person at a time." or "Other people appear, up to 2 at once." on its card (the list says "Up to 2 at
once"), the Sort menu filters to Other People Appear, the inspector's **People** tab (second) says what was found with a
row per face (Unnamed 1, 2...) whose picture is cropped live and never saved, and the first time two faces share a frame
one notice says "Other people appear in this recording." Older recordings get **Look for Faces**. Nobody is named, nothing
made changes, and the privacy lock does not move (voices are M6b). Measured: 13 Sep 30 s, 6 Sep 120 s.

**v2 part M6b, voices and names, Tue 13 Oct (built, not installed: see BUILD-LOG "v2 part M6b"):** right after the faces,
every make listens for who speaks when (step "Voices"). With two or more audio tracks (OBS: track 1 the mix, tracks 2 and up
one microphone each) a track speaks when it is speech (-45 dB or more a tenth of a second) and within 6 dB of the loudest
track at that moment; with one mixed track, FluidAudio's offline diarizer (0.15.5, Hark's pin) tells voices apart, a best
guess, and every change of voice is listed to listen to. Each voice is linked to a face by being the only face on screen or by
the mouth moving with it (Vision landmarks at 10 fps on stretches with two or more faces, measured in memory, never kept).
The people file gains the voices as times only. **Naming without prints:** Settings, Privacy, **People You Name** (a name and
"Cloud models may read their words", off by default); the Info tab's **Who is teaching** (the voice that speaks most and its
face take the name); the People tab's **Name for This Recording** on any face or voice, and **Track N in This Folder** for a
microphone that is always one person's. **The privacy lock now reads the people check:** checked only once both steps ran,
and every face row, voice and glimpse without a name counts as someone else, so a recording stays on this Mac until Ivan
names everyone in it and each named person heard has agreed (and, as before, it is a talk that does not say "Serenity").
Older recordings get **Check People**. Measured: 13 Sep one voice (14 min 49 s, linked to its face); 6 Sep whole pass under
two minutes.

**v2 part M6c, choices applied to audio, Tue 13 Oct (built, not installed: see BUILD-LOG "v2 part M6c"):** every face
and voice in the People tab has a choice, **Include**, **Hide Face** or **Leave Out** (a voice with no face: Include or
Leave Out), with **Set All Unnamed To**, a line saying what it takes out ("Leaving out Voice 2 takes 19 s out of the
podcast."), **Play Their Moments**, and Edit > Undo. **Everyone starts as Include** (Ivan, 12 Oct: releases exist). A
choice is kept on the recording (`Recording.choicesJSON`) and used at the next make: step **People left out** cuts every
stretch a left-out voice speaks from the podcast episode and the podcast-ready episode (`LeaveOut.plan`: every word it
touches whole, a short gap taken whole, a long pause by 0.25 s), joined with Ivan's own cuts, and the transcript files
follow; where someone left out and someone included speak at once the stretch is cut and listed. Step **Who is heard in
the episode** then listens to what was made again (`AudioOutputCheck`, the diarizer in memory) and stops Approve if anyone
sounds like a person left out. Step **Names said aloud** lists every person's name Apple's tagger finds that is not someone
named in Settings; each is **Keep** or **Mute**, and Mute silences it in both episodes and writes [name] in every
transcript file, caption and writing request. Approve waits for the choices to be made, the check to pass, every name to
be decided, and (someone left out of a mixed track) the changes of voice to be listened to. Hide Face changes no picture
yet (M6d). With nobody left out and nothing muted the episode is made exactly as before.

**v2 part M6d, hiding in pictures, Tue 13 Oct (built, not installed: see BUILD-LOG "v2 part M6d"):** once faces are
known, a recording's card, list row and Activity row show a frame from it instead of the plain tile, chosen so everyone
in it is someone Ivan included; failing that, with the face of everyone set to Hide Face or Leave Out hidden by
`FaceHide` (padded 1.6 times, blurred and pixelated, held 0.5 s around each sighting, followed at the full frame rate by
Vision's tracker); failing that, the tile. Vision checks every frame before it is kept. The picture lives in
`<Application Support>/Thumbnails/` and is the only picture Prakriti keeps; a change of choice or name deletes it at once
and chooses again. In the Viewer, on the Original, **People** (top right of the picture, or View > People) draws a box and
a name on each face, dashed with the choice for anyone hidden. Hide Face now changes the recording's picture; the video
that hides faces is M8d.

**Two copies, two jobs.** The live Prakriti is the copy in `~/Applications` (`make install` puts it
there); it watches the real folders and opens at login. Everything run from the build folder for
testing opens with `--development`: its own store, preferences, log, lock and `~/Prakriti/Dev`
folders, beside the live one.

### Day to day (for Ivan)

- **Open it.** It opens by itself when you log in and keeps watching with its window closed. To see
  the window, click its mark in the menu bar (a disc cut across the middle) and choose Open Prakriti, or:

  ```bash
  cd ~ && open ~/Applications/Prakriti.app
  ```

- **Where things go.** Finished files: `~/Prakriti/Outputs/<recording name>/` (`episode.mp3`, the
  transcripts, `REPORT.md`, `show-notes.md` when writing is on, and the `Podcast-ready` folder when
  that output is on: the MP3 to upload, its captions, `Episode text.txt` with the title, show notes
  and social captions, and the upload checklist; the inspector's Outputs has a Copy button for each). Your yeses:
  `~/Prakriti/Approved/<recording name>/`, only when you press Approve. To have any file made, put it
  in `~/Prakriti/Drop`. Prakriti only reads the Studio Recordings folder and never writes into it.
  Every look and every step: `~/Library/Logs/Prakriti/<date>.log`, and Window > Activity.
- **Find a recording.** Needs You (in the sidebar) holds what waits on you; In Progress what is being made;
  Ready what you approved; All Recordings everything. Click one to see it in the inspector on the right;
  double-click it (or press Return) to open it in the Viewer, which plays it with its transcript under it;
  Escape comes back. Type in the search field to find
  one by its title, notes or what was said.
- **The upload folder.** `~/Prakriti/Outputs/<recording name>/Podcast-ready/` holds everything a
  podcast host asks for: the MP3 (named `<Show> - <Title>.mp3` once both are set, by its date until
  then), its captions (`.srt` for the host's transcript field, `.vtt` for the web), `Episode text.txt`
  (and `.md`) with the title, one-line summary, show notes with chapters, keywords and a caption and
  pull quote for Instagram, LinkedIn and X and Threads, and `Upload checklist.txt`, every line PASS,
  MISSING or FAIL with what to do. It exists only for a recording with Podcast-ready episode switched on.
  Prakriti never uploads; you do, by hand. To get one ready:
  1. **Once, in Settings (Command-comma), Outputs, Podcast-ready episode:** the show name, artwork, host or author,
     numbering, and a call to action if you want one. These belong to the show and reach every episode.
  2. **In the inspector (click the recording):** in Info, mark it "Talk, one teacher speaking" and set any trim and
     cuts (or open it and take words out in the Viewer); in Outputs, under Outputs for this recording, switch on Podcast-ready episode (and Titles, show notes and chapters,
     with LM Studio open); press Make Again. With the writing on, allow an hour or more.
  3. **Under Ready to upload:** read the drafts, press Use This Title and Use as Notes for the ones you
     keep (or type your own), type the episode number if numbered, then Update Podcast-Ready Files
     (under a minute; the sound is not made again).
  4. **Listen** for any voice other than the teacher's and any name said. The Speakers line stays
     MISSING whatever you do (Prakriti cannot check voices), so with everything else set the checklist says
     "0 FAIL, 1 MISSING": that last one is your ear.
  5. **Approve** copies the folder to `~/Prakriti/Approved/<recording name>/Podcast-ready/`, every file in
     the receipt. Upload the MP3 from there, upload the `.srt` where the host takes a transcript, and paste
     the title, notes and captions from the page's Copy buttons.
  A class is never made ready. For episode 1, the cuts and the intro in `docs/BUILD-LOG.md`, "Podcast-ready
  episode: the handoff", come first; and Make Again replaces engine v0's `episode.mp3`, so the handoff gives
  the one command that copies it aside before you do.
- **Help.** Help, Prakriti Help (Command-?) opens the Help window; typing in the Help menu's search field
  finds an article too. Help, Show Log in Finder shows today's log. Help describes only what the app does
  today.
- **The welcome.** It opened once by itself (after the v2 part M2b install). Help, Welcome to Prakriti opens
  it again; its last panel is the quickest way to turn on notifications (Open Notification Settings goes
  straight to Prakriti's page in System Settings: turn on Allow notifications).
- **See how far along it is.** A recording being made shows its percent and time left on its card, in the list,
  in the inspector and in the menu bar; Window > Activity (Command-9, or the Activity button in the toolbar)
  shows every step, what waits, what finished and the log. The time left reads "Working out the time left"
  until Prakriti has timed that step on this Mac (after the first make of each kind, it knows).
- **Pause it.** Pause All (the window's toolbar, the menu bar, or Settings, General). A recording already
  running finishes; nothing new is found or started until Resume All. To hold one recording, click Pause beside
  it (Activity or the inspector), then Resume; Stop ends it, keeping the last make's files, and it waits for
  Make Outputs.
- **Stop it.** The mark in the menu bar, Quit Prakriti (or Command-Q with the window in front). It stays stopped
  until you open it again or log in again. To stop it opening at login: System Settings, General,
  Login Items, switch Prakriti off. **If it crashes, nothing restarts it until the next login** (engine
  v0 restarted itself): Activity going quiet, no "Checked 2 folders" line for more than 5 minutes, is
  the sign.
- **Engine v0 is retired** (Sat 10 Oct, 14:57). Prakriti for Mac is the only thing watching. Never
  run both: two watchers make and notify everything twice. Going back: "Engine v0: retired" above.
- **What still needs you:** the checklist in `docs/BUILD-LOG.md`, "Finish line" (turning on
  notifications first), and for the podcast, "Podcast-ready episode: the handoff", For Ivan (listen
  to episode 1 old against new; the show name and artwork from Gabriel).

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
cd ~/Code/prakriti/mac && make fixtures
```
```bash
cd ~/Code/prakriti/mac && make accept MILESTONE=m2
```
```bash
cd ~/Code/prakriti/mac && make regress MILESTONE=v2-m0
```
```bash
cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --app-icon build/Build/Products/Debug/Prakriti.app ../screens/mac/v2-m1
```
```bash
cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --menu-bar build/Build/Products/Debug/Prakriti.app 10 ../screens/mac/v2-m1/menubar
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
cd ~/Code/prakriti/mac && make accept-podcast MILESTONE=podcast
```
```bash
cd ~/Code/prakriti/mac && make accept-episode-text MILESTONE=episode-text
```
```bash
cd ~/Code/prakriti/mac && make accept-help MILESTONE=v2-m2a
```
```bash
cd ~/Code/prakriti/mac && make snapshots MILESTONE=v2-m2a ONLY=help
```
```bash
cd ~/Code/prakriti/mac && make snapshots MILESTONE=v2-m2b ONLY=welcome
```
```bash
cd ~/Code/prakriti/mac && make snapshots MILESTONE=v2-m3a ONLY=library
```
```bash
cd ~/Code/prakriti/mac && make look MILESTONE=v2-m3a
```
```bash
cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --keys build/Build/Products/Debug/Prakriti.app
```
```bash
cd ~/Code/prakriti/mac && make accept-first-launch MILESTONE=v2-m2b
```
```bash
cd ~/Code/prakriti/mac && build/Build/Products/Debug/Prakriti.app/Contents/MacOS/Prakriti --debug-help-search=OBS
```
```bash
cd ~/Code/prakriti/mac && make accept-progress MILESTONE=v2-m4a
```
```bash
cd ~/Code/prakriti/mac && make accept-capture MILESTONE=v2-m4b
```
```bash
cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --activity-window build/Build/Products/Debug/Prakriti.app ../screens/mac/v2-m4a/real/activity-during-a-run.png
```
```bash
cd ~/Code/prakriti/mac && open -n build/Build/Products/Debug/Prakriti.app --args --development --show=activity --debug-status-log
```
```bash
cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6a
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

`make accept-capture` (v2 part M4b, about 2 minutes) runs the **real 13 Sep talk**, `two-people-tracks.mov`,
`silent-60s.mp4` and the 30 s clip through the app's runner in development (in-memory store) and needs the 13 Sep
talk at 1920 by 1080, 29.97 fps, H.264, Rec. 709, one stereo track flagged as one microphone in both channels with
the tip "Give each speaker a microphone on its own track."; the fixture's three tracks each with its own loudness
and none flagged; the silent fixture's track silent; the 30 s clip filed as a test with no output folder and its
check in the store; the originals unchanged. It draws the Checks tab of each, light and dark, and writes
`acceptance-capture.txt`. `make accept-progress` (v2 part M4a, about 3 minutes) makes the **real 13 Sep talk** twice in development with
the podcast-ready episode on, writes every progress snapshot the window would see to `progress-trace.txt` (time,
stage, percent, time left, and the seconds behind it) and `acceptance-progress.txt`, and passes when each run
rises from 0 to 100% without going back and with at most two updates in any second, the second run's time left
at the 50% mark is within 25% of what really remained, and the menu bar's status line, written to the
development log as `--debug-status-log` writes it ("Status line: ..."), matches the trace at 25, 50 and 75% to
the second. `--debug-status-log` (Debug builds only, warning 77) writes every change of the menu bar's status line
to the log. `capture-window.swift --activity-window <app> <png>` captures the Activity window of a copy that is
already running (a development copy making a dropped clip: `make drop MODE=development` opens it with
`--show=activity`). `make look` captures the Activity window's Now (the sample talk being made), Finished and Log
(`--activity-tab=<now|finished|log>`).
`make accept-people` (v2 part M6a, about 5 minutes) runs the face step through the runner in development on the **real 13
Sep talk** (on engine v0's chain: its episode must equal v0's bit for bit; one face track group over 95% of the frames,
or, when two faces ever share a frame, their times and counts written down for Ivan with three frames in `for-ivan/`
that the build never opens), both two-people fixtures (two at once, the corner face 0:20 to 0:60, the notice once),
the step alone on the **real 6 Sep talk** timed (under 5 minutes), nothing stored for strangers (no `People/Faces`,
`Voices` or `FaceIndex` in either mode, no job folder, no list of 128 or more numbers and no picture word in any people
file, `file --mime-type` finds no image under Application Support/Prakriti), the People tab and cards drawn with a test
pattern in each face circle; since v2 part M6d also the card picture of two-people-mixed (everyone included, then the corner
face left out, then the chooser held to 0:20 to 0:60 so the corner face is hidden: one face, inside the main box, the
corner's variance down 80% or more), five frames hidden by `FaceHide` with no face left in a hidden region, the card
pictures the only images under Application Support, and `m6d-hide-test-pattern.png` (the hiding over a moving test
square) to look at; then `scripts/people-crash-check.sh` kills a `--debug-face-scan` with SIGKILL mid-scan and
needs the next development launch to delete its job folder before its first look. It writes `acceptance-people.txt`
and `crash-check.txt`. `make test` runs every unit test (data, rules, copy and type checks, and the snapshot render).
`make snapshots` writes every screen, light and dark, at the window's real size (1440 by 900 since v2
part M3a) to `screens/mac/<milestone>/` (gitignored): every smart group filled and empty, the list, a folder,
the inspector's tabs and states, a search, a filter, the Settings panes, the Activity window and v1's
recording pages (`ONLY=library` for the window and Settings alone), plus an `-end` picture for any page
taller than the window and `-inspector-p2` to `-inspector-end` for a long inspector; it fails if the
selected sidebar row's icon or label cannot be seen, or if the window's content asks for more height than
the window has. The sidebar and the inspector are Liquid Glass, which a bitmap cannot draw, so each is
drawn on its own into its column. `make look` opens the **real** app on sample data (in memory, nothing
saved) at each smart group, the list, a folder, each inspector tab, a search over what was said, each pane
of the Settings window and the Activity window, in light and dark, captures each with `screencapture -l`
into `screens/mac/<milestone>/real/`, checks the main window is 1440 by 900 and its selected sidebar row
by its pixels, checks that adding the Studio Recordings folder is refused with an alert, and then drives
the keys (`--keys`: Return, Escape, Command-Down, Command-Up, Command-[, Command-1 and 2, Command-Option-I,
Command-comma), each read back through Accessibility by process id. Command-Option-I is pressed twice at once,
then the inspector itself (its tab switch, not only the View menu's words) must still be on screen 1.5 s later,
and an unhurried hide and show is the control (warning 107). A capture opens at 1440 by 900 and
saves no window frame into the live copy's preferences. It takes the screen's focus for about three
minutes: leave the Mac alone. `swift scripts/capture-window.swift --contrast <png> <x0> <y0> <x1> <y1>`
measures the contrast between the darkest and lightest pixel in a box of a capture (text on its background).
`make check` builds, tests, launches the app, lets it close its own window, proves it is still
running 15 seconds later, then runs `make look`'s capture. `make accept` is milestone 2's check on
**real recordings** through the app's own pipeline and runner (about 4 to 5 minutes): the 13 Sep talk
must come out between -17 and -15 LUFS with its true peak at or under -1.0 dBFS, a transcript
reaching within 120 s of the end and a REPORT.md; the `silent-60s.mp4` fixture (65 s of the 13 Sep
picture with digital silence) must be Needs a decision with nothing made; the 30 s clip in
`~/Prakriti/Dev/Drop` must be filed as a test; the 6 Sep talk runs too. Until v2 part M0 (Sun 11 Oct)
the silent recording was the 14 Sep class; the rule is now never a class, so `acceptance.txt` names no
2026-09-14 file. It builds the fixtures first if any is missing, writes to `~/Prakriti/Dev/Outputs`,
draws All Recordings, Needs You, the Activity window and each recording's page from what was really measured into
`screens/mac/<milestone>/`, and writes the numbers to `acceptance.txt` there. `make fixtures` builds
the shared test files of v2 (`docs/v2/PLAN.md`, section 4) into `~/Prakriti/Dev/Fixtures` from the 13
Sep and 6 Sep talks and macOS `say`, from scratch every time (about 15 s), and prints each file's
SHA-256 with SAME or CHANGED against the last run: `13sep-90s.mp4`, `silent-60s.mp4`,
`two-people-mixed.mp4` (a second face in the corner from 0:20 to 0:60 and a second voice, `say`, from
0:30 to 0:50, on one dual-mono track), `two-people-tracks.mov` (the same picture; track 1 the mix,
track 2 the talk alone, track 3 the second voice alone, each mono), `ums-and-retake.wav` (planted
fillers, a stutter, a restart and a parallel pair, with its text beside it), `second-voice.txt` and
`synthetic-transcript.json` (a made-up 4,023-word talk in Parakeet's JSON shape, naming no real person,
for cloud tests). `ivan-plus-13sep.mov` is made only once Ivan has put his own `ivan-clip.mov` there.
`make regress` is the regression set every v2 part runs: `make test`, `make accept`, `make
accept-edits`, in order, stopping at the first failure. `capture-window.swift --app-icon` draws the
app's icon the way Finder and the Dock get it (`NSWorkspace`) at 512 and 32 px, plus the 32 px one
magnified 8 times, and measures the mark: the empty rows of the cut and how far the upper half sits
right of the lower one (it FAILs v1's plain dot). `--menu-bar` reads the real menu bar for the given
seconds without clicking anything: it captures the system's menu bar window about three times a second,
finds every Prakriti mark by comparing each item with the seven glyphs, saves the first look at each,
magnified, and prints what each showed and when it changed; it PASSes when the working frames turned
every 0.7 s and every other state held still. It needs Screen Recording permission for whatever runs
it (the session that built v2 part M1 had it through the app it ran in; without it the bar comes back
empty and the check says so). Run it while a development copy works (`make drop MODE=development`) to
see the frames turn. `scripts/process-in-app.sh` checks the **real app**: it opens
Prakriti with Process File on one file (launch flag `--process-file=`), waits for the result in the
log, and captures the real window on Recordings and on that recording's page. `make install`
builds, quits the installed copy cleanly, replaces `~/Applications/Prakriti.app` whole, gives it a
new date (so Finder reads its icon again) and opens it: **run it after every code change**, or the live watcher keeps running the old code. `make drop`
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
whenever a model changes.** It must hold on any real store (warning 91): `FROM=<an older store>` runs it
on that one instead. `make accept-edits` is milestone 5's check on the **real 13 Sep talk**
(about 3 minutes): made with the standard choices, marked as a talk, the first 10 s trimmed and 5:00
to 5:30 cut on its page, made again, approved into `~/Prakriti/Dev/Approved`, the approved MP3
measured with ffprobe against the first episode (about 40 s shorter), the cut words checked gone from
the approved transcript and by transcribing the approved episode again, then marked as a class and
refused; it writes `acceptance-edits.txt` and pictures of each state. `make snapshots ONLY=recording`
draws only the recording pages, for a quick look, and `ONLY=help` only the Help window: every article
this build shows, light and dark, each screenful of a long one, and a search's results. `make
accept-help` (v2 parts M2a and M2b, about two minutes, takes the screen's focus) opens the **real** Help
window on its own (`--sample-data --show=help`, at `--help-article=<id>` or `--help-search=<words>`) at three
articles and a search in light and dark, captures each into `screens/mac/<milestone>/real/`, checks only
the Help window opened; then the **real** welcome on its own (`--show=welcome --welcome-panel=<1 to 5>`, and
`--welcome-folder=<path>` for the last panel after Choose Folder) at each panel, light and dark, each the
only window and fitting without scrolling (the window measures itself and writes "Welcome panel N of 5
fits: needs X pt of 600 pt." to the development log, which the check reads); then, through Accessibility by
process id, Help, Welcome to Prakriti, Continue, Return, Command-Left, Back and Escape on the welcome, its
"More in Help" link and Start Using Prakriti; then runs the Help menu's search handler for OBS,
notifications and privacy through the debug switch `--debug-help-search=<words>` (it prints the article
ids and quits; Debug builds only, never read by the installed copy) and needs the expected article first in
each; it writes `acceptance-help.txt`. `make accept-first-launch` (v2 part M2b, about half a minute, takes
the screen's focus) deletes the **development** preference `welcomeSeenVersion` (never the live one, which
it reads before and after), opens the built app twice with `--development`, and needs the welcome at the
first launch only ("Welcome shown" in the log and its window, in front of the main window) and the
watcher's first look within 5 s of both launches; on the first it also clicks through to the last panel,
opens and cancels Choose Folder, and presses Open Notification Settings only when macOS already has a no
(never Turn On Notifications: the live copy shares the permission), then quits System Settings if it was
not open before; it writes `acceptance-first-launch.txt`. `make snapshots ONLY=welcome` draws the five
panels light and dark, the last panel's states, and the five panels as they will read once every part is
built, and fails if any needs more than 600 pt. `make accept-models` is milestone 6's check on the
**real 13 Sep talk** with the **real models** (about 11 to 15 minutes, nearly all of it Qwen3.8-27B
thinking; it needs LM Studio's server running at the Models screen's address with the model
downloaded): writing is set to the Claude API on purpose, so the privacy lock must hand it to LM Studio
(since v2 part M5a because its people are not checked; the Claude client in the test only counts and
refuses, and must be asked 0 times); tags and summary go to Apple on-device; the model is unloaded first so Prakriti's own load at
65,536 tokens is exercised, and must be unloaded again after. It checks every chapter start against
the cue starts of `transcript.srt` and every quote against `transcript.txt`, has Apple on-device tag a
short input, tests each provider for real, and writes `acceptance-models.txt`, the model's own answer
(`model-answer.txt`) and pictures of the page and the Models screen. `make accept-episode-text` is the
episode text's check on the **real 13 Sep talk** with the **real model** (about 30 minutes, nearly all
of it Qwen3.8-27B; LM Studio's server must be running): made with everything on and writing set to the
Claude API on purpose (the privacy lock must keep it on this Mac: 0 Claude calls), then `Episode
text.txt` and `.md` are read back independently: every section, every pull quote found in
`transcript.txt` and inside one `.srt` cue, every chapter time one ffprobe reads from the finished MP3,
no dashes, no "$" or "enroll" in the captions, X and Threads under 280 characters, at most five
hashtags; then a test call to action is set, the files updated, checked, cleared and updated again; it
writes `acceptance-episode-text.txt` and pictures of the page and of the class refusal. The real window on the sample talk in the Viewer:
`open -n build/Build/Products/Debug/Prakriti.app --args --sample-data --show=needs-you --open=ready
--rendition=podcast --appearance=light` (add `--sample-edits` for a trim and cut not made yet; `--rendition=original`
only with `--sample-original=<a test pattern>`, so no talk's picture is shown; `--sample-output=<folder>` for a
podcast-ready file; `--quick-help`), then
`swift scripts/capture-window.swift --window build/Build/Products/Debug/Prakriti.app out.png`.
`--open=<path>` opens one recording in the Viewer in the real app. **Playback** (v2 part M3b) is proved from the
log, never the picture: `swift scripts/capture-window.swift --playback build/Build/Products/Debug/Prakriti.app
"<a development recording with an episode>" <folder>` (part of `make look`; `PLAYBACK=` picks the file) opens it
with `--development --debug-playback-log`, presses Space and needs two `currentTime` lines 3 s apart to
differ by 2.5 to 3.5 s at rate 1; `playback.txt` holds the lines. **Then open
every PNG and look at it,** including the `-p2`, `-p3` pictures of the screens between a long page's
top and its end. Reading the code is not verification, and neither is a passing test.

### Where things live

| What | Where |
|---|---|
| Project definition (source of truth) | `mac/project.yml`; `make generate` rebuilds `Prakriti.xcodeproj`, and both are committed |
| App code | `mac/Prakriti/App` (launch, paths, settings, log, `PipelineRunner`, `Watcher`, `Notices`, `LoginItem` with the instance lock, `EngineV0Import`, `StatusSummary` and the menu bar's `WorkingTicker`), `Engine` (the pipeline: `Subprocess`, `Readiness`, `Measurements`, `Pipeline` with `Mastering`, `Report`; the watcher's `FolderScan` and `EventStream`), `Model` (vocabulary, SwiftData models, store), `Views`, `Fixtures` |
| Tests | `mac/PrakritiTests`: `ModelTests`, `RulesTests`, `NotificationTests` (the five notices and the copy rules), `WatcherTests` (the watcher end to end on generated files, FSEvents replay, the switch-over on v0's state.json), `PipelineTests` (rules on generated files, runs in `make test`), `PipelineAcceptanceTests` (real recordings, `make accept` only), `OutputsTests` (milestone 4: the word list on planted mis-hearings and through Parakeet with the Mac's own voice, the trim, intro, outro and stereo measured, a remake with the transcript off, a stopped remake), `OutputsAcceptanceTests` (the 13 Sep talk, `make accept-outputs` only), `RecordingPageTests` (milestone 5: edits, the episode's clock, typed times, the cut's words gone through Parakeet with the Mac's voice, six sentences of Parakeet's real misplaced tokens, what the report names, the page's player, Approve and its refusals), `EditsAcceptanceTests` (the 13 Sep talk trimmed, cut, made again and approved, `make accept-edits` only; since v2 part M3b through the Viewer's Remove and Keep and the inspector's typed trim and cut), `ProgressTests` (v2 part M4a: the weighted percent, the time left, a stall, twice a second, ffmpeg's progress, Pause and its time limit, Stop, the line, stage times, the status log), `ProgressAcceptanceTests` (the 13 Sep talk made twice, `make accept-progress` only), `ViewerTests` (v2 part M3b: the transcript as words, sentences and paragraphs, a selection's span, Timeline-lite's spans, Remove, Keep and Restore, the window put back, and a clicked word playing within 0.25 s with Follow Playback moving on, in a real player), `StoreMigrationTests` (`make migrate-check` only), `HelpTests` (v2 part M2a: the articles, the capability blocks, links, the copy rules, what only Help may show, search, the Help menu's handler, Show Me), `WelcomeTests` (v2 part M2b: the welcome's words and symbols, what each stage of the build shows, the first-launch rule, the notification button, Choose Folder), `LibraryTests` (v2 part M3a: the smart groups as predicates, sections and sorts, search, open and back, Remove from Library with the watcher passing over it, places, the lock line, every text color's contrast), `SnapshotTests`, and `SnapshotRenderer` (the drawing both snapshot kinds share: the main window with its sidebar and inspector drawn on their own, the Help window, Settings panes, the Activity window) |
| Real-window capture | `mac/scripts/capture-window.swift` (run by `make look` and `make check`); also `--analyze <png>` to check any capture, `--window <app> <png>` to capture the running app as it is, `--app-icon <app> <folder>` to draw the app's icon as Finder gets it at 512 and 32 px and measure its cut, and `--menu-bar <app> <seconds> <folder>` to read every Prakriti mark in the real menu bar over time (v2 part M1) |
| Real-app pipeline check | `mac/scripts/process-in-app.sh <file> <folder>` |
| The writing models (milestone 6) | `mac/Prakriti/Writing/`: `ModelClients.swift` (the request and reply, LM Studio with its load at 65,536 tokens, Ollama), since v2 part M5b `AnthropicClient.swift` (the current Messages request shape, streamed, its model list), `OpenAIClient.swift` (the Responses API, streamed, its filtered model list) and `Providers.swift` (`CloudHTTP` with the 9-minute silence limit and the event reader, `CloudModel`, `CloudModelList`, `CloudPricing`), `AppleOnDevice.swift` (Foundation Models, guided generation for tags and summaries), `Keychain.swift` (the Anthropic and OpenAI keys), `Writer.swift` (prompts, routing through the lock, tries, `WritingCheck`, `WrittenPackage` and `show-notes.md`), and since v2 part M5a `PrivacyLock.swift` (`PeopleFacts`, `LockSubject`, `PrivacyLock.decide` and `release`, `CloudPayload`, `CloudModelClient`, `LockedCloudClient`), `NameTokens.swift` (the tagger, tokens, restore), `HardwareCheck.swift` (`HardwareProfile`, `HardwareVerdict`) and `Model/Person.swift` (`Person.mayReadInCloud`); `App/ModelActions.swift` (test buttons, saving and removing each key, reading each model list, Write Again, Use This Title); `Views/Settings/ModelsPane.swift` (This Mac, Tasks, the lock, each provider with `KeyRow` and `CloudModelRow`), `Views/WritingSection.swift`; the pipeline step `.writing` and `PipelineRunner.write` (Write Again); tests `WritingTests`, `ProviderTests` (in `make test`), `ModelsAcceptanceTests` (`make accept-models`) and `NameRecallAcceptanceTests` (`make accept-names`, the tagger's recall on the 13 Sep talk) and `ProvidersAcceptanceTests` (`make accept-providers YES=1`, a real call per provider, only with keys in the tests' Keychain items and Ivan's yes on cost) |
| Written files | Beside the episode: `show-notes.md` (titles, notes, chapters, tags, summary, the checklist for review, what the checks changed, and placeholders for what is not chosen yet) and `titles-notes-chapters.json` (the checked package plus the model's own answer; never approved). On the recording: `writtenJSON` (the package without the raw answer) and `writingProblem` |
| The Claude API key | The login Keychain, generic password, service `studio.therowan.prakriti.app.claude-api`, account `api-key`. Tests use `studio.therowan.prakriti.app.tests.claude-api` |
| The recording page (milestone 5; retired in v2 part M3b, its functions in the Viewer and the inspector) | `App/RecordingActions.swift` (what its buttons do), `App/Approval.swift` (who may be approved, the copy and its receipt), `Engine/EpisodeEdits.swift` (the edits, the episode's clock, typed times, the transcript that follows the episode); tests `RecordingPageTests` (in `make test`) and `EditsAcceptanceTests` (`make accept-edits`) |
| Approved files, live | `~/Prakriti/Approved/<file name without extension>/`: `episode.mp3`, the transcript's chosen formats (following the episode), `REPORT.md`, and `APPROVAL.md` (title, notes, edits, every file's size and SHA-256). Never `transcript.json`. Development: `~/Prakriti/Dev/Approved/` |
| Outputs, development mode | `~/Prakriti/Dev/Outputs/<file name without extension>/`: `episode.mp3`, `transcript.txt/.srt/.vtt/.md` (the chosen formats, with the word list applied), `transcript.json` (Parakeet's words as heard, with their times; never changed), `REPORT.md` (engine v0's layout). A make in progress lives in the hidden `.making <name>` folder beside it |
| The podcast-ready episode | `mac/Prakriti/Engine/PodcastReady.swift` (the settings with numbering and the call to action, the chain with the reason for every number, the file name, chapters, `EpisodeCopy` and `PodcastPackage.copy` (the words the text files and the Copy buttons share), the two episode text files, the checklist and the class refusal), `PodcastReadyRun.swift` (the passes ffmpeg makes and the package written and read back), `ID3.swift` (Prakriti's own ID3v2.4 writer and reader), `Artwork.swift` (Apple's artwork rules, read by ImageIO); `Views/PodcastReadyViews.swift` (its settings on Outputs, the Ready to upload section with its Copy buttons and checklist, `Pasteboard`); `Writing/CopyRules.swift` (Ivan's copy rules, read by Swift); `PipelineRunner.packageAgain` (Update Podcast-Ready Files); tests `PodcastReadyTests` and `EpisodeTextTests` (in `make test`), `PodcastReadyAcceptanceTests` (`make accept-podcast`) and `EpisodeTextAcceptanceTests` (`make accept-episode-text`) |
| The Yoga Marga word list | `mac/Prakriti/Engine/Lexicon.swift` (each word as written, how it has been misheard, and what it is); shown in Settings, Outputs |
| Output settings | Which outputs: each folder's switches (the inspector, with the folder selected under Sources), else Settings, Outputs (files added by hand). How: Settings, Outputs. A recording's own choices (its page) override both: `OutputResolver` in `Model/Store.swift` |
| The main window (v2 part M3a) | `mac/Prakriti/Model/Library.swift` (the smart groups and their predicates, `SidebarItem`, the browser's sections and sorts, `LibrarySearch`, `TranscriptIndex`), `App/LibraryActions.swift` (places, open and back, confirmations, a card's menu, Remove from Library), `Views/MainView.swift` (the window, toolbar, Sort menu, sidebar; the Activity window moved to `Views/Activity/` in v2 part M4a), `Views/Library/` (`LibraryView` with the groups, folders, search, empty states and the Needs You status line; `BrowserGrid` with `RecordingCard`, `NeutralTile`, `StatusCapsule`, `RecordingMenu`; `BrowserList`), `Views/Inspector/` (`InspectorView` with the folder and several-selected inspectors; `OutputsTab` with `Deliverable`; `ChecksTab` with `Recording.lockLine` and `setClaim`; `InfoTab`), `Views/Settings/SettingsScene.swift` (the Settings window: General, Outputs = v1's `OutputsView`, Models = `ModelsPane` (v2 part M5b), Privacy, Advanced), `Views/AppColor.swift` (the measured text colors and `.appSecondary`); tests `LibraryTests` and `SnapshotTests.testRenderEveryScreen` |
| The Viewer (v2 part M3b) | `mac/Prakriti/Views/Viewer/` (`ViewerModel` with `Rendition` and `TimelineSpan`; `ViewerView` with the banner, the picture, `RenditionPicker`, the tip and `SelectedSpanStrip`; `TranscriptView`, an `NSTextView`; `TimelineLite`; `Transcript.swift` with `TranscriptDocument`, `TranscriptLine` and `RecordingTranscript`), `App/ViewerActions.swift` (opening it, Remove and Keep, Restore, the typed cut, `WindowState` restoration, the debug switch), `Views/QuickHelp.swift`, `Views/Inspector/RecordingChoices.swift` (v1's per-recording outputs and step rows, moved), `Views/Inspector/InfoTab.swift` (`CutEntry`, Use Player Time); tests `ViewerTests`, `RecordingPageTests`, `EditsAcceptanceTests`, `SnapshotTests` (`20-viewer-*`) |
| Test clips | `~/Prakriti/Dev/Drop/2026-09-13 clip 30s.mp4` (a test) and `~/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4` (a full run), cut with `ffmpeg -c copy` from the 13 Sep talk |
| v2 test fixtures | `~/Prakriti/Dev/Fixtures/` (made by `make fixtures`, never by hand): the files, `SHA256SUMS` from the last run, `RECIPES.txt` (the ffmpeg and macOS versions they were made with). The recipes: `mac/scripts/make-fixtures.sh`, with the texts `say` reads and the made-up talk in `mac/scripts/fixtures/` |
| The built app | `mac/build/Build/Products/Debug/Prakriti.app` (gitignored) |
| The live app | `~/Applications/Prakriti.app` (from `make install`), the login item |
| Store, live | `~/Library/Application Support/Prakriti/Prakriti.store`; the watcher lock beside it (`watcher.lock`) |
| Log, live | `~/Library/Logs/Prakriti/<date>.log`: every look, every step, every notice and what macOS did with it |
| Outputs and drop folder, live | `~/Prakriti/Outputs/<file name without extension>/`, `~/Prakriti/Drop` |
| Engine v0, retired | `engine/prakriti.mjs`; its plist in `~/Prakriti/retired/`; its `~/Prakriti/state.json` and `log.txt` kept as history |
| Store, development mode | `~/Library/Application Support/Prakriti/Development/Prakriti.store` |
| Log, development mode | `~/Library/Logs/Prakriti/Development/<date>.log`, one line per event |
| Working folders, development mode | `~/Prakriti/Dev/Drop`, `~/Prakriti/Dev/Outputs`, `~/Prakriti/Dev/Approved` |
| App icon | `mac/Prakriti/Resources/AppIcon.icon`, an Icon Composer document (two glass layers on stone; default, dark, clear and tinted), copied from the master `docs/v2/icons/source/Prakriti.icon`. `actool` compiles it into `Assets.car` and `AppIcon.icns`, and Info.plist gets `CFBundleIconName` by itself. Design, sources and previews: `docs/v2/icons/` (since v2 part M1; v1's `make_icon.swift` is retired) |
| Prakriti Help (v2 part M2a) | The articles: `mac/Prakriti/Resources/Help/00-index.md` to `10-troubleshooting.md` (user text only, copied into the app as `Contents/Resources/Help`); their notes: `docs/v2/help-notes/`; how to write one: `docs/v2/help/README.md`. Code: `mac/Prakriti/Help/` (`Capabilities` (what is built), `HelpArticle` (front matter), `HelpLibrary` (loading, the `:::` pass, links, places), `HelpRenderer` (swift-markdown to blocks), `HelpSearch`, `HelpMenuSearch` (the Help menu's search field), `HelpModel` (the open article, Back and Forward, Show Me)), `Views/Help/` (`HelpWindow`, `HelpArticleView`), `App/DebugSwitches.swift` (`--debug-help-search`); the Help menu in `App/PrakritiApp.swift`; tests `HelpTests` and `SnapshotTests.testRenderHelp` |
| The welcome window (v2 part M2b) | `mac/Prakriti/Views/Welcome/`: `WelcomeContent.swift` (the five panels' words, each row with the capabilities it describes, `requires` and `unless`; `WelcomeContent.version`), `WelcomeModel.swift` (the open panel, the first-launch rule, Choose Folder), `WelcomeWindow.swift` (the window, its rows and buttons, its own fit measurement); the scene and Help, Welcome to Prakriti in `App/PrakritiApp.swift`; `welcomeSeenVersion` in `App/AppSettings.swift`; Turn On Notifications and `Notifier.openSystemSettings` in `App/Notices.swift`; the copy source and its status: `docs/v2/help-notes/welcome-panels.md`; tests `WelcomeTests` and `SnapshotTests.testRenderWelcome` |
| The capture check (v2 part M4b) | `mac/Prakriti/Engine/CaptureCheck.swift` (`CaptureReport`, `CaptureFinding`, reading ffprobe and the per-track ffmpeg call, the findings and their tips, `run`), the pipeline's `.capture` step, `Recording.captureJSON`, `Views/Inspector/CaptureSection.swift` (the Checks tab's Capture section), `App/CaptureActions.swift` (Check Capture for older recordings); tests `CaptureCheckTests` (in `make test`) and `CaptureAcceptanceTests` (`make accept-capture`) |
| Progress and Activity (v2 part M4a) | `mac/Prakriti/Progress/`: `JobProgress.swift` (`ProgressTracker`, the pure arithmetic: weights, the percent that never goes back, the time left only from a measured rate, the stall line; `ProgressSnapshot` with its status line; `TimeLeft`; `JobProgress`, published at most twice a second), `ProgressMeter.swift` (what the pipeline and ffmpeg report, read twice a second; `ProcessControl`, Pause by SIGSTOP and SIGCONT), `StageTimings.swift` (`StageTiming`, a SwiftData model, the last 10 runs of each stage, seeded once from the store; `firstGuess`, measured 12 Oct). `Engine/Subprocess.swift` (`onStdoutLine`, `control`), `Engine/Pipeline.swift` (`meter`, `passes`, ffmpeg's `-progress pipe:1` in `tool`), `App/PipelineRunner.swift` (`currentJob`, `pause`, `resume`, `stop`, `makeNext`, `queueFraction`, `queueTimeLeft`, `showSample`), `App/StatusSummary.swift` (`noteStatusLine`, `--debug-status-log`); views: `Views/Activity/ActivityWindow.swift` (the window, Now, Finished, Log, `ActivityButton`), `Views/ProgressViews.swift` (`ProgressRing`, `ProgressBlock`, `ProgressButtons`), the card's `StatusCapsule`, the list's Status column, `StatusBlock` in `OutputsTab`, `ViewerBanner`, `Views/MenuBar.swift`; `Fixtures.showProgress` (the sample talk being made, for snapshots and captures); tests `ProgressTests` (in `make test`) and `ProgressAcceptanceTests` (`make accept-progress`) |
| Faces (v2 part M6a) | `mac/Prakriti/People/`: `FaceScan.swift` (the reader, Vision at two frames a second, the change-of-picture measure), `Tracks.swift` (`FaceBox` and the Vision conversion, `FaceTracker`, `FaceGrouping`, `FacesFound` with its lines), `PeopleFile.swift` (`PeopleFolders`, the people file, `FaceStep` with its job folder), `FaceCrops.swift` (the People tab's live crops, memory only); the pipeline's `.faces` step and `PipelineOptions.people`; `Recording.facesJSON`; `App/FaceActions.swift` (`applyFaces`, Look for Faces); `Views/Inspector/PeopleTab.swift` (`PeopleTab`, `FaceRow`, `PeopleLine`); the job cleanup in `AppModel.launch`; `--debug-face-scan` in `App/DebugSwitches.swift`; tests `PeopleTests` (in `make test`), `PeopleAcceptanceTests` and `scripts/people-crash-check.sh` (`make accept-people`) |
| People files and job folders | `~/Library/Application Support/Prakriti/People/Recordings/<recording id>.json` and `.../Jobs/` (live); `.../Prakriti/Development/People/...` and `.../Development/Jobs/` (development) |
| Swift packages | `swift-markdown` 0.9.0 (21 Sep 2026, with `swift-cmark` 0.9.0), pinned in `mac/project.yml` and `mac/Prakriti.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, both committed (v2 part M2a) |
| Menu bar mark | Seven template image sets in `Assets.xcassets` (`prakriti-menubar`, `-working-1`, `-working-2`, `-waiting`, `-problem`, `-paused`, `-not-watching`), copied from `docs/v2/icons/source/menubar/imagesets/`; which one each state draws is `StatusSummary.Icon.menuBarAsset`; the working frames are turned by `App/WorkingTicker.swift` |

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
4. **A compiler warning fails the build** (`SWIFT_TREAT_WARNINGS_AS_ERRORS`, and `make build` reads its own
   output with `scripts/no-warnings.sh`). Reason: "builds clean" is a milestone gate, and an ignored warning
   becomes noise nobody reads. The setting alone is not enough: on 12 Oct a main-actor property read in a
   Sendable NotificationCenter closure stayed a warning, `xcodebuild` said BUILD SUCCEEDED, and that build was
   installed live with a "0 warnings" claim. So `make build` saves `build/build-output.log` and fails on any
   `warning:` line. The one `appintentsmetadataprocessor ... warning` line is the tool talking, not the
   compiler, and is the only line exempt. A warning prints only when its file compiles, so W4 is judged on a
   clean build in a fresh clone, never an incremental one. For AppKit notifications on the main actor, use a
   selector on a `@MainActor` object (`WindowUpdateObserver`), not the closure form.
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
17. **The acceptance tests and `make fixtures` are the only code that reads the Studio Recordings
    folder in development, and only the 13 Sep and 6 Sep talks, read-only;** each checks the
    originals' size and date are unchanged afterwards. Everywhere else development mode refuses that
    folder (warning 1). Anything a check needs that the two talks cannot show (silence, a second face,
    a second voice, a second microphone track) is a fixture made from them by `make fixtures`, never
    another studio file. Reason: the folder holds the classes, which may not be processed (student
    privacy), and the live Prakriti owns it. Until v2 part M0 (Sun 11 Oct) `make accept` also read the
    silent 14 Sep class; `silent-60s.mp4` replaced it, and the test fails if a 2026-09-14 path comes
    back.
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
28. **A folder decides only WHETHER an output is made; HOW it is made comes from the Outputs screen (Settings, Outputs since v2 part M3a),
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
50. **The privacy lock's decision is `PrivacyLock.decide`, applied in `Writer.write` (`route`), the only way any
    task reaches a model** (since v2 part M5a; warning 109 for the adapter): a locked recording turns a Claude
    API choice into LM Studio for every task, and the step line, the page and `show-notes.md` say so. A
    transcript that says "Serenity" (`Privacy.mentionsSerenity`, whole word, any case; `Recording.hasSerenity`
    is then set and never unset) still locks, as do a class and anything not marked as a talk. Reason: SCOPE
    PRV-10, until Serenity's yes no Claude session reads her teaching or any class. Proved: the acceptance set
    writing to the Claude API on the 13 Sep talk and the Claude client was asked 0 times.
51. **The prompts keep private matters out:** titles, show notes, chapters, tags and summaries leave out
    illness, deaths, grief, family matters, money troubles and relationships, anyone's, the speaker's
    included; the checklist may hold the speaker's own income, health or result claims, because those
    must be checked. Reason: on 10 Oct the first run's show notes (Qwen) and summary (Apple) both
    repeated a private family matter the 13 Sep talk mentions; the second run, with this rule, had
    none. A prompt is not a guarantee: Ivan reads every draft.
52. **Each cloud key lives only in the Keychain (`KeyStore.claude` for Anthropic, which keeps v1's service name
    `...claude-api` so an existing key is still found; `KeyStore.openAI` for OpenAI since v2 part M5b), is read only
    when a task is set to that provider (`PipelineRunner.writingSetup`, built tasks only), is sent only in its HTTP
    header, and is never written to a file, a preference, the store or a log, nor shown again after saving.** Tests
    use `KeyStore.testing` and `KeyStore.testingOpenAI` (`AppModel.keyStores`). Reason: the build's rule, and a key in
    a file ends up in git; PLAN section 11 forbids reading or testing with Ivan's real key, so even
    `make accept-providers` reads only the tests' items.
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

57. **The podcast-ready episode must stay "linear": loudnorm's second pass raises the whole episode by
    one amount, and the gain before the first limiter is measured until loudnorm's own correction is
    under 0.2 LU** (`masterPodcastReady`, step 4). Reason: engine v0's chain falls back to "dynamic" on
    every studio talk (the talk's true peak sits 23.8 to 26 dB over its loudness) and rode episode 1's
    volume: the gain over speech moved over a 4 dB spread, jumped more than 2 dB within a second for
    104 s, and swelled the room tone in pauses (measured 10 Oct, BUILD-LOG). The checklist FAILs
    anything but linear.
58. **Prakriti writes the podcast-ready MP3's tag itself (`ID3.swift`); ffmpeg encodes it with
    `-id3v2_version 0`.** Reason: measured on ffmpeg 9.0.1, its MP3 muxer writes the comment as a TXXX
    frame (not COMM) and wrote CHAP frames with no titles in them. Every frame is read back before the
    checklist says it is there, and ffprobe reads the chapters with their titles.
59. **The podcast-ready limits are sample-peak limits set low on purpose (-3.0, then -2.7 dBFS), the
    last limiter must barely act, and a finished MP3 over -1.1 dBTP is made once more with both limits
    lowered by the excess.** Reason: alimiter limits samples, not true peaks; measured, the encoded
    true peak lands 1.2 to 1.8 dB over its limit (at -2.8, the 6 Sep talk trimmed by 10 s reached
    -0.98 dBTP, over Apple's line). When the last limiter had to take 0.7 dB, the true peak rose to
    -0.9 and -1.0 instead of falling. The layout and 44.1 kHz are set before every limiter (v0's bug 2).
60. **A podcast-ready MP3 is measured with loudnorm's meter (`measureFinished`), which reports
    loudness and true peak to the hundredth, never with ebur128's one-decimal summary alone.** Reason:
    on 10 Oct ebur128 printed "-1.0 dBTP" for the file loudnorm measured at -0.98, and the checklist
    showed PASS for a file over the line. The acceptance checks with both meters.
61. **The podcast-ready master aims 0.4 LU louder than -16 (`encoderAllowance`).** Reason: LAME at 96
    and 128 kbps measures 0.4 LU quieter than the master it encodes (13 Sep: master -16.0, MP3 -16.4).
    A miss over 0.5 LU after encoding makes it once more with the aim corrected.
62. **The processed talk is rendered once to a float WAV with a hidden name (`.podcast-talk.wav`) in
    the staging folder, and deleted when the audio is made.** Reason: float, because a talk brought to
    -20 LUFS for the compressor has peaks over 0 dBFS that an integer WAV would clip; hidden, because
    `Pipeline.place` moves every visible file into the recording's folder; once, because the gain
    passes then read the WAV instead of decoding the 2.5 GB recording and compressing it again.
63. **Show name, host and artwork are never filled in by Prakriti; they are MISSING until Ivan sets
    them, and the file is named by its date until it has a title.** Reason: the build's do-nots, and a
    made-up show name in a tag would ship. Artwork that breaks Apple's rules is not embedded and FAILs.
64. **The podcast-ready episode starts off for every folder, and an older store gets it switched off**
    (`isOnByDefault` false, `PrakritiStore.addMissingOutputKinds` at launch; `make migrate-check`).
    Reason: it adds a few minutes per recording, and without a show name and artwork it is not ready
    to upload anyway.
65. **The checklist describes the file in the folder, measured after it was tagged: loudness, peak,
    range, rate, bitrate, length, size, the tail decoded, every tag frame and chapter read back.**
    Reason: reading code is not verification, and a file named for upload must prove itself. Update
    Podcast-Ready Files measures again too.
66. **Update Podcast-Ready Files re-tags and renames around the audio already made; it never masters
    again.** The audio bytes are the same (tested). A new trim, cut, layout or bitrate needs Make
    Again. Reason: a new title or show name should not cost a remaster and a second listen (it takes about
    10 s on a 16-minute talk and 35 s on episode 1, most of it measuring the file again).
67. **Ivan's copy rules are enforced in Swift (`CopyRules`), not only asked for in the prompt: no
    prices, money, earnings, enrollment, sign-ups or offers in a title, the one-line summary, the show
    notes, a keyword, a social caption, a pull quote, the tags or the summary.** A flagged caption, pull
    quote, title or keyword is left out; a flagged sentence of drafted notes or the summary is taken
    out; each is said in the notes and `Episode text.txt`. Ivan's own title, notes and call to action
    are never screened or changed (except an em or en dash becoming a comma); the call to action is the
    only place money or enrollment may appear, and the model never sees it. Reason: on 10 and 11 Oct the
    13 Sep drafts said "available to enrolled students", "pause new student enrollment", "a free week"
    and, in the MP3's comment, "pricing", while enrollment may be closed and the talk names a teacher's
    own income. A prompt is not a guarantee (warning 51). Keep the patterns narrow: "the practice
    offers", "pay attention" and "sales" as a subject are ordinary in a yoga talk.
68. **A pull quote is kept only when it is found word for word inside one line of the transcript (one
    sentence as Parakeet wrote it), keeps the copy rules and repeats no other platform's.** Otherwise it
    is left out and counted, never fixed. Reason: Ivan's brief asks for a one-sentence quote that is
    verbatim; a quote spanning two lines is two sentences, and a reworded one puts words in the
    teacher's mouth.
69. **A class is never made ready to upload.** `Pipeline` skips both podcast-ready steps for a recording
    marked a class (`PodcastPackage.refusal`), `canUpdatePodcastReady` and `repackage` refuse it, and the
    Ready to upload section says why. Make Again on a recording marked a class removes podcast-ready files
    made while it was a talk. Reason: students may be heard in a class and voices are not checked; a
    folder named for upload must never hold one.
70. **`Episode text.txt`, `Episode text.md` and the page's Copy buttons all read `PodcastPackage.copy`,
    and the chapters they list are the ones written into the MP3 (`PodcastPackage.chapters`, the first at
    0:00).** Reason: what Ivan copies must be what the file says, and a chapter time that is not in the
    finished file would send a listener to the wrong moment.
71. **Fixtures are made only by `make fixtures`, from the 13 Sep and 6 Sep talks and macOS `say`, into
    `~/Prakriti/Dev/Fixtures`, and the same recipe gives the same bytes** (metadata stripped, written
    bit-exact; `SHA256SUMS` records the last run, and a rerun says SAME or CHANGED for each file).
    Never add a fixture by hand or from any other studio file, and never let a check depend on a
    fixture's hash without `RECIPES.txt`'s versions beside it. Reason: the v2 checks need a second face,
    a second voice, silence and a second microphone track, which the two talks do not have, and the
    only other studio files with those are classes (student privacy); a hand-made file cannot be made
    again on the verifier's clone. A CHANGED with no recipe change means ffmpeg or the macOS voice
    changed (measured identical across runs on ffmpeg 9.0.1 and macOS 27.2, Sun 11 Oct). The corner
    picture starts at 3:00 of the 6 Sep talk because Vision finds no face from 10:12 on for half a
    minute, and two-people-mixed's sound is coded mid and side because ffmpeg's default AAC let the two
    identical channels drift apart by up to -14.5 dB (both measured).
72. **The menu bar mark is a template image from the asset catalog, one shape per state
    (`StatusSummary.Icon.menuBarAsset`), and the working frames are turned by the model's `WorkingTicker`,
    never by a `TimelineView` or a symbol effect inside the label.** The ticker's timer exists only while
    the menu bar shows the working state, and never with Reduce Motion on (it then holds the first frame
    still, and stops at once if Reduce Motion is turned on mid-work). Reason: a `MenuBarExtra` label is
    drawn once and kept, so a `TimelineView` in it never ticks (measured 10 Oct, one render in 5 s),
    while a change to an `@Observable` value redraws it (in v2 part M1 the real menu bar alternated 92
    times, one every 0.70 s, while a 90 s clip was made, then held still). A glyph that is not a
    template stays black on a dark menu bar, and a timer left running wakes Prakriti all day for
    nothing. `RulesTests` check every glyph is an 18 by 18 pt template and that the seven drawings
    differ, and drive the ticker on a clock the test moves by hand; both were proved by breaking them.
73. **The app icon is the Icon Composer document `Resources/AppIcon.icon`; it keeps the name `AppIcon`
    (the build setting `ASSETCATALOG_COMPILER_APPICON_NAME`), and no `AppIcon.appiconset` comes back.**
    Its master copy is `docs/v2/icons/source/Prakriti.icon`. If Ivan changes the icon in Icon Composer,
    his saved file becomes the master: copy it to both places, and never run
    `docs/v2/icons/tools/make_icons.py` again, because it rewrites the master. Reason: two sources for
    one icon is how a stale one comes back, and the generator would quietly undo Ivan's change. Check a
    change by drawing it (`swift scripts/capture-window.swift --app-icon`), not by reading the JSON.
    **`make install` touches the installed bundle** (`scripts/install.sh`). Reason: `ditto` keeps the
    build folder's date on the bundle (10 Oct), and macOS keeps an app's icon cached against that date,
    so after the first M1 install Finder's icon for `~/Applications/Prakriti.app` was still v1's dot
    while the bundle held the cut disc (measured 11 Oct); with a new date it read the cut disc.

74. **Help shows only what the build does.** Each article, and each block inside one (`:::requires video`
    ... `:::`, or `:::unless video` for what is true until then), names the capability it describes, and
    `Capabilities.built` decides what is visible; a part switches its own capability on in the same commit
    as its feature and rewrites the blocks it makes visible. `HelpTests.unbuiltNames` lists the feature
    names each part introduces and fails if any is visible before its part is built (proved by breaking
    it). Reason: the v2 help drafts described a viewer, faces and an edited video that did not exist, and
    Help that promises a feature is the copy drifting from the build (PLAN R16).
75. **The `:::` blocks are resolved in a text pass before swift-markdown parses anything, and swift-markdown
    parses with smart punctuation off.** Blocks never nest; an unclosed block, a stray `:::` or an unknown
    capability leaves the article out of Help and fails the test. Reason: swift-markdown does not know the
    fence (its directives are `@Name { }`); and its smart punctuation curled every quote (measured on the
    first Help snapshots) and turns `--` into an en dash and `---` into an em dash, which Ivan's rule forbids
    anywhere Prakriti shows text.
76. **The `prakriti://` and `prakriti-help://` links work only inside the Help window; the app registers no
    URL scheme** (`CFBundleURLTypes` absent, tested). Show Me links are buttons, and a link in an article
    opens only another article, never a web page. Reason: a registered scheme would let any web page or
    app drive Prakriti.
77. **Debug switches (`--debug-help-search`, and the later `--debug-playback-log` and `--debug-status-log`)
    are compiled only into Debug builds and are never read by `~/Applications/Prakriti.app`**
    (`DebugSwitches.isAllowed`, tested). Reason: `make install` installs the Debug build, so `#if DEBUG`
    alone would put them in the live app, and a check's flag must never make the live watcher quit.
78. **The Help articles are moved and copied by name, never by a `*.md` glob, and the app's Help folder must
    hold exactly the eleven articles** (`HelpTests.testTheAppHoldsExactlyTheElevenArticles`). Builder notes
    live in `docs/v2/help-notes/`, never in an article. Reason: a glob would have shipped
    `welcome-panels.md` as a Help article, and notes in an article are text Ivan would see.

79. **Drive or read a development copy's menus and buttons through Accessibility by process id
    (`AXUIElementCreateApplication(pid)`), never through System Events.** System Events finds a process by
    name, even when asked `whose unix id is`, and the live and development copies are both named Prakriti.
    Reason: in v2 part M2a two "Prakriti Help" clicks meant for a development copy went to the live app
    (two "Help isn't available" alerts there), and its menu was misread as the new build's.

80. **The welcome opens by itself at one launch only: the first one made by hand, and it counts as seen the
    moment it is shown there** (`welcomeSeenVersion`, `AppModel.welcomeAppeared`, `launchFinished`). At a
    launch macOS makes at login it is neither shown nor counted. Reason: Prakriti closes every window it
    opens at login (`AppDelegate`), so a welcome counted then would never have been read, and one shown at
    every launch would be in Ivan's way. A later "What's New" raises `WelcomeContent.version`. The check
    deletes only the **development** domain's preference
    (`defaults delete studio.therowan.prakriti.app.development welcomeSeenVersion`), never the live one.
81. **The welcome follows `Capabilities` like Help: every row names what it describes (`requires`), and a
    sentence true only until a part lands names that part (`unless`), with its v2 twin (`<id>-v2`) beside
    it.** A part that switches a capability on reads every row naming it and makes each sentence true of
    what it built. `WelcomeTests.testEveryStageOfTheBuildShowsAWholeWelcome` walks the plan's build order
    and fails if a twin pair shows both or neither, and `HelpTests.unbuiltNames` is checked against the
    panels too. Reason: the welcome is the first thing anyone reads, and copy that promises an unbuilt
    feature is PLAN R16.
82. **macOS is never asked about notifications at the launch that shows the welcome, and the welcome's
    button never asks twice:** it reads macOS's answer first; never asked, it asks; turned off, it opens
    System Settings at Prakriti's own page
    (`x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=<bundle id>`, measured on
    macOS 27.2 to open the page with Allow notifications). **No check ever presses Turn On Notifications
    in a development copy:** both copies share the bundle id and so the permission, and the question would
    land on Ivan's screen for the live app. Reason: v1 found notifications off for Prakriti, and once macOS
    has a no a second request shows nothing; the HIG asks for the reason before the system's question.
83. **Nothing in a window capture may let the watcher look through the folders.** A capture flag that adds
    a folder (`--welcome-folder`) stops the watcher around the call. Reason: the sample data names the real
    studio folder with Make outputs automatically, so a look in a capture would take its files in and could
    start work on a class. Found before the capture first ran (v2 part M2b).
84. **A capture finds the main window as the widest one** (`mainWindowID`), and the welcome as the 720 pt
    one. Reason: since v2 part M2b a development copy with an unseen welcome opens it beside the main
    window, and "the first window wider than 600 pt" could have captured the welcome instead.

85. **Remove from Library leaves the file's path on its folder (`Source.forgottenPaths`), and the watcher treats
    those paths as known.** The recording's Outputs folder goes to the Trash (`AppModel.moveToTrash`, only ever a
    folder inside this mode's Outputs); the original and the Approved folder are never touched; it is refused
    while the recording is being made or waits its turn; File > Add File takes the path off the list. Reason:
    the watcher finds a file it has no record of as new, so without the list the next look (5 minutes later)
    would take the removed recording in again and, in a Make outputs automatically folder, make it again
    (read in `Watcher.sweep` before building it; `LibraryTests` proves the look passes over it).
86. **Secondary text is `.foregroundStyle(.appSecondary)`, never the system's `.secondary`; text in the accent is
    `AppColor.accentText`; a problem in words is `AppColor.problemText`** (`Views/AppColor.swift`, `RulesTests`
    fails on `.foregroundStyle(.secondary)`). Reason: measured on macOS 27.2, the system's secondary label is
    3.95 to 1 on the white window and the dark accent #4459E8 is 3.05 on the dark one, under the 4.5 text needs;
    `LibraryTests` measures every text color on every background in light, dark and Increase Contrast. Never
    set a whole window's foreground hierarchy (`foregroundStyle(_:_:)`) to fix it: tried, it turned every
    bordered button and quaternary fill dark in the real window.
87. **Nothing in the main window may ask for more height than the window has** (`SnapshotRenderer` asserts it
    for every snapshot). `EmptyState`'s message has a 240 pt minimum width, and the inspector's empty state
    sits in a scroll view. Reason: a wrapped message with `fixedSize(vertical:)`, asked for its smallest size
    in a narrow column, reflows to a word a line; measured, the empty inspector asked for 2,195 pt and an
    empty group for 1,835 pt, which pushes the window past the screen.
88. **The sidebar and the inspector are Liquid Glass, so the snapshots draw each on its own into its column,
    and the real window (`make look`) is the judge** (warning 7 for the sidebar). A capture opens the main
    window at 1440 by 900 and clears its frame autosave, so it never writes a window frame into the live
    copy's preferences (the live domain holds Ivan's own saved frame, 1140 by 772 on Sun 11 Oct, which his
    window keeps).
89. **The smart groups are predicates over `statusRaw` (`SmartGroup.predicate`), and Ready holds exactly the
    approved recordings until the platform checks exist (M8, M11b).** "Ready for your yes" reads "Waiting for
    your yes" (design spec C1) in the app, in notices and in Activity's line "is waiting for your yes"; the
    stored raw value `readyForYourYes` never changed, so nothing migrated. `make drop` and `process-in-app.sh`
    accept both phrasings in the log. Reason: one word must mean one thing, and "Ready" now means approved.
90. **The privacy lock fails closed** (`PrivacyLock.decide`, `Recording.isPrivacyLocked`, `ModelRouting.provider`,
    which also returns LM Studio for a nil recording). Until 12 Oct evening: only `kind == .talk` without Serenity;
    since v2 part M5a also only once the people check has run (M6) and found everyone heard agreed and nobody
    unnamed, so today no real recording reaches a cloud model. Never let an unset kind read as "not locked". Reason (12 Oct): v1's rule locked only a
    class or Serenity, while the 16, 20 and 23 Sep classes sat in the live store as kind "unknown", the live
    settings chose the Claude API for all three tasks, and a key was in the Keychain: turning titles on for one
    would have sent a class to Anthropic. Part M5a replaces this with `PrivacyLock`; it must stay at least this
    strict.
91. **`make migrate-check` must hold on any real store, never on what Ivan happens not to have done yet.**
    `StoreMigrationTests` reads the copy with SQLite first (`immutable=1`: the copy is in WAL mode, and a plain
    read-only open read every count as 0), then asserts that every row and stored value comes through, that no
    switch moves, and that a field is at its default only when the copy did not have its column. Reason: on 11
    Oct it asserted "nothing approved, no removed files", which stopped being true the evening Ivan approved two
    talks and removed a recording, and failed the ship gate for every later part with a sound schema.
92. **No capture or development copy may write layout into the live preferences.** All copies share the bundle
    identifier, so AppKit autosave (window frames, split views, the Settings window) lands in Ivan's
    `studio.therowan.prakriti.app` domain. `LayoutAutosave` switches it off under `--sample-data` and
    `--development`, and `capture-window.swift` reads the layout keys before a run and puts back any it changed
    at every exit through `finish(_:)` (Swift scripts do not run `atexit`, measured). Reason: on 11 Oct `make
    look` changed `NSSplitView Subview Frames main` and the Settings window's frame in the live domain.
93. **Only the copy in `~/Applications` may run live.** `make install` asks any other copy running without
    `--development` or `--sample-data` to quit, registers the installed one, then unregisters **every other
    registered copy, running or not** (repo builds, DerivedData, scratch clones), and prints "Only the installed
    copy is registered." A verifier that builds a clone must `lsregister -u` it when done, because Xcode
    registers every build it makes. Reason: from 20:13 on 11 Oct the live watcher was a Debug build in a
    verifier's clone under `/private/tmp`, picked by bundle identifier, running on the live store with no login
    item; on 12 Oct, after the running-copy fix, a quit scratch build was still registered and could be picked
    the same way.
94. **The Viewer's player never takes the keyboard focus** (`UnfocusedPlayerView`, `acceptsFirstResponder` false).
    Reason: in `make look` on 12 Oct, with `AVPlayerView` focused after Return opened a recording, Escape stayed in
    the Viewer; the Viewer handles Space, J, K and L itself (warning 99), and the player's buttons still take clicks.
95. **The transcript is AppKit text (`TranscriptTextView`, an `NSTextView`), and the snapshots never page through
    it** (`SnapshotRenderer` skips a scroll view whose document is `PlayableTextView`). Reason: a word must be
    clickable on its own and a selection must cross lines in up to about 10,000 words, with the system's Find;
    and the first Viewer snapshots paged the 13 Sep transcript into 15 pictures per screen, 200 for one run.
    `textViewDidChangeSelection` ignores the selection AppKit drops while the text is replaced (`building`):
    without it, every rebuild cleared the words Ivan had chosen.
96. **No capture or snapshot of the Viewer shows a talk's picture.** The Original is played from a test pattern
    (`--sample-original=`, `ViewerSnapshotMedia`), the Podcast-ready rendition from a copy of the sample episode
    in a temporary folder (`--sample-output=`), and playback is proved from `--debug-playback-log` lines, muted.
    Reason: PLAN section 11, D1 (frames of Gabriel's talks are measured, not looked at, until it is answered), and
    a check must never play a talk aloud on Ivan's Mac, nor read the studio folder outside the acceptances
    (warning 17).
97. **The window's state lives in the mode's preferences (`AppSettings.windowState`, JSON of `WindowState`),
    never in the store,** and captures and tests never restore it (they use the ephemeral preferences). Reason: no
    SwiftData migration for what is only where the window was, and a capture must never write into the live
    preferences (warning 92).
98. **Every edit from the Viewer goes through v1's paths** (`addCut`, `setTrim`; `keep(_:in:)` only subtracts from
    cuts and widens the trim), and a run of words becomes a cut held clear of the words on each side
    (`TranscriptDocument.span(of:)`). Reason: Parakeet stretches the last word before a pause across the next
    word's start, and a cut to its end took the next word too (`ViewerTests.testASelectionTakesExactlyItsWords`);
    and an approved recording must lose its approval on any change (warning 38).
99. **The Viewer's keys (Space, J, K, L, Escape) are read from the app's event stream (`ViewerKeys`, a local
    `keyDown` monitor installed once at launch), never through SwiftUI's `.onKeyPress` on a `.focused` view.**
    They are taken only while the main window is key with no sheet, the Viewer is open, and the first responder
    is not text (a field being typed in, or the transcript, which handles the same keys itself) nor a control
    reached with Full Keyboard Access. Reason: on 12 Oct the M3b verifier saw Space do nothing in 2 of 5 real
    launches, and the fixer measured 4 of 5 before the change: when the window put the Viewer back at launch, the
    focus set in `onAppear` was not taken, and every playback line read rate 0.00 with the window key and
    frontmost. After the change: 20 of 20 launches played (log line "Playback: key Space in the Viewer").
    Play at the very end starts again from the beginning, because the restored moment can be the end.

100. **The window sees a make's progress at most twice a second, with no exception, and the percent never goes
    back** (`JobProgress.refresh`; `ProgressTracker.snapshot` keeps the highest shown; `finish` waits out the half
    second before 100%). Reason: design spec 3.6.1; on 12 Oct a forced last update made three in one second in
    `make accept-progress`, which now fails on any second with more than two.
101. **A time left comes only from a measured rate: ffmpeg's own progress on a stage whose passes are known, or the
    stage's runs measured on this Mac; never from the first guess, and never from the pace of a stage whose passes
    are not known ahead.** Until then it reads "Working out the time left". Reason: design spec 3.6.1; measured 12
    Oct, the podcast-ready mastering (it measures until it is right, so its passes are not known) showed 8.5 s left
    from its pace when 30 s remained. The first guess (`StageTimings.firstGuess`) only weights the bar.
102. **ffmpeg run by the pipeline gets `-progress pipe:1` and nothing else, and no ffmpeg call reads stdout for
    data** (`Pipeline.tool`; ffprobe is never given it). Reason: the progress lines take over stdout;
    `ProgressTests.testFfmpegReportsItsProgressAndMeasuresTheSame` proves what ffmpeg measures is unchanged.
    Parakeet (0.5.2) prints nothing until it ends when piped (checked 12 Oct), so it is timed, held at 95%.
103. **Pause suspends the running tool (SIGSTOP) and holds the next one at the gate; its time limit moves on by the
    time paused; a stopped tool is continued (SIGCONT) before it is terminated.** Writing, a request to a model,
    cannot be paused, so Pause is not offered then. Reason: Mac warning 14's limit would kill a paused tool, and a
    stopped process holds SIGTERM until it runs, so Quit or a limit would leave it stopped forever.
104. **Stop by hand is Ivan's choice, never a failure: the recording's intent is cleared so no look starts it again,
    a recording with files from an earlier make keeps them and its status (warning 29), and it is not counted as
    a try.** Reason: an automatic make that stops counts as a try and restarts at the next look within 5 minutes
    (warning 27), which is not what Stop means.
105. **`StageTiming` never learns the wait for the file (`.complete`) or a stage that was paused, keeps the last 10
    runs, and is seeded once from the store's own steps.** Writing is the average of its runs, not per minute.
    Reason: the wait is 60 s whatever the Mac; a paused stage's seconds include the pause; writing took 1,608 s on
    15:48 and 1,456 s on 55:39 (BUILD-LOG 11 Oct), so per minute it would be wrong by three times.

106. **The toolbar's Activity button draws its ring as a picture (`ProgressRing.image`) inside a `Label`, never as
    SwiftUI shapes, and reads cached numbers (`PipelineRunner.usual(for:)`), never the store, while it draws.**
    Reason: kept because it is cheaper to draw, but **the reason first given here was wrong**. It said shapes in the
    toolbar swallowed the second Command-Option-I; the verifier then saw that key fail in 2 of 5 runs with the
    picture. The key was never lost: see warning 107 for the cause.
107. **The inspector's `.inspector(isPresented:)` binding writes through `AppModel.inspectorReported(_:)`, never
    straight into `inspectorShown`; a report that contradicts what was asked less than 1 s earlier is set aside and
    the window redrawn (`inspectorRedraw`).** Reason: measured 12 Oct (M4a fix) with a call stack on every change of
    `inspectorShown`: the second Command-Option-I reached the menu and set it to true every time, then the first
    hide's animation ended and SwiftUI (`SplitViewController.splitViewItem(_:didChangeCollapsed:animated:)`) wrote
    false over it. That happened in 6 of 6 runs; the check failed only when the write landed before the menu was
    read (2 of 8 runs here, 2 of 5 for the verifier), so it looked like a lost key. With the guard, `--keys`
    passed 13 of 13 runs, the log shows the late report set aside in each, and the inspector is on screen 1.5 s
    later. Dragging the inspector shut still reaches the model (it is not within 1 s of a key). Do not "fix" this
    by waiting longer in the check: the check now reads the inspector again 1.5 s later on purpose.
108. **The capture check never stops a make and never changes a status; it only measures and says.** It is the
    first step once the file is complete (`.capture`, before the 60 s test rule, so a test keeps its check), its
    report is kept on the recording whatever the outcome (`captureJSON`), and a track that ffmpeg cannot read is
    written down as not measured rather than failing the make. Reason: every studio file so far has one track
    with one microphone in both channels (the 13 Sep talk measures left minus right at -91 dB), so a check that
    held recordings back would hold every one; the plan's answer to poor input is a warning and a tip in Checks
    (REQUEST item 1), and the sound check stays the only rule that refuses a recording. Each volumedetect in the
    per-track ffmpeg call is named (`volumedetect@level`, `@difference`) because ffmpeg prints the two in either
    order, each once empty first; and ebur128 runs with `framelog=verbose`, or it prints ten lines a second into
    the text that is read. Recordings found before M4b get **Check Capture** in Checks, never a check by
    themselves (PLAN rule 2.1.7).
109. **A cloud provider is a `CloudModelClient` and takes only a `CloudPayload`; a `CloudPayload` is made only by
    `PrivacyLock.release` (its initializer is `fileprivate` to `PrivacyLock.swift`); the writer reaches a cloud
    client only through `LockedCloudClient`.** Never make a cloud client a `LanguageModelClient`, never add a
    second way to build a payload, and never send from the key test anything but `PrivacyLock.keyCheck()`.
    `release` runs the decision again, replaces every name Apple's tagger finds that is not a consenting named
    person's (`NameTokens`, `[[NAME-n]]`, each written form put back exactly in the answer), always replaces muted
    names, every named person who has not agreed and "Serenity", then reads the text as it would be sent and
    refuses if a name, an always-replaced name or a withheld span is left. A refusal is a non-retryable failure,
    logged by its reason only, never the text. Reason: PLAN 2.2 rule 1 and warning 19: the check must be on the
    data and impossible to skip, not a reviewer remembering. Measured 12 Oct: the tagger missed "Serenity" in the
    writing prompt's own sentence ("The school's teachers are Gabriel and Serenity.") while finding Gabriel, which
    is why she is always replaced; on the 13 Sep talk's text it replaced 20 of 21 name mentions (95%, 7 of 8
    names, reference made by Qwen3.8-27B on this Mac; BUILD-LOG "v2 part M5a"). `ProviderTests` proves each
    refusal, and `testTheUnsafePathCannotBeWritten` fails if any other file writes `CloudPayload(`.

110. **Anthropic is spoken to only in the current request shape (`AnthropicClient`): always `stream: true`, `max_tokens`
    64,000, no `thinking` field at all, `output_config.effort` set per task (writing `high`; tags, summaries and the
    key test `low`), and `fallbacks: "default"` with the `server-side-fallback-2026-07-01` header only for the models in
    `AnthropicClient.fallbackModels`. The model pop-up keeps only models whose Models API entry says
    `capabilities.effort.supported`.** A `refusal` or `max_tokens` stop, an `error` event, a stream with no stop reason or
    empty text is a failure, never a result. Reason: claude-api reference (cached 6 Oct, read 12 Oct): on Opus 5.5 an
    explicit thinking setting is a 400 at every effort and effort defaults to `medium`; older models listed by
    `/v1/models` reject effort or the fallback beta, so offering them would make every call a 400; warning 34; and a
    non-streamed call hung silently twice (engine warnings). `ProviderTests.testTheAnthropicRequestHasTheCurrentShape`
    pins it.
111. **OpenAI is spoken to only through the Responses API (`OpenAIClient`, `POST /v1/responses`, `stream: true`,
    `store: false`), with no model id in the code and no `reasoning.effort` sent.** The pop-up is `GET /v1/models`
    filtered by name to text models (`OpenAIClient.filter`), because that list carries no capability field. A
    `response.refusal.delta`, `response.incomplete` (cut off or filtered), `response.failed`, an `error` event, a stream
    without `response.completed`, or empty text is a failure. Reason: PLAN M5 (no hard-coded id; read the docs on the
    day: developers.openai.com, 12 Oct, event names in the client's header); effort values differ by model and none
    are documented on that page, so sending one could fail every call. Built without a real key: the first call with
    one is the verification still owed (BUILD-LOG "v2 part M5b").

112. **The people file holds boxes and times only: no landmarks, no embedding, no picture, for anyone** (`PeopleFile`; a
    box is `[time, x, y, width, height, confidence]`). `PeopleTests.assertNoPrintAndNoPicture` fails on any list of 128 or
    more numbers or any picture word, and `make accept-people` runs it on every real people file and `file --mime-type`
    on everything under Application Support. A picture is kept later only for a named person who may appear (plan
    section 5); every other face is cropped live (`FaceCrops`, memory only, emptied when another recording is shown).
    Reason: a stored crop or print of every face is a collection of students' faces, the exact thing the biometric
    decision forbids (REQUEST, research-people.md 5.1, plan review item 8). Files under `People/` never name a network
    type or a cloud client (`RulesTests.testFaceWorkCannotReachTheNetwork`).
113. **Every face step works in its own job folder (`Application Support/Jobs/<uuid>/`), deleted when it ends, and a
    launch deletes every job folder it finds right after taking its mode's lock and before anything else.** Only the
    copy holding the lock cleans, so a second copy can never delete a running job's folder. Reason: research-people.md
    5.4, a crash must not leave a pass's work behind; proved by `scripts/people-crash-check.sh` (SIGKILL mid-scan, the next
    launch's "Deleted 1 job folder" line comes before its first "Checked" line).
114. **"Other people appear" means two or more faces in one sampled frame (`FacesFound.mostAtOnce`), never the number of
    rows.** Rows join tracks by place and size, so one person who walks around can make two rows (the 6 Sep talk: one
    face at a time, two rows), and two people who take turns in one place could make one. Reason: without a face
    print nobody can be told apart, and counting faces in one frame needs no guess about identity. Faces alone never
    open the privacy lock (`PeopleFacts.from` returns `.notChecked` until the voice step ran too, M6b): a student can be
    heard unseen.
115. **The diarizer never writes or keeps a voice print: `Diarizer.configuration()` is the only configuration built,
    `export.embeddingsPath` stays nil and chunk embeddings off, only times leave `Diarizer.diarize`, and FluidAudio's
    offline mode is on before its models load from `~/Library/Application Support/FluidAudio/Models/speaker-diarization`.
    Never call `OfflineDiarizerManager.prepareModels`.** Reason: with `embeddingsPath` set FluidAudio writes every
    embedding to disk, a voice print of everyone in the room (research-people.md 2.5); and `prepareModels`, on a failed
    load, deletes that model folder (Hark's too) and downloads it again, which is a fetch nobody said yes to (PLAN 2.2).
    `VoicesTests.testEveryDiarizerConfigurationExportsNoEmbedding` reads the field; `make accept-people` checks the model
    folder is unchanged by size and date.
116. **The diarizer keeps overlapping speech (`exclusiveSegments` and `embedding.excludeOverlap` both off).** Reason:
    measured 13 Oct on two-people-mixed.mp4, a voice that speaks only over the teacher (0:30 to 0:48.5) vanished into the
    teacher with FluidAudio's defaults (one voice) and was found exactly with both off (Voice 2, 29.9 to 48.5 s). That
    voice is a student heard while the teacher talks; missing it would open the privacy lock. Change these only with that
    fixture measured again.
117. **The people check counts as run only when both the face step and the voice step ran for the recording, and every
    face row, voice and glimpse Ivan has not named counts as someone unnamed (`PeopleFacts.from`).** A name whose person
    was removed from Settings counts as unnamed, never as agreed. Who Is Teaching names only the voice that speaks most
    and its linked face (or, with no link, the face on screen most, if no other voice is linked to it); a name crosses a
    link; a hand-given name always wins. Reason: PLAN review item 5 and Mac warning 90: the lock fails closed, and a
    second row of the teacher (warning 114) costs Ivan one more naming, while a guess would cost a student's words in a
    cloud request. Measured: the 13 Sep talk, Gabriel teaching and agreed, stays local (10 unnamed face rows after 12:39,
    and it says "Serenity").
118. **The audio output check is the only code that holds a voice embedding, and only in memory, for the length of one
    `AudioOutputCheck.run`** (`Diarizer.listen` returns `Heard` with each voice's average embedding; the check compares and
    drops them; its decoded sound lives in a job folder deleted when it ends). Never write a `Heard`, a centroid or a
    similarity table anywhere but the log lines of numbers it already writes. Reason: PLAN D2 and research-people.md 2.5,
    no print of anyone is stored; `make accept-people` checks the store's JSON and every people file for a list of 128 or
    more numbers.
119. **Everyone starts as Include (`PeopleChoices.defaultChoice`).** Change it only on Ivan's word. Reason: his note of Mon
    12 Oct (PLAN section 11): the participants signed releases, so the choices are editing choices, not a privacy gate. The
    plan's section 5 default (Leave Out for anyone unnamed) predates the note. The notice says so in its fixed sentence
    (`NoticeBuilder.otherPeopleBody`), so changing the default means changing the notice and Help 07 in the same commit.
120. **Leave Out cuts time, never a track, and fails closed** (`LeaveOut.plan`): every word the left-out voice touches goes
    whole, two of its stretches under 1 s apart are one cut, a gap of 0.5 s or less before it is taken whole (to 0.03 s of
    the word before), a longer pause by 0.25 s; toward the next word the cut stops `wordLead` (0.24 s) before Parakeet's
    start for it, never short of the words it takes. **Then each edge settles on the sound itself** (`EdgeLevels.quiet`,
    the first audio track, the one the episode is made from, read only around the edges): the end moves to the start of
    the quiet (20 ms windows within 10 dB of the quietest) between the left-out voice's own end and the end the words
    gave, the start to the end of the quiet on its side, so each 15 ms fade lies in the quiet. Where there is no room to
    search, or no sound was read, the cut reaches `voiceTail` (0.05 s) beyond the voice's own stretch. Speaking at once
    is cut, not kept on one microphone. Someone left out with no voices from this make stops the make
    (`Pipeline.leaveOut`). Reason: research-people.md 3.4 and 3.5 (a voice bleeds into every microphone).
    **Never place a cut's edge on Parakeet's word times alone:** they come in 80 ms steps and a word's start is often
    late. Measured 13 Oct (M6c verifier, then the fix): the cut ended at 48.77 s on two-people-tracks, inside Gabriel's
    "business" (Parakeet put the word at 48.80 s on the remade file, 48.64 s on the clean clip), and the word was lost
    in every episode, every run. **Nor at the quietest point:** before a voiced "b" the quietest 20 ms is the stop's own
    closure; with the fades, ends at 48.505 to 48.535 s keep the word and ends at 48.54 to 48.55 s lose its "b" (Parakeet
    hears "isness"). The earlier "isness" reading, put down to a tail of "teaching", was this same fault. With nobody left
    out and nothing muted the step is not planned and the chain is unchanged (warning 30).
121. **A muted name is silenced by one `volume` filter on the original's clock before anything is cut
    (`Mastering.muteFilter`), worked out per audio frame, with each span padded 0.06 s (`LeaveOut.mutePad`), and written
    "[name]" by `EpisodeTranscript.cues(mutes:)` in every file that carries words, Write Again and Update Podcast-Ready Files
    included (`Recording.madeMutes`).** Reason: a frame is about 21 ms, so without the pad the start of a name could sound;
    measured on the 13 Sep talk, the muted name's stretch of the episode reads digital silence. A name of two words is
    one [name].
122. **Approve waits for the choices on the page to be in the episode (`Recording.choicesPending`, a signature of who is left
    out and which names are muted), for the audio output check to pass, for every name said aloud to be kept or muted, and,
    with someone left out of a mixed track, for the changes of voice to be marked as listened to** (`ApprovalCheck`).
    Reason: warning 36 (a yes covers exactly what was made), research-people.md 3.6, PLAN section 5 (zero student names
    in anything public), warning 14 (a mixed track is a best guess).
123. **A card picture is written only by `CardPicture.make`, only after the face step ran, and only once Vision has
    looked at the finished picture and found every face inside the box of someone included at that moment** (a face in a
    hidden region, or one the people pass never saw, refuses the frame; no frame passing means the plain tile). Reason:
    Ivan, Mon 12 Oct, "Faces of anyone not Included are never in a thumbnail", and design spec 3.1.2; a face the pass
    missed is a face nobody decided about, so it fails closed. A face is hidden in pictures when its choice is Hide Face or
    Leave Out for **any** output (`Recording.hidesFace`): the card is not an output, so it takes the strictest.
    `Thumbnails/<recording id>.jpg` is the only picture Prakriti keeps (PLAN M6 check 7; `make accept-people` fails on any
    other image under Application Support), written through a job folder and never into a watched folder (warning 12).
124. **Every change of choice or name deletes the card picture at once and makes it again in the background, one at a
    time per recording, the newest last** (`AppModel.refreshCardPicture` waits for the one before it). Never skip the
    deletion or run two at once. Reason: a picture made under older choices must not stay on screen while a new one is
    chosen, and an older make that finishes late would otherwise overwrite a newer one with a face Ivan has since hidden.
    Upgrading never makes card pictures for older recordings (PLAN rule 2.1.7): Check People or a make does.
125. **Hiding follows each hidden face at the full frame rate between sightings (`FaceFollower`, Vision's
    `TrackObjectRequest` started again from every sighting), and also keeps each sighting within 0.5 s of the frame and
    the last place a lost face was seen, plus the head of any body there.** Never hide from held or interpolated boxes
    alone. Reason: research-people.md 3.2 and plan review item 12; measured 13 Oct on a test square moving 300 px a second,
    the followed box overlapped it 0.84 to 0.91 between sightings, the held box alone 0.14 to 0.60. `FaceHide` pads 1.6
    times, blurs 30% of the face's width and pixelates 5 blocks across the face (research: at least a quarter, at most 8).
126. **The People overlay shows the Original as recorded and hides nothing; its boxes come from the people file, two a
    second, moved in a straight line between sightings, and a hidden face's box is dashed with its choice in words.**
    Reason: design spec Q3 (Ivan decides who appears by seeing them) and the rule that color is never alone. The toggle is
    white on clear glass tinted dark: found by looking at the real window 13 Oct, accent text on clear glass over a bright
    picture could not be read.


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
  engine has no Dock icon. **That reason is stale:** Prakriti for Mac has had a Dock icon since v1 (and
  the cut disc since v2 part M1). v2 still shows no badge by choice (`docs/v2/PLAN.md` section 5); a
  badge counting the recordings that wait for Ivan's yes is now possible, and is his decision. A click opens the review address carried in `userInfo` with `NSWorkspace`
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
