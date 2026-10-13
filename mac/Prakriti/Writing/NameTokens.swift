import Foundation
import NaturalLanguage

// Names in text that goes to a cloud model (v2 part M5a, docs/v2/PLAN.md M5, warning 19).
//
// Before any text leaves the Mac, every person's name Apple's tagger finds (NLTagger, `.nameType`,
// `personalName`) is replaced by a token such as [[NAME-1]], except the names of named people who agreed
// to cloud models; a name Ivan marked Mute is always replaced, even when the tagger misses it that time.
// The answer comes back with the tokens and each is put back exactly as it was written, so a quote still
// matches the transcript word for word.
//
// The tagger is not perfect (its recall on the 13 Sep talk is measured in BUILD-LOG, "v2 part M5a"), so
// this is one of three locks, never the only one: the privacy lock keeps every recording with other people
// on this Mac whatever the tagger finds, and PrivacyLock re-reads the text after the tokens are in.

/// The names replaced in one request, and how to put them back.
struct NameTokens: Sendable, Equatable {
    /// Each name exactly as it was written, in the order it was first replaced. Token `i` stands for
    /// `names[i]`.
    private(set) var names: [String] = []

    var count: Int { names.count }

    static func token(_ index: Int) -> String { "[[NAME-\(index + 1)]]" }

    /// A token in text, for the check that runs after tokenizing and for restoring.
    static let tokenPattern = #"\[\[NAME-([0-9]+)\]\]"#

    /// The token for a name as written, made on first use.
    mutating func token(for surface: String) -> String {
        if let index = names.firstIndex(of: surface) { return Self.token(index) }
        names.append(surface)
        return Self.token(names.count - 1)
    }

    /// The answer with every token put back as the name was written. A token the request never had is
    /// left as it is (the model made it up); it names no one.
    func restore(_ text: String) -> String {
        guard !names.isEmpty, let regex = try? NSRegularExpression(pattern: Self.tokenPattern) else { return text }
        let source = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: last, length: match.range.location - last))
            let number = Int(source.substring(with: match.range(at: 1))) ?? 0
            result += (1...names.count).contains(number) ? names[number - 1] : source.substring(with: match.range)
            last = match.range.location + match.range.length
        }
        result += source.substring(from: last)
        return result
    }

    // MARK: Finding names

    /// Every person's name the tagger finds in `text`, as written, each once, in the order found.
    /// Joined names ("Gabriel Galindo") come back whole. Tokens already in the text are never names.
    static func findNames(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
            if tag == .personalName {
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !name.isEmpty, !name.contains("NAME-"), !found.contains(name) { found.append(name) }
            }
            return true
        }
        return found
    }

    /// Whether `name` belongs to someone who may be read by a cloud model: the whole name, or every word
    /// of it, is one of their names or a word of one ("Gabriel" for "Gabriel Galindo"). Case is ignored.
    static func isKept(_ name: String, keep: [String]) -> Bool {
        let keptWords = Set(keep.flatMap(words).map { $0.lowercased() })
        let keptWhole = Set(keep.map { $0.lowercased() })
        if keptWhole.contains(name.lowercased()) { return true }
        let parts = words(name).map { $0.lowercased() }
        return !parts.isEmpty && parts.allSatisfy(keptWords.contains)
    }

    static func words(_ name: String) -> [String] {
        name.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    // MARK: Tokenizing

    /// Replaces names in every text with tokens shared across them (the same name, the same token).
    ///
    /// - `keep`: the names of named people who agreed to cloud models; left as they are.
    /// - `always`: names Ivan marked Mute; replaced whatever the tagger finds.
    ///
    /// The tagger reads each text again after its names are replaced, because the words around a token
    /// can change what it finds; up to three rounds. A name of several words also has each of its
    /// words of three letters or more replaced where it stands alone ("Galindo" after "Gabriel Galindo").
    static func tokenize(_ texts: [String], keep: [String], always: [String]) -> (texts: [String], tokens: NameTokens) {
        var tokens = NameTokens()
        var out = texts
        var targets: [String] = []
        func add(_ name: String) {
            guard !targets.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
            targets.append(name)
        }
        for name in always where !name.trimmingCharacters(in: .whitespaces).isEmpty {
            add(name.trimmingCharacters(in: .whitespaces))
        }
        for round in 0..<3 {
            var grew = round == 0 && !targets.isEmpty
            for text in out {
                for name in findNames(in: text) where !isKept(name, keep: keep) {
                    let before = targets.count
                    add(name)
                    for word in words(name) where words(name).count > 1 && word.count >= 3 && !isKept(word, keep: keep) { add(word) }
                    if targets.count > before { grew = true }
                }
            }
            guard grew else { break }
            out = out.map { replace(targets, in: $0, tokens: &tokens) }
        }
        return (out, tokens)
    }

    /// Every whole-word match of `targets` (case ignored, longest first, no overlaps) replaced by the
    /// token for the words exactly as written there.
    static func replace(_ targets: [String], in text: String, tokens: inout NameTokens) -> String {
        let source = text as NSString
        var taken: [NSRange] = []
        var hits: [(range: NSRange, surface: String)] = []
        for target in targets.sorted(by: { $0.count > $1.count }) {
            let pattern = #"(?<![\p{L}\p{N}\[])"# + NSRegularExpression.escapedPattern(for: target) + #"(?![\p{L}\p{N}\]])"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                guard !taken.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { continue }
                taken.append(match.range)
                hits.append((match.range, source.substring(with: match.range)))
            }
        }
        guard !hits.isEmpty else { return text }
        var result = ""
        var last = 0
        for hit in hits.sorted(by: { $0.range.location < $1.range.location }) {
            result += source.substring(with: NSRange(location: last, length: hit.range.location - last))
            result += tokens.token(for: hit.surface)
            last = hit.range.location + hit.range.length
        }
        result += source.substring(from: last)
        return result
    }
}
