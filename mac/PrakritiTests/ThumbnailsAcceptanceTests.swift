import AVFoundation
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import Vision
import XCTest
@testable import Prakriti

/// v2 part M11b's acceptance (docs/v2/PLAN.md M11, checks 4, 5 and 6), through the app's runner in development:
///
/// - check 4, the **13 Sep talk** (the whole talk: M11b is the last part of M11, PLAN Wed 14 Oct; `PRAKRITI_THUMBS_EXCERPT=1` runs the
///   5-minute excerpt instead): three thumbnails, each 1280 by 720 and under 2 MB with its full-size master, Vision finding only faces
///   of people included (every face in the box of someone included, carried through the composition); the card shows the chosen one.
///   On **two-people-mixed**, with the corner face set to Hide Face: in every option Vision finds no face but the included one.
///   Frames of the talk are measured only (PLAN section 11, D1) and the pictures listed for Ivan in for-ivan/.
/// - check 5, Approve on the 13 Sep talk in development (its Approved folder under ~/Prakriti/Dev, never ~/Prakriti/Approved): the
///   sheet's deliverables, version, people and "None" for moments, drawn to pictures (words only, no frame); APPROVAL.md's hashes
///   against the copied files; every file a proved clone; a planted 190 s short unticked and named; Ready only while everything
///   chosen passes.
/// - check 6: no network request is made by Approve (a URLProtocol counter reads 0).
///
///   cd ~/Code/prakriti/mac && make accept-thumbnails MILESTONE=v2-m11b
///
/// Skipped unless PRAKRITI_ACCEPTANCE=thumbnails. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the original is only
/// read, checked by size and date before and after. Never a class, never the archive. Nothing goes to a cloud provider: writing and
/// planning are set to LM Studio (the headlines by Qwen3.8-27B) and the cloud client factory refuses and counts.
@MainActor
final class ThumbnailsAcceptanceTests: XCTestCase {
    func testThumbnailsApproveAndReady() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "thumbnails" else {
            throw XCTSkip("Reads the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-thumbnails MILESTONE=v2-m11b")
        }
        let only = environment["PRAKRITI_THUMBS_ONLY"] ?? ""
        let excerpt = environment["PRAKRITI_THUMBS_EXCERPT"] == "1"
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let paths = AppPaths(mode: .development)
        let talk = excerpt ? paths.workRoot.appending(path: "Excerpts/\(ViewerVideoAcceptanceTests.excerptName)")
            : paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        let mixed = paths.workRoot.appending(path: "Fixtures/two-people-mixed.mp4")
        XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
        let original = (talk, fingerprint(talk))
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)
        func report() {
            let text = (["v2 part M11b acceptance (thumbnails, Approve, Ready), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                        + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed.",
                           "Thumbnails for Ivan (measured only, they show the talk): \(forIvan.path)"]).joined(separator: "\n") + "\n"
            try? text.write(to: out.appending(path: "acceptance-thumbnails.txt"), atomically: true, encoding: .utf8)
            print(text)
        }

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        model.settings.provider[.planning] = .lmStudio
        model.settings.provider[.writing] = .lmStudio
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        model.log.write("Acceptance test for v2 part M11b (thumbnails, Approve, Ready) started.")
        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        try model.context.save()

        /// Reads one option's file: its size in pixels, its bytes, and the faces Vision finds in it.
        func measure(_ url: URL) async throws -> (width: Int, height: Int, bytes: Int64, faces: [FaceBox]) {
            let (w, h) = VideoThumbnails.pixelSize(url)
            return (w, h, VideoThumbnails.bytes(url), try await VideoThumbnails.facesIn(url))
        }

        // MARK: Check 4 on the 13 Sep talk, and check 5 after it.
        if only.isEmpty || only.contains("13") {
            lines.append("")
            lines.append("13 Sep: \(talk.lastPathComponent)\(excerpt ? " (the 5-minute excerpt)" : " (the whole talk)")")
            let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: talk)
            recording.kind = .talk
            try model.context.save()
            model.setTeacher(teacher, for: recording)
            model.setOutput(.editedVideo, on: true, for: recording)
            model.setOutput(.shorts, on: true, for: recording)
            model.setOutput(.thumbnails, on: true, for: recording)
            let name = talk.deletingPathExtension().lastPathComponent
            let folderURL = paths.outputs.appending(path: name, directoryHint: .isDirectory)
            let seeded = BeatsCache.seed(name, folder: folderURL)
            lines.append(seeded.map { "  Parts of the talk from the cache: \($0.line)" } ?? "  No cached parts for this transcript: the make asks Qwen3.8-27B in LM Studio.")
            let started = Date()
            await model.runner.process(recording, trigger: .byHand)
            for step in recording.latestRun?.steps ?? [] where [PipelineStep.planEdit, .renderVideo, .checkVideo, .shorts, .thumbnails].map(\.title).contains(step.name) {
                lines.append(String(format: "  step %@: %@, %.1f s. %@", step.name, step.state.rawValue, step.seconds ?? 0, step.detail ?? ""))
            }
            lines.append(String(format: "  Made in development in %.0f s; status %@.", Date().timeIntervalSince(started), recording.status.title))
            if seeded == nil, let data = try? Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard)), let heard = PlanWords.from(json: data),
               let made = BeatsFile.cached(in: folderURL, transcriptSHA256: heard.transcriptSHA256) {
                try? BeatsCache.write(made)
            }
            guard let record = model.thumbnailsRecord(recording), let folder = model.thumbnailsFolder(recording) else {
                verdict("Check 4: the thumbnails were made", false, model.thumbnailsProblems[recording.id] ?? recording.statusReason ?? "no record")
                report()
                throw XCTSkip("no thumbnails")
            }
            for note in record.notes { lines.append("  Note: \(note)") }
            lines.append("  Headlines by \(record.headlinesBy); \(record.looked) frames looked at, \(record.refused) refused by the face check; from a \(record.source) recording.")
            verdict("Check 4: three thumbnails", record.candidates.count == 3, record.candidates.map { "\($0.letter) \u{201C}\($0.headline)\u{201D} at \(Format.timecode($0.time))" }.joined(separator: ", "))
            for candidate in record.candidates {
                let m = try await measure(folder.appending(path: candidate.fileName))
                let master = VideoThumbnails.pixelSize(folder.appending(path: candidate.masterName))
                verdict("Check 4: Thumbnail \(candidate.letter) is 1280 by 720 and under 2 MB, with its full-size master",
                        m.width == 1280 && m.height == 720 && m.bytes > 0 && m.bytes < 2_000_000 && master.0 == (record.source == "4K" ? 3840 : 1920),
                        "\(m.width) by \(m.height), \(Format.number(Int(m.bytes))) bytes; master \(master.0) by \(master.1)")
                verdict("Check 4: Thumbnail \(candidate.letter): Vision finds only faces of people included",
                        candidate.lines.first { $0.item == "People" }?.status == .pass && m.faces.count == candidate.faces,
                        "\(m.faces.count) faces found by Vision now, \(candidate.faces) when made, \(candidate.includedFaces) inside the box of someone included; "
                            + "\(candidate.composition.title), cut out: \(candidate.cutOut ? "yes" : "no")")
                verdict("Check 4: Thumbnail \(candidate.letter) reads at 168 pixels wide, with 4.5 to 1 contrast",
                        candidate.capAtSmallest >= 8 && candidate.contrast >= 4.5,
                        String(format: "capitals %.1f px at 168 wide; contrast %.1f to 1; face quality %.2f, aesthetics %.2f, eyes open %@", candidate.capAtSmallest,
                               candidate.contrast, candidate.quality, candidate.aesthetics, candidate.eyesOpen ? "yes" : "no"))
                lines.append("  Thumbnail \(candidate.letter): \(candidate.reason)")
                let copy = forIvan.appending(path: "m11b-13-Sep-thumbnail-\(candidate.letter).jpg")
                try? FileManager.default.removeItem(at: copy)
                try FileManager.default.copyItem(at: folder.appending(path: candidate.fileName), to: copy)
            }
            verdict("Check 4: the card shows the chosen thumbnail", model.tileThumbnail(recording)?.lastPathComponent == VideoThumbnails.fileName("A"),
                    model.tileThumbnail(recording)?.path ?? "none")

            // Check 5: Approve in development.
            verdict("Check 5: it waits for a yes, and it is not in Ready yet", recording.status == .readyForYourYes && !SmartGroup.ready.contains(recording.status),
                    recording.status.title)
            let renderer = try SnapshotRenderer(outputFolder: out)
            func drawSheet(_ name: String) throws {
                for (scheme, appearance) in SnapshotRenderer.appearances {
                    try renderer.renderSheet(AnyView(ApproveSheet(request: ApproveRequest(recordingID: recording.id)).frame(width: 600, height: 1168)), model: model,
                                             size: CGSize(width: 600, height: 1200), appearance: appearance, name: "\(name)-\(scheme)")
                }
            }
            var deliverables = model.approvalDeliverables(recording)
            verdict("Check 5: the sheet lists the deliverables, all passing", !deliverables.isEmpty && deliverables.allSatisfy(\.passes),
                    deliverables.map { "\($0.title)" + ($0.failure.map { " (fails: \($0))" } ?? "") }.joined(separator: "; "))
            verdict("Check 5: the sheet names the version", model.approvalVersionLine(recording) != nil, model.approvalVersionLine(recording) ?? "none")
            verdict("Check 5: the sheet has a line per people decision", !model.approvalPeopleLines(recording).isEmpty, model.approvalPeopleLines(recording).joined(separator: " | "))
            try drawSheet("28-approve-sheet-passing")
            // A planted short of 190 s: a real file, 1080 by 1920, beside the made shorts, named in their record.
            let shorts = try XCTUnwrap(model.shortsFolder(recording))
            var shortsRecord = try XCTUnwrap(Shorts.Record.read(shorts))
            let planted = shorts.appending(path: "Short 9.mp4")
            _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=0x334455:s=1080x1920:r=30000/1001", "-t", "190",
                                                                     "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", planted.path], captureStdout: false, timeout: .seconds(300))
            var plantedShort = try XCTUnwrap(shortsRecord.shorts.first)
            plantedShort.number = 9
            plantedShort.fileName = "Short 9.mp4"
            plantedShort.captionsName = "Short 9.srt"
            plantedShort.duration = 190
            shortsRecord.shorts.append(plantedShort)
            let originalRecord = try Data(contentsOf: shorts.appending(path: Shorts.recordName))
            try shortsRecord.encoded().write(to: shorts.appending(path: Shorts.recordName))
            deliverables = model.approvalDeliverables(recording)
            let plantedItem = deliverables.first { $0.id == "short-9" }
            verdict("Check 5: the planted 190 s short is unticked and named in the sheet", plantedItem?.passes == false && plantedItem?.failure?.contains("Short 9 is 190 s") == true,
                    plantedItem?.failure ?? "not listed")
            try drawSheet("28-approve-sheet-one-failing")
            // What the development Approved folder holds before (an earlier check may have approved this talk there): a refused yes
            // must leave it exactly as it was.
            func snapshot(_ url: URL) -> [String] {
                (FileManager.default.enumerator(atPath: url.path)?.allObjects as? [String] ?? []).sorted().map { path in
                    let a = try? FileManager.default.attributesOfItem(atPath: url.appending(path: path).path)
                    return "\(path) \((a?[.size] as? NSNumber)?.intValue ?? -1) \((a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
                }
            }
            let before = snapshot(model.approvedFolder(for: recording))
            CountingProtocol.count = 0
            URLProtocol.registerClass(CountingProtocol.self)
            let refused = !model.approve(recording, chosen: Set(deliverables.map(\.id)))
            verdict("Check 5: a yes covering the failing short is refused and copies nothing", refused && snapshot(model.approvedFolder(for: recording)) == before,
                    (model.notice?.message ?? "") + " The approved folder: \(before.count) entries before, unchanged after.")
            model.notice = nil
            let approved = model.approve(recording)
            URLProtocol.unregisterClass(CountingProtocol.self)
            verdict("Check 6: no network request is made by Approve", CountingProtocol.count == 0, "\(CountingProtocol.count) requests")
            let approvedFolder = model.approvedFolder(for: recording)
            verdict("Check 5: approved into the development Approved folder, never ~/Prakriti/Approved",
                    approved && approvedFolder.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/").path), approvedFolder.path)
            let approval = try XCTUnwrap(recording.approval)
            let receipt = try String(contentsOf: approvedFolder.appending(path: Approval.receiptName), encoding: .utf8)
            var matched = 0
            for row in approval.rows where (try? Approval.sha256(approvedFolder.appending(path: row.name))) == row.sha
                && receipt.contains("| \(row.name) | \(Format.number(Int(row.bytes))) bytes | `\(row.sha)` |") { matched += 1 }
            verdict("Check 5: APPROVAL.md's hashes match the copied files", matched == approval.rows.count && !approval.rows.isEmpty,
                    "\(matched) of \(approval.rows.count) files; \(approval.rows.filter(\.cloned).count) proved clones (getattrlist: same clone id, 0 bytes of their own)")
            verdict("Check 5: the receipt lists the version, the people, the names said aloud and \u{201C}None\u{201D} for moments",
                    receipt.contains("## Video version") && receipt.contains("## People") && receipt.contains("## Moments from other recordings\n\n- None."),
                    receipt.components(separatedBy: "\n").filter { $0.hasPrefix("## ") }.joined(separator: ", "))
            verdict("Check 5: the planted short was not copied", !FileManager.default.fileExists(atPath: approvedFolder.appending(path: "Shorts/Short 9.mp4").path),
                    approval.leftOut["short-9"] ?? "")
            verdict("Check 5: in Ready once everything chosen passes", recording.status == .approved && SmartGroup.ready.contains(recording.status), recording.status.title)
            // A check that stops passing: an approved file changed by hand. Out of Ready, into Needs You; put back, in Ready again.
            let video = try XCTUnwrap(approval.rows.first { $0.name.hasPrefix(VideoStep.folderName + "/") && $0.name.hasSuffix(".srt") })
            let changed = approvedFolder.appending(path: video.name)
            let kept = try Data(contentsOf: changed)
            try (kept + Data("\n".utf8)).write(to: changed)
            model.recheckApproval(recording)
            verdict("Check 5: an approved file changed: out of Ready, in Needs You as Approved, a check failed",
                    recording.status == .approvedCheckFailed && SmartGroup.needsYou.contains(recording.status) && !SmartGroup.ready.contains(recording.status),
                    recording.statusReason ?? "")
            for (scheme, appearance) in SnapshotRenderer.appearances {
                try renderer.renderSheet(AnyView(OutputsTab(recording: recording).frame(width: 400, height: 1968)), model: model, size: CGSize(width: 400, height: 2000),
                                         appearance: appearance, name: "m11b-outputs-13sep-check-failed-\(scheme)")
            }
            try kept.write(to: changed)
            model.recheckApproval(recording)
            verdict("Check 5: the file put back: in Ready again", recording.status == .approved, recording.status.title)
            try? FileManager.default.removeItem(at: planted)
            try originalRecord.write(to: shorts.appending(path: Shorts.recordName))
            lines.append("  Approved: \(recording.approvedFiles.joined(separator: ", ")). Receipt: \(approvedFolder.appending(path: Approval.receiptName).path)")
            let upload = model.uploadFacts(recording)
            for platform in UploadPlatform.allCases {
                let fields = ReadyChecklist.upload(platform, facts: upload)
                lines.append("  Upload checklist, \(platform.title): " + fields.map { "\($0.status?.rawValue ?? "YOURS") \($0.label)" }.joined(separator: "; "))
            }
        }

        // MARK: Check 4 on two-people-mixed, the corner face hidden.
        if only.isEmpty || only.contains("mixed") {
            lines.append("")
            lines.append("two-people-mixed: \(mixed.path)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: mixed.path), "cd ~/Code/prakriti/mac && make fixtures")
            let recording = Recording(filePath: mixed.path, recordedAt: Date(), foundAt: Date(), kind: .talk)
            model.context.insert(recording)
            recording.source = model.source(containing: mixed)
            try model.context.save()
            model.setOutput(.thumbnails, on: true, for: recording)
            await model.runner.process(recording, trigger: .byHand)
            let mainRow = try XCTUnwrap(recording.faces?.people.first?.id)
            let cornerRow = try XCTUnwrap(recording.faces?.people.first { $0.id != mainRow }?.id)
            model.setTeacher(teacher, for: recording)
            model.setChoice(.hideFace, for: PersonKey.face(cornerRow, names: recording.resolvedNameTable), in: recording)
            await model.runner.process(recording, trigger: .makeAgain)
            for step in recording.latestRun?.steps ?? [] where [PipelineStep.planEdit, .thumbnails].map(\.title).contains(step.name) {
                lines.append(String(format: "  step %@: %@, %.1f s. %@", step.name, step.state.rawValue, step.seconds ?? 0, step.detail ?? ""))
            }
            guard let record = model.thumbnailsRecord(recording), let folder = model.thumbnailsFolder(recording) else {
                verdict("Check 4: two-people-mixed thumbnails were made", false, model.thumbnailsProblems[recording.id] ?? "no record")
                report()
                throw XCTSkip("no thumbnails")
            }
            for note in record.notes { lines.append("  Note: \(note)") }
            verdict("Check 4: two-people-mixed made under the corner face hidden", record.signature == recording.thumbnailSignature && record.signature.contains("\(cornerRow)"),
                    "signature \(record.signature), rows: main \(mainRow), corner \(cornerRow)")
            for candidate in record.candidates {
                let m = try await measure(folder.appending(path: candidate.fileName))
                verdict("Check 4: two-people-mixed Thumbnail \(candidate.letter): no face but the included one",
                        m.faces.count <= 1 && candidate.lines.first { $0.item == "People" }?.status == .pass,
                        "\(m.faces.count) faces found by Vision" + (m.faces.first.map { String(format: " at x %.2f to %.2f, y %.2f to %.2f", $0.x, $0.x + $0.width, $0.y, $0.y + $0.height) } ?? "")
                            + "; \(candidate.composition.title) from \(Format.timecode(candidate.time)), cut out: \(candidate.cutOut ? "yes" : "no")")
                let copy = forIvan.appending(path: "m11b-two-people-mixed-thumbnail-\(candidate.letter).jpg")
                try? FileManager.default.removeItem(at: copy)
                try FileManager.default.copyItem(at: folder.appending(path: candidate.fileName), to: copy)
            }
            verdict("Check 4: two-people-mixed: three options kept", record.candidates.count == 3, "\(record.candidates.count)")
        }

        verdict("Nothing reached a cloud provider", cloudCalls.count == 0, "\(cloudCalls.count) calls")
        verdict("The original is unchanged (size and modification date)", fingerprint(original.0) == original.1, "\(original.0.lastPathComponent): \(fingerprint(original.0))")
        report()
        model.log.write("Acceptance test for v2 part M11b finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
