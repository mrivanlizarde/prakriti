import CoreImage
import SwiftUI
import Foundation
import ImageIO
import XCTest
@testable import Prakriti

/// v2 part M11b: the thumbnails' design and checks, on drawn test patterns only (a figure drawn in grey, never a frame of anyone,
/// PLAN section 11, D1): the words' layout and the sizes they read at, the brand colours' contrast, the choice of three frames, the
/// headlines' checks, the gate that refuses an option with a face of anyone not included, and the three compositions drawn to
/// pictures to look at (`m11b-thumbnail-test-pattern-*.png`).
@MainActor
final class ThumbnailTests: XCTestCase {
    func testTheWordsReadAt168PixelsWideAndTheColoursMeetTheContrast() throws {
        let canvas = CGSize(width: 1920, height: 1080)
        let box = VideoThumbnails.wordsBox(.saffron, subjectOnCanvas: FaceBox(x: 0.6, y: 0.2, width: 0.18, height: 0.3), canvas: canvas)
        XCTAssertLessThanOrEqual(box.maxX, canvas.width * 0.53, "the words take the side away from the teacher")
        for headline in ["Breath Comes First", "Prāṇāyāma First", "Practice Before Theory", "Stay"] where headline != "Stay" {
            let words = try XCTUnwrap(VideoThumbnails.layOut(headline, in: box, canvas: canvas), headline)
            XCTAssertLessThanOrEqual(words.lines.count, 3, headline)
            XCTAssertGreaterThanOrEqual(words.size, canvas.height * 0.135, headline)
            XCTAssertGreaterThanOrEqual(VideoThumbnails.capAtSmallest(words, canvas: canvas), VideoThumbnails.smallestCap, headline)
            XCTAssertLessThanOrEqual(words.widths.max() ?? 0, box.width, headline)
        }
        XCTAssertGreaterThanOrEqual(VideoThumbnails.contrast(VideoThumbnails.night.luminance, VideoThumbnails.saffron.luminance), 4.5)
        XCTAssertGreaterThanOrEqual(VideoThumbnails.contrast(VideoThumbnails.gold.luminance, VideoThumbnails.night.luminance), 4.5)
        XCTAssertLessThan(VideoThumbnails.contrast(VideoThumbnails.white.luminance, VideoThumbnails.saffron.luminance), 4.5,
                          "white on saffron does not reach 4.5 (3.4 to 1), so the saffron option's words are near-black")
    }

    func testThreeFramesAreChosenApartAndTheBestFirst() {
        func look(_ t: Double, _ s: Double) -> VideoThumbnails.Look {
            VideoThumbnails.Look(time: t, score: s, quality: s, aesthetics: 0, eyesOpen: true, subject: FaceBox(x: 0.4, y: 0.2, width: 0.1, height: 0.2), included: [], hidden: [])
        }
        let chosen = VideoThumbnails.choose([look(10, 0.5), look(15, 0.9), look(60, 0.7), look(62, 0.8), look(200, 0.2)])
        XCTAssertEqual(chosen.map(\.time), [15, 62, 200], "the best, then the best at least 20 s from those chosen")
        XCTAssertEqual(VideoThumbnails.choose([look(5, 0.4)]).map(\.time), [5, 5, 5], "one frame serves all three compositions")
        XCTAssertGreaterThan(VideoThumbnails.score(quality: 0.6, aesthetics: 0.2, eyesOpen: true, onKeyLine: false),
                             VideoThumbnails.score(quality: 0.6, aesthetics: 0.2, eyesOpen: false, onKeyLine: false), "open eyes count")
        XCTAssertGreaterThan(VideoThumbnails.eyeOpenness([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 3), CGPoint(x: 20, y: 0), CGPoint(x: 10, y: -3)]), 0.18)
        XCTAssertLessThan(VideoThumbnails.eyeOpenness([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0.5), CGPoint(x: 20, y: 0), CGPoint(x: 10, y: -0.5)]), 0.18)
    }

    func testTheHeadlinesAreCheckedAndNeverInvented() {
        XCTAssertNil(ThumbnailWords.problem("Breath Comes First", title: "Talk with Gabriel"))
        XCTAssertNil(ThumbnailWords.problem("Prāṇāyāma First", title: ""))
        XCTAssertEqual(ThumbnailWords.problem("Breath", title: ""), "it is 1 word, not 2 to 4")
        XCTAssertEqual(ThumbnailWords.problem("Why The Breath Comes First", title: ""), "it is 5 words, not 2 to 4")
        XCTAssertEqual(ThumbnailWords.problem("Breath \u{2014} First", title: ""), "it has a dash")
        XCTAssertEqual(ThumbnailWords.problem("Breath\u{2014}First Always", title: ""), "it has a dash")
        XCTAssertEqual(ThumbnailWords.problem("Talk With Gabriel", title: "Talk with Gabriel"), "it is the title")
        XCTAssertNotNil(ThumbnailWords.problem("Free Class Today", title: ""), "Ivan's copy rules")
        XCTAssertNotNil(ThumbnailWords.problem("Enroll Now Please", title: ""))
        let read = ThumbnailWords.read(#"{"headlines": ["\"Breath Comes First.\"", "Free Week Inside", "Breath comes first", "Steady Mind Steady Body"]}"#, title: "")
        XCTAssertEqual(read.kept, ["Breath Comes First", "Steady Mind Steady Body"], "cleaned, checked, each once")
        XCTAssertEqual(read.refused.count, 1)
        let beat = Beat(id: "b1", firstSentence: "s1", lastSentence: "s2", from: "w0", to: "w9", start: 0, end: 30, summary: "the breath as teacher", scores: [:],
                        kind: .teaching, standsAlone: true, dependsOn: [], keyLine: nil,
                        keyPhrase: Beat.KeyLine(from: "w1", to: "w4", text: "the breath is the first teacher"), hookCandidate: true, terms: [], thesis: false)
        XCTAssertEqual(ThumbnailWords.fallback(beats: [beat], title: "", have: []), ["The breath is the"], "the talk's own words, cut to four")
    }

    /// A grey figure drawn on a plain backdrop: a head and shoulders shape, no face, standing in for the teacher.
    static func testPattern(size: CGSize) -> (frame: CGImage, figure: CIImage, face: FaceBox) {
        let w = Int(size.width), h = Int(size.height)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func draw(_ background: Bool) -> CGImage {
            let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            if background {
                cg.setFillColor(CGColor(srgbRed: 0.45, green: 0.5, blue: 0.55, alpha: 1))
                cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
                cg.setFillColor(CGColor(srgbRed: 0.62, green: 0.6, blue: 0.55, alpha: 1))
                cg.fill(CGRect(x: 0, y: 0, width: w, height: h / 3))
            }
            cg.setFillColor(CGColor(srgbRed: 0.83, green: 0.83, blue: 0.85, alpha: 1))
            cg.fillEllipse(in: CGRect(x: size.width * 0.44, y: size.height * 0.55, width: size.width * 0.12, height: size.height * 0.28))
            cg.fill(CGRect(x: size.width * 0.36, y: 0, width: size.width * 0.28, height: size.height * 0.5))
            cg.fillEllipse(in: CGRect(x: size.width * 0.36, y: size.height * 0.35, width: size.width * 0.28, height: size.height * 0.3))
            return cg.makeImage()!
        }
        let face = FaceBox(x: 0.44, y: 1 - 0.83, width: 0.12, height: 0.28)
        return (draw(true), CIImage(cgImage: draw(false)), face)
    }

    func testTheThreeCompositionsDrawnOnATestPatternToLookAt() async throws {
        let size = CGSize(width: 1920, height: 1080)
        let pattern = Self.testPattern(size: size)
        let look = VideoThumbnails.Look(time: 461, score: 1, quality: 0.8, aesthetics: 0.3, eyesOpen: true, subject: pattern.face, included: [pattern.face], hidden: [])
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let context = CIContext(options: [.cacheIntermediates: false])
        for (composition, headline) in zip(VideoThumbnails.Composition.allCases, ["Breath Comes First", "Prāṇāyāma First", "Steady Mind"]) {
            let designed = try await VideoThumbnails.design(composition, frame: pattern.frame, look: look, headline: headline, canvas: size, context: context, person: pattern.figure)
            XCTAssertEqual(designed.image.width, 1920)
            XCTAssertEqual(designed.image.height, 1080)
            XCTAssertGreaterThanOrEqual(designed.contrast, VideoThumbnails.leastContrast, "\(composition): measured behind the words")
            XCTAssertGreaterThanOrEqual(designed.capAtSmallest, VideoThumbnails.smallestCap, "\(composition)")
            let small = try VideoThumbnails.scaled(designed.image, to: CGSize(width: 1280, height: 720))
            let url = out.appending(path: "m11b-thumbnail-test-pattern-\(composition.rawValue).png")
            try StyleTests.writePNG(small, to: url)
            // And as YouTube's list shows it: 168 pixels wide.
            let tiny = try VideoThumbnails.scaled(designed.image, to: CGSize(width: 168, height: 94.5))
            try StyleTests.writePNG(tiny, to: out.appending(path: "m11b-thumbnail-test-pattern-\(composition.rawValue)-168.png"))
            let jpeg = out.appending(path: "m11b-thumbnail-test-pattern-\(composition.rawValue).jpg")
            try VideoThumbnails.writeJPEG(small, to: jpeg, quality: 0.88)
            XCTAssertLessThan(VideoThumbnails.bytes(jpeg), VideoThumbnails.maxBytes)
            try? FileManager.default.removeItem(at: jpeg)
        }
    }

    /// v2 part M13 (PLAN section 11, Sonny Fri 16 Oct: a light halo round the teacher, and background left as a smear along the
    /// bottom edge). A dark figure cut from a light wall the way Vision's soft mask cuts it: the edge mixed with the wall over about
    /// 12 pixels, and a faint patch of the room (a chair, at a third of full strength) below the figure's shoulder line, apart from
    /// it. Each composition drawn as the edge was before and as it is now, measured by `ThumbnailMatte.measure`, and written to
    /// `m13-thumbnail-edge-*.png` (1280 and 168 wide) to look at. Before: a ring and the patch, both measured over the limits;
    /// now: under both.
    func testTheCutOutHasNoHaloAndNoLeftoverBackground() async throws {
        let size = CGSize(width: 1920, height: 1080)
        let w = Int(size.width), h = Int(size.height)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func draw(_ body: (CGContext) -> Void, grey: Bool = false) -> CGImage {
            let cg = grey ? CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
                : CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            body(cg)
            return cg.makeImage()!
        }
        func figure(_ cg: CGContext) {
            cg.fillEllipse(in: CGRect(x: size.width * 0.44, y: size.height * 0.55, width: size.width * 0.12, height: size.height * 0.28))
            cg.fill(CGRect(x: size.width * 0.36, y: 0, width: size.width * 0.28, height: size.height * 0.5))
            cg.fillEllipse(in: CGRect(x: size.width * 0.36, y: size.height * 0.35, width: size.width * 0.28, height: size.height * 0.3))
        }
        // The room: a light wall, a darker floor, a chair-coloured patch low on the left; the figure dark, as a teacher in dark
        // clothes in front of a white wall.
        let frame = draw { cg in
            cg.setFillColor(CGColor(srgbRed: 0.93, green: 0.92, blue: 0.9, alpha: 1)); cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
            cg.setFillColor(CGColor(srgbRed: 0.7, green: 0.62, blue: 0.5, alpha: 1)); cg.fill(CGRect(x: 0, y: 0, width: w, height: h / 5))
            cg.setFillColor(CGColor(srgbRed: 0.55, green: 0.4, blue: 0.3, alpha: 1)); cg.fill(CGRect(x: w / 8, y: 0, width: w / 6, height: h / 4))
            cg.setFillColor(CGColor(srgbRed: 0.25, green: 0.22, blue: 0.24, alpha: 1)); figure(cg)
        }
        // Vision's mask, as it comes: the figure softened over about 12 pixels, and the chair at a third of full strength.
        let hardFigure = CIImage(cgImage: draw({ cg in cg.setFillColor(gray: 1, alpha: 1); figure(cg) }, grey: true))
        let chair = CIImage(cgImage: draw({ cg in cg.setFillColor(gray: 0.35, alpha: 1); cg.fill(CGRect(x: w / 8, y: 0, width: w / 6, height: h / 4)) }, grey: true))
        let extent = CGRect(origin: .zero, size: size)
        let soft = hardFigure.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 6]).cropped(to: extent)
            .applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: chair])
        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: extent)
        let cut = CIImage(cgImage: frame).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: soft])
        let face = FaceBox(x: 0.44, y: 1 - 0.83, width: 0.12, height: 0.28)
        let look = VideoThumbnails.Look(time: 461, score: 1, quality: 0.8, aesthetics: 0.3, eyesOpen: true, subject: face, included: [face], hidden: [])
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let context = CIContext(options: [.cacheIntermediates: false])
        var lines: [String] = []
        for composition in VideoThumbnails.Composition.allCases {
            for clean in [false, true] {
                let designed = try await VideoThumbnails.design(composition, frame: frame, look: look, headline: "Steady Mind", canvas: size, context: context,
                                                                person: cut, cleanEdge: clean)
                let edge = try XCTUnwrap(designed.edge, "\(composition) measured")
                let name = "m13-thumbnail-edge-\(composition.rawValue)-\(clean ? "now" : "before")"
                lines.append(String(format: "%@: halo %.2f levels, leftover %.3f%%", name, edge.halo, edge.leftover))
                try StyleTests.writePNG(try VideoThumbnails.scaled(designed.image, to: CGSize(width: 1280, height: 720)), to: out.appending(path: name + ".png"))
                try StyleTests.writePNG(try VideoThumbnails.scaled(designed.image, to: CGSize(width: 168, height: 94.5)), to: out.appending(path: name + "-168.png"))
                if clean {
                    XCTAssertLessThanOrEqual(edge.halo, ThumbnailMatte.mostHalo, "\(composition): no ring now")
                    XCTAssertLessThanOrEqual(edge.leftover, ThumbnailMatte.mostLeftover, "\(composition): no background left now")
                } else if composition != .frame {
                    XCTAssertGreaterThan(edge.halo, ThumbnailMatte.mostHalo, "\(composition): the old edge had a ring, and the check sees it")
                    XCTAssertGreaterThan(edge.leftover, ThumbnailMatte.mostLeftover, "\(composition): the old edge kept the chair, and the check sees it")
                }
            }
        }
        try lines.joined(separator: "\n").appending("\n").write(to: out.appending(path: "m13-thumbnail-edge.txt"), atomically: true, encoding: .utf8)
        print(lines.joined(separator: "\n"))
    }

    func testTheGateKeepsOnlyTheOptionsThatPassAndDeletesTheOthers() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "prakriti-thumbs-\(UUID().uuidString)", directoryHint: .isDirectory)
        let staged = folder.appending(path: ".thumbnails", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var candidates: [VideoThumbnails.Candidate] = []
        for (i, letter) in VideoThumbnails.letters.enumerated() {
            var c = VideoThumbnails.Candidate(letter: letter, composition: VideoThumbnails.Composition.allCases[i], headline: "Breath Comes First", reason: "r", time: 10,
                                              fileName: VideoThumbnails.fileName(letter), masterName: VideoThumbnails.masterName(letter))
            c.lines = [ChecklistLine(status: .pass, item: "Size", detail: "1280 by 720.")]
            if letter == "B" { c.lines.append(ChecklistLine(status: .fail, item: "People", detail: "A face in it is not someone you included, so it must not be used.")) }
            candidates.append(c)
            try "jpeg".write(to: staged.appending(path: c.fileName), atomically: true, encoding: .utf8)
            try "jpeg".write(to: staged.appending(path: c.masterName), atomically: true, encoding: .utf8)
        }
        let record = VideoThumbnails.Record(madeAt: Date(), planMadeAt: Date(), signature: "hidden:", source: "1080p", headlinesBy: "test", candidates: candidates)
        let destination = folder.appending(path: VideoThumbnails.folderName, directoryHint: .isDirectory)
        try OutputGate.admitThumbnails(staged: staged, to: destination, record: record)
        XCTAssertEqual(Pipeline.madeFiles(in: destination), ["Thumbnail A full size.jpg", "Thumbnail A.jpg", "Thumbnail C full size.jpg", "Thumbnail C.jpg", VideoThumbnails.recordName])
        let kept = try XCTUnwrap(VideoThumbnails.Record.read(destination))
        XCTAssertEqual(kept.candidates.map(\.letter), ["A", "C"])
        XCTAssertTrue(kept.notes.first?.contains("Thumbnail B: People") == true, kept.notes.joined())

        // None passing: the folder is deleted and nothing reaches the output folder.
        let staged2 = folder.appending(path: ".thumbnails2", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staged2, withIntermediateDirectories: true)
        var failing = record
        failing.candidates = [candidates[1]]
        XCTAssertThrowsError(try OutputGate.admitThumbnails(staged: staged2, to: folder.appending(path: "Other"), record: failing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged2.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "Other").path))
    }

    /// PLAN M11 check 7, the part M11b runs: the Approve sheet passing and with one failing deliverable, the upload checklist for
    /// YouTube and for Shorts, and the Thumbnails section, drawn on the sample data (made-up records of no one) with the thumbnails
    /// designed from the drawn test pattern, so every picture can be looked at. Written to `28-*.png`.
    func testDrawTheApproveSheetUploadChecklistAndThumbnailsToLookAt() async throws {
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let work = FileManager.default.temporaryDirectory.appending(path: "prakriti-m11b-snap-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: work) }
        let (model, made) = try ApproveTests.madeRecording(in: work, peopleChecked: true)
        let outputs = try XCTUnwrap(made.outputFolder.map { URL(fileURLWithPath: $0, isDirectory: true) })
        // Three designed thumbnails of the test pattern, through the gate, as a make leaves them.
        let size = CGSize(width: 1920, height: 1080)
        let pattern = Self.testPattern(size: size)
        let look = VideoThumbnails.Look(time: 461, score: 1, quality: 0.8, aesthetics: 0.3, eyesOpen: true, subject: pattern.face, included: [pattern.face], hidden: [])
        let staged = outputs.appending(path: VideoThumbnails.stagingName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        let context = CIContext(options: [.cacheIntermediates: false])
        var candidates: [VideoThumbnails.Candidate] = []
        for (i, (composition, headline)) in zip(VideoThumbnails.Composition.allCases, ["Breath Comes First", "Prāṇāyāma First", "Steady Mind"]).enumerated() {
            let letter = VideoThumbnails.letters[i]
            let designed = try await VideoThumbnails.design(composition, frame: pattern.frame, look: look, headline: headline, canvas: size, context: context, person: pattern.figure)
            var c = VideoThumbnails.Candidate(letter: letter, composition: composition, headline: headline, reason: composition.reason(at: 461 + Double(i) * 120),
                                              time: 461, fileName: VideoThumbnails.fileName(letter), masterName: VideoThumbnails.masterName(letter))
            try VideoThumbnails.writeJPEG(designed.image, to: staged.appending(path: c.masterName), quality: 0.92)
            try VideoThumbnails.writeJPEG(try VideoThumbnails.scaled(designed.image, to: CGSize(width: 1280, height: 720)), to: staged.appending(path: c.fileName), quality: 0.88)
            c.bytes = VideoThumbnails.bytes(staged.appending(path: c.fileName))
            (c.width, c.height) = VideoThumbnails.pixelSize(staged.appending(path: c.fileName))
            (c.masterWidth, c.masterHeight) = VideoThumbnails.pixelSize(staged.appending(path: c.masterName))
            c.capAtSmallest = designed.capAtSmallest
            c.contrast = designed.contrast
            c.cutOut = true
            c.lines = VideoThumbnails.checklist(c, master: size, accounted: true)
            candidates.append(c)
        }
        let record = VideoThumbnails.Record(madeAt: Fixtures.now, planMadeAt: Fixtures.now, signature: made.thumbnailSignature, source: "1080p",
                                            headlinesBy: "Anthropic, claude-sonnet-5-5", looked: 24, candidates: candidates)
        try record.encoded().write(to: staged.appending(path: VideoThumbnails.recordName))
        try OutputGate.admitThumbnails(staged: staged, to: outputs.appending(path: VideoThumbnails.folderName), record: record)
        made.madeFiles = (made.madeFiles + [VideoThumbnails.folderName]).sorted()
        try model.context.save()

        func sheet(_ view: AnyView, height: CGFloat, name: String) throws {
            for (scheme, appearance) in SnapshotRenderer.appearances {
                try renderer.renderSheet(AnyView(view.frame(width: 600, height: height - 32)), model: model, size: CGSize(width: 600, height: height),
                                         appearance: appearance, name: "\(name)-\(scheme)")
            }
        }
        func section(_ view: AnyView, height: CGFloat, name: String) throws {
            for (scheme, appearance) in SnapshotRenderer.appearances {
                try renderer.renderSheet(AnyView(Form { view }.formStyle(.grouped).frame(width: 400, height: height - 32)), model: model,
                                         size: CGSize(width: 400, height: height), appearance: appearance, name: "\(name)-\(scheme)")
            }
        }
        try sheet(AnyView(ApproveSheet(request: ApproveRequest(recordingID: made.id))), height: 1400, name: "28-approve-sheet-sample-passing")
        try section(AnyView(ThumbnailsSection(recording: made)), height: 1700, name: "28-thumbnails-section")
        try section(AnyView(UploadChecklistSection(recording: made)), height: 1700, name: "28-upload-checklist-youtube")
        try section(AnyView(UploadChecklistSection(recording: made, platform: .youtubeShorts)), height: 1300, name: "28-upload-checklist-shorts")
        // One short over the limit: unticked, named.
        try ApproveTests.headerOnlyMP4(seconds: 190, to: outputs.appending(path: "Shorts/Short 2.mp4"))
        try sheet(AnyView(ApproveSheet(request: ApproveRequest(recordingID: made.id))), height: 1400, name: "28-approve-sheet-sample-one-failing")
        XCTAssertEqual(model.approvalDeliverables(made).first { $0.id == "short-2" }?.failure, "Short 2 is 190 s; the limit is 180 s.")
        XCTAssertEqual(model.tileThumbnail(made)?.lastPathComponent, "Thumbnail A.jpg", "the card shows the chosen thumbnail")
        model.chooseThumbnail("C", for: made)
        XCTAssertEqual(model.tileThumbnail(made)?.lastPathComponent, "Thumbnail C.jpg")
    }
}
