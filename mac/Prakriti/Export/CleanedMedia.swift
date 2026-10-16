@preconcurrency import AVFoundation
import Foundation
import VideoToolbox

// The privacy-safe media of the timelines (v2 part M10b, docs/v2/PLAN.md M10; research-edit-engine.md 5.5, research-people.md 3.3,
// 3.4 and 3.6 item 3). An editing app's timeline points at whole media files: one clip edge dragged outward, or one effect switched
// off, and whatever the file holds comes back. So whenever anyone in the video is hidden or left out, or a name is muted, the
// timelines point at a copy made for them, never at the recording:
//
// - **Only the used ranges:** every kept span of the plan with 2 s of handle on each side, ranges that meet joined, end to end in
//   one file (`ranges`). The timelines' clips are placed on that file's clock (`TimelineSpec.Media.ranges`).
// - **Faces burned in** by the same `Compositor` and the same hidden regions as the MP4 (`VideoHiding` over the ranges, handles
//   included, `CompositionBuilder.buildMedia`), so there is no blur to switch off.
// - **Removed speech replaced by the recording's own room tone on every audio track it keeps** (`silenced`: the plan's people cuts
//   and muted names), never left as a hole and never as the speech: a quiet second of the recording itself, found where nobody
//   speaks (`roomTone`), laid back and forth over each stretch with a 10 ms blend outside it.
// - **A left-out person's own microphone track left out entirely**: their voice is on it even while others speak (research 3.3).
// - **HEVC 10-bit at about 50 Mbps at 1080p** (research 5.5, a rule of thumb until measured, which this part does), every kept
//   sound as 24-bit PCM on its own track, in a `.mov` an editing app reads without converting.
//
// It is made in the timeline's hidden build folder and checked there (`check`): its last 5 s decode, its length is the ranges'
// to the frame, and the same picture and sound output checks as the MP4 run on it (research 3.6 item 3) plus a measure of every
// replaced stretch on every track; `OutputGate.admitTimeline` reads the results and alone moves it into place (PLAN 2.1.11).
// Nothing here reaches the network (RulesTests: `Export/` names no network type).

enum CleanedMedia {
    /// Media on each side of every kept span (PLAN M10: "only the used ranges plus 2 s handles").
    static let handleSeconds = 2.0
    /// HEVC Main 10 at 50 Mbps at 1080p (research 5.5); above 1080p, scaled by the pixels.
    static func bitrate(width: Int, height: Int) -> Int {
        let pixels = Double(width * height) / Double(1920 * 1080)
        return Int((50_000_000 * max(1, pixels)).rounded())
    }
    /// A key frame at least every second: an editing app seeks to any frame quickly.
    static let keyFrameInterval = 30
    /// The room tone laid over removed speech: this much of the recording where nobody speaks.
    static let roomToneSeconds = 1.0
    /// The blend into and out of the room tone, outside each replaced stretch, so the stretch itself is room tone throughout.
    static let blendSamples = 480
    /// A replaced stretch passes when it is no louder than the loudest 100 ms of the room tone it was given by more than this
    /// (measured 15 Oct on two-people-mixed: a 0.3 s stretch over the whole second's level came out 3.1 dB over it, the room tone
    /// not being even; removed speech is 20 dB and more over it).
    static let silenceMarginDB = 1.0

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// Who is hidden and left out, for the media and its checks: from the people check's own file and Ivan's choices for the video.
    struct People: Sendable {
        var hiding = HidePlan()
        var faceTracks: [PictureOutputCheck.Track] = []
        var voiceSegments: [VoiceSegment] = []
        /// Voices left out, by the voice step's ids, and their own microphone tracks (OBS numbering, 2 and up).
        var leftOut: Set<Int> = []
        var leftOutTracks: [Int] = []
        /// The video's counts (`OutputGate.hidden`).
        var hiddenFaces = 0
        var leftOutVoices = 0
        var folders: PeopleFolders?
        var control: ProcessControl?
        var log: (@Sendable (String) -> Void)?

        /// From the people check's file (nil when it is not there) and the gate's facts, for `plan` (the video's).
        static func from(file: PeopleFile?, gate: OutputGate.People, plan: EditPlan, folders: PeopleFolders?, control: ProcessControl? = nil,
                         log: (@Sendable (String) -> Void)? = nil) -> People {
            var people = People(folders: folders, control: control, log: log)
            let hides: (Int?) -> Bool = { row in gate.choices.choice(PersonKey.face(row ?? 0, names: gate.names), for: .video) != .include }
            if let file {
                people.hiding = VideoHiding.plan(file, names: gate.names, choices: gate.choices)
                people.faceTracks = PictureOutputCheck.tracks(file, hidden: hides)
                people.voiceSegments = file.voices?.voiceSegments ?? []
            }
            let counts = OutputGate.hidden(gate)
            people.hiddenFaces = counts.faces
            people.leftOutVoices = counts.voices
            var out = Set(plan.people.leftOut)
            if let voices = gate.voices { out.formUnion(gate.choices.leftOutVoices(voices, names: gate.names, output: .video)) }
            people.leftOut = out
            people.leftOutTracks = (gate.voices?.voices ?? []).filter { out.contains($0.id) }.compactMap(\.track).sorted()
            return people
        }
    }

    /// Whether the timelines need privacy-safe media rather than a clone: anyone hidden or left out, a name muted, or anything the
    /// plan cuts for a person.
    static func needed(plan: EditPlan, hiddenFaces: Int, leftOutVoices: Int) -> Bool {
        hiddenFaces > 0 || leftOutVoices > 0 || !plan.people.leftOut.isEmpty || !plan.people.cuts.isEmpty || !plan.people.mutes.isEmpty
    }

    /// The used ranges of the original: every piece of `timeline` with `handle` frames each side, within the picture, joined where
    /// they meet, as a timeline of their own (each range a piece, end to end from frame 0: the media's own clock).
    static func ranges(_ timeline: EditTimeline, pictureFrames: Int64, handle: Int64) -> EditTimeline {
        var spans: [(Int64, Int64)] = []
        for piece in timeline.pieces {
            spans.append((max(0, piece.sourceFrame - handle), min(pictureFrames, piece.sourceFrame + piece.frames + handle)))
        }
        if let held = timeline.holdSourceFrame, timeline.holdFrames > 0 {
            spans.append((max(0, held - handle), min(pictureFrames, held + 1 + handle)))
        }
        spans.sort { $0.0 < $1.0 }
        var merged: [(Int64, Int64)] = []
        for span in spans where span.1 > span.0 {
            if let last = merged.last, span.0 <= last.1 { merged[merged.count - 1].1 = max(last.1, span.1) } else { merged.append(span) }
        }
        var at: Int64 = 0
        var pieces: [EditTimeline.Piece] = []
        for (index, span) in merged.enumerated() {
            pieces.append(.init(id: "m\(index + 1)", sourceFrame: span.0, frames: span.1 - span.0, editFrame: at))
            at += span.1 - span.0
        }
        return EditTimeline(frame: timeline.frame, pieces: pieces)
    }

    static func handleFrames(_ frame: FrameDuration) -> Int64 { Int64((handleSeconds / frame.seconds).rounded()) }

    /// The stretches of the original replaced by room tone: the people cuts and the muted names, joined. Seconds.
    static func silenced(_ plan: EditPlan) -> [TimeRange] {
        EpisodeEdits.merged(plan.people.cuts + plan.people.mutes)
    }

    /// The quietest `roomToneSeconds` of a sound (interleaved, `channels`) where nobody speaks: away from every voice segment,
    /// every word and every stretch to replace. Falls back to the quietest anywhere when every second has speech. Seconds.
    static func roomTone(blockEnergy: [Double], blockSeconds: Double, busy: [TimeRange], duration: Double) -> TimeRange {
        let window = max(1, Int((roomToneSeconds / blockSeconds).rounded()))
        guard blockEnergy.count >= window else { return TimeRange(start: 0, end: min(duration, roomToneSeconds)) }
        var prefix = [0.0]
        for e in blockEnergy { prefix.append(prefix.last! + e) }
        let sorted = busy.sorted { $0.start < $1.start }
        func free(_ a: Double, _ b: Double) -> Bool { !sorted.contains { $0.start < b + 0.25 && $0.end > a - 0.25 } }
        var best: (Int, Double)?, anywhere: (Int, Double)?
        for i in 0...(blockEnergy.count - window) {
            let energy = (prefix[i + window] - prefix[i]) / Double(window)
            let a = Double(i) * blockSeconds, b = a + roomToneSeconds
            guard b <= duration else { break }
            if energy < (anywhere?.1 ?? .infinity) { anywhere = (i, energy) }
            if free(a, b), energy < (best?.1 ?? .infinity) { best = (i, energy) }
        }
        let pick = best ?? anywhere ?? (0, 0)
        let start = Double(pick.0) * blockSeconds
        return TimeRange(start: start, end: start + roomToneSeconds)
    }

    /// What `make` left in the build folder for `check`.
    struct Made: Sendable {
        let url: URL
        /// The media's clock: each used range a piece.
        let timeline: EditTimeline
        let hidden: HiddenFaces
        /// The original's audio tracks kept (OBS numbering, 1 and up), in the media's order, and those left out.
        let tracksKept: [Int]
        let tracksLeftOut: [Int]
        let roomTone: TimeRange
        /// Root mean square of the room tone's loudest 100 ms on each kept track, in the media's order.
        let roomToneRMS: [Double]
        /// The replaced stretches on the media's clock, seconds.
        let replaced: [TimeRange]
        let frames: Int
        let seconds: Double
    }

    /// What the media's checks found, read by `OutputGate.admitTimeline` and kept in the timelines' record.
    struct Check: Codable, Equatable, Sendable {
        var picture: PictureCheck?
        var sound: AudioCheck?
        /// Stretches replaced by room tone, measured on every kept track; the loudest against its room tone, in dB.
        var replacedStretches = 0
        var loudestOverRoomTone: Double?
        var silenceProblems: [String] = []
        /// The media opens, its last 5 s decode, and it is the used ranges' length to the frame.
        var whole = false
        var wholeLine = ""
    }

    /// Runs ffmpeg with these arguments and returns its stderr.
    typealias Tool = @Sendable ([String]) async throws -> String

    /// Makes the privacy-safe media at `url` (inside the timeline's hidden build folder), working in `job` (deleted after).
    static func make(original: URL, plan: EditPlan, people: People, to url: URL, job: URL, ffmpeg: @escaping Tool,
                     progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Made {
        let started = ContinuousClock.now
        let fm = FileManager.default
        try? fm.removeItem(at: job)
        try fm.createDirectory(at: job, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: job) }
        if people.hiddenFaces > 0 && people.hiding.isEmpty {
            // Someone is set to be hidden, but the people check's file holds no sighting of them: fail closed, as the video does.
            throw Failure(reason: "Someone is set to be hidden, but where their face is could not be read from the people check. Click Check People, then make the timelines again.")
        }
        let pictureFrames = try await CompositionBuilder.pictureFrames(original: original, plan: plan)
        let video = EditTimeline(plan: plan, pictureFrames: pictureFrames)
        let media = ranges(video, pictureFrames: pictureFrames, handle: handleFrames(plan.frameDuration))
        guard media.totalFrames > 0 else { throw Failure(reason: "The plan keeps no frame of the picture, so no media was made.") }

        // The faces, over every frame of the ranges, handles included.
        let hidingShare = people.hiding.isEmpty ? 0.0 : 0.3
        let hidden: HiddenFaces
        do {
            hidden = try await VideoHiding.make(original: original, plan: people.hiding, timeline: media, planMadeAt: plan.madeAt, control: people.control,
                                                progress: { progress(hidingShare * $0) })
        } catch let failure as VideoHiding.Failure {
            throw Failure(reason: failure.reason)
        }

        // The sound: every audio track of the original but the left-out microphones, each with removed speech replaced.
        let asset = AVURLAsset(url: original)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        var channels: [Int] = []
        for track in audio {
            let basic = try await track.load(.formatDescriptions).first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
            channels.append(max(1, min(2, Int(basic?.mChannelsPerFrame ?? 2))))
        }
        let numbers = Array(1...max(1, audio.count)).prefix(audio.count)
        let kept = numbers.filter { !people.leftOutTracks.contains($0) }
        let leftOut = numbers.filter { people.leftOutTracks.contains($0) }
        let duration = media.seconds(pictureFrames)
        let stretches = silenced(plan)
        var busy = stretches + people.voiceSegments.map { TimeRange(start: $0.start, end: $0.end) }
        busy += plan.words.map { TimeRange(start: $0.in, end: $0.out) }
        var wavs: [(url: URL, channels: Int)] = []
        var tone = TimeRange(start: 0, end: roomToneSeconds)
        var toneRMS: [Double] = []
        for (position, number) in kept.enumerated() {
            let ch = channels[number - 1]
            let raw = job.appending(path: "track-\(number).f32")
            _ = try await ffmpeg(["-y", "-v", "error", "-i", original.path, "-map", "0:a:\(number - 1)", "-vn", "-ac", String(ch),
                                  "-ar", String(EditTimeline.sampleRate), "-f", "f32le", raw.path])
            let source = try Samples(raw, channels: ch)
            let expected = Int64((duration * Double(EditTimeline.sampleRate)).rounded())
            guard abs(source.frames - expected) < Int64(EditTimeline.sampleRate) else {
                throw Failure(reason: "Audio track \(number) of the recording did not decode to its length, so no media was made.")
            }
            if position == 0 {
                // The room tone is found once, on the first track kept (the mix), and taken at the same moment on every track.
                tone = roomTone(blockEnergy: try source.blockEnergy(seconds: 0.05), blockSeconds: 0.05, busy: busy, duration: duration)
            }
            let window = try source.read(from: Int64(tone.start * Double(EditTimeline.sampleRate)), count: Int(roomToneSeconds * Double(EditTimeline.sampleRate)))
            // The room tone's loudest 100 ms: what a replaced stretch, however short, may reach and no more.
            toneRMS.append(stride(from: 0, to: window.count, by: ch * EditTimeline.sampleRate / 10).map {
                rms(Array(window[$0..<min(window.count, $0 + ch * EditTimeline.sampleRate / 10)]))
            }.max() ?? rms(window))
            let wav = job.appending(path: "track-\(number).wav")
            try write(source: source, tone: window, stretches: stretches, pieces: media.audioPieces, to: wav)
            try? fm.removeItem(at: raw)
            wavs.append((wav, ch))
            progress(hidingShare + 0.1 * Double(position + 1) / Double(kept.count))
        }
        let built: CompositionBuilder.Built
        do {
            built = try await CompositionBuilder.buildMedia(timeline: media, original: original, hidden: hidden)
        } catch let failure as CompositionBuilder.Failure {
            throw Failure(reason: failure.reason)
        }
        let before = hidingShare + 0.1
        let frames = try await writeMovie(built, sounds: wavs, to: url, progress: { progress(before + (1 - before) * $0) })
        // The replaced stretches on the media's clock, each piece of a stretch inside a range.
        var replaced: [TimeRange] = []
        for piece in media.pieces {
            let a = media.seconds(piece.sourceFrame), b = media.seconds(piece.sourceFrame + piece.frames), at = media.seconds(piece.editFrame)
            for s in stretches where s.end > a && s.start < b {
                replaced.append(TimeRange(start: at + max(a, s.start) - a, end: at + min(b, s.end) - a))
            }
        }
        let elapsed = ContinuousClock.now - started
        people.log?(String(format: "privacy-safe media: %d ranges, %.1f s with handles of the %.1f s kept; %d faces hidden on %d frames; %d tracks kept, %d left out; %d stretches replaced by room tone from %.2f s",
                           media.pieces.count, media.duration, video.seconds(video.keptFrames), hidden.tracks.count, hidden.frames.count, kept.count,
                           leftOut.count, replaced.count, tone.start))
        progress(1)
        return Made(url: url, timeline: media, hidden: hidden, tracksKept: Array(kept), tracksLeftOut: Array(leftOut), roomTone: tone, roomToneRMS: toneRMS,
                    replaced: replaced, frames: frames,
                    seconds: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
    }

    /// The media's checks, in its build folder: whole, the picture output check when anyone is hidden, the sound output check on
    /// every kept track when anyone is left out, and every replaced stretch measured on every kept track.
    static func check(_ made: Made, original: URL, people: People, ffmpeg: @escaping Tool, now: Date,
                      progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Check {
        var check = Check()
        let fm = FileManager.default
        // Whole: opens, decodes at its end, the ranges' length to the frame, every kept track there.
        let asset = AVURLAsset(url: made.url)
        let pictures = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        let sounds = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        var frames: Int64 = -1
        if let picture = pictures.first, let range = try? await picture.load(.timeRange) {
            frames = Int64((range.duration.seconds / made.timeline.frame.seconds).rounded())
        }
        let tail = await TimelineMedia.tailFrames(made.url)
        check.whole = tail > 0 && frames == made.timeline.totalFrames && sounds.count == made.tracksKept.count
        check.wholeLine = "\(frames) frames of the ranges' \(made.timeline.totalFrames), \(sounds.count) sound tracks of \(made.tracksKept.count), last 5 s decode: \(tail > 0)"
        progress(0.05)
        // The picture: every face found again, five frames a second, is someone included.
        if people.hiddenFaces > 0 || !people.hiding.isEmpty {
            check.picture = try await PictureOutputCheck.run(mp4: made.url, timeline: made.timeline, hidden: made.hidden, tracks: people.faceTracks, now: now,
                                                             control: people.control, progress: { progress(0.05 + 0.5 * $0) })
            if let picture = check.picture {
                people.log?(String(format: "privacy-safe media, faces seen again: %d frames, %d faces, %d someone included, %d not accounted for (%.1f s)",
                                   picture.frames, picture.faces, picture.included, picture.findings.count, picture.seconds))
                for finding in picture.findings.prefix(20) {
                    people.log?(String(format: "privacy-safe media: face at %.2f s of the media (%.2f s of the original), %@, box %.3f %.3f %.3f %.3f",
                                       finding.at, finding.original, finding.how, finding.box.x, finding.box.y, finding.box.width, finding.box.height))
                }
            }
        }
        // The sound: every kept track told apart again; every voice in it someone included.
        if !people.leftOut.isEmpty || people.leftOutVoices > 0 {
            guard let folders = people.folders else {
                throw Failure(reason: "Who is heard in the privacy-safe media could not be checked: the people check's folder is not there.")
            }
            let clock = EpisodeClock(intro: 0, segments: made.timeline.pieces.map {
                Mastering.Span(start: made.timeline.seconds($0.sourceFrame), end: made.timeline.seconds($0.sourceFrame + $0.frames))
            })
            let files = made.tracksKept.enumerated().map { index, number in
                AudioOutputCheck.Made(name: "sound track \(number) of the media", url: made.url, clock: clock, map: "0:a:\(index)")
            }
            check.sound = try await AudioOutputCheck.run(original: original, made: files, segments: people.voiceSegments, leftOut: people.leftOut,
                                                         folders: folders, now: now, decode: { arguments in _ = try await ffmpeg(arguments) }, log: people.log)
        }
        progress(0.9)
        // Every replaced stretch on every kept track: no louder than the room tone it was given.
        let job = fm.temporaryDirectory.appending(path: "prakriti-media-check-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: job, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: job) }
        let measured = made.replaced.filter { $0.end - $0.start >= 0.05 }
        check.replacedStretches = measured.count
        if !measured.isEmpty {
            for (index, number) in made.tracksKept.enumerated() {
                let raw = job.appending(path: "check-\(index).f32")
                _ = try await ffmpeg(["-y", "-v", "error", "-i", made.url.path, "-map", "0:a:\(index)", "-ac", "1", "-ar", String(EditTimeline.sampleRate),
                                      "-f", "f32le", raw.path])
                let samples = try Samples(raw, channels: 1)
                let reference = max(made.roomToneRMS[safe: index] ?? 0, 1e-6)
                for stretch in measured {
                    let a = Int64(stretch.start * Double(EditTimeline.sampleRate)), b = Int64(stretch.end * Double(EditTimeline.sampleRate))
                    let level = rms(try samples.read(from: a, count: Int(b - a)))
                    let db = 20 * log10(max(level, 1e-9) / reference)
                    check.loudestOverRoomTone = max(check.loudestOverRoomTone ?? -.infinity, db)
                    if db > silenceMarginDB {
                        check.silenceProblems.append(String(format: "Sound track %d of the media is %.1f dB over its room tone at %@, where speech was removed.",
                                                            number, db, Format.timecode(stretch.start)))
                    }
                }
                try? fm.removeItem(at: raw)
            }
        }
        progress(1)
        return check
    }

    // MARK: Sound

    /// One track's sound for the media, as a float WAV: each used range in turn, every replaced stretch room tone.
    static func write(source: Samples, tone: [Float], stretches: [TimeRange], pieces: [EditTimeline.AudioPiece], to url: URL) throws {
        let ch = source.channels
        let rate = Double(EditTimeline.sampleRate)
        let toneFrames = tone.count / ch
        let regions = stretches.map { (Int64(($0.start * rate).rounded(.down)), Int64(($0.end * rate).rounded(.up))) }
        let total = pieces.reduce(Int64(0)) { $0 + $1.samples }
        FileManager.default.createFile(atPath: url.path, contents: wavHeader(frames: total, channels: ch))
        let out = try FileHandle(forWritingTo: url)
        defer { try? out.close() }
        try out.seekToEnd()
        for piece in pieces {
            var at = piece.sourceSample
            var left = piece.samples
            while left > 0 {
                let count = Int(min(left, Int64(EditTimeline.sampleRate) * 10))
                var chunk = try source.read(from: at, count: count)
                replace(&chunk, start: at, channels: ch, regions: regions, tone: tone, toneFrames: toneFrames)
                out.write(Data(floatsAsBytes: chunk))
                at += Int64(count)
                left -= Int64(count)
            }
        }
    }

    /// Replaces every region inside `chunk` (which starts at source sample `start`) with the room tone, laid forward then back so
    /// it never jumps, each region starting from the tone's beginning; a blend of `blendSamples` outside each region.
    static func replace(_ chunk: inout [Float], start: Int64, channels ch: Int, regions: [(Int64, Int64)], tone: [Float], toneFrames: Int) {
        guard toneFrames > 0 else { return }
        let end = start + Int64(chunk.count / ch)
        let blend = Int64(blendSamples)
        for (a, b) in regions where a - blend < end && b + blend > start {
            let from = max(start, a - blend), to = min(end, b + blend)
            for t in from..<to {
                let g: Float
                if t < a { g = Float(0.5 - 0.5 * cos(Double.pi * Double(t - (a - blend)) / Double(blend))) }
                else if t >= b { g = Float(0.5 - 0.5 * cos(Double.pi * Double((b + blend) - t) / Double(blend))) }
                else { g = 1 }
                let period = Int64(2 * toneFrames)
                let k = Int((((t - a) % period) + period) % period)
                let index = k < toneFrames ? k : 2 * toneFrames - 1 - k
                let i = Int(t - start) * ch
                for c in 0..<ch { chunk[i + c] = chunk[i + c] * (1 - g) + tone[index * ch + c] * g }
            }
        }
    }

    static func rms(_ x: [Float]) -> Double {
        guard !x.isEmpty else { return 0 }
        var sum = 0.0
        for v in x { sum += Double(v) * Double(v) }
        return sqrt(sum / Double(x.count))
    }

    /// A 32-bit float WAV header.
    static func wavHeader(frames: Int64, channels: Int) -> Data {
        let rate = UInt32(EditTimeline.sampleRate)
        let block = UInt16(channels * 4)
        let dataBytes = UInt32(clamping: frames * Int64(block))
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 &+ dataBytes)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(3); u16(UInt16(channels)); u32(rate); u32(rate * UInt32(block)); u16(block); u16(32)
        d.append(contentsOf: Array("data".utf8)); u32(dataBytes)
        return d
    }

    /// Interleaved float samples read by sample frame; anything before the start or past the end is silence.
    final class Samples {
        let handle: FileHandle
        let frames: Int64
        let channels: Int

        init(_ url: URL, channels: Int) throws {
            self.channels = channels
            handle = try FileHandle(forReadingFrom: url)
            let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            frames = bytes / Int64(4 * channels)
        }

        deinit { try? handle.close() }

        func read(from start: Int64, count: Int) throws -> [Float] {
            var out = [Float](repeating: 0, count: max(0, count) * channels)
            let first = max(0, start), last = min(frames, start + Int64(count))
            guard last > first else { return out }
            try handle.seek(toOffset: UInt64(first) * UInt64(4 * channels))
            guard let data = try handle.read(upToCount: Int(last - first) * 4 * channels) else { return out }
            let offset = Int(first - start) * channels
            data.withUnsafeBytes { raw in
                let floats = raw.bindMemory(to: Float.self)
                for i in 0..<min(floats.count, out.count - offset) { out[offset + i] = floats[i] }
            }
            return out
        }

        /// Mean square energy of every block of `seconds`, all channels together.
        func blockEnergy(seconds: Double) throws -> [Double] {
            let block = Int(seconds * Double(EditTimeline.sampleRate))
            var out: [Double] = []
            var at: Int64 = 0
            while at < frames {
                let count = Int(min(Int64(block) * 200, frames - at))
                let chunk = try read(from: at, count: count)
                var i = 0
                while i + block * channels <= chunk.count {
                    var sum = 0.0
                    for k in i..<(i + block * channels) { sum += Double(chunk[k]) * Double(chunk[k]) }
                    out.append(sum / Double(block * channels))
                    i += block * channels
                }
                at += Int64(count)
            }
            return out
        }
    }

    // MARK: Writing

    /// The picture through the compositor as HEVC Main 10, and each sound as 24-bit PCM on its own track, into a `.mov`. Returns
    /// the pictures written.
    static func writeMovie(_ built: CompositionBuilder.Built, sounds: [(url: URL, channels: Int)], to output: URL,
                           progress: @escaping @Sendable (Double) -> Void) async throws -> Int {
        try? FileManager.default.removeItem(at: output)
        let width = Int(built.renderSize.width), height = Int(built.renderSize.height)
        let timeline = built.timeline
        let videoReader = try AVAssetReader(asset: built.composition)
        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [built.track],
                                                              videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: Compositor.pixelFormat])
        videoOutput.videoComposition = built.videoComposition
        let frames = videoReader.outputProvider(for: videoOutput)

        let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String,
                AVVideoAverageBitRateKey: bitrate(width: width, height: height),
                AVVideoMaxKeyFrameIntervalKey: keyFrameInterval,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoExpectedSourceFrameRateKey: Int((1 / timeline.frame.seconds).rounded()),
            ] as [String: any Sendable],
        ])
        videoInput.mediaTimeScale = CMTimeScale(timeline.frame.timescale)
        let pictureIn = writer.inputPixelBufferReceiver(for: videoInput, pixelBufferAttributes: nil)
        var readers: [AVAssetReader] = []
        var feeds: [@Sendable () async throws -> Void] = []
        for sound in sounds {
            let asset = AVURLAsset(url: sound.url)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                throw Failure(reason: "A sound of the media could not be read back to write it.")
            }
            let reader = try AVAssetReader(asset: asset)
            let pcm = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVSampleRateKey: EditTimeline.sampleRate,
                AVNumberOfChannelsKey: sound.channels,
            ])
            let provider = reader.outputProvider(for: pcm)
            var layout = AudioChannelLayout()
            layout.mChannelLayoutTag = sound.channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 24, AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVSampleRateKey: EditTimeline.sampleRate,
                AVNumberOfChannelsKey: sound.channels,
                AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size),
            ])
            readers.append(reader)
            let receiver = writer.inputReceiver(for: input)
            feeds.append {
                while let sample = try await provider.next() {
                    try Task.checkCancellation()
                    try await receiver.append(sample)
                }
                receiver.finish()
            }
        }
        do {
            try videoReader.start()
            for reader in readers { try reader.start() }
            try writer.start()
        } catch {
            throw Failure(reason: "The media could not be started: \(error.localizedDescription)")
        }
        writer.startSession(atSourceTime: .zero)
        let total = max(1, Int(timeline.totalFrames))
        let written: Int
        do {
            written = try await withThrowingTaskGroup(of: Int.self) { group in
                group.addTask {
                    // One picture per frame time (Mac warning 161): a frame time the reader skips is the picture before it.
                    var count = 0
                    var last: CVReadOnlyPixelBuffer?
                    var lastFrame: Int64 = -1
                    while let sample = try await frames.next() {
                        try Task.checkCancellation()
                        guard case let .pixelBuffer(buffer) = sample.content else { continue }
                        let index = Int64((sample.presentationTimeStamp.seconds / timeline.frame.seconds).rounded())
                        if index <= lastFrame || index >= timeline.totalFrames { continue }
                        if index > lastFrame + 1 {
                            let filler = last ?? buffer
                            for skipped in (lastFrame + 1)..<index {
                                try await pictureIn.append(filler, with: timeline.time(skipped))
                                count += 1
                            }
                        }
                        try await pictureIn.append(buffer, with: timeline.time(index))
                        last = buffer
                        lastFrame = index
                        count += 1
                        if count % 30 == 0 { progress(min(1, Double(count) / Double(total))) }
                    }
                    if let last {
                        var next = lastFrame + 1
                        while next < timeline.totalFrames {
                            try await pictureIn.append(last, with: timeline.time(next))
                            next += 1
                            count += 1
                        }
                    }
                    pictureIn.finish()
                    return count
                }
                for feed in feeds {
                    group.addTask {
                        try await feed()
                        return 0
                    }
                }
                var pictures = 0
                for try await n in group { pictures += n }
                return pictures
            }
        } catch {
            writer.cancelWriting()
            throw error is CancellationError ? error : Failure(reason: "The media stopped while it was written: \(error.localizedDescription)")
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw Failure(reason: "The media could not be finished: \(writer.error?.localizedDescription ?? "the writer did not say why").")
        }
        progress(1)
        return written
    }
}
