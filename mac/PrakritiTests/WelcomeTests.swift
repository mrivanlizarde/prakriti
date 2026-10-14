import AppKit
import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import Prakriti

/// The welcome window (v2 part M2b, docs/v2/PLAN.md M2): its words, which rows this build shows, the
/// first-launch rule, the notification button and Choose Folder. What it looks like is checked by the
/// snapshots (`SnapshotTests.testRenderWelcome`) and by the real window (`make accept-help`).
@MainActor
final class WelcomeTests: XCTestCase {
    private var built: [VisibleWelcomePanel] { WelcomeContent.visiblePanels(with: Capabilities.built) }
    private var everything: [VisibleWelcomePanel] { WelcomeContent.visiblePanels(with: Capabilities.all) }

    /// The capabilities in the order the plan builds them (docs/v2/PLAN.md section 1), each part adding
    /// its own: every stage of the build must show a whole welcome.
    static let buildOrder: [Capability] = [.help, .welcome, .viewer, .progress, .captureCheck, .cloudProviders, .faces, .people,
                                           .gallery, .recognition, .video, .style, .timelines, .shorts, .thumbnails, .merge]

    private func freshModel(mode: AppMode = .development) -> AppModel {
        AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: mode), settings: .ephemeral(),
                 log: AppLog(directory: nil), now: { Fixtures.now })
    }

    // MARK: Check 1: the welcome's strings keep the copy rules; every symbol exists

    func testEveryWelcomeStringKeepsTheCopyRules() throws {
        var strings = WelcomeContent.everyString
        // The words the window itself writes: buttons, the position, the status lines.
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Prakriti/Views/Welcome", directoryHint: .isDirectory)
        for name in ["WelcomeWindow.swift", "WelcomeModel.swift", "WelcomeContent.swift"] {
            let source = try String(contentsOf: folder.appending(path: name), encoding: .utf8)
            for (number, line) in source.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                for match in line.matches(of: /"((?:[^"\\]|\\.)*)"/) {
                    strings.append(("\(name) line \(number + 1)", String(match.1)))
                }
            }
        }
        XCTAssertGreaterThan(strings.count, 80, "the test reads the welcome's words")
        for (place, text) in strings {
            XCTAssertFalse(text.contains("\u{2014}"), "em dash in \(place)")
            XCTAssertFalse(text.contains("\u{2013}"), "en dash in \(place)")
            XCTAssertFalse(text.contains("--"), "a double hyphen in \(place)")
            let words = Set(text.lowercased().split { !($0.isLetter || $0.isNumber || $0 == "'") }.map(String.init))
            XCTAssertFalse(words.contains("we") || words.contains("we're") || words.contains("we've") || words.contains("our"), "\"we\" in \(place): \(text)")
            XCTAssertFalse(words.contains("processing"), "\"Processing\" in \(place)")
            XCTAssertFalse(words.contains("tap") || words.contains("taps") || words.contains("tapping"), "\"tap\" in \(place): on a Mac you click")
        }
    }

    func testEverySymbolTheWelcomeUsesExists() {
        var symbols = WelcomeContent.panels.flatMap { [$0.symbol] + $0.rows.map(\.symbol) }
        symbols += (1...6).map { "\($0).circle" }
        symbols += ["checkmark.circle.fill", "exclamationmark.triangle"]
        for symbol in Set(symbols) {
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "SF Symbol \(symbol) does not exist on this Mac")
        }
    }

    // MARK: Check 2: only what is built is visible; with everything built, every panel shows

    /// Every word a reader of the welcome can see: titles, lines, rows and the Help links' titles.
    private func visibleText(_ panels: [VisibleWelcomePanel], capabilities: Set<Capability>) -> [(where: String, text: String)] {
        let library = HelpLibrary.bundled(capabilities: capabilities)
        var out: [(String, String)] = []
        for panel in panels {
            out.append(("\(panel.id) title", panel.title))
            out.append(("\(panel.id) line", panel.line))
            for row in panel.rows {
                out.append(("\(panel.id) \(row.id)", [row.headline, row.sentence].compactMap { $0 }.joined(separator: " ")))
            }
            if let id = panel.helpArticle {
                out.append(("\(panel.id) link", library.visibleArticle(id: id).map { "More in Help: \($0.title)" } ?? ""))
            }
        }
        return out
    }

    private func unbuiltNamesFound(in text: [(where: String, text: String)], built: Set<Capability>) -> [String] {
        var found: [String] = []
        for (place, line) in text {
            for name in HelpTests.unbuiltNames where !built.contains(name.capability) {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: name.phrase) + "\\b"
                let options: NSRegularExpression.Options = name.caseSensitive ? [] : [.caseInsensitive]
                guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { continue }
                if regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                    found.append("\(place): \"\(name.phrase)\" (\(name.capability.rawValue)) in \"\(line)\"")
                }
            }
        }
        return found
    }

    func testOnlyWhatIsBuiltIsVisibleInThePanels() {
        XCTAssertEqual(Capabilities.built, [.help, .welcome, .viewer, .progress, .captureCheck, .cloudProviders, .faces, .voices, .choices, .hiding, .gallery, .recognition, .editPlan, .renderedVideo, .video],
                       "v2 part M2b adds the welcome to Help, M3b the Viewer, M4a progress, M4b the capture check, M5b the cloud providers, M6a faces, M6b voices, M6c choices, M6d hiding, M7a the People gallery, M7b recognition, M8a the edit plan, M8b the rendered MP4, M8c the video in the Viewer")
        XCTAssertEqual(unbuiltNamesFound(in: visibleText(built, capabilities: Capabilities.built), built: Capabilities.built), [])
        // At M2b, panel 1 lists finding recordings, the podcast and "nothing is posted without you".
        XCTAssertEqual(built.map(\.id), ["welcome", "record", "outputs", "privacy", "start"])
        XCTAssertEqual(built[0].rows.map(\.id), ["finds", "podcast", "yours"])
        XCTAssertEqual(built.map(\.rows.count), [3, 6, 4, 4, 4], "M5b adds Choose where models write to Get Started; M6c the People step to How Outputs Work; M7a the People row to Privacy")
        XCTAssertEqual(built[4].rows.map(\.id), ["folder", "notifications", "models", "help"])
        // M4a built `progress`, so step 1 of How Outputs Work reads its v2 sentence; M4b built `captureCheck`, so the
        // recording settings row names Hybrid MOV; M8c built `video`, so step 2 says to watch the edit in the Viewer. No other v2
        // sentence yet.
        XCTAssertEqual(built.flatMap(\.rows).filter { $0.id.hasSuffix("-v2") }.map(\.id), ["settings-v2", "found-v2", "review-v2"], "no v2 sentence before its part")

        // The check finds what it is meant to find: with every row shown, the panels name features that
        // are not built, and it must say so.
        XCTAssertFalse(unbuiltNamesFound(in: visibleText(everything, capabilities: Capabilities.all), built: Capabilities.built).isEmpty,
                       "the check would have caught an unbuilt feature")
    }

    func testWithEveryCapabilityEveryPanelIsVisible() {
        XCTAssertEqual(everything.map(\.id), ["welcome", "record", "outputs", "privacy", "start"])
        for panel in everything {
            XCTAssertTrue((3...6).contains(panel.rows.count), "\(panel.id) has \(panel.rows.count) rows")
        }
        XCTAssertEqual(everything[2].rows.count, 5, "five steps once every part is built")
        XCTAssertEqual(everything[2].line, "From a raw recording to files ready to upload, in five steps.")
        XCTAssertFalse(everything.flatMap(\.rows).contains { ["podcast", "yours", "approve-talks", "notices", "cloud"].contains($0.id) },
                       "today's sentences give way once their parts are built")
    }

    /// At every stage of the build, each sentence that one part replaces shows exactly once (today's or
    /// the v2 one, never both and never neither), every panel shows, and its line counts what is there.
    func testEveryStageOfTheBuildShowsAWholeWelcome() {
        for count in 2...Self.buildOrder.count {
            let capabilities = Set(Self.buildOrder.prefix(count))
            let stage = Self.buildOrder[count - 1].rawValue
            let panels = WelcomeContent.visiblePanels(with: capabilities)
            XCTAssertEqual(panels.count, 5, "at \(stage)")
            for (panel, source) in zip(panels, WelcomeContent.panels) {
                XCTAssertTrue((2...6).contains(panel.rows.count), "\(panel.id) at \(stage): \(panel.rows.count) rows")
                XCTAssertFalse(panel.line.contains("{count}"))
                for row in source.rows where !row.id.hasSuffix("-v2") {
                    guard let twin = source.rows.first(where: { $0.id == row.id + "-v2" }) else { continue }
                    let shown = [row, twin].filter { $0.isVisible(with: capabilities) }.count
                    XCTAssertEqual(shown, 1, "\(panel.id) \(row.id) at \(stage): \(shown) of today's and the v2 sentence shown")
                }
            }
        }
    }

    func testTheLineCountsTheRowsItShows() {
        XCTAssertEqual(built[1].line, "Prakriti does its best work with a clean recording. These six things make the biggest difference.")
        XCTAssertEqual(built[2].line, "From a raw recording to finished files, in four steps.", "M6c adds choosing who is in the episode")
        XCTAssertEqual(built[2].rows.map { built[2].symbol(for: $0) }, ["1.circle", "2.circle", "3.circle", "4.circle"], "steps are numbered as shown")
        XCTAssertEqual(WelcomeContent.numberWord(6), "six")
    }

    func testEveryHelpLinkOpensAVisibleArticle() {
        let library = HelpLibrary.bundled(capabilities: Capabilities.built)
        for panel in built {
            guard let id = panel.helpArticle else { continue }
            XCTAssertNotNil(library.visibleArticle(id: id), "\(panel.id) links to \(id), which this build hides")
        }
        XCTAssertEqual(built.compactMap(\.helpArticle), ["capture-the-best-video", "people-and-privacy"])
    }

    // MARK: Check 5, the rule behind it: the first launch made by hand, once

    func testTheWelcomeShowsAtTheFirstLaunchMadeByHandOnly() {
        // First launch: never seen, so it is due; it appears before launching has finished, and counts
        // as seen once the app knows it was opened by hand.
        let model = freshModel()
        XCTAssertEqual(model.settings.welcomeSeenVersion, 0)
        XCTAssertTrue(model.welcomeIsDue)
        model.welcome.presentsAtLaunch = model.welcomeIsDue
        XCTAssertTrue(model.welcomeAppeared(), "it stays open")
        XCTAssertTrue(model.welcomeIsDue, "not counted until the launch is known")
        model.launchFinished(atLogin: false)
        XCTAssertEqual(model.settings.welcomeSeenVersion, WelcomeContent.version)
        XCTAssertFalse(model.welcomeIsDue, "the next launch does not show it")

        // Appearing after launching has finished, at a launch by hand: seen at once.
        let late = freshModel()
        late.welcome.presentsAtLaunch = true
        late.launchFinished(atLogin: false)
        XCTAssertTrue(late.welcomeAppeared())
        XCTAssertFalse(late.welcomeIsDue)
    }

    func testAtLoginTheWelcomeWaitsForALaunchByHand() {
        // macOS opened Prakriti at login: the app closes every window it opens then, so the welcome is
        // neither kept open nor counted as seen.
        let early = freshModel()
        early.welcome.presentsAtLaunch = true
        XCTAssertTrue(early.welcomeAppeared())
        early.launchFinished(atLogin: true)
        XCTAssertTrue(early.welcomeIsDue, "closed with the other windows at login, it is still due")

        let late = freshModel()
        late.welcome.presentsAtLaunch = true
        late.launchFinished(atLogin: true)
        XCTAssertFalse(late.welcomeAppeared(), "appearing after a login launch, it closes again at once")
        XCTAssertTrue(late.welcomeIsDue)
    }

    func testHelpWelcomeToPrakritiOpensItAtTheFirstPanel() {
        let model = freshModel()
        model.settings.welcomeSeenVersion = WelcomeContent.version
        model.launchFinished(atLogin: true)
        model.welcome.panel = 3
        model.prepareWelcomeFromMenu()
        XCTAssertEqual(model.welcome.panel, 0)
        XCTAssertTrue(model.welcomeAppeared(), "asked for from the Help menu, it opens at any launch")
        XCTAssertFalse(model.welcome.openedFromMenu)
    }

    func testBackContinueAndThePosition() {
        let welcome = WelcomeModel()
        XCTAssertEqual(welcome.position, "1 of 5")
        XCTAssertTrue(welcome.isFirst)
        welcome.goBack()
        XCTAssertEqual(welcome.panel, 0, "Back does nothing on the first panel")
        for _ in 0..<10 { welcome.goForward() }
        XCTAssertEqual(welcome.panel, 4, "Continue stops at the last panel")
        XCTAssertTrue(welcome.isLast)
        XCTAssertEqual(welcome.position, "5 of 5")
        welcome.panel = 9
        XCTAssertEqual(welcome.panel, 4, "a panel past the end is the last")
        welcome.panel = -2
        XCTAssertEqual(welcome.panel, 0)
    }

    // MARK: The notification button

    @MainActor
    private final class FakeAuthority {
        var status: UNAuthorizationStatus
        var answer: Bool
        var requests = 0
        var settingsOpened = 0
        init(status: UNAuthorizationStatus, answer: Bool = true) {
            self.status = status
            self.answer = answer
        }
    }

    private func notifier(_ fake: FakeAuthority) -> AppModel {
        let model = freshModel()
        model.notifier.authority = NotificationAuthority(
            status: { fake.status },
            request: { fake.requests += 1; return fake.answer },
            openSettings: { fake.settingsOpened += 1 })
        return model
    }

    func testTurnOnNotificationsAsksOnlyWhenNeverAsked() async {
        let fresh = FakeAuthority(status: .notDetermined, answer: true)
        let model = notifier(fresh)
        await model.notifier.turnOn()
        XCTAssertEqual(fresh.requests, 1, "never asked: macOS is asked now")
        XCTAssertEqual(fresh.settingsOpened, 0)
        XCTAssertEqual(model.notifier.permission, .allowed)

        let declined = FakeAuthority(status: .notDetermined, answer: false)
        let second = notifier(declined)
        await second.notifier.turnOn()
        XCTAssertEqual(second.notifier.permission, .denied, "Don't Allow: the row then offers System Settings")
    }

    func testTurnOnNotificationsOpensSystemSettingsWhenTurnedOff() async {
        let off = FakeAuthority(status: .denied)
        let model = notifier(off)
        await model.notifier.turnOn()
        XCTAssertEqual(off.requests, 0, "a second request shows nothing once macOS has a no, so it is never sent")
        XCTAssertEqual(off.settingsOpened, 1, "System Settings opens at Prakriti's Notifications page")
        XCTAssertEqual(model.notifier.permission, .denied)

        let on = FakeAuthority(status: .authorized)
        let allowed = notifier(on)
        await allowed.notifier.turnOn()
        XCTAssertEqual(on.requests + on.settingsOpened, 0, "already on: nothing to do")
        XCTAssertEqual(allowed.notifier.permission, .allowed)
    }

    // MARK: Choose Folder

    func testChooseFolderWatchesItOrSaysWhyNot() throws {
        let model = freshModel()
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: model.paths, now: Fixtures.now)
        let folder = URL(fileURLWithPath: "/tmp/Welcome Folder", isDirectory: true)
        XCTAssertEqual(model.watchFolderFromWelcome(at: folder), .added(name: "Welcome Folder"))
        let added = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Source>()).first { $0.name == "Welcome Folder" })
        XCTAssertEqual(added.mode, .askFirst, "a folder chosen in the welcome asks first, like any new folder")
        XCTAssertEqual(model.welcome.folderChoice, .added(name: "Welcome Folder"))
        XCTAssertEqual(model.watchFolderFromWelcome(at: folder), .alreadyWatched(name: "Welcome Folder"))

        // Development refuses the studio folder, said on the row, not in an alert behind the welcome.
        let studio = model.watchFolderFromWelcome(at: model.paths.studioRecordings)
        guard case .refused(let name, let reason) = studio else { return XCTFail("\(studio)") }
        XCTAssertEqual(name, "Studio Recordings")
        XCTAssertFalse(reason.isEmpty)
        XCTAssertNil(model.notice, "no alert: the welcome says it on the row")
        XCTAssertEqual(try model.context.fetch(FetchDescriptor<Source>()).count, 2, "the dev drop folder and the one chosen")
    }
}
