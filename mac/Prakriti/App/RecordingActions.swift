import Foundation
import SwiftData

// What Ivan does on a recording's page (milestone 5): set where the episode starts and ends, mark
// sections to cut, say what the recording is, and Approve. Each leaves one line in Activity. A
// change to an approved recording takes its approval back (SCOPE 9.1 #6: any change after a yes
// voids it), and the approved copy stays where it is until he approves again.
extension AppModel {
    private func label(_ recording: Recording) -> String {
        "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
    }

    // MARK: Trim and cuts

    /// Sets where the episode starts and ends (nil: the recording's own start or end). Returns the
    /// problem in one plain sentence and changes nothing when the times cannot work.
    @discardableResult
    func setTrim(start: Double?, end: Double?, for recording: Recording) -> String? {
        var edits = recording.edits
        edits.start = start.flatMap { $0 <= 0.001 ? nil : $0 }
        edits.end = end.flatMap { value in recording.duration.map { value >= $0 - 0.001 } == true ? nil : value }
        if let problem = problem(edits, recording) { return problem }
        guard !edits.matches(recording.edits) else { return nil }
        let before = recording.edits
        recording.edits = edits
        var said: [String] = []
        if !Self.same(before.start, edits.start) {
            said.append(edits.start.map { "the episode now starts at \(TimeText.string($0))" } ?? "the episode starts at the beginning again")
        }
        if !Self.same(before.end, edits.end) {
            said.append(edits.end.map { "it now ends at \(TimeText.string($0))" } ?? "it runs to the end again")
        }
        record("\(label(recording)): " + said.joined(separator: ", and ") + ". Make Again to hear it.")
        changedAfterApproval(recording, what: "its trim")
        try? context.save()
        return nil
    }

    /// Marks a section to cut. Overlapping or touching cuts become one. Returns the problem, or nil.
    @discardableResult
    func addCut(_ cut: TimeRange, to recording: Recording) -> String? {
        guard cut.end > cut.start else {
            return "A cut must end after it starts."
        }
        if let duration = recording.duration, cut.start >= duration {
            return "The cut starts after the end of the recording (\(TimeText.string(duration)))."
        }
        let clamped = TimeRange(start: max(0, cut.start), end: recording.duration.map { min($0, cut.end) } ?? cut.end)
        let edits = recording.edits.adding(cut: clamped)
        if let problem = problem(edits, recording) { return problem }
        recording.edits = edits
        record("\(label(recording)): cut \(TimeText.string(clamped.start)) to \(TimeText.string(clamped.end)) (\(Format.length(clamped.end - clamped.start))) marked. Make Again to hear it.")
        changedAfterApproval(recording, what: "a cut")
        try? context.save()
        return nil
    }

    func removeCut(_ cut: TimeRange, from recording: Recording) {
        var edits = recording.edits
        edits.cuts.removeAll { abs($0.start - cut.start) < 0.001 && abs($0.end - cut.end) < 0.001 }
        guard edits.cuts.count != recording.cuts.count else { return }
        recording.edits = edits
        record("\(label(recording)): the cut \(TimeText.string(cut.start)) to \(TimeText.string(cut.end)) was taken back. Make Again to hear it.")
        changedAfterApproval(recording, what: "a cut")
        try? context.save()
    }

    /// Clears the trim and every cut.
    func clearEdits(_ recording: Recording) {
        guard !recording.edits.isEmpty else { return }
        recording.edits = EpisodeEdits()
        record("\(label(recording)): the trim and cuts were cleared. Make Again to hear it.")
        changedAfterApproval(recording, what: "its trim and cuts")
        try? context.save()
    }

    private func problem(_ edits: EpisodeEdits, _ recording: Recording) -> String? {
        guard let duration = recording.duration else { return nil }
        let silence: Mastering.Span? = recording.silenceTrimmedStart.map { start in
            Mastering.Span(start: start, end: duration - (recording.silenceTrimmedEnd ?? 0))
        }
        return edits.problem(duration: duration, silence: silence)
    }

    private static func same(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): abs(a - b) < 0.01
        default: false
        }
    }

    // MARK: What it is

    /// Says what the recording is. A class is privacy locked; only a talk can be approved until
    /// speaker checks exist.
    func setKind(_ kind: RecordingKind, for recording: Recording) {
        guard recording.kind != kind, kind != .test else { return }
        recording.kind = kind
        let what: String = switch kind {
        case .talk: "a talk with one teacher speaking"
        case .lesson: "a class. It can be approved once its people are checked"
        case .conversation: "a conversation. It can be approved once its people are checked"
        case .unknown: "not set. It can be approved once its people are checked, or once it is marked as a talk"
        case .test: "a test"
        }
        record("\(label(recording)) marked as \(what).")
        changedAfterApproval(recording, what: "what it is")
        try? context.save()
    }

    /// A change to an approved recording takes its approval back. The approved copy stays in its
    /// folder until Ivan approves again, which replaces it.
    func changedAfterApproval(_ recording: Recording, what: String) {
        guard recording.status.isApproved else { return }
        recording.status = .readyForYourYes
        recording.statusReason = "Changed after it was approved (\(what)). The approved copy is from before the change; approve again to replace it."
        record("\(label(recording)) changed after it was approved (\(what)), so it waits for your yes again. The approved copy was left as it was.", level: .attention)
        try? context.save()
    }

    // MARK: Approve

    /// Whether it can be approved now, and why not.
    func approvalCheck(_ recording: Recording) -> ApprovalCheck {
        ApprovalCheck.check(recording, isBusy: runner.isCurrent(recording) || runner.isWaiting(recording))
    }

    /// The receipt's People section (v2 part M6c): each person's choice for the podcast, the names muted, and the audio
    /// output check. Empty when the people check never ran on it.
    func receiptPeople(_ recording: Recording) -> [String] {
        guard recording.voices != nil, recording.faces != nil else { return [] }
        var lines = recording.choiceLines
        let muted = recording.madeMutes.count
        let kept = (recording.namesSaid?.moments.count ?? 0) - muted
        if muted + kept > 0 { lines.append("Names said aloud: \(Format.number(max(0, kept))) kept, \(Format.number(muted)) muted (written as \(EpisodeTranscript.mutedWord)).") }
        if let check = recording.peopleApplied?.check { lines.append("Who is heard: " + check.line { recording.label(forVoice: $0) }) }
        return lines
    }

    /// Where Approve puts this recording's files: ~/Prakriti/Approved/<the file's name>, beside its
    /// folder in ~/Prakriti/Outputs, which has the same name.
    func approvedFolder(for recording: Recording) -> URL {
        paths.approved.appending(path: URL(fileURLWithPath: recording.filePath).deletingPathExtension().lastPathComponent, directoryHint: .isDirectory)
    }
}
