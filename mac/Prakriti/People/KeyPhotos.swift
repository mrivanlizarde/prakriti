import CoreGraphics
import Foundation
import Observation

// The gallery's key photos (v2 part M7a, PLAN section 5: "a key photo from a real frame for a person who may appear").
// Like the People tab's faces (`FaceCrops`), each is cropped from the original at the face row's key moment while the
// gallery shows it, held in memory, and never written: the store keeps only which recording and which row
// (`Person.keyPhoto`). So `make accept-people`'s rule holds: the card pictures are the only images Prakriti keeps.

@MainActor
@Observable
final class KeyPhotos {
    /// One crop per recording and face row.
    private var images: [KeyPhotoChoice: CGImage] = [:]
    @ObservationIgnored private var loading: Set<KeyPhotoChoice> = []
    /// Sample data and snapshots: a test pattern in place of every face (docs/v2/PLAN.md section 11, D1).
    @ObservationIgnored var useTestPattern = false
    /// At most this many crops are held; the oldest asked for go first.
    @ObservationIgnored private var order: [KeyPhotoChoice] = []
    static let limit = 60

    init() {}

    func image(for choice: KeyPhotoChoice) -> CGImage? {
        if useTestPattern { return FaceCrops.testPattern(seed: choice.row + Int(choice.recording.uuid.0)) }
        return images[choice]
    }

    /// Crops the face off the main thread and keeps it in memory.
    func load(_ choice: KeyPhotoChoice, file: String, face: FacePerson) {
        guard !useTestPattern, images[choice] == nil, !loading.contains(choice) else { return }
        loading.insert(choice)
        let url = URL(fileURLWithPath: file)
        Task { @MainActor in
            let crop = await Task.detached { await FaceCrops.crop(file: url, time: face.keyTime, box: face.keyBox) }.value
            self.loading.remove(choice)
            guard let crop else { return }
            self.images[choice] = crop
            self.order.append(choice)
            if self.order.count > Self.limit { self.images[self.order.removeFirst()] = nil }
        }
    }

    /// Drops every crop (a person forgotten or removed, or the gallery closed for good).
    func clear() {
        images = [:]
        order = []
    }
}
