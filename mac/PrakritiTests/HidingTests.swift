@preconcurrency import AVFoundation
import CoreImage
import Foundation
import SwiftData
import Vision
import XCTest
@testable import Prakriti

/// Hiding in pictures (v2 part M6d, docs/v2/PLAN.md M6 and research-people.md 3.2 and 3.5): which faces are hidden, the
/// regions held around each sighting, the full-rate follower on a moving object, the Core Image hiding itself, the card
/// picture's choice of moment and its check, the People overlay's boxes, and the privacy rules of the card picture (none
/// before the people pass; deleted at once when a choice changes). Nothing here reads a talk or draws a face: the real
/// files are `HidingAcceptanceTests`, and the pictures here are test patterns made by ffmpeg and Core Image.
@MainActor
final class HidingTests: XCTestCase {
    private func track(_ id: Int, row: Int?, from start: Double, to end: Double, box: FaceBox, every: Double = 0.5) -> PeopleFile.Track {
        let boxes = stride(from: start, through: end + 0.0001, by: every).map { [$0, box.x, box.y, box.width, box.height, 0.9] }
        return PeopleFile.Track(id: id, person: row, start: start, end: end, boxes: boxes)
    }

    private let main = FaceBox(x: 0.42, y: 0.27, width: 0.13, height: 0.24)
    private let corner = FaceBox(x: 0.81, y: 0.72, width: 0.04, height: 0.07)

    /// The two-people-mixed fixture's shape: the main face all through, the corner face from 0:20 to 0:60, and one glimpse.
    private func twoPeopleFile(id: UUID = UUID(), cuts: [Double] = []) -> PeopleFile {
        PeopleFile(recordingID: id, duration: 90.1, frameWidth: 1920, frameHeight: 1080,
                   tracks: [track(1, row: 1, from: 0, to: 90, box: main), track(2, row: 2, from: 20, to: 59.5, box: corner),
                            track(3, row: nil, from: 70, to: 70, box: FaceBox(x: 0.05, y: 0.05, width: 0.03, height: 0.05))],
                   people: Fixtures.facesTwoPeople(at: Fixtures.now).people, cuts: cuts)
    }

    // MARK: Which faces are hidden, and where

    func testThePlanHoldsEachRegionHalfASecondBeforeAndAfterAndAroundEverySighting() {
        let file = twoPeopleFile()
        let plan = HidePlan.from(file) { $0 == 2 }
        XCTAssertEqual(plan.tracks.map(\.id), [2])
        XCTAssertEqual(plan.tracks.first?.spots.count, 80)
        // Half a second before the first sighting, and after the last.
        XCTAssertTrue(plan.active(at: 19.4).isEmpty)
        XCTAssertEqual(plan.active(at: 19.5).map(\.id), [2])
        XCTAssertEqual(plan.held(at: 19.6), [corner], "held before the face is first seen")
        XCTAssertEqual(plan.held(at: 59.9), [corner], "held after the face is last seen")
        XCTAssertTrue(plan.active(at: 60.1).isEmpty)
        // Between two sightings half a second apart, both places are hidden.
        XCTAssertEqual(plan.held(at: 30.25).count, 2)
        // The glimpses (row nil) are their own rule.
        XCTAssertEqual(HidePlan.from(file) { $0 == nil }.tracks.map(\.id), [3])
        XCTAssertTrue(HidePlan.from(file) { _ in false }.isEmpty)
    }

    func testAFaceIsHiddenWhenItsChoiceIsHideFaceOrLeaveOutForAnyOutput() throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: FileManager.default.temporaryDirectory),
                             settings: .ephemeral(), log: AppLog(directory: nil), now: { Fixtures.now })
        let recording = Recording(filePath: "/tmp/2026-09-13 talk.mp4", foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        var faces = Fixtures.facesTwoPeople(at: Fixtures.now)
        faces.glimpses = 1
        recording.facesJSON = faces.json()
        model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.now), to: recording)
        XCTAssertFalse(recording.hidesFace(row: 1))
        XCTAssertFalse(recording.hidesFace(row: 2), "everyone starts as Include (Ivan, 12 Oct)")
        XCTAssertFalse(recording.hidesFace(row: nil))
        model.setChoice(.hideFace, for: .face(2), in: recording)
        XCTAssertTrue(recording.hidesFace(row: 2))
        model.setChoice(.leaveOut, for: .face(2), in: recording)
        XCTAssertTrue(recording.hidesFace(row: 2))
        // Left out of the video only: still hidden in the card picture (the strictest of the outputs).
        model.setChoice(.include, for: .face(2), in: recording)
        model.setChoice(.leaveOut, for: .face(2), output: .video, in: recording)
        XCTAssertTrue(recording.hidesFace(row: 2))
        // Set All Unnamed To takes the faces seen for under a second with it.
        model.setChoice(.include, for: .face(2), in: recording)
        model.setAllUnnamed(.hideFace, in: recording)
        XCTAssertTrue(recording.hidesFace(row: nil), "the glimpses go with everyone not named")
        XCTAssertTrue(recording.hidesFace(row: 1) && recording.hidesFace(row: 2))
        // Naming the teacher keeps their face: a named person is never set by Set All Unnamed To.
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        model.setTeacher(gabriel, for: recording)
        XCTAssertFalse(recording.hidesFace(row: 1), "Gabriel's own choice, Include")
        XCTAssertTrue(recording.hidesFace(row: 2))
        XCTAssertEqual(recording.namedFaceRows, [1])
        XCTAssertEqual(recording.overlayLabel(row: 1).name, "Gabriel")
        XCTAssertEqual(recording.overlayLabel(row: 2).name, "Unnamed 2")
        XCTAssertEqual(recording.overlayLabel(row: 2).choice, .hideFace)
        XCTAssertEqual(recording.overlayLabel(row: nil).name, "Unnamed")
    }

    // MARK: The Core Image function

    /// A busy test pattern (a fine checkerboard of colors), so hiding shows as a fall in variance.
    private func pattern(width: Int = 1920, height: Int = 1080) -> CIImage {
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputColor0": CIColor(red: 0.95, green: 0.9, blue: 0.8), "inputColor1": CIColor(red: 0.05, green: 0.1, blue: 0.3),
            "inputWidth": 6, "inputSharpness": 1, "inputCenter": CIVector(x: 0, y: 0),
        ])!.outputImage!
        return checker.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func luma(_ image: CGImage) -> (width: Int, height: Int, values: [Double]) {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var values = [Double](repeating: 0, count: width * height)
        for i in 0..<(width * height) { values[i] = 0.299 * Double(bytes[i * 4]) + 0.587 * Double(bytes[i * 4 + 1]) + 0.114 * Double(bytes[i * 4 + 2]) }
        return (width, height, values)
    }

    /// The variance of the luma inside `box` (0 to 1 from the top left; a CGContext's rows start at the top).
    static func variance(_ values: [Double], width: Int, height: Int, in box: FaceBox) -> Double {
        let x0 = max(0, Int(box.x * Double(width))), x1 = min(width, Int((box.x + box.width) * Double(width)))
        let y0 = max(0, Int(box.y * Double(height))), y1 = min(height, Int((box.y + box.height) * Double(height)))
        var sum = 0.0, squares = 0.0, count = 0.0
        for y in y0..<max(y0, y1) { for x in x0..<max(x0, x1) { let v = values[y * width + x]; sum += v; squares += v * v; count += 1 } }
        guard count > 0 else { return 0 }
        let mean = sum / count
        return squares / count - mean * mean
    }

    func testHidingBlursAndPixelatesOnlyThePaddedEllipseOfEachRegion() throws {
        let source = pattern()
        let context = CIContext()
        let before = luma(try XCTUnwrap(context.createCGImage(source, from: source.extent)))
        let hidden = FaceHide.apply(source, regions: [corner, main])
        XCTAssertEqual(hidden.extent, source.extent, "the picture keeps its size")
        let after = luma(try XCTUnwrap(context.createCGImage(hidden, from: hidden.extent)))
        for box in [corner, main] {
            let was = Self.variance(before.values, width: before.width, height: before.height, in: box)
            let now = Self.variance(after.values, width: after.width, height: after.height, in: box)
            XCTAssertGreaterThan(was, 1000)
            XCTAssertLessThan(now, was * 0.2, "the variance inside the box falls by at least 80% (check 5's measure)")
        }
        // Far from either region, the picture is untouched.
        let away = FaceBox(x: 0.05, y: 0.05, width: 0.2, height: 0.2)
        let outside = (Int(away.y * 1080)..<Int((away.y + away.height) * 1080)).flatMap { y in (Int(away.x * 1920)..<Int((away.x + away.width) * 1920)).map { y * 1920 + $0 } }
        XCTAssertEqual(outside.filter { abs(before.values[$0] - after.values[$0]) > 0.5 }.count, 0)
        // The ellipse is padded 2.0 times (1.6 until part M10b) and covers the whole box, corners included.
        for (x, y) in [(main.x, main.y), (main.x + main.width, main.y), (main.x, main.y + main.height), (main.x + main.width, main.y + main.height)] {
            XCTAssertTrue(FaceHide.covers(main, x: x, y: y), "corner \(x), \(y) of the box is inside the solid ellipse")
        }
        XCTAssertFalse(FaceHide.covers(main, x: main.centerX + main.width, y: main.centerY))
        // The strength research-people.md 3.2 asks for: a blur of at least a quarter of the face's width, and no more than
        // 8 blocks across the face.
        XCTAssertGreaterThanOrEqual(FaceHide.blurShare, 0.25)
        XCTAssertLessThanOrEqual(FaceHide.blocksAcross / FaceHide.pad, 8)
        XCTAssertGreaterThanOrEqual(FaceHide.pad, 2.0, "never smaller than measured in part M10b: the chin of a small face showed under 1.6")
        // No region, no change.
        XCTAssertEqual(FaceHide.apply(source, regions: []).extent, source.extent)
    }

    func testWhereAHiddenRegionCoversAnIncludedFaceHidingWins() throws {
        // Two faces side by side, the hidden one's padded region overlapping the included one: the overlap is hidden.
        let included = FaceBox(x: 0.40, y: 0.30, width: 0.12, height: 0.22)
        let hiddenFace = FaceBox(x: 0.50, y: 0.30, width: 0.12, height: 0.22)
        let source = pattern()
        let context = CIContext()
        let before = luma(try XCTUnwrap(context.createCGImage(source, from: source.extent)))
        let after = luma(try XCTUnwrap(context.createCGImage(FaceHide.apply(source, regions: [hiddenFace]), from: source.extent)))
        let overlap = FaceBox(x: 0.475, y: 0.38, width: 0.02, height: 0.06)
        XCTAssertTrue(FaceHide.covers(hiddenFace, x: overlap.centerX, y: overlap.centerY))
        XCTAssertLessThan(Self.variance(after.values, width: 1920, height: 1080, in: overlap),
                          Self.variance(before.values, width: 1920, height: 1080, in: overlap) * 0.2)
        _ = included
    }

    // MARK: Following a face at the full frame rate

    /// A 6 s, 30 fps test video: a test pattern square, 160 px, moving right at 300 px a second over grey (made by ffmpeg).
    static func movingSquare() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "prakriti-moving-square.mp4")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let ffmpeg = Process()
        ffmpeg.executableURL = ToolPaths.standard.ffmpeg
        ffmpeg.arguments = ["-hide_banner", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=gray:s=1280x720:r=30:d=6", "-f", "lavfi", "-i", "testsrc2=s=160x160:r=30:d=6",
                            "-filter_complex", "[0][1]overlay=x='100+300*t':y=280:shortest=1", "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", url.path]
        try ffmpeg.run()
        ffmpeg.waitUntilExit()
        XCTAssertEqual(ffmpeg.terminationStatus, 0)
        return url
    }

    /// Where the square truly is at `time`.
    static func squareBox(at time: Double) -> FaceBox {
        FaceBox(x: (100 + 300 * time) / 1280, y: 280.0 / 720, width: 160.0 / 1280, height: 160.0 / 720)
    }

    func testTheFollowerKeepsUpWithAMovingFaceBetweenSightings() async throws {
        let video = try Self.movingSquare()
        // Sightings two a second, as the face step makes them; the frames between them are where a held box falls behind.
        let spots = stride(from: 0.0, through: 5.5, by: 0.5).map { HiddenTrack.Spot(time: $0, box: Self.squareBox(at: $0)) }
        let plan = HidePlan(tracks: [HiddenTrack(id: 1, spots: spots)])
        var lines: [String] = []
        for time in [0.7, 1.2, 2.4, 3.1333] {
            let frame = try await FaceFollower.frame(file: video, plan: plan, at: time)
            let truth = Self.squareBox(at: frame.frameTime)
            let followed = try XCTUnwrap(zip(frame.regions, frame.how).first { $0.1 == "followed" }?.0, "followed at \(time): \(frame.how)")
            let heldOnly = try XCTUnwrap(plan.held(at: time).first)
            let followedOverlap = FaceGeometry.overlap(followed, truth), heldOverlap = FaceGeometry.overlap(heldOnly, truth)
            lines.append(String(format: "%.3f s (frame %.3f): followed overlap %.2f, held box alone %.2f", time, frame.frameTime, followedOverlap, heldOverlap))
            XCTAssertGreaterThan(followedOverlap, 0.6, "the follower stays on the square at \(time)")
            // Every region together covers the square's middle: nothing of it shows.
            XCTAssertTrue(frame.regions.contains { FaceHide.covers($0, x: truth.centerX, y: truth.centerY) })
        }
        print("Follower on a moving square:\n" + lines.joined(separator: "\n"))
    }

    // MARK: The card picture: which moment, and its check

    func testTheCardPictureLooksFirstWhereEveryoneIsIncludedAndNeverNearACutOrTheEdges() {
        let file = twoPeopleFile(cuts: [80])
        // Nobody hidden: every moment with a face is a candidate for rule 1.
        let open = CardPicture.candidates(file, plan: HidePlan(), namedRows: [])
        XCTAssertEqual(open.included.count, CardPicture.tries)
        XCTAssertTrue(open.hidden.isEmpty)
        // The corner face hidden: rule 1 only where it is not on screen, with half a second to spare; rule 2 where it is.
        let plan = HidePlan.from(file) { $0 == 2 }
        let hiding = CardPicture.candidates(file, plan: plan, namedRows: [1])
        XCTAssertFalse(hiding.included.isEmpty)
        XCTAssertTrue(hiding.included.allSatisfy { $0 < 19.5 || $0 > 60 }, "\(hiding.included)")
        XCTAssertTrue(hiding.included.allSatisfy { $0 >= CardPicture.edge && $0 <= 90.1 - CardPicture.edge }, "not at the edges")
        XCTAssertTrue(hiding.included.allSatisfy { abs($0 - 80) >= CardPicture.nearCut }, "not near a change of picture")
        XCTAssertTrue(hiding.hidden.allSatisfy { $0 >= 20 && $0 <= 59.5 })
        // Everyone hidden but nobody included in a frame: rule 2 still has moments, and the check decides.
        let all = CardPicture.candidates(file, plan: HidePlan.from(file) { _ in true }, namedRows: [])
        XCTAssertTrue(all.included.isEmpty)
        XCTAssertFalse(all.hidden.isEmpty)
        // No picture: nothing at all.
        var audio = file
        audio.hasPicture = false
        XCTAssertTrue(CardPicture.candidates(audio, plan: HidePlan(), namedRows: []).included.isEmpty)
    }

    func testTheCheckRefusesAFaceInsideAHiddenRegionOrOneNobodyAccountsFor() {
        // The main face, found where the people pass saw it: accounted for.
        XCTAssertTrue(CardPicture.accounted(found: [main], included: [main], hidden: [corner]))
        // A face found inside the hidden region: the hiding failed, refused.
        XCTAssertFalse(CardPicture.accounted(found: [main, corner], included: [main], hidden: [corner]))
        // A face the people pass never saw (nobody can say whether they are included): refused.
        XCTAssertFalse(CardPicture.accounted(found: [main, FaceBox(x: 0.1, y: 0.1, width: 0.05, height: 0.09)], included: [main], hidden: []))
        // No face at all: nothing to refuse.
        XCTAssertTrue(CardPicture.accounted(found: [], included: [], hidden: []))
    }

    func testTheOutcomeLineNamesNoOne() {
        var outcome = CardPicture.Outcome()
        outcome.tried = 3
        XCTAssertEqual(outcome.line, "Card picture: none of the 3 frames looked at could be made safe, so the card keeps its plain tile.")
        outcome.made = .init(time: 41.0, rule: .othersHidden, hidden: 1, faces: 1, madeAt: Fixtures.now)
        outcome.refused = 1
        XCTAssertEqual(outcome.line, "Card picture: the frame at 0:41, with 1 face hidden. 1 frame refused by the check.")
        outcome.made = .init(time: 12, rule: .everyoneIncluded, hidden: 0, faces: 1, madeAt: Fixtures.now)
        outcome.refused = 0
        XCTAssertEqual(outcome.line, "Card picture: the frame at 0:12, where everyone seen is included.")
        XCTAssertEqual(CardPicture.orientation(of: .identity), .up)
        XCTAssertEqual(CardPicture.orientation(of: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)), .right)
    }

    // MARK: The People overlay's boxes

    func testTheOverlayMovesEachBoxBetweenSightingsAndDropsItWhenTheFaceIsGone() {
        let a = FaceBox(x: 0.2, y: 0.2, width: 0.1, height: 0.2), b = FaceBox(x: 0.4, y: 0.2, width: 0.1, height: 0.2)
        let file = PeopleFile(recordingID: UUID(), duration: 10, frameWidth: 1920, frameHeight: 1080,
                              tracks: [PeopleFile.Track(id: 1, person: 1, start: 1, end: 1.5, boxes: [[1, a.x, a.y, a.width, a.height, 1], [1.5, b.x, b.y, b.width, b.height, 1]]),
                                       PeopleFile.Track(id: 2, person: nil, start: 5, end: 5, boxes: [[5, 0.7, 0.7, 0.05, 0.1, 1]])],
                              people: [])
        XCTAssertEqual(PeopleBoxes.boxes(file, at: 1.25).first?.box.x ?? 0, 0.3, accuracy: 1e-9, "halfway between two sightings")
        XCTAssertEqual(PeopleBoxes.boxes(file, at: 1.7).first?.box, b, "held a quarter second after the last")
        XCTAssertTrue(PeopleBoxes.boxes(file, at: 1.8).isEmpty)
        XCTAssertEqual(PeopleBoxes.boxes(file, at: 5.2).map(\.id), [2], "a glimpse shows around its one sighting")
        XCTAssertNil(PeopleBoxes.boxes(file, at: 5.2).first?.row)
        XCTAssertTrue(PeopleBoxes.boxes(file, at: 3).isEmpty)
        // The picture fitted in the player, as `.resizeAspect` draws it.
        let fitted = PeopleOverlay.pictureRect(in: CGSize(width: 1000, height: 1000), frame: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(fitted.minX, 0, accuracy: 1e-6)
        XCTAssertEqual(fitted.minY, 218.75, accuracy: 1e-6)
        XCTAssertEqual(fitted.width, 1000, accuracy: 1e-6)
        XCTAssertEqual(fitted.height, 562.5, accuracy: 1e-6)
    }

    // MARK: Privacy rules of the card picture (design spec 9.3)

    func testNoCardPictureBeforeThePeoplePassAndNoneLeftWhenAChoiceChanges() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "prakriti-hiding-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: home),
                             settings: .ephemeral(), log: AppLog(directory: nil), now: { Fixtures.now })
        let video = try Self.movingSquare()
        let recording = Recording(filePath: video.path, foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        // Before the face step: nothing is written, whatever asks.
        model.refreshCardPicture(recording)
        await model.cardPicturesSettled()
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.peopleFolders.thumbnail(for: recording.id).path), "no picture before the people pass")
        // After it (a people file with the square as the only "face", included): the picture is made, and is the only image.
        var faces = FacesFound(checkedAt: Fixtures.now, duration: 6)
        faces.mostAtOnce = 1
        faces.people = [FacePerson(id: 1, label: "Unnamed 1", onScreen: 6, first: 0, last: 5.5, appearances: 1, keyTime: 3, keyBox: Self.squareBox(at: 3))]
        recording.facesJSON = faces.json()
        let file = PeopleFile(recordingID: recording.id, duration: 6, frameWidth: 1280, frameHeight: 720,
                              tracks: [PeopleFile.Track(id: 1, person: 1, start: 0, end: 5.5,
                                                        boxes: stride(from: 0.0, through: 5.5, by: 0.5).map { t in let b = Self.squareBox(at: t); return [t, b.x, b.y, b.width, b.height, 0.9] })],
                              people: faces.people)
        let saving = try model.peopleFolders.newJob()
        try file.save(in: model.peopleFolders, job: saving)
        try FileManager.default.removeItem(at: saving)
        model.refreshCardPicture(recording)
        await model.cardPicturesSettled()
        let picture = model.peopleFolders.thumbnail(for: recording.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: picture.path), "made after the people pass")
        let made = try XCTUnwrap(CGImageSourceCreateWithURL(picture as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        XCTAssertEqual(made.width, 1280)
        XCTAssertEqual(made.height, 720)
        // A change of choice deletes it at once, before anything is made again.
        model.setChoice(.hideFace, for: .face(1), in: recording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: picture.path), "deleted the moment the choice changed")
        await model.cardPicturesSettled()
        // Removed from the library: its picture goes with it.
        model.refreshCardPicture(recording)
        await model.cardPicturesSettled()
        _ = model.removeFromLibrary(recording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: picture.path))
        // No job folder is left behind.
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? [], [])
    }
}
