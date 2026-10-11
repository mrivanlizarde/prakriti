import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The episode text (11 Oct): the writer's answer checked into a title and three alternatives, a
/// one-line summary, show notes in paragraphs, keywords and a caption per platform with its pull
/// quote; Ivan's copy rules read by Swift; "Episode text.txt" and ".md" laid out with the chapters of
/// the finished file and the call to action; numbering in the checklist; a class never made ready;
/// the Copy buttons' pasteboard. On planted answers and generated audio: nothing here reads a real
/// recording or writes into ~/Prakriti (the 13 Sep talk is EpisodeTextAcceptanceTests).
@MainActor
final class EpisodeTextTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-episode-text-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    /// A talk of seven lines, its times on the episode's clock.
    static let lines: [WritingLine] = [
        WritingLine(start: 0.08, end: 5, label: "0:00", text: "Welcome back, everyone, to a talk about the breath."),
        WritingLine(start: 72, end: 78, label: "1:12", text: "The long exhale calms the nervous system within a few rounds."),
        WritingLine(start: 135.2, end: 140, label: "2:15", text: "In our school we practise twelve rounds before any posture."),
        WritingLine(start: 201, end: 206, label: "3:21", text: "I was making 300 bucks a month when I started teaching."),
        WritingLine(start: 262.4, end: 268, label: "4:22", text: "Now let's try it together, slowly."),
        WritingLine(start: 331, end: 336, label: "5:31", text: "Notice how the mind settles after the twelfth round."),
        WritingLine(start: 390, end: 396, label: "6:30", text: "Enrollment for the next training opens soon, so sign up early."),
    ]
    static var text: String { lines.map(\.text).joined(separator: " ") }

    // MARK: The copy rules

    func testTheCopyRulesCatchMoneyEnrollmentAndOffers() {
        for flagged in ["Tuition is $3,000.", "He earned six figures in a year.", "available to enrolled students", "Enrollment is paused for now.",
                        "Sign up for the next cohort.", "new viewers can access a free week", "I was making 300 bucks a month",
                        "a track on sales, marketing and pricing", "Join now to save 20% off.", "the income of a teacher", "Register today."] {
            XCTAssertNotNil(CopyRules.flag(flagged), flagged)
        }
        for clean in ["The practice offers a way to slow down.", "Pay attention to the exhale.", "A new group on the business of yoga, including sales and marketing.",
                      "Free your breath before any posture.", "Sri Krishnamacharya is called the father of modern yoga.", "Classes return on Mondays at 8 p.m. Pacific.",
                      "Thousands of hours of curriculum are in the online platform."] {
            XCTAssertNil(CopyRules.flag(clean), clean)
        }
        // Sentences are read as NaturalLanguage reads them, so "8 p.m. Pacific" stays one sentence.
        let notes = "Yin yoga returns on Mondays at 8 p.m. Pacific. The decision to pause enrollment is explained.\n\nThe lineage runs through Sri BNS Iyengar."
        let screened = CopyRules.withoutFlaggedSentences(notes)
        XCTAssertEqual(screened.text, "Yin yoga returns on Mondays at 8 p.m. Pacific.\n\nThe lineage runs through Sri BNS Iyengar.")
        XCTAssertEqual(screened.removed.count, 1)
        XCTAssertTrue(screened.removed[0].hasPrefix("enrollment or signing up"), screened.removed[0])
    }

    // MARK: The writer's answer

    func testTheAnswerBecomesTheEpisodeText() throws {
        let longX = "The teacher explains why the long exhale comes first, and why twelve rounds come before any posture in this school. "
            + "Then the class practises it together, slowly and without hurry, and notices the mind settle after the twelfth round, which the teacher says is the whole point of the practice."
        let answer = #"""
            {"titles": ["The Breath Comes First", "Enroll in the Long Exhale", "Twelve Rounds Before Any Posture", "Why the Exhale Matters", "A Fifth"],
             "one_line": "A talk on why the long exhale comes first. It also covers the twelve rounds the school practises before any posture, and how the mind settles after them, slowly and together.",
             "show_notes": ["The teacher explains why the breath comes first. Enrollment for the next training opens soon.", "Twelve rounds come before any posture \u2014 every time.", "The class practises together."],
             "keywords": ["long exhale", "#pranayama", "pricing", "twelve rounds"],
             "chapters": [{"start": "0:00", "title": "Breath First"}, {"start": "2:15", "title": "Twelve Rounds"}, {"start": "4:22", "title": "Practice Together"}],
             "social": {
               "instagram": {"caption": "Why the long exhale comes first. #breath", "hashtags": ["#Breath", "long exhale", "Pranayama", "free trial", "Yoga Marga", "Twelve Rounds", "Seventh"],
                             "pull_quote": "The long exhale calms the nervous system within a few rounds.", "pull_quote_at": "1:12"},
               "linkedin": {"caption": "A teacher who started on $300 a month explains the breath.", "pull_quote": "Notice how the mind settles after the twelfth round.", "pull_quote_at": "5:31"},
               "x": {"caption": "\#(longX)", "pull_quote": "the mind settles after the eleventh round", "pull_quote_at": "5:31"}},
             "checklist": [{"claim": "Twelve rounds come first.", "quote": "In our school we practise twelve rounds before any posture.", "at": "2:15"},
                           {"claim": "He made little at first.", "quote": "I was making 300 bucks a month when I started teaching.", "at": "3:21"}]}
            """#
        let checked = try WritingCheck.check(answer, lines: Self.lines, transcript: Self.text, rules: WritingRules.forLength(418), length: 418)

        // Four titles: the one that sells enrollment is left out, the fifth is not needed.
        XCTAssertEqual(checked.titles, ["The Breath Comes First", "Twelve Rounds Before Any Posture", "Why the Exhale Matters", "A Fifth"])
        XCTAssertTrue(checked.notes.contains { $0.hasPrefix("A title named enrollment") }, "\(checked.notes)")
        // The one-line summary is over 159 characters, so only its first sentence is kept.
        XCTAssertEqual(checked.oneLine, "A talk on why the long exhale comes first.")
        // Three paragraphs; the sentence about enrollment taken out, the dash a comma.
        XCTAssertEqual(CopyRules.paragraphs(checked.showNotes), ["The teacher explains why the breath comes first.", "Twelve rounds come before any posture, every time.", "The class practises together."])
        XCTAssertTrue(checked.notes.contains { $0.contains("of the show notes named enrollment") }, "\(checked.notes)")
        // Keywords: cleaned, "pricing" left out.
        XCTAssertEqual(checked.keywords, ["long exhale", "pranayama", "twelve rounds"])
        // The speaker's own income claim stays in the accuracy checklist: it must be checked.
        XCTAssertEqual(checked.checklist.count, 2)

        XCTAssertEqual(checked.social.map(\.platform), [.instagram, .x], "LinkedIn named a sum of money, so it was left out")
        XCTAssertTrue(checked.notes.contains { $0.hasPrefix("The LinkedIn caption named a price or sum of money") }, "\(checked.notes)")
        let instagram = checked.social[0]
        XCTAssertEqual(instagram.text, "Why the long exhale comes first.", "the hashtag inside the caption is taken out")
        XCTAssertEqual(instagram.hashtags, ["Breath", "LongExhale", "TwelveRounds"],
                       "cleaned, the offer left out, and only words the teacher says: no Pranayama, Yoga Marga or Seventh in this talk")
        XCTAssertTrue(checked.notes.contains { $0.hasPrefix("3 hashtags were not words the teacher says") }, "\(checked.notes)")
        XCTAssertEqual(instagram.pullQuote, "The long exhale calms the nervous system within a few rounds.")
        XCTAssertEqual(instagram.pullQuoteAt, 72)
        XCTAssertEqual(instagram.post, "Why the long exhale comes first.\n\n#Breath #LongExhale #TwelveRounds")
        // X: over 280, cut back to the whole first sentence; its pull quote is not what was said.
        let x = checked.social[1]
        XCTAssertLessThan(x.text.count, 280)
        XCTAssertEqual(x.text, "The teacher explains why the long exhale comes first, and why twelve rounds come before any posture in this school.")
        XCTAssertNil(x.pullQuote, "\"eleventh\" is not what was said")
        XCTAssertEqual(checked.leftOutPullQuotes, ["the mind settles after the eleventh round"])
        XCTAssertEqual(checked.leftOutCaptions, 1)
    }

    /// A hashtag is whole words the teacher says, capitalized as joined words; a misspelling or a
    /// word that is not said is left out (11 Oct: the model wrote "#Yogalinage").
    func testHashtagsAreTheTeachersOwnWords() {
        let spoken = "We trace the yoga lineage of Ashtanga yoga back to Krishnamacharya, at Yoga Marga, in 99 rounds."
        XCTAssertEqual(WritingCheck.hashtag("Ashtangayoga", in: spoken), "AshtangaYoga")
        XCTAssertEqual(WritingCheck.hashtag("#yoga lineage", in: spoken), "YogaLineage")
        XCTAssertEqual(WritingCheck.hashtag("YogaMarga", in: spoken), "YogaMarga")
        XCTAssertEqual(WritingCheck.hashtag("Krishnamacharya", in: spoken), "Krishnamacharya")
        XCTAssertNil(WritingCheck.hashtag("Yogalinage", in: spoken), "misspelled")
        XCTAssertNil(WritingCheck.hashtag("Pranayama", in: spoken), "not said")
        XCTAssertNil(WritingCheck.hashtag("Marg", in: spoken), "part of a word is not a word")
        XCTAssertNil(WritingCheck.hashtag("gaMarga", in: spoken), "a run must start at a word")
    }

    /// The show belongs to the Outputs screen: a recording with its own choices still takes the show's
    /// name, host, artwork, numbering and call to action from there, and its own layout and explicit.
    func testTheShowsSettingsComeFromTheOutputsScreen() throws {
        let paths = AppPaths(mode: .development, home: work)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        let recording = Recording(filePath: work.appending(path: "2026-10-11 talk.m4a").path, foundAt: Date())
        model.context.insert(recording)
        model.setOutput(.podcastReady, on: true, for: recording)
        let own = try XCTUnwrap(recording.outputSettings.first { $0.kind == .podcastReady })
        own.explicitContent = true
        own.bitrateKbps = 128
        let show = try XCTUnwrap(model.defaultSettings().first { $0.kind == .podcastReady })
        show.showName = "Test Show"
        show.hostName = "Test Host"
        show.numbering = .episodes
        show.callToAction = "Write to the studio."
        let settings = model.podcastReadySettings(for: recording)
        XCTAssertEqual(settings.showName, "Test Show", "typed on the Outputs screen after the recording had its own choices")
        XCTAssertEqual(settings.hostName, "Test Host")
        XCTAssertEqual(settings.numbering, .episodes)
        XCTAssertEqual(settings.callToAction, "Write to the studio.")
        XCTAssertTrue(settings.explicit, "explicit is the episode's own")
        XCTAssertEqual(settings.bitrateKbps, 128, "how it sounds is the episode's own")
        XCTAssertEqual(model.runner.options(for: recording).podcastReady?.settings, settings, "the pipeline makes it with the same")
    }

    /// A pull quote must sit inside one line (one sentence as Parakeet wrote it), keep the copy rules,
    /// and not repeat another platform's.
    func testPullQuotesAreOneSentenceOfTheTeachersOwnWords() {
        let found: (String) -> Bool = { Self.text.contains($0) }
        let social: [String: Any] = [
            "instagram": ["caption": "On the breath.", "pull_quote": "within a few rounds. In our school we practise", "pull_quote_at": "1:12"],
            "linkedin": ["caption": "On the breath.", "pull_quote": "I was making 300 bucks a month when I started teaching.", "pull_quote_at": "3:21"],
            "x": ["caption": "On the breath.", "pull_quote": "Now let\u{2019}s try it together, slowly.", "pull_quote_at": "4:22"],
        ]
        let result = WritingCheck.social(social, lines: Self.lines, keywords: ["Breath"], found: found)
        XCTAssertEqual(result.kept.count, 3)
        XCTAssertNil(result.kept[0].pullQuote, "two sentences, across two lines")
        XCTAssertEqual(result.kept[0].hashtags, ["Breath"], "no hashtags given, so from the keywords")
        XCTAssertNil(result.kept[1].pullQuote, "an earnings claim is never a pull quote")
        XCTAssertEqual(result.kept[2].pullQuote, "Now let's try it together, slowly.", "a typographic apostrophe is evened out")
        XCTAssertEqual(result.kept[2].pullQuoteAt, 262.4)
        XCTAssertTrue(result.notes.contains { $0.hasPrefix("The LinkedIn pull quote named a price or sum of money") }, "\(result.notes)")
    }

    // MARK: The files

    private func package(captions: Bool = true) -> WrittenPackage {
        var p = WrittenPackage(titles: ["The Breath Comes First", "Twelve Rounds Before Any Posture", "Why the Exhale Matters", "Practice Together"],
                               showNotes: "The teacher explains why the breath comes first.\n\nTwelve rounds come before any posture.",
                               chapters: [WrittenChapter(start: 0.08, title: "Breath First"), WrittenChapter(start: 135.2, title: "Twelve Rounds"),
                                          WrittenChapter(start: 262.4, title: "Practice Together")],
                               checklist: [], tags: ["breath"], writtenBy: "Qwen3.8-27B in LM Studio", writingProvider: "lmStudio",
                               writtenAt: Date(timeIntervalSince1970: 1_791_600_000), seconds: 600, attempts: 1, writingSeconds: 590, clock: "episode")
        p.oneLine = "A talk on why the long exhale comes first."
        p.keywords = ["long exhale", "pranayama"]
        if captions {
            p.social = [SocialCaption(platform: .instagram, text: "Why the long exhale comes first.", hashtags: ["Breath", "Pranayama"],
                                      pullQuote: "The long exhale calms the nervous system within a few rounds.", pullQuoteAt: 72),
                        SocialCaption(platform: .linkedin, text: "A teacher explains twelve rounds before posture.", pullQuote: "Now let's try it together, slowly.", pullQuoteAt: 262.4),
                        SocialCaption(platform: .x, text: "Twelve rounds before any posture.", pullQuote: "Notice how the mind settles after the twelfth round.", pullQuoteAt: 331)]
        }
        return p
    }

    func testTheTextFilesSayEverythingInOrder() throws {
        var settings = PodcastReadySettings()
        settings.callToAction = "Questions about the practice \u{2014} write to the studio."
        let facts = PodcastEpisodeFacts(title: "", notes: "", label: "Sun 13 Sep", kind: .talk, fileName: "2026-09-13 18-25-44.mp4")
        let written = package()
        // The chapters as written into a 418 s file: the first moved to 0:00.
        let chapters = PodcastPackage.chapters(written.chapters, duration: 418).chapters
        let copy = PodcastPackage.copy(settings: settings, facts: facts, written: written, chapters: chapters)
        XCTAssertEqual(copy.title, "The Breath Comes First")
        XCTAssertFalse(copy.titleChosen)
        XCTAssertEqual(copy.alternatives, ["Twelve Rounds Before Any Posture", "Why the Exhale Matters", "Practice Together"])
        XCTAssertEqual(copy.chapters.map(\.label), ["0:00", "2:15", "4:22"], "times in the finished file, the first at 0:00")
        XCTAssertEqual(copy.callToAction, "Questions about the practice, write to the studio.", "his words, the dash his rule forbids made a comma")
        XCTAssertEqual(copy.showNotes, """
            The teacher explains why the breath comes first.

            Twelve rounds come before any posture.

            Chapters
            0:00 Breath First
            2:15 Twelve Rounds
            4:22 Practice Together

            Questions about the practice, write to the studio.
            """)

        let text = PodcastPackage.episodeText(copy, settings: settings, facts: facts, written: written, fileName: "2026-09-13.mp3", madeAt: Date(), markdown: false)
        let order = ["EPISODE TITLE", "The Breath Comes First", "Alternatives", "1. Twelve Rounds Before Any Posture", "ONE-LINE SUMMARY", "SHOW NOTES",
                     "Chapters\n0:00 Breath First", "Questions about the practice", "KEYWORDS", "long exhale, pranayama", "SOCIAL CAPTIONS",
                     "Instagram (32 characters)", "#Breath #Pranayama", "Pull quote, at 1:12: \"The long exhale calms", "LinkedIn (", "X and Threads (33 of 280 characters)",
                     "FOR THE HOST'S FORM", "Show: not set", "Explicit: No"]
        var cursor = text.startIndex
        for piece in order {
            guard let found = text.range(of: piece, range: cursor..<text.endIndex) else { return XCTFail("\(piece) is missing or out of order:\n\(text)") }
            cursor = found.upperBound
        }
        XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "no em or en dashes")

        let markdown = PodcastPackage.episodeText(copy, settings: settings, facts: facts, written: written, fileName: "2026-09-13.mp3", madeAt: Date(), markdown: true)
        XCTAssertTrue(markdown.hasPrefix("# Sun 13 Sep: episode text"))
        XCTAssertTrue(markdown.contains("## Show notes") && markdown.contains("- 2:15 Twelve Rounds") && markdown.contains("### X and Threads"), markdown)
        XCTAssertTrue(markdown.contains("\\#Breath \\#Pranayama"), "a hashtag at the start of a line would be a heading")
        XCTAssertTrue(markdown.contains("> \u{201C}Notice how the mind settles after the twelfth round.\u{201D}"))

        // Ivan's own title and notes are his words: never screened, and the writer's pick becomes an alternative.
        let own = PodcastEpisodeFacts(title: "Why the Exhale Matters", notes: "My notes. Enrollment opens in January.", label: "Sun 13 Sep", kind: .talk)
        let mine = PodcastPackage.copy(settings: PodcastReadySettings(), facts: own, written: written, chapters: [])
        XCTAssertEqual(mine.title, "Why the Exhale Matters")
        XCTAssertTrue(mine.titleChosen)
        XCTAssertEqual(mine.alternatives, ["The Breath Comes First", "Twelve Rounds Before Any Posture", "Practice Together"])
        XCTAssertEqual(mine.notes, ["My notes. Enrollment opens in January."], "his words are never changed")
        XCTAssertFalse(mine.showNotes?.contains("Chapters") ?? true, "no chapters in the file, none in the notes")
    }

    /// A package written before 11 Oct (three plain captions, one of them about enrolled students)
    /// still reads; the caption that breaks the copy rules is left out of the text, and the checklist
    /// asks for captions per platform.
    func testAnOlderPackageStillReadsAndIsScreened() throws {
        var old = package(captions: false)
        old.oneLine = nil
        old.keywords = nil
        old.captions = ["Yin yoga returns on Mondays.", "Thousands of hours of curriculum are available to enrolled students."]
        old.summary = "The talk covers the school. It mentions pricing for teachers."
        let decoded = try XCTUnwrap(WrittenPackage.decode(old.json()))
        XCTAssertEqual(decoded.captionTexts, old.captions)
        let copy = PodcastPackage.copy(settings: PodcastReadySettings(), facts: PodcastEpisodeFacts(label: "Sun 13 Sep", kind: .talk), written: decoded, chapters: [])
        XCTAssertEqual(copy.plainCaptions, ["Yin yoga returns on Mondays."])
        XCTAssertEqual(copy.oneLine, "The talk covers the school.", "the summary's first sentence, when there is no one-line summary")
        XCTAssertEqual(copy.keywords, ["breath"], "the tags, when there are no keywords")
        XCTAssertEqual(copy.leftOut.count, 1)
        XCTAssertEqual(PodcastPackage.comment(facts: PodcastEpisodeFacts(), written: decoded), "The talk covers the school.", "the MP3's comment keeps the copy rules too")
    }

    // MARK: The checklist

    func testNumberingAndCaptionsInTheChecklist() {
        let measured = PodcastPackage.Measured(lufs: -16.0, truePeak: -1.3, lra: 4.7, normalizationType: "linear", sampleRate: 44_100, bitrateKbps: 96,
                                               channels: 1, duration: 418, expectedDuration: 418, bytes: 5_000_000, tailDecodes: true,
                                               tag: nil, intended: [], artwork: nil, chapterProblem: nil, chaptersWritten: 0, captions: (7, 0.08, 396),
                                               captionsProblem: nil)
        var facts = PodcastEpisodeFacts(label: "Sun 13 Sep", kind: .talk)
        var settings = PodcastReadySettings()
        func line(_ item: String) -> ChecklistLine? {
            PodcastPackage.checklist(measured, settings: settings, facts: facts, written: package()).first { $0.item == item }
        }
        XCTAssertEqual(line("Episode and season numbers")?.status, .pass, "not numbered: optional")
        settings.numbering = .episodes
        XCTAssertEqual(line("Episode and season numbers")?.status, .missing, "numbered, and no number")
        facts.episodeNumber = 2
        XCTAssertEqual(line("Episode and season numbers")?.status, .pass)
        settings.numbering = .seasons
        XCTAssertEqual(line("Episode and season numbers")?.status, .missing, "seasons, and no season")
        XCTAssertTrue(line("Episode and season numbers")?.detail.contains("the season is not set") == true)
        facts.seasonNumber = 1
        XCTAssertEqual(line("Episode and season numbers")?.status, .pass)

        XCTAssertEqual(line("Social captions")?.status, .pass)
        XCTAssertTrue(line("Social captions")?.detail.contains("3 pull quotes found word for word") == true)
        XCTAssertEqual(line("Copy rules")?.status, .pass)
        XCTAssertTrue(line("Show notes")?.detail.contains("No call to action is set") == true)
        settings.callToAction = "Write to the studio."
        XCTAssertTrue(line("Show notes")?.detail.contains("Your call to action closes them") == true)
    }

    // MARK: A class

    /// A class with the podcast-ready episode switched on: the two steps are refused and say why,
    /// nothing is mastered or written, and Update Podcast-Ready Files is refused too.
    func testAClassIsNeverMadeReadyToUpload() async throws {
        let tone = work.appending(path: "2026-10-11 class.m4a")
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-v", "error", "-f", "lavfi", "-i", "sine=frequency=220:duration=70", "-af", "volume=-12dB", "-c:a", "aac", tone.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        var options = PipelineOptions()
        options.stableWait = .milliseconds(200)
        options.makeTranscript = false
        options.kind = .lesson
        options.podcastReady = PodcastReadySetup(settings: PodcastReadySettings(), facts: PodcastEpisodeFacts(label: "Sun 11 Oct", kind: .lesson, fileName: tone.lastPathComponent))
        let folder = work.appending(path: "2026-10-11 class", directoryHint: .isDirectory)
        let result = await Pipeline(options: options, log: nil).run(file: tone, outputFolder: folder, label: "Sun 11 Oct") { _ in }
        XCTAssertEqual(result.outcome, .ready, result.reason)
        XCTAssertNil(result.podcastReady)
        XCTAssertEqual(result.podcastProblem, PodcastPackage.refusal(kind: .lesson))
        for step in [PipelineStep.podcastAudio, .podcastPackage] {
            let made = result.steps.first { $0.name == step.title }
            XCTAssertEqual(made?.state, .skipped, step.title)
            XCTAssertTrue(made?.detail?.hasPrefix("This is a class.") == true, made?.detail ?? "")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: PodcastPackage.folderName).path), "nothing written for a class")
        XCTAssertTrue(result.reason.contains("never made ready to upload"), result.reason)
        XCTAssertNil(PodcastPackage.refusal(kind: .talk))
        XCTAssertNil(PodcastPackage.refusal(kind: .unknown), "unknown is made, with What this is MISSING")
    }

    // MARK: Copy

    func testCopyPutsTheWordsOnThePasteboard() {
        let board = NSPasteboard(name: NSPasteboard.Name("studio.therowan.prakriti.tests.copy"))
        defer { board.releaseGlobally() }
        let caption = package().social?[0]
        Pasteboard.copy(caption?.post ?? "", to: board)
        XCTAssertEqual(board.string(forType: .string), "Why the long exhale comes first.\n\n#Breath #Pranayama")
    }
}
