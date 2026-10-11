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

/// One recording's page: its status and Approve at the top; the system player; the transcript as
/// lines that play from their moment and can be cut; the trim and cuts; its title, notes and what it
/// is; the steps with their timings; what was measured and made; and which outputs it makes, with
/// Make Again.
struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model
    @State private var confirmMakeAgain = false
    @State private var confirmApprove = false
    @State private var page = RecordingPage()

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
                if recording.status == .readyForYourYes || recording.status == .approved {
                    ApproveRows(recording: recording, confirmApprove: $confirmApprove, confirmMakeAgain: $confirmMakeAgain, canMakeAgain: canMakeAgain)
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

            if showsEditing {
                ListenSection(recording: recording, page: page)
                TranscriptSection(recording: recording, page: page)
                EditsSection(recording: recording, page: page, confirmMakeAgain: $confirmMakeAgain, canMakeAgain: canMakeAgain)
            }
            if recording.status != .needsADecision && recording.status != .skipped {
                AboutSection(recording: recording)
                if recording.outputFolder != nil || recording.written != nil {
                    WritingSection(recording: recording)
                }
                // Ready to upload: whenever the podcast-ready episode is made, asked for or refused, and
                // always for a class, which says why it is never made ready.
                if recording.podcastReady != nil || recording.podcastReadyProblem != nil || recording.kind == .lesson
                    || OutputResolver.isOn(.podcastReady, recording: recording, source: nil, defaults: model.defaultSettings()) {
                    PodcastReadySection(recording: recording)
                }
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
                        if let length = recording.episodeDuration {
                            ValueRow(label: "Episode length", value: Format.timecode(length)
                                     + (recording.madeEdits.isEmpty ? Format.trimmed(start: recording.silenceTrimmedStart, end: recording.silenceTrimmedEnd)
                                                                    : ", with your trim and cuts"))
                        }
                    }
                    if let words = recording.wordCount {
                        let verb = recording.coverageOK == false ? ", stops at " : ", reaches "
                        let reach = recording.transcriptReaches.map { reaches in
                            verb + Format.timecode(reaches) + (recording.duration.map { " of " + Format.timecode($0) } ?? "")
                        } ?? ""
                        ValueRow(label: "Transcript", value: Format.number(words) + " words" + reach)
                        if let fixes = recording.wordListFixes {
                            ValueRow(label: "Word list", value: fixes == 0 ? "No known mis-hearings found" : Format.count(fixes, "fix", "fixes") + ", listed in the report")
                        }
                    }
                    if let made = madeLine {
                        ValueRow(label: "Made", value: made)
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

            // A silent recording or a test clip is never made, so it has no outputs to choose.
            if recording.status != .needsADecision && recording.status != .skipped {
                RecordingOutputsSection(recording: recording, confirmMakeAgain: $confirmMakeAgain)
            }
            if recording.hasOwnOutputs && recording.status != .needsADecision && recording.status != .skipped {
                // Only the settings of what this recording makes are shown.
                if let podcast = recording.outputSettings.first(where: { $0.kind == .podcastEpisode && $0.isOn }) {
                    Section {
                        PodcastSettingsRows(setting: podcast)
                    } header: {
                        SectionHeader("Episode settings for this recording")
                    }
                }
                if let transcript = recording.outputSettings.first(where: { $0.kind == .transcript && $0.isOn }) {
                    Section {
                        TranscriptSettingsRows(setting: transcript, wordListIsBelow: false)
                    } header: {
                        SectionHeader("Transcript settings for this recording")
                    }
                }
                if let ready = recording.outputSettings.first(where: { $0.kind == .podcastReady && $0.isOn }) {
                    Section {
                        PodcastReadySettingsRows(setting: ready, showsShow: false)
                    } header: {
                        SectionHeader("Podcast-ready settings for this recording")
                    }
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
        .onAppear { page.load(recording, applyLexicon: wordListOn) }
        .onChange(of: recording.madeAt) { page.load(recording, applyLexicon: wordListOn) }
        .onDisappear { page.player.pause() }
        .confirmationDialog("Make this recording again?", isPresented: $confirmMakeAgain) {
            Button("Make Again") { model.makeOutputs(recording) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is made again with the trim, the cuts and the choices on this page. The files made before are replaced once the new ones are ready, and the original recording is not changed.")
        }
        .confirmationDialog("Approve \(Format.dayLabel(recording.sessionDate))?", isPresented: $confirmApprove) {
            Button("Approve") { model.approve(recording) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Copies \(Format.madeFiles(ApprovalCheck.filesToApprove(recording))) to \(model.paths.display(model.approvedFolder(for: recording).path)), with a receipt. Nothing is uploaded or published.")
        }
    }

    /// The player, transcript and edits, once something has been checked or made.
    private var showsEditing: Bool {
        switch recording.status {
        case .readyForYourYes, .approved: true
        case .working, .found, .couldntFinish: recording.outputFolder != nil
        case .needsADecision, .skipped: false
        }
    }

    /// The word list as this recording's transcript was made, for reading the lines.
    private var wordListOn: Bool {
        OutputResolver.details(for: .transcript, recording: recording, defaults: model.defaultSettings())?.applyLexicon ?? true
    }

    /// Make Again: a finished recording, not waiting or working.
    private var canMakeAgain: Bool {
        (recording.status == .readyForYourYes || recording.status == .approved) && !model.runner.isWaiting(recording) && !model.runner.isCurrent(recording)
    }

    /// "episode.mp3, REPORT.md, transcript (.txt, .srt, .vtt, .md, .json)": what the last finished
    /// make left. A recording made by engine v0 has no list, so its folder is read.
    private var madeLine: String? {
        var names = recording.madeFiles
        if names.isEmpty, let folder = recording.outputFolder {
            names = Pipeline.madeFiles(in: URL(fileURLWithPath: folder)).filter(Pipeline.madeNames.contains)
        }
        return names.isEmpty ? nil : Format.madeFiles(names)
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
            : "This recording mentions Serenity, so only models on this Mac may read it."
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

/// Which outputs this recording makes: its folder's choices, or its own once one is changed here.
/// Make Again sits here, below the choices it uses.
struct RecordingOutputsSection: View {
    @Bindable var recording: Recording
    @Binding var confirmMakeAgain: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let defaults = model.defaultSettings()
        Section {
            RowNote(followLine)
            ForEach(OutputKind.built, id: \.self) { kind in
                OutputToggle(kind: kind, isOn: Binding(
                    get: { OutputResolver.isOn(kind, recording: recording, source: nil, defaults: defaults) },
                    set: { model.setOutput(kind, on: $0, for: recording) }))
            }
            if !recording.hasOwnOutputs {
                if OutputResolver.isOn(.podcastEpisode, recording: recording, source: nil, defaults: defaults),
                   let podcast = OutputResolver.details(for: .podcastEpisode, recording: recording, defaults: defaults) {
                    ValueRow(label: "Episode settings", value: Format.episodeSettings(podcast))
                }
                if OutputResolver.isOn(.transcript, recording: recording, source: nil, defaults: defaults),
                   let transcript = OutputResolver.details(for: .transcript, recording: recording, defaults: defaults) {
                    ValueRow(label: "Transcript settings", value: Format.transcriptSettings(transcript))
                }
            }
            HStack(spacing: 12) {
                if recording.hasOwnOutputs {
                    Button(recording.source == nil ? "Use the Standard Choices" : "Use the Folder's Choices") { model.useStandardOutputs(recording) }
                } else {
                    Button("Change Settings for This Recording") { model.giveOwnOutputs(recording) }
                }
                Spacer()
                if canMakeAgain {
                    Button("Make Again…") { confirmMakeAgain = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        } header: {
            SectionHeader("Outputs for this recording")
        }
    }

    private var followLine: String {
        if recording.hasOwnOutputs {
            return "This recording has its own choices. Changes on Sources and Outputs do not reach it."
        }
        if let source = recording.source {
            return "Made as the \(source.name) folder is set, with the settings on the Outputs screen. Change a switch to give this recording its own choices."
        }
        return "Made with the standard choices on the Outputs screen. Change a switch to give this recording its own choices."
    }

    /// A finished (or approved) recording can be made again with changed choices. One waiting or
    /// working cannot.
    private var canMakeAgain: Bool {
        (recording.status == .readyForYourYes || recording.status == .approved) && !model.runner.isWaiting(recording) && !model.runner.isCurrent(recording)
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
