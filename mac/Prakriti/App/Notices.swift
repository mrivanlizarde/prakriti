import AppKit
import Foundation
import Observation
import UserNotifications

// The notices Ivan gets on this Mac (SCOPE 8): one per recording, updated in place. The builder is
// plain data so the copy rules can be tested without macOS; the Notifier hands it to macOS.
//
// Copy rules (SCOPE 8.1 rule 6), each checked by NotificationTests:
// - Title case with the date ("Ready for Your Yes: Sun 13 Sep"), the weekday computed.
// - Full sentences in the body. No app name (macOS already shows it), no "we", no em dashes, no
//   emoji, no exclamation marks.
// - No student names and no quotes from a session: notices show on lock screens and mirrored
//   devices. So a notice never carries a file name (a dropped file can be named after anyone), a
//   recording's title, or a tool's error text; only the date, lengths, the folder's name and fixed
//   sentences.

/// What a notice is about, without any text yet.
struct NoticeFacts: Sendable, Equatable {
    /// Stable for one recording: its file name without the extension, as a slug.
    var key: String
    var recordingID: UUID
    /// The day the recording was made ("Sun 13 Sep").
    var date: Date
    var duration: Double?
    /// The watched folder's name, or nil when the recording was added by hand.
    var folderName: String?
    /// Found in an "Ask me first" folder: checked, and waiting for Ivan's choice.
    var askFirst = false
    /// What this run makes, for Started and Ready.
    var makesEpisode = true
    var makesTranscript = true
    /// Titles, show notes and chapters are written too (milestone 6).
    var makesWriting = false
    /// Started: how long the work should take, in seconds, when known.
    var estimate: Double?
    /// Ready: how much of the end has no words, when the coverage check failed.
    var coverageGap: Double?
    /// Needs a decision: the file has no audio track at all.
    var noAudioTrack = false
    /// Couldn't finish: tries that stopped, and the step it stopped in ("making the episode audio").
    var tries = 1
    var stoppedWhile: String?

    init(key: String, recordingID: UUID, date: Date) {
        self.key = key
        self.recordingID = recordingID
        self.date = date
    }

    /// The facts for one recording, from what the store knows.
    @MainActor
    init(_ recording: Recording) {
        self.init(key: NoticeBuilder.slug((recording.fileName as NSString).deletingPathExtension),
                  recordingID: recording.id, date: recording.sessionDate)
        duration = recording.duration
        folderName = recording.source?.name.trimmingCharacters(in: .whitespaces)
    }
}

/// One notice, ready to hand to macOS.
struct NoticeContent: Sendable, Equatable {
    enum Level: Sendable, Equatable { case passive, active }

    let event: NotificationEvent
    let identifier: String
    let threadIdentifier: String
    let categoryIdentifier: String
    let title: String
    let subtitle: String
    let body: String
    let playsSound: Bool
    let level: Level
    let recordingID: String
}

enum NoticeBuilder {
    /// "2026-09-13 18-25-44" becomes "2026-09-13-18-25-44": readable in logs, safe as an identifier.
    static func slug(_ name: String) -> String {
        let pieces = name.lowercased().split { !($0.isLetter || $0.isNumber) }
        return pieces.isEmpty ? "recording" : pieces.joined(separator: "-")
    }

    static func category(_ event: NotificationEvent) -> String { "prakriti.\(event.rawValue)" }

    static func content(_ event: NotificationEvent, _ facts: NoticeFacts, timeZone: TimeZone = .current) -> NoticeContent {
        let day = Format.dayLabel(facts.date, timeZone: timeZone)
        let thread = "rec-\(facts.key)"
        return NoticeContent(event: event,
                             identifier: "\(thread)-\(event.identifierSuffix)",
                             threadIdentifier: thread,
                             categoryIdentifier: category(event),
                             title: "\(event.title): \(day)",
                             subtitle: subtitle(facts),
                             body: body(event, facts),
                             playsSound: event.playsSound,
                             level: event.isPassive ? .passive : .active,
                             recordingID: facts.recordingID.uuidString)
    }

    private static func subtitle(_ facts: NoticeFacts) -> String {
        [facts.duration.map { Format.length($0) }, facts.folderName].compactMap { $0 }.joined(separator: ", ")
    }

    private static func body(_ event: NotificationEvent, _ facts: NoticeFacts) -> String {
        switch event {
        case .found:
            let place = facts.folderName.map { "Found in \($0)" } ?? "Found as a new recording"
            if facts.askFirst {
                return "\(place), and it has sound. Nothing is made until you choose Make Outputs on its page."
            }
            let length = facts.duration.map { " It is \(Format.length($0)) long, and" } ?? ""
            return length.isEmpty ? "\(place). The sound check runs next." : "\(place).\(length) the sound check runs next."
        case .started:
            let made = madeList(facts)
            let verb = made.count > 1 ? "are" : "is"
            var text = made.isEmpty
                ? "The sound is good, so the report is being written now."
                : "The sound is good, so \(joined(made)) \(verb) being made now."
            if let estimate = facts.estimate {
                let minutes = max(1, Int((estimate / 60).rounded(.up)))
                text += " It takes about \(minutes) minute\(minutes == 1 ? "" : "s")."
            }
            return text
        case .ready:
            let made = madeList(facts)
            let what = made.isEmpty ? "The checks and the report" : joined(made).capitalizedFirst
            let verb = made.count == 1 ? "is" : "are"
            if let gap = facts.coverageGap, facts.makesTranscript {
                return "\(what) \(verb) ready, but the transcript stops \(Format.length(gap)) before the end. Listen to the end before trusting it."
            }
            return "\(what) \(verb) ready. " + (facts.makesEpisode ? "Listen before anything goes out." : "Read it before anything goes out.")
        case .needsADecision:
            if facts.noAudioTrack {
                return "The file has no audio track, so nothing was made from it. Choose what happens to it on its page."
            }
            let length = facts.duration.map { " for all \(Format.length($0))" } ?? ""
            return "The audio is silent\(length), so nothing was made from it. Choose what happens to it on its page."
        case .couldntFinish:
            let times = facts.tries >= 3 ? " three times" : (facts.tries == 2 ? " twice" : "")
            let step = facts.stoppedWhile.map { " while \($0.lowercasedFirst)" } ?? " before it finished"
            return "It stopped\(times)\(step). The original is untouched, and the details are on the recording page."
        }
    }

    private static func madeList(_ facts: NoticeFacts) -> [String] {
        var made: [String] = []
        if facts.makesEpisode { made.append("the episode audio") }
        if facts.makesTranscript { made.append("the transcript") }
        if facts.makesTranscript && facts.makesWriting { made.append("the show notes") }
        return made
    }

    private static func joined(_ items: [String]) -> String {
        items.count > 1 ? items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "") : (items.first ?? "")
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

/// Hands notices to macOS. Tests replace it with one that only keeps what it was given.
@MainActor
protocol NoticePoster: AnyObject {
    func post(_ content: NoticeContent) async throws
}

/// The real one: UserNotifications.
@MainActor
final class SystemNoticePoster: NoticePoster {
    func post(_ content: NoticeContent) async throws {
        let note = UNMutableNotificationContent()
        note.title = content.title
        note.subtitle = content.subtitle
        note.body = content.body
        note.threadIdentifier = content.threadIdentifier
        note.categoryIdentifier = content.categoryIdentifier
        note.sound = content.playsSound ? .default : nil
        note.interruptionLevel = content.level == .passive ? .passive : .active
        note.userInfo = ["recordingID": content.recordingID]
        let request = UNNotificationRequest(identifier: content.identifier, content: note, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }
}

/// Asks macOS for permission once, posts the notices, and opens a recording's page when one is
/// clicked. Permission is alert and sound only: never provisional (it would arrive quietly, and
/// Ready for Your Yes must make a sound) and never a badge (SCOPE 7.2).
@MainActor
@Observable
final class Notifier {
    enum Permission: Equatable, Sendable {
        /// Not looked at yet (tests, sample data, or before launch finished).
        case unknown
        /// macOS has not asked yet, or Ivan has not answered.
        case waitingForAnswer
        case allowed
        case denied

        /// How the log names it next to each notice.
        var logWords: String {
            switch self {
            case .unknown: "permission not checked yet"
            case .waitingForAnswer: "macOS's permission prompt is not answered yet"
            case .allowed: "allowed"
            case .denied: "notifications are turned off for Prakriti in System Settings"
            }
        }
    }

    var permission: Permission = .unknown
    @ObservationIgnored weak var model: AppModel?
    /// Nil means notices are only written to the log (tests, sample data).
    @ObservationIgnored var poster: NoticePoster?
    /// Every notice built, newest last, for tests and for the log.
    @ObservationIgnored private(set) var sent: [NoticeContent] = []
    @ObservationIgnored private let delegate = NoticeDelegate()

    /// Sets the delegate and the categories, then reads the permission and asks if it was never
    /// asked. Asking shows macOS's own prompt, which only Ivan can answer.
    func setUp() {
        let center = UNUserNotificationCenter.current()
        delegate.onOpen = { [weak self] id in self?.open(recordingID: id) }
        center.delegate = delegate
        center.setNotificationCategories(Set(NotificationEvent.allCases.map { event in
            UNNotificationCategory(identifier: NoticeBuilder.category(event), actions: [], intentIdentifiers: [],
                                   hiddenPreviewsBodyPlaceholder: event.hiddenPreview, options: [])
        }))
        poster = SystemNoticePoster()
        Task { await refreshPermission(askIfNeeded: true) }
    }

    func refreshPermission(askIfNeeded: Bool) async {
        guard poster is SystemNoticePoster else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized:
            setPermission(.allowed, note: "Notifications: allowed.")
        case .denied:
            setPermission(.denied, note: "Notifications: turned off for Prakriti in System Settings. Notices are written to this log only.")
        case .notDetermined:
            setPermission(.waitingForAnswer, note: "Notifications: not answered yet.")
            guard askIfNeeded else { return }
            model?.log.write("Notifications: asking macOS for permission (alert and sound). The prompt needs Ivan's answer.")
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                setPermission(granted ? .allowed : .denied,
                              note: granted ? "Notifications: allowed by Ivan." : "Notifications: Ivan chose Don't Allow.")
            } catch {
                model?.log.write("Notifications: the request did not complete: \(error.localizedDescription)")
            }
        default:
            // Provisional or ephemeral: never requested by Prakriti, but treat as allowed to post.
            setPermission(.allowed, note: "Notifications: allowed (\(status.rawValue)).")
        }
    }

    private func setPermission(_ value: Permission, note: String) {
        guard permission != value else { return }
        permission = value
        if value == .denied {
            // Said where Ivan looks, once per change: nothing reaches Notification Center now.
            model?.record("Notices are turned off for Prakriti in System Settings, so none reach Notification Center. Turn them on in System Settings, Notifications, Prakriti.",
                          level: .attention)
        } else {
            model?.log.write(note)
        }
    }

    /// Builds and posts one notice, unless Ivan turned that kind off in Settings. Every notice is
    /// written to the log with whether macOS took it, so delivery can be checked without looking.
    func post(_ event: NotificationEvent, _ facts: NoticeFacts) {
        guard let model else { return }
        let content = NoticeBuilder.content(event, facts)
        guard model.settings.notify[event] ?? true else {
            model.log.write("Notice not shown (turned off in Settings): \(content.title).")
            return
        }
        sent.append(content)
        guard let poster else {
            model.log.write("Notice (log only): \(content.title). \(content.body)")
            return
        }
        Task {
            do {
                try await poster.post(content)
                let state = permission == .allowed ? "shown" : "handed to macOS but not shown (\(permission.logWords))"
                model.log.write("Notice \(state): \(content.identifier). \(content.title). \(content.body)")
            } catch {
                let why = permission == .allowed ? error.localizedDescription : permission.logWords
                model.log.write("Notice NOT shown (\(why)): \(content.identifier). \(content.title).")
            }
        }
    }

    /// A clicked notice opens that recording's page in the main window.
    func open(recordingID: String) {
        guard let model, let id = UUID(uuidString: recordingID) else { return }
        model.log.write("Opened from a notice.")
        model.openRecording(id: id)
    }
}

/// UserNotifications calls its delegate off the main thread; this hands what matters to the main actor.
final class NoticeDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor var onOpen: ((String) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.content.userInfo["recordingID"] as? String
        guard let id else { return }
        await MainActor.run { onOpen?(id) }
    }
}
