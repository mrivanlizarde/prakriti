import Accelerate
import AVFoundation
import Foundation

// Where a short's picture comes from, and how it follows the speaker (v2 part M11a, docs/v2/PLAN.md M11; research-edit-engine.md
// 2.6 "Vertical" and E6):
//
// 1. **The vertical twin**, when the session has one (OBS's vertical canvas writes `<name>-vertical.mp4` beside the main file,
//    Help 03) and its sound lines up with the main recording's: cross-correlated at three moments, each within one frame of the
//    others (`TwinSync`). Its picture is already 1080 by 1920; a window of 1/1.25 of it follows the face (`twinZoom`), as
//    the crops do. It is a second camera, so its faces are found again on their own (`TwinFaces`, PLAN R20).
// 2. **A 4K source's crop**: a 9:16 window the full height of the picture (1215 by 2160), scaled down to 1080 by 1920: sharp.
// 3. **A 1080p crop** (608 by 1080, enlarged 1.78 times): soft, so the shorts say so in Checks (`Shorts.Record.warning`).
//
// The crop follows the speaker's face with a dead zone (research 2.6, the vault's face-lock method): the window moves only when
// the face leaves its middle third, then eases over to put the face back in the middle, so the frame does not drift with every
// nod. The window is kept inside the picture. The same follow drives the Viewer's 9:16 guide (`VerticalGuide`), so the guide
// shows the window the shorts will use.

enum VerticalCrop {
    /// 9 by 16.
    static let aspect = 9.0 / 16.0
    /// How fast the window eases to its new place: the time constant of the ease, in seconds (about 0.5 s to settle).
    static let settle = 0.16
    /// The vertical twin's reframe: a window 1/1.25 of its width and height, so the face can be kept in the middle third. Measured 16
    /// Oct on the 6 Sep twin: the face's middle ran from 0.26 to 0.69 across; used whole, 12% to 23% of frames had it outside the
    /// middle third; at 1.15 (research 2.6's limit for a punch-in on a 1080-wide picture) the window could move only 0.065 either way
    /// and one short planned 89.8%. 1.25 is still far sharper than a 1080p crop's 1.78, and Ivan judges it by eye.
    static let twinZoom = 1.25
    /// A face seen within this long of a moment counts for it; between two sightings no further apart, it is moved in a line.
    static let reach = 1.0
    /// How far ahead the window looks at the face: the whole short is known before it is drawn, so the window starts its ease a
    /// moment before the face would leave the middle third, instead of after (measured 16 Oct on the 6 Sep twin: following only
    /// behind, 88.2% of frames had the face in the middle third; the ease alone takes about half a second).
    static let lead = 0.3

    /// Where the short's picture comes from.
    enum Source: String, Codable, Sendable {
        case vertical
        case crop4K
        case crop1080

        var line: String {
            switch self {
            case .vertical: "the vertical recording"
            case .crop4K: "a crop of the 4K picture"
            case .crop1080: "a crop of the 1080p picture, enlarged"
            }
        }
    }

    /// The crop's width as a fraction of the picture's: the full height at 9:16 (1 when the picture is already that narrow).
    static func width(sourceWidth: Double, sourceHeight: Double) -> Double {
        guard sourceWidth > 0, sourceHeight > 0 else { return 1 }
        return min(1, sourceHeight * aspect / sourceWidth)
    }

    /// The source a crop of this picture is: 4K and up, or less.
    static func cropSource(sourceHeight: Double) -> Source { sourceHeight >= 2000 ? .crop4K : .crop1080 }

    /// The face's middle across the picture at `time`: between two sightings no more than `reach` apart it is moved in a line,
    /// else the nearest sighting within `reach`, else nil. `spots` sorted by time.
    static func faceX(_ spots: [FaceSpot], at time: Double) -> Double? {
        guard !spots.isEmpty else { return nil }
        var lo = 0, hi = spots.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if spots[mid].time <= time { lo = mid + 1 } else { hi = mid }
        }
        let before = lo > 0 ? spots[lo - 1] : nil
        let after = lo < spots.count ? spots[lo] : nil
        if let before, let after, after.time - before.time <= reach {
            let t = (time - before.time) / max(0.001, after.time - before.time)
            return before.box.centerX + (after.box.centerX - before.box.centerX) * t
        }
        let nearest = [before, after].compactMap { $0 }.min { abs($0.time - time) < abs($1.time - time) }
        guard let nearest, abs(nearest.time - time) <= reach else { return nil }
        return nearest.box.centerX
    }

    /// The window's middle across the picture at each step: `times` are the source moments shown, one a step, each step `step`
    /// seconds long. The window starts on the face (or the middle), stays put while the face is inside its middle third, and
    /// otherwise eases toward the face; it never shows past the picture's edge. Pure.
    static func follow(_ spots: [FaceSpot], times: [Double], width: Double, step: Double) -> [Double] {
        guard width < 0.9999 else { return times.map { _ in 0.5 } }
        let half = width / 2, third = width / 6
        func clamp(_ c: Double) -> Double { min(max(c, half), 1 - half) }
        var out: [Double] = []
        out.reserveCapacity(times.count)
        let first = times.lazy.compactMap { faceX(spots, at: $0) }.first ?? 0.5
        var center = clamp(first), target = center
        let k = 1 - exp(-max(step, 0.001) / settle)
        for time in times {
            if let face = faceX(spots, at: time + lead) ?? faceX(spots, at: time), abs(face - center) > third { target = clamp(face) }
            center = clamp(center + (target - center) * k)
            out.append(center)
        }
        return out
    }

    /// The crop as a `Framing` over the short's edited frames: one segment for each run of frames whose window is the same to the
    /// pixel (`sourceWidth` pixels across). Every frame has a segment, so the picture is always the 9:16 window.
    /// `height` below 1 (the twin's reframe) centres the window up and down.
    static func framing(centers: [Double], width: Double, height: Double = 1, sourceWidth: Double) -> Framing {
        guard width < 0.9999, !centers.isEmpty else { return Framing() }
        var segments: [Framing.Segment] = []
        func rect(_ c: Double) -> CGRect {
            // On whole pixels of the source, so a run of frames shares one window exactly.
            let x = ((c - width / 2) * sourceWidth).rounded() / sourceWidth
            return CGRect(x: min(max(0, x), 1 - width), y: (1 - height) / 2, width: width, height: height)
        }
        var start: Int64 = 0
        var current = rect(centers[0])
        for (i, c) in centers.enumerated().dropFirst() {
            let r = rect(c)
            if r != current {
                segments.append(Framing.Segment(start: start, frames: Int64(i) - start, rect: current, scale: 1 / width,
                                                center: CGPoint(x: current.midX, y: 0.5), easeFrames: 0))
                start = Int64(i)
                current = r
            }
        }
        segments.append(Framing.Segment(start: start, frames: Int64(centers.count) - start, rect: current, scale: 1 / width,
                                        center: CGPoint(x: current.midX, y: 0.5), easeFrames: 0))
        return Framing(segments: segments)
    }

    /// The share of `centers` whose face (from `spots` at `times`) sits inside the middle third of the window, of the frames with
    /// a face. For the log and the tests; the made file is measured by Vision in the acceptance.
    static func middleShare(_ spots: [FaceSpot], times: [Double], centers: [Double], width: Double) -> Double? {
        var inside = 0, counted = 0
        for (t, c) in zip(times, centers) {
            guard let x = faceX(spots, at: t) else { continue }
            counted += 1
            let u = (x - (c - width / 2)) / width
            if u >= 1.0 / 3.0 && u <= 2.0 / 3.0 { inside += 1 }
        }
        return counted == 0 ? nil : Double(inside) / Double(counted)
    }
}

/// The vertical twin and how its sound lines up with the main recording's (research-edit-engine.md E6).
enum TwinSync {
    /// Measured at a 4 kHz mono decode: plenty for a frame's 33 ms, and the search over seconds stays quick.
    static let rate = 4_000
    /// The sound compared at each moment, and how far either side the twin may sit.
    static let window = 8.0
    static let search = 5.0
    /// A clear match: the sound is the same sound (measured 16 Oct on the 6 Sep talk: 0.999 at three moments).
    static let leastCorrelation = 0.6

    /// The twin beside a recording: the same name with `-vertical` before the extension, any of the video types.
    static func twin(of original: URL) -> URL? {
        let base = original.deletingPathExtension().lastPathComponent
        let folder = original.deletingLastPathComponent()
        for ext in [original.pathExtension, "mp4", "mov", "MP4", "MOV"] where !ext.isEmpty {
            let candidate = folder.appending(path: base + "-vertical." + ext)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// What the measure found.
    struct Offset: Codable, Equatable, Sendable {
        /// Seconds the twin runs ahead of the main recording: the twin's moment of the main recording's `t` is `t + seconds`.
        var seconds: Double
        /// The same in whole frames, and what is left over (under half a frame).
        var frames: Int64
        /// Each moment's offset and its correlation (0 to 1).
        var points: [Double]
        var correlations: [Double]

        /// The three moments agree within one frame and each is a clear match.
        func lines(frame: Double) -> Bool {
            guard let lo = points.min(), let hi = points.max(), !points.isEmpty else { return false }
            return hi - lo <= frame + 1e-9 && correlations.allSatisfy { $0 >= TwinSync.leastCorrelation }
        }

        var line: String {
            String(format: "the vertical recording runs %.3f s %@ the main one (%lld frames), measured at %d moments, correlation %@",
                   abs(seconds), seconds >= 0 ? "ahead of" : "behind", frames, points.count,
                   correlations.map { String(format: "%.3f", $0) }.joined(separator: ", "))
        }
    }

    /// Measures the offset at three moments of the main recording (`at`, seconds). `decode` runs ffmpeg with the arguments given.
    /// Nil when either sound cannot be read. Nothing is kept: the sound is decoded into `job` and read there.
    static func measure(main: URL, twin: URL, at times: [Double], frame: Double, job: URL,
                        decode: @Sendable ([String]) async throws -> Void) async throws -> Offset? {
        try FileManager.default.createDirectory(at: job, withIntermediateDirectories: true)
        var points: [Double] = [], correlations: [Double] = []
        for (n, t) in times.enumerated() {
            let a = job.appending(path: "twin-main-\(n).f32"), b = job.appending(path: "twin-vertical-\(n).f32")
            defer {
                try? FileManager.default.removeItem(at: a)
                try? FileManager.default.removeItem(at: b)
            }
            let from = max(0, t - search)
            try await decode(arguments(file: main, from: t, length: window, to: a))
            try await decode(arguments(file: twin, from: from, length: window + (t - from) + search, to: b))
            guard let x = floats(a), let y = floats(b), x.count >= rate, y.count >= x.count else { return nil }
            guard let (lag, correlation) = bestLag(main: x, twin: y) else { return nil }
            points.append(Double(lag) / Double(rate) - (t - from))
            correlations.append(correlation)
        }
        guard !points.isEmpty else { return nil }
        let sorted = points.sorted()
        let seconds = sorted[sorted.count / 2]
        return Offset(seconds: seconds, frames: Int64((seconds / frame).rounded()), points: points, correlations: correlations)
    }

    /// The seek is on the output side (after `-i`): ffmpeg decodes the sound from the start and drops what comes before `from`.
    /// Measured 16 Oct on the 6 Sep excerpts (cut with `-c copy`, their sound starting at -1.0 s): seeking on the input side read
    /// the twin 0.41 and 0.47 s off at two of three moments, while the whole talks and output-side seeking read -0.012 s at every
    /// moment. Output-side costs about 1.5 s for a moment near the end of the 55-minute talk (`-vn`, sound only).
    static func arguments(file: URL, from: Double, length: Double, to output: URL) -> [String] {
        ["-y", "-v", "error", "-i", file.path, "-ss", String(format: "%.3f", from), "-t", String(format: "%.3f", length), "-map", "0:a:0", "-vn",
         "-ac", "1", "-ar", String(rate), "-f", "f32le", output.path]
    }

    static func floats(_ url: URL) -> [Float]? {
        guard let data = try? Data(contentsOf: url), data.count >= 4 else { return nil }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    /// The lag (in samples of `twin`) where `main` matches `twin` best, and the normalized correlation there. Pure.
    static func bestLag(main: [Float], twin: [Float]) -> (Int, Double)? {
        let p = main.count, lags = twin.count - main.count + 1
        guard p > 0, lags > 0 else { return nil }
        var result = [Float](repeating: 0, count: lags)
        twin.withUnsafeBufferPointer { a in
            main.withUnsafeBufferPointer { f in
                result.withUnsafeMutableBufferPointer { c in
                    vDSP_conv(a.baseAddress!, 1, f.baseAddress!, 1, c.baseAddress!, 1, vDSP_Length(lags), vDSP_Length(p))
                }
            }
        }
        var best = 0
        var bestValue: Float = -.infinity
        for i in 0..<lags where abs(result[i]) > bestValue {
            bestValue = abs(result[i])
            best = i
        }
        var mainEnergy: Float = 0, twinEnergy: Float = 0
        vDSP_svesq(main, 1, &mainEnergy, vDSP_Length(p))
        twin.withUnsafeBufferPointer { a in vDSP_svesq(a.baseAddress! + best, 1, &twinEnergy, vDSP_Length(p)) }
        let norm = sqrt(Double(mainEnergy) * Double(twinEnergy))
        guard norm > 0 else { return nil }
        return (best, Double(bestValue) / norm)
    }
}
