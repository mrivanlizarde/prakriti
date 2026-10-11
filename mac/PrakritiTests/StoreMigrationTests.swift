import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Opens a COPY of a real store with this build's schema, the check to run before `make install`
/// whenever the models change. The live store is never opened here: the make target copies it first.
///
///   cd ~/Code/prakriti/mac && make migrate-check
///
/// Skipped unless PRAKRITI_STORE_COPY names the copied store.
@MainActor
final class StoreMigrationTests: XCTestCase {
    func testACopyOfTheStoreOpensWithThisSchema() throws {
        guard let path = ProcessInfo.processInfo.environment["PRAKRITI_STORE_COPY"], !path.isEmpty else {
            throw XCTSkip("Needs a copy of a store. Run it with: cd ~/Code/prakriti/mac && make migrate-check")
        }
        let live = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Prakriti/Prakriti.store").path
        XCTAssertNotEqual(URL(fileURLWithPath: path).resolvingSymlinksInPath().path, live, "never the live store itself")
        let container = try PrakritiStore.makeContainer(at: URL(fileURLWithPath: path))
        let context = container.mainContext
        let recordings = try context.fetch(FetchDescriptor<Recording>())
        let sources = try context.fetch(FetchDescriptor<Source>())
        let settings = try context.fetch(FetchDescriptor<OutputSetting>())
        let lines = try context.fetchCount(FetchDescriptor<LogEntry>())
        XCTAssertFalse(sources.isEmpty, "the copy has its folders")
        XCTAssertFalse(settings.isEmpty, "the copy has its output settings")
        // The fields milestone 4 added arrive empty, and nothing that was there is lost.
        for recording in recordings {
            XCTAssertNil(recording.episodeDuration)
            XCTAssertEqual(recording.madeFiles, [])
            // Milestone 5's fields arrive empty: no edits, none waiting for Make Again, nothing
            // approved, and a recording engine v0 made reads as one part, all of it.
            XCTAssertTrue(recording.edits.isEmpty)
            XCTAssertFalse(recording.editsPending)
            XCTAssertEqual(recording.episodeParts, [])
            XCTAssertNil(recording.approvedAt)
            XCTAssertEqual(recording.approvedFiles, [])
            // Milestone 6's fields arrive empty: nothing written, no problem recorded.
            XCTAssertNil(recording.writtenJSON)
            XCTAssertNil(recording.writingProblem)
            if recording.fromEngineV0, recording.status == .readyForYourYes, let duration = recording.duration {
                XCTAssertEqual(recording.episodeClock?.segments, [Mastering.Span(start: 0, end: duration)])
                XCTAssertTrue(ApprovalCheck.check(recording, isBusy: false).speakersNotChecked, "not marked as a talk yet")
            }
        }
        // Titles, show notes and chapters can be made from milestone 6. None of the folders may start
        // writing on its own after the upgrade: every folder's switch was stored off (it started off,
        // and could not be turned on before milestone 6).
        let writingOn = sources.filter { $0.setting(for: .titlesNotesChapters)?.isOn == true }.map(\.name)
        XCTAssertEqual(writingOn, [], "a folder would start writing with the 33 GB model on its own")
        // The podcast-ready episode (10 Oct, after v1): the launch adds its settings to an older store,
        // switched off everywhere, and its recording fields arrive empty.
        for recording in recordings {
            XCTAssertNil(recording.podcastReadyJSON)
            XCTAssertNil(recording.podcastReadyProblem)
            XCTAssertNil(recording.episodeNumber)
        }
        let added = try PrakritiStore.addMissingOutputKinds(context)
        let readyOn = sources.filter { $0.setting(for: .podcastReady)?.isOn == true }.map(\.name)
        XCTAssertEqual(readyOn, [], "a folder would start making podcast-ready episodes on its own")
        XCTAssertTrue(sources.allSatisfy { $0.setting(for: .podcastReady) != nil }, "every folder has the switch, off")
        let defaultReady = try context.fetch(FetchDescriptor<OutputSetting>()).filter { $0.kind == .podcastReady && $0.source == nil && $0.recording == nil }
        XCTAssertEqual(defaultReady.count, 1, "the Outputs screen has its settings")
        XCTAssertEqual(defaultReady.first?.isOn, false)
        print("The new output was added to the copy: \(added.map(\.title)); switched on in \(readyOn.count) folders")
        let ready = recordings.filter { $0.status == .readyForYourYes }
        print("Store copy opened: \(recordings.count) recordings (\(ready.count) ready: "
              + ready.map { "\($0.fileName) \($0.loudnessLUFS.map { String($0) } ?? "?") LUFS" }.joined(separator: ", ")
              + "), \(sources.count) folders (" + sources.map(\.name).joined(separator: ", ") + "), \(settings.count) output settings, \(lines) Activity lines; "
              + "titles switched on in \(writingOn.count) folders; \(recordings.filter { $0.writtenJSON != nil }.count) recordings with anything written")
    }
}
