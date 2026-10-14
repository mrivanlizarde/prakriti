import Foundation

// The sound's envelope (v2 part M8a, docs/v2/research-edit-engine.md 1.2 step 2): the first audio track as mono at
// 48 kHz, its RMS in 10 ms frames in dBFS, the noise floor, the speech level, and speech activity with hysteresis.
// Every cut the plan makes is placed on it, because Parakeet's word ends are not where the words end: 326 of 502
// pauses of 0.3 s or more in the 6 Sep talk sit inside a word's span (research section 0, measured).
//
// The numbers, each with its reason:
// - 10 ms frames: short enough to find a quiet gap between two words, long enough that one frame's RMS is steady.
// - The floor is the 10th percentile of the 10 ms frames' levels, digital silence left out: the room between phrases.
//   (Research 1.2's one-second windows were measured and do not work; see `floor`.)
// - Speech is on at floor + 12 dB and off below floor + 8 dB (hysteresis), research 1.2 [proposal; tune by listening].
// - The speech level is the median level of the frames where speech is on. "Quiet" for a cut is 20 dB or more under
//   it (research 1.8, the "no cut inside a word" bar).
//
// Nothing here is kept: the plan stores the floor and the speech level as two numbers, never the sound.

struct Envelope: Sendable {
    static let frame = 0.010
    static let sampleRate = 48_000
    static let samplesPerFrame = 480
    /// Speech is on at floor + `onAbove` and off below floor + `offBelow`.
    static let onAbove = 12.0
    static let offBelow = 8.0
    /// A cut point is clean where the sound is this far under the speech level (research 1.8).
    static let quietUnderSpeech = 20.0
    /// Speech shorter than this many frames is not speech.
    static let shortestBurst = 3
    /// The lowest level a frame is given (digital silence has none).
    static let lowest = -120.0

    /// dBFS of each 10 ms frame, from the recording's start.
    let levels: [Double]
    let floor: Double
    let speech: Double
    let active: [Bool]

    var duration: Double { Double(levels.count) * Self.frame }
    var quietLevel: Double { speech - Self.quietUnderSpeech }

    init(levels: [Double]) {
        self.levels = levels
        let floor = Self.floor(levels)
        self.floor = floor
        var active = [Bool](repeating: false, count: levels.count)
        var on = false
        for (i, level) in levels.enumerated() {
            if on { on = level >= floor + Self.offBelow } else { on = level >= floor + Self.onAbove }
            active[i] = on
        }
        // A burst of "speech" shorter than 30 ms is a click or a knock, not a syllable (13 Sep at 8:43: one frame at
        // -47 dB in 1.6 s of room tone): it is not speech.
        var i = 0
        while i < active.count {
            guard active[i] else { i += 1; continue }
            var j = i
            while j < active.count, active[j] { j += 1 }
            if j - i < Self.shortestBurst { for k in i..<j { active[k] = false } }
            i = j
        }
        self.active = active
        let speaking = zip(levels, active).filter(\.1).map(\.0).sorted()
        self.speech = speaking.isEmpty ? floor + Self.onAbove : speaking[speaking.count / 2]
    }

    /// The 10th percentile of the frames' levels, leaving out digital silence (under -100 dBFS: a file's padding, never a
    /// room). Research 1.2 says "the quietest second-long windows"; measured 13 Oct, a one-second window almost always
    /// holds a word in a talk, so the windows' 10th percentile lands on speech (13 Sep: -33.7 dB against the room's -69.5,
    /// and the ums fixture's -21.2), and every pause would read as speech. The frames' own 10th percentile is the room.
    static func floor(_ levels: [Double]) -> Double {
        let heard = levels.filter { $0 > -100 }.sorted()
        guard !heard.isEmpty else { return lowest }
        return heard[min(heard.count - 1, heard.count / 10)]
    }

    /// The RMS level of one frame of samples, in dBFS.
    static func level(_ samples: UnsafeBufferPointer<Float>) -> Double {
        guard !samples.isEmpty else { return lowest }
        var sum = 0.0
        for s in samples { sum += Double(s) * Double(s) }
        let rms = (sum / Double(samples.count)).squareRoot()
        return rms > 0 ? max(lowest, 20 * log10(rms)) : lowest
    }

    /// The envelope of mono float samples at 48 kHz.
    static func of(samples: [Float]) -> Envelope {
        var levels: [Double] = []
        levels.reserveCapacity(samples.count / samplesPerFrame + 1)
        samples.withUnsafeBufferPointer { buffer in
            var i = 0
            while i < buffer.count {
                let n = min(samplesPerFrame, buffer.count - i)
                levels.append(level(UnsafeBufferPointer(rebasing: buffer[i..<(i + n)])))
                i += n
            }
        }
        return Envelope(levels: levels)
    }

    /// The envelope of a raw file of mono little-endian 32-bit floats at 48 kHz, read a few seconds at a time, so an
    /// hour's sound is never held in memory (it would be about 690 MB).
    static func read(rawFloats url: URL) throws -> Envelope {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var levels: [Double] = []
        let chunkFrames = 1000
        while let data = try handle.read(upToCount: chunkFrames * samplesPerFrame * 4), !data.isEmpty {
            data.withUnsafeBytes { raw in
                let floats = raw.bindMemory(to: Float.self)
                var i = 0
                while i < floats.count {
                    let n = min(samplesPerFrame, floats.count - i)
                    levels.append(level(UnsafeBufferPointer(rebasing: floats[i..<(i + n)])))
                    i += n
                }
            }
        }
        return Envelope(levels: levels)
    }

    /// The ffmpeg arguments that decode the first audio track of `file` to `raw` as `read(rawFloats:)` reads it.
    static func decodeArguments(file: URL, raw: URL) -> [String] {
        ["-y", "-v", "error", "-i", file.path, "-map", "0:a:0", "-vn", "-ac", "1", "-ar", String(sampleRate), "-f", "f32le", raw.path]
    }

    // MARK: Reading it

    /// The frame holding moment `t`.
    func frameIndex(_ t: Double) -> Int { Int((t / Self.frame).rounded(.down)) }

    func level(at t: Double) -> Double {
        let i = frameIndex(t)
        return levels.indices.contains(i) ? levels[i] : Self.lowest
    }

    func isActive(at t: Double) -> Bool {
        let i = frameIndex(t)
        return active.indices.contains(i) ? active[i] : false
    }

    /// Every frame that touches [t - half, t + half] is quiet: 20 dB or more under the speech level. Moments outside the
    /// sound (before 0, after its end) count as quiet.
    func isQuiet(around t: Double, half: Double = 0.010) -> Bool {
        let first = max(0, frameIndex(t - half)), last = min(levels.count - 1, frameIndex(t + half - 1e-9))
        guard first <= last else { return true }
        return (first...last).allSatisfy { levels[$0] <= quietLevel }
    }

    /// How long the quiet stretch holding `t` lasts, in seconds (0 when `t` is not quiet).
    func quietRun(at t: Double) -> Double {
        let i = frameIndex(t)
        guard levels.indices.contains(i), levels[i] <= quietLevel else { return 0 }
        var a = i, b = i
        while a > 0, levels[a - 1] <= quietLevel { a -= 1 }
        while b < levels.count - 1, levels[b + 1] <= quietLevel { b += 1 }
        return Double(b - a + 1) * Self.frame
    }

    /// The first moment in [from, to] where speech is on, or nil.
    func firstActive(from: Double, to: Double) -> Double? {
        var i = max(0, frameIndex(from))
        let last = min(levels.count - 1, frameIndex(to))
        while i <= last {
            if active[i] { return max(from, Double(i) * Self.frame) }
            i += 1
        }
        return nil
    }

    /// How long speech is on inside [from, to], in seconds.
    func activeSeconds(from: Double, to: Double) -> Double {
        let first = max(0, frameIndex(from)), last = min(levels.count - 1, frameIndex(to - 1e-9))
        guard first <= last else { return 0 }
        return Double((first...last).filter { active[$0] }.count) * Self.frame
    }

    /// The end of the last frame in [from, to] where speech is on, or nil.
    func lastActiveEnd(from: Double, to: Double) -> Double? {
        let first = max(0, frameIndex(from))
        var i = min(levels.count - 1, frameIndex(to - 1e-9))
        while i >= first {
            if active[i] { return min(to, Double(i + 1) * Self.frame) }
            i -= 1
        }
        return nil
    }

    /// The first moment after `from`, and before `to`, where speech has been off for `hold` seconds: where that quiet
    /// begins. Nil when speech never stays off that long inside.
    func offFor(_ hold: Double, from: Double, to: Double) -> Double? {
        let need = Int((hold / Self.frame).rounded())
        var i = max(0, frameIndex(from))
        let last = min(levels.count - 1, frameIndex(to))
        var run = 0
        while i <= last {
            if active[i] { run = 0 } else {
                run += 1
                if run >= need { return max(from, Double(i - need + 1) * Self.frame) }
            }
            i += 1
        }
        return nil
    }

    /// Where the sound around a word falls to floor + `above` dB: scanning back from `t` (the word's start) for at most
    /// `limit` seconds, the start of the sound; forward from `t` (its end), its end.
    func soundEdge(from t: Double, forward: Bool, above: Double = 6, limit: Double = 0.5) -> Double {
        let threshold = floor + above
        let steps = Int((limit / Self.frame).rounded())
        var i = frameIndex(t)
        if forward {
            var n = 0
            while n < steps, levels.indices.contains(i), levels[i] >= threshold { i += 1; n += 1 }
            return min(t + limit, max(t, Double(i) * Self.frame))
        } else {
            var n = 0
            while n < steps, levels.indices.contains(i - 1), levels[i - 1] >= threshold { i -= 1; n += 1 }
            return max(t - limit, min(t, Double(i) * Self.frame))
        }
    }
}
