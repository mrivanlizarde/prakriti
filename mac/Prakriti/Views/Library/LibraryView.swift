import AppKit
import SwiftData
import SwiftUI

/// The browser (v2 part M3a, docs/v2/design-spec.md 3.1 and 3.2): the recordings of the selected smart
/// group or folder, as a grid of cards or a list, in sections, sorted and filtered; or, while a search is
/// typed, every recording that matches. Dragging a file onto it adds it, and a folder is watched, as v1's
/// drop area did.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Source.addedAt) private var sources: [Source]
    @State private var dropTargeted = false

    var body: some View {
        let item = model.selection ?? .default
        Group {
            if model.search.isActive {
                SearchResultsBrowser()
            } else {
                switch item {
                case .group(let group): GroupBrowser(group: group)
                case .source(let id): SourceBrowser(sourceID: id)
                case .people: GalleryView()
                case .person(let id): PersonPage(personID: id)
                case .unnamed: UnnamedBrowser()
                }
            }
        }
        .navigationTitle(title(item))
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter(\.hasDirectoryPath)
            folders.forEach { model.addSource(at: $0) }
            model.addRecordings(urls.filter { !$0.hasDirectoryPath })
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The window's title: the group's or the folder's name (HIG toolbars: under 15 characters where it can be).
    private func title(_ item: SidebarItem) -> String {
        if model.search.isActive { return "Search" }
        switch item {
        case .group(let group): return group.title
        case .source(let id): return sources.first { $0.id == id }?.name ?? "Sources"
        case .people: return "People"
        case .person(let id): return model.namedPeopleList().first { $0.id == id }?.name ?? "People"
        case .unnamed: return "Unnamed People"
        }
    }
}

/// A smart group's recordings, read with the group's own predicate over the stored status.
struct GroupBrowser: View {
    let group: SmartGroup
    @Query private var members: [Recording]

    init(group: SmartGroup) {
        self.group = group
        _members = Query(filter: group.predicate)
    }

    var body: some View {
        BrowserBody(item: .group(group), recordings: members)
    }
}

/// One watched folder's recordings.
struct SourceBrowser: View {
    let sourceID: UUID
    @Query private var all: [Recording]

    var body: some View {
        BrowserBody(item: .source(sourceID), recordings: Library.members(of: .source(sourceID), in: all))
    }
}

/// Every recording that matches the search, in one section, with the sentences that matched.
struct SearchResultsBrowser: View {
    @Environment(AppModel.self) private var model
    @Query private var all: [Recording]

    var body: some View {
        let search = model.search
        let candidates = Library.filtered(all, kinds: model.kindFilter, otherPeople: model.otherPeopleFilter)
        var matches: [UUID: LibrarySearch.Match] = [:]
        for recording in candidates {
            let match = search.match(recording) { model.transcripts.lines(for: recording) }
            if !match.isEmpty { matches[recording.id] = match }
        }
        let found = Library.sorted(candidates.filter { matches[$0.id] != nil }, by: model.browserSort)
        return Group {
            if found.isEmpty {
                LibraryEmptyState(symbol: "magnifyingglass", title: "No recordings match \u{201C}\(search.text.trimmingCharacters(in: .whitespaces))\u{201D}",
                                  message: search.scopes == [.title] ? "Only titles and notes were searched." :
                                    search.scopes == [.said] ? "Only what was said was searched, in recordings with a transcript." :
                                    "Titles, notes and what was said were searched, in every recording.",
                                  buttons: [("Clear Search", { model.search = LibrarySearch() })])
            } else {
                let heading = found.count == 1 ? "1 recording matches" : "\(found.count) recordings match"
                BrowserContent(sections: [LibrarySection(id: "results", title: heading, recordings: found)], flat: found, matches: matches)
            }
        }
    }
}

/// The browser for one group or folder: filtered by kind, in its sections, or its empty state.
struct BrowserBody: View {
    let item: SidebarItem
    let recordings: [Recording]
    @Environment(AppModel.self) private var model

    var body: some View {
        let filtered = Library.filtered(recordings, kinds: model.kindFilter, otherPeople: model.otherPeopleFilter)
        let sections = Library.sections(for: item, recordings: filtered, sort: model.browserSort, waitingOrder: model.runner.waitingOrder)
        if filtered.isEmpty {
            if !recordings.isEmpty {
                LibraryEmptyState(symbol: "line.3.horizontal.decrease.circle", title: "No recordings match these filters",
                                  message: "Every recording shows again when the filters are cleared.",
                                  buttons: [("Clear Filters", { model.kindFilter = []; model.otherPeopleFilter = false })])
            } else {
                EmptyLibrary(item: item)
            }
        } else {
            BrowserContent(sections: sections, flat: sections.flatMap(\.recordings), matches: [:])
                // Inside the safe area, so it sits under the toolbar rather than behind it.
                .safeAreaInset(edge: .top, spacing: 0) {
                    if case .group(.needsYou) = item { StatusStrip().background(.background) }
                }
        }
    }
}

/// The grid or the list, as chosen (Command-1, Command-2).
struct BrowserContent: View {
    let sections: [LibrarySection]
    let flat: [Recording]
    let matches: [UUID: LibrarySearch.Match]
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.browserMode {
        case .grid: BrowserGrid(sections: sections, matches: matches)
        case .list: BrowserList(recordings: flat, matches: matches)
        }
    }
}

/// One line at the top of Needs You that says what Prakriti is doing: v1's Today line, kept where Ivan
/// looks first. It names a folder that cannot be read, Pause All, or that nothing is being watched.
struct StatusStrip: View {
    @Environment(AppModel.self) private var model
    @Query private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let summary = model.statusSummary(recordings: recordings, sources: sources)
        VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 10) {
            Image(systemName: summary.icon.rawValue)
                .font(AppFont.body)
                .foregroundStyle(.appSecondary)
                .accessibilityHidden(true)
            // At least 300 pt wide before it wraps: asked for its smallest size, a wrapping line otherwise
            // reflows to a word a line (measured: 2,084 pt with a folder that cannot be read).
            Text(summary.line)
                .font(AppFont.body)
                .foregroundStyle(.appSecondary)
                .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        // Prints due for deletion within 30 days (v2 part M7a, retention): one line each, in words.
        ForEach(model.retentionLines, id: \.self) { line in
            Label {
                Text(line)
                    .font(AppFont.body)
                    .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "calendar.badge.clock").font(AppFont.body).foregroundStyle(AppColor.accentText)
            }
        }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}

/// What a group or folder shows when it holds nothing (design spec 3.16): what will appear, that it
/// appears on its own, and the way to do it by hand.
struct EmptyLibrary: View {
    let item: SidebarItem
    @Environment(AppModel.self) private var model
    @Query(sort: \Source.addedAt) private var sources: [Source]
    @Query private var all: [Recording]

    var body: some View {
        switch item {
        case .group(.needsYou):
            if model.retentionLines.isEmpty {
                LibraryEmptyState(symbol: "checkmark.circle", title: "Nothing needs you", message: checkedLine, buttons: [])
            } else {
                // A deletion of prints coming within 30 days still needs to be seen when no recording waits (v2 part M7a).
                LibraryEmptyState(symbol: "calendar.badge.clock", title: "Nothing to approve",
                                  message: model.retentionLines.joined(separator: " "), buttons: [])
            }
        case .group(.inProgress):
            LibraryEmptyState(symbol: "progress.indicator", title: "Nothing is being made",
                              message: "Recordings in a folder set to Make outputs automatically start on their own. Add a file to make one now.",
                              buttons: [("Add File…", { model.chooseFiles() })])
        case .group(.ready):
            LibraryEmptyState(symbol: "checkmark.seal", title: "Nothing is approved yet",
                              message: "A recording you approve appears here, with its files in the Approved folder. Nothing is uploaded.",
                              buttons: [])
        case .group(.all):
            LibraryEmptyState(symbol: "square.grid.2x2", title: "No recordings yet",
                              message: "Recordings in the folders you watch appear here on their own. You can also drag a file here.",
                              buttons: [("Add Folder…", { model.chooseFolder() }), ("Add File…", { model.chooseFiles() })])
        case .source(let id):
            let name = sources.first { $0.id == id }?.name ?? "this folder"
            LibraryEmptyState(symbol: "folder", title: "Nothing found in \(name) yet",
                              message: "A new recording saved in this folder appears here on its own.", buttons: [])
        case .people, .person:
            LibraryEmptyState(symbol: "person.2", title: "No recordings", message: "A person's recordings appear here once you name them in a recording.", buttons: [])
        case .unnamed:
            LibraryEmptyState(symbol: "person.crop.circle.badge.questionmark", title: "Everyone is named",
                              message: "Every face and voice found in your recordings has a name.", buttons: [])
        }
    }

    /// "Prakriti checked 2 folders at 9:41 pm."
    private var checkedLine: String {
        guard model.isWatching, let last = model.watcher.lastCheck else {
            return model.statusSummary(recordings: all, sources: sources).line
        }
        return "Prakriti checked \(Format.count(sources.count, "folder")) at \(Format.clock(last)). Recordings that wait for your yes, need a decision or could not finish appear here."
    }
}

/// An empty state with up to two buttons.
struct LibraryEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let buttons: [(String, () -> Void)]

    var body: some View {
        VStack(spacing: 14) {
            EmptyState(symbol: symbol, title: title, message: message)
            if !buttons.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                        Button(button.0, action: button.1)
                            .controlSize(.large)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }
}
