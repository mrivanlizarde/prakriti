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
