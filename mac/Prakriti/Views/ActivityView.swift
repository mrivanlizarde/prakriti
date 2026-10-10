import SwiftData
import SwiftUI

/// Everything Prakriti did, newest first, including the checks that found nothing new: a quiet
/// day and a stopped engine must look different.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \LogEntry.at, order: .reverse) private var entries: [LogEntry]

    var body: some View {
        let days = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.at) }
            .sorted { $0.key > $1.key }
        Group {
            if entries.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath", title: "Nothing yet",
                           message: "Every check Prakriti makes is listed here, including the ones that find nothing new.")
            } else {
                List {
                    PageIntro(text: "Every check and every step, newest first. The same lines are kept in a file at \(model.paths.display(model.paths.logs.path)).")
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                    ForEach(days, id: \.key) { day, dayEntries in
                        Section {
                            ForEach(dayEntries) { entry in
                                ActivityRow(entry: entry)
                            }
                        } header: {
                            SectionHeader(Format.dayLabel(day))
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Activity")
    }
}

struct ActivityRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(Format.clock(entry.at))
                .font(AppFont.numbers)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)
            Image(systemName: entry.level.symbol)
                .font(AppFont.secondary)
                .foregroundStyle(entry.level.tint)
                .accessibilityHidden(true)
            Text(entry.message)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
