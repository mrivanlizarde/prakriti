import Foundation

// The edited video's sound (v2 part M8b, research-edit-engine.md 1.7, 2.8 and 4.2 item 7):
//
// 1. ffmpeg decodes the original's first audio track (the one the transcript and the plan were made from) to 48 kHz stereo
//    floats in the job folder, with any name said aloud that Ivan muted silenced on the original's clock (v1's
//    `Mastering.muteFilter`, the podcast's own).
// 2. Swift joins the plan's spans from those samples, each exactly as long as its picture (`EditTimeline.audioPieces`), and
//    every join is a 20 ms crossfade of steady power centred on the cut (equal power, eased where both sides are alike), made with 10 ms of handle from the sound taken out on
//    each side. The handles are why the total length stays exactly the sum of the spans: nothing overlaps, nothing is
//    stretched, so the picture stays in sync (research 1.7; ffmpeg's `acrossfade` would shorten the output instead).
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
        let written = try join(raw: raw, pieces: timeline.audioPieces, into: joined)
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
    @discardableResult
    static func join(raw: URL, pieces: [EditTimeline.AudioPiece], into output: URL) throws -> Int64 {
        let source = try SampleSource(raw)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let out = try FileHandle(forWritingTo: output)
        defer { try? out.close() }
        var written: Int64 = 0
        // Half of each join's crossfade, in samples: 10 ms, or less where a piece is too short to hold both of its ends.
        let halves = zip(pieces, pieces.dropFirst()).map { min(handle, Int($0.samples / 2), Int($1.samples / 2)) }
        for (index, piece) in pieces.enumerated() {
            let lead = index == 0 ? 0 : halves[index - 1]
            let tail = index == pieces.count - 1 ? 0 : halves[index]
            // The body: from after the lead crossfade (written with the piece before) to the start of the tail crossfade.
            let bodyStart = piece.sourceSample + Int64(lead)
            let bodyLength = piece.samples - Int64(lead) - Int64(tail)
            if bodyLength > 0 {
                var at = bodyStart
                var left = bodyLength
                while left > 0 {
                    let count = Int(min(left, 48_000 * 10))
                    out.write(Data(floatsAsBytes: try source.read(from: at, count: count)))
                    at += Int64(count)
                    left -= Int64(count)
                }
                written += bodyLength
            }
            if tail > 0 {
                let next = pieces[index + 1]
                // 2 x tail samples centred on the cut: the end of this piece runs on into its handle, the next piece starts
                // from its handle, before its own start.
                let outgoing = try source.read(from: piece.sourceSample + piece.samples - Int64(tail), count: 2 * tail)
                let incoming = try source.read(from: next.sourceSample - Int64(tail), count: 2 * tail)
                out.write(Data(floatsAsBytes: crossfade(outgoing, incoming, frames: 2 * tail)))
                written += Int64(2 * tail)
            }
        }
        return written
    }

    /// A crossfade over `frames` stereo sample frames that keeps the power steady: the equal-power curves (cos and sin of a
    /// quarter turn), scaled by how alike the two sides are. Two unrelated sounds need equal power; the same room tone on both
    /// sides adds up like one sound, and equal power would lift it by up to 3 dB in the middle of the fade. Measured 13 Oct on
    /// the 13 Sep talk with plain equal power: 32 of 96 joins had a sample jump inside the fade bigger than any in the 50 ms
    /// around it, the worst on room tone either side of a shortened pause.
    static func crossfade(_ a: [Float], _ b: [Float], frames: Int) -> [Float] {
        let r = max(0, correlation(a, b))
        var out = [Float](repeating: 0, count: frames * channels)
        for n in 0..<frames {
            let p = (Double(n) + 0.5) / Double(frames)
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
