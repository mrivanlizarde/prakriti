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
| `mac/` | **Prakriti for Mac**, the native app (SwiftUI, SwiftData). Milestone 1 (skeleton) landed Sat 10 Oct: window, sidebar, menu bar menu, data layer, snapshot tests. No watcher or pipeline yet | Read "Prakriti for Mac" below, then `docs/BUILD-LOG.md` |
| `docs/BUILD-LOG.md` | One dated entry per milestone of the Mac app: what was built, every check with its measured result, decisions, and what Ivan must do | A new session resumes from its last entry |

Later, from the Up Next template: `migrations/`, `test/`, `scripts/smoke.mjs` (production refusals
tested as refusals), `scripts/backup.mjs`.

### Facts for the build

| Fact | Value | Status |
|---|---|---|
| Apple team ID | **LD587PB2H8** (07 l.509-511). K55TBYNKUC is the identifier of Ivan's Apple Development certificate; `research/02` l.751 calls it the team and is wrong | Measured |
| Bundle IDs | Prakriti for Mac is `studio.therowan.prakriti.app` (set by the v1 build prompt, signed since Sat 10 Oct). `studio.therowan.prakriti` is the label of engine v0's LaunchAgent, so the app does not reuse it. The login-item identity for the watcher is decided in milestone 3 | App id in use; login item open until milestone 3 |
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

## Engine v0: running now on Ivan's MacBook Pro (since Thu 8 Oct)

The first slice of the engine, built the evening of 8 Oct so Prakriti could be used before the Swift
engine exists: `engine/prakriti.mjs` (Node, no dependencies), run by the LaunchAgent
`~/Library/LaunchAgents/studio.therowan.prakriti.plist` at login, kept alive.

It watches the Studio Recordings folder and `~/Prakriti/Drop`, waits until each file is truly
finished (iCloud download, size stable 60 s, opens, last seconds decode), files clips under 60 s as
tests, refuses silent recordings with a "Needs a Decision" notification, then makes
`episode.mp3` (mono, -16 LUFS, peak under -1 dBFS), `transcript.txt/.srt/.vtt` (Parakeet, with a
coverage check) and `REPORT.md` in `~/Prakriti/Outputs/<recording>/`. Notifications: found,
started, ready (macOS shows them as Script Editor). **It publishes nothing and does not yet label
speakers or mute names:** read REPORT.md and listen before anything goes out.

```bash
cd ~/Code/prakriti/engine && node prakriti.mjs status
```
```bash
cd ~/Code/prakriti/engine && node prakriti.mjs run "/path/to/a recording.mp4"
```
```bash
tail -20 ~/Prakriti/log.txt
```
Stop it: `launchctl bootout gui/$(id -u)/studio.therowan.prakriti`. Start it again:
`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/studio.therowan.prakriti.plist`.

Load-bearing: the limiter must keep `level=disabled`, and mono + sample rate stay **inside** the
filter chain before it. Either mistake put the peak over 0 dBFS in testing on 8 Oct.

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
`docs/NEXT-PROMPT.md`. **Milestone 1 (skeleton) is done, Sat 10 Oct:** a signed SwiftUI app with a
main window (sidebar: Today, Recordings, Sources, Outputs, Models, Activity, Settings), a menu bar
menu (status, Open Prakriti, Pause All, Settings, Quit), a SwiftData store with Source, Recording,
OutputSetting, Run and LogEntry, and tests that draw every screen to PNG. **It does not watch or
process anything yet:** engine v0 still does all the real work until milestone 3. Progress, checks
and decisions per milestone are in `docs/BUILD-LOG.md`.

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

`make test` runs every unit test (data, rules, copy and type checks, and the snapshot render).
`make snapshots` writes every screen, light and dark, at the window's real size (1180 by 760) to
`screens/mac/<milestone>/` (gitignored), plus an `-end` picture for any page taller than the
window. `make check` builds, tests, then launches the app, lets it close its own window and
proves it is still running 15 seconds later. **Then open every PNG and look at it.** Reading the
code is not verification, and neither is a passing test.

### Where things live

| What | Where |
|---|---|
| Project definition (source of truth) | `mac/project.yml`; `make generate` rebuilds `Prakriti.xcodeproj`, and both are committed |
| App code | `mac/Prakriti/App` (launch, paths, settings, log), `Model` (vocabulary, SwiftData models, store), `Views`, `Fixtures` |
| Tests | `mac/PrakritiTests`: `ModelTests`, `RulesTests`, `SnapshotTests` |
| The built app | `mac/build/Build/Products/Debug/Prakriti.app` (gitignored) |
| Store, development mode | `~/Library/Application Support/Prakriti/Development/Prakriti.store` |
| Log, development mode | `~/Library/Logs/Prakriti/Development/<date>.log`, one line per event |
| Working folders, development mode | `~/Prakriti/Dev/Drop`, `~/Prakriti/Dev/Outputs`, `~/Prakriti/Dev/Approved` |
| App icon | Drawn by `mac/scripts/make_icon.swift` from the front door's mark (an ultramarine dot on stone) |

### Load-bearing warnings for the Mac app

1. **`AppMode.current` stays `.development` until the milestone 3 switch-over.** In development the
   app uses only `~/Prakriti/Dev` and its own store, and never adds the Studio Recordings folder (a
   test enforces it). Reason: engine v0 owns Studio Recordings and `~/Prakriti/Drop` and is making
   episode 1 for Fri 23 Oct; two watchers on one folder would process a recording twice and notify
   twice. The switch-over retires v0's LaunchAgent the same day, and the log says so.
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
   other font, any sidebar badge and any small control. Reason: macOS text styles are 10 to 13 pt,
   and Ivan's floor is 12 with a 17 pt body.
6. **No em dashes, no "Processing", no "we"** in any app string; a test reads the sources and fails
   on them. Reason: Ivan's standing rule, and SCOPE 8.3's copy rules.
7. **The snapshots compose the sidebar.** Liquid Glass cannot be drawn into a bitmap (it comes out
   solid white), so the test draws the window, paints the sidebar column with the system window
   background, draws the same `Sidebar` view on top, and redraws the title bar buttons. Switches
   and selected segments draw grey because a test window is never frontmost; the knob's side shows
   the state (right is on). Reason: so nobody "fixes" the app for a capture artifact. Look at the
   real window with `make run` once per milestone for the glass itself.
8. **Tests never touch Ivan's data.** Under tests `AppModel.launch()` uses an in-memory store,
   throwaway preferences and no log file. Reason: a test run must never write into the real store
   or `~/Prakriti`.
9. **SwiftData: every stored property has a default, and enums are stored as raw strings.**
   Reason: additions then migrate on their own, and predicates over raw strings are the reliable
   part of SwiftData. The first change that is not an addition brings a `VersionedSchema`.

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
  silently loses its permission. And a plain `KeepAlive` would make Quit do nothing.
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
