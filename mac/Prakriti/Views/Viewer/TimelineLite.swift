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
    let duration: Double
    /// The moment playing, on the original's clock, or nil (nothing played yet, or inside an intro).
    let position: Double?
    let selected: TimelineSpan?
    let choose: (TimelineSpan) -> Void

    static let height: CGFloat = 28

    var body: some View {
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline: what stays and what goes")
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
