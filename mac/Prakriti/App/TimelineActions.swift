import AppKit
import Foundation

// The timelines in the app (v2 part M10a, docs/v2/PLAN.md M10; design spec 3.5.1 and 3.12): Make Timelines from the video already
// made (seconds, not a make: the plan and the video are there, so only the timelines are written), Open in Final Cut Pro and
// Open in DaVinci Resolve (shown only when each app is on this Mac), Show in Finder, and the File menu's Export Final Cut Pro
// Timeline and Export DaVinci Resolve Timeline. Make Timelines also turns the Timelines output on for the recording, so every
// Make Again writes them with the video. Nothing starts by itself (PLAN rule 2.1.7).
//
// Refused in words, and nothing written, unless everyone in the video is included and no name is muted, both in the video as it
// was made and in Ivan's choices now (fail closed): "A timeline for a recording with hidden people arrives in the next update."
extension AppModel {
    /// The bundle identifiers Prakriti looks for (design spec 3.5.1, measured on this Mac).
    static func timelineAppID(_ version: FCPXMLVersion) -> String {
        version == .finalCut ? "com.apple.FinalCutApp" : "com.blackmagic-design.DaVinciResolve"
    }

    /// The app that opens a version, when it is on this Mac.
    static func timelineApp(_ version: FCPXMLVersion) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: timelineAppID(version))
    }

    /// The recording's Timeline folder, when it is there.
    func timelineFolder(_ recording: Recording) -> URL? {
        guard let folder = recording.outputFolder else { return nil }
        let url = URL(fileURLWithPath: folder, isDirectory: true).appending(path: TimelineExport.folderName, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// What the last Make Timelines or make wrote, read from the folder.
    func timelineRecord(_ recording: Recording) -> TimelineExport.Record? {
        _ = timelineRevision
        return timelineFolder(recording).flatMap(TimelineExport.Record.read)
    }

    /// One version's file, when it is there.
    func timelineFile(_ recording: Recording, _ version: FCPXMLVersion) -> URL? {
        guard let folder = timelineFolder(recording) else { return nil }
        let url = folder.appending(path: version.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The timelines were made from the plan the video in use was made from.
    func timelineIsCurrent(_ recording: Recording) -> Bool {
        guard let record = timelineRecord(recording), let made = recording.video?.planMadeAt else { return false }
        return abs(record.planMadeAt.timeIntervalSince(made)) < 0.001
    }

    /// Why Make Timelines would write nothing for this recording now, or nil.
    func timelineRefusal(_ recording: Recording) -> String? {
        guard let video = recording.video, videoFile(recording) != nil else {
            return "Make the video first: the timelines are the same edit as the video."
        }
        guard let plan = EditPlan.read(folder: recording.outputFolder), let made = video.planMadeAt,
              abs(plan.madeAt.timeIntervalSince(made)) < 0.001 else {
            return "The edit plan changed after the video was made. Make the video again, then make the timelines."
        }
        if let refusal = TimelineExport.refusal(plan: plan, hiddenFaces: video.hiddenFaces, leftOutVoices: video.leftOutVoices) { return refusal }
        // Ivan's choices now, too: someone he has just chosen to hide is never put in a timeline.
        let now = OutputGate.hidden(videoPeople(recording))
        if now.faces > 0 || now.voices > 0 { return TimelineExport.hiddenRefusal }
        return nil
    }

    /// Make Timelines can be asked for: a video is there and nothing is being made for the recording.
    func canMakeTimelines(_ recording: Recording) -> Bool {
        videoFile(recording) != nil && !writingTimelines.contains(recording.id) && !runner.isCurrent(recording) && !runner.isWaiting(recording)
            && recording.status != .working
    }

    /// Make Timelines, in the background.
    func makeTimelines(_ recording: Recording, then: (@MainActor (Bool) -> Void)? = nil) {
        Task { @MainActor in
            let made = await writeTimelines(recording)
            then?(made)
        }
    }

    /// Writes the timelines from the video already made: refused in words, or written, checked and kept through `OutputGate`.
    /// Returns whether they were kept.
    @discardableResult
    func writeTimelines(_ recording: Recording) async -> Bool {
        guard canMakeTimelines(recording) else { return false }
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        if let refusal = timelineRefusal(recording) {
            timelineProblems[recording.id] = refusal
            record("\(label): no timeline was written. \(refusal)", level: .attention)
            return false
        }
        guard let folder = recording.outputFolder, let video = recording.video, let plan = EditPlan.read(folder: folder) else { return false }
        let output = URL(fileURLWithPath: folder, isDirectory: true)
        let style = StyleName(rawValue: plan.style)?.title ?? plan.style
        let setup = TimelineExport.Setup(original: URL(fileURLWithPath: recording.filePath), plan: plan,
                                         videoFolder: output.appending(path: VideoStep.folderName, directoryHint: .isDirectory), captionsName: video.captionsName,
                                         project: "\(Format.dayLabel(recording.sessionDate)), \(style)",
                                         build: output.deletingLastPathComponent().appending(path: ".timeline " + output.lastPathComponent, directoryHint: .isDirectory),
                                         final: output.appending(path: TimelineExport.folderName, directoryHint: .isDirectory),
                                         admitTo: output.appending(path: TimelineExport.folderName, directoryHint: .isDirectory),
                                         hiddenFaces: video.hiddenFaces, leftOutVoices: video.leftOutVoices)
        writingTimelines.insert(recording.id)
        timelineProblems[recording.id] = nil
        defer { writingTimelines.remove(recording.id) }
        if !OutputResolver.isOn(.timelines, recording: recording, source: nil, defaults: defaultSettings()) {
            setOutput(.timelines, on: true, for: recording)
        }
        do {
            let made = try await TimelineExport.make(setup, now: now())
            if !recording.madeFiles.contains(TimelineExport.folderName) { recording.madeFiles = (recording.madeFiles + [TimelineExport.folderName]).sorted() }
            timelineRevision += 1
            record("\(label): the timelines for Final Cut Pro and DaVinci Resolve, \(made.summary.lowercasedFirst)")
            try? context.save()
            return true
        } catch {
            let reason = (error as? TimelineExport.Failure)?.reason ?? error.localizedDescription
            timelineProblems[recording.id] = reason
            record("\(label): no timeline was written. \(reason)", level: .attention)
            return false
        }
    }

    /// Open in Final Cut Pro hands the file to Final Cut Pro, which imports it. DaVinci Resolve does not open FCPXML from the
    /// Finder (its Info.plist claims only its own files), so Open in DaVinci Resolve opens Resolve and shows the file in the Finder,
    /// and the row says to choose File > Import > Timeline.
    func openTimeline(_ recording: Recording, in version: FCPXMLVersion) {
        guard let file = timelineFile(recording, version), let app = Self.timelineApp(version) else { return }
        switch version {
        case .finalCut:
            NSWorkspace.shared.open([file], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        case .resolve:
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
    }

    /// File > Export Final Cut Pro Timeline and Export DaVinci Resolve Timeline: the file in the Finder, written first when it is
    /// not there or is behind the video (design spec 3.12: beside the outputs, never into a watched folder).
    func exportTimeline(_ version: FCPXMLVersion) {
        guard let recording = focusedRecording else { return }
        if timelineIsCurrent(recording), let file = timelineFile(recording, version) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
            return
        }
        makeTimelines(recording) { [weak self] made in
            guard made, let self, let file = self.timelineFile(recording, version) else { return }
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
    }

    /// The File menu's export items can run for the focused recording.
    var canExportTimeline: Bool {
        guard let recording = focusedRecording else { return false }
        return (timelineIsCurrent(recording) && timelineFolder(recording) != nil) || canMakeTimelines(recording)
    }
}
