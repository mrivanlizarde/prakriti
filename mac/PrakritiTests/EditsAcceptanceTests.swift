import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Milestone 5's acceptance, on the real 13 Sep talk, through the app's own page actions, runner,
/// pipeline and Approve:
///
///   cd ~/Code/prakriti/mac && make accept-edits MILESTONE=m5
///
/// 1. Made with the standard choices; its episode is kept aside to measure against.
/// 2. Marked as a talk; the first 10 s trimmed and 5:00 to 5:30 cut. Approve waits (Make Again first).
/// 3. Made again with those edits.
/// 4. Approved: the files are copied to the approved folder. ffprobe measures the approved MP3
///    against the first episode: about 40 s shorter (10 s trimmed, less the 1.18 s the silence trim
///    already took, plus the 30 s cut). The cut words are checked gone twice: from the approved
///    transcript, and by transcribing the approved episode again with Parakeet.
/// 5. Marked as a class: the approval is taken back and Approve is refused (Speakers not checked).
///
/// Skipped unless PRAKRITI_ACCEPTANCE=edits (the make target sets it). Reads only the 13 Sep talk,
/// read-only; writes only into ~/Prakriti/Dev/Outputs, ~/Prakriti/Dev/Approved and a temporary
/// folder; the store is in memory; its lines go to the development log. Development mode's approved
/// folder is ~/Prakriti/Dev/Approved: the live app's is ~/Prakriti/Approved (RulesTests pins it),
/// which is left for Ivan's own approvals.
@MainActor
final class EditsAcceptanceTests: XCTestCase {
    func testMilestoneFiveOnTheThirteenSepTalk() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "edits" else {
            throw XCTSkip("Reads the 13 Sep talk twice. Run it with: cd ~/Code/prakriti/mac && make accept-edits MILESTONE=m5")
        }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.log.write("Acceptance test for milestone 5 started (in-memory store, outputs to \(paths.outputs.path), approvals to \(paths.approved.path)).")
        let work = FileManager.default.temporaryDirectory.appending(path: "prakriti-m5-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

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
        let approved = model.approvedFolder(for: recording)
        precondition(approved.path.hasPrefix(paths.approved.path + "/") && paths.mode == .development)
        try? FileManager.default.removeItem(at: approved)

        var report = ["Milestone 5 acceptance, \(Date().formatted(date: .abbreviated, time: .standard))", "The 13 Sep talk: \(talk.lastPathComponent)", ""]
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var drawn: [String] = []
        func draw(_ name: String) throws {
            for (scheme, appearance) in SnapshotRenderer.appearances {
                model.open(recording)
                try renderer.render(model: model, appearance: appearance, name: "m5-\(name)-\(scheme)")
                drawn.append("m5-\(name)-\(scheme)")
            }
        }

        // 1. The standard choices.
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let firstEpisode = work.appending(path: "first episode.mp3")
        try FileManager.default.copyItem(at: folder.appending(path: "episode.mp3"), to: firstEpisode)
        let silenceAtStart = try XCTUnwrap(recording.silenceTrimmedStart)
        report += ["Run 1, the standard choices",
                   String(format: "  episode %@ (%.2f s); %.2f s of silence trimmed at the start", Format.timecode(recording.episodeDuration ?? 0),
                          recording.episodeDuration ?? 0, silenceAtStart),
                   "  approve: " + (model.approvalCheck(recording).line ?? "")]
        XCTAssertFalse(model.approvalCheck(recording).canApprove, "not marked as a talk yet: unknown voices count as students")
        XCTAssertTrue(model.approvalCheck(recording).speakersNotChecked)
        try draw("talk-1-made")

        // 2. Marked as a talk; the first 10 s trimmed; 5:00 to 5:30 cut, typed as Ivan types it.
        model.setKind(.talk, for: recording)
        XCTAssertTrue(model.approvalCheck(recording).canApprove, model.approvalCheck(recording).line ?? "")
        XCTAssertNil(model.setTrim(start: TimeText.seconds("0:10"), end: nil, for: recording))
        XCTAssertNil(model.addCut(TimeRange(start: try XCTUnwrap(TimeText.seconds("5:00")), end: try XCTUnwrap(TimeText.seconds("5:30"))), to: recording))
        XCTAssertTrue(recording.editsPending)
        let waiting = model.approvalCheck(recording)
        XCTAssertFalse(waiting.canApprove)
        XCTAssertFalse(model.approve(recording), "edits not made yet")
        XCTAssertFalse(FileManager.default.fileExists(atPath: approved.path))
        XCTAssertEqual(model.notice?.title, "Not approved", "a refusal is said in an alert")
        model.notice = nil // as Ivan's OK would; otherwise the alert dims every later picture
        report += ["", "Edits on the page: " + (recording.edits.summary ?? ""), "  approve before Make Again: refused: " + (waiting.line ?? "")]
        try draw("talk-2-edits-pending")

        // 3. Make Again.
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        XCTAssertFalse(recording.editsPending, "the episode has the edits")
        let steps = recording.latestRun?.steps ?? []
        XCTAssertTrue(steps.contains { $0.name == PipelineStep.edits.title && $0.state == .done }, "\(steps)")
        report += ["", "Run 2, made again with the edits",
                   "  steps: " + steps.map { "\($0.name) " + ($0.seconds.map { String(format: "%.1f s", $0) } ?? $0.state.rawValue) }.joined(separator: "; ")]
        for step in steps where [PipelineStep.edits.title, PipelineStep.episodeTranscript.title, PipelineStep.loudness.title].contains(step.name) {
            report.append("  \(step.name): \(step.detail ?? "")")
        }
        try draw("talk-3-made-again")

        // 4. Approve.
        XCTAssertTrue(model.approvalCheck(recording).canApprove, model.approvalCheck(recording).line ?? "")
        XCTAssertTrue(model.approve(recording))
        XCTAssertEqual(recording.status, .approved)
        let approvedFiles = Pipeline.madeFiles(in: approved)
        XCTAssertEqual(approvedFiles, ["APPROVAL.md", "REPORT.md", "episode.mp3", "transcript.md", "transcript.srt", "transcript.txt", "transcript.vtt"])
        XCTAssertFalse(approvedFiles.contains(TranscriptFiles.asHeard), "the words as heard, cut words included, stay out")
        let originalLength = try XCTUnwrap(ffprobeDuration(talk))
        let firstLength = try XCTUnwrap(ffprobeDuration(firstEpisode))
        let approvedLength = try XCTUnwrap(ffprobeDuration(approved.appending(path: "episode.mp3")))
        let shorter = firstLength - approvedLength
        let expected = (10 - silenceAtStart) + 30
        XCTAssertEqual(shorter, expected, accuracy: 0.2, "the trim and the cut are really gone")
        XCTAssertEqual(shorter, 40, accuracy: 1.5, "about 40 s shorter")
        XCTAssertEqual(originalLength - approvedLength, 40, accuracy: 0.2, "40 s shorter than the recording itself")
        let receipt = try String(contentsOf: approved.appending(path: "APPROVAL.md"), encoding: .utf8)
        let sha = try Approval.sha256(approved.appending(path: "episode.mp3"))
        XCTAssertTrue(receipt.contains(sha), "the receipt carries the approved episode's SHA-256")
        XCTAssertEqual(sha, try Approval.sha256(folder.appending(path: "episode.mp3")), "the approved episode is the made one, byte for byte")
        report += ["", "Run 3, approved into \(paths.display(approved.path))",
                   "  files: " + approvedFiles.joined(separator: ", "),
                   String(format: "  ffprobe: first episode %.3f s, approved episode %.3f s: %.2f s shorter (expected %.2f = 10 s trimmed less the %.2f s silence trim already took, plus the 30 s cut)",
                          firstLength, approvedLength, shorter, expected, silenceAtStart),
                   String(format: "  ffprobe: the original recording %.3f s: the approved episode is %.2f s shorter than it (10 s + 30 s)", originalLength, originalLength - approvedLength),
                   "  approved episode SHA-256 \(sha), the same as the made one"]

        // The cut words are gone: from the approved transcript, and from the approved audio itself.
        let heard = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))))
        let inCut = heard.filter { $0.start >= 300 && $0.end <= 330 }.map { Lexicon.apply($0.text.trimmingCharacters(in: .whitespaces)).text }
        let afterCut = heard.filter { $0.start >= 331 && $0.start < 400 }.map { Lexicon.apply($0.text.trimmingCharacters(in: .whitespaces)).text }
        let inTrim = heard.filter { $0.end <= 10 }.map { Lexicon.apply($0.text.trimmingCharacters(in: .whitespaces)).text }
        XCTAssertFalse(inCut.isEmpty, "the cut holds whole sentences to check")
        let approvedText = try String(contentsOf: approved.appending(path: "transcript.txt"), encoding: .utf8)
        for sentence in inCut where sentence.split(separator: " ").count >= 4 {
            XCTAssertFalse(approvedText.contains(sentence), "a cut sentence is in the approved transcript: \(sentence)")
        }
        for sentence in afterCut { XCTAssertTrue(approvedText.contains(sentence), "a kept sentence is missing: \(sentence)") }
        let retold = try transcribe(approved.appending(path: "episode.mp3"), in: work)
        // Every word said inside the cut (by Parakeet's own word times, not only whole sentences),
        // as five-word runs. Only runs said nowhere else in the talk count: a phrase Gabriel repeats
        // after the cut ("a lot of our students") would be heard again rightly.
        let tokens = heard.flatMap { $0.tokens ?? [] }
        let cutWords = tokens.filter { ($0.start + $0.end) / 2 > 300.3 && ($0.start + $0.end) / 2 < 329.7 }.map(\.text).joined()
        let otherWords = tokens.filter { ($0.start + $0.end) / 2 < 299 || ($0.start + $0.end) / 2 > 331 }.map(\.text).joined()
        let cutGrams = Set(grams(cutWords)).subtracting(grams(otherWords))
        let afterGrams = Set(afterCut.flatMap { grams($0) })
        let retoldGrams = Set(grams(retold))
        let cutFound = cutGrams.intersection(retoldGrams).count
        let afterFound = afterGrams.intersection(retoldGrams).count
        XCTAssertEqual(cutFound, 0, "words from the cut were heard again in the approved episode: \(cutGrams.intersection(retoldGrams))")
        XCTAssertGreaterThan(Double(afterFound), Double(afterGrams.count) * 0.5, "the talk after the cut is there")
        report += ["", "The cut, checked gone",
                   "  sentences wholly inside 5:00 to 5:30: \(inCut.count); inside the first 10 s: \(inTrim.count). None is in the approved transcript.txt.",
                   "  the approved episode transcribed again by Parakeet: \(cutFound) of \(cutGrams.count) five-word runs said in the cut (and nowhere else) heard; \(afterFound) of \(afterGrams.count) from the minute after it heard"]

        try draw("talk-4-approved")

        // 5. Marked as a class: the approval is taken back, and Approve refuses.
        let receiptBefore = try Data(contentsOf: approved.appending(path: "APPROVAL.md"))
        model.setKind(.lesson, for: recording)
        XCTAssertEqual(recording.status, .readyForYourYes, "a change takes the approval back")
        let classCheck = model.approvalCheck(recording)
        XCTAssertFalse(classCheck.canApprove)
        XCTAssertTrue(classCheck.speakersNotChecked)
        XCTAssertFalse(model.approve(recording), "a class cannot be approved")
        XCTAssertEqual(model.notice?.title, ApprovalCheck.speakersTitle)
        model.notice = nil
        XCTAssertEqual(try Data(contentsOf: approved.appending(path: "APPROVAL.md")), receiptBefore, "the earlier approved copy is left as it was")
        XCTAssertTrue(recording.isPrivacyLocked)
        report += ["", "Marked as a class: approval taken back; Approve refused: \(ApprovalCheck.speakersTitle). \(classCheck.line ?? "")"]
        try draw("talk-5-class")

        XCTAssertEqual(fingerprint(talk), before, "the original changed")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        report += ["", "Original unchanged (size and modification date): \(fingerprint(talk) == before ? "yes" : "NO")"]
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }
        report += ["", "Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", ")]
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-edits.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for milestone 5 finished.")
    }

    // MARK: Helpers

    /// Lowercased five-word runs, punctuation dropped, for comparing two transcriptions of the same speech.
    private func grams(_ text: String) -> [String] {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        guard words.count >= 5 else { return [] }
        return (0...(words.count - 5)).map { words[$0..<($0 + 5)].joined(separator: " ") }
    }

    /// The approved episode transcribed again, as Prakriti transcribes: mono 16 kHz, then Parakeet.
    private func transcribe(_ mp3: URL, in work: URL) throws -> String {
        let wav = work.appending(path: "approved.wav")
        try runTool(ToolPaths.standard.ffmpeg, ["-y", "-v", "error", "-i", mp3.path, "-ac", "1", "-ar", "16000", wav.path])
        try runTool(ToolPaths.standard.parakeet, [wav.path, "--output-dir", work.path, "--output-format", "txt", "--output-template", "retold"])
        return try String(contentsOf: work.appending(path: "retold.txt"), encoding: .utf8)
    }

    private func runTool(_ tool: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ToolPaths.searchPath + ":" + (environment["PATH"] ?? "")
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "\(tool.lastPathComponent) failed")
    }

    private func ffprobeDuration(_ file: URL) throws -> Double? {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffprobe
        process.arguments = ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Double(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func fingerprint(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        return "\(size)@\(modified)"
    }
}
