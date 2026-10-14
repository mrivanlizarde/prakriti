import AppKit
import SwiftData
import SwiftUI

/// The inspector's Outputs tab (design spec 3.5.1, as built in part M3a): the status in symbol and
/// words with one sentence of what it means and the one thing to do next (Make Outputs, Try Again,
/// Approve, Make Again); the files made, each with Show in Finder and the episode with Play; the titles,
/// show notes and chapters and the podcast-ready files, as on v1's recording page; and Show All Outputs in
/// Finder. Approve keeps every refusal of v1 (`ApprovalCheck`, START_HERE Mac warnings 35 to 38) and asks
/// first; it copies to the Approved folder and uploads nothing.
struct OutputsTab: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                StatusBlock(recording: recording)
            }
            if !deliverables.isEmpty {
                Section {
                    ForEach(deliverables) { deliverable in
                        DeliverableRow(deliverable: deliverable, recording: recording)
                    }
                } header: {
                    SectionHeader("Files")
                }
            }
            if recording.status != .needsADecision && recording.status != .skipped {
                // The edit plan (v2 part M8a), once a transcript is made: it is made from transcript.json. Short, so it
                // comes before the long writing and podcast-ready sections.
                if recording.madeFiles.contains(TranscriptFiles.asHeard) {
                    EditPlanSection(recording: recording)
                    // The edited video (v2 part M8b), made from the plan.
                    VideoSection(recording: recording)
                }
                if recording.outputFolder != nil || recording.written != nil {
                    WritingSection(recording: recording, showsChecklist: false)
                }
                if recording.podcastReady != nil || recording.podcastReadyProblem != nil || recording.kind == .lesson
                    || OutputResolver.isOn(.podcastReady, recording: recording, source: nil, defaults: model.defaultSettings()) {
                    PodcastReadySection(recording: recording)
                }
            }
            // What this recording makes, moved from v1's page (v2 part M3b).
            if recording.status != .needsADecision && recording.status != .skipped {
                RecordingOutputsSection(recording: recording)
                if recording.hasOwnOutputs {
                    RecordingOwnSettingsSections(recording: recording)
                }
            }
            if recording.outputFolder != nil {
                Section {
                    Button("Show All Outputs in Finder") { model.showOutputsInFinder(recording) }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// What this recording's last make left, and the outputs it does not make (dimmed).
    private var deliverables: [Deliverable] {
        Deliverable.list(for: recording, isOn: { OutputResolver.isOn($0, recording: recording, source: nil, defaults: model.defaultSettings()) })
    }
}

/// The status block: symbol and words at 17 pt semibold, what it means, and what to do.
struct StatusBlock: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let check = model.approvalCheck(recording)
        let progress = model.runner.progress(for: recording)
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(progress?.isPaused == true ? "Paused" : recording.status.title)
                    .font(AppFont.headline)
            } icon: {
                Image(systemName: progress?.isPaused == true ? "pause.circle" : recording.status.symbol)
                    .font(AppFont.headline)
                    .foregroundStyle(recording.status.tint)
            }
            if let progress {
                // While it is made (v2 part M4a, design spec 3.6.1).
                ProgressBlock(recording: recording, snapshot: progress)
            } else if model.runner.isWaiting(recording) {
                ForEach(lines, id: \.self) { line in
                    Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                }
                ProgressButtons(recording: recording)
            }
            ForEach(progress != nil || model.runner.isWaiting(recording) ? [] : lines, id: \.self) { line in
                Text(line)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if recording.status == .readyForYourYes {
                if check.speakersNotChecked {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ApprovalCheck.speakersTitle).font(AppFont.headline)
                            Text(check.line ?? "").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: "person.2.slash").font(AppFont.body).foregroundStyle(.orange)
                    }
                    .accessibilityElement(children: .combine)
                } else if let line = check.line {
                    Text(line)
                        .font(AppFont.body)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                if let start = model.startTitle(recording) {
                    Button(start) { model.makeOutputs(recording) }
                        .buttonStyle(.borderedProminent)
                }
                if recording.status == .readyForYourYes {
                    Button("Approve…") { model.ask(.approve, for: recording) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!check.canApprove)
                }
                if model.canMakeAgain(recording) {
                    Button("Make Again…") { model.ask(.makeAgain, for: recording) }
                }
            }
            if recording.status == .readyForYourYes {
                Text("Approve copies the finished files to \(model.paths.display(model.paths.approved.path)). Nothing is uploaded.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let folder = recording.approvedFolder, FileManager.default.fileExists(atPath: folder) {
                PathRow(label: recording.status == .approved ? "Approved files" : "Approved before this change", path: folder)
            }
        }
        .padding(.vertical, 4)
    }

    /// One sentence of what the status means, then the recording's own reason when it adds something.
    private var lines: [String] {
        var lines: [String] = []
        if model.runner.isWaiting(recording) {
            lines.append(model.runner.isHeld(recording) ? "Paused in line. It keeps its place and starts once you resume it."
                         : model.settings.isPaused ? "Waiting to start. Pause All is on; it starts when you resume."
                                                 : "Waiting to start. Another recording is being made first.")
        } else {
            switch recording.status {
            case .found:
                lines.append(recording.statusReason ?? "Found and not made yet. Choose Make Outputs to make it now.")
            case .working:
                lines.append((recording.currentStep ?? "Working") + ".")
            case .readyForYourYes:
                lines.append("Everything chosen for it is made and checked. Listen, then approve.")
                if let reason = recording.statusReason { lines.append(reason) }
            case .needsADecision, .couldntFinish, .skipped:
                if let reason = recording.statusReason { lines.append(reason) }
            case .approved:
                lines.append(recording.statusReason ?? "Approved. Nothing has been uploaded.")
            }
        }
        if recording.editsPending && (recording.status == .readyForYourYes || recording.status == .approved) {
            lines.append("The trim or cuts in the Viewer are not in the episode yet. Make it again before approving.")
        }
        if recording.choicesPending && (recording.status == .readyForYourYes || recording.status == .approved) {
            lines.append("Your choices in People are not in the episode yet. Make it again before approving.")
        }
        return lines
    }
}

/// One file or group of files a make leaves, for the Files list.
struct Deliverable: Identifiable, Equatable {
    let kind: OutputKind
    let detail: String
    /// What Show in Finder selects; nil for an output this recording does not make.
    let url: URL?
    /// The podcast episode plays in the Viewer.
    var playsOnPage = false
    var made: Bool { url != nil }
    var id: String { kind.rawValue }

    /// The outputs, in the design spec's order, as this recording's last make left them. An output it
    /// does not make shows dimmed with "Not made for this recording."; one switched on but not made yet
    /// says so.
    @MainActor
    static func list(for recording: Recording, isOn: (OutputKind) -> Bool) -> [Deliverable] {
        guard recording.status != .needsADecision, recording.status != .skipped else { return [] }
        let folder = recording.outputFolder.map { URL(fileURLWithPath: $0, isDirectory: true) }
        var names = Set(recording.madeFiles)
        if names.isEmpty, let folder {
            names = Set(Pipeline.madeFiles(in: folder))
        }
        func file(_ name: String) -> URL? {
            guard let folder, names.contains(name) else { return nil }
            return folder.appending(path: name)
        }
        var list: [Deliverable] = []
        for kind in [OutputKind.podcastEpisode, .podcastReady, .editedVideo, .transcript, .checksAndReport, .titlesNotesChapters] {
            switch kind {
            case .podcastEpisode:
                if let url = file("episode.mp3") {
                    var parts = ["MP3"]
                    if let lufs = recording.loudnessLUFS { parts.append(Format.lufs(lufs)) }
                    if let length = recording.episodeDuration ?? recording.duration { parts.append(Format.timecode(length)) }
                    list.append(Deliverable(kind: kind, detail: parts.joined(separator: ", ") + ".", url: url, playsOnPage: true))
                    continue
                }
            case .podcastReady:
                if let ready = recording.podcastReady, let folder {
                    let fails = ready.checklist.filter { $0.status == .fail }.count
                    let missing = ready.checklist.filter { $0.status == .missing }.count
                    list.append(Deliverable(kind: kind,
                                            detail: "MP3, \(String(format: "%.1f LUFS", ready.integratedLUFS)), \(Format.timecode(ready.duration)). Upload checklist: \(fails) FAIL, \(missing) MISSING.",
                                            url: folder.appending(path: PodcastPackage.folderName, directoryHint: .isDirectory)))
                    continue
                }
            case .editedVideo:
                if let video = recording.video, let folder, names.contains(VideoStep.folderName) {
                    list.append(Deliverable(kind: kind,
                                            detail: "MP4, \(Format.timecode(video.duration)), with captions and Description.txt. Ready checklist: \(video.failed) FAIL, \(video.missing) MISSING.",
                                            url: folder.appending(path: VideoStep.folderName, directoryHint: .isDirectory).appending(path: video.fileName)))
                    continue
                }
            case .transcript:
                let formats = ["txt", "srt", "vtt", "md"].filter { names.contains("transcript.\($0)") }
                if let first = formats.first, let url = file("transcript.\(first)") {
                    list.append(Deliverable(kind: kind, detail: "." + formats.joined(separator: ", .") + ", with times.", url: url))
                    continue
                }
            case .checksAndReport:
                if let url = file("REPORT.md") {
                    list.append(Deliverable(kind: kind, detail: "REPORT.md: length, sound, loudness and how far the transcript reaches.", url: url))
                    continue
                }
            case .titlesNotesChapters:
                if let url = file(WrittenPackage.notesFileName) {
                    list.append(Deliverable(kind: kind, detail: "\(WrittenPackage.notesFileName): drafts to read before anything goes out.", url: url))
                    continue
                }
            default:
                break
            }
            if isOn(kind) {
                list.append(Deliverable(kind: kind, detail: recording.status == .working || recording.status == .found
                                        ? "Not made yet." : "Chosen, and made at the next Make Again.", url: nil))
            } else {
                list.append(Deliverable(kind: kind, detail: "Not made for this recording.", url: nil))
            }
        }
        return list
    }
}

/// A file row: its symbol, its name at 17 pt, one detail line at 15 pt, and Play or Show in Finder.
struct DeliverableRow: View {
    let deliverable: Deliverable
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deliverable.kind.title)
                        .font(AppFont.body)
                    Text(deliverable.detail)
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: deliverable.kind.symbol)
                    .font(AppFont.body)
                    .foregroundStyle(deliverable.made ? AppColor.accentText : .secondary)
            }
            if let url = deliverable.url {
                HStack(spacing: 10) {
                    if deliverable.playsOnPage {
                        Button("Play") {
                            model.pendingSeek = PendingSeek(recordingID: recording.id, time: 0, play: true, rendition: .podcast)
                            model.open(recording)
                        }
                    }
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                .padding(.leading, 34)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }
}
