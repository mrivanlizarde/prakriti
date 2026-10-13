import SwiftUI

/// A recording's picture on its card, its list row and its Activity row (v2 part M6d, design spec 3.1.2): the card
/// picture the people pass chose (every face in it someone included, or the others hidden), filling the space; until
/// there is one, the plain tile with the date and the kind of recording. Nothing here chooses a frame or reads the
/// original: the picture comes only from `Thumbnails/`, written after the people pass (`CardPicture`).
struct RecordingPicture: View {
    let recording: Recording
    var compact = false
    @Environment(AppModel.self) private var model

    var body: some View {
        let pictures = model.cardPictures
        Group {
            if let image = pictures.image(for: recording) {
                RoundedRectangle(cornerRadius: compact ? 6 : 10)
                    .fill(.quaternary)
                    .overlay {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 10))
                    .accessibilityHidden(true)
            } else {
                NeutralTile(recording: recording, compact: compact)
            }
        }
        .task(id: pictures.version(recording.id)) { pictures.load(recording) }
    }
}
