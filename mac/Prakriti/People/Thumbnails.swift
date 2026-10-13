@preconcurrency import AVFoundation
import CoreImage
import Foundation
import ImageIO
import Vision

// The card picture (v2 part M6d, docs/v2/PLAN.md M6, design spec 3.1.2): the frame a recording's card shows, chosen by
// the people pass and never written before it, in this order:
//
// 1. The sharpest frame in which every face found is someone Ivan included, a named person first (Vision's face capture
//    quality decides "sharpest").
// 2. Otherwise, the best frame with every other face hidden by `FaceHide`, the same hiding the video will use (M8d).
// 3. Otherwise, nothing: the card keeps its plain tile (the date and the kind of recording).
//
// **Every frame is checked before it is kept:** Vision looks for faces in the finished picture, and every face it finds
// must sit inside the box of someone included at that moment. A face inside a hidden region, or a face the people pass
// did not account for, rejects the frame, and the next is tried. So no picture is written with a face of anyone Ivan did
// not include (Ivan, Mon 12 Oct: "Faces of anyone not Included are never in a thumbnail").
//
// The picture is written to `<Application Support>/Thumbnails/<recording id>.jpg`, through a job folder (Mac warning 113),
// and is the only picture Prakriti keeps (PLAN M6 check 7). It is never written into a watched folder (Mac warning 12).

enum CardPicture {
    /// The picture's width in pixels (a card is at most 360 pt wide, so 720 px on a Retina screen; 1280 leaves room).
    static let width = 1280.0
    /// How many moments of each kind are looked at, spread through the recording.
    static let tries = 8
    /// Seconds left out at the start and the end (a recording often starts and ends on a black frame or a fade).
    static let edge = 2.0
    /// Seconds left out around a change of picture.
    static let nearCut = 1.0

    enum Rule: String, Codable, Sendable {
        /// Every face in the frame is someone included (design spec 3.1.2 rule 1).
        case everyoneIncluded
        /// Every other face hidden (rule 2).
        case othersHidden
    }

    /// What was kept: when, by which rule, how many faces are hidden in it and how many are seen.
    struct Made: Codable, Equatable, Sendable {
        var time: Double
        var rule: Rule
        var hidden: Int
        var faces: Int
        var madeAt: Date
    }

    struct Outcome: Sendable {
        var made: Made?
        /// Moments looked at, and how many of them a check refused.
        var tried = 0
        var refused = 0
        var seconds = 0.0

        /// The log's line: what was kept and why, never a name.
        var line: String {
            guard let made else {
                return tried == 0 ? "Card picture: no frame to choose from, so the card keeps its plain tile."
                    : "Card picture: none of the \(Format.count(tried, "frame")) looked at could be made safe, so the card keeps its plain tile."
            }
            let refusedNote = refused == 0 ? "" : " \(Format.count(refused, "frame")) refused by the check."
            switch made.rule {
            case .everyoneIncluded:
                return "Card picture: the frame at \(Format.timecode(made.time)), where everyone seen is included.\(refusedNote)"
            case .othersHidden:
                return "Card picture: the frame at \(Format.timecode(made.time)), with \(Format.count(made.hidden, "face")) hidden.\(refusedNote)"
            }
        }
    }

    /// One sampled moment of the people file: the faces seen in it, by track.
    struct Moment: Equatable, Sendable {
        struct Face: Equatable, Sendable {
            var track: Int
            var row: Int?
            var box: FaceBox
            var confidence: Double
        }

        var time: Double
        var faces: [Face]
    }

    /// Every sampled moment with a face, from the people file, in time order.
    static func moments(_ file: PeopleFile) -> [Moment] {
        var byTime: [Int: Moment] = [:]
        for track in file.tracks {
            for box in track.boxes where box.count >= 5 {
                let key = Int((box[0] * 1000).rounded())
                var moment = byTime[key] ?? Moment(time: box[0], faces: [])
                moment.faces.append(.init(track: track.id, row: track.person, box: FaceBox(x: box[1], y: box[2], width: box[3], height: box[4]),
                                          confidence: box.count >= 6 ? box[5] : 1))
                byTime[key] = moment
            }
        }
        return byTime.values.sorted { $0.time < $1.time }
    }

    /// The moments to look at for each rule, already spread through the recording, a named person first. Pure.
    /// `within` keeps only the moments in a stretch of the recording (the acceptance uses it to look where someone is hidden).
    static func candidates(_ file: PeopleFile, plan: HidePlan, namedRows: Set<Int>, within: ClosedRange<Double>? = nil) -> (included: [Double], hidden: [Double]) {
        guard file.hasPicture, file.duration > 0 else { return ([], []) }
        let duration = file.duration
        let margin = duration > edge * 4 ? edge : 0
        func usable(_ time: Double) -> Bool {
            time >= margin && time <= duration - margin && !file.cuts.contains { abs($0 - time) < nearCut } && (within?.contains(time) ?? true)
        }
        let hiddenTracks = Set(plan.tracks.map(\.id))
        let all = moments(file).filter { usable($0.time) && !$0.faces.isEmpty }
        if file.tracks.isEmpty {
            // No face in the whole recording: any frame is safe as far as the people pass can tell, and the check below
            // still looks at it.
            return ([0.3, 0.5, 0.7, 0.2, 0.8].map { duration * $0 }.filter(usable), [])
        }
        let included = all.filter { moment in moment.faces.allSatisfy { !hiddenTracks.contains($0.track) } && plan.active(at: moment.time).isEmpty }
        let includedTimes = Set(included.map(\.time))
        let others = all.filter { !includedTimes.contains($0.time) }
        func spread(_ moments: [Moment]) -> [Double] {
            let named = moments.filter { $0.faces.contains { $0.row.map(namedRows.contains) ?? false } }
            let pool = named.isEmpty ? moments : named
            guard pool.count > tries else { return pool.map(\.time) }
            return (0..<tries).map { i in pool[Int((Double(i) + 0.5) * Double(pool.count) / Double(tries))].time }
        }
        // Rule 2 looks first where someone is included, so the picture is of someone.
        let withSomeone = others.filter { $0.faces.contains { !hiddenTracks.contains($0.track) } }
        return (spread(included), spread(withSomeone.isEmpty ? others : withSomeone))
    }

    /// Whether every face Vision found in the finished picture is accounted for: inside the box of someone included at
    /// that moment (padded as a hidden region is), and not inside a hidden region. Pure.
    static func accounted(found: [FaceBox], included: [FaceBox], hidden: [FaceBox]) -> Bool {
        found.allSatisfy { face in
            !hidden.contains { FaceHide.covers($0, x: face.centerX, y: face.centerY) }
                && included.contains { FaceGeometry.padded($0, by: FaceHide.pad).contains(x: face.centerX, y: face.centerY) }
        }
    }

    /// Chooses, checks and writes the card picture of one recording. Returns what was kept, or nothing (the plain tile);
    /// the old picture is deleted first either way, so a picture made under older choices never stays.
    static func make(original: URL, recordingID: UUID, people: PeopleFile, plan: HidePlan, namedRows: Set<Int>,
                     folders: PeopleFolders, now: Date, within: ClosedRange<Double>? = nil) async throws -> Outcome {
        let started = ContinuousClock.now
        folders.removeThumbnail(for: recordingID)
        var outcome = Outcome()
        let (included, hidden) = candidates(people, plan: plan, namedRows: namedRows, within: within)
        guard !(included.isEmpty && hidden.isEmpty) else { return outcome }
        let asset = AVURLAsset(url: original)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else { return outcome }
        let transform = try await video.load(.preferredTransform)
        let generator = AVAssetImageGenerator(asset: asset)
        // The frame as decoded, the way the face step read it, so the boxes line up; turned upright only at the end.
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let context = CIContext(options: [.cacheIntermediates: false])
        let moments = Dictionary(self.moments(people).map { (Int(($0.time * 1000).rounded()), $0) }, uniquingKeysWith: { a, _ in a })
        let hiddenTracks = Set(plan.tracks.map(\.id))

        for (rule, times) in [(Rule.everyoneIncluded, included), (.othersHidden, hidden)] where !times.isEmpty {
            var best: (score: Double, made: Made, picture: CIImage)?
            for time in times {
                try Task.checkCancellation()
                outcome.tried += 1
                guard let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image else { continue }
                let regions = rule == .everyoneIncluded ? [] : try await FaceFollower.frame(file: original, plan: plan, at: time).regions
                var picture = FaceHide.apply(CIImage(cgImage: frame), regions: regions)
                let scale = min(1, width / picture.extent.width)
                picture = picture.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                guard let rendered = context.createCGImage(picture, from: picture.extent) else { continue }
                // The check: every face in the finished picture is someone included at this moment.
                let faces = try await DetectFaceRectanglesRequest(.revision4).perform(on: rendered)
                let seen = faces.map { FaceGeometry.fromVision($0.boundingBox.cgRect) }
                let here = moments[Int((time * 1000).rounded())]?.faces ?? []
                let includedFaces = here.filter { !hiddenTracks.contains($0.track) }
                guard accounted(found: seen, included: includedFaces.map(\.box), hidden: regions) else {
                    outcome.refused += 1
                    continue
                }
                var score = 0.0
                if !faces.isEmpty {
                    var quality = DetectFaceCaptureQualityRequest()
                    quality.inputFaceObservations = faces
                    let measured = (try? await quality.perform(on: rendered)) ?? []
                    for face in measured {
                        let box = FaceGeometry.fromVision(face.boundingBox.cgRect)
                        let named = includedFaces.contains { ($0.row.map(namedRows.contains) ?? false)
                            && FaceGeometry.padded($0.box, by: FaceHide.pad).contains(x: box.centerX, y: box.centerY) }
                        score = max(score, Double(face.captureQuality?.score ?? 0) + (named ? 1 : 0))
                    }
                }
                let made = Made(time: time, rule: rule, hidden: here.filter { hiddenTracks.contains($0.track) }.count, faces: seen.count, madeAt: now)
                if best == nil || score > best!.score { best = (score, made, CIImage(cgImage: rendered)) }
            }
            if let best {
                let upright = best.picture.oriented(orientation(of: transform))
                // The job folder is made only now, for the moment the picture is staged, never for the minutes of looking
                // before it (v2 part M6d fix, 13 Oct): made at the start, a run ended mid-look (a test process finishing
                // while this ran in the background, or a quit) left an empty one in Jobs, and the next people check failed on it.
                let job = try folders.newJob()
                defer { try? FileManager.default.removeItem(at: job) }
                let staged = job.appending(path: recordingID.uuidString + ".jpg")
                guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { break }
                try context.writeJPEGRepresentation(of: upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX, y: -upright.extent.minY)),
                                                    to: staged, colorSpace: space,
                                                    options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.85])
                try FileManager.default.createDirectory(at: folders.thumbnails, withIntermediateDirectories: true)
                let target = folders.thumbnail(for: recordingID)
                if FileManager.default.fileExists(atPath: target.path) {
                    _ = try FileManager.default.replaceItemAt(target, withItemAt: staged)
                } else {
                    try FileManager.default.moveItem(at: staged, to: target)
                }
                outcome.made = best.made
                break
            }
        }
        let elapsed = ContinuousClock.now - started
        outcome.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return outcome
    }

    /// The way up of a track's preferred transform, for a recording made on its side (a phone held upright).
    static func orientation(of transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a.rounded(), transform.b.rounded(), transform.c.rounded(), transform.d.rounded()) {
        case (0, 1, -1, 0): .right
        case (0, -1, 1, 0): .left
        case (-1, 0, 0, -1): .down
        default: .up
        }
    }
}

extension FaceBox {
    /// Whether a point (0 to 1 from the top left) lies inside the box.
    func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px <= x + width && py >= y && py <= y + height
    }
}

extension PeopleFolders {
    /// The card pictures (design spec 3.1.2): the only pictures Prakriti keeps.
    var thumbnails: URL { support.appending(path: "Thumbnails", directoryHint: .isDirectory) }

    func thumbnail(for recordingID: UUID) -> URL {
        thumbnails.appending(path: recordingID.uuidString + ".jpg")
    }

    func removeThumbnail(for recordingID: UUID) {
        try? FileManager.default.removeItem(at: thumbnail(for: recordingID))
    }
}
