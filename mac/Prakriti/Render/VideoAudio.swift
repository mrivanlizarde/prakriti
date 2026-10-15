import Foundation

// The edited video's sound (v2 part M8b, research-edit-engine.md 1.7, 2.8 and 4.2 item 7):
//
// 1. ffmpeg decodes the original's first audio track (the one the transcript and the plan were made from) to 48 kHz stereo
//    floats in the job folder, with any name said aloud that Ivan muted silenced on the original's clock (v1's
//    `Mastering.muteFilter`, the podcast's own).
// 2. Swift joins the plan's spans from those samples, each exactly as long as its picture (`EditTimeline.audioPieces`), and
//    every join is a 20 ms crossfade of steady power centred on the cut (equal power, eased where both sides are alike), made
//    with 10 ms of handle from the sound taken out on each side. The handles are why the total length stays exactly the sum
//    of the spans: nothing overlaps, nothing is stretched, so the picture stays in sync (research 1.7; ffmpeg's `acrossfade`
//    would shorten the output instead). Where a handle carries a knock, the fade moves to the clean side of the cut; and every
//    fade is held calmer than the 25 ms either side of it (`calm`), so no join is busier than the room (research 1.8).
// 3. v1's speech chain, re-targeted to the video master: two-pass loudnorm in linear mode to -14 LUFS with the limiter under
//    a -1 dBTP ceiling (`Mastering`, the same filters as the podcast at its own -16), written as a float WAV that the
//    writer encodes as AAC-LC 48 kHz stereo at 320 kbps (research 6.1 asks 384; see VideoWriter for why 320).
//
// The decoded and joined sound live only in the job folder and are deleted with it. Nothing leaves the Mac.

enum VideoAudio {
    static let target = -14.0
    static let ceiling = -1.0
    static let channels = 2
    /// Half of the 20 ms crossfade, in samples at 48 kHz.
    static let handle = 480

    struct Made: Sendable {
        let wav: URL
        let samples: Int64
        let inputLUFS: Double?
        let normalizationType: String?
    }

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// ffmpeg's arguments for step 1.
    static func decodeArguments(original: URL, raw: URL, mutes: [TimeRange]) -> [String] {
        let mute = Mastering.muteFilter(mutes.map { Mastering.Span(start: $0.start, end: $0.end) })
        return ["-y", "-v", "error", "-i", original.path, "-map", "0:a:0", "-vn"]
            + (mute.map { ["-af", $0] } ?? [])
            + ["-ac", String(channels), "-ar", String(EditTimeline.sampleRate), "-f", "f32le", raw.path]
    }

    /// The raw input ffmpeg reads the joined sound from.
    static func rawInput(_ raw: URL) -> [String] {
        ["-f", "f32le", "-ar", String(EditTimeline.sampleRate), "-ac", String(channels), "-i", raw.path]
    }

    /// Step 3's two passes: the first measures, the second writes the WAV.
    static func measureArguments(joined: URL) -> [String] {
        ["-hide_banner", "-nostats"] + rawInput(joined)
            + ["-af", Mastering.firstPass(target: target, ceiling: ceiling, channels: .stereo), "-f", "null", "-"]
    }

    static func masterArguments(joined: URL, measured: Measure.LoudnormPass, wav: URL) -> [String] {
        ["-y", "-hide_banner", "-nostats"] + rawInput(joined)
            // `latency=1`: the limiter looks 5 ms ahead (its attack) and, left alone, delays everything by that much; measured
            // 13 Oct, the made sound sat 239 samples (5 ms) behind its picture at every join. The podcast's chain is left as it
            // is (Mac warning 30); in a video the delay is a lip-sync error.
            + ["-af", Mastering.secondPass(target: target, ceiling: ceiling, measured: measured, channels: .stereo) + ":latency=1",
               "-ar", String(EditTimeline.sampleRate), "-c:a", "pcm_f32le", wav.path]
    }

    /// Makes the sound for a timeline. `tool` runs ffmpeg with the arguments it is given and returns what it wrote to
    /// stderr.
    static func make(original: URL, timeline: EditTimeline, mutes: [TimeRange], job: URL,
                     tool: @Sendable ([String]) async throws -> String) async throws -> Made {
        let fm = FileManager.default
        try fm.createDirectory(at: job, withIntermediateDirectories: true)
        let raw = job.appending(path: "video-sound.f32")
        let joined = job.appending(path: "video-joined.f32")
        let wav = job.appending(path: "video-sound.wav")
        defer {
            try? fm.removeItem(at: raw)
            try? fm.removeItem(at: joined)
        }
        _ = try await tool(decodeArguments(original: original, raw: raw, mutes: mutes))
        let held = timeline.totalSamples - timeline.sample(atFrame: timeline.keptFrames)
        let written = try join(raw: raw, pieces: timeline.audioPieces, holdSamples: held, into: joined)
        try? fm.removeItem(at: raw)
        guard written == timeline.totalSamples else {
            throw Failure(reason: "The sound for the video came out \(written) samples long instead of \(timeline.totalSamples).")
        }
        let first = try await tool(measureArguments(joined: joined))
        guard let measured = Measure.loudnorm(stderr: first) else {
            throw Failure(reason: "The loudness of the video's sound could not be measured.")
        }
        let second = try await tool(masterArguments(joined: joined, measured: measured, wav: wav))
        return Made(wav: wav, samples: written, inputLUFS: measured.inputLUFS, normalizationType: Measure.loudnorm(stderr: second)?.normalizationType)
    }

    /// Step 2: the pieces joined from interleaved stereo floats into `output`, streamed a piece at a time. Returns the
    /// number of sample frames written.
    /// The fade into the silence of a held last frame (v2 part M9a): 100 ms, a quarter cosine, so the room tone does not
    /// stop with a click.
    static let holdFade = 4_800

    @discardableResult
    static func join(raw: URL, pieces: [EditTimeline.AudioPiece], holdSamples: Int64 = 0, into output: URL) throws -> Int64 {
        let source = try SampleSource(raw)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let out = try FileHandle(forWritingTo: output)
        defer { try? out.close() }
        var written: Int64 = 0
        // The last `around + 1` sample frames written, as mono: the sound a join's fade is held calmer than.
        var recent: [Float] = []
        func wrote(_ frames: [Float]) {
            out.write(Data(floatsAsBytes: frames))
            recent = Array((recent + mono(Array(frames.suffix(channels * (around + 1))))).suffix(around + 1))
        }
        // Half of each join's crossfade, in samples: 10 ms, or less where a piece is too short to hold both of its ends.
        let halves = zip(pieces, pieces.dropFirst()).map { min(handle, Int($0.samples / 2), Int($1.samples / 2)) }
        for (index, piece) in pieces.enumerated() {
            let lead = index == 0 ? 0 : halves[index - 1]
            let tail = index == pieces.count - 1 ? 0 : halves[index]
            // The body: from after the lead crossfade (written with the piece before) to the start of the tail crossfade.
            let bodyStart = piece.sourceSample + Int64(lead)
            let bodyLength = piece.samples - Int64(lead) - Int64(tail)
            if bodyLength > 0 {
                // Before a held last frame the piece's last 100 ms fade to silence (v2 part M9a).
                let fading = index == pieces.count - 1 && holdSamples > 0 ? min(Int64(holdFade), bodyLength) : 0
                var at = bodyStart
                var left = bodyLength - fading
                while left > 0 {
                    let count = Int(min(left, 48_000 * 10))
                    wrote(try source.read(from: at, count: count))
                    at += Int64(count)
                    left -= Int64(count)
                }
                if fading > 0 {
                    var frames = try source.read(from: at, count: Int(fading))
                    let n = Int(fading)
                    for i in 0..<n {
                        let g = Float(cos(Double.pi / 2 * Double(i + 1) / Double(n)))
                        for ch in 0..<channels { frames[i * channels + ch] *= g }
                    }
                    wrote(frames)
                }
                written += bodyLength
            }
            if tail > 0 {
                let next = pieces[index + 1]
                // 2 x tail samples centred on the cut: the end of this piece runs on into its handle, the next piece starts
                // from its handle, before its own start.
                let outgoing = try source.read(from: piece.sourceSample + piece.samples - Int64(tail), count: 2 * tail)
                let incoming = try source.read(from: next.sourceSample - Int64(tail), count: 2 * tail)
                // What follows the fade in the output: the next piece from its own start plus `tail`.
                let following = mono(try source.read(from: next.sourceSample + Int64(tail), count: around + 1))
                wrote(joinFade(outgoing, incoming, frames: 2 * tail, before: recent, after: following))
                written += Int64(2 * tail)
            }
        }
        // The held last frame's silence (v2 part M9a).
        var silent = holdSamples
        while silent > 0 {
            let count = Int(min(silent, 48_000 * 10))
            out.write(Data(floatsAsBytes: [Float](repeating: 0, count: count * channels)))
            silent -= Int64(count)
        }
        written += holdSamples
        return written
    }

    /// The 25 ms either side of a fade that it is measured against (research 1.8: "the surrounding 50 ms").
    static let around = 1_200
    /// How much calmer than the sound around it a join is held: no sample-to-sample step inside the fade over 0.7 of the
    /// largest step in the 25 ms either side. Research 1.8's bar is "no sample jump at a join exceeds the largest jump in the
    /// surrounding 50 ms"; untouched room tone fails it by chance on about 29% of joins (the largest of 3,360 steps falls in
    /// the fade's 960 that often), so the fade is held under it by construction. 0.7 rather than 1 because the AAC encoder
    /// moves single steps by up to about 15% (measured 14 Oct on the 6 Sep sound, 163 joins: worst 0.84 after encoding at 0.7,
    /// 1.13 at 1.0).
    static let calm: Float = 0.7

    /// Where the fade sits in its 2 x 10 ms window. Centred is the rule (20 ms, research 1.7). When a handle carries a
    /// transient (a knock or a breath taken out with the pause: the fade's largest step more than twice the sound around it,
    /// 6 Sep at 9:48), the fade moves to the side whose handle is clean: 10 ms ending at the cut (only the next piece's handle
    /// is heard) or 10 ms starting at it (only this piece's).
    enum FadeShape: CaseIterable, Sendable { case centred, beforeCut, afterCut }

    /// One join: the fade in the shape whose handles are cleanest, then held calmer than the sound either side of it.
    /// `before` is the output just before the fade, `after` what follows it, both mono.
    static func joinFade(_ a: [Float], _ b: [Float], frames: Int, before: [Float], after: [Float]) -> [Float] {
        let reference = max(largestStep(before), largestStep(after))
        let first = before.last, last = after.first
        func ratio(_ faded: [Float]) -> Float {
            largestStep((first.map { [$0] } ?? []) + mono(faded) + (last.map { [$0] } ?? [])) / max(reference, 1e-12)
        }
        var faded = crossfade(a, b, frames: frames, shape: .centred)
        if ratio(faded) > 2 {
            let others = [FadeShape.beforeCut, .afterCut].map { crossfade(a, b, frames: frames, shape: $0) }
            if let best = others.min(by: { ratio($0) < ratio($1) }), ratio(best) < ratio(faded) { faded = best }
        }
        guard let first, let last else { return faded }
        let m = mono(faded)
        let steadied = steady(m, from: first, to: last, limit: calm * reference)
        for n in 0..<frames {
            let d = steadied[n] - m[n]
            guard d != 0 else { continue }
            for ch in 0..<channels { faded[n * channels + ch] += d }
        }
        return faded
    }

    /// `window` changed as little as it takes for no step (including the one in from `from` and the one out to `to`, which
    /// stay as they are) to be larger than `limit`: each step over is shared back between its two samples until none is
    /// (projection onto the allowed steps). Where that does not settle, the window is drawn toward the straight line between
    /// its ends just far enough. A limit too small for the ends to be reached is raised to the straight line's step.
    static func steady(_ window: [Float], from: Float, to: Float, limit: Float) -> [Float] {
        let count = window.count
        guard count > 0 else { return window }
        let c = max(limit, abs(to - from) / Float(count + 1) * 1.0001, 1e-9)
        var full = [from] + window + [to]
        func overs() -> Bool { (1..<full.count).contains { abs(full[$0] - full[$0 - 1]) > c } }
        var pass = 0
        while overs(), pass < 400 {
            for i in 1..<full.count {
                let d = full[i] - full[i - 1]
                guard abs(d) > c else { continue }
                let excess = (abs(d) - c) * (d > 0 ? 1 : -1)
                if i == 1 { full[1] -= excess }
                else if i == full.count - 1 { full[i - 1] += excess }
                else { full[i - 1] += excess / 2; full[i] -= excess / 2 }
            }
            pass += 1
        }
        if !overs() { return Array(full[1...count]) }
        // Toward the straight line between the ends, by halves, until every step is within the limit.
        let line = (0..<count).map { from + (to - from) * Float($0 + 1) / Float(count + 1) }
        var low: Float = 0, high: Float = 1
        func blended(_ t: Float) -> [Float] { (0..<count).map { line[$0] + t * (full[$0 + 1] - line[$0]) } }
        for _ in 0..<30 {
            let t = (low + high) / 2
            if largestStep([from] + blended(t) + [to]) <= c { low = t } else { high = t }
        }
        return blended(low)
    }

    /// Interleaved stereo frames as mono, the average of the channels (what the acceptance measures).
    static func mono(_ frames: [Float]) -> [Float] {
        stride(from: 0, to: frames.count - channels + 1, by: channels).map { i in
            (0..<channels).reduce(Float(0)) { $0 + frames[i + $1] } / Float(channels)
        }
    }

    /// The largest step from one sample to the next.
    static func largestStep(_ x: [Float]) -> Float {
        guard x.count > 1 else { return 0 }
        var m: Float = 0
        for i in 1..<x.count { m = max(m, abs(x[i] - x[i - 1])) }
        return m
    }

    /// A crossfade over `frames` stereo sample frames that keeps the power steady: the equal-power curves (cos and sin of a
    /// quarter turn), scaled by how alike the two sides are. Two unrelated sounds need equal power; the same room tone on both
    /// sides adds up like one sound, and equal power would lift it by up to 3 dB in the middle of the fade. Measured 13 Oct on
    /// the 13 Sep talk with plain equal power: 32 of 96 joins had a sample jump inside the fade bigger than any in the 50 ms
    /// around it, the worst on room tone either side of a shortened pause.
    static func crossfade(_ a: [Float], _ b: [Float], frames: Int, shape: FadeShape = .centred) -> [Float] {
        let r = max(0, correlation(a, b))
        var out = [Float](repeating: 0, count: frames * channels)
        for n in 0..<frames {
            let along = (Double(n) + 0.5) / Double(frames)
            let p: Double
            switch shape {
            case .centred: p = along
            case .beforeCut: p = min(1, 2 * along)
            case .afterCut: p = max(0, 2 * along - 1)
            }
            let c = cos(Double.pi / 2 * p), s = sin(Double.pi / 2 * p)
            let k = 1 / sqrt(1 + 2 * r * c * s)
            let gOut = Float(c * k), gIn = Float(s * k)
            for ch in 0..<channels {
                let i = n * channels + ch
                out[i] = (i < a.count ? a[i] : 0) * gOut + (i < b.count ? b[i] : 0) * gIn
            }
        }
        return out
    }

    /// How alike two stretches of sound are, -1 to 1 (0 when either is silent).
    static func correlation(_ a: [Float], _ b: [Float]) -> Double {
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<min(a.count, b.count) {
            dot += Double(a[i]) * Double(b[i])
            na += Double(a[i]) * Double(a[i])
            nb += Double(b[i]) * Double(b[i])
        }
        return na > 0 && nb > 0 ? dot / sqrt(na * nb) : 0
    }

    /// Interleaved stereo floats read by sample frame; anything before the start or past the end of the file is silence.
    final class SampleSource {
        let handle: FileHandle
        let frames: Int64

        init(_ url: URL) throws {
            handle = try FileHandle(forReadingFrom: url)
            let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            frames = bytes / Int64(4 * channels)
        }

        deinit { try? handle.close() }

        func read(from start: Int64, count: Int) throws -> [Float] {
            var out = [Float](repeating: 0, count: count * channels)
            let first = max(0, start), last = min(frames, start + Int64(count))
            guard last > first else { return out }
            try handle.seek(toOffset: UInt64(first) * UInt64(4 * channels))
            guard let data = try handle.read(upToCount: Int(last - first) * 4 * channels) else { return out }
            let offset = Int(first - start) * channels
            data.withUnsafeBytes { raw in
                let floats = raw.bindMemory(to: Float.self)
                for i in 0..<min(floats.count, out.count - offset) { out[offset + i] = floats[i] }
            }
            return out
        }
    }
}

extension Data {
    init(floatsAsBytes floats: [Float]) {
        self = floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
