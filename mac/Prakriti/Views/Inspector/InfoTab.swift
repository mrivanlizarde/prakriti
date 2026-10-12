import AppKit
import SwiftData
import SwiftUI

/// The inspector's Info tab (design spec 3.5.5, as built in part M3a): its title, what it is and its
/// notes, where the episode starts and ends, when it was recorded and found, its length and size, the
/// original and the output folder. Every change goes through the same paths as v1's recording page, so a
/// change to an approved recording takes the approval back (START_HERE, Mac warning 38) and a trim waits
/// for Make Again (warning 36).
struct InfoTab: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(AppFont.secondary).foregroundStyle(.appSecondary)
                    TextField("Title", text: $recording.title, prompt: Text("Untitled"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(AppFont.body)
                        .onChange(of: recording.title) { model.changedAfterApproval(recording, what: "its title") }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("What this is").font(AppFont.secondary).foregroundStyle(.appSecondary)
                    Picker("What this is", selection: Binding(get: { recording.kind == .test ? .unknown : recording.kind },
                                                             set: { model.setKind($0, for: recording) })) {
                        ForEach(RecordingKind.choices, id: \.self) { kind in
                            Text(kind == .talk ? "Talk, one teacher speaking" : kind.title).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .font(AppFont.body)
                    .disabled(recording.status == .working || recording.status == .skipped)
                    Text("Only a talk with one teacher speaking can be approved until Prakriti can check who is speaking.")
                        .font(AppFont.secondary).foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(AppFont.secondary).foregroundStyle(.appSecondary)
                    TextEditor(text: $recording.notes)
                        .font(AppFont.body)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
                        .onChange(of: recording.notes) { model.changedAfterApproval(recording, what: "its notes") }
                        .accessibilityLabel("Notes")
                }
            }
            if showsEpisodeTimes {
                Section {
                    InspectorTimeField(label: "Episode starts at", placeholder: "0:00", value: recording.trimStart) {
                        model.setTrim(start: $0, end: recording.trimEnd, for: recording)
                    }
                    InspectorTimeField(label: "Episode ends at", placeholder: recording.duration.map(Format.timecode) ?? "the end", value: recording.trimEnd) {
                        model.setTrim(start: recording.trimStart, end: $0, for: recording)
                    }
                    Text(recording.cuts.isEmpty
                         ? "Times are from the start of the original. Cuts are made on the recording's page."
                         : "Times are from the start of the original. \(Format.count(recording.cuts.count, "cut")) on the recording's page.")
                        .font(AppFont.secondary).foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if recording.editsPending {
                        Label {
                            Text("Not in the episode yet. Make it again to hear it, and before approving.")
                                .font(AppFont.body)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle").font(AppFont.body).foregroundStyle(.orange)
                        }
                    }
                } header: {
                    SectionHeader("Episode")
                }
            }
            Section {
                StackedValue(label: "Recorded", value: recording.recordedAt.map { Format.dayAndTime($0) } ?? "Not known from its name")
                if let duration = recording.duration {
                    StackedValue(label: "Length", value: Format.length(duration))
                }
                if recording.sizeBytes > 0 {
                    StackedValue(label: "Size", value: Format.size(recording.sizeBytes))
                }
                StackedValue(label: "Found", value: Format.dayAndTime(recording.foundAt) + ", " + (recording.source.map { "in \($0.name)" } ?? "added by hand"))
                PathRow(label: "Original", path: recording.filePath)
                if let folder = recording.outputFolder {
                    PathRow(label: "Output folder", path: folder)
                }
            } header: {
                SectionHeader("File")
            }
        }
        .formStyle(.grouped)
    }

    /// Where the episode starts and ends can be set once something has been checked or made.
    private var showsEpisodeTimes: Bool {
        switch recording.status {
        case .readyForYourYes, .approved: true
        case .working, .found, .couldntFinish: recording.outputFolder != nil
        case .needsADecision, .skipped: false
        }
    }
}

/// A time Ivan types, applied on Return or when the field loses focus, with the problem in words when it
/// cannot work (the same rules as the recording page's fields).
struct InspectorTimeField: View {
    let label: String
    let placeholder: String
    let value: Double?
    let apply: (Double?) -> String?
    @State private var text = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.secondary).foregroundStyle(.appSecondary)
            TextField(label, text: $text, prompt: Text(placeholder))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(AppFont.numbers)
                .frame(maxWidth: 140, alignment: .leading)
                .focused($focused)
                .onSubmit(commit)
            if let problem {
                Text(problem).font(AppFont.secondary).foregroundStyle(AppColor.problemText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { text = value.map(TimeText.string) ?? "" }
        .onChange(of: value) { _, new in text = new.map(TimeText.string) ?? "" }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            problem = apply(nil)
            return
        }
        guard let seconds = TimeText.seconds(trimmed) else {
            problem = "Write a time like 4:12 or 1:02:30."
            return
        }
        problem = apply(seconds)
        if problem != nil { text = value.map(TimeText.string) ?? "" }
    }
}
