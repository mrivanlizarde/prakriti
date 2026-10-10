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
        .commands { AppCommands(model: model) }

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

enum MainWindow {
    static let id = "main"
    /// The size the window opens at, and the size every snapshot is rendered at.
    static let size = CGSize(width: 1180, height: 760)
    static let minimumSize = CGSize(width: 900, height: 600)
}

/// Keeps Prakriti running when its window is closed: the watcher (milestone 3) must keep working.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // macOS can quit an app with no windows on its own (automatic termination). Prakriti
        // must not be quit that way, so it opts out here as well as in Info.plist.
        ProcessInfo.processInfo.disableAutomaticTermination("Prakriti keeps working with its window closed.")
        guard let model = AppModel.current, !AppModel.isRunningTests else { return }
        model.log.write("Finished launching. Menu bar item: \(model.settings.showInMenuBar ? "shown" : "hidden").")

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

    func applicationWillTerminate(_ notification: Notification) {
        guard !AppModel.isRunningTests else { return }
        AppModel.current?.log.write("Quit.")
    }
}

/// The menu bar commands: Add File, Add Folder, Pause All, and Settings in the main window.
struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: MainWindow.id)
                model.open(.settings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {
            Button("Add File…") { model.chooseFiles() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Add Folder…") { model.chooseFolder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Divider()
            Button(model.settings.isPaused ? "Resume All" : "Pause All") {
                model.setPaused(!model.settings.isPaused)
            }
        }
    }
}
