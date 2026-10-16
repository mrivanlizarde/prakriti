import AppKit
import ImageIO
import SwiftUI

/// The thumbnails in the inspector's Outputs tab (v2 part M11b): the three options side by side, each with its headline, its
/// one-line reason and its checks, **Use This One** (the card shows the chosen one) and Show in Finder; Make Thumbnails for a
/// recording made without them. Refused in words only while the people check has not run.
struct ThumbnailsSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let record = model.thumbnailsRecord(recording)
        let chosen = recording.chosenThumbnail(record)
        let refusal = model.videoRefusal(recording)
        Section {
            if let record, let folder = model.thumbnailsFolder(recording), !record.candidates.isEmpty {
                Text("Three designed options for YouTube, each from a real frame of the teacher. The card shows the one chosen.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let behind = model.thumbnailsBehind(recording) { RowNote(behind) }
                ForEach(record.candidates, id: \.letter) { candidate in
                    row(candidate, folder: folder, chosen: chosen?.letter == candidate.letter)
                }
                RowNote("Headlines by \(record.headlinesBy). " + "\(Format.count(record.looked, "frame")) looked at" + (record.refused > 0 ? ", \(record.refused) refused by the face check." : "."))
            } else if let problem = model.thumbnailsProblems[recording.id] {
                Label {
                    Text("Not made on the last try. \(problem)").font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("Prakriti can design three YouTube thumbnails from the best frames of the teacher, with a headline of a few words, in Yoga Marga's colours. Faces of anyone you hid are never in them.")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let refusal, model.thumbnailsProblems[recording.id] == nil {
                RowNote(refusal.replacingOccurrences(of: "no video is made", with: "no thumbnails are made"))
            }
            Button(record == nil ? "Make Thumbnails" : "Make Thumbnails Again") { model.makeThumbnails(recording) }
                .disabled(!model.canMakeThumbnails(recording))
                .quickHelp("Plans the edit and designs three thumbnails, through the line like any make. Nothing is uploaded.", article: "outputs")
        } header: {
            SectionHeader("Thumbnails")
        }
    }

    private func row(_ candidate: VideoThumbnails.Candidate, folder: URL, chosen: Bool) -> some View {
        let url = folder.appending(path: candidate.fileName)
        return VStack(alignment: .leading, spacing: 6) {
            ThumbnailImage(url: url)
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    if chosen { RoundedRectangle(cornerRadius: 6).stroke(AppColor.accentText, lineWidth: 3) }
                }
                .accessibilityLabel("Thumbnail \(candidate.letter): \(candidate.headline)")
            Text("Thumbnail \(candidate.letter), \(candidate.composition.title)" + (chosen ? ", chosen" : ""))
                .font(AppFont.headline)
            Text("\u{201C}\(candidate.headline)\u{201D}. \(candidate.reason)")
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(candidate.failed == 0 ? "Every check passes: 1280 by 720, " + String(format: "%.2f MB", Double(candidate.bytes) / 1_000_000)
                 + String(format: ", words %.1f px tall at 168 wide, contrast %.1f to 1.", candidate.capAtSmallest, candidate.contrast)
                 : "\(Format.count(candidate.failed, "check")) failed.")
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Use This One") { model.chooseThumbnail(candidate.letter, for: recording) }
                    .disabled(chosen)
                Button("Show in Finder") { model.showThumbnailInFinder(url) }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A thumbnail file: 1280 by 720 and about 100 KB, read when the row is made (Outputs is never in the watched iCloud folder, so the
/// read is local and short; Mac warning 24 is about ~/Documents).
struct ThumbnailImage: View {
    let url: URL
    @State private var image: CGImage?

    init(url: URL) {
        self.url = url
        _image = State(initialValue: CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().interpolation(.high).scaledToFit()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
    }
}
