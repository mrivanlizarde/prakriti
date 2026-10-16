import AppKit
import SwiftUI

/// The timelines in the inspector's Outputs tab (v2 part M10a, design spec 3.5.1 rows 3 and 4): one row for Final Cut Pro and one
/// for DaVinci Resolve, each with Open in [the app] (only when the app is on this Mac) and Show in Finder, and Make Timelines,
/// which writes them from the video already made. A recording with anyone hidden or left out, or a muted name, gets the refusal
/// in words and nothing is written (until M10b's privacy-safe media).
struct TimelineSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let record = model.timelineRecord(recording)
        let refusal = model.timelineRefusal(recording)
        let writing = model.writingTimelines.contains(recording.id)
        Section {
            if writing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Writing the timelines.").font(AppFont.body)
                }
            } else if let record, model.timelineFolder(recording) != nil {
                if !model.timelineIsCurrent(recording) {
                    RowNote("These were made from an earlier plan than the video in use. Make the timelines again to match it.")
                }
                row(.finalCut, detail: "FCPXML \(FCPXMLVersion.finalCut.rawValue), \(record.summary) Every cut, punch-in, caption and title, ready to finish by hand.",
                    note: nil)
                row(.resolve, detail: "FCPXML \(FCPXMLVersion.resolve.rawValue), the same edit, with its captions beside it as \(record.captionsName).",
                    note: "In DaVinci Resolve, choose File > Import > Timeline and select the file.")
                RowNote("Both use the copy of the recording in Media and the text in Graphics, inside the Timeline folder. Slow push-ins are markers, and each text has an editable copy switched off above it. Read Me.txt says how to open each.")
            } else if refusal == nil {
                Text("Prakriti can write the same edit as the video for Final Cut Pro and DaVinci Resolve: every cut, punch-in, caption and title, the text as clips that look exactly as in the video. It takes a few seconds.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !writing, let refusal {
                RowNote(refusal)
            } else if !writing, let problem = model.timelineProblems[recording.id] {
                Label {
                    Text("Not written on the last try. \(problem)").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 10) {
                Button(record == nil ? "Make Timelines" : "Make Timelines Again") { model.makeTimelines(recording) }
                    .disabled(writing || refusal != nil || !model.canMakeTimelines(recording))
                    .quickHelp("Writes the timelines for Final Cut Pro and DaVinci Resolve from the video already made, beside it in the Timeline folder. Nothing is uploaded.",
                               article: "outputs")
            }
        } header: {
            SectionHeader("Timelines")
        }
    }

    private func row(_ version: FCPXMLVersion, detail: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(version == .finalCut ? "Final Cut Pro timeline" : "DaVinci Resolve timeline").font(AppFont.body)
                    Text(detail)
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note {
                        Text(note)
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } icon: {
                Image(systemName: OutputKind.timelines.symbol)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.accentText)
            }
            if let file = model.timelineFile(recording, version) {
                // Side by side when they fit, else one under the other: "Open in DaVinci Resolve" was cut short beside Show in
                // Finder at the inspector's width (seen in 26-timelines-ready, 15 Oct).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { buttons(version, file: file) }
                    VStack(alignment: .leading, spacing: 8) { buttons(version, file: file) }
                }
                .padding(.leading, 34)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func buttons(_ version: FCPXMLVersion, file: URL) -> some View {
        if AppModel.timelineApp(version) != nil {
            Button("Open in \(version.appName)") { model.openTimeline(recording, in: version) }
                .fixedSize()
        }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file]) }
            .fixedSize()
    }
}
