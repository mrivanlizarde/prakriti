---
id: editorial-direction
title: Editorial direction
summary: Steer one recording's edit with presets, your own words, a pace and a length, and see the plan before anything is made.
keywords: [direction, edit, style, preset, energetic, calm, pace, cuts, zooms, punch-ins, motivating, enlightening, shorter, length, minutes, plan again, make video, chips, moment, another recording, merge, supporting]
section: direction
order: 1
requires: direction
related: [outputs, reviewing-and-approving, models-and-api-keys]
---

# Editorial direction

Every video starts from the house style you set in Settings, House Style. You can steer one recording
differently: pick presets, write what you want in plain words, choose a pace and a length, then plan it
and make it.

## Where to find it

Select a recording, then in the inspector's Outputs, under **Direction**:

- **Direction:** a field for your own words.
- **Presets:** Energetic, Calm, Faster Cuts, Fewer Cuts, Motivating, Enlightening, Story First and
  Teaching Only. Several can be on at once. Energetic and Calm switch each other off, and so do Faster
  Cuts and Fewer Cuts.
- **Pace:** as in House Style, Relaxed, Balanced or Brisk.
- **Length:** Everything that matters, About 20 minutes, About 10 minutes or About 3 minutes.

Nothing changes until you click **Plan Again**.

## Say what you want

Write what you want in your own words. A few examples:

- "More energetic. Faster, more frequent cuts."
- "Focus on the parts that are motivating or enlightening. Under 10 minutes."
- "Keep the breathing practice whole, with no zooms."
- "Take out the story about the car."
- "Calmer. Let it breathe."

The common phrases are read on this Mac as you type, the same way every time: faster or slower, calmer,
more energetic, more or fewer cuts, no zooms or more zooms, a length such as "under 10 minutes", and what
to focus on (motivating, enlightening, practical, stories, humor, philosophy, technique, personal).
Anything else is read by the model you choose for **Planning the edit** in Settings, Models, when you
plan. See [Models and API keys](09-models-and-api-keys.md).

Who appears in the video is never part of a direction. If you write about the students or about
blurring someone, Prakriti says "People are chosen under People." and changes nothing. Choose people in
the People tab. See [Privacy and students](07-people-and-privacy.md).

## Check what Prakriti understood

Under **Read as**, each thing your direction sets is shown on its own, for example "Style: Energetic",
"Pace: faster (pauses between sentences kept to 0.17 s)", "Length: at most 10 min" or "Focus: motivating and
enlightening". Click the small x on any of them to take it back out. If something you asked for is not
built yet, a line under them says so.

## The parts of the talk

A length, a focus, or something to take out or keep whole means Prakriti chooses among the parts of the
talk. The first time, the model reads the transcript and divides it into parts, each scored for how
motivating, enlightening, practical and so on it is. This takes a few minutes. The parts are kept beside
the plan, so after that a change of pace, length or focus is planned in seconds, without asking the
model again.

Prakriti then keeps the parts that best match your focus within the length, always keeps the talk's main
point and its close, keeps any part another kept part depends on, and never changes their order.

## See the plan, then make it

Click **Plan Again**. Under Edit plan, the plan is shown in plain lines before anything is made. For
"Focus on the parts that are motivating or enlightening. Under 10 minutes." on a 16-minute talk, for
example:

- Cuts pauses longer than 0.4 s inside a sentence and 0.6 s between sentences, down to 0.18 s and 0.35 s.
- Punch-ins about every 20 s, and 3 slow push-ins.
- Keeps 9 of 13 parts of the talk; leaves out 4 (5:29 of the recording).
- Keeps the story at 1:47.
- Ends at 9:52.

"Faster" makes the pauses that stay shorter; it does not cut more of them, because every extra cut is a
jump in the picture.

If it is right, click **Make Video** there. While the video is made, the same lines show in the progress
block, with Stop. If it is not right, change the direction and click Plan Again.

The direction works with what was recorded. It can shorten, choose and emphasize, but never adds words
nobody said or changes their order.

**Tip:** To go back to the house style for a recording, click **Clear Direction**.

:::requires merge
## Bring in a moment from another recording

Sometimes a point made in one recording is supported by something the same person said in another.
Prakriti can find those moments. It never adds one on its own.

1. In the inspector's Direction tab, click Moments From Other Recordings.
2. Prakriti lists moments where the same person makes a related point, each with its words, its
   recording and its date.
3. Play a moment to hear it. To use it, click Add and choose where it goes.
4. Click Make Again.

An added moment shows the date it was recorded on screen, so viewers know it comes from another day.
It follows the people choices of the recording it came from. To take it out, click Remove beside it.

Prakriti only suggests moments from recordings of people who have agreed to be recognized. See
[Privacy and students](07-people-and-privacy.md).
:::

## Who does the work

The model you choose for **Planning the edit** in Settings, Models reads the transcript to find its parts,
and reads any of your words the common phrases do not cover. Everything else, choosing the parts, the
cuts, the punch-ins and the video itself, happens on this Mac.
