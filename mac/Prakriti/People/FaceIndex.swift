@preconcurrency import AVFoundation
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import MediaIntelligence
import UniformTypeIdentifiers

// Apple's face index, and identifying a recording against it (v2 part M7b, docs/v2/PLAN.md M7, research-people.md
// 1.2, 2.1 to 2.4, 5.1, 5.2 and 5.4).
//
// - The index is `MediaIntelligence.FaceGroupAnalyzer` in `<Application Support>/People/FaceIndex/`. Prakriti cannot
//   encrypt the framework's files, so the index is never the record: it holds only what the sealed crops of people with
//   a release can rebuild (`PrintVault`), and it is rebuilt from them, whole, after every change (a person learned, a
//   Yes in Review, a crop deleted by "Not [name]", a Merge, a Forget). When nobody is learned the folder does not exist
//   (PLAN M6 check 7).
// - An asset id is the sealed crop's own file name, a UUID: the framework prints every asset id to the log (measured,
//   research 1.2), so it is never a file name of a recording or anything about a person. The person an asset belongs
//   to is the vault folder it is sealed in.
// - Identifying a recording uses `identifyFaces(in:)`, which stores nothing (measured Sat 10 Oct and again by
//   `make accept-gallery`: the index's files are unchanged in size and date). The frames it reads are written to a job
//   folder and deleted when it ends; a crash leaves them to the next launch's cleanup (Mac warning 113).
// - Files under `People/` never reach the network (`RulesTests.testFaceWorkCannotReachTheNetwork`).

/// One sealed crop: where it came from (so "Not [name]" and Forget can find it) and the picture. Sealed whole under the
/// person's key, so neither the origin nor the picture is readable on disk.
struct SealedCrop: Codable, Equatable, Sendable {
    struct Origin: Codable, Equatable, Hashable, Sendable {
        var recording: UUID
        var row: Int
        var time: Double
    }

    var origin: Origin
    var jpeg: Data

    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) throws -> SealedCrop { try JSONDecoder().decode(SealedCrop.self, from: data) }
}

/// The face index of one mode.
struct FaceIndex: Sendable {
    let vault: PrintVault

    var directory: URL { vault.folders.people.appending(path: "FaceIndex", directoryHint: .isDirectory) }

    /// The index exists: someone with a release has crops in it.
    var exists: Bool { FileManager.default.fileExists(atPath: directory.path) }

    struct Failure: Error, Sendable, Equatable { let reason: String }

    /// Every sealed face crop of the given people: its asset id (the file's UUID), whose it is, and where it is.
    func crops(of people: Set<UUID>) -> [(asset: String, person: UUID, file: URL)] {
        people.sorted { $0.uuidString < $1.uuidString }.flatMap { person in
            let files = (try? FileManager.default.contentsOfDirectory(at: vault.folder(.face, person: person), includingPropertiesForKeys: nil)) ?? []
            return files.filter { $0.pathExtension == "sealed" }.sorted { $0.path < $1.path }
                .map { (asset: $0.deletingPathExtension().lastPathComponent, person: person, file: $0) }
        }
    }

    /// Each crop's origin, opened under its person's key (for "Not [name]" and learning only what is new).
    func origins(of person: UUID) -> [(file: URL, origin: SealedCrop.Origin)] {
        crops(of: [person]).compactMap { crop in
            guard let data = try? vault.open(crop.file, person: person), let sealed = try? SealedCrop.decode(data) else { return nil }
            return (crop.file, sealed.origin)
        }
    }

    struct Summary: Equatable, Sendable {
        var people = 0
        var crops = 0
        /// Faces the analyzer found in the crops (one per crop when every crop is good).
        var faces = 0
        /// Groups the analyzer made (one per person when it groups them as Prakriti does).
        var groups = 0
        /// Crops that could not be opened (a key gone): left out of the index.
        var unreadable = 0
        var seconds: Double = 0

        var line: String {
            guard crops > 0 else { return "The face index is empty, so it was removed." }
            return "The face index was rebuilt from \(Format.count(crops, "crop")) of \(Format.count(people, "person", "people")): "
                + "\(Format.count(faces, "face")) found, \(Format.count(groups, "group")), in \(String(format: "%.1f", seconds)) s."
                + (unreadable > 0 ? " \(Format.count(unreadable, "crop")) could not be opened and were left out." : "")
        }
    }

    /// Rebuilds the index from the sealed crops of `learning` (the people with a release that covers their face), or
    /// removes it when there are none. Purged first, so nothing of anyone else survives in it.
    func rebuild(learning: Set<UUID>) async throws -> Summary {
        let started = ContinuousClock.now
        let crops = crops(of: learning)
        if exists {
            try? await FaceGroupAnalyzer.purge(workingDirectory: directory)
            try? FileManager.default.removeItem(at: directory)
        }
        var summary = Summary()
        guard !crops.isEmpty else { return summary }
        vault.prepare()
        let job = try vault.folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        var assets: [MediaIntelligenceImageAsset] = []
        var people = Set<UUID>()
        for crop in crops {
            guard let data = try? vault.open(crop.file, person: crop.person), let sealed = try? SealedCrop.decode(data) else {
                summary.unreadable += 1
                continue
            }
            let url = job.appending(path: crop.asset + ".jpg")
            try sealed.jpeg.write(to: url)
            assets.append(MediaIntelligenceImageAsset(id: .init(crop.asset), kind: .url(url)))
            people.insert(crop.person)
        }
        guard !assets.isEmpty else { return summary }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let analyzer = try FaceGroupAnalyzer(workingDirectory: directory)
        for try await item in try await analyzer.insertOrUpdateAssets(assets) { summary.faces += item.faces.count }
        try await analyzer.update()
        for try await _ in analyzer.allEntities { summary.groups += 1 }
        summary.people = people.count
        summary.crops = assets.count
        let elapsed = ContinuousClock.now - started
        summary.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return summary
    }

    /// Each group of the index, read through the vault: the one person whose crops make it up, or a conflict.
    func groups(_ analyzer: FaceGroupAnalyzer, learning: Set<UUID>) async throws -> [String: FrameIdentity] {
        let owner = Dictionary(crops(of: learning).map { ($0.asset, $0.person) }, uniquingKeysWith: { a, _ in a })
        var out: [String: FrameIdentity] = [:]
        for try await (entity, assets) in analyzer.allAssetIDsByEntityID {
            let people = Set(assets.compactMap { owner[$0.rawValue] })
            out[entity.rawValue] = people.count == 1 ? .person(people.first!) : (people.isEmpty ? .nobody : .conflict)
        }
        return out
    }

    /// Identifies picture files against the index without storing anything. Each found face comes back in the top-left
    /// convention, read through the gallery. With no index, nothing is identified (an empty answer).
    func identify(_ pictures: [(id: String, url: URL)], learning: Set<UUID>) async throws -> [String: [RowVotes.Found]] {
        guard exists, !pictures.isEmpty else { return [:] }
        let analyzer = try FaceGroupAnalyzer(workingDirectory: directory)
        let groups = try await groups(analyzer, learning: learning)
        var out: [String: [RowVotes.Found]] = [:]
        let assets = pictures.map { MediaIntelligenceImageAsset(id: .init($0.id), kind: .url($0.url)) }
        for try await (asset, faces) in try await analyzer.identifyFaces(in: assets) {
            out[asset.rawValue, default: []] += faces.map { face in
                RowVotes.Found(box: AnalyzerGeometry.box(fromAnalyzer: face.bounds),
                               identity: face.entityID.map { groups[$0.rawValue] ?? .nobody } ?? .nobody)
            }
        }
        return out
    }

    /// Forget's last proof (research-people.md 5.4): a crop of the forgotten person, held in memory from before the key
    /// was destroyed, identified against the rebuilt index. True when any face in it matched a group.
    func matchesAnyone(_ jpeg: Data, learning: Set<UUID>) async throws -> Bool {
        guard exists else { return false }
        let job = try vault.folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        let id = UUID().uuidString
        let url = job.appending(path: id + ".jpg")
        try jpeg.write(to: url)
        let found = try await identify([(id, url)], learning: learning)
        return (found[id] ?? []).contains { $0.identity != .nobody }
    }

    /// Every file under `People/` with its size and the SHA-256 of its contents, for the proof that identifying stores
    /// nothing (PLAN M7 check 3: "the hash list of every file in People/ is identical before and after").
    static func listing(_ folder: URL) -> [String] {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return [] }
        return walker.compactMap { $0 as? URL }.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { return nil }
            let digest = (try? Data(contentsOf: url)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "unreadable"
            return "\(url.path) \(values.fileSize ?? 0) \(digest)"
        }.sorted()
    }
}

/// Identifying one recording (v2 part M7b): the frames `FrameChoice` picks, taken from the original into a job folder,
/// identified against the index, and read into one vote per face row. Nothing is stored but the votes.
enum RecognitionStep {
    struct Outcome: Sendable {
        var votes: [Int: RowVote]
        /// Frames given to the analyzer, picks made, picks whose box had a found face on it, and faces found.
        var frames = 0
        var picks = 0
        var landed = 0
        var faces = 0
        var seconds: Double = 0

        var line: String {
            let named = votes.values.filter { $0.outcome == .named }.count
            let asked = votes.values.filter { $0.outcome == .ask }.count
            return "Recognition looked at \(Format.count(frames, "frame")): \(Format.count(named, "face row")) named without asking, "
                + "\(asked) to review, \(votes.count - named - asked) not recognized."
        }
    }

    static func run(file: URL, recordingID: UUID, index: FaceIndex, learning: Set<UUID>, voices: [Int: VoiceVote]) async throws -> Outcome? {
        guard index.exists, !learning.isEmpty, let people = index.vault.folders.read(recordingID) else { return nil }
        let started = ContinuousClock.now
        let picks = FrameChoice.picks(people)
        var outcome = Outcome(votes: [:], picks: picks.count)
        guard !picks.isEmpty else { return outcome }
        let job = try index.vault.folders.newJob()
        defer { try? FileManager.default.removeItem(at: job) }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.02, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.02, preferredTimescale: 600)
        var pictures: [(id: String, url: URL)] = []
        var idForTime: [Double: String] = [:]
        for time in Set(picks.map(\.time)).sorted() {
            try Task.checkCancellation()
            guard let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image else { continue }
            let id = UUID().uuidString
            let url = job.appending(path: id + ".jpg")
            guard JPEG.write(frame, to: url) else { continue }
            pictures.append((id, url))
            idForTime[time] = id
        }
        outcome.frames = pictures.count
        let found = try await index.identify(pictures, learning: learning)
        outcome.faces = found.values.map(\.count).reduce(0, +)
        let pairs = picks.compactMap { pick in idForTime[pick.time].map { FaceChoicePair(pick: pick, found: found[$0] ?? []) } }
        outcome.landed = RowVotes.landed(pairs)
        outcome.votes = RowVotes.votes(picks: pairs, voices: voices)
        let elapsed = ContinuousClock.now - started
        outcome.seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return outcome
    }
}

enum JPEG {
    /// Writes a JPEG; false when it could not.
    static func write(_ image: CGImage, to url: URL, quality: Double = 0.9) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    static func data(_ image: CGImage, quality: Double = 0.9) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

/// Learning a person's face (v2 part M7b, research-people.md 2.3 and 2.4): crops cut from the face rows Ivan named for
/// them (by hand, as the teacher, or by a Yes in Review), up to 50 per person, spread across recordings and across each
/// row, each sealed under the person's key with its origin. Only for a person whose recorded release covers their face.
enum Learning {
    static let maximum = 50
    /// A recording gives at most this many crops, so the 50 spread across days, light and angles.
    static let perRecording = 8
    /// The crop's square is this many times the face box, so the analyzer sees the whole head.
    static let pad = 2.2
    /// Crops are at most this many pixels on a side.
    static let largest = 512

    struct Source: Equatable, Sendable {
        var recording: UUID
        var file: String
        var row: Int
    }

    struct Pick: Equatable, Sendable {
        var origin: SealedCrop.Origin
        var file: String
        var box: FaceBox
    }

    /// Which crops to cut: for each source row, its largest, surest sightings spread across the row, skipping origins
    /// already sealed; at most `perRecording` per recording and `maximum` in all with what is kept.
    static func picks(sources: [Source], files: [UUID: PeopleFile], kept: Set<SealedCrop.Origin>) -> [Pick] {
        var room = maximum - kept.count
        guard room > 0 else { return [] }
        var picks: [Pick] = []
        let byRecording = Dictionary(grouping: sources, by: \.recording)
        for recording in byRecording.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard room > 0, let file = files[recording] else { continue }
            let rows = Set(byRecording[recording]!.map(\.row))
            let path = byRecording[recording]!.first!.file
            var sightings: [(origin: SealedCrop.Origin, box: FaceBox, score: Double)] = []
            for track in file.tracks {
                guard let row = track.person, rows.contains(row) else { continue }
                for box in track.boxes where box.count >= 6 {
                    let face = FaceBox(x: box[1], y: box[2], width: box[3], height: box[4])
                    guard face.height >= FrameChoice.minimumHeight else { continue }
                    let origin = SealedCrop.Origin(recording: recording, row: row, time: box[0])
                    guard !kept.contains(origin) else { continue }
                    sightings.append((origin, face, face.area * box[5]))
                }
            }
            guard !sightings.isEmpty else { continue }
            sightings.sort { $0.origin.time < $1.origin.time }
            // The better half by size and sureness, then spread evenly across time.
            let threshold = sightings.map(\.score).sorted()[sightings.count / 2]
            let good = sightings.filter { $0.score >= threshold }
            let count = min(perRecording, room, good.count)
            for i in 0..<count {
                let index = count == 1 ? good.count / 2 : Int((Double(i) * Double(good.count - 1) / Double(count - 1)).rounded())
                picks.append(Pick(origin: good[index].origin, file: path, box: good[index].box))
            }
            room -= count
        }
        return picks
    }

    /// Cuts and seals the picks for `person`. Returns how many were sealed.
    static func seal(_ picks: [Pick], person: UUID, vault: PrintVault) async -> Int {
        var sealed = 0
        for pick in picks {
            guard let image = await FaceCrops.crop(file: URL(fileURLWithPath: pick.file), time: pick.origin.time, box: pick.box, pad: pad),
                  let jpeg = JPEG.data(scaled(image)) else { continue }
            guard let data = try? SealedCrop(origin: pick.origin, jpeg: jpeg).encoded(), (try? vault.seal(data, kind: .face, person: person)) != nil else { continue }
            sealed += 1
        }
        return sealed
    }

    static func scaled(_ image: CGImage) -> CGImage {
        let side = max(image.width, image.height)
        guard side > largest else { return image }
        let scale = Double(largest) / Double(side)
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    /// Deletes the sealed crops of `person` cut from one row of one recording ("Not [name]", research 2.4). Returns how
    /// many it deleted.
    static func deleteCrops(of person: UUID, recording: UUID, row: Int, index: FaceIndex) -> Int {
        var deleted = 0
        for (file, origin) in index.origins(of: person) where origin.recording == recording && origin.row == row {
            if (try? FileManager.default.removeItem(at: file)) != nil { deleted += 1 }
        }
        return deleted
    }
}
