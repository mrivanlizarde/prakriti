import Foundation

// "Making the video" and "Checking the video" (v2 part M8b): the edited MP4 from the edit plan, with its captions,
// `Description.txt` and `Ready checklist.txt`, in the recording's `Video` folder. Both steps run inside a make
// (`PipelineStep.renderVideo`, `.checkVideo`) and are called through `VideoStep.make` and `VideoStep.check`.
//
// Everything is made in a staging folder inside the make's own staging folder (hidden, so a make stopped halfway leaves
// nothing a person could post) and reaches the output only through `OutputGate.admit` (PLAN 2.1.11). Nothing here reaches
// the network (RulesTests: no network type under Render/).

/// What the edited video's make left, kept on the recording (`Recording.videoJSON`) and shown in its Outputs.
struct VideoRecord: Codable, Equatable, Sendable {
    var fileName: String
    var captionsName: String
    var duration: Double
    var bytes: Int64
    var frames: Int
    var renderSeconds: Double
    var checklist: [ChecklistLine]
    var madeAt: Date
    /// The plan it was made from, in one line, and who was applied.
    var planSummary: String
    var peopleSignature: String
    var loudness: Double?
    var truePeak: Double?

    var failed: Int { checklist.filter { $0.status == .fail }.count }
    var missing: Int { checklist.filter { $0.status == .missing }.count }
    var passed: Int { checklist.filter { $0.status == .pass }.count }

    var summary: String {
        var parts: [String] = []
        if failed > 0 { parts.append("\(failed) failed") }
        if missing > 0 { parts.append("\(missing) missing") }
        return parts.isEmpty ? "Every line passes" : parts.joined(separator: ", ") + ", \(passed) passed"
    }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String?) -> VideoRecord? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(VideoRecord.self, from: data)
    }
}

enum VideoStep {
    static let folderName = "Video"
    /// The hidden folder a video is made in, inside the make's staging folder.
    static let stagingName = ".video"

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    struct Setup: Sendable {
        var original: URL
        var plan: EditPlan
        /// transcript.json, which the plan was made from.
        var transcript: URL
        /// The make's own staging folder: the video is made in `<staging>/.video` and admitted to `<staging>/Video`.
        var staging: URL
        /// The recording's title and notes as Ivan set them, and the writing step's package when it ran.
        var title: String
        var notes: String
        var written: WrittenPackage?
        /// Where the writer's chapter times are on the original's clock.
        var writtenToOriginal: @Sendable (Double) -> Double?
        var recordedAt: Date?
        var label: String
        var people: OutputGate.People
    }

    /// What `make` leaves for `check`.
    struct Made: Sendable {
        let folder: URL
        let mp4: URL
        let srt: URL
        let description: VideoDescription
        let timeline: EditTimeline
        let renderSize: CGSize
        let frames: Int
        let renderSeconds: Double
        let audio: VideoAudio.Made
        /// The furthest a caption starts after its first word (`Captions.Cue.behind`).
        let captionsBehind: Double
    }

    /// The file's name: the recording's title, else its date (`PodcastPackage.safe`, ASCII and no reserved characters).
    static func baseName(title: String, recordedAt: Date?) -> String {
        let safe = PodcastPackage.safe(title)
        return safe.isEmpty ? PodcastPackage.isoDate(recordedAt) : safe
    }

    /// "Making the video": the sound, the picture through the compositor, the captions and the description, into the hidden
    /// staging folder. `ffmpeg` runs ffmpeg and returns its stderr; `progress` gets 0 to 1.
    static func make(_ setup: Setup, ffmpeg: @escaping @Sendable ([String]) async throws -> String,
                     progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Made {
        if let refusal = OutputGate.refusal(setup.people) { throw Failure(reason: refusal) }
        guard let data = try? Data(contentsOf: setup.transcript), let words = PlanWords.from(json: data) else {
            throw Failure(reason: "The words with their times (transcript.json) could not be read, so no video was made.")
        }
        let problems = PlanValidation.check(setup.plan, words: words)
        if let first = problems.first {
            throw Failure(reason: "The edit plan did not pass its own check (rule \(first.rule): \(first.line)), so no video was made from it.")
        }
        let fm = FileManager.default
        let folder = setup.staging.appending(path: stagingName, directoryHint: .isDirectory)
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let job = setup.staging.appending(path: ".video-job", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: job) }

        let built: CompositionBuilder.Built
        do {
            built = try await CompositionBuilder.build(plan: setup.plan, original: setup.original)
        } catch let failure as CompositionBuilder.Failure {
            throw Failure(reason: failure.reason)
        }
        progress(0.02)
        let audio: VideoAudio.Made
        do {
            audio = try await VideoAudio.make(original: setup.original, timeline: built.timeline, mutes: setup.plan.people.mutes, job: job, tool: ffmpeg)
        } catch let failure as VideoAudio.Failure {
            throw Failure(reason: failure.reason)
        }
        progress(0.1)
        let base = baseName(title: setup.title, recordedAt: setup.recordedAt)
        let mp4 = folder.appending(path: base + ".mp4"), srt = folder.appending(path: base + ".srt")
        let written: VideoWriter.Written
        do {
            written = try await VideoWriter.write(built, wav: audio.wav, to: mp4, settings: .standard(height: Int(built.renderSize.height)),
                                                  progress: { progress(0.1 + 0.9 * $0) })
        } catch let failure as VideoWriter.Failure {
            throw Failure(reason: failure.reason)
        }
        try? fm.removeItem(at: audio.wav)

        let cues = Captions.cues(Captions.words(plan: setup.plan, words: words, timeline: built.timeline), duration: built.timeline.duration)
        try Captions.srt(cues).write(to: srt, atomically: true, encoding: .utf8)
        let description = VideoDescription.make(title: setup.title, notes: setup.notes, written: setup.written, toOriginal: setup.writtenToOriginal,
                                                timeline: built.timeline)
        try description.text.write(to: folder.appending(path: VideoDescription.fileName), atomically: true, encoding: .utf8)
        return Made(folder: folder, mp4: mp4, srt: srt, description: description, timeline: built.timeline, renderSize: built.renderSize,
                    frames: written.frames, renderSeconds: written.seconds, audio: audio, captionsBehind: cues.map(\.behind).max() ?? 0)
    }

    /// "Checking the video": every line of the Ready checklist measured from the files, written beside them, then the
    /// folder through `OutputGate` into `<staging>/Video`. A refusal deletes the folder and throws.
    static func check(_ made: Made, setup: Setup, ffprobe: @escaping @Sendable ([String]) async throws -> String,
                      ffmpeg: @escaping @Sendable ([String]) async throws -> String, now: Date) async throws -> VideoRecord {
        let measured = await ReadyChecklist.measure(mp4: made.mp4, srt: made.srt, ffprobe: ffprobe, ffmpeg: ffmpeg)
        let frame = made.timeline.frame
        let expected = ReadyChecklist.Expected(width: Int(made.renderSize.width), height: Int(made.renderSize.height),
                                               frameRate: "\(frame.timescale)/\(frame.value)",
                                               videoBitrate: Double(VideoWriter.Settings.standard(height: Int(made.renderSize.height)).bitrate),
                                               duration: made.timeline.duration, frame: frame.seconds)
        let lines = ReadyChecklist.lines(measured, expected: expected, description: made.description, people: OutputGate.peopleLine(setup.people),
                                         captionsBehind: made.captionsBehind)
        try ReadyChecklist.text(lines, label: setup.label, fileName: made.mp4.lastPathComponent, madeAt: now)
            .write(to: made.folder.appending(path: ReadyChecklist.name), atomically: true, encoding: .utf8)
        let destination = setup.staging.appending(path: folderName, directoryHint: .isDirectory)
        do {
            try OutputGate.admit(staged: made.folder, to: destination, people: setup.people, measured: measured, expected: expected)
        } catch let refused as OutputGate.Refused {
            throw Failure(reason: refused.reason + " The video was not kept.")
        }
        return VideoRecord(fileName: made.mp4.lastPathComponent, captionsName: made.srt.lastPathComponent, duration: measured.videoDuration ?? made.timeline.duration,
                           bytes: measured.bytes, frames: made.frames, renderSeconds: made.renderSeconds, checklist: lines, madeAt: now,
                           planSummary: setup.plan.summary, peopleSignature: setup.plan.people.applied, loudness: measured.integratedLUFS,
                           truePeak: measured.truePeak)
    }
}
