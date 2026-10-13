---
id: models-and-api-keys
title: Models and API keys
summary: Which steps use a language model, how to choose one for your Mac, how to add an Anthropic or OpenAI key, and what is sent.
section: settings
order: 1
keywords: [models, LM Studio, Qwen, Apple on-device, Apple Intelligence, Ollama, Anthropic, Claude, Claude API, OpenAI, GPT, API key, model list, Keychain, memory, smaller Mac, This Mac, chip, hardware, privacy lock, names replaced, data retention, cost, writing, tagging, summarizing, tasks]
related: [people-and-privacy, outputs, troubleshooting]
---

# Models and API keys

A few of Prakriti's steps use a language model: a program that reads the transcript and writes. You
choose which model does each of these tasks in Settings, Models (Command-comma). Everything else always
runs on this Mac. [Show Me](prakriti://show/settings/models)

## What uses a model, and what never does

These tasks use the model you choose:

- **Writing:** titles, show notes and chapters, and the episode text of the podcast-ready episode.
- **Tagging:** topics and terms for each recording.
- **Summarizing:** a short summary, in the show notes.
:::requires style
- **Planning the edit** from your direction.
:::
:::requires merge
- **Finding related moments** in other recordings.
:::

These always run on this Mac, whatever you choose:

- Transcribing the words.
- Mastering the sound and measuring it.
- Checking every chapter time and every quote against the transcript.
:::requires voices
- Finding faces and voices.
:::
:::requires choices
- Leaving out the voices you choose, muting names, and listening to the episode again to check.
:::
:::requires hiding
- Hiding faces in the pictures of a recording.
:::
:::requires video
- Cutting, zooming and making the video.
:::

## The choices

- **LM Studio, on this Mac.** The standard choice. Prakriti loads its recommended model, Qwen3.8-27B,
  when it needs it and unloads it after. Nothing leaves your Mac. The model uses about 33 GB of memory
  while it works, and writing a 15-minute talk takes about 10 to 15 minutes.
- **Apple on-device.** Built into macOS with Apple Intelligence, on Macs with Apple silicon. Nothing
  leaves your Mac. It reads a few thousand words at once, so it suits tags and summaries: a long
  transcript is read in parts for those, and is too long for writing.
- **Ollama, on this Mac.** Another way to run models locally, if you already use it. Name a model
  Ollama has downloaded to use it.
- **Anthropic.** Claude runs on Anthropic's computers, using your own API key. Fast on any Mac. Text is
  sent to Anthropic, as described below. Claude Sonnet 5.5 is chosen at first: it costs less per call.
  Claude Opus 5.5 is more careful and costs about twice as much.
- **OpenAI.** The model runs on OpenAI's computers, using your own API key. Text is sent to OpenAI.

For Anthropic and OpenAI, the Model pop-up lists the models from the company's own list that work with
Prakriti, read when you save a key. Click Read the List Again when a new model comes out.

## Which choice fits your Mac

Settings, Models shows your Mac's chip and memory under This Mac, with a verdict, such as "Apple M5 Pro,
64 GB. This Mac can run the writing model." [Show Me](prakriti://show/settings/models) It is a suggestion
only: Prakriti never switches to a cloud model by itself.

- **64 GB or more:** LM Studio for every task. Nothing leaves your Mac.
- **Less than 64 GB:** writing a long recording needs an Anthropic or OpenAI key, or it waits for a
  model on this Mac. Apple on-device can do tags and summaries.

Transcribing works on any Mac with Apple silicon. On a smaller Mac it takes longer.

## Add an Anthropic or OpenAI key

### Get a key

For Anthropic, sign in at platform.claude.com, choose Settings > API keys, click Create key, and copy it.
Anthropic shows the key once. If you lose it, make a new one.

For OpenAI, sign in at platform.openai.com, open API keys, click Create new secret key, and copy it. Add
a payment method under Billing first. A key does not work until the account has credit.

### Add it to Prakriti

1. Choose Prakriti > Settings (Command-comma), then click Models. [Show Me](prakriti://show/settings/models)
2. Under Anthropic or OpenAI, paste the key, then click Save in Keychain. The key row then says "Saved in
   your Keychain", and the Model pop-up fills with the company's models.
3. Choose a model, then click Test Anthropic or Test OpenAI and read what it says. The test sends one
   short sentence, never a recording, and for Anthropic it shows what the call cost.
4. Under Tasks, choose Anthropic or OpenAI for the tasks you want it to do.

If the company refuses the key, the key row says so, for example "Anthropic did not accept this key.
Check it and save it again." Paste a new one in its place.

The key is kept in your login keychain, never in a file or in Prakriti's log, and is never shown again
after you save it. To remove it, click Remove Key. To stop it working everywhere, delete it on the
company's site too.

## What is sent, and what is not

When a task uses Anthropic or OpenAI, Prakriti sends the transcript's lines, with their times, and the
instructions for the task. It never sends sound, video or pictures.

**The privacy lock.** A cloud model reads only a talk in which everyone heard is named and has agreed to
cloud models, and nobody else appears or speaks. Classes, and recordings where other people appear or
speak, are only read by models on this Mac, whatever Settings, Models says. Prakriti does not check who
appears and speaks yet, so for now every recording is only read on this Mac. LM Studio does those tasks
instead, and the inspector's Checks tab says why. Nothing is sent.

**Before anything is sent,** Prakriti replaces the names of people in the text with stand-ins such as
[[NAME-1]], and puts them back in the answer. Then it reads the text again, and if it still finds a name
it should have replaced, it sends nothing and says so in the log, without the text.

### What Anthropic keeps

As Anthropic describes its API, as of October 2026: it does not use what you send through its API to
train its models by default. It deletes requests within 30 days, but can keep them for up to 2 years if
they are flagged for breaking its usage policy, and keeps anything you send as feedback for longer.

:::requires cloudProviders
OpenAI does not use what you send through the API to train its models unless you choose to share it.
It keeps requests for up to 30 days to watch for misuse. Prakriti asks OpenAI not to store the answer
for later use.
:::

Read the company's current policy before you rely on it.

## Cost

Anthropic and OpenAI bill you for each request, by how much text is read and written. A longer
recording costs more. Prakriti shows what each Anthropic call cost, in the test's line and in the log,
so you can compare Claude Sonnet 5.5 with Claude Opus 5.5. Set a monthly spending limit in your account
on each company's site.
