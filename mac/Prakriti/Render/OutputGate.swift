import Foundation

// The one gate every rendered file passes before it reaches a recording's output folder (docs/v2/PLAN.md 2.1.11 and 2.2
// rule 3, built in v2 part M8b). A video is made inside a staging folder in the make's job folder, measured there, and
// moved into place only by `admit`, which runs the checks its kind needs; the move itself is private to the gate, so no
// writer can put a file into Outputs any other way. A file that fails is deleted where it was made, so nothing that failed
// a privacy check ever sits in Outputs, one drag from YouTube.
//
// What the gate checks for the edited video in M8b:
// - **People, by construction.** Part M8b makes a video only of a recording whose people check ran (faces and voices
//   both) and found everyone Included in the video. Anyone set to Hide Face or Leave Out, or a recording never checked,
//   is refused before anything is made (`refusal`) and again at the gate, with "Video for recordings with someone hidden
//   or left out arrives in the next update." The refusal is lifted only by part M8d, which hides faces and cuts voices in
//   the video and adds the picture and sound output checks here (research-people.md 3.6). Ivan, 12 Oct: everyone starts
//   as Include, so a checked recording is refused only when he has chosen to hide or leave someone out.
// - **The file is whole.** It opens, its last 5 seconds decode, and it is the plan's length within one frame.
// The rest of the Ready checklist (bitrate, tags, captions, the words) is reported, not gated: a file that misses YouTube's
// spec is safe to keep and look at, and its checklist says FAIL.

enum OutputGate {
    struct Refused: Error, Equatable, Sendable {
        let reason: String
    }

    /// What Make Video says when it will not make a video in this part.
    static let notYet = "Video for recordings with someone hidden or left out arrives in the next update."
    static let notChecked = "Who appears and speaks in it has not been checked, so no video is made. Choose Check People, then make it again."

    /// The people facts the gate reads: what the people check found and Ivan's names and choices.
    struct People: Sendable {
        var faces: FacesFound?
        var voices: VoicesFound?
        var names: (faces: [Int: UUID], voices: [Int: UUID])
        var choices: PeopleChoices
    }

    /// Why a video of this recording is not made in this part, or nil when it may be.
    static func refusal(_ people: People) -> String? {
        guard let faces = people.faces, let voices = people.voices else { return notChecked }
        var keys: [PersonKey] = faces.people.map { PersonKey.face($0.id, names: people.names) }
        if faces.glimpses > 0 { keys.append(PersonKey.face(0, names: people.names)) }
        keys += voices.voices.map { PersonKey.voice($0, names: people.names) }
        let notIncluded = keys.filter { people.choices.choice($0, for: .video) != .include }
        return notIncluded.isEmpty ? nil : notYet
    }

    /// The checklist's People line for a recording `refusal` lets through.
    static func peopleLine(_ people: People) -> VideoPeopleLine {
        if let reason = refusal(people) {
            return VideoPeopleLine(passes: false, detail: reason, todo: "Include everyone in People, then Make Again.")
        }
        let faces = people.faces?.people.count ?? 0, voices = people.voices?.voices.count ?? 0
        return VideoPeopleLine(passes: true, detail: "Checked: \(Format.count(faces, "face")) and \(Format.count(voices, "voice")) found, everyone included in the video, as you chose.")
    }

    /// Moves a staged video folder to `destination` only when it passes; otherwise deletes it and throws why.
    static func admit(staged: URL, to destination: URL, people: People, measured: ReadyChecklist.Measured,
                      expected: ReadyChecklist.Expected) throws {
        var problems: [String] = []
        if let reason = refusal(people) { problems.append(reason) }
        if measured.videoCodec.isEmpty || measured.audioCodec.isEmpty { problems.append("The video does not open with both its picture and its sound.") }
        if !measured.tailDecodes { problems.append("Its last 5 seconds do not decode.") }
        if let d = measured.videoDuration ?? measured.duration {
            if abs(d - expected.duration) > expected.frame + 0.0005 {
                problems.append(String(format: "It is %.3f s long, not the %.3f s the plan keeps.", d, expected.duration))
            }
        } else {
            problems.append("Its length cannot be read.")
        }
        guard problems.isEmpty else {
            try? FileManager.default.removeItem(at: staged)
            throw Refused(reason: problems.joined(separator: " "))
        }
        try move(staged, to: destination)
    }

    /// The only way a made video reaches its folder.
    private static func move(_ staged: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: staged)
        } else {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: staged, to: destination)
        }
    }
}
