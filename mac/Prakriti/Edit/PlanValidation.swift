import Foundation

// The edit plan checked in Swift before it is saved and before anything is made from it (v2 part M8a,
// docs/v2/research-edit-engine.md 3.4, rules 1 to 6; v1's quote check, generalized). A plan that fails any rule is
// refused whole: nothing is written from it, and the step says which rule and where.
//
// 1. Every word id exists in the transcript, and the transcript's hash is the plan's.
// 2. Every span's text is the transcript's words for its range (case and spacing aside).
// 3. Spans are in order and do not overlap; each span's ends sit in the gaps next to its first and last word (within
//    0.25 s of the refined word times); every cut is on a frame boundary; the plan's own kept words and the spans agree.
// 4. Key phrases and hook lines are word for word (none exist until M9; a span with a role but no text fails).
// 5. The people Ivan left out stay out: no kept time overlaps a stretch cut for them, and his own trim and cuts likewise.
// 6. Chapters, when there are any: three or more, the first at the first kept word, each at least 10 s long.
// 7. The picture (v2 part M9a): every punch-in and push-in lies inside its span, at a scale from 1 to 2 that never runs past
//    the frame, no two overlap, and a held ending (at most 10 s) follows the last span.

enum PlanValidation {
    struct Problem: Error, Equatable, Sendable {
        let rule: Int
        let line: String
    }

    static let tolerance = 0.25

    static func check(_ plan: EditPlan, words: PlanWords) -> [Problem] {
        var problems: [Problem] = []
        let all = words.words
        func word(_ id: String) -> PlanWord? { PlanWord.index(of: id).flatMap { all.indices.contains($0) ? all[$0] : nil } }

        // Rule 1.
        if plan.schema != EditPlan.schemaName { problems.append(Problem(rule: 1, line: "The plan is not a \(EditPlan.schemaName) plan.")) }
        if plan.transcriptSHA256 != words.transcriptSHA256 {
            problems.append(Problem(rule: 1, line: "The transcript changed since the plan was made."))
        }
        var ids = plan.spans.flatMap { [$0.from, $0.to] } + plan.words.map(\.id) + plan.removed.flatMap { ($0.words ?? []) + ($0.keptTake ?? []) }
        ids += plan.checks.map(\.at) + plan.chapters.map(\.at)
        for id in Set(ids) where word(id) == nil {
            problems.append(Problem(rule: 1, line: "The word \(id) is not in the transcript."))
        }
        guard problems.isEmpty else { return problems }

        let refined = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func start(_ i: Int) -> Double { refined[all[i].id]?.in ?? all[i].start }
        func end(_ i: Int) -> Double { refined[all[i].id]?.out ?? all[i].end }

        // Rules 2 and 3.
        var previousOut = -Double.infinity
        var previousLast = -1
        var keptIDs: [String] = []
        for span in plan.spans {
            guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to), a <= b else {
                problems.append(Problem(rule: 3, line: "Span \(span.id) runs backwards."))
                continue
            }
            if PlanWords.comparable(span.text) != PlanWords.comparable(PlanWords.text(all[a...b])) {
                problems.append(Problem(rule: 2, line: "Span \(span.id)'s words are not the transcript's."))
            }
            if span.in < previousOut - 1e-6 || a <= previousLast || span.out <= span.in {
                problems.append(Problem(rule: 3, line: "Span \(span.id) overlaps the span before it."))
            }
            let before = a > 0 ? end(a - 1) : 0
            let after = b + 1 < all.count ? start(b + 1) : plan.sourceDuration
            if span.in < before - tolerance || span.in > start(a) + tolerance {
                problems.append(Problem(rule: 3, line: "Span \(span.id) starts at \(TimeText.string(span.in)), away from its first word."))
            }
            if span.out > after + tolerance || span.out < end(b) - tolerance {
                problems.append(Problem(rule: 3, line: "Span \(span.id) ends at \(TimeText.string(span.out)), away from its last word."))
            }
            let atEnd = abs(span.out - plan.frameDuration.below(plan.sourceDuration)) < 1e-6
            if !plan.frameDuration.isBoundary(span.in) || (!plan.frameDuration.isBoundary(span.out) && !atEnd) {
                problems.append(Problem(rule: 3, line: "Span \(span.id) is not cut on a frame."))
            }
            keptIDs += (a...b).map { all[$0].id }
            previousOut = span.out
            previousLast = b
        }
        // Every word is kept by one span or taken out by one item, never both, never neither.
        var removedIDs: [String] = []
        for item in plan.removed {
            guard let ids = item.words, let a = ids.first.flatMap(PlanWord.index(of:)), let b = ids.last.flatMap(PlanWord.index(of:)), a <= b else { continue }
            removedIDs += (a...b).map { all[$0].id }
        }
        if Set(keptIDs).count != keptIDs.count || !Set(keptIDs).isDisjoint(with: removedIDs) || keptIDs.count + removedIDs.count != all.count {
            problems.append(Problem(rule: 3, line: "The kept and removed words do not add up to the transcript: \(keptIDs.count) kept, \(removedIDs.count) taken out, \(all.count) said."))
        }
        if plan.words.map(\.id) != all.map(\.id) {
            problems.append(Problem(rule: 3, line: "The plan's word times are not the transcript's words."))
        }
        // Every removed stretch on frames and outside the spans.
        for item in plan.removed {
            let atEnd = abs(item.to - plan.sourceDuration) < 1e-6
            if !plan.frameDuration.isBoundary(item.from) || (!plan.frameDuration.isBoundary(item.to) && !atEnd) {
                problems.append(Problem(rule: 3, line: "The \(item.kind.rawValue) at \(TimeText.string(item.from)) is not cut on a frame."))
            }
            if plan.spans.contains(where: { $0.in < item.to - 1e-6 && $0.out > item.from + 1e-6 }) {
                problems.append(Problem(rule: 3, line: "The \(item.kind.rawValue) at \(TimeText.string(item.from)) is inside a kept span."))
            }
        }

        // Rule 4: a span with another role must carry its exact words (checked by rule 2); no hook without text.
        for span in plan.spans where span.role != "main" && span.text.isEmpty {
            problems.append(Problem(rule: 4, line: "Span \(span.id) is a \(span.role) without its words."))
        }

        // Rule 5: forced time is never kept.
        var forced = plan.people.cuts
        if let s = plan.basis.edits.start, s > 0 { forced.append(TimeRange(start: 0, end: s)) }
        if let e = plan.basis.edits.end, e < plan.sourceDuration { forced.append(TimeRange(start: e, end: plan.sourceDuration)) }
        forced += plan.basis.edits.cuts
        for f in forced where f.end > f.start {
            if let span = plan.spans.first(where: { $0.in < f.end - 0.001 && $0.out > f.start + 0.001 }) {
                let whose = plan.people.cuts.contains(f) ? "someone you chose to leave out" : "your trim or a cut"
                problems.append(Problem(rule: 5, line: "Span \(span.id) keeps \(TimeText.string(max(span.in, f.start))) to \(TimeText.string(min(span.out, f.end))), which is \(whose)."))
            }
        }

        // Rule 6.
        if !plan.chapters.isEmpty {
            if plan.chapters.count < 3 { problems.append(Problem(rule: 6, line: "Fewer than three chapters.")) }
            if plan.chapters.first?.at != plan.spans.first?.from { problems.append(Problem(rule: 6, line: "The first chapter is not at the start.")) }
            let times = plan.chapters.compactMap { PlanWord.index(of: $0.at).map(start) }
            for (a, b) in zip(times, times.dropFirst()) where b - a < 10 {
                problems.append(Problem(rule: 6, line: "A chapter at \(TimeText.string(a)) is under 10 s long."))
            }
        }
        // Rule 7.
        var framed: [(Double, Double)] = []
        for item in plan.visual {
            guard let span = plan.spans.first(where: { $0.id == item.span }) else {
                problems.append(Problem(rule: 7, line: "A \(item.kind) names span \(item.span), which the plan does not keep."))
                continue
            }
            switch item.kind {
            case EditPlan.Visual.punchIn, EditPlan.Visual.pushIn:
                let scale = item.kind == EditPlan.Visual.punchIn ? item.scale : item.to
                guard let a = item.in, let b = item.out, let scale, let c = item.center, c.count == 2 else {
                    problems.append(Problem(rule: 7, line: "A \(item.kind) in span \(span.id) is missing its times, scale or middle."))
                    continue
                }
                if a < span.in - 1e-6 || b > span.out + 1e-6 || b <= a {
                    problems.append(Problem(rule: 7, line: "A \(item.kind) at \(TimeText.string(a)) runs outside span \(span.id)."))
                }
                let half = 0.5 / max(scale, 1)
                if scale < 1 || scale > 2 || c[0] < half - 1e-3 || c[0] > 1 - half + 1e-3 || c[1] < half - 1e-3 || c[1] > 1 - half + 1e-3 {
                    problems.append(Problem(rule: 7, line: "A \(item.kind) at \(TimeText.string(a)) frames past the edge of the picture."))
                }
                if framed.contains(where: { $0.0 < b - 1e-6 && $0.1 > a + 1e-6 }) {
                    problems.append(Problem(rule: 7, line: "Two zooms overlap at \(TimeText.string(a))."))
                }
                framed.append((a, b))
            case EditPlan.Visual.hold:
                if span.id != plan.spans.last?.id || (item.seconds ?? 0) <= 0 || (item.seconds ?? 0) > 10 {
                    problems.append(Problem(rule: 7, line: "The held ending is not after the last span, or is not between 0 and 10 s."))
                }
            default:
                problems.append(Problem(rule: 7, line: "The plan holds a picture item Prakriti does not make yet (\(item.kind))."))
            }
        }
        return problems
    }
}
