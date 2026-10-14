import AVFoundation
import CoreImage
import Foundation

// The compositor (v2 part M8b, research-edit-engine.md 4.2 items 3 and 4): one `AVVideoCompositing` class that draws every
// frame of the edited video, for the file (`VideoWriter`, through `AVAssetReaderVideoCompositionOutput`) and, from part
// M8c, for the Viewer (`AVPlayerItem.videoComposition`), so the preview is the output.
//
// In M8b an instruction has nothing to draw over the picture (no hidden faces, no zooms, no text: parts M8d and M9), so
// the source frame is handed on unchanged, which is exact: the picture is the original's own pixels until the encoder.
// When an instruction carries something to draw, the frame goes through Core Image on Metal (`draw`), one context for the
// compositor's life. `RenderTests` runs both paths.
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
        if instruction.drawsNothing {
            request.finish(withComposedPixelBuffer: source)
            return
        }
        do {
            request.finish(withComposedPixelBuffer: try draw(source, into: request.renderContext))
        } catch {
            request.finish(with: error)
        }
    }

    /// The frame through Core Image into a new buffer from the render context's pool.
    func draw(_ source: CVReadOnlyPixelBuffer, into renderContext: AVVideoCompositionRenderContext) throws -> CVReadOnlyPixelBuffer {
        let output = try renderContext.makeMutablePixelBuffer()
        let image = source.withUnsafeBuffer { CIImage(cvPixelBuffer: $0) }
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
