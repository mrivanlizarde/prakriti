import AVFoundation
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M8c's acceptance (docs/v2/PLAN.md M8, check 4, "preview equals output", on a real talk): a 5-minute excerpt of the
/// REAL 13 Sep talk (`~/Prakriti/Dev/Excerpts/`, cut with `ffmpeg -c copy` from 2:00, PLAN "routine checks use 5-minute
/// excerpts"; the full talks wait for M8d, the last part of the group) made in development through the app's runner with the
/// edited video on, then opened in the Viewer on Video; six frames at known plan times decoded from the MP4 and taken by
/// `AVAssetImageGenerator` from the Viewer's own player item with the exact `videoComposition` object the player plays must
/// match at 38 dB or better. Numbers only: no frame of the talk is written or looked at (PLAN rule 2.1.9, D1 as this run
/// was told). Also writes the test-pattern video folder `make look-video` captures (`~/Prakriti/Dev/Fixtures/viewer-video-sample`).
///
///   cd ~/Code/prakriti/mac && make accept-viewer-video MILESTONE=v2-m8c
///
/// Skipped unless PRAKRITI_ACCEPTANCE=viewer-video. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the
/// original is only read, checked by size and date before and after. Never a class, never the archive.
@MainActor
final class ViewerVideoAcceptanceTests: XCTestCase {
    static let excerptName = "2026-09-13 excerpt 2m to 7m.mp4"

    func testTheViewerShowsWhatTheFileHolds() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "viewer-video" else {
            throw XCTSkip("Reads an excerpt of the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-viewer-video MILESTONE=v2-m8c")
        }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dev = home.appending(path: "Prakriti/Dev", directoryHint: .isDirectory)

        // The test-pattern video for the real-window capture (no person in it).
        let sample = dev.appending(path: "Fixtures/viewer-video-sample", directoryHint: .isDirectory)
        let pattern = try await VideoFixture.make(in: sample)
        lines.append("Test-pattern video for make look-video: \(sample.path) (\(pattern.record.fileName), \(Format.timecode(pattern.record.duration)), "
                     + "\(pattern.record.failed) checklist lines FAIL)")

        // The excerpt, cut once and kept (PLAN, Part TXGAP's note: routine checks use 5-minute excerpts).
        let paths = AppPaths(mode: .development)
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path), "missing: \(talk.path)")
        let before = fingerprint(talk)
        let excerpts = dev.appending(path: "Excerpts", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: excerpts, withIntermediateDirectories: true)
        let excerpt = excerpts.appending(path: Self.excerptName)
        if !FileManager.default.fileExists(atPath: excerpt.path) {
            _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y", "-ss", "120", "-i", talk.path, "-t", "300",
                                                                     "-map", "0", "-c", "copy", excerpt.path], captureStdout: false, timeout: .seconds(120))
        }
        lines.append("Excerpt: \(excerpt.path), cut with -c copy from 2:00 of the 13 Sep talk, 5:00 long")

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        model.log.write("Acceptance test for v2 part M8c (video in the Viewer) started.")
        let recording = Recording(filePath: excerpt.path, recordedAt: AppModel.dateInName(excerpt.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.kind = .talk
        try model.context.save()
        model.setOutput(.editedVideo, on: true, for: recording)
        let started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let record = try XCTUnwrap(recording.video, "the video was made (\(recording.videoProblem ?? recording.statusReason ?? "no reason"))")
        let folder = try XCTUnwrap(recording.outputFolder)
        precondition(folder.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        lines.append(String(format: "Made in development in %.0f s: %@/%@/%@, %@, Ready checklist %d FAIL, %d MISSING", Date().timeIntervalSince(started),
                            paths.display(folder), VideoStep.folderName, record.fileName, Format.timecode(record.duration), record.failed, record.missing))
        verdict("The video records the plan it was made from", record.planMadeAt != nil, "planMadeAt \(record.planMadeAt.map { "\($0)" } ?? "nil")")

        model.open(recording)
        model.openViewer(recording)
        let viewer = model.viewer
        verdict("A recording with a video opens on Video", viewer.rendition == .video && viewer.isAvailable(.video),
                "rendition \(viewer.rendition.rawValue), available \(viewer.isAvailable(.video)), reason \(viewer.unavailableReason(.video) ?? "none")")
        let ready = await viewer.videoItemReady(timeout: .seconds(120))
        let item = try XCTUnwrap(ready, viewer.originalNote ?? "the Video did not load")
        let timeline = try XCTUnwrap(viewer.videoTimeline)
        let mp4 = URL(fileURLWithPath: folder).appending(path: VideoStep.folderName).appending(path: record.fileName)
        let length = try await item.asset.load(.duration).seconds
        verdict("The player plays the plan's composition through the file's compositor, as long as the file",
                item.videoComposition?.customVideoCompositorClass == Compositor.self && abs(length - record.duration) <= timeline.frame.seconds,
                String(format: "compositor %@, %d instructions, player item %.3f s, MP4 %.3f s", String(describing: item.videoComposition?.customVideoCompositorClass),
                       item.videoComposition?.instructions.count ?? 0, length, record.duration))

        // PLAN M8 check 4.
        let compared = try await PreviewCheck.compare(item: item, mp4: mp4, timeline: timeline)
        for c in compared {
            lines.append(String(format: "      %@: edited %@ (original %@ of the excerpt): %.1f dB; the file against the preview 3 frames later %.1f dB",
                                c.span, TimeText.string(c.edited), TimeText.string(c.original), c.psnr, c.neighbour))
        }
        verdict("Check 4, preview equals output: six frames at known plan times, MP4 against the Viewer's player item, 38 dB or better",
                compared.count == 6 && compared.allSatisfy { $0.psnr >= 38 },
                "\(compared.count) frames, least " + String(format: "%.1f dB", compared.map(\.psnr).min() ?? 0)
                + ", most " + String(format: "%.1f dB", compared.map(\.psnr).max() ?? 0))

        // Restore on the real plan: it goes in the restores and waits for Make Again; nothing is made here.
        if let filler = TimelineSpan.spans(plan: try XCTUnwrap(viewer.videoPlan)).first(where: { $0.reason == .pause }) {
            let edit = model.spanEdit(filler, in: recording)
            model.applySpanEdit(filler, in: recording, undo: UndoManager())
            verdict("Restore on a shortened pause of the real plan waits for Make Again", edit == .restore && recording.planRestores.count == 1
                    && model.videoBehind(recording) != nil && !model.approvalCheck(recording).canApprove,
                    "state before \(edit), restores \(recording.planRestores.count), line \"\(model.videoBehind(recording) ?? "")\", Approve \"\(model.approvalCheck(recording).line ?? "")\"")
            recording.planRestores = []
        }

        verdict("The original is unchanged (size and modification date)", fingerprint(talk) == before, fingerprint(talk))
        let text = (["v2 part M8c acceptance (video in the Viewer), \(Date().formatted(date: .abbreviated, time: .standard))", ""] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed."]).joined(separator: "\n") + "\n"
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try text.write(to: out.appending(path: "acceptance-viewer-video.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M8c finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
