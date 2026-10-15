import AVFoundation
import CoreText
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers
import Vision
import XCTest
@testable import Prakriti

/// v2 part M9b's acceptance (docs/v2/PLAN.md M9, the checks part M9b runs: 2, the typeface, and 4 for the title and the lower
/// third).
///
/// 1. Check 2: the IAST test string and every IAST letter drawn in the four candidate faces (Noto Sans, Source Sans 3, Inter,
///    from Google Fonts' repository, kept in `~/Prakriti/Dev/Fonts`, and the bundled Alegreya Sans) to `typeface.png`, to look
///    at; each face's `CTFont` asked for a glyph for every character.
/// 2. Check 4 on the REAL 13 Sep talk's 5-minute excerpt (PLAN's routine excerpts), made in development through the app's
///    runner with the edited video on, a test title in Info ("The Lineage of Kṛṣṇamācārya", development store only) and a
///    person named as teaching. Every text moment is measured in the made MP4, every half second of each text's life: where the
///    text is (the pixels it brightens, against the same frame drawn by the same compositor without text), whether that box
///    is inside title safe, and whether it touches any face Vision finds in that frame. Numbers only (PLAN rule 2.1.9 and D1
///    as this run was told): the frames are written to `for-ivan/` and not looked at here.
///
///   cd ~/Code/prakriti/mac && make accept-text MILESTONE=v2-m9b
///
/// Skipped unless PRAKRITI_ACCEPTANCE=text. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the original is only
/// read, checked by size and date before and after. Never a class, never the archive.
@MainActor
final class TextAcceptanceTests: XCTestCase {
    static let candidates: [(name: String, file: String, weight: Double?)] = [
        ("Noto Sans", "NotoSans[wdth,wght].ttf", 600), ("Source Sans 3", "SourceSans3[wght].ttf", 600), ("Inter", "Inter[opsz,wght].ttf", 600),
    ]
    static let testTitle = "The Lineage of Kṛṣṇamācārya"

    func testTheTypefaceAndTheTextOnTheThirteenthOfSeptember() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "text" else {
            throw XCTSkip("Reads the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-text MILESTONE=v2-m9b")
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
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)

        // 1. Check 2: the contact sheet.
        let fonts = dev.appending(path: "Fonts", directoryHint: .isDirectory)
        var faces: [(String, CTFont, CTFont, Bool)] = []
        for candidate in Self.candidates {
            let url = fonts.appending(path: candidate.file)
            guard FileManager.default.fileExists(atPath: url.path),
                  let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first else {
                verdict("Check 2: candidate \(candidate.name) is in ~/Prakriti/Dev/Fonts", false, "missing \(candidate.file) (github.com/google/fonts, ofl/)")
                continue
            }
            var d = descriptor
            if let weight = candidate.weight { d = CTFontDescriptorCreateCopyWithVariation(descriptor, 0x7767_6874 as CFNumber, weight) }
            faces.append((candidate.name, CTFontCreateWithFontDescriptor(d, 76, nil), CTFontCreateWithFontDescriptor(d, 52, nil), false))
        }
        let bold76 = try XCTUnwrap(TypeFace.font(TypeFace.bold, size: 76)), bold52 = try XCTUnwrap(TypeFace.font(TypeFace.bold, size: 52))
        faces.append(("Alegreya Sans, Yoga Marga's own (chosen)", bold76, bold52, true))
        for (name, big, _, chosen) in faces {
            let missingString = TypeFace.missing(in: TypeFace.iastTest, font: big)
            let missingLetters = TypeFace.missing(in: TypeFace.iastLetters, font: big)
            let missingPrepared = chosen ? TypeFace.missing(in: TypeFace.prepared(TypeFace.iastLetters, font: TypeFace.bold), font: big) : missingLetters
            lines.append("  \(name): the test string \(missingString.isEmpty ? "every character drawn" : "lacks " + String(missingString)); "
                         + "every IAST letter: " + (missingLetters.isEmpty ? "all drawn as one glyph" : "lacks \(String(missingLetters)) as one glyph")
                         + (chosen ? (missingPrepared.isEmpty ? ", drawn from the letter and its marks" : ", still lacks \(String(missingPrepared))") : ""))
            if chosen {
                verdict("Check 2: the chosen face's CTFont has a glyph for every character of the test string", missingString.isEmpty,
                        "\(TypeFace.iastTest.count) characters, \(missingString.count) missing")
                verdict("Check 2: the chosen face draws every IAST letter (four from a letter and its combining marks)", missingPrepared.isEmpty,
                        "\(missingPrepared.count) missing")
            }
        }
        let sheet = Self.contactSheet(faces.map { ($0.0, $0.1, $0.2, $0.3) })
        try StyleTests.writePNG(sheet, to: out.appending(path: "typeface.png"))
        lines.append("  Contact sheet: \(out.appending(path: "typeface.png").path) (looked at by the build)")

        // 2. Check 4 on the 13 Sep excerpt.
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
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        // The parts of the talk are v2 part M9d's: this check measures what it always measured, with no model asked for them.
        model.runner.askForBeats = false
        XCTAssertTrue(model.settings.houseStyle.titleOnScreen && model.settings.houseStyle.namesOnScreen, "both texts start on")
        model.log.write("Acceptance test for v2 part M9b (text and graphics) started.")
        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        let recording = Recording(filePath: excerpt.path, recordedAt: AppModel.dateInName(excerpt.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: excerpt)
        recording.kind = .talk
        recording.title = Self.testTitle
        try model.context.save()
        model.setTeacher(teacher, for: recording)
        model.setOutput(.editedVideo, on: true, for: recording)
        let started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let record = try XCTUnwrap(recording.video, "the video was made (\(recording.videoProblem ?? recording.statusReason ?? "no reason"))")
        let folder = try XCTUnwrap(recording.outputFolder)
        precondition(folder.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        let plan = try XCTUnwrap(EditPlan.read(folder: folder))
        let timeline = EditTimeline(plan: plan)
        let mp4 = URL(fileURLWithPath: folder).appending(path: VideoStep.folderName).appending(path: record.fileName)
        lines.append("")
        lines.append(String(format: "13 Sep excerpt: made in development in %.0f s; %@", Date().timeIntervalSince(started), plan.summary))
        lines.append("  \(plan.pictureSummary ?? "no picture line")")
        lines.append("  Ready checklist: \(record.summary)" + (record.failed > 0 ? ": " + record.checklist.filter { $0.status == .fail }.map(\.text).joined(separator: "; ") : ""))
        let texts = plan.visual.filter(\.isText)
        let title = texts.first { $0.kind == EditPlan.Visual.title }, lower = texts.first { $0.kind == EditPlan.Visual.lowerThird }
        verdict("The plan puts the title on screen, word for word as set in Info, from the first frame for 2 s",
                title?.lines?.joined(separator: " ") == Self.testTitle && title.flatMap { timeline.editFrame(span: $0.span, original: $0.in ?? -1) } == 0
                    && abs((title?.seconds ?? 0) - 2) <= timeline.frame.seconds,
                "\(title?.lines ?? []) for \(String(format: "%.3f", title?.seconds ?? 0)) s")
        verdict("The plan puts the teacher's name on screen once, after the title, with Teacher under it",
                lower?.lines == ["Gabriel Galindo", "Teacher"] && texts.filter { $0.kind == EditPlan.Visual.lowerThird }.count == 1,
                "\(lower?.lines ?? []) at \(lower.flatMap { timeline.editFrame(span: $0.span, original: $0.in ?? -1) }.map { Format.timecode(timeline.seconds($0)) } ?? "none"), \(lower?.align ?? "") side")

        // Every text moment: the made frame against the same frame drawn without text, and Vision's faces in the made frame.
        let original = URL(fileURLWithPath: excerpt.path)
        let plain = try await CompositionBuilder.build(plan: plan, original: original, drawText: false)
        let made = AVURLAsset(url: mp4)
        for item in texts {
            let start = try XCTUnwrap(timeline.editFrame(span: item.span, original: item.in ?? -1))
            let frames = Int64(((item.seconds ?? 0) / timeline.frame.seconds).rounded())
            let box = try XCTUnwrap(item.box)
            let planned = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
            let step = Int64((0.5 / timeline.frame.seconds).rounded())
            var moments = Array(stride(from: start + 3, to: start + frames - 2, by: Int(step)))
            moments.append(start + frames - 3)
            var inside = 0, clear = 0, measured = 0, faceCount = 0, nearest = Double.infinity
            var inks: [CGRect] = []
            for frame in moments {
                let at = timeline.time(frame)
                let image = try await StyleTests.image(made, at: at)
                let madeFrame = StyleTests.picture(image)
                let without = try await RenderTests.frame(plain.composition, videoComposition: plain.videoComposition, at: at)
                guard let ink = TextTests.inkBox(madeFrame, without) else { continue }
                measured += 1
                inks.append(ink)
                if OverlayLayout.titleSafe.contains(ink) { inside += 1 }
                let found = try await DetectFaceRectanglesRequest().perform(on: image)
                let boxes = found.map { $0.boundingBox.toImageCoordinates(CGSize(width: 1, height: 1), origin: .upperLeft) }
                faceCount += boxes.count
                if !boxes.contains(where: { $0.intersects(ink) || $0.intersects(planned) }) { clear += 1 }
                for b in boxes { nearest = min(nearest, Self.gap(b, ink)) }
                if frame == start + frames / 2 || frame == moments[moments.count / 2] {
                    let name = String(format: "m9b-13-Sep-excerpt-%@-%@.png", item.kind == EditPlan.Visual.title ? "title" : "lower-third",
                                      Format.timecode(timeline.seconds(frame)).replacingOccurrences(of: ":", with: "-"))
                    try StyleTests.writePNG(image, to: forIvan.appending(path: name))
                }
            }
            let kind = item.kind == EditPlan.Visual.title ? "title" : "lower third"
            let union = inks.dropFirst().reduce(inks.first ?? .zero) { $0.union($1) }
            verdict("Check 4 (\(kind)): the text is drawn at every moment measured", measured == moments.count, "\(measured) of \(moments.count) frames, every 0.5 s of its life")
            verdict("Check 4 (\(kind)): every text box inside the frame's title-safe area (the middle 90%)", inside == measured && measured > 0,
                    String(format: "%d of %d; the text's pixels span x %.3f to %.3f, y %.3f to %.3f (title safe 0.050 to 0.950)", inside, measured,
                           union.minX, union.maxX, union.minY, union.maxY))
            verdict("Check 4 (\(kind)): not intersecting any face box (Vision, on the made frame)", clear == measured && measured > 0,
                    String(format: "%d of %d frames clear; %d faces found in them; the nearest face %.3f of the frame away", clear, measured, faceCount,
                           nearest.isFinite ? nearest : -1))
        }
        verdict("The original is unchanged (size and modification date)", fingerprint(talk) == before, fingerprint(talk))
        let text = (["v2 part M9b acceptance (text and graphics), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed.",
                       "Frames written for Ivan (not looked at by the build, D1): \(forIvan.path)"]).joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-text.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M9b finished.")
    }

    /// How far apart two boxes are (0 when they touch or overlap), as a fraction of the frame.
    static func gap(_ a: CGRect, _ b: CGRect) -> Double {
        let dx = max(0, max(a.minX - b.maxX, b.minX - a.maxX)), dy = max(0, max(a.minY - b.maxY, b.minY - a.maxY))
        return hypot(dx, dy)
    }

    /// The contact sheet: each face's name, the test string at 76 px and every IAST letter at 52 px (the chosen face's through
    /// `TypeFace.prepared`, as the video draws it), white on near black.
    static func contactSheet(_ faces: [(String, CTFont, CTFont, Bool)]) -> CGImage {
        let w = 2400, h = 300 + faces.count * 300
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let label = TypeFace.font(TypeFace.medium, size: 30)!
        func draw(_ text: String, _ font: CTFont, x: Double, y: Double, alpha: Double = 1) {
            let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                                           NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: alpha)])
            context.textPosition = CGPoint(x: x, y: Double(h) - y)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
        draw("PLAN M9 check 2: \(TypeFace.iastTest), and every IAST letter", label, x: 60, y: 80, alpha: 0.6)
        let letters = TypeFace.iastLetters.map(String.init).joined(separator: " ")
        var y = 180.0
        for (name, big, small, chosen) in faces {
            draw(name, label, x: 60, y: y, alpha: 0.6)
            draw(TypeFace.iastTest, big, x: 60, y: y + 100)
            draw(chosen ? TypeFace.prepared(letters, font: TypeFace.bold) : letters, small, x: 60, y: y + 190)
            y += 300
        }
        return context.makeImage()!
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
