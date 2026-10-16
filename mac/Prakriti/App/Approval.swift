import CryptoKit
import Foundation

// Approve (milestone 5): Ivan's yes on one recording. It copies the finished files to
// ~/Prakriti/Approved/<name>/ with a receipt, and nothing else: nothing is uploaded, posted or
// published (the build's do-nots; SCOPE PR-1, a yes is never a publish).
//
// Who may be approved is the privacy rule, and it is checked here, not only by the button:
// - A class, a conversation, or a recording nobody has said is a talk shows "Speakers not checked"
//   and cannot be approved. Reason: Prakriti cannot yet tell whose voice is whose, and an unknown
//   voice counts as a student (SCOPE PR-2, PR-3). Only a talk Ivan marks as one teacher speaking
//   can be approved until speaker checks exist.
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
        case .readyForYourYes, .approved: break
        case .found: return ApprovalCheck(canApprove: false, line: "Nothing has been made from it yet.", speakersNotChecked: false)
        case .needsADecision, .skipped: return ApprovalCheck(canApprove: false, line: "Nothing was made from it, so there is nothing to approve.", speakersNotChecked: false)
        case .couldntFinish: return ApprovalCheck(canApprove: false, line: "It did not finish, so there is nothing to approve.", speakersNotChecked: false)
        case .working: break
        }
        if let blocked = speakersLine(recording.kind) {
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
        if recording.voices != nil && recording.faces != nil {
            return ApprovalCheck(canApprove: true, line: "Who appears and speaks was checked on this Mac, and the episode follows your choices in the People tab. Listen before you approve.",
                                 speakersNotChecked: false)
        }
        return ApprovalCheck(canApprove: true,
                             line: "Prakriti has not checked who appears and speaks in this one. You marked it as a talk with one teacher speaking: listen before you approve.",
                             speakersNotChecked: false)
    }

    /// Why this kind of recording cannot be approved until speaker checks exist, or nil for a talk.
    static func speakersLine(_ kind: RecordingKind) -> String? {
        switch kind {
        case .talk: nil
        case .lesson: "This is a class, so students may be heard. A class cannot be approved until Prakriti can check who is speaking."
        case .conversation: "More than one person speaks in a conversation, and Prakriti cannot check who yet. It cannot be approved until it can."
        case .unknown: "Nobody has said what this recording is. Unknown voices count as students, so mark it as a talk with one teacher speaking, if it is one, before approving."
        case .test: "A test recording is never approved."
        }
    }

    /// The files Approve copies: everything the last make left, except the words as heard and the
    /// writer's working record.
    @MainActor
    static func filesToApprove(_ recording: Recording) -> [String] {
        var names = recording.madeFiles
        if names.isEmpty, let folder = recording.outputFolder {
            names = Pipeline.madeFiles(in: URL(fileURLWithPath: folder)).filter(Pipeline.madeNames.contains)
        }
        // titles-notes-chapters.json keeps the model's own answer, quotes that failed the check
        // included; show-notes.md is what is approved. The timelines (v2 part M10a) are for finishing by hand, not for upload,
        // and point at the media in Outputs, so a copy in Approved would point back there: they stay out.
        return names.filter { $0 != TranscriptFiles.asHeard && $0 != "speech.wav" && $0 != WrittenPackage.fileName && $0 != TimelineExport.folderName }.sorted()
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
    }

    /// Copies `files` from `source` into `destination` with a receipt, through a staging folder, so
    /// an approval that stops halfway leaves the last approved copy as it was. Returns the files now
    /// in the approved folder.
    static func copy(_ files: [String], from source: URL, to destination: URL, receipt: Receipt) throws -> Copied {
        let fm = FileManager.default
        let staging = destination.deletingLastPathComponent().appending(path: ".approving " + destination.lastPathComponent, directoryHint: .isDirectory)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        var rows: [(name: String, bytes: Int64, sha: String)] = []
        for name in files {
            let from = source.appending(path: name)
            try fm.copyItem(at: from, to: staging.appending(path: name))
            var isFolder: ObjCBool = false
            if fm.fileExists(atPath: from.path, isDirectory: &isFolder), isFolder.boolValue {
                // The podcast-ready folder: every file in it is listed, so a change to any can be seen.
                for inner in Pipeline.madeFiles(in: from) {
                    let file = staging.appending(path: name).appending(path: inner)
                    let bytes = ((try? fm.attributesOfItem(atPath: file.path))?[.size] as? NSNumber)?.int64Value ?? 0
                    rows.append((name + "/" + inner, bytes, try sha256(file)))
                }
                continue
            }
            let bytes = ((try? fm.attributesOfItem(atPath: from.path))?[.size] as? NSNumber)?.int64Value ?? 0
            rows.append((name, bytes, try sha256(staging.appending(path: name))))
        }
        try markdown(receipt, rows: rows).write(to: staging.appending(path: receiptName), atomically: true, encoding: .utf8)
        let placed = try Pipeline.place(staging, into: destination, known: knownNames)
        return Copied(folder: destination, files: placed.files)
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
        text += "## Files\n\n| File | Size | SHA-256 |\n|---|---|---|\n"
        for row in rows { text += "| \(row.name) | \(Format.number(Int(row.bytes))) bytes | `\(row.sha)` |\n" }
        if receipt.people.isEmpty {
            text += "\nSpeakers were not checked by Prakriti: this was approved as a talk with one teacher speaking.\n"
        } else {
            text += "\n## People\n\n" + receipt.people.map { "- " + $0 }.joined(separator: "\n") + "\n"
        }
        return text
    }
}
