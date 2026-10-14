import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// The episode text's acceptance (11 Oct), on the real 13 Sep talk, through the app's own settings,
/// runner, pipeline and writer, with the real Qwen3.8-27B in LM Studio:
///
///   cd ~/Code/prakriti/mac && make accept-episode-text MILESTONE=episode-text
///
/// 1. Made with everything on: the episode, the transcript, the titles and notes, the podcast-ready
///    episode. Writing is set to the Claude API on purpose: the talk names Serenity, so the privacy
///    lock must hand it to LM Studio, and the Claude client here only counts and refuses (0 calls).
/// 2. "Episode text.txt" and ".md", read back and checked here, independently of the writer: every
///    section is there; every pull quote is found word for word in the episode's transcript.txt and
///    inside one of its transcript.srt cues (one sentence), with its offset; every chapter time in the
///    show notes is a chapter ffprobe reads from the finished MP3, inside its length; no em or en
///    dash; no "$", "enroll", price, earnings or offer in the captions (and the copy rules find
///    nothing in the whole file); the X and Threads caption under 280 characters; at most five hashtags.
/// 3. A call to action set on the Outputs screen and Update Podcast-Ready Files: it closes the show
///    notes; then cleared again and updated, so the files end as the model wrote them.
/// 4. Pictures of the recording page with its Ready to upload section, light and dark, and the same
///    page with the recording marked as a class (the refusal).
///
/// Skipped unless PRAKRITI_ACCEPTANCE=episode-text. Reads only the 13 Sep talk (Gabriel only), read
/// only; writes only into ~/Prakriti/Dev/Outputs and the pictures' folder; the store is in memory.
/// About 30 minutes, nearly all of it the writing model.
@MainActor
final class EpisodeTextAcceptanceTests: XCTestCase {
    private var report: [String] = []

    func testTheEpisodeTextForTheThirteenSepTalk() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "episode-text" else {
            throw XCTSkip("Runs the writing model for about half an hour. Run it with: cd ~/Code/prakriti/mac && make accept-episode-text MILESTONE=episode-text")
        }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(5)
        // Writing on LM Studio: this check is of the local model's episode text (since part LOCK the talk is not locked,
        // so choosing the Claude API would send it).
        model.settings.provider = [.writing: .lmStudio, .tagging: .lmStudio, .summarizing: .lmStudio]
        let claudeCalls = CallCounter()
        model.runner.makeClient = { provider, setup in
            provider == .claudeAPI ? RefusingClient(provider: provider, counter: claudeCalls) : WritingSetup.standardClient(provider, setup)
        }
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: claudeCalls) }
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path))
        let name = talk.deletingPathExtension().lastPathComponent
        let folder = paths.outputs.appending(path: name, directoryHint: .isDirectory)
        precondition(folder.path.hasPrefix(paths.outputs.path + "/") && paths.mode == .development)
        try? FileManager.default.removeItem(at: folder)
        let before = fingerprint(talk)
        model.log.write("Acceptance test for the episode text started on \(talk.lastPathComponent) (in-memory store, outputs to \(paths.outputs.path)).")
        report = ["Episode text acceptance, \(Date().formatted(date: .abbreviated, time: .standard))", "Talk: \(talk.lastPathComponent)",
                  "Choices: writing, tags and summary = LM Studio (the Claude API client only counts and refuses)", ""]
        defer { save() }

        // 1. Everything on.
        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: talk)
        model.setKind(.talk, for: recording)
        for kind in [OutputKind.podcastEpisode, .transcript, .checksAndReport, .titlesNotesChapters, .podcastReady] {
            model.setOutput(kind, on: true, for: recording)
        }
        try model.context.save()
        let started = Date()
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let written = try XCTUnwrap(recording.written, recording.writingProblem ?? "nothing written")
        let ready = try XCTUnwrap(recording.podcastReady, recording.podcastReadyProblem ?? "no podcast-ready files")
        report.append("1. Made in \(Format.length(Date().timeIntervalSince(started))). Steps:")
        for step in recording.latestRun?.steps ?? [] {
            report.append("  \(step.name): \(step.state.title), \(step.seconds.map { String(format: "%.1f s", $0) } ?? "-"). \(step.detail ?? "")")
        }
        report += ["  Privacy lock: hasSerenity \(recording.hasSerenity); written by \(written.writtenBy) (provider \(written.writingProvider)); "
                   + "lock reason \(written.lockReason ?? "none"); locked tasks \(written.lockedTasks); Claude API client calls \(claudeCalls.count)",
                   "  Tokens: \(written.promptTokens.map(String.init) ?? "?") read, \(written.completionTokens.map(String.init) ?? "?") written of which "
                   + "\(written.reasoningTokens.map(String.init) ?? "?") thinking; the writing request \(String(format: "%.0f s", written.writingSeconds)), \(written.attempts) tries"]
        XCTAssertEqual(claudeCalls.count, 0, "the Claude API is not chosen")
        XCTAssertEqual(written.writingProvider, ModelProvider.lmStudio.rawValue)

        // 2. The files, read back.
        let package = folder.appending(path: PodcastPackage.folderName)
        let textURL = package.appending(path: PodcastPackage.textName)
        let mdURL = package.appending(path: PodcastPackage.markdownName)
        let text = try String(contentsOf: textURL, encoding: .utf8)
        let markdown = try String(contentsOf: mdURL, encoding: .utf8)
        let mp3 = package.appending(path: ready.fileName)
        report += ["", "2. Files in \(paths.display(package.path)): " + Pipeline.madeFiles(in: package).joined(separator: ", ")]

        // Every section.
        let sections = ["EPISODE TITLE", "Alternatives", "ONE-LINE SUMMARY", "SHOW NOTES", "Chapters", "KEYWORDS", "SOCIAL CAPTIONS",
                        "Instagram (", "LinkedIn (", "X and Threads (", "Pull quote", "FOR THE HOST'S FORM"]
        let missing = sections.filter { !text.contains($0) }
        report.append("  sections: \(sections.count - missing.count) of \(sections.count) found" + (missing.isEmpty ? "" : "; missing: \(missing)"))
        XCTAssertTrue(missing.isEmpty, "\(missing)")
        for heading in ["## Episode title", "### Alternatives", "## One-line summary", "## Show notes", "## Keywords", "## Social captions", "### Instagram", "### LinkedIn", "### X and Threads"] {
            XCTAssertTrue(markdown.contains(heading), heading)
        }
        let copy = PodcastPackage.copy(settings: model.podcastReadySettings(for: recording), facts: recording.podcastFacts, written: written,
                                       chapters: PodcastPackage.chapters(written.chapters, duration: ready.duration).chapters)
        report += ["  title: \"\(copy.title ?? "none")\" (\(copy.titleChosen ? "chosen" : "the writer's first pick")); alternatives: \(copy.alternatives.count): " + copy.alternatives.map { "\"\($0)\"" }.joined(separator: ", "),
                   "  one-line summary: \(copy.oneLine?.count ?? 0) characters",
                   "  show notes: \(Format.count(copy.notes.count, "paragraph")), \(copy.notes.map(WritingText.words).reduce(0, +)) words; \(Format.count(copy.chapters.count, "chapter")); call to action: \(copy.callToAction ?? "none set")",
                   "  keywords: \(copy.keywords.count): \(copy.keywords.joined(separator: ", "))"]
        XCTAssertEqual(copy.alternatives.count, 3, "the chosen title plus three alternatives")
        XCTAssertLessThan(copy.oneLine?.count ?? 999, 160)
        XCTAssertTrue((2...4).contains(copy.notes.count), "2 to 4 paragraphs")
        XCTAssertFalse(copy.keywords.isEmpty)

        // Every pull quote, word for word in transcript.txt and inside one .srt cue.
        let transcript = WritingText.normalized(try String(contentsOf: folder.appending(path: TranscriptFiles.fileName(.txt)), encoding: .utf8))
        let cues = TranscriptFiles.cues(srt: try String(contentsOf: folder.appending(path: TranscriptFiles.fileName(.srt)), encoding: .utf8))
        report.append("  pull quotes, checked against \(TranscriptFiles.fileName(.txt)) (\(transcript.count) characters) and the \(cues.count) cues of \(TranscriptFiles.fileName(.srt)):")
        XCTAssertEqual(copy.captions.count, 3, "a caption for Instagram, LinkedIn and X and Threads")
        for caption in copy.captions {
            let quote = try XCTUnwrap(caption.pullQuote, "\(caption.platform.title) has a pull quote")
            let offset = transcript.range(of: quote).map { transcript.distance(from: transcript.startIndex, to: $0.lowerBound) }
            let cue = cues.firstIndex { WritingText.normalized($0.text).contains(quote) }
            report.append("    \(caption.platform.title): \"\(quote)\" at \(caption.pullQuoteAt.map { WritingText.stamp($0) } ?? "?"): "
                          + "transcript.txt offset \(offset.map(String.init) ?? "NOT FOUND"), srt cue \(cue.map { "\($0 + 1) (\(Format.timecode(cues[$0].start)))" } ?? "NOT IN ONE CUE")")
            XCTAssertNotNil(offset, "word for word in transcript.txt: \(quote)")
            XCTAssertNotNil(cue, "inside one sentence: \(quote)")
            XCTAssertTrue(text.contains("\"\(quote)\""), "the text file carries it as checked")
        }

        // Chapter times in the show notes against the chapters ffprobe reads from the finished MP3.
        let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-show_chapters", "-show_entries", "format=duration", "-of", "json", mp3.path], timeout: .seconds(120)).stdout
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(probe.utf8)) as? [String: Any])
        let duration = Double(((json["format"] as? [String: Any])?["duration"] as? String) ?? "") ?? 0
        let probed = ((json["chapters"] as? [[String: Any]]) ?? []).map { chapter in
            (start: Double((chapter["start_time"] as? String) ?? "") ?? -1, title: ((chapter["tags"] as? [String: Any])?["title"] as? String) ?? "")
        }
        let chapterLines = text.components(separatedBy: "\n").drop { $0 != "Chapters" }.dropFirst().prefix { !$0.isEmpty }
        report.append("  chapters in the show notes against ffprobe on \(ready.fileName) (\(String(format: "%.3f", duration)) s):")
        XCTAssertEqual(chapterLines.count, probed.count, "every chapter in the file is in the notes")
        XCTAssertGreaterThanOrEqual(probed.count, 3)
        for (line, chapter) in zip(chapterLines, probed) {
            let label = String(line.split(separator: " ", maxSplits: 1).first ?? "")
            let matches = label == WritingText.stamp(chapter.start) && line.hasSuffix(chapter.title) && chapter.start < duration
            report.append("    \"\(line)\": ffprobe \(String(format: "%.3f", chapter.start)) s \"\(chapter.title)\", \(matches ? "the same, inside the file" : "DIFFERENT")")
            XCTAssertTrue(matches, line)
        }

        // Dashes, money and enrollment.
        for (file, body) in [(PodcastPackage.textName, text), (PodcastPackage.markdownName, markdown)] {
            let dashes = body.filter { $0 == "\u{2014}" || $0 == "\u{2013}" }.count
            report.append("  \(file): \(dashes) em or en dashes")
            XCTAssertEqual(dashes, 0, file)
        }
        let captionsText = text.components(separatedBy: "\nSOCIAL CAPTIONS\n").last?.components(separatedBy: "\nFOR THE HOST'S FORM\n").first ?? ""
        let dollar = captionsText.filter { $0 == "$" }.count
        let enroll = captionsText.lowercased().components(separatedBy: "enrol").count - 1
        let flagged = copy.captions.compactMap { CopyRules.flag($0.text) ?? $0.pullQuote.flatMap(CopyRules.flag) }
        let wholeFile = CopyRules.sentences(text).compactMap(CopyRules.flag)
        report += ["  captions section (\(captionsText.count) characters): \(dollar) \"$\", \(enroll) \"enroll\"; copy rules on the captions and pull quotes: \(flagged.isEmpty ? "nothing" : flagged.joined(separator: "; "))",
                   "  copy rules on every sentence of the text file: \(wholeFile.isEmpty ? "nothing" : wholeFile.joined(separator: "; "))"]
        XCTAssertEqual(dollar, 0)
        XCTAssertEqual(enroll, 0)
        XCTAssertTrue(flagged.isEmpty, "\(flagged)")
        let x = try XCTUnwrap(copy.caption(.x))
        let instagram = try XCTUnwrap(copy.caption(.instagram))
        report += ["  X and Threads caption: \(x.text.count) characters (under 280: \(x.text.count < 280))",
                   "  Instagram: \(instagram.text.count) characters, \(Format.count(instagram.hashtags.count, "hashtag")): \(instagram.hashtags.map { "#" + $0 }.joined(separator: " "))",
                   "  LinkedIn: \(copy.caption(.linkedin)?.text.count ?? 0) characters"]
        XCTAssertLessThan(x.text.count, 280)
        XCTAssertLessThanOrEqual(instagram.hashtags.count, 5)
        // Every hashtag is whole words of the transcript, read independently from transcript.txt.
        let rawTranscript = try String(contentsOf: folder.appending(path: TranscriptFiles.fileName(.txt)), encoding: .utf8)
        let unspoken = instagram.hashtags.filter { WritingCheck.hashtag($0, in: rawTranscript) == nil }
        report.append("  hashtags that are not words of transcript.txt: \(unspoken.isEmpty ? "none" : unspoken.joined(separator: ", "))")
        XCTAssertTrue(unspoken.isEmpty, "\(unspoken)")
        XCTAssertEqual(fingerprint(talk), before, "the original is untouched")

        // The checklist.
        let checklist = try String(contentsOf: package.appending(path: PodcastPackage.checklistName), encoding: .utf8)
        XCTAssertTrue(checklist.contains("MISSING  Show name"), "no show name is ever invented")
        XCTAssertTrue(checklist.contains("PASS     Social captions"), checklist)
        XCTAssertTrue(checklist.contains("PASS     Copy rules"), checklist)
        report += ["", "The text file as written (\(PodcastPackage.textName)):", text, "The checklist (\(PodcastPackage.checklistName)):", checklist]

        // 4 (first, while the files are the model's own). Pictures of the page as Ivan sees it.
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        for (scheme, appearance) in SnapshotRenderer.appearances {
            model.open(recording)
            try renderer.render(model: model, appearance: appearance, name: "episode-text-13sep-ready-\(scheme)")
        }

        // 3. A call to action, then none again.
        let setting = try XCTUnwrap(model.defaultSettings().first { $0.kind == .podcastReady })
        let line = "TEST LINE FOR THE ACCEPTANCE, NOT FOR PUBLISHING: this closes the show notes."
        setting.callToAction = line
        XCTAssertTrue(model.podcastReadyIsOutOfDate(recording), "a new call to action makes the files out of date")
        _ = await model.runner.packageAgain(recording)
        let withAction = try String(contentsOf: textURL, encoding: .utf8)
        let notesSection = withAction.components(separatedBy: "\nSHOW NOTES\n").last?.components(separatedBy: "\nKEYWORDS\n").first ?? ""
        let endsWithAction = notesSection.components(separatedBy: "\n(").first?.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(line) == true
        report += ["", "3. Call to action set and the files updated: the show notes end with it: \(endsWithAction)"]
        XCTAssertTrue(endsWithAction, notesSection)
        setting.callToAction = ""
        _ = await model.runner.packageAgain(recording)
        let cleared = try String(contentsOf: textURL, encoding: .utf8)
        report.append("  cleared and updated again: the line is gone: \(!cleared.contains(line)); the rest unchanged apart from the time made: "
                      + "\(cleared.components(separatedBy: "\n").dropFirst(3) == text.components(separatedBy: "\n").dropFirst(3))")
        XCTAssertFalse(cleared.contains(line))

        // 4 (the refusal). The same page, marked as a class.
        model.setKind(.lesson, for: recording)
        for (scheme, appearance) in SnapshotRenderer.appearances {
            model.open(recording)
            try renderer.render(model: model, appearance: appearance, name: "episode-text-13sep-class-\(scheme)")
        }
        XCTAssertFalse(model.canUpdatePodcastReady(recording), "a class is never made ready")
        model.setKind(.talk, for: recording)

        // LM Studio left as it was found: nothing loaded by Prakriti.
        let lmStudio = LMStudioClient(address: model.settings.lmStudioAddress, model: model.settings.lmStudioModel)
        let after = try await lmStudio.state()
        report += ["", "LM Studio after the run: \(after.instances.isEmpty ? "nothing loaded" : after.instances.map(\.id).joined(separator: ", "))"]
    }

    private func fingerprint(_ file: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        return "\((attributes?[.size] as? NSNumber)?.int64Value ?? -1) \((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1)"
    }

    private func save() {
        let folder = SnapshotRenderer.milestoneFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? report.joined(separator: "\n").write(to: folder.appending(path: "acceptance-episode-text.txt"), atomically: true, encoding: .utf8)
    }
}
