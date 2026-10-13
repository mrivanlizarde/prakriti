import Foundation

/// Anthropic's Messages API over raw HTTP (Swift has no official SDK, so this is the documented route),
/// brought to the current request shape in v2 part M5b (docs/v2/PLAN.md M5). It sends text off this Mac, so
/// it is a `CloudModelClient`: it takes only a `CloudPayload`, which only `PrivacyLock.release` makes.
///
/// The shape, each part with its reason (source: the claude-api reference, cached 6 Oct 2026, read 12 Oct):
/// - always `"stream": true` with `max_tokens` 64,000: a silent non-streamed call hung for 10 minutes twice
///   (START_HERE engine warnings), and current models think before they answer.
/// - **no `thinking` field at all**: on Opus 5.5 an explicit disabled or budgeted setting is a 400 at every
///   effort, and START_HERE warning 34 forbids one. Depth is `output_config.effort`, set explicitly per task
///   because Opus 5.5 defaults to `medium`: writing `high`, tags, summaries and the key test `low`.
/// - `fallbacks: "default"` with the `server-side-fallback-2026-07-01` header, only for the models the
///   reference lists for it (`fallbackModels`); another model would answer the field with a 400.
/// - `stop_reason` `refusal` or `max_tokens`, an `error` event, a stream that ends without a stop reason, or
///   empty text is a failure, never a result.
/// The key comes from the Keychain for each run and is sent only in the `x-api-key` header.
struct AnthropicClient: CloudModelClient {
    let provider = ModelProvider.claudeAPI
    let model: String
    let key: String?
    var session: URLSession = CloudHTTP.session

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let modelsEndpoint = "https://api.anthropic.com/v1/models"
    static let version = "2023-06-01"
    static let context = 1_000_000
    static let maxTokens = 64_000
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    /// The models the reference lists for `fallbacks: "default"` (PLAN M5).
    static let fallbackModels: Set<String> = ["claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5", "claude-fable-5-1"]
    static let service = "Anthropic"

    var displayName: String { model + " (Anthropic)" }
    var contextLimit: Int { Self.context }

    /// How hard the model thinks, per task: the writing that matters `high`, the short tasks `low`.
    static func effort(for shape: ModelRequest.Shape) -> String {
        switch shape {
        case .writing: "high"
        case .tags, .summary, .check: "low"
        }
    }

    static func usesFallbacks(_ model: String) -> Bool { fallbackModels.contains(model) }

    /// The headers, the key among them. Kept apart so a test can pin them.
    func headers(key: String) -> [String: String] {
        var headers = ["x-api-key": key, "anthropic-version": Self.version]
        if Self.usesFallbacks(model) { headers["anthropic-beta"] = Self.fallbackBeta }
        return headers
    }

    /// The request body. Kept apart so a test can pin it.
    func body(for payload: CloudPayload) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": Self.maxTokens,
            "stream": true,
            "system": payload.system,
            "messages": [["role": "user", "content": payload.user]],
            "output_config": ["effort": Self.effort(for: payload.shape)],
        ]
        if Self.usesFallbacks(model) { body["fallbacks"] = "default" }
        return body
    }

    func send(_ payload: CloudPayload) async throws -> ModelReply {
        guard let key, !key.isEmpty else {
            throw ModelFailure(kind: .notSetUp, reason: "No Anthropic key is in the Keychain. Add one in Settings, Models.")
        }
        guard !model.isEmpty else { throw ModelFailure(kind: .notSetUp, reason: "No Anthropic model is chosen in Settings, Models.") }
        let started = ContinuousClock.now
        var text = ""
        var stop: String?
        var input: Int?
        var output: Int?
        var servedBy: String?
        let (status, errorBody) = try await CloudHTTP.stream(ModelHTTP.post(Self.endpoint, body: body(for: payload), headers: headers(key: key)),
                                                             session: session, service: Self.service) { event in
            switch event["type"] as? String {
            case "message_start":
                let message = event["message"] as? [String: Any]
                servedBy = message?["model"] as? String
                input = (message?["usage"] as? [String: Any])?["input_tokens"] as? Int
            case "content_block_delta":
                let delta = event["delta"] as? [String: Any]
                if (delta?["type"] as? String) == "text_delta", let piece = delta?["text"] as? String { text += piece }
            case "message_delta":
                if let reason = (event["delta"] as? [String: Any])?["stop_reason"] as? String { stop = reason }
                let usage = event["usage"] as? [String: Any]
                if let tokens = usage?["output_tokens"] as? Int { output = tokens }
                if let tokens = usage?["input_tokens"] as? Int { input = tokens }
            case "error":
                let error = event["error"] as? [String: Any]
                let type = error?["type"] as? String ?? "error"
                throw ModelFailure(kind: .server, reason: type == "overloaded_error" ? "Anthropic is busy. Try again later." : "Anthropic stopped the answer with an error.",
                                   detail: "\(type): \(error?["message"] as? String ?? "")")
            default:
                break
            }
        }
        if status != 200 { throw CloudHTTP.failure(status: status, body: errorBody, service: Self.service) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stop == "refusal" { throw ModelFailure(kind: .refused, reason: "Anthropic declined this text.") }
        if stop == "max_tokens" {
            throw ModelFailure(kind: .truncated, reason: "The answer was cut off at its length limit.", detail: "stop_reason max_tokens after \(output ?? 0) tokens")
        }
        guard stop != nil else { throw ModelFailure(kind: .server, reason: "The answer stopped before it ended.", detail: "no stop_reason in the stream") }
        if trimmed.isEmpty { throw ModelFailure(kind: .empty, reason: "The model answered with nothing.", detail: "stop_reason \(stop ?? "none")") }
        let served = servedBy ?? model
        return ModelReply(text: trimmed, finishReason: stop, promptTokens: input, completionTokens: output, reasoningTokens: nil,
                          seconds: ModelHTTP.seconds(since: started), costUSD: CloudPricing.cost(model: served, input: input, output: output),
                          servedBy: served)
    }

    /// The models this request shape works on: those whose `capabilities.effort.supported` is true in the
    /// Models API (field read 12 Oct from the claude-api reference's Models section). Older models listed
    /// there reject `output_config.effort`, so they never reach the pop-up. Free to call.
    static func models(key: String, session: URLSession = CloudHTTP.session) async throws -> [CloudModel] {
        var found: [CloudModel] = []
        var after: String?
        for _ in 0..<10 {
            var address = modelsEndpoint + "?limit=1000"
            if let after { address += "&after_id=" + (after.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? after) }
            let page = try await CloudHTTP.get(URL(string: address)!, headers: ["x-api-key": key, "anthropic-version": version],
                                               session: session, service: service)
            let data = (page["data"] as? [[String: Any]]) ?? []
            for entry in data {
                guard let id = entry["id"] as? String else { continue }
                let effort = (entry["capabilities"] as? [String: Any])?["effort"] as? [String: Any]
                guard (effort?["supported"] as? Bool) == true else { continue }
                found.append(CloudModel(id: id, name: (entry["display_name"] as? String) ?? id))
            }
            guard (page["has_more"] as? Bool) == true, let last = page["last_id"] as? String else { break }
            after = last
        }
        return found
    }

    /// Without a key there is nothing to test, and nothing is sent. With one, `PrivacyLock.keyCheck()` (fixed
    /// words, no recording) checks that the key and the chosen model work.
    func check() async -> ProviderCheck {
        guard let key, !key.isEmpty else {
            return ProviderCheck(state: .notSetUp, line: "No key added. Nothing is sent to Anthropic.", at: Date())
        }
        do {
            let reply = try await send(PrivacyLock.keyCheck())
            let cost = reply.costUSD.map { ", cost \(CloudPricing.text($0))" } ?? ""
            return ProviderCheck(state: .ok, line: String(format: "%@ answered in %.0f s%@. The key in the Keychain works.", reply.servedBy ?? model, reply.seconds, cost), at: Date())
        } catch let failure as ModelFailure {
            return ProviderCheck(state: failure.kind == .notSetUp || failure.kind == .keyRejected ? .notSetUp : .problem, line: failure.reason, at: Date(),
                                 keyRejected: failure.kind == .keyRejected)
        } catch {
            return ProviderCheck(state: .problem, line: "The test stopped.", at: Date())
        }
    }
}
