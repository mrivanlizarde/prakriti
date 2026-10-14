import Foundation

// Who is in each output (v2 part M6c, docs/v2/PLAN.md M6, research-people.md 3.1, 3.4 and 3.5, design spec 3.5.2):
// one choice per person, Include, Hide Face or Leave Out, for every output at once or one output at a time.
//
// - **Include:** seen and heard as recorded.
// - **Hide Face:** heard as recorded; the face is hidden wherever it appears. Nothing changes in the sound, and the
//   pictures that hide a face are part M6d's (`FaceHide`): today the card picture, from M8d the video.
// - **Leave Out:** every stretch the person speaks is cut from the podcast episode and the podcast-ready episode,
//   widened to whole words and into the pauses so no syllable is left, stopping short of the next word kept (Mac
//   warning 120), with v1's 15 ms fades (Mac warning 42); the transcript
//   files follow (warning 39).
//
// Everyone starts as **Include**. Reason: Ivan, Mon 12 Oct 2026 (PLAN section 11, "releases exist"): "All the
// participants have signed an agreement that includes that their likeness can be used for commercial purposes", so
// people found in a recording default to Include and the three choices are editing choices, not a privacy gate. The
// plan's earlier default (Leave Out for anyone unnamed, section 5) was written before that note.
//
// With nobody left out and no name muted, nothing here changes the episode: the mastering chain stays engine v0's
// string for string (Mac warning 30), and `make accept-outputs` still checks it bit for bit.

/// One person's choice for an output.
enum PersonChoice: String, Codable, CaseIterable, Sendable {
    case include
    case hideFace
    case leaveOut

    /// The pop-up's words (research-people.md 3.1; Ivan's 12 Oct note).
    var title: String {
        switch self {
        case .include: "Include"
        case .hideFace: "Hide Face"
        case .leaveOut: "Leave Out"
        }
    }

    /// What the choice does, for the row under the pop-up and the receipt.
    var meaning: String {
        switch self {
        case .include: "seen and heard as recorded"
        case .hideFace: "heard as recorded, face hidden"
        case .leaveOut: "left out"
        }
    }

    /// Their speech is cut from the sound.
    var cutsSpeech: Bool { self == .leaveOut }

    /// The choices a voice with no face can take: a face cannot be hidden when there is none.
    static let forVoice: [PersonChoice] = [.include, .leaveOut]
}

/// The outputs a choice can differ for (design spec 3.5.2, Customize per Output). Only the podcast is made today;
/// video and shorts are parts M8 and M11, and read the same choices when they exist.
enum ChoiceOutput: String, Codable, CaseIterable, Sendable {
    case podcast
    case video
    case shorts

    var title: String {
        switch self {
        case .podcast: "Podcast"
        case .video: "Video"
        case .shorts: "Shorts"
        }
    }

    /// The outputs this build makes, so the only ones a per-output choice is offered for.
    static let built: [ChoiceOutput] = [.podcast]
}

/// Who a choice belongs to: a person Ivan named (every row of theirs at once), or one face row or one voice not named.
enum PersonKey: Hashable, Sendable, Comparable {
    case named(UUID)
    case face(Int)
    case voice(Int)

    var string: String {
        switch self {
        case .named(let id): "person:" + id.uuidString
        case .face(let row): "face:\(row)"
        case .voice(let id): "voice:\(id)"
        }
    }

    init?(_ string: String) {
        let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "person": guard let id = UUID(uuidString: parts[1]) else { return nil }; self = .named(id)
        case "face": guard let row = Int(parts[1]) else { return nil }; self = .face(row)
        case "voice": guard let id = Int(parts[1]) else { return nil }; self = .voice(id)
        default: return nil
        }
    }

    var isNamed: Bool { if case .named = self { true } else { false } }

    static func < (a: PersonKey, b: PersonKey) -> Bool { a.string < b.string }

    /// The key of a face row: its name when it has one, else the row itself.
    static func face(_ row: Int, names: (faces: [Int: UUID], voices: [Int: UUID])) -> PersonKey {
        names.faces[row].map { .named($0) } ?? .face(row)
    }

    /// The key of a voice: its name when it has one, else the face row it is linked to, else the voice itself.
    static func voice(_ voice: FoundVoice, names: (faces: [Int: UUID], voices: [Int: UUID])) -> PersonKey {
        if let id = names.voices[voice.id] { return .named(id) }
        if let row = voice.face { return Self.face(row, names: names) }
        return .voice(voice.id)
    }
}

/// Keep or Mute, for a name said aloud (PLAN section 5, Serenity's standing condition).
enum NameDecision: String, Codable, Sendable {
    case keep
    case mute

    var title: String { self == .keep ? "Keep" : "Mute" }
}

/// Ivan's choices for one recording (`Recording.choicesJSON`): who is in each output, the names said aloud he kept or
/// muted, and whether he listened to the changes of voice. Nothing about a face or a voice: keys and words only.
struct PeopleChoices: Codable, Equatable, Sendable {
    struct Decision: Codable, Equatable, Sendable {
        var choice: PersonChoice
        /// Customize per Output: a different choice for one output.
        var outputs: [ChoiceOutput: PersonChoice] = [:]
    }

    /// By `PersonKey.string`.
    var people: [String: Decision] = [:]
    /// By `NameMoment.key`.
    var names: [String: NameDecision] = [:]
    /// The changes of voice on a mixed track were listened to, for the voices checked at this moment
    /// (`VoicesFound.checkedAt`): a new voice check asks again.
    var listenedFor: Date?

    static let none = PeopleChoices()

    /// Everyone starts here (Ivan, 12 Oct: releases exist).
    static let defaultChoice: PersonChoice = .include

    var isEmpty: Bool { people.isEmpty && names.isEmpty && listenedFor == nil }

    /// A person's choice for one output: their own for that output, else their choice for every output, else the
    /// default.
    func choice(_ key: PersonKey, for output: ChoiceOutput) -> PersonChoice {
        guard let decision = people[key.string] else { return Self.defaultChoice }
        return decision.outputs[output] ?? decision.choice
    }

    /// The choice for every output, and whether any output differs from it.
    func overall(_ key: PersonKey) -> (choice: PersonChoice, differs: Bool) {
        let decision = people[key.string]
        return (decision?.choice ?? Self.defaultChoice, !(decision?.outputs.isEmpty ?? true))
    }

    /// Sets the choice for every output (nil output), which clears the per-output ones, or for one output.
    mutating func set(_ choice: PersonChoice, for key: PersonKey, output: ChoiceOutput? = nil) {
        var decision = people[key.string] ?? Decision(choice: Self.defaultChoice)
        if let output {
            decision.outputs[output] = choice == decision.choice ? nil : choice
        } else {
            decision.choice = choice
            decision.outputs = [:]
        }
        people[key.string] = decision.choice == Self.defaultChoice && decision.outputs.isEmpty ? nil : decision
    }

    /// Set All Unnamed To: every key not named takes the choice for every output.
    mutating func setAll(_ choice: PersonChoice, unnamed keys: [PersonKey]) {
        for key in keys where !key.isNamed { set(choice, for: key) }
    }

    func name(_ moment: NameMoment) -> NameDecision? { names[moment.key] }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode(_ json: String?) -> PeopleChoices {
        guard let json, let data = json.data(using: .utf8) else { return .none }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PeopleChoices.self, from: data)) ?? .none
    }

    /// Anyone is left out of the podcast or any name is muted: the podcast changes, so the make plans the step that
    /// applies it. Read before the make knows its voices, so it errs toward planning the step.
    var changesPodcast: Bool {
        people.values.contains { ($0.outputs[.podcast] ?? $0.choice) == .leaveOut } || names.values.contains(.mute)
    }

    /// Someone is left out of the podcast (so the voices must be known, or nothing is made).
    var leavesSomeoneOut: Bool {
        people.values.contains { ($0.outputs[.podcast] ?? $0.choice) == .leaveOut }
    }

    /// The voices left out of the podcast (or another output: the edit plan of v2 part M8a reads the video's), by the
    /// voice step's ids.
    func leftOutVoices(_ voices: VoicesFound, names: (faces: [Int: UUID], voices: [Int: UUID]), output: ChoiceOutput = .podcast) -> [Int] {
        voices.voices.filter { choice(PersonKey.voice($0, names: names), for: output) == .leaveOut }.map(\.id).sorted()
    }

    /// Someone is left out of `output`.
    func leavesSomeoneOut(of output: ChoiceOutput) -> Bool {
        people.values.contains { ($0.outputs[output] ?? $0.choice) == .leaveOut }
    }

    /// The names said aloud that are muted, of those found.
    func muted(_ moments: [NameMoment]) -> [NameMoment] {
        moments.filter { names[$0.key] == .mute }
    }

    /// What the podcast is made with, in one line, so the page can tell when the choices on it are not in the episode
    /// yet ("" when nobody is left out and nothing is muted, as for every recording made before this part).
    func podcastSignature(voices: VoicesFound?, names: (faces: [Int: UUID], voices: [Int: UUID]), moments: [NameMoment]) -> String {
        let out = voices.map { leftOutVoices($0, names: names) } ?? []
        let muted = muted(moments).map(\.key).sorted()
        if out.isEmpty && muted.isEmpty { return "" }
        return "out:" + out.map(String.init).joined(separator: ",") + ";mute:" + muted.joined(separator: ",")
    }
}

/// What leaving people out does to the podcast, worked out from who speaks when and the transcript's word times.
/// Seconds on the original recording's clock.
struct LeaveOut: Codable, Equatable, Sendable {
    /// Voices left out, by id.
    var voices: [Int] = []
    /// The stretches cut, grown to whole words and toward the pauses around them (never into the next kept word), sorted and joined.
    var cuts: [TimeRange] = []
    /// Where someone left out and someone included speak at once (research-people.md 3.5): cut too, never kept on its
    /// own, and listed for listening.
    var overlaps: [TimeRange] = []
    /// The names said aloud that are muted, each padded so the whole word goes.
    var mutes: [TimeRange] = []

    var removedSeconds: Double { cuts.reduce(0) { $0 + max(0, $1.end - $1.start) } }

    var isEmpty: Bool { cuts.isEmpty && mutes.isEmpty }

    /// Two stretches of a left-out voice this close are one cut.
    static let joinGap = 1.0
    /// How far a cut reaches into a pause longer than `shortGap`.
    static let pauseReach = 0.25
    /// A gap between words this short or shorter is taken whole by the cut, up to `edge` from the next word.
    static let shortGap = 0.5
    static let edge = 0.03
    /// With no word times (the transcript is off), a cut is widened by this much each side.
    static let blindPad = 0.35
    /// A muted name is silenced from this much before the word to this much after it: the sound is changed in
    /// frames of about 21 ms (`Mastering.muteFilter`), so the edge of a frame never lets the start of a name through.
    static let mutePad = 0.06
    /// Speech that touches a word for less than this does not take the word.
    static let touch = 0.04
    /// How early a kept word may really start before the time Parakeet gives it. A cut growing toward the next word
    /// stops this far before that word's start (never before the words it already takes), so the next word is kept
    /// whole. Parakeet's times come in steps of 80 ms and the start of a word is often late: measured 13 Oct on the
    /// remade two-people fixtures, Gabriel's "business" was placed at 48.80 s, while in the clean 13sep-90s clip it is
    /// 48.64 s and cutting the clean clip at 48.77 s loses the word (cuts at 48.50 to 48.70 keep it, Parakeet).
    static let wordLead = 0.24
    /// How far beyond the left-out voice's own stretch a cut always reaches, wherever the words are: the voice step's
    /// times are rounded, and the fades at a cut are 15 ms.
    static let voiceTail = 0.05

    /// The cuts for the voices left out: each stretch they speak, joined where another stretch of theirs follows
    /// within a short gap, then grown to take every word it touches whole (the included person's words included,
    /// where they speak at once: fail closed, research-people.md 3.5), then grown into the gap on each side (a short
    /// gap whole, a long pause by `pauseReach`), so the cut lands in silence. Words are the transcript's (`wordSpans`).
    static func plan(segments: [VoiceSegment], leftOut: Set<Int>, words: [TimeRange]?, mutes muted: [NameMoment] = [],
                     duration: Double, audio: EdgeLevels? = nil) -> LeaveOut {
        var out = LeaveOut()
        out.voices = leftOut.sorted()
        out.mutes = muted.map { TimeRange(start: max(0, $0.start - mutePad), end: min(duration, $0.end + mutePad)) }
        let theirs = segments.filter { leftOut.contains($0.voice) && $0.length > 0 }
        guard !theirs.isEmpty else { return out }
        let others = segments.filter { !leftOut.contains($0.voice) && $0.length > 0 }
        // Their stretches, joined across a gap under `joinGap`: an island of the teacher that short between two of their
        // phrases is cut with them (fail closed). Measured 13 Oct on two-people-tracks: a 0.35 s piece left between two
        // stretches of the second voice was heard by Parakeet as a different word.
        var joined: [TimeRange] = []
        for stretch in EpisodeEdits.merged(theirs.map { TimeRange(start: $0.start, end: $0.end) }) {
            if let last = joined.last, stretch.start - last.end < joinGap { joined[joined.count - 1].end = max(last.end, stretch.end) } else { joined.append(stretch) }
        }
        // Speaking at once: the left-out stretches that an included voice also speaks in.
        var overlaps: [TimeRange] = []
        for stretch in joined {
            for other in others where other.end > stretch.start && other.start < stretch.end {
                overlaps.append(TimeRange(start: max(stretch.start, other.start), end: min(stretch.end, other.end)))
            }
        }
        out.overlaps = EpisodeEdits.merged(overlaps).filter { $0.end - $0.start >= 0.2 }
        let sorted = (words ?? []).filter { $0.end >= $0.start }.sorted { $0.start < $1.start }
        var cuts: [TimeRange] = []
        for stretch in joined {
            var low = stretch.start, high = stretch.end
            if words == nil {
                cuts.append(TimeRange(start: max(0, low - blindPad), end: min(duration, high + blindPad)))
                continue
            }
            // Every word the stretch touches goes whole.
            for word in sorted where min(word.end, high) - max(word.start, low) > touch || (word.start >= low && word.end <= high) {
                low = min(low, word.start)
                high = max(high, word.end)
            }
            // Then into the pause on each side: a short gap (up to `shortGap`) is taken whole, to within `edge` of the
            // word before, so no tail of a word the left-out voice spoke over is left as a fragment; a longer pause gives up
            // `pauseReach` of itself. Toward the next word the cut stops `wordLead` before Parakeet's start for it, because
            // that start is often late (fixed 13 Oct: the cut had ended 0.13 s inside Gabriel's "business" and lost it).
            let before = sorted.last { $0.end <= low + 0.0001 }?.end
            let after = sorted.first { $0.start >= high - 0.0001 }?.start
            func reach(_ gap: Double?) -> Double {
                guard let gap else { return pauseReach }
                return gap <= shortGap ? max(0, gap - edge) : pauseReach
            }
            let taken = high
            low -= reach(before.map { max(0, low - $0) })
            high += reach(after.map { max(0, $0 - high) })
            // Never into the next kept word, allowing for its start being late (`wordLead`): the cut may end no later than
            // `wordLead` before it, and never earlier than the words it takes.
            if let after { high = max(taken, min(high, after - wordLead)) }
            if let audio, let quiet = audio.quiet(in: TimeRange(start: stretch.end, end: high), toward: .start)?.start {
                // With the sound itself (the track the episode is made from): the end goes to the start of the quiet between
                // the left-out voice's own end and the end worked out from the words (`EdgeLevels.quiet`). Parakeet's word
                // edges are 80 ms steps and often late, so on real speech they can put the end inside the next word; the
                // sound cannot. Measured 13 Oct on two-people-tracks: the words gave 48.64 s and lost "business"; the
                // quiet after the voice's end (48.50 s) starts at 48.51 s, and the word is kept.
                high = quiet
            } else {
                // Without it, always `voiceTail` beyond the left-out voice's own end, whatever the words say (fail closed).
                high = max(high, min(duration, stretch.end + voiceTail))
            }
            if let audio, let quiet = audio.quiet(in: TimeRange(start: low, end: stretch.start), toward: .end)?.end {
                low = quiet
            } else {
                low = min(low, max(0, stretch.start - voiceTail))
            }
            cuts.append(TimeRange(start: max(0, low), end: min(duration, high)))
        }
        out.cuts = EpisodeEdits.merged(cuts)
        return out
    }

    /// "Leaving out Voice 2 takes out 22 s." for the People tab, from that person's own cuts alone.
    static func consequence(label: String, seconds: Double) -> String {
        seconds < 0.5 ? "\(label) is not heard, so leaving them out takes nothing out of the podcast."
                      : "Leaving out \(label) takes \(Format.length(seconds)) out of the podcast."
    }

    /// The step's line in the make's steps and the log: counts only, never a name.
    var stepLine: String {
        var parts: [String] = []
        if !voices.isEmpty {
            parts.append(voices.count == 1 ? "One voice left out" : "\(VoicesFound.word(voices.count).capitalizedFirst) voices left out")
            parts[parts.count - 1] += cuts.isEmpty ? ", not heard in it." : ": \(Format.count(cuts.count, "cut")), \(Format.length(removedSeconds)) in all, each taking whole words and stopping short of the next word kept."
        }
        if !overlaps.isEmpty {
            parts.append("\(Format.count(overlaps.count, "stretch", "stretches")) where they speak at the same time as someone included " + (overlaps.count == 1 ? "is" : "are") + " cut too, to listen to.")
        }
        if !mutes.isEmpty { parts.append("\(Format.count(mutes.count, "name")) said aloud muted.") }
        return parts.isEmpty ? "Nobody is left out." : parts.joined(separator: " ")
    }
}

/// The level of the sound the episode is made from (its first audio track, mono 16 kHz), in pieces around the edges of
/// the cuts: what `LeaveOut.plan` settles each edge against. Levels only, dropped when the step returns; never a voice
/// print.
struct EdgeLevels: Sendable {
    struct Piece: Sendable {
        /// Seconds on the original's clock of the first sample.
        var start: Double
        /// RMS in dB of each `window` of samples, every `hop`.
        var levels: [Double]
    }

    var pieces: [Piece] = []

    static let hop = 0.005
    /// Longer than the 15 ms fade at each side of a cut (`EpisodeEdits.fade`), so the fade lies in the quiet.
    static let window = 0.02
    /// How far either side of a cut's first edge the sound is read: more than a whole word (`longestWord`, 1 s) and a
    /// short gap (0.5 s) beyond the voice's own edge.
    static let reach = 2.5
    static let sampleRate = 16_000

    /// The 20 ms levels every 5 ms of a run of samples.
    static func levels(_ samples: [Float]) -> [Double] {
        let size = Int(Double(sampleRate) * window), step = Int(Double(sampleRate) * hop)
        guard samples.count >= size else { return [] }
        return stride(from: 0, through: samples.count - size, by: step).map { index in
            var sum: Double = 0
            for i in index..<(index + size) { let v = Double(samples[i]); sum += v * v }
            let rms = (sum / Double(size)).squareRoot()
            return rms > 0 ? 20 * log10(rms) : -120
        }
    }

    /// The quiet in `range`: the quietest 20 ms lying wholly inside it, then widened to the first (`toward: .start`) or
    /// last (`.end`) 20 ms within `quietMargin` of it. Nil when the range is shorter than 20 ms or no piece covers it.
    /// A cut's end goes at the start of the first such window and a cut's start at the end of the last, so the 15 ms fade
    /// of the part kept beside it falls in the quiet, as far from the next word's first sound as the quiet allows.
    /// Measured 13 Oct on two-people-tracks' first track, the voiced "b" of "business" after a dip whose quietest 20 ms
    /// starts at 48.54 s: an end at 48.505, 48.52, 48.525, 48.53 or 48.535 keeps the word (Parakeet, with the fades), an end
    /// at 48.54, 48.545 or 48.55 loses its "b" ("isness"). The quietest point is the stop's own closure; the quiet begins
    /// before it.
    func quiet(in range: TimeRange, toward side: Side) -> TimeRange? {
        guard range.end - range.start >= Self.window - 0.0001 else { return nil }
        for piece in pieces {
            let first = Int(((range.start - piece.start) / Self.hop - 0.0001).rounded(.up))
            let last = Int(((range.end - Self.window - piece.start) / Self.hop + 0.0001).rounded(.down))
            guard first >= 0, last < piece.levels.count, first <= last else { continue }
            let quietest = piece.levels[first...last].min() ?? 0
            let within = (first...last).filter { piece.levels[$0] <= quietest + Self.quietMargin }
            guard let index = side == .start ? within.first : within.last else { continue }
            let start = piece.start + Double(index) * Self.hop
            return TimeRange(start: start, end: start + Self.window)
        }
        return nil
    }

    enum Side: Sendable { case start, end }

    /// How far above the quietest 20 ms a window still counts as the same quiet, in dB.
    static let quietMargin = 10.0
}

/// What the last make applied of Ivan's choices, and what the audio output check found in the files it made
/// (`Recording.peopleAppliedJSON`). Times and counts only.
struct PeopleApplied: Codable, Equatable, Sendable {
    var madeAt: Date
    /// `PeopleChoices.podcastSignature` at the make.
    var signature: String
    var leaveOut: LeaveOut
    /// Nil when nothing needed checking (nobody left out).
    var check: AudioCheck?

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode(_ json: String?) -> PeopleApplied? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PeopleApplied.self, from: data)
    }
}

extension EpisodeTranscript {
    /// Every word's start and end on the original's clock, from Parakeet's tokens in the order they were said: what a
    /// cut is widened against. A word is never taken as longer than `longestWord`: Parakeet stretches the last word
    /// before a pause across the pause (Mac warning 40, "caught." ran 3 s into the silence), and a stretched end would
    /// make the pause look like speech.
    static func wordSpans(_ sentences: [Sentence]) -> [TimeRange] {
        sentences.flatMap { sentence in
            words(sentence.tokens ?? [Token(text: sentence.text, start: sentence.start, end: sentence.end)])
                .filter { $0.contains { isWord($0.text) } }
                .compactMap { word in
                    word.first.map { TimeRange(start: $0.start, end: min($0.start + longestWord, max($0.start, word.last?.end ?? $0.end))) }
                }
        }.sorted { $0.start < $1.start }
    }

    static let longestWord = 1.0
}
