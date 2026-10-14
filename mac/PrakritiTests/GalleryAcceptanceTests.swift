import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M7a's acceptance (docs/v2/PLAN.md M7 check 2, "with no release recorded", always run), on a real fixture through
/// the app's own runner, in development:
///
/// - **two-people-mixed.mp4** made with its people check (faces, then voices): the gallery has no named person, and its
///   one face-less tile lists the fixture;
/// - Name This Person on the corner face opens at Name Only (its default button), and Name Only names it;
/// - afterwards `People/Faces`, `People/Voices` and `People/FaceIndex` hold no files, in development and live, and the
///   vault keeps nothing and no key for the person;
/// - `tmutil isexcluded` on the development People folder (prepared as every launch prepares it) reports Excluded; the
///   live folder's answer is written down too (the installed copy prepares it at its next launch);
/// - the gallery and the person page drawn from what was found, key photos as test patterns (D1).
///
///   cd ~/Code/prakriti/mac && make accept-gallery MILESTONE=v2-m7a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=gallery. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the fixture is
/// only read, checked by size and date before and after. Never a class, never the archive.
@MainActor
final class GalleryAcceptanceTests: XCTestCase {
    func testGalleryWithNoReleaseRecorded() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "gallery" else {
            throw XCTSkip("Makes the two-people-mixed fixture. Run it with: cd ~/Code/prakriti/mac && make accept-gallery MILESTONE=v2-m7a")
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
        model.log.write("Acceptance test for v2 part M7a (the People gallery) started.")
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var report = ["v2 part M7a acceptance (the People gallery, no release recorded), \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        let mixed = home.appending(path: "Prakriti/Dev/Fixtures/two-people-mixed.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mixed.path), "cd ~/Code/prakriti/mac && make fixtures")
        let before = fingerprint(mixed)
        let live = PeopleFolders(support: AppPaths(mode: .live).applicationSupport)
        let liveBefore = live.forbidden.map { files(under: $0).count }

        // The fixture made with its people check, nobody named.
        let folder = paths.outputs.appending(path: "two-people-mixed", directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: folder)
        let recording = Recording(filePath: mixed.path, recordedAt: Date(), foundAt: Date())
        model.context.insert(recording)
        try model.context.save()
        await model.runner.process(recording, trigger: .byHand)
        await model.cardPicturesSettled()
        let faces = try XCTUnwrap(recording.faces, "no faces in the store")
        let voices = try XCTUnwrap(recording.voices, "no voices in the store")
        let corner = try XCTUnwrap(faces.people.first { $0.keyBox.x > 0.6 }, "the corner face is a row")
        report.append("two-people-mixed: \(faces.people.count) face rows (corner: \(corner.label), \(Format.timecode(corner.first)) to \(Format.timecode(corner.last))), \(voices.voices.count) voices")

        // The gallery: nobody named, one face-less tile listing the fixture.
        let named = Gallery.ordered(model.galleryEntries(), sort: .name, showHidden: true)
        let unnamed = Gallery.unnamedRecordings((try? model.context.fetch(FetchDescriptor<Recording>())) ?? [])
        XCTAssertTrue(named.isEmpty, "the gallery has no named person")
        XCTAssertTrue(unnamed.contains { $0.id == recording.id }, "the Unnamed people tile lists the fixture")
        report.append("Gallery before naming: \(named.count) named people; the Unnamed people tile lists \(Format.count(unnamed.count, "recording")) (the fixture: \(unnamed.contains { $0.id == recording.id } ? "yes" : "NO"))")
        try draw(renderer, model, "m7a-gallery-empty") { $0.selection = .people }

        // Name This Person on the corner face: Name Only by default.
        model.askToName(.face(corner.id), in: recording)
        var request = try XCTUnwrap(model.nameSheet)
        XCTAssertEqual(request.draft.defaultAction, .nameOnly)
        XCTAssertFalse(request.draft.recordRelease)
        report.append("Name This Person on \(corner.label): default button \(request.draft.defaultAction == .nameOnly ? "Name Only" : "Record Release"), release switch \(request.draft.recordRelease ? "on" : "off")")
        request.draft.name = "Guest"
        XCTAssertNil(model.finishNaming(request, as: request.draft.defaultAction))
        model.nameSheet = nil
        let guest = try XCTUnwrap(model.namedPeopleList().first { $0.name == "Guest" })
        XCTAssertFalse(guest.hasRelease)
        XCTAssertEqual(recording.names.faces[corner.id], guest.id)
        let entries = Gallery.ordered(model.galleryEntries(), sort: .name)
        XCTAssertEqual(entries.map(\.name), ["Guest"])
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.recordings, 1)
        XCTAssertEqual(entry.onScreen, corner.onScreen, accuracy: 0.01)
        report.append("After Name Only: People shows \(entries.map(\.name).joined(separator: ", ")), \(entry.tileLine), \(Gallery.minutes(entry.onScreen)) on screen, \(Gallery.minutes(entry.speaking)) speaking; status: \(Gallery.statusLine(guest))")
        try draw(renderer, model, "m7a-gallery-name-only") { $0.selection = .people }
        try draw(renderer, model, "m7a-person-name-only") { $0.selection = .person(guest.id) }

        // Nothing stored about anyone's face or voice.
        model.vault.prepare()
        var stored: [String] = []
        for folder in model.peopleFolders.forbidden + live.forbidden {
            let count = files(under: folder).count
            stored.append("\(paths.display(folder.path)): \(FileManager.default.fileExists(atPath: folder.path) ? "\(count) files" : "absent")")
            XCTAssertEqual(count, 0, "\(folder.path) holds files")
        }
        XCTAssertFalse(model.vault.holdsAnything(person: guest.id), "no sealed file and no key for a Name Only person")
        XCTAssertEqual(live.forbidden.map { files(under: $0).count }, liveBefore)
        report.append("After Name Only, Faces, Voices and FaceIndex: " + stored.joined(separator: "; "))
        report.append("Vault for Guest: \(model.vault.holdsAnything(person: guest.id) ? "HOLDS SOMETHING" : "nothing sealed, no key")")

        // Out of Time Machine.
        let development = try output(URL(fileURLWithPath: "/usr/bin/tmutil"), ["isexcluded", model.peopleFolders.people.path])
        XCTAssertTrue(development.contains("[Excluded]"), development)
        report.append("tmutil isexcluded (development): \(development)")
        let livePeople = live.people
        let liveAnswer = FileManager.default.fileExists(atPath: livePeople.path)
            ? try output(URL(fileURLWithPath: "/usr/bin/tmutil"), ["isexcluded", livePeople.path]) : "\(livePeople.path) does not exist yet"
        report.append("tmutil isexcluded (live, prepared by the installed copy at launch, not by this test): \(liveAnswer)")

        // Clean up the name in this in-memory store, and check the fixture was only read.
        model.removePerson(guest)
        XCTAssertEqual(fingerprint(mixed), before)
        report.append("Fixture unchanged (size and modification date): \(fingerprint(mixed) == before ? "yes" : "NO")")
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        XCTAssertTrue(jobs.isEmpty, "a job folder was left: \(jobs)")
        report.append("Development Jobs/: \(jobs.isEmpty ? "empty" : jobs.joined(separator: ", "))")
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-gallery.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M7a finished.")
    }

    private func draw(_ renderer: SnapshotRenderer, _ model: AppModel, _ name: String, _ change: (AppModel) -> Void) throws {
        change(model)
        for (scheme, appearance) in SnapshotRenderer.appearances {
            try renderer.render(model: model, appearance: appearance, name: "\(name)-\(scheme)")
        }
    }

    private func files(under folder: URL) -> [String] {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.map(\.path)
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }

    private func output(_ tool: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
