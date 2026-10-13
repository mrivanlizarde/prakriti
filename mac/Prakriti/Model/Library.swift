import Foundation
import SwiftData

// The library's shape (v2 part M3a, docs/v2/design-spec.md 2.3 and 2.4): the smart groups of the
// sidebar, what each holds, how the browser groups and sorts it, and what a search finds. Pure logic,
// so every rule here is tested without drawing a window (LibraryTests).

/// The Library section of the sidebar. Membership is a pure function of the stored status, read as a
/// SwiftData predicate over the raw string (START_HERE, Mac warning 11: predicates over raw strings are
/// the reliable part of SwiftData).
enum SmartGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    case needsYou = "needs-you"
    case inProgress = "in-progress"
    case ready
    case all = "all-recordings"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needsYou: "Needs You"
        case .inProgress: "In Progress"
        case .ready: "Ready"
        case .all: "All Recordings"
        }
    }

    var symbol: String {
        switch self {
        case .needsYou: "exclamationmark.bubble"
        case .inProgress: "progress.indicator"
        case .ready: "checkmark.seal"
        case .all: "square.grid.2x2"
        }
    }

    /// The statuses this group holds, or nil for every recording. Ready holds what is approved: until
    /// the platform checks exist (parts M8 and M11b), an approved recording has passed every check
    /// Prakriti makes, and Approve already refuses one whose edits are not in its files.
    var statuses: [RecordingStatus]? {
        switch self {
        case .needsYou: [.readyForYourYes, .needsADecision, .couldntFinish]
        case .inProgress: [.found, .working]
        case .ready: [.approved]
        case .all: nil
        }
    }

    /// The design spec counts Needs You, In Progress and Ready in the sidebar, never All Recordings.
    var showsCount: Bool { self != .all }

    func contains(_ status: RecordingStatus) -> Bool {
        statuses?.contains(status) ?? true
    }

    /// The group as a SwiftData predicate over `statusRaw`.
    var predicate: Predicate<Recording> {
        guard let statuses else { return #Predicate<Recording> { _ in true } }
        let raws = statuses.map(\.rawValue)
        return #Predicate<Recording> { raws.contains($0.statusRaw) }
    }
}

/// What the sidebar has selected: a smart group, or one watched folder.
enum SidebarItem: Hashable, Sendable {
    case group(SmartGroup)
    case source(UUID)

    static let `default`: SidebarItem = .group(.needsYou)
}

/// The panes of the Settings window (design spec 3.13), as built in part M3a.
enum SettingsPane: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general, outputs, models, privacy, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .outputs: "Outputs"
        case .models: "Models"
        case .privacy: "Privacy"
        case .advanced: "Advanced"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .outputs: "shippingbox"
        case .models: "sparkles"
        case .privacy: "hand.raised"
        case .advanced: "gearshape.2"
        }
    }
}

/// The browser's two ways of showing recordings (Command-1 and Command-2, Finder's keys).
enum BrowserMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case grid, list

    var id: String { rawValue }
    var title: String { self == .grid ? "Grid" : "List" }
    var symbol: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

/// The Sort menu (design spec 3.1.3).
enum BrowserSort: String, CaseIterable, Identifiable, Hashable, Sendable {
    case dateRecorded, dateFound, length, title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateRecorded: "Date Recorded"
        case .dateFound: "Date Found"
        case .length: "Length"
        case .title: "Title"
        }
    }
}

/// The inspector's tabs as built in part M3a (People and Direction come with their parts).
enum InspectorTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// People (v2 part M6a) sits second, where the design spec puts it (3.5): Outputs, People, Direction, Checks, Info.
    case outputs, people, checks, info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outputs: "Outputs"
        case .people: "People"
        case .checks: "Checks"
        case .info: "Info"
        }
    }

    var symbol: String {
        switch self {
        case .outputs: "shippingbox"
        case .people: "person.2"
        case .checks: "checklist"
        case .info: "info.circle"
        }
    }
}

/// The search field's scopes, offered as tokens (design spec 3.1.4): titles and notes, or what was said.
enum SearchScope: String, CaseIterable, Identifiable, Hashable, Sendable {
    case title, said

    var id: String { rawValue }
    var title: String { self == .title ? "Title" : "Said" }
    var suggestion: String { self == .title ? "Titles and notes only" : "What was said only" }
}

extension RecordingKind {
    /// The symbol on a recording's neutral tile (design spec 3.1.2 rule 3). Abstract shapes only.
    var tileSymbol: String {
        switch self {
        case .talk: "person.wave.2"
        case .lesson: "person.3"
        case .conversation: "bubble.left.and.bubble.right"
        case .test: "rectangle.dashed"
        case .unknown: "circle.dashed"
        }
    }

    /// The choices of Mark As and What This Is: a test is filed by Prakriti, never chosen.
    static let choices: [RecordingKind] = [.talk, .lesson, .conversation, .unknown]

    /// The words in Mark As and the Info tab.
    var choiceTitle: String {
        switch self {
        case .talk: "Talk, One Teacher Speaking"
        case .lesson: "Class"
        case .conversation: "Conversation"
        case .unknown: "Not Set"
        case .test: "Test"
        }
    }
}

/// One section of the browser: a heading ("Waiting for your yes", "October 2026") and its recordings.
struct LibrarySection: Identifiable, Equatable {
    let id: String
    let title: String?
    let recordings: [Recording]

    static func == (a: LibrarySection, b: LibrarySection) -> Bool {
        a.id == b.id && a.title == b.title && a.recordings.map(\.id) == b.recordings.map(\.id)
    }
}

enum Library {
    /// The recordings of a selection, before searching: a group's members, or a folder's recordings.
    static func members(of item: SidebarItem, in recordings: [Recording]) -> [Recording] {
        switch item {
        case .group(let group): recordings.filter { group.contains($0.status) }
        case .source(let id): recordings.filter { $0.source?.id == id }
        }
    }

    /// Recordings of the chosen kinds; every kind when none is chosen. With `otherPeople` (the Filter menu's
    /// Other People Appear, v2 part M6a), only recordings where two or more faces were seen at once.
    static func filtered(_ recordings: [Recording], kinds: Set<RecordingKind>, otherPeople: Bool = false) -> [Recording] {
        var shown = recordings
        if !kinds.isEmpty { shown = shown.filter { kinds.contains($0.kind == .test ? .unknown : $0.kind) } }
        if otherPeople { shown = shown.filter { $0.faces?.otherPeopleAppear == true } }
        return shown
    }

    /// The browser's sections for a selection, in the design spec's order (3.1.3):
    /// - Needs You: Waiting for your yes, Needs a decision, Couldn't finish; oldest first in each, what
    ///   has waited longest at the top.
    /// - In Progress: Working, then Waiting in the order they will run, then Found.
    /// - Ready: by the month it was approved, newest first.
    /// - All Recordings and a folder: by the month it was recorded, newest first.
    /// A sort other than Date Recorded orders the recordings inside each section.
    static func sections(for item: SidebarItem, recordings: [Recording], sort: BrowserSort = .dateRecorded,
                         waitingOrder: [UUID] = [], calendar: Calendar = .current) -> [LibrarySection] {
        switch item {
        case .group(.needsYou):
            return [RecordingStatus.readyForYourYes, .needsADecision, .couldntFinish].compactMap { status in
                let these = recordings.filter { $0.status == status }
                guard !these.isEmpty else { return nil }
                let ordered = sort == .dateRecorded ? these.sorted(by: oldestFirst) : sorted(these, by: sort)
                return LibrarySection(id: status.rawValue, title: status.title, recordings: ordered)
            }
        case .group(.inProgress):
            let working = recordings.filter { $0.status == .working }
            let waiting = recordings.filter { $0.status == .found && waitingOrder.contains($0.id) }
                .sorted { (waitingOrder.firstIndex(of: $0.id) ?? 0) < (waitingOrder.firstIndex(of: $1.id) ?? 0) }
            let found = recordings.filter { $0.status == .found && !waitingOrder.contains($0.id) }
            let parts: [(String, String, [Recording])] = [
                ("working", RecordingStatus.working.title, sorted(working, by: sort)),
                // Waiting keeps the runner's order whatever the sort: that is the order they will be made in.
                ("waiting", "Waiting", waiting),
                ("found", RecordingStatus.found.title, sorted(found, by: sort)),
            ]
            return parts.compactMap { id, title, these in these.isEmpty ? nil : LibrarySection(id: id, title: title, recordings: these) }
        case .group(.ready):
            return byMonth(recordings, date: { $0.approvedAt ?? $0.sessionDate }, sort: sort, calendar: calendar)
        case .group(.all), .source:
            return byMonth(recordings, date: \.sessionDate, sort: sort, calendar: calendar)
        }
    }

    /// Month sections, newest month first; inside each, newest first or by the chosen sort.
    private static func byMonth(_ recordings: [Recording], date: (Recording) -> Date, sort: BrowserSort, calendar: Calendar) -> [LibrarySection] {
        let groups = Dictionary(grouping: recordings) { calendar.dateInterval(of: .month, for: date($0))?.start ?? date($0) }
        return groups.keys.sorted(by: >).map { month in
            let these = groups[month] ?? []
            let ordered = sort == .dateRecorded ? these.sorted { date($0) != date($1) ? date($0) > date($1) : Recording.newestFirst($0, $1) }
                                                : sorted(these, by: sort)
            return LibrarySection(id: "month-\(Int(month.timeIntervalSince1970))", title: Format.month(month), recordings: ordered)
        }
    }

    /// Oldest first, the order of what has waited longest; ties fall back to the path, so a list never
    /// reshuffles between looks.
    static func oldestFirst(_ a: Recording, _ b: Recording) -> Bool {
        if a.sessionDate != b.sessionDate { return a.sessionDate < b.sessionDate }
        if a.foundAt != b.foundAt { return a.foundAt < b.foundAt }
        return a.filePath < b.filePath
    }

    /// The Sort menu's order: dates newest first, length longest first, titles A to Z.
    static func sorted(_ recordings: [Recording], by sort: BrowserSort) -> [Recording] {
        switch sort {
        case .dateRecorded:
            return recordings.sorted(by: Recording.newestFirst)
        case .dateFound:
            return recordings.sorted { $0.foundAt != $1.foundAt ? $0.foundAt > $1.foundAt : Recording.newestFirst($0, $1) }
        case .length:
            return recordings.sorted { ($0.duration ?? 0) != ($1.duration ?? 0) ? ($0.duration ?? 0) > ($1.duration ?? 0) : Recording.newestFirst($0, $1) }
        case .title:
            return recordings.sorted {
                let order = $0.cardTitle.localizedStandardCompare($1.cardTitle)
                return order == .orderedSame ? Recording.newestFirst($0, $1) : order == .orderedAscending
            }
        }
    }
}

extension Recording {
    /// The card's title: its own title, else its file name without the extension.
    var cardTitle: String {
        title.isEmpty ? (fileName as NSString).deletingPathExtension : title
    }

    /// The folder it came from, or that it was added by hand.
    var sourceName: String { source?.name ?? "Added by hand" }

    /// Its length in seconds for sorting a table column; 0 when not measured yet.
    var lengthForSorting: Double { duration ?? 0 }
}

// MARK: Search

/// A search over the library (design spec 3.1.4): titles and notes, and what was said. Every word
/// typed must be found, case and accents ignored. A sentence that matches is kept with its time, so
/// the card can show it and clicking it opens the recording at that moment.
struct LibrarySearch: Equatable {
    var text: String = ""
    var scopes: [SearchScope] = []

    var isActive: Bool { !words.isEmpty }

    var words: [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
    }

    var searchesTitles: Bool { scopes.isEmpty || scopes.contains(.title) }
    var searchesSpeech: Bool { scopes.isEmpty || scopes.contains(.said) }

    /// What matched in one recording.
    struct Match: Equatable {
        /// The title or the notes held every word.
        var inTitle = false
        /// Sentences of the transcript that hold every word, in order, at most `limit`.
        var said: [SaidMatch] = []
        var isEmpty: Bool { !inTitle && said.isEmpty }
    }

    struct SaidMatch: Equatable, Hashable {
        /// On the original recording's clock, where the sentence's first word starts.
        let time: Double
        let sentence: String
    }

    static let saidLimit = 3

    func match(_ recording: Recording, lines: () -> [TranscriptLine]) -> Match {
        var match = Match()
        let words = words
        guard !words.isEmpty else { return match }
        if searchesTitles {
            let haystack = Self.fold(recording.title + " " + recording.notes + " " + recording.fileName)
            match.inTitle = words.allSatisfy { haystack.contains($0) }
        }
        if searchesSpeech {
            for line in lines() where match.said.count < Self.saidLimit {
                let folded = Self.fold(line.text)
                if words.allSatisfy({ folded.contains($0) }) {
                    match.said.append(SaidMatch(time: line.speechStart, sentence: line.text))
                }
            }
        }
        return match
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// The transcripts the search reads, loaded from each recording's own files the first time they are
/// searched and kept until a new make lands (keyed by the folder and the time it was made). Only
/// Prakriti's own output folders are read, never the original recording.
@MainActor
final class TranscriptIndex {
    private var cache: [UUID: (key: String, lines: [TranscriptLine])] = [:]

    func lines(for recording: Recording) -> [TranscriptLine] {
        guard let folder = recording.outputFolder else { return [] }
        let key = folder + "|" + (recording.madeAt.map { "\($0.timeIntervalSince1970)" } ?? "") + "|" + recording.madeFiles.joined(separator: ",")
        if let cached = cache[recording.id], cached.key == key { return cached.lines }
        let lines = RecordingTranscript.lines(folder: folder, applyLexicon: true)
        cache[recording.id] = (key, lines)
        return lines
    }
}
