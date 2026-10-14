import Foundation

// The edit plan (v2 part M8a, docs/v2/research-edit-engine.md 3.4, schema `prakriti.editplan/1`): the rough cut in its
// saved form, `edit-plan.json` in the recording's output folder. Written by code, never by a model. Every later output
// (the MP4, its preview, the timelines, the captions, the chapters) is written from it, so it is checked by
// `PlanValidation` before it is saved and again before anything is made from it.
//
// The fields are research 3.4's. Four are added, each because a later part needs it and cannot get it back otherwise:
// `words` (every word's refined start and end, in spoken order: the captions of M8b are timed from them, and rule 3 is checked
// against them), `sourceDuration`, `envelope` (the floor and speech level the cuts were placed on, two numbers, never
// the sound), and `basis` (what the plan was made from, so the app can say it is out of date). `people` also lists the
// stretches cut for the people left out, so rule 5 can be checked on the file alone.
//
// No file a person could post is made from it in M8a (docs/v2/PLAN.md, M8a).

struct EditPlan: Codable, Equatable, Sendable {
    static let schemaName = "prakriti.editplan/1"
    static let fileName = "edit-plan.json"

    var schema = EditPlan.schemaName
    /// The recording's name: its file name without the extension ("2026-09-13 18-25-44").
    var recording: String
    var version = 1
    var transcriptSHA256: String
    var frameDuration: FrameDuration
    var style: String
    var modifiers = Modifiers()
    /// Ivan's direction (M9). Nil in M8a.
    var direction: Direction?
    var spans: [Span] = []
    var removed: [Item] = []
    var checks: [CheckMoment] = []
    /// Punch-ins, text and labels (M9). Empty in M8a.
    var visual: [Visual] = []
    /// Chapters (M9d). Empty in M8a.
    var chapters: [Chapter] = []
    var people = People()
    // Added in M8a (see above).
    var madeAt: Date
    var sourceDuration: Double
    var envelope: EnvelopeLevels
    var words: [WordTime] = []
    var basis: Basis

    struct Modifiers: Codable, Equatable, Sendable {
        var teaching = false
        var pace = 0
        var targetSeconds: Double?
    }

    struct Direction: Codable, Equatable, Sendable {
        var prompt: String
        var chips: [String] = []
    }

    /// A stretch kept: from one word to another, on the original's clock, with its exact words.
    struct Span: Codable, Equatable, Sendable {
        var id: String
        var source: String
        var from: String
        var to: String
        var `in`: Double
        var out: Double
        var role = "main"
        var text: String
    }

    /// A stretch taken out. `from` and `to` are times on the original's clock; `words`, when there are any, is the
    /// first word taken out, or the first and the last.
    struct Item: Codable, Equatable, Sendable {
        var kind: RemovedKind
        var from: Double
        var to: Double
        var words: [String]?
        var confidence: Double
        var keptSeconds: Double?
        var keptTake: [String]?
        var clean = true
        /// The pause's length before it was shortened, for a pause.
        var was: Double?
        /// One sentence for the inspector.
        var say: String
    }

    struct Visual: Codable, Equatable, Sendable {
        var span: String
        var kind: String
    }

    struct Chapter: Codable, Equatable, Sendable {
        var title: String
        var at: String
    }

    /// Who was applied, and what it cut: the people decisions are applied on top of the plan and cannot be overridden by
    /// it (research 3.4 rule 5).
    struct People: Codable, Equatable, Sendable {
        /// The signature of the choices applied (`Pipeline.signature`), empty when everyone is in.
        var applied = ""
        var leftOut: [Int] = []
        var cuts: [TimeRange] = []
        /// Names said aloud that are muted: silenced in the sound, the time kept.
        var mutes: [TimeRange] = []
    }

    struct EnvelopeLevels: Codable, Equatable, Sendable {
        var floorDB: Double
        var speechDB: Double
    }

    /// A word's refined times.
    struct WordTime: Codable, Equatable, Sendable {
        var id: String
        var `in`: Double
        var out: Double
    }

    /// What the plan was made from.
    struct Basis: Codable, Equatable, Sendable {
        var edits: EpisodeEdits
        var peopleSignature: String
        /// The stretches Ivan restored from the Viewer (v2 part M8c). Nil in a plan made before M8c, read as none.
        var restored: [TimeRange]?
    }

    // MARK: Made from a rough cut

    static func from(_ cut: RoughCut, words: PlanWords, input: RoughCut.Input, recording: String, people: People, signature: String,
                     madeAt: Date) -> EditPlan {
        let all = words.words
        var plan = EditPlan(recording: recording, transcriptSHA256: words.transcriptSHA256, frameDuration: input.frame, style: input.preset.name,
                            people: people, madeAt: madeAt, sourceDuration: input.duration,
                            envelope: EnvelopeLevels(floorDB: round2(input.envelope.floor), speechDB: round2(input.envelope.speech)),
                            basis: Basis(edits: input.edits, peopleSignature: signature,
                                         restored: input.restored.isEmpty ? nil : EpisodeEdits.merged(input.restored)))
        plan.spans = cut.kept.enumerated().map { n, span in
            Span(id: "k\(n + 1)", source: recording, from: all[span.first].id, to: all[span.last].id, in: round6(span.start), out: round6(span.end),
                 text: PlanWords.text(all[span.first...span.last]))
        }
        plan.removed = cut.removed.sorted { $0.from < $1.from }.map { r in
            Item(kind: r.kind, from: round6(r.from), to: round6(r.to), words: r.words.map { range in ids(range, all) }, confidence: round2(r.confidence),
                 keptSeconds: r.keptSeconds.map(round3), keptTake: r.keptTake.map { ids($0, all) }, clean: r.clean, was: r.pauseWas.map(round3),
                 say: say(r, words: all))
        }
        plan.checks = cut.checks
        plan.words = all.indices.map { WordTime(id: all[$0].id, in: round3(cut.refinedStart[$0]), out: round3(cut.refinedEnd[$0])) }
        return plan
    }

    static func ids(_ range: ClosedRange<Int>, _ words: [PlanWord]) -> [String] {
        range.count == 1 ? [words[range.lowerBound].id] : [words[range.lowerBound].id, words[range.upperBound].id]
    }

    static func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }
    static func round3(_ x: Double) -> Double { (x * 1000).rounded() / 1000 }
    static func round6(_ x: Double) -> Double { (x * 1_000_000).rounded() / 1_000_000 }

    /// The sentence the inspector shows for a stretch taken out.
    static func say(_ r: Removal, words: [PlanWord]) -> String {
        let length = Format.seconds(r.to - r.from)
        let said = r.words.map { range in
            let text = PlanWords.text(words[range]).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            return text.count > 60 ? String(text.prefix(57)) + "..." : text
        }
        switch r.kind {
        case .pause:
            return "A pause of \(Format.seconds(r.pauseWas ?? 0)) shortened to \(Format.seconds(r.keptSeconds ?? 0))."
        case .filler:
            return "A filler word, \u{201C}\(said ?? "um")\u{201D}, \(length) with the quiet around it."
        case .stutter:
            return "A word said twice, \u{201C}\(said ?? "")\u{201D}; the second is kept."
        case .restart:
            return "A restart, \u{201C}\(said ?? "")\u{201D}; the take after it is kept."
        case .person:
            return "Someone you chose to leave out, \(length)."
        case .cut:
            return "Your cut, \(length)."
        case .trimmed:
            if r.words == nil && r.from < 0.001 { return "Silence before the first word, \(length)." }
            if r.words == nil { return "Silence after the last word, \(length)." }
            return "Your trim, \(length)."
        }
    }

    /// The same restored stretches, to a hundredth of a second (v2 part M8c).
    static func sameRestores(_ a: [TimeRange], _ b: [TimeRange]) -> Bool {
        let x = EpisodeEdits.merged(a), y = EpisodeEdits.merged(b)
        return x.count == y.count && zip(x, y).allSatisfy { abs($0.start - $1.start) < 0.01 && abs($0.end - $1.end) < 0.01 }
    }

    // MARK: Reading it

    var keptSeconds: Double { spans.reduce(0) { $0 + $1.out - $1.in } }

    func count(_ kind: RemovedKind) -> Int { removed.filter { $0.kind == kind }.count }

    /// "Keeps 13:02 of 15:48. Taken out: 212 pauses shortened, 31 fillers, 1 word said twice, 2 restarts. 1 moment to check."
    var summary: String {
        var parts: [String] = []
        let shortened = count(.pause)
        if shortened > 0 { parts.append(Format.count(shortened, "pause") + " shortened") }
        if count(.filler) > 0 { parts.append(Format.count(count(.filler), "filler word")) }
        if count(.stutter) > 0 { parts.append(Format.count(count(.stutter), "word said twice", "words said twice")) }
        if count(.restart) > 0 { parts.append(Format.count(count(.restart), "restart")) }
        if count(.person) > 0 { parts.append(Format.count(count(.person), "stretch", "stretches") + " of someone left out") }
        if count(.cut) > 0 { parts.append(Format.count(count(.cut), "cut") + " of yours") }
        var line = "Keeps \(Format.timecode(keptSeconds)) of \(Format.timecode(sourceDuration))."
        if !parts.isEmpty { line += " Taken out: " + parts.joined(separator: ", ") + "." }
        if !checks.isEmpty { line += " " + Format.count(checks.count, "moment") + " to check." }
        return line
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) -> EditPlan? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let plan = try? decoder.decode(EditPlan.self, from: data), plan.schema == schemaName else { return nil }
        return plan
    }

    /// The plan in a recording's output folder, or nil.
    static func read(folder: String?) -> EditPlan? {
        guard let folder else { return nil }
        let url = URL(fileURLWithPath: folder, isDirectory: true).appending(path: fileName)
        return (try? Data(contentsOf: url)).flatMap(decode)
    }
}
