import Foundation

// The privacy lock (v2 part M5a, rewritten by part LOCK on Wed 14 Oct 2026 to follow Ivan's decision of Mon 12 Oct:
// "all the participants have signed an agreement that includes that their likeness can be used for commercial
// purposes"). Two halves:
//
// 1. Which recordings a cloud model may read (`PrivacyLock.decide`). Every participant counts as released, so a
//    talk, a class, a conversation, a recording with other people seen or heard, and a recording that names
//    Serenity or anyone else aloud are all written by the provider Ivan chose (the Claude API by default). Only two
//    things keep a recording on this Mac, both Ivan's own marks: a named person in it marked "no release" (Settings,
//    Privacy: "Signed release on file" turned off, `Person.noRelease`), or anyone in it set to Leave Out (the People
//    tab, any output). No recording at all is still refused. Names said aloud are not people decisions and never lock.
//
// 2. What a request may carry (`PrivacyLock.release`), the cloud adapter's own check (warning 19). The only way to
//    make a `CloudPayload`, and a cloud client takes nothing else (`CloudModelClient`), so no code path can send text
//    that has not passed here. It runs the decision again, replaces the names Ivan muted and the names of anyone
//    marked "no release" with tokens (`NameTokens`), then reads the result again and refuses if one of those names or
//    a withheld span is still there. A refusal is logged with its reason only, never the text. Other names go as they
//    are: Ivan's 12 Oct decision makes a name said aloud nobody's privacy question.

/// What the people check found in one recording (`PeopleFacts.from`, part M6b: checked only once both the face step
/// and the voice step ran), and Ivan's marks the lock reads. Names are Ivan's own naming per recording; nothing here
/// is a face or voice print.
struct PeopleFacts: Sendable, Equatable, Codable {
    struct Named: Sendable, Equatable, Codable {
        var personID: UUID
        var name: String
        var heard: Bool
        var seen: Bool
        /// A signed release is on file (`!Person.noRelease`). True unless Ivan marked this person "no release":
        /// every participant signed one (Ivan, Mon 12 Oct).
        var released: Bool = true
    }

    /// True only when both the face step and the voice step ran (PLAN review item 5).
    var checked: Bool
    var named: [Named] = []
    var unnamedSeen: Int = 0
    var unnamedHeard: Int = 0
    /// Names said aloud that Ivan marked Mute (part M6c): always replaced before a cloud request.
    var mutedNames: [String] = []
    /// How many people Ivan set to Leave Out in this recording, for any output (the People tab, part M6c).
    var leftOut: Int = 0

    static let notChecked = PeopleFacts(checked: false)

    /// The same facts with each named person's release read from the store, by id. A person not in `people`
    /// (their name was removed) keeps what the facts say.
    func withReleases(from people: [Person]) -> PeopleFacts {
        var facts = self
        let released = Dictionary(people.map { ($0.id, !$0.noRelease) }, uniquingKeysWith: { $0 && $1 })
        for index in facts.named.indices {
            if let value = released[facts.named[index].personID] { facts.named[index].released = value }
        }
        return facts
    }

    /// Someone in it, seen or heard, is a named person Ivan marked "no release".
    var hasSomeoneWithoutRelease: Bool { named.contains { !$0.released && ($0.heard || $0.seen) } }
}

/// Everything the lock reads about one recording.
struct LockSubject: Sendable, Equatable {
    var people: PeopleFacts = .notChecked
    /// Words said by someone left out (none is filled today: Leave Out already locks the recording). None may be sent.
    var withheldSpans: [String] = []
}

/// Why the lock keeps a recording on this Mac, or that it does not.
struct LockDecision: Sendable, Equatable {
    /// Written to sit inside a sentence ("someone in it is set to Leave Out"); nil when a cloud model may read it.
    /// Names no one (design spec C4).
    let reason: String?

    var isLocked: Bool { reason != nil }

    /// The line for the Checks tab: "Someone in it is set to Leave Out, so only models on this Mac read it."
    var line: String? { reason.map { "\($0.capitalizedFirst), so only models on this Mac read it." } }
}

/// The text one cloud request carries, after the lock and the name tokens. There is no other way to
/// make one: its initializer is private to this file, and `PrivacyLock.release` is the only caller.
struct CloudPayload: Sendable {
    let system: String
    let user: String
    let shape: ModelRequest.Shape
    let maxTokens: Int
    /// The names replaced, to put back in the answer.
    let tokens: NameTokens

    fileprivate init(system: String, user: String, shape: ModelRequest.Shape, maxTokens: Int, tokens: NameTokens) {
        self.system = system
        self.user = user
        self.shape = shape
        self.maxTokens = maxTokens
        self.tokens = tokens
    }
}

/// A refused cloud request: the reason only, never the text.
struct LockRefusal: Error, Sendable, Equatable {
    let reason: String
}

enum PrivacyLock {
    static let noRecording = "it is not one recording"
    static let leftOut = "someone in it is set to Leave Out"
    static let noRelease = "someone in it has no signed release on file"

    /// The lock in plain sentences, for Settings, Models and Settings, Privacy. True of what the build does.
    static let settingsLine = "Everyone who takes part has signed a release, so the model chosen for each task reads every recording: talks, classes, recordings where other people appear or speak, and recordings that say anyone's name. Only models on this Mac read a recording in which you set someone to Leave Out, or in which someone appears or speaks whose signed release you turned off in Settings, Privacy. Then LM Studio does a task set to Anthropic or OpenAI, and the recording says so. Names you muted are replaced before anything is sent, and the text is checked again."

    /// Whether a cloud model may read this recording. Locked only for Ivan's own marks, in order: someone set to
    /// Leave Out, then someone named with no signed release. No recording at all is locked too.
    static func decide(_ subject: LockSubject?) -> LockDecision {
        guard let subject else { return LockDecision(reason: noRecording) }
        if subject.people.leftOut > 0 { return LockDecision(reason: leftOut) }
        if subject.people.hasSomeoneWithoutRelease { return LockDecision(reason: noRelease) }
        return LockDecision(reason: nil)
    }

    /// The names replaced whatever else the text says: names Ivan marked Mute, and every named person marked "no
    /// release" (who may be named aloud without being in the recording).
    static func alwaysReplaced(_ subject: LockSubject) -> [String] {
        let names = subject.people.mutedNames + subject.people.named.filter { !$0.released }.map(\.name)
        return names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    typealias Tokenizer = @Sendable ([String], [String]) -> (texts: [String], tokens: NameTokens)

    /// The only way to make a `CloudPayload`. Refuses when the recording is locked, then replaces the names that are
    /// always replaced, then checks the result on the data before it is allowed out.
    static func release(_ request: ModelRequest, for subject: LockSubject?) throws -> CloudPayload {
        try release(request, for: subject, tokenize: { NameTokens.tokenize($0, only: $1) })
    }

    /// `tokenize` is replaceable only so a test can plant a name the tokenizer missed and see the check refuse it.
    static func release(_ request: ModelRequest, for subject: LockSubject?, tokenize: Tokenizer) throws -> CloudPayload {
        let decision = decide(subject)
        guard let subject, !decision.isLocked else {
            throw LockRefusal(reason: "The privacy lock refused the request: \(decision.reason ?? noRecording).")
        }
        let made = tokenize([request.system, request.user], alwaysReplaced(subject))
        guard made.texts.count == 2 else { throw LockRefusal(reason: "The privacy check could not read the request.") }
        try check(made.texts, subject: subject)
        return CloudPayload(system: made.texts[0], user: made.texts[1], shape: request.shape, maxTokens: request.maxTokens, tokens: made.tokens)
    }

    /// The adapter's own check, on the text exactly as it would be sent: no muted name, no name of someone marked
    /// "no release", no withheld span. Throws the first problem found.
    static func check(_ texts: [String], subject: LockSubject) throws {
        for text in texts {
            for name in alwaysReplaced(subject) {
                let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: name) + #"(?![\p{L}\p{N}])"#
                if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    throw LockRefusal(reason: "The privacy check found a name that is always replaced, so nothing was sent.")
                }
            }
            for span in subject.withheldSpans {
                let trimmed = span.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, text.range(of: trimmed, options: [.caseInsensitive]) != nil {
                    throw LockRefusal(reason: "The privacy check found words of someone left out, so nothing was sent.")
                }
            }
        }
    }

    /// The key test's request: fixed words, no recording, no name. The only payload made without a
    /// recording.
    static func keyCheck() -> CloudPayload {
        CloudPayload(system: "You answer with JSON only.", user: "Reply with exactly {\"ready\": true}", shape: .check,
                     maxTokens: ModelSettings.maxTokens, tokens: NameTokens())
    }
}

// MARK: Cloud clients

/// A provider that sends text off this Mac. It takes only a `CloudPayload`, so the lock cannot be
/// skipped; it is never a `LanguageModelClient` itself.
protocol CloudModelClient: Sendable {
    var provider: ModelProvider { get }
    var displayName: String { get }
    /// The most it reads at once, in tokens.
    var contextLimit: Int { get }
    func send(_ payload: CloudPayload) async throws -> ModelReply
    /// The key test: `PrivacyLock.keyCheck()` only.
    func check() async -> ProviderCheck
}

/// What the writer talks to for a cloud provider: every request goes through `PrivacyLock.release` for
/// this recording, and the names come back in the answer. A refusal is a failure that is not tried again.
struct LockedCloudClient: LanguageModelClient {
    let inner: any CloudModelClient
    let subject: LockSubject?
    /// Where a refusal's reason is written (Activity's log line); never the text.
    let onRefusal: @Sendable (String) -> Void

    var provider: ModelProvider { inner.provider }
    var displayName: String { inner.displayName }

    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) {
        (ModelSettings.estimatedTokens(request.system + request.user) + request.maxTokens, inner.contextLimit)
    }

    func complete(_ request: ModelRequest) async throws -> ModelReply {
        let payload: CloudPayload
        do {
            payload = try PrivacyLock.release(request, for: subject)
        } catch let refusal as LockRefusal {
            onRefusal(refusal.reason)
            throw ModelFailure(kind: .refused, reason: refusal.reason)
        }
        var reply = try await inner.send(payload)
        reply.text = payload.tokens.restore(reply.text)
        return reply
    }

    func check() async -> ProviderCheck { await inner.check() }
}

/// What a cloud choice turns into when no cloud client may be made: refuses everything.
struct NoCloudClient: LanguageModelClient {
    let provider: ModelProvider
    var displayName: String { provider.title }
    func budget(for request: ModelRequest) async throws -> (needed: Int, limit: Int) { (0, 1) }
    func complete(_ request: ModelRequest) async throws -> ModelReply {
        throw ModelFailure(kind: .refused, reason: "\(provider.title) is only reached through the privacy lock, so nothing was sent.")
    }
    func check() async -> ProviderCheck { ProviderCheck(state: .problem, line: "Nothing was sent.", at: Date()) }
}
