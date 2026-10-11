import Foundation
import Markdown

/// A run of inline text in an article: its words, how they are styled, and where a link goes.
struct HelpRun: Sendable, Equatable {
    var text: String
    var strong = false
    var emphasis = false
    var code = false
    /// The article a link opens, by id. Show Me links are never runs: they become buttons.
    var articleLink: String?
}

/// A Show Me link: a button under its paragraph that opens a place in the app.
struct HelpShowMe: Sendable, Equatable {
    let title: String
    let place: HelpPlace
}

/// "Tip:", "Note:" and "Important:" paragraphs, drawn with a symbol beside them.
enum HelpCallout: String, Sendable, Equatable, CaseIterable {
    case tip = "Tip:"
    case note = "Note:"
    case important = "Important:"

    /// SF Symbols, each checked to exist on this Mac by the Help test.
    var symbol: String {
        switch self {
        case .tip: "lightbulb"
        case .note: "info.circle"
        case .important: "exclamationmark.triangle"
        }
    }
}

/// One block of an article, as the Help window draws it. Plain values, so an article is parsed once
/// off the main thread and drawn on it, and the swift-markdown tree never crosses an actor.
indirect enum HelpBlock: Sendable, Equatable {
    case heading(level: Int, runs: [HelpRun])
    case paragraph(runs: [HelpRun], callout: HelpCallout?, showMe: [HelpShowMe])
    case list(ordered: Bool, start: Int, items: [[HelpBlock]])
    case code(String)
    case rule

    /// The words a reader sees, for search and for the tests that read visible text.
    var plainText: String {
        switch self {
        case .heading(_, let runs): runs.map(\.text).joined()
        case .paragraph(let runs, _, let showMe): ([runs.map(\.text).joined()] + showMe.map(\.title)).joined(separator: " ")
        case .list(_, _, let items): items.map { $0.map(\.plainText).joined(separator: "\n") }.joined(separator: "\n")
        case .code(let code): code
        case .rule: ""
        }
    }

    /// Every Show Me link in this block and the blocks inside it.
    var showMeLinks: [HelpShowMe] {
        switch self {
        case .paragraph(_, _, let showMe): showMe
        case .list(_, _, let items): items.flatMap { $0.flatMap(\.showMeLinks) }
        default: []
        }
    }
}

/// Turns an article's Markdown (after the capability pass) into blocks, with Apple's swift-markdown
/// (0.9.0, docs/v2/design-spec.md 5.4). The articles use a small CommonMark subset on purpose:
/// headings, paragraphs, numbered and bulleted lists, bold, italics, code and links. A table, an
/// image, HTML or a quote is not drawn, and is named in `problems` so the Help test fails on it.
enum HelpRenderer {
    struct Result: Sendable {
        let blocks: [HelpBlock]
        /// What could not be drawn or resolved, in words. Empty for a good article.
        let problems: [String]
    }

    /// Smart punctuation is off. Reason: it turns "--" into an en dash and "---" into an em dash, which
    /// Ivan's rule forbids in anything Prakriti shows, and it curls quotes and apostrophes that the
    /// rest of the app writes straight (the titles in Help's own sidebar included).
    static let options: ParseOptions = [.disableSmartOpts]

    static func blocks(_ markdown: String, library: HelpLibrary) -> Result {
        var walker = Walker(library: library)
        let document = Document(parsing: markdown, options: options)
        let blocks = document.children.compactMap { walker.block($0) }
        return Result(blocks: blocks, problems: walker.problems)
    }

    /// Every link destination in the Markdown, as written, for the test that each one resolves.
    static func linkDestinations(_ markdown: String) -> [String] {
        var collector = LinkCollector()
        collector.visit(Document(parsing: markdown, options: options))
        return collector.destinations
    }

    private struct LinkCollector: MarkupWalker {
        var destinations: [String] = []
        mutating func visitLink(_ link: Link) {
            destinations.append(link.destination ?? "")
            descendInto(link)
        }
    }

    private struct Walker {
        let library: HelpLibrary
        var problems: [String] = []

        mutating func block(_ markup: Markup) -> HelpBlock? {
            switch markup {
            case let heading as Heading:
                return .heading(level: heading.level, runs: runs(heading.children).runs)
            case let paragraph as Paragraph:
                let (runs, showMe) = runs(paragraph.children)
                var callout: HelpCallout?
                if let first = runs.first, first.strong {
                    callout = HelpCallout.allCases.first { first.text.trimmingCharacters(in: .whitespaces) == $0.rawValue }
                }
                return .paragraph(runs: trimmed(runs), callout: callout, showMe: showMe)
            case let list as OrderedList:
                return .list(ordered: true, start: Int(list.startIndex), items: items(list.children))
            case let list as UnorderedList:
                return .list(ordered: false, start: 1, items: items(list.children))
            case let code as CodeBlock:
                return .code(code.code.trimmingCharacters(in: .newlines))
            case is ThematicBreak:
                return .rule
            default:
                problems.append("\(type(of: markup)) is not drawn in Help: \(markup.format().prefix(60))")
                return nil
            }
        }

        mutating func items(_ children: some Sequence<Markup>) -> [[HelpBlock]] {
            children.compactMap { $0 as? ListItem }.map { item in item.children.compactMap { block($0) } }
        }

        mutating func runs(_ children: some Sequence<Markup>) -> (runs: [HelpRun], showMe: [HelpShowMe]) {
            var out: [HelpRun] = []
            var showMe: [HelpShowMe] = []
            func walk(_ markup: Markup, strong: Bool, emphasis: Bool, link: String?) {
                switch markup {
                case let text as Markdown.Text:
                    out.append(HelpRun(text: text.string, strong: strong, emphasis: emphasis, articleLink: link))
                case let code as InlineCode:
                    out.append(HelpRun(text: code.code, strong: strong, emphasis: emphasis, code: true, articleLink: link))
                case is SoftBreak:
                    out.append(HelpRun(text: " ", strong: strong, emphasis: emphasis, articleLink: link))
                case is LineBreak:
                    out.append(HelpRun(text: "\n", strong: strong, emphasis: emphasis, articleLink: link))
                case let node as Strong:
                    for child in node.children { walk(child, strong: true, emphasis: emphasis, link: link) }
                case let node as Emphasis:
                    for child in node.children { walk(child, strong: strong, emphasis: true, link: link) }
                case let node as Link:
                    let destination = node.destination ?? ""
                    let title = node.plainText
                    switch library.link(destination) {
                    case .article(let id):
                        for child in node.children { walk(child, strong: strong, emphasis: emphasis, link: id) }
                    case .place(let place):
                        showMe.append(HelpShowMe(title: title, place: place))
                    case .unknown:
                        problems.append("The link \"\(title)\" goes nowhere Help knows: \(destination)")
                        for child in node.children { walk(child, strong: strong, emphasis: emphasis, link: nil) }
                    }
                default:
                    problems.append("\(type(of: markup)) is not drawn in Help: \(markup.format().prefix(60))")
                }
            }
            for child in children { walk(child, strong: false, emphasis: false, link: nil) }
            return (out, showMe)
        }

        /// A Show Me link becomes a button under its paragraph, so the space on either side of it is
        /// left behind in the text: two spaces become one, and the paragraph's end is trimmed.
        private func trimmed(_ runs: [HelpRun]) -> [HelpRun] {
            var runs = runs
            for index in runs.indices.dropFirst() where runs[index - 1].text.hasSuffix(" ") {
                runs[index].text = String(runs[index].text.drop { $0 == " " })
            }
            runs.removeAll { $0.text.isEmpty }
            while let last = runs.last, last.text.trimmingCharacters(in: .whitespaces).isEmpty { runs.removeLast() }
            if let last = runs.indices.last {
                runs[last].text = String(runs[last].text.reversed().drop { $0 == " " }.reversed())
            }
            return runs
        }
    }
}
