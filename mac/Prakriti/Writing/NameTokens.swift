import Foundation
import NaturalLanguage

// Names in text that goes to a cloud model (v2 part M5a; narrowed by part LOCK, Wed 14 Oct 2026).
//
// Since part LOCK the lock replaces only the names that must never go: names Ivan marked Mute and the names of
// anyone he marked "no release" (`tokenize(_:only:)`, each whole name and each of its words of three letters or more).
// Every other name goes as it is, because Ivan's decision of Mon 12 Oct (every participant signed a release) makes a
// name said aloud nobody's privacy question. Each replaced form gets its own [[NAME-n]] and is put back exactly in
// the answer, so a quote still matches the transcript word for word.
//
// Apple's tagger (`findNames`, and the older `tokenize(_:keep:always:)` that replaced every name it found) stays for
// the names said aloud step and its measured recall (BUILD-LOG, "v2 part M5a"); the lock no longer calls it.

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

    /// Replaces only `names` (Ivan's muted names and the names of anyone marked "no release"), each whole name and
    /// each of its words of three letters or more where it stands alone, case ignored; nothing the tagger finds.
    static func tokenize(_ texts: [String], only names: [String]) -> (texts: [String], tokens: NameTokens) {
        var targets: [String] = []
        func add(_ name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !targets.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
            targets.append(trimmed)
        }
        for name in names {
            add(name)
            let parts = words(name)
            for word in parts where parts.count > 1 && word.count >= 3 { add(word) }
        }
        var tokens = NameTokens()
        guard !targets.isEmpty else { return (texts, tokens) }
        let out = texts.map { replace(targets, in: $0, tokens: &tokens) }
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
