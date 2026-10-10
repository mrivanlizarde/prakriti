import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Milestone 4's acceptance, on the real 13 Sep talk, through the app's own settings, runner and
/// pipeline: the choices on the Outputs screen and on the recording's page change what is made.
///
///   cd ~/Code/prakriti/mac && make accept-outputs MILESTONE=m4
///
/// 1. The standard choices: -16 LUFS, the silence trim, every transcript format, the word list.
/// 2. The Outputs screen's loudness changed from -16 to -19, made again: measured near -19.
/// 3. The transcript turned off on the recording's page, made again: no transcript file is left.
/// 4. The trim off and -16 again on its page: the episode is engine v0's, bit for bit, so the
///    settings change nothing when they are off.
///
/// Skipped unless PRAKRITI_ACCEPTANCE=outputs (the make target sets it). Reads only the 13 Sep talk,
/// read-only; writes only into ~/Prakriti/Dev/Outputs; the store is in memory; its lines go to the
/// development log.
@MainActor
final class OutputsAcceptanceTests: XCTestCase {
    func testMilestoneFourOnTheThirteenSepTalk() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "outputs" else {
            throw XCTSkip("Reads the 13 Sep talk four times. Run it with: cd ~/Code/prakriti/mac && make accept-outputs MILESTONE=m4")
        }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.log.write("Acceptance test for milestone 4 started (in-memory store, outputs to \(paths.outputs.path)).")

        // The only studio file this test reads, named in the build prompt (Gabriel only).
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path))
        let folder = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: folder)
        let before = fingerprint(talk)

        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: talk)
        try model.context.save()
        let defaults = model.defaultSettings()
        let standardEpisode = try XCTUnwrap(defaults.first { $0.kind == .podcastEpisode })
        XCTAssertEqual(standardEpisode.loudnessTarget, -16)

        var report = ["Milestone 4 acceptance, \(Date().formatted(date: .abbreviated, time: .standard))", "The 13 Sep talk: \(talk.lastPathComponent)", ""]
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var drawn: [String] = []
        func draw(_ name: String, page: SidebarItem? = nil) throws {
            for (scheme, appearance) in SnapshotRenderer.appearances {
                if let page {
                    model.path = []
                    model.selection = page
                } else {
                    model.open(recording)
                }
                try renderer.render(model: model, appearance: appearance, name: "m4-\(name)-\(scheme)")
                drawn.append("m4-\(name)-\(scheme)")
            }
        }
        func transcriptFiles() -> [String] { Pipeline.madeFiles(in: folder).filter { $0.hasPrefix("transcript.") } }

        // 1. The standard choices.
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let first = try measure(folder.appending(path: "episode.mp3"))
        XCTAssertEqual(recording.loudnessLUFS ?? 0, -16, accuracy: 1.0)
        XCTAssertLessThanOrEqual(recording.truePeakDBFS ?? 0, -1.0)
        XCTAssertEqual(first.loudnorm, recording.loudnessLUFS ?? 0, accuracy: 0.3, "two meters disagree")
        XCTAssertEqual(transcriptFiles(), ["transcript.json", "transcript.md", "transcript.srt", "transcript.txt", "transcript.vtt"])
        XCTAssertEqual(recording.silenceTrimmedStart ?? 0, 1.18, accuracy: 0.05, "1.68 s of silence at the start, half a second kept")
        XCTAssertEqual(recording.silenceTrimmedEnd ?? -1, 0, accuracy: 0.05, "the talk runs to its last second")
        XCTAssertEqual(recording.episodeDuration ?? 0, (recording.duration ?? 0) - 1.18, accuracy: 1.0)
        let txt = try String(contentsOf: folder.appending(path: "transcript.txt"), encoding: .utf8)
        let heard = try String(contentsOf: folder.appending(path: "transcript.json"), encoding: .utf8)
        XCTAssertTrue(heard.contains("Yoga Marka"), "Parakeet's words as heard are kept")
        XCTAssertFalse(txt.contains("Yoga Marka"), "the word list fixed it in the .txt")
        XCTAssertGreaterThan(recording.wordListFixes ?? 0, 0)
        let reportLines = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8).components(separatedBy: "\n")
        let fixes = reportLines.drop { $0 != "## Word list fixes" }.dropFirst().prefix { !$0.hasPrefix("## ") && !$0.hasPrefix("Transcript times") }
            .filter { $0.hasPrefix("| ") && !$0.contains("Now reads") }
        report += runLines("Run 1, the standard choices (target -16 LUFS)", recording, first, folder: folder)
        report.append("  word list fixes: \(recording.wordListFixes ?? 0)")
        report += fixes.prefix(20).map { "    " + $0 }
        try draw("talk-1-standard")

        // 2. The Outputs screen's loudness, -16 to -19, and made again.
        standardEpisode.loudnessTarget = -19
        try model.context.save()
        XCTAssertEqual(model.runner.options(for: recording).loudnessTarget, -19, "the Outputs screen reaches the recording")
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let second = try measure(folder.appending(path: "episode.mp3"))
        XCTAssertEqual(recording.loudnessLUFS ?? 0, -19, accuracy: 1.0, "measured near -19")
        XCTAssertEqual(second.loudnorm, -19, accuracy: 1.0, "measured near -19 by the second meter too")
        XCTAssertLessThan(second.loudnorm, first.loudnorm - 2, "the remake is clearly quieter")
        XCTAssertLessThanOrEqual(recording.truePeakDBFS ?? 0, -1.0)
        XCTAssertEqual(transcriptFiles().count, 5, "the transcript is still on")
        report += runLines("Run 2, the Outputs screen's loudness changed to -19 LUFS, made again", recording, second, folder: folder)
        try draw("outputs-at-19", page: .outputs)

        // 3. The transcript turned off on the recording's page, and made again.
        model.setOutput(.transcript, on: false, for: recording)
        XCTAssertTrue(recording.hasOwnOutputs)
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        XCTAssertEqual(transcriptFiles(), [], "no transcript file is left")
        XCTAssertEqual(Pipeline.madeFiles(in: folder), ["REPORT.md", "episode.mp3"])
        XCTAssertEqual(recording.madeFiles, ["REPORT.md", "episode.mp3"])
        XCTAssertNil(recording.wordCount)
        XCTAssertFalse(recording.latestRun?.steps.contains { $0.name == PipelineStep.transcript.title } ?? true, "Parakeet did not run")
        let third = try measure(folder.appending(path: "episode.mp3"))
        XCTAssertEqual(third.loudnorm, -19, accuracy: 1.0, "its own choices started from the Outputs screen's -19")
        let reportText = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertFalse(reportText.contains("| Transcript |"), "the report does not claim a transcript")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        XCTAssertTrue(activity.contains { $0.contains("removed because they were not chosen this time") }, "\(activity)")
        report += runLines("Run 3, the transcript turned off for this recording, made again", recording, third, folder: folder)
        report.append("  files left: " + Pipeline.madeFiles(in: folder).joined(separator: ", "))
        try draw("talk-3-transcript-off")

        // 4. The trim off and -16 again: engine v0's episode, bit for bit.
        let own = try XCTUnwrap(recording.outputSettings.first { $0.kind == .podcastEpisode })
        own.trimSilence = false
        own.loudnessTarget = -16
        try model.context.save()
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let fourth = try measure(folder.appending(path: "episode.mp3"))
        let made = try decodedMD5(folder.appending(path: "episode.mp3"))
        let v0Episode = paths.home.appending(path: "Prakriti/Outputs/2026-09-13 18-25-44/episode.mp3")
        let v0 = FileManager.default.fileExists(atPath: v0Episode.path) ? try decodedMD5(v0Episode) : nil
        if let v0 { XCTAssertEqual(made, v0, "with the new settings off, the episode is engine v0's") }
        report += runLines("Run 4, trim off and -16 LUFS on its page (the v0 chain)", recording, fourth, folder: folder)
        report.append("  decoded audio md5: \(made); engine v0's episode: \(v0 ?? "not found") (\(made == v0 ? "identical" : "DIFFERENT"))")

        XCTAssertEqual(fingerprint(talk), before, "the original changed")
        report += ["", "Original unchanged (size and modification date): \(fingerprint(talk) == before ? "yes" : "NO")"]
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }
        report += ["", "Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", ")]
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-outputs.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for milestone 4 finished.")
    }

    // MARK: Helpers

    private struct Measured {
        let ebur128: Double
        let peak: Double
        let loudnorm: Double
        let loudnormPeak: Double
    }

    private func runLines(_ title: String, _ recording: Recording, _ m: Measured, folder: URL) -> [String] {
        var lines = ["", title]
        lines.append(String(format: "  episode: %.1f LUFS, true peak %.1f dBFS (ebur128); %.2f LUFS, %.2f dBTP (loudnorm print mode)",
                            m.ebur128, m.peak, m.loudnorm, m.loudnormPeak))
        if let length = recording.episodeDuration, let duration = recording.duration {
            lines.append(String(format: "  length: episode %@ of a %@ recording; trimmed %.2f s at the start, %.2f s at the end",
                                Format.timecode(length), Format.timecode(duration), recording.silenceTrimmedStart ?? 0, recording.silenceTrimmedEnd ?? 0))
        }
        if let words = recording.wordCount { lines.append("  transcript: \(words) words, reaches \(recording.transcriptReaches.map { Format.timecode($0) } ?? "?")") }
        if let run = recording.latestRun {
            lines.append("  steps: " + run.steps.map { "\($0.name) " + ($0.seconds.map { String(format: "%.1f s", $0) } ?? $0.state.rawValue) }.joined(separator: "; "))
            if let detail = run.steps.first(where: { $0.name == PipelineStep.episode.title })?.detail { lines.append("  episode step: \(detail)") }
        }
        lines.append("  made: " + recording.madeFiles.joined(separator: ", "))
        return lines
    }

    /// Two meters: the pipeline's own (ebur128 summary) and loudnorm's in print mode.
    private func measure(_ mp3: URL) throws -> Measured {
        let ebur = try stderr(of: ["-hide_banner", "-nostats", "-i", mp3.path, "-af", "ebur128=peak=true:framelog=verbose", "-f", "null", "-"])
        let loud = try stderr(of: ["-hide_banner", "-nostats", "-i", mp3.path, "-af", "loudnorm=print_format=json", "-f", "null", "-"])
        let e = try XCTUnwrap(Measure.ebur128(stderr: ebur))
        let l = try XCTUnwrap(Measure.loudnorm(stderr: loud))
        return Measured(ebur128: e.integratedLUFS, peak: e.truePeakDBFS, loudnorm: try XCTUnwrap(Double(l.inputI)), loudnormPeak: try XCTUnwrap(Double(l.inputTP)))
    }

    /// The md5 of the decoded audio, as milestone 2 compared episodes with engine v0's.
    private func decodedMD5(_ file: URL) throws -> String {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-v", "error", "-i", file.path, "-map", "0:a", "-f", "md5", "-"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stderr(of arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private func fingerprint(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        return "\(size)@\(modified)"
    }
}
