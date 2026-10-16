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
    /// `drawText: false` leaves the text on screen out (tests only, to measure where the text is by difference).
    static func build(plan: EditPlan, original: URL, throughCoreImage: Bool = false, hidden: HiddenFaces? = nil, drawText: Bool = true) async throws -> Built {
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
        // The held last frame (v2 part M9a): the last kept frame inserted once and stretched over the hold, so the player
        // shows it still. A reader of the composition gives that frame once (measured 14 Oct: 62 one-frame inserts of the same
        // frame came out as one frame too), so `VideoWriter` writes it again for every frame of the hold.
        if timeline.holdFrames > 0, let shown = timeline.holdSourceFrame {
            let at = timeline.time(timeline.keptFrames)
            do {
                try track.insertTimeRange(CMTimeRange(start: timeline.time(shown), duration: timeline.time(1)), of: source, at: at)
                track.scaleTimeRange(CMTimeRange(start: at, duration: timeline.time(1)), toDuration: timeline.time(timeline.holdFrames))
            } catch {
                throw Failure(reason: "The held last frame could not be put into the video: \(error.localizedDescription)")
            }
        }

        let frameDuration = CMTime(value: plan.frameDuration.value, timescale: CMTimeScale(plan.frameDuration.timescale))
        // The faces hidden in the video (v2 part M8d): one table shared by every instruction, read by the original's frame.
        let table = hidden.flatMap { $0.isEmpty ? nil : $0.table() }
        // The punch-ins and push-ins (v2 part M9a), one table shared by every instruction, read by the edited frame.
        let framing = Framing(plan: plan, timeline: timeline)
        // The text on screen (v2 part M9b): each text drawn once (on the main actor, `OverlayCache`) and placed on the edited
        // clock, one table shared by every instruction.
        let overlays = drawText ? await OverlayTable.make(plan: plan, timeline: timeline, renderSize: renderSize) : nil
        var instructions = timeline.pieces.map { piece in
            RenderInstruction(timeRange: CMTimeRange(start: timeline.time(piece.editFrame), duration: timeline.time(piece.frames)),
                              trackID: track.trackID, spanID: piece.id, sourceStart: timeline.seconds(piece.sourceFrame),
                              throughCoreImage: throughCoreImage, firstSourceFrame: piece.sourceFrame, frameDuration: frameDuration,
                              hidden: table, framing: framing.isEmpty ? nil : framing, overlays: overlays)
        }
        if timeline.holdFrames > 0, let shown = timeline.holdSourceFrame, let last = timeline.pieces.last {
            instructions.append(RenderInstruction(timeRange: CMTimeRange(start: timeline.time(timeline.keptFrames), duration: timeline.time(timeline.holdFrames)),
                                                  trackID: track.trackID, spanID: last.id, sourceStart: timeline.seconds(shown),
                                                  throughCoreImage: throughCoreImage, firstSourceFrame: shown, frameDuration: frameDuration,
                                                  hidden: table, framing: nil, holds: true, overlays: overlays))
        }
        let configuration = AVVideoComposition.Configuration(
            colorPrimaries: AVVideoColorPrimaries_ITU_R_709_2, colorTransferFunction: AVVideoTransferFunction_ITU_R_709_2,
            colorYCbCrMatrix: AVVideoYCbCrMatrix_ITU_R_709_2, customVideoCompositorClass: Compositor.self, frameDuration: frameDuration,
            instructions: instructions, renderSize: renderSize)
        return Built(composition: composition, videoComposition: AVVideoComposition(configuration: configuration), track: track,
                     timeline: timeline, renderSize: renderSize)
    }

    /// The privacy-safe media of the timelines (v2 part M10b, `CleanedMedia`): the original's frames over `timeline`'s pieces (the
    /// used ranges plus their handles, end to end), drawn by the same `Compositor` with the same hidden regions, and nothing else:
    /// no punch-in, no text, no held frame. The editing app frames and titles it; the faces are already burned in.
    static func buildMedia(timeline: EditTimeline, original: URL, hidden: HiddenFaces?) async throws -> Built {
        let asset = AVURLAsset(url: original)
        guard let source = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The original has no picture, so no media can be made from it.")
        }
        let (size, transform) = try await source.load(.naturalSize, .preferredTransform)
        guard transform.isIdentity else {
            throw Failure(reason: "The original's picture is recorded turned, and Prakriti cannot make media from a turned picture yet.")
        }
        guard timeline.totalFrames > 0 else { throw Failure(reason: "No range of the picture is used, so no media was made.") }
        let renderSize = CGSize(width: abs(size.width).rounded(), height: abs(size.height).rounded())
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure(reason: "The media could not be put together.")
        }
        for piece in timeline.pieces {
            do {
                try track.insertTimeRange(CMTimeRange(start: timeline.time(piece.sourceFrame), duration: timeline.time(piece.frames)), of: source,
                                          at: timeline.time(piece.editFrame))
            } catch {
                throw Failure(reason: "A range of the recording could not be put into the media: \(error.localizedDescription)")
            }
        }
        let frameDuration = timeline.time(1)
        let table = hidden.flatMap { $0.isEmpty ? nil : $0.table() }
        let instructions = timeline.pieces.map { piece in
            RenderInstruction(timeRange: CMTimeRange(start: timeline.time(piece.editFrame), duration: timeline.time(piece.frames)),
                              trackID: track.trackID, spanID: piece.id, sourceStart: timeline.seconds(piece.sourceFrame),
                              firstSourceFrame: piece.sourceFrame, frameDuration: frameDuration, hidden: table)
        }
        let configuration = AVVideoComposition.Configuration(
            colorPrimaries: AVVideoColorPrimaries_ITU_R_709_2, colorTransferFunction: AVVideoTransferFunction_ITU_R_709_2,
            colorYCbCrMatrix: AVVideoYCbCrMatrix_ITU_R_709_2, customVideoCompositorClass: Compositor.self, frameDuration: frameDuration,
            instructions: instructions, renderSize: renderSize)
        return Built(composition: composition, videoComposition: AVVideoComposition(configuration: configuration), track: track,
                     timeline: timeline, renderSize: renderSize)
    }

    /// A short (v2 part M11a, `Shorts`): `timeline`'s pieces of `source` (the main recording, or its vertical twin, on that file's
    /// own frames) end to end, drawn by the same `Compositor` at `renderSize` (1080 by 1920): the faces in `hidden` hidden on the
    /// whole picture first, then the 9:16 window of `framing` (none for the twin, which is already vertical), then the burned
    /// captions. No punch-in, no title, no held frame.
    static func buildShort(timeline: EditTimeline, source original: URL, renderSize: CGSize, framing: Framing, hidden: HiddenFaces?,
                           captions: BurnedCaptions.Table?) async throws -> Built {
        let asset = AVURLAsset(url: original)
        guard let source = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The recording has no picture, so no short can be made from it.")
        }
        let transform = try await source.load(.preferredTransform)
        guard transform.isIdentity else {
            throw Failure(reason: "The recording's picture is recorded turned, and Prakriti cannot make a short from a turned picture yet.")
        }
        guard timeline.totalFrames > 0 else { throw Failure(reason: "The short keeps no frame of the picture.") }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure(reason: "The short could not be put together.")
        }
        for piece in timeline.pieces {
            do {
                try track.insertTimeRange(CMTimeRange(start: timeline.time(piece.sourceFrame), duration: timeline.time(piece.frames)), of: source,
                                          at: timeline.time(piece.editFrame))
            } catch {
                throw Failure(reason: "A part of the short could not be put together: \(error.localizedDescription)")
            }
        }
        let frameDuration = timeline.time(1)
        let table = hidden.flatMap { $0.isEmpty ? nil : $0.table() }
        let instructions = timeline.pieces.map { piece in
            RenderInstruction(timeRange: CMTimeRange(start: timeline.time(piece.editFrame), duration: timeline.time(piece.frames)),
                              trackID: track.trackID, spanID: piece.id, sourceStart: timeline.seconds(piece.sourceFrame),
                              firstSourceFrame: piece.sourceFrame, frameDuration: frameDuration, hidden: table,
                              framing: framing.isEmpty ? nil : framing, captions: captions)
        }
        let configuration = AVVideoComposition.Configuration(
            colorPrimaries: AVVideoColorPrimaries_ITU_R_709_2, colorTransferFunction: AVVideoTransferFunction_ITU_R_709_2,
            colorYCbCrMatrix: AVVideoYCbCrMatrix_ITU_R_709_2, customVideoCompositorClass: Compositor.self, frameDuration: frameDuration,
            instructions: instructions, renderSize: renderSize)
        return Built(composition: composition, videoComposition: AVVideoComposition(configuration: configuration), track: track,
                     timeline: timeline, renderSize: renderSize)
    }
}
