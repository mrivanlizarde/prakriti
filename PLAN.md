# Prakriti: the plan

**Current state on Thu 8 Oct 2026, revised after feedback rounds 1, 2 and 3.** This file says what
gets built, in what order, by whom and by when. What each feature is and why it exists lives in
[docs/SCOPE.md](docs/SCOPE.md). The settled decisions live in
[research/DECISIONS.md](research/DECISIONS.md), which wins wherever anything else disagrees. What
changed and why, one session at a time, lives in [CHANGELOG.md](CHANGELOG.md). Every critic's finding
from the feedback rounds, and the reasoning behind each change, lives in
[docs/FEEDBACK.md](docs/FEEDBACK.md).

- Every weekday in this file was computed with `date(1)`, never recalled. Times are Pacific
  (America/Los_Angeles); US daylight time ends Sun 1 Nov 2026.
- Feature IDs such as ENG-03 or PRV-05 point to the catalog in SCOPE §5. Question IDs such as Q-G2
  point to the open questions table at the end of this file.
- Status words: **Decided** (settled in DECISIONS.md or by its owner). **Proposed** (Sonny's
  recommendation, change it freely). **OPEN** (a named person's call, always shown with a
  recommended answer). **Gated** (waits for a named yes). **Owner action** (a person does it, not
  code).
- Owners are four: **Sonny** (builds and verifies), **Ivan** (operates, decides architecture and
  money, sends anything outward, and publishes every episode through Fri 6 Nov, by hand for episode
  1 and then with his release script, and makes every submission), **Gabriel** and **Serenity** (the
  teachers, their consents and their approvals). One more role appears from round 1: **the account
  holder**, whoever holds the Google account that owns the YouTube channel (Q-GS7).
- **Sonny is Claude.** Until Serenity says yes to Q-S13, no Claude session, Sonny included, opens a
  transcript, title or description of Serenity's teaching or of any class. Sonny sees only counts and
  categories printed by a script on the Mac.
- **Lanes**, defined once. Lane 1 is podcast audio from the studio and the archive, plus archive
  talks on YouTube changed by new metadata and visibility (after Fri 6 Nov). Lane 2 is studio video,
  in Phase 3. The word stays in this file and in SCOPE; the public pages never use it.
- **Teacher-only** is defined once, in Gates below.

---

## Where things stand today

| Area | State on Thu 8 Oct |
|---|---|
| Name | Prakriti. Decided Thu 8 Oct |
| Research | Nine tracks finished (`research/01` to `09`), reconciled into DECISIONS.md |
| Scope | `docs/SCOPE.md` written: 244 features in 15 areas, 31 rejected or retired with reasons; revised for feedback rounds 1 to 3 |
| Feedback | All three rounds done Thu 8 Oct: 141, 127 and 108 findings from six critics, each decided with a reason, recorded in `docs/FEEDBACK.md` |
| Code | Worker (`web/src/index.js`) and front door (`web/public`: `index.html`, `roadmap.html`, `404.html`, `robots.txt`, `assets/`) written, not deployed; screenshot script `scripts/shoot.mjs` |
| Front door | Not live. It goes live through the pre-deploy sequence (row 21) after Ivan looks at the screenshots and says yes. The Fri 9 Oct messages never wait for it |
| Engine | Not started. v1 runs on Ivan's MacBook Pro (Q-I1) |
| Repository | `git init` done. No commits, no remote |
| Accounts | R2 not enabled in Ivan's account, and the current `wrangler` login shows no R2 scope (07 l.394). No Developer ID certificate; Ivan's Apple team ID is LD587PB2H8. YouTube not connected. The podcast's home is not decided: a new Yoga Marga show at its own address, in a new Cloudflare account registered to a Yoga Marga address, is recommended (Q-G2, Q-G26). The school's email runs on Google Workspace (its public mail records, checked Thu 8 Oct); which account owns the YouTube channel is for Serenity to confirm (Q-GS7) |
| Studio input | Nothing usable recorded since Wed 23 Sep. No studio recording of Serenity yet |
| Archive | 958 videos, about 1,175 hours, Nov 2023 to May 2026, on the Yoga Mārga School channel. About 694 are complete inside a partial download on Ivan's Mac (about 253 GB); that download's link likely expired today. The 694 are the primary input; the re-run is off the critical path. None of the archive is transcribed yet; only the studio sessions are. The Takeout is about 388 GB (from its own part sizes). **It does not all fit on Ivan's Mac:** about 811 GiB is free (`df`, Thu 8 Oct, with the partial download still on disk), and the salvage output (about 250 GB), the re-run zips (about 388 GB) and their extraction together come to more than that. An encrypted external SSD of about 2 TB is recommended (Q-I17) |

## The goal, in numbers

From SCOPE §1. These are proposed, and the team changes them.

| For | Number | How it is checked |
|---|---|---|
| Gabriel | **Proposed: 25 archive talks as podcast episodes by Fri 6 Nov 2026,** counted on the feed, from teacher-only talks and self-contained stretches of them (PIP-34). Ivan confirms the number with Gabriel on Fri 9 Oct, with two counts (row 5): talks from sessions with no students present, and talks from sessions where students only listened, which wait on Serenity (Q-S30). If the pool does not clearly exceed 25 after some talks fail the privacy or accuracy checks, Ivan resets the number in that same message. Fallback: "10 by Fri 6 Nov, and 25 once Serenity's talks are cleared." Mon 26 Oct is a confirmation only. YouTube is not counted: archive talks go to YouTube after Fri 6 Nov | Counted on the podcast feed: each episode is read back from the feed, which validates |
| Gabriel | **Proposed target:** every new studio recording ready for a yes within 72 hours of the recording ending, once the engine runs on an always-on Mac. Going live also needs a yes; the median time from ready to live is measured, with no promise | Measured by the web app from the recording's end to "Ready for your yes". Phase 3 check: three studio sessions in a row |
| Gabriel | **Proposed: under 2 minutes of Gabriel's time per piece, after Ivan's listen.** It becomes his goal only if he says yes in his reply to the Fri 9 Oct message (Q-G19). The figure first appears as a proposal in research (09 l.71), not in anything he said | Measured by the web app, from opening the review page to the approval, from Mon 26 Oct |
| Serenity | **Zero student voices and zero student names in anything public (Serenity's condition)** | A privacy receipt per piece; Ivan listens at the queued moments of every archive piece before it reaches its approver, logged with who and when; any piece in which an Other voice was found needs Serenity's receipt |
| Serenity | **Each of Serenity's reviews is prepared so it can take about 5 minutes; nothing is published to meet a clock** | Measured the same way, and never used to hurry her |
| Ivan | **Run cost per piece visible on the home screen**, and Prakriti priced before lane 2 (studio video) switches on | The cost meter (OPS-04, after Fri 6 Nov) and the money gate below |

---

## The next few days (Thu 8 Oct to the week of Mon 12 Oct)

Items due Fri 16 Oct and later are in Phase 0 below. Rows 1 to 15 keep their numbers from the first
version of this plan; rows 16 to 20 were added in round 1, rows 21 to 24 in round 2, and rows 25 and
26 in round 3. **The table runs in the order things happen,** so row 23 (the sizing) and row 5 (the
count) sit ahead of row 4 (the message to Gabriel); the numbers are kept so other documents can point
to them.

| # | What | Owner | Due | IDs |
|---|---|---|---|---|
| 1 | Build the front door and the roadmap page; render them at 390, 768 and 1440 px in light and dark and look at every image; grep for em dashes. Written Thu 8 Oct; rounds 1 to 3 applied the same day | Sonny | Thu 8 Oct | WEB-01 to WEB-05 |
| 2 | Look at the screenshots and say yes or no to putting the front door live | Ivan | Inside row 21 | WEB-01 |
| 3 | The first commit and a private remote, before the first deploy, as steps of row 21. The `.gitignore` edit comes first, because `research/01` to `09` name students and one student's family detail (07-infra l.26, 96, 101; 06-apis l.90; 01-conversations l.431, 436); the call transcript is already ignored. `BRIEF.md` and `DECISIONS.md` are grepped for student names before they are staged | Sonny, on Ivan's yes | Inside row 21 | SET-11, PR-19 |
| 23 | **First on Fri 9 Oct, before the two messages.** Ivan books build sessions through Fri 6 Nov and lists his travel dates from Mon 19 Oct to Fri 6 Nov (OPEN for Ivan; none are written here). Sonny then sizes the work in sessions and ends the sizing in a written cut line ("The cut line" below). If the set above the line does not fit the booked sessions, Ivan books more sessions or resets the number in that day's message | Ivan, then Sonny | Fri 9 Oct, first | "The cut line", "Time it takes" |
| 5 | Count Gabriel's qualifying talks, as two numbers: (a) talks from sessions with no students present; (b) talks from sessions where students only listened, which wait on Serenity's Q-S30. Each number also says how many are already among the 694 salvaged files. The same pass gives two more facts: how many qualifying talks come from sessions where others were present, which is how many privacy receipts Serenity can expect in the week of Mon 26 Oct (told at her first meeting); and a substitute third release sample, another Gabriel-only archive talk, in case no Business of Yoga recording has Gabriel speaking alone (01 C-11 names Serenity in one). **Built by a script on the Mac that prints counts and categories only,** because until Q-S13 is Granted no Claude session, Sonny included, opens a transcript, title or description of Serenity's teaching or of any class. Never a guess: the message carries counted numbers or no number. First metadata screen (reasoner, Thu 8 Oct, counts only): 35 of 958 mention Gabriel or Gab; 31 of those do not mention Serenity and are not private; 5 of the 31 carry no class or session words; the 31 total about 37.5 hours. Metadata is a weak signal; Ivan reviews titles on the Mac before the number is sent. No title is ever copied into a document | Sonny (the script), Ivan (the titles) | Fri 9 Oct, after row 23, before row 4 | ARC-01, Q-G19, Q-S30 |
| 4 | **One message to Gabriel,** sent whatever the state of DECISIONS v2, because it quotes no spine text. It carries: the correction (the archive is not transcribed yet, only the studio sessions are, and the podcast has been on the list since September); podcast first, starting with the Sun 6 Sep talk; **the counted number from row 5, with the reset if it is short:** proposed 25 archive talks as podcast episodes, counted on the feed, with the fallback "10 by Fri 6 Nov, and 25 once Serenity's talks are cleared"; the proposed "under 2 minutes of Gabriel's time per piece, after Ivan's listen", his goal only if he says yes; that his yes to podcast first also covers public audio of his own talks and Claude reading the text of his own talks, with names replaced; the one line *Reply "yes to the suggestions" to accept every row that has one, or name the ones you would change.*; the show name (Q-G26) and the one listener ask (Q-G7), due the day before the studio visit, with Ivan's three suggested names and two suggested asks; **every money statement in the Sun 6 Sep talk, each with its time** (Q-G8), in this private message only and never quoted on any page (the reasoner found them by character position in `2026-09-06 18-06-33.txt`, so Sonny re-finds them in that transcript and gives the times); Q-G27, with how it differs from Q-G8; one information line, "One story about a student is cut from episode 1 under the student rule, unless Serenity answers otherwise first."; the voice clip question (Q-G10b, requested by Fri 16 Oct); the yes to the podcast address cost and the Cloudflare sitting at the studio visit (Q-G2); two questions asked privately and never on the page (Q-G11, the drives; Q-G15, the Fathom links); closing the 08-11 YouTube repurposing promise (01 D-13): the 25 are podcast episodes, and YouTube follows after Fri 6 Nov; a fixed day and time for the weekly call (row 24); and the roadmap link filtered for him (`/roadmap?for=gabriel`) if row 21 is done when Ivan sends it | Ivan (Sonny drafts it in his voice) | Fri 9 Oct, after row 5 | Q-I6, SET-21, Q-G1, Q-G19, Q-G26, Q-G7, Q-G8, Q-G27, Q-G10b, Q-G2, Q-G11, Q-G15 |
| 6 | **One message to Serenity,** from Ivan directly (nothing of hers goes through Gabriel), sent whatever the state of DECISIONS v2: the first look at the archive, built from counts and categories a script prints on the Mac; a request for her **first meeting** with Ivan, 30 to 45 minutes in the week of Mon 12 Oct, and word that a **second**, 30 minutes on Tue 27 Oct, follows the fuller assessment; and one confirmation (row 16, Q-GS7). Her other questions are asked at the meetings, not in the message | Ivan (Sonny drafts) | Fri 9 Oct | ARC-08, Q-GS7 |
| 7 | Confirm the engine runs on Ivan's MacBook Pro for now | Ivan | Fri 9 Oct | Q-I1 |
| 8 | Move the 10-07 transcripts out of the shared iCloud folder. They hold students' personal details and sync to everyone in the share | Ivan | Fri 9 Oct | SET-10, Q-I11 |
| 9 | Reply to podcast first, starting with the Sun 6 Sep talk, and to the numbers as sent in row 4, including the proposed 2 minutes | Gabriel | Mon 12 Oct, or at the studio visit if that comes first | Q-G1, Q-G19 |
| 10 | Decide the archive drive: an encrypted external SSD of about 2 TB (cost to price), attached before the re-run lands; the salvage output and the re-run go there. With no drive: extract part by part, skipping private entries, and delete each re-run zip after its entries verify against their hashes, with Ivan's yes | Ivan | Mon 12 Oct | Q-I17 |
| 11 | **The Takeout re-run, off the critical path,** because the 694 salvaged files are the primary input. The account holder named in Q-GS7 requests it on Wed 14 Oct, signed in on Ivan's Mac. The parts then download over one to three days, with the Mac on power and a wired network, one part at a time in Chrome, each part's size checked. The account holder's session stays on Ivan's Mac until the last part's size verifies, then signs out. **Skipped** if the count (row 5) shows the qualifying talks are already among the 694 salvaged | Account holder (Q-GS7), with Ivan | Request Wed 14 Oct; downloads over one to three days | SET-01, Q-G20 |
| 12 | Pull the complete videos out of the partial download, onto the external SSD once attached. It does not copy anything in the Private Meetings playlist, anything marked private, or anything titled as a meeting room | Sonny | Starts this week | SET-02, PRV-08 |
| 13 | Turn on Keep Downloaded for the studio folder and confirm FileVault is on | Ivan | Mon 12 Oct | SET-09 |
| 14 | Enable R2 in Ivan's Cloudflare account (a billing step), with billing and usage notifications for Workers, R2 and D1. Then run `wrangler login` again and check it with `wrangler r2 bucket list`, because the current login shows no R2 scope (07 l.394) | Ivan | Fri 16 Oct; sooner unblocks more | SET-07, Q-I2 |
| 15 | Start the engine skeleton in `mac/`, after the one-page engine API contract and the process-model spike (Phase 0 below) | Sonny | Phase 0 exit, Fri 16 Oct | see Phase 0 |
| 16 | **The channel-owner confirmation, Serenity's only,** inside row 6 (Q-GS7): "The school's email runs on Google Workspace (checked from its public mail records, Thu 8 Oct). Confirm you hold the contact account that owns the channel, who else can sign in, and whether the channel is in the YouTube Partner Program." The Workspace is stated, not asked, because public records answer it. The account holder adds Gabriel and Ivan as channel Managers, so Test & Compare and any manual visibility change are Ivan's steps. No email address appears on any public page | Ivan asks; Serenity answers | Asked Fri 9 Oct; needed Mon 12 Oct | Q-GS7 |
| 17 | Check RedCircle's own help pages for two things: whether the old feed can carry `itunes:new-feed-url` or answer with a 301 to a new feed, and whether RedCircle allows team access without sharing a password. Until then no document states the forwarding as fact | Ivan | Mon 12 Oct | Q-G2 |
| 18 | Draft three scripts of about 30 words each (intro, outro, 5-second mid-roll), with "Welcome to <name>" and the listener ask as **separate one-line takes**, so either can change without re-recording the rest; and three suggested show names and two suggested listener asks for Ivan to bring. The name and the ask are Gabriel's (Q-G26, Q-G7); nobody invents them | Sonny | Mon 12 Oct | SET-16, Q-G9, Q-G26, Q-G7, BIZ-01 |
| 19 | **Studio visit with Gabriel** (OPEN for Ivan, Q-I18; fallback a 30-minute screen share). Ivan sets OBS to Hybrid MP4, not MKV, with each microphone and Zoom on separate tracks and the teacher on headphones; turns the vertical output back on for talks; makes the 2-minute test recording and captures its MP4 box tree twice, during recording and after Stop, as fixtures for the readiness rule; notes the studio Mac (chip, memory, macOS) and both people's Mac and iPhone versions. Gabriel records the intro, outro and mid-roll in one sitting, with "Welcome to <name>" and the ask as separate one-line takes. **In the same sitting, after Gabriel's yes to the address cost** (the cost is unknown and no number is written until it is priced): Yoga Marga's new Cloudflare account is created, registered to a Yoga Marga address (the school's contact address, or Gabriel's own Yoga Marga address if he has one: to confirm), with Gabriel as owner and Serenity and Ivan as members, and R2 is turned on there. Not Gabriel's existing account, which runs VeraSales production (07 l.355) | Ivan, Gabriel | Week of Mon 12 Oct, by Fri 16 Oct; the name and the ask are due the day before | SET-03 to SET-05, SET-15, SET-16, Q-G4, Q-G9, Q-G22, Q-GS6, Q-G2 |
| 20 | The YouTube Cloud project (separate from the sign-in OAuth client). The school's email runs on Google Workspace, so once Serenity confirms the account (Q-GS7) the project is created inside the school's organization as Internal, with Ivan added, which needs no verification. If the account turns out not to be in that Workspace, WEB-06 is published first and Google's verification is submitted the same day. The owner's consent and the YouTube tests run in the account holder's sitting, week of Mon 26 Oct | Ivan | This week, after Q-GS7 | SET-13, WEB-06 |
| 21 | **The pre-deploy sequence, in this order:** (1) the `.gitignore` edit, done by Ivan's pre-deploy sequence: add `research/0*.md`, `*.mp4`, `*.mov`, `*.mkv`, `*.wav`, `*.m4a` and `*.mp3`, because the nine research files name students and media files carry people's voices; (2) Ivan's yes on the screenshots (row 2); (3) `git status`, read in full, then, with Ivan's yes, a `git grep -i` for the known names over the staged tree, then the first commit, staging files by name and never `git add -A`; (4) a private remote; (5) the `wrangler dev` checks; (6) deploy; (7) the live checks (headers, robots, `/.git/config`, and `http://` answering with a 301 to `https://`); (8) flip the roadmap status row "Front page and roadmap" to "Done, live since <date computed with `date(1)`>". If any step misses, the Fri 9 Oct messages go without links; they never wait for it | Sonny, on Ivan's yes | Thu 8 to Fri 9 Oct | WEB-01 to WEB-05, SET-11 |
|  | **Row 21 done Thu 8 Oct, on Ivan's own request that day** ("hosted at prakriti.therowan.studio", a version to share). Research files 01 and 08 are gitignored; `git grep` for the student names in the class transcripts finds none in the committed tree; private remote `mrivanlizarde/prakriti`; live checks passed (200 on / and /roadmap, 404 on /.git/config and source paths, headers present, http 301 to https, no console errors). | Sonny | Done | WEB-01 to WEB-05 |
| 22 | Accept or reject each pending spine correction (rounds 1 to 3, below) and publish DECISIONS v2. It no longer holds up the two messages, which quote no spine text; it lands before the first build session | Ivan | Mon 12 Oct | DECISIONS.md |
| 24 | The weekly Yoga Marga call (the 7 Oct page promised it). Ivan proposes one fixed day and time in the Fri 9 Oct message; the day is his to choose, and nobody invents one for him. Each week's decisions and one approval session fold into it. Q-I5 and the terms for the next stage are raised on that call in the week of Mon 19 Oct | Ivan | Fri 9 Oct | Q-G23, Q-I5, Phase 2 sessions |
| 25 | Check how long Apple Podcasts and Spotify take to list a new show, on their own help pages, so everyone knows when episode 1 appears in their apps after the Fri 23 Oct submission | Ivan | Mon 12 Oct | PUB-02 |
| 26 | Measure two times on the Sun 6 Sep talk, so the archive is budgeted from measurements, not guesses: the minutes it takes Ivan to hand-label it (this week), and Ivan's listen at its queued moments (when the pipeline first runs on it, Wed 21 Oct). Both go in the run log and in "Time it takes" | Ivan, with Sonny | Hand labels by Sun 11 Oct; the listen Wed 21 Oct | PIP-10, PRV-05 |

### Ivan's Fri 9 Oct, in order

Each step needs the one before it.

1. **The sizing and the cut line** (row 23): book the sessions and list the travel dates; Sonny writes
   the cut line. If the set above it does not fit, book more sessions or reset the number.
2. **The count** (row 5), from the script's counts; Ivan reviews titles on the Mac.
3. **The two messages** (rows 4 and 6; row 16 sits inside row 6 and row 24 inside row 4). They go
   whatever the state of DECISIONS v2, which follows by Mon 12 Oct (row 22).
4. **The deploy** (row 21), on Ivan's yes. The messages never wait for it: if the front door is not
   live when Ivan sends them, they go without links, and the links follow in one line once it is.

Also on Fri 9 Oct, in any order: confirm the engine Mac (row 7) and move the 10-07 transcripts (row 8).

---

## From the Tue 20 Oct demo: Gabriel and Serenity's punch list

Open, not yet placed in a phase. The demo (Fathom, 84 min; transcript in `Gabriel Galindo/Transcripts/`,
call note in the vault's Call Debriefs) set the bar in Gabriel's words: Prakriti succeeds when it
**replaces a person**, measured in decisions he no longer makes. Nothing finished has reached them yet
(Ivan: "I have not exported anything for you guys quite yet"; Serenity: "I'm using a lot of my
imagination"), so the first deliverable is not a feature.

**Do first**

- [ ] **One finished package from Gabriel's clean, scripted recording, before Tue 27 Oct** (the in-person
  session, 3 to 5 pm at their home): long form, podcast audio, shorts. Ivan asked him for the recording.
- [ ] **Local copy on arrival (20:00 to 28:24, 53:07).** The watcher reads iCloud placeholders ("file does not
  open"). Copy each new file from the shared folder into a non-synced local folder (Downloads), and work
  from that copy.
- [ ] **The hand-off (41:14).** A "ready" notice when a recording finishes processing. Today nothing tells
  anyone something is waiting.
- [ ] **The missing outputs (9:30, 23:39).** The podcast-ready episode (intro and outro music), the edited
  video, and thumbnails ("not great right now"; the autogenerated ones sent Fri 16 Oct need dialing in).

**Wizard mode (decided on the call: wizard for Gabriel and Serenity, detailed for Ivan)**

- [ ] **One button, no choices (30:15, 1:00:16).** Record, stop, walk away; come back to the long form, the
  audio, the podcast cut and as many shorts as it can find. Every choice on screen today is "a resistance
  point". His number: **50 to 99 shorts per hour** of recording, of which he keeps about 20.
- [ ] **Never lose the original (34:36, 37:33).** His complaint about OpusClip: choosing reels gave up the
  long-form edit. Every run keeps the long form beside the shorts.
- [ ] **Learn from his picks (37:07).** The 20 he keeps out of 90, and why, shape the next batch.
- [ ] **Detailed mode stays (33:31)** with prompt, vibe, pace, length and count; what Ivan learns there
  becomes wizard mode's defaults.
- [ ] **Inputs that fold away with one press (1:00:16)**, like Vera's pane.

**Smaller**

- [ ] **Merge people (11:24):** one face from several camera angles is read as several people.
- [ ] **A "done" button (47:11)** that ends a recording's life cycle; later it moves the file to S3 Deep
  Archive (cost analysis in the call note: single dollars a month for years; the AWS account belongs to
  Yoga Marga, with Ivan as a user).
- [ ] **Installer for their M1 Macs (39:46).** Blocked on the Developer ID certificate.

Storage, decided on the call: WeTransfer (Ivan's 2 TB plan) now, the shared iCloud folder kept; AWS later.

## Timeline at a glance

| Phase | Dates (2026) | Goal | Done when |
|---|---|---|---|
| **0. Ground** | Thu 8 Oct to Fri 16 Oct | Front door up, every blocking question asked, the cut line written, the engine's contract and process model written, an engine that notices a finished recording and checks its sound | A test recording is noticed, waited for, sound-checked and shown as one notification; after a reboot with the archive drive attached and nothing touched, the engine still reads every folder with no prompt |
| **1. First light** | Mon 19 Oct to Fri 23 Oct | The first episode live by the shortest safe path: Gabriel's Sun 6 Sep studio talk, approved in two versions | The chosen version is live and confirmed by reading the feed, and the show is submitted to Apple Podcasts and Spotify within the hour |
| **2. The archive** | Mon 26 Oct to Fri 6 Nov (archive transcription from Thu 22 Oct, once it passes on the Sun 6 Sep talk; sign-in and the review page ready by Mon 26 Oct) | The archive sorted, and the best teacher-only talks published as podcast episodes | The proposed 25, or the number reset on Fri 9 Oct, live on the podcast feed, each confirmed; the shortlist states how many archive videos can go to YouTube |
| ~~Money gate~~ | Retired Sat 10 Oct by Ivan ("We don't need to price it") | None | None |
| **Below the cut line** | From Mon 9 Nov | Archive talks on YouTube (at most two a day), Web Push, Prakriti's own release slots, and the rest listed after Phase 2 | Each with its own check |
| **3. The studio package** | Mon 9 Nov to Mon 30 Nov | Edited video, thumbnails and shorts for studio sessions; the 72-hour clock starts on the always-on Mac | Three studio sessions in a row ready for a yes within 72 hours |
| **4. The Library and voices** | From Tue 1 Dec | Each teacher's own words, searchable; voice datasets for teachers who say yes | 20 test questions answered with only the teacher's words and working timecodes |
| **5. Later** | 2027, not before Mon 4 Jan | The business loop and the platforms beyond YouTube | Each switched on alone, with its own check |

On the roadmap page the phase status tags are **Now**, **Next** and **Planned**.

---

## The cut line: what is built by Fri 6 Nov

Written by Sonny on Fri 9 Oct (row 23), before the two messages, from the sessions Ivan booked. What
follows is the proposed line; the sizing confirms it, or Ivan changes the sessions or the number, but
nothing moves silently.

**Reason:** round 3 found about 100 features set against about 24 hours of booked sessions (C3), and
every safeguard of the autonomous engine landing after the 25 it protects (C8, E9). A line drawn in
writing before the messages costs less than one drawn by slippage after Gabriel has a number.

**Above the line, by Fri 6 Nov** (most of it by Mon 26 Oct, before archive approvals open):

- The watcher as a login item, with Ivan's three-moment native notification on the engine Mac. This
  is Ivan's 10-08 request, so round 3's suggestion of command-line tools Sonny runs in sessions was
  rejected: a tool that runs only when someone runs it is not autonomous.
- Readiness and the sound check.
- Transcription, labels, name muting and mastering for the podcast.
- The post-render check (PRV-05; SCOPE §7.4 stage 18a).
- Ivan's release script: render `feed.xml`, check the manifest, put the file, read the feed back.
- Up Next's sign-in, copied as is.
- One review page: Approve tied to the manifest; a secondary "Not Yet..." button that opens one note,
  which goes to Ivan and the activity log, and Ivan makes the change by hand; and Keep / Cut / Add a
  Note on each accuracy item, recorded on the manifest.
- Pause All Publishing.
- Take down in one step (PRV-12).
- One email per approval session (NTF-08), never with an approve link.
- The heartbeat, plus a cron that emails Ivan through Resend when `engines.last_heartbeat_at` is late
  (NTF-09).
- A once-daily, report-only sweep of stuck items, measured in awake time (OPS-02).
- Database backups through Up Next's `backup.mjs`, with absolute paths, before the first approval is
  stored (OPS-08).
- ACC-03 ("Recorded in"), ACC-04 (earnings, health and legal claims), ACC-05 (spoken promises), PRV-08
  (quarantine), PRV-09 (minors) and PRV-22 (encryption and least access).
- Needed by the items above, so above the line with them: the review links for episode 1
  (`review_links`), the activity log and the audit log behind it (where the "Not Yet..." note lands),
  the archive inventory, triage and shortlist (ARC-01 to ARC-08), and the daily archive summary
  (NTF-05).

**Below the line, after Fri 6 Nov:**

- Every YouTube API task: PUB-07 to PUB-12, PIP-20, PIP-21, PKG-06, PKG-09, PRV-15 and APP-23. Until
  then the Mon 26 Oct shortlist's YouTube count is checked by eye by Ivan, because the screen check
  (PRV-14) is below the line too.
- Web Push (NTF-04, NTF-07, APP-19).
- Prakriti's own release slots (PUB-13's automation) and the publish calendar (PUB-14).
- The engine Settings window (ENG-08).
- Today and Recordings (APP-02, APP-03).
- Ask for Changes proper (APP-06).
- Chapters (PKG-05).
- The "Your consents" screen, and People and consent (APP-11).
- Onboarding (APP-16).
- Named by neither list, placed here by Sonny: the cost ledger and meter screen (OPS-04; until then the
  Anthropic Console spend limit, set equal to the cap, is the cap) and the package zip (PKG-10).
- Never built: a separate list screen of archive pieces (H2). The session email lists every piece
  instead.

**The rule.** If the set above the line does not fit the booked sessions, Ivan books more sessions or
resets the number on Fri 9 Oct. Nothing above the line slips quietly, because the public dates rest on
it.

**Archive nights** are booked only after transcription passes on the Sun 6 Sep talk (Wed 21 Oct), for
nights from Thu 22 Oct, not Mon 19 to Thu 22 Oct. Reason: a night booked before the code that uses it
exists is a night wasted (C3).

---

## Gates

A gate is a condition that must be true before something switches on. Gates are enforced by the
software where they can be, and by this plan where they cannot.

### Teacher-only, defined once

**Teacher-only** means: no other voice heard, and no student named, described or answered.

Until Serenity answers Q-S30, nothing from a session where students were present, whether they spoke
or only listened, goes public.

### The publishing gate (always on)

- **Nothing becomes public without a named person's yes, tied to a publication manifest:** every
  file's hash, plus every text field exactly as it will be sent (title, description, notes,
  chapters, captions), plus the destination IDs. Any change voids the yes (D3, PR-1, APP-05).
- Reason: the standing rule (nothing outward-facing without a human yes), YouTube's developer policy
  (express consent before each upload or change), and Serenity's accuracy condition all require it.
  A yes tied only to the audio file would let a changed title, or a YouTube visibility change, go
  out unseen. A podcast episode cannot be fully recalled once apps have downloaded it.
- **For the first episode,** before sign-in exists, the yes is Gabriel's one written yes (text or
  email) to **both versions' manifests**: "A if Serenity says yes, otherwise B", given through review
  links or on a 15-minute call. Both hashes and his yes go into the run log, and are copied into the
  audit log once it exists. Reason: a passage cut after his yes would void it (round 3, G2 and E2), so
  the version without it is approved before it is needed.
- **Who says yes.** Each teacher approves their own pieces, or names someone who may. Serenity
  approves every piece in her voice for now, and the privacy receipt of anything with voices other
  than the teachers'. **Any piece in which an Other voice was found, even if all of it was removed,
  needs Serenity's receipt until her rule says otherwise** (S8). Pieces that name Serenity are shown
  to her until she says otherwise.
  - **How "shown to her" works:** a piece that names Serenity (found with the same phonetic matching
    as student names, failing toward showing her; "my partner", and any similar words Gabriel
    confirms he uses for her, count as naming her) lists her as a required viewer. Approve stays
    disabled until she has opened it or her hold time passes (Q-S26, suggested 48 hours). If she has
    not looked by then, the passage that names her is cut and the piece goes ahead. **For the first
    episode,** the two versions replace the cut: her reply, or her silence by the end of Thu 22 Oct,
    picks A or B.
  - **Passages about a teacher's own life** (family, health, grief, money) need that teacher's yes
    for that passage, whoever's piece it is, if they want it (Q-S25 for Serenity, Q-G27 for
    Gabriel). Until they answer, such passages are held. Q-G8 settles the money statements in the
    Sun 6 Sep talk; a passage Q-G8 has settled is not held again under Q-G27.
  - Who may approve Gabriel's solo talks (Q-G23, with Q-G10a merged in) is covered by "yes to the
    suggestions". Suggested: either of you. No answer: he approves his own; Ivan does not.
- **Ivan listens first.** Ivan listens at the queued moments of every archive piece before it
  reaches its approver, Mon 26 Oct to Thu 5 Nov, logged with who and when. Each moment is played to
  its end before his step is marked done. Reason: on one microphone software can mistake a student
  for a teacher without knowing it, and round 3 found the listen had no named listener (S1, C4).
- The yes is made as small as possible: one email per approval session, one review page per piece, one
  named button, **"Approve for the Feed"**, with "Goes live <day, time>. Undo" under it. Until Fri 6
  Nov, approving places the piece in the next morning's run of Ivan's release script (Q-I20); after
  that, in Prakriti's own release slot; either way with an Undo until it goes live. A secondary
  **"Not Yet..."** button opens one note, which goes to Ivan and the activity log, and Ivan makes the
  change by hand. Each accuracy item carries **Keep / Cut / Add a Note**, recorded on the manifest;
  a Cut goes to Ivan. There is never an Approve or Publish button inside a notification or an email
  (NEV-08), because approving unseen work defeats the review and a mail scanner can open links.
- **Publish unless stopped.** Ivan decides whether the setting ever exists, not before Mon 30 Nov and
  only after 20 clean approvals in a lane. It applies to a teacher's pieces only with that teacher's
  own yes for that lane, and never to anything with other voices (Q-I7).

### Consent gates

| Gate | Rule | Reason | Until it is met |
|---|---|---|---|
| **Students** | **The student rule:** "For now, a class goes public only with every student removed, and only after Serenity sets her rule, a lawyer has read a new class release the students have agreed to, and she approves that piece's privacy receipt. Whether a student who says yes in writing may ever be heard is Serenity's rule to set." Teacher-only is defined above; until Serenity answers Q-S30, nothing from a session where students were present, whether they spoke or only listened, goes public. **A segment inherits its source recording's type, gates and approvers,** so a stretch of a class is a class until Serenity answers Q-S24 | Her first condition, set Thu 24 Sep. Students were told the recordings are for the private community, so publishing them is a new purpose that needs new consent. A five-minute stretch cut from a class carries the same students | Classes, calls and stretches of them are processed privately on the Mac only. Earliest public class: Phase 3 (Q-S1 to Q-S4, Q-S24, Q-I12) |
| **Privacy proof** | Split by teacher and by content type. **Gabriel's pieces** are released once his release samples pass: 09-06, 09-13, and one Business of Yoga recording that is his, or, if none has Gabriel speaking alone (01 C-11 names Serenity in one), another Gabriel-only archive talk named in row 5; plus at least three of his Zoom-era archive recordings with students in the session, each student moment a must-reject case. **The Serenity solo-talk sample** gates only her pieces. **Classes and calls** stay locked until their own samples pass. The test: zero seconds of student speech labeled as a teacher. Ivan is the listener: for the samples, about 3 to 4 hours (an estimate, unmeasured), booked Thu 22 to Fri 23 Oct; for every archive piece, at its queued moments before it reaches its approver, Mon 26 Oct to Thu 5 Nov, logged with who and when. Every exact MP3 also gets a **post-render check**: speaker verification in short windows over the whole file, and a fresh transcription searched for roster names, greeting patterns and every muted token; any miss blocks Approve. Until Serenity's own Zoom-era sample passes, Ivan listens to every archive piece in her voice at each speaker change before it reaches her. SCOPE §19 keeps the 10-file set for calibration only | Speaker separation already failed the dangerous way: on Sun 20 Sep a student's personal story was labeled as the teacher. On one microphone, software can mistake a student for a teacher without knowing it, so the promise is the check, not the software. Gabriel's studio samples alone had no student in them to reject (S9) | That teacher's pieces, or that content type, stay private |
| **Voice reference** | No teacher's voice is enrolled for recognition without their written yes (SET-20, Q-S5, Q-G10b). The reference uses one length, a 2 to 3 minute clip. It is a plain-language permission now, replaced by a lawyer-read version within four weeks of the lawyer starting (Q-I12); each teacher may have it read by their own lawyer. Proposed retention: "deleted when you ask, or 3 years after last use, whichever comes first." Kept only on the Mac that runs Prakriti, never backed up or synced. No student voiceprint is ever stored | Voiceprints are biometric data under Illinois and Colorado law, and live lawsuits target exactly "recognize the same person later" (08 §3.4) | Gabriel: Ivan labels his talks by hand, at the rate measured on 09-06 (row 26), which limits how many of the 25 can be ready. Serenity: for a recording where she teaches alone, she may approve it by listening at the moments Prakriti queues; anything else in her voice waits |
| **AI voice or face** | Prakriti never makes an AI voice or face of anyone. A teacher may make their own, in their own account. With that teacher's written yes, Prakriti prepares clean recordings for it and uses the result only for a script that teacher approved, always labeled as AI. Nothing of Serenity's without her written yes (LIB-03, PR-8, PR-9) | ElevenLabs lets a person clone only their own voice; Apple Podcasts and YouTube both require disclosure; Serenity has not consented to an AI version of herself | Nothing is collected for a voice model. Intros and outros are real recordings, which need no disclosure |
| **Cloud AI** | Every cloud call runs after redaction (SCOPE §7.4 stage 15): only public-safe, tokenized, teacher-only text, with Other voice removed. **Until Q-S13 is Granted, no Claude session, Sonny included, opens a transcript, title or description of Serenity's teaching or of any class. Sonny sees only counts and categories printed by a script on the Mac, and the name seed list is built the same way.** Gabriel's own text reaches Claude under his Fri 9 Oct yes | The lexicon stage once sent raw transcript text to Claude before names were tokenized (round 2, E2). Sonny is Claude, so Sonny drafting Serenity's assessment from transcripts would have been a cloud call on her teaching (round 3, S2) | Studio work proceeds on Gabriel's talks; Serenity's items, and every class, wait |
| **Guests** | Guest teachers' recordings stay private until the guest gives written permission (Q-S15) | Their voice and teaching are theirs | Inventory and internal search only, attributed |
| **Quarantine** | Private 1:1 coaching calls, client calls and third-party demos never feed content, the library or voice training (PR-24). They are excluded at inventory, before any audio step: anything in the Private Meetings playlist, marked private on YouTube, or titled as a meeting room is not copied in the salvage. **The re-run is never extracted into a watched folder:** private items stay in the zip or go to a separate encrypted quarantine folder, and no audio step runs on an archive file before inventory classifies it | Not Prakriti's to decide; the client's consent lives outside it. A channel Takeout includes the private coaching calls | An inventory line only. A call found later, inside an item that looked like something else, stops there and its transcript is deleted |

**Consent before the "Your consents" screen exists.** Until the Your consents screen lands after Fri
6 Nov, a teacher's written yes sent from that teacher's own email address counts as Granted for that
teacher's own uses. Ivan records it with the message reference; Ivan's word alone never does. The
teacher re-confirms in the app when the screen exists. Reason: Gabriel's voice clip, his Claude use
and a Fri 30 Oct yes from Serenity would otherwise wait for a screen that lands after the 25 (round 3,
E3 and C13). Gabriel's Fri 9 Oct reply to podcast first explicitly covers public audio of his own
talks and Claude on his own text.

### The money gate (retired Sat 10 Oct)

> **Retired by Ivan on Sat 10 Oct 2026:** *"We don't need to price it."* Asked directly whether to build the
> native app before pricing Prakriti with Gabriel, Ivan chose not to price it. Nothing in this plan waits on
> Q-I5 any more. The text below is kept as history.

**Prakriti is priced and agreed before lane 2 switches on** (D16, OPS-14). The price question, Q-I5,
and the terms for the next stage are raised live on the weekly call in the week of Mon 19 Oct, and
are due Fri 23 Oct. Lane 1 is podcast audio from the studio and the archive, plus archive talks on
YouTube changed by new metadata and visibility. Lane 2 is studio video, in Phase 3. No number appears
in this file; it is Ivan's to name and agree with Gabriel. **The terms, Q-I5, who pays for the lawyer
(Q-I12) and the Developer ID certificate live in this file only** and are not on the public pages
(round 3, conflict 14), because the roadmap is a page Serenity reads and D15 keeps money off it.

- Reason: scope has grown on this engagement without a price before, and Gabriel raised the
  question himself on Wed 7 Oct. Asking by Fri 23 Oct, not on launch day, leaves two weeks before
  Phase 3.
- If the terms are not agreed by Mon 9 Nov, Phase 3 waits. Lane 1 keeps running.

### The engine-host gate

**The 72-hour target starts only when the engine runs on an always-on Mac** (D2, Q-I1).

- Reason: v1 runs on Ivan's MacBook Pro, which travels and sleeps when the lid is closed. A target
  that depends on a laptop being open is not true, and it is already on the record with Gabriel
  from the roadmap page of Wed 7 Oct.
- Until then the web app says so plainly: "Asleep since 9:40 pm. New recordings wait until it
  wakes." (APP-17).
- **The always-on host also needs these, because FileVault is on.** After a power cut or an update
  restart, a FileVault Mac waits at the unlock screen with nobody logged in, so the engine, which is
  a login item, never starts:
  - a UPS;
  - "Start up automatically after a power failure" turned on;
  - `fdesetup authrestart` for planned updates;
  - automatic macOS updates off, so a restart never happens unplanned;
  - the Engine Quiet email at 30 minutes on the always-on host. On the laptop: after 60 minutes of
    silence when the last post was a heartbeat, 20 minutes during a booked archive night, and 12
    hours only after a "going to sleep" post;
  - the engine posting "going to sleep" and "woke", so the web app shows "Asleep" only when the Mac
    said so, and "Not heard from since 9:40 pm" otherwise. Reason: a guessed "Asleep" hides a crash.
- Moving the engine to any Mac other than Ivan's also needs the Developer ID certificate and a
  notarized build first (SET-08, Q-I3), because an unsigned or ad-hoc build loses its folder
  permission silently.

---

## Phase 0. Ground

**Thu 8 Oct to Fri 16 Oct 2026**

**Goal.** Put the front door up, write the cut line, ask every question that blocks the build, write
the engine's contract and process model, and have an engine that notices a finished recording and
checks its sound.

### Milestones

| Date | Milestone | Owner |
|---|---|---|
| Thu 8 Oct | Plan, scope and project docs written and revised for feedback rounds 1 to 3; front door rendered and looked at | Sonny |
| Fri 9 Oct, in order | The sizing and the cut line (row 23); the count (row 5); one message to Gabriel and one to Serenity (rows 4 and 6), whatever the state of DECISIONS v2; the deploy (row 21), on Ivan's yes; the engine Mac confirmed; the 10-07 transcripts moved out of the shared folder | Ivan, Sonny |
| Sun 11 Oct | The minutes it takes Ivan to hand-label the Sun 6 Sep talk, measured (row 26) | Ivan |
| Mon 12 Oct | DECISIONS v2 published (row 22); Serenity confirms the account that owns the channel (Q-GS7); Gabriel and Ivan added as channel Managers; Gabriel's reply on podcast first and the numbers, unless the studio visit comes first; how long Apple Podcasts and Spotify take to list a new show (row 25); the archive drive decided (Q-I17); the salvage running; RedCircle checked; three scripts, three suggested names and two suggested asks drafted | Serenity, Gabriel, account holder, Ivan, Sonny |
| Week of Mon 12 Oct | **Serenity's first meeting** with Ivan, 30 to 45 minutes: the first look; Ivan plays her the passages of the Sun 6 Sep talk that name or refer to her and shows her the draft show description, and records her answer; how many privacy receipts to expect in the week of Mon 26 Oct; three questions needed by Fri 16 Oct (Q-S11a, Q-S30, Q-S13); and Q-S16 and Q-S23, with no deadline. **The day before the studio visit:** Gabriel's show name and listener ask due (Q-G26, Q-G7). **Ivan's studio visit with Gabriel** (Q-I18): OBS, the intro takes, and Yoga Marga's new Cloudflare account | Ivan, Gabriel, Serenity |
| Wed 14 Oct | The Takeout requested on Ivan's Mac, the parts downloading over one to three days (skipped if the files are already salvaged; off the critical path); the engine API contract written and the process-model spike done | Account holder, Ivan, Sonny |
| Wed 14 Oct (target) | The engine notices a finished file in the studio folder and checks its sound | Sonny |
| Fri 16 Oct | Gabriel's answer on the money statements in the Sun 6 Sep talk (Q-G8) and his "yes to the suggestions" reply; the voice clip requested (Q-G10b); Serenity's three answers needed (Q-S11a, Q-S30, Q-S13); Yoga Marga's new Cloudflare account created, with R2 on (at the studio visit); the intro, outro and mid-roll recorded; show art and show description done; privacy policy and terms pages published; Ivan's data-responsibility note drafted; R2 on in Ivan's account, with `wrangler login` re-run and checked; the Developer ID certificate; Phase 0 check | Everyone |

### Tasks

| Task | Owner | IDs |
|---|---|---|
| Front door and roadmap page at `prakriti.therowan.studio` and `/roadmap`; strict headers, noindex, robots disallow all; privacy section naming every outside service | Sonny | WEB-01 to WEB-05, WEB-07 |
| Privacy policy and terms pages, published by Fri 16 Oct, before the owner's consent | Sonny writes, Ivan approves | WEB-06 |
| **The cut line, written Fri 9 Oct** from the booked sessions ("The cut line" above) | Sonny | row 23 |
| **One-page engine API contract before any engine code:** a bearer token per engine, minted by an operator script, its hash in `engines.token_hash`, valid only on `/engine/*` routes; events written first to a local outbox in the same SQLite transaction as the state change, each with a client UUID and a sequence per (engine, token epoch), minting a token resets the sequence; events stored with `INSERT OR IGNORE`, applied per engine in sequence order, a gap held, and a gap open more than 10 minutes while heartbeats arrive raises "Engine Out of Sync" to Ivan and queues a snapshot resync; events about a superseded artifact version refused; `engine_commands` polled every 30 to 60 seconds while awake and on wake; `POST /engine/editorial` for Claude's work, with the result fetched from `GET /engine/editorial/:id` on the command poll; an `X-Prakriti-Protocol` header, refused if unknown; the engine owns Found to "Ready for your yes", the Worker owns Approved to Live; every transition carries the artifact version | Sonny | ENG-12, SCOPE §6.4 |
| Minimal engine auth (ENG-12), the token above, in Phase 0 rather than Phase 1 | Sonny | ENG-12 |
| **Engine process model in writing:** not sandboxed, hardened runtime, one nested `LSUIElement` app (`Contents/Library/LoginItems/Prakriti Engine.app`) launched by `SMAppService.agent` from a written plist (KeepAlive restarts it only after a crash, so Quit stays quit) and ProcessType Standard. It owns FSEvents, the pipeline, child processes, notifications and the optional menu bar, and raises every permission prompt itself at setup. It asks for alert and sound only, never provisional and never a badge, because it has no Dock icon to badge; the ask comes right after the folder is chosen, after a one-sentence explainer with one Continue button. A spike proves it before Wed 14 Oct, sized to fit one 2-hour build session or a longer booked one | Sonny | ENG-01, ENG-02, ENG-07, ENG-09, NTF-01 |
| Engine skeleton: a small Swift app in `mac/`, signed with Ivan's Apple Development certificate (team LD587PB2H8) from the very first build | Sonny | ENG-01, ENG-02, ENG-07, ENG-09 |
| Folder watching that survives sleep, iCloud placeholder handling, the readiness rule (with "finished" for Hybrid MP4 defined only from the fixtures), files read through `NSFileCoordinator` and cloned into the work area, sleep and wake handling, absolute paths and Keychain secrets, never writing into the shared folder, one job at a time, timeouts and a crash-loop guard measured in awake time, preflight checks with a 100 GB free-space floor for archive work | Sonny | ENG-03 to ENG-05, ENG-10, ENG-11, ENG-15, ENG-16, ENG-18 |
| Session pairing (horizontal and vertical twins), silent test filing under 60 seconds, the sound check, a same-day "No Sound" decision | Sonny | PIP-01 to PIP-04 |
| Coverage check after every filter; run log with a dated line even when nothing was found; heartbeat, with "going to sleep" and "woke" posts and `step_awake_s`; retries for passing failures only | Sonny | PIP-08, OPS-01, OPS-03, OPS-05 |
| Native notifications: one per recording, updated in place; Needs a Decision and Couldn't Finish in the same thread; the review address carried in the notice and opened in the browser on a click | Sonny | NTF-01 to NTF-03 |
| Archive inventory of all 958 from the Takeout metadata (metadata only; titles and descriptions encrypted, because they can name students). Private items are excluded here, before any audio step | Sonny | ARC-01, PRV-08 |
| The count for row 5, before Fri 9 Oct, from a script on the Mac that prints counts and categories only | Sonny | ARC-01 |
| Salvage the complete videos from the partial download, with the private exclusions | Sonny | SET-02 |
| Draft the two Fri 9 Oct messages; the three scripts, three suggested show names and two suggested listener asks (by Mon 12 Oct); and Ivan's one-page data-responsibility note (by Fri 16 Oct) | Sonny drafts, Ivan sends | SET-21, Q-I6, ARC-08, SET-16, Q-I16 |
| Send the two messages; check RedCircle's help pages and how long Apple Podcasts and Spotify take to list a new show; Serenity's first meeting; the studio visit | Ivan | SET-21, Q-G2, PUB-02, Q-I18 |
| Book build sessions through Fri 6 Nov and list travel dates, Fri 9 Oct, first (row 23). Accept or reject the pending spine corrections and publish DECISIONS v2 by Mon 12 Oct (row 22) | Ivan | rows 22, 23 |
| Measure the hand-label minutes on the Sun 6 Sep talk (row 26) | Ivan | PIP-10 |
| Show art (3000 x 3000) and the show description, by Fri 16 Oct. The draft description is shown to Serenity at her first meeting, so it is recommended ready by the day before that meeting (OPEN for Ivan; the art can stay Fri 16 Oct) | Ivan | SET-17 |
| Enable R2 in Ivan's account, then `wrangler login` again and `wrangler r2 bucket list` to check it; Keep Downloaded and FileVault; whose Anthropic key pays and the monthly cap; quiet hours; no Cloudflare Access in front of the site; the "Publishing paused or resumed" notice; the release hour (Q-I20); where "Is this Serenity?" is offered (Q-I22) | Ivan | SET-07, SET-09, Q-I2, Q-I4, Q-I10, Q-I13, Q-I19, Q-I20, Q-I22 |
| Confirm the Workers Paid plan before the heartbeat routes deploy; give Prakriti its own Anthropic workspace and key, with a Console spend limit equal to the cap; turn on Cloudflare billing and usage notifications for Workers, R2 and D1 | Ivan | SET-07, SET-18, Q-I4 |
| The Developer ID certificate, by Fri 16 Oct | Ivan | SET-08, Q-I3 |
| The YouTube Cloud project per row 20 | Ivan | SET-13 |
| Resend domain verification, for the email notices | Ivan | SET-19 |
| **The feed home, ready Tue 20 Oct:** the podcast-only address added as its own zone in Yoga Marga's new Cloudflare account (created at the studio visit), the bucket, a token scoped to that bucket, and the feed Worker with that account's `account_id` pinned in its own wrangler config. The feed's owner email is the school's address (Q-G2) | Ivan | SET-15, PUB-01 |
| **Gabriel's seven things through Fri 16 Oct.** (1) The reply to podcast first and the numbers, Mon 12 Oct or at the studio visit if that comes first (Q-G1, Q-G19). (2) "Yes to the suggestions": one reply covering every row with a suggestion (among them the channel Q-G6, the release plan Q-G18, who approves Q-G23, titles Q-G25, the Sunday talk Q-G5, own-life passages Q-G27 and real frames Q-G24). (3) The show name and the one listener ask, the day before the studio visit (Q-G26, Q-G7). (4) The money statements in the Sun 6 Sep talk, Fri 16 Oct (Q-G8). (5) The voice clip, in writing, requested by Fri 16 Oct and never assumed (Q-G10b). (6) Recording the intro, outro and mid-roll at the studio visit (Q-G9). (7) The yes to the podcast address cost, with the Cloudflare sitting, at the studio visit (Q-G2). Rows with a suggestion or a safe setting are not separate things. For information, not a thing to do: one story about a student is cut from episode 1 under the student rule, unless Serenity answers otherwise first | Gabriel | Q-G1, Q-G19, Q-G26, Q-G7, Q-G8, Q-G10b, Q-G9, Q-G2 |
| Sun 18 Oct: the Sunday talk recorded weekly from that day, with his microphone on its own track (Q-G5, covered by "yes to the suggestions"). A Sunday talk where only he speaks can become episode two; a Sunday call where students speak stays private under the student rule. The first episode does not wait for it | Gabriel | Q-G5 |
| A 10-second sound check before every session from now on. Until the engine can confirm it, Gabriel plays the test back himself, because the laptop sleeps and sign-in is not open yet | Gabriel | SET-06 |
| By Mon 12 Oct: confirm the account that owns the channel, who else can sign in, and the Partner Program status (Q-GS7); the account holder adds Gabriel and Ivan as channel Managers. Wed 14 Oct: the account holder requests the Takeout on Ivan's Mac (row 11) | Serenity, account holder | Q-GS7, SET-01, Q-G20 |
| The first meeting with Ivan in the week of Mon 12 Oct; three answers needed by Fri 16 Oct (Q-S11a, Q-S30, Q-S13) | Serenity | ARC-08, SET-21 |

### Blocked by (owner actions)

- **The OBS test recording**, made at Ivan's studio visit (Q-I18, Q-G4), blocks the watcher half of
  the check and the Hybrid MP4 fixtures. Fallback: Sonny copies a past studio file into a test
  folder and runs the check there, and says so; "finished" for Hybrid MP4 stays undefined, and
  Hybrid files wait, until the fixtures exist.
- **The channel owner confirmed** (Q-GS7) blocks the Takeout re-run (Q-G20). Fallback: the roughly
  694 salvaged videos, which are the primary input anyway.
- **The archive drive** (Ivan, Q-I17). Fallback: part-by-part extraction with each zip deleted after
  its entries verify, on Ivan's yes.
- **R2 in Ivan's account** (Ivan, SET-07) does not block Phase 0, but blocks every upload in Phase 1.
  **Yoga Marga's new Cloudflare account,** created at the studio visit with Gabriel's yes to the
  address cost, blocks the feed home (ready Tue 20 Oct).
- **Serenity's Q-S11a and Q-S30** (Fri 16 Oct) do not block Phase 0. Until a name list or a seed list
  exists, nothing from a session where students were present can be approved.

### Done when

Someone can look at each of these:

1. The front door rendered at 390, 768 and 1440 px, light and dark, with no sideways scroll; before
   the first deploy, the `wrangler dev` render and the curl checks of headers and 404s against
   `127.0.0.1:8787`; after it, the header, robots, `/.git/config` and http-to-https 301 checks on the
   live site; zero em dashes in `web/public`.
2. A 2-minute OBS test recording dropped into the shared folder is noticed, waited for until it is
   complete, sound-checked, and shown as **one** notification that updates in place.
3. A file under 60 seconds produces no notification at all.
4. A silent file raises "No Sound" the same day.
5. A run-log line exists for a sweep that found nothing.
6. Quitting the engine mid-recording posts "stopped by Ivan" and the engine stays quit; relaunching
   it still picks the recording up.
7. Reboot the Mac with the archive drive attached, log in, touch nothing: the engine reads the studio
   folder, the drive and the salvage path with no prompt, and posts a notification.
8. Copy a file while OBS is still recording it: the engine does not treat it as finished.
9. The cut line is written, and the count went to Gabriel on Fri 9 Oct with two numbers or no number.

### Not in Phase 0

- No AI calls.
- Nothing published.

---

## Phase 1. First light

**Mon 19 Oct to Fri 23 Oct 2026**

**Goal.** The first episode live by the shortest safe path: Gabriel's Sun 6 Sep studio talk (file
`2026-09-06 18-06-33.mp4`) goes from the folder to a live podcast episode, approved in two versions,
with one written yes from Gabriel in between. Reason for that talk: it is already on the Mac and has
one voice; Serenity hears its passages about her first, at her first meeting. The talk also holds two
income claims about Gabriel's own results, one of them in its opening line, and one spoken offer near
the end, which Gabriel decides by Fri 16 Oct (Q-G8); and one story about a student, cut under the
student rule unless Serenity answers otherwise first. No figure or quote from it appears on any page.
The studio has recorded nothing usable since Wed 23 Sep. There is no trailer: the intro Gabriel
records opens episode 1. A Sunday talk where only Gabriel speaks can become episode two. The first
archive episode follows the morning after its approval (Tue 27 or Wed 28 Oct).

### Milestones

| Date | Milestone | Owner |
|---|---|---|
| Week of Mon 12 Oct | At Serenity's first meeting, Ivan plays her the passages of the Sun 6 Sep talk that name or refer to her, shows her the draft show description, and records her answer | Ivan, Serenity |
| Tue 20 Oct | **The podcast feed is ready:** the zone, the bucket, a bucket-scoped token and the feed Worker, in Yoga Marga's new Cloudflare account | Ivan |
| Wed 21 Oct | The full pipeline runs on the Sun 6 Sep talk, on the Mac, and renders **two versions: A, with the passage that names Serenity, and B, without it.** The post-render check and Ivan's queued listen run on both, logged with who and when, and his listening time is measured (row 26). If the engine is not ready, both are made **by hand with ffmpeg** instead, and that is said plainly to Gabriel and in the run log (Ivan already made edited output from this same talk by hand on 09-10; 01 §12). Serenity gets a review link to the finished file | Sonny, Ivan |
| Thu 22 Oct | **Gabriel approves both manifests in one written yes, "A if Serenity says yes, otherwise B",** through review links (or Ivan plays both on a 15-minute call). His yes and both hashes go into the run log, and are copied into the audit log once it exists | Gabriel, Ivan |
| End of Thu 22 Oct | Serenity's reply, or her silence, picks the version: A only with her yes; B otherwise, including if her days do not work | Serenity |
| From Thu 22 Oct | Two archive nights booked, now that transcription has passed on the Sun 6 Sep talk, for nights from Thu 22 Oct | Ivan |
| Fri 23 Oct | **First episode live:** Ivan uploads the chosen version, logs which, reads the feed back, and within the hour submits the show to Apple Podcasts and Spotify, with whoever holds that Apple ID signing in beside him. It appears in their apps after their review | Ivan |
| By Fri 23 Oct | Ivan books Serenity's second meeting, 30 minutes on Tue 27 Oct | Ivan |

### Tasks

Built this week. Order 1 is the shortest safe path to the first episode, and only that. The app
pieces are in "Before approvals open (by Mon 26 Oct)" in Phase 2, and everything below the cut line is
listed after Phase 2.

| Task | Owner | IDs |
|---|---|---|
| One transcription engine (Apple's, on the Mac), no voice-activity gate, with its coverage check | Sonny | PIP-06, PIP-08 |
| The Yoga Marga lexicon, **local only**: a known-variant list plus phonetic matching against the glossary, original kept. Glossary suggestions fold into the Sonnet call, after redaction | Sonny | PIP-09 |
| Hand labels for Gabriel's talk on the hand-label screen (SCOPE §7.8), unless his written yes to the voice clip is in from his own email. Everything uncertain is Other voice | Sonny builds, Ivan labels | PIP-10, PRV-01, PRV-02 |
| Music detection with SoundAnalysis, as a hard block | Sonny | PIP-12 |
| Warm-up trim and the podcast cut list (never shortening a yin hold); mastering (mono first, then -16 LUFS and -1 dBTP); the real intro and outro joined | Sonny | PIP-16 to PIP-19 |
| Name scrubber and the redaction plan (stage 15), with its real coverage check. "Names Serenity" also catches "my partner" and any similar words Gabriel confirms he uses for her, erring toward showing her | Sonny | PRV-03, PRV-04 |
| The post-render gate on the exact MP3: the one-cluster test on body spans only; the intro, outro and mid-roll checked by hash against the approved recordings; the name and greeting search over the whole MP3. Dry-run on a 09-06 MP3 with the real intro before Wed 21 Oct | Sonny | PRV-05 |
| A Sonnet-written package (titles, show notes, the accuracy checklist), from redacted, tokenized text only, through the editorial endpoint; every claim checked word for word against the transcript; Gabriel's one listener ask if he has named it, otherwise no ask | Sonny | PKG-01 to PKG-04, ACC-01, PRV-10, BIZ-01 |
| Tail decode of every output and the loudness check on the MP3 | Sonny | PIP-27 |
| The review links for episode 1: one per recipient and version, expiring after 72 hours, revocable, stored hashed (SCOPE §10.1 `review_links`) | Sonny | none |
| Ivan listens at the queued moments of both versions before Gabriel's yes, logged with who and when | Ivan | PRV-05 |
| The feed home, then the upload of the chosen version and the read-back of the feed; validated before every write | Ivan, Sonny builds | PUB-01, PUB-03, PUB-15 |
| Submit the show once to Apple Podcasts and Spotify, within the hour of the upload, with whoever holds that Apple ID beside him. Prakriti never handles a password | Ivan | PUB-02 |
| Gabriel's two-minute takedown runbook (below), written and walked through once | Sonny writes, Gabriel keeps | PRV-12 |

**Taking an episode down.** Until take down in one step (PRV-12) lands by Mon 26 Oct, taking an
episode down is Ivan's hand step, done at once. **Gabriel can also do it himself, in two minutes, in
Yoga Marga's own Cloudflare account,** so a takedown never waits for Ivan (C6): he adds the episode's
GUID to `takedowns.json` in the feed bucket, and the feed Worker answers that episode with a 404 at
once; then he texts Ivan, who rewrites the feed and records the takedown, so the next release does not
put it back. Ivan's release script reads `takedowns.json` before every write and never removes a GUID
it did not add, so Gabriel's entry holds.

### Blocked by (owner actions)

- **The show's name** (Gabriel, Q-G26, due the day before the studio visit) and **Yoga Marga's new
  Cloudflare account** (Q-G2, created at the studio visit with his yes to the address cost). **With no
  home, the first episode waits** rather than going out somewhere temporary, because the feed that
  carries episode 1 carries the 25, and RedCircle's forwarding is unverified. This is not a money
  default: nothing is bought without Gabriel's yes, and Transistor ($19 a month) is an option only
  with it.
- **The money statements in the Sun 6 Sep talk** (Gabriel, Q-G8, Fri 16 Oct). With no answer all are
  cut, which removes the talk's opening line, and the recorded intro carries the topic. So this never
  blocks the episode.
- **The intro, outro and mid-roll**, recorded at Ivan's studio visit (Gabriel, Q-G9, by Fri 16 Oct).
- **Serenity's answer** does not block: version B goes without it.
- **Gabriel's voice reference** does not block: without it Ivan labels his talk by hand (Q-G10b).
- **R2 in Ivan's account** (Ivan, SET-07) and **the Anthropic key, workspace and cap** (Ivan, Q-I4).
- **Show art and show description** (Ivan, SET-17, Fri 16 Oct).

### Done when

1. **The chosen version is live**, confirmed by Ivan reading the show's feed back and by Apple
   Podcasts Connect's validation of the new feed; the show was submitted to Apple Podcasts and
   Spotify within the hour.
2. Loudness re-measured on the MP3 itself: -16 LUFS ± 1, true peak at or below -1.0 dBTP.
3. The last 5 seconds of the MP3 decode.
4. A coverage line and a cost line exist in the run log for that recording.
5. Gabriel's one written yes to both manifests is in the run log beside both hashes, and which version
   went out is logged.
6. Serenity heard the passages and saw the draft show description at her first meeting; her reply on
   the finished file, or her silence by the end of Thu 22 Oct, picked the version.
7. Ivan listened at the queued moments of both versions, logged with who and when, and the post-render
   check passed on both.
8. On the engine Mac, episode 1's single notification moved through Ivan's three moments (new recording
   found, processing started, ready for your yes; the copy is in SCOPE §8.3), updated in place, with a
   screenshot of each state.

### Not in Phase 1

- No YouTube publishing.
- No archive episodes.
- No class or call with students in anything public.
- No edited video, thumbnails or shorts.
- No labels for Serenity's voice unless her written yes is in.
- No "publish unless stopped".
- No trailer: it had no way to approve it, would have gone out before anyone could stop it, and added
  a hand upload.

---

## Phase 2. The archive

**Archive transcription starts Thu 22 Oct, once it has passed on the Sun 6 Sep talk. Formal phase
Mon 26 Oct to Fri 6 Nov 2026.**

**Goal.** Every one of the 958 archive videos is accounted for, the best teacher-only talks are
published as podcast episodes, Serenity and then Gabriel have the assessment, and the shortlist states
how many archive videos can go to YouTube after Fri 6 Nov.

### Before approvals open (by Mon 26 Oct)

Built in the Phase 1 week's sessions, after order 1, and ready before any archive approval. This is
the cut line's set (above).

| Task | Owner | IDs |
|---|---|---|
| Web app on the Up Next template, its sign-in copied as is: invite-only, passkeys; a returning person signs in with "Sign In with Passkey" in one step | Sonny | APP-01 |
| One review page: **"Approve for the Feed"** tied to the manifest, with "Goes live <day, time>. Undo" under it; a secondary **"Not Yet..."** button with one note, routed to Ivan and the activity log; **Keep / Cut / Add a Note** on each accuracy item, recorded on the manifest, with Cut routed to Ivan; "Next waiting piece" after an approval; Serenity as a required viewer of any piece that names her | Sonny | APP-04, APP-05, APP-08, ACC-01 |
| Ivan's release script: render `feed.xml`, check the manifest, put the file, read the feed back, at a fixed morning hour (Q-I20); it reads `takedowns.json` first and excludes anything with an open takedown | Sonny builds, Ivan runs | PUB-01, PUB-15 |
| Pause All Publishing; take down in one step, with the "Taken down" state that voids approvals; the activity log, with the audit log behind it | Sonny | OPS-06, APP-15, PRV-12, APP-14, OPS-07 |
| One email per approval session through Resend, "Ready for Your Yes: N Archive Talks", one "Open the Review Page" link per piece and never an approve link, because a mail scanner can open links; "To See" and "Needs a decision" by email the same way, one link each; Ivan's "Engine Quiet" and "Engine Out of Sync" too (SCOPE §8.3, email notice rows) | Sonny | NTF-08 |
| The heartbeat cron that emails Ivan when the engine is late; the once-daily report-only sweep, in awake time; database backups before the first approval is stored | Sonny | NTF-09, OPS-02, OPS-08 |
| The "Recorded in" label, the earnings and spoken-promise flags, the minors rule, and encryption and least access | Sonny | ACC-03, ACC-04, ACC-05, PRV-09, PRV-22 |
| A takedown tested on a separate test feed, never with a throwaway episode in the real feed | Sonny, Ivan | PRV-12 |
| Confirm Serenity's surname spelling and invitation email privately by text, including which Google account her invitation must match, before the invitations go out | Ivan | APP-01 |
| Invitations sent the morning sign-in opens, by Mon 26 Oct, with the accept rows dated the same day | Ivan | APP-01 |

**Done when (Mon 26 Oct):** Gabriel approves one piece from a signed-out iPhone, timed; one approval
is made with VoiceOver on an iPhone; Pause All Publishing refuses a publish; a "Not Yet..." note
reaches Ivan and the activity log; the takedown on the test feed returns a 404 and voids its approval;
a late heartbeat emails Ivan; last night's backup restores into a scratch database.

### Milestones

| Date | Milestone | Owner |
|---|---|---|
| Thu 22 Oct | Archive transcription starts on the files on Ivan's Mac or the drive (salvaged first), once it has passed on the Sun 6 Sep talk, within the machine-time budget below | Sonny |
| Thu 22 Oct (target; Mon 26 Oct at the latest) | The fuller archive assessment sent to Serenity, built from on-Mac counts and categories unless she has said yes to Q-S13 | Sonny drafts, Ivan sends |
| No later than Mon 26 Oct, after Serenity has seen it | The assessment sent to Gabriel, with a one-paragraph summary of what the archive holds and where the strongest material is | Sonny drafts, Ivan sends |
| Thu 22 to Fri 23 Oct | Ivan's hand-check listening for Gabriel's release samples (about 3 to 4 hours, an estimate, unmeasured) | Ivan |
| Week of Mon 19 Oct, on the weekly call | Q-I5 and the terms for the next stage raised (no number on any page); due Fri 23 Oct | Gabriel, Ivan |
| Mon 26 Oct | Sign-in opens; invitations go out that morning, with the accept rows dated the same day; the review page ready; approvals open. The shortlist reports how many shortlisted videos show and sound teachers only, checked by eye by Ivan. Ivan confirms the count sent on Fri 9 Oct (a confirmation only; any reset happened on Fri 9 Oct) | Sonny, Ivan |
| Week of Mon 26 Oct | **The account holder's sitting, with Ivan beside:** the account's password changed, 2-Step Verification turned on, automatic dubbing set to "Publish manually", then Prakriti's Google consent clicked once after seeing a screenshot of it; Prakriti checks it is the right channel. The YouTube tests (SET-13) run in the same sitting through the production Cloud project, on a test Brand Account channel owned by a Workspace user in the school's organization; if the private lock shows, Google's audit form is submitted the same day. Access can be withdrawn at any time in the Google Account, under third-party access | Account holder, Ivan, Sonny |
| Mon 26 Oct to Thu 5 Nov | Ivan listens at the queued moments of every archive piece before it reaches its approver, logged with who and when. Gabriel's approval sessions, 20 minutes each: Mon 26, Tue 27 and Thu 29 Oct, then Tue 3 and Thu 5 Nov, each opened from one email listing every waiting piece; one of them can be the weekly call. Serenity's sessions are her question (Q-S27). Ivan sends one end-of-day line whenever something has waited more than 48 hours | Ivan, Gabriel |
| Tue 27 Oct | **Serenity's second meeting,** 30 minutes, after the fuller assessment: the rest of her questions, due Fri 30 Oct | Serenity, Ivan |
| Tue 27 or Wed 28 Oct | The first approved archive episode goes out alone, the morning after its approval | Ivan (release script) |
| Thu 29 Oct | 18 approved | Gabriel |
| Fri 30 Oct | 18 live on the podcast feed. Serenity's privacy set due | Ivan; Serenity |
| Sat 31 Oct to Fri 6 Nov | One a day to the podcast feed, at Ivan's fixed morning hour (America/Los_Angeles; US daylight time ends Sun 1 Nov) | Ivan |
| Fri 6 Nov | **The proposed 25, or the number reset on Fri 9 Oct, live on the podcast feed**, each confirmed by reading the feed. Q-G24 needed, before the first YouTube approval | Everyone |

For a count of 10: 3 live by Fri 30 Oct, then one a day Sat 31 Oct to Fri 6 Nov.

### Tasks

| Task | Owner | IDs |
|---|---|---|
| Several watched folders (Studio and Archive) and the archive schedule in the budget below | Sonny | ENG-13, ENG-14 |
| The re-run is never extracted into a watched folder: the streaming extractor and its exclusion list apply to it as to the salvage; private items stay in the zip or go to a separate encrypted quarantine folder; no audio step runs on an archive file before inventory classifies it | Sonny | SET-02, ENG-13, PRV-08 |
| Dedupe by sound, skip tests and very short clips, classify every item, music scan | Sonny | ARC-02 to ARC-04, PIP-12, PIP-14 |
| Transcribe the whole archive locally (about 7 hours, unattended, free; the second engine adds about 15 after Fri 6 Nov) | Sonny | ARC-05 |
| Cloud triage with Haiku on the Batch API **only for items classified as talks from metadata**, after redaction; classes and calls are triaged from metadata alone until separate tracks exist; items whose metadata or voice share points to Serenity are triaged on the Mac from metadata only until Q-S13 is Granted, and no Claude session, Sonny included, opens them. Opus judges the shortlist; importing never starts paid work by itself | Sonny | ARC-06, ARC-07, ARC-14 |
| **Cost check:** the first paid archive batch is a pilot of ten talks, checked against Anthropic's usage page before the rest of the triage runs | Sonny, Ivan | OPS-13 |
| Stale-truth check (old prices, closed offers, "enroll now") and corrections memory | Sonny | ACC-02, ACC-06 |
| Segment episodes ("even five good minutes"): a segment inherits its source's type, gates and approvers, so a stretch of a class is a class until Q-S24; its checklist adds "From a class recorded in <month year>" where relevant; Serenity sees any segment of her teaching. Plus the schedule hint | Sonny | PIP-34, PIP-15 |
| **The YouTube count for the Mon 26 Oct shortlist:** Ivan checks by eye how many shortlisted videos show and sound teachers only, with no student named in them. YouTube publishing waits until after Fri 6 Nov | Ivan | PRV-14 (by hand) |
| The fuller archive assessment: to Serenity first, then to Gabriel with its one-paragraph summary. **Until Q-S13 is Granted, no Claude session, Sonny included, opens a transcript, title or description of Serenity's teaching or of any class. Sonny sees only counts and categories printed by a script on the Mac, and the name seed list is built the same way** | Sonny drafts, Ivan sends | ARC-08 |
| **Read the archive assessment**, sent no later than Mon 26 Oct, after Serenity has seen it, with a one-paragraph summary of what the archive holds and where the strongest material is (he asked for the whole-archive view on 7 Oct) | Gabriel | ARC-08 |
| VeraSales sessions are tagged by hand by Ivan until the venture router (PIP-13) exists after Fri 6 Nov; they get a private package, never published | Ivan, Sonny | PIP-13, Q-G17 |
| Studio download fallback for a handful of items missing from Takeout | Sonny | ARC-09 |
| Consent capture kit drafted for a lawyer: spoken class note, Zoom disclaimer, per-use release, English and Spanish | Sonny | PRV-19 |
| Check channel eligibility; set YouTube's automatic dubbing to "Publish manually", before any upload, in the account holder's sitting (week of Mon 26 Oct) | Account holder (Q-GS7) | SET-12 |
| Before the consent click, in the same sitting: change the account's password and turn on 2-Step Verification. Ivan and Prakriti never handle the password | Account holder (Q-GS7) | SET-14, Q-G21 |
| The YouTube tests in the same sitting, through the production Cloud project, before the first archive video goes public | Sonny, Ivan | SET-13 |
| Approve their own pieces; Serenity approves her own pieces and the privacy receipt of any piece in which an Other voice was found | Gabriel, Serenity | APP-05, PRV-05 |
| The terms for the next stage, raised on the weekly call in the week of Mon 19 Oct and agreed by Fri 23 Oct, no number on any page | Gabriel, Ivan | Q-I5 |
| The price named (Fri 23 Oct) | Ivan | Q-I5 |
| The Developer ID certificate (Fri 16 Oct) | Ivan | Q-I3 |
| The always-on Mac decided (Fri 6 Nov) | Ivan and Gabriel (D2) | Q-I1 |
| **RAID build day**, before Mon 9 Nov (the day itself OPEN for Ivan and Gabriel) | Ivan, Gabriel | Q-GS5, Q-I15 |
| Agree Ivan's one-page note: Yoga Marga School owns the data, except each teacher's own voice data, which is theirs, and Ivan processes it for the school (Ivan drafts by Fri 16 Oct; agreed by Fri 30 Oct) | Gabriel, Serenity | Q-I16 |

### Machine-time budget

All archive work rides on Ivan's MacBook Pro, which travels. So the work is budgeted:

- Archive transcription **runs on the Mac whenever it is plugged in, day or night, from Thu 22 Oct,
  plus two booked nights.** The engine schedules archive work itself: it runs when the Mac is on power
  and no studio job is queued (SCOPE §7.2).
- Audio-only work (dedupe, classify, music check, transcription, speaker windows) runs over all 958
  items.
- The YouTube count on the shortlist (about 100 items) is checked by eye by Ivan until the screen check
  lands after Fri 6 Nov.
- Two nights booked as calendar events once transcription has passed on the Sun 6 Sep talk, for nights
  from Thu 22 Oct, with the MacBook on power, lid open, drive attached.
- **A free-space floor of 100 GB pauses archive work, never studio work.** Reason: the archive, the
  salvage and the re-run together nearly fill the Mac.
- The 694 salvaged files are the primary input; the re-run fills the gaps.
- **If Ivan travels on the dates he lists in row 23:** the studio Mac counts only once a notarized build
  has launched there (Q-G22, Q-I3). Until then the archive run slips and Ivan tells Gabriel the new
  count.

### Blocked by (owner actions)

- **The proposed 25 come from Gabriel's teacher-only talks and their segments.** Talks from sessions
  where students only listened wait for Serenity's Q-S30 (Fri 16 Oct), and until a name list or a
  seed list exists (Q-S11a, Fri 16 Oct), nothing from a session where students were present can be
  approved; Ivan resets the number on Fri 9 Oct on that basis. Her other answers are due Fri 30 Oct,
  and until then each question's most private setting applies. Pieces that name her wait for her
  look, up to her hold time.
- **The account holder confirmed** (Q-GS7, Mon 12 Oct) and **the account holder's sitting in the week
  of Mon 26 Oct** (Q-G21): password change, 2-Step Verification, dubbing, then the consent click.
  Managers and Editors cannot authorize API apps; only the owner can. This blocks YouTube only, which
  follows after Fri 6 Nov.
- **Channel settings** (SET-12), including automatic dubbing, which is on by default and would put
  an AI voice speaking a teacher's words in other languages without anyone deciding.
- **The archive files** on Ivan's Mac or the drive (SET-01, SET-02, Q-I17).
- **Ivan's listening:** the release samples, Thu 22 to Fri 23 Oct, and every archive piece, Mon 26 Oct
  to Thu 5 Nov.
- **Gabriel's approval sessions**, Mon 26 Oct to Thu 5 Nov.
- **Gabriel's voice clip** (Q-G10b). Without it, Ivan labels each talk by hand, which limits how many
  of the 25 can be ready.

### Done when

1. **The proposed 25, or the number reset on Fri 9 Oct, live on the podcast feed by Fri 6 Nov**, each
   confirmed by reading the feed.
2. Every one of the 958 accounted for: kept, duplicate, test, quarantined, or shortlisted.
3. Gabriel's release samples passed (09-06, 09-13, one Business of Yoga recording of his or the
   substitute Gabriel-only archive talk, and at least three Zoom-era recordings of his with students in
   the session, each student moment rejected): zero seconds of student speech labeled as a teacher.
   Serenity's solo-talk sample gates only her pieces; classes and calls stay locked until their own
   samples pass.
4. The post-render check passed on every published MP3.
5. Ivan's listen logged, with who and when, for every archive piece before it reached its approver.
6. The assessment delivered to Serenity, then to Gabriel with its one-paragraph summary.
7. The shortlist states how many archive videos can go to YouTube.
8. A takedown tested on the separate test feed.

### Not in Phase 2

- No classes with students, in any form, in public, and no stretch of a class until Q-S24.
- Nothing from a session where students were present until Serenity answers Q-S30.
- No archive talk on YouTube before Mon 9 Nov. Archive video is not re-edited.
- No quarantined material, and no guest teachers in public.
- No shorts from the archive.
- No Serenity piece without her approval.
- No VeraSales piece published.
- No bulk upload of archive audio to YouTube as still-image videos (NEV-16).

### After Fri 6 Nov: below the cut line

Everything here is below the cut line and lands from Mon 9 Nov. Web Push, the web app manifest and the
Turn On Notifications control come here; **until then notices come by email.**

| Task | Owner | IDs |
|---|---|---|
| **Archive talks on YouTube, from Mon 9 Nov,** at most two a day, so the channel does not look like a dump of old uploads; the cap is Gabriel's to change. The YouTube connection; a new title, description, chapters, thumbnail and captions, then visibility, after one yes. A video goes public only if its picture and sound are teachers only and no student is named in it; otherwise a new redacted copy, or podcast only. Prakriti's YouTube code has no delete call. The 25 do not include these | Sonny | PUB-07, PUB-08, PUB-11, PUB-12, PKG-09, PRV-15 |
| **Before any flip:** the screen check (PRV-14, a hard dependency of PRV-15); the name scrubber on the original's transcript, any student or third-party name found or unresolved blocking the flip; the comment count and the audio tracks read through the API (comments present means hold them or publish a new copy; a dubbed track is removed first); verified read-only on the first real video after the owner's consent, including whether YouTube's automatic captions stay visible after new captions are added | Sonny | PRV-14, PRV-15 |
| Thumbnail frame picking and video quality signals; three thumbnails, shown as YouTube feed cards (type-only until Q-G24 and Q-S9); option A set through the API; a one-minute checklist for Test & Compare in YouTube Studio (Ivan's step, as a channel Manager) | Sonny, Ivan | PIP-20, PIP-21, PKG-06, APP-23, PUB-10 |
| Second transcription engine (Parakeet, in process through FluidAudio) | Sonny | PIP-07 |
| Sound map, and music identification with ShazamKit | Sonny | PIP-11, PIP-12 |
| Venture router and content-type classifier for studio sessions (VeraSales tagged by hand until then) | Sonny | PIP-13, PIP-14 |
| Web Push and the Live notification, together with the web app manifest and a Turn On Notifications control (never after them) | Sonny | NTF-04, NTF-07, APP-19 |
| Prakriti's own release slots, stored as wall-clock time plus America/Los_Angeles and run by a 5-minute cron (SCOPE §12.4); the release queue's runway and the publish calendar, where every item can be scheduled and unscheduled by keyboard and by tap | Sonny | PUB-13, PUB-14 |
| Today and Recordings; engine presence; one status vocabulary on every screen; the recordings library and role views | Sonny | APP-02, APP-03, APP-17, APP-21, APP-10, APP-18 |
| The cost ledger and the cost-meter screen (until then the Console spend limit is the cap) | Sonny | OPS-04 |
| Chapters; the package zip | Sonny | PKG-05, PKG-10 |
| Engine settings window | Sonny | ENG-08 |
| Ask for Changes proper, guided speaker correction, the rest of undo | Sonny | APP-06 to APP-08 |
| The "Your consents" screen; People and consent; sources and rules; notification settings; settings; onboarding; account page; empty states | Sonny | PRV-06, APP-11 to APP-13, APP-15, APP-16, APP-20, APP-22 |
| Serenity's approval queue; where copies live | Sonny | PRV-16, PRV-13 |
| Weekly note (it lists each session that began with no test clip before it, because the sound check is the only routine human step and is otherwise never measured), preferences and quiet hours, publishing paused or resumed | Sonny | NTF-06, NTF-10, NTF-12 |
| iCloud space watch | Sonny | OPS-15 |

Take down in one step (PRV-12) is above the line, by Mon 26 Oct, before the first archive episode.
The YouTube tests run in the account holder's sitting, week of Mon 26 Oct, before the first archive
video goes public.

---

## Phase 3. The studio package

**Mon 9 Nov to Mon 30 Nov 2026.** Starts once Ivan and Gabriel agree the terms for this stage (Q-I5,
due Fri 23 Oct).

**Goal.** Studio sessions get the full package (edited video, three thumbnails, chapters, captions,
shorts), and the 72-hour clock starts on an always-on Mac.

### Milestones

| Date | Milestone | Owner |
|---|---|---|
| Mon 9 Nov | (Money gate retired Sat 10 Oct.) Archive talks start on YouTube, at most two a day (below the cut line) | Ivan |
| Set by Q-I1 | Engine on the always-on Mac, as a notarized Developer ID build. **The 72-hour clock starts that day** | Ivan, Sonny |
| Fri 13 Nov (target) | Edited video on for studio talks: edit, three thumbnails, chapters, captions, uploaded private first, then public after a yes | Sonny |
| Fri 20 Nov (target) | Shorts on, cut from the vertical twin | Sonny |
| Mon 30 Nov | Phase 3 check. Thu 26 Nov is Thanksgiving, so the three sessions may be any three in a row that end by Mon 30 Nov | Everyone |

### Tasks

| Task | Owner | IDs |
|---|---|---|
| Buy and place the always-on Mac beside the RAID with the engine-host items above; keep a second copy of the masters before they leave iCloud | Ivan, Gabriel | ENG-17, Q-I1, Q-GS5, Q-I15 |
| The Developer ID certificate, created by Fri 16 Oct | Ivan | SET-08, Q-I3 |
| A notarized, stapled build installed on the always-on Mac, the day it is in place (Q-I1) | Sonny | ENG-09 |
| Edited video cut from the same decisions as the podcast, with a 540p review proxy | Sonny | PIP-22, PKG-07 |
| Three thumbnails, chapters and captions for studio talks; YouTube uploads private first | Sonny | PKG-06, PKG-09, PUB-09, PUB-11 |
| Shorts from the vertical twin, with calm typographic captions. They go to YouTube Shorts after a yes. Instagram waits for Phase 5 and nothing is asked of Gabriel there (Q-G29, OPEN for him); if he wants to share himself, the review screen gives him the file and caption | Sonny | PIP-23, PIP-24, PKG-08 |
| Video files use the same multipart upload through the Worker (32 MiB parts) that every file uses from Phase 1, so no presigned links are needed | Sonny | PIP-26 |
| OBS "recording stopped" signal, the "that was good" marker, a live recording guard. The live recording guard (PIP-29) can retire the manual sound check | Sonny | ENG-06, PIP-28, PIP-29, SET-06 |
| Per-episode intro, if Gabriel wants it: Prakriti drafts two or three sentences for each episode; Gabriel records a week's worth in one sitting. An ElevenLabs intro in his own voice stays his option, with the AI label | Sonny, Gabriel | SET-16, PKG-12 |
| Timecoded comments, taste log, Test & Compare results written back, impact note | Sonny | APP-24, LRN-03, LRN-04, NTF-11 |
| Findability check, themed playlists, YouTube podcast playlist, download counts with OP3 | Sonny | BIZ-05, PKG-13, PUB-16, PUB-17 |
| Find and forget a person; retention timers | Sonny | PRV-17, PRV-18 |
| Storage lifecycle (masters to the RAID, never deleted automatically); one-action export to storage Yoga Marga controls | Sonny | OPS-09, OPS-10 |
| Other recordings (a phone recording, anything outside the studio flow) go into the shared Studio Recordings folder through Finder on a Mac or the Files app on an iPhone. No raw recording is uploaded to the cloud | Gabriel, Serenity | APP-09 |
| An optional weekly teleprompter script drafted from Gabriel's own best moments and fact-checked before he records. Only if he wants it, his own material only, behind the money gate | Sonny, Gabriel | ACC-08 |
| Gabriel's yin classes recorded with his microphone on its own track. A yin episode only under the student rule | Gabriel; Sonny | SET-03, PKG-11 |
| Decide whether new audio episodes may also go to YouTube by feed. Never the archive, because YouTube's inauthentic-content policy targets hundreds of near-identical still-image videos (06 §2.12) | Ivan, Gabriel | PKG-19 |
| Decide whether the browser's own video controls are acceptable under "never skeuomorphic" | Ivan | Q-I9 |
| Audio-only class episodes, **only** under the student rule | Sonny, Serenity | PKG-11, PIP-30, Q-I12 |

The Yoga Marga website redesign from the 7 Oct page is separate from Prakriti; Ivan asks about it on
the weekly call.

### Blocked by (owner actions)

- **The money gate** (Ivan, Q-I5).
- **The always-on Mac decided and bought** (Ivan and Gabriel, Q-I1). Who pays for it is a money
  question.
- **The Developer ID certificate** (Ivan, Q-I3).
- **Studio recordings**: the Phase 3 check needs three sessions in a row (Gabriel, Q-G5).
- For any class: the student rule, which needs Serenity's rule (Q-S1 to Q-S4, Q-S24) and the lawyer's
  read (Q-I12).

### Done when

1. Three studio sessions in a row ready for a yes within 72 hours of the recording ending, on the
   always-on Mac; median ready-to-live measured. Any three consecutive sessions ending by Mon 30 Nov
   count.
2. A notarized Developer ID build running there (`spctl -a -vv` passes).
3. Every produced file tail-decoded.

### Not in Phase 3

- No library, no voice datasets, no Spanish.
- No "publish unless stopped" setting.
- No automated posting to Instagram, TikTok or other platforms.
- No re-edits or shorts of archive video.
- No class in public except under the student rule.

---

## Phase 4. The Library and voices

**From Tue 1 Dec 2026**

**Goal.** Each consenting teacher's own words become a searchable library that answers with their
actual words and a timecode, and teachers who say yes get a clean voice dataset to use themselves.

### Milestones

| Date | Milestone | Owner |
|---|---|---|
| Tue 1 Dec | The Library starts with Gabriel's material, if his Library consent is in (Q-G28) | Sonny |
| Fri 11 Dec (target) | "Ask the archive" passes its 20-question check | Sonny |
| Fri 18 Dec (target) | Gabriel's voice dataset handed to him, if he said yes; Spanish captions and notes on for each teacher who says yes | Sonny |

### Tasks

| Task | Owner | IDs |
|---|---|---|
| Per-teacher knowledge base; "Ask the archive" that quotes only, with timecodes; export of a teacher's passages | Sonny | LIB-01, LIB-02, LIB-13 |
| Voice datasets, Gabriel first; Serenity's locked until her written yes | Sonny | LIB-03 |
| Spanish captions and notes for each teacher who says yes, checked by a Spanish reader before publishing | Sonny | PKG-17, Q-S21 |
| A private students-only feed of full classes, if approved: one feed link per student that can be switched off, only under the new class release; or full classes stay in Skool behind its login | Sonny | PUB-06, Q-GS4 |
| The Prakriti MCP server, so Sonny can read the library and queue from a chat | Sonny | APP-26 |
| Decide on their own AI voice, made in their own ElevenLabs account | Gabriel, Serenity | Q-G16, Q-S8 |
| Library consent per teacher (Q-G28, Mon 30 Nov; Q-S28, when Serenity is ready). Each teacher owns the Library of their own words, can withdraw it at any time, and takes it with them | Gabriel, Serenity | PRV-06 |

### Blocked by (owner actions)

- Each teacher's written consent for the Library and, separately, for a voice dataset (Q-G28, Q-S28,
  Q-G16, Q-S8).
- For Spanish: each teacher's yes, and a Spanish reader.
- For the private feed: Gabriel and Serenity's yes (Q-GS4), Serenity's rule and the new class
  release.

### Done when

1. 20 test questions answered with working timecodes and only the teacher's own words.
2. Gabriel's dataset is at least 30 minutes, checked by listening to 10 random clips.
3. No Serenity material in any voice set without her signed consent on file.

### Not in Phase 4

- No answer ever generated in a teacher's voice. Quotes only.
- Prakriti never makes an AI voice or face of anyone. A teacher may make their own, in their own
  account. With that teacher's written yes, Prakriti prepares clean recordings for it and uses the
  result only for a script that teacher approved, always labeled as AI. Nothing of Serenity's
  without her written yes.
- No avatars in this phase. No Spanish audio or dubbing.

---

## Phase 5. Later

**2027, not before Mon 4 Jan.** Each item switches on alone, with its own owner action and its own
check, one at a time.

| Item | Owner | IDs | Gate |
|---|---|---|---|
| The "publish unless stopped" setting, per lane | Ivan decides whether it ever exists | PUB-21, Q-I7 | Not before Mon 30 Nov and only after 20 clean approvals in a lane; a teacher's pieces only with that teacher's own yes for that lane; never anything with other voices |
| GoHighLevel for Instagram, TikTok, Facebook and LinkedIn; calls to action by content type with tracked links; content-to-lead ledger | Gabriel, Sonny | PUB-18 to PUB-20, BIZ-01, BIZ-02, Q-G13, Q-G29 | Social Planner confirmed on Yoga Marga's plan |
| VeraSales publishing through the same engine (its sessions already get a private package from Phase 2) | Gabriel, Ivan | PIP-13, Q-G17 | Its own approvals |
| Performance feedback; the audience picks the clips | Sonny | LRN-01, LRN-02 | Enough published history to learn from |
| Member library; YTT coverage map; recording brief; question mining from public viewer comments only, never students' speech from recordings | Sonny, Serenity | LIB-04, LIB-05, LIB-12, LIB-14 | The three YTT syllabi (Q-S14); LIB-12 also Serenity's yes |
| Visual search across footage, of teacher-only footage, with each teacher's written yes | Sonny | LIB-10 | Each teacher's written yes |
| Final Cut handoff; re-runs when models improve; pose-aware class chapters | Sonny | PIP-31 to PIP-33 | None beyond the usual checks |
| Quote cards, newsletter and blog post, daily one-minute teaching, seasonal calendar | Sonny | PKG-14 to PKG-16, BIZ-07 | Ivan's yes per item |
| Testimonials, past-student notes, student opt-in registry; comment reply drafts, only for a teacher who has said yes and never in Serenity's name without her yes | Sonny, Serenity | BIZ-03, BIZ-04, PRV-20, BIZ-06 | Each student's own written yes; drafts never sent automatically |
| Spanish audio, or an AI voice or avatar a teacher made themselves, used only for scripts that teacher approved, with written consent; likeness watch | The person whose voice or face it is | PKG-18, LIB-07, LIB-08, PRV-21 | That person's written consent |

**Not in Phase 5, or ever:** everything on the Never list in SCOPE §5.16, each with its reason.

---

## Run costs (estimates)

These are run costs, not anyone's fee. They are estimates from SCOPE §13.7 and §16. The first paid
archive batch is a pilot of ten talks, checked against Anthropic's usage page before the rest of the
triage runs (OPS-13).

| Item | Estimate |
|---|---|
| Claude, one published studio piece | about $0.55 to $1.05 |
| Claude, one published archive piece (Batch API, half price) | about $0.27 to $0.53 |
| Claude, triage of the archive talks | about $1.50 or less (the whole-archive figure; triage now covers talks only) |
| Claude, deep work on a 100-item archive shortlist | about $27 to $53 |
| Transcription and speaker labels, all of it | $0 (on the Mac) |
| R2 storage | about $1 to $7 a month |
| The podcast-only web address, in Yoga Marga's new Cloudflare account (Q-G2) | Unknown until priced; Gabriel says yes to the cost at the studio visit before anything is bought |
| Cloudflare Workers Paid plan (Ivan's account) | to confirm before the Phase 0 routes deploy |
| Optional: Auphonic mastering, only if the ffmpeg chain sounds uneven (Q-I14) | $25 a month, billed yearly |
| Optional: Transistor, only with Gabriel's yes (Q-G2) | $19 a month |
| Optional: an always-on Mac mini (Q-I1) | about $1,499 to $1,699, one time |
| Drive for the archive | an external SSD of about 2 TB, cost to price (Q-I17) |
| A lawyer's read of the class release and the voice permissions (Q-I12) | Not researched; who pays is OPEN for Ivan and Gabriel (suggested: Yoga Marga, as the data owner). Each teacher may have their voice consent read by their own lawyer |

---

## Time it takes

Ivan's time was never budgeted, and every phase rests on it (round 1, finding C12). Sonny builds
only inside sessions Ivan runs, so the build needs dated sessions on his calendar. Nothing below is
an invented number: the session plan is proposed, and Ivan's hours are his to fill in.

**Build sessions:** Ivan books them through Fri 6 Nov on Fri 9 Oct, first (row 23), with his travel
dates. Proposed: three 2-hour sessions a week, on Mon 12, Wed 14, Fri 16, Mon 19, Wed 21, Fri 23,
Mon 26, Wed 28 and Fri 30 Oct, and Mon 2, Wed 4 and Fri 6 Nov. Times of day: OPEN for Ivan. Sonny then
sizes the work above the cut line in sessions and writes the line; if it does not fit, Ivan books more
sessions or resets the number that day.

**Ivan's listening.** Ivan listens at the queued moments of every archive piece before it reaches its
approver, Mon 26 Oct to Thu 5 Nov, logged with who and when. **Ivan's listening time per piece is
measured on the Sun 6 Sep talk first and budgeted from that measurement** (row 26). The round 3 critics
estimated about 6 to 7 minutes a piece, which is about 2 to 3 hours for 25: their estimate, OPEN until
measured.

**Hand labels.** Ivan measures the hand-label minutes on the Sun 6 Sep talk this week (row 26).
Without Gabriel's voice clip, his talks are labeled by hand at that rate.

| Phase | What Ivan does in it | Ivan's hours |
|---|---|---|
| 0. Ground | The sizing and the session booking, two messages, the pre-deploy sequence, DECISIONS v2, the hand-label measurement, Serenity's first meeting, the studio visit and the Cloudflare sitting, RedCircle and listing-time checks, the Takeout request, show art, R2, the YouTube project, the data note | OPEN for Ivan to confirm |
| 1. First light | The listen on both versions of episode 1, the review links and Gabriel's call, the feed home, the upload and the submission within the hour, booking Serenity's second meeting | OPEN for Ivan to confirm |
| 2. The archive | The sample listening (about 3 to 4 hours, an estimate, unmeasured); his listen at every archive piece before it reaches its approver (measured on 09-06, then budgeted; the critics' estimate is about 2 to 3 hours for 25); the YouTube count by eye; two booked nights; the account holder's sitting; Serenity's second meeting; the release script each morning from Tue 27 or Wed 28 Oct; end-of-day lines; and, if Q-G10b is not in, hand-labeling Gabriel's talks at the measured rate | OPEN until measured |
| 3. The studio package | The always-on Mac, the RAID build day, the price | OPEN for Ivan to confirm |
| 4. The Library and voices | Consents and checks | OPEN for Ivan to confirm |
| 5. Later | One decision per item | OPEN for Ivan to confirm |

---

## Open questions

Each belongs to one owner, carries a recommended answer, and has a date. Sorted by date. The same
questions, with their reasoning, are in SCOPE §18; the plain-language versions for Gabriel and
Serenity are in SCOPE §11.9. Operational questions say what happens with no answer; consent, privacy
and money questions never default to a yes. **Gabriel's separate things through Fri 16 Oct are seven**
(Phase 0 tasks); every other row of his with a suggestion is covered by one reply, "yes to the
suggestions". **Serenity meets Ivan twice:** first in the week of Mon 12 Oct, for the first look, the
episode 1 passages and three questions needed by Fri 16 Oct; then for 30 minutes on Tue 27 Oct, after
the fuller assessment, for the rest of her questions, needed by Fri 30 Oct.

| Needed by | Owner | ID | Question | Recommended answer |
|---|---|---|---|---|
| Fri 9 Oct | Ivan | Q-I1 (v1) | Which Mac runs the engine for now? | Ivan's MacBook Pro, with "pauses when the lid is closed" shown honestly |
| Fri 9 Oct | Ivan | Q-I6 | Set the record straight with Gabriel? | Yes, inside the one Fri 9 Oct message: the archive is not transcribed yet (only the studio sessions are), and the podcast has been on the list since September |
| Fri 9 Oct | Ivan | Q-I11 | Move the 10-07 transcripts out of the shared iCloud folder? | Yes, into Prakriti's private store; they hold students' personal details and sync to everyone |
| Mon 12 Oct, or at the studio visit if sooner (asked Fri 9 Oct) | Gabriel | Q-G1 | Podcast first, starting with the Sun 6 Sep talk; the first archive episode the morning after its approval (Tue 27 or Wed 28 Oct)? | Yes. That talk goes first because it is already on the Mac and has one voice; Serenity hears its passages about her first. Your yes also covers public audio of your own talks and Claude reading the text of your own talks, with names replaced; sent from your own email, it counts as Granted for your own uses until the "Your consents" screen exists after Fri 6 Nov |
| Mon 12 Oct, or at the studio visit if sooner (asked Fri 9 Oct) | Gabriel | Q-G19 | Proposed: 25 archive talks as podcast episodes by Fri 6 Nov, counted on the feed; 72 hours for studio recordings; and under 2 minutes of your time per piece. Still the numbers? | 25: proposed, counted on the podcast feed, from your teacher-only talks and self-contained stretches of them. This message carries the count as two numbers: talks from sessions with no students present, and talks from sessions where students only listened, which wait on Serenity. If the pool does not clearly exceed 25 after some talks fail the privacy or accuracy checks, Ivan resets the number in this same message. Fallback: "10 by Fri 6 Nov, and 25 once Serenity's talks are cleared." Mon 26 Oct is a confirmation only. YouTube follows after Fri 6 Nov, at up to two a day, and is not counted. 72 hours: a proposed target, ready for your yes within 72 hours of a new studio recording ending, once Prakriti runs on an always-on Mac; going live also needs a yes, and the median time from ready to live is measured, not promised. 2 minutes: "Proposed: under 2 minutes of Gabriel's time per piece, after Ivan's listen"; it becomes your goal only if you say yes |
| Mon 12 Oct (asked Fri 9 Oct) | Serenity | Q-GS7 (ID kept) | The school's email runs on Google Workspace (checked from its public mail records, Thu 8 Oct). Confirm you hold the contact account that owns the channel, who else can sign in, and whether the channel is in the YouTube Partner Program | Yes, the school's contact account, held by you (to confirm). That account holder owns SET-01, SET-12, SET-14, Q-G20 and Q-G21, and adds Gabriel and Ivan as channel Managers, so Test & Compare and any manual visibility change are Ivan's steps. The password change, 2-Step Verification, dubbing setting and consent click happen in one sitting with Ivan beside, in the week of Mon 26 Oct; Prakriti never handles the password |
| Mon 12 Oct | Ivan | Q-I17 | Where does the archive land? | An encrypted external SSD of about 2 TB (cost to price, not researched), attached before the re-run lands; the salvage output and the re-run go there. With no drive: extract part by part, skipping private entries, and delete each re-run zip after its entries verify against their hashes, with Ivan's yes. Reason: about 811 GiB is free, and the salvage output, the re-run zips and their extraction need more |
| Mon 12 Oct | Ivan | Q-I18 | One studio visit with Gabriel in the week of Mon 12 Oct? | Yes: OBS set to Hybrid MP4 with separate tracks, the vertical output back on for talks, the 2-minute test with its MP4 box tree captured twice, the studio Mac and device details, the intro recording with the name and the ask as separate one-line takes, and Yoga Marga's new Cloudflare account created with Gabriel as owner after his yes to the address cost, all in one visit by Fri 16 Oct. Fallback: a 30-minute screen share |
| Wed 14 Oct | Account holder (Q-GS7) | Q-G20 | Will the account holder re-run Google Takeout of the channel? | Yes, off the critical path: a request on Wed 14 Oct, signed in on Ivan's Mac, then downloads over one to three days with the Mac on power and a wired network, one part at a time in Chrome, each part's size checked. The session stays on Ivan's Mac until the last part's size verifies, then signs out. Skipped if the count shows the qualifying talks are already among the 694 salvaged |
| The day before the studio visit (asked Fri 9 Oct) | Gabriel | Q-G26 | Is the podcast a new Yoga Marga show, and what is it called? | A new Yoga Marga show that you name (the name is yours: OPEN). Ivan brings three suggestions; nobody invents the name. "Welcome to <name>" is recorded as its own one-line take. Your existing RedCircle show stays as it is. No answer by Fri 16 Oct: the first episode waits for the show's home, because a show cannot be submitted without a name and nobody invents one |
| The day before the studio visit (asked Fri 9 Oct) | Gabriel | Q-G7 | Enrollment is paused, so what is the one thing a listener should do next? | One ask, the same every episode, in your words; Ivan brings two suggestions to choose from or replace. It is recorded as its own one-line take, so it can change later. No answer: no ask, never an invented one |
| At the studio visit, by Fri 16 Oct | Gabriel | Q-G2 (Q-G3 merged in) | Where does the podcast live, and who owns it? | A web address Yoga Marga buys only for the podcast, held as its own zone in a **new** Cloudflare account registered to a Yoga Marga address (the school's contact address, or your own Yoga Marga address if you have one: to confirm), separate from the account that runs VeraSales production (07 l.355). You are its owner; Serenity and Ivan are members. It is created at the studio visit, in the same sitting as your yes to the address cost; the cost is unknown until priced, and nothing is bought without your yes. Who buys the domain: Yoga Marga, on your yes. Which Apple ID owns the show in Apple Podcasts Connect, and which Spotify account owns it: ones on the school's address (to confirm which). The feed's owner email is the school's address, so the exit in Q-GS3 works and Spotify's claim code reaches someone on Fri 23 Oct. Ivan does the rest: the zone, the bucket, a token limited to that bucket, the feed Worker (ready Tue 20 Oct), and the Apple Podcasts and Spotify submission within the hour of episode 1, with whoever holds that Apple ID signing in beside him. Prakriti never handles a password. Transistor ($19 a month) only with your yes. No answer: the first episode waits for the show's home rather than going out somewhere temporary, because the feed that carries episode 1 carries the 25, and RedCircle's forwarding is unverified. This is not a money default |
| At the studio visit, by Fri 16 Oct | Gabriel | Q-G9 | Will you record a short intro, outro and 5-second mid-roll? | Yes: record during the studio visit from Sonny's scripts (about 30 words each), in one sitting, with "Welcome to <name>" and the listener ask as separate one-line takes so either can be swapped. The intro opens episode 1. No AI voice, so no AI disclosure is needed |
| At the studio visit, by Fri 16 Oct | Gabriel (Ivan sets it) | Q-G4 | Each microphone on its own track and Zoom on another, Hybrid MP4 (not MKV), the teacher on headphones? Was the vertical canvas turned off on purpose? | Yes to all; Ivan sets it at the studio visit, turns the vertical output back on for talks, and makes a 2-minute test |
| At the studio visit, by Fri 16 Oct | Gabriel (Ivan notes it) | Q-G22 | What is the studio Mac (chip, memory, macOS), and is it always on? | If it is Apple Silicon on macOS 26 or later and always on, it could host the engine instead of a new Mac mini, with heavy work paused while OBS records. It counts as a fallback only once a notarized build has launched there |
| At the studio visit, by Fri 16 Oct | Ivan (notes it) | Q-GS6 | Which macOS and iOS versions do Gabriel's and Serenity's Mac and iPhone run? | Noted by Ivan at the studio visit, not asked of them. Web Push needs macOS 14 and iOS 16.4 or later |
| Fri 16 Oct | Ivan | Q-I2 | Enable R2? | Yes, this week; it is a billing step in the dashboard. Billing and usage notifications for Workers, R2 and D1 on the same day; then `wrangler login` again, checked with `wrangler r2 bucket list` |
| Fri 16 Oct | Ivan | Q-I3 | Create the Developer ID Application certificate? | Yes, now; about 20 minutes in Xcode, and it also unblocks Coffee Cup. The studio Mac can only count as the travel fallback once a notarized build has launched there |
| Fri 16 Oct | Ivan | Q-I4 | Whose Anthropic key pays, and what monthly cap? | Prakriti's own Anthropic workspace and key, billed to the Prakriti project, with a Console spend limit equal to the cap; $150 a month for October and November, with alerts at 50% and 80%; reaching the cap is a Needs a decision for Ivan, never a silent pause |
| Fri 16 Oct | Ivan | Q-I10 | Quiet hours for Web Push? | 9:00 pm to 8:00 am in each person's own time zone, held until morning |
| Fri 16 Oct | Ivan | Q-I13 | Put Cloudflare Access in front of the site? | No. It would hide the features page; the app's own gate covers every other path |
| Fri 16 Oct | Ivan | Q-I19 | "Publishing paused or resumed" notification on for all three? | Yes; it is a safety signal |
| Fri 16 Oct | Ivan | Q-I20 | When does a release go out? | Episode 1: by hand on Fri 23 Oct. Until Fri 6 Nov, Ivan runs his release script at a fixed morning hour, in America/Los_Angeles time; US daylight time ends Sun 1 Nov 2026. The hour is Ivan's to pick. After Fri 6 Nov, Prakriti's own release slots, stored as wall-clock time plus America/Los_Angeles |
| Fri 16 Oct | Ivan | Q-I22 | Should Other voice segments be offered for "Is this Serenity?" only at the engine Mac? | Yes, so no possibly-student audio is uploaded; teacher speech wrongly cut is the accepted price (SCOPE §7.8 rule 8) |
| Fri 16 Oct | Gabriel | Q-G8 | The Sun 6 Sep talk has two income claims about your own results, one of them in its opening line, and one spoken offer near the end. Keep all with a note, cut all, or choose each? | Cut them, or keep them with a plain note in your words. No answer by Fri 16 Oct: all are cut, which removes the talk's opening line, and the recorded intro carries the topic. Each statement and its time are in Ivan's private message, never on a page |
| Fri 16 Oct (yes to the suggestions) | Gabriel | Q-G6 | Which channel holds the "900", and does your personal channel hold Yoga Marga teaching? | The school channel only. No answer: the suggestion stands |
| Fri 16 Oct (yes to the suggestions) | Gabriel | Q-G18 | How should the 25 be released? | The first approved archive episode goes out alone the morning after its approval (Tue 27 or Wed 28 Oct); 18 are live by Fri 30 Oct; then one a day Sat 31 Oct to Fri 6 Nov, which makes 25 on the feed. For a count of 10: 3 by Fri 30 Oct, then one a day Sat 31 Oct to Fri 6 Nov. A takedown is tested on a separate test feed, never with a throwaway episode in the real one. Ivan publishes every episode through Fri 6 Nov, by hand for episode 1 and then with his release script; Prakriti's own release slots switch on after Fri 6 Nov. No answer: the suggestion stands |
| Fri 16 Oct (yes to the suggestions) | Gabriel | Q-G23 (Q-G10a merged in) | Who approves your solo talks: you only, or you or Ivan? | Either of you. Pieces that name Serenity also wait for her look, up to her hold time (Q-S26). No answer: you approve your own; Ivan does not |
| Fri 16 Oct (asked Fri 9 Oct) | Gabriel | Q-G10b | May Prakriti learn your voice from a 2 to 3 minute clip, kept only on the Mac that runs Prakriti? | Yes, in writing, when you are ready; requested by Fri 16 Oct. A written yes from your own email counts as Granted for this use until the "Your consents" screen exists after Fri 6 Nov. A plain-language permission now; a lawyer-read version replaces it within four weeks of the lawyer starting, and you may have it read by your own lawyer. Proposed retention: deleted when you ask, or 3 years after last use, whichever comes first. Never assumed: no answer means Ivan labels your talks by hand, which limits how many of the 25 can be ready |
| Fri 16 Oct (asked at the first meeting) | Serenity | Q-S11a | Is there a list of student names Prakriti can use to mute them? | A list kept only on the engine Mac; until yours arrives, a script on the Mac builds a seed list from the archive's own descriptions, only with your yes, deleted when yours arrives, and no Claude session reads it. Until you answer: an archive piece from a session where students were present cannot be approved |
| Fri 16 Oct (asked at the first meeting) | Serenity | Q-S30 | May a talk where only you or Gabriel speak be used even if students listened on the call, once names are muted from your list and Ivan has listened? | Yes, with your list. Until you answer: nothing from a session where students were present goes public |
| Fri 16 Oct (asked at the first meeting) | Serenity | Q-S13 | Sonny, the assistant writing your assessment, is Claude, by Anthropic. May Claude, Sonny included, read the teacher-only text of your talks, with names replaced, for titles, notes and the assessment? | Yes. If not, the assessment is built from counts on the Mac, and students' words are never shown to it either way. Until you answer: no Claude session, Sonny included, opens a transcript, title or description of your teaching or of any class; Sonny sees only counts and categories printed by a script on the Mac, and your archive items are sorted on the Mac from metadata only |
| Sun 18 Oct (yes to the suggestions) | Gabriel | Q-G5 | Record the Sunday talk weekly from Sun 18 Oct? | Yes, with your microphone on its own track. A Sunday talk where only you speak can become episode two. A Sunday call where students speak stays private under the student rule. No answer: the first episode does not wait for it. Phase 3 needs three sessions in a row |
| Fri 23 Oct (raised on the weekly call in the week of Mon 19 Oct) | Ivan | Q-I5 | What is Prakriti's price, agreed with Gabriel? | Name it before lane 2 switches on (D16), with the terms for the next stage agreed with Gabriel the same day. It stays in this file; no number on any page. Lane 1 is podcast audio plus archive talks on YouTube by metadata and visibility; lane 2 is studio video |
| Fri 23 Oct | Ivan (who pays: Ivan and Gabriel) | Q-I12 | A lawyer reads the class release and the voice permissions? | Yes, by Fri 23 Oct; who pays is for Ivan and Gabriel (suggested: Yoga Marga, as the data owner) and stays in this file; each teacher may have their voice consent read by their own lawyer (08 §7.4). Ask the lawyer to read the class note first (Q-GS8), and to read the release before any class stretch is considered (Q-S24). The lawyer-read voice permission arrives within four weeks of the lawyer starting. On the roadmap, for Gabriel and Serenity, the question reads without payment |
| Fri 23 Oct | Ivan | Q-I21 | Who can lift a pause or takedown? | Only the person who made it, or with their OK recorded in the log. Anything taken down over a student or privacy concern is cleared only by Serenity. A pause the system tripped is lifted by Ivan, with a passkey and a logged reason. Leaving "Taken down" also needs a fresh approval of a new manifest |
| Week of Mon 26 Oct | Account holder (Q-GS7) | Q-G21 | Will the account holder connect Prakriti to the channel once? (ID kept) | Yes, in one sitting with Ivan beside, in the week of Mon 26 Oct: change the password, turn on 2-Step Verification, set dubbing to "Publish manually", then click Prakriti's Google consent after seeing a screenshot of it. Prakriti's YouTube tests run in the same sitting, through the production project. Managers cannot. Prakriti's YouTube code has no delete call, and access can be withdrawn in the Google Account under third-party access |
| Fri 30 Oct | Ivan | Q-I8 | When do the daily archive summary and the weekly note go out? | Daily at 5:00 pm; weekly on Monday at 8:00 am; both in America/Los_Angeles time |
| Fri 30 Oct | Ivan | Q-I14 | ffmpeg mastering or Auphonic? | ffmpeg by default; compare by ear on the first three episodes; Auphonic only if the ffmpeg chain sounds uneven |
| Fri 30 Oct (asked privately in Ivan's message, not on the page) | Gabriel | Q-G11 | The drives held by a former contractor: ask for them back, or for written confirmation of destruction and a list of what was on them? | Ask this month; Prakriti tracks it as a red row until closed |
| Fri 30 Oct (asked privately in Ivan's message, not on the page) | Gabriel | Q-G15 | Are old Fathom class links still open to anyone with the link? | Limit them to enrolled students; switch off old public links |
| Fri 30 Oct (yes to the suggestions) | Gabriel | Q-G25 | Titles and hooks stay in your own words, no engagement bait? | Yes. No answer: the suggestion stands |
| Fri 30 Oct (yes to the suggestions; in the Fri 9 Oct message) | Gabriel | Q-G27 | Should a passage about your own life (family, health, grief, money) need your yes for that passage, whoever's piece it is? This is separate from Q-G8: Q-G8 settles the income claims and the offer in the Sun 6 Sep talk, and a passage it has settled is not held again here | Yes. Until you answer: such passages are held |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S1 | Should the public ever hear a student's voice? | No. Until you answer: the most private setting applies |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S2 | Should students' names said while teaching be muted in anything public? | Yes, always. Until you answer: the most private setting applies |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S3 | Should a student's story retold by a teacher be cut? | Cut it, and send you anything borderline. Until you answer: the most private setting applies |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S6 | Do you approve every piece in your voice? | Yes, every piece in your voice, for now; if you hand some over you name the person and the kind of piece, and can take it back. Until you answer: every piece in your voice waits for you |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S29 | May your own archive talks go out as podcast episodes, and on the school's YouTube channel, each with your yes? Or would you rather they become fresh recordings? | Podcast yes, piece by piece; YouTube once you have approved your first five. Until you answer: none of your teaching is published |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S24 | May a stretch where only you or Gabriel speak, cut from an archive class, with no student heard, named, described or answered, become an episode after the privacy check and your receipt? Full classes stay private | Not yet. Only after the class samples pass with not one second of a student labeled as a teacher, and a lawyer has read the release; then with your receipt on each. Until you answer: class stretches stay private |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S25 | Should a passage about your own life (family, health, grief, money) need your yes for that passage, whoever's piece it is? | Yes. Until you answer: such passages are held |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S26 | When a piece names you, how long should it wait for you to look? (Replaces Q-S19) | 48 hours; if you have not looked by then, the passage that names you is cut and the piece goes ahead. For episode 1 the two versions replace the cut. Until you answer: 48 hours |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S27 | If you have pieces waiting, would two 20-minute sessions a week, Tuesday and Thursday, work? | Yes, starting from your first waiting piece. Until you answer: nothing is put on your calendar, and your pieces wait for you |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S7 | Is a 5 to 10 item accuracy checklist per piece, plus "Recorded in" with the month and year, enough? | Yes. Until you answer: no older recording of yours is published |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S9 | Real video frames of you for thumbnails? | Yes. AI-made images of you never happen (the AI rule). Until you answer: no frames of you; type-only thumbnails |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S10 | Have any minors been in a class? | Anything with a minor stays private; enrollment asks for age from now on. Until you answer: every class stays private |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S15 | Do guest teachers have any agreement about recordings, and who asks them? | Their recordings stay private until you ask them. Until you answer: they stay private |
| Fri 30 Oct (asked at the second meeting, Tue 27 Oct) | Serenity | Q-S18 | How do you want to check a piece: listening on your phone to the few teacher moments Prakriti is least sure about (audio already headed public, which Ivan has already listened to), the written list of what was removed, or both? | Both. Until you answer: both; removed student audio never leaves the Mac |
| Fri 30 Oct; the address by Fri 16 Oct, for episode 1's notes | Gabriel, Serenity | Q-GS1 | If a student asks to be removed, who decides, and how fast? And which address takes removal requests? | Any of the three takes it down at once; talk after. Lifting it follows Q-I21. Every episode's show notes and every YouTube description carry one line, "Questions or a removal request: <address>". The address is yours to choose (OPEN; suggested: the school's contact address) and is never invented; the takedown clock starts when a message arrives there. Until you choose: no address line is printed, never a guessed one |
| Fri 30 Oct | Gabriel, Serenity | Q-GS8 | A short spoken note at the start of each recorded class? | Yes, once a lawyer has read it |
| Fri 30 Oct | Gabriel, Serenity | Q-I16 | Who is the responsible party on paper for the data? (ID kept from the earlier list) | Yoga Marga School owns the data, except each teacher's own voice data, which is theirs; Ivan processes it for the school, as in Ivan's one-page draft (drafted by Fri 16 Oct) |
| Fri 6 Nov | Ivan and Gabriel (D2) | Q-I1 (always-on) | Which always-on Mac runs the engine before the 72-hour target starts? | A Mac mini at the studio beside the RAID, or the studio Mac if it qualifies (Q-G22); decide who pays together |
| Fri 6 Nov | Gabriel | Q-G14 | Where are students and listeners: which states and countries? | Needed to know which privacy laws apply |
| Fri 6 Nov, before the first YouTube approval (yes to the suggestions) | Gabriel | Q-G24 | Real frames of you for thumbnails? | Yes. Until you answer: type-only thumbnails. Podcast approvals carry no thumbnails, so nothing waits on this before Fri 6 Nov |
| Fri 6 Nov | Gabriel, Serenity | Q-GS3 | If the engagement ends, who owns the content, the library and the voice data? | Yoga Marga owns the recordings and the published pieces. Each teacher owns their own voice recordings, voice reference and Library of their own words, can withdraw them at any time, and takes them with them; Yoga Marga uses them only while that teacher's consent stands. One export hands over everything else |
| Fri 6 Nov | Gabriel, Serenity | Q-GS5 | Where does the RAID live, and who can reach it? | One place, beside the always-on Mac; decided with Q-I1, built on the RAID build day before Mon 9 Nov |
| Mon 9 Nov | Ivan | Q-I9 | Is the browser's own video scrubber acceptable under "never skeuomorphic"? | Yes: it is a working control, not a drawing of a machine. Decorative waveforms and film strips stay banned |
| Mon 30 Nov | Ivan | Q-I7 | Will "publish unless stopped" ever exist? | Ivan decides, not before Mon 30 Nov and only after 20 clean approvals in a lane. It applies to a teacher's pieces only with that teacher's own yes for that lane, and never to anything with other voices |
| Mon 30 Nov | Ivan | Q-I15 | Where does the second copy of the masters live once they leave iCloud? | Keep the iCloud copy until the RAID and one external copy both exist |
| Mon 30 Nov | Gabriel | Q-G13 | Does Yoga Marga's GoHighLevel plan include the Social Planner with YouTube connected and approvals? | Check before Phase 5 |
| Mon 30 Nov | Gabriel | Q-G16 | Would you make your own AI voice in your own ElevenLabs account later? | Your choice in Phase 4; Ivan cannot do it for you |
| Mon 30 Nov | Gabriel | Q-G17 | VeraSales content through the same engine? | VeraSales sessions get a private package now; publishing waits for its own lane in Phase 5 |
| Mon 30 Nov | Gabriel | Q-G28 | May your own words go into the Library, which answers only with your words and the moment you said them? | Your choice in Phase 4. Until you answer: nothing of yours enters the Library |
| Mon 30 Nov (yes to the suggestions) | Gabriel | Q-G29 | Should Prakriti do anything on Instagram before Phase 5? | Instagram waits for Phase 5 and nothing is asked of you there; if you want to share yourself, the review screen gives you the file and caption. No answer: the suggestion stands |
| Mon 30 Nov | Serenity | Q-S8 | Would you ever want an AI version of your voice? | Nothing for now; if later, you make it yourself in your own ElevenLabs account. Until you answer: no AI version of your voice |
| Mon 30 Nov | Serenity | Q-S11b | What did students agree to about recordings, and can you send the current enrollment form? | A new form with a box per use, in English and Spanish, read by a lawyer first. Until you answer: every class stays private |
| Mon 30 Nov | Serenity | Q-S12 | How long are raw class recordings with students kept? | While useful to enrolled students, reviewed once a year. For any recording with an Other voice, Prakriti keeps only teacher-window text and the redaction plan, and keeps Other voice only as timecodes, never words. Until you answer: that text rule applies |
| Mon 30 Nov | Serenity | Q-S14 | Are "YTT V1, V2, V3" in Skool the three syllabi? | Send the syllabi when ready; they unlock the coverage map. Until you answer: nothing waits on them |
| Mon 30 Nov | Serenity | Q-S20 | Does Yoga Marga hold Yoga Alliance continuing-education status? | Decide with the self-paced YTT, not now. Until you answer: no courses are made from the archive |
| Mon 30 Nov | Serenity | Q-S21 | Spanish captions and notes of your teaching? | Only with your yes, checked by a Spanish reader. Until you answer: none of your teaching is in Spanish |
| Mon 30 Nov | Gabriel, Serenity | Q-GS2 | Do forms, disclaimers and replies need Spanish? | Yes |
| Mon 30 Nov | Gabriel, Serenity | Q-GS4 | Should enrolled students get a private feed of full classes later? | Yes, in Phase 4, with one feed link per student that can be switched off, only under the new class release; or keep full classes in Skool behind its login |
| Before any class is considered, in Phase 3 | Serenity | Q-S4 | Does your rule cover Gabriel's classes and the Sunday calls? | Yes, one rule for every class and call. Until you answer: the most private setting applies |
| When you are ready | Serenity | Q-S5 | May Prakriti learn your voice from a 2 to 3 minute clip, kept only on the Mac that runs Prakriti? | Yes, in writing, when you are ready; a written yes from your own email counts until the "Your consents" screen exists. A plain-language permission now; a lawyer-read version replaces it within four weeks of the lawyer starting, and you may have it read by your own lawyer. Proposed retention: deleted when you ask, or 3 years after last use, whichever comes first. Another route: for a recording where you teach alone, approve it by listening at the moments Prakriti queues. Until you answer, or if not: Prakriti cannot recognize your voice, so each recording of yours is checked by listening, or stays private |
| When you are ready | Serenity | Q-S22 | Would you record in the studio again, such as Mondays at 1 pm? | Your call; separate tracks make your studio teaching the cleanest route to publishing. Until you answer: nothing is booked for you |
| When you are ready | Serenity | Q-S28 | May your own words go into the Library, which answers only with your words and the moment you said them? | Your choice, when you are ready. The Library of your words is yours: you can withdraw it at any time and take it with you. Until you answer: nothing of yours enters the Library |
| Asked at the first meeting, no deadline | Serenity | Q-S16 | May Prakriti touch the "Private Meetings" playlist and the untitled "Recording Testing" uploads? | Private meetings never; the untitled ones sorted on the Mac first, from their sound and length. Until you answer: the private meetings are never opened, and the Recording Testing items are listed from metadata only and never opened |
| Asked at the first meeting, no deadline | Serenity | Q-S23 | The private-call copies already on Ivan's Mac (inside the partial download), and any in the new export: what happens to them? | They are moved, unopened, to the encrypted archive drive the day it attaches, and deleted only with your yes once the fresh export exists, with a record kept. Deleting is irreversible and yours to decide. Until you answer: they stay where they are, never opened |

Changes in round 1: Q-G12 (background music in older classes) was dropped, because Prakriti checks
every file anyway. Q-S17 (surname spelling and invitation email) was removed from every page; Ivan
confirms both privately by text before the invitations go out, including which Google account her
invitation must match.

Changes in round 2: Q-G3 merged into Q-G2, and Q-G10a into Q-G23. Q-S19 is replaced by Q-S26. New:
Q-G26, Q-G27, Q-S24 to Q-S27, Q-I20 to Q-I22. Q-S4 to Phase 3.

Changes in round 3: new Q-G28 and Q-S28 (the Library), Q-G29 (Instagram), Q-S29 (Serenity's own talks
published), Q-S30 (students who only listened). Q-S11a and Q-S13 move to Fri 16 Oct, at Serenity's
first meeting; the rest of her set is asked at the second meeting, Tue 27 Oct. Q-GS7 is asked of
Serenity only, as a confirmation. Q-G1 and Q-G19 are due Mon 12 Oct or at the studio visit; Q-G26 and
Q-G7 the day before the visit; Q-G24 Fri 6 Nov. The account holder's sitting moves to the week of Mon
26 Oct. Q-S24's suggestion is now "Not yet", because round 2's yes would have made the front page's
promise false (S5). Q-GS1 carries the removal address, Q-GS3 a new ownership suggestion, and Q-I12 the
lawyer question without payment on the page. **Who pays for the lawyer stays in this file and is OPEN
for Ivan and Gabriel** (Q-I12; D16).

---

## Decisions already made

The full text, with reasons, is in [research/DECISIONS.md](research/DECISIONS.md). In one line each:

| ID | Decision |
|---|---|
| D1 | Hybrid: a small native engine on one Mac does the heavy work; a web app at `prakriti.therowan.studio` is the shared room where all three review, approve and get notified; Claude does the editorial thinking |
| D2 | v1 runs on Ivan's MacBook Pro. Which always-on Mac comes next is OPEN (Q-I1), for Ivan and Gabriel |
| D3 | Everything up to "ready for your yes" runs on its own. Publishing waits for one human yes per piece |
| D4 | One notification per recording, updated in place; Needs a Decision and Couldn't Finish as exceptions; archive work summarized once a day; tests silent |
| D5 | Privacy by construction: unknown voice is a student, teacher-only enrollment, name scrubber, privacy receipt, consent registry, music check, kill switch, audit log |
| D6 | Accuracy checklist per piece, stale-truth check for the archive, "Recorded in" label, Yoga Marga lexicon |
| D7 | The unit is a session, not a file; twins pair; tests file themselves; each session goes to a venture |
| D8 | Quality is plain verdicts with reasons, never a number |
| D9 | Podcast audio is the first lane, mastered to -16 LUFS. Hosting is OPEN (Q-G2, Q-G26); a real recorded intro is recommended |
| D10 | YouTube: the channel owner connects once; archive talks already on YouTube are published by changing metadata and visibility; three thumbnails prepared, Test & Compare by hand |
| D11 | The archive is re-exported by the owner, deduped, classified, quarantined where private, transcribed locally, triaged, scored and shortlisted |
| D12 | Later lanes switch on one at a time, each gated: video, shorts, library, voice datasets, Spanish, the business loop |
| D13 | Autonomy you can trust: heartbeat, nightly sweeper, run log, cost cap, retries for passing failures only, coverage checks |
| D14 | Invite-only sign-in, Google plus passkeys; no sign-up; v1 has no app behind the sign-in and says so |
| D15 | The front door is the features page and the sign-in page in one; `/roadmap` is the plain roadmap; both unlisted in search |
| D16 | Prakriti is priced before the second lane; the fee never appears on the public site |

Decided by the people who own them, before Thu 8 Oct: Growati is closed and Prakriti replaces its
outputs; Zoom API work is dropped and OBS records natively; silent recordings go to a b-roll
folder (Gabriel, Wed 7 Oct); the engine is called Prakriti (Ivan, Thu 8 Oct).

### Spine corrections pending

DECISIONS.md is not edited by the feedback rounds. These corrections match `docs/FEEDBACK.md` and
wait for Ivan, who accepts or rejects each and publishes DECISIONS v2 by Mon 12 Oct (row 22). They no
longer hold up the Fri 9 Oct messages, which quote no spine text.

**From round 1:**

- **D11:** the archive Takeout is about 388 GB (the Takeout's own part sizes, 01 l.55), not "1 to 2.7
  TB" (an unverified bitrate estimate, 06 l.95). The drive choice no longer blocks the salvage.
- **D9:** "the existing RedCircle show can redirect to it" is unverified (06 §3.1 shows only an
  inbound import). A self-hosted feed needs its domain's DNS zone and the storage bucket in one
  Cloudflare account, which should be one Yoga Marga owns. The "-21 to -36 LUFS" range was measured
  on stereo or one channel and needs re-measuring on a mono downmix.
- **D3:** "publish unless vetoed" (now "publish unless stopped") also needs each teacher's own yes
  for their pieces, per lane.
- **D16:** the lanes are defined once: lane 1 is podcast audio (studio and archive) plus archive
  talks on YouTube by metadata and visibility; lane 2 is studio video. The price is agreed by
  Fri 23 Oct.
- **D5:** the promise is the check, not perfection; speaker verification moves from clusters to
  short windows.
- **D4 and D1:** Web Push for Gabriel and Serenity follows email (round 2 moves it after Fri 6 Nov);
  Claude calls are proposed to run in the Worker; the engine is one nested app identity.

**Added in round 2:**

- **D9:** one publisher. Ivan's Worker renders `feed.xml` at each release slot and writes it into
  Yoga Marga's bucket with a bucket-scoped token; the feed Worker in Yoga Marga's account reads only
  its own bucket. `itunes:new-feed-url` belongs in the old feed. The podcast gets its own domain,
  held as its own zone. The trailer is dropped.
- **D11:** the archive needs an external drive of about 2 TB (cost to price, OPEN for Ivan) or
  part-by-part extraction; the re-run is never extracted into a watched folder before inventory;
  students' words in class transcripts are kept only as timecodes.
- **D10:** the YouTube Cloud project lives inside the school's Google Workspace if there is one
  (Internal, no verification); Prakriti's YouTube code has no delete call.
- **D1:** every cloud call runs after redaction (the lexicon stage is local); Claude's results reach
  the engine through an editorial endpoint it polls.
- **D14:** a returning person signs in with a passkey in one step; Google is for the first binding to
  the invitation and for recovery.

### Spine corrections pending (round 3)

Copied from `docs/FEEDBACK.md`, Round 3. They join rounds 1 and 2, and no longer hold up the Fri 9 Oct
messages (C12): DECISIONS v2 follows by Mon 12 Oct, before the first build session.

- **D5:** the receipt cannot be approved "in under a minute" while it carries the queued listen. Ivan
  is the listener for archive pieces, and the time is measured, then budgeted (S1, C4).
- **D5 and D3:** "teacher-only" is defined once (no other voice heard, no student named, described or
  answered); sessions where students were present stay private until Serenity's Q-S30 (C2, S3).
- **D10 and Phase 2:** archive talks on YouTube follow after Fri 6 Nov; the 25 are podcast episodes
  on the feed (G5, C3, E1).
- **D1:** Sonny is Claude. Until Serenity says yes to Q-S13, no Claude session, Sonny included, reads
  a transcript, title or description of her teaching or of any class; Sonny sees counts and categories
  printed by a script on the Mac (S2).
- **D9:** the podcast's Cloudflare account is a new one on a Yoga Marga address, separate from
  VeraSales (E14, C7).
- **D4:** email is the only notice channel until after Fri 6 Nov, with its own copy rules and never
  an approve link; Approved never alerts; a release of several pieces sends one notice (H3, H4).
- **D13:** the quiet-engine email, a report-only sweep and backups land before archive approvals
  open, not after Fri 6 Nov (E9, C8).

---

## History

Kept apart from the current state above, so nobody acts on a world that no longer exists.

- **Session by session:** [CHANGELOG.md](CHANGELOG.md). **Feedback rounds:**
  [docs/FEEDBACK.md](docs/FEEDBACK.md).
- **The roadmap page sent to Gabriel on Wed 7 Oct** (`Gabriel Galindo/Roadmap/galindo-lizarde-roadmap.html`
  in Ivan's Projects folder) is the promise on the record. What this plan changes in it is listed
  below, each with its reason.
- **The July content-engine plan** (`Gabriel Galindo/content-engine/`) is history. Its "do not
  build", Fathom as the source, "about 6 uploads a day", unlisted by default and thumbnails as
  prompts are all superseded.
- **The 10-07 transcripts** beside the studio files match the output of Ivan's transcription app,
  Hark (07 §1.4); OBS does not write them. Prakriti ignores them, and they are being moved out of
  the shared folder (SET-10).

### Since the 7 Oct page

- **The first episode is a studio talk, then the archive.** Gabriel's Sun 6 Sep talk goes first,
  because it is already on the Mac and has one voice; Serenity hears its passages about her first.
  The first archive episode goes out the morning after its approval (Tue 27 or Wed 28 Oct).
- **There is no trailer.** Gabriel's recorded intro opens episode 1 instead, because a trailer had no
  way to approve it and would have gone out before anyone could stop it.
- **Gabriel's intro is recorded in his own voice instead of made with ElevenLabs,** so episodes need
  no AI label; Apple requires one for AI voices. An ElevenLabs version stays his option.
- **Ivan publishes every episode through Fri 6 Nov,** by hand for episode 1 and then with his release
  script; Prakriti's own release slots switch on after Fri 6 Nov. Gabriel never uploads, posts to the
  podcast or submits, because his goal is to get out of their own way, and every earlier fallback
  handed posting back to him.
- **The 25 are proposed podcast episodes, counted on the feed,** from teacher-only talks and their
  self-contained segments, and Ivan confirms the number with Gabriel on Fri 9 Oct with two counts.
  Serenity's pieces join when she says yes. Reason: student privacy and her consent.
- **The 25 are podcast episodes. YouTube follows after Fri 6 Nov,** at up to two a day, and is not
  counted, because each video must show and sound teachers only.
- **Gabriel no longer carries Serenity's answers.** Ivan asks her directly, at two meetings: the week
  of Mon 12 Oct, and Tue 27 Oct.
- **A weekly Yoga Marga call,** at a fixed day and time Ivan proposes on Fri 9 Oct, where each week's
  decisions and one approval session fold in.
- **The 72 hours count to "ready for your yes", and start on the always-on Mac.** Going live also
  needs a person's yes, and a laptop that travels cannot keep a clock.
- **Recordings are found in the shared folder; nothing raw is uploaded.** Anything recorded
  elsewhere goes into the same Studio Recordings folder, so the privacy promise holds by
  construction.
- **The owner connects YouTube once, instead of adding Ivan as a manager,** because managers cannot
  authorize apps (DECISIONS fact 5). Gabriel and Ivan are added as Managers too, for the Studio-only
  steps.
- **Each teacher makes their own AI voice in their own account,** because ElevenLabs allows only
  that.
- **The archive has no transcripts yet.** Only the studio sessions are transcribed.
