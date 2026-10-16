import AVFoundation
import CoreImage
import Foundation

// The compositor's instructions (v2 part M8b, research-edit-engine.md 4.2 item 3): one per kept span of the plan, laid end
// to end on the edited clock with no gap, as `AVVideoComposition` requires. Each says which composition track it reads,
// which span of the plan it is and where that span starts on the original's clock, which is the clock everything later
// parts draw is measured on (face boxes, M8d; zooms and text, M9).

/// One stretch of the edited video and how to draw it: which composition track it reads and where on the original's
/// clock it comes from. Read from the plan by `CompositionBuilder`.
final class RenderInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = false
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    let trackID: CMPersistentTrackID
    /// The plan's span id, and where the stretch starts on the original's clock (for what later parts draw: a face box is
    /// found on the original's clock).
    let spanID: String
    let sourceStart: Double
    /// Draw the frame through Core Image even with nothing over it. Only `RenderTests` sets it, to measure that path.
    let throughCoreImage: Bool
    /// The span's first frame on the original's clock and the length of one frame, so a moment of the edited clock finds its
    /// frame of the original (v2 part M8d: the hidden faces are kept by the original's frame).
    let firstSourceFrame: Int64
    let frameDuration: CMTime
    /// The faces hidden in the video (v2 part M8d), shared by every instruction; nil when nobody is hidden.
    let hidden: HiddenFaces.Table?
    /// The punch-ins and push-ins (v2 part M9a), shared by every instruction and read by the edited frame; nil when the
    /// whole picture is shown throughout.
    let framing: Framing?
    /// The held last frame (v2 part M9a): every moment of it shows `firstSourceFrame`.
    let holds: Bool
    /// The text on screen (v2 part M9b), shared by every instruction and read by the edited frame; nil when there is none.
    let overlays: OverlayTable?
    /// A short's burned captions (v2 part M11a), shared by every instruction and read by the edited frame; nil for the video.
    let captions: BurnedCaptions.Table?
    /// The colour match of a moment from another recording (v2 part M12b): red, green and blue gains on the linear picture; nil for none.
    let colour: [Double]?
    /// A cross dissolve where a moment from another recording joins the talk (v2 part M12b): this instruction's own track is the
    /// picture going out, `dissolve` the one coming in.
    let dissolve: Dissolve?

    /// The picture coming in during a cross dissolve, and how far through it each frame is.
    struct Dissolve: @unchecked Sendable {
        let toTrackID: CMPersistentTrackID
        /// Its frame at the dissolve's first frame, on its own recording's clock.
        let toFirstSourceFrame: Int64
        /// The faces hidden in it (the talk's own picture only) and its colour match (a moment's only).
        let toHidden: HiddenFaces.Table?
        let toColour: [Double]?
        /// The edited frames whose framing (punch-in) each side keeps through the dissolve, or nil for the whole picture: the talk's
        /// framing just before the dissolve going out, just after it coming in, so neither side jumps under the dissolve.
        let fromCropFrame: Int64?
        let toCropFrame: Int64?
        /// The dissolve's first edited frame and its length in frames.
        let startFrame: Int64
        let frames: Int64

        /// How far the picture coming in is shown at an edited frame, 0 to 1 (half a frame in from each end, so no frame is either
        /// picture alone).
        func progress(atEditFrame frame: Int64) -> Double {
            min(1, max(0, (Double(frame - startFrame) + 0.5) / Double(max(1, frames))))
        }
    }

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, spanID: String, sourceStart: Double, throughCoreImage: Bool = false,
         firstSourceFrame: Int64 = 0, frameDuration: CMTime = CMTime(value: 1001, timescale: 30000), hidden: HiddenFaces.Table? = nil,
         framing: Framing? = nil, holds: Bool = false, overlays: OverlayTable? = nil, captions: BurnedCaptions.Table? = nil,
         colour: [Double]? = nil, dissolve: Dissolve? = nil) {
        self.overlays = overlays
        self.captions = captions
        self.colour = colour
        self.dissolve = dissolve
        self.timeRange = timeRange
        self.trackID = trackID
        self.spanID = spanID
        self.sourceStart = sourceStart
        self.throughCoreImage = throughCoreImage
        self.firstSourceFrame = firstSourceFrame
        self.frameDuration = frameDuration
        self.hidden = hidden
        self.framing = framing
        self.holds = holds
        requiredSourceTrackIDs = [NSNumber(value: trackID)] + (dissolve.map { [NSNumber(value: $0.toTrackID)] } ?? [])
    }

    /// The edited frame at a moment of the edited clock.
    func editFrame(at compositionTime: CMTime) -> Int64 {
        Int64((compositionTime.seconds / frameDuration.seconds).rounded())
    }

    /// The incoming picture's frame of its own recording at a moment of a dissolve.
    func incomingSourceFrame(at compositionTime: CMTime) -> Int64 {
        let offset = CMTimeSubtract(compositionTime, timeRange.start).seconds / frameDuration.seconds
        return (dissolve?.toFirstSourceFrame ?? 0) + Int64(max(0, offset).rounded())
    }

    /// The original's frame shown at a moment of the edited clock inside this instruction.
    func sourceFrame(at compositionTime: CMTime) -> Int64 {
        if holds { return firstSourceFrame }
        let offset = CMTimeSubtract(compositionTime, timeRange.start).seconds / frameDuration.seconds
        return firstSourceFrame + Int64(max(0, offset).rounded())
    }

    /// The part of the picture shown at a moment of the edited clock (v2 part M9a), or nil for the whole picture.
    func crop(at compositionTime: CMTime) -> CGRect? {
        guard let framing, !holds else { return nil }
        // In a dissolve the picture going out keeps the framing it had (v2 part M12b); a moment's picture is always whole.
        if let dissolve { return dissolve.fromCropFrame.map { framing.rect(atEditFrame: $0) } ?? nil }
        return framing.rect(atEditFrame: editFrame(at: compositionTime))
    }

    /// The part of the incoming picture shown in a dissolve, or nil for the whole picture.
    func incomingCrop() -> CGRect? {
        guard let framing, let frame = dissolve?.toCropFrame else { return nil }
        return framing.rect(atEditFrame: frame)
    }

    /// The text pictures to lay over the frame at `compositionTime`, moved and faded (v2 part M9b); empty when none shows.
    func textLayers(at compositionTime: CMTime) -> [CIImage] {
        let frame = Int64((compositionTime.seconds / frameDuration.seconds).rounded())
        var layers = overlays?.layers(atEditFrame: frame) ?? []
        // A short's caption (v2 part M11a), laid over last.
        if let caption = captions?.layer(atEditFrame: frame) { layers.append(caption) }
        return layers
    }

    /// The regions to hide in the frame at `compositionTime` (none when nobody is hidden).
    func regions(at compositionTime: CMTime) -> [FaceBox] {
        hidden?.regions(atSourceFrame: sourceFrame(at: compositionTime)) ?? []
    }
}
