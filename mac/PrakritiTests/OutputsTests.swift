import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Milestone 4: each output's settings change what is made, measured on files ffmpeg (and the Mac's
/// own voice, `say`) generate in a temporary folder. Nothing here reads a real recording or writes
/// into ~/Prakriti; the 13 Sep talk is OutputsAcceptanceTests (make accept-outputs).
@MainActor
final class OutputsTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-outputs-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: The word list, on text

    /// A planted mis-hearing of each kind the build named ("yoga market", "Yoga Margot", "Yokamarga")
    /// and the rest of the list, in an .srt: every one fixed, nothing else touched, no timing moved.
    func testTheWordListFixesPlantedMishearingsAndNoTiming() {
        let srt = """
        1
        00:00:01,600 --> 00:00:04,880
        Welcome to the yoga market school.

        2
        00:00:04,880 --> 00:00:09,200
        Today Yoga Margot teaches Pradayama,
        and Yokamarga is a community.

        3
        00:05:20,000 --> 00:05:24,000
        We do things different with Yoga Marka and the Yoga Mārga School channel.

        4
        00:07:01,000 --> 00:07:03,500
        Sri Krishna Macharya taught Patabi Joyce and BKS Ayengar samkhya.

        5
        00:09:00,000 --> 00:09:02,000
        The yoga markets are busy; yoga marketing is not us.

        """
        let fixed = Lexicon.applyToSubtitles(srt)
        XCTAssertTrue(fixed.text.contains("Welcome to the Yoga Marga school."), fixed.text)
        XCTAssertTrue(fixed.text.contains("Today Yoga Marga teaches Pranayama,\nand Yoga Marga is a community."), fixed.text)
        XCTAssertTrue(fixed.text.contains("with Yoga Marga and the Yoga Mārga School channel."), "the channel's own spelling is kept")
        XCTAssertTrue(fixed.text.contains("Sri Krishnamacharya taught Pattabhi Jois and BKS Iyengar Samkhya."), fixed.text)
        XCTAssertTrue(fixed.text.contains("The yoga markets are busy; yoga marketing is not us."), "only whole words are fixed")

        // The numbers, the timing lines and the blank lines are byte for byte the same.
        func skeleton(_ text: String) -> [String] { text.components(separatedBy: "\n").filter { $0.contains("-->") || Int($0) != nil || $0.isEmpty } }
        XCTAssertEqual(skeleton(fixed.text), skeleton(srt))
        XCTAssertEqual(TranscriptFiles.cues(srt: fixed.text).map(\.start), TranscriptFiles.cues(srt: srt).map(\.start))

        // Each fix is counted, with what was heard and when.
        XCTAssertEqual(fixed.corrections.count, 9)
        XCTAssertEqual(fixed.corrections.first, Lexicon.Correction(heard: "yoga market", written: "Yoga Marga", at: 1.6))
        XCTAssertTrue(fixed.corrections.contains(Lexicon.Correction(heard: "Yoga Marka", written: "Yoga Marga", at: 320)))
        XCTAssertTrue(fixed.corrections.contains(Lexicon.Correction(heard: "Pradayama", written: "Pranayama", at: 4.88)), "a lowercase term keeps a sentence's capital")
        let groups = Lexicon.summary(fixed.corrections)
        XCTAssertEqual(groups.first?.written, "Yoga Marga")
        XCTAssertEqual(groups.first?.items.count, 4)

        // Running it twice changes nothing more.
        XCTAssertTrue(Lexicon.applyToSubtitles(fixed.text).corrections.isEmpty)
        // Plain text too.
        XCTAssertEqual(Lexicon.apply("yoga marga is at the yoga-market").text, "Yoga Marga is at the Yoga Marga")
        // No em dashes in the list itself (it is UI text).
        for entry in Lexicon.entries { XCTAssertFalse(entry.note.contains("\u{2014}")) }
    }

    func testTheMarkdownTranscriptReadsInParagraphs() {
        let cues = [TranscriptFiles.Cue(start: 1.6, end: 2.88, text: "Okay."),
                    TranscriptFiles.Cue(start: 2.88, end: 5.2, text: "So welcome everyone."),
                    TranscriptFiles.Cue(start: 9.0, end: 12.0, text: "After a pause."),
                    TranscriptFiles.Cue(start: 70.0, end: 74.0, text: "A minute later, still talking.")]
        let md = TranscriptFiles.markdown(cues: cues, label: "Sun 13 Sep", fileName: "2026-09-13 18-25-44.mp4", wordListApplied: true)
        XCTAssertTrue(md.hasPrefix("# Sun 13 Sep: transcript\n"))
        XCTAssertTrue(md.contains("with the Yoga Marga word list applied."))
        XCTAssertTrue(md.contains("\n**0:02** Okay. So welcome everyone.\n"), md)
        XCTAssertTrue(md.contains("\n**0:09** After a pause.\n"), md)
        XCTAssertTrue(md.contains("\n**1:10** A minute later, still talking.\n"), md)
        XCTAssertFalse(md.contains("\u{2014}"))
    }

    // MARK: The silence trim and the mastering chain

    func testTheSilenceTrimReadsSilencedetect() {
        // The 13 Sep talk, measured 10 Oct at -50 dB: 1.68 s of silence at the start, sound to the end.
        let talk = """
        [Parsed_silencedetect_1 @ 0x79bf020c00] silence_start: 0
        [Parsed_silencedetect_1 @ 0x79bf020c00] silence_end: 1.681542 | silence_duration: 1.681542
        [Parsed_silencedetect_1 @ 0x7ad5018c00] silence_start: 941.169646
        [Parsed_silencedetect_1 @ 0x7ad5018c00] silence_end: 942.121354 | silence_duration: 0.951708
        """
        let silences = Measure.silences(stderr: talk)
        XCTAssertEqual(silences, [Measure.Silence(start: 0, end: 1.681542), Measure.Silence(start: 941.169646, end: 942.121354)])
        let kept = SilenceTrim.kept(silences, duration: 947.78)
        XCTAssertEqual(kept?.start ?? 0, 1.181542, accuracy: 0.0001, "half a second is kept before the first sound")
        XCTAssertEqual(kept?.end, 947.78, "a pause in the middle is never trimmed")

        // Silence running to the end, with and without ffmpeg printing its end.
        let tail = Measure.silences(stderr: "silence_start: 0\nsilence_end: 4.0 | silence_duration: 4\nsilence_start: 74\n")
        XCTAssertEqual(tail.last, Measure.Silence(start: 74, end: nil))
        XCTAssertEqual(SilenceTrim.kept(tail, duration: 79), Mastering.Span(start: 3.5, end: 74.5))
        XCTAssertNil(SilenceTrim.kept([], duration: 79), "nothing to trim")
        XCTAssertEqual(SilenceTrim.line(start: 1.18, end: 0), "Trimmed 1.2 s at the start; none at the end.")
        XCTAssertEqual(SilenceTrim.line(start: 0, end: 0), "No silence to trim at either end.")
    }

    func testTheChainIsV0sUntilASettingChangesIt() {
        let measured = Measure.LoudnormPass(inputI: "-26.67", inputTP: "-0.38", inputLRA: "6.10", inputThresh: "-37.10",
                                            targetOffset: "0.52", normalizationType: "dynamic")
        let loud = Mastering.firstPassLoudness(target: -16, ceiling: -1)
        // Plain: engine v0's arguments exactly.
        XCTAssertEqual(Mastering.pass(file: "/a.mp4", program: Mastering.Program(), loudness: loud),
                       ["-i", "/a.mp4", "-vn", "-af", Mastering.firstPass(target: -16, ceiling: -1)])
        // Trimmed and stereo: the trim first, then the layout and rate, then loudness.
        let trimmed = Mastering.pass(file: "/a.mp4", program: Mastering.Program(kept: .init(start: 1.18, end: 900), channels: .stereo), loudness: loud)
        XCTAssertEqual(trimmed.last, "atrim=start=1.180:end=900.000,asetpts=PTS-STARTPTS,aformat=channel_layouts=stereo,aresample=48000," + loud)
        // With an intro and an outro: one graph, every piece in the same layout before the join, and
        // the limiter after it (v0's bug 2: nothing resamples after the limiter).
        let second = Mastering.secondPassLoudness(target: -16, ceiling: -1, measured: measured)
        let program = Mastering.Program(kept: nil, channels: .mono, intro: .init(path: "/i.wav", gainDB: -3.5), outro: .init(path: "/o.mp3", gainDB: 2))
        let args = Mastering.pass(file: "/a.mp4", program: program, loudness: second)
        XCTAssertEqual(Array(args.prefix(6)), ["-i", "/i.wav", "-i", "/a.mp4", "-i", "/o.mp3"])
        XCTAssertEqual(args.suffix(2), ["-map", "[episode]"])
        let graph = args[7]
        XCTAssertEqual(graph, "[0:a]aformat=channel_layouts=mono,aresample=48000,volume=-3.5dB[intro];"
                       + "[1:a]aformat=channel_layouts=mono,aresample=48000[talk];"
                       + "[2:a]aformat=channel_layouts=mono,aresample=48000,volume=2dB[outro];"
                       + "[intro][talk][outro]concat=n=3:v=0:a=1," + second + "[episode]")
        XCTAssertTrue(graph.contains("level=disabled"), "v0's bug 1: the limiter never re-normalizes")
        XCTAssertEqual(Pipeline.matchingGain(talk: -26, piece: -14), -12)
        XCTAssertEqual(Pipeline.matchingGain(talk: -26, piece: -70), 30, "never more than 30 dB")
    }

    // MARK: The pipeline on generated audio

    private func run(_ file: URL, into folder: URL? = nil, _ change: (inout PipelineOptions) -> Void) async -> (PipelineResult, URL) {
        var options = PipelineOptions()
        options.stableWait = .milliseconds(200)
        change(&options)
        let out = folder ?? work.appending(path: "out-" + file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        let result = await Pipeline(options: options, log: nil).run(file: file, outputFolder: out, label: "Test") { _ in }
        return (result, out)
    }

    /// 4 s of silence, 70 s of tone, 5 s of silence; an intro of 3 s and an outro of 2 s; stereo at
    /// -19 LUFS. The episode must be intro + the kept part + outro long, in two channels, near -19.
    func testTrimIntroOutroAndStereoChangeTheEpisode() async throws {
        let body = try make("2026-09-13 body.m4a", ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo:d=4", "-f", "lavfi", "-i", "sine=frequency=220:duration=70",
                                                    "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo:d=5", "-filter_complex",
                                                    "[1:a]volume=-12dB,aformat=channel_layouts=stereo,aresample=48000[t];[0:a][t][2:a]concat=n=3:v=0:a=1", "-c:a", "aac"])
        let intro = try make("intro.wav", ["-f", "lavfi", "-i", "sine=frequency=660:duration=3:sample_rate=44100"])
        let outro = try make("outro.mp3", ["-f", "lavfi", "-i", "sine=frequency=880:duration=2", "-af", "volume=-24dB", "-c:a", "libmp3lame"])
        let (result, folder) = await run(body) { o in
            o.makeTranscript = false
            o.trimSilence = true
            o.introPath = intro.path
            o.outroPath = outro.path
            o.channels = .stereo
            o.loudnessTarget = -19
        }
        XCTAssertEqual(result.outcome, .ready, result.reason)
        XCTAssertEqual(result.trimmedStart ?? 0, 3.5, accuracy: 0.1)
        XCTAssertEqual(result.trimmedEnd ?? 0, 4.5, accuracy: 0.1)
        XCTAssertEqual(result.introDuration ?? 0, 3, accuracy: 0.05)
        XCTAssertEqual(result.outroDuration ?? 0, 2, accuracy: 0.05)
        XCTAssertEqual(result.episodeDuration ?? 0, 3 + 71 + 2, accuracy: 0.5, "intro, the kept 71 s, outro")
        let output = try XCTUnwrap(result.output)
        XCTAssertEqual(output.integratedLUFS, -19, accuracy: 1.0)
        XCTAssertLessThanOrEqual(output.truePeakDBFS, -1.0)
        XCTAssertEqual(try channels(folder.appending(path: "episode.mp3")), 2)
        XCTAssertEqual(result.files, ["REPORT.md", "episode.mp3"], "the transcript was off, so none was made")
        XCTAssertEqual(result.steps.map(\.name), PipelineOptions.titles([.complete, .capture, .sound, .trim, .episode, .loudness, .report]))
        let report = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(report.contains("stereo 128 kbps"), report)
        XCTAssertTrue(report.contains("(target -19 LUFS"), report)
        XCTAssertTrue(report.contains("3.5 s of silence trimmed at the start and 4.5 s at the end"), report)
        XCTAssertTrue(report.contains("intro `intro.wav` (3.0 s) before it, outro `outro.mp3` (2.0 s) after it"), report)

        // The intro (a loud tone) and the outro (24 dB quieter) were brought to the talk's level:
        // the loudest second of each is within a few dB of the talk's.
        let levels = try momentaryLevels(folder.appending(path: "episode.mp3"), at: [1.5, 40, 75])
        XCTAssertEqual(levels[0], levels[1], accuracy: 3, "the intro plays at the talk's loudness")
        XCTAssertEqual(levels[2], levels[1], accuracy: 3, "the outro plays at the talk's loudness")

        // Mono is v0's.
        let (mono, monoFolder) = await run(body, into: work.appending(path: "mono", directoryHint: .isDirectory)) { o in
            o.makeTranscript = false
            o.makeReport = false
        }
        XCTAssertEqual(mono.outcome, .ready, mono.reason)
        XCTAssertEqual(try channels(monoFolder.appending(path: "episode.mp3")), 1)
        XCTAssertEqual(mono.episodeDuration ?? 0, 79, accuracy: 0.5, "no trim: the whole recording")
        XCTAssertEqual(mono.files, ["episode.mp3"], "the report was off")
    }

    /// The transcript turned off and the recording made again: no transcript file is left, the
    /// earlier make's other files are replaced, and a file Ivan keeps in the folder stays.
    func testMakingAgainWithTheTranscriptOffLeavesNoTranscript() async throws {
        let tone = try make("2026-09-13 tone.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=70", "-af", "volume=-12dB", "-c:a", "aac"])
        let folder = work.appending(path: "2026-09-13 tone", directoryHint: .isDirectory)
        let (first, _) = await run(tone, into: folder) { o in
            o.transcriptFormats = Set(TranscriptFormat.allCases)
            o.applyLexicon = true
        }
        XCTAssertEqual(first.outcome, .ready, first.reason)
        XCTAssertEqual(first.files, ["REPORT.md", "episode.mp3", "transcript.json", "transcript.md", "transcript.srt", "transcript.txt", "transcript.vtt"])
        try "my own notes".write(to: folder.appending(path: "notes from Ivan.txt"), atomically: true, encoding: .utf8)
        let firstEpisode = try Data(contentsOf: folder.appending(path: "episode.mp3"))

        let (again, _) = await run(tone, into: folder) { o in
            o.makeTranscript = false
            o.loudnessTarget = -19
        }
        XCTAssertEqual(again.outcome, .ready, again.reason)
        XCTAssertEqual(again.files, ["REPORT.md", "episode.mp3"])
        XCTAssertEqual(Set(again.replaced), Set(first.files), "every earlier file was replaced or removed")
        let left = Pipeline.madeFiles(in: folder)
        XCTAssertEqual(left, ["REPORT.md", "episode.mp3", "notes from Ivan.txt"], "no transcript file is left, and Ivan's own file stays")
        XCTAssertFalse(left.contains { $0.hasPrefix("transcript.") })
        XCTAssertNotEqual(try Data(contentsOf: folder.appending(path: "episode.mp3")), firstEpisode, "the episode was made again")
        XCTAssertFalse(FileManager.default.fileExists(atPath: Pipeline.stagingFolder(for: folder).path), "the staging folder is gone")
        XCTAssertEqual(again.output?.integratedLUFS ?? 0, -19, accuracy: 1.0)
        XCTAssertFalse(again.steps.contains { $0.name == PipelineStep.transcript.title }, "Parakeet did not run")
    }

    /// A make again that stops (here: the intro chosen has gone) leaves the last good files alone.
    func testAMakeAgainThatStopsLeavesTheLastFilesAlone() async throws {
        let tone = try make("2026-09-13 tone.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=70", "-af", "volume=-12dB", "-c:a", "aac"])
        let folder = work.appending(path: "2026-09-13 tone", directoryHint: .isDirectory)
        let (first, _) = await run(tone, into: folder) { o in o.makeTranscript = false }
        XCTAssertEqual(first.outcome, .ready, first.reason)
        let before = try Data(contentsOf: folder.appending(path: "episode.mp3"))

        let (stopped, _) = await run(tone, into: folder) { o in
            o.makeTranscript = false
            o.introPath = self.work.appending(path: "gone.wav").path
        }
        XCTAssertEqual(stopped.outcome, .failed)
        XCTAssertEqual(stopped.reason, "The intro chosen in Settings, Outputs (gone.wav) is not there any more, so no episode audio was made. Choose it again, or remove it.")
        XCTAssertNil(stopped.outputFolder)
        XCTAssertEqual(try Data(contentsOf: folder.appending(path: "episode.mp3")), before, "the last good episode is untouched")
        XCTAssertEqual(Pipeline.madeFiles(in: folder), ["REPORT.md", "episode.mp3"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: Pipeline.stagingFolder(for: folder).path))
    }

    /// The word list through the real tools: the Mac's own voice says the mis-hearings, Parakeet writes
    /// them down as heard, and the word list fixes them in the chosen formats only. transcript.json
    /// keeps what was heard.
    func testTheWordListFixesWhatParakeetMishears() async throws {
        let said = work.appending(path: "said.aiff")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", said.path, "Welcome back to the yoga market school. Today we breathe with pradayama, the practice Yoga Margot teaches."]
        try say.run()
        say.waitUntilExit()
        XCTAssertEqual(say.terminationStatus, 0)
        // Long enough not to be a test (60 s), with sound well above the silence line.
        let speech = try make("2026-10-10 spoken.m4a", ["-i", said.path, "-af", "apad=whole_dur=65", "-c:a", "aac"])
        let (result, folder) = await run(speech) { o in
            o.makeEpisode = false
            o.transcriptFormats = [.txt, .md]
            o.applyLexicon = true
        }
        XCTAssertEqual(result.outcome, .ready, result.reason)
        XCTAssertEqual(result.files, ["REPORT.md", "transcript.json", "transcript.md", "transcript.txt"], "only the chosen formats, and the words as heard")
        let txt = try String(contentsOf: folder.appending(path: "transcript.txt"), encoding: .utf8)
        let md = try String(contentsOf: folder.appending(path: "transcript.md"), encoding: .utf8)
        let heard = try String(contentsOf: folder.appending(path: "transcript.json"), encoding: .utf8)
        print("Parakeet heard: \(heard.prefix(300))\nThe word list wrote: \(txt)")
        XCTAssertTrue(txt.contains("Yoga Marga"), txt)
        XCTAssertTrue(md.contains("Yoga Marga"), md)
        for wrong in ["yoga market", "Yoga Margot", "pradayama"] {
            XCTAssertFalse(txt.lowercased().contains(wrong.lowercased()), "\(wrong) is still in the transcript: \(txt)")
        }
        XCTAssertTrue(heard.lowercased().contains("yoga market"), "transcript.json keeps what was heard")
        XCTAssertGreaterThanOrEqual(result.corrections.count, 2, "\(result.corrections)")
        let report = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(report.contains("## Word list fixes"), report)
        XCTAssertTrue(report.contains("| Yoga Marga | "), report)
        XCTAssertTrue(result.steps.contains { $0.name == "Word list" && $0.state == .done })
    }

    // MARK: Through the app: a recording's own switch decides

    func testARecordingWithTheTranscriptTurnedOffIsMadeWithoutOne() async throws {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .milliseconds(200)
        let tone = try make("2026-09-13 app.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=70", "-af", "volume=-12dB", "-c:a", "aac"])
        let recording = Recording(filePath: tone.path, recordedAt: AppModel.dateInName(tone.lastPathComponent), foundAt: Date())
        model.context.insert(recording)

        // The Outputs screen's loudness reaches a recording with no settings of its own.
        model.defaultSettings().first { $0.kind == .podcastEpisode }?.loudnessTarget = -19
        model.setOutput(.transcript, on: false, for: recording)
        let options = model.runner.options(for: recording)
        XCTAssertFalse(options.makeTranscript)
        XCTAssertEqual(options.loudnessTarget, -19)
        XCTAssertTrue(options.trimSilence, "on by default on the Outputs screen")
        XCTAssertTrue(options.applyLexicon)
        XCTAssertEqual(options.transcriptFormats, Set(TranscriptFormat.allCases))

        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        XCTAssertNil(recording.wordCount)
        XCTAssertNil(recording.wordListFixes)
        XCTAssertEqual(recording.madeFiles, ["REPORT.md", "episode.mp3"])
        XCTAssertEqual(recording.loudnessLUFS ?? 0, -19, accuracy: 1.0)
        XCTAssertEqual(recording.silenceTrimmedStart, 0, "a tone from its first sample has nothing to trim")
        let folder = try XCTUnwrap(recording.outputFolder)
        XCTAssertFalse(Pipeline.madeFiles(in: URL(fileURLWithPath: folder)).contains { $0.hasPrefix("transcript.") })
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

    private func channels(_ file: URL) throws -> Int {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffprobe
        process.arguments = ["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels", "-of", "csv=p=0", file.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Int(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// The momentary loudness (ebur128 M, 400 ms) at each time, in LUFS.
    private func momentaryLevels(_ file: URL, at times: [Double]) throws -> [Double] {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-nostats", "-i", file.path, "-af", "ebur128", "-f", "null", "-"]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        var frames: [(t: Double, m: Double)] = []
        for match in String(decoding: data, as: UTF8.self).matches(of: /t: *([0-9.]+) +TARGET:[^M]*M: *(-?[0-9.]+)/) {
            if let t = Double(match.output.1), let m = Double(match.output.2) { frames.append((t, m)) }
        }
        if frames.isEmpty {
            for match in String(decoding: data, as: UTF8.self).matches(of: /t: *([0-9.]+) +M: *(-?[0-9.]+)/) {
                if let t = Double(match.output.1), let m = Double(match.output.2) { frames.append((t, m)) }
            }
        }
        return times.map { time in frames.min { abs($0.t - time) < abs($1.t - time) }?.m ?? -99 }
    }
}

extension PipelineOptions {
    /// The page's names for a list of steps, for comparing a run's steps in tests.
    static func titles(_ steps: [PipelineStep]) -> [String] { steps.map(\.title) }
}
