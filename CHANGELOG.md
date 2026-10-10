# Changelog

Newest first. One entry per working session. The diff records what changed; this file records
why. Weekdays computed with `date(1)`.

---

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
