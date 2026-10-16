import AVFoundation
import Foundation

// The shorts (v2 part M11a, docs/v2/PLAN.md M11; research-edit-engine.md 2.6, 2.7, 6.2 and 6.3): up to the Direction tab's
// count (3 unless Ivan chooses 0 to 5), each one complete moment of 30 to 60 s (or the length he chooses, never over 3 minutes),
// vertical, 1080 by 1920 at the recording's frame rate, H.264 at about 10 Mbps, the sound at -14 LUFS with its true peak at or
// under -1 dBTP, and calm captions burned in inside the safe area. Made after the video in a make, from the same edit plan.
//
// How each short is chosen (`choose`): from the parts of the talk (the beats, annotated once per transcript by the planning
// model, `beats.json`), never a housekeeping, welcome or closing part when another will do; parts that stand alone and that the
// model marked as a strong opening first, then by their best score. Inside a part the short starts at the part's key line (its
// strongest, found word for word by code) and takes whole sentences on until it is long enough, then earlier sentences of the
// same part if it is still short. Its time is what the edit plan keeps (pauses shortened, fillers, retakes and anyone left out
// already taken out), so a short is cut from the video's own plan and never brings back what the plan took out (`spans`).
// Nothing here asks a model: with no parts of the talk there are no shorts, and the step says why.
//
// Where the picture comes from and how it follows the speaker is `VerticalCrop`; the twin's own face step is `TwinFaces`; the
// captions are `BurnedCaptions`. Each short is made in a hidden folder inside the make's staging folder and reaches `Shorts`
// only through `OutputGate.admitShort` (PLAN 2.1.11): the picture output check whenever anyone is hidden in shorts or the
// picture is the twin's, the sound output check whenever anyone is left out of shorts, and the file itself. A short that fails
// is deleted where it was made; the others are kept. Nothing here reaches the network (RulesTests).

/// How many shorts and how long, from the Direction tab (design spec 3.5.3 item 5): 0 to 5, 30, 45 or 60 s.
struct ShortsSettings: Codable, Equatable, Sendable {
    var count = 3
    var length = 60

    static let counts = 0...5
    static let lengths = [30, 45, 60]

    /// The shortest and longest a short of this length may be.
    var bounds: (least: Double, most: Double) {
        switch length {
        case ...30: (20, 30)
        case ...45: (30, 45)
        default: (30, Double(min(length, Int(OutputGate.longestShort))))
        }
    }

    var line: String { count == 0 ? "No shorts" : "\(Format.count(count, "short")), up to \(length) s" }
}

enum Shorts {
    static let folderName = "Shorts"
    static let recordName = "shorts.json"
    static let stagingName = ".shorts"
    /// About 10 Mbps at 1080 by 1920 (research 6.2: the long-form encoder's settings at the vertical size).
    static let bitrate = 10_000_000
    /// 20 ms of fade at each end of a short's sound, so it never starts or stops with a click.
    static let edgeFade = 960
    /// The capture warning of a short cropped from a 1080p picture (PLAN M11 check 3).
    static let softWarning = "These shorts are cut from a 1080p picture and enlarged 1.78 times, so they are softer than the video. For sharp shorts, keep the vertical recording on in OBS, or record in 4K."

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    // MARK: Choosing

    /// One chosen moment: whole sentences of one part of the talk, on the original's clock.
    struct Window: Equatable, Sendable {
        var beat: String
        var summary: String
        var firstWord: Int
        var lastWord: Int
        /// Where the short is cut, on the original's clock (on frames).
        var start: Double
        var end: Double
        /// What the plan keeps of it, in seconds: the short's length.
        var kept: Double
        var score: Double
    }

    /// How strong a part is for a short: standing alone and marked as an opening first, then its best score. Nil for a part a
    /// short is never made of while another will do.
    static func score(_ beat: Beat) -> Double {
        var s = Double(BeatTag.allCases.map { beat.score($0) }.max() ?? 0)
        if beat.hookCandidate { s += 3 }
        if beat.standsAlone { s += 2 }
        if beat.dependsOn.isEmpty { s += 1 }
        if beat.keyLine != nil { s += 0.5 }
        if [.housekeeping, .welcome, .closing].contains(beat.kind) { s -= 10 }
        return s
    }

    /// The sentences of the transcript as word ranges, in order.
    static func sentences(_ words: [PlanWord]) -> [ClosedRange<Int>] {
        BeatSentence.from(words).map { $0.first...$0.last }
    }

    /// Where a short starting at word `a` and ending at word `b` is cut: halfway into the pause on each side, within 0.05 to
    /// 0.5 s of the word, on a frame.
    static func cuts(_ a: Int, _ b: Int, words: [PlanWord], times: [String: EditPlan.WordTime], frame: Double) -> (Double, Double) {
        func start(_ i: Int) -> Double { times[words[i].id]?.in ?? words[i].start }
        func end(_ i: Int) -> Double { times[words[i].id]?.out ?? words[i].end }
        let s = start(a), e = end(b)
        var from = a > 0 ? (end(a - 1) + s) / 2 : s - 0.3
        from = min(max(from, s - 0.5), s - 0.05)
        var to = b + 1 < words.count ? (e + start(b + 1)) / 2 : e + 0.3
        to = max(min(to, e + 0.5), e + 0.05)
        func onFrame(_ t: Double) -> Double { (max(0, t) / frame).rounded() * frame }
        return (onFrame(from), onFrame(to))
    }

    /// The seconds the plan keeps between two moments of the original.
    static func kept(_ plan: EditPlan, from: Double, to: Double) -> Double {
        plan.mainSpans.reduce(0) { $0 + max(0, min($1.out, to) - max($1.in, from)) }
    }

    /// Up to `settings.count` moments, strongest first, none overlapping another or any stretch in `avoid` (voices left out of
    /// shorts). Pure.
    static func choose(plan: EditPlan, words: [PlanWord], beats: [Beat], settings: ShortsSettings, avoid: [TimeRange] = [])
        -> (windows: [Window], notes: [String]) {
        guard settings.count > 0, !words.isEmpty else { return ([], []) }
        let (least, most) = settings.bounds
        let frame = plan.frameDuration.seconds
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let all = sentences(words)
        var notes: [String] = []
        var found: [Window] = []
        let ranked = beats.map { ($0, score($0)) }.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.start < $1.0.start }
        let usable = ranked.filter { $0.1 > 0 }
        for (beat, value) in (usable.isEmpty ? ranked : usable) {
            guard found.count < settings.count else { break }
            guard let first = PlanWord.index(of: beat.from), let last = PlanWord.index(of: beat.to), first <= last, last < words.count else { continue }
            let inside = all.filter { $0.lowerBound >= first && $0.upperBound <= last }
            guard !inside.isEmpty else { continue }
            let keyWord = beat.keyLine.flatMap { PlanWord.index(of: $0.from) } ?? first
            var lo = inside.firstIndex { $0.contains(keyWord) } ?? 0
            var hi = lo
            func window(_ l: Int, _ h: Int) -> Window {
                let a = inside[l].lowerBound, b = inside[h].upperBound
                let (s, e) = cuts(a, b, words: words, times: times, frame: frame)
                return Window(beat: beat.id, summary: beat.summary, firstWord: a, lastWord: b, start: s, end: e, kept: kept(plan, from: s, to: e), score: value)
            }
            var best = window(lo, hi)
            // Whole sentences on from the key line while the short stays within its length, then earlier ones.
            while best.kept < least && hi + 1 < inside.count && window(lo, hi + 1).kept <= most {
                hi += 1
                best = window(lo, hi)
            }
            while best.kept < least && lo > 0 && window(lo - 1, hi).kept <= most {
                lo -= 1
                best = window(lo, hi)
            }
            guard best.kept >= least && best.kept <= most else {
                notes.append(String(format: "Part %@ (%@) has no run of whole sentences %.0f to %.0f s long, so no short was made of it.", beat.id, beat.summary, least, most))
                continue
            }
            if found.contains(where: { $0.start < best.end && best.start < $0.end }) { continue }
            if avoid.contains(where: { $0.start < best.end && best.start < $0.end }) {
                notes.append("Part \(beat.id) has someone you left out of the shorts speaking in it, so no short was made of it.")
                continue
            }
            found.append(best)
        }
        if found.isEmpty { notes.append(String(format: "No part of the talk holds a moment of %.0f to %.0f s that stands on its own.", least, most)) }
        return (found, notes)
    }

    /// The plan's kept spans inside a window, cut at its ends: the short's spans, so it keeps exactly what the video keeps there.
    static func spans(_ plan: EditPlan, window: Window) -> [EditPlan.Span] {
        plan.mainSpans.compactMap { span in
            let a = max(span.in, window.start), b = min(span.out, window.end)
            guard b - a >= plan.frameDuration.seconds - 1e-6,
                  let from = PlanWord.index(of: span.from), let to = PlanWord.index(of: span.to) else { return nil }
            let first = max(from, window.firstWord), last = min(to, window.lastWord)
            guard first <= last else { return nil }
            var out = span
            out.id = "s" + span.id
            out.in = a
            out.out = b
            out.from = PlanWord.id(first)
            out.to = PlanWord.id(last)
            return out
        }
    }

    /// The plan a short is drawn from: the main plan with only the short's spans, and no picture items, chapters or held ending.
    static func plan(_ main: EditPlan, window: Window) -> EditPlan {
        var plan = main
        plan.spans = spans(main, window: window)
        plan.visual = []
        plan.chapters = []
        plan.held = nil
        return plan
    }

    /// The face the crop follows: the teacher's face row when Ivan named one and it is included in shorts, else the included
    /// row seen most. Times and boxes only, from the people file.
    static func subject(_ file: PeopleFile, faces: FacesFound?, names: (faces: [Int: UUID], voices: [Int: UUID]), teacher: UUID?,
                        choices: PeopleChoices) -> [FaceSpot] {
        guard let row = subjectRow(file, faces: faces, names: names, teacher: teacher, choices: choices) else { return [] }
        return file.tracks.filter { $0.person == row }.flatMap { track in
            track.boxes.compactMap { b in b.count >= 5 ? FaceSpot(time: b[0], box: FaceBox(x: b[1], y: b[2], width: b[3], height: b[4])) : nil }
        }.sorted { $0.time < $1.time }
    }

    /// The People tab row the window follows.
    static func subjectRow(_ file: PeopleFile, faces: FacesFound?, names: (faces: [Int: UUID], voices: [Int: UUID]), teacher: UUID?,
                           choices: PeopleChoices) -> Int? {
        let rows = (faces?.people.map(\.id) ?? file.people.map(\.id))
        let included = rows.filter { choices.choice(PersonKey.face($0, names: names), for: .shorts) == .include }
        return included.first(where: { teacher != nil && names.faces[$0] == teacher }) ?? included.first
    }

    // MARK: What was made

    struct Short: Codable, Equatable, Sendable {
        var number: Int
        var fileName: String
        var captionsName: String
        /// The moment of the original it is cut from, the part of the talk, and its first words.
        var start: Double
        var end: Double
        var beat: String
        var summary: String
        /// Its first and last word of the transcript (indices), so the window can be read again (the Viewer's clock, the checks).
        var firstWord: Int
        var lastWord: Int
        var opening: String
        var duration: Double
        var bytes: Int64
        var loudness: Double?
        var truePeak: Double?
        var captionPages: Int
        /// The share of frames with the face inside the middle third of the window, as planned (nil when no face was followed).
        var middleShare: Double?
        var renderSeconds: Double
        var lines: [ChecklistLine]
        var pictureCheck: PictureCheck?
        var soundCheck: AudioCheck?

        var failed: Int { lines.filter { $0.status == .fail }.count }

        /// The window it was cut from, to cut the same plan again.
        var window: Window {
            Window(beat: beat, summary: summary, firstWord: firstWord, lastWord: lastWord, start: start, end: end, kept: duration, score: 0)
        }

        var summaryLine: String { failed == 0 ? "Every line passes" : "\(failed) failed" }
    }

    /// `Shorts/shorts.json`: what the last make of shorts made, read by the inspector and the Viewer.
    struct Record: Codable, Equatable, Sendable {
        var version = 1
        var madeAt: Date
        /// The plan they were cut from (`EditPlan.madeAt`).
        var planMadeAt: Date
        var settings: ShortsSettings
        var source: VerticalCrop.Source
        var twin: TwinSync.Offset?
        /// Why the vertical recording beside it was not used, when there is one.
        var twinNote: String?
        /// The twin's own face step, in one line (counts only).
        var twinFaces: String?
        /// The capture warning (a 1080p crop), shown in Checks.
        var warning: String?
        var shorts: [Short]
        var notes: [String]

        var summary: String {
            guard !shorts.isEmpty else { return "No shorts." }
            let lengths = shorts.map(\.duration)
            return "\(Format.count(shorts.count, "short")), 9:16, \(Format.timecode(lengths.min() ?? 0)) to \(Format.timecode(lengths.max() ?? 0)), captions burned in, from \(source.line)."
        }

        func encoded() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(self)
        }

        static func read(_ folder: URL) -> Record? {
            guard let data = try? Data(contentsOf: folder.appending(path: recordName)) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(Record.self, from: data)
        }
    }

    // MARK: Making

    struct Setup: Sendable {
        var original: URL
        var plan: EditPlan
        /// transcript.json, which the plan was made from.
        var transcript: URL
        var beats: BeatsFile?
        /// The make's own staging folder: the shorts are made in `<staging>/.shorts` and admitted to `<staging>/Shorts`.
        var staging: URL
        var title: String
        var recordedAt: Date?
        var settings = ShortsSettings()
        var people: OutputGate.People
        var peopleFile: PeopleFile?
        var teacher: UUID?
        var folders: PeopleFolders?
        var control: ProcessControl?
        /// Where the steps write their details (times, boxes, counts; never a name): the make's log.
        var log: (@Sendable (String) -> Void)?
        /// Tests only: no twin is looked for, so a short is cropped even when a vertical recording sits beside the original.
        var ignoreTwin = false
    }

    /// Makes the shorts. `ffmpeg` and `ffprobe` run their tool and return stderr and stdout. Throws only when no short could be
    /// made at all; a short refused by the gate is left out and said in `notes`.
    static func make(_ setup: Setup, ffmpeg: @escaping @Sendable ([String]) async throws -> String,
                     ffprobe: @escaping @Sendable ([String]) async throws -> String, now: Date,
                     progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Record {
        if let refusal = OutputGate.refusal(setup.people) { throw Failure(reason: refusal.replacingOccurrences(of: "no video is made", with: "no shorts are made")) }
        guard let data = try? Data(contentsOf: setup.transcript), let planWords = PlanWords.from(json: data) else {
            throw Failure(reason: "The words with their times (transcript.json) could not be read, so no shorts were made.")
        }
        guard let beats = setup.beats, !beats.beats.isEmpty else {
            throw Failure(reason: "Shorts are chosen from the parts of the talk, and they could not be read for this recording, so no shorts were made. Choose a model for Planning the edit in Settings, Models, then Make Again.")
        }
        let people = setup.people
        let shorts = OutputGate.hidden(people, output: .shorts)
        // Voices left out of shorts: no short holds them speaking.
        var avoid: [TimeRange] = []
        let leftOut = people.voices.map { people.choices.leftOutVoices($0, names: people.names, output: .shorts) } ?? []
        if !leftOut.isEmpty, let segments = setup.peopleFile?.voices?.voiceSegments {
            avoid = segments.filter { leftOut.contains($0.voice) }.map { TimeRange(start: $0.start, end: $0.end) }
        }
        let (windows, notesFound) = choose(plan: setup.plan, words: planWords.words, beats: beats.beats, settings: setup.settings, avoid: avoid)
        var notes = notesFound
        guard !windows.isEmpty else { throw Failure(reason: notes.last ?? "No moment was found for a short.") }

        let fm = FileManager.default
        let made = setup.staging.appending(path: stagingName, directoryHint: .isDirectory)
        let admitted = setup.staging.appending(path: folderName, directoryHint: .isDirectory)
        let job = setup.staging.appending(path: ".shorts-job", directoryHint: .isDirectory)
        try? fm.removeItem(at: made)
        try? fm.removeItem(at: admitted)
        try fm.createDirectory(at: made, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: job)
            try? fm.removeItem(at: made)
        }

        // The main picture: its size and length.
        let mainAsset = AVURLAsset(url: setup.original)
        guard let mainTrack = try await mainAsset.loadTracks(withMediaType: .video).first else {
            throw Failure(reason: "The recording has no picture, so no shorts were made.")
        }
        let (size, mainRange) = try await mainTrack.load(.naturalSize, .timeRange)
        let width = Double(abs(size.width)), height = Double(abs(size.height))
        let frame = setup.plan.frameDuration
        let mainFrames = Int64((mainRange.end.seconds / frame.seconds + 1e-6).rounded(.down))

        // The vertical twin, when there is one and its sound lines up with the main recording's within one frame.
        var source = VerticalCrop.cropSource(sourceHeight: height)
        var offset: TwinSync.Offset?
        var twinNote: String?
        var twinFrames: Int64 = 0
        let twin = setup.ignoreTwin ? nil : TwinSync.twin(of: setup.original)
        if let twin {
            let duration = mainRange.end.seconds
            let moments = [0.15, 0.5, 0.85].map { max(0, min(duration - TwinSync.window - 1, duration * $0)) }
            do {
                let measured = try await TwinSync.measure(main: setup.original, twin: twin, at: moments, frame: frame.seconds,
                                                          job: job.appending(path: "twin", directoryHint: .isDirectory),
                                                          decode: { arguments in _ = try await ffmpeg(arguments) })
                let twinTrack = try await AVURLAsset(url: twin).loadTracks(withMediaType: .video).first
                let twinSize = try await twinTrack?.load(.naturalSize)
                let twinRange = try await twinTrack?.load(.timeRange)
                twinFrames = twinRange.map { Int64(($0.end.seconds / frame.seconds + 1e-6).rounded(.down)) } ?? 0
                if let measured, measured.lines(frame: frame.seconds), let twinSize, abs(twinSize.height) > abs(twinSize.width) {
                    offset = measured
                    source = .vertical
                    setup.log?("shorts: " + measured.line)
                } else {
                    offset = measured
                    twinNote = measured.map { "The vertical recording beside it was not used: its sound does not line up with the main recording's within one frame (\($0.line))." }
                        ?? "The vertical recording beside it was not used: its sound could not be read."
                    setup.log?("shorts: " + (twinNote ?? ""))
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                twinNote = "The vertical recording beside it was not used: \(error.localizedDescription)"
            }
        }

        let cropWidth = VerticalCrop.width(sourceWidth: width, sourceHeight: height)
        let base = VideoStep.baseName(title: setup.title, recordedAt: setup.recordedAt)
        var kept: [Short] = []
        var twinFacesLine: String?
        for (n, window) in windows.enumerated() {
            try Task.checkCancellation()
            let number = n + 1
            let share = 1 / Double(windows.count)
            @Sendable func step(_ x: Double) { progress(min(1, (Double(n) + x) * share)) }
            let started = ContinuousClock.now
            let shortPlan = plan(setup.plan, window: window)
            let timeline = EditTimeline(plan: shortPlan, pictureFrames: mainFrames)
            guard timeline.totalFrames > 0 else { continue }
            // The words on the short's clock, its caption pages and their pictures.
            let words = Captions.words(plan: shortPlan, words: planWords, timeline: timeline)
            let pages = BurnedCaptions.pages(words, duration: timeline.duration)
            let captionProblems = BurnedCaptions.problems(pages)
            let table = BurnedCaptions.Table.make(pages, frame: frame)

            // The picture: the twin's frames on its own clock, or the main recording's with the 9:16 window following the face.
            var useTwin = source == .vertical
            var pictureTimeline = timeline
            if useTwin, let offset {
                pictureTimeline.pieces = timeline.pieces.map { var p = $0; p.sourceFrame += offset.frames; return p }
                if pictureTimeline.pieces.contains(where: { $0.sourceFrame < 0 || $0.sourceFrame + $0.frames > twinFrames }) {
                    useTwin = false
                    pictureTimeline = timeline
                    notes.append("Short \(number) runs past the vertical recording, so it is a crop of the main picture.")
                }
            }
            let pictureSource = useTwin ? (twin ?? setup.original) : setup.original
            // Who is hidden: the twin's own faces, matched to the main recording's people; or the main recording's tracks.
            func shown(_ row: Int?) -> Bool { people.choices.choice(PersonKey.face(row ?? 0, names: people.names), for: .shorts) == .include }
            let subjectRow = setup.peopleFile.flatMap { subjectRow($0, faces: people.faces, names: people.names, teacher: setup.teacher, choices: people.choices) }
            var hidePlan = HidePlan(), checkTracks: [PictureOutputCheck.Track] = []
            var spots: [FaceSpot] = []
            if useTwin, let twin, let offset {
                let first = Double(pictureTimeline.pieces.first?.sourceFrame ?? 0) * frame.seconds
                let last = Double((pictureTimeline.pieces.last.map { $0.sourceFrame + $0.frames }) ?? 0) * frame.seconds
                let found = try await TwinFaces.run(twin: twin, range: max(0, first - 1)...(last + 1), main: setup.peopleFile, offset: offset.seconds,
                                                    control: setup.control)
                hidePlan = TwinFaces.hidePlan(found) { shown($0) }
                checkTracks = TwinFaces.checkTracks(found) { shown($0) }
                // The face the window follows, on the twin's own clock: the twin's tracks matched to the subject's row.
                spots = found.tracks.filter { subjectRow != nil && found.row(of: $0.id) == subjectRow }
                    .flatMap { $0.sightings.map { FaceSpot(time: $0.time, box: $0.box) } }.sorted { $0.time < $1.time }
                twinFacesLine = found.line
                setup.log?("short \(number): " + found.line)
            } else if let file = setup.peopleFile {
                hidePlan = HidePlan.from(file) { row in !shown(row) }
                checkTracks = PictureOutputCheck.tracks(file) { row in !shown(row) }
                spots = subject(file, faces: people.faces, names: people.names, teacher: setup.teacher, choices: people.choices)
            }
            // The window following the face: a 9:16 crop the full height of a wide picture, or on the twin a gentle reframe of at
            // most 1.25 (`VerticalCrop.twinZoom`, measured), so the face stays in the middle third.
            var times: [Double] = []
            for piece in pictureTimeline.pieces {
                for j in 0..<piece.frames { times.append(pictureTimeline.seconds(piece.sourceFrame + j)) }
            }
            let windowWidth = useTwin ? 1 / VerticalCrop.twinZoom : cropWidth
            let windowHeight = useTwin ? 1 / VerticalCrop.twinZoom : 1
            let sourceWidth = useTwin ? BurnedCaptions.frame.width : width
            let centers = VerticalCrop.follow(spots, times: times, width: windowWidth, step: frame.seconds)
            let framing = VerticalCrop.framing(centers: centers, width: windowWidth, height: windowHeight, sourceWidth: Double(sourceWidth))
            let middle = VerticalCrop.middleShare(spots, times: times, centers: centers, width: windowWidth)
            step(0.1)
            let hidden: HiddenFaces
            do {
                hidden = try await VideoHiding.make(original: pictureSource, plan: hidePlan, timeline: pictureTimeline, planMadeAt: setup.plan.madeAt,
                                                    control: setup.control)
            } catch let failure as VideoHiding.Failure {
                notes.append("Short \(number) was not made: \(failure.reason)")
                continue
            }
            step(0.25)
            let built: CompositionBuilder.Built
            do {
                built = try await CompositionBuilder.buildShort(timeline: pictureTimeline, source: pictureSource, renderSize: BurnedCaptions.frame,
                                                                framing: framing, hidden: hidden, captions: table)
            } catch let failure as CompositionBuilder.Failure {
                notes.append("Short \(number) was not made: \(failure.reason)")
                continue
            }
            let audio: VideoAudio.Made
            do {
                audio = try await VideoAudio.make(original: setup.original, timeline: timeline, mutes: setup.plan.people.mutes,
                                                  job: job.appending(path: "short-\(number)", directoryHint: .isDirectory), edgeFade: edgeFade, tool: ffmpeg)
            } catch let failure as VideoAudio.Failure {
                notes.append("Short \(number) was not made: \(failure.reason)")
                continue
            }
            step(0.35)
            let name = "\(base) short \(number)"
            let mp4 = made.appending(path: name + ".mp4"), srt = made.appending(path: name + ".srt")
            do {
                _ = try await VideoWriter.write(built, wav: audio.wav, to: mp4, settings: VideoWriter.Settings(bitrate: bitrate),
                                                      progress: { step(0.35 + 0.4 * $0) })
            } catch let failure as VideoWriter.Failure {
                notes.append("Short \(number) was not made: \(failure.reason)")
                continue
            }
            try? fm.removeItem(at: audio.wav)
            try Captions.srt(Captions.cues(words, duration: timeline.duration)).write(to: srt, atomically: true, encoding: .utf8)

            // Measured from the file, then the people checks, then the gate.
            let measured = await ReadyChecklist.measure(mp4: mp4, srt: srt, ffprobe: ffprobe, ffmpeg: ffmpeg)
            var picture: PictureCheck?
            if useTwin || shorts.faces > 0 {
                do {
                    picture = try await PictureOutputCheck.run(mp4: mp4, timeline: pictureTimeline, hidden: hidden, tracks: checkTracks, framing: framing,
                                                               now: now, control: setup.control)
                    if let picture {
                        setup.log?(String(format: "short %d: faces seen again: %d frames, %d faces, %d someone included, %d not accounted for", number,
                                          picture.frames, picture.faces, picture.included, picture.findings.count))
                    }
                } catch let failure as VideoHiding.Failure {
                    notes.append("Short \(number) was not kept: \(failure.reason)")
                    try? fm.removeItem(at: mp4)
                    try? fm.removeItem(at: srt)
                    continue
                }
            }
            var sound: AudioCheck?
            if shorts.voices > 0, let folders = setup.folders {
                let clock = EpisodeClock(intro: 0, segments: timeline.pieces.map {
                    Mastering.Span(start: timeline.seconds($0.sourceFrame), end: timeline.seconds($0.sourceFrame + $0.frames))
                })
                do {
                    sound = try await AudioOutputCheck.run(original: setup.original, made: [.init(name: "short \(number)", url: mp4, clock: clock)],
                                                           segments: setup.peopleFile?.voices?.voiceSegments ?? [], leftOut: Set(leftOut), folders: folders,
                                                           now: now, decode: { arguments in _ = try await ffmpeg(arguments) }, log: setup.log)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    notes.append("Short \(number) was not kept: who is heard in it could not be checked.")
                    try? fm.removeItem(at: mp4)
                    try? fm.removeItem(at: srt)
                    continue
                }
            }
            step(0.95)
            let facts = OutputGate.ShortFacts(measured: measured, duration: timeline.duration, frame: frame.seconds, captionProblems: captionProblems,
                                              twin: useTwin)
            let lines = checklist(measured, facts: facts,
                                  people: OutputGate.peopleProblems(people, picture: picture, sound: sound, output: .shorts, pictureNeeded: useTwin),
                                  pages: pages.count, picture: picture, frameRate: "\(frame.timescale)/\(frame.value)")
            do {
                try OutputGate.admitShort(files: [mp4, srt], to: admitted, people: people, facts: facts, picture: picture, sound: sound)
            } catch let refused as OutputGate.Refused {
                notes.append("Short \(number) was not kept: \(refused.reason)")
                setup.log?("short \(number) was not kept: \(refused.reason)")
                continue
            }
            let d = ContinuousClock.now - started
            let opening = words.prefix(8).map(\.text).joined(separator: " ")
            kept.append(Short(number: number, fileName: mp4.lastPathComponent, captionsName: srt.lastPathComponent, start: window.start, end: window.end,
                              beat: window.beat, summary: window.summary, firstWord: window.firstWord, lastWord: window.lastWord, opening: opening, duration: measured.videoDuration ?? timeline.duration,
                              bytes: measured.bytes, loudness: measured.integratedLUFS, truePeak: measured.truePeak, captionPages: pages.count,
                              middleShare: middle, renderSeconds: Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18,
                              lines: lines, pictureCheck: picture, soundCheck: sound))
            step(1)
        }
        guard !kept.isEmpty else {
            throw Failure(reason: "No short passed its checks. " + notes.suffix(3).joined(separator: " "))
        }
        // A short refused by the gate is left out; the others keep the number in their file's name.
        let record = Record(madeAt: now, planMadeAt: setup.plan.madeAt, settings: setup.settings, source: source,
                            twin: offset, twinNote: twinNote, twinFaces: twinFacesLine,
                            warning: source == .crop1080 ? softWarning : nil, shorts: kept, notes: notes)
        try record.encoded().write(to: admitted.appending(path: recordName), options: .atomic)
        progress(1)
        return record
    }

    /// The lines each short is measured by: its size, rate, length, sound, end, captions and who is in it (`problems`: the gate's
    /// people problems for shorts).
    static func checklist(_ m: ReadyChecklist.Measured, facts: OutputGate.ShortFacts, people problems: [String], pages: Int, picture: PictureCheck?,
                          frameRate: String) -> [ChecklistLine] {
        var out: [ChecklistLine] = []
        func add(_ pass: Bool, _ item: String, _ detail: String) {
            out.append(ChecklistLine(status: pass ? .pass : .fail, item: item, detail: detail, todo: pass ? nil : "Make Again. If it fails again, the log in Activity says why."))
        }
        add(m.width == 1080 && m.height == 1920, "Size", "\(m.width) by \(m.height), vertical (1080 by 1920).")
        add(m.frameRate == frameRate, "Frame rate", "\(m.frameRate.isEmpty ? "unreadable" : m.frameRate); the recording is \(frameRate).")
        let d = m.videoDuration ?? m.duration ?? 0
        add(d > 0 && d <= OutputGate.longestShort, "Length", String(format: "%@, at most 3 minutes.", Format.timecode(d)))
        if let lufs = m.integratedLUFS {
            add(abs(lufs - VideoAudio.target) <= 1, "Loudness", String(format: "%.1f LUFS (-14, within 1).", lufs))
        } else {
            add(false, "Loudness", "Not measured.")
        }
        if let peak = m.truePeak {
            add(peak <= VideoAudio.ceiling + 0.05, "True peak", String(format: "%.1f dBTP (at or under -1).", peak))
        } else {
            add(false, "True peak", "Not measured.")
        }
        add(m.tailDecodes, "The end plays", m.tailDecodes ? "The last 5 seconds decode." : "The last 5 seconds do not decode.")
        add(facts.captionProblems.isEmpty, "Captions", facts.captionProblems.isEmpty
            ? "\(Format.count(pages, "caption")) burned in, every one inside the safe area." : facts.captionProblems.joined(separator: " "))
        let peopleOK = problems.isEmpty
        add(peopleOK, "People", peopleOK ? (picture?.line ?? "Everyone in it is someone you included in the shorts.") : problems.joined(separator: " "))
        return out
    }
}
