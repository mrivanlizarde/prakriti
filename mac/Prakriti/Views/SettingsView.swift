import AppKit
import SwiftData
import SwiftUI

/// Pause All, the menu bar, notifications, and where everything lives.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle(isOn: Binding(get: { settings.isPaused }, set: { model.setPaused($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause All").font(AppFont.body)
                        Text("Stops finding and making anything new until you turn it back on.")
                            .font(AppFont.secondary).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.showInMenuBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Prakriti in the menu bar").font(AppFont.body)
                        Text("Prakriti keeps running when the window is closed, with or without the menu bar item.")
                            .font(AppFont.secondary).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: {
                SectionHeader("General")
            }

            Section {
                ForEach(sources) { source in
                    PathRow(label: source.name, path: source.path, showInFinder: false)
                }
                HStack {
                    Spacer()
                    Button("Change in Sources") { model.open(.sources) }
                }
            } header: {
                SectionHeader("Folders")
            }

            Section {
                ForEach(NotificationEvent.allCases, id: \.self) { event in
                    Toggle(isOn: Binding(get: { settings.notify[event] ?? true }, set: { settings.notify[event] = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(AppFont.body)
                            Text(event.soundLine).font(AppFont.secondary).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    RowNote("One notice per recording, updated as it moves along. Banner style and sound are set by macOS.")
                    Spacer(minLength: 12)
                    Button("Open Notification Settings…") { openNotificationSettings() }
                }
            } header: {
                SectionHeader("Notifications")
            }

            Section {
                ForEach(ModelTask.allCases, id: \.self) { task in
                    ValueRow(label: task.title, value: (settings.provider[task] ?? .lmStudio).title)
                }
                HStack {
                    Spacer()
                    Button("Change in Models") { model.open(.models) }
                }
            } header: {
                SectionHeader("Model providers")
            }

            Section {
                if model.paths.mode == .development {
                    Label {
                        Text("Test setup: Prakriti uses the folders in ~/Prakriti/Dev until it takes over from the old engine.")
                            .font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle").font(AppFont.body)
                    }
                }
                PathRow(label: "Finished files", path: model.paths.outputs.path)
                PathRow(label: "Approved files", path: model.paths.approved.path)
                PathRow(label: "Log files", path: model.paths.logs.path)
            } header: {
                SectionHeader("Where things are")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
