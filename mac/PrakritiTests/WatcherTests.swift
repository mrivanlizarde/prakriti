import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The watcher end to end, on files ffmpeg generates in a temporary home folder: a file arrives,
/// is found, made and notified with no clicks; "Ask me first" checks and waits; tests stay silent;
/// a silent file is a decision; failures get three tries then one notice; the first look at a
/// folder leaves what is there alone; the heartbeat says "nothing new"; FSEvents really arrive and
/// replay; and the switch-over takes in engine v0's memory so nothing it saw is made again.
/// Nothing here reads a real recording or writes into ~/Prakriti.
@MainActor
final class WatcherTests: XCTestCase {
    private var home: URL!
    private var model: AppModel!
    private var poster: CapturingPoster!

    override func setUp() async throws {
        home = FileManager.default.temporaryDirectory.appending(path: "prakriti-watch-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        model?.watcher.stop()
        model?.runner.stopAll()
        try? FileManager.default.removeItem(at: home)
    }

    private func makeModel(_ mode: AppMode = .development) throws -> AppModel {
        let paths = AppPaths(mode: mode, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Date() })
        for folder in paths.foldersToCreate { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .milliseconds(200)
        model.watcher.scanTimeout = .seconds(10)
        poster = CapturingPoster()
        model.notifier.poster = poster
        self.model = model
        return model
    }

    private var drop: Source { try! model.context.fetch(FetchDescriptor<Source>()).first { $0.kind == .dropFolder }! }

    private func recording(named name: String) -> Recording? {
        try? model.context.fetch(FetchDescriptor<Recording>()).first { $0.fileName == name }
    }

    /// Waits for the runner to settle on this recording (nothing running, nothing waiting).
    private func waitUntilSettled(_ name: String, timeout: TimeInterval = 180) async throws -> Recording {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let r = recording(named: name), !model.runner.isCurrent(r), !model.runner.isWaiting(r), r.status != .working {
                return r
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("timed out waiting for \(name)")
        throw CancellationError()
    }

    // MARK: A file arrives, with no clicks

    func testARecordingDroppedInIsFoundMadeAndNotifiedWithNoClicks() async throws {
        let model = try makeModel()
        try make(in: model.paths.drop, "2026-09-13 drop test.m4a", ["-f", "lavfi", "-i", "sine=frequency=330:duration=70", "-af", "volume=-18dB", "-c:a", "aac"])
        await model.watcher.sweep(.fileEvent)
        let r = try await waitUntilSettled("2026-09-13 drop test.m4a")
        XCTAssertEqual(r.status, .readyForYourYes, r.statusReason ?? "")
        XCTAssertEqual(r.intent, .none)
        XCTAssertEqual(r.latestRun?.trigger, .fileEvent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: model.paths.outputs.appending(path: "2026-09-13 drop test/episode.mp3").path))
        // Found, Started, Ready: one notice, updated in place. The notifier hands each to macOS in a Task of its own,
        // so the last can land a moment after the status settles (seen in the full suite after v2 part M6a's step).
        let posted = Date().addingTimeInterval(3)
        while poster.posted.count < 3 && Date() < posted { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(poster.posted.map(\.event), [.found, .started, .ready])
        XCTAssertEqual(Set(poster.posted.map(\.identifier)), ["rec-2026-09-13-drop-test-status"])
        XCTAssertEqual(poster.posted.last?.title, "Waiting for Your Yes: Sun 13 Sep")
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Found 2026-09-13 drop test.m4a in Test drop folder.") }, "\(lines)")
        XCTAssertTrue(lines.contains { $0.contains("is waiting for your yes") }, "\(lines)")
    }

    func testAskMeFirstChecksTheSoundThenWaits() async throws {
        let model = try makeModel()
        drop.mode = .askFirst
        try make(in: model.paths.drop, "2026-09-13 ask first.m4a", ["-f", "lavfi", "-i", "sine=frequency=330:duration=65", "-af", "volume=-18dB", "-c:a", "aac"])
        await model.watcher.sweep(.timer)
        XCTAssertEqual(recording(named: "2026-09-13 ask first.m4a")?.intent, .check)
        let r = try await waitUntilSettled("2026-09-13 ask first.m4a")
        XCTAssertEqual(r.status, .found)
        XCTAssertEqual(r.intent, .none, "checked once; it now waits for Make Outputs")
        XCTAssertEqual(r.latestRun?.outcome, .checked)
        XCTAssertNotNil(r.loudestDB)
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.paths.outputs.appending(path: "2026-09-13 ask first").path), "nothing is made")
        XCTAssertEqual(poster.posted.map(\.event), [.found])
        XCTAssertTrue(poster.posted.first?.body.contains("Make Outputs") == true)

        // A later look does not start it again.
        await model.watcher.sweep(.timer)
        XCTAssertFalse(model.runner.isWaiting(r))
    }

    func testTestClipsAreFiledSilently() async throws {
        let model = try makeModel()
        try make(in: model.paths.drop, "2026-09-13 eight seconds.m4a", ["-f", "lavfi", "-i", "sine=frequency=440:duration=8", "-c:a", "aac"])
        await model.watcher.sweep(.fileEvent)
        let r = try await waitUntilSettled("2026-09-13 eight seconds.m4a")
        XCTAssertEqual(r.status, .skipped)
        XCTAssertEqual(r.kind, .test)
        XCTAssertTrue(poster.posted.isEmpty, "tests are silent: \(poster.posted.map(\.title))")
    }

    func testASilentRecordingIsADecisionTheSameDay() async throws {
        let model = try makeModel()
        try make(in: model.paths.drop, "2026-09-14 silent.m4a", ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-t", "65", "-c:a", "aac"])
        await model.watcher.sweep(.fileEvent)
        let r = try await waitUntilSettled("2026-09-14 silent.m4a")
        XCTAssertEqual(r.status, .needsADecision)
        XCTAssertNil(r.outputFolder)
        XCTAssertEqual(poster.posted.map(\.event), [.found, .needsADecision])
        XCTAssertEqual(poster.posted.last?.identifier, "rec-2026-09-14-silent-decision")
        XCTAssertEqual(poster.posted.last?.title, "Needs a Decision: Mon 14 Sep")
    }

    func testFailuresGetThreeTriesThenOneNotice() async throws {
        let model = try makeModel()
        let broken = model.paths.drop.appending(path: "2026-09-13 broken.mp4")
        try Data((0..<100_000).map { _ in UInt8.random(in: 0...255) }).write(to: broken)
        for attempt in 1...3 {
            await model.watcher.sweep(.timer)
            let r = try await waitUntilSettled("2026-09-13 broken.mp4")
            XCTAssertEqual(r.failedTries, attempt)
            if attempt < 3 {
                XCTAssertEqual(r.status, .found, "try \(attempt) waits for the next check")
                XCTAssertEqual(r.intent, .make)
                XCTAssertTrue(r.statusReason?.hasPrefix("Try \(attempt) of 3 stopped.") == true, r.statusReason ?? "")
                XCTAssertTrue(poster.posted.isEmpty, "a failure a retry may fix says nothing")
            } else {
                XCTAssertEqual(r.status, .couldntFinish)
                XCTAssertEqual(r.intent, .none)
            }
        }
        XCTAssertEqual(poster.posted.map(\.event), [.couldntFinish])
        XCTAssertEqual(poster.posted.first?.body,
                       "It stopped three times while checking the file is complete. The original is untouched; open it to see the details.")
        let r = try XCTUnwrap(recording(named: "2026-09-13 broken.mp4"))
        XCTAssertEqual(r.runs.count, 3)
        XCTAssertEqual(r.runs.filter { $0.trigger == .retry }.count, 2)
        // Couldn't finish is final until Ivan chooses Try Again: the next look leaves it alone.
        await model.watcher.sweep(.timer)
        XCTAssertFalse(model.runner.isWaiting(r))
    }

    func testAnInterruptedAutomaticRunStartsAgainByItself() throws {
        let model = try makeModel()
        let r = Recording(filePath: "/tmp/2026-09-13 a.mp4", status: .working)
        r.intent = .make
        model.context.insert(r)
        model.recoverInterruptedWork()
        XCTAssertEqual(r.status, .found)
        XCTAssertEqual(r.failedTries, 1, "the stop counts as a try, so a crash cannot loop forever")
        r.status = .working
        r.failedTries = 2
        model.recoverInterruptedWork()
        XCTAssertEqual(r.status, .couldntFinish)
        XCTAssertEqual(r.intent, .none)
        XCTAssertEqual(model.notifier.sent.map(\.event), [.couldntFinish])
    }

    // MARK: Looking

    func testTheFirstLookAtAFolderLeavesWhatIsThereAlone() async throws {
        let model = try makeModel()
        let folder = home.appending(path: "Movies/Old recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(count: 10).write(to: folder.appending(path: "2026-08-01 old talk.mp4"))
        let source = try XCTUnwrap(model.addSource(at: folder))
        XCTAssertNil(source.baselinedAt)
        await model.watcher.sweep(.checkNow)
        let old = try XCTUnwrap(recording(named: "2026-08-01 old talk.mp4"))
        XCTAssertEqual(old.status, .found)
        XCTAssertEqual(old.intent, .none, "already there: listed, never started")
        XCTAssertTrue(old.runs.isEmpty)
        XCTAssertNotNil(source.baselinedAt)
        XCTAssertTrue(model.runner.waitingIDs.isEmpty && model.runner.currentID == nil)

        // Something new afterwards is taken in. The folder is Ask me first, so it is only checked.
        try Data(count: 10).write(to: folder.appending(path: "2026-10-10 new talk.mp4"))
        await model.watcher.sweep(.checkNow)
        XCTAssertEqual(recording(named: "2026-10-10 new talk.mp4")?.intent, .check)
    }

    func testTheHeartbeatSaysNothingNew() async throws {
        let model = try makeModel()
        await model.watcher.sweep(.timer)
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertEqual(lines.filter { $0 == "Checked 1 folder. Nothing new." }.count, 1, "\(lines)")
        let runs = try model.context.fetch(FetchDescriptor<Run>())
        XCTAssertEqual(runs.filter { $0.outcome == .nothingNew && $0.trigger == .timer }.count, 1)
        XCTAssertEqual(model.watcher.states[drop.id]?.health, .ok)

        // A file event that finds nothing new leaves no line (OBS sends one every few seconds).
        await model.watcher.sweep(.fileEvent)
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<LogEntry>()), lines.count)
    }

    func testPauseStopsLookingAndResumeCatchesUp() async throws {
        let model = try makeModel()
        model.setPaused(true)
        try Data(count: 10).write(to: model.paths.drop.appending(path: "2026-09-13 while paused.mp4"))
        await model.watcher.sweep(.timer)
        XCTAssertNil(recording(named: "2026-09-13 while paused.mp4"), "paused: nothing new is looked for")
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains("Paused, so no folder was checked. Resume All to look again."), "\(lines)")
        model.setPaused(false)
        await model.watcher.sweep(.resume)
        XCTAssertNotNil(recording(named: "2026-09-13 while paused.mp4"))
    }

    func testAMissingFolderIsReportedNotFatal() async throws {
        let model = try makeModel()
        try FileManager.default.removeItem(at: model.paths.drop)
        await model.watcher.sweep(.timer)
        XCTAssertEqual(model.watcher.states[drop.id]?.health, .missing)
        let summary = model.statusSummary(recordings: [], sources: [drop])
        XCTAssertEqual(summary.icon, .notWatching, "the watcher is not started in this test")
        model.isWatching = true
        XCTAssertEqual(model.statusSummary(recordings: [], sources: [drop]).icon, .problem)
        XCTAssertTrue(model.statusSummary(recordings: [], sources: [drop]).line.contains("Test drop folder cannot be read yet"))
    }

    func testTheScanTakesWhatEngineV0Took() throws {
        let root = home.appending(path: "Studio", directoryHint: .isDirectory)
        let files = [
            "2026-09-06/2026-09-06 18-06-33.mp4",            // taken
            "2026-09-06/2026-09-06 18-06-33-vertical.mp4",   // the vertical rendition: never
            "2026-09-06/2026-09-06 18-06-33.txt",            // not media
            "2026-09-13/.2026-09-13 hidden.mp4",             // hidden
            "a/b/c/2026-09-20 three deep.mov",               // three folders down: taken
            "a/b/c/d/2026-09-21 four deep.mov",              // four folders down: v0 never looked
            "2026-10-02/2026-10-02 15-10-06.MP4",            // any case
        ]
        for file in files {
            let url = root.appending(path: file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(count: 1).write(to: url)
        }
        try FileManager.default.createSymbolicLink(at: root.appending(path: "2026-09-06/link.mp4"),
                                                   withDestinationURL: root.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4"))
        guard case .files(let found) = FolderScan.scan(root.path) else { return XCTFail("the folder should list") }
        XCTAssertEqual(Set(found.map { ($0.path as NSString).lastPathComponent }),
                       ["2026-09-06 18-06-33.mp4", "2026-10-02 15-10-06.MP4", "2026-09-20 three deep.mov"])
        XCTAssertEqual(found.count, 3, "\(found.map(\.path))")
        XCTAssertEqual(FolderScan.scan(home.appending(path: "nowhere").path), .missing)
    }

    // MARK: FSEvents

    func testFileEventsArriveAndReplayAfterAQuit() async throws {
        let folder = home.appending(path: "events", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let collected = BatchBox()
        let stream = EventStream(paths: [folder.path], since: nil, latency: 0.2) { collected.add($0) }
        XCTAssertTrue(stream.start())
        try await Task.sleep(for: .milliseconds(500))
        try Data(count: 10).write(to: folder.appending(path: "2026-09-13 first.mp4"))
        try await waitFor { collected.paths.contains { $0.hasSuffix("2026-09-13 first.mp4") } }
        let seen = collected.lastID
        XCTAssertGreaterThan(seen, 0)
        stream.stop()

        // Closed: a file arrives. The next stream, started from the saved id, replays it.
        try Data(count: 10).write(to: folder.appending(path: "2026-09-13 while closed.mp4"))
        try await Task.sleep(for: .milliseconds(300))
        let replay = BatchBox()
        let second = EventStream(paths: [folder.path], since: seen, latency: 0.2) { replay.add($0) }
        XCTAssertTrue(second.start())
        try await waitFor { replay.historyDone }
        XCTAssertTrue(replay.paths.contains { $0.hasSuffix("2026-09-13 while closed.mp4") }, "\(replay.paths)")
        XCTAssertGreaterThan(replay.replayed, 0)
        second.stop()
        XCTAssertNotNil(EventStream.deviceUUID(for: home.path))
    }

    // MARK: The switch-over

    /// engine v0's state.json as it stood on Sat 10 Oct (paths only; HOME stands for the home folder).
    static let engineV0State = """
    {
      "files": {
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-14/2026-09-14 20-00-09.mp4": {"size": 2858813029, "mtime": 1789444912000, "status": "silent", "at": "2026-10-08 23:08:31", "duration": 3702.265233},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-13/2026-09-13 18-25-44.mp4": {"size": 730464600, "mtime": 1789350092000, "status": "ready", "at": "2026-10-08 16:15:54", "duration": 947.780167, "output": "HOME/Prakriti/Outputs/2026-09-13 18-25-44", "seconds": 36},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-06/2026-09-06 17-43-25.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-16/2026-09-16 20-03-49.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-17/2026-09-17 06-02-43.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-20/2026-09-20 18-07-58.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-23/2026-09-23 19-59-52.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-26/2026-09-26 10-29-54.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-10-02/2026-10-02 15-10-06.mp4": {"status": "existing", "at": "2026-10-08 16:17:39"},
        "HOME/Prakriti/Drop/2026-10-08 watcher test.mp4": {"size": 69959577, "mtime": 1791501469771.3845, "status": "ready", "at": "2026-10-08 16:17:54", "duration": 90.1099, "output": "HOME/Prakriti/Outputs/2026-10-08 watcher test", "seconds": 10},
        "HOME/Documents/Design Work/Galindo x Lizarde/Studio Recordings /2026-09-06/2026-09-06 18-06-33.mp4": {"size": 2578079009, "mtime": 1788746532000, "status": "ready", "at": "2026-10-09 12:58:14", "duration": 3339.102433, "output": "HOME/Prakriti/Outputs/2026-09-06 18-06-33", "seconds": 122}
      },
      "baselined": "2026-10-08 16:17:39"
    }
    """

    func testTheSwitchOverTakesInEngineV0sMemoryAndMakesNothingAgain() async throws {
        let model = try makeModel(.live)
        let sources = try model.context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.addedAt)]))
        XCTAssertEqual(sources.map(\.name), ["Studio Recordings", "Drop folder"])
        XCTAssertEqual(sources.map(\.mode), [.automatic, .automatic])
        XCTAssertTrue(sources.allSatisfy { $0.baselinedAt != nil })

        // The studio folder as it is on disk (empty stand-ins with the real names), v0's two
        // finished episodes, and its state.json.
        let studio = model.paths.studioRecordings
        let names = ["2026-09-06/2026-09-06 17-43-25.mp4", "2026-09-06/2026-09-06 17-43-25-vertical.mp4", "2026-09-06/2026-09-06 17-43-25.txt",
                     "2026-09-06/2026-09-06 18-06-33.mp4", "2026-09-06/2026-09-06 18-06-33-vertical.mp4", "2026-09-06/2026-09-06 18-06-33.txt",
                     "2026-09-06/2026-09-06 18-06-33-vertical.txt", "2026-09-13/2026-09-13 18-25-44.mp4", "2026-09-13/2026-09-13 18-25-44.txt",
                     "2026-09-14/2026-09-14 20-00-09.mp4", "2026-09-16/2026-09-16 20-03-49.mp4", "2026-09-16/2026-09-16 20-03-49.txt",
                     "2026-09-17/2026-09-17 06-02-43.mp4", "2026-09-20/2026-09-20 18-07-58.mp4", "2026-09-23/2026-09-23 19-59-52.mp4",
                     "2026-09-26/2026-09-26 10-29-54.mp4", "2026-10-02/2026-10-02 15-10-06.mp4", ".DS_Store"]
        for name in names {
            let url = studio.appending(path: name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
        for episode in ["2026-09-13 18-25-44", "2026-09-06 18-06-33"] {
            let folder = model.paths.outputs.appending(path: episode, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(count: 10).write(to: folder.appending(path: "episode.mp3"))
        }
        try """
        | Sound in | average -30 dB, loudest -3.4 dB; loudness -26.67 LUFS |
        | Episode audio | `episode.mp3`, mono 128 kbps, -16.8 LUFS, true peak -1.6 dBFS (target -16 LUFS, peak at or under -1) |
        | Transcript | `transcript.txt`, `.srt`, `.vtt`, 2948 words; reaches 15:47 of 15:48 |
        """.write(to: model.paths.outputs.appending(path: "2026-09-13 18-25-44/REPORT.md"), atomically: true, encoding: .utf8)
        try Self.engineV0State.replacingOccurrences(of: "HOME", with: home.path)
            .write(to: model.paths.engineV0State, atomically: true, encoding: .utf8)

        model.importEngineV0IfNeeded()
        XCTAssertNotNil(model.settings.engineV0ImportedAt)
        let all = try model.context.fetch(FetchDescriptor<Recording>())
        XCTAssertEqual(all.count, 11)
        XCTAssertTrue(all.allSatisfy { $0.fromEngineV0 && $0.intent == .none })
        func status(_ name: String) -> RecordingStatus? { all.first { $0.fileName == name }?.status }
        XCTAssertEqual(status("2026-09-13 18-25-44.mp4"), .readyForYourYes)
        XCTAssertEqual(status("2026-09-06 18-06-33.mp4"), .readyForYourYes)
        XCTAssertEqual(status("2026-09-14 20-00-09.mp4"), .needsADecision)
        XCTAssertEqual(status("2026-10-08 watcher test.mp4"), .skipped, "its files are gone")
        for name in ["2026-09-06 17-43-25.mp4", "2026-09-16 20-03-49.mp4", "2026-09-17 06-02-43.mp4", "2026-09-20 18-07-58.mp4",
                     "2026-09-23 19-59-52.mp4", "2026-09-26 10-29-54.mp4", "2026-10-02 15-10-06.mp4"] {
            XCTAssertEqual(status(name), .skipped, name)
        }
        let talk = try XCTUnwrap(all.first { $0.fileName == "2026-09-13 18-25-44.mp4" })
        XCTAssertEqual(talk.loudnessLUFS, -16.8)
        XCTAssertEqual(talk.truePeakDBFS, -1.6)
        XCTAssertEqual(talk.wordCount, 2948)
        XCTAssertEqual(talk.transcriptReaches, 947)
        XCTAssertEqual(talk.coverageOK, true)
        XCTAssertEqual(talk.source?.name, "Studio Recordings")
        XCTAssertEqual(all.first { $0.fileName == "2026-10-08 watcher test.mp4" }?.source?.name, "Drop folder")

        // The first look after the switch-over: nothing new, nothing started, no notice.
        await model.watcher.sweep(.launch)
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 11, "the vertical renditions are never taken in")
        XCTAssertTrue(model.runner.waitingIDs.isEmpty)
        XCTAssertNil(model.runner.currentID)
        XCTAssertTrue(poster.posted.isEmpty)
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains("Checked 2 folders. Nothing new."), "\(lines)")
        XCTAssertTrue(lines.contains { $0.hasPrefix("Took over from the old engine: 11 files") }, "\(lines)")

        // Read once: a second launch does not import again.
        model.importEngineV0IfNeeded()
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 11)

        // A recording that arrives now is new, and is made automatically.
        try Data(count: 10).write(to: model.paths.drop.appending(path: "2026-10-11 new.mp4"))
        await model.watcher.sweep(.fileEvent)
        XCTAssertEqual(recording(named: "2026-10-11 new.mp4")?.intent, .make)
    }

    // MARK: One watcher per mode, refusals, the login item

    func testOnlyOneCopyPerModeGetsTheLock() throws {
        let file = home.appending(path: "watcher.lock")
        let first = try XCTUnwrap(InstanceLock.acquire(at: file))
        XCTAssertNil(InstanceLock.acquire(at: file), "a second copy in the same mode is refused")
        XCTAssertNotNil(InstanceLock.acquire(at: home.appending(path: "Development/watcher.lock")), "the other mode has its own")
        first.release()
        XCTAssertNotNil(InstanceLock.acquire(at: file), "released when the first one ends")
    }

    func testLiveModeStillRefusesTheArchiveAndPrakritisOwnFolders() {
        let paths = AppPaths(mode: .live, home: URL(fileURLWithPath: "/Users/someone", isDirectory: true))
        XCTAssertNotNil(paths.refusal(for: paths.archive, isFolder: true))
        XCTAssertNotNil(paths.refusal(for: paths.archive.appending(path: "Takeout/call.mp4"), isFolder: false))
        XCTAssertNotNil(paths.refusal(for: paths.home.appending(path: "Downloads", directoryHint: .isDirectory), isFolder: true))
        XCTAssertNotNil(paths.refusal(for: paths.outputs, isFolder: true), "watching Outputs would find its own episodes")
        XCTAssertNotNil(paths.refusal(for: paths.root, isFolder: true), "~/Prakriti holds Outputs")
        XCTAssertNil(paths.refusal(for: paths.studioRecordings, isFolder: true))
        XCTAssertNil(paths.refusal(for: paths.drop, isFolder: true))
        let dev = AppPaths(mode: .development, home: URL(fileURLWithPath: "/Users/someone", isDirectory: true))
        XCTAssertNotNil(dev.refusal(for: dev.outputs, isFolder: true))
        XCTAssertNil(dev.refusal(for: dev.drop, isFolder: true))
    }

    func testOnlyTheInstalledCopyOpensAtLogin() {
        XCTAssertTrue(LoginItem.isInstalledCopy(bundlePath: "/Users/someone/Applications/Prakriti.app", home: "/Users/someone"))
        XCTAssertTrue(LoginItem.isInstalledCopy(bundlePath: "/Applications/Prakriti.app", home: "/Users/someone"))
        XCTAssertFalse(LoginItem.isInstalledCopy(bundlePath: "/Users/someone/Code/prakriti/mac/build/Build/Products/Debug/Prakriti.app", home: "/Users/someone"))
    }

    // MARK: Helpers

    private func waitFor(timeout: TimeInterval = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("timed out") }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @discardableResult
    private func make(in folder: URL, _ name: String, _ arguments: [String]) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Made beside the folder, then moved in, as a finished file arrives.
        let temp = home.appending(path: name)
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-v", "error", "-y"] + arguments + [temp.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "ffmpeg could not make \(name)")
        let url = folder.appending(path: name)
        try FileManager.default.moveItem(at: temp, to: url)
        return url
    }
}

/// Collects batches from the FSEvents queue.
final class BatchBox: @unchecked Sendable {
    private let lock = NSLock()
    private var batches: [EventBatch] = []

    func add(_ batch: EventBatch) { lock.withLock { batches.append(batch) } }
    var paths: [String] { lock.withLock { batches.flatMap(\.paths) } }
    var lastID: UInt64 { lock.withLock { batches.map(\.lastID).max() ?? 0 } }
    var historyDone: Bool { lock.withLock { batches.contains(where: \.historyDone) } }
    var replayed: Int { lock.withLock { batches.map(\.replayed).reduce(0, +) } }
}
