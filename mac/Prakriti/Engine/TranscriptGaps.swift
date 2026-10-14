import Foundation

// Stretches of speech the transcript has no words for (v2 part TXGAP). Parakeet, run once over a whole talk, can write
// nothing for a stretch of plain speech and still return fluent text everywhere else: on the 6 Sep talk it wrote no
// word for 17 s at 24:22, 17 s at 39:24 and 5 s at 43:04 (measured 14 Oct: 72, 59 and 22 words when each stretch is
// transcribed alone). The old coverage check only asked whether the words reach the end, so all three passed, and the
// podcast transcript, captions, chapters and the rough cut lost them (the cut took the two long ones out as "pauses").
//
// So after the whole-file run, the sound's envelope is compared with the words' times. Each wordless stretch of 3 s or
// more that holds 1 s or more of speech is cut from the same 16 kHz audio and transcribed again on its own, and only
// the words that start inside the stretch are taken (no word of the first run starts there, so nothing is written
// twice). The coverage check then fails on any wordless stretch still holding 3 s or more of speech, wherever it is.
//
// The numbers, each with its reason:
// - 3 s: the plan's bar (docs/v2/PLAN.md, part TXGAP). A shorter wordless stretch is a pause.
// - 1 s of speech to listen again: measured on 6 Sep, every wordless stretch of 3 s or more held 0.0 to 0.3 s of
//   speech (a breath, a chair), except the three missed ones (10.7, 11.2 and 3.4 s) and one at 14:41 (0.9 s, one word
//   when transcribed alone). Listening again costs a few seconds, so the bar is low.
// - 3 s of speech to fail the check: "a gap of speech longer than 3 s" (the plan). Below that, a stretch Parakeet
//   still hears nothing in is most likely a cough or a laugh.
// - A word covers its start to its end, but never more than 1 s: Parakeet stretches the last word before a pause
//   across the pause (10 Oct: "caught." ran 3 s into the silence after it), which would hide a gap behind it.
// - 2 s of the sound on each side of a stretch go with it when it is transcribed again, so its first and last words
//   are heard whole; the words found in those 2 s are already in the transcript and are not taken.
//
// The files are rewritten only when words were found. Every cue of the first run is kept as Parakeet wrote it (its
// .srt and .vtt lines are copied, never re-timed), so the transcript is unchanged except for the words added.

enum TranscriptGaps {
    /// A wordless stretch, with how much of it is speech by the envelope.
    struct Gap: Equatable, Sendable {
        let start: Double
        let end: Double
        let speech: Double
        var length: Double { end - start }
        var range: TimeRange { TimeRange(start: start, end: end) }
    }

    /// A wordless stretch this long or longer is looked at.
    static let shortest = 3.0
    /// It is transcribed again when it holds this much speech.
    static let listenAgainAt = 1.0
    /// The coverage check fails on a wordless stretch holding this much speech.
    static let failAt = 3.0
    /// A word covers at most this long from its start.
    static let longestWord = 1.0
    /// The sound taken on each side of a stretch when it is transcribed again.
    static let context = 2.0

    // MARK: Finding them

    /// Where each word is said: its start to its end, at most `longestWord` long. Punctuation alone is not a word.
    static func wordSpans(_ transcript: ParakeetTranscript) -> [TimeRange] {
        transcript.sentences.flatMap(\.tokens)
            .filter { EpisodeTranscript.isWord($0.text) }
            .map { TimeRange(start: $0.start, end: max($0.start, min($0.end, $0.start + longestWord))) }
            .sorted { $0.start < $1.start }
    }

    /// Every stretch of `shortest` or more with no word in it, from the start of the sound to its end, each with its
    /// seconds of speech.
    static func wordless(_ transcript: ParakeetTranscript, envelope: Envelope, duration: Double) -> [Gap] {
        var gaps: [Gap] = []
        var reached = 0.0
        for span in wordSpans(transcript) + [TimeRange(start: duration, end: duration)] {
            if span.start - reached >= shortest {
                gaps.append(Gap(start: reached, end: span.start, speech: envelope.activeSeconds(from: reached, to: span.start)))
            }
            reached = max(reached, span.end)
        }
        return gaps
    }

    /// The stretches worth transcribing again.
    static func toListenAgain(_ transcript: ParakeetTranscript, envelope: Envelope, duration: Double) -> [Gap] {
        wordless(transcript, envelope: envelope, duration: duration).filter { $0.speech >= listenAgainAt }
    }

    /// The stretches the coverage check fails on.
    static func missing(_ transcript: ParakeetTranscript, envelope: Envelope, duration: Double) -> [Gap] {
        wordless(transcript, envelope: envelope, duration: duration).filter { $0.speech >= failAt }
    }

    // MARK: Taking the words found

    /// The sound cut for a stretch: `context` on each side, inside the recording.
    static func piece(for gap: Gap, duration: Double) -> TimeRange {
        TimeRange(start: max(0, gap.start - context), end: min(duration, gap.end + context))
    }

    /// The sentences of a stretch's own transcript (times from the piece's start at `offset`) moved onto the
    /// recording's clock, keeping only the words that start inside the stretch, whole (a word is a token that begins
    /// with a space and the pieces and punctuation after it, as `EpisodeTranscript.words`). A word the first run already
    /// has at the same moment (same letters, starts within `sameMoment`) is not taken again: a second listen can time a
    /// word at the stretch's edge a frame or two later than the first did.
    static func found(in piece: ParakeetTranscript, offset: Double, gap: Gap,
                      existing: [ParakeetTranscript.Token] = []) -> [ParakeetTranscript.Sentence] {
        let known = words(existing).map { (key: key($0), start: $0[0].start) }
        return piece.sentences.compactMap { sentence in
            var kept: [ParakeetTranscript.Token] = []
            for word in words(sentence.tokens) {
                guard let first = word.first(where: { EpisodeTranscript.isWord($0.text) }) else {
                    if !kept.isEmpty { kept += word.map { $0.moved(by: offset) } } // punctuation after a kept word
                    continue
                }
                let start = first.start + offset
                guard start >= gap.start, start < gap.end else { continue }
                let k = key(word)
                guard !known.contains(where: { $0.key == k && abs($0.start - start) < sameMoment }) else { continue }
                kept += word.map { $0.moved(by: offset) }
            }
            guard let first = kept.first, let last = kept.last else { return nil }
            let text = kept.map(\.text).joined()
            let confidence = ParakeetTranscript.rounded(kept.map(\.confidence).reduce(0, +) / Double(kept.count))
            return ParakeetTranscript.Sentence(text: text, start: first.start, end: last.end,
                                               duration: ParakeetTranscript.rounded(last.end - first.start), confidence: confidence, tokens: kept)
        }
    }

    /// Two words this close in time with the same letters are the same word heard twice.
    static let sameMoment = 0.5

    /// Tokens grouped into words: a word starts at a token that begins with a space (or the first token).
    static func words(_ tokens: [ParakeetTranscript.Token]) -> [[ParakeetTranscript.Token]] {
        var words: [[ParakeetTranscript.Token]] = []
        for token in tokens {
            if words.isEmpty || token.text.first?.isWhitespace == true { words.append([token]) } else { words[words.count - 1].append(token) }
        }
        return words
    }

    /// A word's letters and digits, lowercased: what two hearings of it share.
    static func key(_ word: [ParakeetTranscript.Token]) -> String {
        String(word.map(\.text).joined().lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The transcript with the sentences found added, and which of its sentences are new. The first run's sentences
    /// keep their own order, which is not always by start time (6 Sep: one sentence at 31:44.5 follows one at 31:45.8,
    /// Parakeet's misplaced-time tokens); each new sentence goes before the first of them that starts after it.
    static func merged(_ transcript: ParakeetTranscript, adding added: [ParakeetTranscript.Sentence]) -> (ParakeetTranscript, [Bool]) {
        var pending = added.sorted { $0.start < $1.start }[...]
        var sentences: [ParakeetTranscript.Sentence] = [], isNew: [Bool] = []
        for old in transcript.sentences {
            while let next = pending.first, next.start < old.start {
                sentences.append(next); isNew.append(true); pending = pending.dropFirst()
            }
            sentences.append(old); isNew.append(false)
        }
        sentences += pending
        isNew += pending.map { _ in true }
        let text = sentences.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return (ParakeetTranscript(text: text, sentences: sentences), isNew)
    }

    // MARK: Writing the files

    /// Rewrites transcript.json, .txt, .srt and .vtt in `folder` for the merged transcript. The first run's cues keep
    /// their own .srt and .vtt lines; only the new ones are formatted (as Parakeet formats them).
    static func write(_ transcript: ParakeetTranscript, isNew: [Bool], in folder: URL) throws {
        let srtURL = folder.appending(path: TranscriptFiles.fileName(.srt))
        let vttURL = folder.appending(path: TranscriptFiles.fileName(.vtt))
        let oldSRT = (try? String(contentsOf: srtURL, encoding: .utf8)).map(srtBlocks) ?? []
        let oldVTT = (try? String(contentsOf: vttURL, encoding: .utf8)).map(vttBlocks) ?? []
        let oldCount = isNew.filter { !$0 }.count
        var srt: [String] = [], vtt: [String] = []
        var k = 0
        for (sentence, new) in zip(transcript.sentences, isNew) {
            let line = sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !new, oldSRT.count == oldCount {
                srt.append(oldSRT[k])
            } else {
                srt.append(EpisodeTranscript.stamp(sentence.start, separator: ",") + " --> " + EpisodeTranscript.stamp(sentence.end, separator: ",") + "\n" + line)
            }
            if !new, oldVTT.count == oldCount {
                vtt.append(oldVTT[k])
            } else {
                vtt.append(EpisodeTranscript.stamp(sentence.start, separator: ".") + " --> " + EpisodeTranscript.stamp(sentence.end, separator: ".") + "\n" + line)
            }
            if !new { k += 1 }
        }
        let srtText = srt.enumerated().map { "\($0.offset + 1)\n\($0.element)\n" }.joined(separator: "\n")
        let vttText = (["WEBVTT", ""] + vtt.map { $0 + "\n" }).joined(separator: "\n")
        try transcript.encoded().write(to: folder.appending(path: TranscriptFiles.asHeard), atomically: true, encoding: .utf8)
        try transcript.text.write(to: folder.appending(path: TranscriptFiles.fileName(.txt)), atomically: true, encoding: .utf8)
        try srtText.write(to: srtURL, atomically: true, encoding: .utf8)
        try vttText.write(to: vttURL, atomically: true, encoding: .utf8)
    }

    /// Each cue of an .srt as Parakeet wrote it: its timing line and its text, without its number.
    static func srtBlocks(_ srt: String) -> [String] {
        srt.components(separatedBy: "\n\n").compactMap { block in
            let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard let timing = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
            return lines[timing...].joined(separator: "\n")
        }
    }

    /// Each cue of a .vtt as Parakeet wrote it: its timing line and its text.
    static func vttBlocks(_ vtt: String) -> [String] {
        vtt.components(separatedBy: "\n\n").compactMap { block in
            let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard let timing = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
            return lines[timing...].joined(separator: "\n")
        }
    }

    /// "24:22 (17 s), 39:24 (17 s)": where each stretch starts and how long it is, for the log, the report and the page.
    static func list(_ gaps: [TimeRange]) -> String {
        gaps.map { "\(Format.timecode($0.start)) (\(Int(($0.end - $0.start).rounded())) s)" }.joined(separator: ", ")
    }
}

/// Parakeet's transcript.json, every field it writes, so a rewritten file reads exactly as Parakeet's own.
struct ParakeetTranscript: Codable, Sendable {
    struct Token: Codable, Sendable {
        var text: String
        var start: Double
        var end: Double
        var duration: Double
        var confidence: Double

        func moved(by offset: Double) -> Token {
            Token(text: text, start: ParakeetTranscript.rounded(start + offset), end: ParakeetTranscript.rounded(end + offset),
                  duration: duration, confidence: confidence)
        }
    }

    struct Sentence: Codable, Sendable {
        var text: String
        var start: Double
        var end: Double
        var duration: Double
        var confidence: Double
        var tokens: [Token]
    }

    var text: String
    var sentences: [Sentence]

    static func read(_ url: URL) -> ParakeetTranscript? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ParakeetTranscript.self, from: data)
    }

    /// Three decimals, as Parakeet writes them.
    static func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }

    /// The JSON as Parakeet's Python writes it (`json.dumps(..., indent=2, ensure_ascii=False)`), byte for byte: the
    /// keys in its order, two-space indents, and numbers as Python prints them.
    func encoded() -> String {
        var out = "{\n  \"text\": \(Self.quoted(text)),\n  \"sentences\": ["
        if sentences.isEmpty {
            out += "]\n}"
            return out
        }
        out += "\n"
        out += sentences.map { s in
            var block = "    {\n"
            block += "      \"text\": \(Self.quoted(s.text)),\n"
            block += "      \"start\": \(Self.number(s.start)),\n"
            block += "      \"end\": \(Self.number(s.end)),\n"
            block += "      \"duration\": \(Self.number(s.duration)),\n"
            block += "      \"confidence\": \(Self.number(s.confidence)),\n"
            block += "      \"tokens\": ["
            if s.tokens.isEmpty {
                block += "]\n"
            } else {
                block += "\n" + s.tokens.map { t in
                    "        {\n"
                        + "          \"text\": \(Self.quoted(t.text)),\n"
                        + "          \"start\": \(Self.number(t.start)),\n"
                        + "          \"end\": \(Self.number(t.end)),\n"
                        + "          \"duration\": \(Self.number(t.duration)),\n"
                        + "          \"confidence\": \(Self.number(t.confidence))\n"
                        + "        }"
                }.joined(separator: ",\n") + "\n      ]\n"
            }
            return block + "    }"
        }.joined(separator: ",\n")
        out += "\n  ]\n}"
        return out
    }

    /// A number as Python's repr writes a float rounded to three decimals: "3.12", "1.0", "0.0".
    static func number(_ value: Double) -> String {
        let r = rounded(value)
        let text = "\(r == 0 ? 0 : r)"
        return text.contains(".") || text.contains("e") ? text : text + ".0"
    }

    /// A string as Python's json writes it with ensure_ascii off: quotes, backslashes and control characters escaped.
    static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 { out += String(format: "\\u%04x", scalar.value) } else { out.unicodeScalars.append(scalar) }
            }
        }
        return out + "\""
    }
}
