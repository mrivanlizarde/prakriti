import Foundation

// The words Prakriti uses everywhere. One status vocabulary (SCOPE 9.2): the notification a person
// reads and the screen it opens say the same thing. Every string here is UI text, so: plain words,
// no em dashes, no "we", no "Processing...".

/// Where a recording is. The engine owns Found to Waiting for your yes; Approve copies the finished
/// files to ~/Prakriti/Approved. Scheduled, Live and Taken down belong to the web app, later.
/// Since v2 part M3a the words for `readyForYourYes` are "Waiting for your yes" (design spec C1), so
/// "Ready" means only approved; the stored raw value is unchanged, so nothing migrates.
enum RecordingStatus: String, Codable, CaseIterable, Sendable {
    case found
    case working
    case readyForYourYes
    case needsADecision
    case approved
    case skipped
    case couldntFinish

    var title: String {
        switch self {
        case .found: "Found"
        case .working: "Working"
        case .readyForYourYes: "Waiting for your yes"
        case .needsADecision: "Needs a decision"
        case .approved: "Approved"
        case .skipped: "Skipped"
        case .couldntFinish: "Couldn't finish"
        }
    }

    /// SF Symbols that differ by shape, not only by color (HIG, accessibility).
    var symbol: String {
        switch self {
        case .found: "plus.circle"
        case .working: "arrow.triangle.2.circlepath"
        case .readyForYourYes: "checkmark.circle"
        case .needsADecision: "questionmark.circle"
        case .approved: "checkmark.seal"
        case .skipped: "minus.circle"
        case .couldntFinish: "exclamationmark.triangle"
        }
    }

    /// The three states that wait on Ivan. Needs You lists exactly these.
    var needsYou: Bool {
        switch self {
        case .readyForYourYes, .needsADecision, .couldntFinish: true
        default: false
        }
    }
}

/// What kind of session a recording is. A class (or anything with Serenity in it) is privacy
/// locked: only models on this Mac may read it.
enum RecordingKind: String, Codable, CaseIterable, Sendable {
    case talk
    case lesson = "class"
    case conversation
    case test
    case unknown

    var title: String {
        switch self {
        case .talk: "Talk"
        case .lesson: "Class"
        case .conversation: "Conversation"
        case .test: "Test"
        case .unknown: "Not set"
        }
    }
}

/// Everything Prakriti can make from a recording. Five are built (the podcast-ready episode since 11
/// Oct); five are shown and marked "Not built yet" so the plan is visible without pretending.
enum OutputKind: String, Codable, CaseIterable, Sendable {
    case podcastEpisode
    /// The finished episode for a podcast host: its own mastering chain, tags, artwork, chapters,
    /// captions, a text file and an upload checklist. The podcast episode above stays the quick draft.
    case podcastReady
    case transcript
    case checksAndReport
    case titlesNotesChapters
    case editedVideo
    case thumbnails
    case shorts
    case knowledgeBase
    case voiceDataset

    var title: String {
        switch self {
        case .podcastEpisode: "Podcast episode"
        case .podcastReady: "Podcast-ready episode"
        case .transcript: "Transcript"
        case .checksAndReport: "Checks and report"
        case .titlesNotesChapters: "Titles, show notes and chapters"
        case .editedVideo: "Edited video"
        case .thumbnails: "Three thumbnails"
        case .shorts: "Shorts"
        case .knowledgeBase: "Knowledge base"
        case .voiceDataset: "Voice dataset"
        }
    }

    var summary: String {
        switch self {
        case .podcastEpisode: "An MP3 at podcast loudness, ready to listen to."
        case .podcastReady: "The finished MP3 for a podcast host, with its tags, chapters, captions and an upload checklist."
        case .transcript: "The words, with times, in the formats you choose."
        case .checksAndReport: "Length, sound, loudness and coverage, in one short report."
        case .titlesNotesChapters: "Written by the model you choose for writing."
        case .editedVideo: "The talk cut to the teaching, ready for YouTube."
        case .thumbnails: "Three still images to choose from for each video."
        case .shorts: "Short vertical clips from the strongest moments."
        case .knowledgeBase: "Each talk added to a searchable library of the teaching."
        case .voiceDataset: "Clean recordings of consenting teachers' voices, kept on this Mac."
        }
    }

    var symbol: String {
        switch self {
        case .podcastEpisode: "play.circle"
        case .podcastReady: "shippingbox"
        case .transcript: "text.alignleft"
        case .checksAndReport: "checklist"
        case .titlesNotesChapters: "list.bullet.indent"
        case .editedVideo: "play.rectangle"
        case .thumbnails: "rectangle.split.3x1"
        case .shorts: "rectangle.portrait"
        case .knowledgeBase: "text.magnifyingglass"
        case .voiceDataset: "person.crop.circle.badge.checkmark"
        }
    }

    var isBuilt: Bool {
        switch self {
        case .podcastEpisode, .podcastReady, .transcript, .checksAndReport, .titlesNotesChapters: true
        default: false
        }
    }

    /// Can be made today. Since milestone 6 the four built outputs can; the five not built yet are
    /// never made and their switch shows off and greyed, whatever is stored.
    var isAvailable: Bool { isBuilt }

    /// On for a new folder unless Ivan changes it. Titles, show notes and chapters start off: the
    /// writing model holds about 33 GB of memory while it runs and takes minutes per recording, so
    /// Ivan turns them on per folder or per recording. The podcast-ready episode starts off too: it
    /// takes a few more minutes per recording, and without a show name and artwork it is not ready
    /// to upload anyway.
    var isOnByDefault: Bool {
        switch self {
        case .podcastEpisode, .transcript, .checksAndReport: true
        default: false
        }
    }

    static var built: [OutputKind] { allCases.filter(\.isBuilt) }
    static var available: [OutputKind] { allCases.filter(\.isAvailable) }
    static var notBuilt: [OutputKind] { allCases.filter { !$0.isBuilt } }
}

enum TranscriptFormat: String, Codable, CaseIterable, Sendable {
    case txt, srt, vtt, md

    var title: String {
        switch self {
        case .txt: "Plain text (.txt)"
        case .srt: "Subtitles (.srt)"
        case .vtt: "Web subtitles (.vtt)"
        case .md: "Formatted text (.md)"
        }
    }
}

enum AudioChannels: String, Codable, CaseIterable, Sendable {
    case mono, stereo
    var title: String { self == .mono ? "Mono" : "Stereo" }
}

enum SourceKind: String, Codable, CaseIterable, Sendable {
    case folder
    case dropFolder
}

/// Per source: make the chosen outputs on arrival, or ask first.
enum SourceMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case askFirst

    var title: String {
        switch self {
        case .automatic: "Make outputs automatically"
        case .askFirst: "Ask me first"
        }
    }
}

enum RunTrigger: String, Codable, CaseIterable, Sendable {
    case launch, timer, fileEvent, byHand, makeAgain, retry, wake, checkNow
    /// Writes the titles, show notes and chapters again from the transcript already made, and
    /// nothing else (milestone 6).
    case writeAgain
    /// Writes the podcast-ready files again (tags, names, text, checklist) around the audio already
    /// made: for a new title, notes, show name or artwork. The audio is not made again.
    case packageAgain

    var title: String {
        switch self {
        case .launch: "When Prakriti opened"
        case .timer: "Regular check"
        case .fileEvent: "A file changed"
        case .byHand: "Added by hand"
        case .makeAgain: "Make again"
        case .retry: "Trying again"
        case .wake: "After the Mac woke"
        case .checkNow: "Check Now"
        case .writeAgain: "Write again"
        case .packageAgain: "Update podcast-ready files"
        }
    }

    /// Started by Prakriti on its own, not by Ivan. Only these get automatic retries and the
    /// New Recording Found notice.
    var isAutomatic: Bool {
        switch self {
        case .byHand, .makeAgain, .writeAgain, .packageAgain: false
        default: true
        }
    }
}

enum RunOutcome: String, Codable, CaseIterable, Sendable {
    case running, nothingNew, ready, needsADecision, couldntFinish, skippedTest, stopped, checked
}

/// What Prakriti does with a found recording on its own. Stored on the recording, so a quit or a
/// restart never loses the plan: the next check picks it up again.
enum WorkIntent: String, Codable, CaseIterable, Sendable {
    /// Nothing automatic: Ivan starts it (Make Outputs), or it is done.
    case none
    /// From an "Ask me first" folder: check it is complete and has sound, then wait for Ivan.
    case check
    /// From a "Make outputs automatically" folder: make everything chosen for it.
    case make
}

enum StepState: String, Codable, CaseIterable, Sendable {
    case waiting, running, done, failed, skipped

    var symbol: String {
        switch self {
        case .waiting: "circle"
        case .running: "circle.dotted"
        case .done: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "minus.circle"
        }
    }

    var title: String {
        switch self {
        case .waiting: "Waiting"
        case .running: "Working"
        case .done: "Done"
        case .failed: "Stopped"
        case .skipped: "Skipped"
        }
    }
}

enum LogLevel: String, Codable, CaseIterable, Sendable {
    case info, attention, problem

    var symbol: String {
        switch self {
        case .info: "circle.fill"
        case .attention: "questionmark.circle.fill"
        case .problem: "exclamationmark.triangle.fill"
        }
    }
}

/// The jobs a language model does in Prakriti.
enum ModelTask: String, Codable, CaseIterable, Sendable {
    case writing, tagging, summarizing

    var title: String {
        switch self {
        case .writing: "Writing"
        case .tagging: "Tagging"
        case .summarizing: "Summarizing"
        }
    }

    var summary: String {
        switch self {
        case .writing: "Titles, show notes and chapters."
        case .tagging: "Topics and terms for each recording."
        case .summarizing: "A short summary, in the show notes."
        }
    }
}

enum ModelProvider: String, Codable, CaseIterable, Sendable {
    case lmStudio, appleOnDevice, ollama, claudeAPI

    var title: String {
        switch self {
        case .lmStudio: "LM Studio"
        case .appleOnDevice: "Apple on-device"
        case .ollama: "Ollama"
        case .claudeAPI: "Claude API"
        }
    }

    /// Runs on this Mac. Only these may read a class or anything with Serenity in it.
    var isLocal: Bool { self != .claudeAPI }
}

/// The five notices Prakriti can post (SCOPE 8.3), one per recording, updated in place.
enum NotificationEvent: String, Codable, CaseIterable, Sendable {
    case found, started, ready, needsADecision, couldntFinish

    var title: String {
        switch self {
        case .found: "New Recording Found"
        case .started: "Started"
        case .ready: "Waiting for Your Yes"
        case .needsADecision: "Needs a Decision"
        case .couldntFinish: "Couldn't Finish"
        }
    }

    /// Found, Started and Ready share one identifier, so Notification Center holds one row per
    /// recording that changes as it moves along. A decision and a problem get their own, in the
    /// same thread, so neither silently replaces the other (SCOPE 8.1, 8.5).
    var identifierSuffix: String {
        switch self {
        case .found, .started, .ready: "status"
        case .needsADecision: "decision"
        case .couldntFinish: "problem"
        }
    }

    /// What a lock screen with previews hidden shows: the same words as the status on screen
    /// (SCOPE 8.1 rule 10).
    var hiddenPreview: String {
        switch self {
        case .found: RecordingStatus.found.title
        case .started: RecordingStatus.working.title
        case .ready: RecordingStatus.readyForYourYes.title
        case .needsADecision: RecordingStatus.needsADecision.title
        case .couldntFinish: RecordingStatus.couldntFinish.title
        }
    }

    /// Found arrives without a sound and Started goes quietly to Notification Center; the three
    /// that wait on Ivan make a sound. Never Time Sensitive (SCOPE 8.1 rule 8).
    var playsSound: Bool {
        switch self {
        case .found, .started: false
        case .ready, .needsADecision, .couldntFinish: true
        }
    }

    var isPassive: Bool { self == .started }

    var soundLine: String {
        switch self {
        case .found: "Shown without a sound."
        case .started: "Quiet: goes straight to Notification Center."
        case .ready, .needsADecision, .couldntFinish: "Shown with a sound."
        }
    }
}
