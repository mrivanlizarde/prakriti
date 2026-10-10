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

    /// The SerenityAI archive download: private 1:1 coaching calls and classes. Never worked on
    /// while Prakriti is being built.
    var archive: URL { home.appending(path: "Downloads/SerenityAI", directoryHint: .isDirectory) }

    /// Folders development mode may not take in, each with the reason Ivan reads when he tries.
    /// Engine v0 watches the Studio Recordings folder and ~/Prakriti/Drop and writes ~/Prakriti/Outputs
    /// until the milestone 3 switch-over, and the classes live in the studio folder; the archive
    /// holds private calls. ~/Prakriti/Dev is the one part of ~/Prakriti development may use.
    private var developmentRefusals: [(folder: URL, name: String, reason: String)] {
        [
            (studioRecordings, "the Studio Recordings folder",
             "The Studio Recordings folder stays with the old engine until Prakriti takes over from it, and it holds the classes. While Prakriti is being built, it only works on test files in the Dev folder inside ~/Prakriti."),
            (root, "~/Prakriti",
             "The old engine works in ~/Prakriti until Prakriti takes over from it. While Prakriti is being built, it only uses the Dev folder inside it."),
            (archive, "the SerenityAI archive",
             "The SerenityAI archive holds private calls and classes. Nothing in it is worked on while Prakriti is being built."),
        ]
    }

    /// Why this file or folder may not be added, in plain words, or nil if it may. Development mode
    /// refuses anything inside a folder engine v0 owns or the archive, and any folder that holds one
    /// of them (watching ~/Documents would take in the studio folder). Live mode refuses nothing here.
    func refusal(for url: URL, isFolder: Bool) -> String? {
        guard mode == .development else { return nil }
        let target = Self.comparable(url)
        if Self.path(target, isInside: Self.comparable(workRoot)) { return nil }
        for (folder, name, reason) in developmentRefusals {
            let owned = Self.comparable(folder)
            if Self.path(target, isInside: owned) { return reason }
            if isFolder && Self.path(owned, isInside: target) {
                return "This folder holds \(name). " + reason
            }
        }
        return nil
    }

    /// A path for comparing: standardized, symlinks resolved, lowercased (the Mac's disk ignores
    /// case), with no trailing slash. The studio folder's trailing space is kept: it is in the name.
    private static func comparable(_ url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    private static func path(_ path: String, isInside folder: String) -> Bool {
        path == folder || path.hasPrefix(folder == "/" ? "/" : folder + "/")
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
