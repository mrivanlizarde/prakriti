import SwiftData
import SwiftUI

/// The main window: a sidebar and the screen it opens.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Sidebar(selection: $model.selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            NavigationStack(path: $model.path) {
                screen(for: model.selection ?? .today)
                    .navigationDestination(for: RecordingRoute.self) { route in
                        RecordingDestination(route: route)
                    }
            }
        }
        .frame(minWidth: MainWindow.minimumSize.width, minHeight: MainWindow.minimumSize.height)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PauseButton()
            }
        }
        .onAppear {
            if model.openMainWindow == nil { model.openMainWindow = { openWindow(id: MainWindow.id) } }
            if model.openHelpWindow == nil { model.openHelpWindow = { openWindow(id: HelpWindow.id) } }
        }
        .alert(model.notice?.title ?? "", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } }),
               presenting: model.notice) { _ in
            Button("OK") { model.notice = nil }
        } message: { notice in
            Text(notice.message)
        }
    }

    @ViewBuilder
    private func screen(for item: SidebarItem) -> some View {
        switch item {
        case .today: TodayView()
        case .recordings: RecordingsView()
        case .sources: SourcesView()
        case .outputs: OutputsView()
        case .models: ModelsView()
        case .activity: ActivityView()
        case .settings: SettingsView()
        }
    }
}

struct Sidebar: View {
    @Binding var selection: SidebarItem?
    @Query private var recordings: [Recording]

    var body: some View {
        List(selection: $selection) {
            Section {
                row(.today, count: recordings.filter(\.status.needsYou).count)
                row(.recordings)
            }
            Section {
                row(.sources)
                row(.outputs)
                row(.models)
            }
            Section {
                row(.activity)
                row(.settings)
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ item: SidebarItem, count: Int = 0) -> some View {
        HStack {
            Label {
                Text(item.title)
                    .font(AppFont.body)
            } icon: {
                // No foregroundStyle here. The sidebar colors its own icons: accent at rest, white
                // on the selected row. An explicit .tint painted the selected row's icon in the
                // same accent as the selection, so it vanished (caught on the real window, 10 Oct).
                Image(systemName: item.symbol)
                    .font(AppFont.body)
            }
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(AppFont.secondaryEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(count) need you")
            }
        }
        .padding(.vertical, 3)
        .tag(item)
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

/// Resolves a route to its recording; the recording may have been removed since.
struct RecordingDestination: View {
    let route: RecordingRoute
    @Environment(\.modelContext) private var context

    var body: some View {
        if let recording = context.model(for: route.id) as? Recording, !recording.isDeleted {
            RecordingDetailView(recording: recording)
        } else {
            EmptyState(symbol: "questionmark.circle", title: "Recording not found",
                       message: "It may have been removed. It is still in its folder if it was there before.")
        }
    }
}
