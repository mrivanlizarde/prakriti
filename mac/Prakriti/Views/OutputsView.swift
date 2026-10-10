import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The default choice for every output. A folder (Sources) and a recording can each change them.
struct OutputsView: View {
    @Environment(AppModel.self) private var model
    @Query private var settings: [OutputSetting]

    var body: some View {
        let defaults = settings.filter { $0.source == nil && $0.recording == nil }
        Form {
            Section {
                PageIntro(text: "What Prakriti makes from each recording. These are the starting choices: each folder, and each recording, can change them.")
            }

            if let podcast = defaults.first(where: { $0.kind == .podcastEpisode }) {
                PodcastSettings(setting: podcast)
            }
            if let transcript = defaults.first(where: { $0.kind == .transcript }) {
                TranscriptSettings(setting: transcript)
            }
            if let checks = defaults.first(where: { $0.kind == .checksAndReport }) {
                Section {
                    OutputSwitch(setting: checks, detail: "Checks the length, the sound, the loudness, and that the transcript reaches the end. Says plainly that speakers are not checked yet.")
                }
            }
            if let writing = defaults.first(where: { $0.kind == .titlesNotesChapters }) {
                Section {
                    OutputSwitch(setting: writing, detail: writerLine)
                }
            }

            Section {
                ForEach(OutputKind.notBuilt, id: \.self) { kind in
                    NotBuiltRow(kind: kind)
                }
            } header: {
                SectionHeader("Not built yet")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Outputs")
    }

    private var writerLine: String {
        let provider = model.settings.provider[.writing] ?? .lmStudio
        let model = provider == .lmStudio ? "Qwen3.8-27B in LM Studio" : provider.title
        return "Written by \(model). Classes, and anything with Serenity in it, always stay on this Mac."
    }
}

struct PodcastSettings: View {
    @Bindable var setting: OutputSetting

    var body: some View {
        Section {
            OutputSwitch(setting: setting)
            Group {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(Format.loudnessTarget(setting.loudnessTarget))
                            .font(AppFont.numbers)
                            .foregroundStyle(.secondary)
                        Stepper("Loudness target", value: $setting.loudnessTarget, in: -24 ... -12, step: 1)
                            .labelsHidden()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loudness target").font(AppFont.body)
                        Text("Apple Podcasts asks for -16 LUFS.").font(AppFont.secondary).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $setting.trimSilence) {
                    Text("Trim silence at the start and end").font(AppFont.body)
                }
                FileChoiceRow(label: "Intro", path: $setting.introPath)
                FileChoiceRow(label: "Outro", path: $setting.outroPath)
                LabeledContent {
                    Picker("Channels", selection: $setting.channelsRaw) {
                        ForEach(AudioChannels.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                } label: {
                    Text("Channels").font(AppFont.body)
                }
            }
            .disabled(!setting.isOn)
        }
    }
}

struct TranscriptSettings: View {
    @Bindable var setting: OutputSetting

    var body: some View {
        Section {
            OutputSwitch(setting: setting)
            Group {
                ForEach(TranscriptFormat.allCases, id: \.self) { format in
                    Toggle(isOn: Binding(
                        get: { setting.transcriptFormats.contains(format) },
                        set: { on in
                            var formats = setting.transcriptFormats
                            if on { formats.insert(format) } else { formats.remove(format) }
                            setting.transcriptFormats = formats
                        })) {
                        Text(format.title).font(AppFont.body)
                    }
                }
                Toggle(isOn: $setting.applyLexicon) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use the Yoga Marga word list").font(AppFont.body)
                        Text("Corrects the spelling of Yoga Marga and Sanskrit terms.").font(AppFont.secondary).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!setting.isOn)
        }
    }
}

/// An intro or outro file: its name, Choose, and Remove.
struct FileChoiceRow: View {
    let label: String
    @Binding var path: String?

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(path.map { ($0 as NSString).lastPathComponent } ?? "None")
                    .font(AppFont.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if path != nil {
                    Button("Remove") { path = nil }
                }
                Button("Choose…") { choose() }
            }
        } label: {
            Text(label).font(AppFont.body)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Use This File"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

/// An output that is planned but not built: named, described in one line, and marked.
struct NotBuiltRow: View {
    let kind: OutputKind

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .frame(width: Metrics.symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(AppFont.body)
                Text(kind.summary).font(AppFont.secondary).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text("Not built yet")
                .font(AppFont.secondary)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
