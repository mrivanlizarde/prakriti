import AppKit
import Foundation
import Observation
import SwiftData

/// What Choose Folder... on the last panel did, said on the row itself (an alert would land on the main
/// window, which may be closed behind the welcome).
enum WelcomeFolderChoice: Equatable, Sendable {
    case added(name: String)
    case alreadyWatched(name: String)
    case refused(name: String, reason: String)
}

/// The welcome window's state (v2 part M2b): the open panel, what the last panel's buttons did, and
/// whether this launch opens the window by itself.
@MainActor
@Observable
final class WelcomeModel {
    /// How this launch began, known once the app has finished launching (the app delegate says).
    enum Launch: Sendable { case unknown, login, byHand }

    /// The five panels this build shows (`Capabilities.built`), in order, and the What's New panel (v2 part M13).
    @ObservationIgnored let welcomePanels: [VisibleWelcomePanel]
    @ObservationIgnored let whatsNewPanels: [VisibleWelcomePanel]
    /// The window shows What's New in Prakriti instead of the five panels: at the first launch of a version with one, for
    /// someone who has seen the welcome before (design spec 4.1, the Pixelmator Pro and Final Cut Pro shape).
    var showsWhatsNew = false {
        didSet { panel = 0 }
    }
    /// The panels the window shows now.
    var panels: [VisibleWelcomePanel] { showsWhatsNew && !whatsNewPanels.isEmpty ? whatsNewPanels : welcomePanels }
    /// The open panel, counted from 0.
    var panel = 0 {
        didSet { if panel != min(max(panel, 0), panels.count - 1) { panel = min(max(panel, 0), panels.count - 1) } }
    }
    /// What Choose Folder... did, shown on its row.
    var folderChoice: WelcomeFolderChoice?

    /// The window opens by itself at this launch: the first launch (`welcomeSeenVersion` lower than
    /// `WelcomeContent.version`), or a capture of it (`--sample-data --show=welcome`). Read by the scene's
    /// launch behavior and by the notifier, which does not ask macOS at a launch that shows the welcome.
    @ObservationIgnored var presentsAtLaunch = false
    @ObservationIgnored var launch: Launch = .unknown
    /// The window appeared before the app knew whether macOS opened it at login.
    @ObservationIgnored var appearedBeforeLaunchFinished = false
    /// Help, Welcome to Prakriti opened it: shown by request, whatever the launch.
    @ObservationIgnored var openedFromMenu = false
    /// Panels whose fit was already written to the log at this launch.
    @ObservationIgnored var measuredPanels: Set<Int> = []
    /// The height each panel needs, measured as it was drawn (panel number, counted from 1), against
    /// the window's 600 pt. Read by the snapshot test; the log says the same for the real window.
    @ObservationIgnored private(set) var needed: [Int: Double] = [:]

    func record(needed height: Double, panel: Int) { needed[panel] = height }

    init(capabilities: Set<Capability> = Capabilities.built) {
        welcomePanels = WelcomeContent.visiblePanels(with: capabilities)
        whatsNewPanels = WelcomeContent.visibleWhatsNew(with: capabilities)
    }

    var current: VisibleWelcomePanel { panels[min(max(panel, 0), panels.count - 1)] }
    var isFirst: Bool { panel <= 0 }
    var isLast: Bool { panel >= panels.count - 1 }
    /// "2 of 5", in words and numbers, never dots (docs/v2/design-spec.md 4.1).
    var position: String { "\(panel + 1) of \(panels.count)" }

    func goForward() { if !isLast { panel += 1 } }
    func goBack() { if !isFirst { panel -= 1 } }
}

extension AppModel {
    /// The welcome has not been shown in this version yet.
    var welcomeIsDue: Bool { settings.welcomeSeenVersion < WelcomeContent.version }
    /// The welcome was seen in an earlier version, so this version shows only What's New (v2 part M13).
    var whatsNewIsDue: Bool { welcomeIsDue && settings.welcomeSeenVersion >= WelcomeContent.firstVersion }

    /// Help, Welcome to Prakriti: the window opens at the first panel, by request.
    func prepareWelcomeFromMenu() {
        welcome.showsWhatsNew = false
        welcome.panel = 0
        welcome.openedFromMenu = true
    }

    /// Called when the welcome window appears. It counts as seen once Ivan can see it, so it opens by
    /// itself at one launch only: the first launch made by hand. At a launch macOS made at login it is
    /// neither shown nor counted, because the app closes every window it opens at login (AppDelegate)
    /// and a welcome closed that way would never have been read. Returns false when the window should
    /// close again at once.
    func welcomeAppeared() -> Bool {
        if welcome.openedFromMenu {
            welcome.openedFromMenu = false
            log.write("Welcome shown (Help, Welcome to Prakriti).")
            settings.welcomeSeenVersion = max(settings.welcomeSeenVersion, WelcomeContent.version)
            return true
        }
        if CaptureLaunch.current != nil {
            log.write("Welcome shown (sample data for a window capture, at panel \(welcome.panel + 1) of \(welcome.panels.count); nothing is saved).")
            return true
        }
        switch welcome.launch {
        case .unknown:
            welcome.appearedBeforeLaunchFinished = true
            return true
        case .login:
            log.write("Welcome not shown: macOS opened Prakriti at login, so the welcome waits for a launch by hand.")
            return false
        case .byHand:
            markWelcomeSeen()
            return true
        }
    }

    /// Called by the app delegate once launching has finished and it knows whether macOS opened
    /// Prakriti at login.
    func launchFinished(atLogin: Bool) {
        welcome.launch = atLogin ? .login : .byHand
        guard CaptureLaunch.current == nil else { return }
        if !welcome.presentsAtLaunch {
            log.write("Welcome: seen before (version \(settings.welcomeSeenVersion)), so it is not shown. Help, Welcome to Prakriti opens it.")
            return
        }
        guard welcome.appearedBeforeLaunchFinished else { return }
        welcome.appearedBeforeLaunchFinished = false
        if atLogin {
            // The delegate closes every window opened at login, this one too; it stays unseen.
            log.write("Welcome not shown: macOS opened Prakriti at login, so the welcome waits for a launch by hand.")
        } else {
            markWelcomeSeen()
        }
    }

    private func markWelcomeSeen() {
        settings.welcomeSeenVersion = WelcomeContent.version
        if welcome.showsWhatsNew {
            log.write("What's New in Prakriti shown (version \(WelcomeContent.version)). It does not open by itself again; Help, Welcome to Prakriti opens the welcome.")
        } else {
            log.write("Welcome shown at first launch (version \(WelcomeContent.version)). It does not open by itself again; Help, Welcome to Prakriti opens it.")
        }
    }

    /// Whether a panel fits the window without scrolling (docs/v2/design-spec.md 4.1: everything fits at
    /// 17 pt). Written once per panel per launch: always for a window capture, so the check can read it,
    /// and otherwise only when a panel does not fit, which is a fault worth a line.
    func welcomeMeasured(panel: Int, needed: Double, room: Double) {
        welcome.record(needed: needed, panel: panel)
        guard !welcome.measuredPanels.contains(panel) else { return }
        let fits = needed <= room + 0.5
        guard CaptureLaunch.current != nil || !fits else { return }
        welcome.measuredPanels.insert(panel)
        log.write("Welcome panel \(panel) of \(welcome.panels.count) \(fits ? "fits" : "does not fit"): needs \(Int(needed.rounded())) pt of \(Int(room)) pt.")
    }

    /// Choose Folder... on the last panel: the system's Open panel, not modal, so nothing waits on it
    /// (the watcher and the window keep running), then the folder is watched as Add Folder does.
    func chooseFolderForWelcome() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch This Folder"
        panel.message = "Choose a folder for Prakriti to watch for new recordings."
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { _ = self?.watchFolderFromWelcome(at: url) }
        }
    }

    /// Watches a folder chosen on the last panel, with Add Folder's rules (Ask me first; development
    /// refuses the studio folder and ~/Prakriti outside Dev), and says what happened on the row.
    @discardableResult
    func watchFolderFromWelcome(at url: URL) -> WelcomeFolderChoice {
        let name = url.lastPathComponent.trimmingCharacters(in: .whitespaces)
        let path = url.standardizedFileURL.path
        let choice: WelcomeFolderChoice
        if let reason = paths.refusal(for: url, isFolder: true) {
            record("Did not add \(paths.display(path)). \(reason)", level: .attention)
            choice = .refused(name: name.isEmpty ? "This folder" : name, reason: reason)
        } else if ((try? context.fetch(FetchDescriptor<Source>())) ?? []).contains(where: { $0.path == path }) {
            choice = .alreadyWatched(name: name)
        } else if addSource(at: url) != nil {
            choice = .added(name: name)
        } else {
            choice = .alreadyWatched(name: name)
        }
        welcome.folderChoice = choice
        return choice
    }
}
