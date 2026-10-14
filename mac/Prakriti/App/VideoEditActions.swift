import AppKit
import Foundation

// Restore and Remove on the edit plan's spans (v2 part M8c, design spec 3.4.3 and 3.5.0). A span of the Timeline-lite chosen on
// the Video, or on the Original once there is a plan, shows above the inspector's tabs with what it is and one action:
//
// - a stretch the plan took out (a pause shortened, a filler, a word said twice, a false start) has **Restore**: it goes into
//   `Recording.planRestores`, and the next plan keeps it as recorded (`RoughCut.Input.restored`);
// - Ivan's own cut or trim has **Restore** too, through v1's `keep` (the cut gives the time back, the trim moves);
// - time cut for someone he chose to Leave Out has no Restore here (research 3.4 rule 5: people are applied on top of the plan
//   and the plan cannot override them); the strip says to change it in People;
// - a stretch the plan keeps has **Remove** (and Delete): it becomes one of Ivan's cuts, so the podcast loses it too, as Remove
//   from the Edit on the words always has.
//
// Each change can be undone (Edit > Undo, Command-Z) and is "not in the video yet" until Make Again. A span already changed
// shows the opposite action (Take Out Again, Keep), so a second click undoes the first. Nothing here makes a file.

/// What a chosen span can have done to it now.
enum SpanEdit: Equatable {
    /// Taken out by the plan and still out: Restore brings it back.
    case restore
    /// Restored since the video was planned: not in the video yet; Take Out Again puts it back as planned.
    case restored
    /// Kept: Remove takes it out.
    case remove
    /// Removed since (a cut covers it): not in the video yet; Keep brings it back.
    case removed
    /// Ivan's own trim moved since: not in the video yet; Undo puts the trim back.
    case restoredTrim
    /// Time cut for someone left out: changed only in People.
    case person
    /// Nothing to do (the recording cannot be changed now).
    case none
}

extension Recording {
    /// What Ivan restored is not what the made video has (v2 part M8c).
    var restoresPending: Bool {
        guard let video else { return false }
        return !EditPlan.sameRestores(video.restored ?? [], planRestores)
    }
}

extension AppModel {
    /// The window's undo manager, for changes made from the keyboard or a menu (a view passes its own).
    var editUndoManager: UndoManager? {
        if let undoOverride { return undoOverride }
        return NSApp?.windows.first { $0.identifier?.rawValue.hasPrefix(MainWindow.id) == true }?.undoManager
    }

    /// Watch Video (the inspector's Edited video): the recording in the Viewer, on Video, from the start.
    func showVideo(_ recording: Recording) {
        if path.last?.id == recording.persistentModelID, viewer.recordingID == recording.id {
            if viewer.rendition != .video { viewer.choose(.video, recording: recording) }
            return
        }
        pendingSeek = PendingSeek(recordingID: recording.id, time: 0, play: false, rendition: .video)
        open(recording)
    }

    /// The video on show differs from the recording as Ivan has it now, in one sentence, or nil (v2 part M8c).
    func videoBehind(_ recording: Recording) -> String? {
        guard let plan = viewer.videoPlan, viewer.recordingID == recording.id else { return nil }
        if !plan.basis.edits.matches(recording.edits) || plan.basis.peopleSignature != recording.videoSignature
            || !EditPlan.sameRestores(plan.basis.restored ?? [], recording.planRestores) {
            return "Not in the video yet: your newest changes show once you Make Again."
        }
        return nil
    }

    /// What can be done to a span of the plan, as the recording stands now.
    func spanEdit(_ span: TimelineSpan, in recording: Recording) -> SpanEdit {
        guard canEditEpisode(recording) else { return .none }
        let range = TimeRange(start: span.start, end: span.end)
        if !span.isRemoved {
            return Self.covers(recording.edits.cuts, range) ? .removed : .remove
        }
        // The trim and cuts as they stand now, on the Original without a plan (v2 part M3b): Restore gives the time back.
        guard span.isPlanned else { return .restore }
        if span.reason == .person { return .person }
        if span.reason == .cut { return Self.overlaps(recording.edits.cuts, range) ? .restore : .restored }
        if Self.isIvansTrim(span) { return trimCovers(recording, range) ? .restore : .restoredTrim }
        return Self.overlaps(recording.planRestores, range) ? .restored : .restore
    }

    /// A span the plan took out because of Ivan's own trim (not the silence the rough cut trims before the first word).
    static func isIvansTrim(_ span: TimelineSpan) -> Bool {
        span.reason == .trimmed && span.detail?.hasPrefix("Your trim") == true
    }

    func trimCovers(_ recording: Recording, _ r: TimeRange) -> Bool {
        let edits = recording.edits
        return (edits.start.map { r.start < $0 - 0.001 } ?? false) || (edits.end.map { r.end > $0 + 0.001 } ?? false)
    }

    static func overlaps(_ ranges: [TimeRange], _ r: TimeRange) -> Bool {
        ranges.contains { $0.end > r.start + 0.001 && $0.start < r.end - 0.001 }
    }

    static func covers(_ ranges: [TimeRange], _ r: TimeRange) -> Bool {
        EpisodeEdits.merged(ranges).contains { $0.start <= r.start + 0.001 && $0.end >= r.end - 0.001 }
    }

    /// The span's one action, as the strip and Delete use it. Returns the problem, or nil.
    @discardableResult
    func applySpanEdit(_ span: TimelineSpan, in recording: Recording, undo: UndoManager? = nil) -> String? {
        let range = TimeRange(start: span.start, end: span.end)
        let before = EditSnapshot(recording)
        let name: String
        let problem: String?
        switch spanEdit(span, in: recording) {
        case .restore:
            name = "Restore"
            problem = !span.isPlanned || span.reason == .cut || Self.isIvansTrim(span) ? keep(range, in: recording) : addRestore(range, to: recording)
        case .restored:
            name = "Take Out Again"
            problem = span.reason == .cut ? addCut(range, to: recording) : removeRestore(range, from: recording)
        case .remove:
            name = "Remove"
            problem = addCut(range, to: recording)
        case .removed:
            name = "Keep"
            problem = keep(range, in: recording)
        case .restoredTrim, .person, .none:
            return nil
        }
        if let problem {
            notice = Notice(title: "Not changed", message: problem)
            return problem
        }
        registerEditUndo(undo ?? editUndoManager, recording: recording, before: before, name: name)
        return nil
    }

    /// Delete in the Viewer (design spec 6.7): removes the chosen kept span, or the selected words, from the edit.
    func deleteInViewer() {
        guard let recording = focusedRecording else { return }
        if let span = viewer.selectedSpan, spanEdit(span, in: recording) == .remove {
            applySpanEdit(span, in: recording)
        } else if viewer.selectedWords != nil, canRemoveSelectedWords(recording) {
            removeSelectedWords(from: recording)
        }
    }

    /// A stretch of the plan brought back (v2 part M8c).
    func addRestore(_ range: TimeRange, to recording: Recording) -> String? {
        guard range.end > range.start else { return nil }
        recording.planRestores = EpisodeEdits.merged(recording.planRestores + [range])
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): \(TimeText.string(range.start)) to \(TimeText.string(range.end)) restored in the edit. Make Again to see it in the video.")
        changedAfterApproval(recording, what: "a restore")
        try? context.save()
        return nil
    }

    /// A restore taken back: the plan may take that stretch out again.
    func removeRestore(_ range: TimeRange, from recording: Recording) -> String? {
        let kept = recording.planRestores.filter { !($0.end > range.start + 0.001 && $0.start < range.end - 0.001) }
        guard kept.count != recording.planRestores.count else { return nil }
        recording.planRestores = kept
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): \(TimeText.string(range.start)) to \(TimeText.string(range.end)) may be taken out again. Make Again to see it in the video.")
        changedAfterApproval(recording, what: "a restore")
        try? context.save()
        return nil
    }

    /// Puts a recording's trim, cuts and restores back as they were (Undo and Redo).
    func restoreEdits(_ snapshot: EditSnapshot, in recording: Recording) {
        guard EditSnapshot(recording) != snapshot else { return }
        recording.edits = snapshot.edits
        recording.planRestores = snapshot.restores
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): an edit was undone. Make Again to hear and see it.")
        changedAfterApproval(recording, what: "an undo")
        try? context.save()
    }

    /// Undo and Redo for a change of the trim, cuts or restores.
    func registerEditUndo(_ undo: UndoManager?, recording: Recording, before: EditSnapshot, name: String) {
        let after = EditSnapshot(recording)
        guard before != after, let undo else { return }
        undo.registerUndo(withTarget: self) { model in
            model.restoreEdits(before, in: recording)
            model.registerEditUndo(undo, recording: recording, before: after, name: name)
        }
        undo.setActionName(name)
    }
}

/// A recording's trim, cuts and restores at one moment, for Undo.
struct EditSnapshot: Equatable {
    var edits: EpisodeEdits
    var restores: [TimeRange]

    @MainActor
    init(_ recording: Recording) {
        edits = recording.edits
        restores = recording.planRestores
    }
}
