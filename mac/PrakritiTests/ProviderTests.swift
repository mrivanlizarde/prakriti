import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M5a (docs/v2/PLAN.md M5, checks 1 (Keychain and log), 2 and 4): the privacy lock counted in
/// cloud requests, the cloud adapter's own check, the name tokens, the per-person switch, the key and the
/// log, and the hardware check. No request leaves the Mac: cloud clients are scripted or answered by
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
    static func teacher(consent: Bool) -> PeopleFacts.Named {
        .init(personID: teacherID, name: "Asha Verlaine", heard: true, seen: true, cloudConsent: consent)
    }

    // MARK: Check 2: the lock, counted in cloud requests

    func testTheLockCountsCloudRequests() async throws {
        func cloudRequests(kind: RecordingKind = .talk, people: PeopleFacts) async throws -> (Int, Writer.Outcome) {
            let input = try syntheticInput(kind: kind, people: people)
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
        let checkedTeacher = PeopleFacts(checked: true, named: [Self.teacher(consent: true)])

        let (forClass, _) = try await cloudRequests(kind: .lesson, people: checkedTeacher)
        XCTAssertEqual(forClass, 0, "a class")
        let (notChecked, unchecked) = try await cloudRequests(people: .notChecked)
        XCTAssertEqual(notChecked, 0, "people not checked")
        XCTAssertEqual(unchecked.lockReason, PrivacyLock.notChecked)
        let (notAgreed, refused) = try await cloudRequests(people: PeopleFacts(checked: true, named: [Self.teacher(consent: false)]))
        XCTAssertEqual(notAgreed, 0, "a person without cloud consent speaking")
        XCTAssertEqual(refused.lockReason, PrivacyLock.notAgreed)
        let (withUnnamed, unnamed) = try await cloudRequests(people: PeopleFacts(checked: true, named: [Self.teacher(consent: true)], unnamedSeen: 1))
        XCTAssertEqual(withUnnamed, 0, "an unnamed person present")
        XCTAssertEqual(unnamed.lockReason, PrivacyLock.unnamed)
        let (heardUnnamed, _) = try await cloudRequests(people: PeopleFacts(checked: true, named: [Self.teacher(consent: true)], unnamedHeard: 1))
        XCTAssertEqual(heardUnnamed, 0, "an unnamed voice")
        let (open, written) = try await cloudRequests(people: checkedTeacher)
        XCTAssertEqual(open, 1, "the synthetic talk, checked, one consenting speaker")
        XCTAssertNil(written.lockReason)
        XCTAssertEqual(written.package?.writingProvider, ModelProvider.claudeAPI.rawValue, written.problem ?? "")
    }

    func testNoRecordingAndALockedRecordingAreRefusedAtTheAdapterToo() {
        let request = ModelRequest(system: "S", user: "Words.", shape: .writing)
        XCTAssertThrowsError(try PrivacyLock.release(request, for: nil))
        XCTAssertThrowsError(try PrivacyLock.release(request, for: LockSubject(kind: .lesson, mentionsSerenity: false,
                                                                               people: PeopleFacts(checked: true, named: [Self.teacher(consent: true)]))))
        XCTAssertThrowsError(try PrivacyLock.release(request, for: LockSubject(kind: .talk, mentionsSerenity: false)))
    }

    // MARK: The adapter's own check and the name tokens

    var openSubject: LockSubject {
        LockSubject(kind: .talk, mentionsSerenity: false, people: PeopleFacts(checked: true, named: [Self.teacher(consent: true)]))
    }

    func testNamesAreReplacedAndPutBackAndAPlantedNameIsRefused() throws {
        // Apple's tagger finds Gabriel here but not Serenity (measured 12 Oct): she is replaced because the
        // lock always replaces the teacher who has not agreed, not because the tagger found her.
        XCTAssertEqual(NameTokens.findNames(in: "The school's teachers are Gabriel and Serenity."), ["Gabriel"])
        let request = ModelRequest(system: "The school's teachers are Gabriel and Serenity.",
                                   user: "Asha Verlaine opened the evening. Then Priya Raman asked about the breath, and Priya laughed.", shape: .writing)
        let payload = try PrivacyLock.release(request, for: openSubject)
        let sent = payload.system + " " + payload.user
        XCTAssertTrue(sent.contains("Asha Verlaine"), "a consenting named person's name goes as it is")
        for name in ["Priya", "Raman", "Serenity", "Gabriel"] { XCTAssertFalse(sent.contains(name), "\(name) was replaced: \(sent)") }
        XCTAssertGreaterThanOrEqual(payload.tokens.count, 3)
        // The answer comes back with the tokens; each is put back exactly as written.
        XCTAssertEqual(payload.tokens.restore(payload.user), request.user)
        XCTAssertEqual(payload.tokens.restore(payload.system), request.system)
        XCTAssertEqual(payload.tokens.restore("[[NAME-99]] stays."), "[[NAME-99]] stays.", "a token the request never had names no one")

        // The tokenizer is planted to miss everything: the check, reading the text as it would be sent, refuses.
        XCTAssertThrowsError(try PrivacyLock.release(request, for: openSubject, tokenize: { texts, _, _ in (texts, NameTokens()) })) { error in
            let refusal = error as? LockRefusal
            XCTAssertNotNil(refusal)
            XCTAssertFalse(refusal?.reason.contains("Priya") == true, "the refusal never carries the text")
        }
    }

    func testAMutedNameIsAlwaysReplacedAndAWithheldSpanRefused() throws {
        var subject = openSubject
        subject.people.mutedNames = ["Kestrel"]
        let request = ModelRequest(system: "S.", user: "the word kestrel and Kestrel again, never kestrels.", shape: .writing)
        let payload = try PrivacyLock.release(request, for: subject)
        XCTAssertFalse(payload.user.range(of: #"\bkestrel\b"#, options: [.regularExpression, .caseInsensitive]) != nil, payload.user)
        XCTAssertTrue(payload.user.contains("kestrels"), "only the whole word")
        XCTAssertEqual(payload.tokens.restore(payload.user), request.user, "each written form is put back as it was")
        XCTAssertThrowsError(try PrivacyLock.release(request, for: subject, tokenize: { texts, _, _ in (texts, NameTokens()) }),
                             "a muted name the tokens missed is refused")
        XCTAssertThrowsError(try PrivacyLock.release(ModelRequest(system: "S.", user: "Serenity taught.", shape: .writing), for: openSubject,
                                                     tokenize: { texts, _, _ in (texts, NameTokens()) }), "the teacher who has not agreed, missed, is refused")
        var withPerson = openSubject
        withPerson.people.named.append(.init(personID: UUID(), name: "Tomas Brill", heard: false, seen: true, cloudConsent: false))
        let named = try PrivacyLock.release(ModelRequest(system: "S.", user: "tomas brill waved.", shape: .writing), for: withPerson)
        XCTAssertFalse(named.user.lowercased().contains("tomas"), "a named person who has not agreed is replaced even when the tagger misses them: \(named.user)")

        var withheld = openSubject
        withheld.withheldSpans = ["my mother was ill that winter"]
        XCTAssertThrowsError(try PrivacyLock.release(ModelRequest(system: "S.", user: "She said my mother was ill that winter.", shape: .writing), for: withheld))
    }

    func testTheUnsafePathCannotBeWritten() throws {
        // A cloud client is never a LanguageModelClient, so it cannot be handed a ModelRequest.
        XCTAssertFalse((ClaudeClient(model: "claude-opus-5-5", key: nil) as Any) is any LanguageModelClient)
        XCTAssertTrue(WritingSetup.standardClient(.claudeAPI, WritingSetup()) is NoCloudClient)
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

    func testThePersonSwitchIsReadFromTheStore() throws {
        let container = try PrakritiStore.makeContainer(at: nil)
        let context = ModelContext(container)
        let person = Person(id: Self.teacherID, name: "Asha Verlaine")
        context.insert(person)
        try context.save()
        XCTAssertFalse(person.mayReadInCloud, "off by default")
        let facts = PeopleFacts(checked: true, named: [Self.teacher(consent: true)])
        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(PrivacyLock.decide(LockSubject(kind: .talk, mentionsSerenity: false, people: facts.withConsent(from: people))).reason, PrivacyLock.notAgreed)
        person.mayReadInCloud = true
        try context.save()
        XCTAssertNil(PrivacyLock.decide(LockSubject(kind: .talk, mentionsSerenity: false, people: facts.withConsent(from: try context.fetch(FetchDescriptor<Person>())))).reason)
        XCTAssertEqual(PrivacyLock.decide(LockSubject(kind: .talk, mentionsSerenity: false, people: facts.withConsent(from: []))).reason, PrivacyLock.notAgreed,
                       "someone not in the store counts as not agreed")
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
        let input = try syntheticInput(people: PeopleFacts(checked: true, named: [Self.teacher(consent: true)]))
        let answer = Self.passingAnswer(input)
        StubProtocol.seen = []
        StubProtocol.handler = { _, path, _ in
            (path == "/v1/messages" ? 200 : 404, ["stop_reason": "end_turn", "content": [["type": "text", "text": answer]],
                                                  "usage": ["input_tokens": 1_000, "output_tokens": 300]])
        }
        defer { StubProtocol.handler = nil }
        var setup = WritingSetup()
        setup.providers = [.writing: .claudeAPI, .tagging: .claudeAPI, .summarizing: .claudeAPI]
        setup.maxAttempts = 1
        setup.claudeKey = KeyStore.testing.read()
        setup.makeCloudClient = { _, setup in
            var client = ClaudeClient(model: "claude-opus-5-5", key: setup.claudeKey)
            client.session = StubProtocol.session()
            return client
        }
        let outcome = try await Writer(setup: setup, log: log).write(input)
        XCTAssertNotNil(outcome.package, outcome.problem ?? "")
        let sent = StubProtocol.seen.filter { $0.path == "/v1/messages" }
        XCTAssertGreaterThanOrEqual(sent.count, 3, "writing, tags and summary, each through the lock")
        XCTAssertEqual(sent.count, StubProtocol.seen.count, "nothing else was asked")
        for request in sent {
            let text = (request.body?["system"] as? String ?? "") + ((request.body?["messages"] as? [[String: Any]])?.first?["content"] as? String ?? "")
            XCTAssertFalse(text.contains("Serenity"), "the prompt's names are replaced before sending")
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
        var client = ClaudeClient(model: "claude-opus-5-5", key: fakeKey)
        client.session = StubProtocol.session()
        StubProtocol.seen = []
        StubProtocol.handler = { _, _, _ in (200, ["stop_reason": "end_turn", "content": [["type": "text", "text": "{}"]]]) }
        defer { StubProtocol.handler = nil }
        let locked = LockedCloudClient(inner: client, subject: LockSubject(kind: .talk, mentionsSerenity: false,
                                                                           people: PeopleFacts(checked: true, named: [Self.teacher(consent: true)]),
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
        XCTAssertTrue(logText.contains("privacy check found words of someone who has not agreed"), logText)
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
