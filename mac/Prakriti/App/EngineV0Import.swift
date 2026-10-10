import Foundation
import SwiftData

/// The switch-over's memory: everything engine v0 already saw, read from ~/Prakriti/state.json and
/// written into the store as recordings, before the watcher's first look. Reason: v0 marked every
/// file already in the folders on its first start (8 Oct), then made episodes from three; the app
/// must not start again on any of them. Without this, its first look would take the classes of 16,
/// 20 and 23 Sep, which may not be processed (student privacy), as new recordings.
///
/// Only paths are compared: the import never opens a studio file (reading the Documents folder
/// can wait on macOS's permission prompt, and the import runs before the window opens). It reads
/// v0's REPORT.md beside an episode for its numbers; that file is a table, not a transcript.
@MainActor
enum EngineV0Import {
    struct State: Decodable {
        var baselined: String?
        var files: [String: Entry]

        struct Entry: Decodable {
            var status: String?
            var size: Int64?
            var at: String?
            var duration: Double?
            var output: String?
            var seconds: Double?
            var error: String?
            var tries: Int?
        }
    }

    struct Summary: Equatable {
        var imported = 0
        var alreadyKnown = 0
        var byStatus: [String: Int] = [:]

        var line: String {
            let parts = byStatus.sorted { $0.key < $1.key }.map { "\($0.value) \($0.key)" }.joined(separator: ", ")
            return "Took over from the old engine: \(Format.count(imported, "file")) it had already seen were added as they were (\(parts)), so none of them is made again."
                + (alreadyKnown > 0 ? " \(alreadyKnown) were already known." : "")
        }
    }

    /// v0 wrote local times as "2026-10-08 16:17:39".
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: text)
    }

    static func read(_ url: URL) throws -> State {
        try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
    }

    /// Adds every file v0 knew that the store does not, with v0's outcome. Starts nothing.
    @discardableResult
    static func run(_ state: State, into model: AppModel) -> Summary {
        var summary = Summary()
        let known = Set(((try? model.context.fetch(FetchDescriptor<Recording>())) ?? []).map(\.filePath))
        let v0Start = date(state.baselined).map { Format.dayLabel($0) } ?? "8 Oct"
        for (path, entry) in state.files.sorted(by: { $0.key < $1.key }) {
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            if known.contains(standardized) {
                summary.alreadyKnown += 1
                continue
            }
            let at = date(entry.at)
            let recording = Recording(filePath: standardized, recordedAt: AppModel.dateInName((path as NSString).lastPathComponent),
                                      foundAt: at ?? model.now(), duration: entry.duration, sizeBytes: entry.size ?? 0, status: .skipped)
            recording.fromEngineV0 = true
            recording.intent = .none
            let when = at.map { " on " + Format.dayLabel($0) } ?? ""
            let status = entry.status ?? "unknown"
            switch status {
            case "existing":
                recording.status = .skipped
                recording.statusReason = "Already in this folder when the old engine started watching on \(v0Start), so nothing was made from it."
            case "ready":
                let folder = entry.output.map { URL(fileURLWithPath: $0, isDirectory: true) }
                if let folder, FileManager.default.fileExists(atPath: folder.appending(path: "episode.mp3").path) {
                    recording.status = .readyForYourYes
                    recording.outputFolder = folder.path
                    recording.statusReason = "Made by the old engine\(when). Episode audio and transcript are ready. Speakers are not checked yet."
                    readReport(folder.appending(path: "REPORT.md"), into: recording)
                } else {
                    recording.status = .skipped
                    recording.statusReason = "Made by the old engine\(when). Its files are no longer there."
                }
            case "silent":
                recording.status = .needsADecision
                recording.statusReason = "No usable sound, found by the old engine\(when). Nothing was made from it."
            case "test":
                recording.status = .skipped
                recording.kind = .test
                recording.statusReason = "Under 60 seconds, so the old engine filed it as a test. Nothing was made."
            default:
                // "failed", or "checking" and "processing" left by a stop: v0 never finished it.
                // Listed as Couldn't finish with Try Again, never started on its own.
                recording.status = .couldntFinish
                recording.statusReason = "The old engine could not finish it\(when). The original is untouched; try again from here."
            }
            summary.byStatus[status, default: 0] += 1
            model.context.insert(recording)
            recording.source = model.source(containing: URL(fileURLWithPath: standardized))
            summary.imported += 1
        }
        try? model.context.save()
        return summary
    }

    /// The numbers from v0's report table: "-16.8 LUFS, true peak -1.6 dBFS", "2948 words; reaches
    /// 15:47 of 15:48", "loudest -3.4 dB". Anything it cannot read stays empty.
    static func readReport(_ url: URL, into recording: Recording) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        if let m = text.firstMatch(of: /(-?\d+(?:\.\d+)?) LUFS, true peak (-?\d+(?:\.\d+)?) dBFS/) {
            recording.loudnessLUFS = Double(m.1)
            recording.truePeakDBFS = Double(m.2)
        }
        if let m = text.firstMatch(of: /average (-?\d+(?:\.\d+)?) dB, loudest (-?\d+(?:\.\d+)?) dB; loudness (-?\d+(?:\.\d+)?) LUFS/) {
            recording.averageDB = Double(m.1)
            recording.loudestDB = Double(m.2)
            recording.inputLUFS = Double(m.3)
        }
        if let m = text.firstMatch(of: /(\d+) words; (reaches|STOPS at) ((?:\d+:)?\d+:\d+)/) {
            recording.wordCount = Int(m.1)
            recording.coverageOK = m.2 == "reaches"
            recording.transcriptReaches = seconds(String(m.3))
        }
    }

    static func seconds(_ timecode: String) -> Double? {
        let parts = timecode.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
}
