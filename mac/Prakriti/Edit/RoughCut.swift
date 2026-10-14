import Foundation

// The rough cut (v2 part M8a, docs/v2/research-edit-engine.md 1.2 to 1.7): all code, no model. It reads the words and
// the envelope and decides, between every two words it keeps, what time goes: a pause shortened, a filler, a stutter, a
// restart, the trim and cuts Ivan made, and the speech of anyone he chose to leave out. Every cut lands on a video frame
// and in quiet sound, or it is not made. The plan (`EditPlan`) is written from what this returns.
//
// The rules, each with its reason:
// - Word ends are clamped to the sound: a word ends where speech has been off for 150 ms inside it (or at its last
//   sound, when the quiet at the end of its span is shorter), and starts at its first sound if Parakeet placed it in
//   silence (research 1.3: Parakeet's ends run into the pauses after them).
// - Pauses are shortened, never removed, and built from their own start and end (research 1.4), so the room tone and
//   the breath before the next phrase stay. Inside a sentence: longer than 0.40 s becomes 0.18 s. After a comma or a
//   full stop: longer than 0.60 s becomes 0.35 s. A pause after a breath or practice cue, or a question, is kept up to
//   4 s (the Clear style's protected silence).
// - A cut point must sit 20 dB or more under the speech level for 20 ms around it (research 1.8), inside a quiet stretch
//   at least two video frames long (1.2 step 8), at least 60 ms after the sound of the word before falls to floor + 6 dB
//   and 80 ms before the next word's first sound (the tail and the lead-in, 1.3). Where no such point exists, a filler
//   or restart is kept (a restart becomes a Check moment) and a pause is shortened only as far as it can be. One
//   exception: a stutter said with no gap between its copies ("so so") is cut at the frame in the dip before the second
//   copy, 6 dB or more under the speech level (marked not clean unless it is also 20 dB under), because a stutter is
//   what a person wants gone and there is no quieter place (BUILD-LOG, v2 part M8a, decision 4).
// - Ivan's trim and cuts and the people he left out are never kept, clean or not (research 3.4 rule 5): a word they
//   touch goes whole, and when no quiet point is near, the cut is made at their edge and marked not clean.
// - Every cut is on a frame boundary of the video (33.37 ms at 29.97 fps), so the picture and the sound are cut on the
//   same frame and the timelines of M10 can carry the same edit.

/// The numbers of a style. Only Clear exists in M8a; the others are M9.
struct RoughCutPreset: Sendable, Equatable {
    var name = "clear"
    var insideTarget = 0.18
    var insideTrigger = 0.40
    var sentenceTarget = 0.35
    var sentenceTrigger = 0.60
    /// A protected silence is kept up to this long.
    var protectedLimit = 4.0
    /// A word with less speech than this inside its span was not said there (a click or the tail of the word before).
    var shortestSound = 0.05
    /// Kept before a word's first sound.
    var leadIn = 0.08
    /// Kept after the sound of the word before falls to floor + 6 dB.
    var tail = 0.06
    /// A word's end is where speech has been off this long.
    var endHold = 0.15
    /// Kept before the first word and after the last.
    var keepBeforeFirst = 0.5
    var keepAfterLast = 1.0
    /// A stutter said with no gap is cut in the dip between its copies when the dip is this far under the speech level
    /// (measured 13 Oct on the ums fixture's "so so": its lowest 20 ms at a frame is 6.4 dB under; quiet is 20).
    var stutterDip = 6.0
    /// Off in the Clear style. When set, a filler with no quiet around it is cut in the dips between it and the words
    /// around it, when they are this far under the speech level. Measured, not shipped: see BUILD-LOG, v2 part M8a,
    /// "Fillers run into words" (13 Sep: 10 of 76 "um" and "uh" come out with it off).
    var fillerDip: Double?

    static let clear = RoughCutPreset()

    func target(after closes: PlanWord.Closing) -> Double { closes == .none ? insideTarget : sentenceTarget }
    func trigger(after closes: PlanWord.Closing) -> Double { closes == .none ? insideTrigger : sentenceTrigger }
}

/// A frame rate as the fraction of a second one frame lasts ("1001/30000").
struct FrameDuration: Codable, Equatable, Sendable, CustomStringConvertible {
    var value: Int64
    var timescale: Int64

    static let ntsc30 = FrameDuration(value: 1001, timescale: 30000)
    /// For a recording with no picture: the envelope's own 10 ms.
    static let audioOnly = FrameDuration(value: 1, timescale: 100)

    var seconds: Double { Double(value) / Double(timescale) }
    var description: String { "\(value)/\(timescale)" }

    init(value: Int64, timescale: Int64) {
        self.value = value
        self.timescale = timescale
    }

    /// From a frame rate in frames a second: 29.97 is 1001/30000, 30 is 1/30, 25 is 1/25.
    init(rate: Double) {
        let ntsc = [23.976: 24000, 29.97: 30000, 59.94: 60000]
        if let match = ntsc.first(where: { abs($0.key - rate) < 0.01 }) {
            self.init(value: 1001, timescale: Int64(match.value))
        } else {
            self.init(value: 1, timescale: Int64(rate.rounded()))
        }
    }

    init?(text: String) {
        let parts = text.split(separator: "/").compactMap { Int64($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        self.init(value: parts[0], timescale: parts[1])
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let made = FrameDuration(text: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a frame duration: \(text)"))
        }
        self = made
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    /// The frame boundary nearest `t`, below it, or above it.
    func nearest(_ t: Double) -> Double { (t / seconds).rounded() * seconds }
    func below(_ t: Double) -> Double { (t / seconds + 1e-9).rounded(.down) * seconds }
    func above(_ t: Double) -> Double { (t / seconds - 1e-9).rounded(.up) * seconds }
    /// Whether `t` is on a frame boundary, to a microsecond.
    func isBoundary(_ t: Double) -> Bool { abs(nearest(t) - t) < 1e-6 }
}

/// Why time was taken out. The order is the order of precedence when one stretch holds several.
enum RemovedKind: String, Codable, CaseIterable, Sendable {
    case person, cut, trimmed, restart, stutter, filler, pause

    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// One stretch of time the plan takes out, between two kept words (or before the first, after the last).
struct Removal: Equatable, Sendable {
    var kind: RemovedKind
    var from: Double
    var to: Double
    /// The words inside it, inclusive, or nil when it holds none (a pause).
    var words: ClosedRange<Int>?
    var confidence: Double
    /// The pause left where it was, in seconds, for a pause, filler, stutter or restart.
    var keptSeconds: Double?
    /// Placed where the sound is quiet. False only for Ivan's trim and cuts and the people left out, when no quiet point
    /// was near their edge.
    var clean = true
    var keptTake: ClosedRange<Int>?
    /// The pause it shortens, before, for a pause.
    var pauseWas: Double?
}

/// One stretch kept: a run of kept words, with the time around them that stays.
struct KeptSpan: Equatable, Sendable {
    var start: Double
    var end: Double
    var first: Int
    var last: Int
}

/// A pause between two kept words as the edit leaves it.
struct PlannedPause: Equatable, Sendable {
    /// The kept word before it.
    var after: Int
    var closes: PlanWord.Closing
    var protected: Bool
    /// Its length in the original, between the refined word times, and in the edit.
    var was: Double
    var now: Double
    /// Where it is in the original, between the two words.
    var start: Double
    var end: Double
}

struct RoughCut: Sendable {
    struct Input: Sendable {
        var words: PlanWords
        var envelope: Envelope
        var duration: Double
        var frame: FrameDuration
        var edits = EpisodeEdits()
        /// The stretches cut for the people Ivan left out (`LeaveOut.cuts`, their overlaps included).
        var leftOut: [TimeRange] = []
        var preset = RoughCutPreset.clear
    }

    var refinedStart: [Double] = []
    var refinedEnd: [Double] = []
    /// Words Parakeet placed where there is no speech.
    var soundless: [Bool] = []
    var kept: [KeptSpan] = []
    var removed: [Removal] = []
    var checks: [CheckMoment] = []
    var pauses: [PlannedPause] = []
    /// Proposals the rough cut could not cut cleanly, so kept.
    var keptAnyway: [Proposal] = []

    var keptSeconds: Double { kept.reduce(0) { $0 + $1.end - $1.start } }

    /// Words that start a breath or practice cue, or ask the listener something: the pause after protects.
    static let cueWords: Set<String> = ["inhale", "inhaling", "exhale", "exhaling", "breathe", "breathing", "notice", "pause", "feel", "feeling"]
    static let cuePhrases: [[String]] = [["close", "your", "eyes"], ["let", "that", "land"], ["let", "it", "land"]]

    // MARK: Refining the words

    /// Each word's start moved to its first sound when Parakeet put it in silence, and its end clamped to where speech
    /// has been off for `endHold` inside it. A word with no sound at all inside its span was placed in a silence by
    /// Parakeet (measured 13 Oct, 13 Sep at 4:45: "back" and "to" sit in 1.2 s of room tone, said after it): it is moved
    /// to the edge of the sound nearer to it, the end of the sound before or the start of the sound after, so the silence
    /// it hid becomes a pause the plan can see. A filler is moved the same way (v2 part M8b, 13 Oct): left in its silence and
    /// taken out with it, the "uh" itself stayed in the video, run into the word beside it. Measured by Parakeet on the made
    /// MP4s: 5 of the 10 fillers the 13 Sep plan took out, and 4 of 6 on 6 Sep, were heard again at their joins, and each of
    /// those 9 had no sound in Parakeet's span (-50 to -76 dB) while the sound beside it was speech. Moved onto that sound, a
    /// filler is cut only where it can be cut cleanly, like any other, and the silence is a pause. Only a word with no sound
    /// within 3 s either way stays where it is (`soundless`).
    static func refine(_ words: [PlanWord], envelope: Envelope, preset: RoughCutPreset) -> (starts: [Double], ends: [Double], soundless: [Bool]) {
        var starts: [Double] = [], ends: [Double] = [], soundless: [Bool] = []
        let reach = 3.0
        for word in words {
            var s = word.start, e = max(word.end, word.start + 0.02)
            var moved = false
            let heard = envelope.activeSeconds(from: s, to: e) >= preset.shortestSound
            if heard, let first = envelope.firstActive(from: s, to: e) {
                s = first
                if let off = envelope.offFor(preset.endHold, from: s, to: e), off > s { e = off }
                // And the quiet at the very end of its span, shorter than `endHold`, is not the word either.
                else if let last = envelope.lastActiveEnd(from: s, to: e), last > s { e = last }
            } else {
                let before = envelope.lastActiveEnd(from: max(0, s - reach), to: s)
                let after = envelope.firstActive(from: e, to: e + reach)
                switch (before, after) {
                case let (b?, a?):
                    if s - b <= a - e { (s, e) = (max(b - 0.05, 0), b) } else { (s, e) = (a, a + 0.05) }
                case let (b?, nil): (s, e) = (max(b - 0.05, 0), b)
                case let (nil, a?): (s, e) = (a, a + 0.05)
                case (nil, nil): break
                }
                moved = before != nil || after != nil
            }
            starts.append(s)
            ends.append(max(e, s + 0.02))
            soundless.append(!heard && !moved)
        }
        return (starts, ends, soundless)
    }

    // MARK: The cut

    static func make(_ input: Input) -> RoughCut {
        let words = input.words.words
        let env = input.envelope
        let preset = input.preset
        let frame = input.frame
        var cut = RoughCut()
        let refined = refine(words, envelope: env, preset: preset)
        cut.refinedStart = refined.starts
        cut.refinedEnd = refined.ends
        cut.soundless = refined.soundless
        guard !words.isEmpty else { return cut }

        // Ivan's trim and cuts and the people left out, never overridden (research 3.4 rule 5).
        var forced: [(range: TimeRange, kind: RemovedKind)] = []
        if let start = input.edits.start, start > 0 { forced.append((TimeRange(start: 0, end: start), .trimmed)) }
        if let end = input.edits.end, end < input.duration { forced.append((TimeRange(start: end, end: input.duration), .trimmed)) }
        for c in EpisodeEdits.merged(input.edits.cuts) { forced.append((c, .cut)) }
        for c in input.leftOut where c.end > c.start { forced.append((c, .person)) }
        var forcedWord = [RemovedKind?](repeating: nil, count: words.count)
        for i in words.indices {
            for f in forced where cut.refinedEnd[i] > f.range.start + 0.001 && cut.refinedStart[i] < f.range.end - 0.001 {
                if forcedWord[i].map({ f.kind.rank < $0.rank }) ?? true { forcedWord[i] = f.kind }
            }
        }

        // What the detectors propose, on the words nothing forced takes.
        let open = words.filter { forcedWord[$0.index] == nil }
        let markers = Restarts.markers(words)
        var skip = IndexSet()
        for p in markers.proposals { skip.insert(integersIn: p.first...p.last) }
        let sentences = Restarts.sentenceRestarts(words, skip: skip)
        cut.checks = markers.checks + sentences.checks
        var proposals = markers.proposals + sentences.proposals
            + Restarts.stutters(words, starts: cut.refinedStart, ends: cut.refinedEnd) + Restarts.fillers(open)
        proposals = proposals.filter { p in (p.first...p.last).allSatisfy { forcedWord[$0] == nil } }

        // Join by join, from the first word to the last; a proposal that cannot be cut cleanly is kept and the joins are
        // worked out again without it.
        while true {
            var proposedWord = [RemovedKind?](repeating: nil, count: words.count)
            var proposedConfidence = [Double?](repeating: nil, count: words.count)
            for p in proposals {
                for i in p.first...p.last { proposedConfidence[i] = min(proposedConfidence[i] ?? 1, p.confidence) }
                let kind: RemovedKind = switch p.kind { case .filler: .filler; case .stutter: .stutter; case .restart: .restart }
                for i in p.first...p.last where proposedWord[i].map({ kind.rank < $0.rank }) ?? true { proposedWord[i] = kind }
            }
            let keptWords = words.indices.filter { forcedWord[$0] == nil && proposedWord[$0] == nil }
            guard !keptWords.isEmpty else { return cut }
            var removals: [Removal] = []
            var pauses: [PlannedPause] = []
            var failed: Set<Int> = []
            let anchors: [Int?] = [nil] + keptWords.map { Optional($0) } + [nil]
            for (left, right) in zip(anchors, anchors.dropFirst()) {
                let outcome = join(left: left, right: right, words: words, forcedWord: forcedWord, proposedWord: proposedWord,
                                   proposedConfidence: proposedConfidence, forced: forced, cut: cut, input: input)
                switch outcome {
                case let .removal(removal, pause):
                    removals.append(removal)
                    if let pause { pauses.append(pause) }
                case let .kept(pause):
                    if let pause { pauses.append(pause) }
                case let .infeasible(first, last):
                    for (n, p) in proposals.enumerated() where p.first <= last && p.last >= first { failed.insert(n) }
                }
            }
            if failed.isEmpty {
                cut.removed = removals
                cut.pauses = pauses
                break
            }
            for n in failed.sorted(by: >) {
                let p = proposals.remove(at: n)
                cut.keptAnyway.append(p)
                if p.kind == .restart {
                    cut.checks.append(CheckMoment(at: words[p.first].id, kind: .possibleRetake, kept: "both",
                                                  say: "Possible retake at \(Restarts.clock(words[p.first].start)): kept both."))
                }
            }
        }

        // The kept spans: what lies between the removals.
        var spans: [KeptSpan] = []
        var cursor = 0.0
        let keptWords = words.indices.filter { i in
            !cut.removed.contains { r in r.words.map { $0.contains(i) } ?? false }
        }
        var w = 0
        func span(to end: Double) {
            let inside = keptWords[w...].prefix { cut.refinedStart[$0] < end }
            if let first = inside.first, let last = inside.last, end - cursor > 0.0005 {
                spans.append(KeptSpan(start: cursor, end: end, first: first, last: last))
                w += inside.count
            }
        }
        for r in cut.removed.sorted(by: { $0.from < $1.from }) {
            span(to: r.from)
            cursor = r.to
        }
        span(to: frame.below(input.duration))
        cut.kept = spans
        cut.checks.sort { (PlanWord.index(of: $0.at) ?? 0) < (PlanWord.index(of: $1.at) ?? 0) }
        return cut
    }

    enum JoinOutcome {
        case removal(Removal, PlannedPause?)
        case kept(PlannedPause?)
        /// The proposals over these words cannot be cut cleanly.
        case infeasible(Int, Int)
    }

    /// What goes between kept word `left` and kept word `right` (nil: the recording's start or end).
    static func join(left: Int?, right: Int?, words: [PlanWord], forcedWord: [RemovedKind?], proposedWord: [RemovedKind?],
                     proposedConfidence: [Double?], forced: [(range: TimeRange, kind: RemovedKind)], cut: RoughCut, input: Input) -> JoinOutcome {
        let env = input.envelope, preset = input.preset, frame = input.frame, duration = input.duration
        let leftEnd = left.map { cut.refinedEnd[$0] } ?? 0
        let rightStart = right.map { cut.refinedStart[$0] } ?? duration
        let between = ((left.map { $0 + 1 } ?? 0)..<(right ?? words.count))
        let regions = forced.filter { $0.range.end > leftEnd && $0.range.start < rightStart }
        var kind: RemovedKind?
        func consider(_ k: RemovedKind?) { if let k, kind.map({ k.rank < $0.rank }) ?? true { kind = k } }
        for i in between { consider(forcedWord[i] ?? proposedWord[i]) }
        for r in regions { consider(r.kind) }
        let isForced = !regions.isEmpty || between.contains { forcedWord[$0] != nil }

        // The bounds: after the sound of the word before, before the sound of the word after.
        let minC0 = left.map { max(cut.refinedEnd[$0], env.soundEdge(from: cut.refinedEnd[$0], forward: true)) + preset.tail } ?? 0
        let maxC1 = right.map { min(cut.refinedStart[$0] - preset.leadIn, env.soundEdge(from: cut.refinedStart[$0], forward: false) - preset.leadIn) } ?? duration
        let closes = left.map { words[$0].closes } ?? .sentence
        let target = preset.target(after: closes)
        let natural = rightStart - leftEnd

        func quietPoint(in lo: Double, _ hi: Double, near desired: Double) -> Double? {
            guard hi >= lo else { return nil }
            var best: Double?
            var t = frame.above(lo)
            while t <= hi + 1e-9 {
                if env.isQuiet(around: t), env.quietRun(at: t) >= 2 * frame.seconds - 1e-9,
                   best.map({ abs(t - desired) < abs($0 - desired) }) ?? true {
                    best = t
                }
                t += frame.seconds
            }
            return best
        }

        if !between.isEmpty || !regions.isEmpty {
            // Words or forced time to take out: the removal must hold all of it.
            var lo = rightStart, hi = leftEnd
            // A filler with no sound under it is taken out with the time around it, wherever the cut falls.
            for i in between where !(cut.soundless[i] && forcedWord[i] == nil) {
                lo = min(lo, cut.refinedStart[i], env.soundEdge(from: cut.refinedStart[i], forward: false))
                hi = max(hi, cut.refinedEnd[i], env.soundEdge(from: cut.refinedEnd[i], forward: true))
            }
            for r in regions {
                lo = min(lo, max(0, r.range.start))
                hi = max(hi, min(duration, r.range.end))
            }
            lo = max(lo, leftEnd)
            hi = min(hi, rightStart)
            var clean = true
            let c0: Double
            if left == nil {
                c0 = 0
            } else if let point = quietPoint(in: minC0, lo - 0.01, near: leftEnd + target / 2) {
                c0 = point
            } else if isForced {
                c0 = frame.below(lo)
                clean = false
            } else if let left, let under = preset.fillerDip, between.allSatisfy({ proposedWord[$0] == .filler }),
                      let dip = dipPoint(from: cut.refinedEnd[left] - 0.03, to: cut.refinedStart[between.lowerBound] + 0.05,
                                         envelope: env, frame: frame, under: under) {
                // A filler run into the words around it, when Ivan turns on `fillerDip`: cut in the dips around it.
                c0 = dip
                clean = env.isQuiet(around: dip)
            } else {
                return .infeasible(between.lowerBound, between.upperBound - 1)
            }
            var c1: Double
            if right == nil {
                c1 = duration
            } else if let point = quietPoint(in: hi + 0.01, maxC1, near: rightStart - (left == nil ? preset.keepBeforeFirst : target / 2)) {
                c1 = point
            } else if isForced {
                c1 = frame.above(hi)
                clean = false
            } else if let right, between.allSatisfy({ proposedWord[$0] == .stutter }),
                      let dip = dipPoint(from: cut.refinedEnd[between.upperBound - 1], to: (cut.refinedStart[right] + cut.refinedEnd[right]) / 2,
                                         envelope: env, frame: frame, under: preset.stutterDip) {
                // A stutter said with no gap ("so so"): the cut goes in the dip just before the second copy's first sound.
                c1 = dip
                clean = env.isQuiet(around: dip)
            } else if let right, let under = preset.fillerDip, between.allSatisfy({ proposedWord[$0] == .filler }),
                      let dip = dipPoint(from: cut.refinedEnd[between.upperBound - 1] - 0.05, to: cut.refinedStart[right] + 0.03,
                                         envelope: env, frame: frame, under: under) {
                c1 = dip
                clean = env.isQuiet(around: dip)
            } else {
                return .infeasible(between.lowerBound, between.upperBound - 1)
            }
            if c1 <= c0 {
                // Only forced time can get here (a sliver between two kept words): it is taken all the same, one frame wide.
                guard isForced else { return .infeasible(between.lowerBound, between.upperBound - 1) }
                c1 = c0 + frame.seconds
                clean = false
            }
            let keptPause = (left == nil || right == nil) ? nil : (c0 - leftEnd) + (rightStart - c1)
            let wordRange = between.isEmpty ? nil : between.lowerBound...(between.upperBound - 1)
            let confidence = between.map { forcedWord[$0] != nil ? 1.0 : (proposedConfidence[$0] ?? 1.0) }.min() ?? 1.0
            var removal = Removal(kind: kind ?? .pause, from: c0, to: c1, words: wordRange, confidence: confidence, keptSeconds: keptPause, clean: clean)
            if kind == .restart, let right { removal.keptTake = right...(words[right...].firstIndex { $0.endsSentence } ?? right) }
            let pause = keptPause.map { PlannedPause(after: left ?? 0, closes: closes, protected: false, was: natural, now: $0, start: leftEnd, end: rightStart) }
            return .removal(removal, pause)
        }

        // Nothing to take out but time: the start, the end, or a pause between two words.
        if left == nil {
            // Silence before the first word, beyond what is kept.
            guard rightStart > preset.keepBeforeFirst + frame.seconds,
                  let c1 = quietPoint(in: frame.seconds, maxC1, near: rightStart - preset.keepBeforeFirst) else { return .kept(nil) }
            return .removal(Removal(kind: .trimmed, from: 0, to: c1, words: nil, confidence: 1), nil)
        }
        guard let left else { return .kept(nil) }
        guard right != nil else {
            // Silence after the last word, beyond what is kept.
            guard duration - leftEnd > preset.keepAfterLast + frame.seconds,
                  let c0 = quietPoint(in: minC0, frame.below(duration) - frame.seconds, near: leftEnd + preset.keepAfterLast) else { return .kept(nil) }
            return .removal(Removal(kind: .trimmed, from: c0, to: duration, words: nil, confidence: 1), nil)
        }
        let protected = isProtected(after: left, words: words)
        let keep = protected ? preset.protectedLimit : target
        let trigger = protected ? preset.protectedLimit : preset.trigger(after: closes)
        let unchanged = PlannedPause(after: left, closes: closes, protected: protected, was: natural, now: natural, start: leftEnd, end: rightStart)
        guard natural > trigger else { return .kept(unchanged) }
        var length = frame.nearest(natural - keep)
        while length >= frame.seconds - 1e-9 {
            // Both ends quiet, the removal inside the bounds, the pause's own start and end kept around it.
            var best: Double?
            var t = frame.above(minC0)
            let desired = leftEnd + keep / 2
            while t + length <= maxC1 + 1e-9 {
                if env.isQuiet(around: t), env.isQuiet(around: t + length), env.quietRun(at: t) >= 2 * frame.seconds - 1e-9,
                   env.quietRun(at: t + length) >= 2 * frame.seconds - 1e-9, best.map({ abs(t - desired) < abs($0 - desired) }) ?? true {
                    best = t
                }
                t += frame.seconds
            }
            if let c0 = best {
                let c1 = frame.nearest(c0 + length)
                var pause = unchanged
                pause.now = natural - (c1 - c0)
                return .removal(Removal(kind: .pause, from: c0, to: c1, words: nil, confidence: 1, keptSeconds: pause.now, pauseWas: natural), pause)
            }
            length -= frame.seconds
        }
        return .kept(unchanged)
    }

    /// The frame boundary in [from, to] where the 20 ms around it are quietest, when that is at least `under` dB under the
    /// speech level: the dip between two copies of a word said with no gap, or (with `fillerDip`) around a filler.
    static func dipPoint(from: Double, to: Double, envelope env: Envelope, frame: FrameDuration, under: Double) -> Double? {
        var best: (t: Double, level: Double)?
        var t = frame.above(from)
        while t <= to + 1e-9 {
            let a = max(0, env.frameIndex(t - 0.010)), b = min(env.levels.count - 1, env.frameIndex(t + 0.010 - 1e-9))
            if a <= b {
                let level = env.levels[a...b].max() ?? 0
                if best.map({ level < $0.level }) ?? true { best = (t, level) }
            }
            t += frame.seconds
        }
        guard let best, best.level <= env.speech - under else { return nil }
        return best.t
    }

    /// A pause after a breath or practice cue in the words since the last punctuation, or after a question.
    static func isProtected(after index: Int, words: [PlanWord]) -> Bool {
        if words[index].closes == .question { return true }
        var first = index
        while first > 0, words[first - 1].closes == .none { first -= 1 }
        let clause = words[first...index].map(\.norm)
        if clause.contains(where: cueWords.contains) { return true }
        return cuePhrases.contains { !Restarts.find($0, in: clause).isEmpty }
    }
}
