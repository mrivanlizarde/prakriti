import Foundation

// The house style and its four styles as numbers (v2 part M9a, docs/v2/PLAN.md M9; research-edit-engine.md 2.3, 2.4, 2.5
// and 2.6). Every number below is the research's table, in one place, so the rough cut, the visual plan and the tests read
// the same figures:
//
// - **Clear** (the house style, research 2.3): pauses 0.18 / 0.40 s inside a sentence and 0.35 / 0.60 s between sentences;
//   6 to 8 visual changes a minute, 10 or more in the first 30 s; shots about 6 s; punch-ins alternate 1.00 and 1.12; a slow
//   push-in to 1.05 over 4 s at most once in 90 s.
// - **Calm**, **Energetic**, **Story** (research 2.4's Calm teacher, Energetic and Documentary columns).
// - **Teaching** is a switch on any style; **Pace** scales the pause and cut numbers by 0.8, 1.0 or 1.25; **Length** is a
//   target in seconds (research 2.5). Pace and Teaching act in M9a; Length is kept as a number for the selection (M9c).
//
// The House Style pane (Settings) chooses the style, the pace, the punch-ins and the room at the end; every video is made
// from it until the Direction tab (M9d) can steer one recording. Nothing here asks a model anything.

/// The four styles (research 2.5's single list of names).
enum StyleName: String, Codable, CaseIterable, Identifiable, Sendable {
    case clear, calm, energetic, story

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: "Clear"
        case .calm: "Calm"
        case .energetic: "Energetic"
        case .story: "Story"
        }
    }

    /// One plain line for the House Style pane.
    var line: String {
        switch self {
        case .clear: "The house style: tight pauses, about 7 changes of picture a minute, every other one a punch-in."
        case .calm: "Longer shots and pauses, gentle punch-ins only where a cut would jump. For meditation and slow classes."
        case .energetic: "Short pauses and shots, a change of framing at every cut, 12 to 15 a minute. For short motivational talks."
        case .story: "Room to breathe between sentences, a change every 10 to 15 seconds. For longer stories."
        }
    }
}

/// Pace: the chosen style's pause and cut numbers scaled (research 2.5).
enum Pace: Int, Codable, CaseIterable, Identifiable, Sendable {
    case relaxed = -1
    case balanced = 0
    case brisk = 1

    var id: Int { rawValue }

    /// More than 1 is faster: changes a minute times this, pauses and shots divided by it.
    var factor: Double {
        switch self {
        case .relaxed: 0.8
        case .balanced: 1.0
        case .brisk: 1.25
        }
    }

    var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .balanced: "Balanced"
        case .brisk: "Brisk"
        }
    }
}

/// Punch-ins in the House Style pane (research 2.5): none, Calm's gentle ones, the style's own, or Energetic's.
enum PunchLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, subtle, standard, punchy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .standard: "Standard"
        case .punchy: "Punchy"
        }
    }
}

/// How long the video should be (research 2.5: Length; "Highlights" is about 3 minutes). Kept as a number for the
/// selection under a length (M9c); M9a makes every video from the whole recording.
enum Length: Equatable, Sendable {
    case whole
    case about(minutes: Double)

    var targetSeconds: Double? {
        switch self {
        case .whole: nil
        case .about(let minutes): minutes * 60
        }
    }

    static let highlights = Length.about(minutes: 3)
}

/// What the House Style pane holds (Settings, House Style), kept in the preferences as JSON (`AppSettings.houseStyle`).
struct HouseStyle: Codable, Equatable, Sendable {
    var style = StyleName.clear
    var pace = Pace.balanced
    var punchIns = PunchLevel.standard
    /// Teaching: demonstrations kept whole and wide (research 2.5). In M9a: no punch-in inside a span and no push-in, and
    /// wide wherever no face is seen; the beats of M9c will mark demonstrations themselves.
    var teaching = false
    /// Speech ends 5 s before the last frame, the picture held wide (research 2.3, room for YouTube's end screen).
    var endingRoom = true
    /// The recording's title on screen for the first 2 s (v2 part M9b), when it has one in Info.
    var titleOnScreen = true
    /// Each teacher's name on screen once, near the bottom of the frame (v2 part M9b): the lower third.
    var namesOnScreen = true

    static let standard = HouseStyle()

    init(style: StyleName = .clear, pace: Pace = .balanced, punchIns: PunchLevel = .standard, teaching: Bool = false, endingRoom: Bool = true,
         titleOnScreen: Bool = true, namesOnScreen: Bool = true) {
        self.style = style
        self.pace = pace
        self.punchIns = punchIns
        self.teaching = teaching
        self.endingRoom = endingRoom
        self.titleOnScreen = titleOnScreen
        self.namesOnScreen = namesOnScreen
    }

    /// Reads every setting that is there and takes the standard for any that is not, so a House Style saved before a setting
    /// existed (M9a's, before the text of M9b) keeps every choice Ivan made. A synthesized decoder would refuse the whole
    /// value for one missing key and fall back to the standard, losing them.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let standard = HouseStyle()
        style = (try? c.decodeIfPresent(StyleName.self, forKey: .style)) ?? standard.style
        pace = (try? c.decodeIfPresent(Pace.self, forKey: .pace)) ?? standard.pace
        punchIns = (try? c.decodeIfPresent(PunchLevel.self, forKey: .punchIns)) ?? standard.punchIns
        teaching = (try? c.decodeIfPresent(Bool.self, forKey: .teaching)) ?? standard.teaching
        endingRoom = (try? c.decodeIfPresent(Bool.self, forKey: .endingRoom)) ?? standard.endingRoom
        titleOnScreen = (try? c.decodeIfPresent(Bool.self, forKey: .titleOnScreen)) ?? standard.titleOnScreen
        namesOnScreen = (try? c.decodeIfPresent(Bool.self, forKey: .namesOnScreen)) ?? standard.namesOnScreen
    }

    /// One line that changes whenever a setting does: kept in the plan's basis, so the app can say the plan is behind.
    var signature: String {
        "\(style.rawValue) pace \(pace.rawValue) punch-ins \(punchIns.rawValue) teaching \(teaching ? 1 : 0) ending \(endingRoom ? 1 : 0)"
            + " title \(titleOnScreen ? 1 : 0) names \(namesOnScreen ? 1 : 0)"
    }

    /// Reads the preference, falling back to the standard for anything missing or unreadable.
    static func decode(_ json: String?) -> HouseStyle {
        guard let json, let data = json.data(using: .utf8), let style = try? JSONDecoder().decode(HouseStyle.self, from: data) else { return .standard }
        return style
    }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}

/// One style's numbers, with the House Style pane's settings applied (`Style.make`).
struct Style: Equatable, Sendable {
    /// A slow push-in: from 1.00 to `to` over `seconds`, at most once every `every` seconds of the video.
    struct PushIn: Equatable, Sendable {
        var to: Double
        var seconds: Double
        var every: Double
    }

    /// A snap zoom (Energetic only, research 2.4): to `to` in `frames` frames on a punchline, at most once in `every` s.
    /// Kept as numbers: a punchline is a beat (M9c), so M9a never places one.
    struct SnapZoom: Equatable, Sendable {
        var to: Double
        var frames: Int
        var every: Double
    }

    var name: StyleName

    // The rough cut's pauses (research 2.4).
    var insideTarget: Double
    var insideTrigger: Double
    var sentenceTarget: Double
    var sentenceTrigger: Double
    /// Protected silences (a breath cue, a question) are kept up to this long.
    var protectedLimit: Double
    /// Kept before a word's first sound.
    var leadIn: Double

    // The picture (research 2.3, 2.4).
    /// Visual changes a minute (a cut or a change of punch-in; text arrives in M9b).
    var changesPerMinute: ClosedRange<Double>
    /// Visual changes in the first 30 s (research 2.1: densest at the start). 0: no front-loading.
    var openingChanges: Int
    /// The median shot the changes aim at, in seconds.
    var medianShot: ClosedRange<Double>
    /// The shortest shot a punch change inside a span may make, in seconds (in the first 30 s, `openingShortest`).
    var shortestShot: Double
    var openingShortest: Double
    /// The punch-in scales in their rotation, wide first (Clear: 1.00, 1.12). Capped per recording by `maxScale`.
    var punchScales: [Double]
    /// Calm: a cut changes the punch-in only where it would visibly jump.
    var punchOnlyWhereCutsJump: Bool
    /// Punch changes inside a span (between two sentences) to keep the shots near `medianShot`; off with Teaching.
    var punchInsideSpans: Bool
    var pushIn: PushIn?
    var snapZoom: SnapZoom?
    /// Back to wide after this many tight shots in a row (research 2.3).
    var backToWideAfter = 3
    /// Where in `changesPerMinute` the picture's changes aim, from 0 (its bottom) to 1 (its top): the middle by default; a
    /// direction's pace and cuts move it (v2 part M9c, `Direction.style`), never outside the style's own range.
    var changeAim = 0.5
    /// Speech ends this long before the last frame, the picture held wide (0: no room at the end).
    var endingSeconds: Double

    var teaching: Bool
    var pace: Pace
    var length: Length

    /// A punch-in never past this on any source (research 2.6: about 1.15 for a 1080p source to a 1080p video).
    static let resolutionBudget = 1.15

    /// The largest scale a recording allows: `min(style scale, 1.15 x sourceHeight / outputHeight)` (research 2.6). The
    /// video is made at the source's own size, so a 1080p recording never goes past 1.15.
    static func maxScale(_ scale: Double, sourceHeight: Double, outputHeight: Double) -> Double {
        guard sourceHeight > 0, outputHeight > 0 else { return 1 }
        return min(scale, resolutionBudget * sourceHeight / outputHeight)
    }

    /// The style's own numbers, before the pane's settings.
    static func base(_ name: StyleName) -> Style {
        switch name {
        case .clear:
            Style(name: .clear, insideTarget: 0.18, insideTrigger: 0.40, sentenceTarget: 0.35, sentenceTrigger: 0.60, protectedLimit: 4, leadIn: 0.08,
                  changesPerMinute: 6...8, openingChanges: 10, medianShot: 5.5...6.5, shortestShot: 2.0, openingShortest: 1.5,
                  punchScales: [1.00, 1.12], punchOnlyWhereCutsJump: false, punchInsideSpans: true,
                  pushIn: PushIn(to: 1.05, seconds: 4, every: 90), snapZoom: nil, endingSeconds: 5, teaching: false, pace: .balanced, length: .whole)
        case .calm:
            Style(name: .calm, insideTarget: 0.30, insideTrigger: 0.70, sentenceTarget: 0.60, sentenceTrigger: 1.00, protectedLimit: 8, leadIn: 0.12,
                  changesPerMinute: 3...4, openingChanges: 0, medianShot: 10...15, shortestShot: 5.0, openingShortest: 5.0,
                  punchScales: [1.00, 1.06], punchOnlyWhereCutsJump: true, punchInsideSpans: true,
                  pushIn: PushIn(to: 1.04, seconds: 6, every: 150), snapZoom: nil, endingSeconds: 5, teaching: false, pace: .balanced, length: .whole)
        case .energetic:
            Style(name: .energetic, insideTarget: 0.10, insideTrigger: 0.25, sentenceTarget: 0.20, sentenceTrigger: 0.35, protectedLimit: 2, leadIn: 0.06,
                  changesPerMinute: 12...15, openingChanges: 14, medianShot: 3...4, shortestShot: 1.5, openingShortest: 1.2,
                  punchScales: [1.00, 1.15, 1.25], punchOnlyWhereCutsJump: false, punchInsideSpans: true,
                  pushIn: nil, snapZoom: SnapZoom(to: 1.30, frames: 6, every: 45), endingSeconds: 5, teaching: false, pace: .balanced, length: .whole)
        case .story:
            Style(name: .story, insideTarget: 0.22, insideTrigger: 0.50, sentenceTarget: 0.45, sentenceTrigger: 0.80, protectedLimit: 4, leadIn: 0.10,
                  changesPerMinute: 4...6, openingChanges: 6, medianShot: 7...9, shortestShot: 3.0, openingShortest: 2.5,
                  punchScales: [1.00, 1.10], punchOnlyWhereCutsJump: false, punchInsideSpans: true,
                  pushIn: PushIn(to: 1.06, seconds: 6, every: 60), snapZoom: nil, endingSeconds: 5, teaching: false, pace: .balanced, length: .whole)
        }
    }

    /// The numbers a video is made with: the style, then Pace, then the pane's punch-ins, then Teaching and the ending.
    static func make(_ house: HouseStyle, length: Length = .whole) -> Style {
        var style = base(house.style)
        // Pace (research 2.5): pauses, triggers and shots divided by the factor, changes multiplied by it.
        let f = house.pace.factor
        style.pace = house.pace
        if f != 1 {
            style.insideTarget /= f
            style.insideTrigger /= f
            style.sentenceTarget /= f
            style.sentenceTrigger /= f
            style.changesPerMinute = (style.changesPerMinute.lowerBound * f)...(style.changesPerMinute.upperBound * f)
            style.openingChanges = Int((Double(style.openingChanges) * f).rounded())
            style.medianShot = (style.medianShot.lowerBound / f)...(style.medianShot.upperBound / f)
            style.shortestShot /= f
            style.openingShortest /= f
            if var push = style.pushIn {
                push.every /= f
                style.pushIn = push
            }
        }
        // Punch-ins (research 2.5): Off, Subtle = Calm's, Standard = the style's own, Punchy = Energetic's.
        switch house.punchIns {
        case .off:
            style.punchScales = [1.00]
            style.pushIn = nil
            style.snapZoom = nil
        case .subtle:
            let calm = base(.calm)
            style.punchScales = calm.punchScales
            style.punchOnlyWhereCutsJump = calm.punchOnlyWhereCutsJump
            style.pushIn = calm.pushIn
        case .standard:
            break
        case .punchy:
            let energetic = base(.energetic)
            style.punchScales = energetic.punchScales
            style.punchOnlyWhereCutsJump = false
        }
        if house.teaching {
            style.teaching = true
            style.punchInsideSpans = false
            style.pushIn = nil
            style.snapZoom = nil
        }
        style.endingSeconds = house.endingRoom ? 5 : 0
        style.length = length
        return style
    }

    /// The rough cut's numbers for this style. Clear's are exactly `RoughCutPreset.clear` (M8a's measured defaults).
    var roughCut: RoughCutPreset {
        var preset = RoughCutPreset()
        preset.name = name.rawValue
        preset.insideTarget = insideTarget
        preset.insideTrigger = insideTrigger
        preset.sentenceTarget = sentenceTarget
        preset.sentenceTrigger = sentenceTrigger
        preset.protectedLimit = protectedLimit
        preset.leadIn = leadIn
        return preset
    }

    /// The scales of the rotation a recording allows: each capped by `maxScale`, repeats dropped, wide first.
    func scales(sourceHeight: Double, outputHeight: Double) -> [Double] {
        var out: [Double] = []
        for scale in punchScales {
            let capped = (Self.maxScale(scale, sourceHeight: sourceHeight, outputHeight: outputHeight) * 1000).rounded() / 1000
            if !out.contains(where: { abs($0 - capped) < 0.005 }) { out.append(max(1, capped)) }
        }
        if out.first != 1 { out.insert(1, at: 0) }
        return out
    }
}
