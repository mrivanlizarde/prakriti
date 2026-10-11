import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The podcast-ready episode's acceptance, on the real 6 Sep talk (episode 1) and 13 Sep talk,
/// through the app's own runner and pipeline:
///
///   cd ~/Code/prakriti/mac && make accept-podcast MILESTONE=podcast
///
/// For each talk:
/// 1. The diagnosis of engine v0's episode, measured again: its loudness range, how loudnorm's
///    second pass worked (it says "dynamic"), and how the gain it applied moved: its spread over
///    speech, the seconds where it jumped more than 2 dB within one, and what it did to the pauses.
///    The old MP3 is engine v0's, in ~/Prakriti/Outputs, read only.
/// 2. The podcast-ready episode alone (no writing), then again with the first 10 s trimmed: a known
///    caption must move by exactly 10 s less the silence trim.
/// 3. Everything on, titles and notes by Qwen3.8-27B in LM Studio: the package measured and read
///    back (loudness, true peak, loudness range against the old MP3's, linear, the tail, ffprobe's
///    tags, the chapters, the captions), and the checklist: show name and artwork MISSING, loudness
///    and peak PASS. The same measures are taken of the new MP3 as of the old.
///
/// Skipped unless PRAKRITI_ACCEPTANCE=podcast (the make target sets it). Reads only the two talks,
/// read only, and engine v0's two MP3s; writes only into ~/Prakriti/Dev/Outputs and the pictures'
/// folder; the store is in memory. It takes about 40 minutes, most of it the writing model.
@MainActor
final class PodcastReadyAcceptanceTests: XCTestCase {
    private var report: [String] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "podcast" else {
            throw XCTSkip("Reads the 6 Sep and 13 Sep talks and runs the writing model. Run it with: cd ~/Code/prakriti/mac && make accept-podcast MILESTONE=podcast")
        }
    }

    func testTheThirteenSepTalk() async throws {
        try await accept(talk: "2026-09-13/2026-09-13 18-25-44.mp4", knownLine: 40)
    }

    func testTheSixSepTalk() async throws {
        try await accept(talk: "2026-09-06/2026-09-06 18-06-33.mp4", knownLine: 100)
    }

    private func accept(talk relative: String, knownLine: Int) async throws {
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        let talk = paths.studioRecordings.appending(path: relative)
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path))
        let name = talk.deletingPathExtension().lastPathComponent
        let folder = paths.outputs.appending(path: name, directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/") && paths.mode == .development)
        try? FileManager.default.removeItem(at: folder)
        let before = fingerprint(talk)
        model.log.write("Acceptance test for the podcast-ready episode started on \(talk.lastPathComponent) (in-memory store, outputs to \(paths.outputs.path)).")
        report = ["Podcast-ready acceptance, \(Date().formatted(date: .abbreviated, time: .standard))", "Talk: \(talk.lastPathComponent)", ""]
        defer { save(name) }

        // 1. The diagnosis of engine v0's episode.
        let old = paths.home.appending(path: "Prakriti/Outputs/\(name)/episode.mp3")
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.path), "engine v0's episode, read only")
        let source = try await frames(talk, filter: "aformat=channel_layouts=mono,aresample=48000,ebur128=peak=true")
        let oldFrames = try await frames(old, filter: "ebur128=peak=true")
        let firstPass = try await ffmpeg(["-i", talk.path, "-vn", "-af", Mastering.firstPass(target: -16, ceiling: -1), "-f", "null", "-"])
        let measured = try XCTUnwrap(Measure.loudnorm(stderr: firstPass))
        let secondPass = try await ffmpeg(["-i", talk.path, "-vn", "-af", Mastering.secondPass(target: -16, ceiling: -1, measured: measured), "-f", "null", "-"])
        let v0Mode = Measure.loudnorm(stderr: secondPass)?.normalizationType ?? "?"
        let riding = Self.riding(source: source, processed: oldFrames, shift: 0)
        report += ["1. Diagnosis of engine v0's episode (\(paths.display(old.path)), read only)",
                   String(format: "  the talk as recorded: %@ LUFS, true peak %@ dBTP, loudness range %@ LU", measured.inputI, measured.inputTP, measured.inputLRA),
                   String(format: "  peak over loudness: %.2f dB; raising it evenly to -15.4 with the peak at -1.5 allows %.2f, so loudnorm's second pass cannot stay linear",
                          (Double(measured.inputTP) ?? 0) - (Double(measured.inputI) ?? 0), -1.5 - (-15.4)),
                   "  loudnorm's second pass (engine v0's chain, run again): normalization_type \(v0Mode)",
                   String(format: "  the old MP3: %.1f LUFS, true peak %.1f dBTP, loudness range %.1f LU", oldFrames.lufs, oldFrames.truePeak, oldFrames.lra),
                   "  the gain it applied, against the original: " + riding.line, ""]
        XCTAssertEqual(v0Mode, "dynamic", "the diagnosis: v0's second pass rides the level")

        // 2. The podcast-ready episode alone, then with the first 10 s trimmed.
        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: talk)
        model.setKind(.talk, for: recording)
        model.setOutput(.podcastReady, on: true, for: recording)
        model.setOutput(.podcastEpisode, on: false, for: recording)
        model.setOutput(.titlesNotesChapters, on: false, for: recording)
        try model.context.save()
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let alone = try XCTUnwrap(recording.podcastReady, recording.podcastReadyProblem ?? "")
        let package = folder.appending(path: PodcastPackage.folderName)
        let silence = try XCTUnwrap(recording.silenceTrimmedStart)
        let firstCues = TranscriptFiles.cues(srt: try String(contentsOf: package.appending(path: alone.fileName.replacingOccurrences(of: ".mp3", with: ".srt")), encoding: .utf8))
        let known = firstCues[min(knownLine, firstCues.count - 1)]
        let heard = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))))
        let sentence = heard.first { Lexicon.apply($0.text.trimmingCharacters(in: .whitespaces)).text == known.text }
        report += ["2. The podcast-ready episode alone (no plain episode, no writing)",
                   "  steps: " + stepsLine(recording),
                   "  " + Pipeline.podcastLine(alone),
                   String(format: "  silence trimmed at the start: %.2f s", silence),
                   String(format: "  known caption %d, \"%@\": at %.3f s in the package", knownLine + 1, String(known.text.prefix(60)), known.start)
                       + (sentence.map { String(format: "; in the recording at %.3f s (%.3f s less the silence trim)", $0.tokens?.first?.start ?? $0.start, ($0.tokens?.first?.start ?? $0.start) - silence) } ?? "")]
        if let sentence {
            XCTAssertEqual(known.start, (sentence.tokens?.first?.start ?? sentence.start) - silence, accuracy: 0.2, "the caption is on the episode's clock")
        }

        XCTAssertNil(model.setTrim(start: 10, end: nil, for: recording))
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let trimmed = try XCTUnwrap(recording.podcastReady)
        let secondCues = TranscriptFiles.cues(srt: try String(contentsOf: package.appending(path: trimmed.fileName.replacingOccurrences(of: ".mp3", with: ".srt")), encoding: .utf8))
        let moved = try XCTUnwrap(secondCues.first { $0.text == known.text }, "the known caption is still there after the trim")
        report += [String(format: "  made again with the first 10 s trimmed: the same caption at %.3f s, %.3f s earlier (expected 10 s less the %.2f s silence trim = %.3f)",
                          moved.start, known.start - moved.start, silence, 10 - silence),
                   String(format: "  length %.3f s, then %.3f s: %.3f s shorter", alone.duration, trimmed.duration, alone.duration - trimmed.duration), ""]
        XCTAssertEqual(known.start - moved.start, 10 - silence, accuracy: 0.01, "the captions follow the trim exactly")
        XCTAssertEqual(alone.duration - trimmed.duration, 10 - silence, accuracy: 0.1)
        XCTAssertNil(model.setTrim(start: nil, end: nil, for: recording))

        // 3. Everything on, with the titles, show notes, chapters and captions by the writing model.
        model.setOutput(.podcastEpisode, on: true, for: recording)
        model.setOutput(.titlesNotesChapters, on: true, for: recording)
        let started = Date()
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let ready = try XCTUnwrap(recording.podcastReady, recording.podcastReadyProblem ?? "")
        let mp3 = package.appending(path: ready.fileName)
        report += ["3. Everything on, made in \(Format.length(Date().timeIntervalSince(started)))",
                   "  steps: " + stepsLine(recording)]
        for step in recording.latestRun?.steps ?? [] where [PipelineStep.podcastAudio.title, PipelineStep.podcastPackage.title, PipelineStep.writing.title, PipelineStep.loudness.title].contains(step.name) {
            report.append("  \(step.name): \(step.detail ?? "")")
        }

        // The file, measured here again, not taken from the record.
        let newFrames = try await frames(mp3, filter: "ebur128=peak=true")
        let newRiding = Self.riding(source: source, processed: newFrames, shift: silence)
        let tail = try await ffmpeg(["-v", "error", "-sseof", "-5", "-i", mp3.path, "-f", "null", "-"], hideBanner: false)
        let probe = try await tool(ToolPaths.standard.ffprobe, ["-v", "error", "-show_entries", "format_tags:stream=codec_name,sample_rate,channels,bit_rate:format=duration",
                                                                "-show_chapters", "-of", "json", mp3.path])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(probe.utf8)) as? [String: Any])
        let tags = ((json["format"] as? [String: Any])?["tags"] as? [String: String]) ?? [:]
        let probeChapters = (json["chapters"] as? [[String: Any]]) ?? []
        let tag = try XCTUnwrap(ID3.read(mp3))
        report += [String(format: "  the new MP3, measured again by ebur128: %.1f LUFS, true peak %.1f dBTP, loudness range %.1f LU (the old MP3: %.1f LU); by loudnorm, to the hundredth: %.2f LUFS, true peak %.2f dBTP",
                          newFrames.lufs, newFrames.truePeak, newFrames.lra, oldFrames.lra, ready.integratedLUFS, ready.truePeak),
                   "  loudnorm's second pass: \(ready.normalizationType)" + (ready.corrected ? " (made twice: the first true peak was over -1)" : ""),
                   "  the gain it applied, against the original: " + newRiding.line,
                   "  tail: " + (tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "the last 5 s decode with no error" : tail),
                   "  ffprobe tags: " + tags.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.prefix(60))" }.joined(separator: "; "),
                   "  ID3 frames read back: " + tag.frameIDs.joined(separator: " ") + "; COMM: \(tag.comment.map { String($0.prefix(60)) } ?? "none")",
                   "  chapters, read back by Prakriti: " + tag.chapters.map { "\(WritingText.stamp(Double($0.startMS) / 1000)) to \(WritingText.stamp(Double($0.endMS) / 1000)) \($0.title)" }.joined(separator: " | "),
                   "  chapters, read back by ffprobe: \(probeChapters.count): " + probeChapters.compactMap { ($0["tags"] as? [String: Any])?["title"] as? String }.joined(separator: " | "),
                   "  files: " + Pipeline.madeFiles(in: package).joined(separator: ", "),
                   "  original unchanged: \(fingerprint(talk) == before)"]
        XCTAssertEqual(newFrames.lufs, -16, accuracy: 1)
        XCTAssertLessThanOrEqual(newFrames.truePeak, -1.0, "ebur128's meter, one decimal")
        XCTAssertLessThanOrEqual(ready.truePeak, -1.0, "loudnorm's meter, to the hundredth")
        XCTAssertLessThan(newFrames.lra, oldFrames.lra, "the loudness range is lower than the old MP3's")
        XCTAssertEqual(ready.normalizationType, "linear")
        XCTAssertTrue(tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, tail)
        XCTAssertEqual(tags["genre"], "Podcast")
        XCTAssertEqual(tags["date"], "2026")
        XCTAssertNotNil(tags["title"])
        XCTAssertNil(tags["album"], "no show name is ever invented")
        XCTAssertEqual(fingerprint(talk), before, "the original is untouched")
        if let written = recording.written, written.chapters.count >= 3 {
            XCTAssertEqual(tag.chapters.count, written.chapters.count)
            XCTAssertNil(PodcastPackage.chapterProblem(tag, duration: ready.duration))
            XCTAssertEqual(probeChapters.count, written.chapters.count)
        }

        // The checklist and the text file.
        let checklist = try String(contentsOf: package.appending(path: PodcastPackage.checklistName), encoding: .utf8)
        let text = try String(contentsOf: package.appending(path: PodcastPackage.textName), encoding: .utf8)
        XCTAssertTrue(checklist.contains("MISSING  Show name"), checklist)
        XCTAssertTrue(checklist.contains("MISSING  Artwork"), checklist)
        XCTAssertTrue(checklist.contains("PASS     Loudness"), checklist)
        XCTAssertTrue(checklist.contains("PASS     True peak"), checklist)
        XCTAssertTrue(checklist.contains("PASS     Leveling"), checklist)
        for (file, body) in [("checklist", checklist), ("text", text)] {
            XCTAssertFalse(body.contains("\u{2014}") || body.contains("\u{2013}"), "an em or en dash in the \(file)")
        }
        for heading in ["EPISODE TITLE", "SHOW AND EPISODE", "SHOW NOTES", "CHAPTERS", "SOCIAL CAPTIONS"] {
            XCTAssertTrue(text.contains(heading), heading)
        }
        report += ["", "The checklist (\(PodcastPackage.checklistName)):", checklist, "The text file (\(PodcastPackage.textName)):", text]

        // Pictures of the page, as Ivan sees it.
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        for (scheme, appearance) in SnapshotRenderer.appearances {
            model.open(recording)
            try renderer.render(model: model, appearance: appearance, name: "podcast-\(name.prefix(10))-\(scheme)")
        }
    }

    // MARK: Measuring

    struct Frames {
        var t: [Double] = []
        var m: [Double] = []
        var s: [Double] = []
        var lufs = 0.0, lra = 0.0, truePeak = 0.0
    }

    /// ebur128's 100 ms frames (momentary and short-term loudness) and its summary.
    private func frames(_ file: URL, filter: String) async throws -> Frames {
        let stderr = try await ffmpeg(["-i", file.path, "-vn", "-af", filter, "-f", "null", "-"])
        var out = Frames()
        for match in stderr.matches(of: /t:\s*([0-9.]+)\s+TARGET:.*?M:\s*(-?[0-9.]+|-inf)\s+S:\s*(-?[0-9.]+|-inf)/) {
            out.t.append(Double(match.output.1) ?? 0)
            out.m.append(Double(match.output.2) ?? -.infinity)
            out.s.append(Double(match.output.3) ?? -.infinity)
        }
        let summary = Measure.ebur128(stderr: stderr)
        out.lufs = summary?.integratedLUFS ?? 0
        out.truePeak = summary?.truePeakDBFS ?? 0
        out.lra = Measure.loudnessRange(stderr: stderr) ?? 0
        return out
    }

    struct Riding {
        var line: String
    }

    /// How the gain moved: the processed file's short-term loudness less the original's at the same
    /// moment (`shift` is how much earlier the processed file starts, its silence trim), over speech
    /// (the original's short-term loudness above -45 LUFS); how many seconds it jumped more than 2 dB
    /// within a second; and the gain in the pauses (the original's momentary loudness under -50).
    static func riding(source: Frames, processed: Frames, shift: Double) -> Riding {
        // The original's loudness at the processed frame's own moment plus the shift, read between
        // its two nearest frames. Rounding the shift to a whole 100 ms frame put the pauses' edges
        // 20 ms off on the 13 Sep talk's 1.18 s trim (BUILD-LOG, "Podcast-ready episode").
        var gains: [Double] = [], speech: [Bool] = [], pauses: [Double] = []
        var cursor = 0
        for i in processed.s.indices {
            let time = processed.t[i] + shift
            while cursor < source.t.count && source.t[cursor] < time { cursor += 1 }
            guard cursor > 0, cursor < source.t.count else { gains.append(.nan); speech.append(false); continue }
            let w = (time - source.t[cursor - 1]) / max(0.001, source.t[cursor] - source.t[cursor - 1])
            func value(_ values: [Double]) -> Double {
                let a = values[cursor - 1], b = values[cursor]
                return a.isFinite && b.isFinite ? a + (b - a) * w : min(a, b)
            }
            let s = value(source.s), m = value(source.m)
            let isSpeech = s > -45 && processed.s[i] > -70 && s.isFinite && processed.s[i].isFinite
            gains.append(processed.s[i] - s)
            speech.append(isSpeech)
            if m < -50, m > -120, processed.m[i].isFinite { pauses.append(processed.m[i] - m) }
        }
        let g = zip(gains, speech).filter { $0.1 }.map(\.0).sorted()
        func pct(_ values: [Double], _ p: Double) -> Double { values.isEmpty ? .nan : values[min(values.count - 1, Int(Double(values.count - 1) * p))] }
        var jumps = 0, biggest = 0.0
        for i in 10..<max(10, gains.count) where speech[i] && speech[i - 10] {
            let change = abs(gains[i] - gains[i - 10])
            if change > 2 { jumps += 1 }
            biggest = max(biggest, change)
        }
        let p = pauses.sorted()
        return Riding(line: String(format: "over speech %.1f to %.1f dB (5th to 95th percentile, a %.1f dB spread); more than 2 dB within a second for %.0f s (largest %.1f dB); in the pauses %.1f dB (median) to %.1f dB (95th percentile), over %.0f s of pauses",
                                   pct(g, 0.05), pct(g, 0.95), pct(g, 0.95) - pct(g, 0.05), Double(jumps) / 10, biggest, pct(p, 0.5), pct(p, 0.95), Double(p.count) / 10))
    }

    // MARK: Helpers

    private func ffmpeg(_ arguments: [String], hideBanner: Bool = true) async throws -> String {
        let output = try await Subprocess.run(ToolPaths.standard.ffmpeg, (hideBanner ? ["-hide_banner", "-nostats"] : []) + arguments, timeout: .seconds(1800))
        return output.stderr
    }

    private func tool(_ executable: URL, _ arguments: [String]) async throws -> String {
        try await Subprocess.run(executable, arguments, timeout: .seconds(600)).stdout
    }

    private func stepsLine(_ recording: Recording) -> String {
        (recording.latestRun?.steps ?? []).map { "\($0.name) " + ($0.seconds.map { String(format: "%.1f s", $0) } ?? $0.state.rawValue) }.joined(separator: "; ")
    }

    private func fingerprint(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        return "\((attributes?[.size] as? NSNumber)?.int64Value ?? -1) \((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1)"
    }

    private func save(_ name: String) {
        let folder = SnapshotRenderer.milestoneFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? report.joined(separator: "\n").write(to: folder.appending(path: "acceptance-podcast-\(name.prefix(10)).txt"), atomically: true, encoding: .utf8)
    }
}
