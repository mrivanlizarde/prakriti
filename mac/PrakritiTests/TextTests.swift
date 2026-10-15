import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import XCTest
@testable import Prakriti

/// Text and graphics (v2 part M9b, docs/v2/PLAN.md M9 checks 2 and 4; research-edit-engine.md 2.3 and 2.7). Synthetic only:
/// a made-up ten-minute plan with made-up face boxes for the placing rules, and the test pattern (ffmpeg's `testsrc2`, no face
/// of anyone) for the drawn text, so every frame written here may be looked at.
final class TextTests: XCTestCase {
    // MARK: The typeface

    func testTheBundledTypefaceDrawsEveryIASTLetter() throws {
        XCTAssertTrue(TypeFace.register(), "the three weights of Alegreya Sans are in the app and register")
        for name in [TypeFace.regular, TypeFace.medium, TypeFace.bold] {
            let font = try XCTUnwrap(TypeFace.font(name, size: 40), name)
            XCTAssertEqual(CTFontCopyFamilyName(font) as String, TypeFace.familyName)
            XCTAssertEqual(TypeFace.missing(in: TypeFace.iastTest, font: font), [], "\(name) draws every character of the test string")
            XCTAssertEqual(TypeFace.missing(in: TypeFace.prepared(TypeFace.iastLetters, font: name), font: font), [],
                           "\(name) draws every IAST letter, the four it lacks as one glyph from a letter and its marks")
            XCTAssertEqual(TypeFace.missing(in: TypeFace.iastLetters, font: font).map(String.init).sorted(), ["\u{1E38}", "\u{1E5C}", "\u{1E39}", "\u{1E5D}"].sorted(),
                           "the four it lacks as one glyph, as measured (if a new release adds them, this line changes)")
        }
        let folder = try XCTUnwrap(TypeFace.folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appending(path: TypeFace.licenceFile).path), "the licence travels with the faces")
        // The test itself: a face that lacks a letter is caught.
        let bold = try XCTUnwrap(TypeFace.font(TypeFace.bold, size: 40))
        XCTAssertEqual(TypeFace.missing(in: "a\u{E000}", font: bold), ["\u{E000}"], "a character the face lacks is caught")
        XCTAssertEqual(TypeFace.prepared("Kṛṣṇa", font: TypeFace.bold), "Kṛṣṇa", "letters the face has stay as one glyph")
    }

    // MARK: The motion

    func testTheMotionIsTheResearchTimings() {
        let lower = OverlayKind.lowerThird.motion, title = OverlayKind.title.motion, date = OverlayKind.dateLabel.motion
        XCTAssertEqual(lower.total, 4.55, accuracy: 1e-9, "300 ms in, 4 s, 250 ms out")
        XCTAssertEqual(lower.slide, 24)
        XCTAssertEqual(title.total, 2, "the 2 s title")
        XCTAssertEqual(title.rise, 16)
        XCTAssertEqual(date.total, 3, "the first 3 s of a moment")
        var s = OverlayKind.lowerThird.state(at: 0)
        XCTAssertEqual(s.alpha, 0, accuracy: 1e-6)
        XCTAssertEqual(s.dx, 24, accuracy: 1e-6)
        s = OverlayKind.lowerThird.state(at: 0.15)
        XCTAssertGreaterThan(s.alpha, 0.5, "the ease (0.2, 0.8, 0.2, 1) is fast then settling")
        XCTAssertLessThan(s.alpha, 1)
        s = OverlayKind.lowerThird.state(at: 0.3)
        XCTAssertEqual(s.alpha, 1, accuracy: 1e-6)
        XCTAssertEqual(s.dx, 0, accuracy: 1e-6)
        XCTAssertEqual(OverlayKind.lowerThird.state(at: 4.3).alpha, 1, accuracy: 1e-6)
        XCTAssertEqual(OverlayKind.lowerThird.state(at: 4.425).alpha, 0.5, accuracy: 0.01, "fades out linearly over 250 ms")
        XCTAssertEqual(OverlayKind.lowerThird.state(at: 4.55).alpha, 0)
        XCTAssertEqual(OverlayKind.title.state(at: 0).dy, 16, accuracy: 1e-6)
        XCTAssertEqual(OverlayKind.title.state(at: 1.9).alpha, 0.5, accuracy: 0.01, "fades out over 200 ms")
    }

    // MARK: Placing

    static let gabriel = TextPlan.Teacher(name: "Gabriel Galindo", role: "Teacher", spots: StyleTests.face(x: 0.42))

    static func texts(_ plan: EditPlan) -> [EditPlan.Visual] { plan.visual.filter(\.isText) }

    /// The synthetic plan with its punch-ins, then its text, the face as `faces` (the teacher's own the same).
    static func planned(title: String = "The Lineage of Kṛṣṇamācārya", teacher: TextPlan.Teacher? = gabriel, faces: [FaceSpot]? = nil,
                        house: HouseStyle = .standard) -> EditPlan {
        let made = StyleTests.syntheticPlan()
        var plan = StyleTests.visual(house, face: teacher?.spots ?? StyleTests.face(), plan: made)
        var setup = TextPlan.Setup(title: title, teachers: teacher.map { [$0] } ?? [], faces: faces ?? teacher?.spots ?? StyleTests.face(), pictureWidth: 1920)
        setup.showTitle = house.titleOnScreen
        setup.showNames = house.namesOnScreen
        plan.visual += TextPlan.make(plan: plan, setup: setup, pictureHeight: 1080)
        return plan
    }

    func testTheTitleAndTheNameAreClearOfEveryFaceAndInsideTitleSafe() throws {
        let plan = Self.planned()
        let texts = Self.texts(plan)
        XCTAssertEqual(texts.map(\.kind), [EditPlan.Visual.title, EditPlan.Visual.lowerThird], "\(texts)")
        let timeline = EditTimeline(plan: plan)
        let framing = Framing(plan: plan, timeline: timeline)
        let faces = TextPlan.Faces(spots: StyleTests.face(x: 0.42), timeline: timeline, framing: framing)
        for item in texts {
            let box = try XCTUnwrap(item.box)
            let rect = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
            XCTAssertTrue(OverlayLayout.titleSafe.contains(rect), "\(item.kind) inside title safe: \(rect)")
            let start = try XCTUnwrap(timeline.editFrame(span: item.span, original: try XCTUnwrap(item.in)))
            let frames = Int64((try XCTUnwrap(item.seconds) / timeline.frame.seconds).rounded())
            for f in start..<(start + frames) {
                for face in faces.boxes(at: f) {
                    XCTAssertFalse(face.intersects(rect), "\(item.kind) at frame \(f) over a face \(face)")
                }
            }
        }
        let title = try XCTUnwrap(texts.first)
        XCTAssertEqual(title.lines?.joined(separator: " "), "The Lineage of Kṛṣṇamācārya", "the title is Ivan's words, whole")
        XCTAssertEqual(title.seconds ?? 0, 2, accuracy: timeline.frame.seconds, "2 s")
        XCTAssertEqual(timeline.editFrame(span: title.span, original: title.in ?? -1), 0, "from the first frame")
        let lower = try XCTUnwrap(texts.last)
        XCTAssertEqual(lower.lines ?? [], ["Gabriel Galindo", "Teacher"])
        let lowerStart = try XCTUnwrap(timeline.editFrame(span: lower.span, original: lower.in ?? -1))
        XCTAssertGreaterThanOrEqual(timeline.seconds(lowerStart), 2.5, "after the title and its half second")
        XCTAssertLessThan(timeline.seconds(lowerStart), 4, "at the first moment the teacher is seen after it")
        // The face sits at 0.42 to 0.58 across: the name goes on the side away from its middle (0.50, so the left).
        XCTAssertEqual(lower.align, "leading")
        XCTAssertNotNil(plan.pictureSummary?.range(of: "On screen: the title for 2 s at the start and 1 name under the teacher"), plan.pictureSummary ?? "")
        XCTAssertEqual(PlanValidation.check(plan, words: PlanWords(words: StyleTests.syntheticPlan().words, transcriptSHA256: "", sentences: 0)).filter { $0.rule == 7 }, [])
    }

    func testTheNameGoesOnTheEmptySideAndWaitsForTheFace() throws {
        // The face on the left: the name on the right.
        let left = TextPlan.Teacher(name: "Gabriel Galindo", role: "Teacher", spots: StyleTests.face(x: 0.12))
        let lower = try XCTUnwrap(Self.texts(Self.planned(teacher: left)).first { $0.kind == EditPlan.Visual.lowerThird })
        XCTAssertEqual(lower.align, "trailing")
        XCTAssertGreaterThan(lower.box?[0] ?? 0, 0.5)
        // The teacher seen only from 20 s: the name waits for them.
        let late = TextPlan.Teacher(name: "Gabriel Galindo", role: "Teacher", spots: StyleTests.face(x: 0.42).filter { $0.time >= 20 })
        let plan = Self.planned(teacher: late, faces: StyleTests.face(x: 0.42))
        let waited = try XCTUnwrap(Self.texts(plan).first { $0.kind == EditPlan.Visual.lowerThird })
        let timeline = EditTimeline(plan: plan)
        let start = try XCTUnwrap(timeline.editFrame(span: waited.span, original: waited.in ?? -1))
        let original = try XCTUnwrap(timeline.originalTime(timeline.seconds(start)))
        XCTAssertGreaterThanOrEqual(original, 20 - TextPlan.near, "not before the teacher is seen")
        // A second face filling the bottom of the frame on both sides: no room, so no name, never over the face.
        let crowd = StyleTests.face(x: 0.42) + stride(from: 0.0, through: 601, by: 0.5).flatMap {
            [FaceSpot(time: $0, box: FaceBox(x: 0.03, y: 0.70, width: 0.45, height: 0.28)), FaceSpot(time: $0, box: FaceBox(x: 0.52, y: 0.70, width: 0.45, height: 0.28))]
        }
        XCTAssertNil(Self.texts(Self.planned(faces: crowd)).first { $0.kind == EditPlan.Visual.lowerThird }, "no place clear of the faces: no name")
    }

    func testNoTitleWithoutOneAndTheSwitchesTurnTextOff() {
        XCTAssertEqual(Self.texts(Self.planned(title: "")).map(\.kind), [EditPlan.Visual.lowerThird], "no title in Info: no title on screen")
        XCTAssertEqual(Self.texts(Self.planned(teacher: nil)).map(\.kind), [EditPlan.Visual.title], "no teacher named: no name")
        XCTAssertEqual(Self.texts(Self.planned(house: HouseStyle(titleOnScreen: false))).map(\.kind), [EditPlan.Visual.lowerThird])
        XCTAssertEqual(Self.texts(Self.planned(house: HouseStyle(namesOnScreen: false))).map(\.kind), [EditPlan.Visual.title])
        let long = Self.planned(title: "A very long title that goes on and on about the lineage of modern yoga and everything that came after it in the West")
        if let title = Self.texts(long).first(where: { $0.kind == EditPlan.Visual.title }) {
            XCTAssertLessThanOrEqual(title.lines?.count ?? 0, OverlayLayout.titleLines, "at most three lines")
            XCTAssertGreaterThanOrEqual(title.size ?? 0, OverlayLayout.titleSmallest)
        }
    }

    func testTheValidationRefusesTextOutsideTitleSafeOrOverlapping() throws {
        let plan = Self.planned()
        let words = PlanWords(words: StyleTests.syntheticPlan().words, transcriptSHA256: "", sentences: 0)
        var outside = plan
        let i = try XCTUnwrap(outside.visual.firstIndex { $0.kind == EditPlan.Visual.lowerThird })
        outside.visual[i].box = [0.01, 0.9, 0.3, 0.09]
        XCTAssertTrue(PlanValidation.check(outside, words: words).contains { $0.rule == 7 && $0.line.contains("title-safe") })
        var overlapping = plan
        overlapping.visual[i].in = plan.visual.first { $0.kind == EditPlan.Visual.title }?.in
        overlapping.visual[i].span = plan.visual.first { $0.kind == EditPlan.Visual.title }?.span ?? ""
        XCTAssertTrue(PlanValidation.check(overlapping, words: words).contains { $0.rule == 7 && $0.line.contains("overlap") })
        var empty = plan
        empty.visual[i].lines = [" "]
        XCTAssertTrue(PlanValidation.check(empty, words: words).contains { $0.rule == 7 })
    }

    func testAHouseStyleSavedBeforeTheTextKeepsItsChoices() {
        let m9a = #"{"endingRoom":false,"pace":1,"punchIns":"punchy","style":"energetic","teaching":true}"#
        let read = HouseStyle.decode(m9a)
        XCTAssertEqual(read.style, .energetic)
        XCTAssertEqual(read.pace, .brisk)
        XCTAssertEqual(read.punchIns, .punchy)
        XCTAssertTrue(read.teaching)
        XCTAssertFalse(read.endingRoom)
        XCTAssertTrue(read.titleOnScreen, "the new switches start on")
        XCTAssertTrue(read.namesOnScreen)
        XCTAssertEqual(HouseStyle.decode(read.json()), read, "and it reads back as written")
        XCTAssertNotEqual(HouseStyle(titleOnScreen: false).signature, HouseStyle.standard.signature)
    }

    // MARK: Drawn on the test pattern

    /// A text's box in a made frame, measured by difference against the same frame drawn without text: the pixels whose
    /// brightness rose by 60 or more (white type over anything but white), from the top left in fractions.
    static func inkBox(_ with: RenderTests.Picture, _ without: RenderTests.Picture) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<with.height {
            for x in 0..<with.width {
                let i = (y * with.width + x) * 4
                let a = (Int(with.rgba[i]) + Int(with.rgba[i + 1]) + Int(with.rgba[i + 2])) / 3
                let b = (Int(without.rgba[i]) + Int(without.rgba[i + 1]) + Int(without.rgba[i + 2])) / 3
                if a - b >= 60 {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        let w = Double(with.width), h = Double(with.height)
        return CGRect(x: Double(minX) / w, y: Double(minY) / h, width: Double(maxX - minX + 1) / w, height: Double(maxY - minY + 1) / h)
    }

    func testTheTextIsDrawnWhereThePlanSaysOnTheTestPattern() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "text-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let ffmpegURL = ToolPaths.standard.ffmpeg
        // A made-up face (the test pattern has none): the middle of the frame, so the text must go beside and below it.
        let face = StyleTests.face(minutes: 1, x: 0.42)
        var planSetup = PlanStep.Setup(original: original, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                       jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory), duration: 30, frameRate: 29.97)
        planSetup.subject = face
        planSetup.pictureHeight = 1080
        planSetup.text = TextPlan.Setup(title: "Prāṇāyāma, Īśvara praṇidhāna, Kṛṣṇamācārya",
                                        teachers: [.init(name: "Gabriel Galindo", role: "Teacher", spots: face)], faces: face, pictureWidth: 1920)
        let plan = try await PlanStep.run(planSetup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpegURL, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan
        let texts = Self.texts(plan)
        XCTAssertEqual(texts.map(\.kind), [EditPlan.Visual.title, EditPlan.Visual.lowerThird], "\(plan.visual)")

        let setup = VideoStep.Setup(original: original, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: Date(timeIntervalSince1970: 1_789_000_000),
                                    label: "Test pattern", people: RenderTests.everyoneIncluded())
        let made = try await VideoStep.make(setup, ffmpeg: RenderTests.ffmpeg())
        let record = try await VideoStep.check(made, setup: setup, ffprobe: RenderTests.ffprobe(), ffmpeg: RenderTests.ffmpeg(), now: Date())
        XCTAssertEqual(record.checklist.filter { $0.status == .fail }.map(\.text), [])
        let mp4 = staging.appending(path: VideoStep.folderName).appending(path: record.fileName)
        let timeline = made.timeline
        let plain = try await CompositionBuilder.build(plan: plan, original: original, drawText: false)
        let drawnBefore = await MainActor.run { OverlayCache.drawn }
        let preview = try await CompositionBuilder.build(plan: plan, original: original)
        let drawnAfter = await MainActor.run { OverlayCache.drawn }
        XCTAssertEqual(drawnAfter, drawnBefore, "each text is drawn once: the preview takes the file's pictures from the cache")

        let out = await MainActor.run { SnapshotRenderer.milestoneFolder() }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let output = AVURLAsset(url: mp4)
        for item in texts {
            let start = try XCTUnwrap(timeline.editFrame(span: item.span, original: item.in ?? -1))
            let frames = Int64((item.seconds ?? 0) / timeline.frame.seconds)
            let box = try XCTUnwrap(item.box)
            let planned = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
            // Settled (the middle of its life), coming in, and going out.
            for (moment, frame) in [("settled", start + frames / 2), ("coming in", start + 4), ("going out", start + frames - 3)] {
                let at = timeline.time(frame)
                let madeFrame = try await RenderTests.frame(output, at: at)
                let without = try await RenderTests.frame(plain.composition, videoComposition: plain.videoComposition, at: at)
                let previewFrame = try await RenderTests.frame(preview.composition, videoComposition: preview.videoComposition, at: at)
                let ink = try XCTUnwrap(Self.inkBox(madeFrame, without), "\(item.kind) \(moment): text is drawn")
                print(String(format: "%@ %@ at %.2f s: ink %.3f %.3f %.3f %.3f, planned box %.3f %.3f %.3f %.3f; preview against file %.1f dB",
                             item.kind, moment, timeline.seconds(frame), ink.minX, ink.minY, ink.width, ink.height,
                             planned.minX, planned.minY, planned.width, planned.height, RenderTests.psnr(previewFrame, madeFrame)))
                XCTAssertTrue(OverlayLayout.titleSafe.contains(ink), "\(item.kind) \(moment): inside title safe")
                XCTAssertGreaterThanOrEqual(RenderTests.psnr(previewFrame, madeFrame), 38, "the Viewer draws the text as the file has it")
                if moment == "settled" {
                    // The ink sits inside the planned box (a pixel or two of anti-aliasing aside).
                    XCTAssertTrue(planned.insetBy(dx: -0.004, dy: -0.006).contains(ink), "\(item.kind): ink \(ink) inside the planned box \(planned)")
                    XCTAssertFalse(ink.intersects(CGRect(x: 0.42, y: 0.25, width: 0.16, height: 0.23)), "\(item.kind): not over the made-up face")
                    let name = item.kind == EditPlan.Visual.title ? "m9b-title-test-pattern.png" : "m9b-lower-third-test-pattern.png"
                    try StyleTests.writePNG(Self.outlined(StyleTests.cgImage(madeFrame), face: CGRect(x: 0.42, y: 0.25, width: 0.16, height: 0.23)),
                                            to: out.appending(path: name))
                }
            }
            // Before it starts and after it ends, nothing.
            for frame in [start - 2, start + frames + 2] where frame >= 0 && frame < timeline.keptFrames {
                let at = timeline.time(frame)
                let madeFrame = try await RenderTests.frame(output, at: at)
                let without = try await RenderTests.frame(plain.composition, videoComposition: plain.videoComposition, at: at)
                XCTAssertNil(Self.inkBox(madeFrame, without), "\(item.kind): nothing at frame \(frame), outside its life")
            }
        }

        // The date label (M12b places it; drawn here so its look is checked now): on the test pattern's first frame.
        let date = OverlayLayout.dateLabel(try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 18))), height: 1080)
        XCTAssertEqual(date.lines.first?.text, "6 Sep 2026")
        let image = try await MainActor.run { try XCTUnwrap(OverlayCache.image(date)) }
        let size = OverlayLayout.size(date)
        let inner = OverlayLayout.inner
        let rect = CGRect(x: inner.minX * 1920, y: inner.minY * 1080, width: size.width, height: size.height)
        let table = OverlayTable(items: [.init(kind: .dateLabel, start: 0, frames: 90, box: rect, align: .leading, image: CIImage(cgImage: image),
                                               imageSize: CGSize(width: image.width, height: image.height))],
                                 renderSize: CGSize(width: 1920, height: 1080), frameSeconds: 1001.0 / 30000)
        let first = try await StyleTests.image(AVURLAsset(url: original), at: .zero)
        let composed = Compositor.overlay(table.layers(atEditFrame: 45), on: CIImage(cgImage: first))
        let context = CIContext()
        let drawn = try XCTUnwrap(context.createCGImage(composed, from: composed.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)))
        let ink = try XCTUnwrap(Self.inkBox(StyleTests.picture(drawn), StyleTests.picture(first)))
        XCTAssertTrue(OverlayLayout.titleSafe.contains(ink), "the date label sits inside title safe: \(ink)")
        XCTAssertLessThan(ink.maxY, 0.15, "in the top corner")
        XCTAssertTrue(table.layers(atEditFrame: 90).isEmpty, "gone after 3 s")
        try StyleTests.writePNG(drawn, to: out.appending(path: "m9b-date-label-test-pattern.png"))
    }

    /// The made frame with the made-up face's box outlined, to look at where the text went.
    static func outlined(_ image: CGImage, face: CGRect) -> CGImage {
        let w = image.width, h = image.height
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        context.setStrokeColor(CGColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
        context.setLineWidth(4)
        context.stroke(CGRect(x: face.minX * Double(w), y: (1 - face.maxY) * Double(h), width: face.width * Double(w), height: face.height * Double(h)))
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 0, alpha: 1))
        context.setLineDash(phase: 0, lengths: [16, 12])
        let safe = OverlayLayout.titleSafe
        context.stroke(CGRect(x: safe.minX * Double(w), y: (1 - safe.maxY) * Double(h), width: safe.width * Double(w), height: safe.height * Double(h)))
        return context.makeImage()!
    }
}
