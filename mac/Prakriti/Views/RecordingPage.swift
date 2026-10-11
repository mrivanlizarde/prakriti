import AppKit
import AVFoundation
import AVKit
import SwiftUI

// The parts of a recording's page that milestone 5 adds: the system audio player, the transcript as
// lines that play from their moment, the trim and the cuts, the title, notes and what the recording
// is, and Approve. The player is AVKit's own (AVPlayerView): no drawn scrubber or waveform, ever
// (Ivan's rule: never skeuomorphic; the system's own media controls are fine).

/// One line of the transcript: one of Parakeet's sentences, on the original recording's clock, with
/// the word list applied for reading.
struct TranscriptLine: Identifiable, Equatable, Sendable {
    let id: Int
    /// The sentence's span as Parakeet gives it: from the end of the sentence before (so it takes in
    /// the pause before it) to its last word. Cutting a line cuts this span.
    let start: Double
    let end: Double
    let text: String
    /// Where each word is said (`EpisodeTranscript.position`), so a line's fate follows its words,
    /// not the pause Parakeet counts into the sentence.
    var words: [Double] = []

    /// About when its first word starts: where the time shown and the player go.
    var speechStart: Double { words.first.map { max(start, $0 - 0.15) } ?? start }

    /// Where the line stands against the trim and cuts on the page.
    enum Fate: Equatable { case kept, partlyCut, cut }

    func fate(in parts: [Mastering.Span]) -> Fate {
        func kept(_ t: Double) -> Bool { parts.contains { t >= $0.start && t <= $0.end } }
        if !words.isEmpty {
            let count = words.filter(kept).count
            return count == words.count ? .kept : (count == 0 ? .cut : .partlyCut)
        }
        let length = max(0.001, end - start)
        let keptLength = parts.reduce(0.0) { $0 + max(0, min(end, $1.end) - max(start, $1.start)) }
        if keptLength >= length - 0.05 { return .kept }
        return keptLength <= 0.05 ? .cut : .partlyCut
    }
}

enum RecordingTranscript {
    /// The lines of a made transcript: transcript.json (every word as heard, on the original's
    /// clock) with the word list applied, else the .srt. Empty when neither is there.
    static func lines(folder: String?, applyLexicon: Bool) -> [TranscriptLine] {
        guard let folder else { return [] }
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        if let data = try? Data(contentsOf: url.appending(path: TranscriptFiles.asHeard)),
           let sentences = EpisodeTranscript.sentences(json: data), !sentences.isEmpty {
            return sentences.enumerated().map { index, sentence in
                let text = sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return TranscriptLine(id: index, start: sentence.start, end: sentence.end, text: applyLexicon ? Lexicon.apply(text).text : text,
                                      words: (sentence.tokens ?? []).filter { EpisodeTranscript.isWord($0.text) }
                                        .map { EpisodeTranscript.position(start: $0.start, end: $0.end) })
            }
        }
        if let srt = try? String(contentsOf: url.appending(path: TranscriptFiles.fileName(.srt)), encoding: .utf8) {
            return TranscriptFiles.cues(srt: srt).enumerated().map { TranscriptLine(id: $0.offset, start: $0.element.start, end: $0.element.end, text: $0.element.text) }
        }
        return []
    }
}

/// What the player plays.
enum Listening: String, CaseIterable, Identifiable {
    case episode, original
    var id: String { rawValue }
    var title: String { self == .episode ? "Episode" : "Original" }
}

/// The page's player and transcript, loaded once per make.
@MainActor
@Observable
final class RecordingPage {
    var lines: [TranscriptLine] = []
    var listening: Listening = .episode
    var hasEpisode = false
    var originalNote: String?
    /// The player's own time, in seconds, on the clock of what it plays.
    var time: Double = 0
    var hasPlayed = false
    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var clock: EpisodeClock?
    @ObservationIgnored private var originalPath: String?
    @ObservationIgnored private var originalItem: AVPlayerItem?
    /// A moment to go to once the original has opened (it opens a moment after it is chosen).
    @ObservationIgnored private var pendingSeek: Double?

    init() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.time = time.seconds.isFinite ? time.seconds : 0
                if self.player.rate > 0 { self.hasPlayed = true }
            }
        }
    }

    isolated deinit {
        if let observer { player.removeTimeObserver(observer) }
        player.pause()
    }

    /// Loads the transcript and the episode for this make; again only when a new make lands.
    func load(_ recording: Recording, applyLexicon: Bool) {
        let key = [recording.outputFolder ?? "", recording.madeAt.map { "\($0.timeIntervalSince1970)" } ?? "", recording.madeFiles.joined(separator: ",")].joined(separator: "|")
        clock = recording.episodeClock
        originalPath = recording.filePath
        guard key != loadedKey else { return }
        loadedKey = key
        lines = RecordingTranscript.lines(folder: recording.outputFolder, applyLexicon: applyLexicon)
        let episode = recording.outputFolder.map { URL(fileURLWithPath: $0, isDirectory: true).appending(path: "episode.mp3") }
        hasEpisode = episode.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        originalItem = nil
        if hasEpisode, let episode {
            listening = .episode
            player.replaceCurrentItem(with: AVPlayerItem(url: episode))
        } else {
            listening = .original
            loadOriginal()
        }
        time = 0
        hasPlayed = false
    }

    /// Switches between the episode and the original, keeping the moment that is playing.
    func listen(to choice: Listening, recording: Recording) {
        guard choice != listening else { return }
        let moment = currentOriginal
        listening = choice
        player.pause()
        if choice == .episode, let folder = recording.outputFolder {
            player.replaceCurrentItem(with: AVPlayerItem(url: URL(fileURLWithPath: folder, isDirectory: true).appending(path: "episode.mp3")))
        } else {
            loadOriginal()
        }
        if let moment { seek(original: moment, play: false) }
    }

    /// The original's sound only (its picture is not shown): an audio-only copy of its first sound
    /// track, so the system player draws its controls and nothing else.
    private func loadOriginal() {
        guard let path = originalPath else { return }
        if let originalItem {
            player.replaceCurrentItem(with: originalItem)
            return
        }
        player.replaceCurrentItem(with: nil)
        originalNote = nil
        // The original usually lives in the studio folder, inside ~/Documents: it is looked at off
        // the main thread, because a first read there can wait on a macOS permission prompt and
        // would freeze the window (START_HERE, Mac warning 24).
        Task { [weak self] in
            let url = URL(fileURLWithPath: path)
            let state = await Task.detached { () -> String? in
                guard FileManager.default.fileExists(atPath: path) else { return "The original is not on this Mac any more." }
                if Readiness.isDataless(url) { return "The original is in iCloud and not downloaded to this Mac right now, so it cannot play here." }
                return nil
            }.value
            if let state {
                self?.originalNote = state
                return
            }
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
                  let duration = try? await asset.load(.duration) else {
                self?.originalNote = "The original's sound could not be opened."
                return
            }
            let composition = AVMutableComposition()
            guard let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
                  (try? audio.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)) != nil else {
                self?.originalNote = "The original's sound could not be opened."
                return
            }
            guard let self, self.listening == .original else { return }
            let item = AVPlayerItem(asset: composition)
            self.originalItem = item
            self.player.replaceCurrentItem(with: item)
            if let pending = self.pendingSeek {
                self.pendingSeek = nil
                self.seek(original: pending, play: false)
            }
        }
    }

    /// The moment playing, on the original's clock, or nil inside an intro or outro.
    var currentOriginal: Double? {
        switch listening {
        case .original: time
        case .episode: clock.map { $0.originalTime(time) } ?? time
        }
    }

    /// Plays from a moment of the original: in the episode, from where that moment is (or, when it
    /// was cut, from where the episode carries on).
    func seek(original t: Double, play: Bool = true) {
        if listening == .original && player.currentItem == nil { pendingSeek = t }
        let target = listening == .episode ? (clock?.episodeTime(t).time ?? t) : t
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        time = target
        if play {
            hasPlayed = true
            player.play()
        }
    }

    /// The line playing now, once something has been played.
    func currentLineID() -> Int? {
        guard hasPlayed, let t = currentOriginal else { return nil }
        return lines.last { $0.start <= t + 0.05 }.flatMap { $0.end >= t - 0.05 ? $0.id : nil }
    }
}

/// AVKit's own player view, controls only (the episode has no picture).
struct SystemPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        view.showsSharingServiceButton = false
        // The episode has no picture: no black video area behind the controls.
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}

// MARK: Sections

/// Listen: the episode as made, or the original's sound, in the system player.
struct ListenSection: View {
    @Bindable var recording: Recording
    let page: RecordingPage

    var body: some View {
        Section {
            if page.hasEpisode {
                Picker("Listen to", selection: Binding(get: { page.listening }, set: { page.listen(to: $0, recording: recording) })) {
                    ForEach(Listening.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if page.listening == .original, let note = page.originalNote {
                RowNote(note)
            } else {
                // AVKit draws its inline controls as a pill on a dark band; the band is clipped to
                // the pill, so the page shows the system's own control and nothing drawn by Prakriti.
                SystemPlayerView(player: page.player)
                    .frame(height: 46)
                    .clipShape(Capsule())
                    .accessibilityLabel(page.listening == .episode ? "Episode player" : "Original recording player")
            }
            RowNote(listenLine)
        } header: {
            SectionHeader("Listen")
        }
    }

    private var listenLine: String {
        switch page.listening {
        case .episode:
            recording.editsPending
                ? "This is the episode as last made. Your newest trim and cuts are not in it yet."
                : "This is the episode as made. A line of the transcript plays it from that moment."
        case .original:
            "The original recording's sound, as it was recorded. A line of the transcript plays it from that moment."
        }
    }
}

/// The transcript as lines: click one to play from there; select several (Shift-click) to cut them.
struct TranscriptSection: View {
    @Bindable var recording: Recording
    let page: RecordingPage
    @Environment(AppModel.self) private var model
    @State private var selection = Set<Int>()

    var body: some View {
        Section {
            if page.lines.isEmpty {
                RowNote(recording.wordCount == nil
                        ? "No transcript was made for this recording."
                        : "The transcript's files are not in its folder any more.")
            } else {
                let parts = editedParts
                let playing = page.currentLineID()
                List(page.lines, selection: $selection) { line in
                    TranscriptLineRow(line: line, fate: line.fate(in: parts), isPlaying: line.id == playing)
                        .tag(line.id)
                        .contextMenu {
                            Button("Play From Here") { page.seek(original: line.speechStart) }
                            Button("Cut This Line") {
                                if let problem = model.addCut(TimeRange(start: line.start, end: line.end), to: recording) {
                                    model.notice = Notice(title: "Not cut", message: problem)
                                }
                            }
                        }
                }
                .listStyle(.plain)
                .frame(height: 380)
                .onChange(of: selection) { _, chosen in
                    if chosen.count == 1, let id = chosen.first, let line = page.lines.first(where: { $0.id == id }) {
                        page.seek(original: line.speechStart)
                    }
                }
                HStack(spacing: 12) {
                    RowNote(selectionLine)
                    Spacer(minLength: 12)
                    Button(selection.count > 1 ? "Cut Selected Lines" : "Cut Selected Line") { cutSelection() }
                        .disabled(selectedRange == nil)
                }
            }
        } header: {
            SectionHeader("Transcript")
        }
    }

    private var editedParts: [Mastering.Span] {
        guard let duration = recording.duration else { return [Mastering.Span(start: 0, end: .greatestFiniteMagnitude)] }
        return recording.edits.segments(duration: duration)
    }

    private var selectedRange: TimeRange? {
        let chosen = page.lines.filter { selection.contains($0.id) }
        guard let first = chosen.map(\.start).min(), let last = chosen.map(\.end).max(), last > first else { return nil }
        return TimeRange(start: first, end: last)
    }

    private var selectionLine: String {
        if let range = selectedRange {
            return "Selected: \(TimeText.string(range.start)) to \(TimeText.string(range.end)) (\(Format.length(range.end - range.start)))."
        }
        return "Click a line to play from there. Shift-click to select several, then cut them. Control-click a line for more."
    }

    private func cutSelection() {
        guard let range = selectedRange else { return }
        if let problem = model.addCut(range, to: recording) {
            model.notice = Notice(title: "Not cut", message: problem)
        } else {
            selection = []
        }
    }
}

struct TranscriptLineRow: View {
    let line: TranscriptLine
    let fate: TranscriptLine.Fate
    let isPlaying: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(Format.timecode(line.speechStart))
                .font(AppFont.numbers)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.text)
                    .font(isPlaying ? AppFont.headline : AppFont.body)
                    .foregroundStyle(fate == .kept ? .primary : .secondary)
                    .strikethrough(fate == .cut)
                    .fixedSize(horizontal: false, vertical: true)
                if fate != .kept {
                    Text(fate == .cut ? "Cut from the episode" : "Partly cut from the episode")
                        .font(AppFont.label)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Format.timecode(line.speechStart)). \(line.text)" + (fate == .kept ? "" : fate == .cut ? ". Cut." : ". Partly cut."))
    }
}

/// A time Ivan types (or takes from the player), applied on Return or when the field loses focus.
struct TimeField: View {
    let label: String
    let placeholder: String
    let value: Double?
    let apply: (Double?) -> String?
    let playerTime: () -> Double?
    @State private var text = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(label, text: $text, prompt: Text(placeholder))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.numbers)
                    .frame(width: 110)
                    .focused($focused)
                    .onSubmit(commit)
                Button("Use Player Time") {
                    if let t = playerTime() {
                        text = TimeText.string(t)
                        commit()
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AppFont.body)
                if let problem {
                    Text(problem).font(AppFont.secondary).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { text = value.map(TimeText.string) ?? "" }
        .onChange(of: value) { _, new in text = new.map(TimeText.string) ?? "" }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            problem = apply(nil)
            return
        }
        guard let seconds = TimeText.seconds(trimmed) else {
            problem = "Write a time like 4:12 or 1:02:30."
            return
        }
        problem = apply(seconds)
        if problem != nil { text = value.map(TimeText.string) ?? "" }
    }
}

/// Where the episode starts and ends, and the sections cut out of it.
struct EditsSection: View {
    @Bindable var recording: Recording
    let page: RecordingPage
    @Binding var confirmMakeAgain: Bool
    let canMakeAgain: Bool
    @Environment(AppModel.self) private var model
    @State private var cutFrom = ""
    @State private var cutTo = ""
    @State private var cutProblem: String?

    var body: some View {
        Section {
            RowNote("Times are from the start of the original recording, as the transcript shows them. The episode changes when you make it again.")
            TimeField(label: "Episode starts at", placeholder: "0:00", value: recording.trimStart,
                      apply: { model.setTrim(start: $0, end: recording.trimEnd, for: recording) }, playerTime: { page.currentOriginal })
            TimeField(label: "Episode ends at", placeholder: recording.duration.map(Format.timecode) ?? "the end", value: recording.trimEnd,
                      apply: { model.setTrim(start: recording.trimStart, end: $0, for: recording) }, playerTime: { page.currentOriginal })
            ForEach(recording.cuts, id: \.self) { cut in
                LabeledContent {
                    Button("Remove") { model.removeCut(cut, from: recording) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cut \(TimeText.string(cut.start)) to \(TimeText.string(cut.end))").font(AppFont.body)
                        Text(Format.length(cut.end - cut.start) + " taken out").font(AppFont.secondary).foregroundStyle(.secondary)
                    }
                }
            }
            LabeledContent {
                HStack(spacing: 8) {
                    TextField("Cut from", text: $cutFrom, prompt: Text("4:12"))
                        .labelsHidden().textFieldStyle(.roundedBorder).font(AppFont.numbers).frame(width: 90)
                    Text("to").font(AppFont.body).foregroundStyle(.secondary)
                    TextField("Cut to", text: $cutTo, prompt: Text("4:42"))
                        .labelsHidden().textFieldStyle(.roundedBorder).font(AppFont.numbers).frame(width: 90)
                        .onSubmit(addCut)
                    Button("Add Cut", action: addCut)
                        .disabled(cutFrom.isEmpty || cutTo.isEmpty)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cut a section, from and to").font(AppFont.body)
                    Text(cutProblem ?? "Or select lines in the transcript and cut them.")
                        .font(AppFont.secondary).foregroundStyle(cutProblem == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let line = keptLine {
                ValueRow(label: "The episode keeps", value: line)
            }
            if recording.editsPending {
                Label {
                    Text("Not in the episode yet. Make it again to hear these changes, and before approving.")
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.circle").font(AppFont.body).foregroundStyle(.orange)
                }
            }
            HStack(spacing: 12) {
                Button("Clear Trim and Cuts") { model.clearEdits(recording) }
                    .disabled(recording.edits.isEmpty)
                Spacer()
                if recording.editsPending && canMakeAgain {
                    Button("Make Again…") { confirmMakeAgain = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        } header: {
            SectionHeader("Trim and cuts")
        }
    }

    /// "15:08 of 15:48 (40 s taken out)".
    private var keptLine: String? {
        guard let duration = recording.duration, !recording.edits.isEmpty else { return nil }
        let kept = recording.edits.segments(duration: duration).reduce(0) { $0 + $1.length }
        return "\(Format.timecode(kept)) of \(Format.timecode(duration)) (\(Format.length(duration - kept)) taken out)"
    }

    private func addCut() {
        guard let from = TimeText.seconds(cutFrom), let to = TimeText.seconds(cutTo) else {
            cutProblem = "Write each time like 4:12 or 1:02:30."
            return
        }
        cutProblem = model.addCut(TimeRange(start: from, end: to), to: recording)
        if cutProblem == nil {
            cutFrom = ""
            cutTo = ""
        }
    }
}

/// The title, the notes, and what the recording is.
struct AboutSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            LabeledContent {
                TextField("Title", text: $recording.title, prompt: Text("Untitled"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 420)
                    .onChange(of: recording.title) { model.changedAfterApproval(recording, what: "its title") }
            } label: {
                Text("Title").font(AppFont.body)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes").font(AppFont.body)
                TextEditor(text: $recording.notes)
                    .font(AppFont.body)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
                    .onChange(of: recording.notes) { model.changedAfterApproval(recording, what: "its notes") }
                    .accessibilityLabel("Notes")
            }
            .padding(.vertical, 4)
            LabeledContent {
                Picker("What this is", selection: Binding(get: { recording.kind == .test ? .unknown : recording.kind },
                                                         set: { model.setKind($0, for: recording) })) {
                    Text("Talk, one teacher speaking").tag(RecordingKind.talk)
                    Text("Class").tag(RecordingKind.lesson)
                    Text("Conversation").tag(RecordingKind.conversation)
                    Text("Not set").tag(RecordingKind.unknown)
                }
                .labelsHidden()
                .fixedSize()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("What this is").font(AppFont.body)
                    Text("Only a talk with one teacher speaking can be approved until Prakriti can check who is speaking.")
                        .font(AppFont.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            SectionHeader("About this recording")
        }
    }
}

/// Approve, at the top of the page (SCOPE 9.1 #5: the named action at the top of the pane), with
/// the reason it waits, in plain words.
struct ApproveRows: View {
    @Bindable var recording: Recording
    @Binding var confirmApprove: Bool
    @Binding var confirmMakeAgain: Bool
    let canMakeAgain: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let check = model.approvalCheck(recording)
        Group {
            if check.speakersNotChecked {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ApprovalCheck.speakersTitle).font(AppFont.headline)
                        Text(check.line ?? "").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "person.2.slash").font(AppFont.body).foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
            } else if let line = check.line {
                Text(line)
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if recording.status != .approved {
                HStack(spacing: 12) {
                    Button("Approve…") { confirmApprove = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!check.canApprove)
                    // The trim and cuts wait for Make Again, so it sits right here too.
                    if recording.editsPending && canMakeAgain {
                        Button("Make Again…") { confirmMakeAgain = true }
                    }
                    Text(check.canApprove ? "Copies the finished files to \(model.paths.display(model.approvedFolder(for: recording).path)). Nothing is uploaded."
                                          : "Approve copies the finished files to \(model.paths.display(model.paths.approved.path)). Nothing is uploaded.")
                        .font(AppFont.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let folder = recording.approvedFolder, FileManager.default.fileExists(atPath: folder) {
                PathRow(label: recording.status == .approved ? "Approved files" : "Approved before this change", path: folder)
            }
        }
    }
}
