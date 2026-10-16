import AppKit
import Foundation
import SwiftData

// Approve, the sheet, and Ready (v2 part M11b, docs/v2/PLAN.md M11, design spec 3.11 and C8). Approve is Ivan's yes on one
// recording: it copies the deliverables he leaves ticked into ~/Prakriti/Approved/<name>/ (by APFS clone) with APPROVAL.md, and
// nothing else. Nothing is uploaded, posted or published, and nothing here reaches the network (a test counts requests: 0).
//
// - The sheet lists every deliverable of the last make, each ticked when it passes its checks; one that fails is unticked, cannot
//   be ticked, and names the failing check ("Short 2 is 190 s; the limit is 180 s."). A yes that covers a failing deliverable,
//   whoever asks, copies nothing (`approve(_:chosen:)` checks again).
// - Ready holds an approved recording only while what it approved still passes: `recheckApproval` reads the approved files (each
//   one's size against the receipt) and the chosen deliverables' checks again, at every launch and after every approval; a
//   recording that fails moves to "Approved, a check failed", in Needs You, with the reason. An approval made before this part has
//   no record to check against, and stays as it was.

/// The sheet's request.
struct ApproveRequest: Identifiable, Equatable {
    let id = UUID()
    let recordingID: UUID
}

/// What one approval covered (`Recording.approvalJSON`).
struct ApprovalRecord: Codable, Equatable, Sendable {
    var approvedAt: Date
    /// The deliverables chosen, by id ("video", "short-2").
    var chosen: [String]
    /// The deliverables left out, with the reason (unticked by Ivan, or failing a check).
    var leftOut: [String: String]
    var rows: [Approval.Row]

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String?) -> ApprovalRecord? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ApprovalRecord.self, from: data)
    }
}

extension Recording {
    var approval: ApprovalRecord? { ApprovalRecord.decode(approvalJSON) }

    /// Who is hidden in pictures now, as the thumbnails record it (`VideoThumbnails.signature`): a thumbnail made under other choices
    /// is behind, is not shown on the card, and fails its deliverable until it is made again.
    var thumbnailSignature: String {
        let rows = (faces?.people.map(\.id) ?? []).filter { hidesFace(row: $0) } + (hidesFace(row: nil) ? [0] : [])
        return VideoThumbnails.signature(hiddenRows: rows)
    }

    /// The thumbnail chosen: Ivan's pick when it is there, else the first.
    func chosenThumbnail(_ record: VideoThumbnails.Record?) -> VideoThumbnails.Candidate? {
        guard let record else { return nil }
        return thumbnailChoice.flatMap(record.candidate) ?? record.candidates.first
    }
}

extension AppModel {
    /// The moments from other recordings in the video Approve covers (v2 part M12b, design spec 3.8): each with its recording, its time
    /// there and where it plays, read from the plan the video was made from; "None." when there are none.
    func approvalMomentLines(_ recording: Recording) -> [String] {
        guard let plan = editPlan(for: recording), !plan.insertSpans.isEmpty else { return ["None."] }
        let timeline = EditTimeline(plan: plan)
        return plan.insertSpans.map { span in
            let at = timeline.pieces.first { $0.id == span.id }.map { Format.timecode(timeline.seconds($0.editFrame)) } ?? "?"
            let file = span.sourceFile.map { URL(fileURLWithPath: $0).lastPathComponent } ?? span.source
            return "From \(span.sourceLabel ?? span.source) (\(file)), \(Format.timecode(span.in)) to \(Format.timecode(span.out)) of that recording, "
                + "at \(at) of the video. Added by you."
        }
    }
}

extension AppModel {
    private func approvalLabel(_ recording: Recording) -> String {
        "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
    }

    /// Approve… (the toolbar, the inspector, the Recording menu, Command-Shift-Return): opens the sheet, or says why not.
    func askToApprove(_ recording: Recording) {
        let check = approvalCheck(recording)
        guard check.canApprove else {
            notice = Notice(title: check.speakersNotChecked ? ApprovalCheck.speakersTitle : "Not approved", message: check.line ?? "It cannot be approved now.")
            return
        }
        approveSheet = ApproveRequest(recordingID: recording.id)
    }

    /// The deliverables the sheet lists, as the last make left them and as they measure now.
    func approvalDeliverables(_ recording: Recording) -> [ApprovalDeliverable] {
        ApprovalDeliverable.list(recording)
    }

    /// The sheet's People lines: one line per decision (design spec 3.11), and the audio check.
    func approvalPeopleLines(_ recording: Recording) -> [String] {
        let lines = receiptPeople(recording)
        return lines.isEmpty ? ["Who appears and speaks was not checked by Prakriti: you marked it as a talk with one teacher speaking."] : lines
    }

    /// Where each model step ran, from the records the make left (design spec 3.11, Privacy).
    func approvalModelLines(_ recording: Recording) -> [String] {
        var lines: [String] = []
        if let written = recording.written {
            lines.append("Titles, show notes and chapters: \(written.writtenBy).")
        }
        if let folder = recording.outputFolder,
           let data = try? Data(contentsOf: URL(fileURLWithPath: folder).appending(path: BeatsFile.fileName)), let beats = BeatsFile.decode(data) {
            lines.append("The parts of the talk: \(beats.by).")
        }
        if let record = thumbnailsRecord(recording) {
            lines.append("The thumbnails' headlines: \(record.headlinesBy).")
        }
        lines.append("Faces, voices, the edit and the files: on this Mac.")
        return lines
    }

    /// The receipt's names said aloud: each kept name by name with how often, the muted ones only counted (Mac warning 37: a muted
    /// name must not reach the approved folder).
    func approvalNameLines(_ recording: Recording) -> [String] {
        guard let said = recording.namesSaid, !said.moments.isEmpty else { return [] }
        let muted = Set(recording.choices.muted(said.moments).map(\.key))
        var lines: [String] = []
        var mutedCount = 0
        for group in said.byName {
            let kept = group.moments.filter { !muted.contains($0.key) }
            mutedCount += group.moments.count - kept.count
            if !kept.isEmpty { lines.append("\(group.moments.first?.text ?? "A name"): kept, said \(Format.count(kept.count, "time")).") }
        }
        if mutedCount > 0 {
            lines.append("\(Format.count(mutedCount, "name")) muted, written as \(EpisodeTranscript.mutedWord). A muted name is never written here.")
        }
        return lines
    }

    /// Approve: copies the chosen deliverables (by default every one that passes) and a receipt to the approved folder. Refused,
    /// copying nothing, when the rules say no or any chosen deliverable fails a check, whoever asks: the sheet is only the first
    /// guard. Nothing is uploaded, posted or published.
    @discardableResult
    func approve(_ recording: Recording, chosen: Set<String>? = nil) -> Bool {
        let check = approvalCheck(recording)
        guard check.canApprove, let source = recording.outputFolder else {
            let reason = check.line ?? "It cannot be approved now."
            record("Did not approve \(approvalLabel(recording)). " + (check.speakersNotChecked ? "\(ApprovalCheck.speakersTitle): " : "") + reason, level: .attention)
            notice = Notice(title: check.speakersNotChecked ? ApprovalCheck.speakersTitle : "Not approved", message: reason)
            return false
        }
        let deliverables = approvalDeliverables(recording)
        let ids = chosen ?? Set(deliverables.filter(\.passes).map(\.id))
        let picked = deliverables.filter { ids.contains($0.id) }
        // A yes never covers a file that would fail (design spec C8): nothing is copied.
        if let failing = picked.first(where: { !$0.passes }) {
            let failure = (failing.failure ?? "").trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            let reason = "\(failing.title) fails a check: \(failure). Untick it or make it again, then approve."
            record("Did not approve \(approvalLabel(recording)). " + reason + " Nothing was copied.", level: .attention)
            notice = Notice(title: "Not approved", message: reason)
            return false
        }
        guard !picked.isEmpty else {
            record("Did not approve \(approvalLabel(recording)): nothing was chosen to approve.", level: .attention)
            notice = Notice(title: "Not approved", message: "Choose at least one file to approve.")
            return false
        }
        let destination = approvedFolder(for: recording)
        guard paths.isSafeOutputLocation(destination), destination.path.hasPrefix(paths.approved.path + "/") else {
            record("Did not approve \(approvalLabel(recording)): its approved folder would land outside \(paths.display(paths.approved.path)).", level: .problem)
            return false
        }
        let files = picked.flatMap(\.paths).sorted()
        let leftOut = deliverables.filter { !ids.contains($0.id) }
        let at = now()
        let thumbnails = thumbnailsRecord(recording)
        var receipt = Approval.Receipt(label: Format.dayLabel(recording.sessionDate), title: recording.title, notes: recording.notes,
                                       recordingFile: recording.fileName,
                                       editsSummary: recording.madeEdits.summary, approvedAt: at, people: receiptPeople(recording),
                                       version: approvalVersionLine(recording))
        receipt.deliverables = picked.map { "\($0.title): approved. \($0.detail)" }
            + leftOut.map { "\($0.title): not approved, " + ($0.failure.map { "a check fails. \($0)" } ?? "left unticked.") }
        receipt.namesSaid = approvalNameLines(recording)
        if ids.contains("thumbnails"), let chosenThumbnail = recording.chosenThumbnail(thumbnails) {
            receipt.thumbnail = "Thumbnail \(chosenThumbnail.letter), \u{201C}\(chosenThumbnail.headline)\u{201D}: \(chosenThumbnail.reason)"
        }
        receipt.moments = approvalMomentLines(recording)
        receipt.models = approvalModelLines(recording)
        do {
            let copied = try Approval.copy(files, from: URL(fileURLWithPath: source, isDirectory: true), to: destination, receipt: receipt)
            recording.status = .approved
            recording.approvedAt = at
            recording.approvedFolder = copied.folder.path
            recording.approvedFiles = copied.files
            var reasons: [String: String] = [:]
            for item in leftOut { reasons[item.id] = item.failure ?? "Left unticked." }
            recording.approvalJSON = ApprovalRecord(approvedAt: at, chosen: picked.map(\.id), leftOut: reasons, rows: copied.rows).json()
            recording.statusReason = "Approved. Its files are in \(paths.display(copied.folder.path)). Nothing was uploaded or published."
            record("Approved \(approvalLabel(recording)): \(picked.map(\.title).joined(separator: ", ")) and the receipt copied to \(paths.display(copied.folder.path)), "
                   + "\(copied.clones) of \(Format.count(copied.rows.count, "file")) as clones."
                   + (leftOut.isEmpty ? "" : " Not approved: \(leftOut.map(\.title).joined(separator: ", ")).")
                   + (approvalVersionLine(recording).map { " " + $0 } ?? "") + " Nothing was uploaded or published.")
            try? context.save()
            recheckApproval(recording)
            return true
        } catch {
            record("Could not approve \(approvalLabel(recording)): the files could not be copied (\(error.localizedDescription)). The finished files are untouched.", level: .problem)
            notice = Notice(title: "Not approved", message: "The files could not be copied to \(paths.display(destination.path)). The finished files are untouched.")
            return false
        }
    }

    /// Why what was approved no longer passes, or nil when it does: an approved file missing or changed in size, or a chosen
    /// deliverable's check failing now. Nil also for an approval with no record (made before v2 part M11b).
    func approvalProblem(_ recording: Recording) -> String? {
        guard recording.status.isApproved, let approval = recording.approval, let folder = recording.approvedFolder else { return nil }
        let root = URL(fileURLWithPath: folder, isDirectory: true)
        for row in approval.rows {
            let url = root.appending(path: row.name)
            guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber else {
                return "\(row.name) is not in the approved folder any more."
            }
            if size.int64Value != row.bytes { return "\(row.name) in the approved folder changed after it was approved." }
        }
        let now = approvalDeliverables(recording)
        for id in approval.chosen {
            guard let item = now.first(where: { $0.id == id }) else { continue }
            if let failure = item.failure { return "\(item.title): \(failure)" }
        }
        return nil
    }

    /// Reads what was approved again (v2 part M11b): an approved recording whose files or checks stop passing moves to "Approved, a
    /// check failed" (Needs You), and back to Approved (Ready) once they pass again. Returns whether it passes.
    @discardableResult
    func recheckApproval(_ recording: Recording) -> Bool {
        guard recording.status.isApproved, recording.approval != nil else { return true }
        if let problem = approvalProblem(recording) {
            if recording.status != .approvedCheckFailed {
                recording.status = .approvedCheckFailed
                recording.statusReason = "A check no longer passes: \(problem)"
                record("\(approvalLabel(recording)): approved, and a check no longer passes. \(problem)", level: .attention)
                try? context.save()
            }
            return false
        }
        if recording.status == .approvedCheckFailed {
            recording.status = .approved
            recording.statusReason = "Approved. Its files are in \(paths.display(recording.approvedFolder ?? "")). Nothing was uploaded or published."
            record("\(approvalLabel(recording)): every check of what was approved passes again.")
            try? context.save()
        }
        return true
    }

    /// Every approved recording read again, at launch.
    func recheckApprovals() {
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in all where recording.status.isApproved { recheckApproval(recording) }
    }

    /// What the upload checklists read (design spec 3.11), from the recording's own files: the video and its Description.txt and
    /// captions, the tags and the Instagram caption the writer wrote, the chosen thumbnail, and every short.
    func uploadFacts(_ recording: Recording) -> UploadFacts {
        var f = UploadFacts()
        if let folder = recording.outputFolder, let video = recording.video, recording.madeFiles.contains(VideoStep.folderName) {
            let videoFolder = URL(fileURLWithPath: folder, isDirectory: true).appending(path: VideoStep.folderName, directoryHint: .isDirectory)
            f.videoFile = videoFolder.appending(path: video.fileName)
            f.videoFailed = video.failed
            let captions = videoFolder.appending(path: video.captionsName)
            if FileManager.default.fileExists(atPath: captions.path) { f.captionsFile = captions }
            f.captionsPass = video.checklist.first { $0.item == "Captions" }?.status == .pass
            if let text = try? String(contentsOf: videoFolder.appending(path: VideoDescription.fileName), encoding: .utf8) {
                f.description = ReadyChecklist.readDescription(text)
            }
        }
        f.tags = recording.written?.tags ?? []
        f.instagram = recording.written?.social?.first { $0.platform == .instagram }?.post
        if let url = tileThumbnail(recording), let record = thumbnailsRecord(recording), let chosen = recording.chosenThumbnail(record) {
            f.thumbnail = url
            f.thumbnailLine = "Thumbnail \(chosen.letter), \u{201C}\(chosen.headline)\u{201D}: \(chosen.width) by \(chosen.height), " + String(format: "%.2f MB.", Double(chosen.bytes) / 1_000_000)
        }
        f.shorts = shortFiles(recording).map { entry in
            let folder = entry.url.deletingLastPathComponent()
            let captions = folder.appending(path: entry.short.captionsName)
            return UploadFacts.Short(number: entry.short.number, file: entry.url, captions: FileManager.default.fileExists(atPath: captions.path) ? captions : nil,
                                     summary: entry.short.summary, duration: Mp4Boxes.duration(entry.url) ?? entry.short.duration, failed: entry.short.failed)
        }
        return f
    }
}
