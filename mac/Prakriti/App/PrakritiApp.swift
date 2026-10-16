import AppKit
import SwiftData
import SwiftUI

@main
struct PrakritiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.launch()

    var body: some Scene {
        Window("Prakriti", id: MainWindow.id) {
            MainView()
                .environment(model)
                .modelContainer(model.container)
                // Only the real-window capture sets this; otherwise the window follows the Mac.
                // (Setting NSApp.appearance before launch finished stopped the window from opening.)
                .preferredColorScheme(CaptureLaunch.current?.colorScheme)
        }
        .defaultSize(width: MainWindow.size.width, height: MainWindow.size.height)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(mainLaunchBehavior)
        .commands { AppCommands(model: model) }

        // Prakriti Help (v2 part M2a): opened from the Help menu, its search, or a capture.
        Window("Prakriti Help", id: HelpWindow.id) {
            HelpWindow()
                .environment(model)
                                .preferredColorScheme(CaptureLaunch.current?.colorScheme)
        }
        .defaultSize(width: HelpWindow.size.width, height: HelpWindow.size.height)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(CaptureLaunch.current?.showsHelp == true ? .presented : .suppressed)
        // Never reopened by itself at the next launch: Prakriti opens at login, and Help is asked for.
        .restorationBehavior(.disabled)

        // The welcome (v2 part M2b): five panels, opened by itself only at the first launch made by hand
        // (`welcomeSeenVersion`), and from Help, Welcome to Prakriti. Never under sample data unless a
        // capture asks for it, never restored at a later launch, and never in the way of the watcher.
        Window("Welcome to Prakriti", id: WelcomeWindow.id) {
            WelcomeWindow()
                .environment(model)
                .modelContainer(model.container)
                                .preferredColorScheme(CaptureLaunch.current?.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(model.welcome.presentsAtLaunch ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        // The Settings window (v2 part M3a, Command-comma): v1's Outputs and Models screens and its
        // settings moved here from the sidebar (design spec C5).
        Settings {
            SettingsWindow()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(CaptureLaunch.current?.colorScheme)
        }

        // Window, Activity (v2 part M3a): v1's Activity screen, out of the sidebar. Part M4a builds it out.
        Window("Activity", id: ActivityWindow.id) {
            ActivityWindow()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(CaptureLaunch.current?.colorScheme)
        }
        .defaultSize(width: ActivityWindow.size.width, height: ActivityWindow.size.height)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .keyboardShortcut("9", modifiers: .command)

        MenuBarExtra(isInserted: Binding(get: { model.settings.showInMenuBar },
                                         set: { model.settings.showInMenuBar = $0 })) {
            MenuBarMenu()
                .environment(model)
                .modelContainer(model.container)
        } label: {
            MenuBarIcon()
                .environment(model)
                .modelContainer(model.container)
        }
        .menuBarExtraStyle(.menu)
    }
}

extension PrakritiApp {
    /// A capture of Help or the welcome alone (--sample-data --show=help or --show=welcome) opens only that
    /// window. At a launch that shows the welcome, the main window opens too, behind it (measured: left
    /// automatic, SwiftUI opened the welcome alone), so the app is there when the welcome closes.
    var mainLaunchBehavior: SceneLaunchBehavior {
        if let capture = CaptureLaunch.current, capture.showsHelp || capture.showsWelcome { return .suppressed }
        return model.welcome.presentsAtLaunch ? .presented : .automatic
    }
}

enum MainWindow {
    static let id = "main"
    /// The size the window opens at, and the size every snapshot is rendered at (design spec 2.2: 17 pt
    /// type needs the room; v1 was 1180 by 760).
    static let size = CGSize(width: 1440, height: 900)
    static let minimumSize = CGSize(width: 1100, height: 720)
}

/// Keeps Prakriti running when its window is closed: the watcher must keep working.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationSignal: DispatchSourceSignal?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // macOS can quit an app with no windows on its own (automatic termination). Prakriti
        // must not be quit that way, so it opts out here as well as in Info.plist.
        ProcessInfo.processInfo.disableAutomaticTermination("Prakriti keeps working with its window closed.")
        guard let model = AppModel.current, !AppModel.isRunningTests else { return }
        LayoutAutosave.keepOutOfLivePreferences()

        // A second copy in the same mode: hand over to the one already running, and quit.
        if model.isDuplicate {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            others.first?.activate()
            NSApp.terminate(nil)
            return
        }

        // A plain `kill` (or `pkill`, as the install script and the checks use) quits cleanly, the
        // same as Quit: the running tool is stopped and the log says so. Without this, SIGTERM
        // ends the process on the spot.
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        terminationSignal = source

        // The Help menu's search field lists Help articles beside the menu commands (v2 part M2a).
        if let search = model.helpMenuSearch {
            NSApp.registerUserInterfaceItemSearchHandler(search)
        }
        if !model.help.library.problems.isEmpty {
            model.log.write("Help could not read \(model.help.library.problems.count) article(s): \(model.help.library.problems.joined(separator: "; "))")
        }

        let atLogin = Self.launchedAsLoginItem
        model.log.write("Finished launching\(atLogin ? " at login" : ""). Mode: \(model.paths.mode.rawValue). Menu bar item: \(model.settings.showInMenuBar ? "shown" : "hidden").")
        // The welcome counts as seen only at a launch made by hand (v2 part M2b): at login every window
        // is closed below, the welcome too, and it waits for the next launch Ivan makes himself.
        model.launchFinished(atLogin: atLogin)
        // What was approved is read again at every launch (v2 part M11b): Ready holds only what still passes.
        model.recheckApprovals()
        if atLogin {
            // Opened by macOS at login: the watcher starts, and no window jumps up on every login.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }.forEach { $0.performClose(nil) }
            }
        }

        // A self-check used by the milestone checks: close the window, then prove the app is
        // still running by writing to the log a few seconds later.
        if CommandLine.arguments.contains("--check-keeps-running") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let windows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }
                windows.forEach { $0.performClose(nil) }
                model.log.write("Self-check: closed \(windows.count) window(s).")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    let open = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }.count
                    model.log.write("Self-check: still running 3 s after closing the window. Open windows: \(open).")
                }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Login Items can be switched off in System Settings with no notice to the app, so the
        // state is read again whenever Prakriti comes to the front (research 02 §5).
        guard let model = AppModel.current, !AppModel.isRunningTests, !model.isDuplicate else { return }
        // Notifications can be turned on or off in System Settings while Prakriti runs.
        Task { await model.notifier.refreshPermission(askIfNeeded: false) }
        guard model.paths.mode == .live else { return }
        let state = LoginItem.status
        if model.loginItem != .notInstalled, state != model.loginItem {
            model.loginItem = state
            model.log.write("Login item is now: \(state).")
        }
    }

    /// True when macOS opened Prakriti as a login item.
    private static var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !AppModel.isRunningTests, AppModel.current?.isDuplicate != true else { return }
        AppModel.current?.watcher.stop()
        // Stop the running tool rather than leave it working with no one to read its result. The
        // recording is marked Couldn't finish on the next launch.
        AppModel.current?.runner.stopAll()
        AppModel.current?.log.write("Quit.")
    }
}

/// The menu bar commands: Process File, Add File, Add Folder and Pause All in File; the browser's views
/// and the inspector in View; Open, Back and a recording's actions in a Recording menu (v2 part M3a,
/// design spec 6.7 and 6.8); and the Help menu. Settings is the Settings scene's own item (Command-comma).
struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    /// The Edit menu's name for the chosen span's action.
    private var spanActionTitle: String {
        guard let recording = model.focusedRecording, let span = model.viewer.selectedSpan,
              let title = SelectedSpanStrip.actionTitle(model.spanEdit(span, in: recording)) else { return "Restore or Remove Span" }
        return title + " Span"
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Process File…") { model.chooseFilesToProcess() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Add File…") { model.chooseFiles() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Add Folder…") { model.chooseFolder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Divider()
            // The timelines (v2 part M10a, design spec 3.12): written beside the outputs when needed, then shown in the Finder.
            Button("Export Final Cut Pro Timeline") { model.exportTimeline(.finalCut) }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!model.canExportTimeline)
            Button("Export DaVinci Resolve Timeline") { model.exportTimeline(.resolve) }
                .disabled(!model.canExportTimeline)
            Divider()
            Button(model.settings.isPaused ? "Resume All" : "Pause All") {
                model.setPaused(!model.settings.isPaused)
            }
        }
        CommandGroup(before: .sidebar) {
            Button("as Grid") { model.browserMode = .grid }
                .keyboardShortcut("1", modifiers: .command)
            Button("as List") { model.browserMode = .list }
                .keyboardShortcut("2", modifiers: .command)
            Divider()
        }
        // Edit (v2 part M3b): the transcript's Find and the selected words' Remove and Keep.
        CommandGroup(after: .textEditing) {
            Button("Find in Transcript…") { model.findInTranscript() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(model.path.isEmpty || model.viewer.document.isEmpty)
            Button("Remove from the Edit") { model.focusedRecording.map { _ = model.removeSelectedWords(from: $0) } }
                .disabled(model.path.isEmpty || model.focusedRecording.map(model.canRemoveSelectedWords) != true)
            Button("Keep in the Edit") { model.focusedRecording.map { _ = model.keepSelectedWords(in: $0) } }
                .disabled(model.path.isEmpty || model.focusedRecording.map(model.canKeepSelectedWords) != true)
            // The chosen Timeline-lite span's one action (v2 part M8c): Restore or Remove, as the inspector's strip shows it.
            Button(spanActionTitle) { model.focusedRecording.map { r in model.viewer.selectedSpan.map { _ = model.applySpanEdit($0, in: r) } } }
                .disabled(model.path.isEmpty || spanActionTitle == "Restore or Remove Span")
        }
        CommandGroup(after: .sidebar) {
            Toggle("Follow Playback", isOn: Binding(get: { model.viewer.followPlayback }, set: { model.setFollowPlayback($0) }))
            // The People overlay over the Original (v2 part M6d), the same as the toggle on the picture.
            Toggle("People", isOn: Binding(get: { model.viewer.showsPeople }, set: { model.setShowsPeople($0) }))
                .disabled(model.path.isEmpty || model.viewer.rendition != .original)
            // The video's captions over the picture (v2 part M8c), the same as the toggle on the picture.
            Toggle("Captions", isOn: Binding(get: { model.viewer.showsCaptions }, set: { model.setShowsCaptions($0) }))
                .disabled(model.path.isEmpty || model.viewer.rendition != .video || model.viewer.captions.isEmpty)
            // The 9:16 window the shorts use (v2 part M11a), the same as the toggle on the picture.
            Toggle("Vertical Guide", isOn: Binding(get: { model.viewer.showsVerticalGuide }, set: { model.setShowsVerticalGuide($0) }))
                .disabled(model.path.isEmpty || (model.viewer.rendition != .original && model.viewer.rendition != .video))
            Divider()
            Button(model.inspectorShown ? "Hide Inspector" : "Show Inspector") { model.inspectorShown.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            ForEach(Array(InspectorTab.allCases.enumerated()), id: \.element) { index, tab in
                Button("Inspector: \(tab.title)") {
                    model.inspectorShown = true
                    model.inspectorTab = tab
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
            }
            Divider()
        }
        CommandMenu("Recording") {
            Button("Open") { model.openSelected() }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(!model.path.isEmpty || model.selectedRecordings.count != 1)
            Button("Back to Library") { model.back() }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(model.path.isEmpty)
            Divider()
            Button("Show Original in Finder") { model.focusedRecording.map(model.showOriginalInFinder) }
                .disabled(model.focusedRecording == nil)
            Button("Show Outputs in Finder") { model.focusedRecording.map(model.showOutputsInFinder) }
                .disabled(model.focusedRecording?.outputFolder == nil)
            Divider()
            Button("Make Again…") { model.focusedRecording.map { model.ask(.makeAgain, for: $0) } }
                .disabled(model.focusedRecording.map(model.canMakeAgain) != true)
            Button("Approve…") { model.focusedRecording.map { model.ask(.approve, for: $0) } }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(model.focusedRecording.map { model.approvalCheck($0).canApprove } != true)
            // Design spec 3.8 and 6.8 (v2 part M12a).
            Button("Find Supporting Moments…") { model.focusedRecording.map { model.findSupportingMoments($0) } }
                .disabled(model.focusedRecording.map(model.canFindSupportingMoments) != true)
            Divider()
            Button("Remove from Library…") { model.focusedRecording.map { model.ask(.removeFromLibrary, for: $0) } }
                .disabled(model.focusedRecording.map(model.canRemoveFromLibrary) != true)
        }
        // Playback (v2 part M3b, design spec 6.8). Space, J, K and L work in the Viewer itself; they are not
        // given to these items, because a menu's Space would be taken from every text field too.
        CommandMenu("Playback") {
            Button("Play or Pause (Space)") { model.viewer.togglePlay() }
                .disabled(model.path.isEmpty)
            Button("Play Backward (J)") { model.viewer.shuttle("j") }
                .disabled(model.path.isEmpty)
            Button("Stop (K)") { model.viewer.shuttle("k") }
                .disabled(model.path.isEmpty)
            Button("Play Forward (L)") { model.viewer.shuttle("l") }
                .disabled(model.path.isEmpty)
        }
        // The Help menu (v2 parts M2a and M2b). macOS adds its own search field at the top, which also
        // lists Help articles through HelpMenuSearch.
        CommandGroup(replacing: .help) {
            Button("Prakriti Help") {
                openWindow(id: HelpWindow.id)
                NSApp.activate()
            }
            .keyboardShortcut("?", modifiers: .command)
            Button("Welcome to Prakriti") {
                model.prepareWelcomeFromMenu()
                openWindow(id: WelcomeWindow.id)
                NSApp.activate()
            }
            Button(model.quickHelp.isOn ? "Hide Quick Help" : "Show Quick Help") { model.setQuickHelp(!model.quickHelp.isOn) }
            Divider()
            Button("Show Log in Finder") { model.showLogInFinder() }
        }
    }
}

/// Keeps a window capture (`--sample-data`) and a development copy (`--development`) from writing window
/// and split-view sizes into the live copy's preferences. Reason (12 Oct): every copy shares the bundle
/// identifier, so AppKit's autosave wrote `NSSplitView Subview Frames main` (220/860x795 became 220/1220x900)
/// and the Settings window's frame into Ivan's live domain during `make look`, although the app's own
/// settings already went to the ephemeral suite. Only the main window's frame had been switched off.
/// `scripts/capture-window.swift` also puts back any layout key a run changed, and fails if it cannot.
@MainActor
enum LayoutAutosave {
    private static var observer: WindowUpdateObserver?

    static var applies: Bool { CaptureLaunch.current != nil || AppMode.current == .development }

    static func keepOutOfLivePreferences() {
        guard applies, observer == nil else { return }
        NSApp.windows.forEach(forget)
        // Every window as soon as AppKit updates it, before a size it gets can be saved; SwiftUI can name a
        // split view after the window first draws, so this is checked again at each update (cheap: a few
        // views, and only in these two modes).
        // A selector on a main-actor object, not a closure. Reason (12 Oct, W4 fail): the closure form is
        // Sendable, so reading the window's `windowNumber` in it was a warning that warnings-as-errors did not
        // stop, and passing the notification into `MainActor.assumeIsolated` is an error (sending 'note').
        // AppKit posts this notification on the main thread.
        let updates = WindowUpdateObserver()
        NotificationCenter.default.addObserver(updates, selector: #selector(WindowUpdateObserver.windowDidUpdate(_:)),
                                               name: NSWindow.didUpdateNotification, object: nil)
        observer = updates
    }

    static func forget(_ window: NSWindow) {
        if !window.frameAutosaveName.isEmpty { window.setFrameAutosaveName("") }
        clearSplitViews(in: window.contentView)
    }

    private static func clearSplitViews(in view: NSView?) {
        guard let view else { return }
        if let split = view as? NSSplitView, split.autosaveName != nil { split.autosaveName = nil }
        for subview in view.subviews { clearSplitViews(in: subview) }
    }
}

/// Receives `NSWindow.didUpdateNotification` for `LayoutAutosave` on the main actor.
@MainActor
final class WindowUpdateObserver: NSObject {
    @objc func windowDidUpdate(_ note: Notification) {
        if let window = note.object as? NSWindow { LayoutAutosave.forget(window) }
    }
}

