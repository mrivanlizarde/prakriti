import Foundation
import SwiftData

// The data layer: SwiftData, one SQLite store per mode under
// ~/Library/Application Support/Prakriti/ (never under ~/Documents, which syncs to iCloud).
// Every stored property has a default so later additions migrate without a hand-written plan.
// Enums are stored as their raw strings and read through typed accessors, because predicates
// over raw strings are the part of SwiftData that has been reliable.

/// A folder Prakriti watches (or the drop folder), and what it makes from each recording there.
@Model
final class Source {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var path: String = ""
    var kindRaw: String = SourceKind.folder.rawValue
    var modeRaw: String = SourceMode.automatic.rawValue
    var addedAt: Date = Date.distantPast
    /// When Prakriti first looked inside this folder. Whatever was already there at that moment is
    /// listed and left alone (engine v0's "first start" rule), so adding a folder of old recordings
    /// never starts work on all of them. Nil until the first look.
    var baselinedAt: Date?
    /// Files in this folder that Ivan removed from the library (v2 part M3a, Remove from Library). The
    /// watcher passes over them, so a removed recording is not found again as new and made again; adding
    /// one by hand takes it off this list. Paths only: nothing about the recording itself is kept.
    var forgottenPaths: [String] = []
    /// Which named person speaks into which microphone track in this folder (v2 part M6b, research-people.md 2.5:
    /// "Track 2 is Gabriel's microphone"), as JSON of track number to `Person` id, read through `microphones`. Set once
    /// from a recording's People tab; every recording from the folder heard on that track takes the name.
    var microphonesJSON: String?

    @Relationship(deleteRule: .nullify, inverse: \Recording.source)
    var recordings: [Recording] = []

    /// This folder's own output choices. Missing kinds fall back to the defaults on the Outputs screen.
    @Relationship(deleteRule: .cascade, inverse: \OutputSetting.source)
    var outputSettings: [OutputSetting] = []

    init(name: String, path: String, kind: SourceKind = .folder, mode: SourceMode = .automatic, addedAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.kindRaw = kind.rawValue
        self.modeRaw = mode.rawValue
        self.addedAt = addedAt
    }

    var kind: SourceKind {
        get { SourceKind(rawValue: kindRaw) ?? .folder }
        set { kindRaw = newValue.rawValue }
    }

    var mode: SourceMode {
        get { SourceMode(rawValue: modeRaw) ?? .askFirst }
        set { modeRaw = newValue.rawValue }
    }

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    /// Track number to the named person whose microphone it is.
    var microphones: [Int: UUID] {
        get {
            guard let data = microphonesJSON?.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([Int: UUID].self, from: data)) ?? [:]
        }
        set {
            microphonesJSON = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    func setting(for kind: OutputKind) -> OutputSetting? {
        outputSettings.first { $0.kind == kind }
    }
}

/// One recording: a file Prakriti found or was given, and everything it knows about it.
@Model
final class Recording {
    @Attribute(.unique) var id: UUID = UUID()
    var filePath: String = ""
    var title: String = ""
    var notes: String = ""
    var recordedAt: Date?
    var foundAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var duration: Double?
    var sizeBytes: Int64 = 0

    var statusRaw: String = RecordingStatus.found.rawValue
    /// One plain sentence: why it needs a decision, why it was skipped, why it could not finish.
    var statusReason: String?
    /// The step running now, named ("Writing the transcript"), never "Processing".
    var currentStep: String?

    var kindRaw: String = RecordingKind.unknown.rawValue
    var hasSerenity: Bool = false

    /// What Prakriti does next without Ivan (WorkIntent), and how many automatic tries in a row
    /// stopped. Three stopped tries make it Couldn't finish, with one notice (engine v0's rule).
    var intentRaw: String = WorkIntent.none.rawValue
    var failedTries: Int = 0
    /// Made or seen by engine v0 before the switch-over, read from ~/Prakriti/state.json.
    var fromEngineV0: Bool = false

    // What the sound check measured on the original.
    var loudestDB: Double?
    var averageDB: Double?
    var inputLUFS: Double?

    // What the checks measured on the finished files.
    var loudnessLUFS: Double?
    var truePeakDBFS: Double?
    var transcriptReaches: Double?
    var wordCount: Int?
    /// The transcript reaches within two minutes of the end and has words for every stretch of speech (the coverage
    /// check; the second half since v2 part TXGAP).
    var coverageOK: Bool?
    /// Stretches of 3 s or more of speech the transcript still has no words for (v2 part TXGAP), on the original's clock.
    var transcriptGaps: [TimeRange] = []
    /// The episode's own length, and the silence trimmed from the recording's start and end.
    var episodeDuration: Double?
    var silenceTrimmedStart: Double?
    var silenceTrimmedEnd: Double?
    /// How many known mis-hearings the Yoga Marga word list fixed.
    var wordListFixes: Int?
    /// The files the last finished make left in the output folder, by name.
    var madeFiles: [String] = []

    // Ivan's edits, set on the recording's page and used by Make Again (milestone 5): where the
    // episode starts and ends, and the sections cut out, in seconds on the original's clock.
    var trimStart: Double?
    var trimEnd: Double?
    var cuts: [TimeRange] = []
    /// The edits the episode in the folder was made with. When they differ from the ones above, the
    /// page says the trim and cuts are not in the episode yet, and Approve waits for Make Again.
    var madeTrimStart: Double?
    var madeTrimEnd: Double?
    var madeCuts: [TimeRange] = []
    /// Where the original's moments play in the episode in the folder: the parts of the original it
    /// kept, in order, after an intro this long. Lets a transcript line play the episode from the
    /// right place.
    var episodeParts: [TimeRange] = []
    var episodeIntro: Double?
    /// When the files in the folder were made.
    var madeAt: Date?

    var outputFolder: String?
    var approvedFolder: String?
    var approvedAt: Date?
    /// The files Approve copied into the approved folder, by name.
    var approvedFiles: [String] = []

    /// Titles, show notes and chapters as last written and checked (milestone 6): a WrittenPackage
    /// as JSON, read through `written`. Kept as text so the store migrates on its own.
    var writtenJSON: String?
    /// Why the last try at writing them did not give anything, in one plain sentence, or nil.
    var writingProblem: String?
    /// The accuracy checklist's claims Ivan has ticked in the Checks tab (v2 part M3a), by their words.
    /// A claim written again in other words starts unticked. Ticking is his own review; it never changes
    /// a file or an approval.
    var checkedClaims: [String] = []

    /// The podcast-ready episode (10 Oct): this episode's number and season, set on its page (both
    /// optional; Apple asks for them only for a serial show), and what the last podcast-ready make
    /// measured and checked, a PodcastReadyRecord as JSON, read through `podcastReady`.
    var episodeNumber: Int?
    var seasonNumber: Int?
    var podcastReadyJSON: String?
    /// Why the podcast-ready files were not made, in one plain sentence, or nil.
    var podcastReadyProblem: String?

    /// What the capture check measured when the recording was last checked (v2 part M4b): a CaptureReport as
    /// JSON, read through `capture`. Kept for every outcome, a test under 60 s included, because it is about
    /// how the file was recorded, not about what was made from it. Nil for a recording found before M4b.
    var captureJSON: String?

    /// What the face step found when the recording was last looked at (v2 part M6a): a FacesFound as JSON, read
    /// through `faces`. Counts, times and one key moment per row of the People tab; never a picture or a print.
    /// Nil for a recording found before M6a, or not looked at yet.
    var facesJSON: String?

    /// What the voice step found when the recording was last listened to (v2 part M6b): a VoicesFound as JSON, read
    /// through `voices`. Times, counts and links to face rows; never a voice print. Nil until the voice step ran.
    var voicesJSON: String?

    /// Who Ivan named in this recording (v2 part M6b): Who Is Teaching and Name for This Recording, a PeopleNames as
    /// JSON, read through `names`. Names only, never anything about a face or a voice.
    var namesJSON: String?

    /// Ivan's choices of who is in each output, and the names said aloud he kept or muted (v2 part M6c): a
    /// PeopleChoices as JSON, read through `choices`. Keys and words only, never anything about a face or a voice.
    var choicesJSON: String?

    /// The names said aloud the last finished make found in the transcript (v2 part M6c): a NamesSaid as JSON, read
    /// through `namesSaid`. Their times and the words as heard. Nil until a make with the people check looked.
    var namesSaidJSON: String?

    /// What the last finished make applied of the choices (who was left out, the cuts, the muted names) and what the
    /// audio output check found in the files it made (v2 part M6c): a PeopleApplied as JSON, read through
    /// `peopleApplied`. Nil when nobody was left out and nothing was muted.
    var peopleAppliedJSON: String?
    /// The edited video the last finished make made and checked (v2 part M8b): a VideoRecord as JSON, read through `video`,
    /// and why it was not made when it was asked for. Additions with nil defaults, so the store migrates on its own.
    var videoJSON: String?
    var videoProblem: String?
    /// Stretches the edit plan took out that Ivan brought back from the Viewer (v2 part M8c, Restore on a span of the plan):
    /// pauses, filler words, words said twice and false starts, on the original's clock. The next plan keeps each as recorded.
    /// An addition with an empty default, so the store migrates on its own. Ivan's own trim and cuts stay in `cuts`.
    var planRestores: [TimeRange] = []
    /// Ivan's direction for this recording (v2 part M9c): his words, presets, pace and length, and the chips he removed, as JSON
    /// (`RecordingDirection`). Nil until he sets one.
    var directionJSON: String?
    /// Every video made of this recording that is still kept, and which one is in use (v2 part M9d, design spec 3.5.3 and 3.7): an
    /// `EditVersions` as JSON. Nil until a video is made; an addition with a nil default, so the store migrates on its own.
    var versionsJSON: String?

    var source: Source?

    @Relationship(deleteRule: .cascade, inverse: \Run.recording)
    var runs: [Run] = []

    /// This recording's own output choices, overriding its folder's and the defaults.
    @Relationship(deleteRule: .cascade, inverse: \OutputSetting.recording)
    var outputSettings: [OutputSetting] = []

    init(filePath: String, title: String = "", recordedAt: Date? = nil, foundAt: Date = .now,
         duration: Double? = nil, sizeBytes: Int64 = 0, status: RecordingStatus = .found, kind: RecordingKind = .unknown) {
        self.id = UUID()
        self.filePath = filePath
        self.title = title
        self.recordedAt = recordedAt
        self.foundAt = foundAt
        self.updatedAt = foundAt
        self.duration = duration
        self.sizeBytes = sizeBytes
        self.statusRaw = status.rawValue
        self.kindRaw = kind.rawValue
    }

    var status: RecordingStatus {
        get { RecordingStatus(rawValue: statusRaw) ?? .found }
        set { statusRaw = newValue.rawValue }
    }

    var kind: RecordingKind {
        get { RecordingKind(rawValue: kindRaw) ?? .unknown }
        set { kindRaw = newValue.rawValue }
    }

    var intent: WorkIntent {
        get { WorkIntent(rawValue: intentRaw) ?? .none }
        set { intentRaw = newValue.rawValue }
    }

    var fileName: String { (filePath as NSString).lastPathComponent }

    /// What the privacy lock reads about this recording (part LOCK, Wed 14 Oct): who the people check found, each named
    /// person's release read from the store, and anyone Ivan set to Leave Out. The kind and a name said aloud
    /// (`hasSerenity`) no longer lock anything.
    var lockSubject: LockSubject { LockSubject(people: peopleFacts) }

    /// What the people check found and Ivan's choices, as the lock reads them.
    var peopleFacts: PeopleFacts {
        PeopleFacts.from(faces: faces, voices: voices, names: resolvedNames, people: namedPeople, choices: choices)
    }

    /// The people named in Settings, Privacy, as the lock and the People tab read them. None when the recording is
    /// not in a store (then nobody is named).
    var namedPeople: [NamedPerson] {
        ((try? modelContext?.fetch(FetchDescriptor<Person>())) ?? []).map(\.named)
    }

    /// The named people whose role is Teacher (v2 part M9b, for the lower third).
    var teacherIDs: Set<UUID> {
        Set(((try? modelContext?.fetch(FetchDescriptor<Person>())) ?? []).filter { $0.role == .teacher }.map(\.id))
    }

    /// Ivan's names for this recording, with the folder's microphones applied (a voice heard on a track the folder
    /// names, and not named here by hand).
    var resolvedNames: PeopleNames {
        var names = self.names
        if let voices, voices.source == .tracks, let microphones = source?.microphones {
            for voice in voices.voices where names.voices[voice.id] == nil {
                if let track = voice.track, let person = microphones[track] { names.voices[voice.id] = person }
            }
        }
        return names
    }

    /// What the voice step found, or nil.
    var voices: VoicesFound? { VoicesFound.decode(voicesJSON) }

    /// Ivan's own names in this recording.
    var names: PeopleNames {
        get { PeopleNames.decode(namesJSON) }
        set { namesJSON = newValue.isEmpty ? nil : newValue.json() }
    }

    /// Who is in each output, and the names said aloud kept or muted (v2 part M6c).
    var choices: PeopleChoices {
        get { PeopleChoices.decode(choicesJSON) }
        set { choicesJSON = newValue.isEmpty ? nil : newValue.json() }
    }

    /// The names said aloud the last make found, or nil.
    var namesSaid: NamesSaid? { NamesSaid.decode(namesSaidJSON) }

    /// What the last make applied of the choices, and its audio output check, or nil (nothing left out or muted).
    var peopleApplied: PeopleApplied? { PeopleApplied.decode(peopleAppliedJSON) }

    /// The names muted in the files in the folder, on the original's clock: Write Again and Update Podcast-Ready Files
    /// write "[name]" for them as the make did.
    var madeMutes: [TimeRange] { peopleApplied?.leaveOut.mutes ?? [] }

    /// What the choices on the page would make of the podcast, as `PeopleChoices.podcastSignature`.
    var podcastSignature: String {
        choices.podcastSignature(voices: voices, names: resolvedNames.resolved(faces: faces, voices: voices), moments: namesSaid?.moments ?? [])
    }

    /// The choices on the page are not in the episode yet: Make Again first (Mac warning 36's rule, for people).
    var choicesPending: Bool { podcastSignature != (peopleApplied?.signature ?? "") }

    /// Only models on this Mac may read it (PrivacyLock.decide). Fails closed.
    var isPrivacyLocked: Bool { PrivacyLock.decide(lockSubject).isLocked }

    /// The titles, show notes and chapters last written, or nil.
    var written: WrittenPackage? { WrittenPackage.decode(writtenJSON) }

    /// What the last podcast-ready make measured and checked, or nil.
    var podcastReady: PodcastReadyRecord? { PodcastReadyRecord.decode(podcastReadyJSON) }

    /// The edited video (v2 part M8b), or nil.
    var video: VideoRecord? { VideoRecord.decode(videoJSON) }

    /// The videos made of this recording, kept as versions (v2 part M9d).
    var versions: EditVersions {
        get { EditVersions.decode(versionsJSON) }
        set { versionsJSON = newValue.versions.isEmpty ? nil : newValue.json() }
    }

    /// Ivan's direction for this recording (v2 part M9c); empty until he sets one.
    var direction: RecordingDirection {
        get { RecordingDirection.decode(directionJSON) }
        set { directionJSON = newValue.json() }
    }

    /// What the capture check measured, or nil.
    var capture: CaptureReport? { CaptureReport.decode(captureJSON) }

    /// What the face step found, or nil.
    var faces: FacesFound? { FacesFound.decode(facesJSON) }

    /// The facts the podcast-ready package reads from this recording.
    var podcastFacts: PodcastEpisodeFacts {
        PodcastEpisodeFacts(title: title, notes: notes, episodeNumber: episodeNumber, seasonNumber: seasonNumber, recordedAt: recordedAt ?? foundAt,
                            label: Format.dayLabel(sessionDate), kind: kind, fileName: fileName)
    }

    /// The date the recording was made, else the date it was found. Used for its label ("Sun 13 Sep").
    var sessionDate: Date { recordedAt ?? foundAt }

    var latestRun: Run? { runs.max { $0.startedAt < $1.startedAt } }

    /// This recording has its own output choices, set on its page, rather than its folder's.
    var hasOwnOutputs: Bool { !outputSettings.isEmpty }

    /// The trim and cuts on its page.
    var edits: EpisodeEdits {
        get { EpisodeEdits(start: trimStart, end: trimEnd, cuts: cuts) }
        set {
            trimStart = newValue.start
            trimEnd = newValue.end
            cuts = EpisodeEdits.merged(newValue.cuts)
        }
    }

    /// The trim and cuts the episode in the folder was made with.
    var madeEdits: EpisodeEdits { EpisodeEdits(start: madeTrimStart, end: madeTrimEnd, cuts: madeCuts) }

    /// The trim or cuts on the page are not in the episode yet: Make Again first.
    var editsPending: Bool { !edits.matches(madeEdits) }

    /// Where the original's moments play in the episode in the folder. A recording made before
    /// milestone 5 kept one part: all of it (engine v0), or what the silence trim kept.
    var episodeClock: EpisodeClock? {
        guard episodeDuration != nil || fromEngineV0, let duration else { return nil }
        if !episodeParts.isEmpty {
            return EpisodeClock(intro: episodeIntro ?? 0, segments: episodeParts.map { Mastering.Span(start: $0.start, end: $0.end) })
        }
        let start = silenceTrimmedStart ?? 0, end = duration - (silenceTrimmedEnd ?? 0)
        return EpisodeClock(intro: 0, segments: [Mastering.Span(start: start, end: max(start, end))])
    }

    /// Newest first: the date it was made, then when it was found, then its path. Several clips can
    /// share one session's date (all cut from the same talk), and sorting on the date alone left
    /// their order to chance, so the same list drew differently from one look to the next.
    static func newestFirst(_ a: Recording, _ b: Recording) -> Bool {
        if a.sessionDate != b.sessionDate { return a.sessionDate > b.sessionDate }
        if a.foundAt != b.foundAt { return a.foundAt > b.foundAt }
        return a.filePath < b.filePath
    }
}

/// A start and end time inside a recording, in seconds.
struct TimeRange: Codable, Hashable, Sendable {
    var start: Double
    var end: Double
}

/// One output's switch and settings. Belongs to a recording (its own choice), a source (that
/// folder's choice) or to neither (the default on the Outputs screen). Resolution goes
/// recording, then source, then default.
@Model
final class OutputSetting {
    @Attribute(.unique) var id: UUID = UUID()
    var kindRaw: String = OutputKind.podcastEpisode.rawValue
    var isOn: Bool = false

    // Podcast episode
    var loudnessTarget: Double = -16
    var peakCeiling: Double = -1
    var trimSilence: Bool = true
    var introPath: String?
    var outroPath: String?
    var channelsRaw: String = AudioChannels.mono.rawValue

    // Transcript
    var transcriptFormatsRaw: [String] = TranscriptFormat.allCases.map(\.rawValue)
    var applyLexicon: Bool = true

    // Podcast-ready episode (10 Oct). Its trim, intro and outro are the podcast episode's; these are
    // its own. `channelsRaw` above is used too: the podcast-ready setting keeps its own layout.
    var showName: String = ""
    var hostName: String = ""
    var artworkPath: String?
    var explicitContent: Bool = false
    var bitrateKbps: Int = 96
    var noiseReduction: Bool = false
    var aiVoice: Bool = false
    /// How the show numbers its episodes, and Ivan's closing line for the show notes (11 Oct).
    var numberingRaw: String = PodcastNumbering.none.rawValue
    var callToAction: String = ""

    var source: Source?
    var recording: Recording?

    init(kind: OutputKind, isOn: Bool? = nil) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.isOn = kind.isBuilt && (isOn ?? kind.isOnByDefault)
    }

    var kind: OutputKind { OutputKind(rawValue: kindRaw) ?? .podcastEpisode }

    var numbering: PodcastNumbering {
        get { PodcastNumbering(rawValue: numberingRaw) ?? .none }
        set { numberingRaw = newValue.rawValue }
    }

    var channels: AudioChannels {
        get { AudioChannels(rawValue: channelsRaw) ?? .mono }
        set { channelsRaw = newValue.rawValue }
    }

    var transcriptFormats: Set<TranscriptFormat> {
        get { Set(transcriptFormatsRaw.compactMap(TranscriptFormat.init(rawValue:))) }
        set { transcriptFormatsRaw = TranscriptFormat.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    /// A copy with the same choices, for giving a folder or a recording its own setting.
    func copy() -> OutputSetting {
        let c = OutputSetting(kind: kind, isOn: isOn)
        c.loudnessTarget = loudnessTarget
        c.peakCeiling = peakCeiling
        c.trimSilence = trimSilence
        c.introPath = introPath
        c.outroPath = outroPath
        c.channelsRaw = channelsRaw
        c.transcriptFormatsRaw = transcriptFormatsRaw
        c.applyLexicon = applyLexicon
        c.copySettings(from: self)
        return c
    }

    /// The podcast-ready settings, copied from another setting.
    func copySettings(from other: OutputSetting) {
        showName = other.showName
        hostName = other.hostName
        artworkPath = other.artworkPath
        explicitContent = other.explicitContent
        bitrateKbps = other.bitrateKbps
        noiseReduction = other.noiseReduction
        aiVoice = other.aiVoice
        numberingRaw = other.numberingRaw
        callToAction = other.callToAction
    }

    /// The podcast-ready settings as the pipeline reads them.
    var podcastReadySettings: PodcastReadySettings {
        PodcastReadySettings(showName: showName.trimmingCharacters(in: .whitespacesAndNewlines), hostName: hostName.trimmingCharacters(in: .whitespacesAndNewlines),
                             artworkPath: artworkPath, explicit: explicitContent, channels: channels, bitrateKbps: bitrateKbps,
                             noiseReduction: noiseReduction, aiVoice: aiVoice, numbering: numbering,
                             callToAction: callToAction.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// One pass of work: a sweep that found nothing, or one recording processed. Every run is kept,
/// including "nothing new", because a silent engine and a quiet day must look different.
@Model
final class Run {
    @Attribute(.unique) var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var endedAt: Date?
    var triggerRaw: String = RunTrigger.timer.rawValue
    var outcomeRaw: String = RunOutcome.running.rawValue
    var summary: String = ""
    var steps: [RunStep] = []

    var recording: Recording?

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.run)
    var entries: [LogEntry] = []

    init(startedAt: Date = .now, trigger: RunTrigger, outcome: RunOutcome = .running, summary: String = "", steps: [RunStep] = []) {
        self.id = UUID()
        self.startedAt = startedAt
        self.triggerRaw = trigger.rawValue
        self.outcomeRaw = outcome.rawValue
        self.summary = summary
        self.steps = steps
    }

    var trigger: RunTrigger { RunTrigger(rawValue: triggerRaw) ?? .timer }

    var outcome: RunOutcome {
        get { RunOutcome(rawValue: outcomeRaw) ?? .running }
        set { outcomeRaw = newValue.rawValue }
    }

    var seconds: Double? { endedAt.map { $0.timeIntervalSince(startedAt) } }
}

/// One step of a run, with its timing. Stored inside the run, in order.
struct RunStep: Codable, Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var state: StepState
    var seconds: Double?
    /// One plain sentence about the result ("Reaches 15:47 of 15:48."). Never transcript text.
    var detail: String?
}

/// One line in the Activity list. Carries numbers and file names only: never a student's name,
/// never transcript text (SCOPE 7.18).
@Model
final class LogEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var at: Date = Date.distantPast
    var levelRaw: String = LogLevel.info.rawValue
    var message: String = ""
    var run: Run?

    init(at: Date = .now, level: LogLevel = .info, message: String) {
        self.id = UUID()
        self.at = at
        self.levelRaw = level.rawValue
        self.message = message
    }

    var level: LogLevel { LogLevel(rawValue: levelRaw) ?? .info }
}


/// One video made of a recording, kept as a version (v2 part M9d, design spec 3.5.3: "Version 3. Energetic, Faster Cuts. Made Sat 10
/// Oct, 9:41 pm. 11:02 long."): what made it (the direction in a few words, its chips and the plan's lines), when, how long it is,
/// its files, and the video's own record, so it can be played and used again. The files are copies (APFS clones, no extra space
/// until one changes) in `<outputs>/<recording>/Versions/Version N/`: its Video folder, `edit-plan.json` and `video-hiding.json`.
struct EditVersion: Codable, Equatable, Identifiable, Sendable {
    var number: Int
    var madeAt: Date
    /// "Energetic, Faster Cuts", or "Clear, the house style" when no direction made it.
    var made: String
    var chips: [String] = []
    var planLines: [String] = []
    var duration: Double
    var files: [String] = []
    var video: VideoRecord

    var id: Int { number }

    /// "Version 3. Energetic, Faster Cuts. Made Thu 15 Oct, 9:41 pm. 11:02 long."
    var line: String {
        "Version \(number). \(EditVersion.sentence(made)) Made \(Format.dayAndTime(madeAt)). \(Format.timecode(duration)) long."
    }

    /// Words closed by a full stop, unless they already end on one (inside a closing quotation mark too).
    static func sentence(_ words: String) -> String {
        words.hasSuffix(".") || words.hasSuffix(".\u{201D}") || words.hasSuffix("?\u{201D}") || words.hasSuffix("!\u{201D}") ? words : words + "."
    }

    /// Its folder inside a recording's output folder.
    static func folder(_ number: Int, in output: URL) -> URL {
        output.appending(path: EditVersions.folderName, directoryHint: .isDirectory).appending(path: "Version \(number)", directoryHint: .isDirectory)
    }
}

/// A recording's versions, newest last, and the one in use (its files are the ones in the recording's own folder).
struct EditVersions: Codable, Equatable, Sendable {
    static let folderName = "Versions"
    /// Versions kept; the oldest beyond this go (their files with them), never the one in use.
    static let kept = 5
    /// The files of the recording's folder a version holds.
    static let names: Set<String> = [VideoStep.folderName, EditPlan.fileName, HiddenFaces.fileName]

    var current: Int?
    var versions: [EditVersion] = []

    var next: Int { (versions.map(\.number).max() ?? 0) + 1 }
    var inUse: EditVersion? { versions.first { $0.number == current } }

    func version(_ number: Int) -> EditVersion? { versions.first { $0.number == number } }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String?) -> EditVersions {
        guard let json, let data = json.data(using: .utf8) else { return EditVersions() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(EditVersions.self, from: data)) ?? EditVersions()
    }

    /// What made a plan, in a few words: its style, the presets beyond the style, and Ivan's own words in quotes.
    static func made(by plan: EditPlan?) -> String {
        guard let plan else { return "The house style" }
        let style = StyleName(rawValue: plan.style)?.title ?? plan.style
        guard let direction = plan.direction else { return "\(style), the house style" }
        var parts = [style]
        for preset in direction.presets ?? [] where preset != .energetic && preset != .calm && preset != .storyFirst { parts.append(preset.title) }
        let prompt = direction.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty { parts.append("\u{201C}" + (prompt.count > 60 ? String(prompt.prefix(57)) + "..." : prompt) + "\u{201D}") }
        if let pace = direction.pace, pace != .balanced { parts.append(pace.title) }
        if let length = direction.length, length != .everything { parts.append(length.title) }
        return parts.joined(separator: ", ")
    }
}
