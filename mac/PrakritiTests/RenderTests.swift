import AVFoundation
import CoreGraphics
import Foundation
import XCTest
@testable import Prakriti

/// The rendered MP4 (v2 part M8b, docs/v2/PLAN.md M8 check 1, the RenderTests half). Everything here reads synthetic media
/// only: a moving test pattern (ffmpeg's `testsrc2`, 1920 by 1080 at 29.97, no face of anyone) with the sound of
/// `ums-and-retake.wav` (macOS `say`, `make fixtures`), planned by `PlanStep` as a make plans it, so the plan takes out the
/// planted "um", "uh", stutter and restart. Then the video is made and checked through `VideoStep`, exactly as the
/// pipeline's "Making the video" and "Checking the video" steps call it, and its frames at chosen times are compared with
/// the expected images: the original's own frame at the moment the plan maps there.
final class RenderTests: XCTestCase {
    static let wav = RoughCutTests.wav
    static let transcript = RoughCutTests.transcript

    /// The synthetic original, made once per run in a scratch folder.
    static func syntheticOriginal(in folder: URL) async throws -> URL {
        guard FileManager.default.fileExists(atPath: wav.path) else {
            XCTFail("ums-and-retake.wav is missing: cd ~/Code/prakriti/mac && make fixtures")
            throw PlanStep.Failure(reason: "no fixture")
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let out = folder.appending(path: "pattern.mp4")
        _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, [
            "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30000/1001", "-i", wav.path, "-t", "30",
            "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "15",
            "-bsf:v", "h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-shortest", out.path,
        ], captureStdout: false, timeout: .seconds(120))
        return out
    }

    static func everyoneIncluded() -> OutputGate.People {
        OutputGate.People(faces: FacesFound(checkedAt: Date(), duration: 30), voices: VoicesFound(checkedAt: Date(), duration: 30, source: .tracks),
                          names: ([:], [:]), choices: .none)
    }

    static func ffmpeg() -> @Sendable ([String]) async throws -> String {
        { try await Subprocess.run(ToolPaths.standard.ffmpeg, $0, timeout: .seconds(300)).stderr }
    }

    static func ffprobe() -> @Sendable ([String]) async throws -> String {
        { try await Subprocess.run(ToolPaths.standard.ffprobe, $0, timeout: .seconds(300)).stdout }
    }

    // MARK: The whole video, made and checked

    func testTheVideoIsMadeFromThePlanAndItsFramesAreTheOriginals() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "render-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await Self.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Self.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let ffmpegURL = ToolPaths.standard.ffmpeg
        let planSetup = PlanStep.Setup(original: original, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                       jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory), duration: 30, frameRate: 29.97)
        let plan = try await PlanStep.run(planSetup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpegURL, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan
        XCTAssertGreaterThan(plan.removed.filter { $0.kind != .pause && $0.kind != .trimmed }.count, 2, "the plan takes out the planted mistakes")

        let setup = VideoStep.Setup(original: original, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: Date(timeIntervalSince1970: 1_789_000_000),
                                    label: "Test pattern", people: Self.everyoneIncluded())
        let made = try await VideoStep.make(setup, ffmpeg: Self.ffmpeg())
        let timeline = made.timeline
        XCTAssertEqual(made.frames, Int(timeline.totalFrames), "every frame the plan keeps is written")
        let record = try await VideoStep.check(made, setup: setup, ffprobe: Self.ffprobe(), ffmpeg: Self.ffmpeg(), now: Date())
        for line in record.checklist { print("Ready checklist:", line.text) }

        // Through the gate: the files are in Video, the hidden folder is gone.
        let video = staging.appending(path: VideoStep.folderName, directoryHint: .isDirectory)
        let files = Set(try FileManager.default.contentsOfDirectory(atPath: video.path))
        let base = PodcastPackage.isoDate(Date(timeIntervalSince1970: 1_789_000_000))
        XCTAssertEqual(files, [base + ".mp4", base + ".srt", VideoDescription.fileName, ReadyChecklist.name])
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.appending(path: VideoStep.stagingName).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.appending(path: ".video-job").path), "the decoded sound is deleted")

        // Every measured line passes; only the words Prakriti never invents are missing.
        let failing = record.checklist.filter { $0.status == .fail }
        XCTAssertEqual(failing.map(\.text), [])
        XCTAssertEqual(Set(record.checklist.filter { $0.status == .missing }.map(\.item)), ["Title", "Description", "Chapters"])
        let mp4 = video.appending(path: base + ".mp4")
        XCTAssertEqual(try Mp4Boxes.read(mp4).videoEditLists, 0)
        XCTAssertTrue(try Mp4Boxes.read(mp4).indexBeforeMedia)

        // The frames at chosen moments: the made file's against the original's own frame at the moment the plan maps there.
        let source = AVURLAsset(url: original)
        let output = AVURLAsset(url: mp4)
        for piece in [timeline.pieces.first, timeline.pieces.dropFirst().first, timeline.pieces.last].compactMap({ $0 }) {
            for offset in [Int64(1), piece.frames / 2, piece.frames - 2] where offset >= 0 && offset < piece.frames {
                let editFrame = piece.editFrame + offset, sourceFrame = piece.sourceFrame + offset
                let made = try await Self.frame(output, at: timeline.time(editFrame))
                let expected = try await Self.frame(source, at: timeline.time(sourceFrame))
                let neighbour = try await Self.frame(source, at: timeline.time(sourceFrame + 3))
                let right = Self.psnr(made, expected), wrong = Self.psnr(made, neighbour)
                print(String(format: "Frame %lld (%@ +%lld): %.1f dB against the original's frame %lld, %.1f dB against 3 frames later",
                             editFrame, piece.id, offset, right, sourceFrame, wrong))
                XCTAssertGreaterThanOrEqual(right, 38, "edited frame \(editFrame) is the original's frame \(sourceFrame)")
                XCTAssertLessThan(wrong, right - 3, "the comparison tells frames apart")
            }
        }

        // The composition the Viewer will play (M8c) gives the original's pixels, unchanged, before any encoding.
        let built = try await CompositionBuilder.build(plan: plan, original: original)
        let piece = try XCTUnwrap(built.timeline.pieces.dropFirst().first)
        let composed = try await Self.frame(built.composition, videoComposition: built.videoComposition, at: built.timeline.time(piece.editFrame + 4))
        let sourceFrame = try await Self.frame(source, at: built.timeline.time(piece.sourceFrame + 4))
        XCTAssertGreaterThanOrEqual(Self.psnr(composed, sourceFrame), 60, "nothing is drawn, so the composition passes the original's frame on")

        // Through Core Image (the path M8d draws on): the same picture, less what a round trip through Core Image's RGB costs
        // on a test pattern's sharp coloured edges (its 4:2:0 colour resampled twice): 37.9 dB measured 13 Oct, 23.7 dB before
        // the source's colour tags were put on the new buffer. The test pattern is the hard case; that is why a frame with
        // nothing drawn on it is passed on untouched.
        let drawn = try await CompositionBuilder.build(plan: plan, original: original, throughCoreImage: true)
        let throughCI = try await Self.frame(drawn.composition, videoComposition: drawn.videoComposition, at: drawn.timeline.time(piece.editFrame + 4))
        let ci = Self.psnr(throughCI, sourceFrame)
        print(String(format: "Through Core Image: %.1f dB against the original's frame", ci))
        XCTAssertGreaterThanOrEqual(ci, 35)

        // The captions hold only the kept words, on the edited clock.
        let srt = try String(contentsOf: video.appending(path: base + ".srt"), encoding: .utf8)
        let measured = try XCTUnwrap(Captions.measure(srt: srt))
        XCTAssertLessThanOrEqual(measured.longestLine, 42)
        XCTAssertLessThanOrEqual(measured.lastEnd, timeline.duration + 0.001)
        XCTAssertFalse(srt.lowercased().contains(" um,") || srt.lowercased().contains(" uh "), srt)
        XCTAssertFalse(srt.lowercased().contains("let me start over"), "the restart is gone from the captions")
    }

    // MARK: Pieces

    func testTheTimelineCountsFramesAndTheSoundIsExactlyAsLong() {
        let frame = FrameDuration.ntsc30
        let timeline = EditTimeline(frame: frame, pieces: [
            .init(id: "k1", sourceFrame: 10, frames: 100, editFrame: 0),
            .init(id: "k2", sourceFrame: 300, frames: 7, editFrame: 100),
            .init(id: "k3", sourceFrame: 400, frames: 1000, editFrame: 107),
        ])
        XCTAssertEqual(timeline.totalFrames, 1107)
        XCTAssertEqual(timeline.duration, 1107 * 1001 / 30000.0, accuracy: 1e-9)
        let audio = timeline.audioPieces
        XCTAssertEqual(audio.reduce(0) { $0 + $1.samples }, timeline.totalSamples, "the pieces add up to the picture's length in samples")
        XCTAssertEqual(audio[1].editSample, audio[0].editSample + audio[0].samples)
        XCTAssertEqual(timeline.editTime(305 * frame.seconds)!, 105 * frame.seconds, accuracy: 1e-9)
        XCTAssertNil(timeline.editTime(200 * frame.seconds), "a moment taken out is not in the video")
        XCTAssertEqual(timeline.editTimeAtOrAfter(200 * frame.seconds)!, 100 * frame.seconds, accuracy: 1e-9)
        XCTAssertEqual(timeline.originalTime(105 * frame.seconds)!, 305 * frame.seconds, accuracy: 1e-9)
    }

    func testJoinsCrossfadeWithHandlesAndKeepTheLength() throws {
        // A source of two tones: 1.0 in samples 0 to 9999, then -1.0. Two pieces join at sample 4000 of the output.
        let folder = FileManager.default.temporaryDirectory.appending(path: "join-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var samples: [Float] = []
        for i in 0..<20_000 { let v: Float = i < 10_000 ? 1 : -1; samples += [v, v] }
        let raw = folder.appending(path: "raw.f32"), joined = folder.appending(path: "joined.f32")
        try Data(floatsAsBytes: samples).write(to: raw)
        let pieces = [EditTimeline.AudioPiece(sourceSample: 0, editSample: 0, samples: 4000),
                      EditTimeline.AudioPiece(sourceSample: 12_000, editSample: 4000, samples: 3000)]
        let written = try VideoAudio.join(raw: raw, pieces: pieces, into: joined)
        XCTAssertEqual(written, 7000, "the total is the sum of the pieces")
        let out = try Data(contentsOf: joined).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        XCTAssertEqual(out.count, 14_000)
        XCTAssertEqual(out[2 * 3000], 1, "before the crossfade, the first piece as it was")
        XCTAssertEqual(out[2 * 5000], -1, "after it, the second")
        // Inside the 20 ms (960 samples) around sample 4000, the level moves smoothly from 1 to -1: no jump bigger than the
        // fade's own step.
        var largest: Float = 0
        for i in 3400..<4600 { largest = max(largest, abs(out[2 * (i + 1)] - out[2 * i])) }
        XCTAssertLessThan(largest, 0.01, "no click at the join")
        XCTAssertEqual(out[2 * 4000], 0, accuracy: 0.01, "the middle of an equal-power fade between 1 and -1")

        // The same sound on both sides (room tone into room tone) comes through the fade unchanged: no 3 dB lift mid-fade.
        let tone = (0..<960).flatMap { i -> [Float] in let v = Float(sin(Double(i) * 0.05) * 0.3); return [v, v] }
        let faded = VideoAudio.crossfade(tone, tone, frames: 960)
        XCTAssertEqual(faded.map { abs($0) }.max() ?? 0, tone.map { abs($0) }.max() ?? 0, accuracy: 0.001)
        for i in stride(from: 0, to: tone.count, by: 97) { XCTAssertEqual(faded[i], tone[i], accuracy: 0.0005) }
    }

    func testNoJoinIsBusierThanTheRoomAroundItAndAKnockInAHandleIsLeftOut() throws {
        // Room tone (seeded noise, the same on both channels, as OBS records a mono microphone) with a knock planted in the
        // sound taken out just after the first piece ends, inside that piece's 10 ms handle: 6 Sep at 9:48, measured 14 Oct.
        let folder = FileManager.default.temporaryDirectory.appending(path: "join-room-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func noise() -> Float { state = state &* 6_364_136_223_846_793_005 &+ 1; return Float(Int64(bitPattern: state >> 11) % 2001 - 1000) / 1000 }
        let total = 48_000 * 12
        var mono = (0..<total).map { _ in 0.003 * noise() }
        for i in 0..<300 { mono[20_100 + i] += 0.05 * Float(exp(-Double(i) / 60)) * (i % 2 == 0 ? 1 : -1) }
        let raw = folder.appending(path: "raw.f32"), joined = folder.appending(path: "joined.f32")
        try Data(floatsAsBytes: mono.flatMap { [$0, $0] }).write(to: raw)
        // The knock's join, then 40 more joins of plain room tone: by chance alone about 29% of them would fail the bar.
        var pieces = [EditTimeline.AudioPiece(sourceSample: 0, editSample: 0, samples: 20_000)]
        var source: Int64 = 30_000, edit: Int64 = 20_000
        for k in 0..<41 {
            let length = Int64(4_000 + 97 * k)
            pieces.append(EditTimeline.AudioPiece(sourceSample: source, editSample: edit, samples: length))
            source += length + 2_500
            edit += length
        }
        let written = try VideoAudio.join(raw: raw, pieces: pieces, into: joined)
        XCTAssertEqual(written, edit, "the total is still the sum of the pieces")
        let stereo = try Data(contentsOf: joined).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let out = VideoAudio.mono(stereo)
        func largest(_ range: Range<Int>) -> Float {
            var m: Float = 0
            for i in range where i > 0 && i < out.count { m = max(m, abs(out[i] - out[i - 1])) }
            return m
        }
        for piece in pieces.dropFirst() {
            let j = Int(piece.editSample)
            let inside = largest((j - 480)..<(j + 480))
            let around = max(largest((j - 480 - 1_200)..<(j - 480)), largest((j + 480)..<(j + 480 + 1_200)))
            XCTAssertLessThanOrEqual(inside, around * VideoAudio.calm * 1.0001, "the join at \(j) is no busier than the room")
        }
        let knockJoin = 20_000
        let loudest = out[(knockJoin - 480)..<(knockJoin + 480)].map { abs($0) }.max() ?? 0
        XCTAssertLessThan(loudest, 0.006, "the knock in the handle is not heard: the fade moved to the clean side")
        // Room tone keeps its level through the join: the hold changes only a few samples, by little.
        let window = Array(out[(knockJoin + 2_000)..<(knockJoin + 2_960)])
        XCTAssertEqual(window, Array(mono[(30_000 + 2_000)..<(30_000 + 2_960)]), "past the join, the next piece exactly as it was")
    }

    func testSteadyChangesOnlyTheStepsOverTheLimit() {
        let window: [Float] = [0, 0.1, 0, 0.5, 0, 0.1, 0]
        let held = VideoAudio.steady(window, from: 0, to: 0, limit: 0.2)
        let steps = zip([0] + held, held + [0]).map { abs($1 - $0) }
        XCTAssertLessThanOrEqual(steps.max() ?? 0, 0.2 + 1e-6)
        XCTAssertEqual(held[0], 0, accuracy: 1e-6, "a sample whose steps were within the limit is left alone")
        XCTAssertEqual(VideoAudio.steady([0.1, 0.1], from: 0.1, to: 0.1, limit: 1), [0.1, 0.1], "nothing over, nothing changed")
        // Ends too far apart for the limit: the straight line between them.
        let line = VideoAudio.steady([5, -5, 5], from: 0, to: 4, limit: 0.01)
        XCTAssertEqual(line[1], 2, accuracy: 0.01)
    }

    func testCaptionsKeepToFortyTwoCharactersTwoLinesAndTheirSpeed() {
        let text = "Prāṇāyāma is the practice of the breath, and it starts with simply noticing how you breathe right now"
        let words = text.split(separator: " ").enumerated().map { i, w in
            Captions.Word(text: String(w), start: Double(i) * 0.4, end: Double(i) * 0.4 + 0.3, endsSentence: false, endsClause: w.hasSuffix(","))
        }
        let cues = Captions.cues(words, duration: 20)
        XCTAssertGreaterThan(cues.count, 1)
        for cue in cues {
            XCTAssertLessThanOrEqual(cue.lines.count, 2)
            for line in cue.lines { XCTAssertLessThanOrEqual(line.count, 42, line) }
            XCTAssertLessThanOrEqual(cue.end - cue.start, 7.0001)
        }
        XCTAssertEqual(cues.map(\.text).joined(separator: " "), text, "every word once, in order")
        let measured = Captions.measure(srt: Captions.srt(cues))
        XCTAssertEqual(measured?.cues, cues.count)
        XCTAssertEqual(measured?.overSpeed, 0)
        XCTAssertNil(Captions.layout(String(repeating: "word ", count: 30)), "too long for two lines")
    }

    func testDescriptionNeverInventsAndHoldsChaptersToYouTubesRules() {
        let timeline = EditTimeline(frame: .ntsc30, pieces: [.init(id: "k1", sourceFrame: 0, frames: 30_000, editFrame: 0)])
        let none = VideoDescription.make(title: "", notes: "", written: nil, toOriginal: { $0 }, timeline: timeline)
        XCTAssertNil(none.title)
        XCTAssertNil(none.description)
        XCTAssertTrue(none.text.contains("MISSING"))
        XCTAssertFalse(none.text.contains("\u{2014}"))
        XCTAssertEqual(VideoDescription.problem([.init(start: 0, title: "A"), .init(start: 5, title: "B"), .init(start: 60, title: "C")], duration: 120),
                       "\u{201C}A\u{201D} is shorter than 10 seconds in the video.")
        XCTAssertNil(VideoDescription.problem([.init(start: 0, title: "A"), .init(start: 30, title: "B"), .init(start: 60, title: "C")], duration: 120))
        XCTAssertNotNil(VideoDescription.problem([.init(start: 0, title: "A"), .init(start: 30, title: "B")], duration: 120), "at least three")
        XCTAssertEqual(VideoDescription.stamp(3723), "1:02:03")
        XCTAssertEqual(VideoDescription.stamp(65), "1:05")
    }

    func testMakeVideoRefusesARecordingNotCheckedOrWithSomeoneHiddenOrLeftOut() {
        var people = Self.everyoneIncluded()
        XCTAssertNil(OutputGate.refusal(people), "checked, nobody found: everyone (nobody) is included")
        people.faces = nil
        XCTAssertEqual(OutputGate.refusal(people), OutputGate.notChecked)
        people = Self.everyoneIncluded()
        people.voices = nil
        XCTAssertEqual(OutputGate.refusal(people), OutputGate.notChecked, "faces alone are not a people check")

        people = Self.everyoneIncluded()
        let row = FacePerson(id: 1, label: "Unnamed 1", onScreen: 10, first: 0, last: 10, appearances: 1, keyTime: 1,
                             keyBox: FaceBox(x: 0.4, y: 0.3, width: 0.2, height: 0.3))
        people.faces?.people = [row]
        people.voices?.voices = [FoundVoice(id: 1, label: "Voice 1", speaking: 10, first: 0, last: 10, face: 1)]
        XCTAssertNil(OutputGate.refusal(people), "everyone starts as Include (Ivan, 12 Oct)")
        for choice in [PersonChoice.hideFace, .leaveOut] {
            var choices = PeopleChoices.none
            choices.set(choice, for: .face(1))
            people.choices = choices
            XCTAssertEqual(OutputGate.refusal(people), OutputGate.notYet, "\(choice) is refused until M8d")
            XCTAssertFalse(OutputGate.peopleLine(people).passes)
        }
        var podcastOnly = PeopleChoices.none
        podcastOnly.set(.leaveOut, for: .face(1), output: .podcast)
        people.choices = podcastOnly
        XCTAssertNil(OutputGate.refusal(people), "left out of the podcast only: the video includes them")
        XCTAssertFalse(OutputGate.notYet.contains("\u{2014}"))
    }

    func testTheGateDeletesAFileThatFailsAndNeverMovesIt() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "gate-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let staged = folder.appending(path: ".video", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: staged.appending(path: "a.mp4"))
        var measured = ReadyChecklist.Measured()
        measured.videoCodec = "h264"
        measured.audioCodec = "aac"
        measured.tailDecodes = false
        measured.videoDuration = 10
        let expected = ReadyChecklist.Expected(width: 1920, height: 1080, frameRate: "30000/1001", videoBitrate: 16e6, duration: 10, frame: 1001 / 30000)
        let destination = folder.appending(path: "Video", directoryHint: .isDirectory)
        XCTAssertThrowsError(try OutputGate.admit(staged: staged, to: destination, people: Self.everyoneIncluded(), measured: measured, expected: expected))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path), "deleted where it was made")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path), "never moved")

        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        measured.tailDecodes = true
        var hidden = Self.everyoneIncluded()
        hidden.faces = nil
        XCTAssertThrowsError(try OutputGate.admit(staged: staged, to: destination, people: hidden, measured: measured, expected: expected))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))

        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        try OutputGate.admit(staged: staged, to: destination, people: Self.everyoneIncluded(), measured: measured, expected: expected)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: Frames

    struct Picture {
        let width: Int
        let height: Int
        let rgba: [UInt8]
    }

    static func frame(_ asset: AVAsset, videoComposition: AVVideoComposition? = nil, at time: CMTime) async throws -> Picture {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.appliesPreferredTrackTransform = true
        if let videoComposition { generator.videoComposition = videoComposition }
        let image = try await generator.image(at: time).image
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Picture(width: width, height: height, rgba: rgba)
    }

    /// Peak signal to noise over the RGB channels, in dB (99 for identical pictures).
    static func psnr(_ a: Picture, _ b: Picture) -> Double {
        guard a.width == b.width, a.height == b.height else { return 0 }
        var sum = 0.0
        var count = 0
        for i in stride(from: 0, to: a.rgba.count, by: 4) {
            for c in 0..<3 {
                let d = Double(a.rgba[i + c]) - Double(b.rgba[i + c])
                sum += d * d
            }
            count += 3
        }
        let mse = sum / Double(max(1, count))
        return mse == 0 ? 99 : 10 * log10(255 * 255 / mse)
    }
}
