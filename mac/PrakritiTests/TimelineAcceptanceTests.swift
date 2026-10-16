import AVFoundation
import Foundation
import ImageIO
import Synchronization
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M10a's acceptance (docs/v2/PLAN.md M10, checks 2 and 4), on the REAL 13 Sep talk's 5-minute excerpt (PLAN's routine
/// excerpts, `~/Prakriti/Dev/Excerpts`), made in development through the app's runner with the edited video and the Timelines on,
/// the House Style at its standard (Clear), a test title in Info and Gabriel named as teaching (development store only), and the
/// parts of the talk from Qwen3.8-27B in LM Studio (read from `BeatsCache` when they were made from this very transcript):
///
/// - check 2: both files valid against Final Cut Pro's own DTDs and clean under the lint in place; every `media-rep src` inside the
///   recording's Timeline folder (the recording under `Media/`, the texts and the held frame under `Graphics/`), none in the
///   Studio Recordings folder or at the original; every `Media/` file a clone of its source, proved per file by the volume's own
///   record (getattrlist: the same clone id, 0 bytes of its own), never by free space; the timeline the video's length in frames,
///   its texts the plan's, its chapters the plan's, its push-ins markers;
/// - check 4: every `Graphics/` clip ProRes 4444 with an alpha channel (ffprobe), its last frames decoded; one frame of each text
///   written as a PNG to look at (text only, on transparency: no picture of anyone); the held last frame measured only (it shows
///   the talk), its path listed for Ivan;
/// - Make Timelines again from the video already made (no make), then the refusal: the teacher set to Hide Face, and nothing is
///   written ("A timeline for a recording with hidden people arrives in the next update.").
///
///   cd ~/Code/prakriti/mac && make accept-timeline MILESTONE=v2-m10a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=timeline. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the original is only
/// read, checked by size and date before and after. Never a class, never the archive. Nothing goes to a cloud provider: planning is
/// set to LM Studio and the cloud client factory refuses. Writes acceptance-timeline.txt, and the Resolve file's path to
/// ~/Prakriti/Dev/resolve-import.txt for `scripts/resolve-import.py` (PLAN check 5).
@MainActor
final class TimelineAcceptanceTests: XCTestCase {
    func testTimelinesForTheThirteenthOfSeptember() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "timeline" else {
            throw XCTSkip("Reads the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-timeline MILESTONE=v2-m10a")
        }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dev = home.appending(path: "Prakriti/Dev", directoryHint: .isDirectory)
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
        let excerpt = dev.appending(path: "Excerpts").appending(path: ViewerVideoAcceptanceTests.excerptName)
        if !FileManager.default.fileExists(atPath: excerpt.path) {
            try FileManager.default.createDirectory(at: excerpt.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y", "-ss", "120", "-i", talk.path, "-t", "300",
                                                                     "-map", "0", "-c", "copy", excerpt.path], captureStdout: false, timeout: .seconds(120))
        }
        let before = fingerprint(talk), excerptBefore = fingerprint(excerpt)
        let out = SnapshotRenderer.milestoneFolder()
        let looks = out.appending(path: "graphics", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: looks)
        try FileManager.default.createDirectory(at: looks, withIntermediateDirectories: true)

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        model.settings.provider[.planning] = .lmStudio
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        XCTAssertEqual(model.settings.houseStyle, .standard, "Clear, the House Style at its standard")
        model.log.write("Acceptance test for v2 part M10a (timelines) started.")
        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        let recording = Recording(filePath: excerpt.path, recordedAt: AppModel.dateInName(excerpt.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: excerpt)
        recording.kind = .talk
        recording.title = TextAcceptanceTests.testTitle
        try model.context.save()
        model.setTeacher(teacher, for: recording)
        model.setOutput(.editedVideo, on: true, for: recording)
        model.setOutput(.timelines, on: true, for: recording)
        let name = excerpt.deletingPathExtension().lastPathComponent
        let folderURL = paths.outputs.appending(path: name, directoryHint: .isDirectory)
        let seeded = BeatsCache.seed(name, folder: folderURL)
        lines.append(seeded.map { "Beats from the cache: \($0.line)" } ?? "No cached beats for this transcript: the make asks Qwen3.8-27B in LM Studio.")

        var started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let video = try XCTUnwrap(recording.video, "the video was made (\(recording.videoProblem ?? recording.statusReason ?? "no reason"))")
        let folder = try XCTUnwrap(recording.outputFolder)
        precondition(folder.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        if seeded == nil, let data = try? Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard)), let heard = PlanWords.from(json: data),
           let made = BeatsFile.cached(in: folderURL, transcriptSHA256: heard.transcriptSHA256) {
            try? BeatsCache.write(made)
            lines.append("Beats made in the make: \(made.line)")
        }
        let plan = try XCTUnwrap(EditPlan.read(folder: folder))
        let timelineStep = recording.latestRun?.steps.first { $0.name == PipelineStep.timelines.title }
        lines.append("")
        lines.append(String(format: "13 Sep excerpt, Clear: made in development in %.0f s; %@", Date().timeIntervalSince(started), plan.summary))
        lines.append("  \(plan.pictureSummary ?? "no picture line")")
        lines.append("  Video: \(video.fileName), \(Format.timecode(video.duration)), \(video.frames) frames; Ready checklist: \(video.summary)")
        lines.append("  Step \(PipelineStep.timelines.title): \(timelineStep?.state.rawValue ?? "not run"), \(timelineStep?.detail ?? "")")
        let timeline = folderURL.appending(path: TimelineExport.folderName, directoryHint: .isDirectory)
        let record = try XCTUnwrap(TimelineExport.Record.read(timeline), "the timelines were written (\(model.timelineProblems[recording.id] ?? "no reason"))")
        lines.append("  Timeline folder: \(timeline.path)")
        lines.append("  Files: " + Pipeline.madeFiles(in: timeline).joined(separator: ", "))
        verdict("The make wrote the timelines in its own step, after the video", timelineStep?.state == .done && recording.madeFiles.contains(TimelineExport.folderName),
                "\(timelineStep?.state.rawValue ?? "none"); made files include Timeline: \(recording.madeFiles.contains(TimelineExport.folderName))")

        // Check 2: both files valid, the lint clean in place.
        let dtds = try XCTUnwrap(try FCPXMLTests.dtds(), "Final Cut Pro's DTDs")
        var xmls: [FCPXMLVersion: String] = [:]
        for version in FCPXMLVersion.allCases {
            let file = timeline.appending(path: version.fileName)
            let xml = try String(contentsOf: file, encoding: .utf8)
            xmls[version] = xml
            let dtd = await FCPXMLLint.validate(file, version: version, dtds: dtds)
            verdict("Check 2: \(version.fileName) is valid against Final Cut Pro's \(version.dtdName) (xmllint --dtdvalid)", dtd == nil, dtd ?? "valid")
            let problems = FCPXMLLint.check(xml)
            verdict("Check 2: \(version.fileName) passes the lint in place (frames, spine, length, refs, every src there, handles, captions)", problems.isEmpty,
                    problems.isEmpty ? "0 problems" : problems.map(\.description).joined(separator: "; "))
        }
        verdict("Check 2: the record's DTD checks", record.dtd == ["1.14": "valid", "1.10": "valid"], "\(record.dtd)")
        let finalCut = try XCTUnwrap(xmls[.finalCut])
        verdict("Check 2: the two files differ only in their version", finalCut.replacingOccurrences(of: "version=\"1.14\"", with: "version=\"1.10\"") == xmls[.resolve], "")

        // Every src inside the Timeline folder; never the Studio Recordings folder or the original.
        let document = try XMLDocument(xmlString: finalCut, options: [])
        let srcs = ((try? document.nodes(forXPath: "//media-rep/@src")) ?? []).compactMap(\.stringValue).compactMap { URL(string: $0) }
        let media = timeline.appending(path: TimelineMedia.folderName).path + "/", graphics = timeline.appending(path: GraphicsClips.folderName).path + "/"
        let recordingSrcs = srcs.filter { $0.pathExtension == "mp4" }
        verdict("Check 2: every media-rep src is under the version's Media/ (the recording) or Graphics/ (the texts and the held frame)",
                srcs.allSatisfy { $0.path.hasPrefix(media) || $0.path.hasPrefix(graphics) } && recordingSrcs.allSatisfy { $0.path.hasPrefix(media) } && !recordingSrcs.isEmpty,
                "\(srcs.count) sources: \(recordingSrcs.count) under Media/, \(srcs.filter { $0.path.hasPrefix(graphics) }.count) under Graphics/")
        let studio = xmls.values.reduce(0) { $0 + $1.components(separatedBy: "Studio Recordings").count - 1 + $1.components(separatedBy: "Studio%20Recordings").count - 1 }
        let original = xmls.values.reduce(0) { $0 + $1.components(separatedBy: FCPXMLWriter.fileURL(excerpt)).count - 1 + $1.components(separatedBy: excerpt.path).count - 1 }
        verdict("Check 2: neither file names the Studio Recordings folder or the original", studio == 0 && original == 0, "\(studio) and \(original)")

        // Clones, per file.
        for file in Pipeline.madeFiles(in: timeline.appending(path: TimelineMedia.folderName)) {
            let copy = timeline.appending(path: TimelineMedia.folderName).appending(path: file)
            let a = TimelineMedia.cloneFacts(copy), b = TimelineMedia.cloneFacts(excerpt)
            let bytes = (try? copy.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            verdict("Check 2: Media/\(file) is a clone of its source, proved by the file itself (getattrlist)", TimelineMedia.isClone(copy, of: excerpt),
                    "clone id \(a?.cloneID ?? 0) and the source's \(b?.cloneID ?? 0); \(a?.privateBytes ?? -1) of its \(bytes) bytes its own; \(a?.references ?? 0) files share its blocks")
        }

        // The timeline is the video's edit.
        let made = EditTimeline(plan: plan, pictureFrames: try await CompositionBuilder.pictureFrames(original: excerpt, plan: plan))
        // The video's own clock: its length over the frame (the writer shows the held frame at the hold's start for two frame times
        // twice, so its packets can be fewer than its frame times; measured 15 Oct, M9a's writer).
        let videoFrames = Int64((video.duration / plan.frameDuration.seconds).rounded())
        verdict("The timeline is the video's length, in frames", record.frames == made.totalFrames && record.frames == videoFrames,
                String(format: "%lld frames (%.3f s); the video %.3f s = %lld frame times (%d pictures written)", record.frames, record.seconds, video.duration,
                       videoFrames, video.frames))
        let texts = plan.visual.filter(\.isText)
        verdict("Every text of the plan is a graphics clip with its editable copy switched off", record.graphics == texts.count
                    && finalCut.components(separatedBy: "enabled=\"0\"").count - 1 == texts.count,
                "\(record.graphics) clips for \(texts.count) texts (\(texts.map(\.kind).joined(separator: ", ")))")
        verdict("Every chapter of the plan is a chapter marker", record.chapters == plan.chapters.count, "\(record.chapters) of \(plan.chapters.count)")
        let pushes = plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }.count, punches = plan.visual.filter { $0.kind == EditPlan.Visual.punchIn }.count
        verdict("Punch-ins are static transforms; push-ins are markers, never animation", record.pushInMarkers <= pushes && !finalCut.contains("keyframeAnimation")
                    && finalCut.contains("<adjust-transform ") == (punches > 0),
                "\(punches) punch-ins, \(finalCut.components(separatedBy: "<adjust-transform ").count - 1) clips with a transform; \(pushes) push-ins, \(record.pushInMarkers) markers")
        lines.append("  Timeline: \(record.summary) \(record.captions) caption pieces, \(record.markers) markers; media cloned: \(record.mediaCloned)")
        let readMe = try String(contentsOf: timeline.appending(path: TimelineReadMe.fileName), encoding: .utf8)
        verdict("Read Me.txt: five lines, no dashes", readMe.split(separator: "\n").count == 5 && !readMe.contains("\u{2014}") && !readMe.contains("\u{2013}"),
                readMe.replacingOccurrences(of: "\n", with: " | "))
        verdict("The captions beside the files are the video's own", (try? Data(contentsOf: timeline.appending(path: record.captionsName)))
                    == (try? Data(contentsOf: folderURL.appending(path: VideoStep.folderName).appending(path: video.captionsName))), record.captionsName)

        // Check 4: the graphics clips.
        let graphicsFolder = timeline.appending(path: GraphicsClips.folderName, directoryHint: .isDirectory)
        for file in Pipeline.madeFiles(in: graphicsFolder) {
            let url = graphicsFolder.appending(path: file)
            let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-select_streams", "v:0", "-count_frames", "-show_entries",
                                                                              "stream=codec_name,profile,pix_fmt,width,height,r_frame_rate,nb_read_frames",
                                                                              "-of", "compact=p=0", url.path], timeout: .seconds(120)).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let tail = await TimelineMedia.tailFrames(url)
            if file.hasPrefix(GraphicsClips.heldName) {
                verdict("The held last frame is a ProRes clip as long as the video's hold (measured only: it shows the talk)",
                        probe.contains("codec_name=prores") && probe.contains("nb_read_frames=\(made.holdFrames)") && tail > 0,
                        "\(probe); \(made.holdFrames) frames held; for Ivan: \(url.path)")
                continue
            }
            verdict("Check 4: \(file) is ProRes 4444 with an alpha channel, decoded to its end", probe.contains("codec_name=prores") && probe.contains("profile=4444")
                        && probe.contains("pix_fmt=yuva444p") && tail > 0, "\(probe); last frames decoded: \(tail)")
            // Its middle frame, decoded by ffmpeg with its alpha: the transparency measured by counting pixels, and the frame laid
            // over a dark grey with Core Graphics (so the white letters and their shadow both show) as a PNG to look at.
            let frames = Int(probe.components(separatedBy: "nb_read_frames=").last.flatMap { Int($0.prefix { $0.isNumber }) } ?? 30)
            let png = looks.appending(path: file.replacingOccurrences(of: ".mov", with: ".png"))
            let rgba = FileManager.default.temporaryDirectory.appending(path: "m10a-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: rgba) }
            _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-v", "error", "-y", "-i", url.path, "-vf", "select=eq(n\\,\(frames / 2))", "-frames:v", "1",
                                                                     "-pix_fmt", "rgba", rgba.path], captureStdout: false, timeout: .seconds(60))
            var opaque = 0, clear = 0
            if let source = CGImageSourceCreateWithURL(rgba as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let bytes = FCPXMLTests.rgba(image)
                for k in stride(from: 3, to: bytes.count, by: 4) { if bytes[k] == 255 { opaque += 1 } else if bytes[k] == 0 { clear += 1 } }
                let context = CGContext(data: nil, width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: 1920 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.setFillColor(CGColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1080))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
                try StyleTests.writePNG(context.makeImage()!, to: png)
            }
            verdict("Check 4: \(file) is transparent but for its text", clear > 1920 * 1080 * 9 / 10 && opaque > 500,
                    String(format: "middle frame: %d pixels clear (%.1f%%), %d opaque; picture to look at: %@", clear, Double(clear) / 20_736, opaque, png.path))
        }

        // Make Timelines again from the video already made, then the refusal.
        started = Date()
        let again = await model.writeTimelines(recording)
        let second = TimelineExport.Record.read(timeline)
        verdict("Make Timelines (no make): written again from the video already made, through the gate", again && (second?.madeAt ?? .distantPast) > record.madeAt
                    && TimelineMedia.isClone(timeline.appending(path: TimelineMedia.folderName).appending(path: excerpt.lastPathComponent), of: excerpt),
                String(format: "%.1f s; %@", Date().timeIntervalSince(started), second?.summary ?? "none"))
        let choices = model.setChoice(.hideFace, for: .named(teacher.id), in: recording)
        let refusal = model.timelineRefusal(recording)
        let kept = TimelineExport.Record.read(timeline)
        let refused = await model.writeTimelines(recording)
        verdict("Refused with the teacher set to Hide Face: nothing written, the reason in words", refusal == TimelineExport.hiddenRefusal && !refused
                    && TimelineExport.Record.read(timeline) == kept && model.timelineProblems[recording.id] == TimelineExport.hiddenRefusal,
                refusal ?? "no refusal")
        model.restoreChoices(choices, in: recording)
        verdict("Nothing reached a cloud provider", cloudCalls.count == 0, "\(cloudCalls.count) calls")
        verdict("The original and the excerpt are unchanged (size and modification date)", fingerprint(talk) == before && fingerprint(excerpt) == excerptBefore,
                fingerprint(talk) + "; " + fingerprint(excerpt))

        try timeline.appending(path: FCPXMLVersion.resolve.fileName).path.write(to: dev.appending(path: "resolve-import.txt"), atomically: true, encoding: .utf8)
        let layout = "\(record.clips) \(record.frames)"
        try layout.write(to: dev.appending(path: "resolve-import-expected.txt"), atomically: true, encoding: .utf8)
        let text = (["v2 part M10a acceptance (timelines), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed.",
                       "Graphics frames to look at (text only): \(looks.path)"]).joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-timeline.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M10a finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
