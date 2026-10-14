import AppKit
import SwiftUI

/// The edited video in the inspector's Outputs tab (v2 part M8b): whether the video is ready to upload, its files with Show
/// in Finder, the Ready checklist with the lines that do not pass first, and Make Video for a recording made without it.
/// Make Video is refused in words while the people check has not run or someone is set to Hide Face or Leave Out (until part
/// M8d). Watching the video inside Prakriti is part M8c.
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
            RowNote("Watching it here comes in the next update. It is in the Video folder with its captions and Description.txt.")
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
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
