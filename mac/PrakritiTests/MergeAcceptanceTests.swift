import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M12a's acceptance (docs/v2/PLAN.md M12, check 2 up to the suggestions, and check 4), through the app in development:
///
/// - the REAL 13 Sep and 6 Sep talks, whole, made in development with the outputs every recording gets (the transcript and the people
///   check), both "Who is teaching: Gabriel Galindo";
/// - Find Supporting Moments on 13 Sep (its main points from its parts of the talk, from ~/Prakriti/Dev/Beats or read by Qwen3.8-27B in
///   LM Studio): one to three moments, all from 6 Sep, each the 6 Sep transcript's own words found word for word, 5 to 45 s on
///   sentence boundaries, with its date, why and where it would go;
/// - check 4: every request of "Choosing moments" counted under the lock: set to LM Studio here (cloud providers are tried only on
///   made-up words, PLAN section 11 D1), so 0 cloud requests (a refusing cloud client counts any), and the lock's route on the two real
///   recordings: Anthropic while Gabriel's release is on file, LM Studio when he is marked "no release" (worked out, nothing sent).
///
///   cd ~/Code/prakriti/mac && make accept-merge MILESTONE=v2-m12a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=merge. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs and the index to the
/// development Application Support; the originals are only read, checked by size and date before and after. Never a class, never the
/// archive. The moments' words are written only to the report in screens/ (kept off GitHub).
@MainActor
final class MergeAcceptanceTests: XCTestCase {
    func testFindSupportingMomentsOnTheTwoTalks() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "merge" else {
            throw XCTSkip("Reads the 13 Sep and 6 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-merge MILESTONE=v2-m12a")
        }
        guard (ProcessInfo.processInfo.environment["PRAKRITI_MERGE_PART"] ?? "") != "add" else { throw XCTSkip("PRAKRITI_MERGE_PART=add runs part M12b's half only") }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func report() {
            let text = (["v2 part M12a acceptance (supporting moments, found), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                        + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed."]).joined(separator: "\n") + "\n"
            try? text.write(to: out.appending(path: "acceptance-merge.txt"), atomically: true, encoding: .utf8)
            print(text)
        }

        let paths = AppPaths(mode: .development)
        let talks = [("13 Sep", paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")),
                     ("6 Sep", paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4"))]
        for (_, url) in talks {
            XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { url.path.contains($0) }, "never a class")
        }
        let before = talks.map { fingerprint($0.1) }

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        for task in ModelTask.allCases { model.settings.provider[task] = .lmStudio }
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        model.log.write("Acceptance test for v2 part M12a (supporting moments, found) started.")
        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        try model.context.save()

        var recordings: [String: Recording] = [:]
        for (label, url) in talks {
            let recording = Recording(filePath: url.path, recordedAt: AppModel.dateInName(url.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: url)
            recording.kind = .talk
            try model.context.save()
            model.setTeacher(teacher, for: recording)
            let started = Date()
            await model.runner.process(recording, trigger: .byHand)
            let facts = recording.peopleFacts
            lines.append(String(format: "%@: made in development in %.0f s; status %@; people checked: %@; %@", label, Date().timeIntervalSince(started),
                                recording.status.title, facts.checked ? "yes" : "no", recording.faces?.line ?? "no faces record"))
            verdict("\(label): transcript made and people checked (faces and voices)", recording.madeFiles.contains(TranscriptFiles.asHeard) && facts.checked,
                    "\(recording.wordCount ?? 0) words; steps \(model.peopleFolders.read(recording.id)?.steps ?? [])")
            recordings[label] = recording
        }
        guard let sep13 = recordings["13 Sep"], let sep6 = recordings["6 Sep"], let folder13 = sep13.outputFolder.map({ URL(fileURLWithPath: $0, isDirectory: true) }),
              let folder6 = sep6.outputFolder.map({ URL(fileURLWithPath: $0, isDirectory: true) }) else {
            report()
            throw XCTSkip("the talks were not made")
        }

        // The main points of 13 Sep come from its parts of the talk: the cache, else Qwen3.8-27B.
        let words13 = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folder13.appending(path: TranscriptFiles.asHeard))))
        if let cached = BeatsCache.seed("2026-09-13 18-25-44", folder: folder13) {
            lines.append("13 Sep parts of the talk from the cache: \(cached.line)")
        } else {
            let planner = Planner(setup: model.runner.writingSetup(), log: model.log, subject: sep13.lockSubject, fileName: sep13.fileName)
            let client = planner.client()
            let beats = try await planner.beats(words: words13.words, recording: "2026-09-13 18-25-44", transcriptSHA256: words13.transcriptSHA256, kind: .talk,
                                                duration: sep13.duration ?? 0, client: client)
            await planner.release(client)
            try beats.encoded().write(to: folder13.appending(path: BeatsFile.fileName))
            try? BeatsCache.write(beats)
            lines.append("13 Sep parts of the talk read now: \(beats.line)")
        }

        // Check 2, up to the suggestions: Find Supporting Moments on 13 Sep, from the Direction tab (its main points) and from selected
        // words (the transcript's Find Supporting Moments for This...), both entry points of design spec 3.8.
        model.momentRequests.reset()
        try? FileManager.default.removeItem(at: model.momentIndexURL)
        func run(_ request: MomentsRequest, _ label: String) async -> MomentSearch? {
            let started = Date()
            let state = await model.searchMoments(request)
            let seconds = Date().timeIntervalSince(started)
            guard case .found(let search) = state else {
                verdict("Check 2 (\(label)): the search ran", false, "\(state)")
                return nil
            }
            lines.append("")
            lines.append(String(format: "Find Supporting Moments on 13 Sep, %@: %.0f s. %@ searched %d, not searched %d; %d windows read on this Mac; %d candidates above %.2f; %d read by %@, %d not supporting; %d windows left out by the copy rules. Found %d.",
                                label, seconds, search.teacherName, search.searched, search.notSearched, search.windows, search.candidates, MomentFinder.threshold,
                                search.judged, search.by, search.declined, search.copyRules, search.moments.count))
            if search.moments.isEmpty { lines.append("  The sheet says: \(search.emptyLine)") }
            return search
        }
        guard let main = await run(MomentsRequest(recordingID: sep13.id), "its main points") else { report(); return }
        verdict("Check 2 (its main points): the search ran on 6 Sep only, gave at most three, and says what it found with the real count",
                main.searched == 1 && main.moments.count <= 3 && main.moments.allSatisfy { $0.sourceID == sep6.id }
                    && (main.moments.isEmpty ? main.emptyLine.contains("searched 1 recording of Gabriel Galindo") : true),
                "\(main.moments.count) moments; \(main.moments.isEmpty ? main.emptyLine : "")")
        // The part of 13 Sep about the teacher's own work in sales, selected as words.
        let beats13 = try XCTUnwrap(BeatsFile.cached(in: folder13, transcriptSHA256: words13.transcriptSHA256))
        guard let part = beats13.beats.first(where: { $0.summary.lowercased().contains("sales") }) else {
            verdict("Check 2 (selected words): a part of 13 Sep about sales to select", false, beats13.beats.map(\.summary).joined(separator: "; "))
            report()
            return
        }
        lines.append("")
        lines.append("Selected on 13 Sep: the part \u{201C}\(part.summary)\u{201D}, \(Format.timecode(part.start)) to \(Format.timecode(part.end)).")
        guard let selected = await run(MomentsRequest(recordingID: sep13.id, selection: TimeRange(start: part.start, end: part.end)), "selected words") else { report(); return }
        let index = try MomentIndex(url: model.momentIndexURL)
        let entry6 = try index.entry(sep6.id)
        lines.append("Index: \(model.momentIndexURL.path), 6 Sep \(entry6?.windows ?? 0) windows by \(entry6?.model ?? "none"); 13 Sep not indexed (it is the one being edited): \(try index.entry(sep13.id) == nil)")
        verdict("Check 2 (selected words): one to three moments", (1...3).contains(selected.moments.count), "\(selected.moments.count)")
        let search = MomentSearch(header: "", moments: main.moments + selected.moments, searched: 1, notSearched: 0, teacherName: "", windows: 0, candidates: 0,
                                  judged: main.judged + selected.judged, declined: 0, by: "", seconds: 0)
        verdict("Check 2: every moment is from 6 Sep", search.moments.allSatisfy { $0.sourceID == sep6.id }, search.moments.map(\.sourceLabel).joined(separator: "; "))
        let words6 = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folder6.appending(path: TranscriptFiles.asHeard))))
        let whole6 = PlanWords.text(words6.words[...])
        let sentences6 = MomentWindows.sentences(words6.words)
        let starts = Set(sentences6.map { words6.words[$0.lowerBound].index }), ends = Set(sentences6.map { words6.words[$0.upperBound].index })
        for (n, moment) in search.moments.enumerated() {
            lines.append("")
            lines.append("Moment \(n + 1): \(moment.sourceLabel), \(Format.timecode(moment.window.start)) to \(Format.timecode(moment.window.end)) (\(Format.timecode(moment.seconds))), similarity \(String(format: "%.3f", moment.similarity))")
            lines.append("  Words: \u{201C}\(moment.words)\u{201D}")
            lines.append("  Why: \(moment.why)")
            lines.append("  Where it would go: after \u{201C}...\(moment.afterWords)\u{201D} at \(Format.timecode(moment.after)) of 13 Sep")
            verdict("Check 2: moment \(n + 1)'s words are found word for word in the 6 Sep transcript", whole6.contains(moment.words) && moment.words.count > 20,
                    "\(moment.words.split(separator: " ").count) words, found: \(whole6.contains(moment.words))")
            verdict("Check 2: moment \(n + 1) is 5 to 45 s on sentence boundaries", moment.seconds >= 5 && moment.seconds <= 45 && starts.contains(moment.window.firstWord)
                    && ends.contains(moment.window.lastWord), String(format: "%.1f s, words %d to %d", moment.seconds, moment.window.firstWord, moment.window.lastWord))
            verdict("Check 2: moment \(n + 1) keeps Ivan's copy rules", CopyRules.flag(moment.words) == nil, CopyRules.flag(moment.words) ?? "nothing flagged")
            verdict("Check 2: moment \(n + 1) has its date, why and where", moment.sourceLabel.hasPrefix("Sun 6 Sep 2026") && !moment.why.isEmpty && moment.after > 0,
                    "\(moment.sourceLabel); why \(moment.why.split(separator: " ").count) words; after \(Format.timecode(moment.after))")
        }

        // Check 4: the requests, counted under the lock.
        lines.append("")
        verdict("Check 4: every request of Choosing moments counted, all on this Mac", model.momentRequests.local == search.judged && model.momentRequests.cloud == 0 && cloudCalls.count == 0,
                "\(model.momentRequests.local) to LM Studio, \(model.momentRequests.cloud) to a cloud provider, the refusing cloud client asked \(cloudCalls.count) times; \(search.judged) moments read")
        var cloudSetup = WritingSetup()
        cloudSetup.providers = [.choosingMoments: .claudeAPI]
        let pair = sep13.lockSubject.joined(with: sep6.lockSubject)
        let releasedRoute = MomentJudge.route(setup: cloudSetup, subject: pair).provider
        teacher.noRelease = true
        try model.context.save()
        let lockedPair = sep13.lockSubject.joined(with: sep6.lockSubject)
        let lockedRoute = MomentJudge.route(setup: cloudSetup, subject: lockedPair)
        teacher.noRelease = false
        try model.context.save()
        verdict("Check 4: with Choosing moments on Anthropic, the lock sends the 13 Sep and 6 Sep pair to Anthropic while Gabriel's release is on file, and keeps it on this Mac when he is marked no release",
                releasedRoute == .claudeAPI && lockedRoute.provider == .lmStudio,
                "released: \(releasedRoute.title); no release: \(lockedRoute.provider.title) (\(lockedRoute.lockLine ?? "")). Worked out only; nothing was sent")

        let after = talks.map { fingerprint($0.1) }
        verdict("The originals are unchanged by size and date", before == after, after.joined(separator: "; "))
        report()
        model.log.write("Acceptance test for v2 part M12a finished.")
    }


    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
