import CoreGraphics
import Foundation
import XCTest
@testable import Prakriti

/// v2 part M9d (docs/v2/PLAN.md M9): the opening line, key phrases, term cards, chapters, the held moment, the count of every
/// visual change, the plan's own check of them, and versions. Everything here is made up (a synthetic talk of numbered words, a
/// synthetic sound, made-up faces and beats); nothing is read from a recording.
final class HookTests: XCTestCase {
    // MARK: A made-up talk with real pauses

    /// A made-up talk: 10 words a sentence, a word every 0.4 s (0.3 s long), 0.5 s more between sentences; kept in spans of two
    /// sentences with the third sentence's first word taken out between them (a jump cut). 1080p at 29.97.
    static func talk(minutes: Double = 10) -> (plan: EditPlan, words: [PlanWord], envelope: Envelope) {
        let frame = FrameDuration.ntsc30
        var words: [PlanWord] = []
        var t = 0.5
        var i = 0
        while t < minutes * 60 {
            let sentence = i / 10
            let last = i % 10 == 9
            words.append(PlanWord(index: i, text: last ? "word\(i)." : "word\(i)", norm: "word\(i)", start: t, end: t + 0.3, sentence: sentence,
                                  closes: last ? .sentence : .none))
            t += last ? 0.9 : 0.4
            i += 1
        }
        func snap(_ x: Double) -> Double { (x / frame.seconds).rounded() * frame.seconds }
        var spans: [EditPlan.Span] = []
        var a = 0
        while a < words.count - 1 {
            let b = min(words.count - 1, a + 18)
            spans.append(.init(id: "k\(spans.count + 1)", source: "synthetic", from: words[a].id, to: words[b].id,
                               in: snap(words[a].start - 0.04), out: snap(words[b].end + 0.04), text: PlanWords.text(words[a...b])))
            a = b + 2
        }
        let duration = t + 1
        var plan = EditPlan(recording: "synthetic", transcriptSHA256: "synthetic", frameDuration: frame, style: "clear", madeAt: Date(timeIntervalSince1970: 0),
                            sourceDuration: duration, envelope: .init(floorDB: -70, speechDB: -20), basis: .init(edits: EpisodeEdits(), peopleSignature: ""))
        plan.spans = spans
        plan.words = words.map { EditPlan.WordTime(id: $0.id, in: $0.start, out: $0.end) }
        // Words taken out between spans, so the plan's words add up (rule 3).
        let kept = Set(spans.flatMap { s in (PlanWord.index(of: s.from)!...PlanWord.index(of: s.to)!).map { $0 } })
        plan.removed = words.indices.filter { !kept.contains($0) }.map { k in
            EditPlan.Item(kind: .filler, from: spans.last { $0.out <= words[k].start }?.out ?? 0, to: spans.first { $0.in >= words[k].end }?.in ?? duration,
                          words: [words[k].id], confidence: 1, say: "")
        }
        var levels = [Double](repeating: -70, count: Int(duration / Envelope.frame) + 1)
        for w in words {
            for f in Int(w.start / Envelope.frame)..<min(levels.count, Int(w.end / Envelope.frame)) { levels[f] = -20 }
        }
        return (plan, words, Envelope(levels: levels))
    }

    static func beats(_ words: [PlanWord], every: Int = 60) -> [Beat] {
        let sentences = BeatSentence.from(words)
        var out: [Beat] = []
        var s = 0
        var n = 1
        while s < sentences.count {
            let e = min(sentences.count - 1, s + 11)
            let first = sentences[s], last = sentences[e]
            let long = first.first + 18 <= last.last
            let keyFrom = words[min(first.first + 12, last.last)], keyTo = words[min(first.first + 18, last.last)]
            let phraseFrom = words[min(first.first + 13, last.last)], phraseTo = words[min(first.first + 16, last.last)]
            out.append(Beat(id: "b\(n)", firstSentence: first.id, lastSentence: last.id, from: words[first.first].id, to: words[last.last].id,
                            start: words[first.first].start, end: words[last.last].end, summary: "part number \(n)",
                            scores: ["motivating": n % 3, "enlightening": n % 2 == 0 ? 3 : 1], kind: .teaching, standsAlone: true, dependsOn: [],
                            keyLine: long ? .init(from: keyFrom.id, to: keyTo.id, text: PlanWords.text(words[keyFrom.index...keyTo.index])) : nil,
                            keyPhrase: long ? .init(from: phraseFrom.id, to: phraseTo.id, text: PlanWords.text(words[phraseFrom.index...phraseTo.index])) : nil,
                            hookCandidate: n == 4, terms: n == 3 ? ["Prāṇāyāma"] : [], thesis: n == 5))
            s = e + 1
            n += 1
        }
        return out
    }

    // MARK: The opening line

    func testTheOpeningLineIsWholeSentencesTheTalkKeepsAndComesFirst() throws {
        let (plan, words, envelope) = Self.talk()
        let beats = Self.beats(words)
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let hook = try XCTUnwrap(Hook.choose(.init(spans: plan.spans, times: times, words: words, envelope: envelope, frame: plan.frameDuration, beats: beats,
                                                     range: 5...15)))
        XCTAssertEqual(hook.beat, "b4", "the beat the model marked")
        XCTAssertTrue((5...15).contains(hook.seconds), "\(hook.seconds) s")
        var made = plan
        made.spans = hook.spans + plan.spans
        // Whole sentences, from a sentence's first word to a sentence's last.
        let first = try XCTUnwrap(PlanWord.index(of: hook.spans.first!.from)), last = try XCTUnwrap(PlanWord.index(of: hook.spans.last!.to))
        XCTAssertTrue(first == 0 || words[first - 1].endsSentence, "starts a sentence")
        XCTAssertTrue(words[last].endsSentence, "ends a sentence")
        for span in hook.spans {
            XCTAssertTrue(plan.spans.contains { $0.in <= span.in + 1e-6 && $0.out >= span.out - 1e-6 }, "\(span.id) is time the talk keeps")
            XCTAssertTrue(plan.frameDuration.isBoundary(span.in) && plan.frameDuration.isBoundary(span.out), "on frames")
            XCTAssertTrue(envelope.isQuiet(around: span.in) && envelope.isQuiet(around: span.out), "cut in quiet: \(span.in) \(span.out)")
        }
        let problems = PlanValidation.check(made, words: PlanWords(words: words, transcriptSHA256: "synthetic", sentences: words.last!.sentence + 1))
        XCTAssertEqual(problems, [], "\(problems)")
        // On the video's clock: the opening line first, then the talk from its start; a moment it repeats is found in the talk.
        let timeline = EditTimeline(plan: made)
        XCTAssertEqual(timeline.pieces.first?.hook, true)
        XCTAssertEqual(timeline.hookFrames, timeline.pieces.prefix { $0.hook }.reduce(0) { $0 + $1.frames })
        let said = words[first].start + 0.1
        let inTalk = try XCTUnwrap(timeline.editTime(said))
        XCTAssertGreaterThan(inTalk, timeline.seconds(timeline.hookFrames), "the talk's own place, not the opening line's")
        XCTAssertLessThan(try XCTUnwrap(timeline.editTime(said, span: hook.spans[0].id)), timeline.seconds(timeline.hookFrames))
        // The captions say the opening line first, then the talk from its start.
        let caption = Captions.words(plan: made, words: PlanWords(words: words, transcriptSHA256: "synthetic", sentences: 1), timeline: timeline)
        XCTAssertEqual(caption.first?.text, words[first].text)
        XCTAssertEqual(caption.first?.start ?? -1, 0, accuracy: 0.2)
        XCTAssertTrue(caption.contains { $0.text == words[0].text })
        // A line in the first 30 s is never used; a candidate too long for the range is not either.
        var early = beats
        for k in early.indices { early[k].hookCandidate = k == 0; early[k].thesis = false }
        XCTAssertNil(Hook.choose(.init(spans: plan.spans, times: times, words: words, envelope: envelope, frame: plan.frameDuration, beats: early, range: 5...15)))
        XCTAssertNil(Hook.choose(.init(spans: plan.spans, times: times, words: words, envelope: envelope, frame: plan.frameDuration, beats: beats, range: 1...2)))
    }

    func testTheCheckRefusesAnOpeningLineOutsideTheTalk() throws {
        let (plan, words, _) = Self.talk(minutes: 3)
        let all = PlanWords(words: words, transcriptSHA256: "synthetic", sentences: 1)
        var bad = plan
        let span = plan.spans[3]
        bad.spans = [EditPlan.Span(id: "h1", source: "synthetic", from: span.from, to: span.to, in: span.in, out: span.out + 2, role: EditPlan.Span.hook, text: span.text)]
            + plan.spans
        XCTAssertTrue(PlanValidation.check(bad, words: all).contains { $0.rule == 4 || $0.rule == 3 }, "time the talk does not keep")
        var late = plan
        late.spans = plan.spans + [EditPlan.Span(id: "h1", source: "synthetic", from: span.from, to: span.to, in: span.in, out: span.out, role: EditPlan.Span.hook,
                                                 text: span.text)]
        XCTAssertTrue(PlanValidation.check(late, words: all).contains { $0.rule == 4 }, "not at the start")
    }

    // MARK: Key phrases and terms

    func testKeyPhrasesAreTheSpeakersWordsSpacedAndClearOfFaces() throws {
        let (base, words, envelope) = Self.talk()
        var plan = base
        let beats = Self.beats(words)
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if let hook = Hook.choose(.init(spans: plan.spans, times: times, words: words, envelope: envelope, frame: plan.frameDuration, beats: beats, range: 5...15)) {
            plan.spans = hook.spans + plan.spans
        }
        let face = StyleTests.face(x: 0.62)
        plan.visual = VisualPlan.make(.init(plan: plan, words: words, style: Style.make(.standard), subject: face, sourceHeight: 1080, outputHeight: 1080))
        var setup = TextPlan.Setup(title: "A test title", faces: face, pictureWidth: 1920)
        setup.keyPhraseEvery = 60...90
        setup.keyPhrases = PlanStep.keyPhrases(beats, words: words, refined: times)
        setup.terms = PlanStep.terms(beats, words: words, refined: times)
        let items = TextPlan.make(plan: plan, setup: setup, pictureHeight: 1080)
        plan.visual += items
        let timeline = EditTimeline(plan: plan)
        let phrases = items.filter { $0.kind == EditPlan.Visual.keyPhrase }
        XCTAssertGreaterThanOrEqual(phrases.count, 5, "about one a minute and a half over 10 minutes")
        XCTAssertLessThanOrEqual(phrases.count, Int(timeline.duration / 60) + 1)
        let starts = phrases.compactMap { timeline.editFrame(span: $0.span, original: $0.in ?? -1) }.sorted()
        for (a, b) in zip(starts, starts.dropFirst()) {
            XCTAssertGreaterThanOrEqual(timeline.seconds(b - a), 60 - 1e-6, "at most one per 60 s")
        }
        for item in phrases {
            let ids = try XCTUnwrap(item.words)
            let said = PlanWords.text(words[PlanWord.index(of: ids[0])!...PlanWord.index(of: ids[1])!])
            XCTAssertTrue(PlanValidation.sameWords(item.lines!.joined(separator: " "), said), "\(item.lines!) is what was said: \(said)")
            XCTAssertEqual(item.lines?.count, 1, "one line")
            let box = CGRect(x: item.box![0], y: item.box![1], width: item.box![2], height: item.box![3])
            XCTAssertLessThan(box.maxX, 0.62, "on the side away from the face (the face is at 0.62 to 0.78)")
            XCTAssertGreaterThanOrEqual(timeline.editFrame(span: item.span, original: item.in!)!, timeline.hookFrames, "never over the opening line")
        }
        // The title after the opening line.
        let title = try XCTUnwrap(items.first { $0.kind == EditPlan.Visual.title })
        XCTAssertEqual(timeline.editFrame(span: title.span, original: title.in!), timeline.hookFrames)
        // The term, spelled as the word list spells it, only because the list holds it and it is said.
        XCTAssertEqual(Lexicon.term("Prāṇāyāma"), "pranayama")
        XCTAssertNil(Lexicon.term("abhyasa"), "a term the list does not hold is never shown")
        XCTAssertTrue(setup.terms.isEmpty, "the synthetic talk never says pranayama, so no card")
        let problems = PlanValidation.check(plan, words: PlanWords(words: words, transcriptSHA256: "synthetic", sentences: 1))
        XCTAssertEqual(problems, [], "\(problems)")
        // Every text in counts as a change of the picture, unless it comes in with a cut.
        let count = VisualPlan.count(plan)
        XCTAssertEqual(count.changes, count.pictureChanges + count.textIns)
        XCTAssertGreaterThan(count.textIns, 0)
        // A key phrase whose words are not the words said there is refused.
        var wrong = plan
        if let k = wrong.visual.firstIndex(where: { $0.kind == EditPlan.Visual.keyPhrase }) { wrong.visual[k].lines = ["words nobody said"] }
        XCTAssertTrue(PlanValidation.check(wrong, words: PlanWords(words: words, transcriptSHA256: "synthetic", sentences: 1)).contains { $0.rule == 4 })
    }

    func testATermIsFoundWhereItIsSaidAndSpelledFromTheList() {
        let words = [PlanWord(index: 0, text: "The", norm: "the", start: 1, end: 1.2, sentence: 0, closes: .none),
                     PlanWord(index: 1, text: "pranayama,", norm: "pranayama", start: 1.3, end: 1.9, sentence: 0, closes: .clause),
                     PlanWord(index: 2, text: "breath.", norm: "breath", start: 2.0, end: 2.4, sentence: 0, closes: .sentence)]
        let beat = Beat(id: "b1", firstSentence: "s1", lastSentence: "s1", from: "w0", to: "w2", start: 1, end: 2.4, summary: "breath", scores: [:], kind: .teaching,
                        standsAlone: true, dependsOn: [], keyLine: nil, hookCandidate: false, terms: ["Prāṇāyāma", "abhyasa"], thesis: true)
        let terms = PlanStep.terms([beat], words: words, refined: [:])
        XCTAssertEqual(terms.map(\.text), ["Pranayama"])
        XCTAssertEqual(terms.first?.from, "w1")
        XCTAssertTrue(PlanValidation.sameWords("Pranayama", "pranayama,"))
    }

    // MARK: Chapters

    func testChaptersStartAtZeroAreLongEnoughAndGoInTheDescription() throws {
        let (base, words, envelope) = Self.talk()
        var plan = base
        let beats = Self.beats(words)
        let times = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if let hook = Hook.choose(.init(spans: plan.spans, times: times, words: words, envelope: envelope, frame: plan.frameDuration, beats: beats, range: 5...15)) {
            plan.spans = hook.spans + plan.spans
        }
        plan.chapters = Chapters.make(plan: plan, beats: beats, words: words)
        XCTAssertGreaterThanOrEqual(plan.chapters.count, 3)
        XCTAssertEqual(plan.chapters.first?.seconds, 0)
        let seconds = plan.chapters.compactMap(\.seconds)
        for (a, b) in zip(seconds, seconds.dropFirst()) { XCTAssertGreaterThanOrEqual(b - a, Chapters.shortest - 1e-6) }
        XCTAssertEqual(plan.chapters.first?.title, "Part number 1")
        XCTAssertEqual(PlanValidation.check(plan, words: PlanWords(words: words, transcriptSHA256: "synthetic", sentences: 1)), [])
        let timeline = EditTimeline(plan: plan)
        let description = VideoDescription.make(title: "", notes: "", written: nil, toOriginal: { $0 }, timeline: timeline, planChapters: plan.chapters)
        XCTAssertEqual(description.chapters.count, plan.chapters.count)
        XCTAssertNil(description.chapterProblem)
        XCTAssertTrue(description.text.contains("0:00 Part number 1"), description.text)
        // Two chapters are none: YouTube needs three.
        XCTAssertTrue(Chapters.make(plan: plan, beats: Array(beats.prefix(2)), words: words).isEmpty)
        XCTAssertEqual(Chapters.title("price of the course"), "", "Ivan's copy rules keep money out of a title")
    }

    // MARK: The held moment

    func testTheHeldMomentIsWholeSentencesOfTheMainPointAndStaysStill() throws {
        let (base, words, _) = Self.talk()
        let beats = Self.beats(words)
        let starts = words.map(\.start), ends = words.map(\.end)
        let held = try XCTUnwrap(HeldMoment.choose(beats: beats, kept: Set(beats.map(\.id)), words: words, starts: starts, ends: ends, range: 30...60, forced: []))
        XCTAssertTrue((30...60).contains(held.end - held.start), "\(held.end - held.start) s")
        let thesis = try XCTUnwrap(beats.first(where: \.thesis))
        XCTAssertGreaterThanOrEqual(held.start, thesis.start - 1e-6)
        XCTAssertNil(HeldMoment.choose(beats: beats, kept: Set(beats.map(\.id)), words: words, starts: starts, ends: ends, range: 30...60,
                                       forced: [TimeRange(start: thesis.start, end: thesis.end)]), "never where something is cut")
        // One span holds it (as the rough cut keeps it uncut), and the picture is one wide shot over it.
        var plan = base
        let a = try XCTUnwrap(words.firstIndex { $0.start >= held.start - 1e-6 }), b = try XCTUnwrap(words.lastIndex { $0.end <= held.end + 1e-6 })
        let frame = plan.frameDuration
        func snap(_ x: Double) -> Double { (x / frame.seconds).rounded() * frame.seconds }
        plan.spans = plan.spans.filter { s in PlanWord.index(of: s.to)! < a - 1 || PlanWord.index(of: s.from)! > b + 1 }
        plan.spans.append(EditPlan.Span(id: "kheld", source: "synthetic", from: words[a].id, to: words[b].id, in: snap(words[a].start - 0.04), out: snap(words[b].end + 0.04),
                                        text: PlanWords.text(words[a...b])))
        plan.spans.sort { $0.in < $1.in }
        plan.held = held
        plan.visual = VisualPlan.make(.init(plan: plan, words: words, style: Style.make(.standard), subject: StyleTests.face(), sourceHeight: 1080, outputHeight: 1080,
                                            held: held))
        let timeline = EditTimeline(plan: plan)
        let fs = plan.frameDuration.seconds
        let over = VisualPlan.shots(plan, timeline: timeline).filter { s in
            let x = Double(s.sourceFrame) * fs, y = x + Double(s.frames) * fs
            return y > held.start + 0.5 && x < held.end - 0.5
        }
        XCTAssertEqual(over.count, 1, "one shot over the held moment")
        XCTAssertEqual(over.first?.scale, 1, "wide")
        XCTAssertFalse(plan.visual.contains { $0.kind == EditPlan.Visual.pushIn && ($0.in ?? 0) < held.end && ($0.out ?? 0) > held.start }, "no push-in")
    }

    // MARK: The overlay of a key phrase

    func testAKeyPhraseComesInWordByWord() throws {
        XCTAssertTrue(TypeFace.register())
        let line = OverlayLine(text: "the breath comes first", font: TypeFace.bold, size: 64)
        let edges = OverlayLayout.wordEdges(line, scale: 1)
        XCTAssertEqual(edges.count, 4)
        XCTAssertEqual(edges, edges.sorted(), "left to right")
        let width = OverlayLayout.width(line.text, font: try XCTUnwrap(TypeFace.font(TypeFace.bold, size: 64)))
        XCTAssertEqual(try XCTUnwrap(edges.last), width, accuracy: 0.5)
        // 2 to 6 words held 1.5 to 3 s after they are in.
        XCTAssertEqual(OverlayKind.keyPhraseSeconds(words: 4, spoken: 1), 0.07 * 3 + 0.3 + 1.8 + 0.2, accuracy: 1e-9)
        XCTAssertEqual(OverlayKind.keyPhraseSeconds(words: 2, spoken: 0.1), 0.07 + 0.3 + 1.5 + 0.2, accuracy: 1e-9)
        XCTAssertEqual(OverlayKind.keyPhraseSeconds(words: 6, spoken: 9), 0.07 * 5 + 0.3 + 3 + 0.2, accuracy: 1e-9)
    }

    /// A close stands on its own and nothing depends on housekeeping, so the links cannot chain the whole talk together.
    func testTheLinksThatChainATalkAreLoosened() {
        var beats = [StyleTests.beat(1, 60, at: 0), StyleTests.beat(2, 60, at: 60, kind: .housekeeping, depends: [1]),
                     StyleTests.beat(3, 60, at: 120, depends: [1, 2]), StyleTests.beat(4, 60, at: 180, kind: .closing, depends: [3])]
        XCTAssertEqual(BeatCheck.loosen(&beats), 2)
        XCTAssertEqual(beats.map(\.dependsOn), [[], ["b1"], ["b1"], []])
    }

    /// Under 85% of the length asked for, a long part comes in for shorter, weaker ones when that reaches the length.
    func testTheSelectionFillsTowardTheLength() {
        let beats = [StyleTests.beat(1, 60, at: 0, scores: [.enlightening: 3], thesis: true), StyleTests.beat(2, 60, at: 60, scores: [.motivating: 2]),
                     StyleTests.beat(3, 60, at: 120, scores: [.motivating: 2]), StyleTests.beat(4, 200, at: 180, scores: [.motivating: 2]),
                     StyleTests.beat(5, 30, at: 380, kind: .closing)]
        let kept = Dictionary(uniqueKeysWithValues: beats.map { ($0.id, $0.seconds) })
        let outcome = Selection.choose(.init(beats: beats, keptSeconds: kept, budget: 300, fields: DirectionFields(focus: ["motivating": 1.5])))
        XCTAssertTrue(outcome.kept.contains("b4"), "\(outcome.kept)")
        XCTAssertGreaterThanOrEqual(outcome.keptSeconds, 0.85 * 300)
        XCTAssertLessThanOrEqual(outcome.keptSeconds, 300)
        XCTAssertTrue(outcome.kept.contains("b1") && outcome.kept.contains("b5"), "the thesis and the close stay")
    }

    /// The beats answer's room grows with the talk (the 6 Sep talk was cut off at 16,384 tokens, 15 Oct).
    func testTheBeatsAnswerHasRoomForALongTalk() {
        XCTAssertEqual(Planner.beatsTokens(sentences: 50), ModelSettings.maxTokens)
        XCTAssertEqual(Planner.beatsTokens(sentences: 137), 17_480)
        XCTAssertEqual(Planner.beatsTokens(sentences: 565), 34_600)
        XCTAssertEqual(Planner.beatsTokens(sentences: 5_000), 40_000)
        let words = (0..<1_000).map { PlanWord(index: $0, text: $0 % 2 == 1 ? "word." : "word", norm: "word", start: Double($0), end: Double($0) + 0.5, sentence: $0 / 2,
                                               closes: $0 % 2 == 1 ? .sentence : .none) }
        XCTAssertEqual(Planner.beatsRequest(words, kind: .talk, duration: 1_000).maxTokens, 32_000)
    }
}

/// Versions (v2 part M9d): each video made is kept, Use This Version puts one back where Approve finds it, Play plays one from its
/// own folder, and Approve names the version it covers. Made-up files only, in a scratch home.
@MainActor
final class VersionTests: XCTestCase {
    func testEveryVideoIsKeptAndOneCanBeUsedAgain() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "versions-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = AppPaths(mode: .development, home: home)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: home.appending(path: "logs")),
                             now: Date.init)
        let output = paths.outputs.appending(path: "2026-09-13 18-25-44", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: output.appending(path: VideoStep.folderName), withIntermediateDirectories: true)
        let recording = Recording(filePath: "/tmp/2026-09-13 18-25-44.mp4", foundAt: Date())
        model.context.insert(recording)
        recording.outputFolder = output.path
        recording.madeFiles = [VideoStep.folderName, EditPlan.fileName]
        recording.status = .readyForYourYes

        func make(_ marker: String, style: String, prompt: String?, at: Date) throws -> VideoRecord {
            try Data(marker.utf8).write(to: output.appending(path: VideoStep.folderName).appending(path: "talk.mp4"))
            var plan = HookTests.talk(minutes: 1).plan
            plan.style = style
            plan.madeAt = at
            if let prompt { plan.direction = EditPlan.Direction(prompt: prompt, chips: ["Style: Energetic"], presets: [.energetic]) }
            try PlanStep.write(plan, into: output)
            let video = VideoRecord(fileName: "talk.mp4", captionsName: "talk.srt", duration: marker == "A" ? 600 : 420, bytes: 1, frames: 1, renderSeconds: 1,
                                    checklist: [], madeAt: at, planSummary: plan.summary, peopleSignature: "", planMadeAt: plan.madeAt)
            recording.videoJSON = video.json()
            model.recordVersion(recording, video: video, plan: plan)
            return video
        }
        let first = try make("A", style: "clear", prompt: nil, at: Date(timeIntervalSince1970: 1_000_000))
        _ = try make("B", style: "energetic", prompt: "More energetic.", at: Date(timeIntervalSince1970: 2_000_000))
        var versions = recording.versions
        XCTAssertEqual(versions.versions.map(\.number), [1, 2])
        XCTAssertEqual(versions.current, 2)
        XCTAssertEqual(versions.version(1)?.made, "Clear, the house style")
        XCTAssertEqual(versions.version(2)?.made, "Energetic, \u{201C}More energetic.\u{201D}")
        XCTAssertTrue(versions.version(2)!.line.hasPrefix("Version 2. Energetic"), versions.version(2)!.line)
        let v1 = EditVersion.folder(1, in: output)
        XCTAssertEqual(try String(contentsOf: v1.appending(path: "Video/talk.mp4"), encoding: .utf8), "A", "version 1 keeps its own video")
        XCTAssertEqual(EditPlan.read(folder: v1.path)?.style, "clear", "and its own plan")
        XCTAssertEqual(model.approvalVersionLine(recording)?.hasPrefix("Version 2, made "), true)

        // Play version 1: the Viewer reads it from its own folder.
        model.playVersion(1, of: recording)
        XCTAssertEqual(model.viewer.versionPlaying?.number, 1)
        XCTAssertEqual(model.viewer.versionPlaying?.folder, v1.path)

        // Use This Version: version 1's files back in the recording's folder, its record in use, Approve names it.
        XCTAssertTrue(model.canUseVersion(1, of: recording))
        XCTAssertFalse(model.canUseVersion(2, of: recording), "the version in use")
        XCTAssertTrue(model.useVersion(1, of: recording))
        XCTAssertEqual(try String(contentsOf: output.appending(path: "Video/talk.mp4"), encoding: .utf8), "A")
        XCTAssertEqual(EditPlan.read(folder: output.path)?.style, "clear")
        XCTAssertEqual(recording.video?.madeAt, first.madeAt)
        versions = recording.versions
        XCTAssertEqual(versions.current, 1)
        XCTAssertEqual(model.approvalVersionLine(recording)?.hasPrefix("Version 1, made "), true)
        XCTAssertNil(model.viewer.versionPlaying)
        XCTAssertEqual(try String(contentsOf: EditVersion.folder(2, in: output).appending(path: "Video/talk.mp4"), encoding: .utf8), "B", "version 2 is kept")
        // The receipt names the version.
        let receipt = Approval.markdown(.init(label: "Sun 13 Sep", title: "", notes: "", recordingFile: "x.mp4", editsSummary: nil, approvedAt: Date(),
                                              version: model.approvalVersionLine(recording)), rows: [])
        XCTAssertTrue(receipt.contains("## Video version\n\nVersion 1, made "), receipt)

        // Five are kept; the oldest goes, never the one in use.
        for k in 0..<5 { _ = try make("C\(k)", style: "clear", prompt: nil, at: Date(timeIntervalSince1970: 3_000_000 + Double(k))) }
        versions = recording.versions
        XCTAssertEqual(versions.versions.count, EditVersions.kept)
        XCTAssertEqual(versions.versions.map(\.number), [3, 4, 5, 6, 7])
        XCTAssertFalse(FileManager.default.fileExists(atPath: v1.path), "the oldest's folder goes with it")
        // The Versions folder is never one a make replaces or Approve copies.
        XCTAssertFalse(Pipeline.madeNames.contains(EditVersions.folderName))
    }
}
