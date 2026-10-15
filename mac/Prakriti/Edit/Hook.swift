import Foundation

// The opening line, the "hook" (v2 part M9d, docs/v2/PLAN.md M9; research-edit-engine.md 2.3 and 2.4): the video opens on the
// talk's strongest self-contained line, then the title, then the talk from its real start. The model only proposes: the beats it
// marks as a good opening (`hookCandidate`), with their key lines already found word for word in the transcript (`BeatCheck`).
// Everything else is code, and nothing is ever said that was not said, in an order it was not said in:
//
// 1. **Candidates:** up to three beats the model marked, best first by how motivating and enlightening they are, then the main
//    point's key line when fewer than three were marked. A line in the talk's first 30 s is never used: it would play twice in a
//    row.
// 2. **Whole sentences, else whole clauses:** the key line grows to the sentences it sits in, and to the next sentence while it is
//    shorter than the style's shortest opening; it must then fit the style's length (Clear 5 to 15 s, Energetic 3 to 8 s, Story
//    10 to 20 s); else the key line grown to the clauses around it (comma to comma) until long enough; else the key line alone;
//    else the next candidate.
// 3. **Only what the talk keeps:** the opening line is made of the talk's own kept spans cut down to it (`spans`), so the pauses
//    and fillers the rough cut took out stay out, and anything Ivan cut or anyone left out can never come back through it.
// 4. **Ivan's copy rules:** a line that names money, a price, enrollment or an offer is not used (`CopyRules`).
// 5. **Quiet cuts:** where the line starts or ends inside a kept span, the cut goes on a frame in a quiet stretch of the gap
//    before its first word or after its last (the rough cut's own bar, Mac warning 139); with no such place, the candidate is
//    not used.
//
// The spans come first in the plan with the role `hook` (research 3.4); the same words stay in their place in the talk too.

enum Hook {
    struct Input: Sendable {
        /// The talk's kept spans (the plan's main spans), in order, and the plan's refined word times.
        var spans: [EditPlan.Span]
        var times: [String: EditPlan.WordTime]
        var words: [PlanWord]
        var envelope: Envelope
        var frame: FrameDuration
        /// The beats the plan keeps, in order.
        var beats: [Beat]
        /// How long the opening line may be, in seconds of the video.
        var range: ClosedRange<Double>
        /// The style's pause between sentences: the opening line keeps half of it before its first word and after its last, so the
        /// join into the talk is a sentence's pause, never more.
        var pause: Double = 0.35
    }

    struct Choice: Equatable, Sendable {
        var spans: [EditPlan.Span]
        var beat: String
        var seconds: Double
        /// Where the line is in the talk, on the original's clock.
        var start: Double
    }

    /// A line in the talk's first this many seconds is never the opening line.
    static let notBefore = 30.0

    /// The opening line for these beats, or nil when no candidate fits.
    static func choose(_ input: Input) -> Choice? {
        guard let firstKept = input.spans.first?.in else { return nil }
        let marked = input.beats.filter { $0.hookCandidate && $0.keyLine != nil }
            .sorted { rank($0) > rank($1) || (rank($0) == rank($1) && $0.start < $1.start) }
        var candidates = Array(marked.prefix(3))
        if candidates.count < 3, let thesis = input.beats.first(where: { $0.thesis && $0.keyLine != nil }), !candidates.contains(where: { $0.id == thesis.id }) {
            candidates.append(thesis)
        }
        for beat in candidates {
            guard let key = beat.keyLine, let a = PlanWord.index(of: key.from), let b = PlanWord.index(of: key.to), a <= b, b < input.words.count else { continue }
            for (first, last) in ranges(a, b, words: input.words, times: input.times, range: input.range) {
                // Ivan's copy rules (no money, prices, enrollment or offers) hold for the opening line as for every line written to be
                // seen outside Prakriti (`CopyRules`): a line that breaks one is not used.
                guard start(first, input) >= firstKept + notBefore, CopyRules.flag(PlanWords.text(input.words[first...last])) == nil,
                      let cuts = bounds(first, last, input), let spans = spans(cuts.0, cuts.1, first: first, last: last, input: input) else { continue }
                let seconds = spans.reduce(0) { $0 + $1.out - $1.in }
                guard input.range.contains(seconds) else { continue }
                return Choice(spans: spans, beat: beat.id, seconds: seconds, start: cuts.0)
            }
        }
        return nil
    }

    static func rank(_ beat: Beat) -> Int { beat.score(.motivating) + beat.score(.enlightening) + (beat.thesis ? 1 : 0) }

    static func start(_ i: Int, _ input: Input) -> Double { input.times[input.words[i].id]?.in ?? input.words[i].start }
    static func end(_ i: Int, _ input: Input) -> Double { input.times[input.words[i].id]?.out ?? input.words[i].end }

    /// The word ranges to try for a key line from word `a` to `b`: its whole sentences (and the next ones while too short), then
    /// the key line alone.
    static func ranges(_ a: Int, _ b: Int, words: [PlanWord], times: [String: EditPlan.WordTime], range: ClosedRange<Double>) -> [(Int, Int)] {
        func s(_ i: Int) -> Double { times[words[i].id]?.in ?? words[i].start }
        func e(_ i: Int) -> Double { times[words[i].id]?.out ?? words[i].end }
        var first = a, last = b
        while first > 0 && words[first - 1].sentence == words[a].sentence { first -= 1 }
        while last + 1 < words.count && words[last + 1].sentence == words[b].sentence { last += 1 }
        var out: [(Int, Int)] = [(first, last)]
        var grown = last
        while e(grown) - s(first) < range.lowerBound, grown + 1 < words.count {
            let next = words[grown + 1].sentence
            var end = grown + 1
            while end + 1 < words.count && words[end + 1].sentence == next { end += 1 }
            grown = end
            out.append((first, grown))
        }
        // Whole clauses (v2 part M9d, measured on the 13 Sep talk: Parakeet's sentences run 20 s and more where the teacher joins
        // thoughts with commas, so a whole sentence is too long and the key line alone too short): the key line grown to the
        // clauses around it, a clause at a time on the shorter side, until it is long enough.
        func clauseStart(_ i: Int) -> Bool { i == 0 || words[i - 1].closes != .none }
        func clauseEnd(_ i: Int) -> Bool { words[i].closes != .none || i == words.count - 1 }
        var x = a, y = b
        while x > first && !clauseStart(x) { x -= 1 }
        while y < last && !clauseEnd(y) { y += 1 }
        while e(y) - s(x) < range.lowerBound {
            var back = x - 1
            while back > first && !clauseStart(back) { back -= 1 }
            var ahead = y + 1
            while ahead < grown && !clauseEnd(ahead) { ahead += 1 }
            let canBack = x > first, canAhead = y < grown
            guard canBack || canAhead else { break }
            if canAhead && (!canBack || e(ahead) - e(y) <= s(x) - s(back)) { y = min(ahead, words.count - 1) } else { x = max(back, 0) }
        }
        if e(y) - s(x) <= range.upperBound, (x, y) != (first, last) { out.append((x, y)) }
        if (first, last) != (a, b) { out.append((a, b)) }
        return out
    }

    /// The cuts before word `first` and after word `last`: a kept span's own edge when the span starts or ends there, else a quiet
    /// frame in the gap. Nil when there is none.
    static func bounds(_ first: Int, _ last: Int, _ input: Input) -> (Double, Double)? {
        let firstID = input.words[first].id, lastID = input.words[last].id
        let c0: Double
        if let span = input.spans.first(where: { $0.from == firstID }) {
            c0 = span.in
        } else {
            guard first > 0, let t = quiet(from: end(first - 1, input) + 0.06, to: start(first, input) - 0.08,
                                           near: start(first, input) - max(0.08, input.pause / 2), input) else { return nil }
            c0 = t
        }
        let c1: Double
        if let span = input.spans.first(where: { $0.to == lastID }),
           span.out - end(last, input) <= max(0.06, input.pause / 2) + input.frame.seconds || last + 1 >= input.words.count {
            c1 = span.out
        } else if let span = input.spans.first(where: { $0.to == lastID }) {
            // The span runs on into a long pause after the line (the rough cut keeps the talk's own): cut it short in the quiet.
            guard let t = quiet(from: end(last, input) + 0.06, to: span.out, near: end(last, input) + max(0.06, input.pause / 2), input) else { return nil }
            c1 = t
        } else {
            guard last + 1 < input.words.count, let t = quiet(from: end(last, input) + 0.06, to: start(last + 1, input) - 0.08,
                                                               near: end(last, input) + max(0.06, input.pause / 2), input) else { return nil }
            c1 = t
        }
        return c1 > c0 ? (c0, c1) : nil
    }

    /// A frame in [from, to] where the sound is quiet for two frames, nearest `near` (the rough cut's own bar).
    static func quiet(from: Double, to: Double, near: Double, _ input: Input) -> Double? {
        guard to >= from else { return nil }
        var best: Double?
        var t = input.frame.above(from)
        while t <= to + 1e-9 {
            if input.envelope.isQuiet(around: t), input.envelope.quietRun(at: t) >= 2 * input.frame.seconds - 1e-9,
               best.map({ abs(t - near) < abs($0 - near) }) ?? true {
                best = t
            }
            t += input.frame.seconds
        }
        return best
    }

    /// The talk's kept spans cut down to [c0, c1], as the opening line's spans ("h1", "h2", ...), each with its own words. Nil when
    /// a word of the line is not kept (the line would not be what was said in the talk's own edit).
    static func spans(_ c0: Double, _ c1: Double, first: Int, last: Int, input: Input) -> [EditPlan.Span]? {
        var out: [EditPlan.Span] = []
        var covered = Set<Int>()
        for span in input.spans where span.out > c0 + 1e-6 && span.in < c1 - 1e-6 {
            guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to) else { return nil }
            let lo = max(span.in, c0), hi = min(span.out, c1)
            let inside = (a...b).filter { $0 >= first && $0 <= last && start($0, input) >= lo - 1e-6 && end($0, input) <= hi + 1e-6 }
            guard let x = inside.first, let y = inside.last else { continue }
            covered.formUnion(inside)
            out.append(EditPlan.Span(id: "h\(out.count + 1)", source: span.source, from: input.words[x].id, to: input.words[y].id,
                                     in: EditPlan.round6(lo), out: EditPlan.round6(hi), role: EditPlan.Span.hook,
                                     text: PlanWords.text(input.words[x...y])))
        }
        // Every word of the line that the talk keeps is in it; a word the rough cut took out (a filler) is not, and that is right.
        let keptInLine = Set(input.spans.flatMap { s -> [Int] in
            guard let a = PlanWord.index(of: s.from), let b = PlanWord.index(of: s.to) else { return [] }
            return (a...b).filter { $0 >= first && $0 <= last }
        })
        guard !out.isEmpty, keptInLine == covered else { return nil }
        return out
    }
}

// The held moment (v2 part M9d, research 2.3: "one uncut span of 30 to 60 s for the core teaching, placed where the model marks
// the thesis", the deliberate pause of the grammar): whole sentences of the main point's beat, as long as the style asks, kept as
// recorded (no pause shortened, no filler taken out, like a stretch Ivan restored) and still (one shot, wide, no text over it).

enum HeldMoment {
    /// The stretch of sentences, from the start of the main point's beat, whose length (first word's start to last word's end)
    /// fits `range`; trying each sentence of the beat as the start in turn. Nil when none fits, or the beat is not kept.
    static func choose(beats: [Beat], kept: Set<String>, words: [PlanWord], starts: [Double], ends: [Double], range: ClosedRange<Double>,
                       forced: [TimeRange]) -> TimeRange? {
        guard let thesis = beats.first(where: { $0.thesis && kept.contains($0.id) }),
              let a = PlanWord.index(of: thesis.from), let b = PlanWord.index(of: thesis.to), a <= b, b < words.count else { return nil }
        // Sentence starts inside the beat.
        let sentenceStarts = (a...b).filter { $0 == a || words[$0].sentence != words[$0 - 1].sentence }
        for first in sentenceStarts {
            var last = first
            while last + 1 < words.count && words[last + 1].sentence == words[first].sentence { last += 1 }
            while ends[last] - starts[first] < range.lowerBound, last + 1 < words.count {
                var next = last + 1
                while next + 1 < words.count && words[next + 1].sentence == words[last + 1].sentence { next += 1 }
                last = next
            }
            let stretch = TimeRange(start: starts[first], end: ends[last])
            guard range.contains(stretch.end - stretch.start) else { continue }
            if forced.contains(where: { $0.end > stretch.start && $0.start < stretch.end }) { continue }
            return stretch
        }
        return nil
    }
}
