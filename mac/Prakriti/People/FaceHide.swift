@preconcurrency import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import Foundation
import Vision

// Hiding in pictures (v2 part M6d, docs/v2/PLAN.md M6, research-people.md 3.2 and 3.5): the faces of the people Ivan
// chose to hide (Hide Face or Leave Out) taken out of a frame. Used for the card picture (`CardPicture`) and, from part
// M8d, for every frame of the edited video (`Compositor`, with the regions `VideoHiding` follows in order).
//
// Three pieces, each measured or tested on its own:
//
// - `HidePlan`: which tracks of the people file are hidden, and where each was seen. Pure: built from the people file
//   and a rule per row, so the tests drive it with made-up boxes.
// - `FaceFollower`: where each hidden face is in the exact frame asked for. The face step looks twice a second, and a
//   face moves between its looks, so between them each hidden face is followed at the full frame rate by Vision's
//   `TrackObjectRequest`, started again from every sighting (research-people.md 1.1: 3.3 ms per face per frame). A
//   region is also held 0.5 s before a face is first seen and after it is last seen, and kept at both of the sightings
//   around the frame when they are within 0.5 s, so a face turning into view is never shown for a frame. When the
//   follower loses a face between sightings, the last place it was seen stays hidden, and so does the head of any body
//   Vision finds there (unknown means hidden).
// - `FaceHide`: the Core Image function. Each region padded to 1.6 times the face, as a soft-edged ellipse, then a
//   heavy blur (a radius of half the face's width, more than the quarter research-people.md 3.2 asks), pixelated into
//   blocks about a quarter of the face wide (under the 8 across that research allows), and the blocks softened by a last
//   blur of one block, so no block pattern is left for a detector to read as eyes (part M8d, measured: `soften`). Where a
//   hidden region covers part of an included face, the region wins: it is drawn over the whole frame, never around
//   anyone (research-people.md 3.5).
//
// Nothing here keeps a picture, a print or a landmark: frames are read, used and dropped. Files under `People/` never
// reach the network (`RulesTests`).

/// One hidden face, as the people file saw it: every sighting, two a second, boxes from the top left.
struct HiddenTrack: Equatable, Sendable {
    struct Spot: Equatable, Sendable {
        var time: Double
        var box: FaceBox
    }

    var id: Int
    var spots: [Spot]

    var start: Double { spots.first?.time ?? 0 }
    var end: Double { spots.last?.time ?? 0 }

    /// The last sighting at or before `time`, and the first after it.
    func around(_ time: Double) -> (before: Spot?, after: Spot?) {
        let index = spots.firstIndex { $0.time > time + 0.0001 }
        let before = index.map { $0 > 0 ? spots[$0 - 1] : nil } ?? spots.last
        return (before, index.map { spots[$0] })
    }
}

/// Which faces a picture hides: the tracks of the people file whose person Ivan chose to hide.
struct HidePlan: Equatable, Sendable {
    var tracks: [HiddenTrack] = []

    /// How long a region is held before a face is first seen and after it is last seen, and how near a sighting must be
    /// to a frame for its place to be hidden too (research-people.md 3.2).
    static let hold = 0.5

    var isEmpty: Bool { tracks.isEmpty }

    /// The hidden tracks of a people file: `hides` is asked about each track's People tab row (nil for a face seen in
    /// one sample only, the glimpses).
    static func from(_ file: PeopleFile, hides: (Int?) -> Bool) -> HidePlan {
        HidePlan(tracks: file.tracks.filter { hides($0.person) }.map { track in
            HiddenTrack(id: track.id, spots: track.boxes.compactMap { box in
                box.count >= 5 ? HiddenTrack.Spot(time: box[0], box: FaceBox(x: box[1], y: box[2], width: box[3], height: box[4])) : nil
            }.sorted { $0.time < $1.time })
        }.filter { !$0.spots.isEmpty })
    }

    /// The hidden tracks that may be on screen at `time`: from `hold` before their first sighting to `hold` after their last.
    func active(at time: Double) -> [HiddenTrack] {
        tracks.filter { time >= $0.start - Self.hold - 0.0001 && time <= $0.end + Self.hold + 0.0001 }
    }

    /// The regions held at `time` without following anyone: each sighting within `hold` of it, before and after.
    func held(at time: Double) -> [FaceBox] {
        active(at: time).flatMap { track -> [FaceBox] in
            let (before, after) = track.around(time)
            var boxes: [FaceBox] = []
            if let before, time - before.time <= Self.hold + 0.0001 { boxes.append(before.box) }
            if let after, after.time - time <= Self.hold + 0.0001 { boxes.append(after.box) }
            return boxes
        }
    }
}

/// The regions to hide in one frame.
struct HiddenFrame: Equatable, Sendable {
    /// The time asked for.
    var time: Double
    /// The time of the frame read (the one on screen at `time`), or `time` when nothing was read.
    var frameTime: Double
    var regions: [FaceBox]
    /// How each region was found, for the log and the tests: "held", "followed", "lost", "body".
    var how: [String]
}

/// Follows the hidden faces at the full frame rate between the face step's sightings (research-people.md 3.2).
enum FaceFollower {
    /// Below this, Vision's follower has lost the face.
    static let lostConfidence: Float = 0.3
    /// The tallest frame the follower is given (as the face step: boxes are fractions of the picture).
    static let analysisHeight = FaceScan.analysisHeight

    /// The regions to hide in the frame on screen at each of `times`, for `plan`, reading `file`. Each time is read on its
    /// own from the sighting before it, so the times may be far apart.
    static func frames(file: URL, plan: HidePlan, at times: [Double]) async throws -> [HiddenFrame] {
        var out: [HiddenFrame] = []
        for time in times { out.append(try await frame(file: file, plan: plan, at: time)) }
        return out
    }

    static func frame(file: URL, plan: HidePlan, at time: Double) async throws -> HiddenFrame {
        let active = plan.active(at: time)
        var result = HiddenFrame(time: time, frameTime: time, regions: [], how: [])
        guard !active.isEmpty else { return result }
        for box in plan.held(at: time) {
            result.regions.append(box)
            result.how.append("held")
        }
        // The tracks the follower must follow: those whose last sighting is before the frame (a frame at a sighting needs
        // no following: the held box is that sighting's).
        let follow = active.compactMap { track -> (HiddenTrack, HiddenTrack.Spot)? in
            guard let before = track.around(time).before, before.time < time - 0.001 else { return nil }
            return (track, before)
        }
        guard !follow.isEmpty, let from = follow.map(\.1.time).min() else { return result }

        let asset = AVURLAsset(url: file)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { return result }
        let size = try await videoTrack.load(.naturalSize)
        let height = abs(size.height)
        let scale = height > CGFloat(analysisHeight) ? CGFloat(analysisHeight) / height : 1
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, from - 0.02), preferredTimescale: 600),
                                       end: CMTime(seconds: time + 0.2, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        // `outputProvider(for:)` adds the output itself; `reader.add(output)` first would crash (research-people.md 1.7).
        let provider = reader.outputProvider(for: output)
        try reader.start()

        struct Following {
            var track: HiddenTrack
            var request: TrackObjectRequest?
            var box: FaceBox
            var lost = false
            var seeded = -1.0
        }
        var following = follow.map { Following(track: $0.0, request: nil, box: $0.1.box) }
        var lastImage: CIImage?
        var lastTime = -1.0
        while let buffer = try await provider.next() {
            let frameTime = buffer.presentationTimeStamp.seconds
            guard frameTime.isFinite else { continue }
            if frameTime > time + 0.0005 { break }
            let image: CIImage? = buffer.withUnsafeSampleBuffer { sample in
                guard let pixels = CMSampleBufferGetImageBuffer(sample) else { return nil }
                let image = CIImage(cvPixelBuffer: pixels)
                return scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
            }
            guard let image else { continue }
            for index in following.indices {
                let track = following[index].track
                if let spot = track.spots.last(where: { abs($0.time - frameTime) < 0.012 }) {
                    // A sighting on this very frame: start again from it.
                    following[index].request = TrackObjectRequest(detectedObject: DetectedObjectObservation(boundingBox: NormalizedRect(normalizedRect: FaceGeometry.toVision(spot.box))))
                    following[index].box = spot.box
                    following[index].lost = false
                    following[index].seeded = frameTime
                } else if let request = following[index].request, !following[index].lost {
                    if let seen = try? await request.perform(on: image), seen.confidence >= lostConfidence {
                        following[index].box = FaceGeometry.fromVision(seen.boundingBox.cgRect)
                    } else {
                        following[index].lost = true
                    }
                } else if following[index].request == nil, frameTime >= (track.around(time).before?.time ?? 0) - 0.012 {
                    // The reader starts a little before the first sighting needed; start from it as soon as it is reached.
                    following[index].request = TrackObjectRequest(detectedObject: DetectedObjectObservation(boundingBox: NormalizedRect(normalizedRect: FaceGeometry.toVision(following[index].box))))
                    following[index].seeded = frameTime
                }
            }
            lastImage = image
            lastTime = frameTime
        }
        if lastTime >= 0 { result.frameTime = lastTime }
        for item in following {
            result.regions.append(item.box)
            result.how.append(item.lost ? "lost" : "followed")
            if item.lost, let image = lastImage {
                // Lost between two sightings: the last place stays hidden (above), and so does the head of any body in
                // that place (research-people.md 3.2, "when a face is lost").
                for head in try await heads(in: image, near: item.box) {
                    result.regions.append(head)
                    result.how.append("body")
                }
            }
        }
        return result
    }

    /// The head regions of the bodies Vision finds near `box`: the top of each body box, as wide as the body and at most
    /// as tall as it is wide.
    static func heads(in image: CIImage, near box: FaceBox) async throws -> [FaceBox] {
        let bodies = try await DetectHumanRectanglesRequest().perform(on: image)
        return bodies.map { FaceGeometry.fromVision($0.boundingBox.cgRect) }.compactMap { body in
            let reach = max(box.width, box.height) * 2
            guard abs(body.centerX - box.centerX) <= max(reach, body.width / 2), body.y <= box.y + box.height else { return nil }
            return FaceBox(x: body.x, y: body.y, width: body.width, height: min(body.height, body.width * 0.9))
        }
    }
}

/// The Core Image function that hides regions of a frame (research-people.md 3.2).
enum FaceHide {
    /// Each region is padded to this times the face's box (Vision's revision 4 boxes are tight: hair, ears and the jaw
    /// fall outside them, research-people.md 1.7).
    static let pad = 1.6
    /// The ellipse is solid to this share of its radius, then fades to its edge.
    static let solid = 0.9
    /// The blur's radius, as a share of the face's width (research-people.md 3.2: at least a quarter). Half, since part M8d.
    static let blurShare = 0.5
    /// Blocks across the padded region (research-people.md 3.2: no more than 8 across the face; this is about 4 across it).
    static let blocksAcross = 6.0
    /// After the blocks, a last blur of this many blocks softens their edges into one blob (part M8d).
    ///
    /// Load-bearing, with the two numbers above: measured 14 Oct on two-people-mixed's corner face (about 70 by 70 pixels),
    /// 201 frames five a second, Vision still found a "face" inside the hidden region in 5 frames with M6d's quarter-width
    /// blur and 8 blocks (confidence 0.11 to 0.25), in 3 with a half-width blur and 6 blocks, and in none once the blocks are
    /// softened by one block's blur. The video's picture output check fails on any of them, so a weaker hiding stops the
    /// video rather than leaking it, but it must not be weakened.
    static let soften = 1.0

    /// The padded ellipse of a region in the picture's pixels, with y from the BOTTOM (Core Image's way round).
    static func ellipse(_ box: FaceBox, width: Double, height: Double) -> (center: CGPoint, radiusX: Double, radiusY: Double) {
        let center = CGPoint(x: box.centerX * width, y: (1 - box.centerY) * height)
        return (center, box.width * width * pad / 2, box.height * height * pad / 2)
    }

    /// Whether a point of the picture (0 to 1 from the top left) lies inside a region's solid ellipse.
    static func covers(_ box: FaceBox, x: Double, y: Double) -> Bool {
        let rx = box.width * pad / 2 * solid, ry = box.height * pad / 2 * solid
        guard rx > 0, ry > 0 else { return false }
        let dx = (x - box.centerX) / rx, dy = (y - box.centerY) / ry
        return dx * dx + dy * dy <= 1
    }

    /// `image` with every region hidden. Regions are fractions of the picture from the top left; the image's extent
    /// gives the pixels.
    static func apply(_ image: CIImage, regions: [FaceBox]) -> CIImage {
        let extent = image.extent
        guard !regions.isEmpty, extent.width > 0, extent.height > 0, extent.width.isFinite else { return image }
        var result = image
        for box in regions where box.width > 0 && box.height > 0 {
            let (center, rx, ry) = ellipse(box, width: extent.width, height: extent.height)
            let shifted = CGPoint(x: center.x + extent.minX, y: center.y + extent.minY)
            let faceWidth = box.width * extent.width
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = image.clampedToExtent()
            blur.radius = Float(max(4, faceWidth * blurShare))
            let pixels = CIFilter.pixellate()
            pixels.inputImage = blur.outputImage
            pixels.center = shifted
            pixels.scale = Float(max(2, rx * 2 / blocksAcross))
            // Only the ellipse's own rectangle is drawn hidden (outside it the mask is 0), so Core Image blurs only around the
            // face, not the whole frame: the video draws this at every frame where someone is hidden (v2 part M8d).
            let around = CGRect(x: shifted.x - rx, y: shifted.y - ry, width: rx * 2, height: ry * 2).intersection(extent)
            let soft = CIFilter.gaussianBlur()
            soft.inputImage = pixels.outputImage?.clampedToExtent()
            soft.radius = Float(max(2, rx * 2 / blocksAcross * soften))
            guard !around.isEmpty, let hidden = soft.outputImage?.cropped(to: around) else { continue }
            // A circle that fades from `solid` of its radius to its edge, stretched into the ellipse.
            let gradient = CIFilter.radialGradient()
            gradient.center = .zero
            gradient.radius0 = Float(rx * solid)
            gradient.radius1 = Float(rx)
            gradient.color0 = CIColor(red: 1, green: 1, blue: 1)
            gradient.color1 = CIColor(red: 0, green: 0, blue: 0)
            guard let circle = gradient.outputImage, rx > 0 else { continue }
            let mask = circle.transformed(by: CGAffineTransform(scaleX: 1, y: ry / rx).concatenating(CGAffineTransform(translationX: shifted.x, y: shifted.y)))
                .cropped(to: extent)
            let blend = CIFilter.blendWithMask()
            blend.inputImage = hidden
            blend.backgroundImage = result
            blend.maskImage = mask
            if let blended = blend.outputImage?.cropped(to: extent) { result = blended }
        }
        return result
    }
}
