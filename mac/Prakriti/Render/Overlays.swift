import CoreImage
import CoreText
import SwiftUI

// Text on the edited video (v2 part M9b, docs/v2/PLAN.md M9; research-edit-engine.md 2.7 and 4.2 item 5): the title at the
// start, a lower third with a teacher's name, and the date label a moment from another recording will carry (M12b uses the
// renderer built here). Each is designed as a SwiftUI view (`OverlayView`), drawn once into a picture with `ImageRenderer`,
// kept (`OverlayCache`), then moved and faded frame by frame by the compositor (`OverlayTable`), so the file and the Viewer
// draw the same text from the same plan.
//
// The look: Alegreya Sans (`TypeFace`), white, with a soft shadow for legibility over any picture; no bar, box or panel drawn
// behind it (never skeuomorphic, research 2.7). Sizes are designed for a 1080-line picture and scaled to the video's own.
//
// The motion (research 2.7), each on the ease (0.2, 0.8, 0.2, 1) for anything coming in:
// - **Lower third:** slides 24 px toward its side and fades in over 300 ms, holds 4 s, fades out over 250 ms. The name in bold,
//   the role under it in regular at 70%.
// - **Title:** rises 16 px and fades in over 300 ms, holds, fades out over 200 ms: 2 s in all.
// - **Date label:** small, in the top corner, for the first 3 s of a moment: fades in over 300 ms and out over 200 ms.
//
// The layout is measured with Core Text (`OverlayLayout`), off the main thread, so the plan knows each text's box before
// anything is drawn: the box is what the plan checks against every face (`TextPlan`). The view draws exactly those lines in
// exactly that box.

/// The kinds of text, as the plan names them.
enum OverlayKind: String, Codable, CaseIterable, Sendable {
    case title
    case lowerThird
    case dateLabel
    /// The speaker's own words, 2 to 6, on the empty side of the frame (v2 part M9d): each word rises 16 px and fades in over
    /// 300 ms, 70 ms after the one before; held; out over 200 ms (research 2.7).
    case keyPhrase
    /// A term the talk explains, spelled from the word list (v2 part M9d): comes in like a lower third, 3 s.
    case term

    /// How far apart the words of a key phrase come in, in seconds (research 2.7).
    static let wordStagger = 0.07

    /// How the text comes in, stays and goes (research 2.7), in seconds and in pixels of a 1080-line picture.
    struct Motion: Equatable, Sendable {
        var fadeIn: Double
        var fadeOut: Double
        var total: Double
        /// Moves up into place by this much while it fades in.
        var rise: Double = 0
        /// Moves sideways toward its side by this much while it fades in.
        var slide: Double = 0
    }

    var motion: Motion {
        switch self {
        case .lowerThird: Motion(fadeIn: 0.3, fadeOut: 0.25, total: 0.3 + 4 + 0.25, slide: 24)
        case .title: Motion(fadeIn: 0.3, fadeOut: 0.2, total: 2, rise: 16)
        case .dateLabel: Motion(fadeIn: 0.3, fadeOut: 0.2, total: 3)
        case .keyPhrase: Motion(fadeIn: 0.3, fadeOut: 0.2, total: 2.5, rise: 16)
        case .term: Motion(fadeIn: 0.3, fadeOut: 0.25, total: 0.3 + 3 + 0.25, slide: 24)
        }
    }

    /// How long a key phrase of `words` words said over `spoken` seconds stays (research 2.7: the words come in one after another,
    /// then hold 1.5 to 3 s, then go): long enough to read, never longer than 3 s held.
    static func keyPhraseSeconds(words: Int, spoken: Double) -> Double {
        let coming = wordStagger * Double(max(0, words - 1)) + 0.3
        let hold = min(3, max(1.5, spoken + 0.8))
        return coming + hold + 0.2
    }

    /// How far into its life the text is shown, and how far it still has to move: alpha 0 to 1 and the offset in pixels of a
    /// 1080-line picture (x toward its side, y downward), at `t` seconds after it starts.
    func state(at t: Double, total: Double? = nil) -> (alpha: Double, dx: Double, dy: Double) {
        var m = motion
        if let total { m.total = total }
        guard t >= 0, t < m.total else { return (0, 0, 0) }
        if t < m.fadeIn {
            let e = OverlayKind.easeIn(t / m.fadeIn)
            return (e, (1 - e) * m.slide, (1 - e) * m.rise)
        }
        let left = m.total - t
        if left < m.fadeOut { return (max(0, left / m.fadeOut), 0, 0) }
        return (1, 0, 0)
    }

    /// The text-in ease (research 2.6): a cubic Bezier through (0.2, 0.8) and (0.2, 1), fast then settling.
    static func easeIn(_ x: Double) -> Double { Framing.bezier(x, 0.2, 0.8, 0.2, 1) }
}

/// One line of text as it is drawn: the words, the face, the size (pixels of a 1080-line picture) and how opaque.
struct OverlayLine: Codable, Equatable, Hashable, Sendable {
    var text: String
    var font: String
    var size: Double
    var opacity: Double = 1
}

/// A text ready to draw: its lines, laid out by `OverlayLayout`, and which side they line up on.
struct OverlayText: Equatable, Hashable, Sendable {
    enum Align: String, Codable, Sendable {
        case leading, trailing, center
    }

    var kind: OverlayKind
    var lines: [OverlayLine]
    var align: Align
    /// The video's height in pixels: sizes are scaled from 1080 lines to it.
    var height: Double

    var scale: Double { height / 1080 }
}

enum OverlayLayout {
    /// The title-safe area (from the top left, fractions of the frame): the middle 90%, as broadcast title safe. No text
    /// is placed outside it.
    static let titleSafe = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
    /// Where text is actually placed: a little inside title safe.
    static let inner = CGRect(x: 0.065, y: 0.07, width: 0.87, height: 0.86)
    /// Room kept around every text picture for its shadow, in pixels of a 1080-line picture.
    static let shadowRoom = 28.0

    // The designed sizes, for a 1080-line picture.
    static let titleLargest = 84.0
    static let titleSmallest = 56.0
    static let titleLines = 3
    static let nameSize = 54.0
    static let roleSize = 36.0
    static let dateSize = 34.0
    /// Line height as a multiple of the face's own (ascent, descent and leading), tighter for the large title.
    static let titleLeading = 0.92

    /// The lower third: the name in bold, the role under it in regular at 70%.
    static func lowerThird(name: String, role: String, height: Double) -> OverlayText {
        var lines = [OverlayLine(text: name, font: TypeFace.bold, size: nameSize)]
        if !role.isEmpty { lines.append(OverlayLine(text: role, font: TypeFace.regular, size: roleSize, opacity: 0.7)) }
        return OverlayText(kind: .lowerThird, lines: lines, align: .leading, height: height)
    }

    /// A key phrase's designed sizes, largest first (pixels of a 1080-line picture): one line, as large as fits its column.
    static let keyPhraseSizes = [64.0, 56.0, 48.0]
    static let termSize = 54.0

    /// A key phrase on one line, bold, as large as fits `maxWidth` pixels; nil when even the smallest does not.
    static func keyPhrase(_ text: String, maxWidth: Double, height: Double) -> OverlayText? {
        let scale = height / 1080
        for size in keyPhraseSizes {
            guard let font = TypeFace.font(TypeFace.bold, size: size * scale) else { return nil }
            if width(text, font: font) <= maxWidth {
                return OverlayText(kind: .keyPhrase, lines: [OverlayLine(text: text, font: TypeFace.bold, size: size)], align: .leading, height: height)
            }
        }
        return nil
    }

    /// A term card: the term alone, bold, one line.
    static func term(_ text: String, height: Double) -> OverlayText {
        OverlayText(kind: .term, lines: [OverlayLine(text: text, font: TypeFace.bold, size: termSize)], align: .leading, height: height)
    }

    /// Where each word of a one-line text ends, in pixels from the line's start: the middle of the space after it (the last at the
    /// line's end). The compositor brings a key phrase in word by word between these edges.
    static func wordEdges(_ line: OverlayLine, scale: Double) -> [Double] {
        guard let font = TypeFace.font(line.font, size: line.size * scale) else { return [] }
        let words = line.text.split(separator: " ").map(String.init)
        var edges: [Double] = []
        let space = width(" ", font: font)
        for k in words.indices {
            let prefix = words[0...k].joined(separator: " ")
            edges.append(width(prefix, font: font) + (k < words.count - 1 ? space / 2 : 0))
        }
        return edges
    }

    /// The date label on a moment from another recording (design spec C6): "6 Sep 2026".
    static func dateLabel(_ date: Date, height: Double) -> OverlayText {
        OverlayText(kind: .dateLabel, lines: [OverlayLine(text: dateText(date), font: TypeFace.medium, size: dateSize)], align: .leading, height: height)
    }

    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = .current
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// The title, as large as fits `maxWidth` pixels in at most three lines, from 84 down to 56 (in a 1080-line picture), each
    /// line broken between words. Nil when even the smallest does not fit.
    static func title(_ text: String, maxWidth: Double, height: Double) -> OverlayText? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        let scale = height / 1080
        var size = titleLargest
        while size >= titleSmallest - 1e-9 {
            if let lines = wrap(words, font: TypeFace.bold, size: size * scale, maxWidth: maxWidth), lines.count <= titleLines {
                return OverlayText(kind: .title, lines: lines.map { OverlayLine(text: $0, font: TypeFace.bold, size: size) }, align: .leading, height: height)
            }
            size -= 4
        }
        return nil
    }

    /// Words broken into lines no wider than `maxWidth` pixels, or nil when one word alone is wider.
    static func wrap(_ words: [String], font name: String, size: Double, maxWidth: Double) -> [String]? {
        guard let font = TypeFace.font(name, size: size) else { return nil }
        var lines: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : current + " " + word
            if width(candidate, font: font) <= maxWidth {
                current = candidate
            } else {
                if current.isEmpty { return nil }
                lines.append(current)
                guard width(word, font: font) <= maxWidth else { return nil }
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// A line's drawn width in pixels.
    static func width(_ text: String, font: CTFont) -> Double {
        let name = CTFontCopyPostScriptName(font) as String
        let attributed = NSAttributedString(string: TypeFace.prepared(text, font: name), attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    /// One line's height in pixels: the face's ascent, descent and leading at its size (tighter for the title).
    static func lineHeight(_ line: OverlayLine, scale: Double, kind: OverlayKind) -> Double {
        guard let font = TypeFace.font(line.font, size: line.size * scale) else { return line.size * scale * 1.2 }
        let natural = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        return (natural * (kind == .title ? titleLeading : 1)).rounded(.up)
    }

    /// The text's box in pixels: as wide as its widest line, as tall as its lines.
    static func size(_ text: OverlayText) -> CGSize {
        var w = 0.0, h = 0.0
        for line in text.lines {
            if let font = TypeFace.font(line.font, size: line.size * text.scale) { w = max(w, width(line.text, font: font)) }
            h += lineHeight(line, scale: text.scale, kind: text.kind)
        }
        return CGSize(width: w.rounded(.up), height: h.rounded(.up))
    }
}

// MARK: - Drawing

/// The text as a SwiftUI view, exactly `OverlayLayout.size` plus the shadow's room on every side.
struct OverlayView: View {
    let text: OverlayText
    let box: CGSize

    var body: some View {
        let scale = text.scale
        let room = OverlayLayout.shadowRoom * scale
        VStack(alignment: horizontal, spacing: 0) {
            ForEach(Array(text.lines.enumerated()), id: \.offset) { _, line in
                Text(TypeFace.prepared(line.text, font: line.font))
                    .font(.custom(line.font, fixedSize: line.size * scale))
                    .foregroundStyle(Color.white.opacity(line.opacity))
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: box.width, height: OverlayLayout.lineHeight(line, scale: scale, kind: text.kind), alignment: frameAlignment)
            }
        }
        .frame(width: box.width, height: box.height, alignment: .top)
        .shadow(color: .black.opacity(0.55), radius: 10 * scale, x: 0, y: 2 * scale)
        .padding(room)
        .environment(\.colorScheme, .dark)
    }

    private var horizontal: HorizontalAlignment {
        switch text.align {
        case .leading: .leading
        case .trailing: .trailing
        case .center: .center
        }
    }

    private var frameAlignment: Alignment {
        switch text.align {
        case .leading: .leading
        case .trailing: .trailing
        case .center: .center
        }
    }
}

/// Each text drawn once and kept for the app's life: the same title or name in the Viewer and in the file is one picture.
@MainActor
enum OverlayCache {
    private static var images: [OverlayText: CGImage] = [:]
    /// How many pictures were drawn (not taken from the cache), for the test that each is drawn once.
    private(set) static var drawn = 0

    /// The picture of `text`, with the shadow's room around its box, drawn with `ImageRenderer` at one pixel per point.
    static func image(_ text: OverlayText) -> CGImage? {
        if let image = images[text] { return image }
        TypeFace.register()
        let box = OverlayLayout.size(text)
        let renderer = ImageRenderer(content: OverlayView(text: text, box: box))
        renderer.scale = 1
        renderer.isOpaque = false
        renderer.colorMode = .nonLinear
        guard let image = renderer.cgImage else { return nil }
        images[text] = image
        drawn += 1
        return image
    }
}

/// Every text of a video, placed on the edited clock, as pictures ready for the compositor (shared by every instruction,
/// read by the edited frame, as `Framing` is).
final class OverlayTable: @unchecked Sendable {
    struct Placed {
        var kind: OverlayKind
        /// Edited frames it covers.
        var start: Int64
        var frames: Int64
        /// The text's box when it has settled, from the top left, in pixels of the video.
        var box: CGRect
        var align: OverlayText.Align
        var image: CIImage
        var imageSize: CGSize
        /// A key phrase's word edges in pixels from the line's start (v2 part M9d), empty for every other text.
        var wordEdges: [Double] = []
    }

    let items: [Placed]
    let renderSize: CGSize
    let frameSeconds: Double

    init(items: [Placed], renderSize: CGSize, frameSeconds: Double) {
        self.items = items.sorted { $0.start < $1.start }
        self.renderSize = renderSize
        self.frameSeconds = frameSeconds
    }

    var isEmpty: Bool { items.isEmpty }

    /// The text pictures to lay over the frame at an edited frame, already moved into place and faded, in Core Image's
    /// coordinates (origin at the bottom left).
    func layers(atEditFrame frame: Int64) -> [CIImage] {
        var out: [CIImage] = []
        let scale = renderSize.height / 1080
        for item in items where frame >= item.start && frame < item.start + item.frames {
            let t = Double(frame - item.start) * frameSeconds
            let total = Double(item.frames) * frameSeconds
            let room = OverlayLayout.shadowRoom * scale
            if item.kind == .keyPhrase, item.wordEdges.count > 1 {
                out += wordLayers(item, t: t, total: total, scale: scale, room: room)
                continue
            }
            let (alpha, dx, dy) = item.kind.state(at: t, total: total)
            guard alpha > 0.001 else { continue }
            // Toward its side: a text on the left comes in from the left, one on the right from the right.
            let sideways = (item.align == .trailing ? dx : -dx) * scale
            let x = item.box.minX - room + sideways
            let yTop = item.box.minY - room + dy * scale
            let y = renderSize.height - yTop - item.imageSize.height
            var image = item.image.transformed(by: CGAffineTransform(translationX: x, y: y))
            if alpha < 0.999 {
                image = image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
            }
            out.append(image)
        }
        return out
    }

    /// A key phrase word by word (research 2.7): word k comes in `wordStagger` x k after the first, rising 16 px and fading in over
    /// 300 ms on the text-in ease; all go out together. Each word is its own slice of the one picture, cut at the middle of the
    /// spaces, so the words are exactly the ones drawn for the whole line.
    private func wordLayers(_ item: Placed, t: Double, total: Double, scale: Double, room: Double) -> [CIImage] {
        var out: [CIImage] = []
        let m = OverlayKind.keyPhrase.motion
        let left = total - t
        let outAlpha = left < m.fadeOut ? max(0, left / m.fadeOut) : 1
        guard t >= 0, left > 0 else { return [] }
        for (k, edge) in item.wordEdges.enumerated() {
            let local = t - OverlayKind.wordStagger * Double(k)
            guard local > 0 else { continue }
            let e = local >= m.fadeIn ? 1 : OverlayKind.easeIn(local / m.fadeIn)
            let alpha = e * outAlpha
            guard alpha > 0.001 else { continue }
            // The slice of the picture this word owns, in the picture's own pixels (Core Image: origin bottom left).
            let x0 = k == 0 ? 0 : room + item.wordEdges[k - 1]
            let x1 = k == item.wordEdges.count - 1 ? item.imageSize.width : room + edge
            let slice = item.image.cropped(to: CGRect(x: x0, y: 0, width: max(0, x1 - x0), height: item.imageSize.height))
            let x = item.box.minX - room
            let yTop = item.box.minY - room + (1 - e) * m.rise * scale
            let y = renderSize.height - yTop - item.imageSize.height
            var image = slice.transformed(by: CGAffineTransform(translationX: x, y: y))
            if alpha < 0.999 {
                image = image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
            }
            out.append(image)
        }
        return out
    }

    /// Whether any text shows at an edited frame.
    func shows(atEditFrame frame: Int64) -> Bool {
        items.contains { frame >= $0.start && frame < $0.start + $0.frames }
    }

    /// The text of a plan, drawn (on the main actor, once each) and placed on its timeline. Items whose span the timeline
    /// does not keep, or whose face is missing, are left out; nil when the plan holds no text.
    static func make(plan: EditPlan, timeline: EditTimeline, renderSize: CGSize) async -> OverlayTable? {
        let texts = plan.visual.compactMap { item -> (EditPlan.Visual, OverlayText, Int64)? in
            guard OverlayKind(rawValue: item.kind) != nil, let text = item.overlayText(height: renderSize.height),
                  let start = timeline.editFrame(span: item.span, original: item.in ?? -1) else { return nil }
            return (item, text, start)
        }
        guard !texts.isEmpty else { return nil }
        let images = await MainActor.run { texts.map { OverlayCache.image($0.1) } }
        var placed: [Placed] = []
        for ((item, text, start), image) in zip(texts, images) {
            guard let image, let box = item.box, box.count == 4 else { continue }
            let frames = Int64(((item.seconds ?? text.kind.motion.total) / timeline.frame.seconds).rounded())
            let rect = CGRect(x: box[0] * renderSize.width, y: box[1] * renderSize.height, width: box[2] * renderSize.width, height: box[3] * renderSize.height)
            let edges = text.kind == .keyPhrase && text.lines.count == 1 ? OverlayLayout.wordEdges(text.lines[0], scale: text.scale) : []
            placed.append(Placed(kind: text.kind, start: start, frames: frames, box: rect, align: text.align,
                                 image: CIImage(cgImage: image), imageSize: CGSize(width: image.width, height: image.height), wordEdges: edges))
        }
        return placed.isEmpty ? nil : OverlayTable(items: placed, renderSize: renderSize, frameSeconds: timeline.frame.seconds)
    }
}

extension EditPlan.Visual {
    /// The text this item draws, laid out for a picture `height` pixels tall, or nil for a picture item.
    func overlayText(height: Double) -> OverlayText? {
        guard let kind = OverlayKind(rawValue: self.kind), let lines, !lines.isEmpty else { return nil }
        let align = OverlayText.Align(rawValue: self.align ?? "") ?? .leading
        switch kind {
        case .lowerThird:
            var text = OverlayLayout.lowerThird(name: lines[0], role: lines.count > 1 ? lines[1] : "", height: height)
            text.align = align
            return text
        case .title:
            return OverlayText(kind: .title, lines: lines.map { OverlayLine(text: $0, font: TypeFace.bold, size: size ?? OverlayLayout.titleLargest) },
                               align: align, height: height)
        case .dateLabel:
            return OverlayText(kind: .dateLabel, lines: [OverlayLine(text: lines[0], font: TypeFace.medium, size: OverlayLayout.dateSize)], align: align, height: height)
        case .keyPhrase:
            return OverlayText(kind: .keyPhrase, lines: [OverlayLine(text: lines[0], font: TypeFace.bold, size: size ?? OverlayLayout.keyPhraseSizes[0])],
                               align: align, height: height)
        case .term:
            var text = OverlayLayout.term(lines[0], height: height)
            text.align = align
            return text
        }
    }
}

extension EditTimeline {
    /// The edited frame at a moment of a span on the original's clock, by the span's own piece (so a moment at a join belongs
    /// to the span the plan names), or nil when the timeline does not keep that span.
    func editFrame(span: String, original: Double) -> Int64? {
        guard original >= 0, let piece = pieces.first(where: { $0.id == span }) else { return nil }
        let f = Int64((original / frame.seconds).rounded())
        guard f >= piece.sourceFrame, f < piece.sourceFrame + piece.frames else { return nil }
        return piece.editFrame + f - piece.sourceFrame
    }
}
