import AppKit
import SwiftUI

/// The edited video in the inspector's Outputs tab (v2 part M8b): whether the video is ready to upload, its files with Show
/// in Finder, the Ready checklist with the lines that do not pass first, and Make Video for a recording made without it.
/// Make Video is refused in words only while the people check has not run; since part M8d a video hides the face of everyone
/// set to Hide Face or Leave Out and cuts the speech of everyone left out, and the verdict says so. Watching it is part M8c.
struct VideoSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let video = recording.video
        let refusal = model.videoRefusal(recording)
        Section {
            if let video, let file = model.videoFile(recording) {
                verdict(video, file: file)
                checklist(video, folder: file.deletingLastPathComponent())
            } else if let problem = model.videoProblems[recording.id] ?? recording.videoProblem {
                Label {
                    Text(video == nil && recording.videoProblem != nil ? "Not made on the last try. \(problem)" : problem)
                        .font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("Prakriti can make the edited video from the edit plan: an MP4 with the pauses, filler words and restarts taken out, its captions, a description to paste and a checklist against YouTube's rules. A 15-minute talk takes a few minutes.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let refusal, model.videoProblems[recording.id] == nil {
                RowNote(refusal)
            }
            HStack(spacing: 10) {
                Button(video == nil ? "Make Video" : "Make Video Again") { model.makeVideo(recording) }
                    .disabled(!model.canMakeVideo(recording))
                    .quickHelp("Plans the edit and makes the video with its captions, description and checklist, through the line like any make. Nothing is uploaded.",
                               article: "outputs")
            }
        } header: {
            SectionHeader("Edited video")
        }
    }

    private func verdict(_ video: VideoRecord, file: URL) -> some View {
        // The words take the inspector's whole width, the button under them: beside them, the text was squeezed into a
        // column a third as wide (seen in 22-video-ready, 13 Oct).
        VStack(alignment: .leading, spacing: 6) {
            Text(video.failed + video.missing == 0 ? "Ready to upload" : "Not ready to upload yet").font(AppFont.headline)
            Text("\(video.fileName), \(Format.timecode(video.duration)), made \(Format.dayAndTime(video.madeAt)). "
                 + (video.failed + video.missing == 0 ? "Every line of the checklist passes. Nothing is uploaded until you do it."
                    : "\(video.failed) FAIL, \(video.missing) MISSING, \(video.passed) PASS."))
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
            if let people = Self.peopleNote(video) { RowNote(people) }
            RowNote("Watch it here with Video in the toolbar: the picture is drawn the same way as the file. It is in the Video folder with its "
                    + "captions and Description.txt.")
            HStack(spacing: 10) {
                Button("Watch Video") { model.showVideo(recording) }
                    .quickHelp("Opens the recording in the viewer on Video, the edited video as it will be posted.", article: "reviewing-and-approving")
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file]) }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    /// Who the video hides and leaves out, in one line, or nil when everyone is in it as recorded (v2 part M8d).
    static func peopleNote(_ video: VideoRecord) -> String? {
        let faces = video.hiddenFaces ?? 0, voices = video.leftOutVoices ?? 0
        guard faces + voices > 0 else { return nil }
        var parts: [String] = []
        if faces > 0 { parts.append(faces == 1 ? "hides 1 face" : "hides \(faces) faces") }
        if voices > 0 { parts.append(voices == 1 ? "leaves out 1 voice" : "leaves out \(voices) voices") }
        let checked = [video.pictureCheck.map { $0.passed ? "every face in it was found again and is someone you included" : nil },
                       video.soundCheck.map { $0.passed ? "every voice in it was heard again and is someone you included" : nil }]
            .compactMap { $0 ?? nil }
        return "It " + parts.joined(separator: " and ") + ", as you chose in People" + (checked.isEmpty ? "." : "; " + checked.joined(separator: ", and ") + ".")
    }

    private func checklist(_ video: VideoRecord, folder: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ready checklist").font(AppFont.headline)
                Spacer(minLength: 12)
                Button("Open Checklist") { NSWorkspace.shared.open(folder.appending(path: ReadyChecklist.name)) }
            }
            let ordered = video.checklist.filter { $0.status != .pass } + video.checklist.filter { $0.status == .pass }
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, line in
                ChecklistRow(line: line)
            }
        }
        .padding(.vertical, 4)
    }
}
