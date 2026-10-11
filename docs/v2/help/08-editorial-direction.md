---
id: editorial-direction
title: Editorial direction
summary: Steer the edit with presets and your own words, and bring in a moment from another recording when it helps.
keywords: [direction, edit, style, preset, energetic, calm, pace, cuts, zooms, text on screen, captions, motivating, shorter, make again, moment, another recording, merge, supporting]
related: [05-outputs, 06-reviewing-and-approving, 09-models-and-api-keys]
---

# Editorial direction

Prakriti edits every video in one house style. You can steer it: pick a preset, write what you want in
plain words, or both, then make it again.

## The house style

- **Tight.** Long pauses, filler words, false starts and repeated takes come out. The speaker's own
  pauses for breath and emphasis stay.
- **Zooms that hide cuts.** Where a cut would make the picture jump, the next shot is a little closer
  or a little wider, so the cut reads as a new angle.
- **Clean text on screen.** Key ideas appear as short lines of text, in the speaker's own words.
- **Few transitions.** Mostly straight cuts. A simple transition only between sections.
- **Clear sound.** Voices leveled and even, with nothing added under them.

Prakriti's look is its own. It does not use anyone else's logos, fonts, music or intros.

## Choose a preset

On a recording's page, under Direction, choose a preset:

| Preset | What changes |
|---|---|
| **Clear** | The house style. The starting point for every recording. |
| **Energetic** | A faster pace, more frequent cuts and zooms, more text on screen. |
| **Calm** | Longer shots, gentle zooms, fewer cuts. Pauses that let an idea land are kept. Suits meditation, breath work and slow classes. |
| **Teaching** | Demonstrations are kept whole and wide enough to show the whole body. Pose names and key cues appear on screen. |
| **Highlights** | Only the strongest moments, for a short version of a long recording. |

## Say what you want

Under Direction, type what you want in your own words. A few examples:

- "More energetic. Faster, more frequent cuts."
- "Focus on the parts that are motivating or enlightening."
- "Keep the breathing practice whole, with no zooms."
- "Take out the story about the car."
- "Under 12 minutes."
- "Fewer words on screen."

Then click Make Again. Before the video is made, Prakriti shows its plan in a sentence or two, such as
"Removes 4 minutes 10 seconds, adds 22 zooms and 6 lines of text, ends at 11:48." Click Make to go
ahead, or change the direction.

Direction works with what was recorded. It can shorten, reorder within a section, emphasize and
remove. It cannot add words nobody said, and text on screen always uses the speaker's own words.

**Tip:** To use a direction for every recording from a folder, click Use for This Folder under
Direction. To go back to the house style, choose Clear and delete the text.

## Bring in a moment from another recording

Sometimes a point made in one recording is supported by something the same person said in another.
Prakriti can find those moments. It never adds one on its own.

1. On the recording's page, click Moments From Other Recordings.
2. Prakriti lists moments where the same person makes a related point, each with its words, its
   recording and its date.
3. Play a moment to hear it. To use it, click Add and choose where it goes.
4. Click Make Again.

An added moment shows the date it was recorded on screen, so viewers know it comes from another day.
It follows the people choices of the recording it came from. To take it out, click Remove beside it.

Prakriti only suggests moments from recordings of people who have agreed to be recognized. See
[People and privacy](07-people-and-privacy.md).

## Who does the editing

The model you choose for editing on the Models screen reads the transcript and your direction, and
plans the edit. Everything else, including the cutting, zooming, blurring and the final video, happens
on this Mac. See [Models and API keys](09-models-and-api-keys.md).

## See also

- [Outputs](05-outputs.md)
- [Review and approve](06-reviewing-and-approving.md)
- [Models and API keys](09-models-and-api-keys.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

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
