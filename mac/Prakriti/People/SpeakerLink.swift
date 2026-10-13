@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import Vision

// Linking faces to voices (v2 part M6b, docs/v2/PLAN.md M6, research-people.md 2.6). Apple has no active-speaker
// detection, so two kinds of evidence are added up per voice and per row of the People tab:
//
// - **The only face on screen.** Each half second a voice speaks while exactly one face is in the picture counts
//   for that face.
// - **The mouth moves with it.** On stretches with two or more faces at once, Vision's face landmarks at 10 frames a
//   second give each face's inner-lip opening (divided by the face's height); how much it moves is set against when
//   each voice speaks. A second's worth of a voice speaking while one face's mouth follows it, clearly better than
//   any other face's, counts for that face.
//
// A voice is linked to a row only when that row holds at least half of the evidence of the time the voice speaks
// with a face on screen, at least twice any other row's, and two seconds or more; each row takes one voice and each
// voice one row, the strongest first. Doubt leaves a voice unlinked: a voice with no face, which the privacy lock
// counts as someone unnamed until Ivan names it.
//
// Landmark points are face geometry, so they are measured here, in memory, and never kept: only the link (a voice
// number and a row number) leaves this file (research-people.md 5.1, Mac warning 112).

enum SpeakerLink {
    /// Landmarks are read this often on crowded stretches.
    static let mouthRate = 10.0
    /// Correlation of mouth movement with a voice that counts, and the margin over the next face.
    static let leastCorrelation = 0.2
    static let margin = 0.1
    /// The least evidence, in seconds, for a link.
    static let leastSeconds = 2.0

    struct Link: Equatable, Sendable {
        var face: Int
        var by: String
    }

    static let byOnlyFace = "the only face on screen"
    static let byMouth = "the mouth moves with it"

    /// A face's box at `time`: the nearest sighting of a track within half a second, or nil.
    static func box(of track: PeopleFile.Track, at time: Double) -> FaceBox? {
        guard time >= track.start - 0.5, time <= track.end + 0.5 else { return nil }
        var best: [Double]?
        var bestDistance = 0.5
        for b in track.boxes where b.count >= 5 {
            let d = abs(b[0] - time)
            if d <= bestDistance { best = b; bestDistance = d }
        }
        guard let best else { return nil }
        return FaceBox(x: best[1], y: best[2], width: best[3], height: best[4])
    }

    /// The faces at each sampled moment: row id (0 for a face seen once, which is no row) per sample time.
    static func presence(_ tracks: [PeopleFile.Track], every: Double) -> [Double: [Int]] {
        var out: [Double: [Int]] = [:]
        for track in tracks {
            for b in track.boxes where !b.isEmpty {
                let t = (b[0] / every).rounded() * every
                out[t, default: []].append(track.person ?? 0)
            }
        }
        return out
    }

    /// The stretches with two or more faces at once, padded by a quarter second and joined across a second.
    static func crowdedStretches(_ tracks: [PeopleFile.Track], every: Double) -> [(Double, Double)] {
        let times = presence(tracks, every: every).filter { $0.value.count >= 2 }.keys.sorted()
        var out: [(Double, Double)] = []
        for t in times {
            if let last = out.last, t - last.1 <= 1.0 { out[out.count - 1].1 = t + every } else { out.append((t, t + every)) }
        }
        return out.map { (max(0, $0.0 - 0.25), $0.1 + 0.25) }
    }

    /// One face's mouth on a crowded stretch: times and inner-lip opening over face height.
    typealias Mouths = [Int: [(time: Double, opening: Double)]]

    /// The links, from the face tracks, the voices' segments and the mouths measured on crowded stretches. Pure.
    static func link(tracks: [PeopleFile.Track], segments: [VoiceSegment], voices: [Int], mouths: Mouths, every: Double) -> [Int: Link] {
        let presence = presence(tracks, every: every)
        var sole: [Int: [Int: Double]] = [:]
        var withFace: [Int: Double] = [:]
        let byVoice = Dictionary(grouping: segments, by: \.voice)
        for (time, rows) in presence {
            for voice in voices where VoiceTimeline.speaks(byVoice[voice] ?? [], at: time) {
                withFace[voice, default: 0] += every
                if rows.count == 1, let row = rows.first, row != 0 { sole[voice, default: [:]][row, default: 0] += every }
            }
        }
        // Mouth movement: how much the opening changes, over half a second, against each voice speaking.
        var mouth: [Int: [Int: Double]] = [:]
        let step = 1 / mouthRate
        var movement: [Int: [Double: Double]] = [:]
        for (row, series) in mouths where row != 0 {
            let sorted = series.sorted { $0.time < $1.time }
            var raw: [(Double, Double)] = []
            for i in 1..<max(1, sorted.count) where sorted[i].time - sorted[i - 1].time <= step * 1.6 {
                raw.append((sorted[i].time, abs(sorted[i].opening - sorted[i - 1].opening)))
            }
            var smoothed: [Double: Double] = [:]
            for (i, point) in raw.enumerated() {
                let window = raw[max(0, i - 2)...min(raw.count - 1, i + 2)].filter { abs($0.0 - point.0) <= 0.3 }
                smoothed[(point.0 * mouthRate).rounded() / mouthRate] = window.map(\.1).reduce(0, +) / Double(max(1, window.count))
            }
            movement[row] = smoothed
        }
        for voice in voices {
            let own = byVoice[voice] ?? []
            var correlation: [Int: Double] = [:]
            for (row, series) in movement {
                let times = series.keys.sorted()
                guard times.count >= 10 else { continue }
                let x = times.map { series[$0]! }
                let y = times.map { VoiceTimeline.speaks(own, at: $0) ? 1.0 : 0.0 }
                correlation[row] = pearson(x, y)
            }
            let ranked = correlation.sorted { $0.value > $1.value }
            guard let best = ranked.first, best.value >= leastCorrelation else { continue }
            if ranked.count > 1, best.value - ranked[1].value < margin { continue }
            // The seconds the voice speaks while the best face is measured.
            let seconds = Double((movement[best.key] ?? [:]).keys.filter { VoiceTimeline.speaks(own, at: $0) }.count) * step
            mouth[voice, default: [:]][best.key, default: 0] += seconds
        }
        // Each voice's evidence per row; then the strongest links first, one to one.
        var candidates: [(voice: Int, face: Int, evidence: Double, by: String)] = []
        for voice in voices {
            var total: [Int: Double] = [:]
            for (row, s) in sole[voice] ?? [:] { total[row, default: 0] += s }
            for (row, s) in mouth[voice] ?? [:] { total[row, default: 0] += s }
            let ranked = total.sorted { $0.value > $1.value }
            guard let best = ranked.first else { continue }
            let second = ranked.count > 1 ? ranked[1].value : 0
            let speaking = max(withFace[voice] ?? 0, best.value)
            guard best.value >= leastSeconds, best.value >= 0.5 * speaking, best.value >= 2 * second else { continue }
            let byMouthMore = (mouth[voice]?[best.key] ?? 0) > (sole[voice]?[best.key] ?? 0)
            candidates.append((voice, best.key, best.value, byMouthMore ? byMouth : byOnlyFace))
        }
        var links: [Int: Link] = [:]
        var taken = Set<Int>()
        for c in candidates.sorted(by: { $0.evidence > $1.evidence }) where !taken.contains(c.face) {
            links[c.voice] = Link(face: c.face, by: c.by)
            taken.insert(c.face)
        }
        return links
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let n = Double(x.count)
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for i in x.indices {
            let dx = x[i] - mx, dy = y[i] - my
            sxy += dx * dy; sxx += dx * dx; syy += dy * dy
        }
        guard sxx > 0, syy > 0 else { return 0 }
        return sxy / (sxx * syy).squareRoot()
    }

    /// The mouths of every row on the crowded stretches, read from the original at 10 frames a second with Vision's
    /// face landmarks. Each face Vision finds is matched to the row whose box is nearest (within one face width).
    /// Nothing is kept but the opening, a number per face per frame, and it is gone when the step ends.
    static func measureMouths(file: URL, stretches: [(Double, Double)], tracks: [PeopleFile.Track],
                              control: ProcessControl? = nil, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Mouths {
        guard !stretches.isEmpty else { return [:] }
        let asset = AVURLAsset(url: file)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return [:] }
        let size = try await track.load(.naturalSize)
        let height = abs(size.height)
        let scale = height > CGFloat(FaceScan.analysisHeight) ? CGFloat(FaceScan.analysisHeight) / height : 1
        let request = DetectFaceLandmarksRequest()
        let rowTracks = tracks.filter { $0.person != nil }
        let total = stretches.map { $0.1 - $0.0 }.reduce(0, +)
        var done = 0.0
        var mouths: Mouths = [:]
        for (start, end) in stretches {
            try Task.checkCancellation()
            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                           end: CMTime(seconds: end, preferredTimescale: 600))
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            ])
            let provider = reader.outputProvider(for: output)
            try reader.start()
            var next = start
            while let buffer = try await provider.next() {
                try Task.checkCancellation()
                await control?.waitWhilePaused()
                let time = buffer.presentationTimeStamp.seconds
                guard time.isFinite, time + 0.0001 >= next else { continue }
                next = time + 1 / mouthRate
                let image: CIImage? = buffer.withUnsafeSampleBuffer { sample in
                    guard let pixels = CMSampleBufferGetImageBuffer(sample) else { return nil }
                    let image = CIImage(cvPixelBuffer: pixels)
                    return scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
                }
                guard let image else { continue }
                let faces = (try? await request.perform(on: image)) ?? []
                for face in faces {
                    guard let lips = face.landmarks?.innerLips else { continue }
                    let points = lips.pointsInImageCoordinates(CGSize(width: 1, height: 1), origin: .upperLeft)
                    guard let top = points.map(\.y).min(), let bottom = points.map(\.y).max() else { continue }
                    let box = FaceGeometry.fromVision(face.boundingBox.cgRect)
                    guard box.height > 0 else { continue }
                    // The row whose box at this moment is nearest, within one face width.
                    var nearest: (row: Int, distance: Double)?
                    for t in rowTracks {
                        guard let other = SpeakerLink.box(of: t, at: time), let row = t.person else { continue }
                        let d = FaceGeometry.centerDistance(box, other)
                        if d <= max(box.width, other.width), d < (nearest?.distance ?? .infinity) { nearest = (row, d) }
                    }
                    if let nearest { mouths[nearest.row, default: []].append((time, Double(bottom - top) / box.height)) }
                }
                if total > 0 { progress(min(1, (done + (time - start)) / total)) }
            }
            done += end - start
        }
        progress(1)
        return mouths
    }
}
