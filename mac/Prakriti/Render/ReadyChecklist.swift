import Foundation

// The edited video's Ready checklist (v2 part M8b, research-edit-engine.md 6.1 and 6.4), `Ready checklist.txt` in the
// recording's Video folder: every line measured from the files in that folder, never taken from the settings, PASS,
// MISSING or FAIL, each line that does not pass with what to do. MISSING is for what Prakriti never invents (a title, a
// description, chapters: Mac warning 62); FAIL is for a file that does not meet the spec.
//
// YouTube's published upload settings (support.google.com/youtube/answer/1722171), caption formats (answer/2734698) and
// chapter rules (answer/9884579), read for research-edit-engine.md on 10 Oct 2026. The loudness figure, -14 LUFS, is not
// YouTube's: it is what YouTube is measured to turn louder uploads down to (research 6.1, marked not official).

enum ReadyChecklist {
    static let name = "Ready checklist.txt"
    static let sources = "YouTube's upload settings (support.google.com/youtube/answer/1722171), caption formats (answer/2734698) and chapter rules (answer/9884579), read 10 Oct 2026"

    /// What ffprobe, ebur128, the box reader and a decode of the last 5 seconds found in the MP4, and what the captions file
    /// and the description hold.
    struct Measured: Codable, Equatable, Sendable {
        var container = ""
        var videoCodec = ""
        var profile = ""
        var width = 0
        var height = 0
        var frameRate = ""
        var fieldOrder = ""
        var pixelFormat = ""
        var videoBitrate: Double?
        var colorPrimaries = ""
        var colorTransfer = ""
        var colorSpace = ""
        var longestKeyFrameGap: Int?
        /// Every picture frame is the same time after the one before (the stream's time base units, and how many differ).
        var frameSteps: [Int64: Int] = [:]
        var timeBase = ""
        var audioCodec = ""
        var audioProfile = ""
        var sampleRate = 0
        var channels = 0
        var audioBitrate: Double?
        var duration: Double?
        var videoDuration: Double?
        var indexBeforeMedia = false
        var videoEditLists = 0
        var integratedLUFS: Double?
        var truePeak: Double?
        var tailDecodes = false
        var tailError = ""
        var captions: Captions.Measured?
        var bytes: Int64 = 0
    }

    /// What the checklist is measured against.
    struct Expected: Codable, Equatable, Sendable {
        var width: Int
        var height: Int
        var frameRate: String
        var videoBitrate: Double
        var audioBitrate = 320_000.0
        var keyFrameInterval = 15
        /// The sum of the kept spans, and one frame.
        var duration: Double
        var frame: Double
    }

    // MARK: Measuring

    /// Measures the made files. `ffprobe` and `ffmpeg` run their tool with the arguments given and return its stdout or
    /// stderr; a tool that fails throws.
    static func measure(mp4: URL, srt: URL?, ffprobe: @Sendable ([String]) async throws -> String,
                        ffmpeg: @Sendable ([String]) async throws -> String) async -> Measured {
        var m = Measured()
        m.bytes = ((try? FileManager.default.attributesOfItem(atPath: mp4.path)[.size]) as? NSNumber)?.int64Value ?? 0
        if let json = try? await ffprobe(["-v", "error", "-show_format", "-show_streams", "-of", "json", mp4.path]) {
            read(probe: json, into: &m)
        }
        if let keys = try? await ffprobe(["-v", "error", "-select_streams", "v:0", "-skip_frame", "nokey", "-show_entries", "frame=pts_time",
                                          "-of", "csv=p=0", mp4.path]) {
            m.longestKeyFrameGap = longestGap(keyTimes: keys, frameRate: m.frameRate, duration: m.videoDuration ?? m.duration)
        }
        if let steps = try? await ffprobe(["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=time_base:packet=duration",
                                           "-of", "csv=p=0", mp4.path]) {
            for line in steps.split(whereSeparator: \.isNewline) {
                let text = line.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
                if text.contains("/") { m.timeBase = text } else if let d = Int64(text) { m.frameSteps[d, default: 0] += 1 }
            }
        }
        if let layout = try? Mp4Boxes.read(mp4) {
            m.indexBeforeMedia = layout.indexBeforeMedia
            m.videoEditLists = layout.videoEditLists
        }
        if let loud = try? await ffmpeg(["-hide_banner", "-nostats", "-i", mp4.path, "-vn", "-af", "ebur128=peak=true", "-f", "null", "-"]),
           let measured = Measure.ebur128(stderr: loud) {
            m.integratedLUFS = measured.integratedLUFS
            m.truePeak = measured.truePeakDBFS
        }
        do {
            let tail = try await ffmpeg(["-v", "error", "-sseof", "-5", "-i", mp4.path, "-f", "null", "-"])
            let errors = tail.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            m.tailDecodes = errors.isEmpty
            m.tailError = errors.first.map(String.init) ?? ""
        } catch {
            m.tailDecodes = false
            m.tailError = (error as? ToolError)?.logLine ?? error.localizedDescription
        }
        if let srt, let text = try? String(contentsOf: srt, encoding: .utf8) {
            m.captions = Captions.measure(srt: text)
        }
        return m
    }

    static func read(probe json: String, into m: inout Measured) {
        struct Payload: Decodable {
            struct Stream: Decodable {
                let codec_type: String?
                let codec_name: String?
                let profile: String?
                let width: Int?
                let height: Int?
                let r_frame_rate: String?
                let field_order: String?
                let pix_fmt: String?
                let bit_rate: String?
                let color_primaries: String?
                let color_transfer: String?
                let color_space: String?
                let sample_rate: String?
                let channels: Int?
                let duration: String?
            }
            struct Format: Decodable {
                let format_name: String?
                let duration: String?
            }
            let streams: [Stream]?
            let format: Format?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(json.utf8)) else { return }
        m.container = payload.format?.format_name ?? ""
        m.duration = payload.format?.duration.flatMap(Double.init)
        if let v = payload.streams?.first(where: { $0.codec_type == "video" }) {
            m.videoCodec = v.codec_name ?? ""
            m.profile = v.profile ?? ""
            m.width = v.width ?? 0
            m.height = v.height ?? 0
            m.frameRate = v.r_frame_rate ?? ""
            m.fieldOrder = v.field_order ?? ""
            m.pixelFormat = v.pix_fmt ?? ""
            m.videoBitrate = v.bit_rate.flatMap(Double.init)
            m.colorPrimaries = v.color_primaries ?? ""
            m.colorTransfer = v.color_transfer ?? ""
            m.colorSpace = v.color_space ?? ""
            m.videoDuration = v.duration.flatMap(Double.init)
        }
        if let a = payload.streams?.first(where: { $0.codec_type == "audio" }) {
            m.audioCodec = a.codec_name ?? ""
            m.audioProfile = a.profile ?? ""
            m.sampleRate = a.sample_rate.flatMap { Int($0) } ?? 0
            m.channels = a.channels ?? 0
            m.audioBitrate = a.bit_rate.flatMap(Double.init)
        }
    }

    /// The longest run of frames between two key frames, counting to the end of the video.
    static func longestGap(keyTimes: String, frameRate: String, duration: Double?) -> Int? {
        let rate = rateValue(frameRate)
        guard rate > 0 else { return nil }
        let times = keyTimes.split(whereSeparator: \.isNewline).compactMap { Double($0.trimmingCharacters(in: CharacterSet(charactersIn: ", "))) }.sorted()
        guard !times.isEmpty else { return nil }
        var longest = 0
        for (a, b) in zip(times, times.dropFirst()) { longest = max(longest, Int(((b - a) * rate).rounded())) }
        if let duration { longest = max(longest, Int(((duration - (times.last ?? 0)) * rate).rounded())) }
        return longest
    }

    static func rateValue(_ text: String) -> Double {
        let parts = text.split(separator: "/").compactMap { Double($0) }
        if parts.count == 2, parts[1] > 0 { return parts[0] / parts[1] }
        return Double(text) ?? 0
    }

    // MARK: The lines

    static func lines(_ m: Measured, expected e: Expected, description: VideoDescription, people: VideoPeopleLine, captionsBehind: Double = 0) -> [ChecklistLine] {
        var out: [ChecklistLine] = []
        func add(_ status: ChecklistLine.Status, _ item: String, _ detail: String, _ todo: String? = nil) {
            out.append(ChecklistLine(status: status, item: item, detail: detail, todo: status == .pass ? nil : todo))
        }
        let remake = "Make Again. If it fails again, the log in Activity says why."

        // The file.
        add(m.container.contains("mp4") && m.videoCodec == "h264" && m.audioCodec == "aac" ? .pass : .fail, "Container and codecs",
            "\(m.container.contains("mp4") ? "MP4" : m.container.isEmpty ? "unreadable" : m.container), picture \(m.videoCodec == "h264" ? "H.264" : m.videoCodec.isEmpty ? "none" : m.videoCodec.uppercased()), sound \(m.audioCodec.isEmpty ? "none" : m.audioCodec.uppercased()).",
            remake)
        add(m.profile == "High" ? .pass : .fail, "H.264 profile", m.profile.isEmpty ? "Not readable." : "\(m.profile).", remake)
        add(m.width == e.width && m.height == e.height ? .pass : .fail, "Size", "\(m.width) by \(m.height), as recorded (\(e.width) by \(e.height)).", remake)
        add(m.frameRate == e.frameRate && (m.fieldOrder == "progressive" || m.fieldOrder.isEmpty) ? .pass : .fail, "Frame rate",
            "\(m.frameRate.isEmpty ? "unreadable" : m.frameRate), \(m.fieldOrder.isEmpty ? "progressive" : m.fieldOrder); the recording is \(e.frameRate).", remake)
        if let rate = m.videoBitrate {
            let off = abs(rate - e.videoBitrate) / e.videoBitrate
            add(off <= 0.10 ? .pass : .fail, "Picture bitrate", String(format: "%.1f Mbps, aimed at %.0f Mbps (%.0f%% off; within 10%% passes).", rate / 1e6, e.videoBitrate / 1e6, off * 100), remake)
        } else {
            add(.fail, "Picture bitrate", "Not readable.", remake)
        }
        let tagged = m.colorPrimaries == "bt709" && m.colorTransfer == "bt709" && m.colorSpace == "bt709"
        add(tagged ? .pass : .fail, "Colour tags", "Primaries \(or(m.colorPrimaries)), transfer \(or(m.colorTransfer)), matrix \(or(m.colorSpace)); BT.709 expected.", remake)
        if let gap = m.longestKeyFrameGap {
            add(gap <= e.keyFrameInterval ? .pass : .fail, "Key frames", "At least every \(gap) frames (every \(e.keyFrameInterval) or sooner: half a second).", remake)
        } else {
            add(.fail, "Key frames", "Not readable.", remake)
        }
        let steps = m.frameSteps.sorted { $0.value > $1.value }
        add(steps.count == 1 ? .pass : .fail, "Frame timing", steps.isEmpty ? "Not readable."
            : steps.count == 1 ? "Every frame \(steps[0].key) units of \(m.timeBase) after the one before."
            : "Frames are not evenly spaced: " + steps.prefix(3).map { "\($0.value) at \($0.key) units of \(m.timeBase)" }.joined(separator: ", ") + ".", remake)
        add(m.indexBeforeMedia ? .pass : .fail, "Index at the front", m.indexBeforeMedia ? "The index comes before the media (fast start)." : "The index comes after the media.", remake)
        add(m.videoEditLists == 0 ? .pass : .fail, "No edit list on the picture", m.videoEditLists == 0 ? "None." : "The picture track has an edit list.", remake)
        let audioOK = m.audioCodec == "aac" && m.audioProfile == "LC" && m.sampleRate == 48_000 && m.channels == 2
            && (m.audioBitrate.map { abs($0 - e.audioBitrate) / e.audioBitrate <= 0.10 } ?? false)
        add(audioOK ? .pass : .fail, "Sound format",
            "\(m.audioCodec.uppercased())-\(or(m.audioProfile)), \(m.sampleRate) Hz, \(m.channels == 2 ? "stereo" : "\(m.channels) channels"), "
                + (m.audioBitrate.map { String(format: "%.0f kbps", $0 / 1000) } ?? "bitrate unreadable")
                + String(format: "; AAC-LC 48 kHz stereo %.0f kbps expected (the most Apple's encoder makes).", e.audioBitrate / 1000), remake)
        if let lufs = m.integratedLUFS, let peak = m.truePeak {
            add(abs(lufs - VideoAudio.target) <= 1 ? .pass : .fail, "Loudness", String(format: "%.1f LUFS (-14, within 1 LU).", lufs), remake)
            add(peak <= VideoAudio.ceiling + 0.0001 ? .pass : .fail, "True peak", String(format: "%.1f dBTP (at or under -1).", peak), remake)
        } else {
            add(.fail, "Loudness", "Could not be measured.", remake)
        }
        if let d = m.videoDuration ?? m.duration {
            add(abs(d - e.duration) <= e.frame + 0.0005 ? .pass : .fail, "Length",
                "\(Format.timecode(d)) (\(String(format: "%.3f", d)) s); the plan keeps \(String(format: "%.3f", e.duration)) s, within one frame.", remake)
        } else {
            add(.fail, "Length", "Not readable.", remake)
        }
        add(m.tailDecodes ? .pass : .fail, "Plays to its end", m.tailDecodes ? "The last 5 seconds decode with no error." : "The last 5 seconds do not decode: \(m.tailError)", remake)

        // The captions. What YouTube reads (a plain .srt that parses, research 6.1) and the shape research 2.7 sets (42
        // characters a line, two lines, 7 s at most, in order, inside the video, with the voice) pass or fail. The speed, 20
        // characters a second, is Netflix's reading guide, not YouTube's rule; where the edited talk itself is faster, the
        // captions would have to drop words or fall behind the voice to meet it, and Prakriti does neither, so the count
        // over 20 is reported in the line and never fails it (decided 13 Oct, BUILD-LOG v2 part M8b).
        if let c = m.captions {
            let ok = c.longestLine <= Captions.lineLength && c.mostLines <= Captions.lines && c.inOrder
                && c.lastEnd <= (m.videoDuration ?? m.duration ?? 0) + 0.001 && c.longestShown <= Captions.longest + 0.001
                && captionsBehind <= Captions.mostBehind + 0.001
            add(ok ? .pass : .fail, "Captions",
                "\(c.cues) captions parse; longest line \(c.longestLine) characters (42), at most \(c.mostLines) lines (2), "
                    + String(format: "on screen %.2f to %.2f s (7 at most); at most %.1f s after their words (1); ", c.shortestShown, c.longestShown, captionsBehind)
                    + (c.inOrder ? "in order. " : "NOT in order. ")
                    + (c.overSpeed == 0 ? "None faster than 20 characters a second."
                       : String(format: "%d faster than 20 characters a second (the fastest %.1f), where the talk itself is that fast; the words are never shortened.",
                                c.overSpeed, c.fastest)),
                remake)
        } else {
            add(.fail, "Captions", "The .srt file is missing or does not parse.", remake)
        }

        // The words that go with it: never invented (Mac warning 62).
        add(description.title == nil ? .missing : .pass, "Title", description.title.map { "\u{201C}\($0)\u{201D}." } ?? "No title chosen or written.",
            "Give the recording a title in Info, or turn on Titles, show notes and chapters, then Make Again.")
        add(description.description == nil ? .missing : .pass, "Description", description.description == nil ? "No description chosen or written."
            : "\(description.description?.count ?? 0) characters.", "Write notes in Info, or turn on Titles, show notes and chapters, then Make Again.")
        if let problem = description.chapterProblem {
            add(.missing, "Chapters", problem, "Turn on Titles, show notes and chapters, then Make Again.")
        } else {
            add(.pass, "Chapters", "\(description.chapters.count) chapters, the first at 0:00, each at least 10 seconds, in order.")
        }

        // Who is in it.
        add(people.passes ? .pass : .fail, "People", people.detail, people.todo)
        return out
    }

    static func or(_ text: String) -> String { text.isEmpty ? "none" : text }

    /// `Ready checklist.txt`.
    static func text(_ lines: [ChecklistLine], label: String, fileName: String, madeAt: Date) -> String {
        let failed = lines.filter { $0.status == .fail }.count, missing = lines.filter { $0.status == .missing }.count
        let passed = lines.count - failed - missing
        var t = "Ready checklist: \(label), \(fileName)\n\n"
        t += "Made and checked by Prakriti on \(Format.dayAndTime(madeAt)) against \(sources). "
        t += "Every number below was measured on the files in this folder. Nothing has been uploaded.\n\n"
        t += failed + missing == 0 ? "Ready to upload: every line passes.\n\n"
            : "Not ready to upload yet: \(failed) FAIL, \(missing) MISSING, \(passed) PASS.\n\n"
        t += lines.map(\.text).joined(separator: "\n") + "\n"
        return t
    }
}

/// The checklist's People line, worked out before the file is made (`OutputGate`).
struct VideoPeopleLine: Codable, Equatable, Sendable {
    var passes: Bool
    var detail: String
    var todo: String?
}

// MARK: Upload checklists (v2 part M11b)

/// Where a finished file is uploaded by hand (design spec 3.11): YouTube for the long video, and YouTube Shorts, Instagram Reels and
/// TikTok for the shorts. Each platform's fields are in the order its upload form asks for them. YouTube's are from its own help
/// pages (research-edit-engine.md 6.1 and 6.2); Reels' and TikTok's are third-party figures (research 6.2), and their lines say so.
enum UploadPlatform: String, CaseIterable, Identifiable, Sendable {
    case youtube, youtubeShorts, instagramReels, tiktok

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youtube: "YouTube"
        case .youtubeShorts: "YouTube Shorts"
        case .instagramReels: "Instagram Reels"
        case .tiktok: "TikTok"
        }
    }

    /// The short name for the picker.
    var short: String {
        switch self {
        case .youtube: "YouTube"
        case .youtubeShorts: "Shorts"
        case .instagramReels: "Reels"
        case .tiktok: "TikTok"
        }
    }

    var vertical: Bool { self != .youtube }

    /// Whose rules the checks follow.
    var source: String {
        switch self {
        case .youtube: "YouTube's own help pages, read 10 Oct 2026."
        case .youtubeShorts: "YouTube's own help pages, read 10 Oct 2026: a vertical video of up to 3 minutes is a Short."
        case .instagramReels: "A third-party guide, not Instagram's own page (research 6.2): up to 3 minutes."
        case .tiktok: "A third-party guide, not TikTok's own page (research 6.2): up to 10 minutes for most accounts."
        }
    }

    /// The longest a video may be there, in seconds.
    var longest: Double {
        switch self {
        case .youtube: .infinity
        case .youtubeShorts, .instagramReels: 180
        case .tiktok: 600
        }
    }
}

/// One field of an upload form: its words to copy, or a file to show in the Finder, or an answer only Ivan gives; and whether it
/// is ready (PASS), not there (MISSING) or wrong (FAIL). An answer of his has no status.
struct UploadField: Identifiable, Equatable, Sendable {
    enum Value: Equatable, Sendable {
        case text(String)
        case file(URL)
        case answer
    }

    var id: String
    var label: String
    var value: Value
    var status: ChecklistLine.Status?
    var detail: String
    var thirdParty = false
}

/// Everything an upload checklist is made from, read from the recording's files by the app.
struct UploadFacts: Sendable {
    struct Short: Sendable {
        var number: Int
        var file: URL
        var captions: URL?
        var summary: String
        var duration: Double
        var failed: Int
        var width = 1080
        var height = 1920
    }

    var videoFile: URL?
    var videoFailed = 0
    var captionsFile: URL?
    var captionsPass = false
    var description: VideoDescription?
    var tags: [String] = []
    var thumbnail: URL?
    var thumbnailLine: String?
    var instagram: String?
    var shorts: [Short] = []
}

extension ReadyChecklist {
    /// YouTube's limits on the words (support.google.com/youtube: a title of up to 100 characters, a description of up to 5,000,
    /// tags of up to 500 together).
    static let titleLimit = 100
    static let descriptionLimit = 5_000
    static let tagsLimit = 500

    /// The fields of one platform's upload form, in its order. Pure.
    static func upload(_ platform: UploadPlatform, facts f: UploadFacts) -> [UploadField] {
        var out: [UploadField] = []
        switch platform {
        case .youtube:
            if let file = f.videoFile {
                out.append(.init(id: "file", label: "Video file", value: .file(file), status: f.videoFailed == 0 ? .pass : .fail,
                                 detail: f.videoFailed == 0 ? "Every line of its Ready checklist passes or is filled in below." : "\(Format.count(f.videoFailed, "line")) of its Ready checklist fail."))
            } else {
                out.append(.init(id: "file", label: "Video file", value: .answer, status: .missing, detail: "No edited video is made yet."))
            }
            if let title = f.description?.title {
                out.append(.init(id: "title", label: "Title", value: .text(title), status: title.count <= titleLimit ? .pass : .fail,
                                 detail: "\(title.count) characters (up to \(titleLimit))."))
            } else {
                out.append(.init(id: "title", label: "Title", value: .answer, status: .missing, detail: "No title chosen or written. Give the recording a title in Info."))
            }
            if let description = f.description?.description {
                let full = description + (f.description?.chapters.isEmpty == false
                    ? "\n\n" + (f.description?.chapters ?? []).map { "\(VideoDescription.stamp($0.start)) \($0.title)" }.joined(separator: "\n") : "")
                out.append(.init(id: "description", label: "Description", value: .text(full), status: full.count <= descriptionLimit ? .pass : .fail,
                                 detail: "\(Format.number(full.count)) characters (up to \(Format.number(descriptionLimit))), chapters included."))
            } else {
                out.append(.init(id: "description", label: "Description", value: .answer, status: .missing, detail: "No description chosen or written. Write notes in Info."))
            }
            if let thumbnail = f.thumbnail {
                out.append(.init(id: "thumbnail", label: "Thumbnail", value: .file(thumbnail), status: .pass, detail: f.thumbnailLine ?? "1280 by 720, under 2 MB."))
            } else {
                out.append(.init(id: "thumbnail", label: "Thumbnail", value: .answer, status: .missing, detail: "No thumbnail is made yet. Choose Make Thumbnails."))
            }
            out.append(.init(id: "audience", label: "Audience: made for kids", value: .answer, status: nil,
                             detail: "Your answer, in YouTube Studio. YouTube asks it of every video."))
            out.append(.init(id: "altered", label: "Altered or synthetic content", value: .answer, status: nil,
                             detail: "Your answer, in YouTube Studio. Prakriti's edit cuts, zooms and adds text; nothing in its picture or sound is generated."))
            if f.tags.isEmpty {
                out.append(.init(id: "tags", label: "Tags", value: .answer, status: .missing, detail: "No tags written. Turn on Titles, show notes and chapters, then Make Again."))
            } else {
                let text = f.tags.joined(separator: ", ")
                out.append(.init(id: "tags", label: "Tags", value: .text(text), status: text.count <= tagsLimit ? .pass : .fail,
                                 detail: "\(f.tags.count) tags, \(text.count) characters (up to \(tagsLimit))."))
            }
            if let description = f.description, !description.chapters.isEmpty {
                out.append(.init(id: "chapters", label: "Chapters", value: .answer, status: .pass,
                                 detail: "\(description.chapters.count) chapters, in the description, the first at 0:00."))
            } else {
                out.append(.init(id: "chapters", label: "Chapters", value: .answer, status: .missing, detail: f.description?.chapterProblem ?? "No chapters yet."))
            }
            if let captions = f.captionsFile {
                out.append(.init(id: "captions", label: "Subtitles file", value: .file(captions), status: f.captionsPass ? .pass : .fail,
                                 detail: "In Studio, Subtitles, Upload file, With timing."))
            } else {
                out.append(.init(id: "captions", label: "Subtitles file", value: .answer, status: .missing, detail: "No captions file is made yet."))
            }
        case .youtubeShorts, .instagramReels, .tiktok:
            if f.shorts.isEmpty {
                out.append(.init(id: "file", label: "Shorts", value: .answer, status: .missing, detail: "No shorts are made yet. Choose Make Shorts.", thirdParty: platform != .youtubeShorts))
            }
            for short in f.shorts {
                let n = short.number
                let fits = short.duration <= platform.longest + 0.001
                out.append(.init(id: "file-\(n)", label: "Short \(n)", value: .file(short.file), status: short.failed == 0 && fits && short.width == 1080 && short.height == 1920 ? .pass : .fail,
                                 detail: "\(Format.timecode(short.duration)), \(short.width) by \(short.height)"
                                    + (fits ? "" : String(format: ", over the %.0f s %@ takes", platform.longest, platform.title))
                                    + (short.failed == 0 ? ", every check passes." : ", \(Format.count(short.failed, "check")) fail."),
                                 thirdParty: platform != .youtubeShorts))
                switch platform {
                case .youtubeShorts:
                    let title = short.summary.prefix(1).uppercased() + short.summary.dropFirst()
                    out.append(.init(id: "title-\(n)", label: "Short \(n): title", value: .text(title), status: title.count <= titleLimit ? .pass : .fail,
                                     detail: "What its part of the talk is about, in the planner's words. Change it as you like."))
                    out.append(.init(id: "captions-\(n)", label: "Short \(n): words on screen", value: .answer, status: .pass, detail: "Burned into the picture; no file to upload."))
                default:
                    if let caption = f.instagram {
                        out.append(.init(id: "caption-\(n)", label: "Short \(n): caption", value: .text(caption), status: .pass,
                                         detail: platform == .tiktok ? "The Instagram caption, written for the episode." : "The Instagram caption, written for the episode, with its hashtags.",
                                         thirdParty: true))
                    } else {
                        out.append(.init(id: "caption-\(n)", label: "Short \(n): caption", value: .answer, status: .missing,
                                         detail: "No caption written. Turn on Titles, show notes and chapters, then Make Again.", thirdParty: true))
                    }
                }
            }
            out.append(.init(id: "cover", label: "Cover", value: .answer, status: nil,
                             detail: platform == .youtubeShorts ? "Chosen in YouTube Studio from the short's own frames." : "Chosen in the \(platform == .tiktok ? "TikTok" : "Instagram") app from the short's own frames.",
                             thirdParty: platform != .youtubeShorts))
        }
        return out
    }

    /// Reads `Description.txt` back: its title and description (the chapters stay in the description, as YouTube reads them).
    static func readDescription(_ text: String) -> VideoDescription {
        var d = VideoDescription()
        let parts = text.components(separatedBy: "\nDESCRIPTION\n")
        if let head = parts.first {
            let title = head.replacingOccurrences(of: "TITLE\n", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            d.title = title.isEmpty || title.hasPrefix("MISSING") ? nil : title
        }
        if parts.count > 1 {
            let body = parts[1].components(separatedBy: "\nCHAPTERS\n")
            var lines = body[0].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            // The chapter lines at the end of the description ("0:00 Opening"), read back as chapters.
            var chapters: [VideoDescription.Chapter] = []
            while let last = lines.last, let space = last.firstIndex(of: " "), let seconds = Self.seconds(String(last[..<space])) {
                chapters.insert(.init(start: seconds, title: String(last[last.index(after: space)...])), at: 0)
                lines.removeLast()
            }
            let description = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            d.description = description.isEmpty || description.hasPrefix("MISSING") ? nil : description
            d.chapters = chapters
            if chapters.isEmpty, body.count > 1 {
                let problem = body[1].replacingOccurrences(of: "MISSING: ", with: "").components(separatedBy: " Chapters go in")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                d.chapterProblem = problem.isEmpty || problem == "none." ? nil : problem
            }
        }
        return d
    }

    /// "1:02:03" or "12:05" as seconds, or nil.
    static func seconds(_ stamp: String) -> Double? {
        let parts = stamp.split(separator: ":").map { Int($0) }
        guard parts.count >= 2, parts.count <= 3, parts.allSatisfy({ $0 != nil }) else { return nil }
        return Double(parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 })
    }
}
