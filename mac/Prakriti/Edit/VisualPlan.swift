import CoreGraphics
import Foundation

// The visual plan, part one (v2 part M9a, docs/v2/PLAN.md M9; research-edit-engine.md 2.3, 2.4 and 2.6): where the picture
// punches in, where it pushes in slowly, and the held last frame, written into the edit plan's `visual` items by code, from
// the plan's own spans and words, the style's numbers (`Style`) and where the teacher's face is (the people check's boxes).
// No model is asked anything. Text, lower thirds, the hook and chapters are later parts (M9b to M9d).
//
// The rules, each from the research:
// 1. **Shots.** Every kept span starts a shot (a jump cut). Inside a span a shot may change at a sentence or clause end, or at
//    a pause of 0.25 s or more (in the first 30 s, between any two words), so the shots come near the style's median (Clear:
//    about 6 s) and the visual changes a minute
//    reach the middle of the style's range (Clear: 7, of 6 to 8), with the style's count in the first 30 s (Clear: 10).
//    Never a shot under the style's shortest (Clear: 2 s, 1.5 s in the first 30 s), and only where the face is seen, and
//    steady enough to punch in on, on both sides.
// 2. **Punch-ins** (research 2.3, 2.6): the scales alternate in the style's rotation (Clear: 1.00, 1.12), never the same
//    scale twice in a row where a face allows it, back to wide after 3 tight shots, and the last shot is wide; chosen for all
//    the shots together (`assign`), so a shot that cannot be punched in on leaves its neighbours free to change. Each is capped by
//    `Style.maxScale` (a 1080p source never past 1.15), centred on the teacher's face with the eyes on the upper third of
//    the framed picture, and never past the frame's edge. A shot where no face is seen, where the face moves through the shot
//    (eyes over 6% of the frame, or its middle over 10%), where it would leave the framing, or where the eyes could not sit
//    within 4% of the upper third, stays wide. A punch-in is instant: a cut, not a zoom.
// 3. **Push-ins** (research 2.3): on a wide shot with a face, long enough to hold it, from 1.00 to the style's scale (Clear:
//    1.05) over its seconds (Clear: 4 s), eased in and out, at most once in the style's interval (Clear: 90 s). Placed by
//    length until the beats of M9c mark key lines.
// 4. **The ending** (research 2.3): speech ends 5 s before the last frame: the last kept frame is held, wide and silent,
//    for whatever the plan's own tail does not already give.
// 5. **Calm** changes a punch-in at a cut only where the cut would visibly jump (the face moved 2% of the frame or more,
//    or changed size by 5% or more, or is not seen next to the cut).

/// A sighting of the face the punch-ins follow: when, and its box from the top left as fractions of the frame.
struct FaceSpot: Equatable, Sendable {
    var time: Double
    var box: FaceBox
}

enum VisualPlan {
    /// Where the eyes sit inside Vision's face box, from its top, as a fraction of its height. Measured 14 Oct on 29 faces of
    /// the 13 Sep excerpt with Vision's pupils against its box: median 0.267, from 0.228 to 0.362 (numbers only).
    static let eyeInBox = 0.27
    /// How far from the upper third the eyes may sit in a punch-in, as a fraction of the framed height (check 4 allows 5%).
    static let eyeLineTolerance = 0.04
    /// A face is this far inside the framing, as a fraction of the frame, or the shot stays wide.
    static let faceMargin = 0.01
    /// How far the eyes (up and down) and the face's middle (across) may move through a shot, 10th to 90th sighting, as
    /// fractions of the frame, for a still punch-in to keep the eyes near the upper third.
    static let eyeMovement = 0.06
    static let sideMovement = 0.10
    /// A pause this long between two words is a place a shot may change.
    static let splitPause = 0.25

    struct Input: Sendable {
        var plan: EditPlan
        var words: [PlanWord]
        var style: Style
        /// The face the punch-ins follow, in time order (empty: every shot wide).
        var subject: [FaceSpot]
        /// The source picture's height and the video's, in pixels (the video is made at the source's size).
        var sourceHeight: Double
        var outputHeight: Double
        /// Where each beat after the first starts, on the original's clock (v2 part M9c): the picture is wide there.
        var beatStarts: [Double] = []
        /// Where each beat's key line starts, on the original's clock (v2 part M9c): slow push-ins go there first.
        var keyLines: [Double] = []
        /// The held moment (v2 part M9d), on the original's clock: one still, wide shot, no change of framing inside it.
        var held: TimeRange?
        /// How many texts the plan will bring in (v2 part M9d): each is a visual change too (research 2.3), so the picture aims at
        /// that many fewer.
        var textChanges = 0
    }

    /// One shot of the edited video: a stretch of one span with one framing.
    struct Shot: Equatable, Sendable {
        var span: String
        /// Where it starts on the edited clock, and how long it is, in frames.
        var start: Int64
        var frames: Int64
        /// The original's frame at its start.
        var sourceFrame: Int64
        /// It starts at a cut (a new span), not inside one.
        var atCut: Bool
        var scale: Double = 1
        var center: CGPoint?
        var end: Int64 { start + frames }
    }

    // MARK: Making it

    /// The `visual` items for a plan. Pure: the tests drive it with made-up spans and faces.
    static func make(_ input: Input) -> [EditPlan.Visual] {
        let plan = input.plan
        let timeline = EditTimeline(plan: plan)
        guard !timeline.pieces.isEmpty else { return [] }
        let fs = plan.frameDuration.seconds
        let style = input.style
        let rotation = style.scales(sourceHeight: input.sourceHeight, outputHeight: input.outputHeight)
        let subject = input.subject.sorted { $0.time < $1.time }

        var shots = timeline.pieces.enumerated().map { n, piece in
            Shot(span: piece.id, start: piece.editFrame, frames: piece.frames, sourceFrame: piece.sourceFrame, atCut: n > 0)
        }
        func sourceSeconds(_ shot: Shot) -> (Double, Double) {
            (Double(shot.sourceFrame) * fs, Double(shot.sourceFrame + shot.frames) * fs)
        }
        func spots(_ from: Double, _ to: Double) -> [FaceSpot] {
            guard let first = subject.firstIndex(where: { $0.time >= from - 0.25 }) else { return [] }
            var out: [FaceSpot] = []
            for spot in subject[first...] {
                if spot.time > to + 0.25 { break }
                out.append(spot)
            }
            return out
        }
        // A shot that can be punched in at the rotation's largest scale: a face seen, steady enough, inside the frame.
        func frameable(_ shot: Shot) -> Bool {
            guard let largest = rotation.last, largest > 1 else { return false }
            let (a, b) = sourceSeconds(shot)
            return center(for: spots(a, b), scale: largest) != nil
        }

        // 1. Where a shot may change inside each span: the middle of the gap after a sentence or clause end, or of a pause;
        //    in the first 30 s, the gap between any two words (the opening is the densest stretch, research 2.1).
        let opening = Int64((30 / fs).rounded())
        var candidates: [String: [Int64]] = [:]
        if rotation.count > 1 && style.punchInsideSpans {
            let refined = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for (piece, span) in zip(timeline.pieces, plan.spans.filter { s in timeline.pieces.contains { $0.id == s.id } }) {
                guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to), a < b, b < input.words.count else { continue }
                var frames: [Int64] = []
                for k in (a + 1)...b {
                    let before = input.words[k - 1]
                    guard let end = refined[before.id]?.out, let start = refined[input.words[k].id]?.in, start > end else { continue }
                    let source = Int64(((end + start) / 2 / fs).rounded())
                    guard source > piece.sourceFrame, source < piece.sourceFrame + piece.frames else { continue }
                    let edited = piece.editFrame + source - piece.sourceFrame
                    guard before.closes != .none || start - end >= splitPause || edited < opening else { continue }
                    // Never inside the held moment (v2 part M9d): it stays one shot.
                    if let held = input.held, (end + start) / 2 > held.start - 0.5 && (end + start) / 2 < held.end + 0.5 { continue }
                    frames.append(edited)
                }
                candidates[piece.id] = frames
            }
        }
        func split(_ index: Int, near target: Int64, limit: Int64, shortest: Double) -> Bool {
            let shot = shots[index]
            let least = Int64((shortest / fs).rounded())
            let options = (candidates[shot.span] ?? []).filter { c in
                c - shot.start >= least && shot.end - c >= least && c < limit
            }
            // Nearest the middle first; one half at least must show the face steady enough to punch in on, so the split
            // can be a change of framing.
            for c in options.sorted(by: { abs($0 - target) < abs($1 - target) }) {
                var first = shot, second = shot
                first.frames = c - shot.start
                second.start = c
                second.frames = shot.end - c
                second.sourceFrame = shot.sourceFrame + (c - shot.start)
                second.atCut = false
                guard frameable(first) || frameable(second) else { continue }
                shots[index] = first
                shots.insert(second, at: index + 1)
                return true
            }
            return false
        }
        // 2. The punch-ins for a list of shots, chosen together (`assign`), and the changes they make: a cut always counts; a
        //    change inside a span counts only where the framing changes.
        func framing(_ shot: Shot, scale: Double) -> CGPoint? {
            let (a, b) = sourceSeconds(shot)
            return center(for: spots(a, b), scale: scale)
        }
        // Back to wide at every new beat (research 2.3, v2 part M9c): a shot that starts within 0.6 s before a beat's first word
        // or holds it in its first 2 s is wide. A beat that starts deep inside a long shot leaves that shot as it is.
        let beatStarts = input.beatStarts.sorted()
        // The held moment (v2 part M9d): any shot that holds part of it stays wide.
        func inHeld(_ shot: Shot) -> Bool {
            guard let held = input.held else { return false }
            let (a, b) = sourceSeconds(shot)
            return b > held.start && a < held.end
        }
        func atNewBeat(_ shot: Shot) -> Bool {
            guard !beatStarts.isEmpty else { return false }
            let (a, b) = sourceSeconds(shot)
            return beatStarts.contains { $0 >= a - 0.6 && $0 < min(b, a + 2.0) }
        }
        func cutJumps(_ i: Int) -> Bool {
            let end = Double(shots[i].sourceFrame + shots[i].frames) * fs, start = Double(shots[i + 1].sourceFrame) * fs
            return jumps(spots(end - 1, end), spots(start, start + 1))
        }
        func assigned() -> [Int] {
            assign(count: shots.count, levels: rotation.count, backToWideAfter: style.backToWideAfter,
                   allowed: { i, level in level == 0 || (!atNewBeat(shots[i]) && !inHeld(shots[i]) && framing(shots[i], scale: rotation[level]) != nil) },
                   atCut: { shots[$0 + 1].atCut },
                   keepAtCut: { style.punchOnlyWhereCutsJump && !cutJumps($0) })
        }
        func changes(_ levels: [Int]) -> (all: Int, opening: Int) {
            var all = 0, first = 0
            for i in 0..<max(0, shots.count - 1) where shots[i + 1].atCut || levels[i] != levels[i + 1] {
                all += 1
                if shots[i + 1].start < opening { first += 1 }
            }
            return (all, first)
        }
        var levels = rotation.count > 1 ? assigned() : Array(repeating: 0, count: shots.count)

        // 3. More changes where the shots are long: the first 30 s to the style's count (Clear: 10), then the whole video to
        //    the middle of the style's range a minute (Clear: 7), splitting the shot with the most time first. A split counts
        //    only once the punch-ins are chosen again and it changes the framing, so this runs in rounds.
        if !candidates.isEmpty {
            let minutes = Double(timeline.keptFrames) * fs / 60
            let mid = style.changesPerMinute.lowerBound + (style.changesPerMinute.upperBound - style.changesPerMinute.lowerBound) * style.changeAim
            let target = max(0, Int((mid * minutes).rounded()) - input.textChanges)
            var triedOpening = Set<Int64>(), tried = Set<Int64>()
            for _ in 0..<8 {
                let now = changes(levels)
                var wantOpening = max(0, style.openingChanges - now.opening)
                var want = max(0, target - now.all - wantOpening)
                guard wantOpening > 0 || want > 0 else { break }
                var splitAny = false
                while wantOpening > 0 {
                    let inWindow = shots.indices.filter { shots[$0].start < opening && !triedOpening.contains(shots[$0].start) }
                    guard let pick = inWindow.max(by: { min(shots[$0].end, opening) - shots[$0].start < min(shots[$1].end, opening) - shots[$1].start }) else { break }
                    let shot = shots[pick]
                    if split(pick, near: (shot.start + min(shot.end, opening)) / 2, limit: opening, shortest: style.openingShortest) {
                        wantOpening -= 1
                        splitAny = true
                    } else {
                        triedOpening.insert(shot.start)
                    }
                }
                while want > 0 {
                    let open = shots.indices.filter { !tried.contains(shots[$0].start) }
                    guard let pick = open.max(by: { shots[$0].frames < shots[$1].frames }) else { break }
                    let shot = shots[pick]
                    if split(pick, near: (shot.start + shot.end) / 2, limit: .max, shortest: style.shortestShot) {
                        want -= 1
                        splitAny = true
                    } else {
                        tried.insert(shot.start)
                    }
                }
                guard splitAny else { break }
                levels = assigned()
            }
        }
        for i in shots.indices where levels[i] > 0 {
            if let c = framing(shots[i], scale: rotation[levels[i]]) {
                shots[i].scale = rotation[levels[i]]
                shots[i].center = c
            }
        }

        var items: [EditPlan.Visual] = []
        func r(_ x: Double) -> Double { (x * 10_000).rounded() / 10_000 }
        func t(_ frame: Int64) -> Double { EditPlan.round6(Double(frame) * fs) }
        for shot in shots where shot.scale > 1 {
            guard let c = shot.center else { continue }
            items.append(EditPlan.Visual(span: shot.span, kind: EditPlan.Visual.punchIn, in: t(shot.sourceFrame), out: t(shot.sourceFrame + shot.frames),
                                         scale: shot.scale, center: [r(c.x), r(c.y)]))
        }

        // 4. Push-ins on wide shots with a face, long enough, at most once per interval.
        //    With beats (v2 part M9c), the shots that hold a key line come first (research 2.3: "on a model-marked key line"),
        //    then the rest by order, each still at most once per interval.
        if let push = style.pushIn {
            let to = Style.maxScale(push.to, sourceHeight: input.sourceHeight, outputHeight: input.outputHeight)
            var placed: [Double] = []
            let keyLines = input.keyLines
            func holdsKeyLine(_ shot: Shot) -> Bool {
                let (a, b) = sourceSeconds(shot)
                return keyLines.contains { $0 >= a && $0 < b }
            }
            let order = shots.indices.filter { holdsKeyLine(shots[$0]) } + shots.indices.filter { !holdsKeyLine(shots[$0]) }
            for i in order where i < shots.count - 1 && shots[i].scale == 1 && to > 1.001 {
                let shot = shots[i]
                let at = Double(shot.start) * fs
                guard Double(shot.frames) * fs >= push.seconds + 1, !inHeld(shot), placed.allSatisfy({ abs(at - $0) >= push.every }),
                      let c = framing(shot, scale: to) else { continue }
                items.append(EditPlan.Visual(span: shot.span, kind: EditPlan.Visual.pushIn, in: t(shot.sourceFrame), out: t(shot.sourceFrame + shot.frames),
                                             from: 1, to: (to * 1000).rounded() / 1000, seconds: push.seconds, center: [r(c.x), r(c.y)]))
                placed.append(at)
            }
        }

        // 5. The ending: speech ends `endingSeconds` before the last frame.
        if style.endingSeconds > 0, let lastSpan = plan.mainSpans.last(where: { s in timeline.pieces.contains { $0.id == s.id } }),
           let lastWord = plan.words.first(where: { $0.id == lastSpan.to }), let spoken = timeline.editTime(min(lastWord.out, lastSpan.out)) {
            let room = timeline.duration - spoken
            let missing = style.endingSeconds - room
            if missing > 0 {
                let frames = Int64((missing / fs).rounded(.up))
                items.append(EditPlan.Visual(span: lastSpan.id, kind: EditPlan.Visual.hold, seconds: EditPlan.round6(Double(frames) * fs)))
            }
        }
        return items.sorted { ($0.in ?? .infinity, $0.kind) < ($1.in ?? .infinity, $1.kind) }
    }

    /// The level of the rotation for every shot (0 is the whole picture), chosen together so that the most boundaries change
    /// the picture (research 2.3: never the same scale twice in a row), in the rotation's order where there is a choice, with
    /// no more than `backToWideAfter` tight shots in a row and the last shot wide. `allowed` says whether a shot can take a
    /// level (a face to frame); `keepAtCut` marks a cut where the framing should stay (Calm, a cut that does not jump).
    /// Dynamic programming over the shots, the state being the level and the tight run. Pure, for the tests.
    static func assign(count: Int, levels: Int, backToWideAfter: Int, allowed: (Int, Int) -> Bool, atCut: (Int) -> Bool,
                       keepAtCut: (Int) -> Bool) -> [Int] {
        guard count > 0 else { return [] }
        guard levels > 1 else { return Array(repeating: 0, count: count) }
        let runs = backToWideAfter + 1
        func state(_ level: Int, _ run: Int) -> Int { level * runs + run }
        let states = levels * runs
        var score = Array(repeating: Array(repeating: -Double.infinity, count: states), count: count)
        var from = Array(repeating: Array(repeating: -1, count: states), count: count)
        for level in 0..<levels where allowed(0, level) && (count > 1 || level == 0) {
            score[0][state(level, level == 0 ? 0 : 1)] = 0
        }
        for i in 1..<count {
            for previous in 0..<states where score[i - 1][previous] > -.infinity {
                let a = previous / runs, run = previous % runs
                for b in 0..<levels where allowed(i, b) && (i < count - 1 || b == 0) {
                    let nextRun = b == 0 ? 0 : run + 1
                    guard nextRun <= backToWideAfter else { continue }
                    var gain: Double
                    if atCut(i - 1) && keepAtCut(i - 1) {
                        gain = a == b ? 1 : 0
                    } else {
                        gain = a != b ? 1 : 0
                        if b == (a + 1) % levels { gain += 0.1 }
                    }
                    let total = score[i - 1][previous] + gain
                    if total > score[i][state(b, nextRun)] {
                        score[i][state(b, nextRun)] = total
                        from[i][state(b, nextRun)] = previous
                    }
                }
            }
        }
        guard var best = (0..<states).filter({ score[count - 1][$0] > -.infinity }).max(by: { score[count - 1][$0] < score[count - 1][$1] }) else {
            return Array(repeating: 0, count: count)
        }
        var out = Array(repeating: 0, count: count)
        for i in stride(from: count - 1, through: 0, by: -1) {
            out[i] = best / runs
            if i > 0 { best = from[i][best] }
        }
        return out
    }

    /// Where a punch-in at `scale` centres for these sightings: the face's middle across, the eyes on the upper third, kept
    /// inside the frame. Nil when there is no sighting, when the face would leave the framing, or when the eyes could not sit
    /// on the upper third within `eyeLineTolerance`.
    static func center(for spots: [FaceSpot], scale: Double) -> CGPoint? {
        guard !spots.isEmpty, scale > 1 else { return nil }
        let xs = spots.map(\.box.centerX).sorted(), eyes = spots.map { $0.box.y + eyeInBox * $0.box.height }.sorted()
        let cx = xs[xs.count / 2], eye = eyes[eyes.count / 2]
        // A punch-in is a still camera: a face that moves through the shot (its eyes over 6% of the frame up and down, or its
        // middle over 10% across, from the 10th to the 90th sighting) stays wide rather than drift off the upper third.
        // Measured 14 Oct on the 13 Sep plan: shots whose eyes moved 0.04 to 0.10 put the eyes 6% off the third at mid-shot.
        if eyes[eyes.count * 9 / 10] - eyes[eyes.count / 10] > eyeMovement || xs[xs.count * 9 / 10] - xs[xs.count / 10] > sideMovement { return nil }
        let size = 1 / scale
        let x = min(max(cx - size / 2, 0), 1 - size)
        let y = min(max(eye - size / 3, 0), 1 - size)
        // The eyes on the upper third after keeping the framing inside the picture.
        guard abs((eye - y) / size - 1.0 / 3.0) <= eyeLineTolerance else { return nil }
        // Every sighting's face inside the framing.
        for spot in spots {
            let b = spot.box
            if b.x < x + faceMargin || b.x + b.width > x + size - faceMargin || b.y < y + faceMargin || b.y + b.height > y + size - faceMargin {
                return nil
            }
        }
        return CGPoint(x: x + size / 2, y: y + size / 2)
    }

    /// Whether a cut between two sightings would visibly jump (Calm): the face moved 2% of the frame or more, changed size
    /// by 5% or more, or is not seen on one side.
    static func jumps(_ before: [FaceSpot], _ after: [FaceSpot]) -> Bool {
        guard let a = before.last?.box, let b = after.first?.box else { return true }
        let moved = hypot(a.centerX - b.centerX, a.centerY - b.centerY)
        let grew = abs(a.height - b.height) / max(a.height, 0.001)
        return moved >= 0.02 || grew >= 0.05
    }

    // MARK: Reading it

    /// The shots of a plan as made: every cut and every change of framing starts one; the hold belongs to the last.
    static func shots(_ plan: EditPlan, timeline: EditTimeline) -> [Shot] {
        let framing = Framing(plan: plan, timeline: timeline)
        var shots: [Shot] = []
        for (n, piece) in timeline.pieces.enumerated() {
            var cuts = Set<Int64>([piece.editFrame])
            for segment in framing.segments where segment.start > piece.editFrame && segment.start < piece.editFrame + piece.frames { cuts.insert(segment.start) }
            for segment in framing.segments where segment.end > piece.editFrame && segment.end < piece.editFrame + piece.frames { cuts.insert(segment.end) }
            let starts = cuts.sorted()
            for (k, start) in starts.enumerated() {
                let end = k + 1 < starts.count ? starts[k + 1] : piece.editFrame + piece.frames
                let segment = framing.segment(at: start)
                shots.append(Shot(span: piece.id, start: start, frames: end - start, sourceFrame: piece.sourceFrame + start - piece.editFrame,
                                  atCut: n > 0 && k == 0, scale: segment?.scale ?? 1, center: segment?.center))
            }
        }
        // A change inside a span to the same framing is no change: join it to the shot before.
        var joined: [Shot] = []
        for shot in shots {
            if let last = joined.last, !shot.atCut, last.scale == shot.scale, last.center == shot.center, last.end == shot.start {
                joined[joined.count - 1].frames += shot.frames
            } else {
                joined.append(shot)
            }
        }
        if let last = joined.indices.last { joined[last].frames += timeline.holdFrames }
        return joined
    }

    /// What a plan's picture does, counted (PLAN M9 check 3): changes a minute and in the first 30 s, the median shot,
    /// the scales, the push-ins, and how long the picture runs after the last word.
    struct Count: Equatable, Sendable {
        var minutes: Double
        /// Every visual change (research 2.3): cuts, changes of framing and, since v2 part M9d, each text coming in (one at the
        /// same moment as a cut is one change).
        var changes: Int
        var changesFirst30: Int
        var medianShot: Double
        var punchIns: Int
        var pushIns: Int
        var largestScale: Double
        var holdSeconds: Double
        var afterLastWord: Double
        /// Changes of picture alone (cuts and framing), and texts coming in, of `changes`.
        var pictureChanges = 0
        var textIns = 0
        var perMinute: Double { minutes > 0 ? Double(changes) / minutes : 0 }
    }

    static func count(_ plan: EditPlan) -> Count {
        let timeline = EditTimeline(plan: plan)
        let fs = plan.frameDuration.seconds
        let shots = shots(plan, timeline: timeline)
        // Texts coming in (v2 part M9d): each a change, unless it comes in within 0.2 s of a cut or change of framing.
        let starts = Set(shots.map(\.start))
        let near = Int64((0.2 / fs).rounded())
        let texts = plan.visual.filter(\.isText).compactMap { item -> Int64? in
            guard let a = item.in, let f = timeline.editFrame(span: item.span, original: a) else { return nil }
            return starts.contains(where: { abs($0 - f) <= near }) ? nil : f
        }
        let changes = max(0, shots.count - 1) + texts.count
        let first30 = shots.filter { $0.start > 0 && Double($0.start) * fs < 30 }.count + texts.filter { $0 > 0 && Double($0) * fs < 30 }.count
        let lengths = shots.map { Double($0.frames) * fs }.sorted()
        let pushes = plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }
        let scales = plan.visual.compactMap { $0.kind == EditPlan.Visual.punchIn ? $0.scale : $0.to }
        var after = 0.0
        if let lastSpan = plan.mainSpans.last, let word = plan.words.first(where: { $0.id == lastSpan.to }), let spoken = timeline.editTime(min(word.out, lastSpan.out)) {
            after = timeline.duration - spoken
        }
        return Count(minutes: Double(timeline.keptFrames) * fs / 60, changes: changes, changesFirst30: first30,
                     medianShot: lengths.isEmpty ? 0 : lengths[lengths.count / 2], punchIns: plan.visual.filter { $0.kind == EditPlan.Visual.punchIn }.count,
                     pushIns: pushes.count, largestScale: scales.max() ?? 1, holdSeconds: plan.holdSeconds, afterLastWord: after,
                     pictureChanges: max(0, shots.count - 1), textIns: texts.count)
    }
}

// MARK: - The framing of every frame

/// Which part of the source picture each frame of the edited video shows (v2 part M9a): read from the plan's punch-in and
/// push-in items, by the edited clock's frame. The compositor draws it for the file and the Viewer alike, and the picture
/// output check reads it to put a face found in the video back on the original's picture.
struct Framing: Equatable, Sendable {
    struct Segment: Equatable, Sendable {
        /// Edited frames it covers.
        var start: Int64
        var frames: Int64
        /// The framed part of the picture (from the top left, fractions of the frame) at the end of the ease, its scale and
        /// middle; a push-in starts from the whole picture and eases over `easeFrames`, a punch-in has none.
        var rect: CGRect
        var scale: Double
        var center: CGPoint
        var easeFrames: Int64
        var end: Int64 { start + frames }
    }

    var segments: [Segment] = []

    static let whole = CGRect(x: 0, y: 0, width: 1, height: 1)

    init(segments: [Segment] = []) {
        self.segments = segments
    }

    init(plan: EditPlan, timeline: EditTimeline) {
        let fs = plan.frameDuration.seconds
        var out: [Segment] = []
        for item in plan.visual where item.kind == EditPlan.Visual.punchIn || item.kind == EditPlan.Visual.pushIn {
            guard let piece = timeline.pieces.first(where: { $0.id == item.span }), let a = item.in, let b = item.out,
                  let c = item.center, c.count == 2 else { continue }
            let first = max(piece.sourceFrame, Int64((a / fs).rounded()))
            let last = min(piece.sourceFrame + piece.frames, Int64((b / fs).rounded()))
            guard last > first else { continue }
            let scale = item.kind == EditPlan.Visual.punchIn ? (item.scale ?? 1) : (item.to ?? 1)
            guard scale > 1 else { continue }
            let center = CGPoint(x: c[0], y: c[1])
            let ease = item.kind == EditPlan.Visual.pushIn ? Int64(((item.seconds ?? 0) / fs).rounded()) : 0
            out.append(Segment(start: piece.editFrame + first - piece.sourceFrame, frames: last - first, rect: Self.rect(scale: scale, center: center),
                               scale: scale, center: center, easeFrames: ease))
        }
        segments = out.sorted { $0.start < $1.start }
    }

    var isEmpty: Bool { segments.isEmpty }

    /// The framed part of the picture for a scale about a middle, kept inside the frame.
    static func rect(scale: Double, center: CGPoint) -> CGRect {
        let size = 1 / max(scale, 1)
        let x = min(max(center.x - size / 2, 0), 1 - size), y = min(max(center.y - size / 2, 0), 1 - size)
        return CGRect(x: x, y: y, width: size, height: size)
    }

    func segment(at frame: Int64) -> Segment? {
        var lo = 0, hi = segments.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let s = segments[mid]
            if frame < s.start { hi = mid - 1 } else if frame >= s.end { lo = mid + 1 } else { return s }
        }
        return nil
    }

    /// The framed part of the picture at an edited frame, or nil for the whole picture.
    func rect(atEditFrame frame: Int64) -> CGRect? {
        guard let s = segment(at: frame) else { return nil }
        guard s.easeFrames > 0, frame - s.start < s.easeFrames else { return s.rect }
        let t = Self.ease(Double(frame - s.start) / Double(s.easeFrames))
        let w = Self.whole
        return CGRect(x: w.minX + (s.rect.minX - w.minX) * t, y: w.minY + (s.rect.minY - w.minY) * t,
                      width: w.width + (s.rect.width - w.width) * t, height: w.height + (s.rect.height - w.height) * t)
    }

    /// The push-in's ease (research 2.6): a cubic Bezier through (0.42, 0) and (0.58, 1), an even ease in and out.
    static func ease(_ x: Double) -> Double { bezier(x, 0.42, 0, 0.58, 1) }

    /// A CSS-style cubic Bezier ease through (x1, y1) and (x2, y2): the curve's y where its x is `x` (v2 part M9b uses it for
    /// text coming in, research 2.6's (0.2, 0.8, 0.2, 1)).
    static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        let x = min(max(x, 0), 1)
        func bez(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var lo = 0.0, hi = 1.0
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            if bez(mid, x1, x2) < x { lo = mid } else { hi = mid }
        }
        return bez((lo + hi) / 2, y1, y2)
    }

    /// A box found in the edited video's frame (from its top left, fractions of the frame) on the original's picture.
    static func toSource(_ box: FaceBox, through rect: CGRect?) -> FaceBox {
        guard let r = rect else { return box }
        return FaceBox(x: r.minX + box.x * r.width, y: r.minY + box.y * r.height, width: box.width * r.width, height: box.height * r.height)
    }
}
