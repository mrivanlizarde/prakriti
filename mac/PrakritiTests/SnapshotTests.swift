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

        // `make snapshots ONLY=recording` draws just the Viewer (v1's recording page until v2 part M3b), for
        // quick looks while working on it; ONLY=library just the main window and Settings (v2 part M3a); the full set is
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
            // The Checks tab's Capture section (v2 part M4b): a clean 4K recording with a track per microphone, the
            // silent class (its track fails), a test under 60 s (its check is kept), and a recording found before
            // the check existed (Check Capture).
            try draw("07-inspector-checks-capture-clean") { model in
                let talk = try talk13(model)
                talk.captureJSON = Fixtures.captureClean(at: Fixtures.date(2026, 10, 12, 9, 30)).json()
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .checks
            }
            for (name, title, status) in [("silent", "Class", RecordingStatus.needsADecision), ("test", "", .skipped)] {
                try draw("07-inspector-checks-capture-\(name)") { model in
                    let recording = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.title == title && $0.status == status })
                    model.selection = .group(.all)
                    model.selectedRecordings = [recording.id]
                    model.inspectorTab = .checks
                }
            }
            try draw("07-inspector-checks-capture-none") { model in
                let talk = try talk13(model)
                talk.captureJSON = nil
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .checks
            }
            // The People tab (v2 part M6a): two faces at once (the two-people fixture's answer), a recording found
            // before faces were looked for (Look for Faces), and one with no face in its picture. Every face circle is
            // a test pattern: sample data never draws anyone's face.
            try draw("07-inspector-people-two") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .people
            }
            try draw("07-inspector-people-none") { model in
                let talk = try talk13(model)
                talk.facesJSON = nil
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .people
            }
            try draw("07-inspector-people-nofaces") { model in
                let talk = try talk13(model)
                var found = FacesFound(checkedAt: Fixtures.date(2026, 10, 12, 21, 40), duration: 947.78)
                found.samples = 1896
                talk.facesJSON = found.json()
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .people
            }
            // Voices and names (v2 part M6b): the two-people-tracks answer with Gabriel teaching (the second voice on
            // track 3 has no face, the corner face no name), one voice with nobody named in Settings, and the Info tab's
            // Who is teaching.
            try draw("07-inspector-people-voices") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.date(2026, 10, 13, 1, 10)), to: talk)
                model.setTeacher(try XCTUnwrap(model.addPerson(named: "Gabriel")), for: talk)
                _ = model.addPerson(named: "Serenity")
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .people
            }
            try draw("07-inspector-people-voices-unnamed") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesOnePerson(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.applyVoices(Fixtures.voicesOneTeacher(at: Fixtures.date(2026, 10, 13, 1, 10)), to: talk)
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .people
            }
            // Choices applied to audio (v2 part M6c): the two-people-tracks answer with Gabriel teaching and Voice 2 left
            // out, made (two cuts, the audio output check passed) with two names said aloud, one muted and one not decided;
            // and the same with a name muted since the make (not in the episode yet).
            func choices(_ model: AppModel, pending: Bool) throws {
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.date(2026, 10, 13, 1, 10)), to: talk)
                model.setTeacher(try XCTUnwrap(model.addPerson(named: "Gabriel")), for: talk)
                model.setChoice(.leaveOut, for: .voice(2), in: talk)
                let names = [NameMoment(start: 312.4, end: 312.9, text: "Maria"), NameMoment(start: 640.2, end: 640.7, text: "Maria"),
                             NameMoment(start: 702.0, end: 702.6, text: "Arjun")]
                talk.namesSaidJSON = NamesSaid(checkedAt: Fixtures.date(2026, 10, 13, 1, 10), moments: names).json()
                model.decideName(.mute, moments: Array(names.prefix(2)), in: talk)
                var check = AudioCheck(checkedAt: Fixtures.date(2026, 10, 13, 1, 12), files: ["episode.mp3"])
                check.seconds = 21.4
                let segments = [VoiceSegment(start: 30.1, end: 40.0, voice: 2), VoiceSegment(start: 41.0, end: 49.9, voice: 2),
                                VoiceSegment(start: 0.3, end: 89.9, voice: 1)]
                model.choiceFigures.seed(talk, segments: segments, words: nil)
                let plan = LeaveOut.plan(segments: segments, leftOut: [2], words: nil, mutes: Array(names.prefix(2)), duration: 947.78)
                talk.peopleAppliedJSON = PeopleApplied(madeAt: Fixtures.date(2026, 10, 13, 1, 12), signature: talk.podcastSignature, leaveOut: plan, check: check).json()
                // Muting the last name changes the podcast, so it is not in the episode yet. (Leaving out the corner face
                // would not: it is never heard, so the podcast stays as made.)
                if pending { model.decideName(.mute, moments: [names[2]], in: talk) }
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .people
            }
            try draw("07-inspector-people-choices") { model in try choices(model, pending: false) }
            try draw("07-inspector-people-choices-pending") { model in try choices(model, pending: true) }
            try draw("07-inspector-info-teacher") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesOnePerson(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.applyVoices(Fixtures.voicesOneTeacher(at: Fixtures.date(2026, 10, 13, 1, 10)), to: talk)
                model.setTeacher(try XCTUnwrap(model.addPerson(named: "Gabriel")), for: talk)
                model.selection = .group(.needsYou)
                model.selectedRecordings = [talk.id]
                model.inspectorTab = .info
            }
            try draw("05-all-recordings-people-named") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.date(2026, 10, 13, 1, 10)), to: talk)
                model.setTeacher(try XCTUnwrap(model.addPerson(named: "Gabriel")), for: talk)
                model.selection = .group(.all)
            }
            // The cards and the list with their people lines, and the Other People Appear filter.
            try draw("05-all-recordings-people") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.selection = .group(.all)
            }
            try draw("05-all-recordings-list-people") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.selection = .group(.all)
                model.browserMode = .list
            }
            try draw("05-all-recordings-filter-other-people") { model in
                let talk = try talk13(model)
                talk.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.date(2026, 10, 12, 21, 40)).json()
                model.selection = .group(.all)
                model.otherPeopleFilter = true
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
                written += ["10-settings-outputs-numbered-\(scheme)", "10-settings-general-not-asked-\(scheme)"]
                // v2 part M5a: the hardware check on a smaller Mac without Apple Intelligence.
                let small = Fixtures.model()
                small.hardware = HardwareProfile(chip: "Apple M2", memoryBytes: 16 * 1_073_741_824,
                                                 appleIntelligenceUnavailable: "Apple Intelligence is turned off in System Settings, so Apple's on-device model cannot be used.")
                try renderer.renderSettings(model: small, pane: .models, appearance: appearance, name: "10-settings-models-16gb-\(scheme)")
                written.append("10-settings-models-16gb-\(scheme)")
                // v2 part M6b: People You Name, with Gabriel allowed to cloud models and Serenity not.
                let named = Fixtures.model()
                named.setCloudConsent(true, for: try XCTUnwrap(named.addPerson(named: "Gabriel")))
                _ = named.addPerson(named: "Serenity")
                try renderer.renderSettings(model: named, pane: .privacy, appearance: appearance, name: "10-settings-privacy-people-\(scheme)", height: 900)
                written.append("10-settings-privacy-people-\(scheme)")
                // v2 part M5b: the whole Models pane with the cloud keys absent, saved (lists read) and refused.
                let keyStates: [(String, (AppModel) -> Void)] = [
                    ("keys-absent", { _ in }),
                    ("keys-saved", { model in
                        model.keysAdded = [.claudeAPI, .openAI]
                        model.cloudModelLists[.claudeAPI] = CloudModelList(state: .loaded, models: [
                            CloudModel(id: "claude-sonnet-5-5", name: "Claude Sonnet 5.5"), CloudModel(id: "claude-opus-5-5", name: "Claude Opus 5.5"),
                            CloudModel(id: "claude-haiku-5-5", name: "Claude Haiku 5.5")])
                        model.cloudModelLists[.openAI] = CloudModelList(state: .loaded, models: [CloudModel(id: "gpt-5.6", name: "gpt-5.6"), CloudModel(id: "gpt-5.5", name: "gpt-5.5")])
                        model.settings.openAIModel = "gpt-5.6"
                        model.settings.provider[.writing] = .claudeAPI
                        let tested = Fixtures.now.addingTimeInterval(-300)
                        model.providerChecks[.claudeAPI] = ProviderCheck(state: .ok, line: "claude-sonnet-5-5 answered in 2 s, cost less than one cent. The key in the Keychain works.", at: tested)
                        model.providerChecks[.openAI] = ProviderCheck(state: .ok, line: "gpt-5.6 answered in 3 s. The key in the Keychain works.", at: tested)
                    }),
                    ("keys-rejected", { model in
                        model.keysAdded = [.claudeAPI, .openAI]
                        model.keysRejected = [.claudeAPI, .openAI]
                        model.cloudModelLists[.claudeAPI] = CloudModelList(state: .rejected, line: "Anthropic did not accept this key. Check it and save it again.")
                        model.cloudModelLists[.openAI] = CloudModelList(state: .rejected, line: "OpenAI did not accept this key. Check it and save it again.")
                        let tested = Fixtures.now.addingTimeInterval(-300)
                        model.providerChecks[.claudeAPI] = ProviderCheck(state: .notSetUp, line: "Anthropic did not accept this key. Check it and save it again.", at: tested, keyRejected: true)
                        model.providerChecks[.openAI] = ProviderCheck(state: .notSetUp, line: "OpenAI did not accept this key. Check it and save it again.", at: tested, keyRejected: true)
                    }),
                ]
                for (state, prepare) in keyStates {
                    let keys = Fixtures.model()
                    prepare(keys)
                    try renderer.renderSettings(model: keys, pane: .models, appearance: appearance, name: "10-settings-models-\(state)-\(scheme)", height: 2_600)
                    written.append("10-settings-models-\(state)-\(scheme)")
                }
                // The Activity window (v2 part M4a): Now with a make running and one waiting, the same paused, Now
                // empty, Finished and Log.
                let activities: [(String, ActivityTab, (AppModel) -> Void)] = [
                    ("11-activity-now", .now, { Fixtures.showProgress($0) }),
                    ("11-activity-now-paused", .now, { model in
                        Fixtures.showProgress(model, paused: true)
                        if let clip = try? model.context.fetch(FetchDescriptor<Recording>()).first(where: { $0.fileName == "2026-09-13 clip 90s.mp4" }) {
                            model.runner.showSample(job: model.runner.currentJob, waiting: [clip.id], held: [clip.id])
                        }
                    }),
                    // Two waiting: the second in line shows Make Next beside Pause and Stop (M4a fix: no picture showed it).
                    ("11-activity-now-line", .now, { model in
                        Fixtures.showProgress(model)
                        let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
                        let clip = all.first { $0.fileName == "2026-09-13 clip 90s.mp4" }
                        let other = all.first { $0.status != .working && $0.id != clip?.id }
                        model.runner.showSample(job: model.runner.currentJob, waiting: [clip, other].compactMap { $0?.id })
                    }),
                    ("11-activity-now-empty", .now, { _ in }),
                    ("11-activity-finished", .finished, { _ in }),
                    ("11-activity-log", .log, { _ in }),
                ]
                for (name, tab, change) in activities {
                    let model = Fixtures.model()
                    change(model)
                    model.activityTab = tab
                    try renderer.renderActivity(model: model, appearance: appearance, name: "\(name)-\(scheme)")
                    written.append("\(name)-\(scheme)")
                }
            }
            // Progress in the main window (v2 part M4a): the ring and percent on the card, the bar in the list, the
            // inspector's progress with Pause and Stop, a recording waiting in line, and a paused make.
            func working(_ model: AppModel) throws -> Recording {
                try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.status == .working })
            }
            try draw("12-progress-in-progress") { model in
                Fixtures.showProgress(model)
                model.selection = .group(.inProgress)
            }
            try draw("12-progress-list") { model in
                Fixtures.showProgress(model)
                model.selection = .group(.inProgress)
                model.browserMode = .list
                model.selectedRecordings = [try working(model).id]
            }
            try draw("12-progress-inspector") { model in
                Fixtures.showProgress(model)
                model.selection = .group(.inProgress)
                model.selectedRecordings = [try working(model).id]
            }
            try draw("12-progress-inspector-waiting") { model in
                Fixtures.showProgress(model)
                model.selection = .group(.inProgress)
                let clip = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.fileName == "2026-09-13 clip 90s.mp4" })
                model.selectedRecordings = [clip.id]
            }
            try draw("12-progress-inspector-paused") { model in
                Fixtures.showProgress(model, paused: true)
                model.selection = .group(.inProgress)
                model.selectedRecordings = [try working(model).id]
            }
        }
        if only == "library" {
            print("Snapshots written to \(outputFolder.path): \(written.count) library and Settings pictures")
            // v2 part M6a: the People tab joins the inspector's tabs (2), and six People and filter pictures (12).
            // v2 part M6b: four voices and names pictures (8) and Settings, Privacy with named people (2).
            // v2 part M6c: two choices pictures (4).
            XCTAssertEqual(written.count, 4 * 2 * 2 + 2 + 2 + 3 * 2 + 3 * 2 + 2 + 2 + 4 * 2 + 2 * 3 + 2 * 2 + 5 * 2 + 2 * 2 + 5 * 2 + 5 * 2 + 2 + 2 + 3 * 2 + 2 + 6 * 2 + 4 * 2 + 2 + 2 * 2)
            return
        }

        // The People gallery (v2 part M7a, PLAN M7 check 4): empty (nobody named; the sample talk's unnamed face makes
        // the Unnamed people tile), with the sample people (Gabriel Name Only with his key photo as a test pattern,
        // Serenity not shown by a frame so her initials), Gabriel's page with and without a recorded release, Serenity's
        // page, the unnamed people's recordings, and the Name This Person sheet at Name Only and with a release.
        var galleryCount = 0
        if only == nil || only == "people" {
        try draw("11-people-empty") { model in model.selection = .people }
        try draw("11-people") { model in
            Fixtures.showGallery(model)
            model.selection = .people
        }
        try draw("11-person-name-only") { model in
            Fixtures.showGallery(model)
            model.selection = .person(try XCTUnwrap(model.namedPeopleList().first { $0.name == "Gabriel" }).id)
        }
        try draw("11-person-release") { model in
            Fixtures.showGallery(model)
            let gabriel = try XCTUnwrap(model.namedPeopleList().first { $0.name == "Gabriel" })
            var draft = NameThisPersonDraft()
            draft.recordRelease = true
            draft.releaseSignedOn = Fixtures.date(2026, 10, 12, 10, 0)
            draft.releaseKeptAt = "Releases, Yoga Marga drive"
            draft.role = .teacher
            model.recordRelease(draft, for: gabriel)
            model.selection = .person(gabriel.id)
        }
        try draw("11-person-monogram") { model in
            Fixtures.showGallery(model)
            model.selection = .person(try XCTUnwrap(model.namedPeopleList().first { $0.name == "Serenity" }).id)
        }
        try draw("11-unnamed") { model in
            Fixtures.showGallery(model)
            model.selection = .unnamed
        }
        for (variant, release) in [("name-only", false), ("release", true)] {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                Fixtures.showGallery(model)
                let talk = try talk13(model)
                var request = NameSheetRequest(recordingID: talk.id, target: .face(2))
                request.draft.name = "Asha"
                request.draft.role = .guest
                if release {
                    request.draft.recordRelease = true
                    request.draft.releaseSignedOn = Fixtures.date(2026, 10, 12, 10, 0)
                    request.draft.releaseKeptAt = "Releases, Yoga Marga drive"
                }
                try renderer.renderSheet(AnyView(NameThisPersonSheet(request: request)), model: model, size: CGSize(width: 520, height: release ? 720 : 560),
                                         appearance: appearance, name: "11-name-sheet-\(variant)-\(scheme)")
                written.append("11-name-sheet-\(variant)-\(scheme)")
            }
        }
        galleryCount = 6 * 2 + 2 * 2
        }
        if only == "people" {
            print("Snapshots written to \(outputFolder.path): \(written.count) People pictures")
            XCTAssertEqual(written.count, galleryCount)
            return
        }

        // The Viewer (v2 part M3b), opened from the browser: the 13 Sep sample talk on each rendition, with
        // edits, a span chosen, Quick Help on, marked as a class, approved, and the silent sample class. The
        // Original plays a test pattern made here, never the talk's own picture (docs/v2/PLAN.md section 11,
        // D1), and the Podcast-ready rendition a copy of the episode in a folder made here.
        let media = try ViewerSnapshotMedia.make()
        func openTalk(_ model: AppModel, rendition: Rendition? = nil, at original: Double? = nil, _ change: (Recording) -> Void = { _ in }) throws -> Recording {
            let recording = try talk13(model)
            recording.filePath = media.pattern.path
            recording.outputFolder = media.outputs.path
            change(recording)
            model.open(recording)
            model.restoredViewer = (recording.id, rendition, original)
            model.openViewer(recording)
            return recording
        }
        try draw("20-viewer-podcast") { model in _ = try openTalk(model) }
        try draw("20-viewer-podcast-ready") { model in _ = try openTalk(model, rendition: .podcastReady) }
        try draw("20-viewer-original") { model in _ = try openTalk(model, rendition: .original, at: 120) }
        try draw("20-viewer-tip-seen-playing") { model in
            model.dismissViewerTip()
            _ = try openTalk(model, at: 172.5)
        }
        try draw("20-viewer-edits-pending") { model in
            let recording = try openTalk(model, at: 296) { r in
                model.setTrim(start: 10, end: nil, for: r)
                model.addCut(TimeRange(start: 300, end: 330), to: r)
            }
            let chosen = model.viewer.document.words.indices.filter { (340.0...346.0).contains(model.viewer.document.words[$0].start) }
            if let first = chosen.first, let last = chosen.last { model.viewer.selectedWords = first...last }
            XCTAssertTrue(model.canRemoveSelectedWords(recording))
            model.inspectorTab = .info
        }
        try draw("20-viewer-span-selected") { model in
            let recording = try openTalk(model) { r in model.addCut(TimeRange(start: 300, end: 330), to: r) }
            let span = try XCTUnwrap(TimelineSpan.spans(edits: recording.edits, duration: recording.duration ?? 0).first { $0.kind == .cut })
            model.viewer.selectedSpan = span
        }
        try draw("20-viewer-quick-help") { model in
            model.setQuickHelp(true)
            model.quickHelp.show("Choose what plays: the Original as recorded, the Podcast episode, or the Podcast-ready episode. Video and Shorts are not made yet.",
                                 article: "reviewing-and-approving")
            _ = try openTalk(model)
        }
        try draw("20-viewer-class") { model in
            _ = try openTalk(model) { r in model.setKind(.lesson, for: r) }
            model.inspectorTab = .checks
        }
        try draw("20-viewer-approved") { model in
            _ = try openTalk(model) { r in
                r.status = .approved
                r.approvedAt = Fixtures.now
                r.statusReason = "Approved. Its files are in ~/Prakriti/Approved/2026-09-13 18-25-44. Nothing was uploaded or published."
            }
        }
        try draw("20-viewer-own-choices") { model in
            _ = try openTalk(model) { r in
                model.setOutput(.transcript, on: false, for: r)
                r.outputSettings.first { $0.kind == .podcastEpisode }?.loudnessTarget = -19
            }
        }
        try draw("20-viewer-silent") { model in
            let recording = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.title == "Class" && $0.status == .needsADecision })
            recording.filePath = media.pattern.path
            model.open(recording)
        }
        // A make in progress, opened in the Viewer: its banner gives the stage, percent and time left, with Pause and Stop.
        try draw("20-viewer-working") { model in
            Fixtures.showProgress(model)
            let recording = try XCTUnwrap(try model.context.fetch(FetchDescriptor<Recording>()).first { $0.status == .working })
            recording.filePath = media.pattern.path
            model.open(recording)
            model.openViewer(recording)
        }
        // The People overlay on the Original (v2 part M6d): the sample talk's made-up face, included, and a made-up second
        // face in the corner set to Hide Face (`Fixtures.showPeopleOverlay`), over the picture's black canvas (the player
        // cannot draw the test pattern into a bitmap, Mac warning 43; the real window is `make look`'s 12-viewer-people).
        try draw("20-viewer-people") { model in
            _ = try openTalk(model, rendition: .original, at: 120) { r in Fixtures.showPeopleOverlay(model, on: r) }
        }
        // The overlay must be in the picture, not only in the model (v2 part M6d fix, 13 Oct): the first 20-viewer-people
        // snapshots were transparent over the picture, with no box, label or toggle, while the build's report said
        // otherwise. Measured over the picture's area: no transparent pixel, and the boxes, labels and People add white.
        for (scheme, _) in appearances {
            let people = try SnapshotTests.pictureArea(outputFolder.appending(path: "20-viewer-people-\(scheme).png"))
            let plain = try SnapshotTests.pictureArea(outputFolder.appending(path: "20-viewer-original-\(scheme).png"))
            print("20-viewer-people-\(scheme): \(people.samples) samples, \(people.transparent) transparent, \(people.white) white; "
                  + "20-viewer-original-\(scheme): \(plain.transparent) transparent, \(plain.white) white")
            XCTAssertEqual(people.transparent, 0, "20-viewer-people-\(scheme): the picture is not drawn")
            XCTAssertEqual(plain.transparent, 0, "20-viewer-original-\(scheme): the picture is not drawn")
            XCTAssertGreaterThanOrEqual(people.white, plain.white + 50, "20-viewer-people-\(scheme): no boxes or labels over the picture")
        }
        let viewerCount = 13 * 2

        if only == "recording" {
            print("Snapshots written to \(outputFolder.path): \(written.count) Viewer pictures")
            XCTAssertEqual(written.count, viewerCount)
            return
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: outputFolder.path).filter { $0.hasSuffix(".png") }
        print("Snapshots written to \(outputFolder.path): \(written.count) screens, \(files.count) pictures")
        XCTAssertEqual(written.count, 4 * 2 * 2 + 2 + 2 + 3 * 2 + 3 * 2 + 2 + 2 + 4 * 2 + 2 * 3 + 2 * 2 + 5 * 2 + 2 * 2 + 6 * 2 + 5 * 2 + 2 + 3 * 2 + viewerCount + 2 + 6 * 2 + 4 * 2 + 2 + 2 * 2 + galleryCount)
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

    /// The Viewer's picture in a main-window snapshot (1440 by 900 at 2x, the sidebar open): every 8th pixel of the
    /// points 240 to 1060 across and 80 to 460 down, inside the picture whatever the inspector's width. Counts the
    /// transparent pixels (a picture the bitmap did not draw) and the near-white ones (boxes, labels, toggles).
    static func pictureArea(_ url: URL) throws -> (samples: Int, transparent: Int, white: Int) {
        let rep = try XCTUnwrap(NSBitmapImageRep(data: try Data(contentsOf: url)))
        var samples = 0, transparent = 0, white = 0
        for y in stride(from: 160, to: 920, by: 8) {
            for x in stride(from: 480, to: 2120, by: 8) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                samples += 1
                if color.alphaComponent < 0.5 { transparent += 1 }
                else if color.redComponent > 0.85, color.greenComponent > 0.85, color.blueComponent > 0.85 { white += 1 }
            }
        }
        return (samples, transparent, white)
    }
}

/// The media the Viewer's snapshots play (v2 part M3b), made once per test run in a temporary folder: a test
/// pattern with a tone, as long as the 13 Sep talk, standing in for its original (so no picture of a person
/// is drawn or read; the studio folder is never opened), and a copy of the sample talk's output folder with
/// its episode copied in as the podcast-ready MP3 (no podcast-ready file of the talk exists on this Mac).
@MainActor
enum ViewerSnapshotMedia {
    struct Media {
        let pattern: URL
        let outputs: URL
    }

    private static var made: Media?

    static func make() throws -> Media {
        if let made, FileManager.default.fileExists(atPath: made.pattern.path) { return made }
        let root = FileManager.default.temporaryDirectory.appending(path: "prakriti-viewer-snapshots", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let pattern = root.appending(path: "test pattern.mp4")
        let ffmpeg = Process()
        ffmpeg.executableURL = ToolPaths.standard.ffmpeg
        ffmpeg.arguments = ["-hide_banner", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=5", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
                            "-t", "948", "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", pattern.path]
        try ffmpeg.run()
        ffmpeg.waitUntilExit()
        guard ffmpeg.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        let sample = AppPaths(mode: .live).root.appending(path: "Outputs/2026-09-13 18-25-44", directoryHint: .isDirectory)
        let outputs = root.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outputs.appending(path: PodcastPackage.folderName, directoryHint: .isDirectory), withIntermediateDirectories: true)
        for name in ["REPORT.md", "episode.mp3", "transcript.json", "transcript.srt", "transcript.txt", "transcript.vtt"] {
            try FileManager.default.copyItem(at: sample.appending(path: name), to: outputs.appending(path: name))
        }
        try FileManager.default.copyItem(at: sample.appending(path: "episode.mp3"),
                                         to: outputs.appending(path: PodcastPackage.folderName, directoryHint: .isDirectory).appending(path: "Talk with Gabriel.mp3"))
        let media = Media(pattern: pattern, outputs: outputs)
        made = media
        return media
    }
}
