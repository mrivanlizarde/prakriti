import Foundation

// Choosing beats under a length (v2 part M9c, research-edit-engine.md 3.3): a small knapsack over the beats. A 55-minute talk has
// dozens of beats, not thousands, so it is solved here exactly for the beats alone and then made to keep its promises:
//
// - **Value** of a beat: the sum of its scores times the direction's weights (focused tags 1.5, the rest 0.25; with no focus
//   every tag 1; a tag to avoid 0), plus a little for every second it holds, so time left over is filled rather than wasted.
// - **Always kept**: the thesis beat (the talk's main point), the closing beat, any beat Ivan asked to keep whole, and every beat
//   each of those depends on.
// - **Never kept** (unless it must be): a beat on a topic or tag Ivan asked to leave out.
// - **Dependencies**: a kept beat keeps every beat it depends on (`dependsOn`, transitively). The knapsack's answer is repaired
//   to honour them (a beat whose dependencies do not fit is dropped), then filled again greedily; a greedy pass over each beat
//   with its dependencies is tried too, and the better of the two is kept.
// - **Order** is never changed: the selection only keeps or drops.
// - **Housekeeping** and beats scored 0 for every tag are never chosen to fill a length.
// - **With no length**, every beat is kept except housekeeping and those scored 0 for every tag (research 3.3's default), and
//   any beat to leave out.
//
// The seconds a beat costs are what the rough cut keeps of it (`keptSeconds`), so the length is the video's, not the recording's.

enum Selection {
    struct Input: Sendable {
        var beats: [Beat]
        /// What the rough cut keeps of each beat, by id, in seconds.
        var keptSeconds: [String: Double]
        /// The most the kept beats may hold, in seconds; nil for no length.
        var budget: Double?
        var fields: DirectionFields
    }

    struct Outcome: Equatable, Sendable {
        var kept: [String]
        var dropped: [String]
        var keptSeconds: Double
        var value: Double
        /// Kept although the budget could not hold them (the beats that must be kept are longer).
        var overBudget: Bool
    }

    /// A little value per second kept, so leftover time is filled with the next best beat.
    static let perSecond = 0.002

    static func value(_ beat: Beat, weights: [BeatTag: Double], seconds: Double) -> Double {
        BeatTag.allCases.reduce(0) { $0 + Double(beat.score($1)) * (weights[$1] ?? 1) } + perSecond * seconds
    }

    /// Whether a beat is about a topic: every word of substance in the topic is in the beat's summary, terms or words.
    static func about(_ beat: Beat, topic: String, words: [PlanWord]) -> Bool {
        let wanted = topic.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" }).map(String.init)
            .filter { !DirectionRules.filler.contains($0) && $0.count > 1 }
        guard !wanted.isEmpty else { return false }
        var said = Set(beat.summary.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" }).map(String.init))
        for term in beat.terms { said.formUnion(term.lowercased().split(separator: " ").map(String.init)) }
        if let a = PlanWord.index(of: beat.from), let b = PlanWord.index(of: beat.to), a <= b, b < words.count {
            for w in words[a...b] { said.insert(w.norm) }
        }
        return wanted.allSatisfy { w in said.contains(w) || said.contains(w + "s") || (w.hasSuffix("s") && said.contains(String(w.dropLast()))) }
    }

    static func choose(_ input: Input, words: [PlanWord] = []) -> Outcome {
        let beats = input.beats
        let ids = beats.map(\.id)
        let byID = Dictionary(uniqueKeysWithValues: beats.map { ($0.id, $0) })
        let fields = input.fields
        let weights = fields.weights
        func seconds(_ id: String) -> Double { max(0, input.keptSeconds[id] ?? byID[id]?.seconds ?? 0) }
        func closure(_ id: String) -> Set<String> {
            var out: Set<String> = [id], stack = [id]
            while let next = stack.popLast() {
                for d in byID[next]?.dependsOn ?? [] where !out.contains(d) && byID[d] != nil {
                    out.insert(d)
                    stack.append(d)
                }
            }
            return out
        }
        let avoided = Set(beats.filter { b in
            fields.avoid.contains { tag in BeatTag(rawValue: tag).map { b.score($0) >= 2 } ?? false }
                || fields.avoidTopics.contains { about(b, topic: $0, words: words) }
        }.map(\.id))
        var must = Set<String>()
        if let thesis = beats.first(where: \.thesis) { must.insert(thesis.id) }
        if let closing = beats.last(where: { $0.kind == .closing }) { must.insert(closing.id) }
        for b in beats where fields.keepWhole.contains(where: { about(b, topic: $0, words: words) }) { must.insert(b.id) }
        must = must.reduce(into: Set<String>()) { $0.formUnion(closure($1)) }
        func values(_ set: Set<String>) -> Double { set.reduce(0) { $0 + value(byID[$1]!, weights: weights, seconds: seconds($1)) } }
        func total(_ set: Set<String>) -> Double { set.reduce(0) { $0 + seconds($1) } }
        func outcome(_ kept: Set<String>, over: Bool) -> Outcome {
            Outcome(kept: ids.filter { kept.contains($0) }, dropped: ids.filter { !kept.contains($0) }, keptSeconds: total(kept), value: values(kept), overBudget: over)
        }

        guard let budget = input.budget else {
            // No length: everything but housekeeping, what scored nothing, and what Ivan asked to leave out (and what needs them).
            var kept = Set(beats.filter { !$0.isHousekeeping && !$0.scoredNothing && !avoided.contains($0.id) }.map(\.id))
            kept = kept.filter { closure($0).isDisjoint(with: avoided) || must.contains($0) }
            kept.formUnion(must)
            // Keep the dependencies of whatever is kept.
            kept = kept.reduce(into: Set<String>()) { $0.formUnion(closure($1)) }
            return outcome(kept, over: false)
        }

        let base = must
        let room = budget - total(base)
        if room <= 0 { return outcome(base, over: room < 0) }
        // Housekeeping and what scored nothing are never chosen to fill time (research 3.3), only kept when something needs them.
        let candidates = ids.filter { id in
            !base.contains(id) && !avoided.contains(id) && closure(id).isDisjoint(with: avoided) && !(byID[id]!.isHousekeeping || byID[id]!.scoredNothing)
        }

        // A greedy fill: each candidate with what it needs, best value per second first, while it fits.
        func fill(_ start: Set<String>) -> Set<String> {
            var kept = start
            while true {
                var best: (Set<String>, Double)?
                for id in candidates where !kept.contains(id) {
                    let add = closure(id).subtracting(kept)
                    let cost = total(add)
                    guard total(kept) + cost <= budget + 1e-9 else { continue }
                    let density = values(add) / max(cost, 0.5)
                    if best.map({ density > $0.1 }) ?? true { best = (add, density) }
                }
                guard let (add, _) = best else { return kept }
                kept.formUnion(add)
            }
        }
        let greedy = fill(base)

        // The knapsack on the candidates alone (half-second steps), then repaired for dependencies and filled.
        let step = 0.5
        let capacity = Int((room / step).rounded(.down))
        let costs = candidates.map { Int((seconds($0) / step).rounded(.up)) }
        let worth = candidates.map { value(byID[$0]!, weights: weights, seconds: seconds($0)) }
        var best = [Double](repeating: 0, count: capacity + 1)
        var took = [[Bool]](repeating: [Bool](repeating: false, count: capacity + 1), count: candidates.count)
        for i in candidates.indices where costs[i] <= capacity {
            for c in stride(from: capacity, through: costs[i], by: -1) where best[c - costs[i]] + worth[i] > best[c] {
                best[c] = best[c - costs[i]] + worth[i]
                took[i][c] = true
            }
        }
        var chosen = Set<String>()
        var c = capacity
        for i in candidates.indices.reversed() where c >= 0 && took[i][c] {
            chosen.insert(candidates[i])
            c -= costs[i]
        }
        var repaired = base.union(chosen)
        var changed = true
        while changed {
            changed = false
            for id in repaired where !closure(id).isSubset(of: repaired) {
                let missing = closure(id).subtracting(repaired)
                if total(repaired) + total(missing) <= budget + 1e-9 { repaired.formUnion(missing) } else if !base.contains(id) { repaired.remove(id) }
                changed = true
                break
            }
        }
        let knapsack = fill(repaired)
        let kept = values(knapsack) >= values(greedy) ? knapsack : greedy
        return outcome(kept, over: false)
    }
}
