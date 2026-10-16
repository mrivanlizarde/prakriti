import Foundation

// The model's one sentence about a moment from another recording (v2 part M12a, docs/v2/PLAN.md M12): does it support the point
// without contradicting it. It runs on the model chosen for "Choosing moments" in Settings, Models, under the privacy lock exactly as
// the writing and the planning do: a cloud provider is reached only through `LockedCloudClient`, so every request passes
// `PrivacyLock.release`, for a subject that holds the people of BOTH recordings (the request carries words of each), and a pair the
// lock keeps on this Mac is read by LM Studio instead. Nothing the model answers is used before Swift has checked it
// (`MomentJudge.check`). The model never chooses which moments are candidates (that is the embeddings' similarity, on this Mac) and
// never adds anything.

extension LockSubject {
    /// The lock's subject for a request that carries words of two recordings: everyone in either, every muted name and every person
    /// left out, so the lock keeps the pair on this Mac when it would keep either.
    func joined(with other: LockSubject) -> LockSubject {
        var people = self.people
        people.checked = self.people.checked && other.people.checked
        people.named += other.people.named
        people.unnamedSeen += other.people.unnamedSeen
        people.unnamedHeard += other.people.unnamedHeard
        people.mutedNames += other.people.mutedNames
        people.leftOut += other.people.leftOut
        return LockSubject(people: people, withheldSpans: withheldSpans + other.withheldSpans)
    }
}

struct MomentJudge: MomentJudging {
    let setup: WritingSetup
    let log: AppLog?
    /// The recording being edited, and each recording searched, as the lock reads them. Each request carries words of the
    /// recording being edited and of one other, so the lock decides on that pair (`LockSubject.joined`).
    let current: LockSubject
    let sources: [UUID: LockSubject]
    let fileName: String
    /// Counts each request as it is sent (the acceptance and the tests count them under the lock).
    let onRequest: @Sendable (ModelProvider) -> Void
    /// The client on this Mac (the choice when it is local, else LM Studio for a pair the lock keeps here), made once.
    let local: any LanguageModelClient
    /// The cloud provider chosen, reached only through `LockedCloudClient` for each pair; nil when the choice is on this Mac.
    let cloud: (any CloudModelClient)?

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// The provider "Choosing moments" really uses for this subject, and the log line when the lock changed it.
    static func route(setup: WritingSetup, subject: LockSubject) -> (provider: ModelProvider, lockLine: String?) {
        let chosen = setup.chosen(.choosingMoments)
        let reason = PrivacyLock.decide(subject).reason
        let used = ModelRouting.provider(chosen: chosen, locked: reason != nil)
        guard used != chosen else { return (used, nil) }
        return (used, "privacy lock. \((reason ?? "").capitalizedFirst), so choosing moments uses \(used.title) instead of \(chosen.title). Nothing is sent to \(chosen.title).")
    }

    init(setup: WritingSetup, log: AppLog?, current: LockSubject, sources: [UUID: LockSubject], fileName: String,
         onRequest: @escaping @Sendable (ModelProvider) -> Void = { _ in }) {
        self.setup = setup
        self.log = log
        self.current = current
        self.sources = sources
        self.fileName = fileName
        self.onRequest = onRequest
        let chosen = setup.chosen(.choosingMoments)
        local = setup.makeClient(chosen.isLocal ? chosen : ModelRouting.provider(chosen: chosen, locked: true), setup)
        cloud = chosen.isLocal ? nil : setup.makeCloudClient(chosen, setup)
    }

    /// The client for the pair of the recording being edited and `source`.
    func client(for source: UUID) -> any LanguageModelClient {
        let subject = current.joined(with: sources[source] ?? LockSubject(people: .notChecked))
        let (provider, lockLine) = Self.route(setup: setup, subject: subject)
        if let lockLine { log?.write("\(fileName): \(lockLine)") }
        guard !provider.isLocal, let cloud else { return local }
        let log = self.log, fileName = self.fileName
        return LockedCloudClient(inner: cloud, subject: subject, onRefusal: { reason in log?.write("\(fileName): \(reason)") })
    }

    /// The model chosen, for the sheet and the log.
    var displayName: String { cloud?.displayName ?? local.displayName }

    static let system = """
        You help an editor of a video of a yoga teacher's talk. The editor may add a short moment from another recording of the same \
        teacher where it backs up a point. Read the point, from the video being edited, and the moment, from the other recording.

        The moment supports the point when it makes the same point, or gives a reason, an example or a practice for it. It contradicts \
        the point when it says the opposite or something that cannot be true at the same time. A moment about something else does not \
        support it.

        Answer with one JSON object and nothing else, in exactly this shape:
        {"supports": true, "contradicts": false, "why": ""}
        "why" is one plain sentence of at most 20 words saying how the moment relates to the point, as a fact. No praise, no names of \
        people, no dashes.
        """

    static func request(point: String, moment: String, momentDay: String) -> ModelRequest {
        ModelRequest(system: system, user: "The point, from the video being edited:\n\(point)\n\nThe moment, from the recording of \(momentDay):\n\(moment)",
                     shape: .planning, maxTokens: ModelSettings.maxTokens, deterministic: true)
    }

    /// Checks the answer: JSON with two true-or-false values and one sentence of at most 30 words. Dashes become commas.
    static func check(_ text: String) throws -> MomentVerdict {
        guard let object = WritingCheck.jsonObject(text), let supports = object["supports"] as? Bool else {
            throw Failure(reason: "The answer was not the JSON asked for.")
        }
        let contradicts = object["contradicts"] as? Bool ?? false
        var why = (object["why"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        why = why.replacingOccurrences(of: " \u{2014} ", with: ", ").replacingOccurrences(of: "\u{2014}", with: ", ")
            .replacingOccurrences(of: " \u{2013} ", with: ", ").replacingOccurrences(of: "\u{2013}", with: ", ")
        guard !why.isEmpty else { throw Failure(reason: "The answer had no sentence saying why.") }
        guard why.split(whereSeparator: \.isWhitespace).count <= 30 else { throw Failure(reason: "The sentence saying why was longer than 30 words.") }
        if let last = why.last, !".!?".contains(last) { why += "." }
        return MomentVerdict(supports: supports, contradicts: contradicts, why: why.capitalizedFirst)
    }

    /// Gives back what the model on this Mac took (LM Studio unloads a model Prakriti loaded). Called once the search is done.
    func release() async {
        if let line = await local.release() { log?.write("\(fileName): \(line)") }
    }

    func judge(point: String, moment: String, momentDay: String, source: UUID) async throws -> MomentVerdict {
        let request = Self.request(point: point, moment: moment, momentDay: momentDay)
        let model = self.client(for: source)
        if model.provider.isLocal {
            try await model.prepare()
            if let loaded = await model.takeLoadLine() { log?.write("\(fileName): \(loaded)") }
        }
        var attempts = 0
        var last = "No answer came back."
        while attempts < max(1, setup.maxAttempts) {
            attempts += 1
            do {
                onRequest(model.provider)
                let reply = try await model.complete(request)
                let verdict = try Self.check(reply.text)
                log?.write("\(fileName): a moment from \(momentDay) read by \(model.displayName) in " + String(format: "%.0f s", reply.seconds)
                           + (reply.costUSD.map { ", cost \(CloudPricing.text($0))" } ?? "") + ": " + (verdict.supports && !verdict.contradicts ? "supports. " : "does not support. ") + verdict.why)
                return verdict
            } catch let failure as ModelFailure {
                last = failure.reason
                log?.write("\(fileName): choosing moments, try \(attempts) did not pass. \(failure.reason)")
                if !failure.retryable { break }
            } catch let failure as Failure {
                last = failure.reason
                log?.write("\(fileName): choosing moments, try \(attempts) did not pass its check. \(failure.reason)")
            }
        }
        throw Failure(reason: "\(model.displayName) did not give a usable answer about a moment in \(Format.count(attempts, "try", "tries")). The last: \(last)")
    }
}
