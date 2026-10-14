import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The People gallery (v2 part M7a, docs/v2/PLAN.md M7 check 1, the half M7a runs): the sealed vault (seal and open
/// round trip; a destroyed key makes every sealed file fail; Forget's proof), Name Only storing nothing under
/// `People/Faces` or `Voices`, the release recorded with the name and nothing learned, the People folder out of Time
/// Machine, the gallery's order, where a person appears and for how long, the key photo, the unnamed tile, and
/// retention. Nothing here reads a recording or a face: every vault test seals made-up bytes, in a folder of its own
/// under the temporary folder, with the tests' own Keychain service (`VaultKeys.testing`).
@MainActor
final class GalleryTests: XCTestCase {
    private var home: URL!

    override func setUp() async throws {
        home = FileManager.default.temporaryDirectory.appending(path: "prakriti-gallery-\(UUID().uuidString)", directoryHint: .isDirectory)
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
        XCTAssertEqual(model.vaultKeys, .testing, "tests never touch the live or development keys")
        return model
    }

    /// The two-people-tracks shape: the main face with Voice 1 on track 2, a corner face and Voice 2 nobody named.
    private func twoPeopleRecording(_ model: AppModel, day: Date = Fixtures.now, file: String = "/tmp/2026-09-13 talk.mp4") -> Recording {
        let recording = Recording(filePath: file, recordedAt: day, foundAt: day, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        recording.facesJSON = Fixtures.facesTwoPeople(at: day).json()
        model.applyVoices(Fixtures.voicesTwoTracks(at: day), to: recording)
        return recording
    }

    private func files(under folder: URL) -> [String] {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.map(\.path)
    }

    // MARK: The vault

    func testSealAndOpenRoundTripUnderThePersonsOwnKey() throws {
        let vault = PrintVault(folders: folders, keys: .testing)
        let gabriel = UUID(), serenity = UUID()
        defer { vault.forget(person: gabriel); vault.forget(person: serenity) }
        let crop = Data((0..<4096).map { UInt8($0 % 251) })
        let print = Data((0..<1024).map { UInt8(($0 * 7) % 256) })
        let sealedCrop = try vault.seal(crop, kind: .face, person: gabriel)
        let sealedPrint = try vault.seal(print, kind: .voice, person: gabriel)
        XCTAssertEqual(try vault.open(sealedCrop, person: gabriel), crop)
        XCTAssertEqual(try vault.open(sealedPrint, person: gabriel), print)
        // On disk it is not the data: a sealed box (12-byte nonce, the data, a 16-byte tag), named by a UUID only.
        let onDisk = try Data(contentsOf: sealedCrop)
        XCTAssertEqual(onDisk.count, crop.count + 28)
        XCTAssertNil(onDisk.range(of: crop.prefix(64)), "the crop is not readable in the file")
        XCTAssertNotNil(UUID(uuidString: sealedCrop.deletingPathExtension().lastPathComponent))
        XCTAssertTrue(sealedCrop.path.contains("/People/Faces/\(gabriel.uuidString)/"))
        XCTAssertTrue(sealedPrint.path.contains("/People/Voices/\(gabriel.uuidString)/"))
        // Another person's key does not open it.
        _ = try vault.seal(Data([1, 2, 3]), kind: .face, person: serenity)
        XCTAssertThrowsError(try vault.open(sealedCrop, person: serenity))
        XCTAssertEqual(vault.sealedFiles(person: gabriel).count, 2)
        XCTAssertTrue(PrintVault.isExcludedFromBackup(folders.people), "sealing prepares the People folder, out of Time Machine")
    }

    func testADestroyedKeyMakesEverySealedFileFail() throws {
        let vault = PrintVault(folders: folders, keys: .testing)
        let person = UUID()
        defer { vault.forget(person: person) }
        let sealed = try (0..<3).map { try vault.seal(Data("face \($0)".utf8), kind: .face, person: person) }
            + (0..<2).map { try vault.seal(Data("voice \($0)".utf8), kind: .voice, person: person) }
        for file in sealed { XCTAssertNoThrow(try vault.open(file, person: person)) }
        XCTAssertTrue(VaultKeys.testing.destroy(person))
        XCTAssertNil(VaultKeys.testing.key(for: person))
        for file in sealed {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "the file is still there")
            XCTAssertThrowsError(try vault.open(file, person: person), "a sealed file opens without its key")
        }
        // A new key made later is not the old one: the old files stay closed.
        _ = try VaultKeys.testing.keyMakingIfNeeded(for: person)
        for file in sealed { XCTAssertThrowsError(try vault.open(file, person: person)) }
    }

    func testForgetDestroysTheKeyProvesEveryFileFailsAndLeavesNothing() throws {
        let vault = PrintVault(folders: folders, keys: .testing)
        let person = UUID(), other = UUID()
        defer { vault.forget(person: other) }
        for index in 0..<4 { try vault.seal(Data("crop \(index)".utf8), kind: index < 3 ? .face : .voice, person: person) }
        let kept = try vault.seal(Data("someone else".utf8), kind: .face, person: other)
        let proof = vault.forget(person: person)
        XCTAssertEqual(proof, PrintVault.ForgetProof(sealedFiles: 4, failedToOpen: 4, keyGone: true, filesLeft: 0))
        XCTAssertTrue(proof.holds)
        XCTAssertFalse(vault.holdsAnything(person: person))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.folder(.face, person: person).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.folder(.voice).path), "Voices removed once nobody is left in it")
        XCTAssertEqual(try vault.open(kept, person: other), Data("someone else".utf8), "another person's prints are untouched")
        XCTAssertTrue(proof.line.contains("4 sealed files were kept; the key is destroyed, 4 of 4 failed to open after it, and 0 files are left."), proof.line)
        // Forget with nothing kept is still a clean proof; once the last person is forgotten, Faces goes too.
        XCTAssertEqual(vault.forget(person: UUID()), PrintVault.ForgetProof(sealedFiles: 0, failedToOpen: 0, keyGone: true, filesLeft: 0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.folder(.face).path), "Faces stays while someone is in it")
        XCTAssertTrue(vault.forget(person: other).holds)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.folder(.face).path), "Faces removed once nobody is left in it")
    }

    func testThePeopleFolderIsLeftOutOfTimeMachine() throws {
        let vault = PrintVault(folders: folders, keys: .testing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folders.people.path))
        XCTAssertTrue(vault.prepare())
        XCTAssertTrue(PrintVault.isExcludedFromBackup(folders.people))
        // What tmutil reads: the backup exclusion attribute on the folder itself.
        let output = Pipe()
        let tmutil = Process()
        tmutil.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        tmutil.arguments = ["isexcluded", folders.people.path]
        tmutil.standardOutput = output
        try tmutil.run()
        tmutil.waitUntilExit()
        let said = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertTrue(said.contains("[Excluded]"), "tmutil said: \(said)")
        XCTAssertTrue(files(under: folders.people).isEmpty, "preparing makes no file")
    }

    func testEachModeAndTheTestsHaveTheirOwnKeychainService() {
        XCTAssertEqual(VaultKeys.live.service, "studio.therowan.prakriti.app.people")
        XCTAssertEqual(VaultKeys.forMode(.live, testing: false), .live)
        XCTAssertEqual(VaultKeys.forMode(.development, testing: false), .development)
        XCTAssertEqual(VaultKeys.forMode(.live, testing: true), .testing)
        XCTAssertEqual(Set([VaultKeys.live, .development, .testing].map(\.service)).count, 3)
    }

    // MARK: Naming

    func testNameThisPersonDefaultsToNameOnlyAndStoresNothingAboutAFaceOrAVoice() throws {
        let model = model()
        let recording = twoPeopleRecording(model)
        model.askToName(.face(2), in: recording)
        var request = try XCTUnwrap(model.nameSheet)
        XCTAssertEqual(request.draft.defaultAction, .nameOnly, "Name This Person defaults to Name Only")
        XCTAssertFalse(request.draft.recordRelease)
        XCTAssertTrue(request.draft.mayAppear)
        // Return with only a name: Name Only.
        request.draft.name = "  Asha "
        XCTAssertEqual(request.draft.defaultAction, .nameOnly)
        XCTAssertNil(model.finishNaming(request, as: request.draft.defaultAction))
        let asha = try XCTUnwrap(model.namedPeopleList().first { $0.name == "Asha" })
        XCTAssertFalse(asha.hasRelease)
        XCTAssertNil(asha.releaseSignedOn)
        XCTAssertFalse(asha.learnFace || asha.learnVoice)
        XCTAssertFalse(asha.pinned, "Name Only is not pinned by itself")
        XCTAssertEqual(recording.names.faces[2], asha.id, "the corner face is named Asha in this recording")
        // Nothing under Faces, Voices or FaceIndex, and no key.
        for folder in folders.forbidden { XCTAssertTrue(files(under: folder).isEmpty, "\(folder.lastPathComponent) holds files after Name Only") }
        XCTAssertFalse(model.vault.holdsAnything(person: asha.id))
        XCTAssertEqual(Gallery.statusLine(asha), "Recognition off. Named by you in each recording.")
        // A name already in People joins that person instead of making a second.
        var again = NameSheetRequest(recordingID: recording.id, target: .voice(2))
        again.draft.name = "asha"
        XCTAssertNil(model.finishNaming(again, as: .nameOnly))
        XCTAssertEqual(model.namedPeopleList().filter { $0.name.lowercased() == "asha" }.count, 1)
        XCTAssertEqual(recording.names.voices[2], asha.id)
        // An empty name is refused.
        XCTAssertEqual(model.finishNaming(NameSheetRequest(recordingID: recording.id, target: .face(1)), as: .nameOnly), "Type a name.")
    }

    func testARecordedReleaseIsKeptWithTheNameAndNothingIsLearnedWithoutAPicture() throws {
        let model = model()
        let recording = twoPeopleRecording(model)
        var request = NameSheetRequest(recordingID: recording.id, target: .face(1))
        request.draft.name = "Gabriel"
        request.draft.role = .teacher
        request.draft.recordRelease = true
        XCTAssertEqual(request.draft.defaultAction, .nameOnly, "without where it is kept, Return is still Name Only")
        XCTAssertEqual(request.draft.releaseProblem, "Say where the signed release is kept.")
        XCTAssertEqual(model.finishNaming(request, as: .recordRelease), "Say where the signed release is kept.")
        XCTAssertTrue(model.namedPeopleList().isEmpty, "nothing named when the release is refused")
        request.draft.releaseKeptAt = "Releases folder, studio drive"
        request.draft.learnFace = false
        request.draft.learnVoice = false
        XCTAssertEqual(request.draft.releaseProblem, "A release covers a face, a voice or both: turn one on.")
        request.draft.learnFace = true
        request.draft.releaseSignedOn = Fixtures.date(2026, 10, 12, 10, 0)
        XCTAssertEqual(request.draft.defaultAction, .recordRelease)
        XCTAssertNil(model.finishNaming(request, as: .recordRelease))
        let gabriel = try XCTUnwrap(model.namedPeopleList().first)
        XCTAssertTrue(gabriel.hasRelease)
        XCTAssertEqual(gabriel.role, .teacher)
        XCTAssertEqual(gabriel.noticeVersion, NameThisPersonDraft.noticeVersion)
        XCTAssertEqual(gabriel.releaseRecordedAt, Fixtures.now)
        XCTAssertTrue(gabriel.learnFace)
        XCTAssertFalse(gabriel.learnVoice)
        XCTAssertTrue(gabriel.pinned, "a person with a release is pinned to the sidebar")
        XCTAssertEqual(Gallery.statusLine(gabriel),
                       "Written release signed on Mon 12 Oct 2026, kept in Releases folder, studio drive. Recognition is on: name them in a recording and Prakriti learns their face from it.")
        for folder in folders.forbidden { XCTAssertTrue(files(under: folder).isEmpty, "a release learns nothing: \(folder.lastPathComponent) is empty") }
        XCTAssertFalse(model.vault.holdsAnything(person: gabriel.id), "no key is made until something is sealed")
        // Forget withdraws it: recognition off, the record of the release kept, nothing in the vault.
        let proof = model.forgetFaceAndVoice(gabriel)
        XCTAssertTrue(proof.holds)
        XCTAssertFalse(gabriel.hasRelease)
        XCTAssertNotNil(gabriel.releaseSignedOn)
        XCTAssertEqual(gabriel.forgottenAt, Fixtures.now)
        XCTAssertFalse(gabriel.pinned)
        XCTAssertEqual(recording.names.faces[1], gabriel.id, "the name stays on recordings already checked")
    }

    func testRemovingANameForgetsWhatTheVaultKeepsFirst() throws {
        let model = model()
        let person = try XCTUnwrap(model.addPerson(named: "Ivan"))
        let id = person.id
        try model.vault.seal(Data("made-up crop".utf8), kind: .face, person: id)
        XCTAssertTrue(model.vault.holdsAnything(person: id))
        model.removePerson(person)
        XCTAssertFalse(model.vault.holdsAnything(person: id))
        XCTAssertNil(VaultKeys.testing.key(for: id))
        XCTAssertTrue(files(under: folders.people).isEmpty)
    }

    func testRenameChangesOnlyTheLabelAndRefusesATakenName() throws {
        let model = model()
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        _ = model.addPerson(named: "Serenity")
        let recording = twoPeopleRecording(model)
        model.setTeacher(gabriel, for: recording)
        XCTAssertNotNil(model.rename(gabriel, to: "serenity"))
        XCTAssertEqual(model.rename(gabriel, to: " "), "Type a name.")
        XCTAssertNil(model.rename(gabriel, to: "Gabriel Galindo"))
        XCTAssertEqual(gabriel.name, "Gabriel Galindo")
        XCTAssertEqual(recording.names.teacher, gabriel.id)
        XCTAssertTrue(PeopleWords.line(faces: recording.faces, voices: recording.voices, names: recording.resolvedNames,
                                       people: recording.namedPeople)?.hasPrefix("Gabriel Galindo.") == true)
    }

    // MARK: The gallery

    func testEveryNamedPersonIsInTheGalleryFavoritesFirstByNameOrCustomOrder() throws {
        func entry(_ name: String, favorite: Bool = false, hidden: Bool = false, order: Int = 0) -> GalleryEntry {
            GalleryEntry(id: UUID(), name: name, favorite: favorite, hidden: hidden, pinned: false, customOrder: order, mayAppear: true,
                         hasRelease: false, appearances: [])
        }
        let entries = [entry("Serenity", order: 0), entry("asha", order: 2), entry("Gabriel", favorite: true, order: 3), entry("Ben", hidden: true, order: 1)]
        XCTAssertEqual(Gallery.ordered(entries, sort: .name).map(\.name), ["Gabriel", "asha", "Serenity"])
        XCTAssertEqual(Gallery.ordered(entries, sort: .custom).map(\.name), ["Gabriel", "Serenity", "asha"])
        XCTAssertEqual(Gallery.ordered(entries, sort: .name, showHidden: true).map(\.name), ["Gabriel", "asha", "Ben", "Serenity"])
        let ids = entries.map(\.id)
        XCTAssertEqual(Gallery.move(ids[2], before: ids[0], in: ids), [ids[2], ids[0], ids[1], ids[3]])
        XCTAssertEqual(Gallery.move(ids[0], before: ids[3], in: ids), [ids[1], ids[2], ids[0], ids[3]])
        XCTAssertEqual(Gallery.move(ids[0], before: ids[0], in: ids), ids)
        // Through the model: a drop puts the person in that place and switches to Custom Order.
        let model = model()
        let a = try XCTUnwrap(model.addPerson(named: "Asha")), b = try XCTUnwrap(model.addPerson(named: "Ben")), c = try XCTUnwrap(model.addPerson(named: "Cara"))
        model.moveInGallery(c.id, before: a.id)
        XCTAssertEqual(model.gallerySort, .custom)
        XCTAssertEqual(Gallery.ordered(model.galleryEntries(), sort: .custom).map(\.name), ["Cara", "Asha", "Ben"])
        model.setHidden(true, for: b)
        XCTAssertEqual(Gallery.ordered(model.galleryEntries(), sort: .custom).map(\.name), ["Cara", "Asha"])
        // Name Only people are in it from the day they are named, with no recording yet.
        XCTAssertEqual(model.galleryEntries().first { $0.name == "Asha" }?.tileLine, "Not in a recording yet")
        XCTAssertEqual(Gallery.monogram("Gabriel Galindo"), "GG")
        XCTAssertEqual(Gallery.monogram("serenity"), "S")
        XCTAssertEqual(Gallery.monogram("  "), "?")
    }

    func testWhereAPersonAppearsAndForHowLongComesFromIvansNaming() throws {
        let model = model()
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        let talk13 = twoPeopleRecording(model, day: Fixtures.date(2026, 9, 13, 18, 25), file: "/tmp/13.mp4")
        let talk6 = twoPeopleRecording(model, day: Fixtures.date(2026, 9, 6, 18, 6), file: "/tmp/6.mp4")
        let other = twoPeopleRecording(model, day: Fixtures.date(2026, 9, 20, 9, 0), file: "/tmp/20.mp4")
        model.setTeacher(gabriel, for: talk13)
        model.setTeacher(gabriel, for: talk6)
        let recordings = [talk13, talk6, other]
        let appearances = Gallery.appearances(of: gabriel.id, in: recordings)
        XCTAssertEqual(appearances.map(\.recordingID), [talk13.id, talk6.id], "newest first, only where named")
        XCTAssertEqual(appearances[0].onScreen, 90.1, accuracy: 0.001)
        XCTAssertEqual(appearances[0].speaking, 78.4, accuracy: 0.001)
        XCTAssertEqual(appearances[0].speakingPercent, 96)
        let entry = Gallery.entry(gabriel, in: recordings)
        XCTAssertEqual(entry.recordings, 2)
        XCTAssertEqual(entry.tileLine, "In 2 recordings")
        XCTAssertEqual(entry.lastAppeared, Fixtures.date(2026, 9, 13, 18, 25))
        XCTAssertEqual(Gallery.figures(entry).map(\.value), ["2", "3 min", "3 min"])
        XCTAssertEqual(Library.members(of: .person(gabriel.id), in: recordings).count, 2)
        // The key photo: the face on screen the longest, or Ivan's choice while it is still one of theirs.
        let automatic = try XCTUnwrap(Gallery.keyFace(choice: nil, appearances: appearances))
        XCTAssertEqual(automatic.face.id, 1)
        let chosen = try XCTUnwrap(Gallery.keyFace(choice: KeyPhotoChoice(recording: talk6.id, row: 1), appearances: appearances))
        XCTAssertEqual(chosen.appearance.recordingID, talk6.id)
        XCTAssertEqual(Gallery.keyFace(choice: KeyPhotoChoice(recording: talk6.id, row: 2), appearances: appearances)?.face.id, 1,
                       "a row that is not theirs falls back to automatic")
        XCTAssertNil(Gallery.keyFace(choice: nil, appearances: []))
        model.setKeyPhoto(KeyPhotoChoice(recording: talk6.id, row: 1), for: gabriel)
        XCTAssertEqual(gabriel.keyPhoto, KeyPhotoChoice(recording: talk6.id, row: 1))
        // The unnamed tile: every recording with a face or voice nobody named; naming them takes it off.
        XCTAssertEqual(Set(Gallery.unnamedRecordings(recordings).map(\.id)), Set(recordings.map(\.id)))
        let asha = try XCTUnwrap(model.addPerson(named: "Asha"))
        model.nameFace(2, as: asha, in: talk13)
        model.nameVoice(2, as: asha, in: talk13)
        XCTAssertFalse(Gallery.hasUnnamed(talk13))
        XCTAssertEqual(Library.members(of: .unnamed, in: recordings).map(\.id).sorted { $0.uuidString < $1.uuidString },
                       [talk6.id, other.id].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(Gallery.appearances(of: asha.id, in: recordings).first?.onScreen ?? 0, 40, accuracy: 0.001)
    }

    func testTheSidebarSelectionOfPeopleIsRestoredAtTheNextLaunch() throws {
        let model = model()
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        model.selection = .person(gabriel.id)
        let saved = model.settings.windowState
        XCTAssertTrue(saved?.contains(gabriel.id.uuidString) == true)
        model.selection = .group(.all)
        model.settings.windowState = saved
        model.restoreWindowState()
        XCTAssertEqual(model.selection, .person(gabriel.id))
        model.selection = .people
        let savedPeople = model.settings.windowState
        model.selection = .group(.all)
        model.settings.windowState = savedPeople
        model.restoreWindowState()
        XCTAssertEqual(model.selection, .people)
        model.setHidden(true, for: gabriel)
        model.selection = .person(gabriel.id)
        model.setHidden(true, for: gabriel)
        XCTAssertEqual(model.selection, .people, "hiding the open person goes back to People")
        XCTAssertEqual(HelpPlace(path: "people"), .people)
        XCTAssertEqual(HelpPlace(destination: "prakriti://show/people"), .people)
    }

    // MARK: Retention

    func testPrintsAreDeletedTwelveMonthsAfterThePersonLastAppearedWithALineThirtyDaysBefore() throws {
        let calendar = Calendar(identifier: .gregorian)
        let last = Fixtures.date(2026, 9, 13, 18, 25)
        XCTAssertEqual(Retention.deletionDay(lastAppeared: last, recorded: nil, calendar: calendar), Fixtures.date(2027, 9, 13, 18, 25))
        let gabriel = UUID(), serenity = UUID(), nameOnly = UUID()
        let entries = [(id: gabriel, name: "Gabriel", lastAppeared: Optional(last), recorded: Optional<Date>.none),
                       (id: serenity, name: "Serenity", lastAppeared: nil, recorded: Optional(Fixtures.date(2025, 10, 1, 9, 0))),
                       (id: nameOnly, name: "Asha", lastAppeared: Optional(Fixtures.date(2024, 1, 1, 9, 0)), recorded: nil)]
        let holds: (UUID) -> Bool = { $0 != nameOnly }
        XCTAssertEqual(Retention.review(entries, holds: holds, now: Fixtures.date(2027, 8, 1, 9, 0), calendar: calendar), [.now(serenity, name: "Serenity")],
                       "a name with nothing in the vault is never due")
        XCTAssertEqual(Retention.review(entries, holds: holds, now: Fixtures.date(2027, 8, 20, 9, 0), calendar: calendar),
                       [.soon(gabriel, name: "Gabriel", on: Fixtures.date(2027, 9, 13, 18, 25)), .now(serenity, name: "Serenity")])
        XCTAssertEqual(Retention.review(entries, holds: holds, now: Fixtures.date(2027, 9, 14, 9, 0), calendar: calendar).first, .now(gabriel, name: "Gabriel"))
        XCTAssertEqual(Retention.line(name: "Gabriel", on: Fixtures.date(2027, 9, 13, 18, 25)),
                       "On Mon 13 Sep 2027, Prakriti deletes what it keeps of Gabriel's face and voice, 12 months after Gabriel last appeared in a recording.")

        // Through the model, on a fixed clock: due now is forgotten, due soon is a Needs You line.
        var clock = Fixtures.date(2027, 8, 20, 9, 0)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: home),
                             settings: .ephemeral(), log: AppLog(directory: nil), now: { clock })
        model.peopleFolders = folders
        let person = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        defer { model.vault.forget(person: person.id) }
        let recording = twoPeopleRecording(model, day: last)
        model.setTeacher(person, for: recording)
        try model.vault.seal(Data("made-up crop".utf8), kind: .face, person: person.id)
        model.reviewRetention()
        XCTAssertEqual(model.retentionLines.count, 1)
        XCTAssertTrue(model.vault.holdsAnything(person: person.id), "not deleted before the day")
        clock = Fixtures.date(2027, 9, 14, 9, 0)
        model.reviewRetention()
        XCTAssertTrue(model.retentionLines.isEmpty)
        XCTAssertFalse(model.vault.holdsAnything(person: person.id), "deleted on the day")
        XCTAssertEqual(person.forgottenAt, clock)
        XCTAssertEqual(person.name, "Gabriel", "the name is kept")
    }
}
