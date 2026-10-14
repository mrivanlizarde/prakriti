import Foundation

// Fillers, stutters, restarts and retakes (v2 part M8a, docs/v2/research-edit-engine.md 1.5 and 1.6). All code, no
// model: each detector proposes words to take out with a confidence, and anything between "certain" and "deliberate"
// is kept and becomes a Check moment for Ivan ("Possible retake at 12:40: kept both."). Whether a proposal is really
// taken out is decided later by `RoughCut`, which drops any it cannot cut cleanly.
//
// The rules, each with its reason:
// - Fillers are um, uh, er, erm and ah standing alone (research 1.5). "Like", "you know" and the other discourse
//   markers are kept in the house style: telling the filler "like" from the verb needs a model (research 1.5), and
//   Energetic, the style that removes them, is M9.
// - A stutter is a word said twice within 0.3 s ("so so"), or a cut-off start ("w- we"); the first copy goes. A repeat
//   with a comma between ("very, very") is emphasis and stays.
// - A spoken restart marker takes everything from the start of the abandoned sentence to the marker's end. Only the
//   markers that cannot be teaching are acted on: "one more time" and "from the top" are things a yoga teacher says
//   to a room ("let's do that one more time"), so they only ever make a Check moment.
// - A sentence restart (research 1.6 detector 2) needs both: the next sentence opens with the same three words, and
//   the first looks abandoned. The parallel-phrasing guard keeps a complete first sentence whose remainder says
//   something else: two thirds of restart-looking pairs in the 6 Sep talk are deliberate (research, section 0).
// - Passage retakes (detector 4) need embeddings and the writing model's confirmation; neither is called in M8a, so
//   none is looked for here (BUILD-LOG, v2 part M8a, decision 3).

/// A stretch of words the rough cut proposes to take out.
struct Proposal: Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case filler, stutter, restart
    }
    let kind: Kind
    /// The first and last word taken out, inclusive.
    let first: Int
    let last: Int
    let confidence: Double
    /// For a restart: the take kept in its place, inclusive.
    var keptTake: ClosedRange<Int>?
}

/// A moment the rough cut was not sure about and kept, for Ivan to hear.
struct CheckMoment: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case possibleRetake, possibleRestart, uncleanCut
    }
    /// The word the moment is at.
    let at: String
    let kind: Kind
    /// What was kept: "both", or "it".
    let kept: String
    /// One sentence for the inspector, with the time ("Possible retake at 12:40: kept both.").
    let say: String
}

enum Restarts {
    static let fillers: Set<String> = ["um", "uh", "er", "erm", "ah", "uhm", "umm", "uhh"]
    /// A word said again within this long is a stutter.
    static let stutterGap = 0.3
    /// Words that are often said twice on purpose ("I know that that is true", "had had").
    static let doubledOnPurpose: Set<String> = ["that", "had", "is", "do"]
    /// Markers that end a take for certain, as words.
    static let strongMarkers: [[String]] = [
        ["let", "me", "start", "over"], ["let", "me", "say", "that", "again"], ["let", "me", "try", "that", "again"],
        ["let", "me", "say", "it", "again"], ["let", "me", "try", "again"], ["take", "two"], ["scratch", "that"], ["cut", "that"],
    ]
    /// Markers a teacher also says to a room: a Check moment only.
    static let weakMarkers: [[String]] = [["one", "more", "time"], ["from", "the", "top"], ["sorry", "let", "me"]]
    /// A restart's abandoned part longer than this is not taken out by itself: a Check moment instead.
    static let longestAbandoned = 30.0
    /// Two sentences this far apart (start to start) are not a restart.
    static let restartWindow = 20.0
    static let selfRepairs: [[String]] = [["i", "mean"], ["sorry"], ["no", "wait"]]

    static func isFiller(_ word: PlanWord) -> Bool { fillers.contains(word.norm) }

    /// "12:40" for a moment.
    static func clock(_ t: Double) -> String { TimeText.string(t.rounded(.down)) }

    // MARK: Fillers and stutters

    static func fillers(_ words: [PlanWord]) -> [Proposal] {
        words.filter(isFiller).map { Proposal(kind: .filler, first: $0.index, last: $0.index, confidence: 0.97) }
    }

    /// `ends` are the words' refined ends and `starts` their refined starts (or Parakeet's), for the 0.3 s rule.
    static func stutters(_ words: [PlanWord], starts: [Double], ends: [Double]) -> [Proposal] {
        var out: [Proposal] = []
        for i in words.indices.dropLast() {
            let a = words[i], b = words[i + 1]
            guard !a.norm.isEmpty, !isFiller(a), a.sentence == b.sentence, a.closes == .none else { continue }
            let gap = starts[i + 1] - ends[i]
            guard gap <= stutterGap else { continue }
            let cutOff = a.text.hasSuffix("-") && b.norm.hasPrefix(a.norm) && a.norm.count < b.norm.count
            let doubled = a.norm == b.norm && !doubledOnPurpose.contains(a.norm)
            if cutOff || doubled { out.append(Proposal(kind: .stutter, first: i, last: i, confidence: cutOff ? 0.9 : 0.85)) }
        }
        return out
    }

    // MARK: Spoken markers

    /// Where `marker` is said, as the index of its first word, at or after `from`.
    static func find(_ marker: [String], in norms: [String], from: Int = 0) -> [Int] {
        guard marker.count <= norms.count else { return [] }
        var found: [Int] = []
        var i = from
        while i + marker.count <= norms.count {
            if Array(norms[i..<(i + marker.count)]) == marker { found.append(i) }
            i += 1
        }
        return found
    }

    /// Restarts said out loud: each strong marker takes out its abandoned sentence and itself; each weak one is a Check.
    static func markers(_ words: [PlanWord]) -> (proposals: [Proposal], checks: [CheckMoment]) {
        let norms = words.map(\.norm)
        var proposals: [Proposal] = []
        var checks: [CheckMoment] = []
        var taken = IndexSet()
        for marker in strongMarkers {
            for at in find(marker, in: norms) where !taken.contains(at) {
                let end = at + marker.count - 1
                // The abandoned sentence: the one the marker is in, from its start; or, when the marker opens its own
                // sentence, the sentence before it too.
                var first = words[..<at].lastIndex { $0.sentence != words[at].sentence }.map { $0 + 1 } ?? 0
                if first == at, at > 0 {
                    let previous = words[at - 1].sentence
                    first = words[..<at].lastIndex { $0.sentence != previous }.map { $0 + 1 } ?? 0
                }
                let next = end + 1
                guard next < words.count else { continue }
                let keptLast = words[next...].firstIndex { $0.endsSentence } ?? (words.count - 1)
                if words[end].end - words[first].start > longestAbandoned {
                    checks.append(CheckMoment(at: words[at].id, kind: .possibleRestart, kept: "both",
                                              say: "Possible restart at \(clock(words[at].start)): kept both."))
                    continue
                }
                proposals.append(Proposal(kind: .restart, first: first, last: end, confidence: 0.98, keptTake: next...keptLast))
                taken.insert(integersIn: first...end)
            }
        }
        for marker in weakMarkers {
            for at in find(marker, in: norms) where !taken.contains(at) {
                checks.append(CheckMoment(at: words[at].id, kind: .possibleRestart, kept: "both",
                                          say: "Possible restart at \(clock(words[at].start)): kept both."))
            }
        }
        return (proposals, checks)
    }

    // MARK: Sentence restarts

    /// The words' indices grouped by Parakeet sentence, in order.
    static func sentences(_ words: [PlanWord]) -> [ClosedRange<Int>] {
        var out: [ClosedRange<Int>] = []
        var start = 0
        for i in words.indices where i == words.count - 1 || words[i + 1].sentence != words[i].sentence {
            out.append(start...i)
            start = i + 1
        }
        return out
    }

    /// How alike two word lists are: their longest common run in order, over the longer one's length.
    static func similarity(_ a: [String], _ b: [String]) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var table = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                table[i][j] = a[i - 1] == b[j - 1] ? table[i - 1][j - 1] + 1 : max(table[i - 1][j], table[i][j - 1])
            }
        }
        return Double(table[a.count][b.count]) / Double(max(a.count, b.count))
    }

    /// How alike two short strings are, by edit distance (1 the same).
    static func ratio(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 1 }
        if x.isEmpty || y.isEmpty { return 0 }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var current = [Int](repeating: 0, count: y.count + 1)
            current[0] = i
            for j in 1...y.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return 1 - Double(previous[y.count]) / Double(max(x.count, y.count))
    }

    /// A sentence that opens like the next one and was abandoned is a restart; one that was finished and says something
    /// else is parallel phrasing; one that was finished and says nearly the same is a Check ("Possible retake").
    static func sentenceRestarts(_ words: [PlanWord], skip: IndexSet = IndexSet()) -> (proposals: [Proposal], checks: [CheckMoment]) {
        let groups = sentences(words)
        var proposals: [Proposal] = []
        var checks: [CheckMoment] = []
        for (a, b) in zip(groups, groups.dropFirst()) {
            guard !skip.intersects(integersIn: a), words[b.lowerBound].start - words[a.lowerBound].start <= restartWindow else { continue }
            let first = words[a].map(\.norm).filter { !$0.isEmpty && !fillers.contains($0) }
            let second = words[b].map(\.norm).filter { !$0.isEmpty && !fillers.contains($0) }
            guard first.count >= 3, second.count >= 3 else { continue }
            let opening = 3
            guard ratio(first.prefix(opening).joined(separator: " "), second.prefix(opening).joined(separator: " ")) >= 0.8 else { continue }
            let last = words[a.upperBound]
            let endsInFiller = isFiller(last)
            let cutOff = last.text.hasSuffix("-")
            let complete = last.endsSentence && !endsInFiller && !cutOff
            let repaired = selfRepairs.contains { !find($0, in: first).isEmpty }
            let short = Double(first.count) < 0.6 * Double(second.count)
            let abandoned = !complete || repaired || short
            let rest = similarity(Array(first.dropFirst(opening)), Array(second.dropFirst(opening)))
            let parallel = complete && !repaired && rest < 0.5
            if abandoned && !parallel {
                proposals.append(Proposal(kind: .restart, first: a.lowerBound, last: a.upperBound, confidence: 0.85, keptTake: b))
            } else if !parallel && similarity(first, second) >= 0.8 {
                checks.append(CheckMoment(at: words[a.lowerBound].id, kind: .possibleRetake, kept: "both",
                                          say: "Possible retake at \(clock(words[a.lowerBound].start)): kept both."))
            }
        }
        return (proposals, checks)
    }
}
