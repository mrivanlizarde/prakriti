import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M4a: progress on a recording while it is made (docs/v2/PLAN.md M4, check 1). The percent is weighted
/// by each stage's measured time and never goes back; a time left appears only once the running stage has a
/// measured rate; a stage stalled for 61 s says what it waits on; the window's view changes at most twice a
/// second. Then the parts that make it real: ffmpeg's own progress, Pause (a suspended tool whose time limit
/// moves on), Stop, the line's order, and the stage times this Mac learns.
@MainActor
final class ProgressTests: XCTestCase {
    private var work: URL!

    override func setUpWithError() throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-progress-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: work)
    }

    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    private func tracker(_ plan: [PipelineStep], _ expected: [PipelineStep: Double], measured: Set<PipelineStep> = []) -> ProgressTracker {
        ProgressTracker(recordingID: UUID(), label: "Sun 13 Sep", plan: plan, expected: expected, measured: measured, startedAt: t0)
    }

    // MARK: Check 1: the percent

    func testTheOverallPercentIsWeightedAndNeverGoesBack() {
        // A 1 s sound check, a 20 s transcript, a 40 s episode and an instant report.
        var t = tracker([.sound, .transcript, .episode, .report], [.sound: 1, .transcript: 20, .episode: 40, .report: 0.2])
        var shown: [Double] = []
        func look(_ s: Double) { shown.append(t.snapshot(at: at(s)).overall) }

        look(0)
        XCTAssertEqual(shown.last, 0, "it starts at 0%")
        t.begin(.sound, at: at(0))
        t.report(0.5, at: at(0.5))
        look(0.5)
        t.end(.sound, state: .done, seconds: 1, at: at(1))
        look(1)
        // Weighted: the whole sound check is 1 s of 61.2 s, so it is worth under 2%, not a quarter.
        XCTAssertEqual(shown.last ?? 0, 1 / 61.2, accuracy: 0.001)
        t.begin(.transcript, at: at(1))
        for s in stride(from: 1.0, through: 15, by: 0.5) { look(s) }   // timed: elapsed against 20 s
        XCTAssertEqual(shown.last ?? 0, (1 + 14) / 61.2, accuracy: 0.002)
        t.end(.transcript, state: .done, seconds: 14, at: at(15))      // finished early: the bar jumps forward
        look(15)
        t.begin(.episode, at: at(15))
        t.report(0.2, at: at(16)); look(16)
        t.report(0.1, at: at(17)); look(17)                             // a lower report is never shown
        t.report(0.8, at: at(40)); look(40)
        t.end(.episode, state: .failed, seconds: 25, at: at(41))       // a failed step counts as passed
        look(41)
        t.begin(.report, at: at(41))
        look(41.1)
        t.finishAll(at: at(41.2))
        let last = t.snapshot(at: at(41.2))
        shown.append(last.overall)

        for (a, b) in zip(shown, shown.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b, a, "the percent went back: \(shown)")
        }
        XCTAssertEqual(last.overall, 1)
        XCTAssertEqual(last.percent, 100)
        XCTAssertLessThan(t.snapshot(at: at(41.2)).percent, 101)

        // Rounded down: 99.9% is not shown as 100 before the make has finished.
        var almost = tracker([.episode], [.episode: 10])
        almost.begin(.episode, at: at(0))
        almost.report(0.999, at: at(9))
        XCTAssertEqual(almost.snapshot(at: at(9)).percent, 99)
    }

    // MARK: Check 1: the time left

    func testTimeLeftWaitsForAMeasuredRate() {
        // Nothing measured on this Mac: a timed stage has no rate, so no time left.
        var fresh = tracker([.transcript, .episode], [.transcript: 20, .episode: 40])
        fresh.begin(.transcript, at: at(0))
        let first = fresh.snapshot(at: at(5))
        XCTAssertNil(first.timeLeft)
        XCTAssertEqual(first.timeLeftText, "Working out the time left")

        // A tool that reports its own progress gives the stage a rate once it has moved (2% and a second).
        fresh.end(.transcript, state: .done, seconds: 18, at: at(18))
        fresh.begin(.episode, at: at(18))
        XCTAssertNil(fresh.snapshot(at: at(18.5)).timeLeft, "no report yet")
        fresh.report(0.25, at: at(22))
        let rated = fresh.snapshot(at: at(22))
        XCTAssertEqual(try XCTUnwrap(rated.timeLeft), 12, accuracy: 0.01, "a quarter in 4 s leaves 12 s")
        XCTAssertEqual(rated.timeLeftText, "Under a minute left")

        // Measured on this Mac: the timed stage has a rate from the start, and the stages to come add their usual time.
        var measured = tracker([.transcript, .episode], [.transcript: 600, .episode: 300], measured: [.transcript])
        measured.begin(.transcript, at: at(0))
        let known = measured.snapshot(at: at(228))
        XCTAssertEqual(try XCTUnwrap(known.timeLeft), 372 + 300, accuracy: 0.01)
        XCTAssertEqual(known.timeLeftText, "About 11 min left")

        // Passes not known ahead: the bar moves, but its pace is no rate. Unmeasured, no time left; measured, the
        // stage's usual time.
        var uneven = tracker([.podcastAudio], [.podcastAudio: 36])
        uneven.begin(.podcastAudio, at: at(0))
        uneven.report(0.5, even: false, at: at(2))
        XCTAssertNil(uneven.snapshot(at: at(2)).timeLeft)
        var unevenMeasured = tracker([.podcastAudio], [.podcastAudio: 36], measured: [.podcastAudio])
        unevenMeasured.begin(.podcastAudio, at: at(0))
        unevenMeasured.report(0.5, even: false, at: at(2))
        XCTAssertEqual(try XCTUnwrap(unevenMeasured.snapshot(at: at(2)).timeLeft), 34, accuracy: 0.01)
        // Before any stage starts there is no rate at all.
        var unstarted = tracker([.sound], [.sound: 1])
        XCTAssertNil(unstarted.snapshot(at: at(0)).timeLeft)

        XCTAssertEqual(TimeLeft.text(30), "Under a minute left")
        XCTAssertEqual(TimeLeft.text(372), "About 6 min left")
        XCTAssertEqual(TimeLeft.text(3600), "About 1 hr left")
        XCTAssertEqual(TimeLeft.text(4200), "About 1 hr 10 min left")
        XCTAssertEqual(TimeLeft.text(nil), "Working out the time left")
    }

    // MARK: Check 1: a stall

    func testAStallOfSixtyOneSecondsSaysWhatItWaitsOn() {
        // A timed stage stops at 95% (19 s of 20) and then does not move.
        var t = tracker([.transcript, .report], [.transcript: 20, .report: 0.2])
        t.begin(.transcript, at: at(0))
        XCTAssertNil(t.snapshot(at: at(19)).waitingOn)
        XCTAssertEqual(t.snapshot(at: at(19)).stageFraction, ProgressTracker.timedCap, accuracy: 0.001)
        XCTAssertNil(t.snapshot(at: at(19 + 59)).waitingOn, "59 s still: not yet")
        XCTAssertEqual(t.snapshot(at: at(19 + 61)).waitingOn, "Waiting for Parakeet to finish the transcript.")

        // ffmpeg that stops reporting, and the writing model.
        var ffmpeg = tracker([.episode], [.episode: 100])
        ffmpeg.begin(.episode, at: at(0))
        ffmpeg.report(0.3, at: at(1))
        _ = ffmpeg.snapshot(at: at(1))
        XCTAssertEqual(ffmpeg.snapshot(at: at(62)).waitingOn, "Waiting for ffmpeg, which has not moved for a minute.")
        // A paused make is not stalled.
        ffmpeg.pause(at: at(62))
        XCTAssertNil(ffmpeg.snapshot(at: at(200)).waitingOn)
        XCTAssertEqual(ffmpeg.snapshot(at: at(200)).timeLeftText, "Paused")
        XCTAssertEqual(PipelineStep.writing.waitingLine, "Waiting for the writing model to answer. This can take 30 to 60 minutes.")
        XCTAssertEqual(PipelineStep.complete.waitingLine, "Waiting for the file to stop growing. It may still be recording or copying.")
    }

    func testPausedTimeIsNotCountedAndTheStatusLineSaysPaused() {
        var t = tracker([.transcript], [.transcript: 100], measured: [.transcript])
        t.begin(.transcript, at: at(0))
        t.pause(at: at(10))
        XCTAssertEqual(t.activeElapsed(at: at(70)), 10, accuracy: 0.001)
        t.resume(at: at(70))
        XCTAssertEqual(t.activeElapsed(at: at(80)), 20, accuracy: 0.001)
        XCTAssertEqual(t.pausedStages, [.transcript])
        var snapshot = t.snapshot(at: at(80))
        XCTAssertEqual(snapshot.overall, 0.2, accuracy: 0.001)
        snapshot.isPaused = true
        XCTAssertEqual(snapshot.statusLine(waiting: 0), "Paused Sun 13 Sep: Writing the transcript, 20%.")
    }

    // MARK: Check 1: twice a second

    func testTheWindowSeesAtMostTwoUpdatesASecond() async {
        var now = t0
        var t = tracker([.episode], [.episode: 100])
        t.begin(.episode, at: t0)
        let meter = ProgressMeter()
        meter.begin(.episode, passes: 1)
        meter.startPass()
        let job = JobProgress(tracker: t, meter: meter, clock: { now })
        var published: [Date] = []
        job.onPublish = { published.append($0.at) }
        // 200 progress reports in 2 s, each followed by a refresh, as ffmpeg and the ticker could cause.
        for i in 1...200 {
            now = t0.addingTimeInterval(Double(i) * 0.01)
            meter.passProgress(Double(i) / 200)
            job.refresh()
        }
        XCTAssertEqual(published.count, 4, "\(published.map { $0.timeIntervalSince(t0) })")
        for (a, c) in zip(published, published.dropFirst(2)) {
            XCTAssertGreaterThanOrEqual(c.timeIntervalSince(a), 0.999, "three updates inside one second")
        }
        XCTAssertGreaterThan(job.snapshot.overall, 0.7, "the last update carries the last report")

        // The last update, 100%, keeps to the rule too: it waits out the half second, then nothing follows it.
        now = published.last ?? now
        now = now.addingTimeInterval(0.1)
        var slept = 0.0
        await job.finish(sleep: { seconds in slept = seconds; now = now.addingTimeInterval(seconds) })
        XCTAssertEqual(slept, 0.401, accuracy: 0.0001)
        XCTAssertEqual(job.snapshot.percent, 100)
        XCTAssertGreaterThanOrEqual(published[published.count - 1].timeIntervalSince(published[published.count - 2]), 0.5)
        let count = published.count
        now = now.addingTimeInterval(5)
        job.refresh()
        XCTAssertEqual(published.count, count, "nothing is published after the last")
    }

    // MARK: Where the fraction comes from

    func testTheMeterSharesAStageBetweenItsPasses() {
        var s = ProgressMeter.State(step: .episode, passes: 2, pass: -1, passFraction: 0)
        XCTAssertNil(ProgressMeter.stageFraction(s), "before the first pass")
        s.pass = 0; s.passFraction = 0.5
        XCTAssertEqual(ProgressMeter.stageFraction(s) ?? 0, 0.25, accuracy: 1e-9)
        s.pass = 1; s.passFraction = 0.5
        XCTAssertEqual(ProgressMeter.stageFraction(s) ?? 0, 0.75, accuracy: 1e-9)
        s.pass = 2; s.passFraction = 0.1
        XCTAssertEqual(ProgressMeter.stageFraction(s), 0.99, "a pass beyond the known ones holds at 99%")
        // Unknown passes: each takes half of what is left.
        var u = ProgressMeter.State(step: .podcastAudio, passes: nil, pass: 0, passFraction: 0.5)
        XCTAssertEqual(ProgressMeter.stageFraction(u) ?? 0, 0.25, accuracy: 1e-9)
        u.pass = 1; u.passFraction = 0
        XCTAssertEqual(ProgressMeter.stageFraction(u) ?? 0, 0.5, accuracy: 1e-9)
        u.pass = 2; u.passFraction = 1
        XCTAssertEqual(ProgressMeter.stageFraction(u) ?? 0, 0.875, accuracy: 1e-9)
        XCTAssertEqual(ProgressMeter.outTime("out_time_us=90014667") ?? 0, 90.014667, accuracy: 1e-9)
        XCTAssertNil(ProgressMeter.outTime("out_time_us=N/A"))
        XCTAssertNil(ProgressMeter.outTime("progress=end"))
    }

    /// ffmpeg run by the pipeline with a meter reports how far it is, and what it measures is unchanged by the
    /// added `-progress pipe:1`.
    func testFfmpegReportsItsProgressAndMeasuresTheSame() async throws {
        let file = try make("tone120.m4a", ["-f", "lavfi", "-i", "sine=frequency=330:duration=120", "-af", "volume=-9dB", "-c:a", "aac"])
        let meter = ProgressMeter()
        meter.begin(.sound, passes: 1)
        let metered = Pipeline(log: nil, meter: meter)
        let args = ["-hide_banner", "-nostats", "-i", file.path, "-vn", "-af", "volumedetect", "-f", "null", "-"]
        let withProgress = try await metered.tool(.sound, ToolPaths.standard.ffmpeg, args, duration: 120)
        let plain = try await Pipeline(log: nil).tool(.sound, ToolPaths.standard.ffmpeg, args, duration: 120)
        XCTAssertEqual(meter.current.pass, 0)
        XCTAssertGreaterThan(meter.current.passFraction, 0.99, "ffmpeg reported reaching the end")
        XCTAssertEqual(Measure.volume(stderr: withProgress.stderr), Measure.volume(stderr: plain.stderr))
        XCTAssertNotEqual(Measure.volume(stderr: plain.stderr).max, -.infinity)
    }

    // MARK: Pause, at the level of the tool

    func testAToolDoesNotStartWhilePausedAndAPausedToolsTimeLimitMovesOn() async throws {
        let control = ProcessControl()
        control.pause()
        let started = ContinuousClock.now
        let waiting = Task { try await Subprocess.run(URL(fileURLWithPath: "/usr/bin/true"), [], control: control) }
        try await Task.sleep(for: .milliseconds(600))
        control.resume()
        _ = try await waiting.value
        XCTAssertGreaterThanOrEqual(ContinuousClock.now - started, .milliseconds(550), "it waited for the resume")

        // A 3 s tool with a 2 s limit, paused for 2 s after half a second: the limit moves on by the pause, so it
        // is not stopped. Without the pause the same limit stops it.
        let paused = ProcessControl()
        let run = Task { try await Subprocess.run(URL(fileURLWithPath: "/bin/sleep"), ["3"], timeout: .seconds(2), control: paused) }
        try await Task.sleep(for: .milliseconds(500))
        paused.pause()
        try await Task.sleep(for: .seconds(2))
        paused.resume()
        let output = try await run.value
        XCTAssertEqual(output.status, 0)
        do {
            _ = try await Subprocess.run(URL(fileURLWithPath: "/bin/sleep"), ["3"], timeout: .seconds(2))
            XCTFail("the time limit should have stopped it")
        } catch let error as ToolError {
            XCTAssertEqual(error.kind, .timedOut)
        }
    }

    // MARK: The stage times this Mac learns

    func testStageTimesSeedFromTheStoreAndKeepTheLastTen() throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        let recording = Recording(filePath: "/tmp/talk.mp4", duration: 600)
        model.context.insert(recording)
        let run = Run(startedAt: Fixtures.now, trigger: .byHand, steps: [
            RunStep(name: PipelineStep.complete.title, state: .done, seconds: 60),
            RunStep(name: PipelineStep.sound.title, state: .done, seconds: 0.5),
            RunStep(name: PipelineStep.transcript.title, state: .done, seconds: 10),
            RunStep(name: PipelineStep.episode.title, state: .failed, seconds: 3),
        ])
        model.context.insert(run)
        run.recording = recording
        try model.context.save()

        XCTAssertEqual(StageTimings.seedIfEmpty(model.context), 2, "the sound check and the transcript; never the wait, never a failed step")
        XCTAssertEqual(StageTimings.seedIfEmpty(model.context), 0, "seeded once")
        var timings = StageTimings.load(model.context)
        XCTAssertEqual(timings.secondsPerMediaMinute(.transcript) ?? 0, 1.0, accuracy: 1e-9, "10 s for 10 minutes")
        XCTAssertFalse(timings.isMeasured(.complete))
        XCTAssertFalse(timings.isMeasured(.episode))
        XCTAssertEqual(timings.expectedSeconds(.complete, mediaSeconds: 600, stableWait: 60), 61)
        XCTAssertEqual(timings.expectedSeconds(.transcript, mediaSeconds: 1200, stableWait: 60), 20, accuracy: 1e-9)
        XCTAssertEqual(timings.expectedSeconds(.episode, mediaSeconds: 600, stableWait: 60), 14, accuracy: 1e-9, "the first guess: 1.4 s a minute")

        // Twelve more runs of the transcript: only the last ten are kept. A paused stage is not learned.
        for i in 1...12 {
            StageTimings.record([RunStep(name: PipelineStep.transcript.title, state: .done, seconds: Double(i) * 10),
                                 RunStep(name: PipelineStep.episode.title, state: .done, seconds: 99)],
                                mediaSeconds: 600, at: Fixtures.now.addingTimeInterval(Double(i)), excluding: [.episode], in: model.context)
        }
        timings = StageTimings.load(model.context)
        XCTAssertEqual(timings.samples[.transcript]?.count, 10)
        XCTAssertEqual(timings.samples[.transcript]?.map(\.seconds), (3...12).map { Double($0) * 10 })
        XCTAssertFalse(timings.isMeasured(.episode))
        // Writing is the average of its runs, whatever the length (it barely grows with it).
        timings.samples[.writing] = [StageSample(seconds: 1600, mediaSeconds: 948, at: Fixtures.now), StageSample(seconds: 1400, mediaSeconds: 3339, at: Fixtures.now)]
        XCTAssertEqual(timings.expectedSeconds(.writing, mediaSeconds: 200, stableWait: 60), 1500)
    }

    // MARK: Stop, Pause and the line, in the runner

    private func runnerModel() throws -> AppModel {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        return model
    }

    private func waitUntil(_ seconds: Double, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            if Date() > deadline { XCTFail("timed out"); return }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    func testStopEndsTheMakeAndNothingStartsItAgain() async throws {
        let model = try runnerModel()
        model.runner.stableWait = .seconds(3)
        let file = try make("2026-09-13 tone.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=90", "-af", "volume=-12dB", "-c:a", "aac"])
        let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.intent = .make
        model.runner.enqueue(recording, trigger: .fileEvent)
        try await waitUntil(10) { model.runner.progress(for: recording) != nil }
        XCTAssertTrue(model.runner.canStop(recording))
        model.runner.stop(recording)
        try await waitUntil(20) { model.runner.currentJob == nil && !model.runner.isCurrent(recording) }
        XCTAssertEqual(recording.status, .found)
        XCTAssertEqual(recording.intent, .none, "nothing starts it again on its own")
        XCTAssertEqual(recording.latestRun?.outcome, .stopped)
        XCTAssertTrue(recording.statusReason?.hasPrefix("Stopped by you") == true, recording.statusReason ?? "")
        XCTAssertNil(recording.outputFolder)
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.contains("at your request") }, "\(lines)")
    }

    func testPauseHoldsTheMakeAndResumeFinishesIt() async throws {
        let model = try runnerModel()
        model.runner.stableWait = .seconds(2)
        model.defaultSettings().first { $0.kind == .transcript }?.isOn = false
        let file = try make("2026-09-13 tone70.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=70", "-af", "volume=-12dB", "-c:a", "aac"])
        let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        var trace: [ProgressSnapshot] = []
        model.runner.onProgress = { trace.append($0) }
        model.runner.enqueue(recording, trigger: .byHand)
        try await waitUntil(10) { model.runner.progress(for: recording) != nil }
        model.runner.pause(recording)
        XCTAssertTrue(model.runner.canResume(recording))
        // Held: the readiness wait ends, and the next tool waits for the resume.
        try await Task.sleep(for: .seconds(4))
        let held = try XCTUnwrap(model.runner.progress(for: recording))
        XCTAssertTrue(held.isPaused)
        XCTAssertEqual(held.timeLeftText, "Paused")
        XCTAssertEqual(recording.status, .working)
        let before = held.overall
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(model.runner.progress(for: recording)?.overall ?? -1, before, "nothing moves while paused")
        model.runner.resume(recording)
        try await waitUntil(60) { recording.status != .working }
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        XCTAssertEqual(trace.last?.percent, 100)
        for (a, b) in zip(trace, trace.dropFirst()) { XCTAssertGreaterThanOrEqual(b.overall, a.overall) }
        let learned = StageTimings.load(model.context)
        XCTAssertFalse(learned.isMeasured(.sound), "a stage that was paused is not learned")
        XCTAssertTrue(learned.isMeasured(.episode), "the stages after the resume are")
    }

    func testTheLineCanBeHeldReorderedAndShortened() throws {
        let model = try runnerModel()
        model.settings.isPaused = true // nothing starts while the line is arranged
        let recordings = (1...3).map { Recording(filePath: "/tmp/2026-09-1\($0) line.mp4", foundAt: Date()) }
        for recording in recordings {
            model.context.insert(recording)
            recording.intent = .make
            model.runner.enqueue(recording, trigger: .fileEvent)
        }
        XCTAssertEqual(model.runner.waitingIDs, recordings.map(\.id))
        model.runner.makeNext(recordings[2])
        XCTAssertEqual(model.runner.waitingIDs, [recordings[2].id, recordings[0].id, recordings[1].id])
        model.runner.pause(recordings[0])
        XCTAssertTrue(model.runner.isHeld(recordings[0]))
        XCTAssertTrue(model.runner.canResume(recordings[0]))
        model.runner.resume(recordings[0])
        XCTAssertFalse(model.runner.isHeld(recordings[0]))
        model.runner.stop(recordings[1])
        XCTAssertEqual(model.runner.waitingIDs, [recordings[2].id, recordings[0].id])
        XCTAssertEqual(recordings[1].intent, .none, "taken out of the line, it is not started again at the next look")
        model.runner.stopAll()
    }

    // MARK: --debug-status-log

    func testTheStatusLogWritesEachChangeOnce() throws {
        let logs = work.appending(path: "logs", directoryHint: .isDirectory)
        let model = Fixtures.model(mode: .development, log: AppLog(directory: logs))
        model.debugStatusLog = true
        model.noteStatusLine()
        model.noteStatusLine()
        Fixtures.showProgress(model)
        model.noteStatusLine()
        let text = try String(contentsOf: try XCTUnwrap(model.log.todayFile), encoding: .utf8)
        let lines = text.split(separator: "\n").filter { $0.contains("Status line: ") }
        XCTAssertEqual(lines.count, 2, "\(lines)")
        XCTAssertTrue(lines.last?.contains("Status line: Making Sun 6 Sep: Making the episode audio, ") == true, "\(lines)")
        XCTAssertTrue(lines.last?.hasSuffix("1 waiting.") == true, "\(lines)")
    }

    // MARK: Helpers

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

/// v2 part M4a fix: a running step's name in the Activity window's Steps is never in the past tense.
final class StepNameTenseTests: XCTestCase {
    func testARunningStepIsNotNamedAsDone() {
        XCTAssertEqual(PipelineStep.complete.listTitle(running: true), "Checking the file is complete")
        XCTAssertEqual(PipelineStep.complete.listTitle(running: false), "Checked the file is complete")
        for step in PipelineStep.allCases {
            XCTAssertFalse(step.listTitle(running: true).hasPrefix("Checked"), step.rawValue)
            XCTAssertEqual(step.listTitle(running: false), step.title)
        }
    }
}
