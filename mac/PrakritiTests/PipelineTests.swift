import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The pipeline's rules, on tool output captured on this Mac and on small files ffmpeg generates in
/// a temporary folder. Nothing here reads a real recording or writes into ~/Prakriti: the real
/// recordings are PipelineAcceptanceTests (make accept).
@MainActor
final class PipelineTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-pipeline-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: The two mastering bugs (engine v0's comments)

    func testMasteringChainIsEngineV0s() {
        // Engine v0's two passes for the -16 LUFS target, copied from engine/prakriti.mjs. The Swift
        // chain adds only print_format=json to the second pass, so it can report linear or dynamic.
        let measured = Measure.LoudnormPass(inputI: "-26.67", inputTP: "-3.40", inputLRA: "6.10", inputThresh: "-37.10",
                                            targetOffset: "0.52", normalizationType: "dynamic")
        XCTAssertEqual(Mastering.firstPass(target: -16, ceiling: -1),
                       "aformat=channel_layouts=mono,aresample=48000,loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json")
        let v0Second = "aformat=channel_layouts=mono,aresample=48000,loudnorm=I=-15.4:TP=-1.5:LRA=11:measured_I=-26.67:measured_TP=-3.40:"
            + "measured_LRA=6.10:measured_thresh=-37.10:offset=0.52:linear=true,alimiter=limit=0.84:level=disabled:attack=5:release=50"
        let second = Mastering.secondPass(target: -16, ceiling: -1, measured: measured)
        XCTAssertEqual(second.replacingOccurrences(of: ":print_format=json", with: ""), v0Second)

        // Bug 1: the limiter's default auto level re-normalized to 0 dBFS (+2.2 dBFS peak, 8 Oct).
        XCTAssertTrue(second.contains("alimiter=") && second.contains("level=disabled"))
        // Bug 2: mono and the sample rate must come before the limiter, inside the chain.
        let aformat = try! XCTUnwrap(second.range(of: "aformat=channel_layouts=mono")).lowerBound
        let resample = try! XCTUnwrap(second.range(of: "aresample=48000")).lowerBound
        let limiter = try! XCTUnwrap(second.range(of: "alimiter=")).lowerBound
        XCTAssertLessThan(aformat, limiter)
        XCTAssertLessThan(resample, limiter)

        // Another target moves both passes with it.
        XCTAssertTrue(Mastering.firstPass(target: -19, ceiling: -1).contains("loudnorm=I=-19:"))
        XCTAssertTrue(Mastering.secondPass(target: -19, ceiling: -2, measured: measured).contains("loudnorm=I=-18.4:TP=-2.5:"))
    }

    // MARK: Reading the tools

    func testReadsVolumedetectAsV0Does() {
        // ffmpeg 9.0.1 prints an empty first instance before the real one (10 Oct, the 30 s clip).
        let stderr = """
        [Parsed_volumedetect_0 @ 0x777f018600] n_samples: 0
        [Parsed_volumedetect_0 @ 0x777f018b40] n_samples: 2881408
        [Parsed_volumedetect_0 @ 0x777f018b40] mean_volume: -31.5 dB
        [Parsed_volumedetect_0 @ 0x777f018b40] max_volume: -10.3 dB
        """
        XCTAssertEqual(Measure.volume(stderr: stderr), Measure.Volume(max: -10.3, mean: -31.5))
        let silent = Measure.volume(stderr: "max_volume: -91.0 dB\nmean_volume: -91.0 dB")
        XCTAssertEqual(silent.max, -91)
        XCTAssertEqual(Measure.volume(stderr: "max_volume: -inf dB").max, -.infinity)
        XCTAssertEqual(Measure.volume(stderr: "nothing").max, -.infinity, "no reading counts as no sound")
    }

    func testReadsLoudnormAndEbur128() {
        let loudnorm = """
        [Parsed_loudnorm_2 @ 0x7a7ec092c0]
        {
        \t"input_i" : "-28.26",
        \t"input_tp" : "-7.26",
        \t"input_lra" : "4.80",
        \t"input_thresh" : "-38.68",
        \t"output_i" : "-16.98",
        \t"output_tp" : "-1.50",
        \t"output_lra" : "4.20",
        \t"output_thresh" : "-27.38",
        \t"normalization_type" : "dynamic",
        \t"target_offset" : "0.98"
        }
        [out#0/null @ 0x7a7ec08900] video:0KiB audio:11256KiB
        """
        let pass = Measure.loudnorm(stderr: loudnorm)
        XCTAssertEqual(pass?.inputI, "-28.26")
        XCTAssertEqual(pass?.targetOffset, "0.98")
        XCTAssertEqual(pass?.normalizationType, "dynamic")
        XCTAssertEqual(pass?.inputLUFS, -28.26)
        XCTAssertNil(Measure.loudnorm(stderr: "no json here"))

        let ebur = """
        [Parsed_ebur128_0 @ 0x799d020b40] t: 29.9 M: -28.0 S: -27.9 I: -28.4 LUFS LRA: 5.7 LU FTPK: -12.0 dBFS TPK: -10.3 dBFS
        [Parsed_ebur128_0 @ 0x799d020b40] Summary:

          Integrated loudness:
            I:         -16.8 LUFS
            Threshold: -27.1 LUFS

          True peak:
            Peak:      -1.6 dBFS
        """
        XCTAssertEqual(Measure.ebur128(stderr: ebur), Measure.Loudness(integratedLUFS: -16.8, truePeakDBFS: -1.6))
    }

    func testCoverageReadsTheLastCueLikeV0() {
        // The 13 Sep talk's last cue (v0's transcript.srt): 15:47 of 15:48.
        let srt = "136\n00:15:40,000 --> 00:15:45,900\nThank you.\n\n137\n00:15:46,160 --> 00:15:47,600\nWe'll talk soon.\n"
        XCTAssertEqual(Measure.lastCueEnd(srt: srt), 947)
        XCTAssertEqual(Measure.lastCueEnd(srt: "01:02:03.500 --> 01:02:04.900"), 3724, "vtt timestamps use a dot")
        XCTAssertEqual(Measure.lastCueEnd(srt: ""), 0)
        XCTAssertEqual(Measure.wordCount("  one two\nthree\tfour "), 4)
        XCTAssertEqual(Measure.probe(json: #"{"streams":[{"codec_type":"video"},{"codec_type":"audio"}],"format":{"duration":"947.780000"}}"#),
                       Measure.Probe(duration: 947.78, hasAudio: true))
        XCTAssertEqual(Measure.probe(json: #"{"streams":[{"codec_type":"video"}],"format":{"duration":"61.0"}}"#)?.hasAudio, false)
        XCTAssertNil(Measure.probe(json: #"{"format":{}}"#), "no duration means it does not open yet")
    }

    func testPlannedStepsFollowTheOutputs() {
        var options = PipelineOptions()
        XCTAssertEqual(options.plannedSteps, [.complete, .sound, .speechAudio, .transcript, .coverage, .episode, .loudness, .report],
                       "PipelineOptions() is engine v0's run")
        options.applyLexicon = true
        options.trimSilence = true
        XCTAssertEqual(options.plannedSteps, [.complete, .sound, .speechAudio, .transcript, .coverage, .wordList, .trim, .episode, .loudness, .report])
        options.applyLexicon = false
        options.trimSilence = false
        options.makeTranscript = false
        XCTAssertEqual(options.plannedSteps, [.complete, .sound, .episode, .loudness, .report])
        options.makeEpisode = false
        options.makeReport = false
        XCTAssertEqual(options.plannedSteps, [.complete, .sound], "the checks always run")
        XCTAssertEqual(PipelineOptions().stableWait, .seconds(60), "engine v0 waits 60 s for the size to hold still")
        for step in PipelineStep.allCases {
            XCTAssertFalse(step.doing.localizedCaseInsensitiveContains("processing"))
        }
    }

    // MARK: Running tools

    func testSubprocessReportsOutputFailureAndTimeout() async throws {
        let echo = try await Subprocess.run(URL(fileURLWithPath: "/bin/echo"), ["hello"])
        XCTAssertEqual(echo.stdout, "hello\n")

        do {
            _ = try await Subprocess.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "echo broken >&2; exit 3"])
            XCTFail("a non-zero exit must throw")
        } catch let error as ToolError {
            XCTAssertEqual(error.kind, .failed)
            XCTAssertEqual(error.status, 3)
            XCTAssertEqual(error.stderrTail, "broken")
        }

        let clock = ContinuousClock()
        let start = clock.now
        do {
            _ = try await Subprocess.run(URL(fileURLWithPath: "/bin/sleep"), ["30"], timeout: .milliseconds(300))
            XCTFail("a tool past its limit must throw")
        } catch let error as ToolError {
            XCTAssertEqual(error.kind, .timedOut)
        }
        XCTAssertLessThan(clock.now - start, .seconds(5), "the timeout stops the tool, not just the wait")

        do {
            _ = try await Subprocess.run(URL(fileURLWithPath: "/nowhere/ffmpeg"), [])
            XCTFail("a missing tool must throw")
        } catch let error as ToolError {
            XCTAssertEqual(error.kind, .missing)
        }

        // Children get Homebrew's folder on their PATH: Parakeet calls ffmpeg by name.
        let path = try await Subprocess.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "echo $PATH"])
        XCTAssertTrue(path.stdout.hasPrefix("/opt/homebrew/bin:"))
    }

    func testCancellingStopsTheTool() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        let task = Task { try await Subprocess.run(URL(fileURLWithPath: "/bin/sleep"), ["30"]) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let result = await task.result
        XCTAssertThrowsError(try result.get())
        XCTAssertLessThan(clock.now - start, .seconds(5))
    }

    // MARK: Readiness

    func testReadinessWaitsForTheSizeToHoldStill() async throws {
        let file = try make("tone.m4a", ["-f", "lavfi", "-i", "sine=frequency=440:duration=3", "-c:a", "aac"])
        XCTAssertFalse(Readiness.isDataless(file), "a file written here is on this Mac")

        // Grow the file while readiness watches: it must not pass until the growth stops.
        let growing = work.appending(path: "growing.bin")
        try Data(count: 1000).write(to: growing)
        let readiness = Readiness(tools: .standard, stableWait: .milliseconds(400))
        let grower = Task.detached {
            for _ in 0..<4 {
                try await Task.sleep(for: .milliseconds(250))
                let handle = try FileHandle(forWritingTo: growing)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(count: 1000))
                try handle.close()
            }
        }
        do {
            _ = try await readiness.waitUntilReady(growing, log: nil)
            XCTFail("random bytes do not open")
        } catch let failure as PipelineFailure {
            XCTAssertEqual(failure.step, .complete)
            XCTAssertEqual(Readiness.size(growing), 5000, "it waited for the last write before checking the file opens")
        }
        try await grower.value

        let ready = try await readiness.waitUntilReady(file, log: nil)
        XCTAssertEqual(ready.duration, 3, accuracy: 0.1)
        XCTAssertTrue(ready.hasAudio)
    }

    // MARK: The pipeline on generated files

    private func options() -> PipelineOptions {
        var options = PipelineOptions()
        options.stableWait = .milliseconds(200)
        return options
    }

    private func run(_ file: URL) async -> (PipelineResult, URL) {
        let folder = work.appending(path: "out-" + file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        let result = await Pipeline(options: options(), log: nil).run(file: file, outputFolder: folder, label: "Test") { _ in }
        return (result, folder)
    }

    func testUnderSixtySecondsIsATestAndNothingIsMade() async throws {
        let file = try make("clip.m4a", ["-f", "lavfi", "-i", "sine=frequency=440:duration=30", "-c:a", "aac"])
        let (result, folder) = await run(file)
        XCTAssertEqual(result.outcome, .test)
        XCTAssertEqual(result.duration ?? 0, 30, accuracy: 0.2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path), "nothing is made from a test")
        XCTAssertEqual(result.steps.first?.state, .done)
        XCTAssertTrue(result.steps.dropFirst().allSatisfy { $0.state == .skipped })
    }

    func testSilenceNeedsADecisionAndNothingIsMade() async throws {
        let file = try make("silent.m4a", ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-t", "61", "-c:a", "aac"])
        let (result, folder) = await run(file)
        XCTAssertEqual(result.outcome, .silent)
        XCTAssertLessThanOrEqual(result.volume?.max ?? 0, -60)
        XCTAssertTrue(result.reason.hasPrefix("No usable sound"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path), "nothing is made from a silent recording")
        XCTAssertEqual(result.steps.first { $0.name == PipelineStep.sound.title }?.state, .failed)

        let noTrack = try make("picture.mp4", ["-f", "lavfi", "-i", "color=c=black:s=64x64:d=61", "-c:v", "libx264"])
        let (picture, pictureFolder) = await run(noTrack)
        XCTAssertEqual(picture.outcome, .silent)
        XCTAssertEqual(picture.hasAudio, false)
        XCTAssertEqual(picture.reason, "No usable sound: the file has no audio track. Nothing was made from it.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: pictureFolder.path))
    }

    func testABrokenFileCannotFinishAndSaysWhy() async throws {
        let broken = work.appending(path: "broken.mp4")
        try Data((0..<200_000).map { _ in UInt8.random(in: 0...255) }).write(to: broken)
        let (result, folder) = await run(broken)
        XCTAssertEqual(result.outcome, .failed)
        XCTAssertTrue(result.reason.hasPrefix("The file does not open"), result.reason)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    /// The whole chain on a 150 s tone: Parakeet hears no words (it writes an empty transcript), so
    /// the coverage check must say the transcript stops more than 120 s before the end, and the
    /// episode audio must still be measured at the target.
    func testTheWholeChainOnAToneReportsMissingWords() async throws {
        let file = try make("tone150.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=150", "-af", "volume=-12dB", "-c:a", "aac"])
        let (result, folder) = await run(file)
        XCTAssertEqual(result.outcome, .ready, result.reason)
        XCTAssertEqual(result.coverageOK, false, "no words reach the end of a tone")
        XCTAssertTrue(result.reason.contains("The transcript stops at"), result.reason)
        let output = try XCTUnwrap(result.output)
        XCTAssertEqual(output.integratedLUFS, -16, accuracy: 1.0)
        XCTAssertLessThanOrEqual(output.truePeakDBFS, -1.0)
        XCTAssertEqual(result.episodeDuration ?? 0, 150, accuracy: 1.0)
        XCTAssertEqual(result.wordCount, 0)
        for name in ["episode.mp3", "transcript.txt", "transcript.srt", "transcript.vtt", "REPORT.md"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: name).path), "\(name) was not made")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "speech.wav").path), "the speech WAV is removed, as in v0")
        let report = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(report.contains("**Nothing has been published.**"))
        XCTAssertTrue(report.contains("STOPS at"))
        XCTAssertFalse(report.contains("\u{2014}"), "no em dashes")
        XCTAssertTrue(result.steps.allSatisfy { $0.state == .done }, "\(result.steps)")
        XCTAssertTrue(result.steps.allSatisfy { $0.seconds != nil }, "every step has its timing")
    }

    // MARK: The runner writes it onto the recording

    func testTheRunnerRecordsEachOutcome() async throws {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .milliseconds(200)

        let clip = try make("2026-09-13 clip.m4a", ["-f", "lavfi", "-i", "sine=frequency=440:duration=20", "-c:a", "aac"])
        let silent = try make("2026-09-14 silent.m4a", ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-t", "70", "-c:a", "aac"])
        let a = Recording(filePath: clip.path, recordedAt: AppModel.dateInName(clip.lastPathComponent), foundAt: Date())
        let b = Recording(filePath: silent.path, recordedAt: AppModel.dateInName(silent.lastPathComponent), foundAt: Date())
        model.context.insert(a)
        model.context.insert(b)

        await model.runner.process(a, trigger: .byHand)
        XCTAssertEqual(a.status, .skipped)
        XCTAssertEqual(a.kind, .test)
        XCTAssertEqual(a.latestRun?.outcome, .skippedTest)
        XCTAssertNotNil(a.latestRun?.endedAt)
        XCTAssertNil(a.outputFolder)

        await model.runner.process(b, trigger: .byHand)
        XCTAssertEqual(b.status, .needsADecision)
        XCTAssertEqual(b.latestRun?.outcome, .needsADecision)
        XCTAssertNil(b.outputFolder)
        XCTAssertNil(b.currentStep)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.outputs.appending(path: "2026-09-14 silent").path))

        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Filed 2026-09-13 clip.m4a as a test") }, "\(lines)")
        XCTAssertTrue(lines.contains { $0.contains("has no usable sound") && $0.contains("Nothing was made") }, "\(lines)")
        for line in lines { XCTAssertFalse(line.contains("\u{2014}")) }
    }

    func testAQuitDuringWorkIsMarkedOnTheNextLaunch() throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        let recording = Recording(filePath: "/tmp/a.mp4", status: .working)
        model.context.insert(recording)
        let run = Run(trigger: .byHand, steps: [RunStep(name: "Sound check", state: .done, seconds: 1),
                                                RunStep(name: "Transcript", state: .running),
                                                RunStep(name: "Report", state: .waiting)])
        model.context.insert(run)
        run.recording = recording
        model.recoverInterruptedWork()
        XCTAssertEqual(recording.status, .couldntFinish)
        XCTAssertEqual(run.outcome, .stopped)
        XCTAssertEqual(run.steps.map(\.state), [.done, .failed, .skipped])
    }

    func testProcessFileRefusesWhatAddFileRefuses() throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        model.settings.isPaused = true // nothing may start while this test runs
        let studioClass = model.paths.studioRecordings.appending(path: "2026-09-16/2026-09-16 19-00-00.mp4")
        model.processFiles([studioClass])
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 0, "a class in the studio folder is refused")
        XCTAssertNotNil(model.notice)
        XCTAssertTrue(model.runner.waitingIDs.isEmpty)
    }

    // MARK: Helpers

    /// A small media file, generated by ffmpeg in the temporary folder.
    private func make(_ name: String, _ arguments: [String]) throws -> URL {
        let url = work.appending(path: name)
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-v", "error", "-y"] + arguments + [url.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "ffmpeg could not make \(name)")
        return url
    }
}
