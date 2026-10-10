import AppKit
import SwiftData
import SwiftUI

/// The menu bar menu: a menu, not a popover (HIG). Status first, then Open, Pause, Settings, Quit.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let summary = model.statusSummary(recordings: recordings, sources: sources)
        Text(summary.line)
        Divider()
        Button("Open Prakriti") {
            openWindow(id: MainWindow.id)
            NSApp.activate()
        }
        Button(model.settings.isPaused ? "Resume All" : "Pause All") {
            model.setPaused(!model.settings.isPaused)
        }
        Divider()
        Button("Settings…") {
            openWindow(id: MainWindow.id)
            model.open(.settings)
            NSApp.activate()
        }
        .keyboardShortcut(",", modifiers: .command)
        Button("Quit Prakriti") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

/// The menu bar icon: an abstract mark whose shape changes with the state (idle ring, dotted
/// while working, filled when something waits, exclamation for a problem, pause when paused).
struct MenuBarIcon: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let summary = model.statusSummary(recordings: recordings, sources: sources)
        Image(systemName: summary.icon.rawValue)
            .accessibilityLabel("Prakriti: \(summary.line)")
            .onAppear { model.openMainWindow = { openWindow(id: MainWindow.id) } }
    }
}
