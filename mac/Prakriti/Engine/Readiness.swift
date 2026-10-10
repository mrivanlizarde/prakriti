import Darwin
import Foundation

/// A new file is not a finished recording. OBS creates the file when recording STARTS, and an
/// iCloud file can be a placeholder with no data on this Mac. Ported from engine v0's
/// `waitUntilReady`, rule for rule: downloaded, size stable, opens with a duration, last 5 seconds
/// decode. (SCOPE 7.3 asks for more, such as 5 minutes of stability and the MP4 index check; those
/// arrive with the watcher. This milestone ports v0 faithfully.)
struct Readiness: Sendable {
    let tools: ToolPaths
    /// How long the size must hold still. Engine v0 waits 60 s; tests use a few seconds.
    var stableWait: Duration = .seconds(60)
    /// How often to look again while iCloud downloads, and for how long at most (v0: 10 s, an hour).
    var downloadPoll: Duration = .seconds(10)
    var downloadLimit: Duration = .seconds(3600)

    struct Ready: Sendable {
        let duration: Double
        let hasAudio: Bool
        let sizeBytes: Int64
        let waitedForICloud: Bool
    }

    /// The flag macOS sets on a file whose data is still in iCloud (`SF_DATALESS` in sys/stat.h).
    /// Read with lstat, the same flag engine v0 reads through `stat -f %Sf`.
    static let datalessFlag: UInt32 = 0x4000_0000

    static func isDataless(_ url: URL) -> Bool {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return info.st_flags & datalessFlag != 0
    }

    static func size(_ url: URL) -> Int64? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return Int64(info.st_size)
    }

    func waitUntilReady(_ url: URL, log: AppLog?) async throws -> Ready {
        var waitedForICloud = false
        if Self.isDataless(url) {
            waitedForICloud = true
            log?.write("Downloading from iCloud: \(url.lastPathComponent)")
            _ = try? await Subprocess.run(tools.brctl, ["download", url.path], timeout: .seconds(60))
            let clock = ContinuousClock()
            let deadline = clock.now + downloadLimit
            while Self.isDataless(url) && clock.now < deadline {
                try await Task.sleep(for: downloadPoll)
            }
            if Self.isDataless(url) {
                throw PipelineFailure(step: .complete, reason: "iCloud never finished downloading it. Prakriti waited an hour.")
            }
        }

        // The size must stop changing: OBS writes the file for the whole session.
        var last: Int64 = -1
        while true {
            guard let size = Self.size(url) else {
                throw PipelineFailure(step: .complete, reason: "The file was moved or deleted before it finished arriving.")
            }
            if size == last && size > 0 { break }
            last = size
            try await Task.sleep(for: stableWait)
        }

        let probe: Measure.Probe
        do {
            let output = try await Subprocess.run(tools.ffprobe, ["-v", "error", "-show_entries", "format=duration:stream=codec_type",
                                                                  "-of", "json", url.path], timeout: .seconds(120))
            guard let parsed = Measure.probe(json: output.stdout) else {
                throw PipelineFailure(step: .complete, reason: "The file does not open yet: it has no length.")
            }
            probe = parsed
        } catch let error as ToolError {
            throw PipelineFailure(step: .complete, reason: "The file does not open: ffprobe could not read it.", detail: error.logLine)
        }

        // Its last seconds decode. A file cut short, or still recording, fails here.
        do {
            _ = try await Subprocess.run(tools.ffmpeg, ["-v", "error", "-sseof", "-5", "-i", url.path, "-f", "null", "-"],
                                         captureStdout: false, timeout: .seconds(300))
        } catch let error as ToolError {
            throw PipelineFailure(step: .complete, reason: "The last seconds of the file do not play. It may still be recording, or it was cut short.",
                                  detail: error.logLine)
        }
        return Ready(duration: probe.duration, hasAudio: probe.hasAudio, sizeBytes: last, waitedForICloud: waitedForICloud)
    }
}
