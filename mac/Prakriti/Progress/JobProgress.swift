import Foundation
import Observation

// Progress on a recording while it is made (v2 part M4a; REQUEST item 6, "give me a progress on the
// recordings as it's working"; docs/v2/design-spec.md 3.6). Honest by construction:
// - The percent is each stage's share of the work, weighted by how long that stage takes on this Mac, and
//   it never goes backwards.
// - A time left is shown only once the running stage has a measured rate: the tool's own progress, or the
//   stage's runs measured on this Mac. Until then: "Working out the time left". It is always "About" and
//   rounded.
// - A stage that has not moved for 60 s says what it is waiting on, rather than freezing.
// - What the window reads changes at most twice a second.

/// One stage in the Activity window's list.
struct StageLine: Equatable, Sendable, Identifiable {
    let step: PipelineStep
    let state: StepState
    /// How long it took (done), or how long it has run so far (running).
    let seconds: Double?
    /// How long it usually takes here, for a stage still to come; nil until measured on this Mac.
    let usual: Double?
    var id: String { step.rawValue }
}

/// What the window shows for one make, at one moment.
struct ProgressSnapshot: Equatable, Sendable {
    var recordingID: UUID
    /// "Sun 13 Sep".
    var label: String
    var stage: PipelineStep?
    var stepNumber: Int
    var stepCount: Int
    var stageFraction: Double
    /// 0 to 1, weighted by the stages' measured times; never lower than the one before.
    var overall: Double
    /// Seconds, unrounded; nil while the running stage has no measured rate.
    var timeLeft: Double?
    /// What it waits on after 60 s without moving.
    var waitingOn: String?
    /// The latest line the make wrote.
    var logLine: String?
    var isPaused: Bool
    /// False while the running stage cannot be held (a request to a writing model is under way).
    var canPause: Bool
    var stages: [StageLine]
    var startedAt: Date
    var at: Date
    var finished = false

    /// Rounded down, so 100% means finished.
    var percent: Int { finished ? 100 : min(99, Int((overall * 100).rounded(.down))) }

    /// "Writing the transcript", the stage in words (never "Processing").
    var stageName: String { stage?.doing ?? (finished ? "Finished" : "Starting") }

    /// "About 6 min left", "Working out the time left", "Paused".
    var timeLeftText: String {
        if isPaused { return "Paused" }
        return TimeLeft.text(timeLeft)
    }

    /// The status line of the menu bar and the toolbar's Activity button (design spec 3.6.2): "Making Sun 13
    /// Sep: Writing the transcript, 64%, about 6 min left. 2 waiting."
    func statusLine(waiting: Int) -> String {
        let after = waiting > 0 ? " \(waiting) waiting." : ""
        if isPaused { return "Paused \(label): \(stageName), \(percent)%." + after }
        if let waitingOn { return "Making \(label): \(stageName), \(percent)%. \(waitingOn)" + after }
        return "Making \(label): \(stageName), \(percent)%, \(timeLeftText.lowercasedFirst)." + after
    }
}

/// The time left in plain words: under a minute, then whole minutes, then hours and minutes, always "About".
enum TimeLeft {
    static let workingOut = "Working out the time left"

    static func text(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite else { return workingOut }
        if seconds < 60 { return "Under a minute left" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "About \(minutes) min left" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "About \(hours) hr left" : "About \(hours) hr \(rest) min left"
    }

    /// "4 min", "under a minute", "1 hr 10 min": how long a stage usually takes.
    static func usual(_ seconds: Double) -> String {
        if seconds < 60 { return "under a minute" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }
}

extension PipelineStep {
    /// The stages whose progress comes from the tool itself (ffmpeg's `-progress`). The others are timed:
    /// how long they have run against how long they usually take, held at 95% until they finish.
    var isMetered: Bool {
        switch self {
        case .sound, .speechAudio, .trim, .episode, .loudness, .podcastAudio, .podcastPackage: true
        default: false
        }
    }

    /// What a stage that has not moved for a minute is waiting on, in plain words.
    var waitingLine: String {
        switch self {
        case .complete: "Waiting for the file to stop growing. It may still be recording or copying."
        case .transcript: "Waiting for Parakeet to finish the transcript."
        case .writing: "Waiting for the writing model to answer. This can take 30 to 60 minutes."
        default: isMetered ? "Waiting for ffmpeg, which has not moved for a minute." : "Waiting for this step to finish."
        }
    }
}

/// The arithmetic of one make's progress, on a clock the caller gives: pure, so `ProgressTests` can drive it.
struct ProgressTracker {
    /// A stage timed by the clock stops at this share until it finishes (docs/v2/PLAN.md M4: Parakeet is
    /// capped at 95% until it exits).
    static let timedCap = 0.95
    /// A stage that has not moved for this long says what it waits on.
    static let stallSeconds: Double = 60

    let recordingID: UUID
    let label: String
    let plan: [PipelineStep]
    /// How long each stage usually takes for this recording, in seconds: the weights.
    let expected: [PipelineStep: Double]
    /// The stages with runs measured on this Mac: only these give a time left from their history.
    let measured: Set<PipelineStep>
    let startedAt: Date

    private(set) var current: PipelineStep?
    private var stageStartedAt: Date
    private var pausedInStage: Double = 0
    private var pausedSince: Date?
    private(set) var states: [PipelineStep: StepState] = [:]
    private var seconds: [PipelineStep: Double] = [:]
    /// The tool's own fraction for the running stage, when it reports one.
    private var reported: Double?
    private var reportedEvenly = true
    private var stageFraction: Double = 0
    private var lastAdvanceAt: Date
    private var shownOverall: Double = 0
    private(set) var pausedStages: Set<PipelineStep> = []
    var logLine: String?
    var canPause = true
    private(set) var finished = false

    init(recordingID: UUID, label: String, plan: [PipelineStep], expected: [PipelineStep: Double], measured: Set<PipelineStep>, startedAt: Date) {
        self.recordingID = recordingID
        self.label = label
        self.plan = plan
        self.expected = expected
        self.measured = measured
        self.startedAt = startedAt
        stageStartedAt = startedAt
        lastAdvanceAt = startedAt
    }

    var isPaused: Bool { pausedSince != nil }

    private var total: Double { max(0.001, plan.reduce(0) { $0 + weight($1) }) }
    private func weight(_ step: PipelineStep) -> Double { max(StageTimings.floor, expected[step] ?? StageTimings.floor) }

    // MARK: Events

    mutating func begin(_ step: PipelineStep, at now: Date) {
        guard current != step else { return }
        if let current, states[current] == .running { states[current] = .done }
        current = step
        states[step] = .running
        stageStartedAt = now
        pausedInStage = 0
        if pausedSince != nil { pausedSince = now; pausedStages.insert(step) }
        reported = nil
        reportedEvenly = true
        stageFraction = 0
        lastAdvanceAt = now
    }

    mutating func end(_ step: PipelineStep, state: StepState, seconds taken: Double?, at now: Date) {
        states[step] = state
        if let taken { seconds[step] = taken }
        if current == step {
            current = nil
            reported = nil
            reportedEvenly = true
            stageFraction = 0
        }
        lastAdvanceAt = now
    }

    /// The tool's fraction of the running stage. `even` is true when the stage's passes are known, so the
    /// fraction moves with the work and gives a rate; with passes not known ahead (each takes half of what is
    /// left) it moves the bar but says nothing about the time left. Measured 12 Oct: the podcast-ready
    /// mastering showed 8.5 s left from that rate when 30 s remained.
    mutating func report(_ fraction: Double?, even: Bool = true, at now: Date) {
        guard let fraction else { return }
        if fraction > (reported ?? -1) { reported = fraction }
        reportedEvenly = even
    }

    mutating func pause(at now: Date) {
        guard pausedSince == nil else { return }
        pausedSince = now
        if let current { pausedStages.insert(current) }
    }

    mutating func resume(at now: Date) {
        guard let since = pausedSince else { return }
        pausedInStage += now.timeIntervalSince(since)
        pausedSince = nil
        lastAdvanceAt = now
    }

    mutating func finishAll(at now: Date) {
        if let current, states[current] == .running { states[current] = .done }
        current = nil
        finished = true
        shownOverall = 1
    }

    // MARK: Reading

    /// Seconds the running stage has worked, without the time it was paused.
    func activeElapsed(at now: Date) -> Double {
        let paused = pausedInStage + (pausedSince.map { now.timeIntervalSince($0) } ?? 0)
        return max(0, now.timeIntervalSince(stageStartedAt) - paused)
    }

    private func liveFraction(at now: Date) -> Double {
        guard let current else { return 0 }
        if current.isMetered, let reported { return min(0.99, reported) }
        let usual = weight(current)
        return min(Self.timedCap, activeElapsed(at: now) / usual)
    }

    /// The running stage's time left: from the tool's own rate when it reports one, else from the stage's
    /// runs measured on this Mac; nil when it has neither.
    private func stageTimeLeft(at now: Date) -> Double? {
        guard let current else { return states.isEmpty ? nil : 0 }
        let elapsed = activeElapsed(at: now)
        if current.isMetered, reportedEvenly, let reported, reported >= 0.02, elapsed >= 1 {
            return max(0, (1 - reported) * elapsed / reported)
        }
        guard measured.contains(current) else { return nil }
        return max(0, weight(current) - elapsed)
    }

    /// The snapshot at `now`. Moves the shown percent forward only, and notes when the stage last moved.
    mutating func snapshot(at now: Date) -> ProgressSnapshot {
        let fraction = max(stageFraction, liveFraction(at: now))
        if fraction > stageFraction + 0.0005 { lastAdvanceAt = now }
        stageFraction = fraction

        let doneWeight = plan.filter { step in
            guard let state = states[step] else { return false }
            return state == .done || state == .failed || state == .skipped
        }.reduce(0) { $0 + weight($1) }
        let runningWeight = current.map { weight($0) * fraction } ?? 0
        let computed = finished ? 1 : min(0.999, (doneWeight + runningWeight) / total)
        shownOverall = max(shownOverall, computed)

        var timeLeft: Double?
        if finished {
            timeLeft = 0
        } else if let stageLeft = stageTimeLeft(at: now) {
            var index = -1
            if let current, let at = plan.firstIndex(of: current) {
                index = at
            } else if let last = plan.lastIndex(where: { states[$0] != nil }) {
                index = last
            }
            let coming = plan.enumerated().filter { $0.offset > index && states[$0.element] == nil }.reduce(0) { $0 + weight($1.element) }
            timeLeft = stageLeft + coming
        }
        let stalled = !finished && pausedSince == nil && current != nil && now.timeIntervalSince(lastAdvanceAt) >= Self.stallSeconds

        let number = current.flatMap { plan.firstIndex(of: $0) }.map { $0 + 1 } ?? min(plan.count, plan.filter { states[$0] != nil }.count)
        let lines: [StageLine] = plan.map { step in
            let state = states[step] ?? .waiting
            switch state {
            case .running: return StageLine(step: step, state: .running, seconds: activeElapsed(at: now), usual: nil)
            case .waiting: return StageLine(step: step, state: .waiting, seconds: nil, usual: measured.contains(step) ? weight(step) : nil)
            default: return StageLine(step: step, state: state, seconds: seconds[step], usual: nil)
            }
        }
        return ProgressSnapshot(recordingID: recordingID, label: label, stage: current, stepNumber: number, stepCount: plan.count,
                                stageFraction: fraction, overall: shownOverall, timeLeft: timeLeft,
                                waitingOn: stalled ? current?.waitingLine : nil, logLine: logLine, isPaused: pausedSince != nil,
                                canPause: canPause && !finished, stages: lines, startedAt: startedAt, at: now, finished: finished)
    }
}

/// One make in progress, as the window sees it: the tracker, the meter the pipeline writes into, and the
/// snapshot, published at most twice a second.
@MainActor
@Observable
final class JobProgress {
    /// The window's view of the progress changes at most this often (design spec 3.6.1: twice a second).
    static let minimumInterval: Double = 0.5

    let recordingID: UUID
    private(set) var snapshot: ProgressSnapshot
    /// How many times the snapshot has been published (for the twice-a-second test).
    @ObservationIgnored private(set) var publishCount = 0
    @ObservationIgnored private var tracker: ProgressTracker
    @ObservationIgnored let meter: ProgressMeter
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var lastPublished: Date?
    /// Told of every published snapshot (the progress acceptance writes its trace from it).
    @ObservationIgnored var onPublish: ((ProgressSnapshot) -> Void)?

    init(tracker: ProgressTracker, meter: ProgressMeter = ProgressMeter(), clock: @escaping () -> Date = Date.init) {
        self.recordingID = tracker.recordingID
        self.tracker = tracker
        self.meter = meter
        self.clock = clock
        var copy = tracker
        snapshot = copy.snapshot(at: clock())
    }

    var isPaused: Bool { tracker.isPaused }
    var pausedStages: Set<PipelineStep> { tracker.pausedStages }

    /// The pipeline's own report: which step runs, which finished, with their seconds.
    func apply(steps: [RunStep], current: PipelineStep?) {
        let now = clock()
        for step in steps {
            guard let stage = PipelineStep(title: step.name) else { continue }
            switch step.state {
            case .done, .failed, .skipped:
                if tracker.states[stage] == nil || tracker.states[stage] == .running {
                    tracker.end(stage, state: step.state, seconds: step.seconds, at: now)
                }
            case .running, .waiting:
                break
            }
        }
        if let current { tracker.begin(current, at: now) }
        tracker.canPause = current != .writing
        refresh()
    }

    func begin(_ step: PipelineStep) {
        tracker.begin(step, at: clock())
        tracker.canPause = step != .writing
        refresh()
    }

    /// Pause and Resume show at the next publish the half-second rule allows (the ticker's, within 0.5 s).
    func pause() {
        tracker.pause(at: clock())
        refresh()
    }

    func resume() {
        tracker.resume(at: clock())
        refresh()
    }

    /// The make has ended: 100% is published, after waiting out what is left of the half second since the
    /// last one, so even the last update keeps to twice a second.
    func finish(sleep: (Double) async -> Void = { try? await Task.sleep(for: .seconds($0)) }) async {
        tracker.finishAll(at: clock())
        if let last = lastPublished {
            let wait = Self.minimumInterval - clock().timeIntervalSince(last)
            if wait > 0 { await sleep(wait + 0.001) }
        }
        refresh()
        ended = true
    }

    /// Set once the last snapshot is out: nothing is published after it.
    @ObservationIgnored private var ended = false

    /// Reads the meter and publishes a new snapshot, unless one was published less than half a second ago:
    /// no exception, so the window never sees more than two a second.
    func refresh() {
        guard !ended else { return }
        let now = clock()
        let state = meter.current
        if state.step == tracker.current { tracker.report(ProgressMeter.stageFraction(state), even: state.passes != nil, at: now) }
        if let line = state.line { tracker.logLine = line }
        if let last = lastPublished, now.timeIntervalSince(last) < Self.minimumInterval { return }
        // Published even when nothing moved: the stall line and a timed stage depend on the clock alone.
        let next = tracker.snapshot(at: now)
        lastPublished = now
        publishCount += 1
        if next != snapshot { snapshot = next }
        onPublish?(next)
    }
}
