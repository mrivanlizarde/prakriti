# Builder notes: 08-editorial-direction.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/08-editorial-direction.md` ("Editorial direction").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M9c (Thu 15 Oct 2026)

- **The article is visible** (`requires: direction`, the capability part M9c switches on) and rewritten to the build: Direction
  sits in the inspector's Outputs above Edit plan until the Direction tab exists (M9d), with the field, the eight preset
  capsules of design spec 3.5.3, Pace (as in House Style, Relaxed, Balanced, Brisk) and Length (the design spec's four), the
  chips under "Read as" with an x each, Plan Again and Clear Direction; the plan's lines under Edit plan with Make Video; the
  same lines in the progress block while the video is made.
- **Removed from the old text because nothing builds them:** "Clean text on screen. Key ideas appear as short lines" (key
  phrases are M9d), the five-preset list (Highlights is now Length, About 3 minutes; Teaching is the Teaching Only capsule),
  "Use for This Folder" (not built; Settings, House Style is the default for every recording), and "reorder within a section"
  (the selection never reorders; the hook of M9d is the only move).
- **The example plan lines are real:** they are the lines the 13 Sep talk's plan printed for "Focus on the parts that are
  motivating or enlightening. Under 10 minutes." in `make accept-direction` (15 Oct). The chip example is Energetic at a faster
  pace ("pauses between sentences kept to 0.17 s"). A pace step shortens the kept pauses and never cuts more of them (Mac
  warning 169), which the article says in one sentence.
- "Bring in a moment from another recording" stays under `:::requires merge` (M12), unchanged.

## Status after v2 part M3a (Sun 11 Oct 2026)

- Only a hidden line changed: "on the Models screen" became "in Settings, Models".

## Status after v2 part M2a (Sun 11 Oct 2026)

- Whole article hidden (`requires: style`, M9); "Bring in a moment from another recording" inside
  `:::requires merge` (M12). The presets table is a list. Everything in it is still v2 intent, unchanged:
  M9 and M12 confirm or rewrite each line against the build.

## Notes from the help track (Sat 10 Oct 2026)

- **House style source.** REQUEST.md: "MKBHD as the template" means his editing grammar (tight jump
  cuts, punch-in zooms to hide cuts, clean kinetic type, restrained transitions, crisp audio, sharp
  pacing), never his brand. The help text does not name him on purpose: naming a creator in product
  help reads as an endorsement or affiliation, and the decision is to ship Prakriti's own style.
  Ivan may prefer to name the inspiration; his call.
- **Everything in this article is v2 intent and needs confirming against the build:** the Direction
  section, the five presets and their names, the free-text field, the plan shown before making, "Use
  for This Folder", "Moments From Other Recordings", Add and Remove, the on-screen date for an added
  moment.
- **Why the plan step.** A render takes minutes; a plan in one sentence lets Ivan correct a misread
  direction before paying the time. Recommended, not decided.
- **Why the date on screen.** Serenity's accuracy condition (anything public must be right,
  including the year). A moment from another day without a label can misstate when something was said.
- **Merge rule from Ivan:** "should be able to be added to the video at hand but not always and not
  as a rule." Hence suggestions only, nothing automatic.
- **Suggestions only from people who agreed:** finding related moments uses text embeddings of
  transcripts (nomic-embed-text in LM Studio), not biometrics, but matching "the same person" across
  recordings relies on named, agreed people only. Unnamed people are never matched across recordings
  (biometric rule).
- **"Calm" preset** exists because yin and slow classes are 31 to 41% silence by measurement
  (research/07 §1.3); the default tightening would destroy them.
