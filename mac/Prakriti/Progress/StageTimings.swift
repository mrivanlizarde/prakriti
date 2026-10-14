import Foundation
import SwiftData

// How long each stage of a make takes on this Mac (v2 part M4a, docs/v2/PLAN.md M4). The overall percent
// is weighted by these, so a one-second check is not worth as much as a twenty-second mastering pass, and
// the time left is worked out from them. Each stage keeps its last 10 measured runs: seconds taken and the
// length of the recording it worked on.

/// One measured run of one stage.
struct StageSample: Codable, Hashable, Sendable {
    /// Seconds the stage took, with any time it was paused taken out.
    var seconds: Double
    /// The length of the recording it worked on, in seconds.
    var mediaSeconds: Double
    var at: Date
}

/// The measured runs of one stage (SwiftData, an addition in v2 part M4a: every property has a default, so
/// an older store opens with none and `make migrate-check` proves it).
@Model
final class StageTiming {
    @Attribute(.unique) var id: UUID = UUID()
    /// `PipelineStep.rawValue`.
    var stageRaw: String = ""
    /// Newest last, at most `StageTimings.kept`.
    var samples: [StageSample] = []

    init(stage: PipelineStep, samples: [StageSample] = []) {
        self.id = UUID()
        self.stageRaw = stage.rawValue
        self.samples = samples
    }

    var stage: PipelineStep? { PipelineStep(rawValue: stageRaw) }
}

/// What the stages usually take, read from the store once per make: the rate each stage measured on this
/// Mac, or none. Pure, so the progress tests can give their own.
struct StageTimings: Sendable, Equatable {
    /// Samples kept per stage: a running average of the last 10 runs (docs/v2/PLAN.md M4).
    static let kept = 10

    var samples: [PipelineStep: [StageSample]] = [:]

    /// True when this stage has a run measured on this Mac. Only then is a time left shown for it.
    func isMeasured(_ step: PipelineStep) -> Bool { !(samples[step] ?? []).isEmpty }

    /// Seconds per minute of recording, averaged over the kept runs (total seconds over total minutes).
    func secondsPerMediaMinute(_ step: PipelineStep) -> Double? {
        guard let list = samples[step], !list.isEmpty else { return nil }
        let minutes = list.reduce(0) { $0 + $1.mediaSeconds } / 60
        guard minutes > 0 else { return nil }
        return list.reduce(0) { $0 + $1.seconds } / minutes
    }

    /// The average seconds of a whole run of the stage, whatever the length.
    func averageSeconds(_ step: PipelineStep) -> Double? {
        guard let list = samples[step], !list.isEmpty else { return nil }
        return list.reduce(0) { $0 + $1.seconds } / Double(list.count)
    }

    /// How long a stage usually takes on a recording this long, in seconds. Measured on this Mac when it
    /// can be, else the numbers measured here on 12 Oct (`StageTimings.firstGuess`), which weight the
    /// percent but never give a time left on their own (`isMeasured`).
    ///
    /// Two stages are not per minute of recording. Checking the file is complete is the wait for its size to
    /// hold still (60 s in the app), whatever the length. Writing the titles and notes barely grows with the
    /// length (1,608 s for the 15:48 talk and 1,456 s for the 55:39 one, BUILD-LOG 11 Oct), so it is the
    /// average of its runs.
    func expectedSeconds(_ step: PipelineStep, mediaSeconds: Double, stableWait: Double) -> Double {
        let minutes = max(mediaSeconds, 1) / 60
        switch step {
        case .complete:
            return stableWait + 1
        case .writing:
            return averageSeconds(.writing) ?? (WritingEstimate.fixed + mediaSeconds * WritingEstimate.perSecond)
        default:
            let rate = secondsPerMediaMinute(step) ?? Self.firstGuess[step] ?? 0
            return max(Self.floor, rate * minutes)
        }
    }

    /// The smallest weight a stage has, so a stage that takes no measurable time still moves the bar a little.
    static let floor = 0.2

    /// Seconds per minute of recording for each stage, measured on this Mac (M5 Pro) on Mon 12 Oct 2026
    /// from the development log of `make accept-edits` on the 13 Sep talk (15:48, three runs: sound 0.6 s,
    /// audio for the transcript 0.5 s, transcript 10.7 s, silence 0.6 s, episode audio 21.2 to 22.2 s,
    /// loudness 1.7 to 1.8 s), and from BUILD-LOG 10 Oct for the podcast-ready episode (40 s for 15:48, about
    /// 36 of them mastering). Used only until this Mac has measured the stage itself.
    /// The capture check (v2 part M4b) was measured the same day: 3.2 s for the 15:48 talk's one stereo track.
    /// Faces (v2 part M6a) too: 30.1 s for the 15:48 talk and 120 s for the 55:39 one, with the capture quality,
    /// about 2 s a minute. Voices (v2 part M6b): a first guess of half a second a minute (the diarizer runs at
    /// about 300 times real time, research-people.md 2.5), replaced by this Mac's own measure after one run. Names said
    /// aloud and People left out (v2 part M6c) are arithmetic on the transcript; who is heard in the episode runs the
    /// diarizer twice, on the original and on what was made, so it starts from the voice step's guess. Planning the edit
    /// (v2 part M8a) took 1.1 s for the 15:48 talk on Tue 13 Oct (decoding the sound and the rough cut), about 0.07 s a
    /// minute.
    static let firstGuess: [PipelineStep: Double] = [
        .capture: 0.21, .sound: 0.04, .speechAudio: 0.035, .transcript: 0.68, .coverage: 0.0, .wordList: 0.0, .namesSaid: 0.0, .faces: 2.0, .voices: 0.5,
        .trim: 0.04, .edits: 0.0, .leaveOut: 0.0, .planEdit: 0.07, .episode: 1.4, .loudness: 0.11, .podcastAudio: 2.3, .audioCheck: 0.5,
        .episodeTranscript: 0.0, .podcastPackage: 0.25, .report: 0.0,
    ]

    /// The stages that learn from a run. Checking the file is complete is the readiness wait, so its time
    /// says nothing about this Mac.
    static func learns(_ step: PipelineStep) -> Bool { step != .complete }

    /// A new sample added to a list, keeping the last `kept`.
    static func adding(_ sample: StageSample, to list: [StageSample]) -> [StageSample] {
        Array((list + [sample]).suffix(kept))
    }

    // MARK: The store

    /// What the store holds, as a value.
    @MainActor
    static func load(_ context: ModelContext) -> StageTimings {
        var timings = StageTimings()
        for row in (try? context.fetch(FetchDescriptor<StageTiming>())) ?? [] {
            guard let stage = row.stage else { continue }
            timings.samples[stage, default: []] += row.samples
        }
        for (stage, list) in timings.samples { timings.samples[stage] = Array(list.sorted { $0.at < $1.at }.suffix(kept)) }
        return timings
    }

    /// Records the steps a make finished, each with the time it really took. A step that was paused, failed
    /// or skipped is not recorded.
    @MainActor
    static func record(_ steps: [RunStep], mediaSeconds: Double, at date: Date, excluding paused: Set<PipelineStep>, in context: ModelContext) {
        guard mediaSeconds > 0 else { return }
        let rows = (try? context.fetch(FetchDescriptor<StageTiming>())) ?? []
        for step in steps where step.state == .done {
            guard let stage = PipelineStep(title: step.name), learns(stage), !paused.contains(stage),
                  let seconds = step.seconds, seconds.isFinite, seconds >= 0 else { continue }
            let sample = StageSample(seconds: seconds, mediaSeconds: mediaSeconds, at: date)
            if let row = rows.first(where: { $0.stageRaw == stage.rawValue }) {
                row.samples = adding(sample, to: row.samples)
            } else {
                context.insert(StageTiming(stage: stage, samples: [sample]))
            }
        }
        try? context.save()
    }

    /// At first launch, the stages are seeded from the steps of the makes already in the store (v1's own
    /// `RunStep` history): each step that finished, with its seconds and its recording's length, newest 10
    /// per stage. Returns how many samples it found. Never runs twice: once any row exists it does nothing.
    @MainActor
    @discardableResult
    static func seedIfEmpty(_ context: ModelContext) -> Int {
        guard ((try? context.fetchCount(FetchDescriptor<StageTiming>())) ?? 0) == 0 else { return 0 }
        let runs = ((try? context.fetch(FetchDescriptor<Run>())) ?? []).sorted { $0.startedAt < $1.startedAt }
        var found: [PipelineStep: [StageSample]] = [:]
        for run in runs {
            guard let media = run.recording?.duration, media > 0 else { continue }
            for step in run.steps where step.state == .done {
                guard let stage = PipelineStep(title: step.name), learns(stage), let seconds = step.seconds, seconds.isFinite, seconds >= 0 else { continue }
                found[stage, default: []].append(StageSample(seconds: seconds, mediaSeconds: media, at: run.startedAt))
            }
        }
        var count = 0
        for (stage, list) in found {
            let kept = Array(list.suffix(Self.kept))
            count += kept.count
            context.insert(StageTiming(stage: stage, samples: kept))
        }
        if count > 0 { try? context.save() }
        return count
    }
}

extension PipelineStep {
    /// The step a stored `RunStep` names (runs keep the title, the words the inspector lists).
    init?(title: String) {
        guard let step = PipelineStep.allCases.first(where: { $0.title == title }) else { return nil }
        self = step
    }
}
