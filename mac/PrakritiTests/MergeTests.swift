import AppKit
import Foundation
import SwiftUI
import Synchronization
import XCTest
@testable import Prakriti

/// v2 part M12a (docs/v2/PLAN.md M12, check 1 (indexing, teacher), check 4 and check 5 (the sheet)): the windows of whole sentences,
/// who may be in a moment, the index file, the search refusing another teacher, the model's requests under the privacy lock, the
/// embeddings refusing any host but this Mac, and the sheet drawn. Every word here is made up; no recording's words are in the
/// repository, and nothing reaches a model (a stub gives numbers for meaning, a script answers for the model).
@MainActor
final class MergeTests: XCTestCase {
    private var work: URL!

    override func setUp() async throws {
        work = FileManager.default.temporaryDirectory.appending(path: "prakriti-merge-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: work)
    }

    // MARK: Made-up transcripts

    /// Words of made-up sentences, each sentence `seconds` long with its words spread evenly, one after another from `start`.
    static func words(_ sentences: [String], seconds: Double = 6, start: Double = 0) -> [PlanWord] {
        var out: [PlanWord] = []
        var t = start
        for (n, sentence) in sentences.enumerated() {
            let parts = sentence.split(separator: " ").map(String.init)
            let each = seconds / Double(parts.count)
            for (i, text) in parts.enumerated() {
                out.append(PlanWord(index: out.count, text: text, norm: PlanWord.normalize(text), start: t + Double(i) * each,
                                    end: t + Double(i + 1) * each - 0.05, sentence: n, closes: PlanWord.closing(text)))
            }
            t += seconds + 0.4
        }
        return out
    }

    static let breath = ["The breath comes before the pose, always.", "When the breath is steady the body softens.", "So we begin every practice with the breath.",
                         "Count four in and six out.", "Notice how the shoulders drop."]
    static let money = ["Pricing a retreat takes careful planning.", "Deposits are due a month ahead.", "Most people decide in the last two weeks.",
                        "Send the reminder early.", "Keep the form short."]

    /// A people file and voices for a recording: one face track and one voice for its whole length, plus, when asked, a second
    /// unnamed face from `otherFrom` to `otherTo`.
    static func people(duration: Double, other: (from: Double, to: Double)? = nil, steps: [String] = ["faces", "voices"]) -> (PeopleFile, VoicesFound) {
        var tracks = [PeopleFile.Track(id: 1, person: 1, start: 0, end: duration, boxes: [[0, 0.4, 0.2, 0.2, 0.3, 0.9]])]
        var rows = [FacePerson(id: 1, label: "Unnamed 1", onScreen: duration, first: 0, last: duration, appearances: 1, keyTime: 1,
                               keyBox: FaceBox(x: 0.4, y: 0.2, width: 0.2, height: 0.3))]
        if let other {
            tracks.append(PeopleFile.Track(id: 2, person: 2, start: other.from, end: other.to, boxes: [[other.from, 0.8, 0.7, 0.1, 0.15, 0.9]]))
            rows.append(FacePerson(id: 2, label: "Unnamed 2", onScreen: other.to - other.from, first: other.from, last: other.to, appearances: 1,
                                   keyTime: other.from, keyBox: FaceBox(x: 0.8, y: 0.7, width: 0.1, height: 0.15)))
        }
        var file = PeopleFile(recordingID: UUID(), duration: duration, frameWidth: 1920, frameHeight: 1080, tracks: tracks, people: rows)
        file.steps = steps
        file.voices = PeopleFile.Voices(source: "diarizer", tracks: [], segments: [[0, duration, 1]], links: [[1, 1]])
        let voices = VoicesFound(checkedAt: Fixtures.now, duration: duration, source: .diarizer,
                                 voices: [FoundVoice(id: 1, label: "Voice 1", speaking: duration, first: 0, last: duration, track: nil, face: 1, linkedBy: "the only face on screen")])
        return (file, voices)
    }

    static let teacherA = UUID(), teacherB = UUID()

    static func source(_ sentences: [String], teacher: UUID?, released: Bool = true, choices: PeopleChoices = .none, other: (from: Double, to: Double)? = nil,
                       checked: Bool = true, day: Int = 6) -> MomentSource {
        let words = words(sentences)
        let duration = (words.last?.end ?? 0) + 1
        let (file, voices) = people(duration: duration, other: other, steps: checked ? ["faces", "voices"] : ["faces"])
        // The teacher is the one face and voice, named.
        var names = (faces: [Int: UUID](), voices: [Int: UUID]())
        if let teacher { names.faces[1] = teacher; names.voices[1] = teacher }
        let people = MomentPeople.from(file: file, voices: voices, names: names, choices: choices,
                                       people: teacher.map { [NamedPerson(id: $0, name: "Asha Verlaine", released: released)] } ?? [])
        var facts = PeopleFacts(checked: checked, named: teacher.map { [PeopleFacts.Named(personID: $0, name: "Asha Verlaine", heard: true, seen: true, released: released)] } ?? [])
        facts.leftOut = choices.people.values.filter { $0.choice == .leaveOut }.count
        let date = Fixtures.date(2026, 9, day, 18, 0, 0)
        return MomentSource(id: UUID(), label: AppModel.momentSourceLabel(date: date, kind: .talk, teacher: "Asha Verlaine"), date: date, teacher: teacher,
                            words: words, transcriptSHA256: PlanWords.sha256(Data(sentences.joined().utf8)), people: people, facts: facts,
                            filePath: "/nonexistent/\(day).mp4")
    }

    // MARK: Check 1: windows and who may be indexed

    func testWindowsAreWholeSentencesFiveToFortyFiveSeconds() {
        let words = Self.words(Self.breath + Self.money, seconds: 6)
        let windows = MomentWindows.make(words)
        XCTAssertFalse(windows.isEmpty)
        let starts = Set(MomentWindows.sentences(words).map { words[$0.lowerBound].index })
        let ends = Set(MomentWindows.sentences(words).map { words[$0.upperBound].index })
        for window in windows {
            XCTAssertGreaterThanOrEqual(window.seconds, MomentWindows.shortest)
            XCTAssertLessThanOrEqual(window.seconds, MomentWindows.longest)
            XCTAssertTrue(starts.contains(window.firstWord), "starts on a sentence: \(window)")
            XCTAssertTrue(ends.contains(window.lastWord), "ends on a sentence: \(window)")
        }
        // A sentence over 45 s is never a window, and two short ones join until 15 s.
        let long = Self.words(["One very long sentence that goes on."], seconds: 50)
        XCTAssertTrue(MomentWindows.make(long).isEmpty)
        XCTAssertGreaterThanOrEqual(windows[0].seconds, MomentWindows.aim)
    }

    /// PLAN M12 check 1, read with Ivan's decision of Mon 12 Oct: a span with anyone Ivan set to Hide Face or Leave Out, or a named
    /// person marked "no release", is never indexed, and a recording whose people were not checked gives nothing; an unnamed person on
    /// Include (everyone signed a release) no longer keeps a span out.
    func testASpanWithSomeoneNotIncludedOrWithoutAReleaseIsNeverIndexed() async throws {
        let index = try MomentIndex(url: work.appending(path: "Merge/moments.sqlite"))
        let embedder = HashingEmbedder()
        let duration = 60.0
        // A second face from 10 s to 20 s, unnamed, set to Hide Face.
        var hidden = PeopleChoices()
        hidden.set(.hideFace, for: .face(2))
        let withHidden = Self.source(Self.breath + Self.money, teacher: Self.teacherA, choices: hidden, other: (10, 20))
        // The same, but the second face on Include: indexed.
        let withIncluded = Self.source(Self.breath + Self.money, teacher: Self.teacherA, other: (10, 20))
        let noRelease = Self.source(Self.breath, teacher: Self.teacherA, released: false)
        let notChecked = Self.source(Self.breath, teacher: Self.teacherA, checked: false)
        try await MomentFinder.update(index: index, sources: [withHidden, withIncluded, noRelease, notChecked], embedder: embedder, now: Fixtures.now)

        let hiddenWindows = try index.windows(of: [withHidden.id]).map(\.window)
        XCTAssertFalse(hiddenWindows.isEmpty, "the rest of the recording is indexed")
        for window in hiddenWindows {
            XCTAssertFalse(window.end > 10 - MomentPeople.margin && window.start < 20 + MomentPeople.margin, "a span with the hidden face was indexed: \(window)")
        }
        let includedWindows = try index.windows(of: [withIncluded.id]).map(\.window)
        XCTAssertTrue(includedWindows.contains { $0.end > 10 && $0.start < 20 }, "an unnamed person on Include does not keep a span out (Ivan, 12 Oct)")
        XCTAssertGreaterThan(includedWindows.count, hiddenWindows.count)
        XCTAssertEqual(try index.windows(of: [noRelease.id]).count, 0, "the teacher marked no release: nothing indexed")
        XCTAssertEqual(try index.windows(of: [notChecked.id]).count, 0, "people not checked: nothing indexed")
        XCTAssertNil(try index.entry(notChecked.id))
        XCTAssertEqual(withHidden.people.problem(start: 12, end: 14), "someone in it is set to Hide Face")
        XCTAssertEqual(noRelease.people.problem(start: 1, end: 5), "someone in it has no signed release on file")
        _ = duration

        // Leave Out for the video, chosen after indexing: the next update takes the span out, and the search drops it even before.
        var leaveOut = PeopleChoices()
        leaveOut.set(.leaveOut, for: .face(2))
        var changed = withIncluded
        changed.people = Self.source(Self.breath + Self.money, teacher: Self.teacherA, choices: leaveOut, other: (10, 20)).people
        let stored = try index.windows(of: [changed.id])
        let dropped = MomentFinder.candidates(points: [stored[0].vector], stored: stored, sources: [changed.id: changed], threshold: -1)
        XCTAssertFalse(dropped.contains { $0.stored.window.end > 10 - MomentPeople.margin && $0.stored.window.start < 20 + MomentPeople.margin },
                       "the search checks every span against the choices of now")
        try await MomentFinder.update(index: index, sources: [changed], embedder: embedder, now: Fixtures.now)
        XCTAssertFalse(try index.windows(of: [changed.id]).contains { $0.window.end > 10 - MomentPeople.margin && $0.window.start < 20 + MomentPeople.margin })

        // The index keeps times and numbers, never the words.
        let bytes = try Data(contentsOf: index.url)
        XCTAssertNil(bytes.range(of: Data("breath".utf8)), "the index file holds no words")
        // Reopened, it still knows what it holds, and an unchanged recording is not embedded again.
        let reopened = try MomentIndex(url: index.url)
        let calls = embedder.calls
        let again = try await MomentFinder.update(index: reopened, sources: [withHidden], embedder: embedder, now: Fixtures.now)
        XCTAssertEqual(again, 0)
        XCTAssertEqual(embedder.calls, calls)
        try reopened.remove(withHidden.id)
        XCTAssertNil(try reopened.entry(withHidden.id))
    }

    /// PLAN M12 check 1: suggestions are refused for a recording whose teacher differs, and for one with no teacher.
    func testOnlyRecordingsOfTheSameTeacherAreSearched() async throws {
        let index = try MomentIndex(url: work.appending(path: "moments.sqlite"))
        let current = Self.source(Self.breath, teacher: Self.teacherA, day: 13)
        let otherTeacher = Self.source(Self.breath, teacher: Self.teacherB)
        let judge = ScriptedJudge(verdict: MomentVerdict(supports: true, contradicts: false, why: "Makes the same point."))
        let point = try XCTUnwrap(MomentFinder.point(selectedFrom: 0, to: 12, words: current.words))
        let search = try await MomentFinder.find(current: current, points: [point], header: "h", others: [otherTeacher], notSearched: 0, teacherName: "Asha Verlaine",
                                                 index: index, embedder: HashingEmbedder(), judge: judge, now: Fixtures.now)
        XCTAssertEqual(search.moments, [])
        XCTAssertEqual(search.searched, 0)
        XCTAssertEqual(judge.asked, 0, "no model is asked about another teacher's recording")
        XCTAssertNil(try index.entry(otherTeacher.id), "another teacher's recording is not even indexed")
        XCTAssertEqual(search.emptyLine, "No other recording makes this point clearly. Prakriti searched 0 recordings of Asha Verlaine.")
        XCTAssertFalse(MomentFinder.sameTeacher(current, otherTeacher))

        let noTeacher = Self.source(Self.breath, teacher: nil, day: 13)
        do {
            _ = try await MomentFinder.find(current: noTeacher, points: [point], header: "h", others: [Self.source(Self.breath, teacher: Self.teacherA)], notSearched: 0,
                                            teacherName: "", index: index, embedder: HashingEmbedder(), judge: judge, now: Fixtures.now)
            XCTFail("a recording with nobody teaching is refused")
        } catch let refusal as MomentFinder.Refusal {
            XCTAssertTrue(refusal.reason.contains("Choose who is teaching"), refusal.reason)
        }
    }

    /// At most three moments, each the source's own words on sentence boundaries, 5 to 45 s, with where it would go; a moment the
    /// model says does not support the point is left out; two overlapping windows are never both offered.
    func testFindGivesAtMostThreeMomentsInTheSourcesOwnWords() async throws {
        let index = try MomentIndex(url: work.appending(path: "moments.sqlite"))
        let current = Self.source(Self.breath, teacher: Self.teacherA, day: 13)
        let sources = [Self.source(Self.breath + Self.money, teacher: Self.teacherA, day: 6), Self.source(Self.money + Self.breath, teacher: Self.teacherA, day: 20),
                       Self.source(Self.breath, teacher: Self.teacherA, day: 27), Self.source(Self.breath, teacher: Self.teacherA, day: 28)]
        let point = try XCTUnwrap(MomentFinder.point(selectedFrom: 0, to: 12.5, words: current.words))
        XCTAssertEqual(point.afterWords, "When the breath is steady the body softens.")
        // The first candidate is declined; the rest support it.
        let judge = ScriptedJudge(verdict: MomentVerdict(supports: true, contradicts: false, why: "Makes the same point about breath."), declineFirst: true)
        let search = try await MomentFinder.find(current: current, points: [point], header: "h", others: sources, notSearched: 1, teacherName: "Asha Verlaine",
                                                 index: index, embedder: HashingEmbedder(), judge: judge, now: Fixtures.now)
        XCTAssertEqual(search.searched, 4)
        XCTAssertEqual(search.moments.count, MomentFinder.most)
        XCTAssertEqual(search.declined, 1)
        XCTAssertEqual(search.judged, 4)
        let bySource = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        for moment in search.moments {
            let words = try XCTUnwrap(bySource[moment.sourceID]?.words)
            XCTAssertEqual(moment.words, PlanWords.text(words[moment.window.firstWord...moment.window.lastWord]), "the transcript's own words")
            XCTAssertTrue(moment.seconds >= 5 && moment.seconds <= 45)
            XCTAssertEqual(moment.after, point.after)
            XCTAssertTrue(moment.sourceLabel.hasSuffix("Talk with Asha"), moment.sourceLabel)
        }
        for a in search.moments {
            for b in search.moments where a.id != b.id && a.sourceID == b.sourceID {
                XCTAssertFalse(a.window.end > b.window.start && a.window.start < b.window.end, "two overlapping moments")
            }
        }
        XCTAssertEqual(AppModel.momentSourceLabel(date: Fixtures.date(2026, 9, 6, 18, 0, 0), kind: .talk, teacher: "Gabriel Galindo"), "Sun 6 Sep 2026, Talk with Gabriel")
        // A moment that names money is never offered, and the model is not asked about it (Ivan's copy rules).
        let paid = Self.source(["We paid 300 dollars for the retreat.", "The breath comes before the pose, always. When the breath is steady the body softens."],
                               teacher: Self.teacherA, day: 29)
        let index2 = try MomentIndex(url: work.appending(path: "moments2.sqlite"))
        let judge2 = ScriptedJudge(verdict: MomentVerdict(supports: true, contradicts: false, why: "Same point."))
        let refused = try await MomentFinder.find(current: current, points: [point], header: "h", others: [paid], notSearched: 0, teacherName: "Asha Verlaine",
                                                  index: index2, embedder: HashingEmbedder(), judge: judge2, now: Fixtures.now)
        XCTAssertFalse(refused.moments.contains { CopyRules.flag($0.words) != nil })
        XCTAssertGreaterThan(refused.copyRules, 0, "\(refused)")
        XCTAssertEqual(refused.moments.map(\.words), ["The breath comes before the pose, always. When the breath is steady the body softens."], "the sentence without money is still offered")
    }

    /// The main points come from the parts of the talk: the main point first, never the welcome or housekeeping.
    func testTheMainPointsComeFromThePartsOfTheTalk() {
        let words = Self.words(Self.breath + Self.money)
        func beat(_ id: String, _ kind: BeatKind, from: Int, to: Int, thesis: Bool = false, key: String? = nil) -> Beat {
            Beat(id: id, firstSentence: "s1", lastSentence: "s1", from: PlanWord.id(from), to: PlanWord.id(to), start: words[from].start, end: words[to].end,
                 summary: "part \(id)", scores: ["enlightening": thesis ? 1 : 3], kind: kind, standsAlone: true, dependsOn: [],
                 keyLine: key.map { Beat.KeyLine(from: PlanWord.id(from), to: PlanWord.id(to), text: $0) }, hookCandidate: false, terms: [], thesis: thesis)
        }
        let breathEnd = Self.words(Self.breath).count - 1
        let beats = [beat("b1", .welcome, from: 0, to: 6), beat("b2", .teaching, from: 7, to: breathEnd, thesis: true, key: "So we begin every practice with the breath."),
                     beat("b3", .housekeeping, from: breathEnd + 1, to: words.count - 1)]
        let points = MomentFinder.points(beats: beats, words: words)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].text, "part b2. So we begin every practice with the breath.")
        XCTAssertEqual(points[0].afterWords, "Notice how the shoulders drop.")
        XCTAssertEqual(points[0].after, words[breathEnd].end, accuracy: 0.001)
    }

    // MARK: Check 4: the model's requests under the lock

    /// PLAN M12 check 4, with Ivan's decision of Mon 12 Oct: "Choosing moments" set to Anthropic reads a pair of released recordings
    /// in the cloud (1 request), and a pair with someone marked "no release" or set to Leave Out on this Mac (0 cloud requests).
    func testTheModelsRequestsAreCountedUnderTheLock() async throws {
        let answer = #"{"supports": true, "contradicts": false, "why": "Makes the same point — more directly"}"#
        func run(_ sourceFacts: PeopleFacts) async throws -> (cloud: Int, local: Int, verdict: MomentVerdict) {
            let cloud = ScriptedClient(.claudeAPI, limit: 200_000, replies: [.success(answer)])
            let local = ScriptedClient(.lmStudio, limit: 200_000, replies: [.success(answer)])
            var setup = WritingSetup()
            setup.providers = [.choosingMoments: .claudeAPI]
            setup.maxAttempts = 1
            setup.makeClient = { _, _ in local }
            setup.makeCloudClient = { _, _ in cloud }
            let counter = MomentRequestCounter()
            let source = UUID()
            let judge = MomentJudge(setup: setup, log: nil, current: LockSubject(people: PeopleFacts(checked: true, named: [ProviderTests.teacher()])),
                                    sources: [source: LockSubject(people: sourceFacts)], fileName: "test.mp4", onRequest: { counter.count($0) })
            let verdict = try await judge.judge(point: "The breath comes first.", moment: "We begin with the breath.", momentDay: "Sun 6 Sep 2026", source: source)
            XCTAssertEqual(counter.cloud, cloud.requests.count)
            XCTAssertEqual(counter.local, local.requests.count)
            return (cloud.requests.count, local.requests.count, verdict)
        }
        let released = try await run(PeopleFacts(checked: true, named: [ProviderTests.teacher()], unnamedSeen: 2))
        XCTAssertEqual(released.cloud, 1, "released people, an unnamed person included: read by Anthropic")
        XCTAssertEqual(released.local, 0)
        XCTAssertEqual(released.verdict.why, "Makes the same point, more directly.", "dashes become commas, a full stop is added")
        let noRelease = try await run(PeopleFacts(checked: true, named: [ProviderTests.teacher(released: false)]))
        XCTAssertEqual(noRelease.cloud, 0, "the teacher marked no release: nothing sent")
        XCTAssertEqual(noRelease.local, 1)
        var leftOut = PeopleFacts(checked: true, named: [ProviderTests.teacher()])
        leftOut.leftOut = 1
        let left = try await run(leftOut)
        XCTAssertEqual(left.cloud, 0, "someone set to Leave Out in the other recording: nothing sent")
        XCTAssertEqual(left.local, 1)
        XCTAssertThrowsError(try MomentJudge.check("not json"))
        XCTAssertThrowsError(try MomentJudge.check(#"{"supports": true, "why": ""}"#))
        let folder = SnapshotRenderer.milestoneFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? ["v2 part M12a, PLAN M12 check 4: requests of Choosing moments (set to Anthropic) counted under the lock, made-up words",
              "released pair (an unnamed person seen): \(released.cloud) Anthropic, \(released.local) on this Mac",
              "teacher marked no release: \(noRelease.cloud) Anthropic, \(noRelease.local) on this Mac",
              "someone set to Leave Out: \(left.cloud) Anthropic, \(left.local) on this Mac"].joined(separator: "\n").appending("\n")
            .write(to: folder.appending(path: "merge-lock-counts.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: The embeddings stay on this Mac

    /// PLAN 2.2 rule 2: `Merge/` reaches embeddings only through a client that refuses any host but this Mac; a planted remote
    /// address is refused before anything is sent.
    func testTheEmbeddingsRefuseAnyHostButThisMac() async throws {
        StubProtocol.seen = []
        // Not a closure written here: this class is on the main actor, and the stub answers on URLSession's own queue.
        StubProtocol.handler = embeddingsAnswer
        defer { StubProtocol.handler = nil }
        for remote in ["http://example.com:1235/v1", "https://api.example.org/v1", "http://192.168.1.20:1235/v1", "http://localhost.example.com/v1", "file:///tmp/v1"] {
            XCTAssertThrowsError(try LocalEmbeddings(address: remote, session: StubProtocol.session()), remote)
        }
        XCTAssertEqual(StubProtocol.seen.count, 0, "nothing was sent")
        let local = try LocalEmbeddings(address: "http://localhost:1235/v1/", session: StubProtocol.session())
        let vectors = try await local.embed(["search_document: a", "search_document: b"])
        XCTAssertEqual(vectors.count, 2)
        XCTAssertEqual(StubProtocol.seen.first?.path, "/v1/embeddings")
        XCTAssertEqual(StubProtocol.seen.first?.body?["model"] as? String, "text-embedding-nomic-embed-text-v1.5")
        XCTAssertNoThrow(try LocalEmbeddings(address: "http://127.0.0.1:1235/v1"))
        XCTAssertTrue(ModelTask.choosingMoments.isBuilt)
        // Never chosen before, Choosing moments follows the writing's choice (Ivan's live settings: Anthropic for writing).
        let name = "studio.therowan.prakriti.tests.merge-defaults"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(ModelProvider.claudeAPI.rawValue, forKey: "provider.writing")
        XCTAssertEqual(AppSettings(defaults: defaults).provider[.choosingMoments], .claudeAPI)
        defaults.set(ModelProvider.lmStudio.rawValue, forKey: "provider.choosingMoments")
        XCTAssertEqual(AppSettings(defaults: defaults).provider[.choosingMoments], .lmStudio, "a choice made is kept")
    }

    // MARK: Check 5: the sheet, drawn

    /// PLAN M12 check 5, the part M12a runs: the sheet with suggestions, empty, searching and refused, and the Direction tab's
    /// Supporting Moments section, drawn on the sample data with made-up words, written to `29-*.png`.
    func testDrawTheSupportingMomentsSheetToLookAt() throws {
        let renderer = try SnapshotRenderer(outputFolder: SnapshotRenderer.milestoneFolder())
        let (model, made) = try ApproveTests.madeRecording(in: work, peopleChecked: true)
        let teacher = Person(name: "Asha Verlaine")
        teacher.role = .teacher
        model.context.insert(teacher)
        model.setTeacher(teacher, for: made)
        model.cardPictures.useTestPattern = true
        let request = MomentsRequest(recordingID: made.id)
        model.momentsSheet = request
        let words = Self.words(Self.breath)
        func moment(_ day: Int, _ first: Int, _ last: Int, why: String) -> SupportingMoment {
            let date = Fixtures.date(2026, 9, day, 18, 0, 0)
            return SupportingMoment(sourceID: made.id, sourceLabel: AppModel.momentSourceLabel(date: date, kind: .talk, teacher: "Asha Verlaine"), sourceDate: date,
                                    filePath: "/nonexistent.mp4", window: MomentWindow(start: words[first].start + 1_520, end: words[last].end + 1_520, firstWord: first, lastWord: last),
                                    words: PlanWords.text(words[first...last]), why: why, point: 0, after: 252.4, afterWords: "and that is why we start with the breath.",
                                    similarity: 0.71)
        }
        let found = MomentSearch(header: "Moments that support this recording's main points",
                                 moments: [moment(6, 0, 14, why: "Makes the same point about breath, said more directly."),
                                           moment(20, 15, 26, why: "Gives a practice for it: a count for the breath.")],
                                 searched: 2, notSearched: 0, teacherName: "Asha Verlaine", windows: 1_126, candidates: 9, judged: 3, declined: 1,
                                 by: "Qwen3.8-27B in LM Studio", seconds: 41)
        func sheet(_ name: String, _ state: MomentsState, height: CGFloat = 640) throws {
            model.momentsState = state
            for (scheme, appearance) in SnapshotRenderer.appearances {
                try renderer.renderSheet(AnyView(SupportingMomentsSheet(request: request).frame(width: 720, height: height - 32)), model: model,
                                         size: CGSize(width: 720, height: height), appearance: appearance, name: "\(name)-\(scheme)")
            }
        }
        try sheet("29-moments-sheet-suggestions", .found(found), height: 900)
        var empty = found
        empty.moments = []
        empty.notSearched = 1
        try sheet("29-moments-sheet-empty", .found(empty))
        try sheet("29-moments-sheet-searching", .searching("Asking Qwen3.8-27B in LM Studio about a moment from Sun 6 Sep (2 of at most 8)."))
        try sheet("29-moments-sheet-refused", .refused("Prakriti finds this recording's main points in its parts of the talk, and they have not been read yet. Plan the edit in Direction first, or select words in the transcript and choose Find Supporting Moments for This."))
        for (scheme, appearance) in SnapshotRenderer.appearances {
            try renderer.renderSheet(AnyView(Form { SupportingMomentsSection(recording: made) }.formStyle(.grouped).frame(width: 400, height: 268)), model: model,
                                     size: CGSize(width: 400, height: 300), appearance: appearance, name: "29-direction-supporting-moments-\(scheme)")
        }
    }
}

/// LM Studio's embeddings answer, for `StubProtocol`: three numbers per input.
nonisolated func embeddingsAnswer(_ method: String, _ path: String, _ body: [String: Any]?) -> (Int, Any) {
    let inputs = (body?["input"] as? [String]) ?? []
    return (200, ["object": "list", "data": inputs.enumerated().map { ["object": "embedding", "index": $0.offset, "embedding": [1.0, 0.0, 0.0]] }])
}

/// Numbers for meaning without a model: each word adds to one of 64 places, so texts sharing words are close. For the tests only.
final class HashingEmbedder: MomentEmbedder {
    let modelID = "test-hashing"
    let displayName = "test numbers"
    private let count = Mutex(0)
    var calls: Int { count.withLock { $0 } }

    func embed(_ texts: [String]) async throws -> [[Float]] {
        count.withLock { $0 += 1 }
        return texts.map { text in
            var v = [Float](repeating: 0, count: 64)
            for word in text.lowercased().split(whereSeparator: { !$0.isLetter }) where word.count > 3 && !["search", "query", "document"].contains(String(word)) {
                var h: UInt64 = 1469598103934665603
                for b in word.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
                v[Int(h % 64)] += 1
            }
            return LocalEmbeddings.unit(v)
        }
    }
}

/// Answers for the model: the same verdict every time, the first one declined when asked, counting each question.
final class ScriptedJudge: MomentJudging {
    let verdict: MomentVerdict
    let declineFirst: Bool
    private let count = Mutex(0)
    var asked: Int { count.withLock { $0 } }
    let displayName = "scripted model"

    init(verdict: MomentVerdict, declineFirst: Bool = false) {
        self.verdict = verdict
        self.declineFirst = declineFirst
    }

    func judge(point: String, moment: String, momentDay: String, source: UUID) async throws -> MomentVerdict {
        let n = count.withLock { $0 += 1; return $0 }
        if declineFirst && n == 1 { return MomentVerdict(supports: false, contradicts: false, why: "About something else.") }
        return verdict
    }
}
