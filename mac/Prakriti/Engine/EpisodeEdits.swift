import Foundation

// Milestone 5: Ivan's edits to an episode, made on a recording's page. Where the episode starts and
// ends, and the sections cut out of it, all in seconds on the ORIGINAL recording's clock: the clock
// the transcript lines, the player's "Original" and the report use. The pipeline turns the edits
// into the parts of the recording the episode keeps (`segments`), and `EpisodeClock` maps a moment
// of the original to where it plays in the episode and back, so a transcript line can play the
// episode from the right place.
//
// Rules, each with its reason:
// - A part shorter than a quarter of a second left between two cuts is cut too. Reason: kept, it
//   would be a click or half a syllable; and "uncertain means cut" (SCOPE PR-3).
// - Every kept part fades in and out over 15 ms when there are edits. Reason: a cut through a word
//   lands mid-waveform and clicks; 15 ms is too short to hear as a fade and keeps the length exact.
// - Without edits nothing here runs, so the episode is made exactly as milestone 4 made it.

struct EpisodeEdits: Codable, Equatable, Sendable {
    /// Where the episode starts and ends in the original. Nil: the recording's own start or end.
    var start: Double?
    var end: Double?
    /// Sections cut out, sorted and never overlapping (`adding(cut:)` keeps them so).
    var cuts: [TimeRange] = []

    static let shortestPart = 0.25
    static let fade = 0.015

    var isEmpty: Bool { start == nil && end == nil && cuts.isEmpty }

    /// Cuts sorted, and merged where they overlap or touch.
    static func merged(_ cuts: [TimeRange]) -> [TimeRange] {
        var out: [TimeRange] = []
        for cut in cuts.filter({ $0.end > $0.start }).sorted(by: { $0.start < $1.start }) {
            if let last = out.last, cut.start <= last.end + 0.001 {
                out[out.count - 1].end = max(last.end, cut.end)
            } else {
                out.append(cut)
            }
        }
        return out
    }

    /// The same edits with more cuts (v2 part M6c: the speech of people left out), joined with Ivan's own.
    func adding(cuts more: [TimeRange]) -> EpisodeEdits {
        var copy = self
        copy.cuts = Self.merged(cuts + more)
        return copy
    }

    func adding(cut: TimeRange) -> EpisodeEdits {
        var copy = self
        copy.cuts = Self.merged(cuts + [cut])
        return copy
    }

    /// The parts of the original the episode keeps, in order: from the start to the end (each the
    /// later start and the earlier end of Ivan's trim and the silence trim), minus the cuts. Empty
    /// when nothing would be left.
    func segments(duration: Double, silence: Mastering.Span? = nil) -> [Mastering.Span] {
        let low = max(start ?? 0, silence?.start ?? 0, 0)
        let high = min(end ?? duration, silence?.end ?? duration, duration)
        guard high - low >= Self.shortestPart else { return [] }
        var parts: [Mastering.Span] = []
        var cursor = low
        for cut in Self.merged(cuts) where cut.end > low && cut.start < high {
            let cutStart = max(cut.start, low)
            if cutStart - cursor >= Self.shortestPart { parts.append(Mastering.Span(start: cursor, end: cutStart)) }
            cursor = max(cursor, min(cut.end, high))
        }
        if high - cursor >= Self.shortestPart { parts.append(Mastering.Span(start: cursor, end: high)) }
        return parts
    }

    /// Why these edits cannot be made, in one plain sentence, or nil when they can.
    func problem(duration: Double, silence: Mastering.Span? = nil) -> String? {
        let length = TimeText.string(duration)
        if let start, start < 0 { return "The start cannot be before the beginning of the recording." }
        if let start, start >= duration { return "The start (\(TimeText.string(start))) is after the end of the recording (\(length))." }
        if let end, end <= 0 { return "The end must be after the beginning of the recording." }
        if let end, end > duration + 0.5 { return "The end (\(TimeText.string(end))) is after the end of the recording (\(length))." }
        if let start, let end, start >= end { return "The start (\(TimeText.string(start))) is after the end (\(TimeText.string(end)))." }
        for cut in cuts where cut.end <= cut.start {
            return "A cut must end after it starts (\(TimeText.string(cut.start)) to \(TimeText.string(cut.end)))."
        }
        let kept = segments(duration: duration, silence: silence).reduce(0) { $0 + $1.length }
        if kept < 1 { return "Nothing would be left of the episode after the trim and the cuts." }
        return nil
    }

    /// The same edits, to a hundredth of a second.
    func matches(_ other: EpisodeEdits) -> Bool {
        func same(_ a: Double?, _ b: Double?) -> Bool {
            switch (a, b) {
            case (nil, nil): true
            case let (a?, b?): abs(a - b) < 0.01
            default: false
            }
        }
        let mine = Self.merged(cuts), theirs = Self.merged(other.cuts)
        return same(start, other.start) && same(end, other.end) && mine.count == theirs.count
            && zip(mine, theirs).allSatisfy { abs($0.start - $1.start) < 0.01 && abs($0.end - $1.end) < 0.01 }
    }

    /// "Starts at 0:10. 1 cut: 5:00 to 5:30 (30 s)." Nil when there are no edits.
    var summary: String? {
        guard !isEmpty else { return nil }
        var parts: [String] = []
        if let start { parts.append("Starts at \(TimeText.string(start)).") }
        if let end { parts.append("Ends at \(TimeText.string(end)).") }
        let merged = Self.merged(cuts)
        if !merged.isEmpty {
            let listed = merged.map { "\(TimeText.string($0.start)) to \(TimeText.string($0.end)) (\(Format.length($0.end - $0.start)))" }
            parts.append("\(Format.count(merged.count, "cut")): " + listed.joined(separator: ", ") + ".")
        }
        return parts.joined(separator: " ")
    }
}

/// Where a moment of the original plays in the episode, and back: the intro (if any), then the
/// kept parts end to end.
struct EpisodeClock: Equatable, Sendable {
    var intro: Double = 0
    var segments: [Mastering.Span]

    /// The talk's own length in the episode, without the intro or outro.
    var keptLength: Double { segments.reduce(0) { $0 + $1.length } }

    /// The original's moment `t` in the episode. A moment that was cut or trimmed gives the moment
    /// where the episode carries on after it, with `removed` true.
    func episodeTime(_ t: Double) -> (time: Double, removed: Bool) {
        var offset = intro
        for segment in segments {
            if t < segment.start { return (offset, true) }
            if t <= segment.end { return (offset + t - segment.start, false) }
            offset += segment.length
        }
        return (offset, true)
    }

    /// The episode's moment `e` in the original, or nil inside the intro or the outro.
    func originalTime(_ e: Double) -> Double? {
        guard e >= intro else { return nil }
        var x = e - intro
        for segment in segments {
            if x <= segment.length { return segment.start + x }
            x -= segment.length
        }
        return nil
    }

    /// Nothing taken out and nothing added: the episode's times are the original's.
    func isIdentity(duration: Double) -> Bool {
        intro < 0.001 && segments.count == 1 && segments[0].start < 0.001 && segments[0].end > duration - 0.001
    }
}

/// Times as Ivan types and reads them on a recording's page.
enum TimeText {
    /// "4:12" is 252 s, "1:02:30" is 3,750 s, "75" is 75 s, "4:12.5" is 252.5 s. Nil for anything
    /// else, including minutes or seconds of 60 or more after another number.
    static func seconds(_ text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard (1...3).contains(parts.count) else { return nil }
        var total = 0.0
        for (index, part) in parts.enumerated() {
            let last = index == parts.count - 1
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && ($0.isNumber || (last && $0 == ".")) }),
                  part.filter({ $0 == "." }).count <= 1, let value = Double(part) else { return nil }
            if index > 0 && value >= 60 { return nil }
            total = total * 60 + value
        }
        return total
    }

    /// "4:12", "1:02:30", or "4:12.5" when it is not a whole second.
    static func string(_ seconds: Double) -> String {
        let tenths = Int((max(0, seconds) * 10).rounded())
        let whole = tenths / 10, fraction = tenths % 10
        let h = whole / 3600, m = (whole % 3600) / 60, s = whole % 60
        let clock = (h > 0 ? "\(h):" + String(format: "%02d", m) : "\(m)") + ":" + String(format: "%02d", s)
        return fraction == 0 ? clock : clock + ".\(fraction)"
    }
}

/// The transcript as the episode says it: the words that were kept, on the episode's clock. Built
/// from transcript.json, Parakeet's words with their own times, so a cut through the middle of a
/// sentence takes out exactly the words inside it. Reason: a cut is how a student's question or a
/// name comes out of an episode, and the transcript that ships with it must lose those words too.
///
/// Load-bearing: Parakeet's token list is NOT in the order the words were said. Parakeet writes a
/// sentence's text in the order it heard the words, then sorts the sentence's tokens by their start
/// times (parakeet_mlx alignment.py, `AlignedSentence.__post_init__`). Where two of the chunks it
/// listens in meet (every 105 s), a few tokens carry a wrong, too-early time, most often a
/// sentence's last full stop, so the sort moves them: about 4% of sentences (13 Sep: 5 of 137;
/// 6 Sep: 21 of 555). Joined as listed, they read ". But the problem was that again, we spent $100
/// for the venue" and "the You can always have access to Fathom", which shipped in milestone 5's
/// files (verifier, 10 Oct). `sentences(json:)` therefore puts the tokens back in the order the text spells and
/// gives each misplaced token a time between its neighbours (`said`), and a sentence kept whole
/// is written as Parakeet's own text.
enum EpisodeTranscript {
    struct Token: Decodable, Equatable, Sendable {
        let text: String
        let start: Double
        let end: Double
    }

    struct Sentence: Decodable, Sendable {
        let text: String
        let start: Double
        let end: Double
        let tokens: [Token]?
    }

    private struct Payload: Decodable { let sentences: [Sentence]? }

    /// Where a word is said, for deciding whether a cut takes it: its middle, but never more than
    /// 0.15 s after it starts. Reason: Parakeet stretches the last word before a pause across the
    /// pause (measured 10 Oct: "caught." ran 3 s into the silence after it), and its middle then
    /// lands seconds after the word was said.
    static func position(start: Double, end: Double) -> Double {
        min((start + end) / 2, start + 0.15)
    }

    /// A token with a letter or a digit in it; punctuation alone is not a word.
    static func isWord(_ text: String) -> Bool {
        text.contains { $0.isLetter || $0.isNumber }
    }

    /// Punctuation that closes what comes before it, alone in a token: never the start of a line.
    static func isClosingPunctuation(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.allSatisfy { ",.;:!?…".contains($0) }
    }

    /// The sentences of a transcript.json, each with its tokens in the order they were said (`said`),
    /// or nil when it cannot be read.
    static func sentences(json: Data) -> [Sentence]? {
        (try? JSONDecoder().decode(Payload.self, from: json))?.sentences?.map(said)
    }

    /// The sentence with its tokens in the order its text spells them, each misplaced token given a
    /// time between its neighbours, and its start and end taken from them. A sentence whose tokens
    /// already spell its text comes back as it is; so does one they cannot spell (then `cues` still
    /// writes Parakeet's text for it when it is kept whole).
    static func said(_ sentence: Sentence) -> Sentence {
        guard let tokens = sentence.tokens, !tokens.isEmpty, tokens.map(\.text).joined() != sentence.text,
              let order = spelling(sentence.text, with: tokens) else { return sentence }
        let timed = retimed(order.map { tokens[$0] })
        return Sentence(text: sentence.text, start: timed[0].start, end: timed.map(\.end).max() ?? sentence.end, tokens: timed)
    }

    /// The order of `tokens` that spells `text` exactly, or nil when none does (or the search runs
    /// long). Each step tries first the token that comes next in time, so the identical tokens a
    /// sentence repeats (" and", ",") keep their own times.
    static func spelling(_ text: String, with tokens: [Token]) -> [Int]? {
        let target = Array(text.utf8)
        let pieces = tokens.map { Array($0.text.utf8) }
        guard pieces.reduce(0, { $0 + $1.count }) == target.count else { return nil }
        var used = [Bool](repeating: false, count: tokens.count)
        var order: [Int] = []
        order.reserveCapacity(tokens.count)
        var budget = 20_000
        func fits(_ index: Int, at position: Int) -> Bool {
            let piece = pieces[index]
            return position + piece.count <= target.count && target[position..<(position + piece.count)].elementsEqual(piece)
        }
        func search(_ position: Int) -> Bool {
            if order.count == tokens.count { return position == target.count }
            budget -= 1
            guard budget > 0 else { return false }
            let after = order.last.map { tokens[$0].start } ?? -Double.infinity
            let candidates = tokens.indices.filter { !used[$0] && fits($0, at: position) }.sorted { a, b in
                let aNext = tokens[a].start >= after, bNext = tokens[b].start >= after
                if aNext != bNext { return aNext }
                if tokens[a].start != tokens[b].start { return aNext ? tokens[a].start < tokens[b].start : tokens[a].start > tokens[b].start }
                return a < b
            }
            for candidate in candidates {
                used[candidate] = true
                order.append(candidate)
                if search(position + pieces[candidate].count) { return true }
                used[candidate] = false
                order.removeLast()
            }
            return false
        }
        return search(0) ? order : nil
    }

    /// Tokens in the order they were said, with the times that break that order replaced. The
    /// tokens whose times already run in order are kept as they are (the most of them, words
    /// counting double, later times winning a tie, since a misplaced time is the too-early one);
    /// each other token starts where the token before it ends, and ends by the next kept start.
    static func retimed(_ tokens: [Token]) -> [Token] {
        let count = tokens.count
        guard count > 1 else { return tokens }
        var score = [(weight: Int, time: Double)](repeating: (0, 0), count: count)
        var back = [Int](repeating: -1, count: count)
        for k in 0..<count {
            let weight = isWord(tokens[k].text) ? 2 : 1
            score[k] = (weight, tokens[k].start)
            for j in 0..<k where tokens[j].start <= tokens[k].start {
                let candidate = (weight: score[j].weight + weight, time: score[j].time + tokens[k].start)
                if candidate > score[k] { score[k] = candidate; back[k] = j }
            }
        }
        var kept = [Bool](repeating: false, count: count)
        var k = (0..<count).max { score[$0] < score[$1] } ?? count - 1
        while k >= 0 { kept[k] = true; k = back[k] }
        var out = tokens
        for k in 0..<count where !kept[k] {
            let next = ((k + 1)..<count).first { kept[$0] }.map { tokens[$0].start }
            let start = k > 0 ? min(out[k - 1].end, next ?? .infinity) : (next ?? tokens[k].start)
            let end = min(start + max(0, tokens[k].end - tokens[k].start), next ?? .infinity)
            out[k] = Token(text: tokens[k].text, start: start, end: max(start, end))
        }
        return out
    }

    /// A sentence's tokens as words: a word starts at a token that begins with a space (or at the
    /// sentence's first token) and takes the pieces and punctuation that follow it, so " Jer",
    /// "se", "y", "." is one word and a cut keeps or drops it whole.
    static func words(_ tokens: [Token]) -> [[Token]] {
        var words: [[Token]] = []
        for token in tokens {
            if words.isEmpty || token.text.first?.isWhitespace == true { words.append([token]) } else { words[words.count - 1].append(token) }
        }
        return words
    }

    /// The episode's cues: every word said in a kept part (`position`), timed on the episode's
    /// clock, with the word list applied when it is on. A sentence kept whole is Parakeet's own
    /// text; a sentence a cut goes through becomes two cues, never starting with a stray comma or
    /// full stop. `removedWords` counts the words left out; `corrections` are the word list's fixes
    /// in the cues, each at its time in the original recording.
    ///
    /// `mutes` (v2 part M6c): names said aloud that Ivan muted, on the original's clock. A word said inside one is
    /// written "[name]", its punctuation kept, and a sentence with one is built from its words, never written as
    /// Parakeet's own text.
    static func cues(_ sentences: [Sentence], clock: EpisodeClock, applyLexicon: Bool, mutes: [TimeRange] = [])
        -> (cues: [TranscriptFiles.Cue], removedWords: Int, corrections: [Lexicon.Correction]) {
        var cues: [TranscriptFiles.Cue] = []
        var corrections: [Lexicon.Correction] = []
        var removed = 0
        func segmentIndex(_ t: Double) -> Int? { clock.segments.firstIndex { t >= $0.start && t <= $0.end } }
        for sentence in sentences {
            let tokens = sentence.tokens ?? [Token(text: sentence.text, start: sentence.start, end: sentence.end)]
            var run: [Token] = []
            var runSegment: Int?
            var mutedHere = false
            func flush() {
                defer { run = []; runSegment = nil }
                guard let index = runSegment else { return }
                let whole = run.count == tokens.count && !mutedHere
                // Part of a sentence never opens with the punctuation that closed the words before it.
                let pieces = whole ? run[...] : run.drop { Self.isClosingPunctuation($0.text) }
                guard let first = pieces.first, let last = pieces.last else { return }
                let segment = clock.segments[index]
                var text = (whole ? sentence.text : pieces.map(\.text).joined()).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                let at = min(max(first.start, segment.start), segment.end)
                if applyLexicon {
                    let fixed = Lexicon.apply(text, at: at)
                    text = fixed.text
                    corrections += fixed.corrections
                }
                let start = clock.episodeTime(at).time
                let end = clock.episodeTime(min(max(last.end, segment.start), segment.end)).time
                cues.append(TranscriptFiles.Cue(start: start, end: max(start, end), text: text))
            }
            var previous: Int?? = .none
            for word in Self.words(tokens) {
                guard let first = word.first, let last = word.last else { continue }
                let spoken = word.contains { Self.isWord($0.text) }
                // Punctuation on its own goes with the word before it: Parakeet often places a
                // sentence's last full stop after the pause that follows it (measured 10 Oct).
                let index: Int? = if !spoken, let previous { previous } else { segmentIndex(Self.position(start: first.start, end: last.end)) }
                previous = .some(index)
                if index == nil {
                    if spoken { removed += 1 }
                    flush()
                    continue
                }
                if index != runSegment { flush() }
                runSegment = index
                let at = Self.position(start: first.start, end: last.end)
                if spoken, mutes.contains(where: { at >= $0.start && at <= $0.end }) {
                    // A muted name: "[name]" in its place, with the space before it and the punctuation after it. A name
                    // of two words ("Pattabhi Jois") is one "[name]", not two.
                    mutedHere = true
                    let lead = first.text.first?.isWhitespace == true ? " " : ""
                    if run.last?.text.hasSuffix(Self.mutedWord) != true {
                        run.append(Token(text: lead + Self.mutedWord, start: first.start, end: last.end))
                    }
                    run.append(contentsOf: word.dropFirst().filter { !Self.isWord($0.text) })
                } else {
                    run.append(contentsOf: word)
                }
            }
            flush()
        }
        return (cues, removed, corrections)
    }

    /// What a muted name is written as in the captions and the transcript files (PLAN section 5).
    static let mutedWord = "[name]"

    /// "00:15:46,160"
    static func stamp(_ seconds: Double, separator: String) -> String {
        let ms = Int((max(0, seconds) * 1000).rounded())
        let h = ms / 3_600_000, m = (ms / 60_000) % 60, s = (ms / 1000) % 60, x = ms % 1000
        return String(format: "%02d:%02d:%02d", h, m, s) + separator + String(format: "%03d", x)
    }

    /// The cues as an .srt, in Parakeet's own layout.
    static func srt(_ cues: [TranscriptFiles.Cue]) -> String {
        cues.enumerated().map { index, cue in
            "\(index + 1)\n\(stamp(cue.start, separator: ",")) --> \(stamp(cue.end, separator: ","))\n\(cue.text)\n"
        }.joined(separator: "\n")
    }

    /// The cues as a .vtt, in Parakeet's own layout.
    static func vtt(_ cues: [TranscriptFiles.Cue]) -> String {
        "WEBVTT\n\n" + cues.map { "\(stamp($0.start, separator: ".")) --> \(stamp($0.end, separator: "."))\n\($0.text)\n" }.joined(separator: "\n")
    }

    /// The words alone, as one block of text, like Parakeet's .txt.
    static func text(_ cues: [TranscriptFiles.Cue]) -> String {
        cues.map(\.text).joined(separator: " ")
    }
}
