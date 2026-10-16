import AppKit
import SwiftUI

/// The shorts in the inspector's Outputs tab (v2 part M11a, design spec 3.5.1 row "Shorts"): what the last make cut, one row a
/// short with Play (the Viewer on Shorts, that short) and Show in Finder, each short's checklist in one line, and Make Shorts for a
/// recording made without them. Make Shorts is refused in words only while the people check has not run.
struct ShortsSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let record = model.shortsRecord(recording)
        let files = model.shortFiles(recording)
        let refusal = model.videoRefusal(recording)
        Section {
            if let record, !files.isEmpty {
                Text(record.summary)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let behind = model.shortsBehind(recording) { RowNote(behind) }
                ForEach(files, id: \.short.number) { entry in
                    row(entry.short, url: entry.url, index: files.firstIndex { $0.short.number == entry.short.number } ?? 0)
                }
                if let warning = record.warning { RowNote(warning) }
            } else if let problem = model.shortsProblems[recording.id] {
                Label {
                    Text("Not made on the last try. \(problem)").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("Prakriti can cut short vertical clips of the strongest moments from the edit plan: each a complete moment of 30 to 60 seconds, 1080 by 1920, with the words on screen. How many and how long are in the Direction tab.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let refusal, model.shortsProblems[recording.id] == nil {
                RowNote(refusal.replacingOccurrences(of: "no video is made", with: "no shorts are made"))
            }
            HStack(spacing: 10) {
                Button(record == nil ? "Make Shorts" : "Make Shorts Again") { model.makeShorts(recording) }
                    .disabled(!model.canMakeShorts(recording))
                    .quickHelp("Plans the edit and cuts the shorts, through the line like any make. Nothing is uploaded.", article: "outputs")
            }
        } header: {
            SectionHeader("Shorts")
        }
    }

    private func row(_ short: Shorts.Short, url: URL, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Short \(short.number), \(Format.timecode(short.duration))").font(AppFont.body)
                    Text("From \(Format.timecode(short.start)) of the recording: \(short.summary). Checklist: \(short.summaryLine.lowercased()).")
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: short.failed == 0 ? "rectangle.portrait" : "exclamationmark.triangle").font(AppFont.body)
            }
            HStack(spacing: 10) {
                Button("Play") { model.showShort(recording, index: index) }
                    .quickHelp("Opens the recording in the viewer on Shorts, this short.", article: "reviewing-and-approving")
                Button("Show in Finder") { model.showShortInFinder(url) }
            }
        }
        .padding(.vertical, 4)
    }
}

/// The shorts in the Checks tab (v2 part M11a): where their picture came from (the vertical recording, with its offset, or a crop,
/// with the capture warning of a 1080p crop), the vertical recording's own face step, and every short's checklist line by line.
struct ShortsChecksSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        if let record = model.shortsRecord(recording) {
            Section {
                if let warning = record.warning {
                    Label {
                        Text(warning).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.circle").font(AppFont.body).foregroundStyle(Color.orange)
                    }
                    .accessibilityElement(children: .combine)
                }
                StackedValue(label: "Picture", value: "From " + record.source.line + ".")
                if let twin = record.twin, record.source == .vertical {
                    StackedValue(label: "Vertical recording", value: twin.line.prefix(1).uppercased() + twin.line.dropFirst() + ".")
                }
                if let note = record.twinNote { RowNote(note) }
                if let faces = record.twinFaces { RowNote(faces.prefix(1).uppercased() + faces.dropFirst() + ".") }
                ForEach(record.shorts, id: \.number) { short in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Short \(short.number)").font(AppFont.headline)
                        ForEach(Array(short.lines.enumerated()), id: \.offset) { _, line in
                            ShortsCheckLine(line: line)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                SectionHeader("Shorts")
            }
        }
    }
}

/// One line of a short's checklist: PASS or FAIL in words, never color alone.
struct ShortsCheckLine: View {
    let line: ChecklistLine

    var body: some View {
        let text = "\(line.status.rawValue)  \(line.item): \(line.detail)"
        if line.status == .pass {
            Text(text).font(AppFont.secondary).foregroundStyle(.appSecondary).fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text).font(AppFont.secondary).foregroundStyle(AppColor.problemText).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The Direction tab's Shorts (design spec 3.5.3 item 5): how many, 0 to 5, and how long, 30, 45 or 60 seconds. Used at the next
/// make; nothing is made until Ivan asks.
struct ShortsDirectionSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let shorts = recording.direction.shorts
        Section {
            Stepper(value: Binding(get: { shorts.count }, set: { model.setShorts(count: $0, for: recording) }), in: ShortsSettings.counts) {
                Text(shorts.count == 0 ? "Make no shorts" : "Make \(Format.count(shorts.count, "short"))").font(AppFont.body)
            }
            Picker("Length", selection: Binding(get: { shorts.length }, set: { model.setShorts(length: $0, for: recording) })) {
                ForEach(ShortsSettings.lengths, id: \.self) { Text("Up to \($0) seconds").tag($0) }
            }
            .font(AppFont.body)
            RowNote("Each short is a whole moment from the strongest parts of the talk, cut from the edit plan. They are made with the Shorts output; Make Again cuts them with these numbers.")
        } header: {
            SectionHeader("Shorts")
        }
    }
}
