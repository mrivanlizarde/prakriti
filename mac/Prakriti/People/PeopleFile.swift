import Foundation

// The people file and the job folder (v2 part M6a, docs/v2/PLAN.md M6, research-people.md 5.1 and 5.4).
//
// The people file is `<Application Support>/People/Recordings/<recording id>.json`: when and where each face
// was seen (tracks as times and boxes), the rows of the People tab, and nothing else. **No landmarks, no
// embedding and no picture, for anyone** in this part: a box and a time are what hiding a face needs later
// (M6d), and they are not a print of anyone's face. A picture is kept later only for a named person who may
// appear (section 5 of the plan); every other face is cropped live from the video while the People tab is open.
//
// The job folder is `<Application Support>/Jobs/<uuid>/`: the face step writes the people file there first and
// moves it into place only when it is whole, then deletes the job folder. Every launch deletes any job folder
// a crash left, before anything else (research-people.md 5.4), so nothing a pass was working on outlives it.

/// Where the people pass keeps what it keeps, for one mode (live or development).
struct PeopleFolders: Sendable, Equatable {
    /// The mode's Application Support folder (`AppPaths.applicationSupport`).
    let support: URL

    var people: URL { support.appending(path: "People", directoryHint: .isDirectory) }
    var recordings: URL { people.appending(path: "Recordings", directoryHint: .isDirectory) }
    var jobs: URL { support.appending(path: "Jobs", directoryHint: .isDirectory) }

    /// Folders that must never exist while no one has a release (docs/v2/PLAN.md M6 check 7): the gallery's face
    /// crops, voice prints and Apple's face index, which part M7 makes for named people only.
    var forbidden: [URL] {
        ["Faces", "Voices", "FaceIndex"].map { people.appending(path: $0, directoryHint: .isDirectory) }
    }

    func peopleFile(for recordingID: UUID) -> URL {
        recordings.appending(path: recordingID.uuidString + ".json")
    }

    /// A new, empty job folder.
    func newJob() throws -> URL {
        let folder = jobs.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Deletes every job folder: at launch, before anything else, only by the copy that holds its mode's lock (a
    /// job folder is never left on purpose, so any found then was left by a crash). Returns how many it deleted.
    @discardableResult
    func deleteLeftoverJobs() -> Int {
        let found = (try? FileManager.default.contentsOfDirectory(at: jobs, includingPropertiesForKeys: nil)) ?? []
        var deleted = 0
        for item in found where (try? FileManager.default.removeItem(at: item)) != nil { deleted += 1 }
        return deleted
    }

    /// Forgets one recording's people file (Remove from Library; research-people.md 5.4).
    func removePeopleFile(for recordingID: UUID) {
        try? FileManager.default.removeItem(at: peopleFile(for: recordingID))
    }

    func read(_ recordingID: UUID) -> PeopleFile? {
        guard let data = try? Data(contentsOf: peopleFile(for: recordingID)) else { return nil }
        return try? PeopleFile.decoder.decode(PeopleFile.self, from: data)
    }
}

/// One recording's people file. Each box is `[time, x, y, width, height, confidence]` with x and y from the top
/// left (`FaceBox`), rounded to 4 places: six numbers, never a long list of numbers (a face print is 128 or
/// more, and check 7 fails on any such list in this file).
struct PeopleFile: Codable, Equatable, Sendable {
    struct Track: Codable, Equatable, Sendable {
        var id: Int
        /// The People tab row it belongs to (`FacePerson.id`), or nil for a face seen in one sample only.
        var person: Int?
        var start: Double
        var end: Double
        var boxes: [[Double]]
    }

    var version = 1
    var recordingID: UUID
    var madeAt: Date
    var duration: Double
    var hasPicture: Bool
    var frameWidth: Int
    var frameHeight: Int
    var every: Double
    var samples: Int
    var cuts: [Double]
    var tracks: [Track]
    var people: [FacePerson]
    /// Which steps of the people pass ran: "faces" (part M6a), then "voices" (M6b). The people check counts as run
    /// only once both have (docs/v2/PLAN.md M6).
    var steps: [String] = ["faces"]
    /// Who speaks when (part M6b): times only, never a voice print. Nil until the voice step ran.
    var voices: Voices?

    /// The voice step's part of the file. Each segment is `[start, end, voice]` and each link `[voice, face row]`:
    /// short lists of numbers, never a print.
    struct Voices: Codable, Equatable, Sendable {
        /// "tracks" or "diarizer".
        var source: String
        var tracks: [Int]
        var segments: [[Double]]
        var links: [[Int]]

        var voiceSegments: [VoiceSegment] {
            segments.compactMap { $0.count >= 3 ? VoiceSegment(start: $0[0], end: $0[1], voice: Int($0[2])) : nil }
        }
    }

    static func round(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }

    init(recordingID: UUID, scan: FaceScan.Result, found: FacesFound, tracks: [FaceTrack], rows: [[Int]]) {
        self.recordingID = recordingID
        madeAt = found.checkedAt
        duration = scan.duration
        hasPicture = scan.hasPicture
        frameWidth = scan.width
        frameHeight = scan.height
        every = found.every
        samples = found.samples
        cuts = scan.cuts.map(Self.round)
        var personOf: [Int: Int] = [:]
        for (index, row) in rows.enumerated() where found.people.contains(where: { $0.id == index + 1 }) {
            for track in row { personOf[track] = index + 1 }
        }
        self.tracks = tracks.map { track in
            Track(id: track.id, person: personOf[track.id], start: Self.round(track.start), end: Self.round(track.end),
                  boxes: track.sightings.map { s in [s.time, s.box.x, s.box.y, s.box.width, s.box.height, s.confidence].map(Self.round) })
        }
        people = found.people
    }

    /// A people file made up for sample data and the tests (v2 part M6d): boxes and times as given, no scan behind them.
    init(recordingID: UUID, duration: Double, frameWidth: Int, frameHeight: Int, tracks: [Track], people: [FacePerson], cuts: [Double] = []) {
        self.recordingID = recordingID
        madeAt = Date(timeIntervalSince1970: 0)
        self.duration = duration
        hasPicture = true
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        every = FaceScan.every
        samples = Int(duration / FaceScan.every)
        self.cuts = cuts
        self.tracks = tracks
        self.people = people
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Written into `job` first, then moved over the recording's people file in one step, so a crash never
    /// leaves half a file where the app reads it.
    func save(in folders: PeopleFolders, job: URL) throws {
        let staged = job.appending(path: recordingID.uuidString + ".json")
        try Self.encoder.encode(self).write(to: staged, options: .atomic)
        try FileManager.default.createDirectory(at: folders.recordings, withIntermediateDirectories: true)
        let target = folders.peopleFile(for: recordingID)
        if FileManager.default.fileExists(atPath: target.path) {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: target)
        }
    }
}

/// The face step, as the pipeline and Look for Faces run it: the scan, the facts, and the people file, through a
/// job folder that is always deleted when the step ends.
enum FaceStep {
    struct Outcome: Sendable {
        var found: FacesFound
        var file: URL?
    }

    static func run(file: URL, recordingID: UUID, folders: PeopleFolders, now: Date, control: ProcessControl? = nil,
                    progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Outcome {
        let job = try folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        let scan = try await FaceScan.scan(file: file, control: control, progress: progress)
        let made = FacesFound.from(samples: scan.samples, cuts: scan.cuts, duration: scan.duration, checkedAt: now, seconds: scan.seconds)
        var found = made.found
        found.hasPicture = scan.hasPicture
        let people = PeopleFile(recordingID: recordingID, scan: scan, found: found, tracks: made.tracks, rows: made.rows)
        try people.save(in: folders, job: job)
        return Outcome(found: found, file: folders.peopleFile(for: recordingID))
    }
}
