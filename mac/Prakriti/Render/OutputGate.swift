import Foundation

// The one gate every rendered file passes before it reaches a recording's output folder (docs/v2/PLAN.md 2.1.11 and 2.2
// rule 3, built in v2 part M8b). A video is made inside a staging folder in the make's job folder, measured there, and
// moved into place only by `admit`, which runs the checks its kind needs; the move itself is private to the gate, so no
// writer can put a file into Outputs any other way. A file that fails is deleted where it was made, so nothing that failed
// a privacy check ever sits in Outputs, one drag from YouTube.
//
// What the gate checks for the edited video:
// - **People, by construction.** A video is made only of a recording whose people check ran (faces and voices both):
//   "Who appears and speaks in it has not been checked..." otherwise, before anything is made and again here. Since part
//   M8d anyone may be hidden or left out: the faces of everyone set to Hide Face or Leave Out for the video are hidden in
//   every frame (`VideoHiding`, `Compositor`) and the speech of everyone left out is cut from picture and sound (the edit
//   plan's people cuts, research 3.4 rule 5). M8b's refusal of those recordings is gone (Mac warning 143, rewritten).
// - **The picture output check** (research-people.md 3.6 item 1), whenever someone is hidden: every face Vision finds in the
//   made file, five frames a second, is someone included (`PictureOutputCheck`). Any other face stops the video.
// - **The sound output check** (research-people.md 3.6 item 2, M6c's check on the podcast), whenever someone is left out:
//   the made file's sound is told apart again and every voice in it must be someone included (`AudioOutputCheck`).
// - **The file is whole.** It opens, its last 5 seconds decode, and it is the plan's length within one frame.
// The timelines (v2 part M10a) pass the same gate through `admitTimeline`: the lint and DTD clean on both files, every clip
// decoded to its end, and (part M10b) whenever anyone is hidden or left out or a name muted, their privacy-safe media passing the
// picture and sound output checks and a measure of every replaced stretch, never a clone of the recording.
// A check that was needed and did not run counts as failed (fail closed). The rest of the Ready checklist (bitrate, tags,
// captions, the words) is reported, not gated: a file that misses YouTube's spec is safe to keep and look at, and its
// checklist says FAIL.

enum OutputGate {
    struct Refused: Error, Equatable, Sendable {
        let reason: String
    }

    static let notChecked = "Who appears and speaks in it has not been checked, so no video is made. Choose Check People, then make it again."

    /// The people facts the gate reads: what the people check found and Ivan's names and choices.
    struct People: Sendable {
        var faces: FacesFound?
        var voices: VoicesFound?
        var names: (faces: [Int: UUID], voices: [Int: UUID])
        var choices: PeopleChoices
    }

    /// Why a video of this recording is not made, or nil when it may be: only a recording whose people check has not run
    /// (faces and voices both). Since part M8d anyone may be hidden or left out.
    static func refusal(_ people: People) -> String? {
        people.faces == nil || people.voices == nil ? notChecked : nil
    }

    /// The face rows (and the glimpses, row 0) hidden in the video, and the voices left out of it.
    /// `output` is `.shorts` for a short (v2 part M11a): Ivan may choose differently per output.
    static func hidden(_ people: People, output: ChoiceOutput = .video) -> (faces: Int, voices: Int) {
        guard let faces = people.faces else { return (0, 0) }
        var keys = faces.people.map { PersonKey.face($0.id, names: people.names) }
        if faces.glimpses > 0 { keys.append(PersonKey.face(0, names: people.names)) }
        let hidden = keys.filter { people.choices.choice($0, for: output) != .include }.count
        let out = people.voices.map { people.choices.leftOutVoices($0, names: people.names, output: output).count } ?? 0
        return (hidden, out)
    }

    /// What the gate found wrong with who is in the made video: the refusal, a needed output check that did not run, or one
    /// that failed. Empty when it passes.
    /// `output` and `pictureNeeded` (v2 part M11a): a short reads Ivan's choices for shorts, and a short drawn from the vertical
    /// twin, a second camera, always needs its faces seen again, whoever is hidden.
    static func peopleProblems(_ people: People, picture: PictureCheck?, sound: AudioCheck?, output: ChoiceOutput = .video,
                               pictureNeeded: Bool = false) -> [String] {
        if let reason = refusal(people) { return [reason] }
        var problems: [String] = []
        let (faces, voices) = hidden(people, output: output)
        if faces > 0 || pictureNeeded {
            if let picture {
                if !picture.passed { problems.append(picture.line) }
            } else {
                problems.append("The faces in the made video were not checked, so it is not kept.")
            }
        }
        if voices > 0 {
            if let sound {
                if !sound.passed { problems.append(sound.line { "Voice \($0)" }) }
            } else {
                problems.append("Who is heard in the made video was not checked, so it is not kept.")
            }
        }
        return problems
    }

    /// The checklist's People line.
    static func peopleLine(_ people: People, picture: PictureCheck? = nil, sound: AudioCheck? = nil) -> VideoPeopleLine {
        let problems = peopleProblems(people, picture: picture, sound: sound)
        if let first = problems.first {
            return VideoPeopleLine(passes: false, detail: problems.joined(separator: " "),
                                   todo: first == notChecked ? "Click Check People, then Make Again." : "Hide or include the person in People, then Make Again.")
        }
        let faces = people.faces?.people.count ?? 0, voices = people.voices?.voices.count ?? 0
        let (hiddenFaces, leftOut) = hidden(people)
        var detail = "Checked: \(Format.count(faces, "face")) and \(Format.count(voices, "voice")) found"
        if hiddenFaces == 0 && leftOut == 0 {
            detail += ", everyone included in the video, as you chose."
        } else {
            var parts: [String] = []
            if hiddenFaces > 0 { parts.append("\(Format.count(hiddenFaces, "face")) hidden") }
            if leftOut > 0 { parts.append("\(Format.count(leftOut, "voice")) left out") }
            detail += "; " + parts.joined(separator: " and ") + ", as you chose."
            if let picture { detail += " " + picture.line }
            if let sound, leftOut > 0 { detail += " " + sound.line { "Voice \($0)" }.replacingOccurrences(of: "the episode", with: "the video") }
        }
        return VideoPeopleLine(passes: true, detail: detail)
    }

    /// Moves a staged video folder to `destination` only when it passes; otherwise deletes it and throws why.
    static func admit(staged: URL, to destination: URL, people: People, measured: ReadyChecklist.Measured,
                      expected: ReadyChecklist.Expected, picture: PictureCheck? = nil, sound: AudioCheck? = nil) throws {
        var problems = peopleProblems(people, picture: picture, sound: sound)
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

    /// What the gate reads of one made short (v2 part M11a).
    struct ShortFacts: Sendable {
        var measured: ReadyChecklist.Measured
        /// The short's planned length and one frame.
        var duration: Double
        var frame: Double
        /// Every caption box outside the safe area, in words (`BurnedCaptions.problems`).
        var captionProblems: [String]
        /// Drawn from the vertical twin: its faces were found again on their own and must be seen again in the file.
        var twin: Bool
    }

    /// The longest a short may be (YouTube: a vertical video of up to 3 minutes is a Short).
    static let longestShort = 180.0

    /// What the gate finds wrong with one made short: who is in it (Ivan's choices for shorts, the picture output check whenever
    /// anyone is hidden or the picture is the twin's, the sound output check whenever anyone is left out), and the file: both
    /// picture and sound, 1080 by 1920, its last 5 seconds decoding, the planned length within one frame, at most 3 minutes, and
    /// every caption inside the safe area. Empty when it passes.
    static func shortProblems(_ people: People, facts: ShortFacts, picture: PictureCheck?, sound: AudioCheck?) -> [String] {
        var problems = peopleProblems(people, picture: picture, sound: sound, output: .shorts, pictureNeeded: facts.twin)
        let m = facts.measured
        if m.videoCodec.isEmpty || m.audioCodec.isEmpty { problems.append("The short does not open with both its picture and its sound.") }
        if m.width != Int(BurnedCaptions.frame.width) || m.height != Int(BurnedCaptions.frame.height) {
            problems.append("It is \(m.width) by \(m.height), not 1080 by 1920.")
        }
        if !m.tailDecodes { problems.append("Its last 5 seconds do not decode.") }
        if let d = m.videoDuration ?? m.duration {
            if abs(d - facts.duration) > facts.frame + 0.0005 { problems.append(String(format: "It is %.3f s long, not the %.3f s planned.", d, facts.duration)) }
            if d > longestShort { problems.append(String(format: "It is %.0f s long, over the 3 minutes a Short may be.", d)) }
        } else {
            problems.append("Its length cannot be read.")
        }
        problems += facts.captionProblems
        return problems
    }

    /// Moves a made short's files into `folder` only when it passes `shortProblems`; otherwise deletes them and throws why.
    static func admitShort(files: [URL], to folder: URL, people: People, facts: ShortFacts, picture: PictureCheck?, sound: AudioCheck?) throws {
        let problems = shortProblems(people, facts: facts, picture: picture, sound: sound)
        guard problems.isEmpty else {
            for file in files { try? FileManager.default.removeItem(at: file) }
            throw Refused(reason: problems.joined(separator: " "))
        }
        for file in files { try move(file, to: folder.appending(path: file.lastPathComponent)) }
    }

    /// What the timelines point at, for the gate (v2 part M10b): whether privacy-safe media was needed (anyone hidden or left out,
    /// or a name muted), whether it was made, and what its checks found.
    struct TimelineMediaFacts: Sendable {
        var needed: Bool
        var privacySafe: Bool
        var hiddenFaces: Int
        var leftOutVoices: Int
        var check: CleanedMedia.Check?
    }

    /// What the gate finds wrong with the timelines' media: a clone where privacy-safe media was needed, or privacy-safe media that is
    /// not whole or whose picture, sound or replaced stretches did not pass, or a check that was needed and did not run (fail closed).
    static func timelineMediaProblems(_ media: TimelineMediaFacts) -> [String] {
        guard media.needed else { return [] }
        guard media.privacySafe, let check = media.check else {
            return ["Someone is hidden or left out, and the timelines would point at the recording itself, so they are not kept."]
        }
        var problems: [String] = []
        if !check.whole { problems.append("The privacy-safe media is not whole (\(check.wholeLine)).") }
        if media.hiddenFaces > 0 {
            if let picture = check.picture {
                if !picture.passed { problems.append("In the privacy-safe media: " + picture.line) }
            } else {
                problems.append("The faces in the privacy-safe media were not checked, so the timelines are not kept.")
            }
        }
        if media.leftOutVoices > 0 {
            if let sound = check.sound {
                if !sound.passed { problems.append(sound.line { "Voice \($0)" }) }
            } else {
                problems.append("Who is heard in the privacy-safe media was not checked, so the timelines are not kept.")
            }
        }
        problems += check.silenceProblems
        return problems
    }

    /// Moves a staged `Timeline` folder (v2 part M10a) to `destination` only when it may be kept: `refusal` is the timeline's own
    /// rule read again here (a video made before part M8d is unknown, so refused), `problems` what its checks found (the lint and
    /// DTD on both files, every clip decoded to its end), and since M10b `media` what it points at: whenever anyone is hidden or
    /// left out, or a name is muted, the privacy-safe media, passing the same picture and sound output checks as the MP4 and a
    /// measure of every stretch of removed speech. Otherwise it is deleted where it was made and the reason thrown.
    static func admitTimeline(staged: URL, to destination: URL, refusal: String?, problems: [String], media: TimelineMediaFacts) throws {
        let all = (refusal.map { [$0] } ?? []) + problems + timelineMediaProblems(media)
        guard all.isEmpty else {
            try? FileManager.default.removeItem(at: staged)
            throw Refused(reason: all.joined(separator: " "))
        }
        try move(staged, to: destination)
    }

    /// The only way a made video, timeline or short reaches its folder.
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
