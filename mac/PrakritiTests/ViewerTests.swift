import AVFoundation
import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M3b, the Viewer: the transcript as words, sentences and paragraphs; the span a run of words
/// takes; Timeline-lite's spans; Remove from the Edit and Keep in the Edit through the model; the window's
/// state put back at the next launch; and, in a real player (PLAN M3 check 4), a clicked word plays from
/// within 0.25 s of its start on the original's clock, and with Follow Playback on the sentence marked
/// changes as time passes. Generated media and a made-up transcript only; nothing reads a real recording.
@MainActor
final class ViewerTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-viewer-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: A made-up talk

    /// Four sentences of four words, each word 0.5 s with 0.1 s between, sentences 0.6 s apart, and a pause
    /// of 2 s before the fourth (a new paragraph). The words name nobody.
    static let sentenceWords = [["The", "breath", "comes", "first."], ["Then", "the", "body", "follows."],
                                ["We", "practice", "every", "morning."], ["Rest", "is", "practice", "too."]]

    static func sentences() -> [EpisodeTranscript.Sentence] {
        var out: [EpisodeTranscript.Sentence] = []
        var t = 0.4
        for (index, words) in sentenceWords.enumerated() {
            if index == 3 { t += 2 }
            var tokens: [EpisodeTranscript.Token] = []
            for word in words {
                tokens.append(EpisodeTranscript.Token(text: " " + word, start: t, end: t + 0.5))
                t += 0.6
            }
            out.append(EpisodeTranscript.Sentence(text: tokens.map(\.text).joined(), start: tokens[0].start, end: tokens[tokens.count - 1].end, tokens: tokens))
            t += 0.6
        }
        return out
    }

    func testTheTranscriptIsWordsSentencesAndParagraphs() {
        let document = TranscriptDocument(sentences: Self.sentences(), applyLexicon: false)
        XCTAssertEqual(document.words.count, 16)
        XCTAssertEqual(document.words.map(\.text).prefix(4), ["The", "breath", "comes", "first."])
        XCTAssertEqual(document.sentences.count, 4)
        XCTAssertEqual(document.paragraphs.map(\.sentences), [0..<3, 3..<4], "a 2 s pause starts a paragraph")
        XCTAssertEqual(document.sentence(at: 0.5)?.id, 0)
        XCTAssertEqual(document.sentence(at: document.sentences[2].start + 0.2)?.id, 2)
        // The word list fixes what Parakeet mishears, word for word.
        let misheard = EpisodeTranscript.Sentence(text: " the yoga market school", start: 0, end: 2,
                                                  tokens: [.init(text: " the", start: 0, end: 0.4), .init(text: " yoga", start: 0.5, end: 0.9),
                                                           .init(text: " market", start: 1.0, end: 1.4), .init(text: " school", start: 1.5, end: 1.9)])
        let fixed = TranscriptDocument(sentences: [misheard], applyLexicon: true)
        XCTAssertEqual(fixed.words.map(\.text).joined(separator: " "), Lexicon.apply("the yoga market school").text)
    }

    /// A run of words becomes a cut that takes exactly those words, even when Parakeet stretches the last
    /// word over the pause after it (Mac warning 40).
    func testASelectionTakesExactlyItsWords() throws {
        var raw = Self.sentences()
        // Stretch the 6th word ("body") across the next word's start, as Parakeet does before a pause.
        var tokens = raw[1].tokens ?? []
        tokens[2] = .init(text: tokens[2].text, start: tokens[2].start, end: tokens[3].start + 0.4)
        raw[1] = .init(text: raw[1].text, start: raw[1].start, end: raw[1].end, tokens: tokens)
        let document = TranscriptDocument(sentences: raw, applyLexicon: false)
        let span = try XCTUnwrap(document.span(of: 5...6))
        let edits = EpisodeEdits(start: nil, end: nil, cuts: [span])
        let kept = edits.segments(duration: 30)
        let gone = document.words.filter { !$0.isKept(in: kept) }.map(\.text)
        XCTAssertEqual(gone, ["the", "body"], "exactly the two words chosen")
    }

    func testTimelineSpansNameTheTrimAndTheCuts() {
        let edits = EpisodeEdits(start: 10, end: 900, cuts: [TimeRange(start: 300, end: 330)])
        let spans = TimelineSpan.spans(edits: edits, duration: 947.78)
        XCTAssertEqual(spans.map(\.kind), [.trimmedStart, .kept, .cut, .kept, .trimmedEnd])
        XCTAssertEqual(spans[2].start, 300, accuracy: 0.001)
        XCTAssertEqual(spans[2].end, 330, accuracy: 0.001)
        XCTAssertEqual(spans[2].line, "Removed: a cut, 30 s, 5:00 to 5:30.")
        XCTAssertEqual(spans.reduce(0) { $0 + $1.length }, 947.78, accuracy: 0.001, "end to end over the whole original")
        XCTAssertEqual(TimelineSpan.spans(edits: EpisodeEdits(), duration: 60).map(\.kind), [.kept])
    }

    func testRenditionsNotMadeSayWhy() {
        let viewer = ViewerModel()
        XCTAssertEqual(viewer.unavailableReason(.video), "Prakriti does not make an edited video yet.")
        XCTAssertEqual(viewer.unavailableReason(.shorts), "Prakriti does not make shorts yet.")
        XCTAssertFalse(Rendition.video.isBuilt)
        XCTAssertTrue(Rendition.podcastReady.isBuilt)
    }

    // MARK: Remove from the Edit, Keep in the Edit, Restore

    func testRemoveAndKeepGoThroughTheEdit() throws {
        let (model, recording) = try madeRecording()
        model.open(recording)
        model.openViewer(recording)
        XCTAssertEqual(model.viewer.document.words.count, 16)
        // Remove "body follows." (words 6 and 7).
        model.viewer.selectedWords = 6...7
        XCTAssertTrue(model.canRemoveSelectedWords(recording))
        XCTAssertFalse(model.canKeepSelectedWords(recording))
        XCTAssertNil(model.removeSelectedWords(from: recording))
        XCTAssertEqual(recording.cuts.count, 1)
        XCTAssertTrue(recording.editsPending, "waits for Make Again (Mac warning 36)")
        let kept = recording.edits.segments(duration: 20)
        XCTAssertEqual(model.viewer.document.words.filter { !$0.isKept(in: kept) }.map(\.text), ["body", "follows."])
        // Keep one of them again: the cut shrinks around it.
        model.viewer.selectedWords = 6...6
        XCTAssertTrue(model.canKeepSelectedWords(recording))
        XCTAssertNil(model.keepSelectedWords(in: recording))
        let after = recording.edits.segments(duration: 20)
        XCTAssertEqual(model.viewer.document.words.filter { !$0.isKept(in: after) }.map(\.text), ["follows."])
        // Restore on the remaining span: nothing is cut any more.
        let span = try XCTUnwrap(TimelineSpan.spans(edits: recording.edits, duration: 20).first { $0.isRemoved })
        model.restore(span, in: recording)
        XCTAssertTrue(recording.cuts.isEmpty)
        // A trim is kept back too.
        XCTAssertNil(model.setTrim(start: 3, end: nil, for: recording))
        model.viewer.selectedWords = 0...1
        XCTAssertTrue(model.canKeepSelectedWords(recording))
        XCTAssertNil(model.keepSelectedWords(in: recording))
        XCTAssertLessThanOrEqual(recording.trimStart ?? 0, model.viewer.document.words[0].position)
        // The inspector's typed cut, as Ivan types it.
        XCTAssertNil(model.typedCut(from: "0:12", to: "0:13", for: recording))
        XCTAssertEqual(model.typedCut(from: "twelve", to: "0:13", for: recording), "Write each time like 4:12 or 1:02:30.")
        let lines = try model.context.fetch(FetchDescriptor<LogEntry>()).map(\.message)
        XCTAssertTrue(lines.contains { $0.contains("kept in the episode again") }, "\(lines)")
    }

    // MARK: State restoration

    func testTheWindowComesBackAsItWasLeft() throws {
        let (model, recording) = try madeRecording()
        model.selection = .group(.all)
        model.inspectorTab = .info
        model.browserMode = .list
        model.open(recording)
        model.openViewer(recording)
        model.viewer.seek(original: 7.4, play: false)
        model.saveWindowState()
        let saved = try XCTUnwrap(model.settings.windowState)
        let state = try JSONDecoder().decode(WindowState.self, from: Data(saved.utf8))
        XCTAssertEqual(state.group, SmartGroup.all.rawValue)
        XCTAssertEqual(state.open, recording.id)
        XCTAssertEqual(state.rendition, Rendition.podcast.rawValue)
        XCTAssertEqual(state.original ?? 0, 7.4, accuracy: 0.01)
        XCTAssertEqual(state.inspectorTab, "info")

        // A later launch, on the same store and preferences.
        let next = AppModel(container: model.container, paths: model.paths, settings: model.settings, log: AppLog(directory: nil))
        next.restoreWindowState()
        XCTAssertEqual(next.selection, .group(.all))
        XCTAssertEqual(next.inspectorTab, .info)
        XCTAssertEqual(next.browserMode, .list)
        XCTAssertEqual(next.path.count, 1, "the recording is open in the Viewer again")
        XCTAssertEqual(next.restoredViewer?.recordingID, recording.id)
        next.openViewer(recording)
        XCTAssertEqual(next.viewer.rendition, .podcast)
        XCTAssertEqual(next.viewer.currentOriginal ?? 0, 7.4, accuracy: 0.05, "at the moment it was left")
    }

    // MARK: Check 4: a clicked word plays, and Follow Playback moves on

    func testAClickedWordPlaysFromItAndTheMarkedSentenceFollows() async throws {
        let (model, recording) = try madeRecording()
        model.open(recording)
        model.openViewer(recording)
        let viewer = model.viewer
        viewer.player.isMuted = true
        XCTAssertEqual(viewer.rendition, .podcast)
        var report: [String] = []
        for rendition in [Rendition.podcast, .original] {
            if rendition != viewer.rendition { viewer.choose(rendition, recording: recording) }
            try await waitFor { viewer.player.currentItem?.status == .readyToPlay }
            let word = viewer.document.words[9]   // "practice", in the third sentence
            viewer.play(word: word.id)
            let clicked = Date()
            try await waitFor { viewer.player.rate > 0 && abs((viewer.currentOriginal ?? -9) - word.start) < 0.5 }
            let landed = viewer.player.currentTime().seconds
            let original = rendition == .original ? landed : (recording.episodeClock?.originalTime(landed) ?? landed)
            let off = abs(original - word.start)
            report.append(String(format: "%@: clicked \"%@\" at %.2f s on the original's clock; the player landed at %.3f s (%.3f s on the original's clock), %.3f s off, %.2f s after the click",
                                 rendition.rawValue, word.text, word.start, landed, original, off, Date().timeIntervalSince(clicked)))
            XCTAssertLessThanOrEqual(off, 0.25, "\(rendition): the player lands within 0.25 s of the word")
            viewer.pause()
        }
        // Follow Playback: from the first sentence, the marked sentence changes as time passes.
        viewer.choose(.podcast, recording: recording)
        XCTAssertTrue(viewer.followPlayback)
        viewer.play(word: 0)
        var seen: [Int] = []
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let id = viewer.currentSentence?.id, seen.last != id { seen.append(id) }
            try await Task.sleep(for: .milliseconds(100))
        }
        viewer.pause()
        report.append("Follow Playback: sentences marked over 8 s of playing: \(seen)")
        print(report.joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(seen.count, 3, "the marked sentence changes as time passes: \(seen)")
        XCTAssertEqual(seen, seen.sorted(), "in order")
        let folder = SnapshotRenderer.milestoneFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? (report.joined(separator: "\n") + "\n").write(to: folder.appending(path: "viewer-playback.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: Helpers

    /// A made recording of 20 s: a test pattern with a tone as its original, an episode.mp3 that starts 1 s
    /// in (the silence trim), and the made-up transcript.
    private func madeRecording() throws -> (AppModel, Recording) {
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: work.appending(path: "home")),
                             settings: .ephemeral(), log: AppLog(directory: nil))
        let folder = work.appending(path: "outputs", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = work.appending(path: "2026-10-12 viewer.mp4")
        try ffmpeg(["-f", "lavfi", "-i", "testsrc2=size=320x180:rate=10", "-f", "lavfi", "-i", "sine=frequency=330:sample_rate=48000",
                    "-t", "20", "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", original.path])
        try ffmpeg(["-f", "lavfi", "-i", "sine=frequency=220:sample_rate=44100", "-t", "19", "-c:a", "libmp3lame", "-b:a", "96k", folder.appending(path: "episode.mp3").path])
        let json: [String: Any] = ["sentences": Self.sentences().map { sentence in
            ["text": sentence.text, "start": sentence.start, "end": sentence.end,
             "tokens": (sentence.tokens ?? []).map { ["text": $0.text, "start": $0.start, "end": $0.end] }] }]
        try JSONSerialization.data(withJSONObject: json).write(to: folder.appending(path: TranscriptFiles.asHeard))
        let recording = Recording(filePath: original.path, recordedAt: Date(), foundAt: Date(), duration: 20, status: .readyForYourYes, kind: .talk)
        recording.outputFolder = folder.path
        recording.madeFiles = ["episode.mp3", TranscriptFiles.asHeard]
        recording.episodeDuration = 19
        recording.silenceTrimmedStart = 1
        recording.silenceTrimmedEnd = 0
        recording.madeAt = Date()
        model.context.insert(recording)
        try model.context.save()
        return (model, recording)
    }

    private func ffmpeg(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = ToolPaths.standard.ffmpeg
        process.arguments = ["-hide_banner", "-v", "error", "-y"] + arguments
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    private func waitFor(_ condition: () -> Bool, seconds: Double = 10) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
    }
}
