import AppKit
import Foundation
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The sidebar: what Ivan can open. Flat, one level, nothing critical at the bottom (HIG sidebars).
enum SidebarItem: String, CaseIterable, Identifiable, Hashable, Sendable {
    case today, recordings, sources, outputs, models, activity, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .recordings: "Recordings"
        case .sources: "Sources"
        case .outputs: "Outputs"
        case .models: "Models"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .recordings: "rectangle.stack"
        case .sources: "folder"
        case .outputs: "square.and.arrow.down.on.square"
        case .models: "sparkles"
        case .activity: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

/// A refusal Ivan should see: a short title and one plain reason.
struct Notice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Opens one recording's page inside the main window.
struct RecordingRoute: Hashable {
    let id: PersistentIdentifier
}

/// The app's shared state: the store, preferences, the log, and where the window is.
@MainActor
@Observable
final class AppModel {
    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let paths: AppPaths
    @ObservationIgnored let log: AppLog
    let settings: AppSettings
    @ObservationIgnored let now: () -> Date
    /// Runs recordings through the pipeline, one at a time.
    @ObservationIgnored let runner = PipelineRunner()
    /// Watches the sources and feeds the runner.
    let watcher = Watcher()
    /// Posts the notices and asks for permission once.
    let notifier = Notifier()
    /// Turns the menu bar's working frames while work runs (the label cannot animate itself).
    let ticker = WorkingTicker()
    /// Whether Prakriti opens at login (SMAppService.mainApp).
    var loginItem: LoginItemState = .unknown
    /// Another copy holds this mode's lock: this one says so and quits (AppDelegate).
    @ObservationIgnored var isDuplicate = false
    /// engine v0's state.json could not be read at the switch-over, so nothing is watched.
    @ObservationIgnored var importFailed = false
    @ObservationIgnored private var lock: InstanceLock?
    /// Opens the main window. Set by a view that is on screen (the menu bar icon or the window),
    /// because SwiftUI only hands its openWindow action to views.
    @ObservationIgnored var openMainWindow: (() -> Void)?
    /// Opens the Help window, set the same way (the menu bar icon, the main window, Help itself).
    @ObservationIgnored var openHelpWindow: (() -> Void)?
    /// Prakriti Help: the articles this build shows, the open one, Back and Forward, search (v2 part M2a).
    let help: HelpModel
    /// The Help menu's search field handler, registered at launch (AppDelegate).
    @ObservationIgnored private(set) var helpMenuSearch: HelpMenuSearch?
    /// The welcome window: its panels, the open one, and whether this launch opens it (v2 part M2b).
    /// A snapshot test swaps in one built for every capability, to see that the v2 copy fits too.
    var welcome = WelcomeModel()

    var selection: SidebarItem? = .today {
        didSet { if oldValue != selection { path = [] } }
    }
    var path: [RecordingRoute] = []

    /// True while the watcher runs. When false, the status line says so plainly.
    var isWatching = false

    /// Something Ivan tried that was refused, shown by the main window as an alert.
    var notice: Notice?

    /// What each model's test button found, shown on the Models screen (milestone 6).
    var providerChecks: [ModelProvider: ProviderCheck] = [:]
    /// A Claude API key is in the Keychain. Read when the Models screen opens; the key itself never is.
    var claudeKeyAdded = false
    /// Where the Claude API key lives. Tests use their own Keychain item, never Ivan's.
    @ObservationIgnored var keyStore: KeyStore = AppModel.isRunningTests ? .testing : .claude

    /// The model the running app uses, so the app delegate and menu commands can reach it.
    static var current: AppModel?

    init(container: ModelContainer, paths: AppPaths, settings: AppSettings, log: AppLog, now: @escaping () -> Date = Date.init) {
        self.container = container
        self.paths = paths
        self.settings = settings
        self.log = log
        self.now = now
        help = HelpModel(library: .bundled(), lastArticle: settings.helpLastArticle) { [settings] id in
            settings.helpLastArticle = id
        }
        runner.model = self
        watcher.model = self
        notifier.model = self
        helpMenuSearch = HelpMenuSearch(index: help.index) { [weak self] articleID, search in
            self?.openHelp(article: articleID, search: search)
        }
    }

    var context: ModelContext { container.mainContext }

    // MARK: Launch

    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }

    /// The model for this launch. Under tests: an in-memory store, throwaway preferences and no
    /// files written, so a test run never touches Ivan's folders or his real store.
    static func launch() -> AppModel {
        #if DEBUG
        // Debug switches (docs/v2/PLAN.md rule 2.1.10): each does one thing and quits, before any store,
        // lock or folder is touched. Never read by the installed copy (DebugSwitches.isAllowed).
        DebugSwitches.runIfAsked()
        #endif
        if isRunningTests {
            let model = AppModel(container: inMemoryContainer(), paths: AppPaths(mode: .development),
                                 settings: .ephemeral(), log: AppLog(directory: nil))
            current = model
            return model
        }
        if let launch = CaptureLaunch.current {
            // The real-window capture (scripts/capture-window.swift): sample data in memory, so
            // nothing is saved, no folder is created and Ivan's store is never opened.
            // Its lines go to the development log in every mode: after the switch-over a capture
            // runs in live mode, and wrote its lines into Ivan's live log until this was fixed.
            let paths = AppPaths(mode: AppMode.current)
            let model = Fixtures.model(mode: paths.mode, log: AppLog(directory: AppPaths(mode: .development).logs))
            model.selection = launch.screen
            current = model
            model.log.write("Opened with sample data for a window capture, showing \(launch.showsHelp ? "Help" : launch.showsWelcome ? "the welcome" : launch.screen.title). Nothing is saved.")
            // The welcome alone (v2 part M2b): never under sample data unless asked for, at one panel, and
            // optionally with a folder chosen on the last panel (in memory, through the panel's own path).
            if launch.showsWelcome {
                model.welcome.presentsAtLaunch = true
                model.welcome.panel = launch.welcomePanel - 1
                if let folder = launch.welcomeFolder {
                    // Never a look through the folders here: the sample data names the real studio
                    // folder, and a look would take its files in. The watcher only shows as running.
                    model.watcher.isRunning = false
                    model.watchFolderFromWelcome(at: URL(fileURLWithPath: folder, isDirectory: true))
                    model.watcher.isRunning = true
                }
            }
            // Help alone (v2 part M2a): the Help window opens instead of the main window, at one article
            // or with a search filled in, so the capture finds one window.
            if launch.showsHelp {
                if let id = launch.helpArticle { model.help.open(id) }
                // Typed once the window is up, as a person would: set before the window existed, the
                // search field drew its text in the Mac's own appearance (white on a light capture).
                if let search = launch.helpSearch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { model.help.searchText = search }
                }
            }
            // Shows the refusal alert in the real window, through the same path Add Folder takes.
            if let folder = launch.addFolder {
                model.addSource(at: URL(fileURLWithPath: folder, isDirectory: true))
            }
            // A recording's page (milestone 5): the sample talk that is ready for a yes, optionally
            // with a trim and a cut that are not made yet, to see the real player and fields.
            if launch.openReady {
                let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
                if let ready = all.sorted(by: Recording.newestFirst).first(where: { $0.status == .readyForYourYes }) {
                    if launch.sampleEdits {
                        model.setTrim(start: 10, end: nil, for: ready)
                        model.addCut(TimeRange(start: 300, end: 330), to: ready)
                    }
                    model.open(ready)
                }
            }
            return model
        }
        let paths = AppPaths(mode: AppMode.current)
        for folder in paths.foldersToCreate {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let log = AppLog(directory: paths.logs)
        // One watcher per mode: a second copy would process and notify every recording twice.
        guard let lock = InstanceLock.acquire(at: paths.lockFile) else {
            log.write("Another copy of Prakriti is already running in \(paths.mode.rawValue) mode, so this one (\(Bundle.main.bundlePath)) closes.")
            let model = AppModel(container: inMemoryContainer(), paths: paths, settings: .ephemeral(), log: log)
            model.isDuplicate = true
            current = model
            return model
        }
        let container: ModelContainer
        do {
            container = try PrakritiStore.makeContainer(at: paths.store)
        } catch {
            log.write("Could not open the store at \(paths.store.path): \(error.localizedDescription). Using a temporary one for this session.")
            container = inMemoryContainer()
        }
        let model = AppModel(container: container, paths: paths, settings: .forMode(paths.mode), log: log)
        model.lock = lock
        current = model
        // The welcome opens by itself until it has been shown once (v2 part M2b). Decided before
        // anything else starts, because the notifier does not ask macOS at a launch that shows it.
        model.welcome.presentsAtLaunch = model.welcomeIsDue
        model.didLaunch()
        return model
    }

    static func inMemoryContainer() -> ModelContainer {
        do {
            return try PrakritiStore.makeContainer(at: nil)
        } catch {
            fatalError("An in-memory store could not be created: \(error)")
        }
    }

    private func didLaunch() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        log.write("Prakriti \(version) opened. Mode: \(paths.mode.rawValue). Store: \(paths.store.path)")
        do {
            if try PrakritiStore.seedIfEmpty(context, paths: paths, now: now()) {
                let folders = ((try? context.fetch(FetchDescriptor<Source>())) ?? []).map { paths.display($0.path) }
                record("First start. Set up the default outputs and the folders to watch: \(folders.joined(separator: " and ")).")
            }
        } catch {
            record("Could not set up the defaults: \(error.localizedDescription)", level: .problem)
        }
        do {
            let added = try PrakritiStore.addMissingOutputKinds(context)
            if !added.isEmpty {
                record("New output available: \(added.map(\.title).joined(separator: ", ")). It is off for every folder until you turn it on.")
            }
        } catch {
            record("Could not add the new outputs: \(error.localizedDescription)", level: .problem)
        }
        importEngineV0IfNeeded()
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        log.write("Sources: \(sources.map { "\($0.name) (\($0.mode.rawValue))" }.joined(separator: " | ")).")
        recoverInterruptedWork()
        LaunchOptions.current.apply(to: self)
        loginItem = paths.mode == .live ? LoginItem.ensureRegistered(log: log, home: paths.home) : .notInstalled
        if paths.mode == .development { log.write("Login item: not registered in development mode.") }
        notifier.setUp()
        if importFailed {
            log.write("Not watching: the old engine's list could not be read, and without it the studio folder would be made again.")
        } else {
            watcher.start()
        }
    }

    /// The switch-over, once: engine v0's state.json goes into the store before the first look,
    /// so nothing v0 saw is made again. Live mode only; development never reads it.
    func importEngineV0IfNeeded() {
        guard paths.mode == .live, settings.engineV0ImportedAt == nil else { return }
        guard FileManager.default.fileExists(atPath: paths.engineV0State.path) else {
            log.write("No engine v0 state at \(paths.engineV0State.path); nothing to take over.")
            settings.engineV0ImportedAt = now()
            return
        }
        do {
            let state = try EngineV0Import.read(paths.engineV0State)
            let summary = EngineV0Import.run(state, into: self)
            settings.engineV0ImportedAt = now()
            record(summary.line)
        } catch {
            // Not marked as done: the watcher must not start on the studio folder without v0's
            // memory, so it waits, and the next launch tries again.
            record("Could not read the old engine's list of files it had seen (\(error.localizedDescription)). Nothing is watched until it can be read.", level: .problem)
            importFailed = true
        }
    }

    /// A recording left as Working means Prakriti quit while it ran. It is marked Couldn't finish,
    /// with its page offering Try Again, rather than left looking busy forever.
    func recoverInterruptedWork() {
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in all where recording.status == .working {
            recording.currentStep = nil
            if recording.intent != .none && recording.failedTries + 1 < PipelineRunner.maxTries {
                // Work Prakriti started on its own starts again by itself, and the stop counts as
                // a try, so a recording that stops Prakriti every time cannot loop forever.
                recording.failedTries += 1
                recording.status = .found
                recording.statusReason = "Prakriti quit before this finished. It starts again at the first check; the original is untouched."
            } else {
                recording.status = .couldntFinish
                recording.statusReason = "Prakriti quit before this finished. The original is untouched; try again from here."
                if recording.intent != .none {
                    recording.failedTries += 1
                    recording.intent = .none
                    var facts = NoticeFacts(recording)
                    facts.tries = recording.failedTries
                    notifier.post(.couldntFinish, facts)
                }
            }
            if let run = recording.latestRun, run.outcome == .running {
                run.outcome = .stopped
                run.endedAt = run.endedAt ?? now()
                run.steps = run.steps.map { step in
                    var step = step
                    if step.state == .running { step.state = .failed; step.detail = "Stopped when Prakriti quit." }
                    if step.state == .waiting { step.state = .skipped }
                    return step
                }
            }
            record("\(recording.fileName) was stopped when Prakriti quit. Nothing was lost; it can be tried again.", level: .attention)
        }
    }

    // MARK: Activity

    /// One line in Activity and in the log file.
    @discardableResult
    func record(_ message: String, level: LogLevel = .info, run: Run? = nil) -> LogEntry {
        let entry = LogEntry(at: now(), level: level, message: message)
        context.insert(entry)
        entry.run = run
        try? context.save()
        log.write(message)
        return entry
    }

    // MARK: Actions

    func setPaused(_ paused: Bool) {
        guard settings.isPaused != paused else { return }
        settings.isPaused = paused
        record(paused ? "Paused all work. A recording already being worked on finishes first; nothing new is looked for." : "Resumed all work.")
        if !paused {
            runner.resume()
            if watcher.isRunning { Task { await watcher.sweep(.resume) } }
        }
    }

    /// Check Now: look through every folder at once, rather than at the next regular check.
    func checkNow() {
        guard watcher.isRunning else { return }
        Task { await watcher.sweep(.checkNow) }
    }

    /// Opens one recording's page, from a clicked notice.
    func openRecording(id: UUID) {
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        guard let recording = all.first(where: { $0.id == id }) else { return }
        openMainWindow?()
        NSApp.activate()
        open(recording)
    }

    /// Process File: adds the files (with the same refusals as Add File) and starts them now, one
    /// at a time. A file Prakriti already knows is started again rather than added twice.
    func processFiles(_ urls: [URL]) {
        let added = addRecordings(urls)
        let addedPaths = Set(added.map(\.filePath))
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        var toStart = added
        for url in urls where Self.isMedia(url) {
            let path = url.standardizedFileURL.path
            guard !addedPaths.contains(path), paths.refusal(for: url, isFolder: false) == nil,
                  let known = all.first(where: { $0.filePath == path }) else { continue }
            toStart.append(known)
        }
        for recording in toStart where recording.status != .working {
            runner.enqueue(recording, trigger: .byHand)
        }
    }

    /// Make Outputs (or Try Again) on a recording's page. Ivan's own start: one try, everything
    /// chosen for it, whatever the folder's setting.
    func makeOutputs(_ recording: Recording) {
        recording.intent = .none
        recording.failedTries = 0
        runner.enqueue(recording, trigger: recording.status == .found ? .byHand : .makeAgain)
    }

    // MARK: One recording's own outputs

    /// Gives a recording its own output choices, starting from the ones it uses now: its folder's
    /// switches and the Outputs screen's settings. From then on, changes on Sources and Outputs no
    /// longer reach it, and its page says so.
    func giveOwnOutputs(_ recording: Recording) {
        guard !recording.hasOwnOutputs else { return }
        let defaults = defaultSettings()
        for kind in OutputKind.allCases {
            let base = OutputResolver.details(for: kind, recording: nil, defaults: defaults)?.copy() ?? OutputSetting(kind: kind)
            let own = OutputSetting(kind: kind, isOn: OutputResolver.choice(for: kind, recording: nil, source: recording.source, defaults: defaults)?.isOn ?? false)
            own.loudnessTarget = base.loudnessTarget
            own.peakCeiling = base.peakCeiling
            own.trimSilence = base.trimSilence
            own.introPath = base.introPath
            own.outroPath = base.outroPath
            own.channelsRaw = base.channelsRaw
            own.transcriptFormatsRaw = base.transcriptFormatsRaw
            own.applyLexicon = base.applyLexicon
            own.copySettings(from: base)
            context.insert(own)
            own.recording = recording
        }
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)) now has its own output choices.")
        try? context.save()
    }

    /// Turns one output on or off for one recording, giving it its own choices first.
    func setOutput(_ kind: OutputKind, on: Bool, for recording: Recording) {
        guard kind.isAvailable else { return }
        giveOwnOutputs(recording)
        recording.outputSettings.first { $0.kind == kind }?.isOn = on
        record("\(kind.title) turned \(on ? "on" : "off") for \(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)). It applies the next time it is made.")
        try? context.save()
    }

    /// Drops a recording's own choices: it follows its folder and the Outputs screen again.
    func useStandardOutputs(_ recording: Recording) {
        guard recording.hasOwnOutputs else { return }
        for setting in recording.outputSettings { context.delete(setting) }
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)) follows \(recording.source.map { "the \($0.name) folder" } ?? "the standard choices") again.")
        try? context.save()
    }

    func open(_ item: SidebarItem) {
        selection = item
    }

    // MARK: Help

    /// Opens the Help window at an article (if this build shows it), or with a search filled in.
    func openHelp(article id: String? = nil, search: String? = nil) {
        if let id { help.open(id) }
        if let search { help.searchText = search }
        if let openHelpWindow {
            openHelpWindow()
        } else {
            // No view has handed over SwiftUI's openWindow yet (the menu bar item hidden and the main
            // window closed): the Help menu's own Prakriti Help item opens the window instead.
            Self.chooseHelpMenuItem("Prakriti Help")
        }
        NSApp.activate()
    }

    /// Help, Show Log in Finder: today's log selected in the Finder, or its folder if nothing is
    /// written yet today. Ivan never has to type a path (help article 10).
    func showLogInFinder() {
        let target = logToShow
        if target.selects {
            NSWorkspace.shared.activateFileViewerSelecting([target.url])
        } else {
            try? FileManager.default.createDirectory(at: target.url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(target.url)
        }
        log.write("Help: Show Log in Finder showed \(paths.display(target.url.path)).")
    }

    /// What Show Log in Finder shows: this mode's log for today, selected, or its folder when nothing has
    /// been written today. A window capture's sample data writes to the development log, so it shows that.
    var logToShow: (url: URL, selects: Bool) {
        if let today = log.todayFile, FileManager.default.fileExists(atPath: today.path) { return (today, true) }
        return (log.todayFile?.deletingLastPathComponent() ?? paths.logs, false)
    }

    private static func chooseHelpMenuItem(_ title: String) {
        let menu = NSApp.helpMenu ?? NSApp.mainMenu?.items.last { $0.submenu != nil }?.submenu
        guard let menu, let index = menu.items.firstIndex(where: { $0.title == title }) else { return }
        menu.performActionForItem(at: index)
    }

    func open(_ recording: Recording) {
        selection = .recordings
        path = [RecordingRoute(id: recording.persistentModelID)]
    }

    /// Adds a watched folder with this mode's default outputs. Watching it starts with milestone 3.
    /// In development, a folder engine v0 owns (or one that holds it) is refused and Ivan is told why.
    @discardableResult
    func addSource(at url: URL) -> Source? {
        let path = url.standardizedFileURL.path
        if let reason = paths.refusal(for: url, isFolder: true) {
            let name = url.lastPathComponent.trimmingCharacters(in: .whitespaces)
            refuse(title: "\(name.isEmpty ? "This folder" : name) was not added", logged: paths.display(path), reason: reason)
            return nil
        }
        let existing = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        if existing.contains(where: { $0.path == path }) { return nil }
        let source = Source(name: url.lastPathComponent, path: path, kind: .folder, mode: .askFirst, addedAt: now())
        context.insert(source)
        let defaults = defaultSettings()
        for kind in OutputKind.allCases {
            let setting = defaults.first { $0.kind == kind }?.copy() ?? OutputSetting(kind: kind)
            context.insert(setting)
            setting.source = source
        }
        record("Added the folder \(path). It is set to Ask me first: what is already in it is listed and left alone.")
        try? context.save()
        watcher.sourcesChanged()
        return source
    }

    func remove(_ source: Source) {
        let path = source.path
        context.delete(source)
        record("Removed the folder \(path). Nothing in it was touched.")
        try? context.save()
        watcher.sourcesChanged()
    }

    /// Adds recordings by hand (Add File, or a drop). They wait as Found until the pipeline runs them.
    /// In development, a file inside a folder engine v0 owns, or in the archive, is refused.
    @discardableResult
    func addRecordings(_ urls: [URL]) -> [Recording] {
        let known = Set(((try? context.fetch(FetchDescriptor<Recording>())) ?? []).map(\.filePath))
        var added: [Recording] = []
        var refused: [(name: String, reason: String)] = []
        for url in urls where Self.isMedia(url) && !known.contains(url.standardizedFileURL.path) {
            if let reason = paths.refusal(for: url, isFolder: false) {
                refused.append((url.lastPathComponent, reason))
                continue
            }
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            let recording = Recording(filePath: url.standardizedFileURL.path, title: "", recordedAt: Self.dateInName(url.lastPathComponent),
                                      foundAt: now(), sizeBytes: size, status: .found)
            context.insert(recording)
            recording.source = source(containing: url)
            added.append(recording)
            record("Added \(url.lastPathComponent) by hand.")
        }
        if let first = refused.first {
            let one = refused.count == 1
            refuse(title: one ? "\(first.name) was not added" : "\(refused.count) files were not added",
                   logged: one ? first.name : refused.map(\.name).joined(separator: ", "), reason: first.reason)
        }
        return added
    }

    /// Says no, plainly: one line in Activity, and an alert in the window.
    private func refuse(title: String, logged: String, reason: String) {
        record("Did not add \(logged). \(reason)", level: .attention)
        notice = Notice(title: title, message: reason)
    }

    /// The watched folder a file sits in, if any, so its outputs follow that folder's choices.
    func source(containing url: URL) -> Source? {
        let path = url.standardizedFileURL.path
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        return sources.filter { path.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }
            .max { $0.path.count < $1.path.count }
    }

    func defaultSettings() -> [OutputSetting] {
        let all = (try? context.fetch(FetchDescriptor<OutputSetting>())) ?? []
        return all.filter { $0.source == nil && $0.recording == nil }
    }

    // MARK: Panels

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch This Folder"
        panel.message = "Choose a folder for Prakriti to watch for new recordings."
        if panel.runModal() == .OK, let url = panel.url {
            addSource(at: url)
        }
    }

    func chooseFilesToProcess() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .audio]
        panel.prompt = "Process"
        panel.message = "Choose recordings to process now. The originals are never changed."
        if panel.runModal() == .OK {
            processFiles(panel.urls)
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .audio]
        panel.prompt = "Add"
        panel.message = "Choose recordings to add."
        if panel.runModal() == .OK {
            addRecordings(panel.urls)
        }
    }

    // MARK: Helpers

    static func isMedia(_ url: URL) -> Bool {
        FolderScan.isMedia(url.lastPathComponent)
    }

    /// OBS names files "2026-09-13 18-25-44.mp4". Read that as the time the recording was made.
    static func dateInName(_ name: String) -> Date? {
        guard let match = name.firstMatch(of: /(\d{4})-(\d{2})-(\d{2})(?:[ _](\d{2})-(\d{2})-(\d{2}))?/) else { return nil }
        var parts = DateComponents()
        parts.year = Int(match.1)
        parts.month = Int(match.2)
        parts.day = Int(match.3)
        parts.hour = match.4.flatMap { Int($0) } ?? 12
        parts.minute = match.5.flatMap { Int($0) } ?? 0
        parts.second = match.6.flatMap { Int($0) } ?? 0
        return Calendar.current.date(from: parts)
    }
}

/// How the real-window capture opens the app: `--sample-data`, optionally `--show=<screen>`,
/// `--appearance=light|dark`, `--add-folder=<path>` (tries to add that folder, as Add Folder
/// does, so a refusal can be seen), `--open=ready` (the sample talk's page) and `--sample-edits`
/// (with a trim and a cut on it, not made yet), `--show=help` and `--show=welcome` (one window alone).
/// Used only by scripts/capture-window.swift. Each flag is one word with
/// its value after "=": a value passed as a separate word reads to macOS as a file to open, and an
/// app launched to open a file does not open its window.
struct CaptureLaunch {
    let screen: SidebarItem
    let colorScheme: ColorScheme?
    let addFolder: String?
    var openReady = false
    var sampleEdits = false
    /// `--show=help`: the Help window opens on its own, without the main window (v2 part M2a), at
    /// `--help-article=<id>` or with `--help-search=<words>` in its search field.
    var showsHelp = false
    var helpArticle: String?
    var helpSearch: String?
    /// `--show=welcome`: the welcome window opens on its own, without the main window (v2 part M2b), at
    /// `--welcome-panel=<1 to 5>`, and with `--welcome-folder=<path>` chosen on the last panel.
    var showsWelcome = false
    var welcomePanel = 1
    var welcomeFolder: String?

    static var current: CaptureLaunch? {
        let args = CommandLine.arguments
        guard args.contains("--sample-data") else { return nil }
        func value(_ flag: String) -> String? {
            args.first { $0.hasPrefix(flag + "=") }.map { String($0.dropFirst(flag.count + 1)) }
        }
        let screen = value("--show").flatMap(SidebarItem.init(rawValue:)) ?? .today
        let colorScheme: ColorScheme? = switch value("--appearance") {
        case "light": .light
        case "dark": .dark
        default: nil
        }
        return CaptureLaunch(screen: screen, colorScheme: colorScheme, addFolder: value("--add-folder"),
                             openReady: value("--open") == "ready", sampleEdits: args.contains("--sample-edits"),
                             showsHelp: value("--show") == "help", helpArticle: value("--help-article"),
                             helpSearch: value("--help-search"), showsWelcome: value("--show") == "welcome",
                             welcomePanel: value("--welcome-panel").flatMap(Int.init) ?? 1,
                             welcomeFolder: value("--welcome-folder"))
    }
}

/// Flags for a normal launch (Ivan's real store), used by the milestone checks to drive the real
/// app without clicks: `--process-file=<path>` runs Process File on that file, `--show=<screen>`
/// opens a sidebar screen, `--open=latest` opens the newest recording's page and `--open=<path>`
/// that file's page. One word per flag,
/// for the same reason as CaptureLaunch.
struct LaunchOptions {
    let processFiles: [String]
    let show: SidebarItem?
    let openLatest: Bool
    /// `--open=<path>`: opens that recording's page (milestone 4's check of the real window).
    let openPath: String?
    /// `--forget=<path>`: removes that recording from the store (not the file). Used by the
    /// milestone 3 check to take its test clip back out after the switch-over.
    let forget: [String]

    static var current: LaunchOptions {
        let args = CommandLine.arguments
        func values(_ flag: String) -> [String] {
            args.filter { $0.hasPrefix(flag + "=") }.map { String($0.dropFirst(flag.count + 1)) }
        }
        return LaunchOptions(processFiles: values("--process-file"),
                             show: values("--show").first.flatMap(SidebarItem.init(rawValue:)),
                             openLatest: values("--open").first == "latest",
                             openPath: values("--open").first.flatMap { $0 == "latest" ? nil : $0 },
                             forget: values("--forget"))
    }

    @MainActor
    func apply(to model: AppModel) {
        if let show { model.selection = show }
        for path in forget {
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
            for recording in all where recording.filePath == standardized {
                model.context.delete(recording)
                model.record("Forgot \(recording.fileName): a test recording, taken out of the list. Its file was not touched by this.")
            }
            try? model.context.save()
        }
        if !processFiles.isEmpty {
            model.log.write("Launched with Process File for \(processFiles.count) file(s).")
            model.processFiles(processFiles.map { URL(fileURLWithPath: $0) })
        }
        if let openPath {
            let standardized = URL(fileURLWithPath: openPath).standardizedFileURL.path
            let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
            if let recording = all.first(where: { $0.filePath == standardized }) { model.open(recording) }
        }
        if openLatest {
            let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
            if let latest = all.max(by: { $0.foundAt < $1.foundAt }) { model.open(latest) }
        }
    }
}
