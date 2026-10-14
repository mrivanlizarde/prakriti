import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// Choices applied to audio (v2 part M6c, docs/v2/PLAN.md M6 check 1's decisions and widening, and the rules behind
/// checks 3, 4, 10 and 11): the choices and their default, who a choice belongs to, Leave Out widened into the pauses,
/// speaking at once, muted names in the sound and the words, the pipeline's plan, the store's "not in the episode yet",
/// Approve's new refusals and the notice. Nothing here reads a talk: the real files are `ChoicesAcceptanceTests`.
@MainActor
final class ChoicesTests: XCTestCase {
    let gabriel = NamedPerson(id: UUID(), name: "Gabriel")

    // MARK: Check 1: decisions default correctly

    func testEveryoneStartsIncludedAndAChoiceCanDifferPerOutput() {
        var choices = PeopleChoices.none
        let corner = PersonKey.face(2), voice = PersonKey.voice(2), teacher = PersonKey.named(gabriel.id)
        for key in [corner, voice, teacher] {
            for output in ChoiceOutput.allCases { XCTAssertEqual(choices.choice(key, for: output), .include, "Ivan, 12 Oct: releases exist") }
        }
        XCTAssertEqual(PeopleChoices.defaultChoice, .include)
        XCTAssertFalse(choices.changesPodcast)
        choices.set(.leaveOut, for: voice)
        XCTAssertEqual(choices.choice(voice, for: .podcast), .leaveOut)
        XCTAssertEqual(choices.choice(voice, for: .video), .leaveOut)
        XCTAssertTrue(choices.changesPodcast)
        XCTAssertTrue(choices.leavesSomeoneOut)
        // Customize per Output: keep them in the podcast only.
        choices.set(.include, for: voice, output: .podcast)
        XCTAssertEqual(choices.choice(voice, for: .podcast), .include)
        XCTAssertEqual(choices.choice(voice, for: .video), .leaveOut)
        XCTAssertTrue(choices.overall(voice).differs)
        XCTAssertFalse(choices.changesPodcast, "left out of the video only: the podcast is unchanged")
        // A choice for every output clears the per-output ones; back to the default leaves nothing stored.
        choices.set(.include, for: voice)
        XCTAssertTrue(choices.people.isEmpty)
        // Set All Unnamed To never touches a named person.
        choices.setAll(.leaveOut, unnamed: [corner, voice, teacher])
        XCTAssertEqual(choices.choice(corner, for: .podcast), .leaveOut)
        XCTAssertEqual(choices.choice(voice, for: .podcast), .leaveOut)
        XCTAssertEqual(choices.choice(teacher, for: .podcast), .include)
        // Stored as JSON and read back.
        XCTAssertEqual(PeopleChoices.decode(choices.json()), choices)
        XCTAssertEqual(PeopleChoices.decode(nil), .none)
        XCTAssertEqual(PersonKey(teacher.string), teacher)
        XCTAssertEqual(PersonKey("face:2"), corner)
        XCTAssertNil(PersonKey("nobody"))
        XCTAssertEqual(PersonChoice.allCases.map(\.title), ["Include", "Hide Face", "Leave Out"])
        XCTAssertEqual(PersonChoice.forVoice.map(\.title), ["Include", "Leave Out"], "a voice with no face has no face to hide")
    }

    func testAChoiceBelongsToTheNamedPersonElseTheFaceElseTheVoice() {
        var voices = Fixtures.voicesTwoTracks(at: Fixtures.now)
        let faces = Fixtures.facesTwoPeople(at: Fixtures.now)
        let teacher = PeopleNames(teacher: gabriel.id).resolved(faces: faces, voices: voices)
        XCTAssertEqual(PersonKey.voice(voices.voices[0], names: teacher), .named(gabriel.id), "the teacher's voice is the teacher")
        XCTAssertEqual(PersonKey.voice(voices.voices[1], names: teacher), .voice(2), "a voice with no face is its own")
        XCTAssertEqual(PersonKey.face(2, names: teacher), .face(2))
        voices.voices[1].face = 2
        let linked = PeopleNames(teacher: gabriel.id).resolved(faces: faces, voices: voices)
        XCTAssertEqual(PersonKey.voice(voices.voices[1], names: linked), .face(2), "a voice linked to a face goes with the face")
        var choices = PeopleChoices.none
        choices.set(.leaveOut, for: .face(2))
        XCTAssertEqual(choices.leftOutVoices(voices, names: linked), [2], "Leave Out on the face takes its voice")
        choices.set(.hideFace, for: .face(2))
        XCTAssertEqual(choices.leftOutVoices(voices, names: linked), [], "Hide Face keeps the voice")
    }

    // MARK: Check 1: Remove widens to pauses

    /// Words 0.3 s long with 0.1 s between them, and pauses from 9.5 to 10.0 and from 11.9 to 12.6.
    private func words() -> [TimeRange] {
        var out: [TimeRange] = []
        var t = 0.0
        while t < 20 {
            if t >= 9.4 && t < 10.0 { t = 10.0; continue }
            if t >= 12.0 && t < 12.6 { t = 12.6; continue }
            out.append(TimeRange(start: t, end: t + 0.3))
            t += 0.4
        }
        return out
    }

    func testLeaveOutTakesEveryWordItTouchesAndLandsInThePauses() {
        let words = words()
        // Voice 2 from 10.05 to 11.95: inside the words from 10.0 to 11.9 (the last word ends at 12.1).
        let segments = [VoiceSegment(start: 0, end: 9.4, voice: 1), VoiceSegment(start: 10.05, end: 11.95, voice: 2),
                        VoiceSegment(start: 12.6, end: 20, voice: 1)]
        let plan = LeaveOut.plan(segments: segments, leftOut: [2], words: words, duration: 20)
        XCTAssertEqual(plan.cuts.count, 1)
        let cut = plan.cuts[0]
        // Grown to the first word's start (10.0), then the 0.5 s gap before it (9.5 to 10.0) is short, so taken whole to
        // within 0.03 of the word before: 9.53.
        XCTAssertEqual(cut.start, 9.53, accuracy: 0.001)
        // The words run 10.0, 10.4 ... 11.6 (ending 11.9); the stretch ends at 11.95, then a 0.65 s pause to 12.6: longer
        // than 0.5, so 0.25 of it: 12.2.
        XCTAssertEqual(cut.end, 12.2, accuracy: 0.001)
        // No word is left half cut.
        for word in words { XCTAssertFalse(word.start < cut.start && word.end > cut.start, "a word cut at its start") }
        for word in words { XCTAssertFalse(word.start < cut.end && word.end > cut.end, "a word cut at its end") }
        XCTAssertEqual(plan.removedSeconds, 2.67, accuracy: 0.001)
        XCTAssertTrue(plan.overlaps.isEmpty, "nobody else speaks then")
        XCTAssertFalse(plan.stepLine.contains("\u{2014}"))
        // The episode keeps everything else, with the 15 ms fades of milestone 5.
        let parts = EpisodeEdits().adding(cuts: plan.cuts).segments(duration: 20)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0].end, 9.53, accuracy: 0.001)
        XCTAssertEqual(parts[1].start, 12.2, accuracy: 0.001)
    }

    func testSpeakingAtOnceIsCutWholeWordsAndListed() {
        let words = words()
        // Voice 2 speaks over Voice 1 from 4.15 to 5.05: the words it touches (4.0 to 4.3 and 4.8 to 5.1) go whole.
        let segments = [VoiceSegment(start: 0, end: 9.4, voice: 1), VoiceSegment(start: 4.15, end: 5.05, voice: 2)]
        let plan = LeaveOut.plan(segments: segments, leftOut: [2], words: words, duration: 20)
        XCTAssertEqual(plan.overlaps.count, 1, "listed for listening")
        XCTAssertEqual(plan.overlaps[0].start, 4.15, accuracy: 0.001)
        XCTAssertEqual(plan.overlaps[0].end, 5.05, accuracy: 0.001)
        let cut = plan.cuts[0]
        // Touched: the word 4.0 to 4.3 and the word 4.8 to 5.1; the 0.1 s gap before is taken to within 0.03 of the word
        // before, so no fragment of it is left. After, the next word starts at 5.2, and its start may really be up to
        // `wordLead` earlier, so the cut stops at the end of the words it takes: 5.1.
        XCTAssertEqual(cut.start, 3.93, accuracy: 0.001)
        XCTAssertEqual(cut.end, 5.1, accuracy: 0.001)
        // Voice 1 is never left out, and a voice nobody left out cuts nothing.
        XCTAssertTrue(LeaveOut.plan(segments: segments, leftOut: [], words: words, duration: 20).cuts.isEmpty)
    }

    /// The cause of the M6c verifier's failure, on the real word times: on two-people-tracks Parakeet placed Gabriel's
    /// "business" at 48.80 s, and the cut grew to 0.03 s before it (48.77), but in the clean 13sep-90s clip the word
    /// starts at 48.64 s and the cut took it. The cut now stops `wordLead` before the next word's given start, never before
    /// the words it takes nor `voiceTail` past the left-out voice.
    func testTheCutStopsBeforeTheNextWordAllowingForALateStart() {
        // two-people-tracks: voice 2 from tracks, 30.0 to 48.5; "teaching" (48.40 to 48.64) is touched, so taken whole.
        let tracksWords = [TimeRange(start: 47.92, end: 48.0), TimeRange(start: 48.0, end: 48.08), TimeRange(start: 48.40, end: 48.64),
                           TimeRange(start: 48.80, end: 49.20), TimeRange(start: 49.28, end: 49.36)]
        let tracks = LeaveOut.plan(segments: [VoiceSegment(start: 30, end: 48.5, voice: 2), VoiceSegment(start: 48.4, end: 50.7, voice: 1)],
                                   leftOut: [2], words: tracksWords, duration: 90)
        XCTAssertEqual(tracks.cuts.last!.end, 48.64, accuracy: 0.001)
        XCTAssertLessThanOrEqual(tracks.cuts.last!.end, 48.64, "the clean clip's \"business\" starts at 48.64 s and is kept")
        // two-people-mixed: voice 2 by the diarizer to 48.49; the next word Parakeet gives is at 48.64.
        let mixedWords = [TimeRange(start: 47.84, end: 47.92), TimeRange(start: 48.0, end: 48.08), TimeRange(start: 48.64, end: 48.72),
                          TimeRange(start: 48.80, end: 49.20)]
        let mixed = LeaveOut.plan(segments: [VoiceSegment(start: 29.95, end: 48.49, voice: 2)], leftOut: [2], words: mixedWords, duration: 90)
        XCTAssertEqual(mixed.cuts.last!.end, 48.49 + LeaveOut.voiceTail, accuracy: 0.001, "never short of the voice's own end")
        XCTAssertLessThanOrEqual(mixed.cuts.last!.end, 48.64)
        // A real pause is still reached into: the voice ends at 48.5 and the next word is 1 s later, so the cut goes 0.25 s in.
        let paused = LeaveOut.plan(segments: [VoiceSegment(start: 30, end: 48.5, voice: 2)], leftOut: [2],
                                   words: [TimeRange(start: 48.0, end: 48.4), TimeRange(start: 49.5, end: 49.9)], duration: 90)
        XCTAssertEqual(paused.cuts.last!.end, 48.75, accuracy: 0.001)
    }

    /// With the sound: the end settles at the start of the quiet between the voice's own end and the end the words give,
    /// so the 15 ms fade of the part kept after it lies in the quiet. Levels shaped like two-people-tracks' first track
    /// (measured 13 Oct): "teaching" until a dip whose quietest 20 ms starts at 48.535, then "business".
    func testWithTheSoundTheEdgeSettlesInTheQuietestMoment() {
        func index(_ at: Double) -> Int { Int(((at - 47.0) / EdgeLevels.hop).rounded()) }
        var levels: [Double] = Array(repeating: -25, count: 600)   // windows starting 47.0 to 50.0, every 5 ms
        for (at, level) in [(48.50, -36.0), (48.505, -38.0), (48.51, -39.0), (48.515, -40.0), (48.52, -41.0), (48.525, -43.0),
                            (48.53, -45.0), (48.535, -48.0), (48.54, -46.0), (48.545, -38.0), (48.55, -32.0)] { levels[index(at)] = level }
        // A deeper silence inside "teaching" before the voice ends must not be chosen: the search starts at the voice's end.
        levels[index(48.30)] = -80
        let audio = EdgeLevels(pieces: [.init(start: 47.0, levels: levels)])
        // The quietest 20 ms starts at 48.535 (-48 dB); the quiet, within 10 dB of it, begins at 48.505 (-38 dB) and ends with
        // the window starting 48.545 (-38 dB).
        XCTAssertEqual(audio.quiet(in: TimeRange(start: 48.50, end: 48.64), toward: .start)!.start, 48.505, accuracy: 0.0001)
        XCTAssertEqual(audio.quiet(in: TimeRange(start: 48.50, end: 48.64), toward: .end)!.start, 48.545, accuracy: 0.0001)
        XCTAssertNil(audio.quiet(in: TimeRange(start: 48.50, end: 48.51), toward: .start), "shorter than 20 ms")
        XCTAssertNil(audio.quiet(in: TimeRange(start: 10, end: 11), toward: .start), "no sound read there")
        let words = [TimeRange(start: 48.0, end: 48.08), TimeRange(start: 48.40, end: 48.64), TimeRange(start: 48.80, end: 49.20)]
        let segments = [VoiceSegment(start: 30, end: 48.5, voice: 2), VoiceSegment(start: 48.4, end: 50.7, voice: 1)]
        let plain = LeaveOut.plan(segments: segments, leftOut: [2], words: words, duration: 90)
        let heard = LeaveOut.plan(segments: segments, leftOut: [2], words: words, duration: 90, audio: audio)
        XCTAssertEqual(plain.cuts.last!.end, 48.64, accuracy: 0.001)
        XCTAssertEqual(heard.cuts.last!.end, 48.505, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(heard.cuts.last!.end, 48.5, "never before the left-out voice's own end")
        // The start settles at the end of its quiet window, so the fade out of the part before lies in the quiet.
        var before: [Double] = Array(repeating: -25, count: 600)
        before[Int(((29.92 - 27.0) / EdgeLevels.hop).rounded())] = -60
        let start = LeaveOut.plan(segments: [VoiceSegment(start: 30, end: 31, voice: 2)], leftOut: [2],
                                  words: [TimeRange(start: 29.0, end: 29.85), TimeRange(start: 30.0, end: 30.9)], duration: 90,
                                  audio: EdgeLevels(pieces: [.init(start: 27.0, levels: before)]))
        XCTAssertEqual(start.cuts[0].start, 29.94, accuracy: 0.0001)
        // The 20 ms levels of a run of samples: a full-scale square wave is 0 dB, silence the floor.
        XCTAssertEqual(EdgeLevels.levels([Float](repeating: 1, count: 640)).first!, 0, accuracy: 0.001)
        XCTAssertEqual(EdgeLevels.levels([Float](repeating: 0, count: 640)).count, 5)
    }

    func testWithoutWordsALeftOutStretchIsPaddedAndJoined() {
        let segments = [VoiceSegment(start: 30, end: 40, voice: 2), VoiceSegment(start: 40.2, end: 48.5, voice: 2)]
        let plan = LeaveOut.plan(segments: segments, leftOut: [2], words: nil, duration: 90)
        XCTAssertEqual(plan.cuts.count, 1, "two stretches 0.2 s apart are one cut")
        let apart = LeaveOut.plan(segments: [VoiceSegment(start: 30, end: 38.2, voice: 2), VoiceSegment(start: 38.56, end: 48.5, voice: 2),
                                             VoiceSegment(start: 60, end: 62, voice: 2)], leftOut: [2], words: nil, duration: 90)
        XCTAssertEqual(apart.cuts.count, 2, "a 0.36 s island is cut with them; 11.5 s apart is not")
        XCTAssertEqual(plan.cuts[0].start, 30 - LeaveOut.blindPad, accuracy: 0.001)
        XCTAssertEqual(plan.cuts[0].end, 48.5 + LeaveOut.blindPad, accuracy: 0.001)
    }

    func testAWordStretchedAcrossAPauseIsNotTakenAsSpeech() throws {
        // Parakeet's last word before a pause can run seconds into it (Mac warning 40): taken as a second at most.
        let json = #"{"sentences":[{"text":" Caught. Next","start":1.0,"end":5.4,"tokens":[{"text":" Caught","start":1.0,"end":4.0},{"text":".","start":4.0,"end":4.1},{"text":" Next","start":5.0,"end":5.4}]}]}"#
        let sentences = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(json.utf8)))
        let spans = EpisodeTranscript.wordSpans(sentences)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].end, 2.0, accuracy: 0.001)
        XCTAssertEqual(spans[1].start, 5.0, accuracy: 0.001)
    }

    // MARK: Muted names: the sound and the words

    func testAMutedNameSilencesItsFramesAndOnlyThem() {
        XCTAssertNil(Mastering.muteFilter([]), "nothing muted: nothing added to the chain")
        var program = Mastering.Program(kept: nil)
        let plain = Mastering.pass(file: "/in.mp4", program: program, loudness: "LOUD")
        XCTAssertEqual(plain, ["-i", "/in.mp4", "-vn", "-af", Mastering.format(.mono) + ",LOUD"], "engine v0's chain, string for string")
        program.mutes = [Mastering.Span(start: 9.94, end: 10.56)]
        let muted = Mastering.pass(file: "/in.mp4", program: program, loudness: "LOUD")
        XCTAssertEqual(muted.last, "volume=volume='clip((abs(t-10.250)-0.310)/0.03,0,1)':eval=frame," + Mastering.format(.mono) + ",LOUD")
        // With parts, the mute comes before the split, on the original's clock.
        program.parts = [Mastering.Span(start: 0, end: 5), Mastering.Span(start: 6, end: 20)]
        let graph = Mastering.pass(file: "/in.mp4", program: program, loudness: "LOUD")
        let filter = try? XCTUnwrap(graph.firstIndex(of: "-filter_complex").map { graph[$0 + 1] })
        XCTAssertTrue(filter?.hasPrefix("[0:a]volume=volume='clip(") == true, filter ?? "")
        XCTAssertTrue(filter?.contains(":eval=frame,asplit=2[s0][s1]") == true, filter ?? "")
    }

    func testAMutedNameIsWrittenAsNameInTheCaptions() throws {
        let json = #"{"sentences":[{"text":" Thank you, Maria, for asking.","start":1.0,"end":3.0,"tokens":[{"text":" Thank","start":1.0,"end":1.2},{"text":" you","start":1.2,"end":1.4},{"text":",","start":1.4,"end":1.4},{"text":" Maria","start":1.5,"end":1.9},{"text":",","start":1.9,"end":1.9},{"text":" for","start":2.0,"end":2.2},{"text":" asking","start":2.2,"end":2.7},{"text":".","start":2.7,"end":2.8}]}]}"#
        let sentences = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(json.utf8)))
        let clock = EpisodeClock(intro: 0, segments: [Mastering.Span(start: 0, end: 10)])
        XCTAssertEqual(EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: false).cues.first?.text, "Thank you, Maria, for asking.")
        let muted = EpisodeTranscript.cues(sentences, clock: clock, applyLexicon: false, mutes: [TimeRange(start: 1.44, end: 1.96)])
        XCTAssertEqual(muted.cues.first?.text, "Thank you, [name], for asking.")
        // A name of two words is one [name].
        let two = #"{"sentences":[{"text":" Ask Pattabhi Jois.","start":0,"end":2,"tokens":[{"text":" Ask","start":0,"end":0.3},{"text":" Pattabhi","start":0.4,"end":0.9},{"text":" Jois","start":0.9,"end":1.3},{"text":".","start":1.3,"end":1.3}]}]}"#
        let twoSentences = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(two.utf8)))
        let both = EpisodeTranscript.cues(twoSentences, clock: clock, applyLexicon: false, mutes: [TimeRange(start: 0.34, end: 1.36)])
        XCTAssertEqual(both.cues.first?.text, "Ask [name].")
        XCTAssertEqual(muted.removedWords, 0)
    }

    func testNamesSaidAloudAreFoundExceptThePeopleNamed() throws {
        let json = #"{"sentences":[{"text":" Yesterday Maria asked Gabriel about the breath.","start":0,"end":3.2,"tokens":[{"text":" Yesterday","start":0,"end":0.5},{"text":" Maria","start":0.6,"end":1.0},{"text":" asked","start":1.0,"end":1.3},{"text":" Gabriel","start":1.4,"end":1.9},{"text":" about","start":2.0,"end":2.2},{"text":" the","start":2.2,"end":2.3},{"text":" breath","start":2.3,"end":2.8},{"text":".","start":2.8,"end":2.9}]}]}"#
        let sentences = try XCTUnwrap(EpisodeTranscript.sentences(json: Data(json.utf8)))
        let all = NamesSaidAloud.find(sentences, named: [])
        XCTAssertEqual(all.map(\.text), ["Maria", "Gabriel"], "the tagger's two names")
        let found = NamesSaidAloud.find(sentences, named: ["Gabriel Galindo"])
        XCTAssertEqual(found.map(\.text), ["Maria"], "a named person is not a name to check")
        XCTAssertEqual(found.first?.start ?? -1, 0.6, accuracy: 0.001)
        XCTAssertEqual(found.first?.end ?? -1, 1.0, accuracy: 0.001)
        let said = NamesSaid(checkedAt: Fixtures.now, moments: found + [NameMoment(start: 9, end: 9.4, text: "maria")])
        XCTAssertEqual(said.byName.map(\.name), ["Maria"], "one row per name, whatever its case")
        XCTAssertEqual(said.byName.first?.moments.count, 2)
        XCTAssertFalse(said.stepLine.contains("Maria"), "the step's line carries a count, never a name")
        XCTAssertEqual(NamesSaid.decode(said.json()), said)
    }

    // MARK: The pipeline's plan

    func testThePipelinePlansLeaveOutAndTheCheckOnlyWhenSomeoneIsLeftOut() {
        var options = PipelineOptions()
        options.people = PeopleSetup(recordingID: UUID(), folders: PeopleFolders(support: FileManager.default.temporaryDirectory))
        XCTAssertEqual(options.plannedSteps, [.complete, .capture, .sound, .speechAudio, .transcript, .coverage, .namesSaid, .faces, .voices, .episode, .loudness, .report])
        XCTAssertFalse(options.changesTheClock, "nobody left out: the episode is made as before")
        options.choices.set(.leaveOut, for: .voice(2))
        XCTAssertEqual(options.plannedSteps, [.complete, .capture, .sound, .speechAudio, .transcript, .coverage, .namesSaid, .faces, .voices, .leaveOut,
                                              .episode, .loudness, .audioCheck, .episodeTranscript, .report])
        XCTAssertTrue(options.changesTheClock)
        // A muted name alone: the step, no audio check.
        options.choices = .none
        options.choices.names["1.50"] = .mute
        XCTAssertTrue(options.plannedSteps.contains(.leaveOut))
        XCTAssertFalse(options.plannedSteps.contains(.audioCheck))
        // Kept names change nothing.
        options.choices.names["1.50"] = .keep
        XCTAssertFalse(options.plannedSteps.contains(.leaveOut))
        for step in [PipelineStep.namesSaid, .leaveOut, .audioCheck] {
            XCTAssertFalse(step.title.contains("\u{2014}") || step.doing.contains("\u{2014}"))
            XCTAssertFalse(step.doing.lowercased().contains("processing"))
        }
    }

    func testSomeoneLeftOutWithNoVoicesStopsTheMake() async throws {
        let support = FileManager.default.temporaryDirectory.appending(path: "choices-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: support) }
        var options = PipelineOptions()
        options.people = PeopleSetup(recordingID: UUID(), folders: PeopleFolders(support: support))
        options.choices.set(.leaveOut, for: .voice(2))
        let pipeline = Pipeline(options: options, log: nil)
        do {
            _ = try await pipeline.leaveOut(people: try XCTUnwrap(options.people), staging: support, original: support.appending(path: "none.mov"),
                                            duration: 90, namesSaid: nil, faces: nil, voices: nil)
            XCTFail("someone left out with no voices must stop the make")
        } catch {
            XCTAssertEqual((error as? PipelineFailure)?.step, .leaveOut)
        }
    }

    // MARK: The store, Approve and the notice

    private func model() -> AppModel {
        AppModel(container: AppModel.inMemoryContainer(), paths: AppPaths(mode: .development, home: FileManager.default.temporaryDirectory),
                 settings: .ephemeral(), log: AppLog(directory: nil), now: { Fixtures.now })
    }

    func testAChoiceWaitsForMakeAgainAndApproveWaitsForEveryName() throws {
        let model = model()
        let recording = Recording(filePath: "/tmp/2026-09-13 talk.mp4", foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        let folder = FileManager.default.temporaryDirectory.appending(path: "choices-out-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("x".utf8).write(to: folder.appending(path: "episode.mp3"))
        recording.outputFolder = folder.path
        recording.madeFiles = ["episode.mp3"]
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.now), to: recording)
        XCTAssertFalse(recording.choicesPending, "nothing chosen, nothing made: the same")
        XCTAssertTrue(model.approvalCheck(recording).canApprove)
        XCTAssertEqual(recording.personKeys, [.face(1), .face(2), .voice(2)])
        XCTAssertEqual(recording.label(forVoice: 2), "Voice 2")

        // Leave Voice 2 out: not in the episode until it is made again.
        let before = model.setChoice(.leaveOut, for: .voice(2), in: recording)
        XCTAssertEqual(before, .none)
        XCTAssertTrue(recording.choicesPending)
        XCTAssertFalse(model.approvalCheck(recording).canApprove)
        XCTAssertEqual(model.approvalCheck(recording).line, "Make Again first: your newest choices of who is in the episode, or of names to mute, are not in it yet.")
        // Undo puts it back.
        model.restoreChoices(before, in: recording)
        XCTAssertFalse(recording.choicesPending)
        model.setChoice(.leaveOut, for: .voice(2), in: recording)
        // The make applied it: the same signature.
        let plan = LeaveOut.plan(segments: [VoiceSegment(start: 30, end: 48.5, voice: 2)], leftOut: [2], words: nil, duration: 90)
        var applied = PeopleApplied(madeAt: Fixtures.now, signature: Pipeline.signature(left: [2], muted: []), leaveOut: plan, check: nil)
        recording.peopleAppliedJSON = applied.json()
        XCTAssertFalse(recording.choicesPending)
        XCTAssertTrue(model.approvalCheck(recording).canApprove)
        // The audio output check found someone left out: refused, with the time and the label.
        var check = AudioCheck(checkedAt: Fixtures.now, files: ["episode.mp3"])
        check.findings = [.init(file: "episode.mp3", at: 31.2, seconds: 12, voice: 2, how: "sounds like")]
        applied.check = check
        recording.peopleAppliedJSON = applied.json()
        let refused = model.approvalCheck(recording)
        XCTAssertFalse(refused.canApprove)
        XCTAssertTrue(refused.line?.hasPrefix("Speech at 0:31 in episode.mp3 sounds like Voice 2, whom you chose to leave out.") == true, refused.line ?? "")
        applied.check?.findings = []
        recording.peopleAppliedJSON = applied.json()
        XCTAssertTrue(model.approvalCheck(recording).canApprove)

        // Names said aloud are never asked about at Approve (part LOCK, Ivan 12 Oct): kept unless Ivan chooses Mute.
        let maria = [NameMoment(start: 61.2, end: 61.6, text: "Maria"), NameMoment(start: 75, end: 75.4, text: "Maria")]
        recording.namesSaidJSON = NamesSaid(checkedAt: Fixtures.now, moments: maria).json()
        XCTAssertTrue(model.approvalCheck(recording).canApprove, model.approvalCheck(recording).line ?? "")
        XCTAssertFalse(model.approvalCheck(recording).line?.contains("said aloud") == true)
        model.decideName(.keep, moments: maria, in: recording)
        XCTAssertTrue(model.approvalCheck(recording).canApprove, model.approvalCheck(recording).line ?? "")
        // Muting is a change to the episode: Make Again first.
        model.decideName(.mute, moments: maria, in: recording)
        XCTAssertTrue(recording.choicesPending)
        XCTAssertEqual(recording.podcastSignature, "out:2;mute:61.20,75.00")

        // The receipt lists each person and the names.
        recording.peopleAppliedJSON = PeopleApplied(madeAt: Fixtures.now, signature: recording.podcastSignature,
                                                    leaveOut: LeaveOut.plan(segments: [], leftOut: [], words: nil, mutes: maria, duration: 90), check: nil).json()
        let lines = model.receiptPeople(recording)
        XCTAssertTrue(lines.contains("Voice 2: left out."), "\(lines)")
        XCTAssertTrue(lines.contains("Unnamed 1: seen and heard as recorded."), "\(lines)")
        XCTAssertTrue(lines.contains { $0.hasPrefix("Names said aloud: 0 kept, 2 muted") }, "\(lines)")
        for line in lines { XCTAssertFalse(line.contains("\u{2014}")) }
    }

    func testAChoiceCanBeUndoneAndRedone() {
        let model = model()
        let recording = Recording(filePath: "/tmp/2026-09-13 undo.mp4", foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        model.applyVoices(Fixtures.voicesTwoTracks(at: Fixtures.now), to: recording)
        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        let before = model.setChoice(.leaveOut, for: .voice(2), in: recording)
        registerChoiceUndo(undo, model: model, recording: recording, before: before, name: "Choice")
        undo.endUndoGrouping()
        XCTAssertEqual(recording.choices.choice(.voice(2), for: .podcast), .leaveOut)
        XCTAssertEqual(undo.undoActionName, "Choice")
        undo.undo()
        XCTAssertEqual(recording.choices.choice(.voice(2), for: .podcast), .include, "Undo puts it back")
        undo.redo()
        XCTAssertEqual(recording.choices.choice(.voice(2), for: .podcast), .leaveOut, "Redo makes it again")
    }

    func testTheChangesOfVoiceMustBeHeardWhenSomeoneIsLeftOutOfAMixedTrack() throws {
        let model = model()
        let recording = Recording(filePath: "/tmp/2026-09-13 mixed.mp4", foundAt: Fixtures.now, status: .readyForYourYes, kind: .talk)
        model.context.insert(recording)
        recording.facesJSON = Fixtures.facesTwoPeople(at: Fixtures.now).json()
        var voices = Fixtures.voicesTwoTracks(at: Fixtures.now)
        voices.source = .diarizer
        voices.tracksUsed = []
        voices.voices[0].track = nil
        voices.voices[1].track = nil
        voices.listen = [29.9, 48.5]
        model.applyVoices(voices, to: recording)
        XCTAssertFalse(recording.needsListening, "nobody left out: nothing to listen for")
        model.setChoice(.leaveOut, for: .voice(2), in: recording)
        XCTAssertTrue(recording.needsListening)
        model.setListened(true, in: recording)
        XCTAssertFalse(recording.needsListening)
        // A new voice check asks again.
        voices.checkedAt = Fixtures.now.addingTimeInterval(60)
        model.applyVoices(voices, to: recording)
        XCTAssertTrue(recording.needsListening)
    }

    func testTheNoticeSaysWhatThisBuildDoes() {
        XCTAssertEqual(NoticeBuilder.otherPeopleBody, "Other people appear in this recording. Everyone is in the episode until you choose otherwise.")
        XCTAssertFalse(NoticeBuilder.otherPeopleBody.contains("\u{2014}"))
        XCTAssertFalse(NoticeBuilder.otherPeopleBody.contains("Gabriel"))
    }
}
