import Foundation
@testable import Prakriti

/// The edit plan measured against the original's own sound (v2 part M8a, docs/v2/PLAN.md M8 check 2, the half that can
/// be measured before a video exists; research-edit-engine.md 1.8). Everything here reads the plan file and the
/// original's samples, decoded by the test itself, never the planner's own numbers, so the plan is checked from outside.
struct PlanMeasure {
    let plan: EditPlan
    let words: PlanWords
    /// The original's first audio track, mono, 48 kHz.
    let samples: [Float]
    let envelope: Envelope

    static let rate = 48_000.0

    struct CutPoint {
        let at: Double
        let kind: RemovedKind
        let clean: Bool
        /// The loudest 10 ms frame in the 20 ms around it, in dB under the speech level.
        let under: Double
    }

    /// Every cut point inside the recording (the start of the file and its end are not cuts).
    var cutPoints: [CutPoint] {
        var out: [CutPoint] = []
        for item in plan.removed {
            for t in [item.from, item.to] where t > 0.0005 && t < plan.sourceDuration - 0.0005 {
                let a = max(0, envelope.frameIndex(t - 0.010)), b = min(envelope.levels.count - 1, envelope.frameIndex(t + 0.010 - 1e-9))
                let loudest = a <= b ? (envelope.levels[a...b].max() ?? 0) : Envelope.lowest
                out.append(CutPoint(at: t, kind: item.kind, clean: item.clean, under: envelope.speech - loudest))
            }
        }
        return out
    }

    struct Join {
        let at: Double
        /// The largest sample-to-sample jump across the 20 ms equal-power crossfade, and the largest in the original's own
        /// 50 ms around each of the two cut points.
        let jump: Float
        let around: Float
    }

    /// Each join between two kept spans, made the way M8b will make it: a 20 ms equal-power crossfade centred on the cut,
    /// with 10 ms of handle from each side (research 1.7).
    var joins: [Join] {
        var out: [Join] = []
        let half = 480, reach = 1200
        func sample(_ i: Int) -> Float { samples.indices.contains(i) ? samples[i] : 0 }
        func largestJump(_ center: Int) -> Float {
            var m: Float = 0
            for i in (center - reach + 1)...(center + reach) { m = max(m, abs(sample(i) - sample(i - 1))) }
            return m
        }
        var outTime = 0.0
        for (left, right) in zip(plan.spans, plan.spans.dropFirst()) {
            outTime += left.out - left.in
            let a = Int((left.out * Self.rate).rounded()), b = Int((right.in * Self.rate).rounded())
            var joined: [Float] = []
            for n in -half - 1...half {
                let p = Double(n + half) / Double(2 * half)
                let gIn = Float(sin(Double.pi / 2 * min(1, max(0, p)))), gOut = Float(cos(Double.pi / 2 * min(1, max(0, p))))
                joined.append(sample(a + n) * gOut + sample(b + n) * gIn)
            }
            var jump: Float = 0
            for i in 1..<joined.count { jump = max(jump, abs(joined[i] - joined[i - 1])) }
            out.append(Join(at: outTime, jump: jump, around: max(largestJump(a), largestJump(b))))
        }
        return out
    }

    /// A moment of the original on the edit's clock, or nil when it was taken out.
    func editTime(_ t: Double) -> Double? {
        var offset = 0.0
        for span in plan.spans {
            if t >= span.in - 1e-6 && t <= span.out + 1e-6 { return offset + t - span.in }
            offset += span.out - span.in
        }
        return nil
    }

    struct Pause {
        let after: Int
        let closes: PlanWord.Closing
        let protected: Bool
        let was: Double
        let now: Double
        var shortened: Bool { now < was - 0.01 }
    }

    /// The pause between every two kept words that follow each other in the edit, measured on the edit's clock between
    /// the plan's refined word times.
    var pauses: [Pause] {
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let all = words.words
        var out: [Pause] = []
        for span in plan.spans {
            guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to) else { continue }
            for i in a..<b {
                guard let l = times[all[i].id], let r = times[all[i + 1].id] else { continue }
                let was = r.in - l.out
                out.append(Pause(after: i, closes: all[i].closes, protected: RoughCut.isProtected(after: i, words: all), was: was, now: was))
            }
        }
        // Across each join: the kept word before and after it.
        for (left, right) in zip(plan.spans, plan.spans.dropFirst()) {
            guard let l = PlanWord.index(of: left.to), let r = PlanWord.index(of: right.from),
                  let lt = times[all[l].id], let rt = times[all[r].id],
                  let le = editTime(lt.out), let rs = editTime(rt.in) else { continue }
            out.append(Pause(after: l, closes: all[l].closes, protected: RoughCut.isProtected(after: l, words: all), was: rt.in - lt.out, now: rs - le))
        }
        return out.sorted { $0.after < $1.after }
    }

    /// The silences in the edit: stretches where speech is off, on the edit's clock, longer than `longer`, each with
    /// the kept word before it.
    func silences(longer: Double) -> [(at: Double, length: Double, after: Int?, original: Double)] {
        var flags: [Bool] = []
        var origin: [Double] = []
        for span in plan.spans {
            var i = envelope.frameIndex(span.in)
            let last = envelope.frameIndex(span.out - 1e-9)
            while i <= last, envelope.active.indices.contains(i) {
                flags.append(envelope.active[i])
                origin.append(Double(i) * Envelope.frame)
                i += 1
            }
        }
        let times = plan.words
        var out: [(Double, Double, Int?, Double)] = []
        var start: Int?
        for i in 0...flags.count {
            let off = i < flags.count && !flags[i]
            if off, start == nil { start = i }
            if !off, let s = start {
                let length = Double(i - s) * Envelope.frame
                if length > longer {
                    let originalStart = origin[s]
                    let before = times.lastIndex { $0.out <= originalStart + 0.02 }
                    out.append((Double(s) * Envelope.frame, length, before, originalStart))
                }
                start = nil
            }
        }
        return out
    }

    static func median(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// Mono 48 kHz float samples of a file's first audio track, decoded by ffmpeg into `scratch`.
    static func decode(_ file: URL, scratch: URL) async throws -> [Float] {
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let raw = scratch.appending(path: "measure.f32")
        defer { try? FileManager.default.removeItem(at: raw) }
        _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, Envelope.decodeArguments(file: file, raw: raw), captureStdout: false, timeout: .seconds(900))
        let data = try Data(contentsOf: raw)
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
