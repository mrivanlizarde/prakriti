import CoreGraphics
import Foundation

// The edit plan checked in Swift before it is saved and before anything is made from it (v2 part M8a,
// docs/v2/research-edit-engine.md 3.4, rules 1 to 6; v1's quote check, generalized). A plan that fails any rule is
// refused whole: nothing is written from it, and the step says which rule and where.
//
// 1. Every word id exists in the transcript, and the transcript's hash is the plan's.
// 2. Every span's text is the transcript's words for its range (case and spacing aside).
// 3. Spans are in order and do not overlap; each span's ends sit in the gaps next to its first and last word (within
//    0.25 s of the refined word times); every cut is on a frame boundary; the plan's own kept words and the spans agree.
// 4. Key phrases and the opening line are word for word (a span with a role but no text fails). The opening line (v2 part M9d)
//    comes first, is made only of time the talk itself keeps (each of its spans inside one of the talk's), and lasts 3 to 20 s.
// 5. The people Ivan left out stay out: no kept time overlaps a stretch cut for them, and his own trim and cuts likewise.
// 6. Chapters, when there are any: three or more, the first at the start, each at least 10 s long (on the video's own clock
//    since v2 part M9d).
// 7. The picture (v2 part M9a): every punch-in and push-in lies inside its span, at a scale from 1 to 2 that never runs past
//    the frame, no two overlap, and a held ending (at most 10 s) follows the last span. Text (v2 part M9b): every title and
//    lower third starts inside its span, has words, is shown for more than 0 and at most 10 s and ends before the held
//    ending, sits inside title safe, and no two overlap in time. Key phrases and term cards (v2 part M9d) as well, and each shows
//    exactly the words it names (case, punctuation and accents aside), never over the opening line. The held moment lies inside
//    one of the talk's spans (nothing cut inside it).
// 8. Moments from another recording (v2 part M12b): each was added by Ivan (`addedBy: "ivan"`), comes from another recording, is that
//    recording's own words word for word with its ends in the gaps next to its first and last word, on frames, 5 to 45 s of words,
//    sits between two of the talk's spans (never first, never last), carries no zoom, and everyone seen or heard in it is, as Ivan's
//    choices stand NOW, on Include with a release ("A moment from Sun 6 Sep now includes someone who is hidden. Remove it or change
//    their choice."). A moment that cannot be checked against its recording fails (fail closed). The date label is a text like the
//    others and sits on its moment.

enum PlanValidation {
    struct Problem: Error, Equatable, Sendable {
        let rule: Int
        let line: String
    }

    static let tolerance = 0.25

    static func check(_ plan: EditPlan, words: PlanWords, inserts: [MomentInsert] = []) -> [Problem] {
        var problems: [Problem] = []
        let all = words.words
        func word(_ id: String) -> PlanWord? { PlanWord.index(of: id).flatMap { all.indices.contains($0) ? all[$0] : nil } }

        // Rule 1.
        if plan.schema != EditPlan.schemaName { problems.append(Problem(rule: 1, line: "The plan is not a \(EditPlan.schemaName) plan.")) }
        if plan.transcriptSHA256 != words.transcriptSHA256 {
            problems.append(Problem(rule: 1, line: "The transcript changed since the plan was made."))
        }
        var ids = plan.ownSpans.flatMap { [$0.from, $0.to] } + plan.words.map(\.id) + plan.removed.flatMap { ($0.words ?? []) + ($0.keptTake ?? []) }
        ids += plan.checks.map(\.at) + plan.chapters.map(\.at)
        for id in Set(ids) where word(id) == nil {
            problems.append(Problem(rule: 1, line: "The word \(id) is not in the transcript."))
        }
        guard problems.isEmpty else { return problems }

        let refined = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func start(_ i: Int) -> Double { refined[all[i].id]?.in ?? all[i].start }
        func end(_ i: Int) -> Double { refined[all[i].id]?.out ?? all[i].end }

        // Rules 2 and 3, the talk's own spans in order; the opening line's checked on its own below.
        var previousOut = -Double.infinity
        var previousLast = -1
        var keptIDs: [String] = []
        func edges(_ span: EditPlan.Span, _ a: Int, _ b: Int) {
            if PlanWords.comparable(span.text) != PlanWords.comparable(PlanWords.text(all[a...b])) {
                problems.append(Problem(rule: 2, line: "Span \(span.id)'s words are not the transcript's."))
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
        }
        for span in plan.mainSpans {
            guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to), a <= b else {
                problems.append(Problem(rule: 3, line: "Span \(span.id) runs backwards."))
                continue
            }
            if span.in < previousOut - 1e-6 || a <= previousLast || span.out <= span.in {
                problems.append(Problem(rule: 3, line: "Span \(span.id) overlaps the span before it."))
            }
            edges(span, a, b)
            keptIDs += (a...b).map { all[$0].id }
            previousOut = span.out
            previousLast = b
        }
        // The opening line (v2 part M9d): first in the plan, in order, each span inside one of the talk's, 3 to 20 s in all.
        let hooks = plan.hookSpans
        if !hooks.isEmpty {
            if plan.spans.prefix(hooks.count).contains(where: { !$0.isHook }) {
                problems.append(Problem(rule: 4, line: "The opening line is not at the start of the plan."))
            }
            var lastOut = -Double.infinity
            for span in hooks {
                guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to), a <= b else {
                    problems.append(Problem(rule: 4, line: "Span \(span.id) of the opening line runs backwards."))
                    continue
                }
                edges(span, a, b)
                if span.in < lastOut - 1e-6 || span.out <= span.in {
                    problems.append(Problem(rule: 4, line: "Span \(span.id) of the opening line overlaps the span before it."))
                }
                if !plan.mainSpans.contains(where: { $0.in <= span.in + 1e-6 && $0.out >= span.out - 1e-6 }) {
                    problems.append(Problem(rule: 4, line: "Span \(span.id) of the opening line holds time the talk does not keep."))
                }
                lastOut = span.out
            }
            let seconds = hooks.reduce(0) { $0 + $1.out - $1.in }
            if seconds < 3 - 1e-6 || seconds > 20 + 1e-6 {
                problems.append(Problem(rule: 4, line: String(format: "The opening line is %.1f s, outside 3 to 20 s.", seconds)))
            }
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
            if plan.ownSpans.contains(where: { $0.in < item.to - 1e-6 && $0.out > item.from + 1e-6 }) {
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
            if let span = plan.ownSpans.first(where: { $0.in < f.end - 0.001 && $0.out > f.start + 0.001 }) {
                let whose = plan.people.cuts.contains(f) ? "someone you chose to leave out" : "your trim or a cut"
                problems.append(Problem(rule: 5, line: "Span \(span.id) keeps \(TimeText.string(max(span.in, f.start))) to \(TimeText.string(min(span.out, f.end))), which is \(whose)."))
            }
        }

        // Rule 6.
        if !plan.chapters.isEmpty {
            if plan.chapters.count < 3 { problems.append(Problem(rule: 6, line: "Fewer than three chapters.")) }
            if plan.chapters.allSatisfy({ $0.seconds != nil }) {
                // On the video's own clock (v2 part M9d).
                let times = plan.chapters.compactMap(\.seconds)
                if times.first != 0 { problems.append(Problem(rule: 6, line: "The first chapter is not at 0:00.")) }
                for (a, b) in zip(times, times.dropFirst()) where b - a < 10 {
                    problems.append(Problem(rule: 6, line: "A chapter at \(TimeText.string(a)) of the video is under 10 s long."))
                }
                if let last = times.last, EditTimeline(plan: plan).duration - last < 10 {
                    problems.append(Problem(rule: 6, line: "The last chapter is under 10 s long."))
                }
            } else {
                if plan.chapters.first?.at != plan.spans.first?.from { problems.append(Problem(rule: 6, line: "The first chapter is not at the start.")) }
                let times = plan.chapters.compactMap { PlanWord.index(of: $0.at).map(start) }
                for (a, b) in zip(times, times.dropFirst()) where b - a < 10 {
                    problems.append(Problem(rule: 6, line: "A chapter at \(TimeText.string(a)) is under 10 s long."))
                }
            }
        }
        // The held moment (v2 part M9d): inside one of the talk's spans, so nothing is cut inside it.
        if let held = plan.held, !plan.mainSpans.contains(where: { $0.in <= held.start + 1e-6 && $0.out >= held.end - 1e-6 }) {
            problems.append(Problem(rule: 3, line: "The held moment at \(TimeText.string(held.start)) has a cut inside it."))
        }
        // Rule 7.
        var framed: [(Double, Double, String)] = []
        var texts: [(Int64, Int64)] = []
        let timeline = EditTimeline(plan: plan)
        for item in plan.visual {
            guard let span = plan.spans.first(where: { $0.id == item.span }) else {
                problems.append(Problem(rule: 7, line: "A \(item.kind) names span \(item.span), which the plan does not keep."))
                continue
            }
            if span.isInsert && item.kind != OverlayKind.dateLabel.rawValue {
                problems.append(Problem(rule: 8, line: "A \(item.kind) is on the moment from another recording \(span.id), which carries only its date."))
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
                // On the video's own clock: the opening line repeats time the talk keeps, so two zooms may share the original's
                // time and still never overlap in the video (v2 part M9d).
                guard let first = timeline.editFrame(span: span.id, original: a) else {
                    problems.append(Problem(rule: 7, line: "A \(item.kind) at \(TimeText.string(a)) starts outside span \(span.id)."))
                    continue
                }
                // Whole frames: seconds divided by the frame's length land a hair off a whole number.
                let ea = Double(first), eb = ea + ((b - a) / plan.frameDuration.seconds).rounded()
                if let other = framed.first(where: { $0.0 < eb - 0.5 && $0.1 > ea + 0.5 }) {
                    problems.append(Problem(rule: 7, line: String(format: "Two zooms overlap at %@ (%@ and %@ in span %@, frames %.0f to %.0f).", TimeText.string(a),
                                                                  other.2, item.kind, span.id, ea, eb)))
                }
                framed.append((ea, eb, String(format: "%@ in span %@, frames %.0f to %.0f", item.kind, span.id, ea, eb)))
            case EditPlan.Visual.hold:
                if span.id != plan.spans.last?.id || (item.seconds ?? 0) <= 0 || (item.seconds ?? 0) > 10 {
                    problems.append(Problem(rule: 7, line: "The held ending is not after the last span, or is not between 0 and 10 s."))
                }
            case EditPlan.Visual.title, EditPlan.Visual.lowerThird, EditPlan.Visual.keyPhrase, EditPlan.Visual.term, OverlayKind.dateLabel.rawValue:
                let name: String = switch item.kind {
                case EditPlan.Visual.title: "title"
                case EditPlan.Visual.lowerThird: "name on screen"
                case EditPlan.Visual.keyPhrase: "key phrase"
                case OverlayKind.dateLabel.rawValue: "date label"
                default: "term card"
                }
                if item.kind == OverlayKind.dateLabel.rawValue && !span.isInsert {
                    problems.append(Problem(rule: 8, line: "A date label is on span \(span.id), which is not a moment from another recording."))
                }
                guard let a = item.in, let seconds = item.seconds, let box = item.box, box.count == 4,
                      let lines = item.lines, !lines.isEmpty, lines.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
                    problems.append(Problem(rule: 7, line: "A \(name) in span \(span.id) is missing its time, length, box or words."))
                    continue
                }
                guard let start = timeline.editFrame(span: span.id, original: a) else {
                    problems.append(Problem(rule: 7, line: "A \(name) at \(TimeText.string(a)) starts outside span \(span.id)."))
                    continue
                }
                let end = start + Int64((seconds / plan.frameDuration.seconds).rounded())
                if seconds <= 0 || seconds > 10 || end > timeline.keptFrames {
                    problems.append(Problem(rule: 7, line: "A \(name) at \(TimeText.string(a)) is not between 0 and 10 s, or runs into the end."))
                }
                let rect = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
                if rect.width <= 0 || rect.height <= 0 || !OverlayLayout.titleSafe.insetBy(dx: -1e-3, dy: -1e-3).contains(rect) {
                    problems.append(Problem(rule: 7, line: "A \(name) at \(TimeText.string(a)) sits outside the title-safe area."))
                }
                if texts.contains(where: { $0.0 < end && $0.1 > start }) {
                    problems.append(Problem(rule: 7, line: "Two texts overlap at \(TimeText.string(a))."))
                }
                texts.append((start, end))
                // Key phrases and term cards (v2 part M9d): the words they name, exactly, and never over the opening line.
                if item.kind == EditPlan.Visual.keyPhrase || item.kind == EditPlan.Visual.term {
                    guard let ids = item.words, ids.count == 2, let x = PlanWord.index(of: ids[0]), let y = PlanWord.index(of: ids[1]), x <= y, y < all.count,
                          sameWords(lines.joined(separator: " "), PlanWords.text(all[x...y])) else {
                        problems.append(Problem(rule: 4, line: "A \(name) at \(TimeText.string(a)) does not show the words said there."))
                        continue
                    }
                    if span.isHook || start < timeline.hookFrames {
                        problems.append(Problem(rule: 7, line: "A \(name) at \(TimeText.string(a)) is over the opening line."))
                    }
                }
            default:
                problems.append(Problem(rule: 7, line: "The plan holds a picture item Prakriti does not make yet (\(item.kind))."))
            }
        }
        problems += checkInserts(plan, inserts: inserts)
        return problems
    }

    /// Rule 8, the moments from other recordings (v2 part M12b).
    static func checkInserts(_ plan: EditPlan, inserts: [MomentInsert]) -> [Problem] {
        var problems: [Problem] = []
        let frame = plan.frameDuration
        for (k, span) in plan.spans.enumerated() where span.isInsert {
            let day = span.sourceDate.map { Format.dayLabel($0) } ?? "another day"
            if span.addedBy != AddedMoment.byIvan {
                problems.append(Problem(rule: 8, line: "Span \(span.id) is a moment from another recording that you did not add."))
                continue
            }
            if span.source == plan.recording {
                problems.append(Problem(rule: 8, line: "Span \(span.id) is a moment from this same recording."))
            }
            // Between two of the talk's spans: never first, never last, never inside the opening line.
            let before = plan.spans[..<k].last { !$0.isInsert }, after = plan.spans[(k + 1)...].first { !$0.isInsert }
            if before == nil || before?.isHook == true || after == nil || after?.isHook == true {
                problems.append(Problem(rule: 8, line: "The moment from \(day) is not between two parts of the talk."))
            }
            if !frame.isBoundary(span.in) || !frame.isBoundary(span.out) || span.out <= span.in {
                problems.append(Problem(rule: 8, line: "The moment from \(day) is not cut on a frame."))
            }
            if let j = span.join, j < 0 || j > 30 { problems.append(Problem(rule: 8, line: "The moment from \(day) has a join of \(j) frames.")) }
            if let c = span.colour, c.count != 3 || c.contains(where: { abs($0 - 1) > MomentInserts.mostGain + 1e-6 }) {
                problems.append(Problem(rule: 8, line: "The moment from \(day) has a colour match past what Prakriti allows."))
            }
            // Against its own recording, as it is now.
            guard let insert = inserts.first(where: { $0.name == span.source && ($0.original?.path ?? "") == (span.sourceFile ?? "")
                && $0.moment.window.firstWord == PlanWord.index(of: span.from) && $0.moment.window.lastWord == PlanWord.index(of: span.to) }) else {
                problems.append(Problem(rule: 8, line: "The moment from \(day) could not be checked against its own recording, so it is not used."))
                continue
            }
            if let refusal = MomentInserts.refusal(insert) {
                problems.append(Problem(rule: 8, line: refusal))
                continue
            }
            guard let source = insert.words?.words, let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to), a <= b, b < source.count else {
                problems.append(Problem(rule: 8, line: "The words of the moment from \(day) are not in its recording's transcript."))
                continue
            }
            if PlanWords.comparable(span.text) != PlanWords.comparable(PlanWords.text(source[a...b]))
                || span.words?.map(\.id) != (a...b).map({ source[$0].id }) || span.text.split(separator: " ").count != b - a + 1 {
                problems.append(Problem(rule: 2, line: "The words of the moment from \(day) are not its recording's words."))
            }
            let previousEnd = a > 0 ? source[a - 1].end : 0
            let nextStart = b + 1 < source.count ? source[b + 1].start : source[b].end + 1
            if span.in < previousEnd - tolerance || span.in > source[a].start + tolerance || span.out > nextStart + tolerance || span.out < source[b].end - tolerance {
                problems.append(Problem(rule: 8, line: "The moment from \(day) does not start and end in the gaps around its words."))
            }
            let spoken = source[b].end - source[a].start
            if spoken < MomentWindows.shortest - 0.05 || spoken > MomentWindows.longest + 0.05 {
                problems.append(Problem(rule: 8, line: String(format: "The moment from %@ is %.1f s of words, outside 5 to 45 s.", day, spoken)))
            }
        }
        return problems
    }

    /// Two texts are the same words: case, punctuation and accents aside (a term card spells "pranayama" as the list does).
    static func sameWords(_ a: String, _ b: String) -> Bool {
        func words(_ t: String) -> [String] {
            t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).split(whereSeparator: \.isWhitespace)
                .map { PlanWord.normalize(String($0)) }.filter { !$0.isEmpty }
        }
        return words(a) == words(b)
    }
}
