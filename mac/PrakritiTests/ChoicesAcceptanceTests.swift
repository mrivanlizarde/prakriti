import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M6c's acceptance (docs/v2/PLAN.md M6: checks 3, 4 as "matches check 3", 10, and the notice of check 11), on
/// real files through the app's own runner, in development:
///
/// - **two-people-mixed.mp4** (check 3): made once with everyone included (the default), then Who Is Teaching set to
///   Gabriel and Set All Unnamed To Leave Out, then made again with the podcast-ready episode on. Both episodes are
///   transcribed again with Parakeet: 0 of the five-word runs of the `say` paragraph may be heard, and at least 98% of the
///   13 Sep words not taken out must be there, in order (the reference is the 13sep-90s clip's own transcript, the
///   same speech without the second voice). The audio output check must pass. Before the choice, the same check is
///   run on the first episode as if the second voice were left out: it must catch it (research-people.md 6.3).
/// - **two-people-tracks.mov** (check 4): who speaks comes from tracks 2 and 3, and the same choices give the same
///   result.
/// - the **13 Sep talk** (check 10): the names said aloud, counted (a number only, for BUILD-LOG); Approve waits for
///   them; the first one muted and made again: its stretch of the episode measured silent, "[name]" in the captions.
///
///   cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6c
///
/// Skipped unless PRAKRITI_ACCEPTANCE=people. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the
/// originals are only read, checked by size and date before and after. Never a class, never the archive. Frames of
/// Gabriel's talks are measured, never drawn (section 11, D1): the pictures use a test pattern for faces. Names said
/// aloud are written to the report as counts and times only.
@MainActor
final class ChoicesAcceptanceTests: XCTestCase {
    func testChoicesAppliedToAudioOnRealFiles() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "people" else {
            throw XCTSkip("Reads the 13 Sep talk and its fixtures. Run it with: cd ~/Code/prakriti/mac && make accept-people MILESTONE=v2-m6c")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.notifier.poster = nil
        model.log.write("Acceptance test for v2 part M6c (choices applied to audio) started.")
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        let work = FileManager.default.temporaryDirectory.appending(path: "prakriti-m6c-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let talk13 = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        let fixtures = home.appending(path: "Prakriti/Dev/Fixtures", directoryHint: .isDirectory)
        let clip = fixtures.appending(path: "13sep-90s.mp4")
        let mixed = fixtures.appending(path: "two-people-mixed.mp4")
        let tracks = fixtures.appending(path: "two-people-tracks.mov")
        let files = [talk13, clip, mixed, tracks]
        for file in files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing: \(file.path) (cd ~/Code/prakriti/mac && make fixtures)")
            for day in ["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"] { XCTAssertFalse(file.path.contains(day), "never a class") }
        }
        let before = files.map(fingerprint)
        var report = ["v2 part M6c acceptance (choices applied to audio), \(Date().formatted(date: .abbreviated, time: .standard))", ""]

        func make(_ file: URL, podcastReady: Bool = false) async throws -> Recording {
            let folder = paths.outputs.appending(path: file.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
            precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
            try? FileManager.default.removeItem(at: folder)
            let recording = Recording(filePath: file.path, recordedAt: AppModel.dateInName(file.lastPathComponent) ?? Date(), foundAt: Date(), kind: .talk)
            model.context.insert(recording)
            recording.source = model.source(containing: file)
            try model.context.save()
            model.setOutput(.podcastEpisode, on: true, for: recording)
            model.setOutput(.transcript, on: true, for: recording)
            if podcastReady { model.setOutput(.podcastReady, on: true, for: recording) }
            try model.context.save()
            await model.runner.process(recording, trigger: .byHand)
            XCTAssertEqual(recording.status, .readyForYourYes, "\(file.lastPathComponent): \(recording.statusReason ?? "")")
            return recording
        }
        func again(_ recording: Recording) async {
            await model.runner.process(recording, trigger: .makeAgain)
            XCTAssertEqual(recording.status, .readyForYourYes, "\(recording.fileName) again: \(recording.statusReason ?? "")")
        }
        func folder(_ recording: Recording) -> URL { URL(fileURLWithPath: try! XCTUnwrap(recording.outputFolder), isDirectory: true) }
        func step(_ recording: Recording, _ step: PipelineStep) -> String {
            let found = recording.latestRun?.steps.first { $0.name == step.title }
            return "\(step.title): \(found?.state.rawValue ?? "not planned")\(found?.seconds.map { String(format: " in %.1f s", $0) } ?? ""). \(found?.detail ?? "")"
        }

        // The reference: the 13 Sep speech of the clip, word by word with times, without the second voice.
        let clipRec = try await make(clip)
        let clipJSON = try Data(contentsOf: folder(clipRec).appending(path: TranscriptFiles.asHeard))
        let clipWords = EpisodeTranscript.sentences(json: clipJSON)!.flatMap { EpisodeTranscript.words($0.tokens ?? []) }
            .filter { $0.contains { EpisodeTranscript.isWord($0.text) } }
            .map { (text: $0.map(\.text).joined(), at: EpisodeTranscript.position(start: $0.first!.start, end: $0.last!.end)) }
        let sayText = try String(contentsOf: fixtures.appending(path: "second-voice.txt"), encoding: .utf8)
        let sayGrams = Set(grams(sayText)).subtracting(grams(clipWords.map(\.text).joined(separator: " ")))
        report.append("Reference: 13sep-90s, \(clipWords.count) words of the 13 Sep talk; the second voice's paragraph: \(sayGrams.count) five-word runs said only by it.")
        report.append("")

        /// Checks 3 and 4: the second voice left out, then both episodes transcribed again.
        func leaveOutTheSecondVoice(_ file: URL, slug: String) async throws -> (Recording, [String]) {
            var lines: [String] = []
            let recording = try await make(file, podcastReady: true)
            let voices = try XCTUnwrap(recording.voices)
            lines.append("\(slug): first make (everyone included, the default): voices from \(voices.source.rawValue), \(voices.voices.map { "\($0.label) \(String(format: "%.1f", $0.speaking)) s \(Format.timecode($0.first)) to \(Format.timecode($0.last))" + ($0.face.map { " face \($0)" } ?? "")  }.joined(separator: "; ")).")
            XCTAssertNil(recording.peopleApplied, "nobody left out: nothing applied")
            XCTAssertFalse(recording.latestRun?.steps.contains { $0.name == PipelineStep.leaveOut.title } ?? true, "no step when everyone is included")
            lines.append("  steps: \(step(recording, .namesSaid))")
            lines.append("  every person's choice before any change: \(recording.personKeys.map { "\(recording.label(for: $0)) \(recording.choices.choice($0, for: .podcast).title)" }.joined(separator: ", "))")

            // The output check catches a miss: the first episode, made with everyone in, checked as if Voice 2 were left out.
            let second = try XCTUnwrap(voices.voices.first { $0.id != 1 }, "a second voice")
            let segments = try XCTUnwrap(model.peopleFolders.read(recording.id)?.voices?.voiceSegments)
            let clock = try XCTUnwrap(recording.episodeClock)
            let ffmpeg = ToolPaths.standard.ffmpeg
            let planted = try await AudioOutputCheck.run(original: file, made: [.init(name: "episode.mp3", url: folder(recording).appending(path: "episode.mp3"), clock: clock)],
                                                         segments: segments, leftOut: [second.id], folders: model.peopleFolders, now: Date(),
                                                         decode: { arguments in _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(600)) })
            XCTAssertFalse(planted.passed, "\(slug): the check must catch the second voice in an episode that still holds it")
            lines.append("  planted miss (the first episode checked as if \(second.label) were left out): \(planted.passed ? "PASSED, NOT CAUGHT" : "caught"), "
                         + "\(planted.findings.count) finding(s), the first at \(planted.findings.first.map { Format.timecode($0.at) } ?? "none") (\(planted.findings.first?.how ?? ""))")
            for match in planted.matches { lines.append("    \(match)") }

            // The choices: Gabriel teaching, everyone else left out.
            model.setTeacher(gabriel, for: recording)
            model.setAllUnnamed(.leaveOut, in: recording)
            XCTAssertTrue(recording.choicesPending, "not in the episode until made again")
            XCTAssertFalse(model.approvalCheck(recording).canApprove)
            lines.append("  choices: " + recording.personKeys.map { "\(recording.label(for: $0)) \(recording.choices.choice($0, for: .podcast).title)" }.joined(separator: ", "))
            lines.append("  Approve before Make Again: \(model.approvalCheck(recording).line ?? "")")
            await again(recording)
            XCTAssertFalse(recording.choicesPending)
            let applied = try XCTUnwrap(recording.peopleApplied)
            XCTAssertEqual(applied.leaveOut.voices, [second.id])
            lines.append("  made again: \(step(recording, .leaveOut))")
            lines.append("  \(step(recording, .audioCheck))")
            lines.append("  cuts: " + applied.leaveOut.cuts.map { String(format: "%.2f to %.2f", $0.start, $0.end) }.joined(separator: ", ")
                         + "; speaking at once: " + applied.leaveOut.overlaps.map { String(format: "%.2f to %.2f", $0.start, $0.end) }.joined(separator: ", "))
            let check = try XCTUnwrap(applied.check)
            XCTAssertTrue(check.passed, "\(slug): \(check.line { "Voice \($0)" })")
            lines.append("  audio output check: \(check.passed ? "PASS" : "FAIL"), \(String(format: "%.1f", check.seconds)) s: \(check.line { recording.label(forVoice: $0) })")
            for match in check.matches { lines.append("    \(match)") }
            let approval = model.approvalCheck(recording)
            lines.append("  Approve now: \(approval.canApprove ? "allowed" : "refused"): \(approval.line ?? "")")

            // Both episodes, transcribed again.
            let ready = try XCTUnwrap(recording.podcastReady, "the podcast-ready episode was made")
            for (name, mp3) in [("episode.mp3", folder(recording).appending(path: "episode.mp3")),
                                ("podcast-ready " + ready.fileName, folder(recording).appending(path: PodcastPackage.folderName).appending(path: ready.fileName))] {
                let retold = try transcribe(mp3, in: work, name: slug)
                let heardSay = sayGrams.intersection(grams(retold))
                XCTAssertEqual(heardSay.count, 0, "\(slug) \(name): the second voice heard: \(heardSay)")
                // Numbers are left out of both sides: Parakeet writes the same amount as "two hundred" in one run and "200"
                // in another (measured 13 Oct on two-people-tracks), which is not a word lost.
                let kept = clipWords.filter { word in !applied.leaveOut.cuts.contains { word.at >= $0.start && word.at <= $0.end } }.map { normal($0.text) }
                    .filter { !$0.isEmpty && !isNumber($0) }
                let retoldWords = retold.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init).filter { !isNumber($0) }
                // Fillers ("uh", "um") are left out of the share, as word error rates usually leave them: Parakeet writes
                // the same "uh" in one run and not the next (measured 13 Oct: the uncut clip transcribed again matched
                // 241 of 241 words, but the clip cut the same way with no second voice dropped an "uh"). The share with
                // them is written down too.
                let raw = lcs(kept, retoldWords)
                let words = kept.filter { !isFiller($0) }, heardWords = retoldWords.filter { !isFiller($0) }
                let inOrder = lcs(words, heardWords)
                let share = Double(inOrder) / Double(max(1, words.count))
                XCTAssertGreaterThanOrEqual(share, 0.98, "\(slug) \(name): the 13 Sep words not removed, in order")
                lines.append(String(format: "  %@ transcribed again: %d of %d runs of the second voice heard; %d of %d (%.1f%%) of the 13 Sep words not removed heard in order (with fillers: %d of %d, %.1f%%)",
                                    name, heardSay.count, sayGrams.count, inOrder, words.count, share * 100, raw, kept.count, Double(raw) / Double(max(1, kept.count)) * 100))
            }
            return (recording, lines)
        }

        let (mixedRec, mixedLines) = try await leaveOutTheSecondVoice(mixed, slug: "two-people-mixed")
        report += ["Check 3, two-people-mixed.mp4 (one mixed track, the diarizer):"] + mixedLines + [""]
        let (tracksRec, tracksLines) = try await leaveOutTheSecondVoice(tracks, slug: "two-people-tracks")
        XCTAssertEqual(tracksRec.voices?.source, .tracks)
        report += ["Check 4, two-people-tracks.mov (who speaks from tracks 2 and 3; must match check 3):"] + tracksLines + [""]

        // Check 10 on the 13 Sep talk: names said aloud, counted; Approve waits; one muted and measured.
        let talk = try await make(talk13)
        model.setTeacher(gabriel, for: talk)
        let said = try XCTUnwrap(talk.namesSaid, "the names step ran")
        report.append("Check 10, the 13 Sep talk: \(said.moments.count) names said aloud to check (other than Gabriel, who is named in Settings), \(said.byName.count) different names. \(step(talk, .namesSaid))")
        report.append("  Approve while they are not decided: \(model.approvalCheck(talk).line ?? "allowed")")
        if let first = said.moments.first {
            XCTAssertFalse(model.approvalCheck(talk).canApprove, "Approve waits for each name")
            model.decideName(.keep, moments: Array(said.moments.dropFirst()), in: talk)
            model.decideName(.mute, moments: [first], in: talk)
            XCTAssertTrue(talk.choicesPending)
            await again(talk)
            XCTAssertFalse(talk.choicesPending)
            XCTAssertEqual(talk.madeMutes.count, 1)
            report.append("  muted the first (at \(Format.timecode(first.start)), \(String(format: "%.2f", first.end - first.start)) s), kept the rest, made again: \(step(talk, .leaveOut))")
            report.append("  \(step(talk, .episodeTranscript))")
            let mute = try XCTUnwrap(talk.madeMutes.first)
            let clock = try XCTUnwrap(talk.episodeClock)
            let at = clock.episodeTime(first.start).time
            let span = max(0.1, first.end - first.start)
            let rms = try loudness(folder(talk).appending(path: "episode.mp3"), from: at, length: span)
            let around = try loudness(folder(talk).appending(path: "episode.mp3"), from: max(0, at - 3), length: 2.5)
            XCTAssertLessThan(rms, -60, "the muted name is silent")
            report.append(String(format: "  the episode over the name (%.2f to %.2f s): RMS %.1f dB; the 2.5 s before it: %.1f dB (mute span %.2f to %.2f on the original)",
                                 at, at + span, rms, around, mute.start, mute.end))
            let srt = try String(contentsOf: folder(talk).appending(path: TranscriptFiles.fileName(.srt)), encoding: .utf8)
            let marks = srt.components(separatedBy: EpisodeTranscript.mutedWord).count - 1
            XCTAssertEqual(marks, 1, "one [name] in the captions")
            report.append("  \(EpisodeTranscript.mutedWord) in transcript.srt: \(marks)")
            XCTAssertTrue(model.approvalCheck(talk).canApprove, model.approvalCheck(talk).line ?? "")
            report.append("  Approve once each is decided and made: \(model.approvalCheck(talk).canApprove ? "allowed" : "refused")")
            let receipt = model.receiptPeople(talk)
            report.append("  receipt's People section: " + receipt.joined(separator: " | "))
        }
        report.append("")

        // Check 11: the notice for two-people-mixed is the fixed sentence (NotificationTests checks the wording).
        let notice = NoticeBuilder.content(.otherPeople, NoticeFacts(mixedRec))
        XCTAssertEqual(notice.body, NoticeBuilder.otherPeopleBody)
        report.append("Check 11, the notice for two-people-mixed: \"\(notice.title)\" / \"\(notice.body)\"")
        report.append("")

        // Nothing stored for strangers, after the choices too.
        for folders in [model.peopleFolders, PeopleFolders(support: AppPaths(mode: .live).applicationSupport)] {
            for forbidden in folders.forbidden { XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), forbidden.path) }
        }
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        XCTAssertEqual(jobs, [], "no job folder is left")
        report.append("Faces, Voices and FaceIndex folders: absent in development and live. Development Jobs folder: \(jobs.isEmpty ? "empty" : "NOT EMPTY \(jobs)")")
        for recording in [mixedRec, tracksRec, talk] {
            for json in [recording.choicesJSON, recording.peopleAppliedJSON, recording.namesSaidJSON].compactMap({ $0 }) {
                let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
                let longest = PeopleTests.numberArrays(value).map(\.count).max() ?? 0
                XCTAssertLessThan(longest, 128, "no print in the store")
            }
            try PeopleTests.assertNoPrintAndNoPicture(try Data(contentsOf: model.peopleFolders.peopleFile(for: recording.id)))
        }
        report.append("The store's choices, applied and names JSON and each people file: no list of 128 or more numbers, no picture.")
        report.append("")

        // Pictures: the People tab with its choices, light and dark; faces drawn as a test pattern (D1).
        var drawn: [String] = []
        model.faceCrops.useTestPattern = true
        for (scheme, appearance) in SnapshotRenderer.appearances {
            for (slug, recording) in [("two-people-mixed", mixedRec), ("two-people-tracks", tracksRec), ("talk-13-sep", talk)] {
                model.path = []
                model.selection = .group(.all)
                model.selectedRecordings = [recording.id]
                model.inspectorTab = .people
                try renderer.render(model: model, appearance: appearance, name: "m6c-people-\(slug)-\(scheme)")
                drawn.append("m6c-people-\(slug)-\(scheme)")
            }
        }
        report.append("Pictures in \(renderer.outputFolder.path): " + drawn.joined(separator: ", "))

        let after = files.map(fingerprint)
        XCTAssertEqual(after, before)
        report.append("Originals unchanged (size and modification date): \(after == before ? "yes" : "NO")")
        let activity = try model.context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.at)])).map(\.message)
        report += ["", "Activity lines:"] + activity.map { "  " + $0 }
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: renderer.outputFolder.appending(path: "acceptance-choices.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M6c finished.")
    }

    // MARK: Helpers

    /// A word as two transcriptions are compared: lowercased, letters, digits and apostrophes only.
    private func normal(_ word: String) -> String {
        String(word.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "'" })
    }

    /// A filler Parakeet writes in one run and not the next.
    private func isFiller(_ word: String) -> Bool { ["uh", "um", "uhm", "mm", "hmm"].contains(word) }

    /// A number, as digits or words ("200", "two", "hundred", "dollar").
    private func isNumber(_ word: String) -> Bool {
        word.allSatisfy(\.isNumber) || ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "twenty", "thirty", "forty",
                                          "fifty", "hundred", "thousand", "dollar", "dollars"].contains(word)
    }

    /// Lowercased five-word runs, punctuation dropped.
    private func grams(_ text: String) -> [String] {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        guard words.count >= 5 else { return [] }
        return (0...(words.count - 5)).map { words[$0..<($0 + 5)].joined(separator: " ") }
    }

    /// How many of `a` appear in `b` in the same order (the longest common subsequence).
    private func lcs(_ a: [String], _ b: [String]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: b.count + 1)
        for x in a {
            var current = [Int](repeating: 0, count: b.count + 1)
            for (j, y) in b.enumerated() { current[j + 1] = x == y ? previous[j] + 1 : max(previous[j + 1], current[j]) }
            previous = current
        }
        return previous[b.count]
    }

    /// An MP3 transcribed again, as Prakriti transcribes: mono 16 kHz, then Parakeet.
    private func transcribe(_ mp3: URL, in work: URL, name: String) throws -> String {
        let wav = work.appending(path: "\(name).wav")
        try runTool(ToolPaths.standard.ffmpeg, ["-y", "-v", "error", "-i", mp3.path, "-ac", "1", "-ar", "16000", wav.path])
        try runTool(ToolPaths.standard.parakeet, [wav.path, "--output-dir", work.path, "--output-format", "txt", "--output-template", "\(name)-retold"])
        defer { try? FileManager.default.removeItem(at: wav) }
        return try String(contentsOf: work.appending(path: "\(name)-retold.txt"), encoding: .utf8)
    }

    /// The RMS level of a stretch of a file, in dB (-inf for digital silence, reported as -200).
    private func loudness(_ file: URL, from start: Double, length: Double) throws -> Double {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-nostats", "-ss", String(format: "%.3f", start), "-t", String(format: "%.3f", length), "-i", file.path,
                             "-af", "astats=measure_overall=RMS_level:measure_perchannel=none", "-f", "null", "-"]
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard let line = text.split(separator: "\n").last(where: { $0.contains("RMS level dB") }) else { return 0 }
        let value = line.split(separator: ":").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return value == "-inf" ? -200 : Double(value) ?? 0
    }

    private func runTool(_ tool: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ToolPaths.searchPath + ":" + (environment["PATH"] ?? "")
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "\(tool.lastPathComponent) failed")
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
