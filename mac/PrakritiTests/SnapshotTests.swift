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
        // working on them; ONLY=library just the main window and Settings (v2 part M3a); the full set is
        // the milestone's check.
        let only = ProcessInfo.processInfo.environment["PRAKRITI_SNAPSHOT_ONLY"].flatMap { $0.isEmpty ? nil : $0 }
        // ONLY=help draws only the Help window (testRenderHelp), ONLY=welcome only the welcome (testRenderWelcome).
        if only == "help" || only == "welcome" { return }

        func draw(_ name: String, empty: Bool = false, _ change: (AppModel) throws -> Void) throws {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model(empty: empty)
                try change(model)
                try renderer.render(model: model, appearance: appearance, name: "\(name)-\(scheme)")
                written.append("\(name)-\(scheme)")
            }
        }
        func talk13(_ model: AppModel) throws -> Recording {
            try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes })
        }

        if only == nil || only == "library" {
            // v2 part M3a: every smart group, filled and empty, as a grid; nothing selected.
            for (index, group) in SmartGroup.allCases.enumerated() {
                try draw(String(format: "%02d-%@", index + 1, group.rawValue)) { $0.selection = .group(group) }
                try draw(String(format: "%02d-%@-empty", index + 1, group.rawValue), empty: true) { $0.selection = .group(group) }
            }
            // All Recordings as a list, one recording selected (its row and the inspector).
            try draw("05-all-recordings-list") { model in
                model.selection = .group(.all)
                model.browserMode = .list
                model.selectedRecordings = [try talk13(model).id]
            }
            // A folder under Sources: its recordings, its settings in the inspector.
            try draw("06-source-studio") { model in
                model.go(to: .sources)
            }
            // The inspector's three tabs for the 13 Sep talk, and the Outputs tab for a recording that needs
            // a decision, one being made and one approved.
            for tab in InspectorTab.allCases {
                try draw("07-inspector-\(tab.rawValue)") { model in
                    model.selection = .group(.needsYou)
                    model.selectedRecordings = [try talk13(model).id]
                    model.inspectorTab = tab
                }
            }
            for status in [RecordingStatus.needsADecision, .working] {
                try draw("07-inspector-outputs-\(status.rawValue)") { model in
                    let recording = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.status == status })
                    model.selection = .group(.all)
                    model.selectedRecordings = [recording.id]
                }
            }
            try draw("07-inspector-outputs-approved") { model in
                let talk = try talk13(model)
                talk.status = .approved
                talk.approvedAt = Fixtures.now
                talk.statusReason = "Approved. Its files are in ~/Prakriti/Approved/2026-09-13 18-25-44. Nothing was uploaded or published."
                model.selection = .group(.ready)
                model.selectedRecordings = [talk.id]
            }
            // Two claims of the accuracy checklist ticked.
            try draw("07-inspector-checks-ticked") { model in
                let talk = try talk13(model)
                for claim in (talk.written?.checklist ?? []).prefix(2) { model.setClaim(claim.claim, checked: true, for: talk) }
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .checks
            }
            // Several selected.
            try draw("07-inspector-several") { model in
                model.selection = .group(.all)
                model.selectedRecordings = Set(try model.context.fetch(FetchDescriptor<Recording>()).prefix(3).map(\.id))
            }
            // A search over what was said: the 13 Sep talk's transcript (in its output folder) names the lineage.
            try draw("08-search-said") { model in
                model.selection = .group(.all)
                model.search = LibrarySearch(text: "Krishnamacharya", scopes: [])
            }
            try draw("08-search-nothing") { model in
                model.search = LibrarySearch(text: "zqxj", scopes: [.title])
            }
            // A filter that leaves nothing.
            try draw("08-filter-nothing") { model in
                model.selection = .group(.ready)
                model.kindFilter = [.conversation]
            }
            // Right after the switch-over, before Ivan answers macOS's prompt for the Documents folder: the
            // studio folder cannot be read yet, and Needs You and the folder's inspector say so.
            try draw("09-needs-you-waiting-for-permission") { model in
                Fixtures.waitingForPermission(model)
                model.selection = .group(.needsYou)
            }
            try draw("09-source-waiting-for-permission") { model in
                Fixtures.waitingForPermission(model)
                model.go(to: .sources)
            }

            // The Settings window, each pane; Outputs with the show numbered (its podcast-ready settings show
            // the numbering choice and the empty call to action); General with notifications not asked.
            for (index, pane) in SettingsPane.allCases.enumerated() {
                for (scheme, appearance) in appearances {
                    let name = String(format: "10-settings-%02d-%@-%@", index + 1, pane.rawValue, scheme)
                    try renderer.renderSettings(model: Fixtures.model(), pane: pane, appearance: appearance, name: name)
                    written.append(name)
                }
            }
            for (scheme, appearance) in appearances {
                let numbered = Fixtures.model()
                try XCTUnwrap(numbered.defaultSettings().first { $0.kind == .podcastReady }).numbering = .episodes
                try renderer.renderSettings(model: numbered, pane: .outputs, appearance: appearance, name: "10-settings-outputs-numbered-\(scheme)")
                let notAsked = Fixtures.model()
                Fixtures.waitingForPermission(notAsked)
                try renderer.renderSettings(model: notAsked, pane: .general, appearance: appearance, name: "10-settings-general-not-asked-\(scheme)")
                try renderer.renderActivity(model: Fixtures.model(), appearance: appearance, name: "11-activity-\(scheme)")
                written += ["10-settings-outputs-numbered-\(scheme)", "10-settings-general-not-asked-\(scheme)", "11-activity-\(scheme)"]
            }
        }
        if only == "library" {
            print("Snapshots written to \(outputFolder.path): \(written.count) library and Settings pictures")
            XCTAssertEqual(written.count, 4 * 2 * 2 + 2 + 2 + 3 * 2 + 3 * 2 + 2 + 2 + 2 * 3 + 2 * 2 + 5 * 2 + 3 * 2)
            return
        }

        // v1's recording page, opened from the browser (until the Viewer, part M3b): the 13 Sep talk and the
        // sample class with no sound.
        for (slug, title) in [("recording-ready", "Talk with Gabriel"), ("recording-silent", "Class")] {
            try draw("20-\(slug)") { model in
                let recording = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>())
                    .first { $0.title == title && ($0.status == .readyForYourYes || $0.status == .needsADecision) })
                model.open(recording)
            }
        }

        // The 13 Sep talk with its own choices: the transcript turned off and its loudness at -19,
        // as milestone 4's acceptance made it.
        try draw("20-recording-own-choices") { model in
            let recording = try talk13(model)
            model.setOutput(.transcript, on: false, for: recording)
            recording.outputSettings.first { $0.kind == .podcastEpisode }?.loudnessTarget = -19
            model.open(recording)
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
            try draw("20-recording-\(slug)") { model in
                let recording = try talk13(model)
                change(model, recording)
                model.open(recording)
            }
        }

        // Milestone 6: the 13 Sep talk marked as a class, its titles not written yet, with writing set
        // to the Claude API: the page says the privacy lock hands the writing to LM Studio.
        try draw("20-recording-class-not-written") { model in
            model.settings.provider[.writing] = .claudeAPI
            let recording = try talk13(model)
            recording.writtenJSON = nil
            model.setKind(.lesson, for: recording)
            model.open(recording)
        }

        // 11 Oct: the 13 Sep talk marked as a class with the podcast-ready episode switched on: Ready to
        // upload says why a class is never made ready, and nothing was made.
        try draw("20-recording-class-not-ready") { model in
            let recording = try talk13(model)
            model.setKind(.lesson, for: recording)
            model.setOutput(.podcastReady, on: true, for: recording)
            recording.podcastReadyJSON = nil
            recording.podcastReadyProblem = PodcastPackage.refusal(kind: .lesson)
            model.open(recording)
        }

        if only == "recording" {
            print("Snapshots written to \(outputFolder.path): \(written.count) recording pages")
            return
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: outputFolder.path).filter { $0.hasSuffix(".png") }
        print("Snapshots written to \(outputFolder.path): \(written.count) screens, \(files.count) pictures")
        XCTAssertEqual(written.count, 4 * 2 * 2 + 2 + 2 + 3 * 2 + 3 * 2 + 2 + 2 + 2 * 3 + 2 * 2 + 5 * 2 + 3 * 2 + 2 * 2 + 2 + 3 * 2 + 2 + 2)
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
