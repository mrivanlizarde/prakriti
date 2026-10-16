import Foundation

// Editorial direction (v2 part M9c, docs/v2/PLAN.md M9; research-edit-engine.md 3.2; design spec 3.5.3 and 3.7): how Ivan steers
// one recording's edit, in his own words, with presets, a pace and a length. What he writes becomes a small, bounded set of
// fields (`DirectionFields`, research 3.2's vocabulary and nothing else):
//
// 1. **Presets** (design spec 3.5.3: Energetic, Calm, Faster Cuts, Fewer Cuts, Motivating, Enlightening, Story First, Teaching
//    Only), each a fixed set of fields, so a choice is never lost in a long prompt.
// 2. **The rules table** (`DirectionRules`): the common phrases ("faster", "calmer", "more energetic", "fewer cuts", "no zooms",
//    "under 10 minutes", "focus on the motivating parts") read with no model at all, instantly and the same way every time.
// 3. **The model, only for the rest**: a clause the rules cannot read goes to the "Planning the edit" task's model under the
//    privacy lock. Its answer may only use the vocabulary's fields; an answer naming any other field is refused whole
//    (`DirectionModelCheck`), so a model can never set who appears, consent or publishing.
//
// Never in the vocabulary: who appears, Hide Face or Leave Out, consent, publishing. A clause about them changes nothing and is
// answered with "People are chosen under People." (or the publishing sentence). Every field read is shown back as a chip Ivan
// can remove before anything is made (research 3.2: acknowledge, keep the person in control).
//
// Stored per recording (`Recording.directionJSON`) and recorded in the plan (`EditPlan.Direction`), so the plan says which
// direction made it and the app can say "Your direction changed."

/// The design spec's preset capsules (3.5.3). Opposite pairs switch each other off.
enum DirectionPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case energetic, calm, fasterCuts, fewerCuts, motivating, enlightening, storyFirst, teachingOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energetic: "Energetic"
        case .calm: "Calm"
        case .fasterCuts: "Faster Cuts"
        case .fewerCuts: "Fewer Cuts"
        case .motivating: "Motivating"
        case .enlightening: "Enlightening"
        case .storyFirst: "Story First"
        case .teachingOnly: "Teaching Only"
        }
    }

    /// The preset this one switches off.
    var opposite: DirectionPreset? {
        switch self {
        case .energetic: .calm
        case .calm: .energetic
        case .fasterCuts: .fewerCuts
        case .fewerCuts: .fasterCuts
        default: nil
        }
    }

    var fields: DirectionFields {
        var f = DirectionFields()
        switch self {
        case .energetic: f.style = .energetic
        case .calm: f.style = .calm
        case .fasterCuts: f.cutDensity = 1
        case .fewerCuts: f.cutDensity = -1
        case .motivating: f.focus = [BeatTag.motivating.rawValue: DirectionFields.focusWeight]
        case .enlightening: f.focus = [BeatTag.enlightening.rawValue: DirectionFields.focusWeight]
        case .storyFirst: f.style = .story
        case .teachingOnly: f.teaching = true
        }
        return f
    }
}

/// The design spec's Length pop-up (3.5.3).
enum LengthChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case everything, about20, about10, about3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: "Everything that matters"
        case .about20: "About 20 minutes"
        case .about10: "About 10 minutes"
        case .about3: "About 3 minutes"
        }
    }

    var seconds: Double? {
        switch self {
        case .everything: nil
        case .about20: 1_200
        case .about10: 600
        case .about3: 180
        }
    }
}

/// Words on screen (research 3.2's `text`).
enum TextLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, subtle, bold

    var id: String { rawValue }

    /// The House Style pane's words (v2 part M9d).
    var title: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .bold: "Bold"
        }
    }
}

/// The only fields a direction can set (research 3.2). `pace` and `cutDensity` are steps from -2 to 2 (positive is faster, more
/// cuts); `focus` is tag to weight; topics are plain words matched against the beats.
struct DirectionFields: Codable, Equatable, Sendable {
    /// The weight a focused tag gets (research 3.2's example), against `otherWeight` for the rest.
    static let focusWeight = 1.5
    static let otherWeight = 0.25
    /// The keys a model's answer may use. Anything else and the answer is refused whole.
    static let vocabulary: Set<String> = ["style", "pace", "cutDensity", "punchIns", "text", "captionsBurned", "targetSeconds", "focus", "avoid",
                                          "keepWhole", "hook"]

    var style: StyleName?
    var pace = 0
    var cutDensity = 0
    var punchIns: PunchLevel?
    var text: TextLevel?
    var captionsBurned: Bool?
    var targetSeconds: Double?
    var focus: [String: Double] = [:]
    var focusTopics: [String] = []
    var avoid: [String] = []
    var avoidTopics: [String] = []
    var keepWhole: [String] = []
    var hook: Bool?
    /// Teaching Only (a preset, research 2.5's Teaching switch).
    var teaching: Bool?

    var isEmpty: Bool { self == DirectionFields() }

    /// Whether choosing beats is needed: a length, a focus, something to leave out or keep whole.
    var needsBeats: Bool {
        targetSeconds != nil || !focus.isEmpty || !focusTopics.isEmpty || !avoid.isEmpty || !avoidTopics.isEmpty || !keepWhole.isEmpty
    }

    /// `other` laid over this one: its values win, steps add (kept within -2 to 2), lists join.
    func merged(with other: DirectionFields) -> DirectionFields {
        var m = self
        if let s = other.style { m.style = s }
        m.pace = max(-2, min(2, pace + other.pace))
        m.cutDensity = max(-2, min(2, cutDensity + other.cutDensity))
        if let p = other.punchIns { m.punchIns = p }
        if let t = other.text { m.text = t }
        if let c = other.captionsBurned { m.captionsBurned = c }
        if let t = other.targetSeconds { m.targetSeconds = t }
        for (k, v) in other.focus { m.focus[k] = v }
        m.focusTopics = Self.join(focusTopics, other.focusTopics)
        m.avoid = Self.join(avoid, other.avoid)
        m.avoidTopics = Self.join(avoidTopics, other.avoidTopics)
        m.keepWhole = Self.join(keepWhole, other.keepWhole)
        if let h = other.hook { m.hook = h }
        if let t = other.teaching { m.teaching = t }
        return m
    }

    static func join(_ a: [String], _ b: [String]) -> [String] {
        var out = a
        for x in b where !out.contains(where: { $0.caseInsensitiveCompare(x) == .orderedSame }) { out.append(x) }
        return out
    }

    /// The weight of each tag for the selection: focused tags `focusWeight` (or the weight given), the rest `otherWeight`
    /// when anything is focused, else 1; a tag to avoid 0.
    var weights: [BeatTag: Double] {
        var w: [BeatTag: Double] = [:]
        for tag in BeatTag.allCases {
            if avoid.contains(tag.rawValue) { w[tag] = 0 } else if let f = focus[tag.rawValue] { w[tag] = f } else { w[tag] = focus.isEmpty ? 1 : Self.otherWeight }
        }
        return w
    }
}

/// One field read back to Ivan (research 3.2's chips): its id (what removing it clears) and its words.
struct DirectionChip: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var text: String
}

/// What Ivan set for one recording (Settings' House Style is the starting point for everything not set here).
struct RecordingDirection: Codable, Equatable, Sendable {
    var prompt = ""
    var presets: [DirectionPreset] = []
    /// Nil: the House Style's pace.
    var pace: Pace?
    var length = LengthChoice.everything
    /// Chips Ivan removed (their ids): the fields they hold are cleared.
    var removed: [String] = []
    /// How many shorts and how long (v2 part M11a, the Direction tab's Shorts): nil is 3 shorts of up to 60 s. Not part of the plan
    /// (the shorts are cut from it), so neither is in `isEmpty` or `signature`.
    var shortsCount: Int?
    var shortsLength: Int?
    /// The moments from other recordings Ivan added by hand (v2 part M12b), in the order he added them. Kept with the direction
    /// because they steer this recording's video the same way, so no store change comes with them; not in `isEmpty` or `signature`
    /// (the plan keeps their own, `MomentInserts.signature`).
    var moments: [AddedMoment] = []

    init(prompt: String = "", presets: [DirectionPreset] = [], pace: Pace? = nil, length: LengthChoice = .everything, removed: [String] = [],
         shortsCount: Int? = nil, shortsLength: Int? = nil) {
        self.prompt = prompt
        self.presets = presets
        self.pace = pace
        self.length = length
        self.removed = removed
        self.shortsCount = shortsCount
        self.shortsLength = shortsLength
    }

    /// The shorts asked for: 0 to 5, 30, 45 or 60 s.
    var shorts: ShortsSettings {
        var out = ShortsSettings()
        if let count = shortsCount { out.count = min(max(count, ShortsSettings.counts.lowerBound), ShortsSettings.counts.upperBound) }
        if let length = shortsLength, ShortsSettings.lengths.contains(length) { out.length = length }
        return out
    }

    /// Reads field by field, so a direction saved by an older build keeps every choice.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt = (try? c.decodeIfPresent(String.self, forKey: .prompt)) ?? ""
        presets = (try? c.decodeIfPresent([DirectionPreset].self, forKey: .presets)) ?? []
        pace = try? c.decodeIfPresent(Pace.self, forKey: .pace)
        length = (try? c.decodeIfPresent(LengthChoice.self, forKey: .length)) ?? .everything
        removed = (try? c.decodeIfPresent([String].self, forKey: .removed)) ?? []
        shortsCount = try? c.decodeIfPresent(Int.self, forKey: .shortsCount)
        shortsLength = try? c.decodeIfPresent(Int.self, forKey: .shortsLength)
        moments = (try? c.decodeIfPresent([AddedMoment].self, forKey: .moments)) ?? []
    }

    var trimmedPrompt: String { prompt.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEmpty: Bool { trimmedPrompt.isEmpty && presets.isEmpty && pace == nil && length == .everything }

    /// Changes whenever anything Ivan set does: kept in the plan's basis.
    var signature: String {
        isEmpty ? "" : "\(trimmedPrompt)|\(presets.map(\.rawValue).sorted().joined(separator: ","))|\(pace.map { String($0.rawValue) } ?? "house")|\(length.rawValue)|\(removed.sorted().joined(separator: ","))"
    }

    /// Turns a preset on (switching off its opposite) or off.
    mutating func toggle(_ preset: DirectionPreset) {
        if let i = presets.firstIndex(of: preset) {
            presets.remove(at: i)
        } else {
            if let opposite = preset.opposite { presets.removeAll { $0 == opposite } }
            presets.append(preset)
        }
        removed = []
    }

    static func decode(_ json: String?) -> RecordingDirection {
        guard let json, let data = json.data(using: .utf8), let d = try? JSONDecoder().decode(RecordingDirection.self, from: data) else { return RecordingDirection() }
        return d
    }

    func json() -> String? {
        guard !isEmpty || !removed.isEmpty || shortsCount != nil || shortsLength != nil || !moments.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) }
    }
}

/// What a direction comes to: the fields, the chips, and what was said back.
struct DirectionReading: Codable, Equatable, Sendable {
    var fields = DirectionFields()
    var chips: [DirectionChip] = []
    /// Clauses the rules could not read (sent to the model, if one is asked).
    var unread: [String] = []
    /// The model's own reading of `unread`, kept so the same words are never asked about twice, and who gave it.
    var byModel: DirectionFields?
    var modelBy: String?
    /// For which words the model's reading was given.
    var modelReadFor: String?
    /// Sentences said back: the People sentence, what is not built yet, a model reading refused.
    var said: [String] = []
}

enum Direction {
    static let peopleSentence = "People are chosen under People."
    static let publishingSentence = "Nothing is posted from here: publishing is always yours to do."
    static let captionsNotBuilt = "Captions on the picture are not made yet; the captions file is beside the video."

    /// The presets, the pace and length controls, the rules, then the model's reading (when it read these very words), with
    /// the removed chips cleared. Pure and instant.
    static func read(_ direction: RecordingDirection, house: HouseStyle, model: (fields: DirectionFields, by: String, readFor: String)? = nil) -> DirectionReading {
        var reading = DirectionReading()
        var fields = DirectionFields()
        for preset in direction.presets { fields = fields.merged(with: preset.fields) }
        if let seconds = direction.length.seconds { fields.targetSeconds = seconds }
        let rules = DirectionRules.read(direction.trimmedPrompt)
        fields = fields.merged(with: rules.fields)
        reading.unread = rules.unread
        reading.said = rules.said
        if let model, !rules.unread.isEmpty, model.readFor == rules.unread.joined(separator: " ") {
            fields = fields.merged(with: model.fields)
            reading.byModel = model.fields
            reading.modelBy = model.by
            reading.modelReadFor = model.readFor
        }
        for id in direction.removed { fields = clear(id, in: fields) }
        reading.fields = fields
        if fields.captionsBurned == true { reading.said.append(captionsNotBuilt) }
        reading.chips = chips(fields, house: house, pace: direction.pace)
        return reading
    }

    /// What removing a chip clears.
    static func clear(_ id: String, in fields: DirectionFields) -> DirectionFields {
        var f = fields
        switch id {
        case "style": f.style = nil
        case "pace": f.pace = 0
        case "cuts": f.cutDensity = 0
        case "punchIns": f.punchIns = nil
        case "text": f.text = nil
        case "captions": f.captionsBurned = nil
        case "length": f.targetSeconds = nil
        case "focus": f.focus = [:]; f.focusTopics = []
        case "avoid": f.avoid = []; f.avoidTopics = []
        case "keepWhole": f.keepWhole = []
        case "hook": f.hook = nil
        case "teaching": f.teaching = nil
        default: break
        }
        return f
    }

    /// The House Style with a direction's style, punch-ins, teaching, words on screen, the opening line and pace laid over it.
    static func house(_ house: HouseStyle, fields: DirectionFields, pace: Pace?) -> HouseStyle {
        var h = house
        if let s = fields.style { h.style = s }
        if let p = fields.punchIns { h.punchIns = p }
        if let t = fields.teaching { h.teaching = t }
        if let pace { h.pace = pace }
        // Words on screen (v2 part M9d): Off takes every text away; Subtle and Bold set how often key phrases come.
        switch fields.text {
        case .off?:
            h.titleOnScreen = false
            h.namesOnScreen = false
            h.keyPhrases = .off
            h.termCards = false
        case .subtle?: h.keyPhrases = .subtle
        case .bold?: h.keyPhrases = .bold
        case nil: break
        }
        if let hook = fields.hook { h.openingLine = hook }
        return h
    }

    /// The numbers a directed video is made with: the House Style with the direction laid over it (`house`), then the pace
    /// and cut steps: each pace step makes the pauses that are kept 0.85 times as long (research 3.2), and pace and cuts together
    /// move where the picture's changes aim inside the style's own range (its middle at 0, toward its top or bottom by a fifth
    /// of it a step). The style's range is the boundary: a direction never makes Clear into Energetic by the back door.
    ///
    /// A pace step changes how long a shortened pause stays, never which pauses are cut (the triggers). Reason, measured 15 Oct on
    /// the whole 13 Sep talk: with the triggers scaled too, "More energetic. Faster, more frequent cuts." cut so many more short
    /// pauses that the median shot fell to 2.94 s, under Energetic's 3 to 4 s (PLAN M9 check 3); every extra cut is a jump.
    static func style(_ house: HouseStyle, fields: DirectionFields, pace: Pace?, length: Length = .whole) -> Style {
        var style = Style.make(Self.house(house, fields: fields, pace: pace), length: length)
        if fields.pace != 0 {
            let f = pow(0.85, Double(fields.pace))
            style.insideTarget *= f
            style.sentenceTarget *= f
        }
        style.changeAim = max(0.1, min(0.9, 0.5 + 0.2 * Double(fields.pace + fields.cutDensity)))
        return style
    }

    /// The chips for these fields, in the order the design spec reads them.
    static func chips(_ fields: DirectionFields, house: HouseStyle, pace: Pace?) -> [DirectionChip] {
        var chips: [DirectionChip] = []
        let style = Self.style(house, fields: fields, pace: pace)
        if let s = fields.style { chips.append(DirectionChip(id: "style", text: "Style: \(s.title)")) }
        if fields.pace != 0 {
            let word = fields.pace > 0 ? (fields.pace > 1 ? "much faster" : "faster") : (fields.pace < -1 ? "much slower" : "slower")
            chips.append(DirectionChip(id: "pace", text: String(format: "Pace: %@ (pauses between sentences kept to %.2f s)", word, style.sentenceTarget)))
        }
        if fields.cutDensity != 0 {
            chips.append(DirectionChip(id: "cuts", text: fields.cutDensity > 0 ? "Cuts: more frequent" : "Cuts: fewer"))
        }
        if let p = fields.punchIns { chips.append(DirectionChip(id: "punchIns", text: "Punch-ins: \(p.title)")) }
        if fields.teaching == true { chips.append(DirectionChip(id: "teaching", text: "Teaching: demonstrations whole and wide")) }
        if let t = fields.text {
            chips.append(DirectionChip(id: "text", text: t == .off ? "Text on screen: off" : (t == .subtle ? "Key phrases: now and then" : "Key phrases: more often")))
        }
        if let c = fields.captionsBurned { chips.append(DirectionChip(id: "captions", text: c ? "Captions on the picture" : "No captions on the picture")) }
        if let t = fields.targetSeconds { chips.append(DirectionChip(id: "length", text: "Length: " + lengthWords(t))) }
        let focus = BeatTag.allCases.filter { fields.focus[$0.rawValue] != nil }.map(\.title) + fields.focusTopics
        if !focus.isEmpty { chips.append(DirectionChip(id: "focus", text: "Focus: " + list(focus))) }
        let avoid = BeatTag.allCases.filter { fields.avoid.contains($0.rawValue) }.map(\.title) + fields.avoidTopics
        if !avoid.isEmpty { chips.append(DirectionChip(id: "avoid", text: "Leaves out: " + list(avoid))) }
        if !fields.keepWhole.isEmpty { chips.append(DirectionChip(id: "keepWhole", text: "Keeps whole: " + list(fields.keepWhole))) }
        if let h = fields.hook { chips.append(DirectionChip(id: "hook", text: h ? "Opens on the strongest line" : "No opening line")) }
        return chips
    }

    /// "under 10 min", "about 3 min", "about 45 s".
    static func lengthWords(_ seconds: Double) -> String {
        seconds >= 60 ? String(format: "at most %@ min", Self.minutes(seconds)) : String(format: "at most %.0f s", seconds)
    }

    static func minutes(_ seconds: Double) -> String {
        let m = seconds / 60
        return m == m.rounded() ? String(format: "%.0f", m) : String(format: "%.1f", m)
    }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: items[0] + " and " + items[1]
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}

/// Checks a model's reading of a direction (LOCAL-MODEL.md rule 4): only the vocabulary's keys, each with a value it can hold.
/// One key outside the vocabulary, or one value out of range, and the whole reading is refused.
enum DirectionModelCheck {
    struct Refusal: Error, Equatable, Sendable {
        let reason: String
    }

    static func check(_ text: String) throws -> DirectionFields {
        guard let object = WritingCheck.jsonObject(text) else { throw Refusal(reason: "The answer was not a JSON object.") }
        var f = DirectionFields()
        for (key, value) in object {
            guard DirectionFields.vocabulary.contains(key) else {
                throw Refusal(reason: "The reading named \"\(key)\", which is not something a direction can set.")
            }
            if value is NSNull { continue }
            switch key {
            case "style":
                guard let s = (value as? String).flatMap({ StyleName(rawValue: $0.lowercased()) }) else { throw bad(key) }
                f.style = s
            case "pace", "cutDensity":
                guard let n = value as? NSNumber, n.doubleValue == n.doubleValue.rounded(), (-2...2).contains(n.intValue) else { throw bad(key) }
                if key == "pace" { f.pace = n.intValue } else { f.cutDensity = n.intValue }
            case "punchIns":
                guard let p = (value as? String).flatMap({ PunchLevel(rawValue: $0.lowercased()) }) else { throw bad(key) }
                f.punchIns = p
            case "text":
                guard let t = (value as? String).flatMap({ TextLevel(rawValue: $0.lowercased()) }) else { throw bad(key) }
                f.text = t
            case "captionsBurned", "hook":
                guard let b = value as? Bool else { throw bad(key) }
                if key == "hook" { f.hook = b } else { f.captionsBurned = b }
            case "targetSeconds":
                guard let n = value as? NSNumber, (20...14_400).contains(n.doubleValue) else { throw bad(key) }
                f.targetSeconds = n.doubleValue
            case "focus":
                if let map = value as? [String: Any] {
                    for (k, v) in map {
                        if let tag = BeatTag(rawValue: k.lowercased()) {
                            guard let w = v as? NSNumber, (0.5...3).contains(w.doubleValue) else { throw bad(key) }
                            f.focus[tag.rawValue] = w.doubleValue
                        } else {
                            f.focusTopics.append(k)
                        }
                    }
                } else if let items = value as? [String] {
                    for item in items {
                        if let tag = BeatTag(rawValue: item.lowercased()) { f.focus[tag.rawValue] = DirectionFields.focusWeight } else { f.focusTopics.append(item) }
                    }
                } else {
                    throw bad(key)
                }
            case "avoid":
                guard let items = value as? [String] else { throw bad(key) }
                for item in items {
                    if let tag = BeatTag(rawValue: item.lowercased()) { f.avoid.append(tag.rawValue) } else { f.avoidTopics.append(item) }
                }
            case "keepWhole":
                guard let items = value as? [String] else { throw bad(key) }
                f.keepWhole = items
            default:
                throw bad(key)
            }
        }
        f.focusTopics = f.focusTopics.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return f
    }

    private static func bad(_ key: String) -> Refusal {
        Refusal(reason: "The reading gave \"\(key)\" a value it cannot hold.")
    }
}
