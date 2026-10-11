---
id: welcome-panels
title: Welcome panels
summary: The exact copy for the welcome screens shown at first launch, with buttons, symbols and behavior.
keywords: [welcome, onboarding, first launch, startup screen, tips]
related: [01-welcome, 02-capture-the-best-video]
---

# Welcome panels

## Status after v2 part M2b (Sun 11 Oct 2026)

This file was the copy source. **The build's words are in `mac/Prakriti/Views/Welcome/WelcomeContent.swift`**,
and the copy below is history: it was written before the build, for v2 as planned.

- **Structure taken from the design spec (4.1, 4.2), not from this file,** as docs/v2/PLAN.md section 5
  (item 4) decided: five panels titled Welcome to Prakriti, Record for the Best Results, How Outputs Work,
  Privacy and Get Started; a 48 pt symbol, a 28 pt title, one 17 pt line, rows of a 28 pt symbol beside a
  17 pt semibold headline and a 17 pt sentence (read as one paragraph so six rows fit); "1 of 5" in words,
  not dots; Back and Continue, the last button Start Using Prakriti; Return, Command-Left, Escape. No Skip
  button: the close button and Escape close it, and closing counts as seen.
- **Taken from this file where it was shorter or truer:** the 10-second test with headphones (panel 2's
  sixth row, in place of the design spec's "leave a few seconds at each end", which the spec marked
  unverified and v1's silence trim covers); "Hybrid MP4, never MKV" (and Hybrid MOV with the capture check,
  M4b, as PLAN section 5 fixed it); Help, Welcome to Prakriti; the notification ask on the last panel.
- **What a reader sees at M2b,** each row true of v1 with the podcast-ready episode:
  - Panel 1: finds your recordings; makes the podcast episode; nothing is posted without you (you
    listen, then approve).
  - Panel 2: six capture rows; "vertical clips", the blur sentence and Hybrid MOV wait for their parts.
  - Panel 3: three steps (found and made, or Ask me first; listen, trim and cut, Make Again; Approve
    copies to the Approved folder with a receipt). People and Direction join as steps 3 and 4 with M6 and
    M9; the Viewer and the upload checklist replace steps 2 and 5 with M3b and M8, and M11b.
  - Panel 4: only a talk with one teacher speaking can be approved and a class is never made ready;
    notices never show a file name or a title; recordings never leave the Mac, and with a Claude API key
    only words are sent, never from a class or a recording that names Serenity (v1's lock). The blur,
    "remembered only if agreed" and the Anthropic or OpenAI rows wait for M6, M7 and M5b.
  - Panel 5: Choose a folder to watch (Choose Folder..., then "Added <name>. It is set to Ask me first.",
    or the refusal); Get a notice (Turn On Notifications when never asked; Open Notification Settings...
    when off, which opens System Settings at Prakriti's own page; "On." when on); Find help (Open Help).
    "Choose where models run" joins with M5b (the hardware check's verdict line is M5a).
- **How a later part changes it:** every row names its capabilities (`requires`, and `unless` for a
  sentence true only until a part lands, with its `-v2` twin beside it). The part that switches a
  capability on reads every row naming it, makes each sentence true of what it built, and runs
  `WelcomeTests`, which walk every stage of the build. M13 writes the final copy.
- **Measured:** every panel fits 720 by 600 pt at 17 pt; panel 2 needs 530 pt today and 570 pt with every
  part built; the window is 720 by 632 pt with its hidden title bar's band.

Five panels, shown once, at the first launch. Each has a headline of five words or fewer and a body of
under 40 words. Copy is final unless the build renames a feature.

## Panel 1

- **Symbol:** `film.stack`
- **Headline:** From recording to ready
- **Body:** Prakriti watches your recording folders. When a session arrives, it checks the sound, writes
  the transcript and makes what you chose: a podcast episode, an edited video, captions, thumbnails and
  a timeline to finish by hand.
- **Buttons:** Continue

## Panel 2

- **Symbol:** `camera.aperture`
- **Headline:** Record it well
- **Body:** Face the light. Put the lens at eye level. Record 4K if you can. Give each person a
  microphone on its own track. Record 10 seconds and play it back before you begin.
- **Buttons:** Capture Tips (opens Help: Capture the best video), Continue

## Panel 3

- **Symbol:** `person.2.crop.square.stack`
- **Headline:** You choose who appears
- **Body:** Prakriti finds every face and voice. People you name, who have agreed, can appear. Everyone
  else is blurred and their speech taken out. Only the people who agreed are remembered.
- **Buttons:** Continue

## Panel 4

- **Symbol:** `text.bubble`
- **Headline:** Steer the edit with words
- **Body:** Watch every output in the viewer. Then say what you want: more energetic, calmer, shorter,
  focused on what inspires. Prakriti shows its plan, then makes it again.
- **Buttons:** Continue

## Panel 5

- **Symbol:** `checkmark.seal`
- **Headline:** Nothing goes out without you
- **Body:** When you approve, Prakriti copies the finished files to your Approved folder with a
  receipt. It never uploads or posts. Turn on notifications to know when a recording is ready for your
  yes.
- **Buttons:** Turn On Notifications (default), Not Now

After either button on panel 5, the panels close and the main window opens on Today.

## Behavior

- Show once, at the first launch, after the main window has appeared. Never at later launches.
- **Skip** is always visible (top right of each panel, or press Escape) and closes the panels.
- Back and Continue move between panels. Small dots under the body show where you are.
- **Turn On Notifications** asks macOS for permission. macOS shows its own alert; the panel says why
  first, so the alert is expected.
- To show the panels again, choose Help > Welcome to Prakriti.
- Later tips belong next to the control they explain, not in these panels. Show each once.

## Alternative: one sheet

If a single Apple-style welcome sheet fits the design better than five panels, use the same symbols
and headlines as rows, each with one short line, under the title "Welcome to Prakriti":

| Symbol | Row title | Row line |
|---|---|---|
| `film.stack` | From recording to ready | Recordings in your folders become finished episodes, videos and captions. |
| `camera.aperture` | Record it well | Good light, eye-level framing and one microphone per person. |
| `person.2.crop.square.stack` | You choose who appears | Everyone you have not named is blurred and their speech taken out. |
| `text.bubble` | Steer the edit with words | Say what you want, see the plan, make it again. |
| `checkmark.seal` | Nothing goes out without you | You approve. Prakriti never uploads or posts. |

Buttons: Capture Tips, Continue. Ask for notifications on the next screen, with its own line of why.

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

### Counts (checked by script)

| Panel | Headline words | Body words |
|---|---|---|
| 1 | 4 | 36 |
| 2 | 3 | 33 |
| 3 | 4 | 30 |
| 4 | 5 | 27 |
| 5 | 5 | 33 |

### Why this shape

- Apple's HIG on onboarding: "design a flow that's fast, fun, and optional"; occurs after launching
  is complete; a skipped tutorial is not shown again but stays easy to find "in a help, account, or
  settings area"; "consider providing a collection of context-specific tips instead of a single
  onboarding flow"; and if the app needs a permission to function, "consider integrating the
  permission request into your onboarding flow" so you can show why. Source:
  https://developer.apple.com/design/human-interface-guidelines/onboarding (change log: 10 Jun 2024),
  read 10 Oct 2026.
- **The notification ask is the most valuable panel.** v1's finish line found notifications off for
  Prakriti and no banner was ever seen on screen (BUILD-LOG, "What does not work"). A silent class
  would show only in Today. Asking with a reason, at onboarding, is HIG-endorsed.
- **Contextual tips** after the panels: TipKit (macOS 14+) shows a tip once beside its control.
  Candidates: the first time a recording has Unnamed people ("Everyone you have not named starts
  blurred"), the first time Direction is shown, the first time a timeline is made ("Open it in Final
  Cut Pro with File > Import > XML").
- All five symbols were checked to exist with `NSImage(systemSymbolName:)` on this Mac (macOS 27.2).
- Copy rules: no em or en dashes, no "we", sentence case for headlines as Apple's welcome sheets
  use; button titles in title case as macOS buttons are.
- Panel 2's "Record 4K if you can" and panel 4's "shows its plan" depend on v2 features (4K-aware
  zooms, the plan step in Direction). If the plan step is not built, panel 4's last sentence becomes
  "Then make it again."
