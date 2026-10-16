import AVFoundation
import CoreGraphics
import Foundation
import Vision
import XCTest
@testable import Prakriti

/// The shorts (v2 part M11a, docs/v2/PLAN.md M11 check 1, the shorts' half): the safe rectangle refuses a caption box outside it,
/// the dead-zone crop holds still while the face stays in its middle third, the pages of the calm captions, the twin's sound found
/// at its offset, the twin's faces matched by time and order (unknown means hidden), the choice of moments, and a short made end to
/// end from a synthetic test pattern (no face of anyone): through the main picture's crop and through a vertical twin beside it,
/// measured from the file, and one frame of each written with the safe area drawn on it, to look at.
final class ShortsTests: XCTestCase {
    // MARK: The safe rectangle (PLAN M11 check 1)

    func testTheSafeRectangleRejectsAPlantedCaptionBoxOutsideIt() {
        let words = ["The", "breath", "comes", "first."].enumerated().map { i, w in
            Captions.Word(text: w, start: Double(i) * 0.4, end: Double(i) * 0.4 + 0.3, endsSentence: w.hasSuffix("."), endsClause: false)
        }
        let pages = BurnedCaptions.pages(words, duration: 3)
        XCTAssertFalse(pages.isEmpty)
        XCTAssertEqual(BurnedCaptions.problems(pages), [], "laid out by Core Text, every page sits inside the safe area")
        for page in pages {
            XCTAssertGreaterThanOrEqual(page.box.minX, BurnedCaptions.safe.minX)
            XCTAssertLessThanOrEqual(page.box.maxX, BurnedCaptions.safe.maxX)
            XCTAssertTrue((1250...1400).contains(BurnedCaptions.baseline), "the baseline sits where research 6.3 puts it")
        }
        // Planted: the same page moved under the safe area (into TikTok's bottom band), and one too far right (into its buttons).
        var low = pages[0]
        low.box.origin.y = 1600
        var right = pages[0]
        right.box.origin.x = 1000 - right.box.width / 2
        XCTAssertEqual(BurnedCaptions.problems([low]).count, 1, "a caption box below y 1570 is refused")
        XCTAssertEqual(BurnedCaptions.problems([right]).count, 1, "a caption box past x 960 is refused")
        XCTAssertTrue(BurnedCaptions.problems([low])[0].contains("outside the safe area"))
        // And the gate refuses a short whose captions are outside it, deleting the file.
        let folder = FileManager.default.temporaryDirectory.appending(path: "shorts-gate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "a short.mp4")
        FileManager.default.createFile(atPath: file.path, contents: Data([0]))
        var m = ReadyChecklist.Measured()
        m.videoCodec = "h264"; m.audioCodec = "aac"; m.width = 1080; m.height = 1920; m.tailDecodes = true; m.videoDuration = 30
        let facts = OutputGate.ShortFacts(measured: m, duration: 30, frame: 1001.0 / 30000, captionProblems: BurnedCaptions.problems([low]), twin: false)
        XCTAssertThrowsError(try OutputGate.admitShort(files: [file], to: folder.appending(path: "Shorts"), people: RenderTests.everyoneIncluded(), facts: facts,
                                                       picture: nil, sound: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "a refused short is deleted where it was made")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "Shorts").path))
        // A short over 3 minutes is refused too.
        var long = m
        long.videoDuration = 190
        XCTAssertTrue(OutputGate.shortProblems(RenderTests.everyoneIncluded(), facts: OutputGate.ShortFacts(measured: long, duration: 190, frame: 1001.0 / 30000,
                                                                                                             captionProblems: [], twin: false),
                                               picture: nil, sound: nil).contains { $0.contains("3 minutes") })
    }

    func testCaptionPagesAreTwoToFiveWordsOnOneLineAndChangeAtPhrases() {
        let text = "So the body follows the breath. When the breath is slow, the mind is slow. That is where we begin, and that is where we return."
        var t = 0.0
        let words: [Captions.Word] = text.split(separator: " ").map { w in
            defer { t += 0.35 }
            let s = String(w)
            return Captions.Word(text: s, start: t, end: t + 0.3, endsSentence: s.hasSuffix("."), endsClause: s.hasSuffix(","))
        }
        let pages = BurnedCaptions.pages(words, duration: t + 1)
        XCTAssertEqual(pages.flatMap(\.words).joined(separator: " "), text, "every word, in order, none dropped")
        for page in pages {
            XCTAssertTrue((1...5).contains(page.words.count), "\(page.text)")
            XCTAssertLessThanOrEqual(page.box.width, BurnedCaptions.lineWidth, "one line, 30 px inside the safe area each side")
        }
        XCTAssertGreaterThanOrEqual(pages.filter { $0.words.count >= 2 }.count, pages.count - 1, "2 to 5 words a page")
        XCTAssertTrue(pages.contains { $0.words.last == "breath." }, "a page ends with its sentence")
        for (a, b) in zip(pages, pages.dropFirst()) { XCTAssertLessThanOrEqual(a.end, b.start + 1e-9, "pages never overlap") }
        // The spoken word is drawn full white, the rest at 70%: the picture of a page with its second word said.
        let image = BurnedCaptions.image(pages[0], highlighted: 1)
        XCTAssertNotNil(image)
        XCTAssertEqual(Double(BurnedCaptions.restAlpha), 0.7, accuracy: 1e-9)
        let cap = BurnedCaptions.fontSize(cap: BurnedCaptions.capHeight)
        let font = TypeFace.font(BurnedCaptions.fontName, size: cap)
        XCTAssertNotNil(font, "Alegreya Sans is bundled (never SF Pro in a video)")
        if let font { XCTAssertEqual(CTFontGetCapHeight(font), 64, accuracy: 0.5, "a cap height of 64 px") }
    }

    // MARK: The dead-zone crop (PLAN M11 check 1)

    func testTheDeadZoneCropDoesNotMoveForAFaceInsideTheMiddleThird() {
        let width = VerticalCrop.width(sourceWidth: 1920, sourceHeight: 1080)
        XCTAssertEqual(width, 1080 * 9.0 / 16.0 / 1920, accuracy: 1e-9, "a 608 by 1080 window of a 1080p picture")
        XCTAssertEqual(VerticalCrop.width(sourceWidth: 3840, sourceHeight: 2160) * 3840, 1215, accuracy: 0.5, "1215 by 2160 from 4K")
        XCTAssertEqual(VerticalCrop.width(sourceWidth: 1080, sourceHeight: 1920), 1, "the vertical twin is used whole")
        // A face that sways inside the middle third of the window (its third is width / 3 = 0.105 wide): the window never moves.
        let step = 1001.0 / 30000
        let times = (0..<600).map { Double($0) * step }
        let sway = times.map { FaceSpot(time: $0, box: FaceBox(x: 0.5 + 0.04 * sin($0 * 3) - 0.05, y: 0.3, width: 0.1, height: 0.18)) }
        let still = VerticalCrop.follow(sway, times: times, width: width, step: step)
        XCTAssertEqual(Set(still.map { ($0 * 10_000).rounded() }).count, 1, "the window holds still while the face stays in its middle third")
        XCTAssertEqual(VerticalCrop.framing(centers: still, width: width, sourceWidth: 1920).segments.count, 1, "one window for the whole short")
        // The face walks to the right and stays there: the window follows, and settles with the face back in its middle.
        let walk = times.map { t in FaceSpot(time: t, box: FaceBox(x: (t < 5 ? 0.45 : 0.7) - 0.05, y: 0.3, width: 0.1, height: 0.18)) }
        let moved = VerticalCrop.follow(walk, times: times, width: width, step: step)
        XCTAssertEqual(moved[100], moved[0], accuracy: 1e-9, "still before the walk")
        XCTAssertEqual(moved.last ?? 0, 0.7, accuracy: 0.01, "settled on the face after it")
        let settledBy = moved.indices.first { times[$0] > 5 && abs(moved[$0] - 0.7) < 0.035 }.map { times[$0] - 5 }
        XCTAssertNotNil(settledBy)
        XCTAssertLessThan(settledBy ?? 9, 0.8, "eased over in under a second")
        let share = VerticalCrop.middleShare(walk, times: times, centers: moved, width: width) ?? 0
        XCTAssertGreaterThanOrEqual(share, 0.95, "the face in the middle third of the window in 95% of frames or more")
        // Near the edge of the picture the window stops at the edge: it never shows past the picture.
        let edge = VerticalCrop.follow([FaceSpot(time: 0, box: FaceBox(x: 0.97, y: 0.3, width: 0.03, height: 0.1))], times: [0, 0.1], width: width, step: 0.1)
        XCTAssertEqual(edge[1], 1 - width / 2, accuracy: 1e-9)
        // The compositor scales the window to 1080 by 1920.
        let picture = CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.6)).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let framed = Compositor.frame(picture, crop: CGRect(x: 0.3, y: 0, width: width, height: 1), to: CGSize(width: 1080, height: 1920))
        XCTAssertEqual(framed.extent.width, 1080, accuracy: 0.5)
        XCTAssertEqual(framed.extent.height, 1920, accuracy: 0.5)
        XCTAssertEqual(Compositor.frame(picture, crop: nil).extent, picture.extent, "the video's frames are untouched by this part")
    }

    // MARK: The vertical twin

    func testTheTwinsSoundIsFoundAtItsOffset() {
        var generator = SystemRandomNumberGenerator()
        let rate = TwinSync.rate
        let noise = (0..<(rate * 20)).map { _ in Float.random(in: -1...1, using: &generator) }
        // The twin runs 0.4 s ahead: its moment of the main recording's t is t + 0.4.
        let lead = Int(0.4 * Double(rate))
        let main = Array(noise[(rate * 5)..<(rate * 13)])
        // The twin's sample of the main recording's moment i sits at i + lead on its own clock.
        let twin = Array(noise[(rate * 5 - lead - rate * 2)..<(rate * 5 - lead + rate * 10)])
        let (lag, correlation) = TwinSync.bestLag(main: main, twin: twin) ?? (-1, 0)
        XCTAssertEqual(Double(lag) / Double(rate) - 2, 0.4, accuracy: 0.001, "the twin found 0.4 s ahead")
        XCTAssertGreaterThan(correlation, 0.99)
        let offset = TwinSync.Offset(seconds: 0.4, frames: 12, points: [0.4, 0.401, 0.399], correlations: [0.99, 0.99, 0.99])
        XCTAssertTrue(offset.lines(frame: 1001.0 / 30000))
        XCTAssertFalse(TwinSync.Offset(seconds: 0.4, frames: 12, points: [0.4, 0.45, 0.4], correlations: [0.99, 0.99, 0.99]).lines(frame: 1001.0 / 30000),
                       "three moments more than a frame apart do not line up")
        XCTAssertFalse(TwinSync.Offset(seconds: 0.4, frames: 12, points: [0.4, 0.4, 0.4], correlations: [0.99, 0.3, 0.99]).lines(frame: 1001.0 / 30000),
                       "a weak match does not count")
        let folder = URL(fileURLWithPath: "/tmp/x", isDirectory: true)
        XCTAssertNil(TwinSync.twin(of: folder.appending(path: "2026-09-13 18-25-44.mp4")))
    }

    func testTheTwinsFacesAreMatchedByTimeAndOrderAndUnknownIsHidden() {
        // The main recording: Gabriel (row 1) on the left, a guest (row 2) on the right, from 0 to 10 s; the twin runs 1 s ahead.
        let main: [TwinFaces.MainSighting] = stride(from: 0.0, through: 10, by: 0.5).flatMap { t in
            [TwinFaces.MainSighting(time: t, x: 0.3, row: 1, track: 1), TwinFaces.MainSighting(time: t, x: 0.7, row: 2, track: 2)]
        }
        func track(_ id: Int, x: Double, from: Double, to: Double) -> FaceTrack {
            FaceTrack(id: id, sightings: stride(from: from, through: to, by: 0.5).map {
                FaceSighting(time: $0, box: FaceBox(x: x - 0.05, y: 0.3, width: 0.1, height: 0.15), confidence: 0.9)
            })
        }
        // Both faces in the twin from 1 to 11 s of its clock; a third face (a poster) from 12 to 14 s, when the main sees no one.
        let tracks = [track(10, x: 0.4, from: 1, to: 11), track(11, x: 0.6, from: 1, to: 11), track(12, x: 0.5, from: 12, to: 14)]
        let matches = TwinFaces.match(tracks, main: main, offset: 1, segments: [], links: [])
        XCTAssertEqual(matches.first { $0.track == 10 }?.row, 1)
        XCTAssertEqual(matches.first { $0.track == 11 }?.row, 2)
        XCTAssertNil(matches.first { $0.track == 12 }?.row, "a face the main recording never saw is unknown")
        let found = TwinFaces.Found(tracks: tracks, matches: matches, samples: 30, seconds: 0)
        // The guest is hidden in shorts: the twin hides the guest's track and the unknown one, and shows Gabriel.
        let plan = TwinFaces.hidePlan(found) { $0 == 1 }
        XCTAssertEqual(Set(plan.tracks.map(\.id)), [11, 12])
        let check = TwinFaces.checkTracks(found) { $0 == 1 }
        XCTAssertEqual(check.filter(\.hidden).map(\.id).sorted(), [11, 12])
        // By voice: one face in the twin while the main sees none, and the voice speaking is linked to row 1.
        let alone = [track(20, x: 0.5, from: 20, to: 22)]
        let voiced = TwinFaces.match(alone, main: [], offset: 1, segments: [VoiceSegment(start: 18, end: 22, voice: 1)], links: [[1, 1]])
        XCTAssertEqual(voiced.first?.row, 1, "matched by the voice linked to the face")
        XCTAssertTrue(found.line.contains("own face step ran"))
    }

    // MARK: Choosing the moments

    func testTheStrongestStandaloneMomentsAreChosenWithinTheirLength() {
        // Forty sentences of 5 words, 3 s each, every word 0.5 s: a made-up talk on the original's clock, all kept.
        var words: [PlanWord] = []
        for s in 0..<40 {
            for k in 0..<5 {
                let i = words.count
                words.append(PlanWord(index: i, text: k == 4 ? "end." : "word", norm: "word", start: Double(s) * 3 + Double(k) * 0.5,
                                      end: Double(s) * 3 + Double(k) * 0.5 + 0.4, sentence: s, closes: k == 4 ? .sentence : .none))
            }
        }
        let span = EditPlan.Span(id: "k1", source: "s", from: "w0", to: "w\(words.count - 1)", in: 0, out: 120, text: "")
        let plan = EditPlan(recording: "test", transcriptSHA256: "", frameDuration: .ntsc30, style: "clear", spans: [span], madeAt: Date(),
                            sourceDuration: 120, envelope: .init(floorDB: -60, speechDB: -20), basis: .init(edits: EpisodeEdits(), peopleSignature: ""))
        func beat(_ id: String, _ a: Int, _ b: Int, kind: BeatKind, hook: Bool, alone: Bool, score: Int, key: Int? = nil) -> Beat {
            Beat(id: id, firstSentence: "s\(a + 1)", lastSentence: "s\(b + 1)", from: "w\(a * 5)", to: "w\(b * 5 + 4)", start: Double(a) * 3,
                 end: Double(b) * 3 + 2.4, summary: id, scores: ["motivating": score], kind: kind, standsAlone: alone, dependsOn: alone ? [] : ["b1"],
                 keyLine: key.map { Beat.KeyLine(from: "w\($0 * 5)", to: "w\($0 * 5 + 4)", text: "") }, hookCandidate: hook, terms: [], thesis: false)
        }
        let beats = [beat("b1", 0, 9, kind: .welcome, hook: true, alone: true, score: 3),
                     beat("b2", 10, 24, kind: .teaching, hook: true, alone: true, score: 3, key: 14),
                     beat("b3", 25, 31, kind: .story, hook: false, alone: false, score: 2),
                     beat("b4", 32, 39, kind: .teaching, hook: false, alone: true, score: 1)]
        let (windows, notes) = Shorts.choose(plan: plan, words: words, beats: beats, settings: ShortsSettings(count: 3, length: 30))
        XCTAssertEqual(windows.map(\.beat), ["b2", "b4", "b3"], "a strong opening that stands alone first; never the welcome while another will do. Notes: \(notes)")
        let (least, most) = ShortsSettings(count: 3, length: 30).bounds
        for w in windows {
            XCTAssertGreaterThanOrEqual(w.kept, least)
            XCTAssertLessThanOrEqual(w.kept, most)
            XCTAssertEqual(w.start / plan.frameDuration.seconds, (w.start / plan.frameDuration.seconds).rounded(), accuracy: 1e-6, "cut on a frame")
        }
        XCTAssertEqual(windows[0].firstWord, 14 * 5, "the short opens on its part's key line")
        for (a, b) in zip(windows, windows.dropFirst()) { XCTAssertFalse(a.start < b.end && b.start < a.end, "no two shorts overlap") }
        // Its spans are the plan's, cut at its ends.
        let spans = Shorts.spans(plan, window: windows[0])
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].in, windows[0].start, accuracy: 1e-9)
        XCTAssertEqual(spans[0].from, "w70")
        // A voice left out of shorts speaking inside a part: no short of it.
        let avoided = Shorts.choose(plan: plan, words: words, beats: beats, settings: ShortsSettings(count: 3, length: 30),
                                    avoid: [TimeRange(start: 45, end: 46)])
        XCTAssertFalse(avoided.windows.contains { $0.beat == "b2" })
        XCTAssertEqual(Shorts.choose(plan: plan, words: words, beats: beats, settings: ShortsSettings(count: 0, length: 30)).windows, [], "none asked, none made")
        XCTAssertEqual(RecordingDirection().shorts, ShortsSettings(count: 3, length: 60), "3 shorts of up to 60 s unless Ivan chooses")
        XCTAssertEqual(RecordingDirection(shortsCount: 9, shortsLength: 50).shorts, ShortsSettings(count: 5, length: 60), "0 to 5; 30, 45 or 60 s")
        XCTAssertTrue(RecordingDirection(shortsCount: 2).isEmpty, "the shorts' count is not part of the plan's direction")
        XCTAssertNotNil(RecordingDirection(shortsCount: 2).json(), "but it is kept")
    }

    // MARK: A short made end to end, on a synthetic test pattern

    func testAShortIsMadeFromATestPatternCroppedAndFromAVerticalTwin() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "shorts-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let transcript = staging.appending(path: TranscriptFiles.asHeard)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: transcript)
        let ffmpegURL = ToolPaths.standard.ffmpeg
        let planSetup = PlanStep.Setup(original: original, transcript: transcript, jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory),
                                       duration: 30, frameRate: 29.97)
        let plan = try await PlanStep.run(planSetup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpegURL, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: transcript)))
        let sentences = BeatSentence.from(words.words)
        let beat = Beat(id: "b1", firstSentence: "s1", lastSentence: "s\(sentences.count)", from: "w0", to: "w\(words.words.count - 1)", start: 0,
                        end: words.words.last?.end ?? 30, summary: "the breath comes first", scores: ["practical": 3], kind: .teaching, standsAlone: true,
                        dependsOn: [], keyLine: nil, hookCandidate: true, terms: [], thesis: true)
        let beats = BeatsFile(recording: "pattern", transcriptSHA256: words.transcriptSHA256, madeAt: Date(), by: "a test", provider: "none",
                              temperature: nil, seed: nil, seconds: 0, attempts: 1, beats: [beat])
        let settings = ShortsSettings(count: 1, length: 30)
        let out = await SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        // 1. Cropped from the 1920 by 1080 picture (nobody's face: the window stays in the middle).
        var setup = Shorts.Setup(original: original, plan: plan, transcript: transcript, beats: beats, staging: staging, title: "", recordedAt: Date(timeIntervalSince1970: 1_789_000_000),
                                 settings: settings, people: RenderTests.everyoneIncluded())
        let record = try await Shorts.make(setup, ffmpeg: RenderTests.ffmpeg(), ffprobe: RenderTests.ffprobe(), now: Date())
        XCTAssertEqual(record.source, .crop1080)
        XCTAssertEqual(record.warning, Shorts.softWarning, "a 1080p crop says it is softer")
        let short = try XCTUnwrap(record.shorts.first)
        for line in short.lines { print("Short checklist:", line.text) }
        XCTAssertEqual(short.lines.filter { $0.status == .fail }.map(\.text), [])
        let folder = staging.appending(path: Shorts.folderName, directoryHint: .isDirectory)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)), [short.fileName, short.captionsName, Shorts.recordName])
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.appending(path: Shorts.stagingName).path), "the hidden folder is gone")
        let mp4 = folder.appending(path: short.fileName)
        let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-select_streams", "v:0", "-show_entries",
                                                                          "stream=width,height,r_frame_rate,bit_rate", "-of", "compact=p=0", mp4.path], timeout: .seconds(30)).stdout
        XCTAssertTrue(probe.contains("width=1080|height=1920|r_frame_rate=30000/1001"), probe)
        let read = try XCTUnwrap(Shorts.Record.read(folder))
        XCTAssertEqual(read.shorts.map(\.fileName), record.shorts.map(\.fileName))
        XCTAssertEqual(read.source, record.source)
        // The cropped frame is the original's middle, enlarged: compared with Core Graphics' own crop of the original's frame.
        let timeline = EditTimeline(plan: Shorts.plan(plan, window: short.window))
        let piece = try XCTUnwrap(timeline.pieces.first)
        let made = try await RenderTests.frame(AVURLAsset(url: mp4), at: timeline.time(piece.editFrame + 20))
        print("Made frame:", made.width, made.height)
        try await writeFrame(mp4, at: timeline.seconds(piece.editFrame + 20), to: out.appending(path: "m11a-test-pattern-short-crop.png"))

        // 2. With a vertical twin beside it: a 1080 by 1920 test pattern whose sound runs 0.1 s (3 frames) late.
        let twin = scratch.appending(path: "pattern-vertical.mp4")
        _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, [
            "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=1080x1920:rate=30000/1001", "-i", RenderTests.wav.path, "-t", "30",
            "-map", "0:v", "-map", "1:a", "-af", "adelay=100:all=1", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "15",
            "-bsf:v", "h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", twin.path,
        ], captureStdout: false, timeout: .seconds(120))
        XCTAssertEqual(TwinSync.twin(of: original), twin)
        setup.people = RenderTests.everyoneIncluded()
        let twinRecord = try await Shorts.make(setup, ffmpeg: RenderTests.ffmpeg(), ffprobe: RenderTests.ffprobe(), now: Date())
        let offset = try XCTUnwrap(twinRecord.twin)
        print("Twin:", offset.line, offset.points)
        XCTAssertEqual(twinRecord.source, .vertical, twinRecord.twinNote ?? "")
        XCTAssertEqual(offset.seconds, 0.1, accuracy: 0.005, "the twin's sound found 0.1 s late")
        XCTAssertEqual(offset.frames, 3)
        XCTAssertNil(twinRecord.warning)
        let twinShort = try XCTUnwrap(twinRecord.shorts.first)
        XCTAssertNotNil(twinShort.pictureCheck, "the twin's picture is always checked again")
        XCTAssertEqual(twinShort.pictureCheck?.passed, true)
        XCTAssertEqual(twinShort.lines.filter { $0.status == .fail }.map(\.text), [])
        XCTAssertNotNil(twinRecord.twinFaces)
        // The twin's frames, shifted by its 3 frames: the short's frame is the twin's own frame there, not the main picture's.
        let twinMp4 = folder.appending(path: twinShort.fileName)
        let twinTimeline = EditTimeline(plan: Shorts.plan(plan, window: twinShort.window))
        let p = try XCTUnwrap(twinTimeline.pieces.first)
        let shortFrame = try await RenderTests.frame(AVURLAsset(url: twinMp4), at: twinTimeline.time(p.editFrame + 20))
        // Above the captions (the top half of the frame), against the twin's frame at the shifted time, put through the same window
        // by Core Graphics (no face in a test pattern, so the window sits in the middle: 1/1.25 of the picture).
        let source = try await Self.windowed(twin, at: twinTimeline.time(p.sourceFrame + 20 + offset.frames))
        let shiftedWrong = try await Self.windowed(twin, at: twinTimeline.time(p.sourceFrame + 20))
        let later = try await Self.windowed(twin, at: twinTimeline.time(p.sourceFrame + 20 + 2 * offset.frames))
        let right = RenderTests.psnr(Self.topHalf(shortFrame), Self.topHalf(source))
        let wrong = max(RenderTests.psnr(Self.topHalf(shortFrame), Self.topHalf(shiftedWrong)), RenderTests.psnr(Self.topHalf(shortFrame), Self.topHalf(later)))
        print(String(format: "Twin frame: %.1f dB against the twin's own frame at the offset, at most %.1f dB 3 frames either side", right, wrong))
        XCTAssertGreaterThanOrEqual(right, 22)
        XCTAssertLessThan(wrong, right - 1, "the frame 3 frames on, where the measured offset put it, and no other")
        try await writeFrame(twinMp4, at: twinTimeline.seconds(p.editFrame + 20), to: out.appending(path: "m11a-test-pattern-short-twin.png"))
    }

    /// The twin's frame at a time through the middle window of the twin's reframe, scaled back to 1080 by 1920 by Core Graphics.
    static func windowed(_ url: URL, at time: CMTime) async throws -> RenderTests.Picture {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: time).image
        let w = 1 / VerticalCrop.twinZoom
        let crop = CGRect(x: (1 - w) / 2 * Double(image.width), y: (1 - w) / 2 * Double(image.height), width: w * Double(image.width), height: w * Double(image.height))
        let part = try XCTUnwrap(image.cropping(to: crop.integral))
        var rgba = [UInt8](repeating: 0, count: 1080 * 1920 * 4)
        let context = CGContext(data: &rgba, width: 1080, height: 1920, bitsPerComponent: 8, bytesPerRow: 1080 * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(part, in: CGRect(x: 0, y: 0, width: 1080, height: 1920))
        return RenderTests.Picture(width: 1080, height: 1920, rgba: rgba)
    }

    /// The top half of a picture: above the captions.
    static func topHalf(_ p: RenderTests.Picture) -> RenderTests.Picture {
        let rows = p.height / 2
        return RenderTests.Picture(width: p.width, height: rows, rgba: Array(p.rgba.prefix(rows * p.width * 4)))
    }

    /// One frame of a short, with research 6.3's safe area drawn on it, written as a PNG to look at (test pattern only).
    private func writeFrame(_ mp4: URL, at seconds: Double, to png: URL) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: mp4))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        try await ShortsAcceptanceTests.writeWithSafeArea(image, to: png)
    }

    /// PLAN M11 check 1, the part M11b runs: Approve refuses a deliverable whose checklist has a FAIL and copies nothing. A short of
    /// 190 s (over YouTube's 3 minutes) is planted beside two good ones; ticked, the yes is refused and nothing reaches Approved.
    @MainActor
    func testApproveRefusesAShortThatFailsAndCopiesNothing() throws {
        let work = FileManager.default.temporaryDirectory.appending(path: "prakriti-shorts-approve-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: work) }
        let (model, recording) = try ApproveTests.madeRecording(in: work, plantedSeconds: 190)
        let all = Set(model.approvalDeliverables(recording).map(\.id))
        XCTAssertFalse(model.approve(recording, chosen: all))
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.approvedFolder(for: recording).path), "nothing was copied")
        XCTAssertNil(recording.approvedAt)
        // A failing line in a short's own checklist is refused the same way.
        let folder = URL(fileURLWithPath: recording.outputFolder!).appending(path: Shorts.folderName)
        var record = try XCTUnwrap(Shorts.Record.read(folder))
        record.shorts[1].lines = [ChecklistLine(status: .fail, item: "Loudness", detail: "-17.2 LUFS (-14, within 1).")]
        try ApproveTests.headerOnlyMP4(seconds: 42, to: folder.appending(path: "Short 2.mp4"))
        try record.encoded().write(to: folder.appending(path: Shorts.recordName))
        let item = try XCTUnwrap(model.approvalDeliverables(recording).first { $0.id == "short-2" })
        XCTAssertEqual(item.failure, "Short 2 fails a check: Loudness, -17.2 LUFS (-14, within 1).")
        XCTAssertFalse(model.approve(recording, chosen: all))
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.approvedFolder(for: recording).path))
    }
}
