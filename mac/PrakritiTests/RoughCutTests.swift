import Foundation
import XCTest
@testable import Prakriti

/// The rough cut and the edit plan (v2 part M8a, docs/v2/PLAN.md M8 check 1): on `ums-and-retake.wav`, where the right
/// answer is known (`make fixtures`, section 4: a false start and "let me start over", an "Um" and an "uh", a stutter
/// "So so", and a parallel pair), and on made-up envelopes for the rules one at a time. The fixture's words are
/// Parakeet's own transcript of it (`Fixtures/ums-and-retake.transcript.json`, made 13 Oct with parakeet-tdt-0.6b-v3 from
/// the fixture whose SHA-256 is `b00b5199...25d2`), so the test reads no recording and runs no model.
final class RoughCutTests: XCTestCase {
    static let wav = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/Fixtures/ums-and-retake.wav")
    static let transcript = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/ums-and-retake.transcript.json")

    /// The fixture's plan, made through `PlanStep.run` as a make makes it, at 29.97 fps so every cut is snapped to a frame.
    static func fixturePlan(file: StaticString = #filePath, line: UInt = #line) async throws -> (plan: EditPlan, words: PlanWords) {
        guard FileManager.default.fileExists(atPath: wav.path) else {
            XCTFail("ums-and-retake.wav is missing: cd ~/Code/prakriti/mac && make fixtures", file: file, line: line)
            throw PlanStep.Failure(reason: "no fixture")
        }
        let job = FileManager.default.temporaryDirectory.appending(path: "roughcut-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: job) }
        let ffmpeg = ToolPaths.standard.ffmpeg
        let setup = PlanStep.Setup(original: wav, transcript: transcript, jobFolder: job, duration: 30, frameRate: 29.97)
        let outcome = try await PlanStep.run(setup, now: Date(timeIntervalSince1970: 0)) { arguments in
            _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(60))
        }
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: transcript)))
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: job.path)) ?? [], [], "the decoded sound is deleted", file: file, line: line)
        return (outcome.plan, words)
    }

    /// Word indices taken out by the plan, with their kind.
    static func removedWords(_ plan: EditPlan) -> [Int: RemovedKind] {
        var out: [Int: RemovedKind] = [:]
        for item in plan.removed {
            guard let ids = item.words, let a = ids.first.flatMap(PlanWord.index(of:)), let b = ids.last.flatMap(PlanWord.index(of:)) else { continue }
            for i in a...b { out[i] = item.kind }
        }
        return out
    }

    func testTheFixtureLosesWhatWasPlantedAndKeepsTheParallelPair() async throws {
        let (plan, words) = try await Self.fixturePlan()
        let all = words.words
        let removed = Self.removedWords(plan)
        let text = { (i: Int) in all[i].norm }
        for item in plan.removed { print("Fixture plan, removed:", item.kind.rawValue, item.from, item.to, item.words ?? [], item.say) }
        for span in plan.spans { print("Fixture plan, kept:", span.id, span.in, span.out, span.text) }

        // Every planted "um" and "uh" is taken out.
        let fillers = all.filter { ["um", "uh"].contains($0.norm) }
        XCTAssertEqual(fillers.count, 2, "Parakeet heard both planted fillers")
        for filler in fillers { XCTAssertEqual(removed[filler.index], .filler, "\(filler.text) at \(filler.start)") }

        // The stutter's first copy is taken out, the second kept.
        let so = all.indices.filter { text($0) == "so" }
        XCTAssertEqual(so.count, 2)
        XCTAssertEqual(removed[so[0]], .stutter)
        XCTAssertNil(removed[so[1]])

        // Everything before "let me start over", and the marker itself, is taken out; the take after it is kept.
        let over = try XCTUnwrap(all.firstIndex { $0.norm == "over" })
        for i in 0...over { XCTAssertEqual(removed[i], .restart, "\(all[i].text) is part of the abandoned take") }
        XCTAssertNil(removed[over + 1], "the restart's kept take begins")
        let restart = try XCTUnwrap(plan.removed.first { $0.kind == .restart })
        XCTAssertEqual(restart.keptTake?.first, all[over + 1].id)

        // The parallel pair is kept whole, and no Check moment is made for it.
        let pair = all.indices.filter { ["slow", "steady"].contains(text($0)) || text($0) == "when" }
        XCTAssertFalse(pair.isEmpty)
        for i in pair { XCTAssertNil(removed[i], "\(all[i].text) is part of the parallel pair") }
        XCTAssertTrue(plan.checks.isEmpty, "\(plan.checks.map(\.say))")

        // Nothing else is taken out but pauses and silence.
        let other = removed.filter { ![.filler, .stutter, .restart].contains($0.value) }
        XCTAssertTrue(other.isEmpty, "\(other)")
        XCTAssertEqual(PlanValidation.check(plan, words: words), [])
    }

    // MARK: The rules one at a time, on made-up words and sound

    /// A transcript.json in Parakeet's shape: sentences of (word, start, end), each word a token with its leading space.
    static func transcript(_ sentences: [[(String, Double, Double)]]) -> Data {
        let objects: [[String: Any]] = sentences.map { words in
            let tokens = words.enumerated().map { n, w in ["text": (n == 0 ? " " : " ") + w.0, "start": w.1, "end": w.2] as [String: Any] }
            return ["text": words.map(\.0).joined(separator: " "), "start": words.first?.1 ?? 0, "end": words.last?.2 ?? 0, "tokens": tokens]
        }
        return try! JSONSerialization.data(withJSONObject: ["text": "", "sentences": objects])
    }

    /// An envelope loud (-20 dBFS) inside the given stretches and room tone (-70) elsewhere, `seconds` long.
    static func envelope(sound: [(Double, Double)], seconds: Double) -> Envelope {
        var levels = [Double](repeating: -70, count: Int((seconds / Envelope.frame).rounded()))
        for (a, b) in sound {
            for i in Int((a / Envelope.frame).rounded())..<min(levels.count, Int((b / Envelope.frame).rounded())) { levels[i] = -20 }
        }
        return Envelope(levels: levels)
    }

    static func cut(_ sentences: [[(String, Double, Double)]], seconds: Double, sound: [(Double, Double)]? = nil, edits: EpisodeEdits = EpisodeEdits(),
                    leftOut: [TimeRange] = []) -> (RoughCut, PlanWords, RoughCut.Input) {
        let words = PlanWords.from(json: transcript(sentences))!
        let env = envelope(sound: sound ?? sentences.flatMap { $0.map { ($0.1, $0.2) } }, seconds: seconds)
        let input = RoughCut.Input(words: words, envelope: env, duration: seconds, frame: .ntsc30, edits: edits, leftOut: leftOut)
        return (RoughCut.make(input), words, input)
    }

    func testWordsHaveStableIdsAndTheirPunctuation() throws {
        let data = Self.transcript([[("Okay.", 1, 1.5)], [("So", 2, 2.2), ("so,", 2.3, 2.5), ("breathe?", 2.6, 3)]])
        let words = try XCTUnwrap(PlanWords.from(json: data))
        XCTAssertEqual(words.words.map(\.id), ["w0", "w1", "w2", "w3"])
        XCTAssertEqual(words.words.map(\.norm), ["okay", "so", "so", "breathe"])
        XCTAssertEqual(words.words.map(\.closes), [.sentence, .none, .clause, .question])
        XCTAssertEqual(words.transcriptSHA256, PlanWords.sha256(data))
        XCTAssertEqual(words.transcriptSHA256.count, 64)
        XCTAssertEqual(PlanWord.index(of: "w12"), 12)
        XCTAssertNil(PlanWord.index(of: "k1"))
    }

    func testTheFloorIsTheRoomAndAClickIsNotSpeech() {
        // 10 s: the room at -70 with 1 s of digital silence (padding), speech at -20 for 6 s, one 10 ms click at -40.
        var levels = [Double](repeating: -70, count: 1000)
        for i in 0..<100 { levels[i] = Envelope.lowest }
        for i in 200..<800 { levels[i] = -20 }
        levels[900] = -40
        let env = Envelope(levels: levels)
        XCTAssertEqual(env.floor, -70, "digital silence is left out of the floor")
        XCTAssertEqual(env.speech, -20)
        XCTAssertTrue(env.isActive(at: 5))
        XCTAssertFalse(env.isActive(at: 9.005), "a 10 ms click is not speech")
        XCTAssertTrue(env.isQuiet(around: 8.5))
        XCTAssertFalse(env.isQuiet(around: 2.0))
    }

    func testPausesAreShortenedToTheirTargetAndNeverRemoved() throws {
        // "One two. Three four five": a 2.0 s pause after the full stop, a 1.0 s pause inside the sentence, and a 0.3 s one.
        let (cut, words, input) = Self.cut([[("One", 1.0, 1.4), ("two.", 1.5, 2.0)], [("Three", 4.0, 4.4), ("four", 5.4, 5.8), ("five", 6.1, 6.5)]], seconds: 8)
        let pauses = Dictionary(cut.pauses.map { ($0.after, $0) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(try XCTUnwrap(pauses[1]).now, 0.35, accuracy: 0.034, "after a full stop: 0.35 s, within a frame")
        XCTAssertEqual(try XCTUnwrap(pauses[2]).now, 0.18, accuracy: 0.034, "inside a sentence: 0.18 s, within a frame")
        XCTAssertEqual(try XCTUnwrap(pauses[3]).now, 0.3, accuracy: 0.001, "under the trigger: untouched")
        for removal in cut.removed {
            XCTAssertTrue(FrameDuration.ntsc30.isBoundary(removal.from) || removal.from == 0)
            XCTAssertTrue(FrameDuration.ntsc30.isBoundary(removal.to) || removal.to == 8)
            XCTAssertTrue(input.envelope.isQuiet(around: removal.from) || removal.from == 0)
        }
        // Before the first word 0.5 s stays, after the last 1.0 s.
        let plan = EditPlan.from(cut, words: words, input: input, recording: "test", people: .init(), signature: "", madeAt: Date())
        XCTAssertEqual(try XCTUnwrap(plan.spans.first).in, 0.5, accuracy: 0.034)
        XCTAssertEqual(try XCTUnwrap(plan.spans.last).out, 7.5, accuracy: 0.034)
        XCTAssertEqual(PlanValidation.check(plan, words: words), [])
    }

    func testAGapWithSoundButNoWordsIsNeverCutAsAPause() throws {
        // "One two." then 17 s Parakeet wrote no word for, though 12 s of it is speech (as on 6 Sep at 24:22), with a 3 s
        // silence inside it, then "Three four.". Only quiet time may go: the speech stays and only the inner silence shortens.
        let speech: [(Double, Double)] = [(1.0, 1.4), (1.5, 2.0), (2.5, 8.5), (11.5, 17.5), (19.0, 19.4), (19.5, 20.0)]
        let (cut, words, input) = Self.cut([[("One", 1.0, 1.4), ("two.", 1.5, 2.0)], [("Three", 19.0, 19.4), ("four.", 19.5, 20.0)]],
                                       seconds: 22, sound: speech)
        for removal in cut.removed where removal.kind == .pause {
            let loud = RoughCut.LoudCount(envelope: input.envelope, from: removal.from, to: removal.to).seconds(removal.from, removal.to)
            XCTAssertLessThanOrEqual(loud, RoughCut.soundAllowed, "a pause from \(removal.from) to \(removal.to) took out \(loud) s of sound")
            XCTAssertFalse(speech.contains { removal.from < $0.1 && removal.to > $0.0 }, "a pause took out speech: \(removal.from) to \(removal.to)")
        }
        let pauses = cut.removed.filter { $0.kind == .pause }
        // One removal per gap, its longest quiet stretch: two would leave a kept piece with no word, which a plan cannot hold.
        XCTAssertEqual(pauses.count, 1, "\(pauses.map { ($0.from, $0.to) })")
        XCTAssertTrue(pauses.contains { $0.from >= 8.5 && $0.to <= 11.5 && $0.to - $0.from > 2.0 }, "the 3 s silence inside the gap")
        let plan = EditPlan.from(cut, words: words, input: input, recording: "test", people: .init(), signature: "", madeAt: Date())
        XCTAssertEqual(PlanValidation.check(plan, words: words), [])
        XCTAssertEqual(plan.keptSeconds, plan.sourceDuration - cut.removed.reduce(0) { $0 + $1.to - $1.from }, accuracy: 0.034,
                       "every second not taken out by a listed removal is in a span")
        // Sound before the first word Parakeet wrote is not trimmed either.
        let (lead, _, _) = Self.cut([[("Three", 6.0, 6.4), ("four.", 6.5, 7.0)]], seconds: 9, sound: [(0.5, 4.0), (6.0, 6.4), (6.5, 7.0)])
        XCTAssertFalse(lead.removed.contains { $0.kind == .trimmed && $0.from < 4.0 && $0.to > 0.5 }, "speech before the first word is kept")
    }

    func testAPauseAfterABreathCueOrAQuestionIsKept() throws {
        let (cut, _, _) = Self.cut([[("Now", 1.0, 1.3), ("inhale.", 1.4, 1.9)], [("Can", 4.9, 5.1), ("you", 5.2, 5.4), ("feel", 5.5, 5.8), ("it?", 5.9, 6.2)],
                                    [("Good.", 8.2, 8.6)]], seconds: 10)
        XCTAssertEqual(cut.pauses.first { $0.after == 1 }?.now ?? 0, 3.0, accuracy: 0.001, "3 s after \"inhale\" is kept whole")
        XCTAssertTrue(cut.pauses.first { $0.after == 1 }?.protected ?? false)
        XCTAssertEqual(cut.pauses.first { $0.after == 5 }?.now ?? 0, 2.0, accuracy: 0.001, "2 s after a question is kept whole")
        let long = Self.cut([[("Close", 1.0, 1.3), ("your", 1.4, 1.6), ("eyes.", 1.7, 2.0)], [("Good.", 9.0, 9.5)]], seconds: 11).0
        XCTAssertEqual(long.pauses.first { $0.after == 2 }?.now ?? 0, 4.0, accuracy: 0.034, "7 s after a cue becomes the 4 s limit")
    }

    func testAFillerIsKeptWhenItCannotBeCutCleanly() throws {
        // "breath um every", the um run into both words with no quiet on either side: kept. The same with quiet around: cut.
        let joined = Self.cut([[("the", 1.0, 1.2), ("breath,", 1.2, 1.6), ("um,", 1.6, 1.9), ("every", 1.9, 2.3), ("day.", 2.3, 2.7)]], seconds: 4,
                              sound: [(1.0, 2.7)]).0
        XCTAssertFalse(joined.removed.contains { $0.kind == .filler }, "no quiet around the um: kept")
        XCTAssertEqual(joined.keptAnyway.map(\.kind), [.filler])
        let apart = Self.cut([[("the", 1.0, 1.2), ("breath,", 1.2, 1.6), ("um,", 1.9, 2.2), ("every", 2.5, 2.9), ("day.", 2.9, 3.3)]], seconds: 4).0
        let filler = try XCTUnwrap(apart.removed.first { $0.kind == .filler })
        XCTAssertEqual(filler.words, 2...2)
        XCTAssertLessThan(filler.from, 1.9)
        XCTAssertGreaterThan(filler.to, 2.2)
        XCTAssertTrue(filler.clean)
    }

    func testIvansCutsAndThePeopleLeftOutAreNeverKept() throws {
        // A cut from 3.05 s to 3.6 s runs into "three", and someone left out speaks 5.0 to 5.6 s over "five": both words go
        // whole, and the plan passes rule 5.
        let sentences = [[("One", 1.0, 1.3), ("two", 1.6, 1.9), ("three", 3.0, 3.4), ("four", 4.0, 4.3), ("five", 5.0, 5.5), ("six.", 6.0, 6.4)]]
        let edits = EpisodeEdits(start: nil, end: nil, cuts: [TimeRange(start: 3.05, end: 3.6)])
        let (cut, words, input) = Self.cut(sentences, seconds: 8, edits: edits, leftOut: [TimeRange(start: 5.0, end: 5.6)])
        XCTAssertEqual(cut.removed.first { $0.kind == .cut }?.words, 2...2)
        XCTAssertEqual(cut.removed.first { $0.kind == .person }?.words, 4...4)
        let plan = EditPlan.from(cut, words: words, input: input, recording: "test",
                                 people: EditPlan.People(applied: "out:2;mute:", leftOut: [2], cuts: [TimeRange(start: 5.0, end: 5.6)]),
                                 signature: "out:2;mute:", madeAt: Date())
        XCTAssertEqual(PlanValidation.check(plan, words: words), [])
        XCTAssertFalse(plan.spans.contains { $0.text.contains("three") || $0.text.contains("five") })
    }

    func testSentenceRestartsAndTheParallelGuard() {
        func words(_ sentences: [String]) -> [PlanWord] {
            var t = 0.0
            return PlanWords.from(json: Self.transcript(sentences.map { sentence in
                sentence.split(separator: " ").map { w in t += 0.4; return (String(w), t, t + 0.3) }
            }))!.words
        }
        // Abandoned (no closing punctuation, much shorter): a restart.
        let restart = Restarts.sentenceRestarts(words(["The first thing I", "The first thing I want to say is that the breath comes first."]))
        XCTAssertEqual(restart.proposals.map(\.kind), [.restart])
        XCTAssertEqual(restart.proposals.first.map { $0.first...$0.last }, 0...3)
        // Parallel phrasing, both complete, different remainders: kept, no Check.
        let parallel = Restarts.sentenceRestarts(words(["Some people can't afford a massage.", "Some people can't afford to join a yoga studio."]))
        XCTAssertTrue(parallel.proposals.isEmpty)
        XCTAssertTrue(parallel.checks.isEmpty)
        // Complete and nearly the same: kept, and a Check moment.
        let retake = Restarts.sentenceRestarts(words(["The breath leads the body.", "The breath leads the whole body."]))
        XCTAssertTrue(retake.proposals.isEmpty)
        XCTAssertEqual(retake.checks.map(\.kind), [.possibleRetake])
        XCTAssertTrue(retake.checks.first?.say.hasPrefix("Possible retake at 0:00") ?? false)
        // A weak marker a teacher says to a room is a Check, never a cut.
        let weak = Restarts.markers(words(["Let's do that one more time.", "Arms up."]))
        XCTAssertTrue(weak.proposals.isEmpty)
        XCTAssertEqual(weak.checks.map(\.kind), [.possibleRestart])
    }

    func testValidationRefusesABadPlan() throws {
        let (cut, words, input) = Self.cut([[("One", 1.0, 1.3), ("two.", 1.5, 1.9)], [("Three", 4.0, 4.4), ("four.", 4.6, 5.0)]], seconds: 7)
        let good = EditPlan.from(cut, words: words, input: input, recording: "test", people: .init(), signature: "", madeAt: Date())
        XCTAssertEqual(PlanValidation.check(good, words: words), [])
        var text = good
        text.spans[0].text = "One too."
        XCTAssertEqual(PlanValidation.check(text, words: words).map(\.rule), [2])
        var hash = good
        hash.transcriptSHA256 = String(repeating: "0", count: 64)
        XCTAssertEqual(PlanValidation.check(hash, words: words).first?.rule, 1)
        var unknown = good
        unknown.spans[0].to = "w99"
        XCTAssertEqual(PlanValidation.check(unknown, words: words).first?.rule, 1)
        var offFrame = good
        offFrame.spans[0].in += 0.01
        XCTAssertTrue(PlanValidation.check(offFrame, words: words).contains { $0.rule == 3 })
        var person = good
        person.people.cuts = [TimeRange(start: 4.0, end: 4.4)]
        XCTAssertEqual(PlanValidation.check(person, words: words).map(\.rule), [5], "someone left out must not be kept")
        var chapters = good
        chapters.chapters = [EditPlan.Chapter(title: "Only", at: "w0")]
        XCTAssertEqual(PlanValidation.check(chapters, words: words).map(\.rule), [6])
        // The plan round-trips through its file.
        let decoded = try XCTUnwrap(EditPlan.decode(try good.encoded()))
        XCTAssertEqual(decoded.spans, good.spans)
        XCTAssertEqual(decoded.frameDuration, .ntsc30)
        XCTAssertEqual(String(data: try good.encoded(), encoding: .utf8)?.contains("\"frameDuration\" : \"1001/30000\""), true)
        XCTAssertEqual(String(data: try good.encoded(), encoding: .utf8)?.contains("\"schema\" : \"prakriti.editplan/1\""), true)
    }
}
