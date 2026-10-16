import Foundation

// The checks every timeline passes before it is kept (v2 part M10a, docs/v2/PLAN.md M10 check 1; research-edit-engine.md 5.8):
// the semantic lint, read from the written file itself (never from the writer's own model, so a writer bug cannot hide), and
// the DTD that Final Cut Pro ships for the version, through `xmllint`.
//
// The lint's rules, each with its reason:
// 1. **Every time is a whole number of frames.** Otherwise Final Cut Pro inserts gaps with a warning (research 5.1).
// 2. **The spine has no overlap and no gap:** each clip starts where the one before ends, the first at 0.
// 3. **The spine's durations add up to the sequence's.**
// 4. **Every `ref` resolves** to an asset, effect or format in the resources.
// 5. **Every `src` exists** (where it will be once the folder is in place; `resolve` maps that to where it is now).
// 6. **Every transition has handles:** half its length of media before the incoming clip's start and after the outgoing
//    clip's end (research 5.7 rule 4).
// 7. **Captions do not overlap** on the sequence's clock, and **every caption and marker lies inside its clip**
//    (research 5.7 rule 5).
// 8. **Every clip shows media its file holds** (v2 part M10b): its start and length inside its asset's duration, so a clip placed on
//    the privacy-safe media's own clock can never ask for a frame the file does not have.
//
// Load-bearing: `xmllint` cannot read the DTD inside Final Cut Pro's bundle in place (research 5.8, the path has spaces), so the
// DTDs are copied out first (`copyDTDs`).

enum FCPXMLLint {
    struct Problem: Equatable, Sendable, CustomStringConvertible {
        let rule: Int
        let line: String
        var description: String { "rule \(rule): \(line)" }
    }

    /// A rational time in seconds as a numerator and denominator: "3003/30000s", "2s", "0s".
    struct Rational: Equatable, Sendable {
        var n: Int64
        var d: Int64

        init(n: Int64, d: Int64) {
            self.n = n
            self.d = d
        }

        init?(_ text: String?) {
            guard var s = text, s.hasSuffix("s") else { return nil }
            s.removeLast()
            let parts = s.split(separator: "/")
            if parts.count == 1, let n = Int64(parts[0]) { self.init(n: n, d: 1); return }
            if parts.count == 2, let n = Int64(parts[0]), let d = Int64(parts[1]), d > 0 { self.init(n: n, d: d); return }
            return nil
        }

        /// This time in frames of `fd`, or nil when it is not a whole number of them.
        func frames(_ fd: FrameDuration) -> Int64? {
            // n/d = k * value/timescale  =>  k = n * timescale / (d * value)
            let num = n * fd.timescale, den = d * fd.value
            guard den != 0, num % den == 0 else { return nil }
            return num / den
        }
    }

    /// The problems found in `xml`; empty when it passes. `resolve` maps a source's URL to where the file is now.
    static func check(_ xml: String, resolve: (URL) -> URL = { $0 }) -> [Problem] {
        guard let document = try? XMLDocument(xmlString: xml, options: []) , let root = document.rootElement() else {
            return [Problem(rule: 0, line: "The file is not well-formed XML.")]
        }
        var problems: [Problem] = []
        func add(_ rule: Int, _ line: String) { problems.append(Problem(rule: rule, line: line)) }
        func attr(_ e: XMLElement, _ name: String) -> String? { e.attribute(forName: name)?.stringValue }

        // The format, and every id in the resources.
        let resources = root.elements(forName: "resources").first?.children?.compactMap { $0 as? XMLElement } ?? []
        var ids: [String: XMLElement] = [:]
        for r in resources { if let id = attr(r, "id") { ids[id] = r } }
        guard let sequence = (try? root.nodes(forXPath: "//sequence"))?.first as? XMLElement,
              let formatID = attr(sequence, "format"), let format = ids[formatID],
              let fdTime = Rational(attr(format, "frameDuration")) else {
            return [Problem(rule: 4, line: "No sequence with a format and its frame duration.")]
        }
        let fd = FrameDuration(value: fdTime.n, timescale: fdTime.d)

        // Rule 1: every time attribute anywhere is whole frames.
        let timeNames = ["offset", "start", "duration", "tcStart", "posterOffset", "frameDuration"]
        func walk(_ e: XMLElement) {
            for name in timeNames {
                guard let value = attr(e, name) else { continue }
                guard let r = Rational(value) else { add(1, "\(e.name ?? "?") \(name)=\"\(value)\" is not a time."); continue }
                if name != "frameDuration", r.frames(fd) == nil { add(1, "\(e.name ?? "?") \(name)=\"\(value)\" is not a whole number of frames.") }
            }
            for case let child as XMLElement in e.children ?? [] { walk(child) }
        }
        walk(root)

        // Rule 4: every ref resolves.
        func refs(_ e: XMLElement) {
            // A text-style's ref names a text-style-def, checked below; every other ref and format names a resource.
            if e.name != "text-style", let value = attr(e, "ref"), ids[value] == nil {
                add(4, "\(e.name ?? "?") ref=\"\(value)\" resolves to nothing in the resources.")
            }
            if let value = attr(e, "format"), ids[value] == nil {
                add(4, "\(e.name ?? "?") format=\"\(value)\" resolves to nothing in the resources.")
            }
            for case let child as XMLElement in e.children ?? [] { refs(child) }
        }
        refs(root)
        // The text styles a text names are defined in the document.
        let styleIDs = Set(((try? root.nodes(forXPath: "//text-style-def")) ?? []).compactMap { ($0 as? XMLElement).flatMap { attr($0, "id") } })
        for case let style as XMLElement in (try? root.nodes(forXPath: "//text/text-style")) ?? [] {
            if let ref = attr(style, "ref"), !styleIDs.contains(ref) { add(4, "text-style ref=\"\(ref)\" names no text-style-def.") }
        }

        // Rule 5: every src exists.
        for case let rep as XMLElement in (try? root.nodes(forXPath: "//media-rep")) ?? [] {
            guard let src = attr(rep, "src"), let url = URL(string: src), url.isFileURL else {
                add(5, "A media-rep has no file URL."); continue
            }
            if !FileManager.default.fileExists(atPath: resolve(url).path) { add(5, "\(url.lastPathComponent) is not there.") }
        }

        // Rules 2 and 3: the spine.
        let sequenceFrames = Rational(attr(sequence, "duration"))?.frames(fd) ?? -1
        guard let spine = sequence.elements(forName: "spine").first else {
            add(2, "The sequence has no spine.")
            return problems
        }
        let items = spine.children?.compactMap { $0 as? XMLElement } ?? []
        var at: Int64 = 0
        var clipRanges: [(element: XMLElement, offset: Int64, start: Int64, duration: Int64)] = []
        for item in items where item.name != "transition" {
            guard let offset = Rational(attr(item, "offset"))?.frames(fd), let duration = Rational(attr(item, "duration"))?.frames(fd) else {
                add(2, "A spine \(item.name ?? "item") has no offset or duration in whole frames."); continue
            }
            if offset != at { add(2, "A spine \(item.name ?? "item") starts at frame \(offset), not at \(at) where the one before ends.") }
            let start = Rational(attr(item, "start"))?.frames(fd) ?? 0
            clipRanges.append((item, offset, start, duration))
            at = offset + duration
        }
        if at != sequenceFrames { add(3, "The spine's clips add up to \(at) frames, the sequence says \(sequenceFrames).") }

        // Rule 6: transitions have handles.
        for (k, item) in items.enumerated() where item.name == "transition" {
            guard let duration = Rational(attr(item, "duration"))?.frames(fd) else { continue }
            let half = duration / 2
            let before = items[..<k].last { $0.name != "transition" }, after = items[(k + 1)...].first { $0.name != "transition" }
            guard let before, let after, let ref = attr(after, "ref"), let incomingStart = Rational(attr(after, "start"))?.frames(fd),
                  let outgoingRef = attr(before, "ref"), let outStart = Rational(attr(before, "start"))?.frames(fd),
                  let outDuration = Rational(attr(before, "duration"))?.frames(fd) else {
                add(6, "A transition has no clip on one side."); continue
            }
            if incomingStart < half { add(6, "A transition needs \(half) frames before the incoming clip's start, \(ref) has \(incomingStart).") }
            if let asset = ids[outgoingRef], let length = Rational(attr(asset, "duration"))?.frames(fd), outStart + outDuration + half > length {
                add(6, "A transition needs \(half) frames after the outgoing clip's end.")
            }
        }

        // Rule 7: captions do not overlap, and every caption and marker is inside its clip.
        var captions: [(from: Int64, to: Int64)] = []
        for clip in clipRanges {
            for case let child as XMLElement in clip.element.children ?? [] {
                switch child.name {
                case "caption":
                    guard let offset = Rational(attr(child, "offset"))?.frames(fd), let duration = Rational(attr(child, "duration"))?.frames(fd) else { continue }
                    if offset < clip.start || offset + duration > clip.start + clip.duration {
                        add(7, "A caption at frame \(offset) of its clip is not inside the clip (\(clip.start) to \(clip.start + clip.duration)).")
                    }
                    let from = clip.offset + offset - clip.start
                    captions.append((from, from + duration))
                case "marker", "chapter-marker":
                    guard let start = Rational(attr(child, "start"))?.frames(fd) else { continue }
                    if start < clip.start || start >= clip.start + clip.duration {
                        add(7, "A \(child.name ?? "marker") at frame \(start) is not inside its clip (\(clip.start) to \(clip.start + clip.duration)).")
                    }
                default:
                    continue
                }
            }
        }
        captions.sort { $0.from < $1.from }
        for k in captions.indices.dropFirst() where captions[k].from < captions[k - 1].to {
            add(7, "Two captions overlap at frame \(captions[k].from) of the sequence.")
        }

        // Rule 8: every clip shows media its file holds (v2 part M10b: on the privacy-safe media, whose clock is its own ranges').
        for case let clip as XMLElement in (try? root.nodes(forXPath: "//asset-clip")) ?? [] {
            guard let ref = attr(clip, "ref"), let asset = ids[ref], asset.name == "asset",
                  let length = Rational(attr(asset, "duration"))?.frames(fd),
                  let duration = Rational(attr(clip, "duration"))?.frames(fd) else { continue }
            let start = Rational(attr(clip, "start"))?.frames(fd) ?? 0
            if start < 0 || start + duration > length {
                add(8, "\(attr(clip, "name") ?? "A clip") shows frames \(start) to \(start + duration) of a file \(length) frames long.")
            }
        }
        return problems
    }

    // MARK: The DTD

    /// Where Final Cut Pro keeps its FCPXML DTDs, or nil when it is not on this Mac.
    static func dtdFolder() -> URL? {
        let candidates = ["/Applications/Final Cut Pro Creator Studio.app", "/Applications/Final Cut Pro.app"]
        for app in candidates {
            let folder = URL(fileURLWithPath: app).appending(path: "Contents/Frameworks/Interchange.framework/Versions/A/Resources", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: folder.appending(path: FCPXMLVersion.finalCut.dtdName).path) { return folder }
        }
        return nil
    }

    /// Copies both DTDs out of Final Cut Pro into `folder` (xmllint cannot read them in place). False when Final Cut Pro is
    /// not on this Mac.
    @discardableResult
    static func copyDTDs(to folder: URL) -> Bool {
        guard let from = dtdFolder() else { return false }
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for version in FCPXMLVersion.allCases {
            let destination = folder.appending(path: version.dtdName)
            if fm.fileExists(atPath: destination.path) { continue }
            do { try fm.copyItem(at: from.appending(path: version.dtdName), to: destination) } catch { return false }
        }
        return true
    }

    /// `xmllint --noout --dtdvalid` on `file` against the version's DTD in `dtds`: nil when it is valid, else xmllint's words.
    static func validate(_ file: URL, version: FCPXMLVersion, dtds: URL) async -> String? {
        let dtd = dtds.appending(path: version.dtdName)
        guard FileManager.default.fileExists(atPath: dtd.path) else { return "The DTD \(version.dtdName) is not there." }
        do {
            let out = try await Subprocess.run(URL(fileURLWithPath: "/usr/bin/xmllint"), ["--noout", "--dtdvalid", dtd.path, file.path], timeout: .seconds(60))
            return out.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : out.stderr
        } catch let error as ToolError {
            return error.logLine
        } catch {
            return error.localizedDescription
        }
    }
}
