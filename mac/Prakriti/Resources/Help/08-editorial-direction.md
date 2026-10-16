---
id: editorial-direction
title: Editorial direction
summary: Steer one recording's edit with presets, your own words, a pace and a length, and see the plan before anything is made.
keywords: [direction, edit, style, preset, energetic, calm, pace, cuts, zooms, punch-ins, motivating, enlightening, shorter, length, minutes, plan again, make video, make again, chips, versions, version, use this version, play, opening line, hook, key phrases, terms, chapters, held moment, moment, another recording, merge, supporting, supporting moments, find supporting moments, choosing moments]
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

Select a recording, then click **Direction** in the inspector (the wand, the third of the five tabs, or
Command-Option-3):

- **Direction:** a field for your own words.
- **Presets:** Energetic, Calm, Faster Cuts, Fewer Cuts, Motivating, Enlightening, Story First and
  Teaching Only. Several can be on at once. Energetic and Calm switch each other off, and so do Faster
  Cuts and Fewer Cuts.
- **Pace:** as in House Style, Relaxed, Balanced or Brisk.
- **Length:** Everything that matters, About 20 minutes, About 10 minutes or About 3 minutes.

:::requires shorts
Under it, **Shorts** sets how many shorts the next make cuts, from none to 5, and how long each may be:
up to 30, 45 or 60 seconds. They are chosen from the parts of the talk, starting on each part's
strongest line, and do not change the plan.
:::

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
point and its close, keeps any part another kept part depends on, and never changes their order. When
what fits comes out well short of the length, a longer part takes the place of shorter ones.

## See the plan, then make it

Click **Plan Again**. Under **The plan**, the plan is shown in plain lines before anything is made. For
"Focus on the parts that are motivating or enlightening. Under 10 minutes." on a 16-minute talk, for
example:

- Cuts pauses longer than 0.4 s inside a sentence and 0.6 s between sentences, down to 0.18 s and 0.35 s.
- Punch-ins about every 20 s, and 3 slow push-ins.
- Keeps 9 of 13 parts of the talk; leaves out 4 (5:29 of the recording).
- Keeps the story at 1:47.
- Ends at 9:52.

"Faster" makes the pauses that stay shorter; it does not cut more of them, because every extra cut is a
jump in the picture.

If it is right, click **Make Again** there (**Make Video** the first time). While the video is made, the
same lines show in the progress block, with Stop. If it is not right, change the direction and click
Plan Again.

The direction works with what was recorded. It can shorten, choose and emphasize, but never adds words
nobody said. The one line it moves is the opening line, below, and that line is also left in its place.

:::requires style
## What the house style adds from the parts of the talk

Every video is planned from the parts of the talk, not only a directed one. The first time, the model
you choose for Planning the edit reads the transcript; after that the parts are kept beside the plan.
From them, in the house style:

- **The opening line.** The video opens on the talk's strongest line, then the title, then the talk
  from its start. The line is whole sentences or whole clauses, 5 to 15 seconds in Clear (3 to 8 in Energetic, 10 to 20
  in Story, none in Calm), the speaker's own words exactly as the talk keeps them. It is never from the
  talk's first 30 seconds, and never a line that names money, a price or an offer.
- **Key phrases.** 2 to 6 of the speaker's own words, on the side of the picture away from the
  teacher and never over a face, the moment they are said. The words come in one after another. Clear
  shows at most one every 60 to 90 seconds; Energetic one every 20 to 40.
- **Terms.** A Sanskrit term the talk explains, spelled as the Yoga Marga word list spells it, once,
  near the bottom of the picture. A term the list does not hold is never shown.
- **The held moment.** About 30 to 60 seconds of the talk's main point are kept exactly as recorded,
  every pause and every word, as one still, wide shot with nothing over it. Energetic has none.
- **Chapters.** One for each part of the talk the video keeps, the first at 0:00, each at least 30
  seconds, in `Description.txt` for YouTube.

Turn any of them off in Settings, House Style: Open on the strongest line, Key phrases (Off, Subtle or
Bold) and Terms. If the parts of the talk cannot be read (no model is set, or it does not answer), the
video is made without them and the plan says why.

## Versions

Each time a video is made, it is kept as a version. Under **Versions**, newest first, each shows its
number, what made it, when, and how long it is, for example "Version 2. Energetic, “More energetic.
Faster, more frequent cuts.” Made Thu 15 Oct, 9:41 pm. 14:38 long."

- **Play** plays that version in the viewer on Video, drawn the same way as its file.
- **Use This Version** puts that version's video and plan back in the recording's folder. Nothing is
  made again.
- Approve covers the version in use, and says which one. The receipt names it too.

Prakriti keeps the five newest versions. They are copies that take no extra space until one changes.
:::

**Tip:** To go back to the house style for a recording, click **Clear Direction**.

:::requires moments
## Find a moment from another recording

Sometimes a point made in one recording is supported by something the same teacher said in another.
Prakriti can find those moments for you. It never adds one on its own.

1. Choose who is teaching the recording in Info, if you have not yet.
2. In the inspector's Direction tab, under Supporting Moments, click **Find Supporting Moments...**.
   Prakriti looks for moments that support this recording's main points, which it reads from the parts
   of the talk, so plan the edit first if it has not read them. Or select words in the transcript,
   Control-click, and choose **Find Supporting Moments for This...**. The Recording menu has it too.
3. A sheet shows up to three moments. Each has its recording and date, its exact words and how long it
   is, one plain sentence saying how it relates to the point, and where it would go in this recording.
   Click **Play** to hear it, or **Not This One** to set it aside.

How Prakriti finds them: it divides the transcripts of the teacher's other recordings into stretches of
whole sentences, 5 to 45 seconds each, and compares their meaning with the point on this Mac, with the
text-embedding-nomic-embed-text-v1.5 model in LM Studio. What it works out is kept in an index on this
Mac, as times and numbers, not words. The closest stretches are then read by the model you choose for
**Choosing moments** in Settings, Models, which says in one sentence whether each supports the point
without contradicting it. See [Models and API keys](09-models-and-api-keys.md).

Where Prakriti looks: only in other recordings of the same teacher whose people it has checked, and
only in stretches where everyone seen or heard is set to Include and has a signed release on file. A
stretch with someone you set to Hide Face or Leave Out is never offered, even if you change it after a
search. If nothing fits, the sheet says so, with the number of recordings it searched.

LM Studio must be open with text-embedding-nomic-embed-text-v1.5 downloaded, because the comparing
always happens on this Mac.
:::

:::requires merge
## Add a moment to the video

To use a moment you found, click Add and choose where it goes, then click Make Again. An added moment
shows the date it was recorded on screen, so viewers know it comes from another day. It follows the
people choices of the recording it came from. To take it out, click Remove beside it.
:::

## Who does the work

The model you choose for **Planning the edit** in Settings, Models reads the transcript to find its parts,
and reads any of your words the common phrases do not cover. It also picks the strongest lines and the
few words for the screen, which Prakriti then checks word for word against the transcript. Everything else, choosing the parts, the
cuts, the punch-ins and the video itself, happens on this Mac.
