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
    /// Makes the model clients for writing. Nil: the real ones. Tests set it to see which provider
    /// the privacy lock let through, without calling any model.
    @ObservationIgnored var makeClient: (@Sendable (ModelProvider, WritingSetup) -> any LanguageModelClient)?
    /// Tests only: the cloud client the privacy lock wraps (v2 part M5a), to count what reaches it.
    @ObservationIgnored var makeCloudClient: (@Sendable (ModelProvider, WritingSetup) -> any CloudModelClient)?

    /// Recordings waiting their turn, and the one being worked on (by Recording.id), for the UI.
    private(set) var waitingIDs: [UUID] = []
    private(set) var currentID: UUID?
    /// The progress of the make running now (v2 part M4a): stage, percent, time left, the latest line.
    private(set) var currentJob: JobProgress?
    /// Waiting recordings Ivan paused: they keep their place in line and are passed over until resumed.
    private(set) var heldIDs: Set<UUID> = []
    /// Ends the make running now, so Stop can end it and nothing else (v2 part M4a).
    @ObservationIgnored private var cancelActive: (() -> Void)?
    /// Reads the running make's progress twice a second.
    @ObservationIgnored private var progressTicker: Task<Void, Never>?
    /// The recording Ivan stopped, so its end is told as his choice rather than a failure.
    @ObservationIgnored private var stoppedByHand: UUID?
    /// The status the running recording had before this make, for a Stop that leaves its earlier files.
    @ObservationIgnored private var statusBefore: RecordingStatus?
    /// Told of every progress snapshot published (the progress acceptance writes its trace from it).
    @ObservationIgnored var onProgress: ((ProgressSnapshot) -> Void)?

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
    /// The podcast-ready audio and files, per second of recording. Measured 10 Oct: 40 s for the 15:48
    /// talk, 193 s for the 55:39 one (with the two-decimal meter), so about 0.05.
    static let podcastReadyPerSecond = 0.05

    /// About how long the titles, show notes and chapters take with Qwen3.8-27B in LM Studio, for
    /// the "about N minutes" in Started. Measured 10 Oct on the 15:48 talk (milestone 6's acceptance).
    static func writingEstimate(_ duration: Double) -> Double {
        WritingEstimate.fixed + duration * WritingEstimate.perSecond
    }

    func isWaiting(_ recording: Recording) -> Bool { waitingIDs.contains(recording.id) }
    /// The recordings waiting their turn, in the order they will be made (In Progress lists them so).
    var waitingOrder: [UUID] { waitingIDs }
    func isCurrent(_ recording: Recording) -> Bool { currentID == recording.id }
    func isHeld(_ recording: Recording) -> Bool { heldIDs.contains(recording.id) }

    /// The progress of this recording's make, while it runs.
    func progress(for recording: Recording) -> ProgressSnapshot? {
        guard let job = currentJob, job.recordingID == recording.id else { return nil }
        return job.snapshot
    }

    /// Puts a recording in line. It starts when nothing else is running and Pause All is off.
    func enqueue(_ recording: Recording, trigger: RunTrigger) {
        guard let model, !isCurrent(recording), !isWaiting(recording) else { return }
        queue.append((recording, trigger))
        waitingIDs.append(recording.id)
        noteUsual(recording)
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
        heldIDs.removeAll()
        currentJob?.meter.control.resume()
        cancelActive?()
        loop?.cancel()
        progressTicker?.cancel()
    }

    // MARK: Pause, Stop and the order of the line (v2 part M4a, design spec 3.6.3)

    /// Pause on a recording: the make running now holds where it is (its tool is suspended, and the next
    /// one waits); a waiting recording keeps its place and is passed over. Writing cannot be held: a request
    /// to a writing model is under way, so Pause is not offered then.
    func pause(_ recording: Recording) {
        guard let model else { return }
        let label = Format.dayLabel(recording.sessionDate)
        if let job = currentJob, job.recordingID == recording.id {
            guard job.snapshot.canPause, !job.isPaused else { return }
            job.meter.control.pause()
            job.pause()
            model.record("Paused \(label) (\(recording.fileName)) while \(job.snapshot.stageName.lowercasedFirst). It holds there until you resume it.")
        } else if isWaiting(recording), !heldIDs.contains(recording.id) {
            heldIDs.insert(recording.id)
            model.record("Paused \(label) (\(recording.fileName)) in line. It keeps its place and starts once you resume it.")
        }
        model.noteStatusLine()
    }

    func resume(_ recording: Recording) {
        guard let model else { return }
        let label = Format.dayLabel(recording.sessionDate)
        if let job = currentJob, job.recordingID == recording.id, job.isPaused {
            job.meter.control.resume()
            job.resume()
            model.record("Resumed \(label) (\(recording.fileName)).")
        } else if heldIDs.contains(recording.id) {
            heldIDs.remove(recording.id)
            model.record("Resumed \(label) (\(recording.fileName)) in line.")
            pump()
        }
        model.noteStatusLine()
    }

    /// Stop on a recording: the make running now ends (the files of its last finished make are as they were,
    /// Mac warning 29), or a waiting one leaves the line. Nothing restarts it on its own.
    func stop(_ recording: Recording) {
        guard let model else { return }
        let label = Format.dayLabel(recording.sessionDate)
        if isCurrent(recording), let cancel = cancelActive {
            stoppedByHand = recording.id
            currentJob?.meter.control.resume()
            cancel()
            model.record("Stopping \(label) (\(recording.fileName)) at your request.")
        } else if isWaiting(recording) {
            queue.removeAll { $0.recording.id == recording.id }
            waitingIDs.removeAll { $0 == recording.id }
            heldIDs.remove(recording.id)
            recording.intent = .none
            recording.statusReason = "Taken out of the line by you. Choose Make Outputs to start it."
            try? model.context.save()
            model.record("Took \(label) (\(recording.fileName)) out of the line. Nothing was made; choose Make Outputs to start it.")
        }
        model.noteStatusLine()
    }

    /// Make Next: a waiting recording moves to the front of the line.
    func makeNext(_ recording: Recording) {
        guard let model, let index = queue.firstIndex(where: { $0.recording.id == recording.id }), index > 0 else { return }
        let item = queue.remove(at: index)
        queue.insert(item, at: 0)
        waitingIDs.removeAll { $0 == recording.id }
        waitingIDs.insert(recording.id, at: 0)
        model.record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)) is next in line.")
    }

    /// Whether Stop can end this recording's make or take it out of the line.
    func canStop(_ recording: Recording) -> Bool {
        (isCurrent(recording) && cancelActive != nil) || isWaiting(recording)
    }

    /// Whether Pause is offered: the make running now while its stage can be held, or a waiting recording.
    func canPause(_ recording: Recording) -> Bool {
        if let job = currentJob, job.recordingID == recording.id { return job.snapshot.canPause && !job.isPaused && cancelActive != nil }
        return isWaiting(recording) && !heldIDs.contains(recording.id)
    }

    func canResume(_ recording: Recording) -> Bool {
        if let job = currentJob, job.recordingID == recording.id { return job.isPaused }
        return heldIDs.contains(recording.id)
    }

    // MARK: Time

    /// How long a make of this recording usually takes here, in seconds, or nil when its length is not known.
    func expectedSeconds(for recording: Recording, timings: StageTimings) -> Double? {
        guard let duration = recording.duration, duration > 0 else { return nil }
        let options = options(for: recording)
        let wait = Double(options.stableWait.components.seconds)
        return options.plannedSteps.reduce(0) { $0 + timings.expectedSeconds($1, mediaSeconds: duration, stableWait: wait) }
    }

    /// How long each recording in the line usually takes here, worked out once when it joins the line (and
    /// again when a make starts), so the toolbar and the Activity window read numbers instead of fetching the
    /// store each time they draw. Reason (12 Oct): with the fetch in the toolbar's button, `make look`'s
    /// Command-Option-I check failed 2 of 3 times while a make was shown.
    @ObservationIgnored private var usualSeconds: [UUID: Double] = [:]

    /// The usual time of a recording in the line, or nil when its length is not known.
    func usual(for recording: Recording) -> Double? {
        if let known = usualSeconds[recording.id] { return known }
        guard let model, let seconds = expectedSeconds(for: recording, timings: StageTimings.load(model.context)) else { return nil }
        usualSeconds[recording.id] = seconds
        return seconds
    }

    private func noteUsual(_ recording: Recording) {
        usualSeconds[recording.id] = nil
        _ = usual(for: recording)
    }

    /// The whole line's progress, for the toolbar's Activity button: the make running now and the ones
    /// waiting, each weighted by how long it usually takes. Nil when nothing runs.
    func queueFraction() -> Double? {
        guard let job = currentJob else { return nil }
        let runningTotal = usualSeconds[job.recordingID] ?? 1
        let waitingTotal = waitingIDs.compactMap { usualSeconds[$0] }.reduce(0, +)
        return (runningTotal * job.snapshot.overall) / max(1, runningTotal + waitingTotal)
    }

    /// The whole line's time left: the running make's, then each waiting one's usual time. Nil while the
    /// running make has no time left yet, or a waiting recording's length is not known.
    func queueTimeLeft() -> Double? {
        guard let job = currentJob, let running = job.snapshot.timeLeft else { return nil }
        var total = running
        for id in waitingIDs where !heldIDs.contains(id) {
            guard let usual = usualSeconds[id] else { return nil }
            total += usual
        }
        return total
    }

    // MARK: Sample progress (snapshots and window captures only)

    /// Shows a make in progress and a line of waiting recordings without running anything: the snapshots and
    /// the window captures draw the progress from it. Never called by the running app.
    func showSample(job: JobProgress?, waiting: [UUID], held: Set<UUID> = []) {
        currentJob = job
        currentID = job?.recordingID
        // Pause and Stop draw as they do for a real make; in sample data they end nothing.
        cancelActive = job == nil ? nil : {}
        if let model {
            for recording in (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
            where recording.id == job?.recordingID || waiting.contains(recording.id) { noteUsual(recording) }
        }
        waitingIDs = waiting
        heldIDs = held
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
        guard let model, !model.settings.isPaused, let index = queue.firstIndex(where: { !heldIDs.contains($0.recording.id) }) else { return nil }
        let next = queue.remove(at: index)
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
        options.edits = recording.edits
        options.kind = recording.kind
        options.knownSerenity = recording.hasSerenity
        if make.contains(.titlesNotesChapters) && options.makeTranscript {
            options.writing = writingSetup()
        }
        if make.contains(.podcastReady) {
            options.podcastReady = PodcastReadySetup(settings: OutputResolver.podcastReady(recording: recording, defaults: defaults), facts: recording.podcastFacts)
        }
        return options
    }

    /// Who writes, from Settings, Models. A cloud provider's key is read from the Keychain only when a
    /// task is set to that provider (the privacy lock may still keep the recording away from it).
    func writingSetup() -> WritingSetup {
        var setup = WritingSetup()
        guard let model else { return setup }
        let settings = model.settings
        setup.providers = settings.provider
        setup.lmStudioAddress = settings.lmStudioAddress
        setup.lmStudioModel = settings.lmStudioModel
        setup.ollamaAddress = settings.ollamaAddress
        setup.ollamaModel = settings.ollamaModel
        setup.claudeModel = settings.claudeModel
        setup.openAIModel = settings.openAIModel
        let chosen = Set(ModelTask.built.map { settings.provider[$0] ?? .lmStudio })
        if chosen.contains(.claudeAPI) { setup.claudeKey = model.keyStore(for: .claudeAPI)?.read() }
        if chosen.contains(.openAI) { setup.openAIKey = model.keyStore(for: .openAI)?.read() }
        if let makeClient { setup.makeClient = makeClient }
        if let makeCloudClient { setup.makeCloudClient = makeCloudClient }
        return setup
    }

    /// Runs one recording now and waits for it. Outputs go to the mode's Outputs folder, in a
    /// folder named after the file (engine v0's layout), never inside the shared iCloud folder.
    @discardableResult
    func process(_ recording: Recording, trigger: RunTrigger) async -> PipelineResult? {
        guard let model else { return nil }
        if trigger == .writeAgain { return await write(recording) }
        if trigger == .packageAgain { return await packageAgain(recording) }
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
        statusBefore = recording.status
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
        let job = await startJob(for: recording, label: label, plan: options.plannedSteps, options: options, file: file)
        let pipeline = Pipeline(tools: tools, options: options, log: model.log, meter: job.meter)
        let task = Task { [weak self] in
            await pipeline.run(file: file, outputFolder: folder, label: label) { [weak self] progress in
                await self?.apply(progress)
            }
        }
        cancelActive = { task.cancel() }
        let result = await task.value
        cancelActive = nil
        await endJob(job, steps: result.steps, recording: recording, learn: result.outcome != .test)
        finish(result, recording: recording, run: run, label: label)
        return result
    }

    /// The progress of a make that starts now: its stages weighted by how long each takes here (measured on
    /// this Mac when it can be), read twice a second.
    private func startJob(for recording: Recording, label: String, plan: [PipelineStep], options: PipelineOptions, file: URL?) async -> JobProgress {
        var media = recording.duration
        if media == nil, let file {
            // The length weights the stages. A file that does not open yet (still being written) is weighted as
            // a minute long; the percent still never goes back.
            if let probe = try? await Subprocess.run(tools.ffprobe, ["-v", "error", "-show_entries", "format=duration:stream=codec_type", "-of", "json", file.path],
                                                     timeout: .seconds(20)) {
                media = Measure.probe(json: probe.stdout)?.duration
            }
        }
        let timings = model.map { StageTimings.load($0.context) } ?? StageTimings()
        let wait = Double(options.stableWait.components.seconds) + Double(options.stableWait.components.attoseconds) / 1e18
        var expected: [PipelineStep: Double] = [:]
        for step in plan { expected[step] = timings.expectedSeconds(step, mediaSeconds: media ?? 0, stableWait: wait) }
        let measured = Set(plan.filter(timings.isMeasured))
        let tracker = ProgressTracker(recordingID: recording.id, label: label, plan: plan, expected: expected, measured: measured,
                                      startedAt: Date())
        let job = JobProgress(tracker: tracker)
        usualSeconds[recording.id] = plan.reduce(0) { $0 + (expected[$1] ?? 0) }
        job.onPublish = { [weak self] snapshot in
            self?.onProgress?(snapshot)
            // `--debug-status-log`: each published snapshot's status line, as the menu bar shows it.
            self?.model?.noteStatusLine()
        }
        currentJob = job
        job.refresh()
        progressTicker?.cancel()
        progressTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, let job = self.currentJob else { return }
                job.refresh()
                self.model?.noteStatusLine()
            }
        }
        model?.noteStatusLine()
        return job
    }

    /// The make has ended: the progress reads 100% when it finished, and the stages it finished are kept as
    /// this Mac's measured times (not a stage that was paused, and never the wait for the file).
    private func endJob(_ job: JobProgress, steps: [RunStep], recording: Recording, learn: Bool) async {
        job.apply(steps: steps, current: nil)
        await job.finish()
        progressTicker?.cancel()
        progressTicker = nil
        if learn, let model, let media = recording.duration {
            StageTimings.record(steps, mediaSeconds: media, at: model.now(), excluding: job.pausedStages, in: model.context)
        }
        currentJob = nil
        model?.noteStatusLine()
    }

    /// Write Again: the titles, show notes and chapters written again from the transcript already in
    /// the recording's folder, and nothing else made. The two written files are replaced only once
    /// the new ones pass every check; a model that is closed or answers badly leaves the last ones.
    /// An approved recording goes back to waiting for a yes, because what it covered changed.
    @discardableResult
    func write(_ recording: Recording) async -> PipelineResult? {
        guard let model else { return nil }
        currentID = recording.id
        defer { currentID = nil }
        let label = Format.dayLabel(recording.sessionDate)
        let name = recording.fileName
        let before = recording.status
        let run = Run(startedAt: model.now(), trigger: .writeAgain, steps: [RunStep(name: PipelineStep.writing.title, state: .running)])
        model.context.insert(run)
        run.recording = recording
        recording.status = .working
        recording.currentStep = PipelineStep.writing.doing
        recording.updatedAt = model.now()
        try? model.context.save()
        model.record("Writing the titles, show notes and chapters for \(label) (\(name)) again, from its transcript. Nothing else is made.", run: run)
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Prakriti is writing titles for a recording.")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        let job = await startJob(for: recording, label: label, plan: [.writing], options: PipelineOptions(), file: nil)
        job.begin(.writing)

        let started = ContinuousClock.now
        var result = PipelineResult()
        var step = RunStep(name: PipelineStep.writing.title, state: .failed)
        let defaults = model.defaultSettings()
        let lexicon = OutputResolver.details(for: .transcript, recording: recording, defaults: defaults)?.applyLexicon ?? true
        if let path = recording.outputFolder,
           let input = WritingInput.from(folder: URL(fileURLWithPath: path, isDirectory: true), clock: recording.episodeClock, duration: recording.duration ?? 0,
                                         applyLexicon: lexicon, label: label, fileName: name, kind: recording.kind, knownSerenity: recording.hasSerenity) {
            do {
                let writer = Writer(setup: writingSetup(), log: model.log)
                let writing = Task { try await writer.write(input) }
                cancelActive = { writing.cancel() }
                defer { cancelActive = nil }
                let outcome = try await writing.value
                result.mentionsSerenity = outcome.mentionsSerenity
                if let package = outcome.package {
                    let folder = URL(fileURLWithPath: path, isDirectory: true)
                    let staging = folder.deletingLastPathComponent().appending(path: ".writing " + folder.lastPathComponent, directoryHint: .isDirectory)
                    do {
                        try? FileManager.default.removeItem(at: staging)
                        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                        defer { try? FileManager.default.removeItem(at: staging) }
                        try package.save(in: staging, label: label, fileName: name)
                        _ = try Pipeline.place(staging, into: folder, known: WrittenPackage.fileNames)
                        result.written = package
                        result.outcome = .ready
                        step.state = .done
                        step.detail = package.stepLine
                    } catch {
                        result.writingProblem = "The titles, show notes and chapters were written but could not be saved."
                        model.log.write("\(name): saving the written files failed. \(error.localizedDescription)")
                    }
                } else {
                    result.writingProblem = outcome.problem ?? "Nothing was written."
                }
            } catch {
                result.outcome = .stopped
                result.writingProblem = "Stopped before it finished."
            }
        } else {
            result.writingProblem = "There is no transcript to write from. Turn the transcript on for this recording and Make Again first."
        }
        step.seconds = ModelHTTP.seconds(since: started)
        if step.state != .done { step.detail = (result.writingProblem ?? "") + " The earlier files, if any, are as they were." }
        if stoppedByHand == recording.id {
            stoppedByHand = nil
            result.writingProblem = "Stopped by you before it finished."
            step.detail = "Stopped by you. The earlier files, if any, are as they were."
        }
        await endJob(job, steps: [step], recording: recording, learn: step.state == .done)
        run.steps = [step]
        run.endedAt = model.now()
        recording.currentStep = nil
        recording.status = before == .working ? .readyForYourYes : before
        recording.updatedAt = model.now()
        if result.mentionsSerenity && !recording.hasSerenity {
            recording.hasSerenity = true
            model.record("\(label) (\(name)): Serenity is named in the transcript, so from now on only models on this Mac may read it.", run: run)
        }
        if let written = result.written {
            recording.writtenJSON = written.stored.json()
            recording.writingProblem = nil
            recording.madeFiles = Array(Set(recording.madeFiles).union(WrittenPackage.fileNames)).sorted()
            run.outcome = .ready
            run.summary = "Titles, show notes and chapters written."
            model.record("\(label) (\(name)): titles, show notes and chapters written again. \(written.stepLine)", run: run)
            // The podcast-ready files carry the chapters, notes and captions, so they follow.
            if recording.podcastReady != nil {
                let (_, line) = await repackage(recording)
                var steps = run.steps
                steps.append(line)
                run.steps = steps
            }
            model.changedAfterApproval(recording, what: "its titles, show notes and chapters")
        } else {
            recording.writingProblem = result.writingProblem
            run.outcome = result.outcome == .stopped ? .stopped : .couldntFinish
            run.summary = result.writingProblem ?? ""
            model.record("\(label) (\(name)): titles, show notes and chapters were not written. \(result.writingProblem ?? "")", level: .attention, run: run)
        }
        try? model.context.save()
        return result
    }

    /// Update Podcast-Ready Files: the tags, file name, captions, text file and checklist written
    /// again around the audio already made, for a new title, notes, show name, host, artwork or
    /// episode number. The audio is not made again (Make Again does that); a failure leaves the
    /// last files as they were. An approved recording goes back to waiting for a yes.
    @discardableResult
    func packageAgain(_ recording: Recording) async -> PipelineResult? {
        guard let model else { return nil }
        currentID = recording.id
        defer { currentID = nil }
        let before = recording.status
        let run = Run(startedAt: model.now(), trigger: .packageAgain, steps: [RunStep(name: PipelineStep.podcastPackage.title, state: .running)])
        model.context.insert(run)
        run.recording = recording
        recording.status = .working
        recording.currentStep = PipelineStep.podcastPackage.doing
        try? model.context.save()
        let job = await startJob(for: recording, label: Format.dayLabel(recording.sessionDate), plan: [.podcastPackage], options: PipelineOptions(), file: nil)
        job.begin(.podcastPackage)
        let (record, step) = await repackage(recording)
        await endJob(job, steps: [step], recording: recording, learn: false)
        run.steps = [step]
        run.endedAt = model.now()
        recording.currentStep = nil
        recording.status = before == .working ? .readyForYourYes : before
        var result = PipelineResult()
        result.podcastReady = record
        if record != nil {
            run.outcome = .ready
            run.summary = "Podcast-ready files updated."
            model.changedAfterApproval(recording, what: "its podcast-ready files")
        } else {
            run.outcome = .couldntFinish
            run.summary = step.detail ?? ""
            result.podcastProblem = step.detail
        }
        try? model.context.save()
        return result
    }

    /// Writes the podcast-ready folder again from the MP3 already in it, through a staging folder,
    /// and records it. Returns the new record (nil when it failed) and the step to show.
    func repackage(_ recording: Recording) async -> (PodcastReadyRecord?, RunStep) {
        var step = RunStep(name: PipelineStep.podcastPackage.title, state: .failed)
        let started = ContinuousClock.now
        let label = Format.dayLabel(recording.sessionDate)
        guard let model, let path = recording.outputFolder, let old = recording.podcastReady else {
            step.detail = "There are no podcast-ready files to update. Turn the podcast-ready episode on for this recording and Make Again."
            return (nil, step)
        }
        if let refusal = PodcastPackage.refusal(kind: recording.kind) {
            step.state = .skipped
            step.detail = refusal + " Its files were not updated."
            return (nil, step)
        }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        let existing = folder.appending(path: PodcastPackage.folderName).appending(path: old.fileName)
        let staging = folder.deletingLastPathComponent().appending(path: ".packaging " + folder.lastPathComponent, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: staging)
        defer { try? FileManager.default.removeItem(at: staging) }
        let defaults = model.defaultSettings()
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let untagged = staging.appending(path: ".untagged.mp3")
            try ID3.audio(of: Data(contentsOf: existing)).write(to: untagged)
            let setup = PodcastReadySetup(settings: OutputResolver.podcastReady(recording: recording, defaults: defaults), facts: recording.podcastFacts)
            let lexicon = OutputResolver.details(for: .transcript, recording: recording, defaults: defaults)?.applyLexicon ?? true
            let duration = old.expectedDuration ?? old.duration
            let clock = recording.episodeClock ?? EpisodeClock(intro: 0, segments: [Mastering.Span(start: 0, end: recording.duration ?? duration)])
            let hasTranscript = FileManager.default.fileExists(atPath: folder.appending(path: TranscriptFiles.asHeard).path)
            let pipeline = Pipeline(tools: tools, options: options(for: recording), log: model.log)
            let record = try await pipeline.packagePodcastReady(untagged: untagged, into: staging.appending(path: PodcastPackage.folderName, directoryHint: .isDirectory),
                                                                setup: setup, written: recording.written, transcriptFolder: hasTranscript ? folder : nil,
                                                                clock: clock, applyLexicon: lexicon, expectedDuration: duration,
                                                                normalizationType: old.normalizationType, talkLUFS: old.talkLUFS, corrected: old.corrected, madeAt: Date())
            try? FileManager.default.removeItem(at: untagged)
            _ = try Pipeline.place(staging, into: folder, known: [PodcastPackage.folderName])
            recording.podcastReadyJSON = record.json()
            recording.podcastReadyProblem = nil
            recording.updatedAt = model.now()
            step.state = .done
            step.detail = "\(record.fileName) and its checklist written again around the audio already made. Checklist: \(record.summary.lowercasedFirst)."
            step.seconds = ModelHTTP.seconds(since: started)
            model.record("\(label) (\(recording.fileName)): podcast-ready files updated. \(Pipeline.podcastLine(record))")
            return (record, step)
        } catch let failure as PipelineFailure {
            step.detail = failure.reason + " The earlier files are as they were."
            if let detail = failure.detail { model.log.write("\(recording.fileName): updating the podcast-ready files failed. \(detail)") }
        } catch {
            step.detail = "The podcast-ready files could not be updated: \(error.localizedDescription) The earlier files are as they were."
        }
        step.seconds = ModelHTTP.seconds(since: started)
        model.record("\(label) (\(recording.fileName)): the podcast-ready files were not updated. \(step.detail ?? "")", level: .attention)
        return (nil, step)
    }

    private func apply(_ progress: PipelineProgress) {
        guard let model, let recording = activeRecording, let run = activeRun else { return }
        currentJob?.apply(steps: progress.steps, current: progress.current)
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
            facts.estimate = recording.duration.map { $0 * Self.workPerSecond + (activeOptions.writing != nil ? Self.writingEstimate($0) : 0)
                + (activeOptions.makePodcastReady ? $0 * Self.podcastReadyPerSecond : 0) }
            model.notifier.post(.started, facts)
        case nil:
            break
        }
    }

    private func facts(for recording: Recording) -> NoticeFacts {
        var facts = NoticeFacts(recording)
        facts.makesEpisode = activeOptions.makeEpisode
        facts.makesTranscript = activeOptions.makeTranscript
        facts.makesWriting = activeOptions.writing != nil
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
        // The capture check is about the file, so it is kept whatever the make's outcome (a test, a silent
        // recording, a make that stopped later). A run that never reached it leaves the last one in place.
        if let capture = result.capture {
            recording.captureJSON = capture.json()
            let warnings = capture.warnings
            model.record("\(label) (\(recording.fileName)): capture check. " + capture.summary
                         + (warnings.isEmpty ? "" : " " + warnings.map { $0.title }.joined(separator: "; ") + "."),
                         level: warnings.isEmpty ? .info : .attention, run: run)
        }
        // Once a transcript says "Serenity", the recording stays privacy locked (never unset).
        if result.mentionsSerenity && !recording.hasSerenity {
            recording.hasSerenity = true
            model.record("\(label) (\(recording.fileName)): Serenity is named in the transcript, so from now on only models on this Mac may read it.", run: run)
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
            recording.madeAt = model.now()
            // What the episode was made with, so the page can tell when the trim or cuts on it are
            // not in the episode yet, and play the episode from a transcript line's moment.
            let made = activeOptions.makeEpisode ? activeOptions.edits : EpisodeEdits()
            recording.madeTrimStart = made.start
            recording.madeTrimEnd = made.end
            recording.madeCuts = made.cuts
            recording.episodeParts = (result.clock?.segments ?? []).map { TimeRange(start: $0.start, end: $0.end) }
            recording.episodeIntro = result.clock?.intro
            // What was written goes with this make's files; titles not made this time leave none.
            recording.writtenJSON = result.written?.stored.json()
            recording.writingProblem = activeOptions.writing == nil ? nil : result.writingProblem
            // The same for the podcast-ready files: this make's, or none.
            recording.podcastReadyJSON = result.podcastReady?.json()
            recording.podcastReadyProblem = activeOptions.makePodcastReady ? result.podcastProblem : nil
            if result.output == nil, let ready = result.podcastReady { recording.episodeDuration = ready.duration }
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
            run.summary = "Waiting for your yes."
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
            if result.parts == nil, let start = result.trimmedStart, let end = result.trimmedEnd, start + end >= 0.05 {
                numbers.append(String(format: "%.1f s of silence trimmed", start + end))
            }
            if let parts = result.parts {
                numbers.append("your trim and cuts kept \(Format.timecode(parts.reduce(0) { $0 + $1.length })) of \(Format.timecode(result.duration ?? 0))")
            }
            if let left = result.wordsLeftOut, left > 0 { numbers.append("\(Format.count(left, "word")) left out of the transcript") }
            if let written = result.written {
                numbers.append("titles, show notes and chapters by \(written.writtenBy) in \(Format.length(written.seconds))")
            } else if activeOptions.writing != nil {
                numbers.append("titles, show notes and chapters NOT written (\(result.writingProblem ?? "no reason given"))")
            }
            if let ready = result.podcastReady {
                numbers.append("podcast-ready " + Pipeline.podcastLine(ready).dropLast())
            } else if activeOptions.makePodcastReady {
                numbers.append("podcast-ready files NOT made (\(result.podcastProblem ?? "no reason given"))")
            }
            model.record("\(label) (\(name)) is waiting for your yes, made in \(Format.length(result.seconds))" + (numbers.isEmpty ? "." : ": " + numbers.joined(separator: ", ") + "."),
                         level: result.coverageOK == false || result.writingProblem != nil || result.podcastProblem != nil ? .attention : .info, run: run)
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
        case .stopped where stoppedByHand == recording.id:
            // Ivan's Stop (v2 part M4a): told as his choice, never tried again on its own. A recording with
            // files from an earlier make keeps them, and its status, as they were (Mac warning 29).
            stoppedByHand = nil
            run.outcome = .stopped
            run.summary = "Stopped by you."
            recording.intent = .none
            let kept = statusBefore.flatMap { [.readyForYourYes, .approved].contains($0) ? $0 : nil }
            recording.status = kept ?? .found
            recording.statusReason = kept != nil ? "Stopped by you before the new make finished. The files from the last make are as they were."
                                                 : "Stopped by you before it finished. Nothing was made, and the original is untouched. Choose Make Outputs to start it again."
            model.record("Stopped \(name) at your request. " + (kept != nil ? "The files from the last make are as they were." : "Nothing was made.") + " The original is untouched.",
                         run: run)
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
        if stoppedByHand == recording.id { stoppedByHand = nil }
        try? model.context.save()
    }
}

/// How long writing takes with Qwen3.8-27B in LM Studio, for the Started notice. Since the episode
/// text joined the request (11 Oct) it is mostly thinking, and barely grows with the length: the whole
/// step took 1,608 s and 1,798 s on the 15:48 talk (10 and 11 Oct, tags and summary on LM Studio too)
/// and 1,456 s on the 55:39 one; 10 Oct's first estimate (300 s plus 0.3 s a second) said 10 minutes.
enum WritingEstimate {
    static let fixed = 1_500.0
    static let perSecond = 0.1
}
