@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import Vision

// The face step of the people pass (v2 part M6a, docs/v2/PLAN.md M6, research-people.md 1.1, 1.7 and 2.1):
// every frame of the original decoded with AVAssetReader, and two of them a second given to Vision's
// DetectFaceRectanglesRequest, revision 4, with the face capture quality. It reads the original and nothing
// else, keeps no picture, and returns boxes and times only.
//
// Rules from research-people.md 1.7, each measured there:
// - `try reader.start()` and `reader.outputProvider(for:)`, never the macOS 27 deprecated `startReading()` and
//   `copyNextSampleBuffer()` (a deprecation warning fails the build, Mac warning 4). `outputProvider(for:)` adds
//   the output itself: calling `reader.add(output)` first crashes.
// - Vision's first calls load its models and run several times slower, so one frame is analyzed before the
//   step's progress starts (23.9 ms a frame over the first 90 s against 5.7 settled).
// - A picture taller than 1080 lines is analyzed at 1080 (the boxes are fractions of the picture, so nothing
//   else changes).

enum FaceScan {
    /// Two samples a second (the plan's rate).
    static let every = 0.5
    /// The tallest picture Vision is given; a 4K frame is scaled to this first.
    static let analysisHeight = 1080
    /// A change of picture between two samples: the average difference in brightness, 0 to 255, over a 64 by
    /// 36 grid. Measured Mon 12 Oct: a talking teacher moves the 13 Sep picture by at most 27 between samples
    /// half a second apart, and the change of shot at 12:36 measured 141.
    static let cutThreshold = 60.0
    static let gridWidth = 64, gridHeight = 36

    struct Result: Sendable {
        var hasPicture: Bool
        var duration: Double
        var width: Int = 0
        var height: Int = 0
        var samples: [FaceSample] = []
        /// The time of each sample that follows a change of picture.
        var cuts: [Double] = []
        var seconds: Double = 0
    }

    struct Failure: Error, Sendable {
        let reason: String
    }

    /// Looks for faces in `file`. `progress` is called with how far through the picture the scan is, 0 to 1.
    /// A paused make holds between samples; a cancelled one stops at the next. `range` (v2 part M11a, the vertical twin's own face
    /// step) reads only that stretch of the file, in seconds; nil reads it all.
    static func scan(file: URL, range: ClosedRange<Double>? = nil, control: ProcessControl? = nil,
                     progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Result {
        let started = ContinuousClock.now
        let asset = AVURLAsset(url: file)
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return Result(hasPicture: false, duration: duration.isFinite ? duration : 0)
        }
        let size = try await track.load(.naturalSize)
        var result = Result(hasPicture: true, duration: duration.isFinite ? duration : 0,
                            width: Int(abs(size.width).rounded()), height: Int(abs(size.height).rounded()))
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw Failure(reason: "The picture could not be read: \(error.localizedDescription)")
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        if let range {
            reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, range.lowerBound), preferredTimescale: 600),
                                           end: CMTime(seconds: range.upperBound, preferredTimescale: 600))
        }
        let provider = reader.outputProvider(for: output)
        do {
            try reader.start()
        } catch {
            throw Failure(reason: "The picture could not be read: \(error.localizedDescription)")
        }
        let scale = result.height > analysisHeight ? Double(analysisHeight) / Double(result.height) : 1
        let detect = DetectFaceRectanglesRequest(.revision4)
        var next = max(0, range?.lowerBound ?? 0)
        var previousGrid: [Double]?
        var warmed = false
        while let buffer = try await provider.next() {
            try Task.checkCancellation()
            await control?.waitWhilePaused()
            let time = buffer.presentationTimeStamp.seconds
            guard time.isFinite, time + 0.0001 >= next else { continue }
            next += every
            // The frame is read inside the sample buffer's own scope: its brightness grid, and a CIImage that Vision
            // reads from (a pixel buffer itself may not leave that scope under Swift 6's checks).
            let frame: (image: CIImage, grid: [Double]?)? = buffer.withUnsafeSampleBuffer { sample in
                guard let pixels = CMSampleBufferGetImageBuffer(sample) else { return nil }
                let image = scale < 1
                    ? CIImage(cvPixelBuffer: pixels).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    : CIImage(cvPixelBuffer: pixels)
                return (image, brightnessGrid(pixels))
            }
            guard let frame else { continue }
            let image = frame.image
            if let previousGrid, let grid = frame.grid, difference(previousGrid, grid) > cutThreshold { result.cuts.append(time) }
            if let grid = frame.grid { previousGrid = grid }
            if !warmed {
                // Vision loads its models on the first call (research-people.md 1.7): once, before any timing.
                _ = try? await detect.perform(on: image)
                warmed = true
            }
            let faces: [FaceObservation]
            do {
                faces = try await detect.perform(on: image)
            } catch {
                throw Failure(reason: "Vision could not look at the frame at \(Format.timecode(time)): \(error.localizedDescription)")
            }
            var qualities: [UUID: Double] = [:]
            if !faces.isEmpty {
                var quality = DetectFaceCaptureQualityRequest()
                quality.inputFaceObservations = faces
                if let measured = try? await quality.perform(on: image) {
                    for face in measured { if let score = face.captureQuality?.score { qualities[face.uuid] = Double(score) } }
                }
            }
            result.samples.append(FaceSample(time: time, faces: faces.map { face in
                FaceDetection(box: FaceGeometry.fromVision(face.boundingBox.cgRect), confidence: Double(face.confidence), quality: qualities[face.uuid])
            }))
            if let range, range.upperBound > range.lowerBound {
                progress(min(1, max(0, time - range.lowerBound) / (range.upperBound - range.lowerBound)))
            } else if result.duration > 0 {
                progress(min(1, time / result.duration))
            }
        }
        if reader.status == .failed {
            throw Failure(reason: "The picture stopped part way: \(reader.error?.localizedDescription ?? "the file could not be read to its end").")
        }
        let elapsed = ContinuousClock.now - started
        result.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        progress(1)
        return result
    }

    /// The brightness of the picture at 64 by 36 points, read from the luma plane. Used only to notice a change
    /// of picture, and kept only until the next sample.
    static func brightnessGrid(_ pixels: CVPixelBuffer) -> [Double]? {
        guard CVPixelBufferGetPlaneCount(pixels) >= 1 else { return nil }
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0) else { return nil }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let row = CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
        let width = CVPixelBufferGetWidthOfPlane(pixels, 0), height = CVPixelBufferGetHeightOfPlane(pixels, 0)
        guard width >= gridWidth, height >= gridHeight else { return nil }
        var grid = [Double](repeating: 0, count: gridWidth * gridHeight)
        for gy in 0..<gridHeight {
            let y = gy * height / gridHeight + height / (2 * gridHeight)
            for gx in 0..<gridWidth {
                let x = gx * width / gridWidth + width / (2 * gridWidth)
                grid[gy * gridWidth + gx] = Double(bytes[y * row + x])
            }
        }
        return grid
    }

    /// The average absolute difference between two grids.
    static func difference(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var total = 0.0
        for i in a.indices { total += abs(a[i] - b[i]) }
        return total / Double(a.count)
    }
}
