#if DEBUG
import Foundation

/// The development build's debug switches (docs/v2/PLAN.md rule 2.1.10). Each lets an unattended
/// check read something a program can read, instead of judging a menu or a moving picture.
///
/// Compiled only into Debug builds, and never read by the installed copy: `make install` installs a
/// Debug build into ~/Applications, so the switches also check where the app is running from.
/// Reason: the live Prakriti must never quit or change behaviour because of a flag a check passed.
///
/// - `--debug-help-search=<words>`: runs the Help menu's search handler for those words, prints the
///   article ids it returns, one per line, and quits (v2 part M2a).
/// - `--debug-playback-log`: the Viewer's player writes its time and rate to the log once a second (v2 part
///   M3b; `AppModel.startDebugSwitches`).
/// - `--debug-status-log`: every change of the menu bar's status line is written to the log, "Status line:
///   Making Sun 13 Sep: Writing the transcript, 64%, about 6 min left." (v2 part M4a; `AppModel.noteStatusLine`).
enum DebugSwitches {
    /// The installed copy, where the switches are never read.
    static var installedApp: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications/Prakriti.app", directoryHint: .isDirectory)
    }

    /// False for the installed copy: it never reads a debug switch.
    static func isAllowed(bundle: URL = Bundle.main.bundleURL) -> Bool {
        bundle.resolvingSymlinksInPath().standardizedFileURL.path
            != installedApp.resolvingSymlinksInPath().standardizedFileURL.path
    }

    static func value(_ flag: String) -> String? {
        CommandLine.arguments.first { $0.hasPrefix(flag + "=") }.map { String($0.dropFirst(flag.count + 1)) }
    }

    /// Runs the switch asked for, if any, and quits. Called first thing at launch.
    @MainActor
    static func runIfAsked() {
        guard isAllowed(), let words = value("--debug-help-search") else { return }
        let library = HelpLibrary.bundled()
        let handler = HelpMenuSearch(index: HelpSearchIndex(library: library)) { _, _ in }
        for problem in library.problems { FileHandle.standardError.write(Data("Help problem: \(problem)\n".utf8)) }
        let ids = handler.itemIDs(for: words)
        print(ids.joined(separator: "\n"))
        AppLog(directory: AppPaths(mode: .development).logs)
            .write("Debug switch: the Help menu's search for \"\(words)\" returned \(ids.isEmpty ? "nothing" : ids.joined(separator: ", ")).")
        exit(0)
    }
}
#endif
