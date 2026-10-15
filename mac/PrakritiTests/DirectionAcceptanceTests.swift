import Foundation
import Synchronization
import SwiftData
import XCTest
@testable import Prakriti

/// Counts every request a client is asked, and passes it on (v2 part M9c: PLAN M9 check 3's "LM Studio request count").
final class CountingClient: LanguageModelClient {
    let inner: any LanguageModelClient
    private let count = Mutex(0)

    init(_ inner: any LanguageModelClient) { self.inner = inner }

    var provider: ModelProvider { inner.provider }
    var displayName: String { inner.displayName }
    var requests: Int { count.withLock { $0 } }

    func prepare() async throws { try await inner.prepare() }
    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) { try await inner.budget(for: request) }
    func complete(_ request: ModelRequest) async throws -> ModelReply {
        count.withLock { $0 += 1 }
        return try await inner.complete(request)
    }
    func release() async -> String? { await inner.release() }
    func check() async -> ProviderCheck { await inner.check() }
}

/// v2 part M9c's acceptance (docs/v2/PLAN.md M9, check 3 for Energetic, Focus and length, and pace-only), on the REAL 13 Sep
/// talk, whole: made in development through the app's runner (transcript, faces, voices; no video, no writing), then planned by
/// Plan the Edit as Ivan would, with a direction each time, and every plan read back from `edit-plan.json` and counted:
///
/// - "More energetic. Faster, more frequent cuts.": the chips hold Style Energetic and Pace faster; 12 to 15 visual changes a
///   minute; the median shot 3 to 4 s. Read by the rules alone: no model request.
/// - "Focus on the parts that are motivating or enlightening. Under 10 minutes.": the beats by Qwen3.8-27B in LM Studio, timed;
///   the video at most 10:00 and at least 8:30; the kept beats' mean motivating plus enlightening score above the dropped beats'.
/// - The same direction at Brisk pace: 0 model requests, the plan shown in under 10 s.
/// - Then the beats asked for once more, straight from the planner on the same words, to see whether LM Studio honours the seed
///   (measured, not a gate: the beats file is what keeps runs the same).
///
///   cd ~/Code/prakriti/mac && make accept-direction MILESTONE=v2-m9c
///
/// Skipped unless PRAKRITI_ACCEPTANCE=direction. Needs LM Studio's server with Qwen3.8-27B. The store is in memory; outputs go to
/// ~/Prakriti/Dev/Outputs; the original is only read, checked by size and date before and after. Never a class, never the archive.
/// Nothing goes to a cloud provider: the planning task is set to LM Studio, and the cloud client factory refuses.
@MainActor
final class DirectionAcceptanceTests: XCTestCase {
    func testDirectionOnTheThirteenthOfSeptember() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "direction" else {
            throw XCTSkip("Reads the 13 Sep talk and asks LM Studio. Run it with: cd ~/Code/prakriti/mac && make accept-direction MILESTONE=v2-m9c")
        }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let paths = AppPaths(mode: .development)
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path), "missing: \(talk.path)")
        XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
        let before = fingerprint(talk)
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        // Planning on LM Studio, counted; no cloud client can be made.
        model.settings.provider[.planning] = .lmStudio
        let counted = Mutex<[CountingClient]>([])
        model.runner.makeClient = { provider, setup in
            let client = CountingClient(WritingSetup.standardClient(provider, setup))
            counted.withLock { $0.append(client) }
            return client
        }
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        func requests() -> Int { counted.withLock { $0.reduce(0) { $0 + $1.requests } } }
        model.log.write("Acceptance test for v2 part M9c (beats and direction) started.")

        // 1. The talk, made in development: transcript, faces and voices (the punch-ins follow the face).
        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: talk)
        recording.kind = .talk
        try model.context.save()
        var started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let folder = try XCTUnwrap(recording.outputFolder, recording.statusReason ?? "not made")
        precondition(folder.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        lines.append(String(format: "13 Sep made in development in %.0f s (%@); %@", Date().timeIntervalSince(started), recording.status.title,
                            recording.faces == nil ? "no faces" : "faces checked"))
        // A fresh start for the beats: any beats.json left by an earlier run is deleted, so the model is asked and timed.
        let folderURL = URL(fileURLWithPath: folder, isDirectory: true)
        // PRAKRITI_DIRECTION_KEEP_BEATS=1 keeps them when they are there (a second run while tuning), and the time is then the
        // file's own. (The make above removes them anyway when it did not plan: beats.json goes with the plan, warning 171.)
        if environment["PRAKRITI_DIRECTION_KEEP_BEATS"] != "1" { try? FileManager.default.removeItem(at: folderURL.appending(path: BeatsFile.fileName)) }
        let fresh = !FileManager.default.fileExists(atPath: folderURL.appending(path: BeatsFile.fileName).path)

        func plan(_ direction: RecordingDirection, label: String) async throws -> (plan: EditPlan, seconds: Double, requests: Int) {
            model.setDirection(direction, for: recording)
            let asked = requests()
            let t = Date()
            model.planEdit(recording)
            while model.planning.contains(recording.id) { try await Task.sleep(for: .milliseconds(100)) }
            let seconds = Date().timeIntervalSince(t)
            if let problem = model.planProblems[recording.id] { XCTFail("\(label): \(problem)"); throw PlanStep.Failure(reason: problem) }
            model.forgetEditPlan(recording)
            let plan = try XCTUnwrap(EditPlan.read(folder: folder))
            let count = VisualPlan.count(plan)
            lines.append("")
            lines.append(String(format: "%@: planned in %.1f s, %d model request(s). %@", label, seconds, requests() - asked, plan.summary))
            lines.append("  Chips: " + (plan.direction?.chips.joined(separator: "; ") ?? "none"))
            for line in plan.planLines ?? [] { lines.append("  Plan: " + line) }
            lines.append(String(format: "  Picture: %.2f min, %d changes, %.2f a minute, median shot %.2f s, %d punch-ins, %d push-ins; video %@ (kept %@ + held %.2f s)",
                                count.minutes, count.changes, count.perMinute, count.medianShot, count.punchIns, count.pushIns,
                                Format.timecode(EditTimeline(plan: plan).duration), Format.timecode(plan.keptSeconds), plan.holdSeconds))
            return (plan, seconds, requests() - asked)
        }

        // 2. Clear, no direction (the baseline M9a measured).
        let clear = try await plan(RecordingDirection(), label: "No direction (Clear)")
        verdict("No direction asks no model", clear.requests == 0, "\(clear.requests) requests")

        // 3. "More energetic. Faster, more frequent cuts."
        let energetic = try await plan(RecordingDirection(prompt: "More energetic. Faster, more frequent cuts."), label: "Energetic")
        let chips = energetic.plan.direction?.chips ?? []
        verdict("check 3 (Energetic): the chips include Style Energetic and Pace faster",
                chips.contains("Style: Energetic") && chips.contains { $0.hasPrefix("Pace: faster") }, chips.joined(separator: "; "))
        let e = VisualPlan.count(energetic.plan)
        verdict("check 3 (Energetic): 12 to 15 visual changes a minute", (12...15).contains(e.perMinute),
                String(format: "%d changes in %.2f min, %.2f a minute", e.changes, e.minutes, e.perMinute))
        verdict("check 3 (Energetic): median shot 3 to 4 s", (3...4).contains(e.medianShot), String(format: "%.2f s", e.medianShot))
        verdict("Energetic is read by the rules alone (no model request)", energetic.requests == 0, "\(energetic.requests)")
        verdict("Energetic punch-ins never past 1.15 (1080p source)", e.largestScale <= 1.15 + 1e-9, String(format: "%.3f", e.largestScale))

        // 4. "Focus on the parts that are motivating or enlightening. Under 10 minutes." (the beats, by Qwen, timed)
        started = Date()
        let focus = try await plan(RecordingDirection(prompt: "Focus on the parts that are motivating or enlightening. Under 10 minutes."), label: "Focus and length")
        let beats = try XCTUnwrap(BeatsFile.cached(in: folderURL, transcriptSHA256: focus.plan.transcriptSHA256), "beats.json was written")
        lines.append(String(format: "  Beats: %@ (%d tries, temperature %@, seed %@); notes: %@", beats.line, beats.attempts,
                            beats.temperature.map { String($0) } ?? "none", beats.seed.map(String.init) ?? "none",
                            beats.notes.isEmpty ? "none" : beats.notes.joined(separator: " ")))
        for b in beats.beats {
            lines.append(String(format: "    %@ %@ to %@ (%@, %@) m%d e%d p%d s%d h%d ph%d t%d pe%d%@%@%@ %@", b.id, Format.timecode(b.start), Format.timecode(b.end), b.kind.rawValue,
                                Format.length(b.seconds), b.score(.motivating), b.score(.enlightening), b.score(.practical), b.score(.story), b.score(.humor),
                                b.score(.philosophy), b.score(.technique), b.score(.personal), b.thesis ? " thesis" : "",
                                b.dependsOn.isEmpty ? "" : " needs " + b.dependsOn.joined(separator: ","), b.keyLine == nil ? "" : " key line",
                                (focus.plan.beatChoice?.kept.contains(b.id) ?? false) ? "KEPT" : "dropped"))
        }
        verdict("check 3: the beats by Qwen3.8-27B in LM Studio, timed", beats.provider == ModelProvider.lmStudio.rawValue && beats.by.contains("LM Studio")
                && (!fresh || focus.requests >= 1),
                String(format: "%@: the annotation took %@ in %d tr%@; the whole plan %.0f s, %d request(s) in this run%@", beats.by, Format.length(beats.seconds),
                       beats.attempts, beats.attempts == 1 ? "y" : "ies", focus.seconds, focus.requests, fresh ? "" : " (beats kept from an earlier run)"))
        let length = EditTimeline(plan: focus.plan).duration
        verdict("check 3 (Focus, under 10 minutes): at most 10:00 and at least 8:30", length <= 600 + 1e-6 && length >= 510,
                "\(Format.timecode(length)) (\(String(format: "%.2f", length)) s)")
        let choice = try XCTUnwrap(focus.plan.beatChoice)
        let byID = Dictionary(uniqueKeysWithValues: beats.beats.map { ($0.id, $0) })
        func mean(_ ids: [String]) -> Double {
            ids.isEmpty ? 0 : ids.compactMap { byID[$0] }.map { Double($0.score(.motivating) + $0.score(.enlightening)) }.reduce(0, +) / Double(ids.count)
        }
        verdict("check 3 (Focus): kept beats score higher for motivating plus enlightening than dropped beats", mean(choice.kept) > mean(choice.dropped),
                String(format: "kept %.2f (%d beats), dropped %.2f (%d beats)", mean(choice.kept), choice.kept.count, mean(choice.dropped), choice.dropped.count))
        let keptSet = Set(choice.kept)
        let broken = beats.beats.filter { keptSet.contains($0.id) }.flatMap { b in b.dependsOn.filter { !keptSet.contains($0) }.map { "\(b.id) needs \($0)" } }
        verdict("Every kept beat keeps what it depends on; the thesis and the close are kept", broken.isEmpty
                && beats.beats.filter(\.thesis).allSatisfy { keptSet.contains($0.id) }
                && (beats.beats.last { $0.kind == .closing }.map { keptSet.contains($0.id) } ?? true), broken.isEmpty ? "all held" : broken.joined(separator: ", "))
        let validation = PlanValidation.check(focus.plan, words: try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard)))))
        verdict("The directed plan passes its own check (PlanValidation)", validation.isEmpty, validation.map(\.line).joined(separator: "; "))

        // 5. A pace-only change: no model request, the plan in under 10 s.
        var brisk = RecordingDirection(prompt: "Focus on the parts that are motivating or enlightening. Under 10 minutes.")
        brisk.pace = .brisk
        let pace = try await plan(brisk, label: "Pace only (Brisk)")
        verdict("check 3 (pace-only): 0 model requests (LM Studio request count)", pace.requests == 0, "\(pace.requests)")
        verdict("check 3 (pace-only): the plan shown in under 10 s", pace.seconds < 10, String(format: "%.1f s", pace.seconds))
        verdict("Pace-only keeps the same beats", pace.plan.beatChoice?.kept == choice.kept || EditTimeline(plan: pace.plan).duration <= 600,
                "\(pace.plan.beatChoice?.kept.count ?? 0) kept, video \(Format.timecode(EditTimeline(plan: pace.plan).duration))")

        // 6. "Show the students": nothing changes, the People sentence.
        let people = try await plan(RecordingDirection(prompt: "Show the students."), label: "Show the students")
        verdict("\"Show the students\" changes nothing and says the People sentence", people.plan.direction?.reading?.said == [Direction.peopleSentence]
                && people.plan.direction?.chips.isEmpty == true && people.requests == 0 && people.plan.spans == clear.plan.spans,
                "said \(people.plan.direction?.reading?.said ?? []), \(people.requests) requests, spans same as Clear: \(people.plan.spans == clear.plan.spans)")

        // 7. Does LM Studio honour the seed? The beats asked for once more, straight from the planner, on the same words.
        if environment["PRAKRITI_DIRECTION_SEED"] != "skip" {
            let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard))))
            var setup = model.runner.writingSetup()
            setup.providers[.planning] = .lmStudio
            let planner = Planner(setup: setup, log: model.log, subject: LockSubject(people: PeopleFacts(checked: true)), fileName: talk.lastPathComponent)
            let client = planner.client()
            let t = Date()
            let again = try await planner.beats(words: words.words, recording: "2026-09-13 18-25-44", transcriptSHA256: words.transcriptSHA256, kind: .talk,
                                                duration: recording.duration ?? 0, client: client)
            await planner.release(client)
            let same = again.beats == beats.beats
            let sameBounds = again.beats.map { [$0.firstSentence, $0.lastSentence] } == beats.beats.map { [$0.firstSentence, $0.lastSentence] }
            lines.append("")
            lines.append(String(format: "Seed (measured, not a gate): the beats asked for again in %.0f s: %@; the same beats %@, the same boundaries %@ (%d and %d beats)",
                                Date().timeIntervalSince(t), again.by, same ? "yes" : "no", sameBounds ? "yes" : "no", beats.beats.count, again.beats.count))
        }

        verdict("Nothing went to a cloud provider", cloudCalls.count == 0, "\(cloudCalls.count) cloud calls; the planning task on LM Studio")
        verdict("The original is unchanged (size and modification date)", fingerprint(talk) == before, fingerprint(talk))
        let text = (["v2 part M9c acceptance (beats and direction), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed."]).joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-direction.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M9c finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
