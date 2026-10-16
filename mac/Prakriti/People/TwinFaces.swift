import Foundation

// The vertical twin's own face step (v2 part M11a, docs/v2/PLAN.md M11 and risk R20): the twin is a second camera, so the main
// recording's face boxes say nothing about where anyone is in its picture. When a short uses the twin, the face step's scan
// (`FaceScan`, two frames a second, Vision's face finder) runs on the twin itself over the stretch the short shows, its sightings
// are joined into tracks (`FaceTracker`), and each track is matched to the main recording's people:
//
// - **By time**: at each of the track's sightings, the faces the twin sees at that moment and the faces the main recording's
//   people check saw at the same moment (the twin's clock moved by the measured offset) are put in order across the picture;
//   when there are as many of one as of the other, each twin face takes the row of the main face in the same place.
// - **By voice**, when the counts differ and the twin sees one face only: the voice speaking at that moment, when the people
//   check linked it to a face row seen at that moment, names that row.
// - A track is matched to a row only when 3 or more of its sightings (or all of a shorter track's) vote and 60% or more of the
//   votes are that row. Otherwise it is unknown, and **unknown means hidden**: every twin track not matched to someone Included
//   in the shorts is hidden in the short (`hidden`), and the picture output check then accounts for every face against these
//   tracks (PLAN check 2b).
//
// Nothing is kept: the twin's sightings live in memory for the short and are dropped; only counts reach the log and the shorts'
// record. No picture, print or landmark of anyone. Files under `People/` never reach the network (RulesTests).

enum TwinFaces {
    /// How near in time a main sighting must be to count at a twin moment (the face step looks twice a second).
    static let near = 0.3
    /// The votes a track needs, and the share of them for one row.
    static let leastVotes = 3
    static let share = 0.6

    /// One twin track and the main recording's row it was matched to (nil: unknown).
    struct Match: Equatable, Sendable {
        var track: Int
        var row: Int?
        var votes: Int
        var sightings: Int
    }

    struct Found: Sendable {
        var tracks: [FaceTrack]
        var matches: [Match]
        var samples: Int
        var seconds: Double

        func row(of track: Int) -> Int? { matches.first { $0.track == track }?.row }

        /// The line for the log and the record: counts only.
        var line: String {
            let matched = matches.filter { $0.row != nil }.count
            return "the vertical recording's own face step ran: \(Format.count(samples, "frame")) looked at, \(Format.count(tracks.count, "face track")), "
                + "\(matched) matched to the main recording's people, \(tracks.count - matched) unknown (hidden)"
        }
    }

    /// The main recording's sightings, as the matcher reads them: each with its row (nil for a glimpse).
    struct MainSighting: Equatable, Sendable {
        var time: Double
        var x: Double
        var row: Int?
        var track: Int
    }

    static func mainSightings(_ file: PeopleFile) -> [MainSighting] {
        file.tracks.flatMap { track in
            track.boxes.compactMap { b in b.count >= 5 ? MainSighting(time: b[0], x: b[1] + b[3] / 2, row: track.person, track: track.id) : nil }
        }.sorted { $0.time < $1.time }
    }

    /// Matches the twin's tracks to the main recording's rows. `offset` is the twin's lead in seconds (a twin moment `t` is the
    /// main recording's `t - offset`); `segments` and `links` are the people check's voices (`[voice, face row]`). Pure.
    static func match(_ tracks: [FaceTrack], main: [MainSighting], offset: Double, segments: [VoiceSegment], links: [[Int]]) -> [Match] {
        // Every twin sighting by its sample time, so the faces seen together are known.
        var atTime: [Double: [(track: Int, x: Double)]] = [:]
        for track in tracks {
            for s in track.sightings { atTime[s.time, default: []].append((track.id, s.box.centerX)) }
        }
        var votes: [Int: [Int: Int]] = [:]
        func mainAt(_ m: Double) -> [MainSighting] {
            // The nearest sighting of each main track within `near`.
            var lo = 0, hi = main.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if main[mid].time < m - near { lo = mid + 1 } else { hi = mid }
            }
            var best: [Int: MainSighting] = [:]
            var i = lo
            while i < main.count && main[i].time <= m + near {
                let s = main[i]
                if let b = best[s.track], abs(b.time - m) <= abs(s.time - m) {} else { best[s.track] = s }
                i += 1
            }
            return Array(best.values)
        }
        for (time, faces) in atTime {
            let m = time - offset
            let seen = mainAt(m).sorted { $0.x < $1.x }
            let ours = faces.sorted { $0.x < $1.x }
            if !seen.isEmpty && seen.count == ours.count {
                for (twin, mainFace) in zip(ours, seen) {
                    if let row = mainFace.row { votes[twin.track, default: [:]][row, default: 0] += 1 }
                }
            } else if ours.count == 1 {
                // By voice: the voice speaking now, linked to a face row the main recording sees now.
                let speaking = segments.filter { m >= $0.start && m <= $0.end }.map(\.voice)
                let rows = Set(links.filter { $0.count >= 2 && speaking.contains($0[0]) }.map { $0[1] })
                let onScreen = Set(seen.compactMap(\.row))
                let candidates = rows.intersection(onScreen.isEmpty ? rows : onScreen)
                if candidates.count == 1, let row = candidates.first { votes[ours[0].track, default: [:]][row, default: 0] += 1 }
            }
        }
        return tracks.map { track in
            let counted = votes[track.id] ?? [:]
            let total = counted.values.reduce(0, +)
            let top = counted.max { $0.value < $1.value }
            let enough = total >= min(leastVotes, track.sightings.count) && total > 0
            let row = (top.map { Double($0.value) / Double(max(1, total)) >= share } ?? false) && enough ? top?.key : nil
            return Match(track: track.id, row: row, votes: total, sightings: track.sightings.count)
        }
    }

    /// The face step on the twin over `range` (the twin's clock), and the matches. `included` is asked about each matched row.
    static func run(twin: URL, range: ClosedRange<Double>, main: PeopleFile?, offset: Double, control: ProcessControl? = nil) async throws -> Found {
        let scan = try await FaceScan.scan(file: twin, range: range, control: control)
        let tracks = FaceTracker.tracks(scan.samples, cuts: scan.cuts)
        let matches = match(tracks, main: main.map(mainSightings) ?? [], offset: offset,
                            segments: main?.voices?.voiceSegments ?? [], links: main?.voices?.links ?? [])
        return Found(tracks: tracks, matches: matches, samples: scan.samples.count, seconds: scan.seconds)
    }

    /// The twin's tracks to hide: every track not matched to a row `shown` says yes to (unknown means hidden).
    static func hidePlan(_ found: Found, shown: (Int) -> Bool) -> HidePlan {
        HidePlan(tracks: found.tracks.filter { track in found.row(of: track.id).map { !shown($0) } ?? true }.map { track in
            HiddenTrack(id: track.id, spots: track.sightings.map { HiddenTrack.Spot(time: $0.time, box: $0.box) })
        }.filter { !$0.spots.isEmpty })
    }

    /// The twin's tracks as the picture output check reads them, each hidden or not by the same rule.
    static func checkTracks(_ found: Found, shown: (Int) -> Bool) -> [PictureOutputCheck.Track] {
        found.tracks.map { track in
            PictureOutputCheck.Track(id: track.id, hidden: found.row(of: track.id).map { !shown($0) } ?? true,
                                     spots: track.sightings.map { HiddenTrack.Spot(time: $0.time, box: $0.box) })
        }
    }
}
