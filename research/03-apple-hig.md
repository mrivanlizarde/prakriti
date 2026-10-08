# 03. Apple Human Interface Guidelines pass for Prakriti

Track: Apple HIG. Written 2026-10-08 by a Sonny research agent. Read-only research; nothing was
changed, sent or published. Every claim carries a source. `[unverified]` marks anything I could not
confirm against a primary source. `[rec]` marks my recommendation, not Apple's guidance.

Inputs read first: `~/Code/prakriti/research/BRIEF.md` and
`~/Code/prakriti/research/2026-10-07-call-gabriel-transcript.txt`.

Note on style: this file contains no em dashes on purpose, because downstream agents may lift copy
from it into things Gabriel and Serenity read (BRIEF.md, "People and constraints").

---

## How this was done (so a later agent can repeat it)

- Fetched **83 current HIG pages on 2026-10-08** from Apple's own data endpoint
  `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`, which
  is the same content rendered at `https://developer.apple.com/design/human-interface-guidelines/<slug>`.
  Converted to text locally and read. In the rest of this file, a citation like **[HIG: notifications]**
  means `https://developer.apple.com/design/human-interface-guidelines/notifications`.
- Fetched Apple developer docs the same way (`/tutorials/data/documentation/<path>.json`) for
  UserNotifications, SwiftUI `MenuBarExtra`, ServiceManagement `SMAppService`, ActivityKit,
  Foundation Models, and Info.plist privacy keys. Cited as **[DOC: path]** meaning
  `https://developer.apple.com/documentation/<path>`.
- Looked at three Apple web surfaces in the Browser pane, signed out, nothing entered:
  `https://www.icloud.com/` (signed-out page and its Sign In card), `https://account.apple.com/sign-in`,
  and `https://www.apple.com/final-cut-pro/` (via WebFetch).
- Read metadata only (size, duration, resolution via `ffprobe`) of the studio folder
  `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /`. Did not open
  transcripts (they contain student names).
- **Freshness of the HIG** (from each page's change log): Design principles were *reintroduced*
  2026-06-08 (WWDC26 session 250, "Principles of great design") [HIG: design-principles];
  Generative AI updated 2026-06-08 [HIG: generative-ai]; Searching and Sidebars 2026-06-08;
  Layout 2026-09-09 [HIG: layout]; Branding 2026-09-09 [HIG: branding]; Writing 2025-12-16
  [HIG: writing]; Live Activities gained macOS guidance 2025-12-16 [HIG: live-activities].
  The Notifications page itself last changed 2023-10-24, watchOS only [HIG: notifications].
- **There is no HIG for the web.** Apple's own web apps (iCloud.com, account.apple.com, apple.com
  product pages) are the better reference for checklists A and C, and the HIG is translated into
  web terms where it applies.

---

## 0. The findings that change the plan (read this if nothing else)

1. **The HIG pushes back on "notify me when it's detected, when it starts, and when it's done."**
   Apple says to avoid multiple notifications for the same thing [HIG: notifications], that people
   only need to hear when a task *fails* because they expect success [HIG: feedback], and, in so
   many words, not to notify people simply because a task completes [HIG: activity-views].
   Reconciled in section 6: one notification *per recording* that updates in place (same request
   identifier replaces the old one in Notification Center [DOC: usernotifications/unnotificationrequest/init(identifier:content:trigger:)]),
   "started" delivered quietly, and "complete" merged into "Ready for Review", which is a decision,
   not a status. Ivan still gets all three moments; Notification Center holds one entry per recording.
2. **The archive breaks per-item notifications outright.** About 900 archive recordings
   (BRIEF.md) times three notifications is roughly 2,700 banners. Archive work must be a
   once-a-day summary, never per item [rec, grounded in HIG: notifications and HIG: managing-notifications].
3. **Tests would be noise.** 3 of the 12 studio recordings are 8 to 11 seconds long (section 9).
   Clips under a threshold (suggest 60 seconds) should produce no notification [rec].
4. **A Mac notification only reaches the Mac that posts it.** A native agent on the studio Mac (or
   Ivan's laptop, which travels, BRIEF.md) cannot notify Gabriel's M2 Mac or Serenity. The clean
   answer is **Web Push from prakriti.therowan.studio**: Safari supports Web Push on macOS since
   Ventura, and a site added with File > Add to Dock (macOS Sonoma 14+) becomes a web app whose
   notifications arrive as normal macOS notifications and whose Dock icon shows an unread badge
   ([Apple Support 104996](https://support.apple.com/en-us/104996); WWDC22 session 10098 per
   search result). So: native notifications for whoever runs the agent; Web Push for review
   decisions to everyone [rec].
5. **"Autonomous" must mean autonomous intake and processing, not autonomous posting.** The HIG's
   Generative AI page says to keep people in control and get permission before irreversible
   actions [HIG: generative-ai]; BRIEF.md's standing rule says nothing outward-facing without a
   human yes. No Approve or Publish button inside a notification [rec].
6. **The features page doubling as the login page is exactly what the HIG asks for**: delay
   sign-in, explain the benefit of the account in the sign-in view [HIG: managing-accounts],
   [HIG: sign-in-with-apple]. Apple's closest analog is the signed-out **iCloud.com** page: huge
   product name, one sentence of what it is, one Sign In button, two short paragraphs (observed
   2026-10-08).
7. **Quality score must not be a bare number.** The HIG says to translate confidence values into
   concepts people already understand and avoid percentages and statistical jargon
   [HIG: machine-learning]. Use three plain categories with factual reasons (section 5, C-Q).
8. **AI voice must be disclosed.** ElevenLabs intros and outros in Gabriel's or Serenity's voice:
   "Never trick someone into thinking they're interacting with or viewing content authored by a
   human" if it is AI [HIG: generative-ai]. Label it in the app, and decide whether listeners are
   told (open question). Serenity has not consented to an AI version of herself (BRIEF.md).
9. **The menu bar icon can disappear, so the watcher must not live in the icon.** HIG: let people,
   not the app, decide whether the menu bar extra shows, and never rely on its presence
   [HIG: the-menu-bar]. macOS 26 has a System Settings > Menu Bar > "Allow in the Menu Bar" switch
   per app (third-party reports, see Sources). And Apple's `MenuBarExtra` docs say an app that only
   shows in the menu bar is **terminated** if the user removes the extra [DOC: swiftui/menubarextra].
   So the folder watcher runs as a separate login item / LaunchAgent via `SMAppService`
   [DOC: servicemanagement/smappservice], and the icon is just a window onto it [rec].
10. **Ivan's standing rules collide with Apple in four places** (section 7): SF Pro may not be
    embedded on a website (license), macOS native menus render at 13 pt system size, the native
    video player has a scrubber, and apple.com's punning voice is the opposite of "describe, never
    sell". Each has a clean resolution.

---

## 1. Apple's 2026 design principles, applied

Source for all rows: [HIG: design-principles], reintroduced 2026-06-08.

| Principle (Apple's line) | What it means for Prakriti | How to test it |
|---|---|---|
| Purpose: make something meaningful; keep focused | The point is Gabriel's sentence: get out of our own way and hit post (transcript). Every screen should move a recording toward published. | For each screen, name the one action that moves work forward. If none, cut the screen. |
| Agency: stay out of the way; help people recover from mistakes | Processing runs without asking. Every approval can be undone until it is live; every generated piece can be retried or reverted. | Undo exists for every approve, reject, edit. |
| Responsibility: be transparent; collect only what is needed | Say what goes to which service (Anthropic, ElevenLabs, YouTube, RedCircle). Student voices stay out of public output until Serenity's rule exists (BRIEF.md). | Privacy section on the features page names every external service. |
| Familiarity: use concepts people know; clear feedback | Library, Review, Published. Native audio/video players. Standard menu bar behaviors. | A new user can say what each nav item holds without hovering. |
| Flexibility: design for everyone; preserve context | Works on Mac, iPhone, keyboard, VoiceOver. Restores last view. | 375 px wide, keyboard only, VoiceOver pass. |
| Simplicity: include just what is necessary; be concise | Outputs switch on one at a time (agreed sequencing, BRIEF.md). Minimal settings. | Settings fit in one window pane each. |
| Craft: care about every detail | Notification copy, icon, empty states, sound. | Render and look, every state (BRIEF.md rule). |
| Delight: identify the emotion; don't mistake delight for decoration | The feeling is relief: "it's handled." Not excitement. No decoration (Ivan: never skeuomorphic). | No element exists only to look nice. |

---

## 2. HIG guidance by topic (testable extracts)

Each line: the guidance, then where it applies (A = features/login page, B = macOS agent, C = web app).

### 2.1 Foundations

**Accessibility** [HIG: accessibility]
- Text contrast: at least 4.5:1 up to 17 pt; 3:1 at 18 pt and above or bold (WCAG AA values Apple's Accessibility Inspector uses). Check light and dark. (A, B, C)
- Dark Mode page asks for 4.5:1 minimum and *strive for 7:1* for custom colors, especially small text [HIG: dark-mode]. (A, C)
- Don't convey information by color alone; add shape, icon or text. (status chips in C; menu bar states in B)
- Minimum control sizes: macOS 28x28 pt default, 20x20 minimum; touch 44x44 pt. Padding about 12 pt around bezeled controls, about 24 pt around unbezeled ones. (A, B, C)
- Captions and transcripts for audio and video; transcripts are explicitly recommended for podcasts. Prakriti already produces transcripts; surface them next to every player. (C)
- Let people control playback; avoid autoplay without controls. (A hero video, C players)
- Reduce Motion: replace movement with fades, no zoom/scale loops. (A, B animated icon, C)
- Minimize time-boxed UI that auto-dismisses. Toasts that vanish are a problem; prefer persistent inline status. (C)
- Support Full Keyboard Access, Voice Control, VoiceOver labels on every control. (B, C)

**Color** [HIG: color], **Dark Mode** [HIG: dark-mode]
- Every custom color needs light, dark and increased-contrast variants. (A, B, C)
- Avoid using the same color to mean different things. Reserve the accent for the primary action and status. (A, C)
- **Avoid offering an app-specific appearance setting**; follow the system. (C; the web equivalent is `prefers-color-scheme` with no visible toggle) [rec]
- A permanently dark appearance is acceptable for immersive media viewing. (C: the video review stage can stay dark) [HIG: dark-mode]
- Soften white backgrounds in images shown in dark mode (thumbnails with white). (C)

**Typography** [HIG: typography]
- macOS default text 13 pt, minimum 10 pt; iOS default 17 pt, minimum 11 pt. macOS has no Dynamic Type.
- macOS text styles: Body 13/16, Headline 13 bold, Title 1 22, Large Title 26, Footnote and Captions 10 pt.
- Avoid Ultralight, Thin, Light weights. Minimize the number of typefaces.
- Branding page: custom font for headlines is fine; system font for body and captions [HIG: branding].
- For the web: SF Pro is licensed **only for mock-ups of UI for Apple platforms** and may not be used for "website content" or embedded ([developer.apple.com/fonts](https://developer.apple.com/fonts/), license text). Use the system font stack (`system-ui`, or `-apple-system` as Up Next already does in `~/Code/up-next/public/assets/base.css` tokens), which renders SF on Apple devices without shipping the font ([Apple Developer Forums thread 733267](https://developer.apple.com/forums/thread/733267), community answer quoting an Apple forum reply). (A, C)

**Layout** [HIG: layout]
- Order by importance, top and leading. Group related items. Progressive disclosure.
- macOS: avoid critical controls or information at the bottom of a window, because people drag windows partly off screen. Same for the bottom of sidebars [HIG: sidebars]. (B Settings window; C desktop layout: keep Approve at top of the detail pane, not a footer)

**Materials** [HIG: materials]
- Liquid Glass belongs to the control layer (bars, sidebars), never the content layer; use sparingly. (C: at most a translucent top bar; no glass cards) Native menus in B get it automatically.

**Motion** [HIG: motion]
- Purposeful only; make it optional; avoid motion on frequent interactions; let people cancel motion. (A, C)
- Animated SF Symbols are appropriate for ongoing activity (Pulse, Breathe, Variable Color, Rotate) [HIG: sf-symbols]. (B menu bar icon while working)

**Writing** [HIG: writing], **Inclusion** [HIG: inclusion]
- Plain words, no jargon, define terms. Verbs on buttons ("Send" beats "Let's do it!"). Never "Click here".
- **Avoid "we"** in UI ("We're having trouble loading" becomes "Unable to load content"). Use "you".
- Errors: as close to the problem as possible, no blame, say how to fix; no "oops" or "uh-oh".
- Empty states give a next step and a button.
- Settings labels: describe what *on* does.
- Use "click" on Mac and "tap" on touch devices; do not mix.
- Humor and colloquialisms: careful, they translate badly.

**Privacy** [HIG: privacy]
- Request access only when needed, in context, not at launch unless essential.
- Purpose strings: one active, specific sentence with a period. Good: "The app records during the night to detect snoring sounds." Bad: "Microphone access is needed for a better experience."
- A pre-permission screen may have **one button only**, titled "Continue" or "Next", never "Allow", and no Cancel or Close.
- Prefer passkeys; don't invent authentication schemes; store secrets in the Keychain.
- macOS: sign with Developer ID; consider the sandbox; don't assume who is signed in.

**Icons, SF Symbols, App icons** [HIG: icons], [HIG: sf-symbols], [HIG: app-icons]
- Menu bar extra icon: template image (black and clear) so the system can tint it; menu bar is 24 pt tall [HIG: the-menu-bar].
- No replicas of Apple hardware in icons or imagery; use Apple Design Resources if hardware must appear.
- App icons are now layered Liquid Glass icons built in Icon Composer, with default, dark, clear and tinted appearances; no text in the icon; let the system add effects.
- SF Symbols license prohibits use in app icons and logos. On the web, SF Symbol images appear not to be licensed for use at all (forum answers; see Sources) [unverified against the current license text]. Use a licensed web icon set in A and C; use SF Symbols freely in B.

**Branding** [HIG: branding]
- Branding defers to content; don't repeat the logo everywhere; express brand with familiar components; accent color only on primary actions and status.

### 2.2 Patterns

**Onboarding and launching** [HIG: onboarding], [HIG: launching]
- Fast, optional, interactive; prefer context tips over a tour. Postpone nonessential setup. Integrate a required permission into onboarding only if the app cannot work without it. Restore previous state on relaunch. No alert at launch [HIG: alerts].

**Managing accounts** [HIG: managing-accounts]
- Ask for an account only if core function needs it (it does: private content). Explain why, in the sign-in view. Delay sign-in.
- Prefer passkeys. **Name the method** ("Sign In with Passkey", not "Sign In"). Only reference methods the device has (don't say Touch ID on a Mac without it). Don't call it a "passcode".
- If you create accounts you must let people delete them; tell them when deletion completes.

**Loading, progress, feedback** [HIG: loading], [HIG: progress-indicators], [HIG: feedback]
- Show something immediately (placeholders). Use determinate progress when duration is knowable; keep it moving; even out the pace (no 90% in 5 s then 10% in 5 min).
- Describe the step specifically; avoid "Loading" or "Processing". Generative AI page adds: say "Finding substitutions for ingredients", not "Processing…" [HIG: generative-ai].
- macOS: spinner for background operations; don't label spinners.
- Let people cancel or pause long work; warn if cancelling loses progress.
- Status belongs next to the thing it describes. Confirm completion only when the action is significant.

**Notifications and managing notifications** [HIG: notifications], [HIG: managing-notifications]
- Concise, informative. No repeats for the same thing even if unanswered. Don't tell people to do tasks in the app; offer actions instead. **Use an alert, not a notification, for an error message** (see conflict 6.4). Handle foreground gracefully (update inline instead of notifying). No sensitive or personal information.
- Title: short, useful, title-style capitalization, no ending punctuation. If the only title you have is generic ("New Document"), omit it and let the system show the app name.
- Body: complete sentences, sentence case, punctuation; don't truncate yourself.
- Provide a generic hidden-preview placeholder ("New comment", "Reminder") for people who hide previews.
- Don't include the app name or icon in content; the system shows a large app icon.
- Sound: optional, short, distinctive; never the only signal.
- Actions: up to four; short title-case verb phrases; no action that merely opens the app; prefer nondestructive; give each an SF Symbol icon.
- Badges: only for unread notification counts; keep current.
- Interruption levels: Passive (view at leisure), Active (default), Time Sensitive (now or within the hour; breaks Focus), Critical (entitlement, health and safety). Be honest about urgency. Never send marketing as Time Sensitive.

**File management, drag and drop** [HIG: file-management], [HIG: drag-and-drop]
- Prefer the system Open panel; add an "Add (+)" path in addition to menus.
- Support drag and drop everywhere sensible, with an alternative (menu or button). Highlight a destination only while hovering over it and only if it accepts the item. Show progress for long transfers; show a placeholder where the item will land.
- macOS: consider letting people drag finished content into Finder.
- Finder Sync extensions can badge files with sync status in Finder (HIG lists badges, context menu items, toolbar buttons).

**Searching** [HIG: searching], [HIG: search-fields]
- One clearly identified place to search; show scope; suggestions and recent searches; scope bars and tokens for filters; start searching as people type.

**Settings** [HIG: settings]
- Good defaults; minimize settings; Command-Comma opens them; don't duplicate system settings (appearance, notification style). macOS Settings window: toolbar of panes, title reflects pane, minimize and zoom dimmed, restore last pane.

**Undo, modality, sheets, alerts** [HIG: undo-and-redo], [HIG: modality], [HIG: sheets], [HIG: alerts]
- Undo for everything reasonable, label what will be undone.
- Modal only with clear benefit; one sheet at a time; Done always paired with Cancel.
- Alerts sparingly, never purely informational, never at app start. Title says what happened; buttons are specific verbs ("Publish", not "OK"); "Cancel" always cancels; destructive style only when the destruction wasn't the person's intent.

**Collaboration and sharing** [HIG: collaboration-and-sharing]
- Summarize permissions in a short phrase ("Only invited people can edit"). Make it obvious content is shared and with whom.

**Playing audio and video** [HIG: playing-audio], [HIG: playing-video]
- Use the system player; custom players must mirror it. Original aspect ratio, no baked-in letterboxing (relevant to the vertical shorts). Space toggles play and pause. Respect system volume.

**Offering help** [HIG: offering-help]
- Tips: one or two sentences, for features of three steps or fewer, at a reasonable cadence. macOS tooltips: 60 to 75 characters, start with a verb, sentence case.

### 2.3 Components

- **The menu bar / menu bar extras** [HIG: the-menu-bar]: symbol icon; **show a menu, not a popover**, unless the content is too complex for a menu; let people decide whether it shows (offer during setup); don't rely on it; expose the same functions elsewhere too.
- **Menus** [HIG: menus]: verb labels, title-style caps, no articles, ellipsis when more input follows, dim (don't hide) unavailable items in menu bar menus, changeable labels for toggles ("Pause Watching" / "Resume Watching"), icons all-or-none per group, one submenu level.
- **Context menus** [HIG: context-menus]: hide unavailable items; no shortcuts shown; about three groups max.
- **Sidebars** [HIG: sidebars]: two levels max; hideable; don't hide by default; nothing critical at the bottom. Compact widths: a tab bar first.
- **Split views** [HIG: split-views]: highlight the current selection in each pane; thin divider.
- **Lists and tables** [HIG: lists-and-tables]: text in lists; sortable columns on Mac; middle truncation for long names keeps start and end readable (recording names share prefixes like `2026-09-06 18-06-33`).
- **Collections** [HIG: collections]: for thumbnails; standard grid.
- **Toolbars** [HIG: toolbars]: few groups (max three), one prominent primary action on the trailing side, window titles under 15 characters, never the app name as a title.
- **Buttons** [HIG: buttons]: one or two prominent buttons per view; style, not size, marks the preferred choice; never give a destructive action the primary role; ellipsis when a button opens more input.
- **Segmented controls** [HIG: segmented-controls]: about five to seven segments max; text or icons, not both.
- **Tab views** [HIG: tab-views]: six tabs max; noun labels.
- **Toggles** [HIG: toggles]: on macOS, checkboxes for hierarchies of settings, switches for big on/off; never in toolbars.
- **Progress indicators** see 2.2.
- **Popovers** [HIG: popovers]: small, one at a time, never for warnings.
- **Windows** [HIG: windows]: no custom window chrome; call them "windows".
- **Activity views (share)** [HIG: activity-views]: use the Share button; and the line that matters: "don't notify them simply because the task completes."
- **Gauges** [HIG: gauges]: label the value and both endpoints if used for audio levels.

### 2.4 System experiences and technologies

- **Live Activities** [HIG: live-activities], [DOC: activitykit]: best for defined tasks under eight hours, update only on real change, end immediately. **On Mac they appear in the menu bar only as mirrored iPhone Live Activities** (clicking launches iPhone Mirroring). ActivityKit is iOS, iPadOS and Mac Catalyst only, not native macOS. A native Mac agent cannot start one. Only relevant if Prakriti later gets an iPhone app.
- **Widgets** [HIG: widgets]: supported on the Mac desktop and Notification Center. Dynamic content, deep links, 11 pt minimum text, 16 pt margins. Candidate later: "Waiting for review: 2".
- **App Shortcuts** [HIG: app-shortcuts]: *not supported on macOS*, but App Intents actions are, so people can build Shortcuts on Mac with Prakriti's actions.
- **Controls** [HIG: controls]: Control Center controls exist on macOS; a Pause/Resume Watching control is possible but low value.
- **Snippets** [HIG: snippets]: result views for Siri or Shortcuts, 400 pt max height. Only if App Intents are built.
- **Siri** [HIG: siri]: low priority; no app name in responses; no ads.
- **iCloud** [HIG: icloud]: respect people's iCloud storage, don't store regenerable content there; handle iCloud being unavailable quietly; show subtle feedback while large files download. Directly relevant: the watched folder is an iCloud shared folder owned by Ivan (BRIEF.md), and one hour of studio video is about 2.4 to 3.2 GB (section 9).
- **Generative AI** [HIG: generative-ai]: keep people in control (dismiss, revert, retry); clearly identify where AI is used; never pass AI content off as human-authored; set expectations and state limitations; warn about hallucinations and avoid AI for facts it can't verify; ask before irreversible actions; offer alternate versions; specific progress copy; let people give feedback; design so the model can be swapped.
- **Machine learning** [HIG: machine-learning]: translate confidence into concepts; factual, non-emotional attributions ("Because you've read nonfiction", not "Because you love nonfiction"); guided corrections beat freeform ones; persist corrections; withhold low-confidence proactive results; list the most likely option first; offer diverse options.
- **Sign in with Apple** [HIG: sign-in-with-apple]: if offered, it must be no smaller than other sign-in buttons and visible without scrolling; titles only "Sign in with Apple", "Sign up with Apple", "Continue with Apple"; minimum 140x30 pt; black or white only. "Indicate when people are currently signed in" ("Using Sign in with Apple").
- **Foundation Models** [DOC: foundationmodels]: macOS 26+, on-device and Private Cloud Compute models, and (new for 2026) a way to bring other LLM providers into the same framework. Needs an Apple Intelligence device. Candidate for small private text jobs on the studio Mac (episode titles, tags) so transcripts don't leave the Mac [rec; capability vs Claude untested].

### 2.5 macOS platform specifics

- Large displays: more content, fewer nested levels, less modality; resizable windows; full keyboard support; menu bar holds every command [HIG: designing-for-macos].
- Every toolbar item must also exist as a menu command [HIG: toolbars].
- Agent app without a Dock icon: set `LSUIElement` [DOC: bundleresources/information-property-list/lsuielement]. Consequence: no Dock menu, so the HIG advice to offer menu bar functions via a Dock menu doesn't apply; the web app and Shortcuts become the "elsewhere" [rec].
- Launch at login: `SMAppService` (macOS 13+). A LoginItem helper restarts automatically if it crashes; status `requiresApproval` means the person must approve it in System Settings [DOC: servicemanagement/smappservice/register()].
- Folder access: picking a folder in an Open panel or dragging it onto the app grants implied consent with no Documents-folder prompt; touching `~/Documents` without that consent triggers a system prompt that uses `NSDocumentsFolderUsageDescription`. `NSNetworkVolumesUsageDescription` covers network volumes (the studio RAID, if it is networked) [DOC: bundleresources/information-property-list/nsdocumentsfolderusagedescription], [DOC: .../nsnetworkvolumesusagedescription].

---

## 3. Checklist A: the public features page that is also the login page

URL: `prakriti.therowan.studio` (signed-out state). Readers: Gabriel and Serenity first, Ivan second.

**Best references (use these, not the HIG, for web layout):**
- **iCloud.com signed out** (observed 2026-10-08): product name as the hero, one sentence ("The best place for all your photos, files, notes, mail, and more."), a single white "Sign In" pill, a short paragraph on what it does, a second short paragraph on privacy features. Clicking Sign In swaps the page for a centered card titled "Sign in with Apple Account". Nothing else competes.
- **account.apple.com/sign-in** (observed): one field "Email or Phone Number"; a short data-use paragraph with an icon and the link "See how your data is managed…"; two side-by-side buttons, "Continue" (disabled until the field is valid) and "Sign in with Passkey"; a one-line requirement note under the passkey button ("Requires a device with iOS 17 or later."). Local nav: Sign In, Create Your Apple Account, FAQ.
- **apple.com product pages** (Final Cut Pro, fetched): sticky local nav with the product name left and one call to action right; a hero; a tabbed "Get to know" gallery of features; feature sections with short headline, one to three sentences, real screenshots; an FAQ accordion; footnotes. **Borrow the structure, not the voice**: Apple's headlines pun and sell ("Reel intelligence.", "Scene smarts.") which breaks Ivan's describe-never-sell rule (memory `agency-copy-voice`).
- **Up Next** (`~/Code/up-next/public/login.html`), Ivan's own precedent: one card, product line, "Continue with Google", then passkey step-up, recovery codes, "Invitation only.", privacy link. Reuse the mechanics. Two copy fixes if reused: it uses em dashes (not allowed for Gabriel and Serenity) and says "your Mac's Touch ID", which the HIG says not to say on devices that don't have it [HIG: managing-accounts].

**Checklist (each item is testable):**

Structure
- [ ] A1. Persistent top bar: "Prakriti" at leading edge, one "Sign In" button at trailing edge, visible at every scroll position (iCloud.com, apple.com local nav). Wording "Sign In", never "Log In" (Apple Style Guide lists *sign in* (v.) and *sign-in* (n., adj.) [support.apple.com applestyleguide revision history, see Sources]).
- [ ] A2. Hero: name plus one plain sentence of what it does. Draft: "Recordings go in. Podcast episodes, edited video, thumbnails and transcripts come out, and nothing is posted until one of you approves it." (Describes; the promise is true by design, see finding 5.)
- [ ] A3. "How it works" in four steps that match the real system: Record (OBS saves to the shared folder) / Prakriti notices it / A package is prepared / You review and approve. One sentence each.
- [ ] A4. "What you get from each recording": the outputs, each with its honest status (HIG Generative AI: set expectations, state limitations). At launch only podcast audio is on (agreed sequencing, BRIEF.md); show the others as "Next", not as live features.
- [ ] A5. "What you'll be asked to do": approve or adjust; answer the occasional question (who is speaking, can this class be public). Prevents surprise.
- [ ] A6. "Notifications": show a real rendered notification (screenshot of the actual agent, not a drawing) and explain how to get them on your own Mac or iPhone: open the site in Safari, File > Add to Dock (Mac) or Add to Home Screen (iPhone), then allow notifications from inside the web app ([Apple Support 104996](https://support.apple.com/en-us/104996): respond to the request in the web app, not in Safari).
- [ ] A7. "Privacy": what runs on the studio Mac, what is sent to which service (name them), what is stored and where, that student voices are excluded from public output until Serenity's rule is set, and that no AI voice of Serenity exists without her consent (BRIEF.md). HIG: be transparent about server processing and training [HIG: generative-ai], [HIG: privacy].
- [ ] A8. "Invitation only. For Gabriel, Serenity and Ivan." No sign-up path, no "Create account" link (accounts are invited) [rec].
- [ ] A9. Short FAQ (accordion, apple.com pattern) for: Where do files live? What if it gets something wrong? Can something be posted by accident? How do I stop it?
- [ ] A10. Footer: "How your data is handled" link (Up Next precedent), copyright, nothing else.

Sign-in
- [ ] A11. Sign In opens a focused card in place (iCloud.com pattern), not a separate busy page. Card title names the method.
- [ ] A12. Passkey is primary, labeled with the method: "Sign In with Passkey" [HIG: managing-accounts]. Identity fallback as in Up Next (Google), plus recovery codes. Say "passkey", not "Touch ID", unless the device is known to have Touch ID.
- [ ] A13. One sentence in the card on why an account is needed (HIG: explain the benefit in the sign-in view): "Recordings and drafts are private to the three of you."
- [ ] A14. If Sign in with Apple is ever added: Apple's JS button, black on light or white on dark, at least 140x30 pt, no smaller than the other buttons, title "Continue with Apple" or "Sign in with Apple" [HIG: sign-in-with-apple].
- [ ] A15. Never prefill or ask for a password [HIG: entering-data]; never use the word "passcode" [HIG: managing-accounts].
- [ ] A16. Signed-in visitors to `/` go straight to where they left off [HIG: launching].
- [ ] A17. An account page shows how you're signed in ("Signed in with a passkey on this Mac") and has a real "Delete Account" path [HIG: managing-accounts], [HIG: sign-in-with-apple].

Visual and technical
- [ ] A18. System font stack; no SF font files served (license). Body 17 px, line-height 1.47, letter-spacing -0.022em; display sizes in the system display face; nothing below 12 px (memory `interface-type-scale`; brand pages may carry their own headline face per [HIG: branding] and Ivan's rule).
- [ ] A19. Colors as tokens with light and dark values; follows `prefers-color-scheme`; no visible appearance toggle [HIG: dark-mode]; contrast 4.5:1 body, 7:1 goal for small text.
- [ ] A20. Imagery is real product screenshots. No drawn Apple hardware [HIG: icons]. No film strips, reels, grain, scrub bars or decorative waveforms (Ivan: never skeuomorphic).
- [ ] A21. Motion only if it explains something; honors `prefers-reduced-motion`; any looping video is muted, has a visible pause control [HIG: accessibility].
- [ ] A22. No Liquid Glass imitation in content; at most a translucent blurred top bar [HIG: materials].
- [ ] A23. Copy: "you", never "we"; no jargon (no "pipeline", "diarization", "LLM", "ingest"); verbs on buttons; no exclamation marks; no em dashes [HIG: writing], BRIEF.md.
- [ ] A24. Works at 375 px with a 16 px gutter, no horizontal scroll; touch targets 44 px; logical heading order; every image has alt text or is marked decorative; visible focus ring; whole page usable by keyboard [HIG: accessibility], [HIG: voiceover].
- [ ] A25. `noindex, nofollow` and a robots policy, as Up Next does.
- [ ] A26. Verify by rendering at 375, 768 and 1440 px in light and dark and looking (BRIEF.md rule).

---

## 4. Checklist B: the native macOS menu bar agent

Purpose: watch folders, process without input, notify. It runs on whichever Mac holds the files
(studio Mac or Ivan's MacBook Pro; Ivan's travels, BRIEF.md).

### 4.1 Install, permissions, background running

- [ ] B1. Signed with Developer ID and notarized for distribution outside the Mac App Store [HIG: privacy]. Apple Developer Program membership required [unverified whether Ivan has one; open question].
- [ ] B2. First run shows one small setup window (not an alert, not a tour), three steps at most: Sign in (links the Mac to the web account) / Choose Folder… / Notifications. Each step one sentence [HIG: onboarding].
- [ ] B3. Folder chosen through the system Open panel ("Choose Folder…", with ellipsis). This grants implied access with no system prompt; store a security-scoped bookmark so access survives restarts [DOC: nsdocumentsfolderusagedescription]. Never scan `~/Documents` blindly.
- [ ] B4. Still ship purpose strings, one active sentence each: `NSDocumentsFolderUsageDescription`: "Prakriti reads new recordings in the folders you choose so it can prepare them for review." `NSNetworkVolumesUsageDescription`: "Prakriti reads new recordings on the studio drive so it can prepare them for review." [HIG: privacy].
- [ ] B5. Ask for notification permission **right after the first folder is chosen**, in context, not at first launch [DOC: usernotifications/asking-permission-to-use-notifications]. If a short explainer precedes the system prompt, it has one button, "Continue", and no Cancel [HIG: privacy]. Request `.alert`, `.sound`, `.badge`.
- [ ] B6. Don't use provisional authorization for the operator Mac: provisional notifications are delivered quietly to Notification Center only [DOC: asking-permission...], which defeats Ivan's ask [rec].
- [ ] B7. The watcher runs as a login item or LaunchAgent registered with `SMAppService`, separate from the menu bar UI, so hiding or removing the icon never stops watching [DOC: swiftui/menubarextra], [DOC: servicemanagement/smappservice]. If status is `requiresApproval`, show one sentence and a button that opens System Settings at Login Items [HIG: writing: link directly to settings].
- [ ] B8. Setup offers "Show Prakriti in the menu bar" (on by default), repeated in Settings [HIG: the-menu-bar]. If the icon is hidden (by this setting or by macOS 26 "Allow in the Menu Bar"), opening the app from Finder or Spotlight opens the Settings window [rec].
- [ ] B9. `LSUIElement` = true: no Dock icon [DOC: lsuielement].
- [ ] B10. No alert at launch, ever. Problems show in the menu's status line [HIG: alerts].

### 4.2 Menu bar extra

- [ ] B11. Template icon (black and clear), drawn as a custom symbol consistent with SF Symbols weight; 24 pt bar [HIG: the-menu-bar], [HIG: sf-symbols]. Abstract mark, not a camera, reel or microphone (Ivan: never skeuomorphic).
- [ ] B12. States, each distinguishable by shape not only color [HIG: accessibility]: Idle (plain); Working (animated with an SF Symbols effect such as Breathe or Variable Color; static under Reduce Motion; stops the moment work stops) [HIG: sf-symbols], [HIG: motion]; Waiting for you (a filled variant; do not draw a fake red badge, HIG says don't mimic badges [HIG: notifications]); Problem (variant with exclamation, used sparingly [HIG: alerts]); Paused.
- [ ] B13. Click shows a **menu, not a popover** [HIG: the-menu-bar]. Proposed contents, most important first [HIG: menus]:
  1. Status line (disabled text item). Examples: "Watching Studio Recordings. Nothing waiting." / "Working on Wed 23 Sep, about 25 min left" / "Paused" / "Waiting for iCloud to finish downloading 1 recording".
  2. Optional determinate progress row for the current recording, with the current step named ("Separating voices", "Writing transcript", "Choosing thumbnails"), never "Processing…" [HIG: progress-indicators], [HIG: generative-ai].
  3. "Ready for Review" submenu with each waiting recording (opens its page in the web app).
  4. Separator. "Open Prakriti" (the web library). "Add Recording…" (Open panel; the manual path Gabriel described on the call).
  5. Separator. "Pause Watching" / "Resume Watching" (one item, changeable label) [HIG: menus].
  6. Separator. "Settings…" (Command-Comma). "Quit Prakriti".
- [ ] B14. Labels: title-style capitalization, verbs first, no articles, ellipsis only where more input follows, icons for all items in a group or none [HIG: menus].
- [ ] B15. Quitting mid-recording: if work would be lost, an alert titled with the situation ("Quit While a Recording Is Processing?"), buttons "Quit" and "Cancel"; better, make quitting safe and resumable so no alert is needed [HIG: progress-indicators], [HIG: alerts].

### 4.3 Settings window

- [ ] B16. Opens with Command-Comma from the menu; toolbar panes **General, Folders, Notifications, Account**; window title follows the pane; minimize and zoom dimmed; reopens to last pane [HIG: settings].
- [ ] B17. General: Launch at login (checkbox), Show in menu bar (checkbox).
- [ ] B18. Folders: list of watched folders with path shown (path control), "+" and "−" buttons; per folder a pop-up "Treat as: Studio recordings / Archive" (archive work is summarized, never notified per item) [rec].
- [ ] B19. Notifications: checkboxes per event (section 4.4) with Ivan's three on; button "Open Notification Settings…" for banner style and sound, which macOS owns (don't duplicate system settings [HIG: settings]; the person chooses banners versus persistent alerts [DOC: usernotifications/unalertstyle]).
- [ ] B20. Account: "Signed in as ... with a passkey", Sign Out.
- [ ] B21. Text: macOS system controls render at 13 pt and cannot be enlarged in menus. In Settings use Body or larger; never the 10 pt Footnote or Caption styles, to honor Ivan's 12 px floor [HIG: typography], memory `interface-type-scale`.

### 4.4 Notification specification

**Who gets what** [rec]
- The Mac running the agent posts native notifications (UserNotifications). That Mac's person gets the operational events.
- Gabriel, Serenity and Ivan get **Web Push** from the web app for decision events (Ready for Review, Needs a Decision, Couldn't Finish, Archive summary), so it works on any of their Macs or iPhones. Per-person choices live in the web app's Settings.
- Don't send the same event twice to the same Mac (agent plus Web Push). Simplest rule: Web Push carries decision events; native carries operational ones plus decision events only when that Mac's person has turned Web Push off.

**One recording = one thread = one row in Notification Center**
- `threadIdentifier` = the recording session, e.g. `rec-2026-09-23-19-59-52` [DOC: unmutablenotificationcontent/threadidentifier].
- A *session* is every file sharing the timestamp: the landscape `.mp4`, the `-vertical.mp4`, and the `.txt` (2026-09-06 has both orientations, section 9). One notification per session, never per file [rec].
- Detected, Started and Ready reuse **one request identifier** (`rec-<session>-status`). Apple: a matching identifier replaces the delivered notification, alerts again, and moves it to the top [DOC: usernotifications/unnotificationrequest/init(identifier:content:trigger:)]. Needs a Decision and Couldn't Finish use their own identifiers in the same thread.
- When the person opens the recording in the web app, remove its delivered notifications (`removeDeliveredNotifications(withIdentifiers:)`) and update the badge [HIG: notifications: keep badges up to date].
- `targetContentIdentifier` = the recording's page, so a click opens the exact review page [DOC: unmutablenotificationcontent/targetcontentidentifier]; the HIG's rule is that clicking the notification itself opens related content, so no "Open" action is needed [HIG: notifications].

**When not to notify** [rec, grounded in HIG: notifications, HIG: feedback]
- Clips under 60 seconds: no notification (8 s, 10 s, 11 s tests exist). Listed in the menu as "Short clip, skipped" with a way to process anyway.
- Files still syncing from iCloud or still being written by OBS: wait until the size is stable and the file is fully downloaded; say so in the menu, not in a notification [HIG: icloud].
- Transient failures that an automatic retry fixes: never notify.
- While the web app is in front and focused on Prakriti: update in place, don't notify [HIG: notifications: foreground].
- Archive items: never individually. One summary a day.
- Never repeat an unanswered notification. Reminders only when the person chose "Remind Me".

**Interruption levels** [HIG: managing-notifications], [DOC: unnotificationinterruptionlevel] (macOS 12+)
- Detected: Active, no sound.
- Started: Passive (Notification Center only, no sound or screen wake [DOC: .../passive]); replaces Detected. Whether macOS shows a banner for a passive update is [unverified]; render and look.
- Ready for Review: Active, default sound.
- Needs a Decision: Active, default sound.
- Couldn't Finish: Active, default sound.
- Archive summary: Passive, or Active if anything needs review.
- **Never Time Sensitive.** Nothing here is happening within the hour, and it needs the `com.apple.developer.usernotifications.time-sensitive` entitlement anyway (third-party reports; Apple's macOS entitlement page not found) [unverified].

**Content rules (all events)**
- Title: title-style capitalization, no ending punctuation, short, specific. Put the recording's date in the title so the row is useful at a glance [HIG: notifications].
- Subtitle (supported on macOS): kind, people, length.
- Body: one or two complete sentences, sentence case, period at the end. What happened and what happens next.
- Never: the app name, "we", "Oops", "Error 1234", em dashes, emoji, exclamation marks, **student names, quotes from a class, or anything said in a session** (HIG: no sensitive information; Serenity's privacy condition, BRIEF.md). Gabriel's and Serenity's names are fine.
- Dates as "Wed 23 Sep" style, weekday computed by `date(1)`, never recalled (memory `compute-weekdays-never-recall`).
- Hidden-preview placeholder per category: "New recording", "Recording in progress", "Ready for review", "Needs a decision", "Recording needs attention", "Archive summary" [DOC: unnotificationcategory/hiddenpreviewsbodyplaceholder].
- Optional image: first thumbnail candidate as a JPEG attachment on Ready for Review (images up to 10 MB are supported) [DOC: unnotificationattachment]. How macOS renders it [unverified]; render and look.
- Actions: short title-case verb phrases with SF Symbol icons (macOS 12+ [DOC: unnotificationactionicon]); nondestructive; none that merely opens the app; most useful first. On macOS, actions sit behind hover and an Options control ([Apple: Get notifications on Mac](https://support.apple.com/guide/mac-help/mchle7f8a9b0/mac); AppleInsider on Big Sur), so the click itself must carry the main job.
- **No Approve or Publish action in any notification.** Approving unseen work defeats review, and publishing is irreversible [HIG: generative-ai], BRIEF.md safety rule.
- Sound: system default; a custom sound is allowed if short and distinctive [HIG: notifications]; not needed for v1.

**Copy, event by event** (examples use real folder dates; weekdays computed 2026-10-08)

1. **New raw material detected** (category `NEW_RECORDING`, Active, no sound)
   - Title: `Recording from Wed 23 Sep`
   - Subtitle: `1 hr 12 min, landscape and vertical`
   - Body: `Found in Studio Recordings. Work starts in a few minutes.`
   - Body if queued: `Found in Studio Recordings. Two recordings are ahead of it.`
   - Action: `Don't Process` (icon `nosign`). Reversible from the menu.
   - Placeholder: `New recording`
2. **Processing started** (same identifier, Passive)
   - Title: `Recording from Wed 23 Sep`
   - Body: `Started. Transcribing and separating voices first, then the podcast edit. About 40 minutes.`
   - Estimate must be honest and evened out [HIG: progress-indicators]; if unknown, omit the time rather than guess.
   - Placeholder: `Recording in progress`
3. **Processing complete, which is "Ready for Review"** (same identifier, Active, sound)
   - Title: `Ready for Review: Wed 23 Sep`
   - Subtitle: `Talk with Gabriel, 1 hr 12 min`
   - Body: `Podcast episode, transcript and 3 thumbnail options are ready. The first 4 minutes were setup and are trimmed.`
   - Body when an output is missing: `Podcast episode and transcript are ready. The intro and outro are missing because the voice service didn't respond; Try Again is on the review page.`
   - Actions: `Remind Me Tonight` (icon `moon`), `Copy Review Link` (icon `link`).
   - Click opens the review page. Placeholder: `Ready for review`
4. **Needs your review / a decision** (own identifier, same thread, Active, sound)
   - Class with students: Title `Needs a Decision: Sun 13 Sep`; Body `Voices other than Gabriel and Serenity are in this recording. Choose what happens to them before anything is shared.`; Action `Keep Private` (icon `lock`, reversible).
   - Unclear speakers: Title `Who's Speaking? Mon 14 Sep`; Body `Speakers couldn't be told apart for 6 minutes. Confirm them so each transcript files to the right person.`; no action (needs the page).
   - Placeholder: `Needs a decision`
5. **Failed** (own identifier, same thread, Active, sound; only after automatic retries, e.g. three over 30 minutes [rec])
   - Title: `Couldn't Finish: Wed 23 Sep`
   - Body: `The video file stops at 41 of 72 minutes. It may still be syncing from iCloud. The original is untouched.`
   - Action: `Try Again` (icon `arrow.clockwise`)
   - Placeholder: `Recording needs attention`
6. **Daily archive summary** (once a day at a chosen time, Passive unless something needs review)
   - Title: `Archive: 12 Recordings Processed`
   - Body: `3 are ready for review. 9 were kept as source material only.`
   - Placeholder: `Archive summary`

**Do not send (bad examples and why)**
- `Processing…` (vague, HIG progress and generative-ai pages).
- `Error 329347 occurred` or `Oops! Something went wrong` (HIG alerts and writing).
- `We're working on your video!` ("we", exclamation, no information).
- `Prakriti: Done` (app name, generic, and "done" alone isn't a reason to interrupt; HIG activity-views).
- `New class: Yin with Maria and Tom` (student names; HIG privacy; Serenity's condition).
- One banner per archive item, or any banner for an 8-second test.

**Volume check** [rec]: 12 studio recordings in about 4 weeks (section 9), so about 3 a week. With the scheme above that is about 3 banners a week from studio work plus one daily line from the archive. Without it, roughly 9 a week plus thousands from the archive.

### 4.5 Optional Mac integrations (later, in this order) [rec]

- App Intents actions for Shortcuts on Mac: "Add Recording to Prakriti", "Pause Watching", "Recordings Waiting for Review" [HIG: app-shortcuts].
- A small desktop widget: "Waiting for review: 2", deep-linking to Review [HIG: widgets].
- Finder badges on files in the watched folder (processed, working) via a Finder Sync extension [HIG: file-management]. Whether Finder Sync is still the recommended path on macOS 26 is [unverified].
- Focus filter so a "Teaching" Focus holds Prakriti's notifications (`filterCriteria`, macOS 13+) [DOC: unmutablenotificationcontent/filtercriteria].
- Not recommended: Live Activities (needs an iPhone app), Controls, Siri, a custom document type with Quick Look (use plain standard files instead).

---

## 5. Checklist C: the web app (review, approve, library)

Same origin as A, signed in. Desktop first (Macs), must work on iPhone.

### 5.1 Structure and navigation
- [ ] C1. Desktop: sidebar with at most two levels: **Review** (count), **Library**, **Published**, **People** (Gabriel's and Serenity's knowledge bases), **Settings**. Sidebar hideable, shown by default [HIG: sidebars].
- [ ] C2. Phone width: the same areas as a tab bar (five max) [HIG: sidebars: consider a tab bar first].
- [ ] C3. Library and Review as list plus detail (split view), selection highlighted [HIG: split-views], with middle truncation for long names [HIG: lists-and-tables].
- [ ] C4. One search for everything, top of the sidebar or trailing toolbar, starts as you type, with tokens for Speaker, Kind (Talk, Class, Conversation), Status, Date [HIG: searching], [HIG: search-fields]. Don't override the browser's Command-F [HIG: keyboards].
- [ ] C5. Window or tab titles name the place ("Review", "Wed 23 Sep"), never just "Prakriti" [HIG: toolbars]; under 15 characters where shown in a bar.
- [ ] C6. Restore the last view, filter and scroll position [HIG: launching].

### 5.2 The review page (one recording)
- [ ] C7. Header: date, kind, length, speakers (founders only), source folder, status. Status in words plus a shape, not color alone [HIG: accessibility].
- [ ] C8. One prominent primary action per view, at the top of the detail pane, never only at the bottom [HIG: buttons], [HIG: layout]. Label names the result: "Approve Podcast Episode", not "OK" or "Submit".
- [ ] C9. Each output is its own section with the same three controls: **Approve**, **Edit**, **Try Again**, plus Undo after any change [HIG: generative-ai: refine or revert; acknowledge corrections]. Switched-off outputs show "Not turned on yet" rather than empty boxes.
- [ ] C10. Players: native `<audio>` and `<video>` controls (Safari's system player), original aspect ratio (vertical shorts shown vertical, no baked-in bars), Space plays and pauses, nothing autoplays with sound [HIG: playing-video], [HIG: accessibility]. Transcript beside the player; clicking a line seeks.
- [ ] C11. Thumbnails: the three options side by side, most likely first, each with a one-line factual reason ("Close-up, eyes to camera"), choose one or keep all three for the YouTube test [HIG: machine-learning: multiple options].
- [ ] C12. **Quality, not a score**: three plain verdicts, each with factual reasons [HIG: machine-learning: confidence, attribution]:
  - `Ready to post`: "Clear voice, steady frame, one complete idea."
  - `Worth a look`: "Good message; room echo in the first 10 minutes."
  - `Source only`: "Mostly setup and logistics; kept for the knowledge base."
  Never "73/100" or "92% confidence". Separate lines for Audio, Video, Message, each with the same three words. If a number is kept internally for ranking, it stays internal.
- [ ] C13. Speakers: guided correction, not free text: "Is this Serenity?" Yes / No / Someone else; correction persists and re-files the transcript [HIG: machine-learning: corrections].
- [ ] C14. AI disclosure: any AI-generated voice segment is labeled "AI voice" in the editor and the published notes policy is decided (open question). AI-written titles and descriptions are marked "Suggested" until a person edits or approves them [HIG: generative-ai].
- [ ] C15. Known limitation stated where it bites: "Transcripts can mishear Sanskrit and names. Check them before approving." [HIG: generative-ai: limitations, hallucinations].
- [ ] C16. Privacy gate: recordings with voices other than Gabriel and Serenity open as **Private** with the reason, until Serenity's rule is set (BRIEF.md) [HIG: privacy].
- [ ] C17. Optional thumbs up/down on each generated output, voluntary, with consequences described ("Use fewer like this") [HIG: machine-learning: explicit feedback].

### 5.3 Publishing (the irreversible step)
- [ ] C18. Publishing is a separate, explicit act after approval. Confirmation alert names what and where: title "Publish to YouTube and RedCircle?", buttons "Publish" and "Cancel", Publish not styled destructive (it's the intended action) [HIG: alerts].
- [ ] C19. Scheduled publishing shows the exact time and an "Unschedule" path; published items show "Published by Serenity, Thu 8 Oct" [HIG: collaboration-and-sharing].
- [ ] C20. Undo approval until publish; after publish, a documented "Unpublish" path where the platform allows [HIG: undo-and-redo] [rec].

### 5.4 Status, progress, empty states
- [ ] C21. Processing status inline on each row with the step named and a determinate bar where duration is knowable [HIG: progress-indicators], [HIG: feedback].
- [ ] C22. Skeleton placeholders while loading; never a blank screen [HIG: loading].
- [ ] C23. Empty states with a next step: Review empty: "Nothing waiting. New studio recordings appear here a few minutes after they finish syncing." Button: "Add Recording…" [HIG: writing].
- [ ] C24. Errors next to the thing, in plain words, with the fix [HIG: writing]. No vanishing toasts for anything that matters [HIG: accessibility: time-boxed elements].

### 5.5 Adding material
- [ ] C25. Drop a video anywhere on Library to add it (Gabriel's drag-and-drop idea, transcript); the drop zone highlights only while a file is over it; multi-file drops; a placeholder row appears immediately with upload progress [HIG: drag-and-drop].
- [ ] C26. Equivalent "Add Recording…" button for people who don't drag [HIG: drag-and-drop: alternatives].
- [ ] C27. Large uploads continue in the background while people browse [HIG: loading].

### 5.6 Notifications and badges in the web app
- [ ] C28. Settings > Notifications: per person, per event checkboxes; explains Add to Dock / Add to Home Screen; the permission request is triggered only by a click on "Turn On Notifications" (Safari requires a user gesture; WWDC22 10098 per search result) [HIG: privacy: in context].
- [ ] C29. Web Push copy identical to section 4.4 so a notification reads the same on every device.
- [ ] C30. Dock or Home Screen badge = number of recordings waiting for *your* review; cleared as you open them [HIG: notifications: badging]. Badging API support in Safari web apps on macOS is [unverified]; Apple's support page confirms the unread badge for notifications.
- [ ] C31. No marketing or "tips" notifications, ever [HIG: managing-notifications].

### 5.7 Visual, input, accessibility
- [ ] C32. Same type, color and contrast rules as A18 to A19. Review stage may stay dark for media [HIG: dark-mode].
- [ ] C33. Standard keyboard behavior; a few custom shortcuts only for the most frequent actions (next and previous recording); **no single-key Approve or Publish** [HIG: keyboards] [rec].
- [ ] C34. Context menus on list rows with the row's relevant actions only, unavailable items hidden [HIG: context-menus].
- [ ] C35. Settings minimal: notifications, connected accounts (YouTube, RedCircle, ElevenLabs) with "Connected as ..." lines, outputs on or off, account [HIG: settings].
- [ ] C36. VoiceOver labels on every control and chart; headings structure each page; content changes announced [HIG: voiceover].
- [ ] C37. Verify by rendering every state (empty, processing, ready, decision, failed, published) at 375 and 1440 px, light and dark, and looking (BRIEF.md).

---

## 6. Where the HIG argues against what Ivan asked, and how to reconcile it

**6.1 Three notifications per recording (detected, started, complete).**
- Against: avoid multiple notifications for the same thing [HIG: notifications]; reserve completion confirmations for significant tasks because people only need to know when things fail [HIG: feedback]; "don't notify them simply because the task completes" [HIG: activity-views]; be honest about urgency [HIG: managing-notifications].
- Reconcile: keep all three moments, but as **one updating notification per recording** (shared identifier and thread), Started delivered Passive, and Complete reframed as **Ready for Review**, which asks for a decision and so earns the interruption. Per-event checkboxes in Settings let anyone turn moments off. Tests and archive items never notify individually.

**6.2 "Work autonomously without further input."**
- Against: keep people in control; ask before irreversible actions; avoid automating actions that are hard to undo [HIG: generative-ai]; Agency principle [HIG: design-principles]. Also BRIEF.md: nothing outward-facing without a human yes.
- Reconcile: autonomy ends at the draft. Intake, processing, scoring, drafting and queueing are automatic; publishing is a human click. This also matches Gabriel's own addition on the call: someone has to upload and someone has to post.

**6.3 A menu bar agent that is always present.**
- Against: let people decide whether the menu bar extra appears; don't rely on its presence [HIG: the-menu-bar]; macOS 26 lets people hide it system-wide (third-party reports); a menu-bar-only SwiftUI app is terminated if the extra is removed [DOC: swiftui/menubarextra].
- Reconcile: separate watcher process; icon optional; Settings reachable by relaunching the app.

**6.4 A notification when processing fails.**
- Against: use an alert, not a notification, for an error message [HIG: notifications].
- Reconcile: that guidance assumes the person is using the app. An unattended background agent cannot show an alert without stealing focus, and the HIG also says never show alerts at launch or for information [HIG: alerts]. So: a notification that names the problem in plain words with one recovery action (Try Again), and the full explanation inline on the review page. Send it only after automatic retries.

**6.5 "Insanely thorough", many features at once.**
- Against: include just what's necessary [HIG: design-principles]; minimize settings [HIG: settings]; keep focused.
- Reconcile: the agreed sequencing already solves it: build the engine once, switch outputs on one at a time, podcast audio first (BRIEF.md). The UI shows only switched-on outputs as live.

**6.6 A numeric quality score (Gabriel's "gives it a score").**
- Against: translate confidence into concepts; avoid percentages and statistical jargon unless the domain is statistical [HIG: machine-learning].
- Reconcile: three verdicts with factual reasons per dimension (C12). The number, if any, stays internal for ranking the 900.

**6.7 AI voice intros, outros and mid-roll (ElevenLabs).**
- Against: never let people think AI content is human-authored; clearly identify AI [HIG: generative-ai]; ask permission before using personal information.
- Reconcile: label AI voice in the app; decide the listener-facing disclosure (open question); require Gabriel's and Serenity's explicit consent per voice before any clone is used (Serenity has not consented, BRIEF.md).

**6.8 Build for the web vs a local app.**
- Not against, but the HIG asks each platform to be treated with intention [HIG: design-principles] and discourages rebuilding a browser in a web view [HIG: web-views]. So the Mac agent should be a genuine Mac citizen (real menu, real Settings window, login item, system notifications), and anything rich (review, library) belongs in the web app, opened in Safari or as a Dock web app, not embedded in the agent.

---

## 7. Ivan's standing rules versus Apple's guidance

| Ivan's rule (source) | Apple says | Resolution |
|---|---|---|
| SF Pro, 17 px body, nothing under 12 px for tools (memory `interface-type-scale`) | macOS default is 13 pt, min 10 pt; system menus can't be resized [HIG: typography] | Web (A, C): Ivan's scale, via system font stack. Native menus (B): system sizes, unavoidable. Native Settings window: Body or larger, never 10 pt Footnote/Caption. |
| SF Pro on web pages | SF fonts are licensed only for Apple-platform UI mock-ups; not for website content or embedding ([developer.apple.com/fonts](https://developer.apple.com/fonts/)) | `system-ui` / `-apple-system` stack (Up Next already does this). Never self-host SF font files. |
| Never skeuomorphic: no scrub bars, film strips, grain (memory `never-skeuomorphic`) | Use the system video player [HIG: playing-video] | The native player's scrubber is a functional control, not a drawing of a machine, so it is allowed. Ban only decorative ones (drawn timelines, fake waveforms, reels). Flag to Ivan to confirm. |
| Describe, never sell (memory `agency-copy-voice`) | apple.com product pages pun and sell ("Reel intelligence.") | Copy apple.com's structure, not its voice. HIG Writing agrees with Ivan: clear, concise, no cleverness on labels [HIG: writing]. |
| No em dashes for Gabriel and Serenity (BRIEF.md) | HIG text itself uses them | Strip from all copy; notification examples above contain none. |
| Artifact pages carry a light/dark toggle (artifact contract) | Avoid an app-specific appearance setting [HIG: dark-mode] | Prakriti's own pages follow the system with no visible toggle. |
| "Watch folders and work autonomously" | Keep people in control [HIG: generative-ai] | Section 6.2. |

---

## 8. Apple technologies: fit for Prakriti (HIG-relevant view)

| Technology | Availability | Fit | Source |
|---|---|---|---|
| User Notifications (local) | macOS 10.14+; interruption levels and action icons macOS 12+; Focus filter criteria macOS 13+ | **Yes**, core of B | [DOC: usernotifications/...] |
| `MenuBarExtra` + `LSUIElement` | macOS 13+ | **Yes**, B's UI | [DOC: swiftui/menubarextra] |
| `SMAppService` login item / LaunchAgent | macOS 13+ | **Yes**, the watcher | [DOC: servicemanagement/smappservice] |
| Open panel + security-scoped access | macOS | **Yes**, folder consent | [DOC: nsdocumentsfolderusagedescription] |
| Web Push via Safari web app (Add to Dock / Home Screen) | Web Push in Safari since macOS Ventura; Add to Dock macOS Sonoma 14+ | **Yes**, notifications for Gabriel and Serenity | [Apple Support 104996](https://support.apple.com/en-us/104996) |
| App Intents (Shortcuts on Mac) | macOS; App Shortcuts themselves not on macOS | Later | [HIG: app-shortcuts] |
| WidgetKit desktop widget | macOS | Later | [HIG: widgets] |
| Foundation Models (on-device / PCC / other providers) | macOS 26+, Apple Intelligence devices | Maybe, for private small text tasks | [DOC: foundationmodels] |
| Live Activities (ActivityKit) | iOS, iPadOS, Mac Catalyst; shown in Mac menu bar only when mirrored from iPhone | **No** without an iPhone app | [DOC: activitykit], [HIG: live-activities] |
| Controls (Control Center) | macOS | Low value | [HIG: controls] |
| Sign in with Apple (web) | Web supported | Optional; passkeys plus Google already proven in Up Next | [HIG: sign-in-with-apple] |
| Finder Sync badges | macOS | Nice to have; current status [unverified] | [HIG: file-management] |
| iCloud Drive shared folder | Existing | Input only; don't write GB-scale outputs back into it | [HIG: icloud] |

---

## 9. Grounding facts from the studio folder (read 2026-10-08, metadata only)

Folder: `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /`
(trailing space). 9 dated subfolders, 12 `.mp4` files, names are OBS timestamps such as
`2026-09-23 19-59-52.mp4`.

| File | Size | Length | Frame |
|---|---|---|---|
| 2026-09-06 17-43-25 (+ `-vertical`) | 112 MB (+111) | 2 min 33 s | 1920x1080 (+1080x1920) |
| 2026-09-06 18-06-33 (+ `-vertical`) | 2,458 MB (+2,445) | 55 min 39 s | 1920x1080 (+1080x1920) |
| 2026-09-13 18-25-44 | 696 MB | 15 min 47 s | 1920x1080 |
| 2026-09-14 20-00-09 (no `.txt`) | 2,726 MB | 61 min 42 s | 1920x1080 |
| 2026-09-16 20-03-49 | 2,927 MB | 66 min 15 s | 1920x1080 |
| 2026-09-17 06-02-43 | 8 MB | 11 s | 1920x1080 |
| 2026-09-20 18-07-58 | 2,432 MB | 55 min 3 s | 1920x1080 |
| 2026-09-23 19-59-52 | 3,163 MB | 71 min 35 s | 1920x1080 |
| 2026-09-26 10-29-54 | 5 MB | 8 s | 1920x1080 |
| 2026-10-02 15-10-06 | 7 MB | 10 s | 1920x1080 |

What this means for the HIG work:
- Sessions can have **two video files** (landscape and vertical) plus a transcript: group by timestamp, one notification per session.
- **3 of 10 sessions are tests under 15 seconds**: they must not notify.
- One hour is about 2.4 to 3.2 GB: progress must be determinate and honest; iCloud download state matters; never write outputs back into the shared iCloud folder [HIG: icloud].
- One session (2026-09-14) has no transcript file: don't assume the `.txt` arrives; don't wait on it to notify.
- Filenames carry no title or speaker: the Detected notification can only say date and length; kind and speakers appear from Ready for Review onward.
- Weekdays (computed with `date`): Sun 6 Sep, Sun 13 Sep, Mon 14 Sep, Wed 16 Sep, Sun 20 Sep, Wed 23 Sep, Fri 2 Oct. The 25-piece target date, Fri 6 Nov 2026 (BRIEF.md), is a Friday.

---

## 10. Open questions for Ivan (raised by this pass)

1. Which Mac runs the agent day to day: the studio Mac (details unknown, BRIEF.md) or Ivan's travelling MacBook Pro? Notifications on "the agent Mac" only reach that Mac.
2. Does Ivan have an Apple Developer Program membership? Needed for Developer ID signing and notarization of the agent, and for Sign in with Apple if ever used.
3. Do Gabriel and Serenity want push notifications at all, and for which events? Default proposal: Ready for Review and Needs a Decision only.
4. Listener-facing AI disclosure for ElevenLabs intros and outros: say it in the episode notes, in the audio, or both? Requires Gabriel's and Serenity's consent first.
5. Ivan's "never skeuomorphic" list includes scrub bars. Confirm that the native video player's functional scrubber is acceptable.
6. The features page is public (noindex). May it show a real processed example, and if so which one (no student voices)? Otherwise use neutral illustrative content.
7. Notification threshold for tests: 60 seconds proposed. Is there any meaningful content under a minute (shorts recorded natively)?
8. Daily archive summary time: suggest early evening, after teaching hours; confirm.

---

## Sources

HIG pages (all fetched 2026-10-08, `https://developer.apple.com/design/human-interface-guidelines/<slug>`):
design-principles, designing-for-macos, accessibility, branding, color, dark-mode, icons, images,
inclusion, layout, materials, motion, privacy, sf-symbols, typography, writing, app-icons,
charting-data, collaboration-and-sharing, drag-and-drop, entering-data, feedback, file-management,
launching, loading, managing-accounts, managing-notifications, modality, offering-help, onboarding,
playing-audio, playing-video, searching, settings, undo-and-redo, the-menu-bar, alerts, sheets,
sidebars, tab-views, lists-and-tables, progress-indicators, buttons, segmented-controls, toolbars,
windows, popovers, panels, menus, context-menus, collections, split-views, search-fields,
text-fields, toggles, notifications, live-activities, widgets, app-shortcuts, controls, snippets,
dock-menus, rating-indicators, gauges, labels, image-views, activity-views, token-fields,
path-controls, pickers, charts, web-views, sign-in-with-apple, icloud, siri, generative-ai,
machine-learning, mac-catalyst, voiceover, keyboards, pointing-devices.

Apple developer documentation (fetched 2026-10-08, `https://developer.apple.com/documentation/<path>`):
- usernotifications/asking-permission-to-use-notifications
- usernotifications/unnotificationinterruptionlevel (and /passive, /timesensitive)
- usernotifications/unmutablenotificationcontent/threadidentifier, /relevancescore, /filtercriteria, /targetcontentidentifier
- usernotifications/unnotificationrequest and /init(identifier:content:trigger:)
- usernotifications/unnotificationactionicon, unnotificationattachment, unnotificationcategory/hiddenpreviewsbodyplaceholder
- usernotifications/unauthorizationoptions/provisional, unnotificationsettings/alertstyle, unalertstyle
- swiftui/menubarextra; bundleresources/information-property-list/lsuielement
- servicemanagement/smappservice, /register(), /status-swift.enum/requiresapproval
- bundleresources/information-property-list/nsdocumentsfolderusagedescription, nsnetworkvolumesusagedescription
- activitykit; foundationmodels; coreservices/file_system_events

Apple web surfaces observed: https://www.icloud.com/ (signed out, and its Sign In card);
https://account.apple.com/sign-in; https://www.apple.com/final-cut-pro/.

Other:
- Apple fonts license: https://developer.apple.com/fonts/
- SF fonts on the web, community answer: https://developer.apple.com/forums/thread/733267
- SF Symbols on websites, forum answer: https://developer.apple.com/forums/thread/837003 [license text itself not retrieved]
- Safari web apps on Mac: https://support.apple.com/en-us/104996
- Get notifications on Mac (hover, Options): https://support.apple.com/guide/mac-help/mchle7f8a9b0/mac
- Big Sur notification actions behind Options: https://appleinsider.com/articles/20/12/11/how-to-make-the-most-of-notifications-in-macos-big-sur
- Web Push in Safari on macOS Ventura, user gesture required: https://developer.apple.com/videos/play/wwdc2022/10098/ (via search result summary) [unverified directly]
- Time Sensitive entitlement key, third-party reports: https://developer.apple.com/forums/tags/wwdc21-10091 [unverified for macOS specifics]
- macOS 26 "Allow in the Menu Bar": https://eshop.macsales.com/blog/97824-macos-tahoe-makes-it-extremely-easy-to-clean-up-a-messy-menu-bar/ and https://forum.parallels.com/threads/asking-how-to-keep-toolbox-icon-on-menu-bar.369594/ [third-party]
- Apple Style Guide sign in / sign-in: https://support.apple.com/guide/applestyleguide/apdaf2bc3367/web (revision history listing) [entry text not retrieved]

Local files:
- ~/Code/prakriti/research/BRIEF.md; ~/Code/prakriti/research/2026-10-07-call-gabriel-transcript.txt
- ~/Code/up-next/public/login.html and font tokens in ~/Code/up-next/public/assets/
- ~/.claude/projects/-Users-ivanlizarde-Documents-Claude-Projects/memory/never-skeuomorphic.md, interface-type-scale.md, agency-copy-voice.md
- Studio folder metadata as in section 9.
