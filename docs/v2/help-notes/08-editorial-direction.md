# Builder notes: 08-editorial-direction.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/08-editorial-direction.md` ("Editorial direction").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

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
