import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

// The thumbnails' cut-out, finished (v2 part M13, PLAN section 11, Sonny Fri 16 Oct after looking at the 13 Sep excerpt's
// thumbnails): "a light halo rings the subject (hair, shoulders, hands)" and "unmasked background is left as a blurred smear
// along the bottom edge". Two causes, both fixed here:
//
// 1. **Vision's mask is soft.** `generateMaskedImage` keeps every pixel the mask gives any weight, so a band of the wall behind the
//    teacher comes along at partial strength, and low-weight patches away from the teacher (a chair, a shelf) come along as faint
//    smears. The mask is now made hard at half strength, only the part joined to the teacher's face is kept, it is pulled in by
//    about 1.5 pixels at 1080p and its edge softened by about 1 pixel, so nothing the mask was unsure of reaches the picture.
// 2. **The edge carried the wall's colour.** Pixels at the edge mix the teacher with the wall; on a dark ground that mix reads as a
//    light ring. The edge's colour is now taken from the teacher's own pixels just inside it (spread outward by a blur and divided
//    by its own coverage), never from the frame at the edge. And the white outline Saffron drew around the teacher, which was an
//    outer glow by another name, is gone.
//
// `measure` is the check: it reads the finished picture against the same picture with no teacher on it, and against the teacher's
// placed outline, and gives the halo (how much brighter the edge is than a clean edge would be, in 8-bit levels) and the leftover
// background (the share of the picture drawn from the frame but not joined to the teacher). Both are numbers on the files, so the
// gate can refuse a picture with a ring or a smear without anyone looking at a frame of the talk.

enum ThumbnailMatte {
    /// The share of the mask's full strength a pixel needs to be kept as the teacher.
    static let keepAt: UInt8 = 128
    /// How far the edge is pulled in, and how soft it is, in pixels of a 1080-line frame.
    static let pullIn = 1.5
    static let soften = 1.0

    /// The cut-out with a clean edge: `cut` is a cut-out (the frame's pixels where the mask is, premultiplied); `colours` the frame
    /// it came from, opaque, the same size, or nil to take the colours from the cut-out itself (the tests' drawn figure); `face` the
    /// teacher's face, top-left normalised. Nil when nothing joined to the face survives.
    static func refine(_ cut: CIImage, colours frame: CIImage?, face: FaceBox, context: CIContext) -> CIImage? {
        let extent = cut.extent.integral
        let w = Int(extent.width), h = Int(extent.height)
        guard w > 0, h > 0, let alpha = alphaBytes(cut, extent: extent, context: context) else { return nil }
        guard let kept = joinedToFace(alpha, width: w, height: h, face: face) else { return nil }
        guard let maskImage = grey(kept, width: w, height: h) else { return nil }
        let k = Double(h) / 1080
        let mask = CIImage(cgImage: maskImage).transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: extent)
        // The edge: pulled in, then softened. Morphology and blur read past the extent, so the mask is clamped first.
        let feathered = mask.clampedToExtent()
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: max(1, pullIn * k)])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(0.5, soften * k)])
            .cropped(to: extent)
        // The teacher's own pixels, well inside the edge, spread outward: the colour the edge takes.
        let core = mask.clampedToExtent()
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: max(2, (pullIn + 3) * k)])
            .cropped(to: extent)
        let source = frame ?? opaque(cut)
        let inside = source.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: core])
        // Blurred, the teacher's colours spread outward weighted by how much of the teacher each pixel saw; made opaque, each is
        // divided by that weight (CIColorMatrix works on colours with the alpha taken out), so the spread keeps the teacher's own
        // brightness all the way to the edge. Measured: dividing twice (unpremultiplying first) drew a bright line at the edge.
        let spread = opaque(inside.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(3, 8 * k)]).cropped(to: extent))
        let colour = source.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: spread, kCIInputMaskImageKey: core])
        return colour.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: feathered])
            .cropped(to: extent)
    }

    /// The image's colours with its alpha taken out and set to full: CIColorMatrix divides by the alpha before it applies the
    /// matrix, so each pixel keeps its own colour at full strength.
    static func opaque(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                                                           "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
    }

    /// The image's alpha, one byte a pixel, rows from the top.
    static func alphaBytes(_ image: CIImage, extent: CGRect, context: CIContext) -> [UInt8]? {
        let w = Int(extent.width), h = Int(extent.height)
        guard let cg = context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)),
              let rgba = rgbaBytes(cg) else { return nil }
        var out = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { out[i] = rgba[i * 4 + 3] }
        return out
    }

    /// An image's pixels as RGBA bytes, premultiplied, rows from the top.
    static func rgbaBytes(_ image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        var out = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let drawn: Bool = out.withUnsafeMutableBytes { raw in
            guard let cg = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            cg.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? out : nil
    }

    /// The pixels at or over `keepAt` that join the teacher's face (4-connected), as 0 or 255; everything else 0. The seed is the
    /// kept pixel nearest the face's middle inside the face's box; without one there, the largest part.
    static func joinedToFace(_ alpha: [UInt8], width w: Int, height h: Int, face: FaceBox) -> [UInt8]? {
        var label = [Int32](repeating: 0, count: w * h)
        var sizes: [Int] = [0]
        var queue: [Int] = []
        queue.reserveCapacity(w * h / 4)
        for start in 0..<(w * h) where alpha[start] >= keepAt && label[start] == 0 {
            let id = Int32(sizes.count)
            var count = 0
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            label[start] = id
            var head = 0
            while head < queue.count {
                let p = queue[head]; head += 1
                count += 1
                let x = p % w, y = p / w
                for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && nx < w && ny >= 0 && ny < h {
                    let q = ny * w + nx
                    if label[q] == 0 && alpha[q] >= keepAt { label[q] = id; queue.append(q) }
                }
            }
            sizes.append(count)
        }
        guard sizes.count > 1 else { return nil }
        // The part at the face: the kept pixel nearest the face's middle, inside its box.
        let cx = face.centerX * Double(w), cy = face.centerY * Double(h)
        let x0 = max(0, Int(face.x * Double(w))), x1 = min(w - 1, Int((face.x + face.width) * Double(w)))
        let y0 = max(0, Int(face.y * Double(h))), y1 = min(h - 1, Int((face.y + face.height) * Double(h)))
        var chosen: Int32 = 0, best = Double.infinity
        if x0 <= x1, y0 <= y1 {
            for y in y0...y1 {
                for x in x0...x1 where label[y * w + x] != 0 {
                    let d = (Double(x) - cx) * (Double(x) - cx) + (Double(y) - cy) * (Double(y) - cy)
                    if d < best { best = d; chosen = label[y * w + x] }
                }
            }
        }
        if chosen == 0, let largest = sizes.indices.dropFirst().max(by: { sizes[$0] < sizes[$1] }) { chosen = Int32(largest) }
        return label.map { $0 == chosen ? 255 : 0 }
    }

    /// One byte a pixel as a grey image, rows from the top.
    static func grey(_ bytes: [UInt8], width w: Int, height h: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    // MARK: The check

    struct Edge: Codable, Equatable, Sendable {
        /// How much brighter than a clean edge the teacher's edge is, on average, in 8-bit levels of luma: just outside the outline
        /// (where nothing but the ground should be) and in the soft edge itself (against the teacher's own pixels just inside, mixed
        /// with the ground by the edge's own strength). The larger of the two.
        var halo: Double
        /// The share of the picture, in percent, drawn from the frame but not joined to the teacher (more than 8 pixels from the
        /// teacher's outline).
        var leftover: Double
    }

    /// The most a clean edge may be brighter than it should be, in 8-bit levels, and the most of the picture that may be leftover
    /// background, in percent. Set from the measurements of v2 part M13 (BUILD-LOG): the old edge measured far over both.
    static let mostHalo = 6.0
    static let mostLeftover = 0.05

    /// Measures the edge on a finished picture (before the words): `picture` the composite, `ground` the same with no teacher,
    /// `matte` the teacher's placed outline (its alpha), all the canvas's size; `face` the teacher's face on the canvas, top-left.
    static func measure(picture: CGImage, ground: CGImage, matte: CGImage, face: FaceBox) -> Edge? {
        let w = picture.width, h = picture.height
        guard ground.width == w, ground.height == h, matte.width == w, matte.height == h,
              let c = rgbaBytes(picture), let g = rgbaBytes(ground), let m = rgbaBytes(matte) else { return nil }
        let n = w * h
        let linear: [Float] = (0..<256).map { v in
            let x = Float(v) / 255
            return x <= 0.04045 ? x / 12.92 : powf((x + 0.055) / 1.055, 2.4)
        }
        var lc = [Float](repeating: 0, count: n), lg = [Float](repeating: 0, count: n), a = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let o = i * 4
            // Luma in linear light: the picture's edge is mixed in linear light, so the clean edge it is held against must be too.
            lc[i] = 0.2126 * linear[Int(c[o])] + 0.7152 * linear[Int(c[o + 1])] + 0.0722 * linear[Int(c[o + 2])]
            lg[i] = 0.2126 * linear[Int(g[o])] + 0.7152 * linear[Int(g[o + 1])] + 0.0722 * linear[Int(g[o + 2])]
            a[i] = Float(m[o + 3]) / 255
        }
        let half = a.map { $0 >= 0.5 ? UInt8(255) : 0 }
        let main = joinedToFace(half, width: w, height: h, face: face) ?? half
        let core = a.map { $0 >= 0.95 ? Float(1) : 0 }
        let coreLuma = zip(lc, core).map { $0 * $1 }
        let r = max(3, Int((6.0 * Double(h) / 1080).rounded()))
        let near = boxSum(main.map { $0 > 0 ? Float(1) : 0 }, w, h, r)
        let nearMain8 = boxSum(main.map { $0 > 0 ? Float(1) : 0 }, w, h, max(4, Int((8.0 * Double(h) / 1080).rounded())))
        let coreCount = boxSum(core, w, h, r), coreSum = boxSum(coreLuma, w, h, r)
        var ringExcess = 0.0, ringN = 0, bandExcess = 0.0, bandN = 0, leftover = 0
        for i in 0..<n {
            let alpha = a[i]
            if alpha < 0.05 {
                if near[i] > 0 { ringExcess += max(0, levels(lc[i]) - levels(lg[i])); ringN += 1 }
            } else if alpha < 0.95, coreCount[i] > 0 {
                let inner = coreSum[i] / coreCount[i]
                let expected = alpha * inner + (1 - alpha) * lg[i]
                bandExcess += max(0, levels(lc[i]) - levels(expected)); bandN += 1
            }
            if alpha > 0.02, nearMain8[i] == 0 { leftover += 1 }
        }
        let halo = max(ringN == 0 ? 0 : ringExcess / Double(ringN), bandN == 0 ? 0 : bandExcess / Double(bandN))
        return Edge(halo: halo, leftover: 100 * Double(leftover) / Double(n))
    }

    /// Linear light back to 8-bit sRGB levels, the unit the halo is given in.
    static func levels(_ linear: Float) -> Double {
        let x = Double(max(0, min(1, linear)))
        return 255 * (x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055)
    }

    /// The sum of each pixel's square of side 2r+1 (an integral image), clipped at the edges.
    static func boxSum(_ v: [Float], _ w: Int, _ h: Int, _ r: Int) -> [Float] {
        var integral = [Double](repeating: 0, count: (w + 1) * (h + 1))
        for y in 0..<h {
            var row = 0.0
            for x in 0..<w {
                row += Double(v[y * w + x])
                integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row
            }
        }
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            let ya = max(0, y - r), yb = min(h, y + r + 1)
            for x in 0..<w {
                let xa = max(0, x - r), xb = min(w, x + r + 1)
                let s = integral[yb * (w + 1) + xb] - integral[ya * (w + 1) + xb] - integral[yb * (w + 1) + xa] + integral[ya * (w + 1) + xa]
                out[y * w + x] = Float(s)
            }
        }
        return out
    }
}
