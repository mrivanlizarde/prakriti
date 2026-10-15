import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO
import Foundation
import XCTest
@testable import Prakriti

/// People in the video (v2 part M8d, docs/v2/PLAN.md M8). Synthetic media only, no face of anyone: a hidden "face" on the
/// moving test pattern (ffmpeg's `testsrc2`) and the moving square of `HidingTests`.
///
/// - A region set to be hidden is hidden in every frame of the made MP4 that keeps it (its variance falls by 80% or more
///   against the original's frame), the rest of the picture is the original's, the Viewer's composition draws the same
///   (preview equals output, 38 dB), the picture output check runs, and `video-hiding.json` lands beside the plan.
/// - `VideoHiding` follows a moving face at every frame between the face step's sightings, two a second.
/// - `PictureOutputCheck.account` sorts each face found again: someone included, inside a hidden region, where a hidden person
///   is, or no one the people check saw.
@MainActor
final class PeopleInVideoTests: XCTestCase {
    /// The made-up face on the test pattern: fixed, left of the middle.
    static let face = FaceBox(x: 0.12, y: 0.18, width: 0.14, height: 0.26)

    func testAHiddenFaceIsHiddenInEveryKeptFrameOfTheFileAndThePreview() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "m8d-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let ffmpegURL = ToolPaths.standard.ffmpeg
        let planSetup = PlanStep.Setup(original: original, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                       jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory), duration: 30, frameRate: 29.97)
        let plan = try await PlanStep.run(planSetup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpegURL, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan

        // One face row, set to Hide Face for the video, seen from 4 s to 20 s two a second at the same place.
        var people = RenderTests.everyoneIncluded()
        people.faces?.people = [FacePerson(id: 1, label: "Unnamed 1", onScreen: 16, first: 4, last: 20, appearances: 1, keyTime: 5, keyBox: Self.face)]
        var choices = PeopleChoices.none
        choices.set(.hideFace, for: .face(1), output: .video)
        people.choices = choices
        let spots = stride(from: 4.0, through: 20.0, by: 0.5).map { HiddenTrack.Spot(time: $0, box: Self.face) }
        let hiding = HidePlan(tracks: [HiddenTrack(id: 1, spots: spots)])
        let tracks = [PictureOutputCheck.Track(id: 1, hidden: true, spots: spots)]
        var setup = VideoStep.Setup(original: original, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: Date(timeIntervalSince1970: 1_789_000_000),
                                    label: "Test pattern", people: people)
        setup.hiding = hiding
        setup.faceTracks = tracks
        // Someone hidden with no sighting in the people file: refused before anything is made (fail closed).
        var blind = setup
        blind.hiding = HidePlan()
        do {
            _ = try await VideoStep.make(blind, ffmpeg: RenderTests.ffmpeg())
            XCTFail("a hidden person with no sightings must not be made")
        } catch let failure as VideoStep.Failure {
            XCTAssertTrue(failure.reason.contains("Check People"), failure.reason)
        }

        let made = try await VideoStep.make(setup, ffmpeg: RenderTests.ffmpeg())
        let table = made.hidden.table()
        let timeline = made.timeline
        // Every kept frame from 3.5 s to 20.5 s (the sightings, held 0.5 s either side) has the region; none outside it.
        var expectedFrames = 0, wrong: [Int64] = []
        for piece in timeline.pieces {
            for frame in piece.sourceFrame..<(piece.sourceFrame + piece.frames) {
                let t = timeline.seconds(frame)
                let regions = table.regions(atSourceFrame: frame)
                if t >= 3.5 + 0.02 && t <= 20.5 - 0.02 {
                    expectedFrames += 1
                    if !regions.contains(where: { FaceHide.covers($0, x: Self.face.centerX, y: Self.face.centerY) }) { wrong.append(frame) }
                } else if t < 3.4 || t > 20.6 {
                    if !regions.isEmpty { wrong.append(frame) }
                }
            }
        }
        XCTAssertGreaterThan(expectedFrames, 300)
        XCTAssertEqual(wrong, [], "frames with the wrong regions")
        print("Hidden faces: \(made.hidden.frames.count) frames with a region, \(made.hidden.how), \(String(format: "%.2f", made.hidden.seconds)) s")

        let record = try await VideoStep.check(made, setup: setup, ffprobe: RenderTests.ffprobe(), ffmpeg: RenderTests.ffmpeg(), now: Date())
        XCTAssertEqual(record.hiddenFaces, 1)
        XCTAssertEqual(record.leftOutVoices, 0)
        let picture = try XCTUnwrap(record.pictureCheck, "the picture output check ran")
        XCTAssertTrue(picture.passed, picture.line)
        XCTAssertGreaterThanOrEqual(picture.frames, Int(timeline.duration * 5) - 2, "five frames a second")
        XCTAssertNil(record.soundCheck, "nobody left out: no sound check")
        let peopleLine = try XCTUnwrap(record.checklist.first { $0.item == "People" })
        XCTAssertEqual(peopleLine.status, .pass, peopleLine.text)
        XCTAssertTrue(peopleLine.text.contains("1 face hidden"), peopleLine.text)
        let saved = try XCTUnwrap(HiddenFaces.read(folder: staging), "video-hiding.json beside the plan")
        XCTAssertEqual(saved.frames, made.hidden.frames)
        XCTAssertEqual(saved.tracks, [1])
        XCTAssertEqual(saved.planMadeAt.timeIntervalSince(plan.madeAt), 0, accuracy: 1)
        XCTAssertEqual(record.failed, 0, record.checklist.filter { $0.status == .fail }.map(\.text).joined(separator: "; "))

        // The file, frame by frame: the region hidden, the rest the original's.
        let base = PodcastPackage.isoDate(Date(timeIntervalSince1970: 1_789_000_000))
        let mp4 = staging.appending(path: VideoStep.folderName).appending(path: base + ".mp4")
        let output = AVURLAsset(url: mp4), source = AVURLAsset(url: original)
        let preview = try await CompositionBuilder.build(plan: plan, original: original, hidden: saved)
        var lines: [String] = []
        var looked: (RenderTests.Picture, RenderTests.Picture)?
        let inside = timeline.pieces.filter { timeline.seconds($0.sourceFrame) > 4 && timeline.seconds($0.sourceFrame + $0.frames) < 20 && $0.frames > 10 }
        XCTAssertGreaterThanOrEqual(inside.count, 2)
        for piece in inside.prefix(3) {
            let offset = piece.frames / 2
            let madeFrame = try await RenderTests.frame(output, at: timeline.time(piece.editFrame + offset))
            let originalFrame = try await RenderTests.frame(source, at: timeline.time(piece.sourceFrame + offset))
            let previewFrame = try await RenderTests.frame(preview.composition, videoComposition: preview.videoComposition, at: timeline.time(piece.editFrame + offset))
            let was = Self.variance(originalFrame, in: Self.face), now = Self.variance(madeFrame, in: Self.face)
            let fall = 1 - now / max(was, 0.001)
            // Outside every region hidden in that frame (each padded as `FaceHide` pads it): the original's picture, less what
            // the round trip through Core Image costs on a test pattern (37.9 dB measured in M8b).
            let frameRegions = table.regions(atSourceFrame: piece.sourceFrame + offset).map { FaceGeometry.padded($0, by: FaceHide.pad) }
            let outside = Self.psnr(madeFrame, originalFrame, outside: frameRegions)
            let previewMatch = RenderTests.psnr(previewFrame, madeFrame)
            lines.append(String(format: "%@ +%lld: region variance %.0f in the original, %.0f in the video (a fall of %.1f%%); outside it %.1f dB; preview against the file %.1f dB",
                                piece.id, offset, was, now, fall * 100, outside, previewMatch))
            XCTAssertGreaterThanOrEqual(fall, 0.8, "the hidden region's variance falls by at least 80%")
            XCTAssertGreaterThanOrEqual(outside, 35, "the rest of the picture is the original's")
            XCTAssertGreaterThanOrEqual(previewMatch, 38, "the Viewer draws what the file holds")
            if looked == nil { looked = (originalFrame, madeFrame) }
        }
        // A frame outside the hidden stretch is passed on untouched.
        if let early = timeline.pieces.first(where: { timeline.seconds($0.sourceFrame + $0.frames) < 3 && $0.frames > 4 }) {
            let madeFrame = try await RenderTests.frame(output, at: timeline.time(early.editFrame + 2))
            let originalFrame = try await RenderTests.frame(source, at: timeline.time(early.sourceFrame + 2))
            let psnr = RenderTests.psnr(madeFrame, originalFrame)
            lines.append(String(format: "%@ +2 (before anyone is hidden): %.1f dB against the original", early.id, psnr))
            XCTAssertGreaterThanOrEqual(psnr, 38)
        }
        print("People in the video, test pattern:\n" + lines.joined(separator: "\n"))

        // The picture to look at: the test pattern as recorded (above) and as the video shows it (below).
        if let (before, after) = looked {
            let folder = SnapshotRenderer.milestoneFolder()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Self.writePair(before, after, to: folder.appending(path: "m8d-hidden-in-video-test-pattern.png"))
        }
    }

    func testTheVideoFollowsAMovingFaceAtEveryFrame() async throws {
        let video = try HidingTests.movingSquare()
        // Sightings two a second, as the face step makes them.
        let spots = stride(from: 0.0, through: 5.5, by: 0.5).map { HiddenTrack.Spot(time: $0, box: HidingTests.squareBox(at: $0)) }
        let plan = HidePlan(tracks: [HiddenTrack(id: 1, spots: spots)])
        // The whole 6 s kept, at 30 frames a second, in two pieces with a cut between them.
        let frame = FrameDuration(value: 1, timescale: 30)
        let timeline = EditTimeline(frame: frame, pieces: [.init(id: "k1", sourceFrame: 0, frames: 70, editFrame: 0),
                                                           .init(id: "k2", sourceFrame: 85, frames: 90, editFrame: 70)])
        let hidden = try await VideoHiding.make(original: video, plan: plan, timeline: timeline, planMadeAt: Date())
        let table = hidden.table()
        var missed: [String] = [], worst = 1.0
        for piece in timeline.pieces {
            for f in piece.sourceFrame..<(piece.sourceFrame + piece.frames) {
                let truth = HidingTests.squareBox(at: Double(f) / 30)
                let regions = table.regions(atSourceFrame: f)
                // The square's middle and its four corners' middles (a quarter in from each corner) all hidden.
                let points = [(truth.centerX, truth.centerY), (truth.x + truth.width / 4, truth.y + truth.height / 4),
                              (truth.x + 3 * truth.width / 4, truth.y + truth.height / 4), (truth.x + truth.width / 4, truth.y + 3 * truth.height / 4),
                              (truth.x + 3 * truth.width / 4, truth.y + 3 * truth.height / 4)]
                // Only the points still inside the picture: the square runs off its right edge after 5.6 s.
                let inPicture = points.filter { $0.0 < 1 && $0.1 < 1 }
                let covered = inPicture.filter { p in regions.contains { FaceHide.covers($0, x: p.0, y: p.1) } }.count
                worst = min(worst, Double(covered) / Double(max(1, inPicture.count)))
                if covered < inPicture.count { missed.append("frame \(f): \(covered) of \(inPicture.count)") }
            }
            XCTAssertEqual(table.regions(atSourceFrame: 75), [], "a frame the plan cuts gets no row")
        }
        print("Moving square, \(timeline.totalFrames) kept frames: \(missed.count) with a point showing; \(hidden.how)")
        XCTAssertEqual(missed, [], "every kept frame hides the whole square")
        XCTAssertGreaterThan(hidden.how["followed"] ?? 0, 100, "followed between sightings at the full frame rate")
    }

    func testThePictureCheckAccountsForEachFace() {
        let included = PictureOutputCheck.Track(id: 1, hidden: false, spots: [.init(time: 10, box: FaceBox(x: 0.4, y: 0.2, width: 0.2, height: 0.35)),
                                                                              .init(time: 10.5, box: FaceBox(x: 0.42, y: 0.2, width: 0.2, height: 0.35))])
        let hiddenTrack = PictureOutputCheck.Track(id: 2, hidden: true, spots: [.init(time: 10, box: FaceBox(x: 0.75, y: 0.6, width: 0.1, height: 0.15))])
        let tracks = [included, hiddenTrack]
        // Someone included, between two sightings.
        XCTAssertNil(PictureOutputCheck.account(FaceBox(x: 0.41, y: 0.21, width: 0.2, height: 0.34), original: 10.25, regions: [], tracks: tracks))
        // Where the hidden person is, but outside the region drawn: a leak.
        XCTAssertEqual(PictureOutputCheck.account(FaceBox(x: 0.76, y: 0.6, width: 0.1, height: 0.15), original: 10.2, regions: [], tracks: tracks), "near hidden")
        // Found again inside a region the video hid.
        XCTAssertEqual(PictureOutputCheck.account(FaceBox(x: 0.76, y: 0.6, width: 0.1, height: 0.15), original: 10.2,
                                                  regions: [FaceBox(x: 0.75, y: 0.6, width: 0.1, height: 0.15)], tracks: tracks), "hidden")
        // Nobody the people check saw there, or then.
        XCTAssertEqual(PictureOutputCheck.account(FaceBox(x: 0.05, y: 0.7, width: 0.1, height: 0.15), original: 10.2, regions: [], tracks: tracks), "unknown")
        XCTAssertEqual(PictureOutputCheck.account(FaceBox(x: 0.41, y: 0.21, width: 0.2, height: 0.34), original: 30, regions: [], tracks: tracks), "unknown")
        // Nearest wins: a face at the included person's place is theirs, even with the hidden person near.
        XCTAssertNil(PictureOutputCheck.account(FaceBox(x: 0.42, y: 0.2, width: 0.2, height: 0.35), original: 10.4, regions: [], tracks: tracks))
        let check = PictureCheck(checkedAt: Date(), frames: 300, faces: 290, included: 290)
        XCTAssertEqual(check.line, "Seen again: every face in the video, 290 sightings in 300 frames looked at, is someone you included.")
        XCTAssertFalse(check.line.contains("\u{2014}"))
    }

    // MARK: Measures

    /// The variance of the brightness inside `box` (fractions from the top left).
    static func variance(_ picture: RenderTests.Picture, in box: FaceBox) -> Double {
        let x0 = Int(box.x * Double(picture.width)), x1 = Int((box.x + box.width) * Double(picture.width))
        let y0 = Int(box.y * Double(picture.height)), y1 = Int((box.y + box.height) * Double(picture.height))
        var sum = 0.0, squares = 0.0, n = 0.0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let i = (y * picture.width + x) * 4
                let l = 0.2126 * Double(picture.rgba[i]) + 0.7152 * Double(picture.rgba[i + 1]) + 0.0722 * Double(picture.rgba[i + 2])
                sum += l
                squares += l * l
                n += 1
            }
        }
        let mean = sum / max(n, 1)
        return squares / max(n, 1) - mean * mean
    }

    /// PSNR over everything outside `boxes`.
    static func psnr(_ a: RenderTests.Picture, _ b: RenderTests.Picture, outside boxes: [FaceBox]) -> Double {
        var sum = 0.0, count = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let fx = (Double(x) + 0.5) / Double(a.width), fy = (Double(y) + 0.5) / Double(a.height)
                if boxes.contains(where: { $0.contains(x: fx, y: fy) }) { continue }
                let i = (y * a.width + x) * 4
                for c in 0..<3 {
                    let d = Double(a.rgba[i + c]) - Double(b.rgba[i + c])
                    sum += d * d
                }
                count += 3
            }
        }
        let mse = sum / Double(max(1, count))
        return mse == 0 ? 99 : 10 * log10(255 * 255 / mse)
    }

    static func writePair(_ top: RenderTests.Picture, _ bottom: RenderTests.Picture, to url: URL) throws {
        let width = top.width / 2, height = top.height / 2
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: width, height: height * 2 + 20, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height * 2 + 20))
        func image(_ p: RenderTests.Picture) -> CGImage? {
            var bytes = p.rgba
            return bytes.withUnsafeMutableBytes { raw in
                CGContext(data: raw.baseAddress, width: p.width, height: p.height, bitsPerComponent: 8, bytesPerRow: p.width * 4, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
            }
        }
        if let a = image(top) { context.draw(a, in: CGRect(x: 0, y: height + 20, width: width, height: height)) }
        if let b = image(bottom) { context.draw(b, in: CGRect(x: 0, y: 0, width: width, height: height)) }
        guard let out = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, out, nil)
        CGImageDestinationFinalize(destination)
    }
}
