import Foundation

/// The Yoga Marga word list (SCOPE 7.7): known mis-hearings of the school's name, its Sanskrit terms
/// and its lineage names, corrected after transcription, on this Mac, with no network call.
///
/// - Parakeet's own words are always kept in transcript.json, as heard. The word list changes only
///   the .txt, .srt, .vtt and .md, and never a cue's number or timing (a test checks every timing
///   line is untouched).
/// - Only whole words match: "yoga markets" is left alone, and so is "Yoga Mārga".
/// - Every fix is counted and listed with its time in REPORT.md, so a wrong fix can be found. Reason:
///   "the yoga market" could one day be meant, and a silent fix would hide that.
/// - Phonetic matching of low-confidence words (SCOPE's second stage) is not built; only the known
///   variants below are fixed.
enum Lexicon {
    struct Entry: Sendable, Hashable {
        /// How it is written.
        let written: String
        /// How the transcription has heard it, in any capitalization. The written form itself is
        /// listed when only its capitalization goes wrong ("yoga marga").
        let heard: [String]
        /// What it is, in a few words, for the Outputs screen.
        let note: String
    }

    /// Seeded from SCOPE 7.7 (the studio files), plus what Parakeet wrote for the 13 Sep talk and for
    /// a spoken test sentence on 10 Oct ("Yakamarga", "Yoga Marka", "Krishna Macharya", "Patabi
    /// Joyce", "Ayengar", "Ayangar").
    static let entries: [Entry] = [
        Entry(written: "Yoga Marga",
              heard: ["yoga market", "yoga margot", "yoga margo", "yoga marka", "yoga marker", "yokamarga", "yakamarga", "yogamarga", "yoga marga"],
              note: "The school's name."),
        Entry(written: "pranayama", heard: ["pradayama"], note: "Breath practice."),
        Entry(written: "Samkhya", heard: ["sampia", "samkhya"], note: "A school of Indian philosophy."),
        Entry(written: "Krishnamacharya", heard: ["krishna macharya", "krishnamacharya"], note: "The teacher's lineage."),
        Entry(written: "Pattabhi Jois", heard: ["patabi joyce", "pattabhi joyce", "patabi jois", "pattabhi jois"], note: "The teacher's lineage."),
        Entry(written: "Iyengar", heard: ["ayengar", "ayangar", "iyengar"], note: "The teacher's lineage."),
    ]

    /// Words the list knows are right as they are, shown on the Outputs screen and never changed.
    static let keptAsWritten = ["Yoga Mārga School", "yin", "asana", "ahimsa", "YTT", "YMCT", "Gabriel", "Serenity"]

    /// One fix: what was heard, what it now says, and where (seconds from the start of the original
    /// recording, when the text has times).
    struct Correction: Sendable, Hashable {
        let heard: String
        let written: String
        var at: Double?
    }

    /// The list compiled once: one pattern per entry, its variants longest first, whole words only,
    /// any capitalization, a space or hyphen (or a line break inside a subtitle) between words.
    private static let patterns: [(entry: Entry, regex: NSRegularExpression)] = entries.compactMap { entry in
        let variants = entry.heard.sorted { $0.count > $1.count }.map { variant in
            variant.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "[\\s\\-]+")
        }
        let pattern = "(?<![\\p{L}\\p{N}])(?:" + variants.joined(separator: "|") + ")(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return (entry, regex)
    }

    /// Applies the list to plain text. Returns the corrected text and every fix, entry by entry.
    static func apply(_ text: String, at time: Double? = nil) -> (text: String, corrections: [Correction]) {
        var current = text
        var corrections: [Correction] = []
        for (entry, regex) in patterns {
            let ns = current as NSString
            let matches = regex.matches(in: current, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { continue }
            let result = NSMutableString(string: current)
            // Back to front, so earlier ranges stay valid; the fixes are then put back in reading order.
            var found: [Correction] = []
            for match in matches.reversed() {
                let heard = ns.substring(with: match.range)
                let written = casing(entry.written, like: heard)
                guard heard != written else { continue }
                result.replaceCharacters(in: match.range, with: written)
                found.append(Correction(heard: heard, written: written, at: time))
            }
            corrections += found.reversed()
            current = result as String
        }
        return (current, corrections)
    }

    /// Applies the list to an .srt or .vtt: only the text lines of each cue change. The numbers, the
    /// timing lines and the blank lines between cues stay byte for byte, so the timings cannot move.
    static func applyToSubtitles(_ subtitles: String) -> (text: String, corrections: [Correction]) {
        var blocks = subtitles.components(separatedBy: "\n\n")
        var corrections: [Correction] = []
        for index in blocks.indices {
            var lines = blocks[index].components(separatedBy: "\n")
            guard let timing = lines.firstIndex(where: { $0.contains("-->") }), timing + 1 < lines.count else { continue }
            let start = TranscriptFiles.seconds(lines[timing].components(separatedBy: "-->").first ?? "")
            let text = lines[(timing + 1)...].joined(separator: "\n")
            let fixed = apply(text, at: start)
            guard !fixed.corrections.isEmpty else { continue }
            lines.replaceSubrange((timing + 1)..., with: fixed.text.components(separatedBy: "\n"))
            blocks[index] = lines.joined(separator: "\n")
            corrections += fixed.corrections
        }
        return (blocks.joined(separator: "\n\n"), corrections)
    }

    /// "pranayama" at the start of a sentence reads "Pranayama". A name keeps its own capitals.
    private static func casing(_ written: String, like heard: String) -> String {
        guard let first = written.first, first.isLowercase, let heardFirst = heard.first, heardFirst.isUppercase else { return written }
        return first.uppercased() + written.dropFirst()
    }

    /// The fixes grouped for the report and the screen: "Yoga Marga" from "Yoga Marka" at 5:20, ...
    static func summary(_ corrections: [Correction]) -> [(written: String, items: [Correction])] {
        var order: [String] = []
        var groups: [String: [Correction]] = [:]
        for correction in corrections {
            let key = correction.written.lowercased()
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(correction)
        }
        return order.compactMap { key in
            guard let items = groups[key], let first = items.first else { return nil }
            let written = entries.first { $0.written.lowercased() == key }?.written ?? first.written
            return (written, items)
        }
    }
}
