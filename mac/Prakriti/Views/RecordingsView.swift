import AppKit
import SwiftData
import SwiftUI

/// Every recording, newest first.
struct RecordingsView: View {
    @Environment(AppModel.self) private var model
    @Query private var recordings: [Recording]

    var body: some View {
        let sorted = recordings.sorted(by: Recording.newestFirst)
        Group {
            if sorted.isEmpty {
                EmptyState(symbol: "rectangle.stack", title: "No recordings yet",
                           message: "Recordings appear here when Prakriti finds them in a watched folder, or when you add one with Add File.")
            } else {
                List {
                    PageIntro(text: "Every recording Prakriti has found or been given, newest first.")
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                    ForEach(sorted) { recording in
                        NavigationLink(value: RecordingRoute(id: recording.persistentModelID)) {
                            RecordingRow(recording: recording)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Recordings")
        .toolbar {
            ToolbarItem {
                Button { model.chooseFiles() } label: {
                    Label("Add File…", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}

/// One recording's page. Milestone 1 shows its status, steps and results; the player, transcript,
/// trim, cuts, Make Again and Approve arrive in milestone 5.
struct RecordingDetailView: View {
    @Bindable var recording: Recording

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.title.isEmpty ? (recording.fileName as NSString).deletingPathExtension : recording.title)
                        .font(AppFont.pageTitle)
                    Text(subtitle)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    StatusLabel(status: recording.status)
                    if let reason = recording.statusReason {
                        Text(reason)
                            .font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                if recording.isPrivacyLocked {
                    Label {
                        Text(lockLine)
                            .font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock.fill")
                            .font(AppFont.body)
                    }
                }
            } header: {
                SectionHeader("Status")
            }

            if let run = recording.latestRun, !run.steps.isEmpty {
                Section {
                    ForEach(run.steps) { step in
                        StepRow(step: step)
                    }
                } header: {
                    SectionHeader("Steps")
                }
            }

            if hasResults {
                Section {
                    if let lufs = recording.loudnessLUFS {
                        let peak = recording.truePeakDBFS.map { ", peak " + Format.dbfs($0) } ?? ""
                        ValueRow(label: "Episode audio", value: Format.lufs(lufs) + peak)
                    }
                    if let words = recording.wordCount {
                        let reach = recording.transcriptReaches.map { reaches in
                            ", reaches " + Format.timecode(reaches) + (recording.duration.map { " of " + Format.timecode($0) } ?? "")
                        } ?? ""
                        ValueRow(label: "Transcript", value: Format.number(words) + " words" + reach)
                    }
                    if let folder = recording.outputFolder {
                        PathRow(label: "Files", path: folder)
                    }
                } header: {
                    SectionHeader("Results")
                }
            }

            Section {
                PathRow(label: "Original file", path: recording.filePath)
                if recording.sizeBytes > 0 {
                    ValueRow(label: "Size", value: Format.size(recording.sizeBytes))
                }
                ValueRow(label: "Found", value: Format.dayAndTime(recording.foundAt))
            } header: {
                SectionHeader("File")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Format.dayLabel(recording.sessionDate))
    }

    private var subtitle: String {
        var parts = [Format.dayAndTime(recording.sessionDate)]
        if let duration = recording.duration { parts.append(Format.length(duration)) }
        if let source = recording.source { parts.append("From " + source.name) } else { parts.append("Added by hand") }
        if recording.kind != .unknown { parts.append(recording.kind.title) }
        return parts.joined(separator: ". ") + "."
    }

    private var lockLine: String {
        recording.kind == .lesson
            ? "This is a class, so only models on this Mac may read it."
            : "Serenity is in this recording, so only models on this Mac may read it."
    }

    private var hasResults: Bool {
        recording.loudnessLUFS != nil || recording.wordCount != nil || recording.outputFolder != nil
    }
}

/// One step of a run: its state, its name, how long it took, and what it found.
struct StepRow: View {
    let step: RunStep

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: step.state.symbol)
                .font(AppFont.body)
                .foregroundStyle(step.state.tint)
                .frame(width: Metrics.symbolWidth)
                .accessibilityLabel(step.state.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name)
                    .font(AppFont.body)
                if let detail = step.detail {
                    Text(detail)
                        .font(AppFont.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Text(step.seconds.map { Format.length($0) } ?? step.state.title)
                .font(AppFont.numbers)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
