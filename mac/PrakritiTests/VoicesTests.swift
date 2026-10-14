import Foundation
import SwiftData
import Synchronization
import XCTest
@testable import Prakriti

/// Voices and names (v2 part M6b, docs/v2/PLAN.md M6 check 1's `embeddingsPath` and the rules behind checks 2, 4 and
/// 9): the diarizer's configuration exports no embedding, who speaks from microphone tracks on made-up levels, the
/// voices' facts and words, linking faces to voices on made-up boxes and mouths, Ivan's names, and the privacy lock fed
/// by a complete people check. Nothing here reads a talk: the real recordings are `VoicesAcceptanceTests`.
@MainActor
final class VoicesTests: XCTestCase {
    // MARK: Check 1: no embedding leaves the diarizer

    func testEveryDiarizerConfigurationExportsNoEmbedding() {
        XCTAssertFalse(Diarizer.embeddingsPathOfEveryConfiguration.isEmpty)
        for path in Diarizer.embeddingsPathOfEveryConfiguration { XCTAssertNil(path, "OfflineDiarizerConfig.Export.embeddingsPath stays nil") }
        for exposed in Diarizer.chunkEmbeddingsOfEveryConfiguration { XCTAssertFalse(exposed, "chunk embeddings stay off") }
        XCTAssertFalse(Diarizer.configuration().postProcessing.exclusiveSegments, "overlapping speech is kept")
        XCTAssertFalse(Diarizer.configuration().embedding.excludeOverlap, "a voice heard only over another still gets a voice")
        XCTAssertEqual(Diarizer.modelsFolder.lastPathComponent, "speaker-diarization")
        XCTAssertEqual(Diarizer.requiredModels.count, 5)
    }

    // MARK: Who speaks from microphone tracks

    /// Levels every tenth of a second: `level(t)` per track.
    private func levels(_ seconds: Double, _ level: (Double) -> Double) -> [Double] {
        (0..<Int(seconds * 10)).map { level(Double($0) / 10) }
    }

    func testATrackSpeaksWhenItIsSpeechAndNotABleedOfALouderTrack() {
        // Track 2: the teacher at -20 dB from 0 to 10 s. Track 3: the teacher's bleed at -32 dB, and its own voice at
        // -22 dB from 4 to 6 s (both speaking at once, within 6 dB). Track 4: room noise at -60 dB.
        let segments = TrackActivity.segments(levels: [
            2: levels(12) { $0 < 10 ? -20 : -70 },
            3: levels(12) { t in t >= 4 && t < 6 ? -22 : (t < 10 ? -32 : -70) },
            4: levels(12) { _ in -60 },
        ])
        let two = segments.filter { $0.voice == 2 }, three = segments.filter { $0.voice == 3 }
        XCTAssertEqual(two.count, 1)
        XCTAssertEqual(two.first?.start ?? -1, 0, accuracy: 0.01)
        XCTAssertEqual(two.first?.end ?? -1, 10, accuracy: 0.01)
        XCTAssertEqual(three.count, 1, "the bleed is not track 3 speaking; its own voice is")
        XCTAssertEqual(three.first?.start ?? -1, 4, accuracy: 0.01)
        XCTAssertEqual(three.first?.end ?? -1, 6, accuracy: 0.01)
        XCTAssertTrue(segments.allSatisfy { $0.voice != 4 }, "room noise is nobody speaking")
    }

    func testShortGapsJoinAndShortBitsAreDropped() {
        var frames = [Bool](repeating: false, count: 60)
        for i in 0..<10 { frames[i] = true }      // 0.0 to 1.0
        for i in 13..<20 { frames[i] = true }     // a 0.3 s gap: joined
        for i in 30..<32 { frames[i] = true }     // 0.2 s alone: dropped
        for i in 40..<50 { frames[i] = true }     // a 2 s gap before: its own span
        let spans = TrackActivity.smooth(frames)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].0, 0, accuracy: 0.001)
        XCTAssertEqual(spans[0].1, 2.0, accuracy: 0.001)
        XCTAssertEqual(spans[1].0, 4.0, accuracy: 0.001)
        // A track that speaks for under a second in all is not a voice.
        XCTAssertTrue(TrackActivity.segments(levels: [2: levels(5) { $0 < 0.5 ? -20 : -80 }]).isEmpty)
    }

    func testLevelsAreMeasuredEveryTenthOfASecond() {
        let samples = (0..<16_000).map { i in Float(i < 8_000 ? 0.1 : 0) }
        let measured = samples.withUnsafeBufferPointer { TrackActivity.levels($0) }
        XCTAssertEqual(measured.count, 10)
        XCTAssertEqual(measured[0], -20, accuracy: 0.01, "an RMS of 0.1 is -20 dB")
        XCTAssertEqual(measured[9], -120, "digital silence")
    }

    // MARK: The facts and their words

    func testVoicesAreNumberedBySpeakingTimeWithOverlapAndChangesToListenTo() {
        let raw = [VoiceSegment(start: 0, end: 5, voice: 7), VoiceSegment(start: 4, end: 6, voice: 3), VoiceSegment(start: 6, end: 30, voice: 3),
                   VoiceSegment(start: 30, end: 31, voice: 7)]
        let made = VoicesFound.from(segments: raw, source: .diarizer, duration: 31, checkedAt: Fixtures.now)
        XCTAssertEqual(made.found.voices.map(\.label), ["Voice 1", "Voice 2"])
        XCTAssertEqual(made.found.voices[0].speaking, 26, accuracy: 0.001, "the voice that speaks most is Voice 1")
        XCTAssertEqual(made.found.speech, 31, accuracy: 0.001)
        XCTAssertEqual(made.found.overlap, 1, accuracy: 0.001)
        XCTAssertEqual(made.found.listen, [4, 30], "each change of voice on a mixed track is one to listen to")
        XCTAssertEqual(made.segments.first?.voice, 2)
        XCTAssertEqual(made.found.stepLine, "Who speaks is told apart from the one mixed track, so it is a best guess. Two voices, the most for 26 s. No voice is linked to a face. 2 changes of voice to listen to.")
        // From microphone tracks: no changes to listen to, and the tracks named.
        let tracks = VoicesFound.from(segments: [VoiceSegment(start: 0, end: 80, voice: 2), VoiceSegment(start: 30, end: 50, voice: 3)],
                                      source: .tracks, tracks: [2: 2, 3: 3], duration: 90, checkedAt: Fixtures.now)
        XCTAssertEqual(tracks.found.tracksUsed, [2, 3])
        XCTAssertEqual(tracks.found.voices.map(\.track), [2, 3])
        XCTAssertEqual(tracks.found.listen, [])
        XCTAssertTrue(tracks.found.stepLine.hasPrefix("Who speaks is read from the microphone tracks 2 and 3."))
        XCTAssertEqual(VoicesFound.decode(tracks.found.json()), tracks.found)
    }

    // MARK: Linking faces to voices

    private func track(_ id: Int, person: Int?, from: Double, to: Double, x: Double) -> PeopleFile.Track {
        PeopleFile.Track(id: id, person: person, start: from, end: to,
                         boxes: stride(from: from, through: to, by: 0.5).map { [$0, x, 0.3, 0.12, 0.22, 0.9] })
    }

    func testAVoiceIsLinkedToTheOnlyFaceOnScreenAndByTheMouthWhenThereAreTwo() {
        // Row 1 on screen 0 to 60; row 2 in the corner from 20 to 40. Voice 1 speaks 0 to 60 except 25 to 35, where
        // voice 2 speaks. Row 2's mouth moves with voice 2; row 1's mouth moves with voice 1.
        let tracks = [track(1, person: 1, from: 0, to: 60, x: 0.4), track(2, person: 2, from: 20, to: 40, x: 0.8)]
        let segments = [VoiceSegment(start: 0, end: 25, voice: 1), VoiceSegment(start: 25, end: 35, voice: 2), VoiceSegment(start: 35, end: 60, voice: 1)]
        func opening(_ t: Double, speaking: Bool) -> Double { speaking ? 0.05 + 0.04 * sin(t * 17) : 0.02 }
        var mouths: SpeakerLink.Mouths = [:]
        for t in stride(from: 20.0, through: 40.0, by: 0.1) {
            mouths[1, default: []].append((t, opening(t, speaking: !(t >= 25 && t < 35))))
            mouths[2, default: []].append((t, opening(t, speaking: t >= 25 && t < 35)))
        }
        let links = SpeakerLink.link(tracks: tracks, segments: segments, voices: [1, 2], mouths: mouths, every: 0.5)
        XCTAssertEqual(links[1], .init(face: 1, by: SpeakerLink.byOnlyFace))
        XCTAssertEqual(links[2], .init(face: 2, by: SpeakerLink.byMouth))
        XCTAssertEqual(SpeakerLink.crowdedStretches(tracks, every: 0.5).count, 1)
        // Without mouths, the second voice is never alone with a face: no link, a voice with no face.
        let without = SpeakerLink.link(tracks: tracks, segments: segments, voices: [1, 2], mouths: [:], every: 0.5)
        XCTAssertEqual(without[1]?.face, 1)
        XCTAssertNil(without[2], "doubt leaves a voice unlinked")
    }

    func testAnOffCameraVoiceDoesNotTakeTheTeachersFace() {
        // One face all along; the teacher speaks 0 to 50; an off-camera voice asks a question 50 to 55. Each row takes
        // one voice, the strongest first.
        let tracks = [track(1, person: 1, from: 0, to: 60, x: 0.4)]
        let segments = [VoiceSegment(start: 0, end: 50, voice: 1), VoiceSegment(start: 50, end: 55, voice: 2)]
        let links = SpeakerLink.link(tracks: tracks, segments: segments, voices: [1, 2], mouths: [:], every: 0.5)
        XCTAssertEqual(links[1]?.face, 1)
        XCTAssertNil(links[2])
    }

    // MARK: Names and the lock

    let gabriel = NamedPerson(id: UUID(), name: "Gabriel")
    let serenity = NamedPerson(id: UUID(), name: "Serenity")

    func testThePeopleCheckIsCompleteOnlyWithBothSteps() {
        let faces = Fixtures.facesOnePerson(at: Fixtures.now)
        let voices = Fixtures.voicesOneTeacher(at: Fixtures.now)
        let teacher = PeopleNames(teacher: gabriel.id)
        XCTAssertFalse(PeopleFacts.from(faces: faces, voices: nil, names: teacher, people: [gabriel]).checked, "faces alone")
        XCTAssertFalse(PeopleFacts.from(faces: nil, voices: voices, names: teacher, people: [gabriel]).checked, "voices alone")
        XCTAssertEqual(PeopleFacts.from(faces: nil, voices: nil, names: .none, people: [gabriel]), .notChecked)
        // Before the check, the teacher Ivan picked counts as heard (part LOCK: a teacher marked no release still locks).
        XCTAssertEqual(PeopleFacts.from(faces: nil, voices: nil, names: teacher, people: [gabriel]).named.map(\.name), ["Gabriel"])
        // Both steps, nobody named: one face and one voice, both unnamed.
        let unnamed = PeopleFacts.from(faces: faces, voices: voices, names: .none, people: [gabriel])
        XCTAssertTrue(unnamed.checked)
        XCTAssertEqual(unnamed.unnamedSeen, 1)
        XCTAssertEqual(unnamed.unnamedHeard, 1)
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: unnamed)).reason, "unnamed people signed releases too (part LOCK)")
        // Who is teaching: Gabriel takes the voice that speaks most and its linked face.
        let named = PeopleFacts.from(faces: faces, voices: voices, names: teacher, people: [gabriel])
        XCTAssertEqual(named.named.map(\.name), ["Gabriel"])
        XCTAssertEqual(named.named.first?.heard, true)
        XCTAssertEqual(named.named.first?.seen, true)
        XCTAssertEqual(named.unnamedSeen + named.unnamedHeard, 0)
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: named)).reason, "named and released: open")
        // His release turned off: locked.
        var off = gabriel
        off.released = false
        XCTAssertEqual(PrivacyLock.decide(LockSubject(people: PeopleFacts.from(faces: faces, voices: voices, names: teacher, people: [off]))).reason,
                       PrivacyLock.noRelease)
        XCTAssertEqual(PrivacyLock.decide(LockSubject(people: PeopleFacts.from(faces: nil, voices: nil, names: teacher, people: [off]))).reason,
                       PrivacyLock.noRelease, "even before the people check")
        // A name whose person was removed from Settings is nobody named.
        let gone = PeopleFacts.from(faces: faces, voices: voices, names: teacher, people: [])
        XCTAssertEqual(gone.unnamedHeard, 1)
        XCTAssertEqual(gone.unnamedSeen, 1)
        XCTAssertTrue(gone.named.isEmpty)
    }

    func testOtherPeopleNoLongerLockOnlyIvansMarksDo() {
        let faces = Fixtures.facesTwoPeople(at: Fixtures.now)
        let voices = Fixtures.voicesTwoTracks(at: Fixtures.now)
        var names = PeopleNames(teacher: gabriel.id)
        let facts = PeopleFacts.from(faces: faces, voices: voices, names: names, people: [gabriel, serenity])
        XCTAssertEqual(facts.unnamedSeen, 1, "the corner face")
        XCTAssertEqual(facts.unnamedHeard, 1, "the voice on track 3")
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: facts)).reason, "other people seen and heard: everyone signed a release")
        // Leave Out on the unnamed voice, for the podcast only: locked (part LOCK).
        var choices = PeopleChoices()
        choices.set(.leaveOut, for: .voice(2), output: .podcast)
        let leaving = PeopleFacts.from(faces: faces, voices: voices, names: names, people: [gabriel, serenity], choices: choices)
        XCTAssertEqual(leaving.leftOut, 1)
        XCTAssertEqual(PrivacyLock.decide(LockSubject(people: leaving)).reason, PrivacyLock.leftOut)
        // Naming the corner face and the second voice as Serenity, released: open; with her release turned off: local.
        names.faces[2] = serenity.id
        names.voices[2] = serenity.id
        let both = PeopleFacts.from(faces: faces, voices: voices, names: names, people: [gabriel, serenity])
        XCTAssertEqual(both.unnamedSeen + both.unnamedHeard, 0)
        XCTAssertNil(PrivacyLock.decide(LockSubject(people: both)).reason)
        var unreleased = serenity
        unreleased.released = false
        XCTAssertEqual(PrivacyLock.decide(LockSubject(people: PeopleFacts.from(faces: faces, voices: voices, names: names, people: [gabriel, unreleased]))).reason,
                       PrivacyLock.noRelease)
        // Faces seen for under a second count as someone unnamed until named.
        var glimpsed = Fixtures.facesOnePerson(at: Fixtures.now)
        glimpsed.glimpses = 2
        let withGlimpses = PeopleFacts.from(faces: glimpsed, voices: Fixtures.voicesOneTeacher(at: Fixtures.now), names: PeopleNames(teacher: gabriel.id), people: [gabriel])
        XCTAssertEqual(withGlimpses.unnamedSeen, 2)
        let glimpsesNamed = PeopleFacts.from(faces: glimpsed, voices: Fixtures.voicesOneTeacher(at: Fixtures.now),
                                             names: PeopleNames(teacher: gabriel.id, faces: [0: gabriel.id]), people: [gabriel])
        XCTAssertEqual(glimpsesNamed.unnamedSeen, 0)
    }

    func testANameCrossesALinkAndAHandGivenNameWins() {
        let faces = Fixtures.facesTwoPeople(at: Fixtures.now)
        var voices = Fixtures.voicesTwoTracks(at: Fixtures.now)
        voices.voices[1].face = 2
        // Naming the corner face reaches its linked voice.
        let resolved = PeopleNames(faces: [2: serenity.id]).resolved(faces: faces, voices: voices)
        XCTAssertEqual(resolved.voices[2], serenity.id)
        // The teacher takes voice 1 and face 1, unless face 1 is named by hand.
        let byHand = PeopleNames(teacher: gabriel.id, faces: [1: serenity.id]).resolved(faces: faces, voices: voices)
        XCTAssertEqual(byHand.voices[1], gabriel.id)
        XCTAssertEqual(byHand.faces[1], serenity.id)
        // A name for a row that no longer exists is dropped.
        XCTAssertNil(PeopleNames(faces: [9: gabriel.id]).resolved(faces: faces, voices: voices).faces[9])
    }

    func testTheWordsSayWhoSpeaksInPercent() {
        let faces = Fixtures.facesOnePerson(at: Fixtures.now)
        let voices = Fixtures.voicesOneTeacher(at: Fixtures.now)
        XCTAssertEqual(PeopleWords.summary(faces: faces, voices: voices, names: PeopleNames(teacher: gabriel.id), people: [gabriel]),
                       "Gabriel speaks for 100 percent.")
        XCTAssertEqual(PeopleWords.summary(faces: faces, voices: voices, names: .none, people: [gabriel]),
                       "One voice speaks, not named yet. One face is not named.")
        let two = PeopleWords.summary(faces: Fixtures.facesTwoPeople(at: Fixtures.now), voices: Fixtures.voicesTwoTracks(at: Fixtures.now),
                                      names: PeopleNames(teacher: gabriel.id), people: [gabriel])
        XCTAssertEqual(two, "Gabriel speaks for 96 percent. One other voice, not named. One face is not named.")
        XCTAssertEqual(PeopleWords.line(faces: Fixtures.facesTwoPeople(at: Fixtures.now), voices: Fixtures.voicesTwoTracks(at: Fixtures.now),
                                        names: PeopleNames(teacher: gabriel.id), people: [gabriel]),
                       "Gabriel. Up to 2 people at once. 1 other voice.")
        XCTAssertEqual(PeopleWords.line(faces: faces, voices: voices, names: .none, people: []), "One person at a time. One voice.")
        for text in [two, PeopleWords.summary(faces: faces, voices: voices, names: .none, people: [])] {
            XCTAssertFalse(text.contains("\u{2014}"), "no em dash")
        }
    }

    // MARK: The store, the people file and the pipeline

    func testTheRecordingsLockReadsTheStoresPeopleAndTheFoldersMicrophones() throws {
        // Part LOCK's acceptance on a recording in a store: a class, with a face and a voice nobody named, is written by
        // Anthropic; a person set to Leave Out, or marked no release, keeps it on this Mac.
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: FileManager.default.temporaryDirectory),
                             settings: .ephemeral(), log: AppLog(directory: nil), now: { Fixtures.now })
        let recording = Recording(filePath: "/tmp/2026-09-13 class.mp4", foundAt: Fixtures.now, kind: .lesson)
        model.context.insert(recording)
        recording.hasSerenity = true
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: recording), .claudeAPI, "a class, people not checked, that names Serenity")
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        XCTAssertFalse(recording.lockSubject.people.checked, "faces alone")
        model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.now), to: recording)
        XCTAssertTrue(recording.lockSubject.people.checked)
        let gabriel = try XCTUnwrap(model.addPerson(named: "Gabriel"))
        XCTAssertEqual(model.addPerson(named: " gabriel ")?.id, gabriel.id, "the same name twice is one person")
        XCTAssertFalse(gabriel.noRelease, "everyone starts with a signed release on file")
        model.setTeacher(gabriel, for: recording)
        XCTAssertEqual(recording.names.teacher, gabriel.id)
        XCTAssertGreaterThan(recording.lockSubject.people.unnamedSeen + recording.lockSubject.people.unnamedHeard, 0, "the corner face and track 3")
        XCTAssertNil(PrivacyLock.decide(recording.lockSubject).reason, "a class with someone unnamed")
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: recording), .claudeAPI)
        XCTAssertNil(recording.lockLine)
        // Leave Out on the unnamed voice: locked, and the Checks line says why without a name.
        let key = try XCTUnwrap(recording.unnamedKeys.first)
        _ = model.setChoice(.leaveOut, for: key, output: nil, in: recording)
        XCTAssertEqual(PrivacyLock.decide(recording.lockSubject).reason, PrivacyLock.leftOut)
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: recording), .lmStudio)
        XCTAssertEqual(recording.lockLine, "Someone in it is set to Leave Out, so only models on this Mac read it.")
        _ = model.setChoice(.include, for: key, output: nil, in: recording)
        XCTAssertNil(PrivacyLock.decide(recording.lockSubject).reason, "back to Include: open again")
        let serenity = try XCTUnwrap(model.addPerson(named: "Serenity"))
        model.nameFace(2, as: gabriel, in: recording)
        // "Track 3 is Serenity's microphone" for the folder.
        let source = Source(name: "Studio", path: "/tmp")
        model.context.insert(source)
        recording.source = source
        model.setMicrophone(track: 3, to: serenity, for: recording)
        XCTAssertEqual(recording.resolvedNames.voices[2], serenity.id)
        XCTAssertNil(PrivacyLock.decide(recording.lockSubject).reason, "everyone named and released")
        model.setRelease(false, for: serenity)
        XCTAssertTrue(serenity.noRelease)
        XCTAssertEqual(PrivacyLock.decide(recording.lockSubject).reason, PrivacyLock.noRelease, "Serenity marked no release")
        XCTAssertEqual(ModelRouting.provider(chosen: .claudeAPI, for: recording), .lmStudio)
        model.setRelease(true, for: serenity)
        XCTAssertNil(PrivacyLock.decide(recording.lockSubject).reason)
        // Removing a person makes their rows unnamed, which no longer locks.
        model.removePerson(serenity)
        XCTAssertNil(PrivacyLock.decide(recording.lockSubject).reason)
        // What the runner hands a make: the names, the folder's microphones and the people.
        let setup = try XCTUnwrap(model.runner.options(for: recording).people)
        XCTAssertEqual(setup.names.teacher, gabriel.id)
        XCTAssertEqual(setup.people.map(\.name), ["Gabriel"])
        XCTAssertEqual(setup.microphones[3], serenity.id)
    }

    func testThePeopleFileWithVoicesKeepsTimesOnly() throws {
        var file = PeopleFile(recordingID: UUID(), scan: FaceScan.Result(hasPicture: true, duration: 600, width: 1920, height: 1080),
                              found: FacesFound(checkedAt: Fixtures.now, duration: 600), tracks: [], rows: [])
        let segments: [[Double]] = (0..<2000).map { (i: Int) -> [Double] in
            let start = Double(i) * 0.3
            let voice = Double(i % 3 + 1)
            return [start, start + 0.25, voice]
        }
        file.voices = PeopleFile.Voices(source: "diarizer", tracks: [], segments: segments, links: [[1, 1]])
        file.steps.append("voices")
        let data = try PeopleFile.encoder.encode(file)
        try PeopleTests.assertNoPrintAndNoPicture(data)
        let back = try PeopleFile.decoder.decode(PeopleFile.self, from: data)
        XCTAssertEqual(back.voices?.voiceSegments.count, 2000)
        XCTAssertEqual(back.steps, ["faces", "voices"])
        // A people file from part M6a, with no voice part, still reads.
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old["voices"] = nil
        old["steps"] = ["faces"]
        let earlier = try PeopleFile.decoder.decode(PeopleFile.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(earlier.voices)
    }

    func testThePipelinePlansVoicesRightAfterFaces() {
        var options = PipelineOptions()
        XCTAssertFalse(options.plannedSteps.contains(.voices))
        options.people = PeopleSetup(recordingID: UUID(), folders: PeopleFolders(support: FileManager.default.temporaryDirectory))
        XCTAssertEqual(options.plannedSteps, [.complete, .capture, .sound, .speechAudio, .transcript, .coverage, .namesSaid, .faces, .voices, .episode, .loudness, .report])
        XCTAssertEqual(PipelineStep.voices.title, "Voices")
        XCTAssertEqual(PipelineStep.voices.doing, "Listening for voices")
        XCTAssertTrue(PipelineStep.voices.isMetered)
    }

    func testTheVoiceStepReadsMicrophoneTracksAndLeavesNoJobFolder() async throws {
        let work = FileManager.default.temporaryDirectory.appending(path: "prakriti-voices-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let folders = PeopleFolders(support: work.appending(path: "Support", directoryHint: .isDirectory))
        // Three tracks: a mix, a tone on track 2 for 8 s, a tone on track 3 from 3 to 5 s; a test pattern picture.
        let clip = work.appending(path: "tracks.mov")
        let ffmpeg = ToolPaths.standard.ffmpeg
        func run(_ arguments: [String]) throws {
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = ["-hide_banner", "-v", "error", "-y"] + arguments
            try process.run()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0)
        }
        try run(["-f", "lavfi", "-i", "testsrc2=size=320x180:rate=30:duration=8",
                 "-f", "lavfi", "-i", "sine=frequency=220:duration=8",
                 "-f", "lavfi", "-i", "sine=frequency=550:duration=8",
                 "-filter_complex", "[1:a]asplit=2[t2a][t2b];[2:a]volume='if(between(t,3,5),1,0)':eval=frame,asplit=2[t3a][t3b];[t2a][t3a]amix=inputs=2[mix]",
                 "-map", "0:v", "-map", "[mix]", "-map", "[t2b]", "-map", "[t3b]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-ac", "1", clip.path])
        let id = UUID()
        _ = try await FaceStep.run(file: clip, recordingID: id, folders: folders, now: Fixtures.now)
        let count = await VoiceStep.audioTracks(clip)
        XCTAssertEqual(count, 3)
        let lines = Mutex<[String]>([])
        let outcome = try await VoiceStep.run(file: clip, recordingID: id, folders: folders, audioTracks: count, now: Fixtures.now,
                                              decode: { arguments in _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(60)) },
                                              log: { line in lines.withLock { $0.append(line) } })
        XCTAssertEqual(outcome.found.source, .tracks)
        XCTAssertEqual(outcome.found.tracksUsed, [2, 3])
        XCTAssertEqual(outcome.found.voices.count, 2)
        XCTAssertEqual(outcome.found.voices.first { $0.track == 3 }?.first ?? 0, 3, accuracy: 0.3)
        XCTAssertEqual(outcome.found.voices.first { $0.track == 3 }?.last ?? 0, 5, accuracy: 0.3)
        XCTAssertTrue(lines.withLock { $0 }.contains { $0.hasPrefix("Who speaks is read from microphone tracks 2, 3") })
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folders.jobs.path), [], "the job folder is gone when the step ends")
        let file = try XCTUnwrap(folders.read(id))
        XCTAssertEqual(file.steps, ["faces", "voices"])
        try PeopleTests.assertNoPrintAndNoPicture(try Data(contentsOf: folders.peopleFile(for: id)))
        for forbidden in folders.forbidden { XCTAssertFalse(FileManager.default.fileExists(atPath: forbidden.path), forbidden.path) }
    }
}
