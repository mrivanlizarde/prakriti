import AppKit
import SwiftData
import SwiftUI

// What each recording makes, and the steps of its last make: moved from v1's recording page into the
// inspector when the Viewer retired the page (v2 part M3b). Every v1 function stays reachable.

/// Which outputs this recording makes: its folder's choices, or its own once one is changed here.
/// Make Again sits here, below the choices it uses.
struct RecordingOutputsSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let defaults = model.defaultSettings()
        Section {
            RowNote(followLine)
            ForEach(OutputKind.built, id: \.self) { kind in
                OutputToggle(kind: kind, isOn: Binding(
                    get: { OutputResolver.isOn(kind, recording: recording, source: nil, defaults: defaults) },
                    set: { model.setOutput(kind, on: $0, for: recording) }))
            }
            if !recording.hasOwnOutputs {
                if OutputResolver.isOn(.podcastEpisode, recording: recording, source: nil, defaults: defaults),
                   let podcast = OutputResolver.details(for: .podcastEpisode, recording: recording, defaults: defaults) {
                    StackedValue(label: "Episode settings", value: Format.episodeSettings(podcast))
                }
                if OutputResolver.isOn(.transcript, recording: recording, source: nil, defaults: defaults),
                   let transcript = OutputResolver.details(for: .transcript, recording: recording, defaults: defaults) {
                    StackedValue(label: "Transcript settings", value: Format.transcriptSettings(transcript))
                }
            }
            // Stacked, not side by side: the inspector is 320 to 440 pt wide.
            VStack(alignment: .leading, spacing: 8) {
                if recording.hasOwnOutputs {
                    Button(recording.source == nil ? "Use the Standard Choices" : "Use the Folder's Choices") { model.useStandardOutputs(recording) }
                } else {
                    Button("Change Settings for This Recording") { model.giveOwnOutputs(recording) }
                }
                if model.canMakeAgain(recording) {
                    Button("Make Again…") { model.ask(.makeAgain, for: recording) }
                }
            }
        } header: {
            SectionHeader("Outputs for this recording")
        }
    }

    private var followLine: String {
        if recording.hasOwnOutputs {
            return "This recording has its own choices. Changes to its folder and in Settings, Outputs do not reach it."
        }
        if let source = recording.source {
            return "Made as the \(source.name) folder is set, with the settings in Settings, Outputs. Change a switch to give this recording its own choices."
        }
        return "Made with the standard choices in Settings, Outputs. Change a switch to give this recording its own choices."
    }

}


/// The settings of what this recording makes, once it has its own choices: only those it makes are shown.
struct RecordingOwnSettingsSections: View {
    @Bindable var recording: Recording

    var body: some View {
        if let podcast = recording.outputSettings.first(where: { $0.kind == .podcastEpisode && $0.isOn }) {
            Section {
                PodcastSettingsRows(setting: podcast)
            } header: {
                SectionHeader("Episode settings for this recording")
            }
        }
        if let transcript = recording.outputSettings.first(where: { $0.kind == .transcript && $0.isOn }) {
            Section {
                TranscriptSettingsRows(setting: transcript, wordListIsBelow: false)
            } header: {
                SectionHeader("Transcript settings for this recording")
            }
        }
        if let ready = recording.outputSettings.first(where: { $0.kind == .podcastReady && $0.isOn }) {
            Section {
                PodcastReadySettingsRows(setting: ready, showsShow: false)
            } header: {
                SectionHeader("Podcast-ready settings for this recording")
            }
        }
    }
}

/// One step of a run: its state, its name, how long it took, and what it found.
struct StepRow: View {
    let step: RunStep
    var showsState = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: step.state.symbol)
                .font(AppFont.body)
                .foregroundStyle(step.state.tint)
                .frame(width: Metrics.symbolWidth)
                .accessibilityLabel(step.state.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name)
                    .font(AppFont.body)
                if let detail = step.detail {
                    Text(detail)
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if showsState || step.seconds != nil {
                Text(step.seconds.map { Format.length($0) } ?? step.state.title)
                    .font(AppFont.numbers)
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}
