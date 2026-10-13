@preconcurrency import AVFoundation
import CoreImage
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers
import Vision
import XCTest
@testable import Prakriti

/// v2 part M6d's acceptance (docs/v2/PLAN.md M6: checks 5, 6 and 7, the part each names for M6d), on real files through
/// the app's own runner, in development:
///
/// - **Check 5, the card picture of two-people-mixed.mp4:** made by the app after the people pass, with everyone
///   included (the default), then with Gabriel teaching and everyone else left out; and the same chooser held to the
///   stretch where the corner face is on screen (0:20 to 0:60), so its second rule, every other face hidden, is measured
///   too. In each picture Vision must find exactly one face, inside the main track's box; with the corner face hidden,
///   the corner region's variance must fall by at least 80% against the same frame of the original.
/// - **Check 6, hiding:** five frames of two-people-mixed with the corner track hidden, one of them 0.5 s before the corner
///   face first appears and one between two sightings (followed at the full frame rate): Vision must find no face inside
///   any hidden region. Each frame is also measured unhidden, so the check is known to have had a face to hide.
/// - **Check 7, the card pictures are the only images:** after the runs, under Application Support/Prakriti every image
///   (`file --mime-type`) is a card picture in `Thumbnails/`, named for a recording; `People/Faces`, `Voices` and
///   `FaceIndex` do not exist; `Jobs/` is empty; no people file holds a print or a picture.
///
/// Frames of Gabriel's talks are measured, never looked at (this run's instructions, PLAN section 11, D1): the card
/// pictures of the fixture are listed for Ivan in `for-ivan/`, and the picture this test looks at is the hiding drawn
/// over a test pattern (`m6d-hide-test-pattern.png`).
///
///   cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6d
@MainActor
final class HidingAcceptanceTests: XCTestCase {
    func testHidingInPicturesOnRealFiles() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "people" else {
            throw XCTSkip("Reads the two-people fixtures. Run it with: cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6d")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.notifier.poster = nil
        model.log.write("Acceptance test for v2 part M6d (hiding in pictures) started.")
        let folder = SnapshotRenderer.milestoneFolder()
        let forIvan = folder.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        let fixtures = home.appending(path: "Prakriti/Dev/Fixtures", directoryHint: .isDirectory)
        let mixed = fixtures.appending(path: "two-people-mixed.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mixed.path), "missing: \(mixed.path) (cd ~/Code/prakriti/mac && make fixtures)")
        let before = fingerprint(mixed)
        var report = ["v2 part M6d acceptance (hiding in pictures), \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        // Made through the runner, as a dropped file would be.
        let out = paths.outputs.appending(path: mixed.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        precondition(out.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: out)
        let recording = Recording(filePath: mixed.path, recordedAt: Date(), foundAt: Date(), kind: .talk)
        model.context.insert(recording)
        recording.source = model.source(containing: mixed)
        try model.context.save()
        model.setOutput(.podcastEpisode, on: true, for: recording)
        model.setOutput(.transcript, on: true, for: recording)
        try model.context.save()
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        await model.cardPicturesSettled()
        let people = try XCTUnwrap(model.peopleFolders.read(recording.id))
        let rows = (recording.faces?.people ?? []).map { "\($0.label) row \($0.id) \(Format.timecode($0.first)) to \(Format.timecode($0.last))" }
        report.append("two-people-mixed.mp4 made through the runner: \(people.tracks.count) tracks; rows: \(rows.joined(separator: "; ")).")
        // The main face is the row on screen longest; the corner face the other.
        let mainRow = try XCTUnwrap(recording.faces?.people.first?.id)
        let cornerRow = try XCTUnwrap(recording.faces?.people.first { $0.id != mainRow }?.id)
        let mainTracks = people.tracks.filter { $0.person == mainRow }
        let cornerTracks = people.tracks.filter { $0.person == cornerRow }
        let cornerFirst = try XCTUnwrap(cornerTracks.compactMap { $0.boxes.first?.first }.min())
        let cornerLast = try XCTUnwrap(cornerTracks.compactMap { $0.boxes.last?.first }.max())
        report.append(String(format: "Main face: row %d, %d tracks. Corner face: row %d, %d tracks, first seen %.3f s, last %.3f s.", mainRow, mainTracks.count, cornerRow, cornerTracks.count, cornerFirst, cornerLast))
        report.append("")

        /// The box of a row's sighting nearest `time` (within half a second), or nil.
        func box(row: Int, at time: Double) -> FaceBox? {
            let near = people.tracks.filter { $0.person == row }.flatMap(\.boxes).min { abs($0[0] - time) < abs($1[0] - time) }
            guard let near, abs(near[0] - time) <= 0.5 else { return nil }
            return FaceBox(x: near[1], y: near[2], width: near[3], height: near[4])
        }
        func faces(in image: CGImage) async throws -> [FaceBox] {
            try await DetectFaceRectanglesRequest(.revision4).perform(on: image).map { FaceGeometry.fromVision($0.boundingBox.cgRect) }
        }
        func picture(_ url: URL) throws -> CGImage {
            try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }, url.path)
        }
        func describe(_ boxes: [FaceBox]) -> String {
            boxes.isEmpty ? "none" : boxes.map { String(format: "(%.3f, %.3f, %.3f by %.3f)", $0.x, $0.y, $0.width, $0.height) }.joined(separator: ", ")
        }

        // Check 5a: the card picture the app made after the people pass, everyone included.
        func checkAppPicture(_ name: String) async throws -> String {
            let outcome = try XCTUnwrap(model.cardPictureOutcomes[recording.id], "\(name): an outcome")
            let made = try XCTUnwrap(outcome.made, "\(name): a picture was kept: \(outcome.line)")
            let url = model.peopleFolders.thumbnail(for: recording.id)
            let image = try picture(url)
            let found = try await faces(in: image)
            let main = try XCTUnwrap(box(row: mainRow, at: made.time))
            let inside = found.filter { FaceGeometry.padded(main, by: FaceHide.pad).contains(x: $0.centerX, y: $0.centerY) }
            XCTAssertEqual(found.count, 1, "\(name): exactly one unhidden face")
            XCTAssertEqual(inside.count, 1, "\(name): inside the main track's box")
            try FileManager.default.copyItem(at: url, to: forIvan.appending(path: "m6d-card-\(name).jpg"), replacing: true)
            return "\(outcome.line) (\(String(format: "%.1f", outcome.seconds)) s, \(outcome.tried) looked at). \(image.width) by \(image.height). "
                + "Vision finds \(found.count) face(s): \(describe(found)); inside the main track's box: \(inside.count). File: \(url.path)"
        }
        report.append("Check 5a, the app's card picture, everyone included (the default): " + (try await checkAppPicture("everyone-included")))

        // Check 5b: Gabriel teaching, everyone else left out: the picture is deleted at once and made again.
        model.setTeacher(gabriel, for: recording)
        model.setAllUnnamed(.leaveOut, in: recording)
        let deletedAtOnce = !FileManager.default.fileExists(atPath: model.peopleFolders.thumbnail(for: recording.id).path)
        XCTAssertTrue(deletedAtOnce, "the old picture goes the moment the choice changes")
        await model.cardPicturesSettled()
        XCTAssertTrue(recording.hidesFace(row: cornerRow))
        XCTAssertFalse(recording.hidesFace(row: mainRow))
        report.append("Check 5b, Gabriel teaching, everyone else Left Out: the old picture deleted at once: \(deletedAtOnce ? "yes" : "NO"). Made again: "
                      + (try await checkAppPicture("corner-left-out")))

        // Check 5c: the same chooser held to the stretch with the corner face on screen, so the corner face is hidden in it.
        let scratch = FileManager.default.temporaryDirectory.appending(path: "prakriti-m6d-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let scratchFolders = PeopleFolders(support: scratch)
        let plan = recording.hidePlan(people)
        XCTAssertEqual(Set(plan.tracks.map(\.id)), Set(cornerTracks.map(\.id)), "the corner face's tracks, and only they, are hidden")
        let forced = try await CardPicture.make(original: mixed, recordingID: recording.id, people: people, plan: plan, namedRows: recording.namedFaceRows,
                                                folders: scratchFolders, now: Date(), within: cornerFirst...cornerLast)
        let forcedMade = try XCTUnwrap(forced.made, forced.line)
        XCTAssertEqual(forcedMade.rule, .othersHidden)
        let forcedURL = scratchFolders.thumbnail(for: recording.id)
        let forcedImage = try picture(forcedURL)
        let forcedFaces = try await faces(in: forcedImage)
        let mainThen = try XCTUnwrap(box(row: mainRow, at: forcedMade.time))
        let cornerThen = try XCTUnwrap(box(row: cornerRow, at: forcedMade.time))
        XCTAssertEqual(forcedFaces.count, 1, "exactly one unhidden face")
        XCTAssertTrue(forcedFaces.allSatisfy { FaceGeometry.padded(mainThen, by: FaceHide.pad).contains(x: $0.centerX, y: $0.centerY) }, "inside the main track's box")
        // The variance in the corner region, against the same frame of the original at the same size.
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: mixed))
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let source = try await generator.image(at: CMTime(seconds: forcedMade.time, preferredTimescale: 600)).image
        let scaled = try scale(source, toWidth: forcedImage.width)
        let was = variance(scaled, in: cornerThen), now = variance(forcedImage, in: cornerThen)
        let fall = was > 0 ? 1 - now / was : 0
        XCTAssertGreaterThanOrEqual(fall, 0.8, "the corner region's variance falls by at least 80%")
        try FileManager.default.copyItem(at: forcedURL, to: forIvan.appending(path: "m6d-card-corner-hidden.jpg"), replacing: true)
        report.append("Check 5c, the chooser held to \(String(format: "%.2f", cornerFirst)) to \(String(format: "%.2f", cornerLast)) s (the corner face on screen): \(forced.line) "
                      + "(\(String(format: "%.1f", forced.seconds)) s, \(forced.tried) looked at, \(forced.refused) refused). Vision finds \(forcedFaces.count) face(s): \(describe(forcedFaces)), "
                      + "inside the main track's box \(describe([mainThen])). Corner region \(describe([cornerThen])): variance \(String(format: "%.1f", was)) in the original, "
                      + "\(String(format: "%.1f", now)) in the picture, a fall of \(String(format: "%.1f", fall * 100))%.")
        report.append("")

        // Check 6: five frames with the corner track hidden, including 0.5 s before the corner face first appears.
        let times = [cornerFirst - 0.47, cornerFirst - 0.02, cornerFirst + 0.27, (cornerFirst + cornerLast) / 2 + 0.13, cornerLast + 0.4]
        report.append("Check 6, five frames of two-people-mixed with the corner track hidden:")
        var worst = 0
        for time in times {
            let hidden = try await FaceFollower.frame(file: mixed, plan: plan, at: time)
            let frame = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            let rendered = try XCTUnwrap(CIContext().createCGImage(FaceHide.apply(CIImage(cgImage: frame), regions: hidden.regions), from: CGRect(x: 0, y: 0, width: frame.width, height: frame.height)))
            let after = try await faces(in: rendered)
            let beforeFaces = try await faces(in: frame)
            let inHidden = after.filter { face in hidden.regions.contains { FaceHide.covers($0, x: face.centerX, y: face.centerY) } }
            let hadThere = beforeFaces.filter { face in hidden.regions.contains { FaceHide.covers($0, x: face.centerX, y: face.centerY) } }
            worst = max(worst, inHidden.count)
            XCTAssertEqual(inHidden.count, 0, "a face inside a hidden region at \(time)")
            report.append(String(format: "  %.3f s (frame %.3f): %d region(s), %@; unhidden, Vision finds %d face(s), %d inside a region; hidden, %d face(s) (%@), %d inside a region.",
                                 time, hidden.frameTime, hidden.regions.count, hidden.how.joined(separator: ", "), beforeFaces.count, hadThere.count,
                                 after.count, describe(after), inHidden.count))
        }
        report.append("  Faces inside a hidden region, the most in any frame: \(worst).")
        report.append("")

        // A rendered picture to look at, never of a person: the hiding drawn over a test pattern (the moving square, followed).
        let square = try HidingTests.movingSquare()
        let squarePlan = HidePlan(tracks: [HiddenTrack(id: 1, spots: stride(from: 0.0, through: 5.5, by: 0.5).map { .init(time: $0, box: HidingTests.squareBox(at: $0)) })])
        let squareFrame = try await FaceFollower.frame(file: square, plan: squarePlan, at: 2.4)
        let squareGenerator = AVAssetImageGenerator(asset: AVURLAsset(url: square))
        squareGenerator.requestedTimeToleranceBefore = .zero
        squareGenerator.requestedTimeToleranceAfter = .zero
        let squareImage = try await squareGenerator.image(at: CMTime(seconds: 2.4, preferredTimescale: 600)).image
        let original = CIImage(cgImage: squareImage)
        let hiddenSquare = FaceHide.apply(original, regions: squareFrame.regions)
        let pair = hiddenSquare.transformed(by: CGAffineTransform(translationX: 0, y: 0))
            .composited(over: original.transformed(by: CGAffineTransform(translationX: 0, y: original.extent.height + 20)))
        let look = folder.appending(path: "m6d-hide-test-pattern.png")
        try CIContext().writePNGRepresentation(of: pair.cropped(to: CGRect(x: 0, y: 0, width: original.extent.width, height: original.extent.height * 2 + 20)),
                                               to: look, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        report.append("Looked at: \(look.path): the moving test pattern square at 2.4 s, above as recorded, below hidden (regions: \(squareFrame.how.joined(separator: ", "))).")
        report.append("")

        // Check 7: the card pictures are the only images; nothing stored for strangers.
        report.append("Check 7, nothing stored for strangers, and the card pictures the only images:")
        for folders in [model.peopleFolders, PeopleFolders(support: AppPaths(mode: .live).applicationSupport)] {
            for forbidden in folders.forbidden {
                XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), forbidden.path)
                report.append("  does not exist: \(forbidden.path): \(FileManager.default.fileExists(atPath: forbidden.path) ? "NO, IT EXISTS" : "yes")")
            }
        }
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        XCTAssertEqual(jobs, [], "no job folder is left")
        report.append("  development Jobs folder: \(jobs.isEmpty ? "empty" : "NOT EMPTY: \(jobs)")")
        for file in (try? FileManager.default.contentsOfDirectory(at: model.peopleFolders.recordings, includingPropertiesForKeys: nil)) ?? [] {
            try PeopleTests.assertNoPrintAndNoPicture(try Data(contentsOf: file))
        }
        let (images, examined) = try Self.imagesUnderApplicationSupport()
        let strays = images.filter { !Self.isCardPicture($0) }
        XCTAssertEqual(strays, [], "an image that is not a card picture")
        report.append("  `file --mime-type` on every file under ~/Library/Application Support/Prakriti: \(examined) files, \(images.count) images, "
                      + "\(images.count - strays.count) of them card pictures in Thumbnails/, \(strays.count) anything else" + (strays.isEmpty ? "." : ": \(strays)"))
        report.append("")
        XCTAssertEqual(fingerprint(mixed), before, "the fixture is unchanged")
        report.append("two-people-mixed.mp4 unchanged by size and date: \(fingerprint(mixed) == before ? "yes" : "NO")")
        report.append("For Ivan (frames of the talk, never opened by the build): \(forIvan.path)/m6d-card-*.jpg")
        try report.joined(separator: "\n").write(to: folder.appending(path: "acceptance-hiding.txt"), atomically: true, encoding: .utf8)
        print(report.joined(separator: "\n"))
    }

    /// Every image under ~/Library/Application Support/Prakriti, by `file --mime-type`, and how many files were looked at.
    static func imagesUnderApplicationSupport() throws -> ([String], Int) {
        let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Prakriti", directoryHint: .isDirectory)
        var images: [String] = []
        var examined = 0
        for url in (FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.compactMap { $0 as? URL } ?? [])
        where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            examined += 1
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
            process.arguments = ["-b", "--mime-type", url.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            let kind = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            process.waitUntilExit()
            if kind.hasPrefix("image/") { images.append(url.path) }
        }
        return (images, examined)
    }

    /// A card picture: `<a mode's Application Support>/Thumbnails/<recording id>.jpg`.
    static func isCardPicture(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().lastPathComponent == "Thumbnails" && url.pathExtension == "jpg"
            && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
    }

    private func scale(_ image: CGImage, toWidth width: Int) throws -> CGImage {
        let factor = Double(width) / Double(image.width)
        let ci = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        return try XCTUnwrap(CIContext().createCGImage(ci, from: ci.extent))
    }

    /// The variance of the luma inside `box` (0 to 1 from the top left).
    private func variance(_ image: CGImage, in box: FaceBox) -> Double {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var values = [Double](repeating: 0, count: width * height)
        for i in 0..<(width * height) { values[i] = 0.299 * Double(bytes[i * 4]) + 0.587 * Double(bytes[i * 4 + 1]) + 0.114 * Double(bytes[i * 4 + 2]) }
        return HidingTests.variance(values, width: width, height: height, in: box)
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}

private extension FileManager {
    func copyItem(at source: URL, to target: URL, replacing: Bool) throws {
        if replacing { try? removeItem(at: target) }
        try copyItem(at: source, to: target)
    }
}
