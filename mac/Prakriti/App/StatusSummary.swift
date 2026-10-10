import Foundation

/// The one sentence that says what Prakriti is doing, used by the menu bar and Today.
/// Never "Processing...": the step is named.
struct StatusSummary: Equatable, Sendable {
    enum Icon: String, Sendable {
        case idle = "circle"
        case notWatching = "circle.dashed"
        case working = "circle.dotted"
        case waitingForYou = "circle.inset.filled"
        case problem = "exclamationmark.circle"
        case paused = "pause.circle"
    }

    let line: String
    let icon: Icon

    /// - Parameters:
    ///   - isWatching: the watcher is running (false until milestone 3 builds it).
    ///   - working: the label and current step of the recording being worked on, if any.
    static func make(isWatching: Bool, isPaused: Bool, folderNames: [String], blockedFolders: [String] = [], needsYou: Int,
                     problems: Int, working: (label: String, step: String)?) -> StatusSummary {
        if isPaused {
            return StatusSummary(line: "Paused. Nothing new is processed until you resume.", icon: .paused)
        }
        // A folder that cannot be read wins over work in progress: it needs Ivan, and new recordings
        // there go unseen until he answers. Work in progress has its own section on Today.
        if isWatching && !blockedFolders.isEmpty {
            return StatusSummary(line: "Watching " + folderPhrase(folderNames) + ". " + folderPhrase(blockedFolders)
                                 + " cannot be read yet: macOS needs your OK. See Sources.", icon: .problem)
        }
        // Work in progress is named even when not watching: Process File runs the pipeline.
        if let working {
            return StatusSummary(line: "Working on \(working.label): \(working.step.lowercasedFirst)", icon: .working)
        }
        if !isWatching {
            return StatusSummary(line: AppMode.switchedOver ? "Not watching. New recordings wait until Prakriti watches again."
                                                            : "Not watching yet. The old engine still handles new recordings.", icon: .notWatching)
        }
        let watching = "Watching " + folderPhrase(folderNames) + "."

        if needsYou > 0 {
            let waiting = needsYou == 1 ? "1 recording needs you." : "\(needsYou) recordings need you."
            return StatusSummary(line: watching + " " + waiting, icon: problems > 0 ? .problem : .waitingForYou)
        }
        return StatusSummary(line: watching + " Nothing waiting.", icon: .idle)
    }

    static func folderPhrase(_ names: [String]) -> String {
        switch names.count {
        case 0: "no folders"
        case 1: names[0]
        case 2: names[0] + " and " + names[1]
        default: "\(names.count) folders"
        }
    }
}

extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
