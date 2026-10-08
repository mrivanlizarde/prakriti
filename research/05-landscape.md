# 05 · Competitive landscape for Prakriti

Track: competitive landscape, feature matrix, build vs buy.
Written 2026-10-08 by a Sonny research agent. Read-only research; nothing was sent, posted or changed.
Inputs: `~/Code/prakriti/research/BRIEF.md` [S1], `~/Code/prakriti/research/2026-10-07-call-gabriel-transcript.txt` [S2], web research on 2026-10-08, and a read-only probe of the studio folder [S75].

Conventions:
- `[S#]` points to the numbered source list at the end. Every factual claim carries one.
- `[unverified]` = could not confirm on a vendor's own page, or sources conflict. Treat as a planning number, confirm before money moves.
- `[inferred]` = my reasoning, not a sourced fact.
- Prices are USD, before tax, as published or reported on or near 2026-10-08. Third-party price trackers disagree a lot in 2026; where they do, the range is given.
- Effort scale for anything Prakriti would build itself: **S** = under a day of agent build plus Ivan's review; **M** = 2 to 5 days; **L** = 1 to 3 weeks. Rough, for sequencing only.

---

## 0. The answer in twelve lines

1. **Nobody sells Prakriti.** No 2026 product goes from "a file lands in a folder" to "podcast + video + shorts + thumbnails + scored, speaker-tagged transcript + per-teacher knowledge base + consent-checked publishing" unattended. The closest single tools each own one slice: Auphonic (folder to mastered, published audio) [S16-S19], OpusClip (YouTube channel to scheduled shorts) [S7, S10], Castmagic (RSS to transcript, show notes and library chat) [S14, S15]. A search for a watch-folder-to-YouTube-and-podcast tool found none [S38, S18].
2. **What nobody has at all is the yoga-school layer**: a consent registry, student-aware handling of classes, per-teacher knowledge bases with lineage tags, archive-scale triage of 900 hours, and Spanish. That layer is Prakriti's reason to exist (section 7).
3. **Buy loudness, build judgment.** Pay Auphonic for audio mastering on what gets published (about $0.55 to $1.71 per hour) [S16]. Pay a cloud API for diarized transcription of the archive (about $207 for all 900 hours at AssemblyAI's rate) [S62]. Build selection, scoring, consent and publishing, because every vendor optimises for virality, not for Serenity's accuracy and privacy conditions [S1].
4. **Do not buy a clipper yet.** Podcast audio ships first [S1]. When shorts turn on, the studio's own OBS setup produced a native 1080x1920 vertical file on 2026-09-06 and has not since [S75]; turning that back on removes the hardest thing OpusClip sells (reframing). Benchmark OpusClip for one month ($15 to $29) [S7] rather than adopting it.
5. **RedCircle has no public API that I could find** [S40]. A podcast host that publishes unattended needs one. Transistor has a documented API on every plan, private (students-only) feeds, YouTube auto-post and Apple HLS video [S43, S44], from $19/month.
6. **YouTube's upload limit is no longer the blocker the vault says it is.** Uploads moved to their own quota bucket in 2026 and were cut from about 1,600 units to about 100 per upload in Dec 2025 [S47]. The new blocker: uploads from an **unaudited** Google API project are forced to private until Google audits the project [S46]. That happens to match the standing "human yes before anything public" rule [S1].
7. **The archive is already on YouTube.** Publishing an archive talk as video means flipping an existing unlisted video to public with new metadata, not re-uploading [S1, inferred]. Getting the files out for audio work is a Google Takeout job; older uploads may come back re-encoded at up to 1080p [S70] [unverified].
8. **The three-thumbnail A/B test cannot be automated.** YouTube's Test & Compare is free, now tests titles too, picks by watch-time share, but runs only in YouTube Studio on a computer, not via the API, and not on Shorts [S49, S48]. Prakriti makes the three; a person spends two minutes placing them.
9. **ElevenLabs will not let Gabriel build "the Serenity voice."** Professional Voice Cloning only clones the account holder's own voice, even with consent; Serenity would create and verify her own clone and share it [S59]. Prakriti's job is to prepare a clean, single-speaker dataset for each person, not to clone.
10. **Eleven Music (for intro beds) lists "religious organizations or institutions" as a prohibited industry** [S61]. Whether a yoga school counts is a question to settle before using it [inferred].
11. **A SaaS stack that approximates Prakriti costs about $3,000/year and still could not process the archive** (plan caps of 30 media hours/month, 300 clip minutes/month, 100 library hours, 1M training words) [S3, S7, S14, S54]. The recommended build-plus-buy stack runs about **$1,200 to $1,800 in year one**, archive included (section 8).
12. **The actual studio cadence is lower than planned**: six substantive recordings totalling about 5.4 hours between 2026-09-06 and 2026-10-08, roughly 1.3 a week, not 2 to 4 [S75]. Cost math below uses both the measured and the planned rate.

---

## 1. Scale assumptions used throughout

| Input | Value | Source |
|---|---|---|
| Archive size | 900 hours (Gabriel said "900 hours plus"; the brief says about 900 recordings) | [S1, S2] |
| Archive location | Unlisted YouTube, no transcripts on the Mac | [S1] |
| New studio recordings, measured | 6 recordings over 15 min since 2026-09-06; durations 55.7, 15.8, 61.7, 66.3, 55.1, 71.6 min; total about 5.4 h in about 4.6 weeks (about 5 h/month) | [S75] |
| New studio recordings, planned | 2 to 4 a week at about 55 to 70 min, so about 8 to 16 h/month | task brief, [S1] |
| Studio file size | about 2.8 GB per hour at 1920x1080 (e.g. 61.7 min = 2.86 GB) | [S75] |
| Native vertical capture | Present only for 2026-09-06 (`-vertical.mp4`, 1080x1920, same duration as the landscape file) | [S75] |
| Spoken words per hour | about 8,400 (140 words/min) so about 11k tokens/hour | [inferred] |
| Archive transcript volume | about 7.6M words, about 10M to 13M tokens | [inferred] |

---

## 2. The landscape, product by product

"Unattended?" means: once configured, does it take new material and produce output with no person in the loop.

### 2A. AI editors and co-editors

**Descript (incl. Underlord)**
- What: text-based audio/video editor; Underlord is its AI co-editor (rough cuts, filler removal, Studio Sound, captions, clips, translation and dubbing) [S3, S5]. A May 2026 update reportedly added multi-step natural-language workflows on Claude Opus 4.8, e.g. "cut this two-hour video to the best takes, add chapters, strip silences over two seconds," with per-project memory [S5] [unverified, third-party].
- Price: Free; Hobbyist $16 to $24/mo (10 media h/mo); Creator $24 to $35/mo (30 media h/mo, 800 AI credits); Business $50 to $65/mo (40 media h/mo) [S3]. (The page shows two prices per plan without labels; the lower is likely annual [S3].)
- Spanish: transcription supports Spanish (US); language count is 23 to 26 depending on page [S6].
- API: "API + MCP" in early access, included for paying users at no extra cost, drawing on plan credits; can import by URL, run Underlord edits, export transcripts and timelines, publish a share page. **Direct media file export via API is not supported yet** [S4].
- Unattended? Partial. Triggers (RSS, file upload, webhooks) can start workflows, but the page describes a manual review step and early-access status [S4].
- For Prakriti: the best human finishing tool if Gabriel ever wants to polish a flagship. Not a render engine for an unattended pipeline (no media export via API) [S4]. Media-hour caps (30/month on Creator) rule it out for the archive [S3].

**Riverside (Magic Clips, Magic Audio, Co-Creator)**
- What: remote recording studio plus editor. Co-Creator is a chat-based editing agent inside the editor (pacing, music with fades, filler removal, B-roll by description, show notes, newsletters, social posts) [S13]. Magic Clips finds highlights; Magic Audio is one-click enhancement [S13].
- Price: Pro $24 to $29/mo; Grow $34 to $39/mo (adds Riverside MCP, AI thumbnails, social scheduling, podcast hosting for 2 shows); Business by quote (only tier with API access) [S12]. Page is labelled as possibly out of date [S12].
- Unattended? No. Built around recording inside Riverside; Prakriti's input is OBS [S1].
- For Prakriti: skip. Borrow the Co-Creator pattern ("describe the edit in a sentence") for the review screen later.

**Async (formerly Podcastle)**
- What: Podcastle rebranded to Async in early 2026 (Jan or 4 Feb 2026, sources differ); split into Async Studio (editor) and Async API (text-to-speech) [S22]. Magic Dust enhancement, noise reduction, auto-levelling, silence removal, 1,000+ AI voices, voice cloning, subtitles in 70+ languages, podcast hosting page [S22].
- Price: Free; Essentials / Pro / Teams prices were blank on the fetched page; credits 450 / 1,200 / 3,000 per month; transcription 10 / 25 / 100 h/month [S22].
- Unattended? No. API is TTS only [S22].
- For Prakriti: skip. Note it as evidence of vendor churn.

**Gling**
- What: auto-removes silences, filler words and bad takes; YouTube title and chapter generator; SRT; XML export to Final Cut, Resolve, Premiere [S32].
- Price: Plus $15/mo or $10/mo annual, 10 h/month, overage $0.04/min [S32]; a $20 to $30 Pro tier is reported by a competitor [unverified].
- Unattended? No (desktop/web editor).
- For Prakriti: skip; its "bad takes" detection is the feature to replicate for studio recordings (section 6).

**TimeBolt / Recut**
- TimeBolt: desktop silence/filler/bad-take remover with NLE export; $247 lifetime, other listings show $97/yr or $9 to $17/mo [S33] [unverified]. No confirmed batch or watch-folder mode [S33].
- Recut: Mac-only silence remover, $99 one-time [S34] [unverified, competitor source].
- Unattended? No.
- For Prakriti: skip. ffmpeg `silencedetect` plus transcript timing does this for free [inferred].

**Eddie AI**
- What: AI assistant editor for Premiere, Resolve (script extension) and Final Cut (added 15 May); logs footage, syncs up to six multicam angles, builds rough cuts from plain-language direction, exports XML; "Night Shift" processes footage off-hours; about a hundred MCP tools [S35].
- Price: switched to prepaid credits: $10/1,000, $45/5,000, $120/15,000, $350/50,000; import costs about 500 credits per source hour [S35]. So about $3.50 to $5 per imported hour [inferred].
- Unattended? Partial (Night Shift). GPU desktop app [S35].
- For Prakriti: borrow two ideas, Night Shift (process when the Mac is idle and plugged in) and NLE handoff (export a cut list a human can finish in Final Cut).

**Jumper**
- What: local AI search across footage by visual content, tags or spoken words, as a panel in Premiere and Final Cut; analysis runs entirely on the user's machine [S36]. v2026.02.25 added agent control so Claude can drive it [S36].
- Price: about $15/mo or $249 lifetime [S36] [unverified].
- Unattended? No (search tool).
- For Prakriti: borrow later. "Find every moment Serenity demonstrates a pose" across 900 hours is a real knowledge-base feature, and doing it locally fits the privacy rule [inferred].

**Frame.io**
- What: review and approval platform; Transfer app with watch folders that auto-upload and resume; Camera to Cloud; V4 API (V2 deprecated) [S37].
- Price: Pro $15/member/mo, Team $25/member/mo (about $13 and $22 annual) [S37].
- Unattended? Upload only.
- For Prakriti: skip the product; borrow the review pattern (timecoded comments, one Approve button).

**CapCut**
- What: editor with auto captions and "Long Video to Shorts" on Pro [S31].
- Price: Pro reported at $7.99 to $19.99/mo, region-dependent [S31] [unverified].
- Terms: commentary on its terms says uploads grant ByteDance a global, royalty-free, perpetual license including faces and voices, surviving account deletion, on every tier [S31] [unverified against CapCut's own terms page].
- For Prakriti: **disqualified for any recording with students** on the license alone. Skip.

**Captions (now Mirage)**
- What: the Captions company rebranded as Mirage in March 2026; AI Edit styles, chat editing, captions in 100+ languages, filler removal, eye contact, lip-synced dubbing, avatars [S30].
- Price: $9.99 to $279.99/mo by credits [S30] [unverified].
- Unattended? No (mobile-first).
- For Prakriti: skip.

### 2B. Audio cleanup and mastering

**Auphonic** (the strongest buy in this report)
- What: Intelligent Leveler, noise and reverb reduction, loudness targets, filler and silence cutting (all plans); multitrack; multilingual transcription, automatic show notes and chapters (paid) [S16]. Presets, watch folders, outgoing services and a full API and CLI on all plans including Free [S16, S17].
- Price (read from the live pricing page's data on 2026-10-08) [S16]:
  - Recurring per month, billed monthly: 9 h $13 · 21 h $30 · 45 h $64 · 100 h $136 · 250 h $290. Billed yearly (per month): $11 · $25 · $52 · $113 · $245. Unused recurring credits do not roll over.
  - One-time credits, never expire: 5 h $12 · 10 h $23 · 25 h $55 · 50 h $100 · 100 h $171 · 250 h $320 · 500 h $545 · **1,000 h $1,045** · 2,000 h $2,020 · 3,000 h $2,925.
  - Charged on processed duration, 3-minute minimum; re-running the same inputs is free [S16].
- Watch folders: start a production from a preset when files appear in a connected service; Dropbox, Google Drive and OneDrive use push, others are polled with a few minutes' delay [S18]. Sources: Dropbox, Google Drive, OneDrive, FTP, SFTP, S3 and S3-compatible, WebDAV, plus Zapier and n8n [S17]. iCloud is not listed [S17].
- Publishing: YouTube (audio-only gets a video track from cover art; chapters become clickable), SoundCloud, Libsyn, Captivate, PodBean, Spreaker, Archive.org, and since March 2026 RSS.com, Acast and Scrybecast, with an optional **"Review before Publishing"** approval step [S17, S19]. RedCircle and Transistor are not listed [S17].
- Unattended? Yes, the most complete unattended audio chain on the market.
- For Prakriti: integrate via API for every published piece. Do not use its watch folders (Prakriti watches the local iCloud folder itself) or its publishing (Prakriti publishes with its own approval gate).

**Cleanvoice**
- What: removes filler words, mouth sounds, breaths, stutters, silence, background noise; echo/reverb removal; transcription and show notes [S20].
- Price: pay-as-you-go 5 h $11 to 30 h $45; subscriptions 10 h/mo $11, 30 h/mo $28, 100 h/mo $90 (unused credits roll over up to 3x) [S20]. API available, pricing not published [S20]. Spanish not mentioned [S20].
- For Prakriti: skip; Auphonic covers filler and silence cutting already [S16].

**Adobe Podcast (Enhance Speech)**
- What: one-click speech enhancement; v2; a March 2026 update added source separation and multitrack import [S21] [unverified].
- Price: Free (30 min / 500 MB per file, 1 h/day); Premium about $9.99/mo (2 h / 1 GB files, 4 h/day, bulk upload, video) [S21] [unverified].
- API: none found for Enhance Speech; Firefly Services audio APIs found cover TTS and reframe only [S21].
- For Prakriti: skip for automation (no API, daily caps). Useful as a manual rescue for one bad archive recording.

**ElevenLabs Voice Isolator** (see 2G for the rest of ElevenLabs)
- 1,000 credits per audio minute; files up to 500 MB and **1 hour** [S60]. Pro ($99/mo, 600k credits) covers about 10 hours a month [S58, inferred].
- For Prakriti: only for building clean voice-training sets from noisy archive material, never as a bulk cleaner (900 h would need about 54M credits) [inferred].

### 2C. Auto-clippers (long video to shorts)

**OpusClip**
- What: AI clipping with Virality Score, animated captions in 20+ languages, auto-reframe with object tracking (Pro), brand templates, intro/outro cards, brand vocabulary, scheduler, posting to YouTube Shorts / TikTok / Instagram (+ LinkedIn, Facebook, X on Pro) [S7]. ClipAnything accepts natural-language prompts for what to clip [S11].
- Price (official page): Free 60 min/mo; Starter $15/mo, 150 credits; Pro $29/mo, 300 credits; Business custom. 1 credit = 1 minute of imported video regardless of clips kept [S7, S8]. "Save up to 50% annual" [S7]; annual Pro reported at $174/yr for 3,600 credits; credits on monthly plans lapse after 60 days; extra credits cannot be bought standalone [S8] [unverified, third-party].
- Auto import: Starter and Pro can auto-process new **public** YouTube videos over 3 minutes (or chosen public playlists), charging full length [S10]. Unlisted archive videos would not qualify [inferred from "public"].
- API: pricing page lists Video Editing API, Scheduler API and MCP connector on Pro [S7]; OpusClip's own blog alternately says "contact sales for early access" [S9]. Input by URL, upload or RSS; webhooks; speaker focus and duration parameters [S9].
- Spanish: supported for clipping and captions [S11].
- Unattended? Yes for public YouTube channels.
- For Prakriti: see section 8; recommendation is benchmark, not adopt.

**Vizard**
- Clipping, reframe, captions, B-roll, brand kit, scheduling; credits = minutes (60/mo free; paid tiers 7,200 to 74,400 credits/yr); API rate limits 3/min (Creator) to 10/min (Business) [S24]. API page says it can run "identifying viral moments to final publishing" with a preview and a final "Go" before posting; API price not published; "30+ languages" [S24].
- For Prakriti: skip. Note the "Go" gate pattern.

**Munch**
- Clips, captions, trend analysis, post generation, direct publishing to YouTube, TikTok, Instagram; Pro $49/mo (200 upload min), Elite $116 (500), Ultimate $220 (1,000) [S27] [unverified].
- For Prakriti: skip (most expensive per minute).

**Klap**
- Clips priced per clip: Basic $14/mo (100 clips), Pro $39 (300), Pro+ $94 (1,000), billed yearly [S25]. API `POST /v2/video-to-shorts` with public video URL; captions in 100+ languages [S25]. API price not published.
- For Prakriti: skip.

**Submagic**
- Captions-first editor; Magic Clips is a $19/mo add-on; Business + API $69/mo ($41 annual) includes 100 API minutes, packs from $0.23/min down to $0.10/min [S26] [partly unverified]. Whether its API can publish is disputed [S26].
- For Prakriti: skip.

**Choppity**
- Context-aware clipping, multi-speaker face tracking, captions in 97 languages, native posting and scheduling; about $14 to $20/mo [S28] [unverified, mostly self-reported].
- For Prakriti: skip.

**Momento**
- Podcast promotion assistant (highlights, social copy); $24.99 to $34.99/mo for 4 episodes [S29] [unverified, may be a different product of the same name]. No evidence it auto-clips on new episodes [S29].
- For Prakriti: skip.

**Headliner**
- Audiograms; "Automatic Audiograms" create and post a clip to YouTube and social every time a new episode hits the RSS feed; AI post copy on Pro; Pro about $19.99/mo [S39] [price unverified].
- For Prakriti: skip; YouTube's own RSS ingestion covers the audio-on-YouTube case (2E).

### 2D. Transcript-to-text repurposing and library chat

**Castmagic**
- What: speaker-labelled, timestamped transcripts in 60+ languages; show notes, quotes, newsletters, clips and audiograms; Magic Chat across a library; global search; read-only **MCP connector for Claude** (April 2026); import from links, files, Zoom, Google Drive, RSS, YouTube [S14, S15].
- Price (annual): Hobby $19/mo (30 library hours total), Starter $48/mo (100 h, API), Team $139/mo (400 h); Business from $699/mo. Hours are a **library total**, not monthly [S14].
- Unattended? Yes via RSS: connect a feed and every new episode is pulled and transcribed [S15].
- For Prakriti: skip the product (900 hours would need the $699+/mo tier) [S14, inferred]. Borrow two features: library chat with citations, and an MCP connector so Sonny can query the library.

**Swell AI**
- Transcripts, show notes, articles, newsletters, clips; pricing snapshots conflict ($29 to $49/mo; overage $0.10 to $0.13/min) and appear dated [S23] [unverified].
- For Prakriti: skip.

### 2E. Publishing and distribution

**Repurpose.io**
- Cross-posts video and podcast content; sources include Dropbox and Google Drive; "auto publish" sends new uploads without intervention; a same-name `.txt` beside a file supplies description and timestamps [S38]. Starter $35/mo, Pro $79, Agency $179 [S38].
- No documented approval queue [S38].
- For Prakriti: skip (no gate, no editing). Borrow the sidecar-text idea: OBS already writes a `.txt` beside each `.mp4` [S1].

**RedCircle** (the host Gabriel already has)
- Core free (1 podcast); Growth $14.99/mo (unlimited podcasts, dynamic insertion, transcript generation, video generation); Pro $29.99/mo (video upload, **one-click YouTube distribution**, 5 seats); Enterprise $99.99 [S40].
- API: **none found** on the pricing page or support site; the upload flow is the dashboard [S40]. Third-party "RedCircle API" listings appear to be a different product with the same name (Target product data) [S40] [inferred].
- Not on Apple's HLS video partner list [S44].
- For Prakriti: autonomous publishing to RedCircle is not possible on current evidence; it would be a manual upload by Gabriel, who offered to do it [S2].

**Transistor**
- Plans: Starter $19/mo (API, 50 private subscribers, 20k downloads/mo), Professional $49 (YouTube auto-post, 500 private subscribers, dynamic ads), Business $99 (3k private subscribers); unlimited shows and team members; yearly = 2 months free [S43].
- API: create draft episodes, presigned audio upload (5 GB, 600 s URL), publish or schedule with `published_at`, transcripts, private podcast subscribers (create in batch, revoke), analytics, webhooks; 10 requests per 10 seconds [S43].
- Apple Podcasts HLS video partner [S44].
- For Prakriti: the recommended host if RedCircle's audience is small (section 8, open question 1).

**Buzzsprout**
- Audio $15/mo, Audio + Video $25/mo (1080p to Apple, Spotify, YouTube), Multi-Podcast $30/mo; upload allowance shown as "up to 72 hrs/year" (FAQ says monthly, non-rollover); Magic Mastering add-on uses Auphonic algorithms; transcripts included; Cohost AI add-on [S42, S17].
- API: create episodes, three-step upload, publish/schedule, chapters, transcripts; 60 requests/minute [S42].
- Not an Apple HLS partner as of spring 2026 [S44].
- For Prakriti: skip; upload caps fight an archive backfill [inferred].

**Spotify for Creators**
- Free hosting with video; Partner Program eligibility (Jan 2026 criteria reported: 3 episodes, 2,000 hours consumed and 1,000 engaged listeners in 30 days) [S41] [unverified].
- No public creator upload API; a Distribution API lets partner hosts (Acast, Audioboom, Libsyn, Omny, Podigee) deliver video [S41].
- For Prakriti: list the show on Spotify through the RSS feed; no integration needed.

**YouTube podcast RSS ingestion**
- YouTube Studio can ingest a podcast RSS feed: verify ownership by emailed code, import all, a date range, or only future episodes; each episode becomes a still-image video from cover art; new entries arrive automatically; imports start private [S45]. Replacing an audio file in the feed does not update YouTube [S45].
- For Prakriti: free "audio podcast on YouTube" with no upload code [inferred].

**Apple Podcasts HLS video (Feb 2026)**
- Apple launched HLS video podcasts in Feb 2026 through hosting partners: Acast, ART19, Omny, SiriusXM/Simplecast, then Transistor, Audiomeans, PodBean, Captivate, RSS.com, Podigee, Podspace, Riverside, Ausha, Firstory; Buzzsprout, Libsyn and Spotify-owned hosts were missing in March [S44]. Standard RSS video remains available everywhere [S44].

### 2F. YouTube optimisation tools

**YouTube Studio: Test & Compare**
- Up to three thumbnails and/or titles per video; shown evenly; winner by watch-time share; "Winner" or "Preferred"; days to two weeks; **desktop YouTube Studio only**, requires advanced features, excludes Shorts, scheduled lives, premieres, private, made-for-kids and mature videos [S49].
- Data API: `thumbnails.set` uploads **one** thumbnail per call (about 50 units, 50 MB max since 2026-09-14); no experiment endpoint found [S48, S47].
- For Prakriti: integrate as a documented manual step.

**TubeBuddy / vidIQ**
- TubeBuddy's A/B testing is Legend-only (about $278/yr reported); a July 2026 review argues YouTube's free tool absorbed its main selling point [S50] [unverified]. vidIQ's testing feature is disputed between sources; Boost about $199/yr [S50].
- For Prakriti: skip both.

**YouTube automatic dubbing**
- Live for all eligible creators since 4 Feb 2026; on by default; excludes videos over 120 minutes, no speech, Content ID claims; English to Spanish and Spanish to English supported, with "expressive speech" in Spanish; creators can choose **Publish manually** to review dubs first [S51].
- For Prakriti: the free answer to Spanish reach on video (section 7E).

**YouTube Studio blur**
- Face blur (auto-detects faces, you pick which) and custom blur with tracking; desktop only; visual only (voices, captions and metadata untouched); saved edits cannot be reverted [S52].
- For Prakriti: one-off manual fix, not a pipeline step.

**Synthetic media disclosure**
- `status.containsSyntheticMedia` was added to `videos.insert` / `videos.update` on 2024-10-30 [S53]. A cloned voice saying something the person did not say is in scope of YouTube's disclosure rule; generic AI narration by itself reportedly is not [S53] [policy detail unverified on YouTube's help page].
- For Prakriti: set the flag whenever an ElevenLabs clone of Gabriel or Serenity speaks in the output (intro, outro, mid-roll).

### 2G. Digital minds, voices and avatars

**Delphi ("digital minds")** (delphi.ai now redirects to delphi.co)
- Free (first Digital Mind); Builder $79/mo (voice calling and chat, **1M training words**, 40+ languages); Scaler $299/mo (embeds, alerts, Slack); Immortal custom (**12M training words**); White-Glove adds API, SMS/WhatsApp, SSO [S54]. Voice from a 10-second sample [S54].
- For Prakriti: the archive is about 7.6M words across all speakers [inferred], beyond Builder. Build the knowledge base in Prakriti; Delphi stays an optional front end later, gated on consent.

**Coachvox AI**
- AI coach clone trained on books, transcripts, posts; about $99/mo; can charge clients for access [S55] [unverified].
- For Prakriti: same verdict as Delphi.

**HeyGen**
- Creator $29/mo ($24 annual), Pro $49, Business $149 + $20/seat; digital-twin avatars need the **person on camera to record a consent statement**, checked against the training clip; uploading a pre-recorded consent video is enterprise-only [S56].
- For Prakriti: deferred until Serenity consents [S1]. Skip.

**Synthesia**
- Personal avatars require recorded consent; Starter reported $19 to $29/mo; studio-quality custom avatars about $1,000/yr [S57] [unverified].
- For Prakriti: skip.

**ElevenLabs (TTS, Studio, PVC, Scribe, Dubbing, Music)**
- Plans: Free; Starter ($6, promo $1); Creator ($22, promo $11; 121k credits, 1 PVC slot); Pro $99 (600k credits, 1 PVC); Scale $299 (3 PVC); Business $990 (10 PVC) [S58].
- Professional Voice Cloning: 30 min minimum, 2 to 3 h recommended; single speaker, no background noise, no music, one consistent style, same language as intended use; voice verification required; **you can only clone your own voice, even with the other person's consent**; a clone can be shared by link [S59].
- Dubbing: 2,000 to 10,000 credits per minute [S58].
- Eleven Music: prohibited industries include **"religious organizations or institutions"** and political advocacy; no artist names or lyrics in prompts [S61].
- For Prakriti: integrate TTS for intros/outros/mid-rolls (pennies per episode); integrate nothing for cloning (each person clones on their own account); skip Dubbing (cost) and confirm Music terms first.

### 2H. Watch-folder and "set it and forget it" automation

| Tool | What it watches | What it does | Gap for Prakriti | Source |
|---|---|---|---|---|
| Auphonic watch folders | Dropbox, Google Drive, OneDrive (push); FTP, SFTP, S3, WebDAV (polled) | Masters audio with a preset, can publish | No iCloud; audio only | [S17, S18] |
| Repurpose.io | Dropbox, Google Drive, YouTube, Zoom, RSS | Cross-posts | No approval gate, no editing | [S38] |
| OpusClip auto import | Public YouTube channel or playlists | Clips and schedules | Public only; clips only | [S10] |
| Castmagic | RSS, Drive, YouTube, Zoom | Transcribes, writes text assets | Text only | [S15] |
| Headliner | RSS | Audiogram plus auto-post | Promo clip only | [S39] |
| Frame.io Transfer | Local folders | Uploads, resumes | Upload only | [S37] |
| Eddie AI Night Shift | NLE bins | Logs, syncs, rough cuts off-hours | Desktop NLE workflow | [S35] |
| Hazel 6 | Local folders | Rules can run any shell/Python script; $42 one-time | No state, no UI | [S68] |
| macOS Tahoe Shortcuts folder automation | Local folder (Added / Modified / Removed) | Runs a shortcut, immediately or after confirmation | "Pretty basic," shortcut must parse changes | [S69] |

Verdict: nobody watches a **local iCloud folder** and produces a full package. Prakriti's Mac agent does this itself (the Apple-API research track owns the mechanism). Hazel is a credible zero-code stopgap that calls a script [S68] [inferred].

### 2I. Transcription engines (for the cost math)

| Engine | Price per audio hour | Diarization | Notes | Source |
|---|---|---|---|---|
| AssemblyAI Universal-3.5 Pro | $0.21 | +$0.02 (standard), +$0.065 (experimental) | Speaker ID +$0.02; **PII audio redaction +$0.05** (bleeps); PII text redaction +$0.08 (47+ languages on Universal-2) | [S62] |
| AssemblyAI Universal-2 | $0.15 | +$0.02 | | [S62] |
| ElevenLabs Scribe v2 | $0.22 to $0.60 (sources conflict) | up to 32 speakers | keyterm prompting add-on | [S64] [unverified] |
| OpenAI gpt-4o-transcribe-diarize | about $0.36 | included | one listing flags deprecation 2027-04-15 | [S64] [unverified] |
| Deepgram Nova-3 | about $0.26 to $0.35 | about +$0.12 | | [S64] [unverified] |
| Local faster-whisper large-v3 + Parakeet (Ivan's pipeline) | $0 | **failed** in practice (split sentences, merged speakers; 47 CPU-min per 33 audio-min) | about 1.1x real time on an 8 GB M2; Whisper with `language=en` silently translates Spanish into English | [S65] |

AssemblyAI retention: uploads kept 2 days, URL-submitted audio 3 days unless deleted; async transcripts 30 days by default, shortenable with a TTL; zero retention for async is achieved by deleting after transcription; opt-out of model training available (public docs disagree on details) [S63].

### 2J. Privacy and redaction tools

| Tool | What | Price | Source |
|---|---|---|---|
| YouTube Studio blur | Face and custom blur, tracking, manual, desktop | Free | [S52] |
| Secure Redact | Auto-redacts faces, heads, plates | Free tier $8/extra min; Pro £189/mo; Advanced £309/mo (API) | [S66] [unverified] |
| VideoBgRemover redaction | Auto face blur, API included | $4.80/min falling to $2.50/min | [S66] |
| BlurMe | Browser face/body blur | from about $7 to $10/mo; API on enterprise | [S66] [unverified] |
| AssemblyAI PII audio redaction | Bleeps spoken PII (incl. person names) in returned audio | +$0.05/h | [S62] |

At $2.50 to $4.80 per minute, auto-blurring one 60-minute class costs $150 to $288; the archive would cost $135k to $259k [inferred arithmetic]. Visual redaction at archive scale is not a buy.

### 2K. Yoga-business platforms (adjacent, not competitors)

- **Uscreen**: video membership platform with branded apps (iOS, Apple TV, Android, Fire TV, Roku), subscriptions and one-time sales; AI transcription, searchable transcripts and auto-chapters reported added in 2025 [S67] [unverified].
- **Marvelous (formerly Namastream)**: began in 2015 for yoga teachers; online teaching, memberships, live-streaming; AI is limited to a sales-page builder and email tools [S67].
- **Momence**: studio operations; acquired by Clubessential (Jan 2025), which merged into Xplor (Mar 2026); AI Spot Filler and inbox agent [S67].
- Relevance: these are where a paid YTT library could live later. None processes raw recordings, so none competes with Prakriti's engine [inferred].

### 2L. Growati (the vendor Prakriti replaces)

- A Pune-based YouTube post-production automation tool that generated titles, descriptions, thumbnails and chapters; it built a make.com automation for Yoga Marga; closed 2026-10-07 [S73].
- Prakriti's text package must at least match Growati's four outputs on day one [inferred].

---

## 3. Feature matrix

Legend: **Y** yes · **P** partial, plan-gated or manual · **N** no · **?** not found. "Unatt." = runs unattended once configured.

| Product | Auto-ingest | Transcript + speakers | Audio cleanup | Silence/filler cut | Clips + reframe | Captions | Titles/desc/chapters/notes | Thumbnails | Publish | Unatt. | API | Library chat/KB | Voice/avatar | Privacy tooling | Spanish |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Descript [S3-S6] | P | Y | Y | Y | Y | Y | Y | ? | P | P | P (early) | N | Y | N | Y |
| Riverside [S12, S13] | N | Y | Y | Y | Y | Y | Y | Y | Y | N | P (Business) | P (MCP) | P | N | P |
| Async / Podcastle [S22] | N | Y | Y | P | Y | Y | ? | ? | P | N | P (TTS) | P | Y | N | Y |
| Auphonic [S16-S19] | Y | Y | Y | Y | N | P | P | N | Y | Y | Y | N | N | N | P |
| Cleanvoice [S20] | N | Y | Y | Y | N | N | P | N | N | P | Y | N | N | N | ? |
| Adobe Podcast [S21] | N | N | Y | N | N | N | N | N | N | N | N | N | N | N | ? |
| OpusClip [S7-S11] | Y (public YT) | P | P | ? | Y | Y | P | ? | Y | Y | Y (Pro) | N | P | N | Y |
| Vizard [S24] | ? | P | N | ? | Y | Y | P | N | Y | P | Y | N | N | N | ? |
| Munch [S27] | ? | P | N | N | Y | Y | Y | N | Y | ? | ? | N | N | N | ? |
| Klap [S25] | ? | P | N | N | Y | Y | ? | N | Y | ? | Y | N | ? | N | P |
| Submagic [S26] | N | P | N | P | Y (add-on) | Y | P | N | P | ? | Y | N | P | N | ? |
| Choppity [S28] | ? | P | N | N | Y | Y | ? | N | Y | ? | ? | N | N | N | Y |
| Captions / Mirage [S30] | N | P | N | Y | Y | Y | N | N | ? | N | ? | N | Y | N | Y |
| CapCut [S31] | N | P | P | P | Y (Pro) | Y | N | N | P | N | N | N | P | N (bad license) | Y |
| Gling [S32] | N | Y | N | Y | N | Y | Y | N | N | N | N | N | N | N | ? |
| TimeBolt / Recut [S33, S34] | N | N | N | Y | N | N | N | N | N | N | N | N | N | N | n/a |
| Eddie AI [S35] | P | Y | ? | Y | P | Y | N | N | N | P | Y (MCP) | N | P | N | ? |
| Jumper [S36] | N | Y (local) | N | N | N | N | N | N | N | N | P | P (search) | N | P (local) | ? |
| Frame.io [S37] | Y (upload) | ? | N | N | N | N | N | N | N | P | Y | N | N | N | n/a |
| Castmagic [S14, S15] | Y (RSS etc.) | Y | N | N | P | P | Y | P | N | Y | Y | Y (MCP) | N | N | Y |
| Headliner [S39] | Y (RSS) | P | N | N | P | Y | P | N | Y | Y | N | N | N | N | ? |
| Repurpose.io [S38] | Y | N | N | N | N | N | P | N | Y | Y | N | N | N | N | n/a |
| RedCircle [S40] | N | P | N | N | N | N | N | N | Y (YT on Pro) | P | **N (none found)** | N | N | N | ? |
| Transistor [S43] | N | P (add-on) | N | N | N | N | N | N | Y (YT on Pro) | P | Y | N | N | P (private feeds) | ? |
| Buzzsprout [S42] | N | Y | P | N | N | N | P | N | Y | P | Y | N | N | N | ? |
| YouTube Studio [S45-S53] | P (RSS) | P | N | N | N | Y | N | P (Test & Compare) | Y | N | Y | N | P (auto-dub) | P (blur) | Y |
| Delphi [S54] | P | N | N | N | N | N | N | N | N | n/a | P | Y | Y | ? | Y |
| HeyGen [S56] | N | N | N | N | N | N | N | N | N | N | Y | N | Y | P (consent check) | Y |
| ElevenLabs [S58-S61] | N | Y (Scribe) | Y (Isolator) | N | N | N | N | N | N | n/a | Y | P | Y | P (own-voice rule) | Y |
| AssemblyAI [S62, S63] | N | Y | N | N | N | N | P | N | N | Y | Y | N | N | **Y (PII bleep)** | Y |
| **Prakriti (target)** | **Y (local iCloud + archive)** | **Y** | **Y (via Auphonic)** | **Y** | **Y** | **Y** | **Y** | **Y (3 options)** | **Y (gated)** | **Y** | **Y (MCP)** | **Y (per teacher)** | **P (datasets, consent-gated)** | **Y (consent registry)** | **Y** |

---

## 4. What the market converges on (the pattern worth copying)

1. **Review before publish is now standard even in "automatic" tools**: Auphonic "Review before Publishing" [S19], Vizard's preview then "Go" [S24], YouTube auto-dub "Publish manually" [S51], YouTube RSS imports landing private [S45]. Prakriti's human-yes rule [S1] is the market norm, not a compromise.
2. **Everyone added an agent or MCP door in 2026**: Descript MCP [S4], Riverside MCP [S12], Castmagic MCP [S15], Eddie (about 100 MCP tools) [S35], Jumper agent control [S36], OpusClip MCP connector [S7]. Prakriti should expose one so Sonny can query and operate it.
3. **Credits per source minute is the dominant pricing model** for clippers (OpusClip, Vizard, Submagic, Eddie) [S7, S24, S26, S35]. It punishes archives. Any vendor in the chain should receive pre-trimmed segments, never whole recordings [inferred].
4. **Vendor churn is high**: Podcastle became Async [S22], Captions became Mirage [S30], Namastream became Marvelous and Momence changed owners twice [S67], Eddie dropped subscriptions for credits [S35]. Keep vendors behind thin adapters so one can be swapped in an afternoon [inferred].

---

## 5. (a) Features that exist elsewhere and Prakriti should have

How column: **Integrate** = call the vendor's API; **Replicate** = build it; **Native** = use a free platform feature; **Skip/Defer**.

| # | Feature | Who has it | How for Prakriti | Effort | Notes |
|---|---|---|---|---|---|
| 1 | Auto-ingest from a source | OpusClip [S10], Castmagic [S15], Auphonic [S18], Repurpose [S38] | Replicate: Mac agent watches the iCloud `Studio Recordings ` folder; archive importer reads a Google Takeout export [S70] | M | Wait for iCloud download to finish and for OBS to stop writing (stable size) before ingesting [inferred]. Read the OBS `.txt` sidecar [S1]. |
| 2 | One-tap review before publish | Auphonic [S19], Vizard [S24], YouTube [S51] | Replicate: per-package approval screen; nothing public without a named person's yes | S to M | Matches the standing rule [S1]. |
| 3 | A score per output | OpusClip Virality Score [S7] | Replicate, redefined: audio, video, message (Ivan's three) [S1] plus **privacy** and **accuracy** sub-scores | M | Vendors score virality; Yoga Marga needs "is this safe and true." |
| 4 | Prompted moment finding | OpusClip ClipAnything [S11], Riverside topic clips [S13] | Replicate with Claude over the timestamped transcript | S to M | Two-pass: cheap triage on everything, deep pass on the top slice (section 8). |
| 5 | Reframe to 9:16 | OpusClip, Choppity, Klap [S7, S28, S25] | Native first: turn OBS's vertical canvas back on (it existed 2026-09-06) [S75]; else fixed crop for a static talking head; face-tracking later | S (crop) / M (tracking) | Archive is 16:9 only. |
| 6 | Captions burned into shorts | OpusClip, Submagic, Captions [S7, S26, S30] | Replicate: calm, typographic captions from word timestamps (ffmpeg ASS) | M | Ivan's taste rules out emoji and pop effects [S1]. |
| 7 | Filler and silence cutting | Descript, Gling, Cleanvoice, Auphonic [S3, S32, S20, S16] | Integrate Auphonic's cutter for podcast audio; skip for archive ("no major edits") [S2] | S | |
| 8 | Loudness, levelling, noise, reverb | Auphonic, Adobe, Studio Sound, Magic Audio [S16, S21, S3, S13] | Integrate Auphonic API | S | |
| 9 | Titles, descriptions, chapters, show notes | Castmagic [S14], Auphonic [S16], Gling [S32], Co-Creator [S13], Growati [S73] | Replicate with Claude; every claim must be traceable to a transcript quote | S | Serenity's accuracy condition [S1]. |
| 10 | Audio episodes as YouTube videos | Headliner [S39], Auphonic [S17], RedCircle [S40] | Native: YouTube RSS ingestion wraps episodes in cover art [S45]; or a still-image render | S | |
| 11 | Multi-destination publishing + schedule | OpusClip, Vizard, Repurpose, Munch [S7, S24, S38, S27] | Replicate for YouTube (Data API) and podcast host (Transistor API); defer TikTok/IG/LinkedIn until asked | M | |
| 12 | Library chat with citations | Castmagic Magic Chat [S15], Delphi [S54] | Replicate: per-teacher knowledge base, answers cite recording + timecode | M | |
| 13 | MCP connector | Descript, Riverside, Castmagic, Eddie, OpusClip [S4, S12, S15, S35, S7] | Replicate: Prakriti MCP server (read library, queue status, draft packages) | M | Lets Sonny run it from a chat. |
| 14 | Visual search across footage | Jumper [S36] | Defer: on-device vision tagging later | L | Local processing fits privacy. |
| 15 | Overnight queue | Eddie Night Shift [S35] | Replicate: heavy jobs run when the Mac is idle and on power | S | Ivan's MacBook travels [S1]. |
| 16 | NLE handoff | Eddie, Gling, OpusClip, Descript [S35, S32, S7, S4] | Replicate: export a cut list as FCPXML for Final Cut | M | For the rare flagship polish. |
| 17 | Private podcast feed | Transistor [S43] | Integrate | S | Home for full classes with students (section 7B). |
| 18 | Spanish dubbing on YouTube | YouTube auto-dub [S51] | Native: leave on, set "Publish manually" | S | Free; under 120 min only. |
| 19 | Thumbnail/title A/B test | YouTube Test & Compare [S49], TubeBuddy [S50] | Native: Prakriti makes 3 thumbnails and 3 titles; person loads them in Studio | S | Not automatable via API [S48, S49]. Skip TubeBuddy. |
| 20 | Synthetic media flag | YouTube API [S53] | Replicate: set `containsSyntheticMedia` when a cloned voice is used | S | |
| 21 | Transcripts in the RSS feed | Buzzsprout, Transistor [S42, S43] | Integrate via host (`transcript_text`) | S | Accessibility and search. |
| 22 | Brand templates and vocabulary | OpusClip [S7, S11], Descript Brand Studio [S3] | Replicate: style config plus a glossary (Sanskrit, names, lineage terms) fed to ASR prompts and captions | S | See 7D. |
| 23 | Performance feedback loop | OpusClip clip analytics [S7], Klap analytics [S25], Transistor analytics [S43] | Replicate later: pull YouTube Analytics and host downloads back into the score | M | Phase after first publishing month. |
| 24 | Digital mind with voice calls | Delphi [S54], Coachvox [S55] | Defer: build the KB; evaluate Delphi as a front end only after consent | L | |
| 25 | Avatars | HeyGen, Synthesia [S56, S57] | Skip until Serenity consents [S1] | n/a | Each person records their own consent with these vendors anyway [S56]. |
| 26 | Face blur | YouTube blur [S52], Secure Redact [S66] | Skip at scale; route classes to audio-only and private feeds; YouTube blur for a one-off | n/a | Cost in 2J. |
| 27 | Spoken-name bleeping | AssemblyAI PII audio redaction [S62] | Integrate (or replicate with a known-names list and word timestamps) | S | Student names out of public audio [S1]. |

---

## 6. Features I would not copy

- **Virality-first auto-posting** (OpusClip, Munch, Vizard) [S7, S27, S24]: optimises the wrong target for a teacher whose condition is accuracy [S1].
- **Hook rewriting and emoji highlights** (OpusClip "auto hook / emoji highlights") [S7]: conflicts with "describe, never sell" [S1].
- **AI B-roll and stock footage** (OpusClip, Riverside) [S7, S13]: decoration on teachings that work as audio [S2].
- **Eye-contact correction** (Descript, Mirage) [S3, S30]: alters a teacher's face; needs consent like an avatar [inferred].
- **Archive.org export** (Auphonic) [S17]: permanent public copies of material that may contain students [inferred].

---

## 7. (b) What no product combines, which Prakriti uniquely needs

### 7A. A consent registry that every output checks

Nobody in the matrix models consent beyond a one-time avatar consent clip (HeyGen) [S56] or ElevenLabs' own-voice rule [S59].

Spec [inferred]:
- **People**: Gabriel, Serenity, guests, students (named or anonymous "Student 3, 2026-09-16").
- **Scopes per person**: name may appear · voice may appear publicly · face may appear publicly · words may enter a knowledge base · voice may be used for a voice model · likeness for an avatar · private-feed only.
- **State**: granted / not asked / declined / revoked, with date and evidence (a signed release, a recorded statement, a message). A phone release app exists for this ($12.99, Easy Release) but is photo-oriented and had delivery complaints in July 2026 [S76].
- **Enforcement**: every package carries the list of speakers and faces it contains; the publish button is disabled while any scope is unresolved; revoking consent produces a takedown list of every live output containing that person.
- **Defaults**: students are "not asked" and therefore private; Serenity's voice model and avatar are "not asked" [S1].

### 7B. Privacy-aware handling of classes with students

Serenity's standing condition: students' voices and names out of public content [S1]. Classes include named students speaking [S1].

Pipeline nobody sells as one unit [inferred]:
1. Diarize (cloud, section 8) and label the teacher by voice match against known samples; everyone else is "other."
2. **Public cut**: keep teacher-only spans; drop or duck student spans; bleep any spoken student name (AssemblyAI PII audio redaction or a names list) [S62].
3. **Audio-only for classes**: no faces, so no blur problem (2J costs).
4. **Private feed**: the full, unredacted class goes to a students-only feed (Transistor private podcast, 50 to 500+ subscribers by plan) [S43]. This turns Serenity's restriction into a member benefit instead of a deletion [inferred].
5. **Frame check for video**: if more than one face is ever visible, the video output is blocked from public until a person reviews it [inferred].
6. **Processor rule**: if Serenity's answer forbids third-party processing of student audio, route classes through the local engine (no diarization, teacher-only manual marking) and send only consent-cleared spans to cloud vendors [S65, S63].

### 7C. Lineage and teacher knowledge bases

Castmagic and Delphi offer library chat [S15, S54], but none of them does:
- **Per-teacher separation** by speaker attribution (Gabriel's KB, Serenity's KB) from mixed recordings [S1].
- **Lineage and source tags**: tradition, text (e.g. Yoga Sutras chapter and sutra), practice, asana, theme; every passage linked to recording and timecode [inferred].
- **Teacher review**: anything the teacher marks "not how I'd say it" is excluded from public use and from voice/persona training, because accuracy is Serenity's condition [S1].
- **Scale**: about 7.6M words; Delphi Builder caps at 1M training words [S54].
- **Syllabus mapping**: map passages to the three YTT syllabi Serenity owes [S1].

### 7D. Archive-scale backfill of hundreds of hours

Every clipper charges by source minute and caps monthly [S7, S24, S26]; Castmagic's library caps at 30 to 400 hours [S14]; Descript caps at 30 to 40 media hours a month [S3].

What Prakriti needs [inferred unless cited]:
- **Bulk acquisition**: Google Takeout of the channel (from the Brand Account if the channel is one); Studio downloads are limited to about 5 a day at 720p [S70] [unverified].
- **Triage first, depth later**: cheap pass on all 900 hours (metadata, audio-only transcript, quality score, topic, speakers, privacy flags), deep pass only on the top slice.
- **Resumable, idempotent queue**: a 900-item job must survive the laptop closing.
- **Video stays where it is**: for an archive talk, "publish video" means flipping the existing unlisted video to public with new metadata and thumbnail, not a new upload [S1, inferred]. Confirm that an unaudited API project may change visibility on videos uploaded through Studio [unverified]; if not, the visibility flip is the human's step.
- **Trickle schedule**: the 25-by-Friday-6-November target [S1] at 3 to 4 a week rather than a dump.
- **Glossary**: Sanskrit terms, teacher and student names, place names fed to ASR as a vocabulary prompt; the transcription skill found the prompt matters more than any decoder setting [S65].

### 7E. Spanish

Whether recordings or audience are Spanish-speaking is not established in the brief (open question 3). If yes:
- Transcription must auto-detect language and handle code-switching; Whisper with `language=en` silently translates Spanish to English [S65].
- Video reach: YouTube auto-dub English to Spanish (expressive) and Spanish to English, free, under 120 minutes, with manual review [S51].
- Text: titles, descriptions and chapters in both languages (YouTube supports translated metadata) [inferred].
- Podcast: a Spanish feed via ElevenLabs Dubbing costs 2,000 to 10,000 credits a minute [S58], so 120k to 600k credits per hour; defer [inferred].
- Voice models: PVC samples must be in the language the clone will speak [S59], so a bilingual teacher needs per-language datasets [inferred].

### 7F. Voice-model datasets prepared, never cloned

- Output per person: about 30 min minimum, 2 to 3 h ideal, single speaker, no music, no noise, one style [S59], exported only when that person's voice-model scope is "granted" (7A).
- Cloning happens on the person's own ElevenLabs account, then shared [S59]. Gabriel cannot clone Serenity from his account [S59].
- Voice Isolator's 1-hour file limit means the dataset builder should emit sub-hour files [S60].

### 7G. Disclosure and honesty defaults

- Cloned-voice intros set YouTube's synthetic flag [S53] and say so in the show notes [inferred].
- Music beds: Eleven Music's prohibited-industries clause [S61] needs an answer before use; alternatives are a licensed library track or a one-time commissioned sting [inferred].

---

## 8. (c) Build vs buy, with the cost math at Yoga Marga's scale

Scale: archive **900 h** (54,000 min) once; new **5 h/month measured** [S75] to **16 h/month planned** [S1].

### 8.1 Capability by capability

**Transcription with speakers: BUY (cloud API), keep local as the private fallback**
- AssemblyAI U-3.5 Pro + diarization = $0.23/h [S62]. Archive: 900 x $0.23 = **$207**. With speaker ID, PII audio bleep and PII text redaction ($0.38/h): **$342**. New: $1.15 to $3.70 a month.
- ElevenLabs Scribe v2: $198 to $540 for the archive (rate conflict) [S64]. OpenAI diarize: about $324 [S64].
- Local: $0 cash, but about 900 compute-hours at the measured 1.1x real time on an 8 GB M2 (the M5 Pro is faster; unmeasured), and local diarization failed [S65]. Speaker labels are the product here (per-teacher KBs, student handling), so buy.
- Privacy: opt out of training, delete after retrieval, set the shortest TTL [S63]; route classes local-only if Serenity requires it (7B.6).

**Analysis (scores, moments, titles, chapters, KB tags): BUILD on Claude**
- Prices: Opus 5.5 $4 / $20 per M tokens; Sonnet 5.5 $2 / $10; Haiku 5.5 $0.10 / $0.50; Batch API at 50% [S72].
- Archive, about 10M to 13M input tokens, about 3k output tokens per recording [inferred]:
  - Haiku 5.5 triage on all 900: about **$2 to $5**.
  - Sonnet 5.5 full pass on all 900: about $47 to $62; batch about $24 to $31.
  - Opus 5.5 deep pass on top 100 (about 1.2M in, 0.5M out incl. thinking): about **$15 to $25** [inferred; Opus 5.5 always thinks, so output runs higher than the visible text [S72]].
- New: under $5 a month at any model choice [inferred].
- Measure on ten real recordings before trusting these numbers; Ivan's measured per-call costs in memory were higher than token math suggests [inferred].

**Loudness, levelling, noise, filler/silence cutting: BUY Auphonic, but only for what gets published**
- Whole archive: 1,000 h one-time pack **$1,045** [S16]. Not recommended: most of it will never be published [inferred].
- Published archive slice: 25 pieces by 6 Nov (about 25 to 30 h) = 25 h pack **$55** or 50 h **$100**; the first 100 published hours = **$171** [S16].
- New: 21 h/month plan **$30/mo or $25/mo yearly ($300/yr)** covers both the measured and planned cadence [S16].
- Build alternative: ffmpeg two-pass loudness normalisation, $0, effort S, but no multi-speaker levelling, noise or reverb models [inferred]. Use it for previews and KB audio only.

**Shorts (selection + reframe + captions): BUILD, benchmark once**
- OpusClip feeding whole recordings: new at 5 h/mo = 300 credits = exactly Pro ($29) [S7]; at 16 h/mo = 960 credits, beyond Pro, so Business (custom) [S7, S8]. Archive: 54,000 credits, about 15 years of annual Pro allowances [S8, inferred]. Not viable.
- OpusClip fed **pre-trimmed** segments (Prakriti picks 3 to 5 windows, about 12 min per recording) [inferred]: 5 to 15 recordings a month x 12 = 60 to 180 credits, inside Starter ($15) or Pro ($29) [S7]; top 100 archive talks x 12 = 1,200 credits.
- Build: selection already exists from the analysis pass; reframe is free if OBS's vertical canvas is on [S75] or a fixed crop for a static camera; captions via ffmpeg; effort M; marginal cost about $0 [inferred].
- Recommendation: build, and buy one month of OpusClip Starter ($15) to compare output on the same three recordings. Switch to the pre-trimmed OpusClip route only if Gabriel prefers its look; even then, selection stays in Prakriti because consent and accuracy live there [inferred].

**Thumbnails: BUILD; testing is NATIVE**
- Prakriti picks frames and sets type; YouTube Test & Compare is free [S49]. TubeBuddy Legend (about $278/yr) adds nothing needed [S50]. The existing PLAN's "prompts, not images" for v1 is compatible [S74].

**Podcast hosting: BUY Transistor (if RedCircle's audience is small), else keep RedCircle with a manual step**
- Transistor Starter $19/mo ($190/yr), API and 50 private subscribers; Professional $49/mo ($490/yr) for YouTube auto-post and 500 private subscribers [S43].
- RedCircle: free to $29.99/mo; no API found, so a person uploads each episode [S40, S2].
- Self-host RSS on Cloudflare R2: storage $0.015/GB-month, egress free, 10 GB free [S71]. Archive audio at 96 kbps mono is about 43 MB/h, so about 39 GB, so about **$0.44/month** [inferred arithmetic]. Effort M to build the feed; loses host analytics and Apple HLS partner support [S44]. A fallback, not the first choice.

**YouTube publishing: BUILD on the Data API, accept private-until-approved**
- Uploads: own quota bucket since 2026-06-01; per-upload cost cut from about 1,600 to about 100 units on 2025-12-04 [S47]. The method page lists 1 unit in the Video Uploads bucket with a limit of 100 calls/day [S46]. Either way, far above the cadence.
- Unaudited projects: uploads locked to private until a compliance audit [S46]. Recommendation: upload private or scheduled, and let the approval step (a person) make it public; apply for the audit only if the team later wants Prakriti to flip visibility itself [inferred].
- Audio-only episodes on YouTube: native RSS ingestion, free [S45].

**Voice (intros, outros, mid-rolls): BUY ElevenLabs Creator**
- About $22/mo on Gabriel's account (1 PVC slot, 121k credits) [S58]. A 60-second intro is about 900 characters, so dozens of episodes a month use a fraction of the allowance [inferred].
- Serenity's clone, if she consents, lives on her own account [S59].

**Knowledge base: BUILD; Delphi optional later**
- Delphi Builder $79/mo ($948/yr) caps at 1M training words; the archive is about 7.6M [S54, inferred]. Building on the existing Cloudflare stack (D1, R2, Workers) [S1] costs pennies in storage; effort M to L.

**Face blur and dubbing: SKIP at scale**
- Blur: $135k to $259k for the archive at published per-minute rates (2J). Dubbing: ElevenLabs 2k to 10k credits per minute [S58]. Use audio-only for classes and YouTube auto-dub for video [S51].

**Storage of video masters: keep on local/RAID, not R2**
- 900 h x 1 to 2.8 GB/h = 0.9 to 2.5 TB [S75, inferred]; in R2 that is $13.50 to $38/month [S71]. Studio files alone are about 2.8 GB/h [S75]. Keep masters on the studio RAID [S1] and put audio and derivatives in R2 [inferred].

### 8.2 Year-one totals

**Recommended build-plus-buy stack (archive included)**

| Line | Low | High | Basis |
|---|---|---|---|
| AssemblyAI, archive one-time | $207 | $342 | [S62] |
| AssemblyAI, new (12 months) | $14 | $45 | [S62] |
| Claude analysis, archive (triage + deep pass on top 100) | $20 | $100 | [S72], inferred |
| Claude analysis, new (12 months) | $12 | $60 | inferred |
| Auphonic, published archive (first 100 h) | $171 | $171 | [S16] |
| Auphonic, new (21 h plan, yearly) | $300 | $300 | [S16] |
| Transistor (Starter or Professional, yearly) | $190 | $490 | [S43] |
| ElevenLabs Creator (12 months) | $264 | $264 | [S58] |
| R2 (audio + derivatives) | $0 | $6 | [S71] |
| OpusClip benchmark month | $15 | $29 | [S7] |
| **Total** | **about $1,190** | **about $1,810** | |

**For contrast: a SaaS stack approximating Prakriti (new material only)**

| Line | Per year | Basis |
|---|---|---|
| Descript Creator | about $288 | [S3] |
| OpusClip Pro, monthly | $348 | [S7] |
| Castmagic Starter | $579 | [S14] |
| Auphonic 21 h, yearly | $300 | [S16] |
| RedCircle Pro | about $300 to $360 | [S40] |
| Delphi Builder | $948 | [S54] |
| TubeBuddy Legend | about $278 | [S50] |
| **Total** | **about $3,040 to $3,100** | |

That stack still would not process the archive (30 media h/month, 300 clip min/month, 100 library hours, 1M training words) [S3, S7, S14, S54], would not run unattended end to end, and has no consent or student handling (section 7) [inferred]. The SaaS route costs more and does less; the build route's real cost is Ivan's and Sonny's time, which this table does not count.

---

## 9. Traps and stale truths found on this track

1. **Stale truth in the vault and plan**: "YouTube's API upload quota (~6 uploads/day on a default project)" in `20 Projects/Gabriel Galindo — Content Engine.md` [S73] and `content-engine/PLAN.md` line 95 [S74]. Replaced by the 2025-12 and 2026-06 quota changes [S47]. The live constraint is the private-until-audit rule [S46].
2. **Single point of failure, podcast**: RedCircle has no API found [S40]; "autonomous" publishing there means Gabriel uploading by hand, the exact step he says they do not do [S2].
3. **Consent architecture trap**: planning "Gabriel trains the Serenity model" fails at ElevenLabs by policy [S59]; HeyGen likewise needs the person on camera [S56].
4. **Music licence trap**: Eleven Music prohibited industries include religious organizations [S61]; yoga content could be read that way [inferred].
5. **Third-party licence trap**: CapCut's reported perpetual license over uploaded faces and voices [S31].
6. **Coverage trap on cheap transcription**: a fluent transcript can silently cover 20% of a recording; the coverage check from Ivan's pipeline must run on every archive file [S65].
7. **Takeout quality trap**: older uploads may come back re-encoded at up to 1080p, and Brand Account channels must export from the Brand Account [S70] [unverified].
8. **Vendor churn trap**: four rebrands or ownership changes in this landscape in 2026 alone [S22, S30, S67]; keep adapters thin.
9. **Capture trap**: OBS produced a native vertical file on 2026-09-06 and none since [S75]; if it was dropped by accident, every short will be a crop.

---

## 10. Sources

[S1] `~/Code/prakriti/research/BRIEF.md` (read 2026-10-08)
[S2] `~/Code/prakriti/research/2026-10-07-call-gabriel-transcript.txt`
[S3] https://www.descript.com/pricing
[S4] https://www.descript.com/api
[S5] https://www.createwith.com/tool/descript/updates/descript-adds-claude-opus-48-workflows-to-underlord-ai-assistant (third-party) · https://feedback.descript.com/feature-requests/p/get-underlord-to-auto-edit-using-my-past-projects-saved-layouts
[S6] https://www.descript.com/transcription-languages · https://www.descript.com/blog/article/new-in-descript-transcription-in-23-languages · https://descript.com/tools/spanish-audio-to-text
[S7] https://www.opus.pro/pricing (fetched, and page HTML read 2026-10-08)
[S8] https://www.castmagic.io/blog/opus-clip-pricing (third-party) · https://creatify.ai/blog/opusclip-pricing-plans-and-what-you-ll-actually-pay-in-2026 (third-party)
[S9] https://www.opus.pro/blog/podcast-to-shorts-api
[S10] https://help.opus.pro/docs/article/auto-import
[S11] https://www.opus.pro/blog/opusclip-celebrates-30m-in-funding-and-the-launch-of-clipanything · https://www.opus.pro/blog/multi-language-captions-api · https://www.opus.pro/tools/translate-spanish-video-to-english
[S12] https://riverside.com/pricing (page self-labelled as possibly out of date)
[S13] https://riverside.com/university-videos/chat-based-editing · https://riverside.com/blog/meet-co-creator · https://support.riverside.com/hc/en-us/articles/28827095144733 · https://riverside.com/blog/magic-clips
[S14] https://www.castmagic.io/pricing
[S15] https://www.castmagic.io/claude · https://www.castmagic.io/use-cases/podcast-networks · https://appsumo.com/products/castmagic-add-on-ai-transcription-hours/ · https://dupple.com/reviews/castmagic
[S16] https://auphonic.com/pricing (prices read from the page's `data-price-dollar` attributes, 2026-10-08)
[S17] https://auphonic.com/help/web/services.html
[S18] https://www.auphonic.com/help/web/watch.html · https://auphonic.com/blog/2022/07/07/auphonic-watch-folders-release/ · https://auphonic.com/workflows-api
[S19] https://auphonic.com/blog/2026/03/06/new-external-services-rsscom-acast-scrybecast/
[S20] https://cleanvoice.ai/pricing/
[S21] https://www.feisworld.com/blog/adobe-podcast-enhance-speech-v2 (third-party) · https://developer.adobe.com/audio-video-firefly-services/getting-started/usage/
[S22] https://async.com/pricing · https://async.com/blog/podcastle-is-now-async · https://async.com/blog/from-podcastle-to-async/
[S23] https://swellai.com/ · https://www.videosdk.live/ai-apps/swellai · https://getcoai.com/tool-detail/swellai/134200/ (third-party)
[S24] https://vizard.ai/pricing · https://vizard.ai/api
[S25] https://klap.app/pricing · https://klap.app/api
[S26] https://www.submagic.co/pricing (page HTML) · https://www.hooked.so/compare/submagic-pricing (third-party) · https://www.blotato.com/blog/submagic-alternatives (competitor)
[S27] https://sonary.com/reviews/getmunch/ · https://www.creatorstackclub.com/software/munch (third-party)
[S28] https://www.choppity.com/blog/best-ai-podcast-clip-makers-generators (self-published) · https://www.foximusic.com/blog/?p=621
[S29] https://www.saasworthy.com/product/momento-fm/pricing · https://blubrry.com/?p=87099
[S30] https://www.eesel.ai/blog/captions-ai · https://sacra.com/research/mirage · https://apps.apple.com/us/app/captions-ai-short-form-video/id1541407007
[S31] https://async.com/blog/capcut-terms-of-service/ · https://www.techradar.com/pro/popular-video-editing-app-capcut-wants-to-use-any-content-you-produce-for-free-forever-heres-what-you-should-know · https://www.nemovideo.com/blog/capcut-pro-pricing-2026
[S32] https://gling.notion.site/Gling-s-Pricing-Policy-3f09d1973cc944ed844a65fedce7a7b5 · https://techjockey.com/detail/gling
[S33] https://blitzcutai.com/blog/timebolt-pricing-2026 (competitor) · https://toolradar.com/tools/timebolt/pricing
[S34] https://www.feisworld.com/blog/recut · https://blitzcutai.com/blog/timebolt-vs-recut-vs-blitzcut (competitor)
[S35] https://nofilmschool.com/eddie-ai-updates-pricing · https://www.redsharknews.com/eddie-ai-nab-2026-ai-video-editing-rough-cut · https://www.cined.com/eddie-ai-extension-for-davinci-resolve-released-virtual-editing-assistant/ · https://makerstack.co/reviews/eddie-ai-review/
[S36] https://www.provideocoalition.com/review-ai-driven-video-search-with-jumper/ · https://fcp.cafe/news/20260226/ · https://topai.tools/t/jumper
[S37] https://www.capterra.com/p/148214/Frame-io/pricing/ · https://recurdash.com/subscription-pricing/frame-io · https://hedge.co/blog/transfer-straight-into-frame-io-65d422640b7c · https://next.developer.frame.io/platform/v2/index
[S38] https://repurpose.io/pricing/ · https://repurpose.io/podcast-dropbox · https://support.repurpose.io/en/category/workflows-bibsku/
[S39] https://learn.headliner.app/hc/en-us/articles/26110743442967 · https://www.creatorstackclub.com/software/headliner/pricing · https://soundsprofitable.com/press-release/headliner-expands-auto-posting-capabilities-to-include-instagram-facebook-and-linkedin-for-podcast-videos
[S40] https://redcircle.com/pricing · https://support.redcircle.com/distributing-your-podcast-to-youtube · https://support.redcircle.com/uploading-an-episode · https://www.skills.sh/membranedev/application-skills/redcircle-api (name collision evidence)
[S41] https://thepodcastconsultant.com/blog/spotify-for-creators · https://radioinfo.com.au/podcast-info/spotify-expands-podcast-partner-program-and-marks-10b-milestone/
[S42] https://www.buzzsprout.com/pricing · https://github.com/buzzsprout/buzzsprout-api
[S43] https://transistor.fm/pricing/ · https://developers.transistor.fm/
[S44] https://www.apple.com/newsroom/2026/02/apple-introduces-a-new-video-podcast-experience-on-apple-podcasts/ · https://transistor.fm/apple-podcasts-video/ · https://tritondigital.com/news-item/March-16-2026/new-partners-announced-for-apple-podcasts-video · https://www.podcastnewsdaily.com/news/apple-podcasts-rolls-out-hls-video-expanding-podcasting-into-dual-format-era/article_538ee10f-74dc-4288-9d09-7ca0cb9e18f8.html
[S45] https://support.google.com/youtube/answer/13525207 · https://9to5google.com/?p=602070 · https://techcrunch.com/?p=2662754
[S46] https://developers.google.com/youtube/v3/docs/videos/insert
[S47] https://developers.google.com/youtube/v3/revision_history
[S48] https://developers.google.com/youtube/v3/docs/thumbnails/set
[S49] https://support.google.com/youtube/answer/13861714 · https://support.google.com/youtube/answer/16391400
[S50] https://1of10.com/blog/tubebuddy-pricing-review/ · https://vidiq.com/compare/vidiq-vs-tubebuddy/ · https://creaticalc.com/vidiq-vs-tubebuddy · https://thumbnailtest.com/guides/vidiq-vs-tubebuddy/
[S51] https://support.google.com/youtube/answer/15569972 · https://outlierkit.com/resources/youtube-auto-dubbing-all-creators-global-growth-2026/
[S52] https://support.google.com/youtube/answer/9057652 · https://www.creatoressentials.com/glossary/youtube-blur-tool/
[S53] https://developers.google.com/youtube/v3/revision_history (2024-10-30 entry) · https://minimatters.com/youtube-altered-or-synthetic-content-disclosure/ (third-party)
[S54] https://www.delphi.co/pricing
[S55] https://www.xpay.sh/saas-pricing/coachvox-ai/ · https://quso.ai/blog/coachvox-ai-review-features-pros-cons-alternatives.html
[S56] https://www.heygen.com/pricing · https://developers.heygen.com/docs/avatar-consent · https://www.heygen.com/moderation-policy
[S57] https://creatify.ai/blog/synthesia-pricing-(2026)-plans-credits-and-what-you-ll-actually-pay · https://www.feisworld.com/blog/synthesia
[S58] https://elevenlabs.io/pricing
[S59] https://elevenlabs.io/docs/product-guides/voices/voice-cloning/professional-voice-cloning
[S60] https://elevenlabs.io/docs/overview/capabilities/voice-isolator
[S61] https://elevenlabs.io/music-terms · https://elevenlabs.io/docs/overview/capabilities/music
[S62] https://www.assemblyai.com/pricing
[S63] https://assemblyai.com/docs/data-retention-and-model-training · https://www.assemblyai.com/docs/faq/how-long-are-files-submitted-to-the-api-retained · https://www.assemblyai.com/docs/faq/does-assemblyai-offer-zero-data-retention
[S64] https://diyai.io/ai-tools/speech-to-text/speech-to-text-api-pricing/ · https://costgoat.com/pricing/openai-transcription · https://aividpipeline.com/blog/elevenlabs-scribe-v2-guide-2026 · https://convertaudiototext.com/blog/deepgram-nova-3-explained (all third-party)
[S65] `~/.claude/skills/transcribe-audio/SKILL.md`
[S66] https://capterra.com/p/246571/Secure-Redact/ · https://videobgremover.com/blur/redaction · https://www.capterra.com/p/10047001/BlurMe-AI-Face-Blur/
[S67] https://heymarvelous.com/namastream-announcement · https://www.uscreen.tv/yoga-membership-platform/ · https://vibefam.com/momence-review-pricing-features-pros-cons-2026/ · https://elitecontentmarketer.com/uscreen-review/
[S68] https://www.noodlesoft.com/?p=1852 (Hazel 6 FAQ) · https://www.noodlesoft.com/?p=977 (shell scripts)
[S69] https://sixcolors.com/post/2025/08/get-started-with-folder-automation-in-macos-tahoe/ · https://sixcolors.com/post/2026/02/making-the-most-of-shortcuts-automations-in-macos-tahoe-podcasting-file-management/
[S70] https://takeoutday.org/guides/how-to-export-youtube-data (third-party) · https://support.google.com/youtube/answer/9230970 · https://techcrunch.com/?p=660785
[S71] https://developers.cloudflare.com/r2/pricing/
[S72] Anthropic model pricing table from the `claude-api` skill (cached 2026-10-06): Opus 5.5 $4/$20, Sonnet 5.5 $2/$10, Haiku 5.5 $0.10/$0.50 per M tokens; Batch API at 50% cost
[S73] `Sonny/Sonny/20 Projects/Gabriel Galindo — Content Engine.md` · `Sonny/Sonny/30 Ventures/Growati.md`
[S74] `Projects/Gabriel Galindo/content-engine/PLAN.md` (lines 81 to 96)
[S75] Read-only `ffprobe` and `stat` of `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /` on 2026-10-08
[S76] https://apps.apple.com/us/app/easy-release-model-releases/id360835268 · https://expertphotography.com/best-model-release-apps

---

## 11. Open questions this track could not close

1. Does Yoga Marga's RedCircle show already have published episodes and subscribers? That decides whether moving to Transistor costs anything [S40, S43].
2. Is the archive 900 recordings or 900 hours, and what is the average length? Every cost line scales with it [S1, S2].
3. Is any of the archive in Spanish, and is part of the audience Spanish-speaking? (7E)
4. Which Google account or Brand Account owns the unlisted channel? Takeout must run from it [S70].
5. Will Serenity's privacy rule allow a students-only private feed for full classes (7B.4), and does it allow third-party processors (AssemblyAI, Auphonic) to hear student audio (7B.6)?
6. Why did OBS's vertical output stop after 2026-09-06 [S75]?
7. Is the channel in the YouTube Partner Program or eligible for advanced features? Test & Compare and auto-dubbing depend on it [S49, S51].
8. Would ElevenLabs treat a yoga school as a "religious organization" under the Music terms [S61]?
9. Does an unaudited API project's `videos.update` to public work on videos uploaded through Studio, or is that also restricted [S46] [unverified]?
