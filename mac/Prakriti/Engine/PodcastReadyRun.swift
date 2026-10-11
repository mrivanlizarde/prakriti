import Foundation

// Running the podcast-ready chain and writing its package: the passes ffmpeg makes, each measured,
// and the files read back before the checklist says anything about them. The chain and the words
// are in PodcastReady.swift; this file only runs them.

/// What the mastering made: an MP3 with no tag yet, and what was measured on the way.
struct PodcastMaster: Sendable {
    var untagged: URL
    var normalizationType: String
    var talkLUFS: Double?
    var talkLRA: Double?
    var corrected: Bool
    var gainPasses: Int
    var expectedDuration: Double
    var clock: EpisodeClock
    var lufs: Double
    var truePeak: Double
    var lra: Double
}

extension Pipeline {
    /// The podcast-ready audio, in five kinds of pass over the recording:
    /// 1. the talk's loudness as recorded (or the episode's own first pass, when it was just made);
    /// 2. the talk rendered once, through the high-pass, noise reduction if chosen, the compressor
    ///    and the layout at 44.1 kHz, to a float WAV in the staging folder (float, because a talk
    ///    brought to -20 LUFS has peaks over 0 dBFS), measured as it is written;
    /// 3. with an intro or outro, the whole program measured;
    /// 4. the gain before the first limiter, measured until loudnorm's own correction is under
    ///    0.2 LU, so the second pass raises it evenly ("linear") and the last limiter barely works;
    /// 5. the MP3, then measured: a true peak over -1 or a loudness off by more than 0.5 makes it
    ///    once more with the limits lowered by the excess (and says so).
    func masterPodcastReady(file: URL, duration: Double, program base: Mastering.Program, staging: URL,
                            setup: PodcastReadySetup, knownTalkLUFS: Double?) async throws -> PodcastMaster {
        let settings = setup.settings
        let channels = settings.channels
        let target = PodcastMastering.target
        var talkProgram = base
        talkProgram.channels = channels
        talkProgram.intro = nil
        talkProgram.outro = nil

        // 1. The talk as recorded.
        var talkLUFS = knownTalkLUFS
        if talkLUFS == nil {
            let pass = try await tool(.podcastAudio, tools.ffmpeg, ["-hide_banner", "-nostats"]
                                      + Mastering.pass(file: file.path, program: talkProgram, loudness: PodcastMastering.measure())
                                      + ["-f", "null", "-"], duration: duration)
            talkLUFS = Measure.loudnorm(stderr: pass.stderr)?.inputLUFS
        }
        guard let rawLUFS = talkLUFS, rawLUFS.isFinite else {
            throw PipelineFailure(step: .podcastAudio, reason: "The talk's loudness could not be measured, so no podcast-ready audio was made.")
        }

        // 2. The processed talk, rendered once.
        let wav = staging.appending(path: ".podcast-talk.wav")
        defer { try? FileManager.default.removeItem(at: wav) }
        let chain = PodcastMastering.talkChain(pregain: PodcastMastering.pregain(talk: rawLUFS), channels: channels, noiseReduction: settings.noiseReduction)
        let render = try await tool(.podcastAudio, tools.ffmpeg, ["-y", "-hide_banner", "-nostats"]
                                    + Mastering.pass(file: file.path, program: talkProgram, loudness: chain + ",ebur128=peak=true:framelog=verbose")
                                    + ["-c:a", "pcm_f32le", wav.path], captureStdout: false, duration: duration)
        guard let talk = Measure.ebur128(stderr: render.stderr) else {
            throw PipelineFailure(step: .podcastAudio, reason: "The processed talk could not be measured, so no podcast-ready audio was made.",
                                  detail: Subprocess.tail(render.stderr))
        }

        // The intro and outro, each at the processed talk's loudness.
        let intro = try await piece(options.introPath, role: "intro", duration: duration)
        let outro = try await piece(options.outroPath, role: "outro", duration: duration)
        let introPiece = intro.map { Mastering.Piece(path: $0.path, gainDB: Self.matchingGain(talk: talk.integratedLUFS, piece: $0.lufs)) }
        let outroPiece = outro.map { Mastering.Piece(path: $0.path, gainDB: Self.matchingGain(talk: talk.integratedLUFS, piece: $0.lufs)) }
        func program(_ tail: String) -> [String] {
            PodcastMastering.program(talk: wav.path, intro: introPiece, outro: outroPiece, channels: channels, tail: tail)
        }
        let talkParts = base.talk(duration: duration)
        let clock = EpisodeClock(intro: intro?.duration ?? 0, segments: talkParts)
        let expected = (intro?.duration ?? 0) + talkParts.reduce(0) { $0 + $1.length } + (outro?.duration ?? 0)

        // 3. The whole program's loudness, when an intro or outro joins the talk.
        var programLUFS = talk.integratedLUFS
        if intro != nil || outro != nil {
            let pass = try await tool(.podcastAudio, tools.ffmpeg, ["-hide_banner", "-nostats"] + program(PodcastMastering.measure()) + ["-f", "null", "-"], duration: duration)
            guard let whole = Measure.loudnorm(stderr: pass.stderr)?.inputLUFS else {
                throw PipelineFailure(step: .podcastAudio, reason: "The episode with its intro and outro could not be measured, so no podcast-ready audio was made.")
            }
            programLUFS = whole
        }

        let mp3 = staging.appending(path: ".podcast-untagged.mp3")
        var preLimit = PodcastMastering.preLimit, finalLimit = PodcastMastering.finalLimit
        var allowance = PodcastMastering.encoderAllowance
        var corrected = false
        var passes = 0
        while true {
            // 4. The gain before the first limiter, until the even raise left to loudnorm is small.
            let aim = target + allowance
            var gain = aim - programLUFS + 0.5
            var measured: Measure.LoudnormPass?
            for _ in 0..<5 {
                passes += 1
                let pass = try await tool(.podcastAudio, tools.ffmpeg, ["-hide_banner", "-nostats"]
                                          + program(PodcastMastering.gainStage(gain, preLimit: preLimit) + "," + PodcastMastering.measure())
                                          + ["-f", "null", "-"], duration: duration)
                guard let m = Measure.loudnorm(stderr: pass.stderr), let i = m.inputLUFS else {
                    throw PipelineFailure(step: .podcastAudio, reason: "The podcast-ready audio could not be measured, so it was not made.",
                                          detail: Subprocess.tail(pass.stderr))
                }
                measured = m
                if abs(aim - i) <= PodcastMastering.gainTolerance { break }
                // The limiter takes back part of every dB added, so step past the difference.
                gain += (aim - i) * 1.6
            }
            guard let measured else { throw PipelineFailure(step: .podcastAudio, reason: "The podcast-ready audio could not be measured.") }

            // 5. The MP3, with no tag (Prakriti writes its own), then measured.
            let encode = try await tool(.podcastAudio, tools.ffmpeg, ["-y", "-hide_banner", "-nostats"]
                                        + program(PodcastMastering.gainStage(gain, preLimit: preLimit) + ","
                                                  + PodcastMastering.finish(measured: measured, allowance: allowance, channels: channels, finalLimit: finalLimit))
                                        + ["-c:a", "libmp3lame", "-b:a", "\(settings.bitrate)k", "-id3v2_version", "0", "-write_xing", "1", mp3.path],
                                        captureStdout: false, duration: duration)
            let leveling = Measure.loudnorm(stderr: encode.stderr)?.normalizationType ?? ""
            let made = try await measureFinished(mp3, step: .podcastAudio, duration: duration)
            let over = made.truePeak - PodcastMastering.peakAim
            let off = made.lufs - target
            if !corrected && (over > 0 || abs(off) > 0.5) {
                // Once, with the limits lowered by the excess and the aim moved by the miss.
                corrected = true
                if over > 0 { preLimit -= over + 0.2; finalLimit -= over + 0.2 }
                if abs(off) > 0.3 { allowance -= off }
                log?.write("\(file.lastPathComponent): podcast-ready audio measured " + String(format: "%.2f LUFS, true peak %.2f dBTP", made.lufs, made.truePeak)
                           + "; made again with the limits at \(Mastering.number(preLimit)) and \(Mastering.number(finalLimit)) dBFS.")
                continue
            }
            return PodcastMaster(untagged: mp3, normalizationType: leveling, talkLUFS: rawLUFS, talkLRA: nil, corrected: corrected, gainPasses: passes,
                                 expectedDuration: expected, clock: clock, lufs: made.lufs, truePeak: made.truePeak, lra: made.lra)
        }
    }

    /// Writes the podcast-ready folder from an untagged MP3: the tagged MP3 named for the show and
    /// the episode, the captions (.srt and .vtt) timed to it, the text file, and the upload checklist,
    /// every line measured or read back from the file. `transcriptFolder` holds transcript.json.
    func packagePodcastReady(untagged: URL, into folder: URL, setup: PodcastReadySetup, written: WrittenPackage?,
                             transcriptFolder: URL?, clock: EpisodeClock, applyLexicon: Bool, expectedDuration: Double,
                             normalizationType: String, talkLUFS: Double?, corrected: Bool, madeAt: Date) async throws -> PodcastReadyRecord {
        let fm = FileManager.default
        let settings = setup.settings, facts = setup.facts
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = PodcastPackage.baseName(settings: settings, facts: facts)
        let mp3 = folder.appending(path: base + ".mp3")
        let duration = expectedDuration

        // The artwork, only when it passes Apple's rules.
        let artwork = settings.artworkPath.map { ArtworkCheck.check(URL(fileURLWithPath: $0)) }
        var artData: (Data, String)?
        if let artwork, artwork.passes, let path = settings.artworkPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            artData = (data, artwork.mime)
        }
        let chapterPlan = PodcastPackage.chapters(written?.chapters ?? [], duration: duration)
        let title = facts.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var contents = ID3.Contents(title: title.isEmpty ? "\(facts.label) \(PodcastPackage.year(facts.recordedAt) ?? "")".trimmingCharacters(in: .whitespaces) : title)
        contents.artist = settings.hostName.isEmpty ? nil : settings.hostName
        contents.album = settings.showName.isEmpty ? nil : settings.showName
        contents.year = PodcastPackage.year(facts.recordedAt)
        contents.comment = PodcastPackage.comment(facts: facts, written: written)
        contents.track = facts.episodeNumber
        contents.artwork = artData.map { (data: $0.0, mime: $0.1) }
        contents.chapters = chapterPlan.chapters
        var intended = ["TIT2", "TCON"]
        if contents.artist != nil { intended.append("TPE1") }
        if contents.album != nil { intended.append("TALB") }
        if contents.year != nil { intended.append("TDRC") }
        if contents.comment != nil { intended.append("COMM") }
        if contents.track != nil { intended.append("TRCK") }
        if contents.artwork != nil { intended.append("APIC") }
        if !contents.chapters.isEmpty { intended.append("CTOC") }
        do {
            try ID3.write(contents, audioFrom: untagged, to: mp3)
        } catch {
            throw PipelineFailure(step: .podcastPackage, reason: "The podcast-ready MP3 could not be written.", detail: error.localizedDescription)
        }

        // The captions, timed to this file.
        var captions: (count: Int, first: Double, lastEnd: Double)?
        var captionsProblem: String?
        if let transcriptFolder, let data = try? Data(contentsOf: transcriptFolder.appending(path: TranscriptFiles.asHeard)),
           let sentences = EpisodeTranscript.sentences(json: data) {
            let cues = EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: applyLexicon).cues
            do {
                try EpisodeTranscript.srt(cues).write(to: folder.appending(path: base + ".srt"), atomically: true, encoding: .utf8)
                try EpisodeTranscript.vtt(cues).write(to: folder.appending(path: base + ".vtt"), atomically: true, encoding: .utf8)
            } catch {
                throw PipelineFailure(step: .podcastPackage, reason: "The captions could not be written.", detail: error.localizedDescription)
            }
            if let first = cues.first, let last = cues.last {
                captions = (cues.count, first.start, cues.map(\.end).max() ?? last.end)
                if !zip(cues, cues.dropFirst()).allSatisfy({ $0.start <= $1.start }) { captionsProblem = "The captions are not in time order." }
                if (captions?.lastEnd ?? 0) > duration + 0.5 { captionsProblem = "The last caption ends after the episode does." }
            } else {
                captions = (0, 0, 0)
                captionsProblem = "The transcript has no words."
            }
        }

        let fileName = mp3.lastPathComponent
        try PodcastPackage.episodeText(settings: settings, facts: facts, written: written, fileName: fileName, chapters: chapterPlan.chapters, madeAt: madeAt)
            .write(to: folder.appending(path: PodcastPackage.textName), atomically: true, encoding: .utf8)

        // Measured and read back from the file itself.
        let loudness = try await measureFinished(mp3, step: .podcastPackage, duration: duration)
        let probe = try await tool(.podcastPackage, tools.ffprobe, ["-v", "error", "-select_streams", "a:0", "-show_entries",
                                                                    "stream=sample_rate,channels,bit_rate:format=duration,bit_rate", "-of", "json", mp3.path],
                                   duration: duration)
        let stream = Measure.audioStream(json: probe.stdout)
        var tailDecodes = true
        do {
            _ = try await tool(.podcastPackage, tools.ffmpeg, ["-v", "error", "-sseof", "-5", "-i", mp3.path, "-f", "null", "-"], captureStdout: false, duration: duration)
        } catch let failure as PipelineFailure {
            tailDecodes = false
            log?.write("\(facts.fileName): the podcast-ready MP3's tail did not decode. \(failure.detail ?? "")")
        }
        let tag = ID3.read(mp3)
        let bytes = ((try? fm.attributesOfItem(atPath: mp3.path))?[.size] as? NSNumber)?.int64Value ?? 0
        let chapterProblem: String? = if !chapterPlan.chapters.isEmpty, let tag { PodcastPackage.chapterProblem(tag, duration: stream?.duration ?? duration) } else { chapterPlan.problem }
        let measured = PodcastPackage.Measured(lufs: loudness.lufs, truePeak: loudness.truePeak, lra: loudness.lra,
                                               normalizationType: normalizationType, sampleRate: stream?.sampleRate, bitrateKbps: stream?.bitrateKbps,
                                               channels: stream?.channels, duration: stream?.duration, expectedDuration: expectedDuration, bytes: bytes,
                                               tailDecodes: tailDecodes, tag: tag, intended: intended, artwork: artwork, chapterProblem: chapterProblem,
                                               chaptersWritten: tag?.chapters.count ?? 0, captions: captions, captionsProblem: captionsProblem)
        let lines = PodcastPackage.checklist(measured, settings: settings, facts: facts, written: written)
        try PodcastPackage.checklistText(lines, facts: facts, fileName: fileName, madeAt: madeAt)
            .write(to: folder.appending(path: PodcastPackage.checklistName), atomically: true, encoding: .utf8)
        return PodcastReadyRecord(fileName: fileName, integratedLUFS: loudness.lufs, truePeak: loudness.truePeak,
                                  loudnessRange: measured.lra, normalizationType: normalizationType, sampleRate: stream?.sampleRate ?? 0,
                                  bitrateKbps: stream?.bitrateKbps ?? settings.bitrate, channels: stream?.channels ?? 0, duration: stream?.duration ?? 0,
                                  expectedDuration: expectedDuration, bytes: bytes, talkLUFS: talkLUFS, talkLRA: nil, corrected: corrected, captions: captions?.count ?? 0,
                                  chapters: tag?.chapters.count ?? 0, checklist: lines, madeAt: madeAt,
                                  fingerprint: PodcastPackage.fingerprint(settings: settings, facts: facts, written: written))
    }

    /// A finished MP3's loudness, true peak and loudness range, by loudnorm's meter, which reports them
    /// to the hundredth. Reason: ebur128 prints one decimal, and on 10 Oct it printed "-1.0 dBTP" for a
    /// file loudnorm measured at -0.98, over Apple's line, which the checklist would have passed.
    func measureFinished(_ file: URL, step: PipelineStep, duration: Double) async throws -> (lufs: Double, truePeak: Double, lra: Double) {
        let check = try await tool(step, tools.ffmpeg, ["-hide_banner", "-nostats", "-i", file.path, "-af", PodcastMastering.measure(), "-f", "null", "-"], duration: duration)
        guard let m = Measure.loudnorm(stderr: check.stderr), let lufs = m.inputLUFS, let peak = Double(m.inputTP), let lra = Double(m.inputLRA) else {
            throw PipelineFailure(step: step, reason: "The podcast-ready MP3 was made, but its loudness could not be measured.", detail: Subprocess.tail(check.stderr))
        }
        return (lufs, peak, lra)
    }

    /// "-16.02 LUFS, true peak -1.32 dBTP, loudness range 4.7 LU, raised evenly. Checklist: 2 missing, 15 passed."
    static func podcastLine(_ record: PodcastReadyRecord) -> String {
        String(format: "%.2f LUFS, true peak %.2f dBTP, loudness range %.1f LU, %@. ", record.integratedLUFS, record.truePeak, record.loudnessRange,
               record.normalizationType == "linear" ? "raised evenly" : "leveled moment to moment")
            + "Checklist: \(record.summary.lowercasedFirst)."
    }
}
