import AppKit
import SwiftData
import SwiftUI

/// The menu bar menu (design spec 3.14, v2 part M4a): a menu, not a popover (HIG). The status line, with the
/// make's percent and time left while one runs; how many recordings need you, when any do; Open Prakriti and
/// Show Activity; Pause All; Settings, Prakriti Help and Quit.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Query private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let summary = model.statusSummary(recordings: recordings, sources: sources)
        let needsYou = recordings.filter(\.status.needsYou).count
        Text(summary.line)
        if needsYou > 0 {
            Button(needsYou == 1 ? "1 recording needs you" : "\(needsYou) recordings need you") {
                model.open(.group(.needsYou))
                openWindow(id: MainWindow.id)
                NSApp.activate()
            }
        }
        Divider()
        Button("Open Prakriti") {
            openWindow(id: MainWindow.id)
            NSApp.activate()
        }
        Button("Show Activity") {
            openWindow(id: ActivityWindow.id)
            NSApp.activate()
        }
        .keyboardShortcut("9", modifiers: .command)
        Divider()
        Button(model.settings.isPaused ? "Resume All" : "Pause All") {
            model.setPaused(!model.settings.isPaused)
        }
        Divider()
        Button("Settings…") {
            openSettings()
            NSApp.activate()
        }
        .keyboardShortcut(",", modifiers: .command)
        Button("Prakriti Help") {
            openWindow(id: HelpWindow.id)
            NSApp.activate()
        }
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
