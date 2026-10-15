import Foundation

// "Planning the edit" (v2 part M8a): the step that writes `edit-plan.json`. It runs in a make (`PipelineStep.planEdit`)
// and on its own (Plan the Edit, `AppModel.planEdit`), and both call `PlanStep.run`. It reads transcript.json and the
// original's first audio track, decoded once into the job folder it is given and deleted before it returns, and writes
// nothing else. No model is asked anything and nothing leaves the Mac.
//
// A plan that fails `PlanValidation` is not written: the step stops with the rule and the place, and the last good plan,
// if there is one, stays where it was (the caller writes through a staging folder).

enum PlanStep {
    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    struct Setup: Sendable {
        var original: URL
        var transcript: URL
        /// Where the decoded sound goes while the step runs.
        var jobFolder: URL
        var duration: Double
        /// The video's frame rate, or nil for sound alone.
        var frameRate: Double?
        var edits = EpisodeEdits()
        /// Stretches Ivan restored from the Viewer (v2 part M8c): kept as recorded.
        var restored: [TimeRange] = []
        var people = EditPlan.People()
        var signature = ""
        /// The House Style (v2 part M9a): the style's pause numbers for the rough cut and its punch-ins, push-ins and ending
        /// for the picture.
        var house = HouseStyle.standard
        /// The face the punch-ins follow (the teacher's, else the included face seen most), from the people check; empty
        /// keeps every shot wide.
        var subject: [FaceSpot] = []
        /// The source picture's height in pixels (0 for sound alone: no picture to frame).
        var pictureHeight: Double = 0
        /// The title and the teachers' names on screen (v2 part M9b): Ivan's title, the teachers he named and every face seen.
        var text = TextPlan.Setup()
        /// Ivan's direction for this recording (v2 part M9c), and what it was read as (the rules, and the model's reading of
        /// what they could not read, made before the step). Nil reading: read here by the rules alone.
        var direction = RecordingDirection()
        var reading: DirectionReading?
        /// The recording's beats (v2 part M9c), when the direction needs them: a length, a focus, something to leave out.
        var beats: BeatsFile?
    }

    struct Outcome: Sendable {
        let plan: EditPlan
        let seconds: Double
        /// The step's line: what the plan keeps, then the plan in plain lines (v2 part M9c), which the progress block shows
        /// while the video is made. Numbers only, never a name.
        var stepLine: String { ([plan.summary] + (plan.planLines ?? [])).joined(separator: " ") }
    }

    /// Decodes the sound, cuts, builds and checks the plan. `decode` runs ffmpeg with the arguments it is given.
    static func run(_ setup: Setup, now: Date, decode: @Sendable ([String]) async throws -> Void) async throws -> Outcome {
        let clock = ContinuousClock()
        let started = clock.now
        guard let data = try? Data(contentsOf: setup.transcript), let words = PlanWords.from(json: data), !words.words.isEmpty else {
            throw Failure(reason: "The words with their times (transcript.json) could not be read, so the edit could not be planned.")
        }
        try FileManager.default.createDirectory(at: setup.jobFolder, withIntermediateDirectories: true)
        let raw = setup.jobFolder.appending(path: "plan-sound.f32")
        defer { try? FileManager.default.removeItem(at: raw) }
        try await decode(Envelope.decodeArguments(file: setup.original, raw: raw))
        let envelope = try Envelope.read(rawFloats: raw)
        try? FileManager.default.removeItem(at: raw)
        guard envelope.levels.count > 10 else {
            throw Failure(reason: "The sound could not be read, so the edit could not be planned.")
        }
        let frame = setup.frameRate.map { FrameDuration(rate: $0) } ?? .audioOnly
        // The direction (v2 part M9c): the House Style with the direction laid over it.
        let reading = setup.reading ?? Direction.read(setup.direction, house: setup.house)
        let fields = reading.fields
        let house = Direction.house(setup.house, fields: fields, pace: setup.direction.pace)
        let length: Length = fields.targetSeconds.map { .about(minutes: $0 / 60) } ?? .whole
        let style = Direction.style(setup.house, fields: fields, pace: setup.direction.pace, length: length)
        var input = RoughCut.Input(words: words, envelope: envelope, duration: setup.duration, frame: frame, edits: setup.edits,
                                   leftOut: setup.people.cuts, restored: setup.restored, preset: style.roughCut)
        var cut = RoughCut.make(input)
        guard !cut.kept.isEmpty else {
            throw Failure(reason: "Nothing would be left after the trim, the cuts and the people left out, so no plan was made.")
        }
        // Choosing beats under the direction (v2 part M9c): what the rough cut keeps of each beat is what it costs; the parts
        // left out are cut like Ivan's own cuts, from the middle of the pause before to the middle of the pause after.
        var choice: EditPlan.BeatChoice?
        var keptBeats: [Beat] = []
        if let beatsFile = setup.beats, fields.needsBeats, !beatsFile.beats.isEmpty {
            let beats = beatsFile.beats
            // The ending's room is added after the selection, so the budget leaves room for it and a second.
            let room = style.endingSeconds + 1
            var budget = fields.targetSeconds.map { max(0, $0 - room) }
            var outcome = Selection.Outcome(kept: beats.map(\.id), dropped: [], keptSeconds: 0, value: 0, overBudget: false)
            // What each beat costs is measured once, on the cut before anything is left out.
            let kept = Self.keptSeconds(beats, cut: cut)
            for _ in 0..<4 {
                outcome = Selection.choose(.init(beats: beats, keptSeconds: kept, budget: budget, fields: fields), words: words.words)
                input.dropped = Self.ranges(of: outcome.dropped, beats: beats, words: words.words, duration: setup.duration)
                cut = RoughCut.make(input)
                // Joins change what a beat keeps by a little: when the cut runs over the length, the budget comes down by as
                // much and the beats are chosen again.
                guard let target = fields.targetSeconds, let b = budget else { break }
                let over = cut.keptSeconds + style.endingSeconds - target
                if over <= 0 || outcome.overBudget { break }
                budget = max(0, b - over - 0.5)
            }
            guard !cut.kept.isEmpty else {
                throw Failure(reason: "Nothing would be left after the parts your direction leaves out, so no plan was made.")
            }
            choice = EditPlan.BeatChoice(by: beatsFile.by, beats: beats.count, kept: outcome.kept, dropped: outcome.dropped,
                                         targetSeconds: fields.targetSeconds, overBudget: outcome.overBudget)
            keptBeats = beats.filter { outcome.kept.contains($0.id) }
        } else if let beatsFile = setup.beats {
            keptBeats = beatsFile.beats
        }
        let name = setup.original.deletingPathExtension().lastPathComponent
        var plan = EditPlan.from(cut, words: words, input: input, recording: name, people: setup.people, signature: setup.signature, madeAt: now)
        plan.basis.house = setup.house.signature
        plan.basis.direction = setup.direction.signature
        plan.style = style.name.rawValue
        plan.modifiers.teaching = house.teaching
        plan.modifiers.pace = house.pace.rawValue
        plan.modifiers.targetSeconds = fields.targetSeconds
        plan.beatChoice = choice
        if !setup.direction.isEmpty || !setup.direction.removed.isEmpty {
            plan.direction = EditPlan.Direction(prompt: setup.direction.trimmedPrompt, chips: reading.chips.map(\.text), presets: setup.direction.presets,
                                                pace: setup.direction.pace, length: setup.direction.length, reading: reading)
        }
        // A part the direction leaves out says which part it is.
        if let beatsFile = setup.beats, choice != nil {
            for i in plan.removed.indices where plan.removed[i].kind == .beat {
                let r = plan.removed[i]
                if let beat = beatsFile.beats.max(by: { overlap($0, r) < overlap($1, r) }), overlap(beat, r) > 0, !beat.summary.isEmpty {
                    plan.removed[i].say = "A part your direction leaves out, \(Format.length(r.to - r.from)): \u{201C}\(beat.summary)\u{201D}."
                }
            }
        }
        // The picture (v2 part M9a): punch-ins, push-ins and the held ending, only for a recording with a picture.
        if setup.frameRate != nil && setup.pictureHeight > 0 {
            let refined = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            plan.visual = VisualPlan.make(.init(plan: plan, words: words.words, style: style, subject: setup.subject,
                                                sourceHeight: setup.pictureHeight, outputHeight: setup.pictureHeight,
                                                beatStarts: keptBeats.dropFirst().map { refined[$0.from]?.in ?? $0.start },
                                                keyLines: keptBeats.compactMap { b in b.keyLine.map { refined[$0.from]?.in ?? b.start } }))
            // The text on screen (v2 part M9b), placed after the punch-ins so it is kept clear of every face as framed.
            var text = setup.text
            text.showTitle = text.showTitle && house.titleOnScreen
            text.showNames = text.showNames && house.namesOnScreen
            let items = TextPlan.make(plan: plan, setup: text, pictureHeight: setup.pictureHeight)
            if !items.isEmpty {
                plan.visual = (plan.visual + items).sorted { ($0.in ?? .infinity, $0.kind) < ($1.in ?? .infinity, $1.kind) }
            }
        }
        plan.planLines = Self.lines(plan, style: style, beats: setup.beats?.beats ?? [], choice: choice)
        let problems = PlanValidation.check(plan, words: words)
        if let first = problems.first {
            throw Failure(reason: "The plan did not pass its own check (rule \(first.rule): \(first.line)), so it was not saved.")
        }
        let d = clock.now - started
        return Outcome(plan: plan, seconds: Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18)
    }

    /// How much of a beat and a removed stretch overlap, in seconds.
    static func overlap(_ beat: Beat, _ r: EditPlan.Item) -> Double {
        max(0, min(beat.end, r.to) - max(beat.start, r.from))
    }

    /// What the rough cut keeps of each beat, in seconds: its kept spans' time inside the beat's words.
    static func keptSeconds(_ beats: [Beat], cut: RoughCut) -> [String: Double] {
        var out: [String: Double] = [:]
        for beat in beats {
            guard let a = PlanWord.index(of: beat.from), let b = PlanWord.index(of: beat.to), a < cut.refinedStart.count, b < cut.refinedEnd.count else { continue }
            let from = a == 0 ? 0 : cut.refinedStart[a], to = cut.refinedEnd[b]
            out[beat.id] = cut.kept.reduce(0) { $0 + max(0, min($1.end, to) - max($1.start, from)) }
        }
        return out
    }

    /// The time each beat left out takes, on the original's clock: from the middle of the pause before its first word to the
    /// middle of the pause after its last (the start and the end of the recording at the ends), so each join falls in a pause.
    static func ranges(of dropped: [String], beats: [Beat], words: [PlanWord], duration: Double) -> [TimeRange] {
        let set = Set(dropped)
        return beats.filter { set.contains($0.id) }.compactMap { beat in
            guard let a = PlanWord.index(of: beat.from), let b = PlanWord.index(of: beat.to), a <= b, b < words.count else { return nil }
            let start = a == 0 ? 0 : (words[a - 1].end + words[a].start) / 2
            let end = b == words.count - 1 ? duration : (words[b].end + words[b + 1].start) / 2
            return end > start ? TimeRange(start: start, end: end) : nil
        }
    }

    /// The plan in plain lines (design spec 3.5.3, PLAN M9: "Cuts pauses longer than 0.4 s. Punch-ins about every 8 s. Keeps
    /// the story at 12:40. Ends at 11:48."). Numbers only, never a name.
    static func lines(_ plan: EditPlan, style: Style, beats: [Beat], choice: EditPlan.BeatChoice?) -> [String] {
        func s(_ x: Double) -> String {
            let r = (x * 100).rounded() / 100
            return (r == (r * 10).rounded() / 10 ? String(format: "%.1f", r) : String(format: "%.2f", r)) + " s"
        }
        var lines: [String] = []
        lines.append("Cuts pauses longer than \(s(style.insideTrigger)) inside a sentence and \(s(style.sentenceTrigger)) between sentences, "
                     + "down to \(s(style.insideTarget)) and \(s(style.sentenceTarget)).")
        let timeline = EditTimeline(plan: plan)
        let punches = plan.visual.filter { $0.kind == EditPlan.Visual.punchIn }.count
        let pushes = plan.visual.filter { $0.kind == EditPlan.Visual.pushIn }.count
        if punches > 0 {
            let every = Int((timeline.duration / Double(punches)).rounded())
            lines.append("Punch-ins about every \(every) s" + (pushes > 0 ? ", and \(Format.count(pushes, "slow push-in"))." : "."))
        } else if !plan.visual.isEmpty {
            lines.append(pushes > 0 ? "\(Format.count(pushes, "slow push-in")), no punch-ins." : "The whole picture throughout, no punch-ins.")
        }
        if let choice {
            let keptSet = Set(choice.kept)
            let left = beats.filter { !keptSet.contains($0.id) }
            var line = "Keeps \(choice.kept.count) of \(Format.count(choice.beats, "part")) of the talk"
            if !left.isEmpty { line += "; leaves out \(left.count) (\(Format.timecode(left.reduce(0) { $0 + $1.seconds })) of the recording)" }
            lines.append(line + ".")
            if let story = beats.first(where: { keptSet.contains($0.id) && ($0.kind == .story || $0.score(.story) >= 2) }) {
                lines.append("Keeps the story at \(Format.timecode(story.start)).")
            }
            if choice.overBudget, let target = choice.targetSeconds {
                lines.append("The parts that must stay (the main point, the close, what you asked to keep whole) run over \(Direction.minutes(target)) min.")
            }
        }
        lines.append("Ends at \(Format.timecode(timeline.duration)).")
        return lines
    }

    /// The first picture stream's frame rate (`r_frame_rate`), or nil for sound alone or a file ffprobe cannot read.
    static func frameRate(of file: URL, ffprobe: URL) async -> Double? {
        guard let out = try? await Subprocess.run(ffprobe, ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate",
                                                            "-of", "csv=p=0", file.path], timeout: .seconds(60)),
              case let text = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let parts = text.split(separator: "/").compactMap { Double($0) }
        guard parts.count == 2, parts[1] > 0, parts[0] > 0 else { return Double(text) }
        return parts[0] / parts[1]
    }

    /// Writes the plan into `folder` (a staging folder or a job folder).
    static func write(_ plan: EditPlan, into folder: URL) throws {
        try plan.encoded().write(to: folder.appending(path: EditPlan.fileName), options: .atomic)
    }
}
