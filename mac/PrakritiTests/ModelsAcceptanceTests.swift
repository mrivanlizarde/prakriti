import AppKit
import Foundation
import SwiftData
import Synchronization
import XCTest
@testable import Prakriti

/// Counts calls a test does not allow (the Claude API, under the privacy lock).
final class CallCounter: Sendable {
    private let calls = Mutex(0)
    func add() { calls.withLock { $0 += 1 } }
    var count: Int { calls.withLock { $0 } }
}

/// A client that must never be asked: it counts the call and refuses, so nothing is ever sent.
struct RefusingClient: LanguageModelClient {
    let provider: ModelProvider
    let counter: CallCounter
    var displayName: String { "\(provider.title) (must not be called)" }
    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) { counter.add(); return (0, 1) }
    func complete(_ request: ModelRequest) async throws -> ModelReply {
        counter.add()
        throw ModelFailure(kind: .notSetUp, reason: "This provider must not be called.")
    }
    func check() async -> ProviderCheck { ProviderCheck(state: .notSetUp, line: "Not called.", at: Date()) }
}

/// Milestone 6's acceptance, on the real 13 Sep talk, through the app's own settings, runner,
/// pipeline and writer, with the real Qwen3.8-27B in LM Studio and Apple's on-device model:
///
///   cd ~/Code/prakriti/mac && make accept-models MILESTONE=m6
///
/// 1. Writing is set to the Claude API on purpose. The 13 Sep talk names Serenity, so the privacy
///    lock must hand the writing to LM Studio; the Claude client here only counts and refuses, and
///    must be asked 0 times. Tags and the summary are set to Apple on-device.
/// 2. Qwen3.8-27B, loaded by Prakriti at 65,536 tokens (the model is unloaded first so the load is
///    exercised), returns JSON with 3 title options, show notes, chapters, and an accuracy checklist.
/// 3. Checked independently here: every chapter starts at a cue time of the episode's transcript.srt,
///    and every quote is found word for word in transcript.txt. The runtime is recorded.
/// 4. Apple on-device writes tags for a short input (the talk's first lines).
/// 5. Pictures of the recording page and of the Models screen after a real test of each provider.
///
/// Skipped unless PRAKRITI_ACCEPTANCE=models. Reads only the 13 Sep talk (Gabriel only), read-only;
/// writes only into ~/Prakriti/Dev/Outputs; the store is in memory; lines go to the development log.
@MainActor
final class ModelsAcceptanceTests: XCTestCase {
    func testMilestoneSixOnTheThirteenSepTalk() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "models" else {
            throw XCTSkip("Runs the writing model for several minutes. Run it with: cd ~/Code/prakriti/mac && make accept-models MILESTONE=m6")
        }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.log.write("Acceptance test for milestone 6 started (in-memory store, outputs to \(paths.outputs.path)).")

        // 1. The choices: writing on the Claude API (the lock must refuse it), tags and summary on
        //    Apple on-device, titles on.
        model.settings.provider = [.writing: .claudeAPI, .tagging: .appleOnDevice, .summarizing: .appleOnDevice]
        let claudeCalls = CallCounter()
        model.runner.makeClient = { provider, setup in
            provider == .claudeAPI ? RefusingClient(provider: provider, counter: claudeCalls) : WritingSetup.standardClient(provider, setup)
        }
        let defaults = model.defaultSettings()
        try XCTUnwrap(defaults.first { $0.kind == .titlesNotesChapters }).isOn = true
        try model.context.save()

        // LM Studio: unloaded first, so Prakriti's own load at 65,536 tokens is what serves the run.
        let lmStudio = LMStudioClient(address: model.settings.lmStudioAddress, model: model.settings.lmStudioModel)
        let before = try await lmStudio.state()
        XCTAssertTrue(before.downloaded, "Qwen3.8-27B must be downloaded in LM Studio")
        for instance in before.instances {
            _ = try await ModelHTTP.send(ModelHTTP.post(URL(string: lmStudio.root + "/api/v1/models/unload")!, body: ["instance_id": instance.id]),
                                         session: ModelHTTP.session, service: "LM Studio")
        }
        let unloaded = try await lmStudio.state()
        XCTAssertTrue(unloaded.instances.isEmpty)

        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path))
        let folder = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: folder)
        let fingerprintBefore = fingerprint(talk)
        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.kind = .talk
        try model.context.save()
        XCTAssertFalse(recording.hasSerenity, "nothing is known about Serenity before the transcript")

        var report = ["Milestone 6 acceptance, \(Date().formatted(date: .abbreviated, time: .standard))",
                      "The 13 Sep talk: \(talk.lastPathComponent)",
                      "Choices: writing = Claude API (on purpose, to test the privacy lock), tagging = Apple on-device, summarizing = Apple on-device",
                      "LM Studio before the run: \(before.instances.isEmpty ? "not loaded" : before.instances.map { "\($0.id) at \($0.context ?? 0)" }.joined(separator: ", ")); unloaded for the test", ""]
        let logStart = (try? String(contentsOf: model.log.todayFile!, encoding: .utf8))?.count ?? 0

        // 2. The whole make, with the titles, show notes and chapters.
        let started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let total = Date().timeIntervalSince(started)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let run = try XCTUnwrap(recording.latestRun)
        let writingStep = try XCTUnwrap(run.steps.first { $0.name == PipelineStep.writing.title })
        XCTAssertEqual(writingStep.state, .done, writingStep.detail ?? "")
        let written = try XCTUnwrap(recording.written, recording.writingProblem ?? "nothing written")
        XCTAssertEqual(fingerprint(talk), fingerprintBefore, "the original is untouched")

        report.append("Run: \(recording.status.title) in \(Format.length(total)). Steps:")
        for step in run.steps { report.append("  \(step.name): \(step.state.title), \(step.seconds.map { String(format: "%.1f s", $0) } ?? "-"). \(step.detail ?? "")") }

        // Privacy lock: Serenity is named in the transcript, so the Claude API was never asked.
        XCTAssertTrue(recording.hasSerenity, "the 13 Sep transcript names Serenity")
        XCTAssertTrue(recording.isPrivacyLocked)
        XCTAssertEqual(claudeCalls.count, 0, "the Claude API must never be asked for a recording with Serenity in it")
        XCTAssertEqual(written.writingProvider, ModelProvider.lmStudio.rawValue)
        XCTAssertEqual(written.lockReason, "This recording mentions Serenity")
        XCTAssertEqual(written.lockedTasks, ["writing"])
        XCTAssertTrue(writingStep.detail?.contains("Privacy lock") == true)
        report += ["", "Privacy lock:",
                   "  recording.hasSerenity = \(recording.hasSerenity) (the transcript names her; the recording started with false)",
                   "  written by: \(written.writtenBy) (provider \(written.writingProvider)); lock reason: \(written.lockReason ?? "none"); locked tasks: \(written.lockedTasks)",
                   "  Claude API client calls: \(claudeCalls.count)"]

        // 3. The files, read back independently of the writer.
        let jsonURL = folder.appending(path: WrittenPackage.fileName)
        let data = try Data(contentsOf: jsonURL)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any], "titles-notes-chapters.json is valid JSON")
        let modelAnswer = try XCTUnwrap(object["modelAnswer"] as? String)
        let answerObject = try XCTUnwrap(WritingCheck.jsonObject(modelAnswer), "the model's own answer is valid JSON")
        let answerIsBareJSON = (try? JSONSerialization.jsonObject(with: Data(modelAnswer.trimmingCharacters(in: .whitespacesAndNewlines).utf8))) != nil
        let titles = try XCTUnwrap(object["titles"] as? [String])
        XCTAssertTrue((3...4).contains(titles.count), "the pick and up to three alternatives (four asked for since 11 Oct)")
        let showNotes = try XCTUnwrap(object["showNotes"] as? String)
        XCTAssertFalse(showNotes.isEmpty)
        let chapters = try XCTUnwrap(object["chapters"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(chapters.count, 3)
        let checklist = try XCTUnwrap(object["checklist"] as? [[String: Any]])
        XCTAssertFalse(checklist.isEmpty)
        report += ["", "titles-notes-chapters.json: valid JSON (JSONSerialization). The model's own answer: "
                   + (answerIsBareJSON ? "valid JSON as it came, nothing around it" : "JSON inside other text, read from inside it")
                   + "; it offered \((answerObject["titles"] as? [Any])?.count ?? 0) titles, \((answerObject["chapters"] as? [Any])?.count ?? 0) chapters, \((answerObject["checklist"] as? [Any])?.count ?? 0) claims.",
                   "", "Title options (\(titles.count)):"]
        report += titles.enumerated().map { "  \($0.offset + 1). \($0.element) (\($0.element.count) characters)" }
        report += ["", "Show notes (\(WritingText.words(showNotes)) words):", "  " + showNotes]

        // Chapters: each start is a cue start of the episode's own .srt (to the millisecond).
        let srt = try String(contentsOf: folder.appending(path: "transcript.srt"), encoding: .utf8)
        let cues = TranscriptFiles.cues(srt: srt)
        report += ["", "Chapters (\(chapters.count)), each checked against the \(cues.count) cue starts of transcript.srt (the episode's clock):"]
        var previous = -1.0
        for chapter in chapters {
            let start = try XCTUnwrap(chapter["start"] as? Double)
            let title = try XCTUnwrap(chapter["title"] as? String)
            let cue = cues.firstIndex { abs($0.start - start) < 0.0011 }
            XCTAssertNotNil(cue, "chapter at \(start) is not a cue time")
            XCTAssertGreaterThan(start, previous)
            previous = start
            report.append("  \(cue != nil ? "FOUND" : "MISSING") \(WritingText.stamp(start)) (\(String(format: "%.3f", start)) s = cue \(cue.map { String($0 + 1) } ?? "none")) \(title)")
        }
        XCTAssertEqual((chapters.first?["start"] as? Double) ?? -1, cues.first?.start ?? 0, accuracy: 0.0011, "the first chapter starts with the first line")

        // Quotes: each found word for word in transcript.txt.
        let txt = try String(contentsOf: folder.appending(path: "transcript.txt"), encoding: .utf8)
        let collapsed = txt.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        report += ["", "Accuracy checklist (\(checklist.count)), each quote searched for in transcript.txt (\(Format.number(WritingText.words(txt))) words):"]
        for item in checklist {
            let quote = try XCTUnwrap(item["quote"] as? String)
            let claim = try XCTUnwrap(item["claim"] as? String)
            let plain = txt.range(of: quote)
            let spaced = collapsed.range(of: quote.split(whereSeparator: \.isWhitespace).joined(separator: " "))
            XCTAssertTrue(plain != nil || spaced != nil, "not found word for word: \(quote)")
            let at = (item["at"] as? Double).map { WritingText.stamp($0) } ?? "?"
            let offset = plain.map { txt.distance(from: txt.startIndex, to: $0.lowerBound) }
            report.append("  \(plain != nil ? "FOUND as is" : (spaced != nil ? "FOUND (spaces collapsed)" : "NOT FOUND")) at character \(offset.map(String.init) ?? "?"), line \(at): \"\(quote)\"")
            report.append("     claim: \(claim)")
        }
        let leftOut = (object["leftOutQuotes"] as? [String]) ?? []
        report.append("  Left out by the writer, not found word for word: \(leftOut.count)")
        for quote in leftOut { report.append("     \"\(quote)\" (in transcript.txt: \(txt.contains(quote) ? "yes" : "no"))") }
        report.append("  Chapters left out (time not in the transcript): \(object["leftOutChapters"] as? Int ?? 0)")
        for note in written.notes { report.append("  Note: \(note)") }

        // No em or en dash in anything written.
        let notesMarkdown = try String(contentsOf: folder.appending(path: WrittenPackage.notesFileName), encoding: .utf8)
        for text in titles + [showNotes, notesMarkdown] + chapters.compactMap({ $0["title"] as? String }) {
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "a dash in: \(text)")
        }
        let reportMarkdown = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(reportMarkdown.contains("| Titles, show notes and chapters |"))
        XCTAssertEqual(ApprovalCheck.filesToApprove(recording).contains(WrittenPackage.notesFileName), true)
        XCTAssertFalse(ApprovalCheck.filesToApprove(recording).contains(WrittenPackage.fileName))

        // Tags and summary by Apple on-device, on the whole talk (read in parts if it does not fit).
        report += ["", "Tags by \(written.taggedBy ?? "nobody"): \(written.tags.joined(separator: ", "))",
                   "Summary by \(written.summarizedBy ?? "nobody"): \(written.summary ?? "none")"]

        // Runtime.
        report += ["", "Runtime: the writing step took \(Format.length(written.seconds)) in all (\(String(format: "%.1f", written.seconds)) s); "
                   + "the writing task \(String(format: "%.1f", written.writingSeconds)) s over \(Format.count(written.attempts, "try", "tries")); "
                   + "\(written.promptTokens.map(String.init) ?? "?") tokens read, \(written.completionTokens.map(String.init) ?? "?") written, of which \(written.reasoningTokens.map(String.init) ?? "?") thinking.",
                   "Whole make, from the start of the check to the files placed: \(Format.length(total))."]

        // LM Studio: loaded by Prakriti at 65,536 and unloaded after (it was not loaded before).
        let log = String((try String(contentsOf: model.log.todayFile!, encoding: .utf8)).dropFirst(logStart))
        let loadLines = log.components(separatedBy: "\n").filter { $0.contains("Loaded Qwen") || $0.contains("Unloaded Qwen") || $0.contains("try ") || $0.contains("privacy lock") || $0.contains("tags by") || $0.contains("summary by") }
        XCTAssertTrue(log.contains("at 65,536 tokens"), "Prakriti loaded the model at 65,536 tokens")
        let after = try await lmStudio.state()
        XCTAssertTrue(after.instances.isEmpty, "Prakriti unloads what it loaded")
        report += ["", "From the development log:"] + loadLines.map { "  " + $0 }
        report.append("LM Studio after the run: \(after.instances.isEmpty ? "not loaded (Prakriti unloaded what it loaded)" : "still loaded")")

        // 4. Apple on-device: tags for a short input, the talk's first lines.
        let firstLines = Array(WritingLine.lines(cues).prefix(8))
        report += ["", "Apple on-device, a short input (\(firstLines.count) lines, \(WritingText.words(firstLines.map(\.text).joined(separator: " "))) words):"]
        if let reason = AppleOnDeviceClient.unavailableReason {
            report.append("  Unavailable: \(reason)")
        } else {
            let apple = AppleOnDeviceClient()
            let budget = try await apple.budget(for: ModelRequest(system: Writer.tagsSystem, user: firstLines.map(\.text).joined(separator: " "), shape: .tags))
            let shortStart = Date()
            let tags = WritingCheck.tags(try await Writer(setup: WritingSetup(), log: model.log)
                .shortTask(.tags, client: apple, lines: firstLines, fileName: "acceptance short input"))
            XCTAssertGreaterThanOrEqual(tags.count, 1)
            report.append("  \(Format.count(tags.count, "tag")) in \(String(format: "%.1f", Date().timeIntervalSince(shortStart))) s, "
                          + "about \(budget.needed) of its \(budget.limit) tokens: \(tags.joined(separator: ", "))")
        }

        // 5. Pictures: the page, then the Models screen after a real test of each provider.
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        for (scheme, appearance) in SnapshotRenderer.appearances {
            model.open(recording)
            try renderer.render(model: model, appearance: appearance, name: "m6-13sep-written-\(scheme)")
        }
        model.runner.makeClient = nil // the real clients now; the Claude API has no key, so its test sends nothing
        for provider in ModelProvider.allCases { model.testProvider(provider) }
        let deadline = Date().addingTimeInterval(240)
        while Date() < deadline && (model.providerChecks.count < ModelProvider.allCases.count
                                    || model.providerChecks.values.contains(where: { $0.state == .checking })) {
            try await Task.sleep(for: .seconds(1))
        }
        report += ["", "Models screen, each provider tested for real:"]
        for provider in ModelProvider.allCases {
            let check = model.providerChecks[provider]
            report.append("  \(provider.title): \(check?.state.rawValue ?? "not tested"). \(check?.line ?? "")")
        }
        XCTAssertEqual(model.providerChecks[.lmStudio]?.state, .ok)
        XCTAssertEqual(model.providerChecks[.claudeAPI]?.state, .notSetUp, "no key in the test Keychain item: nothing is sent")
        for (scheme, appearance) in SnapshotRenderer.appearances {
            model.path = []
            model.selection = .models
            try renderer.render(model: model, appearance: appearance, name: "m6-models-\(scheme)")
        }

        let out = SnapshotRenderer.milestoneFolder()
        try report.joined(separator: "\n").appending("\n").write(to: out.appending(path: "acceptance-models.txt"), atomically: true, encoding: .utf8)
        try modelAnswer.write(to: out.appending(path: "model-answer.txt"), atomically: true, encoding: .utf8)
        try written.json().write(to: out.appending(path: "written-package.json"), atomically: true, encoding: .utf8)
        print(report.joined(separator: "\n"))
    }

    private func fingerprint(_ url: URL) -> String {
        let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        return "\(attributes[.size] ?? "?") \(attributes[.modificationDate] ?? "?")"
    }
}
