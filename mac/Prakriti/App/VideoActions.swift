import Foundation

// The edited video in the app (v2 part M8b): Make Video on a recording already made, and what the inspector reads. The video
// is made by a make (Make Again with the Edited video switched on for that recording), so it goes through the line, the
// progress, Pause and Stop like any make, and nothing about it is made outside the pipeline's staging and `OutputGate`.
// Nothing starts by itself: the Edited video is off for every folder until Ivan turns it on (PLAN rule 2.1.7), and a
// recording made before this part gets a Make Video button instead.
extension AppModel {
    /// The gate's people facts for a recording as it stands now: its last people check and Ivan's names and choices.
    func videoPeople(_ recording: Recording) -> OutputGate.People {
        OutputGate.People(faces: recording.faces, voices: recording.voices, names: recording.resolvedNameTable, choices: recording.choices)
    }

    /// Why Make Video would not make a video of this recording in this part, or nil.
    func videoRefusal(_ recording: Recording) -> String? {
        OutputGate.refusal(videoPeople(recording))
    }

    /// Make Video can be asked for: the transcript is made (the plan is made from it) and nothing is being made for it.
    func canMakeVideo(_ recording: Recording) -> Bool {
        recording.outputFolder != nil && recording.madeFiles.contains(TranscriptFiles.asHeard)
            && !runner.isCurrent(recording) && !runner.isWaiting(recording) && recording.status != .working
    }

    /// Make Video: refused in words when the people check has not run or someone is not Included (until part M8d);
    /// otherwise the Edited video is switched on for this recording and it is made again.
    func makeVideo(_ recording: Recording) {
        guard canMakeVideo(recording) else { return }
        if let refusal = videoRefusal(recording) {
            videoProblems[recording.id] = refusal
            record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): no video made. \(refusal)", level: .attention)
            return
        }
        videoProblems[recording.id] = nil
        if !OutputResolver.isOn(.editedVideo, recording: recording, source: nil, defaults: defaultSettings()) {
            setOutput(.editedVideo, on: true, for: recording)
        }
        makeOutputs(recording)
    }

    /// The made video's folder and file, when they are there.
    func videoFile(_ recording: Recording) -> URL? {
        guard let video = recording.video, let folder = recording.outputFolder else { return nil }
        let url = URL(fileURLWithPath: folder, isDirectory: true).appending(path: VideoStep.folderName).appending(path: video.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
