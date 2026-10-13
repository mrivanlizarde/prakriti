import CoreGraphics
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Faces in a recording (v2 part M6a, docs/v2/PLAN.md M6 check 1 and the rules of check 7): the coordinate
/// conversion, tracking and its breaks on made-up boxes, the rows, the facts and their words, the people file
/// that keeps no print and no picture, and the job folder. Nothing here reads a talk: the real recordings are
/// `PeopleAcceptanceTests` (make accept-people).
@MainActor
final class PeopleTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-people-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    private func face(_ x: Double, _ y: Double, _ w: Double = 0.13, _ h: Double = 0.24, quality: Double? = nil) -> FaceDetection {
        FaceDetection(box: FaceBox(x: x, y: y, width: w, height: h), confidence: 0.8, quality: quality)
    }

    /// Samples every 0.5 s from `from` to `to` (inclusive), each with the faces `faces(t)` gives.
    private func samples(_ from: Double, _ to: Double, _ faces: (Double) -> [FaceDetection]) -> [FaceSample] {
        stride(from: from, through: to + 0.0001, by: 0.5).map { FaceSample(time: $0, faces: faces($0)) }
    }

    // MARK: Check 1: coordinates

    /// Vision's boxes start at the bottom left, the people file's at the top left (Media Intelligence's way).
    func testVisionAndTopLeftBoxesRoundTrip() {
        let vision = CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.25)
        let box = FaceGeometry.fromVision(vision)
        XCTAssertEqual(box.x, 0.1, accuracy: 1e-12)
        XCTAssertEqual(box.y, 0.05, accuracy: 1e-12, "a face near the top in Vision is near the top here too")
        XCTAssertEqual(box.width, 0.2, accuracy: 1e-12)
        XCTAssertEqual(box.height, 0.25, accuracy: 1e-12)
        for _ in 0..<200 {
            let w = Double.random(in: 0.01...0.5), h = Double.random(in: 0.01...0.5)
            let rect = CGRect(x: Double.random(in: 0...(1 - w)), y: Double.random(in: 0...(1 - h)), width: w, height: h)
            let back = FaceGeometry.toVision(FaceGeometry.fromVision(rect))
            XCTAssertEqual(back.origin.x, rect.origin.x, accuracy: 1e-12)
            XCTAssertEqual(back.origin.y, rect.origin.y, accuracy: 1e-12)
            XCTAssertEqual(back.width, rect.width, accuracy: 1e-12)
            XCTAssertEqual(back.height, rect.height, accuracy: 1e-12)
        }
        // And a top-left box goes to Vision and back.
        let topLeft = FaceBox(x: 0.81, y: 0.72, width: 0.04, height: 0.07)
        XCTAssertEqual(FaceGeometry.fromVision(FaceGeometry.toVision(topLeft)).y, topLeft.y, accuracy: 1e-12)
    }

    // MARK: Check 1: tracking joins and breaks as specified

    func testAFaceThatOverlapsIsOneTrack() {
        // Moving 0.01 across a sample: overlap far above 0.3.
        let tracks = FaceTracker.tracks(samples(0, 30) { t in [face(0.3 + t * 0.002, 0.3)] })
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks[0].sightings.count, 61)
        XCTAssertEqual(tracks[0].start, 0)
        XCTAssertEqual(tracks[0].end, 30)
    }

    func testOverlapBelowThePlansLimitIsStillOneFaceWhenNearAndTheSameSize() {
        let a = FaceBox(x: 0.456, y: 0.580, width: 0.127, height: 0.226)
        let b = FaceBox(x: 0.481, y: 0.465, width: 0.133, height: 0.236)
        // Measured on the two-people fixture at 57.5 and 58.0 s: one head, moved quickly.
        XCTAssertLessThan(FaceGeometry.overlap(a, b), FaceTracker.minimumOverlap)
        XCTAssertGreaterThan(FaceTracker.likeness(a, b), 0, "near and the same size: the same face")
        XCTAssertGreaterThan(FaceTracker.likeness(a, a), 1, "overlapping by 0.3 or more ranks above being near")
        // Far away, or twice the size: another face.
        XCTAssertEqual(FaceTracker.likeness(a, FaceBox(x: 0.8, y: 0.1, width: 0.127, height: 0.226)), 0)
        XCTAssertEqual(FaceTracker.likeness(a, FaceBox(x: 0.456, y: 0.580, width: 0.26, height: 0.45)), 0.0,
                       "same center, twice the size, overlap 0.25: another face")
    }

    func testUnseenForOneAndAHalfSecondsJoinsAndLongerBreaks() {
        // Seen at 0 to 5, unseen at 5.5 and 6.0, seen again at 6.5: 1.5 s since the last sighting, one track.
        let joined = FaceTracker.tracks(samples(0, 10) { t in (t > 5.2 && t < 6.2) ? [] : [face(0.3, 0.3)] })
        XCTAssertEqual(joined.count, 1)
        // Unseen at 5.5, 6.0 and 6.5, seen at 7.0: 2 s, two tracks.
        let broken = FaceTracker.tracks(samples(0, 10) { t in (t > 5.2 && t < 6.7) ? [] : [face(0.3, 0.3)] })
        XCTAssertEqual(broken.count, 2)
        XCTAssertEqual(broken[0].end, 5)
        XCTAssertEqual(broken[1].start, 7)
    }

    func testACutEndsEveryTrack() {
        let all = samples(0, 10) { _ in [face(0.3, 0.3), face(0.7, 0.3)] }
        XCTAssertEqual(FaceTracker.tracks(all).count, 2)
        let cut = FaceTracker.tracks(all, cuts: [5.0])
        XCTAssertEqual(cut.count, 4, "both faces start new tracks at the cut")
        XCTAssertEqual(Set(cut.map(\.start)), [0, 5])
    }

    func testTwoFacesAtOnceAreTwoTracksThatNeverSwap() {
        let tracks = FaceTracker.tracks(samples(0, 20) { t in
            var faces = [face(0.4, 0.3)]
            if t >= 5 && t <= 15 { faces.append(face(0.81, 0.72, 0.04, 0.07)) }
            return faces
        })
        XCTAssertEqual(tracks.count, 2)
        let corner = tracks.first { $0.sightings[0].box.x > 0.7 }
        XCTAssertEqual(corner?.start, 5)
        XCTAssertEqual(corner?.end, 15)
        XCTAssertTrue(corner?.sightings.allSatisfy { $0.box.x > 0.7 } ?? false)
    }

    // MARK: Rows and facts

    func testRowsJoinTracksInOnePlaceAndNeverTwoAtOnce() {
        // One face leaves for 4 s and comes back where it was: two tracks, one row. A face seen at the same time
        // elsewhere is its own row.
        let tracks = FaceTracker.tracks(samples(0, 30) { t in
            var faces: [FaceDetection] = (t > 10 && t < 14.6) ? [] : [face(0.4, 0.3)]
            if t >= 20 { faces.append(face(0.81, 0.72, 0.04, 0.07)) }
            return faces
        })
        XCTAssertEqual(tracks.count, 3)
        let rows = FaceGrouping.rows(tracks)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first?.count, 2)
    }

    func testTheFactsAndTheirWords() {
        let one = FacesFound.from(samples: samples(0, 99.5) { _ in [face(0.4, 0.3)] }, cuts: [], duration: 100, checkedAt: Fixtures.now).found
        XCTAssertEqual(one.mostAtOnce, 1)
        XCTAssertFalse(one.otherPeopleAppear)
        XCTAssertEqual(one.line, "One person at a time.")
        XCTAssertEqual(one.summary, "One person at a time is on screen. A face is seen in 100 percent of the recording.")
        XCTAssertEqual(one.people.map(\.label), ["Unnamed 1"])
        XCTAssertEqual(one.people.first?.onScreen, 100)

        let two = FacesFound.from(samples: samples(0, 89.5) { t in
            var faces = [face(0.4, 0.3, quality: t == 40 ? 0.9 : 0.5)]
            if t >= 20 && t < 60 { faces.append(face(0.81, 0.72, 0.04, 0.07)) }
            if t == 70 { faces.append(face(0.1, 0.1, 0.05, 0.09)) }
            return faces
        }, cuts: [], duration: 90, checkedAt: Fixtures.now).found
        XCTAssertEqual(two.mostAtOnce, 2)
        XCTAssertTrue(two.otherPeopleAppear)
        XCTAssertEqual(two.line, "Other people appear, up to 2 at once.")
        XCTAssertEqual(two.shortLine, "Up to 2 at once")
        XCTAssertEqual(one.shortLine, "One at a time")
        XCTAssertEqual(two.summary, "Other people appear: up to 2 people at once, for 41 s in all, first at 0:20.")
        XCTAssertEqual(two.people.map(\.label), ["Unnamed 1", "Unnamed 2"])
        XCTAssertEqual(two.people[1].onScreen, 40)
        XCTAssertEqual(two.glimpses, 1, "a face seen in one sample only is counted, not listed")
        XCTAssertEqual(two.people[0].keyTime, 40, "the key moment is the best capture quality")

        let none = FacesFound.from(samples: samples(0, 10) { _ in [] }, cuts: [], duration: 10, checkedAt: Fixtures.now).found
        XCTAssertEqual(none.line, "No faces seen.")
        XCTAssertEqual(none.summary, "No faces were seen in this recording.")
        var audio = none
        audio.hasPicture = false
        XCTAssertEqual(audio.line, "No picture to look at.")

        // The JSON the store keeps reads back the same.
        XCTAssertEqual(FacesFound.decode(two.json()), two)
        for text in [one.line, one.summary, two.line, two.summary, none.line, none.summary, audio.line, audio.summary, two.stepLine] {
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), text)
        }
    }

    // MARK: Check 7: nothing stored for strangers

    /// Every array of numbers in the people file, at any depth.
    static func numberArrays(_ value: Any) -> [[Any]] {
        if let array = value as? [Any] {
            let numbers = array.allSatisfy { $0 is NSNumber }
            return (numbers && !array.isEmpty ? [array] : []) + array.flatMap(numberArrays)
        }
        if let object = value as? [String: Any] { return object.values.flatMap(numberArrays) }
        return []
    }

    static func strings(_ value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.flatMap(strings) }
        if let object = value as? [String: Any] { return object.keys.map { $0 } + object.values.flatMap(strings) }
        return []
    }

    /// Fails on any list of 128 or more numbers (a face print is 128 to 768), any image, image path or picture key.
    static func assertNoPrintAndNoPicture(_ data: Data, file: StaticString = #filePath, line: UInt = #line) throws {
        let json = try JSONSerialization.jsonObject(with: data)
        for array in numberArrays(json) {
            XCTAssertLessThan(array.count, 128, "a list of \(array.count) numbers is in the people file", file: file, line: line)
        }
        // "hasPicture" says whether the recording has a picture at all (an audio file has none); it holds no picture.
        for text in strings(json) where text != "hasPicture" {
            let lower = text.lowercased()
            for word in ["landmark", "embedding", "print", "image", "thumbnail", "picture", "crop", ".png", ".jpg", ".jpeg", ".heic", "data:"] {
                XCTAssertFalse(lower.contains(word), "\"\(text)\" is in the people file", file: file, line: line)
            }
        }
    }

    func testThePeopleFileKeepsBoxesAndTimesOnly() throws {
        // A long talk: 3,000 samples of one face, so a flat list of boxes would be thousands of numbers.
        let all = samples(0, 1499.5) { t in [face(0.4 + (t.truncatingRemainder(dividingBy: 10)) * 0.001, 0.3, quality: 0.5)] }
        let made = FacesFound.from(samples: all, cuts: [], duration: 1500, checkedAt: Fixtures.now)
        let scan = FaceScan.Result(hasPicture: true, duration: 1500, width: 1920, height: 1080, samples: all, cuts: [])
        let file = PeopleFile(recordingID: UUID(), scan: scan, found: made.found, tracks: made.tracks, rows: made.rows)
        let data = try PeopleFile.encoder.encode(file)
        try Self.assertNoPrintAndNoPicture(data)
        XCTAssertEqual(file.tracks.first?.boxes.count, 3000)
        XCTAssertEqual(file.tracks.first?.boxes.first?.count, 6, "time, x, y, width, height, confidence")
        XCTAssertEqual(file.steps, ["faces"], "the voice step is part M6b: the people check is not complete")
        // The check finds a print when one is there.
        let planted = try JSONSerialization.data(withJSONObject: ["tracks": [["print": (0..<128).map { Double($0) }]]])
        let json = try JSONSerialization.jsonObject(with: planted)
        XCTAssertEqual(Self.numberArrays(json).first?.count, 128)
    }

    func testTheFaceStepUsesAJobFolderAndLeavesNothingElse() async throws {
        let folders = PeopleFolders(support: work.appending(path: "Support", directoryHint: .isDirectory))
        // A crash left two job folders: the launch's cleanup deletes both.
        _ = try folders.newJob()
        let left = try folders.newJob()
        try Data("partial".utf8).write(to: left.appending(path: "x.json"))
        XCTAssertEqual(folders.deleteLeftoverJobs(), 2)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folders.jobs.path), [])

        // The face step on a generated picture with no face in it.
        let clip = work.appending(path: "pattern.mp4")
        let ffmpeg = Process()
        ffmpeg.executableURL = ToolPaths.standard.ffmpeg
        ffmpeg.arguments = ["-hide_banner", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=6",
                            "-c:v", "libx264", "-pix_fmt", "yuv420p", clip.path]
        try ffmpeg.run()
        ffmpeg.waitUntilExit()
        let id = UUID()
        let outcome = try await FaceStep.run(file: clip, recordingID: id, folders: folders, now: Fixtures.now)
        XCTAssertEqual(outcome.found.samples, 12, "two frames a second for 6 s")
        XCTAssertEqual(outcome.found.mostAtOnce, 0)
        XCTAssertEqual(outcome.found.line, "No faces seen.")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folders.jobs.path), [], "the job folder is gone when the step ends")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folders.peopleFile(for: id).path))
        XCTAssertEqual(folders.read(id)?.samples, 12)
        try Self.assertNoPrintAndNoPicture(try Data(contentsOf: folders.peopleFile(for: id)))
        for forbidden in folders.forbidden { XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), forbidden.path) }
        // Every file under the support folder: only the people file, and no image.
        let everything = FileManager.default.enumerator(at: folders.support, includingPropertiesForKeys: [.isRegularFileKey])?
            .compactMap { $0 as? URL }.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true } ?? []
        XCTAssertEqual(everything.map(\.lastPathComponent), [id.uuidString + ".json"])
        folders.removePeopleFile(for: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folders.peopleFile(for: id).path))

        // A file with no picture has nothing to look at.
        let sound = work.appending(path: "tone.m4a")
        let tone = Process()
        tone.executableURL = ToolPaths.standard.ffmpeg
        tone.arguments = ["-hide_banner", "-v", "error", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=3", "-c:a", "aac", sound.path]
        try tone.run()
        tone.waitUntilExit()
        let audio = try await FaceStep.run(file: sound, recordingID: UUID(), folders: folders, now: Fixtures.now)
        XCTAssertFalse(audio.found.hasPicture)
        XCTAssertEqual(audio.found.line, "No picture to look at.")
    }

    // MARK: The step in the pipeline, the runner and the app

    func testThePipelinePlansFacesAfterTheTranscriptOnlyWhenAsked() {
        var options = PipelineOptions()
        XCTAssertFalse(options.plannedSteps.contains(.faces), "the pipeline alone does not look for faces")
        options.people = PeopleSetup(recordingID: UUID(), folders: PeopleFolders(support: work))
        let steps = options.plannedSteps
        XCTAssertEqual(steps, [.complete, .capture, .sound, .speechAudio, .transcript, .coverage, .faces, .voices, .episode, .loudness, .report])
        options.checksOnly = true
        XCTAssertFalse(options.plannedSteps.contains(.faces), "Ask me first checks only that the file is complete and has sound")
        XCTAssertEqual(PipelineStep.faces.title, "Faces")
        XCTAssertEqual(PipelineStep.faces.doing, "Looking for faces")
        XCTAssertTrue(PipelineStep.faces.isMetered, "its progress is how far through the picture it is")
    }

    func testTheRunnerKeepsWhatWasFoundAndNoticesOtherPeopleOnce() throws {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: work), settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        XCTAssertEqual(model.peopleFolders.support, AppPaths(mode: .development, home: work).applicationSupport)
        let recording = Recording(filePath: "/tmp/2026-09-13 two.mp4", recordedAt: Fixtures.date(2026, 9, 13, 18, 25, 44), foundAt: Fixtures.now)
        model.context.insert(recording)
        XCTAssertEqual(model.runner.options(for: recording).people?.recordingID, recording.id, "every make looks for faces")

        model.applyFaces(Fixtures.facesOnePerson(at: Fixtures.now), to: recording)
        XCTAssertEqual(recording.faces?.line, "One person at a time.")
        XCTAssertTrue(model.notifier.sent.isEmpty, "one person at a time: no notice")
        model.applyFaces(Fixtures.facesTwoPeople(at: Fixtures.now), to: recording)
        XCTAssertEqual(model.notifier.sent.map(\.event), [.otherPeople])
        XCTAssertEqual(model.notifier.sent.first?.body, "Other people appear in this recording.")
        model.applyFaces(Fixtures.facesTwoPeople(at: Fixtures.now), to: recording)
        XCTAssertEqual(model.notifier.sent.count, 1, "told once per recording, not at every make")

        // The Filter menu's Other People Appear.
        let other = Recording(filePath: "/tmp/b.mp4", foundAt: Fixtures.now)
        model.context.insert(other)
        XCTAssertEqual(Library.filtered([recording, other], kinds: [], otherPeople: true).map(\.id), [recording.id])
        XCTAssertEqual(Library.filtered([recording, other], kinds: [], otherPeople: false).count, 2)
        // The privacy lock does not move: faces alone are not a people check (docs/v2/PLAN.md M6, review item 5).
        XCTAssertTrue(recording.isPrivacyLocked)
        XCTAssertEqual(recording.lockSubject.people, .notChecked)
    }

    func testRemoveFromLibraryForgetsThePeopleFile() throws {
        let paths = AppPaths(mode: .development, home: work)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: nil), now: { Fixtures.now })
        let recording = Recording(filePath: "/tmp/c.mp4", foundAt: Fixtures.now, status: .readyForYourYes)
        model.context.insert(recording)
        try FileManager.default.createDirectory(at: model.peopleFolders.recordings, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: model.peopleFolders.peopleFile(for: recording.id))
        XCTAssertTrue(model.removeFromLibrary(recording))
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.peopleFolders.peopleFile(for: recording.id).path))
    }
}
