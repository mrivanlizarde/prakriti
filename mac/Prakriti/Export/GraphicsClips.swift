import AVFoundation
import CoreImage
import CoreVideo
import Foundation

// The text of the timelines as rendered clips (v2 part M10a, docs/v2/PLAN.md M10; research-edit-engine.md 5.4): every title,
// teacher's name, key phrase and term card as a full-frame ProRes 4444 clip with transparency in `Graphics/`, drawn by the very
// code that draws it on the video (`OverlayTable.layers`, the same pictures from `OverlayCache`, the same motion), so the text in
// Final Cut Pro or Resolve looks exactly as in the MP4. The editable title the timeline puts above each is only a convenience.
//
// And the held last frame (M9a's hold), as a short ProRes 422 clip of that one frame, read from the media the timeline points at.
//
// Frames go into the writer through `inputPixelBufferReceiver(for:)` (the macOS 27 call, PLAN 2.2). Each buffer is tagged
// premultiplied, which is what Core Image draws, so the encoder stores the edges of the letters and their shadow correctly.

enum GraphicsClips {
    static let folderName = "Graphics"
    static let heldName = "Held last frame"

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// The clip's name for a text: "Title", "Lower third 1", "Key phrase 3", "Term 1".
    static func name(_ kind: OverlayKind, number: Int) -> String {
        switch kind {
        case .title: number == 1 ? "Title" : "Title \(number)"
        case .lowerThird: "Lower third \(number)"
        case .keyPhrase: "Key phrase \(number)"
        case .term: "Term \(number)"
        case .dateLabel: "Date label \(number)"
        }
    }

    /// Every text of the plan, drawn into `folder` as `<name>.mov`; the clips returned point at `finalFolder`, where the folder
    /// will be once it is kept. In the order they come on screen.
    static func make(plan: EditPlan, timeline: EditTimeline, renderSize: CGSize, into folder: URL, finalFolder: URL,
                     progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> [TimelineSpec.Clip] {
        let texts = plan.visual.filter(\.isText)
        guard !texts.isEmpty else { return [] }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var made: [(clip: TimelineSpec.Clip, table: OverlayTable, placed: OverlayTable.Placed)] = []
        for item in texts {
            var one = plan
            one.visual = [item]
            guard let table = await OverlayTable.make(plan: one, timeline: timeline, renderSize: renderSize), let placed = table.items.first,
                  let kind = OverlayKind(rawValue: item.kind) else { continue }
            let align = OverlayText.Align(rawValue: item.align ?? "") ?? .leading
            made.append((TimelineSpec.Clip(name: "", url: finalFolder, kind: kind, lines: item.lines ?? [], align: align, start: placed.start, frames: placed.frames),
                         table, placed))
        }
        made.sort { $0.clip.start < $1.clip.start }
        var counts: [OverlayKind: Int] = [:]
        var out: [TimelineSpec.Clip] = []
        let total = made.reduce(0) { $0 + $1.placed.frames }
        var done: Int64 = 0
        for var entry in made {
            guard let kind = entry.clip.kind else { continue }
            counts[kind, default: 0] += 1
            let name = Self.name(kind, number: counts[kind] ?? 1)
            entry.clip.name = name
            entry.clip.url = finalFolder.appending(path: name + ".mov")
            try await writeText(entry.table, placed: entry.placed, size: renderSize, frame: timeline.frame, to: folder.appending(path: name + ".mov"))
            done += entry.placed.frames
            progress(Double(done) / Double(max(1, total)))
            out.append(entry.clip)
        }
        return out
    }

    // MARK: Writing

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// One text, frame by frame as the compositor draws it, over transparency, as ProRes 4444.
    static func writeText(_ table: OverlayTable, placed: OverlayTable.Placed, size: CGSize, frame: FrameDuration, to url: URL) async throws {
        let width = Int(size.width), height = Int(size.height)
        let pool = try makePool(width: width, height: height)
        let clear = CIImage(color: .clear).cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        try await write(to: url, codec: .proRes4444, width: width, height: height, frame: frame, frames: placed.frames) { k in
            var image = clear
            for layer in table.layers(atEditFrame: placed.start + k) { image = layer.composited(over: image) }
            let buffer = try makeBuffer(pool)
            CVBufferSetAttachment(buffer, kCVImageBufferAlphaChannelModeKey, kCVImageBufferAlphaChannelMode_PremultipliedAlpha, .shouldPropagate)
            context.render(image.cropped(to: clear.extent), to: buffer, bounds: clear.extent, colorSpace: space)
            // Drawn, and never touched again here: it goes to the writer alone.
            nonisolated(unsafe) let drawn = buffer
            return CVReadOnlyPixelBuffer(unsafeBuffer: drawn)
        }
    }

    /// The held last frame: the media's frame `sourceFrame`, `frames` long, as ProRes 422.
    static func writeHeld(media: URL, sourceFrame: Int64, frame: FrameDuration, frames: Int64, to url: URL) async throws {
        let asset = AVURLAsset(url: media)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The held last frame could not be read: the media has no picture.")
        }
        let size = try await track.load(.naturalSize)
        let reader = try AVAssetReader(asset: asset)
        let at = CMTime(value: sourceFrame * frame.value, timescale: CMTimeScale(frame.timescale))
        reader.timeRange = CMTimeRange(start: at, duration: CMTime(value: 4 * frame.value, timescale: CMTimeScale(frame.timescale)))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let samples = reader.outputProvider(for: output)
        try reader.start()
        var still: CVReadOnlyPixelBuffer?
        while let sample = try await samples.next() {
            if case let .pixelBuffer(buffer) = sample.content { still = buffer; break }
        }
        reader.cancelReading()
        guard let still else { throw Failure(reason: "The held last frame could not be read from the media.") }
        try await write(to: url, codec: .proRes422, width: Int(size.width), height: Int(size.height), frame: frame, frames: frames) { _ in still }
    }

    /// Writes `frames` frames, each from `draw`, at whole frame times.
    private static func write(to url: URL, codec: AVVideoCodecType, width: Int, height: Int, frame: FrameDuration, frames: Int64,
                              draw: (Int64) throws -> CVReadOnlyPixelBuffer) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codec, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ])
        input.mediaTimeScale = CMTimeScale(frame.timescale)
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: nil)
        do {
            try writer.start()
        } catch {
            throw Failure(reason: "A graphics clip could not be started: \(error.localizedDescription)")
        }
        writer.startSession(atSourceTime: .zero)
        do {
            for k in 0..<frames {
                try Task.checkCancellation()
                let buffer = try draw(k)
                try await receiver.append(buffer, with: CMTime(value: k * frame.value, timescale: CMTimeScale(frame.timescale)))
            }
            receiver.finish()
        } catch {
            writer.cancelWriting()
            throw error is CancellationError ? error : Failure(reason: "A graphics clip stopped while it was written: \(error.localizedDescription)")
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw Failure(reason: "A graphics clip could not be finished: \(writer.error?.localizedDescription ?? "the writer did not say why").")
        }
    }

    private static func makePool(width: Int, height: Int) throws -> CVPixelBufferPool {
        var pool: CVPixelBufferPool?
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ]
        guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess, let pool else {
            throw Failure(reason: "No picture buffers could be made for the graphics clips.")
        }
        return pool
    }

    private static func makeBuffer(_ pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
            throw Failure(reason: "No picture buffer could be made for a graphics clip.")
        }
        return buffer
    }
}
