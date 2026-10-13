import Foundation

// Titles, show notes and chapters (milestone 6): written by the model chosen for each task on the
// Models screen, then checked in Swift before anything is kept (LOCAL-MODEL.md rule 4: never trust
// the JSON, even when a schema was asked for).
//
// - The model reads the episode's transcript, one line per sentence with its time on the episode's
//   clock, the words of anything cut already gone (EpisodeTranscript.cues). Reason: a chapter or a
//   quote must never name a student whose question was cut, and the times must match the audio.
// - Every chapter must start at a time that is one of the transcript's own line times; one that
//   does not is left out and counted. Every quote in the accuracy checklist must be found word for
//   word in transcript.txt; one that is not is left out and counted (SCOPE 13, the evidence check).
// - The privacy lock (PrivacyLock.swift, v2 part M5a): a cloud model reads only a talk whose people
//   check ran and found no one unnamed and no one heard who has not agreed, and whose transcript does not
//   name the teacher who has not agreed. Until the people check exists (part M6) that is no real
//   recording. If the Claude API is chosen for a task on a locked recording, LM Studio does that task
//   instead, and the files and the page say so. Every cloud request goes through
//   `PrivacyLock.release` (names replaced by tokens, the text checked again) inside `LockedCloudClient`.
// - A reply cut off at its length, an empty reply, or JSON that fails the checks is tried again, up
//   to three times, always as one system and one user message (LOCAL-MODEL.md rules 2 and 3).
// - No em dash or en dash reaches a title, the notes or a chapter (Ivan's standing rule): each is
//   replaced with a comma and counted. Quotes are never changed; a quote with a dash is simply not
//   in the transcript.

/// The privacy lock's facts.
enum Privacy {
    /// "Serenity" as a whole word, in any case. A false alarm (the word used for calm) only keeps the
    /// text on this Mac, which is the safe direction.
    static func mentionsSerenity(_ text: String) -> Bool {
        text.range(of: #"\bserenity\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

}

extension ModelRouting {
    /// The provider a task really uses: a cloud choice becomes LM Studio when the recording is locked.
    static func provider(chosen: ModelProvider, locked: Bool) -> ModelProvider {
        locked && !chosen.isLocal ? .lmStudio : chosen
    }
}

/// One line the model reads: a sentence, its time on the episode's clock, and that time as text.
struct WritingLine: Equatable, Sendable {
    let start: Double
    let end: Double
    let label: String
    let text: String

    static func lines(_ cues: [TranscriptFiles.Cue]) -> [WritingLine] {
        cues.compactMap { cue in
            let text = cue.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : WritingLine(start: cue.start, end: cue.end, label: WritingText.stamp(cue.start), text: text)
        }
    }
}

enum WritingText {
    /// A line's time as the model reads and writes it: "4:07", "1:02:03". Rounded down, so a line
    /// at 59.6 s reads "0:59", never a second it has not reached.
    static func stamp(_ seconds: Double) -> String {
        let s = Int(max(0, seconds).rounded(.down))
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }

    /// Text compared for quotes: runs of whitespace become one space, typographic quotes and
    /// apostrophes become plain ones. Nothing else changes: case, spelling and punctuation count.
    static func normalized(_ text: String) -> String {
        var s = text.precomposedStringWithCanonicalMapping
        for (from, to) in [("\u{2019}", "'"), ("\u{2018}", "'"), ("\u{201C}", "\""), ("\u{201D}", "\"")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// A quote as the model gave it, without the quotation marks or ellipses around it. The words
    /// inside are left exactly as they are.
    static func bareQuote(_ text: String) -> String {
        var s = normalized(text)
        let edges = CharacterSet(charactersIn: "\"'\u{2026}").union(.whitespaces)
        while true {
            let before = s
            s = s.trimmingCharacters(in: edges)
            if s.hasPrefix("...") { s = String(s.dropFirst(3)) }
            if s.hasSuffix("...") { s = String(s.dropLast(3)) }
            if s == before { break }
        }
        return s
    }

    /// Replaces each em dash and en dash (with any spaces around it) with a comma and a space.
    /// Returns the text and how many were replaced.
    static func withoutDashes(_ text: String) -> (String, Int) {
        var count = 0
        let pattern = try? NSRegularExpression(pattern: "\\s*[\u{2014}\u{2013}]\\s*")
        let range = NSRange(text.startIndex..., in: text)
        count = pattern?.numberOfMatches(in: text, range: range) ?? 0
        guard count > 0, let pattern else { return (text, 0) }
        var s = pattern.stringByReplacingMatches(in: text, range: range, withTemplate: ", ")
        s = s.replacingOccurrences(of: ", ,", with: ",").replacingOccurrences(of: ",,", with: ",")
        return (s.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces)), count)
    }

    static func words(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

/// How many chapters and claims to ask for, from the talk's length (SCOPE PKG-05 and ACC-01):
/// chapters at least 2 minutes long, at least three, no more than six an hour; five to ten claims.
/// A short clip gets one or two chapters and a few claims.
struct WritingRules: Equatable, Sendable {
    var minChapters: Int
    var maxChapters: Int
    var minClaims: Int
    var maxClaims: Int
    static let chapterGap = 120.0
    static let shortTalk = 360.0
    static let titleLimit = 60
    /// Four title options: the writer's pick first, then three alternatives (11 Oct).
    static let titleOptions = 4
    static let chapterTitleWords = 4
    static let chapterTitleLimit = 45
    static let shortestQuote = 4

    static func forLength(_ seconds: Double) -> WritingRules {
        if seconds < shortTalk {
            return WritingRules(minChapters: 1, maxChapters: max(1, min(2, Int(seconds / chapterGap))), minClaims: 1, maxClaims: 5)
        }
        let perHour = Int((seconds / 3600 * 6).rounded(.up))
        let byGap = Int(seconds / chapterGap)
        return WritingRules(minChapters: 3, maxChapters: max(3, min(perHour, byGap)), minClaims: 5, maxClaims: 10)
    }
}

/// A chapter, its start on the episode's clock.
struct WrittenChapter: Codable, Equatable, Sendable {
    var start: Double
    var title: String
    var label: String { WritingText.stamp(start) }
}

/// One claim of the accuracy checklist, with the speaker's words for it, found word for word in the
/// transcript, and the time of the line it starts in.
struct CheckedClaim: Codable, Equatable, Sendable {
    var claim: String
    var quote: String
    var at: Double?
}

/// The three places a podcast episode is shared by hand (11 Oct), each with its own length.
enum SocialPlatform: String, Codable, CaseIterable, Sendable {
    case instagram, linkedin, x

    var title: String {
        switch self {
        case .instagram: "Instagram"
        case .linkedin: "LinkedIn"
        case .x: "X and Threads"
        }
    }

    /// The keys a model may use for it in its answer.
    var keys: [String] {
        switch self {
        case .instagram: ["instagram", "Instagram"]
        case .linkedin: ["linkedin", "LinkedIn", "linked_in"]
        case .x: ["x", "X", "x_threads", "threads", "twitter"]
        }
    }

    /// The platform's own limit on a post, in characters: Instagram 2,200, LinkedIn 3,000, X 280
    /// (Threads takes 500, so a post that fits X fits both). A caption is kept under it: one at or over
    /// it is cut back to the whole sentences that fit, or left out.
    var limit: Int {
        switch self {
        case .instagram: 2_200
        case .linkedin: 3_000
        case .x: 280
        }
    }

    /// Instagram is the only one given hashtags, at most five (Ivan's brief, 11 Oct).
    static let hashtagLimit = 5
}

/// One social caption, checked: the words to post, Instagram's hashtags, and a pull quote, one
/// sentence of the teacher's own found word for word in one line of the transcript (left out when
/// it is not), with that line's time in the episode.
struct SocialCaption: Codable, Equatable, Sendable {
    var platform: SocialPlatform
    var text: String
    var hashtags: [String] = []
    var pullQuote: String?
    var pullQuoteAt: Double?

    /// What is pasted: the caption, then the hashtags on a line of their own.
    var post: String {
        hashtags.isEmpty ? text : text + "\n\n" + hashtags.map { "#" + $0 }.joined(separator: " ")
    }
}

/// What was written for one recording, after the checks. Saved as titles-notes-chapters.json beside
/// the episode (with the model's own answer, for the record) and on the recording, and laid out for
/// reading in show-notes.md.
struct WrittenPackage: Codable, Equatable, Sendable {
    var titles: [String]
    var showNotes: String
    var chapters: [WrittenChapter]
    var checklist: [CheckedClaim]
    var tags: [String] = []
    var summary: String?
    /// "Qwen3.8-27B in LM Studio"
    var writtenBy: String
    var writingProvider: String
    var taggedBy: String?
    var summarizedBy: String?
    /// "This recording mentions Serenity", "This is a class", or nil.
    var lockReason: String?
    /// The tasks whose chosen provider was the Claude API but ran on this Mac because of the lock.
    var lockedTasks: [String] = []
    var writtenAt: Date
    /// The whole writing step, every task and try.
    var seconds: Double
    /// Tries the writing task took (one is the first answer passing every check).
    var attempts: Int
    var writingSeconds: Double
    var promptTokens: Int?
    var completionTokens: Int?
    var reasoningTokens: Int?
    /// Quotes the model gave that are not in the transcript word for word: left out.
    var leftOutQuotes: [String] = []
    /// Chapters whose time is not one of the transcript's line times: left out.
    var leftOutChapters: Int = 0
    /// Plain sentences on what the checks changed or noticed.
    var notes: [String] = []
    /// "episode" when the times are the episode's, "recording" when nothing was cut or added.
    var clock: String
    /// The model's own answer to the writing task, as it came (kept in the JSON file, for the record).
    var modelAnswer: String?
    /// Social captions for sharing the episode (10 Oct), drafts to post by hand. Optional so a
    /// package written before them still reads; any words they quote were found in the transcript.
    var captions: [String]?
    /// Captions left out because they quoted words the transcript does not have.
    var leftOutCaptions: Int?
    /// The episode text (11 Oct): a one-line summary of at most 160 characters, keywords, and one
    /// caption per platform with its pull quote. Optional so a package written before still reads.
    var oneLine: String?
    var keywords: [String]?
    var social: [SocialCaption]?
    /// Pull quotes the model gave that are not in one line of the transcript word for word.
    var leftOutPullQuotes: [String]?

    /// The captions to show: one per platform, else the plain captions of a package written before
    /// 11 Oct.
    var captionTexts: [String] { social.map { $0.map(\.text) } ?? captions ?? [] }

    static let fileName = "titles-notes-chapters.json"
    static let notesFileName = "show-notes.md"
    static var fileNames: Set<String> { [fileName, notesFileName] }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String?) -> WrittenPackage? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WrittenPackage.self, from: data)
    }

    /// The package without the model's raw answer, as kept on the recording in the store.
    var stored: WrittenPackage {
        var copy = self
        copy.modelAnswer = nil
        return copy
    }

    /// show-notes.md: the draft Ivan reads and edits. Titles, the notes, the chapters, then the
    /// checklist for review. Placeholders say plainly what is not chosen yet; nothing is invented.
    func markdown(label: String, fileName source: String) -> String {
        var text = "# \(label): titles, show notes and chapters\n\n"
        text += "A draft written on this Mac by \(writtenBy) on \(Format.dayAndTime(writtenAt)), from the transcript of \(source)"
        text += clock == "episode" ? " as the episode plays it. Times are in the episode." : ". Times are in the recording."
        text += " Read it against the episode before using any of it. **Nothing has been published.**\n"
        if let lockReason { text += "\n\(lockReason.capitalizedFirst), so it was written by a model on this Mac only.\n" }
        text += "\n## Title options\n\n"
        for (index, title) in titles.enumerated() { text += "\(index + 1). \(title)\n" }
        if let oneLine, !oneLine.isEmpty { text += "\n## One-line summary\n\n\(oneLine)\n" }
        text += "\n## Show notes\n\n\(showNotes)\n"
        text += "\n## Chapters\n\n"
        for chapter in chapters { text += "- \(chapter.label) \(chapter.title)\n" }
        text += "\n[The call to action is yours to set, in Settings, Outputs, under Podcast-ready episode; none is written here. "
            + "The address for questions or removal requests is not chosen yet: SCOPE PKG-04 leaves it open for Gabriel and Serenity.]\n"
        if let keywords, !keywords.isEmpty { text += "\n## Keywords\n\n" + keywords.joined(separator: ", ") + "\n" }
        if let social, !social.isEmpty {
            text += "\n## Social captions, drafts to post by hand\n\n"
            for caption in social {
                text += "### \(caption.platform.title)\n\n\(caption.text)\n"
                if !caption.hashtags.isEmpty { text += "\n" + caption.hashtags.map { "\\#" + $0 }.joined(separator: " ") + "\n" }
                if let quote = caption.pullQuote {
                    text += "\n> \u{201C}\(quote)\u{201D}" + (caption.pullQuoteAt.map { " (\(WritingText.stamp($0)))" } ?? "") + "\n"
                }
                text += "\n"
            }
        } else if let captions, !captions.isEmpty {
            text += "\n## Social captions, drafts to post by hand\n\n"
            for (index, caption) in captions.enumerated() { text += "\(index + 1). \(caption)\n" }
        }
        if !tags.isEmpty { text += "\n## Tags\n\n" + tags.joined(separator: ", ") + "\n" }
        if let summary, !summary.isEmpty { text += "\n## Summary\n\n\(summary)\n" }
        text += "\n## Accuracy checklist, for review\n\n"
        text += "Each quote below was found word for word in the transcript. Check each claim before anything is published.\n\n"
        for item in checklist {
            text += "- **\(item.claim)**" + (item.at.map { " (\(WritingText.stamp($0)))" } ?? "") + "\n  \"\(item.quote)\"\n"
        }
        var checks: [String] = []
        if leftOutQuotes.count > 0 { checks.append("\(Format.count(leftOutQuotes.count, "quote")) the model gave \(leftOutQuotes.count == 1 ? "was" : "were") not in the transcript word for word, so \(leftOutQuotes.count == 1 ? "it was" : "they were") left out.") }
        if leftOutChapters > 0 { checks.append("\(Format.count(leftOutChapters, "chapter")) did not start at a time in the transcript, so \(leftOutChapters == 1 ? "it was" : "they were") left out.") }
        if let left = leftOutCaptions, left > 0 { checks.append("\(Format.count(left, "social caption")) broke a check (named below, or quoted words the transcript does not have), so \(left == 1 ? "it was" : "they were") left out.") }
        if let left = leftOutPullQuotes, !left.isEmpty { checks.append("\(Format.count(left.count, "pull quote")) \(left.count == 1 ? "was" : "were") not one line of the transcript word for word, so \(left.count == 1 ? "it was" : "they were") left out.") }
        checks += notes
        if !checks.isEmpty { text += "\n## What the checks changed\n\n" + checks.map { "- " + $0 }.joined(separator: "\n") + "\n" }
        return text
    }
}

/// What to write with: the provider chosen for each task and how to reach each one. Built from the
/// Models screen for each run; the Claude API key is read from the Keychain only when a task will
/// use it, and is never written anywhere.
struct WritingSetup: Sendable {
    var providers: [ModelTask: ModelProvider] = [:]
    var lmStudioAddress = AppSettings.defaultLMStudioAddress
    var lmStudioModel = AppSettings.defaultLMStudioModel
    var ollamaAddress = AppSettings.defaultOllamaAddress
    var ollamaModel = ""
    var claudeModel = AppSettings.defaultClaudeModel
    var claudeKey: String?
    var maxAttempts = 3
    /// Makes the client for a provider on this Mac. Tests pass their own to see which provider is asked.
    var makeClient: @Sendable (ModelProvider, WritingSetup) -> any LanguageModelClient = WritingSetup.standardClient
    /// Makes the client for a cloud provider. It takes only a `CloudPayload`; the writer wraps it in
    /// `LockedCloudClient`, so every request passes the privacy lock. Tests pass their own.
    var makeCloudClient: @Sendable (ModelProvider, WritingSetup) -> any CloudModelClient = WritingSetup.standardCloudClient

    func chosen(_ task: ModelTask) -> ModelProvider { providers[task] ?? .lmStudio }

    static func standardClient(_ provider: ModelProvider, _ setup: WritingSetup) -> any LanguageModelClient {
        switch provider {
        case .lmStudio: LMStudioClient(address: setup.lmStudioAddress, model: setup.lmStudioModel)
        case .appleOnDevice: AppleOnDeviceClient()
        case .ollama: OllamaClient(address: setup.ollamaAddress, model: setup.ollamaModel)
        case .claudeAPI: NoCloudClient(provider: provider)
        }
    }

    static func standardCloudClient(_ provider: ModelProvider, _ setup: WritingSetup) -> any CloudModelClient {
        ClaudeClient(model: setup.claudeModel, key: setup.claudeKey)
    }
}

extension LanguageModelClient {
    /// The line LM Studio leaves when it loaded the model. Nil for the others.
    func takeLoadLine() async -> String? {
        if let lmStudio = self as? LMStudioClient { return await lmStudio.consumeLoadLine() }
        return nil
    }
}

/// What the writer reads.
struct WritingInput: Sendable {
    var label: String
    var fileName: String
    var kind: RecordingKind
    /// Serenity is already known to be in it (from an earlier transcript).
    var knownSerenity: Bool
    /// The transcript as the episode plays it, one cue per sentence.
    var cues: [TranscriptFiles.Cue]
    /// What quotes are checked against: transcript.txt beside the episode (or the cues' own text).
    var transcriptText: String
    /// The times are the episode's (something was cut or trimmed) rather than the recording's.
    var followsEpisode: Bool
    /// Who the people check found (part M6); not checked until then, which keeps it on this Mac.
    var people: PeopleFacts = .notChecked

    /// What the privacy lock reads.
    var lockSubject: LockSubject {
        LockSubject(kind: kind, mentionsSerenity: knownSerenity || Privacy.mentionsSerenity(transcriptText), people: people)
    }
}

/// Writes titles, show notes and chapters (the writing task), then tags and a summary (their own
/// tasks), with the provider chosen for each, the privacy lock applied, and every answer checked.
struct Writer: Sendable {
    let setup: WritingSetup
    let log: AppLog?

    struct Outcome: Sendable {
        var package: WrittenPackage?
        /// Why nothing was written, in one plain sentence.
        var problem: String?
        var mentionsSerenity: Bool
        var lockReason: String?
    }

    /// Never throws except when the work is cancelled (Prakriti quitting).
    func write(_ input: WritingInput) async throws -> Outcome {
        let started = ContinuousClock.now
        let lines = WritingLine.lines(input.cues)
        let serenity = input.knownSerenity || Privacy.mentionsSerenity(input.transcriptText)
        let subject = input.lockSubject
        let lockReason = PrivacyLock.decide(subject).reason
        var outcome = Outcome(package: nil, problem: nil, mentionsSerenity: serenity, lockReason: lockReason)
        guard !lines.isEmpty else {
            outcome.problem = "The transcript has no words to write from."
            return outcome
        }

        var clients: [ModelProvider: any LanguageModelClient] = [:]
        func client(_ provider: ModelProvider) -> any LanguageModelClient {
            if let made = clients[provider] { return made }
            let made: any LanguageModelClient
            if provider.isLocal {
                made = setup.makeClient(provider, setup)
            } else {
                // The only way a cloud provider is reached: every request through PrivacyLock.release.
                let log = self.log, fileName = input.fileName
                made = LockedCloudClient(inner: setup.makeCloudClient(provider, setup), subject: subject,
                                         onRefusal: { reason in log?.write("\(fileName): \(reason)") })
            }
            clients[provider] = made
            return made
        }
        func releaseAll() async {
            for made in clients.values {
                if let line = await made.release() { log?.write("\(input.fileName): \(line)") }
            }
        }
        var lockedTasks: [String] = []
        func route(_ task: ModelTask) -> ModelProvider {
            let chosen = setup.chosen(task)
            let used = ModelRouting.provider(chosen: chosen, locked: lockReason != nil)
            if used != chosen {
                lockedTasks.append(task.title.lowercased())
                log?.write("\(input.fileName): privacy lock. \((lockReason ?? "").capitalizedFirst), so \(task.title.lowercased()) uses \(used.title) instead of \(chosen.title). Nothing is sent to Anthropic.")
            }
            return used
        }

        do {
            // 1. Titles, show notes, chapters and the checklist: the task that matters.
            let writer = client(route(.writing))
            let length = lines.last.map(\.end) ?? 0
            let rules = WritingRules.forLength(length)
            let request = Self.writingRequest(input, lines: lines, rules: rules, length: length)
            if let problem = try await Self.fits(request, client: writer, task: .writing) {
                await releaseAll()
                outcome.problem = problem
                return outcome
            }
            log?.write("\(input.fileName): writing titles, show notes and chapters with \(writer.displayName): \(lines.count) lines, "
                       + "about \(Format.number(ModelSettings.estimatedTokens(request.system + request.user))) tokens to read; "
                       + "asking for " + (rules.minChapters == rules.maxChapters ? Format.count(rules.minChapters, "chapter") : "\(rules.minChapters) to \(rules.maxChapters) chapters")
                       + " and \(rules.minClaims) to \(rules.maxClaims) claims.")
            try await writer.prepare()
            if let loaded = await writer.takeLoadLine() { log?.write("\(input.fileName): \(loaded)") }
            var attempts = 0
            var lastFailure: ModelFailure?
            var answer: (reply: ModelReply, checked: WritingCheck.Checked)?
            var writingSeconds = 0.0
            while attempts < max(1, setup.maxAttempts) && answer == nil {
                attempts += 1
                do {
                    let reply = try await writer.complete(request)
                    if let loaded = await writer.takeLoadLine() { log?.write("\(input.fileName): \(loaded)") }
                    writingSeconds += reply.seconds
                    let checked = try WritingCheck.check(reply.text, lines: lines, transcript: input.transcriptText, rules: rules, length: length)
                    answer = (reply, checked)
                    log?.write("\(input.fileName): try \(attempts) passed in " + String(format: "%.0f s", reply.seconds)
                               + " (finish \(reply.finishReason ?? "?"), \(reply.promptTokens.map(String.init) ?? "?") tokens read, "
                               + "\(reply.completionTokens.map(String.init) ?? "?") written of which \(reply.reasoningTokens.map(String.init) ?? "?") thinking): "
                               + "valid JSON, \(checked.titles.count) titles, \(checked.chapters.count) chapters (\(checked.leftOutChapters) left out), "
                               + "\(checked.checklist.count) quotes found word for word (\(checked.leftOutQuotes.count) left out).")
                } catch let failure as ModelFailure {
                    if let loaded = await writer.takeLoadLine() { log?.write("\(input.fileName): \(loaded)") }
                    lastFailure = failure
                    log?.write("\(input.fileName): try \(attempts) of \(setup.maxAttempts) did not pass. \(failure.reason)" + (failure.detail.map { " (\($0))" } ?? ""))
                    if !failure.retryable { break }
                }
            }
            guard let answer else {
                await releaseAll()
                let failure = lastFailure ?? ModelFailure(kind: .invalid, reason: "No answer came back.")
                outcome.problem = failure.retryable
                    ? "\(writer.displayName) did not give a usable answer in \(Format.count(attempts, "try", "tries")). The last: \(failure.reason)"
                    : failure.reason
                return outcome
            }

            // 2. Tags and 3. a summary: their own tasks, and their own providers. A failure here
            //    leaves a note; the titles, notes and chapters are kept.
            var notes = answer.checked.notes
            let tagger = client(route(.tagging))
            var tags: [String] = []
            var taggedBy: String?
            do {
                let offered = WritingCheck.tags(try await shortTask(.tags, client: tagger, lines: lines, fileName: input.fileName))
                tags = offered.filter { CopyRules.flag($0) == nil }
                if tags.count < offered.count {
                    notes.append("\(Format.count(offered.count - tags.count, "tag")) named money, enrollment or an offer, so \(offered.count - tags.count == 1 ? "it was" : "they were") left out.")
                }
                taggedBy = tagger.displayName
            } catch let failure as ModelFailure {
                notes.append("No tags: \(failure.reason)")
            }
            let summarizer = client(route(.summarizing))
            var summary: String?
            var summarizedBy: String?
            do {
                // The summary is written into the MP3 when there is no one-line summary, so it keeps the
                // copy rules too: a sentence about money, enrollment or an offer is taken out.
                if let raw = try await shortTask(.summary, client: summarizer, lines: lines, fileName: input.fileName).first {
                    let screened = CopyRules.withoutFlaggedSentences(WritingText.withoutDashes(raw.trimmingCharacters(in: .whitespacesAndNewlines)).0)
                    summary = screened.text.isEmpty ? nil : screened.text
                    if !screened.removed.isEmpty {
                        notes.append("\(Format.count(screened.removed.count, "sentence")) of the summary named \(screened.removed.joined(separator: "; ")), so \(screened.removed.count == 1 ? "it was" : "they were") taken out.")
                    }
                }
                summarizedBy = summarizer.displayName
            } catch let failure as ModelFailure {
                notes.append("No summary: \(failure.reason)")
            }
            await releaseAll()

            let checked = answer.checked
            outcome.package = WrittenPackage(
                titles: checked.titles, showNotes: checked.showNotes, chapters: checked.chapters, checklist: checked.checklist,
                tags: tags, summary: summary, writtenBy: writer.displayName, writingProvider: writer.provider.rawValue,
                taggedBy: taggedBy, summarizedBy: summarizedBy, lockReason: lockReason, lockedTasks: lockedTasks,
                writtenAt: Date(), seconds: ModelHTTP.seconds(since: started), attempts: attempts, writingSeconds: writingSeconds,
                promptTokens: answer.reply.promptTokens, completionTokens: answer.reply.completionTokens, reasoningTokens: answer.reply.reasoningTokens,
                leftOutQuotes: checked.leftOutQuotes, leftOutChapters: checked.leftOutChapters, notes: notes,
                clock: input.followsEpisode ? "episode" : "recording", modelAnswer: answer.reply.text,
                captions: checked.captions.isEmpty ? nil : checked.captions, leftOutCaptions: checked.leftOutCaptions,
                oneLine: checked.oneLine, keywords: checked.keywords, social: checked.social.isEmpty ? nil : checked.social,
                leftOutPullQuotes: checked.leftOutPullQuotes)
            return outcome
        } catch is CancellationError {
            await releaseAll()
            throw CancellationError()
        } catch let failure as ModelFailure {
            await releaseAll()
            outcome.problem = failure.reason
            return outcome
        } catch {
            await releaseAll()
            outcome.problem = "Writing stopped: \(error.localizedDescription)"
            return outcome
        }
    }

    /// Nil when the request fits the model, else the plain reason it does not.
    static func fits(_ request: ModelRequest, client: any LanguageModelClient, task: ModelTask) async throws -> String? {
        let budget = try await client.budget(for: request)
        guard budget.needed > budget.limit else { return nil }
        return "\(client.displayName) reads at most \(Format.number(budget.limit)) tokens at once, and this transcript needs about "
            + "\(Format.number(budget.needed)) with room to write. Choose LM Studio for \(task.title.lowercased()) on the Models screen."
    }

    // MARK: Tags and summary

    /// Tags or a summary. When the text does not fit Apple's on-device model at once, it is split
    /// into parts that do: each part is tagged (the tags merged by how often they come up) or
    /// summarized (and the summaries then summarized). Other providers read the whole text.
    /// Returns the tags, or one summary.
    func shortTask(_ shape: ModelRequest.Shape, client: any LanguageModelClient, lines: [WritingLine], fileName: String) async throws -> [String] {
        let started = ContinuousClock.now
        let maxTokens = client.provider == .appleOnDevice ? 1_024 : ModelSettings.maxTokens
        func request(_ text: String, combining: Bool = false) -> ModelRequest {
            ModelRequest(system: shape == .tags ? Self.tagsSystem : Self.summarySystem,
                         user: (combining ? "These are summaries of the parts of one talk, in order. Summarize the whole talk from them:\n\n"
                                          : (shape == .tags ? "Tag this talk:\n\n" : "Summarize this talk:\n\n")) + text,
                         shape: shape, maxTokens: maxTokens)
        }
        let whole = lines.map(\.text).joined(separator: " ")
        var parts: [String] = [whole]
        let budget = try await client.budget(for: request(whole))
        if budget.needed > budget.limit {
            guard client.provider == .appleOnDevice else {
                throw ModelFailure(kind: .tooLong, reason: "The transcript is longer than \(client.displayName) reads at once.")
            }
            parts = try await split(lines.map(\.text), fitting: { try await client.budget(for: request($0)) })
        }
        var answers: [[String]] = []
        for part in parts {
            answers.append(try await ask(client, request(part), shape: shape))
        }
        var result = answers.flatMap { $0 }
        if shape == .summary && result.count > 1 {
            result = try await ask(client, request(result.joined(separator: "\n\n"), combining: true), shape: shape)
        }
        log?.write("\(fileName): \(shape == .tags ? "tags" : "summary") by \(client.displayName) in "
                   + String(format: "%.1f s", ModelHTTP.seconds(since: started))
                   + (parts.count > 1 ? ", read in \(parts.count) parts because the whole transcript does not fit at once." : "."))
        return result
    }

    /// One short request, tried up to twice: the tags, or the summary as one string.
    private func ask(_ client: any LanguageModelClient, _ request: ModelRequest, shape: ModelRequest.Shape) async throws -> [String] {
        var last: ModelFailure?
        for _ in 1...2 {
            do {
                let reply = try await client.complete(request)
                if let loaded = await client.takeLoadLine() { log?.write(loaded) }
                let object = WritingCheck.jsonObject(reply.text)
                if shape == .tags, let tags = object?["tags"] as? [Any] {
                    return tags.compactMap { $0 as? String }
                }
                if shape == .summary, let summary = object?["summary"] as? String, !summary.isEmpty {
                    return [summary]
                }
                throw ModelFailure(kind: .invalid, reason: "The answer was not the JSON asked for.")
            } catch let failure as ModelFailure {
                last = failure
                if !failure.retryable { break }
            }
        }
        throw last ?? ModelFailure(kind: .invalid, reason: "No answer came back.")
    }

    /// Splits the lines into the fewest runs, in order, whose requests each fit the model.
    private func split(_ texts: [String], fitting budget: (String) async throws -> (needed: Int, limit: Int)) async throws -> [String] {
        var parts: [String] = []
        var index = 0
        while index < texts.count {
            var count = texts.count - index
            while count > 1 {
                let candidate = texts[index..<(index + count)].joined(separator: " ")
                let b = try await budget(candidate)
                if b.needed <= b.limit { break }
                count = max(1, count * b.limit / max(b.needed, 1) - 1)
            }
            parts.append(texts[index..<(index + count)].joined(separator: " "))
            index += count
        }
        return parts
    }

    // MARK: Prompts

    static let tagsSystem = """
        You tag talks from the Yoga Marga school. Give 3 to 8 short topic tags, one to three words each, in the talk's own terms: \
        the practices, ideas and texts it teaches. Name no person except teachers of the lineage the speaker names. Never name a student. \
        Nothing about anyone's private life: illness, deaths, family, money troubles. No tag about prices, money, earnings, enrollment or offers. \
        Answer with JSON only, in exactly this shape: {"tags": ["", ""]}
        """

    static let summarySystem = """
        You summarize talks from the Yoga Marga school. Write two or three plain sentences, in the third person, that describe what \
        the talk covers. Use only what the transcript says. Describe; never sell. Never use an em dash or an en dash. Never name a student. \
        Leave out anyone's private life: illness, deaths, grief, family matters, money troubles, relationships. Describe the teaching and the school. \
        Never mention prices, fees, money, income, earnings, enrollment, sign-ups or offers, even when the talk does. \
        Answer with JSON only, in exactly this shape: {"summary": ""}
        """

    static func writingSystem(rules: WritingRules, first: String, example: String) -> String {
        let chapters = rules.minChapters == rules.maxChapters ? "exactly \(rules.minChapters)" : "between \(rules.minChapters) and \(rules.maxChapters)"
        let claims = "\(rules.minClaims) to \(rules.maxClaims)"
        return """
            You write the titles, show notes, chapters and social captions for one recording from the Yoga Marga school, from its transcript. \
            The school's teachers are Gabriel and Serenity. Your answer is checked: every time you give must be one of the times \
            in the transcript, and every quote must be found word for word in the transcript.

            Rules for everything you write:
            - Use only what the transcript says. Add no facts, numbers, names, dates, prices or promises that are not in it.
            - Describe; never sell. Plain, calm words. No hype, no exclamation marks, no emoji, and no hashtags except in "hashtags".
            - Never use an em dash or an en dash. Use a comma, a colon or a full stop instead.
            - Never mention prices, fees, money, income, earnings, sales figures, enrollment, sign-ups, registration, discounts, offers or anything free to try, even when the transcript does, and never quote a sentence that does. The checklist is the one exception (below).
            - Name no one except the teacher speaking, the school's teachers, and the teachers, lineages and texts the speaker names as part of the teaching. Never name a student or anyone who asks a question; say "a student" instead.
            - Everything except the checklist leaves out private matters of anyone, the speaker included: illness, deaths, grief, family matters, money troubles, relationships, where someone lives. Describe the teaching and the school, not people's private lives.
            - Call the speaker "the teacher" unless the transcript says who is speaking.

            What to write:
            - "titles": exactly 4 title options, each 60 characters or fewer, each naming the main idea of the talk in a different way. Put the one you would choose first.
            - "one_line": one sentence of at most 150 characters that says what the episode is about.
            - "show_notes": 2 to 4 short paragraphs, as a list of strings, 120 to 220 words in all, in the third person, describing what the talk covers. \
            No chapter list, no links and no closing line: those are added later.
            - "keywords": 5 to 10 keywords or short phrases a listener might search for, in the talk's own terms.
            - "chapters": \(chapters) chapters, in time order, at the talk's main changes of topic. The first chapter starts at \(first). \
            Every "start" must be copied exactly from one of the times in square brackets in the transcript (for example "\(example)"), \
            and chapters must start at least 2 minutes apart. Each chapter "title" is 2 to 4 words (count them; "Breath Before Posture" is 3) and at most 45 characters.
            - "social": one caption for each of three platforms, each a different way into the talk. \
            "instagram": a "caption" of 1 to 3 short sentences, at most 300 characters, and "hashtags": up to 5 hashtags without the # sign, each one word or joined words. \
            "linkedin": a "caption" of 2 to 4 sentences, at most 600 characters, for teachers and people who work in wellness. \
            "x": a "caption" of at most 240 characters in all. \
            Each also has a "pull_quote": one sentence the teacher says that would make someone want to listen, copied exactly from one line of the transcript \
            (6 to 25 words, the same spelling, punctuation and capital letters, without the time in brackets), and "pull_quote_at": the bracketed time of that line. \
            Use a different pull quote for each platform. Captions describe the teaching in plain words; never sell. No hashtags inside a caption, no emoji, \
            no exclamation marks, no links, no "listen now". A caption may quote the teacher only with words copied exactly from one line of the transcript, inside double quotation marks.
            - "checklist": \(claims) claims a listener could check: facts, numbers, dates, names, history, or any health, income or result claim. \
            The speaker's own income, health or result claims belong here, because they must be checked; another person's private matters never do. \
            "claim" says it in your own words, in one sentence, and says only what the quote says. "quote" is the speaker's own words for it, copied exactly from one line of the \
            transcript: 6 to 30 words in a row, with the same spelling, punctuation and capital letters, without the time in brackets. \
            "at" is the bracketed time of that line.

            Answer with one JSON object and nothing else, in exactly this shape:
            {"titles": ["", "", "", ""], "one_line": "", "show_notes": ["", ""], "keywords": ["", ""], "chapters": [{"start": "\(first)", "title": ""}], \
            "social": {"instagram": {"caption": "", "hashtags": [""], "pull_quote": "", "pull_quote_at": "\(first)"}, \
            "linkedin": {"caption": "", "pull_quote": "", "pull_quote_at": "\(first)"}, "x": {"caption": "", "pull_quote": "", "pull_quote_at": "\(first)"}}, \
            "checklist": [{"claim": "", "quote": "", "at": "\(first)"}]}
            """
    }

    static func kindLine(_ kind: RecordingKind) -> String {
        switch kind {
        case .talk: "A talk, one teacher speaking"
        case .lesson: "A class"
        case .conversation: "A conversation"
        case .test: "A test recording"
        case .unknown: "What it is has not been set"
        }
    }

    static func writingRequest(_ input: WritingInput, lines: [WritingLine], rules: WritingRules, length: Double) -> ModelRequest {
        let first = lines.first?.label ?? "0:00"
        let example = lines.count > 2 ? lines[lines.count / 2].label : first
        var user = "Recording: \(input.label). \(kindLine(input.kind)). \(Format.timecode(length)) long. "
        user += input.followsEpisode ? "Times are from the start of the episode.\n\n" : "Times are from the start of the recording.\n\n"
        user += "Transcript, one line per sentence:\n\n"
        user += lines.map { "[\($0.label)] \($0.text)" }.joined(separator: "\n")
        return ModelRequest(system: writingSystem(rules: rules, first: first, example: example), user: user, shape: .writing)
    }
}

/// The checks every writing answer must pass. Structural problems (not JSON, fewer than three
/// titles, too few chapters at real times, no quote found) are failures to try again; anything
/// else is fixed in a way that can be stated, and stated in `notes`.
enum WritingCheck {
    struct Checked: Equatable, Sendable {
        var titles: [String]
        var showNotes: String
        var chapters: [WrittenChapter]
        var checklist: [CheckedClaim]
        var leftOutQuotes: [String]
        var leftOutChapters: Int
        var notes: [String]
        var captions: [String] = []
        var leftOutCaptions = 0
        var oneLine: String?
        var keywords: [String]?
        var social: [SocialCaption] = []
        var leftOutPullQuotes: [String] = []
    }

    /// The longest one-line summary kept (Ivan's brief: under 160 characters; the prompt asks 150).
    static let oneLineLimit = 159
    static let longestPullQuote = 40

    /// The passages a caption puts in quotation marks (straight or curly), without the marks.
    static func quoted(_ text: String) -> [String] {
        let normalized = WritingText.normalized(text)
        var out: [String] = []
        var inside = false
        var current = ""
        for character in normalized {
            if character == "\"" {
                if inside, !current.trimmingCharacters(in: .whitespaces).isEmpty { out.append(current) }
                inside.toggle()
                current = ""
            } else if inside {
                current.append(character)
            }
        }
        return out
    }

    /// Social captions as kept: dashes made commas, exclamation marks made full stops, hashtags and
    /// links dropped, at most 500 characters, and every quoted passage found word for word in the
    /// transcript or the caption is left out. They are optional: none never fails the answer.
    static func captions(_ offered: [String], found: (String) -> Bool) -> (kept: [String], leftOut: Int, changed: Int) {
        var kept: [String] = [], leftOut = 0, changed = 0
        for raw in offered {
            guard let cleaned = cleanCaption(raw), cleaned.text.count <= 500, CopyRules.flag(cleaned.text) == nil,
                  quoted(cleaned.text).allSatisfy({ found(WritingText.bareQuote($0)) }) else { leftOut += 1; continue }
            if cleaned.changed { changed += 1 }
            if !kept.contains(cleaned.text) { kept.append(cleaned.text) }
        }
        return (Array(kept.prefix(3)), leftOut, changed)
    }

    /// A caption as kept: dashes made commas, exclamation marks made full stops, hashtags and links
    /// taken out. Nil when nothing is left.
    static func cleanCaption(_ raw: String) -> (text: String, changed: Bool)? {
        var (caption, dashes) = WritingText.withoutDashes(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        var words = caption.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let before = words.count
        words.removeAll { $0.hasPrefix("#") || $0.lowercased().hasPrefix("http") }
        caption = words.joined(separator: " ")
        let bangs = caption.filter { $0 == "!" }.count
        caption = caption.replacingOccurrences(of: "!", with: ".")
        return caption.isEmpty ? nil : (caption, dashes > 0 || bangs > 0 || words.count != before)
    }

    /// The whole sentences of `text`, from the start, that fit in `limit` characters, or nil.
    static func fitting(_ text: String, limit: Int) -> String? {
        if text.count <= limit { return text }
        var out = ""
        for sentence in CopyRules.sentences(text) {
            let next = out.isEmpty ? sentence : out + " " + sentence
            guard next.count <= limit else { break }
            out = next
        }
        return out.isEmpty ? nil : out
    }

    /// "#YogaMarga" made "YogaMarga": letters and digits only, the words joined with capitals, an
    /// apostrophe joining its word. Nil for nothing left.
    static func hashtag(_ raw: String) -> String? {
        let words = raw.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "").split { !$0.isLetter && !$0.isNumber }
        let joined = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return joined.isEmpty || joined.count > 40 ? nil : joined
    }

    /// The hashtag as the transcript writes its words, or nil when its letters are not a run of whole
    /// words there: "ashtangayoga" from "Ashtanga yoga" becomes "AshtangaYoga", and "Yogalinage" (the
    /// model's misspelling on 11 Oct) is left out. Reason: a hashtag goes out under the teacher's name,
    /// so it is held to the transcript like a quote, and run-together words read better capitalized.
    static func hashtag(_ raw: String, in source: String) -> String? {
        guard let joined = hashtag(raw) else { return nil }
        let target = joined.lowercased()
        var letters: [String] = [], starts: [Bool] = [], newWord = true
        for character in source.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "") {
            if character.isLetter || character.isNumber {
                letters.append(String(character).lowercased())
                starts.append(newWord)
                newWord = false
            } else {
                newWord = true
            }
        }
        let wanted = target.map { String($0) }
        guard !wanted.isEmpty, wanted.count <= letters.count else { return nil }
        for lo in 0...(letters.count - wanted.count) where starts[lo] && letters[lo] == wanted[0] {
            let hi = lo + wanted.count
            guard hi == letters.count || starts[hi], Array(letters[lo..<hi]) == wanted else { continue }
            return (lo..<hi).map { starts[$0] ? letters[$0].uppercased() : letters[$0] }.joined()
        }
        return nil
    }

    /// The one caption per platform, each checked (11 Oct): cleaned like any caption; left out when it
    /// breaks the copy rules, quotes words the transcript does not have, or is longer than its platform
    /// takes even cut back to whole sentences. Its pull quote is kept only when it is found word for
    /// word inside one line of the transcript (one sentence as Parakeet wrote it) and keeps the copy
    /// rules; the line gives its time. Instagram's hashtags are cleaned, at most five, and come from
    /// the keywords when the model gave none.
    static func social(_ value: Any?, lines: [WritingLine], keywords: [String], found: (String) -> Bool)
        -> (kept: [SocialCaption], leftOut: Int, leftOutQuotes: [String], notes: [String]) {
        let object = value as? [String: Any] ?? [:]
        var kept: [SocialCaption] = [], leftOut = 0, leftOutQuotes: [String] = [], notes: [String] = []
        var usedQuotes = Set<String>()
        let normalizedLines = lines.map { (start: $0.start, text: WritingText.normalized($0.text)) }
        let spoken = lines.map(\.text).joined(separator: " ")
        for platform in SocialPlatform.allCases {
            guard let entry = platform.keys.lazy.compactMap({ object[$0] as? [String: Any] }).first else {
                if !object.isEmpty { notes.append("No \(platform.title) caption came back.") }
                continue
            }
            let raw = (entry["caption"] as? String) ?? (entry["text"] as? String) ?? ""
            guard let cleaned = cleanCaption(raw) else {
                leftOut += 1
                notes.append("The \(platform.title) caption was empty.")
                continue
            }
            if let why = CopyRules.flag(cleaned.text) {
                leftOut += 1
                notes.append("The \(platform.title) caption named \(why), so it was left out.")
                continue
            }
            guard quoted(cleaned.text).allSatisfy({ found(WritingText.bareQuote($0)) }) else {
                leftOut += 1
                notes.append("The \(platform.title) caption quoted words that are not in the transcript, so it was left out.")
                continue
            }
            // Under the platform's limit, not at it: Ivan's brief says "under 280" for X and Threads.
            guard let text = fitting(cleaned.text, limit: platform.limit - 1) else {
                leftOut += 1
                notes.append("The \(platform.title) caption was \(cleaned.text.count) characters, over the \(Format.number(platform.limit)) it takes, so it was left out.")
                continue
            }
            if text.count < cleaned.text.count {
                notes.append("The \(platform.title) caption was \(cleaned.text.count) characters, over the \(Format.number(platform.limit)) it takes, so it was cut back to its first whole sentences (\(text.count)).")
            }
            var caption = SocialCaption(platform: platform, text: text)
            if platform == .instagram {
                let offered = ((entry["hashtags"] as? [Any]) ?? []).compactMap { $0 as? String }
                var tags: [String] = []
                // The rules read each tag as written ("free trial") and as joined ("FreeTrial"); each
                // must be whole words the teacher says.
                let candidates = (offered.isEmpty ? keywords : offered).filter { CopyRules.flag($0) == nil }
                var unspoken = 0
                for raw in candidates {
                    guard let tag = hashtag(raw, in: spoken), CopyRules.flag(tag) == nil else { unspoken += 1; continue }
                    if !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) { tags.append(tag) }
                }
                caption.hashtags = Array(tags.prefix(SocialPlatform.hashtagLimit))
                if offered.isEmpty && !caption.hashtags.isEmpty { notes.append("No hashtags came back, so Instagram's are made from the keywords.") }
                if offered.count > candidates.count {
                    notes.append("\(Format.count(offered.count - candidates.count, "hashtag")) named money, enrollment or an offer, so \(offered.count - candidates.count == 1 ? "it was" : "they were") left out.")
                }
                if unspoken > 0 {
                    notes.append("\(Format.count(unspoken, "hashtag")) \(unspoken == 1 ? "was not" : "were not") words the teacher says, as spelled in the transcript, so \(unspoken == 1 ? "it was" : "they were") left out.")
                }
            }
            let rawQuote = (entry["pull_quote"] as? String) ?? (entry["pullQuote"] as? String) ?? ""
            let quote = WritingText.bareQuote(rawQuote)
            if !quote.isEmpty {
                let words = WritingText.words(quote)
                if let why = CopyRules.flag(quote) {
                    leftOutQuotes.append(rawQuote)
                    notes.append("The \(platform.title) pull quote named \(why), so it was left out.")
                } else if usedQuotes.contains(quote) {
                    notes.append("The \(platform.title) pull quote repeated another platform's, so it was left out.")
                } else if words >= WritingRules.shortestQuote, words <= longestPullQuote,
                          let line = normalizedLines.first(where: { $0.text.contains(quote) }) {
                    caption.pullQuote = quote
                    caption.pullQuoteAt = line.start
                    usedQuotes.insert(quote)
                } else {
                    leftOutQuotes.append(rawQuote)
                }
            } else {
                notes.append("No \(platform.title) pull quote came back.")
            }
            kept.append(caption)
        }
        return (kept, leftOut, leftOutQuotes, notes)
    }

    /// The JSON object in a reply: the reply itself, or the object inside a code fence or prose.
    static func jsonObject(_ text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let object = ModelHTTP.object(Data(trimmed.utf8)) { return object }
        guard let open = trimmed.firstIndex(of: "{"), let close = trimmed.lastIndex(of: "}"), open < close else { return nil }
        return ModelHTTP.object(Data(trimmed[open...close].utf8))
    }

    static func invalid(_ reason: String) -> ModelFailure {
        ModelFailure(kind: .invalid, reason: reason)
    }

    static func check(_ text: String, lines: [WritingLine], transcript: String, rules: WritingRules, length: Double) throws -> Checked {
        guard let object = jsonObject(text) else { throw invalid("The answer was not JSON.") }
        var notes: [String] = []
        var dashes = 0
        func clean(_ value: String) -> String {
            let (s, n) = WritingText.withoutDashes(value.trimmingCharacters(in: .whitespacesAndNewlines))
            dashes += n
            return s
        }

        // Titles: three or four usable ones (the first is the writer's pick, the rest alternatives).
        // A title that breaks the copy rules is left out.
        let offered = ((object["titles"] as? [Any]) ?? []).compactMap { $0 as? String }.map(clean)
        var titles: [String] = []
        for title in offered where !title.isEmpty && title.count <= 100 && !title.contains("<") && !title.contains(">") {
            if let why = CopyRules.flag(title) {
                notes.append("A title named \(why), so it was left out.")
                continue
            }
            if !titles.contains(where: { $0.caseInsensitiveCompare(title) == .orderedSame }) { titles.append(title) }
        }
        guard titles.count >= 3 else { throw invalid("The answer had fewer than three usable titles.") }
        titles = Array(titles.prefix(WritingRules.titleOptions))
        for title in titles where title.count > WritingRules.titleLimit {
            notes.append("A title is \(title.count) characters, over the 60 a phone shows in full.")
        }

        // Show notes: 2 to 4 short paragraphs (a list, or one string with blank lines between). A
        // sentence that breaks the copy rules is taken out; notes with nothing left fail the answer.
        let notesValue = object["show_notes"] ?? object["showNotes"]
        let offeredParagraphs = (notesValue as? [Any])?.compactMap { $0 as? String } ?? CopyRules.paragraphs((notesValue as? String) ?? "")
        let screenedNotes = CopyRules.withoutFlaggedSentences(offeredParagraphs.map(clean).filter { !$0.isEmpty }.joined(separator: "\n\n"))
        let showNotes = screenedNotes.text
        guard !showNotes.isEmpty else {
            throw invalid(screenedNotes.removed.isEmpty ? "The answer had no show notes." : "Every sentence of the show notes named money, enrollment or an offer.")
        }
        if !screenedNotes.removed.isEmpty {
            notes.append("\(Format.count(screenedNotes.removed.count, "sentence")) of the show notes named \(screenedNotes.removed.joined(separator: "; ")), so \(screenedNotes.removed.count == 1 ? "it was" : "they were") taken out.")
        }
        let paragraphCount = CopyRules.paragraphs(showNotes).count
        if notesValue is [Any] || paragraphCount > 1, !(2...4).contains(paragraphCount) {
            notes.append("The show notes are \(Format.count(paragraphCount, "paragraph")), not the 2 to 4 asked for.")
        }

        // The one-line summary: under 160 characters (cut back to its first sentence if that fits),
        // within the copy rules, or none.
        var oneLine: String?
        if let raw = (object["one_line"] ?? object["oneLine"]) as? String {
            let line = clean(raw)
            if let why = CopyRules.flag(line) {
                notes.append("The one-line summary named \(why), so it was left out.")
            } else if let fitted = fitting(line, limit: oneLineLimit), !fitted.isEmpty {
                oneLine = fitted
                if fitted.count < line.count { notes.append("The one-line summary was \(line.count) characters, so only its first sentence is kept.") }
            } else if !line.isEmpty {
                notes.append("The one-line summary was \(line.count) characters, over 159, so it was left out.")
            }
        }

        // Keywords: trimmed, one to four words, within the copy rules, at most ten.
        var keywords: [String]?
        if let offeredKeywords = (object["keywords"] as? [Any])?.compactMap({ $0 as? String }) {
            var kept: [String] = []
            for raw in offeredKeywords {
                let keyword = clean(raw.trimmingCharacters(in: CharacterSet(charactersIn: "#.,").union(.whitespaces)))
                guard !keyword.isEmpty, keyword.count <= 40, WritingText.words(keyword) <= 4 else { continue }
                if let why = CopyRules.flag(keyword) {
                    notes.append("A keyword named \(why), so it was left out.")
                    continue
                }
                if !kept.contains(where: { $0.caseInsensitiveCompare(keyword) == .orderedSame }) { kept.append(keyword) }
            }
            keywords = Array(kept.prefix(10))
        }

        // Chapters: at the transcript's own times only.
        var starts: [String: Double] = [:]
        for line in lines where starts[line.label] == nil { starts[line.label] = line.start }
        var leftOutChapters = 0
        var chapters: [WrittenChapter] = []
        for item in (object["chapters"] as? [Any]) ?? [] {
            guard let entry = item as? [String: Any] else { leftOutChapters += 1; continue }
            let label = ((entry["start"] as? String) ?? (entry["start"] as? NSNumber)?.stringValue ?? "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "[] ").union(.whitespaces))
            let title = clean((entry["title"] as? String) ?? "")
            guard let start = starts[label], !title.isEmpty else { leftOutChapters += 1; continue }
            if let why = CopyRules.flag(title) {
                leftOutChapters += 1
                notes.append("The chapter at \(label) named \(why) in its title, so it was left out.")
                continue
            }
            if !chapters.contains(where: { abs($0.start - start) < 0.001 }) { chapters.append(WrittenChapter(start: start, title: title)) }
        }
        chapters.sort { $0.start < $1.start }
        guard let firstLine = lines.first, !chapters.isEmpty else { throw invalid("No chapter started at a time in the transcript.") }
        if chapters[0].start > firstLine.start + 0.001 {
            notes.append("The first chapter started at \(chapters[0].label); it now starts at the beginning (\(firstLine.label)).")
            chapters[0].start = firstLine.start
        }
        // A chapter shorter than 2 minutes, or one too many, joins the chapter before it (SCOPE PKG-05).
        var merged = 0
        var kept: [WrittenChapter] = []
        for chapter in chapters {
            if let last = kept.last, chapter.start - last.start < WritingRules.chapterGap { merged += 1; continue }
            kept.append(chapter)
        }
        if kept.count > 1, let last = kept.last, length - last.start < WritingRules.chapterGap {
            kept.removeLast()
            merged += 1
        }
        while kept.count > rules.maxChapters {
            var shortest = 1
            for index in 1..<kept.count {
                let end = index + 1 < kept.count ? kept[index + 1].start : length
                let shortestEnd = shortest + 1 < kept.count ? kept[shortest + 1].start : length
                if end - kept[index].start < shortestEnd - kept[shortest].start { shortest = index }
            }
            kept.remove(at: shortest)
            merged += 1
        }
        if merged > 0 {
            notes.append("\(Format.count(merged, "chapter")) joined the one before \(merged == 1 ? "it" : "them"): chapters must be at least 2 minutes long, and at most \(rules.maxChapters) for this length.")
        }
        guard kept.count >= rules.minChapters else {
            throw invalid("The answer had \(Format.count(kept.count, "usable chapter")), not the \(rules.minChapters) asked for.")
        }
        for chapter in kept where WritingText.words(chapter.title) > WritingRules.chapterTitleWords || chapter.title.count > WritingRules.chapterTitleLimit {
            notes.append("The chapter at \(chapter.label) has a title longer than Apple's limit (4 words, 45 characters).")
        }

        // The accuracy checklist: each quote found word for word, or left out.
        let haystack = WritingText.normalized(transcript)
        var located = ""
        var offsets: [(offset: Int, start: Double)] = []
        for line in lines {
            if !located.isEmpty { located += " " }
            offsets.append((located.count, line.start))
            located += WritingText.normalized(line.text)
        }
        var checklist: [CheckedClaim] = []
        var leftOut: [String] = []
        for item in (object["checklist"] as? [Any]) ?? [] {
            guard let entry = item as? [String: Any] else { continue }
            let claim = clean((entry["claim"] as? String) ?? "")
            let raw = (entry["quote"] as? String) ?? ""
            let quote = WritingText.bareQuote(raw)
            guard !claim.isEmpty, !quote.isEmpty else { continue }
            // Found in transcript.txt, or in the lines the model read (the same words with the word
            // list applied: a recording engine v0 made has a .txt without the list's fixes).
            guard WritingText.words(quote) >= WritingRules.shortestQuote, haystack.contains(quote) || located.contains(quote) else {
                leftOut.append(raw)
                continue
            }
            guard !checklist.contains(where: { $0.quote == quote }) else { continue }
            var at: Double?
            if let range = located.range(of: quote) {
                let offset = located.distance(from: located.startIndex, to: range.lowerBound)
                at = offsets.last(where: { $0.offset <= offset })?.start
            } else if let label = entry["at"] as? String {
                at = starts[label.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))]
            }
            checklist.append(CheckedClaim(claim: claim, quote: quote, at: at))
        }
        guard !checklist.isEmpty else { throw invalid("None of the answer's quotes was found word for word in the transcript.") }
        if checklist.count > rules.maxClaims { checklist = Array(checklist.prefix(rules.maxClaims)) }
        if checklist.count < rules.minClaims {
            notes.append("The checklist has \(Format.count(checklist.count, "claim")) with quotes found word for word, under the \(rules.minClaims) asked for.")
        }
        if dashes > 0 {
            notes.append("\(Format.count(dashes, "dash", "dashes")) replaced with a comma: no em dashes or en dashes in anything written.")
        }
        let found: (String) -> Bool = { quote in !quote.isEmpty && (haystack.contains(quote) || located.contains(quote)) }
        // One caption per platform (11 Oct), or the three plain captions a model may still give.
        var social: (kept: [SocialCaption], leftOut: Int, leftOutQuotes: [String], notes: [String]) = ([], 0, [], [])
        var plain: (kept: [String], leftOut: Int, changed: Int) = ([], 0, 0)
        if let value = object["social"] {
            social = Self.social(value, lines: lines, keywords: keywords ?? [], found: found)
            notes += social.notes
        } else {
            let offeredCaptions = ((object["captions"] as? [Any]) ?? []).compactMap { $0 as? String }
            plain = captions(offeredCaptions, found: found)
            if offeredCaptions.isEmpty { notes.append("No social captions came back.") }
            if plain.changed > 0 {
                notes.append("\(Format.count(plain.changed, "social caption")) had a dash, an exclamation mark, a hashtag or a link taken out.")
            }
        }
        return Checked(titles: titles, showNotes: showNotes, chapters: kept, checklist: checklist,
                       leftOutQuotes: leftOut, leftOutChapters: leftOutChapters, notes: notes,
                       captions: plain.kept, leftOutCaptions: plain.leftOut + social.leftOut,
                       oneLine: oneLine, keywords: keywords, social: social.kept, leftOutPullQuotes: social.leftOutQuotes)
    }

    /// Tags as kept: trimmed, one to four words, no dashes, merged by how often they came up (most
    /// first, then first seen), at most eight.
    static func tags(_ offered: [String]) -> [String] {
        var counts: [String: Int] = [:]
        var first: [String: (index: Int, text: String)] = [:]
        for (index, raw) in offered.enumerated() {
            let tag = WritingText.withoutDashes(raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#.,"))).0
            guard !tag.isEmpty, tag.count <= 40, WritingText.words(tag) <= 4 else { continue }
            let key = tag.lowercased()
            counts[key, default: 0] += 1
            if first[key] == nil { first[key] = (index, tag) }
        }
        return counts.keys.sorted { a, b in
            counts[a] != counts[b] ? (counts[a] ?? 0) > (counts[b] ?? 0) : (first[a]?.index ?? 0) < (first[b]?.index ?? 0)
        }.prefix(8).compactMap { first[$0]?.text }
    }
}

extension WritingInput {
    /// The writer's input from a folder holding transcript.json (a make's staging folder, or a
    /// recording's output folder for Write Again): the sentences as the episode plays them, with the
    /// word list applied as the transcript was made, and transcript.txt for checking quotes (or the
    /// sentences' own text when .txt is not one of the chosen formats). Nil when there is no
    /// transcript.json to read.
    static func from(folder: URL, clock: EpisodeClock?, duration: Double, applyLexicon: Bool, label: String, fileName: String,
                     kind: RecordingKind, knownSerenity: Bool) -> WritingInput? {
        guard let data = try? Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard)),
              let sentences = EpisodeTranscript.sentences(json: data) else { return nil }
        let clock = clock ?? EpisodeClock(intro: 0, segments: [Mastering.Span(start: 0, end: max(duration, sentences.map(\.end).max() ?? 0))])
        let cues = EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: applyLexicon).cues
        let text = (try? String(contentsOf: folder.appending(path: TranscriptFiles.fileName(.txt)), encoding: .utf8)) ?? EpisodeTranscript.text(cues)
        return WritingInput(label: label, fileName: fileName, kind: kind, knownSerenity: knownSerenity, cues: cues, transcriptText: text,
                            followsEpisode: !clock.isIdentity(duration: duration))
    }
}

extension WrittenPackage {
    /// Writes titles-notes-chapters.json (with the model's own answer, for the record) and
    /// show-notes.md into `folder`.
    func save(in folder: URL, label: String, fileName: String) throws {
        try json().write(to: folder.appending(path: Self.fileName), atomically: true, encoding: .utf8)
        try markdown(label: label, fileName: fileName).write(to: folder.appending(path: Self.notesFileName), atomically: true, encoding: .utf8)
    }

    /// The step's line on the recording page and in the report: who wrote it, how long it took, and
    /// what the checks kept and left out. Numbers only, never the words written.
    var stepLine: String {
        var line = "Written by \(writtenBy) in \(Format.length(seconds))"
        line += attempts > 1 ? " (\(Format.count(attempts, "try", "tries")))" : ""
        line += ": \(Format.count(titles.count, "title option")), \(Format.count(chapters.count, "chapter")), "
        line += "\(Format.count(checklist.count, "quote")) found word for word in the transcript"
        if let social, !social.isEmpty {
            let quotes = social.filter { $0.pullQuote != nil }.count
            line += ", \(Format.count(social.count, "social caption")) with \(Format.count(quotes, "pull quote")) found word for word"
        } else if let captions, !captions.isEmpty {
            line += ", \(Format.count(captions.count, "social caption"))"
        }
        var left: [String] = []
        if !leftOutQuotes.isEmpty { left.append(Format.count(leftOutQuotes.count, "quote")) }
        if leftOutChapters > 0 { left.append(Format.count(leftOutChapters, "chapter")) }
        line += left.isEmpty ? "." : " (\(left.joined(separator: " and ")) not in it left out)."
        if let lockReason { line += " Privacy lock: \(lockReason), so " + (lockedTasks.isEmpty ? "only models on this Mac read it." : "LM Studio did the \(lockedTasks.joined(separator: " and ")) chosen for the Claude API.") }
        return line
    }
}
