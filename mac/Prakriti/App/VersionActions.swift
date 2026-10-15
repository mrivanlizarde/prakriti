import Foundation

// Versions (v2 part M9d, docs/v2/PLAN.md M9; design spec 3.5.3 item 7 and 3.7): each time a video is made it is kept as a version,
// with the direction that made it, its plan's lines, when it was made and how long it is. Ivan can **Play** any kept version in the
// Viewer and **Use This Version** to put it back in the recording's folder, where Approve finds it: approval covers exactly the
// version in use, and the Approve question and the receipt name it.
//
// Where the files are: `<outputs>/<recording>/Versions/Version N/` holds that version's Video folder, `edit-plan.json` and
// `video-hiding.json`, copied with `FileManager.copyItem`, which clones on APFS (no extra space until a file changes). The folder
// is not one a make writes or Approve copies (`Pipeline.madeNames`), so a make never removes it and Approve never copies it. The
// five newest versions are kept; an older one's folder goes when a sixth is made, never the one in use.
//
// Load-bearing: Use This Version puts the version's own plan back beside its video, so the Viewer, which plays only the plan the
// video was made from (Mac warning 153), plays it, and nothing is made again.
extension AppModel {
    private func versionLabel(_ recording: Recording) -> String {
        "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
    }

    /// Keeps the video a make just placed in the recording's folder as a new version, the one in use.
    func recordVersion(_ recording: Recording, video: VideoRecord, plan: EditPlan?) {
        guard let path = recording.outputFolder else { return }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        var versions = recording.versions
        let number = versions.next
        let folder = EditVersion.folder(number, in: output)
        let fm = FileManager.default
        do {
            try? fm.removeItem(at: folder)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            var copied: [String] = []
            for name in EditVersions.names.sorted() where fm.fileExists(atPath: output.appending(path: name).path) {
                try fm.copyItem(at: output.appending(path: name), to: folder.appending(path: name))
                copied.append(name)
            }
            let version = EditVersion(number: number, madeAt: video.madeAt, made: EditVersions.made(by: plan), chips: plan?.direction?.chips ?? [],
                                      planLines: plan?.planLines ?? [], duration: video.duration, files: copied, video: video)
            versions.versions.append(version)
            versions.current = number
            // The oldest beyond the five newest go, never the one in use.
            while versions.versions.count > EditVersions.kept, let oldest = versions.versions.first(where: { $0.number != versions.current }) {
                try? fm.removeItem(at: EditVersion.folder(oldest.number, in: output))
                versions.versions.removeAll { $0.number == oldest.number }
            }
            recording.versions = versions
            record("\(versionLabel(recording)): kept as version \(number). \(version.made).")
        } catch {
            try? fm.removeItem(at: folder)
            record("\(versionLabel(recording)): the video could not be kept as a version (\(error.localizedDescription)). The video itself is in its folder.", level: .attention)
        }
        try? context.save()
    }

    /// Whether a version's files are all still in its folder.
    func versionIsThere(_ version: EditVersion, of recording: Recording) -> Bool {
        guard let path = recording.outputFolder else { return false }
        let folder = EditVersion.folder(version.number, in: URL(fileURLWithPath: path, isDirectory: true))
        return FileManager.default.fileExists(atPath: folder.appending(path: VideoStep.folderName).appending(path: version.video.fileName).path)
            && FileManager.default.fileExists(atPath: folder.appending(path: EditPlan.fileName).path)
    }

    /// Use This Version can run: not the one in use, its files there, nothing being made or planned.
    func canUseVersion(_ number: Int, of recording: Recording) -> Bool {
        guard let version = recording.versions.version(number), recording.versions.current != number else { return false }
        return versionIsThere(version, of: recording) && !runner.isCurrent(recording) && !runner.isWaiting(recording) && !planning.contains(recording.id)
    }

    /// Use This Version: its Video folder, plan and hidden faces back in the recording's folder (copies, so the version stays), its
    /// record as the recording's video. An approval is taken back, since what would be approved changed.
    @discardableResult
    func useVersion(_ number: Int, of recording: Recording) -> Bool {
        guard canUseVersion(number, of: recording), let version = recording.versions.version(number), let path = recording.outputFolder else { return false }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        let from = EditVersion.folder(number, in: output)
        let staging = output.deletingLastPathComponent().appending(path: ".using " + output.lastPathComponent, directoryHint: .isDirectory)
        let fm = FileManager.default
        do {
            try? fm.removeItem(at: staging)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: staging) }
            for name in version.files where fm.fileExists(atPath: from.appending(path: name).path) {
                try fm.copyItem(at: from.appending(path: name), to: staging.appending(path: name))
            }
            _ = try Pipeline.place(staging, into: output, known: EditVersions.names)
        } catch {
            record("\(versionLabel(recording)): version \(number) could not be put back (\(error.localizedDescription)). The files in its folder are as they were.", level: .problem)
            return false
        }
        recording.videoJSON = version.video.json()
        recording.videoProblem = nil
        var versions = recording.versions
        versions.current = number
        recording.versions = versions
        record("\(versionLabel(recording)): using version \(number) (\(version.made)). Its video and plan are back in the recording's folder.")
        changedAfterApproval(recording, what: "the version in use")
        forgetEditPlan(recording)
        viewer.versionPlaying = nil
        try? context.save()
        if viewer.recordingID == recording.id { openViewer(recording) }
        return true
    }

    /// Play: the Viewer plays this version (from its own folder) on Video; the version in use plays as Video always does.
    func playVersion(_ number: Int, of recording: Recording) {
        guard let version = recording.versions.version(number), let path = recording.outputFolder, versionIsThere(version, of: recording) else {
            notice = Notice(title: "Version \(number) cannot play", message: "Its files are not in the Versions folder any more.")
            return
        }
        if recording.versions.current == number {
            viewer.versionPlaying = nil
        } else {
            viewer.versionPlaying = ViewerModel.VersionPlaying(recordingID: recording.id, number: number,
                                                              folder: EditVersion.folder(number, in: URL(fileURLWithPath: path, isDirectory: true)).path,
                                                              video: version.video)
        }
        if self.path.last?.id == recording.persistentModelID, viewer.recordingID == recording.id {
            openViewer(recording)
            viewer.choose(.video, recording: recording)
            return
        }
        pendingSeek = PendingSeek(recordingID: recording.id, time: 0, play: false, rendition: .video)
        open(recording)
    }

    /// The version Approve covers, in one sentence for the question and the receipt, or nil when no video is kept as a version.
    func approvalVersionLine(_ recording: Recording) -> String? {
        guard recording.video != nil, let version = recording.versions.inUse else { return nil }
        return "Version \(version.number), made \(Format.dayAndTime(version.madeAt)). \(EditVersion.sentence(version.made))"
    }
}
