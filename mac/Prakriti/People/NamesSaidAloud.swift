import Foundation
import NaturalLanguage

// Names said aloud (v2 part M6c, docs/v2/PLAN.md section 5 and M6, risk R13): a student named by the teacher would
// otherwise reach the podcast, its captions and the show notes. Every person's name Apple's tagger finds in the
// transcript (NLTagger, `.nameType`, `personalName`, the same tagger as the cloud lock's NameTokens) that is not the
// name of someone Ivan named in Settings, Privacy becomes a moment to check: Keep, or Mute. Mute silences the word in
// every audio output (`Mastering.muteFilter`) and writes "[name]" in its place in the captions and transcript files
// (`EpisodeTranscript.cues`, `mutes`). Approve waits until every one is decided (`ApprovalCheck`).
//
// The tagger misses some names (its recall on the 13 Sep talk is in BUILD-LOG, "v2 part M5a"), so this is a help to
// Ivan's listening, not a guarantee; the help article says so.

/// One name said aloud, on the original's clock, with the words as Parakeet heard them.
struct NameMoment: Codable, Equatable, Hashable, Sendable, Identifiable {
    var start: Double
    var end: Double
    /// The name as heard ("Krishna"), shown in the People tab so Ivan can decide. Never written to a notice or the log.
    var text: String

    /// Its key in `PeopleChoices.names`: the start to a hundredth of a second (Parakeet's times do not change between
    /// makes of the same file).
    var key: String { String(format: "%.2f", start) }
    var id: String { key }
}

/// What the names step found in one recording (`Recording.namesSaidJSON`).
struct NamesSaid: Codable, Equatable, Sendable {
    var checkedAt: Date
    var moments: [NameMoment] = []

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode(_ json: String?) -> NamesSaid? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(NamesSaid.self, from: data)
    }

    /// The moments grouped by the name said, in the order each name is first said, for the People tab.
    var byName: [(name: String, moments: [NameMoment])] {
        var order: [String] = []
        var groups: [String: [NameMoment]] = [:]
        for moment in moments {
            let key = moment.text.lowercased()
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(moment)
        }
        return order.map { (groups[$0]![0].text, groups[$0]!) }
    }

    /// The step's line: a count, never a name.
    var stepLine: String {
        moments.isEmpty ? "No name said aloud, other than the people you named."
                        : "\(Format.count(moments.count, "name")) said aloud to check, other than the people you named."
    }
}

enum NamesSaidAloud {
    /// The names said in a transcript.json's sentences that are not one of `named` (the people named in Settings,
    /// Privacy: the whole name or every word of it, case ignored, as `NameTokens.isKept` reads it).
    static func find(_ sentences: [EpisodeTranscript.Sentence], named: [String]) -> [NameMoment] {
        var moments: [NameMoment] = []
        for sentence in sentences {
            let tokens = sentence.tokens ?? [EpisodeTranscript.Token(text: sentence.text, start: sentence.start, end: sentence.end)]
            let words = EpisodeTranscript.words(tokens)
            // The sentence as its words spell it, with where each word sits in the text.
            var text = ""
            var spans: [(range: Range<Int>, start: Double, end: Double)] = []
            for word in words {
                guard let first = word.first, let last = word.last else { continue }
                let piece = word.map(\.text).joined()
                let from = text.count
                text += piece
                spans.append((from..<text.count, first.start, last.end))
            }
            guard !text.isEmpty else { continue }
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                                 options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
                guard tag == .personalName else { return true }
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                guard !name.isEmpty, !NameTokens.isKept(name, keep: named) else { return true }
                let lower = text.distance(from: text.startIndex, to: range.lowerBound)
                let upper = text.distance(from: text.startIndex, to: range.upperBound)
                let touched = spans.filter { $0.range.lowerBound < upper && $0.range.upperBound > lower }
                guard let first = touched.first, let last = touched.last else { return true }
                // A word's end can stretch across the pause after it (Mac warning 40): a name is never taken as longer
                // than a second a word.
                let end = min(last.end, last.start + EpisodeTranscript.longestWord)
                moments.append(NameMoment(start: PeopleFile.round(first.start), end: PeopleFile.round(max(first.start, end)), text: name))
                return true
            }
        }
        return moments.sorted { $0.start < $1.start }
    }
}
