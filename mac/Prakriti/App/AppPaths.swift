import Foundation

/// Development uses ~/Prakriti/Dev and its own store, so the app can never touch what engine v0
/// is doing. Live takes over ~/Prakriti/Drop, ~/Prakriti/Outputs and the Studio Recordings folder
/// at the milestone 3 switch-over, and engine v0's LaunchAgent is retired the same day.
enum AppMode: String, Sendable {
    case development
    case live

    /// The one switch: false until the milestone 3 switch-over, when engine v0 is retired.
    static let switchedOver = true

    /// Live once switched over. A copy opened with `--development` stays in development (its own
    /// store, preferences, log and ~/Prakriti/Dev folders) and can run beside the live one, which
    /// is how later milestones test without touching Ivan's recordings.
    static let current: AppMode = (!switchedOver || CommandLine.arguments.contains("--development")) ? .development : .live
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
    /// Engine v0's record of every file it saw, read once at the switch-over.
    var engineV0State: URL { root.appending(path: "state.json") }
    /// Where engine v0's LaunchAgent plist goes when it is retired.
    var retired: URL { root.appending(path: "retired", directoryHint: .isDirectory) }
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
    /// Held while this mode's watcher runs, so a second copy in the same mode stops itself.
    var lockFile: URL { applicationSupport.appending(path: "watcher.lock") }

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
    /// Before the switch-over engine v0 owns the Studio Recordings folder, ~/Prakriti/Drop and
    /// ~/Prakriti/Outputs; after it, the live Prakriti does. Either way the classes live in the
    /// studio folder. ~/Prakriti/Dev is the one part of ~/Prakriti development may use.
    private var developmentRefusals: [(folder: URL, name: String, reason: String)] {
        let owner = AppMode.switchedOver ? "the live Prakriti" : "the old engine"
        let until = AppMode.switchedOver ? "" : " until Prakriti takes over from it"
        return [
            (studioRecordings, "the Studio Recordings folder",
             "The Studio Recordings folder belongs to \(owner)\(until), and it holds the classes. A test copy of Prakriti only works on test files in the Dev folder inside ~/Prakriti."),
            (root, "~/Prakriti",
             "\(owner.capitalizedFirst) works in ~/Prakriti\(until). A test copy of Prakriti only uses the Dev folder inside it."),
        ]
    }

    /// Refused in every mode. The archive holds private 1:1 coaching calls, which are never
    /// processed (START_HERE warning 13); that does not change at the switch-over.
    private var archiveRefusal: (folder: URL, name: String, reason: String) {
        (archive, "the SerenityAI archive",
         "The SerenityAI archive holds private calls and classes. Prakriti never works on it.")
    }

    /// Folders Prakriti writes into. Watching one would find its own episodes as new recordings.
    private var ownFolders: [URL] { [outputs, approved] }

    /// Why this file or folder may not be added, in plain words, or nil if it may.
    /// - Every mode refuses the archive (and any folder that holds it), and refuses watching the
    ///   folders Prakriti writes its finished files into.
    /// - Development also refuses anything inside a folder the live engine owns, and any folder that
    ///   holds one of them (watching ~/Documents would take in the studio folder).
    func refusal(for url: URL, isFolder: Bool) -> String? {
        let target = Self.comparable(url)
        if isFolder {
            for own in ownFolders {
                let folder = Self.comparable(own)
                if Self.path(target, isInside: folder) || Self.path(folder, isInside: target) {
                    return "Prakriti writes its finished files into \(display(own.path)). Watching it would find its own episodes as new recordings."
                }
            }
        }
        let archiveFolder = Self.comparable(archive)
        if Self.path(target, isInside: archiveFolder) { return archiveRefusal.reason }
        if isFolder && Self.path(archiveFolder, isInside: target) { return "This folder holds \(archiveRefusal.name). " + archiveRefusal.reason }
        guard mode == .development else { return nil }
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
