import AVFoundation
import Foundation

// The edited video's picture as an `AVMutableComposition` (v2 part M8b, research-edit-engine.md 4.2 items 1 and 2): every
// kept span of the plan inserted end to end on one video track (all jump cuts), and an `AVVideoComposition` built from
// `AVVideoComposition.Configuration` (never the deprecated mutable types, PLAN 2.2) with the custom `Compositor` and one
// `RenderInstruction` per span. The sound is not in the composition: `VideoAudio` makes it from the same timeline and the
// writer lays it beside the picture.
//
// The same `Built` value is what the Viewer will play in part M8c (`AVPlayerItem.videoComposition`), so the preview and the
// file are drawn by one compositor from one set of instructions.

enum CompositionBuilder {
    struct Built: @unchecked Sendable {
        let composition: AVMutableComposition
        let videoComposition: AVVideoComposition
        let track: AVMutableCompositionTrack
        let timeline: EditTimeline
        let renderSize: CGSize
    }

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// How many whole frames the original's picture holds (what `build` cuts the timeline to).
    static func pictureFrames(original: URL, plan: EditPlan) async throws -> Int64 {
        guard let source = try await AVURLAsset(url: original).loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The original has no picture, so no video can be made from it.")
        }
        let range = try await source.load(.timeRange)
        return Int64((range.end.seconds / plan.frameDuration.seconds + 1e-6).rounded(.down))
    }

    /// The composition for a plan over its original. The original's picture track is read for its size and length; the
    /// spans are inserted in the plan's order.
    static func build(plan: EditPlan, original: URL, throughCoreImage: Bool = false, hidden: HiddenFaces? = nil) async throws -> Built {
        let asset = AVURLAsset(url: original)
        guard let source = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The original has no picture, so no video can be made from it.")
        }
        let (size, transform, range) = try await source.load(.naturalSize, .preferredTransform, .timeRange)
        // A picture recorded turned (a phone held upright) would need turning in the compositor; the studio's cameras record
        // level, so it is refused in words rather than drawn wrong.
        guard transform.isIdentity else {
            throw Failure(reason: "The original's picture is recorded turned, and Prakriti cannot make a video from a turned picture yet.")
        }
        let renderSize = CGSize(width: abs(size.width).rounded(), height: abs(size.height).rounded())
        let pictureFrames = Int64((range.end.seconds / plan.frameDuration.seconds + 1e-6).rounded(.down))
        let timeline = EditTimeline(plan: plan, pictureFrames: pictureFrames)
        guard timeline.totalFrames > 0 else { throw Failure(reason: "The plan keeps no frame of the picture, so no video was made.") }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure(reason: "The video could not be put together.")
        }
        for piece in timeline.pieces {
            let range = CMTimeRange(start: timeline.time(piece.sourceFrame), duration: timeline.time(piece.frames))
            do {
                try track.insertTimeRange(range, of: source, at: timeline.time(piece.editFrame))
            } catch {
                throw Failure(reason: "Span \(piece.id) of the plan could not be put into the video: \(error.localizedDescription)")
            }
        }

        let frameDuration = CMTime(value: plan.frameDuration.value, timescale: CMTimeScale(plan.frameDuration.timescale))
        // The faces hidden in the video (v2 part M8d): one table shared by every instruction, read by the original's frame.
        let table = hidden.flatMap { $0.isEmpty ? nil : $0.table() }
        let instructions = timeline.pieces.map { piece in
            RenderInstruction(timeRange: CMTimeRange(start: timeline.time(piece.editFrame), duration: timeline.time(piece.frames)),
                              trackID: track.trackID, spanID: piece.id, sourceStart: timeline.seconds(piece.sourceFrame),
                              throughCoreImage: throughCoreImage, firstSourceFrame: piece.sourceFrame, frameDuration: frameDuration,
                              hidden: table)
        }
        let configuration = AVVideoComposition.Configuration(
            colorPrimaries: AVVideoColorPrimaries_ITU_R_709_2, colorTransferFunction: AVVideoTransferFunction_ITU_R_709_2,
            colorYCbCrMatrix: AVVideoYCbCrMatrix_ITU_R_709_2, customVideoCompositorClass: Compositor.self, frameDuration: frameDuration,
            instructions: instructions, renderSize: renderSize)
        return Built(composition: composition, videoComposition: AVVideoComposition(configuration: configuration), track: track,
                     timeline: timeline, renderSize: renderSize)
    }
}
