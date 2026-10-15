import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import Prakriti

/// v2 part M3a: the library's rules without drawing a window. The smart groups as predicates over the
/// stored status, the browser's sections and sorts, the search, opening and coming back, Remove from
/// Library (the original untouched, the outputs to the Trash, never found again as new), the places a Show
/// Me link or a launch flag opens, the status words, the privacy lock's line, and every text color's
/// contrast, measured.
@MainActor
final class LibraryTests: XCTestCase {
    private func recording(_ status: RecordingStatus, _ name: String, day: Int, month: Int = 9, kind: RecordingKind = .talk,
                           duration: Double = 600, in model: AppModel) -> Recording {
        let r = Recording(filePath: "/tmp/library-test/\(name).mp4", title: name, recordedAt: Fixtures.date(2026, month, day, 18),
                          foundAt: Fixtures.date(2026, 10, day % 28 + 1, 9), duration: duration, status: status, kind: kind)
        model.context.insert(r)
        return r
    }

    private func emptyModel() -> AppModel {
        AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development), settings: .ephemeral(),
                 log: AppLog(directory: nil), now: { Fixtures.now })
    }

    // MARK: Smart groups

    /// Each group is a SwiftData predicate over the raw status string (START_HERE, Mac warning 11), and it
    /// holds exactly the statuses the design spec gives it (2.4).
    func testSmartGroupsArePredicatesOverTheStoredStatus() throws {
        let model = emptyModel()
        for (index, status) in RecordingStatus.allCases.enumerated() {
            _ = recording(status, "r-\(status.rawValue)", day: index + 1, in: model)
        }
        try model.context.save()
        let expected: [SmartGroup: Set<RecordingStatus>] = [
            .needsYou: [.readyForYourYes, .needsADecision, .couldntFinish],
            .inProgress: [.found, .working],
            .ready: [.approved],
            .all: Set(RecordingStatus.allCases),
        ]
        for group in SmartGroup.allCases {
            let fetched = try model.context.fetch(FetchDescriptor<Recording>(predicate: group.predicate))
            XCTAssertEqual(Set(fetched.map(\.status)), expected[group], "\(group.title) read through its predicate")
            XCTAssertEqual(Set(RecordingStatus.allCases.filter(group.contains)), expected[group], "\(group.title) in code")
        }
        // Skipped (a test clip) is in All Recordings only.
        XCTAssertEqual(SmartGroup.allCases.filter { $0.contains(.skipped) }, [.all])
        // Needs You is exactly what the menu bar counts as needing Ivan.
        XCTAssertEqual(Set(RecordingStatus.allCases.filter(\.needsYou)), expected[.needsYou])
        XCTAssertEqual(SmartGroup.allCases.filter(\.showsCount), [.needsYou, .inProgress, .ready], "All Recordings shows no count")
        XCTAssertEqual(SmartGroup.allCases.map(\.title), ["Needs You", "In Progress", "Ready", "All Recordings"])
    }

    /// Every symbol the sidebar, the tiles, the inspector, the Settings panes and the browser use exists on this Mac.
    func testEverySymbolTheLibraryUsesExists() {
        let symbols = SmartGroup.allCases.map(\.symbol) + InspectorTab.allCases.map(\.symbol) + SettingsPane.allCases.map(\.symbol)
            + BrowserMode.allCases.map(\.symbol) + RecordingKind.allCases.map(\.tileSymbol)
            + ["folder", "tray.and.arrow.down", "plus", "exclamationmark.triangle", "sidebar.trailing", "line.3.horizontal.decrease.circle",
               "chevron.backward", "lock.fill", "lock.open", "externaldrive", "person.2", "bell", "checkmark.seal", "person.2.slash"]
        for symbol in symbols {
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "\(symbol) is not an SF Symbol on this Mac")
        }
    }

    // MARK: Sections and sorting

    func testEachGroupHasTheDesignSpecsSections() throws {
        let model = Fixtures.model()
        let all = try model.context.fetch(FetchDescriptor<Recording>())
        func titles(_ item: SidebarItem, waiting: [UUID] = []) -> [String?] {
            Library.sections(for: item, recordings: Library.members(of: item, in: all), waitingOrder: waiting).map(\.title)
        }
        XCTAssertEqual(titles(.group(.needsYou)), ["Waiting for your yes", "Needs a decision", "Couldn't finish"])
        XCTAssertEqual(titles(.group(.inProgress)), ["Working", "Found"])
        let clip = try XCTUnwrap(all.first { $0.fileName == "2026-09-13 clip 90s.mp4" })
        XCTAssertEqual(titles(.group(.inProgress), waiting: [clip.id]), ["Working", "Waiting"], "a recording in line is Waiting, in run order")
        XCTAssertEqual(titles(.group(.all)), ["September 2026"])
        XCTAssertEqual(titles(.group(.ready)), [], "nothing approved in the sample")
        let studio = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>()).first { $0.name == "Studio Recordings" })
        let studioRecordings = Library.members(of: .source(studio.id), in: all)
        XCTAssertEqual(Set(studioRecordings.map(\.fileName)), ["2026-09-13 18-25-44.mp4", "2026-09-14 20-00-09.mp4", "2026-09-06 18-06-33.mp4"])
    }

    func testMonthsNewestFirstAndNeedsYouOldestFirst() {
        let model = emptyModel()
        let a = recording(.readyForYourYes, "a", day: 13, in: model)
        let b = recording(.readyForYourYes, "b", day: 6, in: model)
        let c = recording(.approved, "c", day: 3, month: 10, in: model)
        let d = recording(.approved, "d", day: 20, in: model)
        c.approvedAt = Fixtures.date(2026, 10, 9)
        d.approvedAt = Fixtures.date(2026, 10, 2)
        let e = recording(.found, "e", day: 1, month: 8, in: model)
        let needs = Library.sections(for: .group(.needsYou), recordings: [a, b])
        XCTAssertEqual(needs.first?.recordings.map(\.title), ["b", "a"], "what has waited longest at the top")
        let ready = Library.sections(for: .group(.ready), recordings: [c, d])
        XCTAssertEqual(ready.map(\.title), ["October 2026"], "Ready is by the month it was approved")
        XCTAssertEqual(ready.first?.recordings.map(\.title), ["c", "d"])
        let everything = Library.sections(for: .group(.all), recordings: [a, b, c, d, e])
        XCTAssertEqual(everything.map(\.title), ["October 2026", "September 2026", "August 2026"])
        XCTAssertEqual(everything[1].recordings.map(\.title), ["d", "a", "b"], "newest first inside a month")
    }

    func testTheSortMenuAndTheKindFilter() {
        let model = emptyModel()
        let short = recording(.readyForYourYes, "Breath", day: 13, duration: 60, in: model)
        let long = recording(.readyForYourYes, "Asana", day: 6, kind: .lesson, duration: 3600, in: model)
        let mid = recording(.readyForYourYes, "Chant", day: 9, kind: .conversation, duration: 900, in: model)
        XCTAssertEqual(Library.sorted([short, long, mid], by: .title).map(\.title), ["Asana", "Breath", "Chant"])
        XCTAssertEqual(Library.sorted([short, long, mid], by: .length).map(\.title), ["Asana", "Chant", "Breath"])
        XCTAssertEqual(Library.sorted([short, long, mid], by: .dateRecorded).map(\.title), ["Breath", "Chant", "Asana"])
        let byTitle = Library.sections(for: .group(.needsYou), recordings: [short, long, mid], sort: .title)
        XCTAssertEqual(byTitle.first?.recordings.map(\.title), ["Asana", "Breath", "Chant"], "a chosen sort orders inside each section")
        XCTAssertEqual(Library.filtered([short, long, mid], kinds: []).count, 3, "no filter: every kind")
        XCTAssertEqual(Library.filtered([short, long, mid], kinds: [.lesson]).map(\.title), ["Asana"])
        XCTAssertEqual(Library.filtered([short, long, mid], kinds: [.talk, .conversation]).map(\.title), ["Breath", "Chant"])
        XCTAssertEqual(BrowserGrid.columns(for: 860), 3, "an 860 pt browser holds three 240 pt cards")
        XCTAssertEqual(BrowserGrid.columns(for: 300), 1)
    }

    // MARK: Search

    func testSearchFindsTitlesNotesAndWhatWasSaid() {
        let model = emptyModel()
        let talk = recording(.readyForYourYes, "Talk with Gabriel", day: 13, in: model)
        talk.notes = "About the first retreat."
        let lines = [TranscriptLine(id: 0, start: 0, end: 4, text: "The breath comes first.", words: [0.4, 0.8, 1.2, 1.6]),
                     TranscriptLine(id: 1, start: 4, end: 9, text: "Then the body follows Kṛṣṇamācārya's breath.", words: [4.3, 5]),
                     TranscriptLine(id: 2, start: 9, end: 12, text: "Nothing here.", words: [9.2])]
        func match(_ text: String, _ scopes: [SearchScope] = []) -> LibrarySearch.Match {
            LibrarySearch(text: text, scopes: scopes).match(talk) { lines }
        }
        XCTAssertTrue(match("gabriel").inTitle, "case does not matter")
        XCTAssertTrue(match("retreat").inTitle, "notes are searched with titles")
        XCTAssertEqual(match("breath").said.map(\.time).map { ($0 * 100).rounded() / 100 }, [0.25, 4.15], "every sentence that holds the word, at its first word")
        XCTAssertEqual(match("breath first").said.map(\.sentence), ["The breath comes first."], "every word must be found")
        XCTAssertEqual(match("krsnamacarya").said.count, 1, "accents do not matter")
        XCTAssertTrue(match("breath", [.title]).said.isEmpty, "Title searches titles and notes only")
        XCTAssertFalse(match("gabriel", [.said]).inTitle, "Said searches what was said only")
        XCTAssertTrue(match("zqxj").isEmpty)
        XCTAssertFalse(LibrarySearch(text: "   ").isActive)
        let many = (0..<6).map { TranscriptLine(id: $0, start: Double($0), end: Double($0) + 1, text: "breath \($0)") }
        XCTAssertEqual(LibrarySearch(text: "breath").match(talk) { many }.said.count, LibrarySearch.saidLimit, "at most three sentences per card")
    }

    // MARK: Opening and coming back

    func testOpenBackAndASaidResult() throws {
        let model = Fixtures.model()
        XCTAssertEqual(model.selection, .group(.needsYou), "the window opens on Needs You")
        let all = try model.context.fetch(FetchDescriptor<Recording>())
        let talk = try XCTUnwrap(all.first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
        model.selectedRecordings = [talk.id]
        XCTAssertEqual(model.focusedRecording?.id, talk.id, "the inspector shows the selected recording")
        model.openSelected()
        XCTAssertEqual(model.path.count, 1, "Open shows its page")
        XCTAssertEqual(model.focusedRecording?.id, talk.id)
        model.back()
        XCTAssertTrue(model.path.isEmpty, "Back returns to the browser")
        XCTAssertEqual(model.selectedRecordings, [talk.id], "with the recording still selected")
        model.selectedRecordings = []
        model.openSelected()
        XCTAssertTrue(model.path.isEmpty, "nothing selected: nothing opens")

        model.open(talk, at: 527.4)
        XCTAssertEqual(model.pendingSeek, PendingSeek(recordingID: talk.id, time: 527.4))
        XCTAssertEqual(model.path.count, 1)
        model.selection = .group(.all)
        XCTAssertTrue(model.path.isEmpty, "choosing another group closes the page")
        XCTAssertTrue(model.selectedRecordings.isEmpty)
    }

    // MARK: Remove from Library

    /// Prakriti forgets the recording and moves its Outputs folder to the Trash; the original and the
    /// approved copy are untouched; the next look does not find it as new; adding it by hand brings it back.
    func testRemoveFromLibraryNeverTouchesTheOriginalAndIsNotFoundAgain() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "prakriti-remove-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: nil), now: { Date() })
        for folder in paths.foldersToCreate { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date().addingTimeInterval(-60))
        model.watcher.scanTimeout = .seconds(10)
        let trash = home.appending(path: "Trash", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        model.moveToTrash = { url in try FileManager.default.moveItem(at: url, to: trash.appending(path: url.lastPathComponent)) }

        let original = paths.drop.appending(path: "2026-10-11 remove me.mp4")
        try Data(repeating: 7, count: 1000).write(to: original)
        let before = try Data(contentsOf: original)
        let added = try XCTUnwrap(model.addRecordings([original]).first)
        let outputs = paths.outputs.appending(path: "2026-10-11 remove me", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: true)
        try Data("episode".utf8).write(to: outputs.appending(path: "episode.mp3"))
        let approved = paths.approved.appending(path: "2026-10-11 remove me", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: approved, withIntermediateDirectories: true)
        try Data("approved".utf8).write(to: approved.appending(path: "episode.mp3"))
        added.outputFolder = outputs.path
        added.status = .readyForYourYes
        model.selectedRecordings = [added.id]

        XCTAssertTrue(model.removeFromLibrary(added))
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 0, "forgotten")
        XCTAssertEqual(try Data(contentsOf: original), before, "the original is untouched")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputs.path), "its Outputs folder is gone from Outputs")
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appending(path: "2026-10-11 remove me/episode.mp3").path), "into the Trash")
        XCTAssertTrue(FileManager.default.fileExists(atPath: approved.appending(path: "episode.mp3").path), "Approved is untouched")
        XCTAssertTrue(model.selectedRecordings.isEmpty)
        let drop = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>()).first { $0.kind == .dropFolder })
        XCTAssertEqual(drop.forgottenPaths, [original.standardizedFileURL.path])

        // The next look passes over it: not found as new, so not made again.
        await model.watcher.sweep(.checkNow)
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 0, "the folder does not bring it back as new")
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Removed Sun 11 Oct (2026-10-11 remove me.mp4) from the library. Its files in Outputs went to the Trash.") }, "\(lines)")
        XCTAssertFalse(lines.contains { $0.hasPrefix("Found 2026-10-11 remove me.mp4") }, "\(lines)")

        // Added by hand: back, and the folder no longer passes over it.
        XCTAssertEqual(model.addRecordings([original]).count, 1)
        XCTAssertEqual(drop.forgottenPaths, [])
    }

    func testRemoveFromLibraryIsRefusedWhileWorking() throws {
        let model = emptyModel()
        let working = recording(.working, "busy", day: 6, in: model)
        XCTAssertFalse(model.canRemoveFromLibrary(working))
        XCTAssertFalse(model.removeFromLibrary(working))
        XCTAssertEqual(model.notice?.title, "Not removed")
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Recording>()), 1)
    }

    /// A confirmation answered Yes runs the same model path as v1's page: Make Again starts a make.
    func testAConfirmationRunsTheModelsOwnPath() throws {
        let model = Fixtures.model()
        let talk = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
        XCTAssertTrue(model.canMakeAgain(talk))
        model.settings.isPaused = true    // so the make waits in line and nothing runs here
        model.ask(.makeAgain, for: talk)
        let question = try XCTUnwrap(model.confirmation)
        XCTAssertEqual(question.action, .makeAgain)
        model.confirm(question)
        XCTAssertNil(model.confirmation)
        XCTAssertTrue(model.runner.isWaiting(talk), "Make Again put it in line")
        XCTAssertFalse(model.canMakeAgain(talk), "and it cannot be asked twice")
        XCTAssertFalse(model.canRemoveFromLibrary(talk), "nor removed while it waits")
        model.runner.stopAll()
    }

    // MARK: Places

    func testPlacesByNameIncludingVOnesScreens() {
        XCTAssertEqual(HelpPlace(path: "needs-you"), .group(.needsYou))
        XCTAssertEqual(HelpPlace(path: "group/all-recordings"), .group(.all))
        XCTAssertEqual(HelpPlace(path: "source"), .sources)
        XCTAssertEqual(HelpPlace(path: "settings-models"), .settings(.models))
        XCTAssertEqual(HelpPlace(path: "settings/privacy"), .settings(.privacy))
        XCTAssertEqual(HelpPlace(path: "activity"), .activity)
        // v1's screen names land on the place that took each one over.
        XCTAssertEqual(HelpPlace(path: "today"), .group(.needsYou))
        XCTAssertEqual(HelpPlace(path: "recordings"), .group(.all))
        XCTAssertEqual(HelpPlace(path: "sources"), .sources)
        XCTAssertEqual(HelpPlace(path: "outputs"), .settings(.outputs))
        XCTAssertEqual(HelpPlace(path: "models"), .settings(.models))
        XCTAssertEqual(HelpPlace(path: "settings"), .settings(.general))
        XCTAssertNil(HelpPlace(path: "nowhere"))
        XCTAssertEqual(HelpPlace(path: "settings/houseStyle"), .settings(.houseStyle))
        XCTAssertEqual(HelpPlace(path: "settings/house-style"), .settings(.houseStyle))
        XCTAssertEqual(HelpPlace.known.count, 4 + 1 + 6 + 1 + 1, "the People gallery since v2 part M7a; the House Style pane since M9a")

        let model = Fixtures.model()
        model.go(to: .settings(.models))
        XCTAssertEqual(model.settingsPane, .models)
        XCTAssertEqual(model.pendingWindow, .settings, "no view has opened yet: it opens with the main window")
        var opened = 0
        model.openSettingsWindow = { opened += 1 }
        model.openPendingWindow()
        XCTAssertEqual(opened, 1)
        XCTAssertNil(model.pendingWindow)
    }

    // MARK: Words

    /// The privacy lock's line names the real reason and never a person (design spec C4). Since part LOCK only Ivan's own
    /// marks lock a recording: a talk, a class, and a transcript that names Serenity have no lock line.
    func testTheLockLineNamesNoOne() {
        let model = emptyModel()
        let talk = recording(.readyForYourYes, "talk", day: 13, in: model)
        XCTAssertNil(talk.lockLine)
        talk.hasSerenity = true
        XCTAssertNil(talk.lockLine, "a name said aloud locks nothing")
        talk.kind = .lesson
        XCTAssertNil(talk.lockLine, "a class locks nothing")
        var choices = PeopleChoices()
        choices.set(.leaveOut, for: .voice(2))
        talk.choices = choices
        XCTAssertEqual(talk.lockLine, "Someone in it is set to Leave Out, so only models on this Mac read it.")
        let unreleased = PrivacyLock.decide(LockSubject(people: PeopleFacts(checked: true, named: [.init(personID: UUID(), name: "Serenity", heard: true, seen: false, released: false)]))).line ?? ""
        XCTAssertEqual(unreleased, "Someone in it has no signed release on file, so only models on this Mac read it.")
        for line in [unreleased, talk.lockLine ?? "", PrivacyLock.leftOut, PrivacyLock.noRelease, PrivacyLock.noRecording, PrivacyLock.settingsLine] {
            XCTAssertFalse(line.contains("Serenity"))
            XCTAssertFalse(line.contains("\u{2014}") || line.contains("\u{2013}"))
        }
    }

    func testCardWords() {
        XCTAssertEqual(Format.cardDate(Fixtures.date(2026, 9, 13, 18, 25)), "Sun 13 Sep 2026, 6:25 pm")
        XCTAssertEqual(Format.fullDay(Fixtures.date(2026, 9, 6, 18)), "Sun 6 Sep 2026")
        XCTAssertEqual(Format.month(Fixtures.date(2026, 10, 11)), "October 2026")
        XCTAssertEqual(Format.spokenLength(947.78), "15 minutes 48 seconds")
        XCTAssertEqual(Format.spokenLength(3702.27), "1 hour 2 minutes")
        XCTAssertEqual(Format.spokenLength(61), "1 minute 1 second")
    }

    // MARK: Check 7: contrast

    /// Every text color measures 4.5 to 1 or more on every background it sits on, in light, dark and both
    /// Increase Contrast appearances (WCAG's formula). The system's own secondary label color, which the app
    /// no longer uses for text, is measured too, to show the test would catch it.
    func testEveryTextColorMeasuresFourPointFiveToOne() throws {
        let appearances: [NSAppearance.Name] = [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]
        var lines: [String] = []
        for name in appearances {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            for pair in AppColor.pairs {
                let ratio = AppColor.contrast(pair, in: appearance)
                lines.append(String(format: "%@  %@: %.2f", name.rawValue, pair.name, ratio))
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(pair.name) in \(name.rawValue) measures \(String(format: "%.2f", ratio)) to 1")
            }
        }
        print("Contrast, every text color:\n" + lines.joined(separator: "\n"))
        let light = try XCTUnwrap(NSAppearance(named: .aqua))
        let system = AppColor.Pair(name: "the system's secondary label on the window", text: .secondaryLabelColor, background: .windowBackgroundColor)
        XCTAssertLessThan(AppColor.contrast(system, in: light), 4.5, "the reason AppColor.secondaryText exists")
        let darkAccent = AppColor.Pair(name: "the accent fill as text", text: NSColor(named: "AccentColor") ?? .controlAccentColor, background: .windowBackgroundColor)
        XCTAssertLessThan(AppColor.contrast(darkAccent, in: try XCTUnwrap(NSAppearance(named: .darkAqua))), 4.5, "the reason AppColor.accentText exists (C7)")
    }

    /// `.appSecondary` resolves to the measured color, and to white on a selected, emphasized row (the
    /// sidebar's and the list's), where the system draws text white on the accent. The real window is measured
    /// too: `swift scripts/capture-window.swift --contrast <png> <box>` on a light capture (BUILD-LOG, v2 part M3a).
    /// (A bitmap drawn by a test window is not measured: its pixels come out lighter than the screen's,
    /// the window background included, so the numbers would not be the screen's.)
    func testAppSecondaryResolvesToTheMeasuredColor() {
        var plain = EnvironmentValues()
        plain.colorScheme = .light
        XCTAssertEqual(NSColor(AppSecondaryStyle().resolve(in: plain)), AppColor.secondaryTextNS)
        var selected = EnvironmentValues()
        selected.backgroundProminence = .increased
        let white = NSColor(AppSecondaryStyle().resolve(in: selected)).usingColorSpace(.sRGB)
        XCTAssertEqual(white?.redComponent ?? 0, 1, accuracy: 0.01)
        XCTAssertEqual(white?.alphaComponent ?? 0, 0.85, accuracy: 0.01)
    }
}
