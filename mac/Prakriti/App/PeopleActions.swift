import Foundation
import SwiftData

// Voices and names (v2 part M6b, docs/v2/PLAN.md M6): what the voice step heard, applied to a recording; Check People
// for a recording found before the people pass existed (the face step, then the voice step, never started by an
// upgrade, PLAN rule 2.1.7); and Ivan's naming: the people named in Settings, Privacy, Who Is Teaching, Name for This
// Recording, and a folder's microphone tracks. Names are not biometric: nothing about a face or a voice is kept for
// any of them.
extension AppModel {
    /// Keeps what the voice step heard on the recording and writes it to Activity. No notice: until someone is named,
    /// every voice is "not named", the teacher's too, so a notice would say nothing new.
    func applyVoices(_ voices: VoicesFound, to recording: Recording, run: Run? = nil) {
        recording.voicesJSON = voices.json()
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): voices. " + voices.stepLine,
               level: voices.voices.count >= 2 ? .attention : .info, run: run)
    }

    /// Check People: the face step and the voice step on their own, for a recording that has not had them or to
    /// check again. Reads the original only and makes nothing else.
    func checkPeople(_ recording: Recording) {
        guard !faceChecking.contains(recording.id) else { return }
        let id = recording.id
        let file = URL(fileURLWithPath: recording.filePath)
        faceProblems[id] = nil
        guard FileManager.default.fileExists(atPath: file.path) else {
            faceProblems[id] = "The original is not where it was found, so it cannot be checked."
            return
        }
        // Reading an iCloud placeholder would start a download of the whole file; the watcher does that one file
        // at a time, so Check People leaves it alone.
        guard !Readiness.isDataless(file) else {
            faceProblems[id] = "The original is in iCloud and not on this Mac yet, so it cannot be checked."
            return
        }
        faceChecking.insert(id)
        let folders = peopleFolders
        let started = now()
        let ffmpeg = runner.tools.ffmpeg
        let limit = Duration.seconds(600 + Int((recording.duration ?? 0).rounded(.up)))
        let tracks = recording.capture?.audio.count
        let log = self.log
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        Task { @MainActor in
            defer { faceChecking.remove(id) }
            do {
                let faces = try await Task.detached { try await FaceStep.run(file: file, recordingID: id, folders: folders, now: started) }.value
                if let current = fetchRecording(id) {
                    applyFaces(faces.found, to: current)
                    try? context.save()
                }
                let voices = try await Task.detached {
                    let count: Int
                    if let tracks { count = tracks } else { count = await VoiceStep.audioTracks(file) }
                    return try await VoiceStep.run(file: file, recordingID: id, folders: folders, audioTracks: count, now: started,
                                                   decode: { arguments in _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: limit) },
                                                   log: { line in log.write("\(label): voices. " + line) })
                }.value
                guard let current = fetchRecording(id) else { return }
                applyVoices(voices.found, to: current)
                try? context.save()
                refreshCardPicture(current)
            } catch {
                let detail = (error as? FaceScan.Failure)?.reason ?? (error as? VoiceStep.Failure)?.reason ?? (error as? Diarizer.Failure)?.reason
                    ?? (error as? ToolError)?.logLine ?? error.localizedDescription
                faceProblems[id] = "People could not be checked. \(detail)"
                record("People could not be checked in \(recording.fileName). \(detail)", level: .attention)
                // The faces may have been found before the voices failed: the card picture follows them.
                if let current = fetchRecording(id), current.faces != nil { refreshCardPicture(current) }
            }
        }
    }

    func fetchRecording(_ id: UUID) -> Recording? {
        try? context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.id == id })).first
    }

    // MARK: People named in Settings, Privacy

    /// Everyone named, by name.
    func namedPeopleList() -> [Person] {
        ((try? context.fetch(FetchDescriptor<Person>())) ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Adds a name. Nothing about the person's face or voice is kept: it is a name to give rows in a recording.
    @discardableResult
    func addPerson(named raw: String) -> Person? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let same = namedPeopleList().first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return same }
        let person = Person(name: name, addedAt: now())
        context.insert(person)
        try? context.save()
        record("Added the name \(name) in Settings, Privacy. Cloud models may not read their words until you turn that on.")
        return person
    }

    /// Removes a name. Recordings that used it count that face or voice as not named again, so their lock closes.
    func removePerson(_ person: Person) {
        let name = person.name
        let id = person.id
        context.delete(person)
        try? context.save()
        refreshCardPictures(naming: id)
        record("Removed the name \(name). Recordings where it was given count that person as not named.")
    }

    /// The per-person switch "Cloud models may read their words" (PLAN section 5, item 2), off by default.
    func setCloudConsent(_ allowed: Bool, for person: Person) {
        guard person.mayReadInCloud != allowed else { return }
        person.mayReadInCloud = allowed
        try? context.save()
        record(allowed ? "Cloud models may now read the words of \(person.name), in recordings where everyone heard has agreed and nobody else appears or speaks."
                       : "Cloud models may no longer read the words of \(person.name). Recordings where they speak are only read on this Mac.")
    }

    // MARK: Naming in one recording

    /// Who Is Teaching (the Info tab). Nil clears it.
    func setTeacher(_ person: Person?, for recording: Recording) {
        var names = recording.names
        guard names.teacher != person?.id else { return }
        names.teacher = person?.id
        recording.names = names
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): " + (person.map { "\($0.name) is teaching." } ?? "who is teaching is cleared."))
        try? context.save()
        refreshCardPicture(recording)
    }

    /// Name for This Recording, for a face row (0: the faces seen for under a second). Nil takes the name off.
    func nameFace(_ row: Int, as person: Person?, in recording: Recording) {
        var names = recording.names
        names.faces[row] = person?.id
        recording.names = names
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): a face is " + (person.map { "named \($0.name)" } ?? "not named any more") + " for this recording.")
        try? context.save()
        refreshCardPicture(recording)
    }

    /// Name for This Recording, for a voice. Nil takes the name off.
    func nameVoice(_ voice: Int, as person: Person?, in recording: Recording) {
        var names = recording.names
        names.voices[voice] = person?.id
        recording.names = names
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): a voice is " + (person.map { "named \($0.name)" } ?? "not named any more") + " for this recording.")
        try? context.save()
        refreshCardPicture(recording)
    }

    /// "Track 2 is Gabriel's microphone" for the recording's folder: every recording from it heard on that track
    /// takes the name, unless named otherwise by hand. Nil forgets the track.
    func setMicrophone(track: Int, to person: Person?, for recording: Recording) {
        guard let source = recording.source else { return }
        var microphones = source.microphones
        microphones[track] = person?.id
        source.microphones = microphones
        record("\(source.name): track \(track) is " + (person.map { "\($0.name)'s microphone." } ?? "no one's microphone now."))
        try? context.save()
        // A voice named by its track crosses its link to a face, so the folder's card pictures follow.
        for other in source.recordings where other.voices?.source == .tracks { refreshCardPicture(other) }
    }
}
