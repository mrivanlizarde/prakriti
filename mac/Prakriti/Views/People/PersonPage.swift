import SwiftData
import SwiftUI

/// A person's page (v2 part M7a, docs/v2/design-spec.md 3.9.2, research-people.md 4.2): their key photo and name, the
/// status line ("Recognition off. Named by you in each recording."), whether they can appear in what is published (a
/// separate consent), three figures (recordings, minutes on screen, minutes speaking), Rename, Change Key Photo, the
/// release, Favorite, Hide from People and Forget Face and Voice; then the recordings they appear in, as the browser
/// shows them. Review Possible Matches and Merge come with recognition (part M7b).
struct PersonPage: View {
    let personID: UUID
    @Environment(AppModel.self) private var model
    @Query private var people: [Person]
    @Query private var recordings: [Recording]

    var body: some View {
        if let person = people.first(where: { $0.id == personID }) {
            let entry = Gallery.entry(person, in: recordings)
            let shown = recordings.filter { recording in entry.appearances.contains { $0.recordingID == recording.id } }
            let filtered = Library.filtered(shown, kinds: model.kindFilter, otherPeople: model.otherPeopleFilter)
            let sections = Library.sections(for: .person(personID), recordings: filtered, sort: model.browserSort)
            Group {
                if filtered.isEmpty {
                    ScrollView {
                        EmptyState(symbol: "person.crop.rectangle.stack", title: "\(person.name) is not in a recording yet",
                                   message: "Choose \(person.name) under Who is teaching in the inspector's Info tab, or use Name for This Recording in its People tab.")
                    }
                } else {
                    BrowserContent(sections: sections, flat: sections.flatMap(\.recordings), matches: [:])
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                PersonHeader(person: person, entry: entry)
                    .background(.background)
            }
        } else {
            ScrollView {
                EmptyState(symbol: "person.crop.circle.badge.questionmark", title: "Not in People any more",
                           message: "The name was removed in Settings, Privacy. Recordings that used it count that person as not named.")
            }
        }
    }
}

/// The top of a person's page.
struct PersonHeader: View {
    let person: Person
    let entry: GalleryEntry
    @Environment(AppModel.self) private var model
    @State private var renaming = false
    @State private var choosingPhoto = false
    @State private var forgetting = false

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            PersonPhoto(person: person, entry: entry, size: 160)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(person.name)
                        .font(AppFont.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    if let role = person.role {
                        Text(role.title)
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                    }
                }
                // At least 300 pt wide before they wrap: asked for their smallest size, wrapping lines otherwise reflow to a
                // word a line (measured in the M7a snapshots: a page asking for 2,415 pt).
                Text(Gallery.statusLine(person))
                    .font(AppFont.body)
                    .frame(minWidth: 300, maxWidth: 640, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Gallery.appearLine(person))
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .frame(minWidth: 300, maxWidth: 640, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 28) {
                    ForEach(Gallery.figures(entry), id: \.label) { figure in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(figure.value).font(AppFont.sectionTitle).monospacedDigit()
                            Text(figure.label).font(AppFont.secondary).foregroundStyle(.appSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 4)
                HStack(spacing: 10) {
                    Button("Rename…") { renaming = true }
                    Button("Change Key Photo…") { choosingPhoto = true }
                        .disabled(!person.mayAppear || entry.appearances.allSatisfy(\.faces.isEmpty))
                    Button(person.releaseSignedOn == nil || person.forgottenAt != nil ? "Record Release…" : "Release…") { model.askForRelease(person) }
                    Menu {
                        Button(person.favorite ? "Unfavorite" : "Favorite") { model.setFavorite(!person.favorite, for: person) }
                        Button(person.pinned ? "Unpin from Sidebar" : "Pin to Sidebar") { model.setPinned(!person.pinned, for: person) }
                        Toggle("Can Appear in What Is Published", isOn: Binding(get: { person.mayAppear }, set: { model.setMayAppear($0, for: person) }))
                        Divider()
                        Button(person.hiddenFromPeople ? "Show in People" : "Hide from People") { model.setHidden(!person.hiddenFromPeople, for: person) }
                        if person.hasRelease || model.vault.holdsAnything(person: person.id) {
                            Divider()
                            Button("Forget Face and Voice…", role: .destructive) { forgetting = true }
                        }
                    } label: {
                        Text("More")
                    }
                    .fixedSize()
                }
                .font(AppFont.body)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .sheet(isPresented: $renaming) { RenameSheet(person: person) }
        .sheet(isPresented: $choosingPhoto) { KeyPhotoSheet(person: person, entry: entry) }
        .alert("Forget \(person.name)?", isPresented: $forgetting) {
            Button("Forget", role: .destructive) { model.forgetFaceAndVoice(person) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete what Prakriti keeps of \(person.name)'s face and voice, and the key that locks it? The name stays on recordings already checked, and so does the record of the release. This cannot be undone.")
        }
    }
}

/// Change Key Photo: every face row named for the person, each cropped live from its recording, newest recording first;
/// or Automatic (the face on screen the longest). Only the choice is kept, never the picture.
struct KeyPhotoSheet: View {
    let person: Person
    let entry: GalleryEntry
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let options = entry.appearances.flatMap { appearance in appearance.faces.map { (appearance, $0) } }
        VStack(alignment: .leading, spacing: 14) {
            Text("Key Photo for \(person.name)")
                .font(AppFont.sectionTitle)
            Text("Each face is taken from its recording while this is open. Only your choice is kept, never the picture.")
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16, alignment: .top)], spacing: 16) {
                    ForEach(options.prefix(40), id: \.1.rowID) { appearance, face in
                        let choice = KeyPhotoChoice(recording: appearance.recordingID, row: face.id)
                        Button {
                            model.setKeyPhoto(choice, for: person)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Group {
                                    if let image = model.keyPhotos.image(for: choice) {
                                        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Image(systemName: "person.crop.circle").resizable().foregroundStyle(.appSecondary)
                                    }
                                }
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: person.keyPhoto == choice ? 3 : 0))
                                Text(Format.dayLabel(appearance.sessionDate)).font(AppFont.secondary)
                                Text(Format.timecode(face.keyTime)).font(AppFont.numbers).foregroundStyle(.appSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .task { model.keyPhotos.load(choice, file: appearance.filePath, face: face) }
                    }
                }
            }
            .frame(width: 560, height: 300)
            HStack {
                Button("Automatic") {
                    model.setKeyPhoto(nil, for: person)
                    dismiss()
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .font(AppFont.body)
        }
        .padding(24)
    }
}

/// The recordings with someone in them nobody named: the gallery's "Unnamed people" tile. Never one person: each
/// recording shows its own unnamed people in its People tab.
struct UnnamedBrowser: View {
    @Query private var all: [Recording]
    @Environment(AppModel.self) private var model

    var body: some View {
        let members = Library.members(of: .unnamed, in: all)
        BrowserBody(item: .unnamed, recordings: members)
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Prakriti does not remember people who are not named. Each recording shows its own, in the inspector's People tab.")
                    .font(AppFont.body)
                    .foregroundStyle(.appSecondary)
                    .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .background(.background)
            }
    }
}
