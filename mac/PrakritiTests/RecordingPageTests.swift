import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Milestone 5, the recording page: the trim and cuts become the parts the episode keeps, the
/// episode's clock maps a transcript line to the right moment, typed times read as people write
/// them, the transcript loses the words of a cut, and Approve copies the finished files, refusing a
/// class (and anything not marked as a talk) because speakers are not checked yet. Generated audio
/// and the Mac's own voice only; nothing here reads a real recording or writes into ~/Prakriti.
/// The 13 Sep talk is EditsAcceptanceTests (make accept-edits).
@MainActor
final class RecordingPageTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-page-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: Edits, the clock and typed times

    func testEditsBecomeThePartsTheEpisodeKeeps() {
        let duration = 947.78
        // The acceptance's edits: the first 10 s trimmed, 5:00 to 5:30 cut.
        let edits = EpisodeEdits(start: 10, end: nil, cuts: [TimeRange(start: 300, end: 330)])
        let parts = edits.segments(duration: duration)
        XCTAssertEqual(parts, [Mastering.Span(start: 10, end: 300), Mastering.Span(start: 330, end: duration)])
        XCTAssertEqual(parts.reduce(0) { $0 + $1.length }, duration - 40, accuracy: 0.001, "40 s shorter")
        // The silence trim's start (1.18 s) is inside Ivan's 10 s, so it changes nothing.
        XCTAssertEqual(edits.segments(duration: duration, silence: Mastering.Span(start: 1.18, end: duration)), parts)
        // Without a trim of Ivan's, the silence trim's start holds.
        XCTAssertEqual(EpisodeEdits(cuts: [TimeRange(start: 300, end: 330)]).segments(duration: duration, silence: Mastering.Span(start: 1.18, end: duration)).first?.start, 1.18)

        // Overlapping and touching cuts become one; a sliver under a quarter second between cuts goes too.
        let merged = EpisodeEdits.merged([TimeRange(start: 50, end: 60), TimeRange(start: 55, end: 70), TimeRange(start: 70, end: 80), TimeRange(start: 10, end: 20)])
        XCTAssertEqual(merged, [TimeRange(start: 10, end: 20), TimeRange(start: 50, end: 80)])
        let sliver = EpisodeEdits(cuts: [TimeRange(start: 10, end: 20), TimeRange(start: 20.1, end: 30)]).segments(duration: 100)
        XCTAssertEqual(sliver, [Mastering.Span(start: 0, end: 10), Mastering.Span(start: 30, end: 100)], "a 0.1 s blip is cut, not kept")
        XCTAssertEqual(EpisodeEdits().adding(cut: TimeRange(start: 5, end: 9)).adding(cut: TimeRange(start: 1, end: 6)).cuts, [TimeRange(start: 1, end: 9)])

        // Problems, in plain words.
        XCTAssertNil(edits.problem(duration: duration))
        XCTAssertEqual(EpisodeEdits(start: 1000).problem(duration: duration), "The start (16:40) is after the end of the recording (15:47.8).")
        XCTAssertEqual(EpisodeEdits(start: 300, end: 200).problem(duration: duration), "The start (5:00) is after the end (3:20).")
        XCTAssertEqual(EpisodeEdits(cuts: [TimeRange(start: 0, end: duration)]).problem(duration: duration), "Nothing would be left of the episode after the trim and the cuts.")
        XCTAssertNil(EpisodeEdits(end: duration + 0.3).problem(duration: duration), "an end a fraction past the end is the end")

        // The same edits, whatever order the cuts were typed in.
        XCTAssertTrue(edits.matches(EpisodeEdits(start: 10.001, end: nil, cuts: [TimeRange(start: 300, end: 330)])))
        XCTAssertFalse(edits.matches(EpisodeEdits(start: 10)))
        XCTAssertTrue(EpisodeEdits().isEmpty)
        XCTAssertEqual(edits.summary, "Starts at 0:10. 1 cut: 5:00 to 5:30 (30 s).")
        for text in [edits.summary ?? "", EpisodeEdits(start: 1000).problem(duration: duration) ?? ""] {
            XCTAssertFalse(text.contains("\u{2014}"))
        }
    }

    func testTheEpisodeClockMapsBothWays() {
        let clock = EpisodeClock(intro: 3, segments: [Mastering.Span(start: 10, end: 300), Mastering.Span(start: 330, end: 947.78)])
        XCTAssertEqual(clock.keptLength, 907.78, accuracy: 0.001)
        XCTAssertEqual(clock.episodeTime(10).time, 3, accuracy: 0.001)
        XCTAssertEqual(clock.episodeTime(100).time, 93, accuracy: 0.001)
        XCTAssertFalse(clock.episodeTime(100).removed)
        // Inside the cut: where the episode carries on, flagged as removed.
        XCTAssertEqual(clock.episodeTime(310).time, 293, accuracy: 0.001)
        XCTAssertTrue(clock.episodeTime(310).removed)
        XCTAssertTrue(clock.episodeTime(2).removed, "the trimmed start")
        XCTAssertEqual(clock.episodeTime(2).time, 3, accuracy: 0.001)
        XCTAssertEqual(clock.episodeTime(400).time, 3 + 290 + 70, accuracy: 0.001)
        XCTAssertEqual(clock.originalTime(363) ?? 0, 400, accuracy: 0.001)
        XCTAssertNil(clock.originalTime(1), "inside the intro")
        XCTAssertNil(clock.originalTime(5000), "past the end")
        for t in stride(from: 10.0, to: 947, by: 37) where !(300...330).contains(t) {
            XCTAssertEqual(clock.originalTime(clock.episodeTime(t).time) ?? -1, t, accuracy: 0.001)
        }
        XCTAssertTrue(EpisodeClock(segments: [Mastering.Span(start: 0, end: 90)]).isIdentity(duration: 90))
        XCTAssertFalse(EpisodeClock(segments: [Mastering.Span(start: 1.18, end: 90)]).isIdentity(duration: 90))
        XCTAssertFalse(EpisodeClock(intro: 2, segments: [Mastering.Span(start: 0, end: 90)]).isIdentity(duration: 90))
    }

    func testTimesAreTypedAsPeopleWriteThem() {
        XCTAssertEqual(TimeText.seconds("4:12"), 252)
        XCTAssertEqual(TimeText.seconds("1:02:30"), 3750)
        XCTAssertEqual(TimeText.seconds("75"), 75)
        XCTAssertEqual(TimeText.seconds(" 0:10 "), 10)
        XCTAssertEqual(TimeText.seconds("4:12.5"), 252.5)
        XCTAssertEqual(TimeText.seconds("15:47.8"), 947.8)
        for wrong in ["", "4:", ":12", "4:75", "1:60:00", "four", "4.12.1", "1:2:3:4", "-5", "4m12s"] {
            XCTAssertNil(TimeText.seconds(wrong), wrong)
        }
        XCTAssertEqual(TimeText.string(252), "4:12")
        XCTAssertEqual(TimeText.string(3750), "1:02:30")
        XCTAssertEqual(TimeText.string(252.5), "4:12.5")
        XCTAssertEqual(TimeText.string(10), "0:10")
        XCTAssertEqual(TimeText.string(947.78), "15:47.8")
    }

    // MARK: The cut, in the chain

    func testACutIsOneGraphWithFadesAndTheLimiterAfterIt() {
        let measured = Measure.LoudnormPass(inputI: "-26.67", inputTP: "-0.38", inputLRA: "6.10", inputThresh: "-37.10",
                                            targetOffset: "0.52", normalizationType: "dynamic")
        let second = Mastering.secondPassLoudness(target: -16, ceiling: -1, measured: measured)
        let program = Mastering.Program(kept: nil, channels: .mono, parts: [Mastering.Span(start: 10, end: 300), Mastering.Span(start: 330, end: 947.78)])
        let args = Mastering.pass(file: "/a.mp4", program: program, loudness: second)
        XCTAssertEqual(Array(args.prefix(2)), ["-i", "/a.mp4"])
        XCTAssertEqual(args.suffix(2), ["-map", "[episode]"])
        XCTAssertEqual(args[3], "[0:a]asplit=2[s0][s1];"
                       + "[s0]atrim=start=10.000:end=300.000,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.015,afade=t=out:st=289.985:d=0.015[p0];"
                       + "[s1]atrim=start=330.000:end=947.780,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.015,afade=t=out:st=617.765:d=0.015[p1];"
                       + "[p0][p1]concat=n=2:v=0:a=1,aformat=channel_layouts=mono,aresample=48000[talk];"
                       + "[talk]" + second + "[episode]")
        XCTAssertTrue(args[3].contains("level=disabled"), "v0's bug 1")
        XCTAssertLessThan(args[3].range(of: "aresample=48000")!.lowerBound, args[3].range(of: "alimiter")!.lowerBound, "v0's bug 2: the rate is set before the limiter")
        // With an intro: the talk is input 1, and the pieces join before the loudness filters.
        let withIntro = Mastering.pass(file: "/a.mp4", program: Mastering.Program(kept: nil, channels: .mono, intro: .init(path: "/i.wav", gainDB: -2),
                                                                                  parts: [Mastering.Span(start: 10, end: 300)]), loudness: second)
        XCTAssertEqual(Array(withIntro.prefix(4)), ["-i", "/i.wav", "-i", "/a.mp4"])
        XCTAssertTrue(withIntro[5].hasPrefix("[0:a]aformat=channel_layouts=mono,aresample=48000,volume=-2dB[intro];[1:a]atrim=start=10.000:end=300.000"), withIntro[5])
        XCTAssertTrue(withIntro[5].contains("[intro][talk]concat=n=2:v=0:a=1,"), withIntro[5])
        // No edits: milestone 4's chain, string for string.
        XCTAssertEqual(Mastering.pass(file: "/a.mp4", program: Mastering.Program(), loudness: second), ["-i", "/a.mp4", "-vn", "-af", Mastering.format(.mono) + "," + second])
    }

    // MARK: The transcript follows the episode

    func testTheEpisodeTranscriptLosesTheWordsOfACut() throws {
        let json = """
        {"text": "x", "sentences": [
          {"text": " Welcome to the yoga market school.", "start": 0.5, "end": 3.0, "tokens": [
            {"text": " Welcome", "start": 0.5, "end": 0.9}, {"text": " to", "start": 0.9, "end": 1.1}, {"text": " the", "start": 1.1, "end": 1.3},
            {"text": " yoga", "start": 1.3, "end": 1.7}, {"text": " market", "start": 1.7, "end": 2.2}, {"text": " school.", "start": 2.2, "end": 3.0}]},
          {"text": " Maria asks about her divorce.", "start": 10.0, "end": 13.0, "tokens": [
            {"text": " Mar", "start": 10.0, "end": 10.3}, {"text": "ia", "start": 10.3, "end": 10.6}, {"text": " asks", "start": 10.6, "end": 11.0},
            {"text": " about", "start": 11.0, "end": 11.5}, {"text": " her", "start": 11.5, "end": 12.0}, {"text": " divorce.", "start": 12.0, "end": 13.0}]},
          {"text": " Then we breathe, and then we rest.", "start": 14.0, "end": 26.0, "tokens": [
            {"text": " Then", "start": 20.0, "end": 20.5}, {"text": " we", "start": 20.5, "end": 21.0}, {"text": " breathe,", "start": 21.0, "end": 22.0},
            {"text": " and", "start": 22.0, "end": 23.0}, {"text": " then", "start": 23.0, "end": 24.0}, {"text": " we", "start": 24.0, "end": 25.0}, {"text": " rest.", "start": 25.0, "end": 26.0}]},
          {"text": " Okay.", "start": 26.0, "end": 29.6, "tokens": [{"text": " Okay", "start": 27.0, "end": 27.3}, {"text": ".", "start": 29.5, "end": 29.6}]}
        ]}
        """
        let sentences = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(json.utf8)))
        XCTAssertEqual(sentences.count, 4)
        // Cut 9 to 14 (the student's question), 22 to 23 (one word in the middle of a sentence) and
        // 26.5 to 29 ("Okay", whose full stop Parakeet placed after the cut, at 29.5).
        let edits = EpisodeEdits(cuts: [TimeRange(start: 9, end: 14), TimeRange(start: 22, end: 23), TimeRange(start: 26.5, end: 29)])
        let clock = EpisodeClock(intro: 0, segments: edits.segments(duration: 30))
        let made = EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: true)
        XCTAssertEqual(made.removedWords, 5 + 1 + 1, "the question's five words, the one word cut from the third sentence, and Okay")
        XCTAssertEqual(made.cues.map(\.text), ["Welcome to the Yoga Marga school.", "Then we breathe,", "then we rest."])
        let text = EpisodeTranscript.text(made.cues)
        XCTAssertFalse(text.contains("Maria") || text.contains("divorce"), "the cut words are gone: \(text)")
        // On the episode's clock: 5 s cut before the last sentence (20 s plays at 15 s), then 1 s
        // more inside it (23 s plays at 17 s).
        XCTAssertEqual(made.cues[1].start, 15, accuracy: 0.001)
        XCTAssertEqual(made.cues[2].start, 17, accuracy: 0.001)
        XCTAssertEqual(made.cues[2].end, 20, accuracy: 0.001)
        let srt = EpisodeTranscript.srt(made.cues)
        XCTAssertEqual(srt, """
        1
        00:00:00,500 --> 00:00:03,000
        Welcome to the Yoga Marga school.

        2
        00:00:15,000 --> 00:00:17,000
        Then we breathe,

        3
        00:00:17,000 --> 00:00:20,000
        then we rest.

        """)
        XCTAssertTrue(EpisodeTranscript.vtt(made.cues).hasPrefix("WEBVTT\n\n00:00:00.500 --> 00:00:03.000\nWelcome"))
        XCTAssertEqual(Measure.lastCueEnd(srt: srt), 20)
        // Nothing cut: every word, at its own time.
        let whole = EpisodeTranscript.cues(sentences, clock: EpisodeClock(segments: [Mastering.Span(start: 0, end: 30)]), applyLexicon: false)
        XCTAssertEqual(whole.removedWords, 0)
        XCTAssertEqual(whole.cues.map(\.start), [0.5, 10, 20, 27])
        XCTAssertEqual(whole.cues.first?.text, "Welcome to the yoga market school.", "the word list was off")
    }

    /// Through the real tools: the Mac's own voice says three sentences, the middle one names a
    /// student, it is cut, and the episode and its transcript lose it while transcript.json keeps it.
    func testATrimAndACutMakeTheEpisodeShorterAndTheTranscriptForgetsTheCut() async throws {
        let lines = ["The first part of the talk is about breathing slowly.",
                     "A student named Maria asks about her divorce.",
                     "The last part of the talk is about resting well."]
        var spoken: [URL] = []
        for (index, line) in lines.enumerated() {
            let url = work.appending(path: "line\(index).aiff")
            let say = Process()
            say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            say.arguments = ["-o", url.path, line]
            try say.run()
            say.waitUntilExit()
            XCTAssertEqual(say.terminationStatus, 0)
            spoken.append(url)
        }
        let lengths = try spoken.map { try XCTUnwrap(probeDuration($0)) }
        // 2 s of silence, line 1, 3 s, line 2, 3 s, line 3, then silence to 70 s.
        let same = "aformat=sample_fmts=fltp:sample_rates=22050:channel_layouts=mono"
        let graph = (0..<6).map { "[\($0):a]\(same)[a\($0)]" }.joined(separator: ";") + ";"
            + (0..<6).map { "[a\($0)]" }.joined() + "concat=n=6:v=0:a=1,apad=whole_dur=70"
        let file = try make("2026-10-10 three lines.m4a", ["-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=2", "-i", spoken[0].path,
                                                            "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=3", "-i", spoken[1].path,
                                                            "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=3", "-i", spoken[2].path,
                                                            "-filter_complex", graph, "-c:a", "aac"])
        let duration = try XCTUnwrap(probeDuration(file))
        let questionStart = 2 + lengths[0] + 3, questionEnd = questionStart + lengths[1]
        let cut = TimeRange(start: questionStart - 1, end: questionEnd + 1)
        var options = PipelineOptions()
        options.stableWait = .milliseconds(200)
        options.transcriptFormats = Set(TranscriptFormat.allCases)
        options.applyLexicon = true
        options.edits = EpisodeEdits(start: 1, end: nil, cuts: [cut])
        let folder = work.appending(path: "2026-10-10 three lines", directoryHint: .isDirectory)
        let result = await Pipeline(options: options, log: nil).run(file: file, outputFolder: folder, label: "Sat 10 Oct") { _ in }
        XCTAssertEqual(result.outcome, .ready, result.reason)

        // The episode is the recording less the trimmed second and the cut.
        let expected = duration - 1 - (cut.end - cut.start)
        XCTAssertEqual(result.episodeDuration ?? 0, expected, accuracy: 0.3)
        XCTAssertEqual(try XCTUnwrap(probeDuration(folder.appending(path: "episode.mp3"))), expected, accuracy: 0.3, "ffprobe agrees")
        XCTAssertEqual(result.parts, [Mastering.Span(start: 1, end: cut.start), Mastering.Span(start: cut.end, end: duration)])
        XCTAssertTrue(result.steps.contains { $0.name == PipelineStep.edits.title && $0.state == .done })

        // The transcript files lose the student; transcript.json keeps every word as heard.
        let txt = try String(contentsOf: folder.appending(path: "transcript.txt"), encoding: .utf8)
        let srt = try String(contentsOf: folder.appending(path: "transcript.srt"), encoding: .utf8)
        let md = try String(contentsOf: folder.appending(path: "transcript.md"), encoding: .utf8)
        let heard = try String(contentsOf: folder.appending(path: "transcript.json"), encoding: .utf8)
        print("Heard: \(heard.prefix(400))\nEpisode transcript: \(txt)")
        for file in [txt, srt, md] {
            XCTAssertFalse(file.localizedCaseInsensitiveContains("divorce"), "the cut words are still there: \(file)")
            XCTAssertTrue(file.localizedCaseInsensitiveContains("breathing"), file)
            XCTAssertTrue(file.localizedCaseInsensitiveContains("resting"), file)
        }
        XCTAssertTrue(heard.localizedCaseInsensitiveContains("divorce"), "transcript.json keeps what was heard")
        XCTAssertGreaterThan(result.wordsLeftOut ?? 0, 4)
        XCTAssertTrue(result.transcriptFollowsEpisode)
        XCTAssertTrue(md.contains("Times are from the start of the episode"), md)
        // The last line is timed on the episode's clock: it starts where the episode says it.
        let cues = TranscriptFiles.cues(srt: srt)
        let last = try XCTUnwrap(cues.last { $0.text.localizedCaseInsensitiveContains("resting") })
        let lastInOriginal = 2 + lengths[0] + 3 + lengths[1] + 3
        XCTAssertEqual(last.start, lastInOriginal - 1 - (cut.end - cut.start), accuracy: 1.0, "the last line moved up by the trim and the cut")

        let report = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(report.contains("| Your edits | Starts at 0:01. 1 cut:"), report)
        XCTAssertTrue(report.contains("The transcript files follow the episode"), report)
        XCTAssertFalse(report.localizedCaseInsensitiveContains("divorce"), "the report never carries transcript text")
    }

    // MARK: Approve

    private func modelWithMadeRecording(kind: RecordingKind) throws -> (AppModel, Recording) {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        let folder = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let made = ["REPORT.md", "episode.mp3", "transcript.json", "transcript.md", "transcript.srt", "transcript.txt", "transcript.vtt"]
        for name in made { try "made: \(name)".write(to: folder.appending(path: name), atomically: true, encoding: .utf8) }
        let recording = Recording(filePath: home.appending(path: "Prakriti/Dev/Drop/2026-09-13 18-25-44.mp4").path, title: "Talk with Gabriel",
                                  recordedAt: Fixtures.date(2026, 9, 13, 18, 25, 44), foundAt: Fixtures.now, duration: 947.78,
                                  status: .readyForYourYes, kind: kind)
        recording.outputFolder = folder.path
        recording.madeFiles = made
        recording.episodeDuration = 946.6
        model.context.insert(recording)
        try model.context.save()
        return (model, recording)
    }

    /// The acceptance's rule: a recording marked "class" cannot be approved, whoever asks.
    func testAClassCannotBeApproved() throws {
        let (model, recording) = try modelWithMadeRecording(kind: .lesson)
        let check = model.approvalCheck(recording)
        XCTAssertFalse(check.canApprove)
        XCTAssertTrue(check.speakersNotChecked, "the page shows Speakers not checked")
        XCTAssertEqual(check.line, "This is a class, so students may be heard. A class cannot be approved until Prakriti can check who is speaking.")
        XCTAssertFalse(model.approve(recording), "the button is not the only guard")
        XCTAssertEqual(recording.status, .readyForYourYes)
        XCTAssertNil(recording.approvedAt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.approvedFolder(for: recording).path), "nothing was copied")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(activity.contains { $0.hasPrefix("Did not approve Sun 13 Sep") && $0.contains("Speakers not checked") }, "\(activity)")
        XCTAssertEqual(model.notice?.title, "Speakers not checked")

        // So are a conversation and a recording nobody has said is a talk; a test never is.
        for kind in [RecordingKind.conversation, .unknown, .test] {
            recording.kind = kind
            XCTAssertFalse(model.approvalCheck(recording).canApprove, kind.rawValue)
            XCTAssertFalse(model.approve(recording), kind.rawValue)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.approvedFolder(for: recording).path))
    }

    func testApprovingATalkCopiesTheFinishedFilesAndAReceipt() throws {
        let (model, recording) = try modelWithMadeRecording(kind: .talk)
        recording.notes = "Gabriel on enrolment."
        let check = model.approvalCheck(recording)
        XCTAssertTrue(check.canApprove, check.line ?? "")
        XCTAssertFalse(check.speakersNotChecked)
        XCTAssertTrue(model.approve(recording))
        let folder = model.approvedFolder(for: recording)
        XCTAssertEqual(folder.path, model.paths.approved.path + "/2026-09-13 18-25-44", "Approved/<name>, beside Outputs/<name>")
        XCTAssertEqual(recording.status, .approved)
        XCTAssertEqual(recording.approvedAt, Fixtures.now)
        XCTAssertEqual(recording.approvedFolder, folder.path)
        let copied = Pipeline.madeFiles(in: folder)
        XCTAssertEqual(copied, ["APPROVAL.md", "REPORT.md", "episode.mp3", "transcript.md", "transcript.srt", "transcript.txt", "transcript.vtt"],
                       "everything made except transcript.json, which keeps the words of any cut")
        XCTAssertEqual(recording.approvedFiles, copied)
        let receipt = try String(contentsOf: folder.appending(path: "APPROVAL.md"), encoding: .utf8)
        XCTAssertTrue(receipt.contains("# Sun 13 Sep: Talk with Gabriel"), receipt)
        XCTAssertTrue(receipt.contains("Gabriel on enrolment."), receipt)
        XCTAssertTrue(receipt.contains("**Nothing has been uploaded or published.**"), receipt)
        XCTAssertTrue(receipt.contains("| episode.mp3 | 17 bytes | `\(try Approval.sha256(folder.appending(path: "episode.mp3")))` |"), receipt)
        XCTAssertFalse(receipt.contains("\u{2014}"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.paths.approved.appending(path: ".approving 2026-09-13 18-25-44").path), "no staging folder left")
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: recording.outputFolder!).appending(path: "episode.mp3"), encoding: .utf8), "made: episode.mp3",
                       "the finished files stay where they were")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(activity.contains { $0.hasPrefix("Approved Sun 13 Sep") && $0.contains("Nothing was uploaded or published.") }, "\(activity)")

        // Approved, it cannot be approved again until something changes.
        XCTAssertFalse(model.approvalCheck(recording).canApprove)
        // Any change takes the approval back, and leaves the approved copy as it was.
        recording.title = "Talk with Gabriel, edited"
        model.changedAfterApproval(recording, what: "its title")
        XCTAssertEqual(recording.status, .readyForYourYes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: "episode.mp3").path))
        XCTAssertTrue(model.approvalCheck(recording).canApprove)

        // A trim on the page that is not in the episode yet: Make Again first.
        XCTAssertNil(model.setTrim(start: 10, end: nil, for: recording))
        XCTAssertTrue(recording.editsPending)
        let pending = model.approvalCheck(recording)
        XCTAssertFalse(pending.canApprove)
        XCTAssertEqual(pending.line, "Make Again first: the trim and cuts on this page are not in the episode yet.")
        XCTAssertFalse(model.approve(recording))

        // Approving again replaces the copy; a file Ivan keeps there stays.
        model.clearEdits(recording)
        try "mine".write(to: folder.appending(path: "notes from Ivan.txt"), atomically: true, encoding: .utf8)
        recording.madeFiles = ["REPORT.md", "episode.mp3", "transcript.json"]
        XCTAssertTrue(model.approve(recording))
        XCTAssertEqual(Pipeline.madeFiles(in: folder), ["APPROVAL.md", "REPORT.md", "episode.mp3", "notes from Ivan.txt"])
    }

    func testTheTrimAndCutsOnThePage() throws {
        let (model, recording) = try modelWithMadeRecording(kind: .talk)
        XCTAssertFalse(recording.editsPending, "nothing changed")
        XCTAssertNil(model.setTrim(start: 10, end: nil, for: recording))
        XCTAssertNil(model.addCut(TimeRange(start: 300, end: 320), to: recording))
        XCTAssertNil(model.addCut(TimeRange(start: 315, end: 330), to: recording), "an overlapping cut joins the first")
        XCTAssertEqual(recording.cuts, [TimeRange(start: 300, end: 330)])
        XCTAssertEqual(recording.edits.summary, "Starts at 0:10. 1 cut: 5:00 to 5:30 (30 s).")
        XCTAssertTrue(recording.editsPending)
        XCTAssertEqual(model.setTrim(start: 2000, end: nil, for: recording), "The start (33:20) is after the end of the recording (15:47.8).")
        XCTAssertEqual(recording.trimStart, 10, "a time that cannot work changes nothing")
        XCTAssertEqual(model.addCut(TimeRange(start: 40, end: 30), to: recording), "A cut must end after it starts.")
        XCTAssertNil(model.setTrim(start: 10, end: 947.78, for: recording))
        XCTAssertNil(recording.trimEnd, "an end at the recording's own end is no trim")
        model.removeCut(TimeRange(start: 300, end: 330), from: recording)
        XCTAssertEqual(recording.cuts, [])
        model.setKind(.lesson, for: recording)
        XCTAssertTrue(recording.isPrivacyLocked, "a class is privacy locked")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        XCTAssertTrue(activity.contains("Sun 13 Sep (2026-09-13 18-25-44.mp4): the episode now starts at 0:10. Make Again to hear it."), "\(activity)")
        XCTAssertTrue(activity.contains { $0.contains("cut 5:00 to 5:20 (20 s) marked") }, "\(activity)")
        XCTAssertTrue(activity.contains { $0.contains("marked as a class") }, "\(activity)")

        // The page's lines know which were cut.
        let line = TranscriptLine(id: 0, start: 305, end: 312, text: "x")
        let parts = EpisodeEdits(start: 10, cuts: [TimeRange(start: 300, end: 330)]).segments(duration: 947.78)
        XCTAssertEqual(line.fate(in: parts), .cut)
        XCTAssertEqual(TranscriptLine(id: 1, start: 295, end: 305, text: "x").fate(in: parts), .partlyCut)
        XCTAssertEqual(TranscriptLine(id: 2, start: 400, end: 410, text: "x").fate(in: parts), .kept)
        XCTAssertEqual(TranscriptLine(id: 3, start: 2, end: 8, text: "x").fate(in: parts), .cut, "before the start is cut too")
    }

    /// The runner hands the page's edits to the pipeline and keeps what the episode was made with.
    func testMakeAgainUsesThePageEditsAndRemembersThem() async throws {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .milliseconds(200)
        let tone = try make("2026-09-13 tone.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=90", "-af", "volume=-12dB", "-c:a", "aac"])
        let recording = Recording(filePath: tone.path, recordedAt: AppModel.dateInName(tone.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        model.setOutput(.transcript, on: false, for: recording)
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let before = try XCTUnwrap(recording.episodeDuration)

        XCTAssertNil(model.setTrim(start: 10, end: nil, for: recording))
        XCTAssertNil(model.addCut(TimeRange(start: 40, end: 60), to: recording))
        XCTAssertEqual(model.runner.options(for: recording).edits, recording.edits)
        XCTAssertTrue(recording.editsPending)
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        XCTAssertFalse(recording.editsPending, "the episode now has the page's edits")
        XCTAssertEqual(before - (recording.episodeDuration ?? 0), 30, accuracy: 0.3, "10 s trimmed and 20 s cut")
        XCTAssertEqual(recording.episodeParts, [TimeRange(start: 10, end: 40), TimeRange(start: 60, end: recording.duration ?? 0)])
        let clock = try XCTUnwrap(recording.episodeClock)
        XCTAssertEqual(clock.episodeTime(70).time, 40, accuracy: 0.001)
        XCTAssertEqual(recording.episodeDuration ?? 0, clock.keptLength, accuracy: 0.3)
    }

    // MARK: The page's player and lines

    /// The page itself: its lines come from transcript.json with the word list applied, a cut line
    /// shows as cut, and a line plays the episode from where its moment is (after the trim and the
    /// cut), or the original from the moment itself.
    func testALinePlaysTheEpisodeFromWhereItsMomentIs() async throws {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .milliseconds(200)
        var spoken: [URL] = []
        for (index, line) in ["Welcome back to the yoga market school.", "This sentence will be cut.", "And this one stays in the episode."].enumerated() {
            let url = work.appending(path: "page\(index).aiff")
            let say = Process()
            say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            say.arguments = ["-o", url.path, line]
            try say.run()
            say.waitUntilExit()
            spoken.append(url)
        }
        let same = "aformat=sample_fmts=fltp:sample_rates=22050:channel_layouts=mono"
        let graph = (0..<6).map { "[\($0):a]\(same)[a\($0)]" }.joined(separator: ";") + ";"
            + (0..<6).map { "[a\($0)]" }.joined() + "concat=n=6:v=0:a=1,apad=whole_dur=70"
        let file = try make("2026-10-10 page.m4a", ["-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=2", "-i", spoken[0].path,
                                                     "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=4", "-i", spoken[1].path,
                                                     "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=4", "-i", spoken[2].path,
                                                     "-filter_complex", graph, "-c:a", "aac"])
        let lengths = try spoken.map { try XCTUnwrap(probeDuration($0)) }
        let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date(), kind: .talk)
        model.context.insert(recording)
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")

        let secondStart = 2 + lengths[0] + 4
        let cut = TimeRange(start: secondStart - 1.5, end: secondStart + lengths[1] + 1.5)
        XCTAssertNil(model.addCut(cut, to: recording))
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")

        let page = RecordingPage()
        page.load(recording, applyLexicon: true)
        XCTAssertTrue(page.hasEpisode)
        XCTAssertEqual(page.listening, .episode)
        XCTAssertGreaterThanOrEqual(page.lines.count, 3, "\(page.lines.map(\.text))")
        XCTAssertTrue(page.lines[0].text.contains("Yoga Marga"), "the word list is applied to the lines: \(page.lines[0].text)")
        let parts = recording.edits.segments(duration: recording.duration ?? 0)
        print("Page lines: " + page.lines.map { "\($0.start)-\($0.end) \($0.text)" }.joined(separator: " | "))
        // Parakeet stretches the second sentence's last word across the pause after it, past the end
        // of the cut, but every one of its words is said inside the cut: it reads as cut.
        let cutLine = try XCTUnwrap(page.lines.first { $0.speechStart >= cut.start && $0.speechStart <= cut.end }, "a line inside the cut")
        XCTAssertEqual(cutLine.fate(in: parts), .cut)
        let last = try XCTUnwrap(page.lines.last)
        XCTAssertEqual(last.fate(in: parts), .kept)

        // The last line, in the episode: its moment less the trimmed silence and the cut.
        page.seek(original: last.speechStart, play: false)
        let clock = try XCTUnwrap(recording.episodeClock)
        let expected = clock.episodeTime(last.speechStart).time
        XCTAssertLessThan(expected, last.speechStart - (cut.end - cut.start) + 0.01, "the episode plays it earlier")
        try await waitFor { abs(page.player.currentTime().seconds - expected) < 0.1 }
        XCTAssertEqual(page.player.currentTime().seconds, expected, accuracy: 0.1)
        XCTAssertEqual(page.currentOriginal ?? 0, last.speechStart, accuracy: 0.1, "and the page reads it back on the original's clock")

        // The original: the same moment, as recorded.
        page.listen(to: .original, recording: recording)
        try await waitFor { page.player.currentItem != nil && abs(page.player.currentTime().seconds - last.speechStart) < 0.1 }
        XCTAssertEqual(page.player.currentTime().seconds, last.speechStart, accuracy: 0.1)
        XCTAssertNil(page.originalNote)
        page.player.pause()
    }

    private func waitFor(_ condition: () -> Bool, seconds: Double = 10) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
    }

    // MARK: Helpers

    private func make(_ name: String, _ arguments: [String]) throws -> URL {
        let url = work.appending(path: name)
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-v", "error", "-y"] + arguments + [url.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "ffmpeg could not make \(name)")
        return url
    }

    private func probeDuration(_ file: URL) throws -> Double? {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffprobe
        process.arguments = ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Double(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
