---
id: models-and-api-keys
title: Models and API keys
summary: Which steps use a language model, how to choose one for your Mac, how to add a Claude API key, and what is sent.
section: settings
order: 1
keywords: [models, LM Studio, Qwen, Apple on-device, Apple Intelligence, Ollama, Anthropic, Claude API, API key, Keychain, memory, smaller Mac, This Mac, chip, hardware, privacy lock, names replaced, data retention, cost, writing, tagging, summarizing, tasks]
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
:::requires people
- Finding faces and voices, blurring faces and removing voices.
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
- **Claude API (Anthropic).** The model runs on Anthropic's computers, using your own API key. Fast on
  any Mac. Text is sent to Anthropic, as described below.
:::requires cloudProviders
- **OpenAI API.** The model runs on OpenAI's computers, using your own API key. Text is sent to OpenAI.
:::

## Which choice fits your Mac

Settings, Models shows your Mac's chip and memory under This Mac, with a verdict, such as "Apple M5 Pro,
64 GB. This Mac can run the writing model." [Show Me](prakriti://show/settings/models) It is a suggestion
only: Prakriti never switches to a cloud model by itself.

- **64 GB or more:** LM Studio for every task. Nothing leaves your Mac.
- **Less than 64 GB:** writing a long recording needs the Claude API, or it waits for a model on this
  Mac. Apple on-device can do tags and summaries.

Transcribing works on any Mac with Apple silicon. On a smaller Mac it takes longer.

## Add a Claude API key

### Get a key

Sign in at platform.claude.com, choose Settings > API keys, click Create key, and copy it. Anthropic
shows the key once. If you lose it, make a new one.

:::requires cloudProviders
For OpenAI, sign in at platform.openai.com, open API keys, click Create new secret key, and copy it. Add
a payment method under Billing first. A key does not work until the account has credit.
:::

### Add it to Prakriti

1. Choose Prakriti > Settings (Command-comma), then click Models. [Show Me](prakriti://show/settings/models)
2. Under Claude API, paste the key, then click Save in Keychain.
3. Click Test Claude API and read what it says.
4. Under Tasks, choose Claude API for the tasks you want it to do.

The key is kept in your login keychain, never in a file or in Prakriti's log. To remove it, click Remove
Key. To stop it working everywhere, delete it on Anthropic's site too.

## What is sent, and what is not

When a task uses the Claude API, Prakriti sends the transcript's lines, with their times, and the
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
It keeps requests for up to 30 days to watch for misuse.
:::

Read the company's current policy before you rely on it.

## Cost

Anthropic bills you for each request, by how much text is read and written. A longer recording costs
more. Set a monthly spending limit in your account on Anthropic's site.
