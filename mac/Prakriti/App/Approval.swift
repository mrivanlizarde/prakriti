import CryptoKit
import Darwin
import Foundation

// Approve (milestone 5): Ivan's yes on one recording. It copies the finished files to
// ~/Prakriti/Approved/<name>/ with a receipt, and nothing else: nothing is uploaded, posted or
// published (the build's do-nots; SCOPE PR-1, a yes is never a publish).
//
// Who may be approved is the privacy rule, and it is checked here, not only by the button:
// - Without a people check (faces and voices), only a talk Ivan marks as one teacher speaking can be approved: a class, a
//   conversation or a recording nobody has said is a talk shows "Speakers not checked". Since v2 part M11b, once the people
//   check ran on it, a class, a conversation or one marked "Not set" may be approved like a talk: every participant signed a
//   release (Ivan, Mon 12 Oct, PLAN section 11: "classes and recordings with other people may be approved"), and the People
//   tab's choices are applied to what is made. A test recording is never approved.
// - Since v2 part M11b Approve is a sheet of deliverables (design spec 3.11): each passes its checks or is unticked with the
//   failing check named, and a yes covering a failing deliverable copies nothing (design spec C8). The files are copied by APFS
//   clone, each proved per file, and APPROVAL.md lists the version, every people decision, the names said aloud and every file's
//   size and SHA-256.
// - The trim and cuts on the page must be in the episode (Make Again first), so a yes always
//   covers exactly what was made.
// - transcript.json is never copied: it keeps every word as heard, including the words of a cut.

/// Whether a recording can be approved now, and the one plain sentence that says why not.
struct ApprovalCheck: Equatable, Sendable {
    let canApprove: Bool
    /// The reason it cannot be approved, or a note to read before approving.
    let line: String?
    /// The privacy rule stops it: shown as "Speakers not checked".
    let speakersNotChecked: Bool

    static let speakersTitle = "Speakers not checked"

    /// The rules, in order: busy, not made, the speakers rule, edits not made yet, files gone.
    @MainActor
    static func check(_ recording: Recording, isBusy: Bool, fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> ApprovalCheck {
        if isBusy || recording.status == .working {
            return ApprovalCheck(canApprove: false, line: "It can be approved once it has been made.", speakersNotChecked: false)
        }
        switch recording.status {
        case .readyForYourYes, .approved, .approvedCheckFailed: break
        case .found: return ApprovalCheck(canApprove: false, line: "Nothing has been made from it yet.", speakersNotChecked: false)
        case .needsADecision, .skipped: return ApprovalCheck(canApprove: false, line: "Nothing was made from it, so there is nothing to approve.", speakersNotChecked: false)
        case .couldntFinish: return ApprovalCheck(canApprove: false, line: "It did not finish, so there is nothing to approve.", speakersNotChecked: false)
        case .working: break
        }
        if let blocked = speakersLine(recording.kind, peopleChecked: recording.voices != nil && recording.faces != nil) {
            return ApprovalCheck(canApprove: false, line: blocked, speakersNotChecked: true)
        }
        if recording.editsPending {
            return ApprovalCheck(canApprove: false, line: "Make Again first: the newest trim and cuts are not in the episode yet.", speakersNotChecked: false)
        }
        // Who is in it (v2 part M6c): the choices on the page must be in the episode, the audio output check must have
        // passed, and with someone left out of a mixed track the changes of voice must have been listened to. Names said
        // aloud are never asked about here (part LOCK, Ivan 12 Oct): a name is kept unless he chose Mute.
        if recording.choicesPending {
            return ApprovalCheck(canApprove: false, line: "Make Again first: your newest choices of who is in the episode, or of names to mute, are not in it yet.",
                                 speakersNotChecked: false)
        }
        // The edited video (v2 part M8c): a stretch of the plan restored in the Viewer must be in the video before a yes.
        if recording.restoresPending {
            return ApprovalCheck(canApprove: false, line: "Make Again first: what you restored is not in the video yet.", speakersNotChecked: false)
        }
        if let check = recording.peopleApplied?.check, !check.passed {
            return ApprovalCheck(canApprove: false, line: check.line { recording.label(forVoice: $0) }
                                 + " Listen there in the People tab, then change who is left out and make it again.", speakersNotChecked: false)
        }
        if recording.needsListening {
            return ApprovalCheck(canApprove: false, line: "Someone is left out, and the voices were told apart on one mixed track. Listen to the changes of voice in the People tab, "
                                 + "then mark them as listened to.", speakersNotChecked: false)
        }
        guard let folder = recording.outputFolder, !filesToApprove(recording).isEmpty,
              filesToApprove(recording).allSatisfy({ fileExists(folder + "/" + $0) }) else {
            return ApprovalCheck(canApprove: false, line: "The finished files are not all in their folder any more. Make Again first.", speakersNotChecked: false)
        }
        if recording.status == .approved {
            return ApprovalCheck(canApprove: false, line: "Any change to it takes this approval back, so the new version can be approved.", speakersNotChecked: false)
        }
        if recording.status == .approvedCheckFailed {
            return ApprovalCheck(canApprove: true, line: (recording.statusReason ?? "A check of what was approved no longer passes.") + " Approve again to replace the approved copy.",
                                 speakersNotChecked: false)
        }
        if recording.voices != nil && recording.faces != nil {
            return ApprovalCheck(canApprove: true, line: "Who appears and speaks was checked on this Mac, and the episode follows your choices in the People tab. Listen before you approve.",
                                 speakersNotChecked: false)
        }
        return ApprovalCheck(canApprove: true,
                             line: "Prakriti has not checked who appears and speaks in this one. You marked it as a talk with one teacher speaking: listen before you approve.",
                             speakersNotChecked: false)
    }

    /// Why this kind of recording cannot be approved, or nil when it can: a talk always; a class, a conversation or one not set
    /// once its people check ran (v2 part M11b, Ivan 12 Oct: every participant signed a release); a test never.
    static func speakersLine(_ kind: RecordingKind, peopleChecked: Bool = false) -> String? {
        if peopleChecked && kind != .test { return nil }
        return switch kind {
        case .talk: nil
        case .lesson: "This is a class, so students may be heard. A class can be approved once Prakriti has checked who appears and speaks in it: choose Check People."
        case .conversation: "More than one person speaks in a conversation. It can be approved once Prakriti has checked who appears and speaks in it: choose Check People."
        case .unknown: "Nobody has said what this recording is. Mark it as a talk with one teacher speaking, if it is one, or choose Check People, before approving."
        case .test: "A test recording is never approved."
        }
    }

    /// The files Approve copies by default: every deliverable that passes its checks (`ApprovalDeliverable.list`), as paths inside
    /// the output folder ("Video", "Shorts/Short 1.mp4"). Never the words as heard, the writer's working record, the timelines or
    /// the make's working files (the edit plan, the parts of the talk, the hidden faces).
    @MainActor
    static func filesToApprove(_ recording: Recording) -> [String] {
        ApprovalDeliverable.list(recording).filter(\.passes).flatMap(\.paths).sorted()
    }
}

/// One thing Approve can copy (v2 part M11b, design spec 3.11): a deliverable, its files, and whether it passes its checks. A
/// deliverable that fails is unticked and cannot be ticked, with its failing check named.
struct ApprovalDeliverable: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var symbol: String
    var detail: String
    /// Paths inside the recording's output folder.
    var paths: [String]
    /// The failing check, in one sentence, or nil when it passes.
    var failure: String?
    /// Lines to read that do not stop it (MISSING lines of a checklist).
    var notes: [String] = []

    var passes: Bool { failure == nil }

    /// The longest a vertical video may be for each place it goes: YouTube Shorts (3 minutes, support.google.com/youtube/answer/15424877);
    /// Instagram Reels (3 minutes, third-party figure, research-edit-engine.md 6.2).
    static let longestShort = OutputGate.longestShort

    /// Every deliverable the last make left, in the order the sheet lists them. `duration` measures a short's file (the sheet
    /// re-reads every short, so a file changed after the make is judged as it is now).
    @MainActor
    static func list(_ recording: Recording, duration: (URL) -> Double? = ApprovalDeliverable.fileDuration) -> [ApprovalDeliverable] {
        guard let folderPath = recording.outputFolder else { return [] }
        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        var names = Set(recording.madeFiles)
        if names.isEmpty { names = Set(Pipeline.madeFiles(in: folder).filter(Pipeline.madeNames.contains)) }
        let fm = FileManager.default
        func exists(_ path: String) -> Bool { fm.fileExists(atPath: folder.appending(path: path).path) }
        var out: [ApprovalDeliverable] = []
        if names.contains("episode.mp3") {
            var parts = ["MP3"]
            if let lufs = recording.loudnessLUFS { parts.append(Format.lufs(lufs)) }
            if let length = recording.episodeDuration ?? recording.duration { parts.append(Format.timecode(length)) }
            out.append(.init(id: "podcast", title: OutputKind.podcastEpisode.title, symbol: OutputKind.podcastEpisode.symbol, detail: parts.joined(separator: ", ") + ".",
                             paths: ["episode.mp3"], failure: exists("episode.mp3") ? nil : "The episode is not in its folder any more."))
        }
        if names.contains(PodcastPackage.folderName) {
            let ready = recording.podcastReady
            let fails = ready?.checklist.filter { $0.status == .fail } ?? []
            out.append(.init(id: "podcast-ready", title: OutputKind.podcastReady.title, symbol: OutputKind.podcastReady.symbol,
                             detail: ready.map { "MP3, \(String(format: "%.1f LUFS", $0.integratedLUFS)), \(Format.timecode($0.duration)), with its tags, captions and text." }
                                ?? "The folder for a podcast host.",
                             paths: [PodcastPackage.folderName],
                             failure: ready == nil ? "Its upload checklist cannot be read. Make Again first."
                                : fails.first.map { "Its upload checklist fails: \($0.item), \($0.detail.lowercasedFirst)" },
                             notes: (ready?.checklist.filter { $0.status == .missing } ?? []).map { "MISSING \($0.item): \($0.detail)" }))
        }
        if names.contains(VideoStep.folderName) {
            let video = recording.video
            let fails = video?.checklist.filter { $0.status == .fail } ?? []
            out.append(.init(id: "video", title: OutputKind.editedVideo.title, symbol: OutputKind.editedVideo.symbol,
                             detail: video.map { "MP4, \(Format.timecode($0.duration)), with its captions, Description.txt and Ready checklist." } ?? "The Video folder.",
                             paths: [VideoStep.folderName],
                             failure: video == nil ? "Its Ready checklist cannot be read. Make Again first."
                                : fails.first.map { "Its Ready checklist fails: \($0.item), \($0.detail.lowercasedFirst)" },
                             notes: (video?.checklist.filter { $0.status == .missing } ?? []).map { "MISSING \($0.item): \($0.detail)" }))
        }
        if names.contains(VideoThumbnails.folderName) {
            let record = VideoThumbnails.Record.read(folder.appending(path: VideoThumbnails.folderName, directoryHint: .isDirectory))
            let chosen = recording.chosenThumbnail(record)
            var failure: String?
            if record == nil || record?.candidates.isEmpty == true {
                failure = "Their record cannot be read. Make Again first."
            } else if let record, record.signature != recording.thumbnailSignature {
                failure = "They were made before your newest choices of who is hidden. Make Again first."
            } else if let record, let fail = record.candidates.flatMap(\.lines).first(where: { $0.status == .fail }) {
                failure = "A check fails: \(fail.item), \(fail.detail.lowercasedFirst)"
            } else if let record, !record.candidates.allSatisfy({ exists(VideoThumbnails.folderName + "/" + $0.fileName) }) {
                failure = "A thumbnail is not in its folder any more. Make Again first."
            }
            out.append(.init(id: "thumbnails", title: OutputKind.thumbnails.title, symbol: OutputKind.thumbnails.symbol,
                             detail: record.map { "\(Format.count($0.candidates.count, "option")), 1280 by 720 with a full-size copy each" + (chosen.map { "; Thumbnail \($0.letter) chosen." } ?? ".") }
                                ?? "The Thumbnails folder.",
                             paths: [VideoThumbnails.folderName], failure: failure))
        }
        if names.contains(Shorts.folderName) {
            let shortsFolder = folder.appending(path: Shorts.folderName, directoryHint: .isDirectory)
            for short in Shorts.Record.read(shortsFolder)?.shorts ?? [] {
                let file = Shorts.folderName + "/" + short.fileName
                let measured = duration(shortsFolder.appending(path: short.fileName))
                var failure: String?
                if !exists(file) {
                    failure = "Short \(short.number) is not in its folder any more."
                } else if let measured, measured > longestShort + 0.001 {
                    failure = String(format: "Short %d is %.0f s; the limit is %.0f s.", short.number, measured, longestShort)
                } else if let fail = short.lines.first(where: { $0.status == .fail }) {
                    failure = "Short \(short.number) fails a check: \(fail.item), \(fail.detail.lowercasedFirst)"
                } else if measured == nil {
                    failure = "Short \(short.number) does not open."
                }
                var paths = [file]
                if exists(Shorts.folderName + "/" + short.captionsName) { paths.append(Shorts.folderName + "/" + short.captionsName) }
                out.append(.init(id: "short-\(short.number)", title: "Short \(short.number)", symbol: OutputKind.shorts.symbol,
                                 detail: "\(Format.timecode(measured ?? short.duration)), 1080 by 1920, from \(Format.timecode(short.start)): \(short.summary).",
                                 paths: paths, failure: failure))
            }
        }
        let formats = ["txt", "srt", "vtt", "md"].filter { names.contains("transcript.\($0)") }
        if !formats.isEmpty {
            out.append(.init(id: "transcript", title: OutputKind.transcript.title, symbol: OutputKind.transcript.symbol,
                             detail: "." + formats.joined(separator: ", .") + ", with times.", paths: formats.map { "transcript.\($0)" }))
        }
        if names.contains(WrittenPackage.notesFileName) {
            out.append(.init(id: "notes", title: "Show notes", symbol: OutputKind.titlesNotesChapters.symbol,
                             detail: "\(WrittenPackage.notesFileName): the drafts of the title, notes and chapters.", paths: [WrittenPackage.notesFileName]))
        }
        if names.contains("REPORT.md") {
            out.append(.init(id: "report", title: OutputKind.checksAndReport.title, symbol: OutputKind.checksAndReport.symbol,
                             detail: "REPORT.md: length, sound, loudness and how far the transcript reaches.", paths: ["REPORT.md"]))
        }
        return out
    }

    /// A media file's length as AVFoundation reads it, or nil when it does not open.
    static func fileDuration(_ url: URL) -> Double? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return Mp4Boxes.duration(url)
    }
}

enum Approval {
    static let receiptName = "APPROVAL.md"

    /// The names Approve may ever replace or remove in an approved folder. Anything else there is
    /// left alone.
    static var knownNames: Set<String> { Pipeline.madeNames.union([receiptName]) }

    struct Copied: Sendable {
        let folder: URL
        let files: [String]
        /// Every file copied, with whether it is a proved APFS clone of its source (v2 part M11b).
        var rows: [Row] = []

        var clones: Int { rows.filter(\.cloned).count }
    }

    struct Row: Codable, Equatable, Sendable {
        var name: String
        var bytes: Int64
        var sha: String
        var cloned: Bool
    }

    /// The facts the receipt records.
    struct Receipt: Sendable {
        var label: String
        var title: String
        var notes: String
        var recordingFile: String
        var editsSummary: String?
        var approvedAt: Date
        /// Who is in it (v2 part M6c): one line per person, and what the audio output check found. Empty when the
        /// people check never ran on it.
        var people: [String] = []
        /// The version of the video approved (v2 part M9d): "Version 2, made Thu 15 Oct, 9:41 pm. Energetic." Nil without one.
        var version: String?
        /// What was chosen and what was left out (v2 part M11b): one line each, the reason for any left out.
        var deliverables: [String] = []
        /// The names said aloud and their choice (v2 part M11b): a kept name by name, a muted one only counted, because a muted
        /// name must never reach the approved folder (Mac warning 37).
        var namesSaid: [String] = []
        /// The thumbnail chosen, with its headline.
        var thumbnail: String?
        /// Moments from other recordings in the video (v2 part M12b), one line each, or "None.".
        var moments: [String] = []
        /// Where each model step ran.
        var models: [String] = []
    }

    /// Copies `files` (paths inside `source`, a folder or one file inside one) into `destination` with a receipt, through a staging
    /// folder, so an approval that stops halfway leaves the last approved copy as it was. Every file is an APFS clone of its source
    /// where the volume allows (`clonefile`, no extra disk), proved per file afterwards (`TimelineMedia.isClone`). Returns the
    /// top-level names now in the approved folder and every file's row.
    static func copy(_ files: [String], from source: URL, to destination: URL, receipt: Receipt) throws -> Copied {
        let fm = FileManager.default
        let staging = destination.deletingLastPathComponent().appending(path: ".approving " + destination.lastPathComponent, directoryHint: .isDirectory)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        var rows: [Row] = []
        func cloneFile(_ path: String) throws {
            let from = source.appending(path: path), to = staging.appending(path: path)
            try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
            if clonefile(from.path, to.path, 0) != 0 { try fm.copyItem(at: from, to: to) }
            let bytes = ((try? fm.attributesOfItem(atPath: from.path))?[.size] as? NSNumber)?.int64Value ?? 0
            rows.append(Row(name: path, bytes: bytes, sha: try sha256(to), cloned: TimelineMedia.isClone(to, of: from)))
        }
        for name in files {
            var isFolder: ObjCBool = false
            guard fm.fileExists(atPath: source.appending(path: name).path, isDirectory: &isFolder) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
            }
            if isFolder.boolValue {
                // A folder (the Video or Podcast-ready folder): every file in it, each listed, so a change to any can be seen.
                let folder = source.appending(path: name, directoryHint: .isDirectory)
                let inner = (fm.enumerator(atPath: folder.path)?.allObjects as? [String] ?? []).filter { path in
                    var dir: ObjCBool = false
                    return !path.split(separator: "/").contains { $0.hasPrefix(".") } && fm.fileExists(atPath: folder.appending(path: path).path, isDirectory: &dir) && !dir.boolValue
                }.sorted()
                for path in inner { try cloneFile(name + "/" + path) }
            } else {
                try cloneFile(name)
            }
        }
        // The shorts' record goes with any short chosen, so the approved folder says what each short is.
        let shortsRecord = Shorts.folderName + "/" + Shorts.recordName
        if files.contains(where: { $0.hasPrefix(Shorts.folderName + "/") }), !files.contains(shortsRecord), fm.fileExists(atPath: source.appending(path: shortsRecord).path) {
            try cloneFile(shortsRecord)
        }
        try markdown(receipt, rows: rows.map { ($0.name, $0.bytes, $0.sha) }).write(to: staging.appending(path: receiptName), atomically: true, encoding: .utf8)
        let placed = try Pipeline.place(staging, into: destination, known: knownNames)
        return Copied(folder: destination, files: placed.files, rows: rows)
    }

    /// SHA-256 of a file, read in 1 MB pieces.
    static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// APPROVAL.md: what was approved, when, with the title and notes as written, and every file's
    /// size and SHA-256, so any later change to a file can be seen.
    static func markdown(_ receipt: Receipt, rows: [(name: String, bytes: Int64, sha: String)]) -> String {
        let title = receipt.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = "# \(receipt.label): \(title.isEmpty ? "untitled" : title)\n\n"
        text += "Approved on this Mac on \(Format.dayAndTime(receipt.approvedAt)), from \(receipt.recordingFile). "
        text += "**Nothing has been uploaded or published.**\n\n"
        text += "## Title\n\n\(title.isEmpty ? "No title written yet." : title)\n\n"
        let notes = receipt.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        text += "## Notes\n\n\(notes.isEmpty ? "No notes written." : notes)\n\n"
        if let edits = receipt.editsSummary { text += "## Edits\n\n\(edits)\n\n" }
        if let version = receipt.version { text += "## Video version\n\n\(version) Approval covers this version only.\n\n" }
        if !receipt.deliverables.isEmpty { text += "## Deliverables\n\n" + receipt.deliverables.map { "- " + $0 }.joined(separator: "\n") + "\n\n" }
        if let thumbnail = receipt.thumbnail { text += "## Thumbnail\n\n\(thumbnail)\n\n" }
        if !receipt.moments.isEmpty { text += "## Moments from other recordings\n\n" + receipt.moments.map { "- " + $0 }.joined(separator: "\n") + "\n\n" }
        if !receipt.models.isEmpty { text += "## Where each model step ran\n\n" + receipt.models.map { "- " + $0 }.joined(separator: "\n") + "\n\n" }
        text += "## Files\n\n| File | Size | SHA-256 |\n|---|---|---|\n"
        for row in rows { text += "| \(row.name) | \(Format.number(Int(row.bytes))) bytes | `\(row.sha)` |\n" }
        if receipt.people.isEmpty {
            text += "\nSpeakers were not checked by Prakriti: this was approved as a talk with one teacher speaking.\n"
        } else {
            text += "\n## People\n\n" + receipt.people.map { "- " + $0 }.joined(separator: "\n") + "\n"
        }
        if !receipt.namesSaid.isEmpty {
            text += "\n## Names said aloud\n\n" + receipt.namesSaid.map { "- " + $0 }.joined(separator: "\n") + "\n"
        }
        return text
    }
}
