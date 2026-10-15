import SwiftUI

/// The edit plan in the inspector's Outputs tab (v2 part M8a): what the rough cut keeps and takes out, the moments it
/// was not sure about with Play, whether Ivan's newest trim, cuts or choices are in it, and Plan the Edit or Plan Again.
/// The plan is shown on the Original's Timeline-lite; nothing a person could post is made from it in this part.
struct EditPlanSection: View {
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
                Text(plan.summary)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let lines = plan.planLines, !lines.isEmpty {
                    // The plan in plain lines, before anything is made (v2 part M9c, design spec 3.5.3).
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(lines, id: \.self) { line in
                            Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                } else if let picture = plan.pictureSummary {
                    Text(picture)
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                RowNote("Planned \(Format.dayAndTime(plan.madeAt)). The strip under the Original in the Viewer shows it.")
                if let behind = model.planIsBehind(recording, plan: plan) {
                    Label {
                        Text(behind + " Plan Again to include them.").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.circle").font(AppFont.body).foregroundStyle(Color.orange)
                    }
                    .accessibilityElement(children: .combine)
                }
                ForEach(Array(plan.checks.enumerated()), id: \.offset) { _, check in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Label {
                            Text(check.say).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "questionmark.circle").font(AppFont.body)
                        }
                        Spacer(minLength: 8)
                        Button("Play") { play(check, plan: plan) }
                            .quickHelp("Plays the Original from just before this moment, so you can hear what was kept.", article: "reviewing-and-approving")
                    }
                }
            } else {
                Text("Prakriti can plan the rough cut of this recording: long pauses shortened, filler words, words said twice and restarts taken out, with your trim, cuts and choices of who is in the video applied. The plan shows on the strip under the Original in the Viewer; nothing else is made from it yet.")
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
            // In rows that wrap (v2 part M9c): with Make Video beside them, three buttons did not fit the inspector's width and
            // the last read "Show in the..." (seen in 24-direction, 15 Oct).
            FlowLayout(spacing: 10) {
                Button(plan == nil ? "Plan the Edit" : "Plan Again") { model.planEdit(recording) }
                    .disabled(!model.canPlanEdit(recording))
                    .quickHelp("Works out the rough cut from the transcript and the sound, on this Mac, in a few seconds. Nothing is changed or made but the plan.",
                               article: "outputs")
                if plan != nil {
                    // The plan is shown first; Make goes ahead with it (v2 part M9c, the plan before rendering).
                    Button(recording.video == nil ? "Make Video" : "Make Video Again") { model.makeVideo(recording) }
                        .disabled(!model.canMakeVideo(recording))
                        .quickHelp("Makes the video from this plan, through the line like any make. Stop in the progress block ends it. Nothing is uploaded.",
                                   article: "editorial-direction")
                    Button("Show in the Viewer") { model.showPlan(recording) }
                        .quickHelp("Opens the Original in the Viewer, where the strip shows what the plan keeps and takes out.", article: "reviewing-and-approving")
                }
            }
        } header: {
            SectionHeader("Edit plan")
        }
    }

    private func play(_ check: CheckMoment, plan: EditPlan) {
        let at = plan.words.first { $0.id == check.at }?.in ?? 0
        model.play(recording, at: at)
    }
}
