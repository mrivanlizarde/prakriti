# Prakriti for Mac v2: design spec (how Apple would build it)

Written Sat 10 Oct 2026, for Ivan and for whoever builds v2. A proposal: nothing here is built.
Read `docs/v2/REQUEST.md` first. Where this spec and REQUEST.md disagree, section 0.2 says so and
why; REQUEST.md's decisions stand until Ivan answers.

**Markers used below.** *Measured on this Mac* means a command was run on Ivan's M5 Pro, macOS 27.2,
on 10 Oct 2026. *[cited]* claims link to a source in "Sources" at the end. **[unverified]** means
it could not be confirmed today and must be checked before it is built on. **[proposal]** means a
design choice made here, not a fact.

**Scope.** This is the interface: windows, screens, states, words, type, color, symbols, motion,
keys, the welcome screen and the help system. How the edit is made (cuts, captions, motion
graphics), the FCPXML and Resolve formats, face and voice matching, and platform specs belong to
the other v2 tracks; this spec says what the interface needs from them (section 9.2) and never
decides their internals.

**This document is internal.** UI strings and help copy quoted in it are drafts and carry no em
dashes; the document follows the same rule so strings can be lifted as they are.

---

## 0. The short version

1. **One main window, built the way Photos and Final Cut Pro are built:** a Library sidebar on the
   left, a browser of recordings in the middle (a grid of real thumbnails, or a list), and an
   inspector on the right for whatever is selected. Opening a recording swaps the browser for the
   **Viewer** (Photos does exactly this); the inspector stays put. No more long scrolling pages.
2. **Sidebar:** Needs You, In Progress, Ready, All Recordings; People (the gallery, then each named
   person); Sources (each watched folder). **Activity, Outputs, Models and Settings leave the
   sidebar.** Activity becomes its own window, like Final Cut Pro's Background Tasks (Command-9);
   Outputs, Models and the rest become panes of a real Settings window (Command-comma).
3. **The Viewer plays everything inside the app:** the original, the edited video, each short, the
   podcast audio. It uses the system player (allowed under the never-skeuomorphic rule). Over the
   picture: a People toggle that boxes and labels faces, a Captions toggle, and a vertical-crop guide.
4. **Under the Viewer, a Timeline-lite and the transcript.** Kept time is a filled bar, removed time
   is an outlined bar with a symbol for why (pause, filler, retake, another person), a clip from
   another recording is a second color with its date. No film strips, no waveforms, no draggable
   scrubber: you click a bar or a word to go there.
5. **The inspector has five tabs:** Outputs (every deliverable, its checks, Open in Final Cut Pro or
   DaVinci Resolve), People (who appears; Include, Blur Face or Remove, per output), Direction (the
   editorial prompt, presets, pace, length, versions, moments from other recordings), Checks
   (capture quality, platform specs, accuracy, privacy lock) and Info.
6. **Progress everywhere it belongs:** a ring and percent on the thumbnail, the stage, percent, time
   left and the latest log line in the inspector and the Viewer, an app-wide Activity window, a
   progress button in the toolbar, and the status line in the menu bar.
7. **Merging from another recording is offered, never automatic:** Prakriti searches the other
   transcripts by meaning, shows up to three moments with their exact words and dates, and you add
   each one by hand. Clips from another day carry their date on screen by default (Serenity's
   accuracy condition).
8. **People gallery like Photos' People & Pets, for named people who have agreed only.** Unnamed
   people never get a face tile in the gallery; their faces show only inside the one recording they
   are in, drawn from the video on demand and never saved.
9. **A five-panel welcome window** at first launch and from Help: what Prakriti does, how to record
   for the best result, how outputs work, privacy, and three optional setup steps.
10. **Help is an in-app Help window** of short articles stored as Markdown in the app, searchable in
    the window and from the Help menu's own search field, with "Show Me" links that open the right
    place in the app. Apple's Help Book format is still supported but is not the better fit (5.6).
11. **Ivan's type rules stay** (17 pt body, nothing under 12 pt, no tooltips). Apple's structure,
    Ivan's scale. Logic Pro's Quick Help replaces tooltips: a panel that explains whatever the
    pointer is over, at 15 pt.
12. **One measured problem to fix now:** the dark-mode accent (#4459E8) is 3.05 to 1 on the dark
    window background, under the 4.5 to 1 text minimum. Text and links in dark mode need their own
    lighter accent (6.2).

### 0.1 Decisions in REQUEST.md this spec builds on, unchanged

Design for clean inputs (poor capture gets a check, a warning and a capture tip, section 3.5.4);
students are the privacy subject (Include, Blur, Remove per person, defaults Blur and Remove for the
unnamed, 3.5.2); face and voice prints only for named people who agreed (3.9); MKBHD's grammar, not
his brand (House Style pane, 3.13); "100% ready" means passing published specs with the human
pressing Upload (Ready group and the upload checklist, 3.11); two deliverables per video, the MP4
and the editable timeline (3.5.1); real-frame thumbnails for Gabriel and Serenity (3.1.2).

### 0.2 What this spec changes, refines or contradicts (Ivan decides)

| # | Where | What | Why | Recommendation |
|---|---|---|---|---|
| C1 | v1 status words | "Ready for your yes" collides with the new "Ready" group (finished and approved). | One word must mean one thing (HIG color and writing guidance; 04 research's single vocabulary). | Rename the v1 status to **"Waiting for your yes"**. "Ready" then only means "approved, passes every check, only Upload is left". |
| C2 | REQUEST.md, "the gallery shows them as 'Unnamed, this recording only'" | Refined: the gallery shows **one** tile, "Unnamed people", with no faces, that lists which recordings have unnamed people. Each unnamed face is shown only in its own recording's People tab, cropped from the video while the page is open and never written to disk. | A gallery grid of student face crops is a stored, browsable collection of student faces, the exact thing the biometric decision avoids, even if no print is kept. | Accept the refinement. |
| C3 | REQUEST.md, the cloud key "in case a user does not have a computer powerful enough" | A cloud key can take over the **language** work (choosing cuts from the transcript, captions polish, titles, notes). It cannot take over transcribing, finding faces or making the video, because no raw recording or removed audio is ever uploaded (START_HERE warning 18). A weak Mac with a key is still slow at rendering. | Honest UI: the Models pane and the welcome panel must say which work moves and which stays. | Keep the rule; say it plainly (copy in 3.13 and 4.2). |
| C4 | v1 copy, the privacy lock | v1's page and Models screen still say "Serenity is in this recording, so only models on this Mac may read it." REQUEST.md relaxed this: only classes, or recordings where other people appear or speak, are locked. | Stale truth on screen. | Change the lock line to name the real reason ("Other people appear in this recording, so only models on this Mac read it."). |
| C5 | v1 sidebar | Today, Outputs, Models, Activity and Settings are sidebar destinations in v1. v2 moves Today into Needs You, Activity into its own window, and Outputs, Models and Settings into the Settings window. | Apple's apps keep the sidebar for content and put preferences in Settings (HIG settings; every Apple app studied). | Accept. |
| C6 | Merged clips | Recommend a small on-screen date label ("13 Sep 2026") on any clip taken from another recording, on by default, switchable per clip. | Serenity's accuracy condition: anything public must be right, including the year. A clip from another day, unlabeled, implies it was said in this session. | Accept, or decide per house style. |
| C7 | v1 accent color | Measured: dark accent #4459E8 on #1E1E1E is 3.05 to 1. Light accent #2337C6 on white is 8.63 to 1 (fine). | HIG accessibility: 4.5 to 1 for text up to 17 pt. | Add a dark-mode text accent, #7D8BFF (5.56 to 1); keep #4459E8 for fills and the selected sidebar row (white on it is 5.47 to 1). |
| C8 | Approve with failing checks | "100% ready" means Approve is refused while any chosen deliverable fails a platform check; the sheet lets Ivan untick that deliverable instead. | A yes must cover a file that would pass on upload. | Accept. |

---

## 1. What Apple's apps do, and what Prakriti takes from each

Apple apps studied at their current versions. Versions of the apps installed on this Mac were read
from their Info.plist (measured): Final Cut Pro 12.4 (`com.apple.FinalCutApp`, sold now as "Final Cut
Pro Creator Studio"), Compressor 5.4, Pixelmator Pro 4.4, iMovie 10.4.5, Keynote 15.4, DaVinci
Resolve 20.2.1 (Blackmagic, for the export target). Final Cut Pro, Logic Pro, Pixelmator Pro, Motion,
Compressor and MainStage became the Apple Creator Studio subscription on 28 Jan 2026, with one-time
purchase still offered [cited: Creator Studio].

| App | What it does that matters here | What Prakriti takes | What Prakriti refuses |
|---|---|---|---|
| **Photos** (macOS 27) and **iPhoto** before it | iPhoto grouped a library into Events, and iPhoto '09 (6 Jan 2009) added Faces: it detects faces, you name one, it finds that person again and asks you to confirm [cited: Apple iLife '09, Macworld]. iPhoto ended 8 Apr 2015 when Photos replaced it [cited: Wikipedia]. Today's Photos: a sidebar of Library, Pinned and Collections; People & Pets with Name this Person, Review More Photos (Yes or No per suggestion), Merge People, Make Key Photo, Hide this Person, "This is Not [name]" [cited: Photos guide]. Double-clicking a photo replaces the grid with the photo; Info sits beside it. | The library model (one library, smart groups, never a folder tree); the People gallery and its exact verbs (Name This Person, Review Possible Matches, Change Key Photo, Not [Name]); the browse-then-open swap; pinned people in the sidebar. | Face naming that stores a print for anyone named. Prakriti stores one only for a person marked "has agreed". Photos' Memories and auto-made slideshows (decoration). |
| **Final Cut Pro 12.4** | Libraries sidebar, browser in filmstrip or list view with a Clip Appearance control, a Viewer, an inspector that changes with the selection (Video, Audio, Info, Share and more) opened with Command-4 [cited: FCP browser views, inspector]. The Background Tasks window (Command-9, or a toolbar button) shows importing, transcoding, analysis, rendering, sharing and backups with percent complete and Pause and Resume per task, and pauses itself while you edit [cited: FCP background tasks]. 12.0 added Transcript Search and Visual Search, and in-app guides plus a downloadable demo project; 12.3 added Generate Captions and Edit Detection; FCPXML is at 1.14 [cited: FCP release notes]. It opens `.fcpxml` and `.fcpxmld` (measured, its Info.plist). Its welcome and What's New are cards of title, one sentence, image, and a "Complete feature list" link (measured, its strings files). | The three-region layout, an inspector with icon tabs, the Background Tasks pattern for Activity (and its Command-9), "Open in Final Cut Pro" as a first-class button, search across what was said (for merging), What's New cards as the shape of the welcome panels. | The magnetic timeline, the filmstrip (a row of frames reads as a film strip, which Ivan's rule rules out), waveforms, the density of a pro tool at 11 to 13 pt. |
| **Compressor 5.4** | A batch has Current, Active and Completed views; Active shows progress bars with Pause, Resume and Cancel per batch, job or output; Completed shows what finished and what failed, with Show in Finder and Reuse [cited: Compressor guide]. | The Activity window's "Now" and "Finished" lists, per-job Pause and Stop, Show in Finder on a finished job, "Make Again with These Settings". | Presets as the user's main vocabulary; Prakriti speaks in outputs, not encoder settings. |
| **iMovie 10.4.5** | Apple's consumer editor; has a welcome screen and What's New (measured: `CEWelcomeScreenWindowController`, `CEWhatsNew` strings). Apple pointed Clips users to it [cited: Clips]. | Plain-language editing words; themes as a precedent for a house style. | Templates that copy a brand (Prakriti's style is its own). |
| **Clips** | **Discontinued**: not offered to new users since 10 Oct 2025 [cited: Clips]. Its live captions and quick-share were the model for "post ready". | Only the idea: captions designed in, not bolted on. | Nothing else; do not cite it as a live guide. |
| **Logic Pro 12** | Quick Help: an area at the top of the inspector, or a floating window, that describes whatever the pointer is over, with links to the full guide [cited: Logic Quick Help, an older guide version; **[unverified]** for Logic Pro 12]. | **Quick Help replaces tooltips.** Ivan's rule bans tooltips because macOS draws them at 11 pt (v1 measured); a Quick Help panel at 15 pt keeps the help and the rule. | Logic's density. |
| **Pixelmator Pro 4.4** | A What's New window of feature rows with a Continue button and "Complete feature list" (measured, `WhatsNew.strings`); registers a Help Book (measured). | The welcome window's structure: headline, short rows with symbols, one Continue. | |
| **Keynote 15.4** | First-launch welcome view and What's New window as separate pieces (measured: `TMAFirstLaunchWelcomeView.nib`, `TMAWhatsNewWindow.nib`). | First launch gets the welcome; later versions get a short What's New in the same window. | |
| **Apple's pro apps' privacy screen** | Final Cut Pro and Compressor ship an onboarding framework whose privacy panel is a title, a one-line summary, bullets, and "See how your data is managed..." (measured, `ProOnboardingFlow.framework` strings). | The privacy welcome panel's shape: title, one-line promise, three bullets, a link to the full Privacy help article. | Analytics. Prakriti collects none. |

**macOS 27 (Golden Gate) design language** [cited: MacRumors on WWDC 2026; HIG pages]:
- Liquid Glass is refined, not removed. Sidebars no longer float: they run edge to edge without the
  extra shadow, and sidebar icons are colored again (the HIG's sidebar page was updated 8 Jun 2026:
  icons use the app's accent color, and fixed colors are fine when used sparingly).
- Toolbars are uniform, so headings and control groups read clearly; windows share one corner
  radius; a System Settings slider lets people make glass clearer or more opaque.
- Glass is for the control layer only (toolbars, sidebars, controls over media). The clear variant
  is for controls that float over photos and video. Content uses standard materials
  [cited: HIG materials].
- Toolbars: at most three groups, one prominent primary action at the trailing edge, a window title
  under 15 characters and never the app's name [cited: HIG toolbars, updated 16 Dec 2025].
- App icons are layered (Icon Composer), with default, dark, clear and tinted appearances, 1024 px,
  no text [cited: HIG app icons, updated 8 Jun 2026].
- The menu bar is 24 pt tall; a menu bar extra is a template symbol and opens a menu, not a popover;
  the Help menu gets a search field automatically [cited: HIG the menu bar].
- Onboarding should be fast, optional and not shown again once skipped, but easy to find later
  [cited: HIG onboarding].

**Measured on this Mac: Help Viewer is now the Tips app.** `/System/Applications/Tips.app` has the
bundle identifier `com.apple.helpviewer`, version 27.2, and still opens "macOS Help Bundle" files;
`hiutil` is still at `/usr/bin/hiutil`. Apple's own apps register Help Books that open web content
(Final Cut Pro's Info.plist names `FinalCutPro10.help`, which is not in its bundle; Keynote's book is
named `...remote.help`). See 5.6.

---

## 2. Information architecture

### 2.1 The windows (SwiftUI scenes)

| Window | Opens with | What it is |
|---|---|---|
| **Main window** (`WindowGroup`, one instance; File, New Window is not offered) | Dock icon, menu bar "Open Prakriti" | Sidebar, browser or Viewer, inspector. Restores the last group, selection, open recording and inspector tab on relaunch (HIG launching). |
| **Activity** (`Window`, id `activity`) | Window menu, Command-9, the toolbar's activity button, the menu bar | Everything working, waiting and finished, app-wide, plus the log (3.6.3). |
| **Settings** (`Settings` scene) | Prakriti menu, Command-comma | Panes: General, Outputs, House Style, Models, Privacy, Advanced (3.13). |
| **Help** (`Window`, id `help`) | Help menu, Command-?, any "?" button, Help menu search results, welcome panel links | The help articles (section 5). |
| **Welcome** (`Window`, id `welcome`, `.defaultLaunchBehavior(.presented)` only on first launch, `.restorationBehavior(.disabled)`) | First launch, Help menu "Welcome to Prakriti" | Five panels (section 4). |
| **Quick Help** (`UtilityWindow`, id `quickhelp`) | Help menu "Show Quick Help" when the inspector is hidden | Floating Quick Help panel (5.5). With the inspector open, Quick Help sits at the top of the inspector instead (Logic's behavior). |
| **Menu bar extra** (`MenuBarExtra`, menu style) | Always, unless Ivan turns it off in Settings, General | Status line and a short menu (3.14). |

Sheets on the main window: Approve (3.11), Name This Person (3.9.4), Supporting Moments (3.8),
Forget Person (alert), Add Folder refusal (alert, as in v1).

### 2.2 The main window, region by region

```
+----------------------------------------------------------------------------------------------+
| [o o o]  [sidebar]  Needs You        [grid|list] [sort]   [(64%) Pause]   [search] [inspector] |  toolbar
+---------------+----------------------------------------------------------+-------------------+
| LIBRARY       |                                                          | [Out|Ppl|Dir|Chk|i]|
|  Needs You  3 |   Waiting for your yes                                   |  Outputs           |
|  In Progress 2|   +------------+  +------------+  +------------+         |                    |
|  Ready      1 |   | thumbnail  |  | thumbnail  |  | thumbnail  |         |  status, progress  |
|  All          |   +------------+  +------------+  +------------+         |  deliverables      |
| PEOPLE        |   Title             Title           Title                |  Open in FCP       |
|  People       |   Sun 13 Sep, 15:48                                       |                    |
|  Gabriel      |   (G) (S) +3 others                                      |                    |
|  Serenity     |                                                          |                    |
| SOURCES       |   Needs a decision                                       |                    |
|  Studio Rec.  |   ...                                                    |                    |
|  Drop folder  |                                                          |                    |
+---------------+----------------------------------------------------------+-------------------+
```

Opening a recording (double-click, Return, or Command-Down) replaces the browser column only:

```
+----------------------------------------------------------------------------------------------+
| [<]  Sun 13 Sep     [Original|Video|Shorts|Podcast]    [Make Again...] [Approve...]  [(o)] [i] |
+---------------+----------------------------------------------------------+-------------------+
| sidebar       |  +----------------------------------------------------+  | inspector,        |
| (unchanged)   |  |                                                    |  | same recording    |
|               |  |          system player, dark canvas                |  |                   |
|               |  |                     [People] [Captions] [9:16]     |  |                   |
|               |  +----------------------------------------------------+  |                   |
|               |  Timeline-lite  [####][  ][########][==][####]            |                   |
|               |  markers         +        T          +                   |                   |
|               |  -------------------------------------------------------  |                   |
|               |  Gabriel                                                  |                   |
|               |  4:10  So the breath comes first. ~~Um, so~~ the body...  |                   |
+---------------+----------------------------------------------------------+-------------------+
```

**Sizes [proposal]:** default window 1440 by 900 pt, minimum 1100 by 720 (v1 is 1180 by 760). Sidebar
220 pt (200 to 280). Inspector 360 pt (320 to 440, `inspectorColumnWidth`). At the default size the
middle column is 860 pt: a 16:9 picture about 836 by 470 above about 300 pt of Timeline-lite and
transcript. At the minimum size the sidebar collapses first (as Mail's does, HIG sidebars), then the
inspector, never the Viewer. The split between picture and transcript is draggable and remembered.

### 2.3 The sidebar

Two levels at most (HIG sidebars). Every row is 17 pt text with its symbol; counts are plain text at
15 pt semibold (v1's rule: no `.badge`, which draws under 12 pt).

| Section | Row | Symbol | Shows in the browser | Count |
|---|---|---|---|---|
| Library | **Needs You** | `exclamationmark.bubble` | Recordings waiting on Ivan, grouped by reason | yes |
| | **In Progress** | `progress.indicator` | Found, waiting their turn, or working | yes |
| | **Ready** | `checkmark.seal` | Approved, every check passed, only Upload left | yes |
| | **All Recordings** | `square.grid.2x2` | Everything, newest first, grouped by month | no |
| People | **People** | `person.2` | The gallery (3.9) | no |
| | each named person, e.g. Gabriel, Serenity | their key photo, 20 pt circle | Recordings they appear in | no |
| Sources | each watched folder, e.g. Studio Recordings, Drop Folder | `folder`, `tray.and.arrow.down` | That folder's recordings | no |
| | (section header +) **Add Folder...** | `plus` | | |

Named people are pinned in the sidebar automatically when named and agreed; Ivan can unpin
(context menu, Photos' Pin and Unpin). Sources and people can be reordered by dragging (HIG: let
people customize a sidebar). Nothing important sits at the bottom of the sidebar (HIG).

### 2.4 Statuses and smart groups

One status vocabulary everywhere: card, list, inspector, Activity, menu bar, notifications.
Membership in a group is a pure function of the stored status and checks, so each group is a SwiftData
predicate over raw strings (v1 warning 11).

| Status (UI words) | v1 status | Symbol | Group |
|---|---|---|---|
| Found | found | `plus.circle` | In Progress |
| Waiting | (new: queued behind another) | `hourglass` | In Progress |
| Working | working | `arrow.triangle.2.circlepath` with a determinate ring on cards | In Progress |
| **Waiting for your yes** | readyForYourYes (renamed, C1) | `checkmark.circle` | Needs You |
| Needs a decision | needsADecision | `questionmark.circle` | Needs You |
| Couldn't finish | couldntFinish | `exclamationmark.triangle` | Needs You |
| Approved, with a failing check | (new) | `checkmark.seal` plus `exclamationmark.triangle` | Needs You |
| **Ready** | approved and every chosen deliverable passes | `checkmark.seal` | Ready |
| Skipped (a test clip) | skipped | `minus.circle` | All Recordings only |

Status is never color alone: every status has its symbol and its words (HIG accessibility).

### 2.5 How you move around

- **Select** a recording (click, arrows): the inspector shows it. **Open** it (double-click, Return,
  Command-Down): the Viewer replaces the browser. **Back** (Escape, Command-Up, Command-[, the
  toolbar chevron): the browser returns with the same selection and scroll position.
- **Quick Look** (Space in the browser): a large preview of the edited video, or of the original if
  nothing is made yet, over the browser, the way Finder and Photos do it. Space again closes it.
- **Notifications** open the recording in the Viewer (v1 already routes a notice to its recording).
- **State restore**: group, selection, open recording, Viewer rendition, playhead time, inspector
  tab and the picture and transcript split are restored on relaunch.

---

## 3. Every screen and its states

### 3.1 The browser, grid view (default)

#### 3.1.1 Card anatomy

```
+--------------------------------------+
| [? Needs a decision]                  |  status capsule, top leading
|                                       |
|          real frame, 16:9             |
|                                       |
|   [Working 64%  (ring)]      [15:48]  |  progress capsule (only while working), length capsule
+--------------------------------------+
 Talk with Gabriel                        17 pt semibold, up to 2 lines
 Sun 13 Sep 2026, 6:25 pm                 15 pt secondary
 (G) (S)  [? 3 others]                    named people as 24 pt circles; others as a symbol chip
```

- **Size:** adaptive grid, cards 240 to 360 pt wide, 20 pt gaps (`LazyVGrid` with
  `.adaptive(minimum: 240, maximum: 360)`). A View menu control "Thumbnail Size" (small, medium,
  large) changes the minimum; no slider.
- **Capsules over the picture** use a standard material (`.regularMaterial`), not glass: they are
  content, and the HIG keeps glass out of the content layer. Text 13 pt semibold, symbol plus word.
- **People line:** named people who agreed show as their key photo; "3 others" uses
  `person.fill.questionmark` and the words; a recording where only voices were heard (no faces) shows
  `waveform` plus "2 other voices". Hidden when no one has been looked for yet.
- **Selection:** the system selection ring around the picture. **Focus** follows Full Keyboard
  Access.
- **Hover:** if an edited video exists, moving the pointer across the picture shows frames from the
  **edited** video (already blurred as decided), the way Final Cut Pro skims. Before an edit exists
  there is no skimming, so hovering never shows an undecided student's face. (Behavior, nothing
  drawn: allowed under the never-skeuomorphic rule.)
- **Context menu** (three groups at most, HIG): Open, Quick Look, Show Original in Finder, Show
  Outputs in Finder | Make Again..., Stop, Mark As (Talk, Class, Conversation) | Remove from Library...
  (forgets Prakriti's record and outputs after a confirmation; **never** touches the original file).

#### 3.1.2 Which frame becomes the thumbnail (privacy rule)

The stored thumbnail is chosen by the engine, in this order:
1. A sharp frame (Vision's face capture quality [cited: Vision docs]) in which every face found is a
   named person who agreed, preferring Gabriel or Serenity looking toward the camera.
2. Otherwise, the best frame with every other face blurred, the same blur the output uses.
3. Otherwise (nothing found yet, audio only, or a frame cannot be made safe): a neutral tile in the
   system's quaternary fill with the recording's date in 21 pt semibold and the symbol for its kind.

No thumbnail is ever written to disk with an undecided face unblurred. Thumbnails live in
`~/Library/Application Support/Prakriti/Thumbnails/` (never in the shared studio folder, v1 warning 12).

#### 3.1.3 Grouping and sorting per group

| Group | Sections | Default sort |
|---|---|---|
| Needs You | Waiting for your yes; Needs a decision; Couldn't finish; Approved, a check failed | Oldest first inside each (what has waited longest) |
| In Progress | Working; Waiting (in the order they will run); Found | Run order |
| Ready | by month approved | Newest first |
| All Recordings | by month recorded ("October 2026", 21 pt semibold headers) | Newest first |
| A person | by month | Newest first |
| A source | by month | Newest first |

The sort menu offers: Date Recorded, Date Found, Length, Title. A filter menu offers: Kind (Talk,
Class, Conversation), People (each named person; "Other people appear"), Has Edited Video.

#### 3.1.4 Search

One search field, in the toolbar (HIG searching). It searches titles, notes and **what was said**
(the transcripts), with tokens for scope (`searchable(text:tokens:)`): "Title", "Said", "Person".
Results that matched speech show the matching sentence under the card, with its time; clicking the
sentence opens the Viewer at that moment. This is Final Cut Pro 12's Transcript Search idea, in
plain words.

### 3.2 The browser, list view

Command-2 (Command-1 for the grid, as in Finder). A `Table`, sortable columns, 17 pt rows about 36 pt
tall:

| Column | Content |
|---|---|
| (thumbnail) | 64 by 36 pt frame, same privacy rule |
| Title | title; long file names truncate in the middle (HIG lists and tables: names like `2026-09-06 18-06-33` share their start) |
| Recorded | "Sun 13 Sep 2026" (monospaced digits) |
| Length | "15:48" |
| People | "Gabriel, Serenity, 3 others" |
| Status | symbol and words |
| Progress | while working: a small bar, percent and time left; otherwise empty |
| Source | folder name |

### 3.3 The toolbar

Three groups at most (HIG toolbars). Toolbar items are also menu commands (HIG macOS).

| Context | Leading | Center | Trailing |
|---|---|---|---|
| Browser | Sidebar toggle; title (the group's name, under 15 characters: "Needs You", "In Progress", "All Recordings", a person's name, a folder's name) | Grid or List (segmented, symbols only: `square.grid.2x2`, `list.bullet`); Sort and Filter menu (`line.3.horizontal.decrease.circle`) | Activity button; Pause All; Search; Inspector toggle (`sidebar.trailing`) |
| Viewer | Back chevron; title (recording date, "Sun 13 Sep") | Rendition picker (segmented, words: Original, Video, Shorts, Podcast; segments for outputs not made are disabled with the reason in Quick Help) | Make Again...; **Approve...** (prominent, the one primary action); Activity button; Inspector toggle |
| People gallery | Sidebar toggle; "People" | | Search; Inspector toggle |

**The Activity button** is a determinate circular progress view with the whole queue's percent beside
it ("64%") while anything works, and the `clock.arrow.circlepath` symbol alone when idle. Clicking
it opens the Activity window (Final Cut Pro's Background Tasks button does the same). **Pause All**
keeps v1's label and symbol, words always shown (no tooltips).

### 3.4 The Viewer

#### 3.4.1 Layout

- **Picture:** an always-dark canvas (black in both appearances; the HIG allows a permanently dark
  appearance for immersive media) with the system player, `AVPlayerView`, floating controls,
  clipped to the window's corner radius. Its own controls (play, scrub, volume, picture in picture)
  are the system's and are the only scrubber in Prakriti (v1 warning 43 keeps the same rule).
- **Over the picture, top trailing,** three toggles in one clear-glass group (`glassEffect(.clear)`,
  the HIG's case for clear glass over video): **People** (`person.crop.rectangle`), **Captions**
  (`captions.bubble`), **Vertical Guide** (`rectangle.portrait`). Each shows its word under the
  symbol at 12 pt semibold, because there are no tooltips.
  - People: draws a rounded rectangle around each face with its label ("Gabriel", "Serenity",
    "Unnamed 2") at 13 pt semibold on a material capsule. On an edited rendition it shows the blur as
    it is in the file.
  - Captions: shows the rendition's captions as they will be published (burned in for shorts, the
    sidecar file for the main video).
  - Vertical Guide: on the Original or the Video, shades outside a centered 9:16 window that follows
    the subject the way the shorts will (Frame.io's guide, 04 research section 5). Abstract shapes
    only.
- **Rendition picker** in the toolbar: **Original** (the source as recorded), **Video** (the edited
  16:9), **Shorts** (a pop-up next to it, "Short 1 of 3"), **Podcast** (the episode audio). Audio
  renditions show the title, date and the transcript; no waveform (v1 rule: no waveforms as
  decoration).
- **Below the picture:** the Timeline-lite (3.4.3) and the transcript (3.4.4), with a draggable
  divider.

#### 3.4.2 Viewer states

| State | Picture | Banner under the toolbar (one line, 17 pt, symbol, actions on the right) |
|---|---|---|
| Nothing made yet, working | Original plays | `Working: Finding people. 38%. About 6 min left.` and the latest log line at 15 pt monospaced under it. [Pause] [Stop] |
| Making a new version | The current version plays | `Making version 3: Rendering the video. 40%. About 4 min left.` [Stop] |
| Waiting for your yes | Video selected | none (Approve is in the toolbar) |
| Needs a decision | Original | The reason in one sentence, then the decision's own buttons, e.g. `No usable sound: the loudest point is -91 dB.` [Make It Anyway] [Skip This Recording] |
| Couldn't finish | Original if it opens | `Couldn't finish: the last seconds of the file do not play. Tried three times. The original is untouched.` [Try Again] [Show Log] |
| Original not available | Placeholder: `icloud.and.arrow.down` and "This recording is in iCloud and not on this Mac yet." | [Download Now] (asks first; it spends disk space) **[proposal]** |
| Approved, a check failed after | Video | `A check no longer passes: Shorts, 61 s is over the 60 s limit.` [Show Checks] |
| Ready | Video | `Ready to upload. Nothing has been posted.` [Show Upload Checklist] |

#### 3.4.3 Timeline-lite

A map of what stays and what goes, not an editor. Never skeuomorphic: flat shapes, no film frames,
no waveform, no draggable playhead.

- **Two lanes, 64 pt tall in all.**
  - **Spans lane (28 pt):** kept time is a filled rounded bar in the accent color; **removed time** is
    the same shape **outlined only** (1.5 pt, secondary label color), so kept and removed differ by
    fill, not color alone; a **clip from another recording** is filled in the second color (system
    teal) with the `link` symbol and its date when wide enough ("13 Sep").
  - **Marks lane (20 pt):** small symbols at the moments the edit adds something: punch-in or zoom
    (`plus.magnifyingglass`), text or title animation (`textformat`), transition
    (`rectangle.on.rectangle`), chapter start (`bookmark`).
- **Reason symbols in removed spans,** when the span is 24 pt wide or more: pause (`pause`), filler
  word (`ellipsis.bubble`), retake or bad take (`arrow.uturn.backward`), another person
  (`person.fill.questionmark`), trimmed start or end (`scissors`).
- **Clock:** a two-way control at the strip's leading edge, **Everything** (the original's clock,
  removed spans visible, the default because review is about what was cut) or **What Stays** (the
  edited clock, removed spans collapsed).
- **Position:** a 2 pt accent line follows the player. It is not a handle: you move by clicking a
  span (plays from its start), clicking a word in the transcript, or the player's own scrubber.
- **Selecting a span** (click, or Option-Left and Option-Right to step between spans) shows it at the
  top of the inspector (3.5.0): what it is, its length, why it was removed or kept, and **Restore**
  or **Remove**. Delete removes a kept span; Command-Z undoes. Every change marks the edit "Not in the
  video yet" until Make Again (v1 warning 36's rule carries over).
- **Zoom:** Command-plus and Command-minus, or pinch, zoom the strip; it scrolls sideways when
  zoomed.
- **Explaining a span without a tooltip:** with Quick Help on, pointing at a span shows "Removed: a
  pause of 1.8 s at 4:12. Click to select it." in the Quick Help panel at 15 pt.

#### 3.4.4 The transcript under it

- Paragraphs by speaker, the name above each paragraph at 15 pt semibold ("Gabriel", "Unnamed 2"),
  the time at the paragraph's start in monospaced digits, the words at 17 pt.
- **Removed words** are struck through in the secondary color (Loom's pattern, 04 research section 6);
  words from a supporting clip sit inside a light teal band headed "From Sun 13 Sep 2026".
- **Click a word** to play from it. **Select words** and use the context menu: Remove from the Edit,
  Keep in the Edit, Find Supporting Moments for This..., Make a Short from This..., Copy.
- **Follow Playback** (View menu, on by default) keeps the current sentence in view and marks it with
  the accent at 12 percent opacity behind it. Fixes v1's "the transcript does not scroll to follow the
  player".
- **Find** (Command-F) searches inside this transcript with next and previous.
- Paragraphs of people whose speech is set to Remove show their label and the words "Removed: their
  speech is not in the outputs" collapsed, expandable for Ivan only.

### 3.5 The inspector

The inspector follows the selection: a recording selected in the browser or open in the Viewer, a
source, a person, or a Timeline-lite span. Built with `.inspector(isPresented:)`; toggled with
Command-Option-I (the iWork key; Final Cut Pro uses Command-4) and the toolbar button. It uses the
window's standard background, not glass. Sections inside each tab are native `Form` sections with
`.grouped` style, not v1's hand-drawn grey cards.

**Tabs (recording selected):** a segmented control of five symbols, Final Cut Pro style, with the
selected tab's name as a 21 pt header right under it (symbols alone would need tooltips, which are
banned):

| Tab | Symbol | Header |
|---|---|---|
| Outputs | `shippingbox` | Outputs |
| People | `person.2` | People |
| Direction | `wand.and.sparkles` | Direction |
| Checks | `checklist` | Checks |
| Info | `info.circle` | Info |

Command-Option-1 to 5 switch tabs [proposal]. The last tab used is remembered per window, not per
recording.

#### 3.5.0 Above the tabs: the selection strip and Quick Help

- When a **Timeline-lite span** is selected, a strip above the tabs shows it: "Removed: pause, 1.8 s,
  4:12 to 4:14" with **Restore** (or "Kept, 22 s" with **Remove**), and for a supporting clip "From Sun
  13 Sep 2026, 0:31" with **Remove Clip** and **Show Date on Screen** (a switch).
- When **Quick Help** is on (Help menu), a panel at the very top of the inspector explains whatever
  the pointer is over, at 15 pt, with a "More in Help" link. Off by default; the welcome window
  mentions it once.

#### 3.5.1 Outputs tab

1. **Status block.** The status symbol and words at 17 pt semibold ("Waiting for your yes"), then
   one sentence of what it means ("Everything is made and checked. Watch it, choose who appears, then
   approve."). While working, this block becomes the progress block (3.6.1).
2. **Approve...** button (prominent) when the recording is selected in the browser; in the Viewer it
   is in the toolbar instead, so it is never shown twice.
3. **Deliverables**, one row each, in this order. A row: symbol, name (17 pt), one detail line
   (15 pt secondary), a check result symbol, and on the right **Play** (opens that rendition in the
   Viewer) and **Show in Finder**. Every row can be dragged out to Finder or onto Final Cut Pro
   (`NSItemProvider` with the file URL; HIG drag and drop).

   | Row | Symbol | Detail example |
   |---|---|---|
   | Video | `play.rectangle` | "16:9, 3840 by 2160, 30 fps, 12:31. Captions file beside it." |
   | Shorts | `rectangle.portrait` | "3 shorts, 9:16, 0:42 to 0:58, captions burned in." |
   | Podcast episode | `play.circle` | "MP3, -16 LUFS, 47:10." |
   | Podcast-ready episode | `shippingbox` | v1's row, unchanged (being built now in the other run). |
   | Captions | `captions.bubble` | ".srt and .vtt, matched to the edited video." |
   | Thumbnails | `rectangle.3.group` | "3 choices, 1280 by 720." |
   | Title and description | `text.alignleft` | "3 title choices, description, chapters, tags." |
   | Final Cut Pro timeline | `square.and.arrow.down.on.square` | "The same edit, every cut, caption and title editable." |
   | DaVinci Resolve timeline | `square.and.arrow.down.on.square` | "The same edit for DaVinci Resolve." |

   An output this recording's source does not make shows its row dimmed with "Not made for this
   folder." and a **Make It** button. An output not built yet in the app shows "Not built yet" (v1's
   honest rule, warning 32).
4. **Open in Final Cut Pro** and **Open in DaVinci Resolve**: shown only when the app is installed,
   found by bundle identifier with `NSWorkspace.urlForApplication(withBundleIdentifier:)`. Measured on
   this Mac: `com.apple.FinalCutApp` (Final Cut Pro 12.4, opens `.fcpxml` and `.fcpxmld`) and
   `com.blackmagic-design.DaVinciResolve` (20.2.1). How each file is built and opened is the export
   track's call; the buttons only hand the file to the app.
5. **Show All Outputs in Finder.** No share sheet [proposal]: sharing to an app from inside Prakriti
   would look like posting, and Prakriti never posts.

#### 3.5.2 People tab

The answer to "let me know when it's Gabriel or Serenity, or when it includes other people", and to
"let me choose who is included in the output videos and audio".

1. **Summary sentence** at the top, 17 pt: "Gabriel speaks for 92 percent. 3 other people appear;
   their faces are blurred and their voices removed." Never a bare percentage without the words
   (HIG machine learning: translate confidence into plain concepts).
2. **One row per person found**, named people first:

   ```
   (face)  Gabriel                                   [ Include        v ]
           On screen 14 min. Speaks 13 min.
   (face)  Unnamed 2                                 [ Blur Face      v ]
           On screen 6 min. Speaks 40 s.             Remove speech: on
           Name This Person...   Play Their Moments
   ```

   - **Face:** for a named person who agreed, their key photo. For anyone else, a crop of their face
     from the original, made when the tab opens, held in memory only, never written to disk (C2).
     A voice with no face shows the `waveform` symbol in a circle.
   - **Decision pop-up** (one per person, applying to every output): **Include**, **Blur Face**,
     **Remove** (removes their speech and blurs them wherever they still appear). For a voice with no
     face: **Include** or **Remove Voice**. Defaults from REQUEST.md: named and agreed, Include; anyone
     else, Blur Face with their speech removed.
   - **Customize per Output** (a disclosure under the pop-up): separate pop-ups for Video, Shorts and
     Podcast, for the rare case such as "keep a student's question in the podcast, but not their
     face in the video". The row then says "Different per output".
   - **The consequence line** updates as the choice changes: "Removing Unnamed 2's speech takes out
     4 min 12 s." "Blurring Unnamed 1 affects 31 min of the video."
   - **Play Their Moments** jumps the Viewer through that person's segments (Option-Right for the
     next).
   - **Name This Person...** opens the sheet in 3.9.4.
3. **Uncertain matches**, only for named people who agreed, in Photos' Review More shape: "Is this
   Gabriel?" with the face and **Yes** and **No**. Shown only when the face track marks a match as
   uncertain; never shown as a number.
4. **Set All Unnamed To** (a pop-up at the bottom of the list): applies one decision to every unnamed
   row at once.
5. Every change is undoable and marks the edit "Not in the video yet" until Make Again.

#### 3.5.3 Direction tab

The answer to "give me a way to prompt or adjust the editorialization".

1. **Direction** (a multi-line field, 4 lines, 17 pt). Placeholder: "Describe the edit you want. For
   example: more energetic, faster cuts, keep the story about the first retreat."
2. **Presets**, toggle capsules in two rows, several can be on: **Energetic**, **Calm**, **Faster
   Cuts**, **Fewer Cuts**, **Motivating**, **Enlightening**, **Story First**, **Teaching Only**. Each is a
   structured instruction sent beside the free text, so it is never lost in a long prompt. Opposite
   pairs switch each other off (Energetic and Calm; Faster Cuts and Fewer Cuts).
3. **Pace:** segmented Relaxed, Balanced, Brisk (default Balanced).
4. **Length:** pop-up "Everything that matters" (default), "About 20 minutes", "About 10 minutes",
   "About 3 minutes".
5. **Shorts:** a stepper "Make 3 shorts" (0 to 5) and a pop-up for their length (30, 45, 60 s).
6. **Make Again...** (Command-R). Making a new version runs the plan step first; when the plan is
   ready, the progress block shows it in plain lines before rendering starts, for example "Cuts
   pauses longer than 0.4 s (was 0.7 s). Punch-ins about every 8 s (was 15 s). Keeps the story at
   12:40." with **Stop** beside it. This is the HIG generative AI rule: acknowledge the correction and
   keep the person in control. **[proposal: the engine track decides what the plan lists]**
7. **Versions**, newest first: "Version 3. Energetic, Faster Cuts. Made Sat 10 Oct, 9:41 pm. 11:02
   long." Each with **Play** and **Use This Version**. Approval covers exactly one version, named in
   the Approve sheet and the receipt.
8. **Supporting Moments** (3.8): the clips added from other recordings, each with **Remove**, and the
   **Find Supporting Moments...** button.
9. The defaults for all of the above come from Settings, House Style; a "Use as Default for New
   Recordings" link under the presets saves the current choices there.

#### 3.5.4 Checks tab

Every check is a row: a symbol (`checkmark.circle` passes, `exclamationmark.triangle` warns,
`xmark.octagon` fails), what was checked, the measured value, and the limit, in words.

1. **Capture** (the clean-input checks): video size and frame rate; audio tracks, sample rate and
   loudness; the speaker's place in the frame (does a vertical crop keep them in); light on the face;
   steadiness. A warning always carries the matching capture tip and a link to the Help article
   "Record for the Best Results". A poor input never publishes silently; it waits in Needs You with
   the warning (REQUEST.md).
2. **Platform** (per deliverable): each published spec, measured against the file. Example: "Video:
   H.264 High, 3840 by 2160, 30 fps, AAC 48 kHz. Passes YouTube's recommended settings." The limits
   and the source of each come from the distribution track; YouTube's own recommended upload settings
   (MP4, AAC-LC 48 kHz, H.264 High, upload at the recorded frame rate, 35 to 45 Mbps for 4K at 30 fps)
   are one example [cited: YouTube].
3. **Accuracy:** v1's checklist of claims for a person to confirm, each with a checkbox Ivan ticks.
   Quotes are proved by the app; claims are not (v1 finish line).
4. **Privacy:** the lock and its reason ("Other people appear in this recording, so only models on
   this Mac read it."), and where each model step ran.

#### 3.5.5 Info tab

Title (field), What This Is (Talk, Class, Conversation), Notes, Recorded (date and time), Original
(path, truncated in the middle, with Show in Finder), Length, Size, Found (date, folder), Output
folder (Show in Finder), Made with (the models and their versions per step).

#### 3.5.6 Inspector for other selections

| Selected | Inspector shows |
|---|---|
| A source (sidebar) | Folder path, "Make outputs automatically" or "Ask me first" (v1), which outputs this folder makes, last checked ("Checked 2 min ago"), Pause This Folder, Show in Finder |
| A person (gallery or sidebar) | Name, key photo, "Agreed on Sat 10 Oct 2026", recordings count, Rename..., Change Key Photo, Review Possible Matches..., Forget This Person... |
| Nothing | "Select a recording to see its outputs, people and direction." |
| Several recordings | Count, total length, and the actions that work on many: Make Again with These Settings..., Pause, Mark As |

### 3.6 Progress

The answer to "give me a progress on the recordings as it's working on the output".

#### 3.6.1 Per recording

| Where | What shows |
|---|---|
| Card | Status capsule "Working" plus a determinate ring and percent ("64%") |
| List row | Small bar, percent, "About 6 min left" |
| Inspector status block | Stage name, "Step 5 of 9", a determinate bar, percent, time left, the latest log line (15 pt monospaced, one line, truncated at the end), Pause and Stop |
| Viewer banner | The same as the inspector, on one line (3.4.2) |
| Activity window | The full stage list (3.6.3) |

**Stage names** are plain verbs, never "Processing" (v1 copy rule). Proposed list, to match the
engine's real steps: Checking the file, Listening (transcribing), Finding people, Planning the edit,
Cutting, Adding captions and titles, Making the video, Making the shorts, Making the podcast audio,
Checking against platform specs. **[proposal: the engine track owns the list]**

**Percent and time left, honestly** (HIG progress indicators: even out the pace, keep it moving,
switch from indeterminate to determinate when you can):
- Overall percent is each stage's share of the work, weighted by that stage's **measured** average
  time on this Mac, so a 10-second check is not worth the same as a 6-minute render.
- Time left is shown only once there is a measured rate for the running stage; before that, "Working
  out the time left". It is always "About" and rounded (under 1 min, then whole minutes, then "About 1
  hr 10 min").
- If a stage makes no progress for 60 s, the line says what it is waiting on ("Waiting for LM
  Studio to load the model") rather than freezing.
- Updates at most twice a second.

#### 3.6.2 App-wide, in the toolbar and the menu bar

The toolbar's Activity button (3.3) shows the whole queue's percent. The menu bar status line
(3.14) reads, for example, "Making Sun 13 Sep: Rendering the video, 64%, about 6 min left. 2
waiting."

#### 3.6.3 The Activity window (Command-9)

Final Cut Pro's Background Tasks plus Compressor's Active and Completed views, in Prakriti's words.
About 640 by 720 pt, resizable.

- **Header:** one sentence ("Making 1 recording. 2 waiting. About 18 min left.") and **Pause All**
  (or Resume All) on the right.
- **Segmented control:** **Now**, **Finished**, **Log**.
- **Now:** a Working section, then Waiting in run order. Each row: thumbnail (same privacy rule), title,
  stage, bar, percent, time left, the latest log line; **Pause** and **Stop** per row; a disclosure
  that opens the stage list: done stages with how long each took, the running stage with a live
  timer, the stages still to come in the secondary color with their measured average ("usually 4
  min"). Waiting rows can be dragged to change the order, and have **Make Next** in their context
  menu.
- **Finished:** today and earlier, each with its result (Waiting for your yes, Couldn't finish,
  Skipped) and **Show** (opens it in the main window) and **Show in Finder**.
- **Log:** v1's Activity sentences, grouped by day, newest first, with a search field. "Checked 2
  folders. Nothing new." stays as the heartbeat. The same lines remain in
  `~/Library/Logs/Prakriti/<date>.log`.
- **Empty (Now):** "Nothing is being made. Prakriti checked 2 folders at 9:41 pm and found nothing
  new."
- Final Cut Pro pauses its background work while you edit; Prakriti does not, because its work is
  the point. **[proposal]** It does lower its own priority while the Viewer is playing, so playback
  never stutters.

### 3.7 Editorial direction: how it behaves

Covered in 3.5.3; the behaviors that span screens:
- Direction, presets, pace and length are stored **per recording** and per version, so Version 2 can
  be compared with Version 3 and the receipt says which direction made the approved file.
- A change to direction does nothing until **Make Again**; the Outputs tab and the Viewer banner say
  "Your direction changed. Make Again to see it." (v1's "Not in the episode yet" pattern).
- Make Again on several recordings at once (browser selection, context menu "Make Again with These
  Settings...") applies one direction to all of them, for example "Calm, Teaching Only" for a set of
  archive talks.
- Where the model runs follows Settings, Models, and the privacy lock (3.13).

### 3.8 Moments from another recording (merging)

The answer to "merge sections from different videos ... added to the video at hand but not always
and not as a rule". Off unless asked; suggestions are never inserted on their own.

**Entry points**
1. Direction tab, **Find Supporting Moments...**: looks for moments that support the main points of
   this recording.
2. Select words in the transcript, context menu **Find Supporting Moments for This...**: looks for
   moments that support that passage.

**The sheet** (about 720 by 600 pt):
- Header: "Moments that support: 'the breath comes before the pose'" (the passage, or "this
  recording's main points").
- **Up to three suggestions,** each a row:
  - The source: thumbnail (privacy rule), "Sun 13 Sep 2026, Talk with Gabriel".
  - **The exact words**, quoted, 17 pt, with their length ("0:31").
  - **Why**, one plain sentence, factual, not flattering (HIG machine learning): "Makes the same
    point about breath, said more directly."
  - **Where it would go:** "After 'and that is why we start with the breath' at 4:12" (a sentence
    boundary in this recording).
  - **Play** (plays the clip in the sheet's own small player, from the source's edited video if one
    exists), **Add**, **Not This One**.
- Footer: "Clips from another day show their date on screen." with a switch (C6), and **Done**.
- **Empty:** "No other recording makes this point clearly. Prakriti searched 14 recordings of
  Gabriel." (Count real, never invented.)

**What may be suggested** (engine rules the UI depends on; the merge track decides the method):
- Only recordings of the **same named person** who agreed, and only spans where every face and
  voice is a named person who agreed (a moment from a class with students in frame is not offered).
- Search is by meaning over transcript sentences, with the local embedding model
  (`nomic-embed-text-v1.5` in LM Studio, per the task brief), so it stays on this Mac.
- Clips 5 to 45 s, starting and ending on sentence boundaries [proposal].

**After Add:** the clip appears in the Timeline-lite in teal with its date, in the transcript inside
a "From Sun 13 Sep 2026" band, and in the Direction tab's Supporting Moments list with **Remove**. It
is in the video at the next Make Again. The Approve sheet and the approval receipt list every added
clip with its source recording and time.

### 3.9 People

#### 3.9.1 The gallery (sidebar, People)

Photos' People & Pets, restricted by the biometric decision.
- **Named people** as circles, 120 pt key photos, name under each (17 pt semibold), "Appears in 12
  recordings" (15 pt). Sort: Custom Order (drag) or By Name (Photos' two sorts).
- **One tile, "Unnamed people"** (`person.crop.circle.badge.questionmark`, no face): "Prakriti does
  not remember people who are not named. Each recording shows its own." and "In 6 recordings";
  clicking it shows those recordings in the browser.
- **Empty:** "No one is named yet. Open a recording, choose People in the inspector, and use Name
  This Person on a face."

#### 3.9.2 A person's page

- Header: key photo (160 pt circle), name (28 pt semibold), "Agreed on Sat 10 Oct 2026. Prakriti
  remembers this face and voice."
- Buttons: **Review Possible Matches...** (Photos' Review More: one appearance at a time with Yes and
  No; only matches the face track marked uncertain), **Change Key Photo...**, **Rename...**.
- Below: the recordings they appear in, as the normal grid, with "Speaks 82 percent" under each.
- **Forget This Person...** (in the inspector, and the context menu): an alert, "Forget Gabriel?",
  message "Prakriti deletes the face and voice it remembers for Gabriel. Recordings keep their
  choices, and Gabriel is not found automatically again until you name him and he agrees again."
  Buttons **Forget** (destructive style, because forgetting is the intent here) and **Cancel**.

#### 3.9.3 What "named" means

| Kind | How it happens | What is stored | Where it shows |
|---|---|---|---|
| **Named, agreed** | Name This Person with "has agreed" ticked | Face and voice prints, the key photo, the date of agreement | Gallery, sidebar, every recording they are found in |
| **Named for this recording** | Name This Person with "has agreed" unticked | The name, on this recording only. No print | That recording's People tab and transcript labels |
| **Unnamed** | Found, never named | Nothing after the job ends (REQUEST.md) | That recording's People tab, labeled "Unnamed 1", "Unnamed 2"... |

#### 3.9.4 The Name This Person sheet

- The face, large (live crop, not saved). A **Name** field with suggestions of people already named
  (choosing one means "this is Gabriel": the appearance joins that person).
- A checkbox: **"[Name] has agreed to be recognized by Prakriti."** Under it, 15 pt: "Checked:
  Prakriti remembers this face and voice to find [Name] in later recordings. Unchecked: the name is
  used in this recording only, and nothing about their face or voice is kept."
- **Cancel** and **Name** (default). The agreement's date is recorded and listed in Settings, Privacy.

### 3.10 Sources

- Each watched folder is a sidebar row; selecting it shows its recordings, and the inspector shows its
  settings (3.5.6).
- **Add Folder...** (the + on the Sources header, and the File menu) uses the system Open panel; v1's
  refusals (the SerenityAI archive, Prakriti's own folders, development mode limits) stay as alerts.
- **Importing a file** (File, Import..., Command-Shift-I, the key Photos uses; Final Cut Pro uses
  Command-I; or dragging a file onto the window) puts it in the Drop folder's queue, as v1's Process File does.
  While a file is dragged over the window, the browser shows a drop highlight only when it can accept
  the file (HIG drag and drop).
- **Empty (no sources):** "Add a folder for Prakriti to watch. New recordings in it are found on their
  own." **[Add Folder...]**

### 3.11 Approve, and Ready

**The Approve sheet** (Approve..., Command-Shift-Return [proposal]):
- Title: "Approve Sun 13 Sep?"
- **Deliverables** with checkboxes, all on by default. A deliverable that fails a platform check is
  unticked and disabled, with the failing check named ("Short 2 is 61 s; the limit is 60 s").
- **Version:** "Version 3, made Sat 10 Oct, 9:41 pm."
- **People:** one line per decision ("Gabriel: included. Unnamed 1 to 3: faces blurred, speech
  removed.").
- **Moments from other recordings:** each with its source and date, or "None".
- **Privacy:** where each model step ran.
- Footnote, 15 pt: "Approving copies these files to Approved and writes a receipt. Nothing is
  uploaded or posted."
- **Cancel** and **Approve** (default). Approve is refused, with the reason in the sheet, while edits
  are not in the video yet (v1 warning 36), or while any chosen deliverable fails a check (C8).

**Ready** (sidebar group): approved and passing. Its inspector Outputs tab adds an **Upload
Checklist** per platform: each field the platform asks for (title, description, tags, chapters,
captions file, thumbnail, made-for-kids answer, AI disclosure where relevant), each with **Copy** for
text and **Show in Finder** for files, in the order the platform's upload form asks for them. The
platform list and field order come from the distribution track. The point: the only step left is
Ivan pressing Upload.

### 3.12 Export menu items

File menu: **Export Final Cut Pro Timeline...** (Command-E [proposal]; Final Cut Pro uses Command-E for
its own export), **Export DaVinci Resolve Timeline...**, **Show Outputs in Finder**. Each export
writes beside the outputs, or where Ivan picks in a save panel; it never writes into a watched
folder.

### 3.13 The Settings window

A standard `Settings` scene: a toolbar of panes, the window title is the pane's name, the last pane
reopens (HIG settings). About 760 pt wide, height fits the pane; 17 pt type; native grouped forms.

| Pane | Symbol | What is in it |
|---|---|---|
| **General** | `gearshape` | Open at login (v1); Show in menu bar (on); Notifications (a button that opens System Settings, Notifications, with the current state in words); Pause All; Show the Welcome Window Again |
| **Outputs** | `shippingbox` | v1's Outputs screen as it is, per output: what is made and how (loudness, trim, intro and outro, transcript formats, podcast-ready); plus the new video outputs' sizes and shorts' count. Which outputs each folder makes stays on the folder (v1 warning 28) |
| **House Style** | `paintpalette` | The editing grammar, inspired by MKBHD's and never his brand (REQUEST.md): Pace default, Punch-ins and zooms (Off, Subtle, Punchy), Text animation (Off, Subtle, Bold), Transitions (Cuts only, Restrained), Captions style (font, size, position, burned in for shorts), Title cards, Brand colors and the title font (Prakriti's own house style by default), Date labels on moments from other recordings (C6). A short sample plays in a small player as each setting changes **[the edit track decides what each setting does]** |
| **Models** | `sparkles` | Where the work happens (below) |
| **Privacy** | `hand.raised` | Default decisions for unnamed people (Blur Face and Remove speech, the REQUEST.md default); the list of people who agreed, with their dates, and Forget; "Prakriti never uploads a recording or removed audio" stated as fact; the privacy lock rule in one sentence |
| **Advanced** | `gearshape.2` | Folders and paths (Outputs, Approved, Drop), the log folder, development mode note; nothing a person needs day to day |

**Models pane, in detail** (the answer to "add space for an OpenAI or Anthropic API"):

1. A first sentence that tells the truth about what moves (C3): "Models write and decide: they choose
   the cuts from the transcript, write captions, titles and notes. Transcribing, finding people and
   making the video always happen on this Mac, and no recording ever leaves it."
2. **This Mac:** the chip and memory, read from the system ("M5 Pro, 64 GB"), with a plain verdict:
   "This Mac can run the writing model." The threshold is measured, not guessed: Qwen3.8-27B holds
   about 33 to 36 GB and the whole Mac peaked at 51 to 54 GB (`docs/LOCAL-MODEL.md`), so the verdict is
   "can run it" at 64 GB or more, and below that "Use a smaller model on this Mac, or a cloud key"
   **[threshold proposed; the model track confirms]**.
3. **Providers**, each a group: **LM Studio** (address and model, v1), **Apple on-device**, **Ollama**,
   **Anthropic** (API key field saved to the Keychain, model pop-up filled from the provider's list,
   **Test** button), **OpenAI** (the same). Keys are never shown after saving, only "Saved in your
   Keychain" with **Remove Key**.
4. **Tasks:** v1's per-task pickers (Planning the edit, Writing, Tagging, Summarizing), each choosing
   a provider.
5. **The privacy lock,** in one sentence with its symbol: "Classes, and recordings where other people
   appear or speak, are only read by models on this Mac. A task set to a cloud provider is done here
   instead for those recordings, and the recording says so." (C4.)

### 3.14 The menu bar extra

A menu, not a popover (HIG). The icon is a template symbol whose shape changes with the state (v1
already does this): idle, working (animated with a symbol effect, static under Reduce Motion), needs
you, paused, problem. The icon art is the icon track's (section 7).

Menu:
1. Status line, disabled text: "Making Sun 13 Sep: Rendering the video, 64%, about 6 min left."
2. "2 recordings need you" (opens Needs You), shown only when true.
3. Divider. **Open Prakriti**, **Show Activity** (Command-9 shown).
4. Divider. **Pause All** or **Resume All**.
5. Divider. **Settings...**, **Prakriti Help**, **Quit Prakriti**.

### 3.15 Notifications

v1's rules hold: one notice per recording, updated in place, never carrying a file name, a title, a
person's name or tool error text (v1 warning 23). New in v2, as fixed sentences:
- "Other people appear in this recording. Their faces are blurred and their voices removed until you
  decide." (Delivered once, when people are first found.)
- "The edit is ready to watch." (Replaces "Ready for Your Yes" in place; the title becomes "Waiting
  for Your Yes".)
- "A check did not pass. Open it to see which." (Approved recording whose check fails.)

### 3.16 Empty states

Each says what will appear, that it appears on its own, and the manual path (04 research section 12).

| Where | Copy | Button |
|---|---|---|
| Needs You | "Nothing needs you. Prakriti checked 2 folders at 9:41 pm." | none |
| In Progress | "Nothing is being made. New recordings start on their own." | Import... |
| Ready | "Nothing is ready to upload yet. Approved recordings that pass every check appear here." | none |
| All Recordings, first run | "No recordings yet. Recordings in the folders you watch appear here on their own. You can also drag a file here." | Add Folder..., Import... |
| A search with no results | "No recordings match 'breath first'." | Clear Search |
| A filter with no results | "No recordings match these filters." | Clear Filters |
| A person with no recordings | "Prakriti has not found Gabriel in a recording yet." | none |
| Viewer, an output not made | "This recording's folder does not make shorts." | Make Shorts |
| Timeline-lite before an edit | "The edit appears here when it is made." | none |
| Supporting Moments, none added | "No moments from other recordings. Add one only when it helps." | Find Supporting Moments... |

### 3.17 Errors

The HIG's rules, as v1 already applies them: say what happened, close to where it happened, without
blame, with the fix; an alert only when Ivan must act now; never at launch.

| Situation | Where it shows | Words (draft) |
|---|---|---|
| A tool stopped | Viewer banner, inspector status | "Couldn't finish: Making the video stopped after 10 min with no progress. The original is untouched." [Try Again] [Show Log] |
| LM Studio not reachable | The progress line, then Needs a decision | "LM Studio is not answering at localhost:1235. Open LM Studio and turn on its server, or choose another model in Settings, Models." [Try Again] [Open Settings] |
| A cloud key rejected | Settings, Models, beside the key | "Anthropic did not accept this key. Check it and save it again." |
| Disk low (archive floor, v1 warning 24) | Activity header | "Archive work is paused: under 100 GB free. Studio recordings keep going." |
| The original moved | Viewer placeholder | "The original is no longer at its path." [Locate...] |

---

## 4. The welcome window

The answer to "a startup screen that gives initial instructions on usage tips for the app, including
how to capture the best video".

### 4.1 How it behaves

- **When:** the first launch only (`Window` with `.defaultLaunchBehavior(.presented)` gated on a
  stored `welcomeSeenVersion`; `.restorationBehavior(.disabled)` so it never reappears by itself).
  Afterwards from **Help, Welcome to Prakriti** and **Settings, General, Show the Welcome Window
  Again**. The HIG: onboarding is optional, not shown again once skipped, easy to find later
  [cited: HIG onboarding].
- **Window:** 720 by 600 pt, not resizable (`.windowResizability(.contentSize)`), centered, in front
  of the main window. It is a window, not a sheet, so the main window stays usable behind it.
- **Navigation:** "1 of 5" at the bottom leading edge (15 pt, words, not dots); **Back** (secondary)
  and **Continue** (default, Return) at the bottom trailing edge; the last panel's button is **Start
  Using Prakriti**. Closing the window at any point counts as seen.
- **Each panel:** a 48 pt symbol in the accent color (hierarchical rendering), a title at 28 pt
  semibold, one line under it at 17 pt secondary, then 3 to 6 rows (a 28 pt symbol, a 17 pt semibold
  headline, a 17 pt sentence). Everything fits without scrolling at 17 pt (a snapshot test checks it).
- **Later versions:** the same window shows one "What's New in Prakriti" panel of feature rows
  instead, once per version that has one (the Pixelmator Pro and Final Cut Pro shape, measured).
- **Accessibility:** each title is an accessibility heading; Escape closes; Command-Left goes back.
- **No pictures of hardware, no illustration for decoration.** Panel 3 may carry one real picture of
  the Viewer drawn from sample data (no real student) **[proposal]**.

### 4.2 The five panels, draft copy

Every string below follows the app's copy rules (no em dashes, no "we", no "Processing", "click" not
"tap", describe, never sell).

**Panel 1. Welcome to Prakriti** (symbol `sparkles`)
Line: "Prakriti turns a raw recording into finished work, on this Mac."

| Symbol | Headline | Sentence |
|---|---|---|
| `tray.and.arrow.down` | It finds your recordings. | Anything saved in a folder you choose is found on its own. |
| `wand.and.sparkles` | It makes the edit. | Pauses, filler words and retakes come out. Captions, titles, zooms and transitions go in. |
| `shippingbox` | It hands you finished files. | A video ready to upload, short vertical clips, a podcast episode, and a timeline you can open in Final Cut Pro or DaVinci Resolve. |
| `checkmark.seal` | Nothing is posted without you. | You watch it, choose who appears and approve it. Uploading is always yours. |

**Panel 2. Record for the Best Results** (symbol `camera.viewfinder`)
Line: "Prakriti does its best work with a clean recording. These six things make the biggest
difference."

| Symbol | Headline | Sentence |
|---|---|---|
| `camera.viewfinder` | Frame at eye level. | Put the speaker in the middle of the picture with a little space above the head, so the vertical clips keep them in frame. |
| `video.badge.checkmark` | Record 4K or 1080p at 30 frames per second. | Keep the same settings for the whole session. In OBS, record Hybrid MP4, not MKV. |
| `mic` | Give each speaker a microphone. | Record each one to its own track. A clip-on mic about a hand's width below the chin works well. |
| `light.max` | Light the face. | Light from the front, a little to one side. Avoid a bright window behind the speaker. |
| `person.2` | Keep students out of frame. | Seat them behind the camera. Anyone Prakriti does not know is blurred and their voice removed, so a clean frame means less is cut. |
| `hourglass` | Leave a few seconds at each end. | Start recording a few seconds before speaking and stop a few seconds after. |

Link under the rows: "More in Help: Record for the Best Results".
Sources for the numbers: YouTube asks for upload at the frame rate recorded and gives 1080p and 4K
settings [cited: YouTube]; OBS Hybrid MP4 is START_HERE warning 15. The microphone distance and
the few seconds at each end are common practice, not a platform rule **[unverified as a measured
need for Prakriti; the edit track should confirm what it uses]**.

**Panel 3. How Outputs Work** (symbol `shippingbox`)
Line: "From a raw recording to files ready to upload, in five steps."

1. "Prakriti finds a new recording and starts on its own. Progress shows on the recording and in
   Activity."
2. "Watch the edit in the Viewer. The bar under the picture shows what stayed and what was taken
   out."
3. "Under People, choose who appears in each output."
4. "Under Direction, say how the edit should feel, for example "more energetic", then choose Make
   Again."
5. "Approve it. The finished files and an upload checklist are ready, and you press Upload."

**Panel 4. Privacy** (symbol `hand.raised`)
Line: "Prakriti protects everyone who did not choose to be in the video."

| Symbol | Sentence |
|---|---|
| `eye.slash` | People Prakriti does not know are blurred and their voices removed, unless you choose otherwise. |
| `person.badge.shield.checkmark` | Prakriti remembers a face or a voice only for someone you name who has agreed. Everyone else is forgotten when the work is done. |
| `lock` | Recordings never leave this Mac. With an Anthropic or OpenAI key, only words are sent, and never for a class or a recording where other people appear. |

Link: "More in Help: Privacy and People". (Apple's pro apps put privacy in onboarding in the same
shape: a title, one line, three short points, a link; measured in `ProOnboardingFlow.framework`.)

**Panel 5. Get Started** (symbol `checklist`)
Line: "Each of these is optional and can be changed later in Settings."

| Row | Control | After |
|---|---|---|
| Choose a folder to watch | **Choose Folder...** (system Open panel) | The folder's name with a checkmark |
| Get a notice when something needs you | **Turn On Notifications** (asks macOS when clicked, never at launch) | "On", or "Off. You can turn them on in System Settings, Notifications." |
| Choose where models run | Pop-up: This Mac, Anthropic, OpenAI, with the verdict line from Settings, Models ("This Mac, M5 Pro with 64 GB, can run the writing model.") | The choice |

Button: **Start Using Prakriti**.

---

## 5. The Help system

The answer to "start building documentation for the help section of the app".

### 5.1 The pieces

| Piece | What it does | Where |
|---|---|---|
| **Help window** | Every article, browsable by section and searchable | Help, Prakriti Help (Command-?) |
| **Help menu search** | Typing in the Help menu's own search field lists matching articles under the app's menu commands | macOS Help menu |
| **"?" buttons** | `HelpLink` in each sheet (Approve, Name This Person, Supporting Moments) opens its article | Sheets |
| **Show Me links** | A link inside an article opens the place in the app it describes | Articles |
| **Quick Help** | Explains whatever the pointer is over, at 15 pt, instead of tooltips | Top of the inspector, or a floating panel |
| **Tips** | At most four one-time tips (TipKit), each one or two sentences | Beside the feature, once |
| **Welcome window** | The five panels | First launch, Help menu |

### 5.2 The Help window

- `NavigationSplitView`: a sidebar of sections and article titles (17 pt), and the article.
- Toolbar: Back and Forward, the article's title, a search field (Command-F inside the window).
- Article: at most 680 pt wide for a comfortable line (about 70 characters at 17 pt), centered, on
  the window background. Title 28 pt semibold, section headings 21 pt semibold, body 17 pt, steps as
  numbered lists, key names written out ("Command-9").
- Sections, in order: Get Started; Recording; Watching and Reviewing; People and Privacy; Directing
  the Edit; Outputs and Uploading; Settings and Models; When Something Goes Wrong.
- Every article ends with "Related" links.
- Default size 960 by 720 pt; remembers its size and last article.

### 5.3 How articles are stored

- **One Markdown file per article,** in the app's source at `mac/Prakriti/Resources/Help/`, copied
  into the app bundle. Written in the same commit as the feature it describes (the project's rule).
- **Front matter** (YAML) on every article:

  ```yaml
  id: record-best-results           # stable; links and the Help menu use it
  title: Record for the Best Results
  summary: Six things that make the biggest difference to what Prakriti can make.
  section: recording
  order: 1
  keywords: [camera, microphone, OBS, 4K, light, framing, students]
  related: [privacy-and-people, checks]
  ```

- **Body:** a small CommonMark subset: `##` and `###` headings, paragraphs, numbered and bulleted
  lists, bold, links, images, and a "Note:" paragraph style. No tables (they do not fit 17 pt in a
  narrow window), no HTML.
- **Links:** `prakriti-help://<id>` opens another article; `prakriti://show/<place>` opens a place in
  the app, for example `prakriti://show/settings/models`, `prakriti://show/activity`,
  `prakriti://show/group/needs-you`. A Show Me link renders as a button ("Show Me").
- **Images:** real window captures made from sample data, never a real student, in light and dark
  pairs (`viewer.png`, `viewer-dark.png`) under `Resources/Help/images/`, made by a capture script
  like v1's `make look`. No drawn illustrations.

### 5.4 How articles are rendered

- Parsed with Apple's open source **swift-markdown** package (`github.com/swiftlang/swift-markdown`,
  pin **0.9.0**, released 21 Sep 2026, measured on GitHub) into blocks, and each block drawn as a
  SwiftUI view with `AppFont`, so the 17 pt and 12 pt rules hold and the same font test covers Help.
  `AttributedString(markdown:)` alone handles only inline styles, so it is used inside paragraphs, not
  for headings and lists.
- Not a web view: no web content process, the same type and colors as the rest of the app, and the
  same snapshot tests.

### 5.5 Search, the Help menu and Quick Help

- **In the Help window:** an index built at launch from every article's title, summary, keywords
  and text (about 30 articles, so no indexer). Ranking: title, then keywords, then summary, then text.
  Results show title, summary and the matching sentence. Search as you type.
- **In the Help menu:** register a search handler at launch with
  `NSApp.registerUserInterfaceItemSearchHandler(_:)` (AppKit, macOS 10.6 and later, not deprecated
  [cited: Apple docs]). The handler implements `NSUserInterfaceItemSearching`:
  `searchForItems(withSearch:resultLimit:matchedItemHandler:)` returns matching article ids,
  `localizedTitles(forItem:)` their titles, `performAction(forItem:)` opens the Help window at that
  article, and `showAllHelpTopics(forSearch:)` adds "Show All Help Topics", which opens the Help
  window with the search filled in. macOS lists matching menu commands beside them by itself.
- **Quick Help:** each control that needs explaining declares a one or two sentence description and,
  if useful, an article id (a `.quickHelp(_:article:)` view modifier that reports hover to a shared
  model). The panel shows it at 15 pt with "More in Help". This replaces `.help()` tooltips, which v1
  bans (11 pt). Off by default; Help, Show Quick Help turns it on.
- **Tips (TipKit),** each shown once, at most one a day (HIG offering help), event based:
  1. First unnamed person found, on the People tab: "Choose who appears. People Prakriti does not
     know stay blurred and their voices removed until you decide."
  2. First edit ready, on the Direction tab: "Say how the edit should feel, then choose Make Again."
  3. First transcript under the Viewer: "Click a word to play from it. Select words to take them out
     or keep them."
  4. First recording in Ready: "Ready recordings carry an upload checklist with every field to
     copy."

  **[unverified]** that `TipView` on macOS draws a tip's `Text` at the font the app sets rather than
  the system's smaller styles; the snapshot test must check it, and if it cannot be made 12 pt or
  more, tips are drawn as Prakriti's own inline rows instead.

### 5.6 Why not an Apple Help Book

Measured on this Mac: Help Viewer is now part of the **Tips** app (`/System/Applications/Tips.app`,
bundle identifier `com.apple.helpviewer`, version 27.2), which still opens Help Books, and `hiutil`
still ships. A Help Book would give Help menu search with no code. It is still the weaker choice:

- Apple's own creative apps register Help Books that point to web pages (Final Cut Pro's named book is
  not in its bundle; Keynote's is a `remote.help`): the format survives mainly as a pointer.
- The help system's indexing has been unreliable for years (Eclectic Light, 2021 and 2023
  [cited]); the authoring guide is a 2013 archive.
- A Help Book opens in another app with its own window chrome, cannot open places inside Prakriti,
  and is HTML instead of the Markdown the rest of the project uses.
- `NSUserInterfaceItemSearching` gives the same Help menu search for Prakriti's own articles.

If Ivan later wants the articles in the Tips app as well, a build step can turn the same Markdown into
a Help Book; nothing in 5.3 prevents it.

### 5.7 The first articles (table of contents)

The documentation track writes them; this is the list the interface links to. Ids are stable.

| Section | id | Title | One-line summary |
|---|---|---|---|
| Get Started | `welcome` | What Prakriti Does | From a raw recording to files ready to upload, on this Mac. |
| | `first-steps` | Your First Recording | Watch a folder, see it found, watch the edit, approve it. |
| | `the-window` | The Library, the Viewer and the Inspector | Where everything is in the main window. |
| Recording | `record-best-results` | Record for the Best Results | Framing, 4K or 1080p at 30 fps, a mic per speaker, light, students out of frame. |
| | `obs-settings` | OBS Settings for Prakriti | Hybrid MP4, separate audio tracks, the same settings every session. |
| | `folders` | How Prakriti Finds Recordings | Watched folders, the Drop folder, Ask Me First, importing a file. |
| Watching and Reviewing | `viewer` | Watching in the Viewer | Original, Video, Shorts, Podcast, and the People, Captions and Vertical Guide toggles. |
| | `timeline-lite` | What Stayed and What Was Taken Out | Reading the bar under the picture, restoring a span. |
| | `transcript` | Editing with the Transcript | Click to play, select to remove or keep, Follow Playback. |
| | `progress` | Watching Progress | Stages, percent, time left, the Activity window, Pause and Stop. |
| People and Privacy | `privacy-and-people` | Privacy and People | Who is protected by default, and what Prakriti remembers. |
| | `choose-who-appears` | Choosing Who Appears | Include, Blur Face or Remove, for every output or per output. |
| | `name-a-person` | Naming a Person | Named for one recording, or named and agreed. |
| | `people-gallery` | The People Gallery | Review possible matches, key photos, forgetting a person. |
| Directing the Edit | `direction` | Directing the Edit | The direction field, presets, pace, length, shorts. |
| | `versions` | Versions | Make Again, compare, use an earlier version. |
| | `supporting-moments` | Adding a Moment from Another Recording | Find, play, add, remove; the date label. |
| | `house-style` | The House Style | Punch-ins, text animation, transitions, captions; inspired by a grammar, never a brand. |
| Outputs and Uploading | `outputs` | What Prakriti Makes | Video, shorts, podcast, captions, thumbnails, titles, timelines. |
| | `final-cut-pro` | Finishing in Final Cut Pro | Open the timeline, what is editable, what to check. |
| | `davinci-resolve` | Finishing in DaVinci Resolve | Import the timeline, what is editable. |
| | `checks` | Checks | Capture, platform specs, accuracy, privacy, and what each warning means. |
| | `approve-and-upload` | Approving and Uploading | The Approve sheet, Ready, the upload checklist. Prakriti never posts. |
| Settings and Models | `models` | Where Models Run | This Mac, Anthropic or OpenAI; what moves to the cloud and what never does. |
| | `privacy-lock` | The Privacy Lock | Which recordings are only read on this Mac, and why. |
| | `shortcuts` | Keyboard Shortcuts | Every shortcut, by window. |
| When Something Goes Wrong | `couldnt-finish` | When a Recording Couldn't Finish | Reading the reason, Try Again, the log. |
| | `lm-studio` | When LM Studio Does Not Answer | Turning on its server, the address, choosing another model. |
| | `where-files-live` | Where Files Live | Outputs, Approved, the Drop folder, logs, and what Prakriti never writes. |

### 5.8 Help checks (tests, added to `make test`)

- Every article has all front matter fields; ids are unique; every `related` id exists.
- Every `prakriti-help://` and `prakriti://show/` link resolves to an article or a real place.
- Every image exists in a light and a dark version.
- No em or en dash, no "we", no "Processing", "click" never "tap" (v1's copy test, extended to
  `Resources/Help`).
- Every SF Symbol named in an article or the welcome window exists (the check `NSImage(systemSymbolName:)`
  run for this spec found every symbol named here on macOS 27.2).
- Every article is drawn in the Help window at 17 pt in light and dark by the snapshot tests, and
  looked at.

---

## 6. The visual system

### 6.1 Type

Ivan's scale stays (v1's `AppFont`; memory "interface type scale"): system font, 17 pt body, 15 pt
secondary, nothing under 12 pt, no tooltips. Apple's Mac default is 13 pt (HIG typography), so every
layout here is sized for 17: fewer columns, more rows, wider inspector.

| Use | Size and weight | Notes |
|---|---|---|
| Welcome titles | 28 pt semibold (34 for panel 1 [proposal]) | |
| Page and article titles | 28 pt semibold | `AppFont.pageTitle` |
| Section headers, inspector tab header, month headers | 21 pt semibold | `AppFont.sectionTitle` |
| Body, sidebar rows, transcript words, list rows | 17 pt | `AppFont.body` |
| Card titles, row names | 17 pt semibold | `AppFont.headline` |
| Secondary lines, Quick Help, log line | 15 pt (log line monospaced) | `AppFont.secondary` |
| Counts in the sidebar | 15 pt semibold, monospaced digits | |
| Capsules on thumbnails, labels under Viewer toggles, transcript speaker names | 13 pt semibold (12 pt minimum) | `AppFont.label` |
| Times and timecodes | 15 pt monospaced digits | `AppFont.numbers` |

### 6.2 Color

| Token | Light | Dark | Use |
|---|---|---|---|
| Accent (fills) | #2337C6 (v1) | #4459E8 (v1) | Selected sidebar row, kept spans, progress, prominent buttons |
| **Accent (text and links)** | #2337C6 | **#7D8BFF (new, C7)** | Text, links, symbols carrying meaning on the window background |
| Supporting clip | system teal | system teal | Clips from other recordings |
| Status, needs you | system orange | system orange | Always with its symbol and words |
| Status, couldn't finish | system red | system red | Same |
| Status, ready | system green | system green | Same |
| Viewer canvas | black | black | Always dark |
| Everything else | system colors (label, secondary label, separators, fills, window background) | | |

Measured contrast (WCAG formula, as Accessibility Inspector uses): #2337C6 on white 8.63 to 1;
white on #2337C6 8.63; white on #4459E8 5.47; **#4459E8 on the dark window #1E1E1E 3.05 (fails 4.5 for
text)**; #7D8BFF on #1E1E1E 5.56. Each custom color also needs an Increase Contrast variant (HIG color);
for the accent, the light value on light and #9AA5FF on dark **[proposal, measure before use]**.
Sidebar icons take the accent, as macOS 27 colors sidebar icons again; no `foregroundStyle` on them
(v1 warning 8 stays).

### 6.3 Materials

- **Liquid Glass only in the control layer:** the toolbar, the sidebar (system), and the three
  toggles over the video (clear variant, the HIG's case for controls over media).
- **Standard materials** for anything over a thumbnail (status, length and progress capsules) and for
  face labels on the video.
- **Plain window background** for the browser, the inspector, the Timeline-lite and the transcript.
  v1's grey rounded cards go away; grouped forms draw their own sections.

### 6.4 SF Symbols

Every name below was checked to exist on this Mac (macOS 27.2) with `NSImage(systemSymbolName:)`.
Symbols are never in the app icon (SF Symbols license, 03 research 2.1). No symbol that draws a
machine or material: `film` exists but is not used (Ivan's never-skeuomorphic rule).

| Meaning | Symbol |
|---|---|
| Needs You | `exclamationmark.bubble` |
| In Progress | `progress.indicator` |
| Ready, Approved | `checkmark.seal` |
| All Recordings | `square.grid.2x2` |
| Grid, List | `square.grid.2x2`, `list.bullet` |
| People, a person, unnamed | `person.2`, key photo, `person.crop.circle.badge.questionmark` |
| Other people in a recording | `person.fill.questionmark` |
| Watched folder, Drop folder | `folder`, `tray.and.arrow.down` |
| Activity | `clock.arrow.circlepath` |
| Inspector tabs | `shippingbox`, `person.2`, `wand.and.sparkles`, `checklist`, `info.circle` |
| Viewer toggles | `person.crop.rectangle`, `captions.bubble`, `rectangle.portrait` |
| Timeline-lite reasons | `pause`, `ellipsis.bubble`, `arrow.uturn.backward`, `person.fill.questionmark`, `scissors` |
| Timeline-lite marks | `plus.magnifyingglass`, `textformat`, `rectangle.on.rectangle`, `bookmark` |
| Supporting clip | `link` |
| Blur, privacy | `eye.slash`, `hand.raised`, `lock`, `person.badge.shield.checkmark` |
| Check pass, warn, fail | `checkmark.circle`, `exclamationmark.triangle`, `xmark.octagon` |
| Settings panes | `gearshape`, `shippingbox`, `paintpalette`, `sparkles`, `hand.raised`, `gearshape.2` |
| Original not on this Mac | `icloud.and.arrow.down` |
| Welcome panels | `sparkles`, `camera.viewfinder`, `shippingbox`, `hand.raised`, `checklist`, plus row symbols in 4.2 |

### 6.5 Motion

Purposeful, short, optional (HIG motion).
- Working: the menu bar icon and the toolbar Activity symbol use a symbol effect (Breathe or Variable
  Color) while work runs; **static** when Reduce Motion is on (`accessibilityReduceMotion`).
- Opening a recording: a 0.2 s crossfade from browser to Viewer; none under Reduce Motion.
- Timeline-lite: spans change width over 0.15 s after Restore or Remove; none under Reduce Motion.
- Progress bars and rings move continuously; percent text changes at most twice a second.
- Nothing waits on an animation finishing to change state (memory "hidden preview pane freezes
  animations": state machines never depend on an animation completing).

### 6.6 Accessibility

- VoiceOver: every card reads "Sun 13 Sep, Talk with Gabriel, 15 minutes 48 seconds, Waiting for your
  yes, Gabriel and 3 other people." Every symbol-only control has a label; the Timeline-lite is an
  accessibility container whose spans read "Removed, pause, 1.8 seconds, at 4 minutes 12 seconds".
- Full Keyboard Access reaches everything, including the Timeline-lite spans and the People pop-ups.
- No state by color alone (fill versus outline in the Timeline-lite; symbol and words on statuses).
- Contrast: 4.5 to 1 for all text (6.2 fixes the one failure found); increase contrast variants.
- Captions in the Viewer (the Captions toggle) and the transcript beside every player (HIG
  accessibility: transcripts for audio and video).
- Reduce Motion and Reduce Transparency honored (glass becomes opaque by the system).

### 6.7 Keyboard shortcuts

| Keys | Command | Where | Note |
|---|---|---|---|
| Command-1, Command-2 | View as Grid, View as List | Browser | Finder's keys |
| Return, Command-Down | Open | Browser | |
| Escape, Command-Up, Command-[ | Back to the browser | Viewer | |
| Space | Quick Look (browser); Play or Pause (Viewer) | | HIG playing video: Space toggles play |
| J, K, L | Play backward, stop, play forward (press again to go faster) | Viewer | Final Cut Pro's keys; behavior, nothing drawn |
| Option-Left, Option-Right | Previous or next span; with a person selected, their previous or next moment | Viewer | |
| Delete | Remove the selected span or words from the edit | Viewer | Undoable |
| Command-Z, Command-Shift-Z | Undo, Redo | Everywhere | |
| Command-F | Search the library; in the Viewer, find in the transcript | | |
| Command-R | Make Again... | Recording | [proposal] |
| Command-Shift-Return | Approve... | Recording | [proposal] |
| Command-E | Export Final Cut Pro Timeline... | Recording | [proposal] |
| Command-Shift-I | Import... | Everywhere | Photos' key (Final Cut Pro's Import Media is Command-I) |
| Command-Option-I | Show or Hide Inspector | Main window | iWork's key |
| Command-Option-1 to 5 | Inspector tabs | Main window | [proposal] |
| Control-Command-S | Show or Hide Sidebar | Main window | The system's key |
| Command-9 | Activity | Everywhere | Final Cut Pro's Background Tasks key |
| Command-comma | Settings | Everywhere | |
| Command-? | Prakriti Help | Everywhere | |
| Command-plus, Command-minus | Zoom the Timeline-lite | Viewer | |

Every shortcut is also a menu item (HIG). The Keyboard Shortcuts help article lists them.

### 6.8 The menu bar (app menus)

| Menu | Items |
|---|---|
| Prakriti | About Prakriti, Settings..., Quit Prakriti |
| File | Import..., Add Folder..., Export Final Cut Pro Timeline..., Export DaVinci Resolve Timeline..., Show Original in Finder, Show Outputs in Finder |
| Edit | Undo, Redo, Cut, Copy, Paste, Select All, Remove from Edit, Keep in Edit, Find |
| View | as Grid, as List, Thumbnail Size, Show Sidebar, Show Inspector, People, Captions, Vertical Guide, Follow Playback, Enter Full Screen |
| Recording | Open, Quick Look, Make Again..., Stop, Approve..., Mark As (Talk, Class, Conversation), Find Supporting Moments..., Name This Person... |
| Playback | Play or Pause, Play Backward, Play Forward, Next Span, Previous Span |
| Window | Activity, Minimize, Zoom, the windows |
| Help | (search field), Prakriti Help, Welcome to Prakriti, Show Quick Help, Keyboard Shortcuts |

Menu items carry their SF Symbols where the system's standard actions have one (HIG the menu bar;
macOS 27 shows icons in more menus).

---

## 7. Icon direction (for the icon track)

Not designed here; these are the constraints the icon track must meet, so the icons fit this design.
- **App icon:** layered, made in Icon Composer, square artwork 1024 px the system masks, default,
  dark, clear and tinted appearances, no text, no photo, no symbol from SF Symbols, no hardware (no
  camera, no film), let the system add glass and highlights [cited: HIG app icons]. It must still read
  at 16 pt in a Finder list.
- **Menu bar icon:** a template image (black and clear) the system tints, drawn for a 24 pt bar, in
  five states that differ by **shape**, not only by color (idle, working, needs you, paused, a
  problem). Best made as a custom symbol in the SF Symbols app so the working state can use a symbol
  effect and Reduce Motion can switch it off [cited: HIG the menu bar].
- **One family:** the menu bar mark should be the app icon's mark reduced to a line, so the two are
  recognizably one product. v1's mark is an ultramarine dot on stone (`mac/scripts/make_icon.swift`).

---

## 8. What changes from v1, and why

Looked at: `screens/mac/finish/` (Today, Recordings, Outputs, Models, Activity, the recording page in
several states) and the real-window captures in `screens/mac/m6/real/`.

| v1 (what the pictures show) | v2 | Why |
|---|---|---|
| A recording is one long page: the approved 13 Sep page is seven screenfuls (`08-recording-approved-light` to `-p6`), with Approve at the top and Make Again near the bottom of a card | The Viewer, the Timeline-lite and transcript, and the inspector's tabs; Approve and Make Again in the toolbar | A long scroll hides controls far from what they affect; Apple's media apps keep the media in view and the controls beside it (Photos, Final Cut Pro). HIG layout: nothing critical at the bottom |
| Today and Recordings are two lists of the same rows | Smart groups in one browser: Needs You, In Progress, Ready, All Recordings | One library, many views, as in Photos |
| Rows of text, no pictures | Real-frame thumbnails under the privacy rule, and a list view for when text is better | Ivan's request; Photos and Final Cut Pro browse by picture |
| Status as grey words at the right end of a row | Status capsule on the thumbnail, progress ring and percent, the status in words in the inspector | Status next to the thing it describes (HIG feedback); color never alone |
| Progress is "Step 5 of 6" and a bar in Today only | Stage, percent, time left and the log line in the card, the inspector, the Viewer, the Activity window, the toolbar and the menu bar | Ivan's request; HIG progress: determinate, accurate, moving |
| Activity is a sidebar page of sentences | An Activity window (Now, Finished, Log), Command-9 | Final Cut Pro's Background Tasks and Compressor's Active view; work you watch while doing something else belongs in its own window |
| Sources, Outputs, Models and Settings are sidebar pages | Sources stay in the sidebar as content; Outputs, Models and the rest become Settings panes | HIG settings; the sidebar is for content |
| Every section is a hand-drawn grey rounded card | Native grouped forms in the inspector and Settings; plain background in the browser | Apple's apps draw sections with the system's forms; less to maintain, correct in both appearances |
| The audio player sits in a card with Episode and Original | The Viewer's rendition picker covers Original, Video, Shorts and Podcast in one player | One player for every output (Ivan: "build a viewer") |
| The transcript is a list of lines that do not follow playback | Paragraphs by speaker, removed words struck through, Follow Playback, select to remove or keep | The transcript is the edit's map (04 research section 6); fixes v1's known gap |
| Privacy lock line names Serenity | Names the real reason (other people, or a class) | REQUEST.md relaxed the lock (C4) |
| "Ready for your yes" | "Waiting for your yes" | "Ready" now means ready to upload (C1) |
| Dark accent used for text | A lighter dark-mode text accent | Measured 3.05 to 1 (C7) |
| Settings live in the main window | A Settings window, Command-comma | Every Apple app; it can stay open beside the library |
| Everything at 17 pt in a 1180 by 760 window | The same type in a 1440 by 900 default window, with collapsing sidebar and inspector | 17 pt needs the room; the Viewer is never the one squeezed |

What stays: the sidebar's accent-colored icons (now matching macOS 27), Pause All always visible, the
copy rules, 17 pt body, the menu bar extra as a menu, the system player, one notice per recording,
every v1 refusal and privacy rule.

---

## 9. Build notes

### 9.1 SwiftUI and AppKit pieces (deployment target is macOS 27.0, `mac/project.yml`)

Availability read from Apple's documentation data on 10 Oct 2026.

| Piece | API | Available |
|---|---|---|
| Three regions | `NavigationSplitView` plus `.inspector(isPresented:)`, `.inspectorColumnWidth(min:ideal:max:)` | macOS 14 |
| Grid | `LazyVGrid` with adaptive columns | macOS 11 |
| List view | `Table`, sortable | macOS 12 |
| Search with scopes | `.searchable(text:tokens:placement:prompt:token:)` | macOS 13 |
| Player | `AVPlayerView` (AppKit, in a representable; v1 already does this) | macOS 10.9 |
| Glass toggles over video | `.glassEffect(_:in:)` with the clear variant | macOS 26 |
| Toolbar groups | `ToolbarItemGroup`, `ToolbarSpacer` | macOS 26 for the spacer |
| Activity, Help, Welcome windows | `Window`, `.defaultLaunchBehavior(_:)`, `.restorationBehavior(_:)` | macOS 15 |
| Quick Help floating panel | `UtilityWindow` | macOS 15 |
| Help menu search | `NSApplication.registerUserInterfaceItemSearchHandler(_:)`, `NSUserInterfaceItemSearching` | macOS 10.6 |
| "?" buttons | `HelpLink` | macOS 14 |
| Tips | TipKit `TipView`, `.popoverTip` | macOS 14 |
| Symbol effects | `.symbolEffect(_:options:isActive:)`, Breathe | macOS 14, Breathe macOS 15 |
| Settings | `Settings` scene, `openSettings` | macOS 14 for `openSettings` |
| Face boxes and key photos | Vision `DetectFaceRectanglesRequest`, `DetectFaceCaptureQualityRequest` | macOS 15 |
| Grouping by month | SwiftData sectioned fetches (`sectionBy`, new at WWDC 2026 per secondary sources) | **[unverified]**; group in code if absent |
| Reordering the Waiting queue | `reorderable()` and `reorderContainer(for:)` (WWDC 2026, secondary sources) | **[unverified]**; `onMove` in a `List` works today |

### 9.2 What the interface needs from the engine (the contract)

The other tracks decide how; the interface needs these fields, observable as they change:

- **Job progress:** stage id and plain name, stage index and count, fraction within the stage,
  overall fraction weighted by measured averages, time left or "not known yet", the latest
  human-readable log line, and what it waits on when stalled.
- **People per recording:** each person found (named and agreed, named here, unnamed n), whether by
  face, voice or both, time on screen, time speaking, their segments (start, end), an uncertain-match
  flag, and a face crop on request (in memory, from the original).
- **Decisions:** per person, per output: Include, Blur Face, Remove (Remove Voice for audio-only
  people); the defaults applied; the consequence (seconds removed, minutes blurred).
- **The edit:** spans on the original's clock (kept, removed with reason, supporting clip with source
  and time), marks (zoom, text, transition, chapter), the map between the original's clock and the
  edited one (v1's `episodeClock` idea, extended to video).
- **Versions:** number, direction and presets, the plan's plain lines, made time, length, files.
- **Deliverables and checks:** each file, its kind, its measured properties, each check with value,
  limit, source and result.
- **Suggestions:** source recording, start and end, exact words, the plain reason, the proposed
  place in this recording.
- **Thumbnails:** a stored frame chosen by the rule in 3.1.2, or none.

### 9.3 Tests to add (beside v1's)

- Snapshot every screen and state above, light and dark (v1's `make snapshots`), and capture the real
  window for the Viewer, the glass toggles and the sidebar (`make look`); bitmaps cannot draw glass or
  `AVPlayerView` (v1 warnings 7 and 43), so the real window is the judge.
- The type test extended to the welcome window, Help articles and tips: nothing under 12 pt.
- The copy test extended to `Resources/Help` and the welcome strings.
- A contrast test over the color tokens (every text token 4.5 to 1 on its background, both
  appearances).
- A privacy test: no thumbnail file is written for a recording until the face step has run, and no
  stored thumbnail contains an undecided face unblurred (checked on a fixture with a planted face).
- A test that the gallery never shows a face for an unnamed person, and that no face crop of an
  unnamed person is ever written to disk.

---

## 10. Open questions for Ivan, each with a recommendation

| # | Question | Recommendation |
|---|---|---|
| Q1 | Rename "Ready for your yes" to "Waiting for your yes" so "Ready" only means ready to upload? (C1) | Yes. |
| Q2 | Show the date on screen for clips taken from another recording, by default? (C6) | Yes, switchable per clip. It keeps Serenity's accuracy condition. |
| Q3 | Show unnamed people's faces, unblurred, in that recording's People tab (made on the fly, never saved), so you can decide? (C2) | Yes. You cannot choose who appears without seeing them. |
| Q4 | Add a "Posted" status you set by hand (with the link), so the library knows what is live? | Yes, after v2's first release. |
| Q5 | Is the Timeline-lite's thin position line acceptable under the never-skeuomorphic rule? It is a line, not a handle; the system player keeps the only scrubber. | Yes. |
| Q6 | Move Outputs, Models and Settings out of the sidebar into a Settings window? (C5) | Yes. |
| Q7 | A shortcut for Approve (Command-Shift-Return), or menu and button only? | Keep it; the sheet still asks. |

---

## Sources

Apple, current documentation and guides (read 10 Oct 2026):
- HIG pages read as Apple's documentation data: [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) (change log to 10 Jun 2024), [Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help), [Launching](https://developer.apple.com/design/human-interface-guidelines/launching), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) (updated 8 Jun 2026), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (updated 16 Dec 2025), [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators), [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (updated 9 Sep 2025), [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) (updated 8 Jun 2026), [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai).
- API availability: [NSUserInterfaceItemSearching](https://developer.apple.com/documentation/appkit/nsuserinterfaceitemsearching), [registerUserInterfaceItemSearchHandler(_:)](https://developer.apple.com/documentation/appkit/nsapplication/registeruserinterfaceitemsearchhandler(_:)), [NSHelpManager](https://developer.apple.com/documentation/appkit/nshelpmanager), [inspector(isPresented:content:)](https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:)), [inspectorColumnWidth](https://developer.apple.com/documentation/swiftui/view/inspectorcolumnwidth(min:ideal:max:)), [searchable with tokens](https://developer.apple.com/documentation/swiftui/view/searchable(text:tokens:placement:prompt:token:)), [Table](https://developer.apple.com/documentation/swiftui/table), [AVPlayerView](https://developer.apple.com/documentation/avkit/avplayerview), [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)), [ToolbarSpacer](https://developer.apple.com/documentation/swiftui/toolbarspacer), [defaultLaunchBehavior](https://developer.apple.com/documentation/swiftui/scene/defaultlaunchbehavior(_:)), [restorationBehavior](https://developer.apple.com/documentation/swiftui/scene/restorationbehavior(_:)), [UtilityWindow](https://developer.apple.com/documentation/swiftui/utilitywindow), [HelpLink](https://developer.apple.com/documentation/swiftui/helplink), [TipKit](https://developer.apple.com/documentation/tipkit), [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra), [DetectFaceRectanglesRequest](https://developer.apple.com/documentation/vision/detectfacerectanglesrequest), [DetectFaceCaptureQualityRequest](https://developer.apple.com/documentation/vision/detectfacecapturequalityrequest), [BreatheSymbolEffect](https://developer.apple.com/documentation/symbols/breathesymboleffect), [Foundation Models](https://developer.apple.com/documentation/foundationmodels).
- [Final Cut Pro release notes](https://support.apple.com/102825) (12.0 on 28 Jan 2026 to 12.4 on 29 Sep 2026; FCPXML 1.14).
- [Final Cut Pro: Background Tasks window](https://support.apple.com/guide/final-cut-pro/verc1fece46/mac); [View background tasks](https://support.apple.com/en-ae/guide/final-cut-pro/ver64e71609/mac); [Browser views](https://support.apple.com/guide/final-cut-pro/ver7ff5e14b9/mac); [Inspector](https://support.apple.com/guide/final-cut-pro/ver15f87af2/mac); [Final Cut Pro 12.0 demo project](https://support.apple.com/guide/final-cut-pro/ver4dec14a61/mac).
- [Compressor interface](https://support.apple.com/en-kz/guide/compressor/cpsr8747af64/mac); [Transcode a batch](https://support.apple.com/guide/compressor/cpsrf204d365/mac).
- [Photos for Mac: find and name people and pets](https://support.apple.com/guide/photos/phtad9d981ab/mac); [Photos sidebar and pinned collections](https://support.apple.com/guide/photos/phtf6b8c37c3/mac).
- [Apple press release, iLife '09 with iPhoto Faces and Places, 6 Jan 2009](https://www.apple.com/ie/newsroom/2009/01/06Apple-Introduces-iLife-09/).
- [Logic Pro Quick Help (Logic Pro 10.1 guide)](https://help.apple.com/logicpro/mac/10.1/en.lproj/lgcp2a07a994.html); [Logic Pro release notes](https://support.apple.com/109503).

Reporting and other sources:
- [MacRumors: all the Liquid Glass changes in macOS Golden Gate, 9 Jun 2026](https://www.macrumors.com/2026/06/09/macos-golden-gate-liquid-glass/).
- [TechCrunch: Apple says goodbye to the Clips app, 11 Oct 2025](https://techcrunch.com/2025/10/11/apple-says-goodbye-to-the-clips-app); [AppleInsider on Clips](https://appleinsider.com/articles/25/10/11/apple-clips-social-video-app-killed-after-eight-years).
- [Apple Creator Studio announced (Videomaker)](https://www.videomaker.com/news/apple-announces-apple-creator-studio-software-subscription/); [OWC on Creator Studio](https://www.owc.com/blog/apple-launches-apple-creator-studio-a-new-all-in-one-creative-subscription-taking-aim-at-adobe).
- [Macworld on iPhoto '09](https://www.macworld.com/article/1138598/iphoto09.html); [Wikipedia: iPhoto](https://en.wikipedia.org/wiki/IPhoto) (end of iPhoto, 2015).
- [Apple WWDC 2026, What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269); [Create with Swift newsletter 111](https://www.createwithswift.com/weekly-newsletter-issue-111/) (secondary, for `reorderable` and `sectionBy`).
- [Eclectic Light: How help works and how it doesn't (2023)](https://eclecticlight.co/2023/05/11/how-help-works-and-how-it-doesnt/); [Why won't that Help book open? (2021)](https://eclecticlight.co/2021/11/16/why-wont-that-help-book-open/); [Apple Help Programming Guide (archive)](https://developer.apple.com/library/mac/documentation/Carbon/Conceptual/ProvidingUserAssitAppleHelp/user_help_intro/user_assistance_intro.html).
- [YouTube recommended upload encoding settings](https://support.google.com/youtube/answer/1722171?hl=en).
- [swift-markdown](https://github.com/swiftlang/swift-markdown) (0.9.0, 21 Sep 2026, from the GitHub API).

Measured on this Mac (macOS 27.2, 10 Oct 2026): app versions and bundle identifiers from Info.plist
(Final Cut Pro 12.4 `com.apple.FinalCutApp`, Compressor 5.4, Pixelmator Pro 4.4, iMovie 10.4.5,
Keynote 15.4, DaVinci Resolve 20.2.1 `com.blackmagic-design.DaVinciResolve`); the welcome, What's New
and onboarding resources inside them; Tips.app as `com.apple.helpviewer`; `/usr/bin/hiutil`; every SF
Symbol named in this spec; the accent colors' contrast; the v1 screenshots in `screens/mac/finish/`
and `screens/mac/m6/real/`.

Project sources: `docs/v2/REQUEST.md`, `START_HERE.md` (Prakriti for Mac and its warnings),
`docs/BUILD-LOG.md` (Finish line), `docs/LOCAL-MODEL.md`, `research/03-apple-hig.md`,
`research/04-ui-patterns.md`, `mac/Prakriti/Views/*.swift`, `mac/Prakriti/Model/Vocabulary.swift`,
`mac/project.yml`.
