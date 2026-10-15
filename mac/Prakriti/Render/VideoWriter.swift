import AVFoundation
import Foundation
import VideoToolbox

// Writing the MP4 (v2 part M8b, research-edit-engine.md 4.2 item 6 and 6.1): the composition's frames, drawn by the
// `Compositor`, read through `AVAssetReaderVideoCompositionOutput`, and the mastered WAV read as PCM, both into one
// `AVAssetWriter`. `AVAssetExportSession` is not used: it cannot set a bitrate.
//
// The macOS 27 calls only (Mac warning 4, PLAN 2.2): `reader.outputProvider(for:)` then `try reader.start()` (never
// `add(_:)` first, which crashes, research-people.md 1.7), and frames into the writer through
// `AVAssetWriter.inputPixelBufferReceiver(for:)` and sound through `inputReceiver(for:)`, which add the inputs themselves.
// Measured on the first day of M8b (13 Oct, SDK 27.0): `outputProvider(for:)` takes an `AVAssetReaderVideoCompositionOutput`
// and hands out the composed frames (PLAN 2.2 had it [unverified]).
//
// The settings, each with its reason:
// - H.264 High, CABAC, a key frame at least every 15 frames (half a second at 29.97, YouTube's "closed GOP of half the frame
//   rate"), BT.709 tags, progressive, the source's frame rate, 16 Mbps at 1080p (45 Mbps over 1080p).
// - **Constant bitrate.** With only an average asked for, VideoToolbox gave 11.9 Mbps for a 16 Mbps target on the 13 Sep
//   talk (a still camera is easy to compress), outside the checklist's 10%; asked for a constant 16 Mbps it gave 15.2.
// - **No B-frames.** With frame reordering on, the writer describes the B-frames' delay with an edit list on the video
//   track (measured: one entry starting 41 units in), and YouTube asks for MP4s without edit lists. Without them the only
//   edit list is the writer's identity entry, which `Mp4Boxes.dropIdentityVideoEditList` turns into a free box, so the
//   video track has none. (YouTube's "2 consecutive B-frames" is a recommendation for its own re-encode, not a rule.)
// - `shouldOptimizeForNetworkUse`: the index (`moov`) before the media (`mdat`).
// - The picture's media timescale is the frame's own (30000 for 29.97), so every frame is exactly one frame after the last.
// - AAC-LC 48 kHz stereo at a constant 320 kbps, not the 384 research 6.1 took from YouTube's recommended settings: Apple's
//   AAC encoder takes no more than 320 kbps for stereo (measured 13 Oct: `afconvert -b 384000` refuses with '!dat', and the
//   writer stops with "Cannot Encode Media"), and ffmpeg's own AAC encoder asked for 384 gave 241 kbps on the 13 Sep talk.
//   At a constant 320 Apple's encoder gave 320.0 kbps. YouTube re-encodes the sound in any case. The encoder's priming is
//   described by an edit list on the audio track, which is allowed (research 6.1).

enum VideoWriter {
    struct Settings: Equatable, Sendable {
        var bitrate: Int
        var keyFrameInterval = 15
        /// Apple's AAC encoder's most for stereo at 48 kHz (see the header).
        var audioBitrate = 320_000

        static func standard(height: Int) -> Settings {
            Settings(bitrate: height > 1080 ? 45_000_000 : 16_000_000)
        }
    }

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    struct Written: Sendable {
        let frames: Int
        let seconds: Double
    }

    /// Writes `built`'s picture and `wav`'s sound into `output`. `progress` gets the share of frames written, 0 to 1.
    static func write(_ built: CompositionBuilder.Built, wav: URL, to output: URL, settings: Settings,
                      progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Written {
        let started = ContinuousClock.now
        try? FileManager.default.removeItem(at: output)
        let width = Int(built.renderSize.width), height = Int(built.renderSize.height)

        // The picture, drawn by the compositor.
        let videoReader = try AVAssetReader(asset: built.composition)
        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [built.track],
                                                              videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: Compositor.pixelFormat])
        videoOutput.videoComposition = built.videoComposition
        let frames = videoReader.outputProvider(for: videoOutput)

        // The sound, as 48 kHz stereo floats.
        let audioAsset = AVURLAsset(url: wav)
        guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw Failure(reason: "The video's sound could not be read back to write it.")
        }
        let audioReader = try AVAssetReader(asset: audioAsset)
        let pcm = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVSampleRateKey: EditTimeline.sampleRate,
            AVNumberOfChannelsKey: VideoAudio.channels,
        ])
        let sound = audioReader.outputProvider(for: pcm)

        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_ConstantBitRate as String: settings.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                AVVideoMaxKeyFrameIntervalKey: settings.keyFrameInterval,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoExpectedSourceFrameRateKey: Int((1 / built.timeline.frame.seconds).rounded()),
            ] as [String: any Sendable],
        ])
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: EditTimeline.sampleRate,
            AVNumberOfChannelsKey: VideoAudio.channels,
            AVEncoderBitRateKey: settings.audioBitrate,
            AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Constant,
        ])
        // The picture's own clock: the frame's timescale (30000 for 29.97). Left to the writer it chose 600, where 1001/30000 s
        // is not a whole number, so frames sat 20 or 21 units apart and a frame read at its exact time was every so often the
        // one before (measured 13 Oct on the test pattern: matching frames swung between the right one and one early in a
        // 50-frame rhythm).
        videoInput.mediaTimeScale = CMTimeScale(built.timeline.frame.timescale)
        let pictureIn = writer.inputPixelBufferReceiver(for: videoInput, pixelBufferAttributes: nil)
        let soundIn = writer.inputReceiver(for: audioInput)

        do {
            try videoReader.start()
            try audioReader.start()
            try writer.start()
        } catch {
            throw Failure(reason: "The video could not be started: \(error.localizedDescription)")
        }
        writer.startSession(atSourceTime: .zero)
        let total = max(1, Int(built.timeline.totalFrames))

        // Picture and sound are fed side by side: the writer interleaves them and waits on whichever is behind.
        let timeline = built.timeline
        async let pictureCount: Int = {
            var count = 0
            var last: CVReadOnlyPixelBuffer?
            var lastFrame: Int64 = -1
            while let sample = try await frames.next() {
                try Task.checkCancellation()
                guard case let .pixelBuffer(buffer) = sample.content else { continue }
                let index = Int64((sample.presentationTimeStamp.seconds / timeline.frame.seconds).rounded())
                // Inside the hold the reader may skip frame times (measured 14 Oct: one frame at the hold's start, the next
                // 2.9 s later): each skipped one is the held frame again.
                if let held = last, timeline.holdFrames > 0, lastFrame >= timeline.keptFrames - 1, index > lastFrame + 1 {
                    for skipped in (lastFrame + 1)..<index {
                        try await pictureIn.append(held, with: timeline.time(skipped))
                        count += 1
                    }
                }
                try await pictureIn.append(buffer, with: sample.presentationTimeStamp)
                last = buffer
                lastFrame = index
                count += 1
                if count % 30 == 0 { progress(min(1, Double(count) / Double(total))) }
            }
            // The held last frame (v2 part M9a): the reader gives a frame held over many frame times once, so it is written
            // again at every frame time after the last one it gave, to the end of the hold.
            if let last, timeline.holdFrames > 0 {
                var next = lastFrame + 1
                while next < timeline.totalFrames {
                    try Task.checkCancellation()
                    try await pictureIn.append(last, with: timeline.time(next))
                    next += 1
                    count += 1
                }
            }
            pictureIn.finish()
            return count
        }()
        async let soundDone: Void = {
            while let sample = try await sound.next() {
                try Task.checkCancellation()
                try await soundIn.append(sample)
            }
            soundIn.finish()
        }()
        let written: Int
        do {
            written = try await pictureCount
            try await soundDone
        } catch {
            writer.cancelWriting()
            throw error is CancellationError ? error : Failure(reason: "The video stopped while it was written: \(error.localizedDescription)")
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw Failure(reason: "The video could not be finished: \(writer.error?.localizedDescription ?? "the writer did not say why").")
        }
        progress(1)
        try Mp4Boxes.dropIdentityVideoEditList(output)
        let d = ContinuousClock.now - started
        return Written(frames: written, seconds: Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18)
    }
}
