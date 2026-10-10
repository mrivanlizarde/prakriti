import Darwin
import Foundation
import ServiceManagement

/// Opening at login, so the watcher runs after every restart without anyone opening the app.
/// Registered with `SMAppService.mainApp`, and only from an installed copy (~/Applications or
/// /Applications). Reason: a login item records where the app lives; registered from the build
/// folder it would follow every rebuild, and a rebuild replaces the app while it runs.
enum LoginItemState: Equatable, Sendable {
    case unknown
    case on
    /// Registered, but switched off in System Settings, General, Login Items. Ivan turns it on.
    case needsApproval
    case off
    /// This copy runs from somewhere else (the build folder): it does not register itself.
    case notInstalled
    case failed(String)

    var line: String {
        switch self {
        case .unknown: "Not checked yet."
        case .on: "Prakriti opens when you log in, so it keeps watching after a restart."
        case .needsApproval: "Prakriti is switched off in Login Items, so it does not open when you log in. Turn it on in System Settings."
        case .off: "Prakriti does not open when you log in."
        case .notInstalled: "This copy runs from the build folder, so it does not open at login. The copy in Applications does."
        case .failed(let reason): "Prakriti could not add itself to Login Items: \(reason)"
        }
    }
}

@MainActor
enum LoginItem {
    /// Only a copy in an Applications folder registers itself.
    static func isInstalledCopy(bundlePath: String, home: String) -> Bool {
        let path = (bundlePath as NSString).standardizingPath
        return path.hasPrefix(home + "/Applications/") || path.hasPrefix("/Applications/")
    }

    static var status: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notRegistered, .notFound: .off
        @unknown default: .unknown
        }
    }

    /// Registers this copy if it is the installed one and not yet registered. Returns the state.
    static func ensureRegistered(log: AppLog, home: URL) -> LoginItemState {
        guard isInstalledCopy(bundlePath: Bundle.main.bundlePath, home: home.path) else {
            log.write("Login item: not registered, this copy runs from \(Bundle.main.bundlePath).")
            return .notInstalled
        }
        let before = status
        if before == .off {
            do {
                try SMAppService.mainApp.register()
            } catch {
                let state = LoginItemState.failed(error.localizedDescription)
                log.write("Login item: register() failed: \(error.localizedDescription). Status: \(SMAppService.mainApp.status.rawValue).")
                return status == .off ? state : status
            }
        }
        let after = status
        log.write("Login item: \(after == .on ? "on" : after == .needsApproval ? "needs Ivan's approval in System Settings, Login Items" : "\(after)")"
                  + (before == .off ? " (registered now)." : "."))
        return after
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// One watcher per mode. A second copy in the same mode would find, process and notify every
/// recording twice, so it gets a lock it cannot take, says so in the log, and quits. The lock is
/// `flock` on a file in the mode's Application Support folder: macOS releases it when the process
/// ends, even in a crash, so a stale lock can never keep Prakriti out.
final class InstanceLock: Sendable {
    let path: String
    private let descriptor: Int32

    private init(path: String, descriptor: Int32) {
        self.path = path
        self.descriptor = descriptor
    }

    /// Nil when another process holds it.
    static func acquire(at url: URL) -> InstanceLock? {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard fd >= 0 else { return nil }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return nil
        }
        let pid = "\(getpid())\n"
        _ = ftruncate(fd, 0)
        _ = pid.withCString { write(fd, $0, strlen($0)) }
        return InstanceLock(path: url.path, descriptor: fd)
    }

    func release() {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
