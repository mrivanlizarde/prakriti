import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Prakriti

/// The podcast-ready episode (10 Oct), on files made here: tones and the Mac's own voice (`say`) by
/// ffmpeg, test images drawn by Core Graphics. Nothing here reads a real recording or writes into
/// ~/Prakriti; the 6 Sep and 13 Sep talks are PodcastReadyAcceptanceTests (make accept-podcast).
/// The test images are made in a temporary folder and deleted; none ships.
@MainActor
final class PodcastReadyTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-podcast-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: The chain

    /// The chain chosen from the 10 Oct measurements, string for string, with engine v0's two rules:
    /// every limiter keeps level=disabled, and the layout and rate come before every limiter.
    func testTheChainIsTheMeasuredOne() {
        XCTAssertEqual(PodcastMastering.talkChain(pregain: 6.67, channels: .mono, noiseReduction: false),
                       "highpass=f=70:poles=2,volume=6.67dB,acompressor=threshold=-22dB:ratio=1.5:attack=20:release=500:knee=2.82843:detection=rms:makeup=1,"
                       + "aformat=channel_layouts=mono,aresample=44100")
        XCTAssertTrue(PodcastMastering.talkChain(pregain: 0, channels: .stereo, noiseReduction: true)
            .hasPrefix("highpass=f=70:poles=2,afftdn=nr=6:tn=1,volume=0dB,"))
        XCTAssertEqual(PodcastMastering.gainStage(9.5), "volume=9.5dB,alimiter=limit=0.7079:level=disabled:attack=5:release=50")
        let m = Measure.LoudnormPass(inputI: "-15.68", inputTP: "-1.62", inputLRA: "3.70", inputThresh: "-26.10", targetOffset: "0.05", normalizationType: "dynamic")
        let finish = PodcastMastering.finish(measured: m, allowance: 0.4, channels: .mono)
        XCTAssertEqual(finish, "loudnorm=I=-15.6:TP=-1:LRA=11:measured_I=-15.68:measured_TP=-1.62:measured_LRA=3.70:measured_thresh=-26.10:offset=0.05:linear=true:print_format=json,"
                       + "aformat=sample_rates=44100:channel_layouts=mono,alimiter=limit=0.7328:level=disabled:attack=5:release=50")
        // The layout and rate come before the last limiter (v0's bug 2).
        let rate = finish.range(of: "aformat=sample_rates=44100")!, limiter = finish.range(of: "alimiter")!
        XCTAssertLessThan(rate.lowerBound, limiter.lowerBound)
        XCTAssertEqual(PodcastMastering.pregain(talk: -26.67), 6.67, accuracy: 0.001)
        XCTAssertEqual(PodcastMastering.pregain(talk: -70), 30, "never more than 30 dB")
        XCTAssertEqual(PodcastReadySettings(channels: .stereo, bitrateKbps: 96).bitrate, 128, "stereo never under 128 kbps")
        XCTAssertEqual(PodcastReadySettings().bitrate, 96, "mono 96 kbps by default")
    }

    // MARK: The tag

    /// A chapters test file with three chapters: the CTOC and three CHAP frames are written, and
    /// read back two ways (Prakriti's own reader and ffprobe), with the title, author, show, year,
    /// the COMM comment, genre Podcast and the artwork. The audio is not touched: it decodes to the
    /// same number of samples before and after (the encoder delay header survives).
    func testATagWithThreeChaptersIsReadBack() async throws {
        let plain = try ffmpeg("plain.mp3", ["-f", "lavfi", "-i", "sine=frequency=300:duration=200", "-ac", "1", "-ar", "44100",
                                             "-c:a", "libmp3lame", "-b:a", "96k", "-id3v2_version", "0"])
        let art = try image("art.jpg", width: 1400, height: 1400)
        let chapters = PodcastPackage.chapters([WrittenChapter(start: 0.08, title: "Breath Before Posture"),
                                                WrittenChapter(start: 60, title: "The Second Part"),
                                                WrittenChapter(start: 130, title: "Closing")], duration: 200)
        XCTAssertNil(chapters.problem)
        var contents = ID3.Contents(title: "The Breath Before Posture")
        contents.artist = "Test Host"
        contents.album = "Test Show"
        contents.year = "2026"
        contents.comment = "A short summary of the talk."
        contents.track = 3
        contents.artwork = (try Data(contentsOf: art), "image/jpeg")
        contents.chapters = chapters.chapters
        let tagged = work.appending(path: "tagged.mp3")
        try ID3.write(contents, audioFrom: plain, to: tagged)

        let tag = try XCTUnwrap(ID3.read(tagged))
        XCTAssertEqual(tag.version, 4)
        XCTAssertEqual(tag.text["TIT2"], "The Breath Before Posture")
        XCTAssertEqual(tag.text["TPE1"], "Test Host")
        XCTAssertEqual(tag.text["TALB"], "Test Show")
        XCTAssertEqual(tag.text["TDRC"], "2026")
        XCTAssertEqual(tag.text["TCON"], "Podcast")
        XCTAssertEqual(tag.text["TRCK"], "3")
        XCTAssertEqual(tag.comment, "A short summary of the talk.", "a real COMM frame, not ffmpeg's TXXX")
        XCTAssertEqual(tag.picture?.mime, "image/jpeg")
        XCTAssertEqual(tag.picture?.type, 3, "front cover")
        XCTAssertEqual(tag.picture?.bytes, try Data(contentsOf: art).count)
        XCTAssertEqual(tag.chapters.map(\.startMS), [0, 60_000, 130_000], "the first chapter starts at 0")
        XCTAssertEqual(tag.chapters.map(\.endMS), [60_000, 130_000, 200_000])
        XCTAssertEqual(tag.chapters.map(\.title), ["Breath Before Posture", "The Second Part", "Closing"])
        XCTAssertEqual(tag.toc, ID3.TableOfContents(id: "toc", topLevel: true, ordered: true, children: ["ch0", "ch1", "ch2"]))
        XCTAssertNil(PodcastPackage.chapterProblem(tag, duration: 200))

        // ffprobe reads the same chapters, titles included.
        let probe = try run(ToolPaths.standard.ffprobe, ["-v", "error", "-show_chapters", "-show_entries", "format_tags", "-of", "json", tagged.path])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(probe.utf8)) as? [String: Any])
        let read = try XCTUnwrap(json["chapters"] as? [[String: Any]])
        XCTAssertEqual(read.count, 3)
        XCTAssertEqual(read.compactMap { ($0["tags"] as? [String: Any])?["title"] as? String }, ["Breath Before Posture", "The Second Part", "Closing"])
        XCTAssertEqual(read.compactMap { $0["start_time"] as? String }, ["0.000000", "60.000000", "130.000000"])
        let tags = try XCTUnwrap((json["format"] as? [String: Any])?["tags"] as? [String: Any])
        XCTAssertEqual(tags["album"] as? String, "Test Show")
        XCTAssertEqual(tags["genre"] as? String, "Podcast")

        // The audio is the same audio.
        XCTAssertEqual(ID3.audio(of: try Data(contentsOf: tagged)), try Data(contentsOf: plain))
        XCTAssertEqual(try decodedBytes(tagged), try decodedBytes(plain), "the same samples: gapless timing kept")

        // Broken chapters are caught when read back.
        var bad = tag
        bad.chapters[1].startMS = 0
        XCTAssertNotNil(PodcastPackage.chapterProblem(bad, duration: 200))
        bad = tag
        bad.chapters.removeLast()
        XCTAssertNotNil(PodcastPackage.chapterProblem(bad, duration: 200), "under 3")
    }

    func testChaptersFromTheWriter() {
        let two = PodcastPackage.chapters([WrittenChapter(start: 0, title: "A"), WrittenChapter(start: 200, title: "B")], duration: 400)
        XCTAssertTrue(two.chapters.isEmpty)
        XCTAssertTrue(two.problem?.contains("at least 3") == true, two.problem ?? "")
        let none = PodcastPackage.chapters([], duration: 400)
        XCTAssertTrue(none.chapters.isEmpty && none.problem == nil, "no chapters is not a problem, only missing")
        let late = PodcastPackage.chapters([WrittenChapter(start: 0, title: "A"), WrittenChapter(start: 200, title: "B"), WrittenChapter(start: 500, title: "C")], duration: 400)
        XCTAssertTrue(late.chapters.isEmpty)
        XCTAssertTrue(late.problem?.contains("after the end") == true)
        // An intro moves every time but the first, which covers it from 0:00.
        let withIntro = PodcastPackage.chapters([WrittenChapter(start: 5.08, title: "A"), WrittenChapter(start: 245, title: "B"), WrittenChapter(start: 400, title: "C")], duration: 600)
        XCTAssertEqual(withIntro.chapters.map(\.startMS), [0, 245_000, 400_000])
        XCTAssertEqual(withIntro.chapters.last?.endMS, 600_000)
    }

    // MARK: Artwork

    /// Test images made here, never shipped: one that passes, and one that breaks each rule.
    func testArtworkIsCheckedAgainstApplesRules() throws {
        let good = ArtworkCheck.check(try image("good.jpg", width: 1400, height: 1400))
        XCTAssertTrue(good.passes, good.problems.joined(separator: " "))
        XCTAssertEqual(good.format, "JPEG")
        XCTAssertEqual(good.colorModel, "RGB")
        XCTAssertTrue(good.line.hasPrefix("1400 by 1400 px JPEG, RGB, "), good.line)

        let png = ArtworkCheck.check(try image("good.png", width: 3000, height: 3000, type: .png, alpha: false))
        XCTAssertTrue(png.passes, png.problems.joined(separator: " "))
        XCTAssertEqual(png.mime, "image/png")

        let small = ArtworkCheck.check(try image("small.jpg", width: 1000, height: 1000))
        XCTAssertEqual(small.problems.count, 1)
        XCTAssertTrue(small.problems[0].contains("the smallest Apple takes is 1400"), small.problems[0])

        let oblong = ArtworkCheck.check(try image("oblong.jpg", width: 1400, height: 1500))
        XCTAssertTrue(oblong.problems.contains { $0.contains("must be square") }, oblong.problems.joined())

        let huge = ArtworkCheck.check(try image("huge.jpg", width: 3200, height: 3200))
        XCTAssertTrue(huge.problems.contains { $0.contains("the largest Apple takes is 3000") })

        let clear = ArtworkCheck.check(try image("clear.png", width: 1400, height: 1400, type: .png, alpha: true))
        XCTAssertTrue(clear.problems.contains { $0.contains("alpha channel") }, clear.problems.joined())

        let grey = ArtworkCheck.check(try image("grey.jpg", width: 1400, height: 1400, grey: true))
        XCTAssertTrue(grey.problems.contains { $0.contains("Apple asks for RGB") }, grey.problems.joined())

        let heavy = ArtworkCheck.check(try image("noisy.jpg", width: 3000, height: 3000, noisy: true))
        XCTAssertTrue(heavy.bytes > ArtworkCheck.largestBytes, "the noisy picture is \(heavy.bytes) bytes")
        XCTAssertTrue(heavy.problems.contains { $0.contains("under 512 KB") }, heavy.problems.joined())

        let fake = work.appending(path: "fake.jpg")
        try Data("not a picture".utf8).write(to: fake)
        XCTAssertEqual(ArtworkCheck.check(fake).problems, ["It does not open as an image."])
        XCTAssertTrue(ArtworkCheck.check(work.appending(path: "gone.jpg")).problems[0].contains("not there any more"))
    }

    // MARK: Names, dates, captions

    func testFileNamesTitlesAndHashtags() {
        var facts = PodcastEpisodeFacts()
        facts.recordedAt = ISO8601DateFormatter().date(from: "2026-09-06T18:06:33-07:00")
        var settings = PodcastReadySettings()
        XCTAssertEqual(PodcastPackage.baseName(settings: settings, facts: facts), "2026-09-06", "no title yet: the date")
        settings.showName = "The Show"
        XCTAssertEqual(PodcastPackage.baseName(settings: settings, facts: facts), "The Show - 2026-09-06")
        facts.title = "Breath: the first step / why it matters?"
        XCTAssertEqual(PodcastPackage.baseName(settings: settings, facts: facts), "The Show - Breath the first step why it matters")
        XCTAssertEqual(PodcastPackage.safe("  ..A title \u{2014} with a dash.  "), "A title , with a dash")
        XCTAssertEqual(PodcastPackage.safe("Yoga M\u{0101}rga: Pr\u{0101}\u{1E47}\u{0101}y\u{0101}ma\u{2019}s \u{2018}breath\u{2019} \u{2665}"), "Yoga Marga Pranayama's 'breath'",
                       "ASCII only, as Apple asks for file names")
        XCTAssertLessThanOrEqual(PodcastPackage.safe(String(repeating: "word ", count: 60)).count, 120)

        for date in ["Sun 6 Sep", "2026-09-06", "6 September 2026", "Sept 6th", "06/09/2026"] {
            XCTAssertTrue(PodcastPackage.isOnlyADate(date), date)
        }
        for title in ["Talk 6/9", "Breath Before Posture", "Sunday", "The 3 Gunas"] {
            XCTAssertFalse(PodcastPackage.isOnlyADate(title), title)
        }
        XCTAssertEqual(PodcastPackage.hashtags(["Yoga Marga", "pranayama", "long exhale", "8 limbs", "Five A's"]), "#YogaMarga #Pranayama #LongExhale #8Limbs #FiveAs")
    }

    /// Social captions are checked like quotes: words in quotation marks must be the teacher's own.
    func testSocialCaptionsAreCheckedLikeQuotes() {
        let transcript = "The long exhale calms the nervous system within a few rounds."
        let found: (String) -> Bool = { transcript.contains($0) }
        let result = WritingCheck.captions([
            "A talk on the breath \u{2014} and why the exhale matters. #yoga #breath",
            "\u{201C}The long exhale calms the nervous system\u{201D}, the teacher says. Listen!",
            "He says \"the exhale cures anxiety\" in this talk.",
            "",
        ], found: found)
        XCTAssertEqual(result.kept, ["A talk on the breath, and why the exhale matters.",
                                     "\u{201C}The long exhale calms the nervous system\u{201D}, the teacher says. Listen."], "the model's own quotation marks are kept")
        XCTAssertEqual(result.leftOut, 2, "a quote not in the transcript, and an empty one")
        XCTAssertEqual(result.changed, 2)
        // A writing answer with captions keeps them; one without them still passes.
        let lines = [WritingLine(start: 0, end: 4, label: "0:00", text: transcript),
                     WritingLine(start: 130, end: 134, label: "2:10", text: "Count four in and eight out."),
                     WritingLine(start: 260, end: 264, label: "4:20", text: "Notice how the mind settles after a few rounds of this.")]
        let answer = #"{"titles": ["A", "B", "C"], "show_notes": "Notes.", "chapters": [{"start": "0:00", "title": "x"}, {"start": "2:10", "title": "y"}, {"start": "4:20", "title": "z"}], "captions": ["Breath first.", "\"Count four in and eight out.\" A simple practice from this talk.", "\"Count to ten\" says the teacher."], "checklist": [{"claim": "c", "quote": "Notice how the mind settles after a few rounds"}]}"#
        let checked = try? WritingCheck.check(answer, lines: lines, transcript: lines.map(\.text).joined(separator: " "), rules: WritingRules.forLength(400), length: 400)
        XCTAssertEqual(checked?.captions, ["Breath first.", "\"Count four in and eight out.\" A simple practice from this talk."])
        XCTAssertEqual(checked?.leftOutCaptions, 1)
    }

    /// The checklist with nothing set: show name and artwork MISSING (never invented), loudness and
    /// peak PASS when they are in range, FAIL when not; a class FAILs; speakers are always MISSING.
    func testTheChecklistSaysWhatIsMissing() {
        var facts = PodcastEpisodeFacts(title: "", notes: "", label: "Sun 6 Sep", kind: .talk, fileName: "2026-09-06 18-06-33.mp4")
        let measured = PodcastPackage.Measured(lufs: -16.0, truePeak: -1.3, lra: 4.7, normalizationType: "linear", sampleRate: 44_100, bitrateKbps: 96,
                                               channels: 1, duration: 3335.2, expectedDuration: 3335.0, bytes: 40_000_000, tailDecodes: true,
                                               tag: nil, intended: [], artwork: nil, chapterProblem: nil, chaptersWritten: 0, captions: (555, 0.08, 3334.0),
                                               captionsProblem: nil)
        let lines = PodcastPackage.checklist(measured, settings: PodcastReadySettings(), facts: facts, written: nil)
        func status(_ item: String) -> ChecklistLine.Status? { lines.first { $0.item == item }?.status }
        XCTAssertEqual(status("Loudness"), .pass)
        XCTAssertEqual(status("True peak"), .pass)
        XCTAssertEqual(status("Leveling"), .pass)
        XCTAssertEqual(status("Sample rate"), .pass)
        XCTAssertEqual(status("Bitrate"), .pass)
        XCTAssertEqual(status("Length"), .pass)
        XCTAssertEqual(status("Show name"), .missing)
        XCTAssertEqual(status("Artwork"), .missing)
        XCTAssertEqual(status("Episode title"), .missing)
        XCTAssertEqual(status("Host or author"), .missing)
        XCTAssertEqual(status("Show notes"), .missing)
        XCTAssertEqual(status("Chapters"), .missing)
        XCTAssertEqual(status("Transcript"), .pass)
        XCTAssertEqual(status("AI voice (Apple 1.11)"), .pass)
        XCTAssertEqual(status("What this is"), .pass)
        XCTAssertEqual(status("Speakers"), .missing)
        XCTAssertEqual(status("Tags"), .fail, "no tag read back is a failure")
        XCTAssertTrue(lines.allSatisfy { ($0.status == .pass) == ($0.todo == nil) }, "every line that does not pass says what to do")
        let text = PodcastPackage.checklistText(lines, facts: facts, fileName: "2026-09-06.mp3", madeAt: Date())
        XCTAssertTrue(text.contains("MISSING  Show name: Not set. Prakriti never makes one up."), text)
        XCTAssertTrue(text.contains("PASS     Loudness: -16.00 LUFS integrated."), text)
        XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "no em or en dashes")

        var loud = measured
        loud.lufs = -14.8
        loud.truePeak = -0.9
        loud.normalizationType = "dynamic"
        let failing = PodcastPackage.checklist(loud, settings: PodcastReadySettings(), facts: facts, written: nil)
        XCTAssertEqual(failing.first { $0.item == "Loudness" }?.status, .fail)
        XCTAssertEqual(failing.first { $0.item == "True peak" }?.status, .fail)
        XCTAssertEqual(failing.first { $0.item == "Leveling" }?.status, .fail)

        facts.kind = .lesson
        facts.title = "Sun 6 Sep"
        let lesson = PodcastPackage.checklist(measured, settings: PodcastReadySettings(showName: "Show", hostName: "Host"), facts: facts, written: nil)
        XCTAssertEqual(lesson.first { $0.item == "What this is" }?.status, .fail)
        XCTAssertEqual(lesson.first { $0.item == "Episode title" }?.status, .missing, "a title that is only a date")
        XCTAssertEqual(lesson.first { $0.item == "Show name" }?.status, .pass)
    }

    // MARK: The pipeline, on the Mac's own voice

    /// The podcast-ready episode end to end on spoken audio, made twice: as it comes, then with the
    /// first 10 s trimmed. The package is named and tagged, measured at -16 within 1 LUFS and -1 dBTP
    /// or under, raised evenly, its checklist written; and the captions move with the trim: a known
    /// line is exactly 10 s less the silence trim earlier the second time.
    func testThePodcastReadyEpisodeAndItsCaptionsFollowATrim() async throws {
        let lines = ["The first part of the talk is about breathing slowly.",
                     "The middle of the talk is about counting each exhale.",
                     "The last part of the talk is about resting well."]
        var spoken: [URL] = []
        for (index, line) in lines.enumerated() {
            let url = work.appending(path: "line\(index).aiff")
            _ = try run(URL(fileURLWithPath: "/usr/bin/say"), ["-o", url.path, line])
            spoken.append(url)
        }
        // 2 s of silence, line 1, 9 s, line 2, 3 s, line 3, then silence to 75 s.
        let same = "aformat=sample_fmts=fltp:sample_rates=22050:channel_layouts=mono"
        let graph = (0..<6).map { "[\($0):a]\(same)[a\($0)]" }.joined(separator: ";") + ";"
            + (0..<6).map { "[a\($0)]" }.joined() + "concat=n=6:v=0:a=1,apad=whole_dur=75"
        let file = try ffmpeg("2026-10-11 spoken.m4a", ["-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=2", "-i", spoken[0].path,
                                                         "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=9", "-i", spoken[1].path,
                                                         "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono:d=3", "-i", spoken[2].path,
                                                         "-filter_complex", graph, "-c:a", "aac"])
        func options(_ edits: EpisodeEdits) -> PipelineOptions {
            var o = PipelineOptions()
            o.stableWait = .milliseconds(200)
            o.trimSilence = true
            o.applyLexicon = true
            o.transcriptFormats = Set(TranscriptFormat.allCases)
            o.edits = edits
            o.kind = .talk
            o.podcastReady = PodcastReadySetup(settings: PodcastReadySettings(), facts: PodcastEpisodeFacts(
                title: "", notes: "", recordedAt: ISO8601DateFormatter().date(from: "2026-10-11T10:00:00-07:00"), label: "Sun 11 Oct", kind: .talk, fileName: file.lastPathComponent))
            return o
        }
        let folder = work.appending(path: "2026-10-11 spoken", directoryHint: .isDirectory)
        let first = await Pipeline(options: options(EpisodeEdits()), log: nil).run(file: file, outputFolder: folder, label: "Sun 11 Oct") { _ in }
        XCTAssertEqual(first.outcome, .ready, first.reason)
        let record = try XCTUnwrap(first.podcastReady, first.podcastProblem ?? "")
        XCTAssertEqual(record.fileName, "2026-10-11.mp3")
        XCTAssertEqual(record.integratedLUFS, -16, accuracy: 1)
        XCTAssertLessThanOrEqual(record.truePeak, -1, "measured to the hundredth")
        XCTAssertEqual(record.normalizationType, "linear")
        XCTAssertEqual(record.sampleRate, 44_100)
        XCTAssertEqual(record.channels, 1)
        XCTAssertEqual(record.bitrateKbps, 96)
        XCTAssertTrue(first.files.contains(PodcastPackage.folderName), "\(first.files)")
        let package = folder.appending(path: PodcastPackage.folderName)
        XCTAssertEqual(Pipeline.madeFiles(in: package), ["2026-10-11.mp3", "2026-10-11.srt", "2026-10-11.vtt", PodcastPackage.textName, PodcastPackage.markdownName,
                                                         PodcastPackage.checklistName].sorted())
        XCTAssertEqual(record.files?.map(\.name), Pipeline.madeFiles(in: package), "the record lists every file it left")
        XCTAssertFalse(FileManager.default.fileExists(atPath: Pipeline.stagingFolder(for: folder).path), "no staging left")
        let steps = first.steps.map(\.name)
        XCTAssertTrue(steps.contains(PipelineStep.podcastAudio.title) && steps.contains(PipelineStep.podcastPackage.title), "\(steps)")
        XCTAssertTrue(first.steps.allSatisfy { $0.state == .done }, "\(first.steps.map { "\($0.name) \($0.state) \($0.detail ?? "")" })")
        let checklist = try String(contentsOf: package.appending(path: PodcastPackage.checklistName), encoding: .utf8)
        XCTAssertTrue(checklist.contains("MISSING  Show name"), checklist)
        XCTAssertTrue(checklist.contains("MISSING  Artwork"), checklist)
        XCTAssertTrue(checklist.contains("PASS     Loudness"), checklist)
        XCTAssertTrue(checklist.contains("PASS     True peak"), checklist)
        XCTAssertTrue(checklist.contains("PASS     Tags: ID3v2.4, read back from the file"), checklist)
        let tag = try XCTUnwrap(ID3.read(package.appending(path: record.fileName)))
        XCTAssertEqual(tag.text["TCON"], "Podcast")
        XCTAssertEqual(tag.text["TDRC"], "2026")
        XCTAssertNil(tag.text["TALB"], "no show name is ever invented")
        let report = try String(contentsOf: folder.appending(path: "REPORT.md"), encoding: .utf8)
        XCTAssertTrue(report.contains("| Podcast-ready episode | `Podcast-ready/2026-10-11.mp3`"), report)

        // The known line: "counting each exhale", timed in the package against transcript.json.
        let heard = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))))
        let middle = try XCTUnwrap(heard.first { $0.text.localizedCaseInsensitiveContains("counting") }, "Parakeet heard: \(heard.map(\.text))")
        let silence = try XCTUnwrap(first.trimmedStart)
        let before = try XCTUnwrap(cue("counting", in: package.appending(path: "2026-10-11.srt")))
        XCTAssertEqual(before.start, (middle.tokens?.first?.start ?? middle.start) - silence, accuracy: 0.2)

        // Made again with the first 10 s trimmed: the line plays 10 s less the silence trim earlier.
        let second = await Pipeline(options: options(EpisodeEdits(start: 10, end: nil, cuts: [])), log: nil).run(file: file, outputFolder: folder, label: "Sun 11 Oct") { _ in }
        XCTAssertEqual(second.outcome, .ready, second.reason)
        let after = try XCTUnwrap(cue("counting", in: package.appending(path: "2026-10-11.srt")))
        XCTAssertEqual(before.start - after.start, 10 - silence, accuracy: 0.001, "shifted by exactly the extra trim")
        XCTAssertNil(try cue("breathing slowly", in: package.appending(path: "2026-10-11.srt")), "the trimmed line is gone from the captions")
        XCTAssertEqual(try XCTUnwrap(second.podcastReady).duration, try XCTUnwrap(first.podcastReady).duration - (10 - silence), accuracy: 0.1)
        let vtt = try String(contentsOf: package.appending(path: "2026-10-11.vtt"), encoding: .utf8)
        XCTAssertTrue(vtt.hasPrefix("WEBVTT"))

        // Approve copies the podcast-ready folder with every file in the receipt.
        let approved = work.appending(path: "Approved/2026-10-11 spoken", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: approved.deletingLastPathComponent(), withIntermediateDirectories: true)
        let copied = try Approval.copy(["REPORT.md", "episode.mp3", PodcastPackage.folderName], from: folder, to: approved,
                                       receipt: Approval.Receipt(label: "Sun 11 Oct", title: "", notes: "", recordingFile: file.lastPathComponent, editsSummary: nil, approvedAt: Date()))
        XCTAssertTrue(copied.files.contains(PodcastPackage.folderName))
        let receipt = try String(contentsOf: approved.appending(path: Approval.receiptName), encoding: .utf8)
        XCTAssertTrue(receipt.contains("| Podcast-ready/2026-10-11.mp3 | "), receipt)
        XCTAssertTrue(receipt.contains(try Approval.sha256(package.appending(path: "2026-10-11.mp3"))))
    }

    /// Through the app: the podcast-ready episode made for a recording, then a show name, host and
    /// title set and Update Podcast-Ready Files pressed. The file is renamed and re-tagged, the audio
    /// is the same audio byte for byte (not made again), and the checklist says the show name passes.
    func testUpdatingTheFilesRetagsWithoutMakingTheAudioAgain() async throws {
        let home = work.appending(path: "home", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: nil), now: { Date() })
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .milliseconds(200)
        let tone = try ffmpeg("2026-10-11 app.m4a", ["-f", "lavfi", "-i", "sine=frequency=220:duration=70", "-af", "volume=-12dB", "-c:a", "aac"])
        let recording = Recording(filePath: tone.path, recordedAt: AppModel.dateInName(tone.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        model.setOutput(.podcastReady, on: true, for: recording)
        model.setOutput(.transcript, on: false, for: recording)
        XCTAssertNotNil(model.runner.options(for: recording).podcastReady)

        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let first = try XCTUnwrap(recording.podcastReady, recording.podcastReadyProblem ?? "")
        let folder = URL(fileURLWithPath: try XCTUnwrap(recording.outputFolder)).appending(path: PodcastPackage.folderName)
        let firstAudio = ID3.audio(of: try Data(contentsOf: folder.appending(path: first.fileName)))
        XCTAssertEqual(first.checklist.first { $0.item == "Show name" }?.status, .missing)
        XCTAssertFalse(model.podcastReadyIsOutOfDate(recording))

        // The show's name and host are the show's, typed on the Outputs screen (11 Oct), even for a
        // recording that has its own choices.
        let show = try XCTUnwrap(model.defaultSettings().first { $0.kind == .podcastReady })
        show.showName = "Test Show"
        show.hostName = "Test Host"
        recording.title = "The Long Exhale"
        recording.episodeNumber = 1
        XCTAssertTrue(model.podcastReadyIsOutOfDate(recording))
        XCTAssertTrue(model.canUpdatePodcastReady(recording))
        await model.runner.process(recording, trigger: .packageAgain)
        let second = try XCTUnwrap(recording.podcastReady)
        XCTAssertEqual(second.fileName, "Test Show - The Long Exhale.mp3")
        XCTAssertEqual(Pipeline.madeFiles(in: folder).filter { $0.hasSuffix(".mp3") }, ["Test Show - The Long Exhale.mp3"], "the old name is gone")
        XCTAssertEqual(ID3.audio(of: try Data(contentsOf: folder.appending(path: second.fileName))), firstAudio, "the same audio, not made again")
        let tag = try XCTUnwrap(ID3.read(folder.appending(path: second.fileName)))
        XCTAssertEqual(tag.text["TALB"], "Test Show")
        XCTAssertEqual(tag.text["TPE1"], "Test Host")
        XCTAssertEqual(tag.text["TIT2"], "The Long Exhale")
        XCTAssertEqual(tag.text["TRCK"], "1")
        XCTAssertEqual(second.checklist.first { $0.item == "Show name" }?.status, .pass)
        XCTAssertEqual(second.checklist.first { $0.item == "Episode title" }?.status, .pass)
        XCTAssertEqual(second.checklist.first { $0.item == "Length" }?.status, .pass)
        XCTAssertFalse(model.podcastReadyIsOutOfDate(recording))
        XCTAssertEqual(recording.status, .readyForYourYes)
        XCTAssertEqual(recording.latestRun?.trigger, .packageAgain)
    }

    /// A store made before the podcast-ready episode existed gets it, switched off, on the Outputs
    /// screen and in every folder; nothing starts making it.
    func testAnOlderStoreGetsTheNewOutputSwitchedOff() throws {
        let paths = AppPaths(mode: .live, home: work)
        let container = AppModel.inMemoryContainer()
        let context = container.mainContext
        _ = try PrakritiStore.seedIfEmpty(context, paths: paths, now: Date())
        for setting in try context.fetch(FetchDescriptor<OutputSetting>()) where setting.kind == .podcastReady { context.delete(setting) }
        try context.save()
        XCTAssertEqual(try PrakritiStore.addMissingOutputKinds(context), [.podcastReady])
        let all = try context.fetch(FetchDescriptor<OutputSetting>()).filter { $0.kind == .podcastReady }
        XCTAssertEqual(all.count, 3, "the default and one for each of the two live folders")
        XCTAssertTrue(all.allSatisfy { !$0.isOn })
        XCTAssertTrue(all.allSatisfy { $0.showName.isEmpty && $0.artworkPath == nil && $0.bitrateKbps == 96 })
        XCTAssertEqual(try PrakritiStore.addMissingOutputKinds(context), [], "only once")
    }

    // MARK: Helpers

    private func ffmpeg(_ name: String, _ arguments: [String]) throws -> URL {
        let url = work.appending(path: name)
        _ = try run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y"] + arguments + [url.path])
        return url
    }

    @discardableResult
    private func run(_ tool: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "\(tool.lastPathComponent) \(arguments.prefix(3))")
        return String(decoding: data, as: UTF8.self)
    }

    private func decodedBytes(_ file: URL) throws -> Int {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-v", "error", "-i", file.path, "-f", "s16le", "-"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data.count
    }

    private func cue(_ words: String, in srt: URL) throws -> TranscriptFiles.Cue? {
        TranscriptFiles.cues(srt: try String(contentsOf: srt, encoding: .utf8)).first { $0.text.localizedCaseInsensitiveContains(words) }
    }

    /// A test image: a gradient (or noise, to make a heavy JPEG), RGB or grey, with or without alpha.
    private func image(_ name: String, width: Int, height: Int, type: UTType = .jpeg, alpha: Bool = false, grey: Bool = false, noisy: Bool = false) throws -> URL {
        let space = grey ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!
        let info: UInt32 = grey ? CGImageAlphaInfo.none.rawValue : (alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info))
        if noisy, let data = context.data {
            let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
            var seed: UInt32 = 2_463_534_242
            for i in 0..<(context.bytesPerRow * height) {
                seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
                bytes[i] = UInt8(truncatingIfNeeded: seed)
            }
        } else {
            context.setFillColor(CGColor(red: 0.14, green: 0.22, blue: 0.78, alpha: alpha ? 0.5 : 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(CGColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1))
            context.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }
        let picture = try XCTUnwrap(context.makeImage())
        let url = work.appending(path: name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, picture, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }
}
