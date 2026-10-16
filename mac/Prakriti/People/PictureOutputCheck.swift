@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import Foundation
import Vision

// The picture output check (v2 part M8d, docs/v2/PLAN.md M8, research-people.md 3.6 item 1): after the edited video is made,
// its faces are found again, five frames a second, in the made file itself, and each must be someone Ivan included. A face
// that sits where Prakriti hid someone, or that no track of the people check accounts for, stops the video: "A face Prakriti
// cannot account for at 12:41. Hide it or include the person, then Make Again." It runs inside `OutputGate`, so a video that
// fails it is deleted where it was made and never reaches the Video folder.
//
// How a face found in the MP4 is accounted for, at the moment of the original the plan maps there:
// 1. Inside a region the video hid at that frame (`HiddenFaces`): a hidden face Vision can still see. A finding.
// 2. Otherwise, the people check's track nearest to it (its box at that moment, moved between sightings no more than 1 s
//    apart, or the nearest sighting within 1 s), if the face's middle is inside that box padded 2.5 times. When that track
//    belongs to someone included, the face is accounted for; when it belongs to someone hidden, it is a finding.
// 3. No track near it: a face the people check never saw. A finding (fail closed).
// It runs only when someone is hidden in the video: with everyone included every face is shown as recorded, as Ivan chose
// (Ivan, 12 Oct: all participants signed releases), and there is nothing to prove.
//
// Nothing is kept: frames are read, looked at and dropped; the result is times, boxes and counts. Files under `People/`
// never reach the network (RulesTests).

/// What the picture output check found: times, boxes and counts, never a picture.
struct PictureCheck: Codable, Equatable, Sendable {
    struct Finding: Codable, Equatable, Sendable {
        /// Where in the video, in seconds of the edited clock, and the moment of the original it shows.
        var at: Double
        var original: Double
        var box: FaceBox
        /// "hidden" (inside a region the video hid), "near hidden" (where a hidden person is), "unknown" (no track near it).
        var how: String
    }

    var checkedAt: Date
    /// Frames looked at, faces Vision found in them, and how they were accounted for.
    var frames = 0
    var faces = 0
    var included = 0
    var findings: [Finding] = []
    var seconds: Double = 0

    var passed: Bool { findings.isEmpty }

    /// One plain sentence for the step, the checklist and the inspector. No name.
    var line: String {
        guard let first = findings.first else {
            return "Seen again: every face in the video, \(Format.count(faces, "sighting")) in \(Format.count(frames, "frame")) looked at, is someone you included."
        }
        let more = findings.count > 1 ? " \(Format.count(findings.count - 1, "more moment")) too." : ""
        return "A face Prakriti cannot account for at \(Format.timecode(first.at)). Hide it or include the person, then Make Again." + more
    }
}

enum PictureOutputCheck {
    /// Frames looked at a second (research-people.md 3.6: 5).
    static let rate = 5.0
    /// How far a track's box reaches around it, and how far in time a sighting counts.
    static let reach = 2.5
    static let within = 1.0

    /// A track of the people check as the check reads it: its sightings and whether its person is hidden in the video.
    struct Track: Sendable {
        var id: Int
        var hidden: Bool
        var spots: [HiddenTrack.Spot]

        /// The track's box at `time`: moved in a straight line between two sightings no more than `within` apart, else the
        /// nearest sighting within `within`, else nil.
        func box(at time: Double) -> FaceBox? {
            let index = spots.firstIndex { $0.time > time }
            let before = index.map { $0 > 0 ? spots[$0 - 1] : nil } ?? spots.last
            let after = index.map { spots[$0] }
            if let before, let after, after.time - before.time <= PictureOutputCheck.within {
                let t = (time - before.time) / max(0.001, after.time - before.time)
                let a = before.box, b = after.box
                return FaceBox(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, width: a.width + (b.width - a.width) * t,
                               height: a.height + (b.height - a.height) * t)
            }
            let nearest = [before, after].compactMap { $0 }.min { abs($0.time - time) < abs($1.time - time) }
            guard let nearest, abs(nearest.time - time) <= PictureOutputCheck.within else { return nil }
            return nearest.box
        }
    }

    /// The people file's tracks, each marked hidden or not by `hidden` (asked about each track's row; nil for a glimpse).
    static func tracks(_ file: PeopleFile, hidden: (Int?) -> Bool) -> [Track] {
        file.tracks.map { track in
            Track(id: track.id, hidden: hidden(track.person), spots: track.boxes.compactMap { box in
                box.count >= 5 ? HiddenTrack.Spot(time: box[0], box: FaceBox(x: box[1], y: box[2], width: box[3], height: box[4])) : nil
            }.sorted { $0.time < $1.time })
        }
    }

    /// How one face found at the original's moment `original` is accounted for: nil when it is someone included, else the
    /// finding's kind. Pure, so the tests drive it with made-up boxes.
    static func account(_ face: FaceBox, original: Double, regions: [FaceBox], tracks: [Track]) -> String? {
        if regions.contains(where: { FaceHide.covers($0, x: face.centerX, y: face.centerY) }) { return "hidden" }
        var best: (track: Track, distance: Double)?
        for track in tracks {
            guard let box = track.box(at: original),
                  FaceGeometry.padded(box, by: reach).contains(x: face.centerX, y: face.centerY) else { continue }
            let dx = (face.centerX - box.centerX) / max(box.width, 0.001), dy = (face.centerY - box.centerY) / max(box.height, 0.001)
            let distance = dx * dx + dy * dy
            if distance < (best?.distance ?? .infinity) { best = (track, distance) }
        }
        guard let best else { return "unknown" }
        return best.track.hidden ? "near hidden" : nil
    }

    /// Looks at the made video `mp4` five frames a second. `timeline` maps its clock to the original's; `hidden` holds the
    /// regions the video hid; `tracks` are the people check's.
    static func run(mp4: URL, timeline: EditTimeline, hidden: HiddenFaces, tracks: [Track], framing: Framing = Framing(), now: Date,
                    rate: Double = PictureOutputCheck.rate, control: ProcessControl? = nil, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> PictureCheck {
        let started = ContinuousClock.now
        var check = PictureCheck(checkedAt: now)
        let table = hidden.table()
        let asset = AVURLAsset(url: mp4)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoHiding.Failure(reason: "The made video has no picture to check.")
        }
        let size = try await track.load(.naturalSize)
        let height = abs(size.height)
        let scale = height > CGFloat(FaceScan.analysisHeight) ? CGFloat(FaceScan.analysisHeight) / height : 1
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        // `outputProvider(for:)` adds the output itself (research-people.md 1.7).
        let provider = reader.outputProvider(for: output)
        try reader.start()
        let detect = DetectFaceRectanglesRequest(.revision4)
        var next = 0.0
        var warmed = false
        let duration = timeline.duration
        while let buffer = try await provider.next() {
            try Task.checkCancellation()
            await control?.waitWhilePaused()
            let time = buffer.presentationTimeStamp.seconds
            guard time.isFinite, time + 0.0001 >= next else { continue }
            next += 1 / rate
            let image: CIImage? = buffer.withUnsafeSampleBuffer { sample in
                guard let pixels = CMSampleBufferGetImageBuffer(sample) else { return nil }
                let image = CIImage(cvPixelBuffer: pixels)
                return scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
            }
            guard let image, let original = timeline.originalTime(time) else { continue }
            if !warmed {
                _ = try? await detect.perform(on: image)
                warmed = true
            }
            // A face found in a punched-in frame is put back on the original's picture (v2 part M9a), where the people
            // check's boxes and the hidden regions are.
            let crop = framing.rect(atEditFrame: Int64((time / timeline.frame.seconds).rounded()))
            let faces = try await detect.perform(on: image).map { Framing.toSource(FaceGeometry.fromVision($0.boundingBox.cgRect), through: crop) }
            check.frames += 1
            let sourceFrame = Int64((original / timeline.frame.seconds).rounded())
            let regions = table.regions(atSourceFrame: sourceFrame)
            for face in faces {
                check.faces += 1
                if let how = account(face, original: original, regions: regions, tracks: tracks) {
                    check.findings.append(.init(at: PeopleFile.round(time), original: PeopleFile.round(original), box: face, how: how))
                } else {
                    check.included += 1
                }
            }
            if duration > 0 { progress(min(1, time / duration)) }
        }
        if reader.status == .failed {
            throw VideoHiding.Failure(reason: "The made video stopped part way while its faces were checked: \(reader.error?.localizedDescription ?? "it could not be read to its end").")
        }
        let elapsed = ContinuousClock.now - started
        check.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        progress(1)
        return check
    }
}
