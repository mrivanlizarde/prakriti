import Foundation
import SwiftData

/// A person Ivan has named (v2 part M5a added only what the privacy lock reads; part M7a adds the gallery's fields and
/// the release). Nothing here is a face or voice print, and nothing is stored about anyone unnamed. Every field has a
/// default, so a store from before M7a opens with them at their defaults (Mac warning 11).
@Model
final class Person {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// "Cloud models may read their words." Off for everyone until Ivan turns it on for that person
    /// (docs/v2/PLAN.md section 5, item 2: Serenity's teaching stays local until her yes). The privacy
    /// lock keeps any recording where someone heard has this off on this Mac.
    var mayReadInCloud: Bool = false
    var addedAt: Date = Date.distantPast

    // v2 part M7a, the People gallery (docs/v2/PLAN.md M7, research-people.md 5.3, design spec 3.9).

    /// Teacher, guest, operator or other (`PersonRole`), as its raw string; empty when not said.
    var roleRaw: String = ""
    /// "Can appear in what is published": a key photo from a real frame is shown only for a person who may appear, a
    /// monogram for anyone else (PLAN section 5). A separate line from recognition: appearing and being recognized are
    /// separate consents (research-people.md 5.3). On by default: Ivan's note of Mon 12 Oct says every participant
    /// signed a release that covers their likeness.
    var mayAppear: Bool = true
    /// The written release for recognition (research-people.md 5.3): the date it was signed, where the signed paper or
    /// file is kept, which notice the person read, and which uses it covers. Nil date means no release: Name Only.
    var releaseSignedOn: Date?
    var releaseKeptAt: String = ""
    var noticeVersion: String = ""
    var learnFace: Bool = false
    var learnVoice: Bool = false
    /// When the release was recorded in Prakriti (accountability, research-people.md 5.3).
    var releaseRecordedAt: Date?
    /// When Forget Face and Voice last ran for this person, or nil.
    var forgottenAt: Date?
    /// Photos' Favorite: favorites come first in the gallery.
    var favorite: Bool = false
    /// Hide from People: off the gallery's grid and the sidebar. It hides nothing anywhere else.
    var hiddenFromPeople: Bool = false
    /// Shown under People in the sidebar (Photos' Pin). Pinned when a release is recorded; Ivan can unpin.
    var pinned: Bool = false
    /// The place in Custom Order; lower first.
    var customOrder: Int = 0
    /// The key photo Ivan chose with Change Key Photo (a `KeyPhotoChoice` as JSON): which recording and which face row.
    /// A reference only: the picture is cropped from the original while it is shown and never written. Nil: automatic.
    var keyPhotoJSON: String?

    init(id: UUID = UUID(), name: String, mayReadInCloud: Bool = false, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.mayReadInCloud = mayReadInCloud
        self.addedAt = addedAt
    }

    var role: PersonRole? {
        get { PersonRole(rawValue: roleRaw) }
        set { roleRaw = newValue?.rawValue ?? "" }
    }

    /// A written release for recognition is on file: a date, where it is kept, and at least one use.
    var hasRelease: Bool {
        releaseSignedOn != nil && !releaseKeptAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (learnFace || learnVoice)
    }

    var keyPhoto: KeyPhotoChoice? {
        get { keyPhotoJSON.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(KeyPhotoChoice.self, from: $0) } }
        set { keyPhotoJSON = newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) } }
    }
}

extension Person {
    /// What a make and the lock read about this person: no store object crosses into a make.
    var named: NamedPerson { NamedPerson(id: id, name: name, cloudConsent: mayReadInCloud) }
}

/// What a named person does in the recordings (research-people.md 5.3).
enum PersonRole: String, CaseIterable, Identifiable, Sendable {
    case teacher, guest, operatorRole = "operator", other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teacher: "Teacher"
        case .guest: "Guest"
        case .operatorRole: "Operator"
        case .other: "Other"
        }
    }
}

/// The key photo Ivan chose: one face row of one recording. Never a picture.
struct KeyPhotoChoice: Codable, Equatable, Hashable, Sendable {
    var recording: UUID
    var row: Int
}
