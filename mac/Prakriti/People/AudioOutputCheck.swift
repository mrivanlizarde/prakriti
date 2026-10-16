import Foundation

// The audio output check (v2 part M6c, docs/v2/PLAN.md M6, research-people.md 3.6 item 2): after a make that leaves
// someone out, the finished podcast files are listened to again, and every stretch of speech in them must be someone
// included. Anything else stops Approve with its time ("Speech at 0:31 sounds like Voice 2, whom you chose to leave
// out."), because a voice wrongly taken for another would otherwise reach the episode unheard.
//
// How, with no voice print kept of anyone (PLAN D2, Mac warning 118):
// 1. The original's first track is told apart again by FluidAudio's diarizer (`Diarizer.listen`), in memory, and each
//    of its voices is matched to the voice step's voices by when they speak (the most shared time over the time
//    either speaks), so each voice step voice gets an average embedding, held in memory for this check only.
// 2. Each finished file is told apart the same way. Each of its voices is compared with every voice of the original:
//    one that sounds most like a voice left out is a finding, at its first moment in the file.
// 3. Each stretch of speech in the file is also mapped back to the original's clock (`EpisodeClock.originalTime`): a
//    moment that falls where a left-out voice speaks in the original is a finding. By construction the cuts cover
//    every such moment, so this catches a file made without them.
// Every embedding is dropped when `run` returns; the job folder with the decoded sound is deleted when it ends.

/// What the audio output check found (stored in `PeopleApplied.check`): times and counts, never a print.
struct AudioCheck: Codable, Equatable, Sendable {
    struct Finding: Codable, Equatable, Sendable {
        /// The file it is in ("episode.mp3").
        var file: String
        /// Where in that file, in seconds.
        var at: Double
        /// How long that voice speaks in the file, in seconds.
        var seconds: Double
        /// The voice left out it sounds like, or is where in the original.
        var voice: Int
        /// "sounds like" or "is where".
        var how: String
    }

    var checkedAt: Date
    var files: [String] = []
    var findings: [Finding] = []
    /// Voices in the finished files, and how each matched (for the log and the BUILD-LOG): "file voice: best voice
    /// similarity, best included similarity".
    var matches: [String] = []
    /// Voices left out that no voice of the original could be matched to by sound, so were checked by time only.
    var timeOnly: [Int] = []
    var seconds: Double = 0

    var passed: Bool { findings.isEmpty }

    /// One plain sentence for the Checks tab and the step's line. Labels only, never a name.
    func line(label: (Int) -> String) -> String {
        guard let first = findings.first else {
            return "Listened to again: everyone heard in " + (files.count == 1 ? "the episode" : "the episodes") + " is someone you included."
                + (timeOnly.isEmpty ? "" : " \(timeOnly.map(label).joined(separator: " and ")) could only be checked by time.")
        }
        let more = findings.count > 1 ? " \(Format.count(findings.count - 1, "more moment")) too." : ""
        return "Speech at \(Format.timecode(first.at)) in \(first.file) \(first.how) \(label(first.voice)), whom you chose to leave out." + more
    }
}

enum AudioOutputCheck {
    /// A file voice speaking for less than this in all is not judged by sound: too little to compare.
    static let shortest = 1.0
    /// A moment of file speech counts as where a left-out voice speaks when it lands this far inside that stretch.
    static let inside = 0.15

    /// Runs ffmpeg with these arguments and waits for it.
    typealias Decode = @Sendable ([String]) async throws -> Void

    struct Made: Sendable {
        var name: String
        var url: URL
        var clock: EpisodeClock
        /// Which sound of the file is listened to (ffmpeg's stream map): the first, unless a file carries several (v2 part M10b,
        /// the timelines' privacy-safe media, where every track it keeps is checked on its own).
        var map = "0:a:0"
    }

    static func run(original: URL, made: [Made], segments: [VoiceSegment], leftOut: Set<Int>, folders: PeopleFolders, now: Date,
                    decode: Decode, log: (@Sendable (String) -> Void)? = nil) async throws -> AudioCheck {
        let started = ContinuousClock.now
        let job = try folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        var check = AudioCheck(checkedAt: now, files: made.map(\.name))

        func samples(of file: URL, map: String, name: String) async throws -> [Float] {
            let raw = job.appending(path: name + ".raw")
            try await decode(["-y", "-v", "error", "-i", file.path, "-map", map, "-ac", "1", "-ar", "16000", "-f", "f32le", raw.path])
            defer { try? FileManager.default.removeItem(at: raw) }
            return try Data(contentsOf: raw, options: .alwaysMapped).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }

        // 1. The original, told apart again, matched to the voice step's voices by when they speak.
        let source = try await Diarizer.listen(try await samples(of: original, map: "0:a:0", name: "original"))
        let voices = Set(segments.map(\.voice))
        var centroid: [Int: [Float]] = [:]
        for voice in voices {
            let theirs = segments.filter { $0.voice == voice }
            var best: (speaker: Int, score: Double)?
            for speaker in Set(source.segments.map(\.voice)) {
                let heard = source.segments.filter { $0.voice == speaker }
                let shared = shared(theirs, heard)
                let either = total(theirs) + total(heard) - shared
                let score = either > 0 ? shared / either : 0
                if score > (best?.score ?? 0.05) { best = (speaker, score) }
            }
            if let best, let vector = source.centroids[best.speaker] { centroid[voice] = vector }
        }
        check.timeOnly = leftOut.filter { centroid[$0] == nil }.sorted()
        let included = voices.subtracting(leftOut)

        // 2 and 3. Each file: by sound, and by time.
        for (index, file) in made.enumerated() {
            let heard = try await Diarizer.listen(try await samples(of: file.url, map: file.map, name: "made-\(index)"))
            for speaker in Set(heard.segments.map(\.voice)).sorted() {
                let own = heard.segments.filter { $0.voice == speaker }.sorted { $0.start < $1.start }
                let speaking = total(own)
                guard let vector = heard.centroids[speaker] else { continue }
                let scores = centroid.mapValues { Diarizer.similarity(vector, $0) }
                let bestOut = scores.filter { leftOut.contains($0.key) }.max { $0.value < $1.value }
                let bestIn = scores.filter { included.contains($0.key) }.map(\.value).max()
                check.matches.append("\(file.name) voice \(speaker) (\(String(format: "%.1f", speaking)) s): "
                                     + scores.sorted { $0.key < $1.key }.map { "Voice \($0.key) \(String(format: "%.3f", $0.value))" }.joined(separator: ", "))
                if speaking >= shortest, let bestOut, bestOut.value > (bestIn ?? -1), let first = own.first {
                    check.findings.append(.init(file: file.name, at: first.start, seconds: speaking, voice: bestOut.key, how: "sounds like"))
                }
            }
            // By time: speech in the file at a moment of the original where a left-out voice speaks.
            let theirs = segments.filter { leftOut.contains($0.voice) }
            for segment in heard.segments.sorted(by: { $0.start < $1.start }) {
                var t = segment.start
                var found: Int?
                while t <= segment.end && found == nil {
                    if let o = file.clock.originalTime(t) {
                        found = theirs.first { o > $0.start + inside && o < $0.end - inside }?.voice
                    }
                    t += 0.2
                }
                if let found, !check.findings.contains(where: { $0.file == file.name && abs($0.at - segment.start) < 0.5 }) {
                    check.findings.append(.init(file: file.name, at: segment.start, seconds: segment.length, voice: found, how: "is where the original has"))
                }
            }
        }
        check.findings.sort { $0.file != $1.file ? $0.file < $1.file : $0.at < $1.at }
        let elapsed = ContinuousClock.now - started
        check.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        for line in check.matches { log?(line) }
        return check
    }

    /// Seconds two lists of stretches share.
    static func shared(_ a: [VoiceSegment], _ b: [VoiceSegment]) -> Double {
        let ua = VoiceTimeline.union(a), ub = VoiceTimeline.union(b)
        var total = 0.0
        for x in ua { for y in ub { total += max(0, min(x.1, y.1) - max(x.0, y.0)) } }
        return total
    }

    static func total(_ a: [VoiceSegment]) -> Double { VoiceTimeline.union(a).map { $0.1 - $0.0 }.reduce(0, +) }
}
