import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import Prakriti

/// Draws every screen, with fixture data, in light and dark, at the window's real size, to
/// screens/mac/<milestone>/ in the repo (gitignored). No Screen Recording permission is needed:
/// each window draws itself into a bitmap. Then a person LOOKS at the PNGs: rendering is not the
/// check, looking is.
///
///   cd ~/Code/prakriti/mac && make snapshots MILESTONE=m1
@MainActor
final class SnapshotTests: XCTestCase {
    private let appearances = SnapshotRenderer.appearances

    func testRenderEveryScreen() throws {
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let outputFolder = renderer.outputFolder
        var written: [String] = []

        // `make snapshots ONLY=recording` draws just the recording pages, for quick looks while
        // working on them; the full set is the milestone's check.
        let only = ProcessInfo.processInfo.environment["PRAKRITI_SNAPSHOT_ONLY"].flatMap { $0.isEmpty ? nil : $0 }
        // ONLY=help draws only the Help window (testRenderHelp), ONLY=welcome only the welcome (testRenderWelcome).
        if only == "help" || only == "welcome" { return }
        for (index, item) in SidebarItem.allCases.enumerated() where only == nil {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                model.selection = item
                let name = String(format: "%02d-%@-%@", index + 1, item.rawValue, scheme)
                try renderer.render(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }

        // The recording page, for the 13 Sep talk and for the silent 14 Sep class.
        for (slug, title) in [("recording-ready", "Talk with Gabriel"), ("recording-silent", "Class")] {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                let recordings = try model.context.fetch(FetchDescriptor<Recording>())
                let recording = try XCTUnwrap(recordings.first { $0.title == title && ($0.status == .readyForYourYes || $0.status == .needsADecision) })
                model.open(recording)
                let name = "08-\(slug)-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }

        // The 13 Sep talk with its own choices: the transcript turned off and its loudness at -19,
        // as milestone 4's acceptance made it.
        for (scheme, appearance) in appearances {
            let model = Fixtures.model()
            let recordings = try model.context.fetch(FetchDescriptor<Recording>())
            let recording = try XCTUnwrap(recordings.first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
            model.setOutput(.transcript, on: false, for: recording)
            recording.outputSettings.first { $0.kind == .podcastEpisode }?.loudnessTarget = -19
            model.open(recording)
            let name = "08-recording-own-choices-\(scheme)"
            try renderer.render(model: model, appearance: appearance, name: name)
            written.append(name)
        }

        // Milestone 5: the 13 Sep talk with a trim and a cut not made yet (Approve waits for Make
        // Again), marked as a class (Speakers not checked), and approved.
        for (slug, change) in [("edits-pending", { (model: AppModel, r: Recording) in
                                   model.setTrim(start: 10, end: nil, for: r)
                                   model.addCut(TimeRange(start: 300, end: 330), to: r) }),
                               ("class-speakers-not-checked", { (model: AppModel, r: Recording) in model.setKind(.lesson, for: r) }),
                               ("approved", { (_: AppModel, r: Recording) in
                                   r.status = .approved
                                   r.approvedAt = Fixtures.now
                                   r.statusReason = "Approved. Its files are in ~/Prakriti/Approved/2026-09-13 18-25-44. Nothing was uploaded or published." })] {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                let recordings = try model.context.fetch(FetchDescriptor<Recording>())
                let recording = try XCTUnwrap(recordings.first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
                change(model, recording)
                model.open(recording)
                let name = "08-recording-\(slug)-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }

        // Milestone 6: the 13 Sep talk marked as a class, its titles not written yet, with writing set
        // to the Claude API: the page says the privacy lock hands the writing to LM Studio.
        for (scheme, appearance) in appearances {
            let model = Fixtures.model()
            model.settings.provider[.writing] = .claudeAPI
            let recordings = try model.context.fetch(FetchDescriptor<Recording>())
            let recording = try XCTUnwrap(recordings.first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
            recording.writtenJSON = nil
            model.setKind(.lesson, for: recording)
            model.open(recording)
            let name = "08-recording-class-not-written-\(scheme)"
            try renderer.render(model: model, appearance: appearance, name: name)
            written.append(name)
        }

        // 11 Oct: the 13 Sep talk marked as a class with the podcast-ready episode switched on: Ready to
        // upload says why a class is never made ready, and nothing was made.
        for (scheme, appearance) in appearances {
            let model = Fixtures.model()
            let recordings = try model.context.fetch(FetchDescriptor<Recording>())
            let recording = try XCTUnwrap(recordings.first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
            model.setKind(.lesson, for: recording)
            model.setOutput(.podcastReady, on: true, for: recording)
            recording.podcastReadyJSON = nil
            recording.podcastReadyProblem = PodcastPackage.refusal(kind: .lesson)
            model.open(recording)
            let name = "08-recording-class-not-ready-\(scheme)"
            try renderer.render(model: model, appearance: appearance, name: name)
            written.append(name)
        }

        if only == "recording" {
            print("Snapshots written to \(outputFolder.path): \(written.count) recording pages")
            return
        }

        // 11 Oct: the Outputs screen with the show numbered, so its podcast-ready settings show the
        // numbering choice and the empty call to action (nothing is ever filled in for Ivan).
        for (scheme, appearance) in appearances {
            let model = Fixtures.model()
            model.selection = .outputs
            try XCTUnwrap(model.defaultSettings().first { $0.kind == .podcastReady }).numbering = .episodes
            let name = "04-outputs-numbered-\(scheme)"
            try renderer.render(model: model, appearance: appearance, name: name)
            written.append(name)
        }

        // Today with nothing waiting, and nothing set up.
        for (scheme, appearance) in appearances {
            let model = Fixtures.model(empty: true)
            model.selection = .today
            let name = "09-today-empty-\(scheme)"
            try renderer.render(model: model, appearance: appearance, name: name)
            written.append(name)
        }

        // Sources and Today right after the switch-over, before Ivan answers macOS's prompt for the
        // Documents folder: the studio folder cannot be read yet, and the app says so.
        for (scheme, appearance) in appearances {
            for item in [SidebarItem.sources, .today, .settings] {
                let model = Fixtures.model()
                Fixtures.waitingForPermission(model)
                model.selection = item
                let name = "10-\(item.rawValue)-waiting-for-permission-\(scheme)"
                try renderer.render(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: outputFolder.path).filter { $0.hasSuffix(".png") }
        print("Snapshots written to \(outputFolder.path): \(written.count) screens, \(files.count) pictures")
        XCTAssertEqual(written.count, SidebarItem.allCases.count * 2 + 26)
    }

    /// v2 part M2a: the Help window, open at every article this build shows, in light and dark, with a
    /// picture of each screenful of a long article ("-p2", "-end"), and a search's results. Every one is
    /// looked at: 17 pt body, nothing clipped (docs/v2/design-spec.md 5.8).
    ///
    ///   cd ~/Code/prakriti/mac && make snapshots MILESTONE=v2-m2a ONLY=help
    func testRenderHelp() throws {
        let only = ProcessInfo.processInfo.environment["PRAKRITI_SNAPSHOT_ONLY"].flatMap { $0.isEmpty ? nil : $0 }
        guard only == nil || only == "help" else { return }
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let library = Fixtures.model().help.library
        XCTAssertTrue(library.problems.isEmpty, "\(library.problems)")
        var written: [String] = []
        for (number, article) in library.visible.enumerated() {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                XCTAssertTrue(model.help.open(article.id))
                let name = String(format: "help-%02d-%@-%@", number, article.id, scheme)
                try renderer.renderHelp(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }
        for (scheme, appearance) in appearances {
            let model = Fixtures.model()
            model.help.searchText = "notifications"
            let name = "help-search-notifications-\(scheme)"
            try renderer.renderHelp(model: model, appearance: appearance, name: name)
            written.append(name)
        }
        print("Help snapshots written to \(renderer.outputFolder.path): \(written.count)")
        XCTAssertEqual(written.count, library.visible.count * 2 + 2)
    }

    /// v2 part M2b: the welcome window at each of its five panels, light and dark; the last panel with
    /// notifications off and not yet asked, and after Choose Folder added a folder or was refused; and,
    /// light only, the five panels as they will read once every part is built (for the look, and to
    /// see the v2 copy fits). Every panel must fit the 600 pt window without scrolling
    /// (docs/v2/design-spec.md 4.1), measured as it was drawn.
    ///
    ///   cd ~/Code/prakriti/mac && make snapshots MILESTONE=v2-m2b ONLY=welcome
    func testRenderWelcome() throws {
        let only = ProcessInfo.processInfo.environment["PRAKRITI_SNAPSHOT_ONLY"].flatMap { $0.isEmpty ? nil : $0 }
        guard only == nil || only == "welcome" else { return }
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        var written: [String] = []
        func draw(_ name: String, _ appearance: NSAppearance.Name, capabilities: Set<Capability> = Capabilities.built,
                  panel: Int, _ change: (AppModel) -> Void = { _ in }) throws {
            let model = Fixtures.model()
            model.welcome = WelcomeModel(capabilities: capabilities)
            model.welcome.panel = panel - 1
            change(model)
            try renderer.renderWelcome(model: model, appearance: appearance, name: name)
            let needed = try XCTUnwrap(model.welcome.needed[panel], "\(name): the panel was measured as it was drawn")
            XCTAssertLessThanOrEqual(needed, Double(WelcomeWindow.size.height), "\(name) needs \(needed) pt: it would not fit without scrolling")
            print("Welcome \(name): needs \(Int(needed.rounded())) pt of \(Int(WelcomeWindow.size.height))")
            written.append(name)
        }
        for panel in 1...5 {
            for (scheme, appearance) in appearances {
                try draw("welcome-\(panel)-\(scheme)", appearance, panel: panel)
            }
        }
        for (scheme, appearance) in appearances {
            try draw("welcome-5-notifications-off-\(scheme)", appearance, panel: 5) { $0.notifier.permission = .denied }
            try draw("welcome-5-notifications-not-asked-\(scheme)", appearance, panel: 5) { $0.notifier.permission = .waitingForAnswer }
            try draw("welcome-5-folder-added-\(scheme)", appearance, panel: 5) { $0.welcome.folderChoice = .added(name: "Studio B") }
            try draw("welcome-5-folder-refused-\(scheme)", appearance, panel: 5) { model in
                // The development copy's refusal, word for word (the live copy owns the studio folder).
                let development = AppPaths(mode: .development)
                model.welcome.folderChoice = .refused(name: "Studio Recordings",
                                                      reason: development.refusal(for: development.studioRecordings, isFolder: true) ?? "")
            }
        }
        for panel in 1...5 {
            try draw("welcome-every-part-built-\(panel)-light", .aqua, capabilities: Capabilities.all, panel: panel)
        }
        print("Welcome snapshots written to \(renderer.outputFolder.path): \(written.count)")
        XCTAssertEqual(written.count, 10 + 8 + 5)
    }
}
