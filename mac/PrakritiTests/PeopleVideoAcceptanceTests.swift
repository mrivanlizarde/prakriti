@preconcurrency import AVFoundation
import CoreImage
import Foundation
import ImageIO
import SwiftData
import Vision
import XCTest
@testable import Prakriti

/// v2 part M8d's acceptance (docs/v2/PLAN.md M8: check 6, and check 3 again on two-people-mixed), on the fixture through the
/// app's own runner, in development:
///
/// - The fixture made with the Edited video on, everyone included (the default); then Gabriel named as teaching and everyone
///   else set to Leave Out, and made again. The video must be made and kept: the corner face hidden in every frame, the second
///   voice's speech cut from picture and sound, and both output checks run inside the gate and pass.
/// - Check 3 on its MP4: H.264 High, 1920 by 1080, 30000/1001, BT.709, AAC 48 kHz stereo (320 kbps, PLAN's 384 being out of
///   the Mac's reach), 16 Mbps within 10%, moov before mdat, no edit list on the picture, -14 LUFS within 1 LU, true peak at or
///   under -1 dBTP, the last 5 s decode, and the Ready checklist PASS but the MISSING title, description and chapters.
/// - Check 6: the MP4 transcribed again by Parakeet holds 0 of the `say` paragraph's five-word runs; measured from outside, no
///   face is found inside the corner's place and its variance falls by 80% or more against the original's frame; the Viewer's
///   composition draws the same frames (38 dB); and with hiding switched off for that track (a test switch), the gate stops the
///   video with the time of the first face it cannot account for, and keeps nothing.
/// - Nothing stored for strangers: no Faces, Voices or FaceIndex folder, Jobs empty.
///
/// Frames of the fixture (Gabriel's talks) are measured, never looked at (this run's instructions, PLAN section 11, D1): one
/// frame of the made video is written to `for-ivan/` and listed for Ivan.
///
///   cd ~/Code/prakriti/mac && make accept-people-video MILESTONE=v2-m8d
@MainActor
final class PeopleVideoAcceptanceTests: XCTestCase {
    func testPeopleInTheVideoOfTwoPeopleMixed() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "people-video" else {
            throw XCTSkip("Reads the two-people fixture. Run it with: cd ~/Code/prakriti/mac && make accept-people-video MILESTONE=v2-m8d")
        }
        let paths = AppPaths(mode: .development)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        model.notifier.poster = nil
        model.log.write("Acceptance test for v2 part M8d (people in the video) started.")
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        let fixtures = home.appending(path: "Prakriti/Dev/Fixtures", directoryHint: .isDirectory)
        let mixed = fixtures.appending(path: "two-people-mixed.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mixed.path), "missing: \(mixed.path) (cd ~/Code/prakriti/mac && make fixtures)")
        let before = fingerprint(mixed)
        var verdicts: [(String, Bool, String)] = []
        var report: [String] = []
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            verdicts.append((name, pass, measured))
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let scratch = FileManager.default.temporaryDirectory.appending(path: "accept-m8d-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        // The first make: everyone included (the default), the video on.
        let outputFolder = paths.outputs.appending(path: mixed.deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
        precondition(outputFolder.path.hasPrefix(paths.outputs.path + "/"))
        try? FileManager.default.removeItem(at: outputFolder)
        let recording = Recording(filePath: mixed.path, recordedAt: Date(), foundAt: Date(), kind: .talk)
        model.context.insert(recording)
        recording.source = model.source(containing: mixed)
        try model.context.save()
        model.setOutput(.podcastEpisode, on: true, for: recording)
        model.setOutput(.transcript, on: true, for: recording)
        model.setOutput(.editedVideo, on: true, for: recording)
        try model.context.save()
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let first = try XCTUnwrap(recording.video, "the first video (\(recording.videoProblem ?? ""))")
        report.append("First make, everyone included: \(first.fileName), \(Format.timecode(first.duration)); hides \(first.hiddenFaces ?? -1), leaves out \(first.leftOutVoices ?? -1); "
                      + "picture check \(first.pictureCheck == nil ? "not needed" : "ran"), sound check \(first.soundCheck == nil ? "not needed" : "ran").")
        verdict("Everyone included: the video is made and nobody is hidden", first.hiddenFaces == 0 && first.leftOutVoices == 0 && first.pictureCheck == nil,
                "hides \(first.hiddenFaces ?? -1) faces, leaves out \(first.leftOutVoices ?? -1) voices")

        // The rows: the main face is on screen longest, the corner face the other.
        let people = try XCTUnwrap(model.peopleFolders.read(recording.id))
        let mainRow = try XCTUnwrap(recording.faces?.people.first?.id)
        let cornerRow = try XCTUnwrap(recording.faces?.people.first { $0.id != mainRow }?.id)
        let cornerTracks = people.tracks.filter { $0.person == cornerRow }
        let cornerFirst = try XCTUnwrap(cornerTracks.compactMap { $0.boxes.first?.first }.min())
        let cornerLast = try XCTUnwrap(cornerTracks.compactMap { $0.boxes.last?.first }.max())
        report.append(String(format: "Rows: main %d, corner %d (%d tracks, first seen %.2f s, last %.2f s). Voices: %@.", mainRow, cornerRow, cornerTracks.count,
                             cornerFirst, cornerLast, (recording.voices?.voices ?? []).map { "\($0.label) \(String(format: "%.1f", $0.speaking)) s" + ($0.face.map { " face \($0)" } ?? "") }.joined(separator: "; ")))

        // Gabriel teaching, everyone else left out: the corner face hidden, the second voice cut.
        model.setTeacher(gabriel, for: recording)
        model.setAllUnnamed(.leaveOut, in: recording)
        let refusal = model.videoRefusal(recording)
        verdict("Make Video is not refused with someone left out (M8b's refusal lifted)", refusal == nil, refusal ?? "not refused")
        report.append("Choices: " + recording.personKeys.map { "\(recording.label(for: $0)) \(recording.choices.choice($0, for: .video).title)" }.joined(separator: ", "))
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        for step in recording.latestRun?.steps ?? [] where [PipelineStep.planEdit, .renderVideo, .checkVideo, .leaveOut, .audioCheck].map(\.title).contains(step.name) {
            report.append(String(format: "  step %@: %@, %.1f s. %@", step.name, step.state.rawValue, step.seconds ?? 0, step.detail ?? ""))
        }
        let record = try XCTUnwrap(recording.video, "the video with the corner hidden and the voice left out (\(recording.videoProblem ?? ""))")
        let folder = try XCTUnwrap(recording.outputFolder.map { URL(fileURLWithPath: $0, isDirectory: true) })
        let video = folder.appending(path: VideoStep.folderName, directoryHint: .isDirectory)
        let mp4 = video.appending(path: record.fileName)
        let plan = try XCTUnwrap(EditPlan.read(folder: folder.path))
        let timeline = EditTimeline(plan: plan)
        let hidden = try XCTUnwrap(HiddenFaces.read(folder: folder), "video-hiding.json beside the plan")
        let picture = try XCTUnwrap(record.pictureCheck, "the picture output check ran")
        let sound = try XCTUnwrap(record.soundCheck, "the sound output check ran")
        verdict("The video is made and kept with the corner face hidden and the second voice left out",
                (record.hiddenFaces ?? 0) >= 1 && (record.leftOutVoices ?? 0) >= 1 && FileManager.default.fileExists(atPath: mp4.path) && !plan.people.leftOut.isEmpty,
                "\(record.fileName), \(Format.timecode(record.duration)); hides \(record.hiddenFaces ?? 0) face row(s), leaves out voice(s) \(plan.people.leftOut); "
                + "people cuts in the plan: " + plan.people.cuts.map { String(format: "%.2f to %.2f", $0.start, $0.end) }.joined(separator: ", ")
                + "; hidden regions on \(hidden.frames.count) frames (\(hidden.how.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")), "
                + String(format: "%.1f s)", hidden.seconds))
        verdict("Check 6: the picture output check passes", picture.passed, picture.line + String(format: " (%d faces, %.1f s)", picture.faces, picture.seconds))
        verdict("Check 6: the sound output check passes", sound.passed, sound.line { "Voice \($0)" } + String(format: " (%.1f s)", sound.seconds))
        for match in sound.matches { report.append("    sound check: \(match)") }

        // Check 3, on this MP4.
        let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-show_format", "-show_streams", "-of", "json", mp4.path], timeout: .seconds(120)).stdout
        var measured = ReadyChecklist.Measured()
        ReadyChecklist.read(probe: probe, into: &measured)
        let layout = try Mp4Boxes.read(mp4)
        let loud = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-nostats", "-i", mp4.path, "-vn", "-af", "ebur128=peak=true", "-f", "null", "-"],
                                            timeout: .seconds(600)).stderr
        let loudness = try XCTUnwrap(Measure.ebur128(stderr: loud))
        let tail = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-v", "error", "-sseof", "-5", "-i", mp4.path, "-f", "null", "-"], timeout: .seconds(120)).stderr
        verdict("Check 3: H.264 High, 1920 by 1080, 30000/1001, BT.709 tags",
                measured.videoCodec == "h264" && measured.profile == "High" && measured.width == 1920 && measured.height == 1080 && measured.frameRate == "30000/1001"
                    && measured.colorPrimaries == "bt709" && measured.colorTransfer == "bt709" && measured.colorSpace == "bt709",
                "\(measured.videoCodec) \(measured.profile), \(measured.width)x\(measured.height), \(measured.frameRate), \(measured.colorPrimaries)/\(measured.colorTransfer)/\(measured.colorSpace)")
        let rate = measured.videoBitrate ?? 0
        verdict("Check 3: video bitrate within 10% of 16 Mbps", abs(rate - 16e6) / 16e6 <= 0.10, String(format: "%.2f Mbps", rate / 1e6))
        verdict("Check 3: AAC-LC 48 kHz stereo (320 kbps: PLAN's 384 is not reachable on this Mac, accepted 14 Oct)",
                measured.audioCodec == "aac" && measured.audioProfile == "LC" && measured.sampleRate == 48_000 && measured.channels == 2,
                String(format: "%@-%@, %d Hz, %d channels, %.1f kbps", measured.audioCodec, measured.audioProfile, measured.sampleRate, measured.channels, (measured.audioBitrate ?? 0) / 1000))
        verdict("Check 3: moov before mdat, no elst on the video track", layout.indexBeforeMedia && layout.videoEditLists == 0,
                "top level " + layout.topLevel.map(\.type).joined(separator: " ") + "; picture edit lists \(layout.videoEditLists)")
        verdict("Check 3: -14 LUFS within 1 LU, true peak at or under -1 dBTP", abs(loudness.integratedLUFS + 14) <= 1 && loudness.truePeakDBFS <= -1,
                String(format: "%.1f LUFS, %.1f dBTP", loudness.integratedLUFS, loudness.truePeakDBFS))
        verdict("Check 3: the last 5 s decode with no error", tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, tail.isEmpty ? "no error" : String(tail.prefix(200)))
        let failing = record.checklist.filter { $0.status == .fail }
        let missing = Set(record.checklist.filter { $0.status == .missing }.map(\.item))
        verdict("Check 3: Ready checklist PASS on every line except MISSING title fields (writing off)",
                failing.isEmpty && missing.isSubset(of: ["Title", "Description", "Chapters"]),
                "\(record.passed) PASS, \(record.missing) MISSING (\(missing.sorted().joined(separator: ", "))), \(record.failed) FAIL"
                + (failing.isEmpty ? "" : ": " + failing.map(\.text).joined(separator: "; ")))
        report.append("Ready checklist:")
        report += record.checklist.map { "    " + $0.text }
        verdict("The length is the sum of the kept spans within one frame",
                abs((measured.videoDuration ?? 0) - plan.keptSeconds) <= plan.frameDuration.seconds + 0.0005,
                String(format: "picture %.3f s, kept spans %.3f s", measured.videoDuration ?? 0, plan.keptSeconds))

        // Check 6: the MP4 transcribed again; the second voice's five-word runs.
        let sayText = try String(contentsOf: fixtures.appending(path: "second-voice.txt"), encoding: .utf8)
        let asHeard = try Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))
        let allWords = EpisodeTranscript.sentences(json: asHeard)!.flatMap { EpisodeTranscript.words($0.tokens ?? []) }
            .filter { $0.contains { EpisodeTranscript.isWord($0.text) } }
            .map { (text: $0.map(\.text).joined(), at: EpisodeTranscript.position(start: $0.first!.start, end: $0.last!.end)) }
        let teacherWords = allWords.filter { word in !plan.people.cuts.contains { word.at >= $0.start && word.at <= $0.end } }
        let sayGrams = Set(grams(sayText)).subtracting(grams(teacherWords.map(\.text).joined(separator: " ")))
        let retold = try transcribe(mp4, in: scratch, name: "m8d-video")
        let heardSay = sayGrams.intersection(grams(retold))
        verdict("Check 6: re-transcribed, 0 runs of the say paragraph remain", heardSay.isEmpty && sayGrams.count > 20,
                "\(heardSay.count) of \(sayGrams.count) five-word runs heard" + (heardSay.isEmpty ? "" : ": " + heardSay.sorted().prefix(5).joined(separator: "; ")))
        let kept = plan.words.isEmpty ? [] : teacherWords.filter { word in plan.spans.contains { word.at >= $0.in && word.at <= $0.out } }.map { normal($0.text) }.filter { !$0.isEmpty }
        let retoldWords = retold.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        let share = Double(lcs(kept, retoldWords)) / Double(max(1, kept.count))
        report.append(String(format: "Reading (not a gate in check 6): %d of %d kept 13 Sep words heard again in order (%.1f%%).", lcs(kept, retoldWords), kept.count, share * 100))

        // Check 6, from outside: the corner's place in the made frames, against the original's.
        let generatorMade = AVAssetImageGenerator(asset: AVURLAsset(url: mp4))
        let generatorOriginal = AVAssetImageGenerator(asset: AVURLAsset(url: mixed))
        for generator in [generatorMade, generatorOriginal] {
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.appliesPreferredTrackTransform = false
        }
        func cornerBox(at time: Double) -> FaceBox? {
            let near = cornerTracks.flatMap(\.boxes).min { abs($0[0] - time) < abs($1[0] - time) }
            guard let near, abs(near[0] - time) <= 0.5 else { return nil }
            return FaceBox(x: near[1], y: near[2], width: near[3], height: near[4])
        }
        let preview = try await CompositionBuilder.build(plan: plan, original: mixed, hidden: hidden)
        var faceLines: [String] = [], facesInCorner = 0, worstFall = 1.0, worstPreview = 99.0
        var probeTimes: [Double] = []
        var probed: Set<Int64> = []
        for fraction in [0.05, 0.15, 0.25, 0.5, 0.75, 0.95] {
            let target = cornerFirst + (cornerLast - cornerFirst) * fraction
            guard let edited = timeline.editTime(target) ?? timeline.editTimeAtOrAfter(target) else { continue }
            let frame = Int64((edited / timeline.frame.seconds).rounded())
            // Two targets inside the stretch cut for the second voice land on the same frame after the cut: measured once.
            guard probed.insert(frame).inserted else { continue }
            guard let original = timeline.originalTime(timeline.seconds(frame)), let corner = cornerBox(at: original) else { continue }
            probeTimes.append(edited)
            let madeImage = try await generatorMade.image(at: timeline.time(frame)).image
            let originalImage = try await generatorOriginal.image(at: CMTime(seconds: original, preferredTimescale: 30000)).image
            let found = try await DetectFaceRectanglesRequest(.revision4).perform(on: madeImage).map { FaceGeometry.fromVision($0.boundingBox.cgRect) }
            let inCorner = found.filter { FaceGeometry.padded(corner, by: FaceHide.pad).contains(x: $0.centerX, y: $0.centerY) }
            facesInCorner += inCorner.count
            let was = variance(originalImage, in: corner), now = variance(madeImage, in: corner)
            let fall = 1 - now / max(was, 0.001)
            worstFall = min(worstFall, fall)
            let madePicture = try await RenderTests.frame(AVURLAsset(url: mp4), at: timeline.time(frame))
            let previewPicture = try await RenderTests.frame(preview.composition, videoComposition: preview.videoComposition, at: timeline.time(frame))
            let match = RenderTests.psnr(previewPicture, madePicture)
            worstPreview = min(worstPreview, match)
            faceLines.append(String(format: "  edited %.2f s (original %.2f s): Vision finds %d face(s), %d inside the corner's place; corner variance %.1f in the original, %.1f in the video (a fall of %.1f%%); the Viewer's frame against the file %.1f dB",
                                    timeline.seconds(frame), original, found.count, inCorner.count, was, now, fall * 100, match))
            if fraction == 0.75 {
                let url = forIvan.appending(path: "m8d-two-people-mixed-video-corner-hidden.png")
                if let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, madeImage, nil)
                    CGImageDestinationFinalize(destination)
                }
                report.append("For Ivan, not looked at (a frame of Gabriel's talk, D1): \(url.path)")
            }
        }
        verdict("Check 6: no face found in the corner's place in the made video", facesInCorner == 0 && probeTimes.count >= 4,
                "\(facesInCorner) faces in \(probeTimes.count) frames")
        verdict("Check 6: the corner's variance falls by 80% or more against the original's frame", worstFall >= 0.8 && probeTimes.count >= 4,
                String(format: "the smallest fall %.1f%% of %d frames", worstFall * 100, probeTimes.count))
        verdict("The Viewer draws the hidden frames as the file holds them (38 dB)", worstPreview >= 38 && probeTimes.count >= 4,
                String(format: "the worst %.1f dB of %d frames", worstPreview, probeTimes.count))
        report += ["Frames of the corner stretch, measured:"] + faceLines
        if case .success(let found) = VideoPreview.source(folder: folder.path, video: record) {
            verdict("The Viewer's Video reads the hidden faces from the same make", found.hidden == hidden, "\(found.hidden?.frames.count ?? 0) frames with regions")
        } else {
            verdict("The Viewer's Video reads the hidden faces from the same make", false, "VideoPreview.source refused")
        }

        // Check 6: hiding switched off for that track (the test switch); the gate must stop the video with the time.
        let staging = scratch.appending(path: ".making off", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: folder.appending(path: TranscriptFiles.asHeard), to: staging.appending(path: TranscriptFiles.asHeard))
        let gatePeople = model.videoPeople(recording)
        var setup = VideoStep.Setup(original: mixed, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: Date(), label: "two-people-mixed (hiding off)",
                                    people: gatePeople)
        setup.hiding = VideoHiding.plan(people, names: gatePeople.names, choices: gatePeople.choices)
        setup.faceTracks = PictureOutputCheck.tracks(people) { row in gatePeople.choices.choice(PersonKey.face(row ?? 0, names: gatePeople.names), for: .video) != .include }
        setup.voiceSegments = people.voices?.voiceSegments ?? []
        setup.folders = model.peopleFolders
        setup.hidingOffForTest = true
        let ffmpeg: @Sendable ([String]) async throws -> String = { try await Subprocess.run(ToolPaths.standard.ffmpeg, $0, timeout: .seconds(600)).stderr }
        let ffprobe: @Sendable ([String]) async throws -> String = { try await Subprocess.run(ToolPaths.standard.ffprobe, $0, timeout: .seconds(600)).stdout }
        let offMade = try await VideoStep.make(setup, ffmpeg: ffmpeg)
        var stopped = ""
        do {
            _ = try await VideoStep.check(offMade, setup: setup, ffprobe: ffprobe, ffmpeg: ffmpeg, now: Date())
        } catch let failure as VideoStep.Failure {
            stopped = failure.reason
        }
        let expectedAt = timeline.editTimeAtOrAfter(cornerFirst) ?? -1
        let stamp = stopped.range(of: #"at (\d+:\d+)"#, options: .regularExpression).map { String(stopped[$0].dropFirst(3)) } ?? ""
        let parts = stamp.split(separator: ":").compactMap { Double($0) }
        let at = parts.count == 2 ? parts[0] * 60 + parts[1] : -100
        verdict("Check 6: with hiding switched off for that track, the output is stopped with the time of the first unaccounted face",
                stopped.contains("A face Prakriti cannot account for at") && abs(at - expectedAt) <= 1.5
                    && !FileManager.default.fileExists(atPath: staging.appending(path: VideoStep.folderName).path)
                    && !FileManager.default.fileExists(atPath: staging.appending(path: VideoStep.stagingName).path),
                "\"\(stopped)\"; the corner face first shows at \(String(format: "%.2f", expectedAt)) s of the video; Video folder made: "
                + "\(FileManager.default.fileExists(atPath: staging.appending(path: VideoStep.folderName).path)), staging left: \(FileManager.default.fileExists(atPath: staging.appending(path: VideoStep.stagingName).path))")

        // Nothing stored for strangers.
        let forbidden = model.peopleFolders.forbidden.filter { FileManager.default.fileExists(atPath: $0.path) }
        let jobs = (try? FileManager.default.contentsOfDirectory(atPath: model.peopleFolders.jobs.path)) ?? []
        verdict("Nothing stored for strangers: no Faces, Voices or FaceIndex folder, Jobs empty", forbidden.isEmpty && jobs.isEmpty,
                "forbidden folders present: \(forbidden.map(\.lastPathComponent)); job folders: \(jobs.count)")
        let hidingText = try String(contentsOf: folder.appending(path: HiddenFaces.fileName), encoding: .utf8)
        verdict("video-hiding.json holds boxes and frame numbers only (no list of 128 or more numbers)", !hidingText.contains("image") && hidden.frames.allSatisfy { $0.count < 128 },
                "\(hidingText.count) characters, \(hidden.frames.count) rows, the longest \(hidden.frames.map(\.count).max() ?? 0) numbers")

        let after = fingerprint(mixed)
        verdict("The fixture is unchanged (size and modification date)", after == before, after == before ? "unchanged" : "CHANGED")
        let lines = verdicts.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0): \($0.2)" }
        let text = (["v2 part M8d acceptance (people in the video), \(Date().formatted(date: .abbreviated, time: .standard))", ""] + lines
                    + ["", "Details"] + report).joined(separator: "\n") + "\n"
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try text.write(to: out.appending(path: "acceptance-people-video.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M8d finished.")
    }

    // MARK: Measures

    private func variance(_ image: CGImage, in box: FaceBox) -> Double {
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PeopleInVideoTests.variance(RenderTests.Picture(width: width, height: height, rgba: rgba), in: box)
    }

    private func normal(_ word: String) -> String {
        word.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "'" }
    }

    /// Lowercased five-word runs, punctuation dropped.
    private func grams(_ text: String) -> [String] {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        guard words.count >= 5 else { return [] }
        return (0...(words.count - 5)).map { words[$0..<($0 + 5)].joined(separator: " ") }
    }

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

    /// The made video's sound transcribed again, as Prakriti transcribes: mono 16 kHz, then Parakeet.
    private func transcribe(_ file: URL, in work: URL, name: String) throws -> String {
        let wav = work.appending(path: "\(name).wav")
        try runTool(ToolPaths.standard.ffmpeg, ["-y", "-v", "error", "-i", file.path, "-vn", "-ac", "1", "-ar", "16000", wav.path])
        try runTool(ToolPaths.standard.parakeet, [wav.path, "--output-dir", work.path, "--output-format", "txt", "--output-template", "\(name)-retold"])
        defer { try? FileManager.default.removeItem(at: wav) }
        return try String(contentsOf: work.appending(path: "\(name)-retold.txt"), encoding: .utf8)
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
