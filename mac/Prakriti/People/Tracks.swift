import CoreGraphics
import Foundation

// Faces in a recording (v2 part M6a, docs/v2/PLAN.md M6, research-people.md 2.1): the pure arithmetic of the
// people pass. Detections at 2 frames a second become tracks (one face followed while the camera keeps it),
// tracks become the rows of the People tab, and the whole becomes the few facts the app shows. Nothing here
// reads a file or a picture, so PeopleTests drive it with made-up boxes.
//
// What is never computed here, by design (research-people.md 5.1): no landmarks, no face print, no picture.
// A face is only ever a box, a time and how sure Vision was.

/// A face's box, from 0 to 1 across and down the picture, with its origin at the TOP LEFT: the way a picture
/// is read, and Media Intelligence's convention. Vision's boxes have their origin at the bottom left;
/// `FaceGeometry.fromVision` and `toVision` convert, and PeopleTests prove the two round-trip.
struct FaceBox: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var centerX: Double { x + width / 2 }
    var centerY: Double { y + height / 2 }
    var area: Double { max(0, width) * max(0, height) }
}

enum FaceGeometry {
    /// Vision (origin bottom left) to a top-left box.
    static func fromVision(_ rect: CGRect) -> FaceBox {
        FaceBox(x: rect.origin.x, y: 1 - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }

    /// A top-left box back to Vision's bottom-left rectangle.
    static func toVision(_ box: FaceBox) -> CGRect {
        CGRect(x: box.x, y: 1 - box.y - box.height, width: box.width, height: box.height)
    }

    /// How much two boxes overlap: the shared area over the area they cover together (0 to 1).
    static func overlap(_ a: FaceBox, _ b: FaceBox) -> Double {
        let w = min(a.x + a.width, b.x + b.width) - max(a.x, b.x)
        let h = min(a.y + a.height, b.y + b.height) - max(a.y, b.y)
        guard w > 0, h > 0 else { return 0 }
        let shared = w * h
        let union = a.area + b.area - shared
        return union > 0 ? shared / union : 0
    }

    /// The distance between two boxes' centers, measured across the picture's width and height alike.
    static func centerDistance(_ a: FaceBox, _ b: FaceBox) -> Double {
        let dx = a.centerX - b.centerX, dy = a.centerY - b.centerY
        return (dx * dx + dy * dy).squareRoot()
    }

    /// `box` grown about its center by `factor`, kept inside the picture.
    static func padded(_ box: FaceBox, by factor: Double) -> FaceBox {
        let w = box.width * factor, h = box.height * factor
        let x = max(0, box.centerX - w / 2), y = max(0, box.centerY - h / 2)
        return FaceBox(x: x, y: y, width: min(1 - x, w), height: min(1 - y, h))
    }
}

/// One face Vision found in one sampled frame.
struct FaceDetection: Equatable, Sendable {
    var box: FaceBox
    /// Vision's own confidence, 0 to 1.
    var confidence: Double
    /// Vision's face capture quality, 0 to 1 ("better lit, sharper, more centrally positioned"), when measured.
    var quality: Double?
}

/// One sampled frame: its time in the recording and every face in it.
struct FaceSample: Equatable, Sendable {
    var time: Double
    var faces: [FaceDetection]
}

/// One sighting of a tracked face.
struct FaceSighting: Equatable, Sendable {
    var time: Double
    var box: FaceBox
    var confidence: Double
    var quality: Double?
}

/// One face followed from sample to sample while the camera keeps it.
struct FaceTrack: Equatable, Sendable, Identifiable {
    let id: Int
    var sightings: [FaceSighting]
    var start: Double { sightings.first?.time ?? 0 }
    var end: Double { sightings.last?.time ?? 0 }
    var last: FaceSighting? { sightings.last }
}

/// Faces to tracks (research-people.md 2.1 step 2, docs/v2/PLAN.md M6).
enum FaceTracker {
    /// The plan's rule: the same face in consecutive samples when the boxes overlap by at least this much.
    static let minimumOverlap = 0.3
    /// A track ends once its face has been unseen this long (s).
    static let unseenBreak = 1.5
    /// Sample times wander by a few hundredths of a second (29.97 fps), so "1.5 s unseen" allows this much.
    static let timeTolerance = 0.05
    /// Added to the plan's rule (measured Mon 12 Oct): a speaker's head moves up to 0.115 of the picture's
    /// height between samples half a second apart on the 13 Sep talk, an overlap of 0.26, so the plan's 0.3
    /// alone split one person's track at every quick move (6 Sep: 111 tracks; with this, 30). Two boxes of
    /// nearly the same size whose centers are within one face width are the same face too.
    static let nearness = 1.0
    static let sameSize: ClosedRange<Double> = 0.67...1.5

    /// How alike two boxes are, for joining a detection to a track: above 1 when they overlap enough, between
    /// 0 and 1 when they are only near and of the same size, 0 when they are not the same face.
    static func likeness(_ a: FaceBox, _ b: FaceBox) -> Double {
        let overlap = FaceGeometry.overlap(a, b)
        if overlap >= minimumOverlap { return 1 + overlap }
        let width = max(a.width, b.width)
        guard width > 0, a.width > 0 else { return 0 }
        let distance = FaceGeometry.centerDistance(a, b)
        let ratio = b.width / a.width
        if distance <= nearness * width && sameSize.contains(ratio) { return max(0.0001, 1 - distance / width) }
        return 0
    }

    /// Every sample, in time order, to tracks. A cut (a change of picture) ends every track, as does a face
    /// unseen for more than 1.5 s. Detections join the open track they are most like, one each, best pairs first.
    static func tracks(_ samples: [FaceSample], cuts: [Double] = []) -> [FaceTrack] {
        var tracks: [FaceTrack] = []
        var open: [Int] = []
        var previous: Double?
        let sortedCuts = cuts.sorted()
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            // A cut is timed at the first sample after it, so it lies after the previous sample and at or before this one.
            if let previous, sortedCuts.contains(where: { $0 > previous && $0 <= sample.time }) {
                open = []
            }
            previous = sample.time
            open.removeAll { sample.time - (tracks[$0].last?.time ?? 0) > unseenBreak + timeTolerance }
            var pairs: [(score: Double, track: Int, face: Int)] = []
            for t in open {
                guard let last = tracks[t].last else { continue }
                for (f, face) in sample.faces.enumerated() {
                    let score = likeness(last.box, face.box)
                    if score > 0 { pairs.append((score, t, f)) }
                }
            }
            pairs.sort { $0.score != $1.score ? $0.score > $1.score : ($0.track, $0.face) < ($1.track, $1.face) }
            var usedTracks = Set<Int>(), usedFaces = Set<Int>()
            for pair in pairs where !usedTracks.contains(pair.track) && !usedFaces.contains(pair.face) {
                usedTracks.insert(pair.track)
                usedFaces.insert(pair.face)
                let face = sample.faces[pair.face]
                tracks[pair.track].sightings.append(FaceSighting(time: sample.time, box: face.box, confidence: face.confidence, quality: face.quality))
            }
            for (f, face) in sample.faces.enumerated() where !usedFaces.contains(f) {
                tracks.append(FaceTrack(id: tracks.count + 1, sightings: [FaceSighting(time: sample.time, box: face.box, confidence: face.confidence, quality: face.quality)]))
                open.append(tracks.count - 1)
            }
        }
        return tracks
    }
}

/// The rows of the People tab: tracks joined when one starts after another ended, in the same place and at
/// the same size. Without a face print (never kept for anyone unnamed, research-people.md 5.1) this is all
/// that can be said: the same place is not proof of the same person, and one person who moves around can
/// make two rows. So the app's headline facts (anyone else on screen, how many at once) never rest on these
/// rows; they come from how many faces are in one frame (`FacesFound.mostAtOnce`).
enum FaceGrouping {
    /// A later track joins a row whose last sighting is within this many face widths of its first.
    static let reach = 2.5
    static let sameSize: ClosedRange<Double> = 0.5...2.0

    /// Track ids per row, each row in time order. A track joins the compatible row seen most recently.
    static func rows(_ tracks: [FaceTrack]) -> [[Int]] {
        var rows: [(tracks: [Int], last: FaceSighting)] = []
        for track in tracks.sorted(by: { ($0.start, $0.id) < ($1.start, $1.id) }) {
            guard let first = track.sightings.first, let last = track.last else { continue }
            var best: Int?
            for (index, row) in rows.enumerated() {
                guard track.start > row.last.time else { continue }
                let width = max(row.last.box.width, first.box.width)
                guard row.last.box.width > 0 else { continue }
                let ratio = first.box.width / row.last.box.width
                guard FaceGeometry.centerDistance(row.last.box, first.box) <= reach * width, sameSize.contains(ratio) else { continue }
                if best == nil || row.last.time > rows[best!].last.time { best = index }
            }
            if let best {
                rows[best].tracks.append(track.id)
                rows[best].last = last
            } else {
                rows.append(([track.id], last))
            }
        }
        return rows.map(\.tracks)
    }
}

/// A row of the People tab: one face, as far as Prakriti can tell without knowing who anyone is.
struct FacePerson: Codable, Equatable, Sendable, Identifiable {
    let id: Int
    /// "Unnamed 1", "Unnamed 2": by time on screen, most first.
    var label: String
    /// Seconds on screen: sightings times the time between samples.
    var onScreen: Double
    var first: Double
    var last: Double
    /// How many tracks the row joins (times the face left and came back, or was lost for a moment).
    var appearances: Int
    /// The sighting the People tab crops its picture from, live and in memory only: the best capture quality,
    /// else the largest box.
    var keyTime: Double
    var keyBox: FaceBox
}

/// What the face step found in one recording, as the app shows it and the store keeps it (`Recording.facesJSON`).
/// Times and counts only: no box of anyone but the row's one key moment, no picture.
struct FacesFound: Codable, Equatable, Sendable {
    /// The JSON's own version, for later parts that add to it.
    var version = 1
    var checkedAt: Date
    var duration: Double
    /// The file has a picture. An audio-only recording has no faces to look for.
    var hasPicture = true
    /// Seconds between samples (2 a second).
    var every: Double = FaceScan.every
    var samples: Int = 0
    var samplesWithFaces: Int = 0
    /// The most faces in one sampled frame. "Other people appear" is 2 or more: a fact about one frame, which
    /// needs no guess about who anyone is.
    var mostAtOnce: Int = 0
    /// Samples with two or more faces, and the first of them.
    var samplesWithOthers: Int = 0
    var firstWithOthers: Double?
    /// Rows seen in two or more samples, most on screen first; rows seen in one sample only are counted in
    /// `glimpses` and not listed (they still count in `mostAtOnce`).
    var people: [FacePerson] = []
    var glimpses: Int = 0
    var tracks: Int = 0
    var cuts: Int = 0
    /// How long the step took, for the log.
    var seconds: Double = 0

    /// Two or more faces in one frame, at least once.
    var otherPeopleAppear: Bool { mostAtOnce >= 2 }

    /// The line on a card and in the list (design spec 3.1.1), true of this part's build: no names yet.
    var line: String {
        guard hasPicture else { return "No picture to look at." }
        switch mostAtOnce {
        case 0: return "No faces seen."
        case 1: return "One person at a time."
        default: return "Other people appear, up to \(mostAtOnce) at once."
        }
    }

    /// The list's People column, where a long line would be cut (design spec 3.2).
    var shortLine: String {
        guard hasPicture else { return "No picture" }
        switch mostAtOnce {
        case 0: return "No faces"
        case 1: return "One at a time"
        default: return "Up to \(mostAtOnce) at once"
        }
    }

    /// The People tab's first sentence (design spec 3.5.2, 17 pt), plain words, never a bare number.
    var summary: String {
        guard hasPicture else { return "This recording has no picture, so there are no faces to look for." }
        guard samples > 0, mostAtOnce > 0 else { return "No faces were seen in this recording." }
        let share = Int((Double(samplesWithFaces) / Double(samples) * 100).rounded())
        if mostAtOnce == 1 {
            return "One person at a time is on screen. A face is seen in \(share) percent of the recording."
        }
        let others = Double(samplesWithOthers) * every
        let first = firstWithOthers.map { ", first at " + Format.timecode($0) } ?? ""
        return "Other people appear: up to \(mostAtOnce) people at once, for \(Format.length(others)) in all\(first)."
    }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode(_ json: String?) -> FacesFound? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(FacesFound.self, from: data)
    }

    /// Everything from the samples: tracks, rows and the facts. Pure.
    static func from(samples: [FaceSample], cuts: [Double], duration: Double, checkedAt: Date, every: Double = FaceScan.every,
                     seconds: Double = 0) -> (found: FacesFound, tracks: [FaceTrack], rows: [[Int]]) {
        let tracks = FaceTracker.tracks(samples, cuts: cuts)
        let rows = FaceGrouping.rows(tracks)
        var found = FacesFound(checkedAt: checkedAt, duration: duration, every: every)
        found.samples = samples.count
        found.samplesWithFaces = samples.filter { !$0.faces.isEmpty }.count
        found.mostAtOnce = samples.map(\.faces.count).max() ?? 0
        let crowded = samples.filter { $0.faces.count >= 2 }.sorted { $0.time < $1.time }
        found.samplesWithOthers = crowded.count
        found.firstWithOthers = crowded.first?.time
        found.tracks = tracks.count
        found.cuts = cuts.count
        found.seconds = seconds
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        var people: [FacePerson] = []
        for (index, row) in rows.enumerated() {
            let sightings = row.compactMap { byID[$0] }.flatMap(\.sightings)
            guard sightings.count >= 2, let first = sightings.first, let last = sightings.last else {
                found.glimpses += 1
                continue
            }
            let key = sightings.max { a, b in
                let qa = a.quality ?? -1, qb = b.quality ?? -1
                return qa != qb ? qa < qb : a.box.area < b.box.area
            } ?? first
            // Each sighting stands for the time to the next sample, never more than the recording.
            let onScreen = duration > 0 ? min(Double(sightings.count) * every, duration) : Double(sightings.count) * every
            people.append(FacePerson(id: index + 1, label: "", onScreen: onScreen, first: first.time, last: last.time,
                                     appearances: row.count, keyTime: key.time, keyBox: key.box))
        }
        people.sort { $0.onScreen != $1.onScreen ? $0.onScreen > $1.onScreen : $0.first < $1.first }
        for i in people.indices { people[i].label = "Unnamed \(i + 1)" }
        found.people = people
        return (found, tracks, rows)
    }
}

extension FacesFound {
    /// The step's line in the make's steps and the log: what was looked at and what was found, no names.
    var stepLine: String {
        guard hasPicture else { return "No picture, so no faces to look for." }
        let looked = "Looked at \(Format.number(samples)) frames, two a second."
        switch mostAtOnce {
        case 0: return looked + " No faces seen."
        case 1: return looked + " One person at a time, in \(Format.count(people.count, "row")) on the People tab."
        default:
            return looked + " Other people appear, up to \(mostAtOnce) at once"
                + (firstWithOthers.map { ", first at " + Format.timecode($0) } ?? "") + "."
        }
    }
}
