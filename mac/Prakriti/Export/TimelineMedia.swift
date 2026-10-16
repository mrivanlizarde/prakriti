import AVFoundation
import Darwin
import Foundation

// What the timelines point at (v2 part M10a, docs/v2/PLAN.md M10; research-edit-engine.md 5.3 and 5.5): `Media/` beside the
// timelines holds an APFS clone of the recording (`clonefile(2)`, what `cp -c` does): no extra disk until either file changes,
// and the timelines never point into the shared Studio Recordings folder, where iCloud could evict the original and leave them
// offline. The clone is used only when everyone in the video is included and nothing is muted; otherwise `Media/` holds the
// privacy-safe copy instead (`CleanedMedia`, v2 part M10b), and never the clone.
//
// A clone is proved per file, never by free disk space (another agent may write to the same disk, PLAN M10 check 2): the
// volume's own record of the file, read with getattrlist(2), says how many of its bytes are its own (ATTR_CMNEXT_PRIVATESIZE,
// 0 for a fresh clone) and which clone family it belongs to (ATTR_CMNEXT_CLONEID, the same as its source's). Measured on this
// Mac 15 Oct on the 13 Sep excerpt: the clone and its source both private 0 bytes, the same clone id, clone count 2; a plain
// copy of 5 MB had 5,001,216 private bytes and its own id.

enum TimelineMedia {
    static let folderName = "Media"

    /// The privacy-safe media's name (v2 part M10b): the recording's name and "privacy-safe", a QuickTime movie.
    static func privacySafeName(_ original: URL) -> String {
        original.deletingPathExtension().lastPathComponent + " privacy-safe.mov"
    }

    struct CloneFacts: Codable, Equatable, Sendable {
        /// Bytes of the file shared with no other file.
        var privateBytes: Int64
        var cloneID: UInt64
        /// How many files share its blocks, when the volume says.
        var references: UInt32
    }

    /// The volume's clone record of a file, or nil when it cannot be read.
    static func cloneFacts(_ url: URL) -> CloneFacts? {
        var list = attrlist()
        list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        list.commonattr = attrgroup_t(truncatingIfNeeded: ATTR_CMN_RETURNED_ATTRS)
        list.forkattr = attrgroup_t(ATTR_CMNEXT_PRIVATESIZE | ATTR_CMNEXT_CLONEID | ATTR_CMNEXT_CLONE_REFCNT)
        var buffer = [UInt8](repeating: 0, count: 256)
        let result = buffer.withUnsafeMutableBytes { getattrlist(url.path, &list, $0.baseAddress, 256, UInt32(FSOPT_ATTR_CMN_EXTENDED)) }
        guard result == 0 else { return nil }
        return buffer.withUnsafeBytes { raw -> CloneFacts? in
            var at = 4
            let returned = raw.loadUnaligned(fromByteOffset: at, as: attribute_set_t.self)
            at += MemoryLayout<attribute_set_t>.size
            guard returned.forkattr & attrgroup_t(ATTR_CMNEXT_PRIVATESIZE) != 0 else { return nil }
            let size = raw.loadUnaligned(fromByteOffset: at, as: Int64.self)
            at += 8
            var id: UInt64 = 0, references: UInt32 = 0
            if returned.forkattr & attrgroup_t(ATTR_CMNEXT_CLONEID) != 0 { id = raw.loadUnaligned(fromByteOffset: at, as: UInt64.self); at += 8 }
            if returned.forkattr & attrgroup_t(ATTR_CMNEXT_CLONE_REFCNT) != 0 { references = raw.loadUnaligned(fromByteOffset: at, as: UInt32.self) }
            return CloneFacts(privateBytes: size, cloneID: id, references: references)
        }
    }

    /// Whether `copy` shares its blocks with `source`: the same clone id, and none of its bytes its own.
    static func isClone(_ copy: URL, of source: URL) -> Bool {
        guard let a = cloneFacts(copy), let b = cloneFacts(source) else { return false }
        return a.cloneID == b.cloneID && a.cloneID != 0 && a.privateBytes == 0
    }

    /// Clones `original` into `folder` under its own name. When the volume cannot clone it (another disk, or a file iCloud has
    /// not downloaded), it is copied instead and `cloned` says so.
    static func clone(_ original: URL, into folder: URL) throws -> (url: URL, cloned: Bool) {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: original.lastPathComponent)
        try? fm.removeItem(at: destination)
        if clonefile(original.path, destination.path, 0) == 0 { return (destination, true) }
        try fm.copyItem(at: original, to: destination)
        return (destination, isClone(destination, of: original))
    }

    /// The media's facts for the timeline: its whole frames at the plan's frame, its picture size and its sound.
    static func info(_ url: URL, name: String, finalURL: URL, frame: FrameDuration) async throws -> TimelineSpec.Media {
        let asset = AVURLAsset(url: url)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else {
            throw GraphicsClips.Failure(reason: "The recording has no picture, so no timeline was written.")
        }
        // The picture's own end, as the video's composition counts it (`CompositionBuilder.pictureFrames`).
        let (size, range) = try await video.load(.naturalSize, .timeRange)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        var channels = 2, rate = 48_000
        if let first = audio.first, let description = try await first.load(.formatDescriptions).first,
           let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
            channels = Int(basic.mChannelsPerFrame)
            rate = Int(basic.mSampleRate)
        }
        let frames = Int64((range.end.seconds / frame.seconds + 1e-6).rounded(.down))
        return TimelineSpec.Media(name: name, url: finalURL, frames: frames, width: Int(size.width), height: Int(size.height), hasAudio: !audio.isEmpty,
                                  audioSources: max(1, audio.count), audioChannels: channels, audioRate: rate)
    }

    /// Whether a made clip opens and its last frames decode: every frame of a short clip, the last 5 s of a long one. Returns the
    /// frames decoded, 0 when none.
    static func tailFrames(_ url: URL, seconds: Double = 5) async -> Int {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first, let duration = try? await asset.load(.duration),
              let reader = try? AVAssetReader(asset: asset) else { return 0 }
        let start = max(0, duration.seconds - seconds)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600_000), end: duration)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let samples = reader.outputProvider(for: output)
        guard (try? reader.start()) != nil else { return 0 }
        var count = 0
        do {
            while let sample = try await samples.next() {
                if case .pixelBuffer = sample.content { count += 1 }
            }
        } catch {
            return 0
        }
        return count
    }
}
