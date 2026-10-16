@preconcurrency import AVFoundation
import CoreImage
import Foundation
import SwiftData
import Vision
import XCTest
@testable import Prakriti

/// v2 part M10b's acceptance (docs/v2/PLAN.md M10, check 3, and the left-out microphone track), on the fixtures through the app's own
/// runner, in development, with the edited video and the Timelines on:
///
/// - **two-people-mixed.mp4**, made once with everyone included (the timelines' media a clone), then with Gabriel named as teaching
///   and everyone else set to Leave Out (the corner face hidden, the second voice cut) and made again. The timelines must be kept,
///   pointing at privacy-safe media: `grep -c "Studio Recordings"` over both files prints 0 and neither names the fixture; Vision on
///   the media, five frames a second, finds no face inside the hidden track's place; Parakeet on the media (each track, and the
///   removed stretches alone) hears 0 of the `say` paragraph's five-word runs; the media is the used ranges plus 2 s handles, to the
///   frame. Both files valid against Final Cut Pro's DTDs, the lint clean in place, the media's own checks passed inside the gate.
/// - **two-people-tracks.mov** (the OBS layout: the mix, Gabriel's microphone, the second voice's microphone), the same way: the
///   second voice's own microphone track is not in the media at all, and Parakeet hears 0 runs on every track it keeps.
/// - **For the round trips (PLAN checks 6 and 7, Ivan's):** the same two-people-mixed timelines, and the 13 Sep excerpt's (M10a's,
///   whose plan has push-ins), written again with push-ins as moves into `~/Prakriti/Dev/Round trip v2-m10b/`, never into the
///   recording's own folder, with the five frame times to compare listed in the report.
///
/// Frames of the fixtures (Gabriel's talks) are measured, never looked at (PLAN section 11, D1); one frame of the media is written to
/// `for-ivan/` and listed for Ivan. Nothing goes to a cloud provider.
///
///   cd ~/Code/prakriti/mac && make accept-timeline-people MILESTONE=v2-m10b
@MainActor
final class TimelinePeopleAcceptanceTests: XCTestCase {
    private var verdicts: [(String, Bool, String)] = []
    private var report: [String] = []

    private func verdict(_ name: String, _ pass: Bool, _ measured: String) {
        verdicts.append((name, pass, measured))
        XCTAssertTrue(pass, "\(name): \(measured)")
    }

    func testPrivacySafeTimelineMedia() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "timeline-people" else {
            throw XCTSkip("Reads the two-people fixtures. Run it with: cd ~/Code/prakriti/mac && make accept-timeline-people MILESTONE=v2-m10b")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fixtures = home.appending(path: "Prakriti/Dev/Fixtures", directoryHint: .isDirectory)
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)
        let roundTrip = home.appending(path: "Prakriti/Dev/Round trip v2-m10b", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: roundTrip)
        try FileManager.default.createDirectory(at: roundTrip, withIntermediateDirectories: true)
        let started = Date()

        let mixed = try await run(fixture: fixtures.appending(path: "two-people-mixed.mp4"), paths: paths, fixtures: fixtures, forIvan: forIvan, roundTrip: roundTrip)
        report.append("")
        _ = try await run(fixture: fixtures.appending(path: "two-people-tracks.mov"), paths: paths, fixtures: fixtures, forIvan: forIvan, roundTrip: nil)
        report.append("")
        try await excerptRoundTrip(paths: paths, home: home, roundTrip: roundTrip)
        report.append("")
        report.append(String(format: "Whole run: %.0f s. two-people-mixed's privacy-safe media: %@", Date().timeIntervalSince(started), mixed))

        let lines = verdicts.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0): \($0.2)" }
        let text = (["v2 part M10b acceptance (privacy-safe timeline media), \(Date().formatted(date: .abbreviated, time: .standard))", ""] + lines
                    + ["", verdicts.allSatisfy(\.1) ? "Every check passed." : "\(verdicts.filter { !$0.1 }.count) check(s) failed.", "", "Details"] + report)
            .joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-timeline-people.txt"), atomically: true, encoding: .utf8)
        print(text)
    }

    /// The last part of M10, so the whole talks (PLAN, Wed 14 Oct note): the REAL 13 Sep and 6 Sep talks made in development with the
    /// edited video and the Timelines on (Clear, Gabriel teaching, the parts of each talk from `BeatsCache`, else no parts asked for):
    /// both timelines valid and clean in place, the timeline the video's length in frames, the media a clone. Then the 13 Sep talk with
    /// every other face set to Hide Face (up to 6 at once after 12:39) made again: the timelines on privacy-safe media of a whole talk,
    /// its checks passed in the gate, its size and speed measured (PLAN R6, research 5.5's rule of thumb). Frames measured only.
    ///
    ///   cd ~/Code/prakriti/mac && make accept-timeline-full MILESTONE=v2-m10b
    func testTimelinesForTheWholeTalks() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "timeline-full" else {
            throw XCTSkip("Reads the whole 13 Sep and 6 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-timeline-full MILESTONE=v2-m10b")
        }
        let paths = AppPaths(mode: .development)
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for (day, hide) in [("2026-09-13/2026-09-13 18-25-44.mp4", true), ("2026-09-06/2026-09-06 18-06-33.mp4", false)] {
            let talk = paths.studioRecordings.appending(path: day)
            XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
            let before = fingerprint(talk)
            let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
            _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
            model.runner.stableWait = .seconds(2)
            model.notifier.poster = nil
            model.settings.provider[.planning] = .lmStudio
            let cloudCalls = CallCounter()
            model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
            let teacher = Person(name: "Gabriel Galindo")
            teacher.role = .teacher
            model.context.insert(teacher)
            let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: talk)
            recording.kind = .talk
            try model.context.save()
            model.setTeacher(teacher, for: recording)
            model.setOutput(.editedVideo, on: true, for: recording)
            model.setOutput(.timelines, on: true, for: recording)
            let name = talk.deletingPathExtension().lastPathComponent
            let folder = paths.outputs.appending(path: name, directoryHint: .isDirectory)
            precondition(folder.path.hasPrefix(paths.outputs.path + "/"), "development outputs only")
            if let beats = BeatsCache.seed(name, folder: folder) {
                report.append("\(name): the parts of the talk from the cache (\(beats.line)).")
            } else {
                model.runner.askForBeats = false
                report.append("\(name): no cached parts for this transcript, so none were asked for.")
            }
            var started = Date()
            await model.runner.process(recording, trigger: .byHand)
            let made = Date().timeIntervalSince(started)
            let video = try XCTUnwrap(recording.video, "\(name): the video (\(recording.videoProblem ?? ""))")
            let plan = try XCTUnwrap(EditPlan.read(folder: folder.path))
            let timeline = folder.appending(path: TimelineExport.folderName, directoryHint: .isDirectory)
            let record = try XCTUnwrap(TimelineExport.Record.read(timeline), "\(name): the timelines (\(recording.latestRun?.steps.first { $0.name == PipelineStep.timelines.title }?.detail ?? ""))")
            let frames = EditTimeline(plan: plan, pictureFrames: try await CompositionBuilder.pictureFrames(original: talk, plan: plan)).totalFrames
            try await validTimelines(timeline, name: "\(name), whole talk, everyone included")
            verdict("\(name), whole talk: the timelines are the video's length in frames and point at a clone, proved per file",
                    record.frames == frames && record.mediaCloned && TimelineMedia.isClone(timeline.appending(path: "Media/\(talk.lastPathComponent)"), of: talk),
                    String(format: "%@ %lld frames of the video's %lld (%@); the make took %.0f s", record.summary, record.frames, frames, Format.timecode(video.duration), made))
            if hide {
                _ = model.setAllUnnamed(.hideFace, in: recording)
                started = Date()
                await model.runner.process(recording, trigger: .makeAgain)
                guard let again = recording.video else {
                    // The edited video's own gate (part M8d) can refuse the make before any timeline is written: then there is no
                    // privacy-safe media of the whole talk to measure. Reported, not hidden.
                    report.append("\(name), other faces set to Hide Face: NOT MEASURED. The edited video was refused by its own gate (part M8d), "
                                  + "so no timeline was written: \(recording.videoProblem ?? "no reason"). The make took \(Int(Date().timeIntervalSince(started))) s.")
                    verdict("\(name): nothing sent to a cloud provider; the original unchanged (size and date)", cloudCalls.count == 0 && fingerprint(talk) == before,
                            "\(cloudCalls.count) calls; \(fingerprint(talk))")
                    try? FileManager.default.removeItem(at: folder.appending(path: "Versions"))
                    continue
                }
                let safe = try XCTUnwrap(TimelineExport.Record.read(timeline), "\(name): privacy-safe timelines (\(recording.latestRun?.steps.first { $0.name == PipelineStep.timelines.title }?.detail ?? ""))")
                let step = recording.latestRun?.steps.first { $0.name == PipelineStep.timelines.title }
                try await validTimelines(timeline, name: "\(name), whole talk, other faces hidden")
                let media = timeline.appending(path: TimelineMedia.folderName).appending(path: safe.mediaName)
                let bytes = (try? media.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let seconds = safe.mediaSeconds ?? 0
                verdict("\(name), whole talk with \(again.hiddenFaces ?? 0) face rows hidden: the timelines on privacy-safe media, its checks passed in the gate",
                        safe.privacySafe == true && !safe.mediaCloned && safe.mediaCheck?.whole == true && safe.mediaCheck?.picture?.passed == true
                            && Pipeline.madeFiles(in: timeline.appending(path: TimelineMedia.folderName)) == [safe.mediaName],
                        String(format: "%@ media %.1f s (%d ranges) made in %.0f s (%.1f times real time), %d bytes, %.1f Mbps, %.1f GB an hour; %@; the timelines step %.0f s, the make %.0f s",
                               safe.summary, seconds, safe.mediaRanges ?? 0, safe.mediaRenderSeconds ?? 0, seconds / max(0.001, safe.mediaRenderSeconds ?? 1), bytes,
                               Double(bytes) * 8 / max(0.001, seconds) / 1e6, Double(bytes) / max(0.001, seconds) * 3600 / 1e9,
                               safe.mediaCheck?.picture?.line ?? "picture not checked", step?.seconds ?? 0, Date().timeIntervalSince(started)))
            }
            verdict("\(name): nothing sent to a cloud provider; the original unchanged (size and date)", cloudCalls.count == 0 && fingerprint(talk) == before,
                    "\(cloudCalls.count) calls; \(fingerprint(talk))")
        }
        let lines = verdicts.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0): \($0.2)" }
        let text = (["v2 part M10b acceptance, the whole talks, \(Date().formatted(date: .abbreviated, time: .standard))", ""] + lines + ["", "Details"] + report)
            .joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-timeline-full.txt"), atomically: true, encoding: .utf8)
        print(text)
    }

    /// Both files valid against Final Cut Pro's DTDs and clean under the lint in place.
    private func validTimelines(_ timeline: URL, name: String) async throws {
        guard let dtds = try FCPXMLTests.dtds() else { return }
        var lines: [String] = []
        var pass = true
        for version in FCPXMLVersion.allCases {
            let file = timeline.appending(path: version.fileName)
            let xml = try String(contentsOf: file, encoding: .utf8)
            let dtd = await FCPXMLLint.validate(file, version: version, dtds: dtds)
            let problems = FCPXMLLint.check(xml)
            pass = pass && dtd == nil && problems.isEmpty && !xml.contains("Studio Recordings") && !xml.contains("Studio%20Recordings")
            lines.append("\(version.rawValue) " + (dtd ?? "valid") + ", \(problems.count) lint problems")
        }
        verdict("\(name): both files valid against Final Cut Pro's DTDs, clean under the lint in place, never the Studio Recordings folder", pass,
                lines.joined(separator: "; "))
    }

    /// One fixture: everyone included, then the second person left out; returns a line about the media.
    private func run(fixture: URL, paths: AppPaths, fixtures: URL, forIvan: URL, roundTrip: URL?) async throws -> String {
        let name = fixture.lastPathComponent
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.path), "missing: \(fixture.path) (cd ~/Code/prakriti/mac && make fixtures)")
        let before = fingerprint(fixture)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.runner.askForBeats = false
        model.notifier.poster = nil
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        model.settings.provider[.planning] = .lmStudio
        model.log.write("Acceptance test for v2 part M10b (privacy-safe timeline media) on \(name) started.")
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        let outputFolder = paths.outputs.appending(path: fixture.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        precondition(outputFolder.path.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        try? FileManager.default.removeItem(at: outputFolder)
        let recording = Recording(filePath: fixture.path, recordedAt: Date(), foundAt: Date(), kind: .talk)
        model.context.insert(recording)
        recording.source = model.source(containing: fixture)
        try model.context.save()
        model.setOutput(.transcript, on: true, for: recording)
        model.setOutput(.editedVideo, on: true, for: recording)
        model.setOutput(.timelines, on: true, for: recording)
        try model.context.save()

        // 1. Everyone included: the timelines point at a clone.
        await model.runner.process(recording, trigger: .byHand)
        let folder = try XCTUnwrap(recording.outputFolder.map { URL(fileURLWithPath: $0, isDirectory: true) })
        let timeline = folder.appending(path: TimelineExport.folderName, directoryHint: .isDirectory)
        let first = TimelineExport.Record.read(timeline)
        verdict("\(name), everyone included: the timelines point at a clone of the recording, as in M10a",
                first?.mediaCloned == true && first?.privacySafe == nil && TimelineMedia.isClone(timeline.appending(path: "Media/\(name)"), of: fixture),
                "\(first?.summary ?? "no timelines: \(recording.latestRun?.steps.first { $0.name == PipelineStep.timelines.title }?.detail ?? "")") media \(first?.mediaName ?? "none"), cloned \(first?.mediaCloned ?? false)")

        // 2. Gabriel teaching, everyone else left out: the corner face hidden, the second voice cut, the timelines on privacy-safe media.
        model.setTeacher(gabriel, for: recording)
        _ = model.setAllUnnamed(.leaveOut, in: recording)
        report.append("\(name). Choices: " + recording.personKeys.map { "\(recording.label(for: $0)) \(recording.choices.choice($0, for: .video).title)" }.joined(separator: ", "))
        let made = Date()
        await model.runner.process(recording, trigger: .makeAgain)
        for step in recording.latestRun?.steps ?? [] where [PipelineStep.renderVideo, .checkVideo, .timelines].map(\.title).contains(step.name) {
            report.append(String(format: "  step %@: %@, %.1f s. %@", step.name, step.state.rawValue, step.seconds ?? 0, step.detail ?? ""))
        }
        let video = try XCTUnwrap(recording.video, "the video (\(recording.videoProblem ?? ""))")
        let plan = try XCTUnwrap(EditPlan.read(folder: folder.path))
        let record = try XCTUnwrap(TimelineExport.Record.read(timeline), "the timelines (\(recording.latestRun?.steps.first { $0.name == PipelineStep.timelines.title }?.detail ?? ""))")
        let mediaName = TimelineMedia.privacySafeName(fixture)
        let media = timeline.appending(path: TimelineMedia.folderName).appending(path: mediaName)
        let check = record.mediaCheck
        verdict("\(name): the timelines are kept, on privacy-safe media, after a make that hides and leaves out",
                record.privacySafe == true && !record.mediaCloned && record.madeAt > made && (video.hiddenFaces ?? 0) >= 1 && (video.leftOutVoices ?? 0) >= 1
                    && Pipeline.madeFiles(in: timeline.appending(path: TimelineMedia.folderName)) == [mediaName] && !TimelineMedia.isClone(media, of: fixture),
                "\(record.summary) media \(record.mediaName) only; video hides \(video.hiddenFaces ?? -1) face row(s), leaves out \(video.leftOutVoices ?? -1) voice(s)")
        verdict("\(name): the media's own checks passed inside the gate (whole, picture, sound, every replaced stretch)",
                check?.whole == true && check?.picture?.passed == true && check?.sound?.passed == true && check?.silenceProblems.isEmpty == true,
                "\(check?.wholeLine ?? "no check"); \(check?.picture?.line ?? "picture not checked") (\(check?.picture?.faces ?? -1) faces in \(check?.picture?.frames ?? -1) frames); "
                + "\(check?.sound?.line { "Voice \($0)" } ?? "sound not checked"); \(check?.replacedStretches ?? -1) replaced stretches, the loudest "
                + String(format: "%.1f dB over its room tone", check?.loudestOverRoomTone ?? .nan))
        for line in check?.sound?.matches ?? [] { report.append("    sound check: \(line)") }

        // Both files valid and clean in place; never the Studio Recordings folder or the fixture.
        var xmls: [String] = []
        if let dtds = try FCPXMLTests.dtds() {
            for version in FCPXMLVersion.allCases {
                let file = timeline.appending(path: version.fileName)
                let xml = try String(contentsOf: file, encoding: .utf8)
                xmls.append(xml)
                let dtd = await FCPXMLLint.validate(file, version: version, dtds: dtds)
                let problems = FCPXMLLint.check(xml)
                verdict("\(name): \(version.fileName) valid against \(version.dtdName) and clean under the lint in place (8 rules)", dtd == nil && problems.isEmpty,
                        (dtd ?? "valid") + "; " + (problems.isEmpty ? "0 problems" : problems.map(\.description).joined(separator: "; ")))
            }
        }
        // grep exits 1 when it counts 0, so it is run here and read whatever it exits with.
        let grep = try output(URL(fileURLWithPath: "/usr/bin/grep"), ["-c", "Studio Recordings"] + FCPXMLVersion.allCases.map { timeline.appending(path: $0.fileName).path })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let named = xmls.reduce(0) { $0 + $1.components(separatedBy: FCPXMLWriter.fileURL(fixture)).count - 1 + $1.components(separatedBy: fixture.path).count - 1 }
        let srcs = xmls.flatMap { xml -> [String] in
            ((try? XMLDocument(xmlString: xml, options: []).nodes(forXPath: "//media-rep/@src")) ?? []).compactMap(\.stringValue)
        }
        let inside = srcs.allSatisfy { URL(string: $0)?.path.hasPrefix(timeline.path + "/") == true }
        verdict("Check 3, \(name): grep -c \"Studio Recordings\" over both files prints 0, neither names the original, every src inside Timeline/",
                grep.split(separator: "\n").allSatisfy { $0.hasSuffix(":0") || $0 == "0" } && named == 0 && inside && xmls.count == 2,
                grep.replacingOccurrences(of: timeline.path + "/", with: "").replacingOccurrences(of: "\n", with: ", ") + "; the original named \(named) times; \(srcs.count) sources, all inside: \(inside)")

        // The media: the used ranges plus 2 s handles, to the frame.
        let pictureFrames = try await CompositionBuilder.pictureFrames(original: fixture, plan: plan)
        let videoTimeline = EditTimeline(plan: plan, pictureFrames: pictureFrames)
        let ranges = CleanedMedia.ranges(videoTimeline, pictureFrames: pictureFrames, handle: CleanedMedia.handleFrames(plan.frameDuration))
        let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-count_packets", "-show_entries",
                                                                          "stream=index,codec_type,codec_name,profile,pix_fmt,channels,nb_read_packets,duration,bit_rate",
                                                                          "-of", "compact=p=0", media.path], timeout: .seconds(300)).stdout
        let videoLine = probe.split(separator: "\n").first { $0.contains("codec_type=video") }.map(String.init) ?? ""
        let packets = Int64(videoLine.components(separatedBy: "nb_read_packets=").last.flatMap { Int64($0.prefix { $0.isNumber }) } ?? -1)
        let audioStreams = probe.split(separator: "\n").filter { $0.contains("codec_type=audio") }.count
        let bytes = (try? media.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let keptSeconds = videoTimeline.seconds(videoTimeline.keptFrames)
        verdict("Check 3, \(name): the media is the used ranges plus 2 s handles, to the frame; HEVC Main 10 and 24-bit PCM",
                packets == ranges.totalFrames && videoLine.contains("codec_name=hevc") && videoLine.contains("profile=Main 10") && videoLine.contains("yuv420p10le")
                    && probe.contains("pcm_s24le"),
                String(format: "%lld frames = %.3f s; the ranges %lld frames (%d ranges, %.3f s: %.3f s kept and the hold's frame, plus handles); %d bytes, %.1f Mbps; %@",
                       packets, Double(packets) * plan.frameDuration.seconds, ranges.totalFrames, ranges.pieces.count, ranges.duration, keptSeconds, bytes,
                       Double(bytes) * 8 / max(0.001, ranges.duration) / 1e6, probe.replacingOccurrences(of: "\n", with: "; ")))
        report.append(String(format: "  %@ media: %.1f s made in %.1f s (%.1f times real time); room tone and %d tracks kept, left out %@",
                             name, record.mediaSeconds ?? 0, record.mediaRenderSeconds ?? 0, (record.mediaSeconds ?? 0) / max(0.001, record.mediaRenderSeconds ?? 1),
                             audioStreams, "\(record.tracksLeftOut ?? [])"))

        // The left-out person's own microphone track (the tracks fixture): not in the media at all.
        let originalTracks = try await AVURLAsset(url: fixture).loadTracks(withMediaType: .audio).count
        if originalTracks > 1 {
            let leftTracks = (recording.voices?.voices ?? []).filter { (plan.people.leftOut).contains($0.id) }.compactMap(\.track)
            verdict("\(name): the left-out voice's own microphone track is left out of the media entirely",
                    !leftTracks.isEmpty && record.tracksLeftOut == leftTracks.sorted() && audioStreams == originalTracks - leftTracks.count,
                    "the recording has \(originalTracks) sound tracks; left out \(record.tracksLeftOut ?? []) (the voice step's \(leftTracks)); the media has \(audioStreams)")
        }

        // Vision on the media, five frames a second: no face inside the hidden track's place.
        let people = try XCTUnwrap(model.peopleFolders.read(recording.id))
        let names = recording.resolvedNameTable
        let hides: (Int?) -> Bool = { row in recording.choices.choice(PersonKey.face(row ?? 0, names: names), for: .video) != .include }
        let hiddenRows = Set(people.tracks.compactMap(\.person).filter { hides($0) })
        let hiddenTracks = people.tracks.filter { hides($0.person) }
        func hiddenBoxes(at time: Double) -> [FaceBox] {
            hiddenTracks.compactMap { track in
                let near = track.boxes.min { abs($0[0] - time) < abs($1[0] - time) }
                guard let near, abs(near[0] - time) <= 0.5 else { return nil }
                return FaceBox(x: near[1], y: near[2], width: near[3], height: near[4])
            }
        }
        let (frames, inHidden, variances, saved) = try await lookAtFaces(media, ranges: ranges, boxes: hiddenBoxes, original: fixture,
                                                                           forIvan: forIvan.appending(path: "m10b-\(fixture.deletingPathExtension().lastPathComponent)-media.png"))
        verdict("Check 3, \(name): Vision on the media, five frames a second, finds no face inside the hidden track's place",
                inHidden == 0 && frames > 100, "\(inHidden) faces in that place in \(frames) frames looked at; hidden rows \(hiddenRows.sorted()), \(hiddenTracks.count) tracks")
        if !variances.isEmpty {
            verdict("\(name): the hidden place's variance falls by 80% or more against the original's frame (measured, not looked at)",
                    variances.min() ?? 0 >= 0.8, variances.map { String(format: "%.1f%%", $0 * 100) }.joined(separator: ", ") + (saved.map { "; for Ivan: \($0)" } ?? ""))
        }

        // Parakeet on the media: every kept track whole, and the removed stretches alone.
        let scratch = FileManager.default.temporaryDirectory.appending(path: "accept-m10b-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let sayText = try String(contentsOf: fixtures.appending(path: "second-voice.txt"), encoding: .utf8)
        let asHeard = try Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))
        let allWords = EpisodeTranscript.sentences(json: asHeard)!.flatMap { EpisodeTranscript.words($0.tokens ?? []) }
            .filter { $0.contains { EpisodeTranscript.isWord($0.text) } }
            .map { (text: $0.map(\.text).joined(), at: EpisodeTranscript.position(start: $0.first!.start, end: $0.last!.end)) }
        let teacherWords = allWords.filter { word in !plan.people.cuts.contains { word.at >= $0.start && word.at <= $0.end } }
        let sayGrams = Set(grams(sayText)).subtracting(grams(teacherWords.map(\.text).joined(separator: " ")))
        var removed: [TimeRange] = []
        for piece in ranges.pieces {
            let a = ranges.seconds(piece.sourceFrame), b = ranges.seconds(piece.sourceFrame + piece.frames), at = ranges.seconds(piece.editFrame)
            for s in CleanedMedia.silenced(plan) where s.end > a && s.start < b {
                removed.append(TimeRange(start: at + max(a, s.start) - a, end: at + min(b, s.end) - a))
            }
        }
        var heardAll = 0, heardLines: [String] = []
        for index in 0..<audioStreams {
            let retold = try transcribe(media, map: "0:a:\(index)", in: scratch, name: "track-\(index)")
            let heard = sayGrams.intersection(grams(retold))
            heardAll += heard.count
            heardLines.append("sound track \(index + 1): \(heard.count) runs, \(retold.split(separator: " ").count) words")
        }
        var removedLine = "no removed stretch inside the ranges"
        if !removed.isEmpty {
            let retold = try transcribe(media, map: "0:a:0", in: scratch, name: "removed", only: removed)
            let heard = sayGrams.intersection(grams(retold))
            heardAll += heard.count
            removedLine = String(format: "the removed stretches alone (%d, %.1f s): %d runs, %d words heard", removed.count,
                                 removed.reduce(0) { $0 + $1.end - $1.start }, heard.count, retold.split(separator: " ").count)
        }
        verdict("Check 3, \(name): Parakeet on the media hears 0 runs of the say paragraph (every track, and the removed stretches alone)",
                heardAll == 0 && sayGrams.count > 20, "\(sayGrams.count) five-word runs looked for; " + heardLines.joined(separator: "; ") + "; " + removedLine)

        // Nothing stored for strangers; nothing to the cloud; the fixture unchanged.
        let forbidden = model.peopleFolders.forbidden.filter { FileManager.default.fileExists(atPath: $0.path) }
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        verdict("\(name): nothing stored for strangers (no Faces, Voices or FaceIndex folder, Jobs empty), nothing sent to a cloud provider",
                forbidden.isEmpty && jobs.isEmpty && cloudCalls.count == 0, "forbidden folders \(forbidden.map(\.lastPathComponent)); jobs \(jobs.count); cloud calls \(cloudCalls.count)")
        verdict("\(name): the fixture is unchanged (size and modification date)", fingerprint(fixture) == before, fingerprint(fixture))

        // For the round trips: the same timelines with push-ins as moves, into the round-trip folder (never the recording's own).
        if let roundTrip {
            let gate = model.videoPeople(recording)
            var setup = TimelineExport.Setup(original: fixture, plan: plan, videoFolder: folder.appending(path: VideoStep.folderName, directoryHint: .isDirectory),
                                             captionsName: video.captionsName, project: "Round trip, \(fixture.deletingPathExtension().lastPathComponent)",
                                             build: roundTrip.appending(path: ".building", directoryHint: .isDirectory),
                                             final: roundTrip.appending(path: fixture.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory),
                                             admitTo: roundTrip.appending(path: fixture.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory),
                                             hiddenFaces: video.hiddenFaces, leftOutVoices: video.leftOutVoices, animationsVerified: true)
            setup.people = CleanedMedia.People.from(file: people, gate: gate, plan: plan, folders: model.peopleFolders)
            setup.ffmpeg = RenderTests.ffmpeg()
            let trial = try await TimelineExport.make(setup, now: Date())
            report.append("  Round trip files (moves on): \(setup.final.path), \(trial.summary) push-in markers \(trial.pushInMarkers); "
                          + "frames to compare with the MP4 at " + fiveTimes(videoTimeline).map { Format.timecode($0) }.joined(separator: ", "))
        }
        model.log.write("Acceptance test for v2 part M10b on \(name) finished.")
        return String(format: "%.1f s, %d bytes", record.mediaSeconds ?? 0, bytes)
    }

    /// The 13 Sep excerpt's timelines (M10a's acceptance made them; everyone included, so a clone) written again with push-ins as
    /// moves into the round-trip folder, for Ivan's check 6.
    private func excerptRoundTrip(paths: AppPaths, home: URL, roundTrip: URL) async throws {
        let excerpt = home.appending(path: "Prakriti/Dev/Excerpts").appending(path: ViewerVideoAcceptanceTests.excerptName)
        let folder = paths.outputs.appending(path: excerpt.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        guard let plan = EditPlan.read(folder: folder.path), FileManager.default.fileExists(atPath: excerpt.path),
              let srt = Pipeline.madeFiles(in: folder.appending(path: VideoStep.folderName)).first(where: { $0.hasSuffix(".srt") }) else {
            report.append("13 Sep excerpt round-trip files: not written (run make accept-timeline first).")
            return
        }
        let final = roundTrip.appending(path: "13 Sep excerpt", directoryHint: .isDirectory)
        let setup = TimelineExport.Setup(original: excerpt, plan: plan, videoFolder: folder.appending(path: VideoStep.folderName, directoryHint: .isDirectory),
                                         captionsName: srt, project: "Round trip, 13 Sep excerpt", build: roundTrip.appending(path: ".building", directoryHint: .isDirectory),
                                         final: final, admitTo: final, hiddenFaces: 0, leftOutVoices: 0, animationsVerified: true)
        let record = try await TimelineExport.make(setup, now: Date())
        let xml = try String(contentsOf: final.appending(path: FCPXMLVersion.finalCut.fileName), encoding: .utf8)
        let moves = xml.components(separatedBy: "<keyframeAnimation>").count - 1
        let pushes = plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }.count
        verdict("Round-trip files for Ivan (checks 6 and 7): the 13 Sep excerpt with every push-in written as a move, valid and kept",
                record.pushInMarkers == 0 && moves == 2 * pushes && pushes > 0 && record.dtd == ["1.14": "valid", "1.10": "valid"],
                "\(final.path): \(record.summary) \(pushes) push-ins, \(moves) keyed parameters (position and scale), \(record.pushInMarkers) markers")
        let timeline = EditTimeline(plan: plan, pictureFrames: try await CompositionBuilder.pictureFrames(original: excerpt, plan: plan))
        report.append("13 Sep excerpt round-trip files: frames to compare with its MP4 at " + fiveTimes(timeline).map { Format.timecode($0) }.joined(separator: ", ")
                      + "; push-ins at " + plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }.compactMap { v in v.in.flatMap { timeline.editTime($0) } }
                        .map { Format.timecode($0) }.joined(separator: ", "))
    }

    /// Five moments of the video to compare across apps: 10%, 30%, 50%, 70% and 90% of the way.
    private func fiveTimes(_ timeline: EditTimeline) -> [Double] {
        [0.1, 0.3, 0.5, 0.7, 0.9].map { (timeline.duration * $0 * 10).rounded() / 10 }
    }

    // MARK: Measures

    /// Every face Vision finds in the media five frames a second, mapped to the original's moment; how many sit inside a hidden
    /// place; and the hidden place's fall in variance against the original's frame at six moments. One frame written for Ivan.
    private func lookAtFaces(_ media: URL, ranges: EditTimeline, boxes: (Double) -> [FaceBox], original: URL, forIvan: URL) async throws
        -> (frames: Int, inHidden: Int, falls: [Double], saved: String?) {
        let asset = AVURLAsset(url: media)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        let detect = DetectFaceRectanglesRequest(.revision4)
        var next = 0.0, frames = 0, inHidden = 0
        var hiddenMoments: [(Double, Double, FaceBox)] = []
        while let sample = try await provider.next() {
            let time = sample.presentationTimeStamp.seconds
            guard time + 0.0001 >= next else { continue }
            next += 0.2
            let image: CIImage? = sample.withUnsafeSampleBuffer { CMSampleBufferGetImageBuffer($0).map { CIImage(cvPixelBuffer: $0) } }
            guard let image, let source = ranges.originalTime(time) else { continue }
            frames += 1
            let here = boxes(source)
            let faces = try await detect.perform(on: image).map { FaceGeometry.fromVision($0.boundingBox.cgRect) }
            inHidden += faces.filter { face in here.contains { FaceGeometry.padded($0, by: FaceHide.pad).contains(x: face.centerX, y: face.centerY) } }.count
            if let box = here.first { hiddenMoments.append((time, source, box)) }
        }
        var falls: [Double] = []
        var saved: String?
        if !hiddenMoments.isEmpty {
            let step = max(1, hiddenMoments.count / 6)
            for (k, moment) in stride(from: 0, to: hiddenMoments.count, by: step).map({ hiddenMoments[$0] }).prefix(6).enumerated() {
                let made = try await RenderTests.frame(asset, at: CMTime(seconds: moment.0, preferredTimescale: 30000))
                let was = try await RenderTests.frame(AVURLAsset(url: original), at: CMTime(seconds: moment.1, preferredTimescale: 30000))
                let a = PeopleInVideoTests.variance(was, in: moment.2), b = PeopleInVideoTests.variance(made, in: moment.2)
                falls.append(1 - b / max(a, 0.001))
                report.append(String(format: "    media %.2f s (original %.2f s): hidden place variance %.1f in the original, %.1f in the media", moment.0, moment.1, a, b))
                if k == 2 {
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.requestedTimeToleranceBefore = .zero
                    generator.requestedTimeToleranceAfter = .zero
                    let image = try await generator.image(at: CMTime(seconds: moment.0, preferredTimescale: 30000)).image
                    if let destination = CGImageDestinationCreateWithURL(forIvan as CFURL, "public.png" as CFString, 1, nil) {
                        CGImageDestinationAddImage(destination, image, nil)
                        CGImageDestinationFinalize(destination)
                        saved = forIvan.path
                    }
                }
            }
        }
        return (frames, inHidden, falls, saved)
    }

    /// Lowercased five-word runs, punctuation dropped.
    private func grams(_ text: String) -> [String] {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        guard words.count >= 5 else { return [] }
        return (0...(words.count - 5)).map { words[$0..<($0 + 5)].joined(separator: " ") }
    }

    /// One sound track of `file` (or only the stretches `only`, joined) transcribed by Parakeet, as Prakriti transcribes: mono 16 kHz.
    private func transcribe(_ file: URL, map: String, in work: URL, name: String, only: [TimeRange] = []) throws -> String {
        let wav = work.appending(path: "\(name).wav")
        var arguments = ["-y", "-v", "error", "-i", file.path, "-map", map, "-vn", "-ac", "1", "-ar", "16000"]
        if !only.isEmpty {
            let select = only.map { String(format: "between(t,%.3f,%.3f)", $0.start, $0.end) }.joined(separator: "+")
            arguments += ["-af", "aselect='\(select)',asetpts=N/SR/TB"]
        }
        try runTool(ToolPaths.standard.ffmpeg, arguments + [wav.path])
        defer { try? FileManager.default.removeItem(at: wav) }
        try runTool(ToolPaths.standard.parakeet, [wav.path, "--output-dir", work.path, "--output-format", "txt", "--output-template", "\(name)-retold"])
        return (try? String(contentsOf: work.appending(path: "\(name)-retold.txt"), encoding: .utf8)) ?? ""
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

    /// A tool's standard output, whatever it exits with.
    private func output(_ tool: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
