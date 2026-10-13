import AppKit
import SwiftData
import SwiftUI

/// The Settings window (Command-comma, v2 part M3a, design spec 3.13): a standard Settings scene, one
/// pane at a time, about 760 pt wide. General (open at login, the menu bar, notifications, Pause All, the
/// welcome), Outputs (v1's Outputs screen as it was), Models (ModelsPane.swift, v2 part M5b), Privacy
/// (the rules that keep recordings and people safe), Advanced (where files live). Which outputs each
/// folder makes stays on the folder (START_HERE, Mac warning 28): select it under Sources.
struct SettingsWindow: View {
    @Environment(AppModel.self) private var model

    static let width: CGFloat = 760

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsPane) {
            ForEach(SettingsPane.allCases) { pane in
                SettingsPaneView(pane: pane)
                    .tabItem { Label(pane.title, systemImage: pane.symbol) }
                    .tag(pane)
            }
        }
            }

    /// The height each pane opens at. Outputs and Models are long and scroll.
    static func height(_ pane: SettingsPane) -> CGFloat {
        switch pane {
        case .general: 620
        case .outputs, .models: 700
        case .privacy: 560
        case .advanced: 460
        }
    }
}

/// One pane, at its own size.
struct SettingsPaneView: View {
    let pane: SettingsPane
    /// Snapshots only: a taller pane than the window, to draw every section.
    var height: CGFloat? = nil

    var body: some View {
        Group {
            switch pane {
            case .general: GeneralPane()
            case .outputs: OutputsView()
            case .models: ModelsPane()
            case .privacy: PrivacyPane()
            case .advanced: AdvancedPane()
            }
        }
        .frame(width: SettingsWindow.width, height: height ?? SettingsWindow.height(pane))
        // No field takes the keys when a pane opens: macOS gave the first one (Outputs' Show name) the focus,
        // which scrolled the pane past its first lines, and a key pressed would have typed into it (measured
        // in the real window, v2 part M3a).
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard let window = NSApp.windows.first(where: { $0.isVisible && $0.identifier?.rawValue.contains("Settings") == true }) ?? NSApp.keyWindow else { return }
                if window.firstResponder is NSText { window.makeFirstResponder(nil) }
                // Back to the pane's first line, under the toolbar.
                Self.scrollToTop(window.contentView)
            }
        }
    }

    private static func scrollToTop(_ view: NSView?) {
        guard let view else { return }
        if let scroll = view as? NSScrollView {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: -scroll.contentView.contentInsets.top))
            scroll.reflectScrolledClipView(scroll.contentView)
            return
        }
        view.subviews.forEach(scrollToTop)
    }
}

/// General: open at login, the menu bar item, notifications, Pause All and the welcome.
struct GeneralPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                LabeledContent {
                    if model.loginItem == .needsApproval || model.loginItem == .off {
                        Button("Open Login Items…") { LoginItem.openSettings() }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open at login").font(AppFont.body)
                        Text(model.loginItem.line)
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.showInMenuBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Prakriti in the menu bar").font(AppFont.body)
                        Text("Prakriti keeps running when the window is closed, with or without the menu bar item.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: Binding(get: { settings.isPaused }, set: { model.setPaused($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause All").font(AppFont.body)
                        Text("Stops finding and making anything new until you turn it back on. A recording already being made finishes first.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section {
                ForEach(NotificationEvent.allCases, id: \.self) { event in
                    Toggle(isOn: Binding(get: { settings.notify[event] ?? true }, set: { settings.notify[event] = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(AppFont.body)
                            Text(event.soundLine).font(AppFont.secondary).foregroundStyle(.appSecondary)
                        }
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    RowNote(permissionLine + " One notice per recording, updated as it moves along. Banner style and sound are set by macOS.")
                    Spacer(minLength: 12)
                    Button("Open Notification Settings…") { Notifier.openSystemSettings() }
                }
            } header: {
                SectionHeader("Notifications")
            }

            Section {
                LabeledContent {
                    Button("Show the Welcome Window Again") {
                        model.prepareWelcomeFromMenu()
                        openWindow(id: WelcomeWindow.id)
                        NSApp.activate()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome").font(AppFont.body)
                        Text("What Prakriti does, how to record for the best results, and where to start.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissionLine: String {
        switch model.notifier.permission {
        case .allowed: "macOS allows Prakriti's notices."
        case .denied: "Notices are turned off for Prakriti in System Settings, so they are only written to the log."
        case .waitingForAnswer: "macOS has not been asked yet. Until notices are allowed, they are only written to the log."
        case .unknown: "Not checked yet."
        }
    }
}

/// Privacy: the rules, in plain sentences, each true of what the app does today.
struct PrivacyPane: View {
    var body: some View {
        Form {
            Section {
                PrivacyRule(symbol: "lock.fill",
                            text: PrivacyLock.settingsLine)
                PrivacyRule(symbol: "externaldrive",
                            text: "Recordings never leave this Mac. With an Anthropic or OpenAI key, only the words of a transcript are sent, names replaced, and never for the recordings above.")
                PrivacyRule(symbol: "person.2",
                            text: "Only a talk with one teacher speaking can be approved, and a class is never made ready to upload.")
                PrivacyRule(symbol: "bell",
                            text: "Notices never show a file name, a title or a person's name, because they appear on the lock screen.")
                PrivacyRule(symbol: "checkmark.seal",
                            text: "Approve copies the finished files to the Approved folder with a receipt. Nothing is uploaded or posted; you do that by hand.")
            } header: {
                SectionHeader("What Prakriti does to keep recordings private")
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacyRule: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .font(AppFont.body)
                .foregroundStyle(AppColor.accentText)
        }
        .padding(.vertical, 2)
    }
}

/// Advanced: where files live. Nothing a person needs day to day.
struct AdvancedPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                if model.paths.mode == .development {
                    Label {
                        Text("A test copy: Prakriti uses the folders in ~/Prakriti/Dev and its own store, log and settings.")
                            .font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle").font(AppFont.body)
                    }
                }
                PathRow(label: "Finished files", path: model.paths.outputs.path)
                PathRow(label: "Approved files", path: model.paths.approved.path)
                PathRow(label: "Drop folder", path: model.paths.drop.path)
                PathRow(label: "Log files", path: model.paths.logs.path)
            } header: {
                SectionHeader("Where things are")
            }
        }
        .formStyle(.grouped)
    }
}
