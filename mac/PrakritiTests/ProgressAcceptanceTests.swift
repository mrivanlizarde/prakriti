import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M4a's acceptance (docs/v2/PLAN.md M4, check 2): the REAL 13 Sep talk made twice in development through
/// the app's own runner, with the podcast-ready episode on so the make has every metered and timed kind of stage.
/// Every progress snapshot the window would see is written to `progress-trace.txt` (time, stage, percent, time
/// left). Passes when the percent rises from 0 to 100 and never goes back in each run; on the second run, which
/// has the first run's stage times, the time left shown at the 50% mark is within 25% of the time that really
/// remained; and the menu bar's status line, written to the development log by the same path as
/// `--debug-status-log` (the menu bar itself cannot be captured, PLAN rule 2.1.10), matches the trace at three
/// moments.
///
///   cd ~/Code/prakriti/mac && make accept-progress MILESTONE=v2-m4a
///
/// Reads only the 13 Sep talk (Gabriel's, read only, its size and date checked after). Writes to
/// ~/Prakriti/Dev/Outputs; the store is in memory; the lines go to the development log. About 3 minutes.
@MainActor
final class ProgressAcceptanceTests: XCTestCase {
    func testProgressOnTheThirteenSepTalkTwice() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "progress" else {
            throw XCTSkip("Makes the real 13 Sep talk twice. Run it with: cd ~/Code/prakriti/mac && make accept-progress MILESTONE=v2-m4a")
        }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        // The podcast-ready episode on, so the make has the mastering passes whose number is not known ahead.
        try XCTUnwrap(model.defaultSettings().first { $0.kind == .podcastReady }).isOn = true
        model.debugStatusLog = true
        let token = UUID().uuidString.prefix(8)
        model.log.write("Progress acceptance \(token) started (in-memory store, outputs to \(paths.outputs.path)).")

        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertFalse(talk.path.contains("2026-09-14"))
        let before = fingerprint(talk)
        let folder = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: folder)

        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date(), kind: .talk)
        model.context.insert(recording)
        recording.source = model.source(containing: talk)
        try model.context.save()

        var runs: [[ProgressSnapshot]] = [[], []]
        var ends: [Date] = []
        var index = 0
        model.runner.onProgress = { runs[index].append($0) }
        for (i, trigger) in [RunTrigger.byHand, .makeAgain].enumerated() {
            index = i
            await model.runner.process(recording, trigger: trigger)
            ends.append(Date())
            XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        }
        model.log.write("Progress acceptance \(token) ended.")

        // The trace, as the window saw it.
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm:ss.SSS"
        var trace = ["# progress-trace.txt, v2 part M4a, \(Date().formatted(date: .abbreviated, time: .standard))",
                     "# run  time          step   stage                                              percent  time left (shown; seconds behind it)"]
        for (n, run) in runs.enumerated() {
            for s in run {
                trace.append(String(format: "%d    %@  %2d/%-2d  %-50@ %3d%%     %@ (%@)", n + 1, clock.string(from: s.at), s.stepNumber, s.stepCount,
                                    s.stageName as NSString, s.percent, s.timeLeftText as NSString,
                                    (s.timeLeft.map { String(format: "%.1f s", $0) } ?? "none") as NSString))
            }
        }
        try (trace.joined(separator: "\n") + "\n").write(to: out.appending(path: "progress-trace.txt"), atomically: true, encoding: .utf8)

        var report = ["v2 part M4a, make accept-progress, \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        // 1. Each run rises from 0 to 100 and never goes back.
        for (n, run) in runs.enumerated() {
            let percents = run.map(\.percent)
            let backwards = zip(run, run.dropFirst()).filter { $1.overall < $0.overall }.count
            XCTAssertEqual(percents.first, 0, "run \(n + 1) starts at 0%")
            XCTAssertEqual(percents.last, 100, "run \(n + 1) ends at 100%")
            XCTAssertEqual(backwards, 0, "run \(n + 1) went backwards")
            let seconds = (run.last?.at ?? Date()).timeIntervalSince(run.first?.at ?? Date())
            report.append("Run \(n + 1): \(run.count) snapshots over \(String(format: "%.1f", seconds)) s, percent \(percents.first ?? -1) to \(percents.last ?? -1), backwards \(backwards) times; at most \(maxPerSecond(run)) in any second.")
            XCTAssertLessThanOrEqual(maxPerSecond(run), 2, "run \(n + 1): more than two updates in one second")
        }

        // 2. Run 2: the time left at the 50% mark against what really remained.
        let second = runs[1]
        let half = try XCTUnwrap(second.first { $0.overall >= 0.5 }, "run 2 never reached 50%")
        let estimate = try XCTUnwrap(half.timeLeft, "no time left was shown at the 50% mark")
        let real = ends[1].timeIntervalSince(half.at)
        let off = abs(estimate - real) / real
        report.append(String(format: "Run 2 at the 50%% mark (%@, %d%%, %@): time left shown \"%@\" from %.1f s; really remained %.1f s; off by %.1f%% (limit 25%%).",
                             clock.string(from: half.at), half.percent, half.stageName, half.timeLeftText, estimate, real, off * 100))
        XCTAssertLessThanOrEqual(off, 0.25)

        // 3. The menu bar's status line, from the development log, at three moments of run 2.
        let logText = try String(contentsOf: try XCTUnwrap(model.log.todayFile), encoding: .utf8)
        let lines = logText.components(separatedBy: "\n")
        let start = try XCTUnwrap(lines.lastIndex { $0.contains("Progress acceptance \(token) started") })
        let end = try XCTUnwrap(lines.lastIndex { $0.contains("Progress acceptance \(token) ended") })
        let statusLines = lines[start...end].filter { $0.contains("  Status line: ") }
        report.append("Status lines written to the development log during the runs: \(statusLines.count).")
        // A log line's time is to the second: it must be the same second as the trace's moment, or the next.
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for target in [0.25, 0.5, 0.75] {
            let moment = try XCTUnwrap(second.first { $0.overall >= target })
            let expected = moment.statusLine(waiting: 0)
            let found = statusLines.first { line in
                guard line.hasSuffix("Status line: " + expected), let at = stamp.date(from: String(line.prefix(19))) else { return false }
                let gap = at.timeIntervalSince(moment.at)
                return gap > -1 && gap < 2
            }
            XCTAssertNotNil(found, "the status line for \(moment.percent)% is not in the log: \(expected)")
            report.append("  trace \(clock.string(from: moment.at)) \(moment.percent)% \(moment.stageName): log \(found.map { String($0.prefix(19)) } ?? "MISSING")  \"\(expected)\"")
        }

        XCTAssertEqual(fingerprint(talk), before, "the original changed")
        report.append("Original unchanged (size and modification date): \(fingerprint(talk) == before ? "yes" : "NO")")
        report.append("Learned stage times (seconds per minute of recording): "
                      + StageTimings.load(model.context).samples.keys.sorted { $0.rawValue < $1.rawValue }
                        .compactMap { step in StageTimings.load(model.context).secondsPerMediaMinute(step).map { "\(step.rawValue) \(String(format: "%.3f", $0))" } }
                        .joined(separator: ", "))
        try (report.joined(separator: "\n") + "\n").write(to: out.appending(path: "acceptance-progress.txt"), atomically: true, encoding: .utf8)
        print(report.joined(separator: "\n"))
    }

    /// The most snapshots published inside any one second.
    private func maxPerSecond(_ run: [ProgressSnapshot]) -> Int {
        var best = 0
        for (i, s) in run.enumerated() {
            best = max(best, run[i...].prefix { $0.at.timeIntervalSince(s.at) < 1 }.count)
        }
        return best
    }

    private func fingerprint(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        return "\(size)@\(modified)"
    }
}
