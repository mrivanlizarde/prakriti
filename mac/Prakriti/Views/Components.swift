import AppKit
import SwiftUI

// Shared pieces. Colors are semantic system colors so light and dark both work; a status is told
// apart by its symbol's shape and its words, never by color alone, and status text stays in the
// primary or secondary text color so it always reads.

extension RecordingStatus {
    var tint: Color {
        switch self {
        case .found, .skipped: .secondary
        case .working: .blue
        case .readyForYourYes: AppColor.accentText
        case .needsADecision: .orange
        case .approved: .green
        case .couldntFinish: .red
        case .approvedCheckFailed: .orange
        }
    }
}

extension StepState {
    var tint: Color {
        switch self {
        case .waiting, .skipped: .secondary
        case .running: .blue
        case .done: .green
        case .failed: .red
        }
    }
}

extension LogLevel {
    var tint: Color {
        switch self {
        case .info: .secondary
        case .attention: .orange
        case .problem: .red
        }
    }
}

extension Recording {
    /// "Sun 13 Sep: Talk with Gabriel". Falls back to the file name until a title is written.
    var displayTitle: String {
        let name = title.isEmpty ? (fileName as NSString).deletingPathExtension : title
        return Format.dayLabel(sessionDate) + ": " + name
    }

    /// One plain sentence under the title in a list.
    var listDetail: String {
        var parts: [String] = []
        if let duration { parts.append(Format.length(duration) + ".") }
        switch status {
        case .found:
            parts.append(statusReason ?? "Waiting to start.")
        case .working:
            parts.append((currentStep ?? "Working") + ".")
        case .readyForYourYes:
            parts.append(statusReason ?? "Ready to listen to.")
        case .needsADecision, .couldntFinish, .skipped:
            if let statusReason { parts.append(statusReason) }
        case .approved:
            if let approvedAt { parts.append("Approved " + Format.dayLabel(approvedAt) + ".") }
        case .approvedCheckFailed:
            parts.append(statusReason ?? "Approved, and a check no longer passes.")
        }
        return parts.joined(separator: " ")
    }
}

/// A status as a symbol and its words.
struct StatusLabel: View {
    let status: RecordingStatus

    var body: some View {
        Label {
            Text(status.title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
        }
        .font(AppFont.secondaryEmphasis)
    }
}

/// One recording in a list: status symbol, title, one plain sentence.
struct RecordingRow: View {
    let recording: Recording
    var showsStatusWords = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: recording.status.symbol)
                .font(AppFont.body)
                .foregroundStyle(recording.status.tint)
                .frame(width: Metrics.symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.displayTitle)
                    .font(AppFont.headline)
                    .lineLimit(1)
                Text(recording.listDetail)
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if showsStatusWords {
                Text(recording.status.title)
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Metrics.rowSpacing)
        .accessibilityElement(children: .combine)
    }
}

/// The one-sentence description at the top of a screen.
struct PageIntro: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.body)
            .foregroundStyle(.appSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A section header in a grouped form, at a size that reads.
struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(AppFont.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}

/// A line of secondary text inside a form row.
struct RowNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(AppFont.secondary)
            .foregroundStyle(.appSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The empty state: what will appear here, in plain words.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(AppFont.pageTitle)
                .foregroundStyle(.appSecondary)
            Text(title)
                .font(AppFont.sectionTitle)
            // At least 240 pt wide: asked for its smallest size, a wrapped message otherwise reflows to a
            // word a line and asks for its full height (measured: a 1,835 pt window, v2 part M3a).
            Text(message)
                .font(AppFont.body)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .frame(minWidth: 240, maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// A file or folder: its label, then its path under it (home shown as ~), with an optional
/// Show in Finder button. A long path takes a second line, left-aligned under the label, so it can
/// be read in full without a tooltip (tooltips draw at 11 pt, under the 12 pt floor).
struct PathRow: View {
    let label: String
    let path: String
    var showInFinder = true
    @Environment(AppModel.self) private var model

    var body: some View {
        LabeledContent {
            if showInFinder {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AppFont.body)
                Text(model.paths.display(path))
                    .font(AppFont.path)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

/// A labeled value in a form, with the value in secondary text.
struct ValueRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        LabeledContent {
            Text(value)
                .font(monospaced ? AppFont.path : AppFont.secondary)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        } label: {
            Text(label)
                .font(AppFont.body)
        }
    }
}

/// An output's on and off switch, with its one-line description.
struct OutputSwitch: View {
    @Bindable var setting: OutputSetting
    /// A longer line in place of the output's one-line summary.
    var detail: String?

    var body: some View {
        OutputToggle(kind: setting.kind, isOn: $setting.isOn, detail: detail)
    }
}

/// The switch itself. An output that cannot be made (one not built yet) shows off and greyed,
/// whatever is stored, so the screen never claims it is made.
struct OutputToggle: View {
    let kind: OutputKind
    @Binding var isOn: Bool
    var detail: String?

    var body: some View {
        Toggle(isOn: Binding(get: { isOn && kind.isAvailable }, set: { isOn = $0 })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(AppFont.body)
                Text(detail ?? line).font(AppFont.secondary).foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!kind.isAvailable)
    }

    private var line: String { kind.summary }
}
