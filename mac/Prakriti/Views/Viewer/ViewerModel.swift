import AVFoundation
import AVKit
import Foundation
import Observation

// The Viewer's state (v2 part M3b, docs/v2/design-spec.md 3.4): which rendition plays, the system
// player, the transcript under it, the moment playing on the ORIGINAL recording's clock, and the words
// or span chosen for Cut and Keep. One Viewer at a time, owned by AppModel, so the inspector, the menus
// and the window's state restoration read the same one. Replaces v1's `RecordingPage` (retired here).

/// What the Viewer plays. Video plays since part M8c, through the same compositor as the file; Shorts since part M11a, each
/// short's own file, chosen with the pop-up beside the picker ("Short 1 of 3").
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

    /// Whether this build can make it at all (every rendition since part M11a).
    var isBuilt: Bool { true }

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
    /// The Captions overlay on the Video (v2 part M8c, design spec 3.4.1): the captions file as it will be uploaded, shown
    /// over the picture. Off until turned on, for this session.
    var showsCaptions = false
    /// The Vertical Guide over the Original and the Video (v2 part M11a, design spec 3.4.1): the 9:16 window the shorts use. Off
    /// until turned on, for this session.
    var showsVerticalGuide = false
    /// The made shorts (v2 part M11a), in their order, and the one Shorts plays.
    struct ShortFile: Equatable {
        var short: Shorts.Short
        var url: URL
    }
    private(set) var shorts: [ShortFile] = []
    private(set) var shortIndex = 0
    /// The short playing's clock against the original's, from the plan it was cut from (nil when the plan cannot be read).
    private(set) var shortTimeline: EditTimeline?
    @ObservationIgnored private var shortsPlan: EditPlan?
    @ObservationIgnored private var guideCache: (key: String, track: VerticalGuideTrack)?
    /// The made video's captions, on the video's clock, read from its `.srt` (v2 part M8c).
    private(set) var captions: [Captions.Cue] = []
    /// The plan the made video was made from, and its timeline between the original's clock and the video's (v2 part M8c).
    /// Nil when the recording has no video the Viewer can play; `videoNote` then says why.
    private(set) var videoPlan: EditPlan?
    /// A kept version the Viewer plays instead of the one in use (v2 part M9d, Play in the Direction tab), from its own folder.
    struct VersionPlaying: Equatable {
        var recordingID: UUID
        var number: Int
        var folder: String
        var video: VideoRecord
    }
    /// Set by Play on a version; nil plays the version in use.
    var versionPlaying: VersionPlaying? { didSet { if oldValue != versionPlaying { loadedKey = "" } } }
    /// The version number on show on Video, when it is not the one in use.
    var playingVersionNumber: Int? { versionPlaying.flatMap { $0.recordingID == recordingID ? $0.number : nil } }
    private(set) var videoTimeline: EditTimeline?
    private(set) var videoNote: String?
    /// The Video rendition is being put together (the composition is built off the main thread).
    private(set) var isBuildingVideo = false
    /// The video's picture size, for drawing the captions over it.
    private(set) var videoSize = CGSize(width: 1920, height: 1080)
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
    /// The Video rendition's player item: the plan's composition with `videoComposition` set to the compositor's (v2 part
    /// M8c). The same object the player plays, kept so PLAN M8 check 4 measures exactly what the player is given.
    @ObservationIgnored private(set) var videoItem: AVPlayerItem?
    @ObservationIgnored private var videoSource: (mp4: URL, plan: EditPlan, hidden: HiddenFaces?)?
    @ObservationIgnored private var videoRequest = 0
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
                   recording.madeFiles.joined(separator: ","), recording.podcastReady?.fileName ?? "", applyLexicon ? "1" : "0",
                   recording.videoJSON ?? ""].joined(separator: "|")
        clocks = Self.clocks(for: recording)
        if key != loadedKey {
            let changedRecording = recordingID != recording.id
            loadedKey = key
            recordingID = recording.id
            files = Self.files(for: recording)
            document = RecordingTranscript.document(folder: recording.outputFolder, applyLexicon: applyLexicon)
            originalItem = nil
            originalNote = nil
            readVideo(recording)
            readShorts(recording)
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

    /// The Video when one is made and can play here (design spec 3.4.2: a recording waiting for a yes opens on its video),
    /// else the Podcast when the episode is made, else the original.
    var defaultRendition: Rendition { isAvailable(.video) ? .video : files[.podcast] != nil ? .podcast : .original }

    func isAvailable(_ rendition: Rendition) -> Bool {
        guard rendition.isBuilt, files[rendition] != nil else { return false }
        return rendition != .video || videoPlan != nil
    }

    /// The made video's file, plan and captions, read once per make (v2 part M8c). Nothing is built until Video is chosen.
    private func readVideo(_ recording: Recording) {
        videoItem = nil
        videoSource = nil
        videoPlan = nil
        videoTimeline = nil
        captions = []
        videoNote = nil
        // A kept version (v2 part M9d) plays from its own folder; otherwise the video in use, from the recording's.
        let version = versionPlaying.flatMap { $0.recordingID == recording.id ? $0 : nil }
        switch VideoPreview.source(folder: version?.folder ?? recording.outputFolder, video: version?.video ?? recording.video) {
        case .success(let found):
            videoSource = (found.mp4, found.plan, found.hidden)
            videoPlan = found.plan
            videoTimeline = EditTimeline(plan: found.plan)
            captions = ((try? String(contentsOf: found.captions, encoding: .utf8)).map(Captions.cues(srt:))) ?? []
            files[.video] = found.mp4
        case .failure(let failure):
            files[.video] = nil
            videoNote = failure.reason
        }
    }

    /// The made shorts, read once per make (v2 part M11a), from `Shorts/shorts.json` and the plan they were cut from.
    private func readShorts(_ recording: Recording) {
        shorts = []
        shortIndex = 0
        shortTimeline = nil
        shortsPlan = nil
        files[.shorts] = nil
        guard let folder = recording.outputFolder, recording.madeFiles.contains(Shorts.folderName) else { return }
        let base = URL(fileURLWithPath: folder, isDirectory: true)
        let shortsFolder = base.appending(path: Shorts.folderName, directoryHint: .isDirectory)
        guard let record = Shorts.Record.read(shortsFolder) else { return }
        shorts = record.shorts.compactMap { short in
            let url = shortsFolder.appending(path: short.fileName)
            return FileManager.default.fileExists(atPath: url.path) ? ShortFile(short: short, url: url) : nil
        }
        shortsPlan = EditPlan.read(folder: folder)
        selectShortFile(0)
    }

    private func selectShortFile(_ index: Int) {
        guard shorts.indices.contains(index) else { return }
        shortIndex = index
        files[.shorts] = shorts[index].url
        shortTimeline = shortsPlan.map { EditTimeline(plan: Shorts.plan($0, window: shorts[index].short.window)) }
    }

    /// Plays another short (the pop-up beside the picker), from its start.
    func chooseShort(_ index: Int) {
        guard index != shortIndex || rendition != .shorts, shorts.indices.contains(index) else { return }
        selectShortFile(index)
        guard rendition == .shorts, let url = files[.shorts] else { return }
        player.pause()
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        time = 0
        onPositionChange?(rendition, 0)
    }

    /// "Short 1 of 3".
    func shortLabel(_ index: Int) -> String { "Short \(index + 1) of \(shorts.count)" }

    /// Where the Vertical Guide's window is, worked out once per people check (v2 part M11a).
    func guideTrack(_ file: PeopleFile, recording: Recording) -> VerticalGuideTrack {
        let key = "\(recording.id.uuidString)|\(file.madeAt.timeIntervalSince1970)|\(recording.choicesJSON ?? "")|\(recording.namesJSON ?? "")"
        if let guideCache, guideCache.key == key { return guideCache.track }
        let track = VerticalGuideTrack.make(file, recording: recording)
        guideCache = (key, track)
        return track
    }

    /// The guide's middle across the picture on show now: on the Original at this moment; on the Video at the moment of the
    /// original it shows, moved through the punch-in on screen. Nil when the moment is not on show.
    func guideCenter(_ track: VerticalGuideTrack) -> Double? {
        switch rendition {
        case .original:
            return track.center(at: time)
        case .video:
            guard let timeline = videoTimeline, let plan = videoPlan, let original = timeline.originalTime(time) else { return nil }
            let center = track.center(at: original)
            guard let crop = Framing(plan: plan, timeline: timeline).rect(atEditFrame: Int64((time / timeline.frame.seconds).rounded())) else { return center }
            return (center - crop.minX) / max(0.001, crop.width)
        default:
            return nil
        }
    }

    /// Why a rendition cannot be chosen, in one sentence; nil when it can.
    func unavailableReason(_ rendition: Rendition) -> String? {
        switch rendition {
        case .video: return videoPlan == nil ? (videoNote ?? "The edited video is not made for this recording.") : nil
        case .shorts: return shorts.isEmpty ? "No shorts are made for this recording." : nil
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
        } else if next == .video {
            loadVideo(path: path)
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

    /// The Video: the plan's composition, drawn by the compositor, with the made video's sound (`VideoPreview`). Built off
    /// the main thread; the original is looked at first, as for the Original (START_HERE, Mac warning 44).
    private func loadVideo(path: String) {
        if let videoItem {
            player.replaceCurrentItem(with: videoItem)
            return
        }
        player.replaceCurrentItem(with: nil)
        guard let source = videoSource else { return }
        originalNote = nil
        videoRequest += 1
        let request = videoRequest, id = recordingID
        isBuildingVideo = true
        Task { [weak self] in
            let outcome = await Task.detached { () -> Result<VideoPreview.Built, VideoPreview.Failure> in
                let original = URL(fileURLWithPath: path)
                guard FileManager.default.fileExists(atPath: path) else {
                    return .failure(.init(reason: "The original is not on this Mac any more, so the video cannot play here."))
                }
                if Readiness.isDataless(original) {
                    return .failure(.init(reason: "This recording is in iCloud and not on this Mac yet, so the video cannot play here."))
                }
                do {
                    return .success(try await VideoPreview.build(plan: source.plan, original: original, mp4: source.mp4, hidden: source.hidden))
                } catch let failure as VideoPreview.Failure {
                    return .failure(failure)
                } catch {
                    return .failure(.init(reason: "The video could not be put together: \(error.localizedDescription)"))
                }
            }.value
            guard let self, self.videoRequest == request, self.recordingID == id else { return }
            self.isBuildingVideo = false
            guard self.rendition == .video else { return }
            switch outcome {
            case .success(let built):
                let item = AVPlayerItem(asset: built.composition)
                item.videoComposition = built.videoComposition
                self.videoItem = item
                self.videoTimeline = built.timeline
                self.videoSize = built.renderSize
                self.player.replaceCurrentItem(with: item)
                if let pending = self.pendingSeek {
                    self.pendingSeek = nil
                    self.seek(original: pending.time, play: pending.play)
                }
            case .failure(let failure):
                self.originalNote = failure.reason
            }
        }
    }

    /// The Video's player item once it is built (PLAN M8 check 4 and the tests wait on it).
    func videoItemReady(timeout: Duration = .seconds(60)) async -> AVPlayerItem? {
        let clock = ContinuousClock(), deadline = clock.now + timeout
        while clock.now < deadline {
            if let videoItem, player.currentItem === videoItem { return videoItem }
            if !isBuildingVideo && rendition == .video && originalNote != nil { return nil }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    // MARK: The clock

    /// The moment playing, on the original's clock, or nil inside an intro or outro.
    var currentOriginal: Double? {
        guard rendition != .original else { return time }
        if rendition == .video { return videoTimeline?.originalTime(time) }
        if rendition == .shorts { return shortTimeline?.originalTime(time) }
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
        if (rendition == .original || rendition == .video) && player.currentItem == nil { pendingSeek = (t, play) }
        let target: Double = switch rendition {
        case .original: t
        // A moment the plan took out plays from where the video carries on after it.
        case .video: videoTimeline?.editTimeAtOrAfter(t) ?? videoTimeline?.duration ?? t
        // A moment outside the short plays it from its start.
        case .shorts: shortTimeline?.editTime(t) ?? 0
        default: clocks[rendition]?.episodeTime(t).time ?? t
        }
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

    /// The caption on screen now, on the Video, when the Captions overlay is on.
    var currentCaption: Captions.Cue? {
        guard showsCaptions, rendition == .video, hasPosition || time > 0 else { return nil }
        return Captions.cue(at: time, in: captions)
    }

    /// Leaves the Viewer: the player stops.
    func close() {
        pause()
    }
}

/// A span of the Timeline-lite: kept time, or time the trim or a cut takes out, on the original's clock. On the Original,
/// once a recording has an edit plan (v2 part M8a), the spans are the plan's: `planned` time taken out, with its reason.
struct TimelineSpan: Identifiable, Equatable, Hashable, Sendable {
    /// `moment`: a moment from another recording Ivan added (v2 part M12b), drawn in teal where it goes, as long as it plays.
    enum Kind: String, Sendable { case kept, trimmedStart, trimmedEnd, cut, planned, moment }
    let kind: Kind
    let start: Double
    let end: Double
    /// For a planned span: why the plan takes it out, and the plan's own sentence for it.
    var reason: RemovedKind?
    var detail: String?
    var id: String { "\(kind.rawValue)-\(Int(start * 1000))-\(Int(end * 1000))" }
    var length: Double { end - start }
    var isRemoved: Bool { kind != .kept && kind != .moment }
    var isMoment: Bool { kind == .moment }
    /// From the edit plan, so Restore (which changes Ivan's trim and cuts) does not apply to it.
    var isPlanned: Bool { kind == .planned || detail != nil }

    /// The reason symbol (design spec 3.4.3): pause, filler word, retake, another person, trimmed.
    var symbol: String {
        switch reason {
        case .pause: "pause"
        case .filler, .stutter: "ellipsis.bubble"
        case .restart: "arrow.uturn.backward"
        case .person: "person.fill.questionmark"
        case .beat: "text.badge.minus"
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
        case .moment: return (detail ?? "A moment from another recording") + ", \(Format.length(length)), added by you after \(TimeText.string(start))."
        }
    }

    /// The plan's spans over the whole original: what it keeps, and what it takes out with each reason.
    static func spans(plan: EditPlan) -> [TimelineSpan] {
        // The opening line repeats time the talk keeps in its place (v2 part M9d): it is a mark, not a span.
        var spans = plan.mainSpans.map { TimelineSpan(kind: .kept, start: $0.in, end: $0.out, detail: $0.text) }
        spans += plan.removed.map { TimelineSpan(kind: .planned, start: $0.from, end: $0.to, reason: $0.kind, detail: $0.say) }
        spans.sort { $0.start < $1.start }
        // The moments from other recordings (v2 part M12b): each where it goes on this original's clock (after the span before it),
        // as long as it plays; Timeline-lite makes room for it.
        for (k, span) in plan.spans.enumerated() where span.isInsert {
            guard let before = plan.spans[..<k].last(where: { !$0.isInsert && !$0.isHook }) else { continue }
            let label = "From " + (span.sourceDate.map { Format.fullDay($0) } ?? (span.sourceLabel ?? "another recording"))
            spans.append(TimelineSpan(kind: .moment, start: before.out, end: before.out + (span.out - span.in), detail: label))
        }
        return spans
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
