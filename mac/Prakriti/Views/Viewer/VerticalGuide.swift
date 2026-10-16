import SwiftUI

/// Where the 9:16 window sits over a recording (v2 part M11a, design spec 3.4.1 "Vertical Guide"): the same face-following window
/// with a dead zone that cuts the shorts (`VerticalCrop.follow`), worked out once over the whole original, ten times a second, from
/// the people file's sightings of the face the shorts follow. Pure numbers; nothing is drawn here.
struct VerticalGuideTrack: Equatable, Sendable {
    static let step = 0.1
    /// The window's width as a fraction of the picture's, and its middle at each step from 0.
    var width: Double
    var centers: [Double]

    static func make(_ file: PeopleFile, recording: Recording) -> VerticalGuideTrack {
        let width = VerticalCrop.width(sourceWidth: Double(file.frameWidth), sourceHeight: Double(file.frameHeight))
        let spots = Shorts.subject(file, faces: recording.faces, names: recording.resolvedNameTable, teacher: recording.names.teacher,
                                   choices: recording.choices)
        let count = max(1, Int((file.duration / step).rounded(.up)) + 1)
        let times = (0..<count).map { Double($0) * step }
        return VerticalGuideTrack(width: width, centers: VerticalCrop.follow(spots, times: times, width: width, step: step))
    }

    /// The window's middle at a moment of the original.
    func center(at time: Double) -> Double {
        guard !centers.isEmpty else { return 0.5 }
        let i = min(max(0, Int((time / Self.step).rounded())), centers.count - 1)
        return centers[i]
    }
}

/// The Vertical Guide over the picture (design spec 3.4.1): on the Original and the Video, everything outside the 9:16 window the
/// shorts would use is shaded, and the window has a thin white edge. Abstract shapes only (never skeuomorphic).
struct VerticalGuideOverlay: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        if viewer.showsVerticalGuide, viewer.rendition == .original || viewer.rendition == .video,
           let file = model.peopleBoxes.file(for: recording, folders: model.peopleFolders) {
            let track = viewer.guideTrack(file, recording: recording)
            GeometryReader { proxy in
                let size = viewer.rendition == .video ? viewer.videoSize : CGSize(width: file.frameWidth, height: file.frameHeight)
                let picture = PeopleOverlay.pictureRect(in: proxy.size, frame: size)
                if let center = viewer.guideCenter(track) {
                    let w = picture.width * track.width
                    let x = picture.minX + picture.width * min(max(center - track.width / 2, 0), 1 - track.width)
                    let window = CGRect(x: x, y: picture.minY, width: w, height: picture.height)
                    ZStack(alignment: .topLeading) {
                        Path { path in
                            path.addRect(picture)
                            path.addRect(window)
                        }
                        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: window.width, height: window.height)
                            .offset(x: window.minX, y: window.minY)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Vertical guide: the 9:16 window the shorts use, following the speaker.")
        }
    }
}
