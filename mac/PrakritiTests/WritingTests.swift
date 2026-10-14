import Foundation
import SwiftData
import Synchronization
import XCTest
@testable import Prakriti

/// A model client that answers from a script and remembers every request, so a test can see which
/// provider the privacy lock let through and what was sent, without calling any model.
final class ScriptedClient: LanguageModelClient {
    let provider: ModelProvider
    let limit: Int
    private let state: Mutex<(replies: [Result<String, ModelFailure>], requests: [ModelRequest])>

    init(_ provider: ModelProvider, limit: Int = ModelSettings.contextLength, replies: [Result<String, ModelFailure>]) {
        self.provider = provider
        self.limit = limit
        self.state = Mutex((replies, []))
    }

    var displayName: String { "\(provider.title) (scripted)" }
    var requests: [ModelRequest] { state.withLock { $0.requests } }

    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) {
        (ModelSettings.estimatedTokens(request.system + request.user) + (provider == .appleOnDevice ? 100 : request.maxTokens), limit)
    }

    func complete(_ request: ModelRequest) async throws -> ModelReply {
        let next: Result<String, ModelFailure> = state.withLock { s in
            s.requests.append(request)
            return s.replies.isEmpty ? .failure(ModelFailure(kind: .server, reason: "The script ran out.")) : s.replies.removeFirst()
        }
        switch next {
        case .success(let text): return ModelReply(text: text, finishReason: "stop", promptTokens: 100, completionTokens: 50, reasoningTokens: 20, seconds: 0.01)
        case .failure(let failure): throw failure
        }
    }

    func check() async -> ProviderCheck { ProviderCheck(state: .ok, line: "Scripted.", at: Date()) }
}

/// The same script as a cloud client (v2 part M5a): it receives only what the privacy lock released,
/// recorded as the request it carried, so a test sees the tokens exactly as they would have gone out.
extension ScriptedClient: CloudModelClient {
    var contextLimit: Int { limit }
    func send(_ payload: CloudPayload) async throws -> ModelReply {
        try await complete(ModelRequest(system: payload.system, user: payload.user, shape: payload.shape, maxTokens: payload.maxTokens))
    }
}

/// Answers LM Studio's REST API and chat completions from a handler, and records every request.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((String, String, [String: Any]?) -> (Int, Any))?
    nonisolated(unsafe) static var seen: [(method: String, path: String, body: [String: Any]?)] = []
    /// Every request's headers, in the order seen (v2 part M5b: where the key goes).
    nonisolated(unsafe) static var headers: [[String: String]] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 65_536)
            var collected = Data()
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                collected.append(buffer, count: n)
            }
            stream.close()
            data = collected
        }
        let body = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
        let method = request.httpMethod ?? "GET", path = request.url?.path ?? ""
        Self.seen.append((method, path, body))
        Self.headers.append(request.allHTTPHeaderFields ?? [:])
        let (status, object) = Self.handler?(method, path, body) ?? (500, [String: Any]())
        // A String answer is sent as it is: a streamed answer (server-sent events, v2 part M5b).
        let streamed = object as? String
        let payload = streamed.map { Data($0.utf8) } ?? (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": streamed == nil ? "application/json" : "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// Milestone 6: the writer's checks, the LM Studio settings from docs/LOCAL-MODEL.md, retries, the
/// privacy lock, the Keychain, Apple on-device on a short input, and what the files and Approve hold.
/// The text here is made up for the tests; no recording's words are in the repository.
@MainActor
final class WritingTests: XCTestCase {
    /// A made-up talk of seven minutes, one cue per sentence.
    static let cues: [TranscriptFiles.Cue] = [
        .init(start: 0.08, end: 4.0, text: "Welcome, everyone, to this evening's talk."),
        .init(start: 31.5, end: 36.0, text: "Tonight I want to talk about the breath and why it comes first."),
        .init(start: 72.0, end: 78.0, text: "The long exhale calms the nervous system within a few rounds."),
        .init(start: 135.2, end: 140.0, text: "In our school we practise twelve rounds before any posture."),
        .init(start: 201.0, end: 207.0, text: "The teacher's teacher taught this in Mysore for forty years."),
        .init(start: 262.4, end: 268.0, text: "Now let's try it together, slowly, with the eyes closed."),
        .init(start: 331.0, end: 336.0, text: "Notice how the mind settles when the breath is long."),
        .init(start: 402.0, end: 418.0, text: "Thank you all for coming, and see you next week."),
    ]
    static var lines: [WritingLine] { WritingLine.lines(cues) }
    static var text: String { cues.map(\.text).joined(separator: " ") }

    static let goodAnswer = """
        {"titles": ["The Breath Comes First", "Why the Long Exhale Matters", "Twelve Rounds Before Any Posture"],
         "show_notes": "The teacher explains why the breath comes first, and how a long exhale settles the mind before any posture.",
         "chapters": [{"start": "0:00", "title": "Welcome"}, {"start": "2:15", "title": "Twelve Rounds"}, {"start": "4:22", "title": "Practice Together"}],
         "checklist": [{"claim": "A long exhale calms the nervous system quickly.", "quote": "The long exhale calms the nervous system within a few rounds.", "at": "1:12"}]}
        """
    static let tagsAnswer = #"{"tags": ["breath", "long exhale", "Breath", "practice"]}"#
    static let summaryAnswer = #"{"summary": "The teacher explains why the breath comes first."}"#

    func input(kind: RecordingKind = .talk, text: String = WritingTests.text, serenity: Bool = false, people: PeopleFacts = .notChecked) -> WritingInput {
        WritingInput(label: "Sun 13 Sep", fileName: "test.mp4", kind: kind, knownSerenity: serenity, cues: Self.cues, transcriptText: text, followsEpisode: true,
                     people: people)
    }

    /// A made-up teacher, named by Ivan and agreed to cloud models (v2 part M5a).
    static let releasedTeacher = PeopleFacts(checked: true, named: [.init(personID: UUID(), name: "Asha Verlaine", heard: true, seen: true)])

    func setup(_ clients: [ModelProvider: ScriptedClient], providers: [ModelTask: ModelProvider] = [:], attempts: Int = 3) -> WritingSetup {
        var setup = WritingSetup()
        setup.providers = providers
        setup.maxAttempts = attempts
        setup.makeClient = { provider, _ in clients[provider] ?? ScriptedClient(provider, replies: []) }
        setup.makeCloudClient = { provider, _ in clients[provider] ?? ScriptedClient(provider, replies: []) }
        return setup
    }

    // MARK: The checks

    func testOnlyTimesAndQuotesFromTheTranscriptAreKept() throws {
        let answer = """
            Here it is:
            ```json
            {"titles": ["The Breath Comes First", "Why the Long Exhale Matters \u{2014} Tonight", "Twelve Rounds Before Any Posture", "A Fourth"],
             "show_notes": "The teacher explains why the breath comes first \u{2014} and how a long exhale settles the mind.",
             "chapters": [{"start": "0:00", "title": "Welcome"}, {"start": "9:99", "title": "Nowhere"}, {"start": "2:15", "title": "Twelve Rounds"},
                          {"start": "2:40", "title": "Too Close"}, {"start": "[4:22]", "title": "Practice Together"}, {"start": "6:42", "title": "Closing"}],
             "checklist": [
               {"claim": "A long exhale calms quickly.", "quote": "The long exhale calms the nervous system within a few rounds.", "at": "1:12"},
               {"claim": "Twelve rounds come first.", "quote": "\u{201C}In our school we practise twelve rounds\u{201D}", "at": "2:15"},
               {"claim": "Fifty years in Mysore.", "quote": "taught this in Mysore for fifty years", "at": "3:21"},
               {"claim": "The mind settles.", "quote": "...Notice how the mind settles...", "at": "5:31"},
               {"claim": "Breath.", "quote": "the breath", "at": "0:31"},
               {"claim": "Practice together.", "quote": "Now let\u{2019}s try it together", "at": "4:22"}]}
            ```
            """
        let rules = WritingRules.forLength(418)
        XCTAssertEqual(rules, WritingRules(minChapters: 3, maxChapters: 3, minClaims: 5, maxClaims: 10))
        let checked = try WritingCheck.check(answer, lines: Self.lines, transcript: Self.text, rules: rules, length: 418)

        XCTAssertEqual(checked.titles, ["The Breath Comes First", "Why the Long Exhale Matters, Tonight", "Twelve Rounds Before Any Posture", "A Fourth"],
                       "four titles (the pick and three alternatives), the dash replaced with a comma")
        XCTAssertFalse(checked.showNotes.contains("\u{2014}"))
        // Chapters: "9:99" and "2:40" are not line times; "[4:22]" is, without its brackets; "6:42"
        // would be a 16-second last chapter, so it joins the one before.
        XCTAssertEqual(checked.chapters.map(\.start), [0.08, 135.2, 262.4])
        XCTAssertEqual(checked.chapters.map(\.label), ["0:00", "2:15", "4:22"])
        XCTAssertEqual(checked.leftOutChapters, 2)
        // Quotes: found word for word (quotation marks, ellipses and a typographic apostrophe aside),
        // each timed by the line it is in; "fifty years" is not what was said, and two words are too few.
        XCTAssertEqual(checked.checklist.map(\.quote), ["The long exhale calms the nervous system within a few rounds.",
                                                         "In our school we practise twelve rounds", "Notice how the mind settles",
                                                         "Now let's try it together"])
        XCTAssertEqual(checked.checklist.map(\.at), [72.0, 135.2, 331.0, 262.4])
        XCTAssertEqual(checked.leftOutQuotes, ["taught this in Mysore for fifty years", "the breath"])
        for quote in checked.checklist.map(\.quote) {
            XCTAssertTrue(WritingText.normalized(Self.text).contains(quote))
        }
        XCTAssertTrue(checked.notes.contains { $0.contains("2 dashes replaced") }, "\(checked.notes)")
        XCTAssertTrue(checked.notes.contains { $0.contains("joined the one before") }, "\(checked.notes)")
        XCTAssertTrue(checked.notes.contains { $0.contains("under the 5 asked for") }, "\(checked.notes)")
    }

    func testAQuoteWithAWordListFixIsFoundInTheLinesTheModelRead() throws {
        // Engine v0's transcript.txt has no word list fixes; the lines the model reads do.
        let unfixed = Self.text.replacingOccurrences(of: "Mysore", with: "My Sore")
        let answer = #"{"titles": ["A", "B", "C"], "show_notes": "Notes.", "chapters": [{"start": "0:00", "title": "x"}, {"start": "2:15", "title": "y"}, {"start": "4:22", "title": "z"}], "checklist": [{"claim": "c", "quote": "taught this in Mysore for forty years"}, {"claim": "d", "quote": "taught this in Delhi for forty years"}]}"#
        let checked = try WritingCheck.check(answer, lines: Self.lines, transcript: unfixed, rules: WritingRules.forLength(418), length: 418)
        XCTAssertEqual(checked.checklist.map(\.quote), ["taught this in Mysore for forty years"])
        XCTAssertEqual(checked.checklist.first?.at, 201.0)
        XCTAssertEqual(checked.leftOutQuotes, ["taught this in Delhi for forty years"], "a quote in neither is still left out")
    }

    func testTheFirstChapterStartsAtTheBeginning() throws {
        let answer = #"{"titles": ["A", "B", "C"], "show_notes": "Notes.", "chapters": [{"start": "0:31", "title": "Breath"}, {"start": "2:15", "title": "Rounds"}, {"start": "4:22", "title": "Together"}], "checklist": [{"claim": "c", "quote": "Notice how the mind settles", "at": "5:31"}]}"#
        let checked = try WritingCheck.check(answer, lines: Self.lines, transcript: Self.text, rules: WritingRules.forLength(418), length: 418)
        XCTAssertEqual(checked.chapters.first?.start, 0.08)
        XCTAssertTrue(checked.notes.contains { $0.contains("now starts at the beginning") })
    }

    func testStructuralProblemsAreFailuresToTryAgain() {
        let rules = WritingRules.forLength(418)
        func reason(_ answer: String) -> String? {
            do {
                _ = try WritingCheck.check(answer, lines: Self.lines, transcript: Self.text, rules: rules, length: 418)
                return nil
            } catch let failure as ModelFailure {
                XCTAssertTrue(failure.retryable)
                return failure.reason
            } catch { return "\(error)" }
        }
        XCTAssertEqual(reason("Sure, here are some titles."), "The answer was not JSON.")
        XCTAssertEqual(reason(#"{"titles": ["One", "Two"], "show_notes": "x", "chapters": [], "checklist": []}"#), "The answer had fewer than three usable titles.")
        XCTAssertEqual(reason(#"{"titles": ["A", "B", "C"], "show_notes": " ", "chapters": [], "checklist": []}"#), "The answer had no show notes.")
        XCTAssertEqual(reason(#"{"titles": ["A", "B", "C"], "show_notes": "x", "chapters": [{"start": "9:99", "title": "x"}], "checklist": []}"#),
                       "No chapter started at a time in the transcript.")
        XCTAssertEqual(reason(#"{"titles": ["A", "B", "C"], "show_notes": "x", "chapters": [{"start": "0:00", "title": "x"}], "checklist": []}"#),
                       "The answer had 1 usable chapter, not the 3 asked for.")
        XCTAssertEqual(reason(#"{"titles": ["A", "B", "C"], "show_notes": "x", "chapters": [{"start": "0:00", "title": "x"}, {"start": "2:15", "title": "y"}, {"start": "4:22", "title": "z"}], "checklist": [{"claim": "c", "quote": "words that were never said at all"}]}"#),
                       "None of the answer's quotes was found word for word in the transcript.")
    }

    func testRulesFollowTheTalksLength() {
        XCTAssertEqual(WritingRules.forLength(90), WritingRules(minChapters: 1, maxChapters: 1, minClaims: 1, maxClaims: 5))
        XCTAssertEqual(WritingRules.forLength(947), WritingRules(minChapters: 3, maxChapters: 3, minClaims: 5, maxClaims: 10), "the 13 Sep talk: 15:47")
        XCTAssertEqual(WritingRules.forLength(3339), WritingRules(minChapters: 3, maxChapters: 6, minClaims: 5, maxClaims: 10), "the 6 Sep talk: 55:39, six an hour")
        XCTAssertEqual(WritingText.stamp(59.6), "0:59", "rounded down, never a second not reached")
        XCTAssertEqual(WritingText.stamp(3723.9), "1:02:03")
    }

    // MARK: LM Studio, as docs/LOCAL-MODEL.md sets it

    func testTheLMStudioRequestKeepsEveryLocalModelSetting() throws {
        let client = LMStudioClient(address: "http://localhost:1235/v1", model: "qwen/qwen3.8-27b")
        XCTAssertEqual(client.root, "http://localhost:1235")
        let body = client.body(for: ModelRequest(system: "S", user: "U", shape: .writing, maxTokens: 512))
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["role"] }, ["system", "user"], "single turn, system and user only (rule 3)")
        XCTAssertEqual(body["max_tokens"] as? Int, 16_384, "never under 16,384, whatever was asked (rule 2)")
        XCTAssertEqual(body["reasoning_effort"] as? String, "medium", "thinking capped (rule 2)")
        XCTAssertEqual(body["temperature"] as? Double, 0.7)
        XCTAssertEqual(body["top_p"] as? Double, 0.8)
        XCTAssertEqual(body["top_k"] as? Int, 20)
        XCTAssertEqual(body["presence_penalty"] as? Double, 1.5, "rule 5")
        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertNil(body["response_format"], "the JSON is checked in Swift (rule 4)")
        XCTAssertEqual(ModelSettings.contextLength, 65_536, "rule 1")
    }

    func testACutOffOrEmptyReplyIsAFailureNeverAResult() throws {
        func object(_ content: String, _ finish: String) -> [String: Any] {
            ["choices": [["message": ["content": content, "reasoning_content": "thinking"], "finish_reason": finish]],
             "usage": ["prompt_tokens": 10, "completion_tokens": 5, "completion_tokens_details": ["reasoning_tokens": 3]]]
        }
        XCTAssertThrowsError(try LMStudioClient.reply(object("{\"titles\"", "length"), seconds: 1)) {
            XCTAssertEqual(($0 as? ModelFailure)?.kind, .truncated)
            XCTAssertEqual(($0 as? ModelFailure)?.retryable, true)
        }
        XCTAssertThrowsError(try LMStudioClient.reply(object("\n\n  \n", "stop"), seconds: 1)) {
            XCTAssertEqual(($0 as? ModelFailure)?.kind, .empty)
        }
        let reply = try LMStudioClient.reply(object("\n\n{\"ready\": true}", "stop"), seconds: 1)
        XCTAssertEqual(reply.text, "{\"ready\": true}", "the leading blank lines are trimmed")
        XCTAssertEqual(reply.reasoningTokens, 3)
    }

    func testLMStudioLoadsAt65536WhenLoadedSmallerAndUnloadsAfter() async throws {
        StubProtocol.seen = []
        StubProtocol.handler = { method, path, _ in
            switch (method, path) {
            case ("GET", "/api/v1/models"):
                return (200, ["models": [["key": "qwen/qwen3.8-27b", "loaded_instances": [["id": "qwen/qwen3.8-27b", "config": ["context_length": 8192]]]]]])
            case ("POST", "/api/v1/models/unload"): return (200, ["instance_id": "qwen/qwen3.8-27b"])
            case ("POST", "/api/v1/models/load"):
                return (200, ["instance_id": "qwen/qwen3.8-27b:2", "status": "loaded", "load_config": ["context_length": 65536]])
            case ("POST", "/v1/chat/completions"):
                return (200, ["choices": [["message": ["content": "\n\n" + WritingTests.goodAnswer], "finish_reason": "stop"]]])
            default: return (404, ["error": "no"])
            }
        }
        defer { StubProtocol.handler = nil }
        let client = LMStudioClient(address: "http://localhost:1235/v1", model: "qwen/qwen3.8-27b", session: StubProtocol.session())
        try await client.prepare() // the writer loads first, so the load is logged when it happens
        let reply = try await client.complete(ModelRequest(system: "S", user: "U", shape: .writing))
        XCTAssertTrue(reply.text.hasPrefix("{"))
        let line = await client.consumeLoadLine()
        XCTAssertEqual(line?.hasPrefix("Loaded again Qwen3.8-27B in LM Studio at 65,536 tokens"), true, line ?? "")
        let released = await client.release()
        XCTAssertNotNil(released)
        let calls = StubProtocol.seen.map { "\($0.method) \($0.path)" }
        XCTAssertEqual(calls, ["GET /api/v1/models", "POST /api/v1/models/unload", "POST /api/v1/models/load", "POST /v1/chat/completions", "POST /api/v1/models/unload"])
        XCTAssertEqual(StubProtocol.seen[2].body?["context_length"] as? Int, 65_536, "loaded at 65,536 tokens, never the default")
        XCTAssertEqual(StubProtocol.seen[1].body?["instance_id"] as? String, "qwen/qwen3.8-27b", "the small one is unloaded first")
        XCTAssertEqual(StubProtocol.seen[4].body?["instance_id"] as? String, "qwen/qwen3.8-27b:2", "only what Prakriti loaded is unloaded")
    }

    func testLMStudioClosedIsSaidPlainly() async {
        let client = LMStudioClient(address: "http://127.0.0.1:9/v1", model: "qwen/qwen3.8-27b")
        let check = await client.check()
        XCTAssertEqual(check.state, .problem)
        XCTAssertTrue(check.line.hasPrefix("LM Studio does not answer."), check.line)
    }

    // MARK: Tries

    func testACutOffEmptyOrInvalidAnswerIsTriedAgainAsTheSameSingleTurn() async throws {
        let lm = ScriptedClient(.lmStudio, replies: [
            .failure(ModelFailure(kind: .truncated, reason: "The answer was cut off at its length limit.")),
            .success("Sure! Here are your titles."),
            .success(Self.goodAnswer), .success(Self.tagsAnswer), .success(Self.summaryAnswer),
        ])
        let outcome = try await Writer(setup: setup([.lmStudio: lm]), log: nil).write(input())
        let package = try XCTUnwrap(outcome.package, outcome.problem ?? "")
        XCTAssertEqual(package.attempts, 3)
        XCTAssertEqual(package.titles.count, 3)
        XCTAssertEqual(package.tags, ["breath", "long exhale", "practice"], "merged by how often they came up")
        XCTAssertEqual(package.summary, "The teacher explains why the breath comes first.")
        let writing = lm.requests.filter { $0.shape == .writing }
        XCTAssertEqual(writing.count, 3)
        XCTAssertEqual(Set(writing.map(\.user)).count, 1, "every try is the same request: one system and one user message, no past turns")
        XCTAssertTrue(writing[0].user.contains("[2:15] In our school we practise twelve rounds before any posture."))
        XCTAssertTrue(writing[0].system.contains("exactly 3 chapters"))
    }

    func testThreeBadAnswersGiveAPlainProblemAndAClosedServerStopsAtOnce() async throws {
        let bad = ScriptedClient(.lmStudio, replies: [.success("no"), .success("no"), .success("no")])
        let outcome = try await Writer(setup: setup([.lmStudio: bad]), log: nil).write(input())
        XCTAssertNil(outcome.package)
        XCTAssertEqual(outcome.problem, "LM Studio (scripted) did not give a usable answer in 3 tries. The last: The answer was not JSON.")

        let closed = ScriptedClient(.lmStudio, replies: [.failure(ModelFailure(kind: .notRunning, reason: "LM Studio does not answer."))])
        let stopped = try await Writer(setup: setup([.lmStudio: closed]), log: nil).write(input())
        XCTAssertEqual(stopped.problem, "LM Studio does not answer.")
        XCTAssertEqual(closed.requests.count, 1, "a closed server is not asked again")
    }

    // MARK: The privacy lock

    func testThePrivacyLockFollowsIvansMarksOnly() async throws {
        // Part LOCK (Wed 14 Oct, Ivan's 12 Oct decision: every participant signed a release).
        let allCloud: [ModelTask: ModelProvider] = [.writing: .claudeAPI, .tagging: .claudeAPI, .summarizing: .claudeAPI]
        func run(kind: RecordingKind, text: String, providers: [ModelTask: ModelProvider], people: PeopleFacts = .notChecked) async throws -> (WrittenPackage?, ScriptedClient, ScriptedClient, ScriptedClient) {
            let lm = ScriptedClient(.lmStudio, replies: [.success(Self.goodAnswer), .success(Self.tagsAnswer), .success(Self.summaryAnswer)])
            let claude = ScriptedClient(.claudeAPI, replies: [.success(Self.goodAnswer), .success(Self.tagsAnswer), .success(Self.summaryAnswer)])
            let apple = ScriptedClient(.appleOnDevice, replies: [.success(Self.tagsAnswer), .success(Self.summaryAnswer)])
            let outcome = try await Writer(setup: setup([.lmStudio: lm, .claudeAPI: claude, .appleOnDevice: apple], providers: providers), log: nil)
                .write(input(kind: kind, text: text, people: people))
            return (outcome.package, lm, claude, apple)
        }

        // A class, people not checked, every task set to the Claude API: Anthropic does all three, LM Studio is not asked.
        let (lesson, lm1, claude1, _) = try await run(kind: .lesson, text: Self.text, providers: allCloud)
        XCTAssertEqual(claude1.requests.count, 3)
        XCTAssertEqual(lm1.requests.count, 0)
        XCTAssertNil(lesson?.lockReason)
        XCTAssertEqual(lesson?.lockedTasks, [])
        XCTAssertEqual(lesson?.writingProvider, "claudeAPI")
        XCTAssertFalse(lesson?.stepLine.contains("Privacy lock") == true, lesson?.stepLine ?? "")
        XCTAssertFalse(lesson?.markdown(label: "Sun 13 Sep", fileName: "x.mp4").contains("on this Mac only") == true)

        // A talk whose transcript says "Serenity": Anthropic, and her name goes as it is.
        let (serenity, _, claude2, _) = try await run(kind: .talk, text: Self.text + " Serenity taught this last week.", providers: allCloud,
                                                       people: Self.releasedTeacher)
        XCTAssertEqual(claude2.requests.count, 3)
        XCTAssertNil(serenity?.lockReason)
        XCTAssertTrue(claude2.requests.first?.system.contains("teachers are Gabriel and Serenity.") == true, "the prompt's own names go as they are")

        // Not marked as anything, a conversation, a test: the chosen provider.
        for kind in [RecordingKind.unknown, .conversation, .test, .talk] {
            let (written, _, claude3, _) = try await run(kind: kind, text: Self.text, providers: [.writing: .claudeAPI])
            XCTAssertEqual(claude3.requests.count, 1, "\(kind) is written by Anthropic")
            XCTAssertNil(written?.lockReason)
        }
        // Others seen and heard, nobody named: the chosen provider.
        let (others, _, claude4, _) = try await run(kind: .lesson, text: Self.text, providers: [.writing: .claudeAPI],
                                                     people: PeopleFacts(checked: true, unnamedSeen: 5, unnamedHeard: 3))
        XCTAssertEqual(claude4.requests.count, 1)
        XCTAssertNil(others?.lockReason)

        // Someone set to Leave Out: LM Studio does every task set to the cloud, and the files say why, naming no one.
        var leaving = Self.releasedTeacher
        leaving.leftOut = 1
        let (left, lm5, claude5, _) = try await run(kind: .lesson, text: Self.text, providers: allCloud, people: leaving)
        XCTAssertEqual(claude5.requests.count, 0, "Leave Out never reaches Anthropic")
        XCTAssertEqual(lm5.requests.count, 3)
        XCTAssertEqual(left?.lockReason, PrivacyLock.leftOut)
        XCTAssertEqual(left?.lockedTasks, ["writing", "tagging", "summarizing"])
        XCTAssertEqual(left?.writingProvider, "lmStudio")
        XCTAssertTrue(left?.stepLine.contains("Privacy lock: someone in it is set to Leave Out, so LM Studio did the writing and tagging and summarizing chosen for a cloud model.") == true,
                      left?.stepLine ?? "")
        XCTAssertTrue(left?.markdown(label: "Sun 13 Sep", fileName: "x.mp4").contains("Someone in it is set to Leave Out, so it was written by a model on this Mac only.") == true)

        // A speaker marked no release: the same.
        let (unreleased, _, claude6, _) = try await run(kind: .talk, text: Self.text, providers: [.writing: .claudeAPI], people: PeopleFacts(checked: true, named: [
            .init(personID: UUID(), name: "Asha Verlaine", heard: true, seen: true, released: false)]))
        XCTAssertEqual(claude6.requests.count, 0)
        XCTAssertEqual(unreleased?.lockReason, PrivacyLock.noRelease)

        // A class with Apple on-device chosen for tags: a local choice is kept.
        let (_, _, _, apple) = try await run(kind: .lesson, text: Self.text, providers: [.tagging: .appleOnDevice])
        XCTAssertEqual(apple.requests.map(\.shape), [.tags])
    }

    func testWriteAgainOnAClassUsesTheChosenProviderAndLeaveOutStaysOnThisMac() async throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(), log: AppLog(directory: nil))
        let folder = FileManager.default.temporaryDirectory.appending(path: "prakriti-writing-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sentences = Self.cues.map { ["text": $0.text, "start": $0.start, "end": $0.end] }
        try JSONSerialization.data(withJSONObject: ["sentences": sentences]).write(to: folder.appending(path: TranscriptFiles.asHeard))
        try "A note Ivan keeps here.".write(to: folder.appending(path: "my note.txt"), atomically: true, encoding: .utf8)

        let recording = Recording(filePath: "/tmp/2026-09-13 class.mp4", recordedAt: Fixtures.date(2026, 9, 13), duration: 418, status: .readyForYourYes, kind: .lesson)
        model.context.insert(recording)
        recording.outputFolder = folder.path
        recording.madeFiles = ["episode.mp3", TranscriptFiles.asHeard]
        model.settings.provider = [.writing: .claudeAPI, .tagging: .lmStudio, .summarizing: .lmStudio]
        let lm = ScriptedClient(.lmStudio, replies: [.success(Self.tagsAnswer), .success(Self.summaryAnswer)])
        let claude = ScriptedClient(.claudeAPI, replies: [.success(Self.goodAnswer)])
        model.runner.makeClient = { provider, _ in provider == .claudeAPI ? claude : (provider == .lmStudio ? lm : ScriptedClient(provider, replies: [])) }
        model.runner.makeCloudClient = { _, _ in claude }

        XCTAssertTrue(model.canWrite(recording))
        await model.runner.write(recording)
        XCTAssertEqual(claude.requests.count, 1, "a class is written by the Claude API (part LOCK)")
        let written = try XCTUnwrap(recording.written, recording.writingProblem ?? "")
        XCTAssertNil(written.lockReason)
        XCTAssertEqual(written.writingProvider, "claudeAPI")
        XCTAssertEqual(recording.status, .readyForYourYes)
        XCTAssertEqual(recording.latestRun?.steps.first?.state, .done)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: WrittenPackage.notesFileName).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: WrittenPackage.fileName).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: "my note.txt").path), "Ivan's own file is left alone")
        XCTAssertEqual(recording.madeFiles, ["episode.mp3", "show-notes.md", "titles-notes-chapters.json", "transcript.json"])

        // Someone set to Leave Out: Write Again reads the page's choices and stays on this Mac, and says so.
        var choices = PeopleChoices()
        choices.set(.leaveOut, for: .voice(2))
        recording.choices = choices
        let lmLocked = ScriptedClient(.lmStudio, replies: [.success(Self.goodAnswer), .success(Self.tagsAnswer), .success(Self.summaryAnswer)])
        model.runner.makeClient = { provider, _ in provider == .lmStudio ? lmLocked : ScriptedClient(provider, replies: []) }
        await model.runner.write(recording)
        XCTAssertEqual(claude.requests.count, 1, "nothing more reached the Claude API")
        XCTAssertEqual(recording.written?.lockReason, PrivacyLock.leftOut)
        XCTAssertTrue(recording.latestRun?.steps.first?.detail?.contains("Privacy lock: someone in it is set to Leave Out") == true,
                      recording.latestRun?.steps.first?.detail ?? "")
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.contains("titles, show notes and chapters written again") && $0.contains("Privacy lock") }, "\(lines)")

        // Write Again on the approved recording takes the approval back.
        recording.status = .approved
        let lm2 = ScriptedClient(.lmStudio, replies: [.success(Self.goodAnswer), .success(Self.tagsAnswer), .success(Self.summaryAnswer)])
        model.runner.makeClient = { provider, _ in provider == .lmStudio ? lm2 : ScriptedClient(provider, replies: []) }
        await model.runner.write(recording)
        XCTAssertEqual(recording.status, .readyForYourYes)

        // A closed model leaves the last files as they were.
        let before = try String(contentsOf: folder.appending(path: WrittenPackage.notesFileName), encoding: .utf8)
        model.runner.makeClient = { provider, _ in ScriptedClient(provider, replies: [.failure(ModelFailure(kind: .notRunning, reason: "LM Studio does not answer."))]) }
        await model.runner.write(recording)
        XCTAssertEqual(recording.writingProblem, "LM Studio does not answer.")
        XCTAssertNotNil(recording.written, "the last good writing is kept")
        XCTAssertEqual(try String(contentsOf: folder.appending(path: WrittenPackage.notesFileName), encoding: .utf8), before)
        XCTAssertEqual(recording.latestRun?.outcome, .couldntFinish)
    }

    func testSerenityIsFoundAsAWholeWord() {
        XCTAssertTrue(Privacy.mentionsSerenity("and Serenity said"))
        XCTAssertTrue(Privacy.mentionsSerenity("SERENITY."))
        XCTAssertTrue(Privacy.mentionsSerenity("a sense of serenity"), "the common word too; recorded only, it locks nothing since part LOCK")
        XCTAssertFalse(Privacy.mentionsSerenity("serenitylike"))
        XCTAssertFalse(Privacy.mentionsSerenity("Gabriel teaches."))
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, locked: true), .lmStudio)
        XCTAssertEqual(ModelRouting.provider(chosen: .ollama, locked: true), .ollama)
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, locked: false), .claudeAPI)
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: Self.releasedTeacher)).reason)
    }

    // MARK: Apple on-device

    func testAppleOnDeviceTagsAShortInput() async throws {
        if let reason = AppleOnDeviceClient.unavailableReason { throw XCTSkip(reason) }
        let lines = Array(Self.lines.prefix(4))
        let tags = WritingCheck.tags(try await Writer(setup: WritingSetup(), log: nil).shortTask(.tags, client: AppleOnDeviceClient(), lines: lines, fileName: "test"))
        XCTAssertGreaterThanOrEqual(tags.count, 1, "\(tags)")
        XCTAssertLessThanOrEqual(tags.count, 8)
        XCTAssertEqual(AppleOnDeviceClient.contextSize, 8_192, "measured on macOS 27.2, 10 Oct")
    }

    func testALongTextIsReadInPartsByAppleOnDeviceAndRefusedForWriting() async throws {
        let apple = ScriptedClient(.appleOnDevice, limit: 380, replies: Array(repeating: .success(Self.summaryAnswer), count: 20))
        let summary = try await Writer(setup: WritingSetup(), log: nil).shortTask(.summary, client: apple, lines: Self.lines, fileName: "test")
        XCTAssertEqual(summary.count, 1)
        let parts = apple.requests.filter { !$0.user.hasPrefix("These are summaries") }
        XCTAssertGreaterThan(parts.count, 1, "split into parts that fit")
        XCTAssertEqual(apple.requests.last?.user.hasPrefix("These are summaries of the parts of one talk"), true, "then the parts' summaries summarized")
        for request in parts {
            let budget = try await apple.budget(for: request)
            XCTAssertLessThanOrEqual(budget.needed, budget.limit)
        }

        // Writing needs the whole talk at once: refused, with the plain reason.
        let small = ScriptedClient(.appleOnDevice, limit: 200, replies: [])
        let outcome = try await Writer(setup: setup([.appleOnDevice: small], providers: [.writing: .appleOnDevice]), log: nil).write(input())
        XCTAssertNil(outcome.package)
        XCTAssertTrue(outcome.problem?.hasPrefix("Apple on-device (scripted) reads at most 200 tokens at once") == true, outcome.problem ?? "")
        XCTAssertEqual(small.requests.count, 0)
    }

    // MARK: The Keychain, the files, Approve

    func testTheClaudeKeyLivesInTheKeychainOnly() throws {
        let store = KeyStore(service: "studio.therowan.prakriti.app.tests.keychain-check", account: "api-key")
        try? store.remove()
        XCTAssertFalse(store.exists)
        XCTAssertNil(store.read())
        try store.save("  not-a-real-key  ")
        XCTAssertTrue(store.exists)
        XCTAssertEqual(store.read(), "not-a-real-key")
        try store.save("replaced")
        XCTAssertEqual(store.read(), "replaced")
        try store.remove()
        XCTAssertFalse(store.exists)
        XCTAssertEqual(AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                                log: AppLog(directory: nil)).keyStore.service, KeyStore.testing.service, "tests never touch Ivan's key")
        // No key, no call: the Claude API's test sends nothing.
        let body = AnthropicClient(model: "claude-opus-5-5", key: nil).body(for: PrivacyLock.keyCheck())
        XCTAssertEqual(body["model"] as? String, "claude-opus-5-5")
        XCTAssertNil(body["temperature"], "Claude Opus 5.5 takes no sampling settings")
        XCTAssertNil(body["thinking"], "no thinking field at all (v2 part M5b, warning 34)")
    }

    func testClaudeWithoutAKeySendsNothing() async {
        let check = await AnthropicClient(model: "claude-opus-5-5", key: nil).check()
        XCTAssertEqual(check.state, .notSetUp)
        XCTAssertEqual(check.line, "No key added. Nothing is sent to Anthropic.")
    }

    func testTheFilesSayWhatWasWrittenAndApproveTakesTheNotesOnly() throws {
        var package = WrittenPackage(titles: ["One", "Two", "Three"], showNotes: "Notes.", chapters: [WrittenChapter(start: 0.08, title: "Welcome")],
                                     checklist: [CheckedClaim(claim: "A claim.", quote: "Notice how the mind settles", at: 331)],
                                     writtenBy: "Qwen3.8-27B in LM Studio", writingProvider: "lmStudio", writtenAt: Fixtures.now,
                                     seconds: 300, attempts: 1, writingSeconds: 290, leftOutQuotes: ["x y z w"], clock: "episode", modelAnswer: "{}")
        package.lockReason = "This recording mentions Serenity"
        let markdown = package.markdown(label: "Sun 13 Sep", fileName: "2026-09-13 18-25-44.mp4")
        XCTAssertFalse(markdown.contains("\u{2014}") || markdown.contains("\u{2013}"))
        XCTAssertTrue(markdown.contains("1. One\n2. Two\n3. Three"))
        XCTAssertTrue(markdown.contains("0:00 Welcome"))
        XCTAssertTrue(markdown.contains("5:31"))
        XCTAssertTrue(markdown.contains("The call to action is yours to set") && markdown.contains("removal requests is not chosen yet"),
                      "a placeholder, never an invented call to action or address")
        XCTAssertTrue(markdown.contains("1 quote the model gave was not in the transcript word for word, so it was left out."))
        XCTAssertTrue(markdown.contains("**Nothing has been published.**"))
        XCTAssertNil(package.stored.modelAnswer, "the store keeps the checked package, not the raw answer")
        XCTAssertEqual(WrittenPackage.decode(package.json()), package)

        let recording = Recording(filePath: "/tmp/a.mp4")
        recording.madeFiles = ["REPORT.md", "episode.mp3", "show-notes.md", "titles-notes-chapters.json", "transcript.json", "transcript.txt"]
        XCTAssertEqual(ApprovalCheck.filesToApprove(recording), ["REPORT.md", "episode.mp3", "show-notes.md", "transcript.txt"])
        XCTAssertTrue(Pipeline.madeNames.isSuperset(of: WrittenPackage.fileNames), "a remake replaces them and never anything else")
    }

    func testTheWritingStepIsPlannedOnlyWithTheTranscript() {
        var options = PipelineOptions()
        options.writing = WritingSetup()
        XCTAssertEqual(options.plannedSteps.suffix(2), [.writing, .report])
        options.makeTranscript = false
        XCTAssertFalse(options.plannedSteps.contains(.writing), "titles are written from the transcript, so not without it")
    }
}
