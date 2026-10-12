import Foundation
import Synchronization

// The bridge between the pipeline, which runs off the main thread, and the progress the window shows (v2
// part M4a). The pipeline and the tools it runs write into a meter; the window reads it twice a second.
// Reading rather than being told keeps the order of updates simple and their number bounded.

/// Where the running stage of one make has got to, as the tools report it.
final class ProgressMeter: Sendable {
    struct State: Sendable, Equatable {
        var step: PipelineStep?
        /// How many measured passes (ffmpeg runs) the stage makes, when the pipeline knows; nil when it
        /// does not (each later pass then takes half of what is left).
        var passes: Int?
        /// The pass running now, from 0; -1 before the first.
        var pass = -1
        /// How far the running pass is through its input, 0 to 1.
        var passFraction = 0.0
        /// The latest line the make wrote for Ivan ("Transcript done in 10.7 s. 2,948 words.").
        var line: String?
    }

    private let state = Mutex<State>(State())
    /// Pauses and resumes the tool running for this make.
    let control = ProcessControl()

    init() {}

    var current: State { state.withLock { $0 } }

    /// A stage starts: `passes` is how many ffmpeg runs it makes, when known.
    func begin(_ step: PipelineStep, passes: Int?) {
        state.withLock { $0 = State(step: step, passes: passes, pass: -1, passFraction: 0, line: $0.line) }
    }

    /// A measured tool starts its run inside the stage.
    func startPass() {
        state.withLock {
            $0.pass += 1
            $0.passFraction = 0
        }
    }

    /// The running pass has read this far through its input.
    func passProgress(_ fraction: Double) {
        guard fraction.isFinite else { return }
        state.withLock { $0.passFraction = min(1, max($0.passFraction, fraction)) }
    }

    func line(_ text: String) {
        state.withLock { $0.line = text }
    }

    /// How far the stage is, from its passes: nil until a measured pass has started. With a known number of
    /// passes each has an equal share; with an unknown number, pass k covers the half of what is left
    /// (0 to 0.5, then 0.5 to 0.75, ...), so the stage moves and never reaches its end before it finishes.
    /// A pass beyond the known number (the decode of the file's tail) holds the stage at 0.99.
    static func stageFraction(_ s: State) -> Double? {
        guard s.pass >= 0 else { return nil }
        let within = min(1, max(0, s.passFraction))
        if let passes = s.passes, passes > 0 {
            guard s.pass < passes else { return 0.99 }
            return min(0.99, (Double(s.pass) + within) / Double(passes))
        }
        let low = 1 - pow(0.5, Double(s.pass))
        let high = 1 - pow(0.5, Double(s.pass + 1))
        return min(0.99, low + (high - low) * within)
    }

    /// ffmpeg's `-progress pipe:1` lines: "out_time_us=123456789" against the input's length.
    static func outTime(_ line: String) -> Double? {
        guard line.hasPrefix("out_time_us="), let micro = Double(line.dropFirst("out_time_us=".count)) else { return nil }
        return micro / 1_000_000
    }
}

/// Pauses the tool a make is running (SIGSTOP), resumes it (SIGCONT), and holds the next tool from starting
/// while paused. A paused tool's time limit is moved on by the time it was paused (Mac warning 14 still holds
/// for the time it runs).
final class ProcessControl: Sendable {
    private struct State: Sendable {
        var paused = false
        var pid: Int32?
        var waiters: [CheckedContinuation<Void, Never>] = []
        var pausedSince: ContinuousClock.Instant?
        var pausedTotal: Duration = .zero
    }

    private let state = Mutex<State>(State())

    init() {}

    var isPaused: Bool { state.withLock { $0.paused } }

    /// All the time spent paused so far, including a pause still going on.
    var pausedTotal: Duration {
        state.withLock { s in s.pausedTotal + (s.pausedSince.map { ContinuousClock.now - $0 } ?? .zero) }
    }

    func pause() {
        state.withLock { s in
            guard !s.paused else { return }
            s.paused = true
            s.pausedSince = .now
            if let pid = s.pid { kill(pid, SIGSTOP) }
        }
    }

    func resume() {
        let waiters: [CheckedContinuation<Void, Never>] = state.withLock { s in
            guard s.paused else { return [] }
            s.paused = false
            if let since = s.pausedSince { s.pausedTotal += ContinuousClock.now - since }
            s.pausedSince = nil
            if let pid = s.pid { kill(pid, SIGCONT) }
            let list = s.waiters
            s.waiters = []
            return list
        }
        waiters.forEach { $0.resume() }
    }

    /// Waits while paused; returns at once otherwise.
    func waitWhilePaused() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let run = state.withLock { s -> Bool in
                if s.paused { s.waiters.append(continuation); return false }
                return true
            }
            if run { continuation.resume() }
        }
    }

    /// The running tool, so a pause can reach it. A tool that starts while paused is stopped at once.
    func attach(_ pid: Int32) {
        state.withLock { s in
            s.pid = pid
            if s.paused { kill(pid, SIGSTOP) }
        }
    }

    func detach(_ pid: Int32) {
        state.withLock { s in if s.pid == pid { s.pid = nil } }
    }
}
