import Foundation

/// The status line for the menu bar and the top of Needs You.
@MainActor
extension AppModel {
    func statusSummary(recordings: [Recording], sources: [Source]) -> StatusSummary {
        let working = recordings.first { $0.status == .working }
        let blocked = sources.filter { watcher.states[$0.id]?.isBlocked == true }.map(\.name)
        return StatusSummary.make(
            isWatching: isWatching,
            isPaused: settings.isPaused,
            folderNames: sources.map(\.name),
            blockedFolders: blocked,
            needsYou: recordings.filter(\.status.needsYou).count,
            problems: recordings.filter { $0.status == .couldntFinish }.count,
            working: working.map { (Format.dayLabel($0.sessionDate), $0.currentStep ?? "Working") })
    }
}


/// The one sentence that says what Prakriti is doing, used by the menu bar and Needs You.
/// Never "Processing...": the step is named.
struct StatusSummary: Equatable, Sendable {
    /// The state's shape. The raw values are SF Symbols, which Needs You draws inside the window, where
    /// SF Symbols belong; the menu bar draws `menuBarAsset` instead.
    enum Icon: String, CaseIterable, Sendable {
        case idle = "circle"
        case notWatching = "circle.dashed"
        case working = "circle.dotted"
        case waitingForYou = "circle.inset.filled"
        case problem = "exclamationmark.circle"
        case paused = "pause.circle"

        /// The menu bar's template glyph for this state: the app icon's cut disc, one shape per state
        /// (docs/v2/icons/README.md, "The menu bar"). A shape, never a color, tells the states apart,
        /// and paused and not watching are outlines rather than dimmed, because macOS already dims
        /// the menu bar on a display that is not active.
        var menuBarAsset: String {
            switch self {
            case .idle: "prakriti-menubar"
            case .notWatching: "prakriti-menubar-not-watching"
            // The first of the two working frames; `WorkingTicker` swaps in the second every 0.7 s.
            case .working: Self.workingFrames[0]
            case .waitingForYou: "prakriti-menubar-waiting"
            case .problem: "prakriti-menubar-problem"
            case .paused: "prakriti-menubar-paused"
            }
        }

        /// The two frames of the working state: the halves lit in turn.
        static let workingFrames = ["prakriti-menubar-working-1", "prakriti-menubar-working-2"]
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
        // there go unseen until he answers. Work in progress has its own section in In Progress.
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
