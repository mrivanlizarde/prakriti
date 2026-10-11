import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The folders Prakriti watches, what it makes from each, and the ways to add a recording by hand.
struct SourcesView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Source.addedAt) private var sources: [Source]
    @State private var sourceToRemove: Source?

    var body: some View {
        Form {
            Section {
                PageIntro(text: "Folders Prakriti watches for new recordings, and what it makes from each one. Prakriti only reads these folders; it never writes into them.")
                WatchingRow()
            }

            ForEach(sources) { source in
                SourceSection(source: source, state: model.watcher.states[source.id]) {
                    sourceToRemove = source
                }
            }

            Section {
                DropZone { urls in
                    let folders = urls.filter { $0.hasDirectoryPath }
                    folders.forEach { model.addSource(at: $0) }
                    model.addRecordings(urls.filter { !$0.hasDirectoryPath })
                }
                HStack(spacing: 12) {
                    Button("Add File…") { model.chooseFiles() }
                    Button("Add Folder…") { model.chooseFolder() }
                    Spacer()
                }
                .controlSize(.large)
            } header: {
                SectionHeader("Add by hand")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Sources")
        .confirmationDialog(removeTitle, isPresented: Binding(get: { sourceToRemove != nil }, set: { if !$0 { sourceToRemove = nil } }),
                            presenting: sourceToRemove) { source in
            Button("Stop Watching", role: .destructive) { model.remove(source) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Prakriti stops watching this folder. Nothing in the folder is deleted, and recordings already found stay in Recordings.")
        }
    }

    private var removeTitle: String {
        "Stop watching \(sourceToRemove?.name ?? "this folder")?"
    }

    /// System Settings at Privacy and Security, Files and Folders: where macOS keeps folder access.
    static func openFilesAndFolders() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Whether Prakriti is watching, when it last looked, and Check Now.
struct WatchingRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label {
                Text(line)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: icon)
                    .font(AppFont.body)
            }
            Spacer(minLength: 12)
            Button("Check Now") { model.checkNow() }
                .disabled(!model.watcher.isRunning || model.settings.isPaused)
        }
    }

    private var icon: String {
        model.settings.isPaused ? "pause.circle" : (model.isWatching ? "eye" : "eye.slash")
    }

    private var line: String {
        if model.settings.isPaused { return "Paused. Nothing new is looked for until you resume." }
        guard model.isWatching else { return "Not watching right now." }
        let last = model.watcher.lastCheck.map { " Last checked at \(Format.clock($0))." } ?? ""
        return "Watching for new recordings, and checking every folder every 5 minutes.\(last)"
    }
}

/// One watched folder: where it is, what the last look found, and what happens when a recording arrives.
struct SourceSection: View {
    @Bindable var source: Source
    var state: SourceWatchState?
    let onRemove: () -> Void

    var body: some View {
        Section {
            PathRow(label: "Folder", path: source.path)
            if let state {
                Label {
                    Text(state.line)
                        .font(AppFont.secondary)
                        .foregroundStyle(state.isBlocked ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: state.isBlocked ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(AppFont.secondary)
                        .foregroundStyle(state.isBlocked ? Color.orange : Color.green)
                }
                if state.health == .notAllowed || state.health == .waitingForPermission {
                    HStack {
                        Spacer()
                        Button("Open Privacy Settings…") { SourcesView.openFilesAndFolders() }
                    }
                }
            }

            Picker(selection: $source.modeRaw) {
                ForEach(SourceMode.allCases, id: \.rawValue) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            } label: {
                Text("When a recording arrives").font(AppFont.body)
            }

            if source.mode == .automatic {
                ForEach(OutputKind.built, id: \.self) { kind in
                    if let setting = source.setting(for: kind) {
                        OutputSwitch(setting: setting)
                    }
                }
            } else {
                RowNote("Prakriti tells you what it found and waits. Nothing is made until you choose.")
            }

            HStack {
                Spacer()
                Button("Stop Watching…", role: .destructive, action: onRemove)
            }
        } header: {
            HStack(spacing: 8) {
                Image(systemName: source.kind == .dropFolder ? "tray.and.arrow.down" : "folder")
                SectionHeader(source.name)
            }
        }
    }
}

/// An output's on and off switch, with its one-line description.
struct OutputSwitch: View {
    @Bindable var setting: OutputSetting
    /// A longer line in place of the output's one-line summary.
    var detail: String?

    var body: some View {
        OutputToggle(kind: setting.kind, isOn: $setting.isOn, detail: detail)
    }
}

/// The switch itself. An output that cannot be made (one not built yet) shows off and greyed,
/// whatever is stored, so the screen never claims it is made.
struct OutputToggle: View {
    let kind: OutputKind
    @Binding var isOn: Bool
    var detail: String?

    var body: some View {
        Toggle(isOn: Binding(get: { isOn && kind.isAvailable }, set: { isOn = $0 })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(AppFont.body)
                Text(detail ?? line).font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!kind.isAvailable)
    }

    private var line: String { kind.summary }
}

/// Drop a recording (or a folder) here. A dashed outline is the standard sign of a drop target.
struct DropZone: View {
    let onDrop: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.to.line")
                .font(AppFont.sectionTitle)
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("Drop a recording here")
                .font(AppFont.headline)
            Text("Or a folder, to watch it.")
                .font(AppFont.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            onDrop(urls)
            return !urls.isEmpty
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Drop a recording file to add it, or a folder to watch it.")
    }
}
