import Foundation

// Recognition of named people with a release (v2 part M7b, docs/v2/PLAN.md M7, research-people.md 2.2 to 2.4 and 5).
// The pure half: which frames of a recording are identified, how a frame's answer is read, the votes that turn a
// row's frames into "named", "ask" or "unnamed", and the calibration report. Nothing here reads a file or a picture,
// so `RecognitionTests` drives every rule with made-up answers. The half that talks to Apple's `FaceGroupAnalyzer`
// is `FaceIndex.swift`; what crops are learned is `Learning.swift`.
//
// Every threshold leans toward not naming (research-people.md 1.6, PLAN risk R3): taking a stranger for a named person
// is the dangerous mistake, taking a named person for a stranger only costs Ivan one Yes.

/// What one identified frame says about one face row. A frame counts only when `FaceGroupAnalyzer` found a face where
/// the people file has the row's box (overlap 0.3 or more).
enum FrameIdentity: Equatable, Sendable {
    /// A face was found, and it matched no one in the gallery.
    case nobody
    /// It matched a group made only of this person's crops.
    case person(UUID)
    /// It matched a group holding crops of two or more people (research-people.md 2.3): never a name.
    case conflict
}

/// What the voice linked to a face row says, for the vote (research-people.md 2.2: "the voice agreeing when the track
/// speaks"). Voice prints are not learned in this part, so the voice's own name (Ivan's naming, a folder's microphone,
/// Who Is Teaching) is what it says.
enum VoiceVote: Equatable, Sendable {
    /// No voice is linked to the row, or it has no name.
    case none
    case person(UUID)
}

/// The machine's answer for one face row of one recording, kept on the recording (`PeopleNames.recognition`) so
/// Review can ask about it and `make calibrate-people` can count it against Ivan's answers. Not biometric: a person id
/// and two counts.
struct RowVote: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable { case named, ask, unnamed }

    var outcome: Outcome
    /// Who it is (named) or who it might be (ask); nil when unnamed.
    var person: UUID?
    /// Frames identified for the row, and how many of them matched `person`.
    var frames: Int
    var matched: Int
}

enum Votes {
    /// research-people.md 2.2, starting points until `make calibrate-people` sets them: named without asking at 3 or
    /// more identified frames, 60% or more of them the same person, none matched to anyone else.
    static let minimumFrames = 3
    static let minimumShare = 0.6

    /// One set of frames to a vote.
    static func vote(_ frames: [FrameIdentity], voice: VoiceVote = .none) -> RowVote {
        var counts: [UUID: Int] = [:]
        var conflicts = 0
        for frame in frames {
            switch frame {
            case .person(let id): counts[id, default: 0] += 1
            case .conflict: conflicts += 1
            case .nobody: break
            }
        }
        guard let top = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key.uuidString > $1.key.uuidString }) else {
            return RowVote(outcome: .unnamed, person: nil, frames: frames.count, matched: 0)
        }
        var vote = RowVote(outcome: .ask, person: top.key, frames: frames.count, matched: top.value)
        // A frame matched to anyone else, or to a group of two people, is never a name: ask.
        let othersMatched = counts.count > 1 || conflicts > 0
        let enough = frames.count >= minimumFrames && Double(top.value) >= minimumShare * Double(frames.count)
        if enough && !othersMatched { vote.outcome = .named }
        // A voice named as someone else turns a name into a question.
        if vote.outcome == .named, case .person(let other) = voice, other != top.key { vote.outcome = .ask }
        return vote
    }

    /// A face row's vote: the row's frames together, and then every track of the row with enough frames of its own must
    /// say the same name, or the row is asked about. Reason: rows join tracks by place (Mac warning 114), so two people
    /// who sit in the same place one after the other can share a row, and the second must never take the first's name.
    static func row(tracks: [[FrameIdentity]], voice: VoiceVote = .none) -> RowVote {
        var vote = vote(tracks.flatMap { $0 }, voice: voice)
        guard vote.outcome == .named, let person = vote.person else { return vote }
        for frames in tracks where frames.count >= minimumFrames {
            let own = self.vote(frames)
            if own.outcome != .named || own.person != person {
                vote.outcome = .ask
                break
            }
        }
        return vote
    }
}

/// Which frames of a recording are given to the analyzer (research-people.md 2.1 step 3): for each track of a named
/// row's or an unnamed row's face, up to 5 sightings spread across it, plus one every 10 s for a long track, never a
/// face smaller than `minimumHeight` of the picture (too small to identify, so it stays unnamed, research 1.6). The
/// people file keeps no capture quality, so the spread stands in for "the best 5": the analyzer itself finds no face in
/// a frame too poor to read, and such a frame does not count.
enum FrameChoice {
    static let perTrack = 5
    static let every = 10.0
    static let minimumHeight = 0.05
    /// At most this many frames for one recording (about 15 s of identifying at 30 ms a frame, measured in research 1.2).
    static let limit = 500

    struct Pick: Equatable, Sendable {
        var time: Double
        var row: Int
        var track: Int
        var box: FaceBox
    }

    static func picks(_ file: PeopleFile) -> [Pick] {
        var picks: [Pick] = []
        for track in file.tracks {
            guard let row = track.person else { continue }
            let sightings: [(time: Double, box: FaceBox)] = track.boxes.compactMap { box in
                guard box.count >= 5 else { return nil }
                let face = FaceBox(x: box[1], y: box[2], width: box[3], height: box[4])
                return face.height >= minimumHeight ? (box[0], face) : nil
            }
            guard !sightings.isEmpty else { continue }
            var chosen = Set<Int>()
            let spread = min(perTrack, sightings.count)
            for i in 0..<spread {
                chosen.insert(spread == 1 ? sightings.count / 2 : Int((Double(i) * Double(sightings.count - 1) / Double(spread - 1)).rounded()))
            }
            var next = sightings[0].time + every
            for (index, sighting) in sightings.enumerated() where sighting.time >= next {
                chosen.insert(index)
                next = sighting.time + every
            }
            for index in chosen.sorted() {
                picks.append(Pick(time: sightings[index].time, row: row, track: track.id, box: sightings[index].box))
            }
        }
        picks.sort { ($0.time, $0.track) < ($1.time, $1.track) }
        if picks.count > limit {
            // Evenly thinned, so every part of the recording keeps some.
            let step = Double(picks.count) / Double(limit)
            picks = (0..<limit).map { picks[Int(Double($0) * step)] }
        }
        return picks
    }
}

/// `FaceGroupAnalyzer.Face.bounds` to a top-left box. **Measured Tue 13 Oct on two-people-mixed.mp4, against Vision on
/// the same frames: the analyzer's bounds have their origin at the BOTTOM left, like Vision's**, though its documentation
/// and research-people.md 1.2 say top left (main face: Vision top-left y 0.284, analyzer y 0.497 = 1 - 0.284 - 0.224).
/// Every analyzer box goes through here, and `make accept-gallery` measures that the boxes still land on the people
/// file's own.
enum AnalyzerGeometry {
    static func box(fromAnalyzer rect: CGRect) -> FaceBox { FaceGeometry.fromVision(rect) }
}

/// Reading a recording's identified frames into one vote per face row.
enum RowVotes {
    /// An identified face, as the analyzer gave it, already in the top-left convention and read through the gallery
    /// (the group's person, a conflict, or nobody).
    struct Found: Equatable, Sendable {
        var box: FaceBox
        var identity: FrameIdentity
    }

    /// The overlap a found face needs with the row's box at that moment to be that row's face.
    static let minimumOverlap = 0.3

    /// The frame answers per row and track: each pick takes the found face that overlaps its box the most (0.3 or
    /// more); a pick with none is not identified and does not count.
    static func frames(picks: [FaceChoicePair]) -> [Int: [Int: [FrameIdentity]]] {
        var out: [Int: [Int: [FrameIdentity]]] = [:]
        for pair in picks {
            let best = pair.found.map { (FaceGeometry.overlap($0.box, pair.pick.box), $0.identity) }.max { $0.0 < $1.0 }
            guard let best, best.0 >= minimumOverlap else { continue }
            out[pair.pick.row, default: [:]][pair.pick.track, default: []].append(best.1)
        }
        return out
    }

    /// One vote per row that had a frame identified, with each row's voice.
    static func votes(picks: [FaceChoicePair], voices: [Int: VoiceVote]) -> [Int: RowVote] {
        var votes: [Int: RowVote] = [:]
        for (row, tracks) in frames(picks: picks) {
            let ordered = tracks.keys.sorted().map { tracks[$0] ?? [] }
            votes[row] = Votes.row(tracks: ordered, voice: voices[row] ?? .none)
        }
        return votes
    }

    /// How many picks had a found face on their box: the measurement that the analyzer's boxes and the people file's
    /// agree (a wrong origin gives almost none).
    static func landed(_ picks: [FaceChoicePair]) -> Int {
        picks.filter { pair in pair.found.contains { FaceGeometry.overlap($0.box, pair.pick.box) >= minimumOverlap } }.count
    }
}

/// One chosen frame and the faces the analyzer found in it.
struct FaceChoicePair: Equatable, Sendable {
    var pick: FrameChoice.Pick
    var found: [RowVotes.Found]
}

/// The voice vote for each face row: the name of the voice linked to it, from Ivan's naming, the folder's microphones
/// and Who Is Teaching (`PeopleNames.resolved` without recognition, so a vote never agrees with itself).
extension VoiceVote {
    static func perRow(names: PeopleNames, faces: FacesFound?, voices: VoicesFound?) -> [Int: VoiceVote] {
        var plain = names
        plain.recognition = nil
        let resolved = plain.resolved(faces: faces, voices: voices)
        var out: [Int: VoiceVote] = [:]
        for voice in voices?.voices ?? [] {
            guard let face = voice.face, let person = resolved.voices[voice.id] else { continue }
            out[face] = .person(person)
        }
        return out
    }
}

// MARK: Calibration

/// `make calibrate-people` (research-people.md 6.1): each row the machine voted on, against what Ivan said about it.
/// Ivan's word is a name he gave the row by hand (Review's Yes is one) or a "Not [name]" (Review's No).
enum Calibration {
    struct Report: Equatable, Sendable {
        /// Rows with a vote and an answer from Ivan.
        var labeled = 0
        /// Named without asking, and right.
        var recognized = 0
        /// Named without asking as one person, and Ivan named them someone else.
        var mistaken = 0
        /// Named without asking, and Ivan said it is not them and named nobody with a release: a stranger taken for a
        /// named person, the mistake that must stay under 1 in 1,000.
        var strangerTaken = 0
        /// Asked about (Review), whatever the answer.
        var asked = 0
        /// Not named, though Ivan named someone with a release there.
        var missed = 0

        var strangerRate: Double? { labeled > 0 ? Double(strangerTaken) / Double(labeled) : nil }

        var lines: [String] {
            guard labeled > 0 else {
                return ["SKIPPED: no row has both a vote and an answer from Ivan. It needs releases recorded, recordings made, and Review answered."]
            }
            func share(_ n: Int) -> String { String(format: "%d of %d (%.1f%%)", n, labeled, Double(n) / Double(labeled) * 100) }
            return ["Rows with a vote and an answer: \(labeled)",
                    "Named without asking, right: \(share(recognized))",
                    "Named without asking, wrong person: \(share(mistaken))",
                    "A stranger taken for a named person: \(share(strangerTaken)) (must stay under 1 in 1,000)",
                    "Asked about: \(share(asked))",
                    "Not named though they have a release: \(share(missed))"]
        }
    }

    /// `released`: the people with a release on file (who could be recognized at all).
    static func report(_ rows: [(vote: RowVote, named: UUID?, notThem: [UUID])], released: Set<UUID>) -> Report {
        var report = Report()
        for row in rows {
            let answered = row.named != nil || (row.vote.person.map { row.notThem.contains($0) } ?? false)
            guard answered else { continue }
            report.labeled += 1
            switch row.vote.outcome {
            case .named:
                if row.named == row.vote.person {
                    report.recognized += 1
                } else if let named = row.named, released.contains(named) {
                    report.mistaken += 1
                } else {
                    report.strangerTaken += 1
                }
            case .ask:
                report.asked += 1
            case .unnamed:
                if let named = row.named, released.contains(named) { report.missed += 1 }
            }
        }
        return report
    }
}
