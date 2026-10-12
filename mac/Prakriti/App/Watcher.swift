import AppKit
import Foundation
import Observation
import Synchronization
import SwiftData

/// Why a look through the folders happened.
enum SweepReason: Sendable, Equatable {
    case launch, timer, fileEvent, wake, checkNow, resume, sourcesChanged

    var trigger: RunTrigger {
        switch self {
        case .launch: .launch
        case .timer, .resume: .timer
        case .fileEvent: .fileEvent
        case .wake: .wake
        case .checkNow, .sourcesChanged: .checkNow
        }
    }

    /// Leaves a line in Activity even when nothing is new: the heartbeat. A file event that finds
    /// nothing new does not, because OBS writing a recording sends one every few seconds.
    var isHeartbeat: Bool { self != .fileEvent }
}

/// What the last look at one watched folder found, for Sources and the status line.
struct SourceWatchState: Equatable, Sendable {
    enum Health: Equatable, Sendable {
        case ok
        case missing
        /// macOS said no: Prakriti is not allowed into this folder.
        case notAllowed
        /// The look did not answer: macOS is most likely waiting on its permission prompt.
        case waitingForPermission
        case unreadable(String)
    }

    var health: Health
    var checkedAt: Date
    var fileCount: Int = 0

    var isBlocked: Bool { health != .ok }

    /// One plain sentence for the Sources screen.
    var line: String {
        switch health {
        case .ok:
            "Watching. Last checked at \(Format.clock(checkedAt)): \(Format.count(fileCount, "recording")) in it."
        case .missing:
            "This folder is not there. Prakriti looks again every 5 minutes, and picks it up when it is back."
        case .notAllowed:
            "macOS has not allowed Prakriti to read this folder. Allow it in System Settings, Privacy and Security, Files and Folders."
        case .waitingForPermission:
            "Waiting for macOS to allow Prakriti into this folder. Answer the prompt on screen, or allow it in System Settings, Privacy and Security, Files and Folders."
        case .unreadable(let reason):
            "This folder could not be read: \(reason)"
        }
    }
}

/// Watches every source: FSEvents for changes (replayed from the last saved event id after a
/// quit), a look through every folder at launch, on wake, every 5 minutes and after any dropped
/// events, and one line in Activity for every regular look, including "nothing new" (engine v0's
/// heartbeat: a quiet day and a stopped engine must look different). New recordings go to the
/// runner's one-at-a-time queue, or wait for Ivan in an "Ask me first" folder.
@MainActor
@Observable
final class Watcher {
    @ObservationIgnored weak var model: AppModel?
    /// Set by start() and stop(); sample data sets it to draw a watching app.
    var isRunning = false
    /// By Source.id.
    var states: [UUID: SourceWatchState] = [:]
    var lastCheck: Date?

    /// The heartbeat (v0: 5 minutes). Tests shorten the waits; the app never does.
    @ObservationIgnored var interval: Duration = .seconds(300)
    /// Events settle this long before a look, so a burst of changes makes one look (v0: 5 s).
    @ObservationIgnored var settle: Duration = .seconds(5)
    /// How long one folder may take to list before it is reported as waiting for permission.
    @ObservationIgnored var scanTimeout: Duration = .seconds(20)

    @ObservationIgnored private var stream: EventStream?
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var sweeping = false
    @ObservationIgnored private var pending: SweepReason?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let inFlight = ScanRegistry()
    @ObservationIgnored private var replayed = 0
    /// The last health logged per folder, so a blocked folder is logged when it changes, not every 5 minutes.
    @ObservationIgnored private var loggedHealth: [UUID: SourceWatchState.Health] = [:]

    // MARK: Start and stop

    func start() {
        guard let model, !isRunning else { return }
        isRunning = true
        model.isWatching = true
        startStream()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.interval ?? .seconds(300))
                guard !Task.isCancelled, let self else { return }
                await self.sweep(.timer)
                await self.model?.notifier.refreshPermission(askIfNeeded: false)
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.willSleep() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        })
        Task { await sweep(.launch) }
    }

    func stop() {
        stream?.stop()
        stream = nil
        heartbeat?.cancel()
        settleTask?.cancel()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        isRunning = false
        model?.isWatching = false
    }

    /// A folder was added or removed: watch the new set, and look now.
    func sourcesChanged() {
        guard isRunning else { return }
        stream?.stop()
        stream = nil
        startStream()
        Task { await sweep(.sourcesChanged) }
    }

    private func willSleep() {
        model?.log.write("Going to sleep. Nothing new is found until the Mac wakes.")
    }

    private func didWake() {
        model?.log.write("Woke from sleep. Looking for anything new.")
        Task { await sweep(.wake) }
    }

    // MARK: FSEvents

    private func startStream() {
        guard let model else { return }
        let sources = (try? model.context.fetch(FetchDescriptor<Source>())) ?? []
        let paths = sources.map(\.path)
        guard !paths.isEmpty else { return }
        let device = EventStream.deviceUUID(for: model.paths.home.path)
        let saved = model.settings.lastEventID
        let since: UInt64? = (saved > 0 && device != nil && device == model.settings.eventDevice) ? saved : nil
        model.settings.eventDevice = device ?? ""
        replayed = 0
        let stream = EventStream(paths: paths, since: since) { [weak self] batch in
            Task { @MainActor in self?.handle(batch) }
        }
        if stream.start() {
            self.stream = stream
            model.log.write("Watching for changes in: " + paths.map { model.paths.display($0) }.joined(separator: " | ")
                            + (since.map { ". Replaying changes since event \($0)." } ?? ". Starting from now."))
        } else {
            model.record("Could not start watching for changes. The regular check every 5 minutes still finds new recordings.", level: .attention)
        }
    }

    /// Called by EventStream through the main actor. Internal so tests can hand it a batch.
    func handle(_ batch: EventBatch) {
        guard let model else { return }
        if batch.lastID > 0 { model.settings.lastEventID = batch.lastID }
        replayed += batch.replayed
        if batch.historyDone {
            model.log.write("Caught up on changes made while Prakriti was closed: \(Format.count(replayed, "event")).")
            replayed = 0
        }
        if batch.mustRescan {
            model.log.write("macOS reported dropped or merged changes. Looking through every folder.")
        }
        guard batch.mustRescan || !batch.paths.isEmpty else { return }
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: self?.settle ?? .seconds(5))
            guard !Task.isCancelled, let self else { return }
            await self.sweep(.fileEvent)
        }
    }

    // MARK: The look through every folder

    /// Lists every source off the main thread, takes in what is new, restarts what was waiting,
    /// and leaves the heartbeat line. One look at a time; a look asked for during one runs after it.
    func sweep(_ reason: SweepReason) async {
        guard let model else { return }
        if sweeping {
            if pending == nil || pending == .fileEvent { pending = reason }
            return
        }
        sweeping = true
        defer {
            sweeping = false
            if let next = pending {
                pending = nil
                Task { await sweep(next) }
            }
        }

        if model.settings.isPaused {
            if reason.isHeartbeat {
                let run = newRun(reason, outcome: .nothingNew, summary: "Paused.")
                model.record("Paused, so no folder was checked. Resume All to look again.", run: run)
            }
            return
        }

        let sources = (try? model.context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
        let results = await Self.scan(sources.map(\.path), timeout: scanTimeout, registry: inFlight)
        // Back on the main actor. The store may have changed during the scan: re-read what is known.
        let recordings = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
        var known = Set(recordings.map(\.filePath))
        // Removed from the library by Ivan (v2 part M3a): never found again as new.
        known.formUnion(sources.flatMap(\.forgottenPaths))
        let now = model.now()
        var newOnes: [(Recording, Source)] = []
        var listed = 0
        var blocked: [String] = []

        for source in sources where !source.isDeleted {
            let result = results[source.path] ?? .timedOut
            let state = Self.state(for: result, at: now)
            states[source.id] = state
            logHealthChange(source, state)
            guard case .files(let files) = result else {
                blocked.append(source.name)
                continue
            }
            let fresh = files.filter { !known.contains($0.path) }
            if source.baselinedAt == nil {
                // The first look at a folder: what is already there is the past, not new material.
                for file in fresh {
                    let recording = add(file, to: source, intent: .none, at: now)
                    recording.statusReason = "Already in this folder when Prakriti started watching it, so nothing was made. Choose Make Outputs to make it."
                    known.insert(file.path)
                }
                source.baselinedAt = now
                listed += fresh.count
                model.record("Started watching \(source.name). " + (fresh.isEmpty ? "It is empty."
                    : "\(Format.count(fresh.count, "recording")) already there \(fresh.count == 1 ? "was" : "were") listed and left alone."))
                continue
            }
            for file in fresh {
                let url = URL(fileURLWithPath: file.path)
                if let reason = model.paths.refusal(for: url, isFolder: false) {
                    // A link or a folder name can lead a watched folder into a refused place.
                    model.record("Left \(url.lastPathComponent) alone in \(source.name). \(reason)", level: .attention)
                    known.insert(file.path)
                    continue
                }
                let intent: WorkIntent = source.mode == .automatic ? .make : .check
                let recording = add(file, to: source, intent: intent, at: now)
                known.insert(file.path)
                newOnes.append((recording, source))
            }
        }
        try? model.context.save()

        for (recording, source) in newOnes {
            model.record("Found \(recording.fileName) in \(source.name). "
                         + (recording.intent == .make ? "It is made automatically once it has finished arriving."
                                                       : "It is checked, then waits for you: the folder is set to Ask me first."))
        }
        // Anything waiting on its own: new arrivals, retries, and work a quit interrupted.
        for recording in recordings + newOnes.map(\.0) where recording.status == .found && recording.intent != .none {
            if model.runner.isWaiting(recording) || model.runner.isCurrent(recording) { continue }
            model.runner.enqueue(recording, trigger: recording.failedTries > 0 ? .retry : reason.trigger)
        }

        lastCheck = now
        guard reason.isHeartbeat || !newOnes.isEmpty || listed > 0 else { return }
        let folders = Format.count(sources.count, "folder")
        var line = "Checked \(folders). " + (newOnes.isEmpty ? "Nothing new." : "Found \(Format.count(newOnes.count, "new recording")).")
        if !blocked.isEmpty { line += " Could not read \(StatusSummary.folderPhrase(blocked))." }
        if let working = recordings.first(where: { $0.status == .working }) {
            line += " Working on \(Format.dayLabel(working.sessionDate)): \((working.currentStep ?? "working").lowercasedFirst)."
        }
        let run = newRun(reason, outcome: newOnes.isEmpty ? .nothingNew : .checked, summary: line)
        run.endedAt = model.now()
        model.record(line, level: blocked.isEmpty ? .info : .attention, run: run)
    }

    private func add(_ file: ScannedFile, to source: Source, intent: WorkIntent, at now: Date) -> Recording {
        let name = (file.path as NSString).lastPathComponent
        let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(name), foundAt: now,
                                  sizeBytes: file.size, status: .found)
        recording.intent = intent
        model?.context.insert(recording)
        recording.source = source
        return recording
    }

    private func newRun(_ reason: SweepReason, outcome: RunOutcome, summary: String) -> Run {
        let run = Run(startedAt: model?.now() ?? Date(), trigger: reason.trigger, outcome: outcome, summary: summary)
        model?.context.insert(run)
        return run
    }

    private func logHealthChange(_ source: Source, _ state: SourceWatchState) {
        guard loggedHealth[source.id] != state.health else { return }
        let first = loggedHealth[source.id] == nil
        loggedHealth[source.id] = state.health
        if state.health == .ok {
            if !first { model?.record("\(source.name) can be read again.") }
            model?.log.write("\(source.name): listed \(Format.count(state.fileCount, "recording")) at \(source.path).")
        } else {
            model?.record("\(source.name): \(state.line)", level: .attention)
        }
    }

    static func state(for result: FolderScan.Result, at date: Date) -> SourceWatchState {
        switch result {
        case .files(let files): SourceWatchState(health: .ok, checkedAt: date, fileCount: files.count)
        case .missing: SourceWatchState(health: .missing, checkedAt: date)
        case .notAllowed: SourceWatchState(health: .notAllowed, checkedAt: date)
        case .timedOut: SourceWatchState(health: .waitingForPermission, checkedAt: date)
        case .failed(let reason): SourceWatchState(health: .unreadable(reason), checkedAt: date)
        }
    }

    /// Lists each folder on its own background thread. A folder in ~/Documents read for the first
    /// time waits until someone answers macOS's permission prompt, so a folder that does not answer
    /// in time is reported as waiting and the others go ahead; its thread stays parked until the
    /// prompt is answered, and no second one is started for it meanwhile.
    nonisolated static func scan(_ folders: [String], timeout: Duration, registry: ScanRegistry) async -> [String: FolderScan.Result] {
        await withTaskGroup(of: (String, FolderScan.Result).self) { group in
            for folder in folders {
                group.addTask {
                    guard registry.begin(folder) else { return (folder, .timedOut) }
                    let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                    let result: FolderScan.Result = await withCheckedContinuation { continuation in
                        let once = ResumeOnce(continuation)
                        DispatchQueue.global(qos: .utility).async {
                            let value = FolderScan.scan(folder)
                            registry.end(folder)
                            once.resume(value)
                        }
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) { once.resume(.timedOut) }
                    }
                    return (folder, result)
                }
            }
            var results: [String: FolderScan.Result] = [:]
            for await (folder, result) in group { results[folder] = result }
            return results
        }
    }
}

/// Resumes a continuation once, whichever of two racers gets there first.
final class ResumeOnce<Value: Sendable>: Sendable {
    private let continuation: CheckedContinuation<Value, Never>
    private let done = Mutex(false)

    init(_ continuation: CheckedContinuation<Value, Never>) { self.continuation = continuation }

    func resume(_ value: Value) {
        let first = done.withLock { finished -> Bool in
            if finished { return false }
            finished = true
            return true
        }
        if first { continuation.resume(returning: value) }
    }
}

/// The folders being listed right now, so a listing parked on a permission prompt is not started twice.
final class ScanRegistry: Sendable {
    private let folders = Mutex<Set<String>>([])

    func begin(_ folder: String) -> Bool { folders.withLock { $0.insert(folder).inserted } }
    func end(_ folder: String) { folders.withLock { _ = $0.remove(folder) } }
}
