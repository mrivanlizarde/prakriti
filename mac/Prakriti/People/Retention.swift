import Foundation

// Keeping prints no longer than needed (v2 part M7a, docs/v2/PLAN.md section 5 and M7, research-people.md 5.4): what
// the vault keeps for a person is deleted 12 months after they last appeared in a recording, and Needs You says so 30
// days before. Only people the vault holds something for are looked at; a name alone is not a print and is kept.

enum Retention {
    /// How long prints are kept after a person last appears (a proposal Ivan can change; BIPA's outside limit is 3 years).
    static let keepMonths = 12
    /// How long before the deletion Needs You says so.
    static let warnDays = 30

    /// What one person's prints are due for.
    enum Due: Equatable, Sendable {
        /// Deleted on this day; Needs You says so until then.
        case soon(UUID, name: String, on: Date)
        /// The day has come: forget now.
        case now(UUID, name: String)
    }

    /// The day a person's prints are deleted: 12 months after they last appeared, or after the release was recorded
    /// when they have not appeared since (nothing else to count from).
    static func deletionDay(lastAppeared: Date?, recorded: Date?, calendar: Calendar = .current) -> Date? {
        guard let from = lastAppeared ?? recorded else { return nil }
        return calendar.date(byAdding: .month, value: keepMonths, to: from)
    }

    /// What is due for each person the vault holds something for. `holds` says whether the vault keeps anything for an id.
    static func review(_ entries: [(id: UUID, name: String, lastAppeared: Date?, recorded: Date?)], holds: (UUID) -> Bool,
                       now: Date, calendar: Calendar = .current) -> [Due] {
        entries.compactMap { entry in
            guard holds(entry.id), let day = deletionDay(lastAppeared: entry.lastAppeared, recorded: entry.recorded, calendar: calendar) else { return nil }
            if now >= day { return .now(entry.id, name: entry.name) }
            if let warn = calendar.date(byAdding: .day, value: -warnDays, to: day), now >= warn { return .soon(entry.id, name: entry.name, on: day) }
            return nil
        }
    }

    /// The Needs You line for a deletion coming soon.
    static func line(name: String, on day: Date) -> String {
        "On \(Format.fullDay(day)), Prakriti deletes what it keeps of \(name)'s face and voice, 12 months after \(name) last appeared in a recording."
    }
}
