import SwiftUI

/// Name This Person (v2 part M7a, docs/v2/design-spec.md 3.9.4, research-people.md 5.3 and 5.6): a name, with
/// suggestions of the people already named (choosing one means "this is them"), their role, whether they can appear in
/// what is published, and the written release for recognition: when it was signed, where it is kept, and which uses it
/// covers. **Name Only** is the default button: a name kept as a name, nothing about a face or a voice. With a complete
/// release that covers their face, the button is **Learn [Name]** (research-people.md 5.6): Prakriti learns their face
/// from the recordings where they are named and recognizes them in new ones (v2 part M7b). A release for the voice only
/// is **Record Release**: voice prints are not learned in this version.
struct NameThisPersonSheet: View {
    @State var request: NameSheetRequest
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var problem: String?

    var body: some View {
        let existing = request.personID.flatMap { id in model.namedPeopleList().first { $0.id == id } }
        let name = request.draft.trimmedName.isEmpty ? "this person" : request.draft.trimmedName
        let suggestions = model.namedPeopleList().filter {
            !request.draft.trimmedName.isEmpty && $0.name.localizedCaseInsensitiveContains(request.draft.trimmedName) && $0.name != request.draft.trimmedName
        }
        VStack(alignment: .leading, spacing: 0) {
            Text(existing == nil ? "Name This Person" : "Release for \(existing!.name)")
                .font(AppFont.sectionTitle)
                .padding([.horizontal, .top], 24)
            Form {
                Section {
                    if existing == nil {
                        TextField("Name", text: $request.draft.name, prompt: Text("Their name"))
                            .font(AppFont.body)
                        if !suggestions.isEmpty {
                            HStack(spacing: 8) {
                                Text("Already named:").font(AppFont.secondary).foregroundStyle(.appSecondary)
                                ForEach(suggestions.prefix(3)) { person in
                                    Button(person.name) { request.draft.name = person.name }
                                        .font(AppFont.secondary)
                                }
                            }
                        }
                        Picker("Role", selection: $request.draft.role) {
                            Text("Not said").tag(PersonRole?.none)
                            ForEach(PersonRole.allCases) { role in Text(role.title).tag(Optional(role)) }
                        }
                        .font(AppFont.body)
                    }
                    Toggle("Can appear in what is published", isOn: $request.draft.mayAppear)
                        .font(AppFont.body)
                    RowNote("Shown by a frame from their recordings in People. Turned off, People shows their initials.")
                }
                Section {
                    Toggle("A written release is signed", isOn: $request.draft.recordRelease)
                        .font(AppFont.body)
                    if request.draft.recordRelease {
                        DatePicker("Written release signed on", selection: $request.draft.releaseSignedOn, displayedComponents: .date)
                            .font(AppFont.body)
                        TextField("Where the signed release is kept", text: $request.draft.releaseKeptAt, prompt: Text("A folder or a place"))
                            .font(AppFont.body)
                        Toggle("It covers their face", isOn: $request.draft.learnFace).font(AppFont.body)
                        Toggle("It covers their voice", isOn: $request.draft.learnVoice).font(AppFont.body)
                    }
                    RowNote(request.draft.recordRelease
                            ? (request.draft.learnFace
                               ? "Prakriti learns \(name)'s face from the recordings where \(name) is named, so it finds \(name) in new recordings by itself. It keeps what it learns only on this Mac, locked, and deletes it if you choose Forget Face and Voice or \(name) has not appeared for 12 months. Voices are not learned yet."
                               : "Prakriti keeps the release with \(name)'s name. Voices are not learned yet, so you name \(name) in each recording.")
                            : "Name Only keeps the name on this recording. Prakriti will not look for \(name) in other recordings, and keeps nothing about a face or a voice.")
                } header: {
                    SectionHeader("Recognition")
                }
                if let problem = problem ?? request.draft.releaseProblem {
                    Text(problem)
                        .font(AppFont.secondary)
                        .foregroundStyle(AppColor.problemText)
                }
            }
            .formStyle(.grouped)
            .frame(width: 520)
            .frame(minHeight: 360)
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if existing == nil {
                    nameOnly
                }
                if request.draft.defaultAction == .recordRelease {
                    Button(releaseButton(name)) { finish(.recordRelease) }
                        .keyboardShortcut(.defaultAction)
                } else if request.draft.recordRelease {
                    Button(releaseButton(name)) { finish(.recordRelease) }
                        .disabled(true)
                }
            }
            .font(AppFont.body)
            .padding([.horizontal, .bottom], 24)
        }
    }

    /// The default button unless a complete release is filled in.
    @ViewBuilder private var nameOnly: some View {
        if request.draft.defaultAction == .nameOnly {
            Button("Name Only") { finish(.nameOnly) }
                .keyboardShortcut(.defaultAction)
                .disabled(request.draft.trimmedName.isEmpty)
        } else {
            Button("Name Only") { finish(.nameOnly) }
        }
    }

    /// "Learn Gabriel" when the release covers a face (it learns it), else "Record Release".
    func releaseButton(_ name: String) -> String {
        request.draft.learnFace && !request.draft.trimmedName.isEmpty ? "Learn \(request.draft.trimmedName)" : "Record Release"
    }

    func finish(_ action: NameThisPersonDraft.Action) {
        problem = model.finishNaming(request, as: action)
        if problem == nil { dismiss() }
    }
}
