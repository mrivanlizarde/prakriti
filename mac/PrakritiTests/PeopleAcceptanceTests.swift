import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M6a's acceptance (docs/v2/PLAN.md M6: check 2's faces half and bit for bit, check 7, check 8's faces
/// half, check 12's People tab and cards), on real files through the app's own runner, in development:
///
/// - the **13 Sep talk**, made with the trim off at -16 LUFS (engine v0's chain): one face track group covering
///   at least 95% of the sampled frames, and its episode's decoded audio equal to engine v0's bit for bit (the
///   face step changes nothing that is made). If two or more faces are ever seen at once, their times and counts
///   are written down and that half is for Ivan (is someone else really there?), never a FAIL (PLAN review item 22);
/// - the **two-people-mixed** and **two-people-tracks** fixtures: two faces at once, the corner one from 0:20 to
///   0:60, the fixed notice once;
/// - the face step alone on the **6 Sep talk** (55:39), timed: under 5 minutes;
/// - nothing stored for strangers: no Faces, Voices or FaceIndex folder, no job folder left, no print and no
///   picture in any people file, and no image file anywhere under Application Support/Prakriti.
///
///   cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=people. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the
/// originals are only read, checked by size and date before and after. Never a class, never the archive. Frames
/// of Gabriel's talks are measured, never drawn: the People tab's faces are test patterns or empty circles in the
/// pictures this writes, and the frames listed for Ivan are only written for him to look at (section 11, D1).
@MainActor
final class PeopleAcceptanceTests: XCTestCase {
    func testFacesOnRealFiles() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "people" else {
            throw XCTSkip("Reads the 13 Sep and 6 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6a")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.log.write("Acceptance test for v2 part M6a (faces) started.")
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())

        let talk13 = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        let talk6 = paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4")
        let mixed = home.appending(path: "Prakriti/Dev/Fixtures/two-people-mixed.mp4")
        let tracks = home.appending(path: "Prakriti/Dev/Fixtures/two-people-tracks.mov")
        let files = [talk13, talk6, mixed, tracks]
        for file in files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing: \(file.path) (cd ~/Code/prakriti/mac && make fixtures)")
            for day in ["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"] { XCTAssertFalse(file.path.contains(day), "never a class") }
        }
        let before = files.map(fingerprint)
        var report = ["v2 part M6a acceptance (faces), \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        // Check 2 (faces; bit for bit): the 13 Sep talk on engine v0's chain.
        let talkFolder = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        precondition(talkFolder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: talkFolder)
        let talk = Recording(filePath: talk13.path, recordedAt: AppModel.dateInName(talk13.lastPathComponent), foundAt: Date())
        model.context.insert(talk)
        talk.source = model.source(containing: talk13)
        try model.context.save()
        model.setOutput(.podcastEpisode, on: true, for: talk)
        let own = try XCTUnwrap(talk.outputSettings.first { $0.kind == .podcastEpisode })
        own.trimSilence = false
        own.loudnessTarget = -16
        try model.context.save()
        await model.runner.process(talk, trigger: .byHand)
        XCTAssertEqual(talk.status, .readyForYourYes, talk.statusReason ?? "")
        let found = try XCTUnwrap(talk.faces, "the 13 Sep talk has no faces in the store")
        let step = talk.latestRun?.steps.first { $0.name == PipelineStep.faces.title }
        XCTAssertEqual(step?.state, .done)
        let people = try XCTUnwrap(model.peopleFolders.read(talk.id), "no people file for the 13 Sep talk")
        let main = try XCTUnwrap(found.people.first)
        let coverage = Double(people.tracks.filter { $0.person == main.id }.map(\.boxes.count).reduce(0, +)) / Double(max(1, found.samples))
        let withFaces = Double(found.samplesWithFaces) / Double(max(1, found.samples))
        report.append("13 Sep talk (15:48): \(found.stepLine)")
        report.append(String(format: "  frames looked at %d, with a face %d (%.1f%%), most at once %d, frames with two or more %d, first at %@, tracks %d, changes of picture %d, rows %d, glimpses %d, step %.1f s",
                             found.samples, found.samplesWithFaces, withFaces * 100, found.mostAtOnce, found.samplesWithOthers,
                             found.firstWithOthers.map(Format.timecode) ?? "never", found.tracks, found.cuts, found.people.count, found.glimpses, found.seconds))
        report.append(String(format: "  the main track group (%@) covers %.1f%% of the sampled frames, %@ to %@", main.label, coverage * 100,
                             Format.timecode(main.first), Format.timecode(main.last)))
        if found.mostAtOnce >= 2 {
            // Two or more faces at once in the talk: written down for Ivan, not judged by the build (PLAN review item 22).
            let before = Double(people.tracks.filter { $0.person == main.id }.flatMap(\.boxes).filter { $0[0] < (found.firstWithOthers ?? 0) }.count)
            let samplesBefore = Double(Int((found.firstWithOthers ?? 0) / found.every))
            report.append(String(format: "  IVAN: up to %d faces at once from %@ on (%d frames, %@ in all). Before then, the main group covers %.1f%% of the frames.",
                                 found.mostAtOnce, Format.timecode(found.firstWithOthers ?? 0), found.samplesWithOthers,
                                 Format.length(Double(found.samplesWithOthers) * found.every), samplesBefore > 0 ? before / samplesBefore * 100 : 0))
            for row in found.people.dropFirst() {
                report.append("    \(row.label): on screen \(Format.length(row.onScreen)), \(Format.timecode(row.first)) to \(Format.timecode(row.last)), \(row.appearances) track(s)")
            }
            // Three frames where the most faces were seen, for Ivan to look at; never opened by the build (D1).
            let ivan = renderer.outputFolder.appending(path: "for-ivan", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: ivan, withIntermediateDirectories: true)
            // The first frame with two or more faces, one with the most, and the last with two or more.
            let counts = Dictionary(grouping: people.tracks.flatMap(\.boxes), by: { ($0[0] * 2).rounded() / 2 }).mapValues(\.count)
            let crowded = counts.filter { $0.value >= 2 }.keys.sorted()
            let most = counts.filter { $0.value == found.mostAtOnce }.keys.sorted()
            for (index, time) in [crowded.first, most.first, crowded.last].compactMap({ $0 }).enumerated() {
                let png = ivan.appending(path: String(format: "13sep-%d-%@.png", index + 1, Format.timecode(time).replacingOccurrences(of: ":", with: "-")))
                try ffmpeg(["-ss", String(format: "%.2f", time), "-i", talk13.path, "-frames:v", "1", png.path])
                report.append("    for Ivan to look at (not opened by the build): \(png.path)")
            }
        } else {
            XCTAssertGreaterThanOrEqual(coverage, 0.95, "one face track group covers at least 95% of the sampled frames")
        }
        let made = try decodedMD5(talkFolder.appending(path: "episode.mp3"))
        let v0Episode = paths.home.appending(path: "Prakriti/Outputs/2026-09-13 18-25-44/episode.mp3")
        let v0 = FileManager.default.fileExists(atPath: v0Episode.path) ? try decodedMD5(v0Episode) : nil
        XCTAssertEqual(made, v0, "with faces looked for, the episode is still engine v0's, bit for bit")
        report.append("  episode decoded audio md5: \(made); engine v0's episode (read only): \(v0 ?? "not found") (\(made == v0 ? "identical" : "DIFFERENT"))")
        XCTAssertTrue(talk.isPrivacyLocked, "faces alone never open the privacy lock")
        report.append("  privacy lock: \(talk.isPrivacyLocked ? "still locked (faces alone are not a people check)" : "OPEN")")
        report.append("")

        // The two fixtures: two faces at once, and the one fixed notice.
        model.notifier.poster = nil
        var fixtureRecordings: [(String, Recording)] = []
        for (name, file) in [("two-people-mixed", mixed), ("two-people-tracks", tracks)] {
            let folder = paths.outputs.appending(path: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
            precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
            try? FileManager.default.removeItem(at: folder)
            let sentBefore = model.notifier.sent.count
            let recording = Recording(filePath: file.path, recordedAt: Date(), foundAt: Date())
            model.context.insert(recording)
            try model.context.save()
            await model.runner.process(recording, trigger: .byHand)
            let faces = try XCTUnwrap(recording.faces, "\(name): no faces in the store")
            XCTAssertEqual(faces.mostAtOnce, 2, "\(name): two faces at once")
            XCTAssertTrue(faces.otherPeopleAppear)
            XCTAssertEqual(faces.line, "Other people appear, up to 2 at once.")
            let corner = faces.people.first { $0.keyBox.x > 0.6 }
            XCTAssertNotNil(corner, "\(name): the corner face is a row")
            XCTAssertEqual(corner?.first ?? 0, 20, accuracy: 1.0)
            XCTAssertEqual(corner?.last ?? 0, 60, accuracy: 1.0)
            let notices = model.notifier.sent.dropFirst(sentBefore).filter { $0.event == .otherPeople }
            XCTAssertEqual(notices.map(\.body), [NoticeBuilder.otherPeopleBody], "\(name): the fixed notice, once")
            report.append("\(name): \(faces.stepLine)")
            report.append("  rows: " + faces.people.map { "\($0.label) \(Format.length($0.onScreen)) (\(Format.timecode($0.first)) to \(Format.timecode($0.last)))" }.joined(separator: "; ")
                          + "; glimpses \(faces.glimpses); notice: " + notices.map { "\"\($0.title)\" \"\($0.body)\"" }.joined())
            fixtureRecordings.append((name, recording))
        }
        report.append("")

        // Check 8 (faces): the face step alone on the 6 Sep talk, timed.
        let clock = ContinuousClock()
        let started = clock.now
        let sixID = UUID()
        let six = try await FaceStep.run(file: talk6, recordingID: sixID, folders: model.peopleFolders, now: Date())
        let seconds = Double((clock.now - started).components.seconds)
        XCTAssertLessThan(seconds, 300, "the face step on 55:39 takes under 5 minutes")
        report.append("6 Sep talk (55:39), the face step alone: \(String(format: "%.0f", seconds)) s (limit 300 s). \(six.found.stepLine)")
        let sixFile = try Data(contentsOf: model.peopleFolders.peopleFile(for: sixID))
        try PeopleTests.assertNoPrintAndNoPicture(sixFile)
        model.peopleFolders.removePeopleFile(for: sixID)
        report.append("")

        // Check 7: nothing stored for strangers.
        let live = AppPaths(mode: .live).applicationSupport
        for folders in [model.peopleFolders, PeopleFolders(support: live)] {
            for forbidden in folders.forbidden {
                XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), forbidden.path)
                report.append("does not exist: \(forbidden.path): \(FileManager.default.fileExists(atPath: forbidden.path) ? "NO, IT EXISTS" : "yes")")
            }
        }
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        XCTAssertEqual(jobs, [], "no job folder is left")
        report.append("development Jobs folder: \(jobs.isEmpty ? "empty" : "NOT EMPTY: \(jobs)")")
        for recording in [talk] + fixtureRecordings.map(\.1) {
            let data = try Data(contentsOf: model.peopleFolders.peopleFile(for: recording.id))
            try PeopleTests.assertNoPrintAndNoPicture(data)
            let json = try JSONSerialization.jsonObject(with: data)
            let longest = PeopleTests.numberArrays(json).map(\.count).max() ?? 0
            report.append("people file \(recording.id.uuidString).json (\(recording.fileName)): \(data.count) bytes, longest list of numbers \(longest), no picture or print words")
        }
        var images: [String] = []
        var examined = 0
        let root = home.appending(path: "Library/Application Support/Prakriti", directoryHint: .isDirectory)
        for url in (FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.compactMap { $0 as? URL } ?? [])
        where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            examined += 1
            let kind = try output(URL(fileURLWithPath: "/usr/bin/file"), ["-b", "--mime-type", url.path])
            if kind.hasPrefix("image/") { images.append("\(url.path): \(kind)") }
        }
        XCTAssertEqual(images, [], "no image under Application Support/Prakriti")
        report.append("`file --mime-type` on every file under \(root.path): \(examined) files, \(images.count) images" + (images.isEmpty ? "" : ": \(images)"))
        report.append("")

        // Check 12: the People tab of each, and the cards with their people lines, light and dark. The face circles
        // are drawn before any crop arrives, so no picture of anyone is in these PNGs.
        var drawn: [String] = []
        // A test pattern in every face circle, so these pictures can be looked at (D1): the layout is what is checked.
        model.faceCrops.useTestPattern = true
        for (scheme, appearance) in SnapshotRenderer.appearances {
            for (slug, recording) in [("talk-13-sep", talk)] + fixtureRecordings {
                model.path = []
                model.selection = .group(.all)
                model.selectedRecordings = [recording.id]
                model.inspectorTab = .people
                let name = "m6a-people-\(slug)-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                drawn.append(name)
            }
            model.selectedRecordings = []
            model.selection = .group(.all)
            try renderer.render(model: model, appearance: appearance, name: "m6a-cards-\(scheme)")
            model.browserMode = .list
            try renderer.render(model: model, appearance: appearance, name: "m6a-list-\(scheme)")
            model.browserMode = .grid
            drawn += ["m6a-cards-\(scheme)", "m6a-list-\(scheme)"]
        }
        report.append("Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", "))

        // The originals were only read.
        let after = files.map(fingerprint)
        XCTAssertEqual(after, before)
        report.append("Originals unchanged (size and modification date): \(after == before ? "yes" : "NO")")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-people.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M6a finished.")
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

    private func ffmpeg(_ arguments: [String]) throws {
        _ = try output(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y"] + arguments)
    }

    /// The md5 of the decoded audio, as milestone 2 compared episodes with engine v0's.
    private func decodedMD5(_ file: URL) throws -> String {
        try output(ToolPaths.standard.ffmpeg, ["-v", "error", "-i", file.path, "-map", "0:a", "-f", "md5", "-"])
    }
}
