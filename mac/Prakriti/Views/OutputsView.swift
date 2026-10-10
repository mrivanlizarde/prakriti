import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The outputs: what each one is, and how it is made. The settings here apply to every recording
/// that has no settings of its own. Which outputs a folder makes is chosen on Sources; a switch here
/// is the starting choice for a new folder and for a file added by hand.
struct OutputsView: View {
    @Environment(AppModel.self) private var model
    @Query private var settings: [OutputSetting]

    var body: some View {
        let defaults = settings.filter { $0.source == nil && $0.recording == nil }
        Form {
            Section {
                PageIntro(text: "What Prakriti makes from each recording, and how. These settings apply to every recording unless one has its own. Which outputs each folder makes is chosen on Sources.")
            }

            if let podcast = defaults.first(where: { $0.kind == .podcastEpisode }) {
                Section {
                    OutputSwitch(setting: podcast, detail: "An MP3 at podcast loudness, ready to listen to.")
                    PodcastSettingsRows(setting: podcast)
                }
            }
            if let transcript = defaults.first(where: { $0.kind == .transcript }) {
                Section {
                    OutputSwitch(setting: transcript)
                    TranscriptSettingsRows(setting: transcript)
                }
                WordListSection()
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

            Section {
                RowNote("A switch on this screen is the starting choice for a folder you add and for a file you add by hand.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Outputs")
    }

    /// Names the model chosen in Models, read from the settings, never written in by hand.
    private var writerLine: String {
        let provider = model.settings.provider[.writing] ?? .lmStudio
        let writer = provider == .lmStudio ? Format.modelName(model.settings.lmStudioModel) + " in LM Studio" : provider.title
        return "Needs the writing model (\(writer)), which Prakriti does not use yet, so these are not made. Classes, and anything with Serenity in it, will stay on this Mac."
    }
}

/// How the episode is made: loudness, the silence trim, intro and outro, mono or stereo. Shared by
/// the Outputs screen and a recording's own settings. Never greyed out by the switch above it: on
/// the Outputs screen that switch is only the starting choice for new folders, and every folder
/// that makes an episode uses these settings.
struct PodcastSettingsRows: View {
    @Bindable var setting: OutputSetting

    var body: some View {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trim silence at the start and end").font(AppFont.body)
                    Text("Only true silence, keeping half a second before the first word and after the last.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FileChoiceRow(label: "Intro", detail: "Played before the talk, at the talk's loudness.", path: $setting.introPath)
            FileChoiceRow(label: "Outro", detail: "Played after the talk, at the talk's loudness.", path: $setting.outroPath)
            LabeledContent {
                Picker("Channels", selection: $setting.channelsRaw) {
                    ForEach(AudioChannels.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Channels").font(AppFont.body)
                    Text("The studio records one microphone, so mono loses nothing.").font(AppFont.secondary).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Which transcript formats are kept, and the word list. Shared by the Outputs screen and a
/// recording's own settings.
struct TranscriptSettingsRows: View {
    @Bindable var setting: OutputSetting
    /// The Outputs screen shows the word list just below; a recording's page does not.
    var wordListIsBelow = true

    var body: some View {
        Group {
            ForEach(TranscriptFormat.allCases, id: \.self) { format in
                Toggle(isOn: Binding(
                    get: { setting.transcriptFormats.contains(format) },
                    set: { on in
                        var formats = setting.transcriptFormats
                        if on { formats.insert(format) } else { formats.remove(format) }
                        // At least one format stays chosen: a transcript with none would make nothing to read.
                        guard !formats.isEmpty else { return }
                        setting.transcriptFormats = formats
                    })) {
                    Text(format.title).font(AppFont.body)
                }
            }
            Toggle(isOn: $setting.applyLexicon) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use the Yoga Marga word list").font(AppFont.body)
                    Text((wordListIsBelow ? "Fixes the known mis-hearings listed below." : "Fixes the known mis-hearings listed on the Outputs screen.")
                         + " The words as heard are kept too, in transcript.json.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The word list itself: each word as it is written, and how it has been misheard.
struct WordListSection: View {
    var body: some View {
        Section {
            ForEach(Lexicon.entries, id: \.written) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.written).font(AppFont.body)
                    Text(heardLine(entry)).font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 1)
                .accessibilityElement(children: .combine)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Kept as written").font(AppFont.body)
                Text(Lexicon.keptAsWritten.joined(separator: ", ") + ".").font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } header: {
            SectionHeader("The Yoga Marga word list")
        }
    }

    /// "Fixed when heard as yoga market, Yoga Margot, Yokamarga."
    private func heardLine(_ entry: Lexicon.Entry) -> String {
        let misheard = entry.heard.filter { $0.lowercased() != entry.written.lowercased() }
        let shown = misheard.map(Self.asHeard)
        var line = entry.note
        if !shown.isEmpty { line += " Fixed when heard as " + shown.joined(separator: ", ") + "." }
        if misheard.count < entry.heard.count { line += " Wrong capitals are fixed too." }
        return line
    }

    /// A variant as Parakeet tends to write it, each word capitalized ("Yoga Margot"). The list
    /// matches any capitalization, so this is only how it reads on screen.
    static func asHeard(_ variant: String) -> String {
        variant.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// An intro or outro file: its name, Choose, and Remove.
struct FileChoiceRow: View {
    let label: String
    var detail: String?
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
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AppFont.body)
                if let detail {
                    Text(detail).font(AppFont.secondary).foregroundStyle(.secondary)
                }
            }
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

/// An output that is planned but not built: named and described in one line. The section's
/// header says "Not built yet" once, so the rows do not repeat it.
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
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
