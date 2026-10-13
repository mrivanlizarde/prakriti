import Foundation

// The language models Prakriti can ask (milestone 6), each behind one small interface, so the
// writer, the privacy lock and the tests treat them the same way:
//
// - LM Studio (the default): Qwen3.8-27B through its local OpenAI-compatible server. Every setting
//   in docs/LOCAL-MODEL.md is load-bearing and kept here: loaded at a 65,536-token context (never
//   LM Studio's default), thinking capped at "medium", max_tokens at least 16,384, a reply cut off
//   by its length or empty counts as a failure and is tried again, one system and one user message
//   only, and the JSON is checked in Swift (Writer), never trusted.
// - Apple on-device (AppleOnDevice.swift): only for inputs under its context limit.
// - Ollama: optional, on this Mac.
// - Claude API: optional, sends text to Anthropic, key kept in the Keychain. It is a
//   `CloudModelClient` and takes only a `CloudPayload` from the privacy lock (PrivacyLock.swift).

/// One request: a single turn, a system message and a user message (LOCAL-MODEL.md rule 3: the
/// family's template mishandles past assistant turns, and some runtimes reject other roles).
struct ModelRequest: Sendable, Equatable {
    /// What the reply must hold. Apple on-device uses it to choose its guided-generation type.
    enum Shape: String, Sendable { case writing, tags, summary, check }

    var system: String
    var user: String
    var shape: Shape
    /// LOCAL-MODEL.md rule 2: at least 16,384, because the model's thinking counts against it.
    var maxTokens: Int = ModelSettings.maxTokens
}

struct ModelReply: Sendable, Equatable {
    var text: String
    var finishReason: String?
    var promptTokens: Int?
    var completionTokens: Int?
    var reasoningTokens: Int?
    var seconds: Double
}

/// Why a model call did not give a usable answer: one plain sentence for Ivan, the detail for the log.
struct ModelFailure: Error, Sendable, Equatable {
    enum Kind: String, Sendable {
        /// The server does not answer (LM Studio or Ollama closed).
        case notRunning
        /// Something Ivan has to set up first: no key, no model chosen, model not downloaded.
        case notSetUp
        /// The input does not fit the model's context.
        case tooLong
        /// Cut off by its length (finish_reason "length"): tried again (LOCAL-MODEL.md rule 2).
        case truncated
        /// Nothing but whitespace came back: tried again.
        case empty
        /// The model declined the text.
        case refused
        /// The server answered with an error.
        case server
        /// Apple's model is not available on this Mac.
        case unavailable
        /// The answer was not the JSON asked for, or did not pass the checks.
        case invalid
    }

    let kind: Kind
    let reason: String
    var detail: String?

    /// Worth one more try with the same request.
    var retryable: Bool {
        switch kind {
        case .truncated, .empty, .invalid, .server: true
        default: false
        }
    }
}

/// The settings LOCAL-MODEL.md fixes, in one place so a test can pin them.
enum ModelSettings {
    /// LM Studio loads at 8,192 by default; a 10k to 25k-token transcript would be cut off.
    static let contextLength = 65_536
    static let maxTokens = 16_384
    /// "medium", not the template's default "xhigh", which spent about 48k reasoning tokens per
    /// task. Measured 10 Oct through the chat completions endpoint: the field changes the prompt
    /// the template builds (41 tokens with it, 79 without), so it is honored there.
    static let reasoningEffort = "medium"
    static let temperature = 0.7
    static let topP = 0.8
    static let topK = 20
    static let presencePenalty = 1.5
    /// Characters per token, counted low on purpose so a size check errs on the side of "too long".
    static let charactersPerToken = 3.0

    static func estimatedTokens(_ text: String) -> Int {
        Int((Double(text.count) / charactersPerToken).rounded(.up))
    }
}

/// What a model's test button found.
struct ProviderCheck: Sendable, Equatable {
    enum State: String, Sendable { case checking, ok, notSetUp, problem }
    var state: State
    var line: String
    var at: Date
}

/// One provider's way of answering a request.
protocol LanguageModelClient: Sendable {
    var provider: ModelProvider { get }
    /// "Qwen3.8-27B in LM Studio", "Apple on-device".
    var displayName: String { get }
    /// Gets the model ready before the first request (LM Studio loads it at 65,536 tokens), so the
    /// load is logged when it happens, not after a ten-minute answer.
    func prepare() async throws
    /// The most this model reads at once, in tokens, and what this request needs (with room to answer).
    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int)
    func complete(_ request: ModelRequest) async throws -> ModelReply
    /// Gives back what the calls took. LM Studio unloads the model if Prakriti loaded it. Returns a
    /// line for the log, or nil.
    func release() async -> String?
    /// The test button.
    func check() async -> ProviderCheck
}

extension LanguageModelClient {
    func prepare() async throws {}
    func release() async -> String? { nil }
}

// MARK: HTTP

enum ModelHTTP {
    /// A model call can take many minutes before its first byte (a long transcript, thinking), so
    /// the time limits are generous; a call that still hangs ends as a failure, never forever.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2_400
        configuration.timeoutIntervalForResource = 2_400
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }()

    /// Sends a request and returns the status and body. A refused connection is "not running".
    static func send(_ request: URLRequest, session: URLSession, service: String) async throws -> (Int, Data) {
        do {
            let (data, response) = try await session.data(for: request)
            return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed].contains(error.code) {
            throw ModelFailure(kind: .notRunning, reason: "\(service) does not answer.", detail: error.localizedDescription)
        } catch let error as URLError where error.code == .timedOut {
            throw ModelFailure(kind: .server, reason: "\(service) took longer than 40 minutes to answer, so the call was stopped.", detail: error.localizedDescription)
        } catch {
            throw ModelFailure(kind: .server, reason: "\(service) could not be reached.", detail: error.localizedDescription)
        }
    }

    static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    static func object(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func post(_ url: URL, body: [String: Any], headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = json(body)
        return request
    }

    static func errorText(_ data: Data) -> String {
        if let object = object(data), let error = object["error"] {
            if let message = (error as? [String: Any])?["message"] as? String { return message }
            if let message = error as? String { return message }
        }
        return String(decoding: data.prefix(300), as: UTF8.self)
    }

    static func seconds(since start: ContinuousClock.Instant) -> Double {
        let d = ContinuousClock.now - start
        return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }
}

// MARK: LM Studio

/// LM Studio's local server: OpenAI-compatible chat completions at `address` (".../v1"), and its own
/// REST API beside it (`/api/v1/models`, `/load`, `/unload`) to load the model at the right context.
/// An actor, because it remembers whether Prakriti loaded the model, so it can unload it after.
actor LMStudioClient: LanguageModelClient {
    nonisolated let provider = ModelProvider.lmStudio
    nonisolated let address: String
    nonisolated let model: String
    nonisolated let session: URLSession
    private var loadedInstance: String?
    private var loadedContext: Int?
    private var loadedByPrakriti = false
    private var loadLine: String?

    init(address: String, model: String, session: URLSession = ModelHTTP.session) {
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    nonisolated var displayName: String { Format.modelName(model) + " in LM Studio" }

    /// "http://localhost:1235/v1" serves chat; its REST API lives at "http://localhost:1235".
    nonisolated var root: String {
        address.hasSuffix("/v1") ? String(address.dropLast(3)) : address
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: path), url.scheme != nil else {
            throw ModelFailure(kind: .notSetUp, reason: "The LM Studio address on the Models screen is not a web address.")
        }
        return url
    }

    /// What LM Studio says about the model: is it downloaded, and is it loaded, at what context.
    struct ModelState: Sendable, Equatable {
        var downloaded: Bool
        var instances: [(id: String, context: Int?)]
        static func == (a: ModelState, b: ModelState) -> Bool {
            a.downloaded == b.downloaded && a.instances.map(\.id) == b.instances.map(\.id) && a.instances.map(\.context) == b.instances.map(\.context)
        }
    }

    func state() async throws -> ModelState {
        let (status, data) = try await ModelHTTP.send(URLRequest(url: try url(root + "/api/v1/models")), session: session, service: "LM Studio")
        guard status == 200, let list = ModelHTTP.object(data)?["models"] as? [[String: Any]] else {
            throw ModelFailure(kind: .server, reason: "LM Studio answered, but not with its list of models. It may need updating.",
                               detail: "GET /api/v1/models: \(status) \(ModelHTTP.errorText(data))")
        }
        guard let entry = list.first(where: { ($0["key"] as? String) == model || ($0["id"] as? String) == model }) else {
            return ModelState(downloaded: false, instances: [])
        }
        let loaded = (entry["loaded_instances"] as? [[String: Any]]) ?? []
        return ModelState(downloaded: true, instances: loaded.map { instance in
            let config = instance["config"] as? [String: Any]
            return ((instance["id"] as? String) ?? model, (config?["context_length"] as? Int) ?? (config?["context_length"] as? NSNumber)?.intValue)
        })
    }

    /// Makes sure the model is loaded at 65,536 tokens (LOCAL-MODEL.md rule 1). Loaded smaller (by
    /// hand, or by a request that loaded it on demand at LM Studio's default 8,192), it is unloaded
    /// and loaded again at 65,536, because a transcript would not fit. Not loaded, Prakriti loads it
    /// and unloads it after (`release`), so 33 GB is not held when nothing is being written.
    func ensureLoaded() async throws {
        if loadedInstance != nil { return }
        guard !model.isEmpty else { throw ModelFailure(kind: .notSetUp, reason: "No LM Studio model is named on the Models screen.") }
        let current = try await state()
        guard current.downloaded else {
            throw ModelFailure(kind: .notSetUp, reason: "\(Format.modelName(model)) is not downloaded in LM Studio.")
        }
        if let ready = current.instances.first(where: { ($0.context ?? 0) >= ModelSettings.contextLength }) {
            loadedInstance = ready.id
            loadedContext = ready.context
            loadLine = "\(displayName) was already loaded at \(Format.number(ready.context ?? 0)) tokens."
            return
        }
        for small in current.instances {
            _ = try await ModelHTTP.send(ModelHTTP.post(try url(root + "/api/v1/models/unload"), body: ["instance_id": small.id]), session: session, service: "LM Studio")
        }
        let started = ContinuousClock.now
        let (status, data) = try await ModelHTTP.send(
            ModelHTTP.post(try url(root + "/api/v1/models/load"), body: ["model": model, "context_length": ModelSettings.contextLength, "echo_load_config": true]),
            session: session, service: "LM Studio")
        let reply = ModelHTTP.object(data)
        guard status == 200, let instance = reply?["instance_id"] as? String else {
            throw ModelFailure(kind: .server, reason: "LM Studio could not load \(Format.modelName(model)). It may not have enough free memory: it needs about 33 GB.",
                               detail: "POST /api/v1/models/load: \(status) \(ModelHTTP.errorText(data))")
        }
        let context = ((reply?["load_config"] as? [String: Any])?["context_length"] as? Int) ?? ModelSettings.contextLength
        guard context >= ModelSettings.contextLength else {
            throw ModelFailure(kind: .server, reason: "LM Studio loaded \(Format.modelName(model)) at \(Format.number(context)) tokens, not 65,536, so a whole transcript would not fit.")
        }
        loadedInstance = instance
        loadedContext = context
        loadedByPrakriti = true
        loadLine = (current.instances.isEmpty ? "Loaded " : "Loaded again ") + "\(displayName) at \(Format.number(context)) tokens in "
            + String(format: "%.0f s", ModelHTTP.seconds(since: started)) + (current.instances.isEmpty ? "." : " (it was loaded smaller).")
    }

    func prepare() async throws { try await ensureLoaded() }

    /// The line `ensureLoaded` left for the log, once.
    func consumeLoadLine() -> String? {
        defer { loadLine = nil }
        return loadLine
    }

    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) {
        (ModelSettings.estimatedTokens(request.system + request.user) + request.maxTokens, loadedContext ?? ModelSettings.contextLength)
    }

    /// The request body, with every LOCAL-MODEL.md setting. Kept apart so a test can pin it.
    nonisolated func body(for request: ModelRequest) -> [String: Any] {
        [
            "model": model,
            "messages": [["role": "system", "content": request.system], ["role": "user", "content": request.user]],
            "max_tokens": max(request.maxTokens, ModelSettings.maxTokens),
            "temperature": ModelSettings.temperature,
            "top_p": ModelSettings.topP,
            "top_k": ModelSettings.topK,
            "presence_penalty": ModelSettings.presencePenalty,
            "reasoning_effort": ModelSettings.reasoningEffort,
            "stream": false,
        ]
    }

    func complete(_ request: ModelRequest) async throws -> ModelReply {
        try await ensureLoaded()
        let started = ContinuousClock.now
        let (status, data) = try await ModelHTTP.send(ModelHTTP.post(try url(address + "/chat/completions"), body: body(for: request)),
                                                      session: session, service: "LM Studio")
        guard status == 200, let object = ModelHTTP.object(data) else {
            throw ModelFailure(kind: .server, reason: "LM Studio answered with an error.", detail: "\(status) \(ModelHTTP.errorText(data))")
        }
        return try Self.reply(object, seconds: ModelHTTP.seconds(since: started))
    }

    /// Reads a chat completions answer. finish_reason "length" or empty content is a failure to try
    /// again, never a result (LOCAL-MODEL.md rule 2). The content may start with blank lines.
    static func reply(_ object: [String: Any], seconds: Double) throws -> ModelReply {
        let choice = (object["choices"] as? [[String: Any]])?.first
        let message = choice?["message"] as? [String: Any]
        let content = ((message?["content"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let finish = choice?["finish_reason"] as? String
        let usage = object["usage"] as? [String: Any]
        let details = usage?["completion_tokens_details"] as? [String: Any]
        let reply = ModelReply(text: content, finishReason: finish, promptTokens: usage?["prompt_tokens"] as? Int,
                               completionTokens: usage?["completion_tokens"] as? Int, reasoningTokens: details?["reasoning_tokens"] as? Int,
                               seconds: seconds)
        if finish == "length" {
            throw ModelFailure(kind: .truncated, reason: "The answer was cut off at its length limit.",
                               detail: "finish_reason length after \(reply.completionTokens ?? 0) tokens (\(reply.reasoningTokens ?? 0) thinking)")
        }
        if content.isEmpty {
            throw ModelFailure(kind: .empty, reason: "The model answered with nothing.",
                               detail: "empty content, finish_reason \(finish ?? "none"), \(reply.reasoningTokens ?? 0) thinking tokens")
        }
        return reply
    }

    func release() async -> String? {
        guard loadedByPrakriti, let instance = loadedInstance else { return nil }
        loadedInstance = nil
        loadedByPrakriti = false
        let request = ModelHTTP.post((try? url(root + "/api/v1/models/unload")) ?? URL(fileURLWithPath: "/"), body: ["instance_id": instance])
        let status = (try? await ModelHTTP.send(request, session: session, service: "LM Studio"))?.0
        return status == 200 ? "Unloaded \(displayName), which Prakriti had loaded, to free its memory." : "Could not unload \(displayName); LM Studio still holds it."
    }

    func check() async -> ProviderCheck {
        let started = ContinuousClock.now
        do {
            try await ensureLoaded()
            let loaded = consumeLoadLine()
            let reply = try await complete(ModelRequest(system: "You answer with JSON only.", user: "Reply with exactly {\"ready\": true}", shape: .check))
            let released = await release()
            let ok = reply.text.contains("true")
            let context = loadedContext.map { " Loaded at \(Format.number($0)) tokens." } ?? ""
            return ProviderCheck(state: ok ? .ok : .problem,
                                 line: (ok ? "Answered in " : "Answered, but not as asked, in ") + String(format: "%.0f s.", ModelHTTP.seconds(since: started))
                                    + (loaded.map { " " + $0 } ?? context) + (released != nil ? " Unloaded again after the test." : ""),
                                 at: Date())
        } catch let failure as ModelFailure {
            _ = await release()
            let hint = failure.kind == .notRunning ? " Open LM Studio and start its server, at \(address)." : ""
            return ProviderCheck(state: failure.kind == .notSetUp ? .notSetUp : .problem, line: failure.reason + hint, at: Date())
        } catch {
            _ = await release()
            return ProviderCheck(state: .problem, line: "The test stopped.", at: Date())
        }
    }
}

// MARK: Ollama

/// Ollama's own chat API on this Mac. Optional. The context is set per request (num_ctx), because
/// its default is a few thousand tokens.
struct OllamaClient: LanguageModelClient {
    let provider = ModelProvider.ollama
    let address: String
    let model: String
    var session: URLSession = ModelHTTP.session
    static let context = 32_768

    init(address: String, model: String, session: URLSession = ModelHTTP.session) {
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    var displayName: String { (model.isEmpty ? "No model" : model) + " in Ollama" }

    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) {
        (ModelSettings.estimatedTokens(request.system + request.user) + request.maxTokens, Self.context)
    }

    func complete(_ request: ModelRequest) async throws -> ModelReply {
        guard !model.isEmpty else { throw ModelFailure(kind: .notSetUp, reason: "No Ollama model is named on the Models screen.") }
        guard let url = URL(string: address + "/api/chat"), url.scheme != nil else {
            throw ModelFailure(kind: .notSetUp, reason: "The Ollama address on the Models screen is not a web address.")
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "system", "content": request.system], ["role": "user", "content": request.user]],
            "stream": false,
            "options": ["num_ctx": Self.context, "num_predict": request.maxTokens, "temperature": ModelSettings.temperature,
                        "top_p": ModelSettings.topP, "top_k": ModelSettings.topK, "presence_penalty": ModelSettings.presencePenalty],
        ]
        let started = ContinuousClock.now
        let (status, data) = try await ModelHTTP.send(ModelHTTP.post(url, body: body), session: session, service: "Ollama")
        guard status == 200, let object = ModelHTTP.object(data) else {
            throw ModelFailure(kind: status == 404 ? .notSetUp : .server,
                               reason: status == 404 ? "Ollama does not have \(model). Pull it in Ollama first." : "Ollama answered with an error.",
                               detail: "\(status) \(ModelHTTP.errorText(data))")
        }
        let content = (((object["message"] as? [String: Any])?["content"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let finish = object["done_reason"] as? String
        if finish == "length" { throw ModelFailure(kind: .truncated, reason: "The answer was cut off at its length limit.") }
        if content.isEmpty { throw ModelFailure(kind: .empty, reason: "The model answered with nothing.") }
        return ModelReply(text: content, finishReason: finish, promptTokens: object["prompt_eval_count"] as? Int,
                          completionTokens: object["eval_count"] as? Int, reasoningTokens: nil, seconds: ModelHTTP.seconds(since: started))
    }

    /// The models Ollama has, by name.
    func installed() async throws -> [String] {
        guard let url = URL(string: address + "/api/tags"), url.scheme != nil else {
            throw ModelFailure(kind: .notSetUp, reason: "The Ollama address on the Models screen is not a web address.")
        }
        let (status, data) = try await ModelHTTP.send(URLRequest(url: url), session: session, service: "Ollama")
        guard status == 200, let models = ModelHTTP.object(data)?["models"] as? [[String: Any]] else {
            throw ModelFailure(kind: .server, reason: "Ollama answered, but not with its list of models.")
        }
        return models.compactMap { $0["name"] as? String }
    }

    func check() async -> ProviderCheck {
        do {
            let names = try await installed()
            let list = names.isEmpty ? "no models" : names.joined(separator: ", ")
            guard !model.isEmpty else {
                return ProviderCheck(state: .notSetUp, line: "Ollama answers. Installed: \(list). Name one above to use it.", at: Date())
            }
            guard names.contains(model) || names.contains(model + ":latest") else {
                return ProviderCheck(state: .notSetUp, line: "Ollama answers, but does not have \(model). Installed: \(list).", at: Date())
            }
            let reply = try await complete(ModelRequest(system: "You answer with JSON only.", user: "Reply with exactly {\"ready\": true}", shape: .check, maxTokens: 2_048))
            return ProviderCheck(state: .ok, line: String(format: "%@ answered in %.0f s. Installed: %@.", model, reply.seconds, list), at: Date())
        } catch let failure as ModelFailure {
            return ProviderCheck(state: failure.kind == .notRunning ? .notSetUp : .problem,
                                 line: failure.kind == .notRunning ? "Ollama is not running at \(address). It is optional." : failure.reason, at: Date())
        } catch {
            return ProviderCheck(state: .problem, line: "The test stopped.", at: Date())
        }
    }
}

// MARK: Claude API

/// The Claude API (Anthropic's Messages API, raw HTTP: there is no official Swift SDK). Optional;
/// sends text to Anthropic, so it is a `CloudModelClient`: it takes only a `CloudPayload`, which only
/// `PrivacyLock.release` makes (v2 part M5a). The request shape is v1's, unchanged in M5a; part M5b brings
/// it to the current one. The key comes from the Keychain for each run and is never written to a file or a log.
/// Claude Opus 5.5 takes no sampling settings; its effort is set to "medium" explicitly, and a declined
/// request falls back on Anthropic's side ("fallbacks").
struct ClaudeClient: CloudModelClient {
    let provider = ModelProvider.claudeAPI
    let model: String
    let key: String?
    var session: URLSession = ModelHTTP.session
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let context = 1_000_000

    var displayName: String { model + " (Claude API)" }
    var contextLimit: Int { Self.context }

    /// The request body. Kept apart so a test can pin it.
    func body(for payload: CloudPayload) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 16_000,
            "system": payload.system,
            "messages": [["role": "user", "content": payload.user]],
            "thinking": ["type": "adaptive"],
            "output_config": ["effort": "medium"],
            "fallbacks": "default",
        ]
    }

    func send(_ payload: CloudPayload) async throws -> ModelReply {
        guard let key, !key.isEmpty else {
            throw ModelFailure(kind: .notSetUp, reason: "No Claude API key is in the Keychain. Add one on the Models screen.")
        }
        let started = ContinuousClock.now
        let (status, data) = try await ModelHTTP.send(
            ModelHTTP.post(Self.endpoint, body: body(for: payload),
                           headers: ["x-api-key": key, "anthropic-version": "2023-06-01", "anthropic-beta": "server-side-fallback-2026-07-01"]),
            session: session, service: "The Claude API")
        guard status == 200, let object = ModelHTTP.object(data) else {
            let kind: ModelFailure.Kind = status == 401 || status == 403 ? .notSetUp : .server
            throw ModelFailure(kind: kind, reason: status == 401 ? "The Claude API did not accept the key in the Keychain." : "The Claude API answered with an error.",
                               detail: "\(status) \(ModelHTTP.errorText(data))")
        }
        let stop = object["stop_reason"] as? String
        if stop == "refusal" { throw ModelFailure(kind: .refused, reason: "The Claude API declined this text.") }
        let text = ((object["content"] as? [[String: Any]]) ?? []).filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if stop == "max_tokens" { throw ModelFailure(kind: .truncated, reason: "The answer was cut off at its length limit.") }
        if text.isEmpty { throw ModelFailure(kind: .empty, reason: "The model answered with nothing.") }
        let usage = object["usage"] as? [String: Any]
        return ModelReply(text: text, finishReason: stop, promptTokens: usage?["input_tokens"] as? Int,
                          completionTokens: usage?["output_tokens"] as? Int, reasoningTokens: nil, seconds: ModelHTTP.seconds(since: started))
    }

    /// Without a key there is nothing to test, and nothing is sent. With one, a one-line request
    /// with no recording in it ("Reply with OK") checks the key works.
    func check() async -> ProviderCheck {
        guard let key, !key.isEmpty else {
            return ProviderCheck(state: .notSetUp, line: "No key added. Nothing is sent to Anthropic.", at: Date())
        }
        do {
            let reply = try await send(PrivacyLock.keyCheck())
            return ProviderCheck(state: .ok, line: String(format: "%@ answered in %.0f s. The key in the Keychain works.", model, reply.seconds), at: Date())
        } catch let failure as ModelFailure {
            return ProviderCheck(state: failure.kind == .notSetUp ? .notSetUp : .problem, line: failure.reason, at: Date())
        } catch {
            return ProviderCheck(state: .problem, line: "The test stopped.", at: Date())
        }
    }
}
