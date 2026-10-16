import Foundation

// The thumbnails' headlines (v2 part M11b, docs/v2/PLAN.md section 11, Ivan Mon 12 Oct): "a 2 to 4 word headline (not the title)
// in large type", written by the writing model (the Writing task's provider in Settings, Models: the Claude API, claude-sonnet-5-5,
// by default), one for each of the three thumbnails. The model reads only the parts of the talk (what each is about and its
// strongest line), never the whole transcript, and its request passes the privacy lock like every writing request: a cloud
// provider is reached only through `LockedCloudClient`, so a recording the lock keeps on this Mac is read by LM Studio instead.
//
// Swift checks every headline before it is drawn (`check`): 2 to 4 words, at most 28 characters, not the title, no dash of any
// kind, no hashtag or emoji, nothing Ivan's copy rules forbid (`CopyRules`: no prices, money, enrolment or offers), every letter
// one the typeface draws. When the model gives fewer than three usable, the rest come from the talk's own key phrases (cut to
// four words), and the record says so; never invented.

enum ThumbnailWords {
    static let system = """
        You write the headline of a YouTube thumbnail for a recorded talk by a yoga teacher. Read what each part of the talk is \
        about and its strongest line, and write three different headlines, each 2 to 4 short words (none over 10 letters): the idea a viewer would click for, \
        in plain words, never the talk's title, never a person's name, never a private matter (no illness, burnout, death, family \
        matter or money trouble, even when the talk mentions one), never a question of more than 4 words. No dashes, no \
        hashtags, no emoji, no quotation marks, no prices, money, enrolment, sign-ups or offers. Sanskrit terms are allowed as \
        said in the talk.

        Answer with one JSON object and nothing else, in exactly this shape:
        {"headlines": ["", "", ""]}
        """

    static let longest = 28
    static let longestWord = 10

    /// The request: the title (so it is not repeated) and the parts of the talk, or, without parts, its first sentences.
    static func request(title: String, beats: [Beat], sentences: [String]) -> ModelRequest {
        var user = title.isEmpty ? "" : "The talk's title (do not repeat it): \(title)\n\n"
        if beats.isEmpty {
            user += "The talk begins:\n" + sentences.prefix(60).joined(separator: " ")
        } else {
            user += "The parts of the talk:\n" + beats.map { beat in
                "- \(beat.summary)" + (beat.keyLine.map { ": \u{201C}\($0.text)\u{201D}" } ?? "")
            }.joined(separator: "\n")
        }
        return ModelRequest(system: system, user: user, shape: .writing, maxTokens: ModelSettings.maxTokens)
    }

    /// Why a headline cannot be used, or nil when it can.
    static func problem(_ raw: String, title: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = text.split(whereSeparator: \.isWhitespace)
        if text.unicodeScalars.contains(where: { [0x2014, 0x2013, 0x2012, 0x2010, 0x2E3A].contains($0.value) }) || text.contains(" - ") { return "it has a dash" }
        if words.count < 2 || words.count > 4 { return "it is \(Format.count(words.count, "word")), not 2 to 4" }
        if text.count > longest { return "it is \(text.count) characters, over \(longest)" }
        // A word of more than 10 letters does not fit beside the teacher at a size that reads at 168 pixels wide (measured 16 Oct:
        // "UNDERSTANDING" needed 1,180 of the 883 pixels there are).
        if let long = words.first(where: { $0.count > longestWord }) { return "\u{201C}\(long)\u{201D} is over \(longestWord) letters" }
        if text.lowercased() == title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) { return "it is the title" }
        if text.contains("#") || text.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) { return "it has a hashtag or an emoji" }
        if let flagged = CopyRules.flag(text) { return "it names \(flagged)" }
        if let font = TypeFace.font(VideoThumbnails.face, size: 40) {
            let missing = TypeFace.missing(in: TypeFace.prepared(text.uppercased(), font: VideoThumbnails.face), font: font)
                .filter { !"\u{2019}'.,!?:".contains($0) }
            if !missing.isEmpty { return "the typeface has no letter for \(String(missing))" }
        }
        return nil
    }

    /// The headline as drawn: quotes and a closing full stop taken off, spaces made single.
    static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}\u{2018}\u{2019}'"))
        if text.hasSuffix(".") { text.removeLast() }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The usable headlines in a model's answer, in order, each once.
    static func read(_ answer: String, title: String) -> (kept: [String], refused: [String]) {
        guard let object = WritingCheck.jsonObject(answer), let list = object["headlines"] as? [Any] else { return ([], ["the answer was not the JSON asked for"]) }
        var kept: [String] = [], refused: [String] = []
        for item in list {
            guard let raw = item as? String else { continue }
            let text = clean(raw)
            if let problem = problem(text, title: title) {
                refused.append("\u{201C}\(text)\u{201D}: \(problem)")
            } else if !kept.contains(where: { $0.lowercased() == text.lowercased() }) {
                kept.append(text)
            }
        }
        return (kept, refused)
    }

    /// Headlines from the talk's own key phrases, for any the model did not give: each cut to its first four words, checked the
    /// same way. Never invented.
    static func fallback(beats: [Beat], title: String, have: [String]) -> [String] {
        var out = have
        let ranked = beats.sorted { ($0.hookCandidate ? 1 : 0) > ($1.hookCandidate ? 1 : 0) }
        for beat in ranked {
            guard out.count < 3 else { break }
            for phrase in [beat.keyPhrase?.text, beat.summary].compactMap({ $0 }) {
                let words = clean(phrase).split(separator: " ").prefix(4).joined(separator: " ")
                let text = words.prefix(1).uppercased() + words.dropFirst()
                if problem(text, title: title) == nil, !out.contains(where: { $0.lowercased() == text.lowercased() }) {
                    out.append(text)
                    break
                }
            }
        }
        return out
    }

    struct Outcome: Sendable {
        var headlines: [String]
        /// Who wrote them: "Anthropic, claude-sonnet-5-5", or "the talk's own key phrases".
        var by: String
        var notes: [String]
    }

    /// Asks the writing model for three headlines, checks them, and fills any missing from the key phrases. Never throws: a model
    /// that cannot be reached leaves the key phrases, and the notes say why.
    static func write(title: String, beats: [Beat], sentences: [String], setup: WritingSetup?, subject: LockSubject, log: AppLog?, fileName: String) async -> Outcome {
        var notes: [String] = []
        var kept: [String] = []
        var by = "the talk's own key phrases"
        if let setup {
            let chosen = setup.chosen(.writing)
            let reason = PrivacyLock.decide(subject).reason
            let provider = ModelRouting.provider(chosen: chosen, locked: reason != nil)
            if provider != chosen {
                log?.write("\(fileName): privacy lock. \((reason ?? "").capitalizedFirst), so the thumbnails' headlines use \(provider.title) instead of \(chosen.title).")
            }
            let client: any LanguageModelClient = provider.isLocal ? setup.makeClient(provider, setup)
                : LockedCloudClient(inner: setup.makeCloudClient(provider, setup), subject: subject, onRefusal: { reason in log?.write("\(fileName): \(reason)") })
            let request = request(title: title, beats: beats, sentences: sentences)
            do {
                try await client.prepare()
                var attempts = 0
                while attempts < max(1, setup.maxAttempts) && kept.count < 3 {
                    attempts += 1
                    do {
                        let reply = try await client.complete(request)
                        let read = read(reply.text, title: title)
                        for text in read.kept where !kept.contains(where: { $0.lowercased() == text.lowercased() }) { kept.append(text) }
                        if !read.refused.isEmpty { notes.append("Headlines not used: " + read.refused.joined(separator: "; ") + ".") }
                        log?.write("\(fileName): the thumbnails' headlines by \(client.displayName), try \(attempts), in " + String(format: "%.0f s", reply.seconds)
                                   + (reply.costUSD.map { ", cost \(CloudPricing.text($0))" } ?? "") + ": \(kept.count) usable.")
                        by = client.displayName
                    } catch let failure as ModelFailure {
                        notes.append("The headlines could not be written by \(client.displayName): \(failure.reason)")
                        if !failure.retryable { break }
                    }
                }
            } catch {
                notes.append("The headlines could not be written by \(client.displayName): \((error as? ModelFailure)?.reason ?? error.localizedDescription)")
            }
            if let line = await client.release() { log?.write("\(fileName): \(line)") }
        } else {
            notes.append("No model is set for writing, so the headlines are the talk's own key phrases.")
        }
        kept = Array(kept.prefix(3))
        if kept.count < 3 {
            let before = kept.count
            kept = fallback(beats: beats, title: title, have: kept)
            if kept.count > before {
                notes.append("\(Format.count(kept.count - before, "headline")) from the talk's own key phrases.")
                if before == 0 { by = "the talk's own key phrases" }
            }
        }
        if kept.isEmpty, !title.isEmpty {
            let words = clean(title).split(separator: " ").prefix(4).joined(separator: " ")
            if words.split(separator: " ").count >= 2, CopyRules.flag(words) == nil {
                kept = [words]
                by = "the title's first words"
                notes.append("No headline could be written, so the thumbnails use the first words of the title.")
            }
        }
        return Outcome(headlines: kept, by: by, notes: notes)
    }
}
