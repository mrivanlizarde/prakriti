import Foundation
import SwiftData

// The People gallery's actions (v2 part M7a, docs/v2/PLAN.md M7): Name This Person with its consent sheet, a release
// recorded or Name Only, Rename, Favorite, Pin, Hide from People, Change Key Photo, Custom Order, Forget Face and Voice,
// and retention. Names and the release record are kept in the store. Since part M7b a release that covers a face starts
// learning it (RecognitionActions.swift), and Forget rebuilds the face index without the person.

/// What Name This Person names in a recording: a face row (0: the faces seen for under a second) or a voice.
enum NameTarget: Hashable, Sendable {
    case face(Int)
    case voice(Int)
}

/// The Name This Person sheet, asked for from the People tab (a row of a recording) or a person's page (a release for
/// someone already named).
struct NameSheetRequest: Identifiable, Equatable {
    let id = UUID()
    var recordingID: UUID?
    var target: NameTarget?
    /// Set when the sheet records a release for a person already named.
    var personID: UUID?
    var draft = NameThisPersonDraft()
}

extension AppModel {
    /// The sealed vault of this mode, with this mode's own Keychain service (tests use theirs).
    var vault: PrintVault { PrintVault(folders: peopleFolders, keys: vaultKeys) }

    // MARK: Naming

    /// Opens Name This Person for a row of a recording. Defaults to Name Only.
    func askToName(_ target: NameTarget, in recording: Recording) {
        nameSheet = NameSheetRequest(recordingID: recording.id, target: target)
    }

    /// Opens the release sheet for someone already named.
    func askForRelease(_ person: Person) {
        var draft = NameThisPersonDraft()
        draft.name = person.name
        draft.role = person.role
        draft.mayAppear = person.mayAppear
        draft.recordRelease = true
        draft.releaseSignedOn = person.releaseSignedOn ?? now()
        draft.releaseKeptAt = person.releaseKeptAt
        draft.learnFace = person.releaseSignedOn == nil ? true : person.learnFace
        draft.learnVoice = person.releaseSignedOn == nil ? true : person.learnVoice
        nameSheet = NameSheetRequest(personID: person.id, draft: draft)
    }

    /// The sheet's Name Only or Record Release. A name that is already in the gallery means "this is that person": the row
    /// joins them. Returns the problem in one plain sentence, or nil when it is done.
    @discardableResult
    func finishNaming(_ request: NameSheetRequest, as action: NameThisPersonDraft.Action) -> String? {
        let draft = request.draft
        if action == .recordRelease, let problem = draft.releaseProblem ?? (draft.recordRelease ? nil : "Turn on A written release is signed first.") {
            return problem
        }
        let person: Person
        if let id = request.personID, let existing = namedPeopleList().first(where: { $0.id == id }) {
            person = existing
        } else {
            guard !draft.trimmedName.isEmpty else { return "Type a name." }
            let before = Set(namedPeopleList().map(\.id))
            guard let named = addPerson(named: draft.trimmedName) else { return "Type a name." }
            person = named
            // A name already in People means "this is them": their role and choices stay as they are.
            if !before.contains(named.id) {
                person.role = draft.role
                person.mayAppear = draft.mayAppear
            }
        }
        if action == .recordRelease { recordRelease(draft, for: person) }
        if let recordingID = request.recordingID, let target = request.target, let recording = fetchRecording(recordingID) {
            switch target {
            case .face(let row): nameFace(row, as: person, in: recording)
            case .voice(let id): nameVoice(id, as: person, in: recording)
            }
        }
        try? context.save()
        return nil
    }

    /// Records a written release on the person (research-people.md 5.3). When it covers their face, Prakriti learns it
    /// from the rows already named for them (v2 part M7b). Voice prints are not learned in this version.
    func recordRelease(_ draft: NameThisPersonDraft, for person: Person) {
        guard draft.releaseIsComplete else { return }
        person.releaseSignedOn = draft.releaseSignedOn
        person.releaseKeptAt = draft.releaseKeptAt.trimmingCharacters(in: .whitespacesAndNewlines)
        person.noticeVersion = NameThisPersonDraft.noticeVersion
        person.learnFace = draft.learnFace
        person.learnVoice = draft.learnVoice
        person.releaseRecordedAt = now()
        person.forgottenAt = nil
        person.role = draft.role ?? person.role
        person.mayAppear = draft.mayAppear
        person.pinned = true
        try? context.save()
        record("Recorded a written release for \(person.name), signed \(Format.fullDay(draft.releaseSignedOn))."
               + (person.learnFace ? " Learning their face from the recordings where they are named." : " It does not cover their face, so nothing is learned."))
        if person.learnFace { learn(person) }
    }

    // MARK: The gallery

    /// Rename: only the label changes, everywhere it is shown. Returns the problem, or nil.
    @discardableResult
    func rename(_ person: Person, to raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Type a name." }
        if namedPeopleList().contains(where: { $0.id != person.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return "\(name) is already in People. To put two people together, use Merge 2 People."
        }
        let old = person.name
        guard old != name else { return nil }
        person.name = name
        try? context.save()
        record("Renamed \(old) to \(name).")
        return nil
    }

    func setFavorite(_ favorite: Bool, for person: Person) {
        person.favorite = favorite
        try? context.save()
    }

    func setPinned(_ pinned: Bool, for person: Person) {
        person.pinned = pinned
        if !pinned, selection == .person(person.id) { selection = .people }
        try? context.save()
    }

    /// Hide from People: off the grid and the sidebar. It changes nothing else, and is not Forget.
    func setHidden(_ hidden: Bool, for person: Person) {
        person.hiddenFromPeople = hidden
        if hidden, selection == .person(person.id) { selection = .people }
        try? context.save()
        record(hidden ? "\(person.name) is hidden from People. Nothing else changes." : "\(person.name) shows in People again.")
    }

    func setMayAppear(_ mayAppear: Bool, for person: Person) {
        guard person.mayAppear != mayAppear else { return }
        person.mayAppear = mayAppear
        try? context.save()
    }

    /// Change Key Photo: a face row of one of their recordings, or nil for the one on screen the longest.
    func setKeyPhoto(_ choice: KeyPhotoChoice?, for person: Person) {
        person.keyPhoto = choice
        try? context.save()
    }

    /// Custom Order: `moving` takes `target`'s place. Every person gets their index, so the order is total.
    func moveInGallery(_ moving: UUID, before target: UUID) {
        let people = namedPeopleList()
        let entries = people.map { GalleryEntry(id: $0.id, name: $0.name, favorite: false, hidden: false, pinned: false, customOrder: $0.customOrder,
                                                mayAppear: true, hasRelease: false, appearances: []) }
        let order = Gallery.ordered(entries, sort: .custom, showHidden: true).map(\.id)
        for (index, id) in Gallery.move(moving, before: target, in: order).enumerated() {
            people.first { $0.id == id }?.customOrder = index
        }
        gallerySort = .custom
        try? context.save()
    }

    /// The gallery's tiles for everyone named.
    func galleryEntries() -> [GalleryEntry] {
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        return namedPeopleList().map { Gallery.entry($0, in: recordings) }
    }

    // MARK: Forget and retention

    /// Forget Face and Voice: the vault's key destroyed, the sealed files proved unreadable and deleted, recognition
    /// switched off. The name stays on recordings already checked (research-people.md 5.4).
    @discardableResult
    func forgetFaceAndVoice(_ person: Person) -> PrintVault.ForgetProof {
        // One old crop, opened before the key is destroyed and held in memory only, for the index's proof (M7b).
        let oldCrop = faceIndex.crops(of: [person.id]).first.flatMap { crop in
            (try? vault.open(crop.file, person: person.id)).flatMap { try? SealedCrop.decode($0).jpeg }
        }
        let hadIndex = faceIndex.exists
        let proof = vault.forget(person: person.id)
        person.learnFace = false
        person.learnVoice = false
        person.forgottenAt = now()
        person.pinned = false
        try? context.save()
        record("Forgot \(person.name)'s face and voice. " + proof.line, level: proof.holds ? .info : .attention)
        if hadIndex || oldCrop != nil { rebuildAfterForget(name: person.name, oldCrop: oldCrop) }
        return proof
    }

    /// Prints kept 12 months after a person last appeared, with a Needs You line 30 days before (PLAN section 5). Run
    /// at launch and after each make. Only people the vault holds something for are looked at.
    func reviewRetention() {
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        let people = namedPeopleList()
        let entries = people.map { person in
            (id: person.id, name: person.name, lastAppeared: Gallery.appearances(of: person.id, in: recordings).map(\.sessionDate).max(),
             recorded: person.releaseRecordedAt)
        }
        let vault = self.vault
        var lines: [String] = []
        for due in Retention.review(entries, holds: { vault.holdsAnything(person: $0) }, now: now()) {
            switch due {
            case .soon(_, let name, let day): lines.append(Retention.line(name: name, on: day))
            case .now(let id, _):
                if let person = people.first(where: { $0.id == id }) { forgetFaceAndVoice(person) }
            }
        }
        retentionLines = lines
    }
}
