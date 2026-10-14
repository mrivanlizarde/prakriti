import Foundation

// The People gallery's logic (v2 part M7a, docs/v2/PLAN.md M7, design spec 3.9, research-people.md 4.2): who is in
// it, in what order, where each person appears and for how long, which face is their key photo, and the words on
// their tile and page. Pure, so every rule is tested without drawing a window (`GalleryTests`).
//
// Every named person is in the gallery from the day they are named, Name Only included (PLAN section 5): their
// recordings, minutes on screen and minutes speaking come from Ivan's own naming in each recording, never from a
// print. Nobody unnamed is in it: one face-less tile stands for them and lists the recordings they are in.

/// Where one named person appears in one recording, from Ivan's naming there.
struct Appearance: Sendable, Equatable {
    var recordingID: UUID
    var filePath: String
    var sessionDate: Date
    /// The face rows named for them, the most on screen first.
    var faces: [FacePerson]
    /// Seconds on screen (their named face rows) and seconds speaking (their named voices).
    var onScreen: Double
    var speaking: Double
    /// All the speech in the recording, for "Speaks 82 percent".
    var speech: Double

    var speakingPercent: Int? {
        guard speech > 0, speaking > 0 else { return nil }
        return min(100, Int((speaking / speech * 100).rounded()))
    }
}

/// How the gallery is sorted (Photos' two sorts).
enum GallerySort: String, CaseIterable, Identifiable, Sendable {
    case name, custom

    var id: String { rawValue }
    var title: String { self == .name ? "By Name" : "Custom Order" }
}

/// One tile of the gallery, and the figures on the person's page.
struct GalleryEntry: Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var favorite: Bool
    var hidden: Bool
    var pinned: Bool
    var customOrder: Int
    var mayAppear: Bool
    var hasRelease: Bool
    var appearances: [Appearance]

    var recordings: Int { appearances.count }
    var onScreen: Double { appearances.map(\.onScreen).reduce(0, +) }
    var speaking: Double { appearances.map(\.speaking).reduce(0, +) }
    /// The newest recording they appear in, or nil.
    var lastAppeared: Date? { appearances.map(\.sessionDate).max() }

    /// The tile's second line: "In 3 recordings", "Not in a recording yet".
    var tileLine: String {
        recordings == 0 ? "Not in a recording yet" : "In \(Format.count(recordings, "recording"))"
    }
}

enum Gallery {
    /// Where a person appears: every recording where Ivan named them, by Who Is Teaching, a face row, a voice, the
    /// faces seen for under a second, or a folder's microphone track. Newest first.
    static func appearances(of person: UUID, in recordings: [Recording]) -> [Appearance] {
        recordings.compactMap { appearance(of: person, in: $0) }
            .sorted { $0.sessionDate != $1.sessionDate ? $0.sessionDate > $1.sessionDate : $0.filePath < $1.filePath }
    }

    static func appearance(of person: UUID, in recording: Recording) -> Appearance? {
        let names = recording.resolvedNames
        let resolved = names.resolved(faces: recording.faces, voices: recording.voices)
        let rows = (recording.faces?.people ?? []).filter { resolved.faces[$0.id] == person }.sorted { $0.onScreen > $1.onScreen }
        let voices = (recording.voices?.voices ?? []).filter { resolved.voices[$0.id] == person }
        let glimpsed = resolved.faces[0] == person
        guard !rows.isEmpty || !voices.isEmpty || glimpsed || names.teacher == person else { return nil }
        return Appearance(recordingID: recording.id, filePath: recording.filePath, sessionDate: recording.sessionDate, faces: rows,
                          onScreen: rows.map(\.onScreen).reduce(0, +), speaking: voices.map(\.speaking).reduce(0, +),
                          speech: recording.voices?.speech ?? 0)
    }

    static func entry(_ person: Person, in recordings: [Recording]) -> GalleryEntry {
        GalleryEntry(id: person.id, name: person.name, favorite: person.favorite, hidden: person.hiddenFromPeople, pinned: person.pinned,
                     customOrder: person.customOrder, mayAppear: person.mayAppear, hasRelease: person.hasRelease,
                     appearances: appearances(of: person.id, in: recordings))
    }

    /// The gallery's tiles: favorites first, then by name or by Ivan's custom order. Hidden people only when asked.
    static func ordered(_ entries: [GalleryEntry], sort: GallerySort, showHidden: Bool = false) -> [GalleryEntry] {
        entries.filter { showHidden || !$0.hidden }.sorted { a, b in
            if a.favorite != b.favorite { return a.favorite }
            if sort == .custom, a.customOrder != b.customOrder { return a.customOrder < b.customOrder }
            let byName = a.name.localizedStandardCompare(b.name)
            return byName != .orderedSame ? byName == .orderedAscending : a.id.uuidString < b.id.uuidString
        }
    }

    /// The custom order after `moving` is dropped on `target` (it takes the target's place; the target and those after
    /// it move one along). Returns every id in its new order; `customOrder` is each one's index.
    static func move(_ moving: UUID, before target: UUID, in order: [UUID]) -> [UUID] {
        guard moving != target, order.contains(moving), order.contains(target) else { return order }
        var result = order.filter { $0 != moving }
        let index = result.firstIndex(of: target) ?? result.endIndex
        result.insert(moving, at: index)
        return result
    }

    /// The face a person's key photo is cropped from: Ivan's choice when it is still one of their face rows, else the
    /// row on screen the longest across their recordings. Nil when they were never seen (named only by their voice).
    static func keyFace(choice: KeyPhotoChoice?, appearances: [Appearance]) -> (appearance: Appearance, face: FacePerson)? {
        if let choice, let appearance = appearances.first(where: { $0.recordingID == choice.recording }),
           let face = appearance.faces.first(where: { $0.id == choice.row }) {
            return (appearance, face)
        }
        var best: (Appearance, FacePerson)?
        for appearance in appearances {
            for face in appearance.faces where face.onScreen > (best?.1.onScreen ?? -1) { best = (appearance, face) }
        }
        return best.map { (appearance: $0.0, face: $0.1) }
    }

    /// Recordings with someone in them Ivan has not named (a face row, a voice, or faces seen for under a second): the
    /// face-less "Unnamed people" tile lists these. Newest first.
    static func unnamedRecordings(_ recordings: [Recording]) -> [Recording] {
        recordings.filter(hasUnnamed).sorted(by: Recording.newestFirst)
    }

    static func hasUnnamed(_ recording: Recording) -> Bool {
        let resolved = recording.resolvedNames.resolved(faces: recording.faces, voices: recording.voices)
        let people = Set(recording.namedPeople.map(\.id))
        let faces = recording.faces
        let rowUnnamed = (faces?.people ?? []).contains { resolved.faces[$0.id].map { !people.contains($0) } ?? true }
        let glimpseUnnamed = (faces?.glimpses ?? 0) > 0 && (resolved.faces[0].map { !people.contains($0) } ?? true)
        let voiceUnnamed = (recording.voices?.voices ?? []).contains { resolved.voices[$0.id].map { !people.contains($0) } ?? true }
        return rowUnnamed || glimpseUnnamed || voiceUnnamed
    }

    /// Up to two letters for a monogram: the first letter of the first two words ("Gabriel Galindo" is "GG").
    static func monogram(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }

    /// The person page's status line (design spec 3.9.2, PLAN section 5). Since part M7b a release that covers a face
    /// turns recognition on: `learned` is how many face crops the vault keeps for them.
    static func statusLine(_ person: Person, learned: Int = 0) -> String {
        if person.hasRelease, let signed = person.releaseSignedOn {
            let release = "Written release signed on \(Format.fullDay(signed)), kept in \(person.releaseKeptAt.trimmingCharacters(in: .whitespacesAndNewlines))."
            guard person.learnFace else { return release + " It does not cover their face, so recognition is off. Named by you in each recording." }
            if learned > 0 {
                return release + " Recognized in new recordings, from \(Format.count(learned, "picture")) of their face kept locked on this Mac."
            }
            return release + " Recognition is on: name them in a recording and Prakriti learns their face from it."
        }
        if let forgotten = person.forgottenAt {
            return "Face and voice forgotten on \(Format.fullDay(forgotten)). Recognition off. Named by you in each recording."
        }
        return "Recognition off. Named by you in each recording."
    }

    /// The person page's line about appearing in what is published, separate from recognition (research-people.md 5.3).
    static func appearLine(_ person: Person) -> String {
        person.mayAppear ? "Can appear in what is published. The key photo is a frame from a recording, never saved."
                         : "Not shown in what is published by choice. The gallery shows their initials, not a frame."
    }

    /// The person page's three figures (research-people.md 4.2): "3 recordings", "12 min on screen", "9 min speaking".
    static func figures(_ entry: GalleryEntry) -> [(value: String, label: String)] {
        [(Format.number(entry.recordings), entry.recordings == 1 ? "recording" : "recordings"),
         (minutes(entry.onScreen), "on screen"),
         (minutes(entry.speaking), "speaking")]
    }

    /// Whole minutes, or seconds under a minute: "12 min", "40 s", "0 min".
    static func minutes(_ seconds: Double) -> String {
        if seconds <= 0 { return "0 min" }
        if seconds < 60 { return "\(Int(seconds.rounded())) s" }
        return "\(Int((seconds / 60).rounded())) min"
    }
}

/// The Name This Person sheet's answers (v2 part M7a, design spec 3.9.4, research-people.md 5.3 and 5.6). It defaults to
/// Name Only: a name kept as a name, nothing about a face or a voice. A release is recorded only when Ivan fills in when
/// it was signed and where it is kept, and turns on at least one use.
struct NameThisPersonDraft: Equatable, Sendable {
    var name = ""
    var role: PersonRole? = nil
    var mayAppear = true
    var recordRelease = false
    var releaseSignedOn = Date()
    var releaseKeptAt = ""
    var learnFace = true
    var learnVoice = true

    /// The notice the person read before signing (research-people.md 5.3: its text will change after the lawyer reads it).
    static let noticeVersion = "1"

    /// What Return does: Name Only unless a complete release is being recorded.
    enum Action: Equatable, Sendable { case nameOnly, recordRelease }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var releaseIsComplete: Bool {
        recordRelease && !releaseKeptAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (learnFace || learnVoice)
    }

    /// The sheet's default button.
    var defaultAction: Action { releaseIsComplete ? .recordRelease : .nameOnly }

    /// Why the release cannot be recorded yet, in one plain sentence, or nil.
    var releaseProblem: String? {
        guard recordRelease else { return nil }
        if releaseKeptAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Say where the signed release is kept." }
        if !learnFace && !learnVoice { return "A release covers a face, a voice or both: turn one on." }
        return nil
    }
}
