import Foundation
import SwiftData

/// A person Ivan has named (v2 part M5a adds only what the privacy lock reads; the People parts, M6 and
/// M7, add the rest). Nothing here is a face or voice print, and nothing is stored about anyone unnamed.
@Model
final class Person {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// "Cloud models may read their words." Off for everyone until Ivan turns it on for that person
    /// (docs/v2/PLAN.md section 5, item 2: Serenity's teaching stays local until her yes). The privacy
    /// lock keeps any recording where someone heard has this off on this Mac.
    var mayReadInCloud: Bool = false
    var addedAt: Date = Date.distantPast

    init(id: UUID = UUID(), name: String, mayReadInCloud: Bool = false, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.mayReadInCloud = mayReadInCloud
        self.addedAt = addedAt
    }
}

extension Person {
    /// What a make and the lock read about this person: no store object crosses into a make.
    var named: NamedPerson { NamedPerson(id: id, name: name, cloudConsent: mayReadInCloud) }
}
