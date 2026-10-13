import Foundation

// The privacy lock (v2 part M5a, docs/v2/PLAN.md M5 and section 2.2), replacing v1's rule in
// `Writer.route`. Two halves:
//
// 1. Which recordings a cloud model may read at all (`PrivacyLock.decide`). It fails closed: only a
//    recording marked as a talk, whose people check has run, in which everyone heard is named and has
//    agreed to cloud models and nobody unnamed appears or speaks, and whose transcript does not name the
//    teacher who has not agreed (v1's rule, kept: START_HERE Mac warning 90 says the lock must stay at
//    least that strict). The people check (faces, part M6a, and voices, M6b) fills `PeopleFacts`; it counts
//    as run only when both steps ran, and every face and voice Ivan has not named is someone unnamed.
//
// 2. What a request may carry (`PrivacyLock.release`), the cloud adapter's own check (warning 19). The
//    only way to make a `CloudPayload`, and a cloud client takes nothing else (`CloudModelClient`), so no
//    code path can send text that has not passed here. It runs the decision again, replaces every name
//    that is not a consenting named person's with a token (`NameTokens`), then reads the result again
//    and refuses if a name, a muted name or a withheld span is still there. A refusal is logged with its
//    reason only, never the text.

/// What the people check found in one recording (`PeopleFacts.from`, part M6b: not checked until both the face
/// step and the voice step ran). Names are Ivan's own naming per recording; nothing here is a face or voice print.
struct PeopleFacts: Sendable, Equatable, Codable {
    struct Named: Sendable, Equatable, Codable {
        var personID: UUID
        var name: String
        var heard: Bool
        var seen: Bool
        /// The person's switch "Cloud models may read their words", from `Person.mayReadInCloud`.
        var cloudConsent: Bool = false
    }

    /// True only when both the face step and the voice step ran (PLAN review item 5): faces alone
    /// could read as "nobody else" on a recording where a student is heard but not seen.
    var checked: Bool
    var named: [Named] = []
    var unnamedSeen: Int = 0
    var unnamedHeard: Int = 0
    /// Names said aloud that Ivan marked Mute (part M6c): always replaced before a cloud request.
    var mutedNames: [String] = []

    static let notChecked = PeopleFacts(checked: false)

    /// The same facts with each named person's cloud switch read from the store, by id. A person not
    /// in `people` counts as not agreed.
    func withConsent(from people: [Person]) -> PeopleFacts {
        var facts = self
        let consent = Dictionary(people.map { ($0.id, $0.mayReadInCloud) }, uniquingKeysWith: { $0 && $1 })
        for index in facts.named.indices { facts.named[index].cloudConsent = consent[facts.named[index].personID] ?? false }
        return facts
    }
}

/// Everything the lock reads about one recording.
struct LockSubject: Sendable, Equatable {
    var kind: RecordingKind
    /// The transcript says "Serenity" (`Privacy.mentionsSerenity`), or an earlier one did.
    var mentionsSerenity: Bool
    var people: PeopleFacts = .notChecked
    /// Words said by someone who has not agreed (from the voice step, part M6b). None may be sent.
    var withheldSpans: [String] = []
}

/// Why the lock keeps a recording on this Mac, or that it does not.
struct LockDecision: Sendable, Equatable {
    /// Written to sit inside a sentence ("this is a class"); nil when a cloud model may read it.
    /// Names no one (design spec C4).
    let reason: String?

    var isLocked: Bool { reason != nil }

    /// The line for the Checks tab: "This is a class, so only models on this Mac read it."
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
    static let isClass = "this is a class"
    static let namesTeacher = "it names a teacher who has not agreed to cloud models"
    static let notChecked = "who appears and speaks in it has not been checked"
    static let unnamed = "someone in it is not named"
    static let notAgreed = "someone heard in it has not agreed to cloud models"

    /// The lock in plain sentences, for Settings, Models and Settings, Privacy. True of what the build does: the
    /// people check (faces and voices, part M6b) feeds it, and a recording nobody named anyone in stays on this Mac.
    static let settingsLine = "A cloud model reads only a talk in which everyone heard is named and has agreed to cloud models, and nobody else appears or speaks. Classes, and recordings where other people appear or speak, are only read by models on this Mac. Prakriti checks who appears and speaks while it makes a recording, and every face and voice you have not named counts as someone else, so until you name the teacher a recording is only read on this Mac. If a task is set to Anthropic or OpenAI, LM Studio does it instead, and the recording says so. Before anything is sent, names are replaced and the text is checked again."

    static func kindReason(_ kind: RecordingKind) -> String? {
        switch kind {
        case .talk: nil
        case .lesson: isClass
        case .conversation: "this is a conversation"
        case .test: "this is marked as a test"
        case .unknown: "it is not marked as a talk yet"
        }
    }

    /// Whether a cloud model may read this recording. The first reason that applies, in order: not a
    /// talk (a class first); the people check has not run; the teacher who has not agreed is named;
    /// anyone unnamed appears or speaks; anyone heard has not agreed. No recording at all is locked too.
    static func decide(_ subject: LockSubject?) -> LockDecision {
        guard let subject else { return LockDecision(reason: noRecording) }
        if let reason = kindReason(subject.kind) { return LockDecision(reason: reason) }
        let people = subject.people
        guard people.checked else { return LockDecision(reason: notChecked) }
        if subject.mentionsSerenity { return LockDecision(reason: namesTeacher) }
        if people.unnamedSeen > 0 || people.unnamedHeard > 0 { return LockDecision(reason: unnamed) }
        if people.named.contains(where: { $0.heard && !$0.cloudConsent }) { return LockDecision(reason: notAgreed) }
        return LockDecision(reason: nil)
    }

    /// The names that may go out as they are: named people who agreed to cloud models.
    static func keptNames(_ subject: LockSubject) -> [String] {
        subject.people.named.filter(\.cloudConsent).map(\.name)
    }

    /// The teacher who has not agreed to cloud models (SCOPE PRV-10). Her name is in the writing prompt
    /// itself, and Apple's tagger missed it there when measured (12 Oct: "The school's teachers are Gabriel
    /// and Serenity." tagged Gabriel only), so it is never left to the tagger.
    static let teacherWithoutConsent = "Serenity"

    /// The names replaced whatever the tagger finds: names Ivan marked Mute, every named person who has
    /// not agreed, and the teacher who has not agreed.
    static func alwaysReplaced(_ subject: LockSubject) -> [String] {
        var names = subject.people.mutedNames + subject.people.named.filter { !$0.cloudConsent }.map(\.name)
        if !keptNames(subject).contains(where: { NameTokens.isKept(teacherWithoutConsent, keep: [$0]) }) { names.append(teacherWithoutConsent) }
        return names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    typealias Tokenizer = @Sendable ([String], [String], [String]) -> (texts: [String], tokens: NameTokens)

    /// The only way to make a `CloudPayload`. Refuses when the recording is locked, then replaces names,
    /// then checks the result on the data before it is allowed out.
    static func release(_ request: ModelRequest, for subject: LockSubject?) throws -> CloudPayload {
        try release(request, for: subject, tokenize: { NameTokens.tokenize($0, keep: $1, always: $2) })
    }

    /// `tokenize` is replaceable only so a test can plant a name the tokenizer missed and see the check
    /// refuse it.
    static func release(_ request: ModelRequest, for subject: LockSubject?, tokenize: Tokenizer) throws -> CloudPayload {
        let decision = decide(subject)
        guard let subject, !decision.isLocked else {
            throw LockRefusal(reason: "The privacy lock refused the request: \(decision.reason ?? noRecording).")
        }
        let keep = keptNames(subject)
        let always = alwaysReplaced(subject)
        let made = tokenize([request.system, request.user], keep, always)
        guard made.texts.count == 2 else { throw LockRefusal(reason: "The privacy check could not read the request.") }
        try check(made.texts, subject: subject)
        return CloudPayload(system: made.texts[0], user: made.texts[1], shape: request.shape, maxTokens: request.maxTokens, tokens: made.tokens)
    }

    /// The adapter's own check, on the text exactly as it would be sent: no name the tagger finds that is
    /// not a consenting named person's, no muted name, no withheld span. Throws the first problem found.
    static func check(_ texts: [String], subject: LockSubject) throws {
        let keep = keptNames(subject)
        for text in texts {
            let left = NameTokens.findNames(in: text).filter { !NameTokens.isKept($0, keep: keep) }
            if !left.isEmpty {
                throw LockRefusal(reason: "The privacy check found \(Format.count(left.count, "name")) the tokens did not replace, so nothing was sent.")
            }
            for name in alwaysReplaced(subject) {
                let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: name) + #"(?![\p{L}\p{N}])"#
                if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    throw LockRefusal(reason: "The privacy check found a name that is always replaced, so nothing was sent.")
                }
            }
            for span in subject.withheldSpans {
                let trimmed = span.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, text.range(of: trimmed, options: [.caseInsensitive]) != nil {
                    throw LockRefusal(reason: "The privacy check found words of someone who has not agreed to cloud models, so nothing was sent.")
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
