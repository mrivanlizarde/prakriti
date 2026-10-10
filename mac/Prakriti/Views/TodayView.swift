import SwiftData
import SwiftUI

extension AppModel {
    func statusSummary(recordings: [Recording], sources: [Source]) -> StatusSummary {
        let working = recordings.first { $0.status == .working }
        let blocked = sources.filter { watcher.states[$0.id]?.isBlocked == true }.map(\.name)
        return StatusSummary.make(
            isWatching: isWatching,
            isPaused: settings.isPaused,
            folderNames: sources.map(\.name),
            blockedFolders: blocked,
            needsYou: recordings.filter(\.status.needsYou).count,
            problems: recordings.filter { $0.status == .couldntFinish }.count,
            working: working.map { (Format.dayLabel($0.sessionDate), $0.currentStep ?? "Working") })
    }
}

/// What needs Ivan now, and what is being worked on.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Recording.foundAt, order: .reverse) private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let needsYou = recordings.filter(\.status.needsYou).sorted(by: Recording.newestFirst)
        let working = recordings.filter { $0.status == .working }.sorted(by: Recording.newestFirst)
        let summary = model.statusSummary(recordings: recordings, sources: sources)

        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Format.longDay(model.now()))
                        .font(AppFont.secondaryEmphasis)
                        .foregroundStyle(.secondary)
                    Text(headline(needsYou: needsYou.count))
                        .font(AppFont.pageTitle)
                    Label {
                        Text(summary.line)
                    } icon: {
                        Image(systemName: summary.icon.rawValue)
                    }
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if needsYou.isEmpty && working.isEmpty {
                Section {
                    EmptyState(symbol: "checkmark.circle", title: "Nothing to review",
                               message: "Recordings appear here when they are ready for your yes, need a decision, or could not finish.")
                }
            }

            if !needsYou.isEmpty {
                Section {
                    ForEach(needsYou) { recording in
                        NavigationLink(value: RecordingRoute(id: recording.persistentModelID)) {
                            RecordingRow(recording: recording)
                        }
                    }
                } header: {
                    SectionHeader("Needs you")
                }
            }

            if !working.isEmpty {
                Section {
                    ForEach(working) { recording in
                        NavigationLink(value: RecordingRoute(id: recording.persistentModelID)) {
                            WorkingRow(recording: recording)
                        }
                    }
                } header: {
                    SectionHeader("Working now")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Today")
    }

    private func headline(needsYou: Int) -> String {
        switch needsYou {
        case 0: "Nothing needs you"
        case 1: "1 recording needs you"
        default: "\(needsYou) recordings need you"
        }
    }
}

/// A recording being worked on: its step, named, and how far along the steps it is.
struct WorkingRow: View {
    let recording: Recording

    var body: some View {
        let steps = recording.latestRun?.steps ?? []
        let done = steps.filter { $0.state == .done }.count
        VStack(alignment: .leading, spacing: 8) {
            RecordingRow(recording: recording, showsStatusWords: false)
            if !steps.isEmpty {
                ProgressView(value: Double(done), total: Double(steps.count)) {
                    Text("Step \(min(done + 1, steps.count)) of \(steps.count)")
                        .font(AppFont.secondary)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, Metrics.symbolWidth + 12)
            }
        }
    }
}
