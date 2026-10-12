import AppKit
import SwiftData
import SwiftUI

/// The menu bar menu: a menu, not a popover (HIG). Status first, then Open, Pause, Settings, Quit.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
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
            openSettings()
            NSApp.activate()
        }
        .keyboardShortcut(",", modifiers: .command)
        Button("Quit Prakriti") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

/// The menu bar icon: the app icon's cut disc as a template glyph, whose shape changes with the
/// state (the mark when idle, the halves lit in turn while working, a dot when something waits, an
/// exclamation mark for a problem, an outline when paused, a dashed outline when not watching).
/// The working frames are turned by the model's `WorkingTicker`, because a label cannot animate.
struct MenuBarIcon: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Query private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let summary = model.statusSummary(recordings: recordings, sources: sources)
        let working = summary.icon == .working
        Image(working ? model.ticker.frame : summary.icon.menuBarAsset)
            .accessibilityLabel("Prakriti: \(summary.line)")
            .onAppear {
                model.openMainWindow = { openWindow(id: MainWindow.id) }
                model.openHelpWindow = { openWindow(id: HelpWindow.id) }
                model.openSettingsWindow = { openSettings() }
                model.openActivityWindow = { openWindow(id: ActivityWindow.id) }
            }
            .onChange(of: working, initial: true) { _, isWorking in model.ticker.setWorking(isWorking) }
            // Hidden from the menu bar (Settings): nothing to animate.
            .onDisappear { model.ticker.setWorking(false) }
    }
}
