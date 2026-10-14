import Foundation

/// REPORT.md: what Ivan reads before he listens. Engine v0's report, with the steps and their
/// timings added. Numbers and file names only, never transcript text; the one exception is the
/// word list's fixes, which are the list's own words ("Yoga Marka" now reads "Yoga Marga" at 5:20).
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
            var made = ""
            if let length = result.episodeDuration { made += "; \(Format.timecode(length)) long" }
            if options.trimSilence, let start = result.trimmedStart, let end = result.trimmedEnd {
                made += start < 0.05 && end < 0.05 ? ", no silence to trim at either end"
                    : String(format: ", %.1f s of silence trimmed at the start and %.1f s at the end", start, end)
            }
            if let intro = result.introDuration { made += String(format: ", intro `%@` (%.1f s) before it", name(options.introPath), intro) }
            if let outro = result.outroDuration { made += String(format: ", outro `%@` (%.1f s) after it", name(options.outroPath), outro) }
            rows.append(("Episode audio", "`episode.mp3`, \(options.channels.title.lowercased()) 128 kbps, \(measured) (target \(Mastering.number(options.loudnessTarget)) LUFS, "
                         + "peak at or under \(Mastering.number(options.peakCeiling)))\(made)\(mode)"))
            if let parts = result.parts, let summary = result.edits.summary {
                let kept = parts.reduce(0) { $0 + $1.length }
                rows.append(("Your edits", "\(summary) The episode keeps \(Format.timecode(kept)) of \(duration) (times in the original recording)"))
            }
        }
        if options.makeTranscript {
            let formats = TranscriptFormat.allCases.filter(options.transcriptFormats.contains)
            let named = formats.enumerated().map { $0.offset == 0 ? "`\(TranscriptFiles.fileName($0.element))`" : "`.\($0.element.rawValue)`" }
            var transcript = (named.isEmpty ? "" : named.joined(separator: ", ") + "; ")
                + "\(result.wordCount.map(String.init) ?? "?") words heard"
            if let reaches = result.transcriptReaches, let length = result.duration {
                let gap = length - reaches
                transcript += gap <= options.coverageGap
                    ? "; reaches \(Format.timecode(reaches)) of \(Format.timecode(length))"
                    : "; STOPS at \(Format.timecode(reaches)) of \(Format.timecode(length)); the last \(Format.timecode(gap)) is missing (it may be silence; listen before trusting it)"
            }
            if !result.relistened.isEmpty {
                transcript += "; \(Format.count(result.relistened.count, "stretch", "stretches")) of speech with no words were transcribed again on their own ("
                    + TranscriptGaps.list(result.relistened) + "), \(Format.count(result.wordsFoundAgain, "word")) found"
            }
            if !result.transcriptGaps.isEmpty {
                transcript += "; NO WORDS for \(Format.count(result.transcriptGaps.count, "stretch", "stretches")) of speech at "
                    + TranscriptGaps.list(result.transcriptGaps) + " (listen there before trusting it)"
            }
            transcript += options.applyLexicon
                ? "; Yoga Marga word list: \(Format.count(result.corrections.count, "fix", "fixes"))"
                : "; the Yoga Marga word list was off"
            rows.append(("Transcript", transcript))
            // This report is copied into the approved folder, where transcript.json never goes, so
            // it says where the words as heard are rather than listing them among the files.
            rows.append(("Words as heard", "`\(TranscriptFiles.asHeard)`, every word with its time, is kept in the Outputs folder only. "
                         + "Approve never copies it: it keeps the words of anything taken out."))
        }
        if options.makeTranscript && options.writing != nil {
            // This report is copied into the approved folder, which gets show-notes.md but not the
            // JSON (it keeps the model's own answer, quotes that failed the check included).
            rows.append(("Titles, show notes and chapters", result.written.map {
                "`\(WrittenPackage.notesFileName)` (and `\(WrittenPackage.fileName)`, kept in the Outputs folder only). " + $0.stepLine
            } ?? "Not written. \(result.writingProblem ?? "")"))
        }
        if let setup = options.podcastReady {
            rows.append(("Podcast-ready episode", result.podcastReady.map { record in
                "`\(PodcastPackage.folderName)/\(record.fileName)`, \(setup.settings.channels.title.lowercased()) \(record.bitrateKbps) kbps, "
                    + "\(String(format: "%.1f", Double(record.sampleRate) / 1000)) kHz: " + Pipeline.podcastLine(record)
                    + " Its own chain: high-pass at 70 Hz, a gentle compressor, raised evenly to -16 LUFS, peaks limited. "
                    + "`\(PodcastPackage.checklistName)` lists every check, with its captions, `\(PodcastPackage.textName)` and `\(PodcastPackage.markdownName)` beside it"
            } ?? "Not made. \(result.podcastProblem ?? "")"))
        }

        var text = "# \(label): \(file.lastPathComponent)\n\n"
        text += "Made by Prakriti for Mac on \(stamp(madeAt)) in \(Format.timecode(result.seconds)). **Nothing has been published.**\n\n"
        text += "| | |\n|---|---|\n"
        for (name, value) in rows { text += "| \(name) | \(value) |\n" }

        if options.makeTranscript && options.applyLexicon && !result.corrections.isEmpty {
            text += "\n## Word list fixes\n\nThe Yoga Marga word list changed these in the .txt, .srt, .vtt and .md. "
                + "`\(TranscriptFiles.asHeard)`, in the Outputs folder only, keeps what was heard. Times are in the original recording."
                + (result.fixesLeftOut > 0
                   ? " \(Format.count(result.fixesLeftOut, "more fix", "more fixes")) fell in the parts taken out of the episode, so \(result.fixesLeftOut == 1 ? "it is" : "they are") in no file and not listed."
                   : "")
                + "\n\n| Now reads | Was heard as | At |\n|---|---|---|\n"
            for fix in result.corrections.prefix(60) {
                text += "| \(fix.written) | \(fix.heard) | \(fix.at.map { Format.timecode($0) } ?? "") |\n"
            }
            if result.corrections.count > 60 { text += "\n\(result.corrections.count - 60) more are not listed.\n" }
        }
        if options.makeTranscript && result.transcriptFollowsEpisode {
            let left = result.wordsLeftOut ?? 0
            text += "\nThe transcript files follow the episode: their times match `episode.mp3`"
                + (left > 0 ? ", and the \(Format.count(left, "word")) in the parts taken out are left out of them" : "")
                + ". `\(TranscriptFiles.asHeard)`, in the Outputs folder only, keeps every word as heard, timed from the start of the original recording.\n"
        }

        let timed = steps.filter { $0.state == .done && $0.seconds != nil }
        if !timed.isEmpty {
            text += "\n## Steps\n\n| Step | Time | Result |\n|---|---|---|\n"
            for step in timed {
                text += "| \(step.name) | \(String(format: "%.1f s", step.seconds ?? 0)) | \(step.detail ?? "") |\n"
            }
        }

        let spellings: String
        if options.makeTranscript && options.applyLexicon {
            spellings = (result.corrections.isEmpty ? "Spellings: the Yoga Marga word list found none of its known mis-hearings."
                         : "Spellings: the Yoga Marga word list fixed the known mis-hearings listed above.")
                + " Other names and Sanskrit terms can still be misheard; search the transcript."
        } else {
            spellings = "Spellings: \"Yoga Marga\" and Sanskrit terms are often misheard; search the transcript."
        }
        // Since v2 part M6c a make with the people check offers choices and names said aloud; without it, v1's line.
        let voicesLine = options.people != nil
            ? """
            2. **Other voices and names.** Choose who is in the episode, and Keep or Mute each name said aloud, in
               the People tab. Prakriti can miss a voice or a name, so listen too.
            """
            : """
            2. **Other voices and names.** Prakriti does not yet label speakers or mute names. If a student
               speaks or is named, do not publish until Serenity's rule is decided (PLAN.md).
            """
        text += """

        ## Before this goes anywhere
        1. **Listen.** Start, end, and anywhere the transcript shows someone other than the teacher.
        \(voicesLine)
        3. **Claims.** Check any income or health claim and any offer that may be closed (enrollment has
           been paused since January).
        4. \(spellings)

        """
        return text
    }

    private static func name(_ path: String?) -> String {
        path.map { ($0 as NSString).lastPathComponent } ?? ""
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
