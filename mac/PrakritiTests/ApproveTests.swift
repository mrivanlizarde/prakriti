import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Counts every request any URLSession tries to make while it is registered (v2 part M11b, PLAN M11 check 6: Approve makes none).
final class CountingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var count = 0
    override class func canInit(with request: URLRequest) -> Bool {
        count += 1
        return false
    }
}

/// v2 part M11b: the Approve sheet's deliverables, the refusal of a failing one (nothing copied), the APFS clones and the receipt, the
/// Ready group, "Approved, a check failed", and a class approvable once its people were checked. Every file here is made by the test
/// (no recording's words or pictures).
@MainActor
final class ApproveTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-approve-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    /// An MP4 that is only its header: `ftyp` and a `moov` holding an `mvhd` of `seconds` (timescale 1000). Enough for
    /// `Mp4Boxes.duration`, which is all the sheet reads of a short.
    static func headerOnlyMP4(seconds: Double, to url: URL) throws {
        func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        var ftyp = be32(20) + Array("ftypisom".utf8) + be32(512) + Array("isom".utf8)
        var mvhd = be32(108) + Array("mvhd".utf8) + [0, 0, 0, 0] + be32(0) + be32(0) + be32(1000) + be32(UInt32(seconds * 1000))
        mvhd += [UInt8](repeating: 0, count: 108 - mvhd.count)
        let moov = be32(UInt32(8 + mvhd.count)) + Array("moov".utf8) + mvhd
        ftyp += moov
        try Data(ftyp).write(to: url)
    }

    /// A made recording with an episode, a transcript, a report, a Video folder (its checklist passing), three shorts (one of
    /// `plantedSeconds` when given) and their record, in a development store under `work`.
    static func madeRecording(in work: URL, kind: RecordingKind = .talk, plantedSeconds: Double? = nil, peopleChecked: Bool = false) throws -> (AppModel, Recording) {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: nil), now: { Fixtures.now })
        let folder = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        let fm = FileManager.default
        try fm.createDirectory(at: folder.appending(path: VideoStep.folderName), withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appending(path: Shorts.folderName), withIntermediateDirectories: true)
        for name in ["REPORT.md", "episode.mp3", "transcript.json", "transcript.txt", "edit-plan.json"] {
            try "made: \(name)".write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
        }
        try "video".write(to: folder.appending(path: "Video/Sun 13 Sep.mp4"), atomically: true, encoding: .utf8)
        try "1\n00:00:00,000 --> 00:00:02,000\nHello\n".write(to: folder.appending(path: "Video/Sun 13 Sep.srt"), atomically: true, encoding: .utf8)
        try "TITLE\nBreath first\n\nDESCRIPTION\nA talk.\n\nCHAPTERS\nMISSING: none.\n".write(to: folder.appending(path: "Video/Description.txt"), atomically: true, encoding: .utf8)
        var shorts: [Shorts.Short] = []
        for n in 1...3 {
            let seconds = n == 2 ? (plantedSeconds ?? 42) : 40 + Double(n)
            try headerOnlyMP4(seconds: seconds, to: folder.appending(path: "Shorts/Short \(n).mp4"))
            try "1\n00:00:00,000 --> 00:00:02,000\nHello\n".write(to: folder.appending(path: "Shorts/Short \(n).srt"), atomically: true, encoding: .utf8)
            shorts.append(Shorts.Short(number: n, fileName: "Short \(n).mp4", captionsName: "Short \(n).srt", start: Double(n) * 100, end: Double(n) * 100 + seconds,
                                       beat: "b\(n)", summary: "why the breath comes first", firstWord: 0, lastWord: 1, opening: "Hello", duration: n == 2 ? 42 : seconds,
                                       bytes: 100, captionPages: 3, renderSeconds: 1,
                                       lines: [ChecklistLine(status: .pass, item: "Length", detail: "fine")]))
        }
        let record = Shorts.Record(madeAt: Fixtures.now, planMadeAt: Fixtures.now, settings: ShortsSettings(), source: .crop1080, shorts: shorts, notes: [])
        try record.encoded().write(to: folder.appending(path: "Shorts/\(Shorts.recordName)"))
        let recording = Recording(filePath: home.appending(path: "Prakriti/Dev/Drop/2026-09-13 18-25-44.mp4").path, title: "Talk with Gabriel",
                                  recordedAt: Fixtures.date(2026, 9, 13, 18, 25, 44), foundAt: Fixtures.now, duration: 947.78, status: .readyForYourYes, kind: kind)
        recording.outputFolder = folder.path
        recording.madeFiles = ["REPORT.md", "Shorts", "Video", "edit-plan.json", "episode.mp3", "transcript.json", "transcript.txt"]
        let video = VideoRecord(fileName: "Sun 13 Sep.mp4", captionsName: "Sun 13 Sep.srt", duration: 890, bytes: 5, frames: 26_685, renderSeconds: 100,
                                checklist: [ChecklistLine(status: .pass, item: "Captions", detail: "fine"),
                                            ChecklistLine(status: .missing, item: "Chapters", detail: "No chapters were written for it.")],
                                madeAt: Fixtures.now, planSummary: "", peopleSignature: "")
        recording.videoJSON = video.json()
        if peopleChecked {
            recording.facesJSON = FacesFound(checkedAt: Fixtures.now, duration: 947.78).json()
            recording.voicesJSON = VoicesFound(checkedAt: Fixtures.now, duration: 947.78, source: .diarizer).json()
        }
        model.context.insert(recording)
        try model.context.save()
        return (model, recording)
    }

    func testTheSheetListsEveryDeliverableAndApproveCopiesThemByCloneWithAReceipt() throws {
        let (model, recording) = try Self.madeRecording(in: work)
        let items = model.approvalDeliverables(recording)
        XCTAssertEqual(items.map(\.id), ["podcast", "video", "short-1", "short-2", "short-3", "transcript", "report"])
        XCTAssertTrue(items.allSatisfy(\.passes), items.compactMap(\.failure).joined(separator: " | "))
        XCTAssertEqual(items.first { $0.id == "video" }?.notes, ["MISSING Chapters: No chapters were written for it."], "a MISSING line is read, not a failure")
        XCTAssertFalse(items.flatMap(\.paths).contains("edit-plan.json"), "the make's working files are not deliverables")

        CountingProtocol.count = 0
        URLProtocol.registerClass(CountingProtocol.self)
        defer { URLProtocol.unregisterClass(CountingProtocol.self) }
        XCTAssertTrue(model.approve(recording))
        XCTAssertEqual(CountingProtocol.count, 0, "Approve makes no network request")
        let folder = model.approvedFolder(for: recording)
        XCTAssertEqual(Pipeline.madeFiles(in: folder), ["APPROVAL.md", "REPORT.md", "Shorts", "Video", "episode.mp3", "transcript.txt"])
        XCTAssertEqual(Pipeline.madeFiles(in: folder.appending(path: "Shorts")),
                       ["Short 1.mp4", "Short 1.srt", "Short 2.mp4", "Short 2.srt", "Short 3.mp4", "Short 3.srt", Shorts.recordName])
        let approval = try XCTUnwrap(recording.approval)
        XCTAssertEqual(approval.rows.count, 13)
        XCTAssertTrue(approval.rows.allSatisfy(\.cloned), "every file an APFS clone: " + approval.rows.filter { !$0.cloned }.map(\.name).joined(separator: ", "))
        let receipt = try String(contentsOf: folder.appending(path: Approval.receiptName), encoding: .utf8)
        for row in approval.rows {
            XCTAssertEqual(try Approval.sha256(folder.appending(path: row.name)), row.sha, row.name)
            XCTAssertTrue(receipt.contains("| \(row.name) | \(Format.number(Int(row.bytes))) bytes | `\(row.sha)` |"), row.name)
        }
        XCTAssertTrue(receipt.contains("## Deliverables"), receipt)
        XCTAssertTrue(receipt.contains("Short 2: approved."), receipt)
        XCTAssertTrue(receipt.contains("## Moments from other recordings\n\n- None."), receipt)
        XCTAssertTrue(receipt.contains("## Where each model step ran"), receipt)
        XCTAssertFalse(receipt.contains("\u{2014}") || receipt.contains("\u{2013}"), "no dashes")
        XCTAssertEqual(recording.status, .approved)
        XCTAssertTrue(SmartGroup.ready.contains(recording.status), "in Ready while everything chosen passes")
    }

    func testAFailingDeliverableIsUntickedAndAYesCoveringItCopiesNothing() throws {
        let (model, recording) = try Self.madeRecording(in: work, plantedSeconds: 190)
        let items = model.approvalDeliverables(recording)
        let planted = try XCTUnwrap(items.first { $0.id == "short-2" })
        XCTAssertEqual(planted.failure, "Short 2 is 190 s; the limit is 180 s.", "the failing check is named")
        XCTAssertFalse(ApprovalCheck.filesToApprove(recording).contains("Shorts/Short 2.mp4"), "unticked by default")

        // Ticked anyway (any caller): refused, nothing copied.
        XCTAssertFalse(model.approve(recording, chosen: Set(items.map(\.id))))
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.approvedFolder(for: recording).path), "nothing was copied")
        XCTAssertEqual(recording.status, .readyForYourYes)
        XCTAssertEqual(model.notice?.message.hasPrefix("Short 2 fails a check: Short 2 is 190 s; the limit is 180 s."), true, model.notice?.message ?? "")

        // Left unticked: the rest is approved, and the receipt says why it was not.
        XCTAssertTrue(model.approve(recording))
        let folder = model.approvedFolder(for: recording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "Shorts/Short 2.mp4").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: "Shorts/Short 1.mp4").path))
        let receipt = try String(contentsOf: folder.appending(path: Approval.receiptName), encoding: .utf8)
        XCTAssertTrue(receipt.contains("Short 2: not approved, a check fails. Short 2 is 190 s; the limit is 180 s."), receipt)
        XCTAssertEqual(recording.approval?.leftOut["short-2"], "Short 2 is 190 s; the limit is 180 s.")
    }

    func testReadyHoldsOnlyWhatStillPassesAndAFailedCheckMovesItToNeedsYou() throws {
        let (model, recording) = try Self.madeRecording(in: work)
        XCTAssertTrue(model.approve(recording))
        XCTAssertEqual(recording.status, .approved)
        let folder = model.approvedFolder(for: recording)
        // An approved file changed: a check fails, and the recording moves to Needs You.
        try "changed by hand, longer".write(to: folder.appending(path: "episode.mp3"), atomically: true, encoding: .utf8)
        XCTAssertFalse(model.recheckApproval(recording))
        XCTAssertEqual(recording.status, .approvedCheckFailed)
        XCTAssertTrue(SmartGroup.needsYou.contains(.approvedCheckFailed))
        XCTAssertFalse(SmartGroup.ready.contains(.approvedCheckFailed))
        XCTAssertEqual(recording.statusReason, "A check no longer passes: episode.mp3 in the approved folder changed after it was approved.")
        let sections = Library.sections(for: .group(.needsYou), recordings: [recording])
        XCTAssertEqual(sections.map(\.title), ["Approved, a check failed"])
        // It can be approved again, which replaces the copy and puts it back in Ready.
        XCTAssertTrue(model.approvalCheck(recording).canApprove)
        XCTAssertTrue(model.approve(recording))
        XCTAssertEqual(recording.status, .approved)
        // An approval from before this part has no record: it is left as it was.
        recording.approvalJSON = nil
        try "changed again".write(to: folder.appending(path: "episode.mp3"), atomically: true, encoding: .utf8)
        XCTAssertTrue(model.recheckApproval(recording))
        XCTAssertEqual(recording.status, .approved)
    }

    func testAClassOrAConversationCanBeApprovedOnceItsPeopleWereChecked() throws {
        let (model, recording) = try Self.madeRecording(in: work, kind: .lesson)
        XCTAssertFalse(model.approvalCheck(recording).canApprove, "not checked: refused as before")
        XCTAssertTrue(model.approvalCheck(recording).speakersNotChecked)
        let (checkedModel, checked) = try Self.madeRecording(in: work.appending(path: "b"), kind: .lesson, peopleChecked: true)
        XCTAssertTrue(checkedModel.approvalCheck(checked).canApprove, checkedModel.approvalCheck(checked).line ?? "")
        checked.kind = .conversation
        XCTAssertTrue(checkedModel.approvalCheck(checked).canApprove)
        checked.kind = .test
        XCTAssertFalse(checkedModel.approvalCheck(checked).canApprove, "a test is never approved")
    }

    func testTheUploadChecklistsListEveryFieldInTheFormsOrder() throws {
        let (model, recording) = try Self.madeRecording(in: work, plantedSeconds: 190)
        let facts = model.uploadFacts(recording)
        let youtube = ReadyChecklist.upload(.youtube, facts: facts)
        XCTAssertEqual(youtube.map(\.label), ["Video file", "Title", "Description", "Thumbnail", "Audience: made for kids", "Altered or synthetic content", "Tags",
                                              "Chapters", "Subtitles file"])
        XCTAssertEqual(youtube.first { $0.id == "title" }?.value, .text("Breath first"))
        XCTAssertEqual(youtube.first { $0.id == "thumbnail" }?.status, .missing)
        let shorts = ReadyChecklist.upload(.youtubeShorts, facts: facts)
        XCTAssertEqual(shorts.first { $0.id == "file-2" }?.status, .fail, "190 s is over the 3 minutes a Short may be")
        let tiktok = ReadyChecklist.upload(.tiktok, facts: facts)
        XCTAssertEqual(tiktok.first { $0.id == "file-2" }?.status, .pass, "TikTok takes 10 minutes (third-party figure)")
        XCTAssertTrue(tiktok.allSatisfy(\.thirdParty), "TikTok's lines say their rule is third-party")
        for platform in UploadPlatform.allCases {
            for field in ReadyChecklist.upload(platform, facts: facts) {
                XCTAssertFalse((field.label + field.detail).unicodeScalars.contains { $0.value == 0x2014 || $0.value == 0x2013 }, field.label)
            }
        }
        // Description.txt read back: the title, the words and the chapters at its end.
        let read = ReadyChecklist.readDescription("TITLE\nBreath first\n\nDESCRIPTION\nA talk.\n\n0:00 Opening\n1:10 The breath\n2:20 Close\n\nCHAPTERS\nAlready in the description above.\n")
        XCTAssertEqual(read.title, "Breath first")
        XCTAssertEqual(read.description, "A talk.")
        XCTAssertEqual(read.chapters.map(\.start), [0, 70, 140])
    }
}
