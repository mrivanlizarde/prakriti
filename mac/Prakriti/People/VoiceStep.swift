import AVFoundation
import Foundation

// The voice step of the people pass (v2 part M6b, docs/v2/PLAN.md M6, research-people.md 2.5 and 2.6), run right
// after the face step in every make and by Check People. Who speaks when, as times only:
//
// - **Two or more audio tracks:** the OBS layout of help article 03, track 1 everything mixed and tracks 2 and up
//   one source each. Who speaks is which of tracks 2 and up is active (`TrackActivity`). The log says so.
// - **One track** (every studio file so far, START_HERE warnings 6 and 14): FluidAudio's diarizer on that track
//   (`Diarizer`), a best guess, so its changes of voice are listed to listen to.
//
// Then each voice is linked to a face (`SpeakerLink`) and the people file gains its voice part. The sound is decoded
// into the step's own job folder, read, and deleted with the folder when the step ends (Mac warning 113); nothing
// about anyone's voice but times is kept.

enum VoiceStep {
    struct Failure: Error, Sendable {
        let reason: String
    }

    struct Outcome: Sendable {
        var found: VoicesFound
    }

    /// Runs ffmpeg with these arguments and waits for it (the pipeline's own runner, with its pause and time limit).
    typealias Decode = @Sendable ([String]) async throws -> Void

    /// The audio tracks of `file`, read by AVFoundation (the capture check's count when it has one).
    static func audioTracks(_ file: URL) async -> Int {
        (try? await AVURLAsset(url: file).loadTracks(withMediaType: .audio).count) ?? 0
    }

    static func run(file: URL, recordingID: UUID, folders: PeopleFolders, audioTracks: Int, now: Date, decode: Decode,
                    control: ProcessControl? = nil, log: (@Sendable (String) -> Void)? = nil,
                    progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Outcome {
        let started = ContinuousClock.now
        guard var people = folders.read(recordingID) else {
            throw Failure(reason: "Faces were not looked for, so voices cannot be linked to them. Check People again.")
        }
        let job = try folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        let duration = people.duration

        var segments: [VoiceSegment] = []
        var source = VoicesFound.Source.tracks
        var trackOf: [Int: Int] = [:]
        if audioTracks >= 2 {
            // Tracks 2 and up, each one microphone (help article 03). ffmpeg numbers audio streams from 0.
            let numbers = Array(2...audioTracks)
            var arguments = ["-y", "-v", "error", "-i", file.path]
            for n in numbers {
                arguments += ["-map", "0:a:\(n - 1)", "-ac", "1", "-ar", "16000", "-f", "f32le", job.appending(path: "track-\(n).raw").path]
            }
            try await decode(arguments)
            progress(0.3)
            var levels: [Int: [Double]] = [:]
            for n in numbers {
                let data = try Data(contentsOf: job.appending(path: "track-\(n).raw"), options: .alwaysMapped)
                levels[n] = data.withUnsafeBytes { raw in TrackActivity.levels(raw.bindMemory(to: Float.self)) }
                try? FileManager.default.removeItem(at: job.appending(path: "track-\(n).raw"))
            }
            segments = TrackActivity.segments(levels: levels)
            for n in numbers { trackOf[n] = n }
            log?("Who speaks is read from microphone tracks \(numbers.map(String.init).joined(separator: ", ")), not guessed from the mix: "
                 + "\(Format.count(Set(segments.map(\.voice)).count, "track")) with a voice.")
        }
        if audioTracks >= 1 && (audioTracks == 1 || segments.isEmpty) {
            // One mixed track, or microphone tracks with no one on them: the diarizer on track 1.
            if audioTracks >= 2 { log?("No microphone track holds a voice, so voices are told apart on track 1 instead.") }
            source = .diarizer
            trackOf = [:]
            let mix = job.appending(path: "mix.raw")
            try await decode(["-y", "-v", "error", "-i", file.path, "-map", "0:a:0", "-ac", "1", "-ar", "16000", "-f", "f32le", mix.path])
            progress(0.2)
            let samples: [Float] = try Data(contentsOf: mix, options: .alwaysMapped).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
            try? FileManager.default.removeItem(at: mix)
            segments = try await Diarizer.diarize(samples, progress: { progress(0.2 + 0.5 * $0) })
            log?("Who speaks is told apart on the one mixed track by FluidAudio's diarizer, so it is a best guess.")
        }
        progress(0.7)
        var made = VoicesFound.from(segments: segments, source: source, tracks: trackOf, duration: duration, checkedAt: now)

        // Link each voice to a face: the only face on screen, and mouths on stretches with two or more faces.
        let crowded = SpeakerLink.crowdedStretches(people.tracks, every: people.every)
        let mouths = people.hasPicture && !made.found.voices.isEmpty
            ? try await SpeakerLink.measureMouths(file: file, stretches: crowded, tracks: people.tracks, control: control,
                                                  progress: { progress(0.7 + 0.28 * $0) })
            : [:]
        let links = SpeakerLink.link(tracks: people.tracks, segments: made.segments, voices: made.found.voices.map(\.id),
                                     mouths: mouths, every: people.every)
        for index in made.found.voices.indices {
            if let link = links[made.found.voices[index].id] {
                made.found.voices[index].face = link.face
                made.found.voices[index].linkedBy = link.by
            }
        }
        let elapsed = ContinuousClock.now - started
        made.found.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18

        people.voices = PeopleFile.Voices(source: source.rawValue, tracks: made.found.tracksUsed,
                                          segments: made.segments.map { [$0.start, $0.end, Double($0.voice)] },
                                          links: links.sorted { $0.key < $1.key }.map { [$0.key, $0.value.face] })
        if !people.steps.contains("voices") { people.steps.append("voices") }
        try people.save(in: folders, job: job)
        progress(1)
        return Outcome(found: made.found)
    }
}
