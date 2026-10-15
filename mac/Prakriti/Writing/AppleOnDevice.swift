import Foundation
import FoundationModels

// Apple's on-device model (Foundation Models), built into macOS. It runs on this Mac, so the privacy
// lock allows it. It reads at most `contextSize` tokens at once (8,192 on macOS 27.2, measured 10 Oct;
// it was 4,096 on macOS 26), counted with Apple's own `tokenCount`, never guessed. A request that does
// not fit is refused here; the tagging and summarizing tasks split a long transcript into parts that
// do fit (Writer), and writing refuses, because titles and chapters need the whole talk at once.
//
// Tags and summaries use guided generation (@Generable), so Apple's model returns the shape asked for
// rather than text that has to be parsed; the result is written out as the same JSON the other
// providers return, so one checker reads them all.

@Generable
struct GeneratedTags {
    @Guide(description: "Short topic tags for the passage, one to three words each, in the passage's own terms", .count(3...8))
    var tags: [String]
}

@Generable
struct GeneratedSummary {
    @Guide(description: "Two or three plain sentences that describe what the passage covers, in the third person")
    var summary: String
}

struct AppleOnDeviceClient: LanguageModelClient {
    let provider = ModelProvider.appleOnDevice
    var displayName: String { "Apple on-device" }

    /// Room kept for the answer when checking that a request fits.
    static func answerRoom(_ shape: ModelRequest.Shape) -> Int {
        shape == .writing ? 2_500 : 1_000
    }

    /// Why Apple's model cannot be used on this Mac now, in plain words, or nil when it can.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "This Mac cannot run Apple's on-device model."
            case .appleIntelligenceNotEnabled: return "Apple Intelligence is turned off in System Settings, so Apple's on-device model cannot be used."
            case .modelNotReady: return "Apple's on-device model is still downloading or getting ready. Try again later."
            @unknown default: return "Apple's on-device model is not available on this Mac."
            }
        @unknown default: return "Apple's on-device model is not available on this Mac."
        }
    }

    static var contextSize: Int { SystemLanguageModel.default.contextSize }

    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) {
        if let reason = Self.unavailableReason { throw ModelFailure(kind: .unavailable, reason: reason) }
        let model = SystemLanguageModel.default
        let counted = try await model.tokenCount(for: request.system + "\n\n" + request.user)
        return (counted + Self.answerRoom(request.shape), model.contextSize)
    }

    func complete(_ request: ModelRequest) async throws -> ModelReply {
        if let reason = Self.unavailableReason { throw ModelFailure(kind: .unavailable, reason: reason) }
        let started = ContinuousClock.now
        let session = LanguageModelSession(instructions: request.system)
        do {
            let text: String
            switch request.shape {
            case .tags:
                let response = try await session.respond(to: request.user, generating: GeneratedTags.self)
                text = String(decoding: ModelHTTP.json(["tags": response.content.tags]), as: UTF8.self)
            case .summary:
                let response = try await session.respond(to: request.user, generating: GeneratedSummary.self)
                text = String(decoding: ModelHTTP.json(["summary": response.content.summary]), as: UTF8.self)
            case .writing, .check, .planning:
                text = try await session.respond(to: request.user).content
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw ModelFailure(kind: .empty, reason: "The model answered with nothing.") }
            return ModelReply(text: trimmed, finishReason: "stop", promptTokens: nil, completionTokens: nil, reasoningTokens: nil,
                              seconds: ModelHTTP.seconds(since: started))
        } catch let failure as ModelFailure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LanguageModelError {
            // macOS 27's errors (the older GenerationError cases are deprecated, and a warning fails the build).
            switch error {
            case .contextSizeExceeded:
                throw ModelFailure(kind: .tooLong, reason: "The text is longer than Apple's on-device model reads at once.", detail: "\(error)")
            case .guardrailViolation, .refusal:
                throw ModelFailure(kind: .refused, reason: "Apple's on-device model declined this text.", detail: "\(error)")
            default:
                throw ModelFailure(kind: .server, reason: "Apple's on-device model stopped with an error.", detail: "\(error)")
            }
        } catch {
            throw ModelFailure(kind: .server, reason: "Apple's on-device model stopped with an error.", detail: "\(error)")
        }
    }

    func check() async -> ProviderCheck {
        if let reason = Self.unavailableReason { return ProviderCheck(state: .notSetUp, line: reason, at: Date()) }
        do {
            let request = ModelRequest(system: "You tag short passages from talks about yoga.",
                                       user: "Tag this passage:\n\nPranayama is the practice of extending the breath. We start with a long exhale, then a pause.",
                                       shape: .tags, maxTokens: 512)
            let reply = try await complete(request)
            let tags = (ModelHTTP.object(Data(reply.text.utf8))?["tags"] as? [String]) ?? []
            return ProviderCheck(state: .ok, line: String(format: "Wrote %@ in %.1f s: %@.", Format.count(tags.count, "tag"), reply.seconds,
                                                          tags.joined(separator: ", ")), at: Date())
        } catch let failure as ModelFailure {
            return ProviderCheck(state: .problem, line: failure.reason, at: Date())
        } catch {
            return ProviderCheck(state: .problem, line: "The test stopped.", at: Date())
        }
    }
}
