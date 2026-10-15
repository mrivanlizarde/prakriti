import Foundation

// The beats of a recording (v2 part M9c, docs/v2/PLAN.md M9; research-edit-engine.md 3.1 and 3.3): the passages a talk is
// made of, each scored by the planning model for eight focus tags, once per transcript. "Annotate once, choose in code":
// the model reads the sentences with their ids and answers with beats; everything after (the direction, the selection under a
// length, the picture) is code, so a change of pace or length asks no model anything.
//
// What the model answers is never trusted (LOCAL-MODEL.md rule 4). `BeatCheck.check` keeps a beat only when:
// - its first and last sentences exist and the beats run in order without overlapping (a sentence no beat holds joins the beat
//   before it, and the note says so);
// - every score is a whole number from 0 to 3 for one of the eight tags (a missing tag is 0);
// - its key line is found word for word inside the beat's own words (case and punctuation aside); a line that is not is left
//   out and counted, never repaired. The word ids are found by code, never taken from the model. Its key phrase (v2 part M9d,
//   2 to 6 words for the screen) is held to the same rule inside the key line;
// - it depends only on beats before it.
//
// Kept in `beats.json` beside the plan, with the transcript's SHA-256, the model, the temperature and the seed, so the same
// transcript is never annotated twice (`BeatsFile.cached`) and a check run twice reads the same beats.

/// The eight focus tags (research 3.3).
enum BeatTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case motivating, enlightening, practical, story, humor, philosophy, technique, personal

    var id: String { rawValue }
    var title: String { rawValue }
}

/// What a beat is (research 3.3).
enum BeatKind: String, Codable, CaseIterable, Sendable {
    case welcome, housekeeping, teaching, story, practice, question, closing
}

/// One beat: a stretch of whole sentences, on the original's clock.
struct Beat: Codable, Equatable, Sendable {
    /// The line the model chose as the beat's strongest, found word for word in its words.
    struct KeyLine: Codable, Equatable, Sendable {
        var from: String
        var to: String
        var text: String
    }

    /// "b1", "b2", in spoken order.
    var id: String
    /// Its first and last sentence ("s1" is the transcript's first) and first and last word ("w0").
    var firstSentence: String
    var lastSentence: String
    var from: String
    var to: String
    /// The first word's start and the last word's end, in seconds on the original's clock (Parakeet's times).
    var start: Double
    var end: Double
    /// A few words for Ivan ("Why the breath comes first"). Never a person's name or a private matter (Mac warning 51).
    var summary: String
    /// 0 to 3 for each tag.
    var scores: [String: Int]
    var kind: BeatKind
    var standsAlone: Bool
    var dependsOn: [String]
    var keyLine: KeyLine?
    /// 2 to 6 words of the key line that say its point on their own (v2 part M9d): the key-phrase text on screen, found word for
    /// word inside the key line. Nil when the model gave none or it was not found.
    var keyPhrase: KeyLine? = nil
    var hookCandidate: Bool
    var terms: [String]
    /// The beat that states the talk's main point. Exactly one per recording after the check.
    var thesis: Bool

    var seconds: Double { max(0, end - start) }

    func score(_ tag: BeatTag) -> Int { scores[tag.rawValue] ?? 0 }

    /// Housekeeping or a warm-up: what the selection leaves out first.
    var isHousekeeping: Bool { kind == .housekeeping }

    /// Scored 0 for every tag.
    var scoredNothing: Bool { BeatTag.allCases.allSatisfy { score($0) == 0 } }
}

/// The beats of one transcript, as `beats.json` keeps them.
struct BeatsFile: Codable, Equatable, Sendable {
    static let schemaName = "prakriti.beats/1"
    static let fileName = "beats.json"
    /// Changes whenever the request does, so beats asked for differently are asked for again. 2 (v2 part M9d): the key phrase.
    static let promptVersion = 2

    var schema = BeatsFile.schemaName
    var promptVersion = BeatsFile.promptVersion
    var recording: String
    var transcriptSHA256: String
    var madeAt: Date
    /// Who annotated ("Qwen3.8-27B in LM Studio", "claude-sonnet-5-5 (Anthropic)") and its provider's raw value.
    var by: String
    var provider: String
    /// The sampling asked for (PLAN M9): temperature 0 and a fixed seed on LM Studio and Ollama; nil for a cloud provider,
    /// which takes no seed (the file itself is what keeps two runs the same).
    var temperature: Double?
    var seed: Int?
    /// How long the annotation took, and in how many tries.
    var seconds: Double
    var attempts: Int
    var beats: [Beat]
    /// What the check changed or left out, one plain sentence each.
    var notes: [String] = []

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) -> BeatsFile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(BeatsFile.self, from: data), file.schema == schemaName else { return nil }
        return file
    }

    /// The beats in `folder` when they were made from this very transcript with this request, else nil.
    static func cached(in folder: URL, transcriptSHA256: String) -> BeatsFile? {
        guard let data = try? Data(contentsOf: folder.appending(path: fileName)), let file = decode(data),
              file.transcriptSHA256 == transcriptSHA256, file.promptVersion == promptVersion, !file.beats.isEmpty else { return nil }
        // Beats checked before the links were loosened (v2 part M9d) read the same as new ones.
        var loosened = file
        _ = BeatCheck.loosen(&loosened.beats)
        return loosened
    }

    /// One line for the inspector and the log: "14 beats by Qwen3.8-27B in LM Studio, 9 min 41 s."
    var line: String {
        "\(Format.count(beats.count, "beat")) by \(by), " + Format.length(seconds) + "."
    }
}

/// A sentence as the model reads it: its id, its time, its words.
struct BeatSentence: Equatable, Sendable {
    var id: String
    var first: Int
    var last: Int
    var start: Double
    var text: String

    /// The transcript's sentences, from its words ("s1" is the first).
    static func from(_ words: [PlanWord]) -> [BeatSentence] {
        var out: [BeatSentence] = []
        var i = 0
        while i < words.count {
            var j = i
            while j + 1 < words.count && words[j + 1].sentence == words[i].sentence { j += 1 }
            out.append(BeatSentence(id: "s\(out.count + 1)", first: i, last: j, start: words[i].start, text: PlanWords.text(words[i...j])))
            i = j + 1
        }
        return out
    }
}

enum BeatCheck {
    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// Checks the model's answer against the transcript's words and returns the beats, with a note for each repair.
    static func check(_ text: String, words: [PlanWord]) throws -> (beats: [Beat], notes: [String]) {
        let sentences = BeatSentence.from(words)
        guard !sentences.isEmpty else { throw Failure(reason: "The transcript has no sentences.") }
        guard let object = WritingCheck.jsonObject(text), let raw = object["beats"] as? [[String: Any]], !raw.isEmpty else {
            throw Failure(reason: "The answer was not the JSON asked for (an object with a list of beats).")
        }
        let index = Dictionary(uniqueKeysWithValues: sentences.enumerated().map { ($1.id, $0) })
        var notes: [String] = []
        struct Draft {
            var first: Int
            var last: Int
            var fields: [String: Any]
            var givenID: String
        }
        var drafts: [Draft] = []
        for (n, item) in raw.enumerated() {
            guard let a = (item["first"] as? String).flatMap({ index[$0.trimmingCharacters(in: .whitespaces)] }),
                  let b = (item["last"] as? String).flatMap({ index[$0.trimmingCharacters(in: .whitespaces)] }), a <= b else {
                throw Failure(reason: "Beat \(n + 1) does not name a first and a last sentence that exist, in order.")
            }
            drafts.append(Draft(first: a, last: b, fields: item, givenID: (item["id"] as? String) ?? "b\(n + 1)"))
        }
        drafts.sort { $0.first < $1.first }
        for (x, y) in zip(drafts, drafts.dropFirst()) where y.first <= x.last {
            throw Failure(reason: "Two beats hold the same sentence (\(sentences[y.first].id)).")
        }
        // Sentences no beat holds join the beat before them (or the first beat, at the start).
        var gaps = 0
        if drafts[0].first > 0 { gaps += drafts[0].first; drafts[0].first = 0 }
        for k in drafts.indices.dropLast() where drafts[k + 1].first > drafts[k].last + 1 {
            gaps += drafts[k + 1].first - drafts[k].last - 1
            drafts[k].last = drafts[k + 1].first - 1
        }
        if drafts[drafts.count - 1].last < sentences.count - 1 {
            gaps += sentences.count - 1 - drafts[drafts.count - 1].last
            drafts[drafts.count - 1].last = sentences.count - 1
        }
        if gaps > 0 { notes.append("\(Format.count(gaps, "sentence")) no beat held joined the beat before.") }

        // The model's own ids, mapped to ours for dependsOn.
        var ours: [String: String] = [:]
        for (k, d) in drafts.enumerated() { ours[d.givenID] = "b\(k + 1)" }
        var beats: [Beat] = []
        var leftOutLines = 0, leftOutPhrases = 0, unknownKinds = 0, droppedLinks = 0, clamped = 0
        for (k, d) in drafts.enumerated() {
            let f = d.fields
            let firstWord = sentences[d.first].first, lastWord = sentences[d.last].last
            var scores: [String: Int] = [:]
            let given = f["scores"] as? [String: Any] ?? [:]
            for tag in BeatTag.allCases {
                let value = (given[tag.rawValue] as? NSNumber)?.doubleValue ?? 0
                let whole = Int(value.rounded())
                if Double(whole) != value || whole < 0 || whole > 3 { clamped += 1 }
                scores[tag.rawValue] = min(3, max(0, whole))
            }
            let kind: BeatKind
            if let named = (f["kind"] as? String).flatMap({ BeatKind(rawValue: $0.lowercased()) }) { kind = named } else { kind = .teaching; unknownKinds += 1 }
            let id = "b\(k + 1)"
            var depends: [String] = []
            for other in (f["dependsOn"] as? [String]) ?? [] {
                if let mapped = ours[other], mapped != id, let m = Int(mapped.dropFirst()), m < k + 1 { depends.append(mapped) } else { droppedLinks += 1 }
            }
            var key: Beat.KeyLine?
            if let line = (f["keyLine"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                if let found = find(line, in: words, from: firstWord, to: lastWord) {
                    key = Beat.KeyLine(from: words[found.lowerBound].id, to: words[found.upperBound].id, text: PlanWords.text(words[found]))
                } else {
                    leftOutLines += 1
                }
            }
            // The key phrase (v2 part M9d): 2 to 6 words, word for word inside the key line (else inside the beat), or left out.
            var phrase: Beat.KeyLine?
            if let line = (f["keyPhrase"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                let count = line.split(whereSeparator: \.isWhitespace).count
                let inside = key.flatMap { k in PlanWord.index(of: k.from).flatMap { a in PlanWord.index(of: k.to).map { (a, $0) } } }
                let found = (count >= 2 && count <= 6) ? (inside.flatMap { find(line, in: words, from: $0.0, to: $0.1) } ?? find(line, in: words, from: firstWord, to: lastWord)) : nil
                if let found {
                    phrase = Beat.KeyLine(from: words[found.lowerBound].id, to: words[found.upperBound].id, text: PlanWords.text(words[found]))
                } else {
                    leftOutPhrases += 1
                }
            }
            let terms = ((f["terms"] as? [String]) ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0.count <= 40 }
            let summary = WritingText.withoutDashes(((f["summary"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)).0
            beats.append(Beat(id: id, firstSentence: sentences[d.first].id, lastSentence: sentences[d.last].id, from: words[firstWord].id, to: words[lastWord].id,
                              start: words[firstWord].start, end: words[lastWord].end, summary: String(summary.prefix(80)), scores: scores, kind: kind,
                              standsAlone: (f["standsAlone"] as? Bool) ?? true, dependsOn: depends, keyLine: key, keyPhrase: phrase,
                              hookCandidate: (f["hookCandidate"] as? Bool) ?? false, terms: Array(terms.prefix(8)), thesis: (f["thesis"] as? Bool) ?? false))
        }
        let loose = loosen(&beats)
        if loose > 0 { notes.append("\(Format.count(loose, "link")) from a close or to housekeeping left out: a close stands on its own, and nothing needs housekeeping.") }
        if leftOutLines > 0 { notes.append("\(Format.count(leftOutLines, "key line")) not found word for word, so left out.") }
        if leftOutPhrases > 0 { notes.append("\(Format.count(leftOutPhrases, "key phrase")) not 2 to 6 words found word for word, so left out.") }
        if unknownKinds > 0 { notes.append("\(Format.count(unknownKinds, "beat")) with no kind the app knows read as teaching.") }
        if droppedLinks > 0 { notes.append("\(Format.count(droppedLinks, "link")) to a beat that is not earlier left out.") }
        if clamped > 0 { notes.append("\(Format.count(clamped, "score")) outside 0 to 3 brought inside.") }
        // Exactly one thesis: the model's first, else the teaching beat that scores highest for enlightening and philosophy.
        let marked = beats.indices.filter { beats[$0].thesis }
        if marked.count > 1 {
            for i in marked.dropFirst() { beats[i].thesis = false }
            notes.append("More than one beat was marked as the main point; the first is kept.")
        } else if marked.isEmpty, let best = beats.indices.filter({ beats[$0].kind == .teaching }).max(by: {
            (beats[$0].score(.enlightening) + beats[$0].score(.philosophy), beats[$1].start) < (beats[$1].score(.enlightening) + beats[$1].score(.philosophy), beats[$0].start)
        }) {
            beats[best].thesis = true
            notes.append("No beat was marked as the main point; the teaching beat that scores highest for enlightening was taken.")
        }
        return (beats, notes)
    }

    /// Links that would chain a whole talk together (v2 part M9d): a closing beat depends on nothing (a close stands on its own),
    /// and no beat depends on housekeeping. Measured 15 Oct on the 13 Sep talk: the model linked the close to the practice, the
    /// practice to the schedule, the schedule to the teaching before it and so on back to the welcome, so keeping the close kept
    /// 12:18 of a video asked to be under 10 minutes. Returns how many links it left out.
    static func loosen(_ beats: inout [Beat]) -> Int {
        let housekeeping = Set(beats.filter(\.isHousekeeping).map(\.id))
        var dropped = 0
        for k in beats.indices {
            let before = beats[k].dependsOn.count
            if beats[k].kind == .closing { beats[k].dependsOn = [] } else { beats[k].dependsOn.removeAll { housekeeping.contains($0) } }
            dropped += before - beats[k].dependsOn.count
        }
        return dropped
    }

    /// The words of `line` inside words `from` to `to`, word for word (case and punctuation aside), or nil.
    static func find(_ line: String, in words: [PlanWord], from: Int, to: Int) -> ClosedRange<Int>? {
        let wanted = line.split(whereSeparator: \.isWhitespace).map { PlanWord.normalize(String($0)) }.filter { !$0.isEmpty }
        guard !wanted.isEmpty, to - from + 1 >= wanted.count else { return nil }
        for start in from...(to - wanted.count + 1) where words[start].norm == wanted[0] {
            if (0..<wanted.count).allSatisfy({ words[start + $0].norm == wanted[$0] }) { return start...(start + wanted.count - 1) }
        }
        return nil
    }

    /// The words of each beat's time on the original's clock, from its words' refined times when a plan gives them.
    static func range(_ beat: Beat, refined: [String: EditPlan.WordTime]) -> TimeRange {
        TimeRange(start: refined[beat.from]?.in ?? beat.start, end: refined[beat.to]?.out ?? beat.end)
    }
}
