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
}
