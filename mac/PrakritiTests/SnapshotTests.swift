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

        for (index, item) in SidebarItem.allCases.enumerated() {
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
        XCTAssertEqual(written.count, SidebarItem.allCases.count * 2 + 14)
    }
}
