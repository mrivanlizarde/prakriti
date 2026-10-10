import Foundation

/// Development uses ~/Prakriti/Dev and its own store, so the app can never touch what engine v0
/// is doing. Live takes over ~/Prakriti/Drop, ~/Prakriti/Outputs and the Studio Recordings folder
/// at the milestone 3 switch-over, and engine v0's LaunchAgent is retired the same day.
enum AppMode: String, Sendable {
    case development
    case live

    /// The one switch. Stays .development until milestone 3 passes.
    static let current: AppMode = .development
}

struct AppPaths: Sendable {
    let mode: AppMode
    let home: URL

    init(mode: AppMode, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.mode = mode
        self.home = home
    }

    /// ~/Prakriti, shared with engine v0 (its state.json and log.txt live here).
    var root: URL { home.appending(path: "Prakriti", directoryHint: .isDirectory) }

    /// Where this mode keeps its working folders.
    var workRoot: URL { mode == .development ? root.appending(path: "Dev", directoryHint: .isDirectory) : root }

    var drop: URL { workRoot.appending(path: "Drop", directoryHint: .isDirectory) }
    var outputs: URL { workRoot.appending(path: "Outputs", directoryHint: .isDirectory) }
    var approved: URL { workRoot.appending(path: "Approved", directoryHint: .isDirectory) }

    /// The shared iCloud folder OBS saves into. The trailing space in the name is real.
    /// Read-only to Prakriti: it syncs to everyone in the share.
    var studioRecordings: URL {
        home.appending(path: "Documents/Design Work/Galindo x Lizarde/Studio Recordings ", directoryHint: .isDirectory)
    }

    var applicationSupport: URL {
        let base = home.appending(path: "Library/Application Support/Prakriti", directoryHint: .isDirectory)
        return mode == .development ? base.appending(path: "Development", directoryHint: .isDirectory) : base
    }

    var store: URL { applicationSupport.appending(path: "Prakriti.store") }

    var logs: URL {
        let base = home.appending(path: "Library/Logs/Prakriti", directoryHint: .isDirectory)
        return mode == .development ? base.appending(path: "Development", directoryHint: .isDirectory) : base
    }

    /// A path as people read it: the home folder shown as ~.
    func display(_ path: String) -> String {
        let homePath = home.path
        return path == homePath ? "~" : (path.hasPrefix(homePath + "/") ? "~" + path.dropFirst(homePath.count) : path)
    }

    /// Folders the app creates at launch. Never the studio folder.
    var foldersToCreate: [URL] { [drop, outputs, approved, applicationSupport, logs] }

    /// Outputs are never written inside the shared iCloud folder (transcripts can carry students'
    /// words and names, and that folder syncs to every participant) or anywhere under ~/Documents.
    func isSafeOutputLocation(_ url: URL) -> Bool {
        let target = url.standardizedFileURL.resolvingSymlinksInPath().path
        let documents = home.appending(path: "Documents", directoryHint: .isDirectory).standardizedFileURL.path
        let studio = studioRecordings.standardizedFileURL.path
        return !(target == documents || target.hasPrefix(documents + "/") || target.hasPrefix(studio))
    }
}
