import Foundation
import SwiftData

// The edit plan in the app (v2 part M8a): Plan the Edit, which plans a recording already made without making anything
// else, and the plan as the window reads it. The plan is `edit-plan.json` in the recording's output folder; nothing about
// it is stored in the store, so no store change comes with it. Once a recording has a plan, every make plans it again
// (`PipelineRunner.options`), so it follows Ivan's newest trim, cuts and choices.
extension AppModel {
    /// The plan in the recording's folder, read when the file changes, or nil.
    func editPlan(for recording: Recording) -> EditPlan? {
        _ = planRevision
        guard let folder = recording.outputFolder else { return nil }
        let path = URL(fileURLWithPath: folder, isDirectory: true).appending(path: EditPlan.fileName).path
        guard let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date else { return nil }
        if let cached = planCache[path], cached.modified == modified { return cached.plan }
        let plan = EditPlan.read(folder: folder)
        planCache[path] = (modified, plan)
        return plan
    }

    /// The window reads the recording's plan again.
    func forgetEditPlan(_ recording: Recording) {
        planRevision += 1
    }

    /// What stands between the plan on disk and the recording as Ivan has it now, in one sentence, or nil.
    func planIsBehind(_ recording: Recording, plan: EditPlan) -> String? {
        if !plan.basis.edits.matches(recording.edits) {
            return "Your newest trim and cuts are not in the plan yet."
        }
        if plan.basis.peopleSignature != recording.videoSignature {
            return "Your newest choices of who is in the video are not in the plan yet."
        }
        if !EditPlan.sameRestores(plan.basis.restored ?? [], recording.planRestores) {
            return "What you restored is not in the plan yet."
        }
        return nil
    }

    /// Show in the Viewer: the Original, where the Timeline-lite draws the plan, at the moment it was left at.
    func showPlan(_ recording: Recording) {
        if path.last?.id == recording.persistentModelID, viewer.recordingID == recording.id {
            if viewer.rendition != .original { viewer.choose(.original, recording: recording) }
            return
        }
        pendingSeek = PendingSeek(recordingID: recording.id, time: 0, play: false, rendition: .original)
        open(recording)
    }

    /// Plan the Edit can run: the transcript is made, nothing is being made or planned, and the original is here.
    func canPlanEdit(_ recording: Recording) -> Bool {
        guard recording.outputFolder != nil, recording.madeFiles.contains(TranscriptFiles.asHeard) else { return false }
        return !planning.contains(recording.id) && !runner.isCurrent(recording) && !runner.isWaiting(recording)
    }

    /// Plan the Edit: the rough cut of a recording already made, from its transcript.json and the original's sound, with
    /// Ivan's trim and cuts and the people he left out of the video applied. Writes `edit-plan.json` into its output folder
    /// through a job folder beside it, and makes nothing else.
    func planEdit(_ recording: Recording) {
        guard canPlanEdit(recording), let folder = recording.outputFolder else { return }
        let id = recording.id
        planProblems[id] = nil
        let file = URL(fileURLWithPath: recording.filePath)
        guard FileManager.default.fileExists(atPath: file.path) else {
            planProblems[id] = "The original is not where it was found, so the edit cannot be planned."
            return
        }
        guard !Readiness.isDataless(file) else {
            planProblems[id] = "The original is in iCloud and not on this Mac yet, so the edit cannot be planned."
            return
        }
        guard let duration = recording.duration else {
            planProblems[id] = "The recording's length is not known yet, so the edit cannot be planned."
            return
        }
        planning.insert(id)
        let output = URL(fileURLWithPath: folder, isDirectory: true)
        let job = output.deletingLastPathComponent().appending(path: ".planning " + output.lastPathComponent, directoryHint: .isDirectory)
        var options = runner.options(for: recording)
        options.planEdit = true
        let pipeline = Pipeline(tools: runner.tools, options: options, log: log)
        let capture = recording.capture, faces = recording.faces, voices = recording.voices, namesSaid = recording.namesSaid
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        record("\(label): planning the edit.")
        Task { @MainActor in
            defer { planning.remove(id) }
            do {
                let outcome = try await Task.detached {
                    let fm = FileManager.default
                    try? fm.removeItem(at: job)
                    try fm.createDirectory(at: job, withIntermediateDirectories: true)
                    defer { try? fm.removeItem(at: job) }
                    try fm.copyItem(at: output.appending(path: TranscriptFiles.asHeard), to: job.appending(path: TranscriptFiles.asHeard))
                    let outcome = try await pipeline.planTheEdit(file: file, staging: job, duration: duration, capture: capture, namesSaid: namesSaid,
                                                                 faces: faces, voices: voices)
                    let destination = output.appending(path: EditPlan.fileName)
                    if fm.fileExists(atPath: destination.path) {
                        _ = try fm.replaceItemAt(destination, withItemAt: job.appending(path: EditPlan.fileName))
                    } else {
                        try fm.moveItem(at: job.appending(path: EditPlan.fileName), to: destination)
                    }
                    return outcome
                }.value
                guard let current = fetchRecording(id) else { return }
                if !current.madeFiles.contains(EditPlan.fileName) { current.madeFiles = (current.madeFiles + [EditPlan.fileName]).sorted() }
                try? context.save()
                forgetEditPlan(current)
                record("\(label): the edit plan. " + outcome.plan.summary + String(format: " Planned in %.1f s.", outcome.seconds))
            } catch {
                let reason = (error as? PlanStep.Failure)?.reason ?? (error as? PipelineFailure)?.reason ?? error.localizedDescription
                planProblems[id] = reason
                record("\(label): the edit plan was not made. \(reason)", level: .attention)
            }
        }
    }
}

extension Recording {
    /// Who is left out of the video as the choices stand now, in the shape `EditPlan.People.applied` keeps (v2 part M8a).
    var videoSignature: String {
        let out = voices.map { choices.leftOutVoices($0, names: resolvedNames.resolved(faces: faces, voices: voices), output: .video) } ?? []
        let muted = choices.muted(namesSaid?.moments ?? [])
        return Pipeline.signature(left: out, muted: muted)
    }
}
