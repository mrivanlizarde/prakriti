import Foundation
import SwiftData

// Faces in a recording (v2 part M6a): what the face step found, applied to a recording. Check People, which runs the
// face step and the voice step on a recording found before they existed, is in PeopleActions.swift (M6b).
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
}
