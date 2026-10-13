import Foundation

// Voices in a recording (v2 part M6b, docs/v2/PLAN.md M6, research-people.md 2.5): the pure arithmetic of the
// voice step. Who speaks when, as times only: from microphone tracks when the recording has them (each track
// being active), else from FluidAudio's diarizer on the one mixed track (Diarizer.swift). Nothing here reads a
// file, so PeopleTests drive it with made-up levels and segments.
//
// What is never kept, by design (research-people.md 5.1): no voice print, no embedding, no sound. A voice is
// only ever a list of times and a label.

/// One stretch of one voice speaking, in seconds from the start of the original.
struct VoiceSegment: Codable, Equatable, Hashable, Sendable {
    var start: Double
    var end: Double
    /// The voice's id in `VoicesFound.voices` (1, 2...).
    var voice: Int

    var length: Double { max(0, end - start) }
}

/// One voice as the People tab lists it.
struct FoundVoice: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: Int
    /// "Voice 1", "Voice 2"... in order of how long each speaks.
    var label: String
    /// Seconds speaking.
    var speaking: Double
    var first: Double
    var last: Double
    /// The microphone track it was heard on (OBS's track number, 2 and up), or nil when it came from the diarizer.
    var track: Int?
    /// The People tab row of the face it is linked to (`FacePerson.id`), or nil when no face moves with it.
    var face: Int?
    /// How the link was made, in words for the People tab: "the only face on screen" or "the mouth moves with it".
    var linkedBy: String?
}

/// What the voice step found in one recording, as the app shows it and the store keeps it (`Recording.voicesJSON`).
/// Times and counts only; never a voice print.
struct VoicesFound: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        /// Each microphone on its own track (OBS tracks 2 and up, help article 03): who speaks is which track is
        /// active.
        case tracks
        /// One mixed track: FluidAudio's offline diarizer told the voices apart.
        case diarizer
    }

    var version = 1
    var checkedAt: Date
    var duration: Double
    var source: Source
    /// The microphone tracks read (tracks 2 and up), empty for the diarizer.
    var tracksUsed: [Int] = []
    var voices: [FoundVoice] = []
    /// Seconds anyone speaks, and seconds two or more speak at once.
    var speech: Double = 0
    var overlap: Double = 0
    /// On one mixed track with two or more voices, every change from one voice to another: the moments Ivan
    /// listens to before trusting who said what (Mac warning 14, research-people.md 2.5: on the mixed studio track
    /// the diarizer once gave a student's story to the teacher). Empty for microphone tracks.
    var listen: [Double] = []
    /// How long the step took, for the log.
    var seconds: Double = 0

    var otherVoices: Int { max(0, voices.count - 1) }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode(_ json: String?) -> VoicesFound? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(VoicesFound.self, from: data)
    }

    /// Where the voices came from, in words for the step's line and the People tab.
    var sourceLine: String {
        switch source {
        case .tracks: "Who speaks is read from the microphone tracks " + tracksUsed.map(String.init).joined(separator: " and ") + "."
        case .diarizer: "Who speaks is told apart from the one mixed track, so it is a best guess."
        }
    }

    /// The step's line in the make's steps and the log: what was heard, no names.
    var stepLine: String {
        let heard: String = switch voices.count {
        case 0: "No one speaks."
        case 1: "One voice, speaking for \(Format.length(voices[0].speaking))."
        default: "\(VoicesFound.word(voices.count).capitalizedFirst) voices, the most for \(Format.length(voices[0].speaking))."
        }
        let linked = voices.filter { $0.face != nil }.count
        let faces = voices.isEmpty ? "" : (linked == 0 ? " No voice is linked to a face." : " \(Format.count(linked, "voice")) linked to a face.")
        let listen = self.listen.isEmpty ? "" : " \(Format.count(self.listen.count, "change")) of voice to listen to."
        return sourceLine + " " + heard + faces + listen
    }

    static func word(_ n: Int) -> String {
        ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"][safe: n] ?? Format.number(n)
    }

    /// The facts from voice segments: voices ordered by speaking time and labelled, speech, overlap and the moments
    /// to listen to. Segments come in with any voice numbers; they go out renumbered 1, 2... by speaking time.
    static func from(segments raw: [VoiceSegment], source: Source, tracks: [Int: Int] = [:], duration: Double, checkedAt: Date,
                     seconds: Double = 0) -> (found: VoicesFound, segments: [VoiceSegment]) {
        let segments = raw.filter { $0.length > 0 }.sorted { $0.start != $1.start ? $0.start < $1.start : $0.voice < $1.voice }
        let byVoice = Dictionary(grouping: segments, by: \.voice)
        let order = byVoice.keys.sorted { a, b in
            let la = byVoice[a]!.map(\.length).reduce(0, +), lb = byVoice[b]!.map(\.length).reduce(0, +)
            return la != lb ? la > lb : a < b
        }
        var renumber: [Int: Int] = [:]
        for (index, voice) in order.enumerated() { renumber[voice] = index + 1 }
        let renumbered = segments.map { VoiceSegment(start: $0.start, end: $0.end, voice: renumber[$0.voice] ?? 0) }
        var found = VoicesFound(checkedAt: checkedAt, duration: duration, source: source, seconds: seconds)
        found.tracksUsed = source == .tracks ? tracks.values.sorted() : []
        found.voices = order.enumerated().map { index, voice in
            let own = byVoice[voice] ?? []
            return FoundVoice(id: index + 1, label: "Voice \(index + 1)", speaking: own.map(\.length).reduce(0, +),
                              first: own.map(\.start).min() ?? 0, last: own.map(\.end).max() ?? 0, track: tracks[voice])
        }
        found.speech = VoiceTimeline.union(renumbered).map { $0.1 - $0.0 }.reduce(0, +)
        found.overlap = VoiceTimeline.overlap(renumbered)
        if source == .diarizer && found.voices.count >= 2 {
            var changes: [Double] = []
            var previous: Int?
            for segment in renumbered {
                if let previous, previous != segment.voice { changes.append(PeopleFile.round(segment.start)) }
                previous = segment.voice
            }
            found.listen = changes
        }
        return (found, renumbered)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Times where voices speak, merged.
enum VoiceTimeline {
    /// The stretches where anyone speaks, joined.
    static func union(_ segments: [VoiceSegment]) -> [(Double, Double)] {
        var out: [(Double, Double)] = []
        for s in segments.sorted(by: { $0.start < $1.start }) {
            if let last = out.last, s.start <= last.1 { out[out.count - 1].1 = max(last.1, s.end) } else { out.append((s.start, s.end)) }
        }
        return out
    }

    /// Seconds in which two or more different voices speak at once.
    static func overlap(_ segments: [VoiceSegment]) -> Double {
        var events: [(Double, Int, Int)] = []
        for s in segments where s.length > 0 { events += [(s.start, 1, s.voice), (s.end, -1, s.voice)] }
        events.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
        var active: [Int: Int] = [:]
        var total = 0.0
        var last = events.first?.0 ?? 0
        for (time, change, voice) in events {
            if active.values.filter({ $0 > 0 }).count >= 2 { total += time - last }
            active[voice, default: 0] += change
            last = time
        }
        return total
    }

    /// Seconds of `segments` (one voice's) inside `start..<end`.
    static func seconds(_ segments: [VoiceSegment], from start: Double, to end: Double) -> Double {
        segments.map { max(0, min($0.end, end) - max($0.start, start)) }.reduce(0, +)
    }

    /// Whether one voice speaks at `time`.
    static func speaks(_ segments: [VoiceSegment], at time: Double) -> Bool {
        segments.contains { $0.start <= time && time < $0.end }
    }
}

/// Who speaks when from microphone tracks (research-people.md 2.5): a track is speaking in a tenth of a second when
/// its level is speech (at or above `floor`) and is no more than `bleed` below the loudest track at that moment. A
/// voice picked up by a neighbour's microphone arrives well below the voice's own microphone, so it is not counted
/// as the neighbour speaking; two people speaking at once at similar levels both count.
///
/// The plan's starting value was "6 dB above the others" [proposal, PE 2.5]. Read literally, two people speaking
/// at once would both be dropped; read as "within 6 dB of the loudest", the bleed is still left out and the overlap
/// is kept, which is what the cut of overlapping speech needs (PE 3.5). Decision in BUILD-LOG "v2 part M6b".
enum TrackActivity {
    /// A tenth of a second per level.
    static let frame = 0.1
    /// Speech: a tenth of a second at or above this, in dB below full scale (RMS). A quiet room measures about -60.
    static let floor = -45.0
    /// A track counts only when it is no more than this many dB below the loudest track at that moment.
    static let bleed = 6.0
    /// Gaps shorter than this inside one track's speech are joined (the breath between words).
    static let joinGap = 0.4
    /// Speech shorter than this, after joining, is dropped (a cough, a click).
    static let shortest = 0.3
    /// A track that speaks for less than this in all is not a voice (a bump of the microphone).
    static let leastVoice = 1.0

    /// RMS level in dB of each tenth of a second of 16 kHz mono samples.
    static func levels(_ samples: UnsafeBufferPointer<Float>, sampleRate: Int = 16_000) -> [Double] {
        let size = Int(Double(sampleRate) * frame)
        guard size > 0 else { return [] }
        var out: [Double] = []
        out.reserveCapacity(samples.count / size + 1)
        var index = 0
        while index < samples.count {
            let end = min(samples.count, index + size)
            var sum: Double = 0
            for i in index..<end { let v = Double(samples[i]); sum += v * v }
            let rms = (sum / Double(max(1, end - index))).squareRoot()
            out.append(rms > 0 ? 20 * log10(rms) : -120)
            index = end
        }
        return out
    }

    /// Segments per track (keyed by track number) from each track's levels.
    static func segments(levels: [Int: [Double]]) -> [VoiceSegment] {
        let tracks = levels.keys.sorted()
        let count = levels.values.map(\.count).max() ?? 0
        var active: [Int: [Bool]] = [:]
        for track in tracks { active[track] = [Bool](repeating: false, count: count) }
        for i in 0..<count {
            let here = tracks.map { levels[$0]![safe: i] ?? -120 }
            let loudest = here.max() ?? -120
            for (k, track) in tracks.enumerated() where here[k] >= floor && here[k] >= loudest - bleed {
                active[track]![i] = true
            }
        }
        var out: [VoiceSegment] = []
        for track in tracks {
            let spans = smooth(active[track]!)
            guard spans.map({ $0.1 - $0.0 }).reduce(0, +) >= leastVoice else { continue }
            out += spans.map { VoiceSegment(start: PeopleFile.round($0.0), end: PeopleFile.round($0.1), voice: track) }
        }
        return out
    }

    /// Frames to spans: short gaps joined, short bits dropped.
    static func smooth(_ frames: [Bool]) -> [(Double, Double)] {
        var spans: [(Double, Double)] = []
        var start: Int?
        for (i, on) in frames.enumerated() {
            if on, start == nil { start = i }
            if !on, let s = start { spans.append((Double(s) * frame, Double(i) * frame)); start = nil }
        }
        if let s = start { spans.append((Double(s) * frame, Double(frames.count) * frame)) }
        var joined: [(Double, Double)] = []
        for span in spans {
            if let last = joined.last, span.0 - last.1 < joinGap { joined[joined.count - 1].1 = span.1 } else { joined.append(span) }
        }
        return joined.filter { $0.1 - $0.0 >= shortest }
    }
}
