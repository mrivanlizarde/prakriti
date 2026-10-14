import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M7b's acceptance (docs/v2/PLAN.md M7 check 3 and what of it runs without a release), on a real fixture through
/// the app's own runner, in development:
///
/// - **Check 3 itself** needs `~/Prakriti/Dev/Fixtures/ivan-clip.mov` (Ivan's own 2-minute clip) and his release: without
///   both it is written down as SKIPPED, blocked on Ivan, never failed (PLAN section 11, D2).
/// - **two-people-mixed.mp4** made with its people check; with nobody learned, recognition does nothing: no face index,
///   no vote, nothing under `People/` changed.
/// - **The identify pass, measured.** In a folder of its own under the temporary folder: an index built from one sealed
///   test-pattern crop of a made-up person (no face of anyone), then the fixture's frames chosen, taken into a job folder,
///   identified by Apple's `FaceGroupAnalyzer` and read into votes. Measured: frames, faces found, how many chosen boxes had
///   a found face on them (the analyzer's boxes against the people file's, which proves the bottom-left reading), every
///   row unnamed, the SHA-256 list of every file under that `People/` identical before and after (nothing stored about a
///   stranger), and the job folder gone. Then Forget's index half: the index removed with the last person.
///
///   cd ~/Code/prakriti/mac && make accept-gallery MILESTONE=v2-m7b
///
/// Skipped unless PRAKRITI_ACCEPTANCE=gallery. Frames of the fixture are measured, never looked at (D1, this run's
/// instructions); they live only in a job folder deleted when the pass ends.
@MainActor
final class RecognitionAcceptanceTests: XCTestCase {
    func testRecognitionWithoutARelease() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "gallery" else {
            throw XCTSkip("Makes the two-people-mixed fixture. Run it with: cd ~/Code/prakriti/mac && make accept-gallery MILESTONE=v2-m7b")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.faceCrops.useTestPattern = true
        model.cardPictures.useTestPattern = true
        model.keyPhotos.useTestPattern = true
        model.log.write("Acceptance test for v2 part M7b (recognition) started.")
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var report = ["v2 part M7b acceptance (recognition, no release recorded), \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        // Check 3 needs Ivan's clip and his release.
        let clip = home.appending(path: "Prakriti/Dev/Fixtures/ivan-clip.mov")
        let hasClip = FileManager.default.fileExists(atPath: clip.path)
        report.append("PLAN M7 check 3 (enroll Ivan from his clip, recognize him in ivan-plus-13sep.mov, Forget him): "
                      + (hasClip ? "ivan-clip.mov is there, but no release is recorded for it in this run: SKIPPED, blocked on Ivan"
                                 : "SKIPPED, blocked on Ivan: ~/Prakriti/Dev/Fixtures/ivan-clip.mov does not exist and no release is recorded"))

        let mixed = home.appending(path: "Prakriti/Dev/Fixtures/two-people-mixed.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mixed.path), "cd ~/Code/prakriti/mac && make fixtures")
        let before = fingerprint(mixed)
        let folder = paths.outputs.appending(path: "two-people-mixed", directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: folder)
        let recording = Recording(filePath: mixed.path, recordedAt: Date(), foundAt: Date())
        model.context.insert(recording)
        try model.context.save()
        let developmentPeople = FaceIndex.listing(model.peopleFolders.people)
        await model.runner.process(recording, trigger: .byHand)
        await model.cardPicturesSettled()
        await model.indexSettled()
        let faces = try XCTUnwrap(recording.faces)
        let voices = try XCTUnwrap(recording.voices)
        report.append("two-people-mixed made: \(faces.people.count) face rows, \(voices.voices.count) voices.")

        // Nobody learned: recognition does nothing.
        XCTAssertTrue(model.learningPeople().isEmpty)
        XCTAssertNil(recording.names.recognition, "no vote while nobody is learned")
        XCTAssertFalse(model.faceIndex.exists)
        let developmentAfter = FaceIndex.listing(model.peopleFolders.people)
        let changed = Set(developmentAfter).symmetricDifference(developmentPeople).filter { !$0.contains("/People/Recordings/") }
        XCTAssertTrue(changed.isEmpty, "only people files change under the development People folder: \(changed)")
        report.append("With nobody learned: votes \(recording.names.recognition == nil ? "none" : "SOME"), face index \(model.faceIndex.exists ? "MADE" : "absent"), "
                      + "files under the development People/ other than people files changed: \(changed.count)")
        for forbidden in model.peopleFolders.forbidden {
            XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), "\(forbidden.path) exists")
        }

        // The identify pass, measured, in a folder of its own.
        let scratch = FileManager.default.temporaryDirectory.appending(path: "prakriti-m7b-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let folders = PeopleFolders(support: scratch)
        try FileManager.default.createDirectory(at: folders.recordings, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: model.peopleFolders.peopleFile(for: recording.id), to: folders.peopleFile(for: recording.id))
        let vault = PrintVault(folders: folders, keys: .testing)
        let index = FaceIndex(vault: vault)
        let madeUp = UUID()
        defer { vault.forget(person: madeUp) }
        let pattern = try XCTUnwrap(JPEG.data(try XCTUnwrap(FaceCrops.testPattern(seed: 7))))
        try vault.seal(try SealedCrop(origin: .init(recording: UUID(), row: 1, time: 0), jpeg: pattern).encoded(), kind: .face, person: madeUp)
        let built = try await index.rebuild(learning: [madeUp])
        report.append("Scratch index from one sealed test-pattern crop of a made-up person: " + built.line)
        let peopleBefore = FaceIndex.listing(folders.people)
        let voiceVotes = VoiceVote.perRow(names: recording.resolvedNames, faces: faces, voices: voices)
        let ran = try await RecognitionStep.run(file: mixed, recordingID: recording.id, index: index, learning: [madeUp], voices: voiceVotes)
        let outcome = try XCTUnwrap(ran)
        let peopleAfter = FaceIndex.listing(folders.people)
        XCTAssertEqual(peopleAfter, peopleBefore, "identifying stored something")
        XCTAssertGreaterThan(outcome.frames, 0)
        XCTAssertGreaterThanOrEqual(Double(outcome.landed), 0.9 * Double(outcome.picks), "the analyzer's boxes do not land on the people file's")
        XCTAssertTrue(outcome.votes.values.allSatisfy { $0.outcome == .unnamed }, "nobody with a face is learned, so every row is unnamed")
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: folders.jobs.path)) ?? []
        XCTAssertTrue(jobs.isEmpty, "the job folder was left: \(jobs)")
        report.append(String(format: "Identify pass on two-people-mixed: %d frames chosen from %d picks, %d faces found by the analyzer, %d of %d picks (%.1f%%) had a found face on their box, in %.1f s.",
                             outcome.frames, outcome.picks, outcome.faces, outcome.landed, outcome.picks,
                             outcome.picks > 0 ? Double(outcome.landed) / Double(outcome.picks) * 100 : 0, outcome.seconds))
        report.append("Votes: " + outcome.votes.keys.sorted().map { "row \($0) \(outcome.votes[$0]!.outcome.rawValue) (\(outcome.votes[$0]!.frames) frames)" }.joined(separator: ", "))
        report.append("SHA-256 list of every file under the scratch People/ before and after (\(peopleBefore.count) files): \(peopleAfter == peopleBefore ? "identical" : "CHANGED")")
        report.append("Scratch Jobs/ after the pass: \(jobs.isEmpty ? "empty" : jobs.joined(separator: ", "))")

        // Forget's index half: the last person gone, the index removed; the old crop tried.
        let proof = vault.forget(person: madeUp)
        let rebuilt = try await index.rebuild(learning: [])
        let tried = try await index.matchesAnyone(pattern, learning: [])
        XCTAssertTrue(proof.holds)
        XCTAssertFalse(index.exists)
        XCTAssertFalse(tried)
        report.append("Forget of the made-up person: \(proof.line) " + rebuilt.line + " Old crop matches anyone: \(tried ? "YES" : "no").")

        // The development folders: nothing for strangers, no job folder; the fixture only read.
        let developmentJobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        XCTAssertTrue(developmentJobs.isEmpty)
        report.append("Development Faces, Voices, FaceIndex: " + model.peopleFolders.forbidden.map { "\($0.lastPathComponent) \(FileManager.default.fileExists(atPath: $0.path) ? "EXISTS" : "absent")" }.joined(separator: ", ")
                      + "; development Jobs/ \(developmentJobs.isEmpty ? "empty" : developmentJobs.joined(separator: ", "))")
        XCTAssertEqual(fingerprint(mixed), before)
        report.append("Fixture unchanged (size and modification date): \(fingerprint(mixed) == before ? "yes" : "NO")")
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-recognition.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M7b finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}

/// `make calibrate-people` (docs/v2/PLAN.md M7, research-people.md 6.1): every face row recognition voted on in a copy of
/// the development store, counted against Ivan's answers (a name he gave, a Yes or a Not in Review). With no release
/// recorded there is nothing to count, and it says SKIPPED. It reads only the copy the make target takes.
@MainActor
final class CalibrationAcceptanceTests: XCTestCase {
    func testCalibrate() throws {
        guard let path = ProcessInfo.processInfo.environment["PRAKRITI_CALIBRATE_STORE"], !path.isEmpty else {
            throw XCTSkip("Run it with: cd ~/Code/prakriti/mac && make calibrate-people")
        }
        let container = try PrakritiStore.makeContainer(at: URL(fileURLWithPath: path))
        let context = ModelContext(container)
        let people = try context.fetch(FetchDescriptor<Person>())
        let released = Set(people.filter(\.hasRelease).map(\.id))
        var rows: [(vote: RowVote, named: UUID?, notThem: [UUID])] = []
        for recording in try context.fetch(FetchDescriptor<Recording>()) {
            let names = recording.names
            for (row, vote) in names.recognition ?? [:] {
                rows.append((vote, names.faces[row], names.notThem?[row] ?? []))
            }
        }
        let report = Calibration.report(rows, released: released)
        var lines = ["make calibrate-people, \(Date().formatted(date: .abbreviated, time: .standard)), on a copy of the development store",
                     "People with a release on file: \(released.count). Face rows with a vote: \(rows.count).",
                     "Thresholds: named without asking at \(Votes.minimumFrames) or more frames, \(Int(Votes.minimumShare * 100))% or more the same person, none matched to anyone else.",
                     ""]
        lines += report.lines
        let text = lines.joined(separator: "\n") + "\n"
        let folder = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try text.write(to: folder.appending(path: "calibrate-people.txt"), atomically: true, encoding: .utf8)
        print(text)
        if let rate = report.strangerRate, report.labeled >= 1000 {
            XCTAssertLessThan(rate, 0.001, "a stranger is taken for a named person in 1 in 1,000 tracks or more: raise the thresholds")
        }
    }
}
