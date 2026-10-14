import CryptoKit
import Foundation

// The words of a recording, as the edit plan reads them (v2 part M8a, docs/v2/research-edit-engine.md 1.2 step 1).
// transcript.json is read through v1's `EpisodeTranscript.sentences(json:)`, which puts Parakeet's tokens back in the
// order they were said (Mac warning 45), then the tokens are grouped into words (`EpisodeTranscript.words`) and each
// word gets a stable id, "w0", "w1" and so on, in spoken order. The file's SHA-256 is kept with them, so a plan made
// from one transcript is refused against another (PlanValidation rule 1).
//
// Load-bearing: the ids are positions in this list. They stay stable only while transcript.json is the same file,
// which is exactly what the hash proves.

/// One word as said: its text with its punctuation, Parakeet's own times, and the sentence it belongs to.
struct PlanWord: Equatable, Sendable {
    let index: Int
    /// "Okay." with the punctuation Parakeet attached, without the leading space.
    let text: String
    /// Lowercase letters, digits and apostrophes only: "Okay." is "okay".
    let norm: String
    /// Parakeet's times for the word (its first token's start, its last token's end), on the original's clock.
    let start: Double
    let end: Double
    /// The Parakeet sentence it belongs to, from 0.
    let sentence: Int
    /// What closes the word, read from its punctuation.
    let closes: Closing

    var id: String { Self.id(index) }

    static func id(_ index: Int) -> String { "w\(index)" }

    /// The index of an id, or nil when it is not one.
    static func index(of id: String) -> Int? {
        guard id.hasPrefix("w"), let n = Int(id.dropFirst()), n >= 0 else { return nil }
        return n
    }

    /// What a word's punctuation says about the pause after it (research-edit-engine.md 1.4).
    enum Closing: String, Codable, Sendable {
        /// No punctuation: a pause inside a sentence.
        case none
        /// A comma, semicolon or colon: Parakeet often joins whole sentences with commas, so this counts as the end of
        /// a sentence for the pause it takes (measured 13 Oct on the ums fixture: "the breath, um, every morning").
        case clause
        /// A full stop, question mark or exclamation mark.
        case sentence
        /// A question mark: a sentence, and a question to the listener, which protects the pause after it.
        case question
    }

    var endsSentence: Bool { closes == .sentence || closes == .question }

    /// Where the word is said, for deciding whether a stretch of time takes it (v1's rule, `EpisodeTranscript.position`).
    var position: Double { EpisodeTranscript.position(start: start, end: end) }

    static func normalize(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "'" || $0 == "\u{2019}" }
            .map(Character.init)).replacingOccurrences(of: "\u{2019}", with: "'")
    }

    static func closing(_ text: String) -> Closing {
        let trailing = text.reversed().prefix { !$0.isLetter && !$0.isNumber }
        if trailing.contains("?") { return .question }
        if trailing.contains(where: { ".!…".contains($0) }) { return .sentence }
        if trailing.contains(where: { ",;:".contains($0) }) { return .clause }
        return .none
    }
}

/// The words of one transcript.json, and its hash.
struct PlanWords: Sendable {
    let words: [PlanWord]
    /// SHA-256 of transcript.json's bytes, in lowercase hex.
    let transcriptSHA256: String
    /// How many Parakeet sentences.
    let sentences: Int

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Reads transcript.json's bytes. Nil when they are not a Parakeet transcript.
    static func from(json data: Data) -> PlanWords? {
        guard let sentences = EpisodeTranscript.sentences(json: data) else { return nil }
        var words: [PlanWord] = []
        for (number, sentence) in sentences.enumerated() {
            let tokens = sentence.tokens ?? [EpisodeTranscript.Token(text: sentence.text, start: sentence.start, end: sentence.end)]
            for group in EpisodeTranscript.words(tokens) {
                guard let first = group.first, let last = group.last else { continue }
                let text = group.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
                // Punctuation on its own (no word before it in this sentence) goes with the word before it.
                guard group.contains(where: { EpisodeTranscript.isWord($0.text) }) else {
                    if let previous = words.last, previous.sentence == number {
                        let joined = previous.text + text
                        words[words.count - 1] = PlanWord(index: previous.index, text: joined, norm: previous.norm, start: previous.start,
                                                          end: max(previous.end, last.end), sentence: number, closes: PlanWord.closing(joined))
                    }
                    continue
                }
                words.append(PlanWord(index: words.count, text: text, norm: PlanWord.normalize(text), start: first.start,
                                      end: max(first.start, last.end), sentence: number, closes: PlanWord.closing(text)))
            }
        }
        return PlanWords(words: words, transcriptSHA256: sha256(data), sentences: sentences.count)
    }

    /// The words from `first` to `last` as written: Parakeet's text joined with single spaces.
    static func text(_ words: ArraySlice<PlanWord>) -> String {
        words.map(\.text).joined(separator: " ")
    }

    /// Text compared for PlanValidation rule 2: case and spacing do not count.
    static func comparable(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
