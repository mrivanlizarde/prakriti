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
        // The word list's fixes are the ones in the cues, at their time in the original; a fix
        // inside a cut is in no file, so the report does not list it (verifier, 10 Oct: a 5:20 fix
        // inside the 5:00 to 5:30 cut was listed in the approved REPORT.md).
        XCTAssertEqual(made.corrections, [Lexicon.Correction(heard: "yoga market", written: "Yoga Marga", at: 0.5)])
        let firstCut = EpisodeTranscript.cues(sentences, clock: EpisodeClock(segments: EpisodeEdits(cuts: [TimeRange(start: 0, end: 4)]).segments(duration: 30)),
                                              applyLexicon: true)
        XCTAssertTrue(firstCut.corrections.isEmpty, "\(firstCut.corrections)")
        XCTAssertFalse(firstCut.cues.contains { $0.text.contains("Marga") })
    }

    /// Parakeet's real tokens, misplaced: it writes a sentence's text in the order it heard the words,
    /// then sorts the tokens by time, and where its listening chunks meet a few carry a too-early
    /// time. Joined as listed, these six read ", And as you guys remember we were doing a lot.",
    /// ". But the problem was that again, we spent $100 for the venue", " the You can always have
    /// access to Fathom ...",
    /// "when we you, know, really", "? Or what if you just exponentially increase that, right" and
    /// " room. I don't want to share a with someone": milestone 5 shipped those in the files that
    /// follow the episode (verifier, 10 Oct: 8 captions of the 6 Sep .srt began with "." or "?").
    func testParakeetsMisplacedTokensAreReadInTheOrderTheyWereSaid() throws {
        // Copied verbatim from transcript.json: 13 Sep at 1:58 and 14:14; 6 Sep at 5:29, 3:38, 15:59 and 33:29.
        let json = """
        {"text": "x", "sentences": [
          {"text": " And as you guys remember, we were doing a lot.", "start": 118.56, "end": 121.64, "tokens": [
            {"text": ",", "start": 118.56, "end": 118.8}, {"text": " And", "start": 118.84, "end": 119.16}, {"text": " as", "start": 119.72, "end": 119.96}, {"text": " you", "start": 119.96, "end": 120.12},
            {"text": " gu", "start": 120.12, "end": 120.2}, {"text": "ys", "start": 120.2, "end": 120.36}, {"text": " rem", "start": 120.36, "end": 120.52}, {"text": "ember", "start": 120.52, "end": 120.68},
            {"text": " we", "start": 120.76, "end": 120.92}, {"text": " were", "start": 120.92, "end": 121.08}, {"text": " do", "start": 121.08, "end": 121.16}, {"text": "ing", "start": 121.16, "end": 121.24},
            {"text": " a", "start": 121.24, "end": 121.4}, {"text": " lot", "start": 121.4, "end": 121.56}, {"text": ".", "start": 121.56, "end": 121.64}
          ]},
          {"text": " But the problem was that again, we spent $100 for the venue.", "start": 329.6, "end": 335.08, "tokens": [
            {"text": ".", "start": 329.6, "end": 329.68}, {"text": " But", "start": 330.12, "end": 330.44}, {"text": " the", "start": 330.44, "end": 330.76}, {"text": " problem", "start": 330.76, "end": 331.08},
            {"text": " was", "start": 331.08, "end": 331.4}, {"text": " that", "start": 331.4, "end": 331.64}, {"text": " aga", "start": 331.8, "end": 332.12}, {"text": "in", "start": 332.12, "end": 332.44},
            {"text": ",", "start": 332.44, "end": 332.76}, {"text": " we", "start": 332.76, "end": 333.0}, {"text": " sp", "start": 333.0, "end": 333.24}, {"text": "ent", "start": 333.24, "end": 333.4},
            {"text": " ", "start": 333.4, "end": 333.48}, {"text": "$", "start": 333.48, "end": 333.56}, {"text": "1", "start": 333.56, "end": 333.56}, {"text": "0", "start": 333.56, "end": 333.72},
            {"text": "0", "start": 333.72, "end": 333.88}, {"text": " for", "start": 334.2, "end": 334.44}, {"text": " the", "start": 334.44, "end": 334.6}, {"text": " ven", "start": 334.6, "end": 334.92},
            {"text": "ue", "start": 334.92, "end": 335.08}
          ]},
          {"text": " You can always have access to the Fathom if you're part of our private community and you're in the group chat.", "start": 854.76, "end": 865.12, "tokens": [
            {"text": " the", "start": 854.76, "end": 854.84}, {"text": " You", "start": 859.68, "end": 859.84}, {"text": " can", "start": 859.84, "end": 860.0}, {"text": " al", "start": 860.0, "end": 860.08},
            {"text": "wa", "start": 860.08, "end": 860.16}, {"text": "ys", "start": 860.16, "end": 860.24}, {"text": " have", "start": 860.24, "end": 860.4}, {"text": " ac", "start": 860.4, "end": 860.56},
            {"text": "cess", "start": 860.56, "end": 860.72}, {"text": " to", "start": 860.72, "end": 860.88}, {"text": " F", "start": 861.04, "end": 861.2}, {"text": "at", "start": 861.2, "end": 861.36},
            {"text": "hom", "start": 861.36, "end": 861.52}, {"text": " if", "start": 862.08, "end": 862.24}, {"text": " you", "start": 862.24, "end": 862.4}, {"text": "'", "start": 862.4, "end": 862.48},
            {"text": "re", "start": 862.48, "end": 862.64}, {"text": " part", "start": 862.64, "end": 862.8}, {"text": " of", "start": 862.8, "end": 862.96}, {"text": " our", "start": 862.96, "end": 863.12},
            {"text": " priv", "start": 863.12, "end": 863.28}, {"text": "ate", "start": 863.28, "end": 863.44}, {"text": " com", "start": 863.44, "end": 863.52}, {"text": "mun", "start": 863.52, "end": 863.6},
            {"text": "ity", "start": 863.6, "end": 863.68}, {"text": " and", "start": 863.76, "end": 863.92}, {"text": " you", "start": 863.92, "end": 864.0}, {"text": "'", "start": 864.0, "end": 864.08},
            {"text": "re", "start": 864.08, "end": 864.16}, {"text": " in", "start": 864.16, "end": 864.32}, {"text": " the", "start": 864.32, "end": 864.4}, {"text": " gro", "start": 864.4, "end": 864.56},
            {"text": "up", "start": 864.56, "end": 864.72}, {"text": " ch", "start": 864.72, "end": 864.88}, {"text": "at", "start": 864.88, "end": 865.04}, {"text": ".", "start": 865.04, "end": 865.12}
          ]},
          {"text": " And I remember when we started with our mentor, when we, you know, really signed up for our first business coach.", "start": 218.24, "end": 226.72, "tokens": [
            {"text": " And", "start": 218.24, "end": 218.56}, {"text": " I", "start": 219.72, "end": 220.04}, {"text": " rem", "start": 220.04, "end": 220.36}, {"text": "ember", "start": 220.36, "end": 220.68},
            {"text": " when", "start": 220.68, "end": 221.0}, {"text": " we", "start": 221.0, "end": 221.32}, {"text": " star", "start": 222.28, "end": 222.6}, {"text": "ted", "start": 222.6, "end": 222.92},
            {"text": " with", "start": 222.92, "end": 223.08}, {"text": " our", "start": 223.08, "end": 223.32}, {"text": " ment", "start": 223.32, "end": 223.56}, {"text": "or", "start": 223.56, "end": 223.72},
            {"text": ",", "start": 223.68, "end": 223.84}, {"text": " when", "start": 223.88, "end": 224.04}, {"text": " we", "start": 224.04, "end": 224.2}, {"text": " you", "start": 224.28, "end": 224.44},
            {"text": ",", "start": 224.32, "end": 224.4}, {"text": " know", "start": 224.44, "end": 224.52}, {"text": ",", "start": 224.64, "end": 224.8}, {"text": " really", "start": 224.68, "end": 224.84},
            {"text": " sig", "start": 225.04, "end": 225.2}, {"text": "ned", "start": 225.2, "end": 225.28}, {"text": " up", "start": 225.28, "end": 225.44}, {"text": " for", "start": 225.44, "end": 225.6},
            {"text": " our", "start": 225.6, "end": 225.76}, {"text": " first", "start": 225.76, "end": 225.92}, {"text": " bus", "start": 225.92, "end": 226.0}, {"text": "in", "start": 226.0, "end": 226.08},
            {"text": "ess", "start": 226.08, "end": 226.24}, {"text": " co", "start": 226.24, "end": 226.4}, {"text": "ach", "start": 226.4, "end": 226.56}, {"text": ".", "start": 226.56, "end": 226.72}
          ]},
          {"text": " Or what if you just exponentially increase that, right?", "start": 959.84, "end": 965.8, "tokens": [
            {"text": "?", "start": 959.84, "end": 960.0}, {"text": " Or", "start": 963.32, "end": 963.48}, {"text": " what", "start": 963.48, "end": 963.72}, {"text": " if", "start": 963.72, "end": 963.88},
            {"text": " you", "start": 963.88, "end": 964.04}, {"text": " just", "start": 964.04, "end": 964.2}, {"text": " ex", "start": 964.36, "end": 964.52}, {"text": "pon", "start": 964.52, "end": 964.76},
            {"text": "enti", "start": 964.76, "end": 964.92}, {"text": "ally", "start": 964.92, "end": 965.08}, {"text": " inc", "start": 965.08, "end": 965.16}, {"text": "re", "start": 965.16, "end": 965.24},
            {"text": "ase", "start": 965.24, "end": 965.32}, {"text": " that", "start": 965.4, "end": 965.56}, {"text": ",", "start": 965.56, "end": 965.64}, {"text": " right", "start": 965.64, "end": 965.8}
          ]},
          {"text": " I don't want to share a room with someone that I don't know.", "start": 2009.6, "end": 2012.6, "tokens": [
            {"text": " ro", "start": 2009.6, "end": 2009.68}, {"text": "om", "start": 2009.68, "end": 2009.84}, {"text": ".", "start": 2009.84, "end": 2009.92}, {"text": " I", "start": 2009.96, "end": 2010.12},
            {"text": " don", "start": 2010.12, "end": 2010.2}, {"text": "'", "start": 2010.2, "end": 2010.28}, {"text": "t", "start": 2010.28, "end": 2010.28}, {"text": " want", "start": 2010.28, "end": 2010.44},
            {"text": " to", "start": 2010.44, "end": 2010.52}, {"text": " sh", "start": 2010.52, "end": 2010.6}, {"text": "are", "start": 2010.6, "end": 2010.76}, {"text": " a", "start": 2010.76, "end": 2010.84},
            {"text": " with", "start": 2011.0, "end": 2011.16}, {"text": " some", "start": 2011.16, "end": 2011.32}, {"text": "one", "start": 2011.32, "end": 2011.48}, {"text": " that", "start": 2011.48, "end": 2011.64},
            {"text": " I", "start": 2011.64, "end": 2011.8}, {"text": " don", "start": 2011.8, "end": 2011.96}, {"text": "'", "start": 2011.96, "end": 2012.28}, {"text": "t", "start": 2012.28, "end": 2012.28},
            {"text": " know", "start": 2012.28, "end": 2012.6}
          ]}
        ]}
        """
        let sentences = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(json.utf8)))
        XCTAssertEqual(sentences.count, 6)
        for sentence in sentences {
            let tokens = try XCTUnwrap(sentence.tokens)
            XCTAssertEqual(tokens.map(\.text).joined(), sentence.text, "the tokens spell the sentence")
            XCTAssertTrue(zip(tokens, tokens.dropFirst()).allSatisfy { $0.start <= $1.start && $0.end >= $0.start }, "times run in order: \(sentence.text)")
            XCTAssertEqual(sentence.start, tokens[0].start)
        }
        // Each line starts at its first word, not at a misplaced full stop or word.
        XCTAssertEqual(sentences.map(\.start), [118.84, 330.12, 859.68, 218.24, 963.32, 2009.96])
        func token(_ sentence: Int, _ text: String, _ occurrence: Int = 0) throws -> EpisodeTranscript.Token {
            try XCTUnwrap(sentences[sentence].tokens?.filter { $0.text == text }.dropFirst(occurrence).first)
        }
        // A misplaced token is timed between the tokens it was said between.
        XCTAssertEqual(try token(0, ",").start, 120.68, accuracy: 0.001, "after \"remember\"")
        XCTAssertEqual(try token(0, ",").end, 120.76, accuracy: 0.001, "before \"we\"")
        XCTAssertEqual(try token(1, ".").start, 335.08, accuracy: 0.001, "after \"venue\"")
        XCTAssertEqual(try token(2, " the").start, 860.88, accuracy: 0.001, "after \"access to\"")
        XCTAssertEqual(try token(3, ",", 1).start, 224.20, accuracy: 0.001, "\"we,\" before \"you know\"")
        XCTAssertEqual(try token(4, "?").start, 965.80, accuracy: 0.001, "after \"right\"")
        XCTAssertEqual(try token(5, " ro").start, 2010.84, accuracy: 0.001, "\"a room with\", not before the sentence")
        XCTAssertEqual(try token(5, ".").start, 2012.60, accuracy: 0.001)

        // Only the silence trim: every sentence is kept whole, word for word as Parakeet wrote it.
        let trimmed = EpisodeTranscript.cues(sentences, clock: EpisodeClock(segments: [Mastering.Span(start: 1.18, end: 2100)]), applyLexicon: false)
        XCTAssertEqual(trimmed.removedWords, 0)
        XCTAssertEqual(trimmed.cues.map(\.text), sentences.map { $0.text.trimmingCharacters(in: .whitespaces) })
        XCTAssertEqual(trimmed.cues[1].start, 330.12 - 1.18, accuracy: 0.001)

        // Cuts through three of them (13 Sep: "we were"; 6 Sep: "But the problem was that again," and
        // "Or what if you"). "$100" is one word: its space, "$", "1", "0", "0" stay together.
        let cut13 = EpisodeEdits(cuts: [TimeRange(start: 120.70, end: 121.10)])
        let made13 = EpisodeTranscript.cues([sentences[0], sentences[2]], clock: EpisodeClock(segments: cut13.segments(duration: 950)), applyLexicon: false)
        XCTAssertEqual(made13.cues.map(\.text), ["And as you guys remember,", "doing a lot.", sentences[2].text.trimmingCharacters(in: .whitespaces)])
        XCTAssertEqual(made13.removedWords, 2)
        let cut06 = EpisodeEdits(cuts: [TimeRange(start: 330.0, end: 332.70), TimeRange(start: 963.0, end: 964.1)])
        let made06 = EpisodeTranscript.cues([sentences[1], sentences[4]], clock: EpisodeClock(segments: cut06.segments(duration: 3300)), applyLexicon: false)
        XCTAssertEqual(made06.cues.map(\.text), ["we spent $100 for the venue.", "just exponentially increase that, right?"])
        XCTAssertEqual(made06.removedWords, 6 + 4)
        for cue in trimmed.cues + made13.cues + made06.cues {
            XCTAssertFalse(EpisodeTranscript.isClosingPunctuation(String(cue.text.prefix(1))), "a line starts with punctuation: \(cue.text)")
        }

        // Tokens that cannot spell their sentence are left as they are; kept whole, the line is
        // Parakeet's own text, and part of it never opens with a stray full stop.
        let broken = EpisodeTranscript.Sentence(text: " Hello there.", start: 9.0, end: 10.6, tokens: [
            EpisodeTranscript.Token(text: ".", start: 9.0, end: 9.1), EpisodeTranscript.Token(text: " Hello", start: 10.0, end: 10.3),
            EpisodeTranscript.Token(text: " thera", start: 10.3, end: 10.6)])
        XCTAssertEqual(EpisodeTranscript.said(broken).tokens, broken.tokens)
        let brokenWhole = EpisodeTranscript.cues([broken], clock: EpisodeClock(segments: [Mastering.Span(start: 0, end: 20)]), applyLexicon: false)
        XCTAssertEqual(brokenWhole.cues.map(\.text), ["Hello there."])
        let brokenCut = EpisodeTranscript.cues([broken], clock: EpisodeClock(segments: EpisodeEdits(cuts: [TimeRange(start: 9.9, end: 10.2)]).segments(duration: 20)),
                                               applyLexicon: false)
        XCTAssertEqual(brokenCut.cues.map(\.text), ["thera"])
    }

    /// The report is copied into the approved folder, where transcript.json never goes, so it must
    /// not list it among the files; and a word list fix inside a cut is counted, never listed.
    func testTheReportNamesOnlyWhatTheFilesHold() {
        var options = PipelineOptions()
        options.applyLexicon = true
        options.transcriptFormats = [.txt, .srt, .vtt, .md]
        var result = PipelineResult()
        result.wordCount = 2948
        result.transcriptFollowsEpisode = true
        result.wordsLeftOut = 103
        result.corrections = [Lexicon.Correction(heard: "yoga marga", written: "Yoga Marga", at: 451)]
        result.fixesLeftOut = 1
        let report = Report.markdown(file: URL(fileURLWithPath: "/tmp/2026-09-13 18-25-44.mp4"), label: "Sun 13 Sep", result: result, options: options,
                                     steps: [], madeAt: Date(timeIntervalSince1970: 0))
        let row = report.components(separatedBy: "\n").first { $0.hasPrefix("| Transcript |") } ?? ""
        XCTAssertTrue(row.contains("`transcript.txt`, `.srt`, `.vtt`, `.md`; 2948 words heard"), row)
        XCTAssertFalse(row.contains(TranscriptFiles.asHeard), "the files row lists only what Approve copies: \(row)")
        XCTAssertTrue(report.contains("| Words as heard | `transcript.json`, every word with its time, is kept in the Outputs folder only. Approve never copies it"), report)
        XCTAssertTrue(report.contains("1 more fix fell in the parts taken out of the episode, so it is in no file and not listed."), report)
        XCTAssertTrue(report.contains("| Yoga Marga | yoga marga | 7:31 |"), report)
        XCTAssertEqual(report.components(separatedBy: "| Yoga Marga |").count - 1, 1, "only the fix in the files")
        XCTAssertFalse(report.contains("\u{2014}") || report.contains("\u{2013}"))
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
        XCTAssertEqual(pending.line, "Make Again first: the newest trim and cuts are not in the episode yet.")
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

    // MARK: The Viewer's player and lines (the page until v2 part M3b)

    /// The lines and the Viewer's words come from transcript.json with the word list applied, a cut line
    /// shows as cut, and a moment plays the episode from where it is (after the trim and the cut), or the
    /// original from the moment itself.
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

        let viewer = ViewerModel()
        viewer.player.isMuted = true
        viewer.load(recording, applyLexicon: true)
        XCTAssertNotNil(viewer.files[.podcast])
        XCTAssertEqual(viewer.rendition, .podcast, "the Viewer opens on the episode when it is made")
        let lines = RecordingTranscript.lines(folder: recording.outputFolder, applyLexicon: true)
        XCTAssertGreaterThanOrEqual(lines.count, 3, "\(lines.map(\.text))")
        XCTAssertTrue(lines[0].text.contains("Yoga Marga"), "the word list is applied to the lines: \(lines[0].text)")
        XCTAssertTrue(viewer.document.words.map(\.text).joined(separator: " ").contains("Yoga Marga"), "and to the Viewer's words")
        let parts = recording.edits.segments(duration: recording.duration ?? 0)
        print("Lines: " + lines.map { "\($0.start)-\($0.end) \($0.text)" }.joined(separator: " | "))
        // Parakeet stretches the second sentence's last word across the pause after it, past the end
        // of the cut, but every one of its words is said inside the cut: it reads as cut.
        let cutLine = try XCTUnwrap(lines.first { $0.speechStart >= cut.start && $0.speechStart <= cut.end }, "a line inside the cut")
        XCTAssertEqual(cutLine.fate(in: parts), .cut)
        let last = try XCTUnwrap(lines.last)
        XCTAssertEqual(last.fate(in: parts), .kept)
        // In the Viewer's words too: every word said inside the cut is struck through, none after it.
        let cutWords = viewer.document.words.filter { $0.position >= cut.start && $0.position <= cut.end }
        XCTAssertFalse(cutWords.isEmpty)
        XCTAssertTrue(cutWords.allSatisfy { !$0.isKept(in: parts) })
        XCTAssertTrue(viewer.document.words.filter { $0.position > cut.end + 0.5 }.allSatisfy { $0.isKept(in: parts) })

        // The last line, in the episode: its moment less the trimmed silence and the cut.
        viewer.seek(original: last.speechStart, play: false)
        let clock = try XCTUnwrap(recording.episodeClock)
        let expected = clock.episodeTime(last.speechStart).time
        XCTAssertLessThan(expected, last.speechStart - (cut.end - cut.start) + 0.01, "the episode plays it earlier")
        try await waitFor { abs(viewer.player.currentTime().seconds - expected) < 0.1 }
        XCTAssertEqual(viewer.player.currentTime().seconds, expected, accuracy: 0.1)
        XCTAssertEqual(viewer.currentOriginal ?? 0, last.speechStart, accuracy: 0.1, "and the Viewer reads it back on the original's clock")

        // The original: the same moment, as recorded.
        viewer.choose(.original, recording: recording)
        try await waitFor { viewer.player.currentItem != nil && abs(viewer.player.currentTime().seconds - last.speechStart) < 0.1 }
        XCTAssertEqual(viewer.player.currentTime().seconds, last.speechStart, accuracy: 0.1)
        XCTAssertNil(viewer.originalNote)
        viewer.pause()
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
