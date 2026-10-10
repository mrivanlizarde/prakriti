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
