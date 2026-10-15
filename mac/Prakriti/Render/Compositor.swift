import AVFoundation
import CoreImage
import Foundation

// The compositor (v2 part M8b, research-edit-engine.md 4.2 items 3 and 4): one `AVVideoCompositing` class that draws every
// frame of the edited video, for the file (`VideoWriter`, through `AVAssetReaderVideoCompositionOutput`) and, from part
// M8c, for the Viewer (`AVPlayerItem.videoComposition`), so the preview is the output.
//
// A frame with nothing to draw over it is handed on unchanged, which is exact: the picture is the original's own pixels
// until the encoder. From part M8d a frame where someone is hidden goes through Core Image on Metal (`draw`, one context for
// the compositor's life) with each region hidden by `FaceHide`; the regions are looked up by the original's frame in
// `HiddenFaces`, worked out before the video is drawn (`VideoHiding`), so the file and the Viewer hide the same. Zooms and
// text (M9) will draw here too. `RenderTests` runs both paths.
//
// The SDK's macOS 27 names only (Mac warning 4, PLAN 2.2): `sourceReadOnlyPixelBuffer(byTrackID:)` and
// `renderContext.makeMutablePixelBuffer()`, never `sourceFrame(byTrackID:)` or `newPixelBuffer()`.

final class Compositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    /// The source frames as the camera's files carry them: 8-bit 4:2:0, video range (BT.709 tagged by the recorder).
    static let pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

    let sourcePixelBufferAttributes: [String: any Sendable]? = [kCVPixelBufferPixelFormatTypeKey as String: Compositor.pixelFormat]
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [kCVPixelBufferPixelFormatTypeKey as String: Compositor.pixelFormat]

    /// One Core Image context for the compositor's life, on the Mac's GPU (Metal). Intermediates are not cached: each frame
    /// is new.
    private let context = CIContext(options: [.cacheIntermediates: false, .name: "Prakriti compositor"])

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? RenderInstruction else {
            request.finish(with: Failure.noInstruction)
            return
        }
        guard let source = request.sourceReadOnlyPixelBuffer(byTrackID: instruction.trackID) else {
            request.finish(with: Failure.noFrame)
            return
        }
        // The faces hidden in this frame (v2 part M8d), looked up by the original's frame. A frame with nothing to hide is
        // handed on untouched, exactly the original's pixels.
        let regions = instruction.regions(at: request.compositionTime)
        if regions.isEmpty && !instruction.throughCoreImage {
            request.finish(withComposedPixelBuffer: source)
            return
        }
        do {
            request.finish(withComposedPixelBuffer: try draw(source, hiding: regions, into: request.renderContext))
        } catch {
            request.finish(with: error)
        }
    }

    /// The frame through Core Image into a new buffer from the render context's pool, with `hiding`'s regions hidden by
    /// `FaceHide` (the same function as the card picture's).
    func draw(_ source: CVReadOnlyPixelBuffer, hiding: [FaceBox] = [], into renderContext: AVVideoCompositionRenderContext) throws -> CVReadOnlyPixelBuffer {
        let output = try renderContext.makeMutablePixelBuffer()
        let frame = source.withUnsafeBuffer { CIImage(cvPixelBuffer: $0) }
        let image = FaceHide.apply(frame, regions: hiding)
        output.withUnsafeBuffer { buffer in
            // The source's colour tags (BT.709 matrix, primaries and transfer) go on the new buffer first: Core Image reads
            // them to turn its working colour back into the same YCbCr. Without them it wrote another matrix (measured 13 Oct
            // in RenderTests on the test pattern: 23.7 dB against the source frame; with them 37.9 dB, the rest being the
            // 4:2:0 colour resampled twice).
            source.withUnsafeBuffer { CVBufferPropagateAttachments($0, buffer) }
            context.render(image, to: buffer)
        }
        return CVReadOnlyPixelBuffer(output)
    }

    enum Failure: Error {
        case noInstruction
        case noFrame
    }
}
