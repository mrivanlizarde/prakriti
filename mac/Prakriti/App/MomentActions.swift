import Foundation
import SwiftData

// Find Supporting Moments in the app (v2 part M12a, docs/v2/PLAN.md M12, design spec 3.8): from the Direction tab (this recording's
// main points), from the transcript's selected words (Find Supporting Moments for This...) and from the Recording menu. It opens the
// sheet at once and searches in the background: the index on this Mac is brought up to date (`MomentFinder.update`), the windows
// above the threshold are read by the model chosen for "Choosing moments" under the privacy lock, and up to three moments are shown.
// Searches run one at a time (`momentWork`). Adding one is by hand only (v2 part M12b, `addMoment`): Add in the sheet keeps it with the
// recording's direction, and it goes into the video at the next Make Again, read again from its own recording then (`momentInserts`).

/// The sheet's request: one recording, and the words chosen in its transcript when it came from them.
struct MomentsRequest: Identifiable, Equatable {
    let id = UUID()
    let recordingID: UUID
    /// The times of the words selected, on the original's clock, or nil for this recording's main points.
    var selection: TimeRange?
}

/// What the sheet shows while it is open.
enum MomentsState: Equatable {
    case searching(String)
    case found(MomentSearch)
    case refused(String)
}

extension AppModel {
    /// The index file of this mode.
    var momentIndexURL: URL { MomentIndex.url(support: paths.applicationSupport) }

    /// Find Supporting Moments can be asked for: the transcript is made.
    func canFindSupportingMoments(_ recording: Recording) -> Bool {
        recording.outputFolder != nil && recording.madeFiles.contains(TranscriptFiles.asHeard)
    }

    /// Opens the sheet and starts the search. `selection` is the selected words' times (Find Supporting Moments for This...).
    func findSupportingMoments(_ recording: Recording, selection: TimeRange? = nil) {
        guard canFindSupportingMoments(recording) else {
            notice = Notice(title: "No moments to look for yet", message: "Moments are found from a recording's transcript, and this one has none yet.")
            return
        }
        let request = MomentsRequest(recordingID: recording.id, selection: selection)
        momentsSheet = request
        dismissedMoments = []
        momentsShowDate = true
        momentsState = .searching("Looking for moments.")
        let previous = momentWork
        momentWork = Task { @MainActor [weak self] in
            await previous?.value
            guard let self, self.momentsSheet?.id == request.id else { return }
            let state = await self.searchMoments(request)
            if self.momentsSheet?.id == request.id { self.momentsState = state }
        }
    }

    /// Find Supporting Moments for This... in the transcript: the selected words' times.
    func findSupportingMomentsForSelection(in recording: Recording) {
        guard let chosen = viewer.selectedWords, let span = viewer.document.span(of: chosen) else { return }
        findSupportingMoments(recording, selection: span)
    }

    /// Not This One: the moment leaves the sheet (for this search only).
    func dismissMoment(_ moment: SupportingMoment) {
        dismissedMoments.insert(moment.id)
    }

    /// The sheet is closed: nothing is kept.
    func closeMoments() {
        momentsSheet = nil
        momentsState = nil
        dismissedMoments = []
    }

    /// The teacher of a recording, by name, or nil.
    func teacherName(of recording: Recording) -> String? {
        guard let id = recording.names.teacher else { return nil }
        return (try? context.fetch(FetchDescriptor<Person>()))?.first { $0.id == id }?.name
    }

    /// "Sun 6 Sep 2026, Talk with Gabriel".
    static func momentSourceLabel(date: Date, kind: RecordingKind, teacher: String?) -> String {
        let first = teacher?.split(separator: " ").first.map(String.init)
        let what: String = switch kind {
        case .talk: "Talk"
        case .lesson: "Class"
        case .conversation: "Conversation"
        case .test, .unknown: "Recording"
        }
        return Format.fullDay(date) + ", " + (first.map { "\(what) with \($0)" } ?? what)
    }

    /// One recording as the search reads it, or nil when it has no transcript to read.
    func momentSource(_ recording: Recording) -> MomentSource? {
        guard let folder = recording.outputFolder, recording.madeFiles.contains(TranscriptFiles.asHeard),
              let data = try? Data(contentsOf: URL(fileURLWithPath: folder, isDirectory: true).appending(path: TranscriptFiles.asHeard)),
              let words = PlanWords.from(json: data) else { return nil }
        let names = recording.resolvedNames
        let resolved = names.resolved(faces: recording.faces, voices: recording.voices)
        let people = MomentPeople.from(file: peopleFolders.read(recording.id), voices: recording.voices, names: resolved, choices: recording.choices,
                                       people: recording.namedPeople)
        return MomentSource(id: recording.id, label: Self.momentSourceLabel(date: recording.sessionDate, kind: recording.kind, teacher: teacherName(of: recording)),
                            date: recording.sessionDate, teacher: names.teacher, words: words.words, transcriptSHA256: words.transcriptSHA256, people: people,
                            facts: recording.peopleFacts, filePath: recording.filePath)
    }

    /// The search behind the sheet. Returns what the sheet shows.
    func searchMoments(_ request: MomentsRequest) async -> MomentsState {
        guard let recording = recording(id: request.recordingID) else { return .refused("This recording is not in the library any more.") }
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        guard let current = momentSource(recording) else { return .refused("This recording's transcript could not be read.") }
        guard let teacherID = current.teacher, let teacher = teacherName(of: recording) else {
            return .refused("Prakriti looks for moments only in other recordings of the same teacher, and nobody is chosen as teaching this one. Choose who is teaching in Info first.")
        }
        // What to support.
        let points: [MomentPoint]
        let header: String
        if let selection = request.selection {
            guard let point = MomentFinder.point(selectedFrom: selection.start, to: selection.end, words: current.words) else {
                return .refused("No words of the transcript are inside the selection.")
            }
            points = [point]
            let shown = point.text.split(separator: " ")
            header = "Moments that support \u{201C}" + shown.prefix(14).joined(separator: " ") + (shown.count > 14 ? "..." : "") + "\u{201D}"
        } else {
            let folder = URL(fileURLWithPath: recording.outputFolder ?? "", isDirectory: true)
            guard let beats = BeatsFile.cached(in: folder, transcriptSHA256: current.transcriptSHA256) else {
                return .refused("Prakriti finds this recording's main points in its parts of the talk, and they have not been read yet. Plan the edit in Direction first, or select words in the transcript and choose Find Supporting Moments for This.")
            }
            points = MomentFinder.points(beats: beats.beats, words: current.words)
            header = "Moments that support this recording's main points"
        }
        // Where to look: every other recording of the same teacher; those whose people were not checked are counted, not read.
        let all = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        let sameTeacher = all.filter { $0.id != recording.id && $0.names.teacher == teacherID && canFindSupportingMoments($0) }
        var others: [MomentSource] = []
        var notSearched = 0
        for other in sameTeacher {
            if let source = momentSource(other), source.people.checked { others.append(source) } else { notSearched += 1 }
        }
        // The model, under the lock for each pair (the request carries words of both recordings).
        let setup = runner.writingSetup()
        let embedder: LocalEmbeddings
        do {
            embedder = try LocalEmbeddings(address: settings.lmStudioAddress)
        } catch {
            return .refused((error as? EmbeddingFailure)?.reason ?? error.localizedDescription)
        }
        let index: MomentIndex
        do {
            index = try MomentIndex(url: momentIndexURL)
        } catch {
            return .refused((error as? MomentIndex.Failure)?.reason ?? error.localizedDescription)
        }
        let counter = momentRequests
        let judge = MomentJudge(setup: setup, log: log, current: LockSubject(people: current.facts),
                                sources: Dictionary(others.map { ($0.id, LockSubject(people: $0.facts)) }, uniquingKeysWith: { a, _ in a }),
                                fileName: recording.fileName, onRequest: { provider in counter.count(provider) })
        record("\(label): looking for supporting moments in \(Format.count(others.count, "other recording")) of \(teacher)"
               + (notSearched > 0 ? " (\(notSearched) more not searched: people not checked)." : "."))
        let now = self.now()
        do {
            let search = try await MomentFinder.find(current: current, points: points, header: header, others: others, notSearched: notSearched,
                                                     teacherName: teacher, index: index, embedder: embedder, judge: judge, now: now,
                                                     progress: { line in Task { @MainActor [weak self] in
                                                         if case .searching = self?.momentsState { self?.momentsState = .searching(line) }
                                                     } })
            await judge.release()
            record("\(label): \(Format.count(search.moments.count, "supporting moment")) found in \(Format.count(search.searched, "recording")) of \(teacher) ("
                   + "\(Format.count(search.windows, "window")) read on this Mac, \(Format.count(search.candidates, "candidate")) above the threshold, "
                   + "\(search.judged) read by \(search.by), \(search.declined) not supporting, \(search.copyRules) left out by your copy rules), " + String(format: "%.0f s.", search.seconds))
            lastMomentSearch = search
            return .found(search)
        } catch {
            await judge.release()
            let reason = (error as? MomentFinder.Refusal)?.reason ?? (error as? MomentJudge.Failure)?.reason ?? (error as? EmbeddingFailure)?.reason
                ?? (error as? MomentIndex.Failure)?.reason ?? (error as? ModelFailure)?.reason ?? error.localizedDescription
            record("\(label): supporting moments were not found. \(reason)", level: .attention)
            return .refused(reason)
        }
    }

    // MARK: Added by hand (v2 part M12b)

    /// Whether this moment is already in the recording.
    func isAdded(_ moment: SupportingMoment, to recording: Recording) -> Bool {
        recording.direction.moments.contains { $0.sourceID == moment.sourceID && $0.window == moment.window }
    }

    /// Add: Ivan's click, and the only way a moment joins a recording. Nothing is planned or made until Make Again.
    func addMoment(_ moment: SupportingMoment, to recording: Recording) {
        guard !isAdded(moment, to: recording) else { return }
        var direction = recording.direction
        direction.moments.append(AddedMoment.added(byIvan: moment, showDate: momentsShowDate, at: now()))
        recording.direction = direction
        recording.updatedAt = now()
        try? context.save()
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): you added a moment from \(Format.dayLabel(moment.sourceDate)) "
               + "(\(Format.length(moment.seconds))) after \(Format.timecode(moment.after)). It goes into the video at the next Make Again.")
    }

    /// Remove beside an added moment.
    func removeMoment(_ id: String, from recording: Recording) {
        var direction = recording.direction
        guard let moment = direction.moments.first(where: { $0.id == id }) else { return }
        direction.moments.removeAll { $0.id == id }
        recording.direction = direction
        recording.updatedAt = now()
        try? context.save()
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): you removed the moment from \(Format.dayLabel(moment.sourceDate)). "
               + "It leaves the video at the next Make Again.")
    }

    /// The date on screen for one added moment (design spec C6, switchable per clip).
    func setMomentShowsDate(_ id: String, _ show: Bool, in recording: Recording) {
        var direction = recording.direction
        guard let i = direction.moments.firstIndex(where: { $0.id == id }), direction.moments[i].showDate != show else { return }
        direction.moments[i].showDate = show
        recording.direction = direction
        recording.updatedAt = now()
        try? context.save()
    }

    /// The moments of a recording as a make reads them, each from its own recording as it is NOW: its original, transcript, frame rate,
    /// and its people and Ivan's choices of this moment (PLAN M12, "Re-checked at every render").
    func momentInserts(for recording: Recording) -> [MomentInsert] {
        recording.direction.moments.map { moment in
            var insert = MomentInsert(moment: moment, name: "", people: MomentPeople(checked: false))
            guard let other = self.recording(id: moment.sourceID) else {
                insert.unreadable = "its recording is not in the library any more"
                return insert
            }
            insert.name = URL(fileURLWithPath: other.filePath).deletingPathExtension().lastPathComponent
            insert.original = URL(fileURLWithPath: other.filePath)
            insert.duration = other.duration
            if !FileManager.default.fileExists(atPath: other.filePath) {
                insert.unreadable = "its original is not where it was found"
            }
            if let source = momentSource(other) {
                insert.words = PlanWords(words: source.words, transcriptSHA256: source.transcriptSHA256, sentences: Set(source.words.map(\.sentence)).count)
                insert.people = source.people
            } else if insert.unreadable == nil {
                insert.unreadable = "its transcript could not be read"
            }
            // The same frame rate as this recording, or the moment's frames would be counted wrong.
            if let mine = recording.capture?.video?.frameRate, let theirs = other.capture?.video?.frameRate, abs(mine - theirs) > 0.01, insert.unreadable == nil {
                insert.unreadable = "it was recorded at another frame rate"
            }
            // A name said aloud that Ivan muted in that recording stays muted: a moment holding one is not used.
            let muted = other.choices.muted(other.namesSaid?.moments ?? [])
            if muted.contains(where: { $0.end > moment.window.start && $0.start < moment.window.end }), insert.unreadable == nil {
                insert.unreadable = "a name said aloud in it is muted"
            }
            return insert
        }
    }

    /// Takes a recording out of the moments index (Remove from Library).
    func forgetMoments(of recordingID: UUID) {
        guard FileManager.default.fileExists(atPath: momentIndexURL.path), let index = try? MomentIndex(url: momentIndexURL) else { return }
        try? index.remove(recordingID)
    }
}

/// Counts the requests of the moment search by provider, for the log and the acceptance (PLAN M12 check 4).
final class MomentRequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [ModelProvider: Int] = [:]

    func count(_ provider: ModelProvider) {
        lock.lock()
        counts[provider, default: 0] += 1
        lock.unlock()
    }

    var local: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.filter { $0.key.isLocal }.values.reduce(0, +)
    }

    var cloud: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.filter { !$0.key.isLocal }.values.reduce(0, +)
    }

    func reset() {
        lock.lock()
        counts = [:]
        lock.unlock()
    }
}
