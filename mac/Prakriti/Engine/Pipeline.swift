import Foundation

// The pipeline in Swift: engine v0's `processFile`, ported rule for rule (engine/prakriti.mjs).
// It knows nothing about the store or the window: it takes a file and a folder to write into,
// reports each step as it goes, and returns what it measured. The app applies that to the
// recording (PipelineRunner). The rules it keeps, each with its reason:
//
// - A new file is not a finished recording (Readiness).
// - Under 60 seconds is a test: filed, nothing made, no notice.
// - Sound check first. The 14 Sep class was recorded silent and nobody knew for 24 days. Loudest
//   point at or below -60 dB, or no audio track: Needs a decision, nothing made.
// - Coverage check after transcription: the transcript must reach within 120 s of the end. A
//   filter once dropped 80% of a tape and returned fluent text; Parakeet dropped the last 85 s of
//   a clip in our own test.
// - Mastering keeps v0's two bug fixes (see Mastering below), then the MP3 is measured, and its
//   tail decoded, rather than trusted.
// - Outputs never go into the shared iCloud folder (the runner checks the folder it passes in).

/// The steps, in order. `title` is what the recording page lists; `doing` is what the status line
/// says while it runs ("Working on Sun 13 Sep: making the episode audio"). Never "Processing".
enum PipelineStep: String, CaseIterable, Sendable {
    case complete, sound, speechAudio, transcript, coverage, episode, loudness, report

    var title: String {
        switch self {
        case .complete: "Checked the file is complete"
        case .sound: "Sound check"
        case .speechAudio: "Audio for the transcript"
        case .transcript: "Transcript"
        case .coverage: "Coverage check"
        case .episode: "Episode audio"
        case .loudness: "Loudness check"
        case .report: "Report"
        }
    }

    var doing: String {
        switch self {
        case .complete: "Checking the file is complete"
        case .sound: "Checking the sound"
        case .speechAudio: "Preparing the audio for the transcript"
        case .transcript: "Writing the transcript"
        case .coverage: "Checking the transcript reaches the end"
        case .episode: "Making the episode audio"
        case .loudness: "Measuring the episode audio"
        case .report: "Writing the report"
        }
    }
}

/// A step that could not finish, with one plain sentence for Ivan and the technical detail for the log.
struct PipelineFailure: Error, Sendable {
    let step: PipelineStep
    let reason: String
    var detail: String?
}

/// What to make and the numbers the rules use. Defaults are engine v0's.
struct PipelineOptions: Sendable {
    /// How long a file's size must hold still before work starts (v0: 60 s).
    var stableWait: Duration = .seconds(60)
    /// Shorter than this is a test (v0: 60 s).
    var testUnder: Double = 60
    /// A loudest point at or below this is no usable sound (v0: -60 dB).
    var silentAtOrBelow: Double = -60
    /// The transcript must reach within this many seconds of the end (v0: 120 s).
    var coverageGap: Double = 120
    /// The episode's loudness, and the ceiling its true peak must stay at or under.
    var loudnessTarget: Double = -16
    var peakCeiling: Double = -1

    var makeEpisode = true
    var makeTranscript = true
    var makeReport = true
    /// An "Ask me first" folder: check the file is complete and has sound, make nothing, and wait
    /// for Ivan. A silent recording is still a Needs a decision the same day (the 14 Sep lesson).
    var checksOnly = false

    /// The steps this run will take, in order. The checks always run.
    var plannedSteps: [PipelineStep] {
        var steps: [PipelineStep] = [.complete, .sound]
        if checksOnly { return steps }
        if makeTranscript { steps += [.speechAudio, .transcript, .coverage] }
        if makeEpisode { steps += [.episode, .loudness] }
        if makeReport { steps.append(.report) }
        return steps
    }
}

/// What a run measured and made.
struct PipelineResult: Sendable {
    enum Outcome: Sendable, Equatable {
        /// Made everything asked for: ready for Ivan's yes.
        case ready
        /// Under 60 s: filed as a test, nothing made.
        case test
        /// No usable sound: needs a decision, nothing made.
        case silent
        /// A step could not finish.
        case failed
        /// Stopped because Prakriti quit or the run was cancelled.
        case stopped
        /// Checks only ("Ask me first"): complete and has sound, nothing made, waiting for Ivan.
        case checked
    }

    var outcome: Outcome = .failed
    /// One plain sentence for the recording page and the list.
    var reason = ""
    var steps: [RunStep] = []
    var duration: Double?
    var sizeBytes: Int64 = 0
    var hasAudio: Bool?
    var volume: Measure.Volume?
    var inputLUFS: Double?
    var output: Measure.Loudness?
    var episodeDuration: Double?
    /// loudnorm's own word for how it worked on the second pass: "linear" is the good one.
    var normalizationType: String?
    var transcriptReaches: Double?
    var wordCount: Int?
    var coverageOK: Bool?
    /// Set only when something was made in it.
    var outputFolder: URL?
    var files: [String] = []
    var seconds: Double = 0
}

struct PipelineProgress: Sendable {
    let steps: [RunStep]
    let current: PipelineStep?
    let duration: Double?
    /// Set on the progress report where a notice belongs.
    var moment: PipelineMoment?
}

/// The two points in a run where Ivan hears about it (engine v0's order): the file is complete
/// and long enough not to be a test (New Recording Found), and the sound is good (Started).
enum PipelineMoment: Sendable, Equatable {
    case fileReady
    case soundOK
}

/// The mastering chain, kept exactly as engine v0 runs it, because two bugs live in its details.
///
/// - The limiter MUST have `level=disabled`. Its default "auto level" re-normalizes to 0 dBFS
///   after limiting, which shipped a +2.2 dBFS peak on the first test (8 Oct).
/// - Mono mix and sample rate are set INSIDE the filter chain, before the limiter. As output
///   options ffmpeg applies them after it, and resampling after a limiter put the peak back over
///   0 dBFS (second test, 8 Oct).
///
/// Two passes: the first measures, the second applies loudnorm in linear mode with those numbers.
/// The second pass aims 0.6 LU above the target because the limiter takes some loudness back
/// (v0: target -16, second pass -15.4). The loudnorm true-peak target and the limiter sit 0.5 dB
/// under the ceiling (v0: -1.5 dBTP and 0.84 for a -1 dBFS ceiling), leaving room for the overshoot
/// MP3 encoding adds.
enum Mastering {
    static let limiterAllowance = 0.6
    static let peakMargin = 0.5

    /// "-16", "-15.4", "0.84": the way v0 writes its numbers into the filter.
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return String(format: "%g", rounded)
    }

    static func peakTarget(ceiling: Double) -> Double { ceiling - peakMargin }

    /// The limiter's linear ceiling for a dB ceiling: -1.5 dB is 0.84.
    static func limiterLevel(ceiling: Double) -> Double { pow(10, peakTarget(ceiling: ceiling) / 20) }

    static func firstPass(target: Double, ceiling: Double) -> String {
        "aformat=channel_layouts=mono,aresample=48000,loudnorm=I=\(number(target)):TP=\(number(peakTarget(ceiling: ceiling))):LRA=11:print_format=json"
    }

    static func secondPass(target: Double, ceiling: Double, measured m: Measure.LoudnormPass) -> String {
        "aformat=channel_layouts=mono,aresample=48000,loudnorm=I=\(number(target + limiterAllowance)):TP=\(number(peakTarget(ceiling: ceiling))):LRA=11:"
            + "measured_I=\(m.inputI):measured_TP=\(m.inputTP):measured_LRA=\(m.inputLRA):measured_thresh=\(m.inputThresh):"
            + "offset=\(m.targetOffset):linear=true:print_format=json,"
            + "alimiter=limit=\(number(limiterLevel(ceiling: ceiling))):level=disabled:attack=5:release=50"
    }
}

/// Runs the steps for one file.
struct Pipeline: Sendable {
    let tools: ToolPaths
    let options: PipelineOptions
    let log: AppLog?

    init(tools: ToolPaths = .standard, options: PipelineOptions = PipelineOptions(), log: AppLog?) {
        self.tools = tools
        self.options = options
        self.log = log
    }

    /// Every tool gets a time limit: ten minutes plus the recording's own length. A hung tool must
    /// end as Couldn't finish, never hold the queue forever.
    private func limit(_ duration: Double?) -> Duration {
        .seconds(600 + Int((duration ?? 0).rounded(.up)))
    }

    func run(file: URL, outputFolder: URL, label: String,
             progress: @escaping @Sendable (PipelineProgress) async -> Void) async -> PipelineResult {
        let clock = ContinuousClock()
        let started = clock.now
        let name = file.lastPathComponent
        var result = PipelineResult()
        var steps = options.plannedSteps.map { RunStep(name: $0.title, state: .waiting) }
        var current: PipelineStep?
        var stepStarted = clock.now

        func index(_ step: PipelineStep) -> Int? { steps.firstIndex { $0.name == step.title } }
        func emit(_ moment: PipelineMoment? = nil) async {
            result.steps = steps
            await progress(PipelineProgress(steps: steps, current: current, duration: result.duration, moment: moment))
        }
        func begin(_ step: PipelineStep) async {
            current = step
            stepStarted = clock.now
            if let i = index(step) { steps[i].state = .running }
            await emit()
        }
        func elapsed() -> Double {
            let d = clock.now - stepStarted
            return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
        }
        func finish(_ step: PipelineStep, _ detail: String?, state: StepState = .done) async {
            let seconds = elapsed()
            if let i = index(step) {
                steps[i].state = state
                steps[i].seconds = seconds
                steps[i].detail = detail
            }
            log?.write("\(name): \(step.title) \(state == .done ? "done" : "stopped") in \(String(format: "%.1f", seconds)) s." + (detail.map { " " + $0 } ?? ""))
            current = nil
            await emit()
        }
        func skipTheRest() {
            for i in steps.indices where steps[i].state == .waiting { steps[i].state = .skipped }
        }
        func total() -> Double {
            let d = clock.now - started
            return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
        }

        do {
            // 1. Is the file complete?
            await begin(.complete)
            let ready = try await Readiness(tools: tools, stableWait: options.stableWait).waitUntilReady(file, log: log)
            result.duration = ready.duration
            result.hasAudio = ready.hasAudio
            result.sizeBytes = ready.sizeBytes
            let stable = Int(options.stableWait.components.seconds)
            await finish(.complete, (ready.waitedForICloud ? "Downloaded from iCloud. " : "")
                         + "Opens, its size held steady for \(stable) s, and its last seconds play.")

            // 2. Under 60 seconds is a test.
            if ready.duration < options.testUnder {
                skipTheRest()
                result.outcome = .test
                result.reason = "Under 60 seconds, so it was filed as a test. Nothing was made and no notice was sent."
                await emit()
                result.seconds = total()
                return result
            }

            await emit(.fileReady)

            // 3. Sound check: the whole audio track, fast (about 2 s per hour).
            await begin(.sound)
            var volume = Measure.Volume(max: -.infinity, mean: -.infinity)
            if ready.hasAudio {
                let output = try await tool(.sound, tools.ffmpeg, ["-hide_banner", "-nostats", "-i", file.path, "-vn", "-af", "volumedetect", "-f", "null", "-"],
                                            duration: ready.duration)
                volume = Measure.volume(stderr: output.stderr)
            }
            result.volume = volume
            guard ready.hasAudio, volume.max > options.silentAtOrBelow else {
                let loudest = ready.hasAudio ? "Loudest point \(Self.db(volume.max))." : "The file has no audio track."
                await finish(.sound, loudest + " Stopped here.", state: .failed)
                skipTheRest()
                result.outcome = .silent
                result.reason = ready.hasAudio
                    ? "No usable sound: the loudest point is \(Self.db(volume.max)). Nothing was made from it."
                    : "No usable sound: the file has no audio track. Nothing was made from it."
                await emit()
                result.seconds = total()
                return result
            }
            await finish(.sound, "Loudest point \(Self.db(volume.max)), average \(Self.db(volume.mean)).")
            if options.checksOnly {
                result.outcome = .checked
                result.reason = "It is complete and has sound. Nothing is made until you choose Make Outputs."
                result.seconds = total()
                await emit()
                return result
            }
            await emit(.soundOK)

            try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
            result.outputFolder = outputFolder
            let speech = outputFolder.appending(path: "speech.wav")
            defer { try? FileManager.default.removeItem(at: speech) }

            // 4. Mono 16 kHz audio, then the transcript (Parakeet), then the coverage check.
            if options.makeTranscript {
                await begin(.speechAudio)
                _ = try await tool(.speechAudio, tools.ffmpeg, ["-y", "-v", "error", "-i", file.path, "-vn", "-ac", "1", "-ar", "16000", speech.path],
                                   captureStdout: false, duration: ready.duration)
                await finish(.speechAudio, "Mono, 16 kHz.")

                await begin(.transcript)
                _ = try await tool(.transcript, tools.parakeet, [speech.path, "--output-dir", outputFolder.path, "--output-format", "all",
                                                                 "--output-template", "transcript"],
                                   captureStdout: false, duration: ready.duration)
                guard let srt = try? String(contentsOf: outputFolder.appending(path: "transcript.srt"), encoding: .utf8),
                      let text = try? String(contentsOf: outputFolder.appending(path: "transcript.txt"), encoding: .utf8) else {
                    throw PipelineFailure(step: .transcript, reason: "Parakeet finished but wrote no transcript.")
                }
                let words = Measure.wordCount(text)
                result.wordCount = words
                await finish(.transcript, "\(Format.number(words)) words.")

                await begin(.coverage)
                let reaches = Measure.lastCueEnd(srt: srt)
                let gap = ready.duration - reaches
                result.transcriptReaches = reaches
                result.coverageOK = gap <= options.coverageGap
                await finish(.coverage, result.coverageOK == true
                             ? "Reaches \(Format.timecode(reaches)) of \(Format.timecode(ready.duration))."
                             : "Stops at \(Format.timecode(reaches)) of \(Format.timecode(ready.duration)). The last \(Format.length(gap)) has no words.")
            }

            // 5. The episode audio: two-pass loudness, mono MP3 128k (Apple Podcasts spec).
            if options.makeEpisode {
                let mp3 = outputFolder.appending(path: "episode.mp3")
                await begin(.episode)
                let first = try await tool(.episode, tools.ffmpeg, ["-hide_banner", "-nostats", "-i", file.path, "-vn", "-af",
                                                                    Mastering.firstPass(target: options.loudnessTarget, ceiling: options.peakCeiling),
                                                                    "-f", "null", "-"], duration: ready.duration)
                guard let measured = Measure.loudnorm(stderr: first.stderr) else {
                    throw PipelineFailure(step: .episode, reason: "The loudness could not be measured, so no episode audio was made.",
                                          detail: Subprocess.tail(first.stderr))
                }
                result.inputLUFS = measured.inputLUFS
                let second = try await tool(.episode, tools.ffmpeg, ["-y", "-hide_banner", "-nostats", "-i", file.path, "-vn", "-af",
                                                                     Mastering.secondPass(target: options.loudnessTarget, ceiling: options.peakCeiling, measured: measured),
                                                                     "-ar", "48000", "-c:a", "libmp3lame", "-b:a", "128k", mp3.path],
                                            captureStdout: false, duration: ready.duration)
                result.normalizationType = Measure.loudnorm(stderr: second.stderr)?.normalizationType
                await finish(.episode, "Mono MP3, 128 kbps, from \(measured.inputI) LUFS. " + Self.levelingLine(result.normalizationType))

                // 6. Measure what was made, rather than trust it, and decode its tail.
                await begin(.loudness)
                let check = try await tool(.loudness, tools.ffmpeg, ["-hide_banner", "-nostats", "-i", mp3.path, "-af", "ebur128=peak=true:framelog=verbose",
                                                                     "-f", "null", "-"], duration: ready.duration)
                guard let loudness = Measure.ebur128(stderr: check.stderr) else {
                    throw PipelineFailure(step: .loudness, reason: "The episode audio was made, but its loudness could not be measured.",
                                          detail: Subprocess.tail(check.stderr))
                }
                result.output = loudness
                _ = try await tool(.loudness, tools.ffmpeg, ["-v", "error", "-sseof", "-5", "-i", mp3.path, "-f", "null", "-"],
                                   captureStdout: false, duration: ready.duration)
                let probe = try await tool(.loudness, tools.ffprobe, ["-v", "error", "-show_entries", "format=duration:stream=codec_type", "-of", "json", mp3.path],
                                           duration: ready.duration)
                let made = Measure.probe(json: probe.stdout)?.duration
                result.episodeDuration = made
                guard let made, abs(made - ready.duration) <= 1.0 else {
                    throw PipelineFailure(step: .loudness, reason: "The episode audio is not the length of the recording, so it cannot be trusted.",
                                          detail: "episode \(made.map { String($0) } ?? "unreadable") s, recording \(ready.duration) s")
                }
                await finish(.loudness, "\(Format.lufs(loudness.integratedLUFS)), peak \(Format.dbfs(loudness.truePeakDBFS)). Plays to its end (\(Format.timecode(made))).")
            }

            // 7. The report Ivan reads before he listens.
            if options.makeReport {
                await begin(.report)
                result.seconds = total()
                result.outcome = .ready
                try? FileManager.default.removeItem(at: speech)
                result.files = Self.madeFiles(in: outputFolder)
                let markdown = Report.markdown(file: file, label: label, result: result, options: options, steps: steps, madeAt: Date())
                do {
                    try markdown.write(to: outputFolder.appending(path: "REPORT.md"), atomically: true, encoding: .utf8)
                } catch {
                    throw PipelineFailure(step: .report, reason: "The report could not be written.", detail: error.localizedDescription)
                }
                await finish(.report, "Written to REPORT.md, beside the episode.")
            }

            try? FileManager.default.removeItem(at: speech)
            result.files = Self.madeFiles(in: outputFolder)
            result.outcome = .ready
            result.reason = readyReason(result)
            result.seconds = total()
            await emit()
            return result
        } catch let failure as PipelineFailure {
            if let detail = failure.detail { log?.write("\(name): \(failure.step.title) failed. \(detail)") }
            if let i = index(failure.step), steps[i].state == .running || steps[i].state == .waiting {
                steps[i].state = .failed
                steps[i].seconds = elapsed()
                steps[i].detail = failure.reason
            }
            skipTheRest()
            result.outcome = .failed
            result.reason = failure.reason
        } catch is CancellationError {
            if let current, let i = index(current) { steps[i].state = .failed; steps[i].detail = "Stopped." }
            skipTheRest()
            result.outcome = .stopped
            result.reason = "Stopped before it finished. The original is untouched."
        } catch {
            if let current, let i = index(current) { steps[i].state = .failed; steps[i].detail = error.localizedDescription }
            skipTheRest()
            result.outcome = .failed
            result.reason = "Stopped: \(error.localizedDescription)"
            log?.write("\(name): failed. \(error)")
        }
        result.files = result.outputFolder.map(Self.madeFiles(in:)) ?? []
        result.seconds = total()
        await emit()
        return result
    }

    /// Runs one tool for a step, turning a tool's failure into one plain sentence.
    private func tool(_ step: PipelineStep, _ executable: URL, _ arguments: [String], captureStdout: Bool = true,
                      duration: Double?) async throws -> ToolOutput {
        do {
            return try await Subprocess.run(executable, arguments, captureStdout: captureStdout, timeout: limit(duration))
        } catch let error as ToolError {
            let reason: String = switch error.kind {
            case .missing:
                "\(Self.toolName(error.tool)) is not installed where Prakriti looks for it, so it stopped while \(step.doing.lowercasedFirst)."
            case .timedOut:
                "\(step.doing) took longer than \(Int(limit(duration).components.seconds / 60)) minutes, so it was stopped."
            case .failed, .couldNotStart:
                "Stopped while \(step.doing.lowercasedFirst): \(Self.toolName(error.tool)) reported a problem. The details are in the log."
            }
            throw PipelineFailure(step: step, reason: reason, detail: error.logLine)
        }
    }

    private func readyReason(_ result: PipelineResult) -> String {
        var made: [String] = []
        if options.makeEpisode { made.append("Episode audio") }
        if options.makeTranscript { made.append("transcript") }
        var reason = made.isEmpty ? "The checks passed." : made.joined(separator: " and ") + (made.count > 1 ? " are ready." : " is ready.")
        if result.coverageOK == false, let reaches = result.transcriptReaches, let duration = result.duration {
            reason += " The transcript stops at \(Format.timecode(reaches)) of \(Format.timecode(duration)): listen to the end before trusting it."
        } else {
            reason += " Speakers are not checked yet."
        }
        return reason
    }

    /// How loudnorm raised the loudness, in plain words. "linear" means evenly, like turning one
    /// knob. "dynamic" means it rode the level moment to moment, because raising it evenly would
    /// have pushed the peaks past the ceiling; SCOPE 7.11 calls that worth a listen (finding E23).
    /// On 10 Oct the port found every studio talk lands in dynamic mode, as engine v0's did unseen.
    static func levelingLine(_ normalizationType: String?) -> String {
        switch normalizationType {
        case "linear": "Loudness raised evenly."
        case nil: ""
        default: "Loudness leveled moment to moment, not evenly, so it is worth a listen."
        }
    }

    static func toolName(_ executable: String) -> String {
        switch executable {
        case "parakeet-mlx": "Parakeet, the transcription tool,"
        default: executable
        }
    }

    /// "-3.4 dB", "-91 dB", "silent".
    static func db(_ value: Double) -> String {
        guard value.isFinite else { return "silent (no signal)" }
        return value == value.rounded() ? String(format: "%.0f dB", value) : String(format: "%.1f dB", value)
    }

    static func madeFiles(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
    }
}
