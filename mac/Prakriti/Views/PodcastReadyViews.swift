import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// How the podcast-ready episode is made and named: the show, its artwork (checked against Apple's
/// rules as soon as it is chosen), its host, explicit, how episodes are numbered, the call to action
/// that closes the show notes, the layout and bitrate, light noise reduction and the AI voice
/// disclosure. Shared by the Outputs screen and a recording's own settings. Nothing here is ever
/// filled in by Prakriti: an empty show name or call to action stays empty.
struct PodcastReadySettingsRows: View {
    @Bindable var setting: OutputSetting
    /// The Outputs screen shows the show's own settings (name, artwork, host, numbering, call to
    /// action); a recording's page does not, because they belong to the show (`OutputResolver.podcastReady`).
    var showsShow = true

    var body: some View {
        Group {
            RowNote("Made with its own chain: a high-pass at 70 Hz, a gentle compressor, raised evenly to Apple's -16 LUFS, peaks at or under -1 dBTP. "
                    + "It uses the podcast episode's silence trim, intro and outro, and each recording's own trim and cuts.")
            if showsShow {
                showRows
            } else {
                RowNote("The show's name, host, artwork, numbering and call to action are set once, on the Outputs screen, for every episode.")
            }
            Toggle(isOn: $setting.explicitContent) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explicit").font(AppFont.body)
                    Text("Apple asks this for every episode. Off means No.").font(AppFont.secondary).foregroundStyle(.secondary)
                }
            }
            soundRows
        }
    }

    /// What the show is: set once, on the Outputs screen.
    @ViewBuilder
    private var showRows: some View {
        TextRow(label: "Show name", detail: "Written into the MP3 as its album, and its file name.", text: $setting.showName)
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
        TextRow(label: "Host or author", detail: "Written into the MP3 as its artist.", text: $setting.hostName)
        LabeledContent {
            Picker("Numbering", selection: $setting.numberingRaw) {
                ForEach(PodcastNumbering.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
            }
            .labelsHidden()
            .fixedSize()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Numbering").font(AppFont.body)
                Text(numberingLine).font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        CallToActionRow(text: $setting.callToAction)
    }

    /// How the episode sounds, and the AI voice line: the episode's own.
    @ViewBuilder
    private var soundRows: some View {
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

    private var artworkCheck: ArtworkCheck? {
        setting.artworkPath.map { ArtworkCheck.check(URL(fileURLWithPath: $0)) }
    }

    private var numberingLine: String {
        switch setting.numbering {
        case .none: "Apple asks for numbers only for a serial show. Numbers typed on a recording's page are still written."
        case .episodes: "Each episode needs its number, typed on its page; until then the checklist says MISSING."
        case .seasons: "Each episode needs its number and season, typed on its page; until then the checklist says MISSING."
        }
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

/// Ivan's closing line for the show notes, typed in his words. Prakriti never writes one.
struct CallToActionRow: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Call to action").font(AppFont.body)
            TextField("Call to action", text: $text, prompt: Text("None"), axis: .vertical)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(AppFont.body)
                .lineLimit(1...4)
            Text(detail)
                .font(AppFont.secondary).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        var line = "One line that closes the show notes, in your words, such as where to learn more. Empty means none. Prakriti never writes one, "
            + "and nothing else it writes mentions prices or enrollment."
        if text.contains("\u{2014}") || text.contains("\u{2013}") { line += " The dash becomes a comma in the files." }
        return line
    }
}

/// Puts text on a pasteboard: the system's, or a test's own (so a test never touches Ivan's clipboard).
enum Pasteboard {
    @MainActor
    static func copy(_ text: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

/// A recording's podcast-ready episode as the thing to upload (11 Oct): whether it is ready, the
/// files the host takes, the words to paste with a Copy button each (the title, the one-line summary,
/// the show notes with chapters and the call to action, a caption per platform and its pull quote),
/// the whole upload checklist with each line's PASS, MISSING or FAIL in words, the episode and season
/// numbers, and Update Podcast-Ready Files. A class says why it is never made ready.
struct PodcastReadySection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let ready = recording.podcastReady
        Section {
            if let refusal = PodcastPackage.refusal(kind: recording.kind) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not made ready to upload").font(AppFont.headline)
                        Text(refusal + " Its episode and transcript are made as usual, for your own listening.")
                            .font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                        if ready != nil {
                            Text("Files made before it was marked a class are still in its folder. They must not be uploaded; Make Again takes them away.")
                                .font(AppFont.secondary).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } icon: {
                    Image(systemName: "nosign").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            } else if let ready, let folder = folderURL {
                let settings = model.podcastReadySettings(for: recording)
                let copy = PodcastPackage.copy(settings: settings, facts: recording.podcastFacts, written: recording.written,
                                               chapters: PodcastPackage.chapters(recording.written?.chapters ?? [], duration: ready.duration).chapters)
                verdict(ready, folder: folder)
                filesRows(ready)
                wordsRows(copy)
                checklistRows(ready, folder: folder)
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
            if recording.kind != .lesson {
                numbersRow
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
            }
        } header: {
            SectionHeader("Ready to upload")
        }
    }

    // MARK: Parts

    /// "Not ready to upload yet: 6 missing, 0 failed" or "Ready to upload", and Show in Finder.
    private func verdict(_ ready: PodcastReadyRecord, folder: URL) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ready.failed + ready.missing == 0 ? "Ready to upload" : "Not ready to upload yet").font(AppFont.headline)
                Text(ready.failed + ready.missing == 0
                     ? "Every line of the checklist passes. Nothing is uploaded until you do it."
                     : "\(ready.failed) FAIL, \(ready.missing) MISSING, \(ready.passed) PASS. What is left is listed at the end of this section.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([folder.appending(path: ready.fileName)])
            }
        }
        .padding(.vertical, 4)
    }

    /// Every file in the Podcast-ready folder, with its size, and the sound and format in one line each.
    private func filesRows(_ ready: PodcastReadyRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Files").font(AppFont.headline)
            Text("In \(model.paths.display(folderURL?.path ?? "")).").font(AppFont.secondary).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if files(ready).isEmpty {
                Text("The files are not in their folder any more. Make Again makes them.").font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(files(ready), id: \.name) { file in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(file.name).font(AppFont.body).textSelection(.enabled)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 12)
                    // Decimal megabytes, as the checklist's File size line counts them.
                    Text(Self.role(file.name, mp3: ready.fileName) + ", "
                         + (file.bytes >= 1_000_000 ? Format.megabytes(file.bytes) : String(format: "%.0f KB", Double(file.bytes) / 1000)))
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            Text(String(format: "%@ MP3, %d kbps, %.1f kHz, %@: %.2f LUFS, true peak %.2f dBTP, loudness range %.1f LU, %@.",
                        ready.channels == 1 ? "Mono" : "Stereo", ready.bitrateKbps, Double(ready.sampleRate) / 1000, Format.timecode(ready.duration),
                        ready.integratedLUFS, ready.truePeak, ready.loudnessRange, ready.normalizationType == "linear" ? "raised evenly" : "leveled moment to moment"))
                .font(AppFont.secondary).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    /// The words to paste into the host's form and the social posts, each with a Copy button.
    @ViewBuilder
    private func wordsRows(_ copy: EpisodeCopy) -> some View {
        if let title = copy.title {
            CopyRow(label: "Title", detail: copy.titleChosen ? "Yours" : "The writer's first pick, not chosen yet", text: title)
        }
        if let one = copy.oneLine {
            CopyRow(label: "One-line summary", detail: Format.count(one.count, "character"), text: one)
        }
        if let notes = copy.showNotes {
            CopyRow(label: "Show notes", detail: (copy.notesChosen ? "Yours" : "A draft") + (copy.chapters.isEmpty ? "" : ", with the chapters")
                        + (copy.callToAction == nil ? "" : " and your call to action"), text: notes)
        }
        ForEach(copy.captions, id: \.platform) { caption in
            CopyRow(label: caption.platform.title,
                    detail: caption.platform == .x ? "\(caption.text.count) of \(caption.platform.limit) characters" : Format.count(caption.text.count, "character"),
                    text: caption.post)
            if let quote = caption.pullQuote {
                CopyRow(label: "Pull quote", detail: "for \(caption.platform.title)" + (caption.pullQuoteAt.map { ", at \(WritingText.stamp($0))" } ?? "") + ", word for word",
                        text: "\u{201C}\(quote)\u{201D}", copied: quote, emphasis: false)
            }
        }
        if copy.captions.isEmpty && !copy.plainCaptions.isEmpty {
            RowNote("These captions were written before there was one per platform; Write Again makes one each for Instagram, LinkedIn and X and Threads, with pull quotes.")
            ForEach(Array(copy.plainCaptions.enumerated()), id: \.offset) { index, caption in
                CopyRow(label: "Caption \(index + 1)", text: caption)
            }
        }
        if copy.title == nil && copy.showNotes == nil && copy.captions.isEmpty {
            RowNote("No title, show notes or captions yet. Write them with Write Titles and Notes, above.")
        }
    }

    /// The whole checklist: what is left first, each with what to do, then what passes.
    private func checklistRows(_ ready: PodcastReadyRecord, folder: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Upload checklist").font(AppFont.headline)
                Spacer(minLength: 12)
                Button("Open Checklist") { NSWorkspace.shared.open(folder.appending(path: PodcastPackage.checklistName)) }
            }
            let ordered = ready.checklist.filter { $0.status != .pass } + ready.checklist.filter { $0.status == .pass }
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, line in
                ChecklistRow(line: line)
            }
        }
        .padding(.vertical, 4)
    }

    private var numbersRow: some View {
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
                Text(numbersLine).font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var numbersLine: String {
        let numbering = model.podcastReadySettings(for: recording).numbering
        let highest = model.highestEpisodeNumber(excluding: recording).map { " The highest number so far is \($0)." } ?? ""
        switch numbering {
        case .none: return "Optional: the show is not numbered (Outputs screen)." + highest
        case .episodes: return "The show is numbered (Outputs screen), so each episode needs its number." + highest
        case .seasons: return "The show has seasons (Outputs screen), so each episode needs its number and season." + highest
        }
    }

    private var folderURL: URL? {
        recording.outputFolder.map { URL(fileURLWithPath: $0).appending(path: PodcastPackage.folderName) }
    }

    /// The files as the make recorded them; for a record made before 11 Oct, the folder as it is.
    private func files(_ ready: PodcastReadyRecord) -> [PodcastReadyRecord.PackageFile] {
        if let files = ready.files, !files.isEmpty { return files }
        guard let folder = folderURL else { return [] }
        return Pipeline.madeFiles(in: folder).map { name in
            PodcastReadyRecord.PackageFile(name: name, bytes: ((try? FileManager.default.attributesOfItem(atPath: folder.appending(path: name).path))?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    /// What each file is for, in a word or two.
    static func role(_ name: String, mp3: String) -> String {
        if name == mp3 { return "the episode" }
        if name == PodcastPackage.checklistName { return "the checklist" }
        if name == PodcastPackage.textName { return "the words, plain text" }
        if name == PodcastPackage.markdownName { return "the words, Markdown" }
        if name.hasSuffix(".srt") { return "captions for the host" }
        if name.hasSuffix(".vtt") { return "captions for the web" }
        return "a file"
    }
}

/// Words to paste somewhere else, with a Copy button that says Copied for a moment.
struct CopyRow: View {
    let label: String
    var detail: String?
    let text: String
    /// What the button copies, when it is not the text shown (a pull quote without its marks).
    var copied: String?
    var emphasis = true
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).font(emphasis ? AppFont.headline : AppFont.body)
                if let detail {
                    Text(detail).font(AppFont.secondary).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 12)
                Button(didCopy ? "Copied" : "Copy") {
                    Pasteboard.copy(copied ?? text)
                    didCopy = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        didCopy = false
                    }
                }
                .accessibilityLabel("Copy \(label)")
            }
            Text(text)
                .font(AppFont.body)
                .foregroundStyle(emphasis ? .primary : .secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

/// One checklist line: its status in words (PASS, MISSING or FAIL), what it is, the measured detail,
/// and what to do when it does not pass.
struct ChecklistRow: View {
    let line: ChecklistLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(line.status.rawValue)
                .font(AppFont.secondaryEmphasis)
                .foregroundStyle(line.status == .pass ? .secondary : .primary)
                .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.item).font(AppFont.body)
                Text(line.detail + (line.todo.map { " What to do: " + $0 } ?? ""))
                    .font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
