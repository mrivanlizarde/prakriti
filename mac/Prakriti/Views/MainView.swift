import AppKit
import SwiftData
import SwiftUI

/// The main window (v2 part M3a, docs/v2/design-spec.md 2.1 to 2.5): the Library sidebar (Needs You,
/// In Progress, Ready, All Recordings; the watched folders under Sources), the browser of recordings in
/// the middle (a grid or a list), and the inspector on the right for whatever is selected. Opening a
/// recording swaps the browser for the Viewer (v2 part M3b).
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        let _ = model.inspectorRedraw
        NavigationSplitView {
            Sidebar(selection: $model.selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            NavigationStack(path: $model.path) {
                LibraryView()
                    .navigationDestination(for: RecordingRoute.self) { route in
                        RecordingDestination(route: route)
                            .navigationBarBackButtonHidden(true)
                    }
            }
        }
        // Through `inspectorReported`, never straight into `inspectorShown`: the split view reports the end of
        // an animation that a newer key press has already overruled (Mac warning 107).
        .inspector(isPresented: Binding(get: { model.inspectorShown }, set: { model.inspectorReported($0) })) {
            InspectorView()
                .inspectorColumnWidth(min: 320, ideal: 360, max: 440)
        }
        .frame(minWidth: MainWindow.minimumSize.width, minHeight: MainWindow.minimumSize.height)
        .toolbar { MainToolbar() }
        .searchable(text: $model.search.text, tokens: $model.search.scopes, placement: .toolbar, prompt: "Search") { scope in
            Text(scope.title)
        }
        .searchSuggestions {
            if model.search.scopes.isEmpty {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope.suggestion).font(AppFont.body).searchCompletion(scope)
                }
            }
        }
        // Searching from the Viewer shows the results in the browser.
        .onChange(of: model.search.text) { _, text in
            if !text.trimmingCharacters(in: .whitespaces).isEmpty { model.back() }
        }
                .onAppear {
            if model.openMainWindow == nil { model.openMainWindow = { openWindow(id: MainWindow.id) } }
            if model.openHelpWindow == nil { model.openHelpWindow = { openWindow(id: HelpWindow.id) } }
            model.openSettingsWindow = { openSettings() }
            model.openActivityWindow = { openWindow(id: ActivityWindow.id) }
            model.openPendingWindow()
            // A window capture opens at the design size, never at a frame the live copy saved, and
            // saves no frame of its own into the live copy's preferences.
            if CaptureLaunch.current != nil {
                DispatchQueue.main.async {
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(MainWindow.id) == true }) else { return }
                    window.setFrameAutosaveName("")
                    window.setContentSize(MainWindow.size)
                    window.center()
                }
            }
        }
        .alert(model.notice?.title ?? "", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } }),
               presenting: model.notice) { _ in
            Button("OK") { model.notice = nil }
        } message: { notice in
            Text(notice.message)
        }
        // Name This Person (v2 part M7a), asked for from the People tab or a person's page.
        .sheet(item: $model.nameSheet) { request in
            NameThisPersonSheet(request: request)
        }
        // The Approve sheet (v2 part M11b, design spec 3.11).
        .sheet(item: $model.approveSheet) { request in
            ApproveSheet(request: request)
        }
        // Review Possible Matches and Merge 2 People (v2 part M7b).
        .sheet(item: $model.reviewSheet) { request in
            ReviewSheet(request: request)
        }
        .sheet(item: $model.mergeSheet) { request in
            MergeSheet(request: request)
        }
        .confirmationDialog(confirmationTitle, isPresented: Binding(get: { model.confirmation != nil },
                                                                    set: { if !$0 { model.confirmation = nil } }),
                            presenting: model.confirmation) { confirmation in
            switch confirmation.action {
            case .makeAgain: Button("Make Again") { model.confirm(confirmation) }
            case .approve: Button("Approve") { model.confirm(confirmation) }
            case .removeFromLibrary: Button("Remove from Library", role: .destructive) { model.confirm(confirmation) }
            }
            Button("Cancel", role: .cancel) { model.confirmation = nil }
        } message: { confirmation in
            Text(confirmationMessage(confirmation))
        }
    }

    private var confirmationTitle: String {
        guard let confirmation = model.confirmation, let recording = model.recording(id: confirmation.recordingID) else { return "" }
        let day = Format.dayLabel(recording.sessionDate)
        return switch confirmation.action {
        case .makeAgain: "Make \(day) again?"
        case .approve: "Approve \(day)?"
        case .removeFromLibrary: "Remove \(day) from the library?"
        }
    }

    private func confirmationMessage(_ confirmation: Confirmation) -> String {
        guard let recording = model.recording(id: confirmation.recordingID) else { return "" }
        return switch confirmation.action {
        case .makeAgain:
            "It is made again with its trim, its cuts and its choices. The files made before are replaced once the new ones are ready, and the original recording is not changed."
        case .approve:
            (model.approvalVersionLine(recording).map { "Approves the video's " + $0.prefix(1).lowercased() + $0.dropFirst() + " " } ?? "")
                + "Copies \(Format.madeFiles(ApprovalCheck.filesToApprove(recording))) to \(model.paths.display(model.approvedFolder(for: recording).path)), with a receipt. Nothing is uploaded or published."
        case .removeFromLibrary:
            "Prakriti forgets this recording and moves its files in Outputs to the Trash. The original recording and anything in Approved are not touched, and its folder does not bring it back as new. To bring it back, add the file with File, Add File."
        }
    }
}

/// The main window's toolbar (design spec 3.3): Back, the rendition picker, Make Again and Approve while a
/// recording is open in the Viewer; Grid or List and the Sort menu in the browser; Pause All, with its
/// words; the inspector's switch. The search field is the window's own (`searchable`).
struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        @Bindable var model = model
        if !model.path.isEmpty {
            ToolbarItem(placement: .navigation) {
                Button { model.back() } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityLabel("Back to the library")
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    RenditionPicker()
                    ShortPicker()
                }
            }
            if let recording = model.focusedRecording {
                if model.canMakeAgain(recording) {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Make Again…") { model.ask(.makeAgain, for: recording) }
                    }
                }
                if recording.status == .readyForYourYes || recording.status == .approvedCheckFailed {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Approve…") { model.ask(.approve, for: recording) }
                            .disabled(!model.approvalCheck(recording).canApprove)
                    }
                }
            }
        } else if model.selection != .people {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $model.browserMode) {
                    ForEach(BrowserMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .accessibilityLabel("View as")
            }
            ToolbarItem(placement: .principal) {
                SortMenu()
            }
        }
        // The Activity button (v2 part M4a, design spec 3.3): the line's percent while anything is made.
        ToolbarItem(placement: .primaryAction) {
            ActivityButton()
        }
        if model.path.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                PauseButton()
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { model.inspectorShown.toggle() } label: {
                Label(model.inspectorShown ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing")
            }
        }
    }
}

/// Sort and filter, in one menu (design spec 3.1.3). The filters are the kind of recording and, since v2 part
/// M6a, Other People Appear (two or more faces seen at once); the edited-video filter comes with its part.
struct SortMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Menu {
            Picker("Sort By", selection: $model.browserSort) {
                ForEach(BrowserSort.allCases) { sort in Text(sort.title).tag(sort) }
            }
            .pickerStyle(.inline)
            Divider()
            Section("Show") {
                ForEach(RecordingKind.choices, id: \.self) { kind in
                    Toggle(kind.choiceTitle, isOn: Binding(get: { model.kindFilter.contains(kind) },
                                                           set: { on in
                                                               if on { model.kindFilter.insert(kind) } else { model.kindFilter.remove(kind) }
                                                           }))
                }
                Button("Show Every Kind") { model.kindFilter = [] }
                    .disabled(model.kindFilter.isEmpty)
            }
            Section("People") {
                Toggle("Other People Appear", isOn: $model.otherPeopleFilter)
            }
        } label: {
            Label(model.kindFilter.isEmpty && !model.otherPeopleFilter ? "Sort" : "Sort and Filter", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Sort and filter")
    }
}

/// The Library sidebar (design spec 2.3): the smart groups with their counts, then each watched folder
/// and Add Folder. Two levels at most. Counts are plain 15 pt text, never a badge (badges draw under 12
/// pt), and the icons carry no color of their own (START_HERE, Mac warning 8: the sidebar colors them,
/// white on the selected row).
struct Sidebar: View {
    @Binding var selection: SidebarItem?
    @Environment(AppModel.self) private var model
    @Query(sort: \Source.addedAt) private var sources: [Source]
    @Query private var people: [Person]

    /// Pinned people, not hidden, favorites first then by name.
    var pinnedPeople: [Person] {
        people.filter { $0.pinned && !$0.hiddenFromPeople }.sorted { a, b in
            a.favorite != b.favorite ? a.favorite : a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SmartGroup.allCases) { group in
                    GroupRow(group: group)
                        .tag(SidebarItem.group(group))
                }
            } header: {
                SidebarHeader(title: "Library")
            }
            // People (v2 part M7a, design spec 2.3): the gallery, then each pinned person.
            Section {
                Label {
                    Text("People").font(AppFont.body)
                } icon: {
                    Image(systemName: "person.2").font(AppFont.body)
                }
                .padding(.vertical, 3)
                .tag(SidebarItem.people)
                ForEach(pinnedPeople) { person in
                    PinnedPersonRow(person: person)
                        .tag(SidebarItem.person(person.id))
                }
            } header: {
                SidebarHeader(title: "People")
            }
            Section {
                ForEach(sources) { source in
                    SourceRow(source: source, blocked: model.watcher.states[source.id]?.isBlocked == true)
                        .tag(SidebarItem.source(source.id))
                }
                Button { model.chooseFolder() } label: {
                    Label {
                        Text("Add Folder…").font(AppFont.body)
                    } icon: {
                        Image(systemName: "plus").font(AppFont.body)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
            } header: {
                SidebarHeader(title: "Sources")
            }
        }
        .listStyle(.sidebar)
    }
}

/// A pinned person under People: a person symbol and their name. Unpin from its menu. Not their key photo: a 20 pt photo
/// stood out from the selected row by 131 pixels where the sidebar's check needs 150 (measured in the M7a snapshots), and
/// the sidebar colors a symbol itself, white on the selected row (Mac warning 8).
struct PinnedPersonRow: View {
    let person: Person
    @State private var renaming = false

    var body: some View {
        Label {
            Text(person.name).font(AppFont.body).lineLimit(1)
        } icon: {
            Image(systemName: "person.crop.circle").font(AppFont.body)
        }
        .padding(.vertical, 3)
        .contextMenu { PersonMenu(person: person, renaming: $renaming) }
        .sheet(isPresented: $renaming) { RenameSheet(person: person) }
    }
}

/// A sidebar section's name, at 15 pt semibold in the measured secondary color (the system's sidebar headers
/// draw at 11 pt, and in a grey measured at 2.23 to 1 on the light sidebar).
struct SidebarHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.secondaryEmphasis)
            .foregroundStyle(.appSecondary)
            .textCase(nil)
    }
}

/// A smart group's row: its symbol, its name and, for the three groups that count, how many recordings
/// it holds, read with the group's own predicate.
struct GroupRow: View {
    let group: SmartGroup
    @Query private var members: [Recording]

    init(group: SmartGroup) {
        self.group = group
        _members = Query(filter: group.predicate)
    }

    var body: some View {
        HStack {
            Label {
                Text(group.title)
                    .font(AppFont.body)
            } icon: {
                // No foregroundStyle here. The sidebar colors its own icons: accent at rest, white
                // on the selected row. An explicit .tint painted the selected row's icon in the
                // same accent as the selection, so it vanished (caught on the real window, 10 Oct).
                Image(systemName: group.symbol)
                    .font(AppFont.body)
            }
            Spacer()
            if group.showsCount && !members.isEmpty {
                Text("\(members.count)")
                    .font(AppFont.secondaryEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(.appSecondary)
                    .accessibilityLabel("\(members.count)")
            }
        }
        .padding(.vertical, 3)
    }
}

/// A watched folder's row. A folder Prakriti cannot read shows a warning shape in place of its folder,
/// so the state is told by shape and by the inspector's words, never by color.
struct SourceRow: View {
    let source: Source
    let blocked: Bool

    var body: some View {
        Label {
            Text(source.name)
                .font(AppFont.body)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: blocked ? "exclamationmark.triangle" : (source.kind == .dropFolder ? "tray.and.arrow.down" : "folder"))
                .font(AppFont.body)
        }
        .padding(.vertical, 3)
        .accessibilityLabel(blocked ? "\(source.name), cannot be read" : source.name)
    }
}

/// Pause All, always one click away in the window's toolbar. It shows its name as well as its
/// symbol, because a tooltip would draw at 11 pt, under the 12 pt floor.
struct PauseButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let paused = model.settings.isPaused
        Button {
            model.setPaused(!paused)
        } label: {
            Label(paused ? "Resume All" : "Pause All", systemImage: paused ? "play.fill" : "pause.fill")
                .labelStyle(.titleAndIcon)
        }
    }
}

/// Resolves a route to its recording in the Viewer; the recording may have been removed since. Escape comes
/// back to the browser (design spec 2.5) and Space plays or pauses, with J, K and L to shuttle (design spec
/// 6.7): those keys are read by `ViewerKeys` from the app's event stream, never through SwiftUI's focus
/// (START_HERE, Mac warning 99). The focus is still set here, so the sidebar does not keep it.
struct RecordingDestination: View {
    let route: RecordingRoute
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if let recording = context.model(for: route.id) as? Recording, !recording.isDeleted {
                ViewerView(recording: recording)
            } else {
                ScrollView {
                    EmptyState(symbol: "questionmark.circle", title: "Recording not found",
                               message: "It may have been removed. It is still in its folder if it was there before.")
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
    }
}
