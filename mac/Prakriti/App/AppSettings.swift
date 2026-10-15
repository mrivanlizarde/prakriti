import Foundation
import Observation

/// Small preferences, kept in UserDefaults. Records (sources, recordings, runs) live in the store.
/// No secret ever lives here: the Anthropic and OpenAI keys are in the Keychain (KeyStore).
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
        static let ollamaAddress = "ollamaAddress"
        static let ollamaModel = "ollamaModel"
        static let claudeModel = "claudeModel"
        static let openAIModel = "openAIModel"
        static let lastEventID = "lastEventID"
        static let eventDevice = "eventDevice"
        static let engineV0ImportedAt = "engineV0ImportedAt"
        static let helpLastArticle = "helpLastArticle"
        static let welcomeSeenVersion = "welcomeSeenVersion"
        static let windowState = "windowState"
        static let followPlayback = "followPlayback"
        static let viewerTipSeen = "viewerTipSeen"
        static let quickHelpOn = "quickHelpOn"
        static let houseStyle = "houseStyle"
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
    /// Ollama is optional; it runs on port 11434 unless changed. No model is chosen until Ivan names one.
    var ollamaAddress: String { didSet { defaults.set(ollamaAddress, forKey: Key.ollamaAddress) } }
    var ollamaModel: String { didSet { defaults.set(ollamaModel, forKey: Key.ollamaModel) } }
    /// Anthropic's model (the preference keeps v1's name). Its key is never here: it lives in the Keychain (KeyStore).
    var claudeModel: String { didSet { defaults.set(claudeModel, forKey: Key.claudeModel) } }
    /// OpenAI's model (v2 part M5b), chosen from its list; empty until Ivan picks one, because no OpenAI model
    /// id is written into the app (PLAN M5).
    var openAIModel: String { didSet { defaults.set(openAIModel, forKey: Key.openAIModel) } }

    /// The newest file-system event already looked at, and the disk it belongs to: the watcher
    /// replays from here on the next launch. Kept as text because UserDefaults has no 64-bit unsigned type.
    var lastEventID: UInt64 { didSet { defaults.set(String(lastEventID), forKey: Key.lastEventID) } }
    var eventDevice: String { didSet { defaults.set(eventDevice, forKey: Key.eventDevice) } }
    /// When engine v0's state.json was taken in at the switch-over. Read once, never again.
    var engineV0ImportedAt: Date? { didSet { defaults.set(engineV0ImportedAt, forKey: Key.engineV0ImportedAt) } }
    /// The Help article open last, so Help opens where Ivan left it (v2 part M2a).
    var helpLastArticle: String? { didSet { defaults.set(helpLastArticle, forKey: Key.helpLastArticle) } }
    /// The welcome window's version once it has been shown (v2 part M2b); 0 until then. The window opens
    /// by itself only while this is lower than `WelcomeContent.version`. Each mode keeps its own, so the
    /// first-launch check can delete the development one (`defaults delete` on the development domain)
    /// and never touch the live one.
    var welcomeSeenVersion: Int { didSet { defaults.set(welcomeSeenVersion, forKey: Key.welcomeSeenVersion) } }

    /// The main window as Ivan left it (v2 part M3b, design spec 2.5): group, selection, open recording,
    /// rendition, the moment playing and the inspector's tab, as JSON (`WindowState`). Each mode keeps its own.
    var windowState: String? { didSet { defaults.set(windowState, forKey: Key.windowState) } }
    /// Follow Playback in the Viewer (View menu); on until turned off.
    var followPlayback: Bool { didSet { defaults.set(followPlayback, forKey: Key.followPlayback) } }
    /// The Viewer's first-time tip was dismissed with Got It.
    var viewerTipSeen: Bool { didSet { defaults.set(viewerTipSeen, forKey: Key.viewerTipSeen) } }
    /// Help > Show Quick Help; off until turned on.
    var quickHelpOn: Bool { didSet { defaults.set(quickHelpOn, forKey: Key.quickHelpOn) } }
    /// Settings, House Style (v2 part M9a): the style, pace, punch-ins and the room at the end every video is planned with.
    var houseStyle: HouseStyle { didSet { defaults.set(houseStyle.json(), forKey: Key.houseStyle) } }

    nonisolated static let defaultLMStudioAddress = "http://localhost:1235/v1"
    nonisolated static let defaultLMStudioModel = "qwen/qwen3.8-27b"
    nonisolated static let defaultOllamaAddress = "http://localhost:11434"
    /// Claude Sonnet 5.5, by Ivan's decision of Mon 12 Oct (PLAN section 11: Sonnet by default, Opus 5.5 for an
    /// accuracy pass; his recorded cost lever). A model he chose before keeps his choice.
    nonisolated static let defaultClaudeModel = "claude-sonnet-5-5"

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
        // Planning the edit (v2 part M9c), never chosen before, follows the writing's choice: Ivan moved writing to Anthropic
        // on 12 Oct, and the same model reading the talk for the plan is what he would expect.
        if defaults.string(forKey: Key.providerPrefix + ModelTask.planning.rawValue) == nil {
            provider[.planning] = provider[.writing] ?? .lmStudio
        }
        self.provider = provider
        lmStudioAddress = defaults.string(forKey: Key.lmStudioAddress) ?? Self.defaultLMStudioAddress
        lmStudioModel = defaults.string(forKey: Key.lmStudioModel) ?? Self.defaultLMStudioModel
        ollamaAddress = defaults.string(forKey: Key.ollamaAddress) ?? Self.defaultOllamaAddress
        ollamaModel = defaults.string(forKey: Key.ollamaModel) ?? ""
        claudeModel = defaults.string(forKey: Key.claudeModel) ?? Self.defaultClaudeModel
        openAIModel = defaults.string(forKey: Key.openAIModel) ?? ""
        lastEventID = defaults.string(forKey: Key.lastEventID).flatMap(UInt64.init) ?? 0
        eventDevice = defaults.string(forKey: Key.eventDevice) ?? ""
        engineV0ImportedAt = defaults.object(forKey: Key.engineV0ImportedAt) as? Date
        helpLastArticle = defaults.string(forKey: Key.helpLastArticle)
        welcomeSeenVersion = defaults.integer(forKey: Key.welcomeSeenVersion)
        windowState = defaults.string(forKey: Key.windowState)
        followPlayback = defaults.object(forKey: Key.followPlayback) as? Bool ?? true
        viewerTipSeen = defaults.bool(forKey: Key.viewerTipSeen)
        quickHelpOn = defaults.bool(forKey: Key.quickHelpOn)
        houseStyle = HouseStyle.decode(defaults.string(forKey: Key.houseStyle))
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
