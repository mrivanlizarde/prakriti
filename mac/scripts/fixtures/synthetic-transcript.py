"""Turn synthetic-talk.txt into synthetic-transcript.json, in the shape parakeet-mlx writes.

Run by make-fixtures.sh (`/usr/bin/python3 -I`); never by the app. The talk is made up and names
no real person, so the cloud providers (v2 part M5) can be tested on it before Gabriel's written yes
(PLAN section 11, D1). The same text always gives the same bytes: every time is computed from the
words, nothing is random, nothing is read from the clock.

The shape, as parakeet-mlx 0.x writes it (measured on Prakriti's own transcript.json, 11 Oct 2026):
  {"text": <the sentences stripped and joined with one space>,
   "sentences": [{"text": " <sentence>", "start", "end", "duration", "confidence",
                  "tokens": [{"text", "start", "end", "duration", "confidence"}, ...]}, ...]}
Times are seconds rounded to 2 places on Parakeet's 80 ms frame. Here each word is one token that
starts with a space (" breath") and each punctuation mark is its own token with no space ("," "."),
which is how Parakeet writes punctuation. Real Parakeet splits long words into pieces (" Be", "ing");
EpisodeTranscript reads both the same way (a word is a token starting with a space and the pieces
after it).

The timing model, chosen to read like a calm talk (about 135 words a minute):
  a word lasts 0.08 s plus 0.06 s per letter, rounded to the frame, at least 2 frames;
  1 frame between words; a comma adds 2 frames, the end of a sentence 6, a new paragraph 15.
"""

import json
import re
import sys

FRAME = 0.08


def frames(seconds):
    return max(2, round(seconds / FRAME))


def t(frame_count):
    return round(frame_count * FRAME, 2)


def confidence(index):
    # A steady, deterministic spread between 0.950 and 0.999, as Parakeet reports on clean speech.
    return round(0.95 + ((index * 37) % 50) / 1000, 3)


def main(source, destination):
    with open(source, encoding="utf-8") as handle:
        paragraphs = [p.strip() for p in handle.read().split("\n\n") if p.strip()]

    sentences = []
    clock = 3  # the first word starts at 0.24 s
    token_index = 0
    for paragraph_number, paragraph in enumerate(paragraphs):
        if paragraph_number > 0:
            clock += 15
        for sentence_text in re.split(r"(?<=[.?!])\s+", paragraph):
            tokens = []
            for word in sentence_text.split():
                match = re.fullmatch(r"(.*?)([.,?!:;]*)", word)
                body, marks = match.group(1), match.group(2)
                length = frames(FRAME + 0.06 * len(body))
                tokens.append({"text": " " + body, "start": t(clock), "end": t(clock + length),
                               "duration": t(length), "confidence": confidence(token_index)})
                token_index += 1
                clock += length
                for mark in marks:
                    tokens.append({"text": mark, "start": t(clock), "end": t(clock + 1),
                                   "duration": t(1), "confidence": confidence(token_index)})
                    token_index += 1
                    clock += 1
                    if mark == ",":
                        clock += 2
                clock += 1
            start, end = tokens[0]["start"], tokens[-1]["end"]
            sentences.append({
                "text": " " + sentence_text,
                "start": start,
                "end": end,
                "duration": round(end - start, 2),
                "confidence": round(sum(token["confidence"] for token in tokens) / len(tokens), 3),
                "tokens": tokens,
            })
            clock += 6

    result = {"text": " ".join(s["text"].strip() for s in sentences), "sentences": sentences}
    with open(destination, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    words = sum(1 for s in sentences for token in s["tokens"] if token["text"].startswith(" "))
    print(f"{words} words, {len(sentences)} sentences, {len(paragraphs)} paragraphs, "
          f"ends at {sentences[-1]['end']:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
