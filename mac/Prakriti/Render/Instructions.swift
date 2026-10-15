import AVFoundation
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

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, spanID: String, sourceStart: Double, throughCoreImage: Bool = false,
         firstSourceFrame: Int64 = 0, frameDuration: CMTime = CMTime(value: 1001, timescale: 30000), hidden: HiddenFaces.Table? = nil,
         framing: Framing? = nil, holds: Bool = false) {
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
        requiredSourceTrackIDs = [NSNumber(value: trackID)]
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
        return framing.rect(atEditFrame: Int64((compositionTime.seconds / frameDuration.seconds).rounded()))
    }

    /// The regions to hide in the frame at `compositionTime` (none when nobody is hidden).
    func regions(at compositionTime: CMTime) -> [FaceBox] {
        hidden?.regions(atSourceFrame: sourceFrame(at: compositionTime)) ?? []
    }
}
