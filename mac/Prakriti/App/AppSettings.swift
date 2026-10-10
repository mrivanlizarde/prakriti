import Foundation
import Observation

/// Small preferences, kept in UserDefaults. Records (sources, recordings, runs) live in the store.
/// No secret ever lives here: the Claude API key goes in the Keychain (milestone 6).
@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let paused = "pauseAll"
        static let showInMenuBar = "showInMenuBar"
        static let notifyPrefix = "notify."
        static let providerPrefix = "provider."
        static let lmStudioAddress = "lmStudioAddress"
        static let lmStudioModel = "lmStudioModel"
        static let lastEventID = "lastEventID"
        static let eventDevice = "eventDevice"
        static let engineV0ImportedAt = "engineV0ImportedAt"
    }

    /// Stops finding and processing recordings until turned back on.
    var isPaused: Bool { didSet { defaults.set(isPaused, forKey: Key.paused) } }
    var showInMenuBar: Bool { didSet { defaults.set(showInMenuBar, forKey: Key.showInMenuBar) } }
    var notify: [NotificationEvent: Bool] {
        didSet { for (event, on) in notify { defaults.set(on, forKey: Key.notifyPrefix + event.rawValue) } }
    }
    var provider: [ModelTask: ModelProvider] {
        didSet { for (task, p) in provider { defaults.set(p.rawValue, forKey: Key.providerPrefix + task.rawValue) } }
    }
    /// LM Studio runs on port 1235 on Ivan's Mac, not its default 1234 (checked 10 Oct).
    var lmStudioAddress: String { didSet { defaults.set(lmStudioAddress, forKey: Key.lmStudioAddress) } }
    var lmStudioModel: String { didSet { defaults.set(lmStudioModel, forKey: Key.lmStudioModel) } }

    /// The newest file-system event already looked at, and the disk it belongs to: the watcher
    /// replays from here on the next launch. Kept as text because UserDefaults has no 64-bit unsigned type.
    var lastEventID: UInt64 { didSet { defaults.set(String(lastEventID), forKey: Key.lastEventID) } }
    var eventDevice: String { didSet { defaults.set(eventDevice, forKey: Key.eventDevice) } }
    /// When engine v0's state.json was taken in at the switch-over. Read once, never again.
    var engineV0ImportedAt: Date? { didSet { defaults.set(engineV0ImportedAt, forKey: Key.engineV0ImportedAt) } }

    static let defaultLMStudioAddress = "http://localhost:1235/v1"
    static let defaultLMStudioModel = "qwen/qwen3.8-27b"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        isPaused = defaults.bool(forKey: Key.paused)
        showInMenuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? true
        var notify: [NotificationEvent: Bool] = [:]
        for event in NotificationEvent.allCases {
            notify[event] = defaults.object(forKey: Key.notifyPrefix + event.rawValue) as? Bool ?? true
        }
        self.notify = notify
        var provider: [ModelTask: ModelProvider] = [:]
        for task in ModelTask.allCases {
            let raw = defaults.string(forKey: Key.providerPrefix + task.rawValue) ?? ""
            provider[task] = ModelProvider(rawValue: raw) ?? .lmStudio
        }
        self.provider = provider
        lmStudioAddress = defaults.string(forKey: Key.lmStudioAddress) ?? Self.defaultLMStudioAddress
        lmStudioModel = defaults.string(forKey: Key.lmStudioModel) ?? Self.defaultLMStudioModel
        lastEventID = defaults.string(forKey: Key.lastEventID).flatMap(UInt64.init) ?? 0
        eventDevice = defaults.string(forKey: Key.eventDevice) ?? ""
        engineV0ImportedAt = defaults.object(forKey: Key.engineV0ImportedAt) as? Date
    }

    /// Each mode keeps its own preferences. Reason: from the switch-over a development copy can run
    /// beside the live one, and sharing one set would let it pause the live watcher or move its
    /// saved event id. Live keeps the app's standard preferences (as milestones 1 and 2 used them).
    static func forMode(_ mode: AppMode) -> AppSettings {
        switch mode {
        case .live: AppSettings(defaults: .standard)
        case .development: AppSettings(defaults: UserDefaults(suiteName: "studio.therowan.prakriti.app.development") ?? .standard)
        }
    }

    /// A throwaway set of preferences for tests and snapshots, so they never touch Ivan's.
    /// One fixed suite, cleared each time, so test runs do not leave files behind.
    static func ephemeral() -> AppSettings {
        let name = "studio.therowan.prakriti.app.ephemeral"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return AppSettings(defaults: defaults)
    }
}
