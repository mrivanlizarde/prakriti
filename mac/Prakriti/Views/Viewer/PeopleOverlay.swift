import SwiftUI

/// The Viewer's People overlay (v2 part M6d, docs/v2/design-spec.md 3.4.1, Q3): on the Original, a rounded rectangle
/// around each face at the moment playing, with its label ("Gabriel", "Unnamed 2") at 13 pt semibold on a material
/// capsule. A face Ivan chose to hide keeps its box, drawn dashed, and its label says the choice ("Unnamed 2, Hide
/// Face"), so the difference is in shape and words, never color alone. Ivan sees faces in his own app: the overlay
/// shows the original as recorded, and hides nothing itself. Boxes only, from the people file; nothing is drawn as
/// hardware (never skeuomorphic).
struct PeopleOverlay: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        if viewer.showsPeople, viewer.rendition == .original, let file = model.peopleBoxes.file(for: recording, folders: model.peopleFolders) {
            GeometryReader { proxy in
                let picture = Self.pictureRect(in: proxy.size, frame: CGSize(width: file.frameWidth, height: file.frameHeight))
                ForEach(PeopleBoxes.boxes(file, at: viewer.time)) { found in
                    let rect = CGRect(x: picture.minX + found.box.x * picture.width, y: picture.minY + found.box.y * picture.height,
                                      width: found.box.width * picture.width, height: found.box.height * picture.height)
                    let label = recording.overlayLabel(row: found.row)
                    PeopleOverlayBox(rect: rect, name: label.name, choice: label.choice, labelBelow: rect.minY < 34)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLine(file))
        }
    }

    /// Where the picture sits in the player at `size`: fitted whole, centered (the player's `.resizeAspect`).
    static func pictureRect(in size: CGSize, frame: CGSize) -> CGRect {
        guard frame.width > 0, frame.height > 0, size.width > 0, size.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / frame.width, size.height / frame.height)
        let width = frame.width * scale, height = frame.height * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func accessibilityLine(_ file: PeopleFile) -> String {
        let boxes = PeopleBoxes.boxes(file, at: model.viewer.time)
        guard !boxes.isEmpty else { return "People: no face at this moment." }
        return "People: " + boxes.map { box in
            let label = recording.overlayLabel(row: box.row)
            return label.choice == .include ? label.name : "\(label.name), \(label.choice.title)"
        }.joined(separator: ", ") + "."
    }
}

/// One face: its box and its label.
struct PeopleOverlayBox: View {
    let rect: CGRect
    let name: String
    let choice: PersonChoice
    let labelBelow: Bool

    var body: some View {
        let hidden = choice != .include
        ZStack(alignment: labelBelow ? .bottomLeading : .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white, style: StrokeStyle(lineWidth: 2.5, dash: hidden ? [7, 5] : []))
                .shadow(color: .black.opacity(0.6), radius: 1.5)
                .frame(width: rect.width, height: rect.height)
            Text(hidden ? "\(name), \(choice.title)" : name)
                .font(AppFont.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
                .offset(y: labelBelow ? 28 : -28)
        }
        .frame(width: rect.width, height: rect.height, alignment: labelBelow ? .bottomLeading : .topLeading)
        .position(x: rect.midX, y: rect.midY)
    }
}

/// The toggles over the picture, top trailing, in one clear-glass group (design spec 3.4.1: the HIG's case for clear
/// glass over video): People on the Original (v2 part M6d), Captions on the Video (v2 part M8c), and the Vertical Guide on both
/// (v2 part M11a). Each shows its word under the symbol at 12 pt semibold, because there are no tooltips.
struct ViewerPictureToggles: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        let hasPeople = model.peopleBoxes.file(for: recording, folders: model.peopleFolders) != nil
        HStack(spacing: 0) {
            if viewer.rendition == .original, hasPeople {
                PictureToggle(title: "People", symbol: "person.crop.rectangle", isOn: viewer.showsPeople) { model.setShowsPeople(!viewer.showsPeople) }
                    .accessibilityHint("Shows a box and a name around each face in the original.")
                    .quickHelp("Draws a box around each face in the original, with its name or Unnamed, and the choice for anyone hidden.",
                               article: "people-and-privacy")
            } else if viewer.rendition == .video, !viewer.captions.isEmpty {
                PictureToggle(title: "Captions", symbol: "captions.bubble", isOn: viewer.showsCaptions) { model.setShowsCaptions(!viewer.showsCaptions) }
                    .accessibilityHint("Shows the captions file that goes with the video, as it will be uploaded.")
                    .quickHelp("Shows the video's captions over the picture: the same .srt file that is uploaded with it.",
                               article: "reviewing-and-approving")
            }
            if viewer.rendition == .original || viewer.rendition == .video, hasPeople {
                PictureToggle(title: "Vertical Guide", symbol: "rectangle.portrait", isOn: viewer.showsVerticalGuide) {
                    model.setShowsVerticalGuide(!viewer.showsVerticalGuide)
                }
                .accessibilityHint("Shades everything outside the 9:16 window the shorts use, which follows the speaker.")
                .quickHelp("Shades the picture outside the vertical window the shorts are cut from. The window follows the speaker the way the shorts do.",
                           article: "reviewing-and-approving")
            }
        }
    }
}

/// One toggle over the picture: its symbol, filled when on, and its word under it.
struct PictureToggle: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: isOn ? symbol + ".fill" : symbol)
                    .font(AppFont.body)
                Text(title)
                    .font(AppFont.toggleLabel)
            }
            // White on a darkened clear glass: measured in `make look` (13 Oct), accent text on clear glass over a bright
            // picture could not be read. On and off differ by the symbol's fill, never by color alone.
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.tint(.black.opacity(0.4)), in: .rect(cornerRadius: 12))
        .padding(12)
        .accessibilityLabel(isOn ? "\(title), shown" : "\(title), hidden")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// The Captions overlay on the Video (v2 part M8c, design spec 3.4.1): the caption the video's `.srt` shows at the moment
/// playing, white on a dark box near the bottom of the picture, as a player shows a captions file. Text only; nothing drawn
/// as hardware.
struct CaptionsOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        if let cue = viewer.currentCaption {
            GeometryReader { proxy in
                let picture = PeopleOverlay.pictureRect(in: proxy.size, frame: viewer.videoSize)
                Text(cue.lines.joined(separator: "\n"))
                    .font(AppFont.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.black.opacity(0.75)))
                    .position(x: picture.midX, y: picture.maxY - max(40, picture.height * 0.1))
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Caption: " + cue.text)
        }
    }
}
