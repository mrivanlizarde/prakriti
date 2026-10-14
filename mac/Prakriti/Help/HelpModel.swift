import AppKit
import Foundation
import Observation

/// The Help window's state: which article is open, where Back and Forward go, and what is searched.
/// Owned by the app model, so the Help menu, its search and a Show Me link all reach the same window.
@MainActor
@Observable
final class HelpModel {
    @ObservationIgnored let library: HelpLibrary
    @ObservationIgnored let index: HelpSearchIndex
    /// Remembers the last article between launches (a preference; nothing else is kept).
    @ObservationIgnored private let remember: @MainActor (String) -> Void
    @ObservationIgnored private var movingThroughHistory = false

    /// The open article's id. Set by the sidebar's selection, a link, the Help menu or Back and Forward.
    var selection: String? {
        didSet {
            guard selection != oldValue else { return }
            if !movingThroughHistory, let oldValue {
                backStack.append(oldValue)
                forwardStack.removeAll()
            }
            if let selection {
                remember(selection)
                // Choosing an article ends a search: the article replaces the results.
                if !movingThroughHistory { searchText = "" }
            }
        }
    }

    /// The search field's text. Results show while it holds a word.
    var searchText = ""

    private(set) var backStack: [String] = []
    private(set) var forwardStack: [String] = []

    init(library: HelpLibrary, lastArticle: String?, remember: @escaping @MainActor (String) -> Void) {
        self.library = library
        index = HelpSearchIndex(library: library)
        self.remember = remember
        selection = lastArticle.flatMap { library.visibleArticle(id: $0)?.id } ?? library.home?.id
    }

    var article: HelpArticle? { selection.flatMap(library.visibleArticle(id:)) }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var results: [HelpSearchIndex.Result] { index.search(searchText) }

    /// Opens an article if this build shows it; a hidden or unknown id changes nothing.
    @discardableResult
    func open(_ id: String) -> Bool {
        guard let article = library.visibleArticle(id: id) else { return false }
        if selection == article.id { searchText = "" } else { selection = article.id }
        return true
    }

    /// Follows a link clicked inside an article. Only links to other articles are followed here; the
    /// `prakriti://` places are buttons, and nothing in Help ever opens a web page.
    func follow(_ url: URL) -> Bool {
        guard case .article(let id) = library.link(url.absoluteString) else { return false }
        return open(id)
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        if let selection { forwardStack.append(selection) }
        movingThroughHistory = true
        selection = previous
        movingThroughHistory = false
        searchText = ""
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        if let selection { backStack.append(selection) }
        movingThroughHistory = true
        selection = next
        movingThroughHistory = false
        searchText = ""
    }
}

/// What a Show Me button does: opens the place the article names. A group or a folder opens in the
/// main window; a Settings pane opens the Settings window; Activity opens its window (v2 part M3a).
@MainActor
enum HelpActions {
    static func show(_ place: HelpPlace, model: AppModel, openMainWindow: () -> Void) {
        switch place {
        case .group, .sources, .people, .person:
            openMainWindow()
            model.path = []
        case .settings, .activity:
            break
        }
        model.go(to: place)
        model.log.write("Help: Show Me opened \(place.logName).")
        if !AppModel.isRunningTests { NSApp.activate() }
    }
}

extension HelpPlace {
    var logName: String {
        switch self {
        case .group(let group): group.title
        case .sources: "Sources"
        case .settings(let pane): "Settings, \(pane.title)"
        case .activity: "Activity"
        case .people: "People"
        case .person: "a person in People"
        }
    }
}
