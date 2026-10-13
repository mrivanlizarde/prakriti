import Foundation

// Naming without prints (v2 part M6b, docs/v2/PLAN.md M6): Ivan says who is who in one recording, and nothing about
// a face or a voice is stored for it. Two ways:
//
// - **Who is teaching** (the Info tab): one pick per recording, from the people named in Settings, Privacy. It names
//   the voice that speaks the most and the face linked to it (or, with no link, the face on screen the most).
// - **Name for This Recording** (the People tab): any row, face or voice, given a name by hand.
//
// A name given to a face reaches the voice linked to it, and the other way round. What the privacy lock reads comes
// from here (`PeopleFacts.from`): the people check counts as run only when both the face step and the voice step
// ran (plan review item 5), and every face row or voice without a name is someone unnamed, which keeps the
// recording on this Mac. Names are not biometric; they are kept on the recording in the store (`Recording.namesJSON`).

/// Who Ivan named in one recording: the teacher he picked, and any face row or voice he named by hand.
struct PeopleNames: Codable, Equatable, Sendable {
    /// Who is teaching (the Info tab), a `Person` id.
    var teacher: UUID?
    /// A face row (`FacePerson.id`) named by hand. Row 0 stands for the faces seen for under a second (no row).
    var faces: [Int: UUID] = [:]
    /// A voice (`FoundVoice.id`) named by hand.
    var voices: [Int: UUID] = [:]

    static let none = PeopleNames()

    var isEmpty: Bool { teacher == nil && faces.isEmpty && voices.isEmpty }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func decode(_ json: String?) -> PeopleNames {
        guard let json, let data = json.data(using: .utf8) else { return .none }
        return (try? JSONDecoder().decode(PeopleNames.self, from: data)) ?? .none
    }

    /// The name each face row and each voice carries once the teacher, the hand-given names and the links are all
    /// applied. A hand-given name always wins; the teacher takes the voice that speaks the most and its face; a name
    /// crosses a link to a face or voice that has none.
    func resolved(faces found: FacesFound?, voices heard: VoicesFound?) -> (faces: [Int: UUID], voices: [Int: UUID]) {
        var faceNames = faces
        var voiceNames = voices
        let rows = Set((found?.people ?? []).map(\.id) + ((found?.glimpses ?? 0) > 0 ? [0] : []))
        faceNames = faceNames.filter { rows.contains($0.key) }
        let ids = Set((heard?.voices ?? []).map(\.id))
        voiceNames = voiceNames.filter { ids.contains($0.key) }
        if let teacher {
            let main = heard?.voices.first
            if let main, voiceNames[main.id] == nil { voiceNames[main.id] = teacher }
            // The teacher's face: the one linked to the voice that speaks the most; with no link, the face on screen
            // the most, unless another voice is linked to it. Only when that voice is the teacher's (or none is heard).
            let linkedFaces = Set((heard?.voices ?? []).compactMap(\.face))
            let face = main?.face ?? found?.people.first.map(\.id).flatMap { linkedFaces.contains($0) ? nil : $0 }
            if let face, faceNames[face] == nil, main == nil || voiceNames[main!.id] == teacher { faceNames[face] = teacher }
        }
        for voice in heard?.voices ?? [] {
            guard let face = voice.face else { continue }
            if let name = voiceNames[voice.id], faceNames[face] == nil { faceNames[face] = name }
            if let name = faceNames[face], voiceNames[voice.id] == nil { voiceNames[voice.id] = name }
        }
        return (faceNames, voiceNames)
    }
}

/// A named person as the pipeline and the lock read them: no store object crosses into a make.
struct NamedPerson: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var cloudConsent: Bool
}

extension PeopleFacts {
    /// What the lock reads, from both steps and Ivan's names. Not checked unless both the face step and the voice step
    /// ran. Every face row and voice without a name counts as someone unnamed; so do faces seen for under a second,
    /// unless Ivan named them.
    static func from(faces: FacesFound?, voices: VoicesFound?, names: PeopleNames, people: [NamedPerson]) -> PeopleFacts {
        guard let faces, let voices else { return .notChecked }
        let resolved = names.resolved(faces: faces, voices: voices)
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var facts = PeopleFacts(checked: true)
        var order: [UUID] = []
        var seen: Set<UUID> = [], heard: Set<UUID> = []
        for row in faces.people.map(\.id) + (faces.glimpses > 0 ? [0] : []) {
            if let id = resolved.faces[row] {
                seen.insert(id)
                if !order.contains(id) { order.append(id) }
            } else {
                facts.unnamedSeen += row == 0 ? faces.glimpses : 1
            }
        }
        for voice in voices.voices {
            if let id = resolved.voices[voice.id] {
                heard.insert(id)
                if !order.contains(id) { order.append(id) }
            } else {
                facts.unnamedHeard += 1
            }
        }
        for id in order {
            // A name whose person was deleted from Settings is nobody named: counted as unnamed, and never consenting.
            guard let person = byID[id] else {
                if seen.contains(id) { facts.unnamedSeen += 1 }
                if heard.contains(id) { facts.unnamedHeard += 1 }
                continue
            }
            facts.named.append(.init(personID: id, name: person.name, heard: heard.contains(id), seen: seen.contains(id),
                                     cloudConsent: person.cloudConsent))
        }
        return facts
    }
}

/// The People tab's and the cards' words once voices are known (design spec 3.1.1 and 3.5.2). Never a bare number.
enum PeopleWords {
    /// "Gabriel speaks for 92 percent." for each named voice, the most first, then the others.
    static func summary(faces: FacesFound?, voices: VoicesFound, names: PeopleNames, people: [NamedPerson]) -> String {
        let resolved = names.resolved(faces: faces, voices: voices)
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard voices.speech > 0 else { return "No one speaks in this recording." }
        var sentences: [String] = []
        var named: [UUID: Double] = [:]
        var unnamed: [FoundVoice] = []
        for voice in voices.voices {
            if let id = resolved.voices[voice.id], byID[id] != nil { named[id, default: 0] += voice.speaking } else { unnamed.append(voice) }
        }
        for (id, seconds) in named.sorted(by: { $0.value > $1.value }) {
            let percent = Int((seconds / voices.speech * 100).rounded())
            sentences.append("\(byID[id]!.name) speaks for \(min(100, percent)) percent.")
        }
        if !unnamed.isEmpty {
            if named.isEmpty {
                sentences.append(unnamed.count == 1 ? "One voice speaks, not named yet." : "\(VoicesFound.word(unnamed.count).capitalizedFirst) voices speak, none named yet.")
            } else {
                sentences.append(unnamed.count == 1 ? "One other voice, not named." : "\(VoicesFound.word(unnamed.count).capitalizedFirst) other voices, not named.")
            }
        }
        let unnamedFaces = (faces?.people ?? []).filter { resolved.faces[$0.id] == nil }.count
        if unnamedFaces > 0 {
            sentences.append(unnamedFaces == 1 ? "One face is not named." : "\(VoicesFound.word(unnamedFaces).capitalizedFirst) faces are not named.")
        }
        return sentences.joined(separator: " ")
    }

    /// The card's people line (design spec 3.1.1: "Gabriel. Up to 2 other people at once. 1 other voice.").
    static func line(faces: FacesFound?, voices: VoicesFound?, names: PeopleNames, people: [NamedPerson]) -> String? {
        guard let voices else { return faces?.line }
        let resolved = names.resolved(faces: faces, voices: voices)
        let byID = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var parts: [String] = []
        var namedIDs: [UUID] = []
        for id in voices.voices.compactMap({ resolved.voices[$0.id] }) + (faces?.people ?? []).compactMap({ resolved.faces[$0.id] })
        where byID[id] != nil && !namedIDs.contains(id) { namedIDs.append(id) }
        parts += namedIDs.compactMap { byID[$0].map { "\($0.name)." } }
        if let faces, faces.mostAtOnce >= 2 {
            parts.append(namedIDs.isEmpty ? "Other people appear, up to \(faces.mostAtOnce) at once." : "Up to \(faces.mostAtOnce) people at once.")
        } else if namedIDs.isEmpty, let faces, faces.hasPicture {
            parts.append(faces.line)
        }
        let otherVoices = voices.voices.filter { resolved.voices[$0.id].flatMap { byID[$0] } == nil }.count
        if otherVoices > 0 {
            parts.append(namedIDs.isEmpty ? (otherVoices == 1 ? "One voice." : "\(Format.number(otherVoices)) voices.")
                         : (otherVoices == 1 ? "1 other voice." : "\(Format.number(otherVoices)) other voices."))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
