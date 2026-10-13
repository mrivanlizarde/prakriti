import SwiftUI

/// The inspector's People tab, read only (v2 part M6a, docs/v2/design-spec.md 3.5.2): what the face step found,
/// in one plain sentence, then one row per face as far as Prakriti can tell without knowing who anyone is, each
/// with its face cropped live from the original and held in memory only. Nobody is named and nothing is decided
/// here yet; names and the choices of who appears come with later parts. A recording found before faces were
/// looked for offers Look for Faces instead of looking by itself (docs/v2/PLAN.md rule 2.1.7).
struct PeopleTab: View {
    let recording: Recording
    @Environment(AppModel.self) private var model

    /// The rows shown; any more are counted under them.
    static let rowLimit = 12

    var body: some View {
        Form {
            if let faces = recording.faces {
                Section {
                    Text(faces.summary)
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Looked at " + Format.dayAndTime(faces.checkedAt) + ", two frames a second. Only when and where each face was seen is kept, never a picture of it.")
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if faces.hasPicture && !faces.people.isEmpty {
                    Section {
                        ForEach(faces.people.prefix(Self.rowLimit)) { person in
                            FaceRow(person: person, recording: recording)
                        }
                        if faces.people.count > Self.rowLimit {
                            RowNote("And \(Format.count(faces.people.count - Self.rowLimit, "more row")).")
                        }
                        if faces.people.count > 1 {
                            RowNote("Each row is a face seen in one place in the picture. One person who moves around can make two rows, so the number at once, above, is the one to go by.")
                        }
                        if faces.glimpses > 0 {
                            RowNote(Format.count(faces.glimpses, "face") + " seen for under a second " + (faces.glimpses == 1 ? "is" : "are") + " not listed.")
                        }
                    } header: {
                        SectionHeader("In This Recording")
                    }
                } else if faces.hasPicture && faces.glimpses > 0 {
                    Section {
                        RowNote(Format.count(faces.glimpses, "face") + " seen for under a second " + (faces.glimpses == 1 ? "is" : "are") + " not listed.")
                    }
                }
                lookAgain
            } else if model.faceChecking.contains(recording.id) {
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(PipelineStep.faces.doing).font(AppFont.body)
                    }
                }
            } else {
                Section {
                    RowNote(recording.status == .found || recording.status == .working
                            ? "Faces are looked for while the outputs are made, after the transcript."
                            : "Not looked at. This recording was found before Prakriti looked for faces.")
                    problem
                    if recording.status != .found && recording.status != .working {
                        Button("Look for Faces") { model.lookForFaces(recording) }
                            .font(AppFont.body)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var problem: some View {
        if let problem = model.faceProblems[recording.id] {
            Text(problem)
                .font(AppFont.secondary)
                .foregroundStyle(AppColor.problemText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var lookAgain: some View {
        if recording.status != .working {
            Section {
                problem
                if model.faceChecking.contains(recording.id) {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(PipelineStep.faces.doing).font(AppFont.body)
                    }
                } else {
                    Button("Look for Faces Again") { model.lookForFaces(recording) }
                        .font(AppFont.body)
                }
            }
        }
    }
}

/// One row: the face, its label, and how long it is on screen.
struct FaceRow: View {
    let person: FacePerson
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let image = model.faceCrops.image(for: person, in: recording) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(AppFont.welcomeRowSymbol)
                        .foregroundStyle(.appSecondary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(person.label)
                    .font(AppFont.body)
                Text("On screen \(Format.length(person.onScreen)), between \(Format.timecode(person.first)) and \(Format.timecode(person.last)).")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .task(id: "\(recording.id)-\(person.id)") { model.faceCrops.load(person, from: recording) }
    }
}

/// The people line under a card and in the list's People column (design spec 3.1.1), once faces were looked for.
struct PeopleLine: View {
    let faces: FacesFound

    var symbol: String {
        guard faces.hasPicture else { return "video.slash" }
        switch faces.mostAtOnce {
        case 0: return "person.slash"
        case 1: return "person"
        default: return "person.2"
        }
    }

    var body: some View {
        Label {
            Text(faces.line)
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .font(AppFont.secondary)
                .foregroundStyle(faces.otherPeopleAppear ? AnyShapeStyle(AppColor.accentText) : AnyShapeStyle(.appSecondary))
        }
        .accessibilityElement(children: .combine)
    }
}
