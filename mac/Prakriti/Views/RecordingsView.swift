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
                Button { model.chooseFilesToProcess() } label: {
                    Label("Process File…", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}

/// One recording's page: its status, what to do next, the steps with their timings, and what was
/// measured and made. The player, transcript, trim, cuts, Make Again and Approve arrive in milestone 5.
struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

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
                if let waiting = waitingLine {
                    Text(waiting)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let action = actionTitle {
                    Button(action) { model.makeOutputs(recording) }
                        .buttonStyle(.borderedProminent)
                }
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
                    ForEach(run.steps.filter { $0.state != .skipped }) { step in
                        StepRow(step: step)
                    }
                    // Steps that never ran (a test, a silent recording) are named once, in one row,
                    // rather than six rows that all say Skipped.
                    let skipped = run.steps.filter { $0.state == .skipped }
                    if !skipped.isEmpty {
                        StepRow(step: RunStep(name: "Not run", state: .skipped, seconds: nil,
                                              detail: Self.sentence(skipped.map(\.name)) + "."), showsState: false)
                    }
                } header: {
                    SectionHeader("Steps")
                }
            }

            if hasResults {
                Section {
                    if let loudest = recording.loudestDB {
                        let average = recording.averageDB.map { ", average " + Pipeline.db($0) } ?? ""
                        ValueRow(label: "Sound in the original", value: "Loudest point " + Pipeline.db(loudest) + average)
                    }
                    if let lufs = recording.loudnessLUFS {
                        let peak = recording.truePeakDBFS.map { ", peak " + Format.dbfs($0) } ?? ""
                        ValueRow(label: "Episode audio", value: Format.lufs(lufs) + peak)
                    }
                    if let words = recording.wordCount {
                        let verb = recording.coverageOK == false ? ", stops at " : ", reaches "
                        let reach = recording.transcriptReaches.map { reaches in
                            verb + Format.timecode(reaches) + (recording.duration.map { " of " + Format.timecode($0) } ?? "")
                        } ?? ""
                        ValueRow(label: "Transcript", value: Format.number(words) + " words" + reach)
                    }
                    if let folder = recording.outputFolder {
                        PathRow(label: "Files", path: folder)
                        let report = URL(fileURLWithPath: folder).appending(path: "REPORT.md")
                        if FileManager.default.fileExists(atPath: report.path) {
                            LabeledContent {
                                Button("Open Report") { NSWorkspace.shared.open(report) }
                            } label: {
                                Text("Report").font(AppFont.body)
                            }
                        }
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

    /// "Transcript, coverage check and report": the first name as written, the rest lowercased.
    static func sentence(_ names: [String]) -> String {
        let words = names.enumerated().map { $0.offset == 0 ? $0.element : $0.element.lowercasedFirst }
        guard words.count > 1 else { return words.first ?? "" }
        return words.dropLast().joined(separator: ", ") + " and " + (words.last ?? "")
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
        recording.loudestDB != nil || recording.loudnessLUFS != nil || recording.wordCount != nil || recording.outputFolder != nil
    }

    /// What Ivan can do from here in this milestone: start a found recording, or try one again.
    private var actionTitle: String? {
        switch recording.status {
        case .found: "Make Outputs"
        case .couldntFinish: "Try Again"
        default: nil
        }
    }

    private var waitingLine: String? {
        guard model.runner.isWaiting(recording) else { return nil }
        return model.settings.isPaused
            ? "Waiting to start. Pause All is on; it starts when you resume."
            : "Waiting to start. Another recording is being worked on first."
    }
}

/// One step of a run: its state, its name, how long it took, and what it found.
struct StepRow: View {
    let step: RunStep
    var showsState = true

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
            if showsState || step.seconds != nil {
                Text(step.seconds.map { Format.length($0) } ?? step.state.title)
                    .font(AppFont.numbers)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
