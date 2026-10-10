import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Milestone 2's acceptance, on real recordings, through the app's own pipeline and runner (not
/// engine v0): the 13 Sep talk becomes an episode at podcast loudness with a transcript that reaches
/// the end and a report; the silent 14 Sep class is refused as Needs a decision with nothing made;
/// a 30 s clip is filed as a test. Then the Recordings screen and each recording's page are drawn
/// with what was really measured.
///
///   cd ~/Code/prakriti/mac && make accept MILESTONE=m2
///
/// Skipped unless PRAKRITI_ACCEPTANCE=1 (make accept sets it): it reads about 6 GB of video and
/// takes a few minutes. Outputs go to ~/Prakriti/Dev/Outputs; the store is in memory; the run log
/// lines go to the development log. The originals are only read, never changed.
@MainActor
final class PipelineAcceptanceTests: XCTestCase {
    /// The only studio files this test may read, each named in the build prompt. Never the 16, 20
    /// or 23 Sep classes, never the archive (student privacy).
    private static let allowedStudioFiles = [
        "2026-09-13/2026-09-13 18-25-44.mp4", // the 13 Sep talk, Gabriel only
        "2026-09-14/2026-09-14 20-00-09.mp4", // the 14 Sep class, recorded with no usable sound
        "2026-09-06/2026-09-06 18-06-33.mp4", // the 6 Sep talk (episode 1)
    ]

    func testMilestoneTwoOnRealRecordings() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Reads real recordings for minutes. Run it with: cd ~/Code/prakriti/mac && make accept MILESTONE=m2")
        }
        let paths = AppPaths(mode: .development)
        XCTAssertEqual(paths.outputs.path, FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/Outputs").path)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(Int(environment["PRAKRITI_STABLE_WAIT"] ?? "") ?? 5)
        model.log.write("Acceptance test for milestone 2 started (in-memory store, outputs to \(paths.outputs.path)).")

        let studio = Self.allowedStudioFiles.map { paths.studioRecordings.appending(path: $0) }
        let talk13 = studio[0], class14 = studio[1], talk06 = studio[2]
        let clip30 = paths.drop.appending(path: "2026-09-13 clip 30s.mp4")
        let files = [clip30, class14, talk13, talk06]
        for file in files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing test media: \(file.path)")
        }

        // An output folder left by an earlier run would hide "nothing made": clear this test's own
        // folders first, only inside ~/Prakriti/Dev/Outputs.
        func outputFolder(_ file: URL) -> URL {
            paths.outputs.appending(path: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        }
        for file in files {
            let folder = outputFolder(file)
            precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
            try? FileManager.default.removeItem(at: folder)
        }
        let before = Dictionary(uniqueKeysWithValues: files.map { ($0.path, fingerprint($0)) })

        var recordings: [URL: Recording] = [:]
        for file in files {
            let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: file)
            try model.context.save()
            recordings[file] = recording
            await model.runner.process(recording, trigger: .byHand)
        }

        var report: [String] = ["Milestone 2 acceptance, \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        // 1. The 13 Sep talk: an episode between -17 and -15 LUFS, true peak at or under -1.0 dBFS,
        //    a transcript reaching within 120 s of the end, and a report.
        let talk = try XCTUnwrap(recordings[talk13])
        XCTAssertEqual(talk.status, .readyForYourYes, talk.statusReason ?? "")
        let talkFolder = outputFolder(talk13)
        let lufs = try XCTUnwrap(talk.loudnessLUFS)
        let peak = try XCTUnwrap(talk.truePeakDBFS)
        XCTAssertGreaterThanOrEqual(lufs, -17)
        XCTAssertLessThanOrEqual(lufs, -15)
        XCTAssertLessThanOrEqual(peak, -1.0)
        let duration = try XCTUnwrap(talk.duration)
        let reaches = try XCTUnwrap(talk.transcriptReaches)
        XCTAssertLessThanOrEqual(duration - reaches, 120)
        for name in ["episode.mp3", "transcript.txt", "transcript.srt", "transcript.vtt", "REPORT.md"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: talkFolder.appending(path: name).path), "\(name) missing")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: talkFolder.appending(path: "speech.wav").path))
        // Measured again, a second way (loudnorm's own meter in print mode), so the number does not
        // rest on one parser.
        let again = try remeasure(talkFolder.appending(path: "episode.mp3"))
        XCTAssertEqual(again.lufs, lufs, accuracy: 0.3, "two meters disagree on the episode's loudness")
        let srt = try String(contentsOf: talkFolder.appending(path: "transcript.srt"), encoding: .utf8)
        XCTAssertEqual(Measure.lastCueEnd(srt: srt), reaches)
        let markdown = try String(contentsOf: talkFolder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(markdown.contains(String(format: "%.1f LUFS", lufs)), "the report carries the measured loudness")
        report += summary("13 Sep talk", talk, folder: talkFolder, remeasured: again)

        // 2. The silent 14 Sep class: Needs a decision, nothing made.
        let silent = try XCTUnwrap(recordings[class14])
        XCTAssertEqual(silent.status, .needsADecision, silent.statusReason ?? "")
        XCTAssertLessThanOrEqual(silent.loudestDB ?? -.infinity, -60)
        XCTAssertNil(silent.outputFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputFolder(class14).path), "something was made from the silent class")
        report += summary("14 Sep class", silent, folder: nil, remeasured: nil)

        // 3. The 30 s clip: filed as a test, nothing made.
        let clip = try XCTUnwrap(recordings[clip30])
        XCTAssertEqual(clip.status, .skipped)
        XCTAssertEqual(clip.kind, .test)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputFolder(clip30).path), "something was made from a test clip")
        report += summary("30 s clip", clip, folder: nil, remeasured: nil)

        // 4. The 6 Sep talk, the hour-long case (engine v0: -16.7 LUFS, reaches 55:38 of 55:39).
        let long = try XCTUnwrap(recordings[talk06])
        XCTAssertEqual(long.status, .readyForYourYes, long.statusReason ?? "")
        let longAgain = try remeasure(outputFolder(talk06).appending(path: "episode.mp3"))
        XCTAssertGreaterThanOrEqual(long.loudnessLUFS ?? -99, -17)
        XCTAssertLessThanOrEqual(long.loudnessLUFS ?? 0, -15)
        XCTAssertLessThanOrEqual(long.truePeakDBFS ?? 0, -1.0)
        XCTAssertLessThanOrEqual((long.duration ?? 0) - (long.transcriptReaches ?? 0), 120)
        report += summary("6 Sep talk", long, folder: outputFolder(talk06), remeasured: longAgain)

        // The originals were only read.
        for file in files {
            XCTAssertEqual(fingerprint(file), before[file.path], "\(file.lastPathComponent) changed")
        }
        report.append("Originals unchanged (size and modification date): \(files.allSatisfy { fingerprint($0) == before[$0.path] } ? "yes" : "NO")")

        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }

        // Draw what was really processed: Recordings, Today, Activity, and each recording's page.
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var drawn: [String] = []
        for (scheme, appearance) in SnapshotRenderer.appearances {
            for item in [SidebarItem.recordings, .today, .activity] {
                model.path = []
                model.selection = item
                let name = "m2-\(item.rawValue)-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                drawn.append(name)
            }
            for (slug, file) in [("talk-13-sep", talk13), ("class-14-sep", class14), ("clip-30s", clip30), ("talk-6-sep", talk06)] {
                model.open(try XCTUnwrap(recordings[file]))
                let name = "m2-recording-\(slug)-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                drawn.append(name)
            }
        }
        report += ["", "Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", ")]
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for milestone 2 finished.")
    }

    // MARK: Helpers

    private func summary(_ title: String, _ recording: Recording, folder: URL?, remeasured: (lufs: Double, peak: Double)?) -> [String] {
        var lines = ["\(title): \(recording.fileName)",
                     "  status: \(recording.status.title). \(recording.statusReason ?? "")"]
        if let duration = recording.duration { lines.append("  length: \(Format.timecode(duration)) (\(String(format: "%.2f", duration)) s)") }
        if let loudest = recording.loudestDB { lines.append("  sound in: loudest \(loudest) dB, average \(recording.averageDB.map { String($0) } ?? "?") dB, loudness \(recording.inputLUFS.map { String($0) } ?? "?") LUFS") }
        if let lufs = recording.loudnessLUFS, let peak = recording.truePeakDBFS {
            lines.append("  episode: \(lufs) LUFS, true peak \(peak) dBFS (ebur128)")
        }
        if let remeasured { lines.append("  episode measured again: \(remeasured.lufs) LUFS, true peak \(remeasured.peak) dBTP (loudnorm print mode)") }
        if let words = recording.wordCount, let reaches = recording.transcriptReaches, let duration = recording.duration {
            lines.append("  transcript: \(words) words, reaches \(Format.timecode(reaches)) of \(Format.timecode(duration)) (gap \(Int(duration - reaches)) s)")
        }
        if let run = recording.latestRun {
            lines.append("  steps: " + run.steps.map { "\($0.name) \($0.state.rawValue)" + ($0.seconds.map { String(format: " %.1f s", $0) } ?? "") }.joined(separator: "; "))
            if let seconds = run.seconds { lines.append(String(format: "  run: %.1f s", seconds)) }
        }
        lines.append("  made: " + (folder.map { Pipeline.madeFiles(in: $0).joined(separator: ", ") } ?? "nothing"))
        lines.append("")
        return lines
    }

    /// The episode's loudness and true peak by loudnorm's meter in print mode: a second meter.
    private func remeasure(_ mp3: URL) throws -> (lufs: Double, peak: Double) {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-nostats", "-i", mp3.path, "-af", "loudnorm=print_format=json", "-f", "null", "-"]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let pass = try XCTUnwrap(Measure.loudnorm(stderr: String(decoding: data, as: UTF8.self)))
        return (try XCTUnwrap(Double(pass.inputI)), try XCTUnwrap(Double(pass.inputTP)))
    }

    private func fingerprint(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        return "\(size)@\(modified)"
    }
}
