import Foundation
import SwiftData

// Recognition's actions (v2 part M7b, docs/v2/PLAN.md M7, research-people.md 2.2 to 2.4, 4.2 and 5.4): learning a person
// with a release, recognizing them in a recording after its people check, Review Possible Matches, Not [name], Merge 2
// People, and the face index rebuilt by Forget. Every change to the face index runs one at a time (`indexWork`), and the
// index is always rebuilt whole from the sealed crops, so it can never hold anything the vault does not.

/// Review Possible Matches for one person: the rows recognition asked about.
struct ReviewRequest: Identifiable, Equatable {
    let id = UUID()
    var personID: UUID
}

/// Merge 2 People: two people, and which name is kept.
struct MergeRequest: Identifiable, Equatable {
    let id = UUID()
    var first: UUID
    var second: UUID
}

/// One face row recognition asked about: "Is this Gabriel?"
struct PossibleMatch: Equatable, Identifiable, Sendable {
    var recordingID: UUID
    var filePath: String
    var sessionDate: Date
    var row: FacePerson
    var person: UUID
    var vote: RowVote

    var id: String { "\(recordingID.uuidString)-\(row.id)" }
}

/// Forget's proof for the face index (research-people.md 5.4): rebuilt from everyone else, and an old crop of the
/// forgotten person no longer matches anyone.
struct ForgetIndexProof: Equatable, Sendable {
    var rebuilt: FaceIndex.Summary
    /// Nil when the person had no crop to try.
    var oldCropMatched: Bool?

    var holds: Bool { oldCropMatched != true }

    var line: String {
        rebuilt.line + (oldCropMatched == nil ? " There was no crop of theirs to try."
                                               : (oldCropMatched! ? " One of their old crops STILL MATCHES a group." : " One of their old crops, tried after, matches no one."))
    }
}

extension AppModel {
    var faceIndex: FaceIndex { FaceIndex(vault: vault) }

    /// The people whose recorded release covers their face and who are not forgotten: the only people learned.
    func learningPeople() -> [Person] {
        namedPeopleList().filter { $0.hasRelease && $0.learnFace && $0.forgottenAt == nil }
    }

    /// How many face crops the vault keeps for a person (the person page's status line).
    func learnedCrops(_ person: Person) -> Int { faceIndex.crops(of: [person.id]).count }

    // MARK: The index, one change at a time

    /// Runs `body` after every earlier change to the index, so two rebuilds never overlap.
    func enqueueIndexWork(_ body: @escaping @MainActor () async -> Void) {
        let previous = indexWork
        indexWork = Task { @MainActor in
            _ = await previous?.result
            indexBusy = true
            await body()
            indexBusy = false
        }
    }

    /// Waits for every change to the index (the tests and the acceptance).
    func indexSettled() async {
        while let work = indexWork {
            _ = await work.result
            if indexWork == work { return }
        }
    }

    /// Rebuilds the index from the sealed crops of everyone learned (or removes it when nobody is). Call from inside
    /// `enqueueIndexWork`.
    @discardableResult
    func rebuildIndexNow(reason: String) async -> FaceIndex.Summary? {
        let index = faceIndex
        let learning = Set(learningPeople().map(\.id))
        do {
            let summary = try await Task.detached { try await index.rebuild(learning: learning) }.value
            lastIndexSummary = summary
            record("\(reason) " + summary.line)
            return summary
        } catch {
            record("\(reason) The face index could not be rebuilt: \(error.localizedDescription) Recognition is off until it is.", level: .attention)
            try? FileManager.default.removeItem(at: index.directory)
            return nil
        }
    }

    // MARK: Learning

    /// Learns a person's face from the rows Ivan named for them, then rebuilds the index. Only with a recorded release
    /// that covers their face. `only` limits it to one row of one recording (a Yes in Review).
    func learn(_ person: Person, only: (recording: UUID, row: Int)? = nil) {
        guard person.hasRelease, person.learnFace, person.forgottenAt == nil else { return }
        let id = person.id, name = person.name
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        let sources = Self.learningSources(of: id, in: recordings, only: only)
        var files: [UUID: PeopleFile] = [:]
        for recording in Set(sources.map(\.recording)) { files[recording] = peopleFolders.read(recording) }
        let index = faceIndex
        enqueueIndexWork { [weak self] in
            guard let self else { return }
            let kept = Set(index.origins(of: id).map(\.origin))
            let picks = Learning.picks(sources: sources, files: files, kept: kept)
            let vault = index.vault
            let sealed = await Task.detached { await Learning.seal(picks, person: id, vault: vault) }.value
            let total = index.crops(of: [id]).count
            if sealed == 0 && (index.exists || total == 0) {
                record("Learning \(name)'s face: nothing new to learn (\(Format.count(total, "crop")) kept, at most \(Learning.maximum)).")
                return
            }
            await rebuildIndexNow(reason: "Learned \(name)'s face from \(Format.count(sealed, "new crop")), \(total) kept in all, sealed under their own key.")
        }
    }

    /// The face rows a person is learned from: only rows Ivan named (by hand, as the teacher, a Yes in Review), never a
    /// row recognition named by itself, because learning from its own answers would let one mistake teach the next (PLAN
    /// risk R3). Never the faces seen for under a second (row 0).
    static func learningSources(of id: UUID, in recordings: [Recording], only: (recording: UUID, row: Int)? = nil) -> [Learning.Source] {
        var sources: [Learning.Source] = []
        for recording in recordings {
            var plain = recording.resolvedNames
            plain.recognition = nil
            let rows = plain.resolved(faces: recording.faces, voices: recording.voices).faces
            for (row, named) in rows.sorted(by: { $0.key < $1.key }) where named == id && row != 0 {
                if let only, only.recording != recording.id || only.row != row { continue }
                sources.append(Learning.Source(recording: recording.id, file: recording.filePath, row: row))
            }
        }
        return sources
    }

    // MARK: Recognizing a recording

    /// After a make or Check People: identifies the recording's face rows against the index and keeps one vote per row on
    /// the recording. Nothing is stored but the votes. Does nothing while nobody is learned.
    func recognize(_ recording: Recording) {
        let learning = Set(learningPeople().map(\.id))
        guard !learning.isEmpty, recording.faces?.hasPicture == true else { return }
        let id = recording.id
        let file = URL(fileURLWithPath: recording.filePath)
        guard FileManager.default.fileExists(atPath: file.path), !Readiness.isDataless(file) else { return }
        let voices = VoiceVote.perRow(names: recording.resolvedNames, faces: recording.faces, voices: recording.voices)
        let index = faceIndex
        let label = "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
        enqueueIndexWork { [weak self] in
            guard let self, index.exists else { return }
            do {
                let outcome = try await Task.detached {
                    try await RecognitionStep.run(file: file, recordingID: id, index: index, learning: learning, voices: voices)
                }.value
                guard let outcome, let current = fetchRecording(id) else { return }
                recognitionOutcomes[id] = outcome
                applyRecognition(outcome.votes, to: current)
                record("\(label): " + outcome.line + String(format: " (%.1f s)", outcome.seconds))
            } catch {
                record("\(label): recognition could not run. \(error.localizedDescription)", level: .attention)
            }
        }
    }

    /// Keeps the machine's votes on the recording (replacing the last ones; Ivan's own names and "Not" answers stay).
    func applyRecognition(_ votes: [Int: RowVote], to recording: Recording) {
        var names = recording.names
        names.recognition = votes.isEmpty ? nil : votes
        recording.names = names
        try? context.save()
        refreshCardPicture(recording)
    }

    // MARK: Review Possible Matches

    /// Every row recognition asked about for a person, recordings waiting for a yes first, then newest.
    func possibleMatches(for person: UUID) -> [PossibleMatch] {
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        var out: [(PossibleMatch, Bool)] = []
        for recording in recordings {
            let names = recording.resolvedNames
            let resolved = names.resolved(faces: recording.faces, voices: recording.voices)
            for (row, asked) in names.asks where asked == person && resolved.faces[row] == nil {
                guard let face = recording.faces?.people.first(where: { $0.id == row }), let vote = names.recognition?[row] else { continue }
                out.append((PossibleMatch(recordingID: recording.id, filePath: recording.filePath, sessionDate: recording.sessionDate,
                                          row: face, person: person, vote: vote), recording.status == .readyForYourYes))
            }
        }
        return out.sorted { a, b in
            if a.1 != b.1 { return a.1 }
            if a.0.vote.matched != b.0.vote.matched { return a.0.vote.matched < b.0.vote.matched }
            return a.0.sessionDate > b.0.sessionDate
        }.map(\.0)
    }

    func askToReview(_ person: Person) { reviewSheet = ReviewRequest(personID: person.id) }

    /// Review's Yes: the row is this person, named as if by hand, and (with a release that covers their face) learned.
    func confirmMatch(_ match: PossibleMatch) {
        guard let recording = fetchRecording(match.recordingID), let person = namedPeopleList().first(where: { $0.id == match.person }) else { return }
        var names = recording.names
        names.faces[match.row.id] = person.id
        recording.names = names
        try? context.save()
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): Review, \(match.row.label) is \(person.name).")
        refreshCardPicture(recording)
        learn(person, only: (recording.id, match.row.id))
    }

    /// Review's "Not [name]" and the People tab's Not This Person: the row is not this person. Any crops learned from it
    /// are deleted and the index rebuilt (research-people.md 2.4). Nothing about who it really is gets stored.
    func rejectMatch(row: Int, person personID: UUID, in recording: Recording) {
        var names = recording.names
        var not = names.notThem ?? [:]
        if !(not[row] ?? []).contains(personID) { not[row, default: []].append(personID) }
        names.notThem = not
        if names.faces[row] == personID { names.faces[row] = nil }
        recording.names = names
        try? context.save()
        let name = namedPeopleList().first { $0.id == personID }?.name ?? "that person"
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): a face is not \(name).")
        refreshCardPicture(recording)
        let index = faceIndex, recordingID = recording.id
        enqueueIndexWork { [weak self] in
            guard let self else { return }
            let deleted = Learning.deleteCrops(of: personID, recording: recordingID, row: row, index: index)
            if deleted > 0 { await rebuildIndexNow(reason: "Deleted \(Format.count(deleted, "crop")) of \(name) cut from a face that is not them.") }
        }
    }

    // MARK: Merge 2 People

    /// Why two people cannot be merged, or nil. Merge joins what Prakriti learned of both, so it needs a release for
    /// each (research-people.md 2.4, PLAN M7 check 1).
    static func mergeProblem(_ a: (name: String, hasRelease: Bool), _ b: (name: String, hasRelease: Bool)) -> String? {
        let missing = [a, b].filter { !$0.hasRelease }.map(\.name)
        guard !missing.isEmpty else { return nil }
        return missing.count == 2
            ? "Merge needs a recorded release for both people, and neither \(missing[0]) nor \(missing[1]) has one."
            : "Merge needs a recorded release for both people, and \(missing[0]) has none. Use Record Release on their page first."
    }

    func mergeProblem(_ a: Person, _ b: Person) -> String? {
        if a.id == b.id { return "Choose two different people." }
        return Self.mergeProblem((a.name, a.hasRelease), (b.name, b.hasRelease))
    }

    func askToMerge(_ a: Person, _ b: Person) { mergeSheet = MergeRequest(first: a.id, second: b.id) }

    /// Merge 2 People: `other` becomes `keep`. Their crops are opened under the other's key and sealed again under the
    /// kept person's; every recording's names and choices move over; the merged person takes the stricter of the two
    /// consents; the other's key is destroyed and their name removed; the index is rebuilt. Returns the problem, or nil.
    @discardableResult
    func merge(_ other: Person, into keep: Person) -> String? {
        if let problem = mergeProblem(keep, other) { return problem }
        let otherID = other.id, keepID = keep.id, otherName = other.name, keepName = keep.name
        // The stricter of the two consents (research-people.md 2.4).
        keep.learnFace = keep.learnFace && other.learnFace
        keep.learnVoice = keep.learnVoice && other.learnVoice
        keep.mayAppear = keep.mayAppear && other.mayAppear
        keep.mayReadInCloud = keep.mayReadInCloud && other.mayReadInCloud
        keep.noRelease = keep.noRelease || other.noRelease
        keep.favorite = keep.favorite || other.favorite
        keep.pinned = keep.pinned || other.pinned
        // What the vault keeps of the other person, sealed again under the kept person's key, when the merged release
        // still covers it.
        var moved = 0
        for kind in VaultKind.allCases where kind == .face ? keep.learnFace : keep.learnVoice {
            let files = (try? FileManager.default.contentsOfDirectory(at: vault.folder(kind, person: otherID), includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "sealed" {
                if let data = try? vault.open(file, person: otherID), (try? vault.seal(data, kind: kind, person: keepID)) != nil { moved += 1 }
            }
        }
        let proof = vault.forget(person: otherID)
        if !keep.learnFace { _ = try? FileManager.default.removeItem(at: vault.folder(.face, person: keepID)) }
        if !keep.learnVoice { _ = try? FileManager.default.removeItem(at: vault.folder(.voice, person: keepID)) }
        // Every recording: names, votes, "not" answers and choices move from the other person to the kept one.
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in recordings {
            var names = recording.names
            names = Self.renamed(names, from: otherID, to: keepID)
            if names != recording.names { recording.names = names }
            var choices = recording.choices
            if let theirs = choices.people.removeValue(forKey: PersonKey.named(otherID).string) {
                let key = PersonKey.named(keepID).string
                if let mine = choices.people[key] {
                    choices.people[key] = Self.stricter(mine, theirs)
                } else {
                    choices.people[key] = theirs
                }
                recording.choices = choices
            }
        }
        for source in (try? context.fetch(FetchDescriptor<Source>())) ?? [] where source.microphones.values.contains(otherID) {
            source.microphones = source.microphones.mapValues { $0 == otherID ? keepID : $0 }
        }
        if selection == .person(otherID) { selection = .person(keepID) }
        gallerySelection = []
        context.delete(other)
        try? context.save()
        record("Merged \(otherName) into \(keepName): \(Format.count(moved, "sealed file")) moved under \(keepName)'s key; \(otherName)'s key destroyed (" + proof.line + ")")
        for recording in recordings where recording.faces != nil { refreshCardPicture(recording) }
        enqueueIndexWork { [weak self] in
            await self?.rebuildIndexNow(reason: "Merged \(otherName) into \(keepName).")
        }
        return nil
    }

    /// The names of one recording with every mention of `from` changed to `to`.
    static func renamed(_ names: PeopleNames, from: UUID, to: UUID) -> PeopleNames {
        var out = names
        if out.teacher == from { out.teacher = to }
        out.faces = out.faces.mapValues { $0 == from ? to : $0 }
        out.voices = out.voices.mapValues { $0 == from ? to : $0 }
        out.recognition = out.recognition?.mapValues { vote in
            var vote = vote
            if vote.person == from { vote.person = to }
            return vote
        }
        out.notThem = out.notThem?.mapValues { list in
            var seen: [UUID] = []
            for id in list.map({ $0 == from ? to : $0 }) where !seen.contains(id) { seen.append(id) }
            return seen
        }
        return out
    }

    /// The stricter of two choices: Leave Out over Hide Face over Include, output by output.
    static func stricter(_ a: PeopleChoices.Decision, _ b: PeopleChoices.Decision) -> PeopleChoices.Decision {
        func rank(_ choice: PersonChoice) -> Int { choice == .leaveOut ? 2 : (choice == .hideFace ? 1 : 0) }
        var out = PeopleChoices.Decision(choice: rank(a.choice) >= rank(b.choice) ? a.choice : b.choice)
        for output in Set(a.outputs.keys).union(b.outputs.keys) {
            let first = a.outputs[output] ?? a.choice, second = b.outputs[output] ?? b.choice
            let choice = rank(first) >= rank(second) ? first : second
            if choice != out.choice { out.outputs[output] = choice }
        }
        return out
    }

    // MARK: Forget, for the index

    /// Forget's second half (research-people.md 5.4): the index purged and rebuilt from everyone else's crops, then one
    /// of the person's old crops (held in memory from before their key was destroyed) identified against it.
    func rebuildAfterForget(name: String, oldCrop: Data?) {
        let index = faceIndex
        enqueueIndexWork { [weak self] in
            guard let self else { return }
            let summary = await rebuildIndexNow(reason: "Forgot \(name): the face index is rebuilt without them.")
            let learning = Set(learningPeople().map(\.id))
            var matched: Bool?
            if let oldCrop {
                matched = (try? await Task.detached { try await index.matchesAnyone(oldCrop, learning: learning) }.value) ?? true
            }
            let proof = ForgetIndexProof(rebuilt: summary ?? FaceIndex.Summary(), oldCropMatched: matched)
            lastForgetIndexProof = proof
            record("Forgot \(name), the face index: " + proof.line, level: proof.holds && summary != nil ? .info : .attention)
        }
    }
}
