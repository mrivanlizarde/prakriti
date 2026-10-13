import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M6b's acceptance (docs/v2/PLAN.md M6: check 2's voice half, check 4, check 8 as the whole pass, check 9), on
/// real files through the app's own runner, in development:
///
/// - the **13 Sep talk**, made on engine v0's chain: its voices told apart on its one mixed track; with Who Is Teaching
///   set to Gabriel, the People tab's sentence reads "Gabriel speaks for N percent."; anything else heard or seen is
///   written down for Ivan (PLAN review item 22), never a FAIL; the episode still engine v0's bit for bit;
/// - **two-people-tracks.mov**: who speaks comes from tracks 2 and 3, and the log says so;
/// - **two-people-mixed.mp4**: the diarizer's voices, written down (check 3 is part M6c's);
/// - the whole people pass (faces, voices, links) on the **6 Sep talk** (55:39), timed: under 5 minutes;
/// - the privacy lock, counted in cloud requests through the real writer with the cloud client scripted (nothing
///   leaves the Mac): two-people-mixed with writing set to Anthropic writes locally; the 13 Sep talk, with Gabriel's
///   cloud switch off and on; the 90 s clip of the same talk, with the switch off and on.
///
///   cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6b
///
/// Skipped unless PRAKRITI_ACCEPTANCE=people. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the
/// originals are only read, checked by size and date before and after. Never a class, never the archive. Frames of
/// Gabriel's talks are measured, never drawn (section 11, D1): the People tab pictures use a test pattern for faces.
@MainActor
final class VoicesAcceptanceTests: XCTestCase {
    func testVoicesAndNamesOnRealFiles() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "people" else {
            throw XCTSkip("Reads the 13 Sep and 6 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6b")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.notifier.poster = nil
        model.log.write("Acceptance test for v2 part M6b (voices and names) started.")
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        XCTAssertFalse(gabriel.mayReadInCloud, "off until Ivan turns it on")

        let talk13 = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        let talk6 = paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4")
        let clip = home.appending(path: "Prakriti/Dev/Fixtures/13sep-90s.mp4")
        let mixed = home.appending(path: "Prakriti/Dev/Fixtures/two-people-mixed.mp4")
        let tracks = home.appending(path: "Prakriti/Dev/Fixtures/two-people-tracks.mov")
        let files = [talk13, talk6, clip, mixed, tracks]
        for file in files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing: \(file.path) (cd ~/Code/prakriti/mac && make fixtures)")
            for day in ["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"] { XCTAssertFalse(file.path.contains(day), "never a class") }
        }
        let before = files.map(fingerprint)
        var report = ["v2 part M6b acceptance (voices and names), \(Date().formatted(date: .abbreviated, time: .standard))", ""]
        report.append("FluidAudio diarizer models: \(Diarizer.modelsFolder.path) (\(Diarizer.modelsPresent ? "present" : "MISSING")); "
                      + "embeddingsPath of every configuration built: \(Diarizer.embeddingsPathOfEveryConfiguration.map { $0 ?? "nil" })")
        let modelsBefore = folderFingerprint(Diarizer.modelsFolder)

        func make(_ file: URL, kind: RecordingKind = .talk, engineV0: Bool = false) async throws -> Recording {
            let folder = paths.outputs.appending(path: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
            precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
            try? FileManager.default.removeItem(at: folder)
            let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent) ?? Date(), foundAt: Date(), kind: kind)
            model.context.insert(recording)
            recording.source = model.source(containing: file)
            try model.context.save()
            if engineV0 {
                model.setOutput(.podcastEpisode, on: true, for: recording)
                let own = try XCTUnwrap(recording.outputSettings.first { $0.kind == .podcastEpisode })
                own.trimSilence = false
                own.loudnessTarget = -16
                try model.context.save()
            }
            await model.runner.process(recording, trigger: .byHand)
            return recording
        }
        func describe(_ name: String, _ recording: Recording) -> [String] {
            var lines: [String] = []
            let step = recording.latestRun?.steps.first { $0.name == PipelineStep.voices.title }
            lines.append("\(name): voices step \(step?.state.rawValue ?? "missing") in \(String(format: "%.1f", step?.seconds ?? 0)) s. \(step?.detail ?? "")")
            if let voices = recording.voices {
                lines.append(String(format: "  source %@, tracks %@, voices %d, speech %.1f s, overlap %.1f s, changes to listen to %d",
                                    voices.source.rawValue, voices.tracksUsed.map(String.init).joined(separator: ","), voices.voices.count,
                                    voices.speech, voices.overlap, voices.listen.count))
                for voice in voices.voices {
                    lines.append("    \(voice.label): speaks \(Format.length(voice.speaking)) (\(String(format: "%.1f", voice.speaking)) s), \(Format.timecode(voice.first)) to \(Format.timecode(voice.last))"
                                 + (voice.track.map { ", track \($0)" } ?? "") + (voice.face.map { ", linked to face row \($0) by \(voice.linkedBy ?? "?")" } ?? ", no face linked"))
                }
            }
            if let faces = recording.faces { lines.append("  faces: \(faces.stepLine)") }
            return lines
        }

        // Check 2 (voice): the 13 Sep talk, on engine v0's chain so its episode can be compared bit for bit.
        let talk = try await make(talk13, engineV0: true)
        XCTAssertEqual(talk.status, .readyForYourYes, talk.statusReason ?? "")
        report += describe("13 Sep talk (15:48)", talk)
        let talkVoices = try XCTUnwrap(talk.voices, "the 13 Sep talk has no voices in the store")
        XCTAssertEqual(talkVoices.source, .diarizer, "one mixed track: the diarizer")
        XCTAssertTrue(talk.isPrivacyLocked, "nobody named yet")
        report.append("  lock before naming anyone: \(PrivacyLock.decide(talk.lockSubject).reason ?? "OPEN")")
        model.setTeacher(gabriel, for: talk)
        let summary13 = PeopleWords.summary(faces: talk.faces, voices: talkVoices, names: talk.resolvedNames, people: talk.namedPeople)
        report.append("  Who is teaching: Gabriel. People tab sentence: \"\(summary13)\"")
        XCTAssertTrue(summary13.hasPrefix("Gabriel speaks for "), summary13)
        XCTAssertNotNil(summary13.range(of: #"^Gabriel speaks for \d+ percent\."#, options: .regularExpression), summary13)
        if talkVoices.voices.count == 1 && (talk.faces?.people.count ?? 0) <= 1 {
            XCTAssertEqual(summary13.components(separatedBy: ". ").count, 1, "no other people: \(summary13)")
        } else {
            report.append("  IVAN: besides Gabriel's voice and face, the pass found \(Format.count(talkVoices.otherVoices, "other voice")) and "
                          + "\(Format.count(max(0, (talk.faces?.people.count ?? 1) - 1), "other face row")) (PLAN review item 22: the talk's content, not a FAIL).")
        }
        let facts13 = talk.peopleFacts
        report.append("  people facts: checked \(facts13.checked), named \(facts13.named.map { "\($0.name) heard \($0.heard) seen \($0.seen)" }), unnamed seen \(facts13.unnamedSeen), unnamed heard \(facts13.unnamedHeard)")
        let made = try decodedMD5(paths.outputs.appending(path: "2026-09-13 18-25-44/episode.mp3"))
        let v0Episode = paths.home.appending(path: "Prakriti/Outputs/2026-09-13 18-25-44/episode.mp3")
        let v0 = FileManager.default.fileExists(atPath: v0Episode.path) ? try decodedMD5(v0Episode) : nil
        XCTAssertEqual(made, v0, "with faces and voices checked, the episode is still engine v0's, bit for bit")
        report.append("  episode decoded audio md5: \(made); engine v0's (read only): \(v0 ?? "not found") (\(made == v0 ? "identical" : "DIFFERENT"))")
        report.append("")

        // Check 4: two-people-tracks.mov, who speaks from tracks 2 and 3.
        let logBefore = (model.log.todayFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) })?.count ?? 0
        let tracksRec = try await make(tracks)
        report += describe("two-people-tracks", tracksRec)
        let tv = try XCTUnwrap(tracksRec.voices)
        XCTAssertEqual(tv.source, .tracks)
        XCTAssertEqual(tv.tracksUsed, [2, 3])
        XCTAssertEqual(tv.voices.count, 2, "two voices, one per microphone track")
        let second = tv.voices.first { $0.track == 3 }
        XCTAssertEqual(second?.first ?? 0, 30, accuracy: 1.0, "the second voice starts at 0:30")
        // The `say` passage sits in a 0:30 to 0:50 slot but its speech ends at 48.51 s (ffmpeg silencedetect at -50 dB on
        // track 3, measured 13 Oct): the truth is the speech, not the slot.
        XCTAssertEqual(second?.last ?? 0, 48.5, accuracy: 1.0, "the second voice ends where its speech ends, 0:48.5")
        let main = tv.voices.first { $0.track == 2 }
        XCTAssertGreaterThan(main?.speaking ?? 0, 45, "track 2 holds the 13 Sep voice")
        XCTAssertEqual(main?.face, 1, "the main voice is linked to the main face")
        let logText = String((model.log.todayFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "").dropFirst(logBefore))
        let line = logText.split(separator: "\n").first { $0.contains("two-people-tracks.mov: voices. Who speaks is read from microphone tracks 2, 3") }
        XCTAssertNotNil(line, "the log says who speaks came from the tracks")
        report.append("  log line: \(line.map(String.init) ?? "MISSING")")
        report.append("")

        // two-people-mixed: the diarizer on the one mixed track (written down; check 3 is M6c's).
        let mixedRec = try await make(mixed)
        report += describe("two-people-mixed", mixedRec)
        XCTAssertEqual(mixedRec.voices?.source, .diarizer)
        XCTAssertEqual(mixedRec.voices?.voices.count, 2, "the second voice, heard only over the teacher, is a voice of its own")
        report.append("")

        // Check 9: the lock, counted through the real writer, nothing leaving the Mac.
        func cloudRequests(_ recording: Recording) async throws -> (Int, String?) {
            let folder = paths.outputs.appending(path: URL(fileURLWithPath: recording.filePath).deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
            var input = try XCTUnwrap(WritingInput.from(folder: folder, clock: nil, duration: recording.duration ?? 0, applyLexicon: false,
                                                        label: "Acceptance", fileName: recording.fileName, kind: recording.kind,
                                                        knownSerenity: recording.hasSerenity), "no transcript in \(folder.path)")
            input.people = recording.peopleFacts
            let cloud = ScriptedClient(.claudeAPI, limit: 200_000, replies: [.success(ProviderTests.passingAnswer(input))])
            let local = ScriptedClient(.lmStudio, limit: 200_000, replies: [.success(ProviderTests.passingAnswer(input))])
            var setup = WritingSetup()
            setup.providers = [.writing: .claudeAPI, .tagging: .lmStudio, .summarizing: .lmStudio]
            setup.maxAttempts = 1
            setup.makeClient = { _, _ in local }
            setup.makeCloudClient = { _, _ in cloud }
            let outcome = try await Writer(setup: setup, log: nil).write(input)
            return (cloud.requests.count, outcome.lockReason)
        }
        let (mixedCount, mixedReason) = try await cloudRequests(mixedRec)
        XCTAssertEqual(mixedCount, 0, "two-people-mixed writes locally")
        report.append("Check 9, writing set to Anthropic, cloud requests counted (the cloud client is scripted; nothing leaves the Mac):")
        report.append("  two-people-mixed, nobody named: \(mixedCount) (\(mixedReason ?? "open"))")
        model.setTeacher(gabriel, for: mixedRec)
        model.setCloudConsent(true, for: gabriel)
        let (mixedNamed, mixedNamedReason) = try await cloudRequests(mixedRec)
        XCTAssertEqual(mixedNamed, 0, "two-people-mixed with Gabriel named and agreed still writes locally: someone else appears")
        report.append("  two-people-mixed, Gabriel teaching and agreed: \(mixedNamed) (\(mixedNamedReason ?? "open"))")
        model.setCloudConsent(false, for: gabriel)
        let (talkOff, talkOffReason) = try await cloudRequests(talk)
        XCTAssertEqual(talkOff, 0, "13 Sep, Gabriel's switch off")
        report.append("  13 Sep talk, Gabriel teaching, his switch off: \(talkOff) (\(talkOffReason ?? "open"))")
        model.setCloudConsent(true, for: gabriel)
        let (talkOn, talkOnReason) = try await cloudRequests(talk)
        report.append("  13 Sep talk, Gabriel teaching, his switch on: \(talkOn) (\(talkOnReason ?? "open"))")
        // The 90 s clip of the same talk (5:00 to 6:30), one face and one voice if the pass says so.
        model.setCloudConsent(false, for: gabriel)
        let clipRec = try await make(clip)
        report += describe("13sep-90s (the same talk, 5:00 to 6:30)", clipRec)
        model.setTeacher(gabriel, for: clipRec)
        let (clipOff, clipOffReason) = try await cloudRequests(clipRec)
        XCTAssertEqual(clipOff, 0, "the clip with Gabriel's switch off")
        model.setCloudConsent(true, for: gabriel)
        let (clipOn, clipOnReason) = try await cloudRequests(clipRec)
        report.append("  13sep-90s, Gabriel teaching, his switch off: \(clipOff) (\(clipOffReason ?? "open")); on: \(clipOn) (\(clipOnReason ?? "open"))")
        let clipFacts = clipRec.peopleFacts
        report.append("  13sep-90s people facts: checked \(clipFacts.checked), named \(clipFacts.named.map { "\($0.name) heard \($0.heard) seen \($0.seen) agreed \($0.cloudConsent)" }), unnamed seen \(clipFacts.unnamedSeen), unnamed heard \(clipFacts.unnamedHeard), says Serenity \(clipRec.hasSerenity)")
        if clipFacts.unnamedSeen == 0 && clipFacts.unnamedHeard == 0 && !clipRec.hasSerenity {
            XCTAssertEqual(clipOn, 1, "one face, one voice, Gabriel named and agreed: allowed")
        }
        model.setCloudConsent(false, for: gabriel)
        // Every real talk names Serenity, which keeps it local (Mac warning 90), so the open case is shown on a made-up
        // recording through the same runner: a test pattern (no face) and one `say` voice, 70 s, naming no one.
        let synthetic = FileManager.default.temporaryDirectory.appending(path: "prakriti-m6b-one-voice.mov")
        try? FileManager.default.removeItem(at: synthetic)
        let speech = FileManager.default.temporaryDirectory.appending(path: "prakriti-m6b-one-voice.aiff")
        let paragraph = "This is a made up talk about breathing slowly. Sit comfortably and let the breath settle. Notice the length of each breath, and let it grow a little longer. "
        try run(URL(fileURLWithPath: "/usr/bin/say"), ["-v", "Samantha", "-o", speech.path, String(repeating: paragraph, count: 6)])
        try run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=70",
                                            "-i", speech.path, "-map", "0:v", "-map", "1:a", "-af", "apad", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac",
                                            "-t", "70", synthetic.path])
        let oneVoice = try await make(synthetic)
        report += describe("synthetic one-voice recording (test pattern, say)", oneVoice)
        if let voice = oneVoice.voices?.voices.first { model.nameVoice(voice.id, as: gabriel, in: oneVoice) }
        let (synthOff, synthOffReason) = try await cloudRequests(oneVoice)
        model.setCloudConsent(true, for: gabriel)
        let (synthOn, synthOnReason) = try await cloudRequests(oneVoice)
        model.setCloudConsent(false, for: gabriel)
        XCTAssertEqual(synthOff, 0, "the voice named Gabriel, his switch off")
        XCTAssertEqual(synthOn, 1, "the voice named Gabriel, his switch on, nobody else: allowed")
        report.append("  synthetic one voice, named Gabriel: switch off \(synthOff) (\(synthOffReason ?? "open")); on \(synthOn) (\(synthOnReason ?? "open"))")
        try? FileManager.default.removeItem(at: speech)
        report.append("")

        // Check 8 (whole pass): faces, voices and links on the 6 Sep talk, timed.
        let clock = ContinuousClock()
        let started = clock.now
        let sixID = UUID()
        let six = try await FaceStep.run(file: talk6, recordingID: sixID, folders: model.peopleFolders, now: Date())
        let faceSeconds = Double((clock.now - started).components.seconds)
        let ffmpeg = ToolPaths.standard.ffmpeg
        let sixVoices = try await VoiceStep.run(file: talk6, recordingID: sixID, folders: model.peopleFolders,
                                                audioTracks: await VoiceStep.audioTracks(talk6), now: Date(),
                                                decode: { arguments in _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(1200)) })
        let seconds = Double((clock.now - started).components.seconds)
        XCTAssertLessThan(seconds, 300, "the whole people pass on 55:39 takes under 5 minutes")
        report.append(String(format: "6 Sep talk (55:39), the whole people pass: %.0f s (faces %.0f s, voices and links %.0f s; limit 300 s).", seconds, faceSeconds, seconds - faceSeconds))
        report.append("  \(six.found.stepLine)")
        report.append("  \(sixVoices.found.stepLine)")
        for voice in sixVoices.found.voices {
            report.append("    \(voice.label): speaks \(Format.length(voice.speaking)), \(Format.timecode(voice.first)) to \(Format.timecode(voice.last))"
                          + (voice.face.map { ", linked to face row \($0) by \(voice.linkedBy ?? "?")" } ?? ", no face linked"))
        }
        let sixFile = try Data(contentsOf: model.peopleFolders.peopleFile(for: sixID))
        try PeopleTests.assertNoPrintAndNoPicture(sixFile)
        model.peopleFolders.removePeopleFile(for: sixID)
        report.append("")

        // Nothing stored for strangers, after the voice step too (check 7 is M6a's; repeated because this step is new).
        for folders in [model.peopleFolders, PeopleFolders(support: AppPaths(mode: .live).applicationSupport)] {
            for forbidden in folders.forbidden {
                XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), forbidden.path)
            }
        }
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        XCTAssertEqual(jobs, [], "no job folder is left")
        report.append("Faces, Voices and FaceIndex folders: absent in development and live. Development Jobs folder: \(jobs.isEmpty ? "empty" : "NOT EMPTY \(jobs)")")
        for recording in [talk, tracksRec, mixedRec, clipRec, oneVoice] {
            let data = try Data(contentsOf: model.peopleFolders.peopleFile(for: recording.id))
            try PeopleTests.assertNoPrintAndNoPicture(data)
            let json = try JSONSerialization.jsonObject(with: data)
            let longest = PeopleTests.numberArrays(json).map(\.count).max() ?? 0
            let file = try PeopleFile.decoder.decode(PeopleFile.self, from: data)
            XCTAssertEqual(file.steps, ["faces", "voices"])
            report.append("people file of \(recording.fileName): \(data.count) bytes, steps \(file.steps), \(file.voices?.segments.count ?? 0) voice segments, links \(file.voices?.links ?? []), longest list of numbers \(longest), no picture or print words")
        }
        let modelsAfter = folderFingerprint(Diarizer.modelsFolder)
        XCTAssertEqual(modelsAfter, modelsBefore, "the diarizer's model folder (Hark's too) is only read")
        report.append("FluidAudio's model folder unchanged by size and date: \(modelsAfter == modelsBefore ? "yes" : "NO")")
        report.append("")

        // Pictures: the People tab and the Info tab of each, light and dark; faces drawn as a test pattern (D1).
        var drawn: [String] = []
        model.faceCrops.useTestPattern = true
        model.cardPictures.useTestPattern = true
        for (scheme, appearance) in SnapshotRenderer.appearances {
            for (slug, recording) in [("talk-13-sep", talk), ("two-people-tracks", tracksRec), ("two-people-mixed", mixedRec)] {
                model.path = []
                model.selection = .group(.all)
                model.selectedRecordings = [recording.id]
                model.inspectorTab = .people
                try renderer.render(model: model, appearance: appearance, name: "m6b-people-\(slug)-\(scheme)")
                drawn.append("m6b-people-\(slug)-\(scheme)")
            }
            model.selectedRecordings = [talk.id]
            model.inspectorTab = .info
            try renderer.render(model: model, appearance: appearance, name: "m6b-info-teacher-\(scheme)")
            model.selectedRecordings = []
            try renderer.render(model: model, appearance: appearance, name: "m6b-cards-\(scheme)")
            drawn += ["m6b-info-teacher-\(scheme)", "m6b-cards-\(scheme)"]
        }
        report.append("Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", "))

        let after = files.map(fingerprint)
        XCTAssertEqual(after, before)
        report.append("Originals unchanged (size and modification date): \(after == before ? "yes" : "NO")")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-voices.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M6b finished.")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }

    private func folderFingerprint(_ folder: URL) -> [String] {
        (FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])?
            .compactMap { $0 as? URL } ?? []).map { "\($0.path) \(fingerprint($0))" }.sorted()
    }

    private func run(_ tool: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "\(tool.lastPathComponent) \(arguments.prefix(4))")
    }

    private func decodedMD5(_ file: URL) throws -> String {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-v", "error", "-i", file.path, "-map", "0:a", "-f", "md5", "-"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
