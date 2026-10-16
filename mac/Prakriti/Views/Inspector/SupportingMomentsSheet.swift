import AVFoundation
import AVKit
import SwiftUI

/// Find Supporting Moments (v2 part M12a, design spec 3.8, about 720 by 600 pt): what the moments should support, then up to three
/// moments from other recordings of the same teacher, each with its source and date, its exact words in quotes with their length,
/// one plain sentence saying why, and where it would go; Play plays it in the sheet's own player, Not This One sets it aside. The empty
/// state gives the real count searched. Add (v2 part M12b) keeps the moment with the recording, by Ivan's click only; it goes into
/// the video at the next Make Again. The footer's switch (design spec C6) says whether a moment added from here shows its date on screen.
struct SupportingMomentsSheet: View {
    let request: MomentsRequest
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var player = MomentPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(header)
                    .font(AppFont.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    model.openHelp(article: "editorial-direction")
                } label: {
                    Image(systemName: "questionmark.circle").font(AppFont.body)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Help: Editorial direction")
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 8)
            if player.playing != nil {
                MomentPlayerView(player: player.player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            Divider()
            HStack(spacing: 10) {
                @Bindable var model = model
                Toggle("Clips from another day show their date on screen.", isOn: $model.momentsShowDate)
                    .toggleStyle(.switch)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .quickHelp("A moment you add shows the day it was recorded, small in the top corner, for its first 3 seconds.", article: "editorial-direction")
                Spacer()
                Button("Done") {
                    player.stop()
                    model.closeMoments()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .font(AppFont.body)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 720)
        .frame(minHeight: 600)
        .onDisappear { player.stop() }
    }

    private var header: String {
        if case .found(let search) = model.momentsState { return search.header }
        return request.selection == nil ? "Moments that support this recording's main points" : "Moments that support the words you chose"
    }

    @ViewBuilder private var content: some View {
        switch model.momentsState {
        case .searching(let line):
            searching(line)
        case nil:
            searching("Looking for moments.")
        case .refused(let reason):
            Label {
                Text(reason).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle").font(AppFont.body)
            }
            .accessibilityElement(children: .combine)
        case .found(let search):
            let shown = search.moments.filter { !model.dismissedMoments.contains($0.id) }
            if shown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(search.moments.isEmpty ? search.emptyLine : "You set aside every moment found. Prakriti searched \(Format.count(search.searched, "recording")) of \(search.teacherName).")
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if search.notSearched > 0 {
                        RowNote("\(Format.count(search.notSearched, "more recording")) of \(search.teacherName) \(search.notSearched == 1 ? "was" : "were") not searched: Prakriti has not checked who appears and speaks in \(search.notSearched == 1 ? "it" : "them").")
                    }
                }
            } else {
                let recording = model.recording(id: request.recordingID)
                ForEach(shown) { moment in
                    MomentRow(moment: moment, playing: player.playing == moment.id, added: recording.map { model.isAdded(moment, to: $0) } ?? false,
                              play: { player.play(moment) }, stop: { player.stop() }, setAside: { model.dismissMoment(moment) },
                              add: { if let recording { model.addMoment(moment, to: recording) } })
                    Divider()
                }
                Text("Found among \(Format.count(search.searched, "recording")) of \(search.teacherName) by meaning on this Mac; each read by \(search.by). A moment you add goes into the video at the next Make Again.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func searching(_ line: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(line)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One moment: its source and date, its words in quotes with their length, why, where it would go, Play, Add and Not This One.
struct MomentRow: View {
    let moment: SupportingMoment
    let playing: Bool
    var added = false
    let play: () -> Void
    let stop: () -> Void
    let setAside: () -> Void
    var add: () -> Void = {}
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                if let source = model.recording(id: moment.sourceID), let image = model.cardPictures.image(for: source) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(width: 96, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.sourceLabel).font(AppFont.headline)
                    Text("At \(Format.timecode(moment.window.start)) in that recording, \(Format.timecode(moment.seconds)) long.")
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                }
            }
            Text("\u{201C}" + moment.words + "\u{201D}")
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Label {
                Text(moment.why).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "text.bubble").font(AppFont.body)
            }
            Label {
                Text("Where it would go: after \u{201C}...\(moment.afterWords)\u{201D} at \(Format.timecode(moment.after)).")
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "arrow.turn.down.right").font(AppFont.body)
            }
            HStack(spacing: 10) {
                if playing {
                    Button("Stop") { stop() }
                } else {
                    Button("Play") { play() }
                        .disabled(!FileManager.default.fileExists(atPath: moment.filePath))
                }
                if added {
                    Label("Added", systemImage: "checkmark.circle")
                        .font(AppFont.body)
                        .foregroundStyle(.appSecondary)
                        .accessibilityLabel("Added. It goes into the video at the next Make Again.")
                } else {
                    Button("Add") { add() }
                        .quickHelp("Adds this moment to the video at the next Make Again, after the sentence shown above.", article: "editorial-direction")
                    Button("Not This One") { setAside() }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The sheet's own player: the moment's stretch of its original, from its first word to its last, then it stops.
@MainActor @Observable
final class MomentPlayer {
    let player = AVPlayer()
    private(set) var playing: String?
    @ObservationIgnored private var observer: Any?

    func play(_ moment: SupportingMoment) {
        stop()
        let item = AVPlayerItem(url: URL(fileURLWithPath: moment.filePath))
        player.replaceCurrentItem(with: item)
        playing = moment.id
        let end = CMTime(seconds: moment.window.end + 0.2, preferredTimescale: 600)
        observer = player.addBoundaryTimeObserver(forTimes: [NSValue(time: end)], queue: .main) { [weak self] in
            MainActor.assumeIsolated { self?.player.pause() }
        }
        player.seek(to: CMTime(seconds: max(0, moment.window.start - 0.1), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in self?.player.play() }
        }
    }

    func stop() {
        player.pause()
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
        player.replaceCurrentItem(with: nil)
        playing = nil
    }
}

/// The system player in the sheet (Mac warning 43: AVKit's own, never a drawn scrubber).
struct MomentPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = UnfocusedPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}
