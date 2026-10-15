# Builder notes: 09-models-and-api-keys.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/09-models-and-api-keys.md` ("Models and API keys").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3a (Sun 11 Oct 2026)

- The Models screen is Settings, Models (Command-comma); Show Me `settings/models`. The lock's last line says the
  page and the inspector's Checks say so.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Visible: v1's four providers and three tasks (Writing, Tagging, Summarizing), the Claude API key steps
  (Save in Keychain, Test Claude API, Remove Key), what is sent (the transcript's lines and the task's
  instructions), the v1 privacy lock, Anthropic's retention. Gated: OpenAI everywhere (`cloudProviders`),
  planning the edit (`style`), finding moments (`merge`), face and video work (`people`, `video`).
- Tables are lists. The "less than 64 GB" line names the Claude API only until OpenAI is built.

## Notes from the help track (Sat 10 Oct 2026)

### Grounded in measurements and code

- LM Studio with Qwen3.8-27B (8-bit MLX), loaded by Prakriti at 65,536 tokens and unloaded after:
  process about 33 to 36 GB, whole-system peaks of 51 to 54 GB measured; writing a 15:48 talk took
  10 min 3 s to 14 min 25 s for the whole step (docs/LOCAL-MODEL.md). Hence "64 GB or more" as the
  comfortable line. A 32 GB Mac might run a 4-bit build or a smaller model `[unverified quality and
  fit]`; the table does not promise it.
- v1 names: "LM Studio", "Apple on-device", "Ollama", "Claude API", "Save in Keychain", "Remove
  Key", "Test LM Studio" and so on; Keychain service `studio.therowan.prakriti.app.claude-api`. v2
  adds "OpenAI API" (Ivan's item 5). Tasks in v1: Writing, Tagging, Summarizing. v2 adds planning
  the edit and finding moments; name them to match the build.
- Recordings longer than about two hours are refused for writing, never cut off (BUILD-LOG). Not
  in the user text; add to troubleshooting if it shows up in practice.

### The privacy lock (decision and a gap to raise)

- REQUEST.md relaxes v1's lock: "mentions Serenity" no longer forces local models; classes and
  recordings where other people appear or speak still do. v1's Models screen text still says
  "anything with Serenity in it"; that copy must change with the code.
- **Gap.** On a Mac under 64 GB the cloud key is the whole point, but the lock forbids it for every
  class. Apple's on-device model has a small context (historically 4,096 tokens; a new model in the
  2026 OS releases adds APIs to read the real size) and cannot plan the edit of a one-hour class. So
  on a small Mac, classes get no titles, notes or editorial plan. This article says "the step waits
  and the page tells you why". The product question for Ivan: is that acceptable, or should a class
  be sendable after Prakriti has removed every unnamed voice and every student name from the text?
  That would be a privacy decision for Serenity, not a technical one.

### Verification notes

- Apple Intelligence: "Mac with M1 or later" (plus MacBook Neo), macOS 27 Golden Gate, up to 8 or
  14 GB of storage: https://support.apple.com/en-us/121115 (checked 10 Oct 2026).
- Apple on-device context: 4,096 tokens per an Apple Developer Forums answer; WWDC 2026 session 241
  describes a new on-device model and context-size APIs (https://developer.apple.com/videos/play/wwdc2026/241)
  `[unverified current size]`.
- LM Studio system requirements: Apple silicon, macOS 14.0 or newer, 16 GB+ recommended:
  https://lmstudio.ai/docs/app/system-requirements
- OpenAI API data: "not used to train or improve OpenAI models" unless you opt in; abuse monitoring
  logs "retained for up to 30 days"; Responses API application state 30 days by default; ZDR by
  approval: https://developers.openai.com/api/docs/guides/your-data (checked 10 Oct 2026).
- Anthropic: commercial inputs and outputs deleted "within 30 days of receipt or generation";
  flagged usage-policy violations up to 2 years (classification scores up to 7 years); feedback 5
  years; last updated 1 Jul 2026: https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data .
  Not used for training by default for commercial products, last updated 18 Aug 2026:
  https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training . A Reuters
  report (Aug 2026) says Anthropic plans to keep the 30-day requirement but let business customers
  hold the data in their own cloud `[unverified plan]`. Some newer Anthropic models carry their own
  retention terms ("Covered Models") `[unverified which]`.
- Getting keys: Anthropic Console at platform.claude.com, Settings > API keys, key shown once:
  https://platform.claude.com/docs/en/get-api-key . OpenAI at platform.openai.com/api-keys, billing
  required, key shown once (third-party guides; OpenAI's own UI wording `[unverified]`):
  https://apideck.com/blog/how-to-get-your-chatgpt-openai-api-key
- Costs: deliberately no number. Per-token prices change and depend on the model chosen. If the
  build shows an estimate before sending, add a line here.

## Built in v2 part M5a (Mon 12 Oct 2026)

- The privacy lock is `PrivacyLock` (mac/Prakriti/Writing/PrivacyLock.swift). A cloud model reads only a talk whose
  people check ran, with no one unnamed and everyone heard named and agreed (`Person.mayReadInCloud`, off by
  default), and whose transcript does not name Serenity. The people check is part M6, so every real recording is
  locked today ("Who appears and speaks in it has not been checked, so only models on this Mac read it.").
- Every cloud request goes through `PrivacyLock.release`: names Apple's tagger finds are replaced by [[NAME-n]] and
  put back in the answer; muted names, named people who have not agreed and Serenity are always replaced (the tagger
  missed "Serenity" in the writing prompt when measured); the text is read again and refused if a name is left.
- Settings, Models has "This Mac": the chip, memory and verdict ("Apple M5 Pro, 64 GB. This Mac can run the writing
  model."), and Apple Intelligence's state. The welcome panel 5 line is part M5b's.
- Not built: OpenAI, Anthropic's current request shape, model lists from each provider (M5b); the people check (M6).

## Built in v2 part M5b (Mon 12 Oct 2026)

- Providers are named Anthropic and OpenAI in the app (the stored value for Anthropic is still `claudeAPI`, and its
  Keychain item keeps v1's service name, so an existing key is still found). OpenAI's key is its own item,
  `studio.therowan.prakriti.app.openai-api`.
- Each key row: a field and Save in Keychain; once saved only "Saved in your Keychain." with Remove Key; refused (401
  or 403) shows "Anthropic did not accept this key. Check it and save it again." with the field back.
- Model pop-ups are filled from each provider's `GET /v1/models` when a key is saved or the pane opens, and Read the
  List Again. Anthropic keeps only models whose `capabilities.effort.supported` is true; OpenAI's list is filtered by
  name to text models. Anthropic's default is Claude Sonnet 5.5 (Ivan, 12 Oct).
- Costs: the article now says that the Anthropic test and each writing step's log line show what the call cost
  (from tokens and the published prices in `CloudPricing`). OpenAI calls show tokens only.
- Tasks lists Planning the edit and Choosing moments, greyed with "Not built yet." The article still lists them only
  under `:::requires style` and `:::requires merge`.
- Welcome panel 5 has "Choose where models write." with this Mac's verdict and Open Settings, Models.

## Changed in part LOCK (Wed 14 Oct 2026)

- Ivan's decision of Mon 12 Oct: every participant signed a release covering their likeness for commercial use. The
  lock no longer reads the kind of recording, the people check, unnamed people or "Serenity" in a transcript. The
  provider chosen for each task (the Claude API by default) reads every recording, unless someone in it is set to
  Leave Out (any output) or a named person in it, seen or heard, has "Signed release on file" turned off in
  Settings, Privacy (`Person.noRelease`, off for everyone). The Checks line names no one: "Someone in it is set to
  Leave Out, so only models on this Mac read it." or "Someone in it has no signed release on file, so ...".
- `PrivacyLock.release` now replaces only muted names and the names of people marked no release (each whole name and
  each word of three letters or more), and refuses if one is left. Names said aloud otherwise go as they are.
- Names said aloud are kept unless Ivan chooses Mute; Approve never asks about them.
- `Person.mayReadInCloud` and its switch "Cloud models may read their words" are retired (the stored field is kept so
  older stores open unchanged).

## Notes from part M8c (Wed 14 Oct 2026)

- "Cutting, zooming and making the video" moved from `requires video` to `requires style`: zooms are M9.

## Notes from part M9a (Wed 14 Oct 2026)

- "Cutting, zooming and making the video" (`style`) became "Choosing where the picture punches in and pushes in" under
  `houseStyle`: the visual plan is code on this Mac (`VisualPlan`), no model. "Planning the edit from your direction" stays
  `style` (M9c asks a model for beats).

## Status after v2 part M9c (Thu 15 Oct 2026)

- "Planning the edit" moved from `style` to `direction` and says what it does as built: the beats once per transcript when a
  direction chooses among parts, and the words of a direction no rule reads; a recording with no direction asks nothing; until
  Ivan chooses, it uses the Writing task's choice (`AppSettings`, so his 12 Oct move to Anthropic carries).
- New line under "These always run on this Mac" (`direction`): the rules table, the choice of parts under a length, the plan.

## Status after v2 part M9d (Thu 15 Oct 2026)

- Planning the edit now reads the parts of the talk for every video (once, kept beside the plan), not only for a directed one; the
  M9c sentence "A recording with no direction never asks it anything" is kept only under `unless style`.
