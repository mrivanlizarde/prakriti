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
//   a clip in our own test. Since v2 part TXGAP it also fails on any stretch of 3 s or more of
//   speech with no words, wherever it is, after each such stretch has been transcribed again on its
//   own (TranscriptGaps): Parakeet wrote nothing for 17 s at 24:22 and 39:24 of the 6 Sep talk.
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
    case complete, capture, sound, speechAudio, transcript, coverage, wordList, namesSaid, faces, voices, trim, edits, leaveOut, planEdit, episode, loudness, podcastAudio, audioCheck, episodeTranscript, writing, renderVideo, checkVideo, podcastPackage, report

    var title: String {
        switch self {
        case .complete: "Checked the file is complete"
        case .capture: "Capture check"
        case .sound: "Sound check"
        case .speechAudio: "Audio for the transcript"
        case .transcript: "Transcript"
        case .coverage: "Coverage check"
        case .wordList: "Word list"
        case .namesSaid: "Names said aloud"
        case .faces: "Faces"
        case .voices: "Voices"
        case .trim: "Silence at the start and end"
        case .edits: "Your trim and cuts"
        case .leaveOut: "People left out"
        case .planEdit: "Planning the edit"
        case .episode: "Episode audio"
        case .loudness: "Loudness check"
        case .podcastAudio: "Podcast-ready audio"
        case .audioCheck: "Who is heard in the episode"
        case .podcastPackage: "Podcast-ready files"
        case .episodeTranscript: "Transcript matched to the episode"
        case .writing: "Titles, show notes and chapters"
        case .renderVideo: "Making the video"
        case .checkVideo: "Checking the video"
        case .report: "Report"
        }
    }

    /// The name in a list of steps (the Activity window's Steps): `title`, except a step whose title is in the
    /// past tense says what it is doing while it runs. Reason (12 Oct, M4a fix): the running first step read
    /// "Checked the file is complete" at 0:28 so far. `title` itself stays, because stored steps are matched
    /// by it (`StageTimings`, `JobProgress`, `PipelineRunner`).
    func listTitle(running: Bool) -> String {
        running && self == .complete ? "Checking the file is complete" : title
    }

    var doing: String {
        switch self {
        case .complete: "Checking the file is complete"
        case .capture: "Checking how it was recorded"
        case .sound: "Checking the sound"
        case .speechAudio: "Preparing the audio for the transcript"
        case .transcript: "Writing the transcript"
        case .coverage: "Checking the transcript has every stretch of speech"
        case .wordList: "Applying the Yoga Marga word list"
        case .namesSaid: "Finding names said aloud"
        case .faces: "Looking for faces"
        case .voices: "Listening for voices"
        case .trim: "Finding the silence at the start and end"
        case .edits: "Applying your trim and cuts"
        case .leaveOut: "Leaving out the people you chose"
        case .planEdit: "Planning the edit"
        case .episode: "Making the episode audio"
        case .loudness: "Measuring the episode audio"
        case .podcastAudio: "Mastering the podcast-ready audio"
        case .audioCheck: "Checking who is heard in the episode"
        case .podcastPackage: "Writing and checking the podcast-ready files"
        case .episodeTranscript: "Matching the transcript to the episode"
        case .writing: "Writing the titles, show notes and chapters"
        case .renderVideo: "Making the video"
        case .checkVideo: "Checking the video"
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
    /// Stretches the plan took out that Ivan restored in the Viewer (v2 part M8c): the next plan keeps each as recorded.
    var planRestores: [TimeRange] = []
    /// The House Style the edit is planned with (v2 part M9a, Settings, House Style): the style's pauses, punch-ins,
    /// push-ins and the room at the end. The standard is Clear.
    var house = HouseStyle.standard

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

    /// The face step of the people pass (v2 part M6a): which recording it is for and where its people file and
    /// job folder go, or nil when faces are not looked for (the tests that run the pipeline alone).
    var people: PeopleSetup?
    /// Ivan's choices of who is in the podcast and which names said aloud are muted (v2 part M6c). The default leaves
    /// everyone in and mutes nothing, so the episode is made exactly as before.
    var choices = PeopleChoices.none

    /// The edit plan (v2 part M8a): `edit-plan.json`, the rough cut every video output will be made from. Planned only
    /// when asked for (the app asks once a recording has a plan, so Make Again keeps it current; M8b ties it to the
    /// edited video), and only with the transcript, which it is made from. No file a person could post comes of it.
    var planEdit = false
    /// The edited video (v2 part M8b): the MP4, its captions, Description.txt and the Ready checklist, made from the edit
    /// plan, which is then always planned. Only with the transcript, which the plan is made from. Off unless the
    /// recording's output switches ask for it (PLAN rule 2.1.7).
    var makeVideo = false
    /// The recording's title and notes as Ivan set them, and when it was recorded: the video's name and Description.txt.
    var video = VideoFacts()

    /// Anyone left out or any name muted: the podcast changes, so the step that applies it is planned.
    var appliesChoices: Bool { people != nil && choices.changesPodcast && (makeEpisode || makePodcastReady) }

    /// Anything taken out of the recording or added to it, so the episode's clock is not the
    /// original's and the transcript files are rewritten to follow the episode. A muted name (v2 part M6c) keeps the
    /// clock but changes the words, so the files are rewritten for it too.
    var changesTheClock: Bool {
        trimSilence || !(introPath ?? "").isEmpty || !(outroPath ?? "").isEmpty || !edits.isEmpty || appliesChoices
    }

    /// The steps this run will take, in order. The checks always run, the capture check first of all once the
    /// file is complete (v2 part M4b), so even a test under 60 s has one.
    var plannedSteps: [PipelineStep] {
        var steps: [PipelineStep] = [.complete, .capture, .sound]
        if checksOnly { return steps }
        if makeTranscript {
            steps += [.speechAudio, .transcript, .coverage]
            if applyLexicon { steps.append(.wordList) }
            // Names said aloud (v2 part M6c), from the transcript, with the people check.
            if people != nil { steps.append(.namesSaid) }
        }
        // After the transcript and before anything is written (docs/v2/PLAN.md M6): faces, then voices; their answer
        // together is what the privacy lock reads (M6b).
        if people != nil { steps += [.faces, .voices] }
        if makeEpisode || makePodcastReady {
            if trimSilence { steps.append(.trim) }
            if !edits.isEmpty { steps.append(.edits) }
            if appliesChoices { steps.append(.leaveOut) }
        }
        if (planEdit || makeVideo) && makeTranscript { steps.append(.planEdit) }
        if makeEpisode { steps += [.episode, .loudness] }
        if makePodcastReady { steps.append(.podcastAudio) }
        // The audio output check, whenever someone is left out (v2 part M6c).
        if appliesChoices && choices.leavesSomeoneOut { steps.append(.audioCheck) }
        if (makeEpisode || makePodcastReady) && makeTranscript && changesTheClock { steps.append(.episodeTranscript) }
        if makeTranscript && writing != nil { steps.append(.writing) }
        // After the writing, so its title, notes and chapters can go in Description.txt (v2 part M8b).
        if makeVideo && makeTranscript { steps += [.renderVideo, .checkVideo] }
        if makePodcastReady { steps.append(.podcastPackage) }
        if makeReport { steps.append(.report) }
        return steps
    }
}

/// What the edited video is named and described with, read from the recording (v2 part M8b).
struct VideoFacts: Sendable, Equatable {
    var title = ""
    var notes = ""
    var recordedAt: Date?
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
    /// Stretches of speech the whole-file run wrote no words for, transcribed again on their own (v2 part TXGAP), and
    /// the words that found.
    var relistened: [TimeRange] = []
    var wordsFoundAgain = 0
    /// Stretches of 3 s or more of speech still with no words after that: the coverage check fails on any.
    var transcriptGaps: [TimeRange] = []
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
    /// What the capture check measured (v2 part M4b), or nil when the file never got that far.
    var capture: CaptureReport?
    /// What the face step found (v2 part M6a), or why it could not look. A face step that fails costs only its
    /// step: the episode and transcript are made as usual.
    var faces: FacesFound?
    var facesProblem: String?
    /// What the voice step found (v2 part M6b), or why it could not listen. Like the face step, a failure costs only
    /// its step, and leaves the people check not run, so the privacy lock stays closed.
    var voices: VoicesFound?
    var voicesProblem: String?
    /// The names said aloud this make found (v2 part M6c), or nil when it did not look (no transcript, no people check).
    var namesSaid: NamesSaid?
    /// What this make left out of the podcast and muted, and the audio output check of what it made (v2 part M6c).
    /// Nil when nobody was left out and nothing was muted.
    var applied: PeopleApplied?
    /// The edit plan this make wrote (v2 part M8a), or why it could not, or neither when it was not asked for.
    var editPlan: EditPlan?
    var planProblem: String?
    /// The edited video this make made and checked (v2 part M8b), or why it did not, or neither when it was not asked for.
    var video: VideoRecord?
    var videoProblem: String?
}

/// Where the face and voice steps write, for one recording, and Ivan's names the writing step's privacy lock reads.
struct PeopleSetup: Sendable, Equatable {
    var recordingID: UUID
    var folders: PeopleFolders
    /// Who Is Teaching and Name for This Recording, with the folder's microphones applied (v2 part M6b).
    var names: PeopleNames = .none
    /// The folder's microphones: a voice heard on one of these tracks takes the person's name.
    var microphones: [Int: UUID] = [:]
    /// The people named in Settings, Privacy, each with whether a signed release is on file.
    var people: [NamedPerson] = []

    /// The names once this make's voices are known: the folder's microphones fill any voice not named by hand.
    func names(for voices: VoicesFound?) -> PeopleNames {
        var out = names
        if let voices, voices.source == .tracks {
            for voice in voices.voices where out.voices[voice.id] == nil {
                if let track = voice.track, let person = microphones[track] { out.voices[voice.id] = person }
            }
        }
        return out
    }
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
        /// Names said aloud that Ivan muted (v2 part M6c), on the original's clock: silenced before anything is cut,
        /// so the times are the original's. Empty: the chain is unchanged, string for string.
        var mutes: [Span] = []

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
        let trim = (muteFilter(program.mutes).map { $0 + "," } ?? "")
            + (program.kept.map { "atrim=start=\(time($0.start)):end=\(time($0.end)),asetpts=PTS-STARTPTS," } ?? "")
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

    /// Silence over each muted name (v2 part M6c): the volume falls to nothing over 30 ms before each span and rises
    /// over 30 ms after it, worked out once per audio frame (about 21 ms), on the original's clock. The spans arrive
    /// padded (`LeaveOut.mutePad`), so a frame that starts just before a name is already silent. Nil with no mutes:
    /// nothing is added to the chain (Mac warning 30).
    static func muteFilter(_ mutes: [Span]) -> String? {
        guard !mutes.isEmpty else { return nil }
        let factors = mutes.map { span in
            "clip((abs(t-\(time((span.start + span.end) / 2)))-\(time(span.length / 2)))/0.03,0,1)"
        }
        return "volume=volume='" + factors.joined(separator: "*") + "':eval=frame"
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
        let mute = muteFilter(program.mutes).map { $0 + "," } ?? ""
        if parts.count == 1, let only = parts.first {
            graph.append("[\(talkInput):a]\(mute)\(part(only)),\(format)[talk]")
        } else {
            graph.append("[\(talkInput):a]\(mute)asplit=\(parts.count)" + parts.indices.map { "[s\($0)]" }.joined())
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
    /// Where the running stage has got to, for the progress the window shows (v2 part M4a). Nil: no
    /// progress is read (the tests that run the pipeline alone).
    var meter: ProgressMeter?

    init(tools: ToolPaths = .standard, options: PipelineOptions = PipelineOptions(), log: AppLog?, meter: ProgressMeter? = nil) {
        self.tools = tools
        self.options = options
        self.log = log
        self.meter = meter
    }

    /// How many ffmpeg passes a stage makes over the recording, when that is known, so each pass is an equal
    /// share of the stage's progress. Nil: not known ahead (the podcast-ready mastering measures until it is
    /// right), and each later pass takes half of what is left.
    func passes(_ step: PipelineStep) -> Int? {
        switch step {
        case .sound, .speechAudio, .trim, .loudness, .faces, .voices, .planEdit, .renderVideo, .checkVideo: return 1
        case .episode:
            let intro = !(options.introPath ?? "").isEmpty, outro = !(options.outroPath ?? "").isEmpty
            return 2 + (intro ? 1 : 0) + (outro ? 1 : 0) + (intro || outro ? 1 : 0)
        default: return nil
        }
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
            meter?.begin(step, passes: passes(step))
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
            let line = "\(step.title) \(state == .done ? "done" : "stopped") in \(String(format: "%.1f", seconds)) s." + (detail.map { " " + $0 } ?? "")
            log?.write("\(name): " + line)
            meter?.line(line)
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

            // 2. The capture check (v2 part M4b): every stream and every audio track measured, each finding with a
            //    capture tip. It never stops the make; a test under 60 s keeps its check too.
            await begin(.capture)
            let capture = try await CaptureCheck.run(file: file, tools: tools, now: Date(), control: meter?.control,
                                                     tracksKnown: { meter?.begin(.capture, passes: max(1, $0)) },
                                                     measureTrack: { arguments in
                                                         try await tool(.capture, tools.ffmpeg, arguments, duration: ready.duration).stderr
                                                     })
            result.capture = capture
            await finish(.capture, capture.stepLine)

            // 3. Under 60 seconds is a test.
            if ready.duration < options.testUnder {
                skipTheRest()
                result.outcome = .test
                result.reason = "Under 60 seconds, so it was filed as a test. Nothing was made and no notice was sent."
                await emit()
                result.seconds = total()
                return result
            }

            await emit(.fileReady)

            // 4. Sound check: the whole audio track, fast (about 2 s per hour).
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

            // 5. Mono 16 kHz audio, then the transcript (Parakeet), the coverage check, the word list.
            if options.makeTranscript {
                await begin(.speechAudio)
                // The same decode also writes the sound as raw floats, for the envelope the gap check reads (TXGAP).
                let speechFloats = staging.appending(path: "speech.f32")
                _ = try await tool(.speechAudio, tools.ffmpeg, ["-y", "-v", "error", "-i", file.path, "-vn", "-ac", "1", "-ar", "16000", speech.path,
                                                                "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", speechFloats.path],
                                   captureStdout: false, duration: ready.duration)
                await finish(.speechAudio, "Mono, 16 kHz.")

                await begin(.transcript)
                _ = try await tool(.transcript, tools.parakeet, [speech.path, "--output-dir", staging.path, "--output-format", "all",
                                                                 "--output-template", "transcript"],
                                   captureStdout: false, duration: ready.duration)
                // Speech the whole-file run wrote no words for, transcribed again stretch by stretch (TranscriptGaps).
                let envelope = try? Envelope.read(rawFloats: speechFloats, samplesPerFrame: 160)
                try? FileManager.default.removeItem(at: speechFloats)
                var heardAgain = ""
                if let envelope {
                    let again = try await listenAgain(speech: speech, envelope: envelope, duration: ready.duration, staging: staging, name: name)
                    result.relistened = again.gaps.map(\.range)
                    result.wordsFoundAgain = again.words
                    if !again.gaps.isEmpty {
                        heardAgain = " \(Format.count(again.gaps.count, "stretch", "stretches")) with no words were transcribed again on their own"
                            + (again.words > 0 ? " and gave \(Format.count(again.words, "word")) more." : ", and still gave none.")
                    }
                }
                try? FileManager.default.removeItem(at: speech)
                let srtFile = staging.appending(path: TranscriptFiles.fileName(.srt))
                guard var srt = try? String(contentsOf: srtFile, encoding: .utf8),
                      let text = try? String(contentsOf: staging.appending(path: TranscriptFiles.fileName(.txt)), encoding: .utf8) else {
                    throw PipelineFailure(step: .transcript, reason: "Parakeet finished but wrote no transcript.")
                }
                let words = Measure.wordCount(text)
                result.wordCount = words
                result.mentionsSerenity = Privacy.mentionsSerenity(text)
                await finish(.transcript, "\(Format.number(words)) words." + heardAgain)

                await begin(.coverage)
                let reaches = Measure.lastCueEnd(srt: srt)
                let gap = ready.duration - reaches
                result.transcriptReaches = reaches
                // Any stretch of speech still with no words, wherever it is (the tail's own check stays as it was). A
                // transcript.json that cannot be read, or sound that could not be measured, leaves only the tail check.
                if let envelope, let heard = ParakeetTranscript.read(staging.appending(path: TranscriptFiles.asHeard)) {
                    result.transcriptGaps = TranscriptGaps.missing(heard, envelope: envelope, duration: ready.duration)
                        .filter { gap <= options.coverageGap || $0.end < ready.duration - 0.01 }.map(\.range)
                }
                result.coverageOK = gap <= options.coverageGap && result.transcriptGaps.isEmpty
                if !result.transcriptGaps.isEmpty {
                    log?.write("\(name): the transcript has no words for \(Format.count(result.transcriptGaps.count, "stretch", "stretches")) of speech: \(TranscriptGaps.list(result.transcriptGaps)).")
                }
                let missing = result.transcriptGaps.isEmpty ? ""
                    : " No words for \(Format.count(result.transcriptGaps.count, "stretch", "stretches")) of speech: \(TranscriptGaps.list(result.transcriptGaps))."
                await finish(.coverage, gap <= options.coverageGap
                             ? "Reaches \(Format.timecode(reaches)) of \(Format.timecode(ready.duration))." + missing
                             : "Stops at \(Format.timecode(reaches)) of \(Format.timecode(ready.duration)). The last \(Format.length(gap)) has no words." + missing)

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

                // 5a. Names said aloud (v2 part M6c): every person's name the tagger finds in the words as heard that is
                //     not someone Ivan named, as a moment to Keep or Mute. Arithmetic on the transcript; nothing leaves
                //     the Mac. A transcript.json that cannot be read finds none, and says so.
                if let people = options.people {
                    await begin(.namesSaid)
                    if let data = try? Data(contentsOf: staging.appending(path: TranscriptFiles.asHeard)),
                       let sentences = EpisodeTranscript.sentences(json: data) {
                        let found = NamesSaid(checkedAt: Date(), moments: NamesSaidAloud.find(sentences, named: people.people.map(\.name)))
                        result.namesSaid = found
                        await finish(.namesSaid, found.stepLine)
                    } else {
                        await finish(.namesSaid, "The words with their times could not be read, so names said aloud were not looked for.", state: .failed)
                    }
                }
            }

            // 5b. Faces (v2 part M6a): every face in the picture, two frames a second, as boxes and times only, into
            //     the recording's people file through a job folder deleted when the step ends. A failure costs only
            //     this step, and nothing it found changes what is made in this part.
            if let people = options.people {
                await begin(.faces)
                meter?.startPass()
                do {
                    let outcome = try await FaceStep.run(file: file, recordingID: people.recordingID, folders: people.folders, now: Date(),
                                                         control: meter?.control, progress: { [meter] fraction in meter?.passProgress(fraction) })
                    result.faces = outcome.found
                    await finish(.faces, outcome.found.stepLine)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let detail = (error as? FaceScan.Failure)?.reason ?? error.localizedDescription
                    result.facesProblem = "Faces could not be looked for. \(detail)"
                    log?.write("\(name): faces failed. \(detail)")
                    await finish(.faces, "Faces could not be looked for. The rest is made as usual.", state: .failed)
                }

                // 5c. Voices (v2 part M6b): who speaks when, from the microphone tracks when there are any, else told
                //     apart on the one mixed track; then each voice linked to a face. Times only, into the same people
                //     file. Needs the face step's file, so a failed face step skips it, and the lock stays closed.
                await begin(.voices)
                meter?.startPass()
                if result.faces == nil {
                    result.voicesProblem = "Voices were not listened for, because faces could not be looked for."
                    await finish(.voices, result.voicesProblem, state: .failed)
                } else {
                    do {
                        var tracks = result.capture?.audio.count ?? 0
                        if result.capture == nil { tracks = await VoiceStep.audioTracks(file) }
                        let ffmpeg = tools.ffmpeg, limit = limit(ready.duration), control = meter?.control
                        let outcome = try await VoiceStep.run(
                            file: file, recordingID: people.recordingID, folders: people.folders, audioTracks: tracks, now: Date(),
                            decode: { arguments in _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: limit, control: control) },
                            control: meter?.control, log: { [log] line in log?.write("\(name): voices. " + line) },
                            progress: { [meter] fraction in meter?.passProgress(fraction) })
                        result.voices = outcome.found
                        await finish(.voices, outcome.found.stepLine)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let detail = (error as? VoiceStep.Failure)?.reason ?? (error as? Diarizer.Failure)?.reason
                            ?? (error as? ToolError)?.logLine ?? error.localizedDescription
                        result.voicesProblem = "Voices could not be listened for. \(detail)"
                        log?.write("\(name): voices failed. \(detail)")
                        await finish(.voices, "Voices could not be listened for. The rest is made as usual.", state: .failed)
                    }
                }
            }

            // 6. The episode audio: the silence trim, two-pass loudness, the MP3 (Apple Podcasts spec).
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

                // The people Ivan chose to leave out, and the names he muted (v2 part M6c): their speech cut from both
                // podcast episodes on top of his own trim and cuts, whole words, each edge settled on the quietest
                // moment of the sound (Mac warning 120); the names
                // silenced. Someone left out with no voices found this make stops it: nothing is made that might
                // still hold them (fail closed).
                if options.appliesChoices, let people = options.people {
                    await begin(.leaveOut)
                    let applied = try await leaveOut(people: people, staging: staging, original: file, duration: ready.duration,
                                                     namesSaid: result.namesSaid, faces: result.faces, voices: result.voices)
                    if !applied.leaveOut.cuts.isEmpty {
                        let edits = options.edits.adding(cuts: applied.leaveOut.cuts)
                        if let problem = edits.problem(duration: ready.duration, silence: program.kept) {
                            throw PipelineFailure(step: .leaveOut, reason: problem + " Nothing was made; change who is left out and make it again.")
                        }
                        let parts = edits.segments(duration: ready.duration, silence: program.kept)
                        program.parts = parts
                        result.parts = parts
                    }
                    program.mutes = applied.leaveOut.mutes.map { Mastering.Span(start: $0.start, end: $0.end) }
                    result.applied = applied
                    let kept = program.talk(duration: ready.duration).reduce(0) { $0 + $1.length }
                    await finish(.leaveOut, applied.leaveOut.stepLine + " The episode keeps \(Format.timecode(kept)) of \(Format.timecode(ready.duration)).")
                }
            }
            // 5d. The edit plan (v2 part M8a): the rough cut as `edit-plan.json`, from the transcript and the original's
            //     sound, with Ivan's trim and cuts and the people left out of the video applied on top. A plan that cannot
            //     be made or does not pass its own check costs only this step; nothing else reads it in M8a.
            if (options.planEdit || options.makeVideo) && options.makeTranscript {
                await begin(.planEdit)
                do {
                    let plan = try await planTheEdit(file: file, staging: staging, duration: ready.duration, capture: result.capture,
                                                     namesSaid: result.namesSaid, faces: result.faces, voices: result.voices)
                    result.editPlan = plan.plan
                    await finish(.planEdit, plan.stepLine)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let reason = (error as? PlanStep.Failure)?.reason ?? (error as? PipelineFailure)?.reason ?? error.localizedDescription
                    result.planProblem = reason
                    log?.write("\(name): planning the edit failed. \(reason)")
                    await finish(.planEdit, reason + " The rest is made as usual.", state: .failed)
                }
            }

            // The names said aloud that this make muted, for every file that carries words (v2 part M6c).
            let mutes = result.applied?.leaveOut.mutes ?? []
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

                // 7. Measure what was made, rather than trust it, and decode its tail.
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

            // 6c. The audio output check (v2 part M6c): the files just made, listened to again; anyone heard who sounds
            //     like someone left out stops Approve, with the time. A check that cannot run says so and stops
            //     Approve the same way (fail closed).
            if options.appliesChoices && options.choices.leavesSomeoneOut, let people = options.people, var applied = result.applied {
                await begin(.audioCheck)
                meter?.startPass()
                var made: [AudioOutputCheck.Made] = []
                if options.makeEpisode, let clock = result.clock {
                    made.append(.init(name: "episode.mp3", url: staging.appending(path: "episode.mp3"), clock: clock))
                }
                if let master = podcastMaster {
                    made.append(.init(name: "the podcast-ready episode", url: master.untagged, clock: master.clock))
                }
                let segments = people.folders.read(people.recordingID)?.voices?.voiceSegments ?? []
                do {
                    let ffmpeg = tools.ffmpeg, limit = limit(ready.duration), control = meter?.control
                    let check = try await AudioOutputCheck.run(
                        original: file, made: made, segments: segments, leftOut: Set(applied.leaveOut.voices), folders: people.folders, now: Date(),
                        decode: { arguments in _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: limit, control: control) },
                        log: { [log] line in log?.write("\(name): who is heard. " + line) })
                    applied.check = check
                    result.applied = applied
                    await finish(.audioCheck, check.line { "Voice \($0)" }, state: check.passed ? .done : .failed)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let detail = (error as? Diarizer.Failure)?.reason ?? (error as? ToolError)?.logLine ?? error.localizedDescription
                    var failed = AudioCheck(checkedAt: Date(), files: made.map(\.name))
                    failed.findings = [.init(file: made.first?.name ?? "episode.mp3", at: 0, seconds: 0, voice: applied.leaveOut.voices.first ?? 0, how: "could not be checked for")]
                    applied.check = failed
                    result.applied = applied
                    log?.write("\(name): who is heard could not be checked. \(detail)")
                    await finish(.audioCheck, "Who is heard could not be checked, so it cannot be approved until it is made again. \(detail)", state: .failed)
                }
            }

            if options.makeEpisode || options.makePodcastReady {
                // 8. The transcript files follow the episode: the words in anything taken out are
                //    left out, and the times are the episode's. transcript.json keeps every word as
                //    heard, on the original's clock, for the recording page.
                if options.makeTranscript && options.changesTheClock, let clock = result.clock {
                    await begin(.episodeTranscript)
                    if clock.isIdentity(duration: ready.duration) && mutes.isEmpty {
                        await finish(.episodeTranscript, "Nothing was taken out or added, so its times already match the episode.")
                    } else {
                        let made = try followEpisode(in: staging, clock: clock, label: label, fileName: file.lastPathComponent, mutes: mutes)
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
                        let muted = mutes.isEmpty ? "" : " \(Format.count(mutes.count, "name")) said aloud written as \(EpisodeTranscript.mutedWord)."
                        await finish(.episodeTranscript, "Times match the episode"
                                     + (left > 0 ? "; \(Format.count(left, "word")) in the parts taken out are left out\(fixesGone)." : String(format: " (%.1f s %@).", abs(shift), shift >= 0 ? "later" : "earlier"))
                                     + muted + " transcript.json keeps every word as heard.")
                    }
                } else if let i = index(.episodeTranscript), steps[i].state == .waiting {
                    // Only the podcast-ready audio was asked for, and it was not made: no clock to follow.
                    steps[i].state = .skipped
                }
            }

            // 9. Titles, show notes and chapters, from the transcript as the episode plays it. A model
            //    that is closed or answers badly costs only this step: the episode and transcript are
            //    kept, the step says why, and Write Again on the page tries once more.
            if options.makeTranscript, let setup = options.writing {
                await begin(.writing)
                guard var input = WritingInput.from(folder: staging, clock: result.clock, duration: ready.duration, applyLexicon: options.applyLexicon,
                                                    label: label, fileName: file.lastPathComponent, kind: options.kind, knownSerenity: options.knownSerenity,
                                                    mutes: mutes) else {
                    throw PipelineFailure(step: .writing, reason: "The transcript could not be read to write the titles, show notes and chapters.")
                }
                // The privacy lock reads this make's people check (v2 part M6b) and Ivan's choices: anyone set to Leave Out, or
                // anyone named and marked "no release", keeps the writing on this Mac (part LOCK).
                if let people = options.people {
                    input.people = PeopleFacts.from(faces: result.faces, voices: result.voices, names: people.names(for: result.voices),
                                                    people: people.people, choices: options.choices)
                } else {
                    input.people.leftOut = PeopleFacts.from(faces: nil, voices: nil, names: .none, people: [], choices: options.choices).leftOut
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

            // 9b. The edited video (v2 part M8b): made from this make's edit plan, after the writing so Description.txt can
            //     carry its title, notes and chapters, in a hidden folder inside the staging folder, then measured and let
            //     through `OutputGate` into Video. A refusal or a failure costs only these two steps: everything else is kept.
            if options.makeVideo && options.makeTranscript {
                await begin(.renderVideo)
                meter?.startPass()
                let setup = videoSetup(file: file, staging: staging, label: label, result: result)
                if let setup {
                    let ffmpeg = tools.ffmpeg, ffprobe = tools.ffprobe, limit = limit(ready.duration), control = meter?.control
                    let runFFmpeg: @Sendable ([String]) async throws -> String = { arguments in
                        try await Subprocess.run(ffmpeg, arguments, timeout: limit, control: control).stderr
                    }
                    let runFFprobe: @Sendable ([String]) async throws -> String = { arguments in
                        try await Subprocess.run(ffprobe, arguments, timeout: limit, control: control).stdout
                    }
                    do {
                        let made = try await VideoStep.make(setup, ffmpeg: runFFmpeg, progress: { [meter] in meter?.passProgress($0) })
                        await finish(.renderVideo, String(format: "%@ and its captions, %d frames in %.0f s (%.1f times real time).", made.mp4.lastPathComponent,
                                                          made.frames, made.renderSeconds, made.timeline.duration / max(0.001, made.renderSeconds)))
                        await begin(.checkVideo)
                        meter?.startPass()
                        let record = try await VideoStep.check(made, setup: setup, ffprobe: runFFprobe, ffmpeg: runFFmpeg, now: Date(),
                                                               progress: { [meter] in meter?.passProgress($0) })
                        result.video = record
                        await finish(.checkVideo, "In the \(VideoStep.folderName) folder. Ready checklist: \(record.summary.lowercasedFirst).",
                                     state: record.failed == 0 ? .done : .failed)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let reason = (error as? VideoStep.Failure)?.reason ?? (error as? ToolError)?.logLine ?? error.localizedDescription
                        result.videoProblem = reason
                        try? FileManager.default.removeItem(at: staging.appending(path: VideoStep.stagingName))
                        log?.write("\(name): the video was not made. \(reason)")
                        if let i = index(.renderVideo), steps[i].state == .running {
                            await finish(.renderVideo, reason + " Everything else is kept.", state: .failed)
                            if let j = index(.checkVideo) { steps[j].state = .skipped }
                        } else {
                            await finish(.checkVideo, reason + " Everything else is kept.", state: .failed)
                        }
                    }
                } else {
                    let reason = result.editPlan == nil
                        ? "No video was made, because the edit plan could not be made" + (result.planProblem.map { ": " + $0 } ?? ".")
                        : (OutputGate.refusal(peopleFacts(result: result)) ?? OutputGate.notChecked)
                    result.videoProblem = reason
                    await finish(.renderVideo, reason, state: result.editPlan == nil ? .failed : .skipped)
                    if let j = index(.checkVideo) { steps[j].state = .skipped }
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
                                                                   clock: master.clock, applyLexicon: options.applyLexicon, mutes: mutes, expectedDuration: master.expectedDuration,
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

            // 10. The report Ivan reads before he listens.
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

            // 11. Only now do the new files take the place of the old ones.
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
    ///
    /// ffmpeg is run with `-progress pipe:1` when the make is metered (v2 part M4a): its `out_time_us` lines,
    /// against the recording's length, are how far the pass is. The option only adds those lines on stdout,
    /// which no ffmpeg call here reads otherwise; what ffmpeg writes and measures is unchanged.
    func tool(_ step: PipelineStep, _ executable: URL, _ arguments: [String], captureStdout: Bool = true,
                      duration: Double?) async throws -> ToolOutput {
        do {
            if let meter, executable == tools.ffmpeg {
                meter.startPass()
                let length = max(duration ?? 0, 0.001)
                return try await Subprocess.run(executable, ["-progress", "pipe:1"] + arguments, captureStdout: captureStdout, timeout: limit(duration),
                                                onStdoutLine: { line in
                                                    if let seconds = ProgressMeter.outTime(line) { meter.passProgress(seconds / length) }
                                                }, control: meter.control)
            }
            return try await Subprocess.run(executable, arguments, captureStdout: captureStdout, timeout: limit(duration), control: meter?.control)
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

    /// Transcribes again, each on its own, the stretches of speech the whole-file run wrote no words for, and adds the
    /// words found to the transcript's files in `staging` (v2 part TXGAP, `TranscriptGaps`). Returns the stretches
    /// listened to again and the words found. A failure here is logged and costs only the second listen: the coverage
    /// check then reports the stretches as missing words, so nothing passes unseen.
    private func listenAgain(speech: URL, envelope: Envelope, duration: Double, staging: URL, name: String) async throws
        -> (gaps: [TranscriptGaps.Gap], words: Int) {
        let asHeard = staging.appending(path: TranscriptFiles.asHeard)
        guard let first = ParakeetTranscript.read(asHeard) else { return ([], 0) }
        let gaps = TranscriptGaps.toListenAgain(first, envelope: envelope, duration: duration)
        guard !gaps.isEmpty else { return ([], 0) }
        let folder = staging.appending(path: "again", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var pieces: [(wav: URL, gap: TranscriptGaps.Gap, offset: Double)] = []
            for (k, gap) in gaps.enumerated() {
                let span = TranscriptGaps.piece(for: gap, duration: duration)
                let wav = folder.appending(path: String(format: "again-%03d.wav", k))
                _ = try await Subprocess.run(tools.ffmpeg, ["-y", "-v", "error", "-ss", String(format: "%.3f", span.start),
                                                            "-t", String(format: "%.3f", span.end - span.start), "-i", speech.path, wav.path],
                                             captureStdout: false, timeout: limit(span.end - span.start), control: meter?.control)
                pieces.append((wav, gap, span.start))
            }
            let length = pieces.reduce(0.0) { $0 + TranscriptGaps.piece(for: $1.gap, duration: duration).end - $1.offset }
            _ = try await Subprocess.run(tools.parakeet, pieces.map(\.wav.path) + ["--output-dir", folder.path, "--output-format", "json",
                                                                                   "--output-template", "{filename}"],
                                         captureStdout: false, timeout: limit(length), control: meter?.control)
            let existing = first.sentences.flatMap(\.tokens)
            var added: [ParakeetTranscript.Sentence] = []
            for piece in pieces {
                let json = folder.appending(path: piece.wav.deletingPathExtension().lastPathComponent + ".json")
                guard let heard = ParakeetTranscript.read(json) else {
                    log?.write("\(name): Parakeet wrote nothing for the stretch at \(Format.timecode(piece.gap.start)) heard again.")
                    continue
                }
                added += TranscriptGaps.found(in: heard, offset: piece.offset, gap: piece.gap, existing: existing)
            }
            let words = added.flatMap(\.tokens).filter { EpisodeTranscript.isWord($0.text) }.count
            log?.write("\(name): \(Format.count(gaps.count, "stretch", "stretches")) of speech with no words transcribed again ("
                       + TranscriptGaps.list(gaps.map(\.range)) + "): \(Format.count(words, "word")) found.")
            if !added.isEmpty {
                let (merged, isNew) = TranscriptGaps.merged(first, adding: added)
                try TranscriptGaps.write(merged, isNew: isNew, in: staging)
            }
            return (gaps, words)
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            log?.write("\(name): the stretches with no words could not be transcribed again. "
                       + ((error as? ToolError)?.logLine ?? error.localizedDescription))
            return (gaps, 0)
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
        if result.coverageOK == false, let reaches = result.transcriptReaches, let duration = result.duration, duration - reaches > options.coverageGap {
            reason += " The transcript stops at \(Format.timecode(reaches)) of \(Format.timecode(duration)): listen to the end before trusting it."
        } else if !result.transcriptGaps.isEmpty {
            reason += " The transcript has no words for \(Format.count(result.transcriptGaps.count, "stretch", "stretches")) of speech, at "
                + TranscriptGaps.list(result.transcriptGaps) + ": listen there before trusting it."
        } else if result.faces != nil && result.voices != nil {
            // Since v2 part M6b the people check names who appears and speaks; since M6c the People tab holds the choices.
            reason += " Who appears and speaks is in its People tab."
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
    /// What leaving people out and muting names does to this make (v2 part M6c): the voices left out, from this make's
    /// own voice step and Ivan's names; their stretches from the people file; the words they touch from transcript.json;
    /// the names said aloud he muted. Someone left out while the voices are unknown stops the make (fail closed).
    func leaveOut(people: PeopleSetup, staging: URL, original: URL, duration: Double, namesSaid: NamesSaid?, faces: FacesFound?,
                  voices: VoicesFound?, output: ChoiceOutput = .podcast) async throws -> PeopleApplied {
        let choices = options.choices
        let moments = namesSaid?.moments ?? []
        var leftOut: [Int] = []
        var segments: [VoiceSegment] = []
        if choices.leavesSomeoneOut(of: output) {
            guard let voices, let file = people.folders.read(people.recordingID), let heard = file.voices else {
                throw PipelineFailure(step: .leaveOut, reason: "Voices could not be listened for, so the people you chose to leave out could not be found. "
                                      + "Nothing was made, so nothing could still hold them. Make it again.")
            }
            let names = people.names(for: voices).resolved(faces: faces, voices: voices)
            leftOut = choices.leftOutVoices(voices, names: names, output: output)
            segments = heard.voiceSegments
        }
        var words: [TimeRange]?
        if let data = try? Data(contentsOf: staging.appending(path: TranscriptFiles.asHeard)), let sentences = EpisodeTranscript.sentences(json: data) {
            words = EpisodeTranscript.wordSpans(sentences)
        }
        var plan = LeaveOut.plan(segments: segments, leftOut: Set(leftOut), words: words, mutes: choices.muted(moments), duration: duration)
        if !plan.cuts.isEmpty && words != nil {
            // Then each edge settled on the sound itself (`LeaveOut.plan`, Mac warning 120): the first audio track, the one
            // the episode is made from, decoded once to mono 16 kHz in the staging folder and read only around the edges.
            let audio = try await edgeLevels(original: original, staging: staging, around: plan.cuts, duration: duration)
            plan = LeaveOut.plan(segments: segments, leftOut: Set(leftOut), words: words, mutes: choices.muted(moments), duration: duration,
                                 audio: audio)
        }
        return PeopleApplied(madeAt: Date(), signature: Self.signature(left: leftOut, muted: choices.muted(moments)), leaveOut: plan, check: nil)
    }

    /// The edit plan for this make (v2 part M8a): the people left out of the video worked out as the podcast's are
    /// (`leaveOut`, whole words, edges on the sound; someone left out while the voices are unknown stops the plan, fail
    /// closed), then `PlanStep` on transcript.json and the original, written into the staging folder.
    func planTheEdit(file: URL, staging: URL, duration: Double, capture: CaptureReport?, namesSaid: NamesSaid?, faces: FacesFound?,
                     voices: VoicesFound?) async throws -> PlanStep.Outcome {
        var people = EditPlan.People()
        if let setup = options.people, options.choices.leavesSomeoneOut(of: .video) || !options.choices.names.isEmpty {
            let applied = try await leaveOut(people: setup, staging: staging, original: file, duration: duration, namesSaid: namesSaid,
                                             faces: faces, voices: voices, output: .video)
            people = EditPlan.People(applied: applied.signature, leftOut: applied.leaveOut.voices,
                                     cuts: EpisodeEdits.merged(applied.leaveOut.cuts + applied.leaveOut.overlaps), mutes: applied.leaveOut.mutes)
        }
        var frameRate = capture?.video?.frameRate
        if capture == nil { frameRate = await PlanStep.frameRate(of: file, ffprobe: tools.ffprobe) }
        var setup = PlanStep.Setup(original: file, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                   jobFolder: staging.appending(path: ".planning", directoryHint: .isDirectory), duration: duration,
                                   frameRate: frameRate, edits: options.edits, restored: options.planRestores, people: people,
                                   signature: people.applied, house: options.house)
        // The face the punch-ins follow (v2 part M9a), from this make's people check: never a guess.
        if let people = options.people, let file = people.folders.read(people.recordingID) {
            setup.pictureHeight = Double(file.frameHeight)
            setup.subject = Self.subject(file, faces: faces, names: people.names(for: voices).resolved(faces: faces, voices: voices),
                                         teacher: people.names.teacher, choices: options.choices)
        }
        defer { try? FileManager.default.removeItem(at: setup.jobFolder) }
        let ffmpeg = tools.ffmpeg
        let outcome = try await PlanStep.run(setup, now: Date()) { arguments in
            _ = try await tool(.planEdit, ffmpeg, arguments, captureStdout: false, duration: duration)
        }
        do {
            try PlanStep.write(outcome.plan, into: staging)
        } catch {
            throw PlanStep.Failure(reason: "The plan was made but could not be saved.")
        }
        return outcome
    }

    /// The sightings of the face the punch-ins follow (v2 part M9a): the teacher's face row when Ivan named one and it is
    /// in the video, else the included face row seen most (the people check lists rows most seen first). Times and boxes
    /// only, read from the people file.
    static func subject(_ file: PeopleFile, faces: FacesFound?, names: (faces: [Int: UUID], voices: [Int: UUID]), teacher: UUID?,
                        choices: PeopleChoices) -> [FaceSpot] {
        let rows = (faces?.people.map(\.id) ?? file.people.map(\.id))
        let included = rows.filter { choices.choice(PersonKey.face($0, names: names), for: .video) == .include }
        let row = included.first { teacher != nil && names.faces[$0] == teacher } ?? included.first
        guard let row else { return [] }
        return file.tracks.filter { $0.person == row }.flatMap { track in
            track.boxes.compactMap { b in b.count >= 5 ? FaceSpot(time: b[0], box: FaceBox(x: b[1], y: b[2], width: b[3], height: b[4])) : nil }
        }.sorted { $0.time < $1.time }
    }

    /// The levels of the original's first audio track for `EdgeLevels.reach` seconds either side of each cut's edges.
    /// The decoded sound is deleted before this returns.
    func edgeLevels(original: URL, staging: URL, around cuts: [TimeRange], duration: Double) async throws -> EdgeLevels {
        let raw = staging.appending(path: "leave-out-edges.raw")
        defer { try? FileManager.default.removeItem(at: raw) }
        _ = try await tool(.leaveOut, tools.ffmpeg, ["-y", "-v", "error", "-i", original.path, "-map", "0:a:0", "-vn", "-ac", "1",
                                                      "-ar", String(EdgeLevels.sampleRate), "-f", "f32le", raw.path],
                           captureStdout: false, duration: duration)
        let handle = try FileHandle(forReadingFrom: raw)
        defer { try? handle.close() }
        var levels = EdgeLevels()
        for cut in cuts {
            for edge in [cut.start, cut.end] {
                let start = max(0, edge - EdgeLevels.reach)
                let first = UInt64(start * Double(EdgeLevels.sampleRate))
                let count = Int(2 * EdgeLevels.reach * Double(EdgeLevels.sampleRate))
                try handle.seek(toOffset: first * 4)
                guard let data = try handle.read(upToCount: count * 4), !data.isEmpty else { continue }
                let samples = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                levels.pieces.append(.init(start: Double(first) / Double(EdgeLevels.sampleRate), levels: EdgeLevels.levels(samples)))
            }
        }
        return levels
    }

    /// The same line `PeopleChoices.podcastSignature` makes, from what a make applied.
    static func signature(left: [Int], muted: [NameMoment]) -> String {
        if left.isEmpty && muted.isEmpty { return "" }
        return "out:" + left.sorted().map(String.init).joined(separator: ",") + ";mute:" + muted.map(\.key).sorted().joined(separator: ",")
    }

    private func followEpisode(in folder: URL, clock: EpisodeClock, label: String, fileName: String, mutes: [TimeRange] = []) throws
        -> (removedWords: Int, corrections: [Lexicon.Correction]) {
        guard let data = try? Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard)),
              let sentences = EpisodeTranscript.sentences(json: data) else {
            throw PipelineFailure(step: .episodeTranscript, reason: "The transcript could not be matched to the episode: Parakeet's words with their times (transcript.json) could not be read.")
        }
        let made = EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: options.applyLexicon, mutes: mutes)
        let formats = options.transcriptFormats
        var files: [(TranscriptFormat, String)] = []
        if formats.contains(.srt) { files.append((.srt, EpisodeTranscript.srt(made.cues))) }
        if formats.contains(.vtt) { files.append((.vtt, EpisodeTranscript.vtt(made.cues))) }
        if formats.contains(.txt) && (made.removedWords > 0 || !mutes.isEmpty) { files.append((.txt, EpisodeTranscript.text(made.cues))) }
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

    // MARK: The edited video (v2 part M8b)

    /// What the gate reads about who is in this make: the people check it just ran and Ivan's names and choices.
    func peopleFacts(result: PipelineResult) -> OutputGate.People {
        let names = options.people?.names(for: result.voices).resolved(faces: result.faces, voices: result.voices) ?? ([:], [:])
        return OutputGate.People(faces: options.people == nil ? nil : result.faces, voices: options.people == nil ? nil : result.voices,
                                 names: names, choices: options.choices)
    }

    /// The video's setup for this make, or nil when it may not be made (no plan, or the gate refuses who is in it).
    func videoSetup(file: URL, staging: URL, label: String, result: PipelineResult) -> VideoStep.Setup? {
        guard let plan = result.editPlan else { return nil }
        let people = peopleFacts(result: result)
        guard OutputGate.refusal(people) == nil else { return nil }
        // Who is hidden and left out (v2 part M8d): read from the people check's own file, never guessed.
        var hiding = HidePlan(), tracks: [PictureOutputCheck.Track] = [], segments: [VoiceSegment] = []
        if let setup = options.people, let file = setup.folders.read(setup.recordingID) {
            hiding = VideoHiding.plan(file, names: people.names, choices: people.choices)
            tracks = PictureOutputCheck.tracks(file) { row in
                people.choices.choice(PersonKey.face(row ?? 0, names: people.names), for: .video) != .include
            }
            segments = file.voices?.voiceSegments ?? []
        }
        // The writer's chapter times are on the episode's clock when the transcript followed the episode, else the original's.
        let clock = result.written?.clock == "episode" ? result.clock : nil
        let facts = options.video
        return VideoStep.Setup(original: file, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                               title: facts.title, notes: facts.notes, written: result.written,
                               writtenToOriginal: { t in
                                   guard let clock else { return t }
                                   return clock.originalTime(t)
                               },
                               recordedAt: facts.recordedAt, label: label, people: people, hiding: hiding, faceTracks: tracks,
                               voiceSegments: segments, folders: options.people?.folders, control: meter?.control,
                               log: { [log] line in log?.write("\(label): the video's people check. " + line) })
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
    static let madeNames: Set<String> = Set(["episode.mp3", "REPORT.md", "speech.wav", TranscriptFiles.asHeard, PodcastPackage.folderName, EditPlan.fileName,
                                                   VideoStep.folderName, HiddenFaces.fileName]
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
