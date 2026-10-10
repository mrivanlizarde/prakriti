import AppKit
import Foundation
import Observation
import SwiftData
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

    var selection: SidebarItem? = .today {
        didSet { if oldValue != selection { path = [] } }
    }
    var path: [RecordingRoute] = []

    /// True once the watcher runs (milestone 3). Until then the status line says so plainly.
    var isWatching = false

    /// The model the running app uses, so the app delegate and menu commands can reach it.
    static var current: AppModel?

    init(container: ModelContainer, paths: AppPaths, settings: AppSettings, log: AppLog, now: @escaping () -> Date = Date.init) {
        self.container = container
        self.paths = paths
        self.settings = settings
        self.log = log
        self.now = now
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
        if isRunningTests {
            let model = AppModel(container: inMemoryContainer(), paths: AppPaths(mode: .development),
                                 settings: .ephemeral(), log: AppLog(directory: nil))
            current = model
            return model
        }
        let paths = AppPaths(mode: AppMode.current)
        for folder in paths.foldersToCreate {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let log = AppLog(directory: paths.logs)
        let container: ModelContainer
        do {
            container = try PrakritiStore.makeContainer(at: paths.store)
        } catch {
            log.write("Could not open the store at \(paths.store.path): \(error.localizedDescription). Using a temporary one for this session.")
            container = inMemoryContainer()
        }
        let model = AppModel(container: container, paths: paths, settings: AppSettings(defaults: .standard), log: log)
        current = model
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
                record("First start. Set up the default outputs and the drop folder at \(paths.drop.path).")
            }
        } catch {
            record("Could not set up the defaults: \(error.localizedDescription)", level: .problem)
        }
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        log.write("Sources: \(sources.map(\.path).joined(separator: " | ")). Watching: no (the watcher arrives in milestone 3; engine v0 still owns the live folders).")
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
        record(paused ? "Paused all work." : "Resumed all work.")
    }

    func open(_ item: SidebarItem) {
        selection = item
    }

    func open(_ recording: Recording) {
        selection = .recordings
        path = [RecordingRoute(id: recording.persistentModelID)]
    }

    /// Adds a watched folder with this mode's default outputs. Watching it starts with milestone 3.
    @discardableResult
    func addSource(at url: URL) -> Source? {
        let path = url.standardizedFileURL.path
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
        record("Added the folder \(path).")
        return source
    }

    func remove(_ source: Source) {
        let path = source.path
        context.delete(source)
        record("Removed the folder \(path). Nothing in it was touched.")
    }

    /// Adds recordings by hand (Add File, or a drop). They wait as Found until the pipeline runs them.
    @discardableResult
    func addRecordings(_ urls: [URL]) -> [Recording] {
        let known = Set(((try? context.fetch(FetchDescriptor<Recording>())) ?? []).map(\.filePath))
        var added: [Recording] = []
        for url in urls where Self.isMedia(url) && !known.contains(url.standardizedFileURL.path) {
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            let recording = Recording(filePath: url.standardizedFileURL.path, title: "", recordedAt: Self.dateInName(url.lastPathComponent),
                                      foundAt: now(), sizeBytes: size, status: .found)
            context.insert(recording)
            added.append(recording)
            record("Added \(url.lastPathComponent) by hand.")
        }
        return added
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

    /// The file types engine v0 accepts.
    static let mediaExtensions: Set<String> = ["mp4", "mov", "mkv", "m4a", "wav", "mp3", "aac", "m4v"]

    static func isMedia(_ url: URL) -> Bool {
        mediaExtensions.contains(url.pathExtension.lowercased())
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
