import Foundation

// What the two cloud providers share (v2 part M5b, docs/v2/PLAN.md M5): the HTTP session with its time
// limits, the reader for streamed answers (server-sent events), the model lists that fill the pop-ups,
// and the measured cost of a call. The clients are AnthropicClient.swift and OpenAIClient.swift; each is a
// `CloudModelClient`, so it takes only a `CloudPayload` that `PrivacyLock.release` made.

/// One model a cloud provider lists, as its pop-up shows it.
struct CloudModel: Sendable, Equatable, Hashable, Identifiable {
    /// The id sent in a request ("claude-sonnet-5-5").
    var id: String
    /// What the pop-up shows ("Claude Sonnet 5.5"); the id when the provider gives no name.
    var name: String
}

/// What loading a provider's model list found.
struct CloudModelList: Sendable, Equatable {
    enum State: String, Sendable { case loading, loaded, noKey, rejected, problem }
    var state: State
    var models: [CloudModel] = []
    /// One plain sentence when the list could not be loaded.
    var line: String?
}

enum CloudHTTP {
    /// Every answer streams, so the 9-minute limit is the longest silence allowed between two pieces of an
    /// answer (START_HERE engine warnings: "AI calls always stream, with a 9-minute timeout"; Anthropic
    /// sends a ping while it thinks). The whole call may run 40 minutes, as LM Studio's may.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 540
        configuration.timeoutIntervalForResource = 2_400
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }()

    /// Sends a streamed request and hands each `data:` line's JSON to `onEvent`, in order. A status other
    /// than 200 returns the status and the error body instead (read whole, it is short). Failures to reach
    /// the provider become `ModelFailure`s in one plain sentence.
    static func stream(_ request: URLRequest, session: URLSession, service: String,
                       onEvent: ([String: Any]) throws -> Void) async throws -> (status: Int, errorBody: Data?) {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count > 65_536 { break }
                }
                return (status, body)
            }
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload.isEmpty || payload == "[DONE]" { continue }
                guard let object = ModelHTTP.object(Data(payload.utf8)) else { continue }
                try onEvent(object)
            }
            return (status, nil)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as ModelFailure {
            throw failure
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed].contains(error.code) {
            throw ModelFailure(kind: .notRunning, reason: "\(service) could not be reached. Check the internet connection.", detail: error.localizedDescription)
        } catch let error as URLError where error.code == .timedOut {
            throw ModelFailure(kind: .server, reason: "\(service) sent nothing for 9 minutes, so the call was stopped.", detail: error.localizedDescription)
        } catch {
            throw ModelFailure(kind: .server, reason: "\(service) could not be reached.", detail: error.localizedDescription)
        }
    }

    /// The failure for an answer that was not 200. 401 and 403 mean the key; 429 and 5xx are worth a retry.
    static func failure(status: Int, body: Data?, service: String) -> ModelFailure {
        let detail = "\(status) \(ModelHTTP.errorText(body ?? Data()))"
        switch status {
        case 401, 403:
            return ModelFailure(kind: .keyRejected, reason: "\(service) did not accept this key. Check it and save it again.", detail: detail)
        case 404:
            return ModelFailure(kind: .notSetUp, reason: "\(service) does not offer the model chosen in Settings, Models.", detail: detail)
        case 429:
            return ModelFailure(kind: .server, reason: "\(service) is busy or this key has reached its limit. Try again later.", detail: detail)
        case 400:
            return ModelFailure(kind: .invalid, reason: "\(service) did not accept the request.", detail: detail)
        default:
            return ModelFailure(kind: .server, reason: "\(service) answered with an error.", detail: detail)
        }
    }

    /// A GET with the provider's headers, its JSON read whole.
    static func get(_ url: URL, headers: [String: String], session: URLSession, service: String) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (status, data) = try await ModelHTTP.send(request, session: session, service: service)
        guard status == 200, let object = ModelHTTP.object(data) else { throw failure(status: status, body: data, service: service) }
        return object
    }
}

/// What a call cost, from the tokens it used and the provider's published prices. Anthropic's are from the
/// claude-api reference (cached 6 Oct 2026, read 12 Oct), in dollars per million tokens. OpenAI's are not
/// listed here, so its calls show their tokens only.
enum CloudPricing {
    static let perMillion: [String: (input: Double, output: Double)] = [
        "claude-fable-5-1": (10, 50), "claude-fable-5": (10, 50),
        "claude-opus-5-5": (4, 20), "claude-opus-5": (5, 25), "claude-opus-4-8": (5, 25), "claude-opus-4-7": (5, 25), "claude-opus-4-6": (5, 25),
        "claude-sonnet-5-5": (2, 10), "claude-sonnet-5": (2, 10), "claude-sonnet-4-6": (3, 15),
        "claude-haiku-5-5": (0.10, 0.50),
    ]

    static func cost(model: String, input: Int?, output: Int?) -> Double? {
        guard let price = perMillion[model], let input, let output else { return nil }
        return (Double(input) * price.input + Double(output) * price.output) / 1_000_000
    }

    /// "$0.13", or "less than one cent".
    static func text(_ dollars: Double) -> String {
        dollars < 0.005 ? "less than one cent" : String(format: "$%.2f", dollars)
    }
}

/// The words a call's line ends with: its tokens and, where the price is known, its cost.
extension ModelReply {
    var usageLine: String {
        var parts: [String] = []
        if let promptTokens { parts.append("\(Format.number(promptTokens)) tokens read") }
        if let completionTokens { parts.append("\(Format.number(completionTokens)) written") }
        if let costUSD { parts.append("cost \(CloudPricing.text(costUSD))") }
        return parts.joined(separator: ", ")
    }
}
