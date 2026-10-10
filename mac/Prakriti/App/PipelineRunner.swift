import Foundation
import Observation
import SwiftData

/// Runs recordings through the pipeline one at a time, as engine v0 does, and writes what happens
/// onto the recording, its run, Activity and the log. The watcher feeds the queue, and so do Process
/// File and a recording's Make Outputs button. It posts the notices (Found, Started, Ready, Needs a
/// decision, Couldn't finish) and gives automatic work three tries before Couldn't finish.
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
    @ObservationIgnored private var activeTrigger: RunTrigger = .byHand
    @ObservationIgnored private var activeOptions = PipelineOptions()

    /// Automatic tries before Couldn't finish (engine v0: three).
    static let maxTries = 3

    /// Seconds of work per second of recording, after the 60 s readiness wait. Measured 10 Oct:
    /// the 13 Sep talk took 36 s for 15:48 (0.038), the 6 Sep talk 124 s for 55:39 (0.037). Used
    /// only for the "about N minutes" in Started.
    static let workPerSecond = 0.04

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

    /// The options for this recording: which outputs, from its own switches, then its folder's,
    /// then the defaults; and how each is made, from its own settings, else the Outputs screen's.
    func options(for recording: Recording) -> PipelineOptions {
        var options = PipelineOptions()
        options.stableWait = stableWait
        options.checksOnly = recording.intent == .check
        guard let model else { return options }
        let defaults = model.defaultSettings()
        let make = OutputResolver.outputsToMake(recording: recording, source: nil, defaults: defaults)
        options.makeEpisode = make.contains(.podcastEpisode)
        options.makeTranscript = make.contains(.transcript)
        options.makeReport = make.contains(.checksAndReport)
        if let podcast = OutputResolver.details(for: .podcastEpisode, recording: recording, defaults: defaults) {
            options.loudnessTarget = podcast.loudnessTarget
            options.peakCeiling = podcast.peakCeiling
            options.trimSilence = podcast.trimSilence
            options.introPath = podcast.introPath
            options.outroPath = podcast.outroPath
            options.channels = podcast.channels
        }
        if let transcript = OutputResolver.details(for: .transcript, recording: recording, defaults: defaults) {
            options.transcriptFormats = transcript.transcriptFormats
            options.applyLexicon = transcript.applyLexicon
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

        // Keep the Mac from idle sleep while this one runs, and released when it ends, so a crash can
        // never pin the Mac awake (SCOPE 7.2). App Nap would otherwise slow a windowless Prakriti.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                                                             reason: "Prakriti is working on a recording.")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        activeTrigger = trigger
        activeOptions = options

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

        model.record("Started \(recording.fileName) (\(trigger.title.lowercased())). "
                     + (options.checksOnly ? "Checking it is complete and has sound; nothing is made." : "Checking it is complete first."), run: run)
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
        switch progress.moment {
        case .fileReady:
            // Found, only for what Prakriti found itself: a file Ivan just chose needs no news.
            // An "Ask me first" recording is announced once its checks pass.
            if activeTrigger.isAutomatic && !activeOptions.checksOnly {
                model.notifier.post(.found, facts(for: recording))
            }
        case .soundOK:
            var facts = facts(for: recording)
            facts.estimate = recording.duration.map { $0 * Self.workPerSecond }
            model.notifier.post(.started, facts)
        case nil:
            break
        }
    }

    private func facts(for recording: Recording) -> NoticeFacts {
        var facts = NoticeFacts(recording)
        facts.makesEpisode = activeOptions.makeEpisode
        facts.makesTranscript = activeOptions.makeTranscript
        return facts
    }

    private func finish(_ result: PipelineResult, recording: Recording, run: Run, label: String) {
        guard let model else { return }
        run.steps = result.steps.isEmpty ? run.steps : result.steps
        run.endedAt = model.now()
        recording.currentStep = nil
        recording.updatedAt = model.now()
        if let duration = result.duration { recording.duration = duration }
        if result.sizeBytes > 0 { recording.sizeBytes = result.sizeBytes }
        if let volume = result.volume {
            recording.loudestDB = volume.max.isFinite ? volume.max : nil
            recording.averageDB = volume.mean.isFinite ? volume.mean : nil
        }
        // What was made is written only when a make finishes: until then the files of the last
        // finished make are still in the folder, so their numbers stay. Something not made this
        // time (a transcript turned off) has no numbers.
        if result.outcome == .ready {
            recording.inputLUFS = result.inputLUFS
            recording.loudnessLUFS = result.output?.integratedLUFS
            recording.truePeakDBFS = result.output?.truePeakDBFS
            recording.episodeDuration = result.output == nil ? nil : result.episodeDuration
            recording.silenceTrimmedStart = result.trimmedStart
            recording.silenceTrimmedEnd = result.trimmedEnd
            recording.transcriptReaches = result.transcriptReaches
            recording.wordCount = result.wordCount
            recording.coverageOK = result.coverageOK
            recording.wordListFixes = activeOptions.makeTranscript && activeOptions.applyLexicon ? result.corrections.count : nil
            recording.outputFolder = result.outputFolder?.path
            recording.madeFiles = result.files
        }
        recording.statusReason = result.reason

        let name = recording.fileName
        let automatic = recording.intent != .none
        if result.outcome != .failed && result.outcome != .stopped {
            recording.intent = .none
            recording.failedTries = 0
        }
        switch result.outcome {
        case .checked:
            recording.status = .found
            run.outcome = .checked
            run.summary = "Checked. Waiting for your choice."
            model.record("\(label) (\(name)) is complete and has sound. It waits for you: nothing is made until you choose Make Outputs.", run: run)
            var facts = facts(for: recording)
            facts.askFirst = true
            model.notifier.post(.found, facts)
        case .ready:
            recording.status = .readyForYourYes
            run.outcome = .ready
            run.summary = "Ready for your yes."
            var facts = facts(for: recording)
            if result.coverageOK == false, let reaches = result.transcriptReaches, let duration = result.duration {
                facts.coverageGap = duration - reaches
            }
            model.notifier.post(.ready, facts)
            var numbers: [String] = []
            if let out = result.output { numbers.append("\(Format.lufs(out.integratedLUFS)), peak \(Format.dbfs(out.truePeakDBFS))") }
            if let reaches = result.transcriptReaches, let duration = result.duration {
                numbers.append("transcript \(result.coverageOK == true ? "reaches" : "STOPS at") \(Format.timecode(reaches)) of \(Format.timecode(duration))")
            }
            if activeOptions.makeTranscript && activeOptions.applyLexicon {
                numbers.append("word list \(Format.count(result.corrections.count, "fix", "fixes"))")
            }
            if let start = result.trimmedStart, let end = result.trimmedEnd, start + end >= 0.05 {
                numbers.append(String(format: "%.1f s of silence trimmed", start + end))
            }
            model.record("\(label) (\(name)) is ready for your yes, made in \(Format.length(result.seconds))" + (numbers.isEmpty ? "." : ": " + numbers.joined(separator: ", ") + "."),
                         level: result.coverageOK == false ? .attention : .info, run: run)
            if !result.replaced.isEmpty {
                let gone = result.replaced.filter { !result.files.contains($0) }
                model.record("Made again: the earlier files were replaced" + (gone.isEmpty ? "." : ", and \(gone.joined(separator: ", ")) removed because \(gone.count == 1 ? "it was" : "they were") not chosen this time."),
                             run: run)
            }
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
            var facts = facts(for: recording)
            facts.noAudioTrack = result.hasAudio == false
            model.notifier.post(.needsADecision, facts)
        case .failed:
            run.outcome = .couldntFinish
            run.summary = result.reason
            let stoppedIn = result.steps.first { $0.state == .failed }.flatMap { step in PipelineStep.allCases.first { $0.title == step.name } }
            if automatic {
                // Automatic work gets three tries, at the regular checks, before anyone is told
                // (engine v0's rule; SCOPE 8.7: a passing failure a retry fixes says nothing).
                recording.failedTries += 1
                if recording.failedTries < Self.maxTries {
                    recording.status = .found
                    recording.statusReason = "Try \(recording.failedTries) of \(Self.maxTries) stopped. \(result.reason) Prakriti tries again at the next check, within 5 minutes."
                    model.record("Couldn't finish \(name) (try \(recording.failedTries) of \(Self.maxTries)). \(result.reason) Trying again at the next check.",
                                 level: .attention, run: run)
                    break
                }
            }
            let tries = automatic ? recording.failedTries : 1
            recording.status = .couldntFinish
            recording.intent = .none
            recording.statusReason = result.reason + (tries >= Self.maxTries ? " Tried three times." : "") + " The original is untouched."
            model.record("Couldn't finish \(name)" + (tries >= Self.maxTries ? " after three tries" : "") + ". \(result.reason) The original is untouched.",
                         level: .problem, run: run)
            var facts = facts(for: recording)
            facts.tries = tries
            facts.stoppedWhile = stoppedIn?.doing
            model.notifier.post(.couldntFinish, facts)
        case .stopped:
            run.outcome = .stopped
            run.summary = result.reason
            if automatic && recording.failedTries + 1 < Self.maxTries {
                // Counted as a try, so a file that stops Prakriti every time cannot loop forever.
                recording.failedTries += 1
                recording.status = .found
                recording.statusReason = "Stopped before it finished. It starts again at the next check; the original is untouched."
            } else {
                recording.status = .couldntFinish
                recording.intent = .none
            }
            model.record("Stopped \(name) before it finished. The original is untouched.", level: .attention, run: run)
        }
        try? model.context.save()
    }
}
