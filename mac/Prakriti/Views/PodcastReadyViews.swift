import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// How the podcast-ready episode is made and named: the show, its host, its artwork (checked
/// against Apple's rules as soon as it is chosen), explicit, the layout and bitrate, light noise
/// reduction and the AI voice disclosure. Shared by the Outputs screen and a recording's own
/// settings. Nothing here is ever filled in by Prakriti: an empty show name stays empty.
struct PodcastReadySettingsRows: View {
    @Bindable var setting: OutputSetting

    var body: some View {
        Group {
            RowNote("Made with its own chain: a high-pass at 70 Hz, a gentle compressor, raised evenly to Apple's -16 LUFS, peaks at or under -1 dBTP. "
                    + "It uses the podcast episode's silence trim, intro and outro, and each recording's own trim and cuts.")
            TextRow(label: "Show name", detail: "Written into the MP3 as its album, and its file name.", text: $setting.showName)
            TextRow(label: "Host or author", detail: "Written into the MP3 as its artist.", text: $setting.hostName)
            FileChoiceRow(label: "Show artwork", detail: artworkLine, path: $setting.artworkPath, contentTypes: [.jpeg, .png])
            if let problems = artworkCheck?.problems, !problems.isEmpty {
                ForEach(problems, id: \.self) { problem in
                    Label {
                        Text(problem).font(AppFont.secondary).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "xmark.octagon").font(AppFont.secondary)
                    }
                }
            }
            Toggle(isOn: $setting.explicitContent) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explicit").font(AppFont.body)
                    Text("Apple asks this for every episode. Off means No.").font(AppFont.secondary).foregroundStyle(.secondary)
                }
            }
            LabeledContent {
                Picker("Channels", selection: Binding(get: { setting.channelsRaw }, set: { raw in
                    setting.channelsRaw = raw
                    let offered = PodcastReadySettings.bitrates(setting.channels)
                    if !offered.contains(setting.bitrateKbps) { setting.bitrateKbps = offered.contains(PodcastMastering.defaultBitrate) ? PodcastMastering.defaultBitrate : offered[0] }
                })) {
                    ForEach(AudioChannels.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Channels").font(AppFont.body)
                    Text("One microphone, so mono loses nothing and halves the file.").font(AppFont.secondary).foregroundStyle(.secondary)
                }
            }
            LabeledContent {
                Picker("Bitrate", selection: $setting.bitrateKbps) {
                    ForEach(PodcastReadySettings.bitrates(setting.channels), id: \.self) { Text("\($0) kbps").tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bitrate").font(AppFont.body)
                    Text(setting.channels == .mono
                         ? "Measured: 96 kbps has 5 dB less coding noise than 64, which also pushed the peak over -1; 128 adds a third to the file for 1.5 dB less."
                         : "128 kbps for stereo, the start of Apple's recommended range.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Toggle(isOn: $setting.noiseReduction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Light noise reduction").font(AppFont.body)
                    Text("Off: the studio's room sound sits 38 to 51 dB under the voice, and noise reduction can smear a voice. For a noisier room only; listen after.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Toggle(isOn: $setting.aiVoice) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The intro or outro has an AI-made voice").font(AppFont.body)
                    Text("Apple asks for that to be said (guideline 1.11). On, the show notes text says so and the checklist asks you to say it in the audio.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var artworkCheck: ArtworkCheck? {
        setting.artworkPath.map { ArtworkCheck.check(URL(fileURLWithPath: $0)) }
    }

    private var artworkLine: String {
        guard let check = artworkCheck else { return "Square JPEG or PNG, 1400 to 3000 px, RGB, under 512 KB. Prakriti never makes artwork." }
        return check.passes ? "\(check.line): passes Apple's rules." : "\(check.line): does not pass, so it is not put in the MP3."
    }
}

/// A labelled text field for a setting, written from the left.
struct TextRow: View {
    let label: String
    var detail: String?
    @Binding var text: String

    var body: some View {
        LabeledContent {
            TextField(label, text: $text, prompt: Text("Not set"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(AppFont.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 320)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AppFont.body)
                if let detail { Text(detail).font(AppFont.secondary).foregroundStyle(.secondary) }
            }
        }
    }
}

/// A whole number typed in a field ("Not set" when empty), applied on Return or when the field is left.
struct NumberField: View {
    let label: String
    let value: Int?
    let apply: (Int?) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(label, text: $text, prompt: Text("Not set"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(AppFont.body)
            .frame(width: 96)
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { if !focused { commit() } }
            .onAppear { text = value.map(String.init) ?? "" }
            .onChange(of: value) { text = value.map(String.init) ?? "" }
            .accessibilityLabel(label)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let number = Int(trimmed).flatMap { $0 > 0 ? $0 : nil }
        if trimmed.isEmpty || number != nil { apply(number) } else { text = value.map(String.init) ?? "" }
    }
}

/// A recording's podcast-ready episode: the file, what was measured, what the checklist still
/// needs, the episode and season numbers, and Update Podcast-Ready Files for a new title, notes or
/// show settings (the audio is not made again).
struct PodcastReadySection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let ready = recording.podcastReady
        Section {
            if let ready, let folder = folderURL {
                LabeledContent {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder.appending(path: ready.fileName)])
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ready.fileName).font(AppFont.body).textSelection(.enabled)
                        Text("In \(model.paths.display(folder.path)), with its captions, \(PodcastPackage.textName) and \(PodcastPackage.checklistName).")
                            .font(AppFont.secondary).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ValueRow(label: "Sound", value: String(format: "%.1f LUFS, true peak %.2f dBTP, range %.1f LU", ready.integratedLUFS, ready.truePeak, ready.loudnessRange)
                         + (ready.normalizationType == "linear" ? ", raised evenly" : ", leveled moment to moment"))
                ValueRow(label: "File", value: "\(ready.channels == 1 ? "Mono" : "Stereo") MP3, \(ready.bitrateKbps) kbps, \(String(format: "%.1f", Double(ready.sampleRate) / 1000)) kHz, "
                         + "\(Format.timecode(ready.duration)), \(Format.megabytes(ready.bytes))")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Upload checklist").font(AppFont.headline)
                        Spacer(minLength: 12)
                        Button("Open Checklist") { NSWorkspace.shared.open(folder.appending(path: PodcastPackage.checklistName)) }
                    }
                    Text(ready.failed + ready.missing == 0 ? "Every line passes." : "\(ready.summary). Still to do:")
                        .font(AppFont.body)
                    ForEach(Array(ready.checklist.filter { $0.status != .pass }.enumerated()), id: \.offset) { _, line in
                        ChecklistRow(line: line)
                    }
                }
                .padding(.vertical, 4)
            } else if let problem = recording.podcastReadyProblem {
                Label {
                    Text("Not made on the last try. \(problem)").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
            } else {
                Text("Not made yet. Turn on Podcast-ready episode under Outputs for this recording, then Make Again.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent {
                HStack(spacing: 8) {
                    Text("Episode").font(AppFont.secondary).foregroundStyle(.secondary)
                    NumberField(label: "Episode number", value: recording.episodeNumber) { model.setEpisodeNumbers(episode: $0, season: recording.seasonNumber, for: recording) }
                    Text("Season").font(AppFont.secondary).foregroundStyle(.secondary)
                    NumberField(label: "Season", value: recording.seasonNumber) { model.setEpisodeNumbers(episode: recording.episodeNumber, season: $0, for: recording) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Episode and season").font(AppFont.body)
                    Text("Optional: Apple asks for them only for a serial show.").font(AppFont.secondary).foregroundStyle(.secondary)
                }
            }
            if ready != nil {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.podcastReadyIsOutOfDate(recording)
                         ? "The title, notes or show settings changed since these files were made."
                         : "Up to date with the title, notes and show settings.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button("Update Podcast-Ready Files") { model.updatePodcastReady(recording) }
                        .disabled(!model.canUpdatePodcastReady(recording))
                }
            }
        } header: {
            SectionHeader("Podcast-ready episode")
        }
    }

    private var folderURL: URL? {
        recording.outputFolder.map { URL(fileURLWithPath: $0).appending(path: PodcastPackage.folderName) }
    }
}

/// One checklist line that does not pass: its status by shape, what it is, and what to do.
struct ChecklistRow: View {
    let line: ChecklistLine

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(line.item): \(line.status == .fail ? "failed" : "missing")").font(AppFont.body)
                Text(line.detail + (line.todo.map { " " + $0 } ?? ""))
                    .font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: line.status == .fail ? "xmark.octagon" : "circle.dashed").font(AppFont.body)
        }
        .accessibilityElement(children: .combine)
    }
}
