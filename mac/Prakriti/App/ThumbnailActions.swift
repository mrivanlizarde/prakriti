import AppKit
import Foundation

// The thumbnails in the app (v2 part M11b): Make Thumbnails on a recording already made, which one is chosen, what the inspector
// reads, and the picture the recording's card shows. They are made by a make (Make Again with the Thumbnails output switched on for
// that recording), so they go through the line, the progress, Pause and Stop like any make, and through the pipeline's staging and
// `OutputGate`. Nothing starts by itself: Thumbnails is off for every folder until Ivan turns it on (PLAN rule 2.1.7).
extension AppModel {
    /// The Thumbnails folder of a recording's last make, when it is there.
    func thumbnailsFolder(_ recording: Recording) -> URL? {
        guard let folder = recording.outputFolder, recording.madeFiles.contains(VideoThumbnails.folderName) else { return nil }
        let url = URL(fileURLWithPath: folder, isDirectory: true).appending(path: VideoThumbnails.folderName, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// What the last make of thumbnails made, read from `Thumbnails/thumbnails.json`.
    func thumbnailsRecord(_ recording: Recording) -> VideoThumbnails.Record? {
        thumbnailsFolder(recording).flatMap(VideoThumbnails.Record.read)
    }

    /// The thumbnails were made under other choices of who is hidden than the People tab holds now.
    func thumbnailsBehind(_ recording: Recording) -> String? {
        guard let record = thumbnailsRecord(recording), record.signature != recording.thumbnailSignature else { return nil }
        return "Your newest choices of who is hidden are not in the thumbnails yet. Make Again to make them again; until then the card shows its own picture."
    }

    /// The picture the card shows (Ivan, 12 Oct: "Each recording tile shows the chosen YouTube thumbnail once one exists"): the chosen
    /// thumbnail while it was made under the choices of now; else nil, and the card picture is shown.
    func tileThumbnail(_ recording: Recording) -> URL? {
        guard let folder = thumbnailsFolder(recording), let record = VideoThumbnails.Record.read(folder), record.signature == recording.thumbnailSignature,
              let chosen = recording.chosenThumbnail(record) else { return nil }
        let url = folder.appending(path: chosen.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Make Thumbnails can be asked for: the transcript is made (the plan is made from it) and nothing is being made for it.
    func canMakeThumbnails(_ recording: Recording) -> Bool { canMakeVideo(recording) }

    /// Make Thumbnails: refused in words only when the people check has not run; otherwise the Thumbnails output is switched on for
    /// this recording and it is made again.
    func makeThumbnails(_ recording: Recording) {
        guard canMakeThumbnails(recording) else { return }
        if let refusal = videoRefusal(recording) {
            let reason = refusal.replacingOccurrences(of: "no video is made", with: "no thumbnails are made")
            thumbnailsProblems[recording.id] = reason
            record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): no thumbnails made. \(reason)", level: .attention)
            return
        }
        thumbnailsProblems[recording.id] = nil
        if !OutputResolver.isOn(.thumbnails, recording: recording, source: nil, defaults: defaultSettings()) {
            setOutput(.thumbnails, on: true, for: recording)
        }
        makeOutputs(recording)
    }

    /// Choose one of the three. The card shows it at once; an approval that covered the thumbnails is taken back, because the
    /// receipt names the one chosen.
    func chooseThumbnail(_ letter: String, for recording: Recording) {
        guard recording.thumbnailChoice != letter, thumbnailsRecord(recording)?.candidate(letter) != nil else { return }
        recording.thumbnailChoice = letter
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): Thumbnail \(letter) chosen.")
        if recording.approval?.chosen.contains("thumbnails") == true { changedAfterApproval(recording, what: "the thumbnail chosen") }
        cardPictures.changed(recording.id)
        try? context.save()
    }

    func showThumbnailInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
