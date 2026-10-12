import AppKit
import Foundation
import SwiftData

/// The main window as Ivan left it (v2 part M3b, design spec 2.1 and 2.5), put back at the next launch:
/// the sidebar's group or folder, the recordings selected, the recording open in the Viewer with its
/// rendition and the moment playing (on the original's clock), the browser's grid or list, and the
/// inspector's tab. Kept in the mode's own preferences (`AppSettings.windowState`), never in the store, so
/// nothing migrates. Window captures and tests never read or write it: they use throwaway preferences.
struct WindowState: Codable, Equatable {
    var group: String?
    var source: UUID?
    var selected: [UUID] = []
    var open: UUID?
    var rendition: String?
    var original: Double?
    var browserMode: String?
    var inspectorTab: String?
    var inspectorShown: Bool?
}

// What the Viewer does (v2 part M3b): opening a recording in it, choosing what plays, Remove from the
// Edit and Keep in the Edit, Restore on a Timeline-lite span, and the typed cut in the inspector. Every
// change to the edit goes through v1's own paths (`addCut`, `setTrim`), so a change to an approved recording
// takes the approval back (START_HERE, Mac warning 38) and waits for Make Again (warning 36).
extension AppModel {
    // MARK: The Viewer

    /// Loads the open recording into the Viewer: its last moment if the window was restored, the moment a
    /// search result or Play asked for, else the start of the default rendition.
    func openViewer(_ recording: Recording) {
        var start: (rendition: Rendition?, original: Double?, play: Bool)?
        if let restored = restoredViewer, restored.recordingID == recording.id {
            restoredViewer = nil
            start = (restored.rendition, restored.original, false)
        }
        if let seek = pendingSeek, seek.recordingID == recording.id {
            pendingSeek = nil
            start = (seek.rendition, seek.time, seek.play)
        }
        viewer.load(recording, applyLexicon: wordListOn(recording), start: start)
    }

    /// The word list as this recording's transcript was made, for reading its words.
    func wordListOn(_ recording: Recording) -> Bool {
        OutputResolver.details(for: .transcript, recording: recording, defaults: defaultSettings())?.applyLexicon ?? true
    }

    /// The toolbar's rendition picker. One this build does not make, or this recording does not have, says
    /// why and stays where it was.
    func chooseRendition(_ rendition: Rendition) {
        guard let recording = focusedRecording else { return }
        if let reason = viewer.unavailableReason(rendition) {
            notice = Notice(title: "\(rendition.title) is not available", message: reason)
            return
        }
        viewer.choose(rendition, recording: recording)
        saveWindowState()
    }

    func setFollowPlayback(_ on: Bool) {
        viewer.followPlayback = on
        settings.followPlayback = on
    }

    func dismissViewerTip() {
        viewerTipSeen = true
        settings.viewerTipSeen = true
    }

    func setQuickHelp(_ on: Bool) {
        quickHelp.isOn = on
        settings.quickHelpOn = on
        if on { inspectorShown = true }
    }

    /// Edit > Find in Transcript (Command-F in the Viewer).
    func findInTranscript() {
        guard !path.isEmpty, !viewer.document.isEmpty else { return }
        viewerFindRequest += 1
    }

    // MARK: Cut and Keep

    /// The trim and cuts can be changed once something has been made (v1's rule for the page), and never
    /// while it waits its turn or is being made again.
    func canEditEpisode(_ recording: Recording) -> Bool {
        switch recording.status {
        case .readyForYourYes, .approved: true
        case .working, .found, .couldntFinish: recording.outputFolder != nil && !runner.isCurrent(recording)
        case .needsADecision, .skipped: false
        }
    }

    private func keptParts(_ recording: Recording) -> [Mastering.Span] {
        recording.duration.map { recording.edits.segments(duration: $0) } ?? [Mastering.Span(start: 0, end: .greatestFiniteMagnitude)]
    }

    func canRemoveSelectedWords(_ recording: Recording) -> Bool {
        guard canEditEpisode(recording), let chosen = viewer.selectedWords else { return false }
        let kept = keptParts(recording)
        return chosen.contains { viewer.document.words.indices.contains($0) && viewer.document.words[$0].isKept(in: kept) }
    }

    func canKeepSelectedWords(_ recording: Recording) -> Bool {
        guard canEditEpisode(recording), let chosen = viewer.selectedWords else { return false }
        let kept = keptParts(recording)
        return chosen.contains { viewer.document.words.indices.contains($0) && !viewer.document.words[$0].isKept(in: kept) }
    }

    /// Remove from the Edit: the selected words become a cut, on the original's clock, held clear of the
    /// words on each side (`TranscriptDocument.span(of:)`).
    @discardableResult
    func removeSelectedWords(from recording: Recording) -> String? {
        guard canRemoveSelectedWords(recording), let chosen = viewer.selectedWords, let span = viewer.document.span(of: chosen) else { return nil }
        if let problem = addCut(span, to: recording) {
            notice = Notice(title: "Not removed", message: problem)
            return problem
        }
        return nil
    }

    /// Keep in the Edit: the selected words come back from the cuts and the trim that took them.
    @discardableResult
    func keepSelectedWords(in recording: Recording) -> String? {
        guard canKeepSelectedWords(recording), let chosen = viewer.selectedWords, let span = viewer.document.span(of: chosen) else { return nil }
        if let problem = keep(span, in: recording) {
            notice = Notice(title: "Not kept", message: problem)
            return problem
        }
        return nil
    }

    /// Restore on a Timeline-lite span: the time the trim or a cut took out comes back.
    func restore(_ span: TimelineSpan, in recording: Recording) {
        guard span.isRemoved, canEditEpisode(recording) else { return }
        if let problem = keep(TimeRange(start: span.start, end: span.end), in: recording) {
            notice = Notice(title: "Not restored", message: problem)
            return
        }
        viewer.selectedSpan = nil
    }

    /// Brings a stretch of the original back into the episode: every cut loses what lies inside it, and the
    /// trim moves to take it in. Returns the problem, or nil.
    @discardableResult
    func keep(_ range: TimeRange, in recording: Recording) -> String? {
        guard range.end > range.start else { return nil }
        var edits = recording.edits
        let before = recording.edits
        if let start = edits.start, range.start < start { edits.start = range.start <= 0.001 ? nil : range.start }
        if let end = edits.end, range.end > end {
            edits.end = recording.duration.map { range.end >= $0 - 0.001 } == true ? nil : range.end
        }
        var cuts: [TimeRange] = []
        for cut in EpisodeEdits.merged(edits.cuts) {
            if cut.end <= range.start || cut.start >= range.end {
                cuts.append(cut)
                continue
            }
            if cut.start < range.start { cuts.append(TimeRange(start: cut.start, end: range.start)) }
            if cut.end > range.end { cuts.append(TimeRange(start: range.end, end: cut.end)) }
        }
        edits.cuts = cuts
        guard !edits.matches(before) else { return nil }
        if let duration = recording.duration {
            let silence: Mastering.Span? = recording.silenceTrimmedStart.map { Mastering.Span(start: $0, end: duration - (recording.silenceTrimmedEnd ?? 0)) }
            if let problem = edits.problem(duration: duration, silence: silence) { return problem }
        }
        recording.edits = edits
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): \(TimeText.string(range.start)) to \(TimeText.string(range.end)) kept in the episode again. Make Again to hear it.")
        changedAfterApproval(recording, what: "a cut")
        try? context.save()
        return nil
    }

    /// The inspector's Cut a Section row: two times typed as Ivan types them ("5:00", "5:30"). Returns the
    /// problem in one plain sentence, or nil once the cut is marked.
    @discardableResult
    func typedCut(from: String, to: String, for recording: Recording) -> String? {
        guard let start = TimeText.seconds(from), let end = TimeText.seconds(to) else {
            return "Write each time like 4:12 or 1:02:30."
        }
        return addCut(TimeRange(start: start, end: end), to: recording)
    }

    // MARK: State restoration

    /// Writes the window's state into the mode's preferences.
    func saveWindowState() {
        guard savesWindowState else { return }
        var state = WindowState()
        switch selection {
        case .group(let group): state.group = group.rawValue
        case .source(let id): state.source = id
        case nil: break
        }
        state.selected = Array(selectedRecordings).sorted { $0.uuidString < $1.uuidString }
        if let route = path.last, let open = context.model(for: route.id) as? Recording, !open.isDeleted {
            state.open = open.id
            if viewer.recordingID == open.id {
                state.rendition = viewer.rendition.rawValue
                state.original = viewer.hasPosition ? viewer.currentOriginal : nil
            }
        }
        state.browserMode = browserMode.rawValue
        state.inspectorTab = inspectorTab.rawValue
        state.inspectorShown = inspectorShown
        guard let data = try? JSONEncoder().encode(state), let text = String(data: data, encoding: .utf8), text != settings.windowState else { return }
        settings.windowState = text
    }

    /// Puts the window back as it was at the last quit. A recording or folder removed since is passed over.
    func restoreWindowState() {
        guard let text = settings.windowState, let data = text.data(using: .utf8),
              let state = try? JSONDecoder().decode(WindowState.self, from: data) else { return }
        savesWindowState = false
        defer { savesWindowState = true }
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        if let raw = state.group, let group = SmartGroup(rawValue: raw) {
            selection = .group(group)
        } else if let id = state.source, sources.contains(where: { $0.id == id }) {
            selection = .source(id)
        }
        selectedRecordings = Set(state.selected.filter { id in recordings.contains { $0.id == id } })
        if let mode = state.browserMode.flatMap(BrowserMode.init(rawValue:)) { browserMode = mode }
        if let tab = state.inspectorTab.flatMap(InspectorTab.init(rawValue:)) { inspectorTab = tab }
        if let shown = state.inspectorShown { inspectorShown = shown }
        if let id = state.open, let recording = recordings.first(where: { $0.id == id }) {
            restoredViewer = (id, state.rendition.flatMap(Rendition.init(rawValue:)), state.original)
            selectedRecordings = [id]
            path = [RecordingRoute(id: recording.persistentModelID)]
        }
        log.write("Window restored: \(state.group ?? (state.source == nil ? "no group" : "a folder")), \(state.selected.count) selected"
                  + (state.open == nil ? "." : ", a recording open in the Viewer (\(state.rendition ?? "default")" + (state.original.map { " at \(TimeText.string($0))" } ?? "") + ")."))
    }

    // MARK: Debug switches

    /// `--debug-playback-log` (Debug builds only, never the installed copy; START_HERE Mac warning 77): the
    /// Viewer's player writes its time and rate to the log once a second.
    func startDebugSwitches() {
        #if DEBUG
        guard DebugSwitches.isAllowed(), CommandLine.arguments.contains("--debug-playback-log") else { return }
        let log = log
        // Muted: a check that plays proves it from the log, and must not play a talk aloud on Ivan's Mac.
        viewer.player.isMuted = true
        viewer.startPlaybackLog { log.write($0) }
        log.write("Debug switch: the Viewer's player writes its time and rate here once a second.")
        #endif
    }
}
