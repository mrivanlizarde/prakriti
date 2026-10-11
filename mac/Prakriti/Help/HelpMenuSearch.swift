import AppKit
import Foundation

/// The Help menu's own search field: typing there lists matching Help articles under the menu commands
/// macOS finds by itself (docs/v2/design-spec.md 5.5). Registered once at launch with
/// `NSApp.registerUserInterfaceItemSearchHandler(_:)`. Each item is an article id.
///
/// macOS may call the search off the main thread, so the handler holds only the immutable index;
/// opening an article hops to the main actor.
final class HelpMenuSearch: NSObject, NSUserInterfaceItemSearching, Sendable {
    let index: HelpSearchIndex
    /// Opens the Help window at an article, or with a search filled in (Show All Help Topics).
    private let open: @MainActor @Sendable (_ articleID: String?, _ search: String?) -> Void

    init(index: HelpSearchIndex, open: @escaping @MainActor @Sendable (_ articleID: String?, _ search: String?) -> Void) {
        self.index = index
        self.open = open
    }

    func searchForItems(withSearch searchString: String, resultLimit: Int, matchedItemHandler handleMatchedItems: @escaping ([Any]) -> Void) {
        handleMatchedItems(index.search(searchString, limit: resultLimit).map(\.id))
    }

    func localizedTitles(forItem item: Any) -> [String] {
        guard let id = item as? String, let entry = index.entry(id: id) else { return [] }
        return [entry.title]
    }

    func performAction(forItem item: Any) {
        guard let id = item as? String else { return }
        let open = open
        Task { @MainActor in open(id, nil) }
    }

    func showAllHelpTopics(forSearch searchString: String) {
        let open = open
        Task { @MainActor in open(nil, searchString) }
    }

    /// The article ids the Help menu lists for a search, in its order, through the same handler
    /// macOS calls: what `--debug-help-search` prints and what the tests read.
    func itemIDs(for search: String, limit: Int = 10) -> [String] {
        let collected = Collected()
        searchForItems(withSearch: search, resultLimit: limit) { items in
            collected.ids += items.compactMap { $0 as? String }
        }
        return collected.ids
    }

    /// The items handed back by `searchForItems`, which answers before it returns.
    private final class Collected: @unchecked Sendable {
        var ids: [String] = []
    }
}
