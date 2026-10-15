import CoreGraphics
import Foundation

// The visual plan, part two (v2 part M9b, docs/v2/PLAN.md M9; research-edit-engine.md 2.3 and 2.7): where the title and each
// teacher's name go on screen, written into the edit plan's `visual` items by code, after the punch-ins (`VisualPlan`), from
// the recording's title as Ivan set it, the people he named and every face the people check saw. No model is asked anything,
// and nothing here invents words: the title is Ivan's, the name is the one he gave, the role is "Teacher".
//
// The rules:
// 1. **The title** (research 2.3, "then a 2 s title"): for 2 s from the first frame, only when the recording has a title in
//    Info and the House Style shows it. Until the hook (M9d) the video opens on the talk, so the title sits over its first
//    seconds, on the empty side of the frame (the side away from the faces), as large as fits in three lines (84 down to 56
//    pixels of a 1080-line picture); with no room beside the faces, below them.
// 2. **A lower third** (research 2.3, "once per teacher, at the first on-camera moment after the hook"): once for each teacher
//    Ivan named who is Included in the video (Who Is Teaching, or a person whose role is Teacher and whose face he named),
//    at the first moment after the title where that teacher's face is seen, near the bottom of the frame on the side away
//    from their face. It shows for 4.55 s (in, 4 s, out).
// 3. **Never over a face, always inside title safe** (PLAN M9 check 4): every face the people check saw, of anyone, followed
//    through the punch-ins frame by frame (`Framing`), kept `faceRoom` away from the text's box, the box including the
//    distance it slides in; a placement that would touch one at any moment is not used, and the next moment is tried.
// 4. Text never overlaps text, and never runs into the held ending.

enum TextPlan {
    /// A teacher to name on screen: the name Ivan gave, the line under it, and where their face is (times and boxes only).
    struct Teacher: Equatable, Sendable {
        var name: String
        var role: String
        var spots: [FaceSpot]
    }

    struct Setup: Equatable, Sendable {
        /// The recording's title as Ivan set it in Info (empty: no title on screen).
        var title = ""
        var teachers: [Teacher] = []
        /// Every face the people check saw, of anyone, in time order.
        var faces: [FaceSpot] = []
        /// The picture's width in pixels (its height is `PlanStep.Setup.pictureHeight`).
        var pictureWidth: Double = 0
        var showTitle = true
        var showNames = true

        var isEmpty: Bool { (title.isEmpty || !showTitle) && (teachers.isEmpty || !showNames) }
    }

    /// How far a text's box stays from any face, as a fraction of the frame.
    static let faceRoom: CGFloat = 0.025
    /// How close a sighting must be to a moment to count as the face there, in seconds (the people check samples twice a second).
    static let near = 0.6
    /// Faces are checked this often through a text's life, in frames.
    static let checkEvery: Int64 = 6
    /// The title waits this long after it ends before a name comes in, in seconds.
    static let gapAfterTitle = 0.5
    /// A name is looked for this far into the video at most, in seconds.
    static let searchSeconds = 240.0

    /// The text items for a plan whose punch-ins are already placed. Pure: the tests drive it with made-up faces.
    static func make(plan: EditPlan, setup: Setup, pictureHeight: Double) -> [EditPlan.Visual] {
        guard !setup.isEmpty, pictureHeight > 0, setup.pictureWidth > 0 else { return [] }
        let timeline = EditTimeline(plan: plan)
        guard !timeline.pieces.isEmpty else { return [] }
        let framing = Framing(plan: plan, timeline: timeline)
        let fs = plan.frameDuration.seconds
        let size = CGSize(width: setup.pictureWidth, height: pictureHeight)
        let faces = Faces(spots: setup.faces, timeline: timeline, framing: framing)
        var items: [EditPlan.Visual] = []
        var taken: [(Int64, Int64)] = []

        func item(kind: String, start: Int64, frames: Int64, text: OverlayText, box: CGRect) -> EditPlan.Visual? {
            guard let piece = timeline.pieces.last(where: { $0.editFrame <= start }), start < piece.editFrame + piece.frames else { return nil }
            let source = piece.sourceFrame + start - piece.editFrame
            func r(_ x: Double) -> Double { (x * 10_000).rounded() / 10_000 }
            return EditPlan.Visual(span: piece.id, kind: kind, in: EditPlan.round6(Double(source) * fs), seconds: EditPlan.round6(Double(frames) * fs),
                                   lines: text.lines.map(\.text), box: [r(box.minX), r(box.minY), r(box.width), r(box.height)],
                                   align: text.align.rawValue, size: kind == EditPlan.Visual.title ? text.lines.first?.size : nil)
        }

        // 1. The title, for 2 s from the first frame.
        let title = setup.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if setup.showTitle && !title.isEmpty {
            let frames = Int64((OverlayKind.title.motion.total / fs).rounded())
            if frames <= timeline.keptFrames, let (text, box) = placeTitle(title, start: 0, frames: frames, size: size, faces: faces),
               let made = item(kind: EditPlan.Visual.title, start: 0, frames: frames, text: text, box: box) {
                items.append(made)
                taken.append((0, frames))
            }
        }

        // 2. A lower third once for each teacher, at the first moment their face is seen after the title.
        if setup.showNames {
            let frames = Int64((OverlayKind.lowerThird.motion.total / fs).rounded())
            let earliest = (taken.map(\.1).max() ?? 0) + Int64(((taken.isEmpty ? 1.0 : gapAfterTitle) / fs).rounded())
            let step = max(1, Int64((0.5 / fs).rounded()))
            var named = Set<String>()
            for teacher in setup.teachers where !named.contains(teacher.name) && !teacher.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let own = Faces(spots: teacher.spots, timeline: timeline, framing: framing)
                let text = OverlayLayout.lowerThird(name: teacher.name, role: teacher.role, height: pictureHeight)
                let last = min(timeline.keptFrames - frames, Int64((searchSeconds / fs).rounded()))
                var start = earliest
                while start <= last {
                    defer { start += step }
                    guard !taken.contains(where: { $0.0 < start + frames && $0.1 > start }), let face = own.boxes(at: start).first else { continue }
                    // The empty side: away from the teacher's face.
                    let sides: [OverlayText.Align] = face.midX < 0.5 ? [.trailing, .leading] : [.leading, .trailing]
                    var placed: (OverlayText, CGRect)?
                    for side in sides {
                        var aligned = text
                        aligned.align = side
                        if let box = lowerThirdBox(aligned, side: side, size: size), clear(box, slide: side, kind: .lowerThird, start: start, frames: frames,
                                                                                            size: size, faces: faces) {
                            placed = (aligned, box)
                            break
                        }
                    }
                    if let (aligned, box) = placed, let made = item(kind: EditPlan.Visual.lowerThird, start: start, frames: frames, text: aligned, box: box) {
                        items.append(made)
                        taken.append((start, start + frames))
                        named.insert(teacher.name)
                        break
                    }
                }
            }
        }
        return items
    }

    // MARK: Placing

    /// The title's text and box (fractions of the frame), or nil when it fits nowhere clear of the faces.
    static func placeTitle(_ title: String, start: Int64, frames: Int64, size: CGSize, faces: Faces) -> (OverlayText, CGRect)? {
        let inner = OverlayLayout.inner
        var seen: CGRect?
        var f = start
        while f < start + frames {
            for box in faces.boxes(at: f) { seen = seen.map { $0.union(box) } ?? box }
            f += checkEvery
        }
        // The columns beside the faces, wider first; with no face, the left two thirds.
        var columns: [(CGFloat, CGFloat, OverlayText.Align)] = []
        if let seen {
            let left = (inner.minX, seen.minX - faceRoom, OverlayText.Align.leading)
            let right = (seen.maxX + faceRoom, inner.maxX, OverlayText.Align.trailing)
            columns = (left.1 - left.0 >= right.1 - right.0) ? [left, right] : [right, left]
        } else {
            columns = [(inner.minX, inner.minX + inner.width * 0.66, .leading)]
        }
        for (a, b, align) in columns where b - a > 0.15 {
            guard var text = OverlayLayout.title(title, maxWidth: Double(b - a) * size.width, height: size.height) else { continue }
            text.align = align
            let px = OverlayLayout.size(text)
            let w = px.width / size.width, h = px.height / size.height
            let x = align == .leading ? a : b - w
            let y = min(max(0.5 - h / 2, inner.minY), inner.maxY - h)
            let box = CGRect(x: x, y: y, width: w, height: h)
            if inner.contains(box), clear(box, slide: nil, kind: .title, start: start, frames: frames, size: size, faces: faces) { return (text, box) }
        }
        // Below the faces, centred, when nothing fits beside them.
        if let seen {
            let top = seen.maxY + faceRoom
            if inner.maxY - top > 0.08, var text = OverlayLayout.title(title, maxWidth: Double(inner.width) * size.width, height: size.height) {
                text.align = .center
                let px = OverlayLayout.size(text)
                let w = px.width / size.width, h = px.height / size.height
                let box = CGRect(x: 0.5 - w / 2, y: inner.maxY - h, width: w, height: h)
                if box.minY >= top, inner.contains(box), clear(box, slide: nil, kind: .title, start: start, frames: frames, size: size, faces: faces) {
                    return (text, box)
                }
            }
        }
        return nil
    }

    /// A lower third's box (fractions of the frame): at the bottom of the inner area, on `side`.
    static func lowerThirdBox(_ text: OverlayText, side: OverlayText.Align, size: CGSize) -> CGRect? {
        let inner = OverlayLayout.inner
        let px = OverlayLayout.size(text)
        let w = px.width / size.width, h = px.height / size.height
        guard w < inner.width / 2, h < inner.height / 3 else { return nil }
        let x = side == .trailing ? inner.maxX - w : inner.minX
        return CGRect(x: x, y: inner.maxY - h, width: w, height: h)
    }

    /// Whether a text's box stays inside title safe and `faceRoom` away from every face through its life, the box widened by
    /// the distance it slides or rises in.
    static func clear(_ box: CGRect, slide: OverlayText.Align?, kind: OverlayKind, start: Int64, frames: Int64, size: CGSize, faces: Faces) -> Bool {
        let motion = kind.motion
        var reach = box
        let scale = size.height / 1080
        if let slide, motion.slide > 0 {
            let dx = motion.slide * scale / size.width
            reach = slide == .trailing ? CGRect(x: box.minX, y: box.minY, width: box.width + dx, height: box.height)
                                       : CGRect(x: box.minX - dx, y: box.minY, width: box.width + dx, height: box.height)
        }
        if motion.rise > 0 { reach.size.height += motion.rise * scale / size.height }
        guard OverlayLayout.titleSafe.contains(reach) else { return false }
        let guarded = reach.insetBy(dx: -faceRoom, dy: -faceRoom)
        var f = start
        while f < start + frames {
            if faces.boxes(at: f).contains(where: { $0.intersects(guarded) }) { return false }
            f += checkEvery
        }
        return !faces.boxes(at: start + frames - 1).contains { $0.intersects(guarded) }
    }

    /// Where faces are in the edited video's frames: the people check's sightings, found by the original's moment each frame
    /// shows and carried through that frame's punch-in.
    struct Faces {
        let spots: [FaceSpot]
        let timeline: EditTimeline
        let framing: Framing

        init(spots: [FaceSpot], timeline: EditTimeline, framing: Framing) {
            self.spots = spots.sorted { $0.time < $1.time }
            self.timeline = timeline
            self.framing = framing
        }

        /// Every face near the moment an edited frame shows, in that frame's own fractions (top left origin).
        func boxes(at frame: Int64) -> [CGRect] {
            guard let original = timeline.originalTime(timeline.seconds(frame)) else { return [] }
            var lo = 0, hi = spots.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if spots[mid].time < original - near { lo = mid + 1 } else { hi = mid }
            }
            let rect = framing.rect(atEditFrame: frame) ?? Framing.whole
            var out: [CGRect] = []
            var i = lo
            while i < spots.count, spots[i].time <= original + near {
                let b = spots[i].box
                out.append(CGRect(x: (b.x - rect.minX) / rect.width, y: (b.y - rect.minY) / rect.height, width: b.width / rect.width, height: b.height / rect.height))
                i += 1
            }
            return out
        }
    }
}
