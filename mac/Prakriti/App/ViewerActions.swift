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
    /// The People gallery ("people"), the unnamed people's recordings ("unnamed"), or one person's page (v2 part M7a).
    var people: String?
    var person: UUID?
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
        if let index = pendingShortIndex {
            pendingShortIndex = nil
            viewer.chooseShort(index)
        }
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

    /// The Viewer's People toggle and View > People (v2 part M6d).
    func setShowsPeople(_ on: Bool) {
        viewer.showsPeople = on
    }

    /// The Viewer's Captions toggle and View > Captions (v2 part M8c).
    func setShowsCaptions(_ on: Bool) {
        viewer.showsCaptions = on
    }

    /// The Viewer's Vertical Guide toggle and View > Vertical Guide (v2 part M11a).
    func setShowsVerticalGuide(_ on: Bool) {
        viewer.showsVerticalGuide = on
    }

    /// The pop-up beside the picker while Shorts plays (v2 part M11a).
    func chooseShort(_ index: Int) {
        viewer.chooseShort(index)
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
        case .readyForYourYes, .approved, .approvedCheckFailed: true
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
        let before = EditSnapshot(recording)
        if let problem = addCut(span, to: recording) {
            notice = Notice(title: "Not removed", message: problem)
            return problem
        }
        // Undoable (design spec 6.7, v2 part M8c).
        registerEditUndo(editUndoManager, recording: recording, before: before, name: "Remove from the Edit")
        return nil
    }

    /// Keep in the Edit: the selected words come back from the cuts and the trim that took them.
    @discardableResult
    func keepSelectedWords(in recording: Recording) -> String? {
        guard canKeepSelectedWords(recording), let chosen = viewer.selectedWords, let span = viewer.document.span(of: chosen) else { return nil }
        let before = EditSnapshot(recording)
        if let problem = keep(span, in: recording) {
            notice = Notice(title: "Not kept", message: problem)
            return problem
        }
        registerEditUndo(editUndoManager, recording: recording, before: before, name: "Keep in the Edit")
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
        case .people: state.people = "people"
        case .unnamed: state.people = "unnamed"
        case .person(let id): state.person = id
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
        } else if let id = state.person, namedPeopleList().contains(where: { $0.id == id }) {
            selection = .person(id)
        } else if state.people == "people" {
            selection = .people
        } else if state.people == "unnamed" {
            selection = .unnamed
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
        // `--debug-status-log` (v2 part M4a): every change of the menu bar's status line goes to the log.
        if DebugSwitches.isAllowed(), CommandLine.arguments.contains("--debug-status-log") {
            debugStatusLog = true
            log.write("Debug switch: every change of the menu bar's status line is written here.")
            noteStatusLine()
        }
        guard DebugSwitches.isAllowed(), CommandLine.arguments.contains("--debug-playback-log") else { return }
        let log = log
        // Muted: a check that plays proves it from the log, and must not play a talk aloud on Ivan's Mac.
        viewer.player.isMuted = true
        viewer.startPlaybackLog { log.write($0) }
        log.write("Debug switch: the Viewer's player writes its time and rate here once a second.")
        #endif
    }
}

// MARK: The Viewer's keys

/// Space, J, K, L and Escape in the Viewer (design spec 2.5 and 6.7), taken from the app's own event stream
/// rather than from SwiftUI's focus. Reason (START_HERE, Mac warning 99): with `.onKeyPress` on a `.focused`
/// view, Space did nothing in 4 of 5 launches that put the Viewer back from the last session
/// (12 Oct, measured from the playback log: every line at rate 0.00 with the window key and frontmost),
/// because the focus set in `onAppear` was not taken when the window was restored. A key reaches the Viewer
/// now whatever holds the focus, except a field being typed in, the transcript (it handles the same keys
/// itself), and a control Ivan reached with Full Keyboard Access (Space presses it).
enum ViewerKeys {
    enum Action: Equatable { case togglePlay, shuttle(Character), back, delete }

    /// What a key does in the Viewer, or nil when it belongs to something else.
    static func action(characters: String, modifiers: NSEvent.ModifierFlags, viewerOpen: Bool,
                       responderIsText: Bool, responderIsKeyboardControl: Bool) -> Action? {
        guard viewerOpen, !responderIsText, !responderIsKeyboardControl else { return nil }
        guard modifiers.intersection([.command, .control, .option]).isEmpty else { return nil }
        if characters == "\u{1b}" { return .back }
        // Delete and Forward Delete (design spec 6.7, v2 part M8c): the chosen span or words out of the edit.
        if characters == "\u{7f}" || characters == "\u{f728}" { return .delete }
        if characters == " " { return .togglePlay }
        if characters.count == 1, let key = characters.first, "jklJKL".contains(key) { return .shuttle(key) }
        return nil
    }

    @MainActor private static var monitor: Any?

    /// Installed once, at launch.
    @MainActor static func install(_ model: AppModel) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model] event in
            let characters = event.charactersIgnoringModifiers ?? ""
            let modifiers = event.modifierFlags
            let window = event.window
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let model else { return false }
                let main = NSApp.windows.first { $0.identifier?.rawValue.hasPrefix(MainWindow.id) == true }
                guard let main, window === main, main.isKeyWindow, main.attachedSheet == nil else { return false }
                let responder = main.firstResponder
                let keyboardControl = NSApp.isFullKeyboardAccessEnabled && responder is NSControl
                guard let action = action(characters: characters, modifiers: modifiers, viewerOpen: !model.path.isEmpty,
                                          responderIsText: responder is NSText, responderIsKeyboardControl: keyboardControl) else {
                    if !model.path.isEmpty, action(characters: characters, modifiers: modifiers, viewerOpen: true, responderIsText: false,
                                                   responderIsKeyboardControl: false) != nil {
                        model.viewer.playbackLog?("Playback: key left to \(responder.map { String(describing: type(of: $0)) } ?? "nothing")")
                    }
                    return false
                }
                switch action {
                case .togglePlay: model.viewer.togglePlay()
                case .shuttle(let key): model.viewer.shuttle(key)
                case .back: model.back()
                case .delete: model.deleteInViewer()
                }
                let name = action == .togglePlay ? "Space" : action == .back ? "Escape" : action == .delete ? "Delete" : "J, K or L"
                model.viewer.playbackLog?(String(format: "Playback: key %@ in the Viewer, rate now %.2f", name, model.viewer.player.rate))
                return true
            }
            return handled ? nil : event
        }
    }
}
