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
/// - The refusal: anyone hidden or left out, or a muted name, and nothing is written.
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

    // MARK: The refusal

    func testATimelineIsRefusedWhenAnyoneIsHiddenOrANameIsMuted() {
        let plan = HookTests.talk(minutes: 1).plan
        XCTAssertNil(TimelineExport.refusal(plan: plan, hiddenFaces: 0, leftOutVoices: 0))
        XCTAssertEqual(TimelineExport.refusal(plan: plan, hiddenFaces: 1, leftOutVoices: 0), TimelineExport.hiddenRefusal)
        XCTAssertEqual(TimelineExport.refusal(plan: plan, hiddenFaces: 0, leftOutVoices: 1), TimelineExport.hiddenRefusal)
        XCTAssertEqual(TimelineExport.refusal(plan: plan, hiddenFaces: nil, leftOutVoices: 0), TimelineExport.unknownRefusal, "unknown is refused")
        var leftOut = plan
        leftOut.people.leftOut = [2]
        XCTAssertEqual(TimelineExport.refusal(plan: leftOut, hiddenFaces: 0, leftOutVoices: 0), TimelineExport.hiddenRefusal)
        var cut = plan
        cut.people.cuts = [TimeRange(start: 10, end: 12)]
        XCTAssertEqual(TimelineExport.refusal(plan: cut, hiddenFaces: 0, leftOutVoices: 0), TimelineExport.hiddenRefusal)
        var muted = plan
        muted.people.mutes = [TimeRange(start: 10, end: 10.4)]
        XCTAssertEqual(TimelineExport.refusal(plan: muted, hiddenFaces: 0, leftOutVoices: 0), TimelineExport.mutedRefusal)
        XCTAssertEqual(TimelineExport.hiddenRefusal, "A timeline for a recording with hidden people arrives in the next update.")
        // The gate refuses and deletes what was made.
        let staged = FileManager.default.temporaryDirectory.appending(path: "gate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        let to = staged.deletingLastPathComponent().appending(path: "gate-to-\(UUID().uuidString)")
        XCTAssertThrowsError(try OutputGate.admitTimeline(staged: staged, to: to, refusal: TimelineExport.hiddenRefusal, problems: []))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: to.path))
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

        // Refused: someone left out, and nothing is kept.
        var hidden = plan
        hidden.people.leftOut = [2]
        var refused = export
        refused.plan = hidden
        refused.final = output.appending(path: "Refused", directoryHint: .isDirectory)
        refused.admitTo = refused.final
        do {
            _ = try await TimelineExport.make(refused, now: Date())
            XCTFail("a plan with someone left out is refused")
        } catch let failure as TimelineExport.Failure {
            XCTAssertEqual(failure.reason, TimelineExport.hiddenRefusal)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: refused.final.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: refused.build.path))
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
