import Foundation

/// OpenAI's Responses API over raw HTTP (v2 part M5b, docs/v2/PLAN.md M5). It sends text off this Mac, so it
/// is a `CloudModelClient`: it takes only a `CloudPayload`, which only `PrivacyLock.release` makes.
///
/// Built against developers.openai.com's API reference as read on Mon 12 Oct 2026 (the Responses resource
/// page; it shows no version number). What was read there, and used:
/// - `POST /v1/responses` with `model`, `instructions` (the system text), `input` (the user text, a string),
///   `max_output_tokens` (counts reasoning tokens too), `stream: true` and `store: false` (nothing is kept on
///   OpenAI's side for later turns; Prakriti never sends a second turn).
/// - Streamed events, each a `data:` line whose `type` names it: `response.output_text.delta` (`delta`),
///   `response.refusal.delta` (`delta`), `response.completed` (`response`, with `usage.input_tokens` and
///   `usage.output_tokens`), `response.incomplete` (`response.incomplete_details.reason`: `max_output_tokens`,
///   `content_filter`, ...), `response.failed` (`response.error.message`) and `error` (`message`).
/// - No `reasoning.effort` is sent: its accepted values differ by model and the page lists none, so a model
///   that rejects a value would fail every call. **[unverified on a real key: no key was available.]**
/// - No model id is written here: the pop-up is filled from `GET /v1/models` (`filter`).
/// A refusal, a cut-off answer, a failed response, a stream that ends without `response.completed`, or empty
/// text is a failure, never a result. JSON in the answer is checked in Swift as every model's is (W48).
struct OpenAIClient: CloudModelClient {
    let provider = ModelProvider.openAI
    let model: String
    let key: String?
    var session: URLSession = CloudHTTP.session

    static let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    static let modelsEndpoint = URL(string: "https://api.openai.com/v1/models")!
    /// Room for thinking and the answer. The writing answer itself is about 3,000 tokens; reasoning models
    /// count their thinking against this too.
    static let maxOutputTokens = 32_000
    /// The context the budget check assumes; current GPT models read more, so this errs on the side of "fits".
    static let context = 400_000
    static let service = "OpenAI"

    var displayName: String { model + " (OpenAI)" }
    var contextLimit: Int { Self.context }

    /// The request body. Kept apart so a test can pin it.
    func body(for payload: CloudPayload) -> [String: Any] {
        [
            "model": model,
            "instructions": payload.system,
            "input": payload.user,
            "max_output_tokens": Self.maxOutputTokens,
            "stream": true,
            "store": false,
        ]
    }

    func send(_ payload: CloudPayload) async throws -> ModelReply {
        guard let key, !key.isEmpty else {
            throw ModelFailure(kind: .notSetUp, reason: "No OpenAI key is in the Keychain. Add one in Settings, Models.")
        }
        guard !model.isEmpty else { throw ModelFailure(kind: .notSetUp, reason: "No OpenAI model is chosen in Settings, Models.") }
        let started = ContinuousClock.now
        var text = ""
        var refusal = ""
        var completed = false
        var incomplete: String?
        var input: Int?
        var output: Int?
        var reasoning: Int?
        var servedBy: String?
        let (status, errorBody) = try await CloudHTTP.stream(ModelHTTP.post(Self.endpoint, body: body(for: payload), headers: ["Authorization": "Bearer " + key]),
                                                             session: session, service: Self.service) { event in
            let response = event["response"] as? [String: Any]
            switch event["type"] as? String {
            case "response.output_text.delta":
                text += event["delta"] as? String ?? ""
            case "response.refusal.delta":
                refusal += event["delta"] as? String ?? ""
            case "response.completed":
                completed = true
                servedBy = response?["model"] as? String
                let usage = response?["usage"] as? [String: Any]
                input = usage?["input_tokens"] as? Int
                output = usage?["output_tokens"] as? Int
                reasoning = (usage?["output_tokens_details"] as? [String: Any])?["reasoning_tokens"] as? Int
            case "response.incomplete":
                incomplete = ((response?["incomplete_details"] as? [String: Any])?["reason"] as? String) ?? "unknown"
                let usage = response?["usage"] as? [String: Any]
                output = usage?["output_tokens"] as? Int
            case "response.failed":
                let error = response?["error"] as? [String: Any]
                throw ModelFailure(kind: .server, reason: "OpenAI could not finish the answer.", detail: "\(error?["code"] as? String ?? "failed"): \(error?["message"] as? String ?? "")")
            case "error":
                throw ModelFailure(kind: .server, reason: "OpenAI stopped the answer with an error.", detail: "\(event["code"] as? String ?? "error"): \(event["message"] as? String ?? "")")
            default:
                break
            }
        }
        if status != 200 { throw CloudHTTP.failure(status: status, body: errorBody, service: Self.service) }
        if !refusal.isEmpty { throw ModelFailure(kind: .refused, reason: "OpenAI declined this text.") }
        if let incomplete {
            if incomplete == "content_filter" { throw ModelFailure(kind: .refused, reason: "OpenAI declined this text.", detail: "incomplete: content_filter") }
            if incomplete == "max_output_tokens" {
                throw ModelFailure(kind: .truncated, reason: "The answer was cut off at its length limit.", detail: "incomplete: max_output_tokens after \(output ?? 0) tokens")
            }
            throw ModelFailure(kind: .server, reason: "OpenAI stopped the answer before it ended.", detail: "incomplete: \(incomplete)")
        }
        guard completed else { throw ModelFailure(kind: .server, reason: "The answer stopped before it ended.", detail: "no response.completed in the stream") }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ModelFailure(kind: .empty, reason: "The model answered with nothing.") }
        return ModelReply(text: trimmed, finishReason: "completed", promptTokens: input, completionTokens: output, reasoningTokens: reasoning,
                          seconds: ModelHTTP.seconds(since: started), costUSD: nil, servedBy: servedBy ?? model)
    }

    /// The models that write text through the Responses API, from everything `GET /v1/models` lists (which
    /// also lists embeddings, speech, images and moderation, with no capability field to tell them apart, so
    /// the filter is by name). Newest names first. Free to call.
    static func models(key: String, session: URLSession = CloudHTTP.session) async throws -> [CloudModel] {
        let page = try await CloudHTTP.get(modelsEndpoint, headers: ["Authorization": "Bearer " + key], session: session, service: service)
        let ids = ((page["data"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }
        return filter(ids).map { CloudModel(id: $0, name: $0) }
    }

    /// Text models only: names that start "gpt-" or "o" and a digit, without the words of the models that
    /// do something else.
    static func filter(_ ids: [String]) -> [String] {
        let other = ["audio", "realtime", "tts", "transcribe", "image", "embedding", "search", "moderation", "instruct", "codex", "computer", "dall-e", "whisper", "sora"]
        return ids.filter { id in
            let lower = id.lowercased()
            let family = lower.hasPrefix("gpt-") || (lower.first == "o" && lower.dropFirst().first?.isNumber == true)
            return family && !other.contains(where: lower.contains)
        }
        .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
    }

    func check() async -> ProviderCheck {
        guard let key, !key.isEmpty else {
            return ProviderCheck(state: .notSetUp, line: "No key added. Nothing is sent to OpenAI.", at: Date())
        }
        do {
            let reply = try await send(PrivacyLock.keyCheck())
            return ProviderCheck(state: .ok, line: String(format: "%@ answered in %.0f s. The key in the Keychain works.", reply.servedBy ?? model, reply.seconds), at: Date())
        } catch let failure as ModelFailure {
            return ProviderCheck(state: failure.kind == .notSetUp || failure.kind == .keyRejected ? .notSetUp : .problem, line: failure.reason, at: Date(),
                                 keyRejected: failure.kind == .keyRejected)
        } catch {
            return ProviderCheck(state: .problem, line: "The test stopped.", at: Date())
        }
    }
}
