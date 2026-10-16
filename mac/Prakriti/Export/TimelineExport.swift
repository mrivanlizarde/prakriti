import CoreGraphics
import Foundation

// Making the timelines (v2 part M10a, docs/v2/PLAN.md M10): the `Timeline` folder in the recording's output folder, beside the
// edited video and made from the same plan the video was made from:
//
//   Timeline/
//     Edit for Final Cut Pro.fcpxml     FCPXML 1.14
//     Edit for DaVinci Resolve.fcpxml   the same edit, FCPXML 1.10
//     <video name>.srt                  the video's own captions, for an app that drops caption lanes
//     Read Me.txt                       five lines: how to open each, what is switched off
//     Graphics/                         every text as ProRes 4444 with transparency, and the held last frame
//     Media/                            an APFS clone of the recording, or its privacy-safe copy (v2 part M10b)
//
// **A timeline never points at the recording while anyone is hidden or left out, or a name is muted** (PLAN M10, R2): an editable
// timeline points at whole media files, so one drag of a clip edge or one switched-off blur would undo a privacy choice. Part M10a
// refused those recordings; part M10b writes them against privacy-safe media instead (`CleanedMedia`: only the used ranges with
// 2 s handles, faces burned in, removed speech replaced by room tone on every track, a left-out person's own microphone track left
// out), which passes the MP4's own picture and sound output checks inside `OutputGate` before any timeline that points at it is
// kept. With everyone included and nothing muted, `Media/` is a clone, as before.
//
// Everything is made in a hidden folder, checked (the lint and Final Cut Pro's own DTDs on both files, every clip's last frames
// decoded), and only then moved into place by `OutputGate.admitTimeline` (PLAN 2.1.11). A timeline that fails is deleted where it
// was made. Nothing here reaches the network (RulesTests).

enum TimelineExport {
    static let folderName = "Timeline"
    /// What was made, beside the files (hidden: Ivan's Finder shows only the files he uses).
    static let recordName = ".timeline.json"

    static let unknownRefusal = "Make the video again first, so Prakriti knows who is in it, then make the timelines."
    static let behindRefusal = "Your newest choices of who is hidden or heard in the video are not in it yet. Make the video again, then make the timelines."
    static let peopleUnreadable = "Who is hidden in the video could not be read from the people check, so no timeline was written. Click Check People, then make the timelines again."

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// What a make of the timelines left, read back by the inspector and the File menu.
    struct Record: Codable, Equatable, Sendable {
        var madeAt: Date
        /// The plan they were made from (`EditPlan.madeAt`), so a newer plan or another version says they are behind.
        var planMadeAt: Date
        var project: String
        var seconds: Double
        var frames: Int64
        var clips: Int
        var graphics: Int
        var captions: Int
        var chapters: Int
        var markers: Int
        var pushInMarkers: Int
        var mediaName: String
        var mediaCloned: Bool
        var captionsName: String
        /// Each version's DTD check: "valid", or why it was not checked.
        var dtd: [String: String]
        /// The privacy-safe media (v2 part M10b), when anyone is hidden or left out or a name is muted: its size, length, how long it
        /// took, the ranges it holds, the audio tracks left out (OBS numbers) and what its checks found. Nil for a clone.
        var privacySafe: Bool?
        var mediaBytes: Int64?
        var mediaSeconds: Double?
        var mediaRenderSeconds: Double?
        var mediaRanges: Int?
        var tracksLeftOut: [Int]?
        var mediaCheck: CleanedMedia.Check?

        /// "4:57, 31 clips, 3 texts, captions and 2 chapters."
        var summary: String {
            var parts = [Format.timecode(seconds), Format.count(clips, "clip")]
            if graphics > 0 { parts.append(Format.count(graphics, "text")) }
            if captions > 0 { parts.append("captions") }
            if chapters > 0 { parts.append(Format.count(chapters, "chapter")) }
            return EditPlan.joined(parts) + "."
        }

        func encoded() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(self)
        }

        static func read(_ timelineFolder: URL) -> Record? {
            guard let data = try? Data(contentsOf: timelineFolder.appending(path: recordName)) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(Record.self, from: data)
        }
    }

    /// Why no timeline is written for this plan, or nil when it may be. `hiddenFaces` and `leftOutVoices` are the video's own counts
    /// (nil for a video made before part M8d: who is in it is unknown, so refused). Since part M10b anyone may be hidden or left out
    /// and a name muted: the timelines then point at privacy-safe media (`CleanedMedia.needed`).
    static func refusal(plan: EditPlan, hiddenFaces: Int?, leftOutVoices: Int?) -> String? {
        if hiddenFaces == nil || leftOutVoices == nil { return unknownRefusal }
        // A moment from another recording (v2 part M12b) needs that recording's media in the timeline too, which the timelines do not
        // carry yet: refused in words rather than written without it (the timeline would not be the video).
        if !plan.insertSpans.isEmpty { return momentsRefusal }
        return nil
    }

    static let momentsRefusal = "The video has a moment from another recording, and timelines with one are not made yet. The video itself has it. Remove the moment in Direction to make timelines."

    /// Whether this plan's timelines need privacy-safe media, from the video's counts.
    static func needsPrivacySafeMedia(_ setup: Setup) -> Bool {
        CleanedMedia.needed(plan: setup.plan, hiddenFaces: setup.hiddenFaces ?? 0, leftOutVoices: setup.leftOutVoices ?? 0)
    }

    struct Setup: Sendable {
        var original: URL
        var plan: EditPlan
        /// The kept video's folder and its captions file's name.
        var videoFolder: URL
        var captionsName: String
        /// The project's name in the app: "Sun 13 Sep, Clear".
        var project: String
        /// An empty working folder the timeline is made in (it is removed).
        var build: URL
        /// Where the `Timeline` folder will be once it is in place: every path inside the files points here.
        var final: URL
        /// Where the gate moves it (the make's staging folder's `Timeline`, or `final` itself).
        var admitTo: URL
        var hiddenFaces: Int?
        var leftOutVoices: Int?
        var animationsVerified = TimelineAnimations.verified
        /// Who is hidden and left out (v2 part M10b), read from the people check: needed for the privacy-safe media. Nil when it
        /// could not be read, which refuses any plan that needs that media (fail closed).
        var people: CleanedMedia.People?
        /// Runs ffmpeg for the privacy-safe media's sound and its checks.
        var ffmpeg: CleanedMedia.Tool?
    }

    /// Makes, checks and admits the timelines. Throws `Failure` with one plain sentence, after deleting what it made.
    static func make(_ setup: Setup, now: Date, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Record {
        if let refusal = refusal(plan: setup.plan, hiddenFaces: setup.hiddenFaces, leftOutVoices: setup.leftOutVoices) {
            throw Failure(reason: refusal)
        }
        if needsPrivacySafeMedia(setup) && (setup.people == nil || setup.ffmpeg == nil) { throw Failure(reason: peopleUnreadable) }
        let fm = FileManager.default
        try? fm.removeItem(at: setup.build)
        try fm.createDirectory(at: setup.build, withIntermediateDirectories: true)
        do {
            let record = try await build(setup, now: now, progress: progress)
            let media = OutputGate.TimelineMediaFacts(needed: needsPrivacySafeMedia(setup), privacySafe: record.privacySafe == true,
                                                      hiddenFaces: setup.hiddenFaces ?? 0, leftOutVoices: setup.leftOutVoices ?? 0, check: record.mediaCheck)
            try OutputGate.admitTimeline(staged: setup.build, to: setup.admitTo,
                                         refusal: refusal(plan: setup.plan, hiddenFaces: setup.hiddenFaces, leftOutVoices: setup.leftOutVoices),
                                         problems: try await check(setup, record: record), media: media)
            return record
        } catch let refused as OutputGate.Refused {
            try? fm.removeItem(at: setup.build)
            throw Failure(reason: refused.reason)
        } catch let failure as GraphicsClips.Failure {
            try? fm.removeItem(at: setup.build)
            throw Failure(reason: failure.reason)
        } catch let failure as CleanedMedia.Failure {
            try? fm.removeItem(at: setup.build)
            throw Failure(reason: failure.reason)
        } catch let failure as VideoHiding.Failure {
            try? fm.removeItem(at: setup.build)
            throw Failure(reason: failure.reason)
        } catch {
            try? fm.removeItem(at: setup.build)
            throw error
        }
    }

    /// Everything written into `setup.build`.
    private static func build(_ setup: Setup, now: Date, progress: @escaping @Sendable (Double) -> Void) async throws -> Record {
        let plan = setup.plan, fd = plan.frameDuration
        let mediaFolder = setup.build.appending(path: TimelineMedia.folderName, directoryHint: .isDirectory)
        let pictureFrames = try await CompositionBuilder.pictureFrames(original: setup.original, plan: plan)
        let timeline = EditTimeline(plan: plan, pictureFrames: pictureFrames)
        // Media: the clone, or (anyone hidden or left out, or a name muted) the privacy-safe copy, checked before anything points at it.
        var media: TimelineSpec.Media
        var mediaFile: URL
        var cloned = false
        var safe: (made: CleanedMedia.Made, check: CleanedMedia.Check, bytes: Int64)?
        var mediaShare = 0.05
        if needsPrivacySafeMedia(setup), let people = setup.people, let ffmpeg = setup.ffmpeg {
            mediaShare = 0.8
            try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            let name = TimelineMedia.privacySafeName(setup.original)
            let made = try await CleanedMedia.make(original: setup.original, plan: plan, people: people, to: mediaFolder.appending(path: name),
                                                   job: setup.build.appending(path: ".media-job", directoryHint: .isDirectory), ffmpeg: ffmpeg,
                                                   progress: { progress(0.6 * $0) })
            let check = try await CleanedMedia.check(made, original: setup.original, people: people, ffmpeg: ffmpeg, now: now,
                                                     progress: { progress(0.6 + 0.2 * $0) })
            mediaFile = made.url
            let bytes = (try? made.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            safe = (made, check, bytes)
            media = try await TimelineMedia.info(made.url, name: (name as NSString).deletingPathExtension,
                                                 finalURL: setup.final.appending(path: TimelineMedia.folderName).appending(path: name), frame: fd)
            media.ranges = made.timeline.pieces
            media.audioSources = max(1, made.tracksKept.count)
        } else {
            let clone = try TimelineMedia.clone(setup.original, into: mediaFolder)
            mediaFile = clone.url
            cloned = clone.cloned
            media = try await TimelineMedia.info(clone.url, name: setup.original.deletingPathExtension().lastPathComponent,
                                                 finalURL: setup.final.appending(path: TimelineMedia.folderName).appending(path: setup.original.lastPathComponent), frame: fd)
        }
        progress(mediaShare)
        let graphicsFrom = mediaShare
        guard timeline.totalFrames > 0 else { throw Failure(reason: "The plan keeps no frame of the picture, so no timeline was written.") }
        let size = CGSize(width: media.width, height: media.height)
        // Graphics: every text, then the held last frame.
        let graphicsFolder = setup.build.appending(path: GraphicsClips.folderName, directoryHint: .isDirectory)
        let finalGraphics = setup.final.appending(path: GraphicsClips.folderName, directoryHint: .isDirectory)
        let graphics = try await GraphicsClips.make(plan: plan, timeline: timeline, renderSize: size, into: graphicsFolder, finalFolder: finalGraphics,
                                                    progress: { progress(graphicsFrom + (0.9 - graphicsFrom) * $0) })
        var held: TimelineSpec.Clip?
        if timeline.holdFrames > 0, let frame = timeline.holdSourceFrame {
            try FileManager.default.createDirectory(at: graphicsFolder, withIntermediateDirectories: true)
            let name = GraphicsClips.heldName + ".mov"
            try await GraphicsClips.writeHeld(media: mediaFile, sourceFrame: media.frame(ofSource: frame), frame: fd, frames: timeline.holdFrames,
                                              to: graphicsFolder.appending(path: name))
            held = TimelineSpec.Clip(name: GraphicsClips.heldName, url: finalGraphics.appending(path: name), kind: nil, start: timeline.keptFrames, frames: timeline.holdFrames)
        }
        progress(0.9)
        // The video's own captions, and a copy of its .srt beside the files.
        let srt = setup.videoFolder.appending(path: setup.captionsName)
        let cues = (try? String(contentsOf: srt, encoding: .utf8)).map { Captions.cues(srt: $0) } ?? []
        if FileManager.default.fileExists(atPath: srt.path) {
            try FileManager.default.copyItem(at: srt, to: setup.build.appending(path: setup.captionsName))
        }
        // Chapters on the video's clock; the plan's moments to check, from their word.
        let chapters = plan.chapters.compactMap { c in c.seconds.map { TimelineSpec.Mark(frame: Int64(($0 / fd.seconds).rounded()), text: c.title) } }
        let times = Dictionary(plan.words.map { ($0.id, $0.in) }, uniquingKeysWith: { a, _ in a })
        let checks = plan.checks.compactMap { c -> TimelineSpec.Mark? in
            guard let original = times[c.at], let edited = timeline.editTime(original) else { return nil }
            return TimelineSpec.Mark(frame: Int64((edited / fd.seconds).rounded()), text: c.say)
        }
        let spec = TimelineSpec(project: setup.project, frame: fd, width: media.width, height: media.height, media: media, timeline: timeline,
                                framing: Framing(plan: plan, timeline: timeline), graphics: graphics, held: held, captions: cues, chapters: chapters,
                                checks: checks, animationsVerified: setup.animationsVerified)
        let layout = FCPXMLWriter.layout(spec)
        for version in FCPXMLVersion.allCases {
            try FCPXMLWriter.xml(spec, layout: layout, version: version).write(to: setup.build.appending(path: version.fileName), atomically: true, encoding: .utf8)
        }
        try TimelineReadMe.text(captions: setup.captionsName, privacySafe: safe != nil).write(to: setup.build.appending(path: TimelineReadMe.fileName), atomically: true, encoding: .utf8)
        // Final Cut Pro's own DTDs, when it is on this Mac, copied where the path has no space: xmllint cannot resolve a DTD whose
        // path has one (measured 15 Oct: "parser error : xmlSAX2ResolveEntity" from the recording's own folder, valid from /tmp).
        let dtds = FileManager.default.temporaryDirectory.appending(path: "prakriti-dtd-\(UUID().uuidString)", directoryHint: .isDirectory)
        var dtd: [String: String] = [:]
        if FCPXMLLint.copyDTDs(to: dtds) {
            for version in FCPXMLVersion.allCases {
                dtd[version.rawValue] = await FCPXMLLint.validate(setup.build.appending(path: version.fileName), version: version, dtds: dtds) ?? "valid"
            }
        } else {
            for version in FCPXMLVersion.allCases { dtd[version.rawValue] = "not checked: Final Cut Pro is not on this Mac" }
        }
        try? FileManager.default.removeItem(at: dtds)
        let record = Record(madeAt: now, planMadeAt: plan.madeAt, project: setup.project, seconds: timeline.duration, frames: layout.totalFrames,
                            clips: layout.clips.count, graphics: graphics.count, captions: layout.captions, chapters: layout.chapterMarkers,
                            markers: layout.markers, pushInMarkers: layout.clips.filter(\.pushInHere).count, mediaName: mediaFile.lastPathComponent,
                            mediaCloned: cloned, captionsName: setup.captionsName, dtd: dtd, privacySafe: safe == nil ? nil : true, mediaBytes: safe?.bytes,
                            mediaSeconds: safe.map { $0.made.timeline.duration }, mediaRenderSeconds: safe?.made.seconds, mediaRanges: safe?.made.timeline.pieces.count,
                            tracksLeftOut: safe?.made.tracksLeftOut, mediaCheck: safe?.check)
        try record.encoded().write(to: setup.build.appending(path: recordName), options: .atomic)
        progress(1)
        return record
    }

    /// What the gate reads: the lint on both files (every path mapped to where it is now), each DTD check that ran and failed,
    /// and every clip's last frames. Empty when everything passes.
    private static func check(_ setup: Setup, record: Record) async throws -> [String] {
        var problems: [String] = []
        let finalPrefix = setup.final.standardizedFileURL.path, buildPrefix = setup.build.standardizedFileURL.path
        let resolve: (URL) -> URL = { url in
            let path = url.standardizedFileURL.path
            return path.hasPrefix(finalPrefix) ? URL(fileURLWithPath: buildPrefix + path.dropFirst(finalPrefix.count)) : url
        }
        for version in FCPXMLVersion.allCases {
            let xml = try String(contentsOf: setup.build.appending(path: version.fileName), encoding: .utf8)
            for problem in FCPXMLLint.check(xml, resolve: resolve).prefix(5) {
                problems.append("The \(version.appName) timeline failed its check (\(problem)).")
            }
            if xml.contains(FCPXMLWriter.fileURL(setup.original)) || xml.contains(setup.original.path) {
                problems.append("The \(version.appName) timeline points at the original recording.")
            }
            if let result = record.dtd[version.rawValue], result != "valid", !result.hasPrefix("not checked") {
                let first = result.split(separator: "\n").first.map(String.init) ?? result
                problems.append("The \(version.appName) timeline is not valid FCPXML \(version.rawValue) (\(first)).")
            }
        }
        let graphics = setup.build.appending(path: GraphicsClips.folderName, directoryHint: .isDirectory)
        for name in Pipeline.madeFiles(in: graphics) where await TimelineMedia.tailFrames(graphics.appending(path: name)) == 0 {
            problems.append("The graphics clip \(name) does not decode to its end.")
        }
        let media = setup.build.appending(path: TimelineMedia.folderName).appending(path: record.mediaName)
        if await TimelineMedia.tailFrames(media) == 0 { problems.append("The media copy's last 5 seconds do not decode.") }
        // Nothing in the Media folder but the one file the timelines point at: never a stray copy of the recording.
        let others = Pipeline.madeFiles(in: setup.build.appending(path: TimelineMedia.folderName, directoryHint: .isDirectory)).filter { $0 != record.mediaName }
        if !others.isEmpty { problems.append("The Media folder holds a file the timelines do not use.") }
        return problems
    }
}
