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
        var people = EditPlan.People()
        var signature = ""
        var preset = RoughCutPreset.clear
    }

    struct Outcome: Sendable {
        let plan: EditPlan
        let seconds: Double
        var stepLine: String { plan.summary }
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
        let input = RoughCut.Input(words: words, envelope: envelope, duration: setup.duration, frame: frame, edits: setup.edits,
                                   leftOut: setup.people.cuts, preset: setup.preset)
        let cut = RoughCut.make(input)
        guard !cut.kept.isEmpty else {
            throw Failure(reason: "Nothing would be left after the trim, the cuts and the people left out, so no plan was made.")
        }
        let name = setup.original.deletingPathExtension().lastPathComponent
        let plan = EditPlan.from(cut, words: words, input: input, recording: name, people: setup.people, signature: setup.signature, madeAt: now)
        let problems = PlanValidation.check(plan, words: words)
        if let first = problems.first {
            throw Failure(reason: "The plan did not pass its own check (rule \(first.rule): \(first.line)), so it was not saved.")
        }
        let d = clock.now - started
        return Outcome(plan: plan, seconds: Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18)
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
