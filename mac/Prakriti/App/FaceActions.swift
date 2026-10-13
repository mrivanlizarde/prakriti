import Foundation
import SwiftData

// Faces in a recording (v2 part M6a): what the face step found, applied to a recording, and Look for Faces for a
// recording found before the step existed. New recordings are looked at in their make; an older one waits for
// Ivan's click, because an upgrade never starts work by itself (docs/v2/PLAN.md rule 2.1.7). It reads the
// original only, two frames a second (about 19 s for a 15-minute talk on this Mac), and makes nothing else.
extension AppModel {
    /// Keeps what was found on the recording, writes it to Activity, and posts the one fixed notice the first
    /// time other people are seen in it ("Other people appear in this recording.", Mac warning 23: no name, no
    /// title). Nothing else changes: this part decides nothing about who appears (M6c does).
    func applyFaces(_ faces: FacesFound, to recording: Recording, run: Run? = nil) {
        let hadOthers = recording.faces?.otherPeopleAppear ?? false
        recording.facesJSON = faces.json()
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): faces. " + faces.stepLine,
               level: faces.otherPeopleAppear ? .attention : .info, run: run)
        if faces.otherPeopleAppear && !hadOthers {
            notifier.post(.otherPeople, NoticeFacts(recording))
        }
    }

    /// Look for Faces: the face step on its own, for a recording that has none yet or to look again.
    func lookForFaces(_ recording: Recording) {
        guard !faceChecking.contains(recording.id) else { return }
        let id = recording.id
        let file = URL(fileURLWithPath: recording.filePath)
        faceProblems[id] = nil
        guard FileManager.default.fileExists(atPath: file.path) else {
            faceProblems[id] = "The original is not where it was found, so it cannot be looked at."
            return
        }
        // Reading an iCloud placeholder would start a download of the whole file; the watcher does that one file
        // at a time, so Look for Faces leaves it alone.
        guard !Readiness.isDataless(file) else {
            faceProblems[id] = "The original is in iCloud and not on this Mac yet, so it cannot be looked at."
            return
        }
        faceChecking.insert(id)
        let folders = peopleFolders
        let started = now()
        Task { @MainActor in
            defer { faceChecking.remove(id) }
            do {
                let outcome = try await Task.detached { try await FaceStep.run(file: file, recordingID: id, folders: folders, now: started) }.value
                guard let current = try? context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.id == id })).first else { return }
                applyFaces(outcome.found, to: current)
                try? context.save()
            } catch {
                let detail = (error as? FaceScan.Failure)?.reason ?? error.localizedDescription
                faceProblems[id] = "Faces could not be looked for. \(detail)"
                record("Faces could not be looked for in \(recording.fileName). \(detail)", level: .attention)
            }
        }
    }
}
