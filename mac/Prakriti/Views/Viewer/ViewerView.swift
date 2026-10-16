import AVKit
import SwiftUI

/// The Viewer (v2 part M3b, docs/v2/design-spec.md 3.4, REQUEST item 10): opening a recording replaces the
/// browser with the system player on an always-dark canvas, the rendition chosen in the toolbar (Original,
/// Podcast, Podcast-ready), and under it the Timeline-lite and the transcript, with a divider between the
/// two that can be dragged. Its banner says, in one line, what stands between this recording and a yes.
/// Replaces v1's recording page, retired in this part; every function of the page now lives here or in the
/// inspector.
struct ViewerView: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        VStack(spacing: 0) {
            ViewerBanner(recording: recording)
            VSplitView {
                ViewerPicture(recording: recording)
                    .frame(minHeight: 220, idealHeight: 470, maxHeight: .infinity)
                ViewerLower(recording: recording)
                    .frame(minHeight: 260, idealHeight: 330, maxHeight: .infinity)
            }
        }
        .navigationTitle(Format.dayLabel(recording.sessionDate))
        .onAppear { model.openViewer(recording) }
        .onChange(of: recording.madeAt) { model.openViewer(recording) }
        .onChange(of: recording.podcastReady?.fileName) { model.openViewer(recording) }
        .onChange(of: recording.videoJSON) { model.openViewer(recording) }
        .onDisappear { viewer.close() }
    }
}

/// The rendition picker for the toolbar while a recording is open: Original, Podcast, Podcast-ready, Video (v2 part M8c) and
/// Shorts (v2 part M11a). One that is not made says why when chosen.
struct RenditionPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        Picker("Play", selection: Binding(get: { viewer.rendition }, set: { model.chooseRendition($0) })) {
            ForEach(Rendition.shown) { rendition in
                Text(rendition.title)
                    .tag(rendition)
                    .accessibilityLabel(viewer.unavailableReason(rendition).map { "\(rendition.title), not available. \($0)" } ?? rendition.title)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .quickHelp("Choose what plays: the Original as recorded, the Podcast episode, the Podcast-ready episode, the edited Video, or the Shorts.",
                   article: "reviewing-and-approving")
    }
}

/// Beside the picker while Shorts plays (design spec 3.4.1): which short, "Short 1 of 3" (v2 part M11a).
struct ShortPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        if viewer.rendition == .shorts, viewer.shorts.count > 1 {
            Picker("Short", selection: Binding(get: { viewer.shortIndex }, set: { model.chooseShort($0) })) {
                ForEach(viewer.shorts.indices, id: \.self) { index in
                    Text(viewer.shortLabel(index)).tag(index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .quickHelp("Chooses which short plays. Each is a complete moment, 1080 by 1920, with its words burned in.", article: "reviewing-and-approving")
        }
    }
}

/// One line under the toolbar when something stands in the way, with its action on the right.
struct ViewerBanner: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        if let banner {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: banner.symbol)
                    .font(AppFont.body)
                    .foregroundStyle(banner.symbol == "exclamationmark.circle" ? Color.orange : .secondary)
                    .accessibilityHidden(true)
                Text(banner.line)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 300, alignment: .leading)
                Spacer(minLength: 12)
                if let action = banner.action {
                    Button(action.title, action: action.run)
                }
                if banner.controls {
                    // Pause and Stop, as in the inspector (v2 part M4a).
                    let runner = model.runner
                    if runner.canResume(recording) {
                        Button("Resume") { runner.resume(recording) }
                    } else {
                        Button("Pause") { runner.pause(recording) }.disabled(!runner.canPause(recording))
                    }
                    Button("Stop") { runner.stop(recording) }.disabled(!runner.canStop(recording))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }
            .accessibilityElement(children: .combine)
        }
    }

    struct Action {
        let title: String
        let run: () -> Void
    }

    private var banner: (symbol: String, line: String, action: Action?, controls: Bool)? {
        if let base = baseBanner {
            return (base.symbol, base.line, base.action, model.runner.isCurrent(recording) || model.runner.isWaiting(recording))
        }
        return nil
    }

    private var baseBanner: (symbol: String, line: String, action: Action?)? {
        let viewer = model.viewer
        if model.runner.isWaiting(recording) {
            return ("hourglass", model.runner.isHeld(recording) ? "Paused in line. It keeps its place and starts once you resume it."
                    : model.settings.isPaused ? "Waiting to start. Pause All is on; it starts when you resume." : "Waiting to start. Another recording is being made first.", nil)
        }
        if let progress = model.runner.progress(for: recording) {
            // The inspector's progress on one line (design spec 3.6.1, v2 part M4a).
            let stage = String(ProgressWords.stage(progress).dropLast())
            let lead = progress.isPaused ? "Paused: " : "Working: "
            let waiting = progress.waitingOn.map { " " + $0 } ?? ""
            let line = lead + stage + ", " + ProgressWords.line(progress) + "." + waiting
            return (progress.isPaused ? "pause.circle" : "arrow.triangle.2.circlepath", line, nil)
        }
        switch recording.status {
        case .working:
            return ("arrow.triangle.2.circlepath", "Working: " + (recording.currentStep ?? "making the outputs") + ".", nil)
        case .needsADecision:
            return ("questionmark.circle", recording.statusReason ?? "This recording needs a decision.", nil)
        case .couldntFinish:
            return ("exclamationmark.triangle", "Couldn't finish. " + (recording.statusReason ?? "") + " The original is untouched.",
                    Action(title: "Try Again") { model.makeOutputs(recording) })
        case .found:
            return ("plus.circle", "Not made yet. The original plays here.", model.startTitle(recording).map { title in Action(title: title) { model.makeOutputs(recording) } })
        default:
            break
        }
        if viewer.rendition == .original || viewer.rendition == .video, let note = viewer.originalNote {
            return ("icloud.and.arrow.down", note, nil)
        }
        // The Video (v2 part M8c): a change made since the video was planned shows once it is made again.
        if viewer.rendition == .video, let behind = model.videoBehind(recording) {
            return ("exclamationmark.circle", behind,
                    model.canMakeAgain(recording) ? Action(title: "Make Again…") { model.ask(.makeAgain, for: recording) } : nil)
        }
        if recording.editsPending {
            return ("exclamationmark.circle", "Your newest trim and cuts are not in the episode yet. Make it again to hear them, and before approving.",
                    model.canMakeAgain(recording) ? Action(title: "Make Again…") { model.ask(.makeAgain, for: recording) } : nil)
        }
        if recording.choicesPending {
            return ("exclamationmark.circle", "Your newest choices of who is in the episode are not in it yet. Make it again to hear them, and before approving.",
                    model.canMakeAgain(recording) ? Action(title: "Make Again…") { model.ask(.makeAgain, for: recording) } : nil)
        }
        return nil
    }
}

/// The picture: the system player (`AVPlayerView`) on a canvas that is black in both appearances. For the
/// podcast renditions, which have no picture, the title and date sit above the player's controls.
struct ViewerPicture: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        ZStack {
            Color.black
            ViewerPlayerView(player: viewer.player, hasPicture: viewer.rendition.hasPicture)
                .accessibilityLabel(viewer.rendition.title + " player")
            // Who is where, over the Original (v2 part M6d): boxes and names, and the toggle that shows them.
            PeopleOverlay(recording: recording)
            // The 9:16 window the shorts use, over the Original and the Video (v2 part M11a).
            VerticalGuideOverlay(recording: recording)
            // The video's captions as they will be uploaded (v2 part M8c).
            CaptionsOverlay()
            ViewerPictureToggles(recording: recording)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            if !viewer.rendition.hasPicture {
                VStack(spacing: 8) {
                    Image(systemName: viewer.rendition.symbol)
                        .font(AppFont.welcomeSymbol)
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityHidden(true)
                    Text(recording.cardTitle)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(viewer.rendition.title + ". " + Format.dayAndTime(recording.sessionDate))
                        .font(AppFont.body)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 70)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .padding(.bottom, 80)
                .allowsHitTesting(false)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// AVKit's own player view: the only scrubber in Prakriti (START_HERE, Mac warning 43). Floating controls
/// over a picture; inline controls, always shown, for sound alone.
struct ViewerPlayerView: NSViewRepresentable {
    let player: AVPlayer
    let hasPicture: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let view = UnfocusedPlayerView()
        view.player = player
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = false
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.controlsStyle = hasPicture ? .floating : .inline
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
        let style: AVPlayerViewControlsStyle = hasPicture ? .floating : .inline
        if view.controlsStyle != style { view.controlsStyle = style }
    }
}

/// The system player, which never takes the keyboard focus: the Viewer keeps it, so Escape goes back to the
/// library and Space, J, K and L reach the Viewer (measured in `make look`, 12 Oct: with the player focused,
/// Escape after Return stayed in the Viewer). Its own buttons still take clicks.
final class UnfocusedPlayerView: AVPlayerView {
    override var acceptsFirstResponder: Bool { false }
}

/// Under the picture: the Timeline-lite, Follow Playback and what the edit keeps, the first-time tip, the
/// transcript, and the selected words' Remove and Keep.
struct ViewerLower: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                // Nothing is cut from a recording that makes nothing (silent, or a test clip): no map to show.
                if let duration = recording.duration, duration > 0, recording.status != .needsADecision, recording.status != .skipped {
                    ViewerTimeline(recording: recording, duration: duration)
                }
                HStack(spacing: 16) {
                    Toggle("Follow Playback", isOn: Binding(get: { viewer.followPlayback }, set: { model.setFollowPlayback($0) }))
                        .toggleStyle(.checkbox)
                        .font(AppFont.secondary)
                        .quickHelp("Keeps the sentence playing in view in the transcript, marked in the accent color.", article: "reviewing-and-approving")
                    Spacer(minLength: 12)
                    if let kept = keptLine {
                        Text(kept)
                            .font(AppFont.numbers)
                            .foregroundStyle(.appSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)
            if !model.viewerTipSeen && !viewer.document.isEmpty {
                ViewerTip { model.dismissViewerTip() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            Divider()
            if viewer.document.isEmpty {
                ScrollView {
                    EmptyState(symbol: "text.alignleft", title: "No transcript",
                               message: recording.wordCount == nil && recording.outputFolder == nil
                                ? "The transcript is made with the outputs. Once it is, it shows here, and a click on a word plays from it."
                                : recording.wordCount == nil ? "No transcript was made for this recording." : "The transcript's files are not in its folder any more.")
                }
            } else {
                ViewerTranscript(recording: recording)
                    .quickHelp("Click a word to play from it. Drag across words, or Shift-click, to select them, then Remove from the Edit or Keep in the Edit. Command-F finds a word.",
                               article: "reviewing-and-approving")
                if let chosen = viewer.selectedWords {
                    Divider()
                    ViewerSelectionBar(recording: recording, chosen: chosen)
                }
            }
        }
    }

    /// "Keeps 15:08 of 15:48": what the trim and cuts leave, as they stand now; on the Original with an edit plan, what
    /// the plan keeps (v2 part M8a).
    private var keptLine: String? {
        if model.viewer.rendition == .video, let plan = model.viewer.videoPlan {
            return "The video keeps \(Format.timecode(plan.keptSeconds)) of \(Format.timecode(plan.sourceDuration))"
        }
        if model.viewer.rendition == .original, let plan = model.editPlan(for: recording) {
            return "The plan keeps \(Format.timecode(plan.keptSeconds)) of \(Format.timecode(plan.sourceDuration))"
        }
        guard let duration = recording.duration, !recording.edits.isEmpty else { return nil }
        let kept = recording.edits.segments(duration: duration).reduce(0) { $0 + $1.length }
        return "Keeps \(Format.timecode(kept)) of \(Format.timecode(duration))"
    }
}

/// The Timeline-lite of this recording, its spans as the edits stand now.
struct ViewerTimeline: View {
    @Bindable var recording: Recording
    let duration: Double
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        TimelineLite(spans: ViewerTimeline.spans(recording, duration: duration, model: model), marks: ViewerTimeline.marks(recording, model: model),
                     duration: duration,
                     position: viewer.hasPosition ? viewer.currentOriginal : nil, selected: viewer.selectedSpan) { span in
            viewer.select(span)
            model.inspectorShown = true
        }
    }
}

extension ViewerTimeline {
    /// On the Video (v2 part M8c), the spans of the plan it was made from; on the Original with an edit plan (v2 part M8a),
    /// the plan's spans; otherwise the trim and cuts as they stand now.
    @MainActor
    static func spans(_ recording: Recording, duration: Double, model: AppModel) -> [TimelineSpan] {
        if model.viewer.rendition == .video, let plan = model.viewer.videoPlan { return TimelineSpan.spans(plan: plan) }
        if model.viewer.rendition == .original, let plan = model.editPlan(for: recording) { return TimelineSpan.spans(plan: plan) }
        return TimelineSpan.spans(edits: recording.edits, duration: duration)
    }

    /// The marks lane (v2 part M9d): what the plan on show adds, on the Video or the Original.
    @MainActor
    static func marks(_ recording: Recording, model: AppModel) -> [TimelineMark] {
        if model.viewer.rendition == .video, let plan = model.viewer.videoPlan { return TimelineMark.marks(plan: plan) }
        if model.viewer.rendition == .original, let plan = model.editPlan(for: recording) { return TimelineMark.marks(plan: plan) }
        return []
    }
}

/// The transcript, wired to the Viewer and the edit.
struct ViewerTranscript: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        let viewer = model.viewer
        // On the Video (v2 part M8c), the words the video keeps; every word it took out is struck through.
        let kept = viewer.rendition == .video && viewer.videoPlan != nil
            ? viewer.videoPlan!.mainSpans.map { Mastering.Span(start: $0.in, end: $0.out) }
            : recording.duration.map { recording.edits.segments(duration: $0) } ?? [Mastering.Span(start: 0, end: .greatestFiniteMagnitude)]
        TranscriptTextView(
            document: viewer.document, kept: kept, playing: viewer.currentSentence?.id, selected: viewer.selectedWords, follow: viewer.followPlayback,
            revealRequest: viewer.revealRequest, findRequest: model.viewerFindRequest,
            actions: .init(playWord: { viewer.play(word: $0) },
                           select: { viewer.selectedWords = $0 },
                           remove: { model.removeSelectedWords(from: recording) },
                           keep: { model.keepSelectedWords(in: recording) },
                           togglePlay: { viewer.togglePlay() },
                           shuttle: { viewer.shuttle($0) },
                           back: { model.back() },
                           canRemove: { model.canRemoveSelectedWords(recording) },
                           canKeep: { model.canKeepSelectedWords(recording) }))
    }
}

/// The words selected, their times, and what can be done with them.
struct ViewerSelectionBar: View {
    @Bindable var recording: Recording
    let chosen: ClosedRange<Int>
    @Environment(AppModel.self) private var model

    var body: some View {
        let document = model.viewer.document
        HStack(spacing: 12) {
            if let span = document.span(of: chosen) {
                Text("Selected: \(Format.count(chosen.count, "word")), \(TimeText.string(span.start)) to \(TimeText.string(span.end)).")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button("Remove from the Edit") { model.removeSelectedWords(from: recording) }
                .disabled(!model.canRemoveSelectedWords(recording))
                .quickHelp("Takes the selected words out of the episode the next time it is made. The original is never changed.", article: "reviewing-and-approving")
            Button("Keep in the Edit") { model.keepSelectedWords(in: recording) }
                .disabled(!model.canKeepSelectedWords(recording))
                .quickHelp("Brings selected words that a cut or the trim took out back into the episode, the next time it is made.", article: "reviewing-and-approving")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

/// The first-time tip under the Timeline-lite (design spec 5.5, tip 3), drawn as Prakriti's own row: TipKit's
/// `TipView` was not proved to draw at 12 pt or more on macOS (design spec 5.5 note), so it is not used.
struct ViewerTip: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "lightbulb")
                .font(AppFont.body)
                .foregroundStyle(AppColor.accentText)
                .accessibilityHidden(true)
            Text("Click a word to play from it. Select words to take them out or keep them.")
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 300, alignment: .leading)
            Spacer(minLength: 12)
            Button("Got It", action: dismiss)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
        .accessibilityElement(children: .combine)
    }
}

/// Above the inspector's tabs (design spec 3.5.0): the Timeline-lite span chosen, with its one action (v2 part M8c): Restore
/// for time the plan, the trim or a cut takes out, Remove for time it keeps, and the opposite once changed, until Make Again.
struct SelectedSpanStrip: View {
    let span: TimelineSpan
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let edit = model.spanEdit(span, in: recording)
        VStack(alignment: .leading, spacing: 8) {
            Label {
                // At most four lines: a plan's sentence is longer than a cut's, and a strip that grows without a limit asked
                // the window for 1,620 pt in the snapshots (v2 part M8a).
                // Once changed, the state takes the line's place, so the strip never grows (a second line made the window ask
                // for 1,006 pt in the 23-viewer-video-restored snapshot, 14 Oct).
                Text(Self.stateLine(edit, span: span) ?? span.line).font(AppFont.body).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: span.symbol).font(AppFont.body)
            }
            HStack(spacing: 10) {
                if let title = Self.actionTitle(edit) {
                    Button(title) { model.applySpanEdit(span, in: recording, undo: undoManager) }
                        .quickHelp(Self.actionHelp(edit), article: "reviewing-and-approving")
                }
                Spacer()
                Button("Done") { model.viewer.selectedSpan = nil }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .accessibilityElement(children: .contain)
    }

    static func actionTitle(_ edit: SpanEdit) -> String? {
        switch edit {
        case .restore: "Restore"
        case .restored: "Take Out Again"
        case .remove: "Remove"
        case .removed: "Keep"
        case .restoredTrim, .person, .direction, .none: nil
        }
    }

    static func actionHelp(_ edit: SpanEdit) -> String {
        switch edit {
        case .restore: "Brings this stretch back as recorded, the next time it is made. Command-Z undoes it."
        case .restored: "Lets the plan take this stretch out again, the next time it is made."
        case .remove: "Takes this stretch out of the video and the episode, the next time they are made. Delete does the same."
        case .removed: "Keeps this stretch in the video and the episode after all."
        case .restoredTrim, .person, .direction, .none: ""
        }
    }

    /// What the span's state is, when there is more to say than its own line.
    static func stateLine(_ edit: SpanEdit, span: TimelineSpan) -> String? {
        switch edit {
        case .restored: "Restored, \(TimeText.string(span.start)) to \(TimeText.string(span.end)). Not in the video yet: Make Again to see it."
        case .removed: "Removed, \(TimeText.string(span.start)) to \(TimeText.string(span.end)). Not in the video yet: Make Again to see it."
        case .restoredTrim: "Your trim was moved. Not in the video yet: Make Again to see it."
        case .person: "Someone you chose to leave out. To bring them back, change their choice in the People tab."
        case .direction: "A part your direction leaves out. To bring it back, change the direction, then Plan Again."
        case .restore, .remove, .none: nil
        }
    }
}
