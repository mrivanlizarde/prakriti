import Foundation
import XCTest
@testable import Prakriti

/// v2 part TXGAP: speech the transcript has no words for. Parakeet, run once over the 6 Sep talk, wrote nothing for 17 s
/// at 24:22 and 39:24 and the old coverage check (does it reach the end?) passed. Here: the gap is found by comparing
/// the sound's envelope with the words' times, transcribed again and merged without duplicates, and a gap planted in
/// Parakeet's own output is caught by the coverage check when the second listen cannot fill it.
@MainActor
final class TranscriptGapsTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-txgap-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: Finding gaps, without Parakeet

    /// 30 s of sound: speech everywhere but 10 to 12 s (room), with words everywhere but 10 to 25 s. The stretch 10 to
    /// 25 s has no words and 13 s of speech: it is listened to again and fails the check. A pause of 2 s with no words
    /// is not a gap.
    func testAWordlessStretchWithSpeechIsFoundAndAQuietOneIsNot() {
        var levels = [Double](repeating: -25, count: 3_000)
        for i in 1_000..<1_200 { levels[i] = -70 }
        for i in 0..<300 { levels[i] = -70 } // a quiet start, so the room's level is the floor
        let envelope = Envelope(levels: levels)
        let words = stride(from: 3.0, to: 30.0, by: 0.5).filter { $0 < 10 || $0 >= 25 }
        let transcript = Self.transcript(words.map { ($0, $0 + 0.3) })
        let gaps = TranscriptGaps.wordless(transcript, envelope: envelope, duration: 30)
        XCTAssertEqual(gaps.count, 2, "\(gaps)")
        XCTAssertEqual(gaps[0].start, 0, accuracy: 0.001)
        XCTAssertEqual(gaps[0].speech, 0, accuracy: 0.05, "the quiet start holds no speech")
        XCTAssertEqual(gaps[1].start, 9.8, accuracy: 0.001, "from the last word's end")
        XCTAssertEqual(gaps[1].end, 25, accuracy: 0.001)
        XCTAssertEqual(gaps[1].speech, 13.2, accuracy: 0.1)
        XCTAssertEqual(TranscriptGaps.toListenAgain(transcript, envelope: envelope, duration: 30).map(\.start), [9.8])
        XCTAssertEqual(TranscriptGaps.missing(transcript, envelope: envelope, duration: 30).map(\.start), [9.8])

        // With the words of 10 to 25 s back, nothing is missing.
        let whole = Self.transcript(stride(from: 3.0, to: 30.0, by: 0.5).map { ($0, $0 + 0.3) })
        XCTAssertTrue(TranscriptGaps.missing(whole, envelope: envelope, duration: 30).isEmpty)

        // Speech of 2 s inside a 5 s wordless stretch is listened to again but does not fail the check (a cough).
        var short = [Double](repeating: -70, count: 3_000)
        for i in 1_500..<1_700 { short[i] = -25 }
        for i in 0..<1_200 { short[i] = -25 }
        for i in 0..<300 { short[i] = -70 }
        let coughEnvelope = Envelope(levels: short)
        let coughWords = Self.transcript(stride(from: 3.0, to: 12.0, by: 0.5).map { ($0, $0 + 0.3) } + [(18.0, 18.3)])
        XCTAssertEqual(TranscriptGaps.toListenAgain(coughWords, envelope: coughEnvelope, duration: 30).count, 1)
        XCTAssertTrue(TranscriptGaps.missing(coughWords, envelope: coughEnvelope, duration: 30).isEmpty)
    }

    /// A word Parakeet stretches across a pause covers at most 1 s, so it cannot hide a gap behind it.
    func testAStretchedWordDoesNotHideAGap() {
        let levels = [Double](repeating: -70, count: 600) + [Double](repeating: -25, count: 2_400)
        let envelope = Envelope(levels: levels)
        let transcript = Self.transcript([(3, 3.3), (4, 20), (20.5, 20.8)])
        let gaps = TranscriptGaps.missing(transcript, envelope: envelope, duration: 21)
        XCTAssertEqual(gaps.map(\.start), [5])
        XCTAssertEqual(gaps.first?.end ?? 0, 20.5, accuracy: 0.001)
    }

    /// The words found when a stretch is heard again are only the ones that start inside it, moved onto the
    /// recording's clock; the 2 s of context on each side are already in the transcript.
    func testOnlyWordsInsideTheStretchAreTakenAndMergedInOrder() {
        let gap = TranscriptGaps.Gap(start: 100, end: 110, speech: 9)
        let piece = TranscriptGaps.piece(for: gap, duration: 1_000)
        XCTAssertEqual(piece, TimeRange(start: 98, end: 112))
        // Times inside the piece: a word at 1 s (99 s, context), words at 3 and 4 s (101, 102 s), one at 13 s (111 s).
        let heard = ParakeetTranscript(text: "", sentences: [
            Self.sentence([(" before", 1, 1.4), (" one", 3, 3.3), (" two", 4, 4.3), (".", 4.3, 4.4)]),
            Self.sentence([(" after", 13, 13.4)]),
        ])
        let found = TranscriptGaps.found(in: heard, offset: piece.start, gap: gap)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].text, " one two.")
        XCTAssertEqual(found[0].start, 101, accuracy: 0.0001)
        XCTAssertEqual(found[0].end, 102.4, accuracy: 0.0001)

        // The same word heard again a little later than the first run timed it is not taken twice.
        let edge = TranscriptGaps.found(in: ParakeetTranscript(text: "", sentences: [Self.sentence([(" w99.0", 1.3, 1.6), (" one", 3, 3.3)])]),
                                        offset: piece.start, gap: TranscriptGaps.Gap(start: 99.2, end: 110, speech: 9),
                                        existing: Self.transcript([(99, 99.4)]).sentences.flatMap(\.tokens))
        XCTAssertEqual(edge.map(\.text), [" one"])

        let first = Self.transcript([(95, 95.3), (99, 99.4), (111, 111.4)])
        let (merged, isNew) = TranscriptGaps.merged(first, adding: found)
        XCTAssertEqual(merged.sentences.map(\.start), [95, 99, 101, 111])
        XCTAssertEqual(isNew, [false, false, true, false])
        let starts = merged.sentences.flatMap(\.tokens).filter { EpisodeTranscript.isWord($0.text) }.map(\.start)
        XCTAssertEqual(starts, starts.sorted(), "every word once, in time order")
        XCTAssertEqual(Set(starts).count, starts.count, "no word written twice")

        // The first run's sentences keep their own order even where it is not by start time (6 Sep, 31:44.5 after 31:45.8).
        let unordered = ParakeetTranscript(text: "", sentences: [Self.sentence([(" a", 10, 10.3)]), Self.sentence([(" c", 30, 30.3)]),
                                                                   Self.sentence([(" b", 29, 29.3)]), Self.sentence([(" d", 40, 40.3)])])
        let (kept, keptNew) = TranscriptGaps.merged(unordered, adding: [Self.sentence([(" x", 20, 20.3)]), Self.sentence([(" y", 35, 35.3)])])
        XCTAssertEqual(kept.sentences.map(\.text), [" a", " x", " c", " b", " y", " d"])
        XCTAssertEqual(keptNew, [false, true, false, false, true, false])
    }

    /// The rewritten files keep the first run's cues exactly as Parakeet wrote them and add only the new ones.
    func testTheFilesKeepEveryOldCueAsWritten() throws {
        let first = Self.transcript([(1, 1.5), (20, 20.5)])
        try first.encoded().write(to: work.appending(path: "transcript.json"), atomically: true, encoding: .utf8)
        // Parakeet's own .srt, with a time it wrote from an unrounded number (1 ms off the JSON's).
        try "1\n00:00:01,001 --> 00:00:01,500\nw1.0\n\n2\n00:00:20,000 --> 00:00:20,500\nw20.0\n"
            .write(to: work.appending(path: "transcript.srt"), atomically: true, encoding: .utf8)
        try "WEBVTT\n\n00:00:01.001 --> 00:00:01.500\nw1.0\n\n00:00:20.000 --> 00:00:20.500\nw20.0\n"
            .write(to: work.appending(path: "transcript.vtt"), atomically: true, encoding: .utf8)
        let added = [Self.sentence([(" new", 10, 10.4), (" words", 10.4, 10.9)])]
        let (merged, isNew) = TranscriptGaps.merged(first, adding: added)
        try TranscriptGaps.write(merged, isNew: isNew, in: work)
        let srt = try String(contentsOf: work.appending(path: "transcript.srt"), encoding: .utf8)
        XCTAssertEqual(srt, "1\n00:00:01,001 --> 00:00:01,500\nw1.0\n\n2\n00:00:10,000 --> 00:00:10,900\nnew words\n\n3\n00:00:20,000 --> 00:00:20,500\nw20.0\n")
        let vtt = try String(contentsOf: work.appending(path: "transcript.vtt"), encoding: .utf8)
        XCTAssertEqual(vtt, "WEBVTT\n\n00:00:01.001 --> 00:00:01.500\nw1.0\n\n00:00:10.000 --> 00:00:10.900\nnew words\n\n00:00:20.000 --> 00:00:20.500\nw20.0\n")
        let txt = try String(contentsOf: work.appending(path: "transcript.txt"), encoding: .utf8)
        XCTAssertEqual(txt, "w1.0 new words w20.0")
        let json = try XCTUnwrap(ParakeetTranscript.read(work.appending(path: "transcript.json")))
        XCTAssertEqual(json.sentences.map(\.text), [" w1.0", " new words", " w20.0"])
    }

    /// transcript.json written again reads byte for byte as Parakeet's Python wrote it, so a rewrite changes nothing
    /// but the words it adds. On a sample in Parakeet's layout here; on the two talks' real files in `make accept`.
    func testTheJSONIsWrittenAsParakeetWritesIt() throws {
        let parakeet = """
        {
          "text": "Okay, \\"welcome\\". $32,000 \\\\ é",
          "sentences": [
            {
              "text": " Okay, \\"welcome\\". $32,000 \\\\ é",
              "start": 3.12,
              "end": 4.08,
              "duration": 0.96,
              "confidence": 1.0,
              "tokens": [
                {
                  "text": " Okay",
                  "start": 3.12,
                  "end": 3.44,
                  "duration": 0.32,
                  "confidence": 0.996
                },
                {
                  "text": ",",
                  "start": 0.0,
                  "end": 3520.08,
                  "duration": 0.08,
                  "confidence": 0.97
                }
              ]
            }
          ]
        }
        """
        let decoded = try JSONDecoder().decode(ParakeetTranscript.self, from: Data(parakeet.utf8))
        XCTAssertEqual(decoded.encoded(), parakeet)
        XCTAssertEqual(ParakeetTranscript(text: "", sentences: []).encoded(), "{\n  \"text\": \"\",\n  \"sentences\": []\n}")
        for name in ["2026-09-13 18-25-44", "2026-09-06 18-06-33"] {
            let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/Outputs/\(name)/transcript.json")
            guard let data = try? Data(contentsOf: url) else { continue }
            let real = try JSONDecoder().decode(ParakeetTranscript.self, from: data)
            XCTAssertEqual(Data(real.encoded().utf8), data, "\(name): transcript.json written again differs from Parakeet's")
        }
    }

    // MARK: Through the pipeline, with Parakeet

    /// About 75 s of spoken words over a quiet room. Parakeet's first run is made to lose every word from 30 to 42 s (a
    /// stand-in in front of the real Parakeet removes them from all four files, as the 6 Sep run lost 17 s). The make
    /// must hear that stretch again, put its words back once each, and pass the coverage check. With the second listen
    /// also made deaf, the coverage check must fail and name the stretch.
    func testAPlantedGapIsHeardAgainOrCaughtByTheCoverageCheck() async throws {
        let speech = try spokenFile()

        // Unplanted: nothing to hear again, and the check passes.
        let plain = await run(speech, parakeet: ToolPaths.standard.parakeet, folder: "plain")
        XCTAssertEqual(plain.result.outcome, .ready, plain.result.reason)
        XCTAssertEqual(plain.result.coverageOK, true, "the spoken file has no gap")
        XCTAssertTrue(plain.result.relistened.isEmpty, "\(plain.result.relistened)")
        let plainWords = try words(in: plain.folder)
        XCTAssertGreaterThan(plainWords.filter { $0.start >= 30 && $0.start < 42 }.count, 20, "the stretch is speech")

        // Planted, and heard again.
        let filled = await run(speech, parakeet: try stand(in: "filled", dropFrom: 30, to: 42, deafAgain: false), folder: "filled")
        XCTAssertEqual(filled.result.outcome, .ready, filled.result.reason)
        XCTAssertEqual(filled.result.relistened.count, 1, "\(filled.result.relistened)")
        let stretch = try XCTUnwrap(filled.result.relistened.first)
        XCTAssertLessThanOrEqual(stretch.start, 30.5)
        XCTAssertGreaterThanOrEqual(stretch.end, 41.5)
        XCTAssertGreaterThan(filled.result.wordsFoundAgain, 20)
        XCTAssertEqual(filled.result.coverageOK, true, filled.result.steps.compactMap(\.detail).joined(separator: " | "))
        XCTAssertTrue(filled.result.transcriptGaps.isEmpty)
        let filledWords = try words(in: filled.folder)
        let inside = filledWords.filter { $0.start >= 30 && $0.start < 42 }
        XCTAssertGreaterThan(inside.count, 20, "the stretch has words again")
        let starts = filledWords.map(\.start)
        XCTAssertEqual(starts, starts.sorted(), "in time order")
        // No word twice: the same letters starting within 0.5 s of each other would be one word heard twice.
        let keyed = TranscriptGaps.words(filledWordsTokens(filled.folder)).map { (TranscriptGaps.key($0), $0[0].start) }
        let twice = keyed.indices.filter { i in keyed.indices.contains { j in j > i && keyed[j].0 == keyed[i].0 && abs(keyed[j].1 - keyed[i].1) < 0.5 } }
        XCTAssertTrue(twice.isEmpty, "written twice: \(twice.map { keyed[$0] })")
        // Every word around the stretch is as the first run wrote it.
        let outside = { (w: [ParakeetTranscript.Token]) in w.filter { $0.start < stretch.start || $0.start >= stretch.end }.map { "\($0.text)@\($0.start)" } }
        let plantedFirst = try XCTUnwrap(ParakeetTranscript.read(work.appending(path: "filled-first.json")))
        XCTAssertEqual(outside(filledWords), outside(plantedFirst.sentences.flatMap(\.tokens).filter { EpisodeTranscript.isWord($0.text) }))
        let txt = try String(contentsOf: filled.folder.appending(path: "transcript.txt"), encoding: .utf8)
        XCTAssertEqual(Measure.wordCount(txt), filled.result.wordCount)
        XCTAssertTrue(filled.result.steps.first { $0.name == PipelineStep.transcript.title }?.detail?.contains("transcribed again") == true)

        print("TXGAP planted gap: plain run \(plainWords.count) words, \(plainWords.filter { $0.start >= 30 && $0.start < 42 }.count) in 30 to 42 s; "
              + "planted run heard again \(TranscriptGaps.list(filled.result.relistened)), \(filled.result.wordsFoundAgain) words found, "
              + "\(inside.count) words now in 30 to 42 s, coverage \(filled.result.coverageOK == true ? "passed" : "FAILED")")

        // Planted, and the second listen deaf too: the coverage check fails and says where.
        let caught = await run(speech, parakeet: try stand(in: "caught", dropFrom: 30, to: 42, deafAgain: true), folder: "caught")
        XCTAssertEqual(caught.result.outcome, .ready, caught.result.reason)
        XCTAssertEqual(caught.result.coverageOK, false, "a stretch of speech with no words fails the coverage check")
        XCTAssertEqual(caught.result.transcriptGaps.count, 1, "\(caught.result.transcriptGaps)")
        let gap = try XCTUnwrap(caught.result.transcriptGaps.first)
        XCTAssertLessThanOrEqual(gap.start, 30.5)
        XCTAssertGreaterThanOrEqual(gap.end, 41.5)
        XCTAssertLessThanOrEqual(caught.result.duration! - caught.result.transcriptReaches!, 120, "the tail is fine: the gap is in the middle")
        XCTAssertTrue(caught.result.reason.contains("The transcript has no words for 1 stretch of speech, at 0:"), caught.result.reason)
        let coverage = try XCTUnwrap(caught.result.steps.first { $0.name == PipelineStep.coverage.title }?.detail)
        XCTAssertTrue(coverage.contains("No words for 1 stretch of speech"), coverage)
        let report = try String(contentsOf: caught.folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(report.contains("NO WORDS for 1 stretch of speech"), report)
        print("TXGAP planted gap, second listen deaf: coverage \(caught.result.coverageOK == false ? "failed as it must" : "PASSED"), "
              + "stretches \(TranscriptGaps.list(caught.result.transcriptGaps)); reason: \(caught.result.reason)")
        for text in [caught.result.reason, coverage, report] {
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "no em or en dashes")
        }
    }

    // MARK: Helpers

    private static func token(_ text: String, _ start: Double, _ end: Double) -> ParakeetTranscript.Token {
        ParakeetTranscript.Token(text: text, start: start, end: end, duration: end - start, confidence: 0.9)
    }

    private static func sentence(_ tokens: [(String, Double, Double)]) -> ParakeetTranscript.Sentence {
        let t = tokens.map { token($0.0, $0.1, $0.2) }
        return ParakeetTranscript.Sentence(text: t.map(\.text).joined(), start: t[0].start, end: t[t.count - 1].end,
                                           duration: t[t.count - 1].end - t[0].start, confidence: 0.9, tokens: t)
    }

    /// One sentence per word, each word named by its time.
    private static func transcript(_ words: [(Double, Double)]) -> ParakeetTranscript {
        let sentences = words.map { sentence([(" w\($0.0)", $0.0, $0.1)]) }
        return ParakeetTranscript(text: sentences.map(\.text).joined().trimmingCharacters(in: .whitespaces), sentences: sentences)
    }

    private func filledWordsTokens(_ folder: URL) -> [ParakeetTranscript.Token] {
        ParakeetTranscript.read(folder.appending(path: "transcript.json"))?.sentences.flatMap(\.tokens) ?? []
    }

    private func words(in folder: URL) throws -> [ParakeetTranscript.Token] {
        let transcript = try XCTUnwrap(ParakeetTranscript.read(folder.appending(path: "transcript.json")))
        return transcript.sentences.flatMap(\.tokens).filter { EpisodeTranscript.isWord($0.text) }
    }

    /// About 75 s of `say` over a quiet room tone (so the envelope's floor is a room, not digital silence).
    private func spokenFile() throws -> URL {
        let said = work.appending(path: "said.aiff")
        let paragraph = Array(repeating: "Today we practice the standing sequence slowly, and we notice how the breath moves through the body. "
                              + "When the mind wanders, we come back to the count, and we let the shoulders soften before the next posture.",
                              count: 6).joined(separator: " ")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", said.path, paragraph]
        try say.run()
        say.waitUntilExit()
        XCTAssertEqual(say.terminationStatus, 0)
        let file = work.appending(path: "2026-10-14 spoken.m4a")
        let ffmpeg = Process()
        ffmpeg.executableURL = ToolPaths.standard.ffmpeg
        ffmpeg.arguments = ["-hide_banner", "-v", "error", "-y", "-i", said.path,
                            "-f", "lavfi", "-i", "anoisesrc=color=pink:amplitude=0.002:sample_rate=22050:duration=200",
                            "-filter_complex", "[0:a]apad=whole_dur=78[s];[s][1:a]amix=inputs=2:duration=first:normalize=0",
                            "-c:a", "aac", file.path]
        try ffmpeg.run()
        ffmpeg.waitUntilExit()
        XCTAssertEqual(ffmpeg.terminationStatus, 0)
        return file
    }

    /// A stand-in for Parakeet: runs the real one, then removes from its whole-file run (the one written as
    /// "transcript") every word starting in [from, to), from all four files, keeping a copy as `<name>-first.json`.
    /// With `deafAgain`, every stretch heard again comes back with no words.
    private func stand(in name: String, dropFrom from: Double, to: Double, deafAgain: Bool) throws -> URL {
        let real = ToolPaths.standard.parakeet
        let python = real.deletingLastPathComponent().appending(path: "python3")
        let script = work.appending(path: "parakeet-\(name)")
        let keep = work.appending(path: "\(name)-first.json")
        let source = """
        #!\(python.path)
        import glob, json, os, subprocess, sys
        args = sys.argv[1:]
        subprocess.run([\(Self.py(real.path))] + args, check=True)
        out = args[args.index("--output-dir") + 1]
        template = args[args.index("--output-template") + 1]
        def stamp(t, mark):
            ms = round(t * 1000)
            return "%02d:%02d:%02d%s%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, mark, ms % 1000)
        def strip(d, gone):
            sentences = []
            for s in d["sentences"]:
                tokens = [t for t in s["tokens"] if not gone(t)]
                while tokens and not any(c.isalnum() for c in tokens[0]["text"]):
                    tokens.pop(0)
                if not tokens:
                    continue
                s["tokens"] = tokens
                s["text"] = "".join(t["text"] for t in tokens)
                s["start"], s["end"] = tokens[0]["start"], tokens[-1]["end"]
                s["duration"] = round(s["end"] - s["start"], 3)
                sentences.append(s)
            d["sentences"] = sentences
            d["text"] = "".join(s["text"] for s in sentences).strip()
            return d
        if template == "transcript":
            path = os.path.join(out, "transcript.json")
            d = strip(json.load(open(path)), lambda t: \(from) <= t["start"] < \(to))
            text = json.dumps(d, indent=2, ensure_ascii=False)
            open(path, "w").write(text)
            open(\(Self.py(keep.path)), "w").write(text)
            open(os.path.join(out, "transcript.txt"), "w").write(d["text"])
            srt, vtt = [], ["WEBVTT", ""]
            for i, s in enumerate(d["sentences"]):
                srt += [str(i + 1), stamp(s["start"], ",") + " --> " + stamp(s["end"], ","), s["text"].strip(), ""]
                vtt += [stamp(s["start"], ".") + " --> " + stamp(s["end"], "."), s["text"].strip(), ""]
            open(os.path.join(out, "transcript.srt"), "w").write("\\n".join(srt))
            open(os.path.join(out, "transcript.vtt"), "w").write("\\n".join(vtt))
        elif \(deafAgain ? "True" : "False"):
            for path in glob.glob(os.path.join(out, "*.json")):
                d = strip(json.load(open(path)), lambda t: True)
                open(path, "w").write(json.dumps(d, indent=2, ensure_ascii=False))
        """
        try source.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    private static func py(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private func run(_ file: URL, parakeet: URL, folder name: String) async -> (result: PipelineResult, folder: URL) {
        var options = PipelineOptions()
        options.stableWait = .milliseconds(200)
        options.makeEpisode = false
        var tools = ToolPaths.standard
        tools.parakeet = parakeet
        let folder = work.appending(path: "out-\(name)", directoryHint: .isDirectory)
        let result = await Pipeline(tools: tools, options: options, log: nil).run(file: file, outputFolder: folder, label: "Test") { _ in }
        return (result, folder)
    }
}
