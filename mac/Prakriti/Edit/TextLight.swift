import AVFoundation
import CoreGraphics
import Foundation

// White text needs a darker picture behind it (v2 part M9d). The text is white with a soft shadow and no box (research 2.7, never
// skeuomorphic), so over a bright wall or floor it can hardly be read. Measured 15 Oct on the 13 Sep talk: a term card placed over
// the floor at 13:23 sat on a picture 247 of 255 bright, and its type barely changed the frame. So once the text is placed, the
// original's picture under each text's box (through that frame's punch-in) is looked at, small, at the start, middle and end of
// its life; a text over a picture brighter than `brightest` is placed again with that stretch of picture treated like a face (kept
// clear), so it moves to the other side, waits, or is left out. Nothing is stored: the frames are 192 pixels wide and read once.

enum TextLight {
    /// The mean brightness (0 to 255) above which white text is placed elsewhere.
    static let brightest = 170.0
    /// How many times the text is placed again at most.
    static let rounds = 2

    /// The texts placed over a picture brighter than `brightest`, each with where that picture is on the original (fractions
    /// from the top left) and the original's moments it covers.
    static func bright(_ items: [EditPlan.Visual], plan: EditPlan, original: URL) async -> [(item: EditPlan.Visual, box: FaceBox, times: [Double])] {
        let timeline = EditTimeline(plan: plan)
        let framing = Framing(plan: plan, timeline: timeline)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: original))
        generator.maximumSize = CGSize(width: 192, height: 108)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
        generator.appliesPreferredTrackTransform = true
        var out: [(EditPlan.Visual, FaceBox, [Double])] = []
        for item in items where item.isText {
            guard let a = item.in, let start = timeline.editFrame(span: item.span, original: a), let b = item.box, b.count == 4 else { continue }
            let frames = Int64(((item.seconds ?? 0) / timeline.frame.seconds).rounded())
            var means: [Double] = [], sourceBox: FaceBox?, times: [Double] = []
            for share in [0.2, 0.5, 0.8] {
                let f = start + Int64(Double(frames) * share)
                guard let t = timeline.originalTime(timeline.seconds(f)) else { continue }
                let box = Framing.toSource(FaceBox(x: b[0], y: b[1], width: b[2], height: b[3]), through: framing.rect(atEditFrame: f))
                sourceBox = sourceBox.map { FaceBox(x: min($0.x, box.x), y: min($0.y, box.y), width: max($0.x + $0.width, box.x + box.width) - min($0.x, box.x),
                                                     height: max($0.y + $0.height, box.y + box.height) - min($0.y, box.y)) } ?? box
                guard let image = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 30000)).image else { continue }
                means.append(mean(image, in: box))
            }
            var t = 0.0
            while t <= Double(frames) * timeline.frame.seconds {
                if let o = timeline.originalTime(timeline.seconds(start) + t) { times.append(o) }
                t += 0.5
            }
            if let worst = means.max(), worst > brightest, let sourceBox { out.append((item, sourceBox, times)) }
        }
        return out
    }

    /// The mean brightness of `image` inside `box` (fractions from the top left).
    static func mean(_ image: CGImage, in box: FaceBox) -> Double {
        let w = image.width, h = image.height
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        var sum = 0.0, n = 0
        let x0 = max(0, Int(box.x * Double(w))), x1 = min(w, Int((box.x + box.width) * Double(w)) + 1)
        let y0 = max(0, Int(box.y * Double(h))), y1 = min(h, Int((box.y + box.height) * Double(h)) + 1)
        for y in y0..<max(y0, y1) {
            for x in x0..<max(x0, x1) {
                let i = (y * w + x) * 4
                sum += (Double(data[i]) + Double(data[i + 1]) + Double(data[i + 2])) / 3
                n += 1
            }
        }
        return n == 0 ? 0 : sum / Double(n)
    }
}
