import Foundation

/// REPORT.md: what Ivan reads before he listens. Engine v0's report, with the steps and their
/// timings added. Numbers and file names only: never transcript text.
enum Report {
    static func markdown(file: URL, label: String, result: PipelineResult, options: PipelineOptions,
                         steps: [RunStep], madeAt: Date) -> String {
        let duration = result.duration.map { Format.timecode($0) } ?? "?"
        let size = String(format: "%.2f GB", Double(result.sizeBytes) / 1e9)
        var rows: [(String, String)] = [("Recording", "\(duration), \(size)")]

        if let volume = result.volume {
            var sound = "average \(Pipeline.db(volume.mean)), loudest \(Pipeline.db(volume.max))"
            if let lufs = result.inputLUFS { sound += "; loudness \(String(format: "%.2f", lufs)) LUFS" }
            rows.append(("Sound in", sound))
        }
        if options.makeEpisode {
            let measured = result.output.map { "\(String(format: "%.1f", $0.integratedLUFS)) LUFS, true peak \(String(format: "%.1f", $0.truePeakDBFS)) dBFS" } ?? "not measured"
            let mode = result.normalizationType.map {
                $0 == "linear" ? "; loudness raised evenly (loudnorm linear mode)"
                    : "; loudness leveled moment to moment, not evenly (loudnorm \($0) mode: raising it evenly would have pushed the peaks past the ceiling), so listen for the level riding up and down"
            } ?? ""
            rows.append(("Episode audio", "`episode.mp3`, mono 128 kbps, \(measured) (target \(Mastering.number(options.loudnessTarget)) LUFS, "
                         + "peak at or under \(Mastering.number(options.peakCeiling)))\(mode)"))
        }
        if options.makeTranscript {
            var transcript = "`transcript.txt`, `.srt`, `.vtt`, \(result.wordCount.map(String.init) ?? "?") words"
            if let reaches = result.transcriptReaches, let length = result.duration {
                let gap = length - reaches
                transcript += result.coverageOK == true
                    ? "; reaches \(Format.timecode(reaches)) of \(Format.timecode(length))"
                    : "; STOPS at \(Format.timecode(reaches)) of \(Format.timecode(length)); the last \(Format.timecode(gap)) is missing (it may be silence; listen before trusting it)"
            }
            rows.append(("Transcript", transcript))
        }

        var text = "# \(label): \(file.lastPathComponent)\n\n"
        text += "Made by Prakriti for Mac on \(stamp(madeAt)) in \(Format.timecode(result.seconds)). **Nothing has been published.**\n\n"
        text += "| | |\n|---|---|\n"
        for (name, value) in rows { text += "| \(name) | \(value) |\n" }

        let timed = steps.filter { $0.state == .done && $0.seconds != nil }
        if !timed.isEmpty {
            text += "\n## Steps\n\n| Step | Time | Result |\n|---|---|---|\n"
            for step in timed {
                text += "| \(step.name) | \(String(format: "%.1f s", step.seconds ?? 0)) | \(step.detail ?? "") |\n"
            }
        }

        text += """

        ## Before this goes anywhere
        1. **Listen.** Start, end, and anywhere the transcript shows someone other than the teacher.
        2. **Other voices and names.** Prakriti does not yet label speakers or mute names. If a student
           speaks or is named, do not publish until Serenity's rule is decided (PLAN.md).
        3. **Claims.** Check any income or health claim and any offer that may be closed (enrollment has
           been paused since January).
        4. Spellings: "Yoga Marga" and Sanskrit terms are often misheard; search the transcript.

        """
        return text
    }

    /// Local time, sortable, as engine v0 writes it: "2026-10-10 14:02:11".
    private static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
