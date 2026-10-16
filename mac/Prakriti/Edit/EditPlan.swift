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
    /// Chapters (v2 part M9d): from the parts of the talk, on the video's own clock. Empty without beats.
    var chapters: [Chapter] = []
    /// The held moment (v2 part M9d, research 2.3): one stretch of the main point kept uncut and still, on the original's clock.
    /// Nil when there is none.
    var held: TimeRange?
    var people = People()
    /// The beats chosen under the direction (v2 part M9c), or nil when no beats were needed.
    var beatChoice: BeatChoice?
    /// The plan in plain lines, shown before anything is made (v2 part M9c): "Cuts pauses longer than 0.4 s.", "Punch-ins
    /// about every 8 s.", "Keeps the story at 12:40.", "Ends at 11:48." Nil in a plan made before M9c.
    var planLines: [String]?
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

    /// Ivan's direction as it made this plan (v2 part M9c): his words, the chips read back, and the whole reading (the
    /// fields, what the rules could not read, the model's reading of it, what was said back), so the next plan reuses the
    /// model's reading of the same words and the app shows what made this plan.
    struct Direction: Codable, Equatable, Sendable {
        var prompt: String
        var chips: [String] = []
        var presets: [DirectionPreset]?
        var pace: Pace?
        var length: LengthChoice?
        var reading: DirectionReading?
    }

    /// The beats the direction chose from (v2 part M9c): who annotated them, which were kept and which left out, and the
    /// length aimed at.
    struct BeatChoice: Codable, Equatable, Sendable {
        var by: String
        var beats: Int
        var kept: [String]
        var dropped: [String]
        var targetSeconds: Double?
        /// The beats that must be kept are longer than the length asked for.
        var overBudget = false
    }

    /// A stretch kept: from one word to another, on the original's clock, with its exact words. A span whose role is `hook`
    /// (v2 part M9d) is the opening line: played first, out of the talk's order, and again in its place in the talk.
    ///
    /// A span whose role is `insert` (v2 part M12b, research 3.4 and 3.5) is a moment from another recording that Ivan added by hand:
    /// `source` is that recording's name, `from`, `to`, `in` and `out` are on ITS clock and word numbers, and it carries what a renderer
    /// needs to draw and hear it without a second plan: the original's path, its word times (for the captions), the day it was said,
    /// the colour match and the join. `addedBy` is always "ivan": nothing else ever adds one (`MomentInserts`).
    struct Span: Codable, Equatable, Sendable {
        static let main = "main"
        static let hook = "hook"
        static let insert = "insert"

        var id: String
        var source: String
        var from: String
        var to: String
        var `in`: Double
        var out: Double
        var role = "main"
        var text: String
        // A moment from another recording (v2 part M12b); nil on the talk's own spans.
        /// Who added it: "ivan", the only value a moment can have.
        var addedBy: String?
        /// The model's sentence about why it supports the point.
        var reason: String?
        /// The other recording's original, its label ("Sun 6 Sep 2026, Talk with Gabriel") and the day it was recorded.
        var sourceFile: String?
        var sourceLabel: String?
        var sourceDate: Date?
        /// Its words' times on its own recording's clock, in order (the captions are timed from them).
        var words: [WordTime]?
        /// The colour match (red, green and blue gains on the linear picture), nil when none is needed.
        var colour: [Double]?
        /// The join at each end, in frames: 0 for a hard cut, else a cross dissolve of that many frames centred on the cut.
        var join: Int?

        var isHook: Bool { role == Self.hook }
        var isInsert: Bool { role == Self.insert }
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

    /// What the picture does over a stretch of a span (v2 part M9a, research 3.4 "visual"): a punch-in (`scale` about
    /// `center`, held for the stretch), a slow push-in (from `from` to `to` over `seconds`, eased, ending about `center`), or
    /// the held last frame at the end (`hold`, `seconds` long). `in` and `out` are on the original's clock, inside the span;
    /// `center` is the middle of the framed part of the picture, from its top left, as fractions of the frame. Every frame no
    /// item covers is the whole picture (1.00).
    ///
    /// Text (v2 part M9b): the title at the start (`title`) and a teacher's name (`lowerThird`), each starting at `in` inside
    /// `span` on the original's clock and shown for `seconds` of the edited video, its `lines` drawn in `box` (from the top
    /// left, fractions of the frame: x, y, width, height, where the text sits once it has come in), lined up on `align`, the
    /// title at `size` (pixels of a 1080-line picture). Key phrases, term cards and the rest arrive in M9d.
    struct Visual: Codable, Equatable, Sendable {
        var span: String
        var kind: String
        var `in`: Double?
        var out: Double?
        var scale: Double?
        var from: Double?
        var to: Double?
        var seconds: Double?
        var center: [Double]?
        var lines: [String]?
        var box: [Double]?
        var align: String?
        var size: Double?
        /// The words a key phrase or term card shows (v2 part M9d): the first and last word's ids, so the text is checked against
        /// the transcript word for word.
        var words: [String]?

        static let punchIn = "punchIn"
        static let pushIn = "pushIn"
        static let hold = "hold"
        static let title = "title"
        static let lowerThird = "lowerThird"
        /// The speaker's own words on screen, 2 to 6 (v2 part M9d); `from` and `to` name its first and last word in `lines`.
        static let keyPhrase = "keyPhrase"
        /// A term the talk explains, spelled from the word list (v2 part M9d).
        static let term = "term"

        var isText: Bool { OverlayKind(rawValue: kind) != nil }
    }

    /// A chapter (v2 part M9d): its title (a few plain words for the part of the talk), the first word it starts at, and where it
    /// starts on the video's own clock (0 for the first).
    struct Chapter: Codable, Equatable, Sendable {
        var title: String
        var at: String
        var seconds: Double?
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
        /// The House Style the plan was made with (`HouseStyle.signature`, v2 part M9a). Nil in a plan made before M9a.
        var house: String?
        /// The direction it was made with (`RecordingDirection.signature`, v2 part M9c); empty for none. Nil in a plan made
        /// before M9c, read as none.
        var direction: String?
        /// The moments Ivan added (`MomentInserts.signature`, v2 part M12b); nil for none.
        var moments: String?
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
        case .beat:
            return "A part your direction leaves out, \(length)."
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

    /// The talk's kept time, the opening line not counted twice.
    var keptSeconds: Double { mainSpans.reduce(0) { $0 + $1.out - $1.in } }

    /// What the plan does to the picture, in one sentence (v2 part M9a), or nil when it does nothing: "Picture, Clear: 39
    /// punch-ins and 4 slow push-ins; the last frame is held 4.8 s, so the speaking ends 5 s before the end."
    var pictureSummary: String? {
        guard !visual.isEmpty else { return nil }
        let punches = visual.filter { $0.kind == Visual.punchIn }.count, pushes = visual.filter { $0.kind == Visual.pushIn }.count
        var parts: [String] = []
        if punches > 0 { parts.append(Format.count(punches, "punch-in")) }
        if pushes > 0 { parts.append(Format.count(pushes, "slow push-in")) }
        var line = "Picture, \(StyleName(rawValue: style)?.title ?? style): " + (parts.isEmpty ? "the whole picture throughout" : parts.joined(separator: " and "))
        if holdSeconds > 0 { line += String(format: "; the last frame is held %.1f s, so the speaking ends 5 s before the end", holdSeconds) }
        if let text = textSummary { line += ". " + text }
        return line + "."
    }

    /// The text on screen in a few words (v2 part M9b), or nil when there is none: "On screen: the title for 2 s at the start
    /// and 1 name". Never a name itself: the line can reach a notice-like place.
    var textSummary: String? {
        let titles = visual.filter { $0.kind == Visual.title }.count, names = visual.filter { $0.kind == Visual.lowerThird }.count
        let phrases = visual.filter { $0.kind == Visual.keyPhrase }.count, terms = visual.filter { $0.kind == Visual.term }.count
        var parts: [String] = []
        if titles > 0 { parts.append(hook == nil ? "the title for 2 s at the start" : "the title for 2 s after the opening line") }
        if names > 0 { parts.append(Format.count(names, "name") + " under the teacher") }
        if phrases > 0 { parts.append(Format.count(phrases, "key phrase")) }
        if terms > 0 { parts.append(Format.count(terms, "term")) }
        return parts.isEmpty ? nil : "On screen: " + Self.joined(parts)
    }

    /// "a", "a and b", "a, b and c".
    static func joined(_ parts: [String]) -> String {
        parts.count <= 2 ? parts.joined(separator: " and ") : parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
    }

    /// The opening line's spans (v2 part M9d), played first; empty when the video opens on the talk.
    var hookSpans: [Span] { spans.filter(\.isHook) }
    /// The talk's own spans, in its order: never the opening line, never a moment from another recording (v2 part M12b).
    var mainSpans: [Span] { spans.filter { !$0.isHook && !$0.isInsert } }
    /// The moments from other recordings Ivan added (v2 part M12b), in the video's order.
    var insertSpans: [Span] { spans.filter(\.isInsert) }
    /// Every span of this recording's own clock: the opening line and the talk, never a moment from another recording.
    var ownSpans: [Span] { spans.filter { !$0.isInsert } }
    /// The opening line, from its first word to its last, or nil.
    var hook: (from: String, to: String, seconds: Double)? {
        let h = hookSpans
        guard let first = h.first, let last = h.last else { return nil }
        return (first.from, last.to, h.reduce(0) { $0 + $1.out - $1.in })
    }

    /// How long the last frame is held after the last span (v2 part M9a), 0 when it is not.
    var holdSeconds: Double { visual.first { $0.kind == Visual.hold }?.seconds ?? 0 }

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
        // Parts left out side by side are one cut, so the parts are counted from the choice, not from the cuts.
        let leftOutParts = beatChoice?.dropped.count ?? count(.beat)
        if leftOutParts > 0 { parts.append(Format.count(leftOutParts, "part") + " your direction leaves out") }
        var line = "Keeps \(Format.timecode(keptSeconds)) of \(Format.timecode(sourceDuration))."
        if !parts.isEmpty { line += " Taken out: " + parts.joined(separator: ", ") + "." }
        let added = insertSpans
        if !added.isEmpty {
            line += " Added by you: " + Format.count(added.count, "moment") + " from another recording ("
                + Format.timecode(added.reduce(0) { $0 + $1.out - $1.in }) + ")."
        }
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
