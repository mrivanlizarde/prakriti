# Prakriti: self-feedback log

On Thu 8 Oct 2026 Ivan asked for three rounds of self-feedback on the Prakriti scope and pages,
each one reasoned and then implemented. Every round puts the work in front of six critics, each
reading through one lens: **Gabriel** (does it fix his problem, "incapable of hitting post"),
**Serenity** (are her two conditions, student privacy and accuracy, really kept), **brand and copy**
(voice, consistency, identity), **Apple HIG and accessibility**, **engineer** (will it actually
work), and **COO completeness** (owners, dates, mechanisms, nothing dropped). A reasoner then decides
every finding: accept, accept with a modification, or reject, each with a one-line reason grounded
in `research/DECISIONS.md` (which wins), the research files, Ivan's standing rules or the evidence.
This file records every finding and that reasoning, so the rounds can be checked after the session
ends. What was actually changed is filled in by the implementers under "What changed".

Finding IDs: G = Gabriel, S = Serenity, B = brand and copy, H = HIG and accessibility,
E = engineer, C = COO completeness. Every weekday below was computed with `date(1)`.

---

## Round 1

Reviewed Thu 8 Oct 2026: `docs/SCOPE.md`, `PLAN.md`, `START_HERE.md`, `README.md`,
`web/public/index.html`, `web/public/roadmap.html`, `web/public/assets/*`, `web/src/index.js`.

### The six verdicts

- **Gabriel:** honest, well made and safe, but it reads as Serenity's safety spec rather than the
  cure for "incapable of hitting post"; it quietly moved his first lane off the archive and hands
  him about 50 asks.
- **Serenity:** she would mostly feel respected, but the front page repeats the voice-separation
  promise that already failed on Sun 20 Sep, her approval cannot catch that failure, and several
  things that need her yes are scheduled or decided without it.
- **Brand and copy:** the identity (Tiro, the ultramarine underdot, the yes line) is specific and
  right; the copy promises what the process will break, contradicts itself on dates and on the
  student and AI rules, and leans on "X, not Y" tics and the internal word "lane".
- **HIG and accessibility:** the pages pass the basics (live CSP clean, nothing under 12px, AA
  contrast, reduced motion); weak spots are the two-button sign-in card, the roadmap filter, faint
  button borders, and in SCOPE the Web Push tags, Phase 1 build order and an Approve with no undo.
- **Engineer:** thorough on intent and `index.js` is correct, but the fail-closed speaker rule can
  still fail open, readiness breaks under the OBS format being requested, the engine has no API or
  process identity, and the recommended feed cannot be built on R2 as written.
- **COO completeness:** every request and ledger item is mapped, but it is not run like an
  operation: the 25 rests on Serenity, an unnamed channel owner, one travelling laptop and Ivan's
  unbudgeted time, and the 72 hours, sign-in date, student rule and receipt approver each read
  differently across documents.

### Conflicts between critics, and how they were resolved

1. **Who approves (G6, S5, C4).** Each teacher approves their own pieces, or names someone who may.
   Gabriel is asked whether Ivan may also approve his solo talks (recommended yes). Serenity
   approves every piece in her voice for now, and the privacy receipt of anything with voices other
   than the teachers' (SCOPE §9.4, D5), not every receipt. Pieces that name her are shown to her
   until she says otherwise.
2. **One AI rule (G12, S9, B2).** "Prakriti never makes an AI voice or face of anyone. A teacher may
   make their own, in their own account. With that teacher's written yes, Prakriti prepares clean
   recordings for it and uses the result only for a script that teacher approved, always labelled
   as AI. Nothing of Serenity's without her written yes." This keeps the VeraSales avatar decision
   (E-08) possible, as Gabriel's own, and keeps Serenity's line.
3. **One student rule (B3, C14).** C14 said "neither is possible before Phase 5", which contradicts
   the Phase 3 class option. Resolved as two sentences: no student is heard, named or described
   unless Serenity's rule allows it and that student said yes in writing; a class goes public only
   with every student removed, after her rule, a lawyer-read new release the students agreed to,
   and her receipt approval.
4. **Serenity's deadlines (C1, B7, S4).** C1 and B7 wanted her critical questions answered by
   Fri 16 Oct in a meeting; S4 showed the biometric question must not carry Gabriel's deadline.
   Resolved: one meeting in the week of Mon 12 Oct; privacy answers needed by Fri 23 Oct, and until
   then the most private setting applies; the voice question has no date; the 25 is decoupled from
   her.
5. **Name list date (S14 Fri 23 Oct, E8 Fri 16 Oct).** Fri 23 Oct, before approvals open, with a
   seed list built only on the engine Mac if she agrees, so muting does not wait.
6. **Drag and drop (G14) vs no raw uploads (E13).** Other recordings go into the shared Studio
   Recordings folder (Finder on a Mac, Files on an iPhone), which the engine already watches. No raw
   file is uploaded to the cloud, so the front-door promise stays true by construction.
7. **Web Push timing (H2 vs E15, C9).** Web Push moves to Phase 1 order 2; the first notice reaches
   Gabriel by email. The manifest and Turn On Notifications ship together with Web Push, never after.
8. **Sign-in card (G21 vs B6, H6).** One date in the card ("week of Mon 19 Oct"), no dates inside
   buttons, one "Continue with Google" button with the passkey as step two.
9. **Notification section (H15 vs G23, B14).** Cut to one specimen (Ready for your yes) instead of
   renaming three; Web Push's missing passive level is stated in SCOPE.
10. **Publish unless stopped (B9 vs S6).** Ivan decides whether the setting ever exists (D3); it
    applies to a teacher's pieces only with that teacher's own yes for that lane; never to other
    voices.
11. **Show art (G22 Fri 16 Oct, C8 Wed 14 Oct).** Fri 16 Oct, which still lands before the trailer.
12. **Comments and auto-dubs check (S13 vs E17).** The Phase 1 YouTube test runs on Ivan's own
    channel, so the comment and dub check is verified read-only on the first real archive video
    after the owner's consent.

### Spine corrections pending (DECISIONS.md is not edited in this round; for Ivan)

- **D11:** the archive Takeout is about 388 GB (the Takeout's own part sizes, 01 l.55), not
  "1 to 2.7 TB" (an unverified bitrate estimate, 06 l.95). The drive choice no longer blocks salvage.
- **D9:** "the existing RedCircle show can redirect to it" is unverified (06 §3.1 shows only an
  inbound import). A self-hosted feed on Yoga Marga's domain needs that domain's zone and the bucket
  in one Cloudflare account, which should be one Yoga Marga owns. The "-21 to -36 LUFS" range was
  measured on stereo or one channel and needs re-measuring on a mono downmix.
- **D3:** "publish unless vetoed" also needs each teacher's own yes for their pieces, per lane.
- **D16:** define the lanes once: lane 1 is podcast audio (studio and archive) plus archive talks
  on YouTube by metadata and visibility; lane 2 is studio video. Price agreed by Fri 23 Oct.
- **D5:** the promise is the check, not perfection; speaker verification moves from clusters to
  short windows (E1).
- **D4 and D1:** Web Push for Gabriel and Serenity lands in Phase 1 order 2 (email first); Claude
  calls are proposed to run in the Worker; the engine is one nested app identity.

### Every finding

| ID | Lens | Severity | Finding | Decision | Reason |
|---|---|---|---|---|---|
| G1 | Gabriel | blocker | First lane quietly moved from archive episodes (his 7 Oct ask, C-01, C-10) to studio talks | Accept-modified | Keep a studio talk first: it is on the Mac, one voice, needs no Takeout or owner consent (DECISIONS Phase 1). But say so with the reason, and the front page says "first from a studio talk, then from the archive" |
| G2 | Gabriel | blocker | About 50 asks of Gabriel; 12 answers and 4 tasks by Fri 16 Oct; his problem is being the bottleneck | Accept-modified | G-02 is the north star. Next two weeks cut to single digits; operational questions say "No answer by date: the suggestion stands"; consent, privacy and money questions never default; setup moves to one Ivan studio visit (OPEN for Ivan). Single digits overall is not realistic across six phases |
| G3 | Gabriel | major | New pages contradict the 7 Oct page in five places with no "what changed" | Accept | The 7 Oct page is the promise on the record (PLAN History). Add "Since the 7 Oct page" with one line and reason per change |
| G4 | Gabriel | major | Gabriel believes the archive is transcribed (Ivan's "Correct.", A-03) | Accept-modified | Add the sentence to the archive row. The 7 Oct page itself said "There are no transcripts of these yet", so the record is half corrected on paper; Ivan's Fri 9 Oct note still closes A-03 |
| G5 | Gabriel | major | First episode depends on a new talk by Sun 18 Oct while input has stopped | Accept | DECISIONS fact 2 and the 01 §13 "input stopped" trap. The Sun 6 Sep talk is the default; its income decision moves to Fri 16 Oct; a new talk is episode two. The 09-13 talk is addressed to a named student, so 09-06 is the clean pick |
| G6 | Gabriel | major | Gabriel is never offered letting Ivan approve his solo talks | Accept-modified | D3 needs a human yes, not necessarily the teacher's. OPEN for Gabriel, Fri 23 Oct, recommended "you or Ivan" for his solo talks only; Serenity's pieces and anything with other voices stay with her |
| G7 | Gabriel | major | RedCircle redirect stated as fact; unverified | Accept | 06 §3.1 shows only an inbound import; D9's wording needs a flag. Ivan checks RedCircle's help pages by Mon 12 Oct; until then the wording is conditional |
| G8 | Gabriel | major | Sample shows the 09-06 Message as Ready to post though the talk has an income claim | Accept-modified | Message becomes "Worth a look: one income claim to decide". No quote of the claim on the page: the DECISIONS design direction bans earnings claims there |
| G9 | Gabriel | major | Thumbnails shown as type-only "title cards"; the product uses real frames | Accept | SCOPE PKG-06 uses real frames; "no photographs" is a rule for this page, not the product. Rename, caption, and Gabriel's frames question joins his consent form (Fri 23 Oct, not this week) |
| G10 | Gabriel | major | Teleprompter and polished re-record missing; a Never item reads as ruling it out | Accept-modified | B-02, B-03 and the stopped studio. Narrow the Never item to the Library; offer a weekly script from his own best moments as a Phase 3 option for his own material, behind the money gate, not forced into scope |
| G11 | Gabriel | major | Front page never speaks to his goal; approval language repeats about 25 times | Accept-modified | Add a short status under the hero in plan and goal words, not promises (B10). Remove duplicate approval lines in hero and FAQ, but keep each rule once, because Serenity's trust rests on them (S5) |
| G12 | Gabriel | major | FAQ "No" to AI contradicts Phase 5, the 7 Oct page and the VeraSales avatar | Accept-modified | One AI rule everywhere (conflict 2) |
| G13 | Gabriel | major | Phase 3 dates hide the money gate | Accept | Merged with C13. One neutral line with no number (D15, D16); Q-I5 moves to Fri 23 Oct |
| G14 | Gabriel | major | "Nobody uploads" drops the drag-and-drop he called brilliant | Accept-modified | Conflict 6: other recordings go into the shared folder; no raw file goes to the cloud (E13, PR-12) |
| G15 | Gabriel | major | His audio-only yin idea appears only as Serenity's call | Accept-modified | Add a line for him: multitrack from now; a yin class still has students in the room, so the new release and Serenity's rule apply (fact 4); earliest Phase 3 |
| G16 | Gabriel | major | Shorts have no destination and no one to post until 2027 | Accept-modified | Shorts go to YouTube Shorts after a yes in Phase 3; the review screen hands Gabriel the file and caption to post to Instagram himself until GoHighLevel. Not automated posting, so Phase 5 stands |
| G17 | Gabriel | major | Never list settles content direction (hooks, attention) | Accept-modified | Content direction is Gabriel's (01 §7). Keep integrity nevers only; hooks become his question, Fri 23 Oct, recommended "titles and hooks in your own words, no engagement bait" |
| G18 | Gabriel | minor | Voice consent question bundles two asks, uses jargon, threatening fallback | Accept | Split it; plain words; fallback "Ivan labels your talks by hand", a human check on a solo talk that keeps D5 |
| G19 | Gabriel | minor | Intro, outro and mid-roll due the same day as the call to action, with no script | Accept | Sonny drafts three scripts of about 30 words by Mon 12 Oct with the suggested ask; one ten-minute sitting; a spoken per-episode intro is a later option |
| G20 | Gabriel | minor | Takeout routed through Gabriel to an unnamed owner | Accept | Merged with C2: name the account on the page without its address; ask both directly |
| G21 | Gabriel | minor | Sign-in dates disagree between pages | Accept-modified | Conflict 8: "week of Mon 19 Oct", invitations Tue 20 Oct; the part of the fix that puts a date in the buttons is rejected |
| G22 | Gabriel | minor | Show art due the day the feed is submitted | Accept | Show art and description Fri 16 Oct; Apple needs the art (06 §3.3) |
| G23 | Gabriel | minor | Notification section is spec-level and long | Accept | Merged with B14 and H15: one specimen; setup steps move to the invitation email and the welcome screen |
| G24 | Gabriel | minor | VeraSales recordings in limbo until 2027 | Accept-modified | D7 routes from day one. VeraSales sessions get a private package, never published; Q-G17's suggestion updated; its date stays Mon 30 Nov to keep this week light |
| G25 | Gabriel | minor | "Even five good minutes become an episode" is invisible | Accept | PIP-34 is already Phase 2; one line |
| S1 | Serenity | blocker | Front page promises a voice separation that failed on Sun 20 Sep, more confidently than on 24 Sep | Accept | DECISIONS fact 3. Promise the check, not perfection; the honest one-microphone sentence; "a person checks" on the removal line; the For Serenity intro names the failed 24 Sep answer and what replaces it |
| S2 | Serenity | blocker | The receipt lists removals only, so her yes cannot catch what was wrongly kept | Accept-modified | Add a "Listen here" row (3 to 8 queued teacher-labelled moments), the "labels can be wrong" line, and the extra listen for her archive pieces until her own sample passes. Q-S18's suggestion changes accordingly |
| S3 | Serenity | major | Sample marks Message and Video Ready though the talk holds what the rules send to a person | Accept-modified | Merged with G8, C19. Video becomes "Worth a look: handwritten figures on the overhead camera near 50 minutes" (08 §1.2); accuracy adds "Mentions Serenity: shown to her first". No quote of the claim and no detail of her earnings (DECISIONS design direction) |
| S4 | Serenity | major | Gabriel's 25 openly depends on her biometric consent within a week | Accept-modified | Conflict 4. The 25 is Gabriel's number from teacher-only talks; her pieces count only if and when she says yes; the voice question has no date; Sonny counts Gabriel-only candidates before the Fri 9 Oct send; if short, Ivan resets the number with Gabriel |
| S5 | Serenity | major | Suggested answer takes her out of approving most of her own teaching | Accept-modified | PR-17 and F-04. Q-S6 suggestion: every piece in her voice, for now. Receipt approval stays limited to pieces with other voices (C4, D5) |
| S6 | Serenity | major | "Publish unless stopped" is Ivan's call and could cover her pieces | Accept-modified | Conflict 10. Spine D3 refinement |
| S7 | Serenity | major | No meeting scheduled; answers due before the assessment; no sign-in step for her | Accept | A-12 and fact 14. Meeting in the week of Mon 12 Oct; fuller assessment target Thu 22 Oct, latest Mon 26 Oct; she accepts her invitation by Fri 23 Oct |
| S8 | Serenity | major | Claude reading her teaching stated as settled; ARC-06 sends every archive transcript to the cloud | Accept | Q-S13 is hers. Front page splits by teacher; an "If not" line; cloud triage only for items classified as talks from metadata |
| S9 | Serenity | major | AI voice and avatar contradictions across pages | Accept | Merged into conflict 2 |
| S10 | Serenity | major | Biometric consent asked before the lawyer's read; no retention stated | Accept-modified | Label it a plain-language permission that a lawyer-read version replaces by Mon 30 Nov; state the proposed retention (SCOPE §7.8). The lawyer is a cost with no budget owner yet (D16), flagged to Ivan |
| S11 | Serenity | major | "Never transcribed, never sent to AI" for private calls is not built into the pipeline | Accept | Exclude at inventory before any audio step; not copied in the salvage; a call found later stops there. Ask Serenity about deleting the copies on Ivan's Mac: deletion is irreversible and hers, so it is asked, never done |
| S12 | Serenity | major | "Never delete an original" contradicts removal rights and retention | Accept | 08 §3.3 and PR-16: never deleted automatically, deleted only by a person's decision with a record |
| S13 | Serenity | major | Before a flip, comments and YouTube auto-dubs are not checked | Accept-modified | Add both checks; conflict 12 for where it is verified; auto-dub setting dated Fri 23 Oct |
| S14 | Serenity | major | Name list due Mon 30 Nov while muting is a hard gate from Phase 1 | Accept | Merged with E8; conflict 5 |
| S15 | Serenity | major | Transcripts with students' stories still in the shared iCloud folder; not on the roadmap | Accept | Already PLAN #8; add a neutral Ivan row, Fri 9 Oct |
| S16 | Serenity | major | Spanish of her teaching switched on without her yes | Accept | SCOPE §11.2 makes translation its own consent use; also an accuracy risk for Sanskrit terms |
| S17 | Serenity | minor | Page says she set a rule she has not set | Accept | 01 F-01 records two open variants |
| S18 | Serenity | minor | Page re-asks her email and surname where Gabriel reads it | Accept | Merged with B7, E17: off the page; Ivan confirms privately before Tue 20 Oct, including which Google account her invitation must match (SCOPE §9.5) |
| S19 | Serenity | minor | "See Gabriel's talks that mention you" due after the first episode | Accept-modified | Asked at the meeting; until she answers she sees any piece that names her, the 09-06 talk included, before Gabriel's yes |
| S20 | Serenity | minor | Data-owner note filed as Ivan's and dated late | Accept-modified | Moves to For you both; Ivan drafts by Fri 16 Oct; agreed by Fri 23 Oct rather than Fri 16 Oct to keep this week light |
| S21 | Serenity | minor | Classes still recorded under the old "private community" framing | Accept-modified | Ask it, Fri 23 Oct. The suggestion "use it pending the lawyer" is rejected: 08 §7 says the drafts are not for use as is. Suggested answer: yes, once a lawyer has read the note, and Ivan asks for that read first |
| S22 | Serenity | minor | Features her conditions rest on are only Proposed in SCOPE | Accept | PRV-04, PRV-09, PRV-10 and PRV-16 carry D5; mark them Decided (D5) |
| S23 | Serenity | minor | Never card overstates where full recordings live | Accept | Merged with B11 |
| B1 | Brand | blocker | Privacy copy promises perfection ("never guesses", names always muted) | Accept | Merged with S1; README too |
| B2 | Brand | blocker | AI likeness rule contradicts itself across pages | Accept | Conflict 2 |
| B3 | Brand | major | The student rule is stated three different ways | Accept-modified | Conflict 3 |
| B4 | Brand | major | Unbuilt product described in the present tense; hero overgeneralises who approves | Accept | Add a status line; "nothing is posted until the teacher in it says yes"; FAQ in the future tense |
| B5 | Brand | major | "The only input" is broken by the roadmap's setup steps | Accept | Honest version: one-time setup, then a 10-second sound check per session |
| B6 | Brand | major | Sign-in date contradicts the roadmap and the same page | Accept | Conflict 8 |
| B7 | Brand | major | Serenity gets 9 questions in 8 days before the assessment she asked for | Accept | Merged with C1; conflict 4 |
| B8 | Brand | major | Serenity is framed as the thing everything waits on | Accept | Merged with S4; "each teacher's stay locked until that teacher says yes" |
| B9 | Brand | major | "Always waits" headline next to a planned exception | Accept-modified | Drop "always"; the note uses conflict 10's wording |
| B10 | Brand | major | 72 hours worded as a promise while D2 is OPEN | Accept | Merged with C3: a proposed target, one definition |
| B11 | Brand | major | Never list claims full recordings stay on the Mac; they sync through iCloud | Accept | Narrow to what Prakriti controls: it adds no new copy online and uploads no raw recording |
| B12 | Brand | major | "X, not Y" tics, colon reveal, aphorism, invented crowd | Accept | Ivan's voice rules (describe, never sell) |
| B13 | Brand | major | "Lane" is internal vocabulary nobody used on the call | Accept | Off the public pages; PLAN and SCOPE keep it |
| B14 | Brand | major | Front page too long for a one-visit job (D15) | Accept | One specimen, file tree to one line, setup steps after sign-in |
| B15 | Brand | major | Two names and two marks (Prakriti vs prakṛti; bar-and-dot favicon) | Accept-modified | Lowercase "prakṛti" with the blue underdot in nav and footer, a screen-reader "Prakriti"; favicon is the dot alone; "Prakriti" stays in prose and titles |
| B16 | Brand | minor | Loudest nav button is the one nobody can use for two weeks | Accept | Roadmap filled, Sign In plain, swapped back the day invitations go out |
| B17 | Brand | minor | Sample episode uses Prakriti's mark as the show's art | Accept | The show is Yoga Marga's; a typographic placeholder with "show art to come" |
| B18 | Brand | minor | Dark mode accent drifts to lavender; card A vanishes | Accept-modified | Split the token; the implementer computes ratios (3:1 for marks, AA for text) before choosing values |
| B19 | Brand | minor | Hero quote is "not X, it's Y" with no referent | Accept | "The second pattern is that people confuse cost with value." is confirmed in the 09-06 transcript; its timecode is measured from the file or left off, never invented, and 00:26:10 is not reused |
| B20 | Brand | minor | "Score out of 100" sits in the solemn Never list | Accept | D8 is a design decision, not a never |
| B21 | Brand | minor | Engineer phrasing teachers will not parse | Accept | Plain words |
| B22 | Brand | minor | Gabriel given technical setup and homework | Accept | Merged with G2: one Ivan studio visit (OPEN for Ivan) |
| B23 | Brand | minor | Roadmap H1 is a table of contents | Accept-modified | "Podcast first. The first episode is planned for Friday 23 October." A plan, not a promise |
| B24 | Brand | minor | Labels drift (Waiting, With consent, Recorded in, Phase 5 "Later" twice) | Accept-modified | One label set. Phase names stay identical across documents; the status tags change to Now, Next, Planned instead of renaming Phase 5 |
| H1 | HIG | major | Web Push tag is per session, so a later push silently replaces an earlier one | Accept | Mirror the native identifiers (D4); renotify where Safari honours it; a three-push render check |
| H2 | HIG | major | Web Push scheduled before the manifest and the permission button it needs | Accept-modified | Conflict 7 |
| H3 | HIG | major | Approve publishes immediately, unnamed, with undo scheduled later | Accept-modified | Name the destination; approval schedules into the next release slot with Undo until then; Publish Now gets a sheet. The release-slot undo is order 1; the rest of APP-08 stays order 2 |
| H4 | HIG | major | Review screen specified for desktop only; the test is on an iPhone | Accept | Add the phone order with the named Approve in thumb reach; Podcast tab only in Phase 1 |
| H5 | HIG | major | No process owns native notifications or their permission timing | Accept | Merged with E4 |
| H6 | HIG | major | Sign-in card shows two parallel buttons for a two-step flow | Accept | One "Continue with Google", passkey as step two, aria-disabled |
| H7 | HIG | major | Three status vocabularies in SCOPE | Accept | D4's words become the states |
| H8 | HIG | major | SCOPE notification defaults contradict D4 | Accept | D4 wins; the impact note is opt in; "publishing paused" is OPEN for Ivan |
| H9 | HIG | major | Filter segments 38px; selected state near invisible | Accept | 44px and an ink fill (WCAG 1.4.11) |
| H10 | HIG | minor | Quiet button borders 1.76:1 | Accept | A 3:1 border token |
| H11 | HIG | minor | Small grey text below the 7:1 goal; no increased-contrast variant | Accept | 03 A19 and SCOPE's own 7:1 goal |
| H12 | HIG | minor | Sample package headings nest under the sign-in card | Accept | pk-title becomes an h2 |
| H13 | HIG | minor | Roadmap contents clips the focus ring | Accept | Small CSS fix and a re-capture |
| H14 | HIG | minor | Safari drops list semantics; step numbers hidden | Accept | role="list"; spoken step numbers |
| H15 | HIG | minor | Specimens show moments they will not receive; level names unclear | Accept-modified | Conflict 9 |
| H16 | HIG | minor | Web app has no navigation model | Accept | Add §9.0 |
| H17 | HIG | minor | No keyboard or VoiceOver spec | Accept | Add to §9.7 and the Phase 1 check |
| H18 | HIG | minor | Phase toggles read a paragraph aloud | Accept | Goal sentence moves out of the summary |
| H19 | HIG | minor | Dock badge promised, unverified | Accept | 03 C30 marks it unverified |
| H20 | HIG | minor | iPhone Share step unverified for current Safari | Accept-modified | The steps leave the front page and are checked on their actual iPhones before sign-in opens |
| H21 | HIG | minor | Tap and click mixed | Accept | Device-neutral verbs outside the per-device steps |
| H22 | HIG | minor | CSP will block later media and uploads | Accept | A SCOPE note for when those features land; no change today |
| H23 | HIG | minor | Decisions anchor lands under the sticky filter at 390px | Accept | scroll-margin fix |
| E1 | Engineer | blocker | Fail-closed speaker rule can still fail open as on Sun 20 Sep; stage-9 check is a tautology | Accept | Fact 3. Verify short overlapping windows, words inside teacher windows only, a real coverage check, the 09-20 story as a must-reject case |
| E2 | Engineer | blocker | Readiness rule breaks under the Hybrid MP4 or MKV being requested | Accept | Ask for Hybrid MP4, not MKV (Apple frameworks cannot open Matroska); format-aware readiness; a copy-while-recording test |
| E3 | Engineer | blocker | No API between engine and Worker: auth, events, commands, ownership | Accept | One-page contract before Phase 0 code; minimal engine auth moves into Phase 0 |
| E4 | Engineer | blocker | Engine process model undefined (notifications, folder permission, sandbox) | Accept | One nested, non-sandboxed app identity that owns everything; reboot check in Phase 0 |
| E5 | Engineer | blocker | Self-hosted feed on R2 needs the domain's zone in the same Cloudflare account | Accept-modified | Recommendation stays a self-hosted feed on a Yoga Marga domain (D9), with zone and bucket in an account Yoga Marga owns, served by a small Worker; Q-G3 reworded; Phase 1 goes through RedCircle by hand until settled. Spine D9 note |
| E6 | Engineer | blocker | "Approval tied to the file hash" misses the text and the YouTube flip | Accept | Approve a publication manifest; required approvals per publication |
| E7 | Engineer | major | Privacy checked on the cut plan, not the rendered file | Accept | Post-render gate on the exact MP3; the first studio episode is hand-checked too |
| E8 | Engineer | major | Name scrubber depends on a roster due Mon 30 Nov | Accept-modified | Conflict 5. The seed list comes from the archive's own descriptions on the engine Mac, only with Serenity's yes; no new harvesting beyond PRV-14's screen check |
| E9 | Engineer | major | Research files that would be committed name students and one student's family detail | Accept | Verified (07 l.26, 96, 101; 06 l.90; 01 l.431, 436). Keep research 01 to 09 out of git; check BRIEF and DECISIONS by grep before the first commit (PR-19) |
| E10 | Engineer | major | Where the Claude calls run is contradictory | Accept-modified | Proposed: in the Worker as a Workflow (the VeraSales pattern). Architecture is Ivan's to confirm |
| E11 | Engineer | major | D1 schema missing pieces, connections, events, commands, challenges | Accept | Write the Phase 1 migration from the list before screens |
| E12 | Engineer | major | Multipart presigned uploads are more than Phase 1 needs | Accept | Authenticated Worker PUT with a streamed hash in Phase 1; multipart from Phase 3 |
| E13 | Engineer | major | Raw uploads to R2 contradict PR-12 and the front door | Accept | Conflict 6 |
| E14 | Engineer | major | $50 cap trips mid-archive | Accept-modified | Q-I4 is Ivan's. Suggested answer becomes $150 for October and November with alerts at 50% and 80%, and reaching it is a Needs a decision, never a silent pause |
| E15 | Engineer | major | Phase 1 order 1 is several times five days of work | Accept | Merged with C9; cut list in the tasks |
| E16 | Engineer | major | Always-on host plan misses FileVault restarts; "Asleep" is a guess | Accept | UPS, auto restart, authrestart, a 30-minute quiet alert, sleep and wake posts |
| E17 | Engineer | major | YouTube consent screen timing and trust gaps; invite email | Accept-modified | WEB-06 by Fri 16 Oct; Ivan starts verification now; SET-13 on Ivan's own test channel; a screenshot of the consent screen to the owner first; S18 for the email |
| E18 | Engineer | major | YouTube writes are not idempotent | Accept | Read before every non-idempotent write; persist the resumable session |
| E19 | Engineer | major | Second engine as specified floods review and is fragile under launchd | Accept | Parakeet in process through FluidAudio; disagreements only on key tokens |
| E20 | Engineer | major | "Never twice" has no identity definition | Accept | Stem, size and partial hash; a later twin attaches without a new notification |
| E21 | Engineer | major | Engine token could publish without approval | Accept | The Worker opens the upload session; the engine gets only the session URI (D3) |
| E22 | Engineer | minor | Word-index citations are unreliable | Accept | Verbatim quote plus rough timecode, matched in code |
| E23 | Engineer | minor | loudnorm goes dynamic on classes; input figures measured on stereo | Accept-modified | SCOPE fix; D9's range flagged for re-measuring in mono, no new number invented |
| E24 | Engineer | minor | index.js correct; verification renders from file:// only | Accept-modified | wrangler dev render and curl checks become required before the first deploy; conditional headers passed through; the app gate when the app lands |
| C1 | COO | blocker | The 25 rests on a questionnaire to Serenity; no meeting anywhere | Accept | Conflict 4 |
| C2 | COO | blocker | Channel owner unnamed; its password was texted twice; no rotation | Accept | Add the owner question; suggested answer "the school's contact account, which Serenity holds (to confirm)"; the account holder changes the password and turns on 2-Step Verification before the consent click. Prakriti never handles it |
| C3 | COO | major | 72 hours defined as "ready" in the goal and "live" in the exit check | Accept | One definition: ready within 72 hours; the median from ready to live is measured, with no promise |
| C4 | COO | major | Serenity made to approve every receipt, against SCOPE §9.4 | Accept | Conflict 1 |
| C5 | COO | major | Privacy gate is all-or-nothing; listener and hours unnamed | Accept | Split by content type; Ivan listens; about 3 to 4 hours (the critic's estimate, unmeasured), Thu 22 to Fri 23 Oct |
| C6 | COO | major | Release plan has no launch day or starting set | Accept | Suggested: launch Fri 30 Oct with 18, then one a day Sat 31 Oct to Fri 6 Nov, making 25; first 18 approved by Thu 29 Oct |
| C7 | COO | major | Gabriel-only fallback never counted | Accept | Merged with S4; a listen-instead-of-enrolment route for Serenity's one-voice recordings is offered as her OPEN question |
| C8 | COO | major | First public piece sits behind the whole web app; Apple review lead time | Accept-modified | A trailer (episode 0) from Gabriel's recorded intro, target Mon 19 Oct, through whichever host is ready (RedCircle by hand if none); Apple's review time is unverified; show art Fri 16 Oct |
| C9 | COO | major | Phase 1 cannot be done as written | Accept | The full-pipeline milestone moves to Wed 21 Oct; order 1 cut |
| C10 | COO | major | Archive size "1 to 2.7 TB" is unverified; the Takeout is about 388 GB | Accept | Spine D11 note; salvage no longer waits on the drive |
| C11 | COO | major | All archive work rides on a travelling laptop with no time budget | Accept | Machine-time budget; Vision only on the shortlist; daytime runs on power; a stated fallback if Ivan travels |
| C12 | COO | major | Nobody budgeted Ivan's time | Accept-modified | Add the table with proposed build sessions; Ivan's hours are left for him to confirm, not invented. One message per person on Fri 9 Oct |
| C13 | COO | major | Money gate lands on launch day; "second lane" defined two ways | Accept | Lanes defined once; Q-I5 to Fri 23 Oct; one neutral Phase 3 line |
| C14 | COO | major | Three student rules across documents | Accept-modified | Conflict 3 |
| C15 | COO | major | Items from 01 and 09 with no row, owner or date | Accept-modified | Add YACEP (Q-S20), the owner question, the two standing calls, close D-13 in the Fri 9 Oct note, password rotation. Restarting Serenity's Monday slot is raised at her meeting with no start date pressed |
| C16 | COO | major | No forcing mechanism in the approval window | Accept | Two 20-minute sessions a week (Tue and Thu) from Tue 27 Oct to Thu 5 Nov; Ivan's end-of-day line when anything waits over 48 hours (one recap a day) |
| C17 | COO | major | Domain mechanism unsettled; could put the school's DNS in Ivan's account | Accept | Merged with E5 |
| C18 | COO | major | Dates and owners differ across the five documents | Accept | One table of shared facts for both implementers |
| C19 | COO | minor | Sample breaks the product's own rule | Accept | Merged with G8, S3 |
| C20 | COO | minor | Phase 3 needs three sessions with no recording commitment; Thanksgiving | Accept-modified | Recording commitment in Q-G5; any three sessions in a row ending by Mon 30 Nov; Thu 26 Nov is Thanksgiving |
| C21 | COO | minor | Nothing records the feedback rounds | Accept | This file, plus a Feedback rounds section in the CHANGELOG |
| C22 | COO | minor | Current-state table already out of date | Accept | Code row updated |

**Totals:** 141 findings, 0 rejected outright. 46 were accepted with a modification, and in five
of those a specific part of the fix was rejected with its reason: dates inside the sign-in buttons
(G21), quoting the income claim on the page (G8, S3), using the class note before a lawyer reads
it (S21), single digits across all phases (G2), and harvesting student names by OCR (E8).

### What changed

Filled in by both implementers on Thu 8 Oct 2026: the site half first, then the docs half.

#### Site: web/public and web/src (site implementer, Thu 8 Oct 2026)

Nothing deployed and nothing committed. Every weekday on the three pages was recomputed with
`date -j -f %Y-%m-%d <date> +%a` (28 distinct dates, 0 mismatches).

**Front page (`index.html`)**
- Hero: the new lead, one status line ("Being built now. The first episode is planned for Friday
  23 October."), and two plain facts under the hero lined up with the card and the package
  (G11, B4). The archive line reads "958 videos, mostly classes and talks, sit on the school's
  YouTube channel, most of them unlisted": the brief's "958 classes and talks" would count the
  114 test uploads and the coaching calls as classes, which is the kind of claim Serenity's
  accuracy condition exists to catch.
- Sign-in card: one "Continue with Google" button with `aria-disabled="true"` and
  `aria-describedby` on the status, so Tab and VoiceOver reach it and hear why it is dimmed
  (checked: the seventh Tab lands on it); the passkey line under it; the "remembers" sentence
  gone; no date in the button; no G mark (H6, B6, G21).
- Sample package: `pk-title` is an `h2` (H12). Quote replaced with "The second pattern is that
  people confuse cost with value." **Timecode measured, 00:27:53**: a local faster-whisper
  large-v3 pass with word timestamps on a read-only slice of
  `Studio Recordings /2026-09-06/2026-09-06 18-06-33.mp4` put "The" at 1673.52 s; a second
  slice from a different offset put it at 1673.60 s. 00:26:10 is gone. The Audio verdict's "no
  gaps longer than 10 seconds" was also measured (ffmpeg silencedetect at -50 dB over the whole
  file: no silence of 10 s or more), and "four other ways" was counted in the file's transcript
  (Yoga Margo, Yoga Margot, Yogamarga, yoga market). Video and Message now read Worth a look,
  with the given reasons; the claim and its figures are not quoted anywhere (G8, S3, C19).
  Accuracy adds the income-claim and Mentions Serenity lines; the label line uses "Recorded in
  September 2026". "Three thumbnail options" with the type-only caption (G9). Episode art is a
  typographic "Yoga Marga" tile in tokens (ink on ground, inverting in dark) with "show art to
  come"; Prakriti's mark is no longer used as show art (B17).
- How it works: the honest lead (B5, G14); step 3 in the honest wording; step 5 "one step to
  approve"; step 6 names the release slot and Undo (H3); `role="list"` on both step lists, and
  the step numbers are read aloud as "Step 1" (H14).
- What runs on its own: headline without "always" (B9); the removal line now says a person
  checks (S1); the AI line rewritten to the one AI rule; the note uses conflict 10's wording.
- What comes out: First, Next, Later, With consent; "lane" appears nowhere on the public pages
  (B13); "Other voices are removed."; no "score out of 100"; thumbnails as real frames or type;
  Spanish is With consent (S16); each teacher's voice recordings stay locked (B8); the file tree
  is one line (B14).
- Privacy and accuracy: the new lead; the privacy promise, student rule and approvals rule
  verbatim (S1, conflicts 1 and 3); names card; receipts "reviewed in a few minutes, with the
  moments worth hearing queued for her"; the yes tied to the file and every word with it (E6);
  "Any of you can stop it."; the Claude row split by teacher (S8); "finished files".
- Notifications: two sentences, one specimen, the Found and Started line, "Opening it shows the
  review screen.", the Never list kept, the Also sent list folded into one sentence, the Mac and
  iPhone setup steps removed (G23, B14, H15, H20).
- Questions: "Questions."; future tense; the AI answer is the AI rule (G12); device-neutral verbs
  (H21). Closing: "One output at a time." with the given text.
- Nav on all three pages: Roadmap is the filled button and Sign In a plain link until
  invitations go out (B16); a comment in the HTML says to swap them back that day. Bar and footer
  wordmark is lowercase "prakṛti" in Tiro with the ultramarine underdot and a screen-reader
  "Prakriti" (B15).

**Roadmap (`roadmap.html`)**
- New H1 and lead (B23); "Since the 7 Oct page" with six lines and their reasons, under the
  phase strip (G3).
- Where things stand: one label set (Done, Waiting on a person, Not started) in rows and key;
  the studio, archive (none transcribed yet, about 388 GB, fits on Ivan's Mac) and front-page
  rows as specified (G4, C10, B24).
- Goal tiles and the 25 note as specified; "0 student voices" is labelled Serenity's condition;
  the lead no longer ends in "something anyone can check" (S4, C3, B10, B12).
- Phases: "Six phases, podcast first."; tags Now, Next, Planned; each goal sentence moved out of
  `<summary>` into the body, so a phase toggle reads only its name, dates and tag (H18). Phase 0
  to 5 rows, deliverables, checks and "Not in this phase" lines rewritten from the shared facts
  (tasks 12 to 15), including the trailer, the Tue 20 / Wed 21 / Thu 22 / Fri 23 Oct targets,
  the release plan, the approval sessions, the account holder's password and 2-Step
  Verification step, and "Starts once Ivan and Gabriel agree the terms for this stage." with no
  number.
- Decisions: For Gabriel, For Serenity (grouped: asked when you meet by Fri 23 Oct; when you are
  ready; by Fri 30 Oct with "Until you answer"; by Mon 30 Nov), For you both and Ivan's to
  decide, as specified; the surname and email question is gone (S18); two "For information"
  lines for Gabriel. The Never list is the eleven headings in order; "Score work out of 100" and
  "Chase attention" are deleted (B20, G17).
- Three wording calls, each to keep a page rule: "in a lane" in the publish-unless-stopped lines
  became "of one kind of piece" (no "lane" on public pages); "click Prakriti's Google consent"
  became "give" (device-neutral verbs); "a checkbox is not consent" became "consent to a likeness
  has to be that person's own, in writing" (no "X, not Y").
- The filter now counts asks, not rows: a phase row and a decision that are the same ask share a
  `data-ask` key and count once, and the summary says how many are due by the end of the phase
  marked Now. Measured on the page: Gabriel 9 asks due by Fri 16 Oct (38 in all), Serenity 3,
  Ivan 11. The sound check ("From now on") has no date, so it counts only in the total. The
  account holder's rows (Takeout, consent, auto-dubbing) are tagged to both Gabriel and Serenity
  until the owner is confirmed on Mon 12 Oct; if Serenity is confirmed, Gabriel drops to 8.

**Stylesheet, favicon, Worker**
- `site.css`: segments 44px with an ink fill when chosen (H9); a `--btn-border` token (light
  #82857E, dark #6A6D72) for control edges (H10); `--ink-3` darkened (light #4F5258, dark
  #A3A59F) and a `prefers-contrast: more` variant (H11); the accent split into `--accent-text`
  and `--accent-mark` (B18). **One value differs from the brief:** the dark mark is #4459E8,
  since #3A4FE0 measures 3.04:1 on the dark ground but 2.82:1 on the dark surface; #4459E8 is
  3.45 / 3.21 / 3.58 on ground, surface and sunk. All ratios in the header comment were computed,
  not copied. Dark tile A has an edge; the contents focus ring sits inside its box and was
  re-captured by Tab in both themes (H13); anchors inside the filter scope have a 104px scroll
  margin, re-checked at 390 and 1440 for #decisions, #for-gabriel, #for-serenity and #phase-1
  (every heading lands below the filter bar) (H23); `role="list"` on every styled list.
- `favicon.svg`: the ultramarine dot alone on the stone ground, with a hairline edge so it holds
  on light and dark tab bars.
- `index.js`: If-None-Match and If-Modified-Since are passed to the asset binding, and its 304
  goes out with no body and the full security headers; the 404 page never takes a conditional.
  CSP unchanged. Verified under `wrangler dev`: 304 with every security header for /, /roadmap,
  /assets/site.css and /robots.txt on a repeat with the ETag; a stale ETag gets 200; unknown
  paths, /src/index.js, /wrangler.jsonc, /.git/config and /404.html get a real 404; no HSTS over
  http. The binding sends no Last-Modified, so only the ETag path could be tested.

**Verification**
- Rendered index, roadmap and 404 at 390, 768 and 1440 in light and dark with
  `scripts/shoot.mjs` (18 renders), and through the local Worker at 1440 and 390 dark: no
  console errors, no failed loads, no sideways scroll at any width. Smallest rendered text is
  12px on every page (measured in the browser). Grep of `web/public`: 0 em dashes, 0 "lane".
- One limit for whoever owns `scripts/shoot.mjs`: it caps a full-page capture at 16,000px, and
  the roadmap is 17,020px tall at 1440 and 25,741px at 390, so the bottom of those PNGs is cut.
  The cut part (Decisions, Never, closing, footer) was checked with separate viewport captures.

#### Docs: PLAN.md, docs/SCOPE.md, README.md, START_HERE.md, CHANGELOG.md (docs implementer, Thu 8 Oct 2026)

Nothing deployed, committed or sent; `research/DECISIONS.md` and `.gitignore` untouched. Every
weekday was recomputed with `date -j -f %Y-%m-%d <date> +%a`. Zero em dashes in all five files.

- **PLAN.md** (rewritten throughout): current-state rows (code written, not deployed; archive not
  transcribed, about 388 GB, fits on Ivan's Mac); the goal rows (the 25 from teacher-only talks with
  the count OPEN until Sonny counts it; 72 hours as a proposed target to "ready"; Serenity's
  condition; reviews under 5 minutes); "The next few days" (one message each on Fri 9 Oct, the
  metadata count, the channel-owner question, RedCircle check, three scripts, the studio visit,
  brand verification; row 3 records the research-files and `.gitignore` steps for the first commit;
  the salvage no longer waits on a drive and excludes private items) (G2, G4, G5, C2, C10, C12, E9,
  S11, S15); gates (publication manifest, the approvals rule, publish unless stopped, the exact
  student and AI rules, privacy proof split by content type with Ivan as listener Thu 22 to Fri 23
  Oct and the post-render check, quarantine at inventory, lanes defined once with Q-I5 Fri 23 Oct,
  the FileVault host items) (E6, S6, C3, C4, C5, C13, E16); Phases 0 to 5 per the shared facts,
  including the engine API contract and process model in Phase 0, the reboot and copy-while-recording
  checks, Phase 1's order 1 cut and new milestones, Phase 2's approval sessions, release plan,
  machine-time budget and pre-flip check, Phase 3's terms line, Thanksgiving and shorts
  destination (E3, E4, C6, C8, C9, C11, C16, C20, G15, G16, H2); "Time it takes" with proposed
  sessions and Ivan's hours left OPEN (C12); the open questions re-sorted by date (Q-G10 and Q-S11
  split, Q-G12 dropped, Q-S17 removed, Q-GS6 to the studio visit, Q-G20, Q-G21 and Q-I16 to the
  pair, new Q-G23 to Q-G25, Q-GS7, Q-GS8, Q-I18, Q-I19, Q-S20 to Q-S23); "Spine corrections
  pending"; "Since the 7 Oct page" (G3).
- **docs/SCOPE.md:** new §6.4 engine API contract (old §6.4 is now §6.5) and the Worker-only upload
  session rule; Claude in the Worker marked Proposed for Ivan (E3, E10, E21); §7.2 process model,
  plain bookmarks (E4); §7.3 format-aware readiness for Hybrid MP4, remux of non-MP4 archive files
  (E2); §7.4 real coverage check at stage 9 and a post-render gate 18a (E1, E7); §7.5 identity
  (E20); §7.7 Parakeet in process, review only on key tokens (E19); §7.8 window verification with
  09-20 as a must-reject case (E1); §7.10 roster seeding with her yes, phonetic matching, fail
  closed in greetings (E8, S14); §7.11 mono first, linear loudnorm, LUFS range flagged (E23);
  §7.13 Worker PUT in Phase 1, multipart from Phase 3, zip at download time (E12); §7.14 FileVault
  and always-on items (E16); §8 Web Push tags mirroring native identifiers, no passive level,
  email first, D4 defaults, Q-I19, the CSP note (H1, H2, H8, H22); §9.0 navigation, the phone
  review layout, the named Approve with release-slot Undo, the manifest, D4's nine states, the
  approvals rule, keyboard and VoiceOver, no Dock badge promise (H3, H4, H7, H16, H17, H19, E6);
  §10 new tables (pieces, connections, engine events and commands, WebAuthn challenges),
  manifest hashes, required approvals, audit-log triggers, no raw uploads, originals never deleted
  automatically (E11, E13, S12); §12 the feed in Yoga Marga's Cloudflare account with a feed
  Worker, RedCircle by hand until then and its forwarding marked unverified, YouTube project and
  verification order, read-before-write, the comment and dub check, the release plan (E5, E17, E18,
  G7, S13, C6); the receipt's "Listen here" row and its line (S2); PRV-04, PRV-09, PRV-10 and
  PRV-16 marked Decided (D5) (S22); the Never list mapped to the shared headings with the three
  shared sentences, NEV-05 and NEV-13 narrowed (G17, B20); §11.9 and §18 rewritten to mirror PLAN
  exactly; §15, §16, §17 (R-35 to R-37 added), §19 and the appendices brought in line. Feature
  count unchanged at 244.
- **README.md:** the Never list in the shared headings and order, the exact student rule, AI rule
  and privacy promise (the "treated as a student and cut" sentence and the web-drop sentence
  removed), "One step approves it" with the release slot and Undo, status and asks per the shared
  facts, no "lane" (S1, B1, B3, B13, E13).
- **START_HERE.md:** warnings 14 to 18 with reasons (separation is never a guarantee; Hybrid MP4,
  never MKV; research 01 to 09 out of git; `wrangler dev` and curl checks before the first deploy;
  no raw upload), the local curl commands, a pointer to this file, and current-state lines that
  match the code on disk (E2, E9, E24, E13).
- **CHANGELOG.md:** a new top entry for round 1 with a Feedback rounds section (six lenses, 141
  findings, 0 rejected outright, 46 accepted with a modification, the five rejected parts, the top
  changes, a pointer here); the earlier entry's "web/public and web/src are still empty" line
  corrected (C21, C22).

---

## Round 2

Reviewed Thu 8 Oct 2026, after the round 1 changes: `docs/SCOPE.md`, `PLAN.md`, `START_HERE.md`,
`README.md`, `web/public/index.html`, `web/public/roadmap.html`, `web/public/assets/*`,
`web/src/index.js`. Finding IDs restart in each round, so G3 here is not round 1's G3. Every weekday
below was computed with `date(1)`.

Two facts were checked by the reasoner before deciding, because whole findings rest on them:

- **The pool behind the 25 is small.** A read-only screen of the Takeout metadata (titles,
  descriptions and the description-text exports, counts only, no titles copied out): 35 of the 958
  videos mention Gabriel or "Gab"; 31 of those do not mention Serenity and are not private; only 5 of
  the 31 carry no class or session words; the 31 add up to about 37.5 hours. Metadata is a weak
  signal (a talk may not name its teacher), so this is a first screen, not the count PLAN row 5 asks
  for. It confirms G2 and C1.
- **The Sun 20 Sep labelling was run on 7 Oct.** `Studio Recordings /2026-09-20/2026-09-20
  18-07-58.txt` was created Wed 7 Oct 13:03; the recording is dated Sun 20 Sep. It confirms S18 and B4.
- Also confirmed by reading SCOPE: stage 11 (lexicon, Haiku) runs before stage 14 (names) and stage
  15 (redaction) (E2); `feed.xml` is rendered from D1 inside Yoga Marga's account (E4); §6.4 has no
  path for Claude's results (E5); PRV-15 and PR-21 check picture and sound but not names (S1).
  `df` shows about 812 GiB free with the partial download still on disk (E9, C5).

### The six verdicts

- **Gabriel:** clearer than round 1 and most of his items landed, but his archive idea (five good
  minutes, hours of Serenity) is quietly closed, the 25 rests on an uncounted small pool, and every
  fallback hands posting back to him.
- **Serenity:** she would trust most of it; the "promise the check" fix missed three places, the
  archive flip can still publish a student's name, and several of her protections have no mechanism.
- **Brand and copy:** the identity holds and round 1's brand fixes shipped, but five promises are
  broken by their own pages, Serenity gets 32 questions, and the length cut (B14) did not happen.
- **HIG and accessibility:** the pages pass the measurable basics; SCOPE would ship stale
  notifications, repeated sign-ins, mute transcripts and a drag-only calendar, and the roadmap hides
  its phase names from screen readers.
- **Engineer:** sound in shape, but six blockers: the Phase 1 workload, a lexicon stage that sends
  unredacted text to Claude, no real "finished" test for Hybrid MP4, a cross-account feed that cannot
  be built, no path for Claude's results, and a KeepAlive that defeats Quit.
- **COO completeness:** coverage is complete and dates check out, but it is not run like an
  operation where the 25 lives: a small pool, a manual default for Gabriel, episode 1 quietly waiting
  on Serenity, no build time or disk room for Phase 2, and a Fri 23 Oct cliff.

### Conflicts between critics, and how they were resolved

1. **Where the podcast lives and who uploads (G3, G4, C2, E1, E4, E14, S10).** One decision for
   Gabriel by Fri 16 Oct: a new Yoga Marga show, which he names, on a web address Yoga Marga buys only
   for the podcast and holds in its own Cloudflare account, so `yogamarga.school` and its email are
   never touched (C2). His existing RedCircle show stays as it is. Ivan sets it up and does every
   upload; Gabriel never uploads, posts to the podcast or submits (G3). The feed follows E4's single
   publisher. C2's "Transistor if no answer" is rejected as a default because it spends money, and
   money never defaults (round 1 G2); Transistor stays an option with Gabriel's yes. With no answer,
   the first episode waits for the show's home rather than going somewhere temporary, because
   whichever feed carries episode 1 carries the 25, and the RedCircle forwarding is unverified.
2. **The path to episode 1 (E1, C13, C15, C3, S4, G11).** Fri 23 Oct stays, as on the record. The
   Mon 19 Oct trailer is dropped: it had no approval mechanism (G11), went out before the stop button
   existed (S10) and added a hand upload. The engine makes episode 1 on the Mac (by hand with ffmpeg as
   a fallback, as Ivan did on 09-10); Serenity gets a private link Wed 21 Oct, Gabriel Thu 22 Oct, and
   his yes in writing is recorded against the exact files; Ivan uploads Fri 23 Oct. C13's Mon 19 Oct
   date is rejected: the show's home and Serenity's look cannot be ready by then. Sign-in, the review
   page, Pause All Publishing, the activity log and the cost ledger move to "by Mon 26 Oct", before
   archive approvals open (E1). Web Push follows after Fri 6 Nov; until then notices come by email
   (C15).
3. **Serenity's dates (S20, B8, C9).** Every one of her questions already has a most-private setting
   until she answers, so none of them blocks Gabriel's 25. Her privacy set moves to Fri 30 Oct, after
   the fuller assessment (target Thu 22 Oct, latest Mon 26 Oct), honouring A-12. Only four questions
   show as needed (voices, names, retold stories, Claude); the rest sit in one collapsed group "Each
   has a safe setting until you answer". Q-S4 (does the rule cover classes and calls) moves to "before
   any class is considered, in Phase 3". C9's "Serenity's privacy set on Fri 23 Oct" is not kept.
4. **Teacher-only stretches of classes (G1 vs S14).** S14's rule is adopted now: a segment inherits
   its source recording's type, gates and approvers, so a stretch of a class is a class. G1's question
   goes to Serenity (new Q-S24, Fri 30 Oct), suggested yes for stretches where no student is heard,
   named, described or answered, with her receipt on each, and the lawyer asked to confirm when the
   release is read. Until she answers, class stretches stay private.
5. **Pieces that name Serenity (S4 vs C3).** She becomes a required viewer of any piece that names
   her (found with the same phonetic matching as student names, failing toward showing her). The hold
   time is hers to set (new Q-S26, suggested 48 hours). If she has not looked by then, the passage
   that names her is cut and the piece proceeds, so nothing about her goes out unseen and Gabriel is
   never stuck. For episode 1 the hold ends at the end of Thu 22 Oct.
6. **Gabriel's voice clip (C7 vs E10).** Asked in the Fri 9 Oct message with a requested date of
   Fri 16 Oct and the plain cost of no answer (Ivan labels by hand, which limits how many of the 25
   can be ready). It never defaults to yes, which keeps E10's "do not press". Serenity's voice question
   stays undated.
7. **Approval sessions (G6, C10, S19).** Gabriel's sessions are 20 minutes on Mon 26, Tue 27 and
   Thu 29 Oct, then Tue 3 and Thu 5 Nov; one of them can be the weekly Yoga Marga call Ivan proposes
   on Fri 9 Oct. For Serenity it becomes a question (new Q-S27). The first 18 are counted on the
   podcast feed only; YouTube approvals follow at up to two a day (C10, B22).
8. **The lawyer's date (S16 Fri 16 Oct, C19 Fri 23 Oct).** Fri 23 Oct, with who pays OPEN for Ivan
   and Gabriel (suggested: Yoga Marga, as the data owner). Fri 16 Oct already carries most of
   Ivan's week. The voice permission's lawyer-read version is restated as "within four weeks of the
   lawyer starting" (S16).
9. **Gabriel's Fri 23 Oct load (G5 vs C9).** C9's dates are used everywhere: release plan and who
   approves to Fri 16 Oct; frames, hooks, removal requests, the class note, the data note, summary
   times and mastering to Fri 30 Oct. The YouTube owner steps (password, 2-Step Verification, consent,
   dubbing) happen in one sitting with Ivan beside, Fri 23 Oct (G5).
10. **Who decides the always-on Mac (C21 item d vs D2).** C21 asks for Ivan alone. DECISIONS D2 says
    Ivan and Gabriel, and the critic shows no fact that D2 is wrong, so that part is rejected: PLAN
    and the roadmap both say "Ivan and Gabriel".
11. **Front page length vs additions (B10 vs G8, G15, G18).** The additions are one FAQ and two
    sentences; B10's folds (the autonomy lists into How it works, Notifications to one sentence, Where
    things run into a FAQ, the "posted by accident" FAQ cut) remove far more. Target about 7,000px at
    1440, measured after rendering.
12. **"Keep as B-roll" (H11).** Kept. Gabriel decided on Wed 7 Oct that silent recordings go to a
    b-roll folder, so it is his own word for his own notice. The rest of H11 is accepted.

### Spine corrections pending (round 2 additions; DECISIONS.md is still not edited)

These join round 1's six. C12 adds an Ivan row, due Fri 9 Oct before the two messages, to accept or
reject each and publish DECISIONS v2 the same day, because every document says the spine wins.

- **D9:** one publisher. Ivan's Worker renders `feed.xml` at each release slot and writes it into
  Yoga Marga's bucket with a bucket-scoped token; the feed Worker in Yoga Marga's account reads only
  its own bucket. `itunes:new-feed-url` belongs in the old feed. The podcast gets its own domain. The
  trailer is dropped.
- **D11:** the archive needs an external drive of about 2 TB (cost to price, OPEN for Ivan) or
  part-by-part extraction; the re-run is never extracted into a watched folder before inventory;
  students' words in class transcripts are kept only as timecodes.
- **D10:** the YouTube Cloud project lives inside the school's Google Workspace if there is one
  (Internal, no verification); Prakriti's YouTube code has no delete call.
- **D1:** every cloud call runs after redaction (the lexicon stage is local); Claude's results reach
  the engine through an editorial endpoint it polls.
- **D14:** a returning person signs in with a passkey in one step; Google is for the first binding to
  the invitation and for recovery.

### Every finding

| ID | Lens | Severity | Finding | Decision | Reason |
|---|---|---|---|---|---|
| G1 | Gabriel | blocker | His archive idea (five minutes from a long class, hours of Serenity) is promised in Phase 2 and closed by the student rule | Accept-modified | Conflict 4: S14's inheritance rule now, plus a dated question to Serenity (Q-S24, Fri 30 Oct) and one plain line on Gabriel's list; never decided silently |
| G2 | Gabriel | blocker | He is asked to re-confirm 25 on Fri 9 Oct from an uncounted, probably small pool; the reset waits to Mon 26 Oct | Accept | Reasoner's metadata screen: 31 candidates, 5 without class words. The count and any reset move into the Fri 9 Oct message; suggested fallback is his own "10" from 10-07; the tile reads Proposed until counted |
| G3 | Gabriel | major | Every fallback hands uploading or posting back to Gabriel | Accept | G-02 is the north star (T1007 l.30-32, l.98). Ivan owns every by-hand upload and submission; Gabriel's only step is one access grant; Ivan checks RedCircle team access on Mon 12 Oct |
| G4 | Gabriel | major | Nobody decided whether the podcast is his existing RedCircle show or a new one | Accept | Conflict 1: a new show he names, in its permanent home; the existing show untouched until forwarding is verified (spine D9 note) |
| G5 | Gabriel | major | Fri 23 Oct piles up about 11 of his items; three operational rows lack a default | Accept-modified | Conflict 9 uses C9's dates; defaults added (who approves defaults to "you approve your own", the conservative reading); owner steps in one sitting |
| G6 | Gabriel | major | The standing Yoga Marga call he asked for vanished from the pages | Accept | T1007 l.181-182 and the 7 Oct page. Ivan proposes times Fri 9 Oct; decisions and an approval session fold into it |
| G7 | Gabriel | major | Choosing "Gabriel" makes the page longer, counts shared account rows, repeats asks | Accept | Merged with H9. A dated list on top, others collapsed, "next" instead of "in all", account rows out of his count until Q-GS7 |
| G8 | Gabriel | major | The front page never says what he has to do or who uploads; approval stated about seven times | Accept-modified | A first FAQ answers it; hero rewritten with S24's accuracy; the "posted by accident" FAQ cut. Instagram stays his until Phase 5, said honestly |
| G9 | Gabriel | major | "Since the 7 Oct page" omits the change to his 25 and what got lighter for him | Accept | Three lines with reasons (the 25 now teacher-only talks, Ivan asks Serenity directly, the weekly call) |
| G10 | Gabriel | major | Shorts need vertical recording, off since 09-06, and no row turns it back on | Accept | PLAN SET-05 already assigns it; moved into Ivan's studio visit so it is not a separate Gabriel ask |
| G11 | Gabriel | minor | "Approve the trailer, Mon 19 Oct" has no way to approve and no owner | Accept-modified | Conflict 2: the trailer is dropped rather than given a mechanism |
| G12 | Gabriel | minor | His episode-specific intro idea shrank to fixed scripts; round 1 G19's later option is on no page | Accept-modified | One Phase 3 line, only if he wants it; an ElevenLabs intro in his own voice stays his option with the AI label (D9) |
| G13 | Gabriel | minor | His questions use infrastructure jargon | Accept | Plain questions on the page; technical wording stays in PLAN (Ivan's plain-language rule) |
| G14 | Gabriel | minor | The status row will read "waiting to go live" on the live page | Accept | A deploy-checklist step changes it to Done with the computed date |
| G15 | Gabriel | minor | His "digital brain" wish only appears as the Phase 4 Library | Accept-modified | One line: the transcript of each of his own solo talks is in his package, ready for his own tools. Limited to his solo talks, so Serenity's teaching is untouched (Q-S13) |
| G16 | Gabriel | minor | The weekly Sunday talk is "For information" with no date while input has stopped | Accept | 01 §13 trap. A dated ask, Sun 18 Oct, suggested yes, with "the first episode does not wait for it" |
| G17 | Gabriel | minor | The terms gate on his shorts sits only in Ivan's list | Accept-modified | A Phase 2 row for Gabriel and Ivan, Fri 23 Oct, no number (D16); raised live on the call |
| G18 | Gabriel | minor | Pages never say where a listener finds the show; the website redesign vanished | Accept-modified | One sentence on where episodes appear once submitted; the redesign is named as separate and asked about on the weekly call, not declared dropped |
| G19 | Gabriel | minor | "Never the archive" reads as an unexplained rule | Accept | Rewrite as given |
| G20 | Gabriel | minor | Two of his PLAN questions (contractor drives, Fathom links) are not on the page that claims "every step" | Accept | Both marked "asked privately in Ivan's message"; the roadmap hero says "every step for Prakriti" |
| S1 | Serenity | blocker | The archive flip checks picture and sound, not spoken student names or YouTube's automatic captions | Accept | 08 §0.1 (names in the first minute). The name scrubber runs on the original's transcript before any flip; any name blocks it; auto-captions checked read-only on the first real video |
| S2 | Serenity | blocker | The front page promises to publish "every new studio session", which includes classes and private disclosures | Accept | Merged with C16. SCOPE §3.3 and 01 l.431; reworded to teacher-only talks, classes wait for her rule |
| S3 | Serenity | major | Student audio upload contradicted three ways (Q-S18 wording, defaults, "Is this Serenity?" on Other voice) | Accept | Merged with B1. Q-S18 reworded to teacher moments; SCOPE's default "both"; Other voice segments only at the engine Mac (OPEN for Ivan, Q-I22); Never reason widened to removed audio |
| S4 | Serenity | major | "Pieces that name Serenity are shown to her" has no mechanism; she accepts her invitation after the episode | Accept-modified | Conflict 5: required viewer, a "To See" notice, phonetic matching, hold time hers (Q-S26); episode 1 by private link |
| S5 | Serenity | major | Passages about her own life are held for whoever approves, not for her | Accept | New Q-S25, suggested yes, held until she answers; offered to Gabriel too |
| S6 | Serenity | major | Claude may read her teaching in archive triage before her answer on Claude | Accept | Q-S13 is hers (round 1 S8). Her items triaged from metadata on the Mac until consent is Granted; the allowlist checks consent; her assessment uses on-Mac data only |
| S7 | Serenity | major | The re-run export will copy the private calls again into a watched folder | Accept | The streaming extractor and its exclusions apply to the re-run; never extracted into a watched folder; "never extracted, opened, transcribed or sent to any AI"; Q-S23 covers both exports |
| S8 | Serenity | major | The one-time YouTube grant lets Prakriti delete any video, with no limit and no way out stated | Accept-modified | A code-enforced rule (no delete call, manifest IDs only, encrypted token) and the withdrawal path on the page. Google's exact wording is quoted only once seen on the screenshot, never from memory |
| S9 | Serenity | major | "Promise the check" missed the goal tile, the names card and step 3 | Accept | Merged with B5. Round 1 S1 extended; the tile uses a distinct mark (H10) |
| S10 | Serenity | major | "Any of you can stop it" is false on the by-hand path; the trailer goes out before the stop button | Accept-modified | Conflict 2 drops the trailer; one line says takedown is Ivan's hand step while uploads are by hand; the show description and intro script go to Serenity before episode 1 |
| S11 | Serenity | major | Students' words in archive class transcripts are kept forever | Accept-modified | Recommended answer to Q-S12 and applied by default (most private): teacher-window text plus the redaction plan, Other voice kept only as timecodes |
| S12 | Serenity | major | Ivan alone can lift a pause or takedown she made for privacy | Accept-modified | OPEN for Ivan (Q-I21) with the recommendation; on the roadmap only, since the front page states only settled rules |
| S13 | Serenity | major | Review-time numbers disagree and put a clock on her accuracy condition | Accept | Merged with B6. One number per person, named as theirs; hers says nothing is published to meet a clock |
| S14 | Serenity | major | Segment episodes inherit nothing from their source | Accept | Conflict 4; a segment inherits type, gates and approvers, plus a context line |
| S15 | Serenity | minor | Her consent switches can be set by Ivan; not enforced in code | Accept | Mirrors §7.8 rule 7: a teacher's own uses go to Granted only from that teacher's account |
| S16 | Serenity | minor | Lawyer-read promises depend on a lawyer decision dated Mon 30 Nov | Accept-modified | Conflict 8: Fri 23 Oct, not Fri 16 Oct; "within four weeks of the lawyer starting" |
| S17 | Serenity | minor | "Until you answer" defaults differ between roadmap and SCOPE | Accept | The stricter one everywhere, word for word |
| S18 | Serenity | minor | Her section gets its own chronology wrong (20 Sep vs 7 Oct) | Accept | Verified by file date. Merged with B4 |
| S19 | Serenity | minor | Approval sessions put on her calendar without asking | Accept | Conflict 7; a question for her (Q-S27) |
| S20 | Serenity | minor | Her answers are due before the assessment she asked for can arrive | Accept-modified | Conflict 3: Fri 30 Oct for the privacy set, Q-S4 to Phase 3 |
| S21 | Serenity | minor | A private feed of full classes is forwardable, unsaid | Accept | One feed link per student that can be switched off, under the new release, or keep classes in Skool |
| S22 | Serenity | minor | Two front-page lists show her voice labelling as already running | Accept | Labelling her voice needs her written yes (Q-S5) |
| S23 | Serenity | minor | AI wording still implies more than the rule ("Not on its own"; "Each teacher makes their own") | Accept | Merged with B9 |
| S24 | Serenity | minor | Hero says "the teacher in it says yes"; the rule lets a named person approve | Accept | Merged with B2; README already uses the accurate form |
| S25 | Serenity | minor | "Kept on one Mac" breaks under Time Machine and the move to an always-on Mac | Accept | Exclude from backup, non-syncing Keychain item, deletion logged on the move |
| B1 | Brand | blocker | "Hear removed moments" says student audio goes to her phone | Accept | Merged with S3 |
| B2 | Brand | blocker | Hero and meta description promise only the teacher approves | Accept | Merged with S24 |
| B3 | Brand | major | Closing line says every suggestion waits for a yes; some default | Accept | Round 1 G2 rule stated honestly |
| B4 | Brand | major | Serenity's section reverses the order of events and uses a colon reveal | Accept | Merged with S18; uses the 7 Oct date |
| B5 | Brand | major | "Names are muted" promises perfection | Accept | Merged with S9 |
| B6 | Brand | major | Hero fact over-promises (classes, everyone's 2 minutes); her 5 minutes stated as fact | Accept | Merged with S2, S13, C16 |
| B7 | Brand | major | The sound-check ask promises a confirmation that cannot happen yet | Accept | The laptop sleeps and sign-in is not open; Gabriel plays the test back himself until then |
| B8 | Brand | major | Serenity gets a questionnaire of 32 questions, nine due before her assessment | Accept-modified | Conflict 3: four shown, the rest collapsed under their safe settings, due Fri 30 Oct |
| B9 | Brand | major | AI FAQ contradicts itself | Accept | Merged with S23 |
| B10 | Brand | major | Round 1 B14 (front page too long) was accepted and not achieved | Accept | Conflict 11; target about 7,000px at 1440, measured |
| B11 | Brand | major | The listener-ask suggestion names no ask and defaults | Accept | "One ask, same every episode, in your words"; no answer means no ask, never an invented one |
| B12 | Brand | minor | "900 or so" on a page that says 958 | Accept | DECISIONS fact 1 |
| B13 | Brand | minor | Since-list aphorism; "the always-on Mac" treats an undecided machine as real | Accept | D2 is OPEN |
| B14 | Brand | minor | "The check that proves it done" is ungrammatical, six times | Accept | "Done when" |
| B15 | Brand | minor | The full AI rule repeats four times on the roadmap | Accept | Once per page in full; one line elsewhere |
| B16 | Brand | minor | Monospace lines show engineer artefacts teachers never see | Accept | Keep what is real and readable; drop "status:" |
| B17 | Brand | minor | "Raised" is jargon; "the same day" holds only while the Mac is awake | Accept-modified | Wording as given, applied to both pages |
| B18 | Brand | minor | A grammar slip; the checklist called a receipt | Accept | Wording as given |
| B19 | Brand | minor | "Venture" is Ivan's internal word | Accept | Wording as given |
| B20 | Brand | minor | "What he owes" frames decisions as debt | Accept | Wording as given |
| B21 | Brand | minor | British and American spellings mixed | Accept | American throughout, for a US school |
| B22 | Brand | minor | "18 in one day, then at most two a day" reads as a contradiction | Accept | Conflict 7: 18 on the feed, YouTube at up to two a day; matches SCOPE PUB-13 |
| B23 | Brand | minor | k and r fuse above the ultramarine dot at 300px | Accept | Fix one way, render at 2x and look before keeping |
| B24 | Brand | minor | README "not X, it's Y" with British spelling | Accept | Ivan's voice rules |
| H1 | HIG | major | Stale "Ready for Your Yes" after approval; clearing other devices impossible over Web Push | Accept | WebKit's userVisibleOnly rule; one status identifier, what is achievable written down, a count of decisions in one body |
| H2 | HIG | major | Sign-in repeated in every Safari, Dock and Home Screen context, two steps each, weekly | Accept | Apple Support 104996; passkey-first return, Google for binding and recovery keeps D14 (spine note) |
| H3 | HIG | major | Phase names hidden from screen readers inside summary | Accept | Measured in the AX tree; hidden prefix and aria-labelledby |
| H4 | HIG | major | Transcript lines as named buttons hide their words; hundreds of Tab stops | Accept | Accessible-name rule; timestamp buttons with roving tabindex |
| H5 | HIG | major | Drag-only calendar; Calendar missing on iPhone | Accept | WCAG 2.2 SC 2.5.7 and 03 §2.2 |
| H6 | HIG | minor | Shift+Tab focus lands under the sticky filter | Accept | Measured; scroll-margin on summaries, smaller sticky bar at phone width |
| H7 | HIG | minor | FAQ toggles announce "plus" and "minus" | Accept | Use the roadmap's aria-hidden span pattern |
| H8 | HIG | minor | APP-19 has no icon or shell spec | Accept | Icons from the ultramarine dot, rendered and looked at on real surfaces |
| H9 | HIG | minor | The filter's count is hidden on phones; ?for=gabriel opens 42 screens | Accept | Merged with G7 |
| H10 | HIG | minor | The filled dot means Done, Now and "Serenity's condition" | Accept | One mapping per page, stated in each key |
| H11 | HIG | minor | Notification copy breaks the page's own rules | Accept-modified | Conflict 12: "Keep as B-Roll" stays (Gabriel's word); the rest as given |
| H12 | HIG | minor | "Approve and Publish" names a result that is a schedule | Accept | 03 C8; "Approve for the Feed" with the Goes live line under it |
| H13 | HIG | minor | Increased-contrast variant barely changes anything | Accept | 03 §2.1; ratios recomputed |
| H14 | HIG | minor | Privacy link hidden on phones | Accept | It answers Serenity's conditions; fits at 390 per the measurement |
| H15 | HIG | minor | SCOPE §9.1 #1 and §7.15 describe a world the page no longer matches | Accept | CLAUDE.md rule: separate current state from intent |
| H16 | HIG | minor | No branding spec for the real Google button; the CSP blocks a remote mark | Accept | Google's branding guidelines; mark served from /assets/ |
| E1 | Engineer | blocker | Round 1 E15 not implemented: Phase 1 order 1 holds 16 rows for about 12 booked hours; the roadmap promises more than PLAN | Accept-modified | Conflict 2. Shortest safe path kept, episode 1 stays Fri 23 Oct, review by private link or call, app pieces by Mon 26 Oct; the RedCircle part follows conflict 1 |
| E2 | Engineer | blocker | Stage 11 sends raw transcript text to Haiku before names and redaction | Accept | Verified in §7.4; breaks PR-12 and the front-door promise. Stage 11 local; every cloud call after stage 15; the adapter checks the data, not the order |
| E3 | Engineer | blocker | Hybrid MP4 "finished" is undefined; the crash path ships truncated audio; no supersede rule | Accept | 02 l.229-233. Fixtures from the studio visit; an unclean stop is a Needs a decision; new version voids approvals; NSFileCoordinator and clonefile |
| E4 | Engineer | blocker | The feed Worker reads D1 across Cloudflare accounts, which is impossible | Accept | Verified in §12.1. Single publisher writes the bucket; spine D9 note; owner actions dated |
| E5 | Engineer | blocker | No path for Claude's results in the engine contract; no event ordering; no protocol version | Accept | Verified in §6.4; three rows before engine code |
| E6 | Engineer | major | KeepAlive makes Quit do nothing; agent and login item APIs mixed; who raises permission prompts | Accept | 02 l.297-300, l.331-333; plist written out, prompts raised by the nested process at setup |
| E7 | Engineer | major | No timeouts or crash-loop guard; "stuck" undefined | Accept | D13 promises autonomy you can trust; limits and a §19 test |
| E8 | Engineer | major | Worker PUT breaks above about 104 minutes; Workers plan unknown; immutability unenforced | Accept | 07 l.407-411. Multipart through the binding from Phase 1, R2 checks integrity, conditional put; Workers Paid confirmed before Phase 0 routes deploy |
| E9 | Engineer | major | Disk arithmetic does not add up with the partial download kept | Accept | Merged with C5; df confirms about 812 GiB free with it on disk |
| E10 | Engineer | major | "Ivan labels by hand" has no tool, no time budget, no post-render check; 30 seconds vs 2 to 3 minutes | Accept | Merged with C7; conflict 6 for the date |
| E11 | Engineer | major | D1 keys receipts by recording, not piece; no manifests, ai_jobs or speaker_labels tables | Accept | PIP-34 makes several pieces per recording; Batch needs custom_id |
| E12 | Engineer | major | YouTube connection gaps: unverified warning, Internal only in the owner's Workspace, ownership, connect binding, session-URI auth | Accept | Merged with C14; 06 l.187-191; session-URI auth tested on Ivan's channel |
| E13 | Engineer | major | A laptop crash goes unnoticed for 12 hours | Accept | The design already tells sleep from silence |
| E14 | Engineer | major | RSS: new-feed-url belongs in the old feed; GUIDs; immutable enclosures; Live read-back | Accept | Merged into conflict 1 and E4 |
| E15 | Engineer | minor | No http to https redirect | Accept | Measured on two live hosts; Ivan's web security baseline |
| E16 | Engineer | minor | Stage 15's coverage check is a tautology, like round 1's stage 9 | Accept | Same reasoning as round 1 E1 |
| E17 | Engineer | minor | No provider-side spend limit or billing alerts | Accept | 07 l.459-461 security baseline |
| E18 | Engineer | minor | NSBackgroundActivityScheduler will not run multi-hour archive batches reliably | Accept | 02 l.328-330 |
| E19 | Engineer | minor | Presigned R2 media links widen the CSP and leak like bearer tokens | Accept | Same-origin through the Worker keeps the CSP at 'self' |
| E20 | Engineer | minor | Roadmap still says "at night" and "10 files pass" | Accept | Round 1 C11 and C5 never reached the page; merged with C6 and C21 |
| C1 | COO | blocker | The 25 probably cannot come from Gabriel-only talks; reset waits to Mon 26 Oct; segments never explained | Accept | Merged with G2; three numbers in the Fri 9 Oct count, the segment rule in plain words |
| C2 | COO | blocker | No answer means Gabriel uploads every episode; feed setup has no owners; owners differ across documents | Accept-modified | Conflict 1: podcast-only domain and owners accepted; Transistor as a no-answer default rejected (money never defaults) |
| C3 | COO | blocker | Episode 1 waits for Serenity's look a day before she can sign in, with no fallback | Accept | Conflict 5; "needs nobody else's answer" corrected in all four places |
| C4 | COO | major | Build sessions end Fri 23 Oct and were never sized; Phase 2 has none | Accept | Ivan books sessions through Fri 6 Nov by Fri 9 Oct; Sonny sizes Phase 1 and 2 and writes what drops |
| C5 | COO | major | "Fits on Ivan's Mac" is wrong once unzipping and the kept partial download are counted; the RAID is unscheduled | Accept | Merged with E9: external SSD recommended by Mon 12 Oct, part-by-part extraction, a dated RAID build day |
| C6 | COO | major | The talk sample that releases Gabriel's talks includes a Serenity solo talk | Accept | Re-couples the 25 to her consent (round 1 S4). Split the gate by teacher |
| C7 | COO | major | Without his voice clip, nobody counted Ivan's hand-labelling hours | Accept | Conflict 6 |
| C8 | COO | major | The account holder is a single point of failure; Studio steps unowned; re-run due the day the owner is named | Accept | Managers added; re-run Wed 14 Oct with a written method; skipped if the count shows the talks are already salvaged |
| C9 | COO | major | 19 of 67 questions fall on Fri 23 Oct | Accept-modified | Conflict 9; Serenity's set moves to Fri 30 Oct (conflict 3), not kept on Fri 23 Oct |
| C10 | COO | major | Two 20-minute sessions cannot approve 18 talks | Accept | Conflict 7 |
| C11 | COO | major | The travel fallback cannot work by its own dates; nights booked after the work starts | Accept-modified | Certificate by Fri 16 Oct; nights booked by Fri 16 Oct for Mon 19 to Thu 22 Oct; the studio-Mac fallback counts only once a notarized build has launched there, so it is not added to an already full Phase 0 exit check |
| C12 | COO | major | Six spine corrections wait with no date while the spine wins | Accept | Ivan row Fri 9 Oct; round 2's additions join the list |
| C13 | COO | major | A hand-made episode 1 could ship a week earlier | Accept-modified | Conflict 2: the by-hand fallback and dropping the trailer are kept; the Mon 19 Oct date is rejected |
| C14 | COO | major | Creating the YouTube project in Ivan's account rules out the Internal route | Accept | Merged with E12; one line added to Q-GS7 |
| C15 | COO | major | Home Screen and notifications asked before Web Push exists | Accept | Round 1 conflict 7 never reached the page; "Notices come by email for now" |
| C16 | COO | major | "Every new studio session" contradicts the student rule | Accept | Merged with S2 |
| C17 | COO | minor | The cost check after ten recordings cannot come before the archive run | Accept | A ten-talk pilot batch checked against Anthropic's usage page |
| C18 | COO | minor | A release slot has no time | Accept | New Q-I20 for Ivan, Fri 16 Oct |
| C19 | COO | minor | Lawyer work dated before the decision to hire one | Accept | Conflict 8 |
| C20 | COO | minor | The Fri 9 Oct messages link to pages not yet live; pre-deploy steps undated | Accept | One dated row in order; messages go without links if a step misses |
| C21 | COO | minor | Nine cross-document disagreements | Accept-modified | All aligned to PLAN except item d, rejected by conflict 10 (D2 says Ivan and Gabriel) |
| C22 | COO | minor | The only routine human step is never measured | Accept | The weekly note lists sessions with no test clip before them; PIP-29 can retire it in Phase 3 |

**Totals:** 127 findings, 0 rejected outright. 24 were accepted with a modification, and in seven of
those a specific part was rejected with its reason: Transistor as a no-answer default (C2, money
never defaults); a Mon 19 Oct episode 1 (C13); Ivan alone choosing the always-on Mac (C21 d, D2);
quoting Google's consent wording before it is seen (S8); "Keep as Video Only" (H11, Gabriel's own
word); Fri 16 Oct for the lawyer (S16); and Serenity's privacy set on Fri 23 Oct (C9).

### Were round 1's accepted items implemented?

Mostly. Not on the page yet, and now carried as round 2 tasks: daytime archive runs (round 1 C11;
E20, C21), the talk-only sample gate (round 1 C5; C6), Web Push timing on the roadmap (round 1
conflict 7; C15), the Phase 1 cut (round 1 E15; E1), the front-page length (round 1 B14; B10), the
spoken per-episode intro as a later option (round 1 G19; G12), and duplicate approval lines (round 1
G11; G8).

### What changed

#### Site: web/public and web/src (site implementer, Thu 8 Oct 2026)

Nothing deployed, committed or sent; `wrangler.jsonc` untouched. Every weekday on the three pages was
recomputed with `date -j -f %Y-%m-%d <date> +%a`: 204 date mentions, 29 distinct dates, 0
mismatches (the weekdays the roadmap script prints are computed from the ISO date, never typed). Grep
of `web/public` and `web/src`: 0 em dashes, 0 "lane", no British spellings left (labeled, recognize,
authorize, color, gray, behavior in the stylesheet comments too). "Yoga Mārga" kept where it names
the channel.

**Front page (`index.html`)**
- Hero and meta description carry the new sentence (B2, S24, G8); status line kept; second hero fact
  replaced (S2, C16, B6, S13); sign-in card "Sign-in opens by Monday 26 October" and "Then confirm it
  is you with a passkey." (E1, H2). The card keeps round 1's single disabled Google button.
- Body copy as given (S9, B5, B7, B16, B17, B18, B19, S22, G15): step 2's silent-recording line, step
  3's "cut, and a person checks", step 4's plain mono line, "status:" dropped from steps 5 and 6, the
  test-recording routine in the intro, "Names it finds are muted." with the queued-moments body,
  labeling "Serenity, once she agrees", the VeraSales line, the transcript and voice-recording rows,
  the one-download line with Gabriel's own transcripts, and the Apple Podcasts, Spotify and YouTube
  sentence in What comes next.
- Privacy cards and FAQ (S13, B1, S10, B9, S23, G8, B10, H7): the new Who approves card; "While
  episodes are uploaded by hand, Ivan takes one down by hand, at once." (the pause-lifting rule is not
  on this page); "What do Gabriel and Serenity have to do?" first; "Could something be posted by
  accident?" deleted; the AI FAQ opens "No." and is the page's one full AI rule. FAQ toggles are an
  aria-hidden span; Chrome's accessibility tree shows all eight names ending at the question mark.
- Length (B10): the two autonomy lists now sit directly under the yes line, in the step text column,
  with the publish-unless-stopped note once after step 6; Notifications is one sentence in step 5
  plus the FAQ "What will notifications never show?" (which also says notices come by email until
  after Fri 6 Nov); Where things run is the FAQ "Where does the work happen?" with its four rows. To
  reach the target I also: dropped the notification specimen (it did not fit), folded "Older
  recordings say when" into the accuracy card, set the outputs in two columns from 1000px wide,
  tightened section and list spacing, and removed the dates that What comes next repeated from the
  hero. **Measured heights, before and after:** 1440: 9,287 to 7,202px (target about 7,000; 3% over,
  I stopped there rather than cut more copy); 768: 10,041 to 8,536; 390: 13,292 to 11,375. Light and
  dark are the same height.

**Roadmap (`roadmap.html`, `assets/roadmap.js`)**
- Hero, status, goals (G20, G14, E20, C21, G2, S9, S13, B6, H10): "every step for Prakriti"; the
  archive row's transcription sentence, and its "about 388 GB, it fits on Ivan's Mac" removed (C5);
  sign-in row "Ready by Mon 26 Oct"; the deploy comment above the front-page row; tiles and note as
  given; the five-numbers lead. Marks, stated once in the key: filled dot Done, ultramarine ring Now,
  half dot Next or proposed, hollow ring Planned or not started, diamond Waiting on a person.
  "Serenity's condition" has no mark, and the phase counts lost their dot.
- Since the 7 Oct page (B13, S23, G9, C3): the given lines and five additions. Three of the additions
  came with no reason and have none, rather than an invented one. The managers line now says Gabriel
  and Ivan are added as managers, since the old "instead of adding Ivan as a manager" had gone stale.
- Phases 0 to 3 (G6, G10, G13, C8, B7, B14, E1, C3, C15, G3, G11, S4, S10, E20, C21, C6, C10, S19,
  G17, G1, S14, G5, S8, G19, G12): every row as given; "Done when" six times; the trailer and its
  rows gone; the two account-holder rows merged into one sitting; Serenity out of the sessions row.
  Two small additions to keep the page true: Ivan's Fri 9 Oct message row says Gabriel's carries the
  count, and Phase 2's release line says Gabriel's talks wait for his samples and Serenity's for hers.
- Decisions (G2, G4, C2, G13, B11, B12, B22, G5, E10, C7, G16, G18, B15, B4, S18, B8, S20, S3, B1,
  S17, S21, S4, S5, S19, G1, S16, B20, C18, S12, C19, C11, E9, B3, S7): all as given. Serenity sees
  four questions, then one collapsed group "Each has a safe setting until you answer (21)". Each of
  her questions carries a concrete most-private "Until you answer" (for example "none of your teaching
  goes to Claude", "Prakriti touches neither", "nothing is booked for you"). The full AI rule appears
  once, in the Never list (`id="ai-rule"`); everywhere else says "under the AI rule".
- The filter (G7, H9): choosing a name renders that person's dated list at the top (This week, Later,
  No date yet, each linked to its row), folds everyone else's rows behind one "Show everyone's (N)"
  button per phase and per decision group (`aria-expanded`), and writes "Gabriel: 10 asks due by
  Fri 16 Oct. Next: ..., Fri 9 Oct.". Rows for the account holder (`data-who="holder"`: the takeout,
  the one-sitting row in Phase 2 and its decision; three rows, since task 9 merged consent and dubbing)
  show to Gabriel and Serenity under "If you hold the school's Google account" and count for neither.
  Counting stays by `data-ask`. Phases no longer open themselves when a name is chosen; the list
  replaces that. A link to a folded row unfolds it and scrolls to it. **Heights with ?for=gabriel:**
  1440: 23,939 to 15,563px; 390: 35,659 to 22,890px. Without a name: 1440 17,020 to 15,877 (the
  whole page now fits one capture), 768 18,438 to 17,663, 390 25,717 to 23,996.

**Accessibility and CSS (H3, H6, H13, H14, B23)**
- Each phase `details` is named by its `.ph-name` id, and every phase h4 has a hidden "Phase N, "
  prefix; the Chrome tree with all phases open shows groups "Phase 0: Ground" to "Phase 5: Later" and
  headings such as "Phase 1, Done when". The collapsed Serenity group is named too.
- Scroll margins: the given rule is in, but at 124px rather than 112px on desktop, because the longer
  count line makes the filter bar 105px tall at 1440 and 768 (95px at 390, where I read "130px" as
  130px under the top bar). Shift+Tab probe through the filter area, every phase open, with and
  without ?for=gabriel, at 390 and 1440: 0 of 51 focus stops hidden. Anchors #decisions,
  #for-gabriel, #for-serenity, #phase-1 and two row links land below the bars at both widths.
- At 600px and under, the "What's needed from" label is gone (its words are the radiogroup's
  `aria-label`) and the count shows as 13px text under the segments, on one line with an ellipsis
  (the full list sits just below).
- Increased contrast: secondary inks #2E3036 light (11.86 / 13.19 / 10.91) and #D4D5CF dark
  (12.79 / 11.90 / 13.26), control edges and hairlines take that ink, and the disabled button has an
  edge. Rendered in both themes and looked at.
- Nav: Privacy stays on phones, How It Works hides; at 375 and 390, no overflow, targets 49x46 and
  45x46px. Smallest rendered text on every page: 12px.
- Wordmark: both fixes rendered at 2x in light and dark. Kept `margin-left: 0.03em` on the hero's
  dot letter: it opens a clear gap between the k's and r's foot serifs. The looser -0.025em word still
  touched there and pushed the intro under the mark at 1440.

**Worker (`src/index.js`, E15)**
- Plain http to any host other than localhost, 127.0.0.1 or [::1] gets a 301 to the same address on
  https, through the same security-header wrapper, with no HSTS. **One change from the brief, and
  why:** `wrangler dev` rewrites request.url to the route's host (http://prakriti.therowan.studio/),
  so the hostname test alone sent every local request a 301 to itself, an endless loop (measured
  under wrangler 4.148). The redirect therefore also requires Cloudflare's own CF-Ray or CF-Visitor
  header, which only the edge adds. Checked: under `wrangler dev`, / and /roadmap answer 200 over
  http with no HSTS; unknown paths, /src/index.js, /wrangler.jsonc and /404.html answer 404; with a
  CF-Ray header the same request gets the 301 with every security header; called directly in Node,
  http://prakriti.therowan.studio/roadmap?for=gabriel goes to the https address with its query kept.
- **Smoke check after deploy:** `curl -sI http://prakriti.therowan.studio/` must return 301 with a
  Location on https. If it returns 200, the edge is not passing CF-Ray to the Worker, and the test
  needs another signal before the page is called done.

**Renders and one open item**
- Renders in `screens/r2-site/`: index, roadmap and 404 at 390, 768 and 1440, light and dark (full
  page), roadmap with ?for=gabriel at 390 and 1440, and index and roadmap at 375. No console errors,
  failed loads or sideways scroll in any of them. Through the local Worker (index, roadmap with a
  name, an unknown deep path) the only logged error was the 404 status of the unknown path itself. The roadmap at
  390 and 768 is taller than the 16,000px capture limit; its lower part (Decisions, Never, closing,
  footer) was checked with separate captures.
- **For Ivan (OPEN):** the lawyer row on Ivan's list says "who pays", with "Suggested: paid by Yoga
  Marga". It names no amount, but the page rule is no money. Recommendation: keep it, since it is a
  question for Ivan and Gabriel and names no sum; move it into PLAN only if you would rather the
  page never mention paying.

#### Docs: PLAN.md, docs/SCOPE.md, README.md, START_HERE.md, CHANGELOG.md (docs implementer, Thu 8 Oct 2026)

Nothing deployed, committed or sent; `research/DECISIONS.md` and `.gitignore` untouched; `web/` not
touched. Every weekday was checked with `date -j -f %Y-%m-%d <date> +%a` (37 distinct dates, 0
wrong). Zero em dashes in all five files. American spelling throughout (labeled, recognize,
authorize, catalog, finalized, honor and the rest); the AI rule, the student rule and the approvals
rule are word for word as in round 1 apart from "labelled" becoming "labeled".

- **PLAN.md** (rewritten throughout):
  - The 25: counted on the podcast feed from teacher-only talks and their segments; the Fri 9 Oct
    message carries three numbers and any reset; suggested fallback "10 by Fri 6 Nov"; Mon 26 Oct a
    confirmation only; the first metadata screen in row 5's notes only (G2, C1).
  - The privacy-proof gate split by teacher, in the consent gates and the Phase 2 check; the 10-file
    set kept for calibration only (C6).
  - The podcast's home: Q-G2 with Q-G3 merged in, new Q-G26; a podcast-only address held as its own
    zone in Yoga Marga's account; Gabriel's steps dated (domain yes; R2 and Ivan's membership by
    Fri 16 Oct); Ivan does every upload and submission; with no answer the first episode waits;
    Transistor only with Gabriel's yes; row 17 asks RedCircle for `itunes:new-feed-url` or a 301 and
    team access (G3, G4, C2, E4, E14).
  - Phase 1 rewritten as the shortest safe path to Fri 23 Oct: no trailer; Wed 21 Oct pipeline or
    ffmpeg by hand; Serenity's private link Wed 21 Oct with the cut at the end of Thu 22 Oct;
    Gabriel's written yes Thu 22 Oct into the run log; Ivan uploads and reads the feed; order 1 cut
    to the listed items; takedown is Ivan's hand step while uploads are by hand (E1, C13, C15, C3,
    S4, S10, G11).
  - New "Before approvals open (by Mon 26 Oct)" in Phase 2 (sign-in, review page, Pause All
    Publishing, activity log, cost ledger, email notice, invitations by Fri 23 Oct) and "After
    Fri 6 Nov" for the rest of old order 2, with Web Push; "needs nobody else's answer" corrected
    everywhere (E1, C15, C3).
  - Dates and questions moved: Q-G18 and Q-G23 (Q-G10a merged in) to Fri 16 Oct with their
    defaults; Q-G24, Q-G25, Q-GS1, Q-GS8, Q-I8, Q-I14, Q-I16 to Fri 30 Oct; Q-I12 to Fri 23 Oct with
    who pays OPEN; Q-I3 to Fri 16 Oct; nights booked by Fri 16 Oct; the travel fallback; Serenity's
    set to Fri 30 Oct; Q-S4 to Phase 3; Q-S16 and Q-S23 without deadline; Q-G10b requested by
    Fri 16 Oct and never a default yes (C9, G5, C10, C11, S16, C19, S20, conflict 3).
  - New questions with recommended answers: Q-G26, Q-G27, Q-S24 to Q-S27 (Q-S26 replaces Q-S19),
    Q-I20 to Q-I22; Q-I17, Q-GS4, Q-S18, Q-S7, Q-S10 and Q-S12 revised (G1, S5, S19, C18, S12, S3,
    E9, C5, S21, S17, S11).
  - The next few days: rows 21 to 24 (pre-deploy sequence, DECISIONS v2, build sessions, weekly
    call); the studio visit adds the vertical output and the MP4 box-tree fixtures; the re-run on
    Wed 14 Oct with its method; Q-GS7 adds the Workspace and Managers; the YouTube project inside a
    Workspace if one exists; Ivan's Workers Paid, Anthropic workspace and billing alerts; Q-G5 dated
    Sun 18 Oct; Q-G11 and Q-G15 asked privately; the RAID build day; the weekly note counts sessions
    with no test clip (G6, G10, C4, C8, C12, C14, C20, E8, E17, G16, G20, C22).
  - Phases 2 and 3: Gabriel's five approval sessions; the ten-talk pilot replaces "after the first
    ten recordings"; Q-I1, Q-I3 and Q-I5 split into three rows; APP-10 renamed "Recordings library
    (browse)"; the terms row Fri 23 Oct; the per-episode intro; the website redesign named as
    separate; hand-labeling hours left OPEN until measured; the machine-time budget and 100 GB floor;
    the drive in run costs; round 2's spine corrections; "Since the 7 Oct page" (C10, C17, C21, G12,
    G17, G18, E10, C7, S19, G9).
- **docs/SCOPE.md:**
  - Engine and cloud: stage 11 local, every cloud call after stage 15 with the adapter's assertion,
    stage 15 checked against stages 9 and 14; "finished" for Hybrid MP4 from fixtures, an unclean
    stop as a Needs a decision, new versions void approvals, `NSFileCoordinator` and `clonefile`;
    §6.4's editorial endpoint, event order and protocol header; §7.2's written plist, Quit, prompts,
    the archive queue on AC power, timeouts and the crash-loop guard; FM-21a timings; §10.1 keyed by
    piece and version, with `manifests`, `ai_jobs` and `speaker_labels` (E2, E3, E5, E6, E7, E11,
    E13, E16, E18).
  - Uploads, feed, YouTube, media: Ivan's Worker as the only feed publisher with a conditional put,
    `takedowns.json`, `<guid>/v<n>.mp3`, `new-feed-url` in the old feed, GUIDs imported as they are;
    multipart through the Worker from Phase 1 (no presigned links); review media same-origin at
    `/media/<artifact id>`; the YouTube project, connect link, channel check and no-delete rule
    (PR-26); spend limits and billing alerts (E4, E8, E12, E14, E17, E19, C14, S8).
  - Privacy: the name scrubber before any flip and the automatic-caption check; Other voice only at
    the engine Mac (Q-I22); "To See" and Serenity as a required viewer; own-life passages (PR-6);
    Serenity's items on metadata only until Q-S13 is Granted; the re-run never extracted into a
    watched folder; class transcripts keep Other voice as timecodes only; segment inheritance
    (PR-27); consents Granted only from the teacher's account; the voice-reference store kept off
    backups and synced keychains; §11.9 and §18 regenerated from PLAN's table, so every "Until you
    answer" matches word for word (S1, S3, S4, S5, S6, S7, S11, S12, S14, S15, S17, S25).
  - Interface and disk: one status identifier with what Web Push can really clear, the decision
    count, the copy fixes; passkey-first sign-in; one sign-in per app context; transcript paragraphs
    as text with timestamp buttons; "Schedule..." by keyboard and tap; APP-19's manifest and icons;
    the review screen's safe area; "Approve for the Feed"; §9.1 #1 as current state; §7.15; the
    disk budget and the external SSD; the hand-label screen (H1, H2, H4, H5, H8, H11, H12, H15, H16,
    E9, E10, C5).
- **README.md:** the "catalog" sentence cut; the private-calls and "never uploads" wording; status
  and asks per the shared facts (episode 1 Fri 23 Oct with no trailer, sign-in by Mon 26 Oct,
  notices by email until after Fri 6 Nov, Ivan does every upload, each person's review figure); a
  line that classes wait for Serenity's rule (S2, C16, B24, G3, C15, S13).
- **START_HERE.md:** warnings 19 to 26, each with its reason (cloud calls after stage 15; Hybrid MP4
  fixtures; one feed publisher; no YouTube delete call; the re-run never in a watched folder; the
  100 GB floor; the http-to-https 301 check; the 16,000px capture cap); the pre-deploy sequence; the
  live 301 check; current-state lines that match PLAN (E2, E3, E4, S8, S7, E9, E15).
- **CHANGELOG.md:** a new top entry for round 2, why first: six lenses, 127 findings, 0 rejected
  outright, 24 accepted with a modification, the seven rejected parts, the top changes, and a
  pointer here.

**Not done, or done with a flag, and why:**

- **§9.1 #1 was written while `web/public/index.html` was still being edited** by the site
  implementer, so it lists the sections as they stood and says the page wins wherever they differ.
- **Costs left unpriced on purpose:** the external SSD, the podcast-only address and the Workers
  Paid plan say "cost to price" or "to confirm"; no number was invented.
- **Ivan's hand-labeling hours stay OPEN** until Sonny measures the minutes per talk on 09-06.
- **Google's consent wording is not quoted anywhere,** because nobody has seen the screen yet.
- **Sonny's additions for Ivan to confirm:** Q-S27's "Until you answer" (nothing is put on her
  calendar), which the task did not specify; the line that take down in one step (PRV-12) and the
  YouTube tests (SET-13) land before their first use whatever the sizing; and Q-G7 reworded per B11
  ("one ask, the same every episode, in your words; no answer means no ask"), so PLAN matches the
  roadmap.
- **The RAID build day has no date yet**, only "before Mon 9 Nov"; the day is Ivan's and Gabriel's.


---

## Round 3

Reviewed Thu 8 Oct 2026, after the round 2 changes: `docs/SCOPE.md`, `PLAN.md`, `START_HERE.md`,
`README.md`, `web/public/index.html`, `web/public/roadmap.html`, `web/public/assets/*`,
`web/src/index.js`. Finding IDs restart in this round. Every weekday below was computed with
`date(1)`.

Five facts were checked by the reasoner before deciding, because whole findings rest on them:

- **The Sun 6 Sep talk has more money in it than the page says.** A read of
  `Studio Recordings /2026-09-06/2026-09-06 18-06-33.txt` (positions only, nothing quoted here):
  an income claim about Gabriel's own results in the opening line, a second one about a third of the
  way in, a statement about earning five figures a month, a statement about what he spent on coaches,
  a spoken offer with a "click here" near the end, and one story about a student in the community
  and a fundraiser goal. The page's "One income claim" is wrong (G1, B3).
- **The same transcript names Serenity as "my partner" with a misheard name** in its first minutes,
  and twice more by name. The hold on passages that name her must catch "my partner" (S18).
- **The school's email runs on Google Workspace.** `dig MX yogamarga.school` returns
  aspmx.l.google.com and four alternates; the SPF record includes `_spf.google.com` (G12).
- **Ivan's Apple team ID is LD587PB2H8.** K55TBYNKUC is the certificate's identifier
  (07 l.509-511); 02 l.751 has it wrong (E17).
- **US daylight time ends on Sun 1 Nov 2026.** `date(1)`: Sat 31 Oct is PDT, Mon 2 Nov is PST, in
  the middle of the one-a-day release window (E15).
- Also confirmed by reading: on the front page the yes line sits above the "On its own" list (B1);
  Gabriel's Cloudflare account runs VeraSales production (07 l.355) (E14, C7); VeraSales'
  `models.js` sends `{type:'disabled'}` for Sonnet 5.5 and `workflow.js` carries the retries guard
  (E10); "under 2 minutes per piece" first appears in `research/09-ideas.md` l.71 as a proposal, not
  in anything Gabriel said (G6); PLAN l.447 has Sonny drafting Serenity's assessment from
  transcripts (S2). Sonny is Claude, so that is a cloud call on her teaching.

### The six verdicts

- **Gabriel:** he would understand Prakriti in one visit and most of round 2 landed, but the road to
  episode 1 has three ordering faults (his yes voided by Serenity's window, the intro recorded before
  the show name, a hidden storage sitting), and the pages misstate his talk, his goal and his 25.
- **Serenity:** she would recognize her conditions, but the listening check has no named listener or
  time for the 25, names are muted with no list while 18 go out, Sonny (Claude) would read her
  teaching, and several places still decide things for her.
- **Brand and copy:** the identity holds and there are no em dashes, but the yes-line diagram
  contradicts itself, both heroes state proposed numbers as facts, the accuracy demo miscounts, and
  money still shows on the page Serenity reads.
- **HIG and accessibility:** the pages pass every measurable check; the serious gaps are in SCOPE's
  Mon 26 Oct to Fri 6 Nov window: no "not yet", no way to reach archive pieces, email with no copy
  rules, and notices that will flood.
- **Engineer:** the shape is right and `index.js` is sound, but the build still does not fit the
  booked hours, episode 1's approval voids itself, the consent rules block Gabriel's own clip, and
  several reliability claims rest on R2 features or alerts that are not there in time.
- **COO completeness:** coverage is complete and every weekday checks, but the pages promise 25
  against about 5 qualifying talks, the privacy promise rules out the plan's own fallback, about 100
  features sit in 24 hours of sessions, and Thu 22 to Fri 23 Oct rests on Ivan alone.

### Conflicts between critics, and how they were resolved

1. **What the build can carry by Fri 6 Nov (E1, C3 against C8, E9, C16, H2).** One written cut line,
   made by Sonny on Fri 9 Oct before the two messages go out. Above it: the watcher as a login item
   with Ivan's three-moment native notification (Ivan's 10-08 request, so E1's "CLI tools Sonny runs
   in sessions" is rejected: a session-run tool is not autonomous); readiness and the sound check;
   transcription, labels, name muting and mastering for the podcast; the post-render check; Ivan's
   release script (render the feed, check the manifest, put the file, read it back); Up Next's sign-in
   as is; one review page with Approve tied to the manifest, a "Not Yet..." note and Keep / Cut /
   Add a Note on accuracy items; Pause All Publishing; take down in one step; one email per approval
   session; the heartbeat with a quiet-engine email, a report-only daily sweep and database backups.
   Below it, after Fri 6 Nov: every YouTube API task, Web Push, Prakriti's own release slots, the
   Settings window, Today and Recordings, Ask for Changes proper, chapters, and the consent screens.
   H2's separate list screen is not built: the session email lists every piece instead. If the set
   above the line still does not fit, Ivan books more sessions or resets the number on Fri 9 Oct.
2. **The 25 on the public pages (G5, B2, C1, G9, C2, S3).** Both heroes say "proposed", say the 25
   are podcast episodes, and say Ivan confirms the number with Gabriel on Fri 9 Oct; if the count is in
   before the pages go live, the counted number replaces it in every place the same day. The hero
   drops the 2-minute clause for one sentence on who uploads (G9). "New studio talks follow as they
   are recorded" is cut, because nothing usable has been recorded since Wed 23 Sep (B2). The fallback
   loses "or class stretches" (C2).
3. **Archive talks on YouTube (G5 against C3, E1, C14).** Gabriel's word was videos, but the build
   cannot carry the YouTube work before Fri 6 Nov and no Zoom-era frame has been checked. The 25 stay
   podcast episodes. The Mon 26 Oct shortlist reports how many shortlisted videos show and sound
   teachers only, so the video half gets a number; YouTube publishing of archive talks starts after
   Fri 6 Nov at up to two a day. The account holder's sitting moves to the week of Mon 26 Oct, and the
   YouTube tests run there through the production project (E13, C6). Spine correction below.
4. **Episode 1's two yeses (G2, E2, S13).** Two versions are rendered on Wed 21 Oct, one with the
   passage that names Serenity and one without; the post-render check and Ivan's listen run on both;
   Gabriel approves both in one written yes on Thu 22 Oct; Serenity's reply, or her silence by the end
   of Thu 22 Oct, picks which goes out. Serenity hears the passages and sees the draft show description
   at her first meeting, so the Wed 21 to Thu 22 Oct window is only for the finished file.
5. **Who listens, and Gabriel's 2 minutes (S1, C4, G6).** Ivan listens at the queued moments of every
   archive piece before it reaches its approver, logged with who and when; his time is measured on the
   Sun 6 Sep talk first and budgeted from that measurement, not from a guess. Gabriel's figure becomes
   "Proposed: under 2 minutes of your time per piece, after Ivan's listen", and it is his goal only if
   he says yes. S1's "Approve stays disabled until every moment is played" applies to Ivan's listen
   step, not to Gabriel's Approve.
6. **Students who were present but silent (S3, C2, S5, S8).** "Teacher-only" is defined once: no other
   voice heard, no student named, described or answered. Whether a session where students listened
   but did not speak may be used is Serenity's call (new Q-S30, asked at the first meeting, needed
   Fri 16 Oct). Until she answers, nothing from a session where students were present goes public, so
   the Fri 9 Oct count carries two numbers: without such sessions, and with them. The name list
   (Q-S11a) moves to the same date. S5's Q-S24 suggestion ("Not yet") replaces round 2's suggested
   yes, because round 2's yes would have made the front page's own promise false; this is a change to
   round 2 conflict 4 on new evidence, not a reversal without reason. S8's rule (any piece in which an
   Other voice was found needs Serenity's receipt) is adopted.
7. **Serenity's meetings (C10 against S2, S3, S13).** Two meetings. The first, in the week of
   Mon 12 Oct: the first look, the episode 1 passages and show description, and three questions
   needed by Fri 16 Oct (names list, students who only listened, Claude including Sonny). The second,
   30 minutes on Tue 27 Oct after the fuller assessment, as she asked on 1 Oct (A-12): the rest of her
   privacy set, needed by Fri 30 Oct, including her own publishing consent (S6).
8. **Where the podcast's account lives (G4 against E14, C7).** Not Gabriel's existing account, which
   runs VeraSales production. A new Cloudflare account registered to a Yoga Marga address (the school's
   contact address, or Gabriel's own Yoga Marga address if he has one: to confirm), Gabriel as owner,
   Serenity and Ivan as members, created at the studio visit in the same sitting as his yes to the
   podcast address cost. G4's dated row and "Without it, the first episode waits" are kept; the feed is
   ready Tue 20 Oct, not on upload day.
9. **Invitations (G13 against C6).** Sent the morning sign-in opens, by Mon 26 Oct, with the accept
   row the same day. That also takes them off Ivan's Fri 23 Oct.
10. **Instagram (G9 against B21).** OPEN for Gabriel (new Q-G29), recommended: Instagram waits for
    Phase 5 and nothing is asked of him there. The Phase 3 file-and-caption handoff becomes optional.
11. **Consent before the consent screen exists (E3 against C13).** Until the "Your consents" screen
    lands after Fri 6 Nov, a teacher's written yes sent from that teacher's own email address counts
    as Granted for that teacher's own uses, recorded by Ivan with the message reference; Ivan's word
    alone never does. This lets Gabriel's voice clip, his Claude use and a Fri 30 Oct yes from
    Serenity take effect before Fri 6 Nov, without building another screen.
12. **Release plan (C9 against the round 2 suggestion, and C14 b).** The first approved archive
    episode goes out alone the morning after its approval; a takedown is tested on a separate test
    feed, never a throwaway episode in the real one; then 18 are live by Fri 30 Oct and one a day after.
    Ivan publishes every episode through Fri 6 Nov, by hand for episode 1 and then with his release
    script, so C14 b's "Prakriti publishes from Fri 30 Oct" is replaced by E1's. For a count of 10:
    3 by Fri 30 Oct, then one a day Sat 31 Oct to Fri 6 Nov (C1).
13. **Serenity's trust paragraph (B7 against S4).** S4's wording, because it promises the check and
    not more: separate tracks only for new studio recordings; for episode 1 and the archive, cutting
    what is uncertain and Ivan's listen, "a check, not a guarantee".
14. **Money on the page (B8, S7).** The terms rows, the Phase 3 terms gate and "who pays" move to
    PLAN (D15). The lawyer question moves to For you both without payment, and adds that each teacher
    may have their voice consent read by their own lawyer. The certificate row leaves the page.
    This closes round 2's OPEN item for Ivan with a recommendation, not a silent decision.

### Spine corrections pending (round 3 additions; DECISIONS.md is still not edited)

These join rounds 1 and 2. They no longer hold up the Fri 9 Oct messages (C12): DECISIONS v2 follows
by Mon 12 Oct, before the first build session.

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

### Every finding

| ID | Lens | Severity | Finding | Decision | Reason |
|---|---|---|---|---|---|
| G1 | Gabriel | major | The page shows one income claim in the Sun 6 Sep talk; there are more, plus a retold student story, and "cut with no answer" silently removes the opening line | Accept | Confirmed in the transcript (above). Merged with B3. Counts on the page, never quotes (DECISIONS design direction); every money statement with its time goes in the private Fri 9 Oct message; one question covers all; the student story is shown as cut until Serenity answers |
| G2 | Gabriel | major | His Thu 22 Oct yes is voided if Serenity's window cuts her passage | Accept | Conflict 4: two versions, one written yes for both, her answer picks. Merged with E2 |
| G3 | Gabriel | major | The intro is recorded before the show name and listener ask exist | Accept | Both asked in the Fri 9 Oct message, due the day before the studio visit; Ivan brings suggestions; name and ask recorded as separate one-line takes so either can change |
| G4 | Gabriel | major | The domain-cost yes and the storage sitting are missing from his dated list | Accept-modified | Conflict 8: dated row at the studio visit, in a new Yoga Marga Cloudflare account, not his VeraSales one; feed ready Tue 20 Oct |
| G5 | Gabriel | major | The 25 quietly changed from videos to podcast episodes, with no number for the video half | Accept-modified | Conflict 3: heroes say podcast episodes and "proposed"; the Mon 26 Oct shortlist reports the teacher-only video count; YouTube publishing after Fri 6 Nov; a "Done when" line for the count, not for publishing |
| G6 | Gabriel | major | "Under 2 minutes" is labeled his goal; he never said it | Accept | 09-ideas l.71 proposed it. Relabeled "Proposed" everywhere and put in his Fri 9 Oct numbers question (conflict 5) |
| G7 | Gabriel | major | He asked for the whole-archive analysis; only Serenity gets it | Accept | T1007 l.95. Serenity first, as she asked, then Gabriel by Mon 26 Oct with a one-paragraph summary; built from counts until Q-S13 (S2) |
| G8 | Gabriel | major | Round 1's single digits through Fri 16 Oct never happened; the page prints 10 | Accept | Round 1 G2. One "yes to the suggestions" reply covers rows with a suggestion; separate asks only for consent, money and creative calls; the duplicate release row goes. Merged with H13 and B9's word "asks" |
| G9 | Gabriel | major | The front page never says, where he will see it, who uploads | Accept-modified | One hero sentence: you record and say yes; Ivan uploads and checks it is live. Instagram handled by B21 (conflict 10) |
| G10 | Gabriel | major | "Live" Fri 23 Oct does not mean findable; submission is undated and review time unknown | Accept-modified | Submitted the same hour; Ivan checks Apple's and Spotify's listing time by Mon 12 Oct; page says it appears after their review. Rejected parts: a day-one share link (no such page exists and a show page is new scope) and holding the 18 if not listed (no privacy gain, and the 25 is counted on the feed) |
| G11 | Gabriel | minor | He is asked to agree to the numbers the day he first sees the count | Accept | Due Mon 12 Oct or at the studio visit, whichever is first |
| G12 | Gabriel | minor | He is asked something public records answer (Workspace) | Accept | MX and SPF checked Thu 8 Oct. Stated as fact; only Serenity confirms the account she holds and who else signs in; off Gabriel's list |
| G13 | Gabriel | minor | Invitations go out before sign-in opens | Accept | Conflict 9: sent the morning sign-in opens, by Mon 26 Oct |
| G14 | Gabriel | minor | The thumbnail-frames question is due after approvals open | Accept-modified | With YouTube after Fri 6 Nov, podcast approvals carry no thumbnails, so the scenario disappears. The question is due Fri 6 Nov, before the first YouTube approval, and sits under "yes to the suggestions" |
| G15 | Gabriel | minor | The two-a-day YouTube cap has no reason | Accept | SCOPE §12.4's reason added ("so the channel does not look like a dump of old uploads"), and the cap is his to change |
| G16 | Gabriel | minor | ElevenLabs was swapped for his own voice without the reason on his list | Accept | DECISIONS fact 8. One line in the Since the 7 Oct list |
| S1 | Serenity | blocker | The privacy listen has no named listener for the 25 and no time budget; "under a minute" cannot hold | Accept-modified | Conflict 5: Ivan listens before the approver, logged; measured on 09-06, then budgeted; D5 to spine corrections. Merged with C4 |
| S2 | Serenity | blocker | Sonny, who is Claude, would draft her assessment from her transcripts | Accept | Q-S13's own default. Counts and categories from a local script until she says yes; Q-S13 names Sonny and is asked at the first meeting, needed Fri 16 Oct |
| S3 | Serenity | blocker | Name muting runs with no student list while the first 18 go out | Accept | Conflict 6: Q-S11a to Fri 16 Oct; until a list or seed list exists, nothing from a session where students were present can be approved; Ivan resets the 25 on that basis; a Zoom-era item with students joins the §19.2 hand count |
| S4 | Serenity | major | Her paragraph says each microphone records on its own track; untrue for everything through Fri 6 Nov | Accept | DECISIONS fact 3. Conflict 13: S4's wording. Merged with B7 |
| S5 | Serenity | major | Q-S24's suggested yes would make the front page's promise false | Accept | Conflict 6: suggestion becomes "Not yet" until class samples pass and the lawyer has read the release; the promise wording names Serenity's rule as the only way it changes |
| S6 | Serenity | major | She is never asked whether her own teaching may be published | Accept | Consent is per use (D5). New Q-S29 at the second meeting, needed Fri 30 Oct; public audio, public video and real-frame thumbnails added to §11.2 |
| S7 | Serenity | major | The ownership suggestion gives the school each teacher's voice data | Accept | The AI rule, the voice permission and 08 §7.4. New suggestion; the lawyer question moves to For you both, with each teacher free to use their own lawyer |
| S8 | Serenity | major | Student protections key on a recording's label, not on what was found | Accept | Any piece in which an Other voice was found needs her receipt; timecodes-only applies to every such recording; the count goes in the Fri 9 Oct message and she is told how many receipts to expect |
| S9 | Serenity | major | Gabriel's release sample is almost all studio audio | Accept | At least three of his Zoom-era archive recordings with students in the session join the sample, student moments as must-reject cases, with the name hand count. Merged with C1's substitute sample |
| S10 | Serenity | major | SCOPE's Q-S16 default misses "Recording Testing" | Accept-modified | SCOPE and §3.3 take the roadmap's default (listed from metadata only, never opened). No date needed: the safe setting holds, and it is asked at the first meeting |
| S11 | Serenity | major | Protections the pages present as built in are still Proposed in SCOPE | Accept | Round 1 S22's pattern. PRV-07, PRV-14, ACC-04, ACC-05, ACC-07 Decided; PRV-14 a hard dependency of PRV-15 |
| S12 | Serenity | major | The Serenity filter shows 39 asks with no safe settings | Accept | Round 2 conflict 3 was undone by the filter. Her real actions and six questions shown; the rest collapsed with each safe setting beside it. Merged with B9 |
| S13 | Serenity | minor | Her episode 1 window is about 40 hours, under her own suggested 48 | Accept | Conflict 4: she hears the passages and the show description at the first meeting; the window is for the finished file, and if the days do not work the version without her passage goes |
| S14 | Serenity | minor | "Until Serenity sets the rule" implies the check on other voices ends | Accept | Line becomes "Anything with voices other than the teachers': Serenity approves its privacy receipt" |
| S15 | Serenity | minor | The "What do they have to do" FAQ answers only for Gabriel | Accept | Her two meetings, her answers with safe settings meanwhile, what she approves |
| S16 | Serenity | minor | No stated way for a student or listener to ask for removal | Accept | 08 §7.2. One line in show notes and descriptions; the address is OPEN for Serenity and Gabriel, never invented; the takedown clock starts on arrival |
| S17 | Serenity | minor | The roadmap's YouTube rule leaves out the name check | Accept | Round 2 S1 and PRV-15. "and no student is named in it" |
| S18 | Serenity | minor | The front page omits what happens if she does not look, and detection keys on her name only | Accept | Confirmed "my partner" in 09-06. Front page adds the hold; §7.10 treats "my partner" and words Gabriel confirms as naming her |
| S19 | Serenity | minor | "Since the 7 Oct page" speaks to Gabriel on a page for both | Accept | Merged with B10 |
| S20 | Serenity | minor | LIB-10, LIB-12 and BIZ-06 have no gates | Accept | Q-S12 default, PR-6 and the never-list. Gated as proposed |
| B1 | Brand | blocker | The yes-line diagram puts "On its own" below "nothing happens until a person approves" | Accept | Confirmed in `index.html` l.182-211. "On its own" above the line, "Waits for a person" below; render at 1440 and 390 |
| B2 | Brand | major | Both heroes state proposed numbers as facts; "new studio talks follow" describes a stopped flow | Accept-modified | Conflict 2 |
| B3 | Brand | major | The accuracy demo miscounts the income claims and skips "exact quote and time" | Accept-modified | Merged with G1. The quote-and-time format stays on the review screen, not the page, because quoting a claim on the page is banned; SCOPE l.265 corrected |
| B4 | Brand | major | "Every muted name is listed on the privacy receipt" reads as names leaving in a zip | Accept | SCOPE stores tokens and counts. "marked on the privacy receipt by its time, never written out" |
| B5 | Brand | major | "Nothing raw goes to the cloud" is false (iCloud, YouTube) | Accept | "Prakriti uploads nothing raw. Recordings stay where they are saved today." |
| B6 | Brand | major | "It becomes episode two" promises a Sunday format that may carry students | Accept | SCOPE l.270: Sun 20 Sep was a call with students. Rewritten with the talk and call cases |
| B7 | Brand | major | Serenity's paragraph overclaims separate tracks | Accept-modified | Merged with S4; conflict 13 |
| B8 | Brand | major | Money and terms rows on the page Serenity reads | Accept | D15. Conflict 14 |
| B9 | Brand | major | Collapsed questions still carry Fri 30 Oct; "asks" is office jargon | Accept | Merged with S12. Collapsed rows read "Any time; the safe setting holds"; "things" for "asks" |
| B10 | Brand | major | "Since the 7 Oct page" leads the page and speaks only to Gabriel; one reason reads as a dig | Accept | Retitled "For Gabriel: what changed since the 7 Oct page", moved below Where things stand, reasons reworded. Merged with S19 |
| B11 | Brand | major | The hero sentence is a 32-word run-on and says Prakriti publishes | Accept | Two sentences; README step 5 matches who uploads |
| B12 | Brand | minor | Ultramarine carries five meanings | Accept | Kept for the underdot, the yes line, "Ready for your yes" and focus rings; Now, is-mine and tile C go to ink |
| B13 | Brand | minor | The monospace register is used for prose and plans | Accept | Mono only for engine output; dates and plan words in the system sans with tabular figures |
| B14 | Brand | minor | The AI FAQ opens "No." then describes a use; Never card repeats its title | Accept | New question and answer; the repeated sentence goes from the Never card and README. The AI rule's substance is unchanged |
| B15 | Brand | minor | The publish-unless-stopped note on the front page contradicts "Nothing without a yes" | Accept | D15. It stays on the roadmap only |
| B16 | Brand | minor | The class rule contradicts itself in one card | Accept | New two-sentence student rule, word for word on all four documents |
| B17 | Brand | minor | "A person" where PLAN names Ivan; repeated stock phrases | Accept-modified | "Ivan listens" wherever the listener is Ivan; "the teacher" for approvals; the other line edits as given |
| B18 | Brand | minor | Step 5 is a settings spec, not a sentence | Accept | Rewritten, with "by email for now" (C14 e) |
| B19 | Brand | minor | Headline repeats "first"; tiles repeat words and use jargon | Accept-modified | Headline and 25 tile as given; the zero tile cites Gabriel's release samples, not the calibration set (S9, C14 c) |
| B20 | Brand | minor | README "recomposes it into something new" and an unasked Partner Program question | Accept-modified | Line rewritten. The Partner Program question exists in PLAN Q-GS7, so it moves into the roadmap's channel row for Serenity rather than being deleted |
| B21 | Brand | minor | Instagram handed back to Gabriel as a silent default | Accept | Conflict 10: OPEN, Q-G29 |
| B22 | Brand | minor | The sample art spells "Yoga Marga" before Gabriel names the show | Accept | Wordless ink tile; "Show name and art to come, from Gabriel and Ivan" |
| H1 | HIG | major | No way to say "not yet" during the 25 window while open items disable Approve | Accept | 03 C9. "Not Yet..." with one note and Keep / Cut / Add a Note on accuracy items join the Mon 26 Oct set; FAQ says so |
| H2 | HIG | major | Archive pieces have no defined way to reach Gabriel | Accept-modified | One email per approval session listing each piece, one link each; "Next waiting piece" after approving. The list screen is rejected for capacity (conflict 1) |
| H3 | HIG | major | Email, the only channel to Fri 6 Nov, has no copy rules and could carry an approve link | Accept | Email rows in §8.3; no approve link ever (a mail scanner can open links); NTF-08, PLAN and §8.2 matched |
| H4 | HIG | major | Approved re-alerts; 18 Live banners at once; Safari renotify unverified | Accept | Approved never alerts; one notice per multi-piece release; design as if renotify is ignored |
| H5 | HIG | minor | §9.6's Web Push steps assume no shared sign-in; first sign-in inside the Home Screen app | Accept-modified | Steps corrected, passkey only in standalone mode, checked on their devices. Web Push is after Fri 6 Nov, so low priority |
| H6 | HIG | minor | The sign-in card describes Google then passkey every time | Accept | Round 2 H2 (D14 correction). "Sign In with Passkey" first, the first-time line under it |
| H7 | HIG | minor | "Settings..." opens nothing for four weeks; a hidden icon leaves no way to Quit | Accept-modified | Dimmed until the Settings window lands; relaunch from Finder documented; phases matched |
| H8 | HIG | minor | `.mine-ask` links are 29px tall on a phone | Accept | 44px minimum, re-measured at 390 |
| H9 | HIG | minor | `targetContentIdentifier` cannot open a page in a menu-bar app; badge requested with no Dock icon | Accept | URL in userInfo, opened with NSWorkspace; alert and sound only; click one notice to verify |
| H10 | HIG | minor | "Show everyone's (N)" keeps its label when open | Accept | Label flips to "Hide everyone's (N)" |
| H11 | HIG | minor | "Sign In" wraps at 320px | Accept | nowrap; check at 320 |
| H12 | HIG | minor | The outputs key is an unnamed div | Accept | Visible "Key:" as on the roadmap |
| H13 | HIG | minor | Gabriel's counter says 10 by Fri 16 Oct | Accept | Merged with G8 |
| E1 | Engineer | blocker | Booked hours cannot carry Phase 0, Phase 1 order 1 and the Mon 26 Oct set | Accept-modified | Conflict 1. Sizing before the messages, with a written cut line. Rejected part: a session-run CLI engine, because Ivan's 10-08 request is autonomous watching with macOS notifications |
| E2 | Engineer | blocker | Episode 1's yes voids itself and the cut file skips its checks | Accept | Merged with G2; conflict 4 |
| E3 | Engineer | major | Teacher consents can only be Granted from a screen that ships after Fri 6 Nov | Accept-modified | Conflict 11: written yes from the teacher's own email counts until the screen exists; hand-label minutes measured on 09-06 this week |
| E4 | Engineer | major | "Exactly one speaker cluster" on the exact MP3 will trip on the intro and outro | Accept | Cluster test on body spans only; inserts checked by hash; name search over the whole file; dry run before Wed 21 Oct |
| E5 | Engineer | major | A takedown returns a piece to Approved with valid approvals | Accept | New "Taken down" state; approvals voided; feed and queue exclude open takedowns; system-tripped pause lifted by Ivan with a passkey and a logged reason |
| E6 | Engineer | major | R2 multipart has no conditional put or per-part checksum | Accept | Cloudflare's R2 Workers API (fetched by the critic Thu 8 Oct). Head check, random key suffix, DigestStream per part and whole file, conditional writes in Yoga Marga's bucket |
| E7 | Engineer | major | One lost event freezes the engine's sequence for good | Accept | Outbox in the same transaction, sequence per token epoch, 10-minute gap alert, snapshot resync, a §19 test |
| E8 | Engineer | major | Timeouts count clock time, so lid sleeps look like crashes | Accept | Awake time, timers restart on wake, a §19 lid test |
| E9 | Engineer | major | Alerts, sweeper and backups land after the window they protect | Accept | Merged with C8; conflict 1 |
| E10 | Engineer | major | Copying VeraSales' model layer breaks Sonnet and Haiku; no retries guard | Accept-modified | Confirmed in `models.js` and `workflow.js`. The 400 on disabled thinking is recorded as the critic's reading of the claude-api skill, verified by the §19 live call per model before use |
| E11 | Engineer | major | Hybrid MP4 rules ignore iCloud stalls during a live recording | Accept | 02 §16 Q6 is unverified. Fixtures on the engine Mac's synced copy over 20 minutes; 3-hour quiet wait; automatic clear |
| E12 | Engineer | major | Episode 1's private links have no design | Accept | Round 2 removed presigned links for this reason. `review_links` table, hashed token, 72 hours, no-store, token stripped from logs |
| E13 | Engineer | major | YouTube tests on Ivan's test channel cannot prove the project's lock | Accept | Tests through the production project at the account-holder sitting, week of Mon 26 Oct; audit form the same day if the lock shows |
| E14 | Engineer | major | The feed's "Yoga Marga account" is Gabriel's VeraSales account | Accept | 07 l.355. Conflict 8 |
| E15 | Engineer | minor | Release slots have no mechanism, failure path or time zone rule across Sun 1 Nov | Accept-modified | DST confirmed. Wall-clock time plus America/Los_Angeles; before Fri 6 Nov Ivan's script runs the slot; the cron design is written for when slots switch on; the daily summary uses the zone rule now |
| E16 | Engineer | minor | The schema lacks delegations, encrypted titles, feed ETag and review links | Accept | Added to the Phase 1 migration list with a delegation test |
| E17 | Engineer | minor | Phase 0 lacks team ID, bundle IDs, D1 name, R2 re-auth, keychain step | Accept-modified | Team LD587PB2H8 confirmed. Bundle IDs and the D1 name are written as proposals for Ivan to confirm, not facts |
| E18 | Engineer | minor | `.gitignore` still does not exclude the research files that name students | Accept-modified | First step of row 21, done by Ivan's pre-deploy sequence; the implementers do not edit `.gitignore` (not their file) |
| C1 | COO | blocker | Both pages state 25 unconditionally against about 5 qualifying talks | Accept | Conflict 2; Q-G18 fallback for 10; a substitute third sample if no Business of Yoga recording has Gabriel alone |
| C2 | COO | blocker | The privacy promise rules out the plan's own route to 25 | Accept | Conflict 6: teacher-only defined once; "or class stretches" removed from the fallback; a yes to Q-S24 changes the page in the same commit |
| C3 | COO | blocker | About 100 features in 24 hours of sessions; archive nights booked before their code | Accept | Conflict 1. YouTube below the cut; archive nights only after transcription passes on 09-06 |
| C4 | COO | major | 2 minutes cannot coexist with the queued listen; no listener named | Accept | Merged with S1; conflict 5 |
| C5 | COO | major | PLAN defers a dozen features SCOPE puts in Phase 1, and contradicts itself | Accept | One reconciliation pass; ACC-03, ACC-04, ACC-05, PRV-08, PRV-09, PRV-22 before approvals; chapters rebadged "Next" |
| C6 | COO | major | Ivan is a single point of failure Thu 22 to Fri 23 Oct | Accept | Account-holder sitting to the week of Mon 26 Oct; invitations to Mon 26 Oct; a takedown runbook Gabriel can run; Ivan's travel dates in row 23 |
| C7 | COO | major | The feed home has unowned steps, no slack, and the wrong account | Accept | Merged with E14 and G4; Q-G2 names the domain buyer, Apple ID, Spotify account and the school's email in the feed; review times checked |
| C8 | COO | major | Every safeguard of the autonomous engine lands after the 25 | Accept | Merged with E9 |
| C9 | COO | major | The first automatic write sends 18 at once after a four-day wait | Accept-modified | Conflict 12: first one alone; takedown tested on a separate test feed |
| C10 | COO | major | The documents disagree on when Serenity is asked; the second meeting has no date | Accept | Conflict 7: Tue 27 Oct |
| C11 | COO | major | Q-G27 (passages about his own life) is never shown to Gabriel | Accept | Added to his list under "yes to the suggestions", with how it differs from the income question |
| C12 | COO | major | The Fri 9 Oct messages wait on DECISIONS v2 | Accept | Decoupled; v2 by Mon 12 Oct; one ordered Fri 9 Oct checklist |
| C13 | COO | minor | Serenity cannot join before Fri 6 Nov with no consent screen | Accept-modified | Conflict 11 |
| C14 | COO | minor | Seven disagreements on dates, owners and build order | Accept-modified | All aligned to PLAN; (b) follows conflict 12 rather than automatic slots from Fri 30 Oct |
| C15 | COO | minor | The Library consent has no ID, answer or date | Accept | Q-G28 (Mon 30 Nov) and Q-S28 (when ready) |
| C16 | COO | minor | No exit check verifies Ivan's three notification moments | Accept | Phase 1 Done when, with screenshots |
| C17 | COO | minor | The Takeout re-run is framed as one sitting | Accept | A request Wed 14 Oct, downloads over one to three days, off the critical path |
| C18 | COO | minor | No dated task moves the private calls off the travelling laptop | Accept-modified | Moving them changes what Serenity was told ("they stay where they are"), so it becomes Q-S23's suggested answer, asked at the first meeting; until she answers they stay put, unopened |
| C19 | COO | minor | Two dated items depend on a weekly call with no day | Accept | Ivan proposes a fixed day and time on Fri 9 Oct; the terms go to that call in the week of Mon 19 Oct, in PLAN only |

**Totals:** 108 findings, 0 rejected outright. 82 accepted as written and 26 accepted with a
modification. In seven of those a specific part was rejected with its reason: a session-run CLI
engine (E1, Ivan's 10-08 request); a day-one share link and holding the 18 if unlisted (G10); a
separate list screen (H2, capacity); thumbnails asked by Fri 16 Oct (G14, no longer needed before
YouTube); Prakriti's automatic release slots from Fri 30 Oct (C14 b, E1); and moving the private
calls without Serenity's yes (C18).

### Were round 2's accepted items implemented?

Mostly; the critics confirmed Ivan doing the uploads, the 25 reset rule, the weekly call, the Sunday
ask, one-microphone wording on the front page, consent per use and the safe settings. Not landed, and
carried as round 3 tasks: round 1 G2's single digits (G8, H13); round 2 conflict 3's four questions,
which the Serenity filter undid (S12, B9); round 2 S17 for Q-S16 (S10); round 2 H2's passkey-first
card on the front page (H6); round 2 E1's sizing (E1, C3); and the length cut (B10, round 2), which
moved the lists under the yes line and caused B1.

### What changed

#### Site: web/public and web/src (site implementer, Thu 8 Oct 2026)

Nothing deployed, committed or sent; `wrangler.jsonc` untouched; `web/src/index.js` unchanged (task
21). Grep of `web/public` and `web/src`: 0 em dashes. Every weekday on the pages and in the roadmap
script was checked with `date -j -f %Y-%m-%d <date> +%A`: 233 date mentions, 30 distinct dates, 0
mismatches; the five new `data-due` values (2026-10-12, -15, -20, -26, -27) print Mon, Thu, Tue, Mon,
Tue through the script's own `label()`. No figure, quote or offer from the Sun 6 Sep talk appears on
either page (the transcript sentence in the sample package is the neutral one from round 1). No money,
fee, price, terms, certificate or "who pays" anywhere on the site.

**Front page (`index.html`)**
- Hero and meta description: the two-sentence lead (B11, B2, G5, G9, C1, conflict 2); hero status kept;
  both hero facts as given, "New studio talks follow" and the 2-minute clause cut. An HTML comment above
  the facts says the counted number replaces 25 here, in the roadmap lead and on its 25 tile, the same
  day, if the count is in before deploy.
- Sign-in card (H6): the button reads "Sign In with Passkey" (still `aria-disabled`, described by the
  status line, no handler, no form); "First time: Continue with Google from Ivan's invitation, then save
  a passkey."; "Not open yet..." kept.
- Sample package (G1, B3, B22, B12): Message "Worth a look, Two income claims and one spoken offer to
  decide."; the six accuracy lines as given, with counts and positions only; the show art is a wordless
  ink tile (`role="img"`, "Show art placeholder"); "Show name and art to come, from Gabriel and Ivan" in
  the system sans; tile C is ink on stone through tokens, with an ink edge so it stays distinct from B
  in light and from A in dark.
- How it works (B1, B18, B15, B17, S14, C14 e, E1): steps 1 to 5, then "On its own", then the yes line,
  then "Waits for a person", then step 6. Rendered at 1440, 768 and 390: each list sits on the side of
  the line its label names. Each list runs in two columns from 900px, which kept the page short. Step 2,
  3, 5 and 6 text as given; the publish-unless-stopped note is gone from this page; "(Ivan listens
  before anything public)"; the other-voices line as given. Step 5's engine line is now the "Ready for
  your yes" chip; "Waits for a person" uses the diamond, the roadmap's mark for "Waiting on a person".
- Outputs (C5, H12): split into "Titles and notes" (First) and "Chapters" (Next, after Fri 6 Nov); the
  key is a visible "Key:" line in the roadmap's `.note.key` pattern. "chapters" left step 4's sample
  output line, since episode 1 ships without them.
- Privacy cards (S4, C2, S5, B4, B16, S18, S1, B17): the four bodies as given, the student rule word for
  word, and "Until Friday 6 November, Ivan takes one down by hand, at once." The FAQ "How do I stop it?"
  got the same "Until Friday 6 November" wording, so the two say one thing.
- FAQ and What comes next (S15, G9, B21, H1, B14, B17, C14 b): all as given, including the new AI
  question and the Sonny line in "Where does the work happen?".
- **Height at 1440: 7,202px before, 7,370px after (+168, inside the 300px allowance).** 768: 8,888px;
  390: 11,560px. Light and dark are the same height.

**Roadmap (`roadmap.html`)**
- Hero and goals (B19, B2, G5, G6, S9, C14 c): h1 and lead as given, with the same count comment; the
  25 tile reads "episodes", the 2 tile "Proposed: ... after Ivan's listen" with "Your goal only if you
  say yes.", the 0 tile's three checks. Every mention of the 10-file hand check is gone (the Phase 2
  sample row now reads "Listen to the privacy sample of Gabriel's talks, including archive talks
  recorded with students on the call"). The goal note carries the two counts and the 10 fallback without
  "or class stretches".
- "For Gabriel: what changed since the 7 Oct page" (B10, S19, B5, G16, G5) is now section 02, below
  Where things stand, out of the hero; the table of contents is renumbered 01 to 07. Lines as given,
  the ElevenLabs line added after the trailer line. The 25 and 72-hour lines carry their reasons inside
  the line, so they have no separate reason.
- Phases 0 to 3 (G1 to G15, C6, C9, C10, C16, C17, S1, S13, S17, B6, B8, B17, B21, E13): every row as
  given. Order kept by date: the new show-name row sits before the visit and the intro row, so "Same
  visit" still reads against the visit row above it. Phase 2's release lines, the takedown test on a
  separate test feed, the email notice line, the YouTube-after-Fri 6 Nov paragraph, the new Ivan and
  Gabriel rows, invitations and both accept rows on Mon 26 Oct (Serenity's too, per the shared fact),
  the account holder's sitting in the week of Mon 26 Oct with the YouTube tests, Serenity's 30-minute
  meeting on Tue 27 Oct. Phase 3 has no terms gate. The terms rows, the certificate row and the
  lawyer-and-who-pays row are gone from the page.
- Decisions (G1 to G16, C11, C15, B6, B7, B8, B9, B14, B16, B21, S2 to S16, C10, C15, C18, E15):
  For Gabriel opens with the "yes to the suggestions" line, then "Needs your answer" (7 rows: podcast
  first and the numbers, both Mon 12 Oct or at the visit; show name and ask; the money statements; the
  podcast home; the voice clip), "Unless you say otherwise" (14 rows, date order), and "For
  information" (4). The frames row is Fri 6 Nov. For Serenity: the new intro; "Needed by Mon 12 Oct"
  (the channel row, moved from For you both); "Asked at our first meeting, needed by Fri 16 Oct" (names
  list, students who only listened, Claude including Sonny); "Asked on Tue 27 Oct, needed by Fri 30 Oct"
  (student voices, retold stories, her own talks); and "Each has a safe setting until you answer (23)".
  For you both: the lawyer row (Fri 23 Oct), the sitting, the removal line with "an address you two
  choose" (no address invented), the new ownership and data-note suggestions. Ivan's list: release-time
  row as given. Never: the student rule word for word; the AI card's repeated first sentence removed.
- Dates and plan words ("target", "Same visit", "From now on", "For information", "Updated Thu 8 Oct
  2026") are in the system sans at 15px with tabular figures (`.meta`); the roadmap has no mono text
  left. Mono stays only for the front page's file names, timecodes, sample header and the engine lines
  of steps 1 to 4 and 6 (B13).

**The filter (`assets/roadmap.js`)**
- "Gabriel: 7 things needed by Fri 16 Oct." and "Serenity: 5 things needed by Fri 16 Oct." (G8, H13,
  S12, B9). Rows marked `data-default` (Gabriel's "Unless you say otherwise", Serenity's safe-setting
  group, and the matching phase rows) never count and never enter the dated list; an ask counts if any
  of its rows is an action, so the intro, a suggestion in the decisions, still counts as the recording
  Gabriel makes at the visit. Ivan's rows are never treated as defaults.
- Each person's list: This week, Later, No date yet; then two collapsed groups, "For you both (N)" and
  "Unless you say otherwise (13)" for Gabriel or "Each has a safe setting until you answer (23)" for
  Serenity, each row with its suggestion (Gabriel) or its "Until you answer" line (Serenity) beside it.
  Serenity's dated list is exactly her real actions (channel confirmation, two meetings, the episode 1
  look, accepting her invitation, approving her pieces and receipts) and her six shown questions.
- Rows timed by an event or a span show "By" and their latest date in the list ("By Thu 15 Oct" for the
  day before the visit), never a day that has not been set; ranges show "From".
- "Show everyone's (N)" becomes "Hide everyone's (N)" when open, `aria-expanded` kept (H10). A decision
  sub-heading hides when no row under it is shown for the chosen name.
- Account-holder rows (the Takeout request, the sitting) are shown to Serenity only, under "If you hold
  the school's Google account", counted for no one (G12 took Gabriel off that question).

**Stylesheet (`assets/site.css`)**
- `.mine-ask` is a block at least 44px tall: measured at 390 with ?for=gabriel, ?for=serenity and
  ?for=ivan, every list link is 44 to 64px (H8).
- `.nav a` never wraps; under 360px "Privacy" hides as "How It Works" does at 640. At 320 the bar shows
  Sign In (46px) and Roadmap (44px) on one line (H11).
- Ultramarine has four jobs only: the underdot (and the 404's large dot, the same mark), the yes line,
  "Ready for your yes", and focus rings. Now is a heavy ink ring; `.is-mine` is an ink edge on the sunk
  fill; the progress line, the Now phase number and strip edge, the current table-of-contents entry, the
  phase counts and inline links are ink; tile C is ink on stone (B12). Checked in light and dark.
- Smallest rendered text on any page: 12px (tile C's floor at 390); nothing under 12.

**Worker checks (task 21, `wrangler dev` 4.149.0 on 127.0.0.1:8787, then stopped)**
- `/`, `/roadmap`, `/roadmap?for=gabriel`, the CSS, the script and robots.txt: 200 over http, no HSTS;
  `/index.html` and `/roadmap.html` 301 to the clean paths; `/404.html`, `/src/index.js`,
  `/wrangler.jsonc`, `/.git/config`, `/PLAN.md`, `/no-such-page` and `/assets/../src/index.js`: 404.
  CSP, nosniff, Referrer-Policy, Permissions-Policy, X-Frame-Options DENY and X-Robots-Tag present.
  Rendered through the Worker (front page, roadmap, roadmap with a name at 1440 and 390 dark, a deep
  unknown path): no CSP or console errors; the only logged error is the 404 status of the unknown path.

**Renders** in `screens/r3-site/`: index and roadmap at 390, 768 and 1440, light and dark, full page,
roadmap with ?for=gabriel and ?for=serenity at all three widths in both themes, both pages at 320, and
the Worker renders in `screens/r3-site/worker/`. The roadmap is taller than the 16,000px single-capture
limit at every width (18,531px at 1440, 27,832px at 390), so `screens/r3-site/segments/` holds it in
slices, with every phase and collapsed group open at 1440, and with each person's list open at 390. No
console errors, failed loads or sideways scroll in any render.

**For Ivan, three things the site now shows that need an owner (OPEN):**
1. **The show description is due Fri 16 Oct, but Serenity sees the draft at her first meeting in the
   week of Mon 12 Oct.** Recommendation: draft the description by the day before her meeting; the art
   can stay Fri 16 Oct. The row was not changed.
2. **The show name has no fallback.** "No answer: episodes go out with no ask" covers the listener ask
   only; a show cannot be submitted without a name, and nobody may invent one. Recommendation: say on
   Gabriel's row that with no name by the day before the visit, the first episode waits, as the podcast
   home row already says.
3. **Seven of Serenity's questions had no safe setting on the page** (her AI voice, the enrollment form,
   raw-recording retention, the syllabi, Spanish, continuing education, recording in the studio). Each
   now carries the plain "nothing happens" setting ("no AI version of your voice", "every class stays
   private", retention uses SCOPE's Q-S12 text rule, and so on), and "audio-only class episodes" joined
   her collapsed group, which is why it reads 23. The docs implementer should mirror these in SCOPE's
   Serenity table so the two match.

#### Docs: PLAN.md, docs/SCOPE.md, START_HERE.md, README.md, CHANGELOG.md (docs implementer, Thu 8 Oct 2026)

Nothing deployed, committed or sent; `.gitignore`, `research/DECISIONS.md` and `web/` untouched. Grep
of all five files: 0 em dashes. Every weekday in the five files was checked against `date(1)` by a
script: 1,199 date mentions, 0 mismatches.

**What changed**
- **PLAN.md:** a new "The cut line" section (above and below the line as specified; row 23 moved
  ahead of row 4; one ordered Fri 9 Oct checklist: sizing, count, messages, deploy; archive nights
  only after transcription passes on 09-06). The 25 as proposed podcast episodes with two counts, the
  substitute third sample, the fallback without "or class stretches", and the new release plan
  (Q-G18, Q-G19). Episode 1 rewritten around versions A and B, the feed ready Tue 20 Oct, submission
  within the hour, review links, and a Done-when with screenshots of the three notification moments.
  Ivan's listen in Gates and "Time it takes" (the critics' 6 to 7 minutes a piece recorded as their
  estimate, OPEN until measured; row 26 measures it); "Proposed: under 2 minutes of Gabriel's time per
  piece, after Ivan's listen" everywhere. Teacher-only defined once in Gates; the student rule word
  for word. Serenity's two meetings, Q-S11a, Q-S13 and the new Q-S30 by Fri 16 Oct, Q-S29 at the
  second meeting, Q-S24 "Not yet". Q-G2 rewritten for the new Yoga Marga Cloudflare account (row 19,
  the feed home); Gabriel's seven things and the "yes to the suggestions" line; Q-G8 with every money
  statement in the private message only; Q-G27 told apart from Q-G8; Q-G5, Q-I12, Q-I20, Q-GS1,
  Q-GS3, Q-I16, Q-GS7 (Serenity only) rewritten; Q-G28, Q-G29, Q-S28 new. Consent before the screen
  exists; Gabriel's two-minute takedown runbook; YouTube, the account holder's sitting and the tests
  moved; money, the terms, who pays for the lawyer and the certificate kept in PLAN only; the round 3
  spine corrections copied; the two "Since the 7 Oct page" lines added (in the third person).
- **docs/SCOPE.md:** every task in 15 to 17. Highlights: PRV-05's listen as Ivan's step, logged in a
  new `listens` table; the student rule and the privacy promise word for word in §5.16, with
  teacher-only defined there and pointed to from R-01 and §1; S8's receipt rule in §9.4 and §10.3;
  §19.1 adds Gabriel's Zoom-era samples and the substitute; the Phase column reconciled to the cut
  line (a script found no ID placed above the line in PLAN and below it in SCOPE, or the reverse,
  except features deliberately split in two); §8.3 email rows, Approved never alerting, one "Live"
  notice per release; §6.4 outbox and epochs; §7.13 and stage 22 integrity without R2 features that do
  not exist; "Taken down" in §9.2; §12.4 release slots across Sun 1 Nov; §13.3 model registry; the
  `delegations`, `review_links` and `listens` tables and the migration list; R-42 to R-45; §11.9 and
  §18 regenerated by a script from PLAN.md's question table, so the wording is identical by
  construction.
- **START_HERE.md:** current-state lines matching PLAN; a "Facts for the build" table (team
  LD587PB2H8; bundle IDs, plist name and D1 name as proposals for Ivan; the `wrangler login` re-auth
  checked with `wrangler r2 bucket list`; the keychain step for the archive drive); the `.gitignore`
  edit as row 21's first step; warnings 27 to 34, each with its reason.
- **README.md:** every task in 19; the two-meetings sentence is the same as PLAN's and SCOPE §18's.
- **CHANGELOG.md:** a new top entry for round 3, why first.

**Mirrored from the site implementer's OPEN list:** Serenity's seven questions now carry the same
"Until you answer" settings in PLAN and SCOPE as on the roadmap (item 3); Q-G26 now says the first
episode waits with no name, because a show cannot be submitted without one (item 2); the show
description row recommends the draft be ready by the day before Serenity's first meeting, as OPEN for
Ivan (item 1).

**Not changed, and why**
- **Q-S24's wording:** the shared fact's version ("not one second of a student labeled as a teacher",
  "a lawyer") is used, not the task's paraphrase ("zero seconds of student speech", "the lawyer"), so
  the docs and the roadmap say the same words.
- **Apostrophes:** the docs keep straight apostrophes where the site uses typographic ones; the words
  of the student rule and the privacy promise are identical.
- **"Built in these two weeks"** is in `web/public/roadmap.html`, the site's file; PLAN's Phase 1 says
  "Built this week".
- **Phase 1's "Not in this phase"** listed no YouTube tests; they were in the after-Fri 6 Nov list and
  in SCOPE §12.3, and are moved from there to the account holder's sitting.
- **The money statements' times** are not written anywhere: Sonny re-finds them in the Sun 6 Sep
  transcript for the private Fri 9 Oct message.

**Placed by the docs implementer, flagged for Ivan** (neither list in the task named them): the cost
ledger and meter screen and the package zip below the cut line (the Console spend limit is the cap
until then); PRV-07 and ACC-07 above it, on the receipt and the review page; the review links, the
activity and audit logs, the archive inventory to shortlist and the daily summary above it, because
items above the line need them; the removal address needed by Fri 16 Oct for episode 1's notes, with
no line printed until it is chosen (suggested: the school's contact address); Q-G29 due Mon 30 Nov;
whether the Mac Dock app keeps the Safari sign-in marked to verify on their Mac.

**OPEN for Ivan:** his travel dates Mon 19 Oct to Fri 6 Nov and the session times (row 23); the weekly
call's day and time (row 24); the release hour (Q-I20); the proposed bundle IDs and D1 name; the
placements above; the pending spine corrections of rounds 1 to 3 and DECISIONS v2 by Mon 12 Oct (row
22); who pays for the lawyer (Q-I12); the address cost, unknown until priced (Q-G2).
