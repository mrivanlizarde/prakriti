import AppKit
import SwiftUI

/// The upload checklist (v2 part M11b, design spec 3.11), in the inspector's Outputs once a video or shorts are made: one platform
/// at a time (YouTube, Shorts, Reels, TikTok), each field its upload form asks for in that form's order, with **Copy** for words and
/// **Show in Finder** for a file, and PASS, MISSING or FAIL in words. Reels' and TikTok's rules are third-party figures, and say so.
/// The point: the only step left is Ivan pressing Upload. Prakriti never uploads.
struct UploadChecklistSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model
    @State private var platform: UploadPlatform

    init(recording: Recording, platform: UploadPlatform = .youtube) {
        self.recording = recording
        _platform = State(initialValue: platform)
    }

    var body: some View {
        let facts = model.uploadFacts(recording)
        if facts.videoFile != nil || !facts.shorts.isEmpty {
            Section {
                Picker("Upload to", selection: $platform) {
                    ForEach(UploadPlatform.allCases) { Text($0.short).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .font(AppFont.body)
                let fields = ReadyChecklist.upload(platform, facts: facts)
                let open = fields.filter { $0.status == .missing || $0.status == .fail }.count
                Text(open == 0 ? "Everything \(platform.title) asks for is ready. Nothing has been uploaded."
                     : "\(Format.count(open, "field")) to finish before uploading to \(platform.title). Nothing has been uploaded.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(fields) { field in
                    UploadFieldRow(field: field)
                }
                RowNote(platform.source)
            } header: {
                SectionHeader("Upload Checklist")
            }
        }
    }
}

/// One field: its name and status in words, the value (three lines at most), and Copy or Show in Finder.
struct UploadFieldRow: View {
    let field: UploadField

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if field.status == .fail {
                        Text(field.status?.rawValue ?? "").foregroundStyle(AppColor.problemText)
                    } else {
                        Text(field.status?.rawValue ?? "YOURS").foregroundStyle(.appSecondary)
                    }
                }
                .font(AppFont.secondaryEmphasis)
                .frame(minWidth: 72, alignment: .leading)
                Text(field.label + (field.thirdParty ? " (third-party rule)" : ""))
                    .font(AppFont.body)
            }
            switch field.value {
            case .text(let text):
                Text(text)
                    .font(AppFont.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            case .file(let url):
                Text(url.lastPathComponent).font(AppFont.secondary).lineLimit(1).truncationMode(.middle)
            case .answer:
                EmptyView()
            }
            Text(field.detail)
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
            switch field.value {
            case .text(let text):
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            case .file(let url):
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            case .answer:
                EmptyView()
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
    }
}
