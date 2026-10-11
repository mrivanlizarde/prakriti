# Builder notes: 09-models-and-api-keys.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/09-models-and-api-keys.md` ("Models and API keys").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

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
