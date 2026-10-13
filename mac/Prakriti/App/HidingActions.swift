import CoreGraphics
import Foundation
import ImageIO
import Observation
import SwiftData

// Hiding in pictures, in the app (v2 part M6d, docs/v2/PLAN.md M6): which faces a recording's pictures hide, its card
// picture (made after the people pass and again after every change of choice or name), and the boxes the Viewer's
// People overlay draws.

extension Recording {
    /// Whether the faces of a People tab row (nil: the faces seen for under a second) are hidden in pictures: when the
    /// person's choice is Hide Face or Leave Out for any output. The card picture is not an output, so it takes the
    /// strictest of them (Ivan, Mon 12 Oct: "Faces of anyone not Included are never in a thumbnail").
    func hidesFace(row: Int?) -> Bool {
        let key = PersonKey.face(row ?? 0, names: resolvedNameTable)
        let choices = self.choices
        return ChoiceOutput.allCases.contains { choices.choice(key, for: $0) != .include }
    }

    /// The hidden tracks of this recording's people file.
    func hidePlan(_ file: PeopleFile) -> HidePlan {
        HidePlan.from(file) { hidesFace(row: $0) }
    }

    /// The People tab rows that carry a name (Gabriel's face first in a card picture).
    var namedFaceRows: Set<Int> { Set(resolvedNameTable.faces.keys) }

    /// What the People overlay calls a row: the person's name, "Unnamed 2", or "Unnamed" for a face seen for under a
    /// second; and its choice when the face is hidden.
    func overlayLabel(row: Int?) -> (name: String, choice: PersonChoice) {
        let key = PersonKey.face(row ?? 0, names: resolvedNameTable)
        let name: String = switch key {
        case .face(0): "Unnamed"
        default: label(for: key)
        }
        return (name, choices.overall(key).choice)
    }
}

/// The card pictures the browser shows (design spec 3.1.2), read from `Thumbnails/` off the main thread and held in
/// memory. A change of choice deletes the picture at once and bumps its version, so a card never shows a picture made
/// under older choices.
@MainActor
@Observable
final class CardPictures {
    /// Bumped whenever a recording's picture is deleted or made again.
    private(set) var versions: [UUID: Int] = [:]
    /// The version each loaded picture belongs to (observed, so a card draws once its picture has loaded).
    private var loaded: [UUID: Int] = [:]
    @ObservationIgnored private var images: [UUID: CGImage] = [:]
    @ObservationIgnored private var loading: Set<UUID> = []
    /// Sample data and snapshots: a test pattern for every recording whose people were checked, so no frame of anyone
    /// is drawn (docs/v2/PLAN.md section 11, D1).
    @ObservationIgnored var useTestPattern = false
    @ObservationIgnored var folders: PeopleFolders

    init(folders: PeopleFolders) {
        self.folders = folders
    }

    func version(_ id: UUID) -> Int { versions[id] ?? 0 }

    /// The picture to draw now, or nil (the plain tile). Read only, so a view's body never changes this model.
    func image(for recording: Recording) -> CGImage? {
        if useTestPattern { return recording.faces?.hasPicture == true ? Self.testPattern(seed: recording.sessionDate.hashValue) : nil }
        guard loaded[recording.id] == version(recording.id) else { return nil }
        return images[recording.id]
    }

    /// Reads the recording's picture, if there is one, off the main thread.
    func load(_ recording: Recording) {
        guard !useTestPattern else { return }
        let id = recording.id, version = version(id)
        guard loaded[id] != version, !loading.contains(id) else { return }
        loading.insert(id)
        let url = folders.thumbnail(for: id)
        Task { @MainActor in
            let image = await Task.detached { () -> CGImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
                return CGImageSourceCreateImageAtIndex(source, 0, nil)
            }.value
            self.loading.remove(id)
            guard self.version(id) == version else { return }
            self.images[id] = image
            self.loaded[id] = version
        }
    }

    /// The picture was deleted or made again.
    func changed(_ id: UUID) {
        versions[id] = version(id) + 1
        images[id] = nil
        loaded[id] = nil
    }

    /// A calm landscape of soft bands, never a face: what sample data shows where a card picture would be.
    nonisolated static func testPattern(seed: Int) -> CGImage? {
        let width = 320, height = 180
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let palettes: [[(CGFloat, CGFloat, CGFloat)]] = [
            [(0.93, 0.80, 0.62), (0.86, 0.42, 0.04), (0.59, 0.32, 0.19)],
            [(0.80, 0.86, 0.93), (0.27, 0.35, 0.91), (0.16, 0.20, 0.45)],
            [(0.85, 0.92, 0.84), (0.20, 0.60, 0.45), (0.10, 0.30, 0.25)],
        ]
        let colors = palettes[abs(seed) % palettes.count]
        for (index, color) in colors.enumerated() {
            context.setFillColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
            let top = CGFloat(height) * CGFloat(colors.count - index) / CGFloat(colors.count)
            context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: top))
        }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35))
        context.fillEllipse(in: CGRect(x: 200, y: 110, width: 60, height: 60))
        return context.makeImage()
    }
}

/// The boxes the Viewer's People overlay draws (design spec 3.4.1): each face's box at the moment playing, from the people
/// file's sightings (two a second), moved smoothly between them. Read once per recording and held in memory; boxes and
/// times only.
@MainActor
final class PeopleBoxes {
    struct Box: Equatable, Identifiable {
        var id: Int
        var row: Int?
        var box: FaceBox
    }

    private var cache: [UUID: (stamp: Double, file: PeopleFile)] = [:]

    func file(for recording: Recording, folders: PeopleFolders) -> PeopleFile? {
        let stamp = recording.faces?.checkedAt.timeIntervalSince1970 ?? -1
        if let hit = cache[recording.id], hit.stamp == stamp { return hit.file }
        guard recording.faces != nil, let file = folders.read(recording.id) else { return nil }
        cache[recording.id] = (stamp, file)
        return file
    }

    /// Sample data's boxes (snapshots and window captures), held as if read from a people file: nothing is written.
    func seed(_ recording: Recording, file: PeopleFile) {
        cache[recording.id] = (recording.faces?.checkedAt.timeIntervalSince1970 ?? -1, file)
    }

    /// Every face on screen at `time`. Between two sightings of a track no more than 0.6 s apart the box moves in a straight
    /// line; within a quarter of a second of a single sighting it is held. Pure, so the tests drive it.
    static func boxes(_ file: PeopleFile, at time: Double) -> [Box] {
        file.tracks.compactMap { track -> Box? in
            guard let first = track.boxes.first, let last = track.boxes.last, first.count >= 5,
                  time >= first[0] - 0.25, time <= last[0] + 0.25 else { return nil }
            let after = track.boxes.firstIndex { $0[0] > time }
            let before = after.map { $0 > 0 ? track.boxes[$0 - 1] : nil } ?? track.boxes.last
            func face(_ b: [Double]) -> FaceBox { FaceBox(x: b[1], y: b[2], width: b[3], height: b[4]) }
            if let before, let next = after.map({ track.boxes[$0] }), next[0] - before[0] <= 0.6 {
                let t = (time - before[0]) / max(0.001, next[0] - before[0])
                let a = face(before), b = face(next)
                return Box(id: track.id, row: track.person, box: FaceBox(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t,
                                                                          width: a.width + (b.width - a.width) * t,
                                                                          height: a.height + (b.height - a.height) * t))
            }
            let nearest = [before, after.map { track.boxes[$0] }].compactMap { $0 }.min { abs($0[0] - time) < abs($1[0] - time) }
            guard let nearest, abs(nearest[0] - time) <= 0.25 else { return nil }
            return Box(id: track.id, row: track.person, box: face(nearest))
        }
    }
}

extension AppModel {
    /// Makes a recording's card picture again: the old one is deleted at once (so a card never shows a picture made under
    /// older choices), then the people pass's tracks and Ivan's choices choose a new one in the background. Only after
    /// the face step ran, and never from a placeholder in iCloud. One at a time per recording, the newest last.
    func refreshCardPicture(_ recording: Recording) {
        let id = recording.id
        let folders = peopleFolders
        folders.removeThumbnail(for: id)
        cardPictures.changed(id)
        let previous = cardPictureWork[id]
        previous?.cancel()
        guard recording.faces?.hasPicture == true, let people = folders.read(id) else { cardPictureWork[id] = nil; return }
        let original = URL(fileURLWithPath: recording.filePath)
        guard FileManager.default.fileExists(atPath: original.path), !Readiness.isDataless(original) else { cardPictureWork[id] = nil; return }
        let plan = recording.hidePlan(people)
        let named = recording.namedFaceRows
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        let started = now()
        cardPictureWork[id] = Task { @MainActor in
            // The newest request runs last: wait for the one before it to stop, so an older picture can never land after a
            // newer one.
            _ = await previous?.result
            guard !Task.isCancelled else { return }
            let work = Task.detached(priority: .utility) {
                try await CardPicture.make(original: original, recordingID: id, people: people, plan: plan, namedRows: named, folders: folders, now: started)
            }
            let outcome: CardPicture.Outcome?
            do {
                outcome = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
            } catch {
                if !(error is CancellationError) { record("\(label): the card picture could not be made. \(error.localizedDescription)", level: .attention) }
                outcome = nil
            }
            guard !Task.isCancelled else { return }
            cardPictures.changed(id)
            cardPictureOutcomes[id] = outcome
            if let outcome { record("\(label): " + outcome.line + String(format: " (%.1f s)", outcome.seconds)) }
        }
    }

    /// Waits for every card picture being made (the acceptance tests and the snapshots).
    func cardPicturesSettled() async {
        while true {
            let pending = Array(cardPictureWork.values)
            for work in pending { _ = await work.result }
            if Set(cardPictureWork.values) == Set(pending) { return }
        }
    }

    /// After a change of names in Settings (a name removed), every recording that used it.
    func refreshCardPictures(naming person: UUID) {
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in all where recording.names.faces.values.contains(person) || recording.names.voices.values.contains(person)
            || recording.names.teacher == person {
            refreshCardPicture(recording)
        }
    }
}
