import Foundation

// Find Supporting Moments (v2 part M12a, docs/v2/PLAN.md M12, design spec 3.8): REQUEST item 9, "merge sections from different
// videos ... added to the video at hand but not always and not as a rule". Prakriti finds; Ivan decides. Nothing here adds anything
// to a plan or a video: the answer is a list for the sheet, and adding one (by hand, `addedBy: "ivan"`) is part M12b.
//
// 1. What to support: this recording's main points (its parts of the talk: the main point first, then the strongest teaching parts),
//    or the words Ivan selected in the transcript.
// 2. Where to look: only other recordings of the same named teacher (Who is teaching in Info), whose people check ran. A recording
//    with another teacher, or none, is never searched.
// 3. How: each point and each indexed window as numbers for meaning (`MomentEmbedder`, on this Mac); every window above
//    `threshold` is a candidate, best first, never two that overlap in the same recording, and every candidate's span is checked
//    again against the people choices of now (`MomentPeople`).
// 4. Then the model chosen for "Choosing moments" reads each candidate beside its point, under the privacy lock, and says in one
//    sentence whether it supports the point without contradicting it (`MomentJudge`, Writing/). At most three are kept.
//    A candidate whose words break Ivan's copy rules (`CopyRules`: a price, money, enrollment, an offer) is never offered.
// 5. Each moment is the source transcript's own words, 5 to 45 s on sentence boundaries, with its date, why, and where it would go
//    (after the last sentence of the point, a sentence boundary of this recording).

/// What a moment should support.
struct MomentPoint: Sendable, Equatable {
    /// The words the point is made of (the part of the talk, or the selection).
    var text: String
    /// Where a moment for it would go: after the sentence that ends at this time, on this recording's clock, and its last words.
    var after: Double
    var afterWords: String
}

/// One recording as the search reads it.
struct MomentSource: Sendable {
    var id: UUID
    /// "Sun 6 Sep 2026, Talk with Gabriel".
    var label: String
    var date: Date
    var teacher: UUID?
    var words: [PlanWord]
    var transcriptSHA256: String
    var people: MomentPeople
    /// What the privacy lock reads about it.
    var facts: PeopleFacts
    /// The original, for the sheet's Play.
    var filePath: String
}

/// One moment found, as the sheet shows it.
struct SupportingMoment: Codable, Equatable, Sendable, Identifiable {
    var sourceID: UUID
    var sourceLabel: String
    var sourceDate: Date
    var filePath: String
    var window: MomentWindow
    /// The source transcript's own words, from its first word to its last.
    var words: String
    /// The model's one sentence.
    var why: String
    /// Which point it supports (an index into the search's points), and where it would go.
    var point: Int
    var after: Double
    var afterWords: String
    var similarity: Double

    var id: String { sourceID.uuidString + ":" + window.key }
    var seconds: Double { window.seconds }
}

/// What one search found, and how.
struct MomentSearch: Sendable, Equatable {
    var header: String
    var moments: [SupportingMoment]
    /// Recordings of the same teacher searched, and those not searched (their people not checked, or no transcript).
    var searched: Int
    var notSearched: Int
    var teacherName: String
    /// Windows read, candidates above the threshold, judged, and judged as not supporting.
    var windows: Int
    var candidates: Int
    var judged: Int
    var declined: Int
    /// Windows never offered because their words break Ivan's copy rules (a price, money, enrollment, an offer).
    var copyRules: Int = 0
    var by: String
    var seconds: Double
    var notes: [String] = []

    /// The empty sheet's words, with the real count (design spec 3.8: never invented).
    var emptyLine: String {
        "No other recording makes this point clearly. Prakriti searched \(Format.count(searched, "recording")) of \(teacherName)."
    }
}

/// The model's reading of one candidate.
struct MomentVerdict: Sendable, Equatable {
    var supports: Bool
    var contradicts: Bool
    var why: String
}

/// Asks the model about one candidate. Writing/ provides it (`MomentJudge`), under the privacy lock.
protocol MomentJudging: Sendable {
    var displayName: String { get }
    func judge(point: String, moment: String, momentDay: String, source: UUID) async throws -> MomentVerdict
}

enum MomentFinder {
    struct Refusal: Error, Equatable, Sendable {
        let reason: String
    }

    /// The least cosine similarity between a point and a window for the model to be asked about it. Measured on the build day (Fri 16
    /// Oct, BUILD-LOG v2 part M12a) with nomic-embed-text-v1.5, the 13 Sep talk's parts (summary and key line, "search_query: ") against
    /// the 6 Sep talk's 563 windows ("search_document: "): median 0.608, 90th percentile 0.672, 99th 0.723, each part's best 0.678 to
    /// 0.752; a sentence about baking bread reached 0.616 at best. 0.66 is above anything unrelated and keeps about the best tenth.
    static let threshold: Float = 0.66
    /// Design spec 3.8: up to three suggestions.
    static let most = 3
    /// The model is asked about at most this many candidates, each point's best in turn. 12: measured 16 Oct, on 13 Sep against 6 Sep
    /// the first 8 read were all declined (two talks on different subjects); about 25 s each on Qwen3.8-27B, a few cents in all on Sonnet.
    static let judgeAtMost = 12

    /// Only another recording with the same named teacher is ever searched.
    static func sameTeacher(_ current: MomentSource, _ other: MomentSource) -> Bool {
        guard let teacher = current.teacher else { return false }
        return other.id != current.id && other.teacher == teacher
    }

    /// The main points of a recording from its parts of the talk: the main point first, then the parts that stand alone, strongest
    /// first; never the welcome, housekeeping or closing. Each is searched for by its few words and its key line (measured 16 Oct: the
    /// part's whole text was found closest to windows that only name the school, the key line to windows making the same point),
    /// and placed after its last sentence.
    static func points(beats: [Beat], words: [PlanWord], most: Int = 5) -> [MomentPoint] {
        func strength(_ beat: Beat) -> Int {
            [BeatTag.enlightening, .motivating, .philosophy, .practical, .technique].map(beat.score).reduce(0, +)
        }
        let usable = beats.filter { ![.welcome, .housekeeping, .closing].contains($0.kind) }
        let ordered = usable.filter(\.thesis) + usable.filter { !$0.thesis }.sorted {
            ($0.standsAlone ? 1 : 0, strength($0), -$0.start) > ($1.standsAlone ? 1 : 0, strength($1), -$1.start)
        }
        return ordered.prefix(most).compactMap { beat in
            let inside = words.filter { $0.position >= beat.start - 0.001 && $0.position <= beat.end + 0.001 }
            guard let last = inside.last else { return nil }
            var made = point(words: Array(inside.prefix(120)), lastWord: last, all: words)
            if let key = beat.keyLine?.text, !key.isEmpty { made.text = beat.summary + ". " + key }
            return made
        }
    }

    /// The point made by the words selected between two times (the transcript's Find Supporting Moments for This...).
    static func point(selectedFrom start: Double, to end: Double, words: [PlanWord]) -> MomentPoint? {
        let inside = words.filter { $0.position >= start - 0.001 && $0.position <= end + 0.001 }
        guard let last = inside.last else { return nil }
        return point(words: inside, lastWord: last, all: words)
    }

    /// A point from its words: a moment for it goes after the end of the sentence its last word is in.
    private static func point(words inside: [PlanWord], lastWord: PlanWord, all: [PlanWord]) -> MomentPoint {
        let sentence = all.filter { $0.sentence == lastWord.sentence }
        let closing = sentence.last ?? lastWord
        let tail = sentence.suffix(8).map(\.text).joined(separator: " ")
        return MomentPoint(text: PlanWords.text(inside[...]), after: closing.end, afterWords: tail)
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }
        var sum: Float = 0
        for i in a.indices { sum += a[i] * b[i] }
        return sum
    }

    /// The candidates, best first: each window's best similarity to any point, above `threshold`, never two overlapping in the same
    /// recording, each span allowed by its recording's people of now.
    static func candidates(points: [[Float]], stored: [MomentIndex.Stored], sources: [UUID: MomentSource],
                           threshold: Float = MomentFinder.threshold, copyRules: UnsafeMutablePointer<Int>? = nil) -> [(stored: MomentIndex.Stored, point: Int, similarity: Float)] {
        var scored: [(stored: MomentIndex.Stored, point: Int, similarity: Float)] = []
        for item in stored {
            guard let source = sources[item.recording], source.people.problem(start: item.window.start, end: item.window.end) == nil else { continue }
            // A moment goes into a published video, so it keeps Ivan's copy rules like every line Prakriti picks for the screen
            // (Mac warning 182): measured 16 Oct, the second moment first found for 13 Sep named "$32,000 in 30 days".
            if CopyRules.flag(MomentWindows.text(item.window, words: source.words)) != nil {
                copyRules?.pointee += 1
                continue
            }
            var best: (Int, Float) = (0, -1)
            for (i, p) in points.enumerated() {
                let s = cosine(p, item.vector)
                if s > best.1 { best = (i, s) }
            }
            if best.1 >= threshold { scored.append((item, best.0, best.1)) }
        }
        scored.sort { $0.similarity > $1.similarity }
        var kept: [(stored: MomentIndex.Stored, point: Int, similarity: Float)] = []
        for candidate in scored where !kept.contains(where: {
            $0.stored.recording == candidate.stored.recording && $0.stored.window.end > candidate.stored.window.start
                && $0.stored.window.start < candidate.stored.window.end
        }) {
            kept.append(candidate)
        }
        // Each point in turn, its best first, so the model reads the best candidate of every point before the second of any.
        var byPoint = Dictionary(grouping: kept, by: \.point).mapValues { $0[...] }
        let order = kept.map(\.point).reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
        var turns: [(stored: MomentIndex.Stored, point: Int, similarity: Float)] = []
        while turns.count < kept.count {
            for point in order {
                if let next = byPoint[point]?.popFirst() { turns.append(next) }
            }
        }
        return turns
    }

    /// Brings the index up to date for these recordings: each recording's windows that may be offered, embedded again when its
    /// transcript, its people or the model changed, and taken out when none may be. Returns how many recordings were embedded.
    @discardableResult
    static func update(index: MomentIndex, sources: [MomentSource], embedder: any MomentEmbedder, now: Date) async throws -> Int {
        var embedded = 0
        for source in sources {
            guard let teacher = source.teacher else { continue }
            let windows = MomentWindows.make(source.words).filter { source.people.problem(start: $0.start, end: $0.end) == nil }
            let signature = MomentIndex.signature(transcriptSHA256: source.transcriptSHA256, windows: windows, model: embedder.modelID)
            if let entry = try index.entry(source.id), entry.signature == signature, entry.teacher == teacher { continue }
            guard !windows.isEmpty else {
                try index.remove(source.id)
                continue
            }
            let texts = windows.map { LocalEmbeddings.documentPrefix + MomentWindows.text($0, words: source.words) }
            let vectors = try await embedder.embed(texts)
            try index.replace(source.id, teacher: teacher, signature: signature, model: embedder.modelID, windows: windows, vectors: vectors, at: now)
            embedded += 1
        }
        return embedded
    }

    /// The search. `others` may hold any recordings; only those with the same teacher are read.
    static func find(current: MomentSource, points: [MomentPoint], header: String, others: [MomentSource], notSearched: Int, teacherName: String,
                     index: MomentIndex, embedder: any MomentEmbedder, judge: any MomentJudging, now: Date,
                     progress: @Sendable (String) -> Void = { _ in }) async throws -> MomentSearch {
        let started = Date()
        guard current.teacher != nil else {
            throw Refusal(reason: "Prakriti looks for moments only in recordings of the same teacher, and nobody is chosen as teaching this one. Choose who is teaching in Info first.")
        }
        guard !points.isEmpty else { throw Refusal(reason: "There is nothing to look for: no main points and no words chosen.") }
        let sources = others.filter { sameTeacher(current, $0) }
        var search = MomentSearch(header: header, moments: [], searched: sources.count, notSearched: notSearched, teacherName: teacherName, windows: 0,
                                  candidates: 0, judged: 0, declined: 0, by: judge.displayName, seconds: 0)
        guard !sources.isEmpty else {
            search.seconds = Date().timeIntervalSince(started)
            return search
        }
        progress("Reading \(Format.count(sources.count, "recording")) of \(teacherName) on this Mac.")
        try await update(index: index, sources: sources, embedder: embedder, now: now)
        let stored = try index.windows(of: sources.map(\.id))
        search.windows = stored.count
        let pointVectors = try await embedder.embed(points.map { LocalEmbeddings.queryPrefix + $0.text })
        let bySource = Dictionary(sources.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var flagged = 0
        let found = withUnsafeMutablePointer(to: &flagged) { candidates(points: pointVectors, stored: stored, sources: bySource, copyRules: $0) }
        search.copyRules = flagged
        search.candidates = found.count
        for candidate in found.prefix(judgeAtMost) {
            guard search.moments.count < most, let source = bySource[candidate.stored.recording] else { break }
            let words = MomentWindows.text(candidate.stored.window, words: source.words)
            guard !words.isEmpty else { continue }
            progress("Asking \(judge.displayName) about a moment from \(Format.dayLabel(source.date)) (\(search.judged + 1) of at most \(min(found.count, judgeAtMost))).")
            let verdict = try await judge.judge(point: points[candidate.point].text, moment: words, momentDay: Format.fullDay(source.date), source: source.id)
            search.judged += 1
            guard verdict.supports, !verdict.contradicts else {
                search.declined += 1
                continue
            }
            let point = points[candidate.point]
            search.moments.append(SupportingMoment(sourceID: source.id, sourceLabel: source.label, sourceDate: source.date, filePath: source.filePath,
                                                   window: candidate.stored.window, words: words, why: verdict.why, point: candidate.point,
                                                   after: point.after, afterWords: point.afterWords, similarity: Double(candidate.similarity)))
        }
        search.seconds = Date().timeIntervalSince(started)
        return search
    }
}
