import SwiftUI

// The People tab's choices (v2 part M6c, design spec 3.5.2): under each person a pop-up, Include, Hide Face or Leave
// Out (a voice with no face: Include or Leave Out), the line that says what it does to the podcast, and Play Their
// Moments; then Set All Unnamed To, the names said aloud with Keep and Mute, what to listen to, and whether the
// choices are in the episode yet. Every change can be undone (Edit > Undo) and waits for Make Again.

/// Undo and Redo for a change of choices: the choices before go back on Undo, the ones after on Redo.
@MainActor
func registerChoiceUndo(_ undo: UndoManager?, model: AppModel, recording: Recording, before: PeopleChoices, name: String) {
    let after = recording.choices
    guard before != after, let undo else { return }
    undo.registerUndo(withTarget: model) { model in
        model.restoreChoices(before, in: recording)
        registerChoiceUndo(undo, model: model, recording: recording, before: after, name: name)
    }
    undo.setActionName(name)
}

/// One person's choice, what it does to the podcast, and Play Their Moments.
struct ChoiceControls: View {
    let recording: Recording
    let key: PersonKey
    /// The person has a face in the picture: Hide Face is offered.
    let hasFace: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    @State private var next = 0

    var choice: PersonChoice { recording.choices.overall(key).choice }

    var consequence: String {
        let label = recording.label(for: key)
        let voices = recording.voiceIDs(for: key)
        switch choice {
        case .include:
            return voices.isEmpty ? "Not heard in the recording." : "In the podcast as recorded."
        case .hideFace:
            return voices.isEmpty ? "Not heard, so the podcast does not change. Their face is hidden in the recording's picture."
                                  : "The podcast keeps their voice. Their face is hidden in the recording's picture."
        case .leaveOut:
            return LeaveOut.consequence(label: label, seconds: model.choiceFigures.removed(voices: voices, in: recording, folders: model.peopleFolders))
        }
    }

    var body: some View {
        let options = hasFace ? PersonChoice.allCases : PersonChoice.forVoice
        VStack(alignment: .leading, spacing: 4) {
            Picker("Choice", selection: Binding(get: { choice }, set: { set($0) })) {
                ForEach(options, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .font(AppFont.body)
            .accessibilityLabel("Choice for \(recording.label(for: key))")
            Text(consequence)
                .font(AppFont.secondary)
                .foregroundStyle(choice == .leaveOut ? AnyShapeStyle(AppColor.accentText) : AnyShapeStyle(.appSecondary))
                .fixedSize(horizontal: false, vertical: true)
            let moments = model.choiceFigures.moments(voices: recording.voiceIDs(for: key), in: recording, folders: model.peopleFolders)
            if !moments.isEmpty {
                Button(moments.count == 1 || next == 0 ? "Play Their Moments" : "Play the Next Moment") {
                    model.play(recording, at: moments[next % moments.count])
                    next = (next + 1) % moments.count
                }
                .font(AppFont.secondary)
            }
        }
    }

    func set(_ new: PersonChoice) {
        let before = model.setChoice(new, for: key, in: recording)
        registerChoiceUndo(undoManager, model: model, recording: recording, before: before, name: "Choice")
    }
}

/// Set All Unnamed To, at the bottom of the list (design spec 3.5.2 item 4).
struct SetAllUnnamed: View {
    let recording: Recording
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let keys = recording.unnamedKeys
        if keys.count >= 1 {
            HStack {
                Text("Set All Unnamed To").font(AppFont.body)
                Spacer(minLength: 8)
                Menu {
                    ForEach(PersonChoice.allCases, id: \.self) { choice in
                        Button(choice.title) {
                            let before = model.setAllUnnamed(choice, in: recording)
                            registerChoiceUndo(undoManager, model: model, recording: recording, before: before, name: "Set All Unnamed")
                        }
                    }
                } label: {
                    Text(summary(keys)).font(AppFont.body)
                }
                .menuStyle(.button)
                .fixedSize()
                .accessibilityLabel("Set All Unnamed To")
            }
        }
    }

    func summary(_ keys: [PersonKey]) -> String {
        let choices = Set(keys.map { recording.choices.overall($0).choice })
        return choices.count == 1 ? choices.first!.title : "Mixed"
    }
}

/// The names said aloud, one row per name with every time it is said, Keep and Mute, and Play.
struct NamesSaidSection: View {
    let recording: Recording
    let names: NamesSaid
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Section {
            RowNote(names.moments.isEmpty
                    ? "No name is said aloud, other than the people you named."
                    : "Prakriti found these names in the transcript. Keep each one, or Mute it: a muted name is silenced in the podcast and "
                      + "written as \(EpisodeTranscript.mutedWord) in its captions and transcript. Approve waits until each is decided. "
                      + "Prakriti can miss a name, so listen too.")
            ForEach(names.byName, id: \.name) { group in
                NameRow(recording: recording, name: group.name, moments: group.moments)
            }
            let undecided = recording.undecidedNames
            if undecided.count > 1 {
                Button("Keep All Not Decided") {
                    let before = model.decideName(.keep, moments: undecided, in: recording)
                    registerChoiceUndo(undoManager, model: model, recording: recording, before: before, name: "Keep All")
                }
                .font(AppFont.body)
            }
        } header: {
            SectionHeader("Names Said Aloud")
        }
    }
}

struct NameRow: View {
    let recording: Recording
    let name: String
    let moments: [NameMoment]
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager

    var decision: NameDecision? {
        let decisions = Set(moments.map { recording.choices.name($0) })
        return decisions.count == 1 ? decisions.first ?? nil : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(name)\u{201D}, said " + (moments.count == 1 ? "at " : "\(Format.count(moments.count, "time")): ")
                 + moments.prefix(6).map { Format.timecode($0.start) }.joined(separator: ", ") + (moments.count > 6 ? " and more." : "."))
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Picker("Name", selection: Binding(get: { decision }, set: { if let new = $0 { decide(new) } })) {
                    if decision == nil { Text("Not Decided").tag(NameDecision?.none) }
                    Text("Keep").tag(NameDecision?.some(.keep))
                    Text("Mute").tag(NameDecision?.some(.mute))
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .font(AppFont.body)
                .accessibilityLabel("Keep or Mute \(name)")
                Button("Play") { model.play(recording, at: moments[0].start) }
                    .font(AppFont.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    func decide(_ new: NameDecision) {
        let before = model.decideName(new, moments: moments, in: recording)
        registerChoiceUndo(undoManager, model: model, recording: recording, before: before, name: new == .mute ? "Mute" : "Keep")
    }
}

/// What to listen to before approving, whether the choices are in the episode yet, and what the audio output check
/// found.
struct ChoiceStatusSection: View {
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let applied = recording.peopleApplied
        let pending = recording.choicesPending
        let voices = recording.voices
        let leaving = voices.map { !recording.choices.leftOutVoices($0, names: recording.resolvedNameTable).isEmpty } ?? false
        if pending || applied != nil || (leaving && voices?.source == .diarizer) {
            Section {
                if pending {
                    Label {
                        Text("Your choices are not in the episode yet. Make it again to put them in.").font(AppFont.body)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(AppColor.accentText)
                    }
                    if model.canMakeAgain(recording) {
                        Button("Make Again\u{2026}") { model.ask(.makeAgain, for: recording) }.font(AppFont.body)
                    }
                }
                if let applied, !pending {
                    RowNote(appliedLine(applied.leaveOut))
                    if let check = applied.check {
                        Label {
                            Text(check.line { recording.label(forVoice: $0) }).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: check.passed ? "checkmark.circle" : "xmark.octagon")
                                .foregroundStyle(check.passed ? AnyShapeStyle(.appSecondary) : AnyShapeStyle(AppColor.problemText))
                        }
                        if let first = check.findings.first, first.how != "could not be checked for" {
                            Button("Play It") { model.play(recording, at: originalTime(first)) }.font(AppFont.secondary)
                        }
                    }
                    ForEach(Array(applied.leaveOut.overlaps.prefix(5).enumerated()), id: \.offset) { _, stretch in
                        HStack {
                            RowNote("Two people speak at once from \(Format.timecode(stretch.start)) to \(Format.timecode(stretch.end)): cut, so the person included loses those words too.")
                            Spacer(minLength: 8)
                            Button("Play") { model.play(recording, at: stretch.start) }.font(AppFont.secondary)
                        }
                    }
                }
                if leaving, let voices, voices.source == .diarizer, !voices.listen.isEmpty {
                    Toggle(isOn: Binding(get: { !recording.needsListening }, set: { model.setListened($0, in: recording) })) {
                        Text("I listened to the changes of voice").font(AppFont.body)
                    }
                    .toggleStyle(.checkbox)
                    HStack(spacing: 8) {
                        ForEach(Array(voices.listen.prefix(6).enumerated()), id: \.offset) { _, moment in
                            Button(Format.timecode(moment)) { model.play(recording, at: moment) }.font(AppFont.secondary)
                        }
                    }
                }
            } header: {
                SectionHeader("In the Episode")
            }
        }
    }

    func appliedLine(_ leaveOut: LeaveOut) -> String {
        var parts: [String] = []
        if !leaveOut.voices.isEmpty {
            let who = leaveOut.voices.map { recording.label(forVoice: $0) }.joined(separator: " and ")
            parts.append(leaveOut.cuts.isEmpty ? "\(who) left out, not heard in it." : "\(who) left out: \(Format.length(leaveOut.removedSeconds)) taken out, in \(Format.count(leaveOut.cuts.count, "place")).")
        }
        if !leaveOut.mutes.isEmpty { parts.append("\(Format.count(leaveOut.mutes.count, "name")) said aloud muted.") }
        return parts.isEmpty ? "Everyone is in the episode." : parts.joined(separator: " ")
    }

    /// A finding's moment on the original's clock, to play it in the Original.
    func originalTime(_ finding: AudioCheck.Finding) -> Double {
        recording.episodeClock?.originalTime(finding.at) ?? finding.at
    }
}
