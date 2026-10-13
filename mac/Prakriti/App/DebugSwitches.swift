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
/// - `--debug-face-scan=<file>`: runs the face step on one file in development (its job folder and people file in
///   the development Application Support folder), logs what it found and quits (v2 part M6a). The crash check of
///   `make accept-people` kills it with SIGKILL while it works, to prove the next launch deletes the job folder.
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
        guard isAllowed() else { return }
        if let path = value("--debug-face-scan") { scanFaces(path) }
        guard let words = value("--debug-help-search") else { return }
        let library = HelpLibrary.bundled()
        let handler = HelpMenuSearch(index: HelpSearchIndex(library: library)) { _, _ in }
        for problem in library.problems { FileHandle.standardError.write(Data("Help problem: \(problem)\n".utf8)) }
        let ids = handler.itemIDs(for: words)
        print(ids.joined(separator: "\n"))
        AppLog(directory: AppPaths(mode: .development).logs)
            .write("Debug switch: the Help menu's search for \"\(words)\" returned \(ids.isEmpty ? "nothing" : ids.joined(separator: ", ")).")
        exit(0)
    }

    /// `--debug-face-scan`: the face step alone, in development only, on a file development may read.
    @MainActor
    private static func scanFaces(_ path: String) {
        let paths = AppPaths(mode: .development)
        let log = AppLog(directory: paths.logs)
        let file = URL(fileURLWithPath: path)
        if let refusal = paths.refusal(for: file, isFolder: false) {
            log.write("Debug switch: faces not looked for in \(file.lastPathComponent). \(refusal)")
            exit(1)
        }
        let folders = PeopleFolders(support: paths.applicationSupport)
        let id = UUID()
        log.write("Debug switch: looking for faces in \(file.lastPathComponent) (job folders in \(paths.display(folders.jobs.path))).")
        let done = DispatchSemaphore(value: 0)
        // The step runs off the main thread (Vision and AVFoundation need no main actor); the main thread only waits.
        Task.detached {
            do {
                let outcome = try await FaceStep.run(file: file, recordingID: id, folders: folders, now: Date())
                log.write("Debug switch: faces in \(file.lastPathComponent). \(outcome.found.stepLine)")
                folders.removePeopleFile(for: id)
            } catch {
                log.write("Debug switch: faces could not be looked for: \(error.localizedDescription)")
            }
            done.signal()
        }
        done.wait()
        exit(0)
    }
}
#endif
