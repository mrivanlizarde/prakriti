import Foundation

// `Description.txt` beside the edited video (v2 part M8b, docs/v2/PLAN.md M8 "Deliverables"): the title, the description
// and the chapters to paste into YouTube. Taken from what Ivan chose (the recording's title and notes in Info) first, then
// from the writing step when it ran; anything neither has is written as MISSING with what to do, never invented (Mac
// warning 62).
//
// Chapters are the plan's own when it has them (v2 part M9d: one per part of the talk, made on the video's clock), else the
// writer's, moved onto the edited video's clock through the plan (a chapter that starts in a stretch the
// plan took out starts where the video picks up again), then held to YouTube's rules (support.google.com/youtube/answer/
// 9884579, research-edit-engine.md 6.1): the first at 0:00, at least three, in order, each at least 10 seconds. Chapters
// that break a rule are not written; the checklist says which rule.

struct VideoDescription: Codable, Equatable, Sendable {
    struct Chapter: Codable, Equatable, Sendable {
        var start: Double
        var title: String
    }

    var title: String?
    var description: String?
    var chapters: [Chapter] = []
    /// Why there are no chapters, or nil when there are.
    var chapterProblem: String?

    static let fileName = "Description.txt"
    static let minimumChapter = 10.0

    /// What goes with the video. `written` is the writing step's package (nil when it did not run); its chapter times are
    /// on `writtenClock`'s clock, mapped to the original's by `toOriginal`.
    static func make(title chosenTitle: String, notes: String, written: WrittenPackage?, toOriginal: (Double) -> Double?,
                     timeline: EditTimeline, planChapters: [EditPlan.Chapter] = []) -> VideoDescription {
        var d = VideoDescription()
        let ownTitle = chosenTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        d.title = !ownTitle.isEmpty ? ownTitle : written?.titles.first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let ownNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let writtenNotes = written?.showNotes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        d.description = !ownNotes.isEmpty ? ownNotes : (writtenNotes.isEmpty ? nil : writtenNotes)
        // The plan's own chapters first (v2 part M9d): made for this video, on its clock, opening line included.
        let planned = planChapters.compactMap { c in c.seconds.map { Chapter(start: $0, title: c.title) } }
        if planned.count == planChapters.count, !planned.isEmpty, problem(planned, duration: timeline.duration) == nil {
            d.chapters = planned
            return d
        }
        guard let written, !written.chapters.isEmpty else {
            d.chapterProblem = "No chapters were written for it."
            return d
        }
        var chapters: [Chapter] = []
        for chapter in written.chapters.sorted(by: { $0.start < $1.start }) {
            guard let original = toOriginal(chapter.start), let at = timeline.editTimeAtOrAfter(original) else { continue }
            if let last = chapters.last, at - last.start < 0.5 { continue }
            chapters.append(Chapter(start: at, title: chapter.title))
        }
        if let first = chapters.first, first.start > 0 { chapters[0].start = 0 }
        if let problem = problem(chapters, duration: timeline.duration) {
            d.chapterProblem = problem
        } else {
            d.chapters = chapters
        }
        return d
    }

    /// YouTube's chapter rules, or nil when they hold.
    static func problem(_ chapters: [Chapter], duration: Double) -> String? {
        guard chapters.count >= 3 else { return "Only \(chapters.count) chapters fit the video; YouTube needs at least three." }
        guard chapters[0].start == 0 else { return "The first chapter does not start at 0:00." }
        for (a, b) in zip(chapters, chapters.dropFirst()) where b.start - a.start < minimumChapter {
            return "\u{201C}\(a.title)\u{201D} is shorter than 10 seconds in the video."
        }
        if let last = chapters.last, duration - last.start < minimumChapter {
            return "\u{201C}\(last.title)\u{201D} is shorter than 10 seconds in the video."
        }
        return nil
    }

    /// "0:00", "12:05", "1:02:03", as YouTube reads chapter times.
    static func stamp(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// The file's words.
    var text: String {
        var t = "TITLE\n"
        t += (title ?? "MISSING: no title chosen or written. Give the recording a title in Info, or turn on Titles, show notes and chapters, then Make Again.") + "\n\n"
        t += "DESCRIPTION\n"
        t += (description ?? "MISSING: no description chosen or written. Write notes in Info, or turn on Titles, show notes and chapters, then Make Again.") + "\n"
        if !chapters.isEmpty {
            t += "\n" + chapters.map { "\(Self.stamp($0.start)) \($0.title)" }.joined(separator: "\n") + "\n"
        }
        t += "\nCHAPTERS\n"
        t += chapters.isEmpty ? "MISSING: \(chapterProblem ?? "none.") Chapters go in the description, so they are left out of it.\n"
            : "Already in the description above, in the form YouTube reads.\n"
        return t
    }
}
