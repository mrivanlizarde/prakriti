import Foundation
import SwiftData
import XCTest
@testable import Prakriti

@MainActor
final class ModelTests: XCTestCase {
    private func freshModel(mode: AppMode = .development) -> AppModel {
        AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: mode), settings: .ephemeral(),
                 log: AppLog(directory: nil), now: { Fixtures.now })
    }

    func testSeedCreatesDefaultsAndOnlyTheDevDropFolder() throws {
        let model = freshModel()
        XCTAssertTrue(try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now))
        XCTAssertFalse(try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now), "seeding twice must do nothing")

        let sources = try model.context.fetch(FetchDescriptor<Source>())
        XCTAssertEqual(sources.count, 1)
        let drop = try XCTUnwrap(sources.first)
        XCTAssertEqual(drop.path, model.paths.home.appending(path: "Prakriti/Dev/Drop").path)
        XCTAssertNotEqual(drop.path, model.paths.studioRecordings.path, "development must never watch the live studio folder")
        XCTAssertEqual(drop.outputSettings.count, OutputKind.allCases.count)

        let defaults = model.defaultSettings()
        XCTAssertEqual(defaults.count, OutputKind.allCases.count)
        XCTAssertEqual(Set(defaults.filter(\.isOn).map(\.kind)), [.podcastEpisode, .transcript, .checksAndReport])
        let podcast = try XCTUnwrap(defaults.first { $0.kind == .podcastEpisode })
        XCTAssertEqual(podcast.loudnessTarget, -16)
        XCTAssertEqual(podcast.peakCeiling, -1)
        XCTAssertEqual(podcast.channels, .mono)
    }

    func testNotBuiltOutputsCannotBeSwitchedOn() {
        for kind in OutputKind.notBuilt {
            XCTAssertFalse(OutputSetting(kind: kind, isOn: true).isOn, "\(kind) is not built and must stay off")
        }
        XCTAssertEqual(OutputKind.built, [.podcastEpisode, .transcript, .checksAndReport, .titlesNotesChapters])
        XCTAssertEqual(OutputKind.notBuilt.count, 5)
    }

    func testOutputResolutionGoesRecordingThenSourceThenDefault() throws {
        let model = freshModel()
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now)
        let drop = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>()).first)
        let recording = Recording(filePath: "/tmp/a.mp4")
        model.context.insert(recording)
        recording.source = drop
        let defaults = model.defaultSettings()

        // Default only.
        XCTAssertEqual(OutputResolver.outputsToMake(recording: recording, source: nil, defaults: defaults),
                       [.podcastEpisode, .transcript, .checksAndReport])

        // The folder turns titles on.
        drop.setting(for: .titlesNotesChapters)?.isOn = true
        XCTAssertTrue(OutputResolver.outputsToMake(recording: recording, source: nil, defaults: defaults).contains(.titlesNotesChapters))

        // The recording turns the transcript off and sets its own loudness.
        let own = OutputSetting(kind: .transcript, isOn: false)
        model.context.insert(own)
        own.recording = recording
        let podcast = OutputSetting(kind: .podcastEpisode, isOn: true)
        podcast.loudnessTarget = -19
        model.context.insert(podcast)
        podcast.recording = recording
        XCTAssertEqual(OutputResolver.outputsToMake(recording: recording, source: nil, defaults: defaults),
                       [.podcastEpisode, .checksAndReport, .titlesNotesChapters])
        XCTAssertEqual(OutputResolver.setting(for: .podcastEpisode, recording: recording, source: nil, defaults: defaults)?.loudnessTarget, -19)
    }

    func testPrivacyLockForcesALocalModel() {
        let talk = Recording(filePath: "/tmp/talk.mp4", kind: .talk)
        let lesson = Recording(filePath: "/tmp/class.mp4", kind: .lesson)
        let withSerenity = Recording(filePath: "/tmp/s.mp4", kind: .talk)
        withSerenity.hasSerenity = true

        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: talk), .claudeAPI)
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: lesson), .lmStudio)
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: withSerenity), .lmStudio)
        XCTAssertTrue(ModelRouting.isOverridden(chosen: .claudeAPI, for: lesson))
        for provider in ModelProvider.allCases where provider.isLocal {
            XCTAssertEqual(ModelRouting.provider(chosen: provider, for: lesson), provider, "a local choice is kept")
        }
        XCTAssertFalse(ModelProvider.claudeAPI.isLocal)
    }

    func testStatusVocabulary() {
        XCTAssertEqual(RecordingStatus.allCases.filter(\.needsYou), [.readyForYourYes, .needsADecision, .couldntFinish])
        XCTAssertEqual(RecordingStatus.readyForYourYes.title, "Ready for your yes")
        XCTAssertEqual(RecordingStatus.couldntFinish.title, "Couldn't finish")
        XCTAssertEqual(Set(RecordingStatus.allCases.map(\.symbol)).count, RecordingStatus.allCases.count,
                       "each status needs its own symbol shape, not only its own color")
    }

    func testRecordsSurviveASaveAndARefetch() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "prakriti-test-\(UUID().uuidString)/Prakriti.store")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let container = try PrakritiStore.makeContainer(at: url)
            let context = ModelContext(container)
            let recording = Recording(filePath: "/tmp/b.mp4", title: "Talk", duration: 947.78, status: .readyForYourYes, kind: .talk)
            recording.cuts = [TimeRange(start: 10, end: 20), TimeRange(start: 300, end: 312.5)]
            context.insert(recording)
            let run = Run(startedAt: Fixtures.now, trigger: .byHand, outcome: .ready, steps: [
                RunStep(name: "First", state: .done, seconds: 1),
                RunStep(name: "Second", state: .done, seconds: 2),
                RunStep(name: "Third", state: .failed, seconds: nil, detail: "Stopped."),
            ])
            context.insert(run)
            run.recording = recording
            try context.save()
        }

        let container = try PrakritiStore.makeContainer(at: url)
        let context = ModelContext(container)
        let recording = try XCTUnwrap(try context.fetch(FetchDescriptor<Recording>()).first)
        XCTAssertEqual(recording.status, .readyForYourYes)
        XCTAssertEqual(recording.kind, .talk)
        XCTAssertEqual(recording.cuts, [TimeRange(start: 10, end: 20), TimeRange(start: 300, end: 312.5)])
        XCTAssertEqual(recording.latestRun?.steps.map(\.name), ["First", "Second", "Third"], "steps keep their order")
        XCTAssertEqual(recording.latestRun?.steps.last?.state, .failed)
    }

    func testRemovingAFolderKeepsItsRecordings() throws {
        let model = freshModel()
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now)
        let drop = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>()).first)
        let recording = Recording(filePath: drop.path + "/clip.mp4")
        model.context.insert(recording)
        recording.source = drop
        try model.context.save()

        model.remove(drop)
        try model.context.save()

        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Source>()), 0)
        let kept = try model.context.fetch(FetchDescriptor<Recording>())
        XCTAssertEqual(kept.count, 1, "removing a folder never removes what was found in it")
        XCTAssertNil(kept.first?.source)
        XCTAssertEqual(model.defaultSettings().count, OutputKind.allCases.count, "the defaults stay")
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<OutputSetting>()), OutputKind.allCases.count,
                       "the folder's own settings go with it")
    }

    func testAddingByHandTakesOnlyMediaAndNoDuplicates() throws {
        let model = freshModel()
        let urls = [URL(fileURLWithPath: "/tmp/2026-09-13 18-25-44.mp4"), URL(fileURLWithPath: "/tmp/notes.txt"),
                    URL(fileURLWithPath: "/tmp/voice.m4a")]
        XCTAssertEqual(model.addRecordings(urls).count, 2)
        XCTAssertEqual(model.addRecordings(urls).count, 0, "the same files are not added twice")
        let all = try model.context.fetch(FetchDescriptor<Recording>())
        XCTAssertTrue(all.allSatisfy { $0.status == .found })
        let entries = try model.context.fetch(FetchDescriptor<LogEntry>())
        XCTAssertEqual(entries.count, 2, "each addition leaves one line in Activity")
    }

    func testAddingAFolderTwiceAddsItOnce() throws {
        let model = freshModel()
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now)
        let folder = URL(fileURLWithPath: "/tmp/Some Folder", isDirectory: true)
        XCTAssertNotNil(model.addSource(at: folder))
        XCTAssertNil(model.addSource(at: folder))
        let added = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>()).first { $0.name == "Some Folder" })
        XCTAssertEqual(added.mode, .askFirst, "a new folder asks first, so adding one never starts work by itself")
        XCTAssertEqual(added.outputSettings.count, OutputKind.allCases.count)
    }

    func testOBSFileNamesGiveTheRecordingTime() throws {
        let date = try XCTUnwrap(AppModel.dateInName("2026-09-13 18-25-44.mp4"))
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second], [2026, 9, 13, 18, 25, 44])
        XCTAssertNotNil(AppModel.dateInName("2026-09-13 clip 90s.mp4"))
        XCTAssertNil(AppModel.dateInName("voice memo.m4a"))
    }

    func testPauseIsRememberedAndLogged() throws {
        let model = freshModel()
        model.setPaused(true)
        XCTAssertTrue(model.settings.isPaused)
        model.setPaused(true)
        model.setPaused(false)
        let messages = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        XCTAssertEqual(messages.filter { $0.contains("Paused") }.count, 1, "pausing twice logs once")
        XCTAssertEqual(messages.filter { $0.contains("Resumed") }.count, 1)
    }

    // MARK: Development refusals (engine v0 owns the live folders until the milestone 3 switch-over)

    func testDevelopmentRefusesEngineFoldersAddedByHand() throws {
        let model = freshModel()
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now)
        let home = model.paths.home
        let refused: [URL] = [
            model.paths.studioRecordings,                                                  // the studio folder itself
            model.paths.studioRecordings.appending(path: "2026-09-16", directoryHint: .isDirectory),  // a class day inside it
            home.appending(path: "Prakriti/Drop", directoryHint: .isDirectory),            // engine v0's drop folder
            home.appending(path: "Prakriti/Outputs", directoryHint: .isDirectory),         // engine v0's outputs
            home.appending(path: "Prakriti", directoryHint: .isDirectory),                 // holds Drop and Outputs
            home.appending(path: "Documents", directoryHint: .isDirectory),                // holds the studio folder
            home.appending(path: "Documents/Design Work/Galindo x Lizarde", directoryHint: .isDirectory),
            home.appending(path: "Downloads/SerenityAI", directoryHint: .isDirectory),     // the archive
            home,                                                                          // holds all of them
        ]
        for folder in refused {
            XCTAssertNil(model.addSource(at: folder), "development must refuse \(folder.path)")
            XCTAssertNotNil(model.notice, "Ivan is told why for \(folder.path)")
            model.notice = nil
        }
        // The same folder spelled in other cases is still refused (the Mac's disk ignores case).
        XCTAssertNil(model.addSource(at: URL(fileURLWithPath: model.paths.studioRecordings.path.uppercased(), isDirectory: true)))
        model.notice = nil

        // Only the dev drop folder is a source, and every refusal left one line in Activity.
        let sources = try model.context.fetch(FetchDescriptor<Source>())
        XCTAssertEqual(sources.map(\.path), [home.appending(path: "Prakriti/Dev/Drop").path])
        let refusals = try model.context.fetch(FetchDescriptor<LogEntry>()).filter { $0.message.hasPrefix("Did not add") }
        XCTAssertEqual(refusals.count, refused.count + 1)
        XCTAssertTrue(refusals.allSatisfy { $0.level == .attention })

        // Folders of its own are fine: the dev folders, and anything else Ivan picks.
        XCTAssertNotNil(model.addSource(at: home.appending(path: "Prakriti/Dev/Clips", directoryHint: .isDirectory)))
        XCTAssertNotNil(model.addSource(at: home.appending(path: "Movies/Test clips", directoryHint: .isDirectory)))
        XCTAssertNotNil(model.addSource(at: home.appending(path: "Documents/Other project", directoryHint: .isDirectory)),
                        "a folder beside the studio folder's tree is fine")
        XCTAssertNil(model.notice)
    }

    func testDevelopmentRefusesClassFilesAndArchiveFilesAddedByHand() throws {
        let model = freshModel()
        let home = model.paths.home
        let studioClass = model.paths.studioRecordings.appending(path: "2026-09-16/2026-09-16 20-00-00.mp4")
        let v0Drop = home.appending(path: "Prakriti/Drop/clip.mp4")
        let archive = home.appending(path: "Downloads/SerenityAI/Takeout/YouTube/videos/call.mp4")
        let clip = home.appending(path: "Prakriti/Dev/Drop/2026-09-13 clip 90s.mp4")

        XCTAssertEqual(model.addRecordings([studioClass]).count, 0)
        XCTAssertEqual(model.notice?.title, "2026-09-16 20-00-00.mp4 was not added")
        XCTAssertTrue(model.notice?.message.contains("Studio Recordings") == true)
        model.notice = nil

        let added = model.addRecordings([v0Drop, archive, clip])
        XCTAssertEqual(added.map(\.fileName), ["2026-09-13 clip 90s.mp4"], "only the file outside engine v0's folders and the archive")
        XCTAssertEqual(model.notice?.title, "2 files were not added")
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 1)
    }

    func testLiveModeDoesNotRefuseTheStudioFolder() {
        let paths = AppPaths(mode: .live, home: URL(fileURLWithPath: "/Users/someone", isDirectory: true))
        XCTAssertNil(paths.refusal(for: paths.studioRecordings, isFolder: true), "after the switch-over the studio folder is Prakriti's")
        XCTAssertNil(paths.refusal(for: paths.drop, isFolder: true))
    }

    // MARK: Order

    func testRecordingsFromOneSessionKeepOneOrder() {
        let session = Fixtures.date(2026, 9, 13, 18, 25, 44)
        let a = Recording(filePath: "/x/2026-09-13 clip 45s.mp4", recordedAt: session, foundAt: Fixtures.date(2026, 10, 10, 10, 31))
        let b = Recording(filePath: "/x/2026-09-13 clip 90s.mp4", recordedAt: session, foundAt: Fixtures.date(2026, 10, 10, 11, 48))
        let c = Recording(filePath: "/x/b.mp4", recordedAt: session, foundAt: Fixtures.date(2026, 10, 9, 16, 15))
        let d = Recording(filePath: "/x/a.mp4", recordedAt: session, foundAt: Fixtures.date(2026, 10, 9, 16, 15))
        let newer = Recording(filePath: "/x/z.mp4", recordedAt: Fixtures.date(2026, 9, 14, 20, 0, 9), foundAt: Fixtures.date(2026, 10, 9, 21, 4))
        let expected = ["/x/z.mp4", "/x/2026-09-13 clip 90s.mp4", "/x/2026-09-13 clip 45s.mp4", "/x/a.mp4", "/x/b.mp4"]
        // Every starting order gives the same list.
        for start in [[a, b, c, d, newer], [newer, d, c, b, a], [c, a, newer, b, d], [d, newer, a, c, b]] {
            XCTAssertEqual(start.sorted(by: Recording.newestFirst).map(\.filePath), expected)
        }
    }
}
