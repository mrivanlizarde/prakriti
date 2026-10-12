import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The five notices and SCOPE 8's copy rules, on the builder that makes every one of them. macOS
/// itself is not involved: what reaches Notification Center is exactly what these build.
@MainActor
final class NotificationTests: XCTestCase {
    private let talk = Fixtures.date(2026, 9, 13, 18, 25, 44)
    private let silentClass = Fixtures.date(2026, 9, 14, 20, 0, 9)

    private func facts(_ date: Date, duration: Double? = 947.78, folder: String? = "Studio Recordings") -> NoticeFacts {
        var facts = NoticeFacts(key: NoticeBuilder.slug("2026-09-13 18-25-44"), recordingID: UUID(), date: date)
        facts.duration = duration
        facts.folderName = folder
        return facts
    }

    /// Every variant of every event the app can post.
    private var everyVariant: [(NotificationEvent, NoticeFacts)] {
        var askFirst = facts(talk, folder: "Drop folder"); askFirst.askFirst = true
        let noLength = facts(talk, duration: nil, folder: nil)
        var started = facts(talk); started.estimate = 38
        var startedLong = facts(talk); startedLong.estimate = 130
        var startedEpisodeOnly = facts(talk); startedEpisodeOnly.makesTranscript = false
        var startedNothing = facts(talk); startedNothing.makesTranscript = false; startedNothing.makesEpisode = false
        var readyGap = facts(talk); readyGap.coverageGap = 185
        var readyTranscriptOnly = facts(talk); readyTranscriptOnly.makesEpisode = false
        var readyChecksOnly = facts(talk); readyChecksOnly.makesEpisode = false; readyChecksOnly.makesTranscript = false
        var noTrack = facts(silentClass, duration: 3702.27); noTrack.noAudioTrack = true
        var threeTries = facts(talk); threeTries.tries = 3; threeTries.stoppedWhile = PipelineStep.transcript.doing
        var oneTry = facts(talk); oneTry.tries = 1; oneTry.stoppedWhile = PipelineStep.episode.doing
        var twoTries = facts(talk); twoTries.tries = 2
        return [
            (.found, facts(talk)), (.found, askFirst), (.found, noLength),
            (.started, started), (.started, startedLong), (.started, startedEpisodeOnly), (.started, startedNothing), (.started, noLength),
            (.ready, facts(talk)), (.ready, readyGap), (.ready, readyTranscriptOnly), (.ready, readyChecksOnly),
            (.needsADecision, facts(silentClass, duration: 3702.27)), (.needsADecision, noTrack), (.needsADecision, noLength),
            (.couldntFinish, threeTries), (.couldntFinish, oneTry), (.couldntFinish, twoTries), (.couldntFinish, noLength),
        ]
    }

    func testEveryNoticeFollowsTheCopyRules() {
        let smallWords: Set<String> = ["a", "an", "the", "for", "of", "from", "and", "to", "in", "on", "at"]
        let weekday = "(Mon|Tue|Wed|Thu|Fri|Sat|Sun)"
        let month = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"
        let titlePattern = try! Regex("^(.+): \(weekday) \\d{1,2} \(month)$")
        for (event, facts) in everyVariant {
            let c = NoticeBuilder.content(event, facts)
            let label = "\(event) \(c.body)"

            // Title case with the date.
            let match = c.title.wholeMatch(of: titlePattern)
            XCTAssertNotNil(match, "title must be '<Event>: <Day d Mon>': \(c.title)")
            let head = c.title.components(separatedBy: ": ").first ?? ""
            XCTAssertEqual(head, event.title)
            for (i, word) in head.split(separator: " ").enumerated() where i == 0 || !smallWords.contains(String(word)) {
                XCTAssertTrue(word.first?.isUppercase == true, "title case: '\(word)' in \(c.title)")
            }

            // Full sentences in the body: each starts with a capital and the body ends with a period.
            XCTAssertTrue(c.body.hasSuffix("."), "a full sentence ends the body: \(label)")
            for sentence in c.body.components(separatedBy: ". ") {
                XCTAssertTrue(sentence.first?.isUppercase == true, "each sentence starts with a capital: \(label)")
                XCTAssertGreaterThanOrEqual(sentence.split(separator: " ").count, 3, "no fragments: '\(sentence)' in \(label)")
            }

            for text in [c.title, c.subtitle, c.body] {
                XCTAssertFalse(text.contains("\u{2014}"), "no em dashes: \(text)")
                XCTAssertFalse(text.contains("\u{2013}"), "no en dashes: \(text)")
                XCTAssertFalse(text.contains("!"), "no exclamation marks: \(text)")
                XCTAssertFalse(text.localizedCaseInsensitiveContains("Prakriti"), "no app name: macOS shows it already: \(text)")
                XCTAssertNil(text.firstMatch(of: /(?i)\b(we|we're|our|us)\b/), "no 'we': \(text)")
                XCTAssertFalse(text.localizedCaseInsensitiveContains("processing"), "never 'Processing': \(text)")
                XCTAssertFalse(text.localizedCaseInsensitiveContains("oops"), text)
                XCTAssertFalse(text.unicodeScalars.contains { $0.properties.isEmojiPresentation }, "no emoji: \(text)")
            }
        }
    }

    func testOneNoticePerRecordingUpdatedInPlace() {
        let f = facts(talk)
        let found = NoticeBuilder.content(.found, f)
        let started = NoticeBuilder.content(.started, f)
        let ready = NoticeBuilder.content(.ready, f)
        let decision = NoticeBuilder.content(.needsADecision, f)
        let problem = NoticeBuilder.content(.couldntFinish, f)
        // Found, Started and Ready replace one another: one row in Notification Center.
        XCTAssertEqual(found.identifier, "rec-2026-09-13-18-25-44-status")
        XCTAssertEqual(started.identifier, found.identifier)
        XCTAssertEqual(ready.identifier, found.identifier)
        // A decision and a problem are their own, in the same thread, so neither erases the other.
        XCTAssertEqual(decision.identifier, "rec-2026-09-13-18-25-44-decision")
        XCTAssertEqual(problem.identifier, "rec-2026-09-13-18-25-44-problem")
        XCTAssertEqual(Set([found, started, ready, decision, problem].map(\.threadIdentifier)), ["rec-2026-09-13-18-25-44"])
        XCTAssertEqual(found.recordingID, f.recordingID.uuidString, "a click opens this recording's page")
    }

    func testSoundsAndLevels() {
        let f = facts(talk)
        let expected: [NotificationEvent: (sound: Bool, level: NoticeContent.Level)] = [
            .found: (false, .active),          // New Recording Found: no sound
            .started: (false, .passive),       // Started: quiet, straight to Notification Center
            .ready: (true, .active),           // Waiting for Your Yes: sound
            .needsADecision: (true, .active),
            .couldntFinish: (true, .active),
        ]
        for event in NotificationEvent.allCases {
            let c = NoticeBuilder.content(event, f)
            XCTAssertEqual(c.playsSound, expected[event]?.sound, "\(event)")
            XCTAssertEqual(c.level, expected[event]?.level, "\(event)")
            XCTAssertEqual(c.categoryIdentifier, "prakriti.\(event.rawValue)")
        }
        // Hidden previews say the status words the app shows (SCOPE 8.1 rule 10).
        XCTAssertEqual(NotificationEvent.allCases.map(\.hiddenPreview),
                       ["Found", "Working", "Waiting for your yes", "Needs a decision", "Couldn't finish"])
    }

    /// The exact words for the 13 Sep talk and the silent 14 Sep class, pinned.
    func testTheExactWords() {
        var f = facts(talk)
        XCTAssertEqual(NoticeBuilder.content(.found, f).title, "New Recording Found: Sun 13 Sep")
        XCTAssertEqual(NoticeBuilder.content(.found, f).subtitle, "15 min 48 s, Studio Recordings")
        XCTAssertEqual(NoticeBuilder.content(.found, f).body, "Found in Studio Recordings. It is 15 min 48 s long, and the sound check runs next.")
        f.estimate = 947.78 * PipelineRunner.workPerSecond
        XCTAssertEqual(NoticeBuilder.content(.started, f).title, "Started: Sun 13 Sep")
        XCTAssertEqual(NoticeBuilder.content(.started, f).body,
                       "The sound is good, so the episode audio and the transcript are being made now. It takes about 1 minute.")
        XCTAssertEqual(NoticeBuilder.content(.ready, f).title, "Waiting for Your Yes: Sun 13 Sep")
        XCTAssertEqual(NoticeBuilder.content(.ready, f).body, "The episode audio and the transcript are ready. Listen before anything goes out.")
        f.coverageGap = 185
        XCTAssertEqual(NoticeBuilder.content(.ready, f).body,
                       "The episode audio and the transcript are ready, but the transcript stops 3 min 5 s before the end. Listen to the end before trusting it.")

        let silent = facts(silentClass, duration: 3702.27)
        XCTAssertEqual(NoticeBuilder.content(.needsADecision, silent).title, "Needs a Decision: Mon 14 Sep")
        XCTAssertEqual(NoticeBuilder.content(.needsADecision, silent).body,
                       "The audio is silent for all 1 hr 2 min, so nothing was made from it. Open it to choose what happens to it.")

        var stopped = facts(talk)
        stopped.tries = 3
        stopped.stoppedWhile = PipelineStep.transcript.doing
        XCTAssertEqual(NoticeBuilder.content(.couldntFinish, stopped).title, "Couldn't Finish: Sun 13 Sep")
        XCTAssertEqual(NoticeBuilder.content(.couldntFinish, stopped).body,
                       "It stopped three times while writing the transcript. The original is untouched; open it to see the details.")

        var ask = facts(talk, folder: "Drop folder")
        ask.askFirst = true
        XCTAssertEqual(NoticeBuilder.content(.found, ask).body,
                       "Found in Drop folder, and it has sound. Nothing is made until you open it and choose Make Outputs.")
    }

    /// A dropped file can be named after anyone, and a title can hold a name. Neither ever reaches
    /// a notice, which shows on lock screens and mirrored devices (PR-22).
    func testNoFileNameOrTitleReachesANotice() throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        let drop = Source(name: "Drop folder", path: "/tmp/drop", kind: .dropFolder)
        model.context.insert(drop)
        let recording = Recording(filePath: "/tmp/drop/Maria asks about her divorce.m4a", title: "Maria's question",
                                  foundAt: Fixtures.date(2026, 10, 9, 18, 0), duration: 300)
        model.context.insert(recording)
        recording.source = drop
        var facts = NoticeFacts(recording)
        facts.stoppedWhile = "Writing the transcript"
        for event in NotificationEvent.allCases {
            let c = NoticeBuilder.content(event, facts)
            for text in [c.title, c.subtitle, c.body] {
                for word in ["Maria", "divorce", "question", "asks", ".m4a"] {
                    XCTAssertFalse(text.localizedCaseInsensitiveContains(word), "\(word) reached the \(event) notice: \(text)")
                }
            }
            XCTAssertEqual(c.title, "\(event.title): Fri 9 Oct", "no date in the name: the day it was found")
        }
    }

    func testTheNotifierHonorsSettingsAndRecordsWhatItSent() async throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        let poster = CapturingPoster()
        model.notifier.poster = poster
        let f = facts(talk)
        model.settings.notify[.started] = false
        model.notifier.post(.found, f)
        model.notifier.post(.started, f)
        model.notifier.post(.ready, f)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(poster.posted.map(\.event), [.found, .ready], "Started is off in Settings")
        XCTAssertEqual(model.notifier.sent.map(\.event), [.found, .ready])
        XCTAssertEqual(poster.posted.first?.title, "New Recording Found: Sun 13 Sep")
    }
}

/// Keeps what would have gone to macOS.
@MainActor
final class CapturingPoster: NoticePoster {
    var posted: [NoticeContent] = []
    func post(_ content: NoticeContent) async throws { posted.append(content) }
}
