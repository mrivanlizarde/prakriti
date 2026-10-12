import Foundation

// The transcript the Viewer shows under the player (v2 part M3b, docs/v2/design-spec.md 3.4.4): every
// word Parakeet heard, on the ORIGINAL recording's clock (START_HERE, Mac warning 41), grouped into
// sentences and the sentences into paragraphs. A word is the unit of playing (click it to play from it)
// and of editing (select words, then Cut or Keep). Read from transcript.json only through
// `EpisodeTranscript.sentences(json:)` (Mac warning 45: Parakeet's tokens are not in the order said).

/// One line of the transcript: one of Parakeet's sentences, on the original recording's clock, with
/// the word list applied for reading. Used by the library search ("Said" results) and by the Viewer.
struct TranscriptLine: Identifiable, Equatable, Sendable {
    let id: Int
    /// The sentence's span as Parakeet gives it: from the end of the sentence before (so it takes in
    /// the pause before it) to its last word.
    let start: Double
    let end: Double
    let text: String
    /// Where each word is said (`EpisodeTranscript.position`), so a line's fate follows its words,
    /// not the pause Parakeet counts into the sentence.
    var words: [Double] = []

    /// About when its first word starts: where the time shown and the player go.
    var speechStart: Double { words.first.map { max(start, $0 - 0.15) } ?? start }

    /// Where the line stands against the trim and cuts.
    enum Fate: Equatable { case kept, partlyCut, cut }

    func fate(in parts: [Mastering.Span]) -> Fate {
        func kept(_ t: Double) -> Bool { parts.contains { t >= $0.start && t <= $0.end } }
        if !words.isEmpty {
            let count = words.filter(kept).count
            return count == words.count ? .kept : (count == 0 ? .cut : .partlyCut)
        }
        let length = max(0.001, end - start)
        let keptLength = parts.reduce(0.0) { $0 + max(0, min(end, $1.end) - max(start, $1.start)) }
        if keptLength >= length - 0.05 { return .kept }
        return keptLength <= 0.05 ? .cut : .partlyCut
    }
}

/// One word of the transcript: what is shown, and when it is said on the original's clock.
struct TranscriptWord: Identifiable, Equatable, Sendable {
    let id: Int
    let sentence: Int
    /// As shown: Parakeet's pieces joined (with the word list applied when the sentence allows it),
    /// with the punctuation that follows the word.
    let text: String
    let start: Double
    let end: Double

    /// Where the word is said, for deciding whether a cut takes it (`EpisodeTranscript.position`).
    var position: Double { EpisodeTranscript.position(start: start, end: end) }

    /// Kept when its moment is inside a part the edit keeps.
    func isKept(in parts: [Mastering.Span]) -> Bool {
        parts.contains { position >= $0.start && position <= $0.end }
    }
}

/// A sentence of the transcript, as a run of its words.
struct TranscriptSentence: Identifiable, Equatable, Sendable {
    let id: Int
    let words: Range<Int>
    let start: Double
    let end: Double
}

/// Sentences shown together under one time.
struct TranscriptParagraph: Identifiable, Equatable, Sendable {
    let id: Int
    let sentences: Range<Int>
    let start: Double
}

/// The whole transcript as the Viewer reads it.
struct TranscriptDocument: Equatable, Sendable {
    var words: [TranscriptWord] = []
    var sentences: [TranscriptSentence] = []
    var paragraphs: [TranscriptParagraph] = []

    static let empty = TranscriptDocument()

    var isEmpty: Bool { words.isEmpty }

    /// A paragraph starts after a pause of this long, or once it holds this many sentences. Reason: until
    /// the people pass (M6) says who speaks, a pause is the only honest place to break; and a paragraph
    /// longer than six sentences is a wall at 17 pt.
    static let paragraphPause = 1.5
    static let paragraphSentences = 6

    /// Builds the document from transcript.json's sentences. With the word list on, a sentence whose
    /// fixed text has as many words as Parakeet heard shows the fixed words ("Yoga Marga" for "yoga
    /// market"); otherwise it shows Parakeet's own words, so a word never shows at another word's time.
    init(sentences raw: [EpisodeTranscript.Sentence], applyLexicon: Bool) {
        var words: [TranscriptWord] = []
        var sentences: [TranscriptSentence] = []
        for sentence in raw {
            let tokens = sentence.tokens ?? [EpisodeTranscript.Token(text: sentence.text, start: sentence.start, end: sentence.end)]
            let groups = EpisodeTranscript.words(tokens).filter { group in group.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
            guard !groups.isEmpty else { continue }
            let heard = groups.map { $0.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines) }
            var shown = heard
            if applyLexicon {
                let fixed = Lexicon.apply(heard.joined(separator: " ")).text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                if fixed.count == heard.count { shown = fixed }
            }
            let first = words.count
            for (index, group) in groups.enumerated() {
                let spoken = group.filter { EpisodeTranscript.isWord($0.text) }
                let start = (spoken.first ?? group[0]).start
                let end = max(start, (spoken.last ?? group[group.count - 1]).end)
                words.append(TranscriptWord(id: words.count, sentence: sentences.count, text: shown[index], start: start, end: end))
            }
            let range = first..<words.count
            sentences.append(TranscriptSentence(id: sentences.count, words: range, start: words[first].start, end: words[range].map(\.end).max() ?? words[first].end))
        }
        var paragraphs: [TranscriptParagraph] = []
        var opened = 0
        for index in sentences.indices {
            let breaks = index > opened
                && (index - opened >= Self.paragraphSentences || sentences[index].start - sentences[index - 1].end >= Self.paragraphPause)
            if breaks {
                paragraphs.append(TranscriptParagraph(id: paragraphs.count, sentences: opened..<index, start: sentences[opened].start))
                opened = index
            }
        }
        if !sentences.isEmpty {
            paragraphs.append(TranscriptParagraph(id: paragraphs.count, sentences: opened..<sentences.count, start: sentences[opened].start))
        }
        self.words = words
        self.sentences = sentences
        self.paragraphs = paragraphs
    }

    init() {}

    /// The sentence being said at `t` on the original's clock: the last one started by then, while it
    /// lasts or until the next one starts.
    func sentence(at t: Double) -> TranscriptSentence? {
        guard let index = sentences.lastIndex(where: { $0.start <= t + 0.05 }) else { return nil }
        let next = sentences.indices.contains(index + 1) ? sentences[index + 1].start : .greatestFiniteMagnitude
        return t <= max(sentences[index].end, next) ? sentences[index] : nil
    }

    /// The span of the original that a run of words takes, for a cut or a keep: from where the first word
    /// is said to where the last one ends, held clear of the words on each side, so a cut takes exactly
    /// the words chosen. Reason: Parakeet stretches the last word before a pause across the pause, and a
    /// cut to its end would take the next word too (Mac warning 40: a word is kept or dropped whole).
    func span(of chosen: ClosedRange<Int>) -> TimeRange? {
        guard words.indices.contains(chosen.lowerBound), words.indices.contains(chosen.upperBound) else { return nil }
        let first = words[chosen.lowerBound], last = words[chosen.upperBound]
        var start = first.start
        if chosen.lowerBound > 0 { start = max(start, words[chosen.lowerBound - 1].position + 0.01) }
        start = min(start, first.position)
        var end = last.end
        if chosen.upperBound + 1 < words.count { end = min(end, words[chosen.upperBound + 1].position - 0.01) }
        end = max(end, last.position + 0.01)
        return end > start ? TimeRange(start: start, end: end) : nil
    }
}

enum RecordingTranscript {
    /// transcript.json's sentences, in the order said, or nil when it is not there.
    static func sentences(folder: String?) -> [EpisodeTranscript.Sentence]? {
        guard let folder else { return nil }
        let url = URL(fileURLWithPath: folder, isDirectory: true).appending(path: TranscriptFiles.asHeard)
        guard let data = try? Data(contentsOf: url), let sentences = EpisodeTranscript.sentences(json: data), !sentences.isEmpty else { return nil }
        return sentences
    }

    /// The lines of a made transcript: transcript.json (every word as heard, on the original's
    /// clock) with the word list applied, else the .srt. Empty when neither is there.
    static func lines(folder: String?, applyLexicon: Bool) -> [TranscriptLine] {
        guard let folder else { return [] }
        if let sentences = sentences(folder: folder) {
            return sentences.enumerated().map { index, sentence in
                let text = sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return TranscriptLine(id: index, start: sentence.start, end: sentence.end, text: applyLexicon ? Lexicon.apply(text).text : text,
                                      words: (sentence.tokens ?? []).filter { EpisodeTranscript.isWord($0.text) }
                                        .map { EpisodeTranscript.position(start: $0.start, end: $0.end) })
            }
        }
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        if let srt = try? String(contentsOf: url.appending(path: TranscriptFiles.fileName(.srt)), encoding: .utf8) {
            return TranscriptFiles.cues(srt: srt).enumerated().map { TranscriptLine(id: $0.offset, start: $0.element.start, end: $0.element.end, text: $0.element.text) }
        }
        return []
    }

    /// The Viewer's document: transcript.json when it is there; else the .srt's cues, one word per
    /// space with the cue's time spread across them (a recording made by engine v0 may have no .json).
    static func document(folder: String?, applyLexicon: Bool) -> TranscriptDocument {
        if let sentences = sentences(folder: folder) {
            return TranscriptDocument(sentences: sentences, applyLexicon: applyLexicon)
        }
        let lines = lines(folder: folder, applyLexicon: false)
        let sentences = lines.map { line -> EpisodeTranscript.Sentence in
            let pieces = line.text.split(separator: " ").map(String.init)
            let step = (line.end - line.start) / Double(max(1, pieces.count))
            let tokens = pieces.enumerated().map { index, piece in
                EpisodeTranscript.Token(text: " " + piece, start: line.start + Double(index) * step, end: line.start + Double(index + 1) * step)
            }
            return EpisodeTranscript.Sentence(text: line.text, start: line.start, end: line.end, tokens: tokens)
        }
        return TranscriptDocument(sentences: sentences, applyLexicon: applyLexicon)
    }
}
