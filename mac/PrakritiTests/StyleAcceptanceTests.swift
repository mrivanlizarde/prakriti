import AVFoundation
import Foundation
import SwiftData
import Vision
import XCTest
@testable import Prakriti

/// v2 part M9a's acceptance (docs/v2/PLAN.md M9, the checks part M9a runs: 3 with Clear's punch-in scales and its visual changes
/// counted from cuts and punch changes only, and 4's eye line in punch-ins), on the REAL 13 Sep talk: first the 5-minute
/// excerpt (`~/Prakriti/Dev/Excerpts/`, PLAN's routine excerpts), then the whole talk, each made in development through the
/// app's runner with the edited video on and the House Style at its standard (Clear, Balanced, Standard punch-ins, room at the
/// end). Numbers only for the talk (PLAN rule 2.1.9 and D1 as this run was told): the plan counted, the MP4's frames at three
/// punch-ins and a push-in measured by Vision's pupils and by PSNR against the original framed by Core Graphics; the frames are
/// written to `for-ivan/` for Ivan and not looked at here.
///
///   cd ~/Code/prakriti/mac && make accept-style MILESTONE=v2-m9a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=style. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the original is only
/// read, checked by size and date before and after. Never a class, never the archive.
@MainActor
final class StyleAcceptanceTests: XCTestCase {
    func testTheHouseStyleOnTheThirteenthOfSeptember() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "style" else {
            throw XCTSkip("Reads the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-style MILESTONE=v2-m9a")
        }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dev = home.appending(path: "Prakriti/Dev", directoryHint: .isDirectory)
        let paths = AppPaths(mode: .development)
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path), "missing: \(talk.path)")
        XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
        let before = fingerprint(talk)
        let excerpt = dev.appending(path: "Excerpts").appending(path: ViewerVideoAcceptanceTests.excerptName)
        if !FileManager.default.fileExists(atPath: excerpt.path) {
            try FileManager.default.createDirectory(at: excerpt.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y", "-ss", "120", "-i", talk.path, "-t", "300",
                                                                     "-map", "0", "-c", "copy", excerpt.path], captureStdout: false, timeout: .seconds(120))
        }
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        // The parts of the talk are v2 part M9d's: this check measures what it always measured, with no model asked for them.
        model.runner.askForBeats = false
        XCTAssertEqual(model.settings.houseStyle, .standard, "the House Style starts at its standard: Clear, Balanced, Standard punch-ins, room at the end")
        model.log.write("Acceptance test for v2 part M9a (house style and zooms) started.")

        let only = environment["PRAKRITI_STYLE_ONLY"] ?? ""
        for (slug, file) in [("13 Sep excerpt", excerpt), ("13 Sep", talk)] where only.isEmpty || only == slug {
            let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: file)
            recording.kind = .talk
            try model.context.save()
            model.setOutput(.editedVideo, on: true, for: recording)
            let started = Date()
            await model.runner.process(recording, trigger: .byHand)
            let record = try XCTUnwrap(recording.video, "\(slug): the video was made (\(recording.videoProblem ?? recording.statusReason ?? "no reason"))")
            let folder = try XCTUnwrap(recording.outputFolder)
            precondition(folder.hasPrefix(paths.outputs.path + "/"), "development outputs only")
            let plan = try XCTUnwrap(EditPlan.read(folder: folder))
            let timeline = EditTimeline(plan: plan)
            let mp4 = URL(fileURLWithPath: folder).appending(path: VideoStep.folderName).appending(path: record.fileName)
            let render = recording.latestRun?.steps.first { $0.name == PipelineStep.renderVideo.title }
            lines.append("")
            lines.append(String(format: "%@: made in development in %.0f s (the video step %.1f s for %@); %@", slug, Date().timeIntervalSince(started),
                                render?.seconds ?? 0, Format.timecode(record.duration), plan.summary))
            lines.append("  Ready checklist: \(record.summary)" + (record.failed > 0 ? ": " + record.checklist.filter { $0.status == .fail }.map(\.text).joined(separator: "; ") : ""))

            // The source's own picture height (the punch-in budget is measured, not assumed).
            let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=height",
                                                                              "-of", "csv=p=0", file.path], timeout: .seconds(60)).stdout
            let height = Int(probe.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            // Check 3 (Clear), counted from the plan: cuts and punch changes only (text arrives in M9b).
            let count = VisualPlan.count(plan)
            let scales = plan.visual.compactMap { $0.kind == EditPlan.Visual.punchIn ? $0.scale : nil }
            lines.append(String(format: "  Picture: %.2f min, %d shots, %d punch-ins (scales %@), %d push-ins, median shot %.1f s, held ending %.2f s",
                                count.minutes, count.changes + 1, count.punchIns, Set(scales).sorted().map { String(format: "%.2f", $0) }.joined(separator: ", "),
                                count.pushIns, count.medianShot, count.holdSeconds))
            let rate = String(format: "%d changes in %.2f min, %.2f a minute (%d cuts, %.2f a minute before any punch-in; %d changes of punch-in inside a span)",
                              count.changes, count.minutes, count.perMinute, timeline.pieces.count - 1, Double(timeline.pieces.count - 1) / max(count.minutes, 0.01),
                              count.changes - (timeline.pieces.count - 1))
            if slug.hasSuffix("excerpt") {
                // Measured, not the bar: PLAN check 3 names the whole talk, and this 5-minute stretch cannot hold both of
                // Clear's rate bars: its own 33 cuts are already 6.95 a minute, and the 7 changes of punch-in the first 30 s
                // would need to reach 10 make 40, 8.4 a minute over 4.75 minutes. The whole talk below is the gate.
                lines.append((((6...8).contains(count.perMinute)) ? "  Within" : "  Outside") + " 6 to 8 a minute on the excerpt (measured, not the bar): " + rate)
                lines.append("  Visual changes in the first 30 s of the excerpt (measured, not the bar): \(count.changesFirst30)")
            } else {
                verdict("\(slug) check 3 (Clear): 6 to 8 visual changes a minute (cuts and punch changes)", (6...8).contains(count.perMinute), rate)
                verdict("\(slug) check 3 (Clear): 10 or more visual changes in the first 30 s", count.changesFirst30 >= 10, "\(count.changesFirst30)")
            }
            verdict("\(slug) check 3 (Clear): every punch-in scale at most 1.15 (\(height)p source)", height == 1080 && count.largestScale <= 1.15 + 1e-9 && !scales.isEmpty,
                    String(format: "source %dp; largest %.3f of %d punch-ins and %d push-ins", height, count.largestScale, count.punchIns, count.pushIns))
            let shots = VisualPlan.shots(plan, timeline: timeline)
            var run = 0, worstRun = 0, same = 0
            for (a, b) in zip(shots, shots.dropFirst()) {
                if a.scale == b.scale { same += 1 }
                run = b.scale > 1 ? run + 1 : 0
                worstRun = max(worstRun, run)
            }
            verdict("\(slug) research 2.3: the scales alternate, back to wide within 3 tight shots, the last shot wide",
                    worstRun <= 3 && shots.last?.scale == 1,
                    "\(same) of \(shots.count - 1) changes keep the same scale (a cut with no face seen on either side), longest tight run \(worstRun), last shot \(shots.last?.scale ?? 0)")
            verdict("\(slug): speech ends 5 s before the last frame (within a frame)", abs(count.afterLastWord - 5) <= plan.frameDuration.seconds + 1e-6,
                    String(format: "%.3f s after the last kept word's end; the last frame held %.3f s", count.afterLastWord, count.holdSeconds))
            verdict("\(slug): the file is the kept spans plus the held ending", abs(record.duration - timeline.duration) <= plan.frameDuration.seconds + 0.0005,
                    String(format: "MP4 %.3f s, plan %.3f s", record.duration, timeline.duration))

            // Check 4: the eye line in punch-ins (and a push-in at its end), measured by Vision on the made frames.
            let framing = Framing(plan: plan, timeline: timeline)
            let punches = framing.segments.filter { $0.easeFrames == 0 }
            var chosen = [punches.first, punches.isEmpty ? nil : punches[punches.count / 2], punches.last].compactMap { $0 }
            if let push = framing.segments.first(where: { $0.easeFrames > 0 && $0.frames > $0.easeFrames + 4 }) { chosen.append(push) }
            let made = AVURLAsset(url: mp4), source = AVURLAsset(url: file)
            var eyeOK = 0, frameOK = 0
            for (n, segment) in chosen.enumerated() {
                let editFrame = segment.easeFrames > 0 ? segment.start + segment.easeFrames + 2 : segment.start + segment.frames / 2
                guard let piece = timeline.pieces.first(where: { editFrame >= $0.editFrame && editFrame < $0.editFrame + $0.frames }) else { continue }
                let image = try await StyleTests.image(made, at: timeline.time(editFrame))
                let faces = try await DetectFaceLandmarksRequest().perform(on: image)
                let eyes = faces.compactMap { face -> Double? in
                    guard let l = face.landmarks?.leftPupil, let r = face.landmarks?.rightPupil else { return nil }
                    let ys = (l.pointsInImageCoordinates(CGSize(width: 1, height: 1), origin: .upperLeft) + r.pointsInImageCoordinates(CGSize(width: 1, height: 1), origin: .upperLeft)).map { Double($0.y) }
                    return ys.reduce(0, +) / Double(max(1, ys.count))
                }
                let eye = eyes.min { abs($0 - 1.0 / 3.0) < abs($1 - 1.0 / 3.0) }
                let sourceFrame = piece.sourceFrame + editFrame - piece.editFrame
                let expected = StyleTests.picture(StyleTests.cropped(try await StyleTests.image(source, at: timeline.time(sourceFrame)), to: segment.rect))
                let psnr = RenderTests.psnr(StyleTests.picture(image), expected)
                let kind = segment.easeFrames > 0 ? "push-in at its end" : "punch-in"
                if let eye, abs(eye - 1.0 / 3.0) <= 0.05 { eyeOK += 1 }
                if psnr >= 30 { frameOK += 1 }
                lines.append(String(format: "  %@ %d at %@ (scale %.2f): %d faces, eyes at %@ of the height; %.1f dB against the original framed by Core Graphics",
                                    kind, n + 1, Format.timecode(timeline.seconds(editFrame)), segment.scale, faces.count,
                                    eye.map { String(format: "%.3f", $0) } ?? "none", psnr))
                let name = String(format: "m9a-%@-%@-%d.png", slug.replacingOccurrences(of: " ", with: "-"), segment.easeFrames > 0 ? "push-in" : "punch-in", n + 1)
                try StyleTests.writePNG(image, to: forIvan.appending(path: name))
            }
            verdict("\(slug) check 4: the eye line within the upper third, plus or minus 5%, in the punch-ins measured", !chosen.isEmpty && eyeOK == chosen.count,
                    "\(eyeOK) of \(chosen.count) frames (three punch-ins and a push-in, Vision's pupils)")
            verdict("\(slug): each measured frame is the planned part of the picture (30 dB or more against the original framed independently)",
                    !chosen.isEmpty && frameOK == chosen.count, "\(frameOK) of \(chosen.count)")
        }

        verdict("The original is unchanged (size and modification date)", fingerprint(talk) == before, fingerprint(talk))
        let text = (["v2 part M9a acceptance (house style and zooms), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed.",
                       "Frames written for Ivan (not looked at by the build, D1): \(forIvan.path)"]).joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-style.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M9a finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
