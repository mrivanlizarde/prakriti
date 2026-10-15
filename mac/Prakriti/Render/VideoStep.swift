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
    /// When the plan it was made from was made (`EditPlan.madeAt`), so the Viewer plays the video from that plan and no
    /// other (v2 part M8c). Nil for a video made before M8c.
    var planMadeAt: Date?
    /// The stretches Ivan had restored when it was made (v2 part M8c), so Approve can wait for newer ones.
    var restored: [TimeRange]?
    /// Who the video hides and leaves out, and what its output checks found (v2 part M8d). Nil for a video made before M8d.
    var hiddenFaces: Int?
    var leftOutVoices: Int?
    var pictureCheck: PictureCheck?
    var soundCheck: AudioCheck?

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
        /// Who is hidden and left out, from the people check (v2 part M8d): the faces hidden in the video (`VideoHiding.plan`),
        /// the people check's tracks for the picture output check, and the voices for the sound output check. Empty when
        /// nobody is.
        var hiding = HidePlan()
        var faceTracks: [PictureOutputCheck.Track] = []
        var voiceSegments: [VoiceSegment] = []
        var folders: PeopleFolders?
        var control: ProcessControl?
        /// Tests only (PLAN M8 check 6, "with hiding switched off for that track in a test build"): the picture is drawn with
        /// nobody hidden while the gate still knows who should be, so the picture output check must stop it. Never set by the
        /// app.
        var hidingOffForTest = false
        /// Where the output checks write their details (times, boxes, counts; never a name): the make's log.
        var log: (@Sendable (String) -> Void)?
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
        /// The faces hidden in it (v2 part M8d), empty when nobody is.
        let hidden: HiddenFaces
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
        if OutputGate.hidden(setup.people).faces > 0 && setup.hiding.isEmpty {
            // Someone is set to be hidden but the people check's file holds no sighting of them: fail closed.
            throw Failure(reason: "Someone is set to be hidden in the video, but where their face is could not be read from the people check. Click Check People, then Make Again.")
        }
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

        // The faces hidden in the video (v2 part M8d): followed in order through the original before anything is drawn, so
        // the compositor (for the file and the Viewer alike) only looks them up.
        let pictureFrames = try await CompositionBuilder.pictureFrames(original: setup.original, plan: setup.plan)
        let timeline = EditTimeline(plan: setup.plan, pictureFrames: pictureFrames)
        let hidingShare = setup.hiding.isEmpty ? 0.0 : 0.25
        let hidden: HiddenFaces
        do {
            hidden = try await VideoHiding.make(original: setup.original, plan: setup.hidingOffForTest ? HidePlan() : setup.hiding, timeline: timeline, planMadeAt: setup.plan.madeAt,
                                                control: setup.control, progress: { progress(0.01 + hidingShare * $0) })
        } catch let failure as VideoHiding.Failure {
            throw Failure(reason: failure.reason)
        }
        let built: CompositionBuilder.Built
        do {
            built = try await CompositionBuilder.build(plan: setup.plan, original: setup.original, hidden: hidden)
        } catch let failure as CompositionBuilder.Failure {
            throw Failure(reason: failure.reason)
        }
        progress(0.02 + hidingShare)
        let audio: VideoAudio.Made
        do {
            audio = try await VideoAudio.make(original: setup.original, timeline: built.timeline, mutes: setup.plan.people.mutes, job: job, tool: ffmpeg)
        } catch let failure as VideoAudio.Failure {
            throw Failure(reason: failure.reason)
        }
        let afterSound = 0.1 + hidingShare * 0.9
        progress(afterSound)
        let base = baseName(title: setup.title, recordedAt: setup.recordedAt)
        let mp4 = folder.appending(path: base + ".mp4"), srt = folder.appending(path: base + ".srt")
        let written: VideoWriter.Written
        do {
            written = try await VideoWriter.write(built, wav: audio.wav, to: mp4, settings: .standard(height: Int(built.renderSize.height)),
                                                  progress: { progress(afterSound + (1 - afterSound) * $0) })
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
                    frames: written.frames, renderSeconds: written.seconds, audio: audio, captionsBehind: cues.map(\.behind).max() ?? 0,
                    hidden: hidden)
    }

    /// "Checking the video": every line of the Ready checklist measured from the files, and (v2 part M8d) the picture and sound
    /// output checks whenever someone is hidden or left out, written beside them, then the folder through `OutputGate` into
    /// `<staging>/Video`, and the hidden faces beside the plan. A refusal deletes the folder and throws.
    static func check(_ made: Made, setup: Setup, ffprobe: @escaping @Sendable ([String]) async throws -> String,
                      ffmpeg: @escaping @Sendable ([String]) async throws -> String, now: Date,
                      progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> VideoRecord {
        let measured = await ReadyChecklist.measure(mp4: made.mp4, srt: made.srt, ffprobe: ffprobe, ffmpeg: ffmpeg)
        let frame = made.timeline.frame
        let expected = ReadyChecklist.Expected(width: Int(made.renderSize.width), height: Int(made.renderSize.height),
                                               frameRate: "\(frame.timescale)/\(frame.value)",
                                               videoBitrate: Double(VideoWriter.Settings.standard(height: Int(made.renderSize.height)).bitrate),
                                               duration: made.timeline.duration, frame: frame.seconds)
        let (hiddenFaces, leftOut) = OutputGate.hidden(setup.people)
        // The picture output check: every face in the made file, five frames a second, is someone included.
        var picture: PictureCheck?
        if hiddenFaces > 0 {
            do {
                picture = try await PictureOutputCheck.run(mp4: made.mp4, timeline: made.timeline, hidden: made.hidden, tracks: setup.faceTracks, now: now,
                                                           control: setup.control, progress: { progress(0.1 + 0.4 * $0) })
                if let picture {
                    setup.log?(String(format: "faces seen again: %d frames, %d faces, %d someone included, %d not accounted for (%.1f s)",
                                      picture.frames, picture.faces, picture.included, picture.findings.count, picture.seconds))
                    for finding in picture.findings.prefix(20) {
                        setup.log?(String(format: "face at %.2f s of the video (%.2f s of the original), %@, box %.3f %.3f %.3f %.3f",
                                          finding.at, finding.original, finding.how, finding.box.x, finding.box.y, finding.box.width, finding.box.height))
                    }
                }
            } catch let failure as VideoHiding.Failure {
                try? FileManager.default.removeItem(at: made.folder)
                throw Failure(reason: failure.reason + " The video was not kept.")
            }
        }
        // The sound output check: the made file's sound told apart again; every voice in it is someone included.
        var sound: AudioCheck?
        if leftOut > 0, let folders = setup.folders {
            let clock = EpisodeClock(intro: 0, segments: made.timeline.pieces.map {
                Mastering.Span(start: made.timeline.seconds($0.sourceFrame), end: made.timeline.seconds($0.sourceFrame + $0.frames))
            })
            do {
                sound = try await AudioOutputCheck.run(original: setup.original, made: [.init(name: "the video", url: made.mp4, clock: clock)],
                                                       segments: setup.voiceSegments, leftOut: Set(setup.plan.people.leftOut), folders: folders, now: now,
                                                       decode: { arguments in _ = try await ffmpeg(arguments) }, log: setup.log)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try? FileManager.default.removeItem(at: made.folder)
                throw Failure(reason: "Who is heard in the made video could not be checked (\((error as? Diarizer.Failure)?.reason ?? error.localizedDescription)). The video was not kept.")
            }
        }
        progress(0.95)
        let lines = ReadyChecklist.lines(measured, expected: expected, description: made.description,
                                         people: OutputGate.peopleLine(setup.people, picture: picture, sound: sound),
                                         captionsBehind: made.captionsBehind)
        try ReadyChecklist.text(lines, label: setup.label, fileName: made.mp4.lastPathComponent, madeAt: now)
            .write(to: made.folder.appending(path: ReadyChecklist.name), atomically: true, encoding: .utf8)
        let destination = setup.staging.appending(path: folderName, directoryHint: .isDirectory)
        do {
            try OutputGate.admit(staged: made.folder, to: destination, people: setup.people, measured: measured, expected: expected,
                                 picture: picture, sound: sound)
        } catch let refused as OutputGate.Refused {
            throw Failure(reason: refused.reason + " The video was not kept.")
        }
        // The hidden faces, beside the plan, so the Viewer draws the video as it was made (warning 156).
        let hidingFile = setup.staging.appending(path: HiddenFaces.fileName)
        if made.hidden.isEmpty {
            try? FileManager.default.removeItem(at: hidingFile)
        } else {
            try made.hidden.write(into: setup.staging)
        }
        progress(1)
        return VideoRecord(fileName: made.mp4.lastPathComponent, captionsName: made.srt.lastPathComponent, duration: measured.videoDuration ?? made.timeline.duration,
                           bytes: measured.bytes, frames: made.frames, renderSeconds: made.renderSeconds, checklist: lines, madeAt: now,
                           planSummary: setup.plan.summary, peopleSignature: setup.plan.people.applied, loudness: measured.integratedLUFS,
                           truePeak: measured.truePeak, planMadeAt: setup.plan.madeAt,
                           restored: setup.plan.basis.restored, hiddenFaces: hiddenFaces, leftOutVoices: leftOut,
                           pictureCheck: picture, soundCheck: sound)
    }
}
