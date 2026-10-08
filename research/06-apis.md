# 06 · Pipeline and publishing APIs

Research track for Prakriti. Written 2026-10-08 by a Sonny research agent, read-only except this
file. Every claim carries a source number (list at the end) or an `L` tag for something measured or
read on Ivan's Mac today. `[unverified]` marks anything I could not confirm against a primary source.
Where official docs contradict each other, both readings are given and the conflict is named.

Scope: YouTube Data API v3, podcast hosting and distribution (RedCircle, Spotify, Apple, self-hosted
RSS on R2, YouTube RSS ingestion), ElevenLabs, Auphonic, speaker diarization, on-device transcription
on Apple Silicon, the Claude API, thumbnails, Instagram Reels publishing, TikTok posting, Cloudflare
R2/Stream/Images. It closes with a recommended stack per pipeline stage, cost per recording, and the
total backfill cost.

---

## 0. The findings that change the plan

1. **YouTube no longer meters uploads out of the 10,000-unit pool.** Since 1 June 2026 `videos.insert`
   has its own bucket: 100 uploads per day at 1 unit each [1][3][4]. The old "1,600 units per upload,
   ~6 uploads a day" rule that most tutorials still quote is dead. Quota is not a constraint for
   25 pieces by 6 Nov, or for 72-hour turnaround on new studio recordings.
2. **The "unverified API projects upload as private-only" rule is in conflict in Google's own docs as of
   today.** The `videos.insert` and `videos` reference pages (both "Last updated 2026-10-08 UTC") now say
   *"Videos uploaded from unverified API projects are not restricted to private viewing mode"* and the
   2025 banner announcing the lock is gone [1][7][6]. But the 2020 revision-history entry imposing the
   lock has no matching reversal entry [3], and the page's own auto-summary still states the old rule [7].
   Treat it as unresolved: build so that Prakriti works either way (upload private, then a human flips
   to public or schedules), and test with one throwaway upload before planning around public API uploads.
3. **A YouTube channel Manager or Editor cannot authorize an API app.** YouTube's channel-permissions page
   says invited users "can't access ... YouTube APIs" [16]. The channel **owner** (Gabriel or whoever
   owns the Yoga Marga Google account or Brand Account) must click through Prakriti's Google consent
   screen once. Ivan cannot do it from his own account even with Manager rights.
4. **Thumbnail A/B testing (Test & Compare) has no API.** It is desktop YouTube Studio only, needs
   advanced features, takes up to 3 thumbnails and/or titles, picks the winner by watch time, and
   does not work on Shorts, private, made-for-kids or age-restricted videos [11]. `thumbnails.set` sets
   exactly one thumbnail [8]. Prakriti can make the three options and set one; a person starts the test
   in Studio (about a minute per video).
5. **RedCircle has no public upload API** that I could find in its own help center [29]; third-party
   "RedCircle API" connector pages conflate it with an unrelated Target-product data API of the same
   name. Spotify for Creators has no public upload API either [30]. Autonomous podcast publishing means
   **Prakriti hosts its own RSS feed on R2** and submits it once to Apple, Spotify and (optionally)
   YouTube. RedCircle stays a manual fallback.
6. **ElevenLabs Professional Voice Cloning only clones your own voice, verified on your own account.**
   "Even with their consent, you cannot clone someone else's voice"; the owner creates and verifies the
   clone on their account, then shares it by link [40]. Serenity's consent condition is therefore enforced
   by the vendor: nobody can make her voice model without her doing it herself. Same for Gabriel.
7. **ElevenLabs Voice Isolator removes noise and music, not other people** [41]. "Speaker-isolated audio"
   for voice training is a diarization job (who spoke when), then cutting, then optional cleanup. And the
   studio recordings are **dual-mono from one mixed source** (left minus right is digital silence, measured
   L1), so there are no per-speaker tracks to lean on. OBS can record up to 6 separate audio tracks in
   Advanced output mode [65]; switching the studio to one mic per teacher on its own track would make
   future speaker isolation exact and free.
8. **On-device transcription on the M5 Pro is effectively free and fast.** Measured today on a 10-minute
   real class clip: Apple `SpeechAnalyzer` (via Ivan's existing Hark CLI) ran at **206× real time**, and
   **126× with speaker labels** (FluidAudio diarization); Parakeet TDT v3 on MLX ran at 61× [L2]. 900 hours
   is roughly 7 hours of machine time for transcript plus speakers. But each engine made different
   errors on the same clip (Apple wrote "shit" for "shin"; Parakeet dropped the last 85 seconds), so
   the dual-engine reconcile from the `transcribe-audio` skill is not optional for anything published [L2][L4].
9. **YouTube auto-dubbing is on by default for eligible channels** [26]. That is an AI voice speaking
   Serenity's teaching in another language, published without anyone deciding to. Turn on "Publish
   manually" (or disable) in Studio before the first upload, until she answers on AI voice.
10. **Claude cost per recording is cents, not dollars, if the model choice is deliberate.** A one-hour talk
    transcript measures about 10,800 words, ~18k tokens on the current tokenizer, ~23k with timestamps
    (L1, [56]); the brief's 15k is low for talks and high for classes (~4,700 words/hour). Opus 5.5 on the
    Batch API costs roughly $0.18 to $0.35 per recording; a Haiku 5.5 triage pass over all 900 costs
    about $1.50 in total [56][L5].

---

## 1. Ground truth measured on Ivan's Mac today (L1, L2)

### 1.1 What OBS is producing

Probed with `ffprobe`/`ffmpeg` on `~/Documents/Design Work/Galindo x Lizarde/Studio Recordings /`:

| Property | Value |
|---|---|
| Video | H.264, 1920×1080, 29.97 fps, ~6.0 Mbps |
| Audio | AAC, 48 kHz, stereo, 160 kbps (127 kbps on the vertical copy) |
| Size | ~2.78 GB per hour (6.18 Mbps total) |
| Vertical copy | Several sessions also have a `-vertical.mp4` (1080×1920, same length, same bitrate), so a session costs ~5.6 GB per hour when both are saved |
| Channels | **Dual-mono**: L minus R measured as `-inf` dB RMS over a 2-minute window of the 2026-09-23 class. One mixed source, no per-speaker tracks |
| Loudness | -28.3 LUFS integrated, -12 dBFS peak on that window, so about +12 dB of gain is needed to reach Apple's -16 LKFS target [32] |
| Folder size | 17 GB for 12 recordings (~5.5 hours of unique content) since 2026-09-06 |
| Transcripts | `.txt`, "Speaker 1:" labels, **no timestamps**. The 2026-09-14 recording has no transcript |
| Files | Not iCloud-evicted today (no `dataless` flag), but the folder is inside iCloud Desktop & Documents, so they can be at any time |

Words per hour in the existing transcripts: talks 10,800 to 11,100; the 09-20 session 9,300; yin classes
4,500 to 4,900 (long holds, little speech). The 2026-09-23 class transcript opens with students named
by name ("Valor", "Brend"), which is the privacy issue Serenity raised, visible in the very first line.

### 1.2 Storage reality

Ivan's Mac: 2 TB disk, 805 GB free (L1). 900 hours of archive at YouTube-original quality is roughly
1 to 2.7 TB depending on what was uploaded `[unverified: archive bitrate unknown]`. It does not fit
alongside everything else, and the Mac travels. The archive has to land on an external drive or the
studio RAID, processed in batches.

The studio folder is shared from **Ivan's** iCloud, so every studio hour (both orientations) is ~5.6 GB
of Ivan's iCloud quota. The first four weeks (2026-09-06 to 10-02) added 17 GB (L1); a busier schedule
scales linearly with recorded hours. That is a slow single point of failure: the day Ivan's iCloud fills, OBS saves fail or sync
stops, and nothing upstream of Prakriti says so.

### 1.3 Transcription benchmark (L2)

10-minute mono 16 kHz extract (15:00 to 25:00) of the 2026-09-23 yin class, M5 Pro, 64 GB, macOS 27.2,
measured while the machine was under load (load average ~10.8 from parallel agents), warm models:

| Engine | Wall time | Speed | Words | Notes |
|---|---|---|---|---|
| Apple SpeechAnalyzer (Hark `diarize-proto --no-speakers`) | 2.9 s | 206× | 511 | Wrote "bring the hands to the **shit**" for "shin" and "heads" for "hands" |
| SpeechAnalyzer + FluidAudio diarization (Hark default) | 4.8 s | 126× | 513 | Speaker labels included |
| Parakeet TDT 0.6B v3 (`parakeet-mlx`) | 9.8 s incl. model load | 61× | 395 | More literal and correct on the words it kept ("shin", "hands", "figure four"), but its last segment ends at 8:35 of 10:00. It dropped real speech ("Layer two...", "Three minutes in this shape") |

Projection for 900 hours, at these rates: SpeechAnalyzer + diarization ~7.1 h; Parakeet second engine
~14.8 h; total under a day of unattended machine time. These are one clip on a loaded machine, so treat
them as order-of-magnitude, not a promise. The lesson is the same one the `transcribe-audio` skill
learned on the Vietnam tapes [L4]: fluent output is not complete output, and two engines disagreeing is
the signal. A profanity substitution in a published caption of a yoga class is exactly the accuracy
failure Serenity asked to be protected from.

`SpeechTranscriber` locale support on this Mac (queried with the Speech framework today): `es-US`,
`es-MX`, `es-ES`, `es-CL` and 40+ others are **supported**; only English variants are **installed** so
far (assets download on first use) (L1, [53]). Apple's Speech framework has no diarization at all; Hark
pairs it with FluidAudio for that reason [L3].

---

## 2. YouTube Data API v3

### 2.1 Quota (current, 2026)

Default allocation: 100 `search.list` calls, 100 `videos.insert` calls, and 10,000 units per day for all
other endpoints combined [4][5]. Moved to granular buckets on 1 June 2026 [3]. Every request, even an
invalid one, costs at least 1 unit [4].

| Call | Cost | Bucket |
|---|---|---|
| `videos.insert` | 1 | Video Uploads (100/day) [1][2] |
| `videos.update` | 50 | general [2] |
| `videos.list` | 1 | general [2] |
| `thumbnails.set` | 50 | general [2][8] |
| `captions.insert` | 400 | general [2][13] |
| `captions.update` | 450 | general [2] |
| `captions.list` | 50 | general [2] |
| `playlists.insert` | 50 | general [2] |
| `playlistItems.insert` | 50 | general [2] |
| `channels.list` | 1 | general [2] |
| `search.list` | 1 | Search (100/day) [2] |

History worth knowing so nobody "fixes" the math back: the documented upload cost fell from ~1,600 to
~100 units on 4 Dec 2025, then moved to its own 1-unit bucket on 1 June 2026 [3].

**Prakriti's quota math** (my arithmetic): a fully packaged long-form publish is insert (1, upload
bucket) + thumbnail (50) + captions (400) + add to playlist (50) + a metadata update (50) = ~550 general
units, so **~18 fully captioned publishes per day**, or ~66 per day without uploading captions. Shorts
(insert + playlist) cost ~51 units. More quota needs a compliance audit via the Audit and Quota
Extension form (https://support.google.com/youtube/contact/yt_api_form) [5]. Not needed for v1.

### 2.2 Unverified projects and private-only uploads (conflict)

- 2020 rule, still in revision history: "All videos uploaded via the videos.insert endpoint from
  unverified API projects created after 28 July 2020 will be restricted to private viewing mode. To lift
  this restriction, each project must undergo an audit" [3]. A 2025 archived copy of the insert page
  carried this as a banner [6].
- Current reference pages (updated 2026-10-08): the banner is gone, and the `status.privacyStatus` text
  reads "Videos uploaded from unverified API projects are not restricted to private viewing mode" [1][7].
  The `videos` page's machine summary still repeats the old rule [7]. No revision-history entry announces
  the change [3].
- The audit guide describes the audit as the route to more quota and does not mention the private lock [5].

**Design consequence:** upload everything as `private` with `publishAt` or a human "publish" click. If the
lock is real, the publish step fails visibly and the fix is the audit form; if it is gone, nothing changes.
Run one test upload from the new Cloud project before 6 Nov.

### 2.3 OAuth, ownership and consent

- Upload scopes: any one of `youtube.upload`, `youtube`, `youtubepartner`, `youtube.force-ssl` [1].
  Request the fewest (upload + `youtube.force-ssl` for captions and playlists) [1][13].
- **Channel permission roles do not grant API access**: "invited users can't access ... YouTube APIs" [16].
  Manager can upload, publish and delete in Studio; Editor cannot delete published content; neither can
  authorize an API client [16]. Brand Accounts must migrate to channel permissions before access can be
  granted or removed [16].
- The person who consents must be the channel owner and must pick the right channel at Google's account
  picker when one login manages several channels (third-party integration guides, not Google docs)
  `[unverified]`. Verify after consent with `channels.list?mine=true` and compare the channel ID.
- **Refresh tokens from an External app left in "Testing" expire after 7 days** [27]. Set the consent
  screen to "In production". An unverified app shows a warning screen and is capped at 100 users, which
  is fine for three people; verification of sensitive scopes can take months [27]. If Yoga Marga's channel
  owner is a Google Workspace account, a Cloud project inside that Workspace with user type "Internal"
  avoids the warning and the verification entirely (same pattern as Ivan's memory note on Gmail access)
  `[unverified for YouTube scopes]`.
- **Developer Policies that shape the product** [17]:
  - III.A.1/2: the client must display a link to YouTube's Terms of Service and require users to agree to
    a privacy policy before using its features. The prakriti.therowan.studio features/login page is
    where these go.
  - III.E.3.d: actions that insert, update or delete data for the user need the user's express consent
    "prior to their actual execution".
  - III.I.2: clients "must not automate or trigger ... uploads ... without the user's prior specific and
    express consent". This lines up with the standing rule (nothing outward-facing without a human yes):
    the approve button is a compliance requirement, not just a preference. Whether one approval can cover
    a batch is my open question `[unverified]`.
  - III.E.1: no downloading, caching or storing YouTube audiovisual content without written approval.
  - III.E.4: non-authorized API data may be stored at most 30 days, then deleted or refreshed.

### 2.4 Upload fields Prakriti will set [7]

- `snippet.title`: max 100 characters, no `<` or `>`.
- `snippet.description`: max 5,000 **bytes** (not characters; accented Spanish characters cost 2 bytes), no `<` `>`.
- `snippet.tags`: 500 characters total, commas count, tags with spaces count their implied quotes.
- `snippet.categoryId` required on `videos.update` of the snippet; `snippet.defaultAudioLanguage`.
- `status.privacyStatus`: `private | public | unlisted`; defaults to `public` on insert if omitted (some
  accounts default to private).
- `status.publishAt`: ISO 8601; only when `privacyStatus` is `private`; only if the video has never been
  published; a past time publishes immediately; on `videos.update` you must resend `privacyStatus: private`.
- `status.selfDeclaredMadeForKids`: set explicitly `false` (made-for-kids videos lose Test & Compare,
  comments and more [11]).
- `status.containsSyntheticMedia`: the API's flag for realistic altered or synthetic content [7][24].
  Set it `true` on anything carrying a cloned voice of a real person.
- `recordingDetails.recordingDate`: the original class date (useful for archive pieces).
- `paidProductPlacementDetails.hasPaidProductPlacement`: false unless a sponsor is involved.
- Max video file 256 GB; MIME `video/*` [1]. Resumable upload is the right transport for multi-GB files.

### 2.5 Thumbnails

- `thumbnails.set`: ~50 units, **max 50 MB since 14 Sep 2026** (was 2 MB), JPEG or PNG; 403 if the
  user lacks permission to set custom thumbnails; 429 `uploadRateLimitExceeded` if too many recently [8][3].
- Custom thumbnails require **intermediate** features (phone verification), not advanced [10][9].
- Specs: 16:9 for video, aim for 3840×2160, minimum 640 px wide; desktop allows 50 MB [9]. YouTube added
  `fhd`/`qhd`/`uhd` thumbnail sizes on 11 Sep 2026 [3], so 4K masters are now worth exporting.
- **Shorts thumbnails can only be set in Studio on a computer** [9]; a third-party guide says
  `thumbnails.set` on a Short returns an error `[unverified]`.
- Repeated thumbnail-policy offenses can remove custom thumbnail privileges for 30 days [9].

### 2.6 Test & Compare (thumbnail and title A/B testing) [11]

- Tests: title only, thumbnail only, or title + thumbnail; up to 3 variants.
- Desktop YouTube Studio only; advanced features required.
- Winner = highest watch time (not CTR); results Winner / Performed Same / Inconclusive; should finish
  within two weeks; changing title or thumbnail mid-test stops it.
- Not available for Shorts, scheduled Lives, Premieres (until converted), made-for-kids, mature-audience,
  private or age-restricted videos.
- **No API.** Nothing in the Data API reference or revision history exposes it [8][3]. The "three thumbnail
  options for A/B tests" deliverable therefore ends in a human step: Prakriti uploads option 1 via API,
  stores options 2 and 3, and shows a one-click "Open in Studio" link with the files ready to drag in.

### 2.7 Captions

- `captions.insert`: 400 units, max 100 MB, media upload [13]. `sync` (auto-timing) is deprecated [13][3];
  upload timed files (SRT/VTT/SBV) built from Prakriti's word timestamps.
- Uploading Prakriti's corrected captions beats YouTube's auto-captions on accuracy, and accuracy is
  Serenity's condition. It is also the single most expensive call (see 2.1), so upload captions for
  published long-form, not for every Short.

### 2.8 Playlists and YouTube Podcasts via API

- `playlists.insert` 50 units; `playlistItems.insert` 50 [2].
- `playlist.status.podcastStatus` = `enabled` marks a playlist as a **podcast show**; it requires a
  playlist image first (`playlistImages.insert`, whose upload limit also rose to 50 MB) [14][3].
  This is how real-video episodes become a YouTube podcast without RSS.

### 2.9 Shorts through the API

- No Shorts flag. Upload normally with `videos.insert`; YouTube classifies square or vertical videos up
  to 3 minutes (uploaded on or after 15 Oct 2024) as Shorts [15]. Max 1080p for Shorts [15].
- `#Shorts` in title/description: third-party guides disagree on whether it matters; Google's pages do
  not mention it `[unverified]`. Some API uploads reportedly miss the Shorts feed (anecdotal) `[unverified]`.
- The studio's OBS vertical copy (L1) is a ready source for Shorts crops without reframing.

### 2.10 Chapters from description timestamps [12]

- First timestamp `00:00`; at least three, ascending; each chapter at least 10 seconds.
- **Requires advanced features** [12][10].
- Manual timestamps override YouTube's automatic chapters; automatic chapters are on by default for new
  uploads.

### 2.11 Feature eligibility to check on day one [10]

Intermediate (phone verification): custom thumbnails, videos longer than 15 minutes, live streaming.
Advanced (channel history, or ID/video verification): chapters, A/B testing, RSS upload, clickable links
in long-form descriptions, multi-language features. Check under Studio > Settings > Channel > Feature
eligibility before promising chapters or A/B tests to Gabriel. Most of the archive runs longer than
15 minutes, so phone verification is the minimum.

### 2.12 Policies that bear on Prakriti

- **Misleading thumbnails/metadata**: the spam and deceptive-practices policy prohibits "maliciously
  misleading" titles, thumbnails and descriptions used to lure clicks, and applies to unlisted and
  private content and thumbnails too; example given is a title promising more than the video delivers [23].
- **Automated or synthetic mass-production**: the same policy targets high volumes of similar AI-made
  content, e.g. "repetitive AI generated imagery across many videos" [23]. The YPP "inauthentic content"
  rename (15 July 2025) targets templated uploads "with little to no variation", including image
  slideshows with minimal narrative [25]. Pushing hundreds of static-image podcast videos onto the channel
  through RSS ingestion is the pattern most exposed to this.
- **Altered or synthetic disclosure** [24]: required when content is realistic and "makes a real person
  appear to say or do something they didn't do". Using AI for "script, thumbnail" and titles is listed as
  production assistance that needs no disclosure; cloning one's own voice for voice-overs or dubs is
  listed as not needing disclosure. A cloned Serenity intro she did not record herself is closer to the
  "real person saying something they didn't say" test; disclose it.
- **Auto-dubbing** [26]: on by default for eligible channels; videos over 120 minutes, music-only, or
  Content-ID-claimed are excluded; dubs cannot be edited line by line, only unpublished or replaced with
  your own track; "Publish manually" holds each dub for review. Spanish is a supported target with the
  expressive voice. Third-party coverage, not the Help Center itself `[unverified details]`.

### 2.13 Getting the 900 unlisted videos out

| Route | Quality | Scale | Terms | Verdict |
|---|---|---|---|---|
| **Google Takeout** (YouTube > Videos) | Original upload quality; "a higher-quality version of the file may be available" vs Studio [20] | All uploads in one export; not individual videos [20] | First-party, sanctioned | **Use this** |
| YouTube Studio download | MP4 at 720p or 360p depending on size [19] | One at a time, max 5 downloads per video per 24 h [19] | Sanctioned | Fallback for a handful |
| Data API | No download endpoint for video media; developer policy forbids storing AV content [17] | n/a | Prohibited | No |
| yt-dlp | YouTube's re-encode, not the original | Scriptable | ToS bars downloading except where YouTube provides a link, and automated access [18]; needs a JS runtime (Deno) and sometimes PO tokens; account use risks a ban per yt-dlp's own wiki [21] | No |
| Google Data Portability API | Has YouTube resources incl. private/unlisted videos scopes `[unverified names]` | Programmatic | Offered in the EEA and UK; other jurisdictions "exploring" [22] | Not available for a US account `[unverified]` |

Takeout gotchas: videos with a copyright claim are excluded from both Takeout and Studio downloads [20]
(class playlists with music are the likely casualties); unlisted videos uploaded before 1 Jan 2017 were
made private in 2021 [20] (still included, being the owner's uploads `[unverified]`); the export must be run
by the account that owns the channel, which may be a Brand Account; exports take hours to days and arrive
as 1 to 50 GB parts; third-party guides say download links expire after 7 days `[unverified]`. Plan a
batch loop: pull one part, extract audio, keep video only for curated picks, move on. At 100 Mbps, 1 TB
takes about 22 hours to download (my arithmetic).

Also: whether the archive is "about 900 recordings" (brief) or "900 hours plus" (Gabriel on the call,
transcript line 25) is unresolved. Costs below assume 900 hours.

---

## 3. Podcast hosting and distribution

### 3.1 RedCircle (account exists)

- No API in RedCircle's help center (Getting Started, Migrating, Distributing; no developer section) [29].
  Connector sites advertising a "RedCircle API" show sample code against an unrelated product-search API
  of the same name `[unverified as podcast API]`.
- Upload limits: audio 200 MB (250 MB on Pro/Enterprise); video 10 GB (Pro/Enterprise only); title,
  description and audio file required; episode artwork 1400 to 3000 px; transcript URL field (HTML, JSON,
  VTT or text); scheduled publish date supported [29].
- Plans: Core free (one podcast, unlimited storage and downloads); Growth from $19.99/mo (Dynamic Insertion,
  5 transcripts/mo); Pro from $34.99/mo (publish video versions to YouTube, 50 transcripts/mo, 5 team
  members); Enterprise from $119.99/mo [29].
- **Dynamic Insertion** stitches pre-recorded audio at insertion points at download time, including
  "repeated intros and outros", consistently across the catalog [29]. This would let Yoga Marga change the
  call-to-action across all 900 episodes without re-rendering. But YouTube's RSS ingestion forbids
  dynamically inserted content [28], so DAI and YouTube-via-RSS are mutually exclusive.
- RedCircle imports a whole show from an existing RSS feed (mp3/m4a only) as a one-time migration [29].

### 3.2 Spotify for Creators

- No public upload API found; the developer podcast API is read/catalog only; a Spotify community thread
  asking for one went unanswered by staff [30]. Video upload from third-party hosts runs through a partner
  "Distribution API" [30].
- Shows hosted elsewhere are added by RSS URL; Spotify then ingests new episodes from the feed [30].
- Spotify provider docs: max episode duration 12 hours (~2 GB at 320 kbps); MP3 96 to 320 kbps [30].
  The full delivery spec v1.10 is a PDF I could not read `[unverified remaining limits]`.

### 3.3 Self-hosted RSS on Cloudflare R2 (recommended for autonomy)

A Worker renders the feed from D1; enclosures are served from an R2 custom domain. One-time submissions
to Apple Podcasts Connect, Spotify for Creators and (optionally) YouTube Studio. After that, publishing
an episode is a database write.

**Apple Podcasts requirements** [31][32][33][34][35]:
- RSS 2.0, publicly reachable, XML declaration, `itunes` and `content` namespaces [31].
- Host must answer **HTTP HEAD and byte-range requests** (R2 does both; verify through the custom domain) [31].
- Unique `<enclosure>` (url, length, type) per episode; a GUID that "never changes"; RFC 2822 dates [31].
- ASCII-only filenames/URLs; `&apos;`/`&quot;` not HTML entities; consistent tag casing [31].
- At least one episode; an Apple Podcasts Connect account [31].
- Show art: 3000×3000 standard; 1400 to 3000 accepted via RSS; PNG or JPG [33].
- Audio for RSS: MP3 or AAC (AAC preferred, MP4 container). Mono MP3 96 to 128 kbps recommended; RSS
  mono 64 to 128 kbps at 44.1/48 kHz [32].
- **Loudness: -16 LKFS ±1 dB, true peak ≤ -1 dBFS** (BS.1770-5), applied before encoding [32].
  The studio audio sits at about -28 LUFS today (L1).
- **Transcripts**: VTT or SRT via the RSS transcript tag; languages include English and **Spanish**;
  iOS 17.4+; subject to quality standards (spelling, punctuation, complete); **a VTT file can name the
  speaker on every line and Apple shows the name when the speaker changes**; to use your own instead of
  Apple's auto transcript, change the show's setting in the Availability tab [34]. Speaker-named VTT is a
  direct use of Prakriti's diarized transcripts.
- **Chapters**: via `<podcast:chapters>`, episode-description timestamps, or MP4/ID3 metadata; first at
  00:00:00, at least three, no more than six per hour, each at least two minutes, titles under 45
  characters and under five words; Apple auto-generates English chapters from iOS 26.2 (opt-out per show
  or episode) [35].

**Podcasting 2.0 namespace** [36]: `podcast:transcript`, `podcast:chapters`, `podcast:locked`,
`podcast:guid`, `podcast:person`, `podcast:soundbite`, `podcast:season`, `podcast:episode`,
`podcast:funding`, `podcast:license`, `podcast:alternateEnclosure`, `podcast:medium`, `podcast:txt`,
`podcast:podroll`. Worth setting from day one: `guid` (stable show identity), `locked` (stops another host
importing the feed `[unverified semantics]`), `transcript`, `chapters`, `person` (Gabriel, Serenity, never
students), `soundbite` (the clip Prakriti already picked for Shorts).

**Analytics**: R2 has no download counts. OP3 is a free, open-source prefix service: prepend
`https://op3.dev/e/` to enclosure URLs for a public stats page [37]. Or log enclosure hits in the Worker.

**YouTube via RSS ingestion** [28][10]:
- Needs advanced features; available in selected countries; owner email in the feed receives a
  verification code; audio-only episodes become static-image videos made from the artwork.
- Feeds delivered this way must not contain advertising, including dynamically inserted ads; host-read
  sponsorships must be declared [28].
- YouTube does not notify subscribers when back-catalogue episodes arrive via RSS; new episodes notify [28].
  Third-party guides say newly ingested episodes land private by default `[unverified]`.
- Recommendation: do **not** ingest all 900 archive episodes into YouTube as static-image videos (see the
  mass-production policy, 2.12). Use YouTube for real video: curated archive videos and studio recordings
  uploaded via the API into a playlist with `podcastStatus: enabled` (2.8).

**Ownership trap**: the feed URL is permanent infrastructure. If it lives under Ivan's `therowan.studio`
zone, Yoga Marga's podcast depends on Ivan's Cloudflare account forever. Put the enclosures and feed on a
domain Yoga Marga owns (e.g. a `podcast.` subdomain of theirs, CNAMEd to R2), with Gabriel's email as
`itunes:owner`. Moving later is possible (301 + `itunes:new-feed-url`) but every directory has to follow
`[unverified per-directory behavior]`.

### 3.4 Recommendation

Prakriti hosts the feed (autonomous, free, Apple/Spotify/YouTube all read it). RedCircle is the manual
fallback: for any episode, Prakriti can hand Gabriel an "upload kit" (MP3, title, description, art,
transcript URL) since he offered to do uploads himself. Revisit RedCircle Growth only if Dynamic Insertion
or its ad marketplace becomes a goal, remembering it conflicts with YouTube RSS ingestion.

---

## 4. ElevenLabs

### 4.1 Plans and API prices (fetched 2026-10-08) [38]

| Plan | Price/mo | Credits/mo | Instant clones | PVC slots |
|---|---|---|---|---|
| Free | $0 | 10k | 3 | 0 |
| Starter | $6 (first month $1) | 30k | 10 | 0 |
| Creator | $22 (first month $11) | 121k | 30 | 1 |
| Pro | $99 | 600k | 160 | 1 |
| Scale | $299 | 1.8M | 660 | 3 |
| Business | $990 | 6M | 2,200 | 10 |

API list prices [38]: TTS Multilingual v2 and v3 $0.08 per 1k characters; Flash/Turbo $0.04; **v4 $0.022
and v4 Turbo $0.011 per 1k, marked 72% off until 12 Oct** (list price reportedly $0.08 per 1k, one secondary
source [39]). Scribe v2 speech-to-text **$0.22 per hour** (+$0.05/h keyterm prompting, +$0.07/h transcript
editing). Voice Isolator **$0.12 per minute**. Voice Changer $0.12/min. Dubbing v1 $0.33/min watermarked,
$0.50/min clean; Dubbing v2 $2.20/min [38]. Credit equivalents in-app: Voice Isolator 1,000 credits/min,
Scribe 330 credits/min, Dubbing 2,000 to 10,000 credits/min [38].

### 4.2 TTS for intro, outro and mid-roll

- **Eleven v4** and v4 Turbo launched 28 Sep 2026: more expressive, audio tags like `[laughs]` inline,
  SSML pause markup off, 90+ languages, up to 10,000 characters per generation, PVC support restored
  after v3 lacked it; API id reportedly `eleven_v4` `[unverified]` [39].
- Cost is trivial: a 45-second personalized intro is ~700 characters, about $0.06 at $0.08 per 1k; a
  5-second mid-roll ~80 characters (my arithmetic). A fixed intro/outro is generated once and reused.
- Before consent, use either Gabriel's real recorded voice (most authentic, zero consent question) or a
  stock library voice. A cloned voice of either founder waits for that founder to make the clone (4.4).

### 4.3 Voice Isolator [41]

- Up to 500 MB and **1 hour per file**; audio (AAC, AIFF, OGG, MP3, OPUS, WAV, FLAC, M4A) and video
  (MP4, MOV, MKV and more). Studio recordings run 55 to 72 minutes, so chunk before sending.
- `POST /v1/audio-isolation`, multipart; `file_format=pcm_s16le_16` for lower latency [41].
- Extracts speech from background noise and music; it is **not** a speaker separator [41].
- At $7.20 per hour it is not a whole-archive tool. Use it on the curated single-speaker training set only.

### 4.4 Professional Voice Cloning and consent [40]

- Slots: none on Free/Starter; 1 on Creator/Pro; 3 on Scale; 10 on Business.
- Audio: 30 minutes bare minimum, 2 to 3 hours recommended; one speaker only; no music, noise, room echo
  or other voices; one consistent style (so pick talks or class-cueing, not both).
- **Verification**: the voice owner reads verification lines, ideally on the same equipment; retry after
  24 hours on failure.
- **Own voice only**: "For now, we only allow you to clone your own voice. ... Even with their consent, you
  cannot clone someone else's voice." The owner creates and verifies it on their own account, then shares
  it by link.
- Fine-tuning 3 to 6 hours, often 6 to 24 hours with the queue.
- Consequence for scope: Prakriti's job is to **prepare** each founder's training set (2 to 3 hours of
  clean, single-speaker, single-style audio with no students), then the founder uploads and verifies it in
  their own ElevenLabs account. Each founder needs at least a Creator plan ($22/mo) for their own slot.

### 4.5 Dubbing for Spanish [42]

- API: up to 3 GB per source file; app limits 1 GB/180 min (Automatic) and 1 GB/45 min (Dubbing Studio);
  up to 32 speakers; Spanish `es`, plus `es-AR/CL/ES/MX` on Dubbing v2.
- "Preserve original voices": dubs carry the speaker's identity (cloning strength 0 to 10 on v2). That is
  an AI clone of whoever is speaking, students included, so it falls under the same consent gate.
- Dubbing Studio is in maintenance mode (critical fixes only).
- Free alternative: YouTube's own auto-dubbing (2.12), which is also the risk if left on by default.

### 4.6 Scribe v2 (cloud transcription) [43][38]

$0.22/hour; diarization up to 32 speakers; word timestamps; audio-event tags (laughter, applause); files
up to 3 GB and 10 hours; 90+ languages; up to 1,000 keyterms of 50 characters each. Keyterms are the
strongest argument for Scribe on the archive: Sanskrit and Yoga Marga vocabulary (asana names,
pranayama, Yoga Marga itself) is exactly where local engines guess. 900 hours ≈ $198, plus $45 with
keyterms (my arithmetic). Note it sends students' voices to a cloud vendor.

---

## 5. Auphonic

Algorithms (single-track) [45]: Adaptive Leveler; loudness normalization to targets including -16 LUFS
(and -14 for Spotify/YouTube); true-peak limiter with 4× oversampling; noise and reverb reduction modes
(Dynamic Denoiser, **Speech Isolation** which removes music, Static Denoiser, Classic Denoiser) with
Remove Noise / Remove Reverb / Remove Breaths amounts; high-pass; Voice AutoEQ with de-plosive; bandwidth
extension; Studio Voice (beta); automatic cuts for silence, filler words, coughs and music segments longer
than ~20 s, with "Export Uncut Audio" as an option.

Plan features [44]: API and CLI on all plans including Free; watch folders and batch productions on paid
plans only; multitrack on Free limited to under 20 minutes; Free productions carry an Auphonic jingle
(unusable for publishing); billing on processed duration with a **3-minute minimum per production**.

Prices in USD (read from the live pricing page's data attributes, 2026-10-08) [44]:

| Recurring (per month) | Hours | Monthly | Yearly (per month) |
|---|---|---|---|
| S | 9 h | $13 | $11 |
| M | 21 h | $30 | $25 |
| L | 45 h | $64 | $52 |
| XL | 100 h | $136 | $113 |
| XXL | 250 h | $290 | $245 |

| One-time credits (never expire) | Price | Per hour |
|---|---|---|
| 5 h | $12 | $2.40 |
| 10 h | $23 | $2.30 |
| 25 h | $55 | $2.20 |
| 50 h | $100 | $2.00 |
| 100 h | $171 | $1.71 |
| 250 h | $320 | $1.28 |
| 500 h | $545 | $1.09 |
| 1000 h | $1,045 | $1.045 |
| 2000 h | $2,020 | $1.01 |
| 3000 h | $2,925 | $0.975 |

The free local alternative for loudness alone is ffmpeg's two-pass `loudnorm` (EBU R128) [66]. It does
not denoise, level speakers against each other, or cut fillers. Auphonic's leveler matters most on class
recordings where the teacher walks away from the mic and students are quiet.

---

## 6. Speaker diarization options

| Option | Where it runs | Accuracy evidence | Cost | Names known speakers? | Notes |
|---|---|---|---|---|---|
| **pyannote community-1** (pyannote.audio 4.x) | Local (CPU/GPU; MPS not documented) | DER vs 3.1: AMI-SDM 19.9 vs 22.7; DIHARD3 20.2 vs 21.4; VoxConverse 11.2 vs 11.2 [46] | Free (CC-BY-4.0, gated HF token) | No (cluster labels); new "exclusive" mode simplifies alignment with ASR words [46] | Ivan's 3.1 attempt failed on band-limited tapes and cost 47 min CPU per 33 min [L4]; studio audio is wideband, so worth one test |
| **pyannoteAI Precision-2 / Precision-3** (hosted) | Cloud | Precision-2 DER: AMI-SDM 15.6, DIHARD3 14.7 [46]; Precision-3 "34.2% more accurate on average than Community-1" [47] | Precision-3 €0.112/h (Developer, €19/mo incl. €19 credit), €0.096/h (Starter); Community-1 hosted €0.035/h; voiceprint creation €0.015 each [47] | **Yes**: enroll a ≤30 s single-speaker voiceprint per person, then `/v1/identify` labels segments "Gabriel" / "Serenity" / unknown; `matching.threshold`, `matching.exclusive`; outputs deleted after 24 h [47] | Best fit for "transcript tagged by speaker" across 900 files. ~€101 for 900 h (my arithmetic). Sends audio to the cloud |
| **FluidAudio** (inside Hark) | Local, Core ML / Neural Engine | Offline pipeline is pyannote community-1 (segmentation + WeSpeaker + VBx); DER not published on the README [51]; 6/6 turns correct on Hark's 2-speaker test [L3] | Free (Apache 2.0) | Embeddings support pre-enrollment / speaker database for identification [51] | Already built and installed on Ivan's Mac; 126× real time measured with transcription [L2] |
| **WhisperX** | Local | Uses pyannote for diarization (same accuracy as the pyannote model it loads) `[unverified current default]` | Free | No | Its VAD gate dropped 80% of a tape silently [L4]; never run with VAD on |
| **NVIDIA NeMo Sortformer** (streaming 4spk v2/v2.1) | Local GPU; community Core ML ports | CALLHOME: ~6.6% DER (2 speakers), 10.1% (3), 12.4% (4), per a third-party reproduction [50] | Free (v2 CC-BY-4.0; offline v1 non-commercial) [50] | No | **Hard cap of 4 speakers**: a class with students exceeds it [50][51] |
| **AssemblyAI** | Cloud | n/a here | Universal-3.5 Pro $0.21/h + diarization $0.02/h (+$0.065 experimental) + speaker identification $0.02/h; $50 free credit [48] | Speaker identification add-on | ~$225 for 900 h with both add-ons (my arithmetic) |
| **Deepgram Nova-3** | Cloud | n/a here | $0.0043/min ($0.258/h) PAYG, $0.0036/min Growth; diarization included; $200 free credit [49] | No | ~$232 for 900 h |
| **ElevenLabs Scribe v2** | Cloud | Language tiers only (≤5% WER "excellent") [43] | $0.22/h [38] | No (labels only) | 32 speakers, keyterms; see 4.6 |
| OpenAI `gpt-4o-transcribe-diarize` | Cloud | Not measured | Not checked | No | Key exists in Keychain; account had no credits [L4] |

Recommendation: local first (Hark's SpeechAnalyzer + FluidAudio, with a voiceprint enrollment for
Gabriel and Serenity so labels come out as names), verified on a 10-file hand-checked sample. If
attribution fails QA, the upgrade is pyannoteAI Precision identify at roughly €0.11 per hour. Keep raw
class audio local by default: that is the cheapest way to honor the student-privacy condition.

Exactness note for voice-training sets: only keep segments where diarization shows one speaker and no
overlap (the "exclusive" output [46][47]), then trim 0.25 s at each boundary `[my heuristic]`.

---

## 7. Transcription engines on Apple Silicon

| Engine | Measured or published speed | Accuracy notes | Fit |
|---|---|---|---|
| **Apple SpeechAnalyzer / SpeechTranscriber** (macOS 26+) | **206× measured** on M5 Pro (L2); MacStories/Yap: 34-min 4K video in 45 s vs MacWhisper large-v3-turbo 1:41 [52] | One blog: LibriSpeech test-clean WER 2.12%, test-other 4.56% on M2 Pro; WhisperKit beat it on Spanish in a harder set [52]; made the "shin" error (L2) | Primary engine; free; Neural Engine; no diarization in the framework [L3]; Spanish locales supported but must download (L1) |
| **Parakeet TDT 0.6B v3** (MLX / FluidAudio Core ML) | 61× measured incl. load (L2); FluidAudio claims ~190× on M4 Pro [51] | Literal, keeps disfluencies, catches what Whisper smooths [L4]; dropped trailing speech on the yoga clip (L2); 25 European languages [51] | Second engine for the reconcile pass |
| **whisper.cpp + Core ML** | Encoder on ANE ">3× faster" than CPU-only; first run compiles slowly [54]; turbo on Metal ~14 to 16× real time on M3 Max/M4 Pro (one blog) [54] | large-v3-turbo mean WER 7.81 vs large-v3 7.45 in one Open ASR table [52] | Viable; not installed (only `openai-whisper` is) (L1) |
| **MLX Whisper large-v3-turbo** | No clean 2026 benchmark; older tests show MLX and whisper.cpp within ~30 to 40% of each other [54] | Same model family as above | Not installed (L1) |
| **WhisperKit** (Argmax) | M3 Max dashboard (Oct 2024): turbo speed 12.55 vs 8.48 for large-v3; avg WER 6.28 vs 5.97 [55] | Strong on Spanish in one test [52] | MIT open source; Pro SDK $0.42/device/mo with a 1,000-device minimum [55], irrelevant here |
| faster-whisper large-v3 (CPU int8) | ~1.1× real time [L4] | Best-known quality baseline | Too slow for 900 h (~820 h of CPU) |

Realistic plan for ~900 hours on the M5 Pro: SpeechAnalyzer + diarization ~7 hours, Parakeet second pass
~15 hours, all local and free (L2 projection). The binding constraint is not compute, it is getting the
archive onto a disk the machine can see while the laptop travels.

Vocabulary: SpeechAnalyzer accepts contextual strings through `AnalysisContext` `[unverified for
SpeechTranscriber]`; Whisper-family engines take an initial prompt [L4]; Scribe takes 1,000 keyterms [43].
Build a Yoga Marga glossary once (teachers, students' names to redact, Sanskrit terms) and feed it to
whichever engine accepts one.

---

## 8. Claude API (edit decisions, titles, chapters, scoring)

### 8.1 Models and prices (Anthropic docs, fetched 2026-10-08) [56][57]

| Model | ID | Input / output per MTok | Cache read | Batch in / out | Context / max output | Thinking | Default effort |
|---|---|---|---|---|---|---|---|
| Opus 5.5 | `claude-opus-5-5` | $4 / $20 | $0.20 | $2 / $10 | 1M / 128K | Adaptive, **always on** | `medium` |
| Sonnet 5.5 | `claude-sonnet-5-5` | $2 / $10 | $0.10 | $1 / $5 | 1M / 128K | Adaptive | `high` |
| Haiku 5.5 | `claude-haiku-5-5` | $0.10 / $0.50 (≤100K prompt); $0.50 / $2.50 above | $0.01 | $0.05 / $0.25 | 1M / 128K | Adaptive | `medium` |

Cache writes cost 1.25× input (5-minute) or 2× (1-hour); batch and caching discounts stack; US-only
inference (`inference_geo: "us"`) is 1.1× [56]. The current tokenizer produces ~30% more tokens for the
same text than pre-4.7 models [56]. Fast mode (Opus 5.5) is $8/$40 and not available on Batch [56].

### 8.2 Gotchas that will bite this pipeline

- **Opus 5.5 cannot turn thinking off**; thinking shares `max_tokens` with the answer. VeraSales lost 12 of
  26 generations to truncated JSON after a switch to Opus 5.5 because budgets were sized for a model that
  did not think [L5]. Give every Prakriti call generous `max_tokens`, stream long ones, and log
  `stop_reason`.
- **Forced `tool_choice` (`any`/`tool`) returns a 400 on Opus 5.5 and Sonnet 5.5** [L6]. Use structured
  outputs (`output_config.format`) for the package JSON (titles, chapters, scores, cut list).
- Opus 5.5 and Sonnet 5.5 can return `stop_reason: "refusal"`; enable the server-side fallback parameter
  and check `stop_reason` before reading content [L6].
- Model choice is the cost lever, not caching: on Closer, ~52% of the bill was output tokens and the
  transcript was sent once, so caching saved under a dollar across the project [L5]. Here only the
  rubric/system prompt repeats; cache it, but expect little from it.

### 8.3 Cost per recording (my arithmetic, from measured transcript sizes)

Assumptions: one-hour talk, ~23k input tokens (transcript with timestamps and speaker labels, L1) plus a
~5k cached rubric; output 13k to 30k tokens including thinking (the low end is my estimate; the high end
is implied by Closer's measured ~$0.83 per Opus 5 call on a ~40k-token transcript [L5]). Classes are about
half the input.

| Job | Model | Per recording (standard) | Per recording (Batch) | 900 recordings (Batch) |
|---|---|---|---|---|
| Triage score (quality, topic, privacy flags, keep/skip) | Haiku 5.5 | ~$0.003 | ~$0.0015 | **~$1.40** |
| Full package (titles, description, chapters, quality score with reasons, cut list, Shorts picks, intro script, thumbnail text) | Opus 5.5 | ~$0.35 to $0.70 | ~$0.18 to $0.35 | **~$160 to $315** |
| Same, Sonnet 5.5 | Sonnet 5.5 | ~$0.18 to $0.35 | ~$0.09 to $0.18 | ~$80 to $160 |

Batch results arrive asynchronously (typically well inside a day `[unverified typical latency]`), which
fits the archive and still fits the 72-hour studio target. Recommendation: Haiku triage on everything,
Opus 5.5 packages for what triage keeps plus every studio recording. Measure real `usage` on the first
ten and re-price before the backfill.

---

## 9. Thumbnails: real frames plus type, not AI images

Recommendation: three options per video, each a **real frame** of the teacher, chosen and composed
locally, with short type. Reasons: it is honest (the policy test is "maliciously misleading" [23]), it is
free, it is consistent with Ivan's non-skeuomorphic, describe-don't-sell taste, and it avoids the
mass-produced AI imagery pattern [23][25].

Frame selection with Apple Vision (all macOS 15+, on-device) [64]:
- `CalculateImageAestheticsScoresRequest`: aesthetic score per candidate frame.
- `DetectFaceCaptureQualityRequest`: picks frames where the face is sharp, open-eyed, well lit.
- `GenerateAttentionBasedSaliencyImageRequest`: where the eye goes, so type avoids it.
- `GenerateForegroundInstanceMaskRequest`: lifts the teacher off the background for a clean layout.

Pipeline: sample a frame every ~2 s near the moments Claude flagged, score, take the top three distinct
moments, set type from Claude's thumbnail text, export 3840×2160 JPEG (≤50 MB) [9][8]. Shorts get no API
thumbnail [9]; Instagram Reels take `cover_url` (JPEG ≤8 MB) or `thumb_offset` [58].

Where generative AI is acceptable: extending a background to fit 16:9 from a vertical frame, cleanup,
upscaling. YouTube lists AI help with thumbnails as production assistance that needs no disclosure [24].
Not acceptable: invented scenes, faces or expressions of Gabriel or Serenity they did not make, or students.

---

## 10. Instagram Reels (Graph API content publishing) [58]

- Professional accounts only. Two auth paths: Facebook Login (Page token, account linked to a Page; Page
  Publishing Authorization can block publishing with no way to detect it in advance) or Instagram Login
  (Instagram user token).
- Permissions: Instagram Login `instagram_business_basic` + `instagram_business_content_publish`; Facebook
  Login `instagram_basic` + `instagram_content_publish` + `pages_read_engagement`.
- **100 API-published posts per rolling 24 hours** per account; check `content_publishing_limit`.
- Flow: create container (`media_type=REELS`, `video_url` on a **publicly reachable** server, or resumable
  upload to `rupload.facebook.com` which is limited to Facebook Login for Business apps), poll
  `status_code`, then `media_publish`. No native scheduling; Prakriti schedules and calls publish itself.
- Reels spec: MP4/MOV, moov atom at front, H.264 or HEVC, 23 to 60 fps, max 1920 px wide, 9:16
  recommended, VBR ≤25 Mbps, AAC ≤48 kHz 128 kbps, **3 seconds to 15 minutes, ≤300 MB**.
- Extras: `share_to_feed`, up to 3 `collaborators` (e.g. Gabriel and Serenity's personal accounts on a
  Yoga Marga reel), `trial_params` for trial reels (`MANUAL` or `SS_PERFORMANCE` graduation).
- App Review / Advanced Access for an app used only by its own admins on its own account: likely workable
  in development mode with the accounts added as app testers `[unverified]`.

## 11. TikTok Content Posting API [59]

- Direct Post needs the `video.publish` scope and an **audit**. Until then: "All content posted by
  unaudited clients will be restricted to private viewing mode"; at most 5 users can post per 24 hours and
  **the posting accounts must themselves be private** at posting time.
- Required UX even after audit: show the creator's nickname; privacy chosen manually from a dropdown with
  **no default**; Comment/Duet/Stitch off until ticked; commercial-content disclosure toggle; a preview;
  express consent before any upload; no promotional watermarks; processing notice; status polling.
- Per-creator cap "typically around 15 posts per day", shared across all apps; max duration comes from the
  creator-info call (300 s in the sample) [59].
- An "upload to inbox" mode (creator finishes the post in the TikTok app) exists in the endpoint paths
  [59]; whether it avoids the audit is `[unverified]`.
- Recommendation: TikTok is out of v1. If wanted later, Prakriti produces the vertical file and caption
  and a person posts, or the team applies for the audit.

## 12. Cloudflare storage and preview

R2 [60]: Standard $0.015/GB-month, Infrequent Access $0.01/GB-month (+$0.01/GB retrieval, 30-day minimum);
Class A $4.50/M, Class B $0.36/M; **egress free**; free tier 10 GB-month, 1M Class A, 10M Class B. Objects
up to ~5 TiB; single PUT up to 5 GiB; multipart up to 10,000 parts [60].

Workers [61]: request bodies capped at **100 MB on Free and Pro accounts** (200 MB Business). A 3 GB studio
file cannot be dragged through a Worker; the browser must upload straight to R2 with presigned multipart
URLs. Cron triggers up to 15 minutes; 128 MB memory per isolate [61]. Media work (ffmpeg, ML) cannot run in
a Worker; it runs on the Mac.

Stream [62]: $5 per 1,000 minutes stored per month (prepaid), $1 per 1,000 minutes delivered, free ingest
and encoding, 30 GB max file. Media Transformations (frames, clips, audio extraction from video) $0.50 per
1,000 unique operations after 5,000 free [62]. Images [63]: $5/100k stored, $1/100k delivered, $0.50 per
1,000 unique transformations after 5,000.

Sizing for 900 hours (my arithmetic):

| What | Size | R2 cost/month |
|---|---|---|
| Podcast MP3, 128 kbps mono | ~58 MB/h → ~52 GB | ~$0.63 (after free 10 GB) |
| Preview proxies, 540p H.264 ~1 Mbps | ~0.45 GB/h → ~405 GB | ~$6.08 |
| Masters at studio bitrate (2.78 GB/h) | ~2.5 TB | ~$37.50 Standard, ~$25 IA |
| **Stream** for the whole archive | 54,000 minutes | **~$270** storage alone |

Recommendation: R2 for audio, proxies and finished packages; HTML5 `<video>` over R2 (byte ranges) for
previews; masters stay on the studio RAID or an external drive with Takeout zips as the cold copy; no
Stream for the archive.

---

## 13. Recommended stack per pipeline stage

"Local" means the Mac that runs the watcher (see open question on which Mac).

| Stage | Recommended | Why | Cost per 1-hour recording | Alternative |
|---|---|---|---|---|
| Archive ingest | Google Takeout by the channel owner, in batches to an external drive [20] | Originals, sanctioned | $0 | Studio download (720p, 5/day) [19] |
| Studio ingest | Watch the OBS folder; wait for file size to stop changing; ask OBS for multitrack MKV going forward [65] | Exact per-speaker audio later | $0 | n/a |
| Audio extract | ffmpeg to 16 kHz mono WAV for ASR; 48 kHz for mastering | Standard | $0 | n/a |
| Transcribe | Apple SpeechAnalyzer (Hark engine) [L2][L3] | 206× real time, free, private | $0 (~20 s) | Scribe v2 $0.22/h (+$0.05 keyterms) [38] |
| Second engine | Parakeet TDT v3 + reconcile on disagreements [L4] | Catches each engine's misses | $0 (~60 s) | whisper.cpp turbo |
| Diarize + name speakers | FluidAudio with Gabriel/Serenity enrollment [51]; escalate to pyannoteAI identify if QA fails [47] | Local keeps students' voices off the cloud | $0 | pyannoteAI ~€0.11/h; AssemblyAI $0.25/h [48] |
| Triage | Claude Haiku 5.5, Batch [56] | Rank all 900 for ~$1.40 | ~$0.0015 | Sonnet 5.5 |
| Package | Claude Opus 5.5, Batch, structured outputs [56] | Quality where it matters | ~$0.18 to $0.35 | Sonnet 5.5 ~$0.09 to $0.18 |
| Audio master | Auphonic for curated and studio episodes [44][45]; ffmpeg two-pass loudnorm to -16 LUFS / -1 dBTP for bulk archive [66][32] | Leveler and speech isolation where it shows | $1.05 to $2.40 (Auphonic) or $0 | Auphonic for everything: $1,045 per 1,000 h |
| Intro / outro / mid-roll | Gabriel's real recorded voice now; ElevenLabs v4 with a founder's own PVC only after that founder makes it [40] | Consent enforced by vendor | ~$0.06 if generated | Stock ElevenLabs voice |
| Voice-training sets | Exclusive single-speaker segments → Voice Isolator → founder uploads to own PVC [41][40] | Isolator is not a speaker separator | $7.20/h of kept audio (training subset only) | Skip isolator on clean studio talks |
| Thumbnails | Real frames scored with Apple Vision + type, three options [64] | Honest, free, on-brand | $0 | Generative expand only for aspect fixes |
| Podcast publish | Self-hosted RSS on R2 under a Yoga Marga-owned domain; Apple, Spotify submit once [31][30] | Only autonomous route | ~$0.001/mo storage | RedCircle manual upload kit [29] |
| YouTube publish | Data API: private upload → human approve → `publishAt` [1][7]; playlist with `podcastStatus` [14]; captions upload for long-form [13] | Policy-compliant consent, quota ample | $0 (quota) | YouTube RSS ingestion for audio-only (not for the bulk archive) [28] |
| A/B thumbnails | Human starts Test & Compare in Studio [11] | No API | $0 | n/a |
| Reels | Instagram Graph API, R2 public URL [58] | 100/day cap is ample | $0 | Manual |
| TikTok | Deferred [59] | Audit required for public posts | n/a | Manual |
| Storage | R2 Standard for audio/proxies/packages [60] | Free egress | ~$0.01 to $0.04/mo | IA for masters |

**Cost per recording**, local-first path: about **$0.20 to $0.40** cash (Claude Batch dominates), or
**$1.25 to $2.75** if it also goes through Auphonic. Cloud-everything path (Scribe + keyterms +
pyannoteAI + Auphonic + Opus standard + TTS): about **$1.85 to $3.55** (my arithmetic from sections 4
to 8; euro prices converted at roughly 1.16 USD per EUR `[unverified rate]`).

**Backfill, 900 hours** (my arithmetic):

| Line | Local-first | Cloud-everything |
|---|---|---|
| Transcription | $0 (~7 h + ~15 h machine time) | Scribe $198 + keyterms $45 |
| Diarization / names | $0 | pyannoteAI Precision ~€101 |
| Haiku triage, all 900 | ~$1.40 | ~$1.40 |
| Opus packages | top 100 via Batch: ~$18 to $35; all 900: ~$160 to $315 | all 900 standard: ~$315 to $630 |
| Mastering | ffmpeg $0; Auphonic for top 100: $171 | Auphonic 1,000 h: $1,045 |
| Voice-training audio (2 founders × 3 h) | ~$43 (Voice Isolator) | ~$43 |
| **One-time total** | **~$60 to $530** depending on how many get full packages and Auphonic | **~$1,760 to $2,080** |
| Monthly run-rate | R2 ~$7 (audio + proxies), Auphonic S $13 for studio sessions, ElevenLabs Creator $22 per founder who clones, Anthropic usage a few dollars | similar plus per-hour cloud fees on new recordings |

The archive's cost is dominated by choices (how many get the Opus package, whether everything goes
through Auphonic), not by any API's price. The cheapest correct first move is triage on all 900, then
spend on the top slice.

---

## 14. Traps, blind spots and open questions raised by this track

1. **Who owns the channel, and will they do the consent click?** API access cannot be delegated through
   Studio roles [16]. Find out whether the Yoga Marga channel is a personal Google account, a Brand
   Account, or a Workspace account, and who the owner is.
2. **Private-only uploads**: unresolved conflict in Google's docs (2.2). Test once.
3. **Feature eligibility** of the channel (phone verification for >15-minute videos and thumbnails;
   advanced for chapters, A/B tests and RSS) [10].
4. **Auto-dubbing default** must be switched to manual before the first upload (2.12).
5. **Music in classes**: Content-ID-claimed videos are excluded from Takeout and auto-dubbing [20][26], and
   publishing class audio with commercial music invites claims. Whether yin classes carry a playlist is
   unknown `[open]`.
6. **Students' voices and names**: present in the first line of a class transcript (L1). Local
   transcription and diarization keep raw audio on-device; names must be redacted from text and
   segments with student voices cut from public audio; any cloud diarization or Scribe pass sends
   students' voices to a vendor. Waits on Serenity's privacy answer.
7. **"900 recordings" vs "900 hours"** changes every total above by whatever the average length is.
8. **Which Mac runs the watcher?** Ivan's laptop travels; the studio Mac is unknown; 805 GB free is not
   enough for the archive (1.2).
9. **iCloud as the studio's ingest path** puts the studio on Ivan's iCloud quota and on iCloud's eviction
   behavior (1.1, 1.2). Files can go `dataless`; the watcher must force-download (or the studio should save
   to local disk and sync out).
10. **Dual-mono capture** (L1): no per-speaker tracks; one OBS setting and one extra mic would make speaker
    isolation exact for every future recording [65].
11. **Feed domain ownership** (3.3): do not tie Yoga Marga's podcast permanently to Ivan's Cloudflare zone.
12. **Batch approval semantics**: YouTube requires express consent before each upload action [17]; whether
    "approve these five" satisfies it is an interpretation, not a documented rule `[unverified]`.
13. **The brief's 15k tokens per hour** is ~18k for talks plain and ~23k with timestamps; ~9k for classes
    (L1, [56]). Size `max_tokens` with thinking headroom on Opus 5.5 [L5].

---

## Sources

Local (read or measured on Ivan's Mac, 2026-10-08):
- **L1** `ffprobe`/`ffmpeg` on `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /`
  (codec, bitrate, L-R difference, EBU R128 loudness on 2026-09-23 10:00 to 12:00, words per transcript);
  `df`/`diskutil` on `/`; `SpeechTranscriber.supportedLocales`/`installedLocales` via a Swift probe.
- **L2** Benchmark files in this session's scratchpad (`.../scratchpad/bench/`): 10-minute extract of
  `2026-09-23 19-59-52.mp4`, Hark `diarize-proto` with and without speakers, `parakeet-mlx`.
- **L3** `/Users/ivanlizarde/Code/transcribe-app/START_HERE.md`, `/Users/ivanlizarde/Code/transcribe-app/CHANGELOG.md` (Hark).
- **L4** `/Users/ivanlizarde/.claude/skills/transcribe-audio/SKILL.md`; `/Users/ivanlizarde/Code/transcribe-3/START_HERE.md`.
- **L5** `~/.claude/projects/-Users-ivanlizarde-Documents-Claude-Projects/memory/model-choice-is-the-cost-lever.md`;
  `.../memory/a-model-switch-changes-every-request.md`.
- **L6** Bundled `claude-api` skill (model table cached 2026-10-06): thinking, forced tool_choice, refusal fallback behavior.

Web (fetched 2026-10-08):
1. https://developers.google.com/youtube/v3/docs/videos/insert
2. https://developers.google.com/youtube/v3/determine_quota_cost
3. https://developers.google.com/youtube/v3/revision_history
4. https://developers.google.com/youtube/v3/getting-started
5. https://developers.google.com/youtube/v3/guides/quota_and_compliance_audits
6. https://web.archive.org/web/2025/https://developers.google.com/youtube/v3/docs/videos/insert
7. https://developers.google.com/youtube/v3/docs/videos
8. https://developers.google.com/youtube/v3/docs/thumbnails/set
9. https://support.google.com/youtube/answer/72431
10. https://support.google.com/youtube/answer/9890437
11. https://support.google.com/youtube/answer/13861714
12. https://support.google.com/youtube/answer/9884579
13. https://developers.google.com/youtube/v3/docs/captions/insert ; https://developers.google.com/youtube/v3/docs/captions
14. https://developers.google.com/youtube/v3/docs/playlists
15. https://support.google.com/youtube/answer/10059070 ; https://support.google.com/youtube/answer/15424877
16. https://support.google.com/youtube/answer/9481328
17. https://developers.google.com/youtube/terms/developer-policies
18. https://www.youtube.com/static?template=terms
19. https://support.google.com/youtube/answer/56100
20. https://support.google.com/youtube/answer/9230970
21. https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide ; https://gigazine.net/gsc_news/en/20250925-yt-dlp-deno-javascript-runtime
22. https://developers.google.com/data-portability/user-guide/introduction ; https://developers.google.com/data-portability/policy ; https://dtinit.org/blog/2025/03/03/report-out-portability-in-practice
23. https://support.google.com/youtube/answer/2801973
24. https://support.google.com/youtube/answer/14328491
25. https://www.searchenginejournal.com/youtube-monetization-update-spam-not-reaction-channels/550755/ ; https://www.socialmediatoday.com/news/youtube-clarifies-monetization-update-inauthentic-repeated-content/752892/
26. https://ppc.land/youtube-auto-dubbing-tops-6m-daily-viewers-expands-to-27-languages ; https://outlierkit.com/resources/youtube-auto-dubbing-all-creators-global-growth-2026/
27. https://support.google.com/cloud/answer/7454865 ; https://discuss.google.dev/t/oauth2-refresh-token-expiration-and-youtube-api-v3/160874
28. https://support.google.com/youtube/answer/13525207 ; https://help.prx.org/hc/en-us/articles/43655810464411-PRX-x-YouTube-FAQ ; https://blubrry.com/manual/podcast-promotion/submit-podcast-youtube/ ; https://www.buzzsprout.com/help/207-youtube-submission
29. https://support.redcircle.com/redcircle-account-plans ; https://support.redcircle.com/uploading-an-episode ; https://support.redcircle.com/articles/1930996965-what-is-dynamic-insertion ; https://support.redcircle.com/redcircle-migration-guide ; https://pipedream.com/apps/redcircle-api
30. https://support.spotify.com/us/creators/article/podcast-specification-doc/ ; https://providersupport.spotify.com/article/podcast-delivery-specification-1-9 ; https://support.spotify.com/us/creators/article/video-episodes-for-shows-not-hosted-with-spotify/ ; https://community.spotify.com/t5/Spotify-for-Developers/Request-for-Access-to-Upload-Podcasts-to-Spotify-from-External/td-p/7044523 ; https://www.musicbusinessworldwide.com/spotify-launches-podcast-api-for-third-party-developers/
31. https://podcasters.apple.com/support/823-podcast-requirements
32. https://podcasters.apple.com/support/893-audio-requirements
33. https://podcasters.apple.com/support/5514-show-cover-template
34. https://podcasters.apple.com/support/5316-transcripts-on-apple-podcasts
35. https://podcasters.apple.com/support/5482-using-chapters-on-apple-podcasts
36. https://podcasting2.org/docs/podcast-namespace/1.0
37. https://op3.dev/
38. https://elevenlabs.io/pricing ; https://elevenlabs.io/pricing/api
39. https://elevenlabs.io/de/blog/eleven-v4 ; https://testingcatalog.com/elevenlabs-launches-eleven-v4-and-v4-turbo-voice-models
40. https://elevenlabs.io/docs/product-guides/voices/voice-cloning/professional-voice-cloning
41. https://elevenlabs.io/docs/capabilities/voice-isolator ; https://elevenlabs.io/docs/api-reference/audio-isolation/convert
42. https://elevenlabs.io/docs/capabilities/dubbing
43. https://elevenlabs.io/docs/capabilities/speech-to-text
44. https://auphonic.com/pricing (USD figures from the page's `data-price-dollar` attributes)
45. https://auphonic.com/help/algorithms/singletrack.html
46. https://huggingface.co/pyannote/speaker-diarization-community-1
47. https://www.pyannote.ai/pricing ; https://docs.pyannote.ai/models.md ; https://docs.pyannote.ai/tutorials/identification-with-voiceprints
48. https://www.assemblyai.com/pricing
49. https://deepgram.com/pricing
50. https://huggingface.co/nvidia/diar_streaming_sortformer_4spk-v2.1 ; https://soniqo.audio/guides/diarize ; https://huggingface.co/FluidInference/diar-streaming-sortformer-coreml
51. https://github.com/FluidInference/FluidAudio
52. https://www.gigazine.net/gsc_news/en/20250619-apple-speech-analyzer ; https://9to5mac.com/2025/06/18/apple-devices-offer-amazing-speech-to-text-transcription-in-developer-betas-shows-test ; https://rohitraj.tech/notes/apple-speechanalyzer-vs-whisper-on-device-stt-2026
53. https://developer.apple.com/documentation/speech/speechtranscriber
54. https://github.com/ggml-org/whisper.cpp ; https://github.com/anvanvan/mac-whisper-speedtest ; https://fazm.ai/blog/ggml-large-v3-turbo-bin ; https://simonwillison.net/2024/Aug/13/mlx-whisper
55. https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks ; https://www.argmaxinc.com/pricing ; https://www.argmaxinc.com/blog/argmax-sdk-2
56. https://platform.claude.com/docs/en/about-claude/pricing
57. https://platform.claude.com/docs/en/about-claude/models/overview
58. https://developers.facebook.com/docs/instagram-platform/content-publishing ; https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media
59. https://developers.tiktok.com/doc/content-posting-api-get-started ; https://developers.tiktok.com/doc/content-sharing-guidelines
60. https://developers.cloudflare.com/r2/pricing/ ; https://developers.cloudflare.com/r2/platform/limits/
61. https://developers.cloudflare.com/workers/platform/limits/
62. https://developers.cloudflare.com/stream/pricing/
63. https://developers.cloudflare.com/images/pricing/
64. https://developer.apple.com/documentation/vision/calculateimageaestheticsscoresrequest ; https://developer.apple.com/documentation/vision/detectfacecapturequalityrequest ; https://developer.apple.com/documentation/vision/generateattentionbasedsaliencyimagerequest ; https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest
65. https://obsproject.com/kb/multiple-audio-track-recording-guide
66. https://ffmpeg.org/ffmpeg-filters.html#loudnorm
