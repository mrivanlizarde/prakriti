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

    // What the checks measured on the finished files.
    var loudnessLUFS: Double?
    var truePeakDBFS: Double?
    var transcriptReaches: Double?
    var wordCount: Int?

    // Edits for "Make again" (milestone 5).
    var trimStart: Double?
    var trimEnd: Double?
    var cuts: [TimeRange] = []

    var outputFolder: String?
    var approvedFolder: String?
    var approvedAt: Date?

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

    var fileName: String { (filePath as NSString).lastPathComponent }

    /// A class, or anything with Serenity in it, may only be read by a model on this Mac.
    var isPrivacyLocked: Bool { kind == .lesson || hasSerenity }

    /// The date the recording was made, else the date it was found. Used for its label ("Sun 13 Sep").
    var sessionDate: Date { recordedAt ?? foundAt }

    var latestRun: Run? { runs.max { $0.startedAt < $1.startedAt } }

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

    var source: Source?
    var recording: Recording?

    init(kind: OutputKind, isOn: Bool? = nil) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.isOn = kind.isBuilt && (isOn ?? kind.isOnByDefault)
    }

    var kind: OutputKind { OutputKind(rawValue: kindRaw) ?? .podcastEpisode }

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
        return c
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
