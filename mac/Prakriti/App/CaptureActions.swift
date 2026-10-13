import Foundation
import SwiftData

// Check Capture (v2 part M4b): the capture check on a recording found before it existed. New recordings get it
// as the first step of their make; an older one waits for Ivan's click, because an upgrade never starts work by
// itself (docs/v2/PLAN.md rule 2.1.7). It only reads the original, like every check: ffprobe once and ffmpeg
// once per audio track, about 3 s for a 15-minute talk on this Mac. Nothing is made and no status changes.
extension AppModel {
    func checkCapture(_ recording: Recording) {
        guard !captureChecking.contains(recording.id) else { return }
        let id = recording.id
        let file = URL(fileURLWithPath: recording.filePath)
        captureProblems[id] = nil
        guard FileManager.default.fileExists(atPath: file.path) else {
            captureProblems[id] = "The original is not where it was found, so it cannot be checked."
            return
        }
        // Reading an iCloud placeholder would start a download of the whole file; the watcher does that one file
        // at a time, so Check Capture leaves it alone.
        guard !Readiness.isDataless(file) else {
            captureProblems[id] = "The original is in iCloud and not on this Mac yet, so it cannot be checked."
            return
        }
        captureChecking.insert(id)
        let tools = runner.tools
        let limit = Duration.seconds(600 + Int((recording.duration ?? 0).rounded(.up)))
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        Task { @MainActor in
            defer { captureChecking.remove(id) }
            do {
                let report = try await CaptureCheck.run(file: file, tools: tools, now: now(), measureTrack: { arguments in
                    try await Subprocess.run(tools.ffmpeg, arguments, timeout: limit).stderr
                })
                guard let current = try? context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.id == id })).first else { return }
                current.captureJSON = report.json()
                record("\(label): capture check. " + report.summary
                       + (report.warnings.isEmpty ? "" : " " + report.warnings.map(\.title).joined(separator: "; ") + "."),
                       level: report.warnings.isEmpty ? .info : .attention)
                try? context.save()
            } catch {
                captureProblems[id] = "The capture check stopped before it finished."
            }
        }
    }
}
