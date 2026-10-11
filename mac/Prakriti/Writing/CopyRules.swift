import Foundation
import NaturalLanguage

// Ivan's copy rules for everything written to be read outside Prakriti: the titles, the one-line
// summary, the show notes, the keywords, the social captions and their pull quotes (11 Oct).
// Describe, never sell. No prices, money or earnings, no enrollment or sign-ups, no offers.
//
// Why Swift reads every line and not only the prompt: on 10 and 11 Oct the drafts for the 13 Sep talk
// said "available to enrolled students", "the decision to pause new student enrollment", "a free
// week" and, in the summary written into the MP3, "pricing for yoga teachers", while enrollment may
// be closed and the talk names a teacher's own income. A prompt is not a guarantee (START_HERE
// warning 51). So a flagged caption, pull quote, title, keyword or one-line summary is left out, a
// flagged sentence of drafted show notes is taken out, and each is counted and said.
//
// The one place money or enrollment may appear is Ivan's own call to action (the Outputs screen),
// which closes the show notes in his words. The model never sees it and Swift never changes it.
// Ivan's own notes and title are his words too, and are never screened.
enum CopyRules {
    /// Each rule: what it catches, in plain words for the notes, and its pattern (case-insensitive,
    /// whole words). Kept narrow on purpose: "the practice offers", "pay attention" and "sales" as a
    /// subject are ordinary in a yoga talk; a false alarm costs one caption, a miss costs trust.
    static let rules: [(name: String, pattern: String)] = [
        ("a price or sum of money", #"[$\x{20AC}\x{00A3}\x{00A5}]|\b\d[\d,.]*\s*(k|grand|dollars?|bucks|usd|euros?|pounds)\b"#),
        ("money or earnings", #"\b(dollars?|bucks|prices?|priced|pricing|fees?|tuition|discounts?|coupons?|promo codes?|refunds?|money|income|incomes|earn|earns|earned|earning|earnings|salary|salaries|revenue|profits?|paycheck|six[- ]figures?|seven[- ]figures?|get paid|getting paid|got paid|costs?)\b"#),
        ("enrollment or signing up", #"\b(enrol|enroll|enrols|enrolls|enrolled|enrolling|enrolment|enrollment|enrollments|sign[- ]?ups?|signing up|register|registered|registering|registration|apply now|join now|join today|spots? (left|available|open)|wait[- ]?list|limited time|book now|buy|buying|purchase|purchasing)\b"#),
        ("an offer", #"\b(free (weeks?|months?|trials?|class|classes|access|sessions?|lessons?|consultations?|calls?)|for free|free of charge|special offer|limited offer|percent off)\b|%\s*off\b"#),
    ]

    private static let compiled: [(name: String, regex: NSRegularExpression)] = rules.compactMap { rule in
        (try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive])).map { (rule.name, $0) }
    }

    /// What breaks the rules in `text`: the kind and the words as found ("enrollment or signing up:
    /// enrolled"), or nil when nothing does.
    static func flag(_ text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for rule in compiled {
            if let match = rule.regex.firstMatch(in: text, range: range), let found = Range(match.range, in: text) {
                return "\(rule.name) (\"\(text[found])\")"
            }
        }
        return nil
    }

    /// The sentences of `text`, as NaturalLanguage reads them (so "8 p.m. Pacific" and "Sri BNS
    /// Iyengar" stay inside their sentence).
    static func sentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { out.append(sentence) }
            return true
        }
        return out
    }

    /// `text` without the sentences that break the rules, paragraph by paragraph (paragraphs are
    /// separated by a blank line and stay so), and what was taken out.
    static func withoutFlaggedSentences(_ text: String) -> (text: String, removed: [String]) {
        var removed: [String] = []
        var out: [String] = []
        for paragraph in paragraphs(text) {
            var kept: [String] = []
            for sentence in sentences(paragraph) {
                if let why = flag(sentence) { removed.append(why) } else { kept.append(sentence) }
            }
            if !kept.isEmpty { out.append(kept.joined(separator: " ")) }
        }
        return (out.joined(separator: "\n\n"), removed)
    }

    /// Paragraphs separated by one or more blank lines, each trimmed, empty ones dropped.
    static func paragraphs(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
