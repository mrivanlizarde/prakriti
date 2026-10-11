# The local writing model: Qwen3.8-27B in LM Studio

Chosen 2026-10-10 by a researcher and an adversarial skeptic (both agreed); existence, size and
license confirmed on Hugging Face the same day.

| | |
|---|---|
| Model | Qwen3.8-27B (Alibaba Qwen, released 14 Aug 2026, Apache 2.0) |
| Build | `lmstudio-community/Qwen3.8-27B-MLX-8bit`, 29.5 GB. **Pick 8-bit; LM Studio's default is the 4-bit build** |
| Why | Strongest model that fits a 64 GB M5 Pro: Artificial Analysis Intelligence Index 34 vs 15 to 18 for the rest of its class; best long-document reasoning (AA-LCR 82%) and least fabrication (AA-Omniscience -10) in class |
| Runner-up | Gemma 4 31B, MLX 8-bit (~33 GB): writing preferred by people on Arena, but it invents far more |
| Speed | ~10 tok/s writing, ~300 to 500 tok/s reading; a 20k-token transcript reads in 1 to 1.5 min |

## Load-bearing settings, each with its reason

1. **Load at a 65,536-token context, never the default.** LM Studio loads at 8,192 by default; a
   10k to 25k-token transcript would be cut off or fail. Pass the context in the app's load call
   (`lms load ... --context-length 65536`), do not rely on the UI setting.
2. **Cap the thinking.** At the template's default effort (xhigh) this model spends about 48k
   reasoning tokens per task: added to a transcript that overflows 65k and runs over an hour.
   `reasoning_effort: "none"` is NOT reliably honored on LM Studio's MLX path (bug #2284, open).
   Set the prompt template's default effort to `medium`, set `max_tokens` to at least 16,384, and
   treat `finish_reason: "length"` or empty content as a failure to retry, never as a result.
3. **Single-turn, `system` + `user` roles only.** The family's template mishandles past assistant
   turns and some runtimes reject the `developer` role.
4. **Validate every JSON in Swift**, even with `response_format: json_schema`. Schema enforcement
   with a thinking, vision-packaged model on MLX is unproven; test the chapter pass once.
5. Sampling for writing passes: temperature 0.7, top_p 0.8, top_k 20, presence_penalty 1.5. If
   Spanish or Sanskrit-heavy output drifts between languages, lower presence_penalty toward 0.5.
6. **Memory:** the model process sits near 33 to 36 GB; whole-system peaks of 51 to 54 GB were
   measured with it serving. Long unattended runs want heavy apps closed.

Optional later: LM Studio's experimental Splash engine runs a 4-bit package about 7x faster with
real reasoning-level control, but has no published quality comparison. A speed option, not the
quality pick. Watch list: new open-weight releases due mid-October.

## Measured in Prakriti for Mac, Sat 10 Oct (milestone 6)

Every setting above is in the app (`mac/Prakriti/Writing/ModelClients.swift`, pinned by `WritingTests`).
What running it on the 13 Sep talk (15:48, 2,948 words, 137 lines) showed:

| | |
|---|---|
| Loading at 65,536 | Through LM Studio's REST API, `POST http://localhost:1235/api/v1/models/load` with `{"model": "qwen/qwen3.8-27b", "context_length": 65536}`; `GET /api/v1/models` shows each loaded instance's `config.context_length`; `POST /api/v1/models/unload` with `instance_id`. 8 to 10 s. The `lms` CLI cannot reach this server (port 1235), so HTTP is the only control |
| `reasoning_effort: "medium"` | Honored on `/v1/chat/completions`: the same 41-token prompt measured 79 prompt tokens without the field and 41 with it, so it changes what the template builds. On the talk: 4,580, 7,117 and 5,073 thinking tokens in three runs, against about 48k at the template's default |
| Time | 585 s, 847 s and 630 s for the writing request (the second while the Mac ran the unit tests beside it); about 5,200 to 5,300 tokens read, 5,300 to 7,700 written, about 9 tokens a second. The whole step, with Apple's tags and summary: 10 min 3 s, 14 min 25 s and 10 min 48 s |
| Answers | All three runs: valid JSON as it came (no fence, no prose, after trimming the leading blank lines), passed every check on the first try: 3 titles, 3 chapters at real line times, 8, 7 and 8 quotes found word for word, none left out |
| What a prompt must say | The first run's show notes repeated a private family matter from the talk; a rule against private matters (illness, deaths, family, money troubles) fixed it in the second. Chapter titles ran to 5 words until the prompt said "2 to 4 words (count them)" |
| `response_format: json_schema` | Not used, and not tested: the JSON came back clean without it, and rule 4 checks it in Swift either way |
| Memory | The app loads the model only for the writing step and unloads it after, so the 33 GB is held for about ten minutes per recording, not all day |
