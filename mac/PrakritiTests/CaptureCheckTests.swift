import AVFoundation
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The capture check (v2 part M4b): reading ffprobe and ffmpeg on the exact text they printed on this Mac, the
/// findings and their words, and the whole check on small files ffmpeg generates in a temporary folder: a
/// Hybrid MOV with three tracks (one silent), one microphone copied to both channels against a real stereo
/// track, a Matroska file, a small and unsteady picture with no color tags, and quiet, too loud and 44.1 kHz
/// tracks. Nothing here reads a real recording: the 13 Sep talk is `make accept-capture`.
@MainActor
final class CaptureCheckTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-capture-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: Reading the tools (the 13 Sep talk's own output, 12 Oct, ffmpeg 9.0.1)

    /// `ffprobe -show_streams -show_format -show_chapters -of json` on the 13 Sep talk, trimmed to the fields read.
    static let probe13Sep = """
    {"streams":[{"index":0,"codec_name":"h264","profile":"High","codec_type":"video","width":1920,"height":1080,
    "color_range":"tv","color_space":"bt709","color_transfer":"bt709","color_primaries":"bt709",
    "r_frame_rate":"30000/1001","avg_frame_rate":"30000/1001","disposition":{"default":1,"attached_pic":0}},
    {"index":1,"codec_name":"aac","profile":"LC","codec_type":"audio","sample_rate":"48000","channels":2,"channel_layout":"stereo",
    "r_frame_rate":"0/0","avg_frame_rate":"0/0","disposition":{"default":1,"attached_pic":0},"tags":{"name":"Track1"}}],
    "chapters":[],
    "format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"947.780167","tags":{"major_brand":"isom"}}}
    """

    /// What `CaptureCheck.trackArguments` made ffmpeg print for the 13 Sep talk's one track.
    static let track13Sep = """
    [volumedetect@difference @ 0x793d020300] n_samples: 0
    [volumedetect@level @ 0x793d020180] n_samples: 0
    [volumedetect@difference @ 0x793d021080] n_samples: 45491136
    [volumedetect@difference @ 0x793d021080] mean_volume: -91.0 dB
    [volumedetect@difference @ 0x793d021080] max_volume: -91.0 dB
    [volumedetect@level @ 0x793d020f00] n_samples: 90982272
    [volumedetect@level @ 0x793d020f00] mean_volume: -30.0 dB
    [volumedetect@level @ 0x793d020f00] max_volume: -3.4 dB
    [Parsed_ebur128_1 @ 0x793d020e40] Summary:
      Integrated loudness:
        I:         -26.6 LUFS
        Threshold: -37.1 LUFS
      Loudness range:
        LRA:         6.2 LU
        Threshold: -47.3 LUFS
        LRA low:   -30.8 LUFS
        LRA high:  -24.6 LUFS
      True peak:
        Peak:       -3.4 dBFS
    """

    func testReadsTheThirteenSeptemberTalk() throws {
        var report = try XCTUnwrap(CaptureCheck.probe(json: Self.probe13Sep, fileName: "2026-09-13 18-25-44.mp4"))
        XCTAssertEqual(report.container, "MP4")
        let video = try XCTUnwrap(report.video)
        XCTAssertEqual(video.width, 1920)
        XCTAssertEqual(video.height, 1080)
        XCTAssertEqual(try XCTUnwrap(video.frameRate), 29.97, accuracy: 0.001)
        XCTAssertEqual(CaptureCheck.rate(video.frameRate ?? 0), "29.97")
        XCTAssertEqual(video.codec, "h264")
        XCTAssertEqual(video.colorSpace, "bt709")
        XCTAssertEqual(report.audio.count, 1)
        XCTAssertEqual(report.audio[0].channels, 2)
        XCTAssertEqual(report.chapters, 0)

        CaptureCheck.readTrack(stderr: Self.track13Sep, into: &report.audio[0])
        let track = report.audio[0]
        XCTAssertEqual(track.loudestDB, -3.4)
        XCTAssertEqual(track.averageDB, -30.0)
        XCTAssertEqual(track.differenceDB, -91.0, "the second, named volumedetect is left minus right")
        XCTAssertEqual(track.integratedLUFS, -26.6)
        XCTAssertEqual(track.truePeakDBTP, -3.4)
        XCTAssertTrue(track.isDualMono)
        XCTAssertFalse(track.isSilent)

        report.findings = CaptureCheck.findings(report)
        let byID = Dictionary(uniqueKeysWithValues: report.findings.map { ($0.id, $0) })
        XCTAssertEqual(byID["picture-size"]?.level, .pass)
        XCTAssertEqual(byID["picture-size"]?.value, "1920 by 1080 (1080p)")
        XCTAssertEqual(byID["frame-rate"]?.value, "29.97 frames per second")
        XCTAssertEqual(byID["video-codec"]?.value, "H.264 (High)")
        XCTAssertEqual(byID["color"]?.value, "Rec. 709, limited range")
        XCTAssertEqual(byID["audio-tracks"]?.level, .warn)
        let dual = try XCTUnwrap(byID["track-1-dual-mono"])
        XCTAssertEqual(dual.level, .warn)
        XCTAssertEqual(dual.tip, "Give each speaker a microphone on its own track.")
        XCTAssertEqual(dual.help, "capture-the-best-video")
        XCTAssertEqual(report.warnings.map(\.id), ["audio-tracks", "track-1-dual-mono"])
        XCTAssertEqual(report.summary, "Two things to change before the next recording.")
        report.measuredAt = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(CaptureReport.decode(report.json()), report, "kept on the recording as JSON and read back the same")
    }

    func testEveryFindingShortOfAPassCarriesATipAndAHelpArticle() {
        let report = CaptureReport(container: "Matroska (MKV)",
                                   video: .init(codec: "mpeg4", width: 1280, height: 720, frameRate: 15, averageFrameRate: 11),
                                   audio: [.init(number: 1, codec: "aac", sampleRate: 44100, channels: 2, integratedLUFS: -48, truePeakDBTP: -0.1,
                                                 loudestDB: -0.1, averageDB: -50, differenceDB: -20),
                                           .init(number: 2, codec: "aac", sampleRate: 48000, channels: 1, loudestDB: -91, averageDB: -91)],
                                   measuredAt: .now)
        let findings = CaptureCheck.findings(report)
        let ids = Set(findings.filter { $0.level != .pass }.map(\.id))
        XCTAssertEqual(ids, ["container", "picture-size", "frame-rate", "video-codec", "color", "track-1", "track-1-quiet", "track-1-peak",
                             "track-1-sample-rate", "track-2", "track-2-silent"])
        for finding in findings where finding.level != .pass && finding.kind != .track {
            XCTAssertNotNil(finding.tip, finding.id)
            XCTAssertNotNil(finding.help.flatMap { CaptureCheck.helpTitles[$0] }, finding.id)
        }
        XCTAssertEqual(findings.first { $0.id == "track-2-silent" }?.level, .warn, "a silent extra track is a microphone to check")
        XCTAssertFalse(findings.contains { $0.id == "track-1-dual-mono" }, "left and right differ by -20 dB: two sounds")
        XCTAssertTrue(findings.first { $0.id == "frame-rate" }?.value.contains("changes during the recording") == true)
        // The words: Ivan's copy rules (no dashes, no "we", no "Processing").
        for finding in findings {
            for text in [finding.title, finding.value, finding.limit, finding.tip ?? ""] {
                XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), text)
                XCTAssertNil(text.range(of: #"\bwe\b"#, options: [.regularExpression, .caseInsensitive]), text)
                XCTAssertFalse(text.localizedCaseInsensitiveContains("processing"), text)
            }
        }
        // A silent first track is not usable: everything is made from it.
        let silentMix = CaptureReport(container: "MP4", audio: [.init(number: 1, codec: "aac", sampleRate: 48000, channels: 2, loudestDB: -91, averageDB: -91, differenceDB: -91)],
                                      measuredAt: .now)
        let silentFindings = CaptureCheck.findings(silentMix)
        XCTAssertEqual(silentFindings.first { $0.id == "track-1-silent" }?.level, .fail)
        XCTAssertFalse(silentFindings.contains { $0.id == "track-1-dual-mono" }, "silence is the same in both channels, but it is silence")
    }

    func testTheHelpArticlesTheFindingsNameExist() {
        let library = HelpLibrary.bundled(capabilities: Capabilities.built)
        for (id, title) in CaptureCheck.helpTitles {
            XCTAssertEqual(library.articles.first { $0.id == id }?.title, title, id)
        }
        XCTAssertTrue(Capabilities.built.contains(.captureCheck))
    }

    // MARK: The check on generated files

    /// A Hybrid MOV as OBS 32 writes one on a Mac (fragmented, then finished), with the OBS track layout: three
    /// mono tracks, the third left silent. Accepted everywhere a Hybrid MP4 is: the watcher lists it, the
    /// readiness check passes it, AVFoundation (the Viewer) opens it, and the capture check reads every track.
    func testAHybridMOVIsAcceptedAndEveryTrackMeasured() async throws {
        let mov = try make("2026-10-12 10-00-00.mov", [
            "-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30:duration=6",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=6",
            "-f", "lavfi", "-i", "sine=frequency=660:sample_rate=48000:duration=6",
            "-f", "lavfi", "-i", "anullsrc=channel_layout=mono:sample_rate=48000:duration=6",
            "-map", "0:v", "-map", "1:a", "-map", "2:a", "-map", "3:a",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
            "-c:a", "aac", "-ac", "1", "-movflags", "+frag_keyframe+empty_moov+default_base_moof", "-f", "mov",
        ])
        let mp4 = try make("2026-10-12 10-00-00 hybrid.mp4", [
            "-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30:duration=6",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=6",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+frag_keyframe+empty_moov+default_base_moof",
        ])
        for file in [mov, mp4] {
            XCTAssertTrue(FolderScan.isCandidate(file.lastPathComponent), file.lastPathComponent)
            let ready = try await Readiness(tools: .standard, stableWait: .milliseconds(200)).waitUntilReady(file, log: nil)
            XCTAssertEqual(ready.duration, 6, accuracy: 0.2)
            let asset = AVURLAsset(url: file)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            XCTAssertEqual(tracks.count, file == mov ? 3 : 1, "AVFoundation opens \(file.lastPathComponent)")
            let playable = try await asset.load(.isPlayable)
            XCTAssertTrue(playable)
        }
        XCTAssertEqual(FolderScan.scan(work.path), .files([mov, mp4].sorted { $0.path < $1.path }.map {
            ScannedFile(path: $0.standardizedFileURL.path, size: Int64(Readiness.size($0) ?? 0)) }))

        let report = try await check(mov)
        XCTAssertEqual(report.container, "MOV")
        XCTAssertEqual(report.audio.count, 3)
        XCTAssertEqual(report.audio.map(\.channels), [1, 1, 1])
        let loudness = report.audio.compactMap(\.integratedLUFS)
        XCTAssertEqual(loudness.count, 2, "tracks 1 and 2 have loudness; track 3 is silent")
        XCTAssertTrue(report.audio[2].isSilent)
        XCTAssertFalse(report.audio.contains { $0.isDualMono })
        let ids = report.findings.map(\.id)
        XCTAssertEqual(report.findings.first { $0.id == "audio-tracks" }?.level, .pass)
        XCTAssertTrue(ids.contains("track-3-silent"))
        XCTAssertEqual(report.findings.first { $0.id == "color" }?.level, .pass)
        XCTAssertEqual(report.findings.first { $0.id == "frame-rate" }?.value, "30 frames per second")
        let mp4Report = try await check(mp4)
        XCTAssertEqual(mp4Report.container, "MP4")
    }

    func testOneMicrophoneInBothChannelsAgainstRealStereo() async throws {
        let dual = try make("dual.m4a", ["-f", "lavfi", "-i", "sine=frequency=330:sample_rate=48000:duration=4",
                                         "-af", "pan=stereo|c0=c0|c1=c0", "-c:a", "aac", "-b:a", "160k"])
        let stereo = try make("stereo.m4a", ["-f", "lavfi", "-i", "sine=frequency=330:sample_rate=48000:duration=4",
                                             "-f", "lavfi", "-i", "sine=frequency=550:sample_rate=48000:duration=4",
                                             "-filter_complex", "[0:a][1:a]join=inputs=2:channel_layout=stereo", "-c:a", "aac"])
        let dualReport = try await check(dual)
        XCTAssertTrue(dualReport.audio[0].isDualMono, "difference \(String(describing: dualReport.audio[0].differenceDB))")
        XCTAssertLessThanOrEqual(dualReport.audio[0].differenceDB ?? 0, -60)
        XCTAssertEqual(dualReport.findings.first { $0.id == "track-1-dual-mono" }?.tip, "Give each speaker a microphone on its own track.")
        XCTAssertEqual(dualReport.findings.first { $0.id == "picture" }?.level, .pass, "a sound file has no picture to check")
        let stereoReport = try await check(stereo)
        XCTAssertFalse(stereoReport.audio[0].isDualMono, "difference \(String(describing: stereoReport.audio[0].differenceDB))")
        XCTAssertGreaterThan(stereoReport.audio[0].differenceDB ?? -.infinity, -60)
    }

    func testPoorCaptureIsNamed() async throws {
        let mkv = try make("old.mkv", ["-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=15:duration=3",
                                       "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100:duration=3",
                                       "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac"])
        let report = try await check(mkv)
        let levels = Dictionary(uniqueKeysWithValues: report.findings.map { ($0.id, $0.level) })
        XCTAssertEqual(report.container, "Matroska (MKV)")
        XCTAssertEqual(levels["container"], .warn)
        XCTAssertEqual(levels["picture-size"], .warn)
        XCTAssertEqual(levels["frame-rate"], .warn, "15 fps")
        XCTAssertEqual(levels["color"], .warn, "no color tags")
        XCTAssertEqual(levels["track-1-sample-rate"], .warn)

        let quiet = try make("quiet.wav", ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=3", "-af", "volume=-25dB"])
        let loud = try make("loud.wav", ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=3", "-af", "volume=20dB,alimiter=limit=1:level=disabled"])
        let quietReport = try await check(quiet), loudReport = try await check(loud)
        XCTAssertEqual(quietReport.findings.first { $0.id == "track-1-quiet" }?.level, .warn)
        XCTAssertEqual(loudReport.findings.first { $0.id == "track-1-peak" }?.level, .warn, "peak \(String(describing: loudReport.audio.first?.truePeakDBTP))")
        XCTAssertEqual(loudReport.container, "WAV")
    }

    // MARK: In the pipeline

    /// The capture check is the first step once the file is complete, so even a test under 60 s keeps one.
    func testAShortTestKeepsItsCaptureCheck() async throws {
        let clip = try make("clip.mov", ["-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30:duration=5",
                                         "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=5",
                                         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac"])
        var options = PipelineOptions()
        options.stableWait = .milliseconds(200)
        let out = work.appending(path: "out", directoryHint: .isDirectory)
        let result = await Pipeline(options: options, log: nil).run(file: clip, outputFolder: out, label: "Test", progress: { _ in })
        XCTAssertEqual(result.outcome, .test)
        XCTAssertEqual(result.steps.map(\.name).prefix(3), ["Checked the file is complete", "Capture check", "Sound check"])
        XCTAssertEqual(result.steps[1].state, .done)
        XCTAssertTrue(result.steps[1].detail?.hasPrefix("1920 by 1080, 30 fps, H.264. 1 audio track.") == true, result.steps[1].detail ?? "")
        let capture = try XCTUnwrap(result.capture)
        XCTAssertEqual(capture.audio.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.path), "nothing made from a test")
    }

    /// The runner keeps the check on the recording, for every outcome, and Activity says what it found.
    func testTheRunnerKeepsTheCheckOnTheRecording() async throws {
        let clip = try make("2026-10-12 11-00-00.mov", ["-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30:duration=4",
                                                        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=4",
                                                        "-af", "pan=stereo|c0=c0|c1=c0", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac"])
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: Date.init)
        model.runner.stableWait = .milliseconds(200)
        let recording = Recording(filePath: clip.path, foundAt: Date())
        model.context.insert(recording)
        try model.context.save()
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.kind, .test)
        let capture = try XCTUnwrap(recording.capture, "the check is in the store")
        XCTAssertTrue(capture.findings.contains { $0.id == "track-1-dual-mono" })
        try model.context.save()
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.contains("capture check. Three things to change") && $0.contains("Color; Audio tracks; Track 1, one microphone in both channels.") }, lines.joined(separator: "\n"))
    }

    /// Check Capture on a recording found before the check existed: it only reads the file, keeps the report, and
    /// changes nothing else; a missing file says so instead.
    func testCheckCaptureOnAnOlderRecording() async throws {
        let file = try make("older.m4a", ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=3", "-c:a", "aac"])
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: Date.init)
        let recording = Recording(filePath: file.path, foundAt: Date(), status: .readyForYourYes)
        let missing = Recording(filePath: work.appending(path: "gone.mp4").path, foundAt: Date(), status: .readyForYourYes)
        model.context.insert(recording)
        model.context.insert(missing)
        try model.context.save()
        model.checkCapture(recording)
        XCTAssertTrue(model.captureChecking.contains(recording.id))
        let deadline = Date().addingTimeInterval(20)
        while model.captureChecking.contains(recording.id) && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(recording.capture?.audio.count, 1)
        XCTAssertEqual(recording.status, .readyForYourYes, "nothing but the report changes")
        model.checkCapture(missing)
        XCTAssertNil(missing.capture)
        XCTAssertEqual(model.captureProblems[missing.id], "The original is not where it was found, so it cannot be checked.")
    }

    // MARK: Helpers

    private func check(_ file: URL) async throws -> CaptureReport {
        let tools = ToolPaths.standard
        return try await CaptureCheck.run(file: file, tools: tools, now: Date(), measureTrack: { arguments in
            try await Subprocess.run(tools.ffmpeg, arguments, timeout: .seconds(60)).stderr
        })
    }

    /// A small media file, generated by ffmpeg in the temporary folder.
    private func make(_ name: String, _ arguments: [String]) throws -> URL {
        let url = work.appending(path: name)
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-y", "-v", "error"] + arguments + [url.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "ffmpeg could not make \(name)")
        return url
    }
}
