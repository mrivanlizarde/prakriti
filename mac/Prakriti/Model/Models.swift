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
    /// The transcript reaches within two minutes of the end (the coverage check).
    var coverageOK: Bool?
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

    /// A class, or anything with Serenity in it, may only be read by a model on this Mac.
    /// `hasSerenity` is set when a transcript says her name (Privacy.mentionsSerenity) and never unset.
    var isPrivacyLocked: Bool { kind == .lesson || hasSerenity }

    /// The titles, show notes and chapters last written, or nil.
    var written: WrittenPackage? { WrittenPackage.decode(writtenJSON) }

    /// What the last podcast-ready make measured and checked, or nil.
    var podcastReady: PodcastReadyRecord? { PodcastReadyRecord.decode(podcastReadyJSON) }

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
