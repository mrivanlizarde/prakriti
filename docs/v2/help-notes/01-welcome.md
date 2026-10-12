# Builder notes: 01-welcome.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/01-welcome.md` ("What Prakriti does").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3b (Mon 12 Oct 2026)

- v1's recording page was retired with the Viewer: every line that sent Ivan to "the recording's page"
  now names the viewer or the inspector's tab that holds the same thing.

## Status after v2 part M3a (Sun 11 Oct 2026)

- Step 3 names In Progress (v1's Today is gone); step 4 opens the recording by double-clicking it (v1's
  page is unchanged until the Viewer, M3b). "Start here" reaches notifications through Prakriti >
  Settings, General (the Settings window, Command-comma) with Show Me `settings/general`, and says
  "waiting for your yes" (design spec C1). The Tip adds Settings, General, Show the Welcome Window Again.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Title changed from "Welcome to Prakriti" to **"What Prakriti does"** (DS 5.7's title for `welcome`), because
  "Welcome to Prakriti" is the name of M2b's Help menu item and welcome window, and the Help test forbids it
  until the `welcome` capability is built.
- Visible today: v1's outputs (podcast episode, podcast-ready episode, transcript, titles and notes), the
  five steps as v1 does them (the recording page, trim and cut, Approve), the v1 privacy lock (class, or
  "Serenity" in the transcript), notifications through Settings, Open Notification Settings (Show Me).
- Gated: `video` (the v2 intro sentence), `people` (no face or voice kept), `welcome` (the Tip).
- The notification steps now go through the app's own Settings screen (Open Notification Settings), not
  System Settings' wording, which was `[unverified on macOS 27]`.
- Keywords to add later: viewer, faces, people, edited video (with their capabilities).

## Notes from the help track (Sat 10 Oct 2026)

- **Assumes these v2 names and places:** the viewer on the recording's page; "Help > Welcome to
  Prakriti" reopens the welcome panels (Apple HIG: a skipped tutorial must be easy to find later, for
  example in a help area); Today and the recording page show per-step progress with time left
  (Ivan's item 6). Rename here if the build uses different words.
- **"It never sends a class, or any recording where other people appear or speak, to a model outside
  your Mac"** is REQUEST.md's relaxed privacy lock (mentions of Serenity no longer force local).
  v1's lock still includes "transcript says Serenity" (`Writer.swift`); this line is true of v1 too.
- **Notifications:** v1's finish line found macOS had notifications off for Prakriti and no banner was
  ever seen. The welcome panels ask for permission (see welcome-panels.md), and this page repeats the
  manual path. The System Settings path is from BUILD-LOG ("System Settings, Notifications, Prakriti:
  Allow notifications") `[unverified on macOS 27 wording]`.
- Five steps mirror SCOPE's life of a recording; the "flagged the same day" line is the 14 Sep silent
  class lesson (`Pipeline.swift`: loudest point at or below -60 dB, Needs a decision, nothing made).

## Status after v2 part M2b (Sun 11 Oct 2026)

- The `welcome` capability is built: the Tip at the end shows, rewritten to what was built ("The welcome
  window opens once by itself. To see it again, choose Help > Welcome to Prakriti. Its last panel can
  choose a folder to watch and turn on notifications."). Keywords gained "welcome window" and "first launch".
- "Start here" step 3 now ends "then turn on Allow notifications": Open Notification Settings opens
  System Settings at Prakriti's own page since M2b (measured on macOS 27.2), where that switch is.
