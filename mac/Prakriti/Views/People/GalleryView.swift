import SwiftData
import SwiftUI

/// The People gallery (v2 part M7a, docs/v2/design-spec.md 3.9.1, research-people.md 4.2): every named person as a round
/// key photo, Name Only included, favorites first, by name or in Ivan's custom order; and one face-less tile for the
/// people nobody named, which lists their recordings. A key photo is a frame cropped live from a recording for a
/// person who may appear, else their initials; nothing about a face is kept for it.
struct GalleryView: View {
    @Environment(AppModel.self) private var model
    @Query private var people: [Person]
    @Query private var recordings: [Recording]

    static let tile: CGFloat = 120

    var body: some View {
        @Bindable var model = model
        let entries = people.map { Gallery.entry($0, in: recordings) }
        let shown = Gallery.ordered(entries, sort: model.gallerySort, showHidden: model.galleryShowsHidden)
        let hiddenCount = entries.filter(\.hidden).count
        let unnamed = Gallery.unnamedRecordings(recordings)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Picker("Sort", selection: $model.gallerySort) {
                        ForEach(GallerySort.allCases) { sort in Text(sort.title).tag(sort) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .font(AppFont.body)
                    if hiddenCount > 0 {
                        Toggle("Show \(Format.count(hiddenCount, "Hidden Person", "Hidden People"))", isOn: $model.galleryShowsHidden)
                            .toggleStyle(.checkbox)
                            .font(AppFont.body)
                    }
                    Spacer(minLength: 0)
                }
                if entries.isEmpty {
                    EmptyState(symbol: "person.2",
                               title: "No one is named yet",
                               message: "Open a recording, choose People in the inspector, and use Name This Person on a face or a voice.")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24, alignment: .top)], alignment: .leading, spacing: 28) {
                    ForEach(shown) { entry in
                        if let person = people.first(where: { $0.id == entry.id }) {
                            PersonTile(person: person, entry: entry)
                        }
                    }
                    if !unnamed.isEmpty {
                        UnnamedTile(count: unnamed.count)
                    }
                }
                Text("Prakriti does not recognize anyone by itself: each person here is someone you named in a recording or in Settings, Privacy. Their name is kept, and their release once you record it. Nothing about a face or a voice is kept.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            .padding(24)
        }
    }
}

/// One named person: their key photo in a 120 pt circle, their name, and how many recordings they are in. Click opens
/// their page; the menu has Favorite, Pin, Rename, Hide from People.
struct PersonTile: View {
    let person: Person
    let entry: GalleryEntry
    @Environment(AppModel.self) private var model
    @State private var renaming = false

    var body: some View {
        VStack(spacing: 8) {
            PersonPhoto(person: person, entry: entry, size: GalleryView.tile)
                .overlay(alignment: .bottomTrailing) {
                    if person.favorite {
                        Image(systemName: "heart.fill")
                            .font(AppFont.headline)
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(Color.accentColor))
                            .accessibilityLabel("Favorite")
                    }
                }
                .opacity(person.hiddenFromPeople ? 0.5 : 1)
            Text(person.name)
                .font(AppFont.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(person.hiddenFromPeople ? "Hidden" : entry.tileLine)
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.selection = .person(person.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(person.name), \(entry.tileLine)")
        .draggable(person.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let moving = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            model.moveInGallery(moving, before: person.id)
            return true
        }
        .contextMenu { PersonMenu(person: person, renaming: $renaming) }
        .sheet(isPresented: $renaming) { RenameSheet(person: person) }
    }
}

/// The menu of a person, in the gallery and in the sidebar (Photos' Favorite, Pin, Hide this Person).
struct PersonMenu: View {
    let person: Person
    @Binding var renaming: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Open") { model.selection = .person(person.id) }
        Divider()
        Button(person.favorite ? "Unfavorite" : "Favorite") { model.setFavorite(!person.favorite, for: person) }
        Button(person.pinned ? "Unpin from Sidebar" : "Pin to Sidebar") { model.setPinned(!person.pinned, for: person) }
        Button("Rename…") { renaming = true }
        Divider()
        Button(person.hiddenFromPeople ? "Show in People" : "Hide from People") { model.setHidden(!person.hiddenFromPeople, for: person) }
    }
}

/// The one face-less tile for everyone nobody named (design spec 3.9.1, PLAN section 5): no face, never grouped across
/// recordings. Click shows the recordings they are in.
struct UnnamedTile: View {
    let count: Int
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(AppFont.monogram)
                .foregroundStyle(.appSecondary)
                .frame(width: GalleryView.tile, height: GalleryView.tile)
                .background(Circle().fill(Color.primary.opacity(0.06)))
            Text("Unnamed people")
                .font(AppFont.headline)
            Text("In \(Format.count(count, "recording"))")
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.selection = .unnamed }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Unnamed people, in \(Format.count(count, "recording"))")
    }
}

/// A person's round picture: a frame from a recording for someone who may appear (cropped live, never saved), else their
/// initials. In the sidebar, too small for initials at 12 pt or more, a symbol stands in.
struct PersonPhoto: View {
    let person: Person
    let entry: GalleryEntry
    let size: CGFloat
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = person.mayAppear ? Gallery.keyFace(choice: person.keyPhoto, appearances: entry.appearances) : nil
        let choice = key.map { KeyPhotoChoice(recording: $0.appearance.recordingID, row: $0.face.id) }
        Group {
            if let choice, let image = model.keyPhotos.image(for: choice) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if size >= 60 {
                Text(Gallery.monogram(person.name))
                    .font(size >= 150 ? AppFont.monogramLarge : AppFont.monogram)
                    .foregroundStyle(AppColor.accentText)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.accentColor.opacity(0.14)))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.appSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: choice) {
            if let choice, let key { model.keyPhotos.load(choice, file: key.appearance.filePath, face: key.face) }
        }
    }
}

/// Rename: only the label changes.
struct RenameSheet: View {
    let person: Person
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename \(person.name)")
                .font(AppFont.sectionTitle)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(AppFont.body)
                .frame(width: 320)
                .onSubmit(save)
            Text(problem ?? "Only the name changes. Every recording that names \(person.name) shows the new name.")
                .font(AppFont.secondary)
                .foregroundStyle(problem == nil ? AnyShapeStyle(.appSecondary) : AnyShapeStyle(AppColor.problemText))
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 320, alignment: .leading)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(AppFont.body)
        }
        .padding(24)
        .onAppear { name = person.name }
    }

    func save() {
        problem = model.rename(person, to: name)
        if problem == nil { dismiss() }
    }
}
