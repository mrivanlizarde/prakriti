import AppKit
import Foundation
import SwiftData

/// A question the main window asks before acting (v2 part M3a): Make Again, Approve and Remove from
/// Library each ask once, wherever they are chosen (the inspector, a card's menu, the Recording menu).
struct Confirmation: Identifiable, Equatable {
    enum Action: Equatable { case makeAgain, approve, removeFromLibrary }
    let id = UUID()
    let action: Action
    let recordingID: UUID
}

/// Where the Viewer should start when a recording opens: a "Said" search result's sentence, or the
/// inspector's Play.
struct PendingSeek: Equatable {
    let recordingID: UUID
    let time: Double
    /// Play from there at once (the Files list's Play), or wait at that moment (a search result).
    var play = false
    /// What plays: the inspector's Play asks for the Podcast; nil keeps the Viewer's own choice.
    var rendition: Rendition?
}

/// A window a launch flag or a Show Me link asked for before any view could open it.
enum PendingWindow: Equatable { case settings, activity }

// What the library does (v2 part M3a): moving between places, opening a recording and coming back,
// and the actions of a card's menu. Each action that changes something leaves one line in Activity.
extension AppModel {
    // MARK: Places

    /// Opens a place: a group or a folder in the main window, a Settings pane, or the Activity window.
    /// A window asked for before any view can open it (a launch flag) opens with the main window.
    func go(to place: HelpPlace) {
        switch place {
        case .group(let group):
            selection = .group(group)
        case .sources:
            let sources = (try? context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
            if let first = sources.first { selection = .source(first.id) }
        case .settings(let pane):
            settingsPane = pane
            if openSettingsWindow != nil { showSettings(pane) } else { pendingWindow = .settings }
        case .activity:
            if openActivityWindow != nil { showActivity() } else { pendingWindow = .activity }
        case .people:
            selection = .people
        case .person:
            let first = Gallery.ordered(galleryEntries(), sort: gallerySort).first
            selection = first.map { .person($0.id) } ?? .people
        }
    }

    /// Opens a window that was asked for before the main window was up. Called once the main window has
    /// handed over SwiftUI's open actions.
    func openPendingWindow() {
        guard let pending = pendingWindow else { return }
        pendingWindow = nil
        switch pending {
        case .settings: showSettings(settingsPane)
        case .activity: showActivity()
        }
    }

    // MARK: Selection

    func recording(id: UUID) -> Recording? {
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        return all.first { $0.id == id }
    }

    /// The one recording the inspector and the Recording menu act on: the open one, else the only one
    /// selected in the browser.
    var focusedRecording: Recording? {
        if let route = path.last, let open = context.model(for: route.id) as? Recording, !open.isDeleted { return open }
        guard selectedRecordings.count == 1, let id = selectedRecordings.first else { return nil }
        return recording(id: id)
    }

    /// The selected folder, when the sidebar has one.
    var selectedSource: Source? {
        guard case .source(let id) = selection else { return nil }
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        return sources.first { $0.id == id }
    }

    /// Open (Return, Command-Down, a double-click): the selected recording, in the Viewer.
    func openSelected() {
        guard path.isEmpty, selectedRecordings.count == 1, let id = selectedRecordings.first, let recording = recording(id: id) else { return }
        open(recording)
    }

    /// Back (Escape, Command-Up, Command-[, the toolbar's chevron): the browser, with the recording still
    /// selected.
    func back() {
        guard !path.isEmpty else { return }
        path = []
    }

    /// A "Said" search result: opens the recording in the Viewer at that sentence.
    func open(_ recording: Recording, at time: Double) {
        pendingSeek = PendingSeek(recordingID: recording.id, time: time)
        open(recording)
    }

    // MARK: A card's menu

    /// Make Again is offered for a finished recording that is not waiting or being made (v1's rule).
    func canMakeAgain(_ recording: Recording) -> Bool {
        (recording.status == .readyForYourYes || recording.status.isApproved) && !runner.isWaiting(recording) && !runner.isCurrent(recording)
    }

    /// Make Outputs (a recording found and not made) or Try Again (one that could not finish).
    func startTitle(_ recording: Recording) -> String? {
        guard !runner.isWaiting(recording), !runner.isCurrent(recording) else { return nil }
        switch recording.status {
        case .found: return "Make Outputs"
        case .couldntFinish: return "Try Again"
        default: return nil
        }
    }

    func ask(_ action: Confirmation.Action, for recording: Recording) {
        // Approve is a sheet of deliverables since v2 part M11b (design spec 3.11), never a one-line question.
        if action == .approve { askToApprove(recording); return }
        confirmation = Confirmation(action: action, recordingID: recording.id)
    }

    /// The answer Yes to a confirmation.
    func confirm(_ confirmation: Confirmation) {
        self.confirmation = nil
        guard let recording = recording(id: confirmation.recordingID) else { return }
        switch confirmation.action {
        case .makeAgain: makeOutputs(recording)
        case .approve: approve(recording)
        case .removeFromLibrary: removeFromLibrary(recording)
        }
    }

    func showOriginalInFinder(_ recording: Recording) {
        // The Finder reads the folder, not Prakriti: nothing on the main thread touches a path inside
        // ~/Documents (START_HERE, Mac warning 24).
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: recording.filePath)])
    }

    func showOutputsInFinder(_ recording: Recording) {
        guard let folder = recording.outputFolder else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder, isDirectory: true)])
    }

    /// Whether Remove from Library can be offered: never while the recording is being made or waits its turn.
    func canRemoveFromLibrary(_ recording: Recording) -> Bool {
        recording.status != .working && !runner.isCurrent(recording) && !runner.isWaiting(recording)
    }

    /// Remove from Library (design spec 3.1.1): Prakriti forgets the recording, its files in Outputs go
    /// to the Trash, and the original and anything in Approved are never touched. Its folder remembers
    /// the file, so the next look does not find it as new and make it again; adding it by hand brings
    /// it back. Refused while it is being made or waits its turn.
    @discardableResult
    func removeFromLibrary(_ recording: Recording) -> Bool {
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        guard canRemoveFromLibrary(recording) else {
            let reason = "It is being made or waits its turn. Remove it once it has finished."
            record("Did not remove \(label) from the library. \(reason)", level: .attention)
            notice = Notice(title: "Not removed", message: reason)
            return false
        }
        var trashed = false
        if let folder = recording.outputFolder, FileManager.default.fileExists(atPath: folder) {
            let url = URL(fileURLWithPath: folder, isDirectory: true).standardizedFileURL
            // Only this mode's own Outputs folder ever loses anything, and only to the Trash.
            guard url.path.hasPrefix(paths.outputs.standardizedFileURL.path + "/") else {
                record("Did not remove \(label): its files are not in \(paths.display(paths.outputs.path)), so nothing was moved.", level: .problem)
                notice = Notice(title: "Not removed", message: "Its files are not in Prakriti's Outputs folder, so nothing was moved.")
                return false
            }
            do {
                try moveToTrash(url)
                trashed = true
            } catch {
                record("Did not remove \(label): its files could not be moved to the Trash (\(error.localizedDescription)).", level: .problem)
                notice = Notice(title: "Not removed", message: "Its files in Outputs could not be moved to the Trash. Nothing was changed.")
                return false
            }
        }
        if let source = recording.source, !source.forgottenPaths.contains(recording.filePath) {
            source.forgottenPaths.append(recording.filePath)
        }
        let sourceName = recording.source?.name
        // Its people file goes with it (research-people.md 5.4): what Prakriti knew of the faces in it.
        peopleFolders.removePeopleFile(for: recording.id)
        // And its card picture (v2 part M6d), the only picture Prakriti keeps of it.
        cardPictureWork[recording.id]?.cancel()
        cardPictureWork[recording.id] = nil
        peopleFolders.removeThumbnail(for: recording.id)
        cardPictures.changed(recording.id)
        selectedRecordings.remove(recording.id)
        if let route = path.last, route.id == recording.persistentModelID { path = [] }
        context.delete(recording)
        record("Removed \(label) from the library. "
               + (trashed ? "Its files in Outputs went to the Trash. " : "")
               + "The original and anything in Approved were not touched."
               + (sourceName.map { " It is not found again in \($0); add it by hand to bring it back." } ?? ""))
        try? context.save()
        return true
    }
}
