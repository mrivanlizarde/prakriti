import SwiftUI

/// The Approve sheet (v2 part M11b, docs/v2/design-spec.md 3.11 and C8): "Approve Sun 13 Sep?", the deliverables with checkboxes,
/// ticked when they pass and unticked and disabled with the failing check named when they do not; the video's version; one line per
/// people decision; moments from other recordings; where each model step ran; the footnote; Cancel and Approve. Approve copies only
/// what is ticked, and is refused (copying nothing) while any ticked deliverable fails, whoever asks (`AppModel.approve`).
struct ApproveSheet: View {
    let request: ApproveRequest
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<String>?

    var body: some View {
        if let recording = model.recording(id: request.recordingID) {
            content(recording)
        } else {
            Text("This recording is not in the library any more.").font(AppFont.body).padding(24)
        }
    }

    @ViewBuilder private func content(_ recording: Recording) -> some View {
        let deliverables = model.approvalDeliverables(recording)
        let ticked = chosen ?? Set(deliverables.filter(\.passes).map(\.id))
        let check = model.approvalCheck(recording)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Approve \(Format.dayLabel(recording.sessionDate))?")
                    .font(AppFont.sectionTitle)
                Spacer()
                Button {
                    model.openHelp(article: "reviewing-and-approving")
                } label: {
                    Image(systemName: "questionmark.circle").font(AppFont.body)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Help: Review and approve")
            }
            .padding([.horizontal, .top], 24)
            Form {
                Section {
                    ForEach(deliverables) { item in
                        DeliverableToggle(item: item, isOn: Binding(get: { ticked.contains(item.id) && item.passes }, set: { on in
                            var next = ticked
                            if on { next.insert(item.id) } else { next.remove(item.id) }
                            chosen = next
                        }))
                    }
                } header: {
                    SectionHeader("Deliverables")
                }
                if let version = model.approvalVersionLine(recording) {
                    Section {
                        Text(version).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    } header: {
                        SectionHeader("Version")
                    }
                }
                Section {
                    ForEach(model.approvalPeopleLines(recording), id: \.self) { line in
                        Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    SectionHeader("People")
                }
                Section {
                    ForEach(model.approvalMomentLines(recording), id: \.self) { line in
                        Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    SectionHeader("Moments from other recordings")
                }
                Section {
                    ForEach(model.approvalModelLines(recording), id: \.self) { line in
                        Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    SectionHeader("Privacy")
                }
            }
            .formStyle(.grouped)
            .frame(width: 600)
            .frame(minHeight: 420, idealHeight: 640)
            VStack(alignment: .leading, spacing: 12) {
                Text("Approving copies these files to Approved and writes a receipt. Nothing is uploaded or posted.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !check.canApprove, let line = check.line {
                    Text(line).font(AppFont.secondary).foregroundStyle(AppColor.problemText).fixedSize(horizontal: false, vertical: true)
                } else if ticked.isEmpty {
                    Text("Choose at least one file to approve.").font(AppFont.secondary).foregroundStyle(AppColor.problemText)
                }
                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Approve") {
                        if model.approve(recording, chosen: ticked) { dismiss() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!check.canApprove || ticked.isEmpty)
                }
            }
            .font(AppFont.body)
            .padding([.horizontal, .bottom], 24)
            .padding(.top, 8)
        }
    }
}

/// One deliverable: a checkbox with its name, one line of what it is, and, when it fails, the failing check in words (never color
/// alone) with the box unticked and disabled.
struct DeliverableToggle: View {
    let item: ApprovalDeliverable
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(item.title).font(AppFont.body)
                } icon: {
                    Image(systemName: item.passes ? item.symbol : "exclamationmark.triangle").font(AppFont.body)
                }
                Text(item.detail)
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let failure = item.failure {
                    Text("Not approved: \(failure)")
                        .font(AppFont.secondary)
                        .foregroundStyle(AppColor.problemText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(item.notes.prefix(2), id: \.self) { note in
                    Text(note).font(AppFont.secondary).foregroundStyle(.appSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.checkbox)
        .disabled(!item.passes)
        .accessibilityElement(children: .combine)
    }
}
