import Foundation
import SwiftData

// Choices applied to audio (v2 part M6c, docs/v2/PLAN.md M6): Ivan's Include, Hide Face or Leave Out for each person,
// Set All Unnamed To, Keep or Mute for each name said aloud, and that he listened to the changes of voice. Each is kept
// on the recording (`Recording.choicesJSON`), never changes a file by itself, and marks the episode "not in it yet"
// until Make Again (Mac warning 36's rule), so a yes always covers exactly what was made. A change to an approved
// recording takes the approval back (warning 38).

extension Recording {
    /// The names the People tab shows: a named face or voice takes its person's name.
    var resolvedNameTable: (faces: [Int: UUID], voices: [Int: UUID]) {
        resolvedNames.resolved(faces: faces, voices: voices)
    }

    /// How the People tab and Approve speak of a voice: its person's name, else its face's label, else "Voice 2".
    func label(forVoice id: Int) -> String {
        let table = resolvedNameTable
        let people = namedPeople
        if let person = table.voices[id], let name = people.first(where: { $0.id == person })?.name { return name }
        if let voice = voices?.voices.first(where: { $0.id == id }) {
            if let face = voice.face, let row = faces?.people.first(where: { $0.id == face }) { return row.label }
            return voice.label
        }
        return "Voice \(id)"
    }

    /// How the People tab and the receipt speak of a person key.
    func label(for key: PersonKey) -> String {
        switch key {
        case .named(let id): namedPeople.first { $0.id == id }?.name ?? "Someone no longer named"
        case .face(let row): row == 0 ? "Faces seen for under a second" : (faces?.people.first { $0.id == row }?.label ?? "Unnamed \(row)")
        case .voice(let id): label(forVoice: id)
        }
    }

    /// Every person in the recording as a choice is kept: named people once, then each unnamed face row and each
    /// unnamed voice with no face.
    var personKeys: [PersonKey] {
        let table = resolvedNameTable
        var keys: [PersonKey] = []
        for row in faces?.people ?? [] where !keys.contains(PersonKey.face(row.id, names: table)) { keys.append(PersonKey.face(row.id, names: table)) }
        for voice in voices?.voices ?? [] where !keys.contains(PersonKey.voice(voice, names: table)) { keys.append(PersonKey.voice(voice, names: table)) }
        return keys
    }

    /// The keys with no name, for Set All Unnamed To.
    var unnamedKeys: [PersonKey] { personKeys.filter { !$0.isNamed } }

    /// The voices that belong to a person key.
    func voiceIDs(for key: PersonKey) -> [Int] {
        let table = resolvedNameTable
        return (voices?.voices ?? []).filter { PersonKey.voice($0, names: table) == key }.map(\.id)
    }


    /// The voices were told apart on one mixed track and someone is left out: Ivan listens to the changes of voice
    /// before Approve (Mac warning 14, research-people.md 3.4: a voice wrongly taken for a stranger would silently
    /// remove the teacher's words, or keep someone left out).
    var needsListening: Bool {
        guard let voices, voices.source == .diarizer, !voices.listen.isEmpty, choices.leavesSomeoneOut,
              !choices.leftOutVoices(voices, names: resolvedNameTable).isEmpty else { return false }
        return choices.listenedFor.map { abs($0.timeIntervalSince(voices.checkedAt)) > 1 } ?? true
    }

    /// One line per person for the receipt and the Outputs tab: "Gabriel: included. Unnamed 2: left out."
    var choiceLines: [String] {
        let choices = self.choices
        return personKeys.map { key in
            let choice = choices.choice(key, for: .podcast)
            let hasFace: Bool = switch key {
            case .face: true
            case .named: true
            case .voice: false
            }
            let words = choice == .hideFace && hasFace ? "in the podcast as recorded, face hidden in the recording's picture" : choice.meaning
            return "\(label(for: key)): \(words)."
        }
    }
}

extension AppModel {
    /// A person's choice, for every output or one. Returns the choices before, for Undo.
    @discardableResult
    func setChoice(_ choice: PersonChoice, for key: PersonKey, output: ChoiceOutput? = nil, in recording: Recording) -> PeopleChoices {
        let before = recording.choices
        var choices = before
        choices.set(choice, for: key, output: output)
        guard choices != before else { return before }
        recording.choices = choices
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): a person is now \(choice.title)"
               + (output.map { " in the \($0.title.lowercased())" } ?? "") + ". Make it again to put it in the episode.")
        changedAfterApproval(recording, what: "who is in it")
        try? context.save()
        refreshCardPicture(recording)
        return before
    }

    /// Set All Unnamed To: one choice for every unnamed face and voice at once. Returns the choices before, for Undo.
    @discardableResult
    func setAllUnnamed(_ choice: PersonChoice, in recording: Recording) -> PeopleChoices {
        let before = recording.choices
        var choices = before
        // The faces seen for under a second go with everyone not named (v2 part M6d): their pictures are hidden too.
        let glimpses = (recording.faces?.glimpses ?? 0) > 0 ? [PersonKey.face(0, names: recording.resolvedNameTable)] : []
        choices.setAll(choice, unnamed: recording.unnamedKeys + glimpses)
        guard choices != before else { return before }
        recording.choices = choices
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): everyone not named is now \(choice.title). Make it again to put it in the episode.")
        changedAfterApproval(recording, what: "who is in it")
        try? context.save()
        refreshCardPicture(recording)
        return before
    }

    /// Keep or Mute for every time one name is said. Returns the choices before, for Undo.
    @discardableResult
    func decideName(_ decision: NameDecision, moments: [NameMoment], in recording: Recording) -> PeopleChoices {
        let before = recording.choices
        var choices = before
        for moment in moments { choices.names[moment.key] = decision }
        guard choices != before else { return before }
        recording.choices = choices
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): \(Format.count(moments.count, "name")) said aloud set to \(decision.title)."
               + (decision == .mute ? " Make it again to mute \(moments.count == 1 ? "it" : "them") in the episode." : ""))
        if decision == .mute || before.names.values.contains(.mute) { changedAfterApproval(recording, what: "a name said aloud") }
        try? context.save()
        return before
    }

    /// Puts back the choices from before a change (Undo and Redo).
    func restoreChoices(_ choices: PeopleChoices, in recording: Recording) {
        guard recording.choices != choices else { return }
        recording.choices = choices
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): a choice of who is in it was undone.")
        changedAfterApproval(recording, what: "who is in it")
        try? context.save()
        refreshCardPicture(recording)
    }

    /// Ivan listened to the changes of voice, for the voices as last checked.
    func setListened(_ listened: Bool, in recording: Recording) {
        var choices = recording.choices
        choices.listenedFor = listened ? recording.voices?.checkedAt : nil
        recording.choices = choices
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): the changes of voice are " + (listened ? "marked as listened to." : "no longer marked as listened to."))
        try? context.save()
    }

    /// Plays the recording's original in the Viewer from `time` (Play Their Moments, a name said aloud, a stretch to
    /// listen to).
    func play(_ recording: Recording, at time: Double) {
        if path.last?.id == recording.persistentModelID, viewer.recordingID == recording.id {
            if viewer.rendition != .original { viewer.choose(.original, recording: recording) }
            viewer.seek(original: max(0, time - 1), play: true)
            return
        }
        pendingSeek = PendingSeek(recordingID: recording.id, time: max(0, time - 1), play: true, rendition: .original)
        open(recording)
    }
}

/// What the People tab needs to say what a choice takes out ("Leaving out Voice 2 takes 22 s out of the podcast."):
/// the voice stretches from the people file and the word times from the recording's transcript.json, read once per
/// make and held in memory. Times only.
@MainActor
final class ChoiceFigures {
    private var cache: [UUID: (stamp: String, segments: [VoiceSegment], words: [TimeRange]?)] = [:]

    func figures(for recording: Recording, folders: PeopleFolders) -> (segments: [VoiceSegment], words: [TimeRange]?) {
        let stamp = "\(recording.voices?.checkedAt.timeIntervalSince1970 ?? 0)-\(recording.madeAt?.timeIntervalSince1970 ?? 0)"
        if let hit = cache[recording.id], hit.stamp == stamp { return (hit.segments, hit.words) }
        let segments = folders.read(recording.id)?.voices?.voiceSegments ?? []
        var words: [TimeRange]?
        if let folder = recording.outputFolder,
           let data = try? Data(contentsOf: URL(fileURLWithPath: folder).appending(path: TranscriptFiles.asHeard)),
           let sentences = EpisodeTranscript.sentences(json: data) {
            words = EpisodeTranscript.wordSpans(sentences)
        }
        cache[recording.id] = (stamp, segments, words)
        return (segments, words)
    }

    /// Sample data's figures (the snapshots), held as if read from a people file: nothing is written anywhere.
    func seed(_ recording: Recording, segments: [VoiceSegment], words: [TimeRange]?) {
        let stamp = "\(recording.voices?.checkedAt.timeIntervalSince1970 ?? 0)-\(recording.madeAt?.timeIntervalSince1970 ?? 0)"
        cache[recording.id] = (stamp, segments, words)
    }

    /// Seconds leaving these voices out takes out of the podcast, as the make would cut them.
    func removed(voices ids: [Int], in recording: Recording, folders: PeopleFolders) -> Double {
        guard !ids.isEmpty else { return 0 }
        let figures = figures(for: recording, folders: folders)
        return LeaveOut.plan(segments: figures.segments, leftOut: Set(ids), words: figures.words, duration: recording.duration ?? .infinity).removedSeconds
    }

    /// The stretches a person's voices speak, in order, for Play Their Moments.
    func moments(voices ids: [Int], in recording: Recording, folders: PeopleFolders) -> [Double] {
        EpisodeEdits.merged(figures(for: recording, folders: folders).segments.filter { ids.contains($0.voice) }
            .map { TimeRange(start: $0.start, end: $0.end) }).map(\.start)
    }
}
