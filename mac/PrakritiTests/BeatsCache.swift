import Foundation
import XCTest
@testable import Prakriti

/// The beats the acceptance checks of v2 part M9d read (docs/v2/PLAN.md M9, checks 3 to 6), kept in development between runs:
/// `~/Prakriti/Dev/Beats/<recording>.json`. Qwen3.8-27B takes about 15 minutes for the 13 Sep talk and about an hour for the 6 Sep
/// talk; a make replaces the recording's output folder, so `beats.json` beside the plan does not survive from one check to the next.
/// A file here is used only when it was made from the very same transcript (its SHA-256) with the current request
/// (`BeatsFile.promptVersion`), exactly as the app's own cache is (`BeatsFile.cached`), so a stale file is never read.
enum BeatsCache {
    static var folder: URL { AppPaths(mode: .development).workRoot.appending(path: "Beats", directoryHint: .isDirectory) }

    static func file(_ recording: String) -> URL { folder.appending(path: recording + ".json") }

    /// The cached beats for this transcript, or nil.
    static func read(_ recording: String, transcriptSHA256: String) -> BeatsFile? {
        guard let data = try? Data(contentsOf: file(recording)), let beats = BeatsFile.decode(data),
              beats.transcriptSHA256 == transcriptSHA256, beats.promptVersion == BeatsFile.promptVersion, !beats.beats.isEmpty else { return nil }
        return beats
    }

    static func write(_ beats: BeatsFile) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try beats.encoded().write(to: file(beats.recording), options: .atomic)
    }

    /// Puts the cached beats beside a recording's plan, so the next plan reads them instead of asking the model. Returns them.
    @discardableResult
    static func seed(_ recording: String, folder: URL) -> BeatsFile? {
        guard let data = try? Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard)), let words = PlanWords.from(json: data),
              let beats = read(recording, transcriptSHA256: words.transcriptSHA256) else { return nil }
        try? beats.encoded().write(to: folder.appending(path: BeatsFile.fileName), options: .atomic)
        return beats
    }
}

/// Makes the beats of the 13 Sep and 6 Sep talks with Qwen3.8-27B in LM Studio from their development transcripts and keeps them in
/// `BeatsCache` (v2 part M9d). Not a check: a warm-up, so the checks that need beats do not each wait an hour.
///
///   cd ~/Code/prakriti/mac && TEST_RUNNER_PRAKRITI_ACCEPTANCE=beats xcodebuild ... -only-testing:PrakritiTests/BeatsWarmTests
///
/// Skipped unless PRAKRITI_ACCEPTANCE=beats. Reads only the development transcripts; nothing goes to a cloud provider.
@MainActor
final class BeatsWarmTests: XCTestCase {
    func testWarmTheBeats() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "beats" else { throw XCTSkip("Asks LM Studio for an hour. Run with PRAKRITI_ACCEPTANCE=beats.") }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        var setup = model.runner.writingSetup()
        setup.providers[.planning] = .lmStudio
        let only = environment["PRAKRITI_BEATS_ONLY"] ?? ""
        for (name, kind) in [("2026-09-13 18-25-44", RecordingKind.talk), ("2026-09-06 18-06-33", RecordingKind.talk)] where only.isEmpty || name.contains(only) {
            let folder = paths.outputs.appending(path: name, directoryHint: .isDirectory)
            let data = try Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))
            let words = try XCTUnwrap(PlanWords.from(json: data))
            if BeatsCache.read(name, transcriptSHA256: words.transcriptSHA256) != nil { print("\(name): beats already cached."); continue }
            let planner = Planner(setup: setup, log: model.log, subject: LockSubject(people: PeopleFacts(checked: true)), fileName: name + ".mp4")
            let client = planner.client()
            let duration = words.words.last?.end ?? 0
            let t = Date()
            let beats = try await planner.beats(words: words.words, recording: name, transcriptSHA256: words.transcriptSHA256, kind: kind,
                                                duration: duration, client: client)
            await planner.release(client)
            try BeatsCache.write(beats)
            print(String(format: "%@: %@ (%.0f s here); %d key phrases, %d key lines, %d hook candidates. Notes: %@", name, beats.line, Date().timeIntervalSince(t),
                         beats.beats.filter { $0.keyPhrase != nil }.count, beats.beats.filter { $0.keyLine != nil }.count,
                         beats.beats.filter(\.hookCandidate).count, beats.notes.joined(separator: " ")))
        }
    }
}
