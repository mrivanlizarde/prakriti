import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import XCTest
@testable import Prakriti

/// v2 part M10a (docs/v2/PLAN.md M10, check 1): the timelines for Final Cut Pro and DaVinci Resolve.
///
/// - Three fixture plans, each written as FCPXML 1.14 and 1.10, valid against the DTDs Final Cut Pro ships (copied out of
///   `/Applications/Final Cut Pro Creator Studio.app/.../Interchange.framework/Versions/A/Resources/` into `mac/build/dtd/`,
///   because xmllint cannot read them in place), and clean under the semantic lint. Skipped, with a message, when Final Cut Pro is
///   not on this Mac.
/// - The lint catches each of its rules when one is broken on purpose.
/// - Since v2 part M10b, only a video made before the people check is refused; anyone hidden or left out, or a muted name, and the
///   timelines point at privacy-safe media, which the gate keeps only when its own checks pass (`timelineMediaProblems`).
/// - A clone is proved per file, never by free space.
/// - End to end on synthetic media only (ffmpeg's test pattern, no face of anyone): the video made as a make makes it, then the
///   timelines from it, through the gate: every file there, both valid, a graphics clip ProRes 4444 with its transparency equal to
///   what the compositor draws, the held last frame, the media a clone; and a refused plan leaves nothing.
final class FCPXMLTests: XCTestCase {
    // MARK: The fixtures

    /// mac/build/dtd, with both DTDs copied from Final Cut Pro, or nil when it is not on this Mac.
    static func dtds() throws -> URL? {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "build/dtd", directoryHint: .isDirectory)
        return FCPXMLLint.copyDTDs(to: folder) ? folder : nil
    }

    /// A file at each source the spec names, so rule 5 can be read.
    static func placeholders(_ spec: TimelineSpec) throws {
        for url in [spec.media.url] + spec.graphics.map(\.url) + [spec.held?.url].compactMap({ $0 }) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) { try Data([0]).write(to: url) }
        }
    }

    /// The plan's texts as graphics clips at their place on the video's clock.
    static func graphics(_ plan: EditPlan, timeline: EditTimeline, folder: URL) -> [TimelineSpec.Clip] {
        var counts: [OverlayKind: Int] = [:]
        return plan.visual.filter(\.isText).compactMap { item in
            guard let kind = OverlayKind(rawValue: item.kind), let start = timeline.editFrame(span: item.span, original: item.in ?? -1) else { return nil }
            counts[kind, default: 0] += 1
            let name = GraphicsClips.name(kind, number: counts[kind] ?? 1)
            return TimelineSpec.Clip(name: name, url: folder.appending(path: "Graphics/\(name).mov"), kind: kind, lines: item.lines ?? [],
                                     align: OverlayText.Align(rawValue: item.align ?? "") ?? .leading, start: start,
                                     frames: Int64(((item.seconds ?? 2) / timeline.frame.seconds).rounded()))
        }
    }

    static func spec(_ plan: EditPlan, words: [PlanWord], folder: URL, width: Int = 1920, height: Int = 1080, project: String) -> TimelineSpec {
        let timeline = EditTimeline(plan: plan)
        let media = TimelineSpec.Media(name: "synthetic", url: folder.appending(path: "Media/synthetic, talk.mp4"),
                                       frames: Int64((plan.sourceDuration / plan.frameDuration.seconds).rounded(.down)), width: width, height: height)
        var held: TimelineSpec.Clip?
        if timeline.holdFrames > 0 {
            held = TimelineSpec.Clip(name: GraphicsClips.heldName, url: folder.appending(path: "Graphics/\(GraphicsClips.heldName).mov"), kind: nil,
                                     start: timeline.keptFrames, frames: timeline.holdFrames)
        }
        let cues = Captions.cues(Captions.words(plan: plan, words: PlanWords(words: words, transcriptSHA256: "", sentences: 1), timeline: timeline),
                                 duration: timeline.duration)
        return TimelineSpec(project: project, frame: plan.frameDuration, width: width, height: height, media: media, timeline: timeline,
                            framing: Framing(plan: plan, timeline: timeline), graphics: graphics(plan, timeline: timeline, folder: folder), held: held,
                            captions: cues)
    }

    /// Three plans: (1) a plain rough cut of jump cuts with captions; (2) the Clear house style with punch-ins, slow push-ins, the
    /// held last frame, the title and a teacher's name; (3) a 4K talk that opens on its strongest line, with two texts at once (two
    /// lane pairs), chapters and moments to check.
    static func fixtures(in folder: URL) -> [(String, TimelineSpec)] {
        let plain = HookTests.talk(minutes: 2)
        let one = spec(plain.plan, words: plain.words, folder: folder.appending(path: "plain"), project: "Plain cut")

        let styled = TextTests.planned()
        let styledWords = StyleTests.syntheticPlan().words
        let two = spec(styled, words: styledWords, folder: folder.appending(path: "styled"), project: "Sun 13 Sep, Clear")

        let talk = HookTests.talk(minutes: 3)
        let beats = HookTests.beats(talk.words)
        let times = Dictionary(talk.plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var hooked = talk.plan
        if let hook = Hook.choose(.init(spans: talk.plan.spans, times: times, words: talk.words, envelope: talk.envelope, frame: talk.plan.frameDuration,
                                        beats: beats, range: 5...15)) {
            hooked.spans = hook.spans + talk.plan.spans
        }
        var three = spec(hooked, words: talk.words, folder: folder.appending(path: "hook"), width: 3840, height: 2160, project: "Sun 6 Sep, Story")
        let fd = hooked.frameDuration
        let g = folder.appending(path: "hook/Graphics")
        three.graphics = [
            .init(name: "Key phrase 1", url: g.appending(path: "Key phrase 1.mov"), kind: .keyPhrase, lines: ["the work that we do"], start: 400, frames: 75),
            .init(name: "Term 1", url: g.appending(path: "Term 1.mov"), kind: .term, lines: ["Prāṇāyāma & “breath”"], align: .trailing, start: 430, frames: 106),
            .init(name: "Key phrase 2", url: g.appending(path: "Key phrase 2.mov"), kind: .keyPhrase, lines: ["traces back to"], start: 2_000, frames: 75),
        ]
        three.chapters = [.init(frame: 0, text: "Welcome"), .init(frame: Int64(40 / fd.seconds), text: "Where it comes from"),
                          .init(frame: Int64(100 / fd.seconds), text: "The practice")]
        three.checks = [.init(frame: 777, text: "Possible retake at 0:25: kept both.")]
        return [("plain", one), ("styled", two), ("hook", three)]
    }

    // MARK: Check 1: both versions valid for three plans, and clean under the lint

    func testThreeFixturePlansAreValidFCPXMLInBothVersionsAndPassTheLint() async throws {
        guard let dtds = try Self.dtds() else {
            throw XCTSkip("Final Cut Pro is not on this Mac, so its FCPXML DTDs cannot be read; the DTD check is skipped.")
        }
        let scratch = FileManager.default.temporaryDirectory.appending(path: "fcpxml-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        for (name, spec) in Self.fixtures(in: scratch) {
            try Self.placeholders(spec)
            let layout = FCPXMLWriter.layout(spec)
            print(String(format: "%@: %d spine clips, %d texts, %d captions, %d chapters, %d markers, %lld frames", name, layout.clips.count, spec.graphics.count,
                         layout.captions, layout.chapterMarkers, layout.markers, layout.totalFrames))
            XCTAssertEqual(layout.totalFrames, spec.timeline.totalFrames, "\(name): the sequence is the video's length")
            for version in FCPXMLVersion.allCases {
                let xml = FCPXMLWriter.xml(spec, version: version)
                let file = scratch.appending(path: "\(name) \(version.rawValue).fcpxml")
                try xml.write(to: file, atomically: true, encoding: .utf8)
                let dtd = await FCPXMLLint.validate(file, version: version, dtds: dtds)
                XCTAssertNil(dtd, "\(name) \(version.rawValue) against \(version.dtdName): \(dtd ?? "")")
                let problems = FCPXMLLint.check(xml)
                XCTAssertEqual(problems, [], "\(name) \(version.rawValue): \(problems)")
                XCTAssertTrue(xml.contains("<fcpxml version=\"\(version.rawValue)\">"))
            }
            // The two files differ only in their version.
            let a = FCPXMLWriter.xml(spec, version: .finalCut), b = FCPXMLWriter.xml(spec, version: .resolve)
            XCTAssertEqual(a.replacingOccurrences(of: "version=\"1.14\"", with: "version=\"1.10\""), b, "\(name): one generator, only the version differs")
        }
        // What the styled plan carries: punch-ins as static transforms, push-ins as markers, the hold, the texts with their copies.
        let styled = try XCTUnwrap(Self.fixtures(in: scratch).first { $0.0 == "styled" }?.1)
        let xml = FCPXMLWriter.xml(styled, version: .finalCut)
        let punches = styled.framing.segments.filter { $0.easeFrames == 0 }.count, pushes = styled.framing.segments.filter { $0.easeFrames > 0 }.count
        XCTAssertGreaterThan(punches, 0)
        XCTAssertGreaterThan(pushes, 0)
        XCTAssertEqual(xml.components(separatedBy: "<adjust-transform ").count - 1, FCPXMLWriter.layout(styled).clips.filter { $0.scale != nil }.count)
        XCTAssertEqual(xml.components(separatedBy: "value=\"\(FCPXMLWriter.pushInMarker)\"").count - 1, pushes, "every push-in is a marker")
        XCTAssertFalse(xml.contains("keyframeAnimation"), "no animation until the round trip passes")
        XCTAssertFalse(xml.contains("<transition"), "no dissolve")
        XCTAssertTrue(xml.contains("name=\"Held last frame\""))
        XCTAssertEqual(xml.components(separatedBy: "enabled=\"0\"").count - 1, styled.graphics.count, "each text's editable copy is switched off")
        XCTAssertTrue(xml.contains("role=\"\(FCPXMLWriter.captionRole)\""))
        XCTAssertTrue(xml.contains("src=\"file://") && xml.contains("synthetic%2C%20talk.mp4"), "spaces and commas percent-encoded")
        // The 4K one names its format and puts two texts at once on two lane pairs.
        let hook = try XCTUnwrap(Self.fixtures(in: scratch).first { $0.0 == "hook" }?.1)
        let hookXML = FCPXMLWriter.xml(hook, version: .resolve)
        XCTAssertTrue(hookXML.contains("name=\"FFVideoFormat2160p2997\""))
        XCTAssertTrue(hookXML.contains("lane=\"3\"") && hookXML.contains("lane=\"4\""), "the overlapping term goes on the second pair")
        XCTAssertTrue(hookXML.contains("name=\"Opening line\""))
        XCTAssertEqual(hookXML.components(separatedBy: "<chapter-marker ").count - 1, 3)
        XCTAssertTrue(hookXML.contains("&amp;") && hookXML.contains("Prāṇāyāma"), "text escaped and kept as written")
    }

    func testThePositionKeepsThePlansFraming() {
        let middle = FCPXMLWriter.position(rect: Framing.rect(scale: 1.12, center: CGPoint(x: 0.5, y: 0.5)), scale: 1.12, aspect: 16 / 9)
        XCTAssertEqual(middle.x, 0, accuracy: 1e-9)
        XCTAssertEqual(middle.y, 0, accuracy: 1e-9)
        // The face right of middle and high: the picture moves left and down (Final Cut Pro's y is up).
        let p = FCPXMLWriter.position(rect: Framing.rect(scale: 1.12, center: CGPoint(x: 0.52, y: 0.48)), scale: 1.12, aspect: 16 / 9)
        XCTAssertEqual(p.x, -1.12 * 0.02 * 16 / 9 * 100, accuracy: 0.001)
        XCTAssertEqual(p.y, -1.12 * 0.02 * 100, accuracy: 0.001)
        // A middle near the edge is held inside the frame, as the video holds it: the framed part's own middle is used.
        let edge = Framing.rect(scale: 1.12, center: CGPoint(x: 0.6, y: 0.5))
        XCTAssertEqual(FCPXMLWriter.position(rect: edge, scale: 1.12, aspect: 16 / 9).x, -1.12 * (edge.midX - 0.5) * 16 / 9 * 100, accuracy: 0.001)
        XCTAssertEqual(edge.maxX, 1, accuracy: 1e-9, "never past the frame")
        XCTAssertEqual(FCPXMLWriter.time(0, .ntsc30), "0s")
        XCTAssertEqual(FCPXMLWriter.time(150, .ntsc30), "150150/30000s")
        XCTAssertEqual(FCPXMLWriter.formatName(width: 1920, height: 1080, frame: .ntsc30), "FFVideoFormat1080p2997")
        XCTAssertNil(FCPXMLWriter.formatName(width: 1080, height: 1920, frame: .ntsc30), "no name for a vertical picture")
    }

    // MARK: The lint catches what it is for

    func testTheLintCatchesEachRule() throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "lint-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let spec = try XCTUnwrap(Self.fixtures(in: scratch).first { $0.0 == "plain" }?.1)
        try Self.placeholders(spec)
        let xml = FCPXMLWriter.xml(spec, version: .finalCut)
        XCTAssertEqual(FCPXMLLint.check(xml), [])
        func rules(_ broken: String) -> Set<Int> { Set(FCPXMLLint.check(broken).map(\.rule)) }
        let layout = FCPXMLWriter.layout(spec)
        let second = layout.clips[1]
        // 1: a time that is not whole frames.
        XCTAssertTrue(rules(xml.replacingOccurrences(of: "offset=\"\(FCPXMLWriter.time(second.editStart, spec.frame))\"", with: "offset=\"1/7s\"")).contains(1))
        // 2: a gap in the spine.
        XCTAssertTrue(rules(xml.replacingOccurrences(of: "offset=\"\(FCPXMLWriter.time(second.editStart, spec.frame))\"",
                                                     with: "offset=\"\(FCPXMLWriter.time(second.editStart + 3, spec.frame))\"")).contains(2))
        // 3: the sequence's length.
        XCTAssertTrue(rules(xml.replacingOccurrences(of: "<sequence format=\"r1\" duration=\"\(FCPXMLWriter.time(layout.totalFrames, spec.frame))\"",
                                                     with: "<sequence format=\"r1\" duration=\"\(FCPXMLWriter.time(layout.totalFrames + 30, spec.frame))\"")).contains(3))
        // 4: a ref to nothing.
        XCTAssertTrue(rules(xml.replacingOccurrences(of: "<asset-clip ref=\"r2\"", with: "<asset-clip ref=\"r9\"")).contains(4))
        // 5: a source that is not there.
        try FileManager.default.removeItem(at: spec.media.url)
        XCTAssertTrue(rules(xml).contains(5))
        try Data([0]).write(to: spec.media.url)
        // 6: a transition with no media before the incoming clip.
        let big = FCPXMLWriter.time(Int64(120 / spec.frame.seconds), spec.frame)
        let withTransition = xml.replacingOccurrences(of: "            <asset-clip ref=\"r2\" name=\"Part 2\"",
                                                      with: "            <transition name=\"Cross Dissolve\" offset=\"0s\" duration=\"\(big)\"/>\n            <asset-clip ref=\"r2\" name=\"Part 2\"")
        XCTAssertTrue(rules(withTransition).contains(6), "\(FCPXMLLint.check(withTransition))")
        // 7: two captions overlapping, and a marker outside its clip.
        let firstCaption = try XCTUnwrap(xml.range(of: "              <caption "))
        let end = try XCTUnwrap(xml.range(of: "</caption>\n", range: firstCaption.upperBound..<xml.endIndex))
        let caption = String(xml[firstCaption.lowerBound..<end.upperBound])
        XCTAssertTrue(rules(xml.replacingCharacters(in: firstCaption.lowerBound..<end.upperBound, with: caption + caption)).contains(7))
        let close = try XCTUnwrap(xml.range(of: "            </asset-clip>"))
        let outside = xml.replacingCharacters(in: close.lowerBound..<close.lowerBound,
                                              with: "              <marker start=\"\(FCPXMLWriter.time(100_000, spec.frame))\" duration=\"1001/30000s\" value=\"x\"/>\n")
        XCTAssertTrue(rules(outside).contains(7), "\(FCPXMLLint.check(outside))")
    }

    // MARK: The refusal, and the gate on the media (v2 part M10b)

    func testOnlyAVideoOfUnknownPeopleIsRefusedAndHiddenPeopleNeedPrivacySafeMedia() {
        let plan = HookTests.talk(minutes: 1).plan
        XCTAssertNil(TimelineExport.refusal(plan: plan, hiddenFaces: 0, leftOutVoices: 0))
        XCTAssertNil(TimelineExport.refusal(plan: plan, hiddenFaces: 1, leftOutVoices: 0), "M10a's refusal of hidden people is lifted")
        XCTAssertNil(TimelineExport.refusal(plan: plan, hiddenFaces: 0, leftOutVoices: 1))
        XCTAssertEqual(TimelineExport.refusal(plan: plan, hiddenFaces: nil, leftOutVoices: 0), TimelineExport.unknownRefusal, "unknown is refused")
        XCTAssertFalse(CleanedMedia.needed(plan: plan, hiddenFaces: 0, leftOutVoices: 0), "everyone included: a clone")
        XCTAssertTrue(CleanedMedia.needed(plan: plan, hiddenFaces: 1, leftOutVoices: 0))
        XCTAssertTrue(CleanedMedia.needed(plan: plan, hiddenFaces: 0, leftOutVoices: 1))
        var leftOut = plan
        leftOut.people.leftOut = [2]
        XCTAssertTrue(CleanedMedia.needed(plan: leftOut, hiddenFaces: 0, leftOutVoices: 0))
        var cut = plan
        cut.people.cuts = [TimeRange(start: 10, end: 12)]
        XCTAssertTrue(CleanedMedia.needed(plan: cut, hiddenFaces: 0, leftOutVoices: 0))
        var muted = plan
        muted.people.mutes = [TimeRange(start: 10, end: 10.4)]
        XCTAssertTrue(CleanedMedia.needed(plan: muted, hiddenFaces: 0, leftOutVoices: 0), "a muted name: the media too")
        XCTAssertEqual(CleanedMedia.silenced(muted), [TimeRange(start: 10, end: 10.4)])
    }

    func testTheGateKeepsTimelinesOnlyWhenTheirMediaPassesItsChecks() throws {
        let passed = PictureCheck(checkedAt: Date(), frames: 50, faces: 0)
        let failed = PictureCheck(checkedAt: Date(), frames: 50, faces: 1, findings: [.init(at: 3, original: 9, box: FaceBox(x: 0.1, y: 0.1, width: 0.1, height: 0.1), how: "hidden")])
        let heard = AudioCheck(checkedAt: Date(), files: ["sound track 1 of the media"])
        let leak = AudioCheck(checkedAt: Date(), files: ["sound track 1 of the media"], findings: [.init(file: "sound track 1 of the media", at: 4, seconds: 2, voice: 2, how: "sounds like")])
        var whole = CleanedMedia.Check(picture: passed, sound: heard)
        whole.whole = true
        func facts(_ needed: Bool, _ safe: Bool, faces: Int = 1, voices: Int = 1, _ check: CleanedMedia.Check?) -> OutputGate.TimelineMediaFacts {
            OutputGate.TimelineMediaFacts(needed: needed, privacySafe: safe, hiddenFaces: faces, leftOutVoices: voices, check: check)
        }
        XCTAssertEqual(OutputGate.timelineMediaProblems(facts(false, false, faces: 0, voices: 0, nil)), [], "everyone included: a clone is right")
        XCTAssertEqual(OutputGate.timelineMediaProblems(facts(true, true, whole)), [], "privacy-safe media that passes")
        XCTAssertEqual(OutputGate.timelineMediaProblems(facts(true, false, nil)).count, 1, "a clone where anyone is hidden is never kept")
        var noPicture = whole
        noPicture.picture = nil
        XCTAssertTrue(OutputGate.timelineMediaProblems(facts(true, true, noPicture)).first?.contains("not checked") == true, "a needed check that did not run fails")
        var noSound = whole
        noSound.sound = nil
        XCTAssertTrue(OutputGate.timelineMediaProblems(facts(true, true, noSound)).first?.contains("not checked") == true)
        XCTAssertEqual(OutputGate.timelineMediaProblems(facts(true, true, faces: 0, voices: 0, noSound)), [], "no one left out: no sound check is needed")
        var badPicture = whole
        badPicture.picture = failed
        XCTAssertTrue(OutputGate.timelineMediaProblems(facts(true, true, badPicture)).first?.contains("cannot account for at 0:03") == true)
        var badSound = whole
        badSound.sound = leak
        XCTAssertTrue(OutputGate.timelineMediaProblems(facts(true, true, badSound)).first?.contains("whom you chose to leave out") == true)
        var loud = whole
        loud.silenceProblems = ["Sound track 1 of the media is 12.0 dB over its room tone at 0:04, where speech was removed."]
        XCTAssertEqual(OutputGate.timelineMediaProblems(facts(true, true, loud)), loud.silenceProblems)
        var broken = whole
        broken.whole = false
        XCTAssertEqual(OutputGate.timelineMediaProblems(facts(true, true, broken)).count, 1)
        // The gate refuses and deletes what was made.
        let staged = FileManager.default.temporaryDirectory.appending(path: "gate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        let to = staged.deletingLastPathComponent().appending(path: "gate-to-\(UUID().uuidString)")
        XCTAssertThrowsError(try OutputGate.admitTimeline(staged: staged, to: to, refusal: nil, problems: [], media: facts(true, false, nil)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: to.path))
    }

    // MARK: The privacy-safe media's arithmetic (v2 part M10b)

    func testTheUsedRangesAreTheKeptSpansWithTwoSecondHandlesJoined() {
        let fd = FrameDuration.ntsc30
        let video = EditTimeline(frame: fd, pieces: [
            .init(id: "h1", sourceFrame: 3_000, frames: 90, editFrame: 0, hook: true),
            .init(id: "k1", sourceFrame: 30, frames: 300, editFrame: 90),
            .init(id: "k2", sourceFrame: 400, frames: 300, editFrame: 390),
            .init(id: "k3", sourceFrame: 2_000, frames: 600, editFrame: 690),
            .init(id: "k4", sourceFrame: 3_050, frames: 100, editFrame: 1_290),
        ], holdFrames: 150)
        let handle = CleanedMedia.handleFrames(fd)
        XCTAssertEqual(handle, 60, "2 s at 29.97")
        let media = CleanedMedia.ranges(video, pictureFrames: 3_180, handle: handle)
        // k1 and k2 meet once their handles are on; k3 alone; the opening line, k4 and the held frame inside one range, cut at the end.
        XCTAssertEqual(media.pieces.map(\.sourceFrame), [0, 1_940, 2_940])
        XCTAssertEqual(media.pieces.map(\.frames), [760, 720, 240])
        XCTAssertEqual(media.pieces.map(\.editFrame), [0, 760, 1_480])
        XCTAssertEqual(media.totalFrames, 1_720)
        XCTAssertEqual(media.holdFrames, 0)
        // Every kept frame of the video, and every handle, is in the media, at one place.
        let spec = TimelineSpec.Media(name: "m", url: URL(fileURLWithPath: "/tmp/m.mov"), frames: media.totalFrames, width: 1920, height: 1080, ranges: media.pieces)
        for piece in video.pieces {
            for f in [piece.sourceFrame - handle, piece.sourceFrame, piece.sourceFrame + piece.frames - 1] where f >= 0 {
                let m = spec.frame(ofSource: f)
                XCTAssertTrue(m >= 0 && m < media.totalFrames, "\(f) maps to \(m)")
                let range = media.pieces.first { m >= $0.editFrame && m < $0.editFrame + $0.frames }!
                XCTAssertEqual(range.sourceFrame + (m - range.editFrame), f, "frame \(f) is the original's own frame")
            }
        }
        XCTAssertEqual(TimelineSpec.Media(name: "c", url: URL(fileURLWithPath: "/tmp/c.mp4"), frames: 9, width: 1, height: 1).frame(ofSource: 1_234), 1_234,
                       "a clone's clock is the original's")
    }

    func testTheRoomToneIsTheQuietestSecondWhereNobodySpeaks() {
        // 20 s in blocks of 50 ms: speech everywhere but a quiet second at 6 s and a quieter one at 12 s that a voice covers.
        var energy = [Double](repeating: 1e-2, count: 400)
        for i in 120..<140 { energy[i] = 1e-6 }
        for i in 240..<260 { energy[i] = 1e-8 }
        let busy = [TimeRange(start: 11.9, end: 13.2)]
        let tone = CleanedMedia.roomTone(blockEnergy: energy, blockSeconds: 0.05, busy: busy, duration: 20)
        XCTAssertEqual(tone.start, 6, accuracy: 0.001, "the quietest free second, not the one under a voice")
        XCTAssertEqual(tone.end - tone.start, CleanedMedia.roomToneSeconds, accuracy: 1e-9)
        // With speech everywhere, the quietest anywhere.
        let everywhere = CleanedMedia.roomTone(blockEnergy: energy, blockSeconds: 0.05, busy: [TimeRange(start: 0, end: 20)], duration: 20)
        XCTAssertEqual(everywhere.start, 12, accuracy: 0.001)
    }

    func testRemovedSpeechBecomesRoomToneWithABlendOutsideIt() {
        // One channel of loud speech, 1 s at 48 kHz; the room tone a quiet ramp; the region 0.4 to 0.6 s.
        var chunk = [Float](repeating: 0.8, count: 48_000)
        let tone = (0..<4_800).map { Float($0) / 4_800 * 0.01 }
        CleanedMedia.replace(&chunk, start: 0, channels: 1, regions: [(19_200, 28_800)], tone: tone, toneFrames: 4_800)
        XCTAssertTrue((19_200..<28_800).allSatisfy { chunk[$0] <= 0.01 }, "the whole region is room tone")
        XCTAssertEqual(chunk[19_200], tone[0], accuracy: 1e-6, "the tone starts from its beginning")
        XCTAssertEqual(chunk[19_200 + 4_800], tone[4_799], accuracy: 1e-6, "then runs back, so it never jumps")
        XCTAssertEqual(chunk[18_000], 0.8, "kept speech away from the region is untouched")
        XCTAssertTrue(chunk[18_900] < 0.8 && chunk[18_900] > 0.01, "the blend is outside the region")
        XCTAssertEqual(chunk[29_400], 0.8)
        // Stereo, and a region starting before the chunk.
        var stereo = [Float](repeating: 0.5, count: 2 * 1_000)
        let toneStereo = [Float](repeating: 0.001, count: 2 * 100)
        CleanedMedia.replace(&stereo, start: 5_000, channels: 2, regions: [(4_000, 5_500)], tone: toneStereo, toneFrames: 100)
        XCTAssertTrue((0..<1_000).allSatisfy { stereo[$0] == 0.001 }, "both channels of the first 500 frames")
        XCTAssertEqual(stereo[2 * 999], 0.5)
    }

    func testTheLintCatchesAClipPastItsMediaAndKeyedPushInsAreValid() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "lint8-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        var styled = try XCTUnwrap(Self.fixtures(in: scratch).first { $0.0 == "styled" }?.1)
        try Self.placeholders(styled)
        // Rule 8: the media made shorter than the clips that show it.
        var short = styled
        short.media.frames = 100
        XCTAssertTrue(FCPXMLLint.check(FCPXMLWriter.xml(short, version: .finalCut)).contains { $0.rule == 8 })
        XCTAssertFalse(FCPXMLLint.check(FCPXMLWriter.xml(styled, version: .finalCut)).contains { $0.rule == 8 })
        // Push-ins as moves, written only once the round trips pass (`TimelineAnimations.verified`, off in this build).
        XCTAssertFalse(TimelineAnimations.verified, "turned on only by a commit with the round trips' evidence")
        styled.animationsVerified = true
        let layout = FCPXMLWriter.layout(styled)
        let keyed = layout.clips.filter { !$0.keys.isEmpty }
        XCTAssertEqual(keyed.count, styled.framing.segments.filter { $0.easeFrames > 0 }.count, "every push-in keyed")
        XCTAssertEqual(layout.clips.filter(\.pushInHere).count, 0, "no marker once they are moves")
        for clip in keyed {
            XCTAssertEqual(clip.keys.first?.scale ?? 0, 1, accuracy: 0.001, "a push-in starts from the whole picture")
            XCTAssertGreaterThan(clip.keys.last?.scale ?? 0, 1)
        }
        let xml = FCPXMLWriter.xml(styled, version: .finalCut)
        XCTAssertTrue(xml.contains("<keyframeAnimation>"))
        XCTAssertEqual(FCPXMLLint.check(xml), [])
        if let dtds = try Self.dtds() {
            for version in FCPXMLVersion.allCases {
                let file = scratch.appending(path: "keyed \(version.rawValue).fcpxml")
                try FCPXMLWriter.xml(styled, version: version).write(to: file, atomically: true, encoding: .utf8)
                let dtd = await FCPXMLLint.validate(file, version: version, dtds: dtds)
                XCTAssertNil(dtd, "keyed push-ins against \(version.dtdName): \(dtd ?? "")")
            }
        }
    }

    // MARK: Clones, proved per file

    func testACloneIsProvedByTheFileItselfAndACopyIsNot() throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "clone-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let source = scratch.appending(path: "source.bin")
        try Data((0..<2_000_000).map { UInt8(truncatingIfNeeded: $0 &* 31) }).write(to: source)
        let (clone, cloned) = try TimelineMedia.clone(source, into: scratch.appending(path: "Media"))
        XCTAssertTrue(cloned)
        XCTAssertTrue(TimelineMedia.isClone(clone, of: source))
        let facts = try XCTUnwrap(TimelineMedia.cloneFacts(clone))
        XCTAssertEqual(facts.privateBytes, 0, "none of its bytes its own")
        let copy = scratch.appending(path: "copy.bin")
        try Data(contentsOf: source).write(to: copy)
        XCTAssertFalse(TimelineMedia.isClone(copy, of: source))
        XCTAssertGreaterThan(TimelineMedia.cloneFacts(copy)?.privateBytes ?? 0, 1_000_000)
    }

    // MARK: End to end on synthetic media

    @MainActor
    func testTheTimelinesAreMadeFromTheVideoCheckedAndKept() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "timeline-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let original = try await RenderTests.syntheticOriginal(in: scratch)
        let staging = scratch.appending(path: ".making pattern", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: RenderTests.transcript, to: staging.appending(path: TranscriptFiles.asHeard))
        let ffmpegURL = ToolPaths.standard.ffmpeg
        let planSetup = PlanStep.Setup(original: original, transcript: staging.appending(path: TranscriptFiles.asHeard),
                                       jobFolder: scratch.appending(path: "plan", directoryHint: .isDirectory), duration: 30, frameRate: 29.97)
        var plan = try await PlanStep.run(planSetup, now: Date()) { arguments in
            _ = try await Subprocess.run(ffmpegURL, arguments, captureStdout: false, timeout: .seconds(60))
        }.plan
        // The house style and a title, as a make plans them: punch-ins on a made-up face, the hold, the title for 2 s.
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: staging.appending(path: TranscriptFiles.asHeard)))).words
        plan.visual = VisualPlan.make(.init(plan: plan, words: words, style: Style.make(.standard), subject: StyleTests.face(minutes: 1),
                                            sourceHeight: 1080, outputHeight: 1080))
        plan.visual += TextPlan.make(plan: plan, setup: TextPlan.Setup(title: "A Test Pattern", faces: StyleTests.face(minutes: 1), pictureWidth: 1920),
                                     pictureHeight: 1080)
        try PlanStep.write(plan, into: staging)
        XCTAssertGreaterThan(plan.holdSeconds, 0)
        XCTAssertTrue(plan.visual.contains { $0.kind == EditPlan.Visual.title })

        let setup = VideoStep.Setup(original: original, plan: plan, transcript: staging.appending(path: TranscriptFiles.asHeard), staging: staging,
                                    title: "A Test Pattern", notes: "", written: nil, writtenToOriginal: { $0 }, recordedAt: nil,
                                    label: "Test pattern", people: RenderTests.everyoneIncluded())
        let made = try await VideoStep.make(setup, ffmpeg: RenderTests.ffmpeg())
        let video = try await VideoStep.check(made, setup: setup, ffprobe: RenderTests.ffprobe(), ffmpeg: RenderTests.ffmpeg(), now: Date())

        let output = scratch.appending(path: "Outputs/pattern", directoryHint: .isDirectory)
        let timelineFolder = output.appending(path: TimelineExport.folderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let export = TimelineExport.Setup(original: original, plan: plan, videoFolder: staging.appending(path: VideoStep.folderName), captionsName: video.captionsName,
                                          project: "Test pattern, Clear", build: scratch.appending(path: "Outputs/.timeline pattern"), final: timelineFolder,
                                          admitTo: timelineFolder, hiddenFaces: video.hiddenFaces, leftOutVoices: video.leftOutVoices)
        let started = Date()
        let record = try await TimelineExport.make(export, now: Date())
        print(String(format: "Timelines written in %.1f s: %@ DTD %@", Date().timeIntervalSince(started), record.summary, "\(record.dtd)"))
        let files = Set(Pipeline.madeFiles(in: timelineFolder))
        XCTAssertEqual(files, [FCPXMLVersion.finalCut.fileName, FCPXMLVersion.resolve.fileName, video.captionsName, TimelineReadMe.fileName,
                               GraphicsClips.folderName, TimelineMedia.folderName])
        XCTAssertFalse(FileManager.default.fileExists(atPath: export.build.path), "the working folder is gone")
        XCTAssertTrue(TimelineMedia.isClone(timelineFolder.appending(path: "Media/pattern.mp4"), of: original), "the media is a clone")
        XCTAssertTrue(record.mediaCloned)
        let graphics = Set(Pipeline.madeFiles(in: timelineFolder.appending(path: GraphicsClips.folderName)))
        XCTAssertEqual(graphics, ["Title.mov", "Held last frame.mov"])
        if FCPXMLLint.dtdFolder() != nil {
            XCTAssertEqual(record.dtd, ["1.14": "valid", "1.10": "valid"])
        }
        for version in FCPXMLVersion.allCases {
            let xml = try String(contentsOf: timelineFolder.appending(path: version.fileName), encoding: .utf8)
            XCTAssertEqual(FCPXMLLint.check(xml), [], "\(version.rawValue) in place: every src there")
            XCTAssertFalse(xml.contains(scratch.appending(path: "pattern.mp4").path), "never the original")
            XCTAssertEqual(record.frames, made.timeline.totalFrames, "the timeline is the video's length in frames")
        }
        let readMe = try String(contentsOf: timelineFolder.appending(path: TimelineReadMe.fileName), encoding: .utf8)
        XCTAssertEqual(readMe.split(separator: "\n").count, 5)
        XCTAssertFalse(readMe.contains("\u{2014}") || readMe.contains("\u{2013}"))

        // The title clip: ProRes 4444 with its transparency, and what it draws is what the compositor draws.
        let title = timelineFolder.appending(path: "Graphics/Title.mov")
        let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-select_streams", "v:0", "-show_entries",
                                                                          "stream=codec_name,profile,pix_fmt,width,height,r_frame_rate,nb_frames", "-of", "compact", title.path]).stdout
        print("Title clip: " + probe.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertTrue(probe.contains("codec_name=prores") && probe.contains("profile=4444") && probe.contains("pix_fmt=yuva444p"), probe)
        let item = try XCTUnwrap(plan.visual.first { $0.kind == EditPlan.Visual.title })
        var one = plan
        one.visual = [item]
        let maybeTable = await OverlayTable.make(plan: one, timeline: made.timeline, renderSize: CGSize(width: 1920, height: 1080))
        let table = try XCTUnwrap(maybeTable)
        let placed = try XCTUnwrap(table.items.first)
        for k in [Int64(3), placed.frames / 2] {
            let png = scratch.appending(path: "title-\(k).png")
            _ = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-v", "error", "-y", "-i", title.path, "-vf", "select=eq(n\\,\(k))", "-frames:v", "1",
                                                                     "-pix_fmt", "rgba", png.path], captureStdout: false, timeout: .seconds(60))
            let decoded = try Self.rgba(XCTUnwrap(CGImageSourceCreateImageAtIndex(XCTUnwrap(CGImageSourceCreateWithURL(png as CFURL, nil)), 0, nil)))
            var drawn = CIImage(color: .clear).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
            for layer in table.layers(atEditFrame: placed.start + k) { drawn = layer.composited(over: drawn) }
            let expected = try Self.rgba(XCTUnwrap(CIContext().createCGImage(drawn, from: drawn.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))))
            let opaque = decoded.enumerated().filter { $0.offset % 4 == 3 && $0.element == 255 }.count, clear = decoded.enumerated().filter { $0.offset % 4 == 3 && $0.element == 0 }.count
            let db = Self.psnr(decoded, expected)
            print(String(format: "Title frame %lld: %.1f dB against the compositor's own drawing; %d pixels opaque, %d clear", k, db, opaque, clear))
            XCTAssertGreaterThanOrEqual(db, 35, "the clip draws what the video draws")
            XCTAssertGreaterThan(clear, 1920 * 1080 / 2, "most of the frame is transparent")
            if k == placed.frames / 2 { XCTAssertGreaterThan(opaque, 1_000, "the letters are solid") }
        }
        let held = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-select_streams", "v:0", "-count_frames", "-show_entries",
                                                                         "stream=codec_name,nb_read_frames", "-of", "compact",
                                                                         timelineFolder.appending(path: "Graphics/Held last frame.mov").path]).stdout
        XCTAssertTrue(held.contains("codec_name=prores") && held.contains("nb_read_frames=\(made.timeline.holdFrames)"), held)

        // v2 part M10b: someone hidden and a name muted. The timelines point at privacy-safe media: only the used ranges with their
        // handles, the hidden face's place blurred on every frame (a made-up track over the test pattern, no face of anyone), the
        // muted stretch room tone, checked inside the gate, and never the clone.
        var hidden = plan
        hidden.people.mutes = [TimeRange(start: 6.0, end: 7.0)]
        let box = FaceBox(x: 0.40, y: 0.30, width: 0.18, height: 0.30)
        let spots = stride(from: 0.0, through: 30.0, by: 0.5).map { HiddenTrack.Spot(time: $0, box: box) }
        var people = CleanedMedia.People()
        people.hiding = HidePlan(tracks: [HiddenTrack(id: 1, spots: spots)])
        people.faceTracks = [PictureOutputCheck.Track(id: 1, hidden: true, spots: spots)]
        people.hiddenFaces = 1
        let safeFolder = output.appending(path: "Safe", directoryHint: .isDirectory)
        var safe = export
        safe.plan = hidden
        safe.hiddenFaces = 1
        safe.final = safeFolder
        safe.admitTo = safeFolder
        safe.build = scratch.appending(path: "Outputs/.timeline safe", directoryHint: .isDirectory)
        // Without the people check's facts it is refused, fail closed.
        do {
            _ = try await TimelineExport.make(safe, now: Date())
            XCTFail("hidden people with no people facts are refused")
        } catch let failure as TimelineExport.Failure {
            XCTAssertEqual(failure.reason, TimelineExport.peopleUnreadable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: safeFolder.path))
        safe.people = people
        safe.ffmpeg = RenderTests.ffmpeg()
        let safeStarted = Date()
        let safeRecord = try await TimelineExport.make(safe, now: Date())
        let mediaName = TimelineMedia.privacySafeName(original)
        let media = safeFolder.appending(path: TimelineMedia.folderName).appending(path: mediaName)
        print(String(format: "Privacy-safe timelines in %.1f s: %@ media %@, %lld bytes, %.2f s, %d ranges; check %@", Date().timeIntervalSince(safeStarted),
                     safeRecord.summary, mediaName, safeRecord.mediaBytes ?? -1, safeRecord.mediaSeconds ?? -1, safeRecord.mediaRanges ?? -1,
                     "\(String(describing: safeRecord.mediaCheck))"))
        XCTAssertEqual(safeRecord.privacySafe, true)
        XCTAssertFalse(safeRecord.mediaCloned)
        XCTAssertEqual(Pipeline.madeFiles(in: safeFolder.appending(path: TimelineMedia.folderName)), [mediaName], "the safe copy only, never a clone")
        XCTAssertFalse(TimelineMedia.isClone(media, of: original))
        let check = try XCTUnwrap(safeRecord.mediaCheck)
        XCTAssertTrue(check.whole, check.wholeLine)
        XCTAssertEqual(check.picture?.passed, true, "the picture output check ran on the media and passed")
        XCTAssertGreaterThanOrEqual(check.replacedStretches, 1)
        XCTAssertEqual(check.silenceProblems, [])
        // HEVC Main 10, PCM, the ranges' length.
        let mediaProbe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-show_entries", "stream=codec_type,codec_name,profile,pix_fmt,channels",
                                                                               "-of", "compact=p=0", media.path]).stdout
        print("Privacy-safe media: " + mediaProbe.replacingOccurrences(of: "\n", with: "; "))
        XCTAssertTrue(mediaProbe.contains("codec_name=hevc") && mediaProbe.contains("profile=Main 10") && mediaProbe.contains("pix_fmt=yuv420p10le"), mediaProbe)
        XCTAssertTrue(mediaProbe.contains("codec_name=pcm_s24le"), mediaProbe)
        let pictureFrames = try await CompositionBuilder.pictureFrames(original: original, plan: hidden)
        let ranges = CleanedMedia.ranges(EditTimeline(plan: hidden, pictureFrames: pictureFrames), pictureFrames: pictureFrames,
                                         handle: CleanedMedia.handleFrames(hidden.frameDuration))
        XCTAssertEqual(safeRecord.mediaSeconds ?? 0, ranges.duration, accuracy: 1e-6, "the used ranges plus 2 s handles")
        // Both files valid in place, every clip on the media's own clock, the Read Me says so.
        for version in FCPXMLVersion.allCases {
            let xml = try String(contentsOf: safeFolder.appending(path: version.fileName), encoding: .utf8)
            XCTAssertEqual(FCPXMLLint.check(xml), [], "\(version.rawValue) on the privacy-safe media")
            XCTAssertTrue(xml.contains(FCPXMLWriter.fileURL(media)), "points at the safe copy")
            XCTAssertFalse(xml.contains(FCPXMLWriter.fileURL(original)) || xml.contains(original.path), "never the original")
        }
        if FCPXMLLint.dtdFolder() != nil { XCTAssertEqual(safeRecord.dtd, ["1.14": "valid", "1.10": "valid"]) }
        let safeReadMe = try String(contentsOf: safeFolder.appending(path: TimelineReadMe.fileName), encoding: .utf8)
        XCTAssertEqual(safeReadMe.split(separator: "\n").count, 5)
        XCTAssertTrue(safeReadMe.contains("privacy-safe copy"))
        // Each spine clip shows the original's own frame at its start (outside the hidden place), and the hidden place is blurred.
        let layout = FCPXMLWriter.layout(TimelineSpec(project: "", frame: hidden.frameDuration, width: 1920, height: 1080,
                                                      media: .init(name: "m", url: media, frames: ranges.totalFrames, width: 1920, height: 1080, ranges: ranges.pieces),
                                                      timeline: EditTimeline(plan: hidden, pictureFrames: pictureFrames), framing: Framing()))
        let videoTimeline = EditTimeline(plan: hidden, pictureFrames: pictureFrames)
        var checked = 0
        for (clip, piece) in zip(layout.clips.filter { $0.asset == "media" }, videoTimeline.pieces).prefix(4) {
            let fromMedia = try await RenderTests.frame(AVURLAsset(url: media), at: videoTimeline.time(clip.sourceStart + 2))
            let fromOriginal = try await RenderTests.frame(AVURLAsset(url: original), at: videoTimeline.time(piece.sourceFrame + 2))
            let outside = PeopleInVideoTests.variance(fromMedia, in: FaceBox(x: 0.02, y: 0.7, width: 0.3, height: 0.25))
            let outsideOriginal = PeopleInVideoTests.variance(fromOriginal, in: FaceBox(x: 0.02, y: 0.7, width: 0.3, height: 0.25))
            let inside = PeopleInVideoTests.variance(fromMedia, in: box), insideOriginal = PeopleInVideoTests.variance(fromOriginal, in: box)
            print(String(format: "Clip at media frame %lld = original frame %lld: outside the hidden place variance %.1f against %.1f; inside %.1f against %.1f",
                         clip.sourceStart + 2, piece.sourceFrame + 2, outside, outsideOriginal, inside, insideOriginal))
            XCTAssertEqual(outside, outsideOriginal, accuracy: max(5, outsideOriginal * 0.1), "the same frame of the original")
            XCTAssertLessThan(inside, insideOriginal * 0.5, "the hidden place is burned in")
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 2)
        // The muted stretch is room tone in the media, and was speech in the original.
        let muteAt = try XCTUnwrap(ranges.pieces.first { 6.0 >= ranges.seconds($0.sourceFrame) && 7.0 <= ranges.seconds($0.sourceFrame + $0.frames) })
        let mediaStart = ranges.seconds(muteAt.editFrame) + 6.0 - ranges.seconds(muteAt.sourceFrame)
        func level(_ file: URL, at start: Double) async throws -> Double {
            let out = try await Subprocess.run(ToolPaths.standard.ffmpeg, ["-hide_banner", "-nostats", "-ss", String(format: "%.3f", start + 0.05), "-t", "0.9",
                                                                           "-i", file.path, "-vn", "-af", "volumedetect", "-f", "null", "-"]).stderr
            return Double(out.components(separatedBy: "mean_volume: ").last?.split(separator: " ").first ?? "") ?? 0
        }
        let mediaLevel = try await level(media, at: mediaStart), originalLevel = try await level(original, at: 6.0)
        print(String(format: "The muted second: %.1f dB in the original, %.1f dB in the media", originalLevel, mediaLevel))
        XCTAssertLessThan(mediaLevel, originalLevel - 20, "the muted second is room tone")
    }

    /// The picture's bytes, premultiplied RGBA 8-bit, 1920 by 1080.
    static func rgba(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 1920 * 1080 * 4)
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: 1920 * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        }
        return bytes
    }

    static func psnr(_ a: [UInt8], _ b: [UInt8]) -> Double {
        var sum = 0.0
        for k in 0..<min(a.count, b.count) {
            let d = Double(a[k]) - Double(b[k])
            sum += d * d
        }
        let mse = sum / Double(max(1, min(a.count, b.count)))
        return mse == 0 ? 99 : 10 * log10(255 * 255 / mse)
    }
}
