import AVFoundation
import CoreImage
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import Vision
import XCTest
@testable import Prakriti

/// v2 part M11a's acceptance (docs/v2/PLAN.md M11, checks 2, 2b and 3), on the 5-minute excerpts of the REAL talks (PLAN's routine
/// excerpts, `~/Prakriti/Dev/Excerpts`; the whole talks run in M11b, the last part of M11):
///
/// - check 2, the **6 Sep talk with its vertical twin** (`2026-09-06 excerpt 20m to 25m.mp4` and its `-vertical` twin, each cut with
///   `-c copy` from 20:00 of the talk and of its vertical recording): the twin's offset measured and written down; three shorts, each
///   ffprobe 1080 by 1920, 30000/1001, at most 180 s; ebur128 -14 within 1 LU and a true peak at or under -1; the last 5 s decoded;
///   Vision's text recognition on a frame every 2 s reads caption words that are the short's own words; the face's middle inside the
///   middle third of the frame in at least 90% of sampled frames; frames with the safe area drawn on them written for Ivan (they show
///   the talk: measured only, PLAN section 11 D1);
/// - check 2b: on the shorts made from the twin, Vision on a frame every 0.5 s finds no face outside an Included person's matched
///   track or a hidden region (the twin's own face step run again here, its line in the development log);
/// - check 3, the **13 Sep talk** (no twin, 1080p): shorts made from a crop, with the capture warning in Checks (the Checks tab drawn
///   to a picture: it shows no frame of anyone).
///
///   cd ~/Code/prakriti/mac && make accept-shorts MILESTONE=v2-m11a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=shorts. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the originals are only
/// read, checked by size and date before and after. Never a class, never the archive. Nothing goes to a cloud provider: planning is
/// set to LM Studio and the cloud client factory refuses. The parts of each talk come from `BeatsCache` when they were made from the
/// very same transcript. Writes acceptance-shorts.txt.
@MainActor
final class ShortsAcceptanceTests: XCTestCase {
    static let sixth = "2026-09-06 excerpt 20m to 25m.mp4"
    static let sixthTwin = "2026-09-06 excerpt 20m to 25m-vertical.mp4"

    func testShorts() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "shorts" else {
            throw XCTSkip("Reads the 6 Sep and 13 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-shorts MILESTONE=v2-m11a")
        }
        let only = environment["PRAKRITI_SHORTS_ONLY"] ?? ""
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let paths = AppPaths(mode: .development)
        let excerpts = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/Excerpts", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: excerpts, withIntermediateDirectories: true)
        let sixthTalk = paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4")
        let sixthVertical = paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33-vertical.mp4")
        let thirteenthTalk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        for talk in [sixthTalk, sixthVertical, thirteenthTalk] {
            XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
        }
        // The excerpts, cut once with -c copy (PLAN's routine excerpts; the 6 Sep one from 20:00, its twin from the same moment).
        func cut(_ talk: URL, from: Int, into name: String) async throws -> URL {
            let url = excerpts.appending(path: name)
            if !FileManager.default.fileExists(atPath: url.path) {
                _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y", "-ss", String(from), "-i", talk.path, "-t", "300",
                                                                         "-map", "0", "-c", "copy", url.path], captureStdout: false, timeout: .seconds(180))
            }
            return url
        }
        let originals = [sixthTalk, sixthVertical, thirteenthTalk].map { ($0, fingerprint($0)) }
        let sixth = try await cut(sixthTalk, from: 1200, into: Self.sixth)
        let sixthTwin = try await cut(sixthVertical, from: 1200, into: Self.sixthTwin)
        let thirteenth = try await cut(thirteenthTalk, from: 120, into: ViewerVideoAcceptanceTests.excerptName)
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        model.settings.provider[.planning] = .lmStudio
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        model.log.write("Acceptance test for v2 part M11a (shorts) started.")
        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        try model.context.save()

        for (file, label, twin) in [(sixth, "6 Sep", true), (thirteenth, "13 Sep", false)] where only.isEmpty || label.contains(only) {
            lines.append("")
            lines.append("\(label) excerpt: \(file.lastPathComponent)" + (twin ? " with \(sixthTwin.lastPathComponent)" : " (no vertical recording)"))
            let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: file)
            recording.kind = .talk
            try model.context.save()
            model.setTeacher(teacher, for: recording)
            model.setOutput(.shorts, on: true, for: recording)
            let name = file.deletingPathExtension().lastPathComponent
            let folderURL = paths.outputs.appending(path: name, directoryHint: .isDirectory)
            let seeded = BeatsCache.seed(name, folder: folderURL)
            lines.append(seeded.map { "  Parts of the talk from the cache: \($0.line)" } ?? "  No cached parts for this transcript: the make asks Qwen3.8-27B in LM Studio.")
            let started = Date()
            await model.runner.process(recording, trigger: .byHand)
            let step = recording.latestRun?.steps.first { $0.name == PipelineStep.shorts.title }
            lines.append(String(format: "  Made in development in %.0f s. Step %@: %@, %@", Date().timeIntervalSince(started), PipelineStep.shorts.title,
                                step?.state.rawValue ?? "not run", step?.detail ?? ""))
            if seeded == nil, let data = try? Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard)), let heard = PlanWords.from(json: data),
               let made = BeatsFile.cached(in: folderURL, transcriptSHA256: heard.transcriptSHA256) {
                try? BeatsCache.write(made)
                lines.append("  Parts made in the make: \(made.line)")
            }
            guard let record = model.shortsRecord(recording), let folder = model.shortsFolder(recording) else {
                verdict("\(label): the shorts were made", false, model.shortsProblems[recording.id] ?? recording.statusReason ?? "no record")
                continue
            }
            for note in record.notes { lines.append("  Note: \(note)") }
            let plan = try XCTUnwrap(EditPlan.read(folder: folderURL.path))
            let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard))))

            if twin {
                let offset = record.twin
                verdict("Check 2: the twin's audio offset measured and written down, within one frame at three moments, and the shorts drawn from it",
                        record.source == .vertical && offset?.lines(frame: plan.frameDuration.seconds) == true,
                        "\(record.source.rawValue); " + (offset?.line ?? "not measured")
                            + (offset.map { "; points " + $0.points.map { String(format: "%.4f s", $0) }.joined(separator: ", ") } ?? ""))
                verdict("Check 2: three shorts", record.shorts.count == 3, "\(record.shorts.count): " + record.shorts.map { "short \($0.number) \(Format.timecode($0.duration)) (part \($0.beat))" }.joined(separator: ", "))
            } else {
                verdict("Check 3: shorts made from a crop of the 1080p picture", record.source == .crop1080 && !record.shorts.isEmpty,
                        "\(record.source.rawValue), \(record.shorts.count) shorts")
                verdict("Check 3: the capture warning is in the record Checks shows", record.warning == Shorts.softWarning, record.warning ?? "none")
                // The Checks tab drawn as the inspector draws it: words only, no frame of anyone.
                let renderer = try SnapshotRenderer(outputFolder: out)
                for (scheme, appearance) in SnapshotRenderer.appearances {
                    try renderer.renderSheet(AnyView(ChecksTab(recording: recording).frame(width: 400, height: 1468)), model: model, size: CGSize(width: 400, height: 1500),
                                             appearance: appearance, name: "m11a-checks-13sep-shorts-\(scheme)")
                }
                verdict("Check 3: the Checks tab shows the warning (drawn to a picture to look at)", model.shortsWarning(recording) == Shorts.softWarning,
                        out.appending(path: "m11a-checks-13sep-shorts-light.png").path)
            }

            for (short, url) in model.shortFiles(recording) {
                let tag = "\(label) short \(short.number)"
                let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-select_streams", "v:0", "-show_entries",
                                                                                  "stream=width,height,r_frame_rate:format=duration", "-of", "compact=p=0", url.path],
                                                     timeout: .seconds(60)).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let duration = Double(probe.components(separatedBy: "duration=").last?.prefix { "0123456789.".contains($0) } ?? "") ?? 0
                verdict("Check 2: \(tag) is 1080 by 1920, 29.97, at most 180 s", probe.contains("width=1080") && probe.contains("height=1920")
                            && probe.contains("r_frame_rate=30000/1001") && duration > 0 && duration <= 180, probe.replacingOccurrences(of: "\n", with: " | "))
                let loud = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-nostats", "-i", url.path, "-vn", "-af", "ebur128=peak=true", "-f", "null", "-"],
                                                    captureStdout: false, timeout: .seconds(120)).stderr
                let loudness = Measure.ebur128(stderr: loud)
                verdict("Check 2: \(tag) is -14 LUFS within 1, true peak at or under -1", loudness.map { abs($0.integratedLUFS + 14) <= 1 && $0.truePeakDBFS <= -1 } ?? false,
                        loudness.map { String(format: "%.1f LUFS, %.1f dBTP", $0.integratedLUFS, $0.truePeakDBFS) } ?? "not measured")
                let tail = try? await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-sseof", "-5", "-i", url.path, "-f", "null", "-"],
                                                     captureStdout: false, timeout: .seconds(60))
                verdict("Check 2: \(tag)'s last 5 s decode", tail != nil && (tail?.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false),
                        tail.map { $0.stderr.isEmpty ? "no error" : $0.stderr } ?? "ffmpeg failed")

                // Frames: every 0.5 s for faces, every 2 s for the captions.
                let shortWords = Set(words.words[short.firstWord...short.lastWord].map { Self.norm($0.text) }.filter { !$0.isEmpty })
                let measured = try await measureFrames(url, duration: duration, words: shortWords, forIvan: forIvan, tag: tag)
                verdict("Check 2: \(tag): Vision reads caption words that are the short's own words (a frame every 2 s)",
                        measured.textFrames >= measured.textSampled / 2 && measured.wordsRead > 0 && Double(measured.wordsMatched) / Double(max(1, measured.wordsRead)) >= 0.9,
                        String(format: "%d of %d frames with caption text; %d of %d words read are the short's own (%.0f%%); e.g. \u{201C}%@\u{201D}",
                               measured.textFrames, measured.textSampled, measured.wordsMatched, measured.wordsRead,
                               100 * Double(measured.wordsMatched) / Double(max(1, measured.wordsRead)), measured.example))
                verdict("Check 2: \(tag): the face's middle inside the middle third in at least 90% of sampled frames (every 0.5 s)",
                        measured.faceFrames > 0 && Double(measured.middle) / Double(measured.faceFrames) >= 0.9,
                        String(format: "%d of %d frames with a face (%.1f%%); planned %@; %@", measured.middle, measured.faceFrames,
                               100 * Double(measured.middle) / Double(max(1, measured.faceFrames)), short.middleShare.map { String(format: "%.1f%%", $0 * 100) } ?? "not cropped",
                               measured.spread))
                verdict("Check 2: \(tag): every caption box inside the safe area (measured by Core Text when made, and every caption line Vision reads on the frames)",
                        short.lines.first { $0.item == "Captions" }?.status == .pass && measured.inkOutside == 0,
                        "\(short.lines.first { $0.item == "Captions" }?.detail ?? "no line"); caption lines Vision read outside the safe area: \(measured.inkOutside) \(measured.outside.joined(separator: "; ")); frames with the safe area drawn, for Ivan (measured only): \(measured.pictures.joined(separator: ", "))")
                lines.append("  \(tag): \(short.fileName), \(Format.timecode(short.duration)), \(short.bytes) bytes, part \(short.beat), made in \(Format.length(short.renderSeconds)); checklist: \(short.summaryLine). Opens: \u{201C}\(short.opening)\u{201D}")
            }
            _ = folder

            if twin {
                // Check 2b: the twin's own face step, run again here, and Vision on every short's frames every 0.5 s.
                let logText = model.log.todayFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
                verdict("Check 2b: the twin's own people step ran (the development log says so)", logText.contains("the vertical recording's own face step ran"),
                        logText.components(separatedBy: "\n").last { $0.contains("own face step ran") } ?? "no line")
                let people = model.videoPeople(recording)
                let peopleFile = model.peopleFolders.read(recording.id)
                for (short, url) in model.shortFiles(recording) {
                    let shortPlan = Shorts.plan(plan, window: short.window)
                    var timeline = EditTimeline(plan: shortPlan)
                    let offset = try XCTUnwrap(record.twin)
                    timeline.pieces = timeline.pieces.map { var p = $0; p.sourceFrame += offset.frames; return p }
                    let first = Double(timeline.pieces.first?.sourceFrame ?? 0) * plan.frameDuration.seconds
                    let last = Double(timeline.pieces.last.map { $0.sourceFrame + $0.frames } ?? 0) * plan.frameDuration.seconds
                    let found = try await TwinFaces.run(twin: sixthTwin, range: max(0, first - 1)...(last + 1), main: peopleFile, offset: offset.seconds)
                    func shown(_ row: Int) -> Bool { people.choices.choice(PersonKey.face(row, names: people.names), for: .shorts) == .include }
                    let hidden = try await VideoHiding.make(original: sixthTwin, plan: TwinFaces.hidePlan(found) { shown($0) }, timeline: timeline, planMadeAt: plan.madeAt)
                    let check = try await PictureOutputCheck.run(mp4: url, timeline: timeline, hidden: hidden, tracks: TwinFaces.checkTracks(found) { shown($0) },
                                                                 now: Date(), rate: 2)
                    verdict("Check 2b: \(label) short \(short.number): Vision every 0.5 s finds no face outside an Included person's matched track or a hidden region",
                            check.passed && check.frames > 0,
                            "\(check.frames) frames, \(check.faces) faces, \(check.included) someone included, \(check.findings.count) not accounted for; \(found.line); the make's own check: \(short.pictureCheck?.line ?? "none")")
                }
            }
        }

        verdict("Nothing reached a cloud provider", cloudCalls.count == 0, "\(cloudCalls.count) calls")
        verdict("The originals are unchanged (size and modification date)", originals.allSatisfy { fingerprint($0.0) == $0.1 },
                originals.map { "\($0.0.lastPathComponent): \(fingerprint($0.0))" }.joined(separator: "; "))
        let text = (["v2 part M11a acceptance (shorts), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed.",
                       "Frames for Ivan (measured only, they show the talk): \(forIvan.path)"]).joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-shorts.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M11a finished.")
    }

    // MARK: Measuring

    static func norm(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || $0 == "'" })
    }

    struct Measured {
        var textSampled = 0
        var textFrames = 0
        var wordsRead = 0
        var wordsMatched = 0
        var example = ""
        var faceFrames = 0
        var middle = 0
        var inkOutside = 0
        var outside: [String] = []
        var xs: [Double] = []
        /// The face's middle across the frame: the 5th, 50th and 95th percentile.
        var spread: String {
            let v = xs.sorted()
            guard !v.isEmpty else { return "no face" }
            func q(_ p: Double) -> Double { v[min(v.count - 1, Int(p * Double(v.count)))] }
            return String(format: "x %.2f / %.2f / %.2f (5th, 50th, 95th percentile)", q(0.05), q(0.5), q(0.95))
        }
        var pictures: [String] = []
    }

    /// Reads the short's frames: every 0.5 s Vision's faces (the largest face's middle against the middle third), every 2 s Vision's
    /// text in the caption band, and three frames written with the safe area drawn on them (for Ivan; never looked at here).
    private func measureFrames(_ url: URL, duration: Double, words: Set<String>, forIvan: URL, tag: String) async throws -> Measured {
        var m = Measured()
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let faces = DetectFaceRectanglesRequest(.revision4)
        var text = RecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = false
        var t = 0.25
        var k = 0
        let saved: Set<Int> = [4, Int(duration), Int(duration * 2) - 6]
        while t < duration - 0.1 {
            let image = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image
            let found = try await faces.perform(on: image)
            if let face = found.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                m.faceFrames += 1
                let x = face.boundingBox.cgRect.midX
                m.xs.append(x)
                if x >= 1.0 / 3.0 && x <= 2.0 / 3.0 { m.middle += 1 }
            }
            if k % 4 == 0 {
                m.textSampled += 1
                // Every line of text Vision reads in the frame; the captions are the lines in the caption band (y 1060 to 1570 of
                // 1920), and any line whose words are the short's own must sit inside the safe area.
                var inBand = false
                for observation in try await text.perform(on: image) {
                    guard let read = observation.topCandidates(1).first?.string else { continue }
                    let tokens = read.split(separator: " ").map { Self.norm(String($0)) }.filter { $0.count >= 2 }
                    guard !tokens.isEmpty else { continue }
                    let matched = tokens.filter { t in words.contains(t) || words.contains { $0.hasPrefix(t) || t.hasPrefix($0) } }.count
                    let box = observation.boundingBox.cgRect
                    let top = (1 - box.maxY) * 1920, bottom = (1 - box.minY) * 1920, left = box.minX * 1080, right = box.maxX * 1080
                    let middle = (top + bottom) / 2
                    if middle >= 1060 && middle <= 1570 {
                        inBand = true
                        m.wordsRead += tokens.count
                        m.wordsMatched += matched
                        if m.example.isEmpty { m.example = read }
                    }
                    // A caption line: mostly the short's own words, and near where captions sit (y 950 to 1750), so text in the room
                    // (a banner reading "RETREAT" at y 760, measured 16 Oct) is not taken for one.
                    if Double(matched) >= 0.6 * Double(tokens.count), middle >= 950 && middle <= 1750,
                       !BurnedCaptions.safe.insetBy(dx: -4, dy: -4).contains(CGRect(x: left, y: top, width: right - left, height: bottom - top)) {
                        m.inkOutside += 1
                        if m.outside.count < 4 {
                            m.outside.append(String(format: "\u{201C}%@\u{201D} at %.1f s, x %.0f to %.0f, y %.0f to %.0f", read, t, left, right, top, bottom))
                        }
                    }
                }
                if inBand { m.textFrames += 1 }
            }
            if saved.contains(k) {
                let png = forIvan.appending(path: "m11a-\(tag.replacingOccurrences(of: " ", with: "-"))-\(k).png")
                try Self.writeWithSafeArea(image, to: png)
                m.pictures.append(png.lastPathComponent)
            }
            k += 1
            t += 0.5
        }
        return m
    }

    static func writeWithSafeArea(_ image: CGImage, to url: URL) throws {
        let w = image.width, h = image.height
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let safe = BurnedCaptions.safe
        context.setStrokeColor(CGColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
        context.setLineWidth(4)
        context.stroke(CGRect(x: safe.minX, y: CGFloat(h) - safe.maxY, width: safe.width, height: safe.height))
        try StyleTests.writePNG(context.makeImage()!, to: url)
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
