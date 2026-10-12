import AppKit
import SwiftData
import SwiftUI

/// The Activity window's three views (design spec 3.6.3).
enum ActivityTab: String, CaseIterable, Identifiable, Sendable {
    case now, finished, log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: "Now"
        case .finished: "Finished"
        case .log: "Log"
        }
    }
}

/// Window, Activity (Command-9; the toolbar's Activity button; the menu bar): what is being made now and
/// what waits, what finished, and the log (v2 part M4a, design spec 3.6.3; Final Cut Pro's Background Tasks
/// with Compressor's Active and Completed views, in Prakriti's words). The Log replaces v1's Activity screen
/// with the same sentences and the heartbeat line.
struct ActivityWindow: View {
    static let id = "activity"
    static let size = CGSize(width: 720, height: 640)
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ActivityHeader()
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            Picker("Show", selection: $model.activityTab) {
                ForEach(ActivityTab.allCases) { tab in Text(tab.title).tag(tab) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .padding(.bottom, 12)
            .accessibilityLabel("Show")
            Divider()
            switch model.activityTab {
            case .now: ActivityNow()
            case .finished: ActivityFinished()
            case .log: ActivityLog()
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// One sentence of what is happening, and Pause All or Resume All on the right.
struct ActivityHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(sentence)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            PauseButton()
        }
    }

    /// "Making 1 recording. 2 waiting. About 18 min left."
    private var sentence: String {
        let runner = model.runner
        let waiting = runner.waitingIDs.count
        guard runner.currentJob != nil else {
            if model.settings.isPaused { return "Pause All is on. Nothing new starts until you resume." + (waiting > 0 ? " \(waiting) waiting." : "") }
            return waiting > 0 ? "Nothing is being made. \(waiting) waiting." : "Nothing is being made."
        }
        var parts = ["Making 1 recording."]
        if waiting > 0 { parts.append("\(waiting) waiting.") }
        parts.append(TimeLeft.text(runner.queueTimeLeft()) + ".")
        return parts.joined(separator: " ")
    }
}

// MARK: Now

/// The make running now, then the recordings waiting, in the order they will be made.
struct ActivityNow: View {
    @Environment(AppModel.self) private var model
    @Query private var recordings: [Recording]
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        let runner = model.runner
        let working = runner.currentJob.flatMap { job in recordings.first { $0.id == job.recordingID } }
        let waiting = runner.waitingIDs.compactMap { id in recordings.first { $0.id == id } }
        ScrollView {
            if working == nil && waiting.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath", title: "Nothing is being made", message: emptyMessage)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if let working, let progress = runner.progress(for: working) {
                        Text("Working").font(AppFont.sectionTitle).accessibilityAddTraits(.isHeader)
                        WorkingRow(recording: working, snapshot: progress)
                    }
                    if !waiting.isEmpty {
                        if working != nil { Divider().padding(.vertical, 4) }
                        Text("Waiting").font(AppFont.sectionTitle).accessibilityAddTraits(.isHeader)
                        ForEach(Array(waiting.enumerated()), id: \.element.id) { index, recording in
                            WaitingRow(recording: recording, place: index + 1)
                            if index < waiting.count - 1 { Divider() }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// "Prakriti last checked 2 folders at 9:41 pm." (The design spec's "and found nothing new" is not always
    /// true: the last look can be the one that found the recording just made.)
    private var emptyMessage: String {
        guard let checked = model.watcher.lastCheck else { return "New recordings start on their own." }
        let folders = Format.count(sources.count, "folder")
        return "Prakriti last checked \(folders) at \(Format.clock(checked)). New recordings start on their own."
    }
}

/// The recording being made: its tile, title, stage, bar, percent and time left, the latest line, Pause and
/// Stop, and its stages (done with how long each took, the running one with its time so far, those to come
/// with their usual time on this Mac).
struct WorkingRow: View {
    let recording: Recording
    let snapshot: ProgressSnapshot
    @Environment(AppModel.self) private var model
    @State private var showsStages = true

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            NeutralTile(recording: recording, compact: true)
                .frame(width: 64, height: 36)
            VStack(alignment: .leading, spacing: 7) {
                Text(recording.cardTitle)
                    .font(AppFont.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text((snapshot.isPaused ? "Paused while " + snapshot.stageName.lowercasedFirst : snapshot.stageName)
                     + ". Step \(snapshot.stepNumber) of \(snapshot.stepCount).")
                    .font(AppFont.body)
                ProgressView(value: snapshot.overall)
                    .accessibilityLabel("Progress")
                    .accessibilityValue(ProgressWords.spoken(snapshot))
                Text(ProgressWords.line(snapshot))
                    .font(AppFont.numbers)
                if let waiting = snapshot.waitingOn {
                    Label {
                        Text(waiting).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "hourglass").font(AppFont.body).foregroundStyle(.orange)
                    }
                }
                if let line = snapshot.logLine {
                    Text(line)
                        .font(AppFont.path)
                        .foregroundStyle(.appSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                ProgressButtons(recording: recording, snapshot: snapshot)
                DisclosureGroup(isExpanded: $showsStages) {
                    StageList(stages: snapshot.stages)
                        .padding(.top, 6)
                } label: {
                    Text("Steps").font(AppFont.body)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Show") { model.openRecording(id: recording.id) }
            Button("Show in Finder") { showInFinder(recording) }
        }
    }

    private func showInFinder(_ recording: Recording) {
        model.showOriginalInFinder(recording)
    }
}

/// Each stage of the running make, in order.
struct StageList: View {
    let stages: [StageLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(stages) { line in
                StageRow(line: line, time: timeText(line))
            }
        }
    }

    /// "Took 22 s", "0:12 so far", "usually 4 min".
    private func timeText(_ line: StageLine) -> String {
        switch line.state {
        case .done: line.seconds.map { "took " + StageList.seconds($0) } ?? "done"
        case .running: line.seconds.map { Format.timecode($0) + " so far" } ?? ""
        case .waiting: line.usual.map { "usually " + TimeLeft.usual($0) } ?? ""
        case .failed: "stopped"
        case .skipped: "skipped"
        }
    }

    /// "0.6 s", "22 s", "1 min 12 s".
    static func seconds(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f s", value) : Format.length(value)
    }
}

/// One stage: its state's symbol, its name, and its time.
struct StageRow: View {
    let line: StageLine
    let time: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: line.state.symbol)
                .font(AppFont.secondary)
                .foregroundStyle(symbolColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(line.step.listTitle(running: line.state == .running))
                .font(AppFont.secondary)
                .foregroundStyle(nameColor)
            Spacer(minLength: 12)
            Text(time)
                .font(AppFont.numbers)
                .foregroundStyle(timeColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var symbolColor: Color {
        switch line.state {
        case .failed: AppColor.problemText
        case .done, .running: AppColor.accentText
        default: AppColor.secondaryText
        }
    }

    private var nameColor: Color { line.state == .waiting || line.state == .skipped ? AppColor.secondaryText : Color.primary }
    private var timeColor: Color { line.state == .running ? Color.primary : AppColor.secondaryText }
}

/// A recording waiting its turn: its place in line, how long it usually takes, Pause and Stop, and Make Next
/// in its context menu.
struct WaitingRow: View {
    let recording: Recording
    let place: Int
    @Environment(AppModel.self) private var model

    var body: some View {
        let runner = model.runner
        HStack(alignment: .top, spacing: 14) {
            NeutralTile(recording: recording, compact: true)
                .frame(width: 64, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.cardTitle)
                    .font(AppFont.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(line)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressButtons(recording: recording)
                    if place > 1 {
                        Button("Make Next") { runner.makeNext(recording) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Make Next") { runner.makeNext(recording) }
                .disabled(place == 1)
            Button("Show") { model.openRecording(id: recording.id) }
        }
    }

    /// "Next in line. Usually 4 min." / "Paused in line, 2nd. Usually 4 min."
    private var line: String {
        let runner = model.runner
        let position = place == 1 ? "Next in line" : "Number \(place) in line"
        let held = runner.isHeld(recording) ? "Paused, keeps its place. " : ""
        let usual = runner.usual(for: recording).map { " Usually " + TimeLeft.usual($0) + "." } ?? ""
        return held + position + "." + usual
    }
}

// MARK: Finished

/// Every make that ended, newest first, grouped by day, with its result, Show and Show in Finder.
struct ActivityFinished: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Run.startedAt, order: .reverse) private var runs: [Run]

    var body: some View {
        let finished = runs.filter { $0.recording != nil && $0.outcome != .running && $0.outcome != .nothingNew }
        let days = Dictionary(grouping: finished) { Calendar.current.startOfDay(for: $0.endedAt ?? $0.startedAt) }
            .sorted { $0.key > $1.key }
        if finished.isEmpty {
            ScrollView {
                EmptyState(symbol: "checkmark.circle", title: "Nothing has finished yet",
                           message: "Each recording Prakriti makes is listed here once it ends, with what came of it.")
            }
        } else {
            List {
                ForEach(days, id: \.key) { day, dayRuns in
                    Section {
                        ForEach(dayRuns) { run in
                            if let recording = run.recording { FinishedRow(run: run, recording: recording) }
                        }
                    } header: {
                        SectionHeader(Format.dayLabel(day))
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct FinishedRow: View {
    let run: Run
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            NeutralTile(recording: recording, compact: true)
                .frame(width: 64, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.cardTitle)
                    .font(AppFont.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Label {
                    Text(result)
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: symbol)
                        .font(AppFont.body)
                        .foregroundStyle(tint)
                }
                Text(when)
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                HStack(spacing: 10) {
                    Button("Show") { model.openRecording(id: recording.id) }
                    Button("Show in Finder") {
                        if recording.outputFolder != nil { model.showOutputsInFinder(recording) } else { model.showOriginalInFinder(recording) }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    /// The result in the design spec's words: Waiting for your yes, Couldn't finish, Skipped.
    private var result: String {
        switch run.outcome {
        case .ready: "Made. " + (recording.status == .readyForYourYes ? "Waiting for your yes." : recording.status.title + ".")
        case .couldntFinish: "Couldn't finish. " + (run.summary.isEmpty ? "" : run.summary)
        case .needsADecision: "Needs a decision. " + run.summary
        case .skippedTest: "Skipped: under 60 seconds, filed as a test."
        case .stopped: run.summary.isEmpty ? "Stopped before it finished." : run.summary
        case .checked: "Checked. Waiting for your choice."
        case .running, .nothingNew: run.summary
        }
    }

    private var symbol: String {
        switch run.outcome {
        case .ready: "checkmark.circle"
        case .couldntFinish: "exclamationmark.triangle"
        case .needsADecision: "questionmark.circle"
        case .skippedTest: "minus.circle"
        case .stopped: "stop.circle"
        default: "circle"
        }
    }

    private var tint: Color {
        switch run.outcome {
        case .ready: .green
        case .couldntFinish: .red
        case .needsADecision: .orange
        default: .secondary
        }
    }

    /// "Ended 9:41 pm, after 1 min 12 s. Make again."
    private var when: String {
        let end = run.endedAt ?? run.startedAt
        return "Ended \(Format.clock(end))" + (run.seconds.map { ", after " + Format.length($0) } ?? "") + ". " + run.trigger.title + "."
    }
}

// MARK: Log

/// v1's Activity: every look and every step, newest first, grouped by day, with a search field. The same
/// lines are kept in a file each day.
struct ActivityLog: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \LogEntry.at, order: .reverse) private var entries: [LogEntry]
    @State private var search = ""

    var body: some View {
        let query = search.trimmingCharacters(in: .whitespaces)
        let shown = query.isEmpty ? entries : entries.filter { $0.message.localizedCaseInsensitiveContains(query) }
        let days = Dictionary(grouping: shown) { Calendar.current.startOfDay(for: $0.at) }
            .sorted { $0.key > $1.key }
        VStack(spacing: 0) {
            TextField("Search the log", text: $search)
                .textFieldStyle(.roundedBorder)
                .font(AppFont.body)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            if entries.isEmpty {
                ScrollView {
                    EmptyState(symbol: "clock.arrow.circlepath", title: "Nothing yet",
                               message: "Every check Prakriti makes is listed here, including the ones that find nothing new.")
                }
            } else if shown.isEmpty {
                ScrollView {
                    EmptyState(symbol: "magnifyingglass", title: "No lines match", message: "No line of the log says \u{201C}\(query)\u{201D}.")
                }
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
    }
}

struct ActivityRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(Format.clock(entry.at))
                .font(AppFont.numbers)
                .foregroundStyle(.appSecondary)
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

/// The toolbar's Activity button (design spec 3.3): while anything is made, a ring and the whole line's
/// percent; otherwise the Activity symbol alone. It opens the Activity window, as Final Cut Pro's Background
/// Tasks button does.
struct ActivityButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let fraction = model.runner.queueFraction()
        Button { model.showActivity() } label: {
            if let fraction {
                // A Label with its title shown, as Pause All is, and the ring as a picture (`ProgressRing.image`):
                // measured 12 Oct, the ring drawn as shapes here made the next Command-Option-I go unheard.
                Label {
                    Text("\(Int((fraction * 100).rounded(.down)))%")
                        .monospacedDigit()
                } icon: {
                    Image(nsImage: ProgressRing.image(fraction))
                }
                .labelStyle(.titleAndIcon)
            } else {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }
        }
        .accessibilityLabel(fraction.map { "Activity, \(Int(($0 * 100).rounded(.down))) percent of the line made" } ?? "Activity")
    }
}
