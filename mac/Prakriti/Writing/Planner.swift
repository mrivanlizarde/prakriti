import Foundation

// The model's two jobs in planning the edit (v2 part M9c, docs/v2/PLAN.md M9; research-edit-engine.md 3.1 to 3.3): the beats of a
// recording, once per transcript, and the reading of a direction's words the rules table could not read. Both run on the model
// chosen for "Planning the edit" in Settings, Models, under the privacy lock exactly as the writing does (`Writer`): a cloud
// provider is reached only through `LockedCloudClient`, so every request passes `PrivacyLock.release`, and a recording the lock
// keeps on this Mac is planned by LM Studio instead. Nothing a model answers is used before Swift has checked it (`BeatCheck`,
// `DirectionModelCheck`).
//
// The beats request asks for temperature 0 and a fixed seed (LM Studio and Ollama), recorded in `beats.json`; whether LM Studio
// honours the seed for this model was measured on the build day (BUILD-LOG, v2 part M9c), and the file is what keeps two runs
// of a check the same either way.

struct Planner: Sendable {
    let setup: WritingSetup
    let log: AppLog?
    let subject: LockSubject
    let fileName: String

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// The provider "Planning the edit" really uses, and the line for the log when the lock changed it.
    var route: (provider: ModelProvider, lockLine: String?) {
        let chosen = setup.chosen(.planning)
        let reason = PrivacyLock.decide(subject).reason
        let used = ModelRouting.provider(chosen: chosen, locked: reason != nil)
        guard used != chosen else { return (used, nil) }
        return (used, "privacy lock. \((reason ?? "").capitalizedFirst), so planning the edit uses \(used.title) instead of \(chosen.title). Nothing is sent to \(chosen.title).")
    }

    /// Gives back what the model took (LM Studio unloads a model Prakriti loaded). Called once both jobs are done.
    func release(_ client: any LanguageModelClient) async {
        if let line = await client.release() { log?.write("\(fileName): \(line)") }
    }

    func client() -> any LanguageModelClient {
        let (provider, lockLine) = route
        if let lockLine { log?.write("\(fileName): \(lockLine)") }
        if provider.isLocal { return setup.makeClient(provider, setup) }
        let log = self.log, fileName = self.fileName
        return LockedCloudClient(inner: setup.makeCloudClient(provider, setup), subject: subject,
                                 onRefusal: { reason in log?.write("\(fileName): \(reason)") })
    }

    // MARK: The beats

    static let beatsSystem = """
        You plan the edit of a recorded talk by a yoga teacher. Read the numbered sentences and divide the whole talk into beats: \
        runs of consecutive sentences about one point, usually 30 seconds to 3 minutes each (a 15-minute talk has about 8 to 20). \
        Every sentence belongs to exactly one beat, and the beats are in the talk's order.

        For each beat give:
        - "first" and "last": the ids of its first and last sentences, copied exactly ("s1").
        - "summary": 2 to 6 plain words saying what it is about. Never a person's name. Never a private matter: no illness, \
        death, family matter or money trouble, even when the talk mentions one.
        - "scores": a whole number from 0 to 3 for each of "motivating", "enlightening", "practical", "story", "humor", \
        "philosophy", "technique", "personal" (0 none, 3 the strongest in the talk).
        - "kind": one of "welcome", "housekeeping", "teaching", "story", "practice", "question", "closing".
        - "standsAlone": true when it makes sense without the beats before it.
        - "dependsOn": the ids of earlier beats it needs, numbered by you in order ("b1" is the first beat).
        - "keyLine": the beat's strongest line, 5 to 20 words copied exactly from its own sentences (same words, same order), or "".
        - "hookCandidate": true when that key line would open the video well on its own.
        - "terms": Sanskrit or yoga terms the beat explains, as said.
        - "thesis": true for the one beat that states the talk's main point; false for every other.

        Answer with one JSON object and nothing else, in exactly this shape:
        {"beats": [{"id": "b1", "first": "s1", "last": "s9", "summary": "", "scores": {"motivating": 0, "enlightening": 0, "practical": 0, \
        "story": 0, "humor": 0, "philosophy": 0, "technique": 0, "personal": 0}, "kind": "welcome", "standsAlone": true, "dependsOn": [], \
        "keyLine": "", "hookCandidate": false, "terms": [], "thesis": false}]}
        """

    static func beatsRequest(_ words: [PlanWord], kind: RecordingKind, duration: Double) -> ModelRequest {
        let sentences = BeatSentence.from(words)
        var user = "\(Writer.kindLine(kind)). \(Format.timecode(duration)) long, \(sentences.count) sentences.\n\n"
        user += sentences.map { "\($0.id) [\(WritingText.stamp($0.start))] \($0.text)" }.joined(separator: "\n")
        return ModelRequest(system: beatsSystem, user: user, shape: .planning, deterministic: true)
    }

    /// Asks for the beats, checks them, tries again on a cut-off, empty or unusable answer (up to the setup's tries).
    func beats(words: [PlanWord], recording: String, transcriptSHA256: String, kind: RecordingKind, duration: Double,
               client: any LanguageModelClient, onRequest: @Sendable () -> Void = {}) async throws -> BeatsFile {
        let started = ContinuousClock.now
        let request = Self.beatsRequest(words, kind: kind, duration: duration)
        if let problem = try await Writer.fits(request, client: client, task: .planning) { throw Failure(reason: problem) }
        log?.write("\(fileName): reading the parts of the talk with \(client.displayName): \(Format.count(BeatSentence.from(words).count, "sentence")), "
                   + "about \(Format.number(ModelSettings.estimatedTokens(request.system + request.user))) tokens to read.")
        try await client.prepare()
        if let loaded = await client.takeLoadLine() { log?.write("\(fileName): \(loaded)") }
        var attempts = 0
        var last = "No answer came back."
        while attempts < max(1, setup.maxAttempts) {
            attempts += 1
            do {
                onRequest()
                let reply = try await client.complete(request)
                let checked = try BeatCheck.check(reply.text, words: words)
                let local = client.provider.isLocal && client.provider != .appleOnDevice
                log?.write("\(fileName): try \(attempts) passed in " + String(format: "%.0f s", reply.seconds)
                           + " (\(reply.promptTokens.map(String.init) ?? "?") tokens read, \(reply.completionTokens.map(String.init) ?? "?") written"
                           + (reply.costUSD.map { ", cost \(CloudPricing.text($0))" } ?? "") + "): \(Format.count(checked.beats.count, "beat"))"
                           + (checked.notes.isEmpty ? "." : ". " + checked.notes.joined(separator: " ")))
                return BeatsFile(recording: recording, transcriptSHA256: transcriptSHA256, madeAt: Date(), by: client.displayName,
                                 provider: client.provider.rawValue, temperature: local ? 0 : nil, seed: local ? ModelSettings.seed : nil,
                                 seconds: ModelHTTP.seconds(since: started), attempts: attempts, beats: checked.beats, notes: checked.notes)
            } catch let failure as ModelFailure {
                last = failure.reason
                log?.write("\(fileName): reading the parts, try \(attempts) did not pass. \(failure.reason)" + (failure.detail.map { " (\($0))" } ?? ""))
                if !failure.retryable { break }
            } catch let failure as BeatCheck.Failure {
                last = failure.reason
                log?.write("\(fileName): reading the parts, try \(attempts) did not pass its check. \(failure.reason)")
            }
        }
        throw Failure(reason: "\(client.displayName) did not give usable parts of the talk in \(Format.count(attempts, "try", "tries")). The last: \(last)")
    }

    // MARK: A direction's words

    static let directionSystem = """
        You turn an editor's words about a video of a talk into settings. Answer with one JSON object and nothing else, using only \
        these keys, and each only when the words ask for it:
        "style": "clear", "calm", "energetic" or "story". "pace": a whole number from -2 to 2 (more is faster). \
        "cutDensity": a whole number from -2 to 2 (more is more cuts). "punchIns": "off", "subtle" or "punchy". \
        "text": "off", "subtle" or "bold" (words on screen). "captionsBurned": true or false. "targetSeconds": the length asked for, in seconds. \
        "focus": an object of tags to weights from 0.5 to 3, where the tags are motivating, enlightening, practical, story, humor, \
        philosophy, technique, personal; a topic that is not a tag is a key with weight 1. "avoid": a list of tags or topics to leave out. \
        "keepWhole": a list of topics to keep uncut. "hook": true or false (open on the strongest line).
        Who appears in the video, hiding or blurring anyone, consent and publishing are never settings: leave them out. \
        If the words ask for nothing these keys can hold, answer {}.
        """

    /// The model's reading of the clauses the rules could not read, checked: any key outside the vocabulary refuses it whole.
    func direction(_ unread: [String], client: any LanguageModelClient, onRequest: @Sendable () -> Void = {}) async throws -> (fields: DirectionFields, by: String) {
        let request = ModelRequest(system: Self.directionSystem, user: "The editor wrote:\n\n" + unread.joined(separator: "\n"), shape: .planning,
                                   deterministic: true)
        try await client.prepare()
        if let loaded = await client.takeLoadLine() { log?.write("\(fileName): \(loaded)") }
        var attempts = 0
        var last = "No answer came back."
        while attempts < max(1, setup.maxAttempts) {
            attempts += 1
            do {
                onRequest()
                let reply = try await client.complete(request)
                let fields = try DirectionModelCheck.check(reply.text)
                log?.write("\(fileName): the direction's own words read by \(client.displayName) in " + String(format: "%.0f s.", reply.seconds))
                return (fields, client.displayName)
            } catch let failure as ModelFailure {
                last = failure.reason
                if !failure.retryable { break }
            } catch let refusal as DirectionModelCheck.Refusal {
                // A reading outside the vocabulary is refused whole and not asked again: the same words would get the same answer.
                log?.write("\(fileName): the direction's reading was refused. \(refusal.reason)")
                throw Failure(reason: refusal.reason)
            }
        }
        throw Failure(reason: last)
    }
}
