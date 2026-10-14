import SwiftUI

/// Review Possible Matches (v2 part M7b, docs/v2/design-spec.md 3.9.2, research-people.md 4.2 and 5.6): Photos' Review
/// More, one face at a time, "Is this Gabriel?" with **Yes** and **Not Gabriel**. Only the faces recognition was not sure
/// about, recordings waiting for a yes first. The face is cropped from its recording while the sheet shows it and never
/// saved; no number is shown (design spec 3.5.2). A Yes names the face and, with a release that covers it, learns it.
struct ReviewSheet: View {
    let request: ReviewRequest
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var image: CGImage?
    @State private var answered = 0

    var body: some View {
        let person = model.namedPeopleList().first { $0.id == request.personID }
        let name = person?.name ?? "this person"
        let matches = model.possibleMatches(for: request.personID)
        VStack(alignment: .leading, spacing: 16) {
            if let match = matches.first {
                Text("Is this \(name)?")
                    .font(AppFont.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .center, spacing: 20) {
                    Group {
                        if let image {
                            Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.crop.circle").resizable().foregroundStyle(.appSecondary)
                        }
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From \(Format.dayLabel(match.sessionDate)), on screen from \(Format.timecode(match.row.first)).")
                            .font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Prakriti found a face that may be \(name), and was not sure enough to name it. Until you answer, it counts as not named.")
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(matches.count == 1 ? "This is the last face to review." : "\(Format.count(matches.count - 1, "more face")) after this one.")
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                    }
                    .frame(width: 300, alignment: .leading)
                }
                .task(id: match.id) { await load(match) }
                HStack(spacing: 10) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Not \(name)") {
                        if let recording = model.fetchRecording(match.recordingID) {
                            model.rejectMatch(row: match.row.id, person: match.person, in: recording)
                        }
                        answered += 1
                    }
                    Button("Yes") {
                        model.confirmMatch(match)
                        answered += 1
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .font(AppFont.body)
            } else {
                Text("No faces to review")
                    .font(AppFont.sectionTitle)
                Text(answered == 0
                     ? "When Prakriti is not sure a face in a new recording is \(name), it asks here. Nothing is waiting now."
                     : "That was the last one. Each Yes named the face, and taught Prakriti a little more of \(name)'s face.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 480, alignment: .leading)
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
                .font(AppFont.body)
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    func load(_ match: PossibleMatch) async {
        image = nil
        if model.keyPhotos.useTestPattern {
            image = FaceCrops.testPattern(seed: match.row.id)
            return
        }
        let file = URL(fileURLWithPath: match.filePath)
        let row = match.row
        image = await Task.detached { await FaceCrops.crop(file: file, time: row.keyTime, box: row.keyBox) }.value
    }
}

/// Merge 2 People (v2 part M7b, research-people.md 2.4): the two become one person, under the name Ivan keeps. Refused
/// unless both have a recorded release, because it joins what Prakriti learned of each.
struct MergeSheet: View {
    let request: MergeRequest
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keep: UUID?
    @State private var problem: String?

    var body: some View {
        let people = model.namedPeopleList()
        if let first = people.first(where: { $0.id == request.first }), let second = people.first(where: { $0.id == request.second }) {
            let refusal = model.mergeProblem(first, second)
            VStack(alignment: .leading, spacing: 14) {
                Text("Merge \(first.name) and \(second.name)?")
                    .font(AppFont.sectionTitle)
                Text("They become one person: every recording that names either takes the name you keep, and what Prakriti learned of both faces is kept together, locked under one key. Where their choices differ, the stricter one is kept.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 460, alignment: .leading)
                Picker("Keep the name", selection: Binding(get: { keep ?? first.id }, set: { keep = $0 })) {
                    Text(first.name).tag(first.id)
                    Text(second.name).tag(second.id)
                }
                .pickerStyle(.radioGroup)
                .font(AppFont.body)
                .disabled(refusal != nil)
                if let message = problem ?? refusal {
                    Text(message)
                        .font(AppFont.secondary)
                        .foregroundStyle(AppColor.problemText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 460, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Merge 2 People") {
                        let kept = (keep ?? first.id) == first.id ? first : second
                        let other = kept.id == first.id ? second : first
                        problem = model.merge(other, into: kept)
                        if problem == nil { dismiss() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(refusal != nil)
                }
                .font(AppFont.body)
            }
            .padding(24)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose two people to merge.").font(AppFont.body)
                HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            }
            .padding(24)
        }
    }
}
