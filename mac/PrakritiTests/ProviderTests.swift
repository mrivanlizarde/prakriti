import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M5a (docs/v2/PLAN.md M5, checks 1 (Keychain and log), 2 and 4), with the lock set to Ivan's 12 Oct decision
/// by part LOCK (Wed 14 Oct): the privacy lock counted in cloud requests, the cloud adapter's own check, the name
/// tokens, the per-person release switch, the key and the log, and the hardware check. No request leaves the Mac: cloud clients are scripted or answered by
/// `StubProtocol`. The only recording-shaped text is `synthetic-transcript.json` (a made-up talk naming
/// no real person) and sentences written here.
@MainActor
final class ProviderTests: XCTestCase {
    static let fixtures = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/Fixtures", directoryHint: .isDirectory)

    /// The synthetic talk as the writer reads it, from a copy of the fixture in a temporary folder.
    func syntheticInput(kind: RecordingKind = .talk, people: PeopleFacts) throws -> WritingInput {
        let source = Self.fixtures.appending(path: "synthetic-transcript.json")
        guard FileManager.default.fileExists(atPath: source.path) else { throw XCTSkip("make fixtures first: \(source.path) is missing") }
        let folder = FileManager.default.temporaryDirectory.appending(path: "prakriti-provider-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.copyItem(at: source, to: folder.appending(path: TranscriptFiles.asHeard))
        var input = try XCTUnwrap(WritingInput.from(folder: folder, clock: nil, duration: 0, applyLexicon: false, label: "Synthetic",
                                                    fileName: "synthetic.json", kind: kind, knownSerenity: false))
        input.people = people
        return input
    }

    /// An answer that passes `WritingCheck` for these lines: real line times, quotes word for word.
    static func passingAnswer(_ input: WritingInput) -> String {
        let lines = WritingLine.lines(input.cues)
        let rules = WritingRules.forLength(lines.last?.end ?? 0)
        let starts = (0..<rules.minChapters).map { lines[$0 * lines.count / rules.minChapters] }
        let quotes = lines.filter { $0.text.split(separator: " ").count >= 8 }.prefix(rules.minClaims)
        let chapters = starts.enumerated().map { ["start": $0.element.label, "title": "Part \($0.offset + 1)"] }
        let checklist = quotes.map { ["claim": "A claim.", "quote": $0.text.trimmingCharacters(in: .whitespaces), "at": $0.label] }
        let object: [String: Any] = ["titles": ["Holding a Question Lightly", "Questions That Wait", "The Simple Question"],
                                     "show_notes": "A talk about holding a simple question lightly.", "chapters": chapters, "checklist": checklist]
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    static let teacherID = UUID()
    static func teacher(released: Bool = true) -> PeopleFacts.Named {
        .init(personID: teacherID, name: "Asha Verlaine", heard: true, seen: true, released: released)
    }

    // MARK: Check 2: the lock, counted in cloud requests (part LOCK's acceptance)

    func testTheLockCountsCloudRequests() async throws {
        func cloudRequests(kind: RecordingKind = .talk, people: PeopleFacts, serenity: Bool = false) async throws -> (Int, Writer.Outcome) {
            var input = try syntheticInput(kind: kind, people: people)
            input.knownSerenity = serenity
            let cloud = ScriptedClient(.claudeAPI, limit: 200_000, replies: [.success(Self.passingAnswer(input))])
            let local = ScriptedClient(.lmStudio, limit: 200_000, replies: [.success(Self.passingAnswer(input))])
            var setup = WritingSetup()
            setup.providers = [.writing: .claudeAPI, .tagging: .lmStudio, .summarizing: .lmStudio]
            setup.maxAttempts = 1
            setup.makeClient = { _, _ in local }
            setup.makeCloudClient = { _, _ in cloud }
            let outcome = try await Writer(setup: setup, log: nil).write(input)
            return (cloud.requests.count, outcome)
        }
        let checkedTeacher = PeopleFacts(checked: true, named: [Self.teacher()])
        var lines: [String] = []
        func expect(_ label: String, _ measured: (Int, Writer.Outcome), _ expected: Int, reason: String? = nil) {
            XCTAssertEqual(measured.0, expected, label)
            XCTAssertEqual(measured.1.lockReason, reason, label)
            if expected == 1 { XCTAssertEqual(measured.1.package?.writingProvider, ModelProvider.claudeAPI.rawValue, "\(label): \(measured.1.problem ?? "")") }
            lines.append("\(label): \(measured.0) Anthropic requests (expected \(expected))" + (measured.1.lockReason.map { ", lock: \($0)" } ?? ", written by \(measured.1.package?.writtenBy ?? "nobody")"))
        }

        // Every participant signed a release (Ivan, 12 Oct): all of these go to Anthropic.
        expect("a class", try await cloudRequests(kind: .lesson, people: checkedTeacher), 1)
        expect("a class nobody named anyone in, people not checked", try await cloudRequests(kind: .lesson, people: .notChecked), 1)
        expect("a talk, people not checked", try await cloudRequests(people: .notChecked), 1)
        expect("a recording not marked as anything", try await cloudRequests(kind: .unknown, people: checkedTeacher), 1)
        expect("an unnamed person seen", try await cloudRequests(people: PeopleFacts(checked: true, named: [Self.teacher()], unnamedSeen: 3)), 1)
        expect("an unnamed person heard", try await cloudRequests(people: PeopleFacts(checked: true, named: [Self.teacher()], unnamedHeard: 1)), 1)
        expect("a transcript that names Serenity", try await cloudRequests(people: checkedTeacher, serenity: true), 1)
        expect("a talk, one released speaker", try await cloudRequests(people: checkedTeacher), 1)
        // Ivan's own marks keep it on this Mac.
        var leftOut = PeopleFacts(checked: true, named: [Self.teacher()], unnamedHeard: 1)
        leftOut.leftOut = 1
        expect("someone set to Leave Out", try await cloudRequests(kind: .lesson, people: leftOut), 0, reason: PrivacyLock.leftOut)
        expect("a speaker marked no release", try await cloudRequests(people: PeopleFacts(checked: true, named: [Self.teacher(released: false)])), 0,
               reason: PrivacyLock.noRelease)
        var unchecked = PeopleFacts.notChecked
        unchecked.leftOut = 1
        expect("Leave Out chosen before the people check", try await cloudRequests(people: unchecked), 0, reason: PrivacyLock.leftOut)

        let folder = SnapshotRenderer.milestoneFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? (["Part LOCK: the privacy lock counted in Anthropic requests, writing set to Anthropic, synthetic-transcript.json", ""] + lines)
            .joined(separator: "\n").appending("\n").write(to: folder.appending(path: "lock-writer-counts.txt"), atomically: true, encoding: .utf8)
    }

    func testNoRecordingAndALockedRecordingAreRefusedAtTheAdapterToo() throws {
        let request = ModelRequest(system: "S", user: "Words.", shape: .writing)
        XCTAssertThrowsError(try PrivacyLock.release(request, for: nil))
        var leftOut = PeopleFacts(checked: true, named: [Self.teacher()])
        leftOut.leftOut = 1
        XCTAssertThrowsError(try PrivacyLock.release(request, for: LockSubject(people: leftOut)))
        XCTAssertThrowsError(try PrivacyLock.release(request, for: LockSubject(people: PeopleFacts(checked: true, named: [Self.teacher(released: false)]))))
        // Not checked, or unnamed people: released like everyone, so the adapter lets the words through.
        XCTAssertEqual(try PrivacyLock.release(request, for: LockSubject()).user, "Words.")
        XCTAssertEqual(try PrivacyLock.release(request, for: LockSubject(people: PeopleFacts(checked: true, unnamedSeen: 4, unnamedHeard: 2))).user, "Words.")
        // A person marked no release who is neither seen nor heard (only named aloud) does not lock it.
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: PeopleFacts(checked: true, named: [
            .init(personID: UUID(), name: "Tomas Brill", heard: false, seen: false, released: false)]))).reason)
    }

    // MARK: The adapter's own check and the name tokens

    var openSubject: LockSubject {
        LockSubject(people: PeopleFacts(checked: true, named: [Self.teacher()]))
    }

    func testNamesSaidAloudGoAsTheyAre() throws {
        // Part LOCK: a name said aloud is nobody's privacy question (Ivan, 12 Oct), so nothing the tagger finds is replaced.
        let request = ModelRequest(system: "The school's teachers are Gabriel and Serenity.",
                                   user: "Asha Verlaine opened the evening. Then Priya Raman asked about the breath, and Priya laughed.", shape: .writing)
        let payload = try PrivacyLock.release(request, for: openSubject)
        XCTAssertEqual(payload.system, request.system)
        XCTAssertEqual(payload.user, request.user)
        XCTAssertEqual(payload.tokens.count, 0)
        XCTAssertEqual(payload.tokens.restore("[[NAME-99]] stays."), "[[NAME-99]] stays.", "a token the request never had names no one")
    }

    func testAMutedOrUnreleasedNameIsAlwaysReplacedAndAWithheldSpanRefused() throws {
        var subject = openSubject
        subject.people.mutedNames = ["Kestrel"]
        let request = ModelRequest(system: "S.", user: "the word kestrel and Kestrel again, never kestrels. Serenity taught.", shape: .writing)
        let payload = try PrivacyLock.release(request, for: subject)
        XCTAssertFalse(payload.user.range(of: #"\bkestrel\b"#, options: [.regularExpression, .caseInsensitive]) != nil, payload.user)
        XCTAssertTrue(payload.user.contains("kestrels"), "only the whole word")
        XCTAssertTrue(payload.user.contains("Serenity"), "a name said aloud goes as it is")
        XCTAssertEqual(payload.tokens.restore(payload.user), request.user, "each written form is put back as it was")
        // The tokenizer is planted to miss everything: the check, reading the text as it would be sent, refuses.
        XCTAssertThrowsError(try PrivacyLock.release(request, for: subject, tokenize: { texts, _ in (texts, NameTokens()) })) { error in
            let refusal = error as? LockRefusal
            XCTAssertNotNil(refusal, "a muted name the tokens missed is refused")
            XCTAssertFalse(refusal?.reason.lowercased().contains("kestrel") == true, "the refusal never carries the text")
        }

        var withPerson = openSubject
        withPerson.people.named.append(.init(personID: UUID(), name: "Tomas Brill", heard: false, seen: false, released: false))
        let named = try PrivacyLock.release(ModelRequest(system: "S.", user: "tomas brill waved, and Brill laughed.", shape: .writing), for: withPerson)
        XCTAssertFalse(named.user.lowercased().contains("tomas"), "a person marked no release is replaced: \(named.user)")
        XCTAssertFalse(named.user.lowercased().contains("brill"), "and each word of their name: \(named.user)")
        XCTAssertEqual(named.tokens.restore(named.user), "tomas brill waved, and Brill laughed.")
        XCTAssertThrowsError(try PrivacyLock.release(ModelRequest(system: "S.", user: "Tomas Brill waved.", shape: .writing), for: withPerson,
                                                     tokenize: { texts, _ in (texts, NameTokens()) }), "a no-release name the tokens missed is refused")

        var withheld = openSubject
        withheld.withheldSpans = ["my mother was ill that winter"]
        XCTAssertThrowsError(try PrivacyLock.release(ModelRequest(system: "S.", user: "She said my mother was ill that winter.", shape: .writing), for: withheld))
    }

    func testTheUnsafePathCannotBeWritten() throws {
        // A cloud client is never a LanguageModelClient, so it cannot be handed a ModelRequest.
        XCTAssertFalse((AnthropicClient(model: "claude-opus-5-5", key: nil) as Any) is any LanguageModelClient)
        XCTAssertTrue(WritingSetup.standardClient(.claudeAPI, WritingSetup()) is NoCloudClient)
        XCTAssertFalse((OpenAIClient(model: "gpt-test", key: nil) as Any) is any LanguageModelClient)
        XCTAssertTrue(WritingSetup.standardClient(.openAI, WritingSetup()) is NoCloudClient)
        XCTAssertTrue(WritingSetup.standardCloudClient(.openAI, WritingSetup()) is OpenAIClient)
        // CloudPayload is made in PrivacyLock.swift only.
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Prakriti")
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertGreaterThan(files.count, 50)
        for file in files where file.lastPathComponent != "PrivacyLock.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("CloudPayload("), "\(file.lastPathComponent) makes a CloudPayload")
        }
    }

    // MARK: The per-person switch

    func testThePersonReleaseIsReadFromTheStore() throws {
        let container = try PrakritiStore.makeContainer(at: nil)
        let context = ModelContext(container)
        let person = Person(id: Self.teacherID, name: "Asha Verlaine")
        context.insert(person)
        try context.save()
        XCTAssertFalse(person.noRelease, "everyone starts with a signed release on file (Ivan, 12 Oct)")
        XCTAssertTrue(person.named.released)
        let facts = PeopleFacts(checked: true, named: [Self.teacher()])
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: facts.withReleases(from: try context.fetch(FetchDescriptor<Person>())))).reason)
        person.noRelease = true
        try context.save()
        XCTAssertEqual(PrivacyLock.decide(LockSubject(people: facts.withReleases(from: try context.fetch(FetchDescriptor<Person>())))).reason, PrivacyLock.noRelease)
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: facts.withReleases(from: []))).reason, "someone not in the store keeps what the facts say")
    }

    // MARK: Check 1, the Keychain and log parts

    func testTheKeyIsReadFromTheTestKeychainAndNeverReachesTheLog() async throws {
        let fakeKey = "sk-test-m5a-\(UUID().uuidString)"
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(), log: AppLog(directory: nil))
        XCTAssertEqual(model.keyStore.service, KeyStore.testing.service)
        XCTAssertNotEqual(KeyStore.testing.service, KeyStore.claude.service, "tests never read Ivan's key")
        try? KeyStore.testing.remove()
        try KeyStore.testing.save(fakeKey)
        addTeardownBlock { try? KeyStore.testing.remove() }
        model.settings.provider = [.writing: .claudeAPI]
        XCTAssertEqual(model.runner.writingSetup().claudeKey, fakeKey, "read from the test Keychain service")

        // A whole write through the real Claude client, its HTTP answered on this Mac by StubProtocol.
        let logs = FileManager.default.temporaryDirectory.appending(path: "prakriti-provider-log-\(UUID().uuidString)", directoryHint: .isDirectory)
        addTeardownBlock { try? FileManager.default.removeItem(at: logs) }
        let log = AppLog(directory: logs)
        let input = try syntheticInput(people: PeopleFacts(checked: true, named: [Self.teacher()]))
        let answer = Self.passingAnswer(input)
        StubProtocol.seen = []
        StubProtocol.handler = { _, path, _ in
            (path == "/v1/messages" ? 200 : 404, Self.anthropicStream(answer))
        }
        defer { StubProtocol.handler = nil }
        var setup = WritingSetup()
        setup.providers = [.writing: .claudeAPI, .tagging: .claudeAPI, .summarizing: .claudeAPI]
        setup.maxAttempts = 1
        setup.claudeKey = KeyStore.testing.read()
        setup.makeCloudClient = { _, setup in
            var client = AnthropicClient(model: "claude-opus-5-5", key: setup.claudeKey)
            client.session = StubProtocol.session()
            return client
        }
        let outcome = try await Writer(setup: setup, log: log).write(input)
        XCTAssertNotNil(outcome.package, outcome.problem ?? "")
        let sent = StubProtocol.seen.filter { $0.path == "/v1/messages" }
        XCTAssertGreaterThanOrEqual(sent.count, 3, "writing, tags and summary, each through the lock")
        XCTAssertTrue(sent.contains { ($0.body?["system"] as? String ?? "").contains("Gabriel and Serenity") },
                      "since part LOCK the prompt's names go as they are (Ivan, 12 Oct)")
        XCTAssertEqual(sent.count, StubProtocol.seen.count, "nothing else was asked")
        for request in sent {
            let text = (request.body?["system"] as? String ?? "") + ((request.body?["messages"] as? [[String: Any]])?.first?["content"] as? String ?? "")
            XCTAssertFalse(text.contains(fakeKey), "the key is never in a body")
        }

        let logText = try FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: nil)
            .map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        XCTAssertFalse(logText.isEmpty, "the writer logged its steps")
        XCTAssertFalse(logText.contains(fakeKey), "the key never reaches the log")
    }

    func testARefusalIsLoggedWithoutTheTextOrTheKey() async throws {
        let fakeKey = "sk-test-m5a-log-\(UUID().uuidString)"
        let logs = FileManager.default.temporaryDirectory.appending(path: "prakriti-provider-log-\(UUID().uuidString)", directoryHint: .isDirectory)
        addTeardownBlock { try? FileManager.default.removeItem(at: logs) }
        let log = AppLog(directory: logs)
        let span = "a sentence only someone who has not agreed said"
        var client = AnthropicClient(model: "claude-opus-5-5", key: fakeKey)
        client.session = StubProtocol.session()
        StubProtocol.seen = []
        StubProtocol.handler = { _, _, _ in (200, Self.anthropicStream("{}")) }
        defer { StubProtocol.handler = nil }
        let locked = LockedCloudClient(inner: client, subject: LockSubject(people: PeopleFacts(checked: true, named: [Self.teacher()]),
                                                                           withheldSpans: [span]),
                                       onRefusal: { log.write("synthetic.json: \($0)") })
        do {
            _ = try await locked.complete(ModelRequest(system: "S.", user: "Before. \(span). After.", shape: .writing))
            XCTFail("the withheld span must be refused")
        } catch let failure as ModelFailure {
            XCTAssertEqual(failure.kind, .refused)
            XCTAssertFalse(failure.retryable)
        }
        XCTAssertEqual(StubProtocol.seen.count, 0, "nothing was sent")
        // And one that is sent: the key goes in the header only.
        _ = try? await locked.inner.send(PrivacyLock.keyCheck())
        XCTAssertEqual(StubProtocol.seen.count, 1)

        let logText = try FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: nil)
            .map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        XCTAssertTrue(logText.contains("privacy check found words of someone left out"), logText)
        XCTAssertFalse(logText.contains(span), "the log never holds the text")
        XCTAssertFalse(logText.contains(fakeKey), "the log never holds the key")
        XCTAssertFalse(logText.contains("sk-"), "nor anything shaped like one")
    }

    // MARK: Check 4: the hardware check

    func testTheHardwareVerdictForEachProfile() {
        let gb: UInt64 = 1_073_741_824
        let expected: [(UInt64, Bool)] = [(16, false), (32, false), (48, false), (64, true), (128, true)]
        var lines: [String] = []
        for (size, canRun) in expected {
            for ai in [nil, "Apple Intelligence is turned off in System Settings, so Apple's on-device model cannot be used."] as [String?] {
                let verdict = HardwareVerdict(HardwareProfile(chip: "Apple M2", memoryBytes: size * gb, appleIntelligenceUnavailable: ai))
                XCTAssertEqual(verdict.canRunWritingModel, canRun, "\(size) GB")
                XCTAssertEqual(verdict.headline, canRun ? "Apple M2, \(size) GB. This Mac can run the writing model."
                                                        : "Apple M2, \(size) GB. Writing a long recording needs a cloud key, or it waits.")
                XCTAssertEqual(verdict.suggestion == nil, canRun)
                XCTAssertEqual(verdict.appleIntelligence, ai ?? "Apple Intelligence is on, so Apple on-device can make tags and summaries.")
                for line in [verdict.headline, verdict.suggestion ?? "", verdict.appleIntelligence] {
                    XCTAssertFalse(line.contains("\u{2014}") || line.contains("\u{2013}"))
                }
                lines.append("\(size) GB, Apple Intelligence \(ai == nil ? "on" : "off"): \(verdict.headline) \(verdict.suggestion ?? "") \(verdict.appleIntelligence)")
            }
        }
        // This Mac, read for real.
        let here = HardwareProfile.current()
        XCTAssertEqual(here.chip, "Apple M5 Pro")
        XCTAssertEqual(here.memoryBytes, 68_719_476_736)
        XCTAssertEqual(HardwareVerdict(here).headline, "Apple M5 Pro, 64 GB. This Mac can run the writing model.")
        lines.append("This Mac: \(HardwareVerdict(here).headline) \(HardwareVerdict(here).appleIntelligence)")
        let folder = SnapshotRenderer.milestoneFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? lines.joined(separator: "\n").appending("\n").write(to: folder.appending(path: "hardware-check.txt"), atomically: true, encoding: .utf8)
    }
}

// MARK: - v2 part M5b: Anthropic and OpenAI (PLAN M5, checks 1 and 2 again)

extension ProviderTests {
    /// An Anthropic streamed answer, as server-sent events (claude-api reference, read 12 Oct).
    static func anthropicStream(_ text: String, stop: String? = "end_turn", model: String = "claude-sonnet-5-5",
                                input: Int = 1_000, output: Int = 300, error: String? = nil) -> String {
        func event(_ name: String, _ object: [String: Any]) -> String {
            "event: \(name)\ndata: " + String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self) + "\n\n"
        }
        var stream = event("message_start", ["type": "message_start", "message": ["id": "msg_1", "type": "message", "model": model, "usage": ["input_tokens": input, "output_tokens": 1]]])
        stream += event("ping", ["type": "ping"])
        stream += event("content_block_start", ["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": ""]])
        let half = text.index(text.startIndex, offsetBy: text.count / 2)
        for piece in [String(text[..<half]), String(text[half...])] where !piece.isEmpty {
            stream += event("content_block_delta", ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": piece]])
        }
        stream += event("content_block_stop", ["type": "content_block_stop", "index": 0])
        if let error { return stream + event("error", ["type": "error", "error": ["type": error, "message": "Overloaded"]]) }
        if let stop {
            stream += event("message_delta", ["type": "message_delta", "delta": ["stop_reason": stop], "usage": ["output_tokens": output]])
        }
        return stream + event("message_stop", ["type": "message_stop"])
    }

    /// An OpenAI Responses streamed answer (developers.openai.com, read 12 Oct).
    static func openAIStream(_ text: String, refusal: String? = nil, incomplete: String? = nil, failed: Bool = false, completed: Bool = true) -> String {
        func event(_ object: [String: Any]) -> String {
            "event: \(object["type"] as? String ?? "")\ndata: " + String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self) + "\n\n"
        }
        var stream = event(["type": "response.created", "response": ["id": "resp_1", "status": "in_progress"]])
        let half = text.index(text.startIndex, offsetBy: text.count / 2)
        for piece in [String(text[..<half]), String(text[half...])] where !piece.isEmpty {
            stream += event(["type": "response.output_text.delta", "item_id": "msg_1", "output_index": 0, "content_index": 0, "delta": piece])
        }
        if let refusal { stream += event(["type": "response.refusal.delta", "item_id": "msg_1", "output_index": 0, "content_index": 0, "delta": refusal]) }
        if let incomplete {
            return stream + event(["type": "response.incomplete", "response": ["id": "resp_1", "status": "incomplete", "incomplete_details": ["reason": incomplete],
                                                                                 "usage": ["input_tokens": 900, "output_tokens": 32_000]]])
        }
        if failed { return stream + event(["type": "response.failed", "response": ["id": "resp_1", "status": "failed", "error": ["code": "server_error", "message": "Failed."]]]) }
        if completed {
            stream += event(["type": "response.completed", "response": ["id": "resp_1", "status": "completed", "model": "gpt-test",
                                                                          "usage": ["input_tokens": 900, "output_tokens": 250, "output_tokens_details": ["reasoning_tokens": 40]]]])
        }
        return stream
    }

    static func payload(_ shape: ModelRequest.Shape = .writing) throws -> CloudPayload {
        let subject = LockSubject(people: PeopleFacts(checked: true, named: [teacher()]))
        return try PrivacyLock.release(ModelRequest(system: "You write JSON.", user: "Asha Verlaine spoke about the breath.", shape: shape), for: subject)
    }

    // MARK: Check 1: the request shapes, through the real clients, answered on this Mac

    func testTheAnthropicRequestHasTheCurrentShape() async throws {
        StubProtocol.seen = []
        StubProtocol.headers = []
        StubProtocol.handler = { _, _, _ in (200, Self.anthropicStream("{\"ready\": true}")) }
        defer { StubProtocol.handler = nil }
        var client = AnthropicClient(model: "claude-sonnet-5-5", key: "sk-test-shape")
        client.session = StubProtocol.session()
        let reply = try await client.send(try Self.payload(.writing))
        XCTAssertEqual(reply.text, "{\"ready\": true}", "the streamed pieces are joined in order")
        XCTAssertEqual(reply.promptTokens, 1_000)
        XCTAssertEqual(reply.completionTokens, 300)
        XCTAssertEqual(try XCTUnwrap(reply.costUSD), 0.005, accuracy: 0.000_001, "1,000 read at $2 and 300 written at $10 per million")
        let body = try XCTUnwrap(StubProtocol.seen.first?.body)
        XCTAssertEqual(StubProtocol.seen.first?.path, "/v1/messages")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertNil(body["thinking"], "no thinking key: a disabled or budgeted setting is a 400 on current models (warning 34)")
        XCTAssertNil(body["temperature"])
        XCTAssertEqual(body["max_tokens"] as? Int, 64_000)
        XCTAssertEqual((body["output_config"] as? [String: Any])?["effort"] as? String, "high", "writing thinks hard")
        XCTAssertEqual(body["fallbacks"] as? String, "default")
        let headers = try XCTUnwrap(StubProtocol.headers.first)
        XCTAssertEqual(headers["anthropic-beta"], "server-side-fallback-2026-07-01")
        XCTAssertEqual(headers["anthropic-version"], "2023-06-01")
        XCTAssertEqual(headers["x-api-key"], "sk-test-shape", "the key goes in its header")
        XCTAssertFalse(String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self).contains("sk-test-shape"), "and never in the body")

        // Tags think lightly; a model the reference does not list for fallbacks gets neither the field nor the header.
        StubProtocol.seen = []
        StubProtocol.headers = []
        var haiku = AnthropicClient(model: "claude-haiku-5-5", key: "sk-test-shape")
        haiku.session = StubProtocol.session()
        _ = try await haiku.send(try Self.payload(.tags))
        let tagsBody = try XCTUnwrap(StubProtocol.seen.first?.body)
        XCTAssertEqual((tagsBody["output_config"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertNil(tagsBody["fallbacks"])
        XCTAssertNil(StubProtocol.headers.first?["anthropic-beta"])
        for model in ["claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5", "claude-fable-5-1"] { XCTAssertTrue(AnthropicClient.usesFallbacks(model)) }
        XCTAssertEqual(AnthropicClient.effort(for: .summary), "low")
        XCTAssertEqual(AnthropicClient.effort(for: .check), "low")
    }

    func testTheOpenAIRequestTargetsResponsesAndStreams() async throws {
        StubProtocol.seen = []
        StubProtocol.headers = []
        StubProtocol.handler = { _, _, _ in (200, Self.openAIStream("{\"ready\": true}")) }
        defer { StubProtocol.handler = nil }
        var client = OpenAIClient(model: "gpt-test", key: "sk-test-openai")
        client.session = StubProtocol.session()
        let reply = try await client.send(try Self.payload(.writing))
        XCTAssertEqual(reply.text, "{\"ready\": true}")
        XCTAssertEqual(reply.promptTokens, 900)
        XCTAssertEqual(reply.completionTokens, 250)
        XCTAssertEqual(reply.reasoningTokens, 40)
        XCTAssertEqual(StubProtocol.seen.first?.method, "POST")
        XCTAssertEqual(StubProtocol.seen.first?.path, "/v1/responses")
        let body = try XCTUnwrap(StubProtocol.seen.first?.body)
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["store"] as? Bool, false, "nothing kept on OpenAI's side")
        XCTAssertEqual(body["model"] as? String, "gpt-test")
        XCTAssertEqual(body["instructions"] as? String, "You write JSON.")
        XCTAssertEqual(body["input"] as? String, "Asha Verlaine spoke about the breath.")
        XCTAssertEqual(body["max_output_tokens"] as? Int, OpenAIClient.maxOutputTokens)
        XCTAssertNil(body["messages"])
        XCTAssertEqual(StubProtocol.headers.first?["Authorization"], "Bearer sk-test-openai")
    }

    // MARK: Check 1: a refusal, a cut-off answer and a refused key are failures

    func testStreamedRefusalsAndCutOffAnswersAreFailures() async throws {
        defer { StubProtocol.handler = nil }
        func anthropic(_ stream: String, status: Int = 200) async -> ModelFailure? {
            let error: [String: Any] = ["type": "error", "error": ["type": "authentication_error", "message": "invalid x-api-key"]]
            StubProtocol.handler = { _, _, _ in status == 200 ? (200, stream as Any) : (status, error as Any) }
            var client = AnthropicClient(model: "claude-opus-5-5", key: "sk-test")
            client.session = StubProtocol.session()
            do { _ = try await client.send(try Self.payload()); return nil } catch { return error as? ModelFailure }
        }
        let refused = await anthropic(Self.anthropicStream("I can't", stop: "refusal"))
        XCTAssertEqual(refused?.kind, .refused)
        XCTAssertEqual(refused?.retryable, false)
        let got1 = await anthropic(Self.anthropicStream("{\"titles\": [", stop: "max_tokens"))
        XCTAssertEqual(got1?.kind, .truncated)
        let got2 = await anthropic(Self.anthropicStream("{}", stop: nil))
        XCTAssertEqual(got2?.kind, .server, "a stream that ends without a stop reason")
        let got3 = await anthropic(Self.anthropicStream("{}", error: "overloaded_error"))
        XCTAssertEqual(got3?.reason, "Anthropic is busy. Try again later.")
        let got4 = await anthropic(Self.anthropicStream("   "))
        XCTAssertEqual(got4?.kind, .empty)
        let rejected = await anthropic("", status: 401)
        XCTAssertEqual(rejected?.kind, .keyRejected)
        XCTAssertEqual(rejected?.reason, "Anthropic did not accept this key. Check it and save it again.")
        XCTAssertFalse(rejected?.detail?.contains("sk-test") == true)

        func openAI(_ stream: String) async -> ModelFailure? {
            StubProtocol.handler = { _, _, _ in (200, stream) }
            var client = OpenAIClient(model: "gpt-test", key: "sk-test")
            client.session = StubProtocol.session()
            do { _ = try await client.send(try Self.payload()); return nil } catch { return error as? ModelFailure }
        }
        let got5 = await openAI(Self.openAIStream("", refusal: "I can't help with that."))
        XCTAssertEqual(got5?.kind, .refused)
        let got6 = await openAI(Self.openAIStream("{\"titles\"", incomplete: "max_output_tokens"))
        XCTAssertEqual(got6?.kind, .truncated)
        let got7 = await openAI(Self.openAIStream("{}", incomplete: "content_filter"))
        XCTAssertEqual(got7?.kind, .refused)
        let got8 = await openAI(Self.openAIStream("{}", failed: true))
        XCTAssertEqual(got8?.kind, .server)
        let got9 = await openAI(Self.openAIStream("{}", completed: false))
        XCTAssertEqual(got9?.kind, .server, "no response.completed")
        let got10 = await openAI(Self.openAIStream(""))
        XCTAssertEqual(got10?.kind, .empty)
    }

    // MARK: The model lists: only models this request shape works on

    func testTheModelListsKeepOnlyModelsThatWork() async throws {
        defer { StubProtocol.handler = nil }
        StubProtocol.seen = []
        StubProtocol.handler = { _, path, _ in
            guard path == "/v1/models" else { return (404, [:]) }
            let pages = StubProtocol.seen.count
            if pages == 1 {
                return (200, ["data": [["id": "claude-sonnet-5-5", "display_name": "Claude Sonnet 5.5", "capabilities": ["effort": ["supported": true]]],
                                       ["id": "claude-haiku-4-5", "display_name": "Claude Haiku 4.5", "capabilities": ["effort": ["supported": false]]]],
                              "has_more": true, "last_id": "claude-haiku-4-5"])
            }
            return (200, ["data": [["id": "claude-opus-5-5", "display_name": "Claude Opus 5.5", "capabilities": ["effort": ["supported": true]]],
                                   ["id": "claude-sonnet-4-5", "display_name": "Claude Sonnet 4.5", "capabilities": ["effort": ["supported": false]]]],
                          "has_more": false])
        }
        let anthropic = try await AnthropicClient.models(key: "sk-test", session: StubProtocol.session())
        XCTAssertEqual(anthropic.map(\.id), ["claude-sonnet-5-5", "claude-opus-5-5"], "two pages read, models without effort left out")
        XCTAssertEqual(anthropic.first?.name, "Claude Sonnet 5.5")
        XCTAssertEqual(StubProtocol.seen.count, 2)
        XCTAssertTrue(StubProtocol.seen.allSatisfy { $0.method == "GET" })

        XCTAssertEqual(OpenAIClient.filter(["gpt-5.5", "text-embedding-3-large", "gpt-4o-realtime-preview", "tts-1", "o4-mini", "gpt-image-1",
                                            "omni-moderation-latest", "gpt-5.6", "whisper-1", "gpt-4o-transcribe", "dall-e-3", "gpt-5.3-codex"]),
                       ["o4-mini", "gpt-5.6", "gpt-5.5"])
        StubProtocol.handler = { _, _, _ in (200, ["data": [["id": "gpt-5.5"], ["id": "tts-1"]]]) }
        let listed = try await OpenAIClient.models(key: "sk-test", session: StubProtocol.session())
        XCTAssertEqual(listed.map(\.id), ["gpt-5.5"])
        StubProtocol.handler = { _, _, _ in (401, ["error": ["message": "Incorrect API key provided"]]) }
        do {
            _ = try await OpenAIClient.models(key: "sk-test", session: StubProtocol.session())
            XCTFail("a refused key is a failure")
        } catch let failure as ModelFailure {
            XCTAssertEqual(failure.kind, .keyRejected)
            XCTAssertEqual(failure.reason, "OpenAI did not accept this key. Check it and save it again.")
        }
    }

    // MARK: Check 1: both keys from the test Keychain, never in the log

    func testBothKeysComeFromTheTestKeychainAndNeverReachTheLog() async throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(), log: AppLog(directory: nil))
        XCTAssertEqual(model.keyStore(for: .claudeAPI)?.service, "studio.therowan.prakriti.app.tests.claude-api")
        XCTAssertEqual(model.keyStore(for: .openAI)?.service, "studio.therowan.prakriti.app.tests.openai-api")
        XCTAssertEqual(KeyStore.openAI.service, "studio.therowan.prakriti.app.openai-api")
        XCTAssertNil(model.keyStore(for: .lmStudio))
        let anthropicKey = "sk-ant-test-m5b-\(UUID().uuidString)"
        let openAIKey = "sk-proj-test-m5b-\(UUID().uuidString)"
        for store in [KeyStore.testing, KeyStore.testingOpenAI] { try? store.remove() }
        addTeardownBlock { for store in [KeyStore.testing, KeyStore.testingOpenAI] { try? store.remove() } }
        XCTAssertNil(model.saveKey(anthropicKey, for: .claudeAPI))
        XCTAssertNil(model.saveKey(openAIKey, for: .openAI))
        XCTAssertEqual(model.keysAdded, [.claudeAPI, .openAI])
        model.settings.provider = [.writing: .openAI, .tagging: .claudeAPI, .summarizing: .lmStudio]
        model.settings.openAIModel = "gpt-test"
        let setup = model.runner.writingSetup()
        XCTAssertEqual(setup.openAIKey, openAIKey)
        XCTAssertEqual(setup.claudeKey, anthropicKey)
        model.settings.provider = [.writing: .lmStudio, .tagging: .lmStudio, .summarizing: .lmStudio]
        XCTAssertNil(model.runner.writingSetup().openAIKey, "read only when a task uses it")
        XCTAssertNil(model.runner.writingSetup().claudeKey)

        // A whole write: writing through OpenAI, tags and summary through Anthropic, every request through the lock.
        let logs = FileManager.default.temporaryDirectory.appending(path: "prakriti-provider-log-\(UUID().uuidString)", directoryHint: .isDirectory)
        addTeardownBlock { try? FileManager.default.removeItem(at: logs) }
        let log = AppLog(directory: logs)
        let input = try syntheticInput(people: PeopleFacts(checked: true, named: [Self.teacher()]))
        let answer = Self.passingAnswer(input)
        StubProtocol.seen = []
        StubProtocol.headers = []
        StubProtocol.handler = { _, path, _ in
            switch path {
            case "/v1/responses": (200, Self.openAIStream(answer))
            case "/v1/messages": (200, Self.anthropicStream("{\"tags\": [\"breath\", \"question\", \"practice\"]}"))
            default: (404, [:])
            }
        }
        defer { StubProtocol.handler = nil }
        var writing = setup
        writing.maxAttempts = 1
        writing.makeCloudClient = { provider, setup in
            if provider == .openAI {
                var client = OpenAIClient(model: setup.openAIModel, key: setup.openAIKey)
                client.session = StubProtocol.session()
                return client
            }
            var client = AnthropicClient(model: setup.claudeModel, key: setup.claudeKey)
            client.session = StubProtocol.session()
            return client
        }
        writing.makeClient = { provider, _ in ScriptedClient(provider, limit: 200_000, replies: [.success("{\"summary\": \"A talk about a question.\"}")]) }
        let outcome = try await Writer(setup: writing, log: log).write(input)
        XCTAssertNotNil(outcome.package, outcome.problem ?? "")
        XCTAssertEqual(outcome.package?.writingProvider, ModelProvider.openAI.rawValue)
        XCTAssertEqual(StubProtocol.seen.filter { $0.path == "/v1/responses" }.count, 1)
        XCTAssertEqual(StubProtocol.seen.filter { $0.path == "/v1/messages" }.count, 1)
        for request in StubProtocol.seen {
            let text = String(decoding: try JSONSerialization.data(withJSONObject: request.body ?? [:]), as: UTF8.self)
            XCTAssertFalse(text.contains(openAIKey) || text.contains(anthropicKey), "no key in any body")
        }
        let logText = try FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: nil)
            .map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        XCTAssertTrue(logText.contains("(OpenAI)"), logText)
        XCTAssertFalse(logText.contains(openAIKey) || logText.contains(anthropicKey), "no key in the log")
        XCTAssertFalse(logText.contains("sk-"), "nor anything shaped like one")

        model.removeKey(for: .openAI)
        model.removeKey(for: .claudeAPI)
        XCTAssertEqual(model.keysAdded, [])
        XCTAssertNil(KeyStore.testingOpenAI.read())
    }

    // MARK: Check 2 again: the lock in front of both providers, counted in HTTP requests

    func testTheLockCountsRequestsToBothProviders() async throws {
        defer { StubProtocol.handler = nil }
        for provider in ModelProvider.cloud {
            func requests(kind: RecordingKind = .talk, people: PeopleFacts) async throws -> Int {
                let input = try syntheticInput(kind: kind, people: people)
                let answer = Self.passingAnswer(input)
                StubProtocol.seen = []
                StubProtocol.handler = { _, path, _ in path == "/v1/responses" ? (200, Self.openAIStream(answer)) : (200, Self.anthropicStream(answer)) }
                var setup = WritingSetup()
                setup.providers = [.writing: provider, .tagging: .lmStudio, .summarizing: .lmStudio]
                setup.maxAttempts = 1
                setup.claudeKey = "sk-test-lock"
                setup.openAIKey = "sk-test-lock"
                setup.openAIModel = "gpt-test"
                setup.makeClient = { _, _ in ScriptedClient(.lmStudio, limit: 200_000, replies: [.success(answer)]) }
                setup.makeCloudClient = { provider, setup in
                    var client: any CloudModelClient
                    if provider == .openAI {
                        var made = OpenAIClient(model: setup.openAIModel, key: setup.openAIKey)
                        made.session = StubProtocol.session()
                        client = made
                    } else {
                        var made = AnthropicClient(model: setup.claudeModel, key: setup.claudeKey)
                        made.session = StubProtocol.session()
                        client = made
                    }
                    return client
                }
                _ = try await Writer(setup: setup, log: nil).write(input)
                return StubProtocol.seen.count
            }
            let checked = PeopleFacts(checked: true, named: [Self.teacher()])
            var leftOut = checked
            leftOut.leftOut = 1
            let counts = [
                ("a class", try await requests(kind: .lesson, people: checked), 1),
                ("people not checked", try await requests(people: .notChecked), 1),
                ("an unnamed person present", try await requests(people: PeopleFacts(checked: true, named: [Self.teacher()], unnamedSeen: 1)), 1),
                ("an unnamed voice", try await requests(people: PeopleFacts(checked: true, named: [Self.teacher()], unnamedHeard: 1)), 1),
                ("checked, one released speaker", try await requests(people: checked), 1),
                ("someone set to Leave Out", try await requests(kind: .lesson, people: leftOut), 0),
                ("a speaker marked no release", try await requests(people: PeopleFacts(checked: true, named: [Self.teacher(released: false)])), 0),
            ]
            var lines: [String] = []
            for (label, measured, expected) in counts {
                XCTAssertEqual(measured, expected, "\(provider.title): \(label)")
                lines.append("\(provider.title), \(label): \(measured) requests (expected \(expected))")
            }
            let folder = SnapshotRenderer.milestoneFolder()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "lock-counts.txt")
            let before = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let kept = before.split(separator: "\n").filter { !$0.hasPrefix(provider.title + ",") }.joined(separator: "\n")
            try? ((kept.isEmpty ? "" : kept + "\n") + lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
