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
// `HiddenFaces`, worked out before the video is drawn (`VideoHiding`), so the file and the Viewer hide the same. From part
// M9a a punch-in or push-in frames the picture here too (`Framing`, read by the edited frame, `frame(_:crop:)`); text (M9b)
// will draw here as well. `RenderTests` and `StyleTests` run every path.
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
        // The punch-in or push-in at this frame (v2 part M9a), nil for the whole picture.
        let crop = instruction.crop(at: request.compositionTime)
        if regions.isEmpty && crop == nil && !instruction.throughCoreImage {
            request.finish(withComposedPixelBuffer: source)
            return
        }
        do {
            request.finish(withComposedPixelBuffer: try draw(source, hiding: regions, crop: crop, into: request.renderContext))
        } catch {
            request.finish(with: error)
        }
    }

    /// The frame through Core Image into a new buffer from the render context's pool, with `hiding`'s regions hidden by
    /// `FaceHide` (the same function as the card picture's), then framed by `crop` (v2 part M9a): the faces are hidden on
    /// the whole picture first, so a punch-in never shows a face the hiding did not cover.
    func draw(_ source: CVReadOnlyPixelBuffer, hiding: [FaceBox] = [], crop: CGRect? = nil, into renderContext: AVVideoCompositionRenderContext) throws -> CVReadOnlyPixelBuffer {
        let output = try renderContext.makeMutablePixelBuffer()
        let frame = source.withUnsafeBuffer { CIImage(cvPixelBuffer: $0) }
        let image = Self.frame(FaceHide.apply(frame, regions: hiding), crop: crop)
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

    /// `image` framed by `crop` (from the top left, fractions of the picture), scaled back to the picture's own size with
    /// Lanczos (Core Image's sharpest resampling). The edge pixels are extended first, so the scale never pulls in black
    /// from outside the picture. Nil or the whole picture returns `image` unchanged.
    static func frame(_ image: CIImage, crop: CGRect?) -> CIImage {
        guard let crop, crop.width < 0.9999 || crop.height < 0.9999 else { return image }
        let extent = image.extent
        let w = extent.width, h = extent.height
        // Core Image's origin is the bottom left.
        let rect = CGRect(x: extent.minX + crop.minX * w, y: extent.minY + (1 - crop.maxY) * h, width: crop.width * w, height: crop.height * h)
        let scale = w / rect.width
        let moved = image.clampedToExtent().cropped(to: rect.insetBy(dx: -8, dy: -8))
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        let scaled = moved.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: (h / rect.height) / scale])
        return scaled.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    enum Failure: Error {
        case noInstruction
        case noFrame
    }
}
