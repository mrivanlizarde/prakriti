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
// M9a a punch-in or push-in frames the picture here too (`Framing`, read by the edited frame, `frame(_:crop:)`), and from part
// M9b the text on screen is laid over the framed picture (`OverlayTable`, `overlay(_:on:)`). `RenderTests` and `StyleTests` run every path.
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
        // The text on screen at this frame (v2 part M9b), already moved and faded.
        let text = instruction.textLayers(at: request.compositionTime)
        // A cross dissolve where a moment from another recording joins the talk (v2 part M12b): both pictures, each hidden, matched and
        // framed as it is on its own, mixed by how far through the dissolve the frame is, then the text over both.
        if let dissolve = instruction.dissolve {
            guard let incoming = request.sourceReadOnlyPixelBuffer(byTrackID: dissolve.toTrackID) else {
                request.finish(with: Failure.noFrame)
                return
            }
            let into = dissolve.toHidden?.regions(atSourceFrame: instruction.incomingSourceFrame(at: request.compositionTime)) ?? []
            let mix = dissolve.progress(atEditFrame: instruction.editFrame(at: request.compositionTime))
            do {
                request.finish(withComposedPixelBuffer: try draw(source, hiding: regions, colour: instruction.colour, crop: crop, text: text,
                                                                 incoming: (incoming, into, dissolve.toColour, instruction.incomingCrop(), mix),
                                                                 into: request.renderContext))
            } catch {
                request.finish(with: error)
            }
            return
        }
        if regions.isEmpty && crop == nil && text.isEmpty && instruction.colour == nil && !instruction.throughCoreImage {
            request.finish(withComposedPixelBuffer: source)
            return
        }
        do {
            request.finish(withComposedPixelBuffer: try draw(source, hiding: regions, colour: instruction.colour, crop: crop, text: text, into: request.renderContext))
        } catch {
            request.finish(with: error)
        }
    }

    /// One picture as the video shows it: matched in colour (a moment from another recording, v2 part M12b), its hidden faces hidden on
    /// the whole picture, then framed to the render size.
    static func picture(_ frame: CIImage, hiding: [FaceBox], colour: [Double]?, crop: CGRect?, to target: CGSize) -> CIImage {
        var image = frame
        if let colour, colour.count == 3 {
            image = image.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: colour[0], y: 0, z: 0, w: 0),
                                                                    "inputGVector": CIVector(x: 0, y: colour[1], z: 0, w: 0),
                                                                    "inputBVector": CIVector(x: 0, y: 0, z: colour[2], w: 0)])
                .cropped(to: frame.extent)
        }
        return Self.frame(FaceHide.apply(image, regions: hiding), crop: crop, to: target)
    }

    /// The frame through Core Image into a new buffer from the render context's pool, with `hiding`'s regions hidden by
    /// `FaceHide` (the same function as the card picture's), then framed by `crop` (v2 part M9a): the faces are hidden on
    /// the whole picture first, so a punch-in never shows a face the hiding did not cover.
    func draw(_ source: CVReadOnlyPixelBuffer, hiding: [FaceBox] = [], colour: [Double]? = nil, crop: CGRect? = nil, text: [CIImage] = [],
              incoming: (CVReadOnlyPixelBuffer, [FaceBox], [Double]?, CGRect?, Double)? = nil,
              into renderContext: AVVideoCompositionRenderContext) throws -> CVReadOnlyPixelBuffer {
        let output = try renderContext.makeMutablePixelBuffer()
        let frame = source.withUnsafeBuffer { CIImage(cvPixelBuffer: $0) }
        // The picture is framed to the render size: the source's own for the video, 1080 by 1920 for a short cropped from a
        // wider picture (v2 part M11a).
        let size = renderContext.size
        let target = size.width > 0 && size.height > 0 ? size : frame.extent.size
        var picture = Self.picture(frame, hiding: hiding, colour: colour, crop: crop, to: target)
        if let (buffer, regions, gains, rect, mix) = incoming {
            let other = Self.picture(buffer.withUnsafeBuffer { CIImage(cvPixelBuffer: $0) }, hiding: regions, colour: gains, crop: rect, to: target)
            picture = Self.dissolve(from: picture, to: other, progress: mix)
        }
        let image = Self.overlay(text, on: picture)
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
    /// `to` is the size of the frame made (v2 part M11a): a short's 9:16 window of a wider picture is scaled to 1080 by 1920.
    /// Nil, or the picture's own size, keeps the picture's size, as for the video.
    static func frame(_ image: CIImage, crop: CGRect?, to size: CGSize? = nil) -> CIImage {
        let extent = image.extent
        let w = extent.width, h = extent.height
        let target = size ?? extent.size
        let resized = abs(target.width - w) > 0.5 || abs(target.height - h) > 0.5
        guard resized || (crop.map { $0.width < 0.9999 || $0.height < 0.9999 } ?? false) else { return image }
        let crop = crop ?? Framing.whole
        // Core Image's origin is the bottom left.
        let rect = CGRect(x: extent.minX + crop.minX * w, y: extent.minY + (1 - crop.maxY) * h, width: crop.width * w, height: crop.height * h)
        let scale = target.width / rect.width
        let moved = image.clampedToExtent().cropped(to: rect.insetBy(dx: -8, dy: -8))
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        let scaled = moved.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: (target.height / rect.height) / scale])
        return scaled.cropped(to: CGRect(x: 0, y: 0, width: target.width, height: target.height))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// A cross dissolve (v2 part M12b): `to` over `from` at `progress` (0 is `from` alone, 1 is `to` alone), mixed on the linear picture.
    static func dissolve(from: CIImage, to: CIImage, progress: Double) -> CIImage {
        from.applyingFilter("CIDissolveTransition", parameters: ["inputTargetImage": to, kCIInputTimeKey: progress]).cropped(to: from.extent)
    }

    /// The text pictures laid over the framed picture (v2 part M9b), last: text is never scaled by a punch-in and never
    /// hidden. Cropped back to the picture, so a text sliding in never widens the frame.
    static func overlay(_ layers: [CIImage], on image: CIImage) -> CIImage {
        guard !layers.isEmpty else { return image }
        var out = image
        for layer in layers { out = layer.composited(over: out) }
        return out.cropped(to: image.extent)
    }

    enum Failure: Error {
        case noInstruction
        case noFrame
    }
}
