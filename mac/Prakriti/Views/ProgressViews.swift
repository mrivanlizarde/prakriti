import AppKit
import SwiftUI

// How a make's progress is drawn (v2 part M4a, design spec 3.6.1): a ring on the card, a bar in the list, the
// inspector and the Activity window, always with the percent and the time left in words. Plain shapes only:
// a ring is two circles, a bar is the system's own progress view (never a gauge, a dial or a drawn reel).

/// A determinate ring: the track and the part done, from the top, clockwise.
struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 16
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension ProgressRing {
    /// The same ring as a picture, for the toolbar. Measured 12 Oct: the ring drawn as SwiftUI shapes inside a
    /// toolbar button made the next Command-Option-I after hiding the inspector go unheard (`make look`'s keys
    /// check failed 3 of 3 runs); as an image, the button behaves like the others. Drawn in whole percent, so it
    /// is made again at most a hundred times a make.
    @MainActor
    static func image(_ fraction: Double, size: CGFloat = 16, lineWidth: CGFloat = 2.5) -> NSImage {
        let percent = Int((min(1, max(0, fraction)) * 100).rounded(.down))
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = inset.width / 2
            let track = NSBezierPath(ovalIn: inset)
            track.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.18).setStroke()
            track.stroke()
            let done = NSBezierPath()
            done.appendArc(withCenter: center, radius: radius, startAngle: 90,
                           endAngle: 90 - 360 * max(0.02, Double(percent) / 100), clockwise: true)
            done.lineWidth = lineWidth
            done.lineCapStyle = .round
            NSColor.controlAccentColor.setStroke()
            done.stroke()
            return true
        }
    }
}

/// "64%, about 6 min left": the percent and the time left, in one line.
enum ProgressWords {
    static func line(_ snapshot: ProgressSnapshot) -> String {
        "\(snapshot.percent)%, " + snapshot.timeLeftText.lowercasedFirst
    }

    /// "Making the episode audio, step 5 of 9."
    static func stage(_ snapshot: ProgressSnapshot) -> String {
        snapshot.stepCount > 1 ? "\(snapshot.stageName), step \(snapshot.stepNumber) of \(snapshot.stepCount)." : "\(snapshot.stageName)."
    }

    /// Read aloud by VoiceOver: "Making the episode audio, step 5 of 9, 64 percent, about 6 min left."
    static func spoken(_ snapshot: ProgressSnapshot) -> String {
        "\(snapshot.stageName), step \(snapshot.stepNumber) of \(snapshot.stepCount), \(snapshot.percent) percent, \(snapshot.timeLeftText.lowercasedFirst)."
    }
}

/// The inspector's status block while a recording is made (design spec 3.6.1): the stage, "Step 5 of 9", a
/// bar, the percent and time left, what it waits on when stalled, the latest line in monospaced type, and
/// Pause and Stop.
struct ProgressBlock: View {
    let recording: Recording
    let snapshot: ProgressSnapshot
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.stageName)
                .font(AppFont.headline)
            Text("Step \(snapshot.stepNumber) of \(snapshot.stepCount)")
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
            ProgressView(value: snapshot.overall)
                .accessibilityLabel("Progress")
                .accessibilityValue("\(snapshot.percent) percent")
            Text(ProgressWords.line(snapshot))
                .font(AppFont.numbers)
            if let waiting = snapshot.waitingOn {
                Label {
                    Text(waiting).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "hourglass").font(AppFont.body).foregroundStyle(.orange)
                }
            }
            if let plan = planLines {
                // The plan before rendering (v2 part M9c, design spec 3.5.3): once the edit is planned, what it does, in plain
                // lines, while the video is made, with Stop below.
                VStack(alignment: .leading, spacing: 4) {
                    Text("The plan").font(AppFont.headline)
                    Text(plan).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if let line = snapshot.logLine {
                Text(line)
                    .font(AppFont.path)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityLabel("Latest line: \(line)")
            }
            ProgressButtons(recording: recording, snapshot: snapshot)
        }
        .accessibilityElement(children: .contain)
    }

    /// The plan's lines, once this make has planned the edit and is making the rest.
    private var planLines: String? {
        guard !snapshot.finished, let stage = snapshot.stage, stage != .planEdit,
              let step = recording.latestRun?.steps.first(where: { $0.name == PipelineStep.planEdit.title && $0.state == .done }) else { return nil }
        return step.detail
    }
}

/// Pause or Resume, and Stop, for the make running now or a recording waiting in line.
struct ProgressButtons: View {
    let recording: Recording
    var snapshot: ProgressSnapshot?
    @Environment(AppModel.self) private var model

    var body: some View {
        let runner = model.runner
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if runner.canResume(recording) {
                    Button("Resume") { runner.resume(recording) }
                } else {
                    Button("Pause") { runner.pause(recording) }
                        .disabled(!runner.canPause(recording))
                }
                Button("Stop") { runner.stop(recording) }
                    .disabled(!runner.canStop(recording))
            }
            if let snapshot, !snapshot.canPause, !snapshot.finished {
                Text("Writing cannot be paused once it has started. Stop ends this make, and the files from the last make stay as they were.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
