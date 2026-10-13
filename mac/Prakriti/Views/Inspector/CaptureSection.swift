import SwiftUI

/// The Checks tab's Capture section (v2 part M4b, docs/v2/design-spec.md 3.5.4): how the recording was made,
/// one row per check (a symbol, what was checked, the measured value, the limit in words), and under anything
/// short of a pass the capture tip and a link to the Help article that explains it. A recording found before
/// the capture check existed has none; it offers Check Capture instead of checking by itself (docs/v2/PLAN.md
/// rule 2.1.7: an upgrade never starts work on recordings that already exist).
struct CaptureSection: View {
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            if let report = recording.capture {
                Text(report.summary)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Checked " + Format.dayAndTime(report.measuredAt) + ". Nothing here changes what is made; it is for the next recording.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // What to change comes first, so it is the first thing read; then every measurement, in the file's order.
                ForEach(report.warnings) { finding in
                    CaptureFindingRow(finding: finding)
                }
                ForEach(report.findings.filter { finding in !report.warnings.contains { $0.id == finding.id } }) { finding in
                    CaptureFindingRow(finding: finding)
                }
            } else if model.captureChecking.contains(recording.id) {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking how it was recorded").font(AppFont.body)
                }
            } else {
                RowNote(recording.status == .found || recording.status == .working
                        ? "The capture check runs first, once the file is complete."
                        : "Not checked. This recording was found before Prakriti checked how each recording was made.")
                if let problem = model.captureProblems[recording.id] {
                    Text(problem)
                        .font(AppFont.secondary)
                        .foregroundStyle(AppColor.problemText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if recording.status != .found && recording.status != .working {
                    Button("Check Capture") { model.checkCapture(recording) }
                        .font(AppFont.body)
                }
            }
        } header: {
            SectionHeader("Capture")
        }
    }
}

/// One capture finding.
struct CaptureFindingRow: View {
    let finding: CaptureFinding
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: finding.level.symbol)
                .font(AppFont.body)
                .foregroundStyle(finding.level.tint)
                .frame(width: Metrics.symbolWidth)
                .accessibilityLabel(finding.level.title)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text(finding.value)
                    .font(AppFont.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Limit: " + finding.limit)
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let tip = finding.tip {
                    Text("Tip: " + tip)
                        .font(AppFont.secondaryEmphasis)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let help = finding.help, let title = CaptureCheck.helpTitles[help] {
                    Button {
                        model.openHelp(article: help)
                    } label: {
                        Label(title, systemImage: "questionmark.circle")
                            .font(AppFont.secondary)
                            .foregroundStyle(AppColor.accentText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Help")
                }
            }
        }
        .padding(.vertical, 2)
    }
}

extension CaptureFinding.Level {
    var tint: Color {
        switch self {
        case .pass: .green
        case .warn: .orange
        case .fail: .red
        }
    }
}
