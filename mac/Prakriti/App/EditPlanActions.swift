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
        // The House Style it was made with (v2 part M9a). A plan made before M9a records none and is not called behind:
        // no new work starts on its own (PLAN rule 2.1.7).
        if let house = plan.basis.house, house != settings.houseStyle.signature {
            return "Your newest House Style settings are not in the plan yet."
        }
        // The direction it was made with (v2 part M9c). A plan made before M9c records none, read as no direction.
        if (plan.basis.direction ?? "") != recording.direction.signature {
            return "Your newest direction is not in the plan yet."
        }
        // The title on screen (v2 part M9b) is the recording's title as it was when the plan was made.
        if let shown = plan.visual.first(where: { $0.kind == EditPlan.Visual.title })?.lines?.joined(separator: " "),
           shown != recording.title.split(whereSeparator: \.isWhitespace).joined(separator: " ") {
            return "Your newest title is not on screen in the plan yet."
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
        planningLines[id] = planningLine(for: recording)
        let output = URL(fileURLWithPath: folder, isDirectory: true)
        let job = output.deletingLastPathComponent().appending(path: ".planning " + output.lastPathComponent, directoryHint: .isDirectory)
        var options = runner.options(for: recording)
        options.planEdit = true
        // The parts of the talk (v2 part M9d) are read for every plan, not only a directed one.
        if options.planning == nil && runner.askForBeats { options.planning = runner.writingSetup() }
        let pipeline = Pipeline(tools: runner.tools, options: options, log: log)
        let capture = recording.capture, faces = recording.faces, voices = recording.voices, namesSaid = recording.namesSaid
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        record("\(label): planning the edit.")
        Task { @MainActor in
            defer {
                planning.remove(id)
                planningLines[id] = nil
            }
            do {
                let outcome = try await Task.detached {
                    let fm = FileManager.default
                    try? fm.removeItem(at: job)
                    try fm.createDirectory(at: job, withIntermediateDirectories: true)
                    defer { try? fm.removeItem(at: job) }
                    try fm.copyItem(at: output.appending(path: TranscriptFiles.asHeard), to: job.appending(path: TranscriptFiles.asHeard))
                    let outcome = try await pipeline.planTheEdit(file: file, staging: job, duration: duration, capture: capture, namesSaid: namesSaid,
                                                                 faces: faces, voices: voices)
                    // The plan, and the beats it was chosen from when there are any (v2 part M9c).
                    for name in [EditPlan.fileName, BeatsFile.fileName] where fm.fileExists(atPath: job.appending(path: name).path) {
                        let destination = output.appending(path: name)
                        if fm.fileExists(atPath: destination.path) {
                            _ = try fm.replaceItemAt(destination, withItemAt: job.appending(path: name))
                        } else {
                            try fm.moveItem(at: job.appending(path: name), to: destination)
                        }
                    }
                    return outcome
                }.value
                guard let current = fetchRecording(id) else { return }
                if !current.madeFiles.contains(EditPlan.fileName) { current.madeFiles = (current.madeFiles + [EditPlan.fileName]).sorted() }
                if FileManager.default.fileExists(atPath: output.appending(path: BeatsFile.fileName).path), !current.madeFiles.contains(BeatsFile.fileName) {
                    current.madeFiles = (current.madeFiles + [BeatsFile.fileName]).sorted()
                }
                try? context.save()
                forgetEditPlan(current)
                record("\(label): the edit plan. " + outcome.stepLine + String(format: " Planned in %.1f s.", outcome.seconds))
            } catch {
                let reason = (error as? PlanStep.Failure)?.reason ?? (error as? PipelineFailure)?.reason ?? error.localizedDescription
                planProblems[id] = reason
                record("\(label): the edit plan was not made. \(reason)", level: .attention)
            }
        }
    }
}

extension AppModel {
    /// What Plan the Edit is doing, in one line, when it asks a model (v2 part M9c): the beats take minutes the first time.
    func planningLine(for recording: Recording) -> String? {
        let direction = recording.direction
        let reading = Direction.read(direction, house: settings.houseStyle)
        let provider = settings.provider[.planning] ?? .lmStudio
        var asks: [String] = []
        // Since v2 part M9d every plan of a recording with a picture reads the parts of the talk once (the opening line, key
        // phrases, terms, chapters, the held moment).
        let picture = recording.capture?.video != nil || recording.faces != nil
        if reading.fields.needsBeats || (picture && runner.askForBeats), let folder = recording.outputFolder {
            let url = URL(fileURLWithPath: folder, isDirectory: true)
            let sha = (try? Data(contentsOf: url.appending(path: TranscriptFiles.asHeard))).map(PlanWords.sha256) ?? ""
            if BeatsFile.cached(in: url, transcriptSHA256: sha) == nil {
                asks.append("reading the parts of the talk with \(provider.title) first, which takes a few minutes the first time")
            }
        }
        if !reading.unread.isEmpty, (editPlan(for: recording)?.direction?.reading?.modelReadFor ?? "") != reading.unread.joined(separator: " ") {
            asks.append("asking \(provider.title) to read your own words")
        }
        return asks.isEmpty ? nil : "Planning the edit: " + asks.joined(separator: ", and ") + "."
    }

    /// Saves a change to the recording's direction (v2 part M9c). Nothing is planned or made until Ivan asks.
    func setDirection(_ direction: RecordingDirection, for recording: Recording) {
        guard recording.direction != direction else { return }
        recording.direction = direction
        recording.updatedAt = now()
        try? context.save()
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
