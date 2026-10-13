import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Prakriti Help (v2 part M2a, docs/v2/PLAN.md M2): the articles, the capability blocks, the links,
/// search, the Help menu's handler and Show Me. The articles are read from the app's own bundle (what
/// Ivan sees) and, for the copy rules, from `mac/Prakriti/Resources/Help` itself (every byte, hidden
/// blocks included).
@MainActor
final class HelpTests: XCTestCase {
    /// The eleven articles, named one by one: `welcome-panels.md` is not an article and must never be
    /// copied into the app (docs/v2/PLAN.md section 10.1, item 7).
    static let articleFiles = ["00-index.md", "01-welcome.md", "02-capture-the-best-video.md", "03-set-up-obs-for-prakriti.md",
                               "04-sources-and-watching.md", "05-outputs.md", "06-reviewing-and-approving.md",
                               "07-people-and-privacy.md", "08-editorial-direction.md", "09-models-and-api-keys.md",
                               "10-troubleshooting.md"]

    private var built: HelpLibrary { HelpLibrary.bundled(capabilities: Capabilities.built) }
    private var everything: HelpLibrary { HelpLibrary.bundled(capabilities: Capabilities.all) }

    private var sourceFolder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Prakriti/Resources/Help", directoryHint: .isDirectory)
    }

    // MARK: Check 1: every article parses, ids unique, links and related resolve, copy rules, symbols

    func testTheAppHoldsExactlyTheElevenArticles() throws {
        let bundled = try XCTUnwrap(Bundle.main.url(forResource: "Help", withExtension: nil), "the Help folder is in the app")
        let inApp = try FileManager.default.contentsOfDirectory(atPath: bundled.path).sorted()
        XCTAssertEqual(inApp, Self.articleFiles, "Contents/Resources/Help holds the eleven articles and nothing else")
        let inSource = try FileManager.default.contentsOfDirectory(atPath: sourceFolder.path).filter { !$0.hasPrefix(".") }.sorted()
        XCTAssertEqual(inSource, Self.articleFiles)
    }

    func testEveryArticleParses() throws {
        let library = built
        XCTAssertEqual(library.problems, [], "every article reads, front matter and capability blocks")
        XCTAssertEqual(library.articles.map(\.fileName).sorted(), Self.articleFiles)
        XCTAssertEqual(Set(library.articles.map(\.id)).count, library.articles.count, "ids are unique")
        for article in library.articles {
            XCTAssertFalse(article.title.isEmpty, article.fileName)
            XCTAssertFalse(article.summary.isEmpty, article.fileName)
            XCTAssertFalse(article.keywords.isEmpty, article.fileName)
            // The first line of the body is the title as a heading, the same words as the front matter.
            let firstLine = article.body.split(separator: "\n").first.map(String.init) ?? ""
            XCTAssertEqual(firstLine, "# " + article.title, "\(article.fileName): the heading must match the title")
        }
        XCTAssertEqual(library.home?.id, "index", "Help opens on its contents page")
    }

    func testFrontMatterIsReadStrictly() {
        let good = "---\nid: a-b\ntitle: T\nsummary: S, with a comma: and a colon\nsection: recording\norder: 2\nkeywords: [x, y z]\nrelated: []\n---\n\n# T\n"
        let article = try? HelpArticle.parse(fileName: "01-a.md", text: good)
        XCTAssertEqual(article?.summary, "S, with a comma: and a colon")
        XCTAssertEqual(article?.keywords, ["x", "y z"])
        XCTAssertEqual(article?.related, [])
        XCTAssertNil(article?.requires)
        XCTAssertThrowsError(try HelpArticle.parse(fileName: "x.md", text: good.replacingOccurrences(of: "section: recording\n", with: "")))
        XCTAssertThrowsError(try HelpArticle.parse(fileName: "x.md", text: good.replacingOccurrences(of: "recording", with: "nowhere")))
        XCTAssertThrowsError(try HelpArticle.parse(fileName: "x.md", text: good.replacingOccurrences(of: "order: 2", with: "order: two")))
        XCTAssertThrowsError(try HelpArticle.parse(fileName: "x.md", text: good.replacingOccurrences(of: "related: []\n", with: "related: []\nrequires: wings\n")))
        XCTAssertThrowsError(try HelpArticle.parse(fileName: "x.md", text: "# No front matter\n"))
    }

    func testEveryArticleDrawsWithOnlyTheBlocksHelpDraws() {
        for library in [built, everything] {
            for article in library.visible {
                let result = HelpRenderer.blocks(library.resolvedBody(article), library: library)
                XCTAssertEqual(result.problems, [], "\(article.fileName) with \(library.capabilities.count) capabilities")
                XCTAssertFalse(result.blocks.isEmpty, article.fileName)
            }
        }
    }

    func testEveryRelatedIdAndEveryLinkResolves() {
        let library = everything
        for article in library.articles {
            for id in article.related {
                XCTAssertNotNil(library.article(id: id), "\(article.fileName) lists a related article that does not exist: \(id)")
                XCTAssertNotEqual(id, article.id, "\(article.fileName) lists itself as related")
            }
            // With every capability on, so the links inside hidden blocks are checked too.
            for destination in HelpRenderer.linkDestinations(library.resolvedBody(article)) {
                switch library.link(destination) {
                case .article(let id):
                    XCTAssertNotNil(library.article(id: id))
                case .place(let place):
                    XCTAssertTrue(HelpPlace.known.contains(place), "\(article.fileName): \(destination)")
                case .unknown:
                    XCTFail("\(article.fileName) links to something Help does not know: \(destination)")
                }
            }
        }
        XCTAssertEqual(library.link("05-outputs.md"), .article("outputs"))
        XCTAssertEqual(library.link("05-outputs.md#transcript"), .article("outputs"))
        XCTAssertEqual(library.link("prakriti-help://troubleshooting"), .article("troubleshooting"))
        XCTAssertEqual(library.link("prakriti://show/sources"), .place(.sources))
        XCTAssertEqual(library.link("prakriti://show/group/needs-you"), .place(.group(.needsYou)))
        XCTAssertEqual(library.link("prakriti://show/settings/models"), .place(.settings(.models)))
        XCTAssertEqual(library.link("prakriti://show/activity"), .place(.activity))
        XCTAssertEqual(library.link("prakriti://show/settings/nowhere"), .unknown("prakriti://show/settings/nowhere"))
        // Every known place writes a link that reads back as itself.
        for place in HelpPlace.known { XCTAssertEqual(library.link(place.destination), .place(place)) }
        XCTAssertEqual(library.link("prakriti://show/nowhere"), .unknown("prakriti://show/nowhere"))
        XCTAssertEqual(library.link("https://example.com"), .unknown("https://example.com"))
        XCTAssertEqual(library.link("../welcome-panels.md"), .unknown("../welcome-panels.md"))
    }

    /// A link that a reader can see never opens an article this build hides.
    func testNoVisibleLinkGoesToAHiddenArticle() {
        let library = built
        for article in library.visible {
            for destination in HelpRenderer.linkDestinations(library.resolvedBody(article)) {
                if case .article(let id) = library.link(destination) {
                    XCTAssertNotNil(library.visibleArticle(id: id), "\(article.fileName) shows a link to the hidden article \(id)")
                }
            }
            XCTAssertTrue(library.related(article).allSatisfy(library.isVisible))
        }
    }

    func testCopyRulesInEveryHelpFile() throws {
        for name in Self.articleFiles {
            let text = try String(contentsOf: sourceFolder.appending(path: name), encoding: .utf8)
            XCTAssertFalse(text.contains("builder-notes"), "\(name): builder notes belong in docs/v2/help-notes")
            XCTAssertFalse(text.lowercased().contains("builder notes"), "\(name): builder notes belong in docs/v2/help-notes")
            for (number, line) in text.components(separatedBy: "\n").enumerated() {
                let at = "\(name) line \(number + 1)"
                XCTAssertFalse(line.contains("\u{2014}"), "em dash in \(at)")
                XCTAssertFalse(line.contains("\u{2013}"), "en dash in \(at)")
                XCTAssertFalse(line.contains("<"), "HTML in \(at)")
                let words = Set(line.lowercased().split { !($0.isLetter || $0.isNumber || $0 == "'") }.map(String.init))
                XCTAssertFalse(words.contains("we") || words.contains("we're") || words.contains("we've") || words.contains("our"), "\"we\" in \(at)")
                XCTAssertFalse(words.contains("processing"), "\"Processing\" in \(at)")
                XCTAssertFalse(words.contains("tap") || words.contains("taps") || words.contains("tapping"), "\"tap\" in \(at): on a Mac you click")
            }
        }
    }

    /// swift-markdown's smart punctuation curled quotes as it parsed (measured on the first snapshots),
    /// and the same pass turns "--" into an en dash and "---" into an em dash. It is off, and the text a
    /// reader sees has no dash, even from a "--" written in an article.
    func testNoDashReachesTheVisibleText() {
        for library in [built, everything] {
            for (place, text) in visibleText(library) {
                XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "a dash in \(place)")
            }
        }
        let library = HelpLibrary(articles: [], capabilities: [.help])
        let drawn = HelpRenderer.blocks("Two -- and three --- and \"quotes\" and it's.", library: library).blocks.map(\.plainText).joined()
        XCTAssertEqual(drawn, "Two -- and three --- and \"quotes\" and it's.")
    }

    func testEverySymbolHelpUsesExists() {
        let symbols = HelpCallout.allCases.map(\.symbol) + [HelpBlockView.showMeSymbol, "chevron.backward", "chevron.forward", "questionmark.circle"]
        for symbol in symbols {
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "SF Symbol \(symbol) does not exist on this Mac")
        }
        // No article names a symbol yet; if one ever does, as `symbol:name`, it must exist too.
        for article in everything.articles {
            for match in article.body.matches(of: /symbol:([a-z0-9.]+)/) {
                XCTAssertNotNil(NSImage(systemSymbolName: String(match.1), accessibilityDescription: nil), "\(article.fileName): \(match.1)")
            }
        }
    }

    // MARK: The capability pass

    func testCapabilityBlocksAreResolvedBeforeParsing() throws {
        let text = "Before.\n\n- One\n:::requires video\n- Two, with video\n:::\n:::unless video\n- Two, until video\n:::\n- Three\n\nAfter."
        XCTAssertEqual(try HelpLibrary.resolve(text, capabilities: [.help]),
                       "Before.\n\n- One\n- Two, until video\n- Three\n\nAfter.")
        XCTAssertEqual(try HelpLibrary.resolve(text, capabilities: [.help, .video]),
                       "Before.\n\n- One\n- Two, with video\n- Three\n\nAfter.")
        // The fence lines go, so the list stays one list either way.
        let library = HelpLibrary(articles: [], capabilities: [.help])
        let blocks = HelpRenderer.blocks(try HelpLibrary.resolve(text, capabilities: [.help]), library: library).blocks
        guard case .list(false, _, let items) = blocks[1] else { return XCTFail("one list: \(blocks)") }
        XCTAssertEqual(items.count, 3)
        // Indented fences (inside a list item) work the same way.
        XCTAssertEqual(try HelpLibrary.resolve("- A\n  :::requires people\n  more\n  :::", capabilities: []), "- A")
    }

    func testBrokenCapabilityBlocksAreRefused() {
        XCTAssertThrowsError(try HelpLibrary.resolve(":::requires video\n:::requires people\nx\n:::\n:::", capabilities: [])) {
            XCTAssertEqual($0 as? HelpLibrary.BlockError, .nested(line: 2))
        }
        XCTAssertThrowsError(try HelpLibrary.resolve("a\n:::requires video\nnever closed", capabilities: [])) {
            XCTAssertEqual($0 as? HelpLibrary.BlockError, .unclosed(line: 2))
        }
        XCTAssertThrowsError(try HelpLibrary.resolve("a\n:::\n", capabilities: [])) {
            XCTAssertEqual($0 as? HelpLibrary.BlockError, .closedWithoutOpening(line: 2))
        }
        XCTAssertThrowsError(try HelpLibrary.resolve(":::requires wings\nx\n:::", capabilities: [])) {
            XCTAssertEqual($0 as? HelpLibrary.BlockError, .unknownCapability("wings", line: 1))
        }
        XCTAssertThrowsError(try HelpLibrary.resolve(":::require video\nx\n:::", capabilities: [])) {
            XCTAssertEqual($0 as? HelpLibrary.BlockError, .malformed(":::require video", line: 1))
        }
        // An article with a broken block is left out of the library and named, never shown half-resolved.
        let folder = FileManager.default.temporaryDirectory.appending(path: "prakriti-help-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let front = "---\nid: a\ntitle: A\nsummary: S\nsection: recording\norder: 1\nkeywords: [k]\nrelated: []\n---\n# A\n"
        try? (front + ":::requires video\nunclosed\n").write(to: folder.appending(path: "01-a.md"), atomically: true, encoding: .utf8)
        let library = HelpLibrary.load(from: folder, capabilities: [.help, .video])
        XCTAssertTrue(library.articles.isEmpty)
        XCTAssertEqual(library.problems.count, 1)
    }

    // MARK: Check 2: with only Help built, nothing unbuilt is visible

    /// Feature names each part introduces, by the capability that builds them. With that capability
    /// off, none may appear in the visible text of any article (titles, summaries, section names,
    /// headings, text, links and Related). Each later part extends this list with its own names.
    static let unbuiltNames: [(phrase: String, caseSensitive: Bool, capability: Capability)] = [
        ("Welcome to Prakriti", true, .welcome),
        ("viewer", false, .viewer),
        ("time left", false, .progress), ("Activity window", false, .progress), ("Command-9", false, .progress),
        ("percent", false, .progress),
        ("capture check", false, .captureCheck), ("Hybrid MOV", false, .captureCheck),
        ("OpenAI", false, .cloudProviders),
        // The People tab and its Unnamed rows arrive with faces (v2 part M6a); the choices with M6c.
        ("People", true, .faces), ("Unnamed", true, .faces), ("Other People Appear", true, .faces),
        // Voices and names arrive with M6b.
        ("Who is teaching", false, .voices), ("Name for This Recording", false, .voices), ("Check People", false, .voices),
        ("People You Name", false, .voices), ("microphone track", false, .voices),
        // Choices applied to audio arrive with M6c; hiding faces in pictures with M6d.
        ("Leave Out", true, .choices), ("Hide Face", true, .choices), ("Set All Unnamed To", false, .choices),
        ("Keep or Mute", false, .choices), ("Mute", true, .choices),
        ("Blur Face", false, .people), ("blurred", false, .people), ("faces hidden", false, .people),
        ("face print", false, .people), ("voice print", false, .people),
        ("People gallery", false, .gallery), ("gallery of", false, .gallery), ("Name This Person", false, .gallery),
        ("Forget This Person", false, .gallery),
        ("edited video", false, .video), ("Ready to post", false, .video), ("Make Video", false, .video),
        ("house style", false, .style), ("preset", false, .style), ("presets", false, .style), ("Direction", true, .style),
        ("zooms", false, .style),
        ("Final Cut Pro", false, .timelines), ("DaVinci", false, .timelines), ("FCPXML", false, .timelines),
        ("timeline", false, .timelines),
        ("shorts", false, .shorts), ("vertical short", false, .shorts),
        ("thumbnail", false, .thumbnails), ("thumbnails", false, .thumbnails),
        ("Moments From Other Recordings", false, .merge), ("supporting moment", false, .merge),
    ]

    /// Every word a reader of this library can see.
    private func visibleText(_ library: HelpLibrary) -> [(where: String, text: String)] {
        var out: [(String, String)] = library.sections.map { ("section \($0.section.rawValue)", $0.section.title(with: library.capabilities)) }
        for article in library.visible {
            out.append(("\(article.fileName) title", article.title))
            out.append(("\(article.fileName) summary", article.summary))
            out.append((article.fileName, library.blocks(article).map(\.plainText).joined(separator: "\n")))
            out.append(("\(article.fileName) related", library.related(article).map(\.title).joined(separator: "\n")))
        }
        return out
    }

    private func unbuiltNamesFound(in library: HelpLibrary, built: Set<Capability>) -> [String] {
        var found: [String] = []
        for (place, text) in visibleText(library) {
            for name in Self.unbuiltNames where !built.contains(name.capability) {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: name.phrase) + "\\b"
                let options: NSRegularExpression.Options = name.caseSensitive ? [] : [.caseInsensitive]
                guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { continue }
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range, in: text) {
                    let line = text[..<range.lowerBound].split(separator: "\n").last.map(String.init) ?? ""
                    found.append("\(place): \"\(name.phrase)\" (\(name.capability.rawValue)) in \"\(line)\(text[range])...\"")
                }
            }
        }
        return found
    }

    func testOnlyWhatIsBuiltIsVisible() {
        XCTAssertEqual(Capabilities.built, [.help, .welcome, .viewer, .progress, .captureCheck, .cloudProviders, .faces, .voices, .choices], "v2 parts M2a, M2b, M3b, M4a, M4b, M5b, M6a, M6b and M6c build Help, the welcome, the Viewer, progress, the capture check, the cloud providers, faces, voices and choices applied to audio; each later part adds its own capability")
        let library = built
        XCTAssertEqual(unbuiltNamesFound(in: library, built: library.capabilities), [])
        XCTAssertNil(library.visibleArticle(id: "editorial-direction"), "editorial direction waits for the house style (M9)")

        // The check finds what it is meant to find: the same articles with every block shown name
        // features that are not built, and it must say so.
        let all = everything
        XCTAssertFalse(unbuiltNamesFound(in: all, built: Capabilities.built).isEmpty, "the check would have caught an unbuilt feature")
    }

    func testWithEveryCapabilityEveryArticleIsVisible() {
        let library = everything
        XCTAssertEqual(library.visible.count, library.articles.count)
        XCTAssertEqual(library.visible.count, 11)
        XCTAssertEqual(library.sections.count, HelpSection.allCases.count, "every section has an article once everything is built")
    }

    // MARK: Search and the Help menu

    func testSearchRanksTitleThenKeywordsThenSummaryThenText() {
        let index = HelpSearchIndex(library: built)
        XCTAssertEqual(index.search("OBS").first?.id, "set-up-obs-for-prakriti")
        XCTAssertEqual(index.search("notifications").first?.id, "troubleshooting")
        XCTAssertEqual(index.search("privacy").first?.id, "people-and-privacy")
        XCTAssertEqual(index.search("Approve").first?.id, "reviewing-and-approving")
        XCTAssertEqual(index.search("  ").count, 0)
        XCTAssertEqual(index.search("zqxj").count, 0)
        // Every word must be found in an article; a word that is nowhere finds nothing.
        XCTAssertEqual(index.search("OBS zqxj").count, 0)
        // Accents and case do not matter.
        XCTAssertEqual(index.search("obs").first?.id, "set-up-obs-for-prakriti")
        // A result shows the sentence that holds the word.
        let result = index.search("Keep Downloaded").first { $0.id == "sources-and-watching" }
        XCTAssertNotNil(result?.sentence)
        XCTAssertTrue(result?.sentence?.contains("Keep Downloaded") ?? false, result?.sentence ?? "no sentence")
        // Hidden articles are never searched.
        XCTAssertFalse(index.search("Calm").contains { $0.id == "editorial-direction" })
        XCTAssertTrue(HelpSearchIndex(library: everything).search("Calm").contains { $0.id == "editorial-direction" })
    }

    func testTheHelpMenuHandlerListsAndOpensArticles() async {
        let model = Fixtures.model()
        let handler = try? XCTUnwrap(model.helpMenuSearch)
        XCTAssertEqual(handler?.itemIDs(for: "OBS").first, "set-up-obs-for-prakriti")
        XCTAssertEqual(handler?.itemIDs(for: "notifications").first, "troubleshooting")
        XCTAssertEqual(handler?.itemIDs(for: "privacy").first, "people-and-privacy")
        XCTAssertEqual(handler?.itemIDs(for: "OBS", limit: 1).count, 1, "the Help menu's limit is kept")
        XCTAssertEqual(handler?.localizedTitles(forItem: "troubleshooting" as NSString), ["If something isn't working"])
        XCTAssertEqual(handler?.localizedTitles(forItem: "editorial-direction"), [], "a hidden article has no title to list")

        var opened = 0
        model.openHelpWindow = { opened += 1 }
        handler?.performAction(forItem: "troubleshooting")
        await Task.yield()
        for _ in 0..<20 where model.help.selection != "troubleshooting" { await Task.yield() }
        XCTAssertEqual(model.help.selection, "troubleshooting")
        XCTAssertEqual(opened, 1, "choosing a result opens the Help window")

        handler?.showAllHelpTopics(forSearch: "OBS")
        for _ in 0..<20 where model.help.searchText != "OBS" { await Task.yield() }
        XCTAssertEqual(model.help.searchText, "OBS")
        XCTAssertTrue(model.help.isSearching)
        XCTAssertEqual(opened, 2)
    }

    // MARK: Check 4: Show Me

    /// "Sources and watching" carries a Show Me link at its top (in the first screenful the snapshot
    /// shows), and the button opens the Sources screen in the main window.
    func testShowMeInSourcesAndWatchingOpensSources() throws {
        let model = Fixtures.model()
        model.selection = .default
        let library = model.help.library
        let article = try XCTUnwrap(library.visibleArticle(id: "sources-and-watching"))
        let blocks = library.blocks(article)
        let first = try XCTUnwrap(blocks.prefix(4).flatMap(\.showMeLinks).first, "a Show Me link near the top of the article")
        XCTAssertEqual(first, HelpShowMe(title: "Show Me", place: .sources))

        var mainWindowOpened = false
        HelpActions.show(first.place, model: model, openMainWindow: { mainWindowOpened = true })
        XCTAssertTrue(mainWindowOpened, "Show Me opens the main window")
        let firstFolder = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.addedAt)])).first)
        XCTAssertEqual(model.selection, .source(firstFolder.id), "and selects the first folder under Sources, its settings in the inspector")
        XCTAssertEqual(model.selectedSource?.name, "Studio Recordings")
    }

    /// A Show Me link in the middle of a paragraph leaves one space between the sentences around it.
    func testAShowMeLinkLeavesNoDoubleSpace() {
        let library = HelpLibrary(articles: [], capabilities: [.help])
        let blocks = HelpRenderer.blocks("Click Activity. [Show Me](prakriti://show/activity) It writes a line. [Show Me](prakriti://show/sources)",
                                         library: library).blocks
        guard case .paragraph(let runs, _, let showMe) = blocks.first else { return XCTFail("\(blocks)") }
        XCTAssertEqual(runs.map(\.text).joined(), "Click Activity. It writes a line.")
        XCTAssertEqual(showMe.map(\.place), [.activity, .sources])
        for article in built.visible {
            XCTAssertFalse(built.blocks(article).map(\.plainText).joined(separator: "\n").contains("  "), "a double space in \(article.fileName)")
        }
    }

    func testEveryShowMeLinkIsAButtonNeverText() {
        let library = everything
        for article in library.articles {
            for block in library.blocks(article) {
                for link in block.showMeLinks {
                    XCTAssertEqual(link.title, "Show Me", "\(article.fileName): a place link reads Show Me")
                }
                if case .paragraph(let runs, _, _) = block {
                    XCTAssertFalse(runs.contains { $0.articleLink?.hasPrefix("prakriti:") ?? false })
                }
            }
        }
    }

    // MARK: The window's model

    func testBackForwardAndLinksStayInsideHelp() throws {
        let model = Fixtures.model()
        let help = model.help
        XCTAssertTrue(help.open("welcome"))
        XCTAssertTrue(help.follow(try XCTUnwrap(URL(string: "prakriti-help://outputs"))))
        XCTAssertEqual(help.selection, "outputs")
        XCTAssertTrue(help.canGoBack)
        help.goBack()
        XCTAssertEqual(help.selection, "welcome")
        XCTAssertTrue(help.canGoForward)
        help.goForward()
        XCTAssertEqual(help.selection, "outputs")
        XCTAssertFalse(help.canGoForward)

        // Nothing else is followed: no web page, no place (places are buttons), no hidden article.
        XCTAssertFalse(help.follow(try XCTUnwrap(URL(string: "https://example.com"))))
        XCTAssertFalse(help.follow(try XCTUnwrap(URL(string: "prakriti://show/sources"))))
        XCTAssertFalse(help.follow(try XCTUnwrap(URL(string: "prakriti-help://editorial-direction"))))
        XCTAssertFalse(help.open("editorial-direction"))
        XCTAssertEqual(help.selection, "outputs")

        // Choosing an article ends a search.
        help.searchText = "OBS"
        XCTAssertTrue(help.isSearching)
        help.open("troubleshooting")
        XCTAssertFalse(help.isSearching)
        XCTAssertEqual(model.settings.helpLastArticle, "troubleshooting", "Help reopens where it was left")
    }

    /// Help, Show Log in Finder: today's log selected, or the log folder when nothing is written yet today.
    func testShowLogInFinderShowsTodaysLog() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "prakriti-log-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = Fixtures.model(mode: .development, log: AppLog(directory: folder))
        XCTAssertEqual(model.logToShow.url.standardizedFileURL.path, folder.standardizedFileURL.path)
        XCTAssertFalse(model.logToShow.selects, "nothing written yet today: the folder")
        model.log.write("A line.")
        let today = try XCTUnwrap(model.log.todayFile)
        XCTAssertEqual(model.logToShow.url, today)
        XCTAssertTrue(model.logToShow.selects, "today's log, selected in the Finder")
        // Without a log file (tests, snapshots): this mode's log folder.
        XCTAssertEqual(Fixtures.model(mode: .live).logToShow.url, AppPaths(mode: .live).logs)
    }

    /// The `prakriti://` and `prakriti-help://` schemes are handled inside the Help window only: the app
    /// registers no URL scheme with macOS, so no other app or web page can drive Prakriti through them.
    func testNoURLSchemeIsRegistered() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes"), "Prakriti registers no URL scheme")
    }

    /// The debug switches are compiled into Debug builds, and `make install` installs a Debug build, so
    /// they check where the app runs from: the installed copy never reads them.
    func testDebugSwitchesAreNeverReadByTheInstalledCopy() {
        XCTAssertFalse(DebugSwitches.isAllowed(bundle: DebugSwitches.installedApp))
        XCTAssertTrue(DebugSwitches.isAllowed(bundle: URL(fileURLWithPath: "/Users/someone/Code/prakriti/mac/build/Build/Products/Debug/Prakriti.app")))
        XCTAssertTrue(DebugSwitches.isAllowed(), "the test host runs from the build folder")
    }
}
