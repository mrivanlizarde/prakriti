import SwiftUI

/// The inspector's Direction tab (v2 part M9d, design spec 3.5.3: "a way to prompt or adjust the editorialization"): the direction
/// for this recording (its words, presets, Pace and Length, read back as chips, moved here from the Outputs tab), the plan in plain
/// lines with Plan Again and Make Again, and the versions made, newest first, each with Play and Use This Version. Approval covers
/// the version in use. Nothing changes until Plan Again or Make Again.
struct DirectionTab: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if recording.madeFiles.contains(TranscriptFiles.asHeard) {
                DirectionSection(recording: recording)
                // How many shorts and how long (v2 part M11a, design spec 3.5.3 item 5).
                ShortsDirectionSection(recording: recording)
                DirectionPlanSection(recording: recording)
                VersionsSection(recording: recording)
                SupportingMomentsSection(recording: recording)
            } else {
                Section {
                    Text("Direction steers how this recording is edited: its style, pace, length and what to focus on. It can be set once the recording's transcript is made.")
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// The plan before anything is made (design spec 3.5.3 item 6): its plain lines, whether the newest direction is in it, Plan Again,
/// and Make Again (Make Video the first time), which makes a new version from the plan shown.
struct DirectionPlanSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.editPlan(for: recording)
        let busy = model.planning.contains(recording.id)
        Section {
            if busy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(model.planningLines[recording.id] ?? "Planning the edit.").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            } else if let plan {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.planLines ?? [plan.summary], id: \.self) { line in
                        Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                RowNote("Planned \(Format.dayAndTime(plan.madeAt)).")
                if let behind = model.planIsBehind(recording, plan: plan) {
                    Label {
                        Text(behind + " Plan Again to include them.").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.circle").font(AppFont.body).foregroundStyle(Color.orange)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text("Plan the edit to see what it will do in plain lines before anything is made.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let problem = model.planProblems[recording.id], !busy {
                Label {
                    Text(problem).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            }
            FlowLayout(spacing: 10) {
                Button(plan == nil ? "Plan the Edit" : "Plan Again") { model.planEdit(recording) }
                    .disabled(!model.canPlanEdit(recording))
                    .quickHelp("Plans the edit with this direction and shows the plan in plain lines before anything is made.", article: "editorial-direction")
                if plan != nil {
                    Button(recording.video == nil ? "Make Video" : "Make Again") { model.makeVideo(recording) }
                        .disabled(!model.canMakeVideo(recording))
                        .quickHelp("Makes a new version of the video from this plan. The versions made before are kept below. Nothing is uploaded.",
                                   article: "editorial-direction")
                }
            }
        } header: {
            SectionHeader("The plan")
        }
    }
}

/// The versions made (design spec 3.5.3 item 7), newest first: "Version 3. Energetic, Faster Cuts. Made Sat 10 Oct, 9:41 pm. 11:02
/// long." with Play and Use This Version; the one in use says so. Approve covers the version in use.
struct VersionsSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let versions = recording.versions
        Section {
            if versions.versions.isEmpty {
                Text("Each video made of this recording is kept here as a version, so you can play an earlier one or use it again.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(versions.versions.reversed()) { version in
                    VersionRow(version: version, recording: recording, inUse: versions.current == version.number,
                               playing: model.viewer.playingVersionNumber == version.number)
                }
                RowNote("Approve covers the version in use. The \(EditVersions.kept) newest versions are kept.")
            }
        } header: {
            SectionHeader("Versions")
        }
    }
}

struct VersionRow: View {
    let version: EditVersion
    @Bindable var recording: Recording
    let inUse: Bool
    let playing: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(version.line)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
            if !version.chips.isEmpty {
                Text(version.chips.joined(separator: "; "))
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button("Play") { model.playVersion(version.number, of: recording) }
                    .disabled(!model.versionIsThere(version, of: recording))
                    .quickHelp("Plays this version in the Viewer on Video, drawn the same way as its file.", article: "editorial-direction")
                if inUse {
                    Label("In use", systemImage: "checkmark.circle")
                        .font(AppFont.body)
                        .foregroundStyle(.appSecondary)
                } else {
                    Button("Use This Version") { model.useVersion(version.number, of: recording) }
                        .disabled(!model.canUseVersion(version.number, of: recording))
                        .quickHelp("Puts this version's video and plan back in the recording's folder, where Approve finds them.", article: "editorial-direction")
                }
                if playing {
                    Text("Playing").font(AppFont.secondary).foregroundStyle(.appSecondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

/// Supporting Moments (design spec 3.5.3 item 8, v2 parts M12a and M12b): the moments Ivan added from other recordings, each with
/// its day, length and where it goes, whether its date shows on screen, and Remove; then Find Supporting Moments..., which looks in
/// other recordings of the same teacher for moments that support this recording's main points.
struct SupportingMomentsSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            let added = recording.direction.moments
            if added.isEmpty {
                Text(model.teacherName(of: recording).map { "Moments where \($0) makes the same point in another recording. Prakriti finds them; you choose which to add." }
                     ?? "Moments where the same teacher makes the same point in another recording. Choose who is teaching in Info first.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(added) { moment in
                    AddedMomentRow(moment: moment, showDate: Binding(get: { moment.showDate }, set: { model.setMomentShowsDate(moment.id, $0, in: recording) }),
                                   remove: { model.removeMoment(moment.id, from: recording) })
                }
                RowNote("Added moments are in the video from the next Make Again.")
            }
            Button("Find Supporting Moments…") { model.findSupportingMoments(recording) }
                .disabled(!model.canFindSupportingMoments(recording))
                .quickHelp("Looks in other recordings of the same teacher for moments that support this recording's main points, and shows up to three.",
                           article: "editorial-direction")
        } header: {
            SectionHeader("Supporting Moments")
        }
    }
}

/// One added moment (v2 part M12b): "From Sun 6 Sep 2026, Talk with Gabriel", its length and where it goes, its date switch and Remove.
struct AddedMomentRow: View {
    let moment: AddedMoment
    @Binding var showDate: Bool
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(AppFont.body)
                    .foregroundStyle(Color.teal)
                    .accessibilityHidden(true)
                Text("From \(moment.sourceLabel)")
                    .font(AppFont.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Remove") { remove() }
                    .quickHelp("Takes this moment out of the video at the next Make Again.", article: "editorial-direction")
            }
            Text("\(Format.timecode(moment.seconds)) long, after \(Format.timecode(moment.after)). Added by you.")
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
            Toggle("Show its date on screen", isOn: $showDate)
                .toggleStyle(.checkbox)
                .font(AppFont.body)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }
}
