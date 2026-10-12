import AppKit
import SwiftData
import SwiftUI

/// The inspector (Command-Option-I, design spec 3.5): it follows the selection. A recording (selected in
/// the browser or open) shows its tabs, Outputs, Checks and Info, as a segmented row of symbols with the
/// tab's name under it at 21 pt (symbols alone would need tooltips). A folder selected in the sidebar
/// shows its settings; several recordings, a count; nothing, one line. The window's own background, and
/// native grouped forms rather than v1's grey cards.
struct InspectorView: View {
    @Environment(AppModel.self) private var model
    @Query private var recordings: [Recording]
    @Query private var sources: [Source]

    var body: some View {
        Group {
            if let recording = model.focusedRecording {
                RecordingInspector(recording: recording)
            } else if model.selectedRecordings.count > 1 {
                SelectionInspector(recordings: recordings.filter { model.selectedRecordings.contains($0.id) })
            } else if let source = model.selectedSource {
                SourceInspector(source: source)
            } else {
                // In a scroll view: a wrapped message in a narrow column otherwise asks for its full
                // height as the window's minimum (measured: 2,195 pt, which made the window taller than
                // the screen in a snapshot).
                ScrollView {
                    EmptyState(symbol: "sidebar.trailing", title: "Nothing selected",
                               message: "Select a recording to see its outputs, its checks and what it is. Select a folder under Sources to see how it is watched.")
                        .padding(.horizontal, 20)
                }
            }
        }
            }
}

/// A recording's three tabs.
struct RecordingInspector: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.inspectorTab {
            case .outputs: OutputsTab(recording: recording)
            case .checks: ChecksTab(recording: recording)
            case .info: InfoTab(recording: recording)
            }
        }
        // The tabs stay put above the scrolling form, inside the safe area (under the toolbar, not behind it).
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
            Picker("Inspector", selection: $model.inspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            Text(model.inspectorTab.title)
                .font(AppFont.sectionTitle)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
        }
    }
}

/// Several recordings selected: how many, and how long they run together.
struct SelectionInspector: View {
    let recordings: [Recording]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Format.count(recordings.count, "recording") + " selected")
                        .font(AppFont.sectionTitle)
                    let total = recordings.compactMap(\.duration).reduce(0, +)
                    if total > 0 {
                        Text(Format.length(total) + " in all.")
                            .font(AppFont.body)
                            .foregroundStyle(.appSecondary)
                    }
                }
                .padding(.vertical, 4)
                ForEach(recordings.sorted(by: Recording.newestFirst)) { recording in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recording.cardTitle).font(AppFont.body).lineLimit(1).truncationMode(.middle)
                            Text(Format.dayLabel(recording.sessionDate) + ". " + recording.status.title)
                                .font(AppFont.secondary).foregroundStyle(.appSecondary)
                        }
                    } icon: {
                        Image(systemName: recording.status.symbol).foregroundStyle(recording.status.tint)
                    }
                    .font(AppFont.body)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// A watched folder (design spec 3.5.6): where it is, whether Prakriti can read it and when it last
/// looked, what happens when a recording arrives and which outputs it makes, Check Now, Show in Finder and
/// Stop Watching. v1's Sources screen, for one folder.
struct SourceInspector: View {
    @Bindable var source: Source
    @Environment(AppModel.self) private var model
    @State private var confirmStop = false

    var body: some View {
        let state = model.watcher.states[source.id]
        Form {
            Section {
                Label {
                    Text(source.name)
                        .font(AppFont.sectionTitle)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: source.kind == .dropFolder ? "tray.and.arrow.down" : "folder")
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(AppColor.accentText)
                }
                .padding(.vertical, 4)
                PathRow(label: "Folder", path: source.path)
                Text("Prakriti only reads this folder; it never writes into it.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Label {
                    Text(watchLine(state))
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: state?.isBlocked == true ? "exclamationmark.triangle" : (model.settings.isPaused ? "pause.circle" : "checkmark.circle"))
                        .font(AppFont.body)
                        .foregroundStyle(state?.isBlocked == true ? Color.orange : .secondary)
                }
                HStack(spacing: 12) {
                    Button("Check Now") { model.checkNow() }
                        .disabled(!model.watcher.isRunning || model.settings.isPaused)
                    if state?.health == .notAllowed || state?.health == .waitingForPermission {
                        Button("Open Privacy Settings…") { SourceInspector.openFilesAndFolders() }
                    }
                }
            } header: {
                SectionHeader("Watching")
            }
            Section {
                Picker(selection: $source.modeRaw) {
                    ForEach(SourceMode.allCases, id: \.rawValue) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                } label: {
                    Text("When a recording arrives").font(AppFont.body)
                }
                .pickerStyle(.radioGroup)
                .font(AppFont.body)
                if source.mode == .automatic {
                    ForEach(OutputKind.built, id: \.self) { kind in
                        if let setting = source.setting(for: kind) {
                            OutputSwitch(setting: setting)
                        }
                    }
                } else {
                    RowNote("Prakriti tells you what it found and waits. Nothing is made until you choose Make Outputs.")
                }
            } header: {
                SectionHeader("Outputs")
            }
            Section {
                HStack {
                    Spacer()
                    Button("Stop Watching…", role: .destructive) { confirmStop = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Stop watching \(source.name)?", isPresented: $confirmStop) {
            Button("Stop Watching", role: .destructive) {
                model.remove(source)
                model.selection = .default
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Prakriti stops watching this folder. Nothing in the folder is deleted, and recordings already found stay in All Recordings.")
        }
    }

    /// System Settings at Privacy and Security, Files and Folders: where macOS keeps folder access.
    static func openFilesAndFolders() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }

    /// v1's Sources lines: watching and when it last looked, Pause All, not watching, or why it cannot read.
    private func watchLine(_ state: SourceWatchState?) -> String {
        if model.settings.isPaused { return "Paused. Nothing new is looked for until you resume." }
        guard model.isWatching else { return "Not watching right now." }
        if let state {
            return state.line + " Every folder is checked every 5 minutes, and at once when something changes."
        }
        return "Watching. Every folder is checked every 5 minutes, and at once when something changes."
    }
}
