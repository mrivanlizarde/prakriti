import Foundation

// The edited video's captions (v2 part M8b, research-edit-engine.md 2.7 and 6.1): a sidecar `.srt`, plain UTF-8, on the
// edited clock, from the plan's own word times (`EditPlan.words`, refined to the sound in M8a). Only words the plan keeps
// are captioned; a name said aloud that Ivan muted is written as [name], as in every transcript file (Mac warning for
// M6c).
//
// The rules (Netflix's, as research 2.7 gives them): at most 42 characters a line and two lines a caption, at most 20
// characters a second where the talk allows it (see `mostBehind`), on screen at least 5/6 s and at most 7 s. A caption starts with its first word and may stay on
// into the pause after its last word, up to the next caption, so a short line is not gone before it is read. Where the
// words come faster than 20 characters a second, captions fall behind them a little and catch up at the next pause. Captions
// break at the end of a sentence where they can, else at a comma, else where the next word would not fit.

enum Captions {
    static let lineLength = 42
    static let lines = 2
    static let charactersPerSecond = 20.0
    static let shortest = 5.0 / 6.0
    static let longest = 7.0
    /// The furthest a caption starts after its first word: further, and the words on screen no longer go with the voice.
    /// Measured 13 Oct on the 13 Sep talk (255 captions): allowed to run late without a limit, captions fell 3.5 s behind and
    /// one still went over 20 characters a second; held to 1 s, 21 go over (the fastest 27), because the edited talk is
    /// faster than 20 characters a second in places. Prakriti never shortens the words, so the speed is reported, and the
    /// captions stay with the voice.
    static let mostBehind = 1.0
    /// How long before its first word a caption may appear.
    static let lead = 0.25
    /// A pause this long between two words always starts a new caption.
    static let pauseBreak = 1.0

    struct Cue: Equatable, Sendable {
        var start: Double
        var end: Double
        var lines: [String]
        /// How far the caption starts after its first word is said (0 when it is on time).
        var behind: Double = 0
        var text: String { lines.joined(separator: " ") }
        var characters: Int { text.count }
        var perSecond: Double { Double(characters) / max(0.001, end - start) }
    }

    struct Word: Equatable, Sendable {
        var text: String
        var start: Double
        var end: Double
        var endsSentence: Bool
        var endsClause: Bool
    }

    /// The kept words on the edited clock, in order. A word the plan took out is not here; a word cut by a span edge keeps
    /// the part inside the span.
    static func words(plan: EditPlan, words: PlanWords, timeline: EditTimeline) -> [Word] {
        let all = words.words
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let muted = plan.people.mutes
        var out: [Word] = []
        for span in plan.spans {
            guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to), a <= b, b < all.count else { continue }
            for i in a...b {
                let word = all[i]
                let t = times[word.id]
                let start = max(t?.in ?? word.start, span.in), end = min(t?.out ?? word.end, span.out)
                guard let s = timeline.editTime(start), let e = timeline.editTime(max(start, end)) else { continue }
                let isMuted = muted.contains { word.position >= $0.start && word.position <= $0.end }
                let text = isMuted ? EpisodeTranscript.mutedWord + trailingPunctuation(word.text) : word.text
                out.append(Word(text: text, start: s, end: max(s, e), endsSentence: word.endsSentence, endsClause: word.closes == .clause))
            }
        }
        return out
    }

    static func trailingPunctuation(_ text: String) -> String {
        String(text.reversed().prefix { ".,;:?!".contains($0) }.reversed())
    }

    /// The captions for the kept words, `duration` being the edited video's length.
    static func cues(_ words: [Word], duration: Double, lead: Double = Captions.lead, behind: Double = Captions.mostBehind, sentenceBreak: Bool = true) -> [Cue] {
        var groups: [[Word]] = []
        var current: [Word] = []
        func text(_ ws: [Word]) -> String { ws.map(\.text).joined(separator: " ") }
        for word in words {
            if let last = current.last {
                let candidate = current + [word]
                let fits = layout(text(candidate)) != nil
                let tooLong = word.end - current[0].start > longest
                let paused = word.start - last.end >= pauseBreak
                // At a sentence's end, a caption already half full closes; a new one starts with the next sentence.
                let sentenceDone = sentenceBreak && last.endsSentence && text(current).count >= lineLength / 2
                if !fits || tooLong || paused || sentenceDone {
                    // Break back at the last comma or full stop inside, when the caption would otherwise end mid-phrase.
                    if !fits || tooLong, let cut = current.lastIndex(where: { $0.endsSentence || $0.endsClause }), cut < current.count - 1, cut >= current.count / 2 {
                        groups.append(Array(current[...cut]))
                        current = Array(current[(cut + 1)...])
                    } else {
                        groups.append(current)
                        current = []
                    }
                }
            }
            current.append(word)
        }
        if !current.isEmpty { groups.append(current) }

        // Times: each caption needs its characters at 20 a second (and 5/6 s at least). Where the words come faster than that
        // (Gabriel's run of words with the pauses shortened), a caption may start up to `lead` before its first word, once
        // the one before has gone, and otherwise waits for it: captions fall a little behind the words and catch up at the
        // next pause. Measured 13 Oct on the 13 Sep talk: with each caption pinned to its words, 78 of 255 went over 20
        // characters a second (the fastest 32.9).
        var cues: [Cue] = []
        var previousEnd = 0.0
        for group in groups {
            guard let first = group.first, let last = group.last, let lines = layout(text(group)) else { continue }
            let chars = Double(lines.joined(separator: " ").count)
            let need = max(shortest, chars / charactersPerSecond)
            var start = max(previousEnd, first.start - lead)
            if start > first.start + behind {
                start = first.start + behind
                if var before = cues.popLast() { before.end = min(before.end, start); cues.append(before) }
            }
            let end = min(duration, max(start + need, min(last.end, start + longest)))
            guard end > start else { continue }
            cues.append(Cue(start: start, end: end, lines: lines, behind: max(0, start - first.start)))
            previousEnd = end
        }
        return cues
    }

    /// The text as at most two lines of at most 42 characters, broken at a space so the lines are as even as they can be;
    /// nil when it does not fit.
    static func layout(_ text: String) -> [String]? {
        if text.count <= lineLength { return [text] }
        guard text.count <= lineLength * lines + 1 else { return nil }
        let words = text.split(separator: " ").map(String.init)
        var best: [String]?
        var bestDifference = Int.max
        for split in 1..<words.count {
            let a = words[..<split].joined(separator: " "), b = words[split...].joined(separator: " ")
            guard a.count <= lineLength, b.count <= lineLength else { continue }
            let difference = abs(a.count - b.count)
            if difference < bestDifference { best = [a, b]; bestDifference = difference }
        }
        return best
    }

    static func srt(_ cues: [Cue]) -> String {
        cues.enumerated().map { index, cue in
            "\(index + 1)\n\(EpisodeTranscript.stamp(cue.start, separator: ",")) --> \(EpisodeTranscript.stamp(cue.end, separator: ","))\n"
                + cue.lines.joined(separator: "\n") + "\n"
        }.joined(separator: "\n")
    }

    // MARK: Reading a caption file back (the Ready checklist reads the file, not these values)

    struct Measured: Codable, Equatable, Sendable {
        var cues: Int
        var longestLine: Int
        var mostLines: Int
        var fastest: Double
        var overSpeed: Int
        var shortestShown: Double
        var longestShown: Double
        var inOrder: Bool
        var lastEnd: Double
    }

    /// The .srt as written, parsed again. Nil when it does not parse.
    static func measure(srt: String) -> Measured? {
        let blocks = srt.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .newlines) }.filter { !$0.isEmpty }
        guard !blocks.isEmpty else { return nil }
        var m = Measured(cues: 0, longestLine: 0, mostLines: 0, fastest: 0, overSpeed: 0, shortestShown: .infinity, longestShown: 0, inOrder: true, lastEnd: 0)
        var previousEnd = -1.0
        for (index, block) in blocks.enumerated() {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 3, Int(lines[0]) == index + 1 else { return nil }
            let times = lines[1].components(separatedBy: " --> ")
            guard times.count == 2, let start = stamp(times[0]), let end = stamp(times[1]), end > start else { return nil }
            let text = Array(lines[2...])
            let chars = Double(text.joined(separator: " ").count)
            m.cues += 1
            m.longestLine = max(m.longestLine, text.map(\.count).max() ?? 0)
            m.mostLines = max(m.mostLines, text.count)
            let speed = chars / (end - start)
            m.fastest = max(m.fastest, speed)
            if speed > charactersPerSecond + 0.05 { m.overSpeed += 1 }
            m.shortestShown = min(m.shortestShown, end - start)
            m.longestShown = max(m.longestShown, end - start)
            if start < previousEnd - 0.0005 { m.inOrder = false }
            previousEnd = end
            m.lastEnd = end
        }
        return m
    }

    /// "00:01:02,345" in seconds.
    static func stamp(_ text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}
