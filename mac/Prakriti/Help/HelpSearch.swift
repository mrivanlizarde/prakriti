import Foundation

/// Search over the visible Help articles, built once at launch from every article's title, keywords,
/// summary and visible text (about a dozen articles, so no indexer). Ranking follows
/// docs/v2/design-spec.md 5.5: a match in the title counts most, then the keywords, then the summary,
/// then the text. Every word of the search must be found somewhere in an article for it to match.
/// Immutable and Sendable, because the Help menu calls its search off the main thread.
struct HelpSearchIndex: Sendable {
    struct Entry: Sendable {
        let id: String
        let title: String
        let summary: String
        fileprivate let titleWords: [String]
        fileprivate let keywordWords: [String]
        fileprivate let summaryWords: [String]
        fileprivate let textWords: [String]
        /// The article's visible sentences, for the line a result shows.
        fileprivate let sentences: [String]
    }

    /// One article that matches, with the sentence that shows why.
    struct Result: Sendable, Equatable, Identifiable {
        let id: String
        let title: String
        let summary: String
        /// The visible sentence that holds the most searched words, if the text holds one.
        let sentence: String?
        let score: Int
    }

    let entries: [Entry]

    /// Indexes the articles this build shows. Hidden articles, and hidden blocks inside visible
    /// ones, are never searched: a search must not find a feature that does not exist.
    init(library: HelpLibrary) {
        entries = library.visible.map { article in
            // The heading that repeats the title is left out of the text, so a title match counts once.
            let blocks = library.blocks(article).filter {
                if case .heading(1, _) = $0 { return false }
                return true
            }
            let text = blocks.map(\.plainText).joined(separator: "\n")
            return Entry(id: article.id, title: article.title, summary: article.summary,
                         titleWords: Self.words(article.title), keywordWords: Self.words(article.keywords.joined(separator: " ")),
                         summaryWords: Self.words(article.summary), textWords: Self.words(text), sentences: Self.sentences(text))
        }
    }

    func entry(id: String) -> Entry? { entries.first { $0.id == id } }

    /// The articles that match, best first; ties keep the order of the Help sidebar.
    func search(_ query: String, limit: Int = 20) -> [Result] {
        let terms = Self.words(query)
        guard !terms.isEmpty else { return [] }
        var results: [Result] = []
        for entry in entries {
            var score = 0
            var allFound = true
            for term in terms {
                let inTitle = entry.titleWords.contains { $0.hasPrefix(term) }
                let inKeywords = entry.keywordWords.contains { $0.hasPrefix(term) }
                let inSummary = entry.summaryWords.contains { $0.hasPrefix(term) }
                let inText = min(9, entry.textWords.filter { $0.hasPrefix(term) }.count)
                if !inTitle && !inKeywords && !inSummary && inText == 0 { allFound = false; break }
                score += (inTitle ? 1000 : 0) + (inKeywords ? 100 : 0) + (inSummary ? 10 : 0) + inText
            }
            guard allFound else { continue }
            // The sentence that holds the most of the searched words; the first such sentence on a tie.
            var sentence: String?
            var best = 0
            for candidate in entry.sentences {
                let words = Self.words(candidate)
                let held = Set(terms).filter { term in words.contains { $0.hasPrefix(term) } }.count
                if held > best { best = held; sentence = candidate }
            }
            results.append(Result(id: entry.id, title: entry.title, summary: entry.summary, sentence: sentence, score: score))
        }
        // A stable sort: equal scores keep the sidebar's order.
        let ranked = results.enumerated().sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
        return Array(ranked.map(\.element).prefix(max(0, limit)))
    }

    /// Lowercased words without accents ("Prāṇāyāma" finds "pranayama"), split on anything that is
    /// not a letter or a digit.
    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
    }

    static func sentences(_ text: String) -> [String] {
        var found: [String] = []
        for line in text.components(separatedBy: "\n") {
            line.enumerateSubstrings(in: line.startIndex..., options: .bySentences) { sentence, _, _, _ in
                if let sentence = sentence?.trimmingCharacters(in: .whitespaces), !sentence.isEmpty { found.append(sentence) }
            }
        }
        return found
    }
}
