import CoreGraphics
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Recognition (v2 part M7b, docs/v2/PLAN.md M7 check 1, the half M7b runs): the votes on made-up identify answers
/// (named, ask, unnamed), a row shared by two people asked about, the analyzer's boxes read from the bottom left as
/// measured, the frames chosen per track, names from recognition below Ivan's own, "Not [name]", Merge refused without a
/// release for both and, with both, names, choices and sealed crops moved under one key, the calibration report, which
/// crops are learned, and Apple's face index built, read and removed from sealed test-pattern crops (no face of anyone).
/// Every vault test uses its own folder under the temporary folder and the tests' own Keychain service.
@MainActor
final class RecognitionTests: XCTestCase {
    private var home: URL!

    override func setUp() async throws {
        home = FileManager.default.temporaryDirectory.appending(path: "prakriti-recognition-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: home)
    }

    private var folders: PeopleFolders { PeopleFolders(support: home.appending(path: "Support", directoryHint: .isDirectory)) }

    private func model() -> AppModel {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: home),
                             settings: .ephemeral(), log: AppLog(directory: nil), now: { Fixtures.now })
        model.peopleFolders = folders
        XCTAssertEqual(model.vaultKeys, .testing)
        return model
    }

    private let gabriel = UUID(), serenity = UUID()

    // MARK: Votes

    func testVotesGiveNamedAskAndUnnamed() {
        let g = FrameIdentity.person(gabriel), s = FrameIdentity.person(serenity)
        // Named without asking: 3 or more frames, 60% or more the same person, nobody else.
        XCTAssertEqual(Votes.vote([g, g, g, g, .nobody]).outcome, .named)
        XCTAssertEqual(Votes.vote([g, g, g, .nobody, .nobody]).outcome, .named, "exactly 60%")
        XCTAssertEqual(Votes.vote([g, g, g, g, .nobody]).person, gabriel)
        XCTAssertEqual(Votes.vote([g, g, g]), RowVote(outcome: .named, person: gabriel, frames: 3, matched: 3))
        // Ask: too few frames, too small a share, someone else matched, or a group of two people matched.
        XCTAssertEqual(Votes.vote([g, g]).outcome, .ask, "two frames are not enough")
        XCTAssertEqual(Votes.vote([g, g, .nobody, .nobody]).outcome, .ask, "50% is not enough")
        XCTAssertEqual(Votes.vote([g, g, g, g, s]).outcome, .ask, "a frame matched to someone else")
        XCTAssertEqual(Votes.vote([g, g, g, g, s]).person, gabriel, "asked about the one matched most")
        XCTAssertEqual(Votes.vote([g, g, g, g, .conflict]).outcome, .ask, "a group holding two people")
        // A voice named as someone else turns a name into a question; the same voice changes nothing.
        XCTAssertEqual(Votes.vote([g, g, g, g], voice: .person(serenity)).outcome, .ask)
        XCTAssertEqual(Votes.vote([g, g, g, g], voice: .person(gabriel)).outcome, .named)
        // Unnamed: nothing matched.
        XCTAssertEqual(Votes.vote([.nobody, .nobody, .nobody, .nobody]), RowVote(outcome: .unnamed, person: nil, frames: 4, matched: 0))
        XCTAssertEqual(Votes.vote([.conflict, .conflict, .nobody]).outcome, .unnamed, "a group of two people names no one to ask about")
        XCTAssertEqual(Votes.vote([]).outcome, .unnamed)
    }

    func testARowSharedByAStrangerIsAskedAbout() {
        let g = FrameIdentity.person(gabriel)
        // Gabriel in the chair for the first track, someone nobody learned in the same chair after: together 5 of 8 is
        // over 60%, but the second track on its own matches no one, so the row is asked about, never named.
        let row = Votes.row(tracks: [[g, g, g, g, g], [.nobody, .nobody, .nobody]])
        XCTAssertEqual(row.outcome, .ask)
        XCTAssertEqual(row.person, gabriel)
        // A short second track (under 3 frames) does not hold the row back; two tracks of Gabriel name it.
        XCTAssertEqual(Votes.row(tracks: [[g, g, g, g], [.nobody]]).outcome, .named)
        XCTAssertEqual(Votes.row(tracks: [[g, g, g], [g, g, g]]).outcome, .named)
    }

    // MARK: The analyzer's boxes and the frames chosen

    func testTheAnalyzersBoxesAreReadFromTheBottomLeftAsMeasured() {
        // Measured 13 Oct on two-people-mixed.mp4 at 25 s: Vision (top left) main face y 0.2844, height 0.2246; the
        // analyzer gave y 0.4971, height 0.2170 for the same face. Read from the bottom left it lands on Vision's box.
        let analyzer = AnalyzerGeometry.box(fromAnalyzer: CGRect(x: 0.4135, y: 0.4971, width: 0.1221, height: 0.2170))
        let vision = FaceBox(x: 0.4103, y: 0.2844, width: 0.1263, height: 0.2246)
        XCTAssertGreaterThan(FaceGeometry.overlap(analyzer, vision), 0.8)
        // Read as top left (the documentation's word) it would miss the face entirely.
        let wrong = FaceBox(x: 0.4135, y: 0.4971, width: 0.1221, height: 0.2170)
        XCTAssertLessThan(FaceGeometry.overlap(wrong, vision), 0.05)
        // The corner face, the same way.
        let corner = AnalyzerGeometry.box(fromAnalyzer: CGRect(x: 0.7917, y: 0.2065, width: 0.0407, height: 0.0724))
        XCTAssertGreaterThan(FaceGeometry.overlap(corner, FaceBox(x: 0.7913, y: 0.7189, width: 0.0433, height: 0.0771)), 0.7)
    }

    func testFramesAreSpreadAcrossEachTrackAndSmallFacesLeftOut() {
        // A 60 s track (120 sightings), a 1 s track (3 sightings), a face too small to identify, and a glimpse (no row).
        let long = (0..<120).map { [Double($0) * 0.5, 0.4, 0.3, 0.1, 0.2, 0.99] }
        let short = (0..<3).map { [100 + Double($0) * 0.5, 0.8, 0.7, 0.04, 0.07, 0.95] }
        let small = (0..<10).map { [200 + Double($0) * 0.5, 0.1, 0.1, 0.02, 0.03, 0.9] }
        let file = PeopleFile(recordingID: UUID(), duration: 300, frameWidth: 1920, frameHeight: 1080, tracks: [
            .init(id: 1, person: 1, start: 0, end: 59.5, boxes: long),
            .init(id: 2, person: 2, start: 100, end: 101, boxes: short),
            .init(id: 3, person: 3, start: 200, end: 204.5, boxes: small),
            .init(id: 4, person: nil, start: 250, end: 250, boxes: [[250, 0.5, 0.5, 0.1, 0.2, 0.9]]),
        ], people: [])
        let picks = FrameChoice.picks(file)
        let first = picks.filter { $0.track == 1 }.map(\.time)
        XCTAssertEqual(first.first, 0)
        XCTAssertEqual(first.last, 59.5, "the spread reaches the track's end")
        XCTAssertTrue(first.count >= 5 && first.count <= 5 + 6, "5 spread plus one every 10 s: \(first.count)")
        XCTAssertEqual(picks.filter { $0.track == 2 }.count, 3, "a short track gives what it has")
        XCTAssertTrue(picks.filter { $0.track == 3 }.isEmpty, "a face under 5% of the picture's height is too small to identify")
        XCTAssertTrue(picks.filter { $0.track == 4 }.isEmpty, "a glimpse has no row")
        XCTAssertEqual(picks.map(\.time), picks.map(\.time).sorted())
    }

    func testFoundFacesAreGivenToTheRowWhoseBoxTheyCover() {
        let main = FaceBox(x: 0.41, y: 0.28, width: 0.13, height: 0.22)
        let corner = FaceBox(x: 0.79, y: 0.72, width: 0.04, height: 0.08)
        func pick(_ time: Double, row: Int, box: FaceBox) -> FrameChoice.Pick { .init(time: time, row: row, track: row, box: box) }
        let found = [RowVotes.Found(box: main, identity: .person(gabriel)), RowVotes.Found(box: corner, identity: .nobody)]
        let pairs = (0..<4).flatMap { t in [FaceChoicePair(pick: pick(Double(t), row: 1, box: main), found: found),
                                             FaceChoicePair(pick: pick(Double(t), row: 2, box: corner), found: found)] }
            + [FaceChoicePair(pick: pick(9, row: 2, box: corner), found: [])]
        XCTAssertEqual(RowVotes.landed(pairs), 8, "the pick at 9 s found no face")
        let votes = RowVotes.votes(picks: pairs, voices: [:])
        XCTAssertEqual(votes[1]?.outcome, .named)
        XCTAssertEqual(votes[1]?.person, gabriel)
        XCTAssertEqual(votes[2], RowVote(outcome: .unnamed, person: nil, frames: 4, matched: 0))
    }

    // MARK: Names

    func testRecognitionNamesOnlyWhatIvanHasNotAndNotThemHolds() throws {
        let faces = Fixtures.facesTwoPeople(at: Fixtures.now)
        let voices = Fixtures.voicesTwoTracks(at: Fixtures.now)
        var names = PeopleNames()
        names.recognition = [1: RowVote(outcome: .named, person: gabriel, frames: 5, matched: 5),
                             2: RowVote(outcome: .ask, person: serenity, frames: 3, matched: 1)]
        var resolved = names.resolved(faces: faces, voices: voices)
        XCTAssertEqual(resolved.faces[1], gabriel, "named without asking")
        XCTAssertEqual(resolved.voices[1], gabriel, "and the voice linked to it")
        XCTAssertNil(resolved.faces[2], "an ask names nothing")
        XCTAssertEqual(names.asks, [2: serenity])
        // Ivan's own name wins.
        names.faces[1] = serenity
        resolved = names.resolved(faces: faces, voices: voices)
        XCTAssertEqual(resolved.faces[1], serenity)
        names.faces[1] = nil
        // His teacher wins too.
        names.teacher = serenity
        XCTAssertEqual(names.resolved(faces: faces, voices: voices).faces[1], serenity)
        names.teacher = nil
        // "Not Gabriel": no name, and not asked again.
        names.notThem = [1: [gabriel], 2: [serenity]]
        resolved = names.resolved(faces: faces, voices: voices)
        XCTAssertNil(resolved.faces[1])
        XCTAssertTrue(names.asks.isEmpty)
        XCTAssertTrue(names.recognized.isEmpty)
        // Kept and read back; a recording named before M7b reads as it was.
        XCTAssertEqual(PeopleNames.decode(names.json()), names)
        let old = PeopleNames.decode(#"{"faces":{"1":"\#(gabriel.uuidString)"},"voices":{}}"#)
        XCTAssertEqual(old.faces[1], gabriel)
        XCTAssertNil(old.recognition)
        XCTAssertFalse(PeopleNames(recognition: [1: RowVote(outcome: .unnamed, person: nil, frames: 3, matched: 0)]).isEmpty)
        XCTAssertFalse(PeopleNames().json().contains("recognition"), "nothing new is written for a recording without votes")
    }

    func testNotThisPersonTakesTheNameOffAndTheVoiceVoteReadsIvansNames() async throws {
        let model = model()
        let recording = Recording(filePath: "/tmp/2026-09-13 talk.mp4", recordedAt: Fixtures.now, foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.now), to: recording)
        let g = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        model.applyRecognition([1: RowVote(outcome: .named, person: g.id, frames: 5, matched: 5)], to: recording)
        XCTAssertEqual(recording.resolvedNameTable.faces[1], g.id)
        model.rejectMatch(row: 1, person: g.id, in: recording)
        XCTAssertNil(recording.resolvedNameTable.faces[1])
        XCTAssertEqual(recording.names.notThem?[1], [g.id])
        XCTAssertEqual(recording.names.recognition?[1]?.outcome, .named, "the machine's vote is kept, for calibration")
        // The voice vote reads only Ivan's names, never recognition's own.
        var names = recording.names
        names.notThem = nil
        XCTAssertEqual(VoiceVote.perRow(names: names, faces: recording.faces, voices: recording.voices), [:])
        names.voices[1] = g.id
        XCTAssertEqual(VoiceVote.perRow(names: names, faces: recording.faces, voices: recording.voices), [1: .person(g.id)])
        await model.indexSettled()
    }

    // MARK: Merge

    func testMergeIsRefusedUnlessBothHaveARelease() throws {
        XCTAssertEqual(AppModel.mergeProblem(("Gabriel", true), ("Gabe", false)),
                       "Merge needs a recorded release for both people, and Gabe has none. Use Record Release on their page first.")
        XCTAssertEqual(AppModel.mergeProblem(("Gabriel", false), ("Gabe", false)),
                       "Merge needs a recorded release for both people, and neither Gabriel nor Gabe has one.")
        XCTAssertNil(AppModel.mergeProblem(("Gabriel", true), ("Gabe", true)))
        let model = model()
        let a = try XCTUnwrap(model.addPerson(named: "Gabriel")), b = try XCTUnwrap(model.addPerson(named: "Gabe"))
        XCTAssertNotNil(model.merge(b, into: a), "refused")
        XCTAssertEqual(model.namedPeopleList().count, 2, "nothing merged")
        XCTAssertEqual(model.mergeProblem(a, a), "Choose two different people.")
    }

    func testMergeMovesNamesChoicesAndCropsUnderOneKey() async throws {
        let model = model()
        let vault = model.vault
        let a = try XCTUnwrap(model.addPerson(named: "Gabriel")), b = try XCTUnwrap(model.addPerson(named: "Gabe"))
        defer { vault.forget(person: a.id); vault.forget(person: b.id) }
        for person in [a, b] {
            person.releaseSignedOn = Fixtures.date(2026, 10, 12, 10, 0)
            person.releaseKeptAt = "Releases folder"
            person.learnFace = true
        }
        a.mayReadInCloud = true
        b.mayReadInCloud = false
        b.noRelease = true
        // Two test-pattern crops for Gabe, one for Gabriel: no face of anyone.
        let pattern = try XCTUnwrap(JPEG.data(try XCTUnwrap(FaceCrops.testPattern(seed: 1))))
        let recordingID = UUID()
        for (index, person) in [b, b, a].enumerated() {
            let crop = SealedCrop(origin: .init(recording: recordingID, row: 1, time: Double(index)), jpeg: pattern)
            try vault.seal(try crop.encoded(), kind: .face, person: person.id)
        }
        let recording = Recording(filePath: "/tmp/talk.mp4", recordedAt: Fixtures.now, foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        var names = PeopleNames()
        names.teacher = b.id
        names.faces[2] = b.id
        names.recognition = [1: RowVote(outcome: .ask, person: b.id, frames: 3, matched: 1)]
        names.notThem = [3: [b.id, a.id]]
        recording.names = names
        var choices = PeopleChoices()
        choices.set(.hideFace, for: .named(b.id))
        choices.set(.include, for: .named(a.id), output: .podcast)
        recording.choices = choices
        XCTAssertNil(model.merge(b, into: a))
        await model.indexSettled()
        XCTAssertEqual(model.namedPeopleList().map(\.name), ["Gabriel"])
        let merged = recording.names
        XCTAssertEqual(merged.teacher, a.id)
        XCTAssertEqual(merged.faces[2], a.id)
        XCTAssertEqual(merged.recognition?[1]?.person, a.id)
        XCTAssertEqual(merged.notThem?[3], [a.id], "one entry, not two")
        XCTAssertEqual(recording.choices.overall(.named(a.id)).choice, .hideFace, "the stricter choice is kept")
        XCTAssertNil(recording.choices.people[PersonKey.named(b.id).string])
        XCTAssertFalse(a.mayReadInCloud, "the stricter consent")
        XCTAssertTrue(a.noRelease, "no release on either side: no release after the merge (part LOCK)")
        // Gabe's crops opened and sealed again under Gabriel's key; Gabe's key destroyed, nothing of Gabe's left.
        XCTAssertEqual(vault.sealedFiles(person: a.id).count, 3)
        for file in vault.sealedFiles(person: a.id) { XCTAssertNoThrow(try SealedCrop.decode(try vault.open(file, person: a.id))) }
        XCTAssertFalse(vault.holdsAnything(person: b.id))
        // The index was rebuilt from the three crops (test patterns: no face, so no group).
        XCTAssertEqual(model.lastIndexSummary?.crops, 3)
        XCTAssertEqual(model.lastIndexSummary?.faces, 0)
        XCTAssertTrue(model.faceIndex.exists)
    }

    // MARK: The index

    func testTheIndexIsBuiltFromSealedCropsAndRemovedWhenNobodyIsLearned() async throws {
        let model = model()
        let vault = model.vault
        let person = UUID()
        defer { vault.forget(person: person) }
        let index = FaceIndex(vault: vault)
        // Nobody learned: no index, and identifying finds nothing and makes nothing.
        XCTAssertFalse(index.exists)
        let nothing = try await index.rebuild(learning: [])
        XCTAssertEqual(nothing.crops, 0)
        XCTAssertFalse(index.exists)
        for folder in folders.forbidden { XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path), "\(folder.lastPathComponent) made for nobody") }
        // Two sealed test-pattern crops (no face of anyone): an index is made from them.
        let pattern = try XCTUnwrap(JPEG.data(try XCTUnwrap(FaceCrops.testPattern(seed: 2))))
        for time in [1.0, 2.0] {
            try vault.seal(try SealedCrop(origin: .init(recording: UUID(), row: 1, time: time), jpeg: pattern).encoded(), kind: .face, person: person)
        }
        XCTAssertEqual(index.crops(of: [person]).count, 2)
        XCTAssertEqual(Set(index.crops(of: [person]).map(\.asset)).count, 2, "each asset id is its crop's own UUID")
        for crop in index.crops(of: [person]) { XCTAssertNotNil(UUID(uuidString: crop.asset)) }
        let built = try await index.rebuild(learning: [person])
        XCTAssertEqual(built.crops, 2)
        XCTAssertEqual(built.people, 1)
        XCTAssertEqual(built.faces, 0, "a test pattern has no face")
        XCTAssertTrue(index.exists)
        XCTAssertTrue(PrintVault.isExcludedFromBackup(folders.people))
        // Identifying stores nothing: every file under People/ is the same before and after.
        let job = try folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        let picture = job.appending(path: UUID().uuidString + ".jpg")
        try pattern.write(to: picture)
        let before = FaceIndex.listing(folders.people)
        let found = try await index.identify([(picture.deletingPathExtension().lastPathComponent, picture)], learning: [person])
        XCTAssertEqual(FaceIndex.listing(folders.people), before)
        XCTAssertTrue(found.values.allSatisfy(\.isEmpty))
        let matched = try await index.matchesAnyone(pattern, learning: [person])
        XCTAssertFalse(matched)
        // Forgotten: the index goes with the last person.
        vault.forget(person: person)
        let gone = try await index.rebuild(learning: [person])
        XCTAssertEqual(gone.crops, 0)
        XCTAssertFalse(index.exists)
        XCTAssertTrue(folders.forbidden.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }, "Faces, Voices and FaceIndex all gone")
        XCTAssertTrue(((try? FileManager.default.contentsOfDirectory(atPath: folders.jobs.path)) ?? []).filter { $0 != job.lastPathComponent }.isEmpty,
                      "no job folder left by the rebuilds")
    }

    func testRecognitionDoesNothingWhileNobodyIsLearned() async throws {
        let model = model()
        let recording = Recording(filePath: "/tmp/talk.mp4", recordedAt: Fixtures.now, foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        _ = model.addPerson(named: "Gabriel")
        model.recognize(recording)
        await model.indexSettled()
        XCTAssertNil(recording.names.recognition)
        XCTAssertNil(model.indexWork, "nothing was even queued")
        XCTAssertTrue(folders.forbidden.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testForgetRebuildsTheIndexWithoutThePersonAndTriesAnOldCrop() async throws {
        let model = model()
        let g = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        g.releaseSignedOn = Fixtures.date(2026, 10, 12, 10, 0)
        g.releaseKeptAt = "Releases folder"
        g.learnFace = true
        let pattern = try XCTUnwrap(JPEG.data(try XCTUnwrap(FaceCrops.testPattern(seed: 3))))
        try model.vault.seal(try SealedCrop(origin: .init(recording: UUID(), row: 1, time: 1), jpeg: pattern).encoded(), kind: .face, person: g.id)
        model.enqueueIndexWork { _ = await model.rebuildIndexNow(reason: "Test.") }
        await model.indexSettled()
        XCTAssertTrue(model.faceIndex.exists)
        let proof = model.forgetFaceAndVoice(g)
        XCTAssertTrue(proof.holds)
        await model.indexSettled()
        let indexProof = try XCTUnwrap(model.lastForgetIndexProof)
        XCTAssertEqual(indexProof.rebuilt.crops, 0)
        XCTAssertEqual(indexProof.oldCropMatched, false)
        XCTAssertTrue(indexProof.holds)
        XCTAssertFalse(model.faceIndex.exists, "nobody else is learned, so the index is gone")
        XCTAssertTrue(folders.forbidden.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    // MARK: Learning and calibration

    func testLearningSpreadsCropsAndKeepsAtMostFifty() {
        let recordings = (0..<10).map { _ in UUID() }
        var files: [UUID: PeopleFile] = [:]
        for id in recordings {
            files[id] = PeopleFile(recordingID: id, duration: 600, frameWidth: 1920, frameHeight: 1080, tracks: [
                .init(id: 1, person: 1, start: 0, end: 599.5, boxes: (0..<1200).map { [Double($0) * 0.5, 0.4, 0.3, 0.1 + Double($0 % 7) * 0.001, 0.2, 0.95] }),
                .init(id: 2, person: 2, start: 0, end: 10, boxes: (0..<20).map { [Double($0) * 0.5, 0.8, 0.7, 0.05, 0.08, 0.9] }),
            ], people: [])
        }
        let sources = recordings.map { Learning.Source(recording: $0, file: "/tmp/\($0).mp4", row: 1) }
        let picks = Learning.picks(sources: sources, files: files, kept: [])
        XCTAssertEqual(picks.count, Learning.maximum, "8 a recording, 50 in all")
        XCTAssertTrue(Dictionary(grouping: picks, by: \.origin.recording).values.allSatisfy { $0.count <= Learning.perRecording })
        XCTAssertTrue(picks.allSatisfy { $0.origin.row == 1 }, "only the rows named for the person")
        let first = picks.filter { $0.origin.recording == recordings.sorted { $0.uuidString < $1.uuidString }[0] }.map(\.origin.time)
        XCTAssertGreaterThan((first.max() ?? 0) - (first.min() ?? 0), 400, "spread across the recording")
        // What is kept is not cut again, and once 50 are kept nothing more is.
        let kept = Set(picks.prefix(10).map(\.origin))
        XCTAssertTrue(Learning.picks(sources: sources, files: files, kept: kept).allSatisfy { !kept.contains($0.origin) })
        XCTAssertTrue(Learning.picks(sources: sources, files: files, kept: Set(picks.map(\.origin))).isEmpty)
    }

    func testOnlyRowsIvanNamedAreLearnedNeverRecognitionsOwn() throws {
        let model = model()
        let recording = Recording(filePath: "/tmp/talk.mp4", recordedAt: Fixtures.now, foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.now), to: recording)
        var names = PeopleNames()
        names.faces[1] = gabriel
        names.recognition = [2: RowVote(outcome: .named, person: gabriel, frames: 5, matched: 5)]
        recording.names = names
        XCTAssertEqual(recording.resolvedNameTable.faces[2], gabriel, "recognition names the corner face")
        let sources = AppModel.learningSources(of: gabriel, in: [recording])
        XCTAssertEqual(sources.map(\.row), [1], "but only the row Ivan named is learned")
        XCTAssertEqual(AppModel.learningSources(of: gabriel, in: [recording], only: (recording.id, 2)).count, 0)
        XCTAssertEqual(AppModel.learningSources(of: gabriel, in: [recording], only: (recording.id, 1)).count, 1)
        // Who is teaching counts as Ivan's naming: the main voice's linked face.
        names.faces = [:]
        names.teacher = gabriel
        recording.names = names
        XCTAssertEqual(AppModel.learningSources(of: gabriel, in: [recording]).map(\.row), [1])
    }

    func testTheCalibrationReportCountsAgainstIvansAnswers() {
        let a = UUID(), b = UUID(), stranger = UUID()
        func vote(_ outcome: RowVote.Outcome, _ person: UUID?) -> RowVote { RowVote(outcome: outcome, person: person, frames: 5, matched: 4) }
        let rows: [(vote: RowVote, named: UUID?, notThem: [UUID])] = [
            (vote(.named, a), a, []),            // right
            (vote(.named, a), a, []),            // right
            (vote(.named, a), b, []),            // the wrong person with a release
            (vote(.named, a), nil, [a]),         // a stranger taken for a
            (vote(.named, b), stranger, []),     // named someone without a release: a stranger too
            (vote(.ask, b), b, []),              // asked
            (vote(.unnamed, nil), a, []),        // missed
            (vote(.unnamed, nil), nil, []),      // no answer: not counted
            (vote(.named, a), nil, []),          // no answer: not counted
        ]
        let report = Calibration.report(rows, released: [a, b])
        XCTAssertEqual(report, Calibration.Report(labeled: 7, recognized: 2, mistaken: 1, strangerTaken: 2, asked: 1, missed: 1))
        XCTAssertEqual(report.lines[3], "A stranger taken for a named person: 2 of 7 (28.6%) (must stay under 1 in 1,000)")
        XCTAssertTrue(Calibration.report([], released: []).lines[0].hasPrefix("SKIPPED"))
    }
}
