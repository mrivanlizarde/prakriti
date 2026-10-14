import AVFoundation
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M8c, the edited video in the Viewer (docs/v2/PLAN.md M8, checks 4 and 7, the parts `make test` can run on
/// synthetic media): a test-pattern original (ffmpeg's `testsrc2`, no face of anyone) with the sound of `ums-and-retake.wav`,
/// planned and made exactly as a make does it, then opened in the Viewer on Video. Check 4 ("preview equals output"): six
/// frames at known plan times decoded from the MP4 and taken by `AVAssetImageGenerator` from the Viewer's own player item,
/// with the exact `videoComposition` object the player plays, match at 38 dB or better. Then the clock between the
/// original and the video, the plan the video was made from (Plan Again stops it playing), Restore and Remove on the plan's
/// spans with Undo, Delete, and Approve waiting for a restore.
@MainActor
final class ViewerVideoTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-viewer-video-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    func testTheViewerPlaysTheVideoAsItWasMade() async throws {
        let made = try await VideoFixture.make(in: work.appending(path: "2026-10-14 pattern", directoryHint: .isDirectory))
        let (model, recording) = try Self.recording(for: made, work: work)
        model.open(recording)
        model.openViewer(recording)
        let viewer = model.viewer
        XCTAssertTrue(viewer.isAvailable(.video))
        XCTAssertNil(viewer.unavailableReason(.video))
        XCTAssertEqual(viewer.defaultRendition, .video, "a recording with a video opens on it (design spec 3.4.2)")
        XCTAssertEqual(viewer.rendition, .video)
        let ready = await viewer.videoItemReady()
        let item = try XCTUnwrap(ready, viewer.originalNote ?? "the Video did not load")
        XCTAssertTrue(viewer.player.currentItem === item)
        let composition = try XCTUnwrap(item.videoComposition)
        XCTAssertTrue(composition.customVideoCompositorClass == Compositor.self, "the Viewer draws through the file's own compositor")
        XCTAssertEqual(composition.instructions.count, made.timeline.pieces.count)
        let tracks = try await item.asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(tracks.count, 1, "the made video's sound")
        let length = try await item.asset.load(.duration).seconds
        XCTAssertEqual(length, made.timeline.duration, accuracy: made.timeline.frame.seconds, "as long as the made video")

        // Check 4: preview equals output.
        let compared = try await PreviewCheck.compare(item: item, mp4: made.mp4, timeline: made.timeline)
        for c in compared {
            print(String(format: "Preview equals output (test pattern): %@ edited %.3f s (original %.3f s): %.1f dB; 3 frames later %.1f dB",
                         c.span, c.edited, c.original, c.psnr, c.neighbour))
        }
        XCTAssertEqual(compared.count, 6)
        for c in compared {
            XCTAssertGreaterThanOrEqual(c.psnr, 38, "frame at \(c.edited) s")
            XCTAssertLessThan(c.neighbour, c.psnr - 3, "the measure tells frames apart at \(c.edited) s")
        }

        // The clock: a word plays from its place in the video; a moment the plan took out plays from where the video goes on.
        let piece = try XCTUnwrap(made.timeline.pieces.dropFirst().first)
        let inside = made.timeline.seconds(piece.sourceFrame + 10)
        viewer.seek(original: inside, play: false)
        XCTAssertEqual(viewer.time, made.timeline.seconds(piece.editFrame + 10), accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(viewer.currentOriginal), inside, accuracy: 0.001)
        let removed = try XCTUnwrap(made.plan.removed.first { $0.kind == .filler || $0.kind == .restart })
        viewer.seek(original: (removed.from + removed.to) / 2, play: false)
        XCTAssertEqual(viewer.time, try XCTUnwrap(made.timeline.editTimeAtOrAfter(removed.to - 0.001)), accuracy: 0.04)

        // The strip and the transcript show the plan the video was made from.
        let spans = ViewerTimeline.spans(recording, duration: made.plan.sourceDuration, model: model)
        XCTAssertEqual(spans, TimelineSpan.spans(plan: made.plan))
        XCTAssertEqual(viewer.videoPlan?.madeAt.timeIntervalSince1970 ?? 0, made.plan.madeAt.timeIntervalSince1970, accuracy: 1)

        // Captions: the uploaded .srt, read back.
        XCTAssertFalse(viewer.captions.isEmpty)
        viewer.showsCaptions = true
        let cue = try XCTUnwrap(viewer.captions.first)
        viewer.seek(original: try XCTUnwrap(made.timeline.originalTime((cue.start + cue.end) / 2)), play: false)
        XCTAssertEqual(viewer.currentCaption?.text, cue.text)

        // Plan Again after the video: the Video says why and does not play an edit that is not in the file.
        var newer = made.plan
        newer.madeAt = made.plan.madeAt.addingTimeInterval(120)
        try newer.encoded().write(to: made.folder.appending(path: EditPlan.fileName))
        recording.madeFiles = recording.madeFiles + ["x"]
        model.openViewer(recording)
        XCTAssertFalse(viewer.isAvailable(.video))
        XCTAssertEqual(viewer.unavailableReason(.video), "The edit was planned again after this video was made, so it plays here once you Make Again.")
        XCTAssertNotEqual(viewer.rendition, .video)
    }

    func testRestoreRemoveUndoAndDeleteOnThePlansSpans() async throws {
        let made = try await VideoFixture.make(in: work.appending(path: "2026-10-14 pattern", directoryHint: .isDirectory))
        let (model, recording) = try Self.recording(for: made, work: work)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.undoOverride = undo
        model.open(recording)
        model.openViewer(recording)
        _ = await model.viewer.videoItemReady()
        let spans = TimelineSpan.spans(plan: made.plan)
        XCTAssertNil(model.videoBehind(recording))
        XCTAssertTrue(model.approvalCheck(recording).canApprove || !(model.approvalCheck(recording).line ?? "").contains("restored"))

        // Restore a filler the plan took out: it goes into the restores, waits for Make Again, and Approve waits for it.
        let filler = try XCTUnwrap(spans.first { $0.reason == .filler })
        XCTAssertEqual(model.spanEdit(filler, in: recording), .restore)
        undo.beginUndoGrouping()
        XCTAssertNil(model.applySpanEdit(filler, in: recording, undo: undo))
        undo.endUndoGrouping()
        XCTAssertEqual(recording.planRestores, [TimeRange(start: filler.start, end: filler.end)])
        XCTAssertEqual(model.spanEdit(filler, in: recording), .restored, "the button turns to Take Out Again")
        XCTAssertEqual(model.videoBehind(recording), "Not in the video yet: your newest changes show once you Make Again.")
        XCTAssertTrue(recording.restoresPending)
        XCTAssertEqual(model.approvalCheck(recording).line, "Make Again first: what you restored is not in the video yet.")
        XCTAssertFalse(model.approvalCheck(recording).canApprove)
        undo.undo()
        XCTAssertEqual(recording.planRestores, [], "Command-Z takes the restore back")
        XCTAssertNil(model.videoBehind(recording))
        undo.redo()
        XCTAssertEqual(recording.planRestores.count, 1, "Redo puts it back")
        undo.undo()

        // Remove a kept span: it becomes a cut (the episode loses it too), and Undo takes it back.
        let kept = try XCTUnwrap(spans.first { !$0.isRemoved && $0.length > 1 })
        XCTAssertEqual(model.spanEdit(kept, in: recording), .remove)
        undo.beginUndoGrouping()
        XCTAssertNil(model.applySpanEdit(kept, in: recording, undo: undo))
        undo.endUndoGrouping()
        XCTAssertEqual(recording.cuts, [TimeRange(start: kept.start, end: kept.end)])
        XCTAssertEqual(model.spanEdit(kept, in: recording), .removed)
        XCTAssertTrue(recording.editsPending)
        undo.undo()
        XCTAssertEqual(recording.cuts, [])

        // Delete with a kept span chosen does the same, through the window's undo manager.
        model.viewer.selectedSpan = kept
        undo.beginUndoGrouping()
        model.deleteInViewer()
        undo.endUndoGrouping()
        XCTAssertEqual(recording.cuts.count, 1)
        undo.undo()
        XCTAssertEqual(recording.cuts, [])

        // Time cut for someone left out has no Restore here (research 3.4 rule 5).
        let person = TimelineSpan(kind: .planned, start: 1, end: 2, reason: .person, detail: "Someone you chose to leave out, 1.0 s.")
        XCTAssertEqual(model.spanEdit(person, in: recording), .person)
        XCTAssertNil(model.applySpanEdit(person, in: recording))
        XCTAssertEqual(recording.cuts, [])
        XCTAssertEqual(recording.planRestores, [])

        // The next plan keeps what was restored as recorded, and records it.
        undo.beginUndoGrouping()
        XCTAssertNil(model.applySpanEdit(filler, in: recording, undo: undo))
        undo.endUndoGrouping()
        let replanned = try await VideoFixture.plan(original: made.original, transcript: made.folder.appending(path: TranscriptFiles.asHeard),
                                                    restored: recording.planRestores, job: work.appending(path: "replan"))
        XCTAssertFalse(replanned.removed.contains { $0.to > filler.start + 0.001 && $0.from < filler.end - 0.001 },
                       "nothing is taken out where Ivan restored")
        XCTAssertEqual(replanned.removed.filter { $0.kind == .filler }.count, made.plan.removed.filter { $0.kind == .filler }.count - 1)
        XCTAssertEqual(replanned.basis.restored, recording.planRestores)
        XCTAssertNil(model.planIsBehind(recording, plan: replanned))
        XCTAssertEqual(model.planIsBehind(recording, plan: made.plan), "What you restored is not in the plan yet.")
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: made.folder.appending(path: TranscriptFiles.asHeard))))
        XCTAssertEqual(PlanValidation.check(replanned, words: words), [])
    }

    func testCaptionsReadBackFromTheFileAndShowAtTheirTime() {
        let srt = "1\n00:00:01,000 --> 00:00:02,500\nThe breath\ncomes first.\n\n2\n00:00:03,000 --> 00:00:04,000\nThen the body.\n"
        let cues = Captions.cues(srt: srt)
        XCTAssertEqual(cues.map(\.lines), [["The breath", "comes first."], ["Then the body."]])
        XCTAssertNil(Captions.cue(at: 0.5, in: cues))
        XCTAssertEqual(Captions.cue(at: 1.0, in: cues)?.text, "The breath comes first.")
        XCTAssertNil(Captions.cue(at: 2.7, in: cues), "nothing between two captions")
        XCTAssertEqual(Captions.cue(at: 3.99, in: cues)?.text, "Then the body.")
        XCTAssertNil(Captions.cue(at: 4.0, in: cues))
    }

    // MARK: Helpers

    /// The made video as a recording of an in-memory store, ready for its yes, everyone included.
    static func recording(for made: VideoFixture.Made, work: URL) throws -> (AppModel, Recording) {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: work.appending(path: "home")),
                             settings: .ephemeral(), log: AppLog(directory: nil))
        let recording = Recording(filePath: made.original.path, recordedAt: Date(), foundAt: Date(), duration: made.plan.sourceDuration,
                                  status: .readyForYourYes, kind: .talk)
        recording.outputFolder = made.folder.path
        recording.madeFiles = ((try? FileManager.default.contentsOfDirectory(atPath: made.folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
        recording.videoJSON = made.record.json()
        recording.madeAt = Date()
        model.context.insert(recording)
        try model.context.save()
        return (model, recording)
    }
}

/// The test-pattern video, made as a make makes it (v2 part M8c): `test pattern.mp4` (ffmpeg's `testsrc2`, 1080p 29.97, the
/// sound of `ums-and-retake.wav`), its transcript (Parakeet's own of the fixture), `edit-plan.json` planned by `PlanStep`, the
/// Video folder made and checked by `VideoStep` through `OutputGate`, and `video-record.json` for the real-window capture.
enum VideoFixture {
    struct Made {
        let folder: URL
        let original: URL
        let mp4: URL
        let plan: EditPlan
        let record: VideoRecord
        let timeline: EditTimeline
    }

    static func plan(original: URL, transcript: URL, restored: [TimeRange] = [], job: URL) async throws -> EditPlan {
        let ffmpeg = ToolPaths.standard.ffmpeg
        var setup = PlanStep.Setup(original: original, transcript: transcript, jobFolder: job, duration: 30, frameRate: 29.97)
        setup.restored = restored
        return try await PlanStep.run(setup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan
    }

    static func make(in folder: URL) async throws -> Made {
        let fm = FileManager.default
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let scratch = folder.appending(path: ".pattern", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: scratch) }
        let made = try await RenderTests.syntheticOriginal(in: scratch)
        let original = folder.appending(path: VideoSampleFolder.original)
        try fm.moveItem(at: made, to: original)
        let transcript = folder.appending(path: TranscriptFiles.asHeard)
        try fm.copyItem(at: RenderTests.transcript, to: transcript)
        let plan = try await plan(original: original, transcript: transcript, job: scratch.appending(path: "plan", directoryHint: .isDirectory))
        try PlanStep.write(plan, into: folder)
        let setup = VideoStep.Setup(original: original, plan: plan, transcript: transcript, staging: folder, title: "", notes: "", written: nil,
                                    writtenToOriginal: { $0 }, recordedAt: Date(timeIntervalSince1970: 1_789_000_000), label: "Test pattern",
                                    people: RenderTests.everyoneIncluded())
        let video = try await VideoStep.make(setup, ffmpeg: RenderTests.ffmpeg())
        let record = try await VideoStep.check(video, setup: setup, ffprobe: RenderTests.ffprobe(), ffmpeg: RenderTests.ffmpeg(), now: Date())
        try record.json().write(to: folder.appending(path: VideoSampleFolder.record), atomically: true, encoding: .utf8)
        let mp4 = folder.appending(path: VideoStep.folderName).appending(path: record.fileName)
        return Made(folder: folder, original: original, mp4: mp4, plan: plan, record: record, timeline: video.timeline)
    }
}

/// PLAN M8 check 4, measured (v2 part M8c): six frames at known plan times, one in the middle of each of six kept spans spread
/// over the video (never within two frames of a join), decoded from the made MP4 and taken by `AVAssetImageGenerator` from the
/// Viewer's player item with its own `videoComposition`, compared by PSNR. Numbers only: no picture is written, so it runs on a
/// talk without anyone looking at a frame (PLAN rule 2.1.9).
enum PreviewCheck {
    struct Compared {
        let span: String
        let edited: Double
        let original: Double
        let psnr: Double
        /// The file's frame against the preview's frame three frames later: proves the measure tells frames apart.
        let neighbour: Double
    }

    /// The player item's asset and video composition, carried off the main actor as the one pair the player plays.
    struct Played: @unchecked Sendable {
        let asset: AVAsset
        let videoComposition: AVVideoComposition?
    }

    @MainActor
    static func compare(item: AVPlayerItem, mp4: URL, timeline: EditTimeline, count: Int = 6) async throws -> [Compared] {
        try await compare(played: Played(asset: item.asset, videoComposition: item.videoComposition), mp4: mp4, timeline: timeline, count: count)
    }

    static func compare(played: Played, mp4: URL, timeline: EditTimeline, count: Int) async throws -> [Compared] {
        // Six moments spread evenly over the edited video, each moved to stay two frames or more from a join.
        var frames: [(piece: EditTimeline.Piece, frame: Int64)] = []
        for n in 0..<count {
            let target = Int64((Double(timeline.totalFrames) * (Double(n) + 0.5) / Double(count)).rounded())
            guard let piece = timeline.pieces.first(where: { target < $0.editFrame + $0.frames }) ?? timeline.pieces.last, piece.frames >= 5 else { continue }
            frames.append((piece, min(max(target, piece.editFrame + 2), piece.editFrame + piece.frames - 3)))
        }
        let output = AVURLAsset(url: mp4)
        var out: [Compared] = []
        for (piece, editFrame) in frames {
            let at = timeline.time(editFrame)
            let file = try await RenderTests.frame(output, at: at)
            let preview = try await RenderTests.frame(played.asset, videoComposition: played.videoComposition, at: at)
            let later = try await RenderTests.frame(played.asset, videoComposition: played.videoComposition, at: timeline.time(min(editFrame + 3, timeline.totalFrames - 1)))
            out.append(Compared(span: piece.id, edited: at.seconds, original: timeline.seconds(piece.sourceFrame + editFrame - piece.editFrame),
                                psnr: RenderTests.psnr(file, preview), neighbour: RenderTests.psnr(file, later)))
        }
        return out
    }
}
