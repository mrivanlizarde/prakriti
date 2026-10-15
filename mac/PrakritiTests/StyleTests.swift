import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Prakriti

/// The house style and the zooms (v2 part M9a, docs/v2/PLAN.md M9; research-edit-engine.md 2.3 to 2.6). Synthetic only: a
/// made-up ten-minute plan with a made-up face box for the rules, and the test pattern (ffmpeg's `testsrc2`, no face of anyone)
/// with the sound of `ums-and-retake.wav` for the picture, so every frame written here may be looked at.
final class StyleTests: XCTestCase {
    // MARK: The numbers

    func testTheStylesAreTheResearchTables() {
        let clear = Style.base(.clear)
        XCTAssertEqual(clear.roughCut, RoughCutPreset.clear, "Clear's rough cut is M8a's measured defaults, number for number")
        XCTAssertEqual(clear.changesPerMinute, 6...8)
        XCTAssertEqual(clear.openingChanges, 10)
        XCTAssertEqual(clear.punchScales, [1.00, 1.12])
        XCTAssertEqual(clear.pushIn, Style.PushIn(to: 1.05, seconds: 4, every: 90))
        XCTAssertEqual(clear.endingSeconds, 5)
        let calm = Style.base(.calm)
        XCTAssertEqual([calm.insideTarget, calm.insideTrigger, calm.sentenceTarget, calm.sentenceTrigger, calm.protectedLimit], [0.30, 0.70, 0.60, 1.00, 8])
        XCTAssertEqual(calm.changesPerMinute, 3...4)
        XCTAssertEqual(calm.punchScales, [1.00, 1.06])
        XCTAssertTrue(calm.punchOnlyWhereCutsJump)
        let energetic = Style.base(.energetic)
        XCTAssertEqual([energetic.insideTarget, energetic.insideTrigger, energetic.sentenceTarget, energetic.sentenceTrigger, energetic.protectedLimit],
                       [0.10, 0.25, 0.20, 0.35, 2])
        XCTAssertEqual(energetic.changesPerMinute, 12...15)
        XCTAssertEqual(energetic.medianShot, 3...4)
        XCTAssertEqual(energetic.punchScales, [1.00, 1.15, 1.25])
        XCTAssertNil(energetic.pushIn)
        XCTAssertEqual(energetic.snapZoom, Style.SnapZoom(to: 1.30, frames: 6, every: 45))
        let story = Style.base(.story)
        XCTAssertEqual([story.insideTarget, story.insideTrigger, story.sentenceTarget, story.sentenceTrigger], [0.22, 0.50, 0.45, 0.80])
        XCTAssertEqual(story.changesPerMinute, 4...6)
        XCTAssertEqual(story.punchScales, [1.00, 1.10])
        XCTAssertEqual(story.pushIn, Style.PushIn(to: 1.06, seconds: 6, every: 60))
        XCTAssertEqual(Length.highlights.targetSeconds, 180)
        XCTAssertNil(Length.whole.targetSeconds)
    }

    func testPacePunchInsTeachingAndTheEndingChangeTheNumbers() {
        let brisk = Style.make(HouseStyle(style: .clear, pace: .brisk))
        XCTAssertEqual(brisk.insideTrigger, 0.40 / 1.25, accuracy: 1e-9)
        XCTAssertEqual(brisk.sentenceTarget, 0.35 / 1.25, accuracy: 1e-9)
        XCTAssertEqual(brisk.changesPerMinute.lowerBound, 7.5, accuracy: 1e-9)
        XCTAssertEqual(brisk.changesPerMinute.upperBound, 10, accuracy: 1e-9)
        XCTAssertEqual(brisk.pushIn?.every ?? 0, 72, accuracy: 1e-9)
        let relaxed = Style.make(HouseStyle(style: .clear, pace: .relaxed))
        XCTAssertEqual(relaxed.insideTarget, 0.18 / 0.8, accuracy: 1e-9)
        XCTAssertEqual(relaxed.openingChanges, 8)

        let off = Style.make(HouseStyle(punchIns: .off))
        XCTAssertEqual(off.punchScales, [1.00])
        XCTAssertNil(off.pushIn)
        let subtle = Style.make(HouseStyle(punchIns: .subtle))
        XCTAssertEqual(subtle.punchScales, [1.00, 1.06])
        XCTAssertTrue(subtle.punchOnlyWhereCutsJump)
        XCTAssertEqual(subtle.insideTrigger, 0.40, "punch-ins never change the pauses")
        let punchy = Style.make(HouseStyle(punchIns: .punchy))
        XCTAssertEqual(punchy.punchScales, [1.00, 1.15, 1.25])

        let teaching = Style.make(HouseStyle(teaching: true))
        XCTAssertTrue(teaching.teaching)
        XCTAssertFalse(teaching.punchInsideSpans)
        XCTAssertNil(teaching.pushIn)
        XCTAssertEqual(Style.make(HouseStyle(endingRoom: false)).endingSeconds, 0)

        XCTAssertEqual(HouseStyle.decode(HouseStyle(style: .story, pace: .brisk, punchIns: .off).json()), HouseStyle(style: .story, pace: .brisk, punchIns: .off))
        XCTAssertEqual(HouseStyle.decode("not json"), .standard)
        XCTAssertNotEqual(HouseStyle.standard.signature, HouseStyle(pace: .brisk).signature)
    }

    func testAPunchInNeverPassesTheResolutionBudget() {
        // research 2.6: maxScale = min(style scale, 1.15 x sourceHeight / outputHeight).
        XCTAssertEqual(Style.maxScale(1.12, sourceHeight: 1080, outputHeight: 1080), 1.12, accuracy: 1e-9)
        XCTAssertEqual(Style.maxScale(1.25, sourceHeight: 1080, outputHeight: 1080), 1.15, accuracy: 1e-9)
        XCTAssertEqual(Style.maxScale(1.25, sourceHeight: 2160, outputHeight: 1080), 1.25, accuracy: 1e-9)
        // Energetic on a 1080p recording: 1.15 and 1.25 both become 1.15, so the rotation is the whole picture and 1.15.
        XCTAssertEqual(Style.base(.energetic).scales(sourceHeight: 1080, outputHeight: 1080), [1.0, 1.15])
        XCTAssertEqual(Style.base(.energetic).scales(sourceHeight: 2160, outputHeight: 1080), [1.0, 1.15, 1.25])
        XCTAssertEqual(Style.base(.clear).scales(sourceHeight: 1080, outputHeight: 1080), [1.0, 1.12])
    }

    // MARK: The visual plan, on a made-up ten-minute talk

    /// A made-up talk: a word every 0.4 s (0.3 s long), a full stop every 10th word, kept in spans of 20 to 60 words with one
    /// word taken out between spans (a jump cut), 1080p at 29.97. Nothing here is from a recording.
    static func syntheticPlan(minutes: Double = 10, spanWords: [Int] = [20, 45, 12, 60, 30]) -> (plan: EditPlan, words: [PlanWord]) {
        let frame = FrameDuration.ntsc30
        let count = Int(minutes * 60 / 0.4)
        let words = (0..<count).map { i in
            PlanWord(index: i, text: i % 10 == 9 ? "word." : "word", norm: "word", start: Double(i) * 0.4 + 0.2, end: Double(i) * 0.4 + 0.5,
                     sentence: i / 10, closes: i % 10 == 9 ? .sentence : .none)
        }
        func snap(_ t: Double) -> Double { (t / frame.seconds).rounded() * frame.seconds }
        var spans: [EditPlan.Span] = []
        var at = 0, n = 0
        while at < count - 1 {
            let length = min(spanWords[n % spanWords.count], count - at)
            let a = at, b = at + length - 1
            spans.append(.init(id: "k\(spans.count + 1)", source: "synthetic", from: words[a].id, to: words[b].id,
                               in: snap(words[a].start - 0.04), out: snap(words[b].end + 0.04), text: ""))
            at = b + 2
            n += 1
        }
        var plan = EditPlan(recording: "synthetic", transcriptSHA256: "", frameDuration: frame, style: "clear", madeAt: Date(timeIntervalSince1970: 0),
                            sourceDuration: Double(count) * 0.4 + 1, envelope: .init(floorDB: -60, speechDB: -20),
                            basis: .init(edits: EpisodeEdits(), peopleSignature: ""))
        plan.spans = spans
        plan.words = words.map { EditPlan.WordTime(id: $0.id, in: $0.start, out: $0.end) }
        return (plan, words)
    }

    /// A made-up face box, still, every half second: middle across, eyes at 0.31 of the frame's height.
    static func face(minutes: Double = 10, x: Double = 0.42) -> [FaceSpot] {
        stride(from: 0.0, through: minutes * 60 + 1, by: 0.5).map { FaceSpot(time: $0, box: FaceBox(x: x, y: 0.25, width: 0.16, height: 0.23)) }
    }

    static func visual(_ house: HouseStyle, face: [FaceSpot] = face(), height: Double = 1080, plan made: (EditPlan, [PlanWord]) = syntheticPlan()) -> EditPlan {
        var plan = made.0
        plan.visual = VisualPlan.make(.init(plan: plan, words: made.1, style: Style.make(house), subject: face, sourceHeight: height, outputHeight: 1080))
        return plan
    }

    func testClearPunchesInAlternatelyAtItsRateAndEndsWide() {
        let plan = Self.visual(.standard)
        let timeline = EditTimeline(plan: plan)
        let shots = VisualPlan.shots(plan, timeline: timeline)
        let count = VisualPlan.count(plan)
        print(String(format: "Clear, synthetic 10 min: %d changes, %.2f a minute, %d in the first 30 s, median shot %.1f s, %d punch-ins, %d push-ins, largest %.2f, %.2f s after the last word",
                     count.changes, count.perMinute, count.changesFirst30, count.medianShot, count.punchIns, count.pushIns, count.largestScale, count.afterLastWord))
        XCTAssertTrue((6...8).contains(count.perMinute), "6 to 8 visual changes a minute: \(count.perMinute)")
        XCTAssertGreaterThanOrEqual(count.changesFirst30, 10)
        XCTAssertLessThanOrEqual(count.largestScale, 1.15)
        XCTAssertGreaterThan(count.punchIns, 10)
        XCTAssertGreaterThanOrEqual(count.pushIns, 1)
        XCTAssertEqual(shots.last?.scale, 1, "the last shot is wide")
        var run = 0
        for (a, b) in zip(shots, shots.dropFirst()) {
            XCTAssertNotEqual(a.scale, b.scale, "never the same scale twice in a row (at \(b.start))")
            run = b.scale > 1 ? run + 1 : 0
            XCTAssertLessThanOrEqual(run, 3)
        }
        for shot in shots.dropLast() {
            XCTAssertGreaterThanOrEqual(Double(shot.frames) * plan.frameDuration.seconds, 1.5 - 0.001, "no shot under the shortest")
        }
        // Every punch-in frames the eyes on the upper third and never passes the picture's edge.
        for item in plan.visual where item.kind == EditPlan.Visual.punchIn {
            let rect = Framing.rect(scale: item.scale!, center: CGPoint(x: item.center![0], y: item.center![1]))
            let eye = 0.25 + VisualPlan.eyeInBox * 0.23
            XCTAssertEqual((eye - rect.minY) / rect.height, 1.0 / 3.0, accuracy: 0.04)
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertGreaterThanOrEqual(rect.minY, 0)
            XCTAssertLessThanOrEqual(rect.maxX, 1.0001)
            XCTAssertLessThanOrEqual(rect.maxY, 1.0001)
        }
        // Push-ins: at most one in any 90 s.
        let pushes = plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }.compactMap { $0.in.flatMap(timeline.editTime) }.sorted()
        for (a, b) in zip(pushes, pushes.dropFirst()) { XCTAssertGreaterThanOrEqual(b - a, 90 - 0.01) }
        // The ending: speech ends 5 s before the last frame (within a frame).
        XCTAssertEqual(count.afterLastWord, 5, accuracy: plan.frameDuration.seconds + 1e-6)
        XCTAssertEqual(timeline.holdFrames, Int64((count.holdSeconds / plan.frameDuration.seconds).rounded()))
        // The inspector's line under the plan's summary.
        let line = try? XCTUnwrap(plan.pictureSummary)
        print("Picture summary:", line ?? "none")
        XCTAssertEqual(line, String(format: "Picture, Clear: %d punch-ins and %d slow push-ins; the last frame is held %.1f s, so the speaking ends 5 s before the end.",
                                    count.punchIns, count.pushIns, count.holdSeconds))
        XCTAssertNil(Self.syntheticPlan().plan.pictureSummary, "a plan with no picture items says nothing")
    }

    func testEnergeticRotatesAndGoesBackToWideAndTeachingAndOffStayCalm() {
        // On a 4K source the full rotation: wide, 1.15, 1.25; at most 3 tight in a row, never the same twice.
        let energetic = Self.visual(HouseStyle(style: .energetic), height: 2160)
        let shots = VisualPlan.shots(energetic, timeline: EditTimeline(plan: energetic))
        XCTAssertEqual(Set(shots.map(\.scale)), [1.0, 1.15, 1.25])
        var run = 0
        for (a, b) in zip(shots, shots.dropFirst()) {
            XCTAssertNotEqual(a.scale, b.scale)
            run = b.scale > 1 ? run + 1 : 0
            XCTAssertLessThanOrEqual(run, 3)
        }
        let count = VisualPlan.count(energetic)
        print(String(format: "Energetic, synthetic: %.2f changes a minute, median shot %.1f s", count.perMinute, count.medianShot))
        XCTAssertTrue((12...15).contains(count.perMinute), "\(count.perMinute)")
        XCTAssertEqual(count.pushIns, 0)
        // On 1080p it never passes 1.15.
        XCTAssertLessThanOrEqual(VisualPlan.count(Self.visual(HouseStyle(style: .energetic))).largestScale, 1.15)

        // Teaching: punch-ins only at cuts, no push-in.
        let teaching = Self.visual(HouseStyle(teaching: true))
        let teachingShots = VisualPlan.shots(teaching, timeline: EditTimeline(plan: teaching))
        XCTAssertTrue(teachingShots.dropFirst().allSatisfy(\.atCut), "no change inside a span with Teaching")
        XCTAssertEqual(VisualPlan.count(teaching).pushIns, 0)

        // Punch-ins Off: nothing but the held ending.
        let off = Self.visual(HouseStyle(punchIns: .off))
        XCTAssertEqual(off.visual.map(\.kind), [EditPlan.Visual.hold])
        // No face seen: every shot wide, the ending still held.
        let faceless = Self.visual(.standard, face: [])
        XCTAssertEqual(faceless.visual.map(\.kind), [EditPlan.Visual.hold])
        // No room at the end asked for: nothing held.
        XCTAssertTrue(Self.visual(HouseStyle(endingRoom: false)).visual.allSatisfy { $0.kind != EditPlan.Visual.hold })
        // A face too near the edge to frame: wide rather than past the edge.
        XCTAssertEqual(VisualPlan.center(for: [FaceSpot(time: 0, box: FaceBox(x: 0.0, y: 0.01, width: 0.2, height: 0.25))], scale: 1.12), nil)
    }

    func testThePunchInsAreChosenTogetherAroundAShotThatCannotBeFramed() {
        // Six shots inside one span (no cuts), shot 2 has no face to frame: the shots around it still alternate where they
        // can, the last is wide, and nothing tight sits next to tight.
        let levels = VisualPlan.assign(count: 6, levels: 2, backToWideAfter: 3, allowed: { i, level in level == 0 || i != 2 },
                                       atCut: { _ in false }, keepAtCut: { _ in false })
        XCTAssertEqual(levels.last, 0)
        XCTAssertEqual(levels[2], 0)
        for (a, b) in zip(levels, levels.dropFirst()) { XCTAssertFalse(a == 1 && b == 1, "\(levels)") }
        XCTAssertEqual(zip(levels, levels.dropFirst()).filter { $0 != $1 }.count, 4, "every boundary but one changes: \(levels)")
        // Three levels with back to wide after 3: never four tight in a row.
        let three = VisualPlan.assign(count: 40, levels: 3, backToWideAfter: 3, allowed: { _, _ in true }, atCut: { _ in true }, keepAtCut: { _ in false })
        var run = 0
        for level in three { run = level == 0 ? 0 : run + 1; XCTAssertLessThanOrEqual(run, 3) }
        XCTAssertTrue(zip(three, three.dropFirst()).allSatisfy { $0 != $1 })
        // Calm: a cut that does not jump keeps the framing.
        let calm = VisualPlan.assign(count: 4, levels: 2, backToWideAfter: 3, allowed: { _, _ in true }, atCut: { _ in true }, keepAtCut: { $0 == 0 })
        XCTAssertEqual(calm[0], calm[1])
    }

    func testCalmChangesOnlyAtCutsThatJump() {
        // A still face: no cut jumps, so a cut keeps the shot's framing; a face that moves at every cut changes it.
        let still = Self.visual(HouseStyle(style: .calm))
        let stillShots = VisualPlan.shots(still, timeline: EditTimeline(plan: still))
        let cutsKept = zip(stillShots, stillShots.dropFirst()).filter { $1.atCut && $0.scale == $1.scale }.count
        XCTAssertGreaterThan(cutsKept, 0, "a cut that does not jump keeps the framing")
        XCTAssertTrue(VisualPlan.jumps([FaceSpot(time: 0, box: FaceBox(x: 0.4, y: 0.2, width: 0.1, height: 0.1))],
                                       [FaceSpot(time: 1, box: FaceBox(x: 0.45, y: 0.2, width: 0.1, height: 0.1))]))
        XCTAssertFalse(VisualPlan.jumps([FaceSpot(time: 0, box: FaceBox(x: 0.4, y: 0.2, width: 0.1, height: 0.1))],
                                        [FaceSpot(time: 1, box: FaceBox(x: 0.405, y: 0.2, width: 0.1, height: 0.1))]))
    }

    func testTheFramingEasesAPushInAndMapsAFaceBack() {
        XCTAssertEqual(Framing.ease(0), 0, accuracy: 1e-6)
        XCTAssertEqual(Framing.ease(1), 1, accuracy: 1e-6)
        XCTAssertEqual(Framing.ease(0.5), 0.5, accuracy: 1e-6)
        XCTAssertLessThan(Framing.ease(0.1), 0.1, "eases in")
        var last = 0.0
        for i in 1...100 {
            let y = Framing.ease(Double(i) / 100)
            XCTAssertGreaterThanOrEqual(y, last)
            last = y
        }
        let framing = Framing(segments: [.init(start: 100, frames: 300, rect: Framing.rect(scale: 1.05, center: CGPoint(x: 0.5, y: 0.45)),
                                               scale: 1.05, center: CGPoint(x: 0.5, y: 0.45), easeFrames: 120)])
        XCTAssertNil(framing.rect(atEditFrame: 99))
        XCTAssertEqual(framing.rect(atEditFrame: 100)?.width ?? 0, 1, accuracy: 1e-9, "a push-in starts from the whole picture")
        XCTAssertEqual(framing.rect(atEditFrame: 220)?.width ?? 0, 1 / 1.05, accuracy: 1e-9, "and ends at its scale")
        XCTAssertEqual(framing.rect(atEditFrame: 399)?.width ?? 0, 1 / 1.05, accuracy: 1e-9)
        XCTAssertNil(framing.rect(atEditFrame: 400))
        // A face found in a punched-in frame goes back on the original's picture.
        let rect = CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.8)
        let back = Framing.toSource(FaceBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1), through: rect)
        XCTAssertEqual(back.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(back.y, 0.45, accuracy: 1e-9)
        XCTAssertEqual(back.width, 0.08, accuracy: 1e-9)
    }

    func testTheTimelineHoldsTheLastFrame() {
        let frame = FrameDuration.ntsc30
        let timeline = EditTimeline(frame: frame, pieces: [.init(id: "k1", sourceFrame: 10, frames: 100, editFrame: 0)], holdFrames: 150)
        XCTAssertEqual(timeline.totalFrames, 250)
        XCTAssertEqual(timeline.keptFrames, 100)
        XCTAssertEqual(timeline.holdSourceFrame, 109)
        XCTAssertEqual(timeline.originalTime(200 * frame.seconds)!, 109 * frame.seconds, accuracy: 1e-9, "the hold shows the last kept frame")
        XCTAssertEqual(timeline.audioPieces.reduce(0) { $0 + $1.samples } + (timeline.totalSamples - timeline.sample(atFrame: 100)), timeline.totalSamples)
    }

    // MARK: The picture, made (test pattern)

    /// The test pattern planned with a made-up face box (Clear), made into a video, and its frames compared with the original's
    /// own frames framed independently (Core Graphics, not the compositor): a punch-in shows exactly the planned part of the
    /// picture, the held ending shows the last kept frame without sound, and the Viewer's composition equals the file.
    func testThePunchInsAreDrawnAsPlannedAndTheEndingIsHeld() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "style-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let ffmpegURL = ToolPaths.standard.ffmpeg
        var planSetup = PlanStep.Setup(original: original, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                       jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory), duration: 30, frameRate: 29.97)
        planSetup.subject = Self.face(minutes: 1, x: 0.30)
        planSetup.pictureHeight = 1080
        let plan = try await PlanStep.run(planSetup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpegURL, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan
        let punches = plan.visual.filter { $0.kind == EditPlan.Visual.punchIn }
        XCTAssertFalse(punches.isEmpty, "the plan punches in: \(plan.visual)")
        XCTAssertGreaterThan(plan.holdSeconds, 0)
        XCTAssertEqual(plan.basis.house, HouseStyle.standard.signature)

        let setup = VideoStep.Setup(original: original, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: Date(timeIntervalSince1970: 1_789_000_000),
                                    label: "Test pattern", people: RenderTests.everyoneIncluded())
        let made = try await VideoStep.make(setup, ffmpeg: RenderTests.ffmpeg())
        let record = try await VideoStep.check(made, setup: setup, ffprobe: RenderTests.ffprobe(), ffmpeg: RenderTests.ffmpeg(), now: Date())
        XCTAssertEqual(record.checklist.filter { $0.status == .fail }.map(\.text), [])
        let timeline = made.timeline
        XCTAssertEqual(made.frames, Int(timeline.totalFrames))
        XCTAssertEqual(record.duration, timeline.duration, accuracy: timeline.frame.seconds + 0.001, "the file is the kept spans plus the hold")
        let mp4 = staging.appending(path: VideoStep.folderName).appending(path: record.fileName)

        let source = AVURLAsset(url: original), output = AVURLAsset(url: mp4)
        let framing = Framing(plan: plan, timeline: timeline)
        let out = await MainActor.run { SnapshotRenderer.milestoneFolder() }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for (n, segment) in framing.segments.prefix(3).enumerated() {
            let editFrame = segment.start + segment.frames / 2
            guard let piece = timeline.pieces.first(where: { editFrame >= $0.editFrame && editFrame < $0.editFrame + $0.frames }) else { continue }
            let sourceFrame = piece.sourceFrame + editFrame - piece.editFrame
            let madeFrame = try await RenderTests.frame(output, at: timeline.time(editFrame))
            let sourceImage = try await Self.image(source, at: timeline.time(sourceFrame))
            let expected = Self.picture(Self.cropped(sourceImage, to: segment.rect))
            let whole = Self.picture(sourceImage)
            let right = RenderTests.psnr(madeFrame, expected), wrong = RenderTests.psnr(madeFrame, whole)
            print(String(format: "Punch-in %d at edited frame %lld, scale %.2f: %.1f dB against the original framed by Core Graphics, %.1f dB against the whole picture",
                         n + 1, editFrame, segment.scale, right, wrong))
            XCTAssertGreaterThanOrEqual(right, 30, "the made frame is the planned part of the picture")
            XCTAssertLessThan(wrong, right - 5, "and not the whole picture")
            if n == 0 {
                try Self.writePNG(Self.cgImage(madeFrame), to: out.appending(path: "m9a-punch-in-test-pattern-made.png"))
                try Self.writePNG(Self.outlined(sourceImage, rect: segment.rect), to: out.appending(path: "m9a-punch-in-test-pattern-original-with-framing.png"))
            }
        }
        // The hold: its frames are the last kept frame, and its sound is silent.
        let lastKept = try await RenderTests.frame(output, at: timeline.time(timeline.keptFrames - 1))
        let inHold = try await RenderTests.frame(output, at: timeline.time(timeline.totalFrames - 10))
        XCTAssertGreaterThanOrEqual(RenderTests.psnr(lastKept, inHold), 38, "the held frames are the last kept frame")
        let tail = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-nostats", "-ss", String(format: "%.3f", timeline.duration - 3), "-i", mp4.path,
                                                                        "-af", "volumedetect", "-vn", "-f", "null", "-"], timeout: .seconds(60)).stderr
        let maxVolume = tail.components(separatedBy: "\n").first { $0.contains("max_volume") } ?? ""
        print("The last 3 s of sound:", maxVolume)
        XCTAssertTrue(maxVolume.contains("-inf") || (Double(maxVolume.split(separator: " ").dropLast().last ?? "0") ?? 0) <= -80, maxVolume)

        // The Viewer's composition draws the punch-ins as the file has them (preview equals output).
        let built = try await CompositionBuilder.build(plan: plan, original: original)
        let compared = try await PreviewCheck.compare(played: .init(asset: built.composition, videoComposition: built.videoComposition), mp4: mp4,
                                                      timeline: built.timeline, count: 6)
        for c in compared { print(String(format: "Preview against file at %.2f s: %.1f dB", c.edited, c.psnr)) }
        XCTAssertTrue(compared.allSatisfy { $0.psnr >= 38 }, "\(compared.map(\.psnr))")
    }

    // MARK: Pictures

    static func image(_ asset: AVAsset, at time: CMTime) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: time).image
    }

    /// The part of `image` at `rect` (from the top left, fractions), scaled back to the image's size by Core Graphics.
    static func cropped(_ image: CGImage, to rect: CGRect) -> CGImage {
        let w = image.width, h = image.height
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        let scale = 1 / rect.width
        // Core Graphics' origin is the bottom left: draw the whole image scaled so that `rect` fills the context.
        let drawn = CGRect(x: -rect.minX * Double(w) * scale, y: -(1 - rect.maxY) * Double(h) * scale, width: Double(w) * scale, height: Double(h) * scale)
        context.draw(image, in: drawn)
        return context.makeImage()!
    }

    /// The whole picture with the framed part outlined, to look at.
    static func outlined(_ image: CGImage, rect: CGRect) -> CGImage {
        let w = image.width, h = image.height
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.setLineWidth(6)
        context.stroke(CGRect(x: rect.minX * Double(w), y: (1 - rect.maxY) * Double(h), width: rect.width * Double(w), height: rect.height * Double(h)))
        let third = (1 - rect.minY - rect.height / 3) * Double(h)
        context.setLineDash(phase: 0, lengths: [20, 14])
        context.stroke(CGRect(x: rect.minX * Double(w), y: third, width: rect.width * Double(w), height: 0))
        return context.makeImage()!
    }

    static func picture(_ image: CGImage) -> RenderTests.Picture {
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return RenderTests.Picture(width: width, height: height, rgba: rgba)
    }

    static func cgImage(_ picture: RenderTests.Picture) -> CGImage {
        var data = picture.rgba
        let context = CGContext(data: &data, width: picture.width, height: picture.height, bitsPerComponent: 8, bytesPerRow: picture.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    // MARK: Direction (v2 part M9c): the rules table, the model's reading, the People sentence, the knapsack, the beats

    /// Every row of the rules table, by a phrase it must read, and what it must set (PLAN M9 check 1).
    func testEveryRulesTablePhraseMapsToItsFields() {
        let cases: [(String, (DirectionFields) -> Bool)] = [
            ("Under 10 minutes.", { $0.targetSeconds == 600 }),
            ("less than twelve minutes", { $0.targetSeconds == 720 }),
            ("about 3 minutes", { $0.targetSeconds == 180 }),
            ("a 5-minute version", { $0.targetSeconds == 300 }),
            ("under 45 seconds", { $0.targetSeconds == 45 }),
            ("just the highlights", { $0.targetSeconds == 180 }),
            ("more frequent cuts", { $0.cutDensity == 1 }),
            ("faster cuts", { $0.cutDensity == 1 && $0.pace == 0 }),
            ("fewer cuts", { $0.cutDensity == -1 }),
            ("no zooms", { $0.punchIns == .off }),
            ("more zooms", { $0.punchIns == .punchy }),
            ("softer zooms", { $0.punchIns == .subtle && $0.style == nil }),
            ("no text on screen", { $0.text == .off }),
            ("fewer words on screen", { $0.text == .subtle }),
            ("more text", { $0.text == .bold }),
            ("add captions", { $0.captionsBurned == true }),
            ("no captions", { $0.captionsBurned == false }),
            ("start with the strongest line", { $0.hook == true }),
            ("no teaser", { $0.hook == false }),
            ("More energetic.", { $0.style == .energetic }),
            ("calmer", { $0.style == .calm }),
            ("like a documentary", { $0.style == .story }),
            ("back to the house style", { $0.style == .clear }),
            ("Faster.", { $0.pace == 1 }),
            ("tighter", { $0.pace == 1 }),
            ("let it breathe", { $0.pace == -1 }),
            ("slower", { $0.pace == -1 }),
            ("Take out the story about the car.", { $0.avoidTopics == ["car"] }),
            ("Keep the breathing practice whole", { $0.keepWhole == ["breathing practice"] }),
            ("Focus on the parts that are motivating or enlightening.", { $0.focus == ["motivating": 1.5, "enlightening": 1.5] && $0.focusTopics.isEmpty }),
            ("practical tips", { $0.focus["practical"] == 1.5 }),
            ("something funny", { $0.focus["humor"] == 1.5 }),
            ("the philosophy", { $0.focus["philosophy"] == 1.5 }),
            ("technique", { $0.focus["technique"] == 1.5 }),
            ("personal", { $0.focus["personal"] == 1.5 }),
            ("the stories", { $0.focus["story"] == 1.5 }),
            ("focus on the first retreat", { $0.focusTopics == ["first retreat"] }),
        ]
        for (phrase, expected) in cases {
            let read = DirectionRules.read(phrase)
            XCTAssertTrue(expected(read.fields), "\"\(phrase)\" read as \(read.fields)")
            XCTAssertTrue(read.unread.isEmpty, "\"\(phrase)\" is read by the rules, so no model is asked: unread \(read.unread)")
        }
        // The example directions from research 3.2 and Help 08, whole.
        let energetic = DirectionRules.read("More energetic. Faster, more frequent cuts.")
        XCTAssertEqual(energetic.fields.style, .energetic)
        XCTAssertEqual(energetic.fields.pace, 1)
        XCTAssertEqual(energetic.fields.cutDensity, 1)
        XCTAssertTrue(energetic.unread.isEmpty)
        let focus = DirectionRules.read("Focus on the parts that are motivating or enlightening. Under 10 minutes.")
        XCTAssertEqual(focus.fields.targetSeconds, 600)
        XCTAssertEqual(Set(focus.fields.focus.keys), ["motivating", "enlightening"])
        XCTAssertTrue(focus.unread.isEmpty)
        // What no rule reads goes to the model, whole clause by whole clause.
        let other = DirectionRules.read("Make it feel like a sunrise over the ocean.")
        XCTAssertEqual(other.unread, ["Make it feel like a sunrise over the ocean"])
        XCTAssertTrue(other.fields.isEmpty)
        // Presets are fixed fields; opposites switch each other off.
        var direction = RecordingDirection()
        direction.toggle(.energetic)
        direction.toggle(.calm)
        XCTAssertEqual(direction.presets, [.calm], "Calm switches Energetic off")
        direction.toggle(.fasterCuts)
        direction.toggle(.fewerCuts)
        XCTAssertEqual(direction.presets, [.calm, .fewerCuts])
        XCTAssertEqual(Direction.read(direction, house: .standard).fields.cutDensity, -1)
    }

    /// The chips read back what a direction set, and removing one clears exactly that (PLAN M9 check 3's chips).
    func testTheChipsReadBackAndCanBeRemoved() {
        var direction = RecordingDirection(prompt: "More energetic. Faster, more frequent cuts.")
        let reading = Direction.read(direction, house: .standard)
        let texts = reading.chips.map(\.text)
        print("Chips:", texts)
        XCTAssertTrue(texts.contains("Style: Energetic"))
        XCTAssertTrue(texts.contains { $0.hasPrefix("Pace: faster") }, "\(texts)")
        XCTAssertTrue(texts.contains("Cuts: more frequent"))
        XCTAssertEqual(texts.first { $0.hasPrefix("Pace") }, "Pace: faster (pauses between sentences kept to 0.17 s)")
        direction.removed = ["style"]
        let without = Direction.read(direction, house: .standard)
        XCTAssertNil(without.fields.style)
        XCTAssertFalse(without.chips.contains { $0.id == "style" })
        XCTAssertEqual(without.fields.pace, 1, "only the removed chip is cleared")
        // The style a direction makes: Energetic's own numbers, pauses 0.85 times as long a pace step, the changes aimed high in
        // its own range and never outside it.
        let style = Direction.style(.standard, fields: reading.fields, pace: nil)
        XCTAssertEqual(style.name, .energetic)
        XCTAssertEqual(style.insideTarget, 0.10 * 0.85, accuracy: 1e-9)
        XCTAssertEqual(style.sentenceTarget, 0.20 * 0.85, accuracy: 1e-9)
        XCTAssertEqual(style.insideTrigger, 0.25, accuracy: 1e-9, "a pace step never changes which pauses are cut")
        XCTAssertEqual(style.changesPerMinute, 12...15)
        XCTAssertEqual(style.changeAim, 0.9, accuracy: 1e-9)
        XCTAssertEqual(Direction.style(.standard, fields: DirectionFields(), pace: nil), Style.make(.standard), "no direction is the House Style exactly")
        // Not-built fields are said, never promised.
        let captions = Direction.read(RecordingDirection(prompt: "Add captions."), house: .standard)
        XCTAssertTrue(captions.said.contains(Direction.captionsNotBuilt))
        // A Text Off direction takes the title and the name away.
        let off = Direction.house(.standard, fields: DirectionRules.read("no text on screen").fields, pace: nil)
        XCTAssertFalse(off.titleOnScreen)
        XCTAssertFalse(off.namesOnScreen)
    }

    /// "Show the students" changes nothing and returns the People sentence; so does anything about faces, consent or publishing.
    func testWhoAppearsIsNeverADirection() {
        for phrase in ["Show the students.", "Blur the student in the back", "include everyone", "Remove the person on the left", "consent"] {
            let read = DirectionRules.read(phrase)
            XCTAssertTrue(read.fields.isEmpty, "\"\(phrase)\" changes nothing: \(read.fields)")
            XCTAssertEqual(read.said, [Direction.peopleSentence], "\"\(phrase)\"")
            XCTAssertTrue(read.unread.isEmpty, "\"\(phrase)\" is never sent to a model")
            XCTAssertTrue(Direction.read(RecordingDirection(prompt: phrase), house: .standard).chips.isEmpty)
        }
        let publish = DirectionRules.read("Then publish it to YouTube.")
        XCTAssertTrue(publish.fields.isEmpty)
        XCTAssertEqual(publish.said, [Direction.publishingSentence])
        // The rest of a direction still counts.
        let mixed = DirectionRules.read("Calmer, but show the students.")
        XCTAssertEqual(mixed.fields.style, .calm)
        XCTAssertEqual(mixed.said, [Direction.peopleSentence])
    }

    /// The model's reading may only use the vocabulary: one field outside it and the whole reading is refused.
    func testTheModelsReadingIsRefusedOutsideTheVocabulary() throws {
        let good = try DirectionModelCheck.check(#"{"style": "calm", "pace": -1, "focus": {"story": 2, "the first retreat": 1}, "avoid": ["humor", "the car"], "targetSeconds": 720}"#)
        XCTAssertEqual(good.style, .calm)
        XCTAssertEqual(good.pace, -1)
        XCTAssertEqual(good.focus, ["story": 2])
        XCTAssertEqual(good.focusTopics, ["the first retreat"])
        XCTAssertEqual(good.avoid, ["humor"])
        XCTAssertEqual(good.avoidTopics, ["the car"])
        XCTAssertEqual(good.targetSeconds, 720)
        XCTAssertTrue(try DirectionModelCheck.check("{}").isEmpty)
        for refused in [#"{"style": "calm", "people": {"student 1": "include"}}"#, #"{"blur": true}"#, #"{"publish": "youtube"}"#,
                        #"{"style": "loud"}"#, #"{"pace": 5}"#, #"{"pace": 0.5}"#, #"{"focus": {"motivating": 9}}"#, #"{"targetSeconds": 3}"#, "not json"] {
            XCTAssertThrowsError(try DirectionModelCheck.check(refused), "refused: \(refused)")
        }
        // A refused reading changes nothing: the direction reads as its rules alone.
        let alone = Direction.read(RecordingDirection(prompt: "calmer, with a sunrise feeling"), house: .standard)
        XCTAssertEqual(alone.fields.style, .calm)
        XCTAssertNil(alone.byModel)
        // A reading given for other words is not used.
        let stale = Direction.read(RecordingDirection(prompt: "with a sunrise feeling"), house: .standard,
                                   model: (DirectionFields(style: .story), "scripted", "something else"))
        XCTAssertNil(stale.fields.style)
        let fresh = Direction.read(RecordingDirection(prompt: "with a sunrise feeling"), house: .standard,
                                   model: (DirectionFields(style: .story), "scripted", "with a sunrise feeling"))
        XCTAssertEqual(fresh.fields.style, .story)
        XCTAssertEqual(fresh.modelBy, "scripted")
    }

    /// Synthetic beats for the knapsack: ids b1..., each `seconds` long, with scores and links.
    static func beat(_ n: Int, _ seconds: Double, at start: Double, scores: [BeatTag: Int] = [:], kind: BeatKind = .teaching,
                     depends: [Int] = [], thesis: Bool = false) -> Beat {
        Beat(id: "b\(n)", firstSentence: "s\(n)", lastSentence: "s\(n)", from: "w\(n)", to: "w\(n)", start: start, end: start + seconds,
             summary: "part \(n)", scores: Dictionary(uniqueKeysWithValues: BeatTag.allCases.map { ($0.rawValue, scores[$0] ?? 0) }), kind: kind,
             standsAlone: depends.isEmpty, dependsOn: depends.map { "b\($0)" }, keyLine: nil, hookCandidate: false, terms: [], thesis: thesis)
    }

    /// The knapsack keeps the length, honours every dependency, keeps the thesis and the close, never reorders, and puts the
    /// focused tags first (PLAN M9 check 1), on hand-made beats and then on 300 random sets.
    func testTheKnapsackHonoursDependenciesAndTheLength() {
        let beats = [
            Self.beat(1, 40, at: 0, kind: .welcome),
            Self.beat(2, 60, at: 40, scores: [.practical: 1]),
            Self.beat(3, 90, at: 100, scores: [.enlightening: 3, .philosophy: 2], thesis: true),
            Self.beat(4, 80, at: 190, scores: [.motivating: 3], depends: [3]),
            Self.beat(5, 120, at: 270, scores: [.story: 3, .personal: 2]),
            Self.beat(6, 70, at: 390, scores: [.motivating: 2, .enlightening: 1], depends: [5]),
            { var b = Self.beat(7, 50, at: 460, scores: [.humor: 2]); b.terms = ["kapalabhati"]; return b }(),
            Self.beat(8, 30, at: 510, scores: [.motivating: 1], kind: .closing),
        ]
        var fields = DirectionFields()
        fields.focus = ["motivating": 1.5, "enlightening": 1.5]
        let budget = 300.0
        let out = Selection.choose(.init(beats: beats, keptSeconds: [:], budget: budget, fields: fields))
        print("Knapsack, focus motivating and enlightening under 300 s:", out)
        XCTAssertLessThanOrEqual(out.keptSeconds, budget)
        XCTAssertTrue(out.kept.contains("b3"), "the thesis")
        XCTAssertTrue(out.kept.contains("b8"), "the close")
        XCTAssertTrue(out.kept.contains("b4"), "the most motivating part fits and is kept")
        XCTAssertEqual(out.kept, out.kept.sorted { Int($0.dropFirst())! < Int($1.dropFirst())! }, "order kept")
        if out.kept.contains("b6") { XCTAssertTrue(out.kept.contains("b5"), "b6 depends on b5") }
        let byID = Dictionary(uniqueKeysWithValues: beats.map { ($0.id, $0) })
        func focusMean(_ ids: [String]) -> Double {
            ids.isEmpty ? 0 : ids.map { Double(byID[$0]!.score(.motivating) + byID[$0]!.score(.enlightening)) }.reduce(0, +) / Double(ids.count)
        }
        XCTAssertGreaterThan(focusMean(out.kept), focusMean(out.dropped))
        // Avoid and keep whole.
        var avoid = DirectionFields()
        avoid.avoidTopics = ["kapalabhati"]
        avoid.targetSeconds = 1_000
        XCTAssertFalse(Selection.choose(.init(beats: beats, keptSeconds: [:], budget: 1_000, fields: avoid)).kept.contains("b7"))
        var whole = fields
        whole.keepWhole = ["part 5"]
        let kept = Selection.choose(.init(beats: beats, keptSeconds: [:], budget: 400, fields: whole))
        XCTAssertTrue(kept.kept.contains("b5"))
        // No length: everything but housekeeping and what scored nothing.
        let none = Selection.choose(.init(beats: beats, keptSeconds: [:], budget: nil, fields: fields))
        XCTAssertFalse(none.kept.contains("b1"), "the welcome scored nothing")
        XCTAssertTrue(none.kept.contains("b3") && none.kept.contains("b8"))
        // Too short for what must stay: the must-keeps only, said as over the length.
        let tight = Selection.choose(.init(beats: beats, keptSeconds: [:], budget: 60, fields: fields))
        XCTAssertEqual(Set(tight.kept), ["b3", "b8"])
        XCTAssertTrue(tight.overBudget)

        // 300 random sets: the length and every dependency, always.
        var seed: UInt64 = 1309
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return seed >> 33 }
        for trial in 0..<300 {
            let n = 4 + Int(next() % 30)
            var start = 0.0
            var made: [Beat] = []
            for i in 1...n {
                let length = 20 + Double(next() % 160)
                var scores: [BeatTag: Int] = [:]
                for tag in BeatTag.allCases { scores[tag] = Int(next() % 4) }
                let depends = i > 1 && next() % 3 == 0 ? [1 + Int(next() % UInt64(i - 1))] : []
                made.append(Self.beat(i, length, at: start, scores: scores, kind: i == n ? .closing : .teaching, depends: depends, thesis: i == 1 + n / 2))
                start += length
            }
            let total = made.reduce(0) { $0 + $1.seconds }
            let target = (0.2 + Double(next() % 70) / 100) * total
            let result = Selection.choose(.init(beats: made, keptSeconds: [:], budget: target, fields: fields))
            let keptSet = Set(result.kept)
            if !result.overBudget { XCTAssertLessThanOrEqual(result.keptSeconds, target + 1e-6, "trial \(trial)") }
            for b in made where keptSet.contains(b.id) {
                for d in b.dependsOn { XCTAssertTrue(keptSet.contains(d), "trial \(trial): \(b.id) needs \(d)") }
            }
            XCTAssertTrue(keptSet.contains("b\(n)") && keptSet.contains("b\(1 + n / 2)"), "trial \(trial): thesis and close")
        }
    }

    /// The beats as the model answers them: a gap joins the beat before, an overlap is refused, a key line is found word for
    /// word or left out, a link forward is dropped, scores are held to 0 to 3, exactly one thesis.
    func testTheBeatsAreCheckedAgainstTheWords() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Prakriti/Dev/Fixtures/synthetic-transcript.json"))
        let words = try XCTUnwrap(PlanWords.from(json: data)).words
        let sentences = BeatSentence.from(words)
        XCTAssertGreaterThan(sentences.count, 20)
        let line = sentences[3].text.split(separator: " ").prefix(6).joined(separator: " ")
        let answer = """
            {"beats": [{"id": "b1", "first": "s1", "last": "s3", "summary": "Why we come back", "scores": {"motivating": 2, "enlightening": 4.0}, "kind": "welcome",
              "dependsOn": ["b2"], "keyLine": "words nobody said here", "thesis": false},
             {"id": "b2", "first": "s4", "last": "s10", "summary": "The practice lives in ordinary days", "scores": {"enlightening": 3}, "kind": "teaching",
              "dependsOn": ["b1"], "keyLine": "\(line.lowercased())", "hookCandidate": true, "thesis": true, "terms": ["abhyasa"]},
             {"id": "b3", "first": "s12", "last": "s\(sentences.count)", "summary": "Close", "scores": {}, "kind": "ending", "thesis": true}]}
            """
        let checked = try BeatCheck.check(answer, words: words)
        print("Beat check notes:", checked.notes)
        XCTAssertEqual(checked.beats.map(\.id), ["b1", "b2", "b3"])
        XCTAssertEqual(checked.beats[1].lastSentence, "s11", "the sentence no beat held joins the beat before")
        XCTAssertNil(checked.beats[0].keyLine, "a key line not found word for word is left out")
        XCTAssertEqual(checked.beats[1].keyLine.map { PlanWords.comparable($0.text) }, PlanWords.comparable(line), "found word for word, case aside")
        XCTAssertEqual(checked.beats[0].dependsOn, [], "a link forward is dropped")
        XCTAssertEqual(checked.beats[1].dependsOn, ["b1"])
        XCTAssertEqual(checked.beats[0].score(.enlightening), 3, "held to 3")
        XCTAssertEqual(checked.beats[2].kind, .teaching, "an unknown kind reads as teaching")
        XCTAssertEqual(checked.beats.filter(\.thesis).map(\.id), ["b2"], "exactly one thesis")
        XCTAssertEqual(checked.beats.first?.from, "w0")
        XCTAssertEqual(checked.beats.last?.to, words.last?.id)
        XCTAssertThrowsError(try BeatCheck.check(#"{"beats": [{"first": "s1", "last": "s5"}, {"first": "s4", "last": "s9"}]}"#, words: words), "an overlap is refused")
        XCTAssertThrowsError(try BeatCheck.check(#"{"beats": [{"first": "s1", "last": "s9999"}]}"#, words: words), "a sentence that does not exist")
        XCTAssertThrowsError(try BeatCheck.check("Here are the beats.", words: words))
    }

    /// The beats request asks LM Studio for temperature 0 and the fixed seed; writing keeps its own sampling.
    func testThePlanningRequestIsDeterministic() {
        let client = LMStudioClient(address: "http://localhost:1235/v1", model: "qwen/qwen3.8-27b")
        let words = [PlanWord(index: 0, text: "Hello.", norm: "hello", start: 0, end: 0.5, sentence: 0, closes: .sentence)]
        let beats = client.body(for: Planner.beatsRequest(words, kind: .talk, duration: 1))
        XCTAssertEqual(beats["temperature"] as? Double, 0)
        XCTAssertEqual(beats["seed"] as? Int, ModelSettings.seed)
        let writing = client.body(for: ModelRequest(system: "s", user: "u", shape: .writing))
        XCTAssertEqual(writing["temperature"] as? Double, ModelSettings.temperature)
        XCTAssertNil(writing["seed"])
        XCTAssertEqual(AnthropicClient.effort(for: .planning), "medium")
    }

    /// The beats change the picture (v2 part M9c): wide at every new beat, and a push-in on a key line first.
    func testTheBeatsSendThePictureBackToWideAndPushInOnAKeyLine() {
        let made = Self.syntheticPlan()
        var plan = made.plan
        let starts = [62.2, 151.0, 300.2, 420.6]
        // A key line in the middle of a long wide shot that the plan without key lines did not push in on.
        var plain = plan
        plain.visual = VisualPlan.make(.init(plan: plain, words: made.words, style: Style.make(.standard), subject: Self.face(), sourceHeight: 1080, outputHeight: 1080,
                                             beatStarts: starts))
        let plainTimeline = EditTimeline(plan: plain)
        let fs0 = plain.frameDuration.seconds
        let pushedBefore = plain.visual.filter { $0.kind == EditPlan.Visual.pushIn }.compactMap(\.in)
        let candidate = VisualPlan.shots(plain, timeline: plainTimeline).dropLast().first { shot in
            let a = Double(shot.sourceFrame) * fs0
            return shot.scale == 1 && Double(shot.frames) * fs0 >= 6 && !pushedBefore.contains { abs($0 - a) < 0.5 } && a > 120
        }
        let shot = try? XCTUnwrap(candidate, "a long wide shot with no push-in")
        let keyLine = shot.map { Double($0.sourceFrame) * fs0 + Double($0.frames) * fs0 / 2 } ?? 200.2
        plan.visual = VisualPlan.make(.init(plan: plan, words: made.words, style: Style.make(.standard), subject: Self.face(), sourceHeight: 1080, outputHeight: 1080,
                                            beatStarts: starts, keyLines: [keyLine]))
        let timeline = EditTimeline(plan: plan)
        let fs = plan.frameDuration.seconds
        for shot in VisualPlan.shots(plan, timeline: timeline) {
            let a = Double(shot.sourceFrame) * fs, b = a + Double(shot.frames) * fs
            if starts.contains(where: { $0 >= a - 0.6 && $0 < min(b, a + 2) }) {
                XCTAssertEqual(shot.scale, 1, "wide at a new beat (\(a) s)")
            }
        }
        let pushes = plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }
        XCTAssertTrue(pushes.contains { ($0.in ?? 0) <= keyLine && ($0.out ?? 0) > keyLine }, "a push-in holds the key line at \(keyLine): \(pushes.map { ($0.in ?? 0, $0.out ?? 0) })")
    }

    /// A plan with a direction, on the test pattern and the ums fixture: the rules read it, the beats come from a scripted planning
    /// model once, a part the direction leaves out is cut and said, the plan's lines are there, and planning again with only the
    /// pace changed asks the model nothing (PLAN M9 check 3's pace-only half, measured in StyleAcceptanceTests on the real talk).
    func testADirectedPlanChoosesBeatsAndAsksTheModelOnce() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "direction-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await RenderTests.syntheticOriginal(in: scratch)
        let folder = scratch.appending(path: "pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: folder.appending(path: TranscriptFiles.asHeard))
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: RenderTests.transcript))).words
        let sentences = BeatSentence.from(words)
        XCTAssertGreaterThanOrEqual(sentences.count, 3)
        let last = sentences.count
        let answer = """
            {"beats": [{"first": "s1", "last": "s1", "summary": "Getting set up", "scores": {}, "kind": "housekeeping"},
             {"first": "s2", "last": "s\(last - 1)", "summary": "The main point", "scores": {"motivating": 3, "enlightening": 2}, "kind": "teaching", "thesis": true},
             {"first": "s\(last)", "last": "s\(last)", "summary": "The close", "scores": {"motivating": 1}, "kind": "closing"}]}
            """
        let scripted = ScriptedClient(.lmStudio, replies: [.success(answer)])
        var setup = WritingSetup()
        setup.providers = [.planning: .lmStudio]
        setup.makeClient = { _, _ in scripted }
        var options = PipelineOptions()
        options.direction = RecordingDirection(prompt: "Focus on the motivating parts.")
        options.planning = setup
        options.planFolder = folder
        func plan(_ options: PipelineOptions) async throws -> EditPlan {
            let staging = scratch.appending(path: ".planning \(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
            let outcome = try await Pipeline(options: options, log: nil).planTheEdit(file: original, staging: staging, duration: 30, capture: nil, namesSaid: nil,
                                                                                       faces: nil, voices: nil)
            // As Plan the Edit does: the plan and the beats into the recording's folder.
            for name in [EditPlan.fileName, BeatsFile.fileName] where FileManager.default.fileExists(atPath: staging.appending(path: name).path) {
                try? FileManager.default.removeItem(at: folder.appending(path: name))
                try FileManager.default.moveItem(at: staging.appending(path: name), to: folder.appending(path: name))
            }
            return outcome.plan
        }
        let first = try await plan(options)
        XCTAssertEqual(scripted.requests.count, 1, "the beats are asked for once")
        XCTAssertEqual(scripted.requests.first?.deterministic, true)
        XCTAssertEqual(first.beatChoice?.dropped, ["b1"], "the housekeeping part is left out")
        XCTAssertEqual(first.count(.beat), 1)
        XCTAssertTrue(first.removed.contains { $0.kind == .beat && $0.say.contains("Getting set up") }, "\(first.removed.map(\.say))")
        XCTAssertFalse(first.spans.contains { PlanWord.index(of: $0.from)! <= sentences[0].last }, "no word of the part left out is kept")
        XCTAssertEqual(first.direction?.chips, ["Focus: motivating"])
        XCTAssertEqual(first.basis.direction, options.direction.signature)
        let lines = try XCTUnwrap(first.planLines)
        print("Plan lines:", lines)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Keeps 2 of 3 parts of the talk") }, "\(lines)")
        XCTAssertTrue(lines.last?.hasPrefix("Ends at ") == true)
        XCTAssertNotNil(BeatsFile.cached(in: folder, transcriptSHA256: first.transcriptSHA256))
        // A pace-only change: the beats are read from beats.json, nothing is asked.
        options.direction.pace = .brisk
        let started = Date()
        let second = try await plan(options)
        XCTAssertEqual(scripted.requests.count, 1, "a pace-only change asks the model nothing")
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
        XCTAssertEqual(second.beatChoice?.dropped, ["b1"])
        XCTAssertEqual(second.modifiers.pace, Pace.brisk.rawValue)
        // Words no rule reads are read by the model once, then reused from the last plan.
        let reader = ScriptedClient(.lmStudio, replies: [.success(#"{"style": "story"}"#)])
        options.planning?.makeClient = { _, _ in reader }
        options.direction.prompt = "Focus on the motivating parts. Make it feel like a sunrise."
        let third = try await plan(options)
        XCTAssertEqual(reader.requests.count, 1)
        XCTAssertEqual(third.style, "story")
        XCTAssertEqual(third.direction?.reading?.modelReadFor, "Make it feel like a sunrise")
        _ = try await plan(options)
        XCTAssertEqual(reader.requests.count, 1, "the same words are never read twice")
        // People in a direction change nothing.
        options.direction = RecordingDirection(prompt: "Show the students.")
        let people = try await plan(options)
        XCTAssertEqual(people.direction?.reading?.said, [Direction.peopleSentence])
        XCTAssertNil(people.beatChoice)
    }

    /// The planning task under the privacy lock: a cloud choice is planned by LM Studio when someone is left out.
    @MainActor
    func testPlanningFollowsThePrivacyLock() {
        var setup = WritingSetup()
        setup.providers = [.planning: .claudeAPI]
        var free = LockSubject(people: PeopleFacts(checked: true))
        free.people.leftOut = 0
        XCTAssertEqual(Planner(setup: setup, log: nil, subject: free, fileName: "x").route.provider, .claudeAPI)
        var locked = free
        locked.people.leftOut = 1
        let route = Planner(setup: setup, log: nil, subject: locked, fileName: "x").route
        XCTAssertEqual(route.provider, .lmStudio)
        XCTAssertNotNil(route.lockLine)
        // Never chosen before, planning follows the writing's choice.
        let settings = AppSettings.ephemeral()
        XCTAssertEqual(settings.provider[.planning], settings.provider[.writing])
        XCTAssertTrue(ModelTask.planning.isBuilt)
    }

}
