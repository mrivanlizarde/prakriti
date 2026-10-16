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
        /// The moments from other recordings Ivan added (v2 part M12b), each read again from its own recording for this plan.
        var moments: [MomentInsert] = []
    }

    struct Outcome: Sendable {
        let plan: EditPlan
        let seconds: Double
        /// What placing the moments from other recordings did (v2 part M12b), for the log.
        var notes: [String] = []
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
        // Only when it is still there: measured 16 Oct (Swift 6.4), a `try? removeItem` in this defer of a file already removed below
        // replaced a refusal thrown later in the step with the remove's own error.
        defer { if FileManager.default.fileExists(atPath: raw.path) { try? FileManager.default.removeItem(at: raw) } }
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
        // The held moment (v2 part M9d, research 2.3): whole sentences of the main point's beat, kept as recorded and still. Only
        // for a recording with a picture and beats, in a style that holds one. Chosen before the parts are, so the length a
        // direction asks for is measured with it: the main point is always kept (`Selection`).
        let picture = setup.frameRate != nil && setup.pictureHeight > 0
        var momentNotes: [String] = []
        var held: TimeRange?
        if picture, let range = style.held, let all = setup.beats?.beats, !all.isEmpty {
            var forced = setup.people.cuts + input.edits.cuts
            if let s = input.edits.start { forced.append(TimeRange(start: 0, end: s)) }
            if let e = input.edits.end { forced.append(TimeRange(start: e, end: setup.duration)) }
            held = HeldMoment.choose(beats: all, kept: Set(all.map(\.id)), words: words.words, starts: cut.refinedStart, ends: cut.refinedEnd,
                                     range: range, forced: forced)
            if let h = held {
                input.held = [h]
                let again = RoughCut.make(input)
                if again.kept.isEmpty { input.held = []; held = nil } else { cut = again }
            }
        }
        // Choosing beats under the direction (v2 part M9c): what the rough cut keeps of each beat is what it costs; the parts
        // left out are cut like Ivan's own cuts, from the middle of the pause before to the middle of the pause after.
        var choice: EditPlan.BeatChoice?
        var keptBeats: [Beat] = []
        if let beatsFile = setup.beats, fields.needsBeats, !beatsFile.beats.isEmpty {
            let beats = beatsFile.beats
            // The ending's room and the opening line (v2 part M9d) are added after the selection, so the budget leaves room for
            // them and a second.
            let room = style.endingSeconds + 1 + (style.opening?.upperBound ?? 0)
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
                let over = cut.keptSeconds + style.endingSeconds + (style.opening?.upperBound ?? 0) - target
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
        plan.held = held.map { TimeRange(start: EditPlan.round3($0.start), end: EditPlan.round3($0.end)) }
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
        if picture {
            let refined = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            // The opening line (v2 part M9d): the strongest self-contained line, played first, made of the talk's own kept spans.
            if let range = style.opening, !keptBeats.isEmpty,
               let hook = Hook.choose(.init(spans: plan.spans, times: refined, words: words.words, envelope: envelope, frame: frame, beats: keptBeats,
                                            range: range, pause: style.sentenceTarget)) {
                // The talk now starts after the opening line, at a join: its first span keeps half a sentence's pause before its
                // first word, not the half second of room a video's very start keeps (measured 15 Oct: 0.55 s of silence at 0:07 of
                // the 6 Sep Energetic video, over its 0.35 s trigger). The silence before it goes with the trimmed start.
                if let first = plan.spans.first, let start = refined[first.from]?.in,
                   let t = Hook.quiet(from: first.in, to: start - style.leadIn, near: start - max(0.08, style.sentenceTarget / 2),
                                      .init(spans: [], times: [:], words: [], envelope: envelope, frame: frame, beats: [], range: range)), t > first.in + frame.seconds / 2 {
                    let old = first.in
                    plan.spans[0].in = EditPlan.round6(t)
                    if let k = plan.removed.firstIndex(where: { abs($0.to - old) < 1e-6 }) { plan.removed[k].to = plan.spans[0].in }
                }
                plan.spans = hook.spans + plan.spans
            }
            // The words to put on screen (v2 part M9d): each kept part's key phrase, and the word list's terms it explains.
            var text = setup.text
            text.showTitle = text.showTitle && house.titleOnScreen
            text.showNames = text.showNames && house.namesOnScreen
            text.keyPhraseEvery = style.keyPhraseEvery
            text.held = plan.held
            text.keyPhrases = Self.keyPhrases(keptBeats, words: words.words, refined: refined)
            text.terms = style.termCards ? Self.terms(keptBeats, words: words.words, refined: refined) : []
            let minutes = plan.keptSeconds / 60
            let phraseRoom = style.keyPhraseEvery.map { Int((minutes * 60 / $0.lowerBound).rounded(.down)) } ?? 0
            let expectedText = min(text.keyPhrases.count, phraseRoom) + Set(text.terms.map { $0.text.lowercased() }).count
                + (text.showTitle && !text.title.isEmpty ? 1 : 0) + (text.showNames ? text.teachers.count : 0)
            plan.visual = VisualPlan.make(.init(plan: plan, words: words.words, style: style, subject: setup.subject,
                                                sourceHeight: setup.pictureHeight, outputHeight: setup.pictureHeight,
                                                beatStarts: keptBeats.dropFirst().map { refined[$0.from]?.in ?? $0.start },
                                                keyLines: keptBeats.compactMap { b in b.keyLine.map { refined[$0.from]?.in ?? b.start } },
                                                held: plan.held, textChanges: expectedText))
            // The text on screen (v2 part M9b), placed after the punch-ins so it is kept clear of every face as framed.
            var items = TextPlan.make(plan: plan, setup: text, pictureHeight: setup.pictureHeight)
            // White text over a bright picture is placed again, that stretch kept clear like a face (`TextLight`, v2 part M9d).
            for _ in 0..<TextLight.rounds where !items.isEmpty {
                var placed = plan
                placed.visual += items
                let bright = await TextLight.bright(items, plan: placed, original: setup.original)
                guard !bright.isEmpty else { break }
                for (_, box, times) in bright { text.faces += times.map { FaceSpot(time: $0, box: box) } }
                text.faces.sort { $0.time < $1.time }
                items = TextPlan.make(plan: plan, setup: text, pictureHeight: setup.pictureHeight)
            }
            if !items.isEmpty {
                plan.visual = (plan.visual + items).sorted { ($0.in ?? .infinity, $0.kind) < ($1.in ?? .infinity, $1.kind) }
            }
            // Chapters (v2 part M9d), from the kept parts, on the video's own clock.
            plan.chapters = Chapters.make(plan: plan, beats: keptBeats, words: words.words)
            // The moments Ivan added (v2 part M12b), last, so nothing planned above reads another recording's frames as this one's.
            // A moment that may not be used now (someone in it hidden since, its recording gone) stops the plan: no video is made.
            if !setup.moments.isEmpty {
                let size = CGSize(width: setup.text.pictureWidth > 0 ? setup.text.pictureWidth : setup.pictureHeight * 16 / 9, height: setup.pictureHeight)
                do {
                    momentNotes = try MomentInserts.place(setup.moments, into: &plan, words: words.words, pictureSize: size)
                } catch let refusal as MomentInserts.Refusal {
                    throw Failure(reason: refusal.reason)
                }
                // The colour match (research 2.8), measured on the two pictures around where each moment goes.
                for k in plan.spans.indices where plan.spans[k].isInsert {
                    let span = plan.spans[k]
                    guard let file = span.sourceFile else { continue }
                    var around: [TimeRange] = []
                    if let before = plan.spans[..<k].last(where: { !$0.isInsert }) { around.append(TimeRange(start: max(before.in, before.out - 10), end: before.out)) }
                    if let after = plan.spans[(k + 1)...].first(where: { !$0.isInsert }) { around.append(TimeRange(start: after.in, end: min(after.out, after.in + 10))) }
                    plan.spans[k].colour = await MomentInserts.colour(main: setup.original, around: around, source: URL(fileURLWithPath: file),
                                                                      moment: TimeRange(start: span.in, end: span.out))
                    momentNotes.append("Colour match for the moment from \(span.sourceDate.map { Format.dayLabel($0) } ?? "another day"): "
                                       + (plan.spans[k].colour.map { "red, green and blue times " + $0.map { String(format: "%.3f", $0) }.joined(separator: ", ") } ?? "none needed") + ".")
                }
            }
        } else if !setup.moments.isEmpty {
            momentNotes.append("Moments from other recordings go only into a video, and this recording has no picture.")
        }
        plan.planLines = Self.lines(plan, style: style, beats: setup.beats?.beats ?? [], choice: choice)
        let problems = PlanValidation.check(plan, words: words, inserts: setup.moments)
        if let first = problems.first {
            throw Failure(reason: "The plan did not pass its own check (rule \(first.rule): \(first.line)), so it was not saved.")
        }
        let d = clock.now - started
        return Outcome(plan: plan, seconds: Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18, notes: momentNotes)
    }

    /// Each kept part's key phrase as words to show (v2 part M9d): its words as said, the full stop or comma at the end left off.
    static func keyPhrases(_ beats: [Beat], words: [PlanWord], refined: [String: EditPlan.WordTime]) -> [TextPlan.Moment] {
        beats.compactMap { beat in
            guard let phrase = beat.keyPhrase, let a = PlanWord.index(of: phrase.from), let b = PlanWord.index(of: phrase.to), a <= b, b < words.count else { return nil }
            let shown = PlanWords.text(words[a...b]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;: \u{201C}\u{201D}\""))
            // Ivan's copy rules hold for words on screen too (`CopyRules`): a phrase naming money, a price or an offer is not shown.
            guard !shown.isEmpty, CopyRules.flag(shown) == nil else { return nil }
            return TextPlan.Moment(from: phrase.from, to: phrase.to, start: refined[phrase.from]?.in ?? words[a].start, end: refined[phrase.to]?.out ?? words[b].end,
                                   text: shown, rank: Hook.rank(beat), words: b - a + 1)
        }
    }

    /// The word list's terms each kept part explains (v2 part M9d), where the term is first said in it, spelled as the list spells
    /// it (first letter capital). A term the model named that the list does not hold is never shown.
    static func terms(_ beats: [Beat], words: [PlanWord], refined: [String: EditPlan.WordTime]) -> [TextPlan.Moment] {
        var out: [TextPlan.Moment] = []
        for beat in beats {
            guard let a = PlanWord.index(of: beat.from), let b = PlanWord.index(of: beat.to), a <= b, b < words.count else { continue }
            for said in beat.terms {
                guard let term = Lexicon.term(said), let i = (a...b).first(where: { Lexicon.term(words[$0].text) == term }) else { continue }
                out.append(TextPlan.Moment(from: words[i].id, to: words[i].id, start: refined[words[i].id]?.in ?? words[i].start,
                                           end: refined[words[i].id]?.out ?? words[i].end, text: term.prefix(1).uppercased() + term.dropFirst(), rank: 0, words: 1))
            }
        }
        return out
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
        // What the parts of the talk add (v2 part M9d), in numbers only.
        if let hook = plan.hook, let first = plan.words.first(where: { $0.id == hook.from }) {
            lines.append(String(format: "Opens on a line from %@ (%.0f s), then the title and the talk from its start.", Format.timecode(first.in), hook.seconds))
        }
        let phrases = plan.visual.filter { $0.kind == EditPlan.Visual.keyPhrase }.count, terms = plan.visual.filter { $0.kind == EditPlan.Visual.term }.count
        if phrases + terms > 0 {
            var parts: [String] = []
            if phrases > 0 { parts.append(Format.count(phrases, "key phrase") + " in the speaker's own words") }
            if terms > 0 { parts.append(Format.count(terms, "term") + " from the word list") }
            lines.append("On screen: " + EditPlan.joined(parts) + ".")
        }
        if let held = plan.held {
            lines.append(String(format: "Holds one still shot for %.0f s from %@, the main point, uncut.", held.end - held.start, Format.timecode(held.start)))
        }
        if !plan.chapters.isEmpty { lines.append(Format.count(plan.chapters.count, "chapter") + " for YouTube, the first at 0:00.") }
        // The moments Ivan added (v2 part M12b).
        for span in plan.insertSpans {
            guard let piece = timeline.pieces.first(where: { $0.id == span.id }) else { continue }
            lines.append(String(format: "Adds your moment from %@ (%.0f s) at %@, with %@.", span.sourceDate.map { Format.dayLabel($0) } ?? "another day",
                                timeline.seconds(piece.frames), Format.timecode(timeline.seconds(piece.editFrame)),
                                (span.join ?? 0) > 0 ? "a \(span.join ?? 0)-frame dissolve at each end" : "a cut at each end"))
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
