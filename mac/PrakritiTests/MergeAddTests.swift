import AppKit
import AVFoundation
import Foundation
import SwiftUI
import Vision
import XCTest
@testable import Prakriti

/// v2 part M12b (docs/v2/PLAN.md M12, check 1 (`addedBy`), the synthetic half of checks 3 and 7, and check 5 (Timeline-lite)): a moment
/// from another recording, added by hand. Everything here is made up: two moving test patterns (ffmpeg's `testsrc2`, no face of anyone),
/// the main one with the sound of `ums-and-retake.wav` (`make fixtures`) and its transcript, the other with macOS `say` speaking made-up
/// sentences 9 dB quieter, so the loudness match has work to do. No recording of anyone is read.
@MainActor
final class MergeAddTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-merge-add-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    static let spoken = ["The breath comes before the pose, always.", "When the breath is steady the body softens.", "So we begin every practice with the breath."]
    static let day = Fixtures.date(2026, 9, 6, 18, 0, 0)
    static let teacher = UUID()

    /// The other recording: 40 s of test pattern, `say` speaking `spoken` from 20 s, at a quarter of its level less a little (-9 dB).
    static func otherRecording(in folder: URL) async throws -> (url: URL, words: [PlanWord]) {
        let aiff = folder.appending(path: "spoken.aiff")
        _ = try await Subprocess.run(URL(fileURLWithPath: "/usr/bin/say"), ["-o", aiff.path, spoken.joined(separator: " ")], captureStdout: false, timeout: .seconds(60))
        let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", aiff.path], timeout: .seconds(30))
        let length = Double(probe.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8
        let out = folder.appending(path: "other pattern.mp4")
        _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, [
            "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30000/1001", "-i", aiff.path, "-t", "40",
            "-filter_complex", "[1:a]aresample=48000,adelay=20000|20000,volume=0.355,apad[a]",
            "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "15",
            "-bsf:v", "h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", out.path,
        ], captureStdout: false, timeout: .seconds(120))
        // The words, spread over the speech by how many there are (made up; nothing here is heard by a model).
        let all = spoken.map { $0.split(separator: " ").map(String.init) }
        let count = Double(all.reduce(0) { $0 + $1.count })
        var words: [PlanWord] = []
        var t = 20.15
        let each = (length - 0.4) / count
        for (n, sentence) in all.enumerated() {
            for text in sentence {
                words.append(PlanWord(index: words.count, text: text, norm: PlanWord.normalize(text), start: t, end: t + each * 0.85, sentence: n,
                                      closes: PlanWord.closing(text)))
                t += each
            }
        }
        return (out, words)
    }

    /// The moment as Add keeps it, and as a make reads it: the whole of `spoken`, from the other recording.
    static func insert(_ url: URL, words: [PlanWord], choices: PeopleChoices = .none, other: (from: Double, to: Double)? = nil,
                       addedBy: String = AddedMoment.byIvan) -> MomentInsert {
        let window = MomentWindow(start: words[0].start, end: words[words.count - 1].end, firstWord: 0, lastWord: words.count - 1)
        let found = SupportingMoment(sourceID: UUID(), sourceLabel: AppModel.momentSourceLabel(date: day, kind: .talk, teacher: "Asha Verlaine"), sourceDate: day,
                                     filePath: url.path, window: window, words: PlanWords.text(words[...]), why: "Makes the same point about breath.", point: 0,
                                     after: 18.5, afterWords: "so the body follows the breath.", similarity: 0.7)
        var moment = AddedMoment.added(byIvan: found, showDate: true, at: Fixtures.now)
        moment.addedBy = addedBy
        let (file, voices) = MergeTests.people(duration: 40, other: other)
        let people = MomentPeople.from(file: file, voices: voices, names: (faces: [1: teacher], voices: [1: teacher]), choices: choices,
                                       people: [NamedPerson(id: teacher, name: "Asha Verlaine", released: true)])
        return MomentInsert(moment: moment, name: "other pattern", original: url, duration: 40,
                            words: PlanWords(words: words, transcriptSHA256: "made-up", sentences: spoken.count), people: people)
    }

    static func plan(main: URL, staging: URL, scratch: URL, moments: [MomentInsert]) async throws -> PlanStep.Outcome {
        var setup = PlanStep.Setup(original: main, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                   jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory), duration: 30, frameRate: 29.97)
        setup.pictureHeight = 1080
        setup.text.pictureWidth = 1920
        setup.moments = moments
        let ffmpeg = ToolPaths.standard.ffmpeg
        return try await PlanStep.run(setup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(60))
        }
    }

    // MARK: Check 1: added by Ivan, and only by Ivan

    func testAnAddedMomentCarriesAddedByIvanAndNothingIsAddedWithoutThatCall() throws {
        let (model, recording) = try ApproveTests.madeRecording(in: work, peopleChecked: true)
        XCTAssertTrue(recording.direction.moments.isEmpty, "a recording starts with no moment")
        let words = MergeTests.words(MergeTests.breath)
        let found = SupportingMoment(sourceID: UUID(), sourceLabel: "Sun 6 Sep 2026, Talk with Asha", sourceDate: Self.day, filePath: "/nonexistent.mp4",
                                     window: MomentWindow(start: words[0].start, end: words[14].end, firstWord: 0, lastWord: 14), words: PlanWords.text(words[0...14]),
                                     why: "Makes the same point.", point: 0, after: 252.4, afterWords: "with the breath.", similarity: 0.7)
        // A search's result is shown, never kept: only Add keeps a moment.
        model.momentsState = .found(MomentSearch(header: "", moments: [found], searched: 1, notSearched: 0, teacherName: "Asha Verlaine", windows: 1, candidates: 1,
                                                 judged: 1, declined: 0, by: "a script", seconds: 1))
        XCTAssertTrue(recording.direction.moments.isEmpty, "a search adds nothing")
        model.momentsShowDate = false
        model.addMoment(found, to: recording)
        model.addMoment(found, to: recording)
        XCTAssertEqual(recording.direction.moments.count, 1, "the same moment is added once")
        let added = try XCTUnwrap(recording.direction.moments.first)
        XCTAssertEqual(added.addedBy, "ivan")
        XCTAssertFalse(added.showDate, "the sheet's switch is kept with the moment")
        XCTAssertTrue(model.isAdded(found, to: recording))
        // Kept with the direction, through its JSON; the direction's own signature is not changed by it (the plan keeps its own).
        let again = RecordingDirection.decode(recording.directionJSON)
        XCTAssertEqual(again.moments, [added])
        XCTAssertEqual(again.signature, RecordingDirection().signature)
        XCTAssertNotNil(MomentInserts.signature(again.moments))
        model.setMomentShowsDate(added.id, true, in: recording)
        XCTAssertTrue(recording.direction.moments[0].showDate)
        model.removeMoment(added.id, from: recording)
        XCTAssertTrue(recording.direction.moments.isEmpty)
        XCTAssertNil(MomentInserts.signature(recording.direction.moments))
    }

    func testAMomentNotAddedByIvanIsRefusedByThePlanAndByItsCheck() async throws {
        let scratch = work.appending(path: "render", directoryHint: .isDirectory)
        let main = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let other = try await Self.otherRecording(in: scratch)

        // Not added by Ivan: the plan is refused.
        do {
            _ = try await Self.plan(main: main, staging: staging, scratch: scratch, moments: [Self.insert(other.url, words: other.words, addedBy: "model")])
            XCTFail("a moment not added by Ivan was planned")
        } catch let failure as PlanStep.Failure {
            XCTAssertTrue(failure.reason.contains("was not added by you"), failure.reason)
        }
        // Added by Ivan: planned, and its span says so; changed afterwards, the plan's own check refuses it.
        let insert = Self.insert(other.url, words: other.words)
        let outcome = try await Self.plan(main: main, staging: staging, scratch: scratch, moments: [insert])
        let span = try XCTUnwrap(outcome.plan.insertSpans.first)
        XCTAssertEqual(span.addedBy, "ivan")
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: staging.appending(path: TranscriptFiles.asHeard))))
        XCTAssertEqual(PlanValidation.check(outcome.plan, words: words, inserts: [insert]), [])
        var tampered = outcome.plan
        tampered.spans[tampered.spans.firstIndex(where: \.isInsert)!].addedBy = nil
        XCTAssertTrue(PlanValidation.check(tampered, words: words, inserts: [insert]).contains { $0.rule == 8 && $0.line.contains("you did not add") })
        // Without its own recording to check it against, the plan fails closed.
        XCTAssertTrue(PlanValidation.check(outcome.plan, words: words).contains { $0.rule == 8 && $0.line.contains("could not be checked") })
        // A plan made with no moment holds none.
        let plain = try await Self.plan(main: main, staging: staging, scratch: scratch, moments: [])
        XCTAssertTrue(plain.plan.insertSpans.isEmpty)
        XCTAssertNil(plain.plan.basis.moments)
    }

    // MARK: Checks 3 and 7 on made-up pictures and words

    func testAMomentJoinsTheVideoWithItsDateItsLoudnessAndADissolveAndIsRefusedOnceSomeoneInItIsHidden() async throws {
        let scratch = work.appending(path: "render", directoryHint: .isDirectory)
        let main = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let other = try await Self.otherRecording(in: scratch)
        let insert = Self.insert(other.url, words: other.words)
        let outcome = try await Self.plan(main: main, staging: staging, scratch: scratch, moments: [insert])
        for note in outcome.notes { print("Placing:", note) }
        for line in outcome.plan.planLines ?? [] { print("Plan:", line) }
        let made0 = outcome.plan
        let span = try XCTUnwrap(made0.insertSpans.first)
        XCTAssertEqual(span.join, 12, "Clear joins a moment with a 12-frame cross dissolve")
        var plan = made0
        // The colour match is measured (the moving pattern differs a little from moment to moment) and kept small; the frames below are
        // compared without it, so they are the other recording's own pixels.
        print("Colour match:", span.colour ?? [])
        XCTAssertTrue((span.colour ?? [1, 1, 1]).allSatisfy { abs($0 - 1) < 0.05 }, "\(span.colour ?? [])")
        if let i = plan.spans.firstIndex(where: \.isInsert) { plan.spans[i].colour = nil }
        let label = try XCTUnwrap(made0.visual.first { $0.kind == OverlayKind.dateLabel.rawValue })
        XCTAssertEqual(label.lines, ["6 Sep 2026"])
        XCTAssertEqual(label.span, span.id)
        XCTAssertTrue(plan.summary.contains("Added by you: 1 moment"), plan.summary)
        XCTAssertTrue(plan.planLines?.contains { $0.hasPrefix("Adds your moment from Sun 6 Sep") } == true)

        var setup = VideoStep.Setup(original: main, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: Fixtures.date(2026, 9, 13, 18, 25, 44),
                                    label: "Test pattern", people: RenderTests.everyoneIncluded())
        setup.moments = [insert]
        let logged = LogLines()
        setup.log = { logged.append($0) }
        let made = try await VideoStep.make(setup, ffmpeg: RenderTests.ffmpeg())
        let record = try await VideoStep.check(made, setup: setup, ffprobe: RenderTests.ffprobe(), ffmpeg: RenderTests.ffmpeg(), now: Date())
        XCTAssertEqual(record.checklist.filter { $0.status == .fail }.map(\.text), [], "the Ready checklist passes")
        let timeline = made.timeline
        XCTAssertEqual(made.frames, Int(timeline.totalFrames))
        let piece = try XCTUnwrap(timeline.pieces.first { $0.id == span.id })
        let before = try XCTUnwrap(timeline.pieces.last { $0.editFrame < piece.editFrame })
        let mp4 = staging.appending(path: VideoStep.folderName).appending(path: record.fileName)
        let video = AVURLAsset(url: mp4), source = AVURLAsset(url: other.url), original = AVURLAsset(url: main)

        // The moment's own frames, after its date label: the other recording's, at the plan's moment.
        let middle = piece.frames - 40
        let madeMiddle = try await RenderTests.frame(video, at: timeline.time(piece.editFrame + middle))
        let theirs = try await RenderTests.frame(source, at: timeline.time(piece.sourceFrame + middle))
        let mine = try await RenderTests.frame(original, at: timeline.time(min(before.sourceFrame + before.frames - 1, piece.sourceFrame + middle)))
        let right = RenderTests.psnr(madeMiddle, theirs), wrong = RenderTests.psnr(madeMiddle, mine)
        print(String(format: "The moment's frame: %.1f dB against the other recording's frame, %.1f dB against this recording's", right, wrong))
        XCTAssertGreaterThanOrEqual(right, 35)
        XCTAssertLessThan(wrong, right - 3)

        // The dissolve: before it this recording alone, in its middle a mix of both, after it the moment alone.
        let cut = piece.editFrame
        let outside = try await RenderTests.frame(video, at: timeline.time(cut - 8))
        let outsideExpected = try await RenderTests.frame(original, at: timeline.time(before.sourceFrame + before.frames - 8))
        let mid = try await RenderTests.frame(video, at: timeline.time(cut))
        let a = try await RenderTests.frame(original, at: timeline.time(before.sourceFrame + before.frames))
        let b = try await RenderTests.frame(source, at: timeline.time(piece.sourceFrame))
        let pa = RenderTests.psnr(mid, a), pb = RenderTests.psnr(mid, b), po = RenderTests.psnr(outside, outsideExpected)
        print(String(format: "Dissolve: 8 frames before, %.1f dB against this recording; at the cut, %.1f dB against this recording, %.1f against the moment", po, pa, pb))
        XCTAssertGreaterThanOrEqual(po, 35)
        XCTAssertLessThan(pa, 30, "the frame at the cut is not this recording alone")
        XCTAssertLessThan(pb, 30, "the frame at the cut is not the moment alone")

        // The date label 1 s in: read by Vision, and written for a look.
        let generator = AVAssetImageGenerator(asset: video)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let second = try await generator.image(at: timeline.time(cut + Int64((1 / timeline.frame.seconds).rounded()))).image
        var text = RecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = false
        let read = try await text.perform(on: second).compactMap { $0.topCandidates(1).first?.string }
        print("Vision reads at 1 s into the moment:", read)
        XCTAssertTrue(read.contains { $0.contains("6 Sep 2026") }, "the date label reads 6 Sep 2026: \(read)")
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try Self.png(second, to: out.appending(path: "30-moment-date-label-test-pattern.png"))
        try Self.png(try await generator.image(at: timeline.time(cut)).image, to: out.appending(path: "30-moment-dissolve-middle-test-pattern.png"))

        // The sound: each recording measured in the made file, both within 1 LU of each other; the match was written to the log.
        let start = timeline.seconds(piece.editFrame), end = timeline.seconds(piece.editFrame + piece.frames)
        let theirsLUFS = try await Self.loudness(mp4, from: start + 0.4, to: end - 0.4)
        let mineLUFS = try await Self.loudness(mp4, from: 0.5, to: start - 0.4)
        print(String(format: "Loudness in the made file: this recording %.1f LUFS, the moment %.1f LUFS", mineLUFS, theirsLUFS))
        XCTAssertLessThanOrEqual(abs(theirsLUFS - mineLUFS), 1.0)
        XCTAssertTrue(logged.lines.contains { $0.contains("matched by +") }, logged.lines.joined(separator: "\n"))
        // Its words are in the captions, at its own times.
        let srt = try String(contentsOf: staging.appending(path: VideoStep.folderName).appending(path: record.captionsName), encoding: .utf8)
        XCTAssertTrue(srt.contains("softens"), srt)

        // The Viewer's preview is drawn from the same plan and composition: the moment's frame there too.
        let built = try await CompositionBuilder.build(plan: plan, original: main)
        let previewed = try await RenderTests.frame(built.composition, videoComposition: built.videoComposition, at: timeline.time(piece.editFrame + middle))
        XCTAssertGreaterThanOrEqual(RenderTests.psnr(previewed, theirs), 35)

        // Check 7's half on made-up people: a second face in the moment, set to Leave Out in the other recording after it was added.
        var leaveOut = PeopleChoices()
        leaveOut.set(.leaveOut, for: .face(2))
        let changed = Self.insert(other.url, words: other.words, choices: leaveOut, other: (21, 23))
        do {
            _ = try await Self.plan(main: main, staging: staging, scratch: scratch, moments: [changed])
            XCTFail("the plan used a moment with someone left out")
        } catch let failure as PlanStep.Failure {
            XCTAssertEqual(failure.reason, "A moment from Sun 6 Sep now includes someone who is hidden. Remove it or change their choice.")
        }
        var refused = setup
        refused.moments = [changed]
        let videoFolder = staging.appending(path: VideoStep.folderName)
        let beforeFiles = try FileManager.default.contentsOfDirectory(atPath: videoFolder.path).sorted()
        let modified = try FileManager.default.attributesOfItem(atPath: mp4.path)[.modificationDate] as? Date
        do {
            _ = try await VideoStep.make(refused, ffmpeg: RenderTests.ffmpeg())
            XCTFail("the video was made with a moment holding someone left out")
        } catch let failure as VideoStep.Failure {
            XCTAssertEqual(failure.reason, "A moment from Sun 6 Sep now includes someone who is hidden. Remove it or change their choice.")
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: videoFolder.path).sorted(), beforeFiles)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: mp4.path)[.modificationDate] as? Date, modified, "nothing new reaches Video")
        // The timelines are refused in words for a video with a moment.
        XCTAssertEqual(TimelineExport.refusal(plan: plan, hiddenFaces: 0, leftOutVoices: 0), TimelineExport.momentsRefusal)
    }

    // MARK: Check 5: Timeline-lite and the Direction tab, drawn

    func testDrawTimelineLiteWithTheTealMomentToLookAt() throws {
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let (model, made) = try ApproveTests.madeRecording(in: work, peopleChecked: true)
        let teacher = Person(name: "Asha Verlaine")
        teacher.role = .teacher
        model.context.insert(teacher)
        model.setTeacher(teacher, for: made)
        // A made-up plan over a 900 s recording: kept spans with pauses taken out, and one moment of 26 s added after 4:12.
        var spans: [TimelineSpan] = []
        var t = 0.0
        var k = 0
        while t < 880 {
            let length = [22.0, 35, 18, 41, 27][k % 5]
            spans.append(TimelineSpan(kind: .kept, start: t, end: min(900, t + length), detail: "kept"))
            spans.append(TimelineSpan(kind: .planned, start: min(900, t + length), end: min(900, t + length + 2.5), reason: .pause, detail: "A pause shortened."))
            t += length + 2.5
            k += 1
        }
        // Where a moment goes: at the end of a kept span (235.5 s), as the plan puts it.
        spans.append(TimelineSpan(kind: .moment, start: 235.5, end: 261.5, detail: "From Sun 6 Sep 2026"))
        for (scheme, appearance) in SnapshotRenderer.appearances {
            let view = VStack(alignment: .leading, spacing: 12) {
                Text("Timeline-lite with a moment from another recording").font(AppFont.headline)
                TimelineLite(spans: spans, marks: [TimelineMark(kind: .transition, time: 235.5, line: "A moment from Sun 6 Sep 2026 joins here.")], duration: 900,
                             position: 120, selected: nil) { _ in }
            }
            .padding(24)
            try renderer.renderSheet(AnyView(view.frame(width: 900, height: 140)), model: model, size: CGSize(width: 900, height: 172), appearance: appearance,
                                     name: "30-timeline-lite-moment-\(scheme)")
        }
        // The Direction tab's Supporting Moments with one added, its date switch and Remove.
        let words = MergeTests.words(MergeTests.breath)
        let found = SupportingMoment(sourceID: made.id, sourceLabel: AppModel.momentSourceLabel(date: Self.day, kind: .talk, teacher: "Asha Verlaine"), sourceDate: Self.day,
                                     filePath: "/nonexistent.mp4", window: MomentWindow(start: 1_520, end: 1_546, firstWord: 0, lastWord: 14),
                                     words: PlanWords.text(words[0...14]), why: "Makes the same point.", point: 0, after: 252.4, afterWords: "with the breath.", similarity: 0.7)
        model.addMoment(found, to: made)
        for (scheme, appearance) in SnapshotRenderer.appearances {
            try renderer.renderSheet(AnyView(Form { SupportingMomentsSection(recording: made) }.formStyle(.grouped).frame(width: 400, height: 300)), model: model,
                                     size: CGSize(width: 400, height: 332), appearance: appearance, name: "30-direction-moment-added-\(scheme)")
        }
        // The sheet with Add, and with one added.
        model.cardPictures.useTestPattern = true
        let request = MomentsRequest(recordingID: made.id)
        model.momentsSheet = request
        var second = found
        second.window = MomentWindow(start: 2_010, end: 2_031, firstWord: 15, lastWord: 26)
        second.words = PlanWords.text(words[15...26])
        second.why = "Gives a practice for it: a count for the breath."
        model.momentsState = .found(MomentSearch(header: "Moments that support this recording's main points", moments: [found, second], searched: 2, notSearched: 0,
                                                 teacherName: "Asha Verlaine", windows: 1_126, candidates: 9, judged: 3, declined: 1, by: "Qwen3.8-27B in LM Studio", seconds: 41))
        for (scheme, appearance) in SnapshotRenderer.appearances {
            try renderer.renderSheet(AnyView(SupportingMomentsSheet(request: request).frame(width: 720, height: 868)), model: model,
                                     size: CGSize(width: 720, height: 900), appearance: appearance, name: "30-moments-sheet-add-\(scheme)")
        }
    }

    // MARK: Helpers

    static func png(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        try rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    /// Integrated loudness (EBU R128) of the file's sound between two times.
    static func loudness(_ file: URL, from: Double, to: Double) async throws -> Double {
        let out = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-nostats", "-ss", String(format: "%.3f", from), "-t", String(format: "%.3f", to - from),
                                                                        "-i", file.path, "-vn", "-af", "ebur128", "-f", "null", "-"], timeout: .seconds(120))
        guard let line = out.stderr.components(separatedBy: "\n").last(where: { $0.contains(" I:") && $0.contains("LUFS") }),
              let value = line.split(separator: " ").compactMap({ Double($0) }).first else { throw PlanStep.Failure(reason: "no loudness") }
        return value
    }
}

/// Lines a step logged, collected from any thread.
final class LogLines: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func append(_ line: String) { lock.lock(); stored.append(line); lock.unlock() }
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return stored }
}
