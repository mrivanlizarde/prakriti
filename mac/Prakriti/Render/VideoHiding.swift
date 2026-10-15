@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import Foundation
import Vision

// The faces hidden in the edited video (v2 part M8d, docs/v2/PLAN.md M8, research-people.md 3.2): for every frame of the
// original the video keeps, the regions to hide, worked out once before the video is drawn and then read by the compositor
// for the file and for the Viewer alike, so the preview hides exactly what the file hides.
//
// Why worked out first, and not inside the compositor: the compositor is asked for frames out of order (the Viewer seeks,
// the writer may ask ahead), while following a face between the face step's sightings (two a second) needs the frames in
// order, from the sighting before (`FaceFollower`, part M6d). So the original is read once, in order, over every stretch
// where a hidden face may be on screen, and Vision's `TrackObjectRequest` follows each hidden face at the full frame rate,
// started again from every sighting, with the same rules as `FaceFollower.frame`: each sighting's box held 0.5 s before and
// after it, the followed box between sightings, and when the follower loses a face the last place it was seen stays hidden
// with the head of any body there (unknown means hidden).
//
// What is kept: `video-hiding.json` in the recording's output folder, beside `edit-plan.json` (boxes and frame numbers only:
// never a picture, a print or a landmark), so the Viewer can draw the video the way it was made. Nothing here reaches the
// network (RulesTests).

/// The regions hidden in each kept frame of the original, for one made video.
struct HiddenFaces: Codable, Equatable, Sendable {
    static let fileName = "video-hiding.json"

    var version = 1
    /// The original's frame, as the plan counts it.
    var frame: FrameDuration
    /// The plan the video was made from (`EditPlan.madeAt`), so the Viewer never draws a newer plan with older hiding.
    var planMadeAt: Date
    /// The people file's tracks that are hidden.
    var tracks: [Int]
    /// One row per frame with something hidden: the frame number on the original's clock, then four numbers a region (x, y,
    /// width and height, from the top left, as fractions of the picture), rounded to 4 places.
    var frames: [[Double]]
    /// How each region was found, counted ("held", "followed", "lost", "body"), for the log and the BUILD-LOG.
    var how: [String: Int] = [:]
    var seconds: Double = 0

    var isEmpty: Bool { tracks.isEmpty }

    /// The rows by frame, for the compositor.
    func table() -> Table {
        var byFrame: [Int64: [FaceBox]] = [:]
        for row in frames where row.count >= 5 {
            var boxes: [FaceBox] = []
            var i = 1
            while i + 3 < row.count {
                boxes.append(FaceBox(x: row[i], y: row[i + 1], width: row[i + 2], height: row[i + 3]))
                i += 4
            }
            byFrame[Int64(row[0])] = boxes
        }
        return Table(byFrame: byFrame)
    }

    /// The regions of every frame, held for the compositor's life (a class, so every instruction shares one).
    final class Table: @unchecked Sendable {
        let byFrame: [Int64: [FaceBox]]
        init(byFrame: [Int64: [FaceBox]]) { self.byFrame = byFrame }
        func regions(atSourceFrame frame: Int64) -> [FaceBox] { byFrame[frame] ?? [] }
        var count: Int { byFrame.count }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func write(into folder: URL) throws {
        try Self.encoder.encode(self).write(to: folder.appending(path: Self.fileName), options: .atomic)
    }

    static func read(folder: URL) -> HiddenFaces? {
        guard let data = try? Data(contentsOf: folder.appending(path: fileName)) else { return nil }
        return try? decoder.decode(HiddenFaces.self, from: data)
    }
}

enum VideoHiding {
    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// The hide plan for the video: the people file's tracks whose row Ivan set to Hide Face or Leave Out for the video (a
    /// row of nil is the faces seen for under a second, `PersonKey.face(0)`).
    static func plan(_ file: PeopleFile, names: (faces: [Int: UUID], voices: [Int: UUID]), choices: PeopleChoices) -> HidePlan {
        HidePlan.from(file) { row in choices.choice(PersonKey.face(row ?? 0, names: names), for: .video) != .include }
    }

    /// The regions to hide in every frame `timeline` keeps, for `plan`, reading `original` once in order. `progress` gets 0
    /// to 1 over the stretches read. Empty (and nothing read) when nobody is hidden.
    static func make(original: URL, plan: HidePlan, timeline: EditTimeline, planMadeAt: Date, control: ProcessControl? = nil,
                     progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> HiddenFaces {
        let started = ContinuousClock.now
        var result = HiddenFaces(frame: timeline.frame, planMadeAt: planMadeAt, tracks: plan.tracks.map(\.id).sorted(), frames: [])
        guard !plan.isEmpty else { return result }
        let frameSeconds = timeline.frame.seconds
        func kept(_ frame: Int64) -> Bool {
            timeline.pieces.contains { frame >= $0.sourceFrame && frame < $0.sourceFrame + $0.frames }
        }

        // The stretches where a hidden face may be on screen, merged, each kept only when the video keeps a frame of it.
        var stretches: [(Double, Double)] = []
        for track in plan.tracks.sorted(by: { $0.start < $1.start }) {
            let from = max(0, track.start - HidePlan.hold), to = track.end + HidePlan.hold
            if let last = stretches.last, from <= last.1 + 1 { stretches[stretches.count - 1].1 = max(last.1, to) } else { stretches.append((from, to)) }
        }
        stretches = stretches.filter { stretch in
            timeline.pieces.contains { piece in
                let a = timeline.seconds(piece.sourceFrame), b = timeline.seconds(piece.sourceFrame + piece.frames)
                return a < stretch.1 && b > stretch.0
            }
        }
        let total = stretches.reduce(0) { $0 + ($1.1 - $1.0) }
        var done = 0.0

        let asset = AVURLAsset(url: original)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The original has no picture, so no face could be hidden in it.")
        }
        let size = try await videoTrack.load(.naturalSize)
        let height = abs(size.height)
        let scale = height > CGFloat(FaceFollower.analysisHeight) ? CGFloat(FaceFollower.analysisHeight) / height : 1
        var rows: [[Double]] = []

        for stretch in stretches {
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch {
                throw Failure(reason: "The original could not be read to hide faces: \(error.localizedDescription)")
            }
            reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, stretch.0 - 0.02), preferredTimescale: 600),
                                           end: CMTime(seconds: stretch.1 + 0.05, preferredTimescale: 600))
            let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            ])
            // `outputProvider(for:)` adds the output itself; `reader.add(output)` first would crash (research-people.md 1.7).
            let provider = reader.outputProvider(for: output)
            try reader.start()

            struct Following {
                var request: TrackObjectRequest?
                var box: FaceBox?
                var lost = false
            }
            var following: [Int: Following] = [:]
            while let buffer = try await provider.next() {
                try Task.checkCancellation()
                await control?.waitWhilePaused()
                let time = buffer.presentationTimeStamp.seconds
                guard time.isFinite else { continue }
                let frame = Int64((time / frameSeconds).rounded())
                let image: CIImage? = buffer.withUnsafeSampleBuffer { sample in
                    guard let pixels = CMSampleBufferGetImageBuffer(sample) else { return nil }
                    let image = CIImage(cvPixelBuffer: pixels)
                    return scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
                }
                guard let image else { continue }
                var regions: [FaceBox] = []
                var how: [String] = []
                for box in plan.held(at: time) {
                    regions.append(box)
                    how.append("held")
                }
                for track in plan.active(at: time) {
                    var state = following[track.id] ?? Following()
                    if let spot = track.spots.last(where: { abs($0.time - time) < 0.012 }) {
                        // A sighting on this very frame: start again from it (its box is already held above).
                        state.request = TrackObjectRequest(detectedObject: DetectedObjectObservation(boundingBox: NormalizedRect(normalizedRect: FaceGeometry.toVision(spot.box))))
                        state.box = spot.box
                        state.lost = false
                        following[track.id] = state
                        continue
                    }
                    guard let before = track.around(time).before, before.time < time - 0.001 else {
                        // Before the first sighting: only the held box (above) hides it.
                        following[track.id] = state
                        continue
                    }
                    if state.request == nil {
                        // Reached between sightings with no follower yet (a stretch read from its middle): start from the
                        // sighting before.
                        state.request = TrackObjectRequest(detectedObject: DetectedObjectObservation(boundingBox: NormalizedRect(normalizedRect: FaceGeometry.toVision(before.box))))
                        state.box = before.box
                    } else if let request = state.request, !state.lost {
                        if let seen = try? await request.perform(on: image), seen.confidence >= FaceFollower.lostConfidence {
                            state.box = FaceGeometry.fromVision(seen.boundingBox.cgRect)
                        } else {
                            state.lost = true
                        }
                    }
                    if let box = state.box {
                        regions.append(box)
                        how.append(state.lost ? "lost" : "followed")
                        if state.lost && kept(frame) {
                            for head in try await FaceFollower.heads(in: image, near: box) {
                                regions.append(head)
                                how.append("body")
                            }
                        }
                    }
                    following[track.id] = state
                }
                if !regions.isEmpty && kept(frame) {
                    rows.append([Double(frame)] + regions.flatMap { [$0.x, $0.y, $0.width, $0.height].map(PeopleFile.round) })
                    for word in how { result.how[word, default: 0] += 1 }
                }
                if total > 0 { progress(min(1, (done + max(0, time - stretch.0)) / total)) }
            }
            if reader.status == .failed {
                throw Failure(reason: "The original stopped part way while hiding faces: \(reader.error?.localizedDescription ?? "it could not be read to its end").")
            }
            done += stretch.1 - stretch.0
        }
        result.frames = rows.sorted { $0[0] < $1[0] }
        let elapsed = ContinuousClock.now - started
        result.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        progress(1)
        return result
    }
}
