import AVFoundation
import Foundation

// The edited video in the Viewer (v2 part M8c, docs/v2/PLAN.md M8, REQUEST item 10: "preview inside the app"). The picture is
// not the MP4's: it is the composition `CompositionBuilder` builds from the same edit plan, drawn by the same `Compositor` with
// the same instructions as the file (`AVPlayerItem.videoComposition`), so what Ivan watches is what the writer encodes, frame
// for frame (PLAN M8 check 4 measures it). The sound is the made MP4's own track, laid on the composition's clock, because
// the video's sound is mastered by ffmpeg (`VideoAudio`) and no player can mix it live; it is exactly as long as the picture
// (`EditTimeline`), so it lines up by construction.
//
// Load-bearing: the preview is built from the plan the video was MADE from (`VideoRecord.planMadeAt`), never from whatever
// `edit-plan.json` says now. Plan Again rewrites that file without making the video, and a preview of a newer plan beside the
// older file would show something that is not in the file. Then the Video rendition says so instead of playing.
//
// From part M8d the faces the video hid are drawn hidden here too: the same `HiddenFaces` the writer used, read from
// `video-hiding.json` beside the plan, go into the same instructions (Mac warning 156).
//
// Nothing here reaches the network (RulesTests: no network type under Render/).

enum VideoPreview {
    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// What the Viewer plays: the composition with the made video's sound, the video composition the player item must carry,
    /// and the timeline between the original's clock and the video's.
    struct Built: @unchecked Sendable {
        let composition: AVMutableComposition
        let videoComposition: AVVideoComposition
        let timeline: EditTimeline
        let renderSize: CGSize
    }

    /// The made video's file and its plan for a recording, or the reason the Video rendition cannot play, in one sentence.
    static func source(folder: String?, video: VideoRecord?) -> Result<(mp4: URL, captions: URL, plan: EditPlan, hidden: HiddenFaces?), Failure> {
        guard let folder, let video else {
            return .failure(Failure(reason: "The edited video is not made for this recording. Make Video is in the inspector's Outputs."))
        }
        let base = URL(fileURLWithPath: folder, isDirectory: true)
        let mp4 = base.appending(path: VideoStep.folderName).appending(path: video.fileName)
        guard FileManager.default.fileExists(atPath: mp4.path) else {
            return .failure(Failure(reason: "The edited video is not in its Video folder any more. Make Again to make it."))
        }
        guard let plan = EditPlan.read(folder: folder) else {
            return .failure(Failure(reason: "The edit plan the video was made from is not in the recording's folder. Make Again to make both."))
        }
        if !matches(plan: plan, video: video) {
            return .failure(Failure(reason: "The edit was planned again after this video was made, so it plays here once you Make Again."))
        }
        // The faces the video hid (v2 part M8d), from the same make: without them the Viewer would show faces the file hides,
        // so a video that hides someone does not play without its own file (warning 156).
        var hidden: HiddenFaces?
        if (video.hiddenFaces ?? 0) > 0 {
            guard let read = HiddenFaces.read(folder: base), abs(read.planMadeAt.timeIntervalSince(plan.madeAt)) < 1 else {
                return .failure(Failure(reason: "Where the video hides faces is not in the recording's folder, so it plays here once you Make Again."))
            }
            hidden = read
        }
        return .success((mp4, base.appending(path: VideoStep.folderName).appending(path: video.captionsName), plan, hidden))
    }

    /// The plan on disk is the one the video was made from: the same moment (to the second, as both files keep it), or, for a
    /// video made before M8c, the same summary and a plan no newer than the video.
    static func matches(plan: EditPlan, video: VideoRecord) -> Bool {
        if let made = video.planMadeAt { return abs(plan.madeAt.timeIntervalSince(made)) < 1 }
        return plan.summary == video.planSummary && plan.madeAt <= video.madeAt.addingTimeInterval(1)
    }

    /// Builds the preview: the plan's composition over the original (`CompositionBuilder`, as the writer builds it) with the
    /// made MP4's sound added on the edited clock.
    static func build(plan: EditPlan, original: URL, mp4: URL, hidden: HiddenFaces? = nil) async throws -> Built {
        let built: CompositionBuilder.Built
        do {
            built = try await CompositionBuilder.build(plan: plan, original: original, hidden: hidden)
        } catch let failure as CompositionBuilder.Failure {
            throw Failure(reason: failure.reason)
        }
        let made = AVURLAsset(url: mp4)
        if let sound = try await made.loadTracks(withMediaType: .audio).first,
           let track = built.composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let range = try await sound.load(.timeRange)
            let total = built.timeline.time(built.timeline.totalFrames)
            let duration = CMTimeMinimum(range.duration, total)
            do {
                try track.insertTimeRange(CMTimeRange(start: range.start, duration: duration), of: sound, at: .zero)
            } catch {
                throw Failure(reason: "The video's sound could not be read: \(error.localizedDescription)")
            }
        }
        return Built(composition: built.composition, videoComposition: built.videoComposition, timeline: built.timeline,
                     renderSize: built.renderSize)
    }
}

/// The test-pattern video folder the M8c acceptance writes for the real-window capture (`--sample-video`): the names inside it.
enum VideoSampleFolder {
    static let original = "test pattern.mp4"
    static let record = "video-record.json"
}
