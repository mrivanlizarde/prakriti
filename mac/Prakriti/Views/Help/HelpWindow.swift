import AppKit
import SwiftUI

/// Prakriti Help (Help menu, Command-?): the sections and their articles in a sidebar, the article
/// beside it, Back and Forward, and a search field that searches as you type
/// (docs/v2/design-spec.md 5.2). Shows only the articles, and the parts of articles, that describe
/// what this build does (`Capabilities.built`).
struct HelpWindow: View {
    static let id = "help"
    static let size = CGSize(width: 960, height: 720)
    static let minimumSize = CGSize(width: 760, height: 520)

    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var help = model.help
        NavigationSplitView {
            HelpSidebar(selection: $help.selection, library: help.library)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .searchable(text: $help.searchText, placement: .toolbar, prompt: "Search Help")
        .navigationTitle(help.isSearching ? "Search Help" : (help.article?.title ?? "Prakriti Help"))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { help.goBack() } label: { Label("Back", systemImage: "chevron.backward") }
                    .disabled(!help.canGoBack)
                    .keyboardShortcut("[", modifiers: .command)
                Button { help.goForward() } label: { Label("Forward", systemImage: "chevron.forward") }
                    .disabled(!help.canGoForward)
                    .keyboardShortcut("]", modifiers: .command)
            }
        }
        // Links inside an article open other articles here. Nothing in Help opens a web page, and the
        // prakriti:// places are buttons (HelpBlockView), so no link leaves this window.
        .environment(\.openURL, OpenURLAction { url in
            help.follow(url) ? .handled : .discarded
        })
        .onAppear {
            model.openHelpWindow = { openWindow(id: HelpWindow.id) }
        }
    }

    @ViewBuilder
    private var detail: some View {
        let help = model.help
        if help.isSearching {
            HelpSearchResults(query: help.searchText, results: help.results) { id in help.open(id) }
        } else if let article = help.article {
            HelpArticleView(article: article, blocks: help.library.blocks(article), related: help.library.related(article),
                            onShowMe: { place in
                                HelpActions.show(place, model: model, openMainWindow: { openWindow(id: MainWindow.id) })
                            },
                            onOpenArticle: { id in help.open(id) })
        } else {
            EmptyState(symbol: "questionmark.circle", title: "Choose an article",
                       message: "Every article is listed on the left, by section.")
        }
    }
}

/// The sections and their articles. Section names at 15 pt semibold, article titles at 17 pt.
struct HelpSidebar: View {
    @Binding var selection: String?
    let library: HelpLibrary

    var body: some View {
        List(selection: $selection) {
            ForEach(library.sections, id: \.section) { group in
                Section {
                    ForEach(group.articles) { article in
                        Text(article.title)
                            .font(AppFont.body)
                            .padding(.vertical, 3)
                            .tag(article.id)
                    }
                } header: {
                    Text(group.section.title(with: library.capabilities))
                        .font(AppFont.secondaryEmphasis)
                        .foregroundStyle(.appSecondary)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

/// What a search found: each article's title, its summary, and the sentence that holds the words.
struct HelpSearchResults: View {
    let query: String
    let results: [HelpSearchIndex.Result]
    let onOpen: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(results.isEmpty ? "No article matches" : results.count == 1 ? "1 article matches" : "\(results.count) articles match")
                    .font(AppFont.pageTitle)
                if results.isEmpty {
                    Text("Try a shorter word, or look through the sections on the left.")
                        .font(AppFont.body)
                        .foregroundStyle(.appSecondary)
                }
                ForEach(results) { result in
                    Button {
                        onOpen(result.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(AppFont.headline)
                                .foregroundStyle(HelpColors.link)
                            Text(result.summary)
                                .font(AppFont.body)
                                .foregroundStyle(.primary)
                            if let sentence = result.sentence {
                                Text(sentence)
                                    .font(AppFont.secondary)
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the article")
                }
            }
            .frame(maxWidth: HelpArticleView.maxWidth, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }
}
