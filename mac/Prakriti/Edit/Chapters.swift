import Foundation

// Chapters of the edited video (v2 part M9d, docs/v2/PLAN.md M9; research-edit-engine.md 3.4 rule 6 and 6.1; YouTube's chapter
// rules, support.google.com/youtube/answer/9884579): one per part of the talk the plan keeps, placed on the video's own clock
// where that part's first kept word plays, titled with the few plain words the planning model gave the part (never a name or a
// private matter, Mac warning 51; Ivan's copy rules applied, `CopyRules`). Code holds them to the rules:
//
// - the first starts at 0:00 (the opening line belongs to it);
// - each is at least `shortest` long (a part shorter than that joins the chapter before it), the last included;
// - at least three, else none: the description then keeps the writer's chapters, as before.
//
// `Description.txt` reads them first (`VideoDescription.make`), and the Timeline-lite marks each with a bookmark.

enum Chapters {
    /// A chapter shorter than this joins the one before it. YouTube's floor is 10 s; parts of a talk under half a minute do not
    /// make chapters a viewer would use.
    static let shortest = 30.0
    static let least = 3

    /// The chapters of a plan whose spans (the opening line included) are final, from the beats it keeps.
    static func make(plan: EditPlan, beats: [Beat], words: [PlanWord]) -> [EditPlan.Chapter] {
        let timeline = EditTimeline(plan: plan)
        guard timeline.totalFrames > 0 else { return [] }
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let kept = Set(plan.mainSpans.flatMap { s -> [Int] in
            guard let a = PlanWord.index(of: s.from), let b = PlanWord.index(of: s.to), a <= b else { return [] }
            return Array(a...b)
        })
        var chapters: [EditPlan.Chapter] = []
        for beat in beats {
            guard let a = PlanWord.index(of: beat.from), let b = PlanWord.index(of: beat.to), a <= b, b < words.count,
                  let first = (a...b).first(where: { kept.contains($0) }), let t = times[words[first].id],
                  let at = timeline.editTime(t.in) ?? timeline.editTimeAtOrAfter(t.in) else { continue }
            let title = Self.title(beat.summary)
            guard !title.isEmpty else { continue }
            let seconds = chapters.isEmpty ? 0 : EditPlan.round3(at)
            if let last = chapters.last, seconds - (last.seconds ?? 0) < shortest { continue }
            chapters.append(EditPlan.Chapter(title: title, at: chapters.isEmpty ? (plan.spans.first?.from ?? words[first].id) : words[first].id, seconds: seconds))
        }
        while let last = chapters.last, chapters.count > 1, timeline.duration - (last.seconds ?? 0) < shortest { chapters.removeLast() }
        return chapters.count >= least ? chapters : []
    }

    /// A part's few words as a chapter title: its first letter capitalized, no dashes, nothing Ivan's copy rules flag.
    static func title(_ summary: String) -> String {
        var t = WritingText.withoutDashes(summary.trimmingCharacters(in: .whitespacesAndNewlines)).0
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".,;: "))
        guard !t.isEmpty, CopyRules.flag(t) == nil else { return "" }
        return t.prefix(1).uppercased() + t.dropFirst()
    }
}
