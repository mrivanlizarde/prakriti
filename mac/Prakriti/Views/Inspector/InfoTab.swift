import AppKit
import SwiftData
import SwiftUI

/// The inspector's Info tab (design spec 3.5.5, as built in parts M3a and M3b): its title, what it is and
/// its notes, where the episode starts and ends and the cuts (each with Restore, and a cut typed as two
/// times), when it was recorded and found, its length and size, the original and the output folder. Every
/// change goes through v1's own paths, so a change to an approved recording takes the approval back
/// (START_HERE, Mac warning 38) and the trim and cuts wait for Make Again (warning 36).
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
                WhoIsTeaching(recording: recording)
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
                    InspectorTimeField(label: "Episode starts at", placeholder: "0:00", value: recording.trimStart, playerTime: playerTime) {
                        model.setTrim(start: $0, end: recording.trimEnd, for: recording)
                    }
                    InspectorTimeField(label: "Episode ends at", placeholder: recording.duration.map(Format.timecode) ?? "the end", value: recording.trimEnd,
                                       playerTime: playerTime) {
                        model.setTrim(start: recording.trimStart, end: $0, for: recording)
                    }
                    Text("Times are from the start of the original, as the transcript shows them.")
                        .font(AppFont.secondary).foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(recording.cuts, id: \.self) { cut in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cut \(TimeText.string(cut.start)) to \(TimeText.string(cut.end))").font(AppFont.body)
                                Text(Format.length(cut.end - cut.start) + " taken out").font(AppFont.secondary).foregroundStyle(.appSecondary)
                            }
                            Spacer(minLength: 8)
                            Button("Restore") { model.removeCut(cut, from: recording) }
                                .disabled(!model.canEditEpisode(recording))
                        }
                    }
                    CutEntry(recording: recording)
                    if !recording.edits.isEmpty {
                        Button("Clear Trim and Cuts") { model.clearEdits(recording) }
                            .disabled(!model.canEditEpisode(recording))
                    }
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

    /// The moment playing in the Viewer, on the original's clock, while this recording is open there.
    private var playerTime: (() -> Double?)? {
        guard model.viewer.recordingID == recording.id, !model.path.isEmpty else { return nil }
        return { model.viewer.hasPosition ? model.viewer.currentOriginal : nil }
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

/// Cut a section by typing its two times (v1's Cut from and Cut to, moved here with the page's retirement,
/// v2 part M3b). Selecting words in the Viewer's transcript does the same with the mouse.
struct CutEntry: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model
    @State private var from = ""
    @State private var to = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cut a section, from and to").font(AppFont.secondary).foregroundStyle(.appSecondary)
            HStack(spacing: 8) {
                TextField("Cut from", text: $from, prompt: Text("4:12"))
                    .labelsHidden().textFieldStyle(.roundedBorder).font(AppFont.numbers).frame(width: 84)
                Text("to").font(AppFont.body).foregroundStyle(.appSecondary)
                TextField("Cut to", text: $to, prompt: Text("4:42"))
                    .labelsHidden().textFieldStyle(.roundedBorder).font(AppFont.numbers).frame(width: 84)
                    .onSubmit(add)
                Button("Add Cut", action: add)
                    .disabled(from.isEmpty || to.isEmpty || !model.canEditEpisode(recording))
            }
            Text(problem ?? "Or select words in the transcript and choose Remove from the Edit.")
                .font(AppFont.secondary)
                .foregroundStyle(problem == nil ? AppColor.secondaryText : AppColor.problemText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func add() {
        problem = model.typedCut(from: from, to: to, for: recording)
        if problem == nil {
            from = ""
            to = ""
        }
    }
}

/// A time Ivan types, applied on Return or when the field loses focus, with the problem in words when it
/// cannot work.
struct InspectorTimeField: View {
    let label: String
    let placeholder: String
    let value: Double?
    /// The Viewer's moment, when the recording is open there: Use Player Time types it in.
    var playerTime: (() -> Double?)?
    let apply: (Double?) -> String?
    @State private var text = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.secondary).foregroundStyle(.appSecondary)
            HStack(spacing: 8) {
                TextField(label, text: $text, prompt: Text(placeholder))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.numbers)
                    .frame(maxWidth: 140, alignment: .leading)
                    .focused($focused)
                    .onSubmit(commit)
                if let playerTime {
                    Button("Use Player Time") {
                        if let t = playerTime() {
                            text = TimeText.string(t)
                            commit()
                        }
                    }
                }
            }
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

/// Who is teaching (v2 part M6b, docs/v2/PLAN.md M6): one pick per recording, from the people named in Settings, Privacy.
/// It names the voice that speaks the most and the face that goes with it, so the People tab can say "Gabriel speaks
/// for 92 percent." Only a name: nothing about the person's face or voice is kept for it.
struct WhoIsTeaching: View {
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let people = model.namedPeopleList()
        let teacher = recording.names.teacher
        VStack(alignment: .leading, spacing: 6) {
            Text("Who is teaching").font(AppFont.secondary).foregroundStyle(.appSecondary)
            if people.isEmpty {
                Text("No one is named yet. Add names in Settings, Privacy.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings, Privacy") { model.showSettings(.privacy) }
                    .font(AppFont.body)
            } else {
                Picker("Who is teaching", selection: Binding(get: { teacher }, set: { id in
                    model.setTeacher(people.first { $0.id == id }, for: recording)
                })) {
                    Text("Not chosen").tag(UUID?.none)
                    ForEach(people) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                }
                .labelsHidden()
                .font(AppFont.body)
                .disabled(recording.status == .working)
            }
            Text(teacherNote)
                .font(AppFont.secondary).foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var teacherNote: String {
        guard recording.voices != nil else {
            return "Gives the name to the voice that speaks the most, and its face, once Prakriti has checked who appears and speaks."
        }
        return "Gives the name to the voice that speaks the most, and its face. Name anyone else in the People tab."
    }
}
