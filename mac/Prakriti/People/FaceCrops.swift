@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import Observation

// The faces on the People tab (v2 part M6a, design spec 3.5.2 and C2): each row's face is cropped from the
// original at its key moment when the tab shows it, held in memory for the recording on screen, and never
// written anywhere. Selecting another recording empties the cache. Reason: a stored picture of every face would
// be a collection of students' faces, the thing the biometric decision forbids (docs/v2/PLAN.md section 5 and
// review item 8); Ivan still sees who is there in his own app (design spec Q3).

@MainActor
@Observable
final class FaceCrops {
    /// The recording whose crops are held; any other is dropped when a new one asks.
    private var recordingID: UUID?
    private var images: [Int: CGImage] = [:]
    @ObservationIgnored private var loading: Set<Int> = []
    /// Sample data and snapshots: a test pattern in place of every face, so no picture of anyone is drawn
    /// (docs/v2/PLAN.md section 11, D1: frames of a talk are measured, not looked at).
    @ObservationIgnored var useTestPattern = false

    init() {}

    /// What the row shows now: read only, so a view's body never changes this model.
    func image(for person: FacePerson, in recording: Recording) -> CGImage? {
        if useTestPattern { return Self.testPattern(seed: person.id) }
        return recordingID == recording.id ? images[person.id] : nil
    }

    /// Crops the person's face from the original, off the main thread (the original lives in ~/Documents, Mac
    /// warning 44), and keeps it in memory. Another recording's crops are dropped first.
    func load(_ person: FacePerson, from recording: Recording) {
        guard !useTestPattern else { return }
        if recordingID != recording.id {
            recordingID = recording.id
            images = [:]
            loading = []
        }
        guard images[person.id] == nil, !loading.contains(person.id) else { return }
        loading.insert(person.id)
        let id = recording.id, file = URL(fileURLWithPath: recording.filePath)
        Task { @MainActor in
            let crop = await Task.detached { await Self.crop(file: file, time: person.keyTime, box: person.keyBox) }.value
            guard self.recordingID == id else { return }
            self.loading.remove(person.id)
            if let crop { self.images[person.id] = crop }
        }
    }

    /// The face at `time`, padded to a square 1.6 times its box (research-people.md 1.7: revision 4's boxes are tight).
    /// Recognition's crops use a wider pad, so Apple's analyzer sees the whole head (v2 part M7b).
    nonisolated static func crop(file: URL, time: Double, box: FaceBox, pad: Double = 1.6) async -> CGImage? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image else { return nil }
        let width = Double(frame.width), height = Double(frame.height)
        let side = max(box.width * width, box.height * height) * pad
        let cx = box.centerX * width, cy = box.centerY * height
        let rect = CGRect(x: max(0, cx - side / 2), y: max(0, cy - side / 2), width: side, height: side)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height)).integral
        return frame.cropping(to: rect)
    }

    /// A soft two-color square, different per row: never a face.
    nonisolated static func testPattern(seed: Int) -> CGImage? {
        let size = 96
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let hues: [(CGFloat, CGFloat, CGFloat)] = [(0.27, 0.35, 0.91), (0.86, 0.42, 0.04), (0.20, 0.60, 0.45), (0.55, 0.36, 0.70)]
        let (r, g, b) = hues[abs(seed) % hues.count]
        let colors = [CGColor(srgbRed: r, green: g, blue: b, alpha: 1), CGColor(srgbRed: r * 0.5, green: g * 0.5, blue: b * 0.5, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
        }
        return context.makeImage()
    }
}
