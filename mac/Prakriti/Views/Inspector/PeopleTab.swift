import SwiftUI

/// The inspector's People tab (v2 parts M6a, M6b and M6c, docs/v2/design-spec.md 3.5.2): what the face step and the
/// voice step found, in plain sentences, then one row per face and one per voice with no face, each with Name for This
/// Recording and its choice (Include, Hide Face, Leave Out; PeopleChoicesViews.swift); Set All Unnamed To; the names
/// said aloud with Keep and Mute; and whether the choices are in the episode. A face's picture is cropped live from the
/// original and held in memory only. A recording found before the people pass existed offers Check People instead of
/// checking by itself (docs/v2/PLAN.md rule 2.1.7).
struct PeopleTab: View {
    let recording: Recording
    @Environment(AppModel.self) private var model

    /// The rows shown; any more are counted under them.
    static let rowLimit = 12

    var body: some View {
        let people = recording.namedPeople
        let names = recording.resolvedNames.resolved(faces: recording.faces, voices: recording.voices)
        Form {
            if let faces = recording.faces {
                Section {
                    Text(summary(faces, people: people))
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(keptLine(faces))
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if (faces.hasPicture && !faces.people.isEmpty) || !(recording.voices?.voices.isEmpty ?? true) {
                    Section {
                        // Face rows and voice rows share one list, and both number from 1, so each gets its own kind
                        // of id (two rows with the same id draw the first twice; measured in the M6b snapshots).
                        let plain = recording.resolvedNames
                        ForEach(faces.people.prefix(Self.rowLimit), id: \.rowID) { person in
                            FaceRow(person: person, recording: recording, voice: voice(linkedTo: person.id),
                                    name: names.faces[person.id].flatMap { id in people.first { $0.id == id }?.name },
                                    recognizedAs: recognized(person.id, plain: plain, names: names, people: people),
                                    askAbout: names.faces[person.id] == nil ? plain.asks[person.id].flatMap { id in people.first { $0.id == id } } : nil)
                        }
                        if faces.people.count > Self.rowLimit {
                            RowNote("And \(Format.count(faces.people.count - Self.rowLimit, "more row")).")
                        }
                        ForEach(unlinkedVoices, id: \.rowID) { voice in
                            VoiceRow(voice: voice, recording: recording,
                                     name: names.voices[voice.id].flatMap { id in people.first { $0.id == id }?.name })
                        }
                        if faces.people.count > 1 {
                            RowNote("Each face row is a face seen in one place in the picture. One person who moves around can make two rows, so the number at once is the one to go by.")
                        }
                        glimpses(faces, name: names.faces[0].flatMap { id in people.first { $0.id == id }?.name })
                        if recording.voices != nil { SetAllUnnamed(recording: recording) }
                    } header: {
                        SectionHeader("In This Recording")
                    }
                } else if faces.hasPicture && faces.glimpses > 0 {
                    Section { glimpses(faces, name: names.faces[0].flatMap { id in people.first { $0.id == id }?.name }) }
                }
                if let voices = recording.voices, !voices.listen.isEmpty {
                    Section {
                        RowNote("The voices were told apart on one mixed track, so who said what is a best guess. "
                                + "\(Format.count(voices.listen.count, "change")) from one voice to another, the first at \(Format.timecode(voices.listen[0])), "
                                + (voices.listen.count == 1 ? "is" : "are") + " worth listening to.")
                    }
                }
                if recording.voices != nil {
                    ChoiceStatusSection(recording: recording)
                    if let said = recording.namesSaid { NamesSaidSection(recording: recording, names: said) }
                }
                if people.isEmpty {
                    Section {
                        RowNote("To name the people in a recording, use Name This Person under a face or a voice, or add their names in Settings, Privacy. A name is kept only as a name: nothing about a face or a voice.")
                        Button("Open Settings, Privacy") { model.showSettings(.privacy) }
                            .font(AppFont.body)
                    }
                }
                checkAgain
            } else if model.faceChecking.contains(recording.id) {
                Section { working }
            } else {
                Section {
                    RowNote(recording.status == .found || recording.status == .working
                            ? "Faces and voices are checked while the outputs are made, after the transcript."
                            : "Not checked. This recording was found before Prakriti checked who appears and speaks.")
                    problem
                    if recording.status != .found && recording.status != .working {
                        Button("Check People") { model.checkPeople(recording) }
                            .font(AppFont.body)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    func summary(_ faces: FacesFound, people: [NamedPerson]) -> String {
        guard let voices = recording.voices else { return faces.summary }
        let said = PeopleWords.summary(faces: faces, voices: voices, names: recording.resolvedNames, people: people)
        // Faces at once, when other people appear: the voices' sentence first, then how many are seen together.
        if faces.mostAtOnce >= 2 {
            return said + " Up to \(faces.mostAtOnce) people are on screen at once" + (faces.firstWithOthers.map { ", first at " + Format.timecode($0) } ?? "") + "."
        }
        return said
    }

    func keptLine(_ faces: FacesFound) -> String {
        guard let voices = recording.voices else {
            return "Faces looked at " + Format.dayAndTime(faces.checkedAt) + ", two frames a second. Voices not listened for yet. Only when and where each face was seen is kept, never a picture of it."
        }
        return "Checked " + Format.dayAndTime(voices.checkedAt) + ". " + voices.sourceLine
            + " Only when and where each face is seen and when each voice speaks are kept, never a picture of a face or a print of a voice."
    }

    func voice(linkedTo face: Int) -> FoundVoice? { recording.voices?.voices.first { $0.face == face } }

    /// The person recognition named a row as, when that is the name the row carries (Ivan's own names come first).
    func recognized(_ row: Int, plain: PeopleNames, names: (faces: [Int: UUID], voices: [Int: UUID]), people: [NamedPerson]) -> NamedPerson? {
        guard plain.faces[row] == nil, let id = plain.recognized[row], names.faces[row] == id else { return nil }
        return people.first { $0.id == id }
    }

    var unlinkedVoices: [FoundVoice] { (recording.voices?.voices ?? []).filter { $0.face == nil } }

    @ViewBuilder func glimpses(_ faces: FacesFound, name: String?) -> some View {
        if faces.glimpses > 0 {
            HStack(alignment: .firstTextBaseline) {
                RowNote(Format.count(faces.glimpses, "face") + " seen for under a second " + (faces.glimpses == 1 ? "is" : "are") + " not listed"
                        + (name.map { ", named \($0)." } ?? ", and not named."))
                Spacer(minLength: 8)
                NameMenu(recording: recording, current: name, target: .face(0)) { model.nameFace(0, as: $0, in: recording) }
            }
        }
    }

    var working: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Looking for faces and listening for voices").font(AppFont.body)
        }
    }

    @ViewBuilder private var problem: some View {
        if let problem = model.faceProblems[recording.id] {
            Text(problem)
                .font(AppFont.secondary)
                .foregroundStyle(AppColor.problemText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var checkAgain: some View {
        if recording.status != .working {
            Section {
                problem
                if model.faceChecking.contains(recording.id) {
                    working
                } else {
                    Button(recording.voices == nil ? "Check People" : "Check People Again") { model.checkPeople(recording) }
                        .font(AppFont.body)
                }
            }
        }
    }
}

/// Name for This Recording: the people named in Settings, Privacy, and Not Named.
struct NameMenu: View {
    let recording: Recording
    let current: String?
    /// The row this menu names, for Name This Person (v2 part M7a).
    var target: NameTarget? = nil
    let choose: (Person?) -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            ForEach(model.namedPeopleList()) { person in
                Button(person.name) { choose(person) }
            }
            if current != nil {
                Divider()
                Button("Not Named") { choose(nil) }
            }
            Divider()
            if let target {
                Button("Name This Person…") { model.askToName(target, in: recording) }
            }
            Button("Add a Name in Settings") { model.showSettings(.privacy) }
        } label: {
            Text("Name for This Recording").font(AppFont.secondary)
        }
        .menuStyle(.button)
        .fixedSize()
        .accessibilityLabel("Name for This Recording")
    }
}

/// One face: its picture, its name or label, how long it is on screen and, when a voice is linked to it, how long it
/// speaks.
struct FaceRow: View {
    let person: FacePerson
    let recording: Recording
    var voice: FoundVoice? = nil
    var name: String? = nil
    /// Recognition named this row (v2 part M7b), or asks whether it is this person.
    var recognizedAs: NamedPerson? = nil
    var askAbout: NamedPerson? = nil
    @Environment(AppModel.self) private var model

    var detail: String {
        var line = "On screen \(Format.length(person.onScreen)), between \(Format.timecode(person.first)) and \(Format.timecode(person.last))."
        if let voice {
            line += " Speaks \(Format.length(voice.speaking))" + (voice.track.map { ", on track \($0)" } ?? "") + (voice.linkedBy.map { ": \($0)." } ?? ".")
        } else if recording.voices != nil {
            line += " No voice is linked to this face."
        }
        return line
    }

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
                Text(name ?? person.label)
                    .font(AppFont.body)
                Text(detail)
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let recognizedAs {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Recognized by Prakriti", systemImage: "person.crop.circle.badge.checkmark")
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                        Button("Not \(recognizedAs.name)") { model.rejectMatch(row: person.id, person: recognizedAs.id, in: recording) }
                            .font(AppFont.secondary)
                    }
                    .padding(.top, 2)
                } else if let askAbout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Is this \(askAbout.name)?")
                            .font(AppFont.secondaryEmphasis)
                        HStack(spacing: 8) {
                        Button("Yes") {
                            if let match = model.possibleMatches(for: askAbout.id).first(where: { $0.recordingID == recording.id && $0.row.id == person.id }) {
                                model.confirmMatch(match)
                            }
                        }
                        Button("Not \(askAbout.name)") { model.rejectMatch(row: person.id, person: askAbout.id, in: recording) }
                        }
                    }
                    .font(AppFont.secondary)
                    .padding(.top, 2)
                }
                if recording.voices != nil {
                    NameMenu(recording: recording, current: name, target: .face(person.id)) { model.nameFace(person.id, as: $0, in: recording) }
                        .padding(.top, 2)
                    ChoiceControls(recording: recording, key: PersonKey.face(person.id, names: recording.resolvedNameTable), hasFace: true)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .task(id: "\(recording.id)-\(person.id)") { model.faceCrops.load(person, from: recording) }
    }
}

/// One voice with no face linked to it: the waveform symbol in a circle (design spec 3.5.2), its name or label, how
/// long it speaks, and for a microphone track, naming the track for the whole folder.
struct VoiceRow: View {
    let voice: FoundVoice
    let recording: Recording
    var name: String? = nil
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(AppFont.welcomeRowSymbol)
                .foregroundStyle(.appSecondary)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(name ?? voice.label)
                    .font(AppFont.body)
                Text("Speaks \(Format.length(voice.speaking)), between \(Format.timecode(voice.first)) and \(Format.timecode(voice.last))"
                     + (voice.track.map { ", on track \($0)" } ?? "") + ". No face is linked to this voice.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    NameMenu(recording: recording, current: name, target: .voice(voice.id)) { model.nameVoice(voice.id, as: $0, in: recording) }
                    if let track = voice.track, recording.source != nil {
                        Menu {
                            ForEach(model.namedPeopleList()) { person in
                                Button(person.name) { model.setMicrophone(track: track, to: person, for: recording) }
                            }
                            if recording.source?.microphones[track] != nil {
                                Divider()
                                Button("No One") { model.setMicrophone(track: track, to: nil, for: recording) }
                            }
                        } label: {
                            Text("Track \(track) in This Folder").font(AppFont.secondary)
                        }
                        .menuStyle(.button)
                        .fixedSize()
                    }
                }
                .padding(.top, 2)
                ChoiceControls(recording: recording, key: PersonKey.voice(voice, names: recording.resolvedNameTable), hasFace: false)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }
}

/// The people line under a card and in the list's People column (design spec 3.1.1), once faces were looked for:
/// the names of the people named in it, then how many others appear and speak.
struct PeopleLine: View {
    let faces: FacesFound
    var recording: Recording? = nil

    var symbol: String {
        guard faces.hasPicture else { return "video.slash" }
        switch faces.mostAtOnce {
        case 0: return "person.slash"
        case 1: return "person"
        default: return "person.2"
        }
    }

    var text: String {
        guard let recording else { return faces.line }
        return PeopleWords.line(faces: faces, voices: recording.voices, names: recording.resolvedNames, people: recording.namedPeople) ?? faces.line
    }

    var body: some View {
        Label {
            Text(text)
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

extension FacePerson {
    var rowID: String { "face-\(id)" }
}

extension FoundVoice {
    var rowID: String { "voice-\(id)" }
}
