import Foundation

/// A place in the app that a Show Me link opens: `prakriti://show/<place>` in an article. The
/// `prakriti://` scheme is handled inside the Help window only and is never registered with Launch
/// Services, so no other app or web page can drive Prakriti through it (docs/v2/PLAN.md, M2).
enum HelpPlace: Equatable, Hashable, Sendable {
    /// A screen of the main window, by its sidebar name: `prakriti://show/sources`.
    case screen(SidebarItem)

    init?(destination: String) {
        guard let url = URL(string: destination), url.scheme == "prakriti", url.host() == "show" else { return nil }
        let path = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let item = SidebarItem(rawValue: path) else { return nil }
        self = .screen(item)
    }

    /// Every place an article may name today, for the test that every Show Me link resolves.
    static var known: [HelpPlace] { SidebarItem.allCases.map { .screen($0) } }
}

/// Where a link in an article goes.
enum HelpLink: Equatable, Sendable {
    /// Another article, by id: `NN-name.md` (optionally with `#heading`) or `prakriti-help://<id>`.
    case article(String)
    /// A place in the app: drawn as a Show Me button.
    case place(HelpPlace)
    /// Anything else. The Help test fails on one; the window draws its text without a link.
    case unknown(String)
}

/// Every Help article in the app, read once from `Contents/Resources/Help`, and what this build may
/// show of them. Immutable, so the Help menu's search (called off the main thread) can share it.
struct HelpLibrary: Sendable {
    /// Every article file, visible or not, in section and then article order.
    let articles: [HelpArticle]
    /// What this build does: decides which articles and blocks are visible.
    let capabilities: Set<Capability>
    /// Files that could not be read, with the reason. Empty in a good build (the Help test checks).
    let problems: [String]

    init(articles: [HelpArticle], capabilities: Set<Capability>, problems: [String] = []) {
        self.articles = articles.sorted {
            let a = HelpSection.allCases.firstIndex(of: $0.section) ?? 0, b = HelpSection.allCases.firstIndex(of: $1.section) ?? 0
            return a != b ? a < b : ($0.order != $1.order ? $0.order < $1.order : $0.fileName < $1.fileName)
        }
        self.capabilities = capabilities
        self.problems = problems
    }

    /// The articles copied into the app (`Contents/Resources/Help`).
    static func bundled(capabilities: Set<Capability> = Capabilities.built) -> HelpLibrary {
        guard let folder = Bundle.main.url(forResource: "Help", withExtension: nil) else {
            return HelpLibrary(articles: [], capabilities: capabilities, problems: ["The Help folder is not in the app."])
        }
        return load(from: folder, capabilities: capabilities)
    }

    /// Reads every `.md` file in a folder. A file that cannot be read is left out and named in `problems`.
    static func load(from folder: URL, capabilities: Set<Capability>) -> HelpLibrary {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        var articles: [HelpArticle] = []
        var problems: [String] = []
        for name in names {
            do {
                let text = try String(contentsOf: folder.appending(path: name), encoding: .utf8)
                let article = try HelpArticle.parse(fileName: name, text: text)
                // The capability pass runs once here with every capability on, so a broken block
                // (nested, unclosed, a capability that does not exist) is found at load, whatever is built.
                _ = try resolve(article.body, capabilities: Capabilities.all)
                articles.append(article)
            } catch {
                problems.append("\(name): \(error)")
            }
        }
        return HelpLibrary(articles: articles, capabilities: capabilities, problems: problems)
    }

    // MARK: What is visible

    func isVisible(_ article: HelpArticle) -> Bool {
        article.requires.map { capabilities.contains($0) } ?? true
    }

    /// The articles this build shows, in order.
    var visible: [HelpArticle] { articles.filter(isVisible) }

    /// The sidebar: each section that has a visible article, with its articles.
    var sections: [(section: HelpSection, articles: [HelpArticle])] {
        HelpSection.allCases.compactMap { section in
            let inSection = visible.filter { $0.section == section }
            return inSection.isEmpty ? nil : (section, inSection)
        }
    }

    /// Any article, visible or not, by id.
    func article(id: String) -> HelpArticle? { articles.first { $0.id == id } }

    /// A visible article by id. Hidden articles are never opened, from a link or from the Help menu.
    func visibleArticle(id: String) -> HelpArticle? { article(id: id).flatMap { isVisible($0) ? $0 : nil } }

    /// The article Help opens on when nothing else is asked for: the contents page.
    var home: HelpArticle? { visibleArticle(id: "index") ?? visible.first }

    /// The related articles a visible article lists at its end, leaving out hidden ones.
    func related(_ article: HelpArticle) -> [HelpArticle] {
        article.related.compactMap(visibleArticle(id:))
    }

    /// The article's Markdown with each capability block resolved for this build.
    func resolvedBody(_ article: HelpArticle) -> String {
        (try? Self.resolve(article.body, capabilities: capabilities)) ?? ""
    }

    /// The article as blocks the window draws, for this build.
    func blocks(_ article: HelpArticle) -> [HelpBlock] {
        HelpRenderer.blocks(resolvedBody(article), library: self).blocks
    }

    /// Where a link's destination goes.
    func link(_ destination: String) -> HelpLink {
        if destination.hasPrefix("prakriti-help://") {
            let id = String(destination.dropFirst("prakriti-help://".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return article(id: id) != nil ? .article(id) : .unknown(destination)
        }
        if destination.hasPrefix("prakriti:") {
            return HelpPlace(destination: destination).map(HelpLink.place) ?? .unknown(destination)
        }
        let file = destination.split(separator: "#", maxSplits: 1).first.map(String.init) ?? destination
        if file.hasSuffix(".md"), !file.contains("/"), let article = articles.first(where: { $0.fileName == file }) {
            return .article(article.id)
        }
        return .unknown(destination)
    }

    // MARK: The capability pass

    /// Why an article's capability blocks could not be resolved. Each fails the Help test.
    enum BlockError: Error, Equatable, CustomStringConvertible {
        case nested(line: Int)
        case unclosed(line: Int)
        case closedWithoutOpening(line: Int)
        case unknownCapability(String, line: Int)
        case malformed(String, line: Int)

        var description: String {
            switch self {
            case .nested(let line): "line \(line) opens a block inside another; blocks cannot be nested"
            case .unclosed(let line): "the block opened on line \(line) is never closed with :::"
            case .closedWithoutOpening(let line): "line \(line) closes a block that was never opened"
            case .unknownCapability(let name, let line): "line \(line) names \"\(name)\", which is not a capability"
            case .malformed(let text, let line): "line \(line) starts with ::: but is not a block line: \(text)"
            }
        }
    }

    /// Resolves the capability blocks in an article's Markdown, as a text pass before any parsing,
    /// because swift-markdown does not know the `:::` fence (its own directives are `@Name { }`).
    ///
    ///     :::requires video        shown only when `video` is built
    ///     :::unless video          shown only while `video` is not built (what is true until then)
    ///     :::                      ends the block
    ///
    /// The fence lines themselves are always removed, so a block can sit between two items of a list.
    /// Blocks cannot be nested, and an unclosed block, a stray `:::` or an unknown capability is an
    /// error, never guessed at. Reason: a mistake here would show Ivan a feature that does not exist,
    /// or hide one that does.
    static func resolve(_ text: String, capabilities: Set<Capability>) throws -> String {
        var kept: [String] = []
        var open: (shown: Bool, line: Int)?
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let number = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(":::") else {
                if open?.shown ?? true { kept.append(line) }
                continue
            }
            let words = trimmed.dropFirst(3).split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if words.isEmpty {
                guard open != nil else { throw BlockError.closedWithoutOpening(line: number) }
                open = nil
                continue
            }
            guard words.count == 2, words[0] == "requires" || words[0] == "unless" else {
                throw BlockError.malformed(trimmed, line: number)
            }
            guard open == nil else { throw BlockError.nested(line: number) }
            guard let capability = Capability(rawValue: words[1]) else { throw BlockError.unknownCapability(words[1], line: number) }
            let built = capabilities.contains(capability)
            open = (words[0] == "requires" ? built : !built, number)
        }
        if let open { throw BlockError.unclosed(line: open.line) }
        return kept.joined(separator: "\n")
    }
}
