import CoreGraphics
import Foundation

// The timelines for Final Cut Pro and DaVinci Resolve (v2 part M10a, docs/v2/PLAN.md M10; research-edit-engine.md 5): the same
// edit as the edited video, as FCPXML a person can finish by hand. One generator writes both files; only the version differs
// (research 5.7 rule 7): 1.14 for Final Cut Pro 12.4, 1.10 for DaVinci Resolve 20.2.1.
//
// What is written, element by element (research 5.4):
// - **Every kept span** as an `asset-clip` in the spine, in the video's order (the opening line first), each cut on a whole frame,
//   with a one-frame audio fade in and out at every cut (`adjust-volume`, never an audio transition: Resolve drops those).
// - **Punch-ins** as a static `adjust-transform` (scale, and the position that keeps the plan's framing). A span whose framing
//   changes inside it is split there, so every clip has one framing.
// - **Slow push-ins are not animated** (the vault's 2026-07-30 lesson: in-XML animation fails silently on import): the clip stays
//   wide and a to-do marker says "Push-in here", until a round trip in both apps has passed (M10b, `timelineAnimationsVerified`).
// - **The held last frame** as a clip of its own (`Graphics/Held last frame.mov`), silent, with the last shot's framing.
// - **Every text** (title, teacher's name, key phrases, terms) as the rendered clip from `Graphics/` on a lane above, enabled,
//   identical to the video; and an editable title on the lane above that, switched off (`enabled="0"`).
// - **Captions** as `caption` elements in the `iTT` role, each inside one clip, never overlapping; the `.srt` beside the files
//   covers an app that drops them.
// - **Chapters** as `chapter-marker`, the plan's moments to check as to-do markers.
//
// Every time is a whole number of frames, written `n * frameDuration` (research 5.7 rule 1); anchored items use the parent clip's
// own time (rule 3). The media is one asset per file with `start="0s"` and an absolute `file://` source, percent-encoded (rule 2).
// Nothing here reaches the network (RulesTests).

/// The two versions written: 1.14 for Final Cut Pro, 1.10 for DaVinci Resolve.
enum FCPXMLVersion: String, CaseIterable, Sendable {
    case finalCut = "1.14"
    case resolve = "1.10"

    var fileName: String { self == .finalCut ? "Edit for Final Cut Pro.fcpxml" : "Edit for DaVinci Resolve.fcpxml" }
    /// The DTD Final Cut Pro ships for it: "FCPXMLv1_14.dtd".
    var dtdName: String { "FCPXMLv" + rawValue.replacingOccurrences(of: ".", with: "_") + ".dtd" }
    var appName: String { self == .finalCut ? "Final Cut Pro" : "DaVinci Resolve" }
}

/// What the timeline is written from: the plan as frames, its framing, and the files it points at.
struct TimelineSpec: Sendable {
    /// The media file the spans come from, where it will be when the timeline is opened.
    struct Media: Equatable, Sendable {
        var name: String
        var url: URL
        /// Whole frames in the file.
        var frames: Int64
        var width: Int
        var height: Int
        var hasAudio = true
        var audioSources = 1
        var audioChannels = 2
        var audioRate = 48_000
        /// The privacy-safe media's used ranges (v2 part M10b, `CleanedMedia.ranges`): each piece a range of the original, end to
        /// end on the file's own clock. Nil for a clone, whose clock is the original's.
        var ranges: [EditTimeline.Piece]?

        /// The file's frame that shows the original's frame `source`. A frame outside every range (never asked for by a timeline
        /// made from the same plan) maps to the nearest range's edge.
        func frame(ofSource source: Int64) -> Int64 {
            guard let ranges, !ranges.isEmpty else { return source }
            if let range = ranges.first(where: { source >= $0.sourceFrame && source < $0.sourceFrame + $0.frames }) {
                return range.editFrame + (source - range.sourceFrame)
            }
            if let last = ranges.last, source == last.sourceFrame + last.frames { return last.editFrame + last.frames }
            let nearest = ranges.min { abs($0.sourceFrame - source) < abs($1.sourceFrame - source) }!
            return source < nearest.sourceFrame ? nearest.editFrame : nearest.editFrame + nearest.frames
        }
    }

    /// A rendered clip (a text, or the held last frame), where it will be.
    struct Clip: Equatable, Sendable {
        var name: String
        var url: URL
        /// The text kind, nil for the held frame.
        var kind: OverlayKind?
        /// The lines its editable copy shows.
        var lines: [String] = []
        var align: OverlayText.Align = .leading
        /// Where it starts on the edited clock, in frames, and for how many.
        var start: Int64
        var frames: Int64
    }

    struct Mark: Equatable, Sendable {
        /// Edited frame.
        var frame: Int64
        var text: String
    }

    /// The project's name in the app: "Sun 13 Sep, Clear".
    var project: String
    var frame: FrameDuration
    var width: Int
    var height: Int
    var media: Media
    var timeline: EditTimeline
    var framing: Framing
    var graphics: [Clip] = []
    var held: Clip?
    /// Captions on the edited clock (the video's own `.srt`).
    var captions: [Captions.Cue] = []
    var chapters: [Mark] = []
    var checks: [Mark] = []
    /// Push-ins and dissolves written as animation (M10b, after the round trips). Off: each is a marker.
    var animationsVerified = false
}

/// The timeline worked out in frames, before it is written: what `FCPXMLWriter.xml` prints, and what the tests count.
struct TimelineLayout: Equatable, Sendable {
    struct Clip: Equatable, Sendable {
        var name: String
        /// "media" or "held".
        var asset: String
        var editStart: Int64
        var frames: Int64
        /// First frame of the asset it shows (the parent's own time for its anchored items).
        var sourceStart: Int64
        var scale: Double?
        /// Position in percent of the frame's height, x to the right, y up (Final Cut Pro's units).
        var position: CGPoint?
        var fadeIn = false
        var fadeOut = false
        var pushInHere = false
        /// A slow push-in written as a move (only once `TimelineAnimations.verified`): the scale and position at each key, the key's
        /// time in the clip's own time.
        var keys: [Key] = []
        var editEnd: Int64 { editStart + frames }

        struct Key: Equatable, Sendable {
            var frame: Int64
            var scale: Double
            var position: CGPoint
        }
    }

    struct Anchored: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case graphic(Int), title(Int), caption(String), marker(String), chapter(String) }
        var kind: Kind
        /// The spine clip it hangs from, and its offset in that clip's own time, in frames.
        var parent: Int
        var offset: Int64
        var frames: Int64
        var lane: Int = 0
    }

    var clips: [Clip] = []
    var anchored: [Anchored] = []
    var totalFrames: Int64 = 0

    var captions: Int { anchored.filter { if case .caption = $0.kind { true } else { false } }.count }
    var markers: Int { anchored.filter { if case .marker = $0.kind { true } else { false } }.count }
    var chapterMarkers: Int { anchored.filter { if case .chapter = $0.kind { true } else { false } }.count }
}

/// Whether slow push-ins go into the timelines as moves (v2 part M10b, PLAN M10 checks 6 and 7). Off until a round trip in Final
/// Cut Pro and in DaVinci Resolve has shown a keyed `adjust-transform` arrive as the same move (the vault's 2026-07-30 lesson: in-XML
/// animation fails silently on import). Turned on only by a commit that carries the evidence (Mac warning 191).
enum TimelineAnimations {
    static let verified = false
}

enum FCPXMLWriter {
    /// The effect Final Cut Pro uses for its Basic Title and Basic Lower Third (as its own exports name them).
    static let basicTitle = ".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti"
    static let basicLowerThird = ".../Titles.localized/Lower Thirds.localized/Basic Lower Third.localized/Basic Lower Third.moti"
    /// Final Cut Pro's own caption role for iTT captions in English.
    static let captionRole = "iTT?captionFormat=ITT.en"
    static let pushInMarker = "Push-in here"

    // MARK: Layout

    /// The spine and everything hung from it, in whole frames.
    static func layout(_ spec: TimelineSpec) -> TimelineLayout {
        var out = TimelineLayout()
        let timeline = spec.timeline
        let aspect = Double(spec.width) / Double(max(1, spec.height))
        var mainNumber = 0
        for piece in timeline.pieces {
            let start = piece.editFrame, end = piece.editFrame + piece.frames
            // Split where the framing changes inside the piece.
            var cuts: Set<Int64> = [start, end]
            for s in spec.framing.segments where s.end > start && s.start < end {
                if s.start > start { cuts.insert(s.start) }
                if s.end < end { cuts.insert(s.end) }
            }
            let points = cuts.sorted()
            if !piece.hook { mainNumber += 1 }
            let base = piece.hook ? "Opening line" : "Part \(mainNumber)"
            for k in 0..<(points.count - 1) {
                let a = points[k], b = points[k + 1]
                var clip = TimelineLayout.Clip(name: base, asset: "media", editStart: a, frames: b - a,
                                               sourceStart: spec.media.frame(ofSource: piece.sourceFrame + (a - start)))
                if let s = spec.framing.segment(at: a) {
                    if s.easeFrames == 0 {
                        clip.scale = s.scale
                        clip.position = position(rect: s.rect, scale: s.scale, aspect: aspect)
                        clip.name = base + String(format: ", punch-in %.2f", s.scale)
                    } else if spec.animationsVerified {
                        // The push-in as a move, keyed where the compositor's ease starts and ends inside this clip (v2 part M10b,
                        // written only once the round trips in both apps have passed: `TimelineAnimations.verified`).
                        let from = max(a, s.start), to = min(b - 1, s.start + s.easeFrames)
                        clip.keys = [from, to].map { f in
                            let rect = spec.framing.rect(atEditFrame: f) ?? Framing.whole
                            let scale = 1 / max(0.01, rect.width)
                            return TimelineLayout.Clip.Key(frame: clip.sourceStart + (f - a), scale: (scale * 10_000).rounded() / 10_000,
                                                           position: position(rect: rect, scale: scale, aspect: aspect))
                        }
                        clip.name = base + String(format: ", push-in %.2f", s.scale)
                    } else {
                        // A slow push-in stays wide, marked, until the round trip passes.
                        clip.pushInHere = s.start == a
                    }
                }
                clip.fadeIn = k == 0
                clip.fadeOut = k == points.count - 2
                out.clips.append(clip)
            }
        }
        if spec.held != nil, timeline.holdFrames > 0, let last = out.clips.last {
            var clip = TimelineLayout.Clip(name: "Held last frame", asset: "held", editStart: timeline.keptFrames, frames: timeline.holdFrames, sourceStart: 0)
            clip.scale = last.scale
            clip.position = last.position
            out.clips.append(clip)
        }
        out.totalFrames = out.clips.last?.editEnd ?? 0

        // Push-in markers, where a push-in starts.
        for (i, clip) in out.clips.enumerated() where clip.pushInHere {
            out.anchored.append(.init(kind: .marker(pushInMarker), parent: i, offset: clip.sourceStart, frames: 1))
        }
        // Graphics: each rendered clip on its own lane pair (picture, then its editable copy above it), the lowest pair free
        // for its whole time.
        var pairs: [[ClosedRange<Int64>]] = []
        for (g, clip) in spec.graphics.enumerated() {
            guard clip.frames > 0, let parent = Self.parent(of: clip.start, in: out.clips) else { continue }
            let range = clip.start...(clip.start + clip.frames - 1)
            var pair = 0
            while pair < pairs.count && pairs[pair].contains(where: { $0.overlaps(range) }) { pair += 1 }
            if pair == pairs.count { pairs.append([]) }
            pairs[pair].append(range)
            let p = out.clips[parent]
            let offset = p.sourceStart + (clip.start - p.editStart)
            out.anchored.append(.init(kind: .graphic(g), parent: parent, offset: offset, frames: clip.frames, lane: 2 * pair + 1))
            out.anchored.append(.init(kind: .title(g), parent: parent, offset: offset, frames: clip.frames, lane: 2 * pair + 2))
        }
        let captionLane = 2 * pairs.count + 1
        // Captions: each cue on whole frames, never overlapping the one before, cut at clip edges so each lies inside its clip.
        var previousEnd: Int64 = 0
        for cue in spec.captions {
            var a = Int64((cue.start / spec.frame.seconds).rounded()), b = Int64((cue.end / spec.frame.seconds).rounded())
            a = max(a, previousEnd)
            b = min(b, out.totalFrames)
            guard b > a else { continue }
            previousEnd = b
            for (i, clip) in out.clips.enumerated() where clip.editEnd > a && clip.editStart < b {
                let from = max(a, clip.editStart), to = min(b, clip.editEnd)
                out.anchored.append(.init(kind: .caption(cue.text), parent: i, offset: clip.sourceStart + (from - clip.editStart), frames: to - from,
                                          lane: captionLane))
            }
        }
        // Chapters and the moments to check, each one frame long inside its clip.
        for mark in spec.chapters {
            guard let parent = Self.parent(of: min(mark.frame, out.totalFrames - 1), in: out.clips) else { continue }
            let p = out.clips[parent]
            out.anchored.append(.init(kind: .chapter(mark.text), parent: parent, offset: p.sourceStart + (min(mark.frame, out.totalFrames - 1) - p.editStart), frames: 1))
        }
        for mark in spec.checks {
            guard let parent = Self.parent(of: min(mark.frame, out.totalFrames - 1), in: out.clips) else { continue }
            let p = out.clips[parent]
            out.anchored.append(.init(kind: .marker(mark.text), parent: parent, offset: p.sourceStart + (min(mark.frame, out.totalFrames - 1) - p.editStart), frames: 1))
        }
        return out
    }

    /// The spine clip that shows edited frame `f`.
    static func parent(of f: Int64, in clips: [TimelineLayout.Clip]) -> Int? {
        clips.firstIndex { f >= $0.editStart && f < $0.editEnd }
    }

    /// Final Cut Pro's position for a punch-in: the framed part's middle brought to the frame's middle after scaling about the
    /// centre, in percent of the frame's height, x to the right and y up.
    static func position(rect: CGRect, scale: Double, aspect: Double) -> CGPoint {
        let x = -scale * (rect.midX - 0.5) * aspect * 100
        let y = scale * (rect.midY - 0.5) * 100
        return CGPoint(x: (x * 10_000).rounded() / 10_000, y: (y * 10_000).rounded() / 10_000)
    }

    // MARK: Writing

    /// The FCPXML document for one version.
    static func xml(_ spec: TimelineSpec, version: FCPXMLVersion) -> String {
        xml(spec, layout: layout(spec), version: version)
    }

    static func xml(_ spec: TimelineSpec, layout: TimelineLayout, version: FCPXMLVersion) -> String {
        let fd = spec.frame
        func t(_ frames: Int64) -> String { time(frames, fd) }
        var x: [String] = []
        x.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        x.append("<!DOCTYPE fcpxml>")
        x.append("<fcpxml version=\"\(version.rawValue)\">")
        x.append("  <resources>")
        var format = "    <format id=\"r1\""
        if let name = formatName(width: spec.width, height: spec.height, frame: fd) { format += " name=\"\(name)\"" }
        format += " frameDuration=\"\(t(1))\" width=\"\(spec.width)\" height=\"\(spec.height)\" colorSpace=\"1-1-1 (Rec. 709)\"/>"
        x.append(format)
        let m = spec.media
        var media = "    <asset id=\"r2\" name=\"\(escape(m.name))\" start=\"0s\" duration=\"\(t(m.frames))\" hasVideo=\"1\" format=\"r1\" videoSources=\"1\""
        if m.hasAudio { media += " hasAudio=\"1\" audioSources=\"\(m.audioSources)\" audioChannels=\"\(m.audioChannels)\" audioRate=\"\(m.audioRate)\"" }
        x.append(media + ">")
        x.append("      <media-rep kind=\"original-media\" src=\"\(fileURL(m.url))\"/>")
        x.append("    </asset>")
        let usesTitle = spec.graphics.contains { $0.kind != .lowerThird && $0.kind != .term }
        let usesLower = spec.graphics.contains { $0.kind == .lowerThird || $0.kind == .term }
        if usesTitle { x.append("    <effect id=\"r3\" name=\"Basic Title\" uid=\"\(escape(basicTitle))\"/>") }
        if usesLower { x.append("    <effect id=\"r4\" name=\"Basic Lower Third\" uid=\"\(escape(basicLowerThird))\"/>") }
        if let held = spec.held {
            x.append("    <asset id=\"r5\" name=\"\(escape(held.name))\" start=\"0s\" duration=\"\(t(held.frames))\" hasVideo=\"1\" format=\"r1\" videoSources=\"1\">")
            x.append("      <media-rep kind=\"original-media\" src=\"\(fileURL(held.url))\"/>")
            x.append("    </asset>")
        }
        for (g, clip) in spec.graphics.enumerated() {
            x.append("    <asset id=\"g\(g + 1)\" name=\"\(escape(clip.name))\" start=\"0s\" duration=\"\(t(clip.frames))\" hasVideo=\"1\" format=\"r1\" videoSources=\"1\">")
            x.append("      <media-rep kind=\"original-media\" src=\"\(fileURL(clip.url))\"/>")
            x.append("    </asset>")
        }
        x.append("  </resources>")
        x.append("  <library>")
        x.append("    <event name=\"Prakriti\">")
        x.append("      <project name=\"\(escape(spec.project))\">")
        x.append("        <sequence format=\"r1\" duration=\"\(t(layout.totalFrames))\" tcStart=\"0s\" tcFormat=\"NDF\" audioLayout=\"stereo\" audioRate=\"48k\">")
        x.append("          <spine>")
        var style = 0
        for (i, clip) in layout.clips.enumerated() {
            let ref = clip.asset == "held" ? "r5" : "r2"
            var open = "            <asset-clip ref=\"\(ref)\" name=\"\(escape(clip.name))\" offset=\"\(t(clip.editStart))\" start=\"\(t(clip.sourceStart))\" duration=\"\(t(clip.frames))\" tcFormat=\"NDF\""
            open += clip.asset == "held" ? " videoRole=\"video\"" : " audioRole=\"dialogue\""
            x.append(open + ">")
            if let scale = clip.scale, let p = clip.position {
                x.append("              <adjust-transform position=\"\(number(p.x)) \(number(p.y))\" scale=\"\(number(scale)) \(number(scale))\"/>")
            } else if clip.keys.count >= 2 {
                x.append("              <adjust-transform>")
                for name in ["position", "scale"] {
                    x.append("                <param name=\"\(name)\">")
                    x.append("                  <keyframeAnimation>")
                    for key in clip.keys {
                        let value = name == "scale" ? "\(number(key.scale)) \(number(key.scale))" : "\(number(key.position.x)) \(number(key.position.y))"
                        x.append("                    <keyframe time=\"\(t(key.frame))\" value=\"\(value)\" interp=\"ease\"/>")
                    }
                    x.append("                  </keyframeAnimation>")
                    x.append("                </param>")
                }
                x.append("              </adjust-transform>")
            }
            if clip.asset == "media" && m.hasAudio && (clip.fadeIn || clip.fadeOut) {
                x.append("              <adjust-volume>")
                x.append("                <param name=\"amount\">")
                if clip.fadeIn { x.append("                  <fadeIn type=\"easeIn\" duration=\"\(t(1))\"/>") }
                if clip.fadeOut { x.append("                  <fadeOut type=\"easeOut\" duration=\"\(t(1))\"/>") }
                x.append("                </param>")
                x.append("              </adjust-volume>")
            }
            let hung = layout.anchored.filter { $0.parent == i }
            // Anchored clips first, then markers (the DTD's order).
            for a in hung {
                switch a.kind {
                case .graphic(let g):
                    let clip = spec.graphics[g]
                    x.append("              <asset-clip ref=\"g\(g + 1)\" lane=\"\(a.lane)\" name=\"\(escape(clip.name))\" offset=\"\(t(a.offset))\" start=\"0s\" duration=\"\(t(a.frames))\" videoRole=\"titles\"/>")
                case .title(let g):
                    let clip = spec.graphics[g]
                    let lower = clip.kind == .lowerThird || clip.kind == .term
                    style += 1
                    x.append("              <title ref=\"\(lower ? "r4" : "r3")\" lane=\"\(a.lane)\" name=\"\(escape(clip.name + ", editable"))\" offset=\"\(t(a.offset))\" start=\"0s\" duration=\"\(t(a.frames))\" enabled=\"0\">")
                    x.append("                <text>")
                    x.append("                  <text-style ref=\"ts\(style)\">\(escape(clip.lines.joined(separator: "\n")))</text-style>")
                    x.append("                </text>")
                    x.append("                <text-style-def id=\"ts\(style)\">")
                    let size = clip.kind == .title ? 72 : clip.kind == .keyPhrase ? 56 : 54
                    let alignment = clip.align == .trailing ? "right" : clip.align == .center ? "center" : "left"
                    x.append("                  <text-style font=\"Alegreya Sans\" fontSize=\"\(size)\" fontFace=\"Bold\" fontColor=\"1 1 1 1\" alignment=\"\(alignment)\"/>")
                    x.append("                </text-style-def>")
                    x.append("              </title>")
                case .caption(let text):
                    style += 1
                    x.append("              <caption lane=\"\(a.lane)\" name=\"\(escape(shortName(text)))\" offset=\"\(t(a.offset))\" start=\"0s\" duration=\"\(t(a.frames))\" role=\"\(captionRole)\">")
                    x.append("                <text placement=\"bottom\">")
                    x.append("                  <text-style ref=\"ts\(style)\">\(escape(text))</text-style>")
                    x.append("                </text>")
                    x.append("                <text-style-def id=\"ts\(style)\">")
                    x.append("                  <text-style font=\".AppleSystemUIFont\" fontSize=\"13\" fontFace=\"Regular\" fontColor=\"1 1 1 1\" backgroundColor=\"0 0 0 1\"/>")
                    x.append("                </text-style-def>")
                    x.append("              </caption>")
                case .marker, .chapter:
                    continue
                }
            }
            for a in hung {
                switch a.kind {
                case .marker(let text):
                    x.append("              <marker start=\"\(t(a.offset))\" duration=\"\(t(1))\" value=\"\(escape(text))\" completed=\"0\"/>")
                case .chapter(let text):
                    x.append("              <chapter-marker start=\"\(t(a.offset))\" duration=\"\(t(1))\" value=\"\(escape(text))\" posterOffset=\"0s\"/>")
                default:
                    continue
                }
            }
            x.append("            </asset-clip>")
        }
        x.append("          </spine>")
        x.append("        </sequence>")
        x.append("      </project>")
        x.append("    </event>")
        x.append("  </library>")
        x.append("</fcpxml>")
        return x.joined(separator: "\n") + "\n"
    }

    /// A whole number of frames as FCPXML's rational seconds: "0s", or "n*value/timescale s".
    static func time(_ frames: Int64, _ fd: FrameDuration) -> String {
        frames == 0 ? "0s" : "\(frames * fd.value)/\(fd.timescale)s"
    }

    /// Final Cut Pro's name for the common 16:9 formats ("FFVideoFormat1080p2997"), nil for any other.
    static func formatName(width: Int, height: Int, frame: FrameDuration) -> String? {
        guard [(1280, 720), (1920, 1080), (3840, 2160)].contains(where: { $0 == (width, height) }) else { return nil }
        let rate: String
        switch (frame.value, frame.timescale) {
        case (1001, 24000): rate = "2398"
        case (1, 24): rate = "24"
        case (1, 25): rate = "25"
        case (1001, 30000): rate = "2997"
        case (1, 30): rate = "30"
        case (1, 50): rate = "50"
        case (1001, 60000): rate = "5994"
        case (1, 60): rate = "60"
        default: return nil
        }
        return "FFVideoFormat\(height)p\(rate)"
    }

    /// An absolute `file://` URL with everything but letters, digits and `-._~/` percent-encoded (spaces and commas
    /// included, research 5.7 rule 2).
    static func fileURL(_ url: URL) -> String {
        var allowed = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)...Unicode.Scalar(127)))
        allowed.insert(charactersIn: "-._~/")
        let path = url.standardizedFileURL.path
        return "file://" + (path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path)
    }

    static func number(_ x: Double) -> String {
        let r = (x * 10_000).rounded() / 10_000
        if r == r.rounded() { return String(Int(r)) }
        var s = String(format: "%.4f", r)
        while s.hasSuffix("0") { s.removeLast() }
        return s
    }

    /// A caption's name in the app: its first few words.
    static func shortName(_ text: String) -> String {
        text.count <= 40 ? text : String(text.prefix(37)) + "..."
    }

    static func escape(_ s: String) -> String {
        var out = ""
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            case "\n": out += "&#10;"
            default: out.append(c)
            }
        }
        return out
    }
}
