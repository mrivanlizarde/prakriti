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

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, spanID: String, sourceStart: Double, throughCoreImage: Bool = false) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.spanID = spanID
        self.sourceStart = sourceStart
        self.throughCoreImage = throughCoreImage
        requiredSourceTrackIDs = [NSNumber(value: trackID)]
    }

    /// Nothing is drawn over the picture in this stretch.
    var drawsNothing: Bool { !throughCoreImage }
}
