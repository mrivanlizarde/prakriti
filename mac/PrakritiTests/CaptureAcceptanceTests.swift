import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M4b's acceptance (docs/v2/PLAN.md M4, check 3), on real files through the app's own runner, in
/// development: the 13 Sep talk (1920 by 1080, 29.97 fps, H.264, Rec. 709, one stereo track flagged as one
/// microphone in both channels with the tip "Give each speaker a microphone on its own track"), the
/// `two-people-tracks.mov` fixture (three tracks, each with its own loudness, none one microphone in both
/// channels), `silent-60s.mp4` (its track silent) and the 30 s clip (filed as a test, no output folder, its
/// capture check in the store). Then the Checks tab of each is drawn, light and dark, from what was measured.
///
///   cd ~/Code/prakriti/mac && make accept-capture MILESTONE=v2-m4b
///
/// Skipped unless PRAKRITI_ACCEPTANCE=capture. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the
/// originals are only read, checked by size and date before and after. Never a class, never the archive.
@MainActor
final class CaptureAcceptanceTests: XCTestCase {
    func testTheCaptureCheckOnRealFiles() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "capture" else {
            throw XCTSkip("Reads the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-capture MILESTONE=v2-m4b")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(Int(environment["PRAKRITI_STABLE_WAIT"] ?? "") ?? 5)
        model.log.write("Acceptance test for v2 part M4b (the capture check) started.")

        let talk13 = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        let tracks = home.appending(path: "Prakriti/Dev/Fixtures/two-people-tracks.mov")
        let silent = home.appending(path: "Prakriti/Dev/Fixtures/silent-60s.mp4")
        let clip30 = paths.drop.appending(path: "2026-09-13 clip 30s.mp4")
        let files = [talk13, tracks, silent, clip30]
        for file in files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing: \(file.path) (cd ~/Code/prakriti/mac && make fixtures)")
            XCTAssertFalse(file.path.contains("2026-09-14") || file.path.contains("2026-09-16") || file.path.contains("2026-09-20")
                           || file.path.contains("2026-09-23"), "never a class")
        }
        func outputFolder(_ file: URL) -> URL {
            paths.outputs.appending(path: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        }
        let clipFolder = outputFolder(clip30)
        precondition(clipFolder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: clipFolder)
        let before = files.map(fingerprint)

        var recordings: [URL: Recording] = [:]
        for file in files {
            let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: file)
            try model.context.save()
            recordings[file] = recording
            await model.runner.process(recording, trigger: .byHand)
        }
        try model.context.save()

        var report = ["v2 part M4b acceptance (the capture check), \(Date().formatted(date: .abbreviated, time: .standard))", ""]
        func describe(_ title: String, _ recording: Recording) throws -> CaptureReport {
            let capture = try XCTUnwrap(recording.capture, "\(title): no capture check in the store")
            report.append("\(title): \(recording.status.rawValue). \(capture.summary)")
            report.append("  step: " + (recording.latestRun?.steps.first { $0.name == PipelineStep.capture.title }?.detail ?? "none"))
            for finding in capture.findings {
                report.append("  [\(finding.level.rawValue)] \(finding.title): \(finding.value)" + (finding.tip.map { " Tip: \($0)" } ?? ""))
            }
            for track in capture.audio {
                report.append(String(format: "  track %d: %d channel(s), %@ Hz, loudest %@ dB, %@ LUFS, true peak %@ dB, left minus right %@ dB",
                                     track.number, track.channels, track.sampleRate.map(String.init) ?? "?",
                                     track.loudestDB.map { String(format: "%.1f", $0) } ?? "none",
                                     track.integratedLUFS.map { String(format: "%.1f", $0) } ?? "none",
                                     track.truePeakDBTP.map { String(format: "%.1f", $0) } ?? "none",
                                     track.differenceDB.map { String(format: "%.1f", $0) } ?? "n/a"))
            }
            report.append("")
            return capture
        }

        // The 13 Sep talk: the known state of the studio files (warning 6, Help 02).
        let talk = try describe("13 Sep talk", try XCTUnwrap(recordings[talk13]))
        let video = try XCTUnwrap(talk.video)
        XCTAssertEqual(video.width, 1920)
        XCTAssertEqual(video.height, 1080)
        XCTAssertEqual(CaptureCheck.rate(video.frameRate ?? 0), "29.97")
        XCTAssertEqual(video.codec, "h264")
        XCTAssertEqual([video.colorSpace, video.colorPrimaries, video.colorTransfer], ["bt709", "bt709", "bt709"])
        XCTAssertEqual(talk.audio.count, 1)
        XCTAssertEqual(talk.audio.first?.channels, 2)
        XCTAssertTrue(talk.audio.first?.isDualMono == true, "left minus right: \(String(describing: talk.audio.first?.differenceDB))")
        XCTAssertEqual(talk.findings.first { $0.id == "track-1-dual-mono" }?.tip, "Give each speaker a microphone on its own track.")
        XCTAssertEqual(try XCTUnwrap(recordings[talk13]).status, .readyForYourYes, "the capture check never stops a make")

        // The OBS layout fixture: three tracks, each with its own loudness, none one microphone in both channels.
        let multi = try describe("two-people-tracks.mov", try XCTUnwrap(recordings[tracks]))
        XCTAssertEqual(multi.container, "MOV")
        XCTAssertEqual(multi.audio.count, 3)
        let loudness = multi.audio.compactMap(\.integratedLUFS)
        XCTAssertEqual(loudness.count, 3, "each track has its own loudness")
        XCTAssertEqual(Set(loudness.map { ($0 * 10).rounded() }).count, 3, "three different loudnesses: \(loudness)")
        XCTAssertFalse(multi.audio.contains { $0.isDualMono })
        XCTAssertFalse(multi.findings.contains { $0.kind == .dualMono })
        XCTAssertEqual(multi.findings.first { $0.id == "audio-tracks" }?.level, .pass)

        // The silent fixture: its track is silent, and the sound check still refuses it.
        let silence = try describe("silent-60s.mp4", try XCTUnwrap(recordings[silent]))
        XCTAssertTrue(silence.audio.first?.isSilent == true)
        XCTAssertEqual(silence.findings.first { $0.id == "track-1-silent" }?.level, .fail)
        XCTAssertEqual(try XCTUnwrap(recordings[silent]).status, .needsADecision)

        // The 30 s clip: a test, nothing made, no output folder, and its capture check in the store.
        let clipRecording = try XCTUnwrap(recordings[clip30])
        XCTAssertEqual(clipRecording.kind, .test)
        XCTAssertEqual(clipRecording.status, .skipped)
        XCTAssertNil(clipRecording.outputFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: clipFolder.path), "no output folder for a test")
        let clip = try describe("30 s clip", clipRecording)
        XCTAssertEqual(clip.audio.count, 1)
        report.append("30 s clip: output folder exists: \(FileManager.default.fileExists(atPath: clipFolder.path) ? "YES" : "no")")

        // The originals were only read.
        let after = files.map(fingerprint)
        XCTAssertEqual(after, before)
        report.append("Originals unchanged (size and modification date): \(after == before ? "yes" : "NO")")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }

        // The Checks tab of each, from what was measured, light and dark.
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var drawn: [String] = []
        for (scheme, appearance) in SnapshotRenderer.appearances {
            for (slug, file) in [("talk-13-sep", talk13), ("two-people-tracks", tracks), ("silent-60s", silent), ("clip-30s", clip30)] {
                model.path = []
                model.selection = .group(.all)
                model.selectedRecordings = [try XCTUnwrap(recordings[file]).id]
                model.inspectorTab = .checks
                let name = "m4b-checks-\(slug)-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                drawn.append(name)
            }
        }
        report += ["", "Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", ")]
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-capture.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M4b finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
