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
//
// Milestone 4 added the outputs' settings, each made only when chosen: the silence trim, an intro
// and outro, mono or stereo, the transcript's formats and the Yoga Marga word list. Two rules came
// with them:
// - A make happens in a staging folder and replaces the recording's files only once it has
//   finished. A remake that stops halfway leaves the last good files as they were, and a remake
//   with the transcript turned off leaves no transcript behind (milestone 4's acceptance).
// - With the trim and the intro and outro off, the chain is still engine v0's string for string
//   (PipelineTests), so PipelineOptions() still makes v0's episode bit for bit.

/// The steps, in order. `title` is what the recording page lists; `doing` is what the status line
/// says while it runs ("Working on Sun 13 Sep: making the episode audio"). Never "Processing".
enum PipelineStep: String, CaseIterable, Sendable {
    case complete, sound, speechAudio, transcript, coverage, wordList, trim, edits, episode, loudness, podcastAudio, episodeTranscript, writing, podcastPackage, report

    var title: String {
        switch self {
        case .complete: "Checked the file is complete"
        case .sound: "Sound check"
        case .speechAudio: "Audio for the transcript"
        case .transcript: "Transcript"
        case .coverage: "Coverage check"
        case .wordList: "Word list"
        case .trim: "Silence at the start and end"
        case .edits: "Your trim and cuts"
        case .episode: "Episode audio"
        case .loudness: "Loudness check"
        case .podcastAudio: "Podcast-ready audio"
        case .podcastPackage: "Podcast-ready files"
        case .episodeTranscript: "Transcript matched to the episode"
        case .writing: "Titles, show notes and chapters"
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
        case .wordList: "Applying the Yoga Marga word list"
        case .trim: "Finding the silence at the start and end"
        case .edits: "Applying your trim and cuts"
        case .episode: "Making the episode audio"
        case .loudness: "Measuring the episode audio"
        case .podcastAudio: "Mastering the podcast-ready audio"
        case .podcastPackage: "Writing and checking the podcast-ready files"
        case .episodeTranscript: "Matching the transcript to the episode"
        case .writing: "Writing the titles, show notes and chapters"
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

    // The episode's settings. The defaults are engine v0's (no trim, mono, no intro or outro), so
    // PipelineOptions() still makes v0's episode bit for bit; the app passes the Outputs screen's.
    var trimSilence = false
    /// Full paths of the intro and outro audio, or nil.
    var introPath: String?
    var outroPath: String?
    var channels: AudioChannels = .mono

    // The transcript's settings. The defaults are engine v0's three formats, with no word list.
    var transcriptFormats: Set<TranscriptFormat> = [.txt, .srt, .vtt]
    var applyLexicon = false

    /// Ivan's edits from the recording's page (milestone 5): where the episode starts and ends, and
    /// the sections cut out, on the original's clock. Empty: the episode is made as milestone 4 made it.
    var edits = EpisodeEdits()

    /// Titles, show notes and chapters (milestone 6): who writes them, or nil when they are not made.
    /// They are written from the transcript, so they are made only with it.
    var writing: WritingSetup?
    /// What the recording is, and whether Serenity is already known to be in it: the privacy lock.
    var kind: RecordingKind = .unknown
    var knownSerenity = false

    /// The podcast-ready episode (10 Oct): its settings and the facts it names, or nil when it is
    /// not made. It shares the episode's trim, cuts, intro and outro.
    var podcastReady: PodcastReadySetup?
    var makePodcastReady: Bool { podcastReady != nil }

    /// Anything taken out of the recording or added to it, so the episode's clock is not the
    /// original's and the transcript files are rewritten to follow the episode.
    var changesTheClock: Bool {
        trimSilence || !(introPath ?? "").isEmpty || !(outroPath ?? "").isEmpty || !edits.isEmpty
    }

    /// The steps this run will take, in order. The checks always run.
    var plannedSteps: [PipelineStep] {
        var steps: [PipelineStep] = [.complete, .sound]
        if checksOnly { return steps }
        if makeTranscript {
            steps += [.speechAudio, .transcript, .coverage]
            if applyLexicon { steps.append(.wordList) }
        }
        if makeEpisode || makePodcastReady {
            if trimSilence { steps.append(.trim) }
            if !edits.isEmpty { steps.append(.edits) }
        }
        if makeEpisode { steps += [.episode, .loudness] }
        if makePodcastReady { steps.append(.podcastAudio) }
        if (makeEpisode || makePodcastReady) && makeTranscript && changesTheClock { steps.append(.episodeTranscript) }
        if makeTranscript && writing != nil { steps.append(.writing) }
        if makePodcastReady { steps.append(.podcastPackage) }
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
    /// The part of the recording the episode keeps, once the silence at its start and end is
    /// trimmed. Nil when nothing was trimmed.
    var kept: Mastering.Span?
    /// Seconds of silence trimmed from the start and the end (0 when the trim found none).
    var trimmedStart: Double?
    var trimmedEnd: Double?
    /// The edits this make applied (milestone 5), and the parts of the original the episode kept
    /// because of them. Nil parts: no edits.
    var edits = EpisodeEdits()
    var parts: [Mastering.Span]?
    /// Where the original's moments play in the episode: the intro, then what was kept.
    var clock: EpisodeClock?
    /// The transcript files were rewritten to follow the episode, and how many words they lost.
    var transcriptFollowsEpisode = false
    var wordsLeftOut: Int?
    /// How many of the word list's fixes were in the parts taken out, so are in no file (and not
    /// in `corrections`, which then lists only the fixes in the files that follow the episode).
    var fixesLeftOut = 0
    var introDuration: Double?
    var outroDuration: Double?
    /// The word list's fixes, each with its time in the original recording.
    var corrections: [Lexicon.Correction] = []
    /// Set only when a make finished and its files are in it.
    var outputFolder: URL?
    var files: [String] = []
    /// Files an earlier make left that this one replaced or removed (a transcript turned off).
    var replaced: [String] = []
    var seconds: Double = 0
    /// The titles, show notes and chapters written and checked, or why they were not (milestone 6).
    var written: WrittenPackage?
    var writingProblem: String?
    /// The transcript says "Serenity": the recording is privacy locked from now on.
    var mentionsSerenity = false
    /// The podcast-ready episode as made and checked, or why it was not made (10 Oct).
    var podcastReady: PodcastReadyRecord?
    var podcastProblem: String?
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

    /// Mono (v0) or stereo, and 48 kHz, set inside the chain so both come before the limiter (bug 2).
    static func format(_ channels: AudioChannels) -> String {
        "aformat=channel_layouts=\(channels.rawValue),aresample=48000"
    }

    static func firstPassLoudness(target: Double, ceiling: Double) -> String {
        "loudnorm=I=\(number(target)):TP=\(number(peakTarget(ceiling: ceiling))):LRA=11:print_format=json"
    }

    static func secondPassLoudness(target: Double, ceiling: Double, measured m: Measure.LoudnormPass) -> String {
        "loudnorm=I=\(number(target + limiterAllowance)):TP=\(number(peakTarget(ceiling: ceiling))):LRA=11:"
            + "measured_I=\(m.inputI):measured_TP=\(m.inputTP):measured_LRA=\(m.inputLRA):measured_thresh=\(m.inputThresh):"
            + "offset=\(m.targetOffset):linear=true:print_format=json,"
            + "alimiter=limit=\(number(limiterLevel(ceiling: ceiling))):level=disabled:attack=5:release=50"
    }

    static func firstPass(target: Double, ceiling: Double, channels: AudioChannels = .mono) -> String {
        format(channels) + "," + firstPassLoudness(target: target, ceiling: ceiling)
    }

    static func secondPass(target: Double, ceiling: Double, measured m: Measure.LoudnormPass, channels: AudioChannels = .mono) -> String {
        format(channels) + "," + secondPassLoudness(target: target, ceiling: ceiling, measured: m)
    }

    /// A stretch of the recording, in seconds from its start.
    struct Span: Equatable, Sendable {
        let start: Double
        let end: Double
        var length: Double { end - start }
    }

    /// An intro or outro, and the gain that brings it to the talk's own loudness before the whole
    /// episode is leveled, so music recorded hot does not come out louder than the talk.
    struct Piece: Equatable, Sendable {
        let path: String
        let gainDB: Double
    }

    /// What the episode is made of: the recording (all of it, or the part kept after the trim), in
    /// mono or stereo, with an intro before it and an outro after it, joined end to end.
    struct Program: Equatable, Sendable {
        var kept: Span?
        var channels: AudioChannels = .mono
        var intro: Piece?
        var outro: Piece?
        /// Ivan's edits (milestone 5): the parts of the recording the episode keeps, in order, each
        /// faded in and out over 15 ms. Nil: `kept` (the silence trim) or the whole recording, and
        /// the chain is milestone 4's string for string.
        var parts: [Span]?

        /// The talk's parts, as the episode plays them.
        func talk(duration: Double) -> [Span] {
            parts ?? [kept ?? Span(start: 0, end: duration)]
        }
    }

    /// "1.183": trim points to the millisecond.
    static func time(_ seconds: Double) -> String { String(format: "%.3f", seconds) }

    /// The ffmpeg inputs and filters for one pass over the program, ending in `loudness` (a pass's
    /// loudnorm, or loudnorm and the limiter). Without an intro or outro this is engine v0's single
    /// `-af` chain, with the trim put first when there is one; with them, a filter graph joins the
    /// pieces (each in the same layout and rate) before the same loudness filters.
    static func pass(file: String, program: Program, loudness: String) -> [String] {
        let format = format(program.channels)
        if let parts = program.parts { return pass(file: file, parts: parts, program: program, loudness: loudness) }
        let trim = program.kept.map { "atrim=start=\(time($0.start)):end=\(time($0.end)),asetpts=PTS-STARTPTS," } ?? ""
        guard program.intro != nil || program.outro != nil else {
            return ["-i", file, "-vn", "-af", trim + format + "," + loudness]
        }
        var inputs: [String] = []
        var graph: [String] = []
        var labels: [String] = []
        func add(_ path: String, _ chain: String, _ label: String) {
            graph.append("[\(labels.count):a]\(chain)[\(label)]")
            inputs += ["-i", path]
            labels.append("[\(label)]")
        }
        if let intro = program.intro { add(intro.path, "\(format),volume=\(number(intro.gainDB))dB", "intro") }
        add(file, trim + format, "talk")
        if let outro = program.outro { add(outro.path, "\(format),volume=\(number(outro.gainDB))dB", "outro") }
        graph.append(labels.joined() + "concat=n=\(labels.count):v=0:a=1,\(loudness)[episode]")
        return inputs + ["-filter_complex", graph.joined(separator: ";"), "-map", "[episode]"]
    }

    /// One kept part: cut out of the recording, started at zero, faded in and out over 15 ms.
    static func part(_ span: Span) -> String {
        "atrim=start=\(time(span.start)):end=\(time(span.end)),asetpts=PTS-STARTPTS,"
            + "afade=t=in:st=0:d=\(time(EpisodeEdits.fade)),afade=t=out:st=\(time(max(0, span.length - EpisodeEdits.fade))):d=\(time(EpisodeEdits.fade))"
    }

    /// The pass with Ivan's edits: the recording is split into its kept parts, each cut and faded,
    /// joined end to end, set to the layout and 48 kHz (before the limiter, v0's bug 2), and joined
    /// to the intro and outro when there are any, before the same loudness filters.
    private static func pass(file: String, parts: [Span], program: Program, loudness: String) -> [String] {
        let format = format(program.channels)
        var inputs: [String] = []
        var graph: [String] = []
        var labels: [String] = []
        if let intro = program.intro {
            graph.append("[\(labels.count):a]\(format),volume=\(number(intro.gainDB))dB[intro]")
            inputs += ["-i", intro.path]
            labels.append("[intro]")
        }
        let talkInput = labels.count
        inputs += ["-i", file]
        if parts.count == 1, let only = parts.first {
            graph.append("[\(talkInput):a]\(part(only)),\(format)[talk]")
        } else {
            graph.append("[\(talkInput):a]asplit=\(parts.count)" + parts.indices.map { "[s\($0)]" }.joined())
            for (index, span) in parts.enumerated() { graph.append("[s\(index)]\(part(span))[p\(index)]") }
            graph.append(parts.indices.map { "[p\($0)]" }.joined() + "concat=n=\(parts.count):v=0:a=1,\(format)[talk]")
        }
        labels.append("[talk]")
        if let outro = program.outro {
            graph.append("[\(labels.count):a]\(format),volume=\(number(outro.gainDB))dB[outro]")
            inputs += ["-i", outro.path]
            labels.append("[outro]")
        }
        graph.append(labels.count == 1 ? "[talk]\(loudness)[episode]" : labels.joined() + "concat=n=\(labels.count):v=0:a=1,\(loudness)[episode]")
        return inputs + ["-filter_complex", graph.joined(separator: ";"), "-map", "[episode]"]
    }
}

/// Trimming the silence at the start and end of a recording. Conservative on purpose: only sound
/// under -50 dB for at least a second counts, and half a second is kept before the first sound and
/// after the last, so no word is clipped. Measured 10 Oct: the 13 Sep talk opens with 1.7 s under
/// -60 dB and runs to its last second; the 6 Sep talk opens with 3.4 s under -50 dB.
enum SilenceTrim {
    static let threshold = -50
    static let minimum = 1.0
    static let pad = 0.5
    /// A silence counts as the start's when it begins in the first 50 ms, and as the end's when it
    /// reaches within half a second of the end (a video's audio can stop a little before its
    /// picture does).
    static let startEdge = 0.05
    static let endEdge = 0.5

    static var filter: String { "aformat=channel_layouts=mono,silencedetect=noise=\(threshold)dB:d=\(Mastering.number(minimum))" }

    /// The part to keep, or nil when there is nothing to trim.
    static func kept(_ silences: [Measure.Silence], duration: Double) -> Mastering.Span? {
        var start = 0.0, end = duration
        if let lead = silences.first, lead.start <= startEdge, let leadEnd = lead.end {
            start = max(0, leadEnd - pad)
        }
        if let trail = silences.last, (trail.end ?? duration) >= duration - endEdge, trail.start > start {
            end = min(duration, trail.start + pad)
        }
        guard start > 0.01 || end < duration - 0.01, end - start >= 1 else { return nil }
        return Mastering.Span(start: start, end: end)
    }

    /// "Trimmed 1.2 s at the start; none at the end."
    static func line(start: Double, end: Double) -> String {
        func amount(_ s: Double) -> String { s < 0.05 ? "none" : String(format: "%.1f s", s) }
        if start < 0.05 && end < 0.05 { return "No silence to trim at either end." }
        return "Trimmed \(amount(start)) at the start; \(amount(end)) at the end."
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

            // Everything is made in a staging folder beside the outputs, and moves into the
            // recording's folder only when the whole make has finished. Reason: a remake that
            // stops halfway must leave the last good episode and transcript as they were.
            let staging = Self.stagingFolder(for: outputFolder)
            try? FileManager.default.removeItem(at: staging) // a make stopped by a quit leaves its unfinished files here
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }
            let speech = staging.appending(path: "speech.wav")

            // 4. Mono 16 kHz audio, then the transcript (Parakeet), the coverage check, the word list.
            if options.makeTranscript {
                await begin(.speechAudio)
                _ = try await tool(.speechAudio, tools.ffmpeg, ["-y", "-v", "error", "-i", file.path, "-vn", "-ac", "1", "-ar", "16000", speech.path],
                                   captureStdout: false, duration: ready.duration)
                await finish(.speechAudio, "Mono, 16 kHz.")

                await begin(.transcript)
                _ = try await tool(.transcript, tools.parakeet, [speech.path, "--output-dir", staging.path, "--output-format", "all",
                                                                 "--output-template", "transcript"],
                                   captureStdout: false, duration: ready.duration)
                try? FileManager.default.removeItem(at: speech)
                let srtFile = staging.appending(path: TranscriptFiles.fileName(.srt))
                guard var srt = try? String(contentsOf: srtFile, encoding: .utf8),
                      let text = try? String(contentsOf: staging.appending(path: TranscriptFiles.fileName(.txt)), encoding: .utf8) else {
                    throw PipelineFailure(step: .transcript, reason: "Parakeet finished but wrote no transcript.")
                }
                let words = Measure.wordCount(text)
                result.wordCount = words
                result.mentionsSerenity = Privacy.mentionsSerenity(text)
                await finish(.transcript, "\(Format.number(words)) words.")

                await begin(.coverage)
                let reaches = Measure.lastCueEnd(srt: srt)
                let gap = ready.duration - reaches
                result.transcriptReaches = reaches
                result.coverageOK = gap <= options.coverageGap
                await finish(.coverage, result.coverageOK == true
                             ? "Reaches \(Format.timecode(reaches)) of \(Format.timecode(ready.duration))."
                             : "Stops at \(Format.timecode(reaches)) of \(Format.timecode(ready.duration)). The last \(Format.length(gap)) has no words.")

                if options.applyLexicon {
                    await begin(.wordList)
                    let fixed = try Self.applyWordList(in: staging)
                    srt = fixed.srt
                    result.corrections = fixed.corrections
                    let fixes = Lexicon.summary(result.corrections)
                    await finish(.wordList, result.corrections.isEmpty ? "No known mis-hearings found."
                                 : "\(Format.count(result.corrections.count, "fix", "fixes")): "
                                    + fixes.map { "\($0.written) (\($0.items.count))" }.joined(separator: ", ") + ".")
                }
                try keepChosenFormats(in: staging, srt: srt, label: label, fileName: file.lastPathComponent)
            }

            // 5. The episode audio: the silence trim, two-pass loudness, the MP3 (Apple Podcasts spec).
            //    The trim and cuts are found first, for the episode and the podcast-ready episode alike.
            var program = Mastering.Program(kept: nil, channels: options.channels)
            if options.makeEpisode || options.makePodcastReady {
                if options.trimSilence {
                    await begin(.trim)
                    let scan = try await tool(.trim, tools.ffmpeg, ["-hide_banner", "-nostats", "-i", file.path, "-vn", "-af", SilenceTrim.filter, "-f", "null", "-"],
                                              duration: ready.duration)
                    program.kept = SilenceTrim.kept(Measure.silences(stderr: scan.stderr), duration: ready.duration)
                    result.kept = program.kept
                    result.trimmedStart = program.kept?.start ?? 0
                    result.trimmedEnd = program.kept.map { max(0, ready.duration - $0.end) } ?? 0
                    await finish(.trim, SilenceTrim.line(start: result.trimmedStart ?? 0, end: result.trimmedEnd ?? 0))
                }

                // Ivan's trim and cuts, on top of the silence trim: the parts the episode keeps.
                if !options.edits.isEmpty {
                    await begin(.edits)
                    if let problem = options.edits.problem(duration: ready.duration, silence: program.kept) {
                        throw PipelineFailure(step: .edits, reason: problem + " Nothing was made; change the trim or the cuts and make it again.")
                    }
                    let parts = options.edits.segments(duration: ready.duration, silence: program.kept)
                    program.parts = parts
                    result.edits = options.edits
                    result.parts = parts
                    let kept = parts.reduce(0) { $0 + $1.length }
                    await finish(.edits, (options.edits.summary.map { $0 + " " } ?? "")
                                 + "The episode keeps \(Format.timecode(kept)) of \(Format.timecode(ready.duration)).")
                }
            }
            if options.makeEpisode {
                let mp3 = staging.appending(path: "episode.mp3")
                await begin(.episode)
                // The intro and outro are checked first, so a missing file stops before minutes of work.
                let intro = try await piece(options.introPath, role: "intro", duration: ready.duration)
                let outro = try await piece(options.outroPath, role: "outro", duration: ready.duration)
                let target = options.loudnessTarget, ceiling = options.peakCeiling
                let talkPass = try await tool(.episode, tools.ffmpeg, ["-hide_banner", "-nostats"]
                                              + Mastering.pass(file: file.path, program: program, loudness: Mastering.firstPassLoudness(target: target, ceiling: ceiling))
                                              + ["-f", "null", "-"], duration: ready.duration)
                guard let talk = Measure.loudnorm(stderr: talkPass.stderr), let talkLUFS = talk.inputLUFS else {
                    throw PipelineFailure(step: .episode, reason: "The loudness could not be measured, so no episode audio was made.",
                                          detail: Subprocess.tail(talkPass.stderr))
                }
                result.inputLUFS = talk.inputLUFS
                var measured = talk
                if intro != nil || outro != nil {
                    program.intro = intro.map { Mastering.Piece(path: $0.path, gainDB: Self.matchingGain(talk: talkLUFS, piece: $0.lufs)) }
                    program.outro = outro.map { Mastering.Piece(path: $0.path, gainDB: Self.matchingGain(talk: talkLUFS, piece: $0.lufs)) }
                    result.introDuration = intro?.duration
                    result.outroDuration = outro?.duration
                    let whole = try await tool(.episode, tools.ffmpeg, ["-hide_banner", "-nostats"]
                                               + Mastering.pass(file: file.path, program: program, loudness: Mastering.firstPassLoudness(target: target, ceiling: ceiling))
                                               + ["-f", "null", "-"], duration: ready.duration)
                    guard let wholePass = Measure.loudnorm(stderr: whole.stderr) else {
                        throw PipelineFailure(step: .episode, reason: "The loudness of the episode with its intro and outro could not be measured, so no episode audio was made.",
                                              detail: Subprocess.tail(whole.stderr))
                    }
                    measured = wholePass
                }
                let second = try await tool(.episode, tools.ffmpeg, ["-y", "-hide_banner", "-nostats"]
                                            + Mastering.pass(file: file.path, program: program,
                                                             loudness: Mastering.secondPassLoudness(target: target, ceiling: ceiling, measured: measured))
                                            + ["-ar", "48000", "-c:a", "libmp3lame", "-b:a", "128k", mp3.path],
                                            captureStdout: false, duration: ready.duration)
                result.normalizationType = Measure.loudnorm(stderr: second.stderr)?.normalizationType
                await finish(.episode, "\(options.channels.title) MP3, 128 kbps, from \(talk.inputI) LUFS. "
                             + Self.piecesLine(intro: intro, outro: outro) + Self.levelingLine(result.normalizationType))

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
                // The intro, the talk (the parts kept after the trims and cuts) and the outro, end to end.
                let talkParts = program.talk(duration: ready.duration)
                result.clock = EpisodeClock(intro: intro?.duration ?? 0, segments: talkParts)
                let expected = (intro?.duration ?? 0) + talkParts.reduce(0) { $0 + $1.length } + (outro?.duration ?? 0)
                guard let made, abs(made - expected) <= 1.0 else {
                    throw PipelineFailure(step: .loudness, reason: "The episode audio is not the length it should be, so it cannot be trusted.",
                                          detail: "episode \(made.map { String($0) } ?? "unreadable") s, expected \(expected) s (recording \(ready.duration) s)")
                }
                await finish(.loudness, "\(Format.lufs(loudness.integratedLUFS)), peak \(Format.dbfs(loudness.truePeakDBFS)). Plays to its end (\(Format.timecode(made))).")
            }

            // 6b. The podcast-ready audio: its own chain, on the same trim, cuts, intro and outro. A
            //     failure costs only this step and the package: the episode and transcript are kept.
            var podcastMaster: PodcastMaster?
            let podcastRefusal = options.podcastReady.flatMap { PodcastPackage.refusal(kind: $0.facts.kind) }
            if let refusal = podcastRefusal {
                // A class is never made ready to upload (11 Oct): nothing is mastered or written for it,
                // and the page says why. The episode and transcript are made as for any recording.
                await begin(.podcastAudio)
                result.podcastProblem = refusal
                await finish(.podcastAudio, refusal + " Nothing was made for it.", state: .skipped)
            } else if let setup = options.podcastReady {
                await begin(.podcastAudio)
                do {
                    let made = try await masterPodcastReady(file: file, duration: ready.duration, program: program, staging: staging, setup: setup,
                                                            knownTalkLUFS: options.makeEpisode && options.channels == setup.settings.channels ? result.inputLUFS : nil)
                    podcastMaster = made
                    if result.clock == nil { result.clock = made.clock }
                    await finish(.podcastAudio, "\(setup.settings.channels.title) MP3, \(setup.settings.bitrate) kbps, 44.1 kHz: "
                                 + String(format: "%.2f LUFS, true peak %.2f dBTP, loudness range %.1f LU. ", made.lufs, made.truePeak, made.lra)
                                 + Self.levelingLine(made.normalizationType) + (made.corrected ? " Made twice: the first measured over -1.1 dBTP or off the loudness, so the limits or the aim were moved." : ""))
                } catch let failure as PipelineFailure {
                    result.podcastProblem = failure.reason
                    if let detail = failure.detail { log?.write("\(name): podcast-ready audio failed. \(detail)") }
                    await finish(.podcastAudio, failure.reason + " The episode and transcript are kept.", state: .failed)
                }
            }

            if options.makeEpisode || options.makePodcastReady {
                // 7. The transcript files follow the episode: the words in anything taken out are
                //    left out, and the times are the episode's. transcript.json keeps every word as
                //    heard, on the original's clock, for the recording page.
                if options.makeTranscript && options.changesTheClock, let clock = result.clock {
                    await begin(.episodeTranscript)
                    if clock.isIdentity(duration: ready.duration) {
                        await finish(.episodeTranscript, "Nothing was taken out or added, so its times already match the episode.")
                    } else {
                        let made = try followEpisode(in: staging, clock: clock, label: label, fileName: file.lastPathComponent)
                        let left = made.removedWords
                        result.transcriptFollowsEpisode = true
                        result.wordsLeftOut = left
                        if options.applyLexicon {
                            // The report lists the fixes in the files, never one inside a cut.
                            result.fixesLeftOut = max(0, result.corrections.count - made.corrections.count)
                            result.corrections = made.corrections
                        }
                        let fixesGone = result.fixesLeftOut > 0 ? " (with \(Format.count(result.fixesLeftOut, "word list fix", "word list fixes")))" : ""
                        let shift = clock.intro - (clock.segments.first?.start ?? 0)
                        await finish(.episodeTranscript, "Times match the episode"
                                     + (left > 0 ? "; \(Format.count(left, "word")) in the parts taken out are left out\(fixesGone)." : String(format: " (%.1f s %@).", abs(shift), shift >= 0 ? "later" : "earlier"))
                                     + " transcript.json keeps every word as heard.")
                    }
                } else if let i = index(.episodeTranscript), steps[i].state == .waiting {
                    // Only the podcast-ready audio was asked for, and it was not made: no clock to follow.
                    steps[i].state = .skipped
                }
            }

            // 8. Titles, show notes and chapters, from the transcript as the episode plays it. A model
            //    that is closed or answers badly costs only this step: the episode and transcript are
            //    kept, the step says why, and Write Again on the page tries once more.
            if options.makeTranscript, let setup = options.writing {
                await begin(.writing)
                guard let input = WritingInput.from(folder: staging, clock: result.clock, duration: ready.duration, applyLexicon: options.applyLexicon,
                                                    label: label, fileName: file.lastPathComponent, kind: options.kind, knownSerenity: options.knownSerenity) else {
                    throw PipelineFailure(step: .writing, reason: "The transcript could not be read to write the titles, show notes and chapters.")
                }
                let outcome = try await Writer(setup: setup, log: log).write(input)
                result.mentionsSerenity = result.mentionsSerenity || outcome.mentionsSerenity
                if let package = outcome.package {
                    do {
                        try package.save(in: staging, label: label, fileName: file.lastPathComponent)
                    } catch {
                        throw PipelineFailure(step: .writing, reason: "The titles, show notes and chapters were written but could not be saved.", detail: error.localizedDescription)
                    }
                    result.written = package
                    await finish(.writing, package.stepLine)
                } else {
                    result.writingProblem = outcome.problem ?? "Nothing was written."
                    await finish(.writing, (result.writingProblem ?? "") + " The episode and transcript are kept.", state: .failed)
                }
            }

            // 8b. The podcast-ready files: the tagged MP3, captions, the text file and the checklist,
            //     written after the titles and notes so they can carry them.
            if let refusal = podcastRefusal {
                await begin(.podcastPackage)
                await finish(.podcastPackage, refusal + " Nothing was written for it.", state: .skipped)
            } else if let setup = options.podcastReady {
                await begin(.podcastPackage)
                if let master = podcastMaster {
                    do {
                        let record = try await packagePodcastReady(untagged: master.untagged, into: staging.appending(path: PodcastPackage.folderName, directoryHint: .isDirectory),
                                                                   setup: setup, written: result.written, transcriptFolder: options.makeTranscript ? staging : nil,
                                                                   clock: master.clock, applyLexicon: options.applyLexicon, expectedDuration: master.expectedDuration,
                                                                   normalizationType: master.normalizationType, talkLUFS: master.talkLUFS, corrected: master.corrected, madeAt: Date())
                        result.podcastReady = record
                        await finish(.podcastPackage, "\(record.fileName) and its checklist, in the \(PodcastPackage.folderName) folder. Checklist: \(record.summary.lowercasedFirst).")
                    } catch let failure as PipelineFailure {
                        result.podcastProblem = failure.reason
                        try? FileManager.default.removeItem(at: staging.appending(path: PodcastPackage.folderName))
                        if let detail = failure.detail { log?.write("\(name): podcast-ready files failed. \(detail)") }
                        await finish(.podcastPackage, failure.reason + " The episode and transcript are kept.", state: .failed)
                    }
                    try? FileManager.default.removeItem(at: master.untagged)
                } else {
                    await finish(.podcastPackage, "Not written: the podcast-ready audio was not made.", state: .failed)
                }
            }

            // 9. The report Ivan reads before he listens.
            result.outcome = .ready
            if options.makeReport {
                await begin(.report)
                result.seconds = total()
                result.files = (Self.madeFiles(in: staging) + ["REPORT.md"]).sorted()
                let markdown = Report.markdown(file: file, label: label, result: result, options: options, steps: steps, madeAt: Date())
                do {
                    try markdown.write(to: staging.appending(path: "REPORT.md"), atomically: true, encoding: .utf8)
                } catch {
                    throw PipelineFailure(step: .report, reason: "The report could not be written.", detail: error.localizedDescription)
                }
                await finish(.report, "Written to REPORT.md, beside the episode.")
            }

            // 10. Only now do the new files take the place of the old ones.
            let placed: (files: [String], replaced: [String])
            do {
                placed = try Self.place(staging, into: outputFolder)
            } catch {
                throw PipelineFailure(step: options.plannedSteps.last ?? .sound, reason: "The files were made but could not be moved into their folder.", detail: error.localizedDescription)
            }
            result.files = placed.files
            result.replaced = placed.replaced
            result.outputFolder = placed.files.isEmpty && !FileManager.default.fileExists(atPath: outputFolder.path) ? nil : outputFolder
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
        // Nothing new was placed: an earlier make's files, if any, are as they were.
        result.outputFolder = nil
        result.files = []
        result.seconds = total()
        await emit()
        return result
    }

    /// Runs one tool for a step, turning a tool's failure into one plain sentence.
    func tool(_ step: PipelineStep, _ executable: URL, _ arguments: [String], captureStdout: Bool = true,
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
        if options.makeTranscript && result.written != nil { made.append("show notes") }
        if result.podcastReady != nil { made.append("the podcast-ready files") }
        let listed = made.count > 1 ? made.dropLast().joined(separator: ", ") + " and " + (made.last ?? "") : (made.first ?? "")
        var reason = made.isEmpty ? "The checks passed." : listed + (made.count > 1 ? " are ready." : " is ready.")
        if result.coverageOK == false, let reaches = result.transcriptReaches, let duration = result.duration {
            reason += " The transcript stops at \(Format.timecode(reaches)) of \(Format.timecode(duration)): listen to the end before trusting it."
        } else {
            reason += " Speakers are not checked yet."
        }
        if let problem = result.writingProblem {
            reason += " Titles, show notes and chapters were not written. \(problem)"
        }
        if let problem = result.podcastProblem {
            reason += " The podcast-ready files were not made. \(problem)"
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

    // MARK: The transcript's files

    /// Applies the word list to the .txt, .srt and .vtt Parakeet wrote (never the .json, which keeps
    /// the words as heard). Returns the corrected .srt and the fixes, timed from the .srt.
    static func applyWordList(in folder: URL) throws -> (srt: String, corrections: [Lexicon.Correction]) {
        var srt = ""
        var corrections: [Lexicon.Correction] = []
        for format in [TranscriptFormat.txt, .srt, .vtt] {
            let url = folder.appending(path: TranscriptFiles.fileName(format))
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let fixed = format == .txt ? Lexicon.apply(text) : Lexicon.applyToSubtitles(text)
            if format == .srt {
                srt = fixed.text
                corrections = fixed.corrections
            }
            guard fixed.text != text else { continue }
            do {
                try fixed.text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw PipelineFailure(step: .wordList, reason: "The word list could not be applied to the transcript.", detail: error.localizedDescription)
            }
        }
        return (srt, corrections)
    }

    /// Rewrites the chosen readable formats (.txt, .srt, .vtt, .md) from transcript.json so they
    /// follow the episode: the words inside anything taken out are dropped, and every time is the
    /// episode's. Returns how many words were left out and the word list's fixes in what is left.
    /// The .txt is rewritten only when words were left out.
    private func followEpisode(in folder: URL, clock: EpisodeClock, label: String, fileName: String) throws
        -> (removedWords: Int, corrections: [Lexicon.Correction]) {
        guard let data = try? Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard)),
              let sentences = EpisodeTranscript.sentences(json: data) else {
            throw PipelineFailure(step: .episodeTranscript, reason: "The transcript could not be matched to the episode: Parakeet's words with their times (transcript.json) could not be read.")
        }
        let made = EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: options.applyLexicon)
        let formats = options.transcriptFormats
        var files: [(TranscriptFormat, String)] = []
        if formats.contains(.srt) { files.append((.srt, EpisodeTranscript.srt(made.cues))) }
        if formats.contains(.vtt) { files.append((.vtt, EpisodeTranscript.vtt(made.cues))) }
        if formats.contains(.txt) && made.removedWords > 0 { files.append((.txt, EpisodeTranscript.text(made.cues))) }
        if formats.contains(.md) {
            files.append((.md, TranscriptFiles.markdown(cues: made.cues, label: label, fileName: fileName,
                                                        wordListApplied: options.applyLexicon, followsEpisode: true)))
        }
        do {
            for (format, text) in files {
                try text.write(to: folder.appending(path: TranscriptFiles.fileName(format)), atomically: true, encoding: .utf8)
            }
        } catch {
            throw PipelineFailure(step: .episodeTranscript, reason: "The transcript could not be matched to the episode.", detail: error.localizedDescription)
        }
        return (made.removedWords, made.corrections)
    }

    /// Writes the .md when it is chosen and removes the formats that are not. transcript.json stays.
    private func keepChosenFormats(in folder: URL, srt: String, label: String, fileName: String) throws {
        let formats = options.transcriptFormats
        if formats.contains(.md) {
            let markdown = TranscriptFiles.markdown(cues: TranscriptFiles.cues(srt: srt), label: label, fileName: fileName,
                                                    wordListApplied: options.applyLexicon)
            do {
                try markdown.write(to: folder.appending(path: TranscriptFiles.fileName(.md)), atomically: true, encoding: .utf8)
            } catch {
                throw PipelineFailure(step: .transcript, reason: "The formatted transcript (.md) could not be written.", detail: error.localizedDescription)
            }
        }
        for format in [TranscriptFormat.txt, .srt, .vtt] where !formats.contains(format) {
            try? FileManager.default.removeItem(at: folder.appending(path: TranscriptFiles.fileName(format)))
        }
    }

    // MARK: The intro and outro

    struct MeasuredPiece: Sendable {
        let path: String
        let lufs: Double
        let duration: Double
    }

    /// Checks an intro or outro is there and has sound, and measures its loudness and length.
    func piece(_ path: String?, role: String, duration: Double) async throws -> MeasuredPiece? {
        guard let path, !path.isEmpty else { return nil }
        let name = (path as NSString).lastPathComponent
        guard FileManager.default.fileExists(atPath: path) else {
            throw PipelineFailure(step: .episode, reason: "The \(role) chosen in Settings, Outputs (\(name)) is not there any more, so no episode audio was made. Choose it again, or remove it.")
        }
        let probe = try await tool(.episode, tools.ffprobe, ["-v", "error", "-show_entries", "format=duration:stream=codec_type", "-of", "json", path],
                                   duration: duration)
        guard let info = Measure.probe(json: probe.stdout), info.hasAudio else {
            throw PipelineFailure(step: .episode, reason: "The \(role) (\(name)) does not open as audio, so no episode audio was made.")
        }
        let pass = try await tool(.episode, tools.ffmpeg, ["-hide_banner", "-nostats", "-i", path, "-vn", "-af",
                                                           Mastering.firstPass(target: options.loudnessTarget, ceiling: options.peakCeiling, channels: options.channels),
                                                           "-f", "null", "-"], duration: duration)
        guard let lufs = Measure.loudnorm(stderr: pass.stderr)?.inputLUFS, lufs.isFinite, lufs > -70 else {
            throw PipelineFailure(step: .episode, reason: "The \(role) (\(name)) has no usable sound, so no episode audio was made.")
        }
        return MeasuredPiece(path: path, lufs: lufs, duration: info.duration)
    }

    /// The gain that brings an intro or outro to the talk's loudness, within 30 dB either way.
    static func matchingGain(talk: Double, piece: Double) -> Double {
        min(30, max(-30, talk - piece))
    }

    /// "Intro 5.0 s and outro 8.0 s added. "
    static func piecesLine(intro: MeasuredPiece?, outro: MeasuredPiece?) -> String {
        func seconds(_ piece: MeasuredPiece) -> String { String(format: "%.1f s", piece.duration) }
        switch (intro, outro) {
        case let (intro?, outro?): return "Intro \(seconds(intro)) and outro \(seconds(outro)) added. "
        case let (intro?, nil): return "Intro \(seconds(intro)) added. "
        case let (nil, outro?): return "Outro \(seconds(outro)) added. "
        case (nil, nil): return ""
        }
    }

    // MARK: Staging and placing

    /// Every file a make can leave. Only these are ever replaced or removed from a recording's
    /// folder; anything else Ivan keeps there is left alone.
    static let madeNames: Set<String> = Set(["episode.mp3", "REPORT.md", "speech.wav", TranscriptFiles.asHeard, PodcastPackage.folderName]
                                            + TranscriptFormat.allCases.map(TranscriptFiles.fileName))
        .union(WrittenPackage.fileNames)

    /// A hidden folder beside the recording's own, in the same Outputs folder (so a move is a rename).
    static func stagingFolder(for outputFolder: URL) -> URL {
        outputFolder.deletingLastPathComponent().appending(path: ".making " + outputFolder.lastPathComponent, directoryHint: .isDirectory)
    }

    /// Moves a finished make into the recording's folder. A file made again replaces the old one; a
    /// file an earlier make left that this one did not make (a transcript turned off) is removed.
    /// Only names in `known` are ever replaced or removed (Approve passes its own list).
    /// Returns the files now there from this make, and the names it replaced or removed.
    static func place(_ staging: URL, into folder: URL, known: Set<String> = madeNames) throws -> (files: [String], replaced: [String]) {
        let fm = FileManager.default
        let new = madeFiles(in: staging)
        let old = madeFiles(in: folder).filter(known.contains)
        if !new.isEmpty { try fm.createDirectory(at: folder, withIntermediateDirectories: true) }
        for name in new {
            let destination = folder.appending(path: name)
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: staging.appending(path: name))
            } else {
                try fm.moveItem(at: staging.appending(path: name), to: destination)
            }
        }
        for name in old where !new.contains(name) {
            try fm.removeItem(at: folder.appending(path: name))
        }
        return (new, old)
    }

    static func madeFiles(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
    }
}
