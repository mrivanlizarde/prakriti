import AppKit
import Foundation

// The shorts in the app (v2 part M11a): Make Shorts on a recording already made, what the inspector and the Viewer read, and the
// Direction tab's count and length. The shorts are made by a make (Make Again with the Shorts output switched on for that
// recording), so they go through the line, the progress, Pause and Stop like any make, and nothing about them is made outside the
// pipeline's staging and `OutputGate`. Nothing starts by itself: Shorts is off for every folder until Ivan turns it on (PLAN rule
// 2.1.7), and a recording made before this part gets a Make Shorts button instead.
extension AppModel {
    /// The shorts folder of a recording's last make, when it is there.
    func shortsFolder(_ recording: Recording) -> URL? {
        guard let folder = recording.outputFolder, recording.madeFiles.contains(Shorts.folderName) else { return nil }
        let url = URL(fileURLWithPath: folder, isDirectory: true).appending(path: Shorts.folderName, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// What the last make of shorts made, read from `Shorts/shorts.json`.
    func shortsRecord(_ recording: Recording) -> Shorts.Record? {
        shortsFolder(recording).flatMap(Shorts.Record.read)
    }

    /// The made shorts' files, in their order, with each one's record.
    func shortFiles(_ recording: Recording) -> [(short: Shorts.Short, url: URL)] {
        guard let folder = shortsFolder(recording), let record = Shorts.Record.read(folder) else { return [] }
        return record.shorts.compactMap { short in
            let url = folder.appending(path: short.fileName)
            return FileManager.default.fileExists(atPath: url.path) ? (short, url) : nil
        }
    }

    /// Make Shorts can be asked for: the transcript is made (the plan is made from it) and nothing is being made for it.
    func canMakeShorts(_ recording: Recording) -> Bool { canMakeVideo(recording) }

    /// Make Shorts: refused in words only when the people check has not run; otherwise the Shorts output is switched on for this
    /// recording and it is made again.
    func makeShorts(_ recording: Recording) {
        guard canMakeShorts(recording) else { return }
        if let refusal = videoRefusal(recording) {
            let reason = refusal.replacingOccurrences(of: "no video is made", with: "no shorts are made")
            shortsProblems[recording.id] = reason
            record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): no shorts made. \(reason)", level: .attention)
            return
        }
        shortsProblems[recording.id] = nil
        if !OutputResolver.isOn(.shorts, recording: recording, source: nil, defaults: defaultSettings()) {
            setOutput(.shorts, on: true, for: recording)
        }
        makeOutputs(recording)
    }

    /// The Direction tab's Shorts (design spec 3.5.3 item 5): how many, 0 to 5, and how long, 30, 45 or 60 s. Saved with the
    /// direction; used at the next make. Nothing is made until Ivan asks.
    func setShorts(count: Int? = nil, length: Int? = nil, for recording: Recording) {
        var direction = recording.direction
        if let count { direction.shortsCount = min(max(count, ShortsSettings.counts.lowerBound), ShortsSettings.counts.upperBound) }
        if let length, ShortsSettings.lengths.contains(length) { direction.shortsLength = length }
        setDirection(direction, for: recording)
    }

    /// The shorts were made with another count or length than the Direction tab now asks for.
    func shortsBehind(_ recording: Recording) -> String? {
        guard let record = shortsRecord(recording), record.settings != recording.direction.shorts else { return nil }
        return "Your newest number or length of shorts is not in them yet. Make Again to cut them."
    }

    /// The capture warning of the last shorts (a crop of a 1080p picture), for Checks.
    func shortsWarning(_ recording: Recording) -> String? { shortsRecord(recording)?.warning }

    /// The inspector's Play on a short: the Viewer on Shorts, that short, from its start.
    func showShort(_ recording: Recording, index: Int) {
        if path.last?.id == recording.persistentModelID, viewer.recordingID == recording.id {
            if viewer.rendition != .shorts { viewer.choose(.shorts, recording: recording) }
            viewer.chooseShort(index)
            return
        }
        pendingSeek = PendingSeek(recordingID: recording.id, time: 0, play: false, rendition: .shorts)
        pendingShortIndex = index
        open(recording)
    }

    /// Shows one short in the Finder.
    func showShortInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
