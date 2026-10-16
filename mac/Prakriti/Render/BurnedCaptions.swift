import CoreGraphics
import CoreImage
import CoreText
import Foundation

// The calm captions burned into every short (v2 part M11a, docs/v2/PLAN.md M11; research-edit-engine.md 2.7 and 6.3): one line
// of 2 to 5 words a page, changing at the end of a phrase, the word being said full white and the rest at 70%, a cap height of
// about 64 px on the 1080 by 1920 frame, a soft shadow and no box, in Alegreya Sans (never SF Pro in a video, Mac warning 168).
//
// Where they sit: platforms publish no binding safe areas, so research 6.3 takes the strictest union of the third-party guides:
// keep clear the top 250 px, the bottom 350, the right 120 (TikTok's buttons) and the left 60. Text lives in x 60 to 960, y 250
// to 1570, and captions sit with their baseline near y 1330, centred on x 510 (the safe area's middle, a little left of the
// frame's). Every page's box is measured by Core Text when the pages are made and checked against that rectangle
// (`problems`); a page that does not fit on one line is split, and a single word too wide for the line is set smaller, down to a
// 44 px cap height. The same box is what is drawn: the picture of each page is made from exactly that line.
//
// The pictures are drawn by Core Graphics and Core Text before the short is drawn (`Table.make`), one per page and word, and the
// compositor only lays the right one over each frame, as it does the video's text (Mac warning 165): no drawing on
// AVFoundation's threads.

enum BurnedCaptions {
    /// The short's frame.
    static let frame = CGSize(width: 1080, height: 1920)
    /// Research 6.3's safe rectangle, from the top left, in pixels of the 1080 by 1920 frame.
    static let safe = CGRect(x: 60, y: 250, width: 900, height: 1320)
    /// The middle of a caption line, and its baseline, from the top left.
    static let centerX: CGFloat = 510
    static let baseline: CGFloat = 1330
    /// Research 2.7: a cap height of about 64 px; never smaller than 44.
    static let capHeight: CGFloat = 64
    static let smallestCap: CGFloat = 44
    /// 2 to 5 words a page.
    static let mostWords = 5
    static let fewestWords = 2
    /// A pause this long between two words starts a new page.
    static let pauseBreak = 0.4
    /// How long a page may stay after its last word when nothing follows at once.
    static let linger = 0.6
    /// The words not being said, against the one being said (research 2.7: 70%).
    static let restAlpha: CGFloat = 0.7
    /// The soft shadow: no box behind the words (research 2.7).
    static let shadowBlur: CGFloat = 14
    static let shadowAlpha: CGFloat = 0.65
    /// Room around the line in each picture for the shadow.
    static let margin: CGFloat = 28
    static let fontName = TypeFace.bold
    /// The widest a line is set: the safe area less 30 px each side, so the soft shadow and the letters' own overhang stay inside
    /// it too (measured 16 Oct: Vision's box for a line set to the full 900 px reached 8 px past the safe area's right edge).
    static let lineWidth: CGFloat = safe.width - 60

    /// One page: its words on the short's clock, when it shows, its line and the box the line takes, from the top left.
    struct Page: Equatable, Sendable {
        var words: [String]
        /// When each word starts, on the short's clock.
        var starts: [Double]
        var start: Double
        var end: Double
        var fontSize: CGFloat
        var box: CGRect
        var text: String { words.joined(separator: " ") }
    }

    /// The font size whose capitals are `cap` pixels tall.
    static func fontSize(cap: CGFloat) -> CGFloat {
        guard let font = TypeFace.font(fontName, size: 100) else { return cap / 0.66 }
        let ratio = CTFontGetCapHeight(font) / 100
        return cap / max(0.3, ratio)
    }

    /// The width of a line of words at a size, and its ascent and descent, measured by Core Text.
    static func measure(_ text: String, size: CGFloat) -> (width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        guard let font = TypeFace.font(fontName, size: size) else { return (CGFloat(text.count) * size * 0.5, size * 0.75, size * 0.25) }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: TypeFace.prepared(text, font: fontName),
                                                                       attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        return (width, ascent, descent)
    }

    /// The box a line takes, centred on `centerX` with its baseline on `baseline`.
    static func box(_ text: String, size: CGFloat) -> CGRect {
        let m = measure(text, size: size)
        return CGRect(x: centerX - m.width / 2, y: baseline - m.ascent, width: m.width, height: m.ascent + m.descent)
    }

    /// The pages for the short's words, `duration` being the short's length. Pure apart from Core Text's measuring.
    static func pages(_ words: [Captions.Word], duration: Double) -> [Page] {
        let standard = fontSize(cap: capHeight)
        var groups: [[Captions.Word]] = []
        var current: [Captions.Word] = []
        func fits(_ ws: [Captions.Word]) -> Bool {
            box(ws.map(\.text).joined(separator: " "), size: standard).width <= lineWidth
        }
        for word in words {
            if let last = current.last {
                let phraseDone = (last.endsSentence || last.endsClause) && current.count >= fewestWords
                let paused = word.start - last.end >= pauseBreak && current.count >= 1
                let full = current.count >= mostWords
                if phraseDone || paused || full || !fits(current + [word]) {
                    groups.append(current)
                    current = []
                }
            }
            current.append(word)
        }
        if !current.isEmpty { groups.append(current) }
        // A page of one word joins the page after it when the two still make one line of at most five words (2 to 5 a page),
        // unless the word ends a sentence or a long pause follows it.
        var joined: [[Captions.Word]] = []
        var i = 0
        while i < groups.count {
            var group = groups[i]
            if group.count == 1, i + 1 < groups.count, !(group[0].endsSentence), groups[i + 1].first.map({ $0.start - group[0].end < pauseBreak }) == true,
               group.count + groups[i + 1].count <= mostWords, fits(group + groups[i + 1]) {
                group += groups[i + 1]
                i += 1
            }
            joined.append(group)
            i += 1
        }
        var out: [Page] = []
        for (n, group) in joined.enumerated() {
            guard let first = group.first, let last = group.last else { continue }
            let text = group.map(\.text).joined(separator: " ")
            var size = standard
            // A single word too wide for the line (a long compound) is set smaller, never cut.
            let smallest = fontSize(cap: smallestCap)
            while box(text, size: size).width > lineWidth && size > smallest { size -= 2 }
            let next = n + 1 < joined.count ? joined[n + 1].first?.start : nil
            let end = min(next ?? .infinity, max(last.end + linger, first.start + 0.5), duration)
            out.append(Page(words: group.map(\.text), starts: group.map(\.start), start: first.start, end: max(first.start + 0.1, end),
                            fontSize: size, box: box(text, size: size)))
        }
        return out
    }

    /// Every page whose box is not inside `safe`, in words. Empty when every caption is inside the safe area.
    static func problems(_ pages: [Page], safe: CGRect = BurnedCaptions.safe) -> [String] {
        pages.compactMap { page in
            safe.contains(page.box.integral.insetBy(dx: 0.5, dy: 0.5)) ? nil
                : String(format: "The caption \u{201C}%@\u{201D} at %.1f s sits outside the safe area (x %.0f to %.0f, y %.0f to %.0f).",
                         page.text, page.start, page.box.minX, page.box.maxX, page.box.minY, page.box.maxY)
        }
    }

    /// The picture of one page with word `highlighted` said (full white) and the others at 70%, placed on the 1080 by 1920 frame
    /// in Core Image's coordinates (origin at the bottom left).
    static func image(_ page: Page, highlighted: Int?, frameHeight: CGFloat = BurnedCaptions.frame.height) -> CIImage? {
        guard let font = TypeFace.font(fontName, size: page.fontSize) else { return nil }
        let text = NSMutableAttributedString()
        for (k, word) in page.words.enumerated() {
            let alpha = highlighted == k ? 1 : restAlpha
            let piece = (k == 0 ? "" : " ") + TypeFace.prepared(word, font: fontName)
            text.append(NSAttributedString(string: piece, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: alpha),
            ]))
        }
        let line = CTLineCreateWithAttributedString(text)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let w = Int((width + 2 * margin).rounded(.up)), h = Int((ascent + descent + 2 * margin).rounded(.up))
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: shadowBlur, color: CGColor(red: 0, green: 0, blue: 0, alpha: shadowAlpha))
        context.textPosition = CGPoint(x: margin, y: margin + descent)
        CTLineDraw(line, context)
        guard let picture = context.makeImage() else { return nil }
        // The line's box on the frame, from the top left: its left edge and its top.
        let x = page.box.minX - margin, top = page.box.minY - margin
        return CIImage(cgImage: picture).transformed(by: CGAffineTransform(translationX: x, y: frameHeight - top - CGFloat(h)))
    }

    /// The pictures of every page on the short's frames, for the compositor: one entry per word said, from its first frame to
    /// the next word's (or the page's end).
    final class Table: @unchecked Sendable {
        struct Entry {
            var first: Int64
            var end: Int64
            var image: CIImage
        }

        let entries: [Entry]

        init(entries: [Entry]) { self.entries = entries.sorted { $0.first < $1.first } }

        /// Draws every page once, before anything is rendered. `frame` is one frame of the short.
        static func make(_ pages: [Page], frame: FrameDuration) -> Table {
            let fs = frame.seconds
            var entries: [Entry] = []
            for page in pages {
                for (k, start) in page.starts.enumerated() {
                    let from = k == 0 ? page.start : start
                    let to = k + 1 < page.starts.count ? page.starts[k + 1] : page.end
                    let a = Int64((from / fs).rounded()), b = Int64((to / fs).rounded())
                    guard b > a, let image = BurnedCaptions.image(page, highlighted: k) else { continue }
                    entries.append(Entry(first: a, end: b, image: image))
                }
            }
            return Table(entries: entries)
        }

        /// The caption picture over an edited frame, or none.
        func layer(atEditFrame frame: Int64) -> CIImage? {
            var lo = 0, hi = entries.count - 1
            while lo <= hi {
                let mid = (lo + hi) / 2
                let e = entries[mid]
                if frame < e.first { hi = mid - 1 } else if frame >= e.end { lo = mid + 1 } else { return e.image }
            }
            return nil
        }

        var count: Int { entries.count }
    }
}
