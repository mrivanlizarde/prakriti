import AVFoundation
import AVKit
import Foundation
import Observation

// The Viewer's state (v2 part M3b, docs/v2/design-spec.md 3.4): which rendition plays, the system
// player, the transcript under it, the moment playing on the ORIGINAL recording's clock, and the words
// or span chosen for Cut and Keep. One Viewer at a time, owned by AppModel, so the inspector, the menus
// and the window's state restoration read the same one. Replaces v1's `RecordingPage` (retired here).

/// What the Viewer plays. Video and Shorts are named now and come with their parts (M8, M11): they show in
/// the picker, unavailable, with the reason.
enum Rendition: String, CaseIterable, Identifiable, Sendable {
    case original, podcast, podcastReady, video, shorts
    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "Original"
        case .podcast: "Podcast"
        case .podcastReady: "Podcast-ready"
        case .video: "Video"
        case .shorts: "Shorts"
        }
    }

    var symbol: String {
        switch self {
        case .original: "video"
        case .podcast: "mic"
        case .podcastReady: "checkmark.circle"
        case .video: "play.rectangle"
        case .shorts: "rectangle.portrait"
        }
    }

    /// Whether this build can make it at all.
    var isBuilt: Bool { self != .video && self != .shorts }

    /// Has a picture to show (the others are sound with the transcript under it).
    var hasPicture: Bool { self == .original || self == .video || self == .shorts }

    static let shown: [Rendition] = [.original, .podcast, .podcastReady, .video, .shorts]
}

@MainActor
@Observable
final class ViewerModel {
    /// The recording open in the Viewer, by id.
    private(set) var recordingID: UUID?
    private(set) var rendition: Rendition = .podcast
    /// The file each rendition plays, for this recording's last make.
    private(set) var files: [Rendition: URL] = [:]
    private(set) var document = TranscriptDocument.empty
    /// The original cannot play here (moved, or in iCloud and not on this Mac): the reason in one sentence.
    private(set) var originalNote: String?
    /// The player's own time, on the clock of what it plays.
    private(set) var time: Double = 0
    private(set) var rate: Float = 0
    /// Something has been played or a moment chosen, so a sentence can be marked as the one playing.
    private(set) var hasPosition = false
    /// Follow Playback (View menu, on by default, design spec 3.4.4): the sentence playing stays in view.
    var followPlayback = true
    /// The People overlay on the Original (v2 part M6d, design spec 3.4.1): off until turned on, for this session.
    var showsPeople = false
    /// The words chosen in the transcript (indices into `document.words`), for Cut and Keep.
    var selectedWords: ClosedRange<Int>?
    /// The Timeline-lite span chosen: shown above the inspector's tabs with Restore or Remove.
    var selectedSpan: TimelineSpan?
    /// Bumped when the transcript must bring the playing sentence into view now (a click on a span).
    private(set) var revealRequest = 0

    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var clocks: [Rendition: EpisodeClock] = [:]
    @ObservationIgnored private var originalItem: AVPlayerItem?
    @ObservationIgnored private var pendingSeek: (time: Double, play: Bool)?
    @ObservationIgnored private var shuttleSpeed: Float = 0
    /// Writes one line a second while `--debug-playback-log` is on (docs/v2/PLAN.md rule 2.1.10).
    @ObservationIgnored var playbackLog: ((String) -> Void)?
    @ObservationIgnored private var logTimer: Timer?
    /// Called when the moment playing moves on by a second or more, for the window's state restoration.
    @ObservationIgnored var onPositionChange: ((Rendition, Double) -> Void)?
    @ObservationIgnored private var lastReported: Double = -10

    init() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.time = time.seconds.isFinite ? max(0, time.seconds) : 0
                self.rate = self.player.rate
                if self.player.rate != 0 { self.hasPosition = true }
                if abs(self.time - self.lastReported) >= 1 {
                    self.lastReported = self.time
                    self.onPositionChange?(self.rendition, self.time)
                }
            }
        }
    }

    isolated deinit {
        if let observer { player.removeTimeObserver(observer) }
        logTimer?.invalidate()
        player.pause()
    }

    // MARK: Loading

    /// Opens a recording: its renditions and transcript, once per make. `start` asks for a rendition and a
    /// moment of the original (a restored window, a search result, the inspector's Play).
    func load(_ recording: Recording, applyLexicon: Bool, start: (rendition: Rendition?, original: Double?, play: Bool)? = nil) {
        let key = [recording.id.uuidString, recording.outputFolder ?? "", recording.madeAt.map { "\($0.timeIntervalSince1970)" } ?? "",
                   recording.madeFiles.joined(separator: ","), recording.podcastReady?.fileName ?? "", applyLexicon ? "1" : "0"].joined(separator: "|")
        clocks = Self.clocks(for: recording)
        if key != loadedKey {
            let changedRecording = recordingID != recording.id
            loadedKey = key
            recordingID = recording.id
            files = Self.files(for: recording)
            document = RecordingTranscript.document(folder: recording.outputFolder, applyLexicon: applyLexicon)
            originalItem = nil
            originalNote = nil
            selectedWords = nil
            selectedSpan = nil
            if changedRecording {
                hasPosition = false
                time = 0
                player.pause()
                player.replaceCurrentItem(with: nil)
                let first = start?.rendition.flatMap { isAvailable($0) ? $0 : nil } ?? defaultRendition
                choose(first, path: recording.filePath, keepMoment: false)
            } else {
                // A new make of the same recording: the same rendition, from the same moment of the original.
                let moment = currentOriginal
                choose(isAvailable(rendition) ? rendition : defaultRendition, path: recording.filePath, keepMoment: false, force: true)
                if let moment { seek(original: moment, play: false) }
            }
        }
        if let start {
            if let wanted = start.rendition, wanted != rendition, isAvailable(wanted) { choose(wanted, path: recording.filePath, keepMoment: false) }
            if let moment = start.original {
                seek(original: moment, play: start.play)
            } else if start.play {
                play()
            }
        }
    }

    /// Podcast when the episode is made, else the original.
    var defaultRendition: Rendition { files[.podcast] != nil ? .podcast : .original }

    func isAvailable(_ rendition: Rendition) -> Bool { rendition.isBuilt && files[rendition] != nil }

    /// Why a rendition cannot be chosen, in one sentence; nil when it can.
    func unavailableReason(_ rendition: Rendition) -> String? {
        switch rendition {
        case .video: return "Prakriti does not make an edited video yet."
        case .shorts: return "Prakriti does not make shorts yet."
        case .podcast: return files[.podcast] == nil ? "The episode is not made for this recording." : nil
        case .podcastReady: return files[.podcastReady] == nil ? "The podcast-ready episode is not made for this recording." : nil
        case .original: return files[.original] == nil ? "The original is not known." : nil
        }
    }

    static func files(for recording: Recording) -> [Rendition: URL] {
        var files: [Rendition: URL] = [.original: URL(fileURLWithPath: recording.filePath)]
        if let folder = recording.outputFolder {
            let base = URL(fileURLWithPath: folder, isDirectory: true)
            let episode = base.appending(path: "episode.mp3")
            if FileManager.default.fileExists(atPath: episode.path) { files[.podcast] = episode }
            if let ready = recording.podcastReady {
                let mp3 = base.appending(path: PodcastPackage.folderName, directoryHint: .isDirectory).appending(path: ready.fileName)
                if FileManager.default.fileExists(atPath: mp3.path) { files[.podcastReady] = mp3 }
            }
        }
        return files
    }

    /// Each rendition's map to the original's clock. The podcast-ready episode keeps the same parts as the
    /// episode (the same trim, cuts and silence trim, made in the same run). Its own intro, when Ivan sets
    /// one, is not stored with it, so its times are read without one: with an intro, a word plays early by
    /// the intro's length. No podcast-ready episode on this Mac has an intro (12 Oct).
    static func clocks(for recording: Recording) -> [Rendition: EpisodeClock] {
        guard let episode = recording.episodeClock else { return [:] }
        var clocks: [Rendition: EpisodeClock] = [.podcast: episode]
        clocks[.podcastReady] = EpisodeClock(intro: 0, segments: episode.segments)
        return clocks
    }

    // MARK: Choosing a rendition

    /// Plays another rendition from the same moment of the original.
    func choose(_ next: Rendition, recording: Recording) {
        guard next != rendition, isAvailable(next) else { return }
        choose(next, path: recording.filePath, keepMoment: true)
    }

    private func choose(_ next: Rendition, path: String, keepMoment: Bool, force: Bool = false) {
        guard force || next != rendition || player.currentItem == nil else { return }
        let moment = keepMoment ? currentOriginal : nil
        let wasPlaying = player.rate != 0
        rendition = next
        player.pause()
        shuttleSpeed = 0
        if next == .original {
            loadOriginal(path: path)
        } else if let url = files[next] {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
        if let moment { seek(original: moment, play: wasPlaying) }
        onPositionChange?(rendition, time)
    }

    /// The original, picture and sound, as recorded. It usually lives in the studio folder inside
    /// ~/Documents, so it is looked at off the main thread first (START_HERE, Mac warning 44).
    private func loadOriginal(path: String) {
        if let originalItem {
            player.replaceCurrentItem(with: originalItem)
            return
        }
        player.replaceCurrentItem(with: nil)
        originalNote = nil
        let id = recordingID
        Task { [weak self] in
            let state = await Task.detached { () -> String? in
                guard FileManager.default.fileExists(atPath: path) else { return "The original is not on this Mac any more." }
                if Readiness.isDataless(URL(fileURLWithPath: path)) {
                    return "This recording is in iCloud and not on this Mac yet, so the original cannot play here."
                }
                return nil
            }.value
            guard let self, self.recordingID == id, self.rendition == .original else { return }
            if let state {
                self.originalNote = state
                return
            }
            let item = AVPlayerItem(url: URL(fileURLWithPath: path))
            self.originalItem = item
            self.player.replaceCurrentItem(with: item)
            if let pending = self.pendingSeek {
                self.pendingSeek = nil
                self.seek(original: pending.time, play: pending.play)
            }
        }
    }

    // MARK: The clock

    /// The moment playing, on the original's clock, or nil inside an intro or outro.
    var currentOriginal: Double? {
        guard rendition != .original else { return time }
        guard let clock = clocks[rendition] else { return time }
        return clock.originalTime(time)
    }

    /// The sentence playing now, once something has been played or chosen.
    var currentSentence: TranscriptSentence? {
        guard hasPosition, let t = currentOriginal else { return nil }
        return document.sentence(at: t)
    }

    /// Plays from a moment of the original: in an episode, from where that moment is (or, when it was
    /// cut, from where the episode carries on).
    func seek(original t: Double, play: Bool = true) {
        hasPosition = true
        if rendition == .original && player.currentItem == nil { pendingSeek = (t, play) }
        let target = rendition == .original ? t : (clocks[rendition]?.episodeTime(t).time ?? t)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        time = target
        if play { self.play() }
        onPositionChange?(rendition, target)
    }

    /// Plays from a word (a click in the transcript).
    func play(word index: Int) {
        guard document.words.indices.contains(index) else { return }
        seek(original: document.words[index].start, play: true)
    }

    /// The rendition's own moment (state restoration keeps it).
    func seek(renditionTime t: Double) {
        hasPosition = true
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        time = t
    }

    // MARK: Playing

    func play() {
        // At the end, Play starts again from the beginning, as QuickTime Player does. Reason: the moment is
        // restored at launch, so a recording left at its end otherwise opened with Space doing nothing (12 Oct,
        // measured: four playback checks in a row stopped at 90.048 s of a 90 s clip).
        if let item = player.currentItem, item.duration.isNumeric, item.duration.seconds > 1,
           player.currentTime().seconds >= item.duration.seconds - 0.25 {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            time = 0
        }
        hasPosition = true
        shuttleSpeed = 1
        player.rate = 1
        rate = 1
    }

    func pause() {
        shuttleSpeed = 0
        player.pause()
        rate = 0
        // The moment paused at is saved now, not up to a second later (12 Oct: a pause at 23.696 s came back
        // at 22.800 s), so the window opens at it next time.
        let now = player.currentTime().seconds
        if player.currentItem != nil, now.isFinite {
            time = max(0, now)
            lastReported = time
            onPositionChange?(rendition, time)
        }
    }

    /// Space (HIG playing video: Space toggles play).
    func togglePlay() {
        if player.rate != 0 { pause() } else { play() }
    }

    /// J, K, L (Final Cut Pro's keys, design spec 6.7): L plays forward and, pressed again, faster (1, 2,
    /// 4, 8 times); J the same backward where the file allows it; K stops. Behaviour only, nothing drawn.
    func shuttle(_ key: Character) {
        switch key {
        case "k", "K":
            pause()
        case "l", "L":
            shuttleSpeed = shuttleSpeed > 0 ? min(8, shuttleSpeed * 2) : 1
            hasPosition = true
            player.rate = shuttleSpeed
        case "j", "J":
            guard player.currentItem?.canPlayReverse == true else {
                pause()
                return
            }
            shuttleSpeed = shuttleSpeed < 0 ? max(-8, shuttleSpeed * 2) : -1
            hasPosition = true
            player.rate = shuttleSpeed
        default:
            break
        }
        rate = player.rate
    }

    /// A click on a Timeline-lite span: it is chosen, and plays from its start.
    func select(_ span: TimelineSpan) {
        selectedSpan = span
        seek(original: span.start, play: true)
        revealRequest += 1
    }

    // MARK: The debug switch

    /// `--debug-playback-log`: one line a second with the player's own time and rate, so an unattended check
    /// proves playback from the log rather than from a moving picture (docs/v2/PLAN.md rule 2.1.10).
    func startPlaybackLog(_ write: @escaping (String) -> Void) {
        playbackLog = write
        logTimer?.invalidate()
        logTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = self.player.currentTime().seconds
                self.playbackLog?(String(format: "Playback: currentTime %.3f s, rate %.2f, rendition %@", now.isFinite ? now : 0, self.player.rate, self.rendition.rawValue))
            }
        }
    }

    /// Leaves the Viewer: the player stops.
    func close() {
        pause()
    }
}

/// A span of the Timeline-lite: kept time, or time the trim or a cut takes out, on the original's clock. On the Original,
/// once a recording has an edit plan (v2 part M8a), the spans are the plan's: `planned` time taken out, with its reason.
struct TimelineSpan: Identifiable, Equatable, Hashable, Sendable {
    enum Kind: String, Sendable { case kept, trimmedStart, trimmedEnd, cut, planned }
    let kind: Kind
    let start: Double
    let end: Double
    /// For a planned span: why the plan takes it out, and the plan's own sentence for it.
    var reason: RemovedKind?
    var detail: String?
    var id: String { "\(kind.rawValue)-\(Int(start * 1000))-\(Int(end * 1000))" }
    var length: Double { end - start }
    var isRemoved: Bool { kind != .kept }
    /// From the edit plan, so Restore (which changes Ivan's trim and cuts) does not apply to it.
    var isPlanned: Bool { kind == .planned || detail != nil }

    /// The reason symbol (design spec 3.4.3): pause, filler word, retake, another person, trimmed.
    var symbol: String {
        switch reason {
        case .pause: "pause"
        case .filler, .stutter: "ellipsis.bubble"
        case .restart: "arrow.uturn.backward"
        case .person: "person.fill.questionmark"
        case .cut, .trimmed, nil: isRemoved ? "scissors" : "checkmark.circle"
        }
    }

    /// "Removed: cut, 30 s, 5:00 to 5:30." for the selection strip and VoiceOver.
    var line: String {
        let times = "\(TimeText.string(start)) to \(TimeText.string(end))"
        switch kind {
        case .kept: return (detail == nil ? "Kept" : "Kept by the plan") + ", \(Format.length(length)), \(times)."
        case .cut: return "Removed: a cut, \(Format.length(length)), \(times)."
        case .trimmedStart: return "Removed: trimmed from the start, \(Format.length(length)), \(times)."
        case .trimmedEnd: return "Removed: trimmed from the end, \(Format.length(length)), \(times)."
        case .planned: return "Removed by the plan, \(times): " + (detail ?? "")
        }
    }

    /// The plan's spans over the whole original: what it keeps, and what it takes out with each reason.
    static func spans(plan: EditPlan) -> [TimelineSpan] {
        var spans = plan.spans.map { TimelineSpan(kind: .kept, start: $0.in, end: $0.out, detail: $0.text) }
        spans += plan.removed.map { TimelineSpan(kind: .planned, start: $0.from, end: $0.to, reason: $0.kind, detail: $0.say) }
        return spans.sorted { $0.start < $1.start }
    }

    /// The spans of a recording as its edits stand now (the newest trim and cuts, made or not): what
    /// stays and what goes, end to end over the whole original.
    static func spans(edits: EpisodeEdits, duration: Double) -> [TimelineSpan] {
        guard duration > 0 else { return [] }
        let kept = edits.segments(duration: duration)
        var spans: [TimelineSpan] = []
        var cursor = 0.0
        for (index, part) in kept.enumerated() {
            if part.start > cursor + 0.001 {
                let trimmed = index == 0 && edits.start.map { abs($0 - part.start) < 0.3 } == true
                spans.append(TimelineSpan(kind: trimmed ? .trimmedStart : .cut, start: cursor, end: part.start))
            }
            spans.append(TimelineSpan(kind: .kept, start: part.start, end: part.end))
            cursor = part.end
        }
        if cursor < duration - 0.001 {
            let trimmed = !kept.isEmpty && edits.end.map { abs($0 - cursor) < 0.3 } == true
            spans.append(TimelineSpan(kind: trimmed ? .trimmedEnd : .cut, start: cursor, end: duration))
        }
        return spans
    }
}
