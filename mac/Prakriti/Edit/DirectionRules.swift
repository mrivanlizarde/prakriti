import Foundation

// The rules table (v2 part M9c, research-edit-engine.md 3.2: "rules first"): the common phrases of a direction read with no
// model, instantly, offline and the same way every time. A direction is split into clauses (at full stops, commas, semicolons,
// question marks, "but" and new lines); each clause is matched against the table, and a clause is read when a rule matched it and
// at most one word of substance is left over. A clause no rule reads goes to the planning model (`Direction`), which may only
// answer in the vocabulary's fields.
//
// Who appears, hiding, consent and publishing are never read as an edit: a clause about them changes nothing and is answered
// with "People are chosen under People." (or the publishing sentence).

enum DirectionRules {
    struct Result: Equatable, Sendable {
        var fields = DirectionFields()
        var unread: [String] = []
        var said: [String] = []
    }

    /// One row of the table: a pattern (case-insensitive) and what it sets. `$n` in the action is the pattern's number group.
    struct Rule: Sendable {
        let pattern: String
        let set: @Sendable (inout DirectionFields, [String]) -> Void
    }

    /// The words that name each focus tag.
    static let tagPatterns: [BeatTag: String] = [
        .motivating: #"\bmotivat(?:ing|ional|ion|e)\b|\binspir(?:ing|ational|e)\b|\buplifting\b"#,
        .enlightening: #"\benlighten(?:ing|ment)?\b|\binsight(?:ful|s)?\b|\bwisdom\b|\bdeep(?:er)? (?:ideas|teaching)\b"#,
        .practical: #"\bpractical\b|\bhow[- ]tos?\b|\btips\b|\bactionable\b"#,
        .humor: #"\bfunny\b|\bhumou?r(?:ous)?\b|\bjokes?\b|\blight[- ]hearted\b"#,
        .philosophy: #"\bphilosoph(?:y|ical)\b"#,
        .technique: #"\btechniques?\b|\balignment\b|\bthe poses?\b|\basanas?\b"#,
        .personal: #"\bpersonal\b"#,
        .story: #"\b(?:the )?stories\b|\banecdotes?\b"#,
    ]

    private static func tag(_ t: BeatTag) -> @Sendable (inout DirectionFields, [String]) -> Void {
        { f, _ in f.focus[t.rawValue] = DirectionFields.focusWeight }
    }

    /// The table, longest phrases first where two could match the same words.
    static let rules: [Rule] = [
        // Length (research 3.2: "under N minutes", "about 3 minutes").
        Rule(pattern: #"\b(?:under|less than|at most|no (?:more|longer) than|shorter than|max(?:imum)?(?: of)?|within|about|around|roughly|keep it (?:to|under))\s+(\d+(?:\.\d+)?|[a-z]+(?:[ -][a-z]+)?)\s*(?:min(?:ute)?s?|m)\b"#) { f, g in
            if let n = DirectionRules.number(g[0]) { f.targetSeconds = n * 60 }
        },
        Rule(pattern: #"\b(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|thirty|forty|fifty|sixty)[ -]min(?:ute)?s?(?: long)?(?: or (?:less|shorter))?\b"#) { f, g in
            if let n = DirectionRules.number(g[0]) { f.targetSeconds = n * 60 }
        },
        Rule(pattern: #"\b(?:under|less than|at most|about|around)\s+(\d+)\s*(?:sec(?:ond)?s?|s)\b"#) { f, g in
            if let n = DirectionRules.number(g[0]), n >= 20 { f.targetSeconds = n }
        },
        Rule(pattern: #"\bhighlights?\b|\bonly the (?:best|strongest) (?:moments|parts|bits)\b"#) { f, _ in f.targetSeconds = 180 },
        // Cuts (before pace, so "faster cuts" is cuts, not pace).
        Rule(pattern: #"\b(?:more|faster|quicker|frequent|more frequent|lots of|plenty of|extra) (?:jump )?cuts\b|\bcut (?:more|faster)\b|\bmore edits\b"#) { f, _ in f.cutDensity += 1 },
        Rule(pattern: #"\b(?:fewer|less|slower|less frequent|not so many|not as many) (?:jump )?cuts\b|\bcut less\b|\bfewer edits\b"#) { f, _ in f.cutDensity -= 1 },
        // Punch-ins (before the styles, so "softer zooms" is punch-ins, not Calm).
        Rule(pattern: #"\b(?:no|without|zero|without any|turn off(?: the)?) (?:zooms?|punch[- ]?ins?|zooming)\b|\bstay wide\b"#) { f, _ in f.punchIns = .off },
        Rule(pattern: #"\b(?:more|bigger|stronger|punchier) (?:zooms?|punch[- ]?ins?)\b|\bzoom (?:in )?more\b"#) { f, _ in f.punchIns = .punchy },
        Rule(pattern: #"\b(?:fewer|gentler|gentle|subtle|subtler|smaller|softer|less) (?:zooms?|punch[- ]?ins?)\b|\bzoom less\b"#) { f, _ in f.punchIns = .subtle },
        // Words on screen.
        Rule(pattern: #"\b(?:no|without) (?:text|words|titles?)(?: on (?:the )?screen)?\b"#) { f, _ in f.text = .off },
        Rule(pattern: #"\b(?:fewer|less) (?:words|text)(?: on (?:the )?screen)?\b"#) { f, _ in f.text = .subtle },
        Rule(pattern: #"\bmore (?:words|text)(?: on (?:the )?screen)?\b"#) { f, _ in f.text = .bold },
        // Captions.
        Rule(pattern: #"\b(?:no|without) (?:captions|subtitles)\b"#) { f, _ in f.captionsBurned = false },
        Rule(pattern: #"\b(?:add |burn(?:ed)?(?: in)? |with |show )?(?:captions|subtitles)(?: on (?:the )?(?:screen|picture|video))?(?: burned in)?\b"#) { f, _ in f.captionsBurned = true },
        // The hook.
        Rule(pattern: #"\b(?:no|without(?: a)?) (?:teaser|hook|cold open)\b"#) { f, _ in f.hook = false },
        Rule(pattern: #"\b(?:start|open|begin) (?:with|on) (?:the )?(?:strongest|best|most powerful) (?:line|moment|quote)\b|\b(?:a |with a )?(?:teaser|hook|cold open)\b"#) { f, _ in f.hook = true },
        // Style.
        Rule(pattern: #"\b(?:more |high[- ]?|higher |with )?energ(?:etic|y|ise|ize|izing|ising)\b|\bpunchier\b|\bhype\b|\bupbeat\b"#) { f, _ in f.style = .energetic },
        Rule(pattern: #"\b(?:more )?calm(?:er)?\b|\bgentler?\b|\bmeditative\b|\bquieter\b"#) { f, _ in f.style = .calm },
        Rule(pattern: #"\b(?:like a |as a )?documentary\b|\bstory first\b|\btell (?:it as )?(?:a|the) story\b"#) { f, _ in f.style = .story },
        Rule(pattern: #"\bhouse style\b|\bclear style\b|\bjust clear\b"#) { f, _ in f.style = .clear },
        // Pace.
        Rule(pattern: #"\b(?:much )?(?:faster|quicker|snappier|tighter)\b|\bspeed (?:it )?up\b|\bpick up the pace\b|\bmore pace\b|\bbrisk(?:er)?\b"#) { f, _ in f.pace += 1 },
        Rule(pattern: #"\b(?:slower|slow (?:it )?down|let it breathe|more room|more space|relaxed|unhurried|take (?:its|your) time)\b"#) { f, _ in f.pace -= 1 },
        // Leave out and keep whole (a topic after the verb; a tag word reads as that tag).
        Rule(pattern: #"\b(?:take out|cut out|cut|remove|skip|drop|leave out|lose|without) (?:the |that |all the |any )?(?:part|bit|section|story|stories|moment|tangent|segment)s? (?:about|on|where|with) (.+)"#) { f, g in
            DirectionRules.add(topic: g[0], to: &f.avoidTopics, tags: &f.avoid)
        },
        Rule(pattern: #"\bkeep (?:the |all the )?(.+?) (?:whole|intact|complete|uncut|in full)\b"#) { f, g in
            f.keepWhole = DirectionFields.join(f.keepWhole, [DirectionRules.topic(g[0])])
        },
        // Focus: the tag words, wherever they are in a clause.
        Rule(pattern: tagPatterns[.motivating]!, set: tag(.motivating)),
        Rule(pattern: tagPatterns[.enlightening]!, set: tag(.enlightening)),
        Rule(pattern: tagPatterns[.practical]!, set: tag(.practical)),
        Rule(pattern: tagPatterns[.humor]!, set: tag(.humor)),
        Rule(pattern: tagPatterns[.philosophy]!, set: tag(.philosophy)),
        Rule(pattern: tagPatterns[.technique]!, set: tag(.technique)),
        Rule(pattern: tagPatterns[.personal]!, set: tag(.personal)),
        Rule(pattern: tagPatterns[.story]!, set: tag(.story)),
        Rule(pattern: #"\bfocus on (.+)"#) { f, g in
            // Whatever follows "focus on" that is more than filler (the tag words are already read) is a topic.
            let t = DirectionRules.topic(g[0])
            if DirectionRules.substantive(t) { f.focusTopics = DirectionFields.join(f.focusTopics, [t]) }
        },
    ]

    /// Words that carry nothing on their own, so a clause read by a rule is not sent to the model for them.
    static let filler: Set<String> = ["a", "an", "the", "and", "or", "of", "on", "in", "to", "it", "its", "is", "are", "be", "that", "this", "these", "those",
                                      "parts", "part", "bits", "moments", "sections", "focus", "make", "please", "more", "less", "very", "much", "bit",
                                      "little", "lot", "keep", "with", "so", "really", "just", "only", "video", "edit", "cut", "overall", "feel", "feels",
                                      "should", "let", "lets", "let's", "can", "you", "we", "i", "want", "would", "like", "also", "too", "for", "all",
                                      "make", "it's", "go", "frequent", "version", "something", "some", "where", "which", "there", "here", "about",
                                      "talk", "one", "way", "using", "use", "any", "whole", "stuff", "things", "thing", "them"]

    /// Who appears, hiding and consent: never an edit.
    static let peoplePattern = #"\bstudents?\b|\bblur(?:red|ring|s)?\b|\bconsent\b|\breleases?\b|\bprivacy\b|\bfaces?\b|\bwho (?:appears|is in|shows up|is shown)\b|\b(?:show|hide|include|remove|cut|leave out|keep|take out|drop) (?:\w+ )?(?:people|person|persons|everyone|everybody|class|audience|room|participants?)\b"#
    /// Publishing: never an edit.
    static let publishingPattern = #"\b(?:publish(?:ed|ing)?|post(?:ed|ing)? (?:it|this)|upload(?:ed|ing)?|put it (?:on|up)|share (?:it )?on|send (?:it )?to|go live)\b"#

    static func read(_ prompt: String) -> Result {
        var result = Result()
        for clause in clauses(prompt) {
            let lower = clause.lowercased()
            if lower.range(of: peoplePattern, options: .regularExpression) != nil {
                if !result.said.contains(Direction.peopleSentence) { result.said.append(Direction.peopleSentence) }
                continue
            }
            if lower.range(of: publishingPattern, options: .regularExpression) != nil {
                if !result.said.contains(Direction.publishingSentence) { result.said.append(Direction.publishingSentence) }
                continue
            }
            var leftover = lower
            var matched = false
            for rule in rules {
                guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else { continue }
                let range = NSRange(leftover.startIndex..., in: leftover)
                let matches = regex.matches(in: leftover, range: range)
                guard !matches.isEmpty else { continue }
                for m in matches {
                    var groups: [String] = []
                    for g in 1..<max(1, m.numberOfRanges) {
                        if let r = Range(m.range(at: g), in: leftover) { groups.append(String(leftover[r])) }
                    }
                    rule.set(&result.fields, groups.isEmpty ? [""] : groups)
                }
                matched = true
                // What a rule read is taken out of the clause, so the leftover shows what no rule read.
                leftover = regex.stringByReplacingMatches(in: leftover, range: NSRange(leftover.startIndex..., in: leftover), withTemplate: " ")
            }
            let rest = leftover.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init).filter { !filler.contains($0) }
            if !matched || rest.count > 1 {
                result.unread.append(clause)
            }
        }
        result.fields.pace = max(-2, min(2, result.fields.pace))
        result.fields.cutDensity = max(-2, min(2, result.fields.cutDensity))
        return result
    }

    /// The clauses of a direction: split at sentence ends, commas, semicolons, new lines and "but".
    static func clauses(_ prompt: String) -> [String] {
        let marked = prompt.replacingOccurrences(of: #"\s+but\s+"#, with: ". ", options: [.regularExpression, .caseInsensitive])
        return marked.components(separatedBy: CharacterSet(charactersIn: ".,;!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// "10", "ten", "twelve", "1.5", "twenty five" as a number.
    static func number(_ text: String) -> Double? {
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        if let n = Double(t) { return n }
        let units = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
                     "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
                     "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "ninety": 90, "a": 1, "half": 0.5]
        let parts = t.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        guard !parts.isEmpty else { return nil }
        var total = 0.0
        for p in parts {
            guard let v = units[p] else { return nil }
            total += Double(v)
        }
        return total > 0 ? total : nil
    }

    static func mentions(_ text: String, _ tag: BeatTag) -> Bool {
        guard let pattern = tagPatterns[tag] else { return false }
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// More than filler words.
    static func substantive(_ text: String) -> Bool {
        text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init).contains { !filler.contains($0) }
    }

    /// A topic as Ivan wrote it, without the words around it ("the story about the car" is "the car").
    static func topic(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        for lead in ["the ", "a ", "an ", "that ", "all the "] where t.lowercased().hasPrefix(lead) { t = String(t.dropFirst(lead.count)) }
        return t
    }

    static func add(topic text: String, to topics: inout [String], tags: inout [String]) {
        let t = topic(text)
        if let tag = BeatTag.allCases.first(where: { mentions(t, $0) }) {
            if !tags.contains(tag.rawValue) { tags.append(tag.rawValue) }
        } else if !t.isEmpty {
            topics = DirectionFields.join(topics, [t])
        }
    }
}
