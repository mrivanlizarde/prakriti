import Foundation

/// The transcript's files. Parakeet writes .txt, .srt, .vtt and .json; Prakriti adds .md (the
/// words in paragraphs, each with its time, for reading), applies the word list, and keeps only the
/// formats chosen on the Outputs screen. transcript.json is always kept while the transcript is on:
/// it is Parakeet's own words, as heard, with their times (the record the word list never touches).
enum TranscriptFiles {
    /// Every file name the transcript can leave, in the order the report lists them.
    static func fileName(_ format: TranscriptFormat) -> String { "transcript.\(format.rawValue)" }
    static let asHeard = "transcript.json"

    struct Cue: Equatable, Sendable {
        let start: Double
        let end: Double
        let text: String
    }

    /// "00:15:46,160" or "00:15:46.160" (or "15:46.160", as some .vtt files write it) in seconds.
    static func seconds(_ stamp: String) -> Double {
        let parts = stamp.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0.0) { $0 * 60 + (Double($1) ?? 0) }
    }

    /// The cues of an .srt (or .vtt), in order.
    static func cues(srt: String) -> [Cue] {
        srt.components(separatedBy: "\n\n").compactMap { block in
            let lines = block.components(separatedBy: "\n")
            guard let timing = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
            let stamps = lines[timing].components(separatedBy: "-->")
            guard stamps.count == 2 else { return nil }
            let end = stamps[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? stamps[1]
            let text = lines[(timing + 1)...].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Cue(start: seconds(stamps[0]), end: seconds(end), text: text)
        }
    }

    /// The transcript for reading: a heading, one line on where it came from, then paragraphs, each
    /// starting with its time (in the original recording, or in the episode once it follows it). A pause of 2 seconds or more, or a minute of
    /// talk ending a sentence, starts a new paragraph.
    static func markdown(cues: [Cue], label: String, fileName: String, wordListApplied: Bool, followsEpisode: Bool = false) -> String {
        var text = "# \(label): transcript\n\n"
        text += "From \(fileName), transcribed on this Mac by Parakeet"
        text += wordListApplied ? ", with the Yoga Marga word list applied." : "."
        text += followsEpisode
            ? " Speakers are not labeled yet. Times are from the start of the episode, and what was taken out of the episode is left out here too.\n"
            : " Speakers are not labeled yet. Times are from the start of the original recording.\n"
        var paragraph: [Cue] = []
        func flush() {
            guard let first = paragraph.first else { return }
            text += "\n**\(Format.timecode(first.start))** " + paragraph.map(\.text).joined(separator: " ") + "\n"
            paragraph = []
        }
        for cue in cues {
            if let last = paragraph.last, let first = paragraph.first {
                let pause = cue.start - last.end
                let long = last.end - first.start >= 60 && last.text.last.map { ".?!".contains($0) } == true
                if pause >= 2 || long { flush() }
            }
            paragraph.append(cue)
        }
        flush()
        return text
    }
}
