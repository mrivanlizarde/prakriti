# 04 · UI pattern research (Mobbin + web fallbacks)

Research track for Prakriti, written 2026-10-08 by a research agent working from `BRIEF.md` and
`2026-10-07-call-gabriel-transcript.txt`. Read-only research; nothing was sent, posted or changed.

## How this was done, and what the tools could and could not see

- **Mobbin MCP worked** (tools `search_screens`, `search_flows`, `search_sections`, no auth error).
  About 35 queries were run across all twelve requested areas plus seven extra areas that the
  transcript made relevant (clip generation, quality scoring, voice datasets, per-person knowledge
  bases, automation rules, the "needs you" home view, export packages, podcast metadata).
  Every Mobbin claim below cites the screen's `mobbin.com/screens/...`, `.../sites/sections/...` or
  `.../flows/...` link. I looked at each returned image; descriptions are of what is on screen.
- **Mobbin limits that matter for Prakriti:**
  - Mobbin's MCP only covers **web and iOS**. There is **no macOS app coverage**, so no Mac menu bar
    apps, no Hazel, no Frame.io Mac app, no Finder-style watched-folder UI. Those came from vendor
    docs via WebSearch and are marked as web-sourced.
  - **YouTube Studio is not on Mobbin.** Searches for the upload wizard and Test & Compare returned
    only consumer YouTube flows (e.g. community post polls,
    https://mobbin.com/screens/36f192d5-853a-4428-9fa8-104bc9989d0b). YouTube Studio facts below come
    from Google's help center.
  - **Apple.com sign-in, Arc, Things and Raycast sign-in screens were not returned.** Linear,
    Descript, Riverside, Frame.io, Superhuman and Notion were.
- Web sources are listed at the end and cited inline. Anything I inferred rather than saw is marked
  **[inferred]**; anything I could not confirm is marked **[unverified]**.

---

## TL;DR: the twelve UI decisions this research supports

1. **The features page is the sign-in page, and the right-hand side shows real output, not
   marketing art.** Riverside's sign-in sits in a modal whose right half shows a speaker-tagged
   transcript, a captioned frame and chapter labels
   (https://mobbin.com/screens/00e41aac-162a-457b-bc07-04f96c51f30f). Klaviyo puts four feature
   bullets next to the form (https://mobbin.com/screens/b913bc06-4fcf-4e33-adbd-cfd53f1ff898).
   Prakriti should do the same with one real (consented) excerpt from a Gabriel talk.
2. **Invite-only sign-in, two methods, "last used" memory.** Google plus passkey (the up-next
   precedent in BRIEF.md), no "Sign up" button, a "Last used" chip like Lovable
   (https://mobbin.com/screens/23a8697b-220b-4ed1-90c8-94b2bbcbef67) and Linear's "You used email to
   log in last time" (https://mobbin.com/screens/3997d60f-bea7-4068-af79-3942a664072e).
3. **Every recording gets one page with a vertical step list**, each step showing done, running
   (with a live timer) or waiting, plus an overall time estimate and the promise "we'll notify you".
   Emergent states exactly this: "It takes around 5-7 mins. We'll notify you once done."
   (https://mobbin.com/screens/dff53201-0975-445f-b0e1-75aa0353d9ba).
4. **"Skipped, and here is why" is a first-class state.** Mistral's library shows Skipped rows with
   the reason inline (https://mobbin.com/screens/003684d5-a229-4cff-a2a4-25dcbe87ad32). Prakriti
   needs this for classes where students speak, which wait on Serenity's privacy answer.
5. **The home screen is a "needs you" list with counts and one button per row**, modelled on Deel's
   "For you today" (https://mobbin.com/screens/6bd4989c-7a50-413e-be7e-e955b2394a29), plus a single
   progress line toward the stated goal (25 archive pieces live by Fri 6 Nov 2026, per BRIEF.md).
6. **The transcript is the timeline.** Descript, Grain, Otter and Substack all let you click text to
   seek and select text to make a clip (e.g. https://mobbin.com/screens/dc0ee15c-352a-4e6a-970f-20b62d6fa8fe).
   This also keeps Prakriti inside Ivan's "never skeuomorphic" rule (no drawn scrub bars or film
   strips): the words are the navigation, not a drawn timeline.
7. **Review uses Frame.io's model**: player, right rail of comments each stamped with a timecode
   chip, composer prefilled with the current time
   (https://mobbin.com/screens/39416f38-9246-4a6d-bc30-79874a268b5e), then a single Approve /
   Request changes decision (Toggl's tabs,
   https://mobbin.com/screens/501c9ea1-ae92-497d-8157-db174d744524).
8. **Sources (watched folders, the YouTube archive) are cards with a live status and a history**,
   like Gumloop's Synced history (https://mobbin.com/screens/67b777c8-be9b-4275-9dd5-16bab0abc5ab)
   and Sana's "Connection status: Synced Today 1:51 PM"
   (https://mobbin.com/screens/99d5da36-18d0-4dd8-ade1-059c58c494b7). The Mac doing the watching
   gets its own presence row, like Devin's "Link Devin Desktop with this account"
   (https://mobbin.com/screens/386fee01-1446-486a-84f9-7fb5128c771e).
9. **Automation is a plain When / Then recipe with readiness per step**, Contractbook style
   ("When: Draft is created [Ready] / Then: Request approval [Configure]",
   https://mobbin.com/screens/e20f6a03-6427-4bc2-bb72-e4ffc6577c95), with one per-source choice copied
   from OpusClip: "Ask me first" vs "Process automatically" (OpusClip help,
   https://help.opus.pro/docs/article/auto-import).
10. **Notification settings = delivery channels first, then an event matrix with a one-line
    description per event** (fal, https://mobbin.com/screens/a5b40b1a-3c52-4a6e-ab9e-047b643671d9;
    Otter, https://mobbin.com/screens/93ab8b2e-8fe3-430c-9416-9e32bcc2487f). Ask for Mac notification
    permission with a soft-ask that names the benefit ("Get notified when your tasks need input or
    are complete", Perplexity, https://mobbin.com/screens/1f1ecbe6-4b1a-4dec-8646-cf848b7e5657).
11. **Each person's knowledge base is its own "mind" with sources, a size meter and answers that cite
    the recording at the second it was said** (Delphi,
    https://mobbin.com/screens/a0e68c38-c83b-42bb-8049-b38178d0a8a8; Grain transcript-snippet search,
    https://mobbin.com/screens/6c4017ac-5b3d-4abe-82f8-a6c73c6f676f; NotebookLM-style citations,
    https://mobbin.com/screens/b102da47-7fa9-4356-8b85-493a5eab06e7).
12. **Voice-model datasets show minutes collected against a stated target and are locked behind
    consent.** ElevenLabs shows "Good 30 mins / Better 1 hr / Best 2 hrs" and "8 minutes more needed"
    (https://mobbin.com/screens/401b1c2c-e3e1-4ddd-97bb-517fa2e8b735). Prakriti should show the same
    as a plain number and bar (not ElevenLabs' dial), and show "Not consented" for Serenity until she
    says yes.

Three findings change scope and are expanded in **Surprises** at the end: YouTube's three-thumbnail
test is Studio-only with no API found; ElevenLabs Professional Voice Cloning only lets the voice owner
clone and verify their own voice; off-the-shelf "auto import from YouTube" tools ignore unlisted
videos, which is where the whole archive lives.

---

## 1. Features page that is also the login page

### 1a. Heroes with sign-in built in (search_sections)

| App | What is on screen | Link |
|---|---|---|
| Tines | A centred card sits **inside the hero**: logo, one line ("Built by you, powered by Tines"), two buttons, and a card footer "Already have an account? Log in." | https://mobbin.com/sites/sections/2b05eff8-4978-4c72-b9e6-0b1935bd7b5e , https://mobbin.com/sites/sections/8ecbe226-92d2-42ab-bf23-a8bf9e1d930a |
| Figma | Nav right: outline "Log in" beside filled "Get started for free"; giant type headline | https://mobbin.com/sites/sections/5f84e90e-f4ae-48e5-bdb0-9b0b9b303f03 |
| Maze | Pill "Log in" top right, huge two-line headline, two CTAs | https://mobbin.com/sites/sections/26e3e993-5f8b-43a3-82a3-92893f3150b4 |
| ClickUp | Email field in the hero beside a product screenshot | https://mobbin.com/sites/sections/8327bdfc-5c9d-4240-b4af-9431eebd0f9e |
| Passionfroot | Serif headline, real product UI fragments floating at the edges | https://mobbin.com/sites/sections/d008689a-c73f-4513-a760-25a93ef6f043 |
| Craft | Browser-framed product screenshot directly under the CTA | https://mobbin.com/sites/sections/81874e27-d807-48c6-8bf3-c2efd62b8c2f |
| Podia | Quiet "Login" text link beside "Sign up free" | https://mobbin.com/sites/sections/c37d35fe-c52e-41e8-b8fd-24f9be8d5f37 |

### 1b. Sign-in screens of premium products

| App | What is on screen | Link |
|---|---|---|
| Linear | "Log in to Linear": Continue with email (primary), the line "You used email to log in last time", Google, SAML SSO, **Log in with passkey**; "Don't have an account? Sign up or learn more" | https://mobbin.com/screens/3997d60f-bea7-4068-af79-3942a664072e |
| Linear | Magic link: "Check your email… temporary login link" + "Enter code manually"; code entry screen | https://mobbin.com/screens/6283263c-110a-489d-849b-d028795f3762 , https://mobbin.com/screens/fa5eecc4-532f-4cc2-a6e8-56814eefbf89 |
| Descript | Card on warm grey: Continue with Google, Use single sign-on, email + "Continue with email", "Use a password instead"; Terms and Privacy as tiny footer | https://mobbin.com/screens/bc48db6d-6307-41ed-a2fa-5d84b9a902f3 |
| Descript | 6-digit passcode with "Your code expires in 9:59", then an inline "Verifying passcode…" bar | https://mobbin.com/screens/9708122b-1592-4d36-b927-bc0a95e1eae3 , https://mobbin.com/screens/aecf441d-a739-40db-bab1-9b132c84c648 |
| Riverside | Login **modal over a blurred dashboard**; right half shows product proof: transcript lines with speaker names, a frame captioned "Studio-quality recording. Effortless editing.", waveform with chapter labels; Google / Apple / Spotify icons, email, SSO | https://mobbin.com/screens/00e41aac-162a-457b-bc07-04f96c51f30f |
| Riverside | Forgot-password toast that teaches: "If you usually sign in with SSO, Google, Apple, or Spotify, please sign in this way." | https://mobbin.com/screens/4eacdd06-f4b5-4b4a-8213-d7158fd26f89 |
| Superhuman | One value sentence ("The most productive email app ever made.") and only Google / Microsoft buttons, on a photographic background | https://mobbin.com/screens/43f85ea5-b1a8-4b7d-b7a7-2de316677564 |
| Superhuman | Sign-up modal floating over the **real app, blurred**; right panel "Trusted by teams at…" | https://mobbin.com/screens/50736706-c53b-4b79-b10a-02058ce34ed7 |
| Superhuman | After sign-in: two cards, "Superhuman for Chrome" vs "Superhuman for Desktop / Download Mac App" | https://mobbin.com/screens/48cd1fa5-385d-4dfb-a7bb-8f7aeeca89d8 |
| Notion | One-line product statement above the form ("Your AI workspace. Log in to your Notion account"), email + verification code "Resend in 18s", grid of Google / Apple / Microsoft / Passkey / SSO | https://mobbin.com/screens/ef4aba01-ca49-4180-9ef3-96c3fc6be970 |
| Lovable | Split: form left, gradient + example prompt right; **"Last used" badge** on the method | https://mobbin.com/screens/23a8697b-220b-4ed1-90c8-94b2bbcbef67 |
| Customer.io | "Last used" chip on email | https://mobbin.com/screens/5351ecaf-f558-4556-8041-6d9dcb1da59b |
| Klaviyo | Split: form left; right = headline + **four feature bullets** + product UI | https://mobbin.com/screens/b913bc06-4fcf-4e33-adbd-cfd53f1ff898 |
| SchoolAI | Right half = a live example of the product doing its job (a conversation) | https://mobbin.com/screens/15a164e9-3509-4456-94b4-ef729012622f |
| Hers | Login is a **right-side sheet over the still-visible marketing page** | https://mobbin.com/screens/5a182d8a-6ba7-4316-b4c7-eb1545ed6e8a |
| Deel | Login card over the marketing hero | https://mobbin.com/screens/497b5564-d6ae-488b-94c2-e98c927d3494 |
| Emergent | Right half = carousel of product screenshots | https://mobbin.com/screens/5043c70e-4f46-457f-bce2-7c8bfe58ab11 |
| Supabase / Vapi | Right half = a testimonial | https://mobbin.com/screens/d2486177-3b26-419a-aa55-a89dabbe7616 , https://mobbin.com/screens/ab11ec2f-51a5-4ab0-80e1-f75127c7fadb |

### 1c. "How it works" sections that explain a pipeline

| App | Pattern | Link |
|---|---|---|
| Givingli | Three numbered steps with a time promise in the subhead ("From brand upload to your first branded send in under five minutes") | https://mobbin.com/sites/sections/a0215bc8-784b-4371-a870-33d3f8d45e5a |
| Mora | "Three steps, no engineers required": Connect / Auto-generate / Customize | https://mobbin.com/sites/sections/d1616dbe-8e19-4089-92b8-96813e0a9042 |
| Browserbase | Three steps, each with a diagram of the actual mechanism | https://mobbin.com/sites/sections/687d0833-191b-4fba-8963-368492c97a10 |
| Function | One step per full-width panel: "STEP 01" eyebrow, headline, checklist, visual | https://mobbin.com/sites/sections/7c72acdf-c8a3-425c-b7a6-2e0c487bb17c |
| Titan | Accordion steps, the last one literally "Step 3) Let the system work" | https://mobbin.com/sites/sections/0d103afa-c85e-4568-a98a-0a1e7cbd5e8f |
| Railway | Vertical stepper joined by a line | https://mobbin.com/sites/sections/35a42526-d3b6-4e26-abf7-47667d6e7479 |
| Superpower / Biograph | Four or three cards: photo + product UI fragment + one sentence | https://mobbin.com/sites/sections/4f88b0b2-0b0a-4f83-abba-cc5971bd13b8 , https://mobbin.com/sites/sections/fd4a8ae0-654b-4887-842f-120212774d02 |
| Amie | Download / Start recording / Save hours | https://mobbin.com/sites/sections/6fbc3a73-93b8-4c35-8d6d-f8febfbcd1f5 |

### 1d. Feature sections from media products (the closest analogues)

| App | Pattern | Link |
|---|---|---|
| Descript | Output-type cards: Video content / Podcasts / Clips | https://mobbin.com/sites/sections/c1f30bed-39d0-4e82-b8e8-dc4a9eb5560b |
| Descript | Six-up workflow grid: Record / Transcribe / Collaborate / Promote / Share / Publish (publish names the podcast hosts) | https://mobbin.com/sites/sections/568bed84-64b4-4ceb-b871-ba3a7f6f3109 |
| Descript | "Sound like, smarter": a transcript sentence with "um um um" struck through | https://mobbin.com/sites/sections/b5bf1803-f0bb-4e97-91fc-f24a602cc934 |
| Descript | "Short clips that pop" with a row of real vertical clips | https://mobbin.com/sites/sections/5f7e5af0-1d81-4d42-9ac7-a1624fd9c478 |
| Loom | Tabbed list left (auto titles, summaries, chapters / filler and silence removal / video to doc), product visual right | https://mobbin.com/sites/sections/d8c7631c-efed-44f6-aedf-cae223b76928 |
| Dovetail | Quick setup (import from Zoom, Drive, SharePoint) / Accurate transcription (speaker + timestamp card) / Highlights | https://mobbin.com/sites/sections/306fae90-db3b-48b4-ac39-88b5c73e8622 |
| Butter | Import / Edit / Enhance / Ship | https://mobbin.com/sites/sections/7a5e830f-16c1-4dcb-89b6-9c8da829d388 |
| Superhuman | Tabs per product, each with headline, four bullets, visual | https://mobbin.com/sites/sections/a35451f7-dc25-4ac8-a1f8-9867c48b4573 |
| Framer | Tabbed tour that swaps the product visual | https://mobbin.com/sites/sections/556c62ee-b2af-4993-b400-187d98f1fd72 |

### 1e. Privacy / trust sections

| App | Pattern | Link |
|---|---|---|
| Shop | Plain-language promises in two columns ("Your data is only used to improve your experience, it's yours, and it's not for sale") | https://mobbin.com/sites/sections/a7b1096b-331c-4a63-9a4d-f33edd5d13d6 |
| Maze | Grid of promises, each with a small tag (Encrypted transmission, Access control, Private workspaces) | https://mobbin.com/sites/sections/b07657a6-9166-45b2-bdc3-3fc8e29e4534 |
| Deel | Four check cards: Security standards / Custom permissions / Approvals / Data logs | https://mobbin.com/sites/sections/fe644c39-7777-4641-8047-d8525138778b |
| Campsite | One statement card: "Private and secure." | https://mobbin.com/sites/sections/7dd8f0d7-cc02-4852-8557-7eaf89de6fa7 |

### Shared pattern
Premium sign-in is one column, three or fewer methods, no password by default, and the page
around it does the explaining. The strongest examples make the explanation **the product's own
output** (Riverside's transcript, SchoolAI's live conversation) rather than illustration. "How it
works" works best as three or four numbered steps with a time promise.

### Recommendation for Prakriti
One page at `prakriti.therowan.studio`, reading top to bottom:

1. **Nav**: wordmark left; one quiet "Sign in" link right (Podia/Figma). No "Get started", no
   pricing: access is by invitation for three people.
2. **Hero, split** (Klaviyo / Riverside): left = headline, one-sentence description, sign-in card
   (Continue with Google, Sign in with a passkey, "Last used" chip, and the line "Access is by
   invitation."). Right = **a real Prakriti package for one recording**, rendered as product UI, not
   art: a speaker-tagged transcript excerpt (Gabriel only, never a student), the quality score, three
   thumbnail options, the podcast episode card. On phones the right side moves below.
3. **How it works, four steps** (Givingli / Railway), copy in Ivan's voice (describe, never sell, no
   em dashes): "1. A recording lands in the Studio folder. 2. Prakriti notices and sends a Mac
   notification. 3. It makes the package: podcast episode, edited video, three thumbnails, a score,
   a transcript. 4. You say yes, and it posts." Put a realistic time under step 3 only once measured
   [inferred: no timing data exists yet].
4. **What every recording becomes**: an output grid like Descript's type cards: Podcast episode
   (with intro, outro and a short mid-roll), Edited video, Three thumbnails, Quality score (audio,
   video, message), Transcript by speaker, Voice-only audio for voice models (with a "needs consent"
   tag), Shorts.
5. **Your library becomes a teacher**: the per-person knowledge base, shown as an answer with a
   citation that jumps to the second it was said (section 9).
6. **Privacy, in plain promises** (Shop/Deel): "Students' voices and names stay out of anything
   public." "Nothing posts without a yes." "No voice model without the person's own consent."
   "Recordings stay in your storage." Each must be literally true at launch (Ivan's copy rule: no
   promise that breaks in week one).
7. **Footer**: who it is for (Yoga Marga), contact, The Rowan Studio credit.

Sign-in behaviour: Google + passkey (BRIEF says up-next already has both); email code as a fallback
with Descript's "expires in 9:59" countdown and auto-verify on the sixth digit; Riverside's
teaching error ("You usually sign in with Google"); after first sign-in on a Mac, a Superhuman-style
two-card choice: "Keep it in Safari" vs "Add Prakriti to your Dock" (see section 10 on why the Dock
web app matters for notifications).

---

## 2. Upload, import, drop zones, watched folders and connected sources

### 2a. Drop zones and upload progress

| App | What is on screen | Link |
|---|---|---|
| Fireflies | Whole Uploads page is the drop zone: "Upload a file to generate a transcript", lists formats (MP3, M4A, WAV, MP4, WEBM) and limits ("Max video size: 2.0 GB"); empty state "You have no recent uploads!"; a bottom-right tray with a **language selector** per upload | https://mobbin.com/screens/0e45d455-f884-44a9-8600-16830793250e |
| Proton Drive | Persistent bottom-right **upload tray**: "4 uploading (59%), 1 canceled", tabs All / Active / Completed / Failed, per-file speed in KB/s | https://mobbin.com/screens/218d53af-5262-4a58-ba33-150cf786437b |
| Zoom Clips | Drop zone + table with Name, "4.4 MB / 7.4 MB", bar, 60%, cancel x | https://mobbin.com/screens/42268236-8e19-4709-8369-88695d6ab52a |
| Airtable | Left rail of sources: Local files / Link (URL) / Google Drive / OneDrive / Box / Dropbox; pause and cancel | https://mobbin.com/screens/f5b0dbcb-bf2f-4b46-aea2-96584e251470 |
| Contractbook | Metadata fields **per file while it uploads** (title, date, parties, tag) | https://mobbin.com/screens/9ade8914-50df-486d-b7c9-a57829694ac4 |
| Sana | "Add meeting": Add notetaker vs Upload recording; inline "88% 62.9 MB"; title and start time fields | https://mobbin.com/screens/02f2ccf5-6dd8-405b-9b44-5044c562b538 |
| ElevenLabs Dubbing | Source tabs Upload / YouTube / TikTok / Other URL / Manual; "Number of speakers: Detect"; time range in hh:mm:ss | https://mobbin.com/screens/fc605526-6d01-435f-aaa3-f1cb55e5adf6 |
| Lindy / AirOps / Perplexity | Formats and size limit stated inside the drop zone; Perplexity's table shows Status "Queued" and "Uploading 0 of 1 files" | https://mobbin.com/screens/7dcd57a7-d2e9-4742-bb0f-9e7b364c139b , https://mobbin.com/screens/3c80b45c-6d21-4bd7-9e60-41ab67ef25e5 , https://mobbin.com/screens/02d41e9b-745a-4bd4-8e7f-89b0434acdd1 |

### 2b. Watched or synced sources

| App / source | What is on screen | Link |
|---|---|---|
| Twenty | Import radio cards "Everything" vs "Some folders", then an exclude toggle, then Visibility levels | https://mobbin.com/screens/cb784971-7c15-4e71-8727-3b902441dfd4 |
| Gumloop | A source page: file table with Status "Synced", right rail **History** (26 minutes ago, 1 change; 1 hour ago…) and "View full history" | https://mobbin.com/screens/67b777c8-be9b-4275-9dd5-16bab0abc5ab |
| Sana | Connect stepper "Connect / Select assets / Ready", then "You're good to go! Your files are syncing in the background"; integrations table with Connection status ("Active", "Synced Today, 1:51 PM"), Assets count, Access, Added by | https://mobbin.com/screens/f781b3e7-50e7-4329-8aa7-f52bd80b8049 , https://mobbin.com/screens/99d5da36-18d0-4dd8-ade1-059c58c494b7 (flow https://mobbin.com/flows/f342a720-9d29-4f26-a736-4f374b44f562) |
| Delphi | "Feeds" tab of auto-synced sources with "Last Synced 1 day ago"; "Want to add all videos from a YouTube channel? Click here" | https://mobbin.com/screens/96323107-29ba-4cda-99d8-a86ba32b7c6c , https://mobbin.com/screens/3932d9f0-f457-486d-b974-db93f5c18c26 |
| Render | Sync record + "Manual sync" button | https://mobbin.com/screens/c5051e6e-518e-4e39-a52e-c2d1865550af |
| Patreon | "Sync with Spotify" toggle labelled "Syncing is on" | https://mobbin.com/screens/8231f307-ea3b-4c9f-8465-6344e6b1ce71 |
| Monarch | "Syncing Account" modal with a step checklist (Syncing transactions, Updating net worth) | https://mobbin.com/screens/bcdcfb3d-ba04-4b15-8994-c079d6080948 |
| Rox | Integrations split into CURRENT (Connected badge, "0 emails processed (Last synced 2 min ago)") and NOT CONNECTED; toast "Gmail Connected" | https://mobbin.com/screens/2820d9c1-11bc-4134-9274-87035d73da60 |
| Devin | "Devin Desktop: Link Devin Desktop with this account [Log in to Devin Desktop]" above the web integrations | https://mobbin.com/screens/386fee01-1446-486a-84f9-7fb5128c771e |
| Neon | Global "All OK" status pill in the top bar | https://mobbin.com/screens/b9aaa8d7-3a64-42d5-8c0b-794b48213af9 |
| Customer.io | Red banner "This destination has been disabled. Data is not being received…" with an Enable action | https://mobbin.com/screens/0798eb2e-54fd-434b-b023-c374add64362 |
| **Frame.io Mac app (web docs)** | Watch Folders live in the **menu bar app**, "Watch Folders" tab, "Add+", choose a local folder; "Everything in this selected folder will be uploaded to your project"; works **only on local folders, not Network or External** | https://help.frame.io/en/articles/1772691-creating-watch-folders-with-the-frame-io-mac-app |
| **Frame.io launch coverage (web)** | Files can be shared with a team "with notifications sent upon upload"; interrupted transfers resume | https://www.provideocoalition.com/frame-io-debuts-watch-folders-a-high-speed-file-transfer-app/ [unverified beyond press summary] |
| **Hazel (web docs)** | Rules = Conditions + Actions; "any / all / none" at each level; first matching rule wins; "Preview Rule" shows matches without running actions | https://www.noodlesoft.com/manual/hazel/attributes-actions/action-reference/ , https://www.noodlesoft.com/?p=899 , https://www.noodlesoft.com/?p=905 |
| **OpusClip Auto Import (web docs)** | Checks hourly; two modes "Notify me via Email (Manual Processing)" vs "Auto create projects (Automatic Processing)"; **public videos only** | https://help.opus.pro/docs/article/auto-import |

### Shared pattern
A source is a card with: what it is, where it points, a status pill, "last checked / last synced",
a count, a pause toggle, a manual "check now", and a history. Health problems are a coloured banner
with one fix action. Desktop-dependent pieces (Frame.io, Devin) show the desktop helper as its own
connection.

### Recommendation for Prakriti
- **Sources page** with three source types: *Studio folder* (the iCloud shared folder named in
  BRIEF.md), *YouTube archive* (the ~900 unlisted videos), *Manual drop*. Each card:
  status pill (`Watching`, `Paused`, `Can't reach the folder`, `Waiting for iCloud to download`),
  "Last checked 2 min ago", "12 recordings, 3 new this week", toggle, "Check now", and a History
  rail like Gumloop's.
- **"Which Mac is watching" row** at the top of Sources and as a pill in the top bar (Neon's "All OK"):
  `Watching on Ivan's MacBook Pro` / `Ivan's Mac is asleep. New recordings will be picked up when it
  wakes.` BRIEF says Ivan's Mac travels; the UI must make that single point of failure visible
  [inferred].
- **iCloud caveat**: Frame.io refuses network and external folders. The Studio folder is an iCloud
  shared folder, where files can exist as not-yet-downloaded placeholders [inferred; verify with the
  Apple-APIs track]. Give it a real state: `Waiting for iCloud to finish downloading
  2026-10-08 Yin class.mp4 (1.4 GB)`.
- **Per-source autonomy switch** from OpusClip: `Ask me first` vs `Process automatically`. Default the
  Studio folder to automatic (Ivan's brief: no further input) and the archive to "ask first" until a
  first batch is reviewed.
- **Manual drop** is a full-page drop zone (Fireflies/Vimeo) that states formats and sizes, with a
  Proton-style tray for progress (All / Active / Done / Failed). While uploading, ask the one question
  the pipeline needs: **who is speaking** (Contractbook's metadata-while-uploading pattern), with
  chips `Gabriel`, `Serenity`, `Students present`, `Someone else`. Gabriel said on the call the tool
  "needs to have context of who's who".
- **Archive import** is a Delphi-style "add the whole channel" action plus a filterable list of what
  was found, so Ivan can pick the top 25 from the 900.

---

## 3. Processing queues, job status, progress and activity

### 3a. Lists of jobs

| App | Pattern | Link |
|---|---|---|
| Mistral | Tabs with counts **All (11) / Pending (0) / Fetched (5) / Failed (0) / Skipped (6)**; Skipped rows carry the **reason** in plain text | https://mobbin.com/screens/003684d5-a229-4cff-a2a4-25dcbe87ad32 |
| Plane | List grouped by state with counts: Backlog 3 / Todo 0 / In Progress 2 / Done / Cancelled | https://mobbin.com/screens/75e250ae-a106-4a28-999e-6e51e9ed20e5 |
| Mercor | Per-row amber pill "3 of 5 steps completed"; collapsed "Submitted applications (6)" group | https://mobbin.com/screens/1ac1f719-f20f-4666-9a42-d32cf7013008 |
| ElevenLabs | Batch table: Name / Agent / Status "In progress" / Progress 100% / Duration | https://mobbin.com/screens/b8057d86-6869-4f86-a823-0aa3a2a75f01 |
| AWS S3 | Summary (Succeeded / Failed with totals), ETA, transfer rate; per-row Succeeded / In progress (58%) / Pending | https://mobbin.com/screens/d0b2a1fa-99a9-4c29-ba83-f77a3f850d40 |
| Databricks | Run history with a success/fail bar chart over time, "top error codes", trigger type (manual vs scheduled), duration | https://mobbin.com/screens/84a71801-838b-477f-9bcf-6a07ed99b018 |
| Hume / Krea | Jobs filtered by status, sorted "Latest first", relative times ("39 mins ago") | https://mobbin.com/screens/fb393250-68ea-4349-a549-072970065d2d , https://mobbin.com/screens/a0740a94-6199-437e-a706-f31883037a44 |

### 3b. One job's progress

| App | Pattern | Link |
|---|---|---|
| Emergent | "Your app will be live soon! It takes around 5-7 mins. We'll notify you once done." Step list: done (check), active (spinner + **live timer 04:29**), waiting (circle) | https://mobbin.com/screens/dff53201-0975-445f-b0e1-75aa0353d9ba |
| Vercel | "Deployment started 7s ago"; accordion steps with check / spinner / clock, warning count, per-step duration | https://mobbin.com/screens/787123a5-8a85-4d1b-838f-705673a0c820 |
| Laravel Cloud | Steps grouped under "Build logs" and "Deployment logs", each "Pending"; toast "Deployment … is building" with Cancel | https://mobbin.com/screens/f9a999ee-f498-4a02-b17f-be383d866950 |
| Hers | Vertical timeline: done / current / future, with typical-duration chips ("avg 12 hrs", "avg 1-2 days") and "You'll be notified via SMS, email" | https://mobbin.com/screens/86231ec9-1c2b-4255-bfe0-8f30a3c32e4d |
| Resend | Status "Pending", horizontal event timeline with timestamps, yellow banner "This may take a few hours" | https://mobbin.com/screens/6f41111b-5a31-4d83-a3fa-ec3f2064a957 |
| HoneyBook | Automation run drawn as stacked nodes, each "COMPLETED" with timestamp | https://mobbin.com/screens/6b0c0c5b-4b33-4767-a2c1-6baafed1f422 |
| Relevance AI | "Running automated checks" checklist with spinners | https://mobbin.com/screens/d0dc629f-1593-4454-bc1c-2f759c5777ff |
| Semrush | "Gathering keywords data: 0/7" bar + a tip | https://mobbin.com/screens/446c7440-7d4f-4eac-bcab-5b9ab88d25b4 |

### 3c. Activity feeds

| App | Pattern | Link |
|---|---|---|
| Vercel | Grouped by month, sentence form ("You created alert rule…"), relative time on the right, filters by project / user / time / event | https://mobbin.com/screens/a111dca7-48a2-4456-bba7-acec68ff70f0 |
| Better Stack | System events ("Sent an email to…", "acknowledged by…") interleaved with human comments, comment box on top | https://mobbin.com/screens/f155b080-db3d-49b2-ba36-f47a0570db1f |
| incident.io | Status stepper across the top (Investigating > Fixing > Monitoring > …), "Ongoing for 23m 15s", grouped timeline, timestamps rail | https://mobbin.com/screens/590e4229-15d9-4d12-808b-2e5479a1d804 |
| Toggl | Audit log with "From None → To X" chips | https://mobbin.com/screens/2deef352-1f6b-4757-a4c9-dcce106b0e6a |
| Neon | Operation / status OK / Duration / Date, with a one-sentence explainer above | https://mobbin.com/screens/53d1a659-3ca1-4aba-9f7b-8353f71040dd |

### Shared pattern
Three nested views: a **queue grouped by state with counts**, a **per-item step list** that shows
which step is running and how long it has taken, and a **sentence-form activity feed** that mixes
system events with people. The best ones promise an outcome time and a notification.

### Recommendation for Prakriti
- **State vocabulary (use everywhere, same words, same colours):** `Found` → `Working` → `Needs you`
  → `Approved` → `Scheduled` → `Live`; side states `Skipped (with reason)` and `Stopped (with fix)`.
  Avoid engineer words ("failed", "pending", "job").
- **Queue page** grouped by those states with counts (Plane), plus tabs with counts (Mistral).
  Each row: thumbnail, title, source, speakers, duration, the current step as Mercor's "4 of 9 steps"
  pill, and time in step.
- **Recording page step list** (Emergent/Vercel): `Found in Studio folder` · `Copied` ·
  `Audio cleaned` · `Transcribed` · `Speakers tagged` · `Scored` · `Podcast episode cut` ·
  `Thumbnails drawn` · `Video edited` · `Waiting for your yes` · `Published`. Done steps show the time
  they took; the running step shows a live timer; the header says "About N minutes left. We'll send a
  Mac notification when it's ready." Use measured averages, shown like Hers' "avg" chips, never a
  guessed number.
- **Skipped with reason** (Mistral): `Skipped: students speak in this class. Waiting on Serenity's
  privacy rule.` `Skipped: under 3 minutes, looks like a test.` These are exactly the content types
  BRIEF.md lists (live yin classes with named students, short tests).
- **Stopped with fix** (Customer.io banner): `Stopped at Transcribed: the file ended early. Re-copy
  from the Studio folder?` [Retry].
- **Activity feed** in sentences, grouped by day, mixing system and people (Vercel + Better Stack):
  "Prakriti found 'Yoga Marga School talk, Oct 8' in the Studio folder." "Gabriel approved the
  podcast episode." "Posted to RedCircle at 9:00."
- Do **not** add charts of success/failure (Databricks) for three users; one line on the home page
  ("All 12 studio recordings processed this month, 1 skipped") is enough.

---

## 4. Media library and asset grid with filters

| App | Pattern | Link |
|---|---|---|
| Frame.io | Cards show **custom fields under the thumbnail** (Status, Date Uploaded, Shoot Location), "Fields 3 Visible", Collections (Videos / Images / Audio / Needs Review / Approved), search with "Jump to" and "Search for 'mountain' in Name / Notes / Audio Codec / Color Space" | https://mobbin.com/screens/85b2feb1-3ea7-4983-992b-3a28b45b23ec |
| Air | Filter bar: Locations / Type / Tags / Smart Tags / Status / Rating / Usage rights / More; "16 ASSETS"; Saved searches; duration on thumbs | https://mobbin.com/screens/5715ed4a-aa84-452b-8883-8ecb9a330731 |
| Runway | Grouped by date headers ("February 4, 2026 · 3 items"), type filter All / Image / Video / Audio, density slider | https://mobbin.com/screens/b2d58551-dd52-4bc5-a413-7fdca162ea7e |
| Zoom Clips | Tabs All / Mine / Playlists / Shared / Starred / Trash; sort; tag filter; grid/list toggle; duration badge | https://mobbin.com/screens/8ac631df-2124-44da-8199-2346d67375ac |
| ClickUp Clips | Left rail by type (Video / Voice / SyncUps / AI Notetaker) | https://mobbin.com/screens/ccfeaa37-a23f-4cda-9fa3-c4a709fffc83 |
| Arcade | Filters All / Status / Tags, "Last edited" sort | https://mobbin.com/screens/02beed61-a42e-462c-a824-b61b0a9ce46c |
| Google Ads | Type chips incl. "YouTube Video", aspect labels "Horizontal (16:9)", Cards/Table toggle | https://mobbin.com/screens/41430f1a-8fb3-4b1f-81d5-6af768f99cb0 |
| Loom | Video page: player, AI summary below, right rail tabs Edit / Activity / Transcript / Views / Settings, an AI "Suggested task" at 1:25 with Accept / Dismiss | https://mobbin.com/screens/ae8a3088-2b8b-4b5f-8f82-416fac3fa7d5 |
| Riverside | Project page: Record / Plan / Upload / Edit / AI Voice actions; "Magic Clips" and "Edit from Scratch" cards | https://mobbin.com/screens/c189c05b-bf62-4724-bbe4-1baf7312dc18 |

### Recommendation for Prakriti
- **Library** = grid (default) and list, grouped by month for the studio and by year for the archive.
- **Card fields** (Frame.io): status pill, speakers (initials), duration, quality score, and which
  outputs exist (small icons: episode, video, thumbnails, transcript).
- **Filters** (Air): Source (Studio / Archive), Speaker (Gabriel / Serenity / Students present),
  Kind (Talk / Class / Conversation / Test), Status, Score (e.g. "Message 8+"), Date.
- **Saved views** pinned in the sidebar: `Ready for your yes`, `Archive picks` (the top 25),
  `Needs privacy review`, `Live`.
- Search covers titles **and transcripts** (section 9), Frame.io-style "Search for X in: Title /
  Transcript / Notes".
- The **recording page** follows Grain (section 6): transcript left, player right, tabs for Package /
  Comments / Activity.

---

## 5. Review and approval with timecoded comments

| App | Pattern | Link |
|---|---|---|
| Frame.io | Dark player; right rail Comments / Fields; each comment has avatar, time, **amber timecode chip** (00:00, 02:53, 00:55), text, reactions, Reply, "#9"; composer pinned at bottom **prefilled with the current timecode**; Public visibility selector | https://mobbin.com/screens/39416f38-9246-4a6d-bc30-79874a268b5e |
| Frame.io | On-frame pin and drawing tools (arrow, line, box, pen, colours) | https://mobbin.com/screens/c2ad415a-4ac9-4b33-a51e-d122e7ee7b81 , https://mobbin.com/screens/9ae6c925-ff35-4042-b856-b19e9b4ef09c |
| Frame.io | Player "Guides" (2.35, 1.85, 16:9, **9:16**, 4:3, 1:1) and a 9:16 overlay on a 16:9 frame, for checking a vertical crop | https://mobbin.com/screens/9ec91edd-6331-4375-bb2d-4df57b621401 , https://mobbin.com/screens/8e9fc00c-e4ac-41aa-b812-b46b95d77a2b |
| Frame.io | Share-link view: "Expires in 11d", Download, "Featured Field: Status" | https://mobbin.com/screens/8717e433-40f5-4536-bb3e-6f418f4204bc |
| Toggl | Approval tabs: Pending review / **Changes requested** / Approved / Not submitted; a "Changes" column and "Requested by" | https://mobbin.com/screens/501c9ea1-ae92-497d-8157-db174d744524 |
| Otter | Select transcript text → inline comment box | https://mobbin.com/screens/99c07fb7-8a55-43a0-a7a0-1fb75e10b4cd |
| Assembly | Post page right rail: Date, [Schedule Post] [Post Now], Status "IN PROGRESS", **Approvals: "No approvers requested"**, Comments & Activity | https://mobbin.com/screens/17307d7f-95e7-420d-a3a9-95d77a7b040e |
| Deel | "37 of 37" summary cards + "Send reminder" | https://mobbin.com/screens/69aff800-d27f-4b29-b4dc-ee3d1e98579e |

### Recommendation for Prakriti
- A recording reaches `Needs you` with one **Review** screen: output tabs (Podcast / Video / Shorts /
  Thumbnails / Transcript), each with the player and a comment rail. Comments carry a timecode chip
  and the composer pre-fills the current time (Frame.io). Comments can also be left on selected
  transcript text (Otter).
- **One decision per output**, two buttons: `Approve` and `Ask for changes` (Toggl's states). "Ask for
  changes" requires a note; Prakriti re-runs only the affected step.
- **Approval is the safety rule made visible.** BRIEF.md: nothing outward-facing without a human yes.
  Put Assembly's "Approvals" field on every scheduled item: `Approved by Gabriel, Oct 9`.
- Who approves what is an open question (see end); design the field for one named approver per
  output.
- A 9:16 guide on the edited video (Frame.io) lets Ivan see what a Short will crop.
- Drawing on frames is **out of scope** for three people [inferred]; timecoded text comments are
  enough.

---

## 6. Transcript-based editing, speakers and clips

| App | Pattern | Link |
|---|---|---|
| Descript | Script left with **speaker name above each paragraph**, preview right, timeline below with a word-level track | https://mobbin.com/screens/745174ba-598b-428f-b37b-e0a9c827f98a |
| Descript | AI Tools: Sound good (Edit for clarity, Studio Sound, Remove filler words, Remove retakes, Shorten word gaps, Add chapters), Look good (Eye contact, Center active speaker, Green screen, Automatic multicam, Blur background), Repurpose (Create clips) | https://mobbin.com/screens/3d73ade6-ad02-4b61-9e86-cc13c1f00881 |
| Descript | Find gaps: "Gaps more than 3s, shorten to 1 seconds, Shorten all", results rail with timestamps | https://mobbin.com/screens/ab0009e2-0fb5-4932-9818-c60025d6b971 |
| Descript | Speaker picker "Select or type to add speaker": In this project / Add AI speaker / **Detect speakers** / Create new speaker | https://mobbin.com/screens/a633e048-ce64-4125-8a19-95ab829fc9ee |
| ElevenLabs STT | **Speaker lanes** at the bottom (Speaker 0 / Speaker 1 segments) with "Move segments to > Speaker 0" | https://mobbin.com/screens/b5300ae7-042c-493e-8e61-bc1e5f33749e |
| Otter | Keywords; **"Speakers: Lisa (79%), Charlie (21%)"**; "Show only highlights"; status "Realigning text with audio" | https://mobbin.com/screens/99c07fb7-8a55-43a0-a7a0-1fb75e10b4cd |
| Loom | Edit transcript: pause chips (1s, 2s, 3s), filler "um" struck through, search 1/5, toggles for removed silences/fillers | https://mobbin.com/screens/fd3a8f4d-a19f-453c-aba0-09dbb23f75f7 |
| Grain | Summary / Chapters / Transcript tabs left; player right with Timeline / Clips / Comments / Trackers / Metrics / Scorecard; Clips empty state "Select text in the transcript to create and share a clip" | https://mobbin.com/screens/9d83a3f1-9536-4c0c-9fcb-2898d9f8850d |
| Substack | Clip maker: video + transcript side by side, highlighted transcript is the selection, start/end time fields, "Download clip" / "Share to Notes" | https://mobbin.com/screens/dc0ee15c-352a-4e6a-970f-20b62d6fa8fe |
| Fireflies | Create Soundbite: Drag and Select / **Magic Soundbite** / Keyword Soundbite; loading copy "Digging through your conversations" | https://mobbin.com/screens/83fcd4f1-d17f-47ea-8198-7be889a996db |
| Apollo | Per-speaker lanes "Spoke: 11% · 2m", Create clip | https://mobbin.com/screens/650408a0-5110-4ab6-a044-2e4006f21f2a |

### Recommendation for Prakriti
- **Transcript view** (also the Markdown that feeds the knowledge base): speaker name above each
  paragraph, timestamp at the paragraph start, click to seek. Speaker share at the top like Otter:
  `Gabriel 82% · Student voices 11% · Serenity 7%`.
- **Speaker correction**: click a speaker label to reassign (Descript), or "Move this paragraph to"
  (ElevenLabs). This matters twice: the knowledge base must only take a person's own words, and the
  voice-only audio must only contain that person.
- **Student segments are flagged, not hidden**: a muted label `Student` with a privacy icon, and the
  package marks what will be cut or bleeped for public outputs [inferred design; the rule itself waits
  on Serenity].
- **Clips from text** (Grain/Substack): select a passage, "Make a Short". Prakriti also proposes
  clips automatically (Fireflies' "Magic Soundbite", Riverside's "Magic Clips"), each listed with its
  sentence, length and why it was picked.
- Keep Descript-level editing out of v1 [inferred]: the call asked for "minor edits", and Ivan's goal
  is posting, not polishing. Offer **trims and removals only**: cut a passage, shorten long pauses
  (Descript's "Gaps more than 3s"), remove filler words, with a before/after length.

---

## 7. Thumbnail selection and A/B testing

| App / source | Pattern | Link |
|---|---|---|
| TikTok Studio | Tabs "Select cover / Upload cover", frame picker, and a **live phone preview** with Feed / Profile / Web-TV tabs showing the cover in context | https://mobbin.com/screens/88160993-731a-4523-bdba-4ec119096285 |
| Suno | "Pick Cover Frame: This is what people see in the home feed and your profile before they play the video" | https://mobbin.com/screens/fbd26377-493a-4758-99ba-1401fac5bbc6 |
| Vimeo | Thumbnail row [+] [option] [option], selected one outlined | https://mobbin.com/screens/13f47f6c-b6da-40d9-99b6-8c3fcff25395 |
| Loom | "Recommend 1920 X 1080 or 16:9 files in .png or .jpg" | https://mobbin.com/screens/b4724029-7709-4127-8c99-7c84106a74cb |
| Upwork | Preview with zoom and move, option strip, "Save as draft" / "Publish" | https://mobbin.com/screens/5ea42cf0-245a-4bc9-a78a-ec43b9739ca3 |
| Grain | Cover image from Gallery / Pixabay / Upload | https://mobbin.com/screens/b8a783e9-4c69-41fb-a997-87cafbee5b83 |
| **YouTube Test & Compare (web)** | Test **up to 3 titles and/or thumbnails**; winner by **watch time share**; results "Winner", "Performed Same", "Inconclusive" (the older page says "Preferred" / "None"); "should be completed within two weeks"; **desktop YouTube Studio only**, "Advanced features" must be on; Shorts, scheduled lives, premieres, made-for-kids, mature and **private** videos excluded; results on the video Details page or the Reach tab | https://support.google.com/youtube/answer/16391400?hl=en , https://support.google.com/youtube/answer/13861714 |
| **YouTube Data API (web)** | `thumbnails.set` uploads one thumbnail for one video; no documented endpoint creates or reads a Test & Compare experiment | https://developers.google.com/youtube/v3/docs/thumbnails/set?hl=de (search summary; [unverified] beyond the method's single-thumbnail signature) |

### Recommendation for Prakriti
- Show the **three thumbnails in context**, TikTok-style: as they would appear in a YouTube home feed
  card at real size next to a title, not as loose images. A toggle for light/dark feed.
- Each option gets one sentence on what it is testing ("close-up, warm", "wide, text-led",
  "Serenity mid-sentence") so the test teaches something.
- Actions: `Use these three`, `Redraw this one`, `Swap for a frame I pick`. Frame picking should be a
  **grid of candidate frames** (real stills), not a drawn film strip, to respect Ivan's "never
  skeuomorphic" rule.
- **Hand-off, honestly labelled**: because Test & Compare appears to be Studio-only, the publish step
  for YouTube should set thumbnail A through the API and then show a checklist card: "Open YouTube
  Studio > this video > Test & compare, add B and C." with download buttons. The UI must not claim
  Prakriti runs the A/B test [inferred from the absence of an API].
- Track the outcome manually: a small field on the item, `Winner: B (watch time)`, so the library
  learns which styles win.
- Respect YouTube's quality floor (sub-720p thumbnails force all test images to 480p, per the Test &
  Compare help article summary): export 1280x720 or larger.

---

## 8. Publishing schedulers and calendars

| App | Pattern | Link |
|---|---|---|
| Buffer | Month calendar; post chip = channel icon + time + thumbnail; "Draft" label; List / Calendar toggle; filters All Posts / Channels / Tags / timezone "Los Angeles"; toast "Your post is live. View Post / Create Another" | https://mobbin.com/screens/82fb0dce-e613-44aa-abcd-20c9786e4f1b |
| Buffer | Create Post: Post / Reel / Story; First Comment; "Now" dropdown + Publish Now; Save Draft; "Create Another" | https://mobbin.com/screens/aeae32b9-fe87-47b6-b59f-5eba784b7607 |
| Later | Week view; **media rail on the left with an "unused" filter** to drag onto the calendar; best-time band highlighted; "Auto" (auto-publish) vs dashed "Draft" | https://mobbin.com/screens/7fb61612-cb90-40bb-968d-7bb1989ca12a |
| Hootsuite | Recommended-time slots and a "posted" badge; observances row | https://mobbin.com/screens/32be838c-21ee-4035-82a7-23fba1285b4b |
| Adobe Express | Calendar filter by post type with coloured dots: **Draft / Scheduled / Published / Failed** | https://mobbin.com/screens/f90999e7-48e7-4ef5-ad34-c028e0d6c551 |
| Adobe Express | Share dialog: channel, caption + Generate, **Schedule / Publish now** radio, "Set as draft" toggle, Preview | https://mobbin.com/screens/907b3f2e-1a6d-469c-a3f1-7ac2f4b5f0c5 |
| TikTok Studio | Schedule time + date, "Who can watch this video: Everyone", "Run a copyright check" toggle, Schedule / Discard, live phone preview | https://mobbin.com/screens/4ae6b2e2-c6ee-4d1c-a361-d1a5e9be06e8 |
| Vimeo | Schedule with date, time, **time zone**, recurring, link privacy | https://mobbin.com/screens/463d5b75-1ee9-478c-bbca-c7c0edff0650 |
| SoundCloud | Scheduled release with timezone and the validation "You can not schedule a date in the past"; header "Processing… 100%" | https://mobbin.com/screens/7b88bfdb-b30b-4868-b537-89f5b41c6c3b |
| Substack | Podcast metadata labelled with the RSS tags (`<itunes:explicit>`, `<itunes:episode>`, `<itunes:season>`, `<itunes:episodeType>` None / Full / Trailer / Bonus, `<itunes:image>` with Apple's 1400 to 3000 px note); "Auto-upload to YouTube" as a connected account | https://mobbin.com/screens/ccfecea2-2384-4a9a-aff7-cbbf448df35f |
| Kajabi | New episode: title, type, optional season, show notes ("appears on your Podcast page and listening apps"), "max 250 MB, mp3", explicit checkbox | https://mobbin.com/screens/23b75fe0-6710-4eee-9707-ac6ddf45f32f |
| Cofounder | Calendar + channel ON/OFF + a cadence slider ("8 posts/wk") | https://mobbin.com/screens/4b2d40f5-a3bd-4c07-b8c5-76f5de500f61 |
| **YouTube Studio upload (web)** | Steps: Details → Video elements → Checks → Visibility. Visibility: publish now as Private / Unlisted / Public, or schedule (stays private until then). Closing early saves as private. Up to 15 uploads at once | https://support.google.com/youtube/answer/57407 |

### Recommendation for Prakriti
- **Calendar** with Week (default) and Month, plus List (Buffer). Chips show channel (YouTube,
  Podcast, Shorts), time, thumbnail, and state using Adobe Express' four types renamed to Prakriti's
  vocabulary: `Draft`, `Scheduled`, `Live`, `Didn't post`.
- **Later's left rail is the key move for Ivan's goal**: a rail of `Approved, not yet scheduled`
  items to drag onto days, which turns the 25-piece archive target into a visible plan.
- **Cadence** setting (Cofounder): "Post 3 archive episodes a week, Tue / Thu / Sat 7:00". Prakriti
  fills empty slots from the approved rail automatically [inferred feature; matches "get out of our
  own way"].
- **Publish dialog** mirrors YouTube's own words so nothing surprises Gabriel: Visibility `Public /
  Unlisted / Private`, `Publish now` or `Schedule` with explicit time zone (Vimeo), and a podcast
  section with plain labels plus RSS hints in small print (Substack). Validation copy like
  SoundCloud's.
- **Every scheduled item shows its approver** (Assembly) and a post-publish toast with a link
  (Buffer: "Live on YouTube. View").

---

## 9. Knowledge base and search across the library, with citations

| App | Pattern | Link |
|---|---|---|
| Delphi (an AI "mind" of one person) | Knowledge page with Content / Feeds tabs; **size meter "930 of 1M words"**; filters Status Complete / Content Type / Word Count / Date Published; types Q&A, PDF, Website, Podcast, Manual, LinkedIn | https://mobbin.com/screens/a0e68c38-c83b-42bb-8049-b38178d0a8a8 |
| Delphi | Content Settings: Status, Type, Word Count, Context, Published Date, **"Content is by or about me"**, Citation URL, Hide citations, Folder | https://mobbin.com/screens/4576e54c-4053-4e03-a744-d645b3adc755 |
| Delphi | Empty: "Nothing Found. Add content to start training your Delphi" | https://mobbin.com/screens/09d6905d-2811-4380-b5c5-5e7f1ec352d8 |
| Delphi | Public directory of minds with suggested questions per person | https://mobbin.com/screens/b29eb123-cbd6-4146-8e8f-e0a53cc71d3d |
| Gemini Notebook | Three panes: **Sources** (checkbox per source, Select all, Add sources) / **Chat with numbered inline citations** / Studio (generated artifacts); "8 sources" under the composer | https://mobbin.com/screens/b102da47-7fa9-4356-8b85-493a5eab06e7 |
| Grain | Search with **"Include Transcripts"** toggle; each result shows matching transcript lines with **timestamps** (0:54, 0:15, 0:30) and "2 More"; filters Owner / Participants / Tags / Date / Meeting Type | https://mobbin.com/screens/6c4017ac-5b3d-4abe-82f8-a6c73c6f676f |
| Fireflies | "2 INSTANCES" + quoted snippets; "Ask anything across your meetings" | https://mobbin.com/screens/1be334c3-ea77-49a2-b7d3-18fbbf9f11b9 , https://mobbin.com/screens/79fdd82e-252f-4787-bc9d-7606eb0b217d |
| Dovetail | AI "Summary of 'banking'" card on top of ordinary search results | https://mobbin.com/screens/e4a2b078-4d85-472b-9539-696148bec4f2 |
| Apollo | Answer that quotes the speaker verbatim | https://mobbin.com/screens/bd771aa7-8298-4f12-9344-eb4706cf7390 |
| Intercom Fin | "This answer uses: Content (2), Guidance (3)" + rate Good / Acceptable / Poor | https://mobbin.com/screens/a4875514-1fa8-409f-b0f5-cf10f00294ca |
| Dropbox Dash | Visible reasoning: "Searching for 'Q1 challenges'", "Analyzing 20 sources from Gmail" with the list | https://mobbin.com/screens/f4ca9d48-c17a-40e5-98a2-f3a293483967 |
| Sana | Player with a timestamped transcript and "Search in meeting" | https://mobbin.com/screens/3dad3342-5941-457f-a91d-fff6e10c77eb |

### Recommendation for Prakriti
- **Two minds, one library.** A "Gabriel" and a "Serenity" page (Delphi pattern): sources, a size
  meter (`312 hours of Gabriel speaking, 1.9M words`), and filters by kind and date. Attribution is
  automatic from speaker tags, with Delphi's "by or about me" made concrete: `Said by Gabriel` vs
  `Mentions Gabriel`.
- **Ask**: a NotebookLM-style chat scoped to one person or both. Every answer quotes the words (Apollo)
  and every quote is a citation chip that opens the recording **at that second** (Grain's timestamps).
  Show "This answer uses 4 recordings" (Fin).
- **Search** everywhere includes transcripts by default (Grain's toggle, on), with result rows that
  show the matching sentence and its timestamp. An AI summary card on top (Dovetail) only when the
  query is a question.
- **Uses that serve the business** [inferred from the call: "structure future offers"]: saved
  questions on the person's page, e.g. "Everything Serenity has said about breath in yin", exportable
  as Markdown for the YTT syllabi BRIEF.md says Serenity owes.
- Serenity's page must say what is and is not in it, and respect her pending consent: the knowledge
  base can exist for private use, while anything that **speaks as her** (voice, avatar) stays locked
  (section 13).

---

## 10. Notification preference settings

| App | Pattern | Link |
|---|---|---|
| fal | **Delivery Channels first** (In-app "On by default · No setup required, always active"; Email "Enabled · Sending to…"; Slack "Connected · #general"), **then a matrix** of events × channels, events grouped, failures tagged "Critical" | https://mobbin.com/screens/a5b40b1a-3c52-4a6e-ab9e-047b643671d9 |
| Otter | Each event row has a **one-line plain description** ("Imported conversation: an imported conversation has been processed and is ready to view"); "All Notifications" master row; Email / Push | https://mobbin.com/screens/93ab8b2e-8fe3-430c-9416-9e32bcc2487f |
| AirOps | Events that map almost 1:1 to Prakriti: "Human review needed", "Input needed", "Playbook completed", "Playbook completed with issues", "Content scoring" | https://mobbin.com/screens/fcb3eaa8-fc70-41b9-be36-43a9a0bcb176 |
| Unify | Groups "My tasks / Success / Needs attention" | https://mobbin.com/screens/a80615c5-55c6-415d-9766-b0e3954386c0 |
| Vercel | Channels Web / Email / Push ("Subscribe Device") / SMS + "Mute: select projects" | https://mobbin.com/screens/2ef3689f-eb09-4d26-a6fd-3cda64208d78 |
| Air | "Digest emails: a round-up of unread notifications twice a day" | https://mobbin.com/screens/e6f97962-c24c-478b-b416-08830dc5b062 |
| Todoist | Master toggle "Desktop and web notifications" above the matrix | https://mobbin.com/screens/1f7a02c0-2c4e-4325-a563-19b5cacb138c |
| **Safari web apps on Mac (web)** | "Add to Dock" (requires macOS Sonoma 14 or later); allowed notifications appear in Notification Center; Dock badge for unread count if permission is granted **in the web app, not in Safari**; the web app appears in System Settings > Notifications under its own name | https://support.apple.com/en-au/104996 |
| **Declarative Web Push (web)** | Safari 18.5 on macOS 15.5 added push without a service worker; payload can set the app badge | https://webkit.org/?p=16923 , https://appleworld.today/2025/05/with-safari-18-5-included-in-macos-15-5-apple-added-declarative-web-push/ |

### Recommendation for Prakriti
- **Events** (the four Ivan named, plus the two the pipeline needs):
  1. `New recording found` ("A new recording appeared in the Studio folder.")
  2. `Started` ("Prakriti began making the package.")
  3. `Ready for your yes` ("A package is ready to review.")
  4. `Live` ("Something was published.")
  5. `Needs attention` ("Something stopped or was skipped and needs a decision.") tagged like fal's
     "Critical".
  6. `Weekly note` (Air-style digest: what went live, what is waiting).
- **Channels**: `Mac notification`, `Email`, `In Prakriti`. Per person defaults: Ivan gets all six on
  Mac; Gabriel and Serenity get only 3, 4 and 6 by default [inferred; confirm].
- **Mac notifications without a native app** are possible through a Safari "Add to Dock" web app plus
  Web Push, which also gives a Dock badge for "things waiting for you" (Apple support page above). The
  Apple-APIs track should decide between that and a native helper; the settings screen is the same
  either way. Note the gotcha from Apple's page: permission must be granted **inside the Dock app**, so
  onboarding must happen there.
- Matrix rows carry Otter's one-line description; channel cards sit above (fal) so the user first sees
  *where* and then *what*.

---

## 11. Onboarding with permission requests

| App | Pattern | Link |
|---|---|---|
| Perplexity | Soft-ask modal: "Stay in the know: Get notified when your tasks need input or are complete" [Enable notifications] | https://mobbin.com/screens/1f1ecbe6-4b1a-4dec-8646-cf848b7e5657 |
| Cursor | "Enable notifications: Get notified when your agent is done" with **Don't ask again / Not now / Allow** | https://mobbin.com/screens/a773fc91-0d05-4ca2-84d4-d7194628b67d |
| Skiff | "Turn on browser notifications" with a picture of what the notification will look like; "Skip for now" | https://mobbin.com/screens/278ca53b-1b43-4061-b61b-6728762ab21a |
| Linear | Integration step that lists what it will do **and what it will not** ("Linear will not ask for code read permissions"); "I'll do this later"; step dots | https://mobbin.com/screens/e0f6ce66-0d22-4858-b8a7-2d2aa3431b23 |
| Vanta (Slack OAuth) | "What will … be able to view? / do?" expandable rows | https://mobbin.com/screens/a809d8a3-4078-4cc9-abf8-83bc50e7eb3c |
| Causal | Connect modal with trust chips "SOC-2 Compliant", "AES-256 encryption" | flow https://mobbin.com/flows/c26c8046-07e0-476b-a44a-ec58c94858b9 |
| Sana | Connect / Select assets / Ready stepper ending in "You're good to go! Your files are syncing in the background" | https://mobbin.com/screens/f781b3e7-50e7-4329-8aa7-f52bd80b8049 |
| Superhuman | Post-sign-in choice of browser vs Mac app | https://mobbin.com/screens/48cd1fa5-385d-4dfb-a7bb-8f7aeeca89d8 |

### Recommendation for Prakriti
Two onboarding paths, each three or four screens, each skippable and resumable.

**Gabriel and Serenity** (after sign-in):
1. `Put Prakriti in your Dock` (Superhuman-style two cards; explains that this is how Mac
   notifications reach them) [depends on the Apple-APIs decision].
2. `Turn on notifications` soft-ask (Perplexity copy shape, Skiff's preview of the actual
   notification: "Ready for your yes: Yoga Marga School talk, Oct 8"). Buttons `Turn on` / `Not now`.
3. `Which voice is yours?` play two short clips from the library and ask "Is this you?" This trains
   speaker tagging and doubles as a check that the right person is signing in to their own mind
   [inferred].
4. Serenity only, separate and explicit: `Voice and likeness` page that states what is locked and why
   (section 13). Not a checkbox buried in onboarding.

**Ivan (admin)**: connect sources (Studio folder via the Mac helper, YouTube with Linear-style "will /
will not" lists, RedCircle), set the rule (section 16), set the cadence (section 8). Each connection
ends on Sana's "You're good to go… syncing in the background".

---

## 12. Empty states

| App | Copy and shape | Link |
|---|---|---|
| Vimeo | "It's empty in here. Drop videos to upload" [Upload]; the whole box is a drop target; links to guidelines | https://mobbin.com/screens/e3b6845e-0c22-4cdf-aa1b-24bc82b63677 |
| Elicit | "Upload papers to start using Elicit. Your library is used to store papers and research for analysis and insights." [Upload Papers] [Connect Zotero] (**two paths**) | https://mobbin.com/screens/e5d8e943-c6f2-418c-8414-542ba852463e |
| fal | Filtered-empty: "No assets match these filters. Try a different search term, media type, or collection." [Show all media], with active filter chips and Clear all | https://mobbin.com/screens/5b0d2d74-e226-422c-a834-579e7c6ac981 |
| Sweatpals | "No recent activity. Check-in activity will appear here as you scan tickets" | https://mobbin.com/screens/6b47a7fc-3b7f-4dae-9074-5b65ad236581 |
| Kajabi | "Once your customers register for the event, they will appear here." | https://mobbin.com/screens/8d06f806-6fd3-4845-bb5e-f000a31b170d |
| Visitors | "Collecting Data. We are still collecting data for this period." with dashes in place of numbers | https://mobbin.com/screens/73ce6686-1274-49a3-9c1d-30a8ebf3bdc3 |
| Grain | Clips tab: "Select text in the transcript to create and share a clip." | https://mobbin.com/screens/9d83a3f1-9536-4c0c-9fcb-2898d9f8850d |
| Frame.io | "Empty folder. Drag files and folders to begin." "0 items" | https://mobbin.com/screens/59b3fa49-146a-4c4d-9dab-8202c6068f76 |
| Delphi | "Nothing Found. Add content to start training your Delphi" | https://mobbin.com/screens/09d6905d-2811-4380-b5c5-5e7f1ec352d8 |

### Recommendation for Prakriti
Empty states say what will appear, **that it will appear on its own**, and offer the manual path.
Draft copy (no em dashes, describe-not-sell):

- Library, nothing yet: "Nothing here yet. New recordings in the Studio folder show up on their own.
  You can also drop a file here." [Choose a file] [Import the YouTube archive]
- Queue, all clear: "Nothing waiting for you. Prakriti is watching the Studio folder (checked 2 minutes
  ago)."
- Calendar, nothing scheduled: "Nothing scheduled this week. 6 approved pieces are ready to place."
- Filtered empty: "No recordings match these filters." [Clear filters]
- Serenity's mind, before consent or content: "Serenity's library is empty until her recordings are
  tagged. Nothing here speaks as her."
- Comments: "No comments. Approve, or leave a note at a moment in the recording."

---

## 13. Extra areas the transcript makes necessary

### 13a. Quality score (audio, video, message)

| App | Pattern | Link |
|---|---|---|
| Contra | Factor cards with an impact tag (HIGH IMPACT / MEDIUM IMPACT), value, chevron to detail | https://mobbin.com/screens/7693806f-0f39-4774-a494-827c20832054 |
| Lovable | Summary table **Category / Current / Potential**, then each issue in plain words with "Try to fix" | https://mobbin.com/screens/a2e7a566-5479-4ba2-8be0-589d62111401 |
| Higgsfield | "Overall Score 55/100" with sub-scores (Hook score, Hold rate) as bars | https://mobbin.com/screens/52444824-c16e-4d80-9b23-b0399581bb94 |
| Grain | Scorecard with 1-5 chips per category | https://mobbin.com/screens/407c6de1-2d96-4b97-b8ea-a9550dee3905 |

**Recommendation:** three numbers out of 10 (Audio, Video, Message), each with one sentence of why and
one suggested fix, plus Lovable's "after fixes" column (e.g. `Audio 5 → 8 after Studio Sound`). No
gauges or dials (skeuomorphic). The message score is the one that decides what goes live from the
archive ("the message is so powerful that it doesn't even matter", Gabriel on the call), so sort the
archive by Message by default.

### 13b. Speaker-isolated audio for voice models

| App / source | Pattern | Link |
|---|---|---|
| ElevenLabs PVC | Amount collected against thresholds "Good 30 mins / Better 1 hr / Best 2 hrs", "8 minutes more needed"; samples list with duration and source | https://mobbin.com/screens/401b1c2c-e3e1-4ddd-97bb-517fa2e8b735 |
| ElevenLabs PVC | Empty state offers "Separate multiple speakers: Upload your samples and we'll separate your voice for you!" | https://mobbin.com/screens/555d1963-7ce5-41b4-a0c2-ebfa3c0d3442 |
| ElevenLabs PVC | Sample settings: background noise removal, trim, "Multiple speakers detected: Choose your voice", "Any overlapping segments have been removed" | https://mobbin.com/screens/9e48042c-bc90-43a7-be3f-58ec344cf6b8 |
| ElevenLabs IVC | Consent checkbox "I hereby confirm that I have all necessary rights or consents to upload and clone these voice samples…" | https://mobbin.com/screens/aeeff1c7-9ab5-4bdb-bc9c-06b37b157b99 |
| **ElevenLabs PVC docs (web)** | Minimum 30 minutes, "closer to 2-3 hours" recommended; single speaker only; noise, reverb and music get cloned; MP3 192 kbps+; verification step read aloud by the owner, "For now, we only allow you to clone your own voice"; PVC slots: Creator/Pro 1, Scale 3, Business 10 | https://elevenlabs.io/docs/eleven-creative/voices/voice-cloning/professional-voice-cloning |

**Recommendation:** a `Voice` tab on each person's page: `Gabriel: 1 h 12 min of clean solo voice.
ElevenLabs suggests 30 minutes minimum and 2 to 3 hours for best results.` as a plain bar with the
thresholds marked, a list of contributing clips (each playable, each removable), and an export button.
For Serenity: `Locked. Serenity has not given consent. Prakriti collects nothing for a voice model.`
Because ElevenLabs requires the owner to verify, the last step is **theirs**: the button says "Send
Gabriel the dataset and the steps", not "Train voice".

### 13c. Per-video package download (Gabriel's "giant zip folder")

| App | Pattern | Link |
|---|---|---|
| Obvious | "Choose what to download", "4 of 10 selected", per-item format (Excel / PDF / Original), [Download 4 selected] | https://mobbin.com/screens/4a8c6ffb-553e-4d2f-92ab-4b3c66d8457f |
| Typeform | "Via email: receive a link to download via email. We will notify you once ready" vs "Direct download" | https://mobbin.com/screens/e2f9772f-62e2-49aa-8913-cf0a18bd0292 |
| Adobe Express | Format with a "Recommended" badge | https://mobbin.com/screens/f9b5b9eb-259d-4208-bc95-13ba3af9bfac |

**Recommendation:** every recording page has `Download package` (Obvious pattern) with all outputs
checked by default and a size total; large packages arrive as a link when ready (Typeform), which
also fires the `Live`-style notification. Name files predictably (e.g.
`2026-10-08 Yoga Marga talk / podcast.mp3`, `thumbnail-a.jpg`, `transcript.md`) [inferred].

### 13d. Home: the "needs you" view

| App | Pattern | Link |
|---|---|---|
| Deel | "For you today: To-dos that require your attention" rows with count badges and a [Review] button each | https://mobbin.com/screens/6bd4989c-7a50-413e-be7e-e955b2394a29 |
| Wrike | Status count table (New 6 / Planned 2 / In review 2 / Ready for review 1) | https://mobbin.com/screens/f47348fb-274b-4014-83d0-2b3dc5bdf53a |
| Plane | Workload tiles Backlog / Not started / Working on / Completed / Canceled + recent activity | https://mobbin.com/screens/dd30ddaf-136d-4171-9387-796ee6b5f3b3 |
| ClickUp | Home with an "AI StandUp (Last 7 days)" narrative | https://mobbin.com/screens/81eba05f-ec09-46ca-9e8a-976fff37b768 |

**Recommendation:** Home, top to bottom: (1) one sentence goal line,
`Archive: 4 of 25 live. Goal: Friday 6 November.` and `Studio: every new recording live within 72
hours. Last one took 41 hours.` (both targets from BRIEF.md); (2) `Needs you` rows with counts and one
button each (`3 episodes ready for your yes` [Review], `2 thumbnail sets to choose` [Choose],
`1 class waiting on the privacy rule` [Open]); (3) `Working now` (live step for each item);
(4) `This week` digest (ClickUp's narrative, two or three sentences).

### 13e. Automation rule (the watched-folder recipe)

| App | Pattern | Link |
|---|---|---|
| Contractbook | Two cards "When: Draft is created [Ready]" / "Then: Request approval [Configure]" | https://mobbin.com/screens/e20f6a03-6427-4bc2-bb72-e4ffc6577c95 |
| incident.io | "Workflow is triggered when…" / "Then checks the following conditions…" / "And runs immediately [Edit delay]" / steps / Add step; menu Test / Disable | https://mobbin.com/screens/d6001df7-21dc-4cc9-aebb-5aa03438912d |
| Asana | When / Check if / Do this, "Active" pill, Publish rule | https://mobbin.com/screens/c28147f8-6cac-45d9-9164-f4e87541f03b |
| Trello | Plain-sentence triggers ("when a card is added to the board by me") with an explainer line | https://mobbin.com/screens/4d712f0a-00a1-4b0a-8bd1-0ba23845bc1a |
| Hazel (web docs) | Conditions with any / all; first matching rule wins; Preview Rule without running actions | https://www.noodlesoft.com/?p=899 , https://www.noodlesoft.com/?p=905 |

**Recommendation:** one readable rule per source, not a builder, in v1:
"**When** a new recording appears in *Studio Recordings*, **and** it is longer than 3 minutes,
**then** make the full package, **and** ask Gabriel for a yes before anything posts." Each clause shows
readiness (Contractbook's Ready / Configure). Include Hazel's "Preview": `This rule would have picked up
11 of the 12 recordings already in the folder (skipped: 'test 2').` A rule can be paused, and
its activity is the source History (section 2).

---

## Cross-cutting rules derived from this research

1. **One status vocabulary**, plain words, used in the queue, calendar, library, notifications and
   emails: `Found`, `Working`, `Needs you`, `Approved`, `Scheduled`, `Live`, `Skipped`, `Stopped`.
2. **Every waiting state names what it waits for and who unblocks it** (Mistral's skipped reason,
   Hers' "you'll be notified").
3. **Time is shown as measured, never promised blind** (Emergent's estimate, Hers' "avg" chips). Until
   averages exist, show elapsed time only [inferred].
4. **The transcript is the navigation surface**; the player uses the browser's native controls.
   This satisfies Ivan's "never skeuomorphic" rule (no drawn scrub bars, film strips, dials).
5. **Real output instead of illustration** on the features page and in onboarding (Riverside,
   SchoolAI, Skiff's notification preview).
6. **Type**: Ivan's interface rule (SF Pro, 17 px body, nothing under 12 px) is larger than most
   Mobbin references, which run 12 to 13 px in tables (e.g. Frame.io rails, AWS tables). Plan for
   fewer columns and more rows; tables become lists on narrow widths.
7. **Consent and privacy are states, not settings buried in a menu**: `Students present`, `Not
   consented`, `Locked` appear on cards, pages and exports.
8. **Nothing outward-facing without a named yes** (BRIEF.md safety rule) is shown on every scheduled
   item as `Approved by …`.

## Proposed screen inventory (from the patterns above)

| # | Screen | Primary pattern source |
|---|---|---|
| 1 | Features + sign-in page | Riverside / Klaviyo split, Tines in-hero card, Givingli steps, Shop privacy |
| 2 | Home ("needs you") | Deel "For you today", Plane tiles, ClickUp weekly note |
| 3 | Queue | Plane grouping, Mistral tabs with reasons, Mercor step pill |
| 4 | Recording page (package + steps + transcript) | Emergent/Vercel step list, Grain layout, Descript speakers |
| 5 | Review (per output) | Frame.io comments, Toggl approve / changes |
| 6 | Thumbnails | TikTok in-context preview, Vimeo option row |
| 7 | Library | Frame.io card fields, Air filters, Runway date groups |
| 8 | Calendar | Buffer month, Later week + approved rail, Adobe Express states |
| 9 | Person pages (Gabriel, Serenity): Knowledge, Ask, Voice | Delphi, Gemini Notebook, Grain search, ElevenLabs PVC meter |
| 10 | Sources (folders, YouTube, manual) + Mac presence | Gumloop history, Sana status, Devin desktop row, Neon pill |
| 11 | Rule | Contractbook When/Then, Hazel preview |
| 12 | Activity | Vercel sentences, Better Stack mixing |
| 13 | Settings: notifications | fal channels + matrix, Otter descriptions |
| 14 | Onboarding (two paths) | Perplexity soft-ask, Skiff preview, Linear will/will-not, Sana stepper |
| 15 | Package download | Obvious selection, Typeform link-when-ready |

## Anti-patterns to avoid (seen in research, wrong for Prakriti)

- **Dials and gauges** (ElevenLabs' sample dial, Higgsfield's brain render): skeuomorphic; use a
  number and a bar.
- **Drawn film strips and scrub bars** for cover picking (TikTok, Suno): use a grid of real frames.
- **Sign-up, pricing, plan meters, trial banners** (Arcade, Fireflies, Plane): three invited users.
- **Builder-style automation canvases** (Employment Hero, HoneyBook graphs): one readable rule is
  enough for v1 [inferred].
- **Engineer status words** ("failed", "pending", error codes from Databricks): Gabriel and Serenity
  are the readers.

---

## Surprises (things that contradict or complicate BRIEF.md)

1. **The three-thumbnail A/B test cannot be fully automated.** YouTube's Test & Compare is
   desktop-Studio-only; I found no Data API endpoint for it, only `thumbnails.set` for a single
   thumbnail (https://support.google.com/youtube/answer/16391400?hl=en ;
   https://developers.google.com/youtube/v3/docs/thumbnails/set?hl=de). BRIEF's output "three thumbnail
   options (for YouTube A/B tests)" stays valid, but the test itself needs a human step in Studio. It
   now also tests titles, and it judges by **watch time share**, not clicks. Unlisted archive videos
   will likely get too few impressions to finish a test [inferred].
2. **ElevenLabs Professional Voice Cloning only lets the voice owner clone and verify their own
   voice** ("For now, we only allow you to clone your own voice"), needs 30 minutes minimum and 2 to
   3 hours for best results, and each PVC uses a plan slot (Creator/Pro: 1; Scale: 3)
   (https://elevenlabs.io/docs/eleven-creative/voices/voice-cloning/professional-voice-cloning). So
   Prakriti can prepare Gabriel's and Serenity's datasets, but cannot train their voices itself; each
   person must verify in an account that has a free PVC slot. It also means Serenity's consent is
   enforced by ElevenLabs as well as by policy. ElevenLabs can separate speakers itself, which lowers
   the bar on Prakriti's isolation quality but does not remove the need to exclude students.
3. **Off-the-shelf "auto import from YouTube" ignores unlisted videos.** OpusClip's Auto Import only
   detects "your own public YouTube videos" longer than 3 minutes uploaded after setup
   (https://help.opus.pro/docs/article/auto-import). The ~900-recording archive is unlisted, so
   Prakriti needs its own authorised channel listing [inferred; the infra track should confirm the
   YouTube Data API returns unlisted uploads to the owner].
4. **Watched folders in the best-known pro tool refuse non-local folders.** Frame.io's Mac watch
   folders "will not work" on network or external folders
   (https://help.frame.io/en/articles/1772691-creating-watch-folders-with-the-frame-io-mac-app).
   Prakriti's Studio folder is an **iCloud shared folder**; whether its files are fully downloaded at
   the moment of detection is a real failure mode [inferred; needs Apple-APIs verification]. The UI
   should expose a `Waiting for iCloud` state.
5. **Mac notifications may not require a native app.** Safari "Add to Dock" web apps (macOS 14+)
   receive Web Push notifications in Notification Center with a Dock badge, and Safari 18.5 added
   Declarative Web Push (https://support.apple.com/en-au/104996 ; https://webkit.org/?p=16923). That
   covers "processing started / complete" from the server, but detecting a new file in a local folder
   still needs something running on a Mac [inferred], which reopens the "Ivan's Mac travels" single
   point of failure.
6. **Mobbin cannot show Mac-app or YouTube Studio UI.** Any Mac helper (menu bar status, folder
   picker) has no Mobbin reference; the Apple HIG track is the source for that.

## Open questions for Ivan (UI decisions that depend on answers)

1. **Who approves what?** One approver per output (Gabriel for his talks, Serenity for hers), or Ivan
   for everything? The approval field and notification defaults depend on it.
2. **Which Mac watches the folder**, and what should the UI say when it is asleep or travelling? Is a
   studio Mac available (BRIEF: details unknown)?
3. **Serenity's privacy rule**: hold whole classes, or cut/bleep student segments? Determines whether
   `Students present` items show "Skipped" or "Needs privacy review".
4. **Do Gabriel and Serenity want phone access** (approve from an iPhone)? This research did not cover
   iOS patterns in depth; Mobbin has strong iOS coverage if needed.
5. **Publishing**: does Prakriti post through APIs (YouTube, RedCircle) or prepare everything and hand
   off a checklist? The calendar's "Live" state and toasts assume direct posting.
6. **Thumbnail hand-off**: is a manual Studio step for Test & Compare acceptable, or should Prakriti
   just pick one thumbnail and skip testing on unlisted archive pieces?
7. **Voice datasets**: whose ElevenLabs account receives each dataset, and is a plan with two PVC
   slots in place?

---

## Web sources used

- YouTube, A/B test titles & thumbnails: https://support.google.com/youtube/answer/16391400?hl=en
- YouTube, Test & compare thumbnails: https://support.google.com/youtube/answer/13861714
- YouTube, Upload YouTube videos: https://support.google.com/youtube/answer/57407
- YouTube Data API, thumbnails.set: https://developers.google.com/youtube/v3/docs/thumbnails/set?hl=de
- ElevenLabs, Professional Voice Cloning: https://elevenlabs.io/docs/eleven-creative/voices/voice-cloning/professional-voice-cloning
- Frame.io, Creating watch folders with the Frame.io Mac app: https://help.frame.io/en/articles/1772691-creating-watch-folders-with-the-frame-io-mac-app
- ProVideo Coalition, Frame.io debuts Watch Folders: https://www.provideocoalition.com/frame-io-debuts-watch-folders-a-high-speed-file-transfer-app/
- Noodlesoft Hazel manual (action reference, rule logic, preview): https://www.noodlesoft.com/manual/hazel/attributes-actions/action-reference/ , https://www.noodlesoft.com/?p=899 , https://www.noodlesoft.com/?p=905
- OpusClip, Auto Import: https://help.opus.pro/docs/article/auto-import
- Apple, Use Safari web apps on Mac: https://support.apple.com/en-au/104996
- WebKit, Safari 18.5 features (Declarative Web Push): https://webkit.org/?p=16923
- AppleWorld.Today on Declarative Web Push in macOS 15.5: https://appleworld.today/2025/05/with-safari-18-5-included-in-macos-15-5-apple-added-declarative-web-push/
