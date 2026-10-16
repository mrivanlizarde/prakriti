import AVFoundation
import CoreImage
import Foundation

// Moments from another recording, added (v2 part M12b, docs/v2/PLAN.md M12, design spec 3.8, research-edit-engine.md 3.4 and 3.5):
// REQUEST item 9, "added to the video at hand but not always and not as a rule". Ivan clicks Add on a moment Find Supporting Moments
// found (M12a); it is kept with the recording's direction (`RecordingDirection.moments`) and goes into the video at the next Make
// Again, never before and never on its own:
//
// 1. `AddedMoment.added(byIvan:)` is the only way a moment joins a recording, and it always says `addedBy: "ivan"`. The plan's
//    `insert` span carries the same, and `PlanValidation` refuses any insert span that does not.
// 2. At every plan (every Make Again) each moment is read again from its own recording (`MomentInsert`, resolved by the app from the
//    store): its transcript, and its people as Ivan has them NOW. Anyone in the moment no longer on Include, or a person newly marked
//    "no release", and the plan is refused with "A moment from Sun 6 Sep now includes someone who is hidden. Remove it or change their
//    choice." (PLAN M12, "Re-checked at every render"). The video step checks again before it draws a frame.
// 3. `place` puts each moment between two sentences of this recording (after the point's last sentence, at the first join of the plan
//    that ends a sentence, never at the very end), on the other recording's own frames, with its date label on screen for its first
//    3 s unless Ivan switched it off (design spec C6), the style's join (Clear and Story a 12-frame cross dissolve, Calm 15, Energetic a
//    hard cut, research 2.4), and the colour match (`colour`, measured, research 2.8). Texts that would run across it are left out
//    and the chapters after it move by its length.
// 4. The sound of each recording is measured on its own and matched before the join (`VideoAudio`).

/// A moment Ivan added to a recording.
struct AddedMoment: Codable, Equatable, Sendable, Identifiable {
    static let byIvan = "ivan"

    var sourceID: UUID
    /// "Sun 6 Sep 2026, Talk with Gabriel".
    var sourceLabel: String
    var sourceDate: Date
    var window: MomentWindow
    /// The other recording's own words, as found.
    var words: String
    var why: String
    /// Where it goes: after the sentence that ends at this time, on this recording's clock, and that sentence's last words.
    var after: Double
    var afterWords: String
    var addedBy: String
    var addedAt: Date
    /// The date on screen for its first 3 s (design spec C6), on unless Ivan switched it off.
    var showDate: Bool

    var id: String { sourceID.uuidString + ":" + window.key }
    var seconds: Double { window.seconds }

    /// Ivan's Add: the only way a moment becomes part of a recording.
    static func added(byIvan moment: SupportingMoment, showDate: Bool, at date: Date) -> AddedMoment {
        AddedMoment(sourceID: moment.sourceID, sourceLabel: moment.sourceLabel, sourceDate: moment.sourceDate, window: moment.window, words: moment.words,
                    why: moment.why, after: moment.after, afterWords: moment.afterWords, addedBy: byIvan, addedAt: date, showDate: showDate)
    }
}

/// One added moment as a make reads it, from its own recording, at the moment the make starts.
struct MomentInsert: Sendable {
    var moment: AddedMoment
    /// The other recording's name (its file name without the extension), the original, its length.
    var name: String
    var original: URL?
    var duration: Double?
    /// Its transcript as it is now.
    var words: PlanWords?
    /// Who is seen and heard in it, and whether each may be in a moment, from its people file and Ivan's choices of now.
    var people: MomentPeople
    /// Why it could not be read, when it could not.
    var unreadable: String?
}

enum MomentInserts {
    struct Refusal: Error, Equatable, Sendable {
        let reason: String
    }

    /// PLAN M12's line, word for word.
    static func hiddenLine(_ date: Date) -> String {
        "A moment from \(Format.dayLabel(date)) now includes someone who is hidden. Remove it or change their choice."
    }

    /// Why a moment may not go into the video now, or nil.
    static func refusal(_ insert: MomentInsert) -> String? {
        let day = Format.dayLabel(insert.moment.sourceDate)
        if insert.moment.addedBy != AddedMoment.byIvan { return "A moment from \(day) was not added by you, so it is not used." }
        if let reason = insert.unreadable { return "A moment from \(day) could not be read (\(reason)). Remove it, or make that recording again." }
        guard insert.people.checked else {
            return "A moment from \(day) comes from a recording whose people are not checked now. Remove it, or check its people again."
        }
        if insert.people.problem(start: insert.moment.window.start, end: insert.moment.window.end) != nil { return hiddenLine(insert.moment.sourceDate) }
        return nil
    }

    /// What the plan keeps of the moments, so a change makes the plan out of date; nil for none.
    static func signature(_ moments: [AddedMoment]) -> String? {
        moments.isEmpty ? nil : moments.map { "\($0.id)|\($0.showDate ? 1 : 0)" }.joined(separator: ",")
    }

    /// The join for a style (research 2.4): Clear and Story a 12-frame cross dissolve, Calm 15, Energetic a hard cut.
    static func joinFrames(_ style: StyleName) -> Int {
        switch style {
        case .clear, .story: 12
        case .calm: 15
        case .energetic: 0
        }
    }

    /// The frames of a dissolve before and after its cut.
    static func halves(_ join: Int) -> (before: Int64, after: Int64) {
        (Int64(join / 2), Int64(join - join / 2))
    }

    /// The index of the talk's span a moment goes after, splitting a span in the pause after the sentence ending at `after` when the plan
    /// keeps that pause whole. Nil when there is no sentence break between two of the talk's spans to use.
    static func anchor(after: Double, plan: inout EditPlan, words: [PlanWord]) -> Int? {
        let frame = plan.frameDuration
        let refined = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func start(_ i: Int) -> Double { refined[words[i].id]?.in ?? words[i].start }
        func end(_ i: Int) -> Double { refined[words[i].id]?.out ?? words[i].end }
        func isLastOfSentence(_ i: Int) -> Bool { i + 1 >= words.count || words[i + 1].sentence != words[i].sentence || words[i].endsSentence }
        let main = plan.spans.indices.filter { !plan.spans[$0].isHook && !plan.spans[$0].isInsert }
        guard let lastMain = main.last else { return nil }
        // Every sentence break the talk keeps, in order: (span index, word ending the sentence), the span's own end or inside it.
        var breaks: [(span: Int, word: Int)] = []
        for k in main {
            guard let a = PlanWord.index(of: plan.spans[k].from), let b = PlanWord.index(of: plan.spans[k].to), a <= b, b < words.count else { continue }
            for w in a...b where isLastOfSentence(w) && !(k == lastMain && w == b) { breaks.append((k, w)) }
        }
        // The first at or after the point's last sentence, else the last one there is.
        guard let chosen = breaks.first(where: { words[$0.word].end >= after - 0.05 }) ?? breaks.last else { return nil }
        let k = chosen.span
        let span = plan.spans[k]
        guard let b = PlanWord.index(of: span.to) else { return nil }
        if chosen.word == b { return k }
        // Split in the pause after the sentence: on a frame, inside the gap between its last word and the next.
        let w = chosen.word
        let gapStart = end(w), gapEnd = start(w + 1)
        var t = frame.nearest((gapStart + gapEnd) / 2)
        if t < gapStart - 1e-6 || t > gapEnd + 1e-6 { t = frame.above(gapStart) }
        guard t > span.in + frame.seconds, t < span.out - frame.seconds else { return nil }
        // Never through the opening line or the held moment, which must each stay inside one of the talk's spans.
        if plan.hookSpans.contains(where: { $0.in < t - 1e-6 && $0.out > t + 1e-6 }) { return nil }
        if let held = plan.held, held.start < t - 1e-6 && held.end > t + 1e-6 { return nil }
        let id = span.id + "s"
        let first = EditPlan.Span(id: span.id, source: span.source, from: span.from, to: words[w].id, in: span.in, out: EditPlan.round6(t),
                                  role: span.role, text: PlanWords.text(words[(PlanWord.index(of: span.from) ?? w)...w]))
        let second = EditPlan.Span(id: id, source: span.source, from: words[w + 1].id, to: span.to, in: EditPlan.round6(t), out: span.out, role: span.role,
                                   text: PlanWords.text(words[(w + 1)...b]))
        plan.spans[k] = first
        plan.spans.insert(second, at: k + 1)
        // What the picture does after the split belongs to the second half; a zoom across it ends at the split.
        var visual: [EditPlan.Visual] = []
        for var item in plan.visual {
            if item.span == span.id {
                if item.kind == EditPlan.Visual.hold { item.span = id }
                else if let a = item.in, a >= t - 1e-6 { item.span = id }
                else if (item.kind == EditPlan.Visual.punchIn || item.kind == EditPlan.Visual.pushIn), let out = item.out, out > t {
                    item.out = EditPlan.round6(t)
                    if t - (item.in ?? t) < 0.5 { continue }
                    if item.kind == EditPlan.Visual.pushIn { item.seconds = min(item.seconds ?? 0, t - (item.in ?? t)) }
                }
            }
            visual.append(item)
        }
        plan.visual = visual
        return k
    }

    /// The date label's box in a picture `size` big (from the top left, fractions): the top corner, inside title safe.
    static func dateBox(_ text: OverlayText, size: CGSize) -> [Double] {
        let measured = OverlayLayout.size(text)
        let inner = OverlayLayout.inner
        return [inner.minX, inner.minY, Double(measured.width / size.width), Double(measured.height / size.height)].map { ($0 * 10_000).rounded() / 10_000 }
    }

    /// Puts each moment into `plan` (a plan already checked, its picture planned). Throws the first refusal: a moment that may not be
    /// used now stops the plan, so nothing is made from it. Returns lines for the log.
    static func place(_ inserts: [MomentInsert], into plan: inout EditPlan, words: [PlanWord], pictureSize: CGSize) throws -> [String] {
        var notes: [String] = []
        let frame = plan.frameDuration
        let style = StyleName(rawValue: plan.style) ?? .clear
        for (n, insert) in inserts.sorted(by: { $0.moment.after < $1.moment.after }).enumerated() {
            if let refusal = refusal(insert) { throw Refusal(reason: refusal) }
            let moment = insert.moment
            let day = Format.dayLabel(moment.sourceDate)
            guard let source = insert.words, let file = insert.original else {
                throw Refusal(reason: "A moment from \(day) could not be read. Remove it, or make that recording again.")
            }
            let sw = source.words
            let a = moment.window.firstWord, b = moment.window.lastWord
            guard a >= 0, b < sw.count, a <= b, PlanWords.comparable(PlanWords.text(sw[a...b])) == PlanWords.comparable(moment.words) else {
                throw Refusal(reason: "The transcript of the recording of \(day) changed since you added a moment from it. Remove the moment and find it again.")
            }
            // Its ends, on its own frames, with up to 0.25 s of its own room either side, never into the next sentence's words.
            let previousEnd = a > 0 ? sw[a - 1].end : 0
            let nextStart = b + 1 < sw.count ? sw[b + 1].start : sw[b].end + 0.5
            let inTime = max(0, frame.below(sw[a].start - min(0.25, max(0, (sw[a].start - previousEnd) / 2))))
            let outTime = frame.above(sw[b].end + min(0.25, max(0, (nextStart - sw[b].end) / 2)))
            // Where it goes: after the point's last sentence. When the plan already cuts there, at that join; when the sentence ends inside
            // a kept span, that span is split in the pause after the sentence (a join that changes nothing heard or seen). Never after the
            // talk's last span (the held ending stays the talk's own last frame): then at the last sentence break before it.
            guard let k = anchor(after: moment.after, plan: &plan, words: words) else {
                throw Refusal(reason: "There is no place between two sentences of this recording to put the moment from \(day).")
            }
            var at = k + 1
            while at < plan.spans.count && plan.spans[at].isInsert { at += 1 }
            let id = "m\(n + 1)"
            // The join: the style's dissolve where both recordings have the frames it needs on each side, else a hard cut.
            var join = joinFrames(style)
            let (h1, h2) = halves(join)
            let before = plan.spans[at - 1], after = at < plan.spans.count ? plan.spans[at] : nil
            let handles = before.out + Double(h2) * frame.seconds <= plan.sourceDuration - frame.seconds
                && (after.map { $0.in - Double(h1) * frame.seconds >= 0 } ?? false)
                && inTime - Double(h1) * frame.seconds >= 0
                && outTime + Double(h2) * frame.seconds <= (insert.duration ?? (sw.last?.end ?? outTime)) - frame.seconds
                && before.isInsert == false && after?.isInsert == false
            if !handles { join = 0 }
            // Two moments side by side meet with a hard cut.
            if before.isInsert { plan.spans[at - 1].join = 0 }
            let span = EditPlan.Span(id: id, source: insert.name, from: sw[a].id, to: sw[b].id, in: EditPlan.round6(inTime), out: EditPlan.round6(outTime),
                                     role: EditPlan.Span.insert, text: PlanWords.text(sw[a...b]), addedBy: moment.addedBy, reason: moment.why,
                                     sourceFile: file.path, sourceLabel: moment.sourceLabel, sourceDate: moment.sourceDate,
                                     words: (a...b).map { EditPlan.WordTime(id: sw[$0].id, in: EditPlan.round3(sw[$0].start), out: EditPlan.round3(sw[$0].end)) },
                                     colour: nil, join: join)
            plan.spans.insert(span, at: at)
            let timeline = EditTimeline(plan: plan)
            guard let piece = timeline.pieces.first(where: { $0.id == id }) else { continue }
            let startSeconds = timeline.seconds(piece.editFrame), length = timeline.seconds(piece.frames)
            // The chapters after it move by its length.
            for c in plan.chapters.indices {
                if let s = plan.chapters[c].seconds, s >= startSeconds - 1e-6 { plan.chapters[c].seconds = EditPlan.round3(s + length) }
            }
            // A text that would run across its start is left out (its own label is its only text).
            let crossing = plan.visual.filter { item in
                guard item.isText, let start = timeline.editFrame(span: item.span, original: item.in ?? -1) else { return false }
                let end = start + Int64(((item.seconds ?? 0) / frame.seconds).rounded())
                return start < piece.editFrame && end > piece.editFrame
            }
            if !crossing.isEmpty {
                plan.visual.removeAll { item in crossing.contains(item) }
                notes.append("\(Format.count(crossing.count, "text")) that would run into the moment from \(day) left out.")
            }
            if moment.showDate, pictureSize.height > 0 {
                let label = OverlayLayout.dateLabel(moment.sourceDate, height: Double(pictureSize.height))
                plan.visual.append(EditPlan.Visual(span: id, kind: OverlayKind.dateLabel.rawValue, in: span.in, seconds: OverlayKind.dateLabel.motion.total,
                                                   lines: [OverlayLayout.dateText(moment.sourceDate)], box: dateBox(label, size: pictureSize),
                                                   align: OverlayText.Align.leading.rawValue))
            }
            notes.append(String(format: "A moment from %@ added by you (%.1f s) at %@ of the video, after \u{201C}...%@\u{201D}; %@; %@.", day, length,
                                Format.timecode(startSeconds), moment.afterWords, join > 0 ? "\(join)-frame cross dissolve at each end" : "hard cuts",
                                moment.showDate ? "its date on screen for 3 s" : "no date on screen"))
        }
        if !inserts.isEmpty {
            plan.visual.sort { ($0.in ?? .infinity, $0.kind) < ($1.in ?? .infinity, $1.kind) }
            plan.basis.moments = signature(inserts.map(\.moment))
        }
        return notes
    }

    // MARK: The colour match (research 2.8)

    /// The most a colour match moves any channel: a match is a correction between two days of the same room, never a grade.
    static let mostGain = 0.15
    /// A difference smaller than this is left alone.
    static let leastGain = 0.02

    /// Red, green and blue gains that bring the moment's picture to the main recording's around where it goes, measured on the linear
    /// picture as the compositor draws it: the mean colour of 6 frames of each (the main recording's last 10 s before the moment and
    /// first 10 s after it; the moment's whole length). Nil when no channel differs by 2% or more, or a frame cannot be read.
    static func colour(main: URL, around: [TimeRange], source: URL, moment: TimeRange) async -> [Double]? {
        func times(_ ranges: [TimeRange], count: Int) -> [Double] {
            let total = ranges.reduce(0) { $0 + max(0, $1.end - $1.start) }
            guard total > 0 else { return [] }
            return (0..<count).compactMap { i in
                var x = total * (Double(i) + 0.5) / Double(count)
                for r in ranges {
                    let len = max(0, r.end - r.start)
                    if x <= len { return r.start + x }
                    x -= len
                }
                return nil
            }
        }
        guard let a = await meanColour(main, times: times(around, count: 6)), let b = await meanColour(source, times: times([moment], count: 6)) else { return nil }
        let gains = (0..<3).map { c in min(1 + mostGain, max(1 - mostGain, b[c] > 1e-6 ? a[c] / b[c] : 1)) }.map { ($0 * 1000).rounded() / 1000 }
        return gains.contains { abs($0 - 1) >= leastGain } ? gains : nil
    }

    /// The mean colour of the frames of `file` at `times`, linear red, green and blue, or nil.
    static func meanColour(_ file: URL, times: [Double]) async -> [Double]? {
        guard !times.isEmpty else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
        generator.maximumSize = CGSize(width: 640, height: 360)
        let context = CIContext(options: [.cacheIntermediates: false, .name: "Prakriti colour match"])
        var sum = [0.0, 0.0, 0.0]
        var count = 0
        for t in times {
            guard let image = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image else { continue }
            let ci = CIImage(cgImage: image)
            let average = ci.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: ci.extent)])
            var pixel = [Float](repeating: 0, count: 4)
            context.render(average, toBitmap: &pixel, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
            for c in 0..<3 { sum[c] += Double(pixel[c]) }
            count += 1
        }
        return count == 0 ? nil : sum.map { $0 / Double(count) }
    }
}
