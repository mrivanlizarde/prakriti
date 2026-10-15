import SwiftUI

/// Timeline-lite (v2 part M3b, design spec 3.4.3): a map of what stays and what goes, over the whole
/// original, not an editor. Kept time is a filled bar in the accent; time the trim or a cut takes out is the
/// same shape outlined only, with its reason symbol when it is 24 pt wide or more (the trim and cuts `scissors`;
/// on the Original with an edit plan, v2 part M8a, also `pause`, `ellipsis.bubble`, `arrow.uturn.backward` and
/// `person.fill.questionmark`), so kept and removed
/// differ by fill, never by color alone. A 2 pt accent line follows the player; it is not a handle. Click a
/// span to play from its start and see it above the inspector's tabs, with Restore or Remove.
///
/// Never skeuomorphic (Ivan's rule, START_HERE Mac warning 43): no film frames, no waveform, no drawn
/// scrubber, no draggable playhead. The system player is the only scrubber.
struct TimelineLite: View {
    let spans: [TimelineSpan]
    /// What the edit adds, as symbols under the spans (v2 part M9d, design spec 3.4.3's marks lane): punch-ins and push-ins, text
    /// and the title, the opening line and chapter starts. Empty: no lane.
    var marks: [TimelineMark] = []
    let duration: Double
    /// The moment playing, on the original's clock, or nil (nothing played yet, or inside an intro).
    let position: Double?
    let selected: TimelineSpan?
    let choose: (TimelineSpan) -> Void

    static let height: CGFloat = 28
    /// The marks lane under the spans (design spec 3.4.3: 20 pt), with 8 pt between: 56 pt in all with the spans, 64 with the
    /// position line's overhang.
    static let marksHeight: CGFloat = 20
    static let gap: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: marks.isEmpty ? 0 : Self.gap) {
            spansLane
            if !marks.isEmpty { marksLane }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline: what stays and what goes")
    }

    /// The marks: one symbol each at its moment, never closer than a symbol's width (the first of a crowd is shown).
    private var marksLane: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(TimelineMark.spaced(marks, width: width, duration: duration, apart: 16)) { mark in
                    Image(systemName: mark.kind.symbol)
                        .font(AppFont.label)
                        .foregroundStyle(.appSecondary)
                        .frame(width: 16, height: Self.marksHeight)
                        .offset(x: min(max(0, x(mark.time, width) - 8), max(0, width - 16)))
                        .accessibilityElement()
                        .accessibilityLabel(mark.line)
                        .quickHelp(mark.line, article: "editorial-direction")
                }
            }
        }
        .frame(height: Self.marksHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What the edit adds")
    }

    private var spansLane: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(spans) { span in
                    let left = x(span.start, width)
                    let w = max(2, x(span.end, width) - left)
                    SpanShape(span: span, width: w, isSelected: span == selected)
                        .frame(width: w, height: Self.height)
                        .offset(x: left)
                        .contentShape(Rectangle())
                        .onTapGesture { choose(span) }
                        .accessibilityElement()
                        .accessibilityLabel(span.line)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { choose(span) }
                        .quickHelp(span.line + (span.isRemoved ? " Click to play from it and see it in the inspector, with Restore."
                                                               : " Click to play from it and see it in the inspector, with Remove."),
                                   article: "reviewing-and-approving")
                }
                if let position, duration > 0 {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: Self.height + 8)
                        .offset(x: min(max(0, x(position, width) - 1), width - 2), y: -4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: Self.height)
    }

    private func x(_ t: Double, _ width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(max(0, t), duration) / duration) * width
    }
}

/// One span: filled when kept, outlined when removed.
private struct SpanShape: View {
    let span: TimelineSpan
    let width: CGFloat
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        ZStack {
            if span.isRemoved {
                shape.strokeBorder(AppColor.secondaryText, lineWidth: 1.5)
                if width >= 24 {
                    Image(systemName: span.symbol)
                        .font(AppFont.label)
                        .foregroundStyle(.appSecondary)
                        .accessibilityHidden(true)
                }
            } else {
                shape.fill(Color.accentColor.opacity(isSelected ? 1 : 0.8))
            }
            if isSelected {
                shape.strokeBorder(Color.primary, lineWidth: 2)
            }
        }
        .padding(.horizontal, width > 6 ? 1 : 0)
    }
}

/// One thing the edit adds, at its moment on the original's clock (v2 part M9d, design spec 3.4.3).
struct TimelineMark: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case zoom, text, transition, chapter, opening

        /// Abstract shapes only (never skeuomorphic).
        var symbol: String {
            switch self {
            case .zoom: "plus.magnifyingglass"
            case .text: "textformat"
            case .transition: "rectangle.on.rectangle"
            case .chapter: "bookmark"
            case .opening: "quote.opening"
            }
        }
    }

    let kind: Kind
    let time: Double
    /// One sentence for Quick Help and VoiceOver: "A punch-in at 4:12."
    let line: String
    var id: String { "\(kind.rawValue)-\(Int(time * 1000))" }

    /// The marks of a plan: punch-ins and push-ins, every text, the opening line where it is in the talk, and each chapter's start.
    static func marks(plan: EditPlan) -> [TimelineMark] {
        var out: [TimelineMark] = []
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for item in plan.visual {
            guard let at = item.in else { continue }
            switch item.kind {
            case EditPlan.Visual.punchIn: out.append(TimelineMark(kind: .zoom, time: at, line: "A punch-in at \(TimeText.string(at))."))
            case EditPlan.Visual.pushIn: out.append(TimelineMark(kind: .zoom, time: at, line: "A slow push-in from \(TimeText.string(at))."))
            case EditPlan.Visual.title: out.append(TimelineMark(kind: .text, time: at, line: "The title on screen at \(TimeText.string(at))."))
            case EditPlan.Visual.lowerThird: out.append(TimelineMark(kind: .text, time: at, line: "The teacher's name on screen at \(TimeText.string(at))."))
            case EditPlan.Visual.keyPhrase: out.append(TimelineMark(kind: .text, time: at, line: "A key phrase on screen at \(TimeText.string(at))."))
            case EditPlan.Visual.term: out.append(TimelineMark(kind: .text, time: at, line: "A term on screen at \(TimeText.string(at))."))
            default: break
            }
        }
        if let hook = plan.hook, let at = times[hook.from]?.in {
            out.append(TimelineMark(kind: .opening, time: at, line: String(format: "The opening line, %.0f s from %@, plays first.", hook.seconds, TimeText.string(at))))
        }
        for chapter in plan.chapters {
            guard let at = times[chapter.at]?.in else { continue }
            out.append(TimelineMark(kind: .chapter, time: at, line: "Chapter \u{201C}\(chapter.title)\u{201D} starts at \(TimeText.string(at))."))
        }
        return out.sorted { $0.time < $1.time }
    }

    /// The marks with room to draw: a mark closer than `apart` points to the one before is left out, except a chapter or the
    /// opening line, which always shows (it replaces what it would cover).
    static func spaced(_ marks: [TimelineMark], width: CGFloat, duration: Double, apart: CGFloat) -> [TimelineMark] {
        guard duration > 0, width > 0 else { return [] }
        func x(_ t: Double) -> CGFloat { CGFloat(min(max(0, t), duration) / duration) * width }
        var out: [TimelineMark] = []
        for mark in marks {
            if let last = out.last, x(mark.time) - x(last.time) < apart {
                let strong: (Kind) -> Bool = { $0 == .chapter || $0 == .opening }
                if strong(mark.kind) && !strong(last.kind) { out[out.count - 1] = mark }
                continue
            }
            out.append(mark)
        }
        return out
    }
}
