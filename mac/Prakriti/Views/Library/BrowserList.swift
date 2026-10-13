import SwiftData
import SwiftUI

/// The list (Command-2, design spec 3.2): one row per recording at 17 pt, the tile at 64 by 36 pt, the
/// title truncated in the middle (names like 2026-09-06 18-06-33 share their start), the day recorded,
/// the length, the status in symbol and words, and the folder. Click a column's heading to sort by it; the
/// Sort menu sorts the same way. Double-click or Return opens a recording; Control-click shows its menu.
/// The list is one sorted run of rows; the grid keeps the sections.
struct BrowserList: View {
    let recordings: [Recording]
    let matches: [UUID: LibrarySearch.Match]
    @Environment(AppModel.self) private var model
    @State private var order: [KeyPathComparator<Recording>] = [KeyPathComparator(\Recording.sessionDate, order: .reverse)]

    var body: some View {
        @Bindable var model = model
        let rows = recordings.sorted(using: order)
        Table(rows, selection: $model.selectedRecordings, sortOrder: $order) {
            TableColumn("") { recording in
                RecordingPicture(recording: recording, compact: true)
                    .frame(width: 64, height: 36)
            }
            .width(72)
            TableColumn(Self.heading("Title"), value: \Recording.cardTitle) { recording in
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.cardTitle)
                        .font(AppFont.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let said = matches[recording.id]?.said.first {
                        Text("\(Format.timecode(said.time))  \(said.sentence)")
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 150, ideal: 190)
            TableColumn(Self.heading("Recorded"), value: \Recording.sessionDate) { recording in
                Text(Format.fullDay(recording.sessionDate))
                    .font(AppFont.body)
                    .monospacedDigit()
            }
            .width(min: 140, ideal: 150)
            TableColumn(Self.heading("Length"), value: \Recording.lengthForSorting) { recording in
                Text(recording.duration.map(Format.timecode) ?? "")
                    .font(AppFont.body)
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 80)
            // Who was seen (v2 part M6a, design spec 3.2): the people line, empty until faces were looked for.
            TableColumn(Self.heading("People")) { recording in
                Text(recording.faces?.shortLine ?? "")
                    .font(AppFont.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 130, ideal: 150)
            TableColumn(Self.heading("Status")) { recording in
                if let progress = model.runner.progress(for: recording) {
                    // While it is made (v2 part M4a): a small bar, the percent and the time left.
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress.overall)
                            .accessibilityLabel("Progress")
                            .accessibilityValue(ProgressWords.spoken(progress))
                        Text(ProgressWords.line(progress))
                            .font(AppFont.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                } else {
                    Label {
                        Text(recording.status.title)
                    } icon: {
                        Image(systemName: recording.status.symbol)
                            .foregroundStyle(recording.status.tint)
                    }
                    .font(AppFont.body)
                    .lineLimit(1)
                }
            }
            .width(min: 200, ideal: 230)
            TableColumn(Self.heading("Source")) { recording in
                Text(recording.sourceName)
                    .font(AppFont.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 140, ideal: 150)
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let id = ids.first, let recording = model.recording(id: id) {
                RecordingMenu(recording: recording)
            }
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first, let recording = model.recording(id: id) {
                model.open(recording)
            }
        }
        .onAppear { order = Self.comparators(for: model.browserSort) }
        .onChange(of: model.browserSort) { _, sort in order = Self.comparators(for: sort) }
    }

    /// A column's heading at 15 pt semibold (the table's own headings draw at about 12 pt).
    static func heading(_ title: String) -> Text {
        Text(title).font(AppFont.secondaryEmphasis)
    }

    /// The Sort menu's choice as the table's sort: dates and lengths newest or longest first, titles A to Z.
    static func comparators(for sort: BrowserSort) -> [KeyPathComparator<Recording>] {
        switch sort {
        case .dateRecorded: [KeyPathComparator(\Recording.sessionDate, order: .reverse)]
        case .dateFound: [KeyPathComparator(\Recording.foundAt, order: .reverse)]
        case .length: [KeyPathComparator(\Recording.lengthForSorting, order: .reverse)]
        case .title: [KeyPathComparator(\Recording.cardTitle, comparator: .localizedStandard)]
        }
    }
}
