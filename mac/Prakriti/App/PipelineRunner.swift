import Foundation
import Observation
import SwiftData

/// Runs recordings through the pipeline one at a time, as engine v0 does, and writes what happens
/// onto the recording, its run, Activity and the log. The watcher (milestone 3) feeds the same
/// queue; until then, Process File and a recording's Make Outputs button do.
@MainActor
@Observable
final class PipelineRunner {
    @ObservationIgnored weak var model: AppModel?
    @ObservationIgnored var tools: ToolPaths = .standard
    /// How long a file's size must hold still before work starts. 60 s, as engine v0 waits; the
    /// acceptance test shortens it, because its files are long finished.
    @ObservationIgnored var stableWait: Duration = .seconds(60)

    /// Recordings waiting their turn, and the one being worked on (by Recording.id), for the UI.
    private(set) var waitingIDs: [UUID] = []
    private(set) var currentID: UUID?

    @ObservationIgnored private var queue: [(recording: Recording, trigger: RunTrigger)] = []
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var activeRecording: Recording?
    @ObservationIgnored private var activeRun: Run?

    func isWaiting(_ recording: Recording) -> Bool { waitingIDs.contains(recording.id) }
    func isCurrent(_ recording: Recording) -> Bool { currentID == recording.id }

    /// Puts a recording in line. It starts when nothing else is running and Pause All is off.
    func enqueue(_ recording: Recording, trigger: RunTrigger) {
        guard let model, !isCurrent(recording), !isWaiting(recording) else { return }
        queue.append((recording, trigger))
        waitingIDs.append(recording.id)
        if model.settings.isPaused {
            model.record("\(recording.fileName) waits until you resume: Pause All is on.")
        }
        pump()
    }

    /// Picks up the queue again, after Resume All.
    func resume() { pump() }

    /// Stops the running tool and clears the line. Used when Prakriti quits; the recording that was
    /// running is marked Couldn't finish on the next launch.
    func stopAll() {
        queue.removeAll()
        waitingIDs.removeAll()
        loop?.cancel()
    }

    private func pump() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while let self, !Task.isCancelled, let next = self.takeNext() {
                await self.process(next.recording, trigger: next.trigger)
            }
            self?.loop = nil
        }
    }

    private func takeNext() -> (recording: Recording, trigger: RunTrigger)? {
        guard let model, !model.settings.isPaused, !queue.isEmpty else { return nil }
        let next = queue.removeFirst()
        waitingIDs.removeAll { $0 == next.recording.id }
        return next
    }

    /// The options for this recording: its outputs and loudness, read from its own settings, then
    /// its folder's, then the defaults.
    func options(for recording: Recording) -> PipelineOptions {
        var options = PipelineOptions()
        options.stableWait = stableWait
        guard let model else { return options }
        let defaults = model.defaultSettings()
        let make = OutputResolver.outputsToMake(recording: recording, source: nil, defaults: defaults)
        options.makeEpisode = make.contains(.podcastEpisode)
        options.makeTranscript = make.contains(.transcript)
        options.makeReport = make.contains(.checksAndReport)
        if let podcast = OutputResolver.setting(for: .podcastEpisode, recording: recording, source: nil, defaults: defaults) {
            options.loudnessTarget = podcast.loudnessTarget
            options.peakCeiling = podcast.peakCeiling
        }
        return options
    }

    /// Runs one recording now and waits for it. Outputs go to the mode's Outputs folder, in a
    /// folder named after the file (engine v0's layout), never inside the shared iCloud folder.
    @discardableResult
    func process(_ recording: Recording, trigger: RunTrigger) async -> PipelineResult? {
        guard let model else { return nil }
        currentID = recording.id
        defer { currentID = nil; activeRecording = nil; activeRun = nil }

        let file = URL(fileURLWithPath: recording.filePath)
        let folder = model.paths.outputs.appending(path: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        let label = Format.dayLabel(recording.sessionDate)
        let options = options(for: recording)

        let run = Run(startedAt: model.now(), trigger: trigger, steps: options.plannedSteps.map { RunStep(name: $0.title, state: .waiting) })
        model.context.insert(run)
        run.recording = recording
        recording.status = .working
        recording.statusReason = nil
        recording.currentStep = PipelineStep.complete.doing
        recording.updatedAt = model.now()
        activeRecording = recording
        activeRun = run

        guard model.paths.isSafeOutputLocation(folder) else {
            // Never reached with the app's own paths; kept because the rule must hold whatever
            // the paths become.
            var refused = PipelineResult()
            refused.outcome = .failed
            refused.reason = "Its outputs would land inside the shared iCloud folder or Documents, so nothing was made."
            finish(refused, recording: recording, run: run, label: label)
            return refused
        }

        model.record("Started \(recording.fileName) (\(trigger.title.lowercased())). Checking it is complete first.", run: run)
        let pipeline = Pipeline(tools: tools, options: options, log: model.log)
        let result = await pipeline.run(file: file, outputFolder: folder, label: label) { [weak self] progress in
            await self?.apply(progress)
        }
        finish(result, recording: recording, run: run, label: label)
        return result
    }

    private func apply(_ progress: PipelineProgress) {
        guard let model, let recording = activeRecording, let run = activeRun else { return }
        run.steps = progress.steps
        if let current = progress.current { recording.currentStep = current.doing }
        if let duration = progress.duration { recording.duration = duration }
        recording.updatedAt = model.now()
        try? model.context.save()
    }

    private func finish(_ result: PipelineResult, recording: Recording, run: Run, label: String) {
        guard let model else { return }
        run.steps = result.steps.isEmpty ? run.steps : result.steps
        run.endedAt = model.now()
        recording.currentStep = nil
        recording.updatedAt = model.now()
        if let duration = result.duration { recording.duration = duration }
        if result.sizeBytes > 0 { recording.sizeBytes = result.sizeBytes }
        recording.loudestDB = result.volume.map(\.max).flatMap { $0.isFinite ? $0 : nil }
        recording.averageDB = result.volume.map(\.mean).flatMap { $0.isFinite ? $0 : nil }
        recording.inputLUFS = result.inputLUFS
        recording.loudnessLUFS = result.output?.integratedLUFS
        recording.truePeakDBFS = result.output?.truePeakDBFS
        recording.transcriptReaches = result.transcriptReaches
        recording.wordCount = result.wordCount
        recording.coverageOK = result.coverageOK
        recording.outputFolder = result.outputFolder?.path
        recording.statusReason = result.reason

        let name = recording.fileName
        switch result.outcome {
        case .ready:
            recording.status = .readyForYourYes
            run.outcome = .ready
            run.summary = "Ready for your yes."
            var numbers: [String] = []
            if let out = result.output { numbers.append("\(Format.lufs(out.integratedLUFS)), peak \(Format.dbfs(out.truePeakDBFS))") }
            if let reaches = result.transcriptReaches, let duration = result.duration {
                numbers.append("transcript \(result.coverageOK == true ? "reaches" : "STOPS at") \(Format.timecode(reaches)) of \(Format.timecode(duration))")
            }
            model.record("\(label) (\(name)) is ready for your yes, made in \(Format.length(result.seconds))" + (numbers.isEmpty ? "." : ": " + numbers.joined(separator: ", ") + "."),
                         level: result.coverageOK == false ? .attention : .info, run: run)
        case .test:
            recording.status = .skipped
            recording.kind = .test
            run.outcome = .skippedTest
            run.summary = "Filed as a test."
            model.record("Filed \(name) as a test (\(result.duration.map { Format.length($0) } ?? "under 60 s")). Nothing made, no notice sent.", run: run)
        case .silent:
            recording.status = .needsADecision
            run.outcome = .needsADecision
            run.summary = "No usable sound."
            let loudest = result.hasAudio == false ? "no audio track" : "loudest point \(Pipeline.db(result.volume?.max ?? -.infinity))"
            model.record("\(label) (\(name)) has no usable sound (\(loudest)). Needs a decision. Nothing was made.", level: .attention, run: run)
        case .failed:
            recording.status = .couldntFinish
            run.outcome = .couldntFinish
            run.summary = result.reason
            model.record("Couldn't finish \(name). \(result.reason) The original is untouched.", level: .problem, run: run)
        case .stopped:
            recording.status = .couldntFinish
            run.outcome = .stopped
            run.summary = result.reason
            model.record("Stopped \(name) before it finished. The original is untouched.", level: .attention, run: run)
        }
        try? model.context.save()
    }
}
